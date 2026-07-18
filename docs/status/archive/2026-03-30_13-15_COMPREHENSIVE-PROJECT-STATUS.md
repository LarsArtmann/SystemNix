# Comprehensive Project Status Report

**Date:** 2026-03-30 13:15 CEST
**System:** evo-x2 (NixOS, AMD Ryzen AI Max+ 395) + Lars-MacBook-Air (macOS, nix-darwin)
**Branch:** master (up to date with origin)
**Working Tree:** 4 staged files (uncommitted), 0 unstaged

---

## A) FULLY DONE

### Core Infrastructure

- **Flake architecture** — Unified flake.nix with flake-parts, 16 inputs, dual-system outputs (darwin + nixos)
- **NixOS base system** — evo-x2 fully declarative: networking, firewall, users, locales, time zone, garbage collection, store optimization
- **Darwin base system** — Lars-MacBook-Air fully declarative: Catppuccin Mocha theme, Touch ID sudo, Keychain integration, LaunchAgents
- **Home Manager cross-platform** — Shared modules in `platforms/common/` with platform-specific overrides. ~80% code reuse between Darwin and NixOS

### Service Stack (All NixOS, flake-parts dendritic modules)

- **DNS Blocker** — Unbound + dnsblockd + dnsblockd-processor. 15 blocklists (~1.9M domains), Quad9+Cloudflare DoT upstream, DNSSEC, HTTPS block page with dynamic per-domain TLS certs. Module system with `blockInterface`, `blockIPPrefix` options for flexible deployment
- **Caddy reverse proxy** — immich.lan, gitea.lan, grafana.lan, home.lan. All bound to `192.168.1.162` with wildcard `*.lan` TLS cert signed by dnsblockd CA
- **Gitea** — SQLite, LFS, weekly dump, GitHub mirror every 30min, sops-managed tokens, auto theme
- **Immich** — Full photo management, PostgreSQL tuned (512MB shared_buffers), Redis, ML enabled, daily DB backup
- **Grafana** — Port 3001, Prometheus datasource, custom dashboards, admin creds via sops
- **Homepage dashboard** — Port 8082, dark theme, all services displayed
- **Prometheus** — Port 9091, 30d retention, 4 scrape targets (node, postgres, caddy, redis exporters)
- **SSH** — Hardened: key-only, no root, strong ciphers, MaxAuthTries=3, fail2ban, banner
- **sops-nix** — Age encryption via SSH host key, 5 secrets, template for gitea-sync.env

### TLS Certificate Architecture (NEW - staged, not yet deployed)

- **dnsblockd-cert.nix** now generates TWO certificates at build time:
  - **CA cert** (`dnsblockd-ca.crt`/`.key`) — CN=dnsblockd-CA, used by dnsblockd Go binary for dynamic per-domain TLS cert signing
  - **Server cert** (`dnsblockd-server.crt`/`.key`) — CN=`*.lan`, SANs: `*.lan`, `immich.lan`, `gitea.lan`, `grafana.lan`, `home.lan`. Used by Caddy for HTTPS on all `.lan` vhosts
- **Caddy** configured with explicit TLS using the server cert (staged change)
- **Flake overlay** now exposes `dnsblockd-cert` as a proper package (staged change)

### DNS Blocker Module Architecture

- **Module** (`platforms/nixos/modules/dns-blocker.nix`) — 286 lines, fully optionized NixOS module
  - `blockInterface` / `blockIPPrefix` — interface and prefix for virtual IP
  - `blockIP` — sinkhole IP (currently `192.168.1.163`)
  - `blockPort` / `blockTLSPort` — HTTP 80 / HTTPS 443
  - `statsPort` — localhost-only stats API on 9090
  - `ExecStartPre` adds virtual IP to `enp1s0` for non-loopback interfaces
  - Uses `network-online.target` for reliable ordering
- **Go block page server** (`platforms/nixos/programs/dnsblockd/main.go`) — 875 lines, zero dependencies
- **Go blocklist processor** (`pkgs/dnsblockd-processor/main.go`) — 155 lines, zero dependencies
- **Site config** (`platforms/nixos/system/dns-blocker-config.nix`) — 15 blocklists, 7 whitelist entries, category mappings

### Security

- **Firewall** — Default deny, TCP 22/53/80/443, UDP 53
- **AppArmor** — Mandatory access control enabled
- **Fail2ban** — SSH jail, aggressive mode, 3 retries, 1h ban
- **ClamAV** — Daemon + signature updater
- **Gitleaks** — Pre-commit secret detection (8 hooks total)

### Desktop (NixOS)

- **Hyprland** — Full Wayland compositor with 10 named workspaces, MD3 animations, kanshi display profiles
- **Niri** — Wrapped with declarative keybindings via wrapper-modules
- **Waybar** — Status bar with DNS stats widget (fixed: `127.0.0.1:9090`)
- **Dunst, Kitty, Foot** — Catppuccin Mocha themed, font size 16 for TV viewing
- **GTK/Qt** — Catppuccin Mocha Compact Lavender Dark, Papirus icons, Bibata cursor
- **Rofi, wlogout, hyprlock, hypridle** — All configured

### Development Toolchain

- **Go 1.26.1** — Full toolchain: gopls, golangci-lint, gofumpt, gotests, mockgen, delve, modernize, buf
- **Shell tooling** — Fish + Zsh + Nushell + Bash, Starship prompt, tmux, fzf, zellij
- **Just** — 80+ recipes in justfile (1778 lines)
- **Pre-commit** — 8 hooks: gitleaks, trailing-whitespace, deadnix, statix, alejandra, nix-check, flake-lock-validate, check-merge-conflicts

### Custom Packages (6)

- **dnsblockd** — Go HTTP block page server (875 lines, zero deps)
- **dnsblockd-processor** — Go build-time blocklist processor (155 lines, zero deps)
- **modernize** — Go 1.26 code modernization tool
- **superfile** — v1.5.0 terminal file manager (vendorHash needs fix)
- **aw-watcher-utilization** — ActivityWatch system resource monitor
- **geekbench-ai** — v1.6.0 AI benchmarking

---

## B) PARTIALLY DONE

### DNS LAN Block Pages (Code Done, Staged, NOT Deployed)

- Config committed: `blockIP = "192.168.1.163"`, `blockInterface = "enp1s0"`, ports 80/443
- Module properly adds virtual IP via `ExecStartPre` with `network-online.target`
- Caddy bound to `192.168.1.162` only — no port conflict
- **4 additional staged changes** ready for commit:
  - `flake.nix`: `dnsblockd-cert` added to overlay
  - `caddy.nix`: TLS with server cert for `*.lan` domains
  - `dnsblockd-cert.nix`: generates both CA + server cert with SANs
  - `dns-blocker.nix`: uses overlay package instead of callPackage
- **BLOCKED**: Needs commit, then `sudo nixos-rebuild switch --flake .#evo-x2`
- **NOT TESTED** from LAN — needs verification after deploy

### TLS for .lan Services (Staged, NOT Deployed)

- dnsblockd-cert now generates server cert with SANs for all `.lan` domains
- Caddy configured to use it — HTTPS will work on all `.lan` vhosts
- CA cert installed system-wide + Firefox NSS — browser will trust the certs
- LAN devices need CA cert installed manually (or accept warning)

### AI/ML Stack

- Ollama installed with Vulkan backend, flash attention
- Python 3.13 with timm/xformers
- AMD NPU driver loaded but **disabled** — needs activation and testing

### Monitoring

- Prometheus + Grafana + exporters — working
- No alerting rules configured
- No Grafana dashboards for DNS blocker performance

### CI/CD

- GitHub Actions: 3 jobs (check, build-darwin, syntax-check)
- No NixOS build in CI — only Darwin gets built

---

## C) NOT STARTED

### High Priority

1. **Deploy DNS LAN fix** — Staged changes need commit + `nixos-rebuild switch`
2. **Router DHCP DNS** — Configure router to advertise `192.168.1.162` as DNS server to all LAN clients
3. **Grafana alerting** — No alert rules for disk, CPU, memory, service failures
4. **Automated backups** — No offsite backup strategy (Immich photos, Gitea repos, Grafana dashboards)

### Desktop (NixOS)

5. **Bluetooth** — 8-step setup in TODO_LIST.md, not started
6. **Audio pipewire** — Not configured
7. **Gaming** — Not started

### Infrastructure

8. **NixOS automated testing** — No NixOS VM tests
9. **Secret rotation** — No rotation strategy for sops secrets
10. **IPv6** — Completely disabled, no plan for re-enablement
11. **NPU activation** — AMD XDNA NPU present but disabled
12. **DNS-over-HTTPS server** — Could serve DoH to LAN clients

### Documentation

13. **API documentation** — No docs for dnsblockd HTTP API
14. **Operational runbook** — No runbook for common incidents
15. **NixOS architecture diagram** — SVG exists for Darwin but not NixOS

---

## D) TOTALLY FUCKED UP

### Broken/Blocked

1. **CA private key world-readable in Nix store** — `dnsblockd-cert.nix` generates `dnsblockd-ca.key` into `/nix/store` which is world-readable. Any local user can read the CA key and forge trusted TLS certificates. The `chmod 600` is ineffective.
2. **XSS vulnerability in dnsblockd HTML** — `main.go:604,682` uses `fmt.Fprintf` with raw `%s` for domain names in HTML responses. No HTML escaping. A malicious domain containing `<script>` tags would execute in the block page.
3. **`unbound-control` called without absolute path** — `dnsblockd/main.go:302` uses `exec.Command("unbound-control", "reload")` bare command name. In NixOS systemd context, PATH may not include this. Should use `${pkgs.unbound}/bin/unbound-control`.
4. **superfile.nix vendorHash=null will fail** — `pkgs/superfile.nix:17` has `vendorHash = null` but superfile has Go dependencies. Will break on first build.
5. **auditd disabled** — Blocked by NixOS bug #483085 (AppArmor conflicts). No workaround.
6. **Hyprland plugins incompatible** — hy3, hyprsplit incompatible with Hyprland 0.54.2. Disabled.
7. **uBlock filters disabled** — "Temporarily disabled due to time parsing issues" — unclear root cause.
8. **Sublime sync LaunchAgent wrong path** — References `~/projects/SystemNix/scripts/` (should be `Setup-Mac`).
9. **CI Cachix cache mismatch** — check job pushes to `larsartmann`, build-darwin pushes to `petersaluja`.

### Tech Debt

10. **Go overlay duplicated** — Same Go 1.26.1 overlay defined in both `flake.nix:103-111` and `darwin/default.nix:64-73`. Darwin version also has `golangci-lint` override missing from NixOS.
11. **dnsblockd package built 2-3 times** — Built in `dnsblockdOverlay` AND `perSystem.packages` with identical source filters. Plus now dnsblockd-cert in overlay.
12. **Dead code: Technitium DNS** — `platforms/nixos/private-cloud/dns.nix` with `openFirewall = true` is never imported. Dead code with security implications if accidentally imported.
13. **Dead code: dns-blocklist.nix** — `pkgs/dns-blocklist.nix` is pure-Nix blocklist processor, superseded by Go `dnsblockd-processor`. Not imported anywhere.
14. **Dead code: dns-blocklist.nix** — `pkgs/dns-blocklist.nix` not imported anywhere.
15. **58 scripts, many stale** — `scripts/` has 58 files. Multiple overlapping: 5 benchmark scripts, 4 health check scripts, 3 Nix diagnostic scripts, 3 optimization scripts. Many predate the declarative Nix setup.
16. **132 docs/status files** — Massive documentation bloat. Most are superseded session reports.
17. **SSH AllowUsers includes "art"** — `ssh.nix:27` has `AllowUsers = ["lars" "art"]`. Unknown if "art" is intentional.
18. **Duplicate firewall rules** — Caddy module opens TCP 80/443, networking.nix also opens them.
19. **CI outdated** — `cachix/install-nix-action@v22` (current is v28+), no NixOS build, no Go tests.

---

## E) WHAT WE SHOULD IMPROVE

### Security

1. **Move CA key out of Nix store** — Generate at runtime into `/var/lib/dnsblockd/` or use `sops-nix`. Current approach leaks the CA private key to all local users.
2. **Fix XSS in dnsblockd** — HTML-escape domain names in block page responses (`main.go:604,682`). Use `html/template` instead of `text/template` or `fmt.Fprintf`.
3. **Use absolute path for unbound-control** — Replace bare `"unbound-control"` with `${pkgs.unbound}/bin/unbound-control` in the Go code or pass it as a flag from Nix.
4. **Verify SSH AllowUsers** — Confirm "art" is intentional. Remove if not.

### Architecture

5. **Unify Go overlay** — Single definition, imported by both Darwin and NixOS. Include `golangci-lint` override in both.
6. **Deduplicate dnsblockd packages** — Use one definition (overlay OR perSystem, not both).
7. **Remove dead code** — Delete `private-cloud/dns.nix`, `pkgs/dns-blocklist.nix`, unused `wrapper-modules` input.
8. **Extract unbound access-control to module option** — Still hardcoded to `192.168.1.0/24`. Should be a `allowedNetworks` option.

### DNS/Network

9. **Router DNS delegation** — Configure router DHCP to hand out `192.168.1.162` as primary DNS.
10. **DNS-over-TLS for LAN** — Enable Unbound DoT on port 853 for LAN clients.
11. **Distribute CA cert to LAN devices** — Export dnsblockd CA cert for installation on phones/tablets/laptops.

### Monitoring

12. **Grafana alert rules** — Disk space, CPU, memory, service down, DNS query failures.
13. **DNS performance dashboard** — Query rate, cache hit ratio, block rate, upstream latency.

### Development

14. **Add NixOS build to CI** — Currently only Darwin gets built.
15. **Fix CI Cachix** — Use single consistent cache name.
16. **Add Go tests** — No test files for dnsblockd or dnsblockd-processor.
17. **Fix superfile vendorHash** — Build once, get real hash, insert.
18. **Archive old status reports** — 132 files in `docs/status/`. Keep last 2 weeks, archive rest.
19. **Audit scripts** — 58 scripts, many stale. Consolidate and remove broken ones.
20. **Fix Sublime sync path** — SystemNix -> Setup-Mac.

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Priority | Task                                                                      | Effort | Impact |
| --- | -------- | ------------------------------------------------------------------------- | ------ | ------ |
| 1   | **P0**   | Commit staged DNS/TLS changes and deploy (`nixos-rebuild switch`)         | 5min   | HIGH   |
| 2   | **P0**   | Verify from Mac: `dig @192.168.1.162 pornhub.com` returns `192.168.1.163` | 2min   | HIGH   |
| 3   | **P0**   | Verify from Mac: `curl http://192.168.1.163` shows block page             | 2min   | HIGH   |
| 4   | **P0**   | Fix XSS in dnsblockd HTML responses (`html/template` or escape)           | 30min  | HIGH   |
| 5   | **P0**   | Fix `unbound-control` bare path in Go code                                | 15min  | HIGH   |
| 6   | **P0**   | Configure router DHCP to advertise `192.168.1.162` as DNS                 | 10min  | HIGH   |
| 7   | **P1**   | Move CA key out of Nix store (runtime generation or sops)                 | 1h     | HIGH   |
| 8   | **P1**   | Verify SSH AllowUsers — is "art" intentional?                             | 2min   | MEDIUM |
| 9   | **P1**   | Unify Go overlay (flake.nix + darwin/default.nix)                         | 1h     | MEDIUM |
| 10  | **P1**   | Deduplicate dnsblockd package definitions                                 | 30min  | LOW    |
| 11  | **P1**   | Remove dead code (Technitium, dns-blocklist.nix, wrapper-modules input)   | 15min  | LOW    |
| 12  | **P1**   | Add Grafana alerting rules (disk, CPU, memory, service down)              | 2h     | HIGH   |
| 13  | **P1**   | Fix CI Cachix cache inconsistency                                         | 30min  | MEDIUM |
| 14  | **P1**   | Add NixOS build job to GitHub Actions CI                                  | 1h     | HIGH   |
| 15  | **P2**   | Fix superfile.nix vendorHash                                              | 15min  | MEDIUM |
| 16  | **P2**   | Archive old docs/status/ files (keep last 2 weeks)                        | 30min  | MEDIUM |
| 17  | **P2**   | Audit and consolidate 58 scripts                                          | 2h     | MEDIUM |
| 18  | **P2**   | Enable AMD NPU and test with Ollama                                       | 2h     | HIGH   |
| 19  | **P2**   | Create DNS performance Grafana dashboard                                  | 2h     | MEDIUM |
| 20  | **P2**   | Set up automated offsite backup for Immich photos                         | 3h     | HIGH   |
| 21  | **P2**   | Fix Sublime sync LaunchAgent path                                         | 15min  | LOW    |
| 22  | **P3**   | Add Go tests for dnsblockd and dnsblockd-processor                        | 2h     | MEDIUM |
| 23  | **P3**   | Enable DNS-over-TLS on port 853 for LAN clients                           | 1h     | MEDIUM |
| 24  | **P3**   | Write operational runbook for common incidents                            | 3h     | HIGH   |
| 25  | **P3**   | Document dnsblockd HTTP API                                               | 2h     | LOW    |

---

## G) TOP #1 QUESTION

**Is "art" in SSH AllowUsers intentional?** The SSH config at `modules/nixos/services/ssh.nix:27` has `AllowUsers = ["lars" "art"]`. I cannot determine if "art" is a second user account, a nickname, or leftover from a previous setup. If it's not a real user with an authorized key, it's harmless but should be cleaned up. If it IS a real user, it needs a home directory and SSH key configured.

---

## Staged Changes (Ready to Commit)

| File                                      | Change                                          |
| ----------------------------------------- | ----------------------------------------------- |
| `flake.nix:116`                           | Add `dnsblockd-cert` to `dnsblockdOverlay`      |
| `modules/nixos/services/caddy.nix`        | Add TLS with server cert for all `*.lan` vhosts |
| `pkgs/dnsblockd-cert.nix`                 | Generate CA + server cert with `*.lan` SANs     |
| `platforms/nixos/modules/dns-blocker.nix` | Use overlay package instead of callPackage      |

---

## Session Commits

| Hash      | Message                                                                                 |
| --------- | --------------------------------------------------------------------------------------- |
| `55e3d70` | docs(status): add comprehensive DNS LAN block page status report                        |
| `f5be829` | docs: resolve Home Manager issue reference and clean up status report formatting        |
| `27120de` | fix(darwin): replace placeholder GitHub issue URL with actual home-manager issue #6036  |
| `0651529` | feat(nixos/dns-blocker): bind DNS block page to LAN interface for network-wide blocking |

---

_Generated: 2026-03-30 13:15 CEST_
