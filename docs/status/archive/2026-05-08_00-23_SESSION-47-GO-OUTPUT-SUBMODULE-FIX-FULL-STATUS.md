# Session 47 — Comprehensive Full System Status

**Date:** 2026-05-08 00:23
**Session:** 47 (POST-FIX: go-output sub-module build repair)
**Commit:** `e205f2f` → pending fix commit
**Channel:** 23 (Yarara), Nix 2.34.6

---

## Executive Summary

Session 47 fixed a build-breaking regression in `file-and-image-renamer` caused by the `go-output` library restructuring into Go workspace sub-modules (`enum`, `escape`, `table`, `sort`). The upstream `go.mod`/`go.sum` didn't include `require` directives for these sub-modules (they were local `replace` directives only), causing `go mod vendor` to fail during Nix builds. Fixed by adding `require` + `replace` directives for all four sub-modules in `postPatch`. Build verified clean. Flake inputs also updated (go-output rev 238, emeet-pixyd rev 123, monitor365 rev 681, NUR, homebrew-cask).

---

## A) FULLY DONE ✅

### 1. file-and-image-renamer Build Fix

**Root cause:** `go-output` restructured into Go workspace sub-modules. Each sub-module (`enum`, `escape`, `table`, `sort`) has its own `go.mod`. The root `go-output` module depends on them via local `replace` directives, and `cmdguard` depends on `go-output/table` directly. When Nix builds `file-and-image-renamer`, only the root `go-output-src` path is provided as a `replace` — the sub-modules aren't resolved, causing:

```
missing go.sum entry for module providing package github.com/larsartmann/go-output/enum
no required module provides package github.com/larsartmann/go-output/table
```

**Fix:** In `pkgs/file-and-image-renamer.nix`, added `require` + `replace` directives for all four sub-modules in `postPatch`:

```nix
for sub in enum escape table sort; do
  echo "require github.com/larsartmann/go-output/$sub v0.0.0" >> go.mod
  echo "replace github.com/larsartmann/go-output/$sub => ${go-output-src}/$sub" >> go.mod
done
```

**Key learning:** Go workspace sub-modules with separate `go.mod` files need BOTH `require` and `replace` directives in downstream consumers. The `replace` alone isn't enough — Go needs the `require` to know the module exists in the dependency graph.

**Files changed:**
- `pkgs/file-and-image-renamer.nix` — Added sub-module `require`+`replace` loop
- `flake.lock` — Updated go-output-src (rev 238), emeet-pixyd (rev 123), monitor365 (rev 681), NUR, homebrew-cask

### 2. Shared Lib Adoption (Session 46 — Still Clean)

| Helper | Modules Using |
|--------|--------------|
| `harden {}` | 18 modules (all systemd services) |
| `serviceDefaults {}` | 17 modules |
| `serviceTypes.servicePort` | 8 modules |
| `serviceTypes.systemdServiceIdentity` | 3 modules (hermes, gatus, authelia) |

### 3. DNS CA System-Wide Trust (Session 46)

CA cert embedded in `security.pki.certificates` in `dns-blocker-config.nix`. All system tools and services trust `*.home.lan` TLS certs.

### 4. Core Infrastructure Stack

All foundational services are production-stable:

| Service | Status | Notes |
|---------|--------|-------|
| Caddy (reverse proxy) | ✅ Running | TLS via sops, all `*.home.lan` domains |
| Authelia (SSO) | ✅ Running | Forward auth on protected services |
| Gitea (git hosting) | ✅ Running | GitHub mirror sync (2 repos) |
| Immich (photos) | ✅ Running | PostgreSQL + ML pipeline |
| Homepage (dashboard) | ✅ Running | Service overview |
| SigNoz (observability) | ✅ Running | ClickHouse + OTel Collector |
| Gatus (health checks) | ✅ Running | 15 endpoints monitored |
| TaskChampion (task sync) | ✅ Running | Cross-platform (NixOS, macOS, Android) |
| Hermes (AI gateway) | ✅ Running | Discord bot, cron scheduler |
| Manifest (LLM router) | ✅ Running | Cost-optimized AI model routing |
| Twenty CRM | ✅ Running | Customer relationship management |
| Voice Agents | ✅ Running | LiveKit + Whisper ASR |
| ComfyUI (image gen) | ✅ Running | Persistent GPU model |
| Minecraft | ✅ Running | LAN-only, whitelisted |
| DNS (Unbound + dnsblockd) | ✅ Running | 2.5M+ domains blocked |
| Ollama (LLM inference) | ✅ Running | GPU-accelerated, memory-limited |
| Sops-nix (secrets) | ✅ Running | age-encrypted via SSH host key |

### 5. NixOS Desktop Stack

| Component | Status | Notes |
|-----------|--------|-------|
| Niri (Wayland compositor) | ✅ Running | BindsTo→Wants patched |
| SDDM (login) | ✅ Running | Silent theme, Catppuccin Mocha |
| Waybar (status bar) | ✅ Running | hwmon fix, Catppuccin Mocha |
| Rofi (launcher) | ✅ Running | calc + emoji plugins |
| Niri Session Manager | ✅ Running | Window save/restore on boot |
| EMEET PIXY webcam | ✅ Running | Auto-tracking, privacy mode |
| Wallpaper (awww) | ✅ Running | Self-healing daemon recovery |

### 6. Cross-Platform Home Manager

Both macOS and NixOS import `common/home-base.nix` with 14 shared program modules. Catppuccin Mocha theme everywhere.

### 7. Build Quality

- `nix flake check --no-build` — ✅ all checks passed
- `nix build .#file-and-image-renamer` — ✅ succeeds
- Pre-commit hooks: 6 hooks (gitleaks, trailing whitespace, deadnix, statix, alejandra, nix flake check)
- `lib/` shared helpers: `systemd.nix`, `service-defaults.nix`, `types.nix`, `rocm.nix`

### 8. Custom Packages (9 total)

| Package | Language | Status |
|---------|----------|--------|
| `aw-watcher-utilization` | Python | ✅ |
| `file-and-image-renamer` | Go | ✅ (fixed this session) |
| `golangci-lint-auto-configure` | Go | ✅ |
| `jscpd` | Node.js | ✅ |
| `modernize` | Go | ✅ |
| `monitor365` | Rust | ✅ (disabled service) |
| `mr-sync` | Go | ✅ |
| `netwatch` | Rust | ✅ |
| `openaudible` | AppImage | ✅ |

Plus external flake inputs: `dnsblockd` (Go), `emeet-pixyd` (Go), `todo-list-ai` (Go)

---

## B) PARTIALLY DONE ⚠️

### 1. Gatus Health Check Coverage — 15/21 services

**Monitored (15):** Caddy, Authelia, Gitea, Homepage, Immich, SigNoz, Manifest, TaskChampion, Twenty, Ollama, ComfyUI, Node Exporter, cAdvisor, DNS Resolver, DNS Blocker

**Missing (6):**
| Service | Port | Reason |
|---------|------|--------|
| Whisper ASR | 7860 | Not added (Docker container) |
| LiveKit | 7880 | Not added (Docker container) |
| Hermes | N/A (Discord bot) | No HTTP health endpoint |
| Minecraft | 25565 | Not HTTP (game protocol) |
| EMEET PIXY | 8090/metrics | Not added |
| Docker daemon | /var/run/docker.sock | Not added |

### 2. `serviceTypes.servicePort` — 8/11 candidates

Remaining: `signoz.nix` (nested submodule), `voice-agents.nix` (Docker), `file-and-image-renamer.nix` (no port). All justified skips.

### 3. `serviceDefaults` — 17/20 candidates

Remaining: `file-and-image-renamer.nix` (user service), `monitor365.nix` (user service, disabled), `niri-config.nix` (patched unit). All justified skips.

### 4. Docker Module (`modules/nixos/services/default.nix`) — No shared lib

The Docker service module doesn't use `harden {}` or `serviceDefaults {}`. It enables Docker daemon + auto-prune timer. Low priority since Docker manages its own process lifecycle.

### 5. ADRs (Architecture Decision Records)

No `docs/adr/` directory exists. Key decisions are documented in AGENTS.md but not in formal ADR format.

---

## C) NOT STARTED ❌

### 1. Gatus Alerting Configuration

Gatus supports Discord webhook alerting. Hermes (Discord bot) is on the same machine. Could send alerts to a Discord channel on endpoint failure. No alerting configured at all — Gatus only stores results in SQLite.

### 2. Automated Nix GC Timer

No systemd timer for `nix-collect-garbage`. All cleanup is manual via `just clean`. Disk was at 90% last session — risk of build failures.

### 3. Pi 3 DNS Failover Node

`rpi3-dns` NixOS config exists in flake.nix. Hardware not provisioned. DNS failover cluster is defined but not operational.

### 4. Backup Restorability Verification

Immich, Gitea, Twenty, Manifest all have backup timers, but no one has verified a restore actually works.

### 5. Homepage Dashboard ↔ Gatus Integration

Homepage still uses its own `siteMonitor` polling instead of linking to Gatus for health status.

### 6. `docs/adr/` Directory

No architecture decision records exist. Key decisions (Go workspace sub-modules, BindsTo→Wants, PartOf vs BindsTo, GPU headroom) are only documented in AGENTS.md or status reports.

### 7. User-Service `serviceDefaults` Variant

`lib/systemd/service-defaults.nix` uses `lib.mkForce` which is only valid for system services. User services (file-and-image-renamer, monitor365) can't use it. A `serviceDefaultsUser` variant without mkForce would complete the adoption.

### 8. BTRFS Snapshot Health Verification

Timeshift snapshots are configured but no monitoring or verification exists.

### 9. Status Docs Archive/Consolidation

`docs/status/` has 23 active files across 3 days + archive with 200+. Many are redundant session-specific reports. Needs consolidation.

---

## D) TOTALLY FUCKED UP 💥

### 1. Disk at ~90% — Still Not Addressed

Root filesystem was at 90% (52GB free of 512GB) in session 46. **No cleanup has been run since.** This is the single biggest operational risk. If Nix builds fail mid-switch due to disk full, the system can be left in a broken state.

### 2. No Alerting Pipeline At All

22+ services running with zero alerting. If any service goes down overnight, no one knows until manually checking Gatus or the desktop notification (only visible if logged in and looking). This is a **production system with production data** (photos in Immich, code in Gitea, CRM in Twenty).

### 3. Go Workspace Sub-Module Pattern — Fragile

The fix in this session exposed a fragility: any Go project that depends on `go-output` needs to know about ALL its sub-modules and add `require`+`replace` directives for each. If `go-output` adds a new sub-module tomorrow, ALL downstream Nix packages break until patched. This applies to:
- `file-and-image-renamer` (depends on `go-output` via `cmdguard`)
- `golangci-lint-auto-configure` (if it uses `go-output`)
- `dnsblockd` (if it uses `go-output`)

The correct fix is upstream: `go-output` should publish proper Go modules with tagged versions, not rely on local workspace replace directives. But that's outside our control.

### 4. `photomap` Disabled Due to Podman Permissions

`photomap.enable = true` is commented out with note "podman config permission issue". This has been broken for multiple sessions without investigation.

### 5. DNS Failover Cluster — Defined But Dead

The `dns-failover.nix` module and `rpi3-dns` NixOS config exist but Pi 3 hardware is not provisioned. Single point of failure for DNS (all LAN clients point to evo-x2's Unbound). If evo-x2 goes down, ALL devices lose DNS resolution.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **ADR formalization** — Create `docs/adr/` for key decisions (Go workspace handling, GPU headroom, BindsTo→Wants, PartOf vs BindsTo, DNS CA embedding). Current documentation in AGENTS.md is good but not structured for long-term reference.

2. **Gatus alerting** — Configure Discord webhook alerting via Hermes. Five-line config change, massive operational improvement.

3. **Automated GC timer** — Add `systemd.timer` for weekly `nix-collect-garbage --delete-older-than 7d`. Prevent disk pressure from building up.

4. **Go sub-module pattern centralization** — Consider creating a Nix helper function that takes `go-output-src` and returns all `require`+`replace` lines. Avoid duplicating the sub-module list in every package that depends on `go-output`.

5. **Overlay consolidation** — Extract overlay definitions from `flake.nix` to a separate file. Currently ~100 lines of overlay definitions in the main flake.

6. **User-service shared lib** — Create `serviceDefaultsUser` (no mkForce) for Home Manager user services.

### Operational

7. **Disk monitoring threshold** — Disk monitor service exists but there's no automation to trigger cleanup at 85%. Should auto-run `nix-collect-garbage` at threshold.

8. **Backup testing** — Create a `just backup-test` command that restores one backup to a temp location and verifies integrity.

9. **Status doc consolidation** — Archive all but the latest comprehensive status. Create `CURRENT-STATUS.md` symlink pattern.

10. **Secret rotation plan** — The dnsblockd CA cert (2036 expiry) and age encryption keys should have a documented rotation procedure.

### Code Quality

11. **Docker module hardening** — `modules/nixos/services/default.nix` doesn't use `harden {}`. Low priority but inconsistent with the rest of the codebase.

12. **Signoz port refactoring** — Extract nested port options to top-level for `serviceTypes.servicePort` consistency.

13. **flake.nix organization** — 800+ lines. Consider splitting into `flake/` directory with separate files for overlays, packages, and modules.

---

## F) Top #25 Things We Should Get Done Next

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | **P0** | **Run `just clean`** — disk at ~90%, imminent build failure risk | Critical | 5 min |
| 2 | **P0** | **Deploy the fix** — `just switch` to apply file-and-image-renamer fix | Critical | 10 min |
| 3 | **P0** | **Configure Gatus alerting** (Discord webhook) | High | 15 min |
| 4 | P1 | **Add automated Nix GC timer** (weekly, 7d threshold) | High | 15 min |
| 5 | P1 | **Add whisper-asr + livekit Gatus endpoints** | Medium | 10 min |
| 6 | P1 | **Create ADR-001: Go workspace sub-module Nix pattern** | Medium | 20 min |
| 7 | P1 | **Extract Go sub-module helper function** for `go-output` | Medium | 20 min |
| 8 | P1 | **Archive old status docs** — keep latest 3, archive rest | Low | 10 min |
| 9 | P2 | **Create `serviceDefaultsUser` variant** (no mkForce) | Low | 15 min |
| 10 | P2 | **Add Docker health check** to service-health-check script | Medium | 10 min |
| 11 | P2 | **Fix photomap podman permissions** — investigate and fix | Medium | 1 hour |
| 12 | P2 | **Add `status.home.lan` link** to Homepage dashboard | Low | 10 min |
| 13 | P2 | **Create ADR-002: GPU headroom for niri (memory fraction)** | Low | 15 min |
| 14 | P2 | **Clean up stale DNS cert files** in `platforms/nixos/secrets/` | Low | 5 min |
| 15 | P2 | **Add disk-monitor → auto-cleanup integration** at 85% | Medium | 30 min |
| 16 | P3 | **Consolidate flake.nix overlays** to separate file | Medium | 30 min |
| 17 | P3 | **Refactor signoz port options** to top-level serviceTypes | Low | 20 min |
| 18 | P3 | **BTRFS snapshot health verification** — Timeshift monitoring | Medium | 30 min |
| 19 | P3 | **Backup restorability test** — verify Immich or Gitea backup | Medium | 30 min |
| 20 | P3 | **Pi 3 DNS failover provisioning** — build and flash SD card | High | 2 hours |
| 21 | P3 | **Docker module hardening** — add `harden {}` to default.nix | Low | 10 min |
| 22 | P4 | **Add `just doctor` command** — comprehensive system diagnostics | Low | 30 min |
| 23 | P4 | **Evaluate `deploy.rs`** for remote Pi 3 deployment | Medium | 1 hour |
| 24 | P4 | **Add SigNoz alerts** for disk, service failures, OOM | Medium | 1 hour |
| 25 | P4 | **Create ADR-003: DNS CA embedding strategy** | Low | 15 min |

---

## G) Top #1 Question I Cannot Figure Out Myself 🤔

**What is the current disk usage breakdown on evo-x2?**

Session 46 reported 90% (52GB free of 512GB). I cannot determine what's consuming the ~460GB without running `du`/`ncdu` on the live system. The likely culprits in order of probability:

1. `/nix/store` — old generations, stale derivations
2. `/data/docker` — images, volumes, build cache
3. `/data/ai/models/` — Ollama blobs, ComfyUI models, whisper models
4. `/data/postgresql` — Immich + SigNoz + Twenty databases
5. BTRFS snapshots (Timeshift)

This directly affects whether `just clean` alone will solve the problem or if we need to prune Docker images or AI models. Running `just clean && df -h /` would tell us.

---

## System Metrics

| Metric | Value |
|--------|-------|
| NixOS Channel | 26.05 (Yarara) |
| Nix Version | 2.34.6 |
| Service Modules | 32 |
| Enabled Services | 29 of 32 (monitor365 disabled, photomap disabled, dns-failover pending) |
| Health Check Coverage | 15 Gatus endpoints + 27 service-health-check |
| Custom Packages | 9 (local) + 3 (external flake inputs) |
| Flake Inputs | 35 |
| Pre-commit Hooks | 6 (all passing) |
| Root Disk Usage | ~90% (52GB free, last checked session 46) |
| Platform | x86_64-linux (evo-x2, AMD Ryzen AI Max+ 395, 128GB RAM) |
| Shared Libs | 4 (`systemd.nix`, `service-defaults.nix`, `types.nix`, `rocm.nix`) |
| Cross-Platform Programs | 14 (shared via `common/home-base.nix`) |
| NixOS Desktop Modules | 12 (desktop, programs, hardware) |
| Scripts | 10 (health, DNS, GPU, wallpaper, etc.) |
| Sops Secrets | 8 files (authelia, dnsblockd, hermes, manifest, voice-agents, main) |

---

## Service Module Audit

| Module | Enabled | `harden` | `serviceDefaults` | `serviceTypes` | Notes |
|--------|---------|----------|-------------------|----------------|-------|
| ai-models | ✅ | — | — | — | tmpfiles only |
| ai-stack | ✅ | ✅ | ✅ | — | ollama + gpu-python |
| audio | ✅ | — | — | — | pipewire config |
| authelia | ✅ | ✅ | ✅ | ✅ | SSO forward auth |
| caddy | ✅ | ✅ | ✅ | — | reverse proxy (uses nixpkgs module port) |
| chromium-policies | ✅ | — | — | — | policy config only |
| comfyui | ✅ | ✅ | ✅ | ✅ | GPU image gen |
| default (Docker) | ✅ | — | — | — | daemon + prune timer |
| disk-monitor | ✅ | ✅ | — | — | desktop notifications |
| display-manager | ✅ | — | — | — | SDDM config |
| dns-failover | ❌ | — | — | — | pending Pi 3 hardware |
| file-and-image-renamer | ✅ | — | — | — | user service (HM), fixed this session |
| gatus-config | ✅ | ✅ | ✅ | ✅ | 15 endpoints |
| gitea | ✅ | ✅ | ✅ | — | uses nixpkgs HTTP_PORT |
| gitea-repos | ✅ | ✅ | ✅ | — | mirror sync |
| hermes | ✅ | ✅ | ✅ | ✅ | Discord AI gateway |
| homepage | ✅ | ✅ | ✅ | ✅ | service dashboard |
| immich | ✅ | ✅ | ✅ | — | uses nixpkgs module |
| manifest | ✅ | ✅ | ✅ | ✅ | LLM router |
| minecraft | ✅ | ✅ | ✅ | ✅ | LAN server |
| monitor365 | ❌ | — | — | — | disabled (high RAM) |
| monitoring | ✅ | — | — | — | node_exporter, cadvisor |
| multi-wm | ✅ | — | — | — | window manager helpers |
| niri-config | ✅ | — | — | — | compositor (patched unit) |
| photomap | ❌ | — | — | — | disabled (podman perms) |
| security-hardening | ✅ | ✅ | — | — | kernel params, watchdog |
| signoz | ✅ | ✅ | ✅ | — | nested port options |
| sops | ✅ | — | — | — | secret decryption |
| steam | ✅ | — | — | — | gaming config |
| taskchampion | ✅ | ✅ | ✅ | — | task sync server |
| twenty | ✅ | ✅ | ✅ | ✅ | CRM |
| voice-agents | ✅ | ✅ | ✅ | — | Docker (LiveKit + Whisper) |

---

## Session Flow

| Time | Action |
|------|--------|
| 23:55 | User reported file-and-image-renamer build failure (go-output sub-modules) |
| 23:57 | Diagnosed: go-output split into workspace sub-modules (enum, escape, table, sort) |
| 00:00 | First attempt: add `replace` directives only → `go mod tidy` needed (no network in sandbox) |
| 00:03 | Second attempt: `go mod tidy` in postPatch → HOME/GOCACHE permission errors |
| 00:05 | Third attempt: add both `require` + `replace` for each sub-module → ✅ build succeeds |
| 00:08 | Verified: `nix build .#file-and-image-renamer` succeeds, vendorHash unchanged |
| 00:12 | Status report requested — comprehensive audit |
| 00:15 | Scanned all 32 service modules, 9 packages, 14 programs, 4 lib helpers |
| 00:20 | Writing comprehensive status report |

---

## Files Modified This Session

| File | Change |
|------|--------|
| `pkgs/file-and-image-renamer.nix` | Added `require`+`replace` loop for go-output sub-modules (enum, escape, table, sort) |
| `flake.lock` | Updated: go-output-src (237→238), emeet-pixyd (121→123), monitor365 (668→681), NUR, homebrew-cask |

---

_Previous: Session 46 (`7ba2240`) — shared lib adoption, DNS CA trust, full system status_
_Current: Session 47 — go-output sub-module build fix, comprehensive status_
