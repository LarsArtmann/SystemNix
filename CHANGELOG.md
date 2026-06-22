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

## [2026-05] — Ecosystem Stabilization Sprint

### Added
- **Pocket ID migration** — replaced Authelia with passkey-based OIDC provider, declarative provisioning (`pocket-id-config.provision.enable`)
- **BTRFS snapshot overhaul** — btrbk daily snapshots with 14d+4w retention, `btrfs-verify-snapshots` timer, `/mnt/btrfs-root` automount
- **Custom `signoz.target`** — decouples SigNoz/ClickHouse from `multi-user.target`, ~2m faster boot
- **Crash-loop protection** — `startLimitBurst = 5` on all critical services
- **Stale LSP cleanup timer** — kills gopls/vtsls/rust-analyzer running >5min every 5min
- **Rust target cleanup** — weekly timer prunes stale `target/` dirs

### Changed
- Migrated from earlyoom to systemd-oomd
- Consolidated flake follows (38 duplicate lock nodes eliminated: 182→144)
- SigNoz JWT auto-generation wrapper script (no longer needs sops secret)
- Port centralization — all ports in `lib/ports.nix`, collision-protected
- Image registry — all container references via `lib/images.nix`

### Fixed
- OOM crash chain — Helium/Electron renderers in `user-1000.slice` exhausting RAM → journald starved → sp5100-tco WDT hard reset
- DNS rollback incident — Mullvad talpid_dns crisis
- Boot performance — `initrd-nixos-activation` 2m50s hang (sops owner validation)
- OAuth2-proxy cookie secret blocking deploy

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
