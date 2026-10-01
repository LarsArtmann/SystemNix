# Status: Manifest service removal + image-freshness audit (2026-10-01 07:21 CEST)

**Session scope:** owner asked (1) "do we still use docker?", (2) "are all images up to date (latest)?", then pivoted mid-session: "remove manifest, I do not use it". This report covers that session only — no research beyond it. Co-existing agent session(s) were active the whole time (mr-sync/dns-blocker/bank-sync work landed in parallel; their work is referenced ONLY as tree-state context, never claimed).

**Format note:** the status-report skill's canonical output is a styled HTML dashboard; the owner explicitly requested `.md` — honored, override flagged here per skill contract.

---

## a) FULLY DONE

| # | What | Evidence |
|---|------|----------|
| a1 | **Manifest service removed from the entire config surface** — module (`modules/nixos/services/manifest.nix`, 224 lines) + sops file (`platforms/nixos/secrets/manifest.yaml`, 18 lines) deleted via `git rm`; every wire stripped: port 2099 (`lib/ports.nix`), both image pins (`lib/images.nix`: `manifestdotbuild/manifest:6.18.0@…` + postgres sidecar), `manifest.home.lan` DNS record (`dns-local.nix`), `services.manifest.enable` flip + 2 comment blocks (`configuration.nix`), restic app-dump path, post-deploy smoke check + auth-vHost fallback entry, status-report monitored-units entry, service-health-check listing, both VM-test stub sets (`test-caddy-mint.nix`, `test-integration.nix`), and 8 stale comment cleanups (gatus-config, miniflux, service-defaults, data-corruption-repair, otel-endpoint-audit, papdashboard, backup-coordination, configuration.nix) | `git rm` exit 0; sweep greps: `flake.nix` 0 hits, port `2099` 0 live hits, modules README catalog 0 hits |
| a2 | **Eval-verification battery green** — `nix flake check --no-build` all-checks-passed (run twice: after core removal, after doc passes); negative evals: `nix eval …config.services.manifest` → attribute missing; `networking.local.subdomains` → 0 manifest entries; `scripts/check-todo-system.sh` → "queue/library structure clean"; `nix-instantiate --parse` on all 13 touched `.nix` files OK; shellcheck on 4 touched shell scripts (3 clean; 1 pre-existing SC2034 in `service-health-check:69`, untouched line) | command outputs in session; commits `bbfd04fa`, `06317dfb`, `5d1b63be` |
| a3 | **All live doc surfaces reconciled** — README service-table row, FEATURES (5 spots: service table, pool backups, DNS list, backup schedule, off-site list), ROADMAP (2), sso-dns Layer-2 table, signoz-coverage, health-dashboard fleet inventory, storage NOCOW row, TODO_LIST backfill row, planning-doc T5b marked MOOT, and a `### Removed` CHANGELOG entry naming every surface incl. the deliberately-kept host-side residue | daemon commits `06317dfb` (11 files), `5d1b63be`; CHANGELOG entry verifiable at `git show 06317dfb -- CHANGELOG.md` |
| a4 | **Twenty image staleness detected + queued** — `scripts/check-image-updates.sh`: `twentycrm/twenty v2.32.0 → 2.43.0 OUTDATED`; queued as `[ready]` with the DB-migration-review gate (queue row + `docs/todo/services.md` library row, pair-consistent) | script output "Checked: 5, failures: 1"; TODO_LIST row + services.md row landed |
| a5 | **Both owner questions answered** — docker: yes, still a default service (`default-services.nix:21`, data-root `/data/docker`), remaining consumers twenty/dozzle/whisper-rocm(disabled); images: twenty outdated, postgres/redis float by design, dozzle+whisper digest-pinned (caveat → b3/e2) | answered in-session; caveats corrected below |
| a6 | **Self-introduced error caught + fixed during report authoring** — my miniflux schedule rewording still referenced the now-deleted 02:30 slot; corrected to the real neighbors (~02:00 pg_dump window / cv 03:17) | `modules/nixos/services/miniflux.nix:441`, fix uncommitted at report time (daemon will sweep) |

## b) PARTIALLY DONE

| # | What works | What remains | Blocker | Effort |
|---|-----------|--------------|---------|--------|
| b1 | Manifest removal is **committed and eval-green** | **Not deployed.** The live host still runs the compose containers, the protected vHost (both zones), the DNS record, the Gatus "Manifest" check, and the tile until the owner runs `nix run .#deploy` | deploy is owner sudo | S |
| b2 | Removal work is fully in git (tree correct, verified) | **History hygiene imperfect:** the removal sits under heuristic daemon commit messages; one commit (`bbfd04fa`, 25 files) entangles my ~20 removal files with the other session's dns-blocker/mr-sync work. Amend attempted twice, raced both times (index lock; daemon fired `d5ec0c8a` mid-retry), repair deliberately aborted under an active foreign session. CHANGELOG entry is the canonical record | rewriting shared history requires a quiescent window (see g2) | S–M |
| b3 | Image-freshness check executed; twenty correctly flagged | Dozzle reported "OK (digest pinned)" but the script only proves digest drift, **not version currency** — v10.10.0 may not be the newest release. Tooling gap queued (pipeline.md) | none — script extension is `[ready]` | S |
| b4 | Both touched VM tests eval-clean (`nix flake check --no-build` evaluates them) | **Never executed** — a runtime vHost/service-enumeration divergence would be invisible to eval. Queued `[ready]` | none | S |
| b5 | Docker question answered from config (module, data-root, consumers) | **Live state not probed** — no `docker ps` / `docker system df` this session, so "what actually runs right now" (incl. manifest containers still up pre-deploy) is inferred, not observed | none — one command, next session | S |

## c) NOT STARTED

| # | What | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| c1 | Host-side residue prune (compose project down, `manifest_pgdata` volume, `/mnt/pool/backups/manifest`) | deploy-gated + owner-gated (final PG data deletion) | yes — queued `[blocked:deploy]` |
| c2 | Twenty bump execution | queued behind migration review (11 minors of upstream release notes) | yes |
| c3 | check-image-updates.sh semver-currency extension | queued `[ready]`, not yet implemented | yes |
| c4 | Twenty → native-Nix migration decision/work | owner architecture question (g1), zero pre-work done | unknown — that's the question |
| c5 | Reuse of the freed 02:30 backup IO slot | owner decision, noticed only while fixing comments | unknown |
| c6 | Service-removal checklist in CONTRIBUTING (distilled from geometrikks + manifest removals) | not started; the two removals happened checklist-free and both left residue (geometrikks: docker volumes; manifest: comment time-slots) | yes |

## d) TOTALLY FUCKED UP

Nothing loses data or blocks development — but radical honesty per section contract:

| # | What's wrong | Severity | Root cause | Mitigation |
|---|-------------|----------|-----------|------------|
| d1 | **I introduced a stale-reference while removing stale-references**: my miniflux rewording said "staggered between cv (03:17) and the 02:30 pg_dump slot" — but 02:30 WAS manifest's backup and no longer exists. It shipped inside a daemon commit and was caught only by self-review during THIS report | Trivial (one comment), but the class is exactly what removals exist to kill | I rewrote a schedule comment from memory of the OLD stagger map instead of re-deriving the live 02:xx neighborhood | fixed same-session (`miniflux.nix:441`); lesson → e1/c6 |
| d2 | **Reported dozzle as "OK / up to date" without the digest-pin caveat** — the script's OK proves tag-resolution, not version currency; the owner asked "are all images up to date (latest)?" and got an overconfident yes for 2 of 5 images (dozzle, whisper-rocm) | Low-Medium (misinforms the always-latest policy) | I read the script's verdict labels as semantic truth without reading what each check mode actually proves | corrected here; tooling fix queued (b3) |
| d3 | **Lost the daemon-race twice and the removal never got a properly-messaged commit** — amend attempt 1: index lock; attempt 2 (after a 20 s sleep): the daemon fired between my check and my commit, sweeping the foreign session's in-flight test file into a new HEAD | Low (cosmetic/history), Medium annoyance | I retried the amend instead of treating a lock as "wait for quiescence" — the retry is what created the raced-HEAD confusion; aborting was the correct call, retrying was not | one-time `git commit --amend` attempt policy → e3; split decision → g2 |
| d4 | **Answered "do we still use docker" from config greps, never from the live host** — the honest runtime answer ("manifest containers are STILL RUNNING right now, burning RAM + port 2099 until you deploy") was inferable but never observed | Low | config greps answer "configured", not "running" — the assert-WHICH-entity discipline applies to state questions too | b5; habit fix → e4 |
| d5 | **My first sweep grep for leftover references was case-sensitive** and missed `papdashboard.nix`'s "Manifest" comment; the sub-agent's inventory had it, my "verification" pass initially didn't | Trivial (caught in the follow-up pass) | entity-name sweeps must be `-i` | convention → e5 |

## e) WHAT WE SHOULD IMPROVE

1. **Service-removal needs a checklist** (c6): two removals now (geometrikks 2026-09-29, manifest today) each left residue the next session had to find. The checklist writes itself from this session's inventory: module, sops file, port, images, DNS record, vHost/gatus/tile/backup registry entries, restic paths, smoke scripts, monitored-units lists, VM-test stubs, doc surfaces, CHANGELOG — **plus TIME-SLOT comments** (schedules/stagger maps that name the dead service) and a final case-insensitive repo sweep.
2. **`check-image-updates.sh` should make "OK" mean "latest"** (b3/d2): add Hub-tags semver comparison for digest-pinned APP images; sidecars keep the deliberate major-float SKIP.
3. **Daemon-amend policy refinement** (d3): CONTRIBUTING's daemon-race policy covers land-on-top vs amend and the soft-reset split, but not the retry trap: a lock during an amend attempt means **schedule for quiescence, never retry** — my 20-second sleep-retry created a raced HEAD that made the repair strictly harder. One sentence in CONTRIBUTING "Daemon-race commit policy" closes it.
4. **Probe the live host for state questions** (d4): config greps for "what is configured", one `docker ps` / `systemctl is-active` batch for "what is running". Cheap, and it would have surfaced the still-running manifest containers as the headline caveat.
5. **Case-insensitive entity sweeps** (d5) — one flag, infinite re-runs saved.
6. **Report-vs-signal separation**: this session carried two questions + a pivot; the pivot's noise (daemon races, doc passes) nearly buried the actual Q2 answer (twenty is 11 minors behind). For multi-ask sessions, answer the QUESTIONS first in the final message, then the work log — done here, but it should be the default shape, not a recovery.

## f) Up to 50 things we should get done next

Items 1–10 are THIS session's findings (harvest state marked). Items 11–50 are open work **already tracked** in TODO_LIST/domain libs — confirmed still-open during this session's edits; listed for the owner's prioritization view, deliberately NOT re-harvested (they live in the system; duplicating them here would create the drift the TODO system forbids).

| # | Task | Impact | Effort | Category | Harvest state |
|---|------|--------|--------|----------|---------------|
| 1 | Deploy the manifest removal (`nix run .#deploy`, owner sudo) — until then the host runs a service the owner doesn't use | Critical | S | Deploy | recorded here; residue row (item 2) carries the deploy gate |
| 2 | Post-deploy residue prune: `docker compose ls` → project down → volume rm (`*_manifest_pgdata`, owner-gated data loss) → `trash /mnt/pool/backups/manifest`; verify Gatus check/tile/DNS/vHost gone in BOTH zones | High | S | Cleanup | **HARVESTED** queue+library (`[blocked:deploy]`) |
| 3 | Run `tests/test-integration.nix` + `tests/test-caddy-mint.nix` VM tests (touched, eval-green, never executed) | High | S | Quality | **HARVESTED** queue+library |
| 4 | Twenty bump v2.32.0 → 2.43.0 with upstream migration review (11 minors) + add digest pin while in `lib/images.nix` | High | M | Feature | **HARVESTED** queue+library (earlier in session) |
| 5 | `check-image-updates.sh`: semver-currency for digest-pinned app images (dozzle) | Medium | S | Quality | **HARVESTED** queue+library (pipeline.md) |
| 6 | Soft-reset split of mixed daemon commit `bbfd04fa` (my removal files vs foreign dns-blocker/mr-sync) in a quiescent window | Low | S | Cleanup | NOT harvested — owner-gated history rewrite, question g2 |
| 7 | Write the service-removal checklist into CONTRIBUTING (distilled from geometrikks + manifest) | Medium | M | Documentation | NOT harvested — folded into this row; harvest on owner go-ahead |
| 8 | Daemon-amend policy sentence: lock ⇒ quiescence, never retry (CONTRIBUTING) | Low | S | Documentation | NOT harvested — folded into row 7's doc pass |
| 9 | Decide reuse of the freed 02:30 backup IO slot | Low | S | Decision | NOT harvested — owner question (see g-set below) |
| 10 | Sweep `~/projects/*` for manifest-router consumers (scripts/keys POSTing to `manifest.home.lan:2099`) before deploy | Medium | S | Cleanup | NOT harvested — blocked on g3 answer |
| 11 | Deploy the mr-sync `wantedBy` fix + full verification battery | High | S | Deploy | tracked: TODO_LIST + services.md (`[blocked:deploy]`) |
| 12 | mr-sync VM test (`tests/test-mr-sync.nix`) | Medium | M | Quality | tracked: services.md `[ready]` |
| 13 | Eval-time "never-enabled unit" audit (health-dashboard + mr-sync ghost class) | High | M | Quality | tracked: pipeline.md `[ready]` |
| 14 | Fix the 63 queue↔library drifts from the pairing check | Medium | M | Documentation | tracked: pipeline.md `[ready]` |
| 15 | Close the 53-report unharvested backlog (harvest-coverage lint) | Medium | L | Documentation | tracked: pipeline.md `[ready]` |
| 16 | Codify re-fire evidence-appendix convention in CONTRIBUTING | Low | S | Documentation | tracked: pipeline.md `[ready]` |
| 17 | Architecture-catalog go-live (owner sequence: setup script → CI green → sops paste → deploy) | High | M | Deploy | tracked: services.md `[blocked:user]` |
| 18 | Architecture-catalog VM test | Medium | M | Quality | tracked: services.md `[ready]` |
| 19 | SigNoz dashboard tile for catalog freshness | Low | S | Feature | tracked: services.md `[watch]` |
| 20 | Forgejo G1 Samsung subvol migration window (owner: prepare → finalize → deploy → burn-in) | High | M | Deploy | tracked: services.md `[blocked:user]` |
| 21 | Forgejo Phase 2 logo/favicon decision + build | Low | M | Feature | tracked: services.md `[decision]` |
| 22 | NOCOW for the twenty pg volume on `/data` (premise-check `lsattr` first; manifest leg now gone) | Medium | S | Storage | tracked: storage.md `[blocked:user]` |
| 23 | Offsite Borg go-live (StorageBox host/user + host-key pin) | High | S | Backup | tracked: storage.md + offsite-borg.md `[blocked:user]` |
| 24 | `backup.nix` VM test before the Borg flip | Medium | M | Quality | tracked: storage.md |
| 25 | Runbook backfills: immich, twenty, pocket-id, oauth2-proxy, crush-daily, dozzle, openseo, taskchampion, atticd, signoz (manifest dropped today) | Medium | L | Documentation | tracked: services.md `[ready]` |
| 26 | Fold 21 "Agent Notes" appendices into runbook narratives | Low | M | Documentation | tracked: services.md `[ready]` |
| 27 | Decide: crush hook to auto-inject `docs/agents/<domain>.md` on first domain touch | Low | M | Tooling | tracked: services.md `[decision]` |
| 28 | Health Hub post-deploy verification chain (item 11 of its checklist remains open) | Medium | S | Quality | tracked: services.md `[blocked:deploy]` |
| 29 | Expose hub cadence/timeout as module options (upstream `WithPushInterval` gap) | Low | M | Feature | tracked: services.md `[ready]` |
| 30 | Decide hub federated remotes beyond CV | Low | S | Decision | tracked: services.md `[decision]` |
| 31 | Decide hub fetch cadence (2 s vs 30 s/1 m) | Low | S | Decision | tracked: services.md `[decision]` |
| 32 | Decide hub protected vs plain vHost | Low | S | Decision | tracked: services.md `[decision]` |
| 33 | Decide hub hardening/feature toggles to wire | Low | S | Decision | tracked: services.md `[decision]` |
| 34 | Rogue hermes llama pair: kill / re-port / delete cron | Medium | S | Decision | tracked: services.md `[decision]` |
| 35 | Browser-history gate acceptance re-run timing (post-fix vs probe-user cleanup) | Medium | S | Decision | tracked: services.md `[decision]` |
| 36 | Borg real-repo drill verify semantics (live-cmp vs baked manifest) | Medium | S | Decision | tracked: TODO_LIST + storage.md |
| 37 | Samsung migration phase scheduling (hot-DB waves 2+: twenty/manifest-era pg dirs → shared PG cluster already hosts geometrikks) | High | L | Storage | tracked: ROADMAP + storage.md |
| 38 | `/data` rename + model-root consolidation | Medium | L | Storage | tracked: ROADMAP |
| 39 | Root-disk cleanup proposal P1–P6 rows (366 GB btrfs-level snapshot/reflink usage is the lever) | High | M | Storage | tracked: docs/operations/disk-cleanup-proposal-2026-09-28.md |
| 40 | DMARC fleet-rollout follow-ups (report modified in-tree by the parallel session — confirm its open items) | Medium | S | Mail | tracked: docs/status/2026-09-30_08-06 report (foreign session's surface — verify, don't duplicate) |
| 41 | Crash-loop circuit breaker: boot-catch-up stampede control | Medium | M | Stability | tracked: ROADMAP |
| 42 | io.latency pilot for interactive cgroups (only post-Samsung, on real Zone-6 recurrence) | Low | L | Stability | tracked: ROADMAP (conditional) |
| 43 | Continuous per-unit IO telemetry (io.stat textfile collector) | Medium | M | Observability | tracked: ROADMAP |
| 44 | Guard Zone 7 episodic IO bucket (calibrate from io-psi-forensics data first — do NOT build preemptively) | Low | M | Observability | tracked: ROADMAP (conditional) |
| 45 | Restic as single source of truth for app-dump retention (after ≥3 green nightlies + restore smoke) | Medium | S | Decision | tracked: ROADMAP |
| 46 | Reduce unsafe shutdowns (UPS / WDT tuning decision) | High | M | Hardware | tracked: ROADMAP |
| 47 | BTRFS `/data` subvolume migration (`@data`) | Low | L | Storage | tracked: storage.md `[blocked:user]` |
| 48 | Bank-sync go-live (sops secrets + enable flip) | Medium | S | Feature | tracked: services.md area |
| 49 | Voice-agents / minecraft re-enable decisions (both disabled, both still config-carried) | Low | S | Decision | surfaced via FEATURES read this session; not formally queued — harvest only if wanted |
| 50 | Twenty DB-side: verify the postgres-sidecar digest-pin pattern actually covers `twenty-postgres`/`twenty-redis` (both FLOAT today — unpinned `16-alpine`/`7-alpine`), unlike manifest's pinned sidecars | Medium | S | Quality | NOT harvested — folds into row 4's `lib/images.nix` touch |

**Harvest accounting:** rows 2, 3, 4, 5 harvested queue+library at authoring time (4 earlier in-session). Row 1 is owner action, carried by row 2's gate. Rows 6–10 deliberately not harvested (owner-gated history rewrite, doc-convention bundle, owner decision, g3-blocked sweep — each marked why). Rows 11–49 pre-tracked (no action). Row 50 folds into row 4.

## g) Top 3 questions I can NOT figure out myself

1. **Docker end-state:** after geometrikks (native) and manifest (deleted), Twenty is the last real docker consumer. Do you want twenty migrated to native Nix (retiring docker entirely, like the geometrikks pilot), or is docker staying as a platform? This single answer gates rows 4, 22, 37, 47, 49 — and whether the freed 02:30 slot and the docker data-root end-state planning even matter. (What I tried: the geometrikks migration proves the pattern, but twenty is a large Node monorepo with redis+pg sidecars — migration cost is unknowable without upstream packaging research I shouldn't start without your direction.)
2. **History repair for `bbfd04fa`:** that daemon commit entangles my manifest removal with the parallel session's dns-blocker/mr-sync work under a heuristic message. CONTRIBUTING's soft-reset split is the sanctioned repair, but rewriting shared history while the other session is live (it was committing during THIS report) is what the tree discipline forbids. Do you want the split done in the next quiescent window, or is heuristic history acceptable? (What I tried: amend twice; both raced; aborted deliberately.)
3. **Did anything OUTSIDE this repo consume the Manifest router?** API keys minted in its UI, cron jobs, scripts on other machines, or workflows POSTing to `manifest.home.lan:2099` / `manifest.larsartmann.cloud`? Repo greps are clean, but consumers living outside SystemNix are invisible to me — any of them break silently at deploy. (What I tried: full-repo sweep, doc sweep, inventory of all in-repo wiring — all clean.)

---

*Point-in-time snapshot; goes stale by design. §f rows 2–5 harvested into TODO_LIST.md + docs/todo/{services,pipeline}.md at authoring time per the AGENTS.md self-harvest rule. Commit left to the auto-commit daemon per harness contract.*
