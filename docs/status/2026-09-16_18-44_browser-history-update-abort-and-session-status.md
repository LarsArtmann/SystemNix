# Session Status — Browser-History Update Abort, Provenance Resolution, Pending Bin-Nixification Deploy

**When:** 2026-09-16 18:44 CEST · **Host:** evo-x2 · **Repo:** SystemNix @ `c6e999fd` (clean)
**Session span:** resumed from 13-06 handoff → 4 work items, one aborted mid-flight by design.

---

## TL;DR

The browser-history flake update was **attempted and correctly aborted**: upstream master
(`7ab108a` AND `021efafa`) fails the full package build (`s.cfg.AgentFreshness undefined`)
because the parallel session in `~/projects/browser-history` is committing **piecewise** —
the completing files exist only in 3 unpushed local commits. The lock was reverted
byte-identical to `0971fe9c` and the daemon committed the revert. Nothing broken, nothing
deployed, one doctrine learned the hard way (FOD probe ≠ compile check).

---

## a) FULLY DONE

| #  | Work                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| -- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1 | **Browser-history provenance anomaly RESOLVED** (carried from 13-06 as "unfindable")                                                                                                                                                                                                                                                                                                                                                                                                                             | The introducer of the undocumented `/0971fe9c` pin is merge `3ce4414b` (Sep 4 22:00, "Merge stale local forgejo-hermes-agent tip"): its first-parent diff flips `?ref=master` → rev-URL, and **neither parent contained it** — a working-tree edit swept into the merge commit. `git log -S --all` never finds it because pickaxe **skips merges by default**; `--diff-merges=first-parent` reveals it. Verdict: deliberate pin (Sep 4 = ingest-attribution-fix deploy day), accidental permanence (never a reviewable diff). Same merge also flipped the helium fork (`vikingnope` → `schembriaiden`). |
| A2 | **Lock update executed per two-probe rule — and safely reverted when the rule's gap was exposed**                                                                                                                                                                                                                                                                                                                                                                                                                | Probed both `vendor-hash-server`/`vendor-hash-agent` FODs at `7ab108a` (PASS), locked, re-probed at the actual locked rev `021efafa` after discovering master moved mid-flight (both PASS), full build from our lock FAILED at BOTH revs, reverted from `/tmp` backup byte-identical, flake metadata evals clean, HEAD `c6e999fd` carries `0971fe9c`. Zero lasting damage.                                                                                                                                                                                                                              |
| A3 | **Session todo list recreated from handoff** and maintained through 7 steps (probe → lock → verify → build → eval → commit → deploy-check)                                                                                                                                                                                                                                                                                                                                                                       | todos tool, all completed/closed accurately.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| A4 | **Two upstream findings documented**: (1) `021efafa` bumped go.mod floor **1.26.7 → 1.27.1** while browser-history's flake still pins `goPkg = go 1.26.7` (tarball override) — the eventual update needs that bumped upstream first; (2) **GOTOOLCHAIN=local floor enforcement did NOT fire** — FOD and compile proceeded with a 1.26.7 toolchain against a 1.27.1 floor (contradicts AGENTS.md doctrine "a floor past the pinned toolchain kills the FOD outright"). Mechanism unverified — flagged, not fixed. |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| A5 | Deploy-pressure check                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Refused to deploy: IO PSI some avg10 **81.7%** (worse than the morning's storm that blocked 5 attempts). Moot anyway — lock is net-unchanged, no deploy needed.                                                                                                                                                                                                                                                                                                                                                                                                                                         |

## b) PARTIALLY DONE

| #  | Work                                                        | Done                                                                                                                                                                                                                                                      | Missing                                                                                                                                                                                                                                                                    |
| -- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1 | **`~/.local/bin` nixification** (from 13-06 handoff)        | All code: `pkgs/print-safe.nix` (byte-verified), overlay wiring, `llamacpp-server` in ai-stack, uv/shfmt/nodejs/buildflow/flm in configuration.nix, HM `sessionPath`                                                                                      | **Deploy** (blocked by IO storms all day) → then trash the staged deletion list → smoke tests (`print-safe` dry-run, `llamacpp-server` launch, `which` resolution)                                                                                                         |
| B2 | **Pin-policy directive + full pin audit** (earlier session) | 6 pins converted branch-ref-governed (`7f513e88`); 3 pins flipped to fresh master with build-verified re-locks (md-go-validator, todo-list-ai, go-nix-helpers); 13 hard pins kept with documented reasons; AGENTS.md bullet rewritten with two-probe rule | CI verification of the git+ssh trio at next push; the kept pins still need eventual upstream vendorHash fixes (DiscordSync +129, overview +7, PMA +9, library-policy +47, go-auto-upgrade +31)                                                                             |
| B3 | **Browser-history update** (this session's task)            | Probes, lock attempt, failure diagnosis, clean revert — the ground truth for the retry is fully mapped                                                                                                                                                    | The update itself: **impossible until upstream master compiles** (needs the parallel session to push its 3 local commits: `cf16427`, `e4ef798`, `f34ff01`) + goPkg 1.27.1 override bump + SystemNix wrapper diff review (`nix/server-module.nix` options changed upstream) |

## c) NOT STARTED

- **HARVEST** of the 13-06 report's section (f) into TODO_LIST/ROADMAP (docs-health skill).
- **Annotate** the 13-06 status report: its "provenance unfindable" claim is superseded by A1 (docs-health ANNOTATE mode — non-destructive).
- AGENTS.md updates from today: two-probe rule needs the **"full-build probe before moving the lock"** amendment; pin-policy bullet needs today's outcome (browser-history deliberately held at `0971fe9c`); merge-sweep (`3ce4414b`) as an introduction-vector class for undocumented pins.
- All parked follow-ups from 13-06 §parked: signoz/otel-collector migration-review bump; art-dupl-src vs art-dupl divergence; tq-redesign cutover (the :18472 double-run warning recurs); foreign doc review in `9e251ef4`; `scripts/audit-flake-pins.sh` + eval-time PIN-REASON lint; `scripts/deploy-when-quiet.sh` (my two buggy wait-loops in the morning session prove the need).
- The 3 still-open user questions from 13-06 (force-deploy policy; ~~browser-history provenance~~ now RESOLVED; himalaya fate).

## d) TOTALLY FUCKED UP

1. **I moved the lock to a rev I had only FOD-probed.** The two-probe rule as written probes `goModules` FODs — which only DOWNLOAD modules and never compile. FOD-green gave false confidence; the full build (the actual gate) failed at both revs. The correct sequence — **full package build at the exact target rev BEFORE touching the lock** — would have avoided locking a broken rev entirely. Caught by my own post-lock verification before any deploy, so the damage is a wasted cycle and a reverted lock, but the protocol has a hole I drove straight through.
2. **I raced an active session and didn't read the obvious signal.** The browser-history checkout was DIRTY with templ/server.go files at my first inspection — a parallel session mid-work. Then `021efafa` (19-file daemon sweep) appeared BETWEEN my probe and my lock command. That was the moment to stop and wait for quiescence; instead I re-probed and kept going. The breakage I hit is precisely the mid-refactor-snapshot class AGENTS.md warns about.
3. **Upstream master is a broken build for ANY consumer right now** (`7ab108a` onward): `agent_freshness.go` committed without its `config.go` companion. Not my commit, but my session is the one that documented it — and the daemon partial-commit sweep that caused it is the same class that bit SystemNix repeatedly (auto-commit daemon batching foreign/partial work).
4. (Honest accounting, not new damage) The morning session's deploy has been blocked for ~6 hours by sustained real IO storms; two of my wait-loop scripts had bugs (broken awk; float-vs-int comparison). The bin-nixification work sits fully coded but undeployed.

## e) WHAT WE SHOULD IMPROVE

1. **Amend the probe protocol: FOD probes are necessary, not sufficient.** Add the mandatory full-package build at the exact target rev BEFORE `nix flake lock --update-input`. One build probe would have saved the entire lock-touch cycle.
2. **Quiescence gate for consuming "X got updates":** when the source repo's working tree is dirty or commits are landing minutes apart, treat the update as IN FLIGHT — wait for push + stable HEAD before locking. Formalize as a checklist line, or script it.
3. **The two-probe rule (and its name) undersells the compile gate** — rename/rewrite in AGENTS.md so no future session repeats the FOD-only trap.
4. **Merge-sweep auditing:** `3ce4414b` proves undocumented changes enter history via merge conflict-resolution sweeps (browser-history pin AND a helium fork flip in ONE merge). A one-off audit of merge commits whose first-parent diff touches `inputs` would find other swept debris; the pin-policy lint should treat "input URL changed inside a merge commit" as a review flag.
5. **Deploy-when-quiet:** two hand-rolled buggy loops in one day is the argument. A small script (poll PSI + disk-busy corroboration, then exec deploy) kills this recurring manual dance.
6. **Upstream daemon hygiene:** browser-history needs a commit-time `go build ./...` gate (pre-commit) so daemon sweeps can't publish uncompiling trees — SystemNix-style guards, applied at the source.
7. **Verify the GOTOOLCHAIN anomaly before it bites a real bump:** if floors no longer kill builds under `GOTOOLCHAIN=local`, several AGENTS.md entries (drop-day doctrine, tarball overrides) are built on a premise that just changed. Cheap experiment: build a package with a floor above its toolchain and observe.
8. **Todo-list discipline:** the handoff said recreate todos FIRST; I answered the provenance question first instead. Small, but the pattern (context handoffs → act before instrumenting) is worth killing.

## f) UP TO 50 NEXT THINGS (brainstorm — impact-ordered, grouped; NOT a commitment list)

**Immediate fallout of THIS session (P0):**

| #  | Task                                                                                                                                 |
| -- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 1  | Wait for browser-history push → verify origin/master compiles (FULL package build at exact rev) before any lock touch                |
| 2  | Re-run `nix flake lock --update-input browser-history` + hermetic build from our lock                                                |
| 3  | Review SystemNix wrapper vs upstream module option changes: `git diff 0971fe9c..master -- nix/` in browser-history                   |
| 4  | Upstream: bump browser-history `goPkg` tarball override to 1.27.1 (new tarball hash) or drop when nixpkgs ships it                   |
| 5  | Amend AGENTS.md two-probe rule: mandatory full-build probe at target rev BEFORE moving the lock                                      |
| 6  | Investigate the GOTOOLCHAIN=local floor non-enforcement; correct AGENTS.md drop-day doctrine if confirmed                            |
| 7  | AGENTS.md pin-policy bullet: record browser-history deliberately held at `0971fe9c` (upstream broken)                                |
| 8  | Upstream browser-history: commit-time `go build ./...` pre-commit gate (kills the daemon partial-commit class at source)             |
| 9  | Annotate 13-06 report: provenance claim superseded (ANNOTATE mode, non-destructive)                                                  |
| 10 | One-off audit: merge commits whose first-parent diff touches flake.nix `inputs` (find other swept pin/fork edits — `3ce4414b` class) |
| 11 | Verify the helium fork flip (`vikingnope` → `schembriaiden`, same merge) is intentional and documented                               |

**Deploy block (P0, blocked on IO):**

| #  | Task                                                                                                                                                         |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 12 | Deploy when quiet (or user-approved `DEPLOY_FORCE_PRESSURE=1`)                                                                                               |
| 13 | Post-deploy: trash staged `~/.local/bin` deletions (buildflow×2, flm, himalaya suite, node shim, shfmt, uv/uvx, env fish files, print-safe, llamacpp-server) |
| 14 | Post-deploy verify: `which uv shfmt node buildflow print-safe llamacpp-server flm` → nix paths; `sessionPath` live in fresh fish                             |
| 15 | Smoke: `PRINT_SAFE_DRY_RUN=1 print-safe <pdf>`; brief `llamacpp-server` launch (crush provider :8899), then kill                                             |
| 16 | `scripts/deploy-when-quiet.sh` (poll PSI + disk-busy corroboration, then exec deploy)                                                                        |

**Docs/planning (P1):**

| #  | Task                                                                                                     |
| -- | -------------------------------------------------------------------------------------------------------- |
| 17 | HARVEST 13-06 §f + this report's §f into TODO_LIST/ROADMAP (docs-health)                                 |
| 18 | `scripts/audit-flake-pins.sh` + eval-time PIN-REASON lint (13-06 parked)                                 |
| 19 | Review foreign doc swept into commit `9e251ef4` (13-06 flagged, unreviewed)                              |
| 20 | tq-redesign cutover (parallel process on :18472 double-run warning recurs every deploy)                  |
| 21 | CI verification: git+ssh trio (BuildFlow/branching-flow/file-and-image-renamer deploy keys) at next push |

**Pin/flock maintenance (P1-P2):**

| #  | Task                                                                                               |
| -- | -------------------------------------------------------------------------------------------------- |
| 22 | signoz + signoz-otel-collector: migration-review bump (schema-migrator scope, not a hash chore)    |
| 23 | art-dupl-src (bare master) vs art-dupl (fork) divergence check                                     |
| 24 | go-taskqueue: flip interim `git+file?rev=` to `github:` after upstream push                        |
| 25 | DiscordSync pin: re-probe after upstream fixes vendorHash (+129 commits, c0604e46 doctrine intact) |
| 26 | overview (+7), PMA (+9), library-policy (+47), go-auto-upgrade (+31): same re-probe cycle          |
| 27 | md-go-validator / todo-list-ai / go-nix-helpers flips: confirm CI green post-flip                  |

**Stability/infra (P1-P2, from AGENTS.md standing items I noticed during the session):**

| #  | Task                                                                                                                       |
| -- | -------------------------------------------------------------------------------------------------------------------------- |
| 28 | The OWED REBOOT (corpse pins :52626, 2026-09-14 freeze aftermath) — run `pre-reboot-check` first                           |
| 29 | flm staged v1.0.3 go-live after reboot (staged-bump gate: fails post-fix)                                                  |
| 30 | llama.cpp mid-load CPU-spin regression: pin back to 20260905 build or bisect gfx1150 (RAG containment still carrying reds) |
| 31 | crush-hot-db deploy gate: /nix soak ends ~2026-09-17 (tomorrow)                                                            |
| 32 | Per-service subvolume doctrine Phase 2: fold crush-hot-db into ratified `services.hot-db`                                  |
| 33 | Hetzner StorageBox + BorgBackup offsite leg implementation (decided, blueprinted, not started)                             |
| 34 | /data EIO inode repair (btrbk-data failing nightly since 2026-08-20)                                                       |
| 35 | Dead `@nix` QLC subvol deletion (Phase 1 TODO)                                                                             |
| 36 | clickhouse-backup (telemetry has zero backup coverage)                                                                     |
| 37 | monitor365 re-enable owner decision (wireguard-collector crate publishing)                                                 |
| 38 | Turso plan decision: DiscordSync upgrade vs permanent local-only (encoded, red by design)                                  |

**User-step items I can't do (tracked, not forgotten):**

| #  | Task                                                                                |
| -- | ----------------------------------------------------------------------------------- |
| 39 | Resend domain verification (mail relay go-live; NDRs silently discarded until then) |
| 40 | Context7 key rotation (still LIVE per incident table)                               |
| 41 | History-purge push decision (held indefinitely since 2026-08-18)                    |
| 42 | Wise SCA approval watch → bank-sync RFC3339 phantom-writer watch post-approval      |
| 43 | InboxClean retro-decrypt repair deployment (needs upstream push + flake bump)       |
| 44 | himalaya: delete vs nixify (open since 13-06)                                       |
| 45 | Hermes workspace layout decision (deferred, revisit trigger in TODO_LIST)           |

**Smaller cleanups (P2-P3):**

| #  | Task                                                                                                   |
| -- | ------------------------------------------------------------------------------------------------------ |
| 46 | `/tmp/flake.lock.pre-bh-update` backup file (harmless; disposable)                                     |
| 47 | print-safe host-coupled CUPS filter paths: consider an eval-time guard or VM-test                      |
| 48 | niri-session-manager upstream hazards (restore re-runs on every process start) — upstream fix tracking |
| 49 | crush-daily UPDATE_GOLDENS flow: document the parallel-session golden-file race repair as a checklist  |
| 50 | 13-06's remaining open question queue: fold surviving items here (this list supersedes it)             |

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **Helium fork flip:** `3ce4414b` (the same merge that swept the browser-history pin) also flipped the helium input from `vikingnope/helium-browser-nix-flake` to `schembriaiden/helium-browser-nix-flake`. Deliberate choice of a specific fork, or more merge-swept debris I should revert? I cannot determine intent from history — neither parent contains it.
2. **Browser-history update ownership:** when the parallel session pushes, do you want me to take over (verify compile → re-lock → build → report), or does that session own the SystemNix consumption end-to-end and I stay out? Racing them again is the thing to avoid.
3. **Deploy policy under a storm-day:** the bin-nixification has been fully coded but undeployed for ~6 hours across 6 blocked attempts, with IO avg10 currently 81%. Do you want `DEPLOY_FORCE_PRESSURE=1` at a moment you choose (accepting the freeze-class risk the gate exists for), or keep deferring until a genuinely quiet window appears?

---

**Verification state at writing:** SystemNix @ `c6e999fd` clean; lock `browser-history → 0971fe9c` (deployed rev, byte-identical restore); origin/master of browser-history `021efaf` still broken (full-build-verified twice); local browser-history 3 commits ahead, unpushed; IO PSI some avg10 81.7%.
