# SystemNix: AGENT GUIDE


**Project Type:** Cross-Platform Nix Configuration (macOS + NixOS)
**Repo:** `github:LarsArtmann/SystemNix`

---

## Project Overview

SystemNix manages two machines through a single Nix flake:

| System | Hostname | Platform | Hardware |
|--------|----------|----------|----------|
| macOS | `Lars-MacBook-Air` | aarch64-darwin | Apple Silicon |
| NixOS | `evo-x2` | x86_64-linux | AMD Ryzen AI Max+ 395, 128GB |

~80% of configuration is shared via `platforms/common/`. Platform-specific code lives in `platforms/darwin/` and `platforms/nixos/`.

## Architecture

```
SystemNix/
├── flake.nix                    # Entry point (flake-parts)
├── justfile                     # Task runner — ALWAYS use this over raw Nix commands
│
├── modules/nixos/services/      # NixOS service modules (flake-parts)
│   ├── default.nix              # Docker + Nix GC timer
│   ├── caddy.nix                # Reverse proxy (TLS via sops)
│   ├── gitea.nix                # Git hosting + GitHub mirror
│   ├── homepage.nix             # Service dashboard
│   ├── immich.nix               # Photo/video management
│   ├── photomap.nix             # AI photo exploration
│   ├── signoz.nix               # Observability (traces/metrics/logs)
│   ├── sops.nix                 # Secrets management
│   ├── taskchampion.nix         # Taskwarrior sync server
│   └── openseo.nix              # SEO suite (rank tracking, keywords, backlinks)
│
├── pkgs/                        # Custom packages
│   ├── aw-watcher-utilization.nix # ActivityWatch system utilization watcher (Python)
│   ├── dnsblockd.nix            # DNS block page server (Go)
│   ├── jscpd.nix                # Copy/paste detector (Node.js)
│   ├── modernize.nix            # Go modernize tool
│   ├── monitor365.nix           # Device monitoring agent (Rust)
│   ├── netwatch.nix             # Real-time network diagnostics TUI (Rust)
│   ├── openaudible.nix          # Audible audiobook manager (AppImage)
│   ├── file-and-image-renamer.nix # AI screenshot renaming (Go)
│
│   # External flake inputs (packages via overlay — no local pkgs/ file)
│   # emeet-pixyd             — EMEET PIXY webcam daemon
│   # todo-list-ai            — AI-powered TODO extraction CLI
│   # golangci-lint-auto-configure — golangci-lint auto-configurator
│   # mr-sync                 — ~/.mrconfig GitHub sync CLI
│   # hierarchical-errors     — Error handling pattern analyzer
│
└── platforms/
    ├── common/                  # Shared (~80%)
    │   ├── home-base.nix        # Imports 14 program modules
    │   ├── programs/            # fish, zsh, bash, starship, git, tmux, fzf, taskwarrior, ...
    │   ├── packages/base.nix    # All cross-platform packages (70+)
    │   └── core/nix-settings.nix
    ├── darwin/                  # macOS (nix-darwin)
    │   ├── default.nix          # System config (user: larsartmann)
    │   ├── home.nix             # HM config (imports common/home-base.nix)
    │   ├── services/launchagents.nix  # ActivityWatch, Crush updates
    │   └── programs/shells.nix  # darwin-rebuild aliases
    └── nixos/                   # NixOS
        ├── system/configuration.nix  # Main system entry
        ├── system/primary-user.nix    # Shared primaryUser option (default: "lars")
        ├── system/boot.nix      # systemd-boot, kernel params, ZRAM
        ├── system/networking.nix # Static IP, firewall
        ├── system/dns-blocker-config.nix  # Unbound + dnsblockd
        ├── system/snapshots.nix # BTRFS + Timeshift
        ├── desktop/             # Niri, Waybar, SDDM, AI stack, security
        ├── hardware/            # AMD GPU/NPU, Bluetooth, EMEET PIXY
        ├── programs/            # Rofi, swaylock, wlogout, Yazi, Zellij, Chromium
        └── users/home.nix       # HM config (imports common/home-base.nix)
```

## Key Patterns

### NixOS Service Modules (flake-parts)

Services are self-contained flake-parts modules in `modules/nixos/services/`. Each module:
- Defines its own `config` options under `services.<name>`
- Manages its own systemd services, users, and dependencies
- Is imported in `flake.nix` via `imports = [ ./modules/nixos/services/<name>.nix ];`
- Is wired into the NixOS configuration via `inputs.self.nixosModules.<name>`

To add a new service:
1. Create `modules/nixos/services/<name>.nix` as a flake-parts module
2. Add it to `imports` in `flake.nix`
3. Add `inputs.self.nixosModules.<name>` to the evo-x2 module list
4. Enable it in `platforms/nixos/system/configuration.nix`

### Cross-Platform Home Manager

Both platforms import `platforms/common/home-base.nix`, which pulls in 14 program modules from `platforms/common/programs/`. The import paths differ:

```nix
# Darwin (platforms/darwin/home.nix)
imports = [ ../common/home-base.nix ];

# NixOS (platforms/nixos/users/home.nix)
imports = [ ../../common/home-base.nix ];
```

**Rules:**
- Shared config goes in `platforms/common/` — both platforms inherit it
- Platform differences use `pkgs.stdenv.isLinux` / `pkgs.stdenv.isDarwin`
- Only override in platform dirs for things that genuinely differ
- Darwin user: `larsartmann`, NixOS user: `lars`

### Custom Overlays

All private LarsArtmann repos use `git+ssh://git@github.com/LarsArtmann/<name>?ref=<branch>` for flake inputs. No `path:` inputs exist — the flake is fully portable.

**Naming convention:** `-src` suffix = `flake = false` (source-only). No suffix = full flake.

**Active overlays:**
- `sharedOverlays` — applied on Darwin + NixOS (NUR, aw-watcher, todo-list-ai, jscpd, library-policy, buildflow, go-auto-upgrade, go-structure-linter, branching-flow, art-dupl, golangci-lint-auto-configure, mr-sync, hierarchical-errors)
- `linuxOnlyOverlays` — NixOS only (openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer)
- `disableTestsOverlay` — disables flaky tests for valkey, aiocache
- `pythonTestOverlay` — NixOS-specific Python test overrides

**Rule:** Never override `vendorHash` from outside a package. Each repo owns its own hash.

### Wrapped Packages (Vimjoyer Pattern)

Niri is wrapped using the `wrapper-modules` pattern to bake configuration into the package:

```nix
# Config function (platforms/nixos/programs/niri-wrapped.nix)
{ pkgs, lib }:
{
  binds = {
    "Mod+Q".close-window = null;        # null for actions
    "Mod+Return".spawn = ["kitty"];      # list for spawn
    "Mod+D".spawn-sh = "rofi -show drun"; # string for shell commands
  };
}
```

**Limitation:** `lib.mkMerge` does not work with flake-parts modules.

### Niri Session Manager (`niri-session-manager` flake input)

Automatic window save/restore for the NixOS (evo-x2) machine via [niri-session-manager](https://github.com/MTeaHead/niri-session-manager) (Rust).

**How it works:**
- Periodic save (configurable interval, default 15min) via `niri_ipc` async IPC
- Automatic restore on startup — spawns apps on their saved workspaces
- Backup rotation with configurable retention
- App ID → command mapping via TOML config (`$XDG_CONFIG_HOME/niri-session-manager/config.toml`)
- Single-instance dedup and skip-apps support
- Retry logic with configurable attempts/delay

**Storage:**
- Session: `$XDG_DATA_HOME/niri-session-manager/session.json`
- Backups: `$XDG_DATA_HOME/niri-session-manager/session-{timestamp}.bak`
- Config: `$XDG_CONFIG_HOME/niri-session-manager/config.toml`

**Enabled in:** `platforms/nixos/system/configuration.nix` (`services.niri-session-manager.enable = true`)

**TOML config:** Managed declaratively via Home Manager in `platforms/nixos/users/home.nix` (`xdg.configFile."niri-session-manager/config.toml"`). Contains `single_instance_apps` (helium, firefox, signal) and `app_mappings` (signal → signal-desktop).

**Known limitation:** Does not restore terminal child processes (e.g. kitty running `btop`/`nvim`) or CWD. See `docs/niri-session-migration.md` for context and upstream issue tracking.

**Commands:**
```bash
just session-status       # Show session manager status + session file
just session-restore      # Restart session manager (triggers restore)
```

### Wallpaper Self-Healing (`scripts/wallpaper-set.sh`)

Automatic wallpaper management with daemon crash recovery:

**Source files:**
- `scripts/wallpaper-set.sh` — wallpaper setter (random/restore modes, daemon wait loop)
- `platforms/nixos/programs/niri-wrapped.nix` — awww-daemon + awww-wallpaper systemd services

**Self-healing architecture:**
- `awww-daemon`: `Restart=always` — systemd auto-restarts after BrokenPipe crash (upstream awww 0.12.0 bug)
- `awww-wallpaper`: `PartOf=["awww-daemon.service"]` — **automatically restarted by systemd when daemon restarts** (no bash supervisor loop)
- On daemon crash recovery: uses `awww restore` to restore last displayed image (preserves user choice)
- On first boot / `Mod+W`: picks random wallpaper from `~/.local/share/wallpapers/`
- Wallpaper script waits up to 60s for daemon socket before setting

**Do NOT use `BindsTo`** — it kills the wallpaper service when the daemon crashes, preventing recovery. `PartOf` is correct: it propagates restarts without killing. This was a bug introduced in `029a911` that caused permanent wallpaper loss on daemon crash.

### Niri DRM Healthcheck & GPU Recovery

Automatic detection and recovery from GPU driver corruption that leaves niri in a zombie state (alive but unable to render).

**DRM Healthcheck (`scripts/niri-drm-healthcheck.sh`):**
- User timer fires every 60s (via `systemd.user.timers.niri-drm-healthcheck`)
- Counts DRM errors (`Permission denied` / `DeviceMissing`) in niri's journal from the last 30s
- Uses a **consecutive failure counter** (state file at `/var/lib/niri-drm-healthcheck/state`)
- Only triggers `gpu-recovery.service` after 3+ consecutive failing checks (prevents false positives)
- Auto-resets counter when niri is not running or errors clear

**GPU Recovery (`scripts/gpu-recovery.sh`):**
- System service with `OOMScoreAdjust=-1000` (OOM-protected)
- Unbinds amdgpu from PCI device `0000:c5:00.0`, waits 2s, rebinds
- Waits up to 30s for GPU to reappear
- Starts niri and verifies DRM health for 5s
- **Auto-reboots** on any unrecoverable failure (unbind fail, rebind fail, GPU timeout, persistent DRM errors)
- No manual intervention needed — the system self-heals or reboots

**Niri Health Metrics (`niri-config.nix`):**
- System timer fires every 30s, writes to node_exporter textfile collector
- Exposes: `niri_running` (0/1), `niri_restarts_10m` (count), `niri_drm_errors_30s` (count)
- Gatus checks `niri_running 1` — alerts if compositor is down
- SigNoz receives all metrics via OTel prometheus scraper

**Key files:**
- `scripts/niri-drm-healthcheck.sh` — consecutive-error detection
- `scripts/niri-health.sh` — standalone health check script
- `scripts/gpu-recovery.sh` — unbind/rebind + auto-reboot
- `modules/nixos/services/niri-config.nix` — timers, services, and metrics

### Crush AI Config Deployment

Crush config (`~/.config/crush/`) is a flake input deployed via Home Manager on both platforms:

```nix
# flake.nix input (SSH URL for private repo)
crush-config.url = "git+ssh://git@github.com/LarsArtmann/crush-config?ref=master";

# Both home.nix files
home.file.".config/crush".source = crush-config;
```

To update: `just update && just switch` (fetches latest crush-config from GitHub).

### SigNoz Observability Pipeline

SigNoz is the sole observability platform (replaces Prometheus + Grafana). Full stack in `modules/nixos/services/signoz.nix`.

**Data pipeline:**
- **node_exporter** (port 9100) → system metrics (CPU, RAM, disk, network, pressure)
- **amdgpu-metrics** → GPU VRAM/busy/temp via node_exporter textfile collector (`/var/lib/prometheus-node-exporter/textfile_collectors/amdgpu.prom`, every 30s)
- **niri-health-metrics** → compositor running/restarts/DRM errors via textfile collector (`niri.prom`, every 30s)
- **cAdvisor** (port 9110) → Docker container metrics
- **Caddy** (port 2019) → HTTP request rates, latencies, errors
- **Authelia** (port 9959) → SSO health metrics
- **journald receiver** → service logs from signoz, caddy, immich, gitea, docker, postgresql, authelia
- **OTLP receiver** → traces/metrics/logs from OTel-instrumented apps (ports 4317/4318)

**SigNoz OTel Collector** scrapes all Prometheus exporters via `prometheus` receiver, collects journald logs, and exports everything to ClickHouse.

**Components (all enabled by default):**
| Component | Port | Purpose |
|-----------|------|---------|
| Query Service | 8080 | Web UI + API (`signoz.home.lan`) |
| OTel Collector | 4317/4318 | OTLP ingest + Prometheus scraping + journald |
| ClickHouse | 9000 | Metrics/traces/logs storage |
| node_exporter | 9100 | System metrics |
| cAdvisor | 9110 | Container metrics |

**Configurable via `services.signoz.components`:**
- `queryService` — SigNoz server (default: enabled)
- `otelCollector` — OTel collector + scrapers (default: enabled)
- `clickhouse` — managed ClickHouse (default: enabled)
- `nodeExporter` — node_exporter (default: enabled)
- `cadvisor` — container metrics (default: enabled)

### Gatus Health Check Monitor

Self-contained flake-parts module (`modules/nixos/services/gatus-config.nix`) wrapping the **nixpkgs `services.gatus` module**. Monitors 17 endpoints across all services with SQLite storage.

| Component | Port | Purpose |
|-----------|------|---------|
| Gatus | 8083 | Health check dashboard (`status.home.lan`) |

**Module:** `modules/nixos/services/gatus-config.nix` (flake-parts)
**Enabled via:** `services.gatus-config.enable = true` in configuration.nix
**Virtual host:** `status.home.lan` via Caddy (forward auth protected)
**Storage:** SQLite at `/var/lib/gatus/gatus.db`
**Systemd hardening:** `harden{}` + `serviceDefaults{}` in module
**All endpoints use `http://localhost`** — no TLS issues with self-signed certs

**Monitored endpoints:**
| Group | Endpoints |
|-------|-----------|
| Infrastructure | Caddy (metrics), Authelia, Homepage, DNS Resolver, DNS Blocker |
| Development | Gitea |
| Media | Immich |
| Monitoring | SigNoz, Manifest, Node Exporter, cAdvisor, GPU VRAM Metrics, Root Disk Space, Niri Compositor |
| Productivity | TaskChampion, Twenty CRM, OpenSEO |
| AI | Ollama, ComfyUI, Whisper ASR, LiveKit |

### NixOS DNS Blocker

Custom DNS blocking stack: Unbound (resolver) + dnsblockd (Go block page server).
- 25 blocklists, 2.5M+ domains blocked
- Upstream: Quad9 (DNS-over-TLS) + Cloudflare fallback
- Local `.home.lan` DNS records for all services
- Blocklist source: `platforms/nixos/programs/dnsblockd/`
- **CA cert trusted system-wide** via `security.pki.certificates` in `dns-blocker-config.nix` — the dnsblockd CA is embedded as a string (public cert, not a secret) so all services and tools trust `*.home.lan` TLS certificates

### Network Configuration (`platforms/nixos/system/local-network.nix`)

Shared IP addresses defined as `networking.local` module options:
- `networking.local.lanIP` (default: 192.168.1.150) — evo-x2 LAN IP
- `networking.local.gateway` (default: 192.168.1.1) — default gateway
- `networking.local.subnet` (default: 192.168.1.0/24) — LAN subnet
- `networking.local.blockIP` (default: 192.168.1.200) — DNS block page IP
- `networking.local.virtualIP` (default: 192.168.1.53) — VRRP virtual IP
- `networking.local.piIP` (default: 192.168.1.151) — Pi 3 backup DNS IP

Both `evo-x2` and `rpi3-dns` import this module. Changing the subnet only requires updating `local-network.nix` defaults.

### DNS Failover Cluster

High-availability DNS via Keepalived VRRP (`modules/nixos/services/dns-failover.nix`).
- Two-node cluster: evo-x2 (primary, priority 100) + Raspberry Pi 3 (backup, priority 50)
- Virtual IP shared between nodes — LAN clients point to VIP, not individual IPs
- Health check: tracks `unbound` process — if unbound dies, node loses VIP
- VRRP garp refresh every 30s for rapid failover detection
- Module options: `services.dns-failover.{enable, virtualIP, interface, priority, routerID, subnetPrefix, authPassword}`
- Pi 3 image built via `nixosConfigurations.rpi3-dns` in flake.nix
- **Status**: Planned — Pi 3 hardware not yet provisioned

### Centralized AI Model Storage (`modules/nixos/services/ai-models.nix`)

Unified directory structure for ALL AI models and tool data on NixOS (evo-x2).

**Directory tree (`/data/ai/`):**
```
/data/ai/
├── models/
│   ├── ollama/         → Ollama service home + model blobs
│   ├── gguf/           → LLaMA.cpp standalone models
│   ├── whisper/        → Whisper ASR models
│   ├── comfyui/        → ComfyUI checkpoints/Loras
│   ├── jan/            → Jan AI data (symlinked from ~/.config/Jan/data)
│   ├── vision/         → Vision models (CLIP, etc)
│   ├── image/          → Image generation models
│   ├── embeddings/     → Embedding models
│   └── tts/            → Text-to-speech models
├── cache/
│   └── huggingface/    → HuggingFace Hub + Transformers cache
└── workspaces/
    └── unsloth/        → Unsloth Studio venv + workspace
```

**How it works:**
- `services.ai-models.enable = true` creates all directories via `systemd.tmpfiles.rules`
- `services.ai-models.paths` attrset provides derived paths for all modules to reference
- Environment variables (`OLLAMA_MODELS`, `HF_HOME`, `LLAMA_MODEL_PATH`, etc.) are set system-wide
- All AI services (Ollama, Whisper, ComfyUI, Unsloth) reference `config.services.ai-models.paths.*`
- Jan AI data folder is symlinked via Home Manager activation (`~/.config/Jan/data` → `/data/ai/models/jan`)

**Module options (`services.ai-models`):**
| Option | Default | Description |
|--------|---------|-------------|
| `enable` | false | Enable centralized AI storage |
| `baseDir` | "/data/ai" | Root directory for all AI data |
| `user` | "lars" | File owner |
| `group` | "users" | File group |
| `paths` | (derived) | Attrset of all tool-specific paths |

**Migration:**
```bash
just ai-migrate    # Move legacy /data/{models,cache,unsloth} → /data/ai/
just ai-status     # Show current storage status
```

**Migration MUST happen BEFORE `just switch`** if you have existing models at `/data/models/`.

**Key files:**
- Module: `modules/nixos/services/ai-models.nix`
- Enabled in: `platforms/nixos/system/configuration.nix`
- Jan symlink: `platforms/nixos/users/home.nix` (home.activation)
- Refactored consumers: `ai-stack.nix`, `voice-agents.nix`, `comfyui.nix`

### Taskwarrior + TaskChampion Sync

Task management synced across NixOS, macOS, and Android via TaskChampion sync server.
- Server: `services.taskchampion-sync-server` on NixOS (port 10222, behind Caddy at `tasks.home.lan`)
- Client: Taskwarrior 3 via Home Manager (`platforms/common/programs/taskwarrior.nix`)
- Android: TaskStrider (Play Store, supports TaskChampion sync)
- Sync URL: `https://tasks.home.lan`
- No forward auth — TaskChampion uses client ID allowlisting + client-side encryption
- **Zero manual setup**: client IDs derived deterministically from `username@platform` via SHA-256, encryption secret is a shared deterministic hash. `just switch && task sync` just works.
- Per-device client ID: `sha256("taskchampion-${username}@${system}")` formatted as UUID
- Shared encryption secret: `sha256("taskchampion-sync-encryption-systemnix")` (same on all devices)

AI agent task tracking protocol:
- Tag `+agent` for AI-created/tracked tasks
- UDA `source` identifies the originating agent (e.g., `source:crush`)
- Report: `task report.agent` shows agent tasks
- Quick add: `just task-agent "description"` adds task with `+agent source:crush`
- Backup: `just task-backup` exports all tasks as JSON to `~/backups/taskwarrior/`
- Theme: Catppuccin Mocha colors configured in `platforms/common/programs/taskwarrior.nix`

## Critical Rules & Gotchas

### Must Follow

- **Use `just` commands** — never raw `nixos-rebuild`/`darwin-rebuild` directly
- **Test before applying** — `just test-fast` (syntax) or `just test` (full build)
- **Use `trash` not `rm`** for file deletion
- **Use `git mv` not `mv`** in this repo
- **No OpenZFS on macOS** — causes kernel panics (see ADR-003)
- **2-space indentation** for Nix files
- **Open new terminal** after `just switch` (shell changes need new session)
- **`config.allowBroken = false`** — must stay false in flake.nix
- **Caddy port references** — always use `config.services.<name>.port`, never hardcode in caddy.nix

### Non-Obvious Gotchas

| Issue | Explanation |
|-------|-------------|
| Darwin HM user | Must define `users.users.larsartmann.home` in `platforms/darwin/default.nix` — Home Manager requires it |
| Different relative paths | Darwin home.nix uses `../common/`, NixOS uses `../../common/` due to directory depth |
| Darwin overlays | Darwin uses `sharedOverlays` directly (no Linux-only overlays). perSystem applies the same shared + Linux-only overlays. No Go overlay — uses nixpkgs default. |
| d2 Darwin overlay | d2 unconditionally depends on `libgbm`/`playwright-driver` (Linux-only). A Darwin-only overlay in `sharedOverlays` re-instantiates d2 via `callPackage` with stub packages. Do NOT remove this overlay — d2 will fail to evaluate on Darwin without it. See commit `524be5ab`. |
| NixOS overlays separate | NixOS adds `niri.overlays.niri`, `dnsblockdOverlay`, and Python overrides on top of the shared ones |
| SigNoz built from source | SigNoz is built from source (Go 1.25), not from a pre-built package. Takes significant build time. |
| crush-config doesn't follow nixpkgs | The crush-config input intentionally does NOT follow nixpkgs (no `inputs.nixpkgs.follows`) |
| Theme everywhere | Catppuccin Mocha is the universal theme — all apps, terminals, bars, login screen |
| SSH config is external | SSH configuration comes from `nix-ssh-config` flake input, not defined locally |
| Secrets via sops-nix | Secrets are age-encrypted using the SSH host key. Managed in `modules/nixos/services/sops.nix` |
| BTRFS dual layout | Root uses zstd compression, `/data` uses zstd:3 with async discard. Docker lives on `/data`. |
| Niri BindsTo patched | Upstream niri.service uses `BindsTo=graphical-session.target` — we replace with `Wants=` in `niri-config.nix`. `BindsTo` kills niri when the target stops during `just switch`; `Wants` pulls in the target (activating waybar etc.) without the hard binding. Niri has `OOMScoreAdjust=-1000` (maximum OOM protection). |
| awww-daemon BrokenPipe | Upstream awww 0.12.0 panics on BrokenPipe at `daemon/src/main.rs:712:32` (Wayland disconnect during suspend/output hotplug). `Restart=always` covers it. Never use `BindsTo` for wallpaper services — use `PartOf` for restart propagation. |
| awww-wallpaper ordering cycle | `awww-wallpaper` must NOT have `After=["awww-daemon.service"]` — it creates a cycle: `wallpaper → daemon → graphical-session → wallpaper`. The wallpaper-set script has its own 60s wait loop for the daemon socket, so `After=["graphical-session.target"]` is sufficient. |
| Niri portal config | Niri ships `niri-portals.conf` with `default=gnome;gtk`. Without a GNOME session, the Settings interface times out and `color-scheme=dark` never reaches browsers. Override via `xdg.portal.config.niri.default = ["gtk" "wlr"]`. |
| Unbound do-ip6 | evo-x2 has no global IPv6 (link-local only). Unbound defaults `do-ip6=yes` when kernel IPv6 is enabled, causing it to prefer IPv6 root servers → all queries SERVFAIL. `do-ip6 = false` is set in both `dns-blocker.nix` and `rpi3/default.nix`. Do NOT remove these — any new unbound instance must also set `do-ip6 = false`. |

### lib/ Shared Helpers

Reusable functions in `lib/` — imported directly by relative path:

| File | Purpose | Usage |
|------|---------|-------|
| `lib/systemd.nix` | Security hardening (PrivateTmp, NoNewPrivileges, ProtectSystem, etc.) | `harden = import ../../../lib/systemd.nix {inherit lib;};` then `harden {MemoryMax = "512M";}` |
| `lib/systemd/service-defaults.nix` | Common service defaults (Restart, RestartSec) — returns attrset with `.serviceDefaults` (system, uses mkForce) and `.serviceDefaultsUser` (user services, no mkForce) | `sd = import ../../../lib/systemd/service-defaults.nix lib;` then `sd.serviceDefaults {}` or `sd.serviceDefaultsUser {}` |
| `lib/types.nix` | Reusable NixOS module option constructors (ports, user/group, delays) | `serviceTypes = import ../../../lib/types.nix lib;` then `serviceTypes.systemdServiceIdentity {}` |
| `lib/rocm.nix` | ROCm GPU runtime library lists and env vars | `rocm = import ../../../lib/rocm.nix {inherit pkgs;};` then `rocm.env` / `rocm.makeLdLibraryPath lib` |
| `lib/go-output-submodules.nix` | Generates `require`+`replace` directives for go-output workspace sub-modules | `import ../lib/go-output-submodules.nix go-output-src` in postPatch |

Combining: `serviceConfig = harden {MemoryMax = "1G";} // serviceDefaults {};`

**Adoption status:** All service modules that manage systemd services use `harden {}` from the shared lib. 17 modules use `serviceDefaults {}`. No service should manually inline `PrivateTmp`, `NoNewPrivileges`, etc. — always use the shared helpers. For Home Manager user services, use `serviceDefaultsUser` (no `mkForce`).

**Single import pattern:** All modules use `inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;` — one import replaces three. For user-service modules that need `serviceDefaultsUser`, import the set: `sd = import ../../../lib/default.nix lib;` then call `sd.serviceDefaultsUser {}`.

### Caddy Port References

Caddy reverse-proxy ports are derived from service module options — NOT hardcoded:

| Service | Caddy Reference |
|---------|----------------|
| Authelia | `config.services.authelia-config.port` |
| Immich | `config.services.immich.port` |
| Gitea | `config.services.gitea.settings.server.HTTP_PORT` |
| Homepage | `config.services.homepage.port` |
| PhotoMap | `config.services.photomap.port` |
| SigNoz | `config.services.signoz.settings.queryService.port` |
| Twenty | `config.services.twenty.port` |
| TaskChampion | `config.services.taskchampion-sync-server.port` |
| ComfyUI | `config.services.comfyui.port` |
| Gatus | `config.services.gatus-config.port` (via nixpkgs `settings.web.port`) |
| OpenSEO | `config.services.openseo.port` |

**Rule:** When adding a new service behind caddy, always define a `port` option in the service module and reference it in `caddy.nix`. Never hardcode port numbers in caddy. For nixpkgs modules, use the module's own port option (e.g., `settings.web.port`).

### GPU Compute Headroom for Niri

AI workloads on the iGPU can starve niri (Wayland compositor) of GPU cycles, causing desktop lag. Since AMD APUs lack MPS-style GPU scheduling, headroom is preserved via memory fraction limiting.

**GPU memory budget (73 GiB total):**

| Service | Fraction | Cap | Rationale |
|---------|----------|-----|-----------|
| Ollama (per runner) | 0.45 | ~33 GiB | `OLLAMA_MAX_LOADED_MODELS=1` prevents dual-runner. Leaves 7 GiB for niri |
| Ollama overhead | — | 8 GiB | `OLLAMA_GPU_OVERHEAD=8589934592` reserves headroom for compositor |
| ComfyUI | 0.50 | ~36 GiB | When Ollama (45%) + ComfyUI (50%) both active = 95% |
| gpu-python | 0.95 (configurable) | ~69 GiB | Solo GPU use only; override with `GPU_MEM_FRACTION=0.8` |

**Key design decisions:**
- Fractions are set **per-service**, NOT system-wide. The old system-wide `PYTORCH_CUDA_ALLOC_CONF` session variable was removed — it gave every process a 95% cap, causing Ollama dual-runner OOM (see Incident 2026-05-10 below).
- `OLLAMA_MAX_LOADED_MODELS=1` — **critical defense**: prevents Ollama from loading two model runners simultaneously (the root cause of the dual-runner GPU OOM incident)
- `OLLAMA_GPU_OVERHEAD=8589934592` (8 GiB) — reserves GPU VRAM for niri compositor and other processes
- `OLLAMA_NUM_PARALLEL=2` — reduced from 4 to limit concurrent GPU batches
- `OOMScoreAdjust=500` on Ollama — ensures OOM killer prefers killing Ollama over niri (`-1000`)
- `gpu-python` wrapper: `gpu-python script.py` or `GPU_MEM_FRACTION=0.8 gpu-python script.py` for ad-hoc scripts

**Files:** `ai-stack.nix` (Ollama env + gpu-python wrapper), `comfyui.nix` (ComfyUI alloc conf)

### WatchdogSec / sd_notify Rules

**`WatchdogSec` is ONLY valid for services that implement `sd_notify()` (i.e., `Type = "notify"`).** Setting it on services that don't call `sd_notify()` causes systemd to kill them after the timeout — even though they're running perfectly fine.

**Services that support sd_notify (Type=notify, safe to use WatchdogSec):**
- Caddy (`modules/nixos/services/caddy.nix`)
- Gitea (`modules/nixos/services/gitea.nix`)

**Services that do NOT support sd_notify (NEVER set WatchdogSec):**
- All Python services: Hermes, ComfyUI, Immich ML
- All Node.js services: Homepage, Immich server
- Go services without explicit sd_notify: SigNoz, Authelia, cadvisor, EMEET PIXY
- Rust services without explicit sd_notify: TaskChampion

**Rule:** If a service isn't `Type = "notify"`, do NOT set `WatchdogSec`. The `serviceDefaults` function does NOT include `WatchdogSec` for this reason — pass it explicitly only for sd_notify-capable services.

## Known Issues

| Issue | Workaround | Status |
|-------|-----------|--------|
| Darwin HM user definition | Explicit `users.users.larsartmann` in darwin/default.nix | Workaround applied |
| mkMerge + flake-parts | Use inline config or imports instead of `lib.mkMerge` | Accepted limitation |
| `wire` not in Nixpkgs | Installed via `go install` manually | Accepted |
| AI model migration order | Run `just ai-migrate` BEFORE `just switch` to avoid Ollama seeing empty model dir | Documented |
| Go overlay removed on Darwin | nixpkgs `go_1_26` is already 1.26.1; overlay was invalidating 1094 binary cache derivations | Resolved — removed |
| GPU hang recovery | Hermes anime-comic-pipeline (PyTorch/ROCm) SIGSEGV → GPU driver hang → entire desktop frozen. Defense in depth: `kernel.sysrq=1` (REISUB), `kernel.panic=30`, `softlockup_panic=1`, `hung_task_panic=1`, `watchdogd` (SP5100 TCO), `amdgpu.gpu_recovery=1`. See `boot.nix`. | Resolved |
| Helium "RESTORE TABS" on every launch | Chromium writes `exit_type=Normal` only on clean JS-initiated shutdown; SIGTERM from session stop leaves it as `Crashed`. Fixed with `--restore-last-session --disable-session-crashed-bubble` wrapper flags. | Resolved |
| watchdogd nixpkgs module broken for `device` | NixOS `services.watchdogd.settings.device` generates `device = /dev/watchdog0` but watchdogd v4.1 expects titled section `device /dev/watchdog0 { ... }`. Workaround: omit `device` from settings (default `/dev/watchdog` is the SP5100 TCO). Do NOT set `device` in `settings`. Upstream nixpkgs bug. | Workaround applied |
| watchdogd `reset-reason` section fails | The `file` key in `reset-reason` section also fails to parse (nixpkgs module generates unquoted string paths). Only `timeout`, `interval`, `safe-exit`, and monitor plugins (`meminfo`, `filenr`, `loadavg`) work. | Accepted — no reset tracking |
| Ollama dual-runner GPU OOM | Ollama loaded two model runners simultaneously (gemma4 + second model), each with `per_process_memory_fraction:0.95` = 138 GiB demand on 73 GiB GPU. Caused amdgpu exhaustion → niri SIGABRT → cascading OOM kills (helium, kitty, pipewire, user systemd). Fix: `OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_GPU_OVERHEAD=8GiB`, per-runner fraction 0.45, `OOMScoreAdjust=500` for Ollama / `-1000` for niri. | Resolved — multi-layer GPU defense |
| awww-daemon crash loop | awww-daemon 0.12.0 panics on `unwrap()` when Wayland compositor is down. During niri crash cascade, caused 15 consecutive SIGABRTs at ~70s intervals. Fix: added ExecStartPre Wayland check, tightened StartLimitBurst to 3/300s. | Resolved — controlled failure instead of crash |

| ~130W power ceiling | GMKtec NucBox EVO-X2 firmware enforces PPT at ~130W. No OS override possible: `ryzen_smu` lacks Strix Halo support, RAPL exposes no constraint files, BIOS has no cTDP/platform profile options. `amd_pstate=performance` + `performance` governor ensure max utilization within the ceiling. Future: check GMKtec BIOS updates, wait for `ryzen_smu` Strix Halo support. | Accepted — hardware/firmware limit |

## Essential Commands

Run `just` (or `just --list`) to see all recipes grouped by category. Key commands:

```bash
# Core
just setup              # Initial setup after clone
just switch             # Apply config (detects platform automatically)
just update             # Update flake inputs
just rollback           # Revert to previous generation
just check              # System status, git status, disk usage

# Quality
just test-fast          # Syntax-only validation (fast)
just test               # Full build validation (slow)
just format             # Format with treefmt + alejandra
just health             # Cross-platform health check

# Clean
just clean              # Clean Nix store, caches, temp files, Docker

# Services (NixOS only)
just dns-diagnostics    # Full DNS stack diagnostics
just dns-update         # Update blocklist commits + recompute SRI hashes
just immich-status      # Immich service status + backup count
just immich-backup      # Database backup
just gitea-sync-repos   # Sync GitHub → Gitea
just hermes-status      # Hermes gateway status
just manifest-status    # Manifest LLM router status

# Desktop (NixOS only)
just cam-status         # Camera state (tracking, audio, position)
just cam-privacy        # Toggle privacy mode
just wallpaper-status   # Wallpaper daemon health + images
just session-status     # Niri session manager status
just reload             # Reload niri config (no rebuild)

# Taskwarrior (cross-platform)
just task-list           # Show pending tasks (next report)
just task-add <desc>     # Add a new task
just task-agent <desc>   # Add AI-tracked task (+agent source:crush)
just task-sync           # Sync with TaskChampion server
just task-status         # Show task counts + sync config
just task-setup          # Per-device auto-config info
just task-backup         # Export all tasks as JSON

# AI Models (NixOS only)
just ai-migrate           # Migrate legacy AI data → /data/ai/ (run BEFORE switch)
just ai-status            # Show AI model storage status

# Tools (cross-platform)
just todo-scan             # Extract TODOs (default: mock provider)
just todo-scan-openai DIR  # Extract TODOs with OpenAI
just lint-configure        # Auto-configure golangci-lint

# Disk (NixOS only)
just disk-status         # Disk monitor + filesystem usage
just disk-check          # Trigger manual disk check
just rust-clean          # Rust target/ cleanup
```

### EMEET PIXY Webcam (`emeet-pixyd` flake input)

Custom Go daemon for the EMEET PIXY dual-camera AI webcam with auto-activation:

| Component | Path | Purpose |
|-----------|------|---------|
| Package | `emeet-pixyd` flake input overlay | buildGoModule derivation (no local pkgs/ file) |
| NixOS module | `platforms/nixos/hardware/emeet-pixy.nix` | udev rules, user systemd service |
| NixOS module | `inputs.emeet-pixyd.nixosModules.default` | flake-provided NixOS module |
| Waybar | `platforms/nixos/desktop/waybar.nix` | Camera state indicator |

**Architecture:**
- User-level systemd service (inherits Wayland + pipewire session env)
- Call detection: scans `/proc/*/fd` for any process holding the video device open
- Auto-actions: face tracking + noise cancellation on call start, privacy mode on call end
- Auto-switches PipeWire default source to PIXY on call start
- Desktop notifications via `notify-send` on state changes
- Systemd watchdog (`WatchdogSec=30`) prevents hung daemon
- Structured logging via `slog` (leveled: debug/info/warn/error)
- Waybar click toggles privacy, right-click enables tracking, middle-click centers
- Device auto-detection by USB vendor/product ID (`328f:00c0`), not hardcoded
- Hotplug recovery: re-probes on error, recovers when camera reconnected
- Boot default: privacy mode (camera physically disabled until needed)
- Configurable via `Config` struct (poll interval, debounce count, state dir)
- Type-safe HID commands via `CameraState.HIDByte()` / `AudioMode.HIDByte()` methods
- Socket permissions 0600 (user-only, not world-writable)
- HID state querying via bidirectional hidraw (reads camera's actual tracking/audio/gesture state)
- State sync on startup + `sync` command to reconcile believed state with camera reality

```bash
# Camera commands
just cam-status          # Show camera state
just cam-privacy         # Toggle privacy mode
just cam-track           # Enable face tracking
just cam-reset           # Center camera (pan/tilt/zoom)
just cam-audio           # Cycle audio: nc → live → org → nc
just cam-audio <mode>    # Set audio: nc, live, org
just cam-sync           # Sync daemon state with camera
just cam-restart         # Restart daemon (user service)
just cam-logs            # View daemon logs

# Direct daemon commands (either emeet-pixyd or emeet-pixy works)
emeet-pixy status           # Full status
emeet-pixy toggle-privacy   # Toggle privacy
emeet-pixy probe            # Re-detect device
emeet-pixy sync             # Sync state from camera
emeet-pixy audio            # Cycle audio mode
```

### OpenSEO — Self-Hosted SEO Suite (`modules/nixos/services/openseo.nix`)

Declarative NixOS module for [OpenSEO](https://github.com/every-app/open-seo) — self-hosted alternative to Ahrefs/Semrush.

| Component | Path | Purpose |
|-----------|------|---------|
| NixOS module | `modules/nixos/services/openseo.nix` | flake-parts module — docker-compose systemd wrapper |
| Secrets | `platforms/nixos/secrets/openseo.yaml` | sops-encrypted DataForSEO API key |
| Virtual host | `seo.home.lan` | Caddy reverse proxy (forward auth protected) |

**Architecture:**
- Docker container via inline `docker-compose.yml` (follows `manifest.nix` pattern)
- Image: `ghcr.io/every-app/open-seo:latest`
- SQLite data at `/var/lib/openseo/data` (Docker volume `openseo_data`)
- Auth: `local_noauth` — protected behind Authelia forward auth via Caddy
- DataForSEO API key via sops template → env file at service start

**Module options (`services.openseo`):**

| Option | Default | Description |
|--------|---------|-------------|
| `enable` | false | Enable OpenSEO service |
| `port` | 3001 | HTTP port |
| `imageTag` | "latest" | Docker image tag |

**Sops secrets (`openseo.yaml`):**
- `dataforseo_api_key` — DataForSEO API key (base64 `login:password`)

**Cost model:** Pay-as-you-go via DataForSEO. Light use $2–5/mo, moderate $10–20/mo.

```bash
just openseo-status    # Show service status
just openseo-restart   # Restart service
just openseo-logs      # View logs
```

---

### Hermes AI Agent Gateway (`modules/nixos/services/hermes.nix`)

Declarative NixOS module for the Hermes AI agent gateway (Discord bot, cron scheduler, messaging).

| Component | Path | Purpose |
|-----------|------|---------|
| NixOS module | `modules/nixos/services/hermes.nix` | flake-parts module — system service, tmpfiles, user/group |
| Secrets | `platforms/nixos/secrets/hermes.yaml` | sops-encrypted API keys |
| Config | `/home/hermes/config.yaml` | Hermes runtime config (NOT in repo — Hermes writes at runtime) |
| Env | `/home/hermes/.env` | Merged from sops template at service start (secrets + non-secret env) |

**Architecture:**
- Installed via flake input `hermes-agent` (pinned to **v2026.4.30** in `flake.lock`)
- System-level systemd service (`systemd.services.hermes`) targeting `multi-user.target` — starts at boot without login
- Dedicated system user/group (`hermes`/`hermes`) with state at `/home/hermes`
- `binutils` in service PATH for `ctypes.util.find_library` opus resolution on NixOS
- `GATEWAY_ALLOW_ALL_USERS=true` — all Discord users can interact with the bot
- Auto-migrates state from `/home/lars/.hermes` or `/var/lib/hermes` on first start
- Secrets decrypted by sops-nix template → merged into `.env` by `mergeEnvScript` (ExecStartPre) → Hermes reads `.env` at runtime via `load_hermes_dotenv`
- `libopus` installed system-wide for Discord voice support (in `configuration.nix`)
- `key_env` references in `config.yaml` read API keys from `.env` instead of inline plaintext

**npmDeps hash patching:**
Upstream hermes-agent has a stale `npmDepsHash` in `nix/tui.nix`. The local overlay (`hermesPkg` in hermes.nix) intercepts `callPackage` for `tui.nix` and replaces the npmDeps with a corrected hash. On hermes upgrade: check if upstream fixed their hash (remove `fixedHash` and test build). If still stale, update `fixedHash` per the comment in hermes.nix.

**SQLite auto-recovery:**
The `ExecStartPre` migrate script runs `PRAGMA integrity_check` on `state.db`. If malformed, it renames the DB with a `.malformed-<timestamp>` suffix and removes WAL/SHM sidecars, letting Hermes create a fresh DB on startup.

**State directories (tmpfiles + activation):**
`/home/hermes/` with subdirs: `sessions`, `skills`, `memories`, `cron`, `cache`, `logs/curator`, `workspace`. All created with 2770 permissions owned by `hermes:hermes`.

**Module options (`services.hermes`):**
| Option | Default | Description |
|--------|---------|-------------|
| `enable` | false | Enable the gateway |
| `user` | "hermes" | System user |
| `group` | "hermes" | System group |
| `stateDir` | "/home/hermes" | State directory |
| `restartSec` | "5" | Restart delay after failure |
| `timeoutStopSec` | "120" | Graceful shutdown timeout |

**Sops secrets (`hermes.yaml`):**
- `hermes_discord_bot_token` — Discord bot token
- `hermes_glm_api_key` — Z.AI/GLM API key
- `hermes_minimax_api_key` — MiniMax API key
- `hermes_xiaomi_api_key` — Xiaomi MiMo API key
- `hermes_fal_key` — fal.ai image generation key
- `hermes_firecrawl_api_key` — Firecrawl web scraping key

```bash
# Hermes commands
just hermes-status        # Show gateway status
just hermes-restart       # Restart gateway service
just hermes-logs          # View gateway logs
hermes gateway status     # Check gateway state
hermes model              # Change default model
hermes cron list          # List cron jobs
```

## Flake Inputs

| Input | What | Follows nixpkgs? |
|-------|------|-------------------|
| `nixpkgs` | Package collection (unstable) | — |
| `nix-darwin` | macOS system management | Yes |
| `home-manager` | User configuration | Yes |
| `flake-parts` | Modular flake architecture | No |
| `niri` | Wayland compositor | Yes |
| `nix-homebrew` | Homebrew management (macOS) | No |
| `sops-nix` | Secrets with age | Yes |
| `nix-amd-npu` | AMD XDNA NPU driver | Yes |
| `nix-ssh-config` | SSH configuration | Yes (+ HM) |
| `crush-config` | AI assistant config | No |
| `hermes-agent` | AI agent gateway (Discord, cron) | Yes |
| `nix-colors` | Color schemes | No |
| `silent-sddm` | SDDM theme | Yes |
| `nur` | Nix User Repository | Yes |
| `helium` | Helium browser | Yes |
| `otel-tui` | OpenTelemetry TUI viewer | Yes |
| `signoz-src` | SigNoz source (flake=false) | — |
| `signoz-collector-src` | SigNoz collector source (flake=false) | — |
| `todo-list-ai` | AI-powered TODO extraction CLI | Yes |
| `library-policy` | Banned/vulnerable library detector for Go projects | Yes |
| `golangci-lint-auto-configure` | golangci-lint auto-configurator | Yes |
| `hierarchical-errors` | Error handling pattern analyzer | Yes |
| `homebrew-bundle` | Homebrew taps (flake=false) | — |
| `homebrew-cask` | Homebrew cask taps (flake=false) | — |
| `monitor365-src` | Device monitoring agent source (flake=false) | — |
| `mr-sync` | ~/.mrconfig GitHub sync CLI | Yes |
| `wallpapers-src` | Wallpaper collection (flake=false) | — |
| `file-and-image-renamer-src` | AI screenshot renamer source (flake=false) | — |
| `cmdguard-src` | Go command guard library (flake=false) | — |
| `go-output-src` | Go output library (flake=false) | — |
| `nixos-hardware` | Hardware profiles (RPi, etc.) | No |
| `emeet-pixyd` | EMEET PIXY webcam daemon | Yes |
| `niri-session-manager` | Niri window save/restore (Rust) | Yes |
| `treefmt-full-flake` | Treefmt formatter | Yes |

**All LarsArtmann private repos use `git+ssh://` URLs.** No `path:` inputs remain.
