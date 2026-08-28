# 2026-08-22 Kernel Freeze #2 — Root Cause & Guard Hardening

**Incident:** boot `4d307ab5` (00:48:05 → 05:49:56) froze solid ~5 h after the
freeze-#1 recovery boot. Journal cut mid-write at 05:49:56; next boot 05:55:36;
no shutdown record. This happened WITH `memory-emergency-guard` deployed,
healthy, and actively tripping.

## Timeline (all 2026-08-22, boot -1)

| Time        | Event                                                                                                                                                                                                                                                 |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 00:48       | Boot (crash-recovery)                                                                                                                                                                                                                                 |
| 01:27       | First guard deploy runs — **dead on arrival**: `mv …prom.tmp → .prom: Operation not permitted` every minute (sticky-bit textfile dir + empty CapabilityBoundingSet; rename-over-foreign-file needs CAP_FOWNER even for root). Fail #26×/exit-1 until… |
| 01:39       | flm SIGABRT core-dump (v1.0.2 heap bug recurring) → restart → 21.6 GB cold load                                                                                                                                                                       |
| 01:52       | Cap fix deployed (commit `9a14a8e1`, concurrent session) — guard starts working                                                                                                                                                                       |
| 02:37       | flm dies by signal again → another cold load                                                                                                                                                                                                          |
| 03:31       | Deploy (generation `e5bdc4a`)                                                                                                                                                                                                                         |
| 03:32       | **Guard trip #1**: MemAvail 9.0%, zram 98.6% → stops flm (32G peak). zram value never moves again                                                                                                                                                     |
| 03:42–04:53 | **Guard trips #2–#7** (MemAvail 5.4–9.7%, zram stuck 98.6%, Free swap = 64 kB of 29.5 GB). flm re-activates between trips ~10 min apart (restart-backoff cadence; enricher insights logged at 03:35 prove flm serving mid-storm)                      |
| 04:58       | Kernel global OOM (kswapd): kills flm-real (22.2 GiB shmem) + ollama. OOM dump: **50.3 GiB shmem**, 51 GiB page cache, zram 100% full                                                                                                                 |
| 05:26       | Guard alert RESOLVED                                                                                                                                                                                                                                  |
| 05:34       | flm insight logged again — model re-faulted, pressure rebuilding                                                                                                                                                                                      |
| 05:49:39    | Gatus "Memory pressure CRITICAL" (PSI some avg10 >50%) + ZRAM Fill over-threshold                                                                                                                                                                     |
| 05:48:58    | **Guard ran and did NOT trip** — MemAvailable was still ≥10%                                                                                                                                                                                          |
| 05:49:56    | **Kernel froze** — 17 s after PSI-critical, 2 s before the next guard tick                                                                                                                                                                            |

## Root causes (three compounding guard design gaps)

1. **The feedback loop (why 7 trips couldn't win):** the guard stopped only
   `fastflowlm.service`, leaving `fastflowlm.socket` accepting — by design
   ("self-heals on next connection"). But every trip GENERATED alerts →
   PapDashboard ingest → the LLM insight enricher → a flm connection → a fresh
   21.6 GB cold load into a zram-full machine → re-trip. The guard's own alerts
   re-woke its sacrifice victim.
2. **The PSI blind spot (why the last window tripped nothing):** the final
   freeze was refault-thrash — the kernel had 51 GiB of reclaimable page cache
   so MemAvailable stayed ≥10% while PSI some avg10 exceeded 50%. Both trip
   zones (MemAvail<10%+zram≥92%, or <5% absolute) evaluated false 58 s before
   death. The kernel died of zram decompression CPU burn, not page exhaustion.
3. **Cadence:** 60 s tick; the collapse ran PSI-critical → dead in 17 s. The
   05:49:58 tick never happened.

Contributing load (OOM-dump census): ~a dozen concurrent crush agent sessions
(52 crush + 50 bun processes), 10 nix builds, 72 compile + 22 golangci-lint + 8
go processes, 12 qemu VMs (NixOS VM tests, 8 cross-arch aarch64), 78 helium +
20 chromium processes, iotop/btop running interactively — all against flm's
22 GiB unevictable shmem with zram 100% full. flm's v1.0.2 heap bug also
recurred twice (01:39 SIGABRT core-dump, 02:37 signal), each restart re-paying
the 21.6 GB cold read.

## Fixes (this session, module `memory-emergency-guard.nix`)

1. **Socket sacrifice + auto-restore:** trips now stop `fastflowlm.socket`
   FIRST (outside the cooldown; idempotent) — LLM clients get instant
   ECONNREFUSED; the PapDashboard enricher degrades gracefully instead of
   cold-loading the model. New `socketUnits` option. The guard restores the
   socket once MemAvailable ≥15% AND zram <92% AND PSI some avg10 <5% AND the
   10-min cooldown has elapsed (plus `systemctl reset-failed` on the sacrifice
   units). Reboot also restores it (sockets.target).
2. **Zone 3 (thrash) trip:** PSI some avg10 ≥40% (`psiSomeThresholdPercent`)
   AND zram ≥80% (`zramPsiFillThresholdPercent`), regardless of MemAvailable.
3. **30 s cadence** (`checkInterval` default; a 64M oneshot is cheap).
4. New metrics: `memory_emergency_guard_psi_some_avg10_percent`,
   `memory_emergency_guard_sacrifice_socket_active`. Gatus check description
   updated (conditions unchanged — presence + `last_trip_recent 0`).

Fix #3 from the morning (sticky-dir EPERM → CAP_FOWNER+CAP_DAC_OVERRIDE,
commit `9a14a8e1`) was authored by a concurrent session and verified live: the
guard ran clean from 01:53 onward.

## Verification

- `nix flake check --no-build` — all checks passed
- Deployed via `nix run .#deploy` (shellcheck on the script runs at build time
  via `writeShellApplication`)
- Post-deploy: `journalctl -u memory-emergency-guard` shows clean runs;
  `memory_emergency_guard_psi_some_avg10_percent` present in
  `/var/lib/prometheus-node-exporter/textfile_collectors/memory-emergency-guard.prom`

## Follow-ups (not done here)

- **flm v1.0.2 heap bug** now has 2 more crash samples (01:39, 02:37) — if it
  recurs, check upstream for a v1.0.3
- **PapDashboard enricher backoff**: it re-wakes flm on every alert storm even
  outside emergencies; consider teaching it to skip enrichment while
  `fastflowlm.socket` is inactive (upstream change)
- **Operational**: avoid full `nix flake check` (builds/runs VM tests = qemu
  storm) and mega-parallel agent sessions while flm is resident and zram is
  > 80% — the box has exactly one 21.6 GB unevictable liability and it must
  > always have ~25 GB of headroom
