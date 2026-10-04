# Thermal-Pstate-Guard Implementation — Self-Review + Status (2026-10-04 06:39)

**Session scope:** the "monitor disk heat, flip amd_pstate performance↔guided on the fly" turn — full implementation of `thermal-pstate-guard` in tree. Companion reports: `05-22 freeze-14 autopsy` (this session, earlier turns) and `05-42 freeze-14 session self-review` (the a–g report covering the autopsy/report/plan turns; its missed-harvest items 5/6 are healed, see §a).

## LIVE STATE AT AUTHORING (read before anything else)

- **Load average 19.6 / 41.4 / 47.1** (1/5/15 min) — the highest sustained load recorded in any freeze report; IO PSI some avg60 56.3 %; Tctl 81.5 °C; **8 guard trips already on boot 0** (#1821→#1828 range).
- Boot 0 is at **exactly 1h30m uptime — the same duration boot -1 survived before freeze #14**. The box is re-running the death pattern: an unidentified heavy load class (same signature as the 05:07 nix burst — the driver-identification row is now URGENT, journal is warm NOW).
- The guard that would throttle this is **in tree but NOT deployed** — everything below protects nothing until the deploy lands (§b.1).

## a) FULLY DONE

1. **`scripts/thermal-pstate-guard.sh`** — the complete guard: 10 s tick, per-sensor hysteresis (k10temp 95/80, nvme 70/60, amdgpu 90/75, acpitz 85/70), 2-tick enter debounce, 12-tick exit dwell, governor/EPP snapshot+restore, external-override adoption, blind-sensor degradation, atomic textfile metrics (temps, throttled, trips/restores, freshness timestamp). Shellcheck clean; **20/20 selftest assertions pass** — directly AND built through nix (`checks.thermal-pstate-guard-selftest` built green).
2. **`modules/nixos/services/thermal-pstate-guard.nix`** — typed sensor submodule options, harden/serviceOneshotDefaults/onFailure wiring, oneshot+timer (memory-guard pattern), Environment contract for thresholds; auto-discovered; **enabled on evo-x2** (eval-verified: `enable=true`, timer `OnBootSec=1min/OnUnitActiveSec=10s`, all 6 Environment vars render).
3. **`platforms/nixos/system/boot.nix`** — `amd_pstate=performance` → `amd_pstate=active` with corrected comment ("performance" is not a documented driver mode; the driver ran `active` regardless — the performance governor/EPP is the actual pin).
4. **`flake.nix`** — selftest check added; **full `nix flake check --no-build` zero errors** — including the port-registry audit, which CAUGHT my first sensor-spec format (`k10temp:95:80` = colon-form port literals) and forced the honest fix (`name=high/low`). The prevention layer worked exactly as designed, mid-implementation.
5. **`docs/services/thermal-pstate-guard.md`** — runbook: state machine, incident class, behavior rules, verification drill, traps.
6. **Todo surfaces synced**: stability :110 (decision row — enforcement variant landed in tree), new `[blocked:deploy]` deploy row + nix-driver row note; monitoring :17 (wire gatus against the guard's new metrics); TODO_LIST both rows; `check-todo-system.sh` structure clean.
7. **Both missed harvests from the 05-42 report healed**: stability :103 (PSI-80 trigger live fact), desktop niri row (0-lines-both-boots note).
8. **Daemon-race discipline held**: new files `git add`ed BEFORE any evo-x2 eval (tracked-files trap avoided); the daemon's mid-turn heuristic commit (`721a7a29`) was detected via "modified since read", verified with `git log --stat`, and the edit re-applied cleanly.

## b) PARTIALLY DONE

1. **The protection itself is 0 % live.** In tree, deploy-gated. The box is at load 47 RIGHT NOW with no guard running. All verification was eval/selftest-level; not one real sysfs transition has ever executed on this hardware.
2. **Runtime-now mitigation was suggested, not executed**: the `echo guided | sudo tee …` owner leg from the 05-42 plan remains undone (owner-gated, unverifiable from here).
3. **Gatus/alerting wiring**: only the monitoring :17 row update — no check written, so even post-deploy the guard's data alerts nothing until that row runs.
4. **The guided-firmware bet is untested** (see §d.6) — a shadow-mode option that would de-risk it was conceived (§e.4) but not built.

## c) NOT STARTED

1. The deploy (blocked: cooling/storm gate) + post-deploy live-transition drill (runbook).
2. **VM-test parity** — memory-guard has `tests/test-memory-emergency-guard.nix`; mine relies on the fixture selftest through nix. Defensible (same env-override design, no systemd behavior under test beyond standard oneshot+timer) but not documented as a decision.
3. Nix-driver cgroup archaeology (queued since 05-22; now urgent — see Live).
4. Owner legs: cooling inspection, recovery-reader stops, runtime governor flip.
5. Threshold tuning against real thermal data (impossible pre-deploy).

## d) TOTALLY FUCKED UP (brutal)

1. **Four bugs in the first script write**: an unbalanced quote (line 290, cascading syntax error), permission-denied self-reinvocation (`env "$0"` without +x), an EXIT-trap unbound-variable under `set -u` (local invisible to trap), and an SC2034 unused var. Three fix iterations before green. bash -n and shellcheck would have caught two BEFORE any run — I ran selftest first, shellcheck only after (order reversed from optimal).
2. **I initially declared "20/20 PASS" reading the assertion lines while the process exited 1** — the trap bug printed its error AFTER "SELFTEST PASSED". I did catch it from the exit code, but the first glance at green "ok:" lines nearly swallowed a failing exit.
3. **Product logic bug found only while writing the test**: adoption-into-active restored the governor ONLY if a snapshot existed — a crash-mid-throttle adoption (exactly the freeze-series scenario!) would have left the box in guided-limp with no governor restore. Scenario 9 of the selftest forced the fix. This is TDD working, but the initial logic shipped in my head as "done" was wrong.
4. **Two edit-tool failures from my own tool interleaving** — I modified the script via bash `sed`, then the edit tool correctly refused ("modified since read"). Self-inflicted; the sed path was chosen for speed and cost a round trip each time.
5. **The selftest fixture itself was wrong twice** (90000 misread as "hot" vs the 95 threshold; a phantom "snapshot re-created" assumption) — caught by re-reading, not by the test.
6. **The core mechanism is an UNVERIFIED BET**: the entire guard assumes GMKtec firmware's `guided` policy actually backs off under heat. Nobody has ever observed guided behavior under the current cooling deficit (guided ran pre-2026-05-11, before the deficit developed). If firmware-guided is as dumb as the fan control, the guard flips modes and the box dies anyway. The runbook says so; the design does not mitigate it (no shadow mode, no auto-revert-on-inefficacy).
7. **"Disk heat" is request-faithful but mechanically weak**: nvme thresholds are monitored, yet switching CPU pstate barely cools disks (their heat is IO-driven; stopping IO is the memory guard's job). Honest framing: the nvme trigger mostly protects against package/ambient coupling, not disk self-heating.

## e) WHAT WE SHOULD IMPROVE

1. **Verify cheaply, then verify expensively, in that order**: shellcheck/bash -n before selftest before nix-build before eval before deploy. This turn inverted the first two steps.
2. **Shadow/dry-run mode for first deployment of any actuator**: log the transition it WOULD make, flip nothing — one module option + one script branch. Post-deploy, compare shadow decisions against real thermal data, THEN arm. Directly de-risks §d.6.
3. **Read exit codes before reading output**: green text with a failing exit code is still a failure (§d.2). The house lesson "assert WHICH question your evidence answers" applies to tool output too.
4. **The alerting half is still missing after five thermal crashes** — with the guard's .prom series one gatus-config edit away (eval-checkable, same deploy). Highest value-per-line in the repo right now.
5. **Load-47 with no attribution** — the death-minute nix-burst class is happening AGAIN at report time and we still cannot name the process family. The archaeology window (boot 0 journal) is warm now; every hour of delay is evidence decay.

## f) NEXT (impact-ordered, ≤50 — 25 real)

1. **Owner: cooling inspection** (stability :117 — unchanged critical path, 4 days, 7 freezes)
2. **Owner: runtime `echo guided > /sys/devices/system/cpu/amd_pstate/status` NOW** — unguarded at load 47
3. **Owner: stop recovery readers** (crush-hot-db-migrate + discordsync-db-heal; PSI trigger long past)
4. **Add shadow/dry-run mode to thermal-pstate-guard before first deploy** (§e.2)
5. **Deploy the staged batch** (guard + param + gatus wiring) first calm window
6. **Post-deploy: runbook live-transition drill** both directions + threshold tuning from real data
7. **Wire gatus**: freshness on `…_last_run_timestamp_seconds` + sustained-Tctl alert on `…_sensor_celsius` (monitoring :17)
8. **Nix-driver archaeology on boot -1 AND boot 0** (live recurrence — the burst class is active NOW)
9. Validate the guided-firmware bet: first live transition observation (does Tctl actually fall in guided?)
10. crash-autopsy.sh (6 manual passes paid; add the own-config-accelerant + sensors-first legs)
11. IO admission decision (tq pool + build slices — owner throughput call)
12. Guard trip-counter persist-before-log (VM-gated)
13. io-psi-forensics bundle retention + durability
14. SEV1 live-vs-latched triage (stability :100)
15. kdump /var/crash provisioning (:106)
16. pstore reads post-#13/#14 (owner root)
17. Thermal-series forensics freeze-14 boot -1 (guided-impact baseline)
18. tq fleet budget reset-per-boot check (crash-loop-feeding-fleet hypothesis)
19. Add load average to guard trip-log line (:108)
20. Fold freeze #8–#14 taxonomy into docs/agents/stability.md (:102 execution)
21. hermes duplicate-key fix (services :20; top boot reader)
22. storage-collector statvfs EPERM noise; 23. mr-sync projection unhandled events; 24. postgres paperless collation refresh; 25. Boot-time catch-up stampede control (existing row)

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **Deploy-gate exception?** The guard deploy builds a toplevel (the gated heavy-build class) — but it IS the protection, and the box is at load 47 unguarded. Approve a bounded exception (deploy now in a small window, accepting the build heat), or strictly cooling-inspection-first?
2. **Shadow mode or live arming?** First deploy as log-only shadow (safe, delays protection by one verification cycle) or live-switching immediately (protects now, bets on unverified firmware-guided behavior — §d.6)?
3. **Was the 05:07 nix burst (and/or whatever is driving load 47 now) yours?** If you ran an interactive build/eval, the archaeology row closes instantly; if not, I assume daemon/fleet and dig — but I cannot see your shells.

**Bottom line:** the guard is built, tested, and verified to the eval boundary — and protects nothing yet, while the box live-rehearses freeze #15 at load 47. The critical path is still physical, but the deploy decision (Q1/Q2) is now the blocking software action.

**Harvest ledger (at authoring time):** §f.4 (shadow mode) → folded into the stability.md deploy row as a pending-owner decision; §f.7 (gatus wiring) → already owned by monitoring :17 (updated this session to target the guard's metrics — deliberately not duplicated); §f.1–3 owner legs → stability :117/:103 rows already carry them; §f.5–6 → the deploy row's drill clause; everything else was already queued in earlier sessions' rows, verified cited above.
