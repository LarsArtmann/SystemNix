# Session 73 — Monitoring Completeness, Overlay Extraction, Script Quality

**Date:** 2026-05-11
**Duration:** ~90 min
**Commits:** 9 (7ad8ae2d..123b1eaa)

---

## Summary

Continued the master TODO execution plan from session 71. Completed phases 2-5 (monitoring, overlay extraction, lib consistency, script quality) and partial phases 7-8 (security, documentation). Researched and decided to skip SigNoz v2 migration (no v2 API exists). Built and deployed via `nh os boot`.

## Completed Work

### Phase 2: Monitoring Completeness
- **Tasks 15-17:** Applied `hardenUser {}` to all 3 user services (monitor365, file-and-image-renamer, niri-drm-healthcheck)
- **Tasks 18-20:** Replaced Gatus sed hack with native Gatus env var interpolation — sops template provides `DISCORD_WEBHOOK_URL` via `environmentFile`, Gatus natively expands `$DISCORD_WEBHOOK_URL` in config YAML
- **Task 22:** Hardened ClickHouse with `harden {}` (4G MemoryMax) + `serviceDefaults {}` + `onFailure`
- **Task 23:** Added `onFailure` to amdgpu-metrics timer service
- **DNS blocking fix:** Changed Gatus DNS Blocking Active endpoint from `[DNS_RCODE] == NOERROR` to `[BODY] == 127.0.0.2` — actually verifies blocking is active

### Phase 3: Flake.nix Cleanup
- **Tasks 24-28:** Extracted all overlays from flake.nix to `overlays/` directory:
  - `overlays/shared.nix` — 13 shared overlay functions (Darwin + NixOS)
  - `overlays/linux.nix` — 6 Linux-only overlays
  - `overlays/default.nix` — composes both, exports `disableTests` + `pythonTest`
- Reduced flake.nix by ~200 lines (787 → 630)
- Fixed path references (`./pkgs/` → `../pkgs/` in overlay files)
- Removed dead `unboundDoQ` commented-out overlay block

### Phase 4: Lib/ Consistency
- **Task 33:** Audited all modules — all use `lib/default.nix` single import (only `rocm.nix` uses direct import, acceptable since it takes `pkgs` not `lib`)
- **Task 34:** Adopted `serviceTypes.servicePort` in voice-agents (replaced manual mkOption)
- **Task 36:** Fixed gpu-recovery `Type=oneshot` + `Restart=always` conflict — changed to `Restart=no`
- **Result:** Zero NixOS evaluation warnings (was 1)

### Phase 5: Script Quality
- **Tasks 37-39:** Confirmed `writeShellApplication` already wraps scripts with `set -euo pipefail` — no manual addition needed
- **Task 40:** Auto-detect AMD GPU PCI address in `gpu-recovery.sh` (scans DRM subsystem for vendor `0x1002`, fallback to evo-x2 default). Overridable via `GPU_PCI` env var
- **Task 41:** Parameterized hostname in `nixos-diagnostic.sh` (auto-detected from `hostname`). Overridable via `FLAKE_HOST` env var
- **Task 42:** Added `just validate-scripts` recipe (shellcheck all scripts)

### Phase 6: SigNoz v2 Migration — SKIPPED
- Researched SigNoz API: **no v2 rules API exists**. The current `POST /api/v1/rules` is the recommended and only API for programmatic rule management. "v2" references in Terraform provider are schema version, not API version.
- Decision: Skip tasks 43-47 entirely.

### Phase 7: Security & Secrets
- **Task 53:** Added Gatus TLS certificate expiry check for `auth.home.lan` (7-day threshold, Discord alert)
- **Task 52 (blocked):** dns-failover VRRP password migration to sops blocked — age identity not available in this session (uses SSH host key)

### Phase 8: Documentation
- **Task 60:** Updated AGENTS.md with `hardenUser {}` pattern in lib/ section
- **Task 61:** Updated AGENTS.md with overlay extraction structure
- Updated: architecture tree (overlays/ directory), Gatus section (Discord alerting, 26+ endpoints), lib helpers table, overlay naming, essential commands

## Commit Log

| Commit | Description |
|--------|-------------|
| `7ad8ae2d` | fix(monitoring): harden user services + fix DNS blocking check |
| `6a310af1` | refactor(gatus): replace sed hack with native env var interpolation |
| `7d3f3694` | harden(signoz): sandbox ClickHouse + onFailure for amdgpu-metrics |
| `127e0c68` | refactor(flake): extract overlays to overlays/ directory |
| `7002bb6e` | fix(gpu-recovery): auto-detect AMD GPU PCI address |
| `842d6d88` | fix(scripts): parameterize hostname + PCI address, add validate-scripts |
| `e0e29026` | fix(lib): adopt servicePort in voice-agents, fix gpu-recovery oneshot warning |
| `123b1eaa` | docs(agents): update architecture + add TLS cert check |

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Skip SigNoz v2 migration | No v2 API exists — v1 is current and recommended |
| Gatus env var over sops template | Gatus natively supports `${VAR}` interpolation; nixpkgs module has `environmentFile` — cleaner than generating full YAML via sops template |
| Keep `restartDelay`/`stopTimeout` in lib/types.nix | Used by hermes module options; good pattern for configurable timing |
| Auto-detect GPU PCI address | Long-term portability; `writeShellApplication` provides bash for `readlink -f` |

## Not Done (from master plan)

| Tasks | Reason |
|-------|--------|
| 1-8 (deploy + verify) | Requires physical machine access after reboot |
| 21 (disk-monitor serviceDefaults) | Need to verify if already present |
| 52 (dns-failover sops) | Blocked — age identity not available |
| 43-47 (SigNoz v2) | Skipped — no v2 API exists |
| 48-51 (SigNoz dashboards) | Deferred to next session |
| 54 (Caddy metrics dashboard) | Deferred |
| 55 (TODO_LIST.md) | Deferred |
| 56-57 (ADRs) | Deferred |
| 58 (archive status docs) | Deferred |
| 59 (consolidate AGENTS.md) | Partially done |
| 62-64 (test infrastructure) | Deferred |
| 65-66 (lib helpers) | Deferred |
| 67-68 (Pi 3) | Hardware not provisioned |

## Monitoring Coverage

| Metric | Count |
|--------|-------|
| SigNoz alert rules | 11 (2 new: Ollama Down, Docker Daemon Down) |
| Gatus endpoints | 26+ (4 new: DNS Blocking Active, DNS Resolver TCP, Upstream DNS, TLS Cert Expiry) |
| Discord alert channels | 1 (SigNoz + Gatus shared) |
| Services with `harden {}` | 23 (ClickHouse new) |
| User services with `hardenUser {}` | 3 (monitor365, file-and-image-renamer, niri-drm-healthcheck) |
| Services with `onFailure` | 22 (ClickHouse + amdgpu-metrics new) |
| NixOS evaluation warnings | 0 (was 1) |
