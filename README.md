# SystemNix

**Declarative cross-platform system configuration using Nix.**

SystemNix manages both macOS (nix-darwin) and NixOS systems through a single, reproducible Nix flake. All system settings, packages, services, and user configurations are defined in code and applied consistently across machines.

## What You Get

| Category                 | Tools & Services                                                                                                                                                      |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Languages**            | Go 1.26, Node.js, Bun, Python 3.13, Rust                                                                                                                              |
| **Cloud & Infra**        | AWS CLI, GCP SDK, kubectl, Helm, Terraform, Docker                                                                                                                    |
| **Development**          | Git, GitHub CLI, Git Town, JetBrains Toolbox, Zed, Sublime Text 4, Fish shell, tmux, Zellij                                                                           |
| **Desktop (NixOS)**      | Niri (Wayland tiling), DankMaterialShell (Quickshell) status bar / notifications / launcher / lock, SDDM, Ghostty, Kitty, Sway (backup WM), Rofi (Sway fallback only) |
| **Self-Hosted Services** | Immich (photos), Forgejo (Git), SigNoz (observability), Homepage Dashboard, Hermes AI                                                                                 |
| **AI/ML**                | Ollama (ROCm), llama.cpp, AMD NPU (XDNA) driver                                                                                                                       |
| **Security**             | Gitleaks, sops-nix, AppArmor, Fail2ban, ClamAV, Touch ID for sudo (macOS)                                                                                             |
| **Monitoring**           | SigNoz (18 alert rules, 9 dashboards), Gatus (52+ health checks), ActivityWatch                                                                                       |
| **Networking**           | Caddy reverse proxy (TLS), dnsblockd embedded resolver (sdns: DNSSEC, DoT, DoH), 2.5M+ blocked domains                                                                |
| **Storage**              | BTRFS with btrbk snapshots (daily), ZRAM swap (~16 GiB), monthly scrub                                                                                                |

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
├── modules/nixos/services/     # 35 NixOS service modules + 6 desktop modules (auto-discovered, ~34 enabled)
├── pkgs/                        # 6 custom package derivations + dms-plugins/ (13 widgets)
├── overlays/                    # Shared + Linux-only overlays (callPackage + flake-input overlays)
├── lib/                         # 10 files exporting 13+ helpers (harden, ports, mkDockerServiceFactory, ...)
├── platforms/
│   ├── common/                  # Shared across platforms (~80% of config)
│   │   ├── home-base.nix        # Home Manager base (19 program modules)
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
├── scripts/                     # 36 operational scripts (shell + Python)
└── docs/                        # Architecture decisions (ADRs), status reports, troubleshooting
```

## NixOS Services (evo-x2)

All services are defined as flake-parts modules, reverse-proxied through Caddy with TLS, and monitored by Gatus (52+ health checks) + SigNoz (18 alert rules, 9 dashboards):

| Service          | Port             | URL                 | Description                                                                                         |
| ---------------- | ---------------- | ------------------- | --------------------------------------------------------------------------------------------------- |
| **Caddy**        | 443              | `*.home.lan`        | Reverse proxy with sops-managed TLS certs                                                           |
| **Immich**       | 2283             | `immich.home.lan`   | Self-hosted Google Photos alternative (PostgreSQL + Redis + ML)                                     |
| **Forgejo**      | 3000             | `forgejo.home.lan`  | Self-hosted Git forge with GitHub mirror sync & Actions                                             |
| **SigNoz**       | 4317, 4318, 8080 | `signoz.home.lan`   | Observability: traces, metrics, logs + node_exporter + cAdvisor, 6 dashboards                       |
| **Homepage**     | 8082             | `dash.home.lan`     | Service overview dashboard                                                                          |
| **Pocket ID**    | 1411             | `auth.home.lan`     | Passkey-based SSO/IDP + oauth2-proxy forward auth                                                   |
| **Hermes**       | —                | —                   | AI agent gateway (Discord bot, cron scheduler, multi-provider LLM)                                  |
| **Twenty CRM**   | 3200             | `crm.home.lan`      | Self-hosted CRM (Docker Compose: PostgreSQL + Redis)                                                |
| **Voice Agents** | 7880             | —                   | AI voice agents (Docker: LiveKit + Whisper ASR with ROCm)                                           |
| **TaskChampion** | 10222            | `tasks.home.lan`    | Taskwarrior sync server (cross-platform + Android)                                                  |
| **Manifest**     | 2099             | `manifest.home.lan` | Smart LLM router for AI agents (cost optimization)                                                  |
| **Overview**     | 8083             | —                   | Local project dashboard (git repo discovery, stats, activity)                                       |
| **Dozzle**       | 8084             | `logs.home.lan`     | Real-time Docker container log viewer                                                               |
| **Monitor365**   | 3001             | `monitor.home.lan`  | Device monitoring agent + server dashboard                                                          |
| **OpenSEO**      | 3002             | `seo.home.lan`      | Self-hosted SEO suite (rank tracking, keyword research)                                             |
| **Crush Daily**  | 8081             | `daily.home.lan`    | AI-powered development insights from Crush databases                                                |
| **PMA**          | —                | —                   | Projects Management Automation (AI commit messages, repo discovery)                                 |
| **Dual-WAN**     | —                | —                   | MPTCP dual-WAN with route health monitoring                                                         |
| **Gatus**        | 9110             | `status.home.lan`   | Health check monitoring with Discord alerts                                                         |
| **DNS Blocker**  | 53, 8050         | —                   | dnsblockd (embedded sdns resolver: DNSSEC, DoT, DoH, caching), 23 blocklists, 2.5M+ domains blocked |
| **Mullvad VPN**  | —                | —                   | WireGuard VPN — currently disabled (talpid_dns corrupted resolv.conf)                               |
| **DiscordSync**  | —                | —                   | Continuous Discord channel backup bot                                                               |

### DNS Blocking

- dnsblockd with embedded sdns recursive resolver (DNSSEC, DoT, DoH, caching, local zones, LAN ACLs)
- 2.5M+ blocked domains across 23 blocklists (ads, trackers, malware, telemetry, gambling, native device trackers)
- Blocklist hot-reload with automatic cache flush
- Local `.home.lan` DNS zone with wildcard resolution for all services
- IPv6 disabled at DNS level (no global IPv6 on evo-x2)
- **DNS failover**: Raspberry Pi 3 secondary resolver with VRRP VIP (planned)

## NixOS Desktop

- **DankMaterialShell (DMS / Quickshell)**: Desktop shell replacing Waybar, Dunst, wlogout, swaylock, and rofi — status bar, notifications, launcher, lock screen, power menu, clipboard, wallpaper
- **Ghostty**: Primary terminal (GPU-accelerated, native Wayland)
- **Kitty**: Backup terminal (GPU-accelerated, image display)
- **SDDM**: Login manager with Catppuccin Mocha theme
- **Theme**: Catppuccin Mocha across all applications (GTK, Qt, terminal, browser)
- **Backup WM**: Sway configured as fallback (uses Rofi, not DMS)

## NixOS Hardware (evo-x2)

| Component   | Configuration                                                                                            |
| ----------- | -------------------------------------------------------------------------------------------------------- |
| **CPU**     | AMD Ryzen AI Max+ 395 (Strix Halo), amd_pstate=guided                                                    |
| **GPU**     | AMD integrated (amdgpu), Mesa latest, ROCm compute stack                                                 |
| **NPU**     | AMD XDNA via nix-amd-npu, XRT runtime                                                                    |
| **Memory**  | 128GB physical (~94 GiB visible after GPU VRAM carveout), ZRAM swap (~16 GiB), tuned for AI/ML workloads |
| **Storage** | BTRFS root (zstd) + `/data` (zstd:3), btrbk snapshots (daily)                                            |
| **Boot**    | systemd-boot (50 generations), latest Linux kernel                                                       |
| **Network** | Realtek 2.5G Ethernet, MediaTek WiFi                                                                     |

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
| **Git**       | GPG signing, SSH insteadOf HTTPS, git-town integration            |
| **tmux**      | Catppuccin theme, resurrect plugin, SystemNix dev session         |
| **FZF**       | Ripgrep integration, reverse layout                               |
| **KeePassXC** | Browser integration (Chromium + Helium)                           |
| **Chromium**  | Enterprise policies, YouTube Shorts Blocker, HTTPS-only           |

## Flake Inputs

56 inputs — key ones below:

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

GitHub Actions workflow (`.github/workflows/nix-check.yml`) runs on every push/PR to master (Ubuntu runner):

- **Flake evaluation**: `nix flake check --no-build --all-systems`
- **Package builds**: `jscpd`, `govalid`, `aw-watcher-utilization`
- **Statix**: Nix anti-pattern linting
- **Deadnix**: Dead code detection
- **Formatting**: `nix fmt -- --check .`

### Pre-commit Hooks

10 hooks configured via `.pre-commit-config.yaml`:

- **gitleaks** — secret detection
- **alejandra** — Nix formatting
- **deadnix** — dead code detection
- **statix** — Nix anti-patterns
- **trailing-whitespace** — whitespace cleanup
- **nix-check** — flake validation
- **flake-lock-validate** — lock file integrity
- **shellcheck** — shell script linting
- **check-merge-conflicts** — conflict marker detection
- **protect-home-audit** — catches `harden {}` services that silently lose access to `/home`

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
