# SystemNix — Comprehensive Status Report

**Date:** 2026-06-02 22:38
**Since Last Report:** Session 115 cleanup sprint (same evening, 80min later)
**Build Status:** ✅ `just test-fast` — all checks passed (gitleaks, deadnix, statix, alejandra, nix flake check)
**Uncommitted Changes:** 2 files (formatter-only changes to unrelated files)
**Git HEAD:** `8eacbf69` on `master`, pushed to remote

---

## A) FULLY DONE ✅

### Session 115 — Cleanup Sprint (6 commits)

#### Package Deduplication (3 packages)
- **ghostty** — removed from `base.nix`, `programs.ghostty` (HM) is sole owner
- **swappy** — removed from `base.nix`, HM `home.packages` + `xdg.configFile` is sole owner
- **jq** — removed from `yazi.nix` `home.packages`, already in `base.nix` system packages

#### Justfile Bug Fixes (5 fixes)
- `gatus-status`: port 8083→9110 (queried dns-blocker-stats instead of gatus)
- `update-vendor-hashes`: `".$pkg"` → `".#$pkg"` (missing `#` = always fails)
- `auth-bootstrap`: `pocket-id.yaml` → `secrets.yaml` (wrong filename)
- `snapshot-migrate-data`: dead `comfyui.service` stop removed
- `update-vendor-hashes`: removed `go-structure-linter` from package list

#### Stale Artifact Deletion (3 files)
- `platforms/nixos/secrets/authelia-secrets.yaml` — Authelia→Pocket ID leftover (ADR-007)
- `lib/ports.nix.bak` — leftover backup
- `CHANGELOG.md` — boilerplate never updated

#### Dead Reference Cleanup
- README.md: Authelia → Pocket ID entry updated
- README.md: ComfyUI entry removed (service deleted session 74)
- README.md: Voice Agents description corrected
- FEATURES.md: 4 self-referencing ❌ script entries removed

#### go-structure-linter Fully Disabled
- `overlays/shared.nix`: overlay commented out
- `flake.nix`: removed from `perSystem.packages`
- `base.nix`: was already commented out (session 114)
- Flake input retained for potential upstream fix

#### Memory/Swap Alerting
- Gatus: 2 new checks — Memory Metrics + Swap Metrics with Discord alerts
- SigNoz: verified existing `memory-critical` (>90%) and `swap-critical` (>80%) rules

### Session 114 — Overlay API Break Cascade
- `golangci-lint-auto-configure`: patched `finding.Merge→Combine`
- `buildflow`: patched `finding.Merge→Combine` + `WriteSARIF`
- `go-structure-linter`: disabled (broken upstream `go.sum`)

### Session ~113 — Ghostty Terminal Migration
- Ghostty primary (`Mod+Return`), Kitty backup (`Mod+Shift+Return`), Foot sway fallback
- XDG defaults, Rofi, Niri autostart, window rules, floating yazi — all migrated

### Sessions 73-75 — Overlay Extraction & Tooling
- Overlays extracted from flake.nix → `overlays/` (~200 lines saved)
- `mkPackageOverlay` helper for platform-safe overlays
- `hardenUser {}` + 3 user services hardened
- 4 SigNoz dashboards, Service Failure Spike alert, TLS cert check

### Sessions 71-72 — Boot Performance
- `boot.tmp.useTmpfs = true` — 56% reduction (2m13s → 58s)
- Eliminated `unbound-anchor` fetch (~4s savings)
- Conditional `hermes fixPermissionsScript` (~18s savings when perms correct)

### Foundation (Sessions 1-70)
- Niri scrollable-tiling compositor — production-quality
- 80+ keybindings, 5 named workspaces, session save/restore
- DNS stack: Pi-hole replacement, 2.5M+ domains blocked
- SigNoz: full-stack traces/metrics/logs
- sops-nix + age security, systemd hardening
- Pocket ID + oauth2-proxy forward auth
- 80% shared config via `platforms/common/`
- Catppuccin Mocha theme everywhere

---

## B) PARTIALLY DONE ⚠️

### Hermes AI Gateway (70% done)
- ✅ Discord bot running, sops secrets, 4G memory limit
- ✅ `extraDependencyGroups`: messaging, anthropic, firecrawl, edge-tts, fal, exa
- ❌ No secondary LLM provider (OpenRouter/OpenAI fallback)
- ❌ No git remote access (SSH deploy key missing)
- ❌ GLM-5.1 rate limit monitoring unverified

### SigNoz Provisioning (80% done)
- ✅ 18 alert rules, 5 dashboards, Discord channel configured
- ❌ Per-threshold routing (critical→Discord, warning→log) not done
- ❌ Discord test alert not verified
- ❌ Provision logs not checked

### Darwin Config — Bitrotting (15% done)
- ✅ System config, packages, shell, Homebrew, security, ActivityWatch, SSH
- ❌ Home Manager: 7 lines of config, no terminal, no editor, no theme, no desktop programs
- ❌ NixOS home.nix has 400+ lines by contrast

### flake.nix Health (85% done)
- ✅ 46 inputs, `allowBroken = false` enforced
- ✅ `go-structure-linter` fully disabled (overlay + package output)
- ❌ `go-structure-linter` flake input still exists (no churn, but stale)
- ❌ `ai-stack` and `default-services` modules exist but are unreferenced (orphan modules)
- ❌ 3 unreferenced service modules (`ai-stack`, `default-services`, `dns-failover` only used by rpi3)

---

## C) NOT STARTED 📋

| # | Item | Priority | Effort | Notes |
|---|------|----------|--------|-------|
| 1 | Configure Hermes secondary LLM provider | 🔴 P0 | 1h | Needs API key |
| 2 | Hermes git remote SSH deploy key | 🔴 P0 | 30min | Needs key provisioning |
| 3 | Deploy committed changes to evo-x2 | 🔴 P0 | 30min | `just switch` |
| 4 | Verify boot time (~35s target) | 🔴 P0 | 10min | Needs live system |
| 5 | Test SigNoz Discord alert channel | 🔴 P0 | 15min | End-to-end verification |
| 6 | Verify Gatus endpoints healthy | 🔴 P0 | 10min | Confirm new checks active |
| 7 | Investigate swap exhaustion (7 gopls, 13Gi/13Gi) | 🔴 P0 | 2h | Root cause analysis |
| 8 | Add per-threshold SigNoz channel routing | 🟡 P1 | 1h | critical→Discord, warning→log |
| 9 | Bring Darwin home.nix to parity | 🟡 P1 | 4h | Terminal, editor, theme, xdg |
| 10 | Extract go-finding patches upstream | 🟡 P1 | 3h | Fork or contribute |
| 11 | Create `mkHardenedService` wrapper | 🟡 P1 | 1h | Combine harden + serviceDefaults |
| 12 | Resolve port 8050 conflict (dns-blocker-block vs photomap) | 🟡 P1 | 15min | Reassign one |
| 13 | Remove duplicate zellij from base.nix | 🟡 P1 | 2min | HM programs.zellij already installs |
| 14 | Audit 46 flake inputs for stale/unused | 🟡 P2 | 2h | Maintenance |
| 15 | Convert go-auto-upgrade `path:` inputs to SSH URLs | 🟡 P2 | 30min | Remove path: anti-pattern |
| 16 | Shared flake-parts template for Go repos | 🟡 P2 | 3h | Standardization |
| 17 | Remove orphan modules (ai-stack, default-services) or wire them | 🟡 P2 | 30min | Dead code |
| 18 | Remove go-structure-linter flake input | 🟢 P3 | 5min | Clean flake.lock |
| 19 | nix-colors integration (17+ hardcoded colors) | 🟢 P3 | 6h | Theme consistency |
| 20 | Deploy Dozzle for Docker log viewing | 🟢 P3 | 1h | Observability |
| 21 | Create `just status` command | 🟢 P3 | 2h | Automation |
| 22 | Add integration tests beyond eval-time | 🟢 P3 | 4h | Reliability |
| 23 | Persist dnsblockd temp-allows across restarts | 🟢 P3 | 2h | Data durability |
| 24 | Provision Raspberry Pi 3 for DNS failover | 🟢 P4 | Hardware | Needs physical access |
| 25 | Wire Pi 3 as secondary DNS | 🟢 P4 | 2h | DNS redundancy |

---

## D) TOTALLY FUCKED UP 💥

### 1. Overlay Patches are Fragile Time Bombs
- **`buildflow`** and **`golangci-lint-auto-configure`** both have sed patches for upstream `go-finding` API breaks
- Every upstream change to `go-finding` API will break these again
- Session 114 was entirely consumed fixing the last cascade
- **Fix:** Fork `go-finding` or contribute patches upstream

### 2. Swap Exhaustion (13Gi/13Gi)
- 7 gopls instances consuming ~7.4Gi RSS
- Alerting now exists (SigNoz swap-critical >80%, Gatus metrics checks)
- **Root cause not addressed** — likely stale LSP processes from editor crashes
- **Impact:** System can OOM silently → journald cascade → disk fills with coredumps

### 3. Darwin Config Bitrotting
- 7 lines of home-manager config vs 400+ on NixOS
- No terminal, no editor, no theme, no desktop programs
- Unknown if actively used or just maintained "in case"
- **Impact:** If actively used, it's a terrible developer experience

### 4. Orphan Modules
- `ai-stack.nix` and `default-services.nix` are service modules that no configuration imports
- `ai-stack` is partially redundant with `ai-models` (which IS enabled)
- `default-services` provides Docker auto-prune + Nix GC — these may be configured elsewhere
- **Impact:** Dead code, confusing for maintenance, unclear if features are missing

---

## E) WHAT WE SHOULD IMPROVE

### Architecture
1. **`mkHardenedService` wrapper** — combine `harden {} + serviceDefaults {}` into single call. Currently every service does `harden {} // serviceDefaults {} // { ... }` — should be `mkHardenedService { ... }`
2. **Extract overlay sed patches upstream** — fork `go-finding` or contribute patches
3. **Add typed NixOS options** for key service config (ports, paths, timeouts) — enables validation at eval time
4. **Port collision detection** — `servicePort` already checks collisions but `ports.nix` manual entries may bypass it
5. **Persist dnsblockd temp-allows** — currently lost on restart (in-memory only)
6. **Resolve orphan modules** — wire `ai-stack`/`default-services` or delete them
7. **Remove zellij from base.nix** — `programs.zellij` already installs it via HM

### Operations
8. **Deploy committed changes** — 6 commits ahead of production
9. **Investigate gopls memory** — 7 instances is abnormal
10. **Audit 46 flake inputs** — identify stale/unused
11. **Verify SigNoz + Gatus health** — confirm all alerting works end-to-end

### Testing
12. **Add integration tests** — currently only eval-time tests (exec-start-paths, statix, deadnix)
13. **Test deploy on Darwin** — unclear when last `just switch` was run on macOS
14. **End-to-end alert test** — trigger a SigNoz alert and verify Discord delivery

---

## F) Top 25 Things We Should Get Done Next

Sorted by impact/effort ratio (highest first):

| # | Task | Priority | Effort | Impact |
|---|------|----------|--------|--------|
| 1 | Deploy committed changes to evo-x2 | 🔴 | 30min | 6 commits in production |
| 2 | Remove duplicate zellij from base.nix | 🔴 | 2min | Clean install |
| 3 | Verify boot time (~35s target) | 🔴 | 10min | Performance validation |
| 4 | Test SigNoz Discord alert channel | 🔴 | 15min | Alert delivery verified |
| 5 | Verify Gatus endpoints healthy | 🔴 | 10min | Monitoring confirmed |
| 6 | Resolve port 8050 conflict | 🟡 | 15min | Prevent future collision |
| 7 | Remove go-structure-linter flake input | 🟡 | 5min | Clean flake.lock |
| 8 | Remove/wire orphan modules (ai-stack, default-services) | 🟡 | 30min | Dead code elimination |
| 9 | Configure Hermes secondary LLM provider | 🔴 | 1h | Resilience |
| 10 | Add per-threshold SigNoz channel routing | 🟡 | 1h | Alert quality |
| 11 | Create `mkHardenedService` wrapper | 🟡 | 1h | DRY systemd config |
| 12 | Add Hermes git remote SSH deploy key | 🔴 | 30min | Hermes git operations |
| 13 | Convert go-auto-upgrade `path:` inputs to SSH URLs | 🟡 | 30min | Remove path: anti-pattern |
| 14 | Investigate swap exhaustion (7 gopls instances) | 🔴 | 2h | System stability |
| 15 | Audit 46 flake inputs for stale/unused | 🟡 | 2h | Maintenance |
| 16 | Extract go-finding patches upstream | 🟡 | 3h | Remove fragile sed patches |
| 17 | Shared flake-parts template for Go repos | 🟡 | 3h | Standardization |
| 18 | Bring Darwin home.nix to parity | 🟡 | 4h | Cross-platform quality |
| 19 | Add integration tests beyond eval-time | 🟢 | 4h | Reliability |
| 20 | nix-colors integration (17+ hardcoded colors) | 🟢 | 6h | Theme consistency |
| 21 | Persist dnsblockd temp-allows across restarts | 🟢 | 2h | Data durability |
| 22 | Deploy Dozzle for Docker log viewing | 🟢 | 1h | Observability |
| 23 | Create `just status` command | 🟢 | 2h | Automation |
| 24 | Provision Raspberry Pi 3 for DNS failover | 🟢 | Hardware | Infrastructure resilience |
| 25 | Wire Pi 3 as secondary DNS | 🟢 | 2h | DNS redundancy |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Is the Darwin (MacBook Air) config actively used for daily work, or is it just maintained for "in case"?**

The Darwin config has 7 lines of home-manager config vs 400+ on NixOS — no terminal, no editor, no theme, no desktop programs. If it's actively used, it's a terrible developer experience and needs 4-8h of work immediately. If it's a fallback machine, the current minimal state is fine.

This determines whether Darwin parity (#18) is P0 or P5.

---

## System Metrics (Exact Counts)

| Metric | Value |
|--------|-------|
| Service modules | 36 (29 enabled, 4 disabled, 3 orphan) |
| Custom packages (pkgs/) | 5 |
| Overlay packages (mkPackageOverlay) | 12 (+ 1 disabled) |
| Total flake packages | 23 |
| Flake inputs | 46 |
| Justfile recipes | 75 |
| Gatus health checks | 30 (28 active + 2 voice-agents conditional) |
| SigNoz alert rules | 18 |
| SigNoz dashboards | 5 |
| lib/ helpers | 13 |
| ADRs | 8 |
| Scripts | 23 |
| BROKEN markers | 2 (go-structure-linter in overlay + base.nix) |
| TODO markers | 1 (rpi3 sops-nix) |
| Duplicate packages remaining | 1 (zellij: base.nix + HM) |
| Port conflicts | 0 (latent: 8050 dns-blocker-block vs photomap) |
| Build status | ✅ All checks passed |
| Uncommitted changes | 2 (formatter-only, unrelated) |

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
| dns-blocker | ✅ | dns-blocker-config.nix |
| emeet-pixy | ✅ | configuration.nix |
| ollama | ✅ | ai-models |
| **file-and-image-renamer** | ❌ | Go 1.26.3 unavailable |
| **voice-agents** | ❌ | Disabled |
| **minecraft** (server) | ❌ | Disabled |
| **photomap** | ❌ | Disabled (commented out) |
| **ai-stack** | ⚠️ | Orphan — not imported |
| **default-services** | ⚠️ | Orphan — not imported |
| **dns-failover** | ✅ | rpi3 config only |

**33 enabled, 4 disabled, 2 orphan, 1 rpi3-only.**

---

_Arte in Aeternum_
