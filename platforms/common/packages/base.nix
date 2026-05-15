{
  pkgs,
  lib,
  helium,
  otel-tui ? null,
  ...
}: let
  # Import modernize from local pkgs if available
  inherit (pkgs.stdenv.hostPlatform) system;
  modernizePackage =
    (builtins.tryEval (import ../../../pkgs/modernize.nix {
      inherit pkgs;
    })).value or null;

  # Override gopls to remove modernize binary (we use our custom build)
  goplsWithoutModernize = pkgs.symlinkJoin {
    name = "gopls-without-modernize";
    paths = [pkgs.gopls];
    postBuild = ''
      rm -f $out/bin/modernize
    '';
  };

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

          # Wrap binary with VAAPI hardware video acceleration flags
          rm -rf $out/bin
          cp -a ${heliumPackage}/bin $out/bin
          chmod -R u+w $out/bin
          wrapProgram $out/bin/helium \
            --add-flags "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,AcceleratedVideoDecoder,AcceleratedVideoEncoder" \
            --add-flags "--ignore-gpu-blocklist" \
            --add-flags "--enable-zero-copy" \
            --add-flags "--restore-last-session" \
            --add-flags "--disable-session-crashed-bubble" \
            --add-flags "--disable-backgrounding-occluded-windows" \
            --add-flags "--disable-renderer-backgrounding"
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
      nodejs # Node.js JavaScript runtime
      pnpm # Fast, disk space-efficient package manager
      vtsls # TypeScript language server for IDE LSP support
      esbuild # Fast JavaScript bundler and minifier

      # Go development
      go
      goplsWithoutModernize # Custom override without modernize binary (use our custom build)
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
    ++ [
      # Nix helper tools
      nh
      statix # Lints and suggestions for Nix code

      # AI-powered code analysis
      todo-list-ai # Extract TODOs from codebases using AI

      # Go linting automation
      golangci-lint-auto-configure # Auto-configure golangci-lint for Go projects

      # Library governance
      library-policy # Banned/vulnerable library detector for Go projects

      # Repo management
      mr-sync # Keep ~/.mrconfig in sync with GitHub repos

      # Go tooling ecosystem (LarsArtmann)
      art-dupl # AST-based code deduplication
      branching-flow # Error context preservation analyzer
      buildflow # Build automation
      go-auto-upgrade # Automated Go version upgrades
      go-structure-linter # Go project structure linting
      hierarchical-errors # Error handling pattern analyzer

      # Go testing
      ginkgo # BDD testing framework for Go
      gotools # Go tools (goimports, etc.)

      # Wallpaper management tools (Linux-only)
      imagemagick # Image manipulation for wallpaper management
    ]
    ++ lib.optionals (modernizePackage != null) [modernizePackage]
    ++ lib.optionals stdenv.isLinux [
      awww # Simple Wayland Wallpaper for animated wallpapers (Linux-only)
      geekbench_6 # Geekbench 6 includes AI/ML benchmarking capabilities (Linux-only)
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

      # Additional ricing tools discovered from community configs
      wl-color-picker # Color picker for Wayland
      swappy # Screenshot annotation tool
      imv # Minimal image viewer
      wf-recorder # Screen recorder
      brillo # Brightness control utility
      pamixer # PulseAudio command line mixer
      foot # Lightweight Wayland terminal emulator
      zellij # Modern terminal multiplexer
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
  environment.systemPackages = essentialPackages ++ developmentPackages ++ guiPackages ++ aiPackages ++ linuxUtilities;
}
