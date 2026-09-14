# Session 30 — Manifest LLM Router Integration + Full System Status

**Date:** 2026-05-05 20:37
**Session:** 30
**Branch:** master (clean before this commit)
**Previous:** Session 29 — brutal self-review + architecture cleanup sprint

---

## Executive Summary

This session added **Manifest** (open-source LLM router) as a fully declarative NixOS service module with Docker Compose backend, sops secrets, Caddy reverse proxy, DNS record, homepage dashboard entry, and justfile commands. All `just test-fast` checks pass. The module awaits sops secret creation and `just switch` deployment on evo-x2.

Beyond Manifest, the system carries forward **3 critical issues from session 28** (failing services: caddy, comfyui, photomap), **undeployed session 29 changes**, and an **84% root disk** situation. This report provides a full project health assessment.

---

## a) FULLY DONE ✅

### Session 30 Work

| Item                      | Files                                             | Status                                                                                                            |
| ------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| **Manifest NixOS module** | `modules/nixos/services/manifest.nix` (207 lines) | ✅ Full flake-parts module: Docker Compose stack, systemd service, daily backup timer, sops secrets, health check |
| **Caddy reverse proxy**   | `modules/nixos/services/caddy.nix`                | ✅ `manifest.home.lan` with forward auth (protected vhost)                                                        |
| **DNS record**            | `platforms/nixos/system/dns-blocker-config.nix`   | ✅ `manifest` added to unbound local-data                                                                         |
| **Sops secrets**          | `modules/nixos/services/sops.nix`                 | ✅ `manifest_auth_secret`, `manifest_encryption_key`, `manifest_db_password` from `manifest.yaml`                 |
| **Homepage dashboard**    | `modules/nixos/services/homepage.nix`             | ✅ Manifest card under Monitoring with health check                                                               |
| **Justfile commands**     | `justfile`                                        | ✅ `manifest-status`, `manifest-restart`, `manifest-logs`, `manifest-logs-follow`, `manifest-backup`              |
| **Flake wiring**          | `flake.nix`                                       | ✅ Import + `nixosModules.manifest` added to evo-x2 modules                                                       |
| **Service enablement**    | `platforms/nixos/system/configuration.nix`        | ✅ `services.manifest.enable = true`                                                                              |
| **Formatting**            | `manifest.nix`                                    | ✅ `nix fmt` — 0 changes needed                                                                                   |
| **Validation**            | All                                               | ✅ `just test-fast` — all checks passed                                                                           |

### Carried Over (Previous Sessions)

| Item                                                                                    | Status                     |
| --------------------------------------------------------------------------------------- | -------------------------- |
| **primaryUser module** (session 29) — eliminated 15 hardcoded `"lars"` refs             | ✅ Done                    |
| **Dead code removal** (session 29) — gatus.nix, nix-visualize input, lib/default.nix    | ✅ Done                    |
| **serviceDefaults migration** (session 29) — twenty, gitea-repos, ai-stack              | ✅ Done                    |
| **Port split-brain fix** (session 29) — caddy references service config ports           | ✅ Done                    |
| **Service hardening** (sessions 28-29) — 16/18 applicable services use `harden()` (89%) | ✅ Done                    |
| **Taskwarrior + TaskChampion** — zero-setup sync, cross-platform                        | ✅ Done                    |
| **DNS blocker** — Unbound + dnsblockd, 2.5M+ domains                                    | ✅ In production           |
| **SigNoz observability** — full stack (ClickHouse, OTel, node_exporter, cAdvisor)       | ✅ In production           |
| **Niri session save/restore** — crash recovery with kitty state                         | ✅ In production           |
| **Wallpaper self-healing** — awww daemon with systemd PartOf recovery                   | ✅ In production           |
| **EMEET PIXY webcam** — auto-tracking, audio modes, Waybar indicator                    | ✅ In production           |
| **Hermes AI gateway** — Discord bot, cron scheduler, multi-provider                     | ✅ In production           |
| **AI model storage** — centralized `/data/ai/` with all services referencing it         | ✅ In production           |
| **32 service modules** in flake-parts architecture                                      | ✅ All wired and evaluated |

---

## b) PARTIALLY DONE ⚠️

| Item                                | What's Done                                                                                      | What's Missing                                                                                            |
| ----------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| **Manifest deployment**             | Module written, validated, wired                                                                 | ❌ `platforms/nixos/secrets/manifest.yaml` not created — needs `sops` on evo-x2; ❌ `just switch` not run |
| **serviceDefaults adoption**        | 9/30 modules (30%) use `serviceDefaults{}`                                                       | 13 modules still manually inline `Restart = "always"`                                                     |
| **lib/types.nix adoption**          | 4 helpers defined (`systemdServiceIdentity`, `servicePort`, etc.)                                | Only hermes.nix uses it — should be adopted by all services with port/user options                        |
| **Session 29 deployment**           | 8 commits pushed to master                                                                       | ❌ NOT deployed to evo-x2 — `just switch` never ran                                                       |
| **Pi 3 DNS failover**               | Full config in `platforms/nixos/rpi3/`, VRRP module in `modules/nixos/services/dns-failover.nix` | ❌ Hardware not provisioned; ❌ VRRP password hardcoded (should be in sops)                               |
| **Catppuccin theme centralization** | Universal theme across all apps                                                                  | 140 hardcoded hex colors across waybar/rofi/swaylock/yazi — not extracted to shared module                |
| **Audit framework**                 | `security-hardening.nix` has AppArmor + auditd config                                            | AppArmor disabled; auditd disabled due to NixOS 26.05 bug (#483085)                                       |
| **Private cloud planning**          | `docs/planning/private-cloud-planning/README.md` exists                                          | No implementation — contradicts existing Unbound+dnsblockd stack                                          |

---

## c) NOT STARTED ❌

| Item                                | Priority | Notes                                                                      |
| ----------------------------------- | -------- | -------------------------------------------------------------------------- |
| **Manifest sops secret file**       | P0       | `platforms/nixos/secrets/manifest.yaml` — must create before `just switch` |
| **Deploy sessions 29+30 to evo-x2** | P0       | `just switch` on evo-x2 — 2 sessions of undeployed changes                 |
| **Root disk cleanup**               | P0       | `nix-collect-garbage -d` + `docker system prune -af` — disk at 84%         |
| **Fix 3 failing services**          | P0       | caddy, comfyui, photomap — caddy down = all `*.home.lan` unreachable       |
| **Pi 3 hardware provisioning**      | P3       | DNS failover cluster backup node                                           |
| **SigNoz version update**           | P2       | signoz-src pinned at v0.117.1, collector at v0.144.2 — may be outdated     |
| **Docker image digest pinning**     | P2       | Twenty and Manifest use `latest` tags — not reproducible                   |
| **TODO_LIST.md**                    | P3       | No comprehensive TODO list exists                                          |
| **FEATURES.md**                     | P3       | No feature inventory exists                                                |
| **CONTEXT.md**                      | P3       | No project context file exists                                             |

---

## d) TOTALLY FUCKED UP 💥

| Issue                            | Severity    | Details                                                                                                                                                                                             |
| -------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **3 services failing on evo-x2** | 🔴 CRITICAL | caddy, comfyui, photomap — reported in session 28, **not investigated since**. caddy = ALL `*.home.lan` domains unreachable. comfyui = AI image generation down. photomap = photo exploration down. |
| **2 sessions undeployed**        | 🔴 CRITICAL | Sessions 29+30 changes sitting in git. Primary user module, service hardening, port fixes, dead code cleanup — none of it active on the machine.                                                    |
| **Root disk 84%**                | 🟡 HIGH     | No evidence of cleanup since session 28 reported it. Risk of disk full → service failures.                                                                                                          |
| **Manifest not deployable yet**  | 🟡 HIGH     | Module is written but `manifest.yaml` sops file doesn't exist — `just switch` will fail until secrets are created.                                                                                  |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Architecture & Code Quality

1. **serviceDefaults adoption** — 13/30 modules manually inline `Restart = "always"`. Every service should use `serviceDefaults{}`. This is the #1 DRY violation remaining.

2. **signoz.nix splitting** — At 746 lines, it's 2x larger than the next module. Split into: signoz.nix (core), signoz-clickhouse.nix, signoz-otel.nix, signoz-scrapers.nix.

3. **Catppuccin color centralization** — 140 hardcoded hex values across 4 desktop modules. Extract to `lib/catppuccin.nix` as an attrset, reference via variable.

4. **Docker image version pinning** — Twenty uses `latest`, Manifest uses `latest`. Pin to specific versions or digests for reproducibility.

5. **lib/types.nix adoption** — 4 well-designed helpers with only 1 consumer (hermes). Either adopt broadly across all services with port/user options, or inline into hermes and delete the lib.

6. **Commented-out imports cleanup** — `configuration.nix` lines 24-35 have 7 commented-out service imports from pre-flake-parts era. Dead noise.

7. **rpi3 VRRP password** — Hardcoded `"DNSClusterVRRP-evox2"` in `platforms/nixos/rpi3/default.nix`. Should be in sops.

### Operational

8. **Deployment discipline** — 2 sessions went by without deploying. Every session should end with `just switch` (or explicit documentation of why not).

9. **Disk monitoring** — The disk-monitor module exists but disk hit 84% without action. Should trigger automatic cleanup or at least stronger alerts.

10. **Service health verification** — After every `just switch`, should verify critical services are running (caddy, dns, immich, etc.). Currently manual.

### Documentation

11. **No TODO_LIST.md** — Project has no comprehensive TODO list. Sessions generate tasks but they're scattered across status reports.

12. **No FEATURES.md** — No feature inventory. Hard to know what's implemented vs planned.

13. **Private cloud planning is stale** — `docs/planning/private-cloud-planning/` describes Technitium DNS, but the project already uses Unbound+dnsblockd. Misleading.

14. **23 planning documents** — Many from Nov-Dec 2025, likely stale. Should be archived or updated.

---

## f) Top 25 Things We Should Get Done Next

| #  | Priority | Item                                                                                   | Effort  | Impact                                   |
| -- | -------- | -------------------------------------------------------------------------------------- | ------- | ---------------------------------------- |
| 1  | P0       | **Create `manifest.yaml` sops secrets** on evo-x2                                      | 5 min   | Unblocks Manifest deployment             |
| 2  | P0       | **Deploy to evo-x2** (`just switch`) — sessions 29+30                                  | 10 min  | Activates all recent work                |
| 3  | P0       | **Fix caddy service** — CRITICAL, all `*.home.lan` down                                | 15 min  | Restores all web services                |
| 4  | P0       | **Fix comfyui service**                                                                | 15 min  | Restores AI image generation             |
| 5  | P0       | **Fix photomap service**                                                               | 15 min  | Restores photo exploration               |
| 6  | P0       | **Disk cleanup** — `nix-collect-garbage -d && docker system prune -af`                 | 10 min  | Prevents disk-full crash                 |
| 7  | P1       | **Migrate 13 remaining modules to `serviceDefaults{}`**                                | 30 min  | Eliminates #1 DRY violation              |
| 8  | P1       | **Pin Docker image versions** — Twenty, Manifest                                       | 10 min  | Reproducible deployments                 |
| 9  | P1       | **Move rpi3 VRRP password to sops**                                                    | 10 min  | Security fix                             |
| 10 | P1       | **Clean up commented-out imports in configuration.nix**                                | 5 min   | Removes dead noise                       |
| 11 | P1       | **Verify all 32 services start after deploy**                                          | 15 min  | Confidence in system state               |
| 12 | P2       | **Extract Catppuccin colors to shared lib**                                            | 30 min  | 140 hardcoded values → 1 source of truth |
| 13 | P2       | **Split signoz.nix** (746 lines) into sub-modules                                      | 45 min  | Maintainability                          |
| 14 | P2       | **Adopt lib/types.nix across services** or inline into hermes                          | 20 min  | Reduce dead helper code                  |
| 15 | P2       | **Update SigNoz versions** — currently v0.117.1/v0.144.2                               | 30 min  | Security + features                      |
| 16 | P2       | **Add post-deploy health check to justfile** (`just health-deploy`)                    | 15 min  | Catches failures immediately             |
| 17 | P2       | **Create FEATURES.md** — full feature inventory from code                              | 30 min  | Project documentation                    |
| 18 | P2       | **Create TODO_LIST.md** — comprehensive, verified against code                         | 30 min  | Project tracking                         |
| 19 | P2       | **Archive stale planning docs** (23 files, many from 2025)                             | 10 min  | Reduce noise                             |
| 20 | P2       | **Delete stale private-cloud-planning/** or update                                     | 10 min  | Remove misleading docs                   |
| 21 | P3       | **Provision Pi 3 hardware** for DNS failover                                           | 2 hours | High-availability DNS                    |
| 22 | P3       | **Add auditd back** when NixOS 26.05 bug #483085 is fixed                              | 10 min  | Security hardening                       |
| 23 | P3       | **Enable AppArmor** in security-hardening.nix                                          | 30 min  | Mandatory access control                 |
| 24 | P3       | **Add Docker health checks** to Twenty module (currently missing)                      | 10 min  | Service reliability                      |
| 25 | P3       | **Consider building Manifest from source** (NestJS → Nix derivation) instead of Docker | 4 hours | Full Nix-native, no Docker dependency    |

---

## g) Top #1 Question I Cannot Answer 🔍

**Are caddy, comfyui, and photomap actually still failing on evo-x2 right now?**

The session 28 status report from earlier today (12:32) listed these as failing, but session 29 (17:54) didn't verify their state. It's possible they were fixed by session 29's port split-brain changes and just need a deploy. Or they could be genuinely broken for a different reason. I can't tell without running `systemctl status` on evo-x2. The answer completely changes the priority order — if caddy is already working after the port fix, P0 drops from 6 items to 3.

---

## Project Stats

| Metric                          | Value                          |
| ------------------------------- | ------------------------------ |
| Service modules                 | 32 (31 existing + manifest)    |
| Custom packages                 | 9                              |
| Shared programs                 | 14                             |
| Flake inputs                    | 30                             |
| NixOS modules enabled on evo-x2 | 30+                            |
| sops secret files               | 7 (manifest.yaml pending)      |
| Lines in largest module         | 746 (signoz.nix)               |
| Total module lines              | 5,372                          |
| `just test-fast`                | ✅ PASS                        |
| `nix fmt`                       | ✅ CLEAN                       |
| Deployed to evo-x2              | ❌ Sessions 29+30 NOT deployed |
| Root disk                       | 84% (needs cleanup)            |

---

## Files Changed This Session

| File                                            | Change                                |
| ----------------------------------------------- | ------------------------------------- |
| `modules/nixos/services/manifest.nix`           | **NEW** — 207-line flake-parts module |
| `flake.nix`                                     | +2 lines (import + nixosModule)       |
| `justfile`                                      | +21 lines (5 manifest commands)       |
| `modules/nixos/services/caddy.nix`              | +1 line (manifest vhost)              |
| `modules/nixos/services/homepage.nix`           | +6 lines (Manifest dashboard card)    |
| `modules/nixos/services/sops.nix`               | +7 lines (3 manifest secrets)         |
| `platforms/nixos/system/configuration.nix`      | +5 lines (manifest enable)            |
| `platforms/nixos/system/dns-blocker-config.nix` | +1 line (manifest DNS)                |
| **Total**                                       | **+249 lines, -2 lines**              |
