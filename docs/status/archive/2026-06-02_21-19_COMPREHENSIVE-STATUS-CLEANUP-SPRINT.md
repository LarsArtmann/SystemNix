# SystemNix — Comprehensive Status Report

**Date:** 2026-06-02 21:19
**Since Last Report:** Session 114 → session 115 (~hours, same evening)
**Build Status:** ✅ `just test-fast` — all checks passed
**Uncommitted Changes:** 10 files (cleanup, bug fixes, alerting, docs)

---

## A) FULLY DONE ✅

### Session 115: Cleanup Sprint

#### Package Deduplication
- **ghostty** — removed duplicate from `base.nix`, kept Home Manager (`programs.ghostty`) as single owner
- **swappy** — removed duplicate from `base.nix`, kept Home Manager (`home.packages` + `xdg.configFile`) as single owner
- **jq** — removed duplicate from `yazi.nix` home.packages, already in `base.nix` system packages

#### Justfile Bug Fixes (4 bugs)
- `gatus-status` — port 8083 (dns-blocker-stats) → 9110 (gatus) — wrong service queried
- `update-vendor-hashes` — `".$pkg"` → `".#$pkg"` — missing `#` would fail on every invocation
- `auth-bootstrap` — `pocket-id.yaml` → `secrets.yaml` — wrong filename, bootstrap would misdirect users
- `snapshot-migrate-data` — removed dead `comfyui.service` stop (ComfyUI deleted in session 74)

#### Stale Artifact Cleanup (3 files deleted)
- `platforms/nixos/secrets/authelia-secrets.yaml` — leftover from Authelia→Pocket ID migration (ADR-007)
- `lib/ports.nix.bak` — leftover backup file
- `CHANGELOG.md` — boilerplate only, never updated since project inception

#### Dead References Removed
- FEATURES.md — 4 self-referencing ❌ script entries removed (benchmark-system.sh, performance-monitor.sh, shell-context-detector.sh, storage-cleanup.sh)
- README.md — stale ComfyUI service entry removed (service deleted session 74)
- README.md — Authelia entry updated to Pocket ID (port 9091→1411, correct description)
- `update-vendor-hashes` — removed `go-structure-linter` from package list (BROKEN, will never update)

#### go-structure-linter Full Disable
- Overlay in `overlays/shared.nix` — commented out (was still building despite being BROKEN)
- Package output in `flake.nix` — removed from `perSystem.packages`
- Package in `base.nix` — was already commented out (session 114)
- Flake input retained — may be fixed upstream, no `flake.lock` churn

#### Memory/Swap Alerting
- Gatus — added Memory Metrics + Swap Metrics collection checks with Discord alerts
- SigNoz — verified existing `memory-critical` (>90%) and `swap-critical` (>80%) alert rules already in place
- Coverage: metric collection (Gatus) + threshold alerting (SigNoz) + Discord notification (both)

#### Documentation Updates
- TODO_LIST.md — fully updated, all completed items archived, current state reflected
- AGENTS.md — terminal hierarchy documented (session ~114)

### Prior Sessions (Still Valid)

#### Overlay Extraction (sessions 73–75)
- Overlays extracted from flake.nix → `overlays/` directory (~200 lines saved)
- `mkPackageOverlay` helper for platform-safe overlays

#### Boot Performance (sessions 71–72)
- `boot.tmp.useTmpfs = true` — 56% boot time reduction (2m13s → 58s)

#### Desktop & Compositor
- Niri scrollable-tiling compositor — stable, production-quality
- 80+ keybindings, 5 named workspaces, session save/restore
- Ghostty primary, Kitty backup, Foot sway fallback

#### DNS Stack
- Full Pi-hole replacement: dynamic TLS, 10-category blocklist, temp-allow API
- 2.5M+ domains blocked, Prometheus metrics

#### Observability
- SigNoz: 15+ alert rules (memory, swap, CPU, disk, GPU, NVMe SMART, service failures)
- Gatus: 25+ health checks with Discord webhooks
- 5 provisioned dashboards (overview, GPU, DNS, Docker, Caddy)

#### Security
- sops-nix with age (SSH host key as master)
- systemd hardening via reusable `harden {}` function
- Pocket ID + oauth2-proxy forward auth for all web services

#### Cross-Platform Foundation
- 80% shared config via `platforms/common/`
- Catppuccin Mocha theme everywhere

---

## B) PARTIALLY DONE ⚠️

### Hermes AI Gateway
- ✅ Discord bot running, sops secrets, 4G memory limit
- ✅ `extraDependencyGroups`: messaging, anthropic, firecrawl, edge-tts, fal, exa
- ❌ No secondary LLM provider (OpenRouter/OpenAI fallback)
- ❌ No git remote access (SSH deploy key missing)
- ❌ GLM-5.1 rate limit monitoring unverified

### SigNoz Provisioning
- ✅ 15+ alert rules, 5 dashboards, channel configuration
- ❌ Per-threshold routing (critical→Discord, warning→log) not done
- ❌ Discord test alert not verified
- ❌ Provision logs not checked

### Voice Agents
- Module exists, enabled but `enable = false` in configuration.nix
- Caddy vHost already consolidated in caddy.nix (verified this session)
- Whisper ASR description updated in README.md

### flake.nix Health
- 30+ inputs, `allowBroken = false` enforced
- ⚠️ `go-structure-linter` input retained but overlay + package output disabled
- ⚠️ ~46 inputs — audit needed for stale/unused

### Darwin Config — Bitrotting
- **What works:** System config, packages, shell, Homebrew, security, ActivityWatch, SSH
- **What's missing:** Home Manager has 7 lines of config — no terminal, no editor, no theme, no desktop programs
- **Contrast:** NixOS home.nix has 400+ lines

---

## C) NOT STARTED 📋

| Item | Priority | Effort |
|------|----------|--------|
| Configure Hermes secondary LLM provider | P0 | 1h |
| Hermes git remote SSH deploy key | P0 | 30min |
| Bring Darwin home.nix to parity | P2 | 4h |
| nix-colors integration (17+ hardcoded colors) | P3 | 6h |
| Deploy Dozzle (Docker log viewer) | P3 | 1h |
| Create `just status` command | P3 | 2h |
| Shared flake-parts template for Go repos | P2 | 3h |
| Convert `go-auto-upgrade` `path:` inputs to SSH URLs | P2 | 30min |
| Provision Raspberry Pi 3 for DNS failover | P4 | Hardware |
| Wire Pi 3 as secondary DNS | P4 | 2h |
| Investigate swap exhaustion (7 gopls, 13Gi/13Gi) | P2 | 2h |
| Audit 46 flake inputs for stale/unused | P3 | 2h |
| Resolve port 8050 conflict (dns-blocker-block vs photomap) | P3 | 15min |

---

## D) TOTALLY FUCKED UP 💥

### 1. Overlay Patches are Fragile Time Bombs
- **`buildflow`** and **`golangci-lint-auto-configure`** both have sed patches for upstream API breaks
- Every upstream change to `go-finding` API will break these again
- Session 114 was entirely consumed fixing the last cascade
- **Fix needed:** Fork `go-finding` or contribute patches upstream

### 2. Swap Exhaustion (13Gi/13Gi)
- 7 gopls instances consuming ~7.4Gi RSS
- SigNoz now has alerting for this (swap-critical >80%), but root cause not addressed
- **Impact:** System can OOM silently despite alerting

### 3. Latent Port Conflict
- `dns-blocker-block = 8050` in `lib/ports.nix` conflicts with `photomap` port 8050
- Both disabled currently (photomap disabled, dns-blocker-block overridden to 80)
- Would collide if both enabled simultaneously
- `servicePort` collision checker may not catch `ports.nix` manual entries

---

## E) WHAT WE SHOULD IMPROVE

### Architecture
1. **Extract overlay sed patches upstream** — fork `go-finding` or contribute patches
2. **`mkHardenedService` wrapper** — combine `harden {} + serviceDefaults {}` into single call
3. **Add typed NixOS options** for key service config (ports, paths, timeouts)
4. **Port collision detection** — extend `servicePort` to check `ports.nix` entries too
5. **Persist dnsblockd temp-allows** to SQLite/file — currently lost on restart
6. **Remove `go-structure-linter` flake input** once confirmed permanently broken

### Operations
7. **Deploy committed changes** — ghostty migration, justfile fixes, alerting improvements
8. **Investigate gopls memory** — 7 instances is abnormal, likely LSP not shutting down
9. **Audit 46 flake inputs** — identify stale/unused, especially disabled services
10. **Test deploy on Darwin** — unclear when last `just switch` was run on macOS

### Testing
11. **Add integration tests** — currently only eval-time tests
12. **Verify SigNoz Discord alerts** — test end-to-end alert delivery
13. **Verify Gatus endpoint health** — confirm new memory/swap checks active

---

## F) Top 25 Things We Should Get Done Next

| # | Task | Priority | Effort | Impact |
|---|------|----------|--------|--------|
| 1 | Deploy committed changes to evo-x2 | 🔴 | 30min | Production parity |
| 2 | Verify boot time (~35s target) | 🔴 | 10min | Performance validation |
| 3 | Test SigNoz Discord alert channel | 🔴 | 15min | Alert verification |
| 4 | Verify Gatus endpoints healthy | 🔴 | 10min | Monitoring verification |
| 5 | Configure Hermes secondary LLM provider | 🔴 | 1h | Resilience |
| 6 | Add Hermes git remote SSH deploy key | 🔴 | 30min | Hermes git operations |
| 7 | Investigate swap exhaustion (7 gopls instances) | 🔴 | 2h | System stability |
| 8 | Resolve port 8050 conflict (dns-blocker-block vs photomap) | 🟡 | 15min | Prevent future collision |
| 9 | Add per-threshold SigNoz channel routing | 🟡 | 1h | Alert quality |
| 10 | Audit 46 flake inputs for stale/unused | 🟡 | 2h | Maintenance |
| 11 | Bring Darwin home.nix to parity | 🟡 | 4h | Cross-platform quality |
| 12 | Extract go-finding patches upstream | 🟡 | 3h | Remove fragile sed patches |
| 13 | Create `mkHardenedService` wrapper | 🟡 | 1h | DRY systemd config |
| 14 | Remove go-structure-linter flake input | 🟡 | 5min | Clean flake.lock |
| 15 | Convert go-auto-upgrade `path:` inputs to SSH URLs | 🟡 | 30min | Remove path: anti-pattern |
| 16 | Shared flake-parts template for Go repos | 🟡 | 3h | Standardization |
| 17 | nix-colors integration (17+ hardcoded colors) | 🟢 | 6h | Theme consistency |
| 18 | Deploy Dozzle for Docker log viewing | 🟢 | 1h | Observability |
| 19 | Create `just status` command | 🟢 | 2h | Automation |
| 20 | Add integration tests beyond eval-time | 🟢 | 4h | Reliability |
| 21 | Persist dnsblockd temp-allows across restarts | 🟢 | 2h | Data durability |
| 22 | Provision Raspberry Pi 3 for DNS failover | 🟢 | Hardware | Infrastructure resilience |
| 23 | Wire Pi 3 as secondary DNS | 🟢 | 2h | DNS redundancy |
| 24 | Port collision detection for ports.nix entries | 🟢 | 1h | Prevent future conflicts |
| 25 | Test deploy on Darwin | 🟢 | 30min | Cross-platform verification |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Is the Darwin (MacBook Air) config actively used for daily work, or is it just maintained for "in case"?**

The Darwin config is skeletal compared to NixOS — 7 lines of home-manager config, no terminal/editor/theme customization, no desktop programs. If it's actively used, it desperately needs love (4–8h of work). If it's a fallback machine, the current minimal state is fine and we should focus all effort on NixOS.

This matters because it determines whether items #11 and the entire Darwin section are P0 or P5.

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

**33 services enabled, 3 disabled.**

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Total flake inputs | 46 |
| NixOS service modules | 29 |
| Custom packages | 22 (was 23 with go-structure-linter) |
| Cross-platform programs | 20+ |
| NixOS desktop components | 15+ |
| Justfile commands | 90+ |
| Validation scripts | 7 (all existing) |
| ADRs | 7 (ADR-007 Authelia→Pocket ID) |
| GitHub Actions | 3 |
| SigNoz alert rules | 15+ |
| Gatus health checks | 27+ |
| BROKEN markers | 1 (go-structure-linter — now fully disabled) |
| Build status | ✅ All checks passed |
| Uncommitted changes | 10 files |

---

_Arte in Aeternum_
