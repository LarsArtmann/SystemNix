# STATUS — 2026-08-22 06:41 · Freeze #2 Forensics → Guard Hardening → VM Regression Test

**Session arc:** "Why the fuck did we crash this time?" → full root-cause → guard redesign → deployed + verified live → regression-tested end-to-end. Companion docs: `2026-08-22_06-20_kernel-freeze-2-guard-feedback-loop-psi-blindspot.md` (incident analysis), `2026-08-22_06-24_self-review-freeze2-guard-hardening.md` (honest self-review with misses).

---

## What's Done

### Diagnosis (complete)

Boot `-1` (00:48:05 → **05:49:56 hard freeze**, no shutdown record) died WITH the
new memory-emergency-guard deployed and tripping. Three compounding design gaps:

1. **Feedback loop** — guard stopped only `fastflowlm.service`; the activation
   socket kept accepting. Every trip's own gatus alerts → PapDashboard insight
   enricher → flm connection → fresh 21.6 GB cold load into a zram-full machine →
   re-trip ~10 min later. Guard tripped **7×** (03:32–04:53, MemAvail 5.4–9.7%,
   zram pinned 98.6%, Free swap = 64 kB / 29.5 GB); kernel OOM-killed flm
   (22.2 GiB shmem) + ollama at 04:58; resolved 05:26; flm re-served by 05:34;
   froze 05:49:56.
2. **PSI blind spot** — final freeze was refault-thrash: PSI some avg10 >50%
   while MemAvailable stayed ≥10% (51 GiB page cache headroom). No trip zone
   fired at 05:48:58; kernel died 17 s after PSI-critical, 2 s before the next
   tick.
3. **Cadence** — 60 s tick vs a 17 s collapse window.

Contributing load (OOM-dump census): ~12 concurrent crush sessions (52 crush +
50 bun), 10 nix builds, 72 compile + 22 golangci-lint, 12 qemu VMs (8 cross-arch
aarch64 NixOS VM tests), 78 helium procs. flm heap bug (v1.0.2) also recurred
twice (01:39 SIGABRT, 02:37 signal).

### Fixes (implemented + deployed + verified live)

`modules/nixos/services/memory-emergency-guard.nix`:

- **Socket sacrifice**: trips stop `fastflowlm.socket` FIRST (idempotent,
  outside cooldown) — clients get instant ECONNREFUSED; the enricher degrades
  instead of cold-loading. **Auto-restore** restarts the socket once
  MemAvailable ≥15% AND zram <92% AND PSI some avg10 <5% AND the 600 s cooldown
  elapsed (+ `systemctl reset-failed` on sacrifice units; reboot also restores).
- **Zone 3 thrash trip**: PSI some avg10 ≥40% AND zram ≥80%, regardless of
  MemAvailable — the 05:49 mode.
- **30 s cadence** (was 60 s).
- New metrics: `memory_emergency_guard_psi_some_avg10_percent`,
  `memory_emergency_guard_sacrifice_socket_active`.
- Env-overridable kernel data sources (test hooks; production defaults
  unchanged).

Verified on the live machine (deployed 06:23:40 via the concurrent session's
switch — my commits `a5982065`/`afbbd887` rode along):

- Deployed script contains `SOCKET_UNITS="fastflowlm.socket"`, timer at 30 s
- Textfile metrics: `psi_some_avg10 0.09`, `sacrifice_socket_active 1`,
  `avail 31.6%`, `zram 20.7%`, `tripped_total 7` (state persisted from the night)
- Gatus alert text updated (conditions unchanged)

### Regression test (written, green)

`tests/test-memory-emergency-guard.nix` — VM test running the REAL deployed
script against REAL systemd with dummy `fastflowlm{,.socket,@}` units; only
meminfo/zram/PSI sources are faked via env overrides. 7 scenarios: healthy
no-trip, Zone 1, Zone 2, **Zone 3 blind-spot (asserts trip with HEALTHY
MemAvailable)**, cooldown skip (counter frozen, socket stays down), restore
after cooldown, restore blocked by residual PSI. Passing:
`nix build .#checks.x86_64-linux.memory-emergency-guard` → exit 0.

### Documentation

- AGENTS.md: freeze section rewritten covering both incidents + general rules
  (socket-activated sacrifice needs its SOCKET down; trip on PSI not just free
  memory; don't run VM-test storms while flm is resident)
- Two status reports + this one; gatus-config.nix comments updated

## What's Broken (needs external action)

1. **DAS is physically absent** since the freeze reboot: lsblk shows ONLY
   nvme0n1 + zram0 — no pool Toshibas, no buildcache SSD, no SanDisks.
   `/mnt/pool` and `/mnt/buildcache` unmounted, smartd exiting (16).
   Nightly btrbk pool sends WILL fail tonight. **User action: reseat DAS USB
   cable + enclosure power, then reboot** (post-crash peripheral class, same as
   the documented 8-1 link death).
2. **XFS finalize pending user decision**: the deploy mounted
   `/var/lib/clickhouse` on XFS (verified: `clickhouse_xfs_mounted 1`, 30%
   used, server running on it — the root-BTRFS contamination is over). The
   shadowed originals (~26 GiB) on `@` stay until
   `sudo bash scripts/migrate-clickhouse-xfs.sh finalize`. Timing is a user
   call (data deletion).
3. **flm v1.0.2 heap bug**: 2 more crashes this night (01:39 SIGABRT core-dump,
   02:37 signal). Contained by restart backoff + the guard; upstream release
   check pending.

## What's Partially Complete

1. **Tree ↔ running system divergence (small)**: the running guard is the
   06:23:40 build (socket + Zone 3 + 30 s — all critical fixes). The
   env-override test hooks landed in the tree AFTER that switch; production
   behavior is identical, but one redeploy is needed to converge. Blocked on
   the concurrent session's uncommitted edits (caddy.nix, sops.nix,
   configuration.nix — not mine to deploy around).
2. **Full `nix flake check` not re-run** after the test additions (the
   individual test derivation built green; the flake-wide check is the
   pre-commit/CI gate anyway).
3. **PapDashboard enricher**: socket-stop contains it during emergencies, but
   it still hammers flm with doomed connections during every alert storm.
   Upstream backoff = follow-up consideration (user sign-off on the
   degradation trade requested in the 06:24 self-review).

## Next Actions (priority order)

1. **User**: reseat DAS + reboot; verify pool + buildcache + smartd recover
   (`lsblk`, `findmnt /mnt/pool`, btrbk verify).
2. **User**: XFS finalize decision (immediately vs soak N days).
3. Redeploy (`nix run .#deploy`) once the concurrent session's edits settle —
   converges tree and system.
4. Check FastFlowLM upstream for a release fixing the recurring SIGABRT.
5. Consider upstream enricher backoff; watch Zone 3 thresholds for
   false-trips under legitimate heavy load (auto-restore mitigates).

## System Snapshot (06:41)

| Metric | Value |
| ------ | ----- |
| Uptime | 46 min (boot 05:55:36) |
| MemAvailable / zram / PSI | 31.6% / 20.7% / 0.09% — healthy |
| Guard | new version live, 30 s cadence, socket up, 0 trips this boot |
| flm | running (model resident) — expected; healthy headroom |
| ClickHouse | on XFS (nvme0n1p9), 30% used |
| DAS | ABSENT (physical reseat needed) |
| Pool backups | offline until DAS returns |
