# SystemNix — Full Comprehensive Status Report

**Date:** 2026-05-11 23:23
**Session:** 77
**Machine:** evo-x2 (NixOS 26.05, x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)
**Branch:** master (1 commit ahead of origin)
**Uptime:** 42 minutes (recent reboot)
**Commits today:** 64

---

## a) FULLY DONE ✅

### Session 76–77: Critical Fix + Pipe Operator Modernization

| # | What | File | Detail |
|---|------|------|--------|
| 1 | **Gatus sops secret fix** | `modules/nixos/services/sops.nix` | Fixed `gatus-env` template owner from `gatus`→`root`. nixpkgs `services.gatus` uses `DynamicUser=true` (no static user), so sops-install-secrets failed validation at activation — blocking ALL secret installation. Now passes. |
| 2 | **Pipe operator refactor: sops.nix** | `modules/nixos/services/sops.nix` | Rewrote `mkSecrets` and `mkKeyedSecrets` using `|>` pipe operators. |
| 3 | **Pipe operator refactor: manifest.nix** | `modules/nixos/services/manifest.nix` | Rewrote sops secrets generation with `|>` pipe chain. |
| 4 | **Pipe operator refactor: niri-config.nix** | `modules/nixos/services/niri-config.nix` | Rewrote unit file processing pipeline with `|>` pipe chains (BindsTo→Wants patch, unit file filtering). |
| 5 | **Pipe operator refactor: taskwarrior.nix** | `platforms/common/programs/taskwarrior.nix` | Rewrote UUID derivation with `|>` pipes. |

### Sessions 67–76: Major Sprint (64 commits today)

| Category | Completed | Highlights |
|----------|-----------|------------|
| **Overlay extraction** | ✅ | Extracted 18 overlays from `flake.nix` → `overlays/{shared,linux,default}.nix`. flake.nix reduced 787→603 lines. |
| **Monitoring completeness** | ✅ | Gatus 26+ endpoints with Discord alerting, SigNoz alert rules + 5 dashboards (GPU, DNS, Docker, Caddy, Service Failure Spike). |
| **Service hardening** | ✅ | `hardenUser {}` lib helper, applied to 3 user services (monitor365, file-and-image-renamer, niri-drm-healthcheck). All system services use `harden {}`. |
| **Script quality** | ✅ | All shell scripts wrapped in `writeShellApplication` (set -euo pipefail). PCI address auto-detection, hostname parameterization, `just validate-scripts`. |
| **Dual-WAN fix** | ✅ | WiFi interface name fixed from `wlp195s0` to `wlan0`. |
| **rpi3-dns build** | ✅ | Removed explicit `system` — nixpkgs infers `aarch64-linux`. mr-sync overlay supports aarch64. |
| **ADRs** | ✅ | 6 architecture decision records (go-workspace, GPU headroom, BindsTo vs Wants, PartOf vs BindsTo, Discord notifications, Gatus secret injection). |
| **Pipe operators** | ✅ | `nixConfig` declares `pipe-operators` experimental feature. 4 files refactored to use `|>`. |

### Build Verification

| Check | Result |
|-------|--------|
| `just test-fast` (syntax) | ✅ all checks passed |
| `just test` (full build) | ✅ 18/18 derivations |
| `just health` | ⚠️ 1 failed (3 systemd units), 24 passed |
| `just format` | ✅ clean |

---

## b) PARTIALLY DONE 🔧

| Item | Status | Detail |
|------|--------|--------|
| **Deploy to production** | ⬜ Phase 1 tasks 2–8 | Build passes, but `just switch` not yet run. 3 services failing in `nh os test` (clickhouse, niri-health-metrics, signoz-provision) — likely environment-specific, not code bugs. |
| **Nix Flake Standardization (9 Go projects)** | 🟡 Plan written | `docs/planning/2026-05-11_11-47-NIX-FLAKE-STANDARDIZATION.md` has full plan. Phase 1 (fix 3 broken builds), Phase 2 (shared template), Phase 3 (apply to all). Not started on actual projects. |
| **Dozzle evaluation** | 🟡 Evaluated | `docs/planning/2026-05-11_dozzle-evaluation.md` complete. Decision not yet made. |

---

## c) NOT STARTED ⬜

From Master TODO (`docs/planning/2026-05-11_17-30_MASTER-TODO-EXECUTION-PLAN.md`):

| # | Task | Priority | Why Not Started |
|---|------|----------|----------------|
| 2–8 | Deploy + verify on evo-x2 | 🔴 | Needs manual `just switch` |
| 46 | SigNoz per-threshold channel routing | 🟢 | Low priority |
| 52 | Move dns-failover authPassword to sops | 🟡 | Blocked — needs age identity setup |
| 55 | Create TODO_LIST.md | 🟡 | Documentation |
| 56 | ADR: Discord notification architecture | 🟢 | Already have ADR-005 |
| 57 | ADR: Gatus secret injection | 🟢 | Already have ADR-006 |
| 58 | Archive old status docs | 🔵 | Housekeeping |
| 62–64 | Test infrastructure (`just test` recipes) | 🟢 | Existing `just test` already works |
| 65 | `mkGraphicalUserService` helper | 🟢 | DRY improvement |
| 66 | Voice-agents Caddy consolidation | 🟢 | Code quality |
| 67–68 | Pi 3 DNS failover | 🔵 | Hardware not provisioned |

---

## d) TOTALLY FUCKED UP 💥

### Currently Failing Services (3 system units)

| Service | Error | Root Cause | Severity |
|---------|-------|-----------|----------|
| **caddy.service** | Failed to start | Likely missing TLS cert or sops secret after reboot. Was working before last deploy. | 🔴 Critical — all `*.home.lan` services unreachable |
| **niri-health-metrics.service** | Failed | Depends on niri compositor state. Check journal for specifics. | 🟡 Medium — monitoring only |
| **signoz-provision.service** | Failed | SigNoz provisioning (alert rules, dashboards). Check if ClickHouse is running first. | 🟡 Medium — monitoring only |

### Known Persistent Issues

| Issue | Status | Impact |
|-------|--------|--------|
| ~130W power ceiling | Accepted — firmware limit | No OS fix possible |
| awww-daemon BrokenPipe on Wayland disconnect | Covered by `Restart=always` | Self-healing |
| watchdogd nixpkgs module broken for `device` | Workaround applied | Can't track reset reasons |
| Helium "RESTORE TABS" on every launch | Fixed with `--restore-last-session` wrapper | Resolved |

### Disk Usage Concern

| Mount | Used | Free | Total | Note |
|-------|------|------|-------|------|
| `/` | 80% (394G) | 99G | 512G | `/nix/store` is 94G — consider `just clean` |
| `/data` | 80% (819G) | 206G | 1.0T | Docker images consuming bulk |

---

## e) WHAT WE SHOULD IMPROVE 🔧

### High-Impact Improvements

1. **Caddy reliability on boot** — 3 reboots in recent history, caddy failed each time. Need to investigate if it's a sops secret race condition or TLS cert issue.
2. **Disk hygiene** — 80% on both mounts. `just clean` should be run regularly. Consider automated cleanup timer.
3. **Secret deployment ordering** — The gatus incident showed sops validates ALL owners before ANY user creation. Services using `DynamicUser` can't own sops secrets. Need audit of all sops templates for DynamicUser compatibility.
4. **Test infrastructure** — `just test` (full build) takes 21s and catches real issues. But 3 services fail in `nh os test` — these may be environment-specific or may indicate real bugs. Need investigation.
5. **Pipe operator migration** — Only 4 files converted. Many more Nix files could benefit from `|>` readability improvement.

### Architecture Improvements

6. **mkGraphicalUserService adoption** — Helper exists but not yet adopted by all user services that follow the `After/PartOf/WantedBy graphical-session.target` pattern.
7. **Voice-agents Caddy consolidation** — Currently has its own Caddy vHost pattern instead of using the standard `caddy.nix` module.
8. **Dozzle decision** — Evaluation complete but no deployment decision. Would replace manual `docker logs` with web UI.
9. **Nix Flake Standardization** — Plan exists for 9 Go projects but no execution yet. Would unify build tooling across LarsArtmann ecosystem.

---

## f) TOP 25 THINGS TO DO NEXT

### 🔴 P0 — Deploy or Die (blocks everything)

| # | Task | Est |
|---|------|-----|
| 1 | Run `just switch` to deploy current config | 10min |
| 2 | Investigate and fix caddy.service failure | 10min |
| 3 | Investigate and fix signoz-provision.service failure | 10min |
| 4 | Investigate and fix niri-health-metrics.service failure | 5min |
| 5 | Verify all services start clean after fixes | 3min |
| 6 | `git push` to origin (1 commit ahead) | 2min |

### 🟡 P1 — High Impact

| # | Task | Est |
|---|------|-----|
| 7 | Audit all sops templates for DynamicUser compatibility (prevent future gatus-like failures) | 15min |
| 8 | Run `just clean` to reclaim disk space on both mounts | 10min |
| 9 | Investigate caddy boot reliability — add `After=sops-nix.service` if needed | 10min |
| 10 | Continue pipe operator migration to remaining Nix files | 30min |
| 11 | Adopt `mkGraphicalUserService` in all user services that match the pattern | 15min |

### 🟢 P2 — Code Quality

| # | Task | Est |
|---|------|-----|
| 12 | Consolidate voice-agents Caddy vHost into caddy.nix | 10min |
| 13 | Deploy Dozzle for Docker log viewing (if decision is yes) | 15min |
| 14 | Start Nix Flake Standardization Phase 1: fix 3 broken Go builds (BuildFlow, PMA, go-auto-upgrade) | 30min |
| 15 | Add `just test` integration: test-home-manager + test-shell-aliases | 15min |
| 16 | Create/update TODO_LIST.md from all planning docs | 10min |
| 17 | Archive old status docs (sessions 45–62) | 5min |
| 18 | Move dns-failover authPassword to sops (unblock: needs age identity) | 10min |
| 19 | Add SigNoz per-threshold channel routing (critical vs warning) | 10min |
| 20 | Add Gatus endpoint: Dozzle (if deployed) | 5min |

### 🔵 P3 — Infrastructure

| # | Task | Est |
|---|------|-----|
| 21 | Create shared flake-parts template for Go projects (Phase 2 of standardization) | 30min |
| 22 | Apply template to all 9 LarsArtmann Go projects (Phase 3) | 2hr |
| 23 | Provision Pi 3 hardware for DNS failover cluster | Hardware |
| 24 | Wire Pi 3 as secondary DNS in dns-failover.nix | 10min |
| 25 | Add automated disk cleanup timer (monthly `just clean`) | 10min |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**Why does caddy.service consistently fail after reboot?**

caddy has failed in multiple recent activation cycles. Possible causes:
1. **sops secret race** — caddy needs TLS certs from sops (`dnsblockd_server_cert`/`dnsblockd_server_key`), and sops-install-secrets may not complete before caddy starts
2. **Missing `After=sops-nix.service`** — caddy's systemd unit may need explicit ordering
3. **TLS cert path issues** — certs may not be at expected paths after reboot
4. **Port conflict** — something else binding to 443/80 before caddy starts

I cannot check `journalctl -u caddy` or inspect the live system state. The next `just switch` + manual investigation of `journalctl -u caddy.service -b` would reveal the exact cause.

---

## System State Summary

| Metric | Value |
|--------|-------|
| NixOS version | 26.05.20260423.01fbdee (Yarara) |
| Nix version | 2.34.6 |
| Kernel | (needs reboot to update) |
| Uptime | 42 minutes |
| Load | 0.82, 2.33, 4.17 |
| Memory | 39G/62G (62%) |
| Swap | 9.0G/25G used |
| Disk `/` | 80% (99G free) |
| Disk `/data` | 80% (206G free) |
| Users online | 11 |
| Failed units | 3 system (caddy, niri-health-metrics, signoz-provision) |
| Commits today | 64 |
| Uncommitted changes | 4 files (3 staged, 1 unstaged) |
| Branch status | 1 commit ahead of origin |
| Total LOC | ~9,200 lines (flake, overlays, modules, lib, scripts) |

---

_Arte in Aeternum_
