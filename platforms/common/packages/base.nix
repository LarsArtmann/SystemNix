{
  pkgs,
  lib,
  helium,
  herdr ? null,
  otel-tui ? null,
  larsPackages,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;

  heliumPackage =
    if builtins.hasAttr "packages" helium && builtins.hasAttr system helium.packages then
      (helium.packages.${system}.default or helium.packages.${system}.helium or null)
    else
      null;

  heliumWrapped =
    if heliumPackage != null && pkgs.stdenv.hostPlatform.isLinux then
      pkgs.symlinkJoin {
        name = "helium";
        paths = [ heliumPackage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          # Add Widevine CDM for DRM streaming (Netflix, Max, Disney+, etc.)
          rm -rf $out/opt
          cp -a ${heliumPackage}/opt $out/opt
          chmod -R u+w $out/opt
          ln -s ${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm $out/opt/helium/WidevineCdm

          # Wrap the REAL binary directly — NOT the upstream wrapper.
          # Double-wrapping (wrapping the upstream makeWrapper script) caused a
          # silent --enable-features collision: Chromium's GetSwitchValueASCII
          # returns the LAST value for duplicate switches, so one layer's
          # features silently overwrote the other. Single-wrapping ensures all
          # flags reach the binary exactly once.
          #
          # Note: WaylandWindowDecorations (from upstream) is intentionally EXCLUDED —
          # niri is a scrollable tiling compositor that strips all decorations.
          # CSD would add conflicting title bars/buttons useless in a tiling layout.
          #
          # Note: --enable-gpu-rasterization is intentionally EXCLUDED —
          # Strix Halo has 51+ GiB GPUActive (55% of visible RAM) with GPUReclaim=0.
          # GPU rasterization moves more work to the GPU, increasing GTT buffer objects
          # and worsening the unified memory pressure crisis.
          #
          # Anti-throttling flags — CRITICAL for video playback in niri (tiling WM).
          # Without these, Chromium aggressively throttles background tabs and occluded
          # windows: requestAnimationFrame drops to ~1 FPS, JS timers coalesce to ~1/sec,
          # media playback is suspended. In niri's scrolling layout, when a video tab is
          # scrolled out of view or loses focus, playback drops to 1-3 FPS.
          # --disable-background-timer-throttling: JS timers run at full speed in background tabs
          # --disable-backgrounding-occluded-windows: Aura occlusion tracker can't background windows
          # --disable-renderer-backgrounding: background renderer processes keep full CPU priority
          # --disable-background-media-suspend: media keeps playing in background tabs
          rm -rf $out/bin
          mkdir -p $out/bin
          # --password-store=basic: Helium must NEVER touch gnome-keyring.
          # The login keyring's password desynced from the SDDM password
          # (journal: gkr-pam "the password for the login keyring was
          # invalid"), so PAM auto-unlock failed and every browser start
          # popped a gcr-prompter "unlock login keyring" dialog — the
          # double password at login — plus 100+ gkr-pam journal
          # lines/boot from DBus activation retries. Verified lossless
          # 2026-10-06: all profiles' Cookies were ALREADY v11
          # (basic-store AES, hardcoded key) because the keyring never
          # unlocked — nothing of Helium's lives in the keyring; KeePassXC
          # owns credentials. (NOTE: comments must NEVER sit between the
          # backslash-continued --add-flags lines — a comment line ends
          # the command and the next flag line becomes "command not found"
          # at build time, invisible to eval-only checks.)
          makeWrapper $out/opt/helium/helium $out/bin/helium \
            --prefix LD_LIBRARY_PATH : "${
              pkgs.lib.makeLibraryPath ([
                pkgs.libGL
                pkgs.libvdpau
                pkgs.libva
                pkgs.pipewire
                pkgs.alsa-lib
                pkgs.libpulseaudio
              ])
            }" \
            --add-flags "--ozone-platform-hint=auto" \
            --add-flags "--enable-features=VaapiVideoDecoder,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoEncoder,VaapiIgnoreDriverChecks,UseMultiPlaneFormatForHardwareVideo,WebAuthenticationHybridTransport" \
            --add-flags "--ignore-gpu-blocklist" \
            --add-flags "--disable-gpu-watchdog" \
            --add-flags "--disable-background-timer-throttling" \
            --add-flags "--disable-backgrounding-occluded-windows" \
            --add-flags "--disable-renderer-backgrounding" \
            --add-flags "--disable-background-media-suspend" \
            --add-flags "--restore-last-session" \
            --add-flags "--disable-session-crashed-bubble" \
            --add-flags "--password-store=basic" \
            --add-flags "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'" \
            --add-flags "--check-for-update-interval=0" \
            --add-flags "--load-extension=/home/lars/projects/nsfw-classifier/nsfw-extension"
          # Auto-loads the local NSFW filter extension on EVERY launch (main
          # profile, dp1/dp2 instances, desktop file — all exec this bin).
          # --load-extension exists in Helium's unbranded build (removed only
          # from branded Chrome 137+; switch + loader verified live in this
          # binary via a headless probe that installed the extension). The
          # path MUST stay stable: Chromium derives the extension ID from a
          # SHA-256 of the path (here: inepplcmcfagipoamngjldlehdjlihfe), so
          # chrome.storage settings survive restarts and deploys. Pointing it
          # at a rebuilt store-path copy would change the ID per rebuild and
          # silently reset all extension settings. Loading the live source
          # dir also means code edits are picked up on the next helium
          # restart. A missing dir only logs a load error — the browser
          # starts fine.
          # CRITICAL: --disable-background-networking and --disable-component-update
          # were REMOVED because they silently block all force_installed extensions
          # from downloading. --disable-background-networking kills the ExtensionDownloader
          # (the Chromium subsystem that fetches CRX files from update_url in enterprise
          # policy). Without it, ExtensionSettings with force_installed mode silently fails —
          # policies appear in chrome://policy but no extension ever appears in
          # chrome://extensions. Helium's ungoogled-chromium base already strips Google
          # telemetry, and Helium anonymizes Chrome Web Store requests via its own proxy,
          # so the privacy tradeoff of allowing background networking is acceptable.
          #
          # --enable-zero-copy was REMOVED (2026-08-22) to test whether it causes
          # display hotplug crashes. If removing it prevents the crashes,
          # --disable-gpu-watchdog may also become unnecessary. Zero-copy can
          # cause GPU process crashes on display reconfiguration because the
          # GPU buffer manager doesn't always handle output removal gracefully.
          # Re-evaluate after observing hotplug behavior across deploys.
        '';
      }
    else
      heliumPackage;

  # Essential CLI tools that work across platforms
  essentialPackages = [
    # Version control
    pkgs.git
    pkgs.gh # GitHub CLI
    pkgs.git-town # High-level Git workflow management
    pkgs.git-filter-repo # Rewrite git history
    # NOTE: pkgs.jj is a JSON stream editor, NOT Jujutsu — do not re-add here.
    # Jujutsu is installed via programs.jujutsu in platforms/common/programs/jujutsu.nix.
    pkgs.mr # myrepos — manage multiple repositories via a single command

    # Essential editors
    pkgs.micro
    pkgs.neovim

    # Terminal emulator
    pkgs.alacritty-graphics

    # Shells and prompts
    pkgs.fish
    pkgs.carapace

    # File operations and browsing
    pkgs.curl
    pkgs.wget
    pkgs.tree
    pkgs.ripgrep
    pkgs.fd
    pkgs.eza
    pkgs.bat
    pkgs.trash-cli

    # Data manipulation
    pkgs.jq
    pkgs.yq-go
    pkgs.duckdb # In-process analytical SQL database (used by monitor365)
    pkgs.sqlite # sqlite3 CLI for inspecting service sqlite DBs

    # Task runner
    pkgs.just

    # Security tools
    pkgs.gitleaks
    pkgs.gnupg
    pkgs.pre-commit
    pkgs.openssh
    pkgs.ssh-to-age
    # Secrets-workflow CLIs (the sops-secret-management skill runs these).
    # GLOBAL operator tools — they must never ride a service module's
    # conditional systemPackages: services.forgejo-repos going enable=false
    # on 2026-10-03 silently dropped both from the system closure and
    # broke every `sops`/`age` invocation on the host until this restore.
    pkgs.sops
    pkgs.age

    # Modern CLI productivity tools
    pkgs.glow # Render markdown on the CLI, with pizzazz

    # System monitoring
    pkgs.btop
    pkgs.bottom
    pkgs.fastfetch

    # Archive tools
    pkgs.unzip
    pkgs.zip

    # File utilities
    pkgs.sd # Modern find and replace
    pkgs.dust # Modern du

    # GNU utilities (cross-platform)
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnused

    # Graph visualization
    pkgs.graphviz
    pkgs.d2 # Declarative diagram scripting language
    pkgs.mermaid-cli # CLI for Mermaid diagram generation from markdown

    # Media tools
    pkgs.ffmpeg # Complete, cross-platform solution to record, convert and stream audio and video

    # Clipboard management (Linux-only, Wayland)
    # cliphist # Not available on Darwin (Linux-only package)
    # Desktop integration (cross-platform)
    pkgs.xdg-utils # XDG desktop utilities for both platforms
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.cliphist # Wayland clipboard history for Linux
  ];

  # Development tools (platform-agnostic)
  developmentPackages = [
    # JavaScript/TypeScript
    pkgs.bun # Incredibly fast JavaScript runtime
    pkgs.pnpm # Fast, disk space-efficient package manager
    pkgs.vtsls # TypeScript language server for IDE LSP support
    pkgs.esbuild # Fast JavaScript bundler and minifier

    # Go development
    # go_1_27: pinned ahead of the nixpkgs default (1.26.7). The ecosystem
    # go.mod floor is 1.27.1; the shell's `go` must satisfy it natively.
    # Shells run with GOTOOLCHAIN unset (2026-09-29 removal), so the
    # built-in auto mode never downloads a toolchain for floor-satisfied
    # repos.
    pkgs.go_1_27
    pkgs.golines # Go line-shortener (moved from stray ~/go/bin 2026-10-01, fifty-todos #45; nixpkgs 0.16.0 verified)
    pkgs.gopls
    pkgs.golangci-lint
    pkgs.golangci-lint-langserver
    pkgs.go-arch-lint
    pkgs.gofumpt
    pkgs.gotests
    pkgs.mockgen
    pkgs.sqlc
    pkgs.protoc-gen-go
    pkgs.buf
    pkgs.delve
    pkgs.gup
    pkgs.templ

    # Document rendering
    pkgs.typst # Document typesetting compiler (CV PDF rendering; moved from imperative nix profile 2026-09-22)

    # CGO build tools for Go
    pkgs.gcc
    pkgs.gnumake

    # Common libraries for CGO dependencies
    pkgs.pkg-config

    # JavaScript/TypeScript development (Oxc tools)
    pkgs.oxlint
    pkgs.tsgolint
    pkgs.oxfmt

    # Code quality
    pkgs.scc # Sloc, Cloc and Code: fast lines of code counter
    pkgs.jscpd # Copy/paste detector for source code

    # Infrastructure as Code
    pkgs.terraform # Infrastructure as Code tool from HashiCorp
    pkgs.google-cloud-sdk # Google Cloud SDK for cloud management

    # Kubernetes tools
    pkgs.kubectl # Kubernetes CLI (includes fish/zsh/bash completions!)
    pkgs.k9s # Kubernetes CLI To Manage Your Clusters In Style

    # Observability tools (Linux-only — otel-tui builds from source, 40+ min on macOS)
  ]
  ++ lib.optionals (otel-tui != null) [
    otel-tui.packages.${system}.otel-tui # OpenTelemetry terminal viewer
  ]
  ++ lib.optionals (herdr != null) [
    herdr.packages.${system}.default # Agent multiplexer for the terminal
  ]
  ++ [
    # Nix helper tools
    pkgs.nh
    pkgs.statix # Lints and suggestions for Nix code
    pkgs.deadnix # Find and remove dead code (unused bindings) in Nix files

    # Go testing
    pkgs.ginkgo # BDD testing framework for Go
    pkgs.go-licenses # Dependency license reporting — go1.27-rebuilt via overlays/shared.nix (analyzers lead the fleet toolchain)
    pkgs.govalid # Type-safe struct validation code generator
    pkgs.gotools # Go tools (goimports, etc.)

    # Wallpaper management tools (Linux-only)
    pkgs.imagemagick # Image manipulation for wallpaper management
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.geekbench_6 # Geekbench 6 includes AI/ML benchmarking capabilities (Linux-only)
    pkgs.goreleaser # Release Go projects with ease — global binary, Linux-only (Darwin disk-constrained)
  ];

  # Linux-specific utilities
  linuxUtilities = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.jetbrains.idea
    pkgs.openaudible
    pkgs.prismlauncher # Minecraft launcher (MultiMC fork)

    # Media streaming
    pkgs.fcast-client # FCast Client Terminal, media streaming client
    pkgs.fcast-receiver # FCast Receiver, media streaming receiver
    pkgs.ffcast # Run commands on rectangular screen regions
    pkgs.castnow # Command-line Chromecast player for Google Cast devices

    # Hardware monitoring (Linux-only)
    pkgs.lm_sensors # Hardware monitoring (GPU/CPU temperature)

    # System diagnostics
    pkgs.radeontop # AMD GPU monitoring
    pkgs.strace # System call tracer
    # 2026-10-01 nixpkgs bump: ltrace's testsuite dies under make check in
    # the sandbox (ptrace class); the binary itself builds clean. Drop the
    # override when nixpkgs ships a fixed ltrace.
    (pkgs.ltrace.overrideAttrs (_: {
      doCheck = false;
    })) # Library call tracer
    pkgs.nethogs # Per-process network bandwidth
    pkgs.iftop # Network interface bandwidth
    pkgs.netwatch # Real-time network diagnostics TUI (interfaces, connections, packets, health probes)
    pkgs.ecapture # Capture SSL/TLS text content without CA cert using eBPF

    # Network & DNS diagnostics — always available, even during outages
    pkgs.bind.dnsutils # dig, nslookup, host, delv — DNS troubleshooting
    pkgs.ldns # drill — modern dig alternative with DNSSEC validation
    pkgs.dnstracer # Trace DNS delegation chain to authoritative servers
    pkgs.mtr # Combined ping + traceroute with real-time stats
    pkgs.traceroute # Classic network path tracing
    pkgs.tcpdump # Packet capture — essential for protocol-level debugging
    pkgs.nettools # netstat, ifconfig, route — legacy network tools (ss replacement kept too)

    # Privacy & anonymity
    pkgs.tor-browser # Anonymous browsing bundle

    # Additional ricing tools discovered from community configs
    pkgs.wl-color-picker # Color picker for Wayland
    pkgs.imv # Minimal image viewer
    pkgs.wf-recorder # Screen recorder
    pkgs.brillo # Brightness control utility
    pkgs.pamixer # PulseAudio command line mixer
    pkgs.alsa-utils # speaker-test, aplay, amixer — audio debugging & test tones
    pkgs.pipewire # pw-cat, pw-play, pw-cli — PipeWire CLI for audio routing debug

    # Disk space visualization
    pkgs.qdirstat # Qt-based disk usage analyzer with treemap visualization
  ];

  # GUI Applications (cross-platform)
  guiPackages =
    lib.optional (heliumWrapped != null) heliumWrapped
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      pkgs.google-chrome
      pkgs.iterm2
      pkgs.duti # macOS file association utility (used by activation scripts)
    ];

  # Use NUR (Nix User Repository) for the most up-to-date version of Crush
  # NUR is updated much more frequently than nixpkgs unstable
  #
  # Wrapped with ionice/nice to elevate I/O and CPU priority above builds
  # (BE/3 vs nix-daemon BE/7). Works in scripts, MCP, and non-login shells —
  # not just interactive sessions like a shell alias would.
  realCrush = pkgs.nur.repos.charmbracelet.crush;
  crushWithIoPriority = pkgs.writeShellApplication {
    name = "crush";
    runtimeInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.util-linux ];
    text =
      if pkgs.stdenv.hostPlatform.isLinux then
        ''
          exec ionice -c 2 -n 3 nice -n 5 ${lib.getExe' realCrush "crush"} "$@"
        ''
      else
        ''
          exec ${lib.getExe' realCrush "crush"} "$@"
        '';
  };
  aiPackages = [ crushWithIoPriority ];
in
{
  # System packages list
  environment.systemPackages =
    essentialPackages
    ++ developmentPackages
    ++ (builtins.attrValues larsPackages)
    ++ guiPackages
    ++ aiPackages
    ++ linuxUtilities;
}
