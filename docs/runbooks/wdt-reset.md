# WDT Reset Investigation Runbook

**When the system reboots unexpectedly (sp5100-tco watchdog timer hard reset).**

The sp5100-tco watchdog has a 60-second timeout. When journald is starved
(I/O blocked or CPU starved under memory pressure), systemd's watchdog
thread cannot update the WDT, and the hardware forces a reset.

---

## Quick Diagnosis (First 5 Minutes)

### 1. Confirm it was a WDT reset (not a clean shutdown or kernel panic)

```bash
# Check last boot reason
journalctl --list-boots | tail -5
last reboot | head -5

# Look for WDT-specific messages in the previous boot's last moments
journalctl -b -1 --no-pager | tail -100

# Check if the boot before last ended abruptly (no shutdown messages)
journalctl -b -1 -u systemd-logind --no-pager
```

**WDT reset signature:** The previous boot's journal ends abruptly with no
`System is going down` or `Reached target Shutdown` messages. There may be
I/O errors, frozen processes, or OOM killer messages just before the cutoff.

### 2. Check for OOM killer activity

```bash
# Kernel OOM killer logs from the crashed boot
journalctl -b -1 -k | grep -i "oom\|out of memory\|killed process"

# systemd-oomd activity
journalctl -b -1 -u systemd-oomd --no-pager
```

### 3. Check memory state before crash

```bash
# PSI (Pressure Stall Information) from the crashed boot
journalctl -b -1 -k | grep "pressure"

# Memory pressure textfile metrics (if the boot was long enough)
# These are overwritten each boot, so only current boot is available
grep node_psi_memory /var/lib/prometheus-node-exporter/textfile_collectors/psi.prom
```

---

## Root Cause Analysis

### The OOM Cascade Chain (Most Common Cause)

```
Helium/Electron renderers grow unbounded in user-1000.slice
  → journald I/O starved (cannot flush to disk)
    → systemd main PID cannot send WDT keepalive
      → sp5100-tco fires after 60s timeout
        → HARD RESET
```

**Key indicators:**
- `user-1000.slice` MemoryCurrent was near MemoryMax (64G)
- GPUActive was >50G (consuming most of the ~110G visible RAM)
- zram swap was at 100% capacity
- No clean shutdown messages in journal

### Other Causes

| Cause | How to Identify |
|-------|----------------|
| **BTRFS metadata ENOSPC** | `btrfs filesystem usage /` shows 0% unallocated. Check `journalctl -b -1 -k \| grep btrfs` |
| **discard=async on QLC NAND** | 253ms discard latencies → 17.7s BTRFS commit freezes. Check `mount \| grep discard` |
| **Kernel panic** | `journalctl -b -1 -k \| grep -i panic` or check `/var/log/kdump/` if configured |
| **Power loss** | No journal entries at all from the "crashed" boot (UPS logs if available) |
| **Hardware fault** | Check `mcelog`, `dmesg \| grep -i mce`, NVMe SMART errors |

---

## Post-Recovery Steps

### 1. Clear failed units

```bash
sudo systemctl reset-failed
systemctl --user reset-failed
```

Services that crash-looped before the reset will be in `start-limit-hit`
state. Without this, they won't restart, and `nix run .#deploy` will fail
with `switch-to-configuration exit code 4`.

### 2. Check for corrupted state

```bash
# Docker containerd (most common corruption after hard reset)
sudo systemctl status docker
# If "bbolt corruption" errors:
sudo systemctl stop docker
cd /data/docker/containerd/daemon/io.containerd.metadata.v1.bolt/
sudo mv meta.db meta.db.bak
sudo rm -rf /data/docker/containers/ /data/docker/containerd/ /data/docker/network/
sudo systemctl start docker

# SigNoz SQLite migration lock
sudo sqlite3 /var/lib/signoz/signoz.db "DELETE FROM migration_lock;" 2>/dev/null
sudo systemctl restart signoz

# Monitor365 DuckDB WAL (auto-healed by ExecStartPre, but verify)
journalctl -u monitor365-server -n 20 | grep duckdb-heal

# BTRFS filesystem
sudo btrfs device stats /
sudo btrfs scrub status /
```

### 3. Clean up stale build sandboxes

```bash
# OOM/hard resets leave orphaned Nix build sandboxes
sudo du -sh /nix/var/nix/builds/ 2>/dev/null
sudo rm -rf /nix/var/nix/builds/nix-*
# Note: BTRFS snapshots may hold references; space frees as snapshots expire (14d)
```

### 4. Run full health check

```bash
nix run .#post-deploy-check
systemctl --failed
systemctl --user --failed
```

---

## Prevention

### Memory Pressure Mitigations Already in Place

| Mitigation | Where | What It Does |
|------------|-------|-------------|
| `user-1000.slice` MemoryHigh=56G | `boot.nix` | Throttles user processes before hard limit |
| `user-1000.slice` MemoryMax=64G | `boot.nix` | Hard kill limit for user processes |
| systemd-oomd 50%/20s | `boot.nix` | Kills memory-hungry processes before OOM cascade |
| MGLRU `min_ttl_ms=1000` | `boot.nix` | Protects youngest page generation from eviction |
| `--disable-gpu-watchdog` | `base.nix` (Helium) | Prevents GPU process kill during display hotplug |
| Memory-limited test wrappers | `home.nix` | `go-test-memlimit`, `cargo-test-memlimit`, `pnpm-test-memlimit` |
| Gatus: GPUActive > 60G alert | `gatus-config.nix` | Early warning before critical memory pressure |
| Gatus: user-slice > 40G alert | `gatus-config.nix` | Early warning before OOM cascade |
| Gatus: Memory Pressure (PSI) | `gatus-config.nix` | Fires at >50% stall (10s avg) |
| `/tmp` tmpfs capped 48G + stale-entry cleanup timer | `boot.nix`, `scheduled-tasks.nix` | Prevents build cache filling RAM-backed tmpfs; timer removes untouched entries >4h |

### Monitoring the WDT Health

The WDT itself is not directly monitored. The best proxy is monitoring the
conditions that lead to WDT fires:

1. **Memory pressure** (PSI) — Gatus alerts at >50% stall
2. **user-1000.slice memory** — Gatus alerts at >40G
3. **GPUActive memory** — Gatus alerts at >60G
4. **journald health** — Check `journalctl --disk-usage` periodically

If all three memory alerts fire in sequence, a WDT reset is likely imminent.
Close Helium tabs and restart Quickshell immediately.

---

## Hardware Details

- **WDT device:** sp5100-tco (AMD South Bridge watchdog)
- **Timeout:** 60 seconds (hardware, not configurable from userspace on this board)
- **Location:** `/dev/watchdog0`
- **Kernel module:** `sp5100_tco`
- **The WDT is armed by systemd** (`/lib/systemd/systemd --watchdog`) via
  `sd_notify(WATCHDOG=1)`. If systemd's main loop stalls for >60s, the hardware
  fires. This is BY DESIGN — a frozen init system means the machine is
  unrecoverable without hardware reset.
