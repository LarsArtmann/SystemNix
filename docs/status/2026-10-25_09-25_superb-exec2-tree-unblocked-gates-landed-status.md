# SUPERB exec-2 Status — Tree Unblocked, Gates Landed, Storm+Lock Double-Block

**Session:** 2026-10-25 ~07:29–09:2x CET · **Instance:** exec-2 (resume of exec-1's carry-forward list) · **HEAD at authoring:** `b31a465e2` + working tree

## a) DONE this session (all committed unless noted)

| Commit | What |
|---|---|
| `93926a908` | Plan EXECUTING tombstone re-flipped for exec-2 (twin-executor guard) |
| `050567953` | **Tree unblocked**: foreign `tests/test-upholds-convergence.nix` used `systemd.units.<n>.upholds` — absent from pinned nixpkgs fe13242, broke EVERY non-docs commit at the pre-commit eval leg ~1h. Verified from pinned source (`systemd-unit-options.nix`, `systemd-lib.nix` symlink pass) that the inverse-facing `upheldBy` on the consumer renders the IDENTICAL mount-side `.upholds` edge; re-expressed + statix-clean module arg. `upholds-convergence.drvPath` evals green. |
| `416218795` | **Batch A landed**: FEATURES enable-drift standing gate (F11–F13) — 45 rows guarded, 0 violations live verdict; 5-leg fixture selftest. |
| `f800a2bc1` | **Batch B landed**: watch-the-watcher (F25–F29) — node_textfile_scrape_error gatus check (229→230) + `checks.system-health-rendered-unique`. |
| `e3293d694` | **Crash-loop detection + restart-metric swap fix** (monitoring.md nsfw row, §f.23): TWO roots found. (1) The 2026-09-19 merged `systemctl show -p CPUUsageNSec -p NRestarts` read assumed flag-order output — systemctl prints its OWN order (live-probed: NRestarts FIRST; busctl cross-check: NRestarts=u 0 vs .prom nrestarts=8.4e13 CPU-ns) — for six weeks `system_service_nrestarts` carried CPU-nanoseconds, `system_service_cpu_percent` read ~0 fleet-wide, and the fast crash-loop delta (correct cur vs swapped prev) could NEVER be positive. Fixed with an order-immune keyed `Key=value` parse. (2) The churn/crash-loop aggregates existed but NOTHING consumed them — wired: gatus check (endpoints 230→231), sev1-bridge notify leg (UNIT CRASH LOOP + per-service attribution), two SigNoz rules (47→49). Selftest `system-health-restart-tracking` VM-GREEN: slices the REAL keyed parse from the rendered collector against a systemctl stub pinned to the live order (+ flag-order/[not set]/missing-line legs) + wiring tripwires. |
| `edb3d4abb` | **/data usage alarms** (T19/F67): WARN >85% / CRITICAL >90% SigNoz rules on the /data series (the root rule pins mountpoint="/"). LIVE PREMISE-CHECK overturned the plan: /data is at **66.7%** (345 GiB free — ~190 GiB reclaimed since the 2026-10-11 85.0% baseline; rules arrive GREEN). Stale storage.md watch-row headline ("at 86%") corrected. monitoring.md nsfw row closed with full evidence. |
| `b31a465e2` | README SigNoz count 49→51. |
| daemon-swept (uncommitted) | CHANGELOG entry for exec-1+exec-2 gates (sits above the foreign tile-coverage entry; left for the daemon to sweep — pathspec commit would have swept their half-done work). |

## b) IN-FLIGHT (working tree, mine)

- **hermes-db-health maintenance-entry gate** (stability.md row 38 / §f.24): the census is PSI-gated but caps at 12×30s then RUNS REGARDLESS — the freeze-33 T+5 finding (census ran INTO a 60%+ recovery storm). Defer branch added (marker kept, exit 0, "maintenance never enters a storm"); fixture leg 3 rewritten from "runs anyway after cap" to the deferral invariant; standalone + minimal-sandbox repros GREEN.
- **BLOCKED MYSTERY**: `checks.hermes-migrate-fixture` fails leg2 ("pragma re-assert did not run") in the nix build sandbox but is GREEN in every reproduction (standalone, env -i, minimal PATH). Both failing greps' outcomes are jointly explainable ONLY by the census taking the timeout/marker branch in-sandbox — cause unknown; leg2 fail message instrumented to dump the stub log + output (instrumentation to revert after diagnosis).
- **HARD BLOCKER (foreign, in-flight)**: at ~09:11 a parallel session floated `flake.lock` (buildflow, crm, cv, dankMaterialShell, dnsblockd, go-health-dashboard, …) WITHOUT regenerating `flake/expected-locks.nix` — **exec-1's lock-float gate now fires on every eval of the working tree**, blocking all builds/checks (including my instrumented rebuild and any deploy). The gate is working as designed (registry+lock must move together after a green toplevel build). Their float to land; I will NOT regenerate the registry (would bless unverified revs) and will NOT revert their lock. If their session died, the tree stays eval-blocked until they (or the owner) resolve it.

## c) DEPLOY GATE — still closed all session

Sustained io PSI never held <30% (observed 25–88%, mostly >35%) AND k10temp cycled 77–99°C (freeze-#33/#34 doctrine: never build a toplevel into that). T1/T2 (deploy + proofs F17–F21) remain queued. The deploy batch now ALSO carries: my crash-loop wiring, /data alarms, hermes defer gate, + foreign waves (forgejo-runner migration, integration tiles, trust-proxy, the floated lock once it lands).

## d) KEY FINDINGS (durable)

1. **systemctl show property order is NOT the -p flag order** (live-proven twice: busctl + the six-week metric swap). Keyed `Key=value` parsing is the only safe multi-property read.
2. **/data was silently reclaimed ~190 GiB** between 2026-10-11 and 10-25 (86%→66.7%) — the watch row's headline had rotted; two plan items (F67 threshold urgency, F66 measurement) were premised on the stale 86%.
3. **The pipe-rc trap bit twice more** (`nix build … | tail; echo rc=$?` masks build failure — rc comes from tail). Un-piped redirection or `>file; echo rc=$?` only.
4. Parallel-session reality: 11+ live crush sessions; flake.lock mid-float; foreign half-done CHANGELOG entry sharing the file with mine.

## e) NEXT (ordered)

1. Wait out the lock float: if the parallel session lands it (registry+lock together), rebuild `hermes-migrate-fixture`, diagnose the sandbox leg2 divergence via the instrumented dump, revert instrumentation, land the hermes defer batch.
2. First calm window (io PSI avg10 <30% sustained AND k10temp <85°C): `nix run .#deploy` (carries everything above), anchor-by-NUMBER verify, `scripts/post-deploy-check.sh`, proofs F17–F21.
3. F66/F68 (du-vs-df /data measurement + growth-attribution close) at the same calm window (heavy-IO du).
4. §f remainder: T13 decompose, T22 tq hardening, queue triage sprints (39–42), hermes IFD decision row.
5. Owner questions (07-16 §g) still standing: deploy autonomy, cap 250k + agent fate, upstream push.

**Source:** docs/planning/2026-10-25_05-10_SUPERB-*.md (exec-2 marker) + exec-1 close-outs 07-05/07-16.
