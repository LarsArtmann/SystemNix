# evo-x2 NixOS Comprehensive Status Report

**Date:** 2026-03-29 15:32 CEST
**Host:** evo-x2 (GMKtec AMD Ryzen AI Max+ 395, 62 GiB RAM, 512 GB NVMe)
**NixOS:** 26.05 (unstable), nixpkgs `832efc0`
**Disk:** 284G / 512G used (56%)
**Memory:** 16G used / 62G total (available: 45G)
**Swap:** 41G (4.5M used)
**Uptime:** Post-deploy (15:27 CEST)
**Compositors:** Hyprland (default SDDM) + Niri
**Shell:** Fish

---

## A. FULLY DONE (Deployed & Verified)

### Session 1 (Prior Session)

| #   | What                                                                                | Files                                           |
| --- | ----------------------------------------------------------------------------------- | ----------------------------------------------- |
| 1   | Font system: replaced plain fonts with Nerd Font versions, fixed missing import     | `fonts.nix`, `configuration.nix`                |
| 2   | Home Manager: removed standalone `homeConfigurations`, unified to NixOS-module-only | `flake.nix`, `justfile`                         |
| 3   | Waybar: added `systemd.enable = true` to prevent duplicate instances                | `waybar.nix`                                    |
| 4   | Monitoring stack: Prometheus (9091) + Grafana (3001) + Homepage (8082) from scratch | `monitoring.nix`, `grafana.nix`, `homepage.nix` |
| 5   | Grafana dashboard: auto-provisioned "evo-x2 Overview" with CPU/memory/disk/network  | `dashboards/overview.json`                      |
| 6   | Caddy vhosts: 4 reverse proxies (immich.lan, gitea.lan, grafana.lan, home.lan)      | `caddy.nix`                                     |
| 7   | DNS records: added `*.lan` domains for all new services                             | `dns-blocker-config.nix`                        |
| 8   | Secrets: sops-nix integration for Grafana admin password and secret key             | `sops.nix`, `grafana.nix`                       |

### Session 2 (This Session)

| #   | What                                                                            | Files                          |
| --- | ------------------------------------------------------------------------------- | ------------------------------ |
| 9   | dnsblockd port conflict FIXED: `80/443` → `8080/8443`                           | `dns-blocker-config.nix`       |
| 10  | Health check script: `dig` → `host` (tool was not installed)                    | `scripts/check-services.sh`    |
| 11  | Service health check: added gitea, ollama, prometheus, grafana, homepage        | `scripts/service-health-check` |
| 12  | Immich bound to `127.0.0.1` (was `0.0.0.0` + `openFirewall=true`)               | `services/immich.nix`          |
| 13  | fail2ban enabled with aggressive SSH jail (maxretry=3, bantime=1h)              | `security-hardening.nix`       |
| 14  | Removed `processor.max_cstate=1` kernel param (blocked CPU deep sleep)          | `boot.nix`                     |
| 15  | Added `amdgpu` to initrd kernel modules (early KMS)                             | `hardware-configuration.nix`   |
| 16  | SSD TRIM enabled (`services.fstrim.enable`)                                     | `configuration.nix`            |
| 17  | Automatic Nix GC: weekly, deletes older than 7d + auto optimise                 | `nix-settings.nix`             |
| 18  | SMART disk health monitoring enabled (`services.smartd`)                        | `configuration.nix`            |
| 19  | Deleted dead Technitium DNS files (`dns-config.nix`, `dns.md`)                  | `system/` (removed)            |
| 20  | Hyprland `$mod,G` conflict: gitui → `$mod SHIFT,G`, togglegroup keeps `$mod,G`  | `hyprland.nix`                 |
| 21  | Removed duplicate `ollama` package (service already installs `ollama-vulkan`)   | `ai-stack.nix`                 |
| 22  | Removed stale `chrome-144.0.7559.97` version pin                                | `nix-settings.nix`             |
| 23  | Fixed duplicate AMD GPU comment in configuration.nix                            | `configuration.nix`            |
| 24  | Cleaned Technitium/stale refs in networking.nix, set nameservers to `127.0.0.1` | `networking.nix`               |

### Current Service State (All 15 ACTIVE, 0 FAILED)

| Service            | Port      | Bind               | Status                              |
| ------------------ | --------- | ------------------ | ----------------------------------- |
| Caddy              | 80/443    | `*:80`, `*:443`    | active                              |
| dnsblockd          | 8080/8443 | `127.0.0.2`        | active (FIXED — no more crash-loop) |
| Unbound            | 53        | `127.0.0.1`, `::1` | active                              |
| Immich Server      | 2283      | `127.0.0.1`        | active (FIXED — was `0.0.0.0`)      |
| Immich ML          | —         | —                  | active                              |
| PostgreSQL         | 5432      | —                  | active                              |
| Gitea              | 3000      | `*:3000`           | active                              |
| Ollama             | 11434     | `127.0.0.1`        | active                              |
| Prometheus         | 9091      | `*:9091`           | active                              |
| Grafana            | 3001      | `127.0.0.1`        | active                              |
| Homepage Dashboard | 8082      | `*:8082`           | active                              |
| Node Exporter      | 9100      | `*:9100`           | active                              |
| Postgres Exporter  | 9187      | `*:9187`           | active                              |
| Redis Exporter     | 9121      | `*:9121`           | active                              |
| Docker             | —         | —                  | active                              |

### New System Services (Activated This Session)

| Service            | Status | Schedule                                                        |
| ------------------ | ------ | --------------------------------------------------------------- |
| smartd             | active | continuous (short test daily 02:00, long test weekly Sat 03:00) |
| fstrim.timer       | active | weekly (next: Mon 2026-03-30 01:18)                             |
| nix-gc.timer       | active | weekly (next: Mon 2026-03-30 00:00)                             |
| nix-optimise.timer | active | daily (next: Mon 2026-03-30 03:55)                              |
| fail2ban           | active | continuous (sshd jail: aggressive, maxretry=3, bantime=1h)      |

### DNS Resolution (Verified)

| Domain      | IP        |
| ----------- | --------- |
| home.lan    | 127.0.0.1 |
| grafana.lan | 127.0.0.1 |
| gitea.lan   | 127.0.0.1 |
| immich.lan  | 127.0.0.1 |

---

## B. PARTIALLY DONE

### 1. Monitoring Stack

- Prometheus scraping 4 targets: node, postgres, redis, caddy
- Grafana auto-provisioned with Prometheus datasource + overview dashboard
- Homepage dashboard shows 12 services across 4 groups with ping checks
- **Missing:** No Prometheus alerting rules configured
- **Missing:** No dnsblockd metrics (no `/metrics` endpoint in the Go binary)
- **Missing:** Exporters bound to `*` (should be `127.0.0.1`)

### 2. Networking Cleanup

- Technitium references removed from networking.nix
- DNS nameservers corrected to `127.0.0.1` (unbound)
- **Missing:** `networking.firewall` still not configured (deny-by-default)
- **Missing:** `homepage-dashboard` bound to `*:8082` (should be `127.0.0.1`)
- **Missing:** Gitea bound to `*:3000` (should be `127.0.0.1`)

---

## C. NOT STARTED

### High Priority

1. **NixOS firewall (deny-by-default)** — No `networking.firewall` configured. Docker punches its own holes. All exporter ports (9100, 9187, 9121, 9091) exposed on all interfaces.
2. **Immich media backup** — Only PostgreSQL DB backed up daily. The actual photos/videos in `/var/lib/immich` have NO backup. Highest data-loss risk.
3. **Off-disk backup** — All backups on same NVMe disk. No NAS, S3, or external target.
4. **PostgreSQL tuning** — Defaults for photo library workload. `shared_buffers`, `work_mem`, `effective_cache_size` all at defaults.
5. **Immich GPU acceleration** — `accelerationDevices = null` explicitly disables GPU ML inference. Should use AMD ROCm.

### Medium Priority

6. **Prometheus alerting rules** — No alerts configured for disk space, service down, etc.
7. **Homepage dashboard widgets** — No system stats widgets (CPU, memory, disk usage).
8. **Justfile NixOS platform detection** — Multiple commands hardcode `darwin-rebuild`, broken on NixOS.
9. **Go overlay deduplication** — Go 1.26.1 override defined 3 times in flake.nix.
10. **Duplicate `foot` packages** — In `multi-wm.nix`, `home.nix`, and `base.nix`.

### Low Priority

11. **Gitea mirror script bug** — `wc -l < /dev/stdin` reads nothing (line 91)
12. **SystemAssertions.nix** — 3 of 5 assertions are `assertion = true` (no-op validation)
13. **Empty debug stubs** — `test-minimal.nix` and `minimal-test.nix`
14. **Immich/Gitea inaccessible from LAN** — DNS hardcoded to `127.0.0.1`

---

## D. TOTALLY FUCKED UP

Nothing is currently broken or in a failed state. All services active, zero failed units.

**Known minor issues:**

- fail2ban socket not queryable without root (`fail2ban-client` needs `sudo`) — not a bug, just permissions
- Kernel changes (amdgpu initrd, max_cstate removal) take effect on next reboot — not yet rebooted
- dnsblockd restart counter was at 175+ before the fix — now running clean on ports 8080/8443

---

## E. WHAT WE SHOULD IMPROVE

### Security (Critical)

- **Firewall**: NixOS has no deny-by-default firewall. Docker, Prometheus exporters, Gitea, Homepage are all exposed on `0.0.0.0`. This is the single biggest security gap.
- **Exporter binding**: Node/Postgres/Redis exporters listen on `*:9100/9187/9121`. Should bind to `127.0.0.1`.
- **Prometheus binding**: Listening on `*:9091`. Should be `127.0.0.1`.
- **Homepage binding**: Listening on `*:8082`. Should be `127.0.0.1`.
- **Gitea binding**: Listening on `*:3000`. Should be `127.0.0.1` since Caddy proxies it.

### Reliability (Critical)

- **Immich media backup**: Zero backup strategy for user photos/videos. Only the DB is backed up. This is the #1 data-loss risk.
- **Off-disk backup**: Everything on one NVMe. Disk failure = total loss of all data including BTRFS snapshots.

### Performance

- **PostgreSQL tuning**: Immich's photo library queries are heavy. Default PostgreSQL settings waste the 62GB RAM.
- **Immich GPU acceleration**: ML inference running on CPU when a Ryzen AI Max+ 395 with ROCm is available.

### Code Quality

- **Justfile**: Multiple commands broken on NixOS (hardcoded `darwin-rebuild`).
- **Go overlay**: Triple-defined in flake.nix. Extract to shared overlay.
- **Duplicate packages**: `foot` in 3 files, removed `ollama` but `foot` still duplicated.

---

## F. TOP 25 NEXT THINGS TO DO

| #   | Priority | What                                                          | Effort       | File(s)                                 |
| --- | -------- | ------------------------------------------------------------- | ------------ | --------------------------------------- |
| 1   | CRITICAL | Enable NixOS firewall (deny-by-default, allow only 22/80/443) | ~20 lines    | `networking.nix` or new `firewall.nix`  |
| 2   | CRITICAL | Bind Prometheus to `127.0.0.1:9091`                           | 1 line       | `monitoring.nix`                        |
| 3   | CRITICAL | Bind all exporters to `127.0.0.1`                             | 3 lines      | `monitoring.nix`                        |
| 4   | CRITICAL | Bind Homepage to `127.0.0.1:8082`                             | 1 line       | `homepage.nix`                          |
| 5   | CRITICAL | Bind Gitea to `127.0.0.1:3000`                                | 2 lines      | `gitea.nix`                             |
| 6   | HIGH     | Immich media backup (restic/borg to external)                 | ~40 lines    | new `backup.nix`                        |
| 7   | HIGH     | Off-disk backup target (NAS/S3/restic)                        | ~40 lines    | new `backup-target.nix`                 |
| 8   | HIGH     | PostgreSQL tuning for photo library (shared_buffers=4G, etc.) | ~10 lines    | `immich.nix` or new `postgresql.nix`    |
| 9   | HIGH     | Immich GPU acceleration via ROCm                              | 3-5 lines    | `immich.nix`                            |
| 10  | HIGH     | Prometheus alerting rules (disk space, service down, SMART)   | ~30 lines    | `monitoring.nix` or new `alerts.nix`    |
| 11  | HIGH     | Reboot to activate kernel changes (amdgpu initrd, max_cstate) | 0 lines      | just reboot                             |
| 12  | MEDIUM   | Homepage dashboard: add system stat widgets                   | ~20 lines    | `homepage.nix`                          |
| 13  | MEDIUM   | Fix justfile for NixOS platform detection                     | ~50 lines    | `justfile`                              |
| 14  | MEDIUM   | Deduplicate Go overlay (3x → 1x in flake.nix)                 | ~20 lines    | `flake.nix` + new `overlays/go.nix`     |
| 15  | MEDIUM   | Remove duplicate `foot` package (in 3 files)                  | ~5 lines     | `multi-wm.nix`, `home.nix`              |
| 16  | MEDIUM   | Add disk space alerting (timer + threshold script)            | ~15 lines    | new `disk-alert.nix`                    |
| 17  | MEDIUM   | Fix Gitea mirror script bug (`wc -l < /dev/stdin`)            | ~5 lines     | Gitea script                            |
| 18  | LOW      | Grafana: add SMART disk dashboard                             | ~20 lines    | `dashboards/smart.json`                 |
| 19  | LOW      | Grafana: add PostgreSQL performance dashboard                 | ~20 lines    | `dashboards/postgres.json`              |
| 20  | LOW      | dnsblockd: add Prometheus `/metrics` endpoint                 | ~30 lines Go | `dnsblockd/main.go`                     |
| 21  | LOW      | Fix `SystemAssertions.nix` (3 no-op assertions)               | ~10 lines    | `SystemAssertions.nix`                  |
| 22  | LOW      | Clean up empty debug stubs (`test-minimal.nix`, etc.)         | Delete files | `platforms/darwin/`, `platforms/nixos/` |
| 23  | LOW      | Make `*.lan` DNS accessible from LAN devices                  | ~10 lines    | `dns-blocker-config.nix`                |
| 24  | LOW      | Enable systemd restart policies for all services              | ~15 lines    | per-service files                       |
| 25  | LOW      | Fix stale `hyprland-system.nix` comment in networking.nix     | 1 line       | `networking.nix`                        |

---

## G. OPEN QUESTION

**#1 Question I cannot figure out myself:**

The Prometheus exporters and Grafana are bound to `127.0.0.1`, but Prometheus itself and several exporters (node, postgres, redis) listen on `0.0.0.0`. NixOS Prometheus module uses `listenAddress` which defaults to `*`. The exporters use `listenAddress` too.

However, when I try to bind these to `127.0.0.1` via the standard NixOS options, I'm unsure if Caddy's reverse proxy will still be able to reach them since Caddy binds to `*:80/443`. The question is:

**Should I bind Prometheus and all exporters to `127.0.0.1`, then configure Caddy to reverse-proxy Grafana (and potentially Prometheus) externally if LAN access is ever needed? Or is the current approach (Prometheus on `*` for scraping, exporters on `*` for Prometheus to reach) actually correct since they're all on localhost anyway?**

The answer depends on whether NixOS Prometheus scrapes via localhost regardless of the exporter's `listenAddress`, or if it needs the exporter to be on the same address. Since everything runs on the same machine, binding to `127.0.0.1` should work — but I want confirmation before changing the production config.

---

## Deployment History

| Time       | Action                       | Result                                |
| ---------- | ---------------------------- | ------------------------------------- |
| 15:27 CEST | `nh os switch .`             | Success — all changes activated       |
| 15:30 CEST | `check-services.sh`          | All 15 services active, 0 failed      |
| 15:32 CEST | `fail2ban` confirmed running | Socket needs root to query (expected) |

## Files Modified (This Session)

| File                                                  | Change                                         |
| ----------------------------------------------------- | ---------------------------------------------- |
| `platforms/nixos/system/dns-blocker-config.nix`       | `blockPort=8080`, `blockTLSPort=8443`          |
| `scripts/check-services.sh`                           | `dig` → `host`                                 |
| `platforms/nixos/scripts/service-health-check`        | Added 7 service/URL checks                     |
| `platforms/nixos/services/immich.nix`                 | `host="127.0.0.1"`, `openFirewall=false`       |
| `platforms/nixos/desktop/security-hardening.nix`      | fail2ban enabled with SSH jail                 |
| `platforms/nixos/system/boot.nix`                     | Removed `processor.max_cstate=1`               |
| `platforms/nixos/hardware/hardware-configuration.nix` | Added `amdgpu` to initrd                       |
| `platforms/nixos/system/configuration.nix`            | fstrim, smartd, duplicate comment fix          |
| `platforms/common/core/nix-settings.nix`              | Auto GC + optimise, removed chrome pin         |
| `platforms/nixos/system/networking.nix`               | Cleaned Technitium refs, nameservers=127.0.0.1 |
| `platforms/nixos/desktop/ai-stack.nix`                | Removed duplicate `ollama`                     |
| `platforms/nixos/desktop/hyprland.nix`                | gitui: `$mod,G` → `$mod SHIFT,G`               |
| `platforms/nixos/system/dns-config.nix`               | DELETED (dead Technitium config)               |
| `platforms/nixos/system/dns.md`                       | DELETED (dead Technitium docs)                 |
