# SystemNix — Full Comprehensive Status Report

**Date:** 2026-05-05 23:54 CEST
**Session:** 34
**Machine:** evo-x2 (NixOS 26.05, x86_64-linux, AMD Ryzen AI Max+ 395, 128GB RAM)
**Git HEAD:** `e1168e9` | **Deployed:** gen 275 (commit `727886e`, May 4 17:30)
**Build status:** ✅ PASSES (41.6 GiB, with manifest.yaml fix)
**Uptime:** 1 day 1h27m | **Load:** 8.27, 7.81, 6.80

---

## System Health Overview

| Metric             | Value                                   | Status                           |
| ------------------ | --------------------------------------- | -------------------------------- |
| Root disk `/`      | 437G/512G (89% used, 57G free)          | 🔴 HIGH — trending toward full   |
| Data disk `/data`  | 607G/800G (76% used, 194G free)         | 🟡 OK but growing                |
| RAM                | 22G/62G used, 40G available             | ✅ Healthy                       |
| Swap               | 8G/41G used                             | ✅ Normal                        |
| Nix generations    | 26 profiles (deployed: gen 275)         | 🟡 Stale — needs GC              |
| Docker containers  | 5 running (Twenty stack + Whisper)      | ✅ Healthy                       |
| Undeployed commits | 2 ahead of deployed (727886e → e1168e9) | 🟡 Includes manifest secrets fix |
| Build validation   | `nh os build .` ✅ passes               | ✅ Ready to deploy               |

---

## a) FULLY DONE ✅

### Infrastructure & Architecture

| Item                                 | Details                                                                                         | Since         |
| ------------------------------------ | ----------------------------------------------------------------------------------------------- | ------------- |
| **Flake-parts modular architecture** | 31 service modules, all imported in flake.nix, zero orphans                                     | Session 29    |
| **Shared `lib/` helpers**            | `systemd.nix` (harden), `service-defaults.nix`, `types.nix`, `rocm.nix` — adopted by 8+ modules | Session 29-30 |
| **primaryUser module**               | Eliminated 15 hardcoded `"lars"` refs across the codebase                                       | Session 29    |
| **Port split-brain fix**             | All Caddy references use `config.services.<name>.port` — no hardcoded ports                     | Session 30    |
| **Justfile overhaul**                | 50+ recipes in 9 groups, DRY dns-diagnostics, trash instead of rm                               | Session 31    |
| **DNS blocker**                      | Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream                           | Long-standing |
| **SigNoz observability**             | Full OTel pipeline: node_exporter, cAdvisor, journald, ClickHouse                               | Long-standing |
| **Taskwarrior + TaskChampion**       | Cross-platform sync (NixOS, macOS, Android), deterministic client IDs                           | Session 28    |
| **EMEET PIXY webcam daemon**         | Auto face-tracking, noise cancellation, call detection, Waybar integration                      | Long-standing |
| **Niri session save/restore**        | 60s snapshots, workspace-aware restore, floating state, column widths, kitty state via /proc    | Session 28    |
| **Wallpaper self-healing**           | awww-daemon PartOf restart propagation, BrokenPipe crash recovery                               | Session 32    |
| **Wallpaper collection**             | 100+ wallpapers via `wallpapers-src` flake input                                                | Long-standing |
| **AI model centralization**          | `/data/ai/` tree with `services.ai-models.paths` for all AI modules                             | Session 29    |
| **sops-nix secrets**                 | age encryption via SSH host key, 7 secret files (including new manifest.yaml)                   | Ongoing       |
| **Catppuccin Mocha everywhere**      | Terminals, bars, login screen, all apps themed consistently                                     | Long-standing |
| **Cross-platform Home Manager**      | 14 program modules shared via `platforms/common/home-base.nix`                                  | Long-standing |
| **Crush config deployment**          | Flaked crush-config deployed via HM on both platforms                                           | Long-standing |
| **Dead code cleanup**                | Removed gatus module, nix-visualize input, lib/default.nix, unused imports                      | Session 29    |
| **Codebase size**                    | 104 .nix files, 13,492 lines, 7 shell scripts                                                   | Current       |

### Services (Running & Verified)

| Service                  | Status     | Notes                                                      |
| ------------------------ | ---------- | ---------------------------------------------------------- |
| **Caddy**                | ✅ Running | Reverse proxy with TLS via sops, forward auth via Authelia |
| **Gitea**                | ✅ Running | Git hosting + GitHub mirror (2 repos)                      |
| **Immich**               | ✅ Running | Photo/video management                                     |
| **Homepage**             | ✅ Running | Service dashboard                                          |
| **Authelia**             | ✅ Running | SSO/OIDC provider                                          |
| **TaskChampion**         | ✅ Running | Taskwarrior sync on port 10222                             |
| **Twenty CRM**           | ✅ Running | Docker stack (server, worker, db, redis — all healthy)     |
| **Whisper ASR**          | ✅ Running | Docker container on port 7860                              |
| **SigNoz**               | ✅ Running | Full observability pipeline                                |
| **Ollama**               | ✅ Running | LLM inference with ROCm GPU                                |
| **ComfyUI**              | ✅ Running | AI image generation with persistent GPU                    |
| **Hermes**               | ✅ Running | AI agent gateway (Discord bot, cron)                       |
| **Disk Monitor**         | ✅ Running | Btrfs usage monitoring + notifications                     |
| **File & Image Renamer** | ✅ Running | AI screenshot renaming watcher                             |

### Session 34 Work (This Session)

| Item                                   | Status                                                      |
| -------------------------------------- | ----------------------------------------------------------- |
| **manifest.yaml sops secrets created** | ✅ Created with random secrets, encrypted with host age key |
| **manifest.yaml staged in git**        | ✅ Force-added past gitignore                               |
| **`nh os build .` passes**             | ✅ 41.6 GiB system builds cleanly                           |

---

## b) PARTIALLY DONE 🟡

| Item                            | What's Done                                                                           | What's Missing                                                                                              |
| ------------------------------- | ------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Manifest LLM router**         | Module written, secrets created, build passes, Caddy/DNS/Homepage wired               | **Not deployed** — needs `nh os switch`. Service has never run. Image not pulled.                           |
| **Cybersecurity tools guide**   | Written (`docs/cybersecurity-tools-evo-x2.md`), 126 lines, tiered recommendations     | **Not committed** — staged but loose. Most tools installed but no automation (scans, reports).              |
| **Niri session PID resolution** | Research doc written, working bash PoC exists in scripts/                             | **Not committed** — doc updated but unstaged. Feature not implemented in the NixOS module yet.              |
| **Niri session migration docs** | Migration research documented (`docs/niri-session-migration.md`)                      | **Not committed** — staged. Decision pending on whether to accept terminal state loss.                      |
| **DNS failover cluster**        | Module written, Keepalived VRRP config done                                           | **Pi 3 hardware not provisioned** — cluster is code-only                                                    |
| **Security hardening**          | fail2ban, ClamAV, polkit rules, PAM limits, sysctl hardening all active               | **Duplicate fail2ban config** in both `configuration.nix` and `security-hardening.nix` — should consolidate |
| **GPU crash recovery**          | Defense-in-depth: SysRq REISUB, watchdogd (SP5100 TCO), amdgpu.gpu_recovery, earlyoom | **Whisper Docker image unpinned** (`:main` tag, 37.5 GB) — could break on update                            |
| **Darwin config**               | Shared overlays, Home Manager, program modules all working                            | **2 commits behind** in deployment, not tested recently                                                     |

---

## c) NOT STARTED ⬜

| #  | Item                                                                                                                              | Impact   | Effort  |
| -- | --------------------------------------------------------------------------------------------------------------------------------- | -------- | ------- |
| 1  | **Deploy Manifest** — `nh os switch` to activate the LLM router                                                                   | HIGH     | 5 min   |
| 2  | **Root disk cleanup** — GC old generations, prune Docker, clean caches                                                            | CRITICAL | 15 min  |
| 3  | **Fix `harden()` priority model** — `mkDefault` (prio 1000) silently overridden by NixOS modules (prio 100) for Ollama and others | HIGH     | 30 min  |
| 4  | **Consolidate fail2ban config** — remove duplicate from `configuration.nix`, keep `security-hardening.nix`                        | MEDIUM   | 10 min  |
| 5  | **Pin Whisper Docker image** — replace `:main` with SHA256 digest                                                                 | MEDIUM   | 5 min   |
| 6  | **Cybersecurity automation** — scheduled scans (nmap, lynis, aide), alerting                                                      | MEDIUM   | 2-3 hrs |
| 7  | **Raspberry Pi 3 provisioning** — build SD image, deploy DNS failover cluster                                                     | LOW      | 4+ hrs  |
| 8  | **Niri PID-to-command restore** — implement /proc walking in NixOS module                                                         | LOW      | 3-4 hrs |
| 9  | **Twenty CRM freelance projects setup** — guide written, not configured in UI                                                     | LOW      | 30 min  |
| 10 | **Monitor365 investigation** — disabled due to high RAM; evaluate if still needed                                                 | LOW      | 1 hr    |
| 11 | **Photomap investigation** — disabled due to podman config permission issue                                                       | LOW      | 2-3 hrs |

---

## d) TOTALLY FUCKED UP 💥

| # | Issue                                                                  | Severity    | Root Cause                                                                                                                                             | Impact                                                                             |
| - | ---------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| 1 | **Root disk 89% (57G free)**                                           | 🔴 CRITICAL | Whisper Docker image 37.5 GB + 26 Nix generations + stale builds                                                                                       | Machine becomes unusable at 100%. Docker writes fail, services crash, build fails. |
| 2 | **`harden()` silently ineffective for Ollama**                         | 🟡 HIGH     | `mkDefault` (prio 1000) is WEAKER than NixOS module defaults (prio 100). Security hardening is a no-op for services that set their own systemd config. | False sense of security — Ollama runs without hardening.                           |
| 3 | **Photomap disabled, health check fails every 15 min**                 | 🟡 HIGH     | Podman config permission issue + health check still references it                                                                                      | Noise in monitoring, missed real alerts.                                           |
| 4 | **Stale `manifest-4QmxKO.yaml` in repo root**                          | 🟡 LOW      | Leftover from sops creation attempt — contains plaintext placeholders                                                                                  | Should be deleted immediately (security risk, though values are placeholders).     |
| 5 | **Unstaged changes to `niri-session-manager-issue-pid-resolution.md`** | 🟡 LOW      | Modified but not staged — shows as dirty in `git status`                                                                                               | Should be committed or discarded.                                                  |
| 6 | **Commented-out imports in `configuration.nix`**                       | 🟡 LOW      | 8 lines of dead commented-out service imports from pre-flake-parts migration                                                                           | Confusing noise. Should be removed.                                                |
| 7 | **`docker-compose` V1 CLI in manifest.nix**                            | 🟡 LOW      | Uses deprecated `docker-compose` binary instead of `docker compose` V2 plugin                                                                          | Will break when V1 is removed from nixpkgs.                                        |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Architecture & Code Quality

1. **Fix `harden()` priority model** — Switch from `mkDefault` to `mkForce` (prio 50) or a custom priority (prio 900) so hardening is always applied unless explicitly overridden. This is a systemic issue affecting all services using `harden{}`.

2. **Consolidate duplicate fail2ban config** — Two modules configure the same service with overlapping settings. Security-hardening module should be the single source of truth.

3. **Remove dead code** — Commented-out imports in `configuration.nix`, stale temp files in repo root.

4. **Pin Docker image references** — Whisper uses `:main` tag (37.5 GB, unpinned). All Docker images should use SHA256 digests for reproducibility.

5. **Migrate `docker-compose` V1 → V2** — Manifest module uses deprecated `docker-compose` binary. Switch to `docker compose` V2 plugin syntax.

6. **NixOS tests** — Zero automated NixOS VM tests exist. Build passes but service integration isn't validated automatically.

### Operations & Reliability

7. **Root disk monitoring threshold** — 89% is critical. Add a 90% alert via disk-monitor + automatic GC trigger.

8. **Generation cleanup** — 26 generations, some dating back weeks. Add `nix-collect-garbage` to a weekly timer.

9. **Docker image cleanup** — Whisper alone is 37.5 GB. Add `docker image prune` to the clean recipe.

10. **Undeployed commit tracking** — 2 commits ahead of deployed state. Consider adding a `just check` step that warns about undeployed changes.

### Security

11. **Cybersecurity tool automation** — Tools are installed but no scheduled scans or alerting. Add nmap/lynis/aide cron jobs.

12. **Delete `manifest-4QmxKO.yaml`** — Plaintext secrets (placeholders) in repo root is a bad precedent.

---

## f) Top 25 Things We Should Get Done Next

**Pareto-sorted by impact:**

| #  | Priority | Task                                                                                            | Impact                                                | Effort  | Category |
| -- | -------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------- | -------- |
| 1  | 🔴 P0    | **Root disk cleanup** — `sudo nix-collect-garbage -d`, `docker system prune -af`, clean /tmp    | Frees 20-40 GB, prevents system lockup                | 15 min  | Ops      |
| 2  | 🔴 P0    | **Deploy current build** — `nh os switch` to activate Manifest + all session 29-34 work         | 2 commits deployed, Manifest live                     | 10 min  | Ops      |
| 3  | 🔴 P0    | **Delete `manifest-4QmxKO.yaml`** from repo root                                                | Removes plaintext secret file                         | 1 min   | Security |
| 4  | 🟡 P1    | **Fix `harden()` priority model** — switch from `mkDefault` to proper priority                  | Fixes silent security gap for Ollama + other services | 30 min  | Arch     |
| 5  | 🟡 P1    | **Consolidate fail2ban config** — remove from `configuration.nix`                               | Single source of truth for security                   | 10 min  | Code     |
| 6  | 🟡 P1    | **Pin Whisper Docker image** to SHA256 digest                                                   | Reproducibility, prevents surprise breaks             | 5 min   | Code     |
| 7  | 🟡 P1    | **Clean commented-out imports** in `configuration.nix`                                          | Removes dead noise                                    | 5 min   | Code     |
| 8  | 🟡 P1    | **Commit staged docs** — cybersecurity guide, niri session docs, twenty guide                   | Preserves research work                               | 5 min   | Docs     |
| 9  | 🟡 P1    | **Stage or discard** unstaged `niri-session-manager-issue-pid-resolution.md` changes            | Clean working tree                                    | 1 min   | Git      |
| 10 | 🟡 P1    | **Migrate manifest.nix** from `docker-compose` V1 to `docker compose` V2                        | Future-proofing                                       | 20 min  | Code     |
| 11 | 🟡 P1    | **Add weekly GC timer** — automatic `nix-collect-garbage`                                       | Prevents disk creep                                   | 15 min  | Ops      |
| 12 | 🟡 P1    | **Fix photomap or remove health check** — either fix podman perms or remove from health checker | Stops false alerts                                    | 30 min  | Ops      |
| 13 | 🟡 P2    | **Set up Manifest in Homepage dashboard** — add health check URL                                | Full integration                                      | 5 min   | Config   |
| 14 | 🟡 P2    | **Configure Hermes → Manifest** — route LLM calls through Manifest for cost optimization        | Actual cost savings (up to 70%)                       | 30 min  | Config   |
| 15 | 🟡 P2    | **Configure Crush → Manifest** — route AI calls through Manifest                                | Cost optimization for daily Crush usage               | 30 min  | Config   |
| 16 | 🟡 P2    | **Add disk-monitor 90% alert** + auto-GC trigger                                                | Prevents future disk emergencies                      | 20 min  | Ops      |
| 17 | 🟢 P2    | **Twenty CRM freelance projects** — set up in UI per the guide                                  | Better project tracking                               | 30 min  | Config   |
| 18 | 🟢 P2    | **Cybersecurity automation** — scheduled nmap/lynis/aide scans with reporting                   | Proactive security posture                            | 2-3 hrs | Security |
| 19 | 🟢 P2    | **Niri PID-to-command restore** — implement /proc walking in NixOS module                       | Full session restore including terminal commands      | 3-4 hrs | Feature  |
| 20 | 🟢 P3    | **Write NixOS VM tests** — basic service integration tests                                      | Automated validation                                  | 4+ hrs  | Quality  |
| 21 | 🟢 P3    | **Investigate Monitor365** — is it still needed? Fix RAM issue or remove                        | Reduces disabled services                             | 1 hr    | Ops      |
| 22 | 🟢 P3    | **Investigate Photomap** — fix podman config permission issue                                   | Restores photo exploration                            | 2-3 hrs | Feature  |
| 23 | 🟢 P3    | **Raspberry Pi 3 provisioning** — build SD image, deploy DNS failover cluster                   | HA DNS for home network                               | 4+ hrs  | Infra    |
| 24 | 🟢 P3    | **Audit all Docker images** — list sizes, pin digests, prune unused                             | Disk optimization                                     | 1 hr    | Ops      |
| 25 | 🟢 P3    | **Push undeployed commits** to origin/master                                                    | Backup + sync                                         | 1 min   | Git      |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**What is the actual priority for Manifest — should we deploy it NOW and route Hermes/Crush through it immediately, or is it a "nice to have" that can wait?**

The module is ready, secrets are generated, build passes, but:

- Manifest has never run on this machine
- We don't know if the Docker image works on AMD ROCm (it's Node.js, likely fine)
- Configuring Hermes + Crush to route through it requires understanding their API call patterns
- The claimed 70% cost savings is theoretical — we'd need baseline metrics first

**Is this a P0 "deploy immediately" or a P3 "when we get to it"?**

---

## Staged Changes (Ready to Commit)

| File                                                  | Change                                                  |
| ----------------------------------------------------- | ------------------------------------------------------- |
| `docs/cybersecurity-tools-evo-x2.md`                  | New — security tools guide (126 lines)                  |
| `docs/niri-session-manager-issue-pid-resolution.md`   | New — PID resolution feature research (120 lines)       |
| `docs/niri-session-migration.md`                      | New — session migration research (235 lines)            |
| `manifest-4QmxKO.yaml`                                | **TO DELETE** — plaintext secret placeholders           |
| `modules/nixos/services/twenty-FREELANCE-PROJECTS.md` | New — freelance project guide for Twenty CRM (39 lines) |
| `platforms/nixos/secrets/manifest.yaml`               | New — sops-encrypted Manifest secrets                   |
| `platforms/nixos/system/boot.nix`                     | **No actual diff** — phantom staging?                   |

## Unstaged Changes

| File                                                | Change                                               |
| --------------------------------------------------- | ---------------------------------------------------- |
| `docs/niri-session-manager-issue-pid-resolution.md` | Trimmed from 120 lines to 24 lines (summary version) |

---

## Summary Stats

| Metric                | Value                                         |
| --------------------- | --------------------------------------------- |
| Nix files             | 104                                           |
| Nix lines             | 13,492                                        |
| Shell scripts         | 7                                             |
| Service modules       | 31 (26 enabled, 2 disabled, 3 infrastructure) |
| Flake inputs          | 34                                            |
| Docker containers     | 5 running (Twenty stack + Whisper)            |
| Commits today (May 5) | ~40+ across 8 sessions                        |
| Undeployed commits    | 2 (HEAD → deployed)                           |
| Root disk             | 89% ⚠️                                         |
| Build status          | ✅ PASSING                                    |
