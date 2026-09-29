# Memory Guard 4 Fixes Implemented: Backup-Starvation Catch-Up Slot, Log Dedup, Trip Attribution

**Session:** 2026-09-28 18:04 → 2026-09-29 01:45 CEST (single session, resumed from the 2026-09-18 20:16 handoff)
**Scope:** live-state re-verification of the 10-day-stale handoff + implementation of the guard's 4 outstanding fixes. No other areas touched.

---

## What I forgot / could have done better (self-critique)

1. **Eval-green lied to me once.** My first verification was `nix eval` only — it passed while the build was BROKEN (shellcheck SC2034: unused `BACKUP_CATCHUP_RESUME_PERCENT` shell var; the awk used the nix literal instead). Caught only because `writeShellApplication` runs shellcheck at BUILD time. Re-learn of the documented "eval-green ≠ build-green" class, this time on the shellcheck axis, not FOD.
2. **Two documented build traps re-hit** before the working invocation: `getFlake` on the unlocked local ref needs `--impure`; ExecStart-as-string hits the "context with output 'out'" error whose message names the `.drv` to build directly. Both procedures are in AGENTS.md — I should have gone straight to the documented forms.
3. **Interim messaging listed mount-options as an open fix** ("implementing next") before reading `hardware-configuration.nix:76-77` — where the DELIBERATE no-commit=300-on-TLC decision is documented. Read before classifying.
4. **Todos tool not kept current** during execution.
5. **No `nix fmt` run yet** on the edited module.
6. **VM test not extended, not run** — the trip/churn state machine changes are exactly the class the VM test exists for; "implemented + builds" is weaker than "behavior-verified".

## Live state observed this session (all probes 2026-09-28 ~18:04-18:20 unless noted)

- **IO storm ACTIVE at session start**: io PSI some avg10=58.2 / avg60=59.5; load 4.7/13.6/16.7 (falling); **memory healthy the whole time** (79 Gi avail, memory PSI ~0) — pure Zone-6 class.
- **Guard at trip #1360**, 105 trips that day alone; flm socket down, restore capped earlier (3/day spent). Newest forensics bundle written 2 min before probe (1263 bundles total).
- **Storm drivers** (bundle `20260928T160234Z` + ps): `system-btrfs-scrub.slice` **5.9 TB** cumulative since boot (the weekly scrub ran for hours, died 02:27 exit 1 after printing "no errors found"; units `btrfs-scrub@-.service`/`btrfs-scrub@data.service` now FAILED and listed by service-health every run), fish session 844 GB, nix-daemon 426 GB, clickhouse 103 GB; live at probe: a `nix` build at 96% CPU + several crush sessions.
- **Backups starved 3 nights**: pool receives stop at `@.20260925T2300` (+`@home-hermes-…0925`); `btrbk-root` was guard-killed Sep 26 23:01:22 and Sep 27 23:00:13 (trip #1252, **13 s into the send**, mid `btrfs receive`). **Zero churn re-arms overnight** — avg60 never dropped below the 40% re-arm bar. Root cause of starvation confirmed: the re-arm gate is unreachable during multi-day storms, and each night's 23:00 timer start dies to the next trip action.
- **llama-rag RESURRECTED by hermes cron**: both llama-server 0.3.0 instances (:8848 embeddings, :8849 reranker) running since Sep 28 05:40, cgroup `hermes-worker-cron-*.scope` — while the repo has `llama-rag.enable = false` (configuration.nix:775). NEW resurrection vector (agent cron, not a parallel session's config edit). The 2026-09-18 portGuard only runs at unit start — disabled units never start, so it cannot see this.
- **Deployed state**: system-799, `current-system == profile` (anchored). flake.nix carries a **parallel session's uncommitted** Linux-gating apps refactor (dated 2026-09-28) — untouched by me.
- **Handoff step 8 (commit=300 on /nix + /mnt/hot) is MOOT**: hardware-configuration.nix documents the deliberate 30s default on TLC (line 76-77); /data and /mnt/pool carry commit=300 as intended.

## a) FULLY DONE

1. **Live-state re-verification** of the 10-day-stale handoff (PSI, trips, pool receives, generations, llama procs, btrbk journals, forensics bundle, scrub state, mount options) — every claim above probe-backed.
2. **Handoff reconciliation**: guard fixes = still open (now done); backup-seed handoff = OBSOLETE (hermes receives landed Sep 18; problem inverted to guard-kill starvation); verify-gate WARN posture, 0.4.0-vs-0.3.0 discrepancy, oomd-hermes attribution, reboot-window question = all moot/superseded by the 10 days of landed work documented in AGENTS.md; mount-options = moot (deliberate TLC decision).
3. **Guard module read IN FULL** (884 lines) + full VM test read — the mandatory pre-edit step that was skipped in 3 prior sessions.
4. **All 4 standing-directive fixes IMPLEMENTED** in `modules/nixos/services/memory-emergency-guard.nix` (12-edit multiedit):
   - **(i) Starved-backup catch-up slot** (inverted from the handoff sketch, per live evidence): new `backupUnits` (4 btrbk units), `backupStarvationSeconds` (6h), `backupCatchupResumePercent` (50 — deliberately ABOVE the 40 re-arm bar: backups may resume into a mild storm, never the extreme band), `backupCatchupProtectSeconds` (900s). Trip actions skip protected backup units; every real backup stop (re)writes `backup-stopped.epoch` (survives churn-file rewrites that drop inactive units — a state-tracking fragility found while designing); grant starts the units once avg60 < 50, clears the epoch, prunes them from the churn window; full re-arm clears the epoch too. Slot repeats at most once per starvation window.
   - **(ii) Starvation metrics**: `memory_emergency_guard_backup_starved`, `_backup_catchup_protected`, `_backup_catchup_slots_total` (all always-emitted, fail-closed by freshness).
   - **(iii) Log dedup**: `should_log_verbose` heartbeat (`verboseLogIntervalSeconds` 600) gates the cooldown-active and restore-capped steady-state lines (live evidence: restore-capped spammed every 30 s, 22:58-23:00 Sep 27). Action/transition lines always log.
   - **(iv) Trip-line offender attribution**: at trip actions only (zero steady-state cost), bounded+timeout-bounded per-cgroup `io.stat` walk (maxdepth 4, root cgroup excluded — forensics-script pattern), snapshotted in `cgroup-io.last`, top-3 delta appended to the "action taken" line ("top io since last trip: …"). `CGROUP_IO_SRC` env-overridable for the VM test.
5. **Verification (partial but real)**: scoped eval green; **script derivation builds** (writeShellApplication shellcheck PASS after fixing SC2034); `bash -n` PASS; all three fix surfaces confirmed present in the built artifact.

## b) PARTIALLY DONE

- **Guard fix verification**: build + syntax + shellcheck done; **VM regression test NOT extended/run** (scenarios designed: starvation→grant, slot-protection through a trip action, attribution from a fixture `CGROUP_IO_SRC`; needs a dummy `btrbk-root` unit + reset_state extension).
- **Monitoring wiring for the new metric**: Gatus check "Memory Guard Backup Starved" (anchored VALUE-0 pat on node-exporter, niri pattern) planned, not inserted.
- **Docs**: runbook `docs/services/memory-emergency-guard.md` + AGENTS.md Zone-6 paragraph updates pending.

## c) NOT STARTED (this session's scope, deliberately or not)

- Deploy of the guard fix (user-run; deploy gate likely blocks at PSI ≥20% — rc=12 semantics).
- sev1-escalation notify-tier wiring for `backup_starved` (deliberately deferred: unread module, Gatus+Discord covers paging).
- Resurrection detector (port-holder probe for config-disabled module ports) — designed in-hand, not built.
- TODO_LIST/docs/todo harvest of this report's follow-ups (deliberately deferred: user scoped this session to reporting; see h).
- Killing / legitimizing the hermes-spawned llama-servers (sudo-blocked for me; user decision).

## d) TOTALLY FUCKED UP

- Nothing destroyed. One self-inflicted-and-fixed breakage: the SC2034 unused-var that broke the script BUILD while eval stayed green (see self-critique #1). No config regressions; module still undeployed, so prod is untouched by my edits.

## e) WHAT WE SHOULD IMPROVE

1. **Build-verify shell scripts at write time, not eval time** — the repo lesson ("raw systemd script strings are NOT linted — bash -n the extracted text") now extends to writeShellApplication modules: eval alone passed a broken script.
2. **The guard's churn-stop may be a PHANTOM for scrubs**: `systemctl stop` on `btrfs-scrub@*` kills the CLI, but only `btrfs scrub cancel` stops the kernel-side scrub — the 5.9 TB continued for hours after trip stops. Needs verification + fix (cancel, not just stop).
3. **Scrub scheduling vs multi-day storms**: the weekly scrub fired into/through the Sep 26-28 storm; its deferral gate only guards START. Consider a duration watchdog or higher deferral bar.
4. **Resurrection detection is still reactive** — two independent incidents now (parallel session Sep 18, hermes cron Sep 28). A cheap port-holder probe metric would close the class.
5. **Handoff freshness**: this session began from a 10-day-stale handoff; ~60% of it was moot. Handoffs should lead with "verify against AGENTS.md changelog first".

## f) NEXT (ranked, this session's scope only)

1. Gatus check "Memory Guard Backup Starved" (Monitoring group, niri-pattern anchored pat).
2. Extend `tests/test-memory-emergency-guard.nix`: dummy `btrbk-root` unit; reset_state += 6 new state files; scenario 9 (starve epoch 7h + io avg60=45 → grant, prune, metrics), 9b (trip action during slot keeps btrbk-root running, balance re-stopped, cooldown-line dedup asserted), 9c (attribution from `CGROUP_IO_SRC=/tmp/cgt` fixture + seeded snapshot).
3. Run the VM test (quiet window or `heavy-job`; NOT during an active storm).
4. `nix fmt --no-update-lock-file -- modules/nixos/services/memory-emergency-guard.nix tests/test-memory-emergency-guard.nix`.
5. Runbook + AGENTS.md sentence for the catch-up slot.
6. Deploy (user-run); then verify `memory_emergency_guard_backup_starved` appears and watch the first grant.
7. Tonight's 23:00 btrbk-root outcome with the fix live (first catch-up candidate if avg60 < 50).
8. Verify pool receives land (`@.20260926T2300+` catch-up chain, ~3 incrementals).
9. User decision: kill the hermes llama-servers (`sudo systemctl stop`… they live in a cron scope — `sudo pkill -f 'llama-server.*884'` as the user-run verb) or re-enable llama-rag legitimately.
10. Identify the spawning hermes cron job (needs sudo/user: hermes state 2770).
11. Investigate scrub-stop phantom (e) #2 — maybe make the guard run `btrfs scrub cancel` for scrub units.
12. Root-cause `btrfs-scrub@-/@data` FAILED state (exit 1 after "no errors found") + clear; exit-4 hazard check before next unit churn.
13. sev1 notify-tier for backup_starved.
14. Resurrection detector (port-holder metric + Gatus).
15. /mnt/hot one-line "commit stays default (TLC)" comment for symmetry.
16. Post-mortem the Sep 26-28 storm drivers once quiet (scrub + sessions + nix).
17. Harvest items 1-16 into TODO_LIST.md + docs/todo/{stability,monitoring}.md.
18. Coordinate flake.nix working-tree state with the parallel session before any commit-sensitive step.
19. Watch the first real attribution line in the guard journal post-deploy; sanity-check its top-3 against a forensics bundle.
20. Check the attribution walk's real cost at trip time on the host (maxdepth-4 cgroup tree, timeout 10).

## g) QUESTIONS (cannot resolve myself)

1. **The hermes-cron llama-servers**: kill them and teach hermes not to spawn module services, or treat them as legitimate and re-enable `llama-rag` (they are the proven 0.3.0 pinned builds and are currently, accidentally, serving paperless-ai's embedding env)? Killing is user-run sudo.
2. **Deploy timing for the guard fix**: deploy now/today via a quiet window (or `DEPLOY_FORCE_PRESSURE=1` given memory is healthy and the storm is IO-only), or hold until the multi-day storm fully drains?
3. **Catch-up slot policy defaults** (starve 6h / resume bar avg60<50 / protect 15 min): these deliberately resume backups INTO a mild storm — accept, or tighten (e.g. 45%/10 min) / loosen?

## h) Deliberately not harvested

Per the TODO-system doctrine this report's §f should be harvested into `TODO_LIST.md` + the domain libraries at authoring time; deferred because the user explicitly scoped this session to reporting ("DO NOT RESEARCH OTHER STUFF… THEN WAIT FOR INSTRUCTIONS"). Say the word and the harvest lands.
