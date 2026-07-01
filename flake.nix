{
  description = "Lars nix-darwin + NixOS system flake - Modular Architecture with flake-parts";

  nixConfig = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
    warn-dirty = false;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
      url = "github:SigNoz/signoz/v0.127.1";
      flake = false;
    };
    signoz-collector-src = {
      url = "github:SigNoz/signoz-otel-collector/v0.144.5";
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
      url = "github:NousResearch/hermes-agent/v2026.6.5";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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
    };

    # library-policy — Banned/vulnerable library detector for Go projects
    library-policy = {
      url = "git+ssh://git@github.com/LarsArtmann/library-policy?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
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

    # crush-daily — Daily AI-powered insights from Crush development databases
    crush-daily = {
      url = "git+ssh://git@github.com/LarsArtmann/crush-daily?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # Shared Go libraries — single source of truth for all Go tool repos.
    # IMPORTANT: These are `flake = false` tarballs. They must NOT be
    # `follows`-overridden into Go tool flakes — the override changes vendored
    # Go module content, breaking vendorHash (fixed-output hash mismatch).
    # Only build-infra inputs (nixpkgs, go-nix-helpers, flake-parts,
    # treefmt-nix, systems) may be followed into Go tool flakes.
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
    go-error-family = {
      url = "git+ssh://git@github.com/LarsArtmann/go-error-family?ref=master";
      flake = false;
    };
    cmdguard = {
      url = "git+ssh://git@github.com/LarsArtmann/cmdguard?ref=master";
      flake = false;
    };
    go-nix-helpers = {
      url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
      flake = false;
    };

    # golangci-lint-auto-configure — auto-configure golangci-lint for Go projects
    golangci-lint-auto-configure = {
      url = "git+ssh://git@github.com/LarsArtmann/golangci-lint-auto-configure?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # mr-sync — CLI to keep ~/.mrconfig in sync with GitHub repos
    # NOTE: Go-module replace deps (go-output, go-branded-id, cmdguard) are NOT
    # followed — overriding them changes vendored content and breaks vendorHash.
    # Only build-infra inputs are followed.
    mr-sync = {
      url = "git+ssh://git@github.com/LarsArtmann/mr-sync?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # hierarchical-errors — Error handling pattern analyzer for Go projects
    hierarchical-errors = {
      url = "git+ssh://git@github.com/LarsArtmann/hierarchical-errors?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # go-finding: NOT followed — hierarchical-errors hasn't been updated for the new Confidence type API
      };
    };

    # BuildFlow — Zero-configuration build automation for Go projects
    buildflow = {
      url = "git+ssh://git@github.com/LarsArtmann/BuildFlow?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # go-auto-upgrade — Automate Go library upgrades
    go-auto-upgrade = {
      url = "git+ssh://git@github.com/LarsArtmann/go-auto-upgrade?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # go-structure-linter — Go project structure validator
    go-structure-linter = {
      url = "git+ssh://git@github.com/LarsArtmann/go-structure-linter?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # branching-flow — Error context preservation analyzer
    branching-flow = {
      url = "git+ssh://git@github.com/LarsArtmann/branching-flow?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # art-dupl — Code duplication detector
    art-dupl = {
      url = "git+ssh://git@github.com/LarsArtmann/art-dupl?ref=fork";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # projects-management-automation — CLI for managing multiple projects with workflow automation
    projects-management-automation = {
      url = "git+ssh://git@github.com/LarsArtmann/projects-management-automation?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # project-meta — Per-project metadata management CLI
    project-meta = {
      url = "git+ssh://git@github.com/LarsArtmann/project-meta?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # Overview — local project dashboard (discovers and browses git repos via web UI)
    overview = {
      url = "git+ssh://git@github.com/LarsArtmann/overview?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # DiscordSync — Continuous Discord backup with Turso cloud sync
    discordsync = {
      url = "git+ssh://git@github.com/LarsArtmann/DiscordSync?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };
    # md-go-validator — Validate code blocks embedded in Markdown/MDX docs
    md-go-validator = {
      url = "git+ssh://git@github.com/LarsArtmann/md-go-validator?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # DankMaterialShell — Quickshell-based desktop shell (Niri + Hyprland)
    # Brings quickshell transitively — no separate quickshell input needed
    dankMaterialShell = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    nix-ssh-config,
    treefmt-full-flake,
    ...
  }: let
    lib = nixpkgs.lib;
    overlays = import ./overlays inputs;
    inherit
      (overlays)
      sharedOverlays
      linuxOnlyOverlays
      disableTests
      pythonTest
      ;

    # Auto-discover NixOS modules from modules/nixos/{services,desktop}/.
    # Convention: filename (minus .nix) IS the module name and MUST be unique
    # across all scanned directories (it becomes flake.nixosModules.<name>).
    # Non-module files must start with _ (e.g., _signoz-alerts.nix).
    # Non-.nix files and directories are ignored automatically.
    moduleDirs = [
      ./modules/nixos/services
      ./modules/nixos/desktop
    ];
    discoveredModules =
      lib.concatMap (
        dir: let
          files = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n && !(lib.hasPrefix "_" n)) (
            builtins.readDir dir
          );
        in
          lib.mapAttrsToList (file: _: {
            path = dir + "/${file}";
            module = lib.removeSuffix ".nix" file;
          })
          files
      )
      moduleDirs;

    discoveredModulePaths = map (m: m.path) discoveredModules;

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

    # LarsArtmann Go tool packages — single source of truth in lib/lars-packages.nix.
    # Referenced by perSystem.packages (for nix build .#X) and passed to base.nix
    # via specialArgs (for environment.systemPackages).
    mkLarsPackages = import ./lib/lars-packages.nix {inherit lib inputs;};
  in
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      # Import service modules — registered as flake-parts modules (inputs.self.nixosModules.*)
      imports = discoveredModulePaths;

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
          config.allowBroken = false; # # <-- THIS MUST ALWAYS BE FALSE!
          overlays =
            sharedOverlays
            ++ [disableTests]
            ++ lib.optionals (lib.hasSuffix "-linux" system) linuxOnlyOverlays;
        };

        # Use treefmt-full-flake's formatter which includes alejandra in PATH
        formatter = treefmt-full-flake.formatter.${system};

        packages =
          (mkLarsPackages system)
          // {
            inherit
              (pkgs)
              aw-watcher-utilization
              govalid
              jscpd
              sqlc
              ;
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            inherit
              (pkgs)
              openaudible
              dnsblockd
              monitor365
              netwatch
              emeet-pixyd
              file-and-image-renamer
              crush-daily
              ;
          };

        # Development shells for different program categories
        devShells = {
          default = pkgs.mkShell {
            BUILDFLOW_EXCLUDE_PATTERNS = "assets/avatar.png";
            packages = with pkgs; [
              git
              nixfmt
              alejandra
              treefmt
              deadnix
              shellcheck
              statix
              gitleaks
              jq
              sqlc
            ];
          };
          # Quickshell development — hot-reload QML shell development
          quickshell = pkgs.mkShell {
            packages = [
              inputs.dankMaterialShell.packages.${system}.default
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qttools # provides qmlls (QML LSP)
            ];
          };
        };

        checks =
          {
            statix =
              pkgs.runCommand "statix-check"
              {
                nativeBuildInputs = [pkgs.statix];
              }
              ''
                cd ${./.}
                statix check -o errfmt . 2>&1 | grep -v ':E:0:' | tee $out || true
                if statix check -o errfmt . 2>&1 | grep -v ':E:0:' | grep -q '.'; then
                  exit 1
                fi
                exit 0
              '';

            deadnix =
              pkgs.runCommand "deadnix-check"
              {
                nativeBuildInputs = [pkgs.deadnix];
              }
              ''
                cd ${./.}
                deadnix --fail --no-lambda-pattern-names . 2>&1 | tee $out
              '';
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux (
            import ./tests {
              inherit
                pkgs
                lib
                nixpkgs
                system
                ;
            }
          );

        apps = let
          mkApp = name: description: runtimeInputs: scriptPath: {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                inherit name runtimeInputs;
                text = builtins.readFile scriptPath;
              }
            }/bin/${name}";
            meta.description = description;
          };
        in
          {
            deploy =
              mkApp "deploy" "Deploy NixOS config to evo-x2 via nh with post-deploy checks" [
                pkgs.nh
                pkgs.systemd
              ]
              ./scripts/deploy.sh;
            validate = mkApp "validate" "Validate flake without building" [pkgs.nix] ./scripts/validate.sh;
            pre-deploy-check =
              mkApp "pre-deploy-check" "Pre-deploy validation: catches boot-breaking issues before switch"
              [pkgs.nix pkgs.jq pkgs.systemd]
              ./scripts/pre-deploy-check.sh;
            pocket-id-login-code =
              mkApp "pocket-id-login-code" "Generate a one-time Pocket ID login code for a new device"
              [pkgs.curl pkgs.jq]
              ./scripts/pocket-id-login-code.sh;
          }
          // lib.optionalAttrs pkgs.stdenv.isLinux {
            dns-diagnostics =
              mkApp "dns-diagnostics" "Run DNS stack diagnostics (resolution, blocking, stats)"
              [pkgs.systemd pkgs.dnsutils pkgs.curl]
              ./scripts/dns-diagnostics.sh;
            dms-restart = {
              type = "app";
              program = "${
                pkgs.writeShellApplication {
                  name = "dms-restart";
                  runtimeInputs = [pkgs.systemd];
                  text = "systemctl --user restart dms.service && echo 'DMS restarted'";
                }
              }/bin/dms-restart";
              meta.description = "Restart DankMaterialShell desktop shell";
            };
            dms-locks = {
              type = "app";
              program = "${
                pkgs.writeShellApplication {
                  name = "dms-locks";
                  text = "dms ipc lock lock 2>/dev/null || exec swaylock";
                }
              }/bin/dms-locks";
              meta.description = "Lock screen via DMS IPC (fallback: swaylock)";
            };
            dms-wallpaper-next = {
              type = "app";
              program = "${
                pkgs.writeShellApplication {
                  name = "dms-wallpaper-next";
                  text = "dms ipc call wallpaper next";
                }
              }/bin/dms-wallpaper-next";
              meta.description = "Cycle to next wallpaper via DMS IPC";
            };
          };
      };

      # System configurations — assembled in systems/*.nix (thin host files)
      flake = {
        lib = import ./lib {inherit (nixpkgs) lib;};

        darwinConfigurations."Lars-MacBook-Air" = import ./systems/darwin.nix {
          inherit
            inputs
            mkLarsPackages
            sharedOverlays
            sharedHomeManagerConfig
            sharedHomeManagerSpecialArgs
            ;
        };

        nixosConfigurations."evo-x2" = import ./systems/evo-x2.nix {
          inherit
            inputs
            mkLarsPackages
            sharedOverlays
            linuxOnlyOverlays
            pythonTest
            discoveredModules
            sharedHomeManagerConfig
            sharedHomeManagerSpecialArgs
            ;
        };

        nixosConfigurations."rpi3-dns" = import ./systems/rpi3-dns.nix {
          inherit
            inputs
            linuxOnlyOverlays
            sharedHomeManagerConfig
            sharedHomeManagerSpecialArgs
            ;
        };
      };
    };
}
