# Status Report — Forgejo Staged-Primary: Plan + Phase-0 Code

**Session date:** 2026-09-18, ~15:00–17:28 CEST (continuum: storage Q&A → goal → pareto plan → Phase-0 execution)
**Scope:** THIS session only — the Forgejo-primary staged plan and its Phase-0 implementation. The parallel sessions' mirror hardening (system-785, 16:45 report) is baseline, not reported here.
**Skill note:** status-report skill's canonical output is HTML; user explicitly requested `.md` at `docs/status/` — override honored, divergence flagged per the skill's own rule.

---

## 0. TL;DR

The session converted "Forgejo becomes my primary" into a gated, staged, committed plan (23 medium / 90 fine tasks, 3 verification gates) AND executed the entire Phase-0 CODE: dedicated Samsung-TLC subvolume storage (inert), migration script, 8h btrbk backup leg, weekly restore drill, fail-closed freshness monitoring. Three commits pushed (`e4aa99ff` plan, `82b03d88` M01+M02, `4e7b61fc` M03+M04), every one eval-verified and `nix flake check --no-build` green. **Nothing is live yet** — everything ships inert behind `services.forgejo.dedicatedSubvolume` (default false), waiting on owner gate G1 (deploy + user-run migration). Three real self-caught quality gaps are listed in (d)/(e); the biggest: the restore drill's dump-zip layout assumption is UNVERIFIED, the migration script has NO fixture test, and the plan doc drifted from implementation in one place (F19).

## a) FULLY DONE

1. **Storage recommendation evolution** (conversation): Q&A established where Forgejo lives (`/var/lib/forgejo`, QLC `@`), initial Set-C recommendation was made, then self-invalidated when the user's goal (PRIMARY, not disposable mirror) landed — final doctrine: **Set B** (dedicated subvol, own btrbk leg, snapshots, no `+C`), grounded in `docs/planning/2026-09-15_per-service-btrfs-subvolumes-analysis.md`.
2. **Gap analysis of the user's goal**: push mirrors are DEAD CODE (2026-09-18 audit), "both ways" issues/PRs has no maintained tool (one-time import is native), off-LAN was declined 2026-08-31, storage doctrine flip required — all surfaced with sources before planning.
3. **Existing-docs inventory** for the goal: found the prior `docs/planning/2026-08-31_21-15_forgejo-primary-migration.md` (proposal with 5 recorded decisions), today's research session outputs, the 2026-07-22 brainstorm (sync layers, why issues can't sync, no-daemon verdict), and the 16:45 parallel-session report (baseline).
4. **Comprehensive plan committed**: `docs/planning/2026-09-18_16-44_FORGEJO-PRIMARY-STAGED-FOUNDATION.md` — pareto tiers (1%→51%, 4%→64%, 20%→80%, other-20%), 8 standing decisions, 6 phases with explicit EXIT gates (G1 foundation proof, G2 capability proof, G3 pilot burn-in), 23 medium tasks, 90 fine tasks (≤12 min each), mermaid execution graph, verschlimmbessern guardrails (dry-run-first deletes, shim never ships before pilot, shadow-dir-safe migration, IO-window discipline), risks section. Supersedes the 2026-08-31 plan's falsified push-mirror premise (annotated in-plan, doc itself not yet edited — see b8).
5. **M01 — subvol storage wiring** (`modules/nixos/services/forgejo.nix`): `services.forgejo.dedicatedSubvolume` option (mkEnableOption, ships inert), `fileSystems."/var/lib/forgejo"` (by-label tlc, `subvol=hot/forgejo`, doctrine options, nofail), `forgejo-subvol-bootstrap` oneshot (idempotent subvol create via `/mnt/hot`, `wantedBy`/`before` the dataDir mount — fstab cannot create subvols), mount gating on the WHOLE unit family (forgejo: `RequiresMountsFor` + `ConditionPathIsMountPoint`; backup/token/ssh-keys/github-sync/oidc/hermes: `RequiresMountsFor`), eval-time assertion requiring the `/mnt/hot` mount.
6. **M02 — migration script** (`scripts/migrate-forgejo-subvol.sh`): prepare (idempotent subvol + live pre-rsync) / finalize (refuses without prepare, refuses while family units active, delta rsync `--delete`, entry-count + apparent-size + sampled-checksum verification, rename-only swap keeping a `.qlc-pre-subvol` safety copy), `--dry-run`, tool preflight (sudo-PATH lesson), explicit abort path, and the critical semantics: **finalize leaves forgejo DOWN** — only the option-flip deploy may bring it up (mount-first ordering).
7. **M03 — 8h btrbk leg** (`snapshots.nix`): `btrbk.instances."forgejo"` (OnCalendar `*-*-* 05,13,21:40:00`, local 2d/3d, pool target `/mnt/pool/backups/forgejo-subvol` bounded 7d/14d 8w, subvol referenced via the `/mnt/hot` TOPLEVEL mount — independent of the dataDir mount), unit overrides (RequiresMountsFor both ends, 6h seed timeout, `MemoryHigh 4G` + `OOMScoreAdjust -250` per the btrbk-data oom lesson, onFailure), tmpfiles for snapshot + receive dirs (trailing `-`, detached-disk-boot clean), registered in `memory-emergency-guard.ioChurnUnits` (Zone-6 stoppable churn).
8. **M03 — freshness monitoring (fail-closed)**: `forgejo-subvol-backup-metrics` collector (5-min timer, mktemp+chmod+trap+CAP_FOWNER pattern, audit-textfile-tmp compliant) emitting `forgejo_subvol_backup_{scrape_errors,last_age_seconds,fresh}` from the newest RECEIVED subvol pool-side; new Gatus registry check "Forgejo Subvol Backup (8h)" (anchored `\n` pats, absence = red by design, 12h threshold = one missed slot tolerated).
9. **M04 — restore drill**: `forgejo-restore-drill` (Sun 06:00, after the 03:30 dump + 05:40 slot) proving BOTH recovery paths — dump zip (unzip → DB rebuild → `PRAGMA integrity_check` → `git fsck` sample) and received subvol (read in place, no mount needed → fsck sample); failures exit 1 → OnFailure + `system-health.extraMonitoredServices` (deliberate-event alerting; deviation from plan F19's metric+Gatus — see b/d).
10. **Verification discipline held throughout**: option-ON shape proven via `extendModules` throwaway evals (mount options, bootstrap wiring, all gates, drill+timer, exactly-once monitored entry, 4 registry checks); option-OFF baseline proven inert (`fileSystems ? "/var/lib/forgejo"` = false, btrbk instance absent); `nix flake check --no-build` green after EVERY batch (3×); `bash -n` on the script; pre-commit suite (gitleaks, deadnix, statix, treefmt, shellcheck on .sh) green on every commit.
11. **All three commits pushed to origin** with detailed messages: `e4aa99ff` (plan), `82b03d88` (M01+M02), `4e7b61fc` (M03+M04). Daemon commit races recovered cleanly 3× (pathspec commits, amend-after-stat-verify, collapse-after-content-verify — see d).

## b) PARTIALLY DONE

| # | Item                                              | What remains                                                                                                                                                                                                                                                                                                |
| - | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Gate G1 (Phase-0 activation)**                  | Owner-run: deploy inert batch → prebuild toplevel → `migrate-forgejo-subvol.sh prepare` + `finalize` (quiet-IO window) → I flip `dedicatedSubvolume = true` → deploy → verify (mount live, 2 consecutive 8h sends, Gatus green, drill OK). Everything is code-complete, nothing is live.                    |
| 2 | **Plan F05**                                      | "Enable option in configuration.nix" — deliberately NOT done (enablement is gated on G1 by design); the plan's wording ("ship inert first") was ambiguous and should have been written as "enablement happens AT gate F23".                                                                                 |
| 3 | **Report-back tables**                            | Medium table delivered in full; fine table delivered grouped/abbreviated in chat (full text in the plan doc) — acceptable, but the chat version omitted est/dep columns per-row.                                                                                                                            |
| 4 | **M08 overlap discovery**                         | Mid-session I noticed the parallel session already shipped `system_forgejo_mirror_sync_stalled` (fleet-level). My plan's M07 (per-repo dead candidates) remains valuable but the plan doc does NOT acknowledge the overlap — M07 should read "complements the fleet-stall metric with per-repo divergence". |
| 5 | **Runbook extensions (F10 partial)**              | The migration script carries its own runbook-as-header; `docs/services/forgejo.md` not yet extended with the subvol/flip/drill/shim sections (planned M19/F73 — not started this session by design, listed here for honesty because the script header is not a substitute).                                 |
| 6 | **Pre-deploy §10 awareness**                      | New metrics (`forgejo_subvol_backup_*`) will be auto-loaned by the auto-derived mechanism (verified reading the AGENTS §10 notes) — but I did not RUN the pre-deploy check against the new config; first real deploy will prove it.                                                                         |
| 7 | **The 5 open questions from the goal discussion** | Only the staged-approach question was answered (implicitly). GitHub-issues post-flip policy, off-LAN, public-repo scope, backup shape, both-ways priority → all parked in the plan's owner-decision packet (M18). Not lost, but also not answered.                                                          |
| 8 | **Annotating the 2026-08-31 plan**                | The new plan doc says "supersedes" and explains the stale premise; the OLD plan file itself carries no pointer back (that's plan F76, not started — should ideally have landed with the plan commit).                                                                                                       |

## c) NOT STARTED (from this session's plan; nothing outside it)

- **G1 gate steps** (owner: F21–F24) — see b1.
- **M17** size measurement + growth projection (needs sudo).
- **P1 capability**: M05 push-mirror rebuild (`canonicalRepos`, interval fix, clobber-refuse), M06 `forgejo-flip-repo` (delete-mirror → full re-migrate → push mirror), M07 dead-mirror collector, M08 live census.
- **P2 pilot**: M09 insteadOf shim + stray audit, M10 pilot flip E2E, G3 burn-in.
- **P3 rollout**: M11 batches + GitHub branch-protection seatbelts.
- **P4 CI/Renovate**: M12–M15 (4 workflow ports, `DEFAULT_ACTIONS_URL`, retention, migrations allowlist, Renovate, backup tightening).
- **P5 end-state**: M16 VM test, M18 owner packet, M19 docs/AGENTS/TODO sync + harvest, M20 Codeberg + 3 upstream filings, M21 hygiene, M22 both-ways R&D, M23 watchlist (v17.0 2026-10-15, LTS memo, ForgeFed).
- New self-identified gaps (see e/f): fixture test for the migration script, dump-zip layout verification, calendar-string parse validation, F19 plan-doc sync.

## d) TOTALLY FUCKED UP (all self-caught; none reached origin in broken form)

| # | What                                                                                                                                                                                                          | Root cause                                                                                                                                                                                                                                                              | Lesson                                                                                                                                                                                                                                                                 |
| - | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Wrong storage recommendation first** (Set C: +C, no snapshots, dump-only)                                                                                                                                   | Calibrated to the DISPOSABLE-mirror posture before asking what the service was FOR; the user's goal statement invalidated it within two turns                                                                                                                           | For storage doctrine picks, the service's ROLE is the first question, not an assumption — I asked it only after recommending                                                                                                                                           |
| 2 | **Nix duplicate-path eval failure** (`systemd.services = lib.optionalAttrs …` colliding with the nested block)                                                                                                | Re-opening an already-defined attrset level from a second assignment in the same module — the exact class the file structure already encodes against                                                                                                                    | Read the file's OWN idiom (all units defined once, nested or flat) before adding a new shape; one failed eval round-trip burned                                                                                                                                        |
| 3 | **mkEnableOption shape assumed wrong** (`.enable` on a boolean)                                                                                                                                               | Assumed submodule shape without checking; second wasted eval round                                                                                                                                                                                                      | mkEnableOption IS the boolean; `extendModules` probes caught both this and #2 immediately — the throwaway-eval pattern is what kept these cheap                                                                                                                        |
| 4 | **Dead `emit()` function shipped into an intermediate edit** of the collector script                                                                                                                          | First-draft sloppiness; caught on self-review before commit                                                                                                                                                                                                             | Review your own diff for dead code BEFORE eval, not after                                                                                                                                                                                                              |
| 5 | **Daemon commit races ×3** — my `git commit` lost to the auto-commit daemon three times in a row (17:01, 17:13, 17:17), including one mid-chain `reset --soft` + `commit` split that the daemon landed inside | I re-ran the SAME two-step pattern (stage, then commit) after the first race instead of adapting; the AGENTS rule ("re-check `git status` immediately before `git add`") was followed in letter, not adapted in spirit                                                  | With this daemon: prefer SINGLE-command `git add <path> && git commit -m … -- <path>` chains, and when beaten, verify `git show --stat HEAD` then `--amend` — the amend-on-daemon-tip path worked flawlessly all three times; the reset-dance was the avoidable detour |
| 6 | **Restore drill's dump-zip layout is UNVERIFIED**                                                                                                                                                             | I wrote repo-discovery (`find -name objects` + refs check) and DB-rebuild (`*db*.sql`) logic against an ASSUMED forgejo-dump zip layout — never inspected a real dump (pool backups are 0750 forgejo-owned, unreadable from lars) nor the forgejo source for the layout | The drill fails LOUD on a wrong assumption (safe direction), but the first Sunday run could false-FAIL; assumption-based verification logic must be labeled unverified until first live run — I only labeled it in my head                                             |
| 7 | **Plan doc drifted from implementation** (F19 still says "metric+Gatus"; shipped onFailure+monitoredServices)                                                                                                 | Deviated deliberately during M04 but did not circle back to the plan file in the same session                                                                                                                                                                           | The plan is the durable artifact; deviations update the plan in the same breath as the code, or the next session trusts a stale F19                                                                                                                                    |
| 8 | **Migration script has NO fixture test** — `bash -n` syntax check only                                                                                                                                        | Time/context pressure at the end of the M02 batch; the parallel session fixture-tested THEIR forgejo scripts the same day — I did not match the bar the repo just set                                                                                                   | `scripts/migrate-forgejo-subvol.sh` guards real data movement; its guard branches (refuse-without-prepare, refuse-while-active, verify-then-swap) are exactly the logic a stubbed rsync/systemctl fixture should prove                                                 |

## e) WHAT WE SHOULD IMPROVE

1. **Ask "what is this service FOR" before doctrine picks** — d1's general rule; the whole Set-C→Set-B detour was avoidable.
2. **Atomic-commit discipline vs the daemon** — single-command chains; amend-on-verified-daemon-tip as the standard recovery; never a multi-command git dance on a shared tree (d5).
3. **Label unverified assumptions in the artifact, not the mind** — dump layout (d6), comma-hour calendar parsing (eval'd the string renders, never `systemd-analyze calendar '*-*-* 05,13,21:40:00'`), rsync `-HAX` behavior on the subvol: all currently "believed correct, not proven".
4. **Match the repo's fixture-test bar for anything that moves data** — migration script, restore drill (both currently eval/syntax-verified only). The PATH-sed stub pattern is established here.
5. **Plan-doc sync in the same commit as the deviation** (d7) — or a standing rule that F-rows carry status stamps.
6. **Inline nix scripts bypass shellcheck** (repo-wide class): the collector + drill scripts live inside forgejo.nix — no shellcheck coverage. Either extract to `scripts/` or accept + document the gap; the parallel session's scripts are standalone writeShellApplications (checked at build).
7. **Read the live system where cheap** — I never confirmed the Samsung's free space for the forgejo subvol (needs sudo; folded into M17) and never ran `btrbk dryrun` (the plan's F16 says to, but the instance is gated off — the dryrun can only happen post-G1; should have said so explicitly in F16).
8. **Chat-report fidelity** — the fine table in chat dropped columns "to keep it readable"; the user asked for the tables, the doc has them, but the chat version was lossy. Own the full table or point at the doc loudly.

## f) Up to 50 things we should get done next

**Gate G1 (owner-coupled — the critical path):**

| #  | Task                                                                                                                  | Impact | Effort |
| -- | --------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 1  | Owner: `nix run .#deploy` (ship Phase-0 inert batch)                                                                  | High   | S      |
| 2  | Owner: prebuild toplevel in a quiet-IO window (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`) | High   | S      |
| 3  | Owner: `sudo ./scripts/migrate-forgejo-subvol.sh prepare`                                                             | High   | S      |
| 4  | Owner: `sudo ./scripts/migrate-forgejo-subvol.sh finalize --dry-run` then real `finalize`                             | High   | S      |
| 5  | Me: flip `services.forgejo.dedicatedSubvolume = true` on your go                                                      | High   | S      |
| 6  | Owner: deploy; verify mount + forgejo healthy + mirrors syncing                                                       | High   | S      |
| 7  | Verify 2 consecutive 8h btrbk receives pool-side + freshness Gatus green                                              | High   | S      |
| 8  | First restore-drill run (or `systemctl start forgejo-restore-drill`) — proves/fixes the d6 zip-layout assumption      | High   | S      |
| 9  | `sudo -u forgejo du -sh /var/lib/forgejo` (M17) + pool growth projection                                              | Med    | S      |
| 10 | Burn-in window (≥24h): watch subvol backup + mirror sync + no IO-storm interaction with the 8h sends                  | High   | —      |

**Session-quality debts (from d/e — do these before M05):**

| #  | Task                                                                                              | Impact | Effort |
| -- | ------------------------------------------------------------------------------------------------- | ------ | ------ |
| 11 | Fixture-test `migrate-forgejo-subvol.sh` guard branches (stubbed rsync/systemctl/btrfs)           | High   | M      |
| 12 | `systemd-analyze calendar '*-*-* 05,13,21:40:00'` — prove the comma-hour parse                    | Med    | S      |
| 13 | Verify forgejo dump zip layout (forgejo source or first drill run) + fix drill discovery if wrong | High   | S      |
| 14 | Sync plan doc F19 (+F05 wording, M07 overlap note, F16 dryrun-timing note)                        | Med    | S      |
| 15 | Annotate the 2026-08-31 plan with the supersede pointer (F76)                                     | Low    | S      |
| 16 | Extract collector/drill scripts or document the shellcheck gap                                    | Low    | S      |

**Phase 1 — Capability (after G1):**

| #  | Task                                                                                                     | Impact | Effort |
| -- | -------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 17 | M05: `canonicalRepos` option + `forgejo-push-mirror` script (interval "8h", clobber-refuse)              | High   | M      |
| 18 | M05: fold as phase-3 of `forgejo-github-sync`, fixture-tested                                            | High   | M      |
| 19 | M06: `forgejo-flip-repo` — preconditions + dry-run                                                       | High   | M      |
| 20 | M06: delete-mirror → full re-migrate (issues/PRs/labels/milestones/releases/wiki) → push mirror → verify | High   | L      |
| 21 | M06: fixtures incl. mid-flip failure recovery                                                            | High   | M      |
| 22 | M06: lossiness notes (reactions/reviews/cross-refs) → runbook                                            | Med    | S      |
| 23 | M07: per-repo dead-mirror collector (updated_at divergence, complements fleet-stall) + Gatus             | High   | M      |
| 24 | M08: live-forge census (native/mirror split, runner, workflows, LFS) → runbook                           | Med    | S      |
| 25 | G2: deploy P1 batch + live push-mirror POST 201 proof                                                    | High   | S      |

**Phase 2 — Pilot:**

| #  | Task                                                                        | Impact | Effort |
| -- | --------------------------------------------------------------------------- | ------ | ------ |
| 26 | M09: `forgejo-remote-audit.sh` + run on evo-x2                              | High   | S      |
| 27 | M09: insteadOf shim behind flag (HM, nixos + darwin) — enable ONLY at pilot | High   | M      |
| 28 | M09: audit on Lars-MacBook-Air                                              | Med    | S      |
| 29 | M10: pilot repo native + push mirror + GitHub receive verified              | High   | S      |
| 30 | M10: sync_on_commit + force-push probe + nix `github:` input resolution     | High   | S      |
| 31 | G3: one full 6h/8h cycle burn-in green                                      | High   | —      |

**Phase 3/4 — Rollout + CI (post-G3):**

| #  | Task                                                                                                    | Impact | Effort |
| -- | ------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 32 | M11: batch definitions (private-low-value → private-core → SystemNix/cv → public)                       | High   | S      |
| 33 | M11: per-batch executor runbook with burn-in gates                                                      | High   | M      |
| 34 | M11: GitHub branch-protection seatbelt design (bypass for sync PAT)                                     | High   | M      |
| 35 | M11: apply seatbelts per flipped batch                                                                  | Med    | S      |
| 36 | M12: port `nix-check.yml` → `.forgejo/workflows/` (dual-run)                                            | High   | L      |
| 37 | M12: runner secrets strategy (deploy keys on host runner)                                               | High   | M      |
| 38 | M13: port remaining 3 workflows; image-updates needs Forgejo-API issue creation                         | Med    | M      |
| 39 | M13: `DEFAULT_ACTIONS_URL` → `data.forgejo.org` + verify the 3 live workflows                           | Med    | S      |
| 40 | M13: `LOG/ARTIFACT_RETENTION_DAYS=30`; `[migrations] ALLOWED_DOMAINS=github.com`                        | Med    | S      |
| 41 | M14: self-hosted Renovate (`platform=forgejo`, sops PAT, native-repo allowlist)                         | Med    | L      |
| 42 | M15: registry maxAge re-check; dump retention decision post-M17; offsite pointer into Hetzner/Borg TODO | Med    | S      |

**Phase 5 — End-state + hygiene:**

| #  | Task                                                                                                                                                                                                                                                               | Impact | Effort |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------ |
| 43 | M16: `tests/test-forgejo.nix` VM test + script fixtures                                                                                                                                                                                                            | Med    | L      |
| 44 | M18: owner-decision packet (7 decisions, one table)                                                                                                                                                                                                                | Med    | S      |
| 45 | M19: runbook + AGENTS.md + TODO_LIST harvest from the plan                                                                                                                                                                                                         | Med    | M      |
| 46 | M20: Codeberg account + file the 3 verified mirror issues (Tier-1 post-flip)                                                                                                                                                                                       | Med    | S      |
| 47 | M21: repo-scoped token re-issues; forgejo doctor dry-run; starred-reconcile design; commit-graph.lock cleanup                                                                                                                                                      | Low    | M      |
| 48 | M22: both-ways R&D — webhook inventory, identity mapping, loop suppression, build/no-build verdict (post-rollout)                                                                                                                                                  | Med    | L      |
| 49 | M23: v17.0 release-notes read (mirror-redirect impact on 385 mirrors, 2026-10-15) + LTS-jump memo                                                                                                                                                                  | Med    | S      |
| 50 | Re-check: does `git push` from THIS session's commits trip anything in the pending history-purge runbook? (verified clean — gitleaks green ×3 — but the push-time re-filter checklist should be re-read before ANY purge flip; parked as a reminder, not a defect) | Low    | S      |

## g) Questions I can NOT figure out myself

1. **When is the G1 migration window?** The finalize step takes forgejo DOWN for minutes (delta rsync + swap), must ride a quiet-IO window (chronic IO storms noted by the parallel session), and needs you at the keyboard for the sudo steps + the deploy. Tell me the window and I'll stage the option flip + verification checklist to match.
2. **GitHub Issues/PRs after the flip — freeze or keep-live?** (unanswered from the goal discussion): freeze read-only (my recommendation — one-time import at flip, GitHub issues become an archive) vs. keep GitHub issues open for strangers + one-way import timer. This gates M06's import design and M11's per-batch policy.
3. **Off-LAN stance reconfirm:** 2026-08-31 decision #1 says LAN-only, deliberate — but "Forgejo is my primary" makes "cannot push when not home" a weekly-ish reality. Confirm LAN-only (VPN later if it hurts) or reprioritize remote access now? Gates whether any VPN/Tailscale work enters the plan.

---

**Evidence trail:** origin log `e4aa99ff` / `82b03d88` / `4e7b61fc` (all pre-commit-suite green); extendModules eval outputs (mount options `subvol=hot/forgejo …`, timer `*-*-* 05,13,21:40:00`, gates, 4 registry checks); baseline inertness evals (`fileSystems ? …` = false); `nix flake check --no-build` green ×3; plan doc at `docs/planning/2026-09-18_16-44_FORGEJO-PRIMARY-STAGED-FOUNDATION.md`.

**Next:** WAITING FOR INSTRUCTIONS — the critical path is owner gate G1 (f1–f8); everything after is sequenced in the plan.
