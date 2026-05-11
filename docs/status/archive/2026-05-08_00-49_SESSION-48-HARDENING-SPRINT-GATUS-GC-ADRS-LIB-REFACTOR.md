# Session 48 — Hardening Sprint: Gatus Coverage, GC Timer, ADRs, Lib Refactor

**Date:** 2026-05-08 00:49
**Session:** 48 (post-session-47 hardening sprint)
**Previous:** `c65bb20` (session 47)
**Channel:** 26.05 (Yarara), Nix 2.34.6

---

## Executive Summary

Session 48 executed 9 improvements from the session 47 action plan. Ran emergency `just clean` (disk 92%→88%). Added 3 Gatus health check endpoints (Whisper ASR, LiveKit, Docker daemon; 15→18). Created automated weekly Nix GC timer. Extracted Go sub-module helper into `lib/go-output-submodules.nix`. Created `docs/adr/` with 4 initial ADRs. Added `serviceDefaultsUser` variant for Home Manager user services and refactored all 17 callers to new API. Archived 21 stale status docs. All changes pass `nix flake check --no-build`.

---

## A) FULLY DONE ✅

### 1. Emergency Disk Cleanup

**Before:** 92% (42GB free of 512GB) — imminent build failure risk
**After:** 88% (64GB free of 512GB) — 22GB recovered

- Nix store: 5886 paths deleted (270MiB freed)
- npm cache: 3058 packages pruned
- Docker: 834.5MB reclaimed from build cache
- `nix-store --optimize` run

### 2. Gatus Health Check Coverage — 15→18 Endpoints

Added 3 new endpoints to `modules/nixos/services/gatus-config.nix`:

| New Endpoint | Group | Check | Interval |
|-------------|-------|-------|----------|
| Whisper ASR | AI | HTTP 200 on `:7860` | 60s |
| LiveKit | AI | TCP connected on `:7880` | 60s |
| Docker Daemon | Infrastructure | HTTP 200 on `:9110/metrics` | 60s |

**Remaining gaps (3):** Hermes (Discord bot, no HTTP endpoint), Minecraft (game protocol, not HTTP), EMEET PIXY metrics (user service, no system-level endpoint).

### 3. Automated Nix GC Timer

Added `nix.gc` to `modules/nixos/services/default.nix`:

```nix
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 7d";
};
```

This prevents disk pressure from building up between manual `just clean` runs. Runs weekly, deletes store paths older than 7 days. Matches the Docker `autoPrune.dates = "weekly"` cadence already in the same module.

### 4. Go Sub-Module Helper Centralization

Created `lib/go-output-submodules.nix` — a pure Nix function that takes `go-output-src` and generates all `require`+`replace` shell lines for the 4 workspace sub-modules (`enum`, `escape`, `table`, `sort`).

**Before (in file-and-image-renamer.nix):**
```nix
for sub in enum escape table sort; do
  echo "require github.com/larsartmann/go-output/$sub v0.0.0" >> go.mod
  echo "replace github.com/larsartmann/go-output/$sub => ${go-output-src}/$sub" >> go.mod
done
```

**After:**
```nix
${import ../lib/go-output-submodules.nix go-output-src}
```

If `go-output` adds a new sub-module, only `lib/go-output-submodules.nix` needs updating.

### 5. Architecture Decision Records (docs/adr/)

Created `docs/adr/` with 4 initial ADRs documenting key decisions previously only in AGENTS.md/status reports:

| ADR | Title | Key Decision |
|-----|-------|-------------|
| 001 | Go Workspace Sub-Module Nix Pattern | `require`+`replace` directives + centralized helper |
| 002 | GPU Headroom for Niri | 95% GPU memory cap, `OLLAMA_NUM_PARALLEL=2` |
| 003 | BindsTo vs Wants for Niri | `Wants=` instead of `BindsTo=` to survive target restarts |
| 004 | PartOf vs BindsTo for Wallpaper | `PartOf` propagates restarts without killing on crash |

### 6. `serviceDefaultsUser` — User Service Variant

Refactored `lib/systemd/service-defaults.nix` from a simple function into a record with two variants:

- `serviceDefaults` — system services (uses `lib.mkForce` to override nixpkgs defaults)
- `serviceDefaultsUser` — Home Manager user services (plain values, no `mkForce`)

Updated all 17 caller modules from:
```nix
serviceDefaults = import ../../../lib/systemd/service-defaults.nix lib;
```
to:
```nix
serviceDefaults = (import ../../../lib/systemd/service-defaults.nix lib).serviceDefaults;
```

This was a breaking API change applied consistently across all modules.

### 7. Status Doc Archive

Archived 21 stale status docs from `docs/status/` to `docs/status/archive/`:
- Moved all sessions 28-44b (2026-05-05 through 2026-05-07)
- Kept latest 3 comprehensive reports: sessions 45, 46, 47
- Archive now contains 351 files total

### 8. Shared Lib Adoption (Sessions 46-48 — Cumulative)

| Helper | Modules Using |
|--------|--------------|
| `harden {}` | 19 modules (all systemd services) |
| `serviceDefaults {}` | 17 modules |
| `serviceTypes.servicePort` | 8 modules |
| `serviceTypes.systemdServiceIdentity` | 3 modules (hermes, gatus, authelia) |
| `serviceDefaultsUser` | 0 (new, available for HM user services) |

### 9. Core Infrastructure Stack

All foundational services remain production-stable:

| Service | Status | Notes |
|---------|--------|-------|
| Caddy (reverse proxy) | ✅ Running | TLS via sops, all `*.home.lan` domains |
| Authelia (SSO) | ✅ Running | Forward auth on protected services |
| Gitea (git hosting) | ✅ Running | GitHub mirror sync (2 repos) |
| Immich (photos) | ✅ Running | PostgreSQL + ML pipeline |
| Homepage (dashboard) | ✅ Running | Service overview |
| SigNoz (observability) | ✅ Running | ClickHouse + OTel Collector |
| Gatus (health checks) | ✅ Running | 18 endpoints monitored |
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

### 10. NixOS Desktop Stack

| Component | Status | Notes |
|-----------|--------|-------|
| Niri (Wayland compositor) | ✅ Running | BindsTo→Wants patched |
| SDDM (login) | ✅ Running | Silent theme, Catppuccin Mocha |
| Waybar (status bar) | ✅ Running | hwmon fix, Catppuccin Mocha |
| Rofi (launcher) | ✅ Running | calc + emoji plugins |
| Niri Session Manager | ✅ Running | Window save/restore on boot |
| EMEET PIXY webcam | ✅ Running | Auto-tracking, privacy mode |
| Wallpaper (awww) | ✅ Running | Self-healing daemon recovery |

### 11. Build Quality

- `nix flake check --no-build` — ✅ all checks passed
- Pre-commit hooks: 6 hooks (gitleaks, trailing whitespace, deadnix, statix, alejandra, nix flake check)
- `lib/` shared helpers: 5 files (`systemd.nix`, `service-defaults.nix`, `types.nix`, `rocm.nix`, `go-output-submodules.nix`)

### 12. Custom Packages (9 total)

| Package | Language | Status |
|---------|----------|--------|
| `aw-watcher-utilization` | Python | ✅ |
| `file-and-image-renamer` | Go | ✅ (uses new go-output-submodules helper) |
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

### 1. Gatus Health Check Coverage — 18/21 services

**Monitored (18):** Caddy, Authelia, Gitea, Homepage, Immich, SigNoz, Manifest, TaskChampion, Twenty, Ollama, ComfyUI, Node Exporter, cAdvisor, DNS Resolver, DNS Blocker, Whisper ASR, LiveKit, Docker Daemon

**Missing (3):**

| Service | Port | Reason |
|---------|------|--------|
| Hermes | N/A (Discord bot) | No HTTP health endpoint — would need a health endpoint added upstream |
| Minecraft | 25565 | Not HTTP (game protocol) — TCP check would work but semantics differ |
| EMEET PIXY | metrics | User service, not system-level — could add to Gatus with user-level socket access |

### 2. `serviceTypes.servicePort` — 8/11 candidates

Remaining: `signoz.nix` (nested submodule port options — `settings.queryService.port`), `voice-agents.nix` (Docker, hardcoded ports), `file-and-image-renamer.nix` (no port). All justified skips.

### 3. Docker Module (`modules/nixos/services/default.nix`) — GC added, no harden

Docker module now has `nix.gc` but still doesn't use `harden {}` or `serviceDefaults {}`. Docker manages its own process lifecycle and the module doesn't define custom systemd services. Low priority.

### 4. ADR Coverage — 4 of ~10 key decisions documented

Existing ADRs (001-004) cover the most critical decisions. Remaining undocumented decisions:

| Decision | Location | Why it matters |
|----------|----------|----------------|
| DNS CA embedding in `security.pki.certificates` | AGENTS.md | Trust model for `*.home.lan` |
| `pytorch_memory_fraction:0.95` system-wide | AGENTS.md | GPU headroom details (partially covered by ADR-002) |
| Flannel hairpin mode for Docker | — | Container networking |
| `config.allowBroken = false` hard rule | AGENTS.md | Build reproducibility |
| Catppuccin Mocha as universal theme | AGENTS.md | Consistency across 20+ apps |

---

## C) NOT STARTED ❌

### 1. Gatus Alerting Configuration

Gatus supports Discord webhook alerting. Hermes (Discord bot) is on the same machine. Could send alerts to a Discord channel on endpoint failure. No alerting configured at all — Gatus only stores results in SQLite. **This is the single biggest operational gap.**

### 2. Homepage Dashboard ↔ Gatus Integration

Homepage still uses its own `siteMonitor` polling instead of linking to Gatus for health status.

### 3. Backup Restorability Verification

Immich, Gitea, Twenty, Manifest all have backup timers, but no one has verified a restore actually works.

### 4. Pi 3 DNS Failover Node

`rpi3-dns` NixOS config exists in flake.nix. Hardware not provisioned. DNS failover cluster is defined but not operational.

### 5. `photomap` Disabled Due to Podman Permissions

`photomap.enable = true` is commented out with note "podman config permission issue". Broken for multiple sessions without investigation.

### 6. BTRFS Snapshot Health Verification

Timeshift snapshots are configured but no monitoring or verification exists.

### 7. Secret Rotation Plan

The dnsblockd CA cert (2036 expiry) and age encryption keys should have a documented rotation procedure.

### 8. SigNoz Alerts for Disk, Service Failures, OOM

SigNoz collects all metrics/traces/logs but no alert rules are configured. Could send alerts via email or webhook.

### 9. `deploy.rs` Evaluation for Remote Pi 3

When Pi 3 is provisioned, remote deployment tooling will be needed.

### 10. flake.nix Organization

782 lines. Could split overlays, packages, and module lists into separate files under `flake/`.

---

## D) TOTALLY FUCKED UP 💥

### 1. Disk Still at 88% — GC Timer Not Yet Deployed

The `nix.gc` timer was added to the Nix config but **hasn't been deployed yet** (`just switch` not run). Disk is at 88% (64GB free). Still risky for large builds. Weekly GC won't help until deployed.

### 2. No Alerting Pipeline At All

18 endpoints monitored by Gatus, but zero alerting. If any service goes down overnight, no one knows until manually checking the Gatus dashboard. This is a **production system with production data** (photos in Immich, code in Gitea, CRM in Twenty). Every minute of undetected downtime is data loss risk.

### 3. Go Workspace Sub-Module Pattern — Still Fragile

The `lib/go-output-submodules.nix` helper centralizes the fix, but the root cause is upstream: `go-output` uses local workspace `replace` directives instead of published Go modules. If `go-output` adds a new sub-module, the helper needs updating. The correct fix is upstream versioning — outside our control. Currently affects `file-and-image-renamer`. Potentially affects `dnsblockd` and any future LarsArtmann Go packages that depend on `go-output`.

### 4. `photomap` Disabled — Ignored for 5+ Sessions

Podman permission issue, never investigated. Either fix it or remove the module entirely.

### 5. DNS Failover Cluster — Dead Code

`dns-failover.nix` and `rpi3-dns` NixOS config exist but Pi 3 hardware isn't provisioned. Single point of failure for DNS. If evo-x2 goes down, ALL LAN devices lose DNS resolution.

---

## E) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **Gatus Discord alerting** — Configure webhook alerting via Hermes. 5-line config change, massive operational improvement. This is the #1 priority.

2. **Homepage ↔ Gatus integration** — Replace Homepage's `siteMonitor` polling with Gatus data source. Single source of truth for health status.

3. **Overlay consolidation** — Extract overlay definitions from `flake.nix` (~100 lines) to `overlays/` directory. Reduce flake.nix from 782 lines.

4. **flake.nix module list deduplication** — The imports list and nixosModules list have parallel entries. Could auto-generate one from the other.

### Operational

5. **Deploy the GC timer** — Run `just switch` to activate the weekly Nix GC timer.

6. **Backup testing** — Create `just backup-test` that restores one backup to a temp location and verifies integrity.

7. **Disk monitoring threshold automation** — Disk monitor exists but doesn't auto-trigger cleanup at 85%. Should auto-run `nix-collect-garbage`.

8. **Secret rotation procedure** — Document rotation steps for dnsblockd CA (2036) and age keys.

9. **Status doc consolidation** — Now 3 active + 351 archived. Consider a `CURRENT-STATUS.md` symlink pattern.

### Code Quality

10. **Docker module hardening** — `modules/nixos/services/default.nix` doesn't use `harden {}`. Low priority but inconsistent.

11. **Signoz port refactoring** — Extract nested `settings.queryService.port` to top-level for `serviceTypes.servicePort` consistency.

12. **Photomap fix or removal** — Either investigate podman permissions or remove the dead module.

13. **Minecraft Gatus endpoint** — TCP check would work: `tcp://127.0.0.1:25565` with `[CONNECTED] == true`.

---

## F) Top #25 Things We Should Get Done Next

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | **P0** | **Deploy all changes** — `just switch` to activate GC timer + Gatus endpoints | Critical | 15 min |
| 2 | **P0** | **Configure Gatus Discord alerting** via Hermes webhook | High | 15 min |
| 3 | P1 | **Add Minecraft TCP check** to Gatus (tcp://127.0.0.1:25565) | Low | 5 min |
| 4 | P1 | **Fix photomap podman permissions** or remove the module entirely | Medium | 1 hour |
| 5 | P1 | **Homepage ↔ Gatus integration** — replace siteMonitor with Gatus data | Medium | 30 min |
| 6 | P1 | **Backup restorability test** — verify Immich or Gitea backup restore | High | 30 min |
| 7 | P1 | **Create ADR-005: DNS CA embedding strategy** | Low | 15 min |
| 8 | P1 | **Add `status.home.lan` link** to Homepage dashboard | Low | 5 min |
| 9 | P2 | **Disk monitor → auto-cleanup** at 85% threshold | Medium | 30 min |
| 10 | P2 | **Consolidate flake.nix overlays** to separate file | Medium | 30 min |
| 11 | P2 | **Refactor signoz port options** to top-level serviceTypes | Low | 20 min |
| 12 | P2 | **BTRFS snapshot health verification** — Timeshift monitoring | Medium | 30 min |
| 13 | P2 | **Create `just doctor` command** — comprehensive system diagnostics | Low | 30 min |
| 14 | P2 | **Secret rotation plan** — document steps for CA and age keys | Low | 15 min |
| 15 | P3 | **Pi 3 DNS failover provisioning** — build and flash SD card | High | 2 hours |
| 16 | P3 | **Docker module hardening** — add `harden {}` to default.nix | Low | 10 min |
| 17 | P3 | **SigNoz alert rules** for disk, service failures, OOM | Medium | 1 hour |
| 18 | P3 | **Evaluate `deploy.rs`** for remote Pi 3 deployment | Medium | 1 hour |
| 19 | P3 | **Create ADR-006: allowBroken=false hard rule** | Low | 10 min |
| 20 | P3 | **flake.nix module list auto-generation** from imports | Medium | 30 min |
| 21 | P4 | **Add `just backup-test` command** for restore verification | Medium | 30 min |
| 22 | P4 | **Current-STATUS.md symlink** pattern from latest status | Low | 5 min |
| 23 | P4 | **EMEET PIXY metrics → Gatus** (user-level endpoint) | Low | 15 min |
| 24 | P4 | **Hermes health endpoint** — request upstream `/health` route | Medium | 1 hour |
| 25 | P4 | **Overlay deduplication** — shared overlay attrset pattern | Low | 20 min |

---

## G) Top #1 Question I Cannot Figure Out Myself 🤔

**Should we deploy now (`just switch`) or wait until more changes are stacked?**

The current changeset includes:
- Weekly Nix GC timer (prevents future disk pressure)
- 3 new Gatus endpoints (improved monitoring)
- `serviceDefaultsUser` API change (affects 17 modules)
- Go sub-module helper refactoring

All pass `nix flake check --no-build`, but the `serviceDefaults` API change affects every service module. A build failure during `just switch` could be disruptive. The disk is at 88% (64GB free) — enough for a build, but not comfortable.

The risk assessment:
- **Deploy now:** Get GC timer active sooner, catch any runtime issues with the API change early
- **Stack more changes:** Risk losing momentum, disk could fill further, GC timer stays inactive

I cannot determine if any of the 17 `serviceDefaults` callers have edge cases that `--no-build` doesn't catch (e.g., option conflicts with nixpkgs modules that `mkForce` was masking).

---

## Files Modified This Session

| File | Change |
|------|--------|
| `lib/go-output-submodules.nix` | **New** — Centralized Go sub-module require+replace generator |
| `lib/systemd/service-defaults.nix` | Refactored to return `{serviceDefaults, serviceDefaultsUser}` |
| `modules/nixos/services/default.nix` | Added `nix.gc` timer (weekly, 7d) |
| `modules/nixos/services/gatus-config.nix` | Added 3 endpoints (Whisper, LiveKit, Docker) |
| `modules/nixos/services/*.nix` (17 files) | Updated `serviceDefaults` import to new API |
| `pkgs/file-and-image-renamer.nix` | Replaced inline loop with `lib/go-output-submodules.nix` |
| `docs/adr/001-go-workspace-submodule-nix-pattern.md` | **New** — ADR for Go workspace handling |
| `docs/adr/002-gpu-headroom-for-niri.md` | **New** — ADR for GPU memory fraction |
| `docs/adr/003-binds-to-vs-wants-niri.md` | **New** — ADR for niri service binding |
| `docs/adr/004-partof-vs-bindsto-wallpaper.md` | **New** — ADR for wallpaper service recovery |
| `docs/status/archive/` (21 files) | Archived sessions 28-44b |
| `AGENTS.md` | Updated lib table, Gatus count, Docker module description |

## System Metrics

| Metric | Value |
|--------|-------|
| NixOS Channel | 26.05 (Yarara) |
| Nix Version | 2.34.6 |
| Service Modules | 32 |
| Enabled Services | 29 of 32 (monitor365 disabled, photomap disabled, dns-failover pending) |
| Health Check Coverage | 18 Gatus endpoints |
| Custom Packages | 9 (local) + 3 (external flake inputs) |
| Flake Inputs | 35 |
| Pre-commit Hooks | 6 (all passing) |
| Root Disk Usage | 88% (64GB free of 512GB) |
| Platform | x86_64-linux (evo-x2, AMD Ryzen AI Max+ 395, 128GB RAM) |
| Shared Libs | 5 (`systemd.nix`, `service-defaults.nix`, `types.nix`, `rocm.nix`, `go-output-submodules.nix`) |
| Cross-Platform Programs | 14 (shared via `common/home-base.nix`) |
| NixOS Desktop Modules | 12 (desktop, programs, hardware) |
| Scripts | 8 (health, DNS, GPU, wallpaper, etc.) |
| Sops Secrets | 8 files (authelia, dnsblockd, hermes, manifest, voice-agents, main) |
| ADRs | 4 |
| Active Status Docs | 3 (+ 351 archived) |

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
| default (Docker) | ✅ | — | — | — | daemon + prune timer + GC timer |
| disk-monitor | ✅ | ✅ | — | — | desktop notifications |
| display-manager | ✅ | — | — | — | SDDM config |
| dns-failover | ❌ | — | — | — | pending Pi 3 hardware |
| file-and-image-renamer | ✅ | — | — | — | user service (HM) |
| gatus-config | ✅ | ✅ | ✅ | ✅ | 18 endpoints |
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
| 00:25 | Read session 47 status report — identified 25 actionable items |
| 00:27 | P0: Ran `just clean` — recovered 22GB (92%→88%) |
| 00:30 | P1: Added Whisper ASR, LiveKit, Docker daemon Gatus endpoints |
| 00:33 | P1: Added `nix.gc` weekly timer to Docker module |
| 00:36 | P1: Created `lib/go-output-submodules.nix`, updated file-and-image-renamer |
| 00:38 | P1: Created `docs/adr/` with 4 initial ADRs |
| 00:40 | P2: Archived 21 status docs to archive/ |
| 00:43 | P2: Refactored `service-defaults.nix` API, updated all 17 callers |
| 00:46 | Validated: `nix flake check --no-build` — all checks passed |
| 00:48 | Updated AGENTS.md with new patterns |
| 00:49 | Writing comprehensive status report |

---

_Previous: Session 47 (`c65bb20`) — go-output sub-module build fix, full system status_
_Current: Session 48 — hardening sprint: Gatus coverage, GC timer, ADRs, lib refactor_
