# SystemNix — Feature Inventory

_A brutally honest audit of every feature the project actually has._

**Generated:** 2026-05-03 | **Updated:** 2026-08-21 | **Scope:** Full codebase scan

---

## Status Legend

| Icon | Status               | Meaning                                    |
| ---- | -------------------- | ------------------------------------------ |
| ✅   | FULLY_FUNCTIONAL     | Complete, wired, tested, works as intended |
| ⚠️   | PARTIALLY_FUNCTIONAL | Mostly works, known gaps or edge cases     |
| 🔧   | DISABLED             | Code exists but not currently enabled      |
| 📋   | PLANNED              | Module/scaffold exists, not yet deployed   |
| ❌   | BROKEN               | Implemented but currently non-functional   |

---

## 1. Core Infrastructure

### Flake Architecture

| Feature                                   | Status | Notes                                                                                                                                    |
| ----------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Cross-platform Nix flake (Darwin + NixOS) | ✅     | Single flake, two systems, 80% shared via `platforms/common/`                                                                            |
| flake-parts modular architecture          | ✅     | 55 modules auto-discovered (60 files total, 5 `_`-prefixed helpers skipped). Run: `nix eval .#nixosModules --apply 'x: builtins.length (builtins.attrNames x)'` |
| nixpkgs tarball regression guard    | ✅     | Eval-time `nixpkgsTarballGuard` in `flake.nix`, pre-commit hook, CI normalization, `nix run .#fix-nixpkgs-lock` recovery. NixOS + Darwin registry override |
| Shared overlays (Darwin + NixOS)          | ✅     | NUR, aw-watcher, todo-list-ai, golangci-lint-auto-configure, mr-sync                                                                     |
| Linux-only overlays                       | ✅     | openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer, go-humanize-linter                                        |
| Shared Home Manager config                | ✅     | `sharedHomeManagerConfig` + `sharedHomeManagerSpecialArgs`                                                                               |
| Custom packages (pkgs/ + overlays)        | ✅     | 30 packages: 15 mkLarsPackages + 8 in pkgs/ + 7 flake-input overlays                                                                        |
| Formatter (treefmt + alejandra)           | ✅     | Via `treefmt-full-flake`                                                                                                                 |
| Flake checks (statix, deadnix, eval)      | ✅     | Per-system + Linux-specific                                                                                                              |
| Raspberry Pi 3 SD image build             | 📋     | `nixosConfigurations.rpi3-dns` defined, hardware not provisioned                                                                         |
| Go toolchain                              | ✅     | Uses nixpkgs Go directly (no custom overlay) — preserves binary cache                                                                    |

### Three System Targets

| System         | Hostname           | Platform       | Status     |
| -------------- | ------------------ | -------------- | ---------- |
| macOS          | `Lars-MacBook-Air` | aarch64-darwin | ✅ Active  |
| NixOS Desktop  | `evo-x2`           | x86_64-linux   | ✅ Active  |
| Raspberry Pi 3 | `rpi3-dns`         | aarch64-linux  | 📋 Planned |

---

## 2. NixOS Services (evo-x2)

### Infrastructure Services

| Service                        | Status | Module                 | Key Details                                                                                                                                  |
| ------------------------------ | ------ | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Docker                         | ✅     | `default-services.nix` | Always-on, overlay2, `/data/docker`, weekly auto-prune, user `lars` in docker group                                                          |
| Caddy (reverse proxy)          | ✅     | `caddy.nix`            | TLS via sops certs, forward auth via oauth2-proxy + Pocket ID, 16+ virtual hosts (14 auth-protected), metrics enabled, sops-nix boot ordering |
| SOPS secrets management        | ✅     | `sops.nix`             | Age-encrypted via SSH host key, 4 sops files, auto-restart per secret, ALL service-specific secrets guarded with `lib.optionalAttrs`         |
| Pocket ID (OIDC provider)      | ✅     | `pocket-id.nix`        | Passkey-only OIDC provider, Go backend, SQLite, web UI for user/client management                                                            |
| oauth2-proxy                   | ✅     | `oauth2-proxy.nix`     | Forward-auth bridge between Caddy and Pocket ID, cookie-based sessions                                                                       |
| DNS Failover (Keepalived VRRP) | 📋     | `dns-failover.nix`     | Two-node VRRP cluster, dnsblockd health tracking, GARP refresh — Pi 3 not provisioned                                                        |

### Self-Hosted Applications

| Service                               | Status | Module                               | Key Details                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------- | ------ | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Forgejo (Git forge)                   | ✅     | `forgejo.nix`                        | SQLite, LFS, weekly dumps, GitHub mirror + push mirrors, Actions runner (Docker + native), admin auto-setup, declarative SSH keys, federation enabled                                                                                                                                                                                                                                                                                         |
| Forgejo repos (declarative mirroring) | ✅     | `forgejo-repos.nix`                  | Auto-sync on rebuild + daily timer, push mirrors to GitHub, hardened oneshot, sops-managed tokens                                                                                                                                                                                                                                                                                                                                             |
| Homepage Dashboard                    | ✅     | `homepage.nix`                       | Catppuccin Mocha, programmatic `mkGroup`/`mkService` tiles, 5 categories, `ALLOWED_HOSTS`, cache dir, conditional tiles per service                                                                                                                                                                                                                                                                                                           |
| Immich (photo/video management)       | ✅     | `immich.nix`                         | PostgreSQL + Redis + ML, OAuth via Pocket ID, VA-API hardware transcoding (H.264/HEVC/AV1), ML GPU access. **Media lives on the HDD pool** since 2026-08-17 (`/mnt/pool/services/immich`, byte-exact verified migration, `RequiresMountsFor` on server+ML) — DB backup pool-side via mediaLocation                                                                                                                     |
| Paperless-ngx (document mgmt)         | ✅     | `paperless.nix`                      | v3 "superb" config (2026-08-18): port 2892 (`paperless.home.lan`, protectedVHost), `dataDir=/mnt/pool/services/paperless`, **PostgreSQL backend** (shared Immich instance, peer-auth; sqlite→PG engine migration oneshot), **Paperless AI on the NPU LLM** (FastFlowLM qwen3.6: classify/tag/title suggestions; embeddings/RAG OFF — embed co-load breaks the NPU model load), **Tika 9998 + Gotenberg 3199** (Office/E-Mail consume; gotenberg OTel→SigNoz with mandatory `http://` scheme), 30d trash dir, PATCHT barcode splitting + Code-39 ASN, v3 double-curly filename format, OCR deu+eng, `TASK_WORKERS=2`, exporter on, all units resource-tiered. Gatus: functional login-body check + both sidecars; deploy smoke in post-deploy-check; VM test `tests/test-paperless.nix` (caught the v3 filename deprecation). sops admin password via upstream `LoadCredential`. Backup: exporter manifests pool-side via dataDir. Old SQLite export recoverable from `export/` pending user decision |
| SigNoz (observability)                | ✅     | `signoz.nix`                         | Full-stack: traces/metrics/logs, ClickHouse, OTel Collector, node_exporter, cadvisor. **Web UI shipped** (2026-08-16: hermetic pnpm-10 frontend package, `web.enabled=true`, `/etc/signoz/web` store symlink, restartTriggers). 23 alert rules + 23 route policies converged per deploy (v5-v7 provisioner: PUT-in-place, no identity churn); 5 native-v2 Perses dashboards (`schemaVersion v6`, converging provisioner — was 251 v1-era zombies); enriched journald logs (OTTL: body=MESSAGE, PRIORITY→severity, service.name, ~6.8k rows/10min, 15d TTL); 9 scrape targets incl. collector self-scrape + ClickHouse + docker-engine; 3 meta-alerts (collector down, export failures, ClickHouse down). Custom `signoz.target`, JWT auto-generation, PSI metrics, CPUQuota=200% on all services |
| TaskChampion (Taskwarrior sync)       | ✅     | `taskchampion.nix`                   | Port 10222, TLS via Caddy, no forward auth, 100 snapshots / 14 days                                                                                                                                                                                                                                                                                                                                                                           |
| Twenty CRM                            | ✅     | `twenty.nix`                         | Docker Compose (4 containers), PostgreSQL + Redis, sops secrets, daily DB backup (registered in `backup-coordination`), Caddy at crm.home.lan (Layer 2 Pocket ID auth via oauth2-proxy; LAN bypass). ALL containers memory-bounded (server=1g+768M heap, worker=2g+1536M heap, db=2g, redis=256m) — prevents oomd kill loops. **Auth note:** native OIDC/SAML is a Twenty paid entitlement, so no in-app "Login with Pocket ID" exists. The historic `role "twenty" does not exist` crash was transient (PG volume recreation) — healthy since 2026-08-14                                                                                                                                                                                          |
| Dozzle (Docker log viewer)            | ✅     | inline `configuration.nix`           | OCI container, `logs.home.lan`, Docker socket mount, 300-line tail, running-only filter                                                                                                                                                                                                                                                                                                                                                       |
| Minecraft server                      | 🔧     | `minecraft.nix`                      | JDK 25, ZGC, firewall restricted to LAN, Prism Launcher client config, whitelist — disabled in config                                                                                                                                                                                                                                                                                                                                         |
| Manifest (LLM router)                 | ✅     | `manifest.nix`                       | Smart LLM router for AI agents, cost optimization, port 2099, `manifest.home.lan`                                                                                                                                                                                                                                                                                                                                                             |
| Overview (project dashboard)          | ✅     | `overview` flake input               | Local project dashboard, git repo discovery, stats, activity, port 8083                                                                                                                                                                                                                                                                                                                                                                       |
| Crush Daily (AI insights)             | ✅     | `crush-daily.nix`                    | AI-powered development insights from Crush databases, port 8081, `daily.home.lan`. Runs as `primaryUser` via `runAsUser` (fixes ACL `/home/lars` traversal). Silent-zero-data post-deploy assertion (`session_count > 0`). Fixed: CLI schema drift, SQLite DSN `file:` prefix, HTML template printf arg order.                                                                                                                                |
| OpenSEO (SEO suite)                   | ✅     | `openseo.nix` + `pkgs/openseo.nix`   | Self-hosted SEO: rank tracking, keyword research, backlinks. Native NixOS service (built from source via Vite/pnpm, workerd runtime), port 3002, `seo.home.lan`. GSC OAuth callback exempt from forward-auth, AI features conditional, `openseo-validate` ExecStartPre                                                                                                                                                                        |
| System Health Collector               | ✅     | `system-health.nix`                  | Prometheus textfile collector: systemd service state, `user-1000.slice` memory, GPUActive thresholds, monitor365 buffer pressure. Pre-computes boolean flags for Gatus `pat()` matching                                                                                                                                                                                                                                                       |
| ~~PhotoMap AI~~                       | ❌     | —                                    | Removed (2026-07-04): OCI container permission issue, niche feature, maintenance burden                                                                                                                                                                                                                                                   |
| Monitor365 (device monitoring)        | 🔧     | `monitor365.nix`                     | **DISABLED since 2026-08-12** (`enable = false` in configuration.nix): the vendored `wireguard-collector` crate lives in a PRIVATE LarsArtmann repo — the Nix build can never fetch it. Re-enable requires publishing/vendoring the crate (owner decision). Module remains complete: agent + server, DuckDB, dual-instance, native OIDC, schema-migrate oneshot, watchdogs, backup monitoring. Post-deploy checks auto-SKIP when units absent                                                                                                                       |
| PMA (auto-commit daemon)              | ✅     | `projects-management-automation.nix` | Watches ~/projects, AI commit messages, repo discovery daemon, debounce + min-interval. `ManagedOOMPreference=omit` + `OOMScoreAdjust=-1000` (survives discovery burst). Split-mode: passive discovery + active committer independently controllable                                                                                                                                                                                                                                                                                                                                                        |
| Gatus (health checks)                 | ✅     | `gatus-config.nix`                   | 120 health check endpoints (incl. 20 OSS project-website checks from the terraform inventory, nix-daemon liveness, ClickHouse ping, crash-loop/oomd/docker-restart/disk-usage/textfile-health detectors, buildcache mount+SMART, ZRAM fill, SigNoz Web UI), Discord alerting, SQLite storage (self-monitored by reading the sqlite directly — the HTTP API sits behind OIDC), port 9110, `status.home.lan` |
| Disk Monitor                          | ✅     | `disk-monitor.nix`                   | Desktop notifications at disk usage thresholds                                                                                                                                                                                                                                                                                                                                                                                                |
| NVMe Health Monitor                   | ✅     | `nvme-health-monitor.nix`            | Desktop notifications for critical NVMe SMART events                                                                                                                                                                                                                                                                                                                                                                                          |
| DiscordSync                           | ✅     | `discordsync.nix`                    | Continuous Discord channel backup bot — real-time sync via Discord Gateway, sqlite backend (local-first; Turso cloud sync DISABLED after free-plan quota exhaustion 2026-08-16 — local data safe, cloud offsite copy stale until plan decision), backfill, attachment downloads, SQLite corruption self-heal (`PRAGMA integrity_check` + `sqlite3 .recover` on boot), HTTP API (`/metrics`, `/api/events/stream`, `/api/export`) on port 8085 (localhost-only). Consumes upstream `nixosModules.default` (Monitor365 gold-standard pattern). GCS attachment backup opt-in via `gcsBucket`. OTel tracing into SigNoz.       |
| visionreviewd (lazy wrapper)          | ✅     | `visionreviewd.nix`                  | Thin wrapper module for the upstream visionreviewd flake service — lazy activation, eval-hardened (`packages.<sys>.default` + `lib.optionalAttrs` instead of a type-checked top-level `mkIf`)       |
| Qmd (global RAG search CLI + Crush MCP) | ✅ | flake input + crushrc | On-device hybrid search (BM25 + vector embeddings + LLM rerank) over markdown/code collections. Re-added 2026-08-20 as an upstream-flake global CLI (`github:tobi/qmd` tag pin) + stdio MCP server in Crush — NO service/port this time. The 2026-08-14 retirement was of the hand-rolled pnpm packaging + port-8181 HTTP service (NAR-hash drift); consuming upstream's bun flake moved the packaging burden upstream. Collections/index/models are user-local (`~/.config/qmd`, `~/.cache/qmd`) |
| SearXNG (privacy metasearch)          | ✅     | `searxng.nix`                        | Privacy-focused metasearch engine on port 8889 (`search.home.lan`). Built-in Granian ASGI server. Rate limiter + Redis REMOVED (private LAN, no abuse vector). POST→GET method switch, `query_in_title=true`. 71 engines across 5 categories. Layer 2 SSO via oauth2-proxy (no native OIDC). POST-only search (privacy), dark mode, favicon caching (DuckDuckGo). Browser default search engine via Chromium policy. `restartTriggers` on settings + package. |
| Attic binary cache                    | ✅     | `attic.nix`                          | Self-hosted Nix binary cache on port 8200 (`cache.home.lan`). RS256 JWT auth, DynamicUser + sops secret (owner=root), Prometheus metrics split from GC trigger, storage dir pre-creation service, cache bootstrap automation. NixOS VM test (6 assertions).                                                                                                                                                                                    |
| Browser History                       | ✅     | `browser-history.nix`                | Go CQRS/ES browser history server on port 8087 (`history.home.lan`). SQLite WAL, WebAuthn + OAuth2 (Pocket ID) dual auth. Direct TLS proxy (NOT `protectedVHost`). Agent extracts history from Firefox/Chromium profiles. OIDC oneshot via `LoadCredential`. `MAX_USERS=1` registration gate set (verify gate live in deployed binary — see TODO_LIST). **Startup is fast since the storage/v4.7.0 era** (input `4e7604d`: async drain + readiness gate + paged checkpoints killed the 4-min journal replay; keyset-pagination fix released upstream in go-cqrs-lite). `mkOidcGate` ExecStartPre survives simultaneous dnsblockd+server restarts. **Known gaps:** `expires_at` session reaper schema error, OAuth2 login not manually tested, `importUsers()` path ungated |
| PapDashboard (smart alerting hub)     | ✅     | `papdashboard.nix`                   | Alert lifecycle hub + NPU insight enricher on port 8088 (`alerts.home.lan`, Layer 2 protectedVHost — UI has no built-in auth, ingest API key-gated). Ingests every Gatus trigger/resolve via `POST /api/ingest` (dual-path design: raw Discord fast-path keeps flowing if PapDashboard dies); alerts match by (sourceApp, title), FTS5 search/filters. Insight enricher: FastFlowLM LLM + journald/URL evidence (best-effort, never fatal). Secrets via sops `papdashboard_api_key`. Ingest VERIFIED live (gatus 200s) since the 2026-08-18 two-bug fix (flake re-pin `ebbc6fa` + `method = "POST"` — lowercase method tokens 405 on Go ServeMux). Known debt: `journalUnits` default wrong unit name, no deploy smoke checks (TODO_LIST P1/P3) |
| bank-sync (Wise transaction sync)     | ✅     | `bank-sync.nix`                      | Wise bank transaction sync + read-only dashboard (`banksync.home.lan`), upstream flake module consumed (Monitor365 pattern). Data on the pool subvolume `/mnt/pool/services/bank-sync`; events AES-256-encrypted at rest with a dedicated key split into its own sops file (`bank-sync-encryption.yaml` — creatable with only the host PUBLIC age key; `mkSecretCheck` guard fails loudly on silent-unencrypted downgrade). Own system user + group. Gatus check + post-deploy smoke, enable-gated. Shipped disabled once (missing sops key blocked every deploy), re-enabled 2026-08-18 (`e3995077`) |
| google-sync (Drive→pool mirror)       | 🔧     | `google-sync.nix`                    | rclone one-way mirror Google Drive → `/mnt/pool/backups` every 5 min, ONE service / THREE mirrors (`gdrive` ~1.9 TB, `gdrive-shared` shared-with-me forest, `gwork`). Remote deletions park 30d in `google-drive-deleted/<remote>/` grace trees (Google Mirror mode minus its instant-deletion data loss). Mount-gated `google-sync-dirs` oneshot (the 226/NAMESPACE lesson: ReadWritePaths must exist pre-start) + placeholder-token `configCheck`. **Ships DISABLED pending OAuth go-live** (sops scaffold committed; user steps in TODO_LIST P0). Freshness marker registered in backup-coordination |

### AI / ML Stack

| Service                          | Status     | Module             | Key Details                                                                                                                                                                                        |
| -------------------------------- | ---------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Centralized AI model storage     | ✅         | `ai-models.nix`    | `/data/ai/` tree (14 dirs), env vars, tmpfiles rules — dependency for all AI services                                                                                                              |
| Ollama (LLM inference)           | ✅         | `ai-stack.nix`     | ROCm GPU, flash attention, 2 parallel, q8_0 KV, 1h keep-alive, 32G MemoryMax, auto-starts with `multi-user.target` (`mkForce []` removed)                                                          |     |
| llama.cpp (standalone)           | ✅         | `ai-stack.nix`     | ROCWMMA custom build. MFMA flag (`-DGGML_HIP_MMQ_MFMA=ON`) REMOVED — complete no-op on Strix Halo (gfx1150/RDNA 3.5). Flag only affects CDNA GPUs; RDNA uses WMMA via compiler builtins. **GPU acceleration works from interactive shells since 2026-08-18** — `rocmEnv` merged into `environment.sessionVariables` (was service-only for 136 days → silent CPU fallback) + `llama-server-rocm` wrapper bakes in the ROCm `LD_LIBRARY_PATH` for dlopen'd libs |
| gpu-python wrapper               | ✅         | `ai-stack.nix`     | ROCm env vars + LD_LIBRARY_PATH for GPU-accelerated Python                                                                                                                                         |
| FastFlowLM (NPU LLM server)      | ✅         | `fastflowlm.nix`   | Qwen3.6-35B-A3B MoE (~3B active, 13.6 GB mmap) on the AMD XDNA2 NPU; OpenAI-compatible `127.0.0.1:52625/v1`. Socket-activated: `Accept=true` inetd socket + per-connection `fastflowlm@.service` socat bridge to backend :52626 (systemd-socket-proxyd does NOT exist in nixpkgs — the original design died exit 127 for ~5 h). `MaxConnections=8` (flm hard limit 10), 1h idle TTL via journal-based idle check, `ioTier.background`, `OOMScoreAdjust=300`. Package `pkgs/fastflowlm.nix` (autoPatchelf + protobuf_32, deterministic XILINX_XRT wrapper). E2E smoke in post-deploy-check is the ONLY functional gate (cold-pins the model); Gatus must NOT probe the port (TCP keepalives pin 13.6 GB in RAM) — system-health service-state metrics instead |
| ComfyUI (image generation)       | ❌ Removed | —                  | Disabled — prefer using AI models via code directly                                                                                                                                                |
| Voice agents (LiveKit + Whisper) | 🔧         | `voice-agents.nix` | Docker ROCm Whisper, Caddy reverse proxy, UDP 50000-51000 — disabled in config                                                                                                                     |
| Hermes AI gateway                | ✅     | `hermes.nix`       | v0.19+ (default-branch tracking) — Discord bot, cron, messaging, edge-tts, exa, firecrawl, fal — system service, sops secrets, 4G memory limit, USR1 reload, multi-provider LLM wiring (GLM, MiniMax, Xiaomi, Synthetic, FAL). Downstream `registration_lifecycle` PYTHONPATH patch (upstream `py-modules` list omits it — crash-loops without the patch). **2026-08-20 hardening round:** read-only projects bind (`BindReadOnlyPaths` + `GIT_CONFIG_GLOBAL` safe.directory store + `TERMINAL_CWD`/`HERMES_WRITE_SAFE_ROOT` confinement), exec-preserving perms walk + `hermes-lsp-bin-heal` (restores LSP exec bits), versioned workspace AGENTS.md (`<!-- systemnix-workspace-doc: vN -->` marker install), read-only GitHub PAT scaffolding (sops placeholder + `hermes-git-credential` helper + `hermes-github-verify` canary, inert until PAT go-live), Gatus liveness/memory checks via system-health (`hermes` in monitoredServices), restart-churn metric (`system_service_restart_churn`), 82-assertion VM test (`tests/test-hermes.nix`) |

### Desktop & System Services

| Service                   | Status | Module                       | Key Details                                                                                                                                                                                                                                                    |
| ------------------------- | ------ | ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Niri (Wayland compositor) | ✅     | `niri-config.nix`            | niri-unstable, XWayland satellite, patched BindsTo→PartOf, OOMScoreAdjust=-900                                                                                                                                                                                 |
| SDDM display manager      | ✅     | `display-manager.nix`        | SilentSDDM, Catppuccin Mocha theme, Niri as default session                                                                                                                                                                                                    |
| PipeWire audio            | ✅     | `audio.nix`                  | ALSA + PulseAudio + JACK compat, rtkit realtime. WirePlumber HDMI profile priority rules (TV-pinned; `device.restore-profile = false`) — dynamic routing handled by smart-audio daemon (coexistence verification pending)                                                                |
| Security hardening        | ✅     | `security-hardening.nix`     | fail2ban (SSH aggressive), ClamAV, polkit, GNOME Keyring, 30+ security tools                                                                                                                                                                                   |
| Browser policies          | ✅     | `browser-policies.nix`       | YouTube Shorts Blocker + OneTab force-installed                                                                                                                                                                                                                |
| Steam gaming              | ✅     | `steam.nix`                  | extest, protontricks, gamemode (renice=10, GPU temp 80°C), gamescope, mangohud                                                                                                                                                                                 |
| Multi-WM (Sway backup)    | ✅     | `multi-wm.nix`               | Sway as backup at SDDM login — enabled in config                                                                                                                                                                                                               |
| File & Image Renamer (AI) | ✅     | `file-and-image-renamer.nix` | AI screenshot renaming via charm.land/fantasy. Watcher + health dashboard unified on `dataDir` state (split-brain fixed `b0c76b58`). Auth fallback via `ErrorTypeAuth` (upstream `8bf60bd`). Post-deploy-check asserts `total_operations > 0`.                 |
| Helium auto-restart       | ✅     | `niri-wrapped.nix`           | systemd user service (`helium.service`) with `Restart=always`, `RestartSec=5`, `StartLimitBurst=10`. `helium-launch` wrapper pgrep-checks existing process to prevent empty-window crash loop. Recovers from niri zero-output client death on display hotplug. Anti-throttle flags: `--disable-background-timer-throttling`, `--disable-backgrounding-occluded-windows`, `--disable-renderer-backgrounding`, `--disable-background-media-suspend` (prevents 1–3 FPS video under I/O contention). |
| Smart-audio daemon        | ✅     | `smart-audio.nix`            | Niri-focus-following HDMI audio router (`services.smart-audio.enable`, user service). Python stdlib daemon watches `niri msg --json event-stream`, maps focused workspace → output → Radeon HDMI profile, switches via `wpctl set-profile` + `wpctl set-default` (HDMI profiles are mutually exclusive on the Radeon card — profile switching, not just sink switching). JSON IPC over unix socket for DMS integration. Gatus socket health probe. Audible-output + reverse-direction tests pending |
| Session boot audit        | ✅     | `session-boot-audit.nix`     | Eval-time guard (`services.session-boot-audit`): fails `nix flake check` if any user unit reachable from `default.target` Wants/Requires/BindsTo `graphical-session.target` (the 2026-08-18 headless-zombie-niri black-screen class). Graphs NixOS-shape, HM-shape, and raw-text user units with canonical name merging; reports the full offending chain; `allowedUnits` escape hatch. CI-negative-tested in `tests/test-session-boot-audit.nix` (4 cases incl. the exact historical bug) |

### Monitoring

| Service                | Status | Module           | Key Details                                         |
| ---------------------- | ------ | ---------------- | --------------------------------------------------- |
| SigNoz observability   | ✅     | `signoz.nix`     | See Self-Hosted Applications above                  |
| Monitoring tools (CLI) | ✅     | `monitoring.nix` | radeontop, strace, ltrace, nethogs, iftop, netwatch |

---

## 3. Cross-Platform Programs (Home Manager)

### Shells

| Program                | Status | Notes                                                                                              |
| ---------------------- | ------ | -------------------------------------------------------------------------------------------------- |
| Fish                   | ✅     | Primary shell — shared aliases, Carapace completions, 5k history, autosuggestions, GOPATH in PATH, direnv per-command caching (46ms→0.7ms), starship/fzf/carapace init caching |
| Zsh                    | ✅     | Autosuggestions + syntax highlighting, XDG dotdir, `~/.env.private` sourcing                       |
| Bash                   | ✅     | Shared aliases, erase-dups history, cdspell/autocd/globstar                                        |
| Starship prompt        | ✅     | Performance-tuned: 400ms timeout, 30+ modules disabled, only Go/Node/Nix shown, colorScheme-driven |
| Shell aliases (shared) | ✅     | `shell-aliases.nix` — DRY across Fish/Zsh/Bash (ADR-002)                                           |

### Development Tools

| Program          | Status | Notes                                                                                                                                                      |
| ---------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Git              | ✅     | GPG signing, SSH multiplexing, HTTPS→SSH rewrite, Git Town aliases, LFS, `.crush` in global ignores                                                        |
| Tmux             | ✅     | Resurrect + yank plugins, custom SystemNix dev session, vi copy-mode, Catppuccin-themed status bar                                                         |
| Fzf              | ✅     | Fish/Zsh/Bash integration, reverse layout, rg-powered, colorScheme-driven colors                                                                           |
| Pre-commit hooks | ✅     | 10 hooks: gitleaks, trailing-whitespace, deadnix, statix, alejandra, nix-check, flake-lock-validate, shellcheck, check-merge-conflicts, protect-home-audit |
| Go environment   | ✅     | GOPATH/GOPRIVATE/GONOSUMDB, `~/go/bin` in PATH, gopls without modernize                                                                                    |
| Node.js/Bun/pnpm | ✅     | Via base.nix packages                                                                                                                                      |

### Applications

| Program               | Status | Platform | Notes                                                                                              |
| --------------------- | ------ | -------- | -------------------------------------------------------------------------------------------------- |
| ActivityWatch         | ✅     | Linux    | Wayland window watcher + utilization watcher (5s poll), dark theme on startup                      |
| ActivityWatch (macOS) | ✅     | Darwin   | LaunchAgent auto-start, aw-watcher-utilization via Nix package                                     |
| KeePassXC             | ✅     | Both     | Browser integration, Chromium + Helium native messaging manifests, dark/compact mode               |
| Chromium              | ✅     | Darwin   | Brave as primary, VAAPI decode/encode, YouTube Shorts Blocker extension                            |
| Chromium (NixOS)      | ✅     | Linux    | System-wide via `browser-policies.nix` module                                                      |
| Taskwarrior 3         | ✅     | Both     | Sync to `tasks.home.lan`, deterministic UUID client ID, Catppuccin Mocha colors, daily JSON backup |
| SSH config            | ✅     | Both     | Via `nix-ssh-config` flake input — 7 hosts: onprem, evo-x2, 4× Hetzner private cloud               |

### Theme & Appearance

| Feature                   | Status | Notes                                                          |
| ------------------------- | ------ | -------------------------------------------------------------- |
| Catppuccin Mocha (global) | ✅     | Universal theme — GTK, icons, cursor, fonts, all apps          |
| Nix-colors integration    | ✅     | `colorScheme` passed as specialArg, drives Starship/Fzf/Qt/GTK |
| Bibata cursor (96px)      | ✅     | Linux — Bibata-Modern-Classic via fonts.nix                    |
| JetBrainsMono Nerd Font   | ✅     | Terminal font everywhere                                       |
| Papirus icons             | ✅     | Dark variant across platforms                                  |

### Fonts (Linux)

| Font                             | Status | Notes             |
| -------------------------------- | ------ | ----------------- |
| JetBrains Mono Nerd Font         | ✅     | Primary monospace |
| Fira Code Nerd Font              | ✅     | Alternative mono  |
| Iosevka Nerd Font                | ✅     | Alternative mono  |
| Noto Fonts (regular, emoji, CJK) | ✅     | Unicode fallback  |

---

## 4. NixOS Desktop (evo-x2)

### Window Management

| Feature                         | Status | Notes                                                                                                                                                               |
| ------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Niri (scrolling-tiling Wayland) | ✅     | Extensive config: 5 named workspaces, window rules, vim-style keybindings, preset column widths                                                                     |
| Niri session save/restore       | ✅     | Crash recovery: 60s timer, workspace-aware restore, floating state, column widths, focus order, kitty CWD/child proc capture                                        |
| Niri keybindings (80+)          | ✅     | DMS spotlight/clipboard/keybinds IPC (app, clipboard, emoji, calc, cheatsheet), screenshots (grim+slurp+swappy), media keys, brightness (ddcutil), random wallpaper |
| XWayland support                | ✅     | xwayland-satellite installed                                                                                                                                        |

### Desktop Shell (DankMaterialShell / Quickshell)

| Component                | Status | Notes                                                                                                                                                                                            |
| ------------------------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| DankMaterialShell (DMS)  | ✅     | v1.4.6 on Quickshell v0.2.1 — replaces Waybar, Dunst, Wlogout, Swaylock, polkit-gnome. Owns `org.freedesktop.Notifications`, `org.gnome.ScreenSaver`, `org.kde.StatusNotifierWatcher` DBus names |
| DMS status bar (DankBar) | ✅     | System monitoring, media, clock, tray — replaces Waybar's 15+ modules                                                                                                                            |
| DMS notifications        | ✅     | Full notification daemon with popup history, replaces Dunst                                                                                                                                      |
| DMS lock screen          | ✅     | `dms ipc lock lock` via Mod+Shift+Escape; swaylock-effects fallback (wallpaper + blur, Catppuccin Mocha). Shared `pkgs/dms-lock.nix`                  |
| DMS power menu           | ✅     | Replaces wlogout — lock/hibernate/logout/shutdown/suspend/reboot                                                                                                                                 |
| DMS polkit agent         | ✅     | Replaces polkit-gnome                                                                                                                                                                            |
| DMS OSD                  | ✅     | Volume/brightness/media overlay                                                                                                                                                                  |
| DMS clipboard manager    | ✅     | Owns clipboard history exclusively (cliphist service retired 2026-06-30)                                                                                                                         |
| DMS wallpaper management | ✅     | DMS IPC wallpaper cycling (`dms ipc call wallpaper next`, Mod+W). `dms-wallpaper-init` seeds from `~/.local/share/wallpapers/`. DMS derives cycling directory from current wallpaper's parent dir. Dynamic theming DISABLED (Catppuccin Mocha preserved). swww RETIRED (ghost service crash-loop)             |
| DMS calendar/events      | ✅     | `enableCalendarEvents = false` (khal available, disabled)                                                                                                                                        |
| DMS audio wavelength     | ✅     | cava-based visualizer (`enableAudioWavelength`)                                                                                                                                                  |

### DMS Plugins (13 SystemNix + 2 community)

| Plugin                   | Service           | Bar Pill                                   |
| ------------------------ | ----------------- | ------------------------------------------ |
| systemnix-ollama         | Ollama AI         | Model + VRAM + temp                        |
| systemnix-dns-stats      | DNS Blocker       | Queries/blocks                             |
| systemnix-gpu-monitor    | AMD GPU           | Util % + temp                              |
| systemnix-task-radar     | Taskchampion      | Pending/overdue                            |
| systemnix-service-health | Gatus             | Up/down dot                                |
| systemnix-btrfs          | btrbk timer       | Days since snapshot + disk %               |
| systemnix-voice-agent    | Whisper + LiveKit | Pulsing mic icon                           |
| systemnix-camera         | eMeet PixyD       | Camera name/off                            |
| systemnix-servers        | CPU/RAM/Disk      | Triple bar chart                           |
| systemnix-crm            | Twenty CRM        | Latency ms                                 |
| systemnix-dual-wan       | WAN failover      | DUAL/PRI/SEC/DOWN (auto-detect interfaces) |
| systemnix-npu            | AMD NPU           | MHz + load %                               |
| systemnix-sops           | Sops secrets      | Secret count + key status                  |

### Desktop Components (Remaining)

| Component                     | Status | Notes                                                                                                               |
| ----------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------- |
| DMS spotlight (launcher)      | ✅     | Replaces rofi — `dms ipc call spotlight toggle` (Mod+D/Mod+Space). App, file, window search                         |
| Focus-new-windows daemon      | ✅     | User service watching the niri event stream — follows spotlight launches to their `open-on-workspace` target via `focus-window --id` |
| DMS clipboard modal           | ✅     | Replaces rofi cliphist — `dms ipc call clipboard toggle` (Alt+C)                                                    |
| DMS keybinds modal            | ✅     | Replaces `niri msg binds                                                                                            | rofi -dmenu`—`dms ipc call keybinds toggle niri` (Mod+Shift+/) |
| DMS emoji launcher            | ✅     | Community plugin dms-emoji-launcher — `dms ipc call spotlight toggleQuery ":e"` (Mod+.)                             |
| DMS calculator                | ✅     | Community plugin DankCalculator — `dms ipc call spotlight toggleQuery "="` (Mod+Shift+C)                            |
| Rofi (Sway fallback)          | ✅     | Sway backup WM only — grid layout (5×3), Catppuccin Mocha, Papirus icons. Niri uses DMS spotlight                   |
| Yazi (file manager)           | ✅     | Catppuccin Mocha theme, file type associations, Ctrl-key keybindings, Zed integration, fd/rg search                 |
| Zellij (terminal multiplexer) | ✅     | Catppuccin Mocha, tmux-compatible keybindings (Ctrl+A), 3 custom layouts (dev/monitoring/default)                   |
| Kitty (terminal)              | ✅     | Font size 16 (TV-friendly), 85% opacity, Catppuccin Mocha, Nix GC resilience patch                                  |
| Foot (terminal)               | ✅     | Lightweight Wayland alt, JetBrainsMono size 12, 95% opacity                                                         |
| Swayidle                      | ✅     | 12h idle → suspend, lock before sleep. `sway-audio-idle-inhibit` prevents idle during audio playback |
| SSH suspend guard             | ✅     | Holds `sleep` block inhibitor via `systemd-inhibit` while SSH sessions active — prevents suspend during remote work |
| Cliphist CLI                  | ✅     | Package kept for manual use; always-on service retired (DMS owns clipboard history)                                 |

### Hardware Support

| Hardware              | Status | Notes                                                                                                                                     |
| --------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| AMD GPU (Strix Halo)  | ✅     | amdgpu, Mesa, RADV Vulkan, ROCm (clr.icd, rocblas), VA-API, 32-bit support, nvtop, amdgpu_top, corectrl                                   |
| AMD NPU (XDNA)        | ✅     | XRT driver, Boost 1.87 fix, dev tools, unlimited memlock                                                                                  |
| Realtek 2.5G Ethernet | ✅     | `r8125` extra module package (not in mainline kernel)                                                                                     |
| MediaTek WiFi/BT      | ✅     | `mt7925e` module                                                                                                                          |
| EMEET PIXY webcam     | ✅     | Full daemon: call detection, auto-tracking, noise cancellation, privacy mode, PipeWire source switch, DMS camera plugin, hotplug recovery |
| Bluetooth             | ✅     | Power-on-boot, A2DP source/sink (Google Nest Audio), Blueman GUI                                                                          |
| DDC/CI brightness     | ✅     | i2c-dev kernel module, ddcutil for external monitor brightness                                                                            |
| BTRFS root (`/`)      | ✅     | zstd compression, noatime, `commit=300` (5min metadata commit), `nodiscard` (QLC NAND I/O choke)                                                                                                         |
| BTRFS data (`/data`)  | ✅     | zstd:3 compression, `commit=300`, `nodiscard`, space_cache=v2 — Docker lives here                                                                                           |
| FAT32 boot (`/boot`)  | ✅     | Restrictive masks (fmask=0077, dmask=0077)                                                                                                |
| BTRFS snapshots       | ✅     | btrbk: daily snapshots of root (@) + /data, 14d + 4w retention, weekly autoScrub (incl. `/mnt/pool`), verify timer alerts stale snapshots. **Since 2026-08-17 root+data also SEND to the HDD pool** (`/mnt/pool/backups/{root,data}`, 30d 12w target retention, mount-gated) + `btrbk-pool` (23:45) snapshots the pool's `services/*` subvols; `btrfs-verify-pool-backups` daily guard                                                                                          |
| BTRFS weekly balance  | ✅     | `btrfs-health.nix`: metadata (`-musage=50`) Mon 04:00 + bounded data (`-dusage=50 -dlimit=10`) Mon 05:00. Both guarded by `btrfs-chunk-check` (skip if unallocated < threshold). Prevents metadata ENOSPC crash mode |
| BTRFS emergency reserve | ✅   | `btrfs-emergency-reserve.service`: 10 GiB `fallocate` at boot. Delete for instant free space during recovery. Prometheus metrics + Gatus alert if missing                    |
| HDD backup pool (`/mnt/pool`) | ✅ | 2× Toshiba MG08ACA16TE 16 TB in BTRFS RAID1 (`pool`, by-id fstab, `noatime,compress=zstd,commit=300,nofail`). Subvols: `services/{immich,paperless,monitor365,discordsync,browser-history}` (own-tools reserved), `backups`, `archive`. Holds: btrbk root+data sends, forgejo dumps (03:30, 7d), pocket-id sqlite backups (04:00, 14d), Twenty+Manifest pg_dumps (`backup.dir` in `mkDockerService`), immich DB backup, paperless exports, private-cloud forensic archive. smartd `-d sat` on both members; weekly scrub; `btrfs-verify-pool-backups` daily guard. **Second copy of irreplaceables on different physical disks — closes the single-NVMe risk** (true off-site still open) |
| BTRFS health metrics  | ✅     | Prometheus textfile: `btrfs_scrub_status`, `btrfs_scrub_errors_total`, `btrfs_scrub_error_free`, `btrfs_device_unallocated_bytes`. Requires `CAP_SYS_ADMIN`                 |
| Daily fstrim          | ✅     | QLC NAND SLC cache maintenance. Changed weekly → daily (CoW churn exhausts cache within 22-47h). Idle I/O priority (`IOSchedulingClass=idle`, `Nice=10`). Gatus alert if >30min                          |
| ZRAM swap             | ✅     | 30% of visible RAM (~28 GiB compressed, ~3.2x zstd level 1), `vm.swappiness=150` (zram-only correct — prefers in-RAM swap over disk page-cache reclaim)                                                            |
| AMD virtualization    | ✅     | KVM-AMD + AMD microcode updates                                                                                                           |

### Networking & DNS

#### DNS Stack (dnsblockd with embedded sdns resolver)

The DNS blocker uses dnsblockd's embedded sdns recursive resolver — the sole DNS resolver on :53. Unbound was fully removed (2026-07-13). dnsblockd lives in its own repo (`github.com/LarsArtmann/dnsblockd`).

| Component                   | Status | Notes                                                                                                                                                                        |
| --------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| dnsblockd embedded resolver | ✅     | sdns recursive resolver: DNSSEC, DoT/DoH listeners, caching, local zones with NXDOMAIN boundaries, LAN ACLs, cache flush on blocklist reload, IPv6 disable                   |
| dnsblockd (Go app)          | ✅     | ~930-line production Go: dynamic TLS cert generation per domain (SNI-based, CA-signed), Catppuccin-themed block page UI                                                      |
| Blocklist processing        | ✅     | Build-time: 23 blocklists fetched via `fetchurl` (StevenBlack + HaGeZi ultimate/tif/doh + 14 native device trackers), processed by `dnsblockd process` into dnsblockd config |
| 10-category system          | ✅     | Advertising 📢, Tracking 👀, Analytics 📊, Malware 🦠, Phishing 🎣, Gambling 🎰, Adult 🔞, Social 💬, Crypto 💰, Scam 🎭                                                     |
| Temp-allow API              | ✅     | Bypass blocks for 5m/15m/60m/24h via web UI, auto-redirects after allow, dnsblockd reload + cache flush                                                                      |
| False positive reporting    | ✅     | `/api/report` endpoint, last 100 reports in memory                                                                                                                           |
| Prometheus metrics          | ✅     | `dnsblockd_blocked_total`, `dnsblockd_active_temp_allows`, `dnsblockd_false_positive_reports` on `/metrics`                                                                  |
| Stats API (port 9090)       | ✅     | Top blocked domains, recent blocks (100), health endpoint, total blocked count, uptime                                                                                       |
| Firefox policy integration  | ✅     | Disables browser DoH, installs CA cert, locks prefs (swipe gestures, default browser check)                                                                                  |
| NSS CA cert import          | ✅     | User service imports CA cert for graphical sessions                                                                                                                          |
| sops-nix secrets            | ✅     | CA cert/key + server cert/key encrypted at rest                                                                                                                              |
| Coverage                    | ✅     | 2.5M+ domains blocked, `.lan` domains protected, whitelist for immich.app/GitHub/etc, Reddit forced NXDOMAIN                                                                 |
| Systemd hardening           | ✅     | ProtectSystem=strict, ProtectHome, PrivateTmp, capability restrictions                                                                                                       |
| dnsblockd OOM mitigation    | ✅     | `MemoryMax=4G` + `GOMEMLIMIT=3GiB` (raised from 2G/1500MiB after 730 oomd kills/day). Root cause: unbounded OTEL cardinality (dns_domain, http_path labels). Mitigated, upstream fix pending. oomd exemption still pending (P0)                             |

#### Network Infrastructure

| Feature                    | Status | Notes                                                                                                                                                                                                        |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Static IP networking       | ✅     | `eno1` 192.168.1.150, no DHCP/NetworkManager                                                                                                                                                                 |
| Firewall                   | ✅     | TCP 22,53,80,443; UDP 53,853                                                                                                                                                                                 |
| Centralized network config | ✅     | `local-network.nix` module options — lanIP, gateway, subnet, blockIP, virtualIP, piIP                                                                                                                        |
| Local DNS records          | ✅     | auth/immich/forgejo/dash/signoz/tasks/crm/manifest/status/seo/daily/logs/monitor/dnsblock/search/history/cache → `*.home.lan` (explicitly listed in `localSubdomains` — dnsblockd does NOT support wildcard local records) |
| Mullvad VPN                | 🔧     | WireGuard VPN — **disabled** (talpid_dns corrupted `/etc/resolv.conf`). Config kept for future re-enablement                                                                                                 |
| Dual-WAN (MPTCP)           | ✅     | MPTCP dual-WAN with route health monitoring, automatic failover                                                                                                                                              |
| SSH banner                 | ✅     | Legal warning banner on SSH login                                                                                                                                                                            |
| Private cloud cluster      | ✅     | 4 Hetzner servers (`private-cloud-hetzner-0` through `-3`) defined in SSH config                                                                                                                             |

### System Reliability

| Feature                           | Status | Notes                                                                                                                                         |
| --------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| systemd-oomd                      | ✅     | PSI-based OOM killer (replaces earlyoom). Tuned: 60%/30s pressure threshold (raised from 50%/20s which killed nix-daemon mid-build and the Twenty worker in steady-state), per-slice limits, `user-1000.slice` MemoryHigh=80G/MemoryMax=90G. nix-daemon + PMA exempt via `ManagedOOMPreference=omit`. Takes effect after reboot |
| OOM protection                    | ✅     | sshd (-1000), journald (-500), dms/quickshell (-500), pipewire (-500)                                                                         |
| Systemd watchdog (sd_notify only) | ✅     | Caddy, Forgejo — correctly limited to Type=notify services                                                                                    |
| Service failure notifications     | ✅     | `notify-failure@` template — desktop + syslog fallback                                                                                        |
| Session boot-transaction guard    | ✅     | `session-boot-audit.nix` eval-time assertion: no user unit reachable from `default.target` may `Wants/Requires/BindsTo=graphical-session.target` (the 2026-08-18 black-screen class). Graphs NixOS-shape + HM-shape + raw-text units, canonical-name dedupe, `allowedUnits` escape hatch. Permanent CI negative test (`tests/test-session-boot-audit.nix`, pure eval — the only surface that forces assertions) |
| Service health check              | ✅     | Every 15 min, critical services, desktop notification on failure                                                                              |
| BTRFS scrub                       | ✅     | Weekly auto-scrub on `/` and `/data` (changed from monthly: frequent reboots interrupted monthly scrub)                                       |
| Smart monitoring                  | ✅     | smartd with scheduled short/long tests                                                                                                        |
| Nix GC                            | ✅     | Weekly, delete older than 7 days, auto-optimise-store                                                                                         |
| systemd-boot                      | ✅     | 50 generation limit, latest kernel                                                                                                            |
| BFQ I/O Priority Tiers            | ✅     | 7-tier BFQ scheduling (`lib/default.nix`): sshd (BE/1), desktop (BE/3), default (BE/4), heavy DB (BE/5), background (BE/6), build (BE/7+Nice), maintenance (idle). `verify-io-tiers` flake app validates assignments. Prevents build storms from freezing SSH and desktop compositor on QLC NAND |
| GOMEMLIMIT on Go services         | ✅     | 8 Go services (discordsync, browser-history, PMA, signoz-query, signoz-otel 768MiB, pocket-id, crush-daily, file-and-image-renamer) configured with `GOMEMLIMIT` at ~75% of MemoryMax. dnsblockd has tuned value (3GiB) from OOM data |
| Build cache SSD (`/mnt/buildcache`) | ✅     | 240 GB SanDisk on USB 3.0 (`services.buildcache`): ext4 `data=writeback`, holds GOCACHE/GOMODCACHE/golangci-lint/goimports/Rust targets/npm/pnpm/pip/Playwright — ~115 GB of rebuildable caches off the QLC NVMe. Gatus: mount + SMART + usage alerts. smartd `-d sat` on both USB SSDs. No TRIM via bridge; drive is disposable-by-design |

### Scheduled Tasks

| Task                    | Schedule         | Notes                                                |
| ----------------------- | ---------------- | ---------------------------------------------------- |
| Crush provider update   | Daily 00:00      | Updates AI provider configs                          |
| Blocklist auto-update   | Weekly Mon 04:00 | Downloads + hashes blocklists                        |
| Service health check    | Every 15 min     | Checks critical services                             |
| Docker prune            | Weekly Mon 03:00 | Prunes >168h                                         |
| fstrim                  | Daily            | Idle I/O priority. QLC NAND SLC cache maintenance   |
| Immich DB backup        | Daily            | 7-day retention, pool-side                           |
| Twenty DB backup        | Daily            | 30-day retention, pool-side (`backup.dir`)           |
| Manifest DB backup      | Daily            | Pool-side (`backup.dir`)                             |
| Forgejo dump            | Daily 03:30      | Full `forgejo dump` zip → pool, 7-day retention      |
| Pocket-ID sqlite backup | Daily 04:00      | WAL-safe `.backup` → pool, 14-day retention          |
| Paperless export        | Daily            | Exporter manifests on pool via dataDir               |
| btrbk-pool snapshots    | Daily 23:45      | Pool `services/*` subvols                            |
| btrfs-verify-pool-backups | Daily          | Mount + device stats + received-backup freshness     |
| Taskwarrior JSON backup | Daily            | 30-day retention                                    |
| Stale LSP cleanup       | Every 5 min      | Kills gopls/vtsls/rust-analyzer/lua-ls running >5min |
| Stale nix sandbox cleanup | Daily          | Removes `/nix/var/nix/builds` sandboxes untouched >24h |
| Rust target cleanup     | Weekly Sun 05:00 | Prunes stale `target/` dirs in Rust projects         |
| Disk growth check       | Daily            | Alerts if /data grows >5G/24h                        |

---

## 5. macOS (Darwin)

### System Configuration

| Feature                          | Status | Notes                                                                                      |
| -------------------------------- | ------ | ------------------------------------------------------------------------------------------ |
| nix-darwin system management     | ✅     | Full declarative macOS config                                                              |
| Homebrew (nix-homebrew)          | ✅     | Declarative taps, auto-migrate, headlamp cask                                              |
| Nix sandbox                      | ⚠️     | **Explicitly disabled** (`lib.mkForce false`) — macOS sandbox compatibility tradeoff       |
| macOS Application Firewall (ALF) | ✅     | Enabled, allows signed apps, no stealth mode. Per-app rules via Little Snitch              |
| Wake-on-LAN                      | ✅     | Explicitly disabled (laptop power saving)                                                  |
| Dark mode                        | ✅     | Driven by shared `preferences.appearance.variant` — not hardcoded, cross-platform          |
| System defaults                  | ✅     | Fast key repeat (2/15), trackpad tap-to-click + 3-finger drag, Finder list view + path bar |
| State version                    | ✅     | nix-darwin `stateVersion = 6`                                                              |

### Security

| Feature                    | Status | Notes                                                                                                                                         |
| -------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Touch ID for sudo (PAM)    | ✅     | `pam_tid.so` enabled, Apple Watch disabled, **tmux reattach enabled** (fixes TouchID inside multiplexers)                                     |
| Keychain auto-lock         | ✅     | 5-minute inactivity timeout via activation script (`security set-keychain-settings`)                                                          |
| Chrome enterprise policies | ✅     | YouTube Shorts Blocker force-installed, HTTPS-only, sign-in disabled, password manager disabled, Safe Browsing enabled, Manifest V2 preserved |
| GPG signing                | ✅     | OpenPGP for Git commits, osxkeychain credential helper                                                                                        |

### File Associations & Integration

| Feature                      | Status | Notes                                                                            |
| ---------------------------- | ------ | -------------------------------------------------------------------------------- |
| File associations (duti)     | ✅     | `.txt/.md/.json/.jsonl/.yaml/.yml/.toml/.d2` → Sublime Text 4, `.rtf` → TextEdit |
| Build-time d2 verification   | ✅     | Self-test asserts d2 binary + file associations are correct                      |
| Nix Apps Spotlight indexing  | ✅     | `mdimport` for `/Applications/Nix Apps`                                          |
| Launch Services registration | ✅     | `/Applications/Nix Apps` registered on activation                                |

### Services (LaunchAgents)

| Service                   | Status | Notes                                                |
| ------------------------- | ------ | ---------------------------------------------------- |
| ActivityWatch auto-start  | ✅     | `aw-qt --no-gui`, KeepAlive, background process      |
| SublimeText settings sync | ✅     | Daily at 18:00, exports to dotfiles                  |
| aw-watcher-utilization    | ✅     | Nix-managed system resource monitor → localhost:5600 |
| Crush AI provider update  | ✅     | Daily at midnight, updates AI provider configs       |

### Darwin Packages

| Feature        | Status | Notes                                                                         |
| -------------- | ------ | ----------------------------------------------------------------------------- |
| Helium browser | ✅     | Default browser (`BROWSER=helium`), with Widevine DRM + VAAPI hardware accel  |
| iTerm2         | ✅     | Default terminal (`TERMINAL=iTerm2`)                                          |
| Google Chrome  | ✅     | Secondary browser with enterprise policies                                    |
| JetBrains IDEA | ✅     | Full IDE                                                                      |
| Go toolchain   | ✅     | Uses nixpkgs Go (1.26.x) directly — no custom overlay, preserves binary cache |

---

## 6. Custom Packages (pkgs/)

| Package                      | Language | Status | Notes                                                                                                                                                                                         |
| ---------------------------- | -------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| aw-watcher-utilization       | Python   | ✅     | ActivityWatch system utilization watcher                                                                                                                                                      |
| dnsblockd                    | Go       | ✅     | ~930-line DNS blocker: dynamic TLS, temp-allow API, false positive reporting, Prometheus metrics, 10-category system, Catppuccin block page — source in `platforms/nixos/programs/dnsblockd/` |
| emeet-pixyd                  | Go       | ✅     | EMEET PIXY webcam daemon — via flake input                                                                                                                                                    |
| monitor365                   | Rust     | ✅     | Device monitoring agent — source-only flake input                                                                                                                                             |
| qmd                          | Node.js/Bun | ✅ | On-device hybrid RAG search — consumed from the upstream flake (`github:tobi/qmd`, tag-pinned)                                                                                                                                |
| netwatch                     | Rust     | ✅     | Real-time network diagnostics TUI                                                                                                                                                             |
| openaudible                  | AppImage | ✅     | Audible audiobook manager                                                                                                                                                                     |
| jscpd                        | Node.js  | ✅     | Copy/paste detector                                                                                                                                                                           |
| file-and-image-renamer       | Go       | ✅     | AI screenshot renaming — source-only flake input with Go deps                                                                                                                                                     |
| go-humanize-linter           | Go       | ✅     | AST linter detecting hand-rolled go-humanize reimplementations — via `mkLarsPackages`                                                                                                                            |
| golangci-lint-auto-configure | Go       | ✅     | Auto-configure golangci-lint — source-only flake input                                                                                                                                        |
| todo-list-ai                 | Go       | ✅     | AI-powered TODO extraction — via flake input                                                                                                                                                  |
| mr-sync                      | Go       | ✅     | `~/.mrconfig` GitHub sync CLI — source-only flake input                                                                                                                                       |
| dms-lock                     | Nix      | ✅     | Shared lock-screen package for DMS (`pkgs/dms-lock.nix`)                                                                                                                                       |
| govalid                      | Go       | ✅     | Go validation library (`pkgs/govalid.nix`)                                                                                                                                                     |
| openseo                      | Node.js  | ✅     | Self-hosted SEO suite — built from source via Vite/pnpm (`pkgs/openseo.nix`)                                                                                                                   |
| crush-daily                  | Go       | ✅     | AI-powered dev insights from Crush databases — via flake input overlay                                                                                                                          |
| discordsync                  | Go       | ✅     | Discord channel backup bot — via flake input overlay                                                                                                                                            |
| overview                     | Go       | ✅     | Local project dashboard — via flake input overlay                                                                                                                                               |
| art-dupl + 10 Go tools       | Go       | ✅     | `mkLarsPackages` set (`lib/lars-packages.nix`): art-dupl, branching-flow, buildflow, cqrs-lint, go-auto-upgrade, go-structure-linter, hierarchical-errors, library-policy, md-go-validator, project-meta, projects-management-automation |

---

## 7. CI/CD & Quality

| Feature                      | Status | Notes                                                                                                                                                                                    |
| ---------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GitHub Actions: flake-update | ✅     | Weekly Mon 06:00 UTC, runs `nix flake update --commit-lock-file`, opens PR via `peter-evans/create-pull-request`                                                                         |
| GitHub Actions: nix-check    | ✅     | On push/PR to master (Ubuntu) — `nix flake check --no-build --all-systems`, builds local packages, statix + deadnix linting, `nix fmt --check`                                           |
| Pre-commit hooks             | ✅     | 10 hooks via `.pre-commit-config.yaml`: gitleaks, trailing-whitespace, deadnix, statix, alejandra, nix-check, flake-lock-validate, shellcheck, check-merge-conflicts, protect-home-audit |
| Gitleaks                     | ✅     | Secret detection via `.gitleaks.toml`                                                                                                                                                    |
| Statix checks                | ✅     | Nix lint in flake checks                                                                                                                                                                 |
| Deadnix checks               | ✅     | Dead code detection in flake checks                                                                                                                                                      |
| treefmt formatting           | ✅     | alejandra + other formatters                                                                                                                                                             |

---

## 8. Validation & Diagnostic Scripts

| Script                  | Status | Purpose                        | Key Features                                                                                              |
| ----------------------- | ------ | ------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `health-check.sh`       | ✅     | Cross-platform system health   | Nix/direnv/shell validation, NixOS: failed units + disk + HM age, macOS: Homebrew, PASS/FAIL/WARN summary |
| `nixos-diagnostic.sh`   | ✅     | NixOS Home Manager diagnostics | HM version/generation check, `nix flake check`, broken profile detection, remediation steps               |
| `verify-deployment.sh`  | ✅     | Pre-deployment validator       | Boot config, AMD GPU, Niri, SSH hardening, user/groups, security, generates timestamped report            |
| `test-home-manager.sh`  | ✅     | Post-deploy HM integration     | Starship, Fish aliases, env vars (EDITOR, LANG), PATH entries, Tmux settings                              |
| `test-shell-aliases.sh` | ✅     | ADR-002 alias validation       | 8 common + 3 platform aliases across Fish/Zsh/Bash, percentage grading                                    |
| `dns-diagnostics.sh`    | ✅     | Full DNS diagnostics           | Resolution, blocking, cache stats, dnsblockd config validation                                            |
| `lib.sh`                | ✅     | Shared shell library           | `PROJECT_ROOT` auto-detect, platform detection, helper functions                                          |

---

## 9. Nix Flake Commands

The justfile was **removed** in favor of direct Nix flake commands. Scripts are run directly from `scripts/`.

| Category    | Commands                                                                                                                                                                    | Status |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Core        | `nix flake check --no-build` (validate), `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (quick eval), `nix run .#deploy` (deploy), `nix fmt` (format) | ✅     |
| Maintenance | `nix flake update` (update inputs), `nix-collect-garbage -d` (clean generations)                                                                                            | ✅     |
| Flake apps  | `nix run .#deploy`, `nix run .#validate`, `nix run .#dns-diagnostics`                                                                                                       | ✅     |
| Diagnostics | `scripts/dns-diagnostics.sh`, `scripts/health-check.sh`, `scripts/verify-deployment.sh`, `scripts/status-report.sh`                                                         | ✅     |

---

## 10. Known Gaps & Honesty Check

| Area              | Issue                                                                                                                                                                                                                                                       | Severity |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Raspberry Pi 3    | Hardware not provisioned — entire DNS failover cluster is planned-only                                                                                                                                                                                      | High     |
| ~~PhotoMap AI~~   | Removed (2026-07-04) — module, port, Docker image all cleaned up                                                                                                                                                                                            | —        |
| Multi-WM (Sway)   | Enabled as backup compositor at SDDM login — may have minor bitrot                                                                                                                                                                                          | Low      |
| Twenty CRM        | ~~`twenty-server` crash-loops with PG role mismatch~~ **Resolved 2026-08-14** — error was transient (PG volume recreation after oomd kill); all 4 containers healthy, data intact (90 tables, 66 companies), all containers memory-bounded                                    | Medium→resolved |
| SigNoz alerts     | 23 alert rules + 23 route policies converged every deploy (provisioner v5-v7: PUT-in-place, dedupe, orphan cleanup, hard-fail assertions). Discord channel carries custom title/message templates with values + ruleSource links. All verified `state: inactive` (nothing firing) | Low     |
| NVMe data integrity | SMART healthy (0 media errors, 11% wear). 13 corrupted files found and deleted (Aug 3). Root cause: QLC SLC cache exhaustion from infrequent fstrim → WDT resets → incomplete BTRFS commits. Fix: daily fstrim + `commit=300`. Off-site backup still missing | Medium   |
| Voice agents      | Disabled in configuration, Whisper Docker + ROCm pipeline                                                                                                                                                                                                   | Medium   |
| Minecraft         | Disabled in configuration                                                                                                                                                                                                                                   | Low      |
| Benchmark scripts | Planned but never created                                                                                                                                                                                                                                   | Low      |
| Auditd            | Disabled due to NixOS 26.05 bug #483085                                                                                                                                                                                                                     | Medium   |
| AppArmor          | Explicitly disabled (`mkDefault false`) in security-hardening                                                                                                                                                                                               | Medium   |
| DNS-over-QUIC     | Overlay disabled — breaks binary cache (40+ min builds)                                                                                                                                                                                                     | Low      |
| Browser History   | Startup fast since storage/v4.7.0 (async drain + readiness gate, deployed `4e7604d`); `mkOidcGate` fixes the dnsblockd restart race; `MAX_USERS=1` set — **verify the registration gate is live in the deployed binary** (release chain had a tag-ordering break; see TODO_LIST). Known gaps: `expires_at` session reaper schema error, OAuth2 login not manually tested, `importUsers()` path ungated | Medium   |
| Off-site backup   | **Pool safety net LIVE (2026-08-17):** btrbk root+data sends + ALL application backups (forgejo, pocket-id, immich, twenty, manifest, paperless) land on the 2×16 TB BTRFS mirror — irreplaceables now exist on different physical disks than the NVMe. **True OFF-SITE still missing** (3rd copy leaves the house): user states important photos/docs already live in Google Photos/Drive — decide whether 3-2-1 is satisfied or an offsite leg (e.g. periodic sdf vault) returns. Flagged since 2026-06-25 | Medium→High     |
| Monitor365        | **Deliberately disabled** since 2026-08-12 — private `wireguard-collector` git dep makes the Nix build unfetchable. Re-enable blocked on owner decision (publish crate / make repo public / vendor into workspace). Post-deploy checks auto-SKIP; backup-entry gating deployed                                                                                                                       | Medium   |
| ZFS era CLOSED    | `datapool` (2×16 TB) DESTROYED 2026-08-16 and rebuilt as the BTRFS RAID1 backup pool after full forensic extraction (373,491/373,491 files verified; zero user media ever existed on the box — see CHANGELOG). ZFS-VM scripts (`scripts/zfs-vm-*.sh`) are stale remnants awaiting retirement. Source: `docs/status/2026-08-16_19-12_private-cloud-recovery-final-verification.md` | Low      |
| ~~PMA upstream fix~~  | **Resolved** — `isNothingToCommit()` TOCTOU fix confirmed already in upstream (`committer.go:289`). PMA re-enabled with `ManagedOOMPreference=omit` + split-mode. Flake input bumped | —        |
| ~~SigNoz dashboards~~ | **Resolved 2026-08-16** — 251 zombie dashboards purged to exactly 5 native-v2 (Perses v6) dashboards; provisioner converges (skip/PUT/zombie-cleanup/hard-fail). Follow-ups (eval-time JSON lint, generator script in `scripts/`) in TODO_LIST | —        |
| ~~Hermes packaging~~ | **Resolved 2026-08-21** — upstream ships `registration_lifecycle` in py-modules (since v0.20.1); import verified against the sealed uv2nix venv at `63c6d9a4` and the downstream PYTHONPATH patch DELETED from `hermes.nix` | —        |
| ~~`// ioTier.*` anti-pattern~~ | Fixed 2026-08-10 — all 4 services converted to `lib.mkMerge [ ... ioTier.* ]` | —        |

---

## 11. Architecture Patterns

### Reusable NixOS Module Patterns

| Pattern                    | Location                                   | Purpose                                                                                               |
| -------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| Systemd hardening          | `lib/systemd.nix`                          | Reusable function: `harden { MemoryMax = "512M"; }` — PrivateTmp, NoNewPrivileges, ProtectClock, etc. |
| Service defaults           | `lib/systemd/service-defaults.nix`         | Restart=always, RestartSec=5s, burst limits. WatchdogSec intentionally excluded (requires sd_notify)  |
| Composable services        | `harden {} // serviceDefaults {}`          | Nix module merge combines hardening + lifecycle into serviceConfig                                    |
| Cross-platform preferences | `platforms/common/preferences.nix`         | Shared option module — drives macOS dark mode AND Linux GTK theme from single source                  |
| Dendritic modules          | `modules/nixos/services/*.nix`             | Each file is self-contained flake-parts module with own `config` options                              |
| Local network options      | `platforms/nixos/system/local-network.nix` | `networking.local.*` module options used by both evo-x2 and rpi3-dns                                  |
| Shared DNS blocklists      | `platforms/shared/dns-blocklists.nix`      | Blocklist config consumed by both evo-x2 dnsblockd and rpi3-dns                                       |

### Architecture Decision Records (ADRs)

SystemNix has two ADR collections: the canonical `docs/adr/` set (8 records) and the earlier `docs/architecture/` set (5 records). The numbers overlap because the two directories evolved separately; treat them as separate namespaces.

**Canonical ADRs (`docs/adr/`):**

| ADR                                                             | Title                                      | Decision                                                                    |
| --------------------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------- |
| [ADR-001](./docs/adr/001-go-workspace-submodule-nix-pattern.md) | Go Workspace Sub-Module Nix Pattern        | `mkPreparedSource` pattern for private Go repos with replace directives     |
| [ADR-002](./docs/adr/002-gpu-headroom-for-niri.md)              | GPU Memory Headroom for Niri               | Reserve GPU memory for compositor (`OLLAMA_GPU_OVERHEAD`)                   |
| [ADR-003](./docs/adr/003-binds-to-vs-wants-niri.md)             | BindsTo vs Wants for Niri                  | `BindsTo` kills niri on deploy — use `Wants=` instead                       |
| [ADR-004](./docs/adr/004-partof-vs-bindsto-wallpaper.md)        | PartOf vs BindsTo for Wallpaper            | Historical (awww retired). DMS owns wallpapers natively. Kept for reference |
| [ADR-005](./docs/adr/005-discord-notification-channel.md)       | Discord Notification Channel for SigNoz    | Dedicated Discord channel for critical alert routing                        |
| [ADR-005b](./docs/adr/ADR-005-local-deps-pattern.md)            | `_local_deps` Pattern for Private Go Repos | Local replace directives for private Go module builds                       |
| [ADR-006](./docs/adr/006-gatus-secret-injection.md)             | Gatus Secret Injection                     | Environment file pattern for Discord webhook URL                            |
| [ADR-007](./docs/adr/007-authelia-to-pocket-id-migration.md)    | Authelia → Pocket ID Migration             | Migrated from Authelia to Pocket ID for passkey-based OIDC                  |

**Platform / architecture ADRs (`docs/architecture/`):**

| ADR                                                                      | Title                            | Decision                                                    |
| ------------------------------------------------------------------------ | -------------------------------- | ----------------------------------------------------------- |
| [ADR-001](./docs/architecture/adr-001-home-manager-for-darwin.md)        | Home Manager for Darwin          | Use Home Manager on macOS via nix-darwin integration        |
| [ADR-002](./docs/architecture/adr-002-cross-shell-alias-architecture.md) | Cross-Shell Alias Architecture   | Single source of truth for aliases across Fish/Zsh/Bash     |
| [ADR-003](./docs/architecture/adr-003-ban-openzfs-on-macos.md)           | Ban OpenZFS on macOS             | OpenZFS causes kernel panics on macOS (rejected)            |
| [ADR-004](./docs/architecture/adr-004-secrets-management-sops-nix.md)    | Secrets Management with sops-nix | Use age + SSH host keys for secret decryption               |
| [ADR-005](./docs/architecture/adr-005-niri-session-restore.md)           | Niri Session Restore             | Save and restore niri workspace/window state across crashes |

---

## 12. Improvement Opportunities

### Type Model / Architecture Suggestions

| Area                 | Current State                                | Suggestion                                                                                   |
| -------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------- |
| dnsblockd categories | Stringly-typed (10 hardcoded strings)        | Define `Category` enum type in Go — make impossible states unrepresentable                   |
| dnsblockd temp-allow | In-memory map, lost on restart               | Persist to SQLite or file — already has `/var/lib` state dir pattern                         |
| Nix module options   | Many modules use `mkEnableOption` only       | Add typed options for key config (ports, paths, timeouts) — enables validation and testing   |
| Service hardening    | Per-service `harden {}` calls                | Consider `mkHardenedService` wrapper that combines hardening + defaults + common patterns    |
| Overlays             | Defined as standalone functions in flake.nix | Extract to `overlays/` directory (already done for some via pkgs/) for discoverability       |
| Shared preferences   | Only `preferences.nix` currently             | Extend pattern: shared `services.defaults` for common service config (user, group, stateDir) |

### Well-Established Libraries Already In Use

| Library            | Purpose                    | Why Good Choice                                                                               |
| ------------------ | -------------------------- | --------------------------------------------------------------------------------------------- |
| flake-parts        | Modular flake architecture | Standard pattern for complex Nix flakes, enables dendritic modules                            |
| sops-nix           | Secrets management         | Battle-tested, age/GPG/SSH key support, systemd integration                                   |
| nix-colors (local) | Declarative color schemes  | Defined locally in `platforms/common/theme.nix` — drives all apps from single source of truth |
| home-manager       | User-level config          | Cross-platform, NixOS module integration, declarative dotfiles                                |
| nix-homebrew       | Homebrew management        | Declarative taps/casks, auto-migrate, pinned inputs                                           |
| niri-flake         | Wayland compositor         | Wraps niri for NixOS, overlay + module + wrapper-modules pattern                              |

---

## 13. Feature Count Summary

_Counts computed from code; re-verify with `rg` / `ls` before citing._

| Category                   | Count | How to verify                                                                 |
| -------------------------- | ----- | ----------------------------------------------------------------------------- |
| NixOS service modules      | 55    | `ls modules/nixos/services/*.nix modules/nixos/desktop/*.nix \| grep -v '/_' \| wc -l` |
| Custom packages            | 30    | 15 mkLarsPackages + 8 pkgs/ + 7 flake-input overlays                          |
| Gatus health endpoints     | 100   | `grep -c 'name = "' modules/nixos/services/gatus-config.nix`                |
| Sops secret files          | 16    | `ls platforms/nixos/secrets/*.yaml \| wc -l`                                  |
| DMS plugins                | 13    | 13 SystemNix (`ls pkgs/dms-plugins/ \| grep -v '^_'`)                         |
| Architecture patterns      | 7     | See section 11                                                                |
| ADRs                       | 13    | 8 canonical (`docs/adr/`) + 5 platform (`docs/architecture/`)                 |
| NixOS VM tests             | 11    | `ls tests/test-*.nix \| wc -l`                                                |
| Known gaps                 | 15    | See section 10                                                                |

---

_Generated by deep code audit — every module, program, service file, script, and workflow was read and assessed._
