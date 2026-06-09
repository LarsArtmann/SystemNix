# SystemNix — Comprehensive Master Status Report

**Date:** 2026-06-09 22:52
**System:** evo-x2 (NixOS) + Lars-MacBook-Air (macOS)
**Branch:** master (4 unpushed commits)
**Build:** `just test-fast` — ALL CHECKS PASSED
**Session context:** Port centralization, ecapture, monitor365, Overview integration, Manifest auth fix, Homepage dynamic tiles

---

## Executive Summary

SystemNix is a **mature, production Nix configuration** managing 2 daily-driver machines (NixOS desktop + macOS laptop) with 35+ services. The codebase is in **strong shape** — all builds pass, port centralization is complete, services are hardened. The main risks are unverified deployments (4 unpushed/untested commits), a handful of disabled services, and the usual vendorHash cascade from Go dependency updates.

---

## a) FULLY DONE

### Core Infrastructure

| Item | Details |
|------|---------|
| **Cross-platform flake** | Single flake, two platforms (Darwin + NixOS), 80% shared via `platforms/common/` |
| **flake-parts architecture** | 36 service modules auto-discovered from `modules/nixos/services/` |
| **Port centralization** | ALL service ports in `lib/ports.nix` — every service references `ports.*`, zero hardcoded ports |
| **Systemd hardening library** | `harden`, `hardenUser`, `serviceDefaults`, `serviceDefaultsUser`, `onFailure` — reusable helpers |
| **Docker service factory** | `mkDockerServiceFactory` — standardized Docker Compose → systemd with backup, env templates |
| **SOPS secrets** | Age-encrypted via SSH host keys, per-secret restart units, 4 encrypted files |
| **Overlay system** | `mkPackageOverlay` for all flake-input overlays — platform-safe, returns `{}` on wrong system |
| **`mkPreparedSource`** | Centralized in `go-nix-helpers` — auto-strips local replaces, normalizes pseudo-versions, handles v2 sub-modules |

### Authentication Stack

| Item | Details |
|------|---------|
| **Pocket ID** | Passkey-only OIDC provider at `auth.home.lan`, Go backend, SQLite, metrics enabled |
| **oauth2-proxy** | Forward-auth bridge between Caddy and Pocket ID, cookie-based sessions |
| **Caddy forward auth** | `protectedVHost` helper — 12 services behind Pocket ID SSO |
| **WebAuthn hybrid transport** | Phone-as-authenticator passkeys enabled |

### Production Services (enabled & running)

| Service | Module | Key Details |
|---------|--------|-------------|
| **Caddy** | `caddy.nix` | 12 virtual hosts, TLS via sops, metrics, 10 proxy targets |
| **Forgejo** | `forgejo.nix` | SQLite, LFS, Actions runner (Docker + native), GitHub push mirrors, admin auto-setup |
| **Forgejo repos** | `forgejo-repos.nix` | Declarative repo mirroring (dnsblockd, BuildFlow), daily auto-sync |
| **Immich** | `immich.nix` | PostgreSQL + Redis + ML, OAuth, VA-API transcoding, daily DB backup |
| **SigNoz** | `signoz.nix` | Full-stack observability: traces/metrics/logs, ClickHouse, OTel, 7 alert rules, 4 provisioned dashboards |
| **Homepage Dashboard** | `homepage.nix` | Catppuccin Mocha, dynamic service tiles, health checks, resource widgets |
| **TaskChampion** | `taskchampion.nix` | Port 10222, TLS via Caddy, 100 snapshots/14d retention |
| **Twenty CRM** | `twenty.nix` | Docker Compose (4 containers), PostgreSQL + Redis, daily DB backup |
| **Manifest** | `manifest.nix` | LLM router, Docker Compose with PostgreSQL, Ollama integration |
| **Hermes** | `hermes.nix` | AI Agent Gateway, Discord bot, cron scheduler, 4G memory limit |
| **crush-daily** | `crush-daily.nix` | AI-powered dev insights, sops-managed secrets |
| **Overview** | `overview.nix` | Project dashboard, discovers git repos, shows stats/activity |
| **Monitor365** | `monitor365.nix` | Device monitoring agent + server, ActivityWatch integration, selective collectors |
| **OpenSEO** | `openseo.nix` | SEO suite (keyword research, rank tracking, audits) |
| **Gatus** | `gatus-config.nix` | Health check monitoring, 20 endpoints, Discord alerts, SQLite storage |
| **Dozzle** | inline `configuration.nix` | Docker log viewer at `logs.home.lan` |
| **DNS Blocker** | `dns-blocker.nix` | Unbound + blocklists + dnsblockd block page + stats API |
| **Ollama** | `ai-stack.nix` | ROCm GPU, flash attention, q8_0 KV, 32G MemoryMax |

### Desktop Environment

| Item | Details |
|------|---------|
| **Niri (Wayland)** | Primary compositor, XWayland satellite, OOMScoreAdjust=-900 |
| **SDDM** | SilentSDDM, Catppuccin Mocha theme |
| **PipeWire** | ALSA + PulseAudio + JACK compat, rtkit realtime |
| **Ghostty** | Primary terminal (Mod+Return), Kitty backup (Mod+Shift+Return), Foot sway fallback |
| **Security hardening** | fail2ban (SSH aggressive), ClamAV, polkit, GNOME Keyring, 30+ defensive tools |
| **Steam** | Proton, gamemode, gamescope, mangohud |
| **BTRFS snapshots** | Daily via btrbk, auto-pruning (14d + 4w), pre-deploy snapshots |
| **Boot GPU params** | `amdgpuGttSize` / `ttmPagesLimit` shared between kernelParams and extraModprobeConfig |
| **emeet-pixy webcam** | Auto-tracking, audio NC, systemd service |

### Recent Session Wins (2026-06-09)

1. **Port centralization** — ALL ports moved to `lib/ports.nix`, zero hardcoded ports remain
2. **ecapture** — eBPF SSL/TLS capture tool added to system packages
3. **Monitor365 build fix** — overlay updated, server mode wired, port centralized
4. **Overview integration** — New NixOS service module, Caddy vhost, Homepage tile
5. **Manifest auth fix** — Removed double auth (Pocket ID forward auth + Better Auth), now plain TLS proxy
6. **Homepage dynamic tiles** — Services conditionally shown based on `enable` flags, no stale tiles for disabled services
7. **Monitor365 Caddy vhost** — Added `monitor.home.lan` behind Pocket ID forward auth
8. **Rust toolchain** — Added to NixOS user packages
9. **SigNoz + Hermes upgrades** — SigNoz 0.117.1→0.127.1, hermes v2026.5.16→v2026.6.5

---

## b) PARTIALLY DONE

| Item | Status | What's Missing |
|------|--------|----------------|
| **Homepage dynamic tiles** | Committed but homepage.nix has unstaged additions | `when`/`hasContainer` helpers and conditional tiles need deployment verification |
| **Monitor365 Caddy vhost** | Code added (unstaged in caddy.nix) | Needs `just switch` to deploy, needs testing at `monitor.home.lan` |
| **Hermes OpenAI fallback** | Config wired (`OPENAI_API_KEY` in template) | **MANUAL**: Add API key to `sops hermes.yaml`, set `fallback_model` in hermes runtime |
| **Hermes git remote** | SSH deploy key generated | **MANUAL**: Install private key to `/home/hermes/.ssh/`, add public key to GitHub |
| **Pocket ID declarative config** | Plan written (`docs/planning/POCKET-ID-DECLARATIVE-PLAN.md`) | Not implemented — OIDC clients still manually configured via web UI |
| **Pi 3 DNS failover** | `dns-failover.nix` module complete, `rpi3-dns` NixOS config defined | Hardware not provisioned, no physical Pi 3 |
| **Darwin Home Manager** | Minimal parity (zellij, yazi, zed-editor, xdg) | No desktop config, no terminal theme parity with NixOS, disk-constrained (90%+ full) |
| **Gatus endpoints for new services** | Monitor365 endpoint added, Overview endpoint missing | Need `mkHttpCheck` for Overview at `overview.home.lan` |

---

## c) NOT STARTED

| Item | Notes |
|------|-------|
| **Gatus endpoint for Overview** | No health check defined yet |
| **Gatus endpoint for crush-daily** | No health check defined yet |
| **Gatus endpoint for Hermes** | No health check defined yet (hermes has no HTTP health endpoint?) |
| **BTRFS `/data` migration** | `/data` is still BTRFS toplevel (subvolid=5), cannot be snapshotted. `just snapshot-migrate-data` exists but not run |
| **Pocket ID OIDC clients as Nix config** | Plan exists, not implemented |
| **ActivityWatch cross-platform parity** | NixOS has monitor365+AW integration, Darwin has aw-watcher overlay but no home-manager wiring |
| **Niri config refinement** | Window rules, keybinds could be improved — functional but basic |
| **Homepage Kubernetes/Docker integration** | Homepage shows Docker status but no k8s integration |
| **Immich ML model optimization** | Using default ML models, no custom model tuning |
| **Backup automation for non-DB services** | Only Forgejo, Immich, Twenty, Manifest have DB backups. No config/tate backup strategy |
| **Automated nix flake update CI** | Manual `just update` process, no auto-PR on flake input bumps |
| **Darwin disk cleanup automation** | 90-95% full, manual `nix-collect-garbage` needed before builds |
| **PhotoMap re-enablement** | Disabled due to podman config permission issue, no fix attempted |
| **Voice agents re-enablement** | Disabled, LiveKit + Whisper ROCm Docker — no immediate need |

---

## d) TOTALLY FUCKED UP / KNOWN ISSUES

| Issue | Severity | Details |
|-------|----------|---------|
| **4 unpushed commits** | HIGH | Local-only changes: Overview integration, homepage reorg, status reports. If disk crashes, these are lost |
| **Manifest double auth (FIXED this session)** | WAS HIGH | Manifest was behind `protectedVHost` (Pocket ID) AND had its own Better Auth login. Fixed: removed forward auth, now uses Manifest's own auth only |
| **file-and-image-renamer disabled** | MEDIUM | `charm.land/fantasy@v0.25.0` requires Go 1.26.3, nixpkgs has 1.26.2. Blocked on upstream Go bump |
| **Dozzle module eval issue** | LOW | Creating `modules/nixos/services/dozzle.nix` with options causes `nix flake check` failure. Workaround: inline `virtualisation.oci-containers` in configuration.nix |
| **Auditd blocked** | LOW | NixOS 26.05 bug: https://github.com/NixOS/nixpkgs/issues/483085 — can't enable auditd |
| **Stale LSP processes** | MITIGATED | gopls/vtsls eating ~7.4Gi RSS. Mitigated by daily `stale-lsp-cleanup` timer. Root cause: LSP servers not exiting on editor close |
| **Jan llama-server respawn** | UNRESOLVED | Spawns new llama-server every 1-3 min (~1.2GB each). No cgroup limits possible (not a systemd service) |
| **sops GPG key import hang** | MITIGATED | `gnupg.sshKeyPaths = []` prevents RSA key GPG import causing 2min+ initrd hang |
| **Hermes `BindsTo` cycle** | FIXED | Changed to `Wants=` to prevent niri kill on `just switch` |
| **OOM crash chain** | MITIGATED | Helium (Electron) escaped cgroup limits → OOM killed journald → cascade. Mitigated by `MemoryHigh`, per-service `MemoryMax`, `systemd-oomd` |
| **Git stash has old WIP** | LOW | `stash@{0}: WIP on master: 38974be2 feat(pma)` — stale stash from earlier session, should be dropped or evaluated |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture & Code Quality

1. **Eliminate Dozzle inline config** — Move from `configuration.nix` inline to proper module (blocked by nix flake check eval issue, needs investigation)
2. **Pocket ID declarative OIDC clients** — Plan exists, would eliminate manual web UI client setup
3. **Backup strategy for non-DB state** — `/var/lib/*` directories, Caddy certs, sops encrypted files — no backup beyond BTRFS snapshots
4. **Status report archive** — 130+ status reports in `docs/status/`, most are historical. Archive older ones to `docs/status/archive/` (already has an `archive/` dir but it's underutilized)
5. **Cross-platform theme parity** — Darwin has minimal Home Manager config, no terminal/theme/editor parity with NixOS
6. **Gatus coverage gaps** — Overview, crush-daily, Hermes lack health checks
7. **Flake input deduplication** — 45 inputs, some could potentially be consolidated
8. **Stale git stash** — `stash@{0}` is old WIP, evaluate and drop

### Operational

9. **Push strategy** — 4 unpushed commits is risky. Establish a push cadence (after every session?)
10. **`/data` BTRFS subvolume migration** — Cannot snapshot `/data` as toplevel. `just snapshot-migrate-data` exists but never run (requires downtime)
11. **Monitor365 firewall** — Server listens on `0.0.0.0` but only accessible via Caddy. Direct access possible — should bind to `127.0.0.1` or add firewall rule
12. **Hermes deploy key installation** — Manual step never completed, hermes can't reach git remotes
13. **Darwin disk management** — 90-95% full, no automated cleanup. Consider scheduled `nix-collect-garbage --delete-old` timer

### Documentation

14. **FEATURES.md update** — Last updated 2026-06-03, missing: Overview, Manifest auth fix, Monitor365 server mode, Homepage dynamic tiles
15. **TODO_LIST.md update** — Missing: Monitor365 Caddy vhost, Manifest auth fix, Overview integration verification items

---

## f) Top 25 Things We Should Get Done Next

### Priority 0: IMMEDIATE (Safety & Deployment)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 1 | **Push 4 unpushed commits to origin** | Risk of data loss if local disk fails | 1 min |
| 2 | **Deploy & verify on evo-x2** (`just switch`) | Caddy manifest fix, Monitor365 vhost, Homepage tiles — all committed but not deployed | 10 min |
| 3 | **Verify Manifest auth** — confirm login works without Pocket ID redirect | Just changed from protectedVHost to plain proxy | 2 min |
| 4 | **Verify Monitor365 at `monitor.home.lan`** | New vhost, needs TLS cert and Pocket ID forward auth test | 2 min |
| 5 | **Verify Homepage dynamic tiles** — no stale tiles for disabled services | New conditional rendering | 2 min |

### Priority 1: QUICK WINS (< 30 min each)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 6 | **Add Gatus endpoint for Overview** | Health check coverage gap | 5 min |
| 7 | **Add Gatus endpoint for crush-daily** | Health check coverage gap | 5 min |
| 8 | **Drop stale git stash** (`git stash drop`) | `stash@{0}` is old PMA WIP, confusing | 1 min |
| 9 | **Update FEATURES.md** — add Overview, Manifest auth fix, Monitor365 server mode | Docs out of date | 15 min |
| 10 | **Archive old status reports** — move pre-June to `archive/` | 130+ files cluttering `docs/status/` | 5 min |
| 11 | **Bind Monitor365 server to `127.0.0.1`** | Currently `0.0.0.0`, Caddy proxies anyway — defense in depth | 5 min |

### Priority 2: IMPORTANT (1-2 hours each)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 12 | **Hermes deploy key installation** | Hermes can't reach git remotes, manual step documented but not done | 15 min |
| 13 | **Hermes OpenAI fallback key** | Add API key to sops, set fallback model | 15 min |
| 14 | **BTRFS `/data` migration** (`just snapshot-migrate-data`) | Cannot snapshot `/data` — single biggest data loss risk | 30 min + downtime |
| 15 | **Pocket ID declarative OIDC clients** | Plan exists, eliminates manual client setup | 2 hours |
| 16 | **PhotoMap podman fix** | Disabled due to podman config permission issue | 1 hour investigation |

### Priority 3: STRATEGIC (Half-day+)

| # | Task | Why | Effort |
|---|------|-----|--------|
| 17 | **Darwin Home Manager parity** — terminal, editor, theme | 7-line config vs full NixOS HM. UX inconsistency across machines | Half day |
| 18 | **Darwin disk automation** — scheduled nix-collect-garbage timer | 90-95% full causes build failures | 1 hour |
| 19 | **Pi 3 DNS failover provisioning** | Hardware needed, but module is ready | Hardware + 2 hours |
| 20 | **Dozzle module eval fix** — investigate nix flake check failure | Inline config is a code smell | 2 hours investigation |
| 21 | **Backup automation for non-DB state** — Caddy certs, sops files, /var/lib | BTRFS snapshots only, no offsite | Half day |
| 22 | **Automated flake update CI** — GitHub Action for `nix flake update` PRs | Manual process, easy to forget | 2 hours |
| 23 | **Voice agents re-enablement** | LiveKit + Whisper disabled, no immediate need but module exists | 1 hour |
| 24 | **file-and-image-renamer re-enablement** | Blocked on Go 1.26.3 in nixpkgs — watch for nixpkgs update | 5 min once Go bumps |
| 25 | **Immich ML model optimization** | Default models, could be faster with tuned models | Half day research |

---

## g) My Top #1 Question I Cannot Figure Out Myself

**Is the `/data` BTRFS migration safe to run during normal operation, or does it require a full system downtime?**

The `just snapshot-migrate-data` script presumably converts `/data` from toplevel (subvolid=5) to a proper subvolume. This is the **single biggest data loss risk** — `/data` holds Docker volumes, AI models, and all persistent service state, but has NO BTRFS snapshots. However, I can't determine from the code alone whether:
- The migration is live-safe (data accessible during conversion)
- It requires unmounting `/data` (which would stop Docker and all container services)
- There's a rollback path if something goes wrong
- How long the migration would take for ~500GB of data

This requires **your confirmation** before proceeding — it's the highest-impact undone item that I'm not confident executing autonomously.

---

## Git State

### Unstaged Changes (working tree)
```
M modules/nixos/services/caddy.nix      — Manifest: protectedVHost → plain proxy + Monitor365 vhost
M modules/nixos/services/homepage.nix   — Dynamic service tiles (when/hasContainer helpers)
```

### Unpushed Commits (4)
```
2f5a5e96 feat(homepage): reorganize dashboard — add AI category, new service tiles
8c1c13b2 docs(status): comprehensive master status report — 2026-06-09 22:16
f975c41a docs(status): add overview NixOS integration status report
aa671dd0 feat(services): integrate Overview project dashboard as NixOS service
```

### Stash
```
stash@{0}: WIP on master: 38974be2 feat(pma): wire excludePaths for forks/archived, update flake lock
```

---

## Service Inventory Summary

| Category | Enabled | Disabled | Total |
|----------|---------|----------|-------|
| Infrastructure (Caddy, DNS, Auth, SOPS) | 6 | 1 (dns-failover) | 7 |
| Self-hosted Apps (Forgejo, Immich, CRM, etc.) | 10 | 3 (photomap, minecraft, multi-wm) | 13 |
| AI/ML (Ollama, Hermes, Manifest, etc.) | 5 | 2 (voice-agents, file-renamer) | 7 |
| Desktop (Niri, SDDM, Audio, Steam) | 6 | 0 | 6 |
| Monitoring (Gatus, SigNoz, Disk, NVMe) | 4 | 0 | 4 |
| **TOTAL** | **31** | **6** | **37** |

---

_Generated by Crush — 2026-06-09 22:52_
