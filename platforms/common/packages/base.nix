{
  pkgs,
  lib,
  helium,
  herdr ? null,
  otel-tui ? null,
  larsPackages,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  heliumPackage =
    if builtins.hasAttr "packages" helium && builtins.hasAttr system helium.packages
    then (helium.packages.${system}.default or helium.packages.${system}.helium or null)
    else null;

  heliumWrapped =
    if heliumPackage != null && pkgs.stdenv.isLinux
    then
      pkgs.symlinkJoin {
        name = "helium";
        paths = [heliumPackage];
        nativeBuildInputs = [pkgs.makeWrapper];
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
          rm -rf $out/bin
          mkdir -p $out/bin
          makeWrapper $out/opt/helium/helium $out/bin/helium \
            --prefix LD_LIBRARY_PATH : "${
            pkgs.lib.makeLibraryPath (
              with pkgs; [
                libGL
                libvdpau
                libva
                pipewire
                alsa-lib
                libpulseaudio
              ]
            )
          }" \
            --add-flags "--ozone-platform-hint=auto" \
            --add-flags "--enable-features=VaapiVideoDecoder,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoEncoder,VaapiIgnoreDriverChecks,UseMultiPlaneFormatForHardwareVideo,WebAuthenticationHybridTransport" \
            --add-flags "--ignore-gpu-blocklist" \
            --add-flags "--enable-zero-copy" \
            --add-flags "--disable-gpu-watchdog" \
            --add-flags "--restore-last-session" \
            --add-flags "--disable-session-crashed-bubble" \
            --add-flags "--disable-component-update" \
            --add-flags "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'" \
            --add-flags "--check-for-update-interval=0" \
            --add-flags "--disable-background-networking"
        '';
      }
    else heliumPackage;

  # Essential CLI tools that work across platforms
  essentialPackages = with pkgs;
    [
      # Version control
      git
      gh # GitHub CLI
      git-town # High-level Git workflow management
      git-filter-repo # Rewrite git history
      jj # Git-compatible version control system
      mr # myrepos — manage multiple repositories via a single command

      # Essential editors
      micro
      neovim

      # Terminal emulator
      alacritty-graphics

      # Shells and prompts
      fish
      carapace

      # File operations and browsing
      curl
      wget
      tree
      ripgrep
      fd
      eza
      bat
      trash-cli

      # Data manipulation
      jq
      yq-go

      # Task runner
      just

      # Security tools
      gitleaks
      gnupg
      pre-commit
      openssh
      ssh-to-age

      # Modern CLI productivity tools
      glow # Render markdown on the CLI, with pizzazz

      # System monitoring
      btop
      bottom

      # Archive tools
      unzip
      zip

      # File utilities
      sd # Modern find and replace
      dust # Modern du

      # GNU utilities (cross-platform)
      coreutils
      findutils
      gnused

      # Graph visualization
      graphviz
      d2 # Declarative diagram scripting language
      mermaid-cli # CLI for Mermaid diagram generation from markdown

      # Media tools
      ffmpeg # Complete, cross-platform solution to record, convert and stream audio and video

      # Clipboard management (Linux-only, Wayland)
      # cliphist # Not available on Darwin (Linux-only package)
      # Desktop integration (cross-platform)
      xdg-utils # XDG desktop utilities for both platforms
    ]
    ++ lib.optionals stdenv.isLinux [
      cliphist # Wayland clipboard history for Linux
    ];

  # Development tools (platform-agnostic)
  developmentPackages = with pkgs;
    [
      # JavaScript/TypeScript
      bun # Incredibly fast JavaScript runtime
      pnpm # Fast, disk space-efficient package manager
      vtsls # TypeScript language server for IDE LSP support
      esbuild # Fast JavaScript bundler and minifier

      # Go development
      go
      gopls
      golangci-lint
      golangci-lint-langserver
      go-arch-lint
      gofumpt
      gotests
      mockgen
      sqlc
      protoc-gen-go
      buf
      delve
      gup
      templ

      # CGO build tools for Go
      gcc
      gnumake

      # Common libraries for CGO dependencies
      pkg-config

      # JavaScript/TypeScript development (Oxc tools)
      oxlint
      tsgolint
      oxfmt

      # Code quality
      scc # Sloc, Cloc and Code: fast lines of code counter
      jscpd # Copy/paste detector for source code

      # Infrastructure as Code
      terraform # Infrastructure as Code tool from HashiCorp
      google-cloud-sdk # Google Cloud SDK for cloud management

      # Container tools
      docker # Docker CLI tools
      docker-compose # Multi-container Docker applications

      # Kubernetes tools
      kubectl # Kubernetes CLI (includes fish/zsh/bash completions!)
      k9s # Kubernetes CLI To Manage Your Clusters In Style

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
      nh
      statix # Lints and suggestions for Nix code

      # Go testing
      ginkgo # BDD testing framework for Go
      govalid # Type-safe struct validation code generator
      gotools # Go tools (goimports, etc.)

      # On-device markdown search engine (BM25 + vector + LLM reranking).
      # Used both as CLI (`qmd search ...`) and as the long-lived
      # `qmd mcp --http` server managed by `modules/nixos/services/qmd.nix`.
      qmd

      # Wallpaper management tools (Linux-only)
      imagemagick # Image manipulation for wallpaper management
    ]
    ++ lib.optionals stdenv.isLinux [
      geekbench_6 # Geekbench 6 includes AI/ML benchmarking capabilities (Linux-only)
      goreleaser # Release Go projects with ease — global binary, Linux-only (Darwin disk-constrained)
    ];

  # Linux-specific utilities
  linuxUtilities = with pkgs;
    lib.optionals stdenv.isLinux [
      jetbrains.idea
      openaudible
      prismlauncher # Minecraft launcher (MultiMC fork)

      # Media streaming
      fcast-client # FCast Client Terminal, media streaming client
      fcast-receiver # FCast Receiver, media streaming receiver
      ffcast # Run commands on rectangular screen regions
      castnow # Command-line Chromecast player for Google Cast devices

      # Hardware monitoring (Linux-only)
      lm_sensors # Hardware monitoring (GPU/CPU temperature)

      # System diagnostics
      radeontop # AMD GPU monitoring
      strace # System call tracer
      ltrace # Library call tracer
      nethogs # Per-process network bandwidth
      iftop # Network interface bandwidth
      netwatch # Real-time network diagnostics TUI (interfaces, connections, packets, health probes)
      ecapture # Capture SSL/TLS text content without CA cert using eBPF

      # Network & DNS diagnostics — always available, even during outages
      bind.dnsutils # dig, nslookup, host, delv — DNS troubleshooting
      ldns # drill — modern dig alternative with DNSSEC validation
      dnstracer # Trace DNS delegation chain to authoritative servers
      mtr # Combined ping + traceroute with real-time stats
      traceroute # Classic network path tracing
      tcpdump # Packet capture — essential for protocol-level debugging
      nettools # netstat, ifconfig, route — legacy network tools (ss replacement kept too)

      # Privacy & anonymity
      tor-browser # Anonymous browsing bundle

      # Additional ricing tools discovered from community configs
      wl-color-picker # Color picker for Wayland
      imv # Minimal image viewer
      wf-recorder # Screen recorder
      brillo # Brightness control utility
      pamixer # PulseAudio command line mixer

      # Disk space visualization
      qdirstat # Qt-based disk usage analyzer with treemap visualization
    ];

  # GUI Applications (cross-platform)
  guiPackages = with pkgs;
    lib.optional (heliumWrapped != null) heliumWrapped
    ++ lib.optionals stdenv.isDarwin [
      google-chrome
      iterm2
      duti # macOS file association utility (used by activation scripts)
    ];

  # Use NUR (Nix User Repository) for the most up-to-date version of Crush
  # NUR is updated much more frequently than nixpkgs unstable
  aiPackages = [pkgs.nur.repos.charmbracelet.crush];
in {
  # System packages list
  environment.systemPackages =
    essentialPackages
    ++ developmentPackages
    ++ (builtins.attrValues larsPackages)
    ++ guiPackages
    ++ aiPackages
    ++ linuxUtilities;
}
