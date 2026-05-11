{
  description = "Lars nix-darwin + NixOS system flake - Modular Architecture with flake-parts";

  inputs = {
    # Use nixpkgs-unstable to match nix-darwin master
    nixpkgs.url = "github:NixOS/nixpkgs/01fbdeef22b76df85ea168fbfe1bfd9e63681b30";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add flake-parts for modular architecture
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Add NUR (Nix User Repository) for other packages
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium Browser
    helium = {
      url = "github:vikingnope/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add nix-colors for declarative color schemes
    nix-colors.url = "github:misterio77/nix-colors";

    # Add nix-homebrew for declarative Homebrew management
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Homebrew bundle for cask management
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    # Homebrew cask for headlamp and other GUI apps
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    # Niri scrollable-tiling Wayland compositor
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # OpenTelemetry TUI viewer
    otel-tui = {
      url = "github:ymtdzzz/otel-tui";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AMD NPU (XDNA) driver for Ryzen AI Max+ Strix Halo
    nix-amd-npu = {
      url = "github:robcohen/nix-amd-npu";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management via sops + age
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SilentSDDM - customizable SDDM theme with Catppuccin support
    silent-sddm = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SigNoz observability platform sources
    signoz-src = {
      url = "github:SigNoz/signoz/v0.117.1";
      flake = false;
    };
    signoz-collector-src = {
      url = "github:SigNoz/signoz-otel-collector/v0.144.2";
      flake = false;
    };

    nix-ssh-config = {
      url = "github:LarsArtmann/nix-ssh-config";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Crush AI Agent Configuration — global AI assistant settings
    # This ensures AGENTS.md and all references are synced across machines
    crush-config = {
      url = "git+ssh://git@github.com/LarsArtmann/crush-config?ref=master";
    };

    # dnsblockd — DNS blocklist service with block pages and blocklist processing
    dnsblockd = {
      url = "git+ssh://git@github.com/LarsArtmann/dnsblockd?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wallpapers-src = {
      url = "git+ssh://git@github.com/LarsArtmann/wallpapers?ref=master";
      flake = false;
    };

    # Hermes AI Agent — Discord/gateway agent platform
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.4.30";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # monitor365 — Device monitoring agent (Rust)
    monitor365 = {
      url = "git+ssh://git@github.com/LarsArtmann/monitor365?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS hardware profiles (Raspberry Pi, etc.)
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # EMEET PIXY webcam auto-activation daemon
    emeet-pixyd = {
      url = "git+ssh://git@github.com/LarsArtmann/emeet-pixyd?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Niri session manager — automatic window save/restore
    niri-session-manager = {
      url = "github:MTeaHead/niri-session-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Treefmt formatter with auto-discovery for nix fmt
    treefmt-full-flake = {
      url = "github:LarsArtmann/treefmt-full-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # todo-list-ai — AI-powered CLI tool for extracting TODOs from codebases
    todo-list-ai = {
      url = "git+ssh://git@github.com/LarsArtmann/todo-list-ai?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # library-policy — Banned/vulnerable library detector for Go projects
    library-policy = {
      url = "git+ssh://git@github.com/LarsArtmann/library-policy?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # file-and-image-renamer — AI-powered screenshot renaming tool
    file-and-image-renamer = {
      url = "git+ssh://git@github.com/LarsArtmann/file-and-image-renamer?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # golangci-lint-auto-configure — auto-configure golangci-lint for Go projects
    golangci-lint-auto-configure = {
      url = "git+ssh://git@github.com/LarsArtmann/golangci-lint-auto-configure?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # mr-sync — CLI to keep ~/.mrconfig in sync with GitHub repos
    mr-sync = {
      url = "git+ssh://git@github.com/LarsArtmann/mr-sync?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hierarchical-errors — Error handling pattern analyzer for Go projects
    hierarchical-errors = {
      url = "git+ssh://git@github.com/LarsArtmann/hierarchical-errors?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # BuildFlow — Zero-configuration build automation for Go projects
    buildflow = {
      url = "git+ssh://git@github.com/LarsArtmann/BuildFlow?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # go-auto-upgrade — Automate Go library upgrades
    go-auto-upgrade = {
      url = "git+ssh://git@github.com/LarsArtmann/go-auto-upgrade?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # go-structure-linter — Go project structure validator
    go-structure-linter = {
      url = "git+ssh://git@github.com/LarsArtmann/go-structure-linter?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # branching-flow — Error context preservation analyzer
    branching-flow = {
      url = "git+ssh://git@github.com/LarsArtmann/branching-flow?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # art-dupl — Code duplication detector
    art-dupl = {
      url = "git+ssh://git@github.com/LarsArtmann/art-dupl?ref=fork";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    dnsblockd,
    flake-parts,
    nix-darwin,
    nixpkgs,
    home-manager,
    helium,
    nur,
    nix-colors,
    nix-homebrew,
    homebrew-bundle,
    homebrew-cask,
    niri,
    otel-tui,
    nix-amd-npu,
    nix-ssh-config,
    nixos-hardware,
    emeet-pixyd,
    niri-session-manager,
    treefmt-full-flake,
    todo-list-ai,
    library-policy,
    file-and-image-renamer,
    monitor365,
    golangci-lint-auto-configure,
    mr-sync,
    hierarchical-errors,
    buildflow,
    go-auto-upgrade,
    go-structure-linter,
    branching-flow,
    art-dupl,
    ...
  }: let
    # NOTE: goOverlay removed — nixpkgs go_1_26 is already 1.26.1.
    # Overriding go forced a from-source rebuild that invalidated the
    # binary cache for the ENTIRE dependency tree (1094 derivations).
    awWatcherOverlay = _final: prev: {
      aw-watcher-utilization = prev.callPackage ./pkgs/aw-watcher-utilization.nix {};
    };

    openaudibleOverlay = _final: prev: {
      openaudible = prev.callPackage ./pkgs/openaudible.nix {};
    };

    dnsblockdOverlay = _final: prev: {
      dnsblockd = dnsblockd.packages.${prev.stdenv.system}.default;
    };

    netwatchOverlay = _final: prev: {
      netwatch = prev.callPackage ./pkgs/netwatch.nix {};
    };

    jscpdOverlay = _final: prev: {
      jscpd = prev.callPackage ./pkgs/jscpd.nix {};
    };
    # DISABLED: unboundDoQOverlay patches unbound for DNS-over-QUIC support.
    # It overrides unbound's build flags which cascades to ffmpeg, linux, pipewire,
    # and hundreds of other packages — killing binary cache hits entirely (40+ min builds).
    # To re-enable: uncomment the overlay below and add it back to overlay lists.
    # unboundDoQOverlay = _final: prev: let
    #   unboundNoSlim = prev.unbound.override {withSlimLib = false;};
    # in {
    #   unbound = unboundNoSlim.overrideAttrs (o: {
    #     buildInputs =
    #       (o.buildInputs or [])
    #       ++ [
    #         prev.ngtcp2
    #         prev.nghttp3
    #       ];
    #     configureFlags =
    #       (o.configureFlags or [])
    #       ++ [
    #         "--with-libngtcp2=${prev.ngtcp2.dev}"
    #         "--with-libnghttp3=${prev.nghttp3.dev}"
    #       ];
    #   });
    # };
    emeetPixyOverlay = emeet-pixyd.overlays.default;

    # Upstream todo-list-ai has a stale outputHash on its bun-based deps derivation.
    # On upgrade: remove fixedHash, let upstream hash attempt, if it fails:
    #   1. Delete the hash below
    #   2. Run: nix build .#todo-list-ai --no-link 2>&1 | grep got
    #   3. Paste the correct hash here
    todoListAiFixedHash = "sha256-gK2KiswUrC4iym1X0r8Ykof1H8Fb2keBsc9X0PPQPPU=";

    todoListAiOverlay = _final: prev: let
      bun = prev.bun;
      upstream = todo-list-ai.packages.${prev.stdenv.system}.default;
      patchedDeps = prev.stdenv.mkDerivation {
        name = "todo-list-ai-deps";
        src = upstream.src;
        nativeBuildInputs = [bun];
        buildPhase = "bun install --frozen-lockfile";
        installPhase = "rm -rf node_modules/.cache && cp -r node_modules $out";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = todoListAiFixedHash;
        dontFixup = true;
      };
    in {
      todo-list-ai = upstream.overrideAttrs (_: {
        buildPhase = ''
          runHook preBuild
          cp -r ${patchedDeps} node_modules
          chmod -R u+w node_modules
          find node_modules -type f -exec grep -q '^#!/usr/bin/env node' {} \; -print0 \
            | xargs -0 -r sed -i '1s|^#!/usr/bin/env node|#!${bun}/bin/bun|'
          patchShebangs node_modules/.bin

          bun build ./index.ts --compile --outfile ./dist/todo-list-ai
          runHook postBuild
        '';
      });
    };

    libraryPolicyOverlay = _final: prev: {
      library-policy = library-policy.packages.${prev.stdenv.system}.default;
    };

    hierarchicalErrorsOverlay = _final: prev: {
      hierarchical-errors = hierarchical-errors.packages.${prev.stdenv.system}.default;
    };

    golangciLintAutoConfigureOverlay = _final: prev: {
      golangci-lint-auto-configure = golangci-lint-auto-configure.packages.${prev.stdenv.system}.default;
    };

    mrSyncOverlay = _final: prev: {
      mr-sync = mr-sync.packages.${prev.stdenv.system}.default;
    };

    # Disable tests for packages with flaky integration tests in sandboxed builders
    disableTestsOverlay = _final: prev: {
      valkey = prev.valkey.overrideAttrs (_old: {doCheck = false;});
      aiocache = prev.python3Packages.aiocache.overrideAttrs (_old: {doCheck = false;});
    };

    # Shared overlays applied on all machines (Darwin + NixOS)
    sharedOverlays = [
      nur.overlays.default
      awWatcherOverlay
      todoListAiOverlay
      jscpdOverlay
      libraryPolicyOverlay
      buildflow.overlays.default
      go-auto-upgrade.overlays.default
      go-structure-linter.overlays.default
      branching-flow.overlays.default
      art-dupl.overlays.default
      golangciLintAutoConfigureOverlay
      mrSyncOverlay
      hierarchicalErrorsOverlay
      # d2 unconditionally depends on libgbm/playwright-driver (Linux-only).
      # On Darwin, libgbm → mesa → libdrm fails the platform check.
      # Override via callPackage with stubs so d2 evaluates cleanly.
      (_final: prev:
        prev.lib.optionalAttrs prev.stdenv.isDarwin {
          d2 = prev.callPackage (prev.path + "/pkgs/by-name/d2/d2/package.nix") {
            libgbm = prev.runCommand "libgbm-stub" {} "mkdir $out";
            playwright-driver = {browsers = prev.runCommand "playwright-stub" {} "mkdir $out";};
          };
        })
    ];

    # Linux-only overlays (custom packages that only make sense on NixOS)
    linuxOnlyOverlays = [
      openaudibleOverlay
      dnsblockdOverlay
      emeetPixyOverlay
      monitor365.overlays.default
      netwatchOverlay
      file-and-image-renamer.overlays.default
    ];

    # Python test override (separate because it's NixOS-specific)
    pythonTestOverlay = _final: prev: {
      python313Packages = prev.python313Packages.overrideScope (_pyFinal: pyPrev: {
        timm = pyPrev.timm.overridePythonAttrs (_: {doCheck = false;});
        xformers = pyPrev.xformers.overridePythonAttrs (_: {doCheck = false;});
      });
    };

    # Shared Home Manager configuration — only user/home file path differs per system
    sharedHomeManagerConfig = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      overwriteBackup = true;
    };

    # Shared extraSpecialArgs for Home Manager — available in all platform home.nix files
    sharedHomeManagerSpecialArgs = {
      inherit nix-colors;
      inherit nix-ssh-config;
      colorScheme = nix-colors.colorSchemes.catppuccin-mocha;
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["aarch64-darwin" "x86_64-linux"];

      # Import dendritic modules - each file is a self-contained flake-parts module
      imports = [
        ./modules/nixos/services/authelia.nix
        ./modules/nixos/services/caddy.nix
        ./modules/nixos/services/default.nix
        ./modules/nixos/services/gitea.nix
        ./modules/nixos/services/gitea-repos.nix
        ./modules/nixos/services/homepage.nix
        ./modules/nixos/services/immich.nix
        ./modules/nixos/services/signoz.nix
        ./modules/nixos/services/twenty.nix
        ./modules/nixos/services/photomap.nix
        ./modules/nixos/services/sops.nix
        ./modules/nixos/services/taskchampion.nix
        ./modules/nixos/services/voice-agents.nix
        ./modules/nixos/services/hermes.nix
        ./modules/nixos/services/minecraft.nix
        ./modules/nixos/services/monitor365.nix
        ./modules/nixos/services/comfyui.nix
        ./modules/nixos/services/dns-blocker.nix
        ./modules/nixos/services/dns-failover.nix
        ./modules/nixos/services/display-manager.nix
        ./modules/nixos/services/audio.nix
        ./modules/nixos/services/niri-config.nix
        ./modules/nixos/services/security-hardening.nix
        ./modules/nixos/services/ai-models.nix
        ./modules/nixos/services/ai-stack.nix
        ./modules/nixos/services/monitoring.nix
        ./modules/nixos/services/multi-wm.nix
        ./modules/nixos/services/chromium-policies.nix
        ./modules/nixos/services/steam.nix
        ./modules/nixos/services/file-and-image-renamer.nix
        ./modules/nixos/services/disk-monitor.nix
        ./modules/nixos/services/manifest.nix
        ./modules/nixos/services/gatus-config.nix
        ./modules/nixos/services/openseo.nix
        ./modules/nixos/services/dual-wan.nix
        # SSH module now loaded from nix-ssh-config flake input
      ];

      # Per-system configuration (packages, devShells, etc.)
      perSystem = {
        pkgs,
        system,
        lib,
        ...
      }: {
        # Allow unfree and broken packages for all systems
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.allowBroken = false; ## <-- THIS MUST ALWAYS BE FALSE!
          overlays =
            sharedOverlays
            ++ [disableTestsOverlay]
            ++ lib.optionals (system == "x86_64-linux") linuxOnlyOverlays;
        };

        # Use treefmt-full-flake's formatter which includes alejandra in PATH
        formatter = treefmt-full-flake.formatter.${system};

        packages =
          {
            modernize = import ./pkgs/modernize.nix {
              inherit pkgs;
            };
            inherit
              (pkgs)
              aw-watcher-utilization
              jscpd
              sqlc
              todo-list-ai
              library-policy
              golangci-lint-auto-configure
              mr-sync
              hierarchical-errors
              buildflow
              go-auto-upgrade
              go-structure-linter
              branching-flow
              art-dupl
              ;
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            inherit (pkgs) openaudible dnsblockd monitor365 netwatch emeet-pixyd file-and-image-renamer;
          };

        # Development shells for different program categories
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              git
              nixfmt
              alejandra
              treefmt
              deadnix
              shellcheck
              just # Task runner
              statix
              gitleaks
              jq
              sqlc
            ];
          };
        };

        checks = {
          statix =
            pkgs.runCommand "statix-check" {
              nativeBuildInputs = [pkgs.statix];
            } ''
              cd ${./.}
              statix check . 2>&1 | tee $out
            '';

          deadnix =
            pkgs.runCommand "deadnix-check" {
              nativeBuildInputs = [pkgs.deadnix];
            } ''
              cd ${./.}
              deadnix --fail --no-lambda-pattern-names . 2>&1 | tee $out
            '';
        };

        apps =
          {
            deploy = {
              type = "app";
              program = "${pkgs.writeShellScriptBin "deploy" ''
                set -euo pipefail

                echo "=== Deploying NixOS config to evo-x2 ==="
                nh os switch . 2>&1

                echo ""
                echo "=== Waiting 5s for services to settle ==="
                sleep 5

                echo ""
                echo "=== dnsblockd status ==="
                systemctl status dnsblockd --no-pager 2>/dev/null || true

                echo ""
                echo "=== Failed units ==="
                systemctl --failed --no-pager 2>/dev/null || true
              ''}/bin/deploy";
              meta.description = "Deploy NixOS config to evo-x2 via nh with post-deploy checks";
            };
            validate = {
              type = "app";
              program = "${pkgs.writeShellScriptBin "validate" ''
                nix --extra-experimental-features "nix-command flakes" flake check --no-build
              ''}/bin/validate";
              meta.description = "Validate flake without building";
            };
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            dns-diagnostics = {
              type = "app";
              program = "${pkgs.writeShellScriptBin "dns-diagnostics" ''
                echo "=== DNS Services ==="
                systemctl is-active unbound dnsblockd 2>/dev/null || true
                echo ""
                echo "=== DNS Resolution ==="
                ${pkgs.dig}/bin/dig google.com +short | head -1
                echo ""
                echo "=== DNS Blocking ==="
                ${pkgs.dig}/bin/dig doubleclick.net +short | head -1
                echo ""
                echo "=== dnsblockd Stats ==="
                ${pkgs.curl}/bin/curl -s http://127.0.0.1:9090/stats 2>/dev/null || echo "Stats unavailable"
              ''}/bin/dns-diagnostics";
              meta.description = "Run DNS stack diagnostics (resolution, blocking, stats)";
            };
          };
      };

      # System configurations (maintain backward compatibility)
      flake = {
        darwinConfigurations."Lars-MacBook-Air" = nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit (inputs.self) inputs;
            inherit nixpkgs;
            inherit helium;
            inherit nur;
            inherit nix-colors;
            inherit otel-tui;
          };
          modules = [
            {
              nixpkgs = {
                hostPlatform = "aarch64-darwin";
                config.allowUnfree = true;
                overlays = sharedOverlays;
              };
            }

            # Import nix-homebrew for declarative Homebrew management
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                user = "larsartmann";
                autoMigrate = true;
                # Pin Homebrew taps to flake inputs for reproducibility
                taps = {
                  "homebrew/bundle" = homebrew-bundle;
                  "homebrew/cask" = homebrew-cask;
                };
              };
            }

            # Import Home Manager module for Darwin
            inputs.home-manager.darwinModules.home-manager

            # Define Home Manager configuration inline for top-level visibility
            {
              home-manager =
                sharedHomeManagerConfig
                // {
                  users.larsartmann = {...}: {
                    imports = [
                      ./platforms/darwin/home.nix
                    ];
                  };
                  extraSpecialArgs = sharedHomeManagerSpecialArgs;
                };
            }

            # Core Darwin configuration
            ./platforms/darwin/default.nix
          ];
        };

        # NixOS configuration
        nixosConfigurations."evo-x2" = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit (inputs.self) inputs;
            inherit helium;
            inherit nur;
            inherit nix-colors;
            inherit niri;
            inherit otel-tui;
            inherit nix-amd-npu;
            inherit nix-ssh-config;
          };
          modules = [
            {
              nixpkgs = {
                hostPlatform = "x86_64-linux";
                config.allowUnfree = true;
                overlays =
                  sharedOverlays
                  ++ [
                    inputs.niri.overlays.niri
                  ]
                  ++ linuxOnlyOverlays
                  ++ [pythonTestOverlay];
              };
              system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
            }
            home-manager.nixosModules.home-manager
            nur.modules.nixos.default

            {
              home-manager =
                sharedHomeManagerConfig
                // {
                  users.lars = _: {
                    imports = [
                      ./platforms/nixos/users/home.nix
                    ];
                  };
                  extraSpecialArgs =
                    sharedHomeManagerSpecialArgs
                    // {
                      wallpapers = inputs.wallpapers-src;
                    };
                };
            }

            # Import the existing NixOS configuration
            inputs.niri.nixosModules.niri
            inputs.nix-amd-npu.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            inputs.silent-sddm.nixosModules.default
            inputs.self.nixosModules.authelia
            inputs.self.nixosModules.caddy
            inputs.self.nixosModules.default-services
            inputs.self.nixosModules.gitea
            inputs.self.nixosModules.gitea-repos
            inputs.self.nixosModules.homepage
            inputs.self.nixosModules.immich
            inputs.self.nixosModules.photomap
            inputs.self.nixosModules.sops
            inputs.nix-ssh-config.nixosModules.ssh
            inputs.self.nixosModules.signoz
            inputs.self.nixosModules.twenty
            inputs.self.nixosModules.taskchampion
            inputs.self.nixosModules.voice-agents
            inputs.self.nixosModules.hermes
            inputs.self.nixosModules.minecraft
            inputs.self.nixosModules.monitor365
            inputs.self.nixosModules.comfyui
            inputs.self.nixosModules.dns-blocker
            inputs.self.nixosModules.dns-failover
            inputs.self.nixosModules.display-manager
            inputs.self.nixosModules.audio
            inputs.self.nixosModules.niri-config
            inputs.self.nixosModules.security-hardening
            inputs.self.nixosModules.ai-models
            inputs.self.nixosModules.ai-stack
            inputs.self.nixosModules.monitoring
            inputs.self.nixosModules.multi-wm
            inputs.self.nixosModules.chromium-policies
            inputs.self.nixosModules.steam
            inputs.self.nixosModules.file-and-image-renamer
            inputs.niri-session-manager.nixosModules.niri-session-manager
            inputs.self.nixosModules.disk-monitor
            inputs.self.nixosModules.manifest
            inputs.self.nixosModules.gatus-config
            inputs.self.nixosModules.openseo
            inputs.self.nixosModules.dual-wan
            inputs.emeet-pixyd.nixosModules.default
            ./platforms/nixos/system/configuration.nix
          ];
        };

        # Raspberry Pi 3 — DNS cluster backup node
        nixosConfigurations."rpi3-dns" = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {
            inherit (inputs.self) inputs;
            inherit nix-ssh-config;
            inherit nixos-hardware;
          };
          modules = [
            {
              nixpkgs = {
                hostPlatform = "aarch64-linux";
                config.allowUnfree = true;
                overlays = [
                  nur.overlays.default
                  dnsblockdOverlay
                ];
              };
            }
            home-manager.nixosModules.home-manager
            nur.modules.nixos.default
            {
              home-manager =
                sharedHomeManagerConfig
                // {
                  users.root = _: {
                    programs.home-manager.enable = true;
                    home = {
                      stateVersion = "25.11";
                      file.".config/crush".source = inputs.crush-config;
                    };
                  };
                  extraSpecialArgs = sharedHomeManagerSpecialArgs;
                };
            }
            inputs.self.nixosModules.dns-failover
            nixos-hardware.nixosModules.raspberry-pi-3
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
            ./platforms/nixos/rpi3/default.nix
          ];
        };
      };
    };
}
