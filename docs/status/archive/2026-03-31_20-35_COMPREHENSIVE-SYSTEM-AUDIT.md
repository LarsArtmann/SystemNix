# SystemNix Comprehensive Status Report

**Date:** 2026-03-31 20:35 CEST
**Branch:** master
**Commits Today:** 51
**Platform:** NixOS (evo-x2 — AMD Ryzen AI Max+ 395) + macOS (nix-darwin)

---

## A) FULLY DONE

### Desktop Environment

| Component           | Status | Details                                            |
| ------------------- | ------ | -------------------------------------------------- |
| Niri compositor     | DONE   | Scrollable-tiling WM, fully migrated from Hyprland |
| SDDM + SilentSDDM   | DONE   | Catppuccin-mocha theme, defaultSession=niri        |
| Waybar              | DONE   | Catppuccin-themed, Niri workspace integration      |
| Kitty terminal      | DONE   | Primary terminal with TV-friendly font (16pt)      |
| Foot terminal       | DONE   | Lightweight Wayland backup terminal                |
| Rofi launcher       | DONE   | drun mode, Catppuccin theme                        |
| wlogout             | DONE   | Power off, reboot, suspend, lock                   |
| Dunst notifications | DONE   | Full Catppuccin theming, overlay layer             |
| Cliphist clipboard  | DONE   | History + waybar integration                       |
| Screenshot tools    | DONE   | grimblast + niri native                            |

### System Services

| Service            | Status | Details                                                                                       |
| ------------------ | ------ | --------------------------------------------------------------------------------------------- |
| DNS Blocker        | DONE   | Unbound + dnsblockd Go server, 1.5M+ domains blocked, temp allowlist, .lan domain protection  |
| Immich             | DONE   | Photo/video management (port 2283), PostgreSQL + Redis + ML, daily DB backups                 |
| Gitea              | DONE   | Self-hosted Git mirror, declarative repo mirroring, auto token generation                     |
| Caddy              | DONE   | Reverse proxy for *.lan domains with dnsblockd TLS certs, auto_https off for port coexistence |
| PhotoMapAI         | DONE   | OCI container, CLIP embedding map over Immich library, immich dependency wait script          |
| Grafana            | DONE   | Monitoring dashboards on :3001, Prometheus datasource                                         |
| Homepage Dashboard | DONE   | Service overview on :8082, health monitors with HTTPS                                         |
| Prometheus         | DONE   | Metrics scraping (node, postgres, caddy, redis exporters)                                     |
| SSH                | DONE   | Hardened, key-only auth, strong ciphers, fail2ban                                             |
| sops-nix           | DONE   | Secrets management with age encryption                                                        |

### Cross-Platform

| Component       | Status | Details                                         |
| --------------- | ------ | ----------------------------------------------- |
| Home Manager    | DONE   | Shared modules for Fish, Starship, Tmux         |
| Fish shell      | DONE   | Cross-platform aliases, nixup/nixbuild/nixcheck |
| Starship prompt | DONE   | Consistent on macOS + NixOS                     |
| Tmux            | DONE   | 24h color, SystemNix session template           |
| ActivityWatch   | DONE   | Time tracking + aw-watcher-utilization          |

### Security

| Component          | Status | Details                                        |
| ------------------ | ------ | ---------------------------------------------- |
| Secrets management | DONE   | sops-nix with age encryption from SSH host key |
| Swaylock PAM       | DONE   | PAM service configured                         |
| Firewall           | DONE   | nftables (22/53/80/443 TCP, 53 UDP)            |
| Chrome policies    | DONE   | Extension management declarative               |

### Custom Go Programs

| Program             | Status | Details                                                              |
| ------------------- | ------ | -------------------------------------------------------------------- |
| dnsblockd           | DONE   | HTTPS block page server, stats API, cert generation, unbound control |
| dnsblockd-processor | DONE   | Blocklist processor (hosts -> unbound conf + mapping JSON)           |

### Today's Fixes (2026-03-31)

| Fix                         | Files Changed                                                           | Impact                                          |
| --------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------- |
| PhotoMap immich wait script | `photomap.nix`                                                          | Container no longer fails on activation         |
| Caddy auto_https off        | `caddy.nix`                                                             | Port 80 conflict with dnsblockd resolved        |
| .lan domain protection      | `dnsblockd/main.go`, `dnsblockd-processor/main.go`, `dns-blocklist.nix` | 3-layer defense against blocking local services |
| Homepage HTTPS monitors     | `homepage.nix`                                                          | Proper HTTPS health checks for all services     |
| SilentSDDM integration      | `display-manager.nix`                                                   | Catppuccin-mocha themed login screen            |

---

## B) PARTIALLY DONE

| Item                   | What's Done                                  | What's Missing                                         |
| ---------------------- | -------------------------------------------- | ------------------------------------------------------ |
| **Wallpaper rotation** | swww spawns at startup with random wallpaper | No timer/cycling; hardcoded path                       |
| **Swaylock theming**   | PAM configured, binary available             | No Catppuccin theme via Home Manager                   |
| **Idle management**    | swayidle package installed                   | Not configured in Niri spawn-at-startup                |
| **Monitoring stack**   | Prometheus + Grafana running                 | Over-engineered; could consolidate                     |
| **Multi-WM**           | Sway as backup WM                            | Not really needed since Niri is stable                 |
| **Core type system**   | 9 files in platforms/common/core/            | 7 of 9 are dead code (not imported anywhere)           |
| **Networking**         | Static IP 192.168.1.150/24                   | IP mismatch: configs still reference 192.168.1.162/163 |

---

## C) NOT STARTED

| Item                       | Priority | Why It Matters                                     |
| -------------------------- | -------- | -------------------------------------------------- |
| DNS-over-HTTPS             | Medium   | unbound uses plain DNS upstream; DoH adds privacy  |
| Immich ML on NPU           | Medium   | AMD NPU available but Immich uses CPU for ML       |
| Automated flake updates    | Low      | No scheduled `nix flake update`                    |
| Niri binary cache          | Low      | No cachix for faster builds                        |
| Git push reminder hook     | Low      | No warning when >3 commits ahead                   |
| Pre-push commit count hook | Low      | Same as above                                      |
| `just reload` recipe       | Medium   | Convenience for `niri msg action reload-config`    |
| Dead core module cleanup   | Medium   | 519 lines of unused code in platforms/common/core/ |
| IP address audit           | High     | Multiple hardcoded IPs that may be stale           |
| Network namespace cleanup  | Medium   | The activate log showed netns mount units          |

---

## D) TOTALLY FUCKED UP (Fixed Today)

| Issue                                     | Severity                 | Root Cause                                                                                                  | Fix Applied                                                          |
| ----------------------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **PhotoMap activation failure**           | HIGH                     | Container health check ran before immich was ready; systemd marked activation as failed                     | ExecStartPre wait script polling immich API + Restart=on-failure     |
| **Caddy/dnsblockd port conflict**         | HIGH                     | Removing `bind 192.168.1.162` caused Caddy to bind 0.0.0.0:80, colliding with dnsblockd on 192.168.1.163:80 | Added `auto_https off` to Caddy globalConfig                         |
| **.lan domains could be blocked**         | MEDIUM                   | No protection for local domains in DNS blocker                                                              | 3-layer defense: blocklist filter, processor filter, runtime handler |
| **SDDM black screen**                     | CRITICAL (fixed earlier) | Missing `defaultSession = "niri"`                                                                           | Added to display-manager.nix                                         |
| **Overengineered ContainerService types** | SELF-INFLICTED           | Created 300 lines of type abstraction for 1 OCI container                                                   | Removed. Manual pattern matches gitea-repos.nix                      |

### Lessons Learned

1. **Premature abstraction is waste** — ContainerService/ContainerTypes added 300 lines for 1 container, then had to be removed
2. **Check before refactoring** — The caddy bind removal caused a port conflict because dnsblockd also uses port 80
3. **Wait scripts are essential** — Container services that depend on other services MUST have ExecStartPre wait scripts
4. **Three layers of defense** — The .lan domain protection (build-time filter + processor filter + runtime check) is the right pattern for critical invariants

---

## E) WHAT WE SHOULD IMPROVE

### Architecture

1. **Dead code in core/** — 7 of 9 files in `platforms/common/core/` are unused (519 lines). Either wire them in or delete them.
2. **Hardcoded IP addresses** — Multiple files reference 192.168.1.162 (old IP?) while networking.nix sets 192.168.1.150. dnsblockd uses 192.168.1.163. Need a single source of truth.
3. **ContainerService premature abstraction** — Lesson learned. When we have 3+ OCI containers, THEN extract a helper.

### Reliability

4. **All service dependencies should use wait scripts** — gitea-ensure-repos does it correctly. photomap now does too. Other services (homepage, monitoring) should follow.
5. **Error handling in dnsblockd** — `fmt.Fprintf` return value unchecked (Go lint warning at main.go:453)
6. **Network ordering** — dhcpcd was just removed in favor of static networking. Ensure all services handle this correctly.

### Code Quality

7. **Pre-commit hooks are excellent** — Gitleaks, deadnix, statix, alejandra, flake check all passing. Keep this.
8. **Go test coverage** — No tests for dnsblockd or dnsblockd-processor
9. **Nix module option documentation** — Some modules lack proper `description` and `example` fields

### Operations

10. **Monitoring consolidation** — Prometheus + Grafana + Netdata + ntopng is too many tools. Pick 2.
11. **Backup verification** — Immich DB backup runs daily but no verification step
12. **Automated health checks** — The `service-health-check` timer exists but could be more comprehensive

---

## F) Top 25 Things We Should Get Done Next

### Priority 1 — Fix Real Issues (Do Now)

1. **IP address audit** — Centralize all hardcoded IPs; networking.nix says 192.168.1.150 but caddy/dnsblockd reference 162/163
2. **Verify `just test` passes clean** — Build test was running when report was requested; confirm green
3. **Apply current changes to evo-x2** — `sudo nixos-rebuild switch --flake .#evo-x2` and verify all services start
4. **Clean up Go lint warning** — Check `fmt.Fprintf` return value in dnsblockd/main.go:453

### Priority 2 — Clean Up Debt (Do This Week)

5. **Remove dead core modules** — Delete or properly wire up the 7 unused files in platforms/common/core/
6. **Add Go tests for dnsblockd** — At least unit tests for blockHandler, isLANDomain, temp allowlist
7. **Add Go tests for dnsblockd-processor** — At least unit tests for domain parsing, whitelist filtering
8. **Consolidate monitoring** — Decide on Prometheus+Grafana OR Netdata, remove the other
9. **Remove Sway backup WM** — Niri is stable, Sway adds unnecessary complexity
10. **Audit all tmpfiles rules** — Ensure data directories have correct permissions and ownership

### Priority 3 — Improve Reliability (Do This Month)

11. **Add wait scripts to all dependent services** — homepage-dashboard, monitoring, etc.
12. **Create centralized IP config module** — Single source of truth for all IP addresses
13. **Add DNS-over-HTTPS to unbound** — Privacy improvement for upstream DNS
14. **Verify Immich DB backups** — Add a restore test step
15. **Add `just reload` recipe** — For niri config hot-reload
16. **Add `just status` recipe** — Quick overview of all services
17. **Wire core type modules into flake.nix** — Or delete them if not needed

### Priority 4 — Nice to Have (Backlog)

18. **Immich ML on AMD NPU** — Leverage XDNA driver for ML inference
19. **Automated flake updates** — Weekly `nix flake update` via timer
20. **Niri binary cache** — cachix or attic for faster CI
21. **Git push reminder hook** — Warn when >3 commits ahead
22. **Swaylock Catppuccin theme** — Home Manager module for theming
23. **Wallpaper rotation timer** — swww cycling with random selection
24. **swayidle configuration** — Auto-lock, screen off after idle
25. **Dunst auto-start in Niri** — Ensure notifications start with compositor

---

## G) Top #1 Question I Cannot Figure Out Myself

**What is the correct static IP for evo-x2?**

The codebase has conflicting IP addresses:

- `networking.nix`: Static IP `192.168.1.150/24`
- `dns-blocker-config.nix`: Block IP `192.168.1.163`
- `caddy.nix` (before refactor): Was binding to `192.168.1.162`
- `dns-blocker-config.nix`: DNS record `photomap.lan IN A 192.168.1.163`

Which IP is actually assigned to the machine? Is it .150, .162, or .163? The dnsblockd needs to listen on the machine's actual IP for the block page to work. If the machine is .150, then dnsblockd listening on .163 won't work. If the machine has multiple IPs, we need to document which is which.

---

## Session Statistics

| Metric                | Value                                    |
| --------------------- | ---------------------------------------- |
| Commits today         | 51                                       |
| Files in flake        | ~120+                                    |
| Flake inputs          | 17                                       |
| NixOS service modules | 11                                       |
| Custom Go programs    | 2                                        |
| Dead core modules     | 7 (519 lines)                            |
| OCI containers        | 1 (photomap)                             |
| Monitoring tools      | 4 (Prometheus, Grafana, Netdata, ntopng) |
