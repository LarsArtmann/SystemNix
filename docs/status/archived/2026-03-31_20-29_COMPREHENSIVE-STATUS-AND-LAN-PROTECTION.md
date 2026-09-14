# COMPREHENSIVE STATUS REPORT — SystemNix Project

**Date:** 2026-03-31 20:29 CEST
**Branch:** master
**Commits Ahead of Origin:** 4
**Latest Commit:** `e31125f` — refactor(types): remove overengineered ContainerService modules
**Platform:** NixOS (evo-x2: AMD Ryzen AI Max+ 395) + macOS (Lars-MacBook-Air: M4)
**Status Reports in Archive:** 130+ files, 71,000+ lines

---

## SESSION WORK — What Was Done This Session

### `.lan` Domain Protection (Completed)

Added three-layer defense to guarantee `.lan` local domains are **never** blocked by the DNS blocker:

| Layer      | File                                                 | Mechanism                                                            |
| ---------- | ---------------------------------------------------- | -------------------------------------------------------------------- |
| Build-time | `pkgs/dnsblockd-processor/main.go:69-71`             | `strings.HasSuffix(domain, ".lan")` skip during blocklist processing |
| Build-time | `pkgs/dns-blocklist.nix:23-24`                       | `lib.hasSuffix ".lan" domain` filter in pure-Nix path                |
| Runtime    | `platforms/nixos/programs/dnsblockd/main.go:431-437` | `isLANDomain()` guard in block page HTTP handler                     |

**Already committed** as `5c5e77c` (fix: protect .lan domains from being blocked). Build verified, `go vet` clean.

### Homepage Dashboard Service Monitoring (Uncommitted)

`modules/nixos/services/homepage.nix` has improvements:

- All service links migrated from `http://` to `https://` (uses dnsblockd TLS certs)
- Replaced legacy `ping:` with `siteMonitor:` + `statusStyle: dot` for proper health checks
- Caddy href fixed (was pointing to immich.lan, now correctly points to home.lan)
- API-based health endpoints for Immich, Gitea, Grafana, Ollama, Prometheus, Node Exporter
- **Status: UNCOMMITTED** — needs to be committed

---

## A) FULLY DONE ✅

### Desktop Environment (NixOS evo-x2)

| Component       | Status | File/Details                                                                  |
| --------------- | ------ | ----------------------------------------------------------------------------- |
| Niri compositor | ✅     | `platforms/nixos/programs/niri-wrapped.nix` — scrollable-tiling, all keybinds |
| SilentSDDM      | ✅     | catppuccin-mocha, Qt6, virtual keyboard, auto-deps                            |
| Waybar          | ✅     | Catppuccin, Niri workspace, clipboard, sudo monitor                           |
| Kitty           | ✅     | Primary terminal, 16pt font, 85% opacity                                      |
| Foot            | ✅     | Lightweight Wayland backup                                                    |
| Rofi            | ✅     | drun mode, Catppuccin theme                                                   |
| wlogout         | ✅     | Power menu with Catppuccin icons                                              |
| Dunst           | ✅     | Full Catppuccin theming, overlay layer                                        |
| Cliphist        | ✅     | History + waybar + rofi picker                                                |
| Screenshots     | ✅     | grimblast + Niri native                                                       |
| swww            | ✅     | Random wallpaper at startup, Mod+W                                            |
| GTK/Qt/Cursor   | ✅     | Catppuccin + Papirus + Bibata XL                                              |
| XWayland        | ✅     | xwayland-satellite                                                            |

### System Services

| Service                     | Status | Details                                                    |
| --------------------------- | ------ | ---------------------------------------------------------- |
| DNS Blocker                 | ✅     | unbound + dnsblockd, ~1.9M domains blocked, .lan protected |
| Caddy                       | ✅     | 5 virtual hosts (.lan), dnsblockd TLS certs, ports 80/443  |
| Immich                      | ✅     | Photo management, port 2283                                |
| PhotoMap AI                 | ✅     | Container with Immich wait logic, restart-on-failure       |
| Gitea                       | ✅     | GitHub repo mirroring, sops-nix secrets                    |
| Grafana + Prometheus        | ✅     | Monitoring stack                                           |
| Netdata                     | ✅     | Real-time system monitoring                                |
| AMD GPU (ROCm)              | ✅     | Full acceleration                                          |
| AMD NPU (XDNA)              | ✅     | Driver loaded                                              |
| BTRFS                       | ✅     | Timeshift snapshots                                        |
| SOPS secrets                | ✅     | age encryption                                             |
| PipeWire / Bluetooth / CUPS | ✅     | All working                                                |
| smartd                      | ✅     | Scheduled disk tests                                       |

### Cross-Platform

| Component                                            | Status |
| ---------------------------------------------------- | ------ |
| Home Manager shared modules                          | ✅     |
| Fish shell (nixup/nixbuild/nixcheck)                 | ✅     |
| Starship prompt                                      | ✅     |
| Tmux (100k history)                                  | ✅     |
| ActivityWatch (Linux: HM module, macOS: LaunchAgent) | ✅     |

### Security

| Component                                  | Status |
| ------------------------------------------ | ------ |
| Swaylock PAM                               | ✅     |
| Gitleaks pre-commit                        | ✅     |
| Chrome policies (HTTPS-only, SafeBrowsing) | ✅     |
| Network-wide DNS blocking                  | ✅     |
| Firewall (TCP 22/53/80/443, UDP 53)        | ✅     |

---

## B) PARTIALLY DONE 🟡

| Item                   | Status | What's Missing                                                                               |
| ---------------------- | ------ | -------------------------------------------------------------------------------------------- |
| **Homepage dashboard** | 🟡     | Changes in `homepage.nix` are UNCOMMITTED — need git commit                                  |
| **Monitoring stack**   | 🟡     | 4 tools (Netdata + Prometheus + Grafana + ntopng) — over-engineered, should consolidate to 2 |
| **DNS-over-HTTPS**     | 🟡     | unbound configured but no DoH upstream (only DoT to Quad9/Cloudflare)                        |
| **Swaylock theming**   | 🟡     | PAM works, binary exists, but no Catppuccin theme configured                                 |
| **Wallpaper system**   | 🟡     | Works but path hardcoded in 2 places, no rotation timer, no prev/next keybinds               |
| **Go lint warnings**   | 🟡     | 3 warnings: 2 unused `//nolint:gosec` directives, 1 unchecked `fmt.Fprintf`                  |

---

## C) NOT STARTED ❌

| #  | Item                                               | Effort | Priority     |
| -- | -------------------------------------------------- | ------ | ------------ |
| 1  | swayidle for Niri (dim/lock/suspend)               | 15 min | 🔴 Critical  |
| 2  | Dunst in Niri spawn-at-startup                     | 5 min  | 🔴 Critical  |
| 3  | Delete orphaned `regreet.css`                      | 1 min  | 🔴 Quick win |
| 4  | Extract wallpaper path to variable                 | 10 min | 🟡           |
| 5  | Add `just reload` recipe for Niri                  | 5 min  | 🟡           |
| 6  | Wallpaper prev/next keybinds                       | 10 min | 🟡           |
| 7  | Immich ML on AMD NPU                               | 1-2 hr | 🟠           |
| 8  | Automated flake updates (CI)                       | 30 min | 🟠           |
| 9  | CI/CD pipeline (GitHub Actions)                    | 1 hr   | 🟠           |
| 10 | keybind cheatsheet overlay                         | 20 min | 🟢           |
| 11 | Consolidate terminals (kitty + ghostty + foot → 2) | 15 min | 🟢           |
| 12 | Remove sway from multi-wm.nix                      | 5 min  | 🟢           |
| 13 | Stale docs cleanup (STATUS.md, TODO-STATUS.md)     | 30 min | 🟢           |

---

## D) TOTALLY FUCKED UP 💀

| Item                               | Severity | Details                                                                                                                                      |
| ---------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **130+ status reports, 71K lines** | 💀       | Massive documentation bloat. Most reports are redundant duplicates. No one will ever read these. They accumulate faster than they're useful. |
| **3 commits ahead of origin**      | ⚠️        | No pre-push hook to warn. Risk of diverged branches.                                                                                         |
| **Stale TODO tracking**            | ⚠️        | `docs/TODO-STATUS.md` last updated 2026-01-13 (2.5 months stale). `TODO_LIST.md` counts are wrong.                                           |
| **Stale `docs/STATUS.md`**         | ⚠️        | 3 months out of date.                                                                                                                        |
| **auditd kernel module**           | ⚠️        | Disabled due to AppArmor conflict (2 TODOs in `security-hardening.nix:14,21`). Blocked by nixpkgs#483085.                                    |
| **Security-hardening audit-rules** | ⚠️        | Service bug, re-enable after NixOS fix.                                                                                                      |

---

## E) WHAT WE SHOULD IMPROVE

### Immediate Hygiene (Do Today)

1. **Commit `homepage.nix`** — changes have been sitting uncommitted
2. **Push to origin** — 4 commits behind remote, no pre-push hook
3. **Delete `docs/STATUS.md`** — completely stale, replaced by status reports
4. **Archive old status reports** — anything older than 2 weeks should move to `docs/archive/status/`

### Process Improvements

5. **Add pre-push hook** — warn when >3 commits ahead of origin
6. **Status report deduplication** — stop writing "comprehensive" reports every session. One per week max, plus targeted reports for specific changes.
7. **Update `TODO_LIST.md`** — counts are wrong, items are stale, some already done
8. **Add `just reload`** — for Niri config reload without full rebuild
9. **Fix Go lint warnings** — 3 warnings are trivial to fix

### Architecture Improvements

10. **Consolidate monitoring** — 4 monitoring tools (Netdata, Prometheus, Grafana, ntopng) is overkill for a homelab. Pick 2.
11. **Terminal consolidation** — kitty + ghostty + foot = 3 terminals. Pick 2 max.
12. **Wallpaper path variable** — extract to a single source of truth
13. **DNS-over-HTTPS** — DoT works but DoH would prevent ISP snooping
14. **Remove dead code** — sway from multi-wm.nix, swaybg references

---

## F) TOP 25 THINGS TO DO NEXT

| #  | Task                                               | Effort | Impact | Category    |
| -- | -------------------------------------------------- | ------ | ------ | ----------- |
| 1  | **Commit homepage.nix changes**                    | 2 min  | 🔴     | Hygiene     |
| 2  | **Push 4 commits to origin**                       | 1 min  | 🔴     | Hygiene     |
| 3  | **Add swayidle for Niri** (dim/lock/suspend)       | 15 min | 🔴     | Desktop     |
| 4  | **Add dunst to Niri spawn-at-startup**             | 5 min  | 🔴     | Desktop     |
| 5  | **Delete orphaned regreet.css**                    | 1 min  | 🔴     | Cleanup     |
| 6  | **Fix 3 Go lint warnings**                         | 5 min  | 🟡     | Quality     |
| 7  | **Add `just reload` recipe for Niri**              | 5 min  | 🟡     | DevEx       |
| 8  | **Extract wallpaper path to variable**             | 10 min | 🟡     | Refactor    |
| 9  | **Theme swaylock with Catppuccin**                 | 15 min | 🟡     | Desktop     |
| 10 | **Add pre-push hook** (warn >3 ahead)              | 10 min | 🟡     | Hygiene     |
| 11 | **Archive old status reports** (>2 weeks)          | 10 min | 🟡     | Docs        |
| 12 | **Consolidate terminals** (remove ghostty or foot) | 15 min | 🟡     | Cleanup     |
| 13 | **Remove sway from multi-wm.nix**                  | 5 min  | 🟢     | Cleanup     |
| 14 | **Add wallpaper keybinds** (Mod+Shift/Ctrl+W)      | 10 min | 🟢     | Desktop     |
| 15 | **Update TODO_LIST.md** with accurate counts       | 30 min | 🟢     | Docs        |
| 16 | **Consolidate monitoring** (4→2 tools)             | 30 min | 🟠     | Infra       |
| 17 | **Enable DNS-over-HTTPS upstream**                 | 20 min | 🟠     | Security    |
| 18 | **Automate flake updates** (weekly timer)          | 30 min | 🟠     | Infra       |
| 19 | **Add GitHub Actions CI** (nix flake check)        | 1 hr   | 🟠     | Infra       |
| 20 | **Immich ML on AMD NPU**                           | 1-2 hr | 🟠     | Performance |
| 21 | **Resolve auditd/AppArmor conflict**               | 1 hr   | 🟠     | Security    |
| 22 | **Delete stale docs/STATUS.md**                    | 1 min  | 🟢     | Docs        |
| 23 | **Add keybind cheatsheet overlay**                 | 20 min | 🟢     | Desktop     |
| 24 | **Clean up Hyprland comment references**           | 15 min | 🟢     | Cleanup     |
| 25 | **Bluetooth Nest Audio pairing**                   | 30 min | 🟢     | Hardware    |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why are 4 commits sitting ahead of origin with no push?**

The branch has been ahead of origin for at least the current session:

- `e31125f` refactor(types): remove overengineered ContainerService modules
- `5c5e77c` fix(dnsblockd): protect .lan domains from being blocked
- `3a5547a` fix(packages): replace nodePackages.pnpm with top-level pnpm
- `d20d18c` feat(types): add ContainerService type system for OCI containers

Is there a reason to hold these locally, or should they be pushed immediately? The AGENTS.md says "Push changes immediately" but also "NEVER PUSH TO REMOTE unless explicitly asked." These seem contradictory for normal workflow. **Should I push after committing the status report and homepage changes?**

---

## UNCOMMITTED CHANGES (Current Working Tree)

| File                                                                    | Change Type | Status                                                  |
| ----------------------------------------------------------------------- | ----------- | ------------------------------------------------------- |
| `modules/nixos/services/homepage.nix`                                   | Modified    | Migrated ping→siteMonitor, http→https, fixed Caddy href |
| `pkgs/dnsblockd-processor/dnsblockd-processor`                          | Untracked   | Go binary (in .gitignore, harmless)                     |
| `platforms/nixos/programs/dnsblockd/dnsblockd`                          | Untracked   | Go binary (in .gitignore, harmless)                     |
| `docs/status/2026-03-31_20-31_PHOTOMAP-IMMICH-ROOT-CAUSE-FIX-STATUS.md` | Untracked   | Previous session status report                          |

## GIT LOG (Last 20 Commits)

```
e31125f refactor(types): remove overengineered ContainerService modules
5c5e77c fix(dnsblockd): protect .lan domains from being blocked
3a5547a fix(packages): replace nodePackages.pnpm with top-level pnpm
d20d18c feat(types): add ContainerService type system for OCI containers
3aa124f docs(status): add comprehensive full project status report and statix linting tool
287825f docs(status): add comprehensive post-SilentSDDM integration status report
6cd668e fix(services): resolve photomap container startup and caddy port conflicts
0fd3d6b docs(status): add comprehensive full project status report and statix linting tool
e022038 chore(deps): update flake.lock with latest revisions for all inputs
39fae5b style(niri): add 95% opacity to non-floating windows
ad268ce style(display-manager): fix alejandra formatting for SilentSDDM config
1437c98 feat(sddm): integrate SilentSDDM theme with catppuccin-mocha
76de011 feat(photomap): refactor container configuration with read-only volumes and declarative config
7ac5381 docs(status): add comprehensive post-fix status report
4cf7df9 fix(display-manager): consolidate services block and set defaultSession
1dd0ccb chore: remove dnsblockd binary executable
679b6b7 docs(status): add comprehensive SDDM critical fix and system status report
a641704 fix(networking): resolve port conflict between caddy and dnsblockd
880dee7 refactor(caddy): remove explicit bind addresses for virtual hosts
293899c docs: add improvement ideas tracker for SystemNix project
```
