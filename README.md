# SystemNix

**Declarative cross-platform system configuration using Nix.**

SystemNix manages both macOS (nix-darwin) and NixOS systems through a single, reproducible Nix flake. All system settings, packages, services, and user configurations are defined in code and applied consistently across machines.

## What You Get

| Category                 | Tools & Services                                                                                                                                                                                                                                                                                                |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Languages**            | Go 1.26, Node.js, Bun, Python 3.13, Rust                                                                                                                                                                                                                                                                        |
| **Cloud & Infra**        | AWS CLI, GCP SDK, kubectl, Helm, Terraform                                                                                                                                                                                                                                                                      |
| **Development**          | Git, GitHub CLI, Git Town, JetBrains Toolbox, Zed, Sublime Text 4, Fish shell, tmux, Zellij                                                                                                                                                                                                                     |
| **Desktop (NixOS)**      | Niri (Wayland tiling), DankMaterialShell (Quickshell) status bar / notifications / launcher / lock, SDDM, Ghostty, Kitty, Helium (Chromium browser), Sway (backup WM), Rofi (Sway fallback only)                                                                                                                |
| **Self-Hosted Services** | Immich (photos), Forgejo (Git), Paperless-ngx (documents + AI), SigNoz (observability), SearXNG (privacy search), Pocket ID (SSO), Hermes AI, Gatus, PapDashboard (alert hub + services dashboard), Browser History, InboxClean (Gmail assistant), CV server, Crush Daily, Attic (binary cache), Miniflux (RSS) |
| **AI/ML**                | FastFlowLM (Qwen MoE on AMD NPU), llama-rag (embeddings + reranking on GPU), llama.cpp, AMD XDNA NPU driver                                                                                                                                                                                                      |
| **Security**             | Gitleaks, sops-nix, AppArmor, Fail2ban, ClamAV, Touch ID for sudo (macOS)                                                                                                                                                                                                                                       |
| **Monitoring**           | SigNoz (51 alert rules, 10 dashboards), Gatus (234 health checks, Discord alerting), system-health textfile collectors, sev1 desktop escalation |
| **Networking**           | Caddy reverse proxy (TLS), dnsblockd embedded resolver (sdns: DNSSEC, DoT, DoH), SearXNG metasearch, 3.9M+ blocked domains                                                                                                                                                                                      |
| **Storage**              | BTRFS with btrbk snapshots (daily, sent to a 2×16TB RAID1 HDD pool), ZRAM swap (~62 GiB at 50% of visible RAM), weekly scrub, daily fstrim                                                                                                                                                                      |

## Quick Start

### Prerequisites

- macOS (Apple Silicon) or Linux (x86_64) with Nix installed
- Administrative access

### Installation

```bash
# Install Nix (Determinate Systems installer)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Clone and apply configuration
git clone https://github.com/LarsArtmann/SystemNix.git ~/projects/SystemNix
cd ~/projects/SystemNix
nix run .#deploy         # Build and deploy to current system
nix flake check --no-build  # Validate configuration syntax
```

### Target Systems

| System                   | Hardware                           | Configuration                | Command            |
| ------------------------ | ---------------------------------- | ---------------------------- | ------------------ |
| macOS (Lars-MacBook-Air) | Apple Silicon, 24GB RAM, 256GB SSD | `flake.nix#Lars-MacBook-Air` | `nix run .#deploy` |
| NixOS (evo-x2)           | AMD Ryzen AI Max+ 395, 128GB RAM   | `flake.nix#evo-x2`           | `nix run .#deploy` |

## Architecture

```
SystemNix/
├── flake.nix                    # Main entry point with flake-parts
├── modules/nixos/services/     # 118 NixOS service modules (auto-discovered by filename)
├── modules/nixos/desktop/      # 13 desktop modules (auto-discovered)
├── pkgs/                        # Custom packages (fastflowlm, systemd-graph, dms-plugins/ with 13 widgets + 2 community)
├── overlays/                    # Shared + Linux-only overlays (callPackage + flake-input overlays)
├── lib/                         # 15 files exporting 13+ helpers (harden, ports, mkDockerServiceFactory, ...)
├── platforms/
│   ├── common/                  # Shared across platforms (~80% of config)
│   │   ├── home-base.nix        # Home Manager base (20 program modules)
│   │   ├── programs/            # Fish, Zsh, Bash, Starship, Git, tmux, ...
│   │   ├── packages/            # Cross-platform packages & fonts
│   │   └── environment/         # Nix daemon settings
│   ├── darwin/                  # macOS-specific (nix-darwin)
│   │   ├── default.nix          # System config
│   │   ├── home.nix             # User config
│   │   ├── services/            # LaunchAgents (ActivityWatch, Crush updates)
│   │   └── programs/            # Chrome policies, shell aliases
│   └── nixos/                   # NixOS-specific
│       ├── system/              # Boot, networking, BTRFS snapshots, DNS blocker
│       ├── desktop/             # Niri, DankMaterialShell (Quickshell), ssh-suspend-guard
│       ├── hardware/            # AMD GPU/NPU, Bluetooth, hardware config
│       ├── programs/            # Rofi (Sway backup), Yazi, Zellij, Chromium
│       └── users/               # Home Manager user config
├── scripts/                     # 72 operational scripts (shell + Python)
└── docs/                        # Architecture decisions (ADRs), status reports, troubleshooting
```

## NixOS Services (evo-x2)

All services are defined as flake-parts modules, reverse-proxied through Caddy with TLS, and monitored by Gatus (247 health checks) + SigNoz (51 alert rules, 10 dashboards). Counts re-derived 2026-10-24, gatus 228→229 re-stamped 2026-10-25 (alert-relay health endpoint, e22397e03), 229→230 same day (node-exporter textfile self-health check, F25/F26), 230→231 same day (unit crash-loop/churn consumption check — the 2026-10-20..25 nsfw 239-restart invisible-loop class), 231→232 same day (Memory Guard Load-Bearing per-boot trip escalation), SigNoz 47→49 same day (unit crash-loop + restart-churn rules), 49→51 same day (/data usage warn>85% + critical>90% — SUPERB T19/F67), counts 131→132 + mkRule 51→52 re-stamped 2026-10-25 (caddy-perhost-drift-audit module + caddy per-host 5xx rule), 132→133 + gatus 232→234 same day (opencloud pilot module + its 2 checks), 133→134 + gatus 234→235 same day (journal-serve module + its Hauptbuch check — owner g-2 vHost answer), 236 re-derived 2026-10-27 (working-tree count vs the 235 stamp — the re-arm wave landed an endpoint without a re-stamp), 134→135 2026-10-26 (media-atlas groundwork module — RO PG role + Immich archive read access, no port/vHost yet; media-atlas v0.1 plan L11), 135→137 2026-10-26 (late-applications + ordering-cycle-audit modules — the gitea-runner/geometrikks/crowdsec deleted-start-job ordering-cycle class fix), 137→138 + gatus 236→237 2026-10-27 (signoz-migrator-guard module + its SigNoz Migrator Guard check — the 1010 squash-gap detector), 138→139 + gatus 237→239 2026-10-27 (btrfs-balance-watch module + its Btrfs Balance Failure Watch check, and the storage-collector freshness check — storage-crisis plan S24/S25), gatus 239→241 2026-10-27 (CV CRM mirror dead-letter alarm + crm-status endpoint liveness — the 2026-10-27 CRM-mirror incident bundle, cv.nix), gatus 241→243 2026-10-28 (browser-history AI-endpoint rewire checks — sibling deploy-slot session), 243→247 2026-10-28 (sibling endpoint waves + this session's 2 dnsblockd freshness checks; doc-counts caught every missing re-stamp), 139→140 2026-10-28 (paperless-triage module — the document-triage gate; re-stamped alongside the queue batch's lint close-out), row-depth verified 2026-10-24 (7 stale rows corrected: SigNoz dashboards 6→10 + cAdvisor removed, Overview/DNS-Blocker/indexer URLs added, bank-sync + indexer-web deploy-state fixed, Dual-WAN marked disabled) — enforced by `checks.doc-counts` (`nix eval .#nixosModules` → 140; `nix eval .#nixosConfigurations.evo-x2.config.services.gatus.settings.endpoints --apply 'x: builtins.length x'` → 247; 52 `mkRule` sites + 10 dashboard JSONs in `modules/nixos/services/_signoz-alerts.nix`):

| Service             | Port             | URL                  | Description                                                                                                                                               |
| ------------------- | ---------------- | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Caddy**           | 443              | `*.home.lan`         | Reverse proxy with sops-managed TLS certs                                                                                                                 |
| **Immich**          | 2283             | `immich.home.lan`    | Self-hosted Google Photos alternative (PostgreSQL + Redis + ML)                                                                                           |
| **OpenCloud**       | 9200             | `cloud.home.lan`     | File sync & share pilot (posix driver, Pocket ID OIDC, LAN/VPN-only)                                                                                      |
| **Forgejo**         | 3000             | `forgejo.home.lan`   | Self-hosted Git forge with GitHub mirror sync & Actions                                                                                                   |
| **SigNoz**          | 4317, 4318, 8080 | `signoz.home.lan`    | Observability: traces, metrics, logs + node_exporter, 10 dashboards                                                                                       |
| **Pocket ID**       | 1411             | `auth.home.lan`      | Passkey-based SSO/IDP + oauth2-proxy forward auth                                                                                                         |
| **Hermes**          | —                | —                    | AI agent gateway (Discord bot, cron scheduler, multi-provider LLM)                                                                                        |
| **Paperless-ngx**   | 2892             | `paperless.home.lan` | Document management + OCR + AI tagging (PG backend, Tika/Gotenberg, NPU LLM)                                                                              |
| **PapDashboard**    | 8088             | `dash.home.lan`      | Alert lifecycle hub + NPU insight enricher + services dashboard (ingests Gatus; old `alerts.home.lan` redirects)                                          |
| **Browser History** | 8087             | `history.home.lan`   | Cross-device browser history (WebAuthn + Pocket ID OIDC)                                                                                                  |
| **InboxClean**      | 8099             | `inbox.home.lan`     | Gmail AI assistant (event-sourced, multi-account, HTMX dashboard)                                                                                         |
| **CV server**       | 8098             | `cv.home.lan`        | Resume/CV generator (typst PDF, pipeline scanner + LLM evaluation)                                                                                        |
| **Attic**           | 8200             | `cache.home.lan`     | Nix binary cache (pool-backed)                                                                                                                            |
| **TaskChampion**    | 10222            | `tasks.home.lan`     | Taskwarrior sync server (cross-platform + Android)                                                                                                        |
| **Overview**        | 8083             | `overview.home.lan`  | Local project dashboard (git repo discovery, stats, activity)                                                                                             |
| **Logs**            | —                | `logs.home.lan`      | Redirect to the SigNoz logs explorer (Dozzle retired with the Docker removal, 2026-10-08)                                                                 |
| **Mail Relay**      | 25               | —                    | Central outbound SMTP null client (loopback-only, relays via Resend; Paperless/Forgejo/system mail)                                                       |
| **Miniflux**        | 8101             | `rss.home.lan`       | Minimalist RSS reader (Go + local PostgreSQL, native OIDC via Pocket ID)                                                                                  |
| **Kith CRM**        | 8091             | `crm.home.lan`*      | Event-sourced CRM (Go + go-cqrs-lite) — Twenty replacement, rebranded **Ledger → Kith** 2026-10-08; Pocket ID OIDC is the only sign-in since 2026-10-17 (`-passkeys=false`) |
| **indexer-web**     | 8105             | `index.home.lan`     | Event-sourced docs index WebUI (deployed)                                                                                                                 |
| **NetBird VPN**     | 51820            | —                    | Self-hosted WireGuard mesh (pbx control plane) — CONNECTED 2026-10-15 (evo-x2 enrolled; runbook `docs/services/net-vpn.md`)                                              |
| **NSFW Filter**     | 8104             | `nsfw.home.lan`      | Go/ONNX NSFW image server — browser-extension backend (auto-discovery + pairing token)                                                                    |
| **bank-sync**       | 8097             | `banksync.home.lan`  | Wise bank-sync dashboard (Layer 2 protected; canary + Paperless/Qonto sync units deployed)                                                                |
| **journal-serve**   | 8484 (loopback)  | `journal.home.lan`   | Hauptbuch dashboard over the journal accounting kernel (Layer 2 protected; unit binds loopback only until upstream T16 auth)                               |
| **File Renamer**    | 8086             | `renamer.home.lan`   | AI file-and-image renamer service                                                                                                                         |
| **Monitor365**      | 3001             | `monitor.home.lan`   | Device monitoring agent + server dashboard (re-enabled 2026-10-18 after the upstream preparedSrc restructure unblocked the build)                                                                   |
| **OpenSEO**         | 3002             | `seo.home.lan`       | Self-hosted SEO suite (rank tracking, keyword research)                                                                                                   |
| **Crush Daily**     | 8081             | `daily.home.lan`     | AI-powered development insights from Crush databases                                                                                                      |
| **PMA**             | —                | —                    | Projects Management Automation (AI commit messages, repo discovery)                                                                                       |
| **Dual-WAN**        | —                | —                    | MPTCP dual-WAN with route health monitoring (module in-tree, currently disabled)                                                                          |
| **Gatus**           | 9110             | `status.home.lan`    | Health check monitoring with Discord alerts                                                                                                               |
| **DNS Blocker**     | 53, 8050         | `dnsblock.home.lan`  | dnsblockd (embedded sdns resolver: DNSSEC, DoT, DoH, caching), 23 blocklists, 2.5M+ domains blocked                                                       |
| **Mullvad VPN**     | —                | —                    | WireGuard VPN — currently disabled (talpid_dns corrupted resolv.conf)                                                                                     |
| **DiscordSync**     | —                | —                    | Continuous Discord channel backup bot                                                                                                                     |
| **SearXNG**         | 8889             | `search.home.lan`    | Privacy metasearch engine (70+ engines, no tracking, POST-only, DuckDuckGo icons)                                                                         |
| **FastFlowLM**      | 52625            | —                    | NPU LLM server (Qwen3.6 MoE, socket-activated, OpenAI-compatible)                                                                                         |
| **llama-rag**       | 8848, 8849       | —                    | GPU embeddings (bge-m3) + reranking (bge-reranker-v2-m3) for RAG                                                                                          |
| **llama-vlm**       | 8127, 8128       | —                    | CPU socket-activated vision servers (Gemma-4-E4B image reasoning + NSFWCaption-v3 Qwen3-VL-8B captioning, idle-stop)                                      |
| **systemd-graph**   | 8847             | `graph.home.lan`     | Live systemd dependency graph (LAN-only)                                                                                                                  |
| **timer-monitor**   | —                | `timers.home.lan`    | Read-only systemd services+timers audit (LAN-only)                                                                                                        |

### DNS Blocking

- dnsblockd with embedded sdns recursive resolver (DNSSEC, DoT, DoH, caching, local zones, LAN ACLs)
- 3.9M+ blocked domains across 23 blocklists (ads, trackers, malware, telemetry, gambling, native device trackers)
- Blocklist hot-reload with automatic cache flush
- Local `.home.lan` DNS zone — explicit per-service records (dnsblockd has NO wildcard local resolution; new subdomains must be listed)
- IPv6 disabled at DNS level (no global IPv6 on evo-x2)
- **DNS failover**: Raspberry Pi 3 secondary resolver with VRRP VIP (planned)

## NixOS Desktop

- **DankMaterialShell (DMS / Quickshell)**: Desktop shell replacing Waybar, Dunst, wlogout, swaylock, and rofi — status bar, notifications, launcher, lock screen, power menu, clipboard, wallpaper
- **Ghostty**: Primary terminal (GPU-accelerated, native Wayland)
- **Kitty**: Backup terminal (GPU-accelerated, image display)
- **SDDM**: Login manager with Catppuccin Mocha theme
- **Theme**: Catppuccin Mocha across all applications (GTK, Qt, terminal, browser)
- **Helium**: Ungoogled Chromium fork (Chromium 151) with Widevine DRM, VA-API hardware video decode, Catppuccin Mocha theme
- **Backup WM**: Sway configured as fallback (uses Rofi, not DMS)

## NixOS Hardware (evo-x2)

| Component   | Configuration                                                                                                                                                                        |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **CPU**     | AMD Ryzen AI Max+ 395 (Strix Halo), amd_pstate=guided                                                                                                                                |
| **GPU**     | AMD integrated (amdgpu), Mesa latest, ROCm compute stack                                                                                                                             |
| **NPU**     | AMD XDNA via nix-amd-npu, XRT runtime                                                                                                                                                |
| **Memory**  | 128GB physical (~124 GiB visible after the 1 GiB BIOS-floor GPU carveout), ZRAM swap (~62 GiB at 50%, zram-only), tuned for AI/ML workloads                                          |
| **Storage** | BTRFS root (zstd, QLC-tuned: commit=300, daily fstrim) + `/data` (zstd:3) + ClickHouse XFS partition + 2×16TB BTRFS RAID1 HDD pool; btrbk snapshots (daily) sent to the pool nightly |
| **Boot**    | systemd-boot (50 generations), latest Linux kernel                                                                                                                                   |
| **Network** | Realtek 2.5G Ethernet, MediaTek WiFi                                                                                                                                                 |

## Essential Commands

```bash
# Core workflow
nix flake check --no-build  # Validate configuration syntax (fast)
nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel  # Quick eval
nix run .#deploy            # Build and deploy via nh
nix run .#pre-deploy-check  # Catch boot-breaking issues before switch
nix run .#post-deploy-check # Verify services are functional after deploy
nix fmt                     # Format code with treefmt + alejandra
nix flake update            # Update flake inputs

# Maintenance
nix-collect-garbage -d      # Clean old generations
scripts/health-check.sh     # System health check
scripts/verify-deployment.sh # Deployment readiness validator

# DNS diagnostics
nix run .#dns-diagnostics   # Full DNS diagnostics (Linux)
scripts/dns-diagnostics.sh   # Direct DNS diagnostics script

# Service status checks
scripts/status-report.sh     # Comprehensive system status
```

## Cross-Platform Programs

Shared across macOS and NixOS via `platforms/common/programs/`:

| Program       | Configuration                                                     |
| ------------- | ----------------------------------------------------------------- |
| **Fish**      | Primary shell, shared aliases, carapace completions, 5000 history |
| **Zsh**       | Secondary shell with autosuggestions, syntax highlighting         |
| **Starship**  | Prompt with Catppuccin Mocha, performance-optimized               |
| **Git**       | GPG signing, SSH remotes, git-town integration                    |
| **tmux**      | Catppuccin theme, resurrect plugin, SystemNix dev session         |
| **FZF**       | Ripgrep integration, reverse layout                               |
| **KeePassXC** | Browser integration (Chromium + Helium)                           |
| **Chromium**  | Enterprise policies, YouTube Shorts Blocker, HTTPS-only           |

## Flake Inputs

56→68 inputs — key ones below:

| Input                  | Purpose                                         |
| ---------------------- | ----------------------------------------------- |
| `nixpkgs`              | Package collection (unstable)                   |
| `nix-darwin`           | macOS system management                         |
| `home-manager`         | Cross-platform user configuration               |
| `flake-parts`          | Modular flake architecture                      |
| `niri`                 | Scrollable-tiling Wayland compositor            |
| `nix-homebrew`         | Declarative Homebrew management (macOS)         |
| `sops-nix`             | Secrets management with age encryption          |
| `nix-amd-npu`          | AMD NPU (XDNA) driver                           |
| `nix-ssh-config`       | Shared SSH configuration                        |
| `crush-config`         | AI assistant configuration                      |
| `hermes-agent`         | AI agent gateway (Discord bot)                  |
| `silent-sddm`          | SDDM theme with Catppuccin support              |
| `signoz-src`           | SigNoz observability source (built from source) |
| `signoz-collector-src` | SigNoz OTel collector source                    |
| `dnsblockd`            | Custom DNS blocker (Go)                         |
| `treefmt-full-flake`   | Code formatting (alejandra + more)              |
| `nixos-hardware`       | Hardware-specific NixOS modules                 |
| `helium`               | Helium browser (macOS)                          |
| `nur`                  | Nix User Repository                             |
| `wallpapers-src`       | Wallpaper collection                            |

Color schemes are defined locally in `platforms/common/theme.nix` (not via a flake input).

## CI/CD

Six GitHub Actions workflows (`.github/workflows/`), running on push/PR to master (Ubuntu runner):

- **nix-check.yml** — `nix flake check --no-build`, statix/deadnix lints, formatting arbiter (`nix fmt -- --ci` over the locked treefmt), package builds, VM tests (private inputs via SSH deploy keys; private `github:` lock nodes via the `NIX_GITHUB_RO_TOKEN` fallback)
- **nixpkgs-compat.yml** — daily nixpkgs compatibility eval
- **secret-history-scan.yml** — full-history secret scan (gzip-aware python scanner; CI counterpart to gitleaks)
- **go-deps-audit.yml** — nightly go.mod-vs-flake.lock dependency audit (`scripts/audit-go-deps.sh`)
- **image-updates.yml** — daily Docker image digest/semver drift check against Docker Hub
- **flake-update.yml** — scheduled input bump attempts

### Pre-commit

The repo uses `.githooks/pre-commit` (via `core.hooksPath`), linting STAGED files only — not the entire codebase:

- gitleaks (secrets), deadnix + statix + the locked formatter (Nix), shellcheck
- `nix flake check --no-build` (eval + all assertions incl. the 7 audit modules)
- Guard scripts: tarball-type nixpkgs rejection, Gatus `pat()` glob-trap lint, `*_templ.go` committed check, nullglob command-indirection audit, Unknown-Author identity guard

## Documentation

| Guide                                                       | Description                                         |
| ----------------------------------------------------------- | --------------------------------------------------- |
| [AGENTS.md](./AGENTS.md)                                    | AI assistant guide and project conventions          |
| [docs/CONTRIBUTING.md](./docs/CONTRIBUTING.md)              | Contributor setup, style, and verification commands |
| [Architecture Decisions](./docs/architecture/)              | ADRs for key design choices                         |
| [Project Status](./docs/status/)                            | Development status reports                          |
| [Troubleshooting](./docs/troubleshooting/)                  | Common issues and solutions                         |
| [Architecture Diagrams](./docs/architecture-understanding/) | Mermaid diagram collection                          |

## Troubleshooting

### Build Errors

```bash
nix flake check --no-build  # Quick syntax validation
nix-collect-garbage -d      # Clean and rebuild
nix run .#deploy            # Rebuild and deploy
```

### GPG Not Working

```bash
nix profile add nixpkgs#gnupg
# Path: ~/.nix-profile/bin/gpg
```

### Package Not Found

```bash
nix search nixpkgs <package-name>
```

### DNS Issues (NixOS)

```bash
scripts/dns-diagnostics.sh  # Full DNS diagnostics
```

## Contributing

See [docs/CONTRIBUTING.md](./docs/CONTRIBUTING.md) for the full contributor guide, style rules, and verification commands.

Quick checklist:

1. Make changes in `platforms/common/` for cross-platform config
2. Use platform-specific directories for platform differences
3. Run `nix flake check --no-build` before committing
4. Follow existing code style (2-space indentation for Nix)
5. Install pre-commit hooks: `pre-commit install`

## License

Personal configuration. Adapt for your own use.
