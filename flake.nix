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
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Single flake-utils source — all inputs follow this to avoid 10+ duplicate instances
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    # Single nix-systems source — flake-utils and niri-session-manager follow this
    systems.url = "github:nix-systems/default";

    # Single treefmt-nix source — dnsblockd, niri-session-manager follow this
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
      url = "github:SigNoz/signoz";
      flake = false;
    };
    signoz-collector-src = {
      url = "github:SigNoz/signoz-otel-collector";
      flake = false;
    };

    nix-ssh-config = {
      url = "github:LarsArtmann/nix-ssh-config";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Crush AI Agent Configuration — global AI assistant settings
    # This ensures AGENTS.md and all references are synced across machines
    crush-config = {
      url = "github:LarsArtmann/crush-config?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # dnsblockd — DNS blocklist service with block pages and blocklist processing
    dnsblockd = {
      url = "github:LarsArtmann/dnsblockd?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    wallpapers-src = {
      url = "github:LarsArtmann/wallpapers?ref=master";
      flake = false;
    };

    # Hermes AI Agent — Discord/gateway agent platform.
    # RE-VERIFY ON BUMP: the projects-access wiring depends on upstream env
    # behavior — TERMINAL_CWD surviving as the terminal default unless
    # config.yaml sets terminal.cwd (gateway/run.py resolve_placeholder_terminal_cwd,
    # cwd_placeholder.py) and HERMES_WRITE_SAFE_ROOT confining write_file/patch.
    # Both verified against the source 2026-08-21 @ 63c6d9a4 (v0.20.4):
    # symbols intact; upstream commit 31561e37 additionally BLESSES the
    # env bridge (the deprecation warning now reads the .env FILE — env
    # TERMINAL_CWD is "legitimate" per its docstring). A bump that changes
    # either silently changes agent workspace/write semantics
    # (tests/test-hermes.nix covers the env wiring, not the upstream Python
    # behavior).
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # monitor365 — Device monitoring agent (Rust)
    monitor365 = {
      url = "github:LarsArtmann/monitor365?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # PapDashboard — event-sourced alert hub with NPU insight enricher (Go)
    papdashboard = {
      url = "github:LarsArtmann/PapDashboard?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # InboxClean — Gmail AI assistant: web dashboard + incremental sync (Go)
    inboxclean = {
      url = "github:LarsArtmann/InboxClean?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS hardware profiles (Raspberry Pi, etc.)
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # EMEET PIXY webcam auto-activation daemon
    emeet-pixyd = {
      url = "github:LarsArtmann/emeet-pixyd?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Niri session manager — automatic window save/restore
    niri-session-manager = {
      url = "github:LarsArtmann/niri-session-manager";
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
      url = "github:LarsArtmann/todo-list-ai?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # library-policy — Banned/vulnerable library detector for Go projects
    library-policy = {
      url = "github:LarsArtmann/library-policy?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
      };
    };

    # file-and-image-renamer — AI-powered screenshot renaming tool
    file-and-image-renamer = {
      url = "github:LarsArtmann/file-and-image-renamer?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      # Without this, the input locks its own go-nix-helpers via git+ssh:
      # (git insteadOf pollution) — divergent narHash vs the top-level
      # github: fetch, the "NAR hash mismatch" daemon-cache trap (AGENTS.md).
      inputs.go-nix-helpers.follows = "go-nix-helpers";
    };

    # crush-daily — Daily AI-powered insights from Crush development databases
    crush-daily = {
      url = "github:LarsArtmann/crush-daily?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # bank-sync — Wise/Qonto bank transaction sync into SQLite + dashboard
    bank-sync = {
      url = "github:LarsArtmann/bank-sync?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # go-nix-helpers is deliberately NOT followed: mkPreparedSource from
        # a different helper version than the one bank-sync's vendorHash was
        # validated against produces a different prepared source (replace
        # directives) and therefore a different vendor tree — FOD hash
        # mismatch (2026-08-18: followed eca72e10 vs pinned 064a269e
        # produced 4BsvdHH… vs the expected gRJEQt…). bank-sync must consume
        # its own locked helper version for reproducible builds.
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # qmd — on-device hybrid search (BM25 + vector embeddings + LLM rerank)
    # for markdown and code; global CLI + MCP server (stdio/HTTP) for Crush.
    # nixpkgs is deliberately NOT followed: upstream's nodeModules FOD hash
    # was validated with upstream's own nixpkgs bun — a different bun version
    # can install a different node_modules tree and break the FOD hash.
    # Update by bumping the tag (and re-verifying the CLI + `qmd mcp`).
    qmd = {
      url = "github:tobi/qmd/v2.8.3";
    };

    # Shared Go libraries — single source of truth for all Go tool repos.
    # IMPORTANT: These are `flake = false` tarballs. They must NOT be
    # `follows`-overridden into Go tool flakes — the override changes vendored
    # Go module content, breaking vendorHash (fixed-output hash mismatch).
    # Only build-infra inputs (nixpkgs, go-nix-helpers, flake-parts,
    # treefmt-nix, systems) may be followed into Go tool flakes.
    go-finding = {
      url = "github:LarsArtmann/go-finding?ref=master";
      flake = false;
    };
    go-output = {
      url = "github:LarsArtmann/go-output?ref=master";
      flake = false;
    };
    gogenfilter = {
      url = "github:LarsArtmann/gogenfilter?ref=master";
      flake = false;
    };
    go-branded-id = {
      url = "github:LarsArtmann/go-branded-id?ref=master";
      flake = false;
    };
    go-filewatcher = {
      url = "github:LarsArtmann/go-filewatcher?ref=master";
      flake = false;
    };
    go-error-family = {
      url = "github:LarsArtmann/go-error-family?ref=master";
      flake = false;
    };
    cmdguard = {
      url = "github:LarsArtmann/cmdguard?ref=master";
      flake = false;
    };
    go-nix-helpers = {
      url = "github:LarsArtmann/go-nix-helpers?ref=master";
      # project-meta consumes go-nix-helpers.flakeModules.go-standard, so this
      # must remain a flake input even though Go libraries are the primary use.
    };

    # golangci-lint-auto-configure — auto-configure golangci-lint for Go projects
    golangci-lint-auto-configure = {
      url = "github:LarsArtmann/golangci-lint-auto-configure?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # mr-sync — CLI to keep ~/.mrconfig in sync with GitHub repos
    # NOTE: Go-module replace deps (go-output, go-branded-id, cmdguard) are NOT
    # followed — overriding them changes vendored content and breaks vendorHash.
    # Only build-infra inputs are followed.
    mr-sync = {
      url = "github:LarsArtmann/mr-sync?ref=master";
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
      url = "github:LarsArtmann/hierarchical-errors?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        # go-finding: NOT followed — hierarchical-errors hasn't been updated for the new Confidence type API
      };
    };

    # BuildFlow — Zero-configuration build automation for Go projects
    buildflow = {
      url = "github:LarsArtmann/BuildFlow?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # go-auto-upgrade — Automate Go library upgrades
    go-auto-upgrade = {
      url = "github:LarsArtmann/go-auto-upgrade?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # go-structure-linter — Go project structure validator
    go-structure-linter = {
      url = "github:LarsArtmann/go-structure-linter?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # go-cqrs-lite — CQRS/Event-Sourcing library (provides cqrs-lint CLI)
    # Go dep inputs (go-finding, go-output, etc.) are NOT followed — overriding
    # flake=false tarballs changes vendored content and breaks vendorHash.
    go-cqrs-lite = {
      url = "git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # branching-flow — Error context preservation analyzer
    branching-flow = {
      url = "github:LarsArtmann/branching-flow?ref=master";
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
      url = "github:LarsArtmann/art-dupl?ref=fork";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # art-dupl raw source — consumed transitively by dnsblockd (follows this input)
    art-dupl-src = {
      url = "github:LarsArtmann/art-dupl";
      flake = false;
    };

    # go-commit — Conventional commit helper (consumed by PMA via mkPreparedSource).
    go-commit = {
      url = "github:LarsArtmann/go-commit?ref=master";
      flake = false;
    };

    # projects-management-automation — CLI for managing multiple projects with workflow automation
    # nixpkgs / go-commit / go-nix-helpers deliberately NOT followed
    # (DiscordSync + bank-sync + qmd precedents): PMA's vendorHash was
    # validated against ITS own lock — a different mkPreparedSource (helper
    # version), go-commit rev, or nixpkgs go changes the vendored module set
    # and breaks the go-modules FOD hash (hit live 2026-08-27: go-commit
    # master moved past PMA's own pin under the old follows wiring).
    # PMA must consume its own locked build environment.
    projects-management-automation = {
      url = "github:LarsArtmann/projects-management-automation?ref=master";
      inputs = {
        flake-parts.follows = "flake-parts";
      };
    };

    # project-meta — Per-project metadata management CLI
    project-meta = {
      url = "github:LarsArtmann/project-meta?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
      };
    };

    # Overview — local project dashboard (discovers and browses git repos via web UI)
    overview = {
      url = "github:LarsArtmann/overview?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # DiscordSync — Continuous Discord backup with Turso cloud sync
    # Rev-pinned (2026-08-25) at 2862b613 = upstream aa56b582 + two commits
    # on branch nix/aa56b582-vendorhash (vendorHash correction + the
    # projection_dlq_legacy_unchanged growth flag the gatus check asserts).
    # aa56b582 is the LAST tree before upstream's Go toolchain floor bump to
    # 1.26.6 (ca9c470c, 2026-08-22) — nixpkgs has 1.26.5 + GOTOOLCHAIN=local,
    # so master's go-modules FOD fails loudly (same class as
    # file-and-image-renamer). When nixpkgs go >= 1.26.6: rebase the branch
    # onto master (or cherry-pick the two commits), then switch back to
    # ?ref=master and update-input.
    discordsync = {
      url = "github:LarsArtmann/DiscordSync/2862b613";
      inputs = {
        # go-nix-helpers AND nixpkgs deliberately NOT followed (bank-sync +
        # qmd precedents): upstream's vendorHash was validated against ITS
        # own lock — a different mkPreparedSource (helper version) or a
        # different go (nixpkgs) changes the vendored module set and breaks
        # the go-modules FOD hash (2026-08-25: both mismatch classes hit
        # live before this pin; got-hash drifted with each follows change).
        # discordsync must consume its own locked build environment.
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # vision-review-agent — visionreviewd, the event-sourced UI review daemon
    vision-review-agent = {
      url = "github:LarsArtmann/vision-review-agent?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        systems.follows = "systems";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    # md-go-validator — Validate code blocks embedded in Markdown/MDX docs
    md-go-validator = {
      url = "github:LarsArtmann/md-go-validator?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # browser-history — Browser history intelligence server (CQRS/ES, WebAuthn)
    browser-history = {
      url = "github:LarsArtmann/browser-history?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # CV — resume generator + career pipeline server (PRIVATE repo: git+ssh).
    # No follows on purpose (discordsync precedent): CV's vendorHash was
    # validated against its own locked nixpkgs/go-nix-helpers — and CV builds
    # its own go 1.26.6 from the go.dev tarball (nixpkgs has 1.26.5 while the
    # go.mod floor is 1.26.6), so it must consume its own build environment.
    cv = {
      url = "git+ssh://git@github.com/LarsArtmann/CV?ref=master";
    };

    # DankMaterialShell — Quickshell-based desktop shell (Niri + Hyprland)
    # Brings quickshell transitively — no separate quickshell input needed
    dankMaterialShell = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # herdr — Agent multiplexer for the terminal (runs multiple AI coding agents with real panes)
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # go-humanize-linter — AST linter detecting hand-rolled reimplementations of go-humanize
    # Go dep inputs (go-finding, go-linter-sdk, go-error-family) are NOT followed —
    # they are flake=false git+ssh inputs fetched by the upstream flake itself.
    go-humanize-linter = {
      url = "github:LarsArtmann/go-humanize-linter?ref=main";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
      };
    };
  };

  outputs = inputs @ {
    flake-parts,
    nixpkgs,
    nix-ssh-config,
    treefmt-full-flake,
    ...
  }: let
    inherit (nixpkgs) lib;
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

    # Eval-time guard: the nix global registry rewrites github:NixOS/nixpkgs/nixos-unstable
    # to a tarball URL. The tarball pointer can be stale, silently downgrading nixpkgs
    # by months. This assertion fails nix flake check / nix eval if the regression recurs.
    # Uses builtins.seq to force eager evaluation (Nix is lazy — an unreferenced let
    # binding would never fire).
    lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);
    nixpkgsLockType = lockFile.nodes.nixpkgs.original.type or "unknown";
    nixpkgsTarballGuard = assert nixpkgsLockType
    == "github"
    || throw ''
      nixpkgs flake.lock regression: original type is "${nixpkgsLockType}", expected "github".
      The nix global registry rewrote nixpkgs to a tarball which may be stale.
      Fix: manually edit flake.lock nodes.nixpkgs.original to type "github".
    ''; true;
  in
    builtins.seq nixpkgsTarballGuard flake-parts.lib.mkFlake {inherit inputs;} {
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
              systemd-timer-monitor
              ;
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            inherit
              (pkgs)
              openaudible
              openseo
              dnsblockd
              monitor365
              netwatch
              systemd-graph
              systemd-graph-webui
              emeet-pixyd
              file-and-image-renamer
              crush-daily
              fastflowlm
              ;
            freebsd-zfs-vm = import ./pkgs/freebsd-zfs-vm.nix {inherit pkgs;};
          };

        # Development shells for different program categories
        devShells = {
          default = pkgs.mkShellNoCC {
            BUILDFLOW_EXCLUDE_PATTERNS = "assets/avatar.png";
            packages = with pkgs;
              [
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
              ]
              ++ [
                (mkLarsPackages system).buildflow
              ];
          };
          # Quickshell development — hot-reload QML shell development
          quickshell = pkgs.mkShellNoCC {
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

            # Gatus pat() uses GLOB, not regex. Chars ? and + have
            # different meanings in glob (? = single-char wildcard) vs
            # regex (? = optional quantifier), causing silent false
            # negatives in health checks. { is allowed — Prometheus
            # labels use {label="value"} syntax.
            gatus-pattern-lint = pkgs.runCommand "gatus-pattern-lint" {} ''
              if grep -v '^[[:space:]]*#' ${./modules/nixos/services/gatus-config.nix} | grep -nE 'pat\(.*[?+]'; then
                echo "FAIL: Gatus pat() patterns contain regex-only chars (? or +)."
                echo "Gatus pat() uses GLOB, not regex."
                echo "  ? = single-char wildcard (NOT optional quantifier)"
                echo "  + = literal character (NOT one-or-more quantifier)"
                exit 1
              fi
              # pat() globs the WHOLE /metrics body, HELP comments included: an
              # asserted-1 condition pat(*<metric> 1*) silently matches the metric's
              # own "# HELP <metric> 1 if ..." comment and stays green at ANY value
              # (phantom green, live on buildcache/pool/lan-nic/signoz 2026-08-22).
              # Asserted-0 conditions are unaffected ("0 otherwise" never contains
              # "<metric> 0" as a substring). Use the anchored form instead.
              if grep -v '^[[:space:]]*#' ${./modules/nixos/services/gatus-config.nix} | grep -nE 'pat\(\*[a-z_0-9]+ 1\*\)'; then
                echo "FAIL: bare pat(*<metric> 1*) conditions match the metric's own HELP comment."
                echo "Use:  [BODY] != pat(*<metric> 0\\n*)  +  [BODY] == pat(*\\n<metric> *)"
                echo "NOTE: the \\n must reach gatus as a REAL newline (nix \"\\n\" string) — a literal"
                echo "backslash-n is filepath.Match's ESCAPE for a literal 'n' and can never match"
                echo "(2026-08-22 bug: 7 deployed checks permanently red from exactly this)."
                echo "Incident: 2026-08-22 DAS USB drop (buildcache/pool stayed green through a live outage) — docs/status/2026-08-22_01-46_das-usb-drop-gatus-phantom-green-fix.md"
                exit 1
              fi
              # Escape-sequence trap: in a double-quoted nix string the source
              # bytes backslash-backslash-n evaluate to a LITERAL backslash + 'n'.
              # gatus 5.36.0 pattern.Match delegates to filepath.Match, which
              # treats '\' as an escape for the next character — so the glob
              # "\\n" matches only the letter 'n' and the condition can NEVER
              # match a real /metrics body (permanently red, zero diagnostics;
              # 7 checks were live-broken by this on 2026-08-22). The anchored
              # form needs the REAL newline: single-backslash \n in the nix
              # source (gatus-config.nix anchored conditions are the reference).
              if grep -v '^[[:space:]]*#' ${./modules/nixos/services/gatus-config.nix} | grep -nE 'pat\(.*\\\\n'; then
                echo "FAIL: pat() contains a literal backslash-n (nix source \"\\\\n\")."
                echo "filepath.Match treats '\\' as an ESCAPE, so this glob matches only the letter 'n'"
                echo "and the condition can never match a real body. Write the newline as single-"
                echo "backslash \"\\n\" in the double-quoted nix string — see gatus-config.nix anchored forms."
                exit 1
              fi
              # HTTP method tokens are case-SENSITIVE end to end (RFC 9110):
              # gatus passes the configured method through verbatim and Go's
              # ServeMux matches method tokens case-sensitively — a lowercase
              # "post" 405s against a POST-registered route while an
              # unauthenticated 401 probe CANNOT catch it (auth middleware
              # runs before routing). Live incident: papdashboard /api/ingest
              # 405'd 1076× before a journal 200 proved the fix (2026-08-18).
              if grep -v '^[[:space:]]*#' ${./modules/nixos/services/gatus-config.nix} | grep -nE 'method = "[a-z]+"'; then
                echo "FAIL: lowercase HTTP method value in gatus-config.nix."
                echo "Method tokens are matched case-sensitively (RFC 9110 + Go ServeMux);"
                echo "'post' 405s against POST-registered routes and 401 probes cannot detect it."
                echo "Use uppercase: method = \"POST\"."
                exit 1
              fi
              touch $out
            '';

            # SigNoz alert rules (_signoz-alerts.nix) + dashboards query the
            # OTel-collector-backed metrics store, which has DIFFERENT label
            # and naming semantics than a plain Prometheus:
            #   1. The prometheus receiver stores the scrape job as the
            #      resource attribute service.name — NO series ever carries a
            #      `job` label, so any `job=` matcher is a permanent
            #      phantom-green (6 rules were silently dead for months;
            #      fixed 2026-08-27 — see
            #      docs/status/2026-08-27_15-50_signoz-phantom-alert-purge-6-dead-rules-fixed.md).
            #   2. Histogram/summary suffixes are stored DOTTED
            #      (`metric.sum`, not `metric_sum`) — the underscore form has
            #      zero series; query via {__name__="metric.suffix"}.
            #   3. `up{service_name=...}` goes STALE mid-outage (the labeled
            #      series disappears when the scrape target fails), so a bare
            #      selector never fires — wrap in count(...) or vector(0).
            #   4. Known-dead metric names (verified 0 series in the store).
            signoz-query-lint =
              let
                alerts = ./modules/nixos/services/_signoz-alerts.nix;
                dashboards = ./modules/nixos/services/dashboards;
                deadMetrics = [ "node_amdgpu_gpu_temp_celsius" ];
              in
              pkgs.runCommand "signoz-query-lint"
                {
                  # extensible blocklist of metrics verified to have 0 series;
                  # verify additions via
                  #   clickhouse-client --query "SELECT count() FROM signoz_metrics.distributed_time_series_v4 WHERE metric_name='X'"
                  metrics = toString deadMetrics;
                }
                ''
                  fail=0
                  # NOTE: stdenv setup.sh enables `shopt -s nullglob` — an
                  # unquoted `$strip` command-string variable would have its
                  # glob-bearing words (the quoted grep pattern) silently
                  # DELETED, turning every trap below phantom-green. Command
                  # indirection MUST use function definitions (quotes parse
                  # at definition time), never variable expansion.
                  scan() { # scan <label> <files...>
                    label="$1"; shift
                    for f in "$@"; do
                      case "$f" in
                        *.nix)
                          stream() { grep -v '^[[:space:]]*#' "$1"; }
                          ;;
                        *)
                          stream() { cat "$1"; }
                          ;;
                      esac

                      # 1. job= label matchers never match anything
                      if stream "$f" | grep -nE '\bjob[[:space:]]*=[[:space:]]*["~]' >lint_hits; then
                        echo "FAIL [$label] $f: job= label matcher — no series carries a job label."
                        echo "  The OTel prometheus receiver stores the scrape job as resource attr"
                        echo "  service.name. Use node_systemd_unit_state{name=\"X.service\",state=\"active\"}"
                        echo "  for liveness, or count(up{service_name=\"X\"}) or vector(0) for scrape health."
                        sed 's/^/    /' lint_hits
                        fail=1
                      fi

                      # 2. underscore histogram/summary suffixes are stored DOTTED
                      if stream "$f" | grep -nE '[a-z_0-9]+_(sum|count|bucket)\b' >lint_hits; then
                        echo "FAIL [$label] $f: underscore histogram suffix (metric_sum/_count/_bucket)."
                        echo "  SigNoz stores suffixes DOTTED: metric.sum, metric.count, metric.bucket."
                        echo "  The underscore form matches zero series (caddy/dns dashboards 2026-08-27)."
                        echo "  Query as {__name__=\"metric.suffix\"} instead."
                        sed 's/^/    /' lint_hits
                        fail=1
                      fi

                      # 3. up{service_name=...} goes STALE mid-outage without a vector(0) fallback
                      if stream "$f" | grep -nE 'up\{[^}]*service_name' | grep -vE '(or vector\(0\)|absent\()' >lint_hits; then
                        echo "FAIL [$label] $f: bare up{service_name=...} selector."
                        echo "  On scrape FAILURE the receiver emits a bare-label up=0 series and the"
                        echo "  labeled series goes stale — the selector returns nothing exactly when"
                        echo "  it should fire (dnsblockd :9090 wedge, 2026-08-27)."
                        echo "  Use: count(up{service_name=\"X\"}) or vector(0)"
                        sed 's/^/    /' lint_hits
                        fail=1
                      fi

                      # 4. known-dead metric names
                      for m in $metrics; do
                        if stream "$f" | grep -nE "\b$m\b" >lint_hits; then
                          echo "FAIL [$label] $f: dead metric '$m' (verified 0 series in the store)."
                          sed 's/^/    /' lint_hits
                          fail=1
                        fi
                      done
                    done
                    rm -f lint_hits
                    return 0
                  }

                  scan alerts ${alerts}
                  scan dashboards ${dashboards}/*.json

                  [ "$fail" -eq 0 ] || exit 1
                  touch $out
                '';

            # Recursive chown/chmod walks in modules that also configure
            # Bind*Paths: systemd builds the mount namespace BEFORE any
            # ExecStartPre, so a recursive ownership walk descends into the
            # bind (EROFS on read-only binds; cross-filesystem mutation on
            # writable ones). -xdev does NOT protect same-filesystem binds
            # (shared st_dev on one BTRFS subvol) — prune the exact path.
            # WARNING-only for now (live incident class: hermes 2026-08-20,
            # down 09:18-09:35); promote to exit 1 after one clean cycle.
            chown-vs-bind-audit = pkgs.runCommand "chown-vs-bind-audit" {} ''
              warn=0
              for f in $(grep -rlE 'Bind(ReadOnly|ReadWrite)?Paths' ${./modules}); do
                if grep -nE '(chown|chmod) -R' "$f" | grep -vE '^[0-9]+:[[:space:]]*#'; then
                  echo "WARN: $f: recursive chown/chmod -R in a module with Bind*Paths — use find with -prune on the bind target instead"
                  warn=1
                fi
                if grep -nE 'find .*(chown|chmod)' "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -vE -- '-prune|-xdev'; then
                  echo "WARN: $f: find chown/chmod walk without -prune/-xdev in a module with Bind*Paths"
                  warn=1
                fi
              done
              if [ "$warn" -ne 0 ]; then
                echo "WARNING (non-blocking): recursive ownership walks coexist with bind mounts — review the lines above"
              fi
              touch $out
            '';
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
            import ./tests {
              inherit
                pkgs
                lib
                system
                inputs
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
            fix-nixpkgs-lock =
              mkApp "fix-nixpkgs-lock"
              "Restore the flake.lock nixpkgs node to github type (one-command recovery from the tarball regression)"
              [pkgs.nix pkgs.jq]
              ./scripts/fix-nixpkgs-lock.sh;
            pre-deploy-check =
              mkApp "pre-deploy-check" "Pre-deploy validation: catches boot-breaking issues before switch"
              [pkgs.nix pkgs.jq pkgs.systemd]
              ./scripts/pre-deploy-check.sh;
            post-deploy-check =
              mkApp "post-deploy-check" "Post-deploy smoke test: verifies services are functional, not just alive"
              [
                pkgs.coreutils # date, wc, head, tr, sleep, id
                pkgs.curl
                pkgs.fish
                pkgs.glibc # getent
                pkgs.gnugrep
                pkgs.jq
                pkgs.nix
                pkgs.procps # pgrep
                pkgs.systemd # systemctl, journalctl
              ]
              ./scripts/post-deploy-check.sh;
            btrfs-inventory =
              mkApp "btrfs-inventory" "List all BTRFS subvolumes, snapshots, and mount points" [
                pkgs.btrfs-progs
                pkgs.util-linux
                pkgs.coreutils
                pkgs.findutils
              ]
              ./scripts/btrfs-subvolume-inventory.sh;
            migrate-buildcache =
              mkApp "migrate-buildcache"
              "One-time migration of build caches (Go/Rust/npm/pip/pnpm/playwright) to the USB SSD at /mnt/buildcache. Run BEFORE the first deploy of services.buildcache"
              [
                pkgs.coreutils # cut, du, find, tr, wc
                pkgs.e2fsprogs # e2label
                pkgs.findutils
                pkgs.gnugrep
                pkgs.rsync
                pkgs.trash-cli
                pkgs.util-linux # findmnt, mountpoint
              ]
              ./scripts/migrate-buildcache.sh;
            verify-io-tiers =
              mkApp "verify-io-tiers" "Verify BFQ I/O priority tiers are correctly applied" [
                pkgs.systemd
                pkgs.procps
              ]
              ./scripts/verify-io-tiers.sh;
            pocket-id-login-code =
              mkApp "pocket-id-login-code" "Generate a one-time Pocket ID login code for a new device"
              [pkgs.curl pkgs.jq]
              ./scripts/pocket-id-login-code.sh;
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            dns-diagnostics =
              mkApp "dns-diagnostics" "Run DNS stack diagnostics (resolution, blocking, stats, connectivity)"
              [
                pkgs.systemd
                pkgs.bind.dnsutils
                pkgs.curl
                pkgs.iproute2
                pkgs.iputils
                pkgs.jq
              ]
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
              program = "${pkgs.callPackage ./pkgs/dms-lock.nix {inherit (theme) colors;}}/bin/dms-lock";
              meta.description = "Lock screen via DMS IPC (fallback: swaylock-effects with wallpaper + Catppuccin Mocha)";
            };
            dms-wallpaper-next = {
              type = "app";
              program = "${
                pkgs.writeShellApplication {
                  name = "dms-wallpaper-next";
                  runtimeInputs = [inputs.dankMaterialShell.packages.${system}.default];
                  text = "dms ipc call wallpaper next";
                }
              }/bin/dms-wallpaper-next";
              meta.description = "Cycle to next wallpaper via DMS IPC";
            };
            crush-daily-backfill = {
              type = "app";
              program = "${
                pkgs.writeShellApplication {
                  name = "crush-daily-backfill";
                  runtimeInputs = [
                    pkgs.python3
                    inputs.crush-daily.packages.${system}.default or pkgs.crush-daily
                        or (throw "crush-daily package not found")
                  ];
                  text = builtins.readFile ./scripts/crush-daily-backfill.py;
                }
              }/bin/crush-daily-backfill";
              meta.description = "Backfill crush-daily reports for zero-data or missing dates";
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

        nixosConfigurations."zfs-vm" = import ./systems/zfs-vm.nix {
          inherit inputs;
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
