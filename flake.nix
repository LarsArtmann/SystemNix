{
  description = "Lars nix-darwin + NixOS system flake - Modular Architecture with flake-parts";

  nixConfig = {
    extra-experimental-features = ["nix-command" "flakes" "pipe-operators"];
    warn-dirty = false;
  };

  inputs = {
    # Use nixpkgs-unstable to match nix-darwin master
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

    # Single flake-utils source — all inputs follow this to avoid 10+ duplicate instances
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    # Single nix-systems source — flake-utils and niri-session-manager follow this
    systems.url = "github:nix-systems/default";

    # Single treefmt-nix source — dnsblockd, library-policy, niri-session-manager follow this
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add NUR (Nix User Repository) for other packages
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Helium Browser
    helium = {
      url = "github:vikingnope/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };

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
      inputs.flake-utils.follows = "flake-utils";
    };

    # AMD NPU (XDNA) driver for Ryzen AI Max+ Strix Halo
    nix-amd-npu = {
      url = "github:robcohen/nix-amd-npu";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        treefmt-full-flake.follows = "treefmt-full-flake";
      };
    };

    # Crush AI Agent Configuration — global AI assistant settings
    # This ensures AGENTS.md and all references are synced across machines
    crush-config = {
      url = "git+ssh://git@github.com/LarsArtmann/crush-config?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # dnsblockd — DNS blocklist service with block pages and blocklist processing
    dnsblockd = {
      url = "git+ssh://git@github.com/LarsArtmann/dnsblockd?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    wallpapers-src = {
      url = "git+ssh://git@github.com/LarsArtmann/wallpapers?ref=master";
      flake = false;
    };

    # Hermes AI Agent — Discord/gateway agent platform
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.5.16";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # monitor365 — Device monitoring agent (Rust)
    monitor365 = {
      url = "git+ssh://git@github.com/LarsArtmann/monitor365?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
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
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Treefmt formatter with auto-discovery for nix fmt
    treefmt-full-flake = {
      url = "github:LarsArtmann/treefmt-full-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # todo-list-ai — AI-powered CLI tool for extracting TODOs from codebases
    todo-list-ai = {
      url = "git+ssh://git@github.com/LarsArtmann/todo-list-ai?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    # library-policy — Banned/vulnerable library detector for Go projects
    library-policy = {
      url = "git+ssh://git@github.com/LarsArtmann/library-policy?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # file-and-image-renamer — AI-powered screenshot renaming tool
    file-and-image-renamer = {
      url = "git+ssh://git@github.com/LarsArtmann/file-and-image-renamer?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Shared Go libraries — single source of truth for all Go tool repos
    go-finding = {
      url = "git+ssh://git@github.com/LarsArtmann/go-finding?ref=master";
      flake = false;
    };
    go-output = {
      url = "git+ssh://git@github.com/LarsArtmann/go-output?ref=master";
      flake = false;
    };
    gogenfilter = {
      url = "git+ssh://git@github.com/LarsArtmann/gogenfilter?ref=master";
      flake = false;
    };
    go-branded-id = {
      url = "git+ssh://git@github.com/LarsArtmann/go-branded-id?ref=master";
      flake = false;
    };
    go-filewatcher = {
      url = "git+ssh://git@github.com/LarsArtmann/go-filewatcher?ref=master";
      flake = false;
    };
    cmdguard = {
      url = "git+ssh://git@github.com/LarsArtmann/cmdguard?ref=master";
      flake = false;
    };

    # golangci-lint-auto-configure — auto-configure golangci-lint for Go projects
    golangci-lint-auto-configure = {
      url = "git+ssh://git@github.com/LarsArtmann/golangci-lint-auto-configure?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        goFindingSrc.follows = "go-finding";
      };
    };

    # mr-sync — CLI to keep ~/.mrconfig in sync with GitHub repos
    mr-sync = {
      url = "git+ssh://git@github.com/LarsArtmann/mr-sync?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        cmdguard.follows = "cmdguard";
        go-output.follows = "go-output";
        go-branded-id.follows = "go-branded-id";
      };
    };

    # hierarchical-errors — Error handling pattern analyzer for Go projects
    hierarchical-errors = {
      url = "git+ssh://git@github.com/LarsArtmann/hierarchical-errors?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        # go-finding: NOT followed — hierarchical-errors hasn't been updated for the new Confidence type API
        go-filewatcher.follows = "go-filewatcher";
        gogenfilter.follows = "gogenfilter";
      };
    };

    # BuildFlow — Zero-configuration build automation for Go projects
    buildflow = {
      url = "git+ssh://git@github.com/LarsArtmann/BuildFlow?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        cmdguard.follows = "cmdguard";
        go-finding.follows = "go-finding";
        go-output.follows = "go-output";
        go-branded-id.follows = "go-branded-id";
      };
    };

    # go-auto-upgrade — Automate Go library upgrades
    go-auto-upgrade = {
      url = "git+ssh://git@github.com/LarsArtmann/go-auto-upgrade?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        cmdguard.follows = "cmdguard";
        go-finding.follows = "go-finding";
        go-output.follows = "go-output";
        go-branded-id.follows = "go-branded-id";
      };
    };

    # go-structure-linter — Go project structure validator
    go-structure-linter = {
      url = "git+ssh://git@github.com/LarsArtmann/go-structure-linter?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-finding.follows = "go-finding";
        go-output.follows = "go-output";
        gogenfilter.follows = "gogenfilter";
        go-branded-id.follows = "go-branded-id";
      };
    };

    # branching-flow — Error context preservation analyzer
    branching-flow = {
      url = "git+ssh://git@github.com/LarsArtmann/branching-flow?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        go-finding.follows = "go-finding";
        go-output.follows = "go-output";
      };
    };

    # art-dupl — Code duplication detector
    art-dupl = {
      url = "git+ssh://git@github.com/LarsArtmann/art-dupl?ref=fork";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.gogenfilter.follows = "gogenfilter";
    };

    # projects-management-automation — CLI for managing multiple projects with workflow automation
    projects-management-automation = {
      url = "git+ssh://git@github.com/LarsArtmann/projects-management-automation?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        cmdguard.follows = "cmdguard";
        go-output.follows = "go-output";
        go-branded-id.follows = "go-branded-id";
        go-filewatcher.follows = "go-filewatcher";
        gogenfilter.follows = "gogenfilter";
      };
    };
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    home-manager,
    nix-darwin,
    nix-homebrew,
    homebrew-bundle,
    homebrew-cask,
    niri,
    otel-tui,
    nix-amd-npu,
    nix-ssh-config,
    nixos-hardware,
    niri-session-manager,
    sops-nix,
    silent-sddm,
    signoz-src,
    signoz-collector-src,
    crush-config,
    helium,
    hermes-agent,
    nur,
    treefmt-full-flake,
    wallpapers-src,
    ...
  }: let
    overlays = import ./overlays inputs;
    inherit (overlays) sharedOverlays linuxOnlyOverlays disableTests pythonTest;

    # Service module paths — single source of truth for flake-parts imports AND nixosConfigurations
    # Each entry is { path = ./modules/nixos/services/<name>.nix; module = "<nixosModule-name>"; }
    serviceModules = [
      {
        path = ./modules/nixos/services/authelia.nix;
        module = "authelia";
      }
      {
        path = ./modules/nixos/services/caddy.nix;
        module = "caddy";
      }
      {
        path = ./modules/nixos/services/default.nix;
        module = "default-services";
      }
      {
        path = ./modules/nixos/services/forgejo.nix;
        module = "forgejo";
      }
      {
        path = ./modules/nixos/services/forgejo-repos.nix;
        module = "forgejo-repos";
      }
      {
        path = ./modules/nixos/services/homepage.nix;
        module = "homepage";
      }
      {
        path = ./modules/nixos/services/immich.nix;
        module = "immich";
      }
      {
        path = ./modules/nixos/services/photomap.nix;
        module = "photomap";
      }
      {
        path = ./modules/nixos/services/sops.nix;
        module = "sops";
      }
      {
        path = ./modules/nixos/services/signoz.nix;
        module = "signoz";
      }
      {
        path = ./modules/nixos/services/twenty.nix;
        module = "twenty";
      }
      {
        path = ./modules/nixos/services/taskchampion.nix;
        module = "taskchampion";
      }
      {
        path = ./modules/nixos/services/voice-agents.nix;
        module = "voice-agents";
      }
      {
        path = ./modules/nixos/services/hermes.nix;
        module = "hermes";
      }
      {
        path = ./modules/nixos/services/minecraft.nix;
        module = "minecraft";
      }
      {
        path = ./modules/nixos/services/monitor365.nix;
        module = "monitor365";
      }
      {
        path = ./modules/nixos/services/dns-blocker.nix;
        module = "dns-blocker";
      }
      {
        path = ./modules/nixos/services/dns-failover.nix;
        module = "dns-failover";
      }
      {
        path = ./modules/nixos/services/display-manager.nix;
        module = "display-manager";
      }
      {
        path = ./modules/nixos/services/audio.nix;
        module = "audio";
      }
      {
        path = ./modules/nixos/services/niri-config.nix;
        module = "niri-config";
      }
      {
        path = ./modules/nixos/services/security-hardening.nix;
        module = "security-hardening";
      }
      {
        path = ./modules/nixos/services/ai-models.nix;
        module = "ai-models";
      }
      {
        path = ./modules/nixos/services/ai-stack.nix;
        module = "ai-stack";
      }
      {
        path = ./modules/nixos/services/multi-wm.nix;
        module = "multi-wm";
      }
      {
        path = ./modules/nixos/services/browser-policies.nix;
        module = "browser-policies";
      }
      {
        path = ./modules/nixos/services/steam.nix;
        module = "steam";
      }
      {
        path = ./modules/nixos/services/file-and-image-renamer.nix;
        module = "file-and-image-renamer";
      }
      {
        path = ./modules/nixos/services/disk-monitor.nix;
        module = "disk-monitor";
      }
      {
        path = ./modules/nixos/services/manifest.nix;
        module = "manifest";
      }
      {
        path = ./modules/nixos/services/gatus-config.nix;
        module = "gatus-config";
      }
      {
        path = ./modules/nixos/services/openseo.nix;
        module = "openseo";
      }
      {
        path = ./modules/nixos/services/dual-wan.nix;
        module = "dual-wan";
      }
      {
        path = ./modules/nixos/services/nvme-health-monitor.nix;
        module = "nvme-health-monitor";
      }
    ];

    serviceModulePaths = map (sm: sm.path) serviceModules;

    # Shared Home Manager configuration — only user/home file path differs per system
    sharedHomeManagerConfig = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      overwriteBackup = true;
    };

    # Shared theme (Catppuccin Mocha palette)
    theme = import ./platforms/common/theme.nix;

    # Shared extraSpecialArgs for Home Manager — available in all platform home.nix files
    sharedHomeManagerSpecialArgs = {
      inherit nix-ssh-config;
      inherit (theme) colorScheme;
    };
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["aarch64-darwin" "x86_64-linux"];

      # Import service modules — registered as flake-parts modules (inputs.self.nixosModules.*)
      imports = serviceModulePaths;

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
            ++ [disableTests]
            ++ lib.optionals (lib.hasSuffix "-linux" system) linuxOnlyOverlays;
        };

        # Use treefmt-full-flake's formatter which includes alejandra in PATH
        formatter = treefmt-full-flake.formatter.${system};

        packages =
          {
            inherit
              (pkgs)
              aw-watcher-utilization
              govalid
              jscpd
              sqlc
              todo-list-ai
              # library-policy — disabled: go.mod local replace breaks Nix sandbox
              golangci-lint-auto-configure
              mr-sync
              hierarchical-errors
              # buildflow — disabled: upstream compilation error
              go-auto-upgrade
              # go-structure-linter — disabled: inconsistent vendoring
              branching-flow
              art-dupl
              # projects-management-automation — disabled: missing branching-flow/pkg/stats
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
              statix check -o errfmt . 2>&1 | grep -v ':E:0:' | tee $out || true
              if statix check -o errfmt . 2>&1 | grep -v ':E:0:' | grep -q '.'; then
                exit 1
              fi
              exit 0
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
              program = "${pkgs.writeShellScriptBin "deploy" (builtins.readFile ./scripts/deploy.sh)}/bin/deploy";
              meta.description = "Deploy NixOS config to evo-x2 via nh with post-deploy checks";
            };
            validate = {
              type = "app";
              program = "${pkgs.writeShellScriptBin "validate" (builtins.readFile ./scripts/validate.sh)}/bin/validate";
              meta.description = "Validate flake without building";
            };
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            dns-diagnostics = {
              type = "app";
              program = "${pkgs.writeShellScriptBin "dns-diagnostics" (builtins.readFile ./scripts/dns-diagnostics.sh)}/bin/dns-diagnostics";
              meta.description = "Run DNS stack diagnostics (resolution, blocking, stats)";
            };
          };
      };

      # System configurations (maintain backward compatibility)
      flake = {
        lib = import ./lib {inherit (nixpkgs) lib;};

        darwinConfigurations."Lars-MacBook-Air" = nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit (inputs.self) inputs;
            inherit nixpkgs;
            inherit helium;
            inherit nur;
          };
          modules = [
            {
              nixpkgs = {
                hostPlatform = "aarch64-darwin";
                config.allowUnfree = true;
                overlays = sharedOverlays;
              };
              # otel-tui is Linux-only (40+ min from-source build on macOS, disk-hungry)
              _module.args.otel-tui = null;
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
            inherit (inputs) nur;
            inherit niri;
            inherit otel-tui;
            inherit nix-amd-npu;
            inherit nix-ssh-config;
          };
          modules =
            [
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
                    ++ [pythonTest];
                };
                system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
              }
              home-manager.nixosModules.home-manager
              inputs.nur.modules.nixos.default

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
            ]
            ++ (map (sm: inputs.self.nixosModules.${sm.module}) serviceModules)
            ++ [
              inputs.nix-ssh-config.nixosModules.ssh
              inputs.niri-session-manager.nixosModules.niri-session-manager
              inputs.emeet-pixyd.nixosModules.default
              ./platforms/nixos/system/configuration.nix
            ];
        };

        # Raspberry Pi 3 — DNS cluster backup node
        nixosConfigurations."rpi3-dns" = nixpkgs.lib.nixosSystem {
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
                overlays =
                  [inputs.nur.overlays.default]
                  ++ linuxOnlyOverlays;
              };
            }
            home-manager.nixosModules.home-manager
            inputs.nur.modules.nixos.default
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
