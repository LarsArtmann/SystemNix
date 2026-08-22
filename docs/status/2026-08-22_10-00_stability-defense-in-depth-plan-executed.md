# Stability Defense-in-Depth — Pareto Plan + Full Execution

**Date:** 2026-08-22 07:01–10:00 · **Session:** stability brainstorm → 5-question alignment → plan → execute-everything
**Plan:** `docs/planning/2026-08-22_07-01_STABILITY-DEFENSE-IN-DEPTH-PARETO-PLAN.html` (+ `stability-plan-ladder.d2/.svg`)

## Context

User asked for stability/reliability ideas after the 2026-08-22 double kernel freeze + guard redesign session. Brainstorm produced 12 candidate improvements; a 5-question alignment round locked the design:

| Decision | Choice |
| --- | --- |
| Mode | Plan first, then execute EVERYTHING this session |
| Admission control | Full enforcement for builds + VM tests; crush monitor-only |
| Auto-shedder (kill VMs/builds at PSI≥20) | **REJECTED** — PSI warning tier is alert-only |
| Hang → reboot + dump | Approved, FULL (kdump + panic=10) |
| SEV1 channel | Discord (phone) + DMS notify + fullscreen overlay; overlay earns: guard-trip, infra-criticals, guard-dead |
| MAX_CONCURRENT | 3 heavy jobs |

## Key research finding (changed the hang-detection design)

Both freezes were scheduler **LIVELOCKS, not lockups**: `softlockup_panic=1`, `hung_task_panic=1`, and the 30 s hardware WDT were ALL already armed and NONE fired. A livelock (CPUs burning in zram refault, IRQs enabled, RCU progressing) pets the WDT eventually, never trips the soft-lockup detector, and starves khungtaskd. Nothing in-kernel catches that class → prevention must act BEFORE the cliff (admission control, guard); kdump only guarantees evidence when a panic does fire.

Second finding: builds run inside `system.slice/nix-daemon.service` regardless of invoking user (daemon-multiplexed) and it's oomd-EXEMPT with no MemoryHigh — census night's 10 concurrent builds × 4-8 GB ran completely unbounded.

## What was built (all deployed + verified live)

| ID | Component | Verification |
| --- | --- | --- |
| T1.1a | `nix-daemon.serviceConfig.MemoryHigh = "32G"` (networking.nix) — throttles ALL builds at 32 GB combined; reclaim/swap, never kill | `/sys/fs/cgroup/system.slice/nix-daemon.service/memory.high = 34359738368` ✅ |
| T1.1b | `workload-admission.nix` — `heavy-job` wrapper: slot-counting flock queue (held-fd pattern `exec 9>lock; flock -n 9; exec "$@"`), 3 slots, waits never fails; tmpfiles slot dir | `heavy-job` in system bin ✅ |
| T1.1c | Crush census: `system_crush_sessions{,_over_threshold}` in system-health + Gatus "Crush Session Pressure" (alert-only, threshold 6) | metric live: **26 sessions** (alert firing — soak data for tuning) ✅ |
| T1.2 | `boot.crashDump.enable` (fork-verified) + `kernel.panic` 30→10 + `kdump-retention.service` (keep 2 newest, 20 G cap; boot+weekly timer) | crashkernel=128M in new generation (arms at REBOOT); panic=10 live sysctl ✅ |
| T2.1 | PSI warning tier: `node_psi_memory_some_avg60` + `node_psi_memory_warning` (avg60 ≥20%) in psi-metrics + Gatus "Memory Pressure Warning" (1m interval, Discord-only) | metrics live (0.00) ✅ |
| T2.2 | `sev1-escalation.nix` — `sev1-bridge` (root, 10 s): guard-trip / guard-DEAD / monitoring-stale / DAS / LAN-NIC / btrfs / zram-combined → `/run/systemnix/sev1/alert` (self-expiring: 3rd line epoch, overlay TTL 120 s) + ONE deduped notify-send via `systemd-run --machine=lars@.host --user` (machined proxy). `sev1-overlay` user quickshell fullscreen banner (shutdown-overlay pattern). Module-presence gates (`SYSTEMCTL_BIN` env hook): hosts without guard/system-health never page DEAD/STALE. Gatus "SEV1 Escalation Bridge" meta-check | bridge journal: `SEV1 active (1 condition): DAS USB LINK DOWN` (TRUE condition — DAS physically absent); alert file 3-line format correct; overlay wired to graphical-session.target.wants ✅ |
| T2.3 | Top-8 cgroup census: `system_cgroup_mem_{,anon_,shmem_,unevictable_}bytes{cgroup=…}` | live: flm 26.7 GB top, user sessions ~2 GB each — "who holds RAM" is now a metric ✅ |
| T3.1 | deploy.sh pressure gate (exit 12): PSI≥20 OR avail<10 OR zram≥95-with-PSI≥5 → block; `DEPLOY_FORCE_PRESSURE=1` escape | LIVE-TESTED BOTH WAYS: v1 (zram≥90 standalone) blocked its own deploy at zram 98.5%/PSI 0.00 → recognized steady-state-normal → fixed to combined semantics → passed at zram 96.9%/PSI 0.00/avail 25% ✅ |

VM regression test `tests/test-sev1-escalation.nix` (7 scenarios: healthy, trip, dedup, guard-dead, module-absent gate, DAS infra, clear) — GREEN after two real fixes it caught: shellcheck SC2154 (`''${stateDir}` over-escape) and the writeShellApplication runtimeInputs-prepend (PATH-shim systemctl loses → `SYSTEMCTL_BIN` env hook). `nix flake check --no-build` green, gatus-pattern-lint green (all new pats anchored).

## Two live lessons folded back in during deployment

1. **zram-full alone is steady-state NORMAL on this box** (swappiness=150 keeps cold anon compressed; measured 98.5-98.6% with PSI 0.00 and 25% avail). Both my deploy gate v1 and the bridge's original zram condition over-triggered on it — both fixed to combined semantics (zram high AND margins degraded), mirroring the emergency guard's zones. The mystery from freeze #2 ("zram pinned 98.6% for 2 h") may partly be THIS: not a leak, just zram doing its job.
2. **26 crush sessions detected** — census night was ~12. Either normal for this box (→ raise threshold) or leaked TUIs (→ close them). Soak data; monitor-only by decision.

## Verification state at session end

- Deploy switched (generation includes everything; kdump arms at next reboot — crashkernel is a boot param)
- `sev1_bridge_alerts_active 1` = the genuine DAS-down condition; overlay should be visible on the desktop
- Post-deploy check: 62 PASS / 8 FAIL — ALL 8 are the pre-existing DAS-absence casualties (Immich ×2, Attic, Paperless, Bank-Sync ×4 — pool-backed services), none from this session's changes
- Pre-deploy-check KNOWN_NEW_METRICS extended with the 10 new metric names (remove after next green scrape cycle)

## Open items (harvested to TODO_LIST.md)

- T2.4 upstream: PapDashboard enricher LLM backoff + guard-trip circuit break
- T3.2 monitor-the-monitors meta-audit · T3.3 zram recompression study · T3.4 flm release watch (SIGABRT heap bug) · T3.5 physical: powered USB hub / enclosure swap + UPS
- USER: reboot when convenient to arm kdump; DAS reseat still pending (everything pool-side stays red until then); tune `crushSessionAlertThreshold` (6) after observing what "normal" is
