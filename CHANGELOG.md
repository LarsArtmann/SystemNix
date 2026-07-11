# Changelog

All notable changes to SystemNix are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/).

Given the project's history (2,927 commits), this changelog focuses on significant user-facing and architectural changes. For exhaustive detail, see `git log` and `docs/status/`.

---

## [Unreleased]

### Added
- **ssh-suspend-guard** — holds `sleep` block inhibitor via `systemd-inhibit` while SSH sessions active, preventing idle suspend during remote work
- **PSI memory pressure metrics** — textfile collector in SigNoz exports `/proc/pressure/memory` avg10 values + derived alert boolean, with Gatus Discord alerting
- **md-go-validator** — added to both NixOS and macOS desktops
- **USB printing support** — added to NixOS hardware configuration

### Changed
- **OOM hardening** — tuned systemd-oomd thresholds (50%/20s pressure), added `user-1000.slice` MemoryHigh=56G / MemoryMax=64G to contain runaway user processes that starved journald → WDT hard reset. PSI early-warning alerting via Gatus Discord
- **mkLarsPackages simplification** — eliminated manual vendorHash overrides, removed `mkPackageOverlay` indirection for Go tool packages
- **goreleaser** added to Linux base packages

### Removed
- **justfile** — removed in favor of direct Nix flake commands (`nix run .#deploy`, `nix flake check --no-build`, `nix fmt`). All recipes replaced by flake apps and `scripts/` shell scripts

### Fixed
- Cascading build failures across 10+ Go repos (cmdguard follows clause, vendor hash cascades)
- Hermes hardcoded `lars` username → `config.users.primaryUser`
- Forgejo duplicate password generation in admin setup
- Monitor365 re-enabled after SQLX_OFFLINE fix

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
