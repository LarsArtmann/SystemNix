# Master-Plan P2 Execution Continuation — Scrub Staleness Landed Unverified, Fleet Sweep Clean

**Session**: 2026-10-01 ~12:00–13:41 CEST (continuation of the 07-22 master-plan execution session)
**Plan**: `docs/planning/2026-09-30_09-30_two-day-todo-master-plan.html` (61 agent quick wins + owner-gated chains)
**Prior session report**: `docs/status/2026-10-01_07-22_master-plan-execution-p1-p2-session.md` (P1a–d terminal, P2 #6 done, #7 started; 3 owner questions pending)

---

## a) FULLY DONE (this session, verified)

1. **Dangling report citations fixed** (the "CRITICAL inconsistency" from the handoff). All 4 sites citing the never-created `2026-10-01_03-40_master-plan-execution-session.md` now cite the real `2026-10-01_07-22_master-plan-execution-p1-p2-session.md` (`TODO_LIST.md` rows 303–304, `docs/todo/pipeline.md` entries 226–227). The *legitimate* `2026-09-13_03-40` citation at pipeline.md:95 was deliberately untouched. `check-todo-system.sh` green after (WARN-grade standing backlogs only: 63 pairing drifts, 60 unharvested — grew from 53 because parallel sessions keep writing §f reports).
2. **Shellcheck on `scripts/negative-test-lints.sh`** (the prior session's unverified edit): clean.
3. **P2 #7 — SuccessExitStatus fleet sweep: COMPLETE, verdict CLEAN.** Systematic pass over every non-zero exit in repo oneshots (`grep -rn 'exit [123]' modules/ platforms/`, then per-candidate judgment): every one is **fail-loud-on-abnormal by design** — scrubGuard defers and placeholder skips (discordsync-immich-verify, architecture-catalog) already `exit 0`; cv-scan 503 is warn-only; verify-* WARNING+exit-1 paths trip only on abnormal states; `btrbk-data`'s deliberate fail is the owner-decided standing tripwire; `lan-nic-watchdog`/`hermes-github-verify`/attic/paperless/signoz/caddy exits are genuine alert paths; the hermes `exit 1` in `hermes-git-credential` is **git credential-helper protocol** ("no credential" → anonymous fallback), not a systemd unit exit — out of scope. **Zero new SuccessExitStatus declarations needed**; the only instance of the btrfs-scrub@ class was nixpkgs-internal (fixed in P1d).
4. **En-route real bug found + fixed: `btrfs-verify-snapshots`' @home-hermes gate was dead code.** It still probed `findmnt -n /home/hermes | grep -q '@home-hermes'` — **BLIND inside `harden {}`'s `ProtectHome=true` namespace** (phantom green since the 2026-09-15 hermes subvol era). The sibling `btrfs-verify-pool-backups` leg got the `systemctl is-active --quiet home-hermes.mount` fix on 2026-09-17 (AGENTS-documented incident); this leg never got it. Fixed to the sibling's proven form with an explanatory comment (snapshots.nix:869-878); rendered-script eval-verified (probe present in the unit's script). Landed via daemon sweep `b02d295c`, verified in tree post-sweep.
5. **CHANGELOG entry** for the session's gates (pairing/harvest lints + SCAN_TARGET latent fix + scrub timers + scrub-exit-contract + fleet-sweep verdict + the hermes-gate fix) — commit `eb4eca00`.
6. **Plan HTML annotated**: quick-wins rows 1–4, 6, 7 now carry `<span class="verdict">` dispositions (row 1: DISCHARGED-premise-falsified with evidence; rows 2,3,6,7: DONE with pointers; row 4: DONE-rides-deploy). Added a `.verdict` CSS class. `verify-html-diagrams.sh` PASS after. Commit `0a12995b`.
7. **`nix flake check --no-build` GREEN** at the session's midpoint — after healing a GC-evicted flake-input source (`storage-collector-prepared-source.drv` "is not valid", the documented 2026-09-26 environmental class; healed by evaluating the evo-x2 toplevel, which re-created the drv). Both my commits verified reachable post-parallel-session churn.

## b) PARTIALLY DONE (in-flight, disclosed honestly)

1. **P2 #5 — scrub-completion staleness: WRITTEN but the verification ladder is INCOMPLETE.** Landed (daemon sweep `abf5cda9`):
   - `btrfs-health.nix` collector: `btrfs_scrub_last_completed_seconds{mount}` (epoch of last FINISHED scrub's start; 0 = never/unknown), `btrfs_scrub_stale{mount}` (1 = no completion within a **10-day budget**: weekly cadence + storm-era grace; RUNNING counts as fresh — avoids the phantom-red the 2026-09-15 split fixed), `btrfs_scrub_staleness_parse_errors` (fail-loud on unparseable FINISHED dates). Labels slash-sanitized (`root`/`data`) because gatus `pat()` glob-vs-slash behavior is unproven (the only slash-pattern check — GCP receiver — sits containment-RED, so it proves nothing).
   - `gatus-config.nix`: new "BTRFS Scrub Staleness" check (anchored `\n` presence + not-stale conditions for both mounts + parse-errors, Discord alert with the Persistent=false context and the manual re-arm command).
   - **NOT yet done** (interrupted by this report request): `bash -n` on the extracted script; **fixture test** of the five logic branches (finished-old→stale 1, finished-fresh→0, running→0, never-started→1, unparseable→parse_errors 1); flake check after these edits (the writeShellApplication build shellcheck); the scrub-status **date-format assumption** ("`Scrub started:    Mon Sep 29 10:00:03 2026`") is unverified against the locked btrfs-progs — my user shell cannot run `btrfs scrub status` (root-only ioctl); a wrong format → parse_errors 1 → the new check reds on first deployed run (fail-loud, not phantom-green, but a page).
   - Minor unresolved: which systemd attr hosts the collector unit (found `ExecStart = lib.getExe btrfsHealthMetrics` at btrfs-health.nix:678 but didn't finish identifying the attr name for eval probes).
2. **P2 #6's todo-row status**: the handoff asked to mark #6 completed in todos — done in the tracking tool this session, but the plan HTML row 6 annotation (done, see a.6) is the durable record.

## c) NOT STARTED

- **P2 #8** eval-time stray-unit lint (@-template + systemd-instantiated allowlist)
- **P2 #9** guard per-zone `trips_last_hour` gauges
- **P2 #10** guard cooldown-disclosure journal line + ExecPrint churn-list drift check
- **P2 #11** deploy.sh race-detector WARN (HEAD moved <15min + first-activation unit in diff)
- **P3 items 12–61** — **CAVEAT: a parallel session closed "48 of 50" of a fifty-todos list** (commits `95164b03` batch G, `27ab9858` session-3 closeout, others) that overlaps the master plan's P3 pool. **A cross-check/dedupe pass is REQUIRED before executing any P3 item** — executing blind would duplicate freshly-landed work.

## d) TOTALLY FUCKED UP (self-caught, no damage)

1. **Nested-shell quoting bug**: my python heredoc inside `bash -c "..."` had its `\"` escapes eaten by the outer shell → wrote `class=verdict` (unquoted) into the plan HTML 6×. Caught immediately by my own grep-count verification, fixed in the next tool call. Lesson: **never put scripts >5 lines inside `bash -c` double quotes — use the write tool for script files**.
2. **False alarm on my own annotation**: the verification grep said 0 matches and I nearly diagnosed a parallel-session revert; it was (again) my quoting (`grep -c` counts LINES and the plan's table is one giant line). One wasted diagnostic cycle.
3. **Commit subject 74 chars → rejected** by the house 72-char commit-msg hook (working as designed — a prior session's gate catching me). Shortened; no damage.
4. **Daemon race #4/#5**: my pathspec commit `eb4eca00` landed only CHANGELOG.md because the daemon had swept the other 3 files into `b02d295c` seconds earlier; and the P2#5 edits were swept as `abf5cda9` **before I ran their verification ladder** — meaning unverified script text briefly became "landed" state on master. All content verified present post-sweep, but the ordering violated my own discipline (see e.2).

## e) WHAT WE SHOULD IMPROVE

1. **Script-file authoring discipline**: heredocs inside `bash -c` double quotes corrupt escapes. Rule: any script ≥5 lines goes through the `write` tool to a real file first.
2. **Never leave verification behind an edit in a daemon-swept tree**: the daemon commits within ~10 minutes, so "I'll verify right after the edit" is a race I lost this session. Either verify within the same tool-call window or don't make the edit.
3. **Fail-loud date-format risk in P2#5**: the collector parses a btrfs-progs human date I could not sample live (root-only). Improvement: fixture-test against the LOCKED nixpkgs btrfs-progs' actual output format before deploy (or have the deployed smoke capture root output).
4. **Unit-attr archaeology is slow in this repo** (multiple indirection layers between module option and systemd attr). An eval one-liner filtering `builtins.attrNames config.systemd.services` beats nested greps.
5. **Parallel-session coordination**: three active sessions (fifty-todos, agents-docs-durability session 4, this one) landed interleaved commits this window. The fifty-todos/master-plan overlap needs a dedupe artifact (a short crosswalk table) so the next executor doesn't re-close closed items.

## f) NEXT (ordered, realistic — the master plan's remaining pool after dedupe)

1. Finish P2#5 verification: `bash -n` extracted script + 5-branch fixture test + flake check (the edits are already on master — this is now a correctness debt, not optional)
2. Verify the "Scrub started:" format against the locked nixpkgs btrfs-progs (source or root-run capture) — protects parse_errors from a format-drift page
3. Identify the collector's unit attr (eval attrNames filter) for future probes
4. Run `nix build .#checks.x86_64-linux.gatus-pattern-lint`-equivalent flake check to confirm the new conditions pass the pat() trap scanner
5. P2 #8: eval-time stray-unit lint (warning-grade, @-template + systemd-instantiated allowlist)
6. P2 #9: guard per-zone trips_last_hour gauges
7. P2 #10: guard cooldown-disclosure journal line + churn-list drift check
8. P2 #11: deploy.sh race-detector WARN
9. **Crosswalk: fifty-todos 48/50 closures vs master-plan P3 12–61** (which P3 rows are already done? which remain?)
10. Annotate plan rows 5, 8–11 with verdicts as they land
11. P3 #12: pressure-gate 3×2s io_ticks multi-sample + corpse-pile wording
12. P3 #13: Gatus batch (stuck-jobs, sustained load, cacheSubvolume tripwire, failed-unit-count)
13. P3 #14: gatus flm-port audit + :1411 low-port pair root-cause
14. P3 #15: fastflowlm pre-bind port forensics ExecStartPre
15. P3 #16: fixture-test dns-update.sh
16. P3 #17: post-deploy smoke gatus-active assertion + retired-surface sweep
17. P3 #18: negative-test-lints gatus-config-parse mutation case
18. P3 #19: GCP hardening batch (test-signoz-gcp.nix + smoke + CHANGELOG)
19. P3 #20: ClickHouse fill-velocity gauge
20. P3 #21: signoz-collector-config-lint flake check
21. P3 #22: batch lock-free goModules staleness sweep across LarsArtmann inputs
22. P3 #23: PapDashboard flake bump (upstream 4c76f4f)
23. P3 #24: commit/stash CV TODO_LIST.md (tq deadlock)
24. P3 #25: browser-history 1c8f967..5f04c79 jump assessment
25. P3 #26: buildcache-init 3 fallback targets
26. P3 #27: single-source the 4 cache-reap inventories
27. P3 #28: heal-breadcrumb CONTRIBUTING wiring + SUDO_USER
28. P3 #29: geometryGuards-style eval assertions for subvol-mounting fileSystems
29. P3 #30: deploy-gate hook for un-migrated migrate-*.sh modules
30. P3 #32: ADR-008 catalog completion sweep (22–23 subdomains)
31. P3 #33: hot-db plan-doc T-task status pass
32. P3 #34: annotate stale reports (04-34, 09-25_05-33, 23-20)
33. P3 #36: document scrub exit contract 0/1/3 in runbooks
34. P3 #37: deploy.sh reset-failed template-instance coverage
35. P3 #38: guard 09:56-boot silence root-cause
36. P3 #39: backup-starvation audit Sep 27–29
37. P3 #40: execute never-executed VM-test checks (quiet window)
38. P3 #41: full flake check --all-systems (quiet window)
39. P3 #42: guard VM scenarios 9/9b/9c
40. P3 #43–46: crush-db batches A/B/C + tq-agent-pool 937 GB attribution
41. P3 #47–49: gatus rule reviews + /nix usage metric + queue hygiene
42. P3 #50–52: cite conventions + CI dark job + all-green sweep
43. P3 #53–55: FLM socket re-arm verify + dns-update re-run + guard cap doc
44. P3 #56–59: NetBird hardening + mint/TLS smoke + InboxClean docs + tag-demote root-cause
45. P3 #60–61: Docker NOCOW decision + Upholds= evaluation
46. Sweep the 63 pairing drifts + 60 unharvested reports (queued rows TODO_LIST 303/304 — large but mechanical)
47. Owner decisions from the plan's 18-decision table (each needs a verdict)
48. The 10 watch items from the plan (monitoring-only, no action unless triggered)
49. Re-run `nix flake check --no-build` after any further edits this session (the green in a.7 predates the P2#5 edits)

**Harvest note (self-harvest convention)**: §f items 1–8 are deliberately NOT newly queued — the master plan table (annotated this session) + the fifty-todos queue already track them; re-harvesting would duplicate rows while a parallel session is actively closing the same pool. Revisit after f.9's crosswalk lands.

## g) QUESTIONS (cannot figure out myself — all three carried from the 07-22 report, still unanswered)

1. **Deploy authority**: multiple landed items (P1d scrub timers, the hermes-gate fix, P2#5 once verified, plus parallel-session work like caddy-logs-hot and the agents-docs durability batch) ride `nix run .#deploy`. Should the agent fire deploys when gates are green and the box is calm (checking PSI/guard-trip recency per the rc=12 doctrine), or does every deploy stay owner-run?
2. **Gate hardness for the two new todo lints** (pairing + harvest, currently WARN with strict hatches): flip to strict-by-default NOW (blocks every commit until the 63+60 backlog drains) or only AFTER the backlogs are worked down?
3. **Attribution policy**: should agent-authored commits carry the Crush attribution footer, or is the session-report citation (as in `eb4eca00`/`0a12995b` → this report's predecessors) sufficient? The daemon frequently sweeps agent files into unattributed heuristic commits, making per-commit attribution inconsistent anyway.

---

**Session ledger**: commits `eb4eca00` (CHANGELOG), `0a12995b` (plan annotations); daemon-swept authorship: `b02d295c` (snapshots.nix hermes fix + citation fixes), `abf5cda9` (P2#5 collector + gatus edits, UNVERIFIED — see b.1). Tree clean at report time; both named commits reachable from HEAD through the parallel sessions' chains.

**WAITING FOR INSTRUCTIONS.**
