# Watchdogd RT Supervisor Analysis

**Date:** 2026-08-12
**Status:** Decision — do NOT enable. Revisit if we hit a CFS scheduler starvation failure mode.

---

## Background

The hardware watchdog (`watchdogd`) on evo-x2 pets the SP5100 TCO timer every 10s. If it fails to pet within 30s, the system hard-resets. During the 2026-08 crash chain (QLC SLC cache exhaustion → IO queue → kernel freeze), `watchdogd` was unable to run and the WDT fired.

The question arose: should `watchdogd` run with **real-time CPU scheduling** (`SCHED_RR`) to guarantee it gets a timeslice even under heavy load?

## What watchdogd Supports

`watchdogd` (troglobit/watchdogd) has a built-in process supervisor that can switch to `SCHED_RR` (real-time round-robin) via `sched_setscheduler()`. From `src/supervisor.c`:

```c
if (ena) {
    prio.sched_priority = rtprio;  // default 98
    sched_setscheduler(getpid(), SCHED_RR, &prio);
} else {
    sched_setscheduler(getpid(), SCHED_OTHER, &prio);
}
```

- When supervisor is enabled with `priority > 0`: `SCHED_RR` at RT priority 98
- By default / supervisor disabled: `SCHED_OTHER` (normal CFS scheduling)

This requires `CAP_SYS_NICE` on the systemd unit for `sched_setscheduler(SCHED_RR)`.

## IO Priority Is Irrelevant

`watchdogd` does effectively zero block I/O:
- Writes 1 byte to `/dev/watchdog0` (character device — bypasses block layer entirely)
- Reads `/proc/meminfo` (virtual file — no block I/O)

IO scheduling class/priority (`ioprio`, BFQ, `ioTier`) has **no effect** on character device or virtual filesystem access. The kernel default (best-effort, priority 4) is fine and cannot be improved upon for this workload.

The real risk is **CPU scheduler starvation**, not I/O.

## Tradeoffs

| Aspect | Current (CFS / SCHED_OTHER) | With SCHED_RR prio 98 |
|---|---|---|
| **Survives scheduler starvation** (CFS never gives it a timeslice) | No — starved by IO-heavy processes | Yes — preempts all normal tasks |
| **Survives true kernel lockup** (non-preemptible section, RCU stall) | No | No — if the scheduler isn't running, nothing runs |
| **Risk if watchdogd itself bugs out** | Low — normal priority, trivially managed | High — RT process can monopolize a CPU core, harder to kill/debug |
| **Extra capabilities needed** | None | `CAP_SYS_NICE` (or root) for `sched_setscheduler(SCHED_RR)` |
| **Impact on system latency** | Zero | Minimal — daemon is tiny, runs ~1ms every 10s |
| **False resets during recoverable stalls** | More likely — any brief stall → missed kick → reset | Less likely — rides out short scheduler stalls |

## Why Not Enable It

The crash chains on this system (2026-08-03, 2026-08-04, 2026-08-09, 2026-08-11) were all **true kernel freezes** — QLC SLC cache exhaustion creates an exponential IO queue that stalls the kernel in **non-preemptible block-layer code** (e.g. `io_schedule()`, BTRFS locks). When the kernel is stuck in a non-preemptible section, the scheduler itself isn't running. `SCHED_RR` doesn't help — no userspace process runs, RT or not.

`SCHED_RR` only helps against **CFS scheduler starvation** — where the kernel is healthy but `watchdogd` keeps losing the CPU lottery to noisy neighbors. That is **not** the failure pattern on this system.

Enabling RT priority adds risk (a runaway RT process is harder to manage) for a failure mode that hasn't occurred.

## Existing Mitigations (Already Deployed)

The root causes of the kernel freezes are addressed at the source:

- `commit=300` on all BTRFS mounts — reduces metadata write frequency ~10x
- Daily `fstrim` at idle I/O priority — keeps SLC cache healthy
- `MemoryHigh` caps on PMA and other memory-hungry services — prevents page-cache thrash loops
- BTRFS balance (weekly) — prevents metadata ENOSPC
- `startLimitBurst`/`startLimitIntervalSec` fixes — prevents infinite restart loops from compounding IO pressure

## When to Revisit

Revisit this decision if we observe a crash where:

1. The kernel was **not** in a non-preemptible section (no RCU stall, no hung task in D-state)
2. `watchdogd` was starved by userspace CPU contention (CFS never scheduled it)
3. The system was otherwise responsive (network/SSH partially working)

This would indicate CFS scheduler starvation, which `SCHED_RR` would fix. Check `dmesg` / pstore for the absence of hung-task warnings to distinguish from kernel lockups.

## References

- [troglobit/watchdogd](https://github.com/troglobit/watchdogd) — source code (`src/supervisor.c`)
- `platforms/nixos/system/boot.nix:339-352` — current watchdogd config
- `docs/crash-analysis-2026-06-26.md` — WDT timeout tradeoff analysis
- `docs/crash-analysis-2026-08-09.md` — PMA page-cache thrash crash
- `docs/crash-analysis-2026-08-11.md` — browser-history crash-loop WDT chain
