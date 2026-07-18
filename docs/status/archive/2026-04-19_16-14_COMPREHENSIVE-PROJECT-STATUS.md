# SystemNix Comprehensive Status Report

**Date:** 2026-04-19 16:14
**Branch:** master
**Commits (total):** 1,669
**Commits (April 2026):** 332
**Nix files:** 87
**Go files:** 15
**Just recipes:** 156
**Status reports:** 128 (3.4 MB, 95 archived)

---

## A) FULLY DONE ✅

### 1. EMEET PIXY Webcam Daemon (`pkgs/emeet-pixyd/`)

- Full Go daemon with HID control, V4L2 camera management, call detection
- Web UI with htmx 2.0.8, live MJPEG preview, PTZ sliders, status panel
- Auto face-tracking, noise cancellation on call start; privacy mode on call end
- Hotplug recovery via uevent netlink, context propagation, PTZ caching
- Systemd watchdog, structured slog logging, socket permissions (0600)
- Bidirectional HID state querying (sync command), type-safe CameraState/AudioMode
- NixOS module with udev rules, Waybar indicator with click/right-click/middle-click
- Integration tests, comprehensive unit tests, golangci-lint config
- **Status: Production-ready, actively deployed on evo-x2**

### 2. Niri Session Save/Restore (`platforms/nixos/programs/niri-wrapped.nix`)

- Periodic save (60s timer): windows.json, workspaces.json, kitty-state.json
- Startup restore: re-spawns apps on correct workspaces with column widths, floating state, focus order
- Fallback: hardcoded default apps if session >7 days old
- JSON validation, deduplication via pgrep, critical failure notifications
- `just session-status` / `just session-restore` commands
- **Status: Complete, round-2 crash recovery improvements landed**

### 3. Voice Agents Module (`modules/nixos/services/voice-agents.nix`)

- LiveKit migrated from Docker Compose to native NixOS module
- SOPS secrets integration, GPU device access for Whisper
- Network dependency ordering, decoupled image pulls from startup
- **Status: Deployed and operational**

### 4. DNS Blocker Stack

- Unbound resolver + dnsblockd (Go block page server) + dnsblockd-processor
- 25 blocklists, 2.5M+ domains blocked, Quad9 DoT + Cloudflare fallback
- Local `.home.lan` DNS records for all services
- Runtime IP detection, path traversal protection, path-secured file operations
- **Status: Fully operational, hardened**

### 5. Taskwarrior Cross-Platform Sync

- TaskChampion sync server on NixOS (behind Caddy at `tasks.home.lan`)
- Zero-config: deterministic client IDs from SHA-256, shared encryption secret
- macOS + NixOS + Android (TaskStrider) all sync seamlessly
- Catppuccin Mocha themed reports, `+agent` tracking protocol
- **Status: Fully operational across all devices**

### 6. Twenty CRM (`modules/nixos/services/twenty.nix`)

- Self-hosted CRM with Docker Compose deployment
- SOPS secrets, tmpfiles state directories, proper env-file handling
- **Status: Deployed and operational**

### 7. flake.nix Infrastructure

- flake-parts modular architecture, 20+ inputs
- Custom Go overlay (1.26.1), dnsblockd overlay, aw-watcher overlay
- flake apps for deploy, validate, dns-diagnostics
- flake checks, treefmt with alejandra
- Cross-platform: nix-darwin (aarch64) + NixOS (x86_64)
- **Status: Solid foundation, 80% shared config via `platforms/common/`**

### 8. Cross-Platform Home Manager

- 15 shared program modules (fish, zsh, bash, nushell, starship, git, tmux, fzf, taskwarrior, etc.)
- Catppuccin Mocha theme everywhere
- SSH config via `nix-ssh-config` flake input
- Crush AI config synced via flake input
- **Status: Both platforms fully managed**

### 9. NixOS Desktop (evo-x2)

- Niri Wayland compositor with wrapped config (Vimjoyer pattern)
- Waybar, SDDM (SilentSDDM theme), Rofi, swaylock, wlogout
- AMD GPU (Strix Halo) + NPU drivers, ROCm for AI workloads
- Steam/GameMode/MangoHud gaming stack, CS2 crash fix
- Audio (PipeWire), Bluetooth, ZRAM, BTRFS snapshots
- Security hardening: fail2ban, firewall, Authelia SSO
- **Status: Daily driver, stable**

### 10. Crush-Config Private Repo Access (THIS SESSION)

- Fixed `nix flake update` 404 error for private `crush-config` repo
- Changed `github:LarsArtmann/crush-config` → `git+ssh://git@github.com/LarsArtmann/crush-config?ref=master`
- Full flake update completed successfully (8 inputs updated)
- **Status: Fixed and committed**

---

## B) PARTIALLY DONE 🔧

### 1. Authelia SSO

- Config deployed with OIDC for Immich, Grafana
- Known issues: SOPS dependency ordering during rebuild, session config fragility
- **Missing:** Full SSO coverage across all services, automated testing of auth flows

### 2. SigNoz Observability

- Built from source (Go 1.25), integrated with Caddy + Homepage
- ClickHouse cluster name issues fixed, keeper config cleaned up
- **Missing:** Custom dashboards, alert rules, log pipeline tuning

### 3. Immich Photo Management

- Deployed with OIDC SSO, Bull Board UI patch available
- TLS working via Caddy
- **Missing:** OAuth 500 error sporadic, AI model optimization incomplete

### 4. Gitea + GitHub Mirror

- Running with HTTPS, Actions CI/CD runner enabled
- Repo sync script (`just gitea-sync-repos`)
- **Missing:** Automated scheduled sync, backup verification

### 5. Monitoring Stack

- Prometheus removed (port conflict incident), Grafana exists
- Waybar monitoring, SigNoz for traces/metrics/logs
- **Missing:** Unified dashboard, proper alerting pipeline, Prometheus replacement decision

### 6. Homepage Dashboard

- Service cards configured for all services
- **Missing:** Dynamic health checks, auto-discovery of new services

### 7. AI Stack

- Ollama on ROCm, Unsloth Studio, llama.cpp
- Data partition migration complete (/data/models/ollama)
- **Missing:** Multi-agent orchestration, GPU utilization monitoring, model auto-management

---

## C) NOT STARTED ⏳

1. **NixOS tests** (`nixosTests`) for custom modules
2. **Automated CI/CD pipeline** (Dagger removed, nothing replaced it)
3. **Cross-platform backup strategy** (justfile recipes exist but no automated schedule)
4. **macOS-specific improvements** (launchagents, ActivityWatch integration lagging)
5. **Documentation cleanup** — 128 status reports (3.4 MB), many stale/redundant
6. **Secrets rotation automation** — manual sops process
7. **Disaster recovery runbook** — no tested DR procedure documented
8. **Network monitoring/alerting** — no uptime monitoring for services
9. **Log aggregation** — SigNoz deployed but not ingesting all service logs
10. **Auto-upgrade system** — no automated nixos-rebuild/darwin-rebuild scheduling

---

## D) TOTALLY FUCKED UP 💥

### 1. Status Report Bloat

- **128 status reports** totaling 3.4 MB in `docs/status/`
- 95 archived, but ~33 active reports still in the directory
- Naming convention inconsistency (SCREAMING_SNAKE vs snake_case, mixed date formats)
- Many are session-specific AI agent dumps, not actionable documents
- **Impact:** Makes it hard to find actual documentation; pollutes git history

### 2. Documentation Sprawl

- `docs/` has 80+ top-level items: guides, reports, plans, proposals, complaints
- Multiple overlapping "comprehensive status reports" from different sessions
- Stale proposals and plans that were either completed or abandoned
- No clear doc taxonomy or index

### 3. Crush-Config Was Broken for Unknown Duration

- The `crush-config` input used `github:` fetcher which fails on private repos
- This means `nix flake update` has been broken since the repo went private
- **Unknown:** When did it go private? How many update attempts failed silently?

---

## E) WHAT WE SHOULD IMPROVE 📈

### High Priority

1. **Archive/cull status reports** — move all but last 5 to `archive/`, delete truly obsolete ones
2. **Consolidate docs/ structure** — create clear taxonomy (guides/, architecture/, operations/, archive/)
3. **Add NixOS module tests** — at minimum for dnsblockd, emeet-pixyd, voice-agents
4. **Replace CI/CD** — Dagger removed but nothing fills the gap; Gitea Actions runner exists
5. **Secrets rotation schedule** — document and automate sops key rotation

### Medium Priority

6. **Monitoring unification** — decide: Prometheus replacement or lean into SigNoz for everything
7. **Service health checks** — automated verification after `just switch`
8. **Stale input cleanup** — review 20+ flake inputs, remove unused ones
9. **Cross-platform parity audit** — macOS config has fallen behind NixOS
10. **Automated flake updates** — weekly auto-update + test pipeline

### Low Priority

11. **Consistent code comments** — many modules lack doc comments
12. **Justfile organization** — 156 recipes is unwieldy; group into categories
13. **Git history hygiene** — many "comprehensive status" commits; could benefit from squash merges
14. **README accuracy** — ensure README reflects actual current state
15. **AGENTS.md updates** — keep in sync with architectural changes

---

## F) TOP 25 THINGS TO DO NEXT

| #   | Task                                                                        | Impact | Effort |
| --- | --------------------------------------------------------------------------- | ------ | ------ |
| 1   | Archive/cull 100+ status reports to last 5 + README index                   | High   | Low    |
| 2   | Consolidate docs/ into clear taxonomy (guides/, architecture/, operations/) | High   | Medium |
| 3   | Add `nixosTests` for dnsblockd + emeet-pixyd modules                        | High   | Medium |
| 4   | Set up Gitea Actions CI pipeline (runner exists, no pipelines)              | High   | Medium |
| 5   | Automated `nix flake update` + `just test-fast` weekly schedule             | High   | Low    |
| 6   | Post-switch health check script (verify all services running)               | High   | Low    |
| 7   | Secrets rotation runbook + automation                                       | High   | Medium |
| 8   | Disaster recovery test (rollback + restore on evo-x2)                       | High   | Medium |
| 9   | SigNoz log ingestion for all systemd services                               | Medium | Medium |
| 10  | Unified monitoring dashboard (SigNoz OR Prometheus, pick one)               | Medium | High   |
| 11  | Network uptime monitoring (external health checks for services)             | Medium | Low    |
| 12  | macOS config parity audit (launchagents, ActivityWatch, packages)           | Medium | Medium |
| 13  | Immich OAuth stability fix (sporadic 500 errors)                            | Medium | Medium |
| 14  | Gitea automated scheduled sync with GitHub                                  | Medium | Low    |
| 15  | Authelia SSO coverage for remaining services                                | Medium | Medium |
| 16  | Clean up stale flake inputs (review all 20+)                                | Medium | Low    |
| 17  | Ollama model auto-management (cleanup old models, GPU monitoring)           | Medium | Medium |
| 18  | Justfile reorganization (group 156 recipes into logical categories)         | Low    | Low    |
| 19  | AGENTS.md auto-sync with actual codebase state                              | Low    | Medium |
| 20  | Homepage dynamic health checks for all services                             | Low    | Low    |
| 21  | BTRFS snapshot verification + automated cleanup                             | Low    | Low    |
| 22  | ROCm/NPU driver version tracking + update automation                        | Low    | Medium |
| 23  | Photomap service status — is it actively used? Evaluate keep/retire         | Low    | Low    |
| 24  | Voice agents module — document architecture, add to Homepage                | Low    | Low    |
| 25  | Create ADR template + start recording architectural decisions               | Low    | Low    |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**When did the `crush-config` GitHub repo become private, and was `nix flake update` broken before today's fix for days, weeks, or months?**

The `github:` fetcher in the original flake.nix would have failed immediately once the repo visibility changed to private. This means either:

- Someone has been unable to update flakes for an extended period, OR
- The repo was made private very recently (but the 404 suggests it's been private for at least some time)

Checking `git log` for the crush-config input in `flake.lock` could reveal the last successful update timestamp, which would answer this. But I cannot determine the **intent** — was this always meant to be private? Should it stay private?

---

## Current Flake Input Status (Post-Update)

| Input                 | Status         | Last Updated |
| --------------------- | -------------- | ------------ |
| nixpkgs               | ✅ Updated     | 2026-04-16   |
| home-manager          | ✅ Updated     | 2026-04-19   |
| niri                  | ✅ Updated     | 2026-04-19   |
| nixpkgs-stable (niri) | ✅ Updated     | 2026-04-17   |
| niri-unstable         | ✅ Updated     | 2026-04-19   |
| crush-config          | ✅ Fixed (SSH) | 2026-04-19   |
| helium                | ✅ Updated     | 2026-04-18   |
| homebrew-cask         | ✅ Updated     | 2026-04-19   |
| nur                   | ✅ Updated     | 2026-04-19   |
| nix-darwin            | ✅ Current     | 2026-04-14   |
| sops-nix              | ✅ Current     | 2026-04-14   |
| flake-parts           | ✅ Current     | —            |
| All others            | ✅ Current     | —            |

---

## Project Metrics

| Metric                       | Value     |
| ---------------------------- | --------- |
| Total commits                | 1,669     |
| April 2026 commits           | 332       |
| Nix files                    | 87        |
| Go files                     | 15        |
| NixOS service modules        | 15        |
| Custom packages              | 10        |
| Home Manager program modules | 15        |
| Just recipes                 | 156       |
| Flake inputs                 | 20+       |
| Status reports (active)      | 33        |
| Status reports (archived)    | 95        |
| Working tree                 | **CLEAN** |
