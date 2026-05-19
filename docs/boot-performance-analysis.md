# Boot Performance Analysis — evo-x2

**Date:** 2026-05-08
**Kernel:** 7.0.1 (latest)
**System:** AMD Ryzen AI Max+ 395, 128GB, BTRFS on NVMe

## Current Boot Time: 36.0s

| Phase | Time | % |
|---|---|---|
| Firmware (UEFI/BIOS) | 5.3s | 15% |
| Loader (systemd-boot) | 5.8s | 16% |
| Kernel | 1.8s | 5% |
| Initrd | 4.2s | 12% |
| **Userspace** | **19.0s** | **53%** |
| `graphical.target` reached at | 18.989s | |

## Critical Path

```
graphical.target @18.989s
└─multi-user.target @18.989s
  └─clamav-daemon.service @18.989s    ← SOLE BLOCKER
    └─basic.target @1.773s
      └─dbus-broker.service @1.739s +26ms
        └─dbus.socket @1.729s
          └─sysinit.target @1.718s
            └─systemd-update-utmp.service @1.695s +21ms
              └─systemd-tmpfiles-setup.service @1.631s +62ms
                └─systemd-journal-flush.service @677ms +95ms
                  └─systemd-remount-fs.service @619ms +53ms
```

`clamav-daemon` is the **only service blocking graphical.target**. Everything else (Unbound, ClickHouse, Authelia, SigNoz, Docker) runs in parallel and finishes later but doesn't block login.

## Top Services by Time (parallel, not all critical)

| Service | Time | On critical path? |
|---|---|---|
| `nix-gc.service` | 61.3s | No (timer, parallel) |
| `systemd-tmpfiles-clean` | 14.8s | No (timer, parallel) |
| `gitea-github-sync` | 13.3s | No (parallel) |
| `authelia-main` | 11.1s | No (parallel) |
| `signoz` | 9.0s | No (parallel) |
| `unbound` | 7.5s | No (parallel) |
| `clickhouse` | 7.2s | No (parallel) |
| `hermes` | 6.2s | No (parallel) |
| **`clamav-daemon`** | **~17s effective** | **YES — sole blocker** |

## Boot Timeline (key milestones, monotonic)

```
 0.000s  Kernel starts
 2.243s  Initrd systemd starts
 2.501s  Initrd Root Device
 3.536s  Initrd Root FS mounted
 4.806s  Initrd Default Target (switch-root)
 6.605s  Userspace systemd starts
 7.747s  basic.target reached
 7.903s  Network is Online
 8.632s  Display Manager (SDDM) started
 9.103s  Authelia started
 9.461s  PostgreSQL ready
10.450s  Gitea started
12.054s  User session starts
15.087s  ClickHouse started
19.323s  Unbound started (DNS available)
20.535s  Docker started
20.536s  cAdvisor started
```

## Optimizations (sorted by impact)

### 1. Remove ClamAV from boot critical path — saves ~17s

`clamav-daemon.service` has `WantedBy=multi-user.target` (from nixpkgs default), making it the sole blocker for `graphical.target`. It sits at 18.989s despite depending only on `basic.target` (1.773s) — the nixpkgs clamav module adds implicit filesystem ordering that delays it.

**Fix:** Convert to socket-only activation (on-demand when something actually scans). Add to `security-hardening.nix`:

```nix
systemd.services.clamav-daemon = {
  wantedBy = lib.mkForce [];  # Remove from multi-user.target
  after = lib.mkForce ["basic.target"];
};
```

ClamAV still works — it just activates on-demand via its socket instead of blocking login.

### 2. Remove `network-online.target` from local-only services — saves ~1-2s

These services wait for full network-online even though they only need local resources:

| Service | File | Fix |
|---|---|---|
| `podman-photomap` | `photomap.nix:58` | Remove `network-online.target` (only talks to local immich/postgres) |

### 3. Reduce systemd-boot loader timeout — saves up to ~5s

The loader phase takes 5.76s — likely includes a menu timeout. In `boot.nix`:

```nix
boot.loader.systemd-boot.editor = false;  # Disable editor (security + speed)
boot.loader.timeout = 1;  # 1 second, or 0 to skip menu entirely
```

### 4. Disable TPM device polling (if unused) — ~4.3s I/O reduction

TPM and serial port device enumeration takes 4.3s. Not on the critical path but adds I/O load during boot. Since measured boot is disabled (`Measured UKI: no`, Secure Boot disabled):

```nix
boot.kernelParams = [
  # ... existing params ...
  "tpm.disabled=1"  # Disable TPM entirely — not used for measured boot
];
```

Only do this if you don't plan to use TPM-based disk encryption or measured boot.

### 5. Move heavy services to post-login targets (optional) — reduces boot I/O contention

Services like Unbound (7.5s), ClickHouse (7.2s), SigNoz (9s) are already parallel but compete for I/O during boot. Moving them to start after `graphical.target` reduces contention:

```nix
# Example for signoz.nix:
systemd.services.signoz = {
  wantedBy = [ "graphical.target" ];  # Start after login, not before
  after = [ "graphical.target" "clickhouse.service" ];
};
```

## Summary

| # | Optimization | Estimated Savings | Effort | Risk |
|---|---|---|---|---|
| 1 | **ClamAV → socket-only** | **~17s** | 3 lines | Low — still works on-demand |
| 2 | Remove unnecessary `network-online.target` | ~1-2s | 4 lines | None |
| 3 | Reduce loader timeout | up to ~5s | 1-2 lines | None |
| 4 | Disable TPM (if unused) | ~4.3s I/O reduction | 1 line | Low — breaks measured boot |
| 5 | Move heavy services post-login | I/O reduction | optional | Low — services start later |

**The single biggest win is #1 (ClamAV).** It alone accounts for ~89% of the userspace boot time. With that fix, userspace time drops from 19s to ~2s, and total boot from 36s to ~19s.

## Commands for Future Analysis

```bash
systemd-analyze                        # Overall boot time
systemd-analyze blame | head -30       # Top services by time
systemd-analyze critical-chain         # Critical path to default target
systemd-analyze critical-chain graphical.target  # Critical path to graphical
journalctl -b -o short-monotonic       # Full boot timeline (monotonic)
bootctl status                         # Boot loader configuration
```
