# ADR-009: Zram-Only Swap on evo-x2

**Date:** 2026-10-21
**Status:** Accepted (retroactive — the configuration has been live since before 2026-08; this ADR records the decision, its evidence, and the closed recompression study)
**Origin:** stability plan T3.3 + TODO_LIST "ADR: zram-only swap decision" (status report 2026-08-13_15-04 §49, 2026-08-16_06-45 §12); posture decision recorded live 2026-08-18_23-51 §6

## Context

evo-x2 is a 128 GB unified-memory host (AMD Strix Halo, soldered LPDDR5X) with a
QLC root NVMe and a 90 %+ full disk. Swap is provided by a single zram device
(`zram-generator.conf`: `zram-size=50% ram`, `compression-algorithm=zstd(level=1)`,
`swap-priority=5` — `platforms/nixos/system/boot.nix` `zramSwap`). There is NO
disk-backed swap and none is planned.

The incident chain that shaped this decision (documented across
docs/agents/stability.md and the 2026-08-13 IO-pressure analysis):

1. Old `vm.swappiness=10` actively preferred page-cache reclaim (QLC disk I/O)
   over the in-RAM zram swap — backwards for zram-only, and a major contributor
   to the BTRFS I/O-storm freezes (fixed to `150` at `0bd8a272`).
2. Kernel-default `vm.page-cluster=3` and `watermark_boost_factor=15000` are
   HDD-era settings that waste zram CPU and amplify reclaim bursts (both fixed
   2026-09-05, `page-cluster=0`, `watermark_boost_factor=0`).
3. Full zram is NOT itself unhealthy: the risk is losing the only cheap reclaim
   path on a zram-only host, converting new memory pressure into page-cache
   eviction → QLC I/O storm (the documented freeze backbone) or oomd killing
   desktop services instead of the big anon consumers (2026-08-18 §6 verdict).
4. Disk swap was explicitly removed historically to free disk space; with the
   SSD at 90 %+ full there is no room to give back, and QLC sync-write latency
   (~200 ms fsync under load vs zram's RAM speed) makes a disk swap device a
   stall amplifier exactly when the system is already dying.

## Decision

**Zram-only swap stands.** Concretely:

- `zramSwap.memoryPercent = 50` (half of 128 GB ≈ 60 GiB device; raised from the
  earlier 30 % sizing as service memory budgets grew — the 2026-08-18 posture
  decision was "keep + monitor" at 30 %, and the sizing has since been revisited
  upward once, deliberately, with the guard stack already live).
- `compression-algorithm = zstd(level=1)` — measured on this box: L1 gives
  3.2× live ratio at ~370 MiB/s compress; higher levels buy ≤ +2 % ratio for
  up to 48 % slower compression (boot.nix comment block, kernel-default L3
  comparison). Under memory pressure, swap-out is synchronous on the reclaim
  path, so compress speed compounds.
- `vm.swappiness = 150`, `vm.page-cluster = 0`, `vm.watermark_boost_factor = 0`
  (the three sysctls above, each with sourced comments in boot.nix).
- **Monitor-only posture, no automatic swap relief valve.** Zram fill is watched
  by three independent layers: Gatus "ZRAM Fill" (≥90 % → Discord, the
  storm-precursor leading indicator), sev1 `ZRAM SWAP CRITICAL` (combined
  zram ≥90 % + degraded PSI/available, notify tier — never an overlay), and the
  memory-emergency-guard zones (which contain the emergency by stopping
  resumable churn and, at the limit, sacrificing sockets). A chronic-100 %
  steady state is a SIZING signal (raise memoryPercent or shrink consumers),
  not an automation trigger.

## Alternatives considered and rejected

| Alternative | Verdict | Reason |
| --- | --- | --- |
| Disk swap fallback (4–8 GiB) | **Rejected** | Disk 90 %+ full (reclaiming 4–8 GiB currently not viable); QLC ~200 ms write latency converts a memory emergency into an I/O emergency — the exact storm class the guard exists to prevent; would mask the zram-fill sizing signal. Re-evaluate ONLY after the disk has headroom AND a chronic zram-full steady state is observed. |
| zram writeback backing device | **Rejected** | Same backing-disk problem as above; writeback moves the WORST pages (cold, but re-read on demand) onto the slowest medium. |
| Raise memoryPercent beyond 50 % | **Rejected for now** | Memory is budgeted (GTT-first GPU doctrine, hot DBs, service MemoryMax fractions); oversized zram just delays the oomd/guard trip without adding physical capacity — compressed anon still consumes physical RAM. 50 % already exceeds any observed steady anon demand. |
| lzo-rle primary (Fedora default) | **Rejected** | zstd(level=1) measured better here: the ratio delta (~3.2× vs ~2.5×) matters more than lzo-rle's compress-speed edge on a 128 GB host whose bottleneck is reclaim latency, not CPU. |

## Recompression study (stability plan T3.3) — mechanics verified, adoption gated

Kernel zram recompression (`CONFIG_ZRAM_MULTI_COMP`, sysfs `recomp_algorithm` +
`recompress`, **Linux 6.2** — kernel commit `84b33bf788897`; per-algorithm
`algorithm_params` is 6.12+) lets cold/idle or huge pages be re-compressed with
a stronger secondary algorithm, reclaiming physical RAM from an already-full
zram. This box runs kernel 7.x and **zram-generator 1.2.1** (verified from the
host's `systemd.packages`), which is ≥ v1.2.0 (2024-11-27) — the first release
that configures recompression via a whitespace-separated
`compression-algorithm=` list (upstream PR #200; subsequent entries become
recompression algorithms with decreasing priority). The NixOS `boot.zramSwap`
module passes the string through to `zram-generator.conf` verbatim (verified:
the generated conf carries `zstd(level=1)` byte-for-byte).

Scope limits, verified against upstream:

- zram-generator **configures** the recompression algorithms/parameters at
  device setup but deliberately does **not schedule** recompression runs
  (maintainer: "equivalent to a cron job" — zram-generator#178). A recurring
  run needs our own bounded timer echoing to `/sys/block/zram0/recompress`.
- Recompression is CPU-work on the reclaim path; running it DURING a storm
  would worsen the exact failure it is meant to prevent.

Candidate shape if adopted (NOT deployed by this ADR):

```
boot.zramSwap.algorithm = "zstd(level=1) lzo-rle (type=idle,threshold=1500)";
# + a PSI-gated, bounded oneshot timer (memory-guard-churn pattern) that only
#   recompresses while io PSI and memory avg10 are LOW.
```

Verdict: **mechanically viable, adopt only with live evidence.** The 98.6 %-pinned
episodes that motivated T3.3 must first be re-observed post-sizing-increase: if
they no longer pin, recompression solves a problem we no longer have. The
follow-up (live study: baseline `mm_stat`, bounded timer, reclaim measured) is
queued in TODO_LIST; this ADR neither enables nor blocks it beyond the gating
above.

## Consequences

- The kernel ALWAYS has a cheap reclaim path; the freeze backbone is the
  page-cache-eviction fallback, which the guard stack (zones, churn stops,
  backup catch-up slot) owns.
- Sizing changes (memoryPercent) are deliberate, evidenced decisions — not
  reactive knob-turns mid-storm.
- Any future disk-swap proposal must clear BOTH preconditions: real disk
  headroom AND a documented chronic zram-full pattern that sizing did not fix.
- The three sysctls and the algorithm choice are load-bearing documented
  settings: changing any of them requires editing this ADR, not just boot.nix.
