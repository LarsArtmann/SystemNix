# Session 49 — Hermes Stability Fix, Full System Audit

**Date:** 2026-05-08 02:04 CEST
**Branch:** master (2 commits ahead of origin)
**Nixpkgs:** 26.05.20260423.01fbdee (Yarara)
**Platform:** NixOS x86_64-linux (evo-x2) + macOS aarch64-darwin (Lars-MacBook-Air)

---

## Executive Summary

System is **functional but degraded**. Hermes Agent is the primary pain point — 146 error events in 7 days from three root causes (dead API key, permission drift, SQLite corruption on BTRFS). The `service-health-check` timer has been failing every 15 minutes for weeks due to wrong service names (fix exists but not deployed). Disk usage is elevated (90% root, 83% /data). Everything else is stable.

**This session**: Fixed Hermes permissions + SQLite corruption prevention. MiniMax API key renewal is user-actionable only.

---

## a) FULLY DONE ✅

### Infrastructure & Core

| Item | Status | Details |
|------|--------|---------|
| **Flake architecture** | ✅ Complete | 35 inputs, flake-parts with 31 service modules, 3 machine configs |
| **Cross-platform Home Manager** | ✅ Complete | `common/home-base.nix` → 14 program modules, shared by both platforms |
| **NixOS services (17 active)** | ✅ Complete | Caddy, Gitea, Immich, SigNoz, Ollama, ComfyUI, Gatus, Homepage, Authelia, TaskChampion, Hermes, Manifest, Twenty, Whisper ASR, Minecraft, DNS blocker, Docker |
| **Shared lib helpers** | ✅ Complete | `harden{}`, `serviceDefaults{}`, `serviceDefaultsUser{}`, `serviceTypes`, `rocm`, `go-output-submodules` — all adopted across modules |
| **DNS blocking stack** | ✅ Complete | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream |
| **SigNoz observability** | ✅ Complete | node_exporter, cAdvisor, journald, OTLP, ClickHouse — full pipeline |
| **Gatus health monitoring** | ✅ Complete | 18 endpoints, SQLite storage, Caddy virtual host, systemd hardening |
| **Sops-nix secrets** | ✅ Complete | age-encrypted, hermes, caddy, authelia, dnsblockd secrets all wired |
| **Caddy reverse proxy** | ✅ Complete | TLS via sops, all ports derived from service options (no hardcoding) |
| **AI model storage** | ✅ Complete | Centralized `/data/ai/`, Ollama, Whisper, ComfyUI, Jan, HuggingFace all linked |
| **GPU headroom for Niri** | ✅ Complete | PYTORCH_CUDA_ALLOC_CONF=per_process_memory_fraction:0.95, OLLAMA_NUM_PARALLEL=2 |
| **Niri session manager** | ✅ Complete | Auto window save/restore, TOML config via HM, single-instance dedup |
| **EMEET PIXY webcam daemon** | ✅ Complete | Auto face tracking, noise cancellation, Waybar integration, hotplug recovery |
| **Wallpaper self-healing** | ✅ Complete | awww-daemon Restart=always, wallpaper PartOf=daemon, restore on crash |
| **Watchdog hardware watchdog** | ✅ Complete | SP5100 TCO, softlockup_panic, hung_task_panic, GPU recovery |
| **DNS failover cluster design** | ✅ Complete | Keepalived VRRP module, Pi 3 backup node config (hardware not provisioned) |
| **Catppuccin Mocha theme** | ✅ Complete | Universal: all apps, terminals, bars, login screen |
| **Taskwarrior + TaskChampion sync** | ✅ Complete | Cross-platform, deterministic client IDs, zero-setup, Android support |
| **ADR documentation** | ✅ Complete | 4 ADRs in `docs/adr/` (Go workspace, GPU headroom, BindsTo vs Wants, PartOf vs BindsTo) |
| **Flake checks & formatting** | ✅ Complete | statix, deadnix, treefmt + alejandra, all passing |
| **Justfile task runner** | ✅ Complete | 40+ recipes covering build, test, services, desktop, tasks, AI, disk |

### Session 49 Fixes (This Session)

| Fix | Status | Details |
|-----|--------|---------|
| **Hermes permission drift** | ✅ Fixed | `fixPermissionsScript` runs as root on every service start — recursive chown + chmod |
| **Hermes SQLite corruption** | ✅ Fixed | `chattr +C` disables BTRFS CoW on state dir + enforce WAL mode + synchronous=NORMAL |
| **Flake syntax check** | ✅ Passing | `nix flake check --no-build` clean |

---

## b) PARTIALLY DONE 🔧

| Item | Status | What's Left |
|------|--------|-------------|
| **Hermes MiniMax API key** | 🔧 Identified | Key is expired/invalid (HTTP 401). Fix is ready in `hermes.nix` but key must be regenerated from MiniMax console and updated in `sops platforms/nixos/secrets/hermes.yaml` |
| **Hermes unawaited coroutine** | 🔧 Identified | `RuntimeWarning: coroutine 'DiscordAdapter.send' was never awaited` — upstream bug in background review callback. Not crashing service yet but silently drops messages. Needs upstream fix. |
| **Service hardening adoption** | 🔧 63% complete | 20/32 modules use `harden{}`, 18/32 use `serviceDefaults{}`. 12 modules have no systemd services (correct). Remaining gaps: oneshot services (backups, token generators), `niri-config.nix`, Home Manager user services |
| **Hermes npmDeps hash patching** | 🔧 Ongoing | Upstream `hermes-agent` has stale `npmDepsHash` in `nix/tui.nix`. Local overlay intercepts `callPackage` and replaces hash. Must verify on each hermes upgrade. |
| **Darwin `colorScheme` override** | 🔧 Known | `platforms/darwin/default.nix:52` hardcodes `catppuccin-mocha`, overriding dynamic `preferences.appearance.colorSchemeName` option. Dead code path. |
| **service-health-check script** | 🔧 Fixed in repo, NOT deployed | Session 44 rewrote the script fixing 3 wrong service names + 7 missing services. `just switch` needed. |

---

## c) NOT STARTED ⏳

| Item | Priority | Notes |
|------|----------|-------|
| **Deploy pending changes** | 🔴 Critical | 2 unpushed commits + hermes.nix fix + service-health-check fix — `just switch` needed |
| **Monitor365 re-enablement** | Low | Service disabled due to "high RAM usage" — needs investigation or memory limit tuning |
| **PhotoMap re-enablement** | Medium | Disabled due to "podman config permission issue" — needs debugging |
| **DNS-over-QUIC** | Low | `unboundDoQOverlay` commented out — cascades to 40+ min rebuilds, not worth it |
| **Private cloud planning** | Low | `docs/planning/private-cloud-planning/` exists but no implementation |
| **Cross-platform consistency audit** | Medium | `docs/audits/` has reports from Dec 2025, likely stale |
| **Extract dnsblockd from SystemNix** | Low | Plan exists at `docs/planning/2026-05-03_02-52_extract-dnsblockd-from-systemnix.md` |
| **Nix anti-patterns phase 3-4** | Low | Plan at `docs/planning/2026-01-12_19-09-NIX-ANTI-PATTERNS-PHASE-3-4-EXECUTION-PLAN.md` |
| **Helium browser session restore** | Done | `--restore-last-session --disable-session-crashed-bubble` wrapper flags added |

---

## d) TOTALLY FUCKED UP 💥

| Item | Severity | Impact | Root Cause | Status |
|------|----------|--------|------------|--------|
| **Hermes MiniMax API key dead** | 🔴 Critical | All cron jobs using `minimax-m2.7-highspeed` fail (HTTP 401). ~8+ failures/day. | API key expired/invalid | 🔧 User must regenerate from MiniMax console |
| **Hermes permission drift** | 🔴 Critical | 58 `PermissionError` in 7 days. Skill self-management completely broken. | `hermes` user can't write to `/home/hermes/skills/` subdirectories (wrong ownership after self-created nested dirs) | ✅ Fixed this session (recursive chown on ExecStartPre) |
| **Hermes SQLite corruption** | 🟠 High | DB malformed weekly, falls back to JSONL, loses session state. Recurs because BTRFS CoW + SQLite journal = fragmentation. | BTRFS copy-on-write on `/home/hermes` (BTRFS root volume) | ✅ Fixed this session (`chattr +C` + WAL mode) |
| **service-health-check failing** | 🟠 High | Failing every 15 minutes for weeks. Notification spam. | 3 wrong service names in check script. Fix exists but **not deployed** | 🔧 `just switch` needed |
| **Disk usage: root 90%** | 🟡 Warning | 55G free of 512G. `/nix/store` is 65G. | Natural accumulation of generations + store | 🔧 `just clean` recommended |
| **Disk usage: /data 83%** | 🟡 Warning | 140G free of 800G. Docker + AI models. | Docker images, model files | 🔧 Docker prune recommended |
| **Hermes Z.AI rate limiting** | 🟡 Warning | HTTP 429 on `glm-5.1` model during cron jobs. | Z.AI overloaded or quota exceeded | 🔧 May need model fallback config |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Code Quality

1. **Oneshot service hardening** — 10+ backup/setup/token-generator oneshots lack `harden{}` and `serviceDefaults{}`. Apply consistently.
2. **Home Manager user services** — `file-and-image-renamer.nix` and `monitor365.nix` use raw `Service.{}` instead of `serviceDefaultsUser{}`.
3. **Hardcoded usernames** — `authelia.nix` ACLs hardcode `user:lars`; `hermes.nix` activation script hardcodes `lars`; should use `config.users.primaryUser`.
4. **Hardcoded paths** — `comfyui.nix` defaults to `/home/lars/projects/anime-comic-pipeline/...`; `disk-monitor.nix` hardcodes `DISPLAY=:0`.
5. **Darwin colorScheme dead code** — Remove hardcoded override, let dynamic `preferences.appearance.colorSchemeName` work.
6. **Duplicate nix.gc config** — Both `common/core/nix-settings.nix` and `nixos/system/networking.nix` declare `nix.gc`. Remove from one.
7. **DoQ port inconsistency** — UDP 853 open in firewall but DoQ disabled in dns-blocker-config.
8. **Empty darwin services/default.nix** — Placeholder with no content, should be removed or populated.

### Architecture

9. **Hermes npmDeps patching** — Fragile overlay intercepts `callPackage` for `tui.nix`. Should be fixed upstream.
10. **35 flake inputs** — Consider consolidating private LarsArtmann repos where possible (8 private `git+ssh://` inputs).
11. **270+ archived status reports** — Consider pruning or summarizing older ones.
12. **Planning docs sprawl** — 25 planning docs, many from late 2025. Needs triage — which are still relevant?

### Operations

13. **Disk cleanup** — Root 90%, /data 83%. Run `just clean` + Docker prune.
14. **Deploy cadence** — Multiple fixes sit in repo but aren't deployed (`just switch`). Establish deploy-after-fix discipline.
15. **API key rotation monitoring** — Hermes doesn't alert on API key expiry. Add Gatus check for provider auth validity.

---

## f) Top 25 Things We Should Get Done Next

### 🔴 Critical (Do Now)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy all pending changes** (`just switch`) | Fixes service-health-check, Hermes permissions, SQLite corruption | 10 min |
| 2 | **Regenerate MiniMax API key** from console, update sops | Restores all Hermes cron jobs | 5 min |
| 3 | **Run `just clean`** — disk at 90% root | Prevents disk-full failures | 5 min |
| 4 | **Docker system prune** — /data at 83% | Reclaims Docker image space | 5 min |

### 🟠 High Priority (This Week)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 5 | **Harden all oneshot services** — apply `harden{}` + `serviceDefaults{}` to backup/setup scripts | Defense in depth | 30 min |
| 6 | **Adopt `serviceDefaultsUser`** in file-and-image-renamer + monitor365 | Consistency | 15 min |
| 7 | **Replace hardcoded usernames** with `config.users.primaryUser` | Multi-user correctness | 30 min |
| 8 | **Fix Darwin colorScheme override** | Removes dead code path | 5 min |
| 9 | **Remove duplicate nix.gc** from networking.nix or nix-settings.nix | Eliminates redundancy | 5 min |
| 10 | **Push 3 local commits** to origin/master | Backup + sync | 1 min |

### 🟡 Medium Priority (This Sprint)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 11 | **PhotoMap re-enablement** — debug podman permission issue | Restores photo exploration service | 1-2 hrs |
| 12 | **Add Gatus check for Hermes API key validity** | Early warning on key expiry | 20 min |
| 13 | **Hermes upstream bug: unawaited coroutine** — file issue | Gets upstream fix for silent message drops | 15 min |
| 14 | **Remove UDP 853 firewall rule** (DoQ disabled) | Eliminates inconsistency | 5 min |
| 15 | **Clean up darwin services/default.nix** placeholder | Code hygiene | 5 min |
| 16 | **Audit docs/planning/** — triage 25 docs for relevance | Reduces cognitive load | 30 min |
| 17 | **Prune old docs/status/archive/** — 270+ files | Reduces repo size | 15 min |

### 🟢 Nice to Have (Backlog)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 18 | **Monitor365 re-enablement** with memory limit tuning | Device monitoring | 1 hr |
| 19 | **Extract dnsblockd** into standalone repo | Cleaner separation | 2-3 hrs |
| 20 | **Consolidate private flake inputs** where possible | Simpler dependency tree | 2 hrs |
| 21 | **Pi 3 DNS backup node provisioning** | HA DNS failover | 2-4 hrs |
| 22 | **Update cross-platform consistency audit** (stale from Dec 2025) | Ensures platform parity | 1 hr |
| 23 | **Add BTRFS snapshot automation** for /home/hermes before ExecStartPre | Additional safety net | 30 min |
| 24 | **Hermes structured logging** — contribute slog adoption upstream | Better observability | 4+ hrs |
| 25 | **Nix anti-patterns phase 3-4** execution plan | Codebase quality | 4+ hrs |

---

## g) Top #1 Question I Cannot Answer Myself 🤔

**When was the MiniMax API key last rotated, and what is the exact rotation/expiry policy on the MiniMax platform?**

The key `sk-cp-zvNpj9...` is being rejected as `invalid api key (2049)`. I cannot determine from logs whether:
- The key expired naturally (MiniMax has token expiry?)
- The key was revoked from the console
- The account ran out of credits and keys are invalidated
- This is a MiniMax platform migration (v1 → v2 API) that invalidated old keys

This requires logging into the MiniMax console to check. Once we have a new key, the fix is:
```bash
sops platforms/nixos/secrets/hermes.yaml
# Update minimax_api_key value
just switch
```

---

## System Metrics Snapshot

| Metric | Value | Status |
|--------|-------|--------|
| Root disk | 90% (55G free / 512G) | ⚠️ Warning |
| /data disk | 83% (140G free / 800G) | ⚠️ Warning |
| RAM | 48G/62G (77%) | ✅ OK |
| Nix store | 65G | ℹ️ Info |
| Nix version | 2.34.6 | ✅ Current |
| Flake checks | All passing | ✅ Clean |
| Failed systemd units | 1 (service-health-check) | ❌ Fix ready, needs deploy |
| Health check | 21/22 passed | ⚠️ service-health-check + 3 warnings |
| Unpushed commits | 2 (now 3 after this) | 🔧 Needs push |
| Hermes errors (7d) | 146 | 🔴 Degraded |

---

## Hermes Error Breakdown (Last 7 Days)

| Error Type | Count | Impact |
|------------|-------|--------|
| MiniMax HTTP 401 (invalid api key) | ~40 | All cron jobs using MiniMax fail |
| PermissionError writing skills | 58 | Skill self-management broken |
| SQLite database malformed | ~4 | Session state loss, JSONL fallback |
| Z.AI HTTP 429 (rate limit) | ~3 | Cron job failures during peak |
| Unawaited coroutine warning | 1+ | Silent message drops |
| interpreter shutdown during send | 1+ | Cron job delivery failure |

---

## File Changes This Session

- `modules/nixos/services/hermes.nix` — Added `fixPermissionsScript` (recursive chown on ExecStartPre), BTRFS CoW disable (`chattr +C`), WAL mode enforcement on SQLite

---

_Generated by Crush — Session 49_
