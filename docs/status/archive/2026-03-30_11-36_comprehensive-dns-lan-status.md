# Comprehensive Project Status Report

**Date:** 2026-03-30 11:36 CEST
**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395) + Lars-MacBook-Air (macOS, nix-darwin)
**Branch:** master (1 commit ahead of origin)
**Last Commit:** `d49ac95` feat(nixos/dns-blocker): bind DNS listener to all interfaces with LAN access

---

## A) FULLY DONE ✅

### Core Infrastructure

- **Flake architecture** — Unified flake.nix with flake-parts, 17 inputs, dual-system outputs (darwin + nixos)
- **NixOS base system** — evo-x2 fully declarative: networking, firewall, users, locales, time zone, garbage collection, store optimization
- **Darwin base system** — Lars-MacBook-Air fully declarative: Catppuccin Mocha theme, Touch ID sudo, Keychain integration, LaunchAgents
- **Home Manager cross-platform** — Shared modules in `platforms/common/` with platform-specific overrides. ~80% code reuse between Darwin and NixOS

### Service Stack (All NixOS, flake-parts dendritic modules)

- **DNS Blocker** — Unbound + dnsblockd + dnsblockd-processor. 15 blocklists (~1.9M domains), Quad9+Cloudflare DoT upstream, DNSSEC, HTTPS block page. **Just fixed: now listens on 0.0.0.0 with 192.168.1.0/24 access** ⬅️ THIS SESSION
- **Caddy reverse proxy** — immich.lan, gitea.lan, grafana.lan, home.lan all routing via Caddy with metrics
- **Gitea** — SQLite, LFS, weekly dump, GitHub mirror every 30min, sops-managed tokens, auto theme
- **Immich** — Full photo management, PostgreSQL tuned (512MB shared_buffers), Redis, ML enabled, daily DB backup
- **Grafana** — Port 3001, Prometheus datasource, custom dashboards, admin creds via sops
- **Homepage dashboard** — Port 8082, dark theme, all services displayed
- **Prometheus** — Port 9091, 30d retention, 4 scrape targets (node, postgres, caddy, redis exporters)
- **SSH** — Hardened: key-only, no root, strong ciphers, MaxAuthTries=3, fail2ban, banner
- **sops-nix** — Age encryption via SSH host key, 5 secrets, template for gitea-sync.env

### Security

- **Firewall** — Default deny, TCP 22/53/80/443, UDP 53 **(TCP 53 just added this session)**
- **AppArmor** — Mandatory access control enabled
- **Fail2ban** — SSH jail, aggressive mode, 3 retries, 1h ban
- **ClamAV** — Daemon + signature updater
- **Gitleaks** — Pre-commit secret detection
- **Security tools** — nmap, lynis, wireshark, masscan, sqlmap, nikto, nuclei, aircrack-ng, sleuthkit, aide, osquery

### DNS (This Session's Fix)

- **Unbound now binds 0.0.0.0** (was 127.0.0.1 only)
- **192.168.1.0/24 allowed** in access-control (was localhost only)
- **TCP port 53 opened** in firewall (was UDP only)
- Local LAN records: immich.lan, gitea.lan, grafana.lan, home.lan → 192.168.1.162

### Desktop (NixOS)

- **Hyprland** — Full Wayland compositor with 10 named workspaces, MD3 animations, kanshi display profiles (TV 4K@30 / 1080@120)
- **Niri** — Wrapped with declarative keybindings via wrapper-modules
- **Waybar** — Status bar configured
- **Dunst** — Catppuccin Mocha themed, font size 16 for TV viewing
- **Kitty** — Font size 16, 85% opacity, for TV viewing
- **Foot** — Lightweight Wayland terminal, Catppuccin Mocha
- **GTK/Qt** — Catppuccin Mocha Compact Lavender Dark, Papirus icons, Bibata cursor
- **Animated wallpaper** — 30s interval, random transitions
- **Rofi, wlogout, hyprlock, hypridle** — All configured

### Development Toolchain

- **Go 1.26.1** — Full toolchain: gopls, golangci-lint, gofumpt, gotests, mockgen, delve, modernize, buf
- **Shell tooling** — Fish + Zsh + Nushell + Bash, Starship prompt, tmux, fzf, zellij
- **Just** — 80+ commands covering build, test, deploy, monitor, DNS, Immich, Go, Node, backup
- **Pre-commit** — 8 hooks: gitleaks, trailing-whitespace, deadnix, statix, alejandra, nix-check, flake-lock-validate, check-merge-conflicts

### Custom Packages

- **dnsblockd** — Go HTTP block page server
- **dnsblockd-processor** — Go build-time blocklist processor
- **modernize** — Go 1.26 code modernization tool
- **superfile** — v1.5.0 terminal file manager
- **aw-watcher-utilization** — ActivityWatch system resource monitor
- **geekbench-ai** — v1.6.0 AI benchmarking

### Documentation

- **145+ status reports** in docs/status/
- **4 Architecture Decision Records** (ADR-001 through ADR-004)
- **Comprehensive AGENTS.md** — AI agent instructions, patterns, troubleshooting
- **Troubleshooting guides**, verification templates, planning docs

---

## B) PARTIALLY DONE 🔧

### DNS LAN Access (This Session — DEPLOYED BUT NOT VERIFIED)

- Config changed: Unbound binds 0.0.0.0, LAN access allowed, firewall TCP 53 open
- **NOT YET TESTED** from external machine — needs `sudo nixos-rebuild switch --flake .#evo-x2` + `dig @192.168.1.162 google.de` from Mac

### AI/ML Stack

- Ollama installed with Vulkan backend, flash attention — ✅
- Python 3.13 with timm/xformers — ✅
- AMD NPU driver loaded but **disabled** (`enable=false`) — needs activation and testing
- ROCm environment variables set — ✅
- No GPU temperature/VRAM monitoring in Grafana — missing

### Darwin (macOS)

- Base system declarative — ✅
- Home Manager working — ✅
- ActivityWatch managed via LaunchAgent — ✅
- uBlock filter management — **DISABLED** (time parsing issues)
- Darwin home.nix has empty packages list — all in common, but could be better organized
- Go overlay defined twice (flake.nix + darwin/default.nix) — duplicate

### Monitoring

- Prometheus + Grafana + exporters — ✅ working
- No alerting rules configured
- No Grafana dashboards for DNS blocker performance
- Homepage dashboard references `localhost:53` for Unbound ping — should now work from LAN

### CI/CD

- GitHub Actions: 3 jobs (check, build-darwin, syntax-check) — ✅
- Cachix integration — ⚠️ inconsistent caches (larsartmann vs petersaluja)
- No NixOS build in CI — only Darwin gets built

---

## C) NOT STARTED ❌

### High Priority

1. **Deploy DNS LAN fix** — Config is ready but `nixos-rebuild switch` not run yet
2. **DNS-over-TLS for LAN clients** — Unbound accepts DoT on 853 but not configured for LAN
3. **DHCP DNS advertisement** — Router needs to advertise 192.168.1.162 as DNS server to LAN clients
4. **Grafana alerting** — No alert rules for disk, CPU, memory, service failures
5. **Automated backups** — No offsite backup strategy (Immich photos, Gitea repos, Grafana dashboards)

### Desktop (NixOS)

6. **Bluetooth** — 8-step setup in TODO_LIST.md, not started
7. **Audio pipewire** — Not configured
8. **Gaming** — Not started
9. **Window rules** — Hyprland window rules for specific apps not defined

### Infrastructure

10. **NixOS automated testing** — No NixOS VM tests
11. **Secret rotation** — No rotation strategy for sops secrets
12. **IPv6** — Completely disabled, no plan for re-enablement
13. **NPU activation** — AMD XDNA NPU present but disabled
14. **DNS-over-HTTPS server** — Could serve DoH to LAN clients with unbound

### Documentation

15. **API documentation** — No docs for dnsblockd HTTP API
16. **Runbook** — No operational runbook for common incidents
17. **Architecture diagram** — SVG exists for Darwin but not NixOS

---

## D) TOTALLY FUCKED UP 💥

### Broken/Blocked

1. **superfile.nix vendorHash=null** — Will fail on first build. Needs manual hash insertion after first attempted build.
2. **Auditd disabled** — Blocked by NixOS bug #483085 (AppArmor conflicts). No workaround available.
3. **Hyprland plugins (hy3, hyprsplit)** — Incompatible with Hyprland 0.54.2. Disabled, no fix available.
4. **uBlock filters** — "Temporarily disabled due to time parsing issues" — unclear when this broke or how to fix.
5. **Home Manager issue XXXX** — Placeholder reference in `darwin/default.nix:85` never replaced with actual issue number.
6. **Sublime sync LaunchAgent** — References `~/projects/SystemNix/scripts/` which may be wrong path (repo is `Setup-Mac`).
7. **CI Cachix cache mismatch** — check job pushes to `larsartmann`, build-darwin pushes to `petersaluja`. Probably a leftover from fork/copy.

### Tech Debt

8. **145+ status report files** — Massive documentation bloat. Most should be archived.
9. **Go overlay duplication** — Same Go 1.26 overlay defined in both flake.nix and darwin/default.nix.
10. **227-line TODO_LIST.md** — 75+ items, many stale, needs triage.
11. **Stale scripts** — `scripts/archive/` has removed functionality that may or may not still be referenced.
12. **Gitea dump interval** — Comment says "weekly" but no explicit `dump.interval` set (uses default daily).

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Extract DNS listen config** — The interface/access-control should be options in the dns-blocker module, not hardcoded. Site config should set `listenInterfaces` and `allowedNetworks`.
2. **Unify Go overlay** — Single definition, imported by both darwin and nixos. Current duplication is a maintenance trap.
3. **Consolidate docs/status/** — Archive everything older than 2 weeks. Keep only the latest comprehensive report.
4. **Add NixOS build to CI** — Currently only Darwin gets built. evo-x2 should also be checked.

### DNS/Network

5. **Router DNS delegation** — Configure router DHCP to hand out 192.168.1.162 as primary DNS. Currently every client uses its own resolver.
6. **DNS-over-TLS for LAN** — Unbound can serve DoT on port 853. Enable for clients that support it.
7. **Split-horizon DNS** — Consider separate views for LAN vs localhost queries.

### Monitoring

8. **Grafana alert rules** — Disk space, CPU, memory, service down, DNS query failures.
9. **DNS performance dashboard** — Query rate, cache hit ratio, block rate, upstream latency.
10. **Uptime monitoring** — External ping checks for critical services.

### Security

11. **Secret rotation** — Automated sops secret rotation strategy.
12. **Network segmentation** — Consider VLANs for IoT devices (Samsung, Xiaomi, LG WebOS telemetry is blocked, but devices are on same network).
13. **Auditd re-enablement** — Track NixOS bug #483085 and re-enable when fixed.

### Development

14. **NixOS VM tests** — Test service configuration in isolated VMs.
15. **superfile hash fix** — Actually build it once and fill in the vendorHash.
16. **Clean TODO_LIST.md** — Triage 75+ items, remove completed/stale, prioritize remaining.

---

## F) TOP 25 THINGS TO DO NEXT 🎯

| #   | Priority | Task                                                               | Effort  | Impact |
| --- | -------- | ------------------------------------------------------------------ | ------- | ------ |
| 1   | **P0**   | Deploy DNS LAN fix (`nixos-rebuild switch`) and verify from Mac    | 5min    | HIGH   |
| 2   | **P0**   | Configure router DHCP to advertise 192.168.1.162 as DNS server     | 10min   | HIGH   |
| 3   | **P0**   | Fix superfile.nix vendorHash — build once, insert real hash        | 15min   | MEDIUM |
| 4   | **P1**   | Add Grafana alerting rules (disk, CPU, memory, service down)       | 2h      | HIGH   |
| 5   | **P1**   | Archive old docs/status/ files (keep last 2 weeks only)            | 30min   | MEDIUM |
| 6   | **P1**   | Unify Go overlay (remove duplication between flake.nix and darwin) | 1h      | MEDIUM |
| 7   | **P1**   | Extract DNS listen/allow options in dns-blocker module             | 1h      | MEDIUM |
| 8   | **P1**   | Fix CI Cachix cache inconsistency (use single cache)               | 30min   | MEDIUM |
| 9   | **P1**   | Fix Sublime sync LaunchAgent path (SystemNix → Setup-Mac)          | 15min   | LOW    |
| 10  | **P1**   | Add NixOS build job to GitHub Actions CI                           | 1h      | HIGH   |
| 11  | **P2**   | Triage TODO_LIST.md — remove stale items, prioritize remaining     | 1h      | MEDIUM |
| 12  | **P2**   | Enable AMD NPU and test with Ollama                                | 2h      | HIGH   |
| 13  | **P2**   | Create DNS performance Grafana dashboard                           | 2h      | MEDIUM |
| 14  | **P2**   | Configure NixOS Bluetooth (8 steps in TODO)                        | 1h      | MEDIUM |
| 15  | **P2**   | Fix uBlock filter time parsing issue and re-enable                 | 1h      | LOW    |
| 16  | **P2**   | Set up automated offsite backup for Immich photos                  | 3h      | HIGH   |
| 17  | **P2**   | Replace Home Manager issue XXXX placeholder with real number       | 5min    | LOW    |
| 18  | **P2**   | Add Gitea explicit dump.interval = "weekly" to match comment       | 5min    | LOW    |
| 19  | **P3**   | Enable DNS-over-TLS on port 853 for LAN clients                    | 1h      | MEDIUM |
| 20  | **P3**   | Create NixOS architecture diagram (like Darwin's SVG)              | 2h      | MEDIUM |
| 21  | **P3**   | Write operational runbook for common incidents                     | 3h      | HIGH   |
| 22  | **P3**   | Set up VLAN for IoT devices (Samsung, Xiaomi, LG)                  | 4h      | HIGH   |
| 23  | **P3**   | Add NixOS VM tests for critical services                           | 4h      | HIGH   |
| 24  | **P3**   | Document dnsblockd HTTP API                                        | 2h      | LOW    |
| 25  | **P3**   | Track NixOS bug #483085 and re-enable auditd when fixed            | ongoing | MEDIUM |

---

## G) MY TOP #1 QUESTION ❓

**What is the primary use case for this machine?** Is evo-x2 a:

- **Homelab server** (headless, services-first, accessed remotely)?
- **Desktop workstation** (connected to TV, Hyprland GUI, daily driver)?
- **Both** (used as desktop with services running in background)?

This matters because the current config tries to be both — Hyprland with TV-optimized fonts AND a full service stack with Grafana/Gitea/Immich. The DNS fix I just did is server-first thinking. But the Hyprland config with animated wallpapers and dunst at font-size-16 says "living room media PC." The priorities for what to do next shift dramatically depending on the answer.

---

## Session Changes

### Files Modified This Session

| File                                      | Change                                    |
| ----------------------------------------- | ----------------------------------------- |
| `platforms/nixos/modules/dns-blocker.nix` | Bind to 0.0.0.0/::0, allow 192.168.1.0/24 |
| `platforms/nixos/system/networking.nix`   | Add TCP port 53 to firewall               |

### Commits This Session

| Hash      | Message                                                                      |
| --------- | ---------------------------------------------------------------------------- |
| `d49ac95` | feat(nixos/dns-blocker): bind DNS listener to all interfaces with LAN access |

---

_Generated: 2026-03-30 11:36 CEST_
