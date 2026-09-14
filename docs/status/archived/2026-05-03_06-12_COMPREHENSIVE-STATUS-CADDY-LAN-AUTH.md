# SystemNix — Comprehensive Status Report

**Date:** 2026-05-03 06:12 CEST
**Uptime:** 1 day 20h 27m
**NixOS:** 26.05.20260423.01fbdee (Yarara)
**Host:** evo-x2 (AMD Ryzen AI Max+ 395, 128GB RAM, x86_64-linux)

---

## Executive Summary

The system is **mostly healthy** with 45 systemd services running, 0 failed. However there are notable issues: disk usage is high (89% root, 86% /data), the Whisper ASR container is crash-looping, several user services are dead despite being enabled, and the uncommitted Caddy LAN auth bypass needs deployment.

---

## a) FULLY DONE ✅

### Core Infrastructure

- **Cross-platform Nix flake** — Darwin + NixOS, 80% shared via `platforms/common/`
- **flake-parts modular architecture** — 29 service modules
- **Shared overlays** — NUR, aw-watcher, todo-list-ai, golangci-lint-auto-configure, mr-sync
- **Linux-only overlays** — openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer
- **Shared Home Manager config** — `sharedHomeManagerConfig` pattern
- **Formatter** — treefmt + alejandra
- **Flake checks** — statix, deadnix, eval

### Running System Services (46 active, 0 failed)

| Service                   | Status     | Uptime | Notes                                                  |
| ------------------------- | ---------- | ------ | ------------------------------------------------------ |
| Docker                    | ✅ running | 1d20h  | 6 containers (5 healthy, 1 crash-looping)              |
| Caddy                     | ✅ running | 1d20h  | 10 virtual hosts, TLS via sops                         |
| Authelia                  | ✅ running | 1d20h  | SSO/IdP, TOTP + WebAuthn 2FA                           |
| Gitea                     | ✅ running | 1d20h  | SQLite, LFS, Actions runner                            |
| Homepage Dashboard        | ✅ running | 1d20h  | Catppuccin Mocha theme                                 |
| Immich (server + ML)      | ✅ running | 1d20h  | PostgreSQL + Redis + GPU ML                            |
| SigNoz (full stack)       | ✅ running | 1d20h  | ClickHouse + OTel Collector + node_exporter + cadvisor |
| TaskChampion              | ✅ running | 1d20h  | Port 10222, TLS                                        |
| Twenty CRM (4 containers) | ✅ running | 38h    | All healthy — server, worker, db, redis                |
| Hermes AI gateway         | ✅ running | 1d20h  | Discord bot, cron                                      |
| Minecraft server          | ✅ running | 1d20h  | JDK 25, ZGC                                            |
| Ollama                    | ✅ running | 1d20h  | ROCm GPU                                               |
| ComfyUI                   | ✅ running | 1d20h  | ROCm GPU, image generation                             |
| ClickHouse                | ✅ running | 1d20h  | SigNoz storage                                         |
| PostgreSQL                | ✅ running | 1d20h  | Immich backend                                         |
| Redis (immich)            | ✅ running | 1d20h  |                                                        |
| Unbound                   | ✅ running | 1d20h  | DNS resolver, 2.5M+ domains blocked                    |
| dnsblockd                 | ✅ running | 1d20h  | DNS block page server                                  |
| LiveKit                   | ✅ running | 1d20h  | SFU server                                             |
| Keepalived                | ✅ running | 1d20h  | VRRP                                                   |
| cAdvisor                  | ✅ running | 1d20h  | Container metrics                                      |
| ClamAV                    | ✅ running | 1d20h  |                                                        |
| fail2ban                  | ✅ running | 1d20h  |                                                        |
| SSH                       | ✅ running | 1d20h  |                                                        |
| smartd                    | ✅ running | 1d20h  |                                                        |

### Running User Services (19 active, 0 failed)

| Service                 | Status     | Notes                                         |
| ----------------------- | ---------- | --------------------------------------------- |
| Niri                    | ✅ running | Wayland compositor                            |
| PipeWire + WirePlumber  | ✅ running | Audio stack                                   |
| Dunst                   | ✅ running | Notifications                                 |
| EMEET PIXY daemon       | ✅ running | Webcam auto-activation                        |
| ActivityWatch (3 units) | ✅ running | Server + window watcher + utilization watcher |
| llama.cpp vision model  | ✅ running | Gemma 4 26B                                   |
| gamemoded               | ✅ running | Feral gamemode                                |
| niri-flake-polkit       | ✅ running | PolicyKit agent                               |
| xdg-desktop-portal      | ✅ running |                                               |
| gcr-ssh-agent           | ✅ running |                                               |
| niri-session-save timer | ✅ running | 60s interval                                  |

### Recent Commits (last 30)

- Caddy LAN auth bypass for protected vhosts
- Authelia bcrypt→argon2id migration
- Hermes user/group fixes + state migration
- dnsblockd extracted to external flake input
- Voice agents Docker image pinned to SHA256
- FEATURES.md comprehensive audit
- Dead code cleanup
- Flake.lock updates (monitor365, NUR)

### CI/CD

- **GitHub Actions:** flake-update (weekly), go-test (dnsblockd-processor), nix-check (eval-only)
- **Pre-commit hooks:** Nix validation, shellcheck, markdownlint, gitleaks, large files
- **Formatter:** treefmt + alejandra

### Cross-Platform Programs

- Fish/Zsh/Bash shells with shared aliases (ADR-002)
- Starship prompt (performance-tuned)
- Git (GPG signing, SSH multiplexing)
- Tmux (Resurrect + yank)
- Fzf (rg-powered, cross-shell)
- Taskwarrior 3 (TaskChampion sync)
- KeePassXC (browser integration)
- Catppuccin Mocha (global theme)

### Desktop (NixOS)

- Niri with 80+ keybindings, 5 workspaces, session save/restore
- Rofi (grid layout, calc, emoji)
- Waybar (15+ modules)
- Swaylock + Wlogout + Swayidle
- Yazi file manager, Zellij multiplexer
- Kitty + Foot terminals
- Cliphist clipboard manager

### Hardware Support

- AMD GPU (Strix Halo) — amdgpu, RADV, ROCm, VA-API
- AMD NPU (XDNA) — XRT driver
- Realtek 2.5G Ethernet (r8125)
- MediaTek WiFi/BT (mt7925e)
- EMEET PIXY webcam (full daemon)
- Bluetooth (A2DP with Google Nest Audio)
- BTRFS root + data (zstd compression, snapshots)
- ZRAM swap (50% of 128GB)

### DNS Stack

- Unbound resolver with DNS-over-TLS
- dnsblockd (930-line Go app) — 10 categories, 2.5M+ domains
- Temp-allow API, false positive reporting, Prometheus metrics
- Stats API, Firefox policy integration

---

## b) PARTIALLY DONE ⚠️

### 1. Caddy LAN Auth Bypass (UNCOMMITTED)

- **Status:** Code written but not deployed (`just switch` not run)
- **File:** `modules/nixos/services/caddy.nix` — `protectedVHost` now skips forward_auth for 127.0.0.1/8 and 192.168.1.0/24
- **Impact:** All protected services (Immich, Gitea, CRM, etc.) will be accessible without Authelia from LAN

### 2. Whisper ASR (Crash-Looping)

- **Status:** Container restart-looping — `python3: can't open file '/app/python'`
- **Root cause:** Image entrypoint is `python3`, compose command string `python -m insanely_fast_whisper_rocm.api ...` is being passed as args to `python3`, so it tries to open `/app/python` as a file
- **Fix needed:** Change compose `command` to list format: `["-m", "insanely_fast_whisper_rocm.api", "--host", "0.0.0.0", "--port", "8000"]` (drop the `python` prefix since entrypoint already provides it)
- **Image:** `beecave/insanely-fast-whisper-rocm` — 20 months old (2024-08-28), 37.5GB, pinned to SHA256

### 3. Twenty CRM — FEATURES.md Incorrect

- **Status:** FEATURES.md says 🔧 (disabled) but service is fully active and healthy (38h uptime, all 4 containers healthy)
- **Fix needed:** Update FEATURES.md status to ✅

### 4. Voice Agents Service

- **Status:** `voice-agents.service` not found as systemd unit — Whisper container runs directly via Docker restart policy, not managed by systemd
- **Issue:** The compose file manages the container, but the systemd service isn't wired

### 5. DNS Failover Cluster

- **Status:** Keepalived running on evo-x2, but Pi 3 not provisioned — single-node cluster with no failover partner

### 6. Monitor365

- **Status:** Service not found — neither system nor user unit. Package is installed but service not running

### 7. File & Image Renamer

- **Status:** User unit enabled but inactive (dead) — not running despite being enabled

### 8. AWWW Wallpaper Daemon

- **Status:** User unit enabled but inactive (dead) — has config error: `Unknown key 'StartLimitIntervalSec' in section [Service]`
- **Note:** `StartLimitIntervalSec` belongs in `[Unit]`, not `[Service]`

---

## c) NOT STARTED 📋

### Major

1. **Raspberry Pi 3 provisioning** — Hardware not available, entire DNS failover cluster blocked
2. **AppArmor** — Commented out in security-hardening module
3. **Auditd** — Disabled due to NixOS 26.05 bug #483085
4. **DNS-over-QUIC** — Overlay disabled (40+ min builds)
5. **Unsloth Studio** — Disabled by default, complex PyTorch ROCm setup
6. **Multi-WM (Sway)** — Disabled backup compositor, may have bitrot
7. **PhotoMap AI** — Disabled in config, pinned to old SHA256

### Missing Scripts (referenced in justfile)

8. `benchmark-system.sh` — Referenced by `just benchmark`
9. `performance-monitor.sh` — Referenced by `just perf`
10. `shell-context-detector.sh` — Referenced by `just context`
11. `storage-cleanup.sh` — Referenced by `just clean`/`clean-storage`

### Features from Status Reports (never started)

12. Pin Docker images by digest (whisper, twenty, photomap) — whisper is pinned, twenty uses `:latest`
13. Papermark integration — researched, never started
14. Backup verification for twenty DB

---

## d) TOTALLY FUCKED UP 💥

### 1. Whisper ASR — Crash Loop (CRITICAL)

- **Container:** `whisper-asr` — continuously restarting with `python3: can't open file '/app/python'`
- **Root cause:** Compose `command` string includes `python` prefix, but image entrypoint is already `python3`. Docker runs `python3 python -m ...` → tries to open `/app/python` as script file
- **Impact:** Voice agents pipeline completely non-functional
- **Fix:** Remove `python` from command in `voice-agents.nix` compose file, use list syntax

### 2. AWWW Wallpaper Daemon — Config Error

- **Error:** `Unknown key 'StartLimitIntervalSec' in section [Service]`
- **Impact:** Wallpaper daemon won't start on boot
- **Fix:** Move `StartLimitIntervalSec` from `[Service]` to `[Unit]` section, or remove it

### 3. User Services Dead Despite Enabled

- `awww-daemon.service` — enabled but inactive (config error)
- `file-and-image-renamer.service` — enabled but inactive (dead)
- `monitor365` — not even installed as a service unit
- `crush-update-providers.timer` — inactive (user timer)

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Urgent

1. **Fix Whisper ASR** — Remove `python` prefix from compose command, use list syntax
2. **Fix AWWW daemon** — Correct systemd unit section for `StartLimitIntervalSec`
3. **Investigate dead user services** — Why are enabled services not running after reboot?
4. **Deploy Caddy LAN bypass** — `just switch` needed to activate

### High Priority

5. **Disk space** — Root 89% (61G free), /data 86% (116G free) — need cleanup strategy
6. **Swap usage** — 15GB of 41GB swap used — indicates memory pressure despite 128GB RAM
7. **Twenty CRM image** — Using `:latest` tag (fragile after v0.16.2 disappeared from Hub)
8. **Monitor365** — Installed but no running service — either enable or remove
9. **FEATURES.md accuracy** — Twenty CRM marked 🔧 but is actually ✅ active

### Medium Priority

10. **Whisper image age** — 20 months old (2024-08-28), 37.5GB — check for updates
11. **User service management** — Several enabled-but-dead services suggest a pattern (maybe HM activation issue)
12. **Flake.lock staleness** — Some inputs may be outdated (last full update was recent, but individual pins vary)

### Low Priority

13. **Missing justfile scripts** — 4 referenced scripts don't exist
14. **DNS-over-QUIC** — Disabled for binary cache compatibility
15. **RPi3 provisioning** — Blocked on hardware

---

## f) Top 25 Things We Should Get Done Next

| #  | Task                                                                      | Impact | Effort   | Priority   |
| -- | ------------------------------------------------------------------------- | ------ | -------- | ---------- |
| 1  | Fix Whisper ASR compose command (remove `python` prefix)                  | High   | 5min     | 🔴 P0      |
| 2  | Deploy Caddy LAN auth bypass (`just switch`)                              | High   | 10min    | 🔴 P0      |
| 3  | Fix AWWW daemon systemd unit (StartLimitIntervalSec section)              | Medium | 5min     | 🔴 P0      |
| 4  | Investigate & fix dead user services (file-and-image-renamer, monitor365) | Medium | 30min    | 🔴 P0      |
| 5  | Update FEATURES.md: Twenty CRM 🔧→✅                                      | Low    | 2min     | 🟡 P1      |
| 6  | Pin Twenty CRM Docker image to digest                                     | High   | 5min     | 🟡 P1      |
| 7  | Disk cleanup: root at 89%                                                 | High   | 30min    | 🟡 P1      |
| 8  | Investigate 15GB swap usage                                               | Medium | 15min    | 🟡 P1      |
| 9  | Wire voice-agents systemd service properly                                | Medium | 15min    | 🟡 P1      |
| 10 | Update Whisper Docker image (20 months old)                               | Medium | 15min    | 🟡 P1      |
| 11 | Remove or fix missing justfile script references                          | Low    | 10min    | 🟢 P2      |
| 12 | Enable AppArmor (security-hardening)                                      | Medium | 20min    | 🟢 P2      |
| 13 | Investigate auditd NixOS 26.05 bug status                                 | Medium | 10min    | 🟢 P2      |
| 14 | Add Twenty CRM to AGENTS.md with accurate status                          | Low    | 5min     | 🟢 P2      |
| 15 | Verify all user services start on boot (regression test)                  | Medium | 15min    | 🟢 P2      |
| 16 | Check if PhotoMap can be updated/re-enabled                               | Low    | 20min    | 🟢 P2      |
| 17 | Run `nix flake check --no-build` to verify eval                           | Low    | 5min     | 🟢 P2      |
| 18 | Update flake.lock for stale inputs                                        | Low    | 5min     | 🟢 P2      |
| 19 | Create missing scripts (benchmark, perf, context, clean-storage)          | Low    | 2h       | ⚪ P3      |
| 20 | Research Unsloth Studio enablement feasibility                            | Low    | 30min    | ⚪ P3      |
| 21 | Add backup verification for Twenty CRM DB                                 | Low    | 5min     | ⚪ P3      |
| 22 | Extract `mkHardenedService` wrapper pattern                               | Low    | 1h       | ⚪ P3      |
| 23 | Add Nix module typed options for key services                             | Low    | 2h       | ⚪ P3      |
| 24 | Provision Raspberry Pi 3 for DNS failover                                 | High   | Hardware | 🔵 Blocked |
| 25 | Implement DNS-over-QUIC with binary cache fix                             | Low    | 2h       | ⚪ P3      |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Why are multiple enabled user services dead after a 1-day uptime reboot?**

Three user services are `enabled` but `inactive (dead)`:

- `awww-daemon.service` — has a config error (`StartLimitIntervalSec` in wrong section)
- `file-and-image-renamer.service` — no obvious error, just dead
- `monitor365` — not even installed as a unit

Is this:

1. A Home Manager generation issue (services written but not pulled in by current generation)?
2. A `WantedBy=default.target` vs `graphical-session.target` issue (services waiting for a target that won't trigger)?
3. An intentional decision (you disabled them and forgot)?

I cannot tell without running `systemctl --user show <unit>` to see the `WantedBy` and `After` targets, and checking the HM activation script output.

---

## System Metrics

```
Memory:  62Gi total | 47Gi used | 5.4Gi free | 14Gi available | 16Gi buff/cache
Swap:    41Gi total | 15Gi used | 25Gi free
Disk /:  512G total | 447G used | 61G free  (89%)
Disk /data: 800G total | 685G used | 116G free (86%)
Load:    3.44, 3.38, 3.60
Uptime:  1 day 20:27
```

## Service Counts

| Category          | Running   | Failed                    | Inactive/Dead                      |
| ----------------- | --------- | ------------------------- | ---------------------------------- |
| System services   | 46        | 0                         | 2 (voice-agents, monitor365)       |
| User services     | 19        | 0                         | 3 (awww, file-renamer, monitor365) |
| Docker containers | 5 healthy | 1 crash-looping (whisper) | —                                  |
| Systemd timers    | 22        | 0                         | —                                  |

## Uncommitted Changes

- `modules/nixos/services/caddy.nix` — LAN auth bypass (not deployed)

---

_Generated 2026-05-03 06:12 CEST_
