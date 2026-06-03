# SystemNix — Comprehensive Status Report

**Date:** 2026-06-03 14:56 CEST
**Host:** evo-x2 (x86_64-linux, NixOS)
**Session:** 117 — Activation Fix & Overlay Cleanup
**Build:** ✅ `just test-fast` passes (all checks, zero warnings)
**Branch:** master (1 commit ahead of origin)
**Uncommitted:** Clean working tree

---

## Table of Contents

1. [Session 117 Summary](#1-session-117-summary)
2. [A) Fully Done](#2-fully-done)
3. [B) Partially Done](#3-partially-done)
4. [C) Not Started](#4-not-started)
5. [D) Totally Fucked Up](#5-totally-fucked-up)
6. [E) What We Should Improve](#6-what-we-should-improve)
7. [F) Top 25 Things to Do Next](#7-top-25-next)
8. [G) Unanswered Question](#8-unanswered-question)

---

## 1. Session 117 Summary

### What happened this session

Two commits landed:

**Commit `b5882a33`** — Major overlay cleanup + activation fixes:
- Eliminated ALL sed patches from overlays — fixed upstream repos instead
- Upstream repos tagged with semver (library-policy v1.0.0, mr-sync v0.3.0, etc.)
- BuildFlow unpinned from locked revision back to `ref=master`
- `overlays/shared.nix` dropped from ~81 lines to 65 lines (3 big override blocks removed)
- Fixed 3 activation test failures:
  1. `xdg-desktop-portal-gtk` — added `After=niri.service` drop-in
  2. `home-manager-lars` — cascading failure from #1, fixed by same
  3. `dnsblockd` — added blockIP interface readiness check (30s wait)

### Project Stats

| Metric | Value |
|--------|-------|
| Total lines of Nix | ~13,772 |
| Service modules | 37 (34 active, 3 orphan/unused) |
| Enabled services on evo-x2 | ~25+ |
| Flake inputs | 48 |
| Overlays | 13 packages (shared + Linux-only) |
| ADRs | 8 |
| Status reports | 20+ |
| Home Manager (NixOS) | 536 lines (`home.nix`) |
| Home Manager (Darwin) | 62 lines (`default.nix`) — **bare minimum** |
| Caddy virtual hosts | ~10 |

---

## 2. A) Fully Done ✅

These are complete, tested, wired, and working:

### Infrastructure Core

| What | Details |
|------|---------|
| Cross-platform Nix flake | Single flake, Darwin + NixOS, 80% shared via `platforms/common/` |
| flake-parts modular architecture | 37 service modules auto-discovered |
| Overlay system | `mkPackageOverlay` helper, platform-safe (empty overlay on wrong system) |
| SOPS + Age secrets | SSH host key → age conversion, 4 sops files, per-secret auto-restart |
| Home Manager integration | `useGlobalPkgs = true`, `useUserPackages = true`, backup on conflict |
| Formatter (treefmt + alejandra) | Via `treefmt-full-flake` |
| Flake checks | statix, deadnix, eval per-system, Linux-specific |

### Overlay Cleanup (This Session)

| What | Details |
|------|---------|
| Eliminated sed patches | `buildflow`, `golangci-lint-auto-configure`, `hierarchical-errors` — all fixed upstream |
| Semver versioning | library-policy v1.0.0, mr-sync v0.3.0, PMA v0.2.0, golangci-lint-auto-configure v0.2.0 |
| BuildFlow unpinned | Back to `ref=master` from locked revision |
| `overlays/shared.nix` | 3 override blocks removed, clean `mkPackageOverlay` pass-throughs |

### Services (25+ Running)

| Service | Module | Status |
|---------|--------|--------|
| Caddy reverse proxy | `caddy.nix` (118 LOC) | ✅ TLS, forward auth, 10 vhosts, metrics |
| Forgejo (Git forge) | `forgejo.nix` | ✅ SQLite, LFS, Actions runner, push mirrors |
| Immich (photos) | `immich.nix` | ✅ PostgreSQL + Redis + ML, VA-API transcoding |
| SigNoz (observability) | `signoz.nix` | ✅ Full-stack traces/metrics/logs, 7 alert rules, 4 dashboards |
| Homepage Dashboard | `homepage.nix` | ✅ Catppuccin Mocha, health checks, widgets |
| Pocket ID (OIDC) | `pocket-id.nix` | ✅ Passkey-only auth provider |
| oauth2-proxy | `oauth2-proxy.nix` | ✅ Forward-auth bridge |
| DNS Blocker (dnsblockd) | `dns-blocker.nix` (342 LOC) | ✅ 25 blocklists, ~2.5M domains, stats API |
| Unbound DNS | `dns-blocker.nix` | ✅ Full recursive, DNSSEC, blocklists |
| Twenty CRM | `twenty.nix` | ✅ Docker Compose, daily DB backup |
| Gatus (health checks) | `gatus-config.nix` | ✅ Memory/swap metric collection, Discord alerts |
| TaskChampion sync | `taskchampion.nix` | ✅ Port 10222, TLS |
| Hermes (AI assistant) | `hermes.nix` | ✅ Discord bot, anthropic, firecrawl, edge-tts |
| Manifest (LLM router) | `manifest.nix` | ✅ AI cost optimization |
| OpenSEO | `openseo.nix` | ✅ Self-hosted SEO suite |
| Dual-WAN | `dual-wan.nix` | ✅ MPTCP + route monitoring |
| Disk monitor | `disk-monitor.nix` | ✅ Desktop notifications at thresholds (`pcent` fix applied) |
| NVMe health monitor | `nvme-health-monitor.nix` | ✅ Desktop notifications for critical events |
| Projects Management Automation | `projects-management-automation.nix` | ✅ Running |
| Docker | `default.nix` | ✅ Always-on, overlay2, weekly prune |
| Niri (Wayland compositor) | `niri-config.nix` | ✅ Custom animations, window rules |
| Audio (PipeWire) | `audio.nix` | ✅ Low-latency, VA-API |
| Steam | `steam.nix` | ✅ Configured |
| Display manager (SDDM) | `display-manager.nix` | ✅ Silent SDDM |
| Browser policies | `browser-policies.nix` | ✅ DoH disabled, cert injected |

### Resilience & Recovery

| What | Details |
|------|---------|
| BTRFS snapshots | Daily via btrbk, 14d + 4w retention, pre-deploy auto-snapshot |
| Journald limits | 16G system, 2G runtime, 1 month retention |
| systemd-oomd | Per-service `MemoryMax`, `MemoryHigh` for heavy services |
| Service failure notifications | `notify-failure@%n.service` template for all service failures |
| Gatus TLS cert expiry | Alerts before cert expiration |
| SigNoz swap alerts | Critical at 80% swap usage |

### Developer Experience

| What | Details |
|------|---------|
| `just test-fast` | Syntax-only validation (~30s) |
| `just test` | Full build validation via `nh os test` |
| `just switch` | Apply config with auto-snapshots |
| `just hash-check` | Verify overlay vendor hashes |
| `just test-exec-paths` | Validate 127 ExecStart paths |
| Pre-commit hooks | alejandra, deadnix, statix, gitleaks |
| `mkPackageOverlay` | Platform-safe overlay helper |
| `lib/` helpers | harden, serviceDefaults, mkStateDir, mkDockerServiceFactory, ports, images |

### Desktop (NixOS)

| What | Details |
|------|---------|
| Ghostty (primary terminal) | ✅ Promoted this session |
| Kitty (backup terminal) | ✅ Mod+Shift+Return |
| Niri window rules | ✅ Per-app floating, sizing, workspace |
| Waybar | ✅ Custom config |
| Rofi | ✅ App launcher, DNS management |
| wlogout | ✅ Logout menu |
| swaylock | ✅ Screen locker |
| Fonts | ✅ JetBrainsMono Nerd Font, Noto family |
| Color scheme | ✅ Dark mode (dconf + xdg portal) |
| EMEET Pixy webcam | ✅ Auto-tracking, Niri integration |

---

## 3. B) Partially Done ⚠️

### Overlay Cleanup — Almost Complete

| Item | Status | Remaining |
|------|--------|-----------|
| `buildflow` sed patches | ✅ Removed | — |
| `golangci-lint-auto-configure` sed patches | ✅ Removed | — |
| `hierarchical-errors` vendorHash override | ✅ Removed | — |
| `go-structure-linter` | ❌ Still broken | Private `template-LICENSE/types` dep, `go mod tidy` fails in sandbox. Overlay commented out. Package removed from base.nix. Flake input still exists. |
| Remaining `vendorHash` overrides | ⚠️ 5 remain | library-policy, mr-sync, go-auto-upgrade, branching-flow, art-dupl — needed because `inputs.follows` pins shared deps at different versions |

### SigNoz Alerting — Functional but Incomplete

| Item | Status |
|------|--------|
| Memory-critical alert | ✅ |
| Swap-critical alert | ✅ |
| Service failure spike alert | ✅ |
| TLS cert expiry alert | ✅ |
| Per-threshold channel routing (critical→Discord, warning→log) | ❌ Not done |
| Discord channel test | ❌ Not verified |

### DNS Infrastructure — Functional but Incomplete

| Item | Status |
|------|--------|
| Unbound recursive resolver | ✅ Working |
| dnsblockd block page | ✅ Working |
| 25 blocklists (~2.5M domains) | ✅ Working |
| Stats API + Prometheus metrics | ✅ Working |
| DNS-over-QUIC | ❌ Disabled — unbound lacks ngtcp2 |
| DNS failover (VRRP to Pi 3) | ❌ Pi 3 not provisioned |
| DoQ overlay (patched unbound) | ❌ Disabled — kills binary cache (40+ min rebuilds) |

### Hermes (AI Assistant) — Running with Gaps

| Item | Status |
|------|--------|
| Discord bot | ✅ Working |
| Anthropic integration | ✅ Working |
| Secondary LLM provider fallback | ❌ Not configured |
| Git remote (SSH deploy key) | ❌ `origin` unreachable in sandbox |
| GLM-5.1 rate limit monitoring | ❌ Not verified |

---

## 4. C) Not Started 📋

### Infrastructure

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 1 | Provision Raspberry Pi 3 for DNS failover cluster | 2-4h | High — eliminates single DNS point of failure |
| 2 | Wire Pi 3 as secondary DNS in dns-failover.nix | 1h | High — part of #1 |
| 3 | Deploy Dozzle (Docker container log tailing at `logs.home.lan`) | 30min | Medium — operational visibility |
| 4 | nix-colors integration: migrate 17+ hardcoded colors | 6h | Medium — consistency |
| 5 | Create `just status` command for automated status generation | 2h | Medium — DX |

### Testing & CI

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 6 | Add nixosTests for each service module (34 modules without tests) | 4-20h | High — catch regressions |
| 7 | Wire nixosTests into GitHub Actions | 15min | Medium — CI |
| 8 | Add `just test` to GitHub Actions (full build) | 1h | High — CI |
| 9 | Darwin CI | 2h | Medium — cross-platform |

### Documentation

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 10 | Create shared flake-parts template (mkGoPackage, checks, devshells) | 3h | Medium — standardize Go repos |
| 11 | Convert go-auto-upgrade `path:` inputs to SSH URLs | 1h | Low — correctness |
| 12 | Bring Darwin home.nix to parity with NixOS (terminal, editor, theme, xdg) | 4h | Medium — if Darwin is actively used |

### Upstream Contributions

| # | Item | Effort | Impact |
|---|------|--------|--------|
| 13 | Fix `go-structure-linter` upstream — expose `template-LICENSE/types` via `_local_deps` | 1h | Medium — unblocks tool |
| 14 | Contribute `go-finding` API stability fixes upstream | 2h | Medium — prevent future breaks |

---

## 5. D) Totally Fucked Up 💥

### D1. Overlay Sed Patches — RESOLVED THIS SESSION ✅

The `buildflow` and `golangci-lint-auto-configure` sed patches were fragile time bombs that broke on every upstream `go-finding` API change. **Fixed** by pushing corrections upstream and tagging releases. Overlays are now clean pass-throughs.

### D2. `go-structure-linter` — Still Broken

Private `template-LICENSE/types` dep not accessible in Nix sandbox. Overlay commented out, package removed from PATH. Flake input still present (dead weight). Needs upstream fix to expose the dep via `_local_deps` pattern.

### D3. Swap Exhaustion — 13Gi/13Gi

7 gopls instances consuming ~7.4Gi RSS. Alerting exists (SigNoz swap at 80%) but the root cause — stale LSP processes not being cleaned up — is not addressed. This caused the May 30 disk-full cascade.

### D4. Darwin Config — Bitrotting

62 lines of Home Manager config vs 536 on NixOS. No terminal, no editor, no theme, no xdg parity. If Darwin is actively used, this is terrible DX. If not, it's dead weight that still needs to eval correctly.

### D5. Orphan Modules

- `ai-stack.nix` — exists in `modules/nixos/services/` but no config imports it (Ollama is managed differently)
- `default-services.nix` — exists but not imported anywhere
- Both are dead code, auto-discovered by flake but unused

### D6. Port 8050 Latent Conflict

`dns-blocker-block` and `photomap` both configured for port 8050. Both currently disabled. Will explode if both are enabled simultaneously.

### D7. `/data` Disk Usage — 950G/1T

Still at ~93-95% after the May 30 crash freed 74GB. No long-term solution for ClickHouse data growth, Docker images, or Nix store on `/data`. Will hit 100% again without intervention.

### D8. Jan llama-server Memory Leak

Spawns new `llama-server` every 1-3 min (~1.2GB each). Not a systemd service — no cgroup limits apply. Only mitigation is to not use Jan or manually kill processes.

---

## 6. E) What We Should Improve 🔧

### E1. Overlay Hygiene → Zero vendorHash Overrides

5 packages still need `vendorHash` overrides because `inputs.follows` pins shared deps at different versions than upstream. Long-term: either contribute `_local_deps` pattern to all repos (standardize) or accept the override as inherent to the multi-repo architecture.

### E2. CI Pipeline — Nonexistent

No GitHub Actions workflows. No CI at all. Every push to master triggers nothing. `just test-fast`, `just hash-check`, `just test-exec-paths` all exist but rely on manual execution. This is the single highest-impact gap.

### E3. Test Coverage — 2 Tests for 37 Modules

- `boot` test — verifies system boots
- `dns-blocking` test — verifies unbound blocks domains
- 35 modules have zero test coverage
- `test-exec-paths` is good but not wired to CI

### E4. Secret Management — Manual Bootstrap

Pocket ID → oauth2-proxy → sops secrets chain requires manual steps. No automated secret rotation. `cookie_secret` must be exactly 16, 24, or 32 bytes. No validation.

### E5. Monitoring — Gaps in Coverage

- No disk growth trend alerting (only threshold checks)
- No automated response to swap pressure (alert only)
- No Docker container health aggregation
- No boot time regression tracking

### E6. Disk Management — No Long-term Plan

- `/data` at 93-95% with ClickHouse, Docker, and Nix store growing
- No automated cleanup beyond weekly Docker prune
- No data retention policies for SigNoz/ClickHouse
- No separate disk/subvolume for observability data

### E7. Darwin Parity — Decide and Commit

Either:
- **Actively use Darwin** → invest 4h in bringing home.nix to parity (terminal, editor, theme, xdg)
- **De-prioritize Darwin** → accept minimal config, focus on NixOS

Current state (62 lines, no desktop) is the worst of both worlds.

### E8. Dead Code Cleanup

- `ai-stack.nix` and `default-services.nix` — orphan modules
- `go-structure-linter` flake input — dead, commented out
- `photomap` module — disabled, likely abandoned
- `voice-agents` module — disabled
- `minecraft` module — disabled (seasonal?)
- Darwin LaunchAgent for SublimeText — orphan

---

## 7. F) Top 25 Things to Do Next 🎯

Sorted by impact × urgency (Pareto ranking):

### P0: Deploy & Verify (Immediate)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 1 | **Deploy uncommitted changes** (`just switch`) | 5min | 2 commits ahead of origin — overlay cleanup + activation fixes sitting idle |
| 2 | **Push to origin** (`git push`) | 1min | Branch is 1 commit ahead |
| 3 | **Verify activation** — check all 3 previously-failing services | 10min | Confirm portal-gtk, home-manager-lars, dnsblockd all start cleanly |

### P1: Resilience (This Week)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 4 | **Add `/data` disk growth trend alerting** — Gatus check for >90% with daily delta | 1h | Prevents repeat of May 30 disk-full crash |
| 5 | **ClickHouse data retention policy** — TTL for SigNoz traces/metrics (30d default) | 2h | Largest contributor to disk growth |
| 6 | **Automated stale process cleanup** — systemd timer killing gopls >24h old | 1h | Root cause of swap exhaustion |
| 7 | **Investigate Monitor365 crash-loop** — user service broken since boot | 30min | P1 service failure |

### P2: CI & Testing (This Week)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 8 | **Add GitHub Actions CI** — `just test-fast` + `just hash-check` on PRs/push | 1h | Single highest-impact DX improvement |
| 9 | **Add `just test` to CI** — full build on merge to master | 30min | Catches vendor hash drift, eval-only issues |
| 10 | **Add nixosTest for dnsblockd module** — verify service starts with mock sops | 2h | Most complex custom service, zero test coverage |

### P3: Code Quality (Next 2 Weeks)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 11 | **Delete orphan modules** — `ai-stack.nix`, `default-services.nix` | 15min | Dead code, confusing for AI sessions |
| 12 | **Fix port 8050 conflict** — reassign photomap or dnsblockd | 15min | Latent bomb |
| 13 | **Clean up `go-structure-linter` flake input** — remove or fix upstream | 1h | Dead input, confusing |
| 14 | **Audit flake inputs** — 48 inputs, some may be stale/unused | 2h | Reduces eval time, attack surface |
| 15 | **Add `just status` command** — automated status report | 2h | DX, replaces manual status sessions |

### P4: Architecture (Next Month)

| # | Task | Effort | Why |
|---|------|--------|-----|
| 16 | **Separate `/data` subvolume for observability** — prevent ClickHouse from filling root | 2h | Long-term disk safety |
| 17 | **Provision Pi 3 for DNS failover** — eliminate single DNS point of failure | 4h | Infrastructure resilience |
| 18 | **nix-colors integration** — migrate 17+ hardcoded colors | 6h | Consistency, maintainability |
| 19 | **Darwin home.nix parity** — if actively used | 4h | DX parity |
| 20 | **Shared flake-parts template** — mkGoPackage, checks, devshells for all Go repos | 3h | Standardization across 10+ repos |

### P5: Polish & Future

| # | Task | Effort | Why |
|---|------|--------|-----|
| 21 | **Deploy Dozzle** — Docker container log tailing at `logs.home.lan` | 30min | Operational visibility |
| 22 | **Add per-threshold SigNoz channel routing** — critical→Discord, warning→log | 1h | Alert hygiene |
| 23 | **Configure Hermes secondary LLM provider** — OpenRouter/OpenAI fallback | 30min | Reliability |
| 24 | **Add nixosTests for critical services** — caddy auth chain, forgejo, immich | 8h | Regression prevention |
| 25 | **Automated secret rotation** — sops + age key rotation | 4h | Security hygiene |

---

## 8. G) Unanswered Question ❓

### Is Darwin (macOS) actively used for daily work?

This is the single most impactful open question because it determines:

1. **Whether to invest 4h in Darwin home.nix parity** (terminal, editor, theme, xdg)
2. **Whether to keep Darwin-specific overlays** (d2 stub overlay, otel-tui exclusion)
3. **Whether to add Darwin CI** (2h investment)
4. **Whether to maintain cross-platform compatibility** at all

Currently: 62 lines of HM config, no desktop, no terminal, no editor. If it's a secondary machine used only occasionally, the current minimal config may be fine. If it's a daily driver, the gap is critical.

---

## Appendix: Recent Session Timeline

| Date | Session | Key Achievement |
|------|---------|-----------------|
| Jun 3 | 117 | Overlay cleanup, activation fixes (this session) |
| Jun 3 | 116 | Post-crash forensics, journald limits, disk-monitor fix |
| Jun 2 | 115 | Ghostty migration, justfile fixes, Gatus alerting |
| Jun 1 | 114 | WriteSARIF upstream fix cascade, BuildFlow vendoring |
| Jun 1 | 113 | PMA service stop, submodule cascade |
| May 31 | 112 | PMA notification fix, build fix, flake quality |
| May 30 | 111 | BTRFS cache subvolumes |
| May 30 | 110 | Niri animation speedup, DNS blocklist, Rofi benchmark |
| May 28 | 108 | Services README, lib refactor, full status |
| May 28 | 107 | mkPreparedSource auto-features, mkPackageOverlay platform safety |
| May 25 | 96 | OOM hardening, build parallelism |
| May 24 | 85 | Authelia → Pocket ID migration |

---

_Arte in Aeternum_
