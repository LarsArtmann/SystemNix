# Session 32 — Full System Status + Photomap Disabled + Manifest Not Deployed

**Date:** 2026-05-05 21:34
**Session:** 32
**Branch:** master (clean)
**Previous:** Session 31 — justfile overhaul self-review

---

## Executive Summary

Tree is clean. 13 commits since session 29, spanning: Manifest LLM router integration, justfile radical rewrite (-65%), photomap disable, and doc/reference hygiene. **Nothing has been deployed to evo-x2 in 4+ sessions.** The machine has 2 failing systemd units (podman-photomap which we just disabled, and service-health-check which is a cascading failure), root disk at 88%, and Manifest is blocked on a missing sops secrets file.

---

## a) FULLY DONE ✅

### Sessions 29–31 Work (All Committed, NOT Deployed)

| Item                                                                                | Commit     | Status       |
| ----------------------------------------------------------------------------------- | ---------- | ------------ |
| **primaryUser module** — eliminated 15 hardcoded `"lars"` refs                      | `abb7739`  | ✅ Committed |
| **Dead code removal** — gatus.nix (406 lines), nix-visualize input, lib/default.nix | `8cc002b`  | ✅ Committed |
| **serviceDefaults migration** — twenty, gitea-repos, ai-stack                       | `033e560`  | ✅ Committed |
| **Port split-brain fix** — caddy references service config ports                    | `d039c9e`  | ✅ Committed |
| **Service hardening** — 16/18 applicable services use `harden()` (89%)              | `ade530b`+ | ✅ Committed |
| **Manifest NixOS module** (207 lines) — Docker Compose + sops + Caddy + DNS         | `cb2df5d`  | ✅ Committed |
| **Justfile radical rewrite** — 1658→582 lines, 143→59 recipes                       | `9b756d7`+ | ✅ Committed |
| **Photomap disable** — podman config permission issue                               | `894d9af`  | ✅ Committed |
| **Doc hygiene** — README, AGENTS.md, contributing, health-check references          | `63fe2a8`+ | ✅ Committed |

### Long-Standing Production Systems

| System                                                               | Status     |
| -------------------------------------------------------------------- | ---------- |
| **DNS blocker** — Unbound + dnsblockd, 2.5M+ domains                 | ✅ Running |
| **SigNoz observability** — ClickHouse, OTel, node_exporter, cAdvisor | ✅ Running |
| **Niri compositor** — session save/restore, crash recovery           | ✅ Running |
| **Waybar** — Catppuccin Mocha themed                                 | ✅ Running |
| **EMEET PIXY webcam** — auto-tracking, audio modes, Waybar           | ✅ Running |
| **Hermes AI gateway** — Discord bot, cron, multi-provider            | ✅ Running |
| **AI model storage** — centralized `/data/ai/`                       | ✅ Running |
| **Twenty CRM** — Docker stack (server + worker + postgres + redis)   | ✅ Running |
| **Whisper ASR** — speech-to-text                                     | ✅ Running |
| **Taskwarrior + TaskChampion** — cross-platform sync                 | ✅ Running |
| **Homebrew** — macOS declarative management                          | ✅ Running |
| **Sops-nix** — secrets via age + SSH host key                        | ✅ Running |
| **32 flake-parts service modules** — all evaluated                   | ✅ Clean   |

---

## b) PARTIALLY DONE ⚠️

| Item                                | What's Done                                      | What's Missing                                                                                                  |
| ----------------------------------- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| **Manifest deployment**             | Module written, validated, wired, all hooks pass | ❌ `platforms/nixos/secrets/manifest.yaml` doesn't exist — must create with sops on evo-x2 before `just switch` |
| **serviceDefaults adoption**        | 9/30 modules (30%)                               | 13 modules still manually inline `Restart = "always"`                                                           |
| **lib/types.nix adoption**          | 4 helpers defined                                | Only hermes.nix uses it — should adopt broadly or inline                                                        |
| **Catppuccin theme centralization** | Universal theme across all apps                  | 140 hardcoded hex colors across waybar/rofi/swaylock/yazi                                                       |
| **Pi 3 DNS failover**               | Full config, VRRP module                         | ❌ Hardware not provisioned; VRRP password hardcoded                                                            |
| **Audit framework**                 | security-hardening.nix has config                | AppArmor disabled; auditd disabled (NixOS 26.05 bug #483085)                                                    |
| **Docker image pinning**            | All images specified                             | Twenty and Manifest use `latest` tag — not reproducible                                                         |
| **Justfile docs cleanup**           | Core references updated                          | 21 files with ~118 stale recipe references in docs/                                                             |

---

## c) NOT STARTED ❌

| Item                                  | Priority | Notes                                                                  |
| ------------------------------------- | -------- | ---------------------------------------------------------------------- |
| **Create manifest.yaml sops secrets** | P0       | Blocks Manifest deployment entirely                                    |
| **Deploy to evo-x2** (`just switch`)  | P0       | 4+ sessions of undeployed changes                                      |
| **Root disk cleanup**                 | P0       | 88% — 61G free, needs `nix-collect-garbage -d` + `docker system prune` |
| **Fix service-health-check.service**  | P1       | Failing on every run (15min interval), cascading from photomap         |
| **SigNoz version update**             | P2       | Pinned at v0.117.1/v0.144.2 — may be outdated                          |
| **Pi 3 hardware provisioning**        | P3       | DNS failover cluster backup node                                       |
| **TODO_LIST.md**                      | P3       | No comprehensive TODO list exists                                      |
| **FEATURES.md**                       | P3       | No feature inventory exists                                            |
| **Archive stale docs**                | P3       | 23 planning files from 2025, 21 files with stale recipe refs           |

---

## d) TOTALLY FUCKED UP 💥

| Issue                                 | Severity    | Details                                                                                                                                                                                  |
| ------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **4+ sessions not deployed**          | 🔴 CRITICAL | Sessions 29–32 (primaryUser, hardening, port fixes, Manifest, photomap disable, justfile rewrite) — all in git, NONE active on evo-x2. The machine is running session 28's config.       |
| **Root disk 88% (worsening)**         | 🔴 CRITICAL | Was 84% in session 28 (6 hours ago). Now 88%. Trending toward disk-full. `/nix/store` alone is 82G. No cleanup performed despite multiple reports.                                       |
| **Manifest blocked on sops**          | 🟡 HIGH     | Module is ready but `manifest.yaml` doesn't exist. `just switch` will fail on the sops secrets reference.                                                                                |
| **service-health-check failing**      | 🟡 HIGH     | Runs every 15 minutes, fails every time, triggers OnFailure notification cascade. Root cause: checks photomap which is broken. Will self-fix after deploy (photomap disabled in config). |
| **21 files with stale justfile refs** | 🟢 LOW      | Docs reference removed recipes. Non-blocking but noisy.                                                                                                                                  |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Critical Process

1. **Deploy after every session** — 4 sessions without deploy is unacceptable. Every session should end with `just switch` (or explicit documented reason why not). We've been writing code that nobody is running.

2. **Act on disk warnings** — Disk went from 84% → 88% in 6 hours across 4 status reports that all flagged it. Nobody ran the cleanup commands. This will cause a real outage.

3. **Verify after commit** — Pre-commit hooks pass but that doesn't mean the machine is healthy. Add a post-deploy verification step.

### Code Quality

4. **serviceDefaults adoption** — 13/30 modules still manually inline `Restart = "always"`. This is the #1 remaining DRY violation.

5. **signoz.nix splitting** — 746 lines, 2x larger than next module. Split into sub-modules.

6. **Docker image pinning** — `latest` tags are not reproducible. Pin to versions or digests.

7. **Catppuccin colors** — 140 hardcoded hex values → extract to `lib/catppuccin.nix`.

8. **lib/types.nix** — 4 helpers, 1 consumer. Adopt broadly or inline and delete.

9. **Stale docs cleanup** — Archive 2025 planning files, fix 21 files with stale justfile references.

---

## f) Top 25 Things We Should Get Done Next

| #   | Priority | Item                                                                             | Effort  | Impact                       |
| --- | -------- | -------------------------------------------------------------------------------- | ------- | ---------------------------- |
| 1   | P0       | **Create `manifest.yaml` sops secrets** on evo-x2                                | 5 min   | Unblocks Manifest            |
| 2   | P0       | **Deploy to evo-x2** (`just switch`) — 4 sessions of changes                     | 10 min  | Activates ALL recent work    |
| 3   | P0       | **Root disk cleanup** — `nix-collect-garbage -d && docker system prune -af`      | 10 min  | Prevents disk-full crash     |
| 4   | P1       | **Fix service-health-check** — verify it passes after deploy (photomap disabled) | 5 min   | Stops notification spam      |
| 5   | P1       | **Verify all services healthy after deploy**                                     | 10 min  | Confidence in system state   |
| 6   | P1       | **Migrate 13 remaining modules to `serviceDefaults{}`**                          | 30 min  | Eliminates #1 DRY violation  |
| 7   | P1       | **Pin Docker image versions** — Twenty, Manifest                                 | 10 min  | Reproducible deploys         |
| 8   | P1       | **Move rpi3 VRRP password to sops**                                              | 10 min  | Security fix                 |
| 9   | P1       | **Clean up commented-out imports in configuration.nix**                          | 5 min   | Removes dead noise           |
| 10  | P1       | **Fix 21 files with stale justfile references** in docs/                         | 30 min  | Doc accuracy                 |
| 11  | P2       | **Extract Catppuccin colors to shared lib**                                      | 30 min  | 140 values → 1 source        |
| 12  | P2       | **Split signoz.nix** (746 lines) into sub-modules                                | 45 min  | Maintainability              |
| 13  | P2       | **Adopt lib/types.nix across services** or inline into hermes                    | 20 min  | Reduce dead helper code      |
| 14  | P2       | **Update SigNoz versions** — currently v0.117.1/v0.144.2                         | 30 min  | Security + features          |
| 15  | P2       | **Create FEATURES.md** — full feature inventory from code                        | 30 min  | Project documentation        |
| 16  | P2       | **Create TODO_LIST.md** — comprehensive, verified against code                   | 30 min  | Project tracking             |
| 17  | P2       | **Archive 2025 planning docs** (23 files)                                        | 10 min  | Reduce noise in docs/        |
| 18  | P2       | **Delete stale private-cloud-planning/** or update                               | 10 min  | Misleading docs              |
| 19  | P2       | **Add post-deploy health check to justfile** (`just deploy-check`)               | 15 min  | Catches failures immediately |
| 20  | P2       | **Add Docker health checks to Twenty module**                                    | 10 min  | Service reliability          |
| 21  | P3       | **Provision Pi 3 hardware** for DNS failover                                     | 2 hours | High-availability DNS        |
| 22  | P3       | **Enable AppArmor** in security-hardening.nix                                    | 30 min  | Mandatory access control     |
| 23  | P3       | **Add auditd back** when NixOS 26.05 bug #483085 is fixed                        | 10 min  | Security hardening           |
| 24  | P3       | **Consider building Manifest from source** (NestJS → Nix derivation)             | 4 hours | Full Nix-native              |
| 25  | P3       | **Archive session-artifact status reports** — keep only 3 most recent            | 10 min  | Clean docs/status/           |

---

## g) Top #1 Question I Cannot Answer 🔍

**Should we deploy right now given root disk is at 88%?**

Deploying (`just switch`) will create a new generation in `/nix/store`, potentially adding 1-2GB. With 61G free that's fine. But if we deploy AND add Manifest's Docker images (Manifest app ~200MB + Postgres ~80MB), we're still safe. The real question is: should we clean first, then deploy? Or deploy first, then clean? Both work, but cleaning first gives us more headroom. I'd recommend: **clean first** (`nix-collect-garbage -d`), **then deploy** — but this is your call.

---

## Project Stats

| Metric               | Value                                           |
| -------------------- | ----------------------------------------------- |
| Service modules      | 31 (photomap disabled)                          |
| Custom packages      | 9                                               |
| Shared programs      | 14                                              |
| Flake inputs         | 30                                              |
| Total .nix files     | ~97                                             |
| Justfile recipes     | 59 (down from 143)                              |
| Justfile lines       | 582 (down from 1658)                            |
| sops secret files    | 7 (manifest.yaml MISSING)                       |
| Largest module       | signoz.nix (746 lines)                          |
| Total module lines   | 5,370                                           |
| `just test-fast`     | ✅ PASS                                         |
| `nix fmt`            | ✅ CLEAN                                        |
| Pre-commit hooks     | ✅ ALL PASS                                     |
| Deployed to evo-x2   | ❌ 4 sessions behind (session 28 config active) |
| Root disk            | 88% (61G free) — WORSENING                      |
| Data disk            | 74% (209G free)                                 |
| Docker containers    | 5 running (Twenty stack + whisper-asr)          |
| Failed systemd units | 2 (podman-photomap, service-health-check)       |
| Memory               | 48G/62G (77%)                                   |

---

## Timeline: Today's Sessions

| Time  | Session | Key Work                                       |
| ----- | ------- | ---------------------------------------------- |
| 12:27 | 28      | Build fix chain, deploy, reliability hardening |
| 12:30 | 28b     | Waybar health, Gitea, Waybar recovery          |
| 12:32 | —       | Comprehensive full system status               |
| 17:54 | 29      | Brutal self-review + architecture cleanup      |
| 20:37 | 30      | Manifest LLM router integration                |
| 21:19 | 31      | Justfile overhaul self-review                  |
| 21:34 | 32      | This report — photomap disabled, full status   |
