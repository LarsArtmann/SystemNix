# SystemNix

**Declarative cross-platform system configuration using Nix.**

SystemNix manages both macOS (nix-darwin) and NixOS systems through a single, reproducible Nix flake. All system settings, packages, services, and user configurations are defined in code and applied consistently across machines.

## What You Get

| Category | Tools & Services |
|----------|-----------------|
| **Languages** | Go 1.26, Node.js, Bun, Python 3.13, Rust |
| **Cloud & Infra** | AWS CLI, GCP SDK, kubectl, Helm, Terraform, Docker |
| **Development** | Git, GitHub CLI, Git Town, JetBrains Toolbox, (editor of choice - NOT VS Code), Fish shell, tmux, Zellij |
| **Desktop (NixOS)** | Niri (Wayland tiling), Waybar, SDDM, Rofi, Ghostty, Kitty, Dunst, swaylock |
| **Self-Hosted Services** | Immich (photos), Forgejo (Git), SigNoz (observability), Homepage Dashboard, Hermes AI |
| **AI/ML** | Ollama (ROCm), llama.cpp, AMD NPU (XDNA) driver |
| **Security** | Gitleaks, sops-nix, AppArmor, Fail2ban, ClamAV, Touch ID for sudo (macOS) |
| **Monitoring** | SigNoz (18 alert rules, 5 dashboards), Gatus (30 health checks), ActivityWatch |
| **Networking** | Caddy reverse proxy (TLS), Unbound DNS with 2.5M+ blocked domains, DNSSEC |
| **Storage** | BTRFS with btrbk snapshots (daily + pre-deploy), ZRAM swap, monthly scrub |

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
just setup              # Complete setup
just switch             # Apply configuration
```

### Target Systems

| System | Hardware | Configuration | Command |
|--------|----------|--------------|---------|
| macOS (Lars-MacBook-Air) | Apple Silicon, 24GB RAM, 256GB SSD | `flake.nix#Lars-MacBook-Air` | `just switch` |
| NixOS (evo-x2) | AMD Ryzen AI Max+ 395, 128GB RAM | `flake.nix#evo-x2` | `just switch` |

## Architecture

```
SystemNix/
├── flake.nix                    # Main entry point with flake-parts
├── justfile                     # Task runner for all operations
├── modules/nixos/services/     # 36 NixOS service modules (auto-discovered, 29 enabled)
├── pkgs/                        # 5 custom packages (jscpd, govalid, netwatch, openaudible, aw-watcher)
├── overlays/                    # 12 overlay packages via mkPackageOverlay + manual overlays
├── lib/                         # 13 reusable helpers (harden, ports, mkDockerServiceFactory, ...)
├── platforms/
│   ├── common/                  # Shared across platforms (~80% of config)
│   │   ├── home-base.nix        # Home Manager base (14 program modules)
│   │   ├── programs/            # Fish, Zsh, Bash, Nushell, Starship, Git, tmux, ...
│   │   ├── packages/            # Cross-platform packages & fonts
│   │   └── core/                # Nix daemon settings
│   ├── darwin/                  # macOS-specific (nix-darwin)
│   │   ├── default.nix          # System config
│   │   ├── home.nix             # User config
│   │   ├── services/            # LaunchAgents (ActivityWatch, Crush updates)
│   │   └── programs/            # Chrome policies, shell aliases
│   └── nixos/                   # NixOS-specific
│       ├── system/              # Boot, networking, BTRFS snapshots, DNS blocker
│       ├── desktop/             # Niri, Waybar, SDDM, AI stack, security hardening
│       ├── hardware/            # AMD GPU/NPU, Bluetooth, hardware config
│       ├── programs/            # Rofi, swaylock, wlogout, Yazi, Zellij, Chromium
│       └── users/               # Home Manager user config
├── scripts/                     # 23 operational scripts
└── docs/                        # Architecture decisions (8 ADRs), status reports, troubleshooting
```

## NixOS Services (evo-x2)

All services are defined as flake-parts modules, reverse-proxied through Caddy with TLS, and monitored by Gatus (30 health checks) + SigNoz (18 alert rules):

| Service | Port | URL | Description |
|---------|------|-----|-------------|
| **Caddy** | 443 | `*.home.lan` | Reverse proxy with sops-managed TLS certs |
| **Immich** | 2283 | `immich.home.lan` | Self-hosted Google Photos alternative (PostgreSQL + Redis + ML) |
| **Forgejo** | 3000 | `forgejo.home.lan` | Self-hosted Git forge with GitHub mirror sync & Actions |
| **SigNoz** | 4317, 4318, 8080 | `signoz.home.lan` | Observability: traces, metrics, logs + node_exporter + cAdvisor |
| **Homepage** | 8082 | `dash.home.lan` | Service overview dashboard |
| **Pocket ID** | 1411 | `auth.home.lan` | Passkey-based SSO/IDP + oauth2-proxy forward auth |
| **Hermes** | — | — | AI agent gateway (Discord bot, cron scheduler, multi-provider LLM) |
| **Twenty CRM** | 3200 | `crm.home.lan` | Self-hosted CRM (Docker Compose: PostgreSQL + Redis) |
| **Voice Agents** | 7880 | — | AI voice agents (Docker: LiveKit + Whisper ASR with ROCm) |
| **TaskChampion** | 10222 | `tasks.home.lan` | Taskwarrior sync server (cross-platform + Android) |
| **DNS Blocker** | 53, 8083 | — | Unbound + dnsblockd, 10 blocklists, 2.5M+ domains blocked, DoT upstream |

### DNS Blocking

- 2.5M+ blocked domains (ads, trackers, malware, telemetry, gambling)
- Upstream: Quad9 (DNS-over-TLS) + Cloudflare fallback
- Local `.home.lan` DNS records for all services
- DNSSEC enabled, qname minimization
- **DNS failover**: Raspberry Pi 3 secondary resolver with VRRP VIP (planned)

## NixOS Desktop

- **Niri**: Scrollable-tiling Wayland compositor with 5 named workspaces, session save/restore
- **Ghostty**: Primary terminal (GPU-accelerated, native Wayland)
- **Kitty**: Backup terminal (GPU-accelerated, image display)
- **Waybar**: Custom status bar with workspaces, media, weather, DNS stats, power menu
- **SDDM**: Login manager with Catppuccin Mocha theme
- **Theme**: Catppuccin Mocha across all applications (GTK, Qt, terminal, browser)
- **Backup WM**: Sway configured as fallback

## NixOS Hardware (evo-x2)

| Component | Configuration |
|-----------|--------------|
| **CPU** | AMD Ryzen AI Max+ 395 (Strix Halo), amd_pstate=guided |
| **GPU** | AMD integrated (amdgpu), Mesa latest, ROCm compute stack |
| **NPU** | AMD XDNA via nix-amd-npu, XRT runtime |
| **Memory** | 128GB unified, ZRAM swap (32GB), tuned for AI/ML workloads |
| **Storage** | BTRFS root (zstd) + `/data` (zstd:3), btrbk snapshots (daily + pre-deploy) |
| **Boot** | systemd-boot (50 generations), latest Linux kernel |
| **Network** | Realtek 2.5G Ethernet, MediaTek WiFi |

## Essential Commands

```bash
# Core workflow
just setup              # Initial setup (run once after clone)
just switch             # Apply configuration changes
just update             # Update flake inputs and packages
just update-nix         # Self-update Nix to latest version
just test               # Validate configuration (full build)
just test-fast          # Syntax-only validation (fast)
just check              # System status, git, disk usage

# Quality
just format             # Format code with treefmt + alejandra
just health             # System health check
just pre-commit-install # Install pre-commit hooks
just pre-commit-run     # Run all hooks on all files

# Maintenance
just clean              # Comprehensive cleanup (Nix, caches, temp, Docker)
just rollback           # Revert to previous generation

# NixOS services
just dns-diagnostics    # Full DNS diagnostics
just immich-status       # Check Immich service status
just immich-backup       # Run database backup
just forgejo-sync-repos  # Sync GitHub repos to Forgejo
just hermes-status       # Check Hermes gateway status
just manifest-status     # Check Manifest LLM router status
just session-status      # Check niri session save state
just cam-status          # Check EMEET PIXY webcam state

# Taskwarrior
just task-list           # Show pending tasks
just task-sync           # Sync with TaskChampion server
just task-backup         # Export all tasks as JSON
```

## Cross-Platform Programs

Shared across macOS and NixOS via `platforms/common/programs/`:

| Program | Configuration |
|---------|--------------|
| **Fish** | Primary shell, shared aliases, carapace completions, 5000 history |
| **Zsh** | Secondary shell with autosuggestions, syntax highlighting |
| **Starship** | Prompt with Catppuccin Mocha, performance-optimized |
| **Git** | GPG signing, SSH insteadOf HTTPS, git-town integration |
| **tmux** | Catppuccin theme, resurrect plugin, SystemNix dev session |
| **FZF** | Ripgrep integration, reverse layout |
| **KeePassXC** | Browser integration (Chromium + Helium) |
| **Chromium** | Enterprise policies, YouTube Shorts Blocker, HTTPS-only |

## Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` | Package collection (unstable) |
| `nix-darwin` | macOS system management |
| `home-manager` | Cross-platform user configuration |
| `flake-parts` | Modular flake architecture |
| `niri` | Scrollable-tiling Wayland compositor |
| `nix-homebrew` | Declarative Homebrew management (macOS) |
| `sops-nix` | Secrets management with age encryption |
| `nix-amd-npu` | AMD NPU (XDNA) driver |
| `nix-ssh-config` | Shared SSH configuration |
| `crush-config` | AI assistant configuration |
| `hermes-agent` | AI agent gateway (Discord bot) |
| `nix-colors` | Declarative color schemes |
| `silent-sddm` | SDDM theme with Catppuccin support |
| `signoz-src` | SigNoz observability source (built from source) |
| `nur` | Nix User Repository |

## CI/CD

GitHub Actions workflow (`.github/workflows/nix-check.yml`):
- **Flake check**: `nix flake check` on macOS and Ubuntu
- **Build**: Full Darwin build on macOS runner
- **Syntax check**: `nix flake check --no-build` on Ubuntu

### Pre-commit Hooks

9 hooks configured via `.pre-commit-config.yaml`:
- **gitleaks** — secret detection
- **alejandra** — Nix formatting
- **deadnix** — dead code detection
- **statix** — Nix anti-patterns
- **trailing-whitespace** — whitespace cleanup
- **nix-check** — flake validation
- **flake-lock-validate** — lock file integrity
- **shellcheck** — shell script linting
- **check-merge-conflicts** — conflict marker detection

## Documentation

| Guide | Description |
|-------|-------------|
| [AGENTS.md](./AGENTS.md) | AI assistant guide and project conventions |
| [Architecture Decisions](./docs/architecture/) | ADRs for key design choices |
| [Project Status](./docs/status/) | Development status reports |
| [Troubleshooting](./docs/troubleshooting/) | Common issues and solutions |
| [Architecture Diagrams](./docs/architecture-understanding/) | Mermaid diagram collection |

## Troubleshooting

### Build Errors

```bash
just test-fast          # Quick syntax validation
just clean && just switch  # Clean and rebuild
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
just dns-diagnostics    # Full DNS diagnostics
just dns-restart        # Restart DNS services
just dns-test           # Test resolution and blocking
```

## Contributing

1. Make changes in `platforms/common/` for cross-platform config
2. Use platform-specific directories for platform differences
3. Run `just test` before committing
4. Follow existing code style (2-space indentation for Nix)

## License

Personal configuration. Adapt for your own use.
