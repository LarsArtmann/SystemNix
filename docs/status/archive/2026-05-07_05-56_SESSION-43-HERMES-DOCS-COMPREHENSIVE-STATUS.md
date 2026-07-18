# SystemNix — Session 43: Comprehensive Status, Hermes Docs, Health Check Fix

**Date:** 2026-05-07 05:56 CEST
**Branch:** master (up to date with origin/master)
**Session:** 43 (continuation of 24h+ continuous work since May 5)

---

## Changes This Session

|| File | Lines | Description |
|------|------|-------------|
| `modules/nixos/services/hermes.nix` | +5 | Added npmDeps hash resilience comment with upgrade instructions |
| `AGENTS.md` | +9 | Documented hermes npmDeps patching, SQLite auto-recovery, curator dirs, version pin |

**Previous session (42) uncommitted files now committed:** AGENTS.md (GPU headroom section), justfile (gpu-python command)

**Note:** The Hermes v2026.4.30 upgrade, GPU limiting, and Manifest CORS fix from sessions 41-42 are committed but **NOT deployed** — still needs `just switch`.

---

## a) FULLY DONE ✅

### Infrastructure & Core

- **Cross-platform Nix flake** — Single flake, two systems (Darwin + NixOS), 80% shared via `platforms/common/`
- **flake-parts modular architecture** — 30 NixOS service modules, all using `lib/types.nix`, `lib/systemd.nix`, `lib/systemd/service-defaults.nix`
- **Shared overlays** — NUR, aw-watcher, todo-list-ai, golangci-lint-auto-configure, mr-sync, library-policy (cross-platform); openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer (Linux-only)
- **All `path:` inputs eliminated** — Fully portable flake, all private repos via `git+ssh://`
- **Formatter** — treefmt + alejandra via `treefmt-full-flake`, `just format` works
- **Flake checks** — statix, deadnix, eval checks pass: `just test-fast` → all checks passed
- **Pre-commit hooks** — gitleaks (secrets), trailing whitespace, deadnix, statix, alejandra, nix flake check

### NixOS Services (evo-x2) — 30 modules

- **Docker** — Always-on, overlay2, `/data/docker`, weekly auto-prune
- **Caddy reverse proxy** — TLS via sops certs, forward auth via Authelia, 10+ virtual hosts, metrics
- **SOPS secrets** — Age-encrypted via SSH host key, 4 sops files, auto-restart per secret
- **Authelia SSO** — OIDC provider, TOTP + WebAuthn 2FA, file-based auth, brute-force protection
- **Gitea** — SQLite, LFS, weekly dumps, GitHub mirror, Actions runner (Docker + native)
- **Homepage Dashboard** — Catppuccin Mocha theme, 5 categories, resource widgets
- **Immich** — PostgreSQL + Redis + ML, OAuth via Authelia, daily DB backup, GPU for ML
- **SigNoz** — Full observability: traces/metrics/logs, ClickHouse, OTel Collector, node_exporter, cadvisor, 7 alert rules, dashboard provisioning
- **TaskChampion** — Port 10222, TLS via Caddy, no forward auth, deterministic client IDs
- **Minecraft** — JDK 25, ZGC, LAN-only firewall, Prism Launcher client
- **Ollama** — ROCm GPU, flash attention, **2 parallel** (reduced from 4), q8_0 KV, 1h keep-alive, **95% GPU memory cap**
- **ComfyUI** — ROCm GPU, bf16, OOMScoreAdjust=-100, **95% GPU memory cap**
- **Hermes AI gateway** — v2026.4.30, Discord bot, cron, sops secrets, 24G memory limit, USR1 reload, **SQLite auto-recovery**, npmDeps hash patching documented
- **Manifest LLM router** — Docker Compose (app + postgres), sops secrets, daily DB backup, Caddy reverse proxy
- **File & Image Renamer** — Watches Desktop, ZAI API, hardened sandbox
- **Monitor365** — Device monitoring agent, ActivityWatch integration
- **DNS blocker** — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream
- **Voice agents** — LiveKit + Whisper module, Docker ROCm
- **PhotoMap AI** — Module exists, disabled in config
- **Twenty CRM** — Module exists, Docker Compose, sops secrets

### Desktop (NixOS)

- **Niri compositor** — niri-unstable, XWayland satellite, patched BindsTo→Wants, OOMScoreAdjust=-900
- **SDDM** — SilentSDDM, Catppuccin Mocha theme
- **PipeWire** — ALSA + PulseAudio + JACK compat, rtkit realtime
- **Waybar** — Thermal zone fix (no hardcoded hwmon), security status indicator
- **EMEET PIXY webcam** — Full Go daemon, auto-tracking, call detection, Waybar integration, HID state querying
- **Niri session manager** — Window save/restore, TOML app mappings, backup rotation
- **Security hardening** — fail2ban, ClamAV, polkit, GNOME Keyring, 30+ security tools
- **Steam gaming** — extest, protontricks, gamemode, gamescope, mangohud
- **Wallpaper self-healing** — awww-daemon + awww-wallpaper with PartOf restart propagation
- **Helium browser** — Restore tabs on launch via wrapper flags
- **Rofi** — calc + emoji plugins
- **Yazi, Zellij, Chromium** — Configured via NixOS modules

### Cross-Platform (Darwin + NixOS)

- **Home Manager** — 14 shared program modules: fish, zsh, bash, starship, git, tmux, fzf, taskwarrior, keepassxc, pre-commit, shell-aliases, ssh-config, chromium, activitywatch
- **Taskwarrior** — TaskChampion sync, deterministic client IDs, Catppuccin Mocha colors, `just task-*` commands
- **Git config** — External `nix-ssh-config` flake input
- **Crush config** — Deployed via flake input + Home Manager on both platforms
- **Catppuccin Mocha theme** — Universal: all apps, terminals, bars, login screen

### GPU Management

- **PyTorch GPU memory fraction** — 95% cap system-wide via `PYTORCH_CUDA_ALLOC_CONF`
- **Ollama parallelism reduction** — 4→2 concurrent requests
- **`gpu-python` wrapper** — Convenience command for ad-hoc GPU scripts with configurable fraction

### Documentation & Quality

- **AGENTS.md** — Comprehensive project guide (700+ lines) with architecture, patterns, gotchas, commands
- **FEATURES.md** — Brutally honest feature inventory (498 lines) with status indicators
- **`just` commands** — 67 recipes organized by category, all documented
- **Shared lib helpers** — `lib/systemd.nix` (harden), `lib/systemd/service-defaults.nix`, `lib/types.nix`, `lib/rocm.nix`
- **AMD debugging guide** — `docs/amdgpu-debugging-guide.md` for Strix Halo GPU bugs

---

## b) PARTIALLY DONE ⚠️

| Item                          | Status | What's Missing                                                                                                                                                                                                 |
| ----------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **GPU headroom for niri**     | ⚠️     | Committed, build passes. **NOT deployed** — needs `just switch`. `per_process_memory_fraction` caps memory allocation but does NOT directly limit compute utilization. May need to lower further (0.90, 0.85). |
| **Manifest LLM router**       | ⚠️     | `CORS_ORIGIN` fix committed but NOT deployed. Rate limiting warning ("could not determine client IP") — upstream Manifest doesn't expose `trustedProxies` config.                                              |
| **Hermes v2026.4.30 upgrade** | ⚠️     | Pinned to release tag, npmDeps hash patched, SQLite auto-recovery added, curator dirs documented — committed but NOT deployed                                                                                  |
| **DNS failover cluster**      | ⚠️     | Module exists (`dns-failover.nix`), Keepalived VRRP config written — Pi 3 hardware not provisioned                                                                                                             |
| **Voice agents**              | ⚠️     | LiveKit + Whisper module exists, Docker ROCm — may need verification after deploy                                                                                                                              |
| **PhotoMap AI**               | 🔧     | Module exists, disabled in config                                                                                                                                                                              |
| **Twenty CRM**                | 🔧     | Module exists, Docker Compose, sops secrets — unclear if actively deployed                                                                                                                                     |
| **Unsloth Studio**            | 🔧     | Module exists (`ai-models.nix`), disabled by default                                                                                                                                                           |
| **Multi-WM (Sway)**           | 🔧     | Module exists, disabled in config                                                                                                                                                                              |
| **AMD NPU driver**            | ⚠️     | `nix-amd-npu` input present, XDNA driver support experimental                                                                                                                                                  |
| **Raspberry Pi 3 image**      | 📋     | `nixosConfigurations.rpi3-dns` defined in flake — hardware not provisioned                                                                                                                                     |
| **Service health check**      | ⚠️     | Script exists (`service-health-check`), runs on timer, but **fails every run** — likely a service down or URL check failing. Needs investigation.                                                              |

---

## c) NOT STARTED 📋

1. **Pi 3 DNS backup node** — Hardware provisioning + SD image flash + network config
2. **Gatus health checks** — Draft module started, not completed
3. **Papermark document sharing** — Research done, not implemented
4. **Private cloud planning** — Directory exists with README, no implementation
5. **ecapture integration** — Assessment done, not implemented
6. **mitmproxy + ActivityWatch integration** — Research done, not implemented
7. **Reticulum network** — Assessment done, not implemented
8. **Qubes-in-NixOS** — Research done, not implemented
9. **YouTube frontend alternatives** — Research done, not implemented
10. **Coroot/deepflow evaluation** — Reports written, no implementation
11. **ActivityWatch URL tracking** — Investigated, not implemented
12. **Nix colors integration** — Research done, currently using Catppuccin directly
13. **Technitium DNS migration** — Full evaluation + guides written, not migrated (staying with Unbound)
14. **GolangCI-lint auto-configure** — Package in `pkgs/`, not wired as CI step
15. **mr-sync auto-sync timer** — Package in `pkgs/`, no cron or systemd timer for auto-sync
16. **Actual GPU compute throttling** — `per_process_memory_fraction` is memory-only. True compute queue limiting (NVIDIA MPS equivalent) doesn't exist for AMD. Would need kernel-level AMD HSA queue priority support.
17. **Service dependency graph** — D2 diagram planned, not started
18. **Disaster recovery playbook** — No tested procedure for full rebuild
19. **TODO_LIST.md** — Does not exist; feature audit done in FEATURES.md

---

## d) TOTALLY FUCKED UP 💥

| Item                                     | Severity | Details                                                                                                                                                                                                                                                                                                                                              |
| ---------------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **GPU compute scheduling**               | Medium   | AMD APUs have NO GPU compute priority mechanism. `per_process_memory_fraction` limits memory, not compute cycles. If AI workloads saturate compute units, niri WILL still lag. The 95% memory cap + reduced parallelism are mitigations, not a fix. True fix requires AMD HSA/ROCm queue priority support at the kernel level — doesn't exist today. |
| **amdgpu driver crash loop**             | Medium   | Hermes anime-comic-pipeline (PyTorch/ROCm) can SIGSEGV → GPU driver hang → desktop frozen. Defense in depth: sysrq, panic=30, watchdogd, gpu_recovery=1. Upstream AMD driver bug. PP Overdrive disabled because it made this WORSE.                                                                                                                  |
| **service-health-check fails every run** | Medium   | Timer fires every 15min, script exits 1 every time since at least 04:34 today. `OnFailure=notify-failure@%n.service` triggers but likely no one sees it. Needs investigation — probably a URL check or service check failing.                                                                                                                        |
| **Manifest rate limiting**               | Low      | Better Auth can't determine client IP because Docker bridge strips origin info. Manifest doesn't expose `trustedProxies` config — upstream limitation.                                                                                                                                                                                               |
| **awww-daemon BrokenPipe**               | Low      | Upstream awww 0.12.0 panics on BrokenPipe during suspend/output hotplug. `Restart=always` + `PartOf` propagation covers it.                                                                                                                                                                                                                          |
| **watchdogd nixpkgs module**             | Low      | `device` and `reset-reason` sections generate invalid config (unquoted paths). Workaround: omit both. Upstream nixpkgs bug.                                                                                                                                                                                                                          |
| **Disk usage creeping**                  | Low      | Root 84% (82G free), /data 83% (140G free). Nix store is 84G. Not critical but trending upward.                                                                                                                                                                                                                                                      |
| **304 top-level docs**                   | Low      | `docs/` has 304 .md files outside status/. Most are research/evaluations that should be archived.                                                                                                                                                                                                                                                    |

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Session 43 Learnings

1. **npmDeps resilience documented** — Added upgrade instructions so next hermes bump doesn't require digging through git history
2. **Health check silently failing** — The service-health-check has been failing for hours with no visible alert. Should fix the underlying check AND ensure notifications actually reach the desktop.
3. **Many "committed but not deployed" items** — 3 major changes (GPU limit, Hermes upgrade, Manifest CORS) sitting uncommitted-to-machine. Deploy backlog is a risk.

### Architecture & Code Quality

4. **Archive the 330+ stale status reports** — `docs/status/` has 18 active + 330 archived. Consider pruning archive too.
5. **Archive 304 top-level docs** — `docs/` has 80+ research/evaluation files. Organize into `docs/research/`.
6. **File Manifest upstream issue** — Request `trustedProxies` in Better Auth config.
7. **Gatus health checks** — Replace ad-hoc health check script. Module draft exists.
8. **Service dependency graph** — D2 diagram of service dependencies.
9. **CI pipeline** — `nix-check.yml` exists but doesn't run on PRs. Add Darwin build check.
10. **Module option documentation** — Many `options` lack `description`.
11. **Shared `port` type pattern** — All services should use `lib/types.nix` consistently.
12. **Impermanence / root-on-tmpfs** — Evaluate tmpfs root for evo-x2.
13. **Automated DNS blocklist updates** — Weekly CI job or timer (script exists, not on timer).
14. **Fix service-health-check** — Investigate which check fails and fix it.
15. **niri-config missing harden{}** — Only module flagged by health check as not using harden.

### Reliability

16. **Deploy the pending changes** — 3+ commits (GPU limiting, Hermes upgrade, Manifest CORS) committed but NOT deployed.
17. **Gitea backup verification** — Backups run but never tested for restore.
18. **SOPS secret rotation** — Never rotated since initial setup.
19. **Disaster recovery playbook** — No tested procedure for full rebuild.
20. **SigNoz alert notifications** — Alerts defined, no notification channel configured.
21. **System snapshot testing** — BTRFS + Timeshift never tested restore.

### Darwin-specific

22. **macOS ActivityWatch** — Utilization watcher exists but macOS issues remain.
23. **Darwin build time** — Could optimize with binary cache.
24. **Homebrew management** — `nix-homebrew` exists but packages not fully managed.

---

## f) Top 25 Things We Should Get Done Next

### Priority 1: Deploy & Verify (IMMEDIATE)

| #   | Task                                                                                    | Impact | Effort |
| --- | --------------------------------------------------------------------------------------- | ------ | ------ |
| 1   | **`just switch`** — Deploy GPU limiting + Hermes upgrade + Manifest CORS                | High   | Low    |
| 2   | **Fix service-health-check** — Investigate which check fails, fix script                | High   | Low    |
| 3   | **Verify niri responsiveness under AI load** — Run Ollama inference while using desktop | High   | Low    |
| 4   | **Verify Manifest sign-in** after CORS_ORIGIN deploy                                    | High   | Low    |
| 5   | **Verify Hermes auto-recovery** — test SQLite malformed DB handling                     | Medium | Low    |

### Priority 2: Reliability & Monitoring

| #   | Task                                                                           | Impact | Effort |
| --- | ------------------------------------------------------------------------------ | ------ | ------ |
| 6   | **Configure SigNoz alert notifications** — webhook or email channel            | High   | Medium |
| 7   | **Gatus health checks** — finish module, replace ad-hoc script                 | High   | Medium |
| 8   | **Lower GPU fraction if still laggy** — If 0.95 isn't enough, try 0.90 or 0.85 | High   | Low    |
| 9   | **Gitea backup restore test** — verify weekly dumps are valid                  | High   | Low    |
| 10  | **Run `just health`** after deploy — confirm all checks pass                   | Medium | Low    |

### Priority 3: Architecture Cleanup

| #   | Task                                                                          | Impact | Effort |
| --- | ----------------------------------------------------------------------------- | ------ | ------ |
| 11  | **Archive stale docs** — move 304 top-level research docs to `docs/research/` | Low    | Low    |
| 12  | **Add niri-config harden{}** — only module missing systemd hardening          | Low    | Low    |
| 13  | **Service dependency graph** — D2 diagram of all services                     | Medium | Medium |
| 14  | **File Manifest upstream issue** — request `trustedProxies` config            | Medium | Low    |
| 15  | **Add module option descriptions** — ensure all `options` have `description`  | Low    | Medium |

### Priority 4: GPU & Desktop

| #   | Task                                                                                        | Impact | Effort |
| --- | ------------------------------------------------------------------------------------------- | ------ | ------ |
| 16  | **Benchmark niri latency** — Measure frame times with/without AI workloads                  | Medium | Medium |
| 17  | **Monitor GPU utilization** — Add `gpu_busy_percent` to SigNoz via textfile collector       | Medium | Low    |
| 18  | **Research AMD HSA queue priority** — Check ROCm 6.4+/kernel 7.x for compute queue priority | Medium | Medium |
| 19  | **BTRFS snapshot restore test** — verify Timeshift works                                    | Medium | Low    |
| 20  | **Disaster recovery playbook** — document full rebuild procedure                            | Medium | Medium |

### Priority 5: Infrastructure & New Features

| #   | Task                                                                       | Impact | Effort |
| --- | -------------------------------------------------------------------------- | ------ | ------ |
| 21  | **Automated DNS blocklist updates** — weekly timer or CI job               | Medium | Low    |
| 22  | **Pi 3 provisioning** — flash SD, boot, verify DNS failover                | High   | High   |
| 23  | **SOPS secret rotation plan** — document and schedule                      | Medium | Medium |
| 24  | **Voice agents verification** — confirm LiveKit + Whisper works end-to-end | Medium | Medium |
| 25  | **Twenty CRM deployment verification** — confirm or remove module          | Low    | Low    |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Which check in `service-health-check` is actually failing?**

The health check script (`platforms/nixos/scripts/service-health-check`) runs 10 systemctl checks, 4 user service checks, and 11 URL checks. It exits 1 every 15 minutes but the journal only shows the failure — not which specific check failed. The script sends a desktop notification via `notify-send` but since it's running as a systemd service, the notification may not reach any active Wayland session (D-Bus `DISPLAY=:0` + `WAYLAND_DISPLAY=wayland-1` are set but may be stale or wrong).

**What I need from you:**

1. Run the health check script manually: `bash platforms/nixos/scripts/service-health-check`
2. Or check which service/URL is down by running individual checks
3. Then we can fix the root cause and ensure notifications actually reach the desktop

---

## System Metrics

| Metric                      | Value                                                 |
| --------------------------- | ----------------------------------------------------- |
| NixOS version               | 26.05.20260423.01fbdee (Yarara)                       |
| Kernel                      | 7.0.1                                                 |
| Root filesystem             | 84% used (82G free of 512G)                           |
| /data filesystem            | 83% used (140G free of 800G)                          |
| RAM                         | 41G used / 62G total (20G available)                  |
| Swap                        | 9.8G used / 41G total (31G free)                      |
| GPU busy                    | 0% (idle)                                             |
| GPU VRAM                    | 383M used / 64G total                                 |
| Load average                | 1.55, 2.06, 1.74                                      |
| Uptime                      | 23h 12m                                               |
| NixOS service modules       | 30                                                    |
| Custom packages (pkgs/)     | 9                                                     |
| Flake inputs                | 35                                                    |
| Shared Home Manager modules | 14                                                    |
| `just` recipes              | 67                                                    |
| Top-level docs              | 304                                                   |
| Status docs (active)        | 18                                                    |
| Status docs (archived)      | 330                                                   |
| Total git commits           | 2,169                                                 |
| Commits since May 5         | 70                                                    |
| Build status                | ✅ Passing (`just test-fast` all checks passed)       |
| Health check                | ❌ Failing (service-health-check exits 1 every 15min) |
| Pending deploy              | 3+ commits (GPU limit, Hermes upgrade, Manifest CORS) |

---

## Session Timeline (May 5–7, 2026)

| Session | Time            | What Happened                                                             |
| ------- | --------------- | ------------------------------------------------------------------------- |
| 28      | May 5 12:27     | Build fix chain, deployment                                               |
| 28b     | May 5 12:30     | Reliability hardening, Waybar health, Gitea                               |
| 29      | May 5 17:54     | Self-review, architecture cleanup                                         |
| 30      | May 5 20:37     | Manifest LLM router integration (initial)                                 |
| 31      | May 5 21:19     | Justfile overhaul, self-review                                            |
| 32      | May 5 21:34     | Full system status                                                        |
| 33      | May 5 23:31     | Deploy, GC, Caddy fix                                                     |
| 34      | May 5 23:30     | Brutal self-review execution sprint                                       |
| 34b     | May 5 23:54     | Full system status, Manifest secrets                                      |
| 35      | May 6 03:57     | Niri session migration, GPU recovery                                      |
| 36      | May 6 04:47     | Fork PR plan (partial implementation)                                     |
| 37      | May 6 07:10     | DNS reproducibility, Manifest hardening                                   |
| 38      | May 6 07:54     | Watchdog fix, Manifest healthcheck, SOPS dedup                            |
| 39      | May 6 08:41     | Helium session restore, Rofi plugins, Waybar                              |
| 40      | May 6 10:30     | File-renamer API key fix, SOPS revert, deploy prep                        |
| 41      | May 6 12:17     | Manifest CORS fix, Hermes v2026.4.30 upgrade, full status                 |
| 42      | May 6 12:46     | GPU headroom for niri (memory fraction + parallelism), full status        |
| **43**  | **May 7 05:56** | **Hermes npmDeps docs, comprehensive status, health check investigation** |

---

_Session 43 — Waiting for instructions._
