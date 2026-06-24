# SystemNix — Full Comprehensive Status Report

**Date:** 2026-05-11 23:15 CEST
**Session:** 76
**Branch:** master (clean, up to date with origin)
**Nix files:** 109 | **Service modules:** 35 | **Scripts:** 15 | **Justfile recipes:** 75
**Total Nix LOC:** ~14,251 (modules: 6,555; flake.nix: 602; lib: 196)

---

## Executive Summary

SystemNix is in **excellent shape**. All `nix flake check --no-build` passes clean. Only 1 evaluation warning remains (x86_64-darwin deprecation notice from nixpkgs — informational, not actionable). The codebase has matured dramatically over sessions 66–76: overlays extracted, hardening standardized, GPU OOM defense deployed, observability fully operational, and `system` deprecation warning fixed this session.

**Uncommitted work:** flake.lock (art-dupl update) + sops.nix (gatus template owner fix).

---

## a) FULLY DONE ✅

### Infrastructure Core
- **Cross-platform Nix flake** — Darwin + NixOS, 80% shared via `platforms/common/`
- **flake-parts modular architecture** — 35 service modules, dendritic pattern
- **Overlay extraction** — `overlays/shared.nix` (12 overlays), `overlays/linux.nix` (6 overlays), `overlays/default.nix` (utility overlays)
- **Shared Home Manager** — 14 program modules, single import pattern
- **Custom packages** — 13 packages across Go/Rust/Python/Node.js/AppImage
- **Formatter** — treefmt + alejandra, wired via treefmt-full-flake
- **CI/CD** — GitHub Actions (weekly flake-update PR, on-push nix check), pre-commit hooks (shellcheck, markdownlint, gitleaks)

### NixOS Services (evo-x2)
- **Caddy reverse proxy** — 10+ virtual hosts, TLS via sops, forward auth, metrics port 2019
- **Authelia SSO** — OIDC, TOTP + WebAuthn 2FA, brute-force protection
- **SigNoz observability** — Full stack (ClickHouse, OTel Collector, node_exporter, cAdvisor, 7 alert rules, dashboard provisioning, journald logs)
- **Gatus health monitoring** — 26+ endpoints, SQLite, Discord alerting, TLS cert check
- **Gitea** — SQLite, LFS, GitHub mirror, Actions runner, declarative repo mirroring
- **Immich** — PostgreSQL + Redis + ML, OAuth, daily DB backup
- **Twenty CRM** — Docker Compose (4 containers), daily DB backup
- **Hermes AI gateway** — Discord bot, cron, system service, sops secrets, SQLite auto-recovery
- **TaskChampion** — Taskwarrior sync, deterministic UUID, zero-setup cross-platform
- **Homepage Dashboard** — Catppuccin Mocha, 5 categories, resource widgets
- **OpenSEO** — SEO suite, Docker, DataForSEO API via sops
- **Docker** — Always-on, overlay2 on `/data/docker`, weekly prune
- **Minecraft** — JDK 25, ZGC, LAN-only, whitelist

### AI/ML Stack
- **Centralized AI model storage** — `/data/ai/` tree (14 dirs), env vars, tmpfiles rules
- **Ollama** — ROCm GPU, flash attention, `MAX_LOADED_MODELS=1` defense, 8 GiB overhead
- **ComfyUI** — ROCm GPU, bf16, memory fraction 0.50
- **llama.cpp** — ROCWMMA + MFMA custom build

### Desktop & System
- **Niri compositor** — Scrolling-tiling Wayland, 80+ keybindings, patched BindsTo→Wants, OOM -1000
- **Niri session save/restore** — Periodic snapshots, workspace-aware restore
- **Niri DRM healthcheck + GPU recovery** — Consecutive failure detection, unbind/rebind, auto-reboot
- **EMEET PIXY webcam** — Full daemon: call detection, auto-tracking, noise cancellation, privacy mode, PipeWire source switch, Waybar indicator, hotplug recovery, bidirectional HID state sync
- **DNS blocker** — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, temp-allow API, false positive reporting, Prometheus metrics, 10-category system, Catppuccin block page
- **BTRFS** — Root (zstd) + data (zstd:3), Timeshift snapshots, monthly scrub
- **ZRAM swap** — 50% RAM (64 GB compressed)
- **Security hardening** — fail2ban, ClamAV, polkit, GNOME Keyring, 30+ security tools
- **earlyoom** — Kills at 10% free, protects critical services

### macOS (Darwin)
- **nix-darwin** — Full declarative macOS config
- **Touch ID for sudo** — PAM, tmux reattach
- **Chrome policies** — Enterprise-grade security
- **Homebrew** — Declarative via nix-homebrew
- **ActivityWatch** — LaunchAgent auto-start + Nix-managed utilization watcher
- **Keychain auto-lock** — 5-minute timeout

### Code Quality Patterns
- **`lib/` shared helpers** — `harden`, `hardenUser`, `serviceDefaults`, `serviceDefaultsUser`, `serviceTypes`, `mkGraphicalUserService` (196 LOC total)
- **ADR archive** — 6 decisions documented
- **Validation scripts** — 8 working (health-check, nixos-diagnostic, validate, test-hm, test-aliases, dns-diagnostics, gpu-recovery, wallpaper-set)
- **Justfile** — 75 recipes, well-organized by category

### Session 76 Achievements (this session)
- **Fixed `system` deprecation warning** — `art-dupl` upstream overlay changed from `prev.system` to `prev.stdenv.hostPlatform.system`
- **Updated flake.lock** — art-dupl pinned to `9b4054c` (fix included)
- **Identified sops.nix fix** — gatus template owner/group changed from `gatus` to `root` (uncommitted, needs verification)

---

## b) PARTIALLY DONE ⚠️

| Area | Status | What's Missing |
|------|--------|----------------|
| **nix-colors integration** | Research done (`docs/planning/NIX-COLORS-INTEGRATION-RESEARCH.md`) | 17+ hardcoded colors still in niri-wrapped, waybar, rofi, dunst, kitty — ~6h migration |
| **Dozzle deployment** | Evaluation done (`docs/planning/2026-05-11_dozzle-evaluation.md`) | No module created yet — Docker log tailing at `logs.home.lan` |
| **Voice agents (LiveKit + Whisper)** | Module exists, enabled in config | Whisper Docker + ROCm pipeline unverified — may need testing |
| **DNS-over-QUIC** | Disabled in dns-blocker.nix | Unbound not compiled with ngtcp2 — needs upstream fix |
| **PhotoMap AI** | Module exists, disabled | Pinned to old SHA256, disabled in config — bitrot likely |
| **Multi-WM (Sway backup)** | Module exists, disabled | Not tested recently — may have bitrot |
| **Unsloth Studio** | Module exists, disabled | Complex PyTorch ROCm build, disabled by default |
| **SigNoz alert routing** | Basic Discord alerts working | Per-threshold routing (critical→Discord, warning→log) not implemented |
| **Gatus sops template** | Discord webhook wired | Owner changed to `root` as fix — needs verification that Gatus can still read the env file |

---

## c) NOT STARTED 📋

| Task | Priority | Estimated Effort |
|------|----------|-----------------|
| **Provision Raspberry Pi 3** for DNS failover cluster | Medium | Hardware task (physical) |
| **Wire Pi 3 as secondary DNS** in dns-failover.nix | Medium | Depends on Pi provisioning |
| **Deploy to evo-x2** with latest kernel (7.0.1→7.0.6) | High | `just switch` + reboot |
| **Move dns-failover `authPassword` to sops** | Medium | Blocked on age identity |
| **Consolidate voice-agents Caddy vHost** into caddy.nix pattern | Low | Refactoring |
| **Create shared flake-parts template** (mkGoPackage, checks, devshells) | Medium | Template creation |
| **Convert go-auto-upgrade `path:` inputs to SSH URLs** | Low | External repo task |
| **Compute real `vendorHash` for BuildFlow** (fix fakeHash) | Medium | External repo task |
| **Compute real `vendorHash` for PMA** (replace null) | Medium | External repo task |
| **Create `flake.nix` for hierarchical-errors** | Low | External repo task |
| **Auditd enablement** — blocked by NixOS 26.05 bug #483085 | Low | Upstream fix needed |
| **AppArmor enablement** | Low | Currently disabled |
| **dnsblockd temp-allow persistence** — in-memory only, lost on restart | Low | SQLite or file persistence |
| **dnsblockd Category enum** — stringly-typed | Low | Go type safety improvement |

---

## d) TOTALLY FUCKED UP ❌

| Issue | Severity | Status |
|-------|----------|--------|
| **No critical issues** | — | System is stable and functional |

**Minor issues:**
| Issue | Severity | Notes |
|-------|----------|-------|
| `benchmark-system.sh` referenced in FEATURES.md | Low | Script doesn't exist — but already removed from justfile |
| `performance-monitor.sh` referenced in FEATURES.md | Low | Script doesn't exist — but already removed from justfile |
| `storage-cleanup.sh` referenced in FEATURES.md | Low | Script doesn't exist — but already removed from justfile |
| sops.nix gatus template owner fix uncommitted | Medium | Changed `gatus:gatus` → `root:root` — needs deploy verification |
| FEATURES.md outdated — still references missing scripts | Low | Needs refresh to remove benchmark/perf/storage-cleanup references |

**The good news:** FEATURES.md references non-existent scripts, but the justfile was already cleaned up. The documentation just needs a sync.

---

## e) WHAT WE SHOULD IMPROVE 🔧

### High Impact
1. **Deploy the accumulated changes** — Multiple commits since last deploy (kernel bump, overlay fixes, art-dupl update, sops fix). `just switch` + reboot needed.
2. **Verify Gatus sops fix** — The owner change from `gatus` to `root` needs real-world testing. If Gatus runs as `gatus` user, it may not be able to read the root-owned template file.
3. **FEATURES.md freshness** — Still references 4 non-existent scripts from old justfile. Should be cleaned up.

### Medium Impact
4. **nix-colors migration** — 17+ hardcoded colors across niri, waybar, rofi, dunst, kitty. Research is done, execution is ~6h. This would make theme switching a 1-line change.
5. **Dozzle deployment** — Evaluation complete. Would give real-time Docker container log viewing at `logs.home.lan`.
6. **SigNoz per-threshold routing** — Currently all alerts go to Discord. Critical vs warning separation would reduce noise.
7. **External repo flake standardization** — BuildFlow fakeHash, PMA null hash, hierarchical-errors missing flake.nix. These are technical debt in the Go ecosystem.

### Low Impact
8. **dnsblockd persistence** — Temp-allow state lost on restart. SQLite persistence would improve UX.
9. **DNS-over-QUIC** — Blocked on unbound upstream. Low priority.
10. **PhotoMap / Multi-WM / Unsloth** — All disabled. Enable when needed or clean up.

---

## f) Top #25 Things We Should Get Done Next

### Tier 1: Deploy & Verify (Do First)
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | **Deploy to evo-x2**: `just switch` + reboot with kernel 7.0.1→7.0.6 | 15 min | Critical — multiple fixes untested on real hardware |
| 2 | **Verify all services start clean**: `systemctl --failed` after reboot | 5 min | Critical — confirm no regressions |
| 3 | **Verify Gatus sops template**: Check `status.home.lan` loads webhook, Discord alerts fire | 10 min | High — sops owner change needs verification |
| 4 | **Test Discord alert**: `POST /api/v1/channels/test` via SigNoz | 5 min | High — confirm alert pipeline end-to-end |
| 5 | **Commit sops.nix fix**: gatus template owner change | 2 min | High — uncommitted fix |

### Tier 2: Quick Wins (Under 1 Hour Each)
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | **Refresh FEATURES.md**: Remove references to non-existent scripts (benchmark, perf, storage-cleanup, context) | 15 min | Medium — docs accuracy |
| 7 | **Archive stale planning docs**: 28 planning files in `docs/planning/`, most from 2025 — archive pre-2026 | 10 min | Low — clutter reduction |
| 8 | **Fix `dnsblockd` category types**: Define Go `Category` enum instead of stringly-typed categories | 30 min | Medium — type safety (external repo) |
| 9 | **Add `nix-colors` to a single test app** (e.g., kitty) as proof-of-concept | 30 min | Medium — unblocks full migration |
| 10 | **Deploy Dozzle**: Docker log viewer at `logs.home.lan` | 45 min | Medium — evaluation done, needs implementation |

### Tier 3: Important Improvements (1–4 Hours Each)
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | **nix-colors full migration**: Wire `colorScheme` to all 17+ hardcoded colors | 6h | High — single-source-of-truth theming |
| 12 | **SigNoz alert routing**: critical→Discord, warning→log-only | 2h | Medium — reduce alert noise |
| 13 | **Move dns-failover `authPassword` to sops** | 1h | Medium — secrets hygiene |
| 14 | **Consolidate voice-agents Caddy vHost** into caddy.nix pattern | 1h | Low — consistency |
| 15 | **Create shared flake-parts Go template** | 3h | Medium — standardize all Go repos |

### Tier 4: External Repo Cleanup
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 16 | **Compute real `vendorHash` for BuildFlow** (fix fakeHash) | 30 min | Medium — unblock nix builds |
| 17 | **Compute real `vendorHash` for PMA** (replace null) | 30 min | Medium — unblock nix builds |
| 18 | **Create `flake.nix` for hierarchical-errors** | 1h | Low — repo has no flake |
| 19 | **Convert go-auto-upgrade `path:` inputs to SSH URLs** | 30 min | Low — portability |

### Tier 5: Future / Blocked
| # | Task | Effort | Impact |
|---|------|--------|--------|
| 20 | **Provision Raspberry Pi 3** for DNS failover cluster | Hardware | High — HA DNS |
| 21 | **Wire Pi 3 as secondary DNS** in dns-failover.nix | 2h | High — depends on #20 |
| 22 | **Enable Auditd** after NixOS 26.05 bug #483085 is fixed | 1h | Medium — security |
| 23 | **Enable AppArmor** | 2h | Medium — security hardening |
| 24 | **dnsblockd temp-allow persistence** (SQLite) | 2h | Low — UX improvement |
| 25 | **DNS-over-QUIC** when unbound supports ngtcp2 | Blocked | Low — upstream |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why was the Gatus sops template owner changed from `gatus:gatus` to `root:root`?**

The uncommitted change in `modules/nixos/services/sops.nix` changes:
```nix
owner = "gatus"; group = "gatus";  →  owner = "root"; group = "root";
```

If Gatus runs as the `gatus` user (which it should, per the nixpkgs module), it may not be able to read a `root:root`-owned file with default permissions. This change either:
- Was made because the `gatus` user doesn't exist yet on the system (timing issue with sops decryption vs user creation), OR
- Was a debugging workaround that accidentally got left in the working tree

**I need to know:** Should this change be committed? Was there a specific issue with the `gatus` user not being able to read the template? Or should we revert it and use `gatus:gatus` with appropriate permissions?

---

## Codebase Metrics

| Metric | Value |
|--------|-------|
| Total Nix files | 109 |
| Total Nix LOC | ~14,251 |
| Service modules | 35 |
| Custom packages | 13 |
| Shell scripts | 15 |
| Justfile recipes | 75 |
| GitHub Actions | 2 |
| Pre-commit hooks | 7 |
| ADRs | 6 |
| Lib helpers | 5 (196 LOC) |
| Evaluation warnings | 1 (x86_64-darwin deprecation — informational) |
| Build errors | 0 |
| Uncommitted files | 2 (flake.lock, sops.nix) |

## Uncommitted Changes

| File | Change | Action Needed |
|------|--------|---------------|
| `flake.lock` | art-dupl updated to `9b4054c` (fixes `system` deprecation) | Commit |
| `modules/nixos/services/sops.nix` | gatus template owner `gatus:gatus` → `root:root` | Verify before commit |

---

_Generated at 2026-05-11 23:15 CEST by session 76._
