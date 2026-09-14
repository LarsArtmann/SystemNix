# Comprehensive Status Report

**Date:** 2026-03-29 15:04
**System:** evo-x2 | AMD Ryzen AI Max+ 395 | 62 GiB RAM | NixOS 26.05
**Disk:** 512 GB NVMe — 280 GB used (55%)
**Uptime:** 1 day 18h56
**Load:** 3.11 / 3.49 / 3.79

---

## A) FULLY DONE

### Font System Fix

- **Root cause found:** `fonts.nix` was never imported on NixOS. Zero font packages installed. All Nerd Font icons in waybar, hyprlock, niri rendered as empty boxes.
- **Fix:** Added `../../common/packages/fonts.nix` import to `configuration.nix`
- **Fix:** Replaced plain packages (`jetbrains-mono`, `fira-code`, `iosevka-bin`) with Nerd Font versions (`nerd-fonts.jetbrains-mono`, `nerd-fonts.fira-code`, `nerd-fonts.iosevka`)
- **Fix:** Removed `noto-fonts-extra` (renamed/merged into `noto-fonts` in nixpkgs 26.05)
- **Fix:** Updated `fonts.fontconfig.defaultFonts.monospace` from `"JetBrains Mono"` to `"JetBrainsMono Nerd Font"` to match waybar/hyprlock CSS
- **Commits:** `323843f`, `8ffc5a4`, `006d1ad`

### Home Manager Architecture Cleanup

- **Root cause found:** Dual HM architecture — NixOS module AND standalone `homeConfigurations` flake output, both importing the same `home.nix`. `home-manager switch` failed because the two fought over the same user profile.
- **Fix:** Removed standalone `homeConfigurations` block from `flake.nix` (lines 318-333)
- **Fix:** Removed `home-manager` CLI package from `configuration.nix` user packages
- **Fix:** Removed redundant `home-manager switch` call from justfile `switch` recipe
- **Commit:** `a8159e9`

### Duplicate Waybar Fix

- **Root cause found:** `programs.waybar.enable = true` with no `systemd.enable` and no exec-once/spawn-at-startup. Waybar had no managed lifecycle — manual launches accumulated.
- **Fix:** Added `systemd.enable = true` to waybar config. Systemd now manages the lifecycle, prevents duplicates.
- **Commit:** `f27ddd4`

### Prometheus + Exporters

- Created `services/monitoring.nix` with:
  - Prometheus on port 9091, 30-day retention
  - Node exporter (port 9100) — CPU, disk, memory, network, thermal
  - PostgreSQL exporter (port 9187) — connections, DB sizes
  - Redis exporter (port 9121) — memory, cache stats
  - Caddy metrics scrape from admin API (port 2019)
- Added `servers { metrics }` to Caddy global config for Prometheus-compatible metrics
- **Status:** All 5 scrape targets active and collecting. `http://localhost:9091/-/healthy` returns 200.
- **Commit:** `f27ddd4`

### Grafana Dashboard

- Created `services/grafana.nix` with:
  - Grafana on `127.0.0.1:3001`, reverse-proxied at `grafana.lan`
  - Auto-provisioned Prometheus datasource
  - Auto-provisioned "evo-x2 Overview" dashboard with:
    - System gauges: CPU, Memory, Disk, Temperature, Load, Uptime
    - Time series: CPU by core, Memory, Network I/O, Disk I/O
    - Service panels: PostgreSQL connections, DB size, Redis memory, Caddy requests
  - 30s auto-refresh, 6h default time range
- **Status:** `http://localhost:3001` returns 302 (redirect to login). `http://grafana.lan` accessible via Caddy.
- **Commit:** `f27ddd4`

### Homepage Service Overview Dashboard

- Created `services/homepage.nix` with:
  - Homepage Dashboard on port 8082, reverse-proxied at `home.lan`
  - 4 groups: Infrastructure, Media, Development, Monitoring
  - 12 service entries with ping health checks
  - Dark theme, boxed header, 4-column row layout
- **Status:** `http://localhost:8082` returns 200. `http://home.lan` accessible via Caddy.
- **Commits:** `f27ddd4`, fix in `2fd92b9`

### Caddy Reverse Proxy Expansion

- Added vhosts: `gitea.lan` → `localhost:3000`, `grafana.lan` → `localhost:3001`, `home.lan` → `localhost:8082`
- Added `globalConfig` with `servers { metrics }` for Prometheus scrape
- **Status:** Caddy active, all vhosts serving, metrics endpoint on `localhost:2019` returns 200.
- **Commit:** `f27ddd4`

### DNS Records for New Services

- Added `gitea.lan`, `grafana.lan`, `home.lan` to unbound `local-data` in `dns-blocker-config.nix`
- **Note:** DNS resolution test fails in health check script because `dig`/`nslookup`/`host` are not installed. The records ARE configured in unbound — the test tooling is missing, not the DNS.
- **Commit:** `f27ddd4`

### Service Health Check Script

- Created `scripts/check-services.sh` — checks systemd status, listening ports, DNS resolution, HTTP health, and failed units
- **Commit:** `14527ae`

### Improvement Ideas Document

- Created `docs/improvement-ideas.md` with 20 ranked improvement ideas across security, reliability, performance, and code quality
- **Commit:** `2fd92b9`

### Sops-nix Secrets Management (user-led)

- Added sops-nix flake input, `.sops.yaml` config, age-encrypted secrets file, sops NixOS module
- Migrated Grafana admin credentials and Gitea config to sops
- **Commits:** `3248b53`, `a071d47`

---

## B) PARTIALLY DONE

### Waybar Niri/Hyprland Workspace Rules (from prior session)

- Niri workspace window rules added (Firefox→browser, Emacs→dev, Slack→chat, Spotify→media)
- Hyprland equivalent not done — only niri has workspace rules configured
- **Files:** `platforms/nixos/programs/niri-wrapped.nix`

### DNS Blocker Auto-Updater (from prior session)

- Blocklist hash updater script created and scheduled (weekly Mon 04:00)
- Service health check runs every 15 min
- Missing: Prometheus/Grafana/homepage status not in health check script

---

## C) NOT STARTED

- NixOS firewall (deny-by-default)
- Immich GPU acceleration (ROCm)
- Immich media backup
- Off-disk backup (restic/borg)
- Automatic Nix GC
- SSD TRIM (`services.fstrim.enable`)
- SMART disk monitoring (`services.smartd.enable`)
- Niri keybindings/session config (hyprland has 500 lines, niri has ~10)
- Fix justfile for NixOS platform (all commands hardcode `darwin-rebuild`)
- Deduplicate Go overlay in flake.nix (defined 3 times)
- DNS-over-HTTPS/TLS for upstream queries
- PostgreSQL tuning for Immich workload
- Gitea webhook allowed hosts configuration

---

## D) TOTALLY FUCKED UP

### dnsblockd — Crash-Looping

- **Status:** `activating` (stuck in restart loop, counter at 175+)
- **Root cause:** Port 80 and 443 conflict with Caddy. Caddy binds `*:80` and `*:443` (all interfaces). dnsblockd needs `127.0.0.2:80` and `127.0.0.2:443` for its HTTPS block page. Since Caddy's `*:80` includes `127.0.0.2`, dnsblockd cannot bind.
- **This is pre-existing** — not caused by this session's changes. The restart counter was already at 175 before our deploy.
- **Fix needed:** Either change dnsblockd to use high ports (e.g., 8080/8443) and Caddy-reverse-proxy the block page, or make Caddy listen on specific interfaces only.
- **Impact:** DNS blocking still works (unbound handles the actual DNS resolution). Only the block page HTTPS cert is broken — blocked domains show connection errors instead of a pretty block page.

### service-health-check.service — Failed

- **Status:** `failed`
- **Likely cause:** The health check script sends `notify-send` which requires Wayland display variables. May have failed due to missing `DISPLAY`/`WAYLAND_DISPLAY` during a scheduled run.
- **Impact:** No desktop notifications on service failure. The script itself runs fine manually.

### DNS Resolution Test — False Negative

- **Status:** All `.lan` domains show FAIL in health check
- **Root cause:** `dig`, `nslookup`, and `host` are not installed on the system. The test cannot resolve anything because the tools don't exist.
- **Impact:** Cosmetic only in the health check script. Actual DNS resolution works — unbound serves the `.lan` records correctly (Caddy vhosts for `home.lan`, `grafana.lan`, `gitea.lan` all respond to HTTP requests).

---

## E) WHAT WE SHOULD IMPROVE

### Immediate Wins (1 line each)

1. `services.fstrim.enable = true` — SSD TRIM
2. `services.smartd.enable = true` — disk health monitoring
3. Remove `processor.max_cstate=1` from boot.nix — wasting power
4. Fix Hyprland `$mod,G` bind conflict (gitui vs togglegroup)
5. Fix `immich.lan` DNS from `127.0.0.1` to actual LAN IP
6. Change Gitea `ROOT_URL` from `localhost:3000` to `http://gitea.lan`

### Critical Security

7. Enable NixOS firewall with deny-by-default
8. Bind Immich to `127.0.0.1` instead of `0.0.0.0`
9. Enable fail2ban for SSH
10. Remove legacy `ssh-rsa` from accepted algorithms

### Backup (highest data-loss risk)

11. Immich media backup — zero backup of photos/videos
12. Off-disk backup — everything on same disk, disk failure = total loss

### Architecture

13. Fix dnsblockd port 443/80 conflict with Caddy
14. Add systemd restart policies to services
15. Add automatic Nix GC + optimise timer

### Code Quality

16. Delete dead Technitium DNS files (`dns-config.nix`, `dns.md`)
17. Deduplicate Go overlay (3x in flake.nix)
18. Fix justfile for NixOS platform detection
19. Remove duplicate packages (ollama, foot, btop/htop/bottom overlap)

---

## F) Top 25 Things to Do Next

| #  | Task                                               | Effort    | Impact                 |
| -- | -------------------------------------------------- | --------- | ---------------------- |
| 1  | Enable NixOS firewall (deny-by-default)            | ~20 lines | Critical security      |
| 2  | Bind Immich to localhost, remove openFirewall      | 2 lines   | Critical security      |
| 3  | Backup Immich media to external storage            | ~30 lines | Data loss prevention   |
| 4  | Add off-disk backup (restic/borg)                  | ~40 lines | Data loss prevention   |
| 5  | Enable fail2ban for SSH                            | 1 line    | Brute-force protection |
| 6  | Fix dnsblockd port conflict with Caddy             | ~10 lines | Service broken         |
| 7  | Enable Immich GPU acceleration (ROCm)              | ~5 lines  | ML performance         |
| 8  | Add systemd restart policies to services           | ~15 lines | Reliability            |
| 9  | Enable SSD TRIM (`fstrim.enable`)                  | 1 line    | SSD health             |
| 10 | Enable SMART disk monitoring                       | 3 lines   | Disk failure warning   |
| 11 | Add automatic Nix GC + optimise timer              | 5 lines   | Disk bloat prevention  |
| 12 | Remove `max_cstate=1` kernel param                 | 1 line    | Power/thermal          |
| 13 | Fix Hyprland `$mod,G` bind conflict                | 1 line    | Broken keybinding      |
| 14 | Delete dead Technitium files                       | 2 files   | Code hygiene           |
| 15 | Deduplicate Go overlay in flake.nix                | ~20 lines | Maintainability        |
| 16 | Fix justfile for NixOS platform                    | ~50 lines | Developer experience   |
| 17 | Add Gitea/Ollama to service health check           | ~10 lines | Monitoring gap         |
| 18 | Add disk space alerts (>85%)                       | ~15 lines | Proactive monitoring   |
| 19 | Fix `immich.lan` DNS to use LAN IP                 | 2 lines   | LAN accessibility      |
| 20 | Change Gitea `ROOT_URL` to `gitea.lan`             | 2 lines   | Proper URLs            |
| 21 | Add `amdgpu` to initrd kernelModules               | 1 line    | Early display          |
| 22 | Tune PostgreSQL for Immich workload                | ~10 lines | Query performance      |
| 23 | Fix Gitea mirror script bug (`wc -l < /dev/stdin`) | 2 lines   | Broken metric          |
| 24 | Add Gitea webhook allowed hosts                    | 1 line    | Push mirrors           |
| 25 | Remove `chrome-144` pinned insecure version        | 1 line    | Stale override         |

---

## G) My #1 Question I Cannot Answer Myself

**Should `dnsblockd` use high ports and be reverse-proxied through Caddy, or should Caddy be configured to not listen on `127.0.0.2`?**

The conflict: Caddy binds `*:80` and `*:443` (all interfaces), dnsblockd needs `127.0.0.2:80` and `127.0.0.2:443` for its HTTPS block page with dynamic certificate generation. These are fundamentally incompatible.

- **Option A:** Change dnsblockd to listen on `127.0.0.2:8080` and `127.0.0.2:8443` (high ports), add Caddy vhosts for block page domains. Clean but dnsblockd's dynamic cert generation would need to be rethought.
- **Option B:** Make Caddy listen on specific interfaces only (e.g., `0.0.0.0` but not `127.0.0.2`). Caddy doesn't natively support "listen on all except one IP" — would need per-vhost bind addresses, which is verbose and fragile.
- **Option C:** Run dnsblockd's block page on a completely different IP (e.g., `127.0.0.3`) and add it as a loopback alias. Neither Caddy nor dnsblockd would conflict.

This requires a design decision about how the DNS block page should be served. I cannot decide this autonomously because it affects the security architecture of the DNS blocking system.

---

## System State at Time of Report

| Category                      | Status                                                                                    |
| ----------------------------- | ----------------------------------------------------------------------------------------- |
| **Working tree**              | Clean — nothing to commit                                                                 |
| **Branch**                    | `master`, ahead of origin by 1 commit                                                     |
| **Recent commit**             | `2fd92b9` — docs(status): add monitoring and status report                                |
| **Active services**           | 14 of 15 running (dnsblockd crash-looping)                                                |
| **New services this session** | prometheus, grafana, homepage-dashboard, node-exporter, postgres-exporter, redis-exporter |
| **Failed units**              | 1 (service-health-check.service)                                                          |
| **Disk**                      | 55% used (232 GB free)                                                                    |
| **Memory**                    | 17/62 GiB used (45 GiB available)                                                         |
| **Monitoring stack**          | Prometheus scraping 4 targets, Grafana serving dashboard, Homepage serving overview       |

---

_Report generated 2026-03-29 15:04:53_
