# SystemNix — Comprehensive Status Report

**Date:** 2026-06-02 20:35
**Since Last Report:** Session ~114 → now (~3 weeks of activity)
**Build Status:** ✅ `just test-fast` — all checks passed
**Uncommitted Changes:** 5 files (Ghostty terminal migration)

---

## A) FULLY DONE ✅

### Ghostty Terminal Migration (this session)
- Ghostty added as primary terminal (`Mod+Return`)
- Kitty demoted to backup (`Mod+Shift+Return`)
- Foot remains as Sway fallback only
- XDG default handlers → `com.mitchellh.ghostty.desktop`
- Rofi terminal → ghostty
- Niri autostart (btop, nvtop) → ghostty
- Niri window rules → `^com.mitchellh.ghostty$`
- Floating yazi → `ghostty --class floating -e yazi`
- AGENTS.md updated with terminal hierarchy

### Overlay Extraction (sessions 73–75)
- Overlays extracted from flake.nix → `overlays/` directory (~200 lines saved)
- `mkPackageOverlay` helper for platform-safe overlays
- Shared overlays (NUR, aw-watcher, Go tools) in `overlays/shared.nix`
- Linux-only overlays in `overlays/linux.nix`

### Boot Performance (sessions 71–72)
- `boot.tmp.useTmpfs = true` — 56% boot time reduction (2m13s → 58s)
- Eliminated `unbound-anchor` fetch (~4s savings)
- Conditional `hermes fixPermissionsScript` (~18s savings when perms correct)

### Self.rev Anti-Pattern Elimination (session 70)
- Removed `self.rev` across 29 repos
- Automated versioning with update scripts

### Overlay Upstream Fix Cascade (sessions 112–114)
- `golangci-lint-auto-configure`: patched for `finding.Merge→Combine` API break
- `buildflow`: patched for `finding.Merge→Combine` + `WriteSARIF` signature change
- `go-structure-linter`: disabled entirely — broken upstream `go.sum`

### Go Dependency Management
- All private Go repos use `git+ssh://` URLs (no `path:` inputs)
- `mkPreparedSource` centralized in `go-nix-helpers`
- `vendorHash = ""` pattern documented for dep updates

### Desktop & Compositor
- Niri scrollable-tiling compositor — stable, production-quality
- 80+ keybindings, 5 named workspaces, session save/restore
- XWayland satellite for legacy apps
- Waybar with 15+ modules (CPU, memory, weather, DNS stats, camera, etc.)
- Rofi grid launcher with Catppuccin Mocha theme
- Swaylock, wlogout, dunst, cliphist — all themed

### DNS Stack (~930 lines of Go)
- Full Pi-hole replacement: dynamic TLS, 10-category blocklist, temp-allow API
- 2.5M+ domains blocked, Prometheus metrics, false positive reporting
- Unbound resolver with DNSSEC, DoT upstream, qname minimization

### Observability
- SigNoz: full-stack traces/metrics/logs, 7 alert rules, 4 provisioned dashboards
- Gatus: endpoint health monitoring, TLS cert expiry checks
- Service failure notifications via `notify-failure@` template

### Security
- sops-nix with age (SSH host key as master)
- fail2ban (SSH aggressive), ClamAV, polkit, GNOME Keyring
- systemd hardening via reusable `harden {}` function
- Gitleaks, pre-commit hooks, GitHub Actions CI

### Cross-Platform Foundation
- 80% shared config via `platforms/common/`
- Fish/Zsh/Bash with shared aliases (ADR-002)
- Starship prompt, fzf, git, tmux — all cross-platform
- Catppuccin Mocha theme everywhere
- JetBrainsMono Nerd Font everywhere

---

## B) PARTIALLY DONE ⚠️

### Darwin Config — Bitrotting
- **What works:** System config, packages, shell, Homebrew, security, ActivityWatch, SSH
- **What's missing:** Home Manager has 7 lines of config — no terminal, no editor, no theme, no desktop programs
- **Contrast:** NixOS home.nix has 400+ lines with ghostty, kitty, zed-editor, xdg, dunst, etc.
- **Impact:** MacBook Air works for dev but is far from parity with NixOS desktop experience

### Hermes AI Gateway
- ✅ Discord bot running, sops secrets, 4G memory limit
- ✅ `extraDependencyGroups`: messaging, anthropic, firecrawl, edge-tts, fal, exa
- ❌ No secondary LLM provider (OpenRouter/OpenAI fallback)
- ❌ No git remote access (SSH deploy key missing)
- ❌ GLM-5.1 rate limit monitoring unverified

### SigNoz Provisioning
- ✅ 7 alert rules, 4 dashboards, channel configuration
- ❌ Per-threshold routing (critical→Discord, warning→log) not done
- ❌ Discord test alert not verified
- ❌ Provision logs not checked

### Voice Agents
- Module exists, enabled but `enable = false` in configuration.nix
- Docker ROCm Whisper + LiveKit pipeline — may have bitrot
- Caddy vHost needs consolidation into caddy.nix pattern

### flake.nix Health
- 30+ inputs, `allowBroken = false` enforced
- ⚠️ ~47 inputs — some may be stale/unused (audit needed)
- ⚠️ `go-structure-linter` input exists but package is BROKEN

---

## C) NOT STARTED 📋

| Item | Priority | Effort |
|------|----------|--------|
| Provision Raspberry Pi 3 for DNS failover | P4 | Hardware task |
| Wire Pi 3 as secondary DNS | P4 | 2h |
| nix-colors integration (migrate 17+ hardcoded colors) | P3 | 6h |
| Deploy Dozzle (Docker log viewer) | P3 | 1h |
| Create `just status` command | P3 | 2h |
| Consolidate voice-agents Caddy vHost | P2 | 30min |
| Configure Hermes secondary LLM provider | P0 | 1h |
| Hermes git remote access (SSH deploy key) | P0 | 30min |
| Darwin home-manager parity | P2 | 4h |
| Shared flake-parts template for Go repos | P2 | 3h |
| Convert `go-auto-upgrade` `path:` inputs to SSH URLs | P2 | 30min |

---

## D) TOTALLY FUCKED UP 💥

### 1. go-structure-linter — BROKEN
- **File:** `overlays/shared.nix:87`
- **Why:** Upstream `go.sum` is broken, `template-LICENSE/types` private dep not in `_local_deps`
- **Impact:** Package commented out, cannot be used
- **Fix:** Needs upstream fix — nothing we can do here

### 2. Overlay Patches are Fragile Time Bombs
- **`buildflow`** and **`golangci-lint-auto-configure`** both have sed patches for upstream API breaks
- Every upstream change to `go-finding` API will break these again
- Session 114 was entirely consumed fixing the last cascade
- **Impact:** High maintenance burden, blocks `just update` when it breaks

### 3. Duplicate Package Declarations
- **ghostty** — installed BOTH in `base.nix` (system-level) AND `programs.ghostty` (home-manager)
- **swappy** — installed in BOTH `base.nix` linuxUtilities AND `home.nix` home.packages
- **Impact:** Wasted disk space, potential version mismatch, confusing for maintenance

### 4. Justfile Bugs
- `gatus-status` recipe queries port **8083** (dns-blocker-stats) instead of **9110** (gatus)
- `update-vendor-hashes` recipe has `nix build ".$pkg"` — missing `#`, will fail
- `auth-bootstrap` references `pocket-id.yaml` — wrong filename (actual: `secrets.yaml`)
- `snapshot-migrate-data` references `comfyui.service` which no longer exists

### 5. Stale Artifacts
- `authelia-secrets.yaml` — leftover from Authelia→Pocket ID migration (ADR-007)
- `lib/ports.nix.bak` — backup file in lib/
- `CHANGELOG.md` — boilerplate only, not updated since project start
- 4 scripts referenced in FEATURES.md don't exist: `benchmark-system.sh`, `performance-monitor.sh`, `shell-context-detector.sh`, `storage-cleanup.sh`

### 6. Swap Exhaustion (13Gi/13Gi)
- 7 gopls instances consuming ~7.4Gi RSS
- No memory/swap alerting configured
- **Impact:** System can OOM silently

---

## E) WHAT WE SHOULD IMPROVE

### Architecture
1. **Extract overlay sed patches upstream** — fork `go-finding` or contribute patches so we don't maintain fragile sed commands
2. **`mkHardenedService` wrapper** — combine `harden {} + serviceDefaults {}` into single call
3. **Add typed NixOS options** for key service config (ports, paths, timeouts) — enables validation
4. **Eliminate duplicate packages** — choose system OR home-manager, not both
5. **Persist dnsblockd temp-allows** to SQLite/file — currently lost on restart

### Operations
6. **Fix all justfile bugs** — wrong ports, missing `#`, wrong filenames
7. **Add memory/swap alerting** to SigNoz/Gatus — swap exhaustion is a ticking bomb
8. **Audit 47 flake inputs** — identify stale/unused ones
9. **Clean up stale artifacts** — authelia secrets, ports.nix.bak, dead script references in FEATURES.md
10. **Update CHANGELOG.md** or delete it (session-based status docs are the real changelog)

### Darwin
11. **Bring Darwin home.nix to parity** — add terminal (ghostty/kitty), editor (zed), theme, xdg config
12. **Remove Darwin-specific d2 overlay hack** if no longer needed

### Testing
13. **Add integration tests** — currently only eval-time tests (exec-start-paths, statix, deadnix)
14. **Test deploy on Darwin** — unclear when last `just switch` was run on macOS

---

## F) Top 25 Things We Should Get Done Next

| # | Task | Priority | Effort | Impact |
|---|------|----------|--------|--------|
| 1 | Fix duplicate ghostty (remove from base.nix, keep HM only) | 🔴 | 5min | Clean install |
| 2 | Fix duplicate swappy (remove from base.nix OR home.nix) | 🔴 | 5min | Clean install |
| 3 | Fix justfile `gatus-status` port (8083→9110) | 🔴 | 2min | Correct monitoring |
| 4 | Fix justfile `update-vendor-hashes` missing `#` | 🔴 | 2min | Working recipe |
| 5 | Fix justfile `auth-bootstrap` wrong filename | 🔴 | 2min | Working bootstrap |
| 6 | Configure Hermes secondary LLM provider | 🔴 | 1h | Resilience |
| 7 | Add Hermes git remote SSH deploy key | 🔴 | 30min | Hermes git operations |
| 8 | Add memory/swap alerting to SigNoz/Gatus | 🔴 | 1h | Prevent silent OOM |
| 9 | Investigate swap exhaustion (7 gopls, 13Gi/13Gi) | 🔴 | 2h | System stability |
| 10 | Delete stale `authelia-secrets.yaml` | 🟡 | 1min | Clean secrets dir |
| 11 | Delete stale `lib/ports.nix.bak` | 🟡 | 1min | Clean lib dir |
| 12 | Remove dead script references from FEATURES.md | 🟡 | 5min | Accurate docs |
| 13 | Consolidate voice-agents Caddy vHost | 🟡 | 30min | Clean caddy config |
| 14 | Add per-threshold SigNoz channel routing | 🟡 | 1h | Alert quality |
| 15 | Deploy committed changes to evo-x2 | 🟡 | 30min | Production parity |
| 16 | Verify boot time (~35s target) | 🟡 | 10min | Performance validation |
| 17 | Test SigNoz Discord alert channel | 🟡 | 15min | Alert verification |
| 18 | Verify Gatus endpoints healthy | 🟡 | 10min | Monitoring verification |
| 19 | Bring Darwin home.nix to parity (terminal, editor, theme) | 🟡 | 4h | Cross-platform quality |
| 20 | Update TODO_LIST.md (last updated session 75 — 3 weeks stale) | 🟡 | 30min | Accurate task tracking |
| 21 | Audit 47 flake inputs for stale/unused | 🟢 | 2h | Maintenance |
| 22 | nix-colors integration (17+ hardcoded colors) | 🟢 | 6h | Theme consistency |
| 23 | Deploy Dozzle for Docker log viewing | 🟢 | 1h | Observability |
| 24 | Create `just status` command | 🟢 | 2h | Automation |
| 25 | Provision Raspberry Pi 3 for DNS failover | 🟢 | Hardware | Infrastructure resilience |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Is the Darwin (MacBook Air) config actively used for daily work, or is it just maintained for "in case"?**

The Darwin config is skeletal compared to NixOS — 7 lines of home-manager config, no terminal/editor/theme customization, no desktop programs. If it's actively used, it desperately needs love (4–8h of work). If it's a fallback machine, the current minimal state is fine and we should focus all effort on NixOS.

This matters because it determines whether items #19 and the entire Darwin section are P0 or P5.

---

## Service Enable Matrix (evo-x2)

| Service | Enabled | Module |
|---------|---------|--------|
| accounts-daemon | ✅ | configuration.nix |
| udisks2 | ✅ | configuration.nix |
| sops-config | ✅ | configuration.nix |
| caddy | ✅ | configuration.nix |
| forgejo | ✅ | configuration.nix |
| forgejo-repos | ✅ | configuration.nix |
| immich | ✅ | configuration.nix |
| pocket-id | ✅ | configuration.nix |
| oauth2-proxy | ✅ | configuration.nix |
| homepage | ✅ | configuration.nix |
| taskchampion | ✅ | configuration.nix |
| display-manager | ✅ | configuration.nix |
| audio | ✅ | configuration.nix |
| niri-config | ✅ | configuration.nix |
| niri-session-manager | ✅ | configuration.nix |
| security-hardening | ✅ | configuration.nix |
| gatus-config | ✅ | configuration.nix |
| multi-wm | ✅ | configuration.nix |
| browser-policies | ✅ | configuration.nix |
| steam | ✅ | configuration.nix |
| manifest | ✅ | configuration.nix |
| disk-monitor | ✅ | configuration.nix |
| nvme-health-monitor | ✅ | configuration.nix |
| openseo | ✅ | configuration.nix |
| dual-wan | ✅ | configuration.nix |
| ai-models | ✅ | configuration.nix |
| signoz | ✅ | configuration.nix |
| twenty | ✅ | configuration.nix |
| hermes | ✅ | configuration.nix |
| monitor365 | ✅ | configuration.nix |
| smartd | ✅ | configuration.nix |
| ssh-server | ✅ | configuration.nix |
| projects-management-automation | ✅ | configuration.nix |
| **file-and-image-renamer** | ❌ | Go 1.26.3 unavailable |
| **voice-agents** | ❌ | Disabled |
| **minecraft** (server) | ❌ | Disabled |

**35 services enabled, 3 disabled.**

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Total flake inputs | 30+ |
| NixOS service modules | 29 |
| Custom packages | 13 |
| Cross-platform programs | 20+ |
| NixOS desktop components | 15+ |
| Justfile commands | 90+ |
| Validation scripts | 8 (4 dead references) |
| ADRs | 5 |
| GitHub Actions | 3 |
| Total enabled features | ~140 |
| BROKEN markers | 2 (go-structure-linter) |
| TODO markers | 1 (Pi 3 provisioning) |
| Build status | ✅ All checks passed |
| Uncommitted changes | 5 files (Ghostty migration) |

---

_Arte in Aeternum_
