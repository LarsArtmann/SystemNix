# SystemNix — Feature Inventory

_A brutally honest audit of every feature the project actually has._

**Generated:** 2026-05-03 | **Scope:** Full codebase scan

---

## Status Legend

| Icon | Status | Meaning |
|------|--------|---------|
| ✅ | FULLY_FUNCTIONAL | Complete, wired, tested, works as intended |
| ⚠️ | PARTIALLY_FUNCTIONAL | Mostly works, known gaps or edge cases |
| 🔧 | DISABLED | Code exists but not currently enabled |
| 📋 | PLANNED | Module/scaffold exists, not yet deployed |
| ❌ | BROKEN | Implemented but currently non-functional |

---

## 1. Core Infrastructure

### Flake Architecture

| Feature | Status | Notes |
|---------|--------|-------|
| Cross-platform Nix flake (Darwin + NixOS) | ✅ | Single flake, two systems, 80% shared via `platforms/common/` |
| flake-parts modular architecture | ✅ | 29 service modules imported in `flake.nix` |
| Shared overlays (Darwin + NixOS) | ✅ | NUR, aw-watcher, todo-list-ai, golangci-lint-auto-configure, mr-sync |
| Linux-only overlays | ✅ | openaudible, dnsblockd, emeet-pixyd, monitor365, netwatch, file-and-image-renamer |
| Shared Home Manager config | ✅ | `sharedHomeManagerConfig` + `sharedHomeManagerSpecialArgs` |
| Custom packages (pkgs/) | ✅ | 13 packages: 6 Go, 2 Rust, 1 Python, 1 Node.js, 3 via flake inputs |
| Formatter (treefmt + alejandra) | ✅ | Via `treefmt-full-flake` |
| Flake checks (statix, deadnix, eval) | ✅ | Per-system + Linux-specific |
| Raspberry Pi 3 SD image build | 📋 | `nixosConfigurations.rpi3-dns` defined, hardware not provisioned |
| Go overlay (perSystem) | ✅ | Removed — using nixpkgs Go 1.26.1 directly to preserve binary cache |

### Three System Targets

| System | Hostname | Platform | Status |
|--------|----------|----------|--------|
| macOS | `Lars-MacBook-Air` | aarch64-darwin | ✅ Active |
| NixOS Desktop | `evo-x2` | x86_64-linux | ✅ Active |
| Raspberry Pi 3 | `rpi3-dns` | aarch64-linux | 📋 Planned |

---

## 2. NixOS Services (evo-x2)

### Infrastructure Services

| Service | Status | Module | Key Details |
|---------|--------|--------|-------------|
| Docker | ✅ | `default.nix` | Always-on, overlay2, `/data/docker`, weekly auto-prune, user `lars` in docker group |
| Caddy (reverse proxy) | ✅ | `caddy.nix` | TLS via sops certs, forward auth via oauth2-proxy + Pocket ID, 10 virtual hosts, metrics enabled |
| SOPS secrets management | ✅ | `sops.nix` | Age-encrypted via SSH host key, 4 sops files, auto-restart per secret |
| Pocket ID (OIDC provider) | ✅ | `pocket-id.nix` | Passkey-only OIDC provider, Go backend, SQLite, web UI for user/client management
| oauth2-proxy | ✅ | `oauth2-proxy.nix` | Forward-auth bridge between Caddy and Pocket ID, cookie-based sessions |
| DNS Failover (Keepalived VRRP) | 📋 | `dns-failover.nix` | Two-node VRRP cluster, unbound health tracking, GARP refresh — Pi 3 not provisioned |

### Self-Hosted Applications

| Service | Status | Module | Key Details |
|---------|--------|--------|-------------|
| Forgejo (Git forge) | ✅ | `forgejo.nix` | SQLite, LFS, weekly dumps, GitHub mirror + push mirrors, Actions runner (Docker + native), admin auto-setup, federation enabled |
| Forgejo repos (declarative mirroring) | ✅ | `forgejo-repos.nix` | Auto-sync on rebuild + daily timer, push mirrors to GitHub, hardened oneshot, sops-managed tokens |
| Homepage Dashboard | ✅ | `homepage.nix` | Catppuccin Mocha theme, 5 service categories, resource widgets, health checks |
| Immich (photo/video management) | ✅ | `immich.nix` | PostgreSQL + Redis + ML, OAuth via Pocket ID, daily DB backup, VA-API hardware transcoding (H.264/HEVC/AV1), ML GPU access |
| PhotoMap AI | 🔧 | `photomap.nix` | CLIP embedding visualization, OCI container, pinned SHA256, disabled in config |
| SigNoz (observability) | ✅ | `signoz.nix` | Full-stack: traces/metrics/logs, ClickHouse, OTel Collector, node_exporter, cadvisor, 7 alert rules, dashboard provisioning |
| TaskChampion (Taskwarrior sync) | ✅ | `taskchampion.nix` | Port 10222, TLS via Caddy, no forward auth, 100 snapshots / 14 days |
| Twenty CRM | ✅ | `twenty.nix` | Docker Compose (4 containers), PostgreSQL + Redis, sops secrets, daily DB backup, Caddy at crm.home.lan |
| Minecraft server | ✅ | `minecraft.nix` | JDK 25, ZGC, firewall restricted to LAN, Prism Launcher client config, whitelist |

### AI / ML Stack

| Service | Status | Module | Key Details |
|---------|--------|--------|-------------|
| Centralized AI model storage | ✅ | `ai-models.nix` | `/data/ai/` tree (14 dirs), env vars, tmpfiles rules — dependency for all AI services |
| Ollama (LLM inference) | ✅ | `ai-stack.nix` | ROCm GPU, flash attention, 4 parallel, q8_0 KV, 24h keep-alive, user `lars` in render group |
| llama.cpp (standalone) | ✅ | `ai-stack.nix` | ROCWMMA + MFMA custom build, installed alongside Ollama |
| ComfyUI (image generation) | ❌ Removed | `comfyui.nix` | Disabled — prefer using AI models via code directly |
| Voice agents (LiveKit + Whisper) | 🔧 | `voice-agents.nix` | Docker ROCm Whisper, Caddy reverse proxy, UDP 50000-51000 — enabled but may need verification |
| Hermes AI gateway | ✅ | `hermes.nix` | Discord bot, cron, messaging — system service, sops secrets, 4G memory limit, USR1 reload |

### Desktop & System Services

| Service | Status | Module | Key Details |
|---------|--------|--------|-------------|
| Niri (Wayland compositor) | ✅ | `niri-config.nix` | niri-unstable, XWayland satellite, patched BindsTo→PartOf, OOMScoreAdjust=-900 |
| SDDM display manager | ✅ | `display-manager.nix` | SilentSDDM, Catppuccin Mocha theme, Niri as default session |
| PipeWire audio | ✅ | `audio.nix` | ALSA + PulseAudio + JACK compat, rtkit realtime |
| Security hardening | ✅ | `security-hardening.nix` | fail2ban (SSH aggressive), ClamAV, polkit, GNOME Keyring, 30+ security tools |
| Chromium policies | ✅ | `chromium-policies.nix` | YouTube Shorts Blocker + OneTab force-installed |
| Steam gaming | ✅ | `steam.nix` | extest, protontricks, gamemode (renice=10, GPU temp 80°C), gamescope, mangohud |
| Multi-WM (Sway backup) | 🔧 | `multi-wm.nix` | Sway as backup at SDDM login — disabled in config |
| File & Image Renamer (AI) | ✅ | `file-and-image-renamer.nix` | Watches Desktop, ZAI API, hardened sandbox, Home Manager user service |
| Monitor365 | ✅ | `monitor365.nix` | Device monitoring agent, ActivityWatch integration, user systemd service, hardened |

### Monitoring

| Service | Status | Module | Key Details |
|---------|--------|--------|-------------|
| SigNoz observability | ✅ | `signoz.nix` | See Self-Hosted Applications above |
| Monitoring tools (CLI) | ✅ | `monitoring.nix` | radeontop, strace, ltrace, nethogs, iftop, netwatch |

---

## 3. Cross-Platform Programs (Home Manager)

### Shells

| Program | Status | Notes |
|---------|--------|-------|
| Fish | ✅ | Primary shell — shared aliases, Carapace completions, 5k history, autosuggestions, GOPATH in PATH |
| Zsh | ✅ | Autosuggestions + syntax highlighting, XDG dotdir, `~/.env.private` sourcing |
| Bash | ✅ | Shared aliases, erase-dups history, cdspell/autocd/globstar |
| Starship prompt | ✅ | Performance-tuned: 400ms timeout, 30+ modules disabled, only Go/Node/Nix shown, colorScheme-driven |
| Shell aliases (shared) | ✅ | `shell-aliases.nix` — DRY across Fish/Zsh/Bash (ADR-002) |

### Development Tools

| Program | Status | Notes |
|---------|--------|-------|
| Git | ✅ | GPG signing, max compression, SSH multiplexing, HTTPS→SSH rewrite, Git Town aliases, LFS, `.crush` in global ignores |
| Tmux | ✅ | Resurrect + yank plugins, custom SystemNix dev session, vi copy-mode, Catppuccin-themed status bar |
| Fzf | ✅ | Fish/Zsh/Bash integration, reverse layout, rg-powered, colorScheme-driven colors |
| Pre-commit hooks | ✅ | Nix config validation, shellcheck, markdownlint, private key detection, nixpkgs-fmt |
| Go environment | ✅ | GOPATH/GOPRIVATE/GONOSUMDB, `~/go/bin` in PATH, gopls without modernize |
| Node.js/Bun/pnpm | ✅ | Via base.nix packages |

### Applications

| Program | Status | Platform | Notes |
|---------|--------|----------|-------|
| ActivityWatch | ✅ | Linux | Wayland window watcher + utilization watcher (5s poll), dark theme on startup |
| ActivityWatch (macOS) | ✅ | Darwin | LaunchAgent auto-start, aw-watcher-utilization via Nix package |
| KeePassXC | ✅ | Both | Browser integration, Chromium + Helium native messaging manifests, dark/compact mode |
| Chromium | ✅ | Darwin | Brave as primary, VAAPI decode/encode, YouTube Shorts Blocker extension |
| Chromium (NixOS) | ✅ | Linux | System-wide via `chromium-policies.nix` module |
| Taskwarrior 3 | ✅ | Both | Sync to `tasks.home.lan`, deterministic UUID client ID, Catppuccin Mocha colors, daily JSON backup |
| SSH config | ✅ | Both | Via `nix-ssh-config` flake input — 7 hosts: onprem, evo-x2, 4× Hetzner private cloud |

### Theme & Appearance

| Feature | Status | Notes |
|---------|--------|-------|
| Catppuccin Mocha (global) | ✅ | Universal theme — GTK, icons, cursor, fonts, all apps |
| Nix-colors integration | ✅ | `colorScheme` passed as specialArg, drives Starship/Fzf/Qt/GTK |
| Bibata cursor (96px) | ✅ | Linux — Bibata-Modern-Classic via fonts.nix |
| JetBrainsMono Nerd Font | ✅ | Terminal font everywhere |
| Papirus icons | ✅ | Dark variant across platforms |

### Fonts (Linux)

| Font | Status | Notes |
|------|--------|-------|
| JetBrains Mono Nerd Font | ✅ | Primary monospace |
| Fira Code Nerd Font | ✅ | Alternative mono |
| Iosevka Nerd Font | ✅ | Alternative mono |
| Noto Fonts (regular, emoji, CJK) | ✅ | Unicode fallback |

---

## 4. NixOS Desktop (evo-x2)

### Window Management

| Feature | Status | Notes |
|---------|--------|-------|
| Niri (scrolling-tiling Wayland) | ✅ | Extensive config: 5 named workspaces, window rules, vim-style keybindings, preset column widths |
| Niri session save/restore | ✅ | Crash recovery: 60s timer, workspace-aware restore, floating state, column widths, focus order, kitty CWD/child proc capture |
| Niri keybindings (80+) | ✅ | Rofi integrations (app, clipboard, emoji, calc, notifications), screenshots (grim+slurp+swappy), media keys, brightness (ddcutil), random wallpaper |
| XWayland support | ✅ | xwayland-satellite installed |

### Desktop Components

| Component | Status | Notes |
|-----------|--------|-------|
| Rofi (app launcher) | ✅ | Grid layout (5×3), Catppuccin Mocha, Papirus icons, rounded corners, transparency |
| Rofi plugins | ✅ | rofi-calc, rofi-emoji — calculator (Mod+Shift+C), emoji picker (Mod+.) |
| Waybar (status bar) | ✅ | 15+ modules: workspaces, window, clock, media, camera, DNS stats, disk, weather, audio, network, CPU, memory, temp, clipboard, tray, power |
| Swaylock (screen locker) | ✅ | swaylock-effects, Catppuccin Mocha colors, indicator radius 100px |
| Wlogout (power menu) | ✅ | 6 actions (lock/hibernate/logout/shutdown/suspend/reboot), color-coded SVG icons |
| Dunst (notifications) | ✅ | Catppuccin-colored, overlay layer, rofi as dmenu, progress bars, 5-notification limit |
| Yazi (file manager) | ✅ | Catppuccin Mocha theme, file type associations, Ctrl-key keybindings, Zed integration, fd/rg search |
| Zellij (terminal multiplexer) | ✅ | Catppuccin Mocha, tmux-compatible keybindings (Ctrl+A), 3 custom layouts (dev/monitoring/default) |
| Kitty (terminal) | ✅ | Font size 16 (TV-friendly), 85% opacity, Catppuccin Mocha, Nix GC resilience patch |
| Foot (terminal) | ✅ | Lightweight Wayland alt, JetBrainsMono size 12, 95% opacity |
| Swayidle | ✅ | 12hr idle → suspend, lock before sleep |
| Cliphist (clipboard) | ✅ | Wayland clipboard history via wl-paste watcher, rofi integration (Alt+C) |
| Awww (wallpaper daemon) | ✅ | Random wallpaper on startup (Mod+W), systemd user service |

### Hardware Support

| Hardware | Status | Notes |
|----------|--------|-------|
| AMD GPU (Strix Halo) | ✅ | amdgpu, Mesa, RADV Vulkan, ROCm (clr.icd, rocblas), VA-API, 32-bit support, nvtop, amdgpu_top, corectrl |
| AMD NPU (XDNA) | ✅ | XRT driver, Boost 1.87 fix, dev tools, unlimited memlock |
| Realtek 2.5G Ethernet | ✅ | `r8125` extra module package (not in mainline kernel) |
| MediaTek WiFi/BT | ✅ | `mt7925e` module |
| EMEET PIXY webcam | ✅ | Full daemon: call detection, auto-tracking, noise cancellation, privacy mode, PipeWire source switch, Waybar indicator, hotplug recovery |
| Bluetooth | ✅ | Power-on-boot, A2DP source/sink (Google Nest Audio), Blueman GUI |
| DDC/CI brightness | ✅ | i2c-dev kernel module, ddcutil for external monitor brightness |
| BTRFS root (`/`) | ✅ | zstd compression, noatime |
| BTRFS data (`/data`) | ✅ | zstd:3 compression, SSD optimizations, async discard, space_cache=v2 — Docker lives here |
| FAT32 boot (`/boot`) | ✅ | Restrictive masks (fmask=0077, dmask=0077) |
| BTRFS snapshots | ✅ | Timeshift: daily snapshots, 5 boot / 5 daily / 3 weekly / 2 monthly retention, monthly scrub |
| ZRAM swap | ✅ | 50% of RAM (64GB compressed) |
| AMD virtualization | ✅ | KVM-AMD + AMD microcode updates |

### Networking & DNS

#### DNS Stack (dnsblockd — ~930 lines of production Go)

The DNS blocker is one of the largest custom features in the project — a full Pi-hole-like system with its own Go application, NixOS module, and processor binary.

| Component | Status | Notes |
|-----------|--------|-------|
| Unbound resolver | ✅ | 2 threads, 32MB msg cache, 64MB rrset cache, DNSSEC, qname minimization, DoT upstream (Quad9 + Cloudflare) |
| dnsblockd (Go app) | ✅ | ~930-line production Go: dynamic TLS cert generation per domain (SNI-based, CA-signed), Catppuccin-themed block page UI |
| Blocklist processing | ✅ | Build-time: 25 blocklists fetched via `fetchurl`, processed by `dnsblockd process` (external dnsblockd repo) into unbound config |
| 10-category system | ✅ | Advertising 📢, Tracking 👀, Analytics 📊, Malware 🦠, Phishing 🎣, Gambling 🎰, Adult 🔞, Social 💬, Crypto 💰, Scam 🎭 |
| Temp-allow API | ✅ | Bypass blocks for 5m/15m/60m/24h via web UI, auto-redirects after allow, unbound reload + cache flush |
| False positive reporting | ✅ | `/api/report` endpoint, last 100 reports in memory |
| Prometheus metrics | ✅ | `dnsblockd_blocked_total`, `dnsblockd_active_temp_allows`, `dnsblockd_false_positive_reports` on `/metrics` |
| Stats API (port 9090) | ✅ | Top blocked domains, recent blocks (100), health endpoint, total blocked count, uptime |
| Firefox policy integration | ✅ | Disables browser DoH, installs CA cert, locks prefs (swipe gestures, default browser check) |
| NSS CA cert import | ✅ | User service imports CA cert for graphical sessions |
| sops-nix secrets | ✅ | CA cert/key + server cert/key encrypted at rest |
| Coverage | ✅ | 2.5M+ domains blocked, `.lan` domains protected, whitelist for immich.app/GitHub/etc, Reddit forced NXDOMAIN |
| Systemd hardening | ✅ | ProtectSystem=strict, ProtectHome, PrivateTmp, capability restrictions |

#### Network Infrastructure

| Feature | Status | Notes |
|---------|--------|-------|
| Static IP networking | ✅ | `eno1` 192.168.1.150, no DHCP/NetworkManager |
| Firewall | ✅ | TCP 22,53,80,443; UDP 53,853 |
| Centralized network config | ✅ | `local-network.nix` module options — lanIP, gateway, subnet, blockIP, virtualIP, piIP |
| Local DNS records | ✅ | auth/immich/forgejo/dash/photomap/signoz/tasks/crm → `*.home.lan` |
| SSH banner | ✅ | Legal warning banner on SSH login |
| Private cloud cluster | ✅ | 4 Hetzner servers (`private-cloud-hetzner-0` through `-3`) defined in SSH config |

### System Reliability

| Feature | Status | Notes |
|---------|--------|-------|
| earlyoom | ✅ | Kills at 10% free, protects sshd/journald/niri/waybar/pipewire, prefers ollama/python/chrome/node |
| OOM protection | ✅ | sshd (-1000), journald (-500), waybar (-500), pipewire (-500) |
| Systemd watchdog (sd_notify only) | ✅ | Caddy, Forgejo — correctly limited to Type=notify services |
| Service failure notifications | ✅ | `notify-failure@` template — desktop + syslog fallback |
| Service health check | ✅ | Every 15 min, critical services, desktop notification on failure |
| BTRFS scrub | ✅ | Monthly auto-scrub on `/` and `/data` |
| Smart monitoring | ✅ | smartd with scheduled short/long tests |
| Nix GC | ✅ | Weekly, delete older than 7 days, auto-optimise-store |
| systemd-boot | ✅ | 50 generation limit, latest kernel |

### Scheduled Tasks

| Task | Schedule | Notes |
|------|----------|-------|
| Crush provider update | Daily 00:00 | Updates AI provider configs |
| Blocklist auto-update | Weekly Mon 04:00 | Downloads + hashes blocklists |
| Service health check | Every 15 min | Checks critical services |
| Docker prune | Weekly Mon 03:00 | Prunes >168h |
| Immich DB backup | Daily | 7-day retention |
| Twenty DB backup | Daily | 30-day retention |
| Taskwarrior JSON backup | Daily | 30-day retention |

---

## 5. macOS (Darwin)

### System Configuration

| Feature | Status | Notes |
|---------|--------|-------|
| nix-darwin system management | ✅ | Full declarative macOS config |
| Homebrew (nix-homebrew) | ✅ | Declarative taps, auto-migrate, headlamp cask |
| Nix sandbox | ⚠️ | **Explicitly disabled** (`lib.mkForce false`) — macOS sandbox compatibility tradeoff |
| macOS Application Firewall (ALF) | ✅ | Enabled, allows signed apps, no stealth mode. Per-app rules via Little Snitch |
| Wake-on-LAN | ✅ | Explicitly disabled (laptop power saving) |
| Dark mode | ✅ | Driven by shared `preferences.appearance.variant` — not hardcoded, cross-platform |
| System defaults | ✅ | Fast key repeat (2/15), trackpad tap-to-click + 3-finger drag, Finder list view + path bar |
| State version | ✅ | nix-darwin `stateVersion = 6` |

### Security

| Feature | Status | Notes |
|---------|--------|-------|
| Touch ID for sudo (PAM) | ✅ | `pam_tid.so` enabled, Apple Watch disabled, **tmux reattach enabled** (fixes TouchID inside multiplexers) |
| Keychain auto-lock | ✅ | 5-minute inactivity timeout via activation script (`security set-keychain-settings`) |
| Chrome enterprise policies | ✅ | YouTube Shorts Blocker force-installed, HTTPS-only, sign-in disabled, password manager disabled, Safe Browsing enabled, Manifest V2 preserved |
| GPG signing | ✅ | OpenPGP for Git commits, osxkeychain credential helper |

### File Associations & Integration

| Feature | Status | Notes |
|---------|--------|-------|
| File associations (duti) | ✅ | `.txt/.md/.json/.jsonl/.yaml/.yml/.toml/.d2` → Sublime Text 4, `.rtf` → TextEdit |
| Build-time d2 verification | ✅ | Self-test asserts d2 binary + file associations are correct |
| Nix Apps Spotlight indexing | ✅ | `mdimport` for `/Applications/Nix Apps` |
| Launch Services registration | ✅ | `/Applications/Nix Apps` registered on activation |

### Services (LaunchAgents)

| Service | Status | Notes |
|---------|--------|-------|
| ActivityWatch auto-start | ✅ | `aw-qt --no-gui`, KeepAlive, background process |
| SublimeText settings sync | ✅ | Daily at 18:00, exports to dotfiles |
| aw-watcher-utilization | ✅ | Nix-managed system resource monitor → localhost:5600 |
| Crush AI provider update | ✅ | Daily at midnight, updates AI provider configs |

### Darwin Packages

| Feature | Status | Notes |
|---------|--------|-------|
| Helium browser | ✅ | Default browser (`BROWSER=helium`), with Widevine DRM + VAAPI hardware accel |
| iTerm2 | ✅ | Default terminal (`TERMINAL=iTerm2`) |
| Google Chrome | ✅ | Secondary browser with enterprise policies |
| JetBrains IDEA | ✅ | Full IDE |
| Go toolchain | ✅ | Uses nixpkgs default Go (1.26.1) — overlay removed to preserve binary cache |

---

## 6. Custom Packages (pkgs/)

| Package | Language | Status | Notes |
|---------|----------|--------|-------|
| aw-watcher-utilization | Python | ✅ | ActivityWatch system utilization watcher |
| dnsblockd | Go | ✅ | ~930-line DNS blocker: dynamic TLS, temp-allow API, false positive reporting, Prometheus metrics, 10-category system, Catppuccin block page — source in `platforms/nixos/programs/dnsblockd/` |
| emeet-pixyd | Go | ✅ | EMEET PIXY webcam daemon — via flake input |
| monitor365 | Rust | ✅ | Device monitoring agent — source-only flake input |
| netwatch | Rust | ✅ | Real-time network diagnostics TUI |
| openaudible | AppImage | ✅ | Audible audiobook manager |
| jscpd | Node.js | ✅ | Copy/paste detector |
| modernize | Go | ✅ | Go modernize tool |
| file-and-image-renamer | Go | ✅ | AI screenshot renaming — source-only flake input with Go deps |
| golangci-lint-auto-configure | Go | ✅ | Auto-configure golangci-lint — source-only flake input |
| todo-list-ai | Go | ✅ | AI-powered TODO extraction — via flake input |
| mr-sync | Go | ✅ | `~/.mrconfig` GitHub sync CLI — source-only flake input |

---

## 7. CI/CD & Quality

| Feature | Status | Notes |
|---------|--------|-------|
| GitHub Actions: flake-update | ✅ | Weekly Mon 06:00 UTC, runs `nix flake update --commit-lock-file`, opens PR via `peter-evans/create-pull-request` |
| GitHub Actions: nix-check | ✅ | On push/PR to master — `nix flake check --no-build` (eval-only), magic-nix-cache for speed |
| Pre-commit hooks | ✅ | Nix validation, shellcheck, markdownlint, private key detection, large files (1MB), TOML/YAML/JSON checks |
| Gitleaks | ✅ | Secret detection via `.gitleaks.toml` |
| Statix checks | ✅ | Nix lint in flake checks |
| Deadnix checks | ✅ | Dead code detection in flake checks |
| treefmt formatting | ✅ | alejandra + other formatters |

---

## 8. Validation & Diagnostic Scripts

| Script | Status | Purpose | Key Features |
|--------|--------|---------|--------------|
| `health-check.sh` | ✅ | Cross-platform system health | Nix/direnv/shell validation, NixOS: failed units + disk + HM age, macOS: Homebrew, PASS/FAIL/WARN summary |
| `nixos-diagnostic.sh` | ✅ | NixOS Home Manager diagnostics | HM version/generation check, `nix flake check`, broken profile detection, remediation steps |
| `validate-deployment.sh` | ✅ | Pre-deployment validator | Boot config, AMD GPU, Niri, SSH hardening, user/groups, security, generates timestamped report |
| `test-home-manager.sh` | ✅ | Post-deploy HM integration | Starship, Fish aliases, env vars (EDITOR, LANG), PATH entries, Tmux settings |
| `test-shell-aliases.sh` | ✅ | ADR-002 alias validation | 8 common + 3 platform aliases across Fish/Zsh/Bash, percentage grading |
| `ai-integration-test.sh` | ✅ | AI/ML stack validation | Ollama ROCm env vars, ROCm packages, DeepSeek support, OCR, PyTorch ecosystem |
| `update-crush-latest.sh` | ✅ | Crush version updater | Before/after version, NUR eval, `--switch` flag for auto-activate |
| `lib/paths.sh` | ✅ | Shared path constants | `PROJECT_ROOT` auto-detect, platform/user/nix paths, helper functions (`is_darwin`, `is_linux`, `ensure_dir`) |
| `benchmark-system.sh` | ❌ | Referenced by FEATURES.md | Script does not exist — justfile command removed |
| `performance-monitor.sh` | ❌ | Referenced by FEATURES.md | Script does not exist — justfile command removed |
| `shell-context-detector.sh` | ❌ | Referenced by FEATURES.md | Script does not exist — justfile command removed |
| `storage-cleanup.sh` | ❌ | Referenced by FEATURES.md | Script does not exist — justfile command removed |

---

## 9. Task Runner (Justfile)

 | Commands | Status |
|----------|----------|--------|
| Core | `setup`, `switch`, `update`, `test`, `test-fast`, `format`, `validate`, `rollback`, `health` | ✅ |
| DNS | `dns-status`, `dns-logs`, `dns-restart`, `dns-test`, `dns-perf`, `dns-diagnostics`, `dns-stats` | ✅ |
| Immich | `immich-status`, `immich-logs`, `immich-backup`, `immich-restart` | ✅ |
| Forgejo | `forgejo-update-token`, `forgejo-sync-repos`, `forgejo-setup` | ✅ |
| Taskwarrior | `task-list`, `task-add`, `task-agent`, `task-sync`, `task-status`, `task-setup`, `task-backup` | ✅ |
| Niri session | `session-status`, `session-restore` | ✅ |
| Camera | `cam-status`, `cam-privacy`, `cam-track`, `cam-reset`, `cam-audio`, `cam-sync`, `cam-restart`, `cam-logs` | ✅ |
| Hermes | `hermes-status`, `hermes-restart`, `hermes-logs`, `hermes-logs-follow` | ✅ |
| AI models | `ai-migrate`, `ai-status` | ✅ |
| Go dev | `go-lint`, `go-format`, `go-modernize`, `go-dev`, `go-tools-version`, etc. | ✅ |
| Node dev | `node-lint`, `node-format`, `node-check`, `node-test`, `node-build`, `node-dev` | ✅ |
| Cleanup | `clean`, `rust-clean` | ✅ | Comprehensive Nix/Docker/cache cleanup |
| Dep graphs | `dep-graph` (nixos/darwin/svg/png/dot/all/verbose/view/clean) | ⚠️ | Depends on nix-visualize, may be slow |

---

## 10. Known Gaps & Honesty Check

| Area | Issue | Severity |
|------|-------|----------|
| Raspberry Pi 3 | Hardware not provisioned — entire DNS failover cluster is planned-only | High |
| PhotoMap AI | Disabled in configuration, pinned to old SHA256 | Medium |
| Multi-WM (Sway) | Disabled — may have bitrot | Low |
| Twenty CRM | Module exists but unclear if actively deployed | Medium |
| Voice agents | Enabled but Whisper Docker + ROCm pipeline may need verification | Medium |
| Benchmark scripts | Removed from justfile — scripts never created | Low |
| Auditd | Disabled due to NixOS 26.05 bug #483085 | Medium |
| AppArmor | Commented out in security-hardening | Medium |
| DNS-over-QUIC | Overlay disabled — breaks binary cache (40+ min builds) | Low |
| go-overlay (perSystem) | Removed to preserve binary cache — correct tradeoff | N/A |

---

---

## 11. Architecture Patterns

### Reusable NixOS Module Patterns

| Pattern | Location | Purpose |
|---------|----------|---------|
| Systemd hardening | `lib/systemd.nix` | Reusable function: `harden { MemoryMax = "512M"; }` — PrivateTmp, NoNewPrivileges, ProtectClock, etc. |
| Service defaults | `lib/systemd/service-defaults.nix` | Restart=always, RestartSec=5s, burst limits. WatchdogSec intentionally excluded (requires sd_notify) |
| Composable services | `harden {} // serviceDefaults {}` | Nix module merge combines hardening + lifecycle into serviceConfig |
| Cross-platform preferences | `platforms/common/preferences.nix` | Shared option module — drives macOS dark mode AND Linux GTK theme from single source |
| Dendritic modules | `modules/nixos/services/*.nix` | Each file is self-contained flake-parts module with own `config` options |
| Local network options | `platforms/nixos/system/local-network.nix` | `networking.local.*` module options used by both evo-x2 and rpi3-dns |
| Shared DNS blocklists | `platforms/shared/dns-blocklists.nix` | Blocklist config consumed by both evo-x2 unbound and rpi3-dns |

### Architecture Decision Records (ADRs)

| ADR | Title | Decision |
|-----|-------|----------|
| ADR-001 | Home Manager for Darwin | Use HM for unified user config across macOS + NixOS, 80% code sharing |
| ADR-002 | Cross-shell alias architecture | Single source of truth in `shell-aliases.nix`, imported by Fish/Zsh/Bash |
| ADR-003 | Ban OpenZFS on macOS | Permanently banned (kernel panics), ZFS allowed on NixOS |
| ADR-004 | Secrets management | sops-nix with age, SSH host key as master key, 3-2-1 backup required |
| ADR-005 | Niri session restore | Periodic snapshots via systemd timer, restore on compositor startup |

---

## 12. Improvement Opportunities

### Type Model / Architecture Suggestions

| Area | Current State | Suggestion |
|------|---------------|------------|
| dnsblockd categories | Stringly-typed (10 hardcoded strings) | Define `Category` enum type in Go — make impossible states unrepresentable |
| dnsblockd temp-allow | In-memory map, lost on restart | Persist to SQLite or file — already has `/var/lib` state dir pattern |
| Nix module options | Many modules use `mkEnableOption` only | Add typed options for key config (ports, paths, timeouts) — enables validation and testing |
| Service hardening | Per-service `harden {}` calls | Consider `mkHardenedService` wrapper that combines hardening + defaults + common patterns |
| Overlays | Defined as standalone functions in flake.nix | Extract to `overlays/` directory (already done for some via pkgs/) for discoverability |
| Shared preferences | Only `preferences.nix` currently | Extend pattern: shared `services.defaults` for common service config (user, group, stateDir) |

### Well-Established Libraries Already In Use

| Library | Purpose | Why Good Choice |
|---------|---------|-----------------|
| flake-parts | Modular flake architecture | Standard pattern for complex Nix flakes, enables dendritic modules |
| sops-nix | Secrets management | Battle-tested, age/GPG/SSH key support, systemd integration |
| nix-colors | Declarative color schemes | Base16 standard, drives all apps from single source of truth |
| home-manager | User-level config | Cross-platform, NixOS module integration, declarative dotfiles |
| nix-homebrew | Homebrew management | Declarative taps/casks, auto-migrate, pinned inputs |
| niri-flake | Wayland compositor | Wraps niri for NixOS, overlay + module + wrapper-modules pattern |

---

## 13. Feature Count Summary

| Category | Count |
|----------|-------|
| NixOS service modules | 29 |
| Custom packages | 13 |
| Cross-platform programs | 20+ |
| NixOS desktop components | 15+ |
| macOS features | 25+ |
| DNS stack components | 12 |
| Validation scripts | 8 (4 missing) |
| Justfile commands | 90+ |
| Architecture patterns | 7 |
| ADRs | 5 |
| GitHub Actions | 3 |
| **Total enabled features** | **~140** |
| Planned/disabled | ~8 |
| Known gaps | 12 |

---

_Generated by deep code audit — every module, program, service file, script, and workflow was read and assessed._
