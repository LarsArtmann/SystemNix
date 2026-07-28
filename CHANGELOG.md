# Changelog

All notable changes to SystemNix are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/).

Given the project's history (2,927 commits), this changelog focuses on significant user-facing and architectural changes. For exhaustive detail, see `git log` and `docs/status/`.

---

## [Unreleased]

### Added

- **OpenSEO** — self-hosted SEO suite (rank tracking, keyword research, backlinks). Native NixOS service built from source (Vite/pnpm + workerd runtime). Port 3002, `seo.home.lan`. GSC OAuth callback + AI features conditionally enabled with `openseo-validate` ExecStartPre.
- **system-health collector** — Prometheus textfile collector for systemd service state (active/failed/start-limit-hit), `user-1000.slice` memory threshold (40G), GPUActive threshold (60G), monitor365 DuckDB buffer pressure. Pre-computes boolean flags for Gatus `pat()` matching.
- **Monitor365 schema-migrate oneshot** — runs `ALTER TABLE tenants ADD COLUMN IF NOT EXISTS version INTEGER` before server start. Resolves the DuckDB "version" column binder error after upstream schema change.
- **Monitor365 agent watchdog** — timer (every 5min) checks agent process + metrics endpoint; resets start-limit and restarts if dead. Runs as root (required for `systemctl start`).
- **Monitor365 graphical-restart path unit** — watches for Wayland socket, restarts agent when compositor appears. Debounced (skips restart if started <60s ago or not active).
- **Helium auto-restart service** — systemd user service (`helium.service`) with `Restart=always`, `RestartSec=5`, `StartLimitBurst=10`. `helium-launch` wrapper pgrep-checks for existing main process before launching, preventing the empty-window crash loop.
- **Memory-limited test wrappers** — `go-test-memlimit` (4G), `cargo-test-memlimit` (8G), `pnpm-test-memlimit` (4G) via `wrapWithMemoryLimit` helper in `lib/default.nix`. Uses `systemd-run --user --scope` with `MemoryMax`.
- **TTM page_pool_size reduction** — `ttmPagePoolSize` reduced from 112 GiB to 24 GiB in boot.nix (was exceeding the 94 GiB visible to Linux, allowing GPU driver to consume virtually all RAM).
- **Post-deployment health check** — `scripts/post-deploy-check.sh` verifies services are functional (not just alive) after deploy: checks vHosts return expected HTML, APIs return expected JSON, catches "alive but broken" services.
- **DNS local config module** — `dns-local.nix` extracted from inline config. Manages `localSubdomains` list (required because dnsblockd's sdns resolver does NOT support wildcard local records).
- **qmd** — on-device semantic + BM25 hybrid markdown/code search via persistent HTTP MCP server (port 8181). Built from GitHub source (`fetchFromGitHub` + `pnpmConfigHook`). Three GGUF models auto-cached (~2 GiB). CPU-only by default. Crush MCP integration.
- **Bun memory limiter** — `bunMemoryLimitOverlay` wraps `bun` in a `systemd-run --user --scope` with `MemoryMax=8G`, `MemorySwapMax=0`, `oom_score_adj=1000`. Prevents runaway `bun test` from consuming 61 GB and triggering WDT reset.
- **monitor365 graphical collectors** — keystroke, mouse, camera, clipboard, screenshot collectors wired. `input`/`video` groups added, path-unit restart on Wayland login, upstream pgrep-based display env discovery (`displayUser`).
- **monitor365 backup health monitoring** — Prometheus textfile collector (`monitor365_backup_healthy`, `monitor365_backup_age_hours`) + Gatus Discord alert. Follows AGENTS.md rule 9 mandate.
- **monitor365 nightly DuckDB backup** — timer at 03:00, 7-day retention.
- **DiscordSync OTel tracing** — traces exported to SigNoz via `OTEL_EXPORTER_OTLP_ENDPOINT`.
- **DiscordSync webhook alerting** — `DISCORDSYNC_WEBHOOK_URL` from sops secret.
- **ssh-suspend-guard** — holds `sleep` block inhibitor via `systemd-inhibit` while SSH sessions active, preventing idle suspend during remote work
- **PSI memory pressure metrics** — textfile collector in SigNoz exports `/proc/pressure/memory` avg10 values + derived alert boolean, with Gatus Discord alerting
- **md-go-validator** — added to both NixOS and macOS desktops
- **USB printing support** — added to NixOS hardware configuration
- **Homepage local icons** — `enableLocalIcons = true` bundles 4276 dashboard icons (was defaulting to false, producing ~25 browser 404s per page load)
- **SearXNG** — privacy-focused metasearch engine on port 8889 (`search.home.lan`). Built-in Granian ASGI server, dedicated Redis (unix socket, isolated from Immich), auto-generated secret key (not sops — machine-local random). Layer 2 SSO via oauth2-proxy (no native OIDC support). Rate limiter with trusted proxies (Caddy) + LAN `pass_ip`. POST-only search (queries not in URLs/logs), dark mode, favicon caching (DuckDuckGo resolver). Browser default search engine integration via Chromium policy (`DefaultSearchProviderSuggestURL` proxied through SearXNG). `restartTriggers` on settings + limiter config + package

### Changed

- **Deploy resilience** — `deploy.sh` now runs `systemctl reset-failed` (system + user) AND explicitly starts enabled-but-inactive services after reset. Previously crash-looped services at boot blocked ALL deploys until manually reset.
- **Monitor365 module restructured** — pinned to upstream `0615301` (avoids libspa-sys bindgen breakage from `5ee717e3+`). Added schema-migrate, watchdog, graphical-restart, backup-health, restartTriggers. All `//` chains converted to `lib.mkMerge`.
- **oauth2-proxy hardening** — added `--whitelist-domain=.home.lan` (fixes post-login redirect 500), `partOf = pocket-id-provision.service` (ensures credential reload on secret rotation), PKCE S256 enabled (`code-challenge-method = "S256"`).
- **SigNoz auth** — impersonation mode (`SIGNOZ_IDENTN_IMPERSONATION_ENABLED=true`) + unconditional Caddy forward-auth (no LAN bypass). Pocket ID is the sole auth boundary. OIDC is Enterprise-only ($4k/mo).
- **samber-do-auditlog pinned to v0.5.0** — resolves cmdguard type mismatch (`ServiceName` typed string vs bare `string`). Added as top-level flake input with `go-cqrs-lite.inputs.samber-do-auditlog.follows`.
- **mr-sync pinned to `3db4fb2`** — upstream `6492eef` removed `nixpkgs` from `outputs` params without adding `...` catch-all.
- **DiscordSync module refactor** — consumes upstream `nixosModules.default` (Monitor365 gold-standard pattern). Eliminates option re-declaration drift. SystemNix specifics layered via `lib.mkMerge`.
- **Post-deploy-check improvements** — SIGPIPE fix (body-file grep instead of pipe), `--compressed` flag for gzip responses, DiscordSync startup-race handling (retry + SKIP for backfill), renamer data-correctness assertion (`total_operations > 0`).
- **OOM hardening** — tuned systemd-oomd thresholds (50%/20s pressure), added `user-1000.slice` MemoryHigh=56G / MemoryMax=64G to contain runaway user processes that starved journald → WDT hard reset. PSI early-warning alerting via Gatus Discord
- **mkLarsPackages simplification** — eliminated manual vendorHash overrides, removed `mkPackageOverlay` indirection for Go tool packages
- **Gatus monitoring expansion** — 65 endpoints (was 59), with Discord alerting and response-time thresholds on user-facing services
- **NixOS modules** — 43 auto-discovered (was 42, added SearXNG)
- **DiscordSync backend** — switched turso-sync → sqlite (eliminates Turso free-plan "SQL read operations forbidden" 403 — 13,993+ consecutive failures). Turso cloud sync can be re-enabled by setting `backend = "turso-sync"` + `tursoUrl` + `tursoAuthTokenFile`
- **Caddy `proxyTo` helper** — `protectedVHost` now wraps `reverse_proxy` with `header_up X-Real-IP {remote_host}`, benefiting all Layer 2 services behind forward-auth (SearXNG, Homepage, etc.)
- **Crush Daily** — `runAsUser` support (runs as `primaryUser` instead of system user, fixing ACL `mask::---` on `/home/lars`). Silent-zero-data post-deploy assertion (`session_count > 0`)
- **goreleaser** added to Linux base packages

### Removed

- **justfile** — removed in favor of direct Nix flake commands (`nix run .#deploy`, `nix flake check --no-build`, `nix fmt`). All recipes replaced by flake apps and `scripts/` shell scripts

### Fixed

- **ActivityWatch Wayland watcher start-limit-hit** — `aw-watcher-window-wayland` had `After`/`PartOf = graphical-session.target` but no start-limit hardening, so a slow compositor start or transient Wayland failure hit the systemd default (5 starts / 10 s) and left the watcher dead until manual `reset-failed`. Added `StartLimitBurst=5` / `StartLimitIntervalSec=300` to the local override. Upstream Home Manager patch prepared (`docs/services/home-manager-activitywatch-graphical-session.patch`) adding a `requiresGraphicalSession` watcher option so the compositor dep is upstreamable instead of a hand-rolled per-site override.
- **Monitor365 DuckDB WAL corruption** — `monitor365-duckdb-heal` ExecStartPre always removes `.wal` before startup. DuckDB checkpoints WAL on graceful shutdown; `.wal` present = unclean shutdown. Server was crash-looping 291+ times.
- **Monitor365 agent circuit-breaker deadlock + start-limit death spiral** — 4-layer fix: `startLimitBurst=10` on service, debounced graphical-restart (skips if <60s ago), watchdog timer (resets + restarts), deploy.sh starts inactive services.
- **PMA auto-commit (DefaultChain)** — `committer.New()` now uses `DefaultChainFromEnv()` (reads `MINIMAX_API_KEY` from env) instead of `DefaultChain()` (empty providers). Upstream `d1d013d2`.
- **PMA "Unknown Author"** — go-git's `repo.Config()` reads only local scope (`.git/config`), not global. Both go-commit (`v0.4.0`) and PMA (`e8380b44`) now use `git config user.name`/`user.email` via CLI which merges all scopes.
- **Helium empty-window crash loop** — `Restart=always` + existing-session handoff spawned 11 empty windows in 36s. `helium-launch` wrapper pgrep-checks before launch.
- **dnsblockd wildcard DNS resolution** — `*.home.lan` wildcard record silently ignored by sdns resolver. Only explicitly listed subdomains in `localSubdomains` resolve. Added all service subdomains.
- **dnsblockd cache CNAME-chase bug** — cache never called `SetQueryer`, serving partial CNAME answers (CNAME without terminal A/AAAA). Caused `curl: (6) Could not resolve host` for CNAME-chained CDN hostnames. Fixed upstream.
- **dnsblockd blocklist dir-vs-file path** — was reading directory instead of file inside it (0 entries blocked, 2.5M domains silently missing).
- **Pocket ID client-secret desync** — provision script migration block seeded stale secrets; skip-if-exists check prevented regeneration. `regenerateSecretsFor` option added for declarative recovery.
- **Forgejo GitHub-sync API token** — `FORGEJO_TOKEN` must come from auto-generated token file, not sops template (stale `CHANGE_ME` placeholder rejected all API calls).
- **Immich Redis TCP port** — nixpkgs defaults to unix-socket-only (port 0); overridden to listen on TCP for monitoring.
- **PMA Type=notify without sd_notify** — upstream sets `Type=notify` + `WatchdogSec=30s` but Go binary never calls `sd_notify(READY=1)`. Overridden to `Type=exec`.
- **Overview OOM-kills when PMA absent** — Overview delegates discovery to PMA daemon socket; falls back to 4+ GB local discovery (OOM-loop) when socket missing.
- **File & Image Renamer auth fallback** — `ErrorTypeAuth` (non-retryable, triggers provider fallback) for 401/403. Upstream `8bf60bd`. Sops key provisioning via `mkKeyedSecrets`.
- **File & Image Renamer split-brain** — watcher and health service unified on `dataDir` state paths (`b0c76b58`). Dashboard was silently showing 0 operations.
- **PMA watcher attribution** — `convertEvent` now resolves actual git repo root per file event (upstream `52c01b18`).
- **Monitor365 integrity hash serialization** — canonical JSON serialization before hashing (upstream `9ea1f1000` + `ebb26a0bd`).
- **Homepage orphaned process after nix-gc** — `restartTriggers = [ pkg ]` forces restart when package changes (same pattern as dnsblockd).
- **Post-deploy-check SIGPIPE false-FAIL** — grep reads from body file directly instead of pipe (large bodies >64KB triggered SIGPIPE under `set -o pipefail`).
- **btrbk-data snapshot directory** — `/data/.snapshots` created via tmpfiles rule.
- **btrfs-verify-snapshots false alarm** — parses snapshot name instead of inherited `stat` mtime.
- **Ollama silent non-start** — removed `wantedBy = mkForce []` that suppressed nixpkgs' default `WantedBy=multi-user.target`.
- **Pre-commit hook statix multi-file bug** — statix now iterates per-file instead of passing all files to one invocation.
- Cascading build failures across 10+ Go repos (cmdguard follows clause, vendor hash cascades)
- Hermes hardcoded `lars` username → `config.users.primaryUser`
- Forgejo duplicate password generation in admin setup
- Monitor365 re-enabled after SQLX_OFFLINE fix
- **SigNoz provision jq array-path bug** — 4-month-old `jq` accessed `.rules[]` instead of `.data.rules[]` in alert-rules provisioning, blocking `nh os switch`. Fixed array path in `signoz-provision` script
- **Homepage bookmark schema crash** — bare YAML object instead of list-of-one-object white-screened the entire dashboard. Fixed to upstream schema format (`[{ ... }]`)
- **Crush Daily silent-zero-data (3 bugs)** — (1) service ran as `crush-daily` system user instead of `primaryUser` (ACL `mask::---` blocked `/home/lars` traversal — `crush projects --json` read empty state), (2) crush CLI v0.86 schema drift (`prompt_tokens`/`completion_tokens`/`cost` moved from per-message to per-session columns — SQL `no such column`), (3) SQLite DSN without `file:` URI prefix opened in-memory DB (treated `?` as filename). All fixed upstream + SystemNix
- **DiscordSync nullable FK crash loop** — backfilling empty string into nullable `guild_id`/`channel_id` columns caused `invalid expression in CREATE INDEX` → crash loop → `start-limit-hit`. Upstream fix (`d785fdfa`) added `backfill_nulls.go` regression test
- **md-go-validator FOD purity break** — `go-branded-id@v0.5.0` shipped a 3.3 MB committed ELF `namer` binary embedding the Go compiler store path. Resolved upstream in v0.5.1 (removed binary). SystemNix `stripPrebuiltGoBinaries` band-aid removed
- **sops crush-daily user mismatch** — secrets owned by non-existent `crush-daily` system user blocked ALL secret deployment atomically (`failed to lookup user 'crush-daily'`). Fixed to `owner = primaryUser; group = "users"` (same pattern as file-and-image-renamer)
- **Crush Daily SQLite DSN** — `sql.Open("sqlite", dbPath+"?_loc=...")` without `file:` URI prefix opened in-memory DB. Fixed to `sql.Open("sqlite", "file:"+dbPath+"?_loc=auto&_time_format=sqlite")` (upstream `83cb19d`)
- **Crush Daily HTML template** — Go 1.26 `html/template` reverted `printf` arg order — `{{"%.2f"|printf .TotalCost}}` triggered type error. Fixed to `{{printf "%.2f" .TotalCost}}` (upstream `b8095de`)

### Disabled

- **Mullvad VPN** — `mullvad-vpn.enable = false` due to talpid_dns corrupting `/etc/resolv.conf`. Config preserved for future re-enablement

---

## [2026-07] — Desktop Shell Migration & Infrastructure Hardening

### Added

- **DankMaterialShell (DMS)** — replaced Waybar, Dunst, Rofi as sole Quickshell desktop shell. Owns notifications, wallpapers, clipboard, launcher, polkit
- **DMS community plugins** — emoji launcher (`:e` trigger) and DankCalculator (`=` trigger) via `fetchFromGitHub`
- **DMS SystemNix plugins** — 13 native widgets (clock, volume, brightness, network, battery, workspace bar, etc.)
- **Helium display-hotplug crash mitigation** — `--disable-gpu-watchdog` flag prevents Chromium GPU watchdog kill during slow DCN 3.5.1 surface recreation under GPUActive pressure
- **`/tmp` tmpfs capped at 16 GiB** — static systemd `tmp.mount` unit replacing default 50%-of-RAM (~47 GiB) tmpfs. go-build caches filled 16+ GiB in 21h previously
- **MGLRU thrashing protection** — `min_ttl_ms=1000` via sysfs service prevents thrash spiral (evict hot page → fault → evict another) that starves journald
- **BTRFS metadata ENOSPC prevention** — `btrfs-health.nix` gates `nix-gc` when device-unallocated < 10%, Gatus Discord alerts on metadata ratio, DMS widget shows device-unallocated %. btrbk staggered to 23:00 (before GC at 00:00)
- **Network interface boot race fix** — `dnsblockd-attach-ip.service` (CAP_NET_ADMIN oneshot, ordered after `.device` unit) replaces `localCommands` with `|| true`
- **Pre-deploy validation** — `nix run .#pre-deploy-check` catches boot-breakers (ext4 `discard=async`, missing `nofail`)
- **Post-deploy smoke test** — `nix run .#post-deploy-check` verifies vHosts return expected HTML, APIs return expected JSON, catches "alive but broken" services
- **ProtectHome pre-commit hook** — flags `harden{} + /home` patterns at commit time, catches the crush-daily class of silent data-access failure
- **Functional Gatus body assertions** — Monitor365 `/ui/` checks for `<html` body, Homepage + Overview body checks with Discord alerts. Catches "alive but broken" services
- **Gatus monitoring expansion** — 38→41 endpoints, 31 with Discord alerts, 17 with response-time thresholds. Added Redis TCP check, Mullvad DoT upstream check, external HTTPS connectivity check
- **Caddy security hardening** — `commonConfig` snippet: HSTS, nosniff, frame-options, referrer-policy, permissions-policy, compression (zstd/gzip), HTTP→HTTPS redirect, structured JSON access logging (100MB rotation), TLS 1.2+ enforcement, strict SNI host, 10GB body size limit
- **SSH socket cleanup timer** — systemd user timer (every 5 min) probes `ControlMaster` sockets via AF_UNIX `connect()` and unlinks dead ones
- **Herdr terminal agent multiplexer** — deployed across platforms
- **Niri fork** — switched to `LarsArtmann/niri` (commit `f1f23079`) for improved session save/restore
- **DNS local config module** — `dns-local.nix` extracted from inline configuration
- **Monitoring runbook** — `docs/runbooks/monitoring-runbook.md` documents recovery procedures for every Discord alert
- **Renamer health dashboard** — Caddy vHost + Gatus + Pocket ID for `file-and-image-renamer`
- **DiscordSync dashboard** — exposed at `discordsync.home.lan` with Layer-2 SSO via Pocket ID
- **Overview exposed** — `overview.home.lan`, last unexposed web UI
- **Overview CSP/CDN migration** — cross-repo fix: `templ-components` switched CDN from unpkg.com → cdn.jsdelivr.net. cqrs-htmx v3→v4 migration
- **Resend SMTP wiring** — `smtp.resend.com:465`, `noreply@cloud.larsartmann.com`
- **dnsblockd v0.2.0** — tagged with full embedded recursive resolver (sdns, DNSSEC, DoT, DoH, caching, local zones, ACLs, upstream forwarding). Ready for SystemNix migration

### Changed

- **Rofi → DMS migration** — all 5 niri rofi keybindings rewired to DMS IPC (spotlight, clipboard, keybinds, emoji, calc). Root cause: rofi leaked 7 GB → global OOM killed niri + 8 other processes
- **Unbound cache bounds** — `key-cache-size = "16m"`, `neg-cache-size = "16m"`, `infra-cache-numhost = 10000`. Was 1.5 GiB RSS for 192 MiB explicit caches (DNSSEC key + NXDOMAIN caches were unbounded)
- **OOM tuning** — `user-1000.slice` MemoryHigh=56G / MemoryMax=64G, oomd 50%/20s pressure threshold
- **Deploy resilience** — `deploy.sh` now runs `systemctl reset-failed` (system + user) before `nh os switch`. Without this, crash-looped services at boot block ALL deploys
- **Monitor365 UI package fix** — changed from `pkgs.monitor365` (agent CLI, no UI) to `pkgs.monitor365-server` (symlinkJoin with WASM UI + `UI_DIST_PATH` wrapper)
- **Crush-daily data collection repaired** — `ProtectHome=false` + scoped `ReadOnlyPaths` to `.crush/`. `harden{}` defaults made `/home` invisible — silent empty output for weeks

### Removed

- **Photomap** — module, port (8051), Docker image, Homepage tile, config stub all cleaned up
- **cliphist service** — `wl-paste --watch cliphist store` retired; DMS owns clipboard history exclusively. CLI tool kept for manual use
- **Waybar** — completely removed (import, package, service, scripts). DMS is sole shell
- **Dunst** — disabled (`services.dunst.enable = lib.mkForce false`). DMS owns `org.freedesktop.Notifications`

### Fixed

- **Rofi OOM crash** — 7 GB leak over 5h22m triggered global OOM killing niri, ghostty, signal, pipewire, unbound, clickhouse, immich
- **Helium display-hotplug crash** — GPU watchdog killed process during slow surface recreation under GPUActive memory pressure
- **`switch-to-configuration` exit code 4** — crash-looped services at boot block deploys until manually reset
- **Crush-daily `ProtectHome` silent failure** — hardened service couldn't read `~/.local/share/crush/`
- **BuildFlow silent empty binary** — `buildGoModule` silently dropped `GOEXPERIMENT=jsonv2` from `env` attr; moved to `export` in `preBuild`
- **NVMe `discard=async` watchdog hard-reset diagnosed** — 253ms discard latency on QLC NAND → 17.7s BTRFS commit → system freeze → 30s watchdog → hard reset. Fix: remove `discard=async`, use `fstrim.timer`
- **Monitor365 DB path** — `sqlite://` → `sqlite:///` (3 slashes = absolute path) + added `--config` flag to ExecStart
- **aw-watcher-window-wayland startup race** — added `After=graphical-session.target` dependency
- **Pocket ID OTel** — removed unnecessary traces/logs exporters, kept `OTEL_METRICS_EXPORTER=prometheus`
- **project-meta build** — re-investigated; builds successfully, package is healthy. Original TODO was based on outdated evaluation
- **7 LarsArtmann Go repos** — eliminated stale `vendorHash` / `go.sum` overrides: `golangci-lint-auto-configure`, `hierarchical-errors`, `go-structure-linter`, `art-dupl`, `dnsblockd`, `emeet-pixyd` (all use upstream overlays or `follows` now)

### Added (Documentation)

- **Documentation overhaul** — ROADMAP.md (6 themes), CHANGELOG.md, archived 197 old status reports, freshness pass across README/FEATURES/CONTRIBUTING (retired Waybar/Dunst/Rofi references, corrected counts, replaced `just` with flake commands)
- **AGENTS.md gotchas** — `discard=async` QLC NAND I/O death spiral, `buildGoModule` silent env attr filtering, `buildGoDir` silent-swallow behavior, Helium wrapper double-wrap collision, VA-API flag renames

---

## [2026-06] — Auth & Service Wiring

### Added

- **Sops secret management skill** — project-local skill at `.crush/skills/sops-secret-management/SKILL.md` with gitignore whitelist
- **ssh-to-age** — added to system packages (was not installed, needed `nix run` every time)

### Fixed

- **Caddy boot ordering** — `wants = ["sops-nix.service"]` + `after` prevents 14-hour outage recurrence
- **DNS A records for 5 subdomains** — status, seo, daily, logs, monitor added to both primary + RPi3 DNS
- **All sops secrets guarded** — hermes, crush-daily, openseo, monitor365, signoz, voice-agents wrapped in `lib.optionalAttrs config.services.X.enable`
- **AGENTS.md sops guide** — corrected ssh-to-age `-private-key`, `SOPS_AGE_KEY` in RAM, one-liner pattern

---

## [2026-05] — Ecosystem Stabilization Sprint

### Added

- **Pocket ID migration** — replaced Authelia with passkey-based OIDC provider, declarative provisioning (`pocket-id-config.provision.enable`)
- **BTRFS snapshot overhaul** — btrbk daily snapshots with 14d+4w retention, `btrfs-verify-snapshots` timer, `/mnt/btrfs-root` automount
- **Custom `signoz.target`** — decouples SigNoz/ClickHouse from `multi-user.target`, ~2m faster boot
- **Crash-loop protection** — `startLimitBurst = 5` on all critical services
- **Stale LSP cleanup timer** — kills gopls/vtsls/rust-analyzer running >5min every 5min
- **Rust target cleanup** — weekly timer prunes stale `target/` dirs
- **QDirStat** — Qt disk usage analyzer added
- **NVMe APST boot delay fix** — `nvme_core.default_ps_max_latency_us=0` kernel param prevents 2m50s device detection delay

### Changed

- Migrated from earlyoom to systemd-oomd
- Consolidated flake follows (38 duplicate lock nodes eliminated: 182→144)
- SigNoz JWT auto-generation wrapper script (no longer needs sops secret)
- Port centralization — all ports in `lib/ports.nix`, collision-protected
- Image registry — all container references via `lib/images.nix`
- **go-auto-upgrade fix** — added `go-error-family.follows`, removed redundant vendorHash override from `overlays/shared.nix`
- Manifest moved behind auth (`protectedVHost`)
- Hermes icon fix (`ai.png` → `hermes-icon.png`)

### Fixed

- OOM crash chain — Helium/Electron renderers in `user-1000.slice` exhausting RAM → journald starved → sp5100-tco WDT hard reset
- DNS rollback incident — Mullvad talpid_dns crisis
- Boot performance — `initrd-nixos-activation` 2m50s hang (sops owner validation)
- OAuth2-proxy cookie secret blocking deploy
- Pocket ID provision — header casing + URL encoding + race conditions

---

## [2026-04] — Service Hardening & Auth Stack

### Added

- **oauth2-proxy** — forward-auth bridge between Caddy and Pocket ID
- **Gatus health monitoring** — expanding endpoint coverage with Discord alerting
- **SigNoz dashboards** — Caddy, DNS, Docker, GPU, overview, SigNoz-overview
- **Pocket ID SMTP** — configurable via module options (`cfg.smtp.*`)

### Changed

- Homepage Dashboard rewritten with `mkGroup`/`mkService` helpers
- All sops secrets guarded with `lib.optionalAttrs config.services.X.enable`
- Caddy boot ordering fix (`wants = ["sops-nix.service"]`)

---

## [2026-03] — Desktop & Display Manager Migration

### Added

- **SilentSDDM** — replaced SDDM with themed login manager
- **Ghostty terminal** — primary terminal (GPU-accelerated, native Wayland)
- **Nix-colors migration** — 164 colors migrated to local `theme.nix`

### Changed

- Display manager migration from LightDM/GDM to SilentSDDM
- DNS blocklist ultimate expansion (23 blocklists, 2.5M+ domains)

---

## [2026-02] — Kernel Panic Investigation & Recovery

### Fixed

- Kernel panic investigation and ZFS removal on macOS (ADR-003)
- Nix-darwin build fix (Go module builder mismatch)
- Path reference cleanup

---

## [2026-01] — Nix Anti-Patterns Elimination

### Changed

- Phase 3-4 anti-patterns elimination — major refactoring
- GOPATH implementation made Nix-native
- Wrapper system removal
- Technitium DNS automation (later replaced by dnsblockd)

---

## [2025-12] — v1.0 Release

### Added

- Cross-platform Nix flake (Darwin + NixOS)
- Flake-parts modular architecture
- Home Manager integration for Darwin
- BTRFS root with snapshots
- Custom packages: jscpd, govalid, netwatch, openaudible, aw-watcher-utilization

---

## [2025-11] — NixOS Desktop Setup

### Added

- Hyprland (later replaced by Niri)
- btop wallpaper automation
- Home Manager consolidation
- Evo-X2 hardware configuration (AMD Strix Halo)

---

## [2025-07] — v2.0.0 (Initial Nix Migration)

### Added

- Initial migration from dotfiles to Nix flake
- Terminal performance optimization
- Network monitoring setup
