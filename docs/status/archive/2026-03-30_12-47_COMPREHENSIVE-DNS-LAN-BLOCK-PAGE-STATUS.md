# Comprehensive DNS LAN Block Page Status Report

**Date:** 2026-03-30 12:47 CEST
**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395) + Lars-MacBook-Air (macOS, nix-darwin)
**Branch:** master
**Last Commit:** `f5be829` docs: resolve Home Manager issue reference and clean up status report formatting

---

## Executive Summary

DNS blocking works for LAN queries — blocked domains resolve via unbound. However the **block page is invisible to LAN devices** because blocked domains resolve to `127.0.0.2` (loopback-only). The fix (virtual LAN IP `192.168.1.163`) has been coded and committed but **not yet deployed** to evo-x2.

---

## A) FULLY DONE

### Core Infrastructure

- **Flake architecture** — Unified flake.nix with flake-parts, 16 inputs, dual-system outputs (darwin + nixos)
- **NixOS base system** — evo-x2 fully declarative: networking, firewall, users, locales, time zone, garbage collection, store optimization
- **Darwin base system** — Lars-MacBook-Air fully declarative: Catppuccin Mocha theme, Touch ID sudo, Keychain integration, LaunchAgents
- **Home Manager cross-platform** — Shared modules in `platforms/common/` with platform-specific overrides. ~80% code reuse between Darwin and NixOS

### Service Stack (All NixOS, flake-parts dendritic modules)

- **DNS Blocker** — Unbound + dnsblockd + dnsblockd-processor. 15 blocklists (~1.9M domains), Quad9+Cloudflare DoT upstream, DNSSEC, HTTPS block page with dynamic per-domain TLS certs. Module system with `blockInterface`, `blockIPPrefix` options for flexible deployment.
- **Caddy reverse proxy** — immich.lan, gitea.lan, grafana.lan, home.lan all routing via Caddy bound to `192.168.1.162` (avoids port conflict with dnsblockd on `192.168.1.163`)
- **Gitea** — SQLite, LFS, weekly dump, GitHub mirror every 30min, sops-managed tokens, auto theme
- **Immich** — Full photo management, PostgreSQL tuned (512MB shared_buffers), Redis, ML enabled, daily DB backup
- **Grafana** — Port 3001, Prometheus datasource, custom dashboards, admin creds via sops
- **Homepage dashboard** — Port 8082, dark theme, all services displayed
- **Prometheus** — Port 9091, 30d retention, 4 scrape targets (node, postgres, caddy, redis exporters)
- **SSH** — Hardened: key-only, no root, strong ciphers, MaxAuthTries=3, fail2ban, banner
- **sops-nix** — Age encryption via SSH host key, 5 secrets, template for gitea-sync.env

### Security

- **Firewall** — Default deny, TCP 22/53/80/443, UDP 53
- **AppArmor** — Mandatory access control enabled
- **Fail2ban** — SSH jail, aggressive mode, 3 retries, 1h ban
- **ClamAV** — Daemon + signature updater
- **Gitleaks** — Pre-commit secret detection
- **Security tools** — nmap, lynx, wireshark, masscan, sqlmap, nikto, nuclei, aircrack-ng, sleuthkit, aide, osquery

### DNS Blocker Module Architecture

- **Module** (`platforms/nixos/modules/dns-blocker.nix`) — 286 lines, fully optionized NixOS module
  - `blockInterface` option (default: `lo`) — interface for block IP
  - `blockIPPrefix` option (default: `8`) — prefix length
  - `blockIP` option (default: `127.0.0.2`) — sinkhole IP
  - `blockPort` / `blockTLSPort` — HTTP/HTTPS ports
  - `statsPort` — localhost-only stats API
  - `blocklists`, `whitelist`, `categories`, `upstreamDNS`, `enableDNSSEC`
  - Auto-adds virtual IP via `ExecStartPre` for non-loopback interfaces
  - Uses `network-online.target` for reliable ordering
- **Go block page server** (`platforms/nixos/programs/dnsblockd/main.go`) — 875 lines
  - HTTP + HTTPS block pages with styled HTML
  - Dynamic TLS cert generation per blocked domain (signed by dnsblockd CA)
  - APIs: `/api/allow` (temp bypass 5m/15m/1h), `/api/report` (false positive)
  - Stats API on `127.0.0.1:9090` with top domains, recent blocks, uptime
- **Go blocklist processor** (`pkgs/dnsblockd-processor/main.go`) — 155 lines
  - Converts hosts-format blocklists to Unbound `local-data:` entries
  - Deduplicates across all lists, respects whitelist
  - Outputs `unbound.conf` + `mapping.json` (domain to source blocklist name)
- **CA cert** (`pkgs/dnsblockd-cert.nix`) — Build-time OpenSSL CA generation
  - Installed system-wide + into Firefox/NSS databases
- **Site config** (`platforms/nixos/system/dns-blocker-config.nix`) — 168 lines
  - `blockIP = "192.168.1.163"`, `blockInterface = "enp1s0"`, ports 80/443
  - 15 blocklists from HaGeZi and StevenBlack
  - Whitelist: immich, github, openstreetmap domains
  - Category mappings for block page UI
  - Local DNS records: immich.lan, gitea.lan, grafana.lan, home.lan -> 192.168.1.162

### DNS LAN Access (Code Complete, Not Yet Deployed)

- Unbound binds `0.0.0.0` with `192.168.1.0/24` access control
- DNS queries work from LAN: `dig @192.168.1.162 pornhub.com` returns `192.168.1.163` (after deploy)
- dnsblockd will listen on `192.168.1.163:80` (HTTP) + `:443` (HTTPS) for block pages
- Caddy restricted to `192.168.1.162` only — no port conflict
- Stats API stays on `127.0.0.1:9090` (waybar, health checks)
- Waybar DNS widget fixed to use `127.0.0.1:9090` (was incorrectly pointing to `127.0.0.2:9090`)
- Health check scripts fixed to use `127.0.0.1:9090`
- Justfile dns-test updated to expect `192.168.1.163` as block response

### Desktop (NixOS)

- **Hyprland** — Full Wayland compositor with 10 named workspaces, MD3 animations, kanshi display profiles (TV 4K@30 / 1080@120)
- **Niri** — Wrapped with declarative keybindings via wrapper-modules
- **Waybar** — Status bar with DNS stats widget
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

### Custom Packages (6 total)

- **dnsblockd** — Go HTTP block page server (875 lines, zero dependencies)
- **dnsblockd-processor** — Go build-time blocklist processor (155 lines, zero dependencies)
- **modernize** — Go 1.26 code modernization tool (built with Go 1.26rc2 via flake-parts)
- **superfile** — v1.5.0 terminal file manager
- **aw-watcher-utilization** — ActivityWatch system resource monitor
- **geekbench-ai** — v1.6.0 AI benchmarking

### Documentation

- **131+ status reports** in docs/status/
- **4 Architecture Decision Records** (ADR-001 through ADR-004)
- **Comprehensive AGENTS.md** — AI agent instructions, patterns, troubleshooting

---

## B) PARTIALLY DONE

### DNS LAN Block Pages (Code Done, Not Deployed)

- Config committed: `blockIP = "192.168.1.163"`, `blockInterface = "enp1s0"`, ports 80/443
- Module properly adds virtual IP via `ExecStartPre` with `network-online.target`
- **BLOCKED**: Needs `sudo nixos-rebuild switch --flake .#evo-x2` on evo-x2
- **NOT TESTED** from LAN — needs verification after deploy:
  ```bash
  dig @192.168.1.162 pornhub.com    # should return 192.168.1.163
  curl http://192.168.1.163         # should show block page
  ```

### AI/ML Stack

- Ollama installed with Vulkan backend, flash attention
- Python 3.13 with timm/xformers
- AMD NPU driver loaded but **disabled** (`enable=false`) — needs activation and testing
- ROCm environment variables set
- No GPU temperature/VRAM monitoring in Grafana

### Darwin (macOS)

- Base system declarative
- Home Manager working
- ActivityWatch managed via LaunchAgent
- uBlock filter management — **DISABLED** (time parsing issues)
- Go overlay defined twice (flake.nix + darwin/default.nix) — duplicate

### Monitoring

- Prometheus + Grafana + exporters — working
- No alerting rules configured
- No Grafana dashboards for DNS blocker performance
- Homepage dashboard references DNS Blocker as monitored service

### CI/CD

- GitHub Actions: 3 jobs (check, build-darwin, syntax-check)
- Cachix integration — inconsistent caches (larsartmann vs petersaluja)
- **No NixOS build in CI** — only Darwin gets built

---

## C) NOT STARTED

### High Priority

1. **Deploy DNS LAN fix** — Config is ready, needs `nixos-rebuild switch`
2. **Router DHCP DNS** — Configure router to advertise `192.168.1.162` as DNS server to all LAN clients
3. **Grafana alerting** — No alert rules for disk, CPU, memory, service failures
4. **Automated backups** — No offsite backup strategy (Immich photos, Gitea repos, Grafana dashboards)

### Desktop (NixOS)

5. **Bluetooth** — 8-step setup in TODO_LIST.md, not started
6. **Audio pipewire** — Not configured
7. **Gaming** — Not started
8. **Window rules** — Hyprland window rules for specific apps not defined

### Infrastructure

9. **NixOS automated testing** — No NixOS VM tests
10. **Secret rotation** — No rotation strategy for sops secrets
11. **IPv6** — Completely disabled, no plan for re-enablement
12. **NPU activation** — AMD XDNA NPU present but disabled
13. **DNS-over-HTTPS server** — Could serve DoH to LAN clients with unbound

### Documentation

14. **API documentation** — No docs for dnsblockd HTTP API
15. **Runbook** — No operational runbook for common incidents
16. **Architecture diagram** — SVG exists for Darwin but not NixOS

---

## D) TOTALLY FUCKED UP

### Broken/Blocked

1. **superfile.nix vendorHash=null** — Will fail on first build. Needs manual hash insertion after first attempted build. The comment claims "Nix computes it automatically" but `vendorHash = null` means "no vendor dir" which is wrong for a Go project with dependencies.
2. **auditd disabled** — Blocked by NixOS bug #483085 (AppArmor conflicts). Two TODOs in `security-hardening.nix` (lines 14, 21). No workaround available.
3. **Hyprland plugins (hy3, hyprsplit)** — Incompatible with Hyprland 0.54.2. Disabled, no fix available.
4. **uBlock filters** — "Temporarily disabled due to time parsing issues" — unclear when this broke or how to fix.
5. **Sublime sync LaunchAgent** — References `~/projects/SystemNix/scripts/` which is wrong path (repo is `Setup-Mac`).
6. **CI Cachix cache mismatch** — check job pushes to `larsartmann`, build-darwin pushes to `petersaluja`. Leftover from fork/copy.
7. **SSH AllowUsers includes "art"** — `ssh.nix:27` has `AllowUsers = ["lars" "art"]` — is "art" a real user or leftover?
8. **CA private key in Nix store** — `dnsblockd-cert.nix:14` generates `dnsblockd-ca.key` into world-readable `/nix/store`. Any local user can read the CA key and forge trusted certificates.

### Tech Debt

9. **131+ status report files** — Massive documentation bloat in `docs/status/`. Most should be archived.
10. **Go overlay duplication** — Same Go 1.26 overlay defined in both `flake.nix:103-111` and `darwin/default.nix:64-80`. Darwin version also adds `golangci-lint` override missing from NixOS.
11. **dnsblockd package built twice** — Built in `perSystem.packages` for Linux AND in `dnsblockdOverlay`. Identical source filters.
12. **Legacy Technitium DNS config** — `platforms/nixos/private-cloud/dns.nix` with `openFirewall = true` is dead code (not imported anywhere).
13. **Legacy dns-blocklist.nix** — `pkgs/dns-blocklist.nix` is pure-Nix blocklist processor, superseded by Go `dnsblockd-processor`. Not imported anywhere.
14. **227-line TODO_LIST.md** — 75+ items, many stale, needs triage.
15. **Stale scripts** — `scripts/` has 55 scripts, many potentially broken: `fix-dns.sh` (predates dnsblockd), `fix-network-deep.sh` (predates current dhcpcd setup), `automation-setup.sh`, `check-services.sh`.
16. **Gitea dump interval** — Comment says "weekly" but no explicit `dump.interval` set (uses default daily).
17. **Duplicate firewall rules** — Caddy module opens TCP 80/443, networking.nix also opens them. Harmless but redundant.
18. **Justfile tmux-dev path** — References `~/projects/SystemNix` which may not exist.
19. **wrapper-modules input declared but unused** — `flake.nix:21` declares the input but no module references it.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **Extract DNS listen config** — The interface/access-control should be options in the dns-blocker module, not hardcoded. Site config should set `listenInterfaces` and `allowedNetworks`. Partially done (blockInterface/blockIPPrefix are options) but unbound access-control is still hardcoded to `192.168.1.0/24`.
2. **Unify Go overlay** — Single definition, imported by both darwin and nixos. Current duplication is a maintenance trap. Darwin overlay also has `golangci-lint` override missing from NixOS.
3. **Deduplicate dnsblockd package** — Built twice (perSystem.packages + overlay). Use one or the other.
4. **Remove legacy Technitium DNS** — Delete `platforms/nixos/private-cloud/dns.nix` and related docs.
5. **Remove legacy dns-blocklist.nix** — Delete `pkgs/dns-blocklist.nix` (superseded by Go processor).
6. **Remove unused wrapper-modules input** — Clean from flake.nix if not used.

### DNS/Network

7. **Router DNS delegation** — Configure router DHCP to hand out `192.168.1.162` as primary DNS. Currently every client uses its own resolver.
8. **DNS-over-TLS for LAN** — Unbound can serve DoT on port 853. Enable for clients that support it.
9. **Split-horizon DNS** — Consider separate views for LAN vs localhost queries.
10. **Fix CA key security** — Move dnsblockd CA key out of Nix store into `/var/lib/dnsblockd/` with proper permissions.

### Monitoring

11. **Grafana alert rules** — Disk space, CPU, memory, service down, DNS query failures.
12. **DNS performance dashboard** — Query rate, cache hit ratio, block rate, upstream latency.
13. **Uptime monitoring** — External ping checks for critical services.

### Security

14. **Secret rotation** — Automated sops secret rotation strategy.
15. **Network segmentation** — Consider VLANs for IoT devices (Samsung, Xiaomi, LG WebOS telemetry is blocked, but devices are on same network).
16. **Auditd re-enablement** — Track NixOS bug #483085 and re-enable when fixed.
17. **Verify SSH AllowUsers** — Is "art" a real second user or a leftover?

### Development

18. **NixOS VM tests** — Test service configuration in isolated VMs.
19. **superfile hash fix** — Actually build it once and fill in the vendorHash.
20. **Clean TODO_LIST.md** — Triage 75+ items, remove completed/stale, prioritize remaining.
21. **Archive old status reports** — 131+ files in docs/status/. Keep last 2 weeks, archive rest.
22. **Fix stale scripts** — Audit 55 scripts in scripts/, remove broken ones.
23. **Add NixOS build to CI** — Currently only Darwin gets built.
24. **Fix CI Cachix cache** — Use single consistent cache name.

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Priority | Task                                                                                  | Effort | Impact |
| --- | -------- | ------------------------------------------------------------------------------------- | ------ | ------ |
| 1   | **P0**   | Deploy DNS LAN fix (`sudo nixos-rebuild switch --flake .#evo-x2`) and verify from Mac | 5min   | HIGH   |
| 2   | **P0**   | Configure router DHCP to advertise `192.168.1.162` as DNS server                      | 10min  | HIGH   |
| 3   | **P0**   | Fix superfile.nix vendorHash — build once, insert real hash                           | 15min  | MEDIUM |
| 4   | **P0**   | Verify SSH AllowUsers — is "art" a real user? Remove if not                           | 2min   | HIGH   |
| 5   | **P1**   | Fix CA key security — move dnsblockd CA key out of Nix store                          | 1h     | HIGH   |
| 6   | **P1**   | Add Grafana alerting rules (disk, CPU, memory, service down)                          | 2h     | HIGH   |
| 7   | **P1**   | Unify Go overlay (remove duplication between flake.nix and darwin)                    | 1h     | MEDIUM |
| 8   | **P1**   | Deduplicate dnsblockd package (perSystem + overlay)                                   | 30min  | LOW    |
| 9   | **P1**   | Remove legacy Technitium DNS + dns-blocklist.nix dead code                            | 15min  | LOW    |
| 10  | **P1**   | Fix CI Cachix cache inconsistency (use single cache)                                  | 30min  | MEDIUM |
| 11  | **P1**   | Fix Sublime sync LaunchAgent path (SystemNix -> Setup-Mac)                            | 15min  | LOW    |
| 12  | **P1**   | Add NixOS build job to GitHub Actions CI                                              | 1h     | HIGH   |
| 13  | **P2**   | Archive old docs/status/ files (keep last 2 weeks only)                               | 30min  | MEDIUM |
| 14  | **P2**   | Triage TODO_LIST.md — remove stale items, prioritize remaining                        | 1h     | MEDIUM |
| 15  | **P2**   | Enable AMD NPU and test with Ollama                                                   | 2h     | HIGH   |
| 16  | **P2**   | Create DNS performance Grafana dashboard                                              | 2h     | MEDIUM |
| 17  | **P2**   | Configure NixOS Bluetooth (8 steps in TODO)                                           | 1h     | MEDIUM |
| 18  | **P2**   | Fix uBlock filter time parsing issue and re-enable                                    | 1h     | LOW    |
| 19  | **P2**   | Set up automated offsite backup for Immich photos                                     | 3h     | HIGH   |
| 20  | **P2**   | Audit and clean 55 scripts in scripts/ directory                                      | 1h     | MEDIUM |
| 21  | **P3**   | Remove unused wrapper-modules flake input                                             | 5min   | LOW    |
| 22  | **P3**   | Enable DNS-over-TLS on port 853 for LAN clients                                       | 1h     | MEDIUM |
| 23  | **P3**   | Create NixOS architecture diagram (like Darwin's SVG)                                 | 2h     | MEDIUM |
| 24  | **P3**   | Write operational runbook for common incidents                                        | 3h     | HIGH   |
| 25  | **P3**   | Document dnsblockd HTTP API                                                           | 2h     | LOW    |

---

## G) TOP #1 QUESTION

**Is "art" in SSH AllowUsers intentional?** The SSH config at `modules/nixos/services/ssh.nix:27` has `AllowUsers = ["lars" "art"]`. Is "art" a second user account on evo-x2, or is it leftover from a previous configuration? If it's not a real user, anyone trying to SSH as "art" will be rejected anyway (no home directory, no authorized keys), but it should be cleaned up for clarity.

---

## Session Changes

### Files Modified This Session

| File                                            | Change                                                                                                                       |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `platforms/nixos/modules/dns-blocker.nix`       | Already refactored with `blockInterface`/`blockIPPrefix` options, `network-online.target`, `ExecStartPre` for LAN interfaces |
| `platforms/nixos/system/dns-blocker-config.nix` | `blockIP = "192.168.1.163"`, `blockInterface = "enp1s0"`, ports 80/443                                                       |
| `modules/nixos/services/caddy.nix`              | Added `bind 192.168.1.162` to all virtual hosts                                                                              |
| `platforms/nixos/desktop/waybar.nix`            | Stats URL fixed to `127.0.0.1:9090`                                                                                          |
| `platforms/nixos/programs/dnsblockd/main.go`    | Dynamic fallback domain from configured address                                                                              |
| `platforms/nixos/scripts/service-health-check`  | Stats URL fixed to `127.0.0.1:9090`                                                                                          |
| `scripts/service-health-check`                  | Stats URL fixed to `127.0.0.1:9090`                                                                                          |
| `justfile`                                      | dns-test expects `192.168.1.163` as block response                                                                           |

### Commits This Session

| Hash      | Message                                                                                 |
| --------- | --------------------------------------------------------------------------------------- |
| `0651529` | feat(nixos/dns-blocker): bind DNS block page to LAN interface for network-wide blocking |
| `27120de` | fix(darwin): replace placeholder GitHub issue URL with actual home-manager issue #6036  |
| `f5be829` | docs: resolve Home Manager issue reference and clean up status report formatting        |

### Deployment Required

The DNS LAN block page fix is code-complete but requires deployment:

```bash
sudo nixos-rebuild switch --flake .#evo-x2
```

### Verification After Deploy

```bash
# From Mac:
dig @192.168.1.162 pornhub.com     # should return 192.168.1.163
curl http://192.168.1.163          # should show styled block page
ping -c 1 192.168.1.163           # should respond

# On evo-x2:
systemctl status dnsblockd         # should be active
ip addr show enp1s0                # should show both 192.168.1.162 and 192.168.1.163
```

---

_Generated: 2026-03-30 12:47 CEST_
