# SystemNix — Session 41: Comprehensive Status Report

**Date:** 2026-05-06 12:17 CEST
**Branch:** master (up to date with origin/master)
**Session:** 41 (ongoing — started May 5, ~24h continuous)

---

## Uncommitted Changes (4 files)

| File                                  | Change   | Description                                                                                                                                                                                              |
| ------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `flake.nix`                           | 1 line   | Pin hermes-agent to `v2026.4.30` release tag                                                                                                                                                             |
| `flake.lock`                          | 95 lines | Flake input updates (cmdguard, dnsblockd, emeet-pixyd, file-and-image-renamer, go-finding, golangci-lint-auto-configure, helium, hermes-agent, library-policy, mr-sync, NUR, flake-parts, homebrew-cask) |
| `modules/nixos/services/hermes.nix`   | 21 lines | New vendor hash for v2026.4.30, SQLite auto-recovery for malformed DBs, `logs/curator` subdirectory                                                                                                      |
| `modules/nixos/services/manifest.nix` | 1 line   | Add `CORS_ORIGIN` env var to fix "Invalid origin" 403 on sign-in                                                                                                                                         |

---

## a) FULLY DONE ✅

### Infrastructure & Core

- **Cross-platform Nix flake** — Single flake, two systems (Darwin + NixOS), 80% shared via `platforms/common/`
- **flake-parts modular architecture** — 29 NixOS service modules, all using `lib/types.nix`, `lib/systemd.nix`, `lib/systemd/service-defaults.nix`
- **Shared overlays** — NUR, aw-watcher, todo-list-ai, golangci-lint-auto-configure, mr-sync, library-policy (cross-platform); openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer (Linux-only)
- **All `path:` inputs eliminated** — Fully portable flake, all private repos via `git+ssh://`
- **Formatter** — treefmt + alejandra via `treefmt-full-flake`, `just format` works
- **Flake checks** — statix, deadnix, eval checks pass: `just test-fast` → all checks passed

### NixOS Services (evo-x2)

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
- **Ollama** — ROCm GPU, flash attention, 4 parallel, q8_0 KV, 24h keep-alive
- **ComfyUI** — ROCm GPU, bf16, OOMScoreAdjust=-100
- **Hermes AI gateway** — Discord bot, cron, sops secrets, 4G memory limit, USR1 reload, SQLite auto-recovery
- **Manifest LLM router** — Docker Compose (app + postgres), sops secrets, daily DB backup, Caddy reverse proxy, CORS origin fix (pending deploy)
- **File & Image Renamer** — Watches Desktop, ZAI API, hardened sandbox
- **Monitor365** — Device monitoring agent, ActivityWatch integration
- **DNS blocker** — Unbound + dnsblockd, 25 blocklists, 2.5M+ domains, Quad9 DoT upstream

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

### Cross-Platform (Darwin + NixOS)

- **Home Manager** — 14 shared program modules: fish, zsh, bash, starship, git, tmux, fzf, taskwarrior, keepassxc, pre-commit, shell-aliases, ssh-config, chromium, activitywatch
- **Taskwarrior** — TaskChampion sync, deterministic client IDs, Catppuccin Mocha colors, `just task-*` commands
- **Git config** — External `nix-ssh-config` flake input
- **Crush config** — Deployed via flake input + Home Manager on both platforms
- **Catppuccin Mocha theme** — Universal: all apps, terminals, bars, login screen

### Documentation & Quality

- **AGENTS.md** — Comprehensive project guide with architecture, patterns, gotchas, commands
- **FEATURES.md** — Brutally honest feature inventory with status indicators
- **`just` commands** — 60+ recipes organized by category, all documented
- **Shared lib helpers** — `lib/systemd.nix` (harden), `lib/systemd/service-defaults.nix`, `lib/types.nix`, `lib/rocm.nix`

---

## b) PARTIALLY DONE ⚠️

| Item                          | Status | What's Missing                                                                                                                                                                                               |
| ----------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Manifest LLM router**       | ⚠️      | `CORS_ORIGIN` fix committed but NOT deployed. Rate limiting warning ("could not determine client IP") — upstream Manifest doesn't expose `trustedProxies` config. First-run setup done (admin user created). |
| **Hermes v2026.4.30 upgrade** | ⚠️      | Pinned to release tag, new vendor hash, SQLite auto-recovery added, `logs/curator` subdirectory — committed but NOT deployed                                                                                 |
| **DNS failover cluster**      | ⚠️      | Module exists (`dns-failover.nix`), Keepalived VRRP config written — Pi 3 hardware not provisioned                                                                                                           |
| **Voice agents**              | ⚠️      | LiveKit + Whisper module exists, Docker ROCm — may need verification after last deploy                                                                                                                       |
| **PhotoMap AI**               | 🔧     | Module exists, disabled in config                                                                                                                                                                            |
| **Twenty CRM**                | 🔧     | Module exists, Docker Compose, sops secrets — unclear if actively deployed                                                                                                                                   |
| **Unsloth Studio**            | 🔧     | Module exists, disabled by default                                                                                                                                                                           |
| **Multi-WM (Sway)**           | 🔧     | Module exists, disabled in config                                                                                                                                                                            |
| **AMD NPU driver**            | ⚠️      | `nix-amd-npu` input present, but XDNA driver support is experimental                                                                                                                                         |
| **Raspberry Pi 3 image**      | 📋     | `nixosConfigurations.rpi3-dns` defined in flake — hardware not provisioned                                                                                                                                   |

---

## c) NOT STARTED 📋

1. **Pi 3 DNS backup node** — Hardware provisioning + SD image flash + network config
2. **Gatus health checks** — Draft module started, not completed (see `docs/2026-05-04_15-56_COMPREHENSIVE-STATUS-AND-GATUS-DRAFT.md`)
3. **Papermark document sharing** — Research done (see `docs/status/2026-05-01_09-03_PAPERMARK-INTEGRATION-RESEARCH-AND-PLANNING.md`), not implemented
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
14. **GolangCI-lint auto-configure** — Package in `pkgs/`, not wired as a system service or CI step
15. **mr-sync** — Package in `pkgs/`, no cron or systemd timer for auto-sync

---

## d) TOTALLY FUCKED UP 💥

| Item                         | Severity | Details                                                                                                                                                                                                                                                                                    |
| ---------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Manifest rate limiting**   | Low      | Better Auth can't determine client IP because Docker bridge (172.21.0.1) strips origin info. Manifest doesn't expose `trustedProxies` config — upstream limitation. Rate limiting is silently skipped. Not security-critical (Authelia forward auth protects the endpoint), but not ideal. |
| **amdgpu driver crash loop** | Medium   | Hermes anime-comic-pipeline (PyTorch/ROCm) can SIGSEGV → GPU driver hang → desktop frozen. Defense in depth: kernel.sysrq=1, kernel.panic=30, softlockup_panic=1, hung_task_panic=1, watchdogd, amdgpu.gpu_recovery=1. Not a config issue — upstream AMD driver bug.                       |
| **awww-daemon BrokenPipe**   | Low      | Upstream awww 0.12.0 panics on BrokenPipe at daemon/src/main.rs:712:32 during suspend/output hotplug. `Restart=always` + `PartOf` propagation covers it. Not fixed upstream.                                                                                                               |
| **watchdogd nixpkgs module** | Low      | `services.watchdogd.settings.device` generates invalid config (unquoted paths). Workaround: omit `device` from settings. Upstream nixpkgs bug. Reset-reason section also broken.                                                                                                           |

---

## e) WHAT WE SHOULD IMPROVE 🎯

### Architecture & Code Quality

1. **Archive the 280+ stale status reports** — `docs/status/` has 16 active + 280+ archived. `docs/status/archive/` is enormous. Should be pruned to last 30 days.
2. **Archive stale docs** — `docs/` has 80+ top-level .md files. Many are research/evaluation docs from months ago. Should organize into `docs/research/` more aggressively.
3. **Add `trustedProxies` to Manifest** — File upstream issue with mnfst/manifest to support `trustedProxies` in Better Auth config, or contribute a PR.
4. **Gatus health checks** — Replace ad-hoc monitoring with Gatus for all services. Module draft exists.
5. **Service dependency graph** — Document which services depend on which (Caddy → Authelia → SOPS, Docker → all Docker services, etc.)
6. **CI pipeline** — `nix-check.yml` exists but doesn't run on PRs. Should add Darwin build check.
7. **Module option documentation** — Many modules have `options` but no `description` on each option.
8. **Shared `port` type pattern** — All services should use `lib/types.nix` port option consistently.
9. **Impermanence / root-on-tmpfs** — NixOS would benefit from tmpfs root with only `/data` and `/var/lib/<service>` persisted.
10. **Automated DNS blocklist updates** — Currently manual `just dns-update`. Should be a weekly CI job or timer.

### Reliability

11. **Gitea backup verification** — Backups run weekly but nobody checks they restore correctly.
12. **SOPS secret rotation** — Secrets have never been rotated since initial setup.
13. **Disaster recovery playbook** — No tested procedure for full system rebuild from scratch.
14. **SigNoz alert notification** — Alerts defined but no notification channel configured (no email/webhook).
15. **System snapshot testing** — BTRFS + Timeshift configured but never tested restore.

### Darwin-specific

16. **macOS ActivityWatch** — Utilization watcher exists but macOS-specific issues remain.
17. **Darwin build time** — Darwin config rebuild takes significant time. Could optimize with binary cache.
18. **Homebrew management** — `nix-homebrew` input exists but Homebrew packages aren't fully managed.

---

## f) Top 25 Things We Should Get Done Next

### Priority 1: Deploy & Verify (Immediate)

| # | Task                                                                               | Impact | Effort |
| - | ---------------------------------------------------------------------------------- | ------ | ------ |
| 1 | **Deploy pending changes** (`just switch`) — Hermes v2026.4.30 + Manifest CORS fix | High   | Low    |
| 2 | **Verify Manifest sign-in works** after CORS_ORIGIN deploy                         | High   | Low    |
| 3 | **Verify Hermes auto-recovery** — test SQLite malformed DB handling                | Medium | Low    |
| 4 | **Run `just health`** — full cross-platform health check                           | Medium | Low    |

### Priority 2: Observability & Reliability

| #  | Task                                                                | Impact | Effort |
| -- | ------------------------------------------------------------------- | ------ | ------ |
| 5  | **Configure SigNoz alert notifications** — webhook or email channel | High   | Medium |
| 6  | **Gatus health checks** — finish module, deploy for all services    | High   | Medium |
| 7  | **Gitea backup restore test** — verify weekly dumps are valid       | High   | Low    |
| 8  | **Disaster recovery playbook** — document full rebuild procedure    | Medium | Medium |
| 9  | **BTRFS snapshot restore test** — verify Timeshift works            | Medium | Low    |
| 10 | **SOPS secret rotation plan** — document and schedule               | Medium | Medium |

### Priority 3: Architecture & Code Quality

| #  | Task                                                                          | Impact | Effort |
| -- | ----------------------------------------------------------------------------- | ------ | ------ |
| 11 | **Archive stale status reports** — move everything > 14 days to `archive/`    | Low    | Low    |
| 12 | **Organize `docs/` top-level** — move research/evaluation to `docs/research/` | Low    | Low    |
| 13 | **File Manifest upstream issue** — request `trustedProxies` config support    | Medium | Low    |
| 14 | **Add module option descriptions** — ensure all `options` have `description`  | Low    | Medium |
| 15 | **Service dependency graph** — visualize with D2 diagram                      | Medium | Medium |

### Priority 4: Infrastructure

| #  | Task                                                             | Impact | Effort |
| -- | ---------------------------------------------------------------- | ------ | ------ |
| 16 | **Automated DNS blocklist updates** — weekly timer or CI job     | Medium | Low    |
| 17 | **Pi 3 provisioning** — flash SD, boot, verify DNS failover      | High   | High   |
| 18 | **DNS failover cluster testing** — verify VRRP failover works    | High   | Medium |
| 19 | **CI Darwin build check** — ensure Darwin config doesn't regress | Medium | Low    |
| 20 | **Impermanence research** — evaluate tmpfs root for evo-x2       | High   | High   |

### Priority 5: New Features & Polish

| #  | Task                                                                             | Impact | Effort |
| -- | -------------------------------------------------------------------------------- | ------ | ------ |
| 21 | **Voice agents verification** — confirm LiveKit + Whisper stack works end-to-end | Medium | Medium |
| 22 | **Twenty CRM deployment verification** — confirm or remove module                | Low    | Low    |
| 23 | **PhotoMap AI re-enablement** — evaluate if CLIP visualization is worth running  | Low    | Medium |
| 24 | **mr-sync auto-sync timer** — wire `mr-sync` as a weekly systemd timer           | Low    | Low    |
| 25 | **GolangCI-lint auto-configure CI step** — integrate into Go project workflows   | Low    | Medium |

---

## g) Top #1 Question I Cannot Figure Out Myself 🤔

**Is the Twenty CRM actually deployed and in use?**

The module at `modules/nixos/services/twenty.nix` is a full Docker Compose stack (4 containers + PostgreSQL + Redis + sops secrets + daily backup). It has a Caddy vhost at `crm.home.lan`. But it's unclear whether:

- It was ever successfully deployed and verified working
- Anyone is actively using it
- The sops secrets exist in the manifest

If it's not in use, the module should be disabled (`services.twenty.enable = false`) or removed to reduce system complexity and resource consumption (4 Docker containers = non-trivial RAM/CPU).

**Check needed:**

```bash
docker ps | grep twenty     # Are the containers running?
just switch --dry-run       # Does the config try to start them?
ls platforms/nixos/secrets/ # Is twenty.yaml in sops?
```

---

## Session Timeline (May 5–6, 2026)

| Session | Time      | What Happened                                                        |
| ------- | --------- | -------------------------------------------------------------------- |
| 28      | 12:27     | Build fix chain, deployment                                          |
| 28b     | 12:30     | Reliability hardening, Waybar health, Gitea                          |
| 29      | 17:54     | Self-review, architecture cleanup                                    |
| 30      | 20:37     | Manifest LLM router integration (initial)                            |
| 31      | 21:19     | Justfile overhaul, self-review                                       |
| 32      | 21:34     | Full system status                                                   |
| 33      | 23:31     | Deploy, GC, Caddy fix                                                |
| 34      | 23:30     | Brutal self-review execution sprint                                  |
| 34b     | 23:54     | Full system status, Manifest secrets                                 |
| 35      | 03:57     | Niri session migration, GPU recovery                                 |
| 36      | 04:47     | Fork PR plan (partial implementation)                                |
| 37      | 07:10     | DNS reproducibility, Manifest hardening                              |
| 38      | 07:54     | Watchdog fix, Manifest healthcheck, SOPS dedup                       |
| 39      | 08:41     | Helium session restore, Rofi plugins, Waybar                         |
| 40      | 10:30     | File-renamer API key fix, SOPS revert, deploy prep                   |
| **41**  | **12:17** | **Manifest CORS fix, Hermes v2026.4.30 upgrade, full status report** |

---

## Key Metrics

| Metric                      | Value                         |
| --------------------------- | ----------------------------- |
| NixOS service modules       | 29                            |
| Custom packages (pkgs/)     | 13                            |
| Flake inputs                | 32                            |
| Shared Home Manager modules | 14                            |
| `just` recipes              | 60+                           |
| Active status reports       | 16                            |
| Archived status reports     | 280+                          |
| Days of continuous work     | ~2 (May 5–6)                  |
| Uncommitted files           | 4                             |
| Build status                | ✅ Passing (`just test-fast`) |

---

_Session 41 — Waiting for instructions._
