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
    # REV-PINNED nixpkgs holding the llama.cpp 0.3.0 build (the last build
    # proven serving on gfx1150 before the 0.4.0 mid-model-load CPU-spin
    # regression, live 2026-09-14). Consumed ONLY by services/llama-rag.nix.
    # Path-form rev pin is deliberate (a `?rev=` query is eval-guard-blocked
    # and re-pins backward on lock churn): do NOT `nix flake lock
    # --update-input nixpkgs-llama-rag` — drop this input entirely once the
    # 0.4.0+ spin regression is fixed upstream and re-verified live.
    nixpkgs-llama-rag.url = "github:NixOS/nixpkgs/0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
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
      url = "github:schembriaiden/helium-browser-nix-flake";
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

    # Superfile terminal file manager (upstream flake — nixpkgs stuck at 1.3.3,
    # upstream v1.6.0 ships bubbletea-v2 preview reliability + sidebar config)
    superfile = {
      url = "github:yorukot/superfile";
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

    # Declarative disk partitioning — geometry-spec only for SystemNix:
    # diskoConfigurations.samsung-tlc is an eval-checked reference of the
    # live Samsung layout (NOT imported by nixosConfigurations — see
    # disko/samsung-tlc.nix). No module consumers; input kept for the
    # disko CLI (dry-run script rendering / rescue use).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SigNoz observability platform sources (flake = false, packaged in
    # _signoz-packages.nix). Branch-ref governed per the 2026-09-16 pin
    # policy: 2026-09-18 bump lifted the pre-09-13 INTERIM pins after the
    # probe+build passed (sonic is STILL v1.14.1 upstream — the Go-1.26
    # patches in modules/nixos/services/patches/ stay until SigNoz bumps
    # sonic >= 1.15). Bump = migration-review class: pkg/sqlmigration
    # (metadata DB) runs at signoz start, the collector's ClickHouse
    # schema-migrator runs pre-start — review new migrations before
    # deploying a moved rev.
    signoz-src = {
      url = "github:SigNoz/signoz?ref=main";
      flake = false;
    };
    signoz-collector-src = {
      url = "github:SigNoz/signoz-otel-collector?ref=main";
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
    # Both verified against the source 2026-08-21 @ 63c6d9a4 (v0.20.4) and
    # re-verified 2026-09-04 @ d3630f85 (v0.21.0): symbols intact, env flow
    # unchanged; upstream commit 31561e37 additionally BLESSES the
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

    # storage-collector — filesystem capacity tracking daemon (Rust).
    # Private GitHub repo. Flake-input fetches happen outside the build
    # sandbox with the user's git credentials, so `github:` works where
    # in-build cargo git deps broke monitor365. NOTE: its nested
    # `collector-utils` sub-input is pinned to a LOCAL git+file path
    # (~/projects/collector-utils, ahead of origin) — builds need that
    # sibling checkout until collector-utils is pushed and the sub-input
    # moves to `github:`.
    storage-collector = {
      url = "github:LarsArtmann/storage-collector?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # PapDashboard — event-sourced alert hub with NPU insight enricher (Go)
    papdashboard = {
      url = "github:LarsArtmann/PapDashboard?ref=master";
      # nixpkgs deliberately NOT followed (bank-sync/qmd vendorHash doctrine):
      # upstream derives its vendorHash against ITS pinned buildGoModule —
      # following our nixpkgs invalidates it on every bump (2026-09-17: 4
      # revs hunted in one evening, every one hash-mismatched under the
      # b1b87598 buildGoModule).
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
    # Was INTERIM-pinned to f9f3b335 (2026-09-13: auto-commit left the frozen
    # bun lockfile stale); master verified BUILDABLE at HEAD 2026-09-16
    # (package build probe passed) — pin dropped per the pin policy.
    todo-list-ai = {
      url = "github:LarsArtmann/todo-list-ai?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # library-policy — Banned/vulnerable library detector for Go projects
    # ?ref=master since 2026-09-17: upstream ef02247 fixed the build chain
    # (toolchain bumped to go_1_27 for the samber-do-auditlog go.mod floor,
    # vendorHash refreshed; FOD + package verified). Bumps flow via
    # `nix flake lock --update-input library-policy --refresh`.
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
      # Was INTERIM `git+file:///home/lars/projects/file-and-image-renamer` -
      # a local-path pin that broke every CI eval (same class as art-dupl,
      # 2026-09-15). Flip condition satisfied: commit 494c9b7 (the vendorHash
      # refresh forced by the go-nix-helpers /vN fix) is origin/master HEAD
      # (verified via branches-where-head, 2026-09-16). git+ssh fetches on CI
      # via the NIX_DEPLOY_KEY_FILE_AND_IMAGE_RENAMER read-only deploy key.
      # Branch-ref governed (pin policy 2026-09-16: ?ref=master as much as
      # possible; the lock holds the exact rev until an explicit update).
      url = "git+ssh://git@github.com/LarsArtmann/file-and-image-renamer?ref=refs/heads/master";
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

    # go-taskqueue — projects-aware task work queue + agent pool (tq CLI).
    # 2026-09-17: interim git+file FLIPPED to github:?ref=master — the push
    # backlog landed on origin (master = 1c48478, incl. the vendorHash fix
    # from 1a4eb48). go-nix-helpers deliberately NOT followed (bank-sync
    # FOD-mismatch trap): the vendorHash was validated with upstream's
    # locked helper.
    go-taskqueue = {
      url = "github:LarsArtmann/go-taskqueue?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
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
      # Was INTERIM `git+file:///home/lars/worktrees/go-nix-helpers-vnfix` -
      # the /vN pseudo-version normalization fix (8c87f26) now lives on the
      # pushed branch `systemnix-vn-version-fix` (public repo, rev verified
      # on GitHub 2026-09-16). Tarball fetch needs no auth (public repo,
      # no deploy key); CI's insteadOf rewrite keeps covering the transitive
      # git+ssh copies. Was pinned to 8c87f265 (systemnix-vn-version-fix
      # branch) until the fix landed on master as c42fd778 ("preserve
      # module-path major in pseudo-version normalization", verified
      # 2026-09-16) — pin dropped per the pin policy; consumer goModules
      # FODs re-verified after the lock move.
      # project-meta consumes go-nix-helpers.flakeModules.go-standard, so this
      # must remain a flake input even though Go libraries are the primary use.
      url = "github:LarsArtmann/go-nix-helpers?ref=master";
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

    # go-health-dashboard — federated go-health hub (health.home.lan).
    # Consumed for its packages.health-hub buildGoModule output (the flake
    # owns the go_1_27 + GOEXPERIMENT=jsonv2 toolchain wiring).
    go-health-dashboard = {
      url = "github:LarsArtmann/go-health-dashboard?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # erraudit — Error handling pattern analyzer for Go projects
    # (GitHub renamed the repo from hierarchical-errors; the input name and
    # the mkLarsPackages attr follow the new name. 2026-09-17.)
    erraudit = {
      url = "github:LarsArtmann/erraudit?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        # go-finding: NOT followed — upstream hasn't been updated for the new Confidence type API
      };
    };

    # BuildFlow — Zero-configuration build automation for Go projects
    buildflow = {
      # Branch-ref governed (pin policy 2026-09-16). LOCK HOLD LIFTED
      # (2026-09-23): the lock holds 5b3483a, where BOTH prior breakers are
      # fixed and PUSHED — the vendorHash (upstream vendorHash.nix = the
      # WIFsGV… "got" hash; `nix build .#buildflow` verified clean in
      # ~/projects/BuildFlow) and the gvafix.* compile break (fixed in the
      # commits after bc999b4). The lars-packages.nix vendorHash shim was
      # dropped in the same change per the hold's own instruction. History:
      # hold began 2026-09-22 at 7e1fbfe (bc999b4 mid-refactor broke COMPILE;
      # root-nixpkgs move re-resolved the FOD graph), interim rollback
      # 2026-09-23 after a lock wave jumped to 48d59fc. Standing discipline:
      # after any `nix flake lock --update-input buildflow`, probe
      # `nix build .#buildflow` before switching, and re-shim ONLY via
      # nix-hash-fix evidence, never by hand.
      url = "git+ssh://git@github.com/LarsArtmann/BuildFlow?ref=refs/heads/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # go-auto-upgrade — Automate Go library upgrades
    # ?ref=master since 2026-09-17: upstream a6d1e65 refreshed the stale
    # vendorHash (FOD + package verified). Bumps flow via
    # `nix flake lock --update-input go-auto-upgrade --refresh`.
    go-auto-upgrade = {
      url = "github:LarsArtmann/go-auto-upgrade?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # go-structure-linter — Go project structure validator
    go-structure-linter = {
      # INTERIM-ROLLBACK (2026-09-23): the wave re-locked to 721c62a0, whose
      # go.mod floor (1.27.1) exceeds the followed nixpkgs go (1.26.7) — the
      # go-modules FOD dies under GOTOOLCHAIN=local. The lock node was rolled
      # back to 96b6a01f (gen-797-proven). Do NOT update-input until upstream
      # wires go_1_27 (the library-policy three-wiring-points pattern).
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
      # Was the `cqrs-lint-vendorhash-fix` branch pin (d84e4d6a) — a stale
      # fork of master that CI could only fetch via deploy key. 2026-09-17:
      # master itself carries a FRESHER cqrs-lint vendorHash refresh
      # (0b5813f45, FOD + package verified) and 247 commits of the branch
      # divergence are folded in, so the input rides master again
      # (branch-ref governed per the 2026-09-16 pin policy). git+ssh kept
      # (PRIVATE repo; CI fetches via NIX_DEPLOY_KEY_GO_CQRS_LITE).
      url = "git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=refs/heads/master";
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
      # Was INTERIM `git+file:///home/lars/projects/branching-flow` - a local
      # path that can never resolve on CI (2026-09-15). Flip condition
      # satisfied: origin/master (7789334) carries 46000f38 (verified via
      # `git merge-base --is-ancestor`). git+ssh fetches on CI via the
      # NIX_DEPLOY_KEY_BRANCHING_FLOW deploy key. Branch-ref governed (pin
      # policy 2026-09-16: ?ref=master as much as possible; the lock holds
      # the exact rev until an explicit update).
      url = "git+ssh://git@github.com/LarsArtmann/branching-flow?ref=refs/heads/master";
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
      # Pinned to the fork-branch rev that carries the vendorHash refresh.
      # Was INTERIM `git+file:///home/lars/projects/art-dupl` — a local-path
      # input that made EVERY CI eval fail (`Git repository ... does not
      # exist`: flake-check VM tests + go-deps-audit input evals, 2026-09-15).
      # The flip condition (fork branch pushes 9c370324) is satisfied:
      # origin/fork contains it. `git+https` with an explicit fork ref
      # fetches in CI and stays lock-governed (pin policy 2026-09-16:
      # branch refs over rev pins; the lock holds the exact rev until an
      # explicit update). (A bare `github:<rev>` URL failed
      # to lock: nix's tarball-to-git-tree import dies with a libgit2
      # tree-builder error on this repo - the real git+https clone path
      # handles it, and the locked narHash is byte-identical to the old
      # local pin, so no consumer hash churn.)
      url = "git+https://github.com/LarsArtmann/art-dupl?ref=refs/heads/fork";
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
      # ?ref=master since 2026-09-17: upstream 4b634211 refreshed the stale
      # vendorHash (FOD + package verified, PMA's own lock). Bumps flow via
      # `nix flake lock --update-input projects-management-automation --refresh`.
      url = "github:LarsArtmann/projects-management-automation?ref=master";
      inputs = {
        flake-parts.follows = "flake-parts";
      };
    };

    # project-discovery-daemon — standalone discovery daemon owning
    # /run/project-discovery/daemon.sock (flipped from PMA's co-located
    # embedded daemon 2026-09-07). Must be at a rev that supports
    # PROJECT_DISCOVERY_SEARCH_PATHS and PROJECT_DISCOVERY_SOCKET_MODE.
    project-discovery-daemon = {
      url = "github:LarsArtmann/project-discovery-daemon?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        # go-nix-helpers master tip is currently broken (undefined `mod` in
        # mkPreparedSource.nix, 2a74b8b4); follow this flake's known-good pin.
        go-nix-helpers.follows = "go-nix-helpers";
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
      # ?ref=master since 2026-09-17: upstream a0cfbc2 refreshed the stale
      # vendorHash (FOD + package verified). Bumps flow via
      # `nix flake lock --update-input overview --refresh`.
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
    # Branch-ref governed (pin policy 2026-09-16): flake.nix tracks
    # ?ref=master, flake.lock holds the exact rev — df1a2bf0 (2026-09-17:
    # first master-head lift since the c0604e46 pin era; upstream's
    # vendorHashes were refreshed IN DiscordSync df1a2bf0 after the
    # post-pin churn left BOTH goModules FODs stale, +131 commits incl. a
    # new ADDITIVE nixos-module option tursoSyncMonthlyBudgetBytes,
    # default 2.5 GB/month sync breaker). Bumps flow via
    # `nix flake lock --update-input discordsync --refresh` — the
    # --refresh is LOAD-BEARING after ref-ahead pushes: the nix daemon
    # serves the stale ref→rev resolution from its in-memory fetch cache
    # (a sudo daemon restart also clears it; --refresh is the no-sudo
    # path, verified 2026-09-17). Known upstream gap: packages.cqrs-lint
    # fails AFTER its FOD ("updates to go.mod needed" — go-cqrs-lite cmd
    # module drift); SystemNix consumes only packages.default, green.
    discordsync = {
      # INTERIM-ROLLBACK (2026-09-23): the wave re-locked discordsync to
      # 605efc28, whose prepared source fails mkPreparedSource's private-dep
      # validation (go-sqlitestore in go.mod without a flake deps wiring) —
      # unfixable SystemNix-side. The lock node was rolled back to b3077aa2,
      # the gen-797-proven rev currently deployed (upstream nixpkgs NOT
      # followed, so the FOD is a cache hit). Do NOT update-input until
      # upstream wires go-sqlitestore and the FOD + package probe green.
      url = "github:LarsArtmann/DiscordSync?ref=master";
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

    # nix-email — Declarative mail stack (Stalwart + DMARC monitoring).
    # Consumed via the upstream-flake pattern (like inboxclean/discordsync):
    # flake.nixosModules.default wraps nixpkgs services.stalwart +
    # services.parsedmarc; the consumer wrapper here layers sops secrets,
    # onFailure routing, the integration-registry entry and backup
    # freshness checks (modules/nixos/services/nix-email.nix).
    #
    # nixpkgs.follows is REQUIRED, not just convenient: the wrapper is
    # eval-verified against OUR nixpkgs services.stalwart module by
    # checks.nix-email-contract on every flake check — follows forces our
    # pin even when upstream's own lock trails it, so the contract test
    # (not a shared rev) is the compat doctrine now. Upstream master has
    # its own CI + stalwart/relay/parsedmarc E2E suites since v0.3.0.
    nix-email = {
      url = "github:LarsArtmann/nix-email?ref=master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # Dedupe (2026-09-22, per the nix-email CHANGELOG hint): collapse
        # upstream's flake-parts into OUR flake-parts node - without this
        # the lock carries a second flake-parts (flake-parts_17) that only
        # nix-email consumes.
        flake-parts.follows = "flake-parts";
      };
    };

    # vision-review-agent — visionreviewd, the event-sourced UI review daemon
    # (returned 2026-09-22 after the 2026-09-15 dormant-integration removal;
    # this time enabled on evo-x2, pointed at llama-vlm's captioner endpoint)
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
    # Was INTERIM-pinned to 5b72f894 (2026-09-13 vendorHash wave); master
    # verified BUILDABLE at HEAD 2026-09-16 (goModules FOD probe passed) —
    # pin dropped per the pin policy (?ref=master everywhere possible).
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
    # Branch-ref governed (pin policy 2026-09-16): the lock still holds
    # 0971fe9c until an explicit `nix flake lock --update-input
    # browser-history` — probe the go-modules FOD at the target rev first
    # (its build rides published cqrs-htmx tags; AGENTS.md probe protocol).
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

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      nix-ssh-config,
      crush-config,
      superfile,
      treefmt-full-flake,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      overlays = import ./overlays inputs;
      inherit (overlays)
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
      discoveredModules = lib.concatMap (
        dir:
        let
          files = lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".nix" n && !(lib.hasPrefix "_" n)) (
            builtins.readDir dir
          );
        in
        lib.mapAttrsToList (file: _: {
          path = dir + "/${file}";
          module = lib.removeSuffix ".nix" file;
        }) files
      ) moduleDirs;

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
        inherit nix-ssh-config crush-config superfile;
        inherit (theme) colorScheme;
      };

      # LarsArtmann Go tool packages — single source of truth in lib/lars-packages.nix.
      # Referenced by perSystem.packages (for nix build .#X) and passed to base.nix
      # via specialArgs (for environment.systemPackages).
      mkLarsPackages = import ./lib/lars-packages.nix { inherit lib inputs; };

      # Eval-time guard: the nix global registry rewrites github:NixOS/nixpkgs/nixos-unstable
      # to a tarball URL. The tarball pointer can be stale, silently downgrading nixpkgs
      # by months. This assertion fails nix flake check / nix eval if the regression recurs.
      # Uses builtins.seq to force eager evaluation (Nix is lazy — an unreferenced let
      # binding would never fire).
      lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);
      nixpkgsLockType = lockFile.nodes.nixpkgs.original.type or "unknown";
      nixpkgsTarballGuard =
        assert
          nixpkgsLockType == "github"
          || throw ''
            nixpkgs flake.lock regression: original type is "${nixpkgsLockType}", expected "github".
            The nix global registry rewrote nixpkgs to a tarball which may be stale.
            Fix: manually edit flake.lock nodes.nixpkgs.original to type "github".
          '';
        true;

      # Eval-time guard: a `?rev=` in a flake.nix input URL OVERRIDES
      # flake.lock (the overview templ-components trap — every lock re-sync
      # re-fetches the pinned tree and re-pins BACKWARD). The ONLY sanctioned
      # ?rev= is the git+file: interim pin of a local checkout/worktree
      # (2026-09-13 broken mass-update remediation): there it is the
      # documented defense against the dirtyRev/narHash lock trap, and CI
      # cannot fetch git+file anyway. Remote-scheme pins must move in
      # flake.lock, never in the URL. Reads the LOCK's original URLs (the
      # resolved-flake `.original` attr infinite-recurses here).
      inputUrlRevOffenders =
        let
          rootInputs = lockFile.nodes.${lockFile.root}.inputs or { };
          nodeUrl = key: lockFile.nodes.${key}.original.url or "";
        in
        lib.filter (n: n != null) (
          lib.mapAttrsToList (
            name: node:
            let
              url = if builtins.isString node then nodeUrl node else "";
            in
            if builtins.match ".*[?&]rev=.*" url != null && !lib.hasPrefix "git+file:" url then name else null
          ) rootInputs
        );
      inputUrlRevGuard =
        assert
          inputUrlRevOffenders == [ ]
          || throw ''
            flake.nix input URL carries ?rev= (overrides flake.lock, silently re-pins on every lock re-run): ${lib.concatStringsSep ", " inputUrlRevOffenders}.
            Fix: drop ?rev= from the URL and pin via flake.lock, or use a git+file: interim pin (local checkouts only).
          '';
        true;
      allEvalGuards = builtins.seq nixpkgsTarballGuard inputUrlRevGuard;
    in
    builtins.seq allEvalGuards flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      # Import service modules — registered as flake-parts modules (inputs.self.nixosModules.*)
      imports = discoveredModulePaths;

      # Executable disk-geometry specs (docs, not applied by any host —
      # see disko/samsung-tlc.nix for the discovery-trap rationale).
      flake.diskoConfigurations.samsung-tlc = import ./disko/samsung-tlc.nix;

      # Per-system configuration (packages, devShells, etc.)
      perSystem =
        {
          pkgs,
          system,
          lib,
          ...
        }:
        {
          # Allow unfree and broken packages for all systems
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            config.allowBroken = false; # # <-- THIS MUST ALWAYS BE FALSE!
            overlays =
              sharedOverlays
              ++ [ disableTests ]
              ++ lib.optionals (lib.hasSuffix "-linux" system) linuxOnlyOverlays;
          };

          # Formatter: treefmt-full-flake's treefmt with ONE local patch —
          # generated HTML report bundles under docs/ are NEVER formatted
          # (AGENTS.md "Big self-contained HTML reports": the inline mermaid
          # JS is generated content; prettier expands the 3.6 MB bundle to
          # 7.8 MB and that churn has oscillated the blob in git history
          # repeatedly — 2026-09-20 and 2026-09-21). The upstream wrapper
          # bakes its --config-file store path; the config text is
          # regenerated with the excludes added and the formatter programs
          # and their versions stay untouched.
          formatter =
            let
              upstream = treefmt-full-flake.formatter.${system};
              # The wrapper's --config-file path is extracted in the BUILDER,
              # never at eval: reading "${upstream}/bin/treefmt" at eval forces
              # realization of the treefmt package during EVERY flake check,
              # and after nixpkgs churn invalidates the drv the eval dies
              # `path '...treefmt.drv' is not valid` (the niri-class
              # package-output-coercion gotcha; dead pre-commit gate
              # 2026-09-24..25). A failed extraction fails the BUILD loudly.
              patchedConfig = pkgs.runCommand "treefmt-systemnix-excludes.toml" { } ''
                wrapper="${upstream}/bin/treefmt"
                configLine="$(grep -m1 -- '--config-file=' "$wrapper" || true)"
                case "$configLine" in
                  *--config-file=*) ;;
                  *)
                    echo "treefmt-full-flake wrapper no longer carries --config-file; rework the formatter override in flake.nix" >&2
                    exit 1
                    ;;
                esac
                upstreamConfig="$(printf '%s\n' "$configLine" | sed -n 's/.*--config-file=\([^[:space:]]\+\).*/\1/p')"
                substitute "$upstreamConfig" "$out" \
                  --replace 'excludes = ["*.lock"' 'excludes = [
                "docs/**/*.html",
                "*.lock"'
              '';
            in
            pkgs.writeShellScriptBin "treefmt" ''
              exec ${upstream}/bin/treefmt --config-file=${patchedConfig} --tree-root-file=flake.nix "$@"
            '';

          packages =
            (mkLarsPackages system)
            // {
              inherit (pkgs)
                aw-watcher-utilization
                govalid
                jscpd
                sqlc
                systemd-timer-monitor
                ;

              # Pre-deploy batch build (Pareto T17/F65): ONE command
              # surfaces every stale vendorHash / FOD breakage in the
              # LarsArtmann Go set BEFORE `nix run .#deploy` pays for a
              # full toplevel build mid-switch — the domino-deploy class
              # (2026-08-27: four sequential switch attempts, each dying
              # at the next FOD; --keep-going enumerates, this PREVENTS).
              # NOT included: bank-sync (rides the bank-sync home-manager
              # module import in systems/evo-x2.nix, not mkLarsPackages;
              # the old vendorHash-override exclusion reason died with the
              # override itself, dropped 2026-09-03 — the daemon build is
              # exercised by every `nixos-rebuild switch`), monitor365 (its
              # wireguard-collector git dep is a PRIVATE crate that 404s on
              # anonymous fetch — the documented reason the service is
              # disabled since 2026-08-12; a permanent red, not drift —
              # first quick-go run proved exactly this), cv (built with its
              # real module-level package by checks.x86_64-linux.cv), hermes
              # (Python/uv2nix, not a vendorHash class).
              quick-go = pkgs.symlinkJoin {
                name = "quick-go-batch";
                paths =
                  (builtins.attrValues (mkLarsPackages system))
                  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
                    pkgs.dnsblockd
                    pkgs.emeet-pixyd
                    pkgs.file-and-image-renamer
                    pkgs.crush-daily
                  ];
              };
            }
            // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
              # monitor365 REMOVED 2026-09-15: nix flake check derivationStrict's
              # every package, and monitor365's prepared source is permanently
              # unbuildable (private wireguard-collector crate — the 2026-08-12
              # disable reason). The entry only ever passed via a stale
              # store-cached drv; the first input bump after cache eviction
              # hard-blocked every deploy at pre-deploy check 1.
              inherit (pkgs)
                openaudible
                openseo
                dnsblockd
                netwatch
                systemd-graph
                systemd-graph-webui
                emeet-pixyd
                file-and-image-renamer
                crush-daily
                fastflowlm
                ;
              freebsd-zfs-vm = import ./pkgs/freebsd-zfs-vm.nix { inherit pkgs; };
            };

          # Development shells for different program categories
          devShells = {
            default = pkgs.mkShellNoCC {
              BUILDFLOW_EXCLUDE_PATTERNS = "assets/avatar.png";
              packages =
                with pkgs;
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
            let
              # Unit scripts must EXEC every binary they use from the unit's
              # own PATH (runtimeInputs / path / an absolute store ref). A
              # binary provided only by the ambient profile is exit-127 under
              # harden{}'s restricted PATH — or a PHANTOM GREEN when the miss
              # lands inside an `if` condition. Both classes hit LIVE:
              #   awk without gawk:
              #     - btrfs-verify-pool-backups (2026-08-18): awk missing from
              #       the unit path made the device-stats branch silently skip
              #     - btrfs-balance-{metadata,data} (2026-08-31): awk missing
              #       from runtimeInputs — exit 127 on every run for a week
              #       while root chunk-unalloc sat CRITICAL (the ENOSPC
              #       prevention layer fully dead)
              #   `#!/usr/bin/env python3` without pkgs.python3:
              #     - systemd-timer-monitor: exit 127, env: 'python3': No such
              #       file or directory (documented gotcha)
              # v0 is FILE-scoped: the provider must appear anywhere in the
              # same file (runtimeInputs, path, or ${pkgs.X}/bin ref). Extend
              # ONLY with rows backed by a real incident — a false positive
              # here blocks every deploy through pre-commit + CI.
              binaryCoverageScanner = pkgs.writeShellScript "binary-coverage-scan" ''
                # usage: binary-coverage-scan <tree>... — exit 1 on provider gaps
                fail=0
                noncomments() { grep -vE '^[[:space:]]*#($|[^!])' "$1" | grep -vE '^[[:space:]]*(description|name)\s*=' || true; }
                for tree in "$@"; do
                  for f in $(find "$tree" -type f -name '*.nix' | sort); do
                    # awk → gawk|busybox (provider grep runs on the RAW file, so a `# awk` note alone never satisfies it... actually it DOES — v0 accepts any mention; comments-stripped only gates the USAGE side)
                    if noncomments "$f" | grep -qw awk && ! grep -qwE 'gawk|busybox' "$f"; then
                      echo "FAIL: $f execs 'awk' but never mentions gawk/busybox in runtimeInputs/path."
                      echo "  Incidents: btrfs-verify-pool-backups phantom green (2026-08-18);"
                      echo "  btrfs-balance-* exit 127 for a week (2026-08-31). Add pkgs.gawk."
                      fail=1
                    fi
                    # python3 → pkgs.python3 (SHEBANGS COUNT: the timer-monitor incident WAS a shebang)
                    if { noncomments "$f" | grep -qw python3 || grep -qE '^#!.*python3' "$f"; } \
                       && ! grep -qE 'pkgs\.python3|python3Full|python3\.interpreter|python3Packages\.python|writePython3|/bin/python' "$f"; then
                      echo "FAIL: $f uses python3 but never provides it (pkgs.python3 in runtimeInputs/path)."
                      echo "  Incident: systemd-timer-monitor exit 127 — env: 'python3': No such file."
                      fail=1
                    fi
                  done
                done
                exit "$fail"
              '';
            in
            {
              statix =
                pkgs.runCommand "statix-check"
                  {
                    nativeBuildInputs = [ pkgs.statix ];
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
                    nativeBuildInputs = [ pkgs.deadnix ];
                  }
                  ''
                    cd ${./.}
                    deadnix --fail --no-lambda-pattern-names . 2>&1 | tee $out
                  '';

              # disko geometry spec guard (Phase-2 plan T16.2/T16.3):
              # eval-checks diskoConfigurations.samsung-tlc against the LIVE
              # geometry and asserts the flake-discovery trap stays closed —
              # the disko config must never be reachable from
              # nixosConfigurations (an imported disko module would make
              # `disko --flake .#evo-x2` apply destructive modes).
              disko-samsung-tlc =
                let
                  inherit (inputs.self.diskoConfigurations.samsung-tlc.disko.devices.disk.samsung-tlc) content device;
                  inherit (content.partitions) esp main;
                  evoConfigOptions = inputs.self.nixosConfigurations.evo-x2.options;
                  geometryGuards =
                    assert device == "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V";
                    assert content.type == "gpt";
                    assert esp.type == "EF00" && esp.size == "4G";
                    assert esp.content.format == "vfat";
                    assert esp.content.mountpoint == null;
                    assert lib.elem "-n" esp.content.extraArgs && lib.elem "SAMSUNG-EFI" esp.content.extraArgs;
                    assert main.content.type == "btrfs";
                    assert lib.elem "-L" main.content.extraArgs && lib.elem "tlc" main.content.extraArgs;
                    # toplevel (subvolid=5) at /mnt/hot — hot/<name> service
                    # subvols are created THROUGH it, never a named subvol
                    assert main.content.mountpoint == "/mnt/hot";
                    assert main.content.subvolumes ? "/nix";
                    assert main.content.subvolumes ? "/users/lars/cache/nix";
                    assert !(evoConfigOptions ? disko);
                    true;
                in
                builtins.deepSeq geometryGuards (
                  pkgs.runCommand "disko-samsung-tlc-check" { } ''
                    echo "samsung-tlc disko geometry + discovery-trap guard OK" > $out
                  ''
                );

              # Behavioral fixture tests for the forgejo staged-primary
              # scripts (plan M05/M06/M07): push-mirror attach, repo flip,
              # dead-mirror notice parsing. The scripts are
              # writeShellApplication outputs, whose runtimeInputs dirs sit
              # FIRST on PATH — plain PATH stubs CANNOT shadow them (the
              # DMS lesson). Fixtures therefore copy each wrapper and
              # sed-inject a stub dir at the FRONT of its PATH line.
              forgejo-scripts-fixture =
                let
                  forgejoScripts = import ./modules/nixos/services/_forgejo-scripts.nix {
                    inherit pkgs lib;
                    config = {
                      services = { };
                    };
                    primaryUser = "lars";
                    cfg = {
                      sshKeys = { };
                    };
                    forgejoPkg = pkgs.hello;
                    forgejoUrl = "http://localhost:3000";
                    stateDir = "/var/lib/forgejo";
                    hostName = "fixture";
                    runnerLabels = [ ];
                    runnerConfigFile = pkgs.writeText "runner-config" "";
                  };
                in
                pkgs.runCommand "forgejo-scripts-fixture"
                  {
                    nativeBuildInputs = with pkgs; [
                      bash
                      coreutils
                      gnused
                      gnugrep
                      jq
                    ];
                  }
                  ''
                    set -euo pipefail
                    FIX=$(mktemp -d)
                    STUB_BIN="$FIX/stub-bin"; mkdir -p "$STUB_BIN"
                    STUB_HTTP="$FIX/http"; mkdir -p "$STUB_HTTP"
                    STUB_STATE="$FIX/state"; mkdir -p "$STUB_STATE"
                    export STUB_HTTP STUB_STATE

                    # ---- curl stub: METHOD+URL keyed responses under
                    # $STUB_HTTP; per-key sequential counters serve
                    # stateful scenarios (repo state changes across a flip).
                    cat > "$STUB_BIN/curl" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    method=GET; url=; out=; wcode=; data=; fail=0; payload=
                    while [ $# -gt 0 ]; do
                      case "$1" in
                        -X) method="$2"; shift 2 ;;
                        -o) out="$2"; shift 2 ;;
                        -w) wcode="$2"; shift 2 ;;
                        -d) data=1; payload="$2"; shift 2 ;;
                        -sf|-s|-f|-k|-L|--compressed) case "$1" in *f*) fail=1;; esac; shift ;;
                        -H|--connect-timeout|--max-time) shift 2 ;;
                        http*) url="$1"; shift ;;
                        *) shift ;;
                      esac
                    done
                    [ -n "$data" ] && [ "$method" = GET ] && method=POST
                    key=$(printf '%s' "$url" | sed 's|https\{0,1\}://||; s|[^A-Za-z0-9._-]|_|g')
                    base="$STUB_HTTP/''${key}.''${method}"
                    n=0
                    [ -f "$STUB_STATE/n.''${key}.''${method}" ] && n=$(cat "$STUB_STATE/n.''${key}.''${method}")
                    n=$((n + 1)); echo "$n" > "$STUB_STATE/n.''${key}.''${method}"
                    printf '%s' "''${payload:-}" > "$STUB_STATE/req.''${key}.''${method}.$n.json"
                    code_file=""; body_file=""
                    if [ -f "$base.$n.code" ]; then code_file="$base.$n.code"; body_file="$base.$n.body"
                    elif [ -f "$base.code" ]; then code_file="$base.code"; body_file="$base.body"
                    fi
                    code=404
                    [ -n "$code_file" ] && code=$(cat "$code_file")
                    if [ "$code" -ge 400 ] && [ "$fail" = 1 ]; then exit 22; fi
                    if [ -n "$out" ]; then [ -n "$body_file" ] && cat "$body_file" > "$out"
                    elif [ -z "$wcode" ]; then [ -n "$body_file" ] && cat "$body_file"
                    fi
                    [ -n "$wcode" ] && printf '%s' "$code"
                    exit 0
                    STUBEOF
                    chmod +x "$STUB_BIN/curl"

                    # ---- gh stub: serves $STUB_HTTP/gh_<sanitized>.body
                    cat > "$STUB_BIN/gh" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    [ "''${1:-}" = "api" ] || { echo "gh stub: only api" >&2; exit 1; }
                    key=gh_$(printf '%s' "''${2:-}" | sed 's|[^A-Za-z0-9._-]|_|g')
                    if [ -f "$STUB_HTTP/$key.body" ]; then cat "$STUB_HTTP/$key.body"; exit 0; fi
                    echo '{"message":"Not Found"}'
                    exit 1
                    STUBEOF
                    chmod +x "$STUB_BIN/gh"

                    # ---- sqlite3 stub: cats $STUB_SQLITE_OUT (env)
                    cat > "$STUB_BIN/sqlite3" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    [ -n "''${STUB_SQLITE_OUT:-}" ] && [ -f "$STUB_SQLITE_OUT" ] && cat "$STUB_SQLITE_OUT"
                    exit 0
                    STUBEOF
                    chmod +x "$STUB_BIN/sqlite3"

                    # PATH-inject the stub dir into a copy of a
                    # writeShellApplication wrapper (runtimeInputs dirs
                    # come first in the original PATH line).
                    inject() {
                      cp "$1" "$2"
                      sed -i 's#^export PATH="#export PATH="'"$STUB_BIN"':#' "$2"
                      chmod +x "$2"
                    }
                    PUSH="$FIX/forgejo-push-mirror"
                    FLIP="$FIX/forgejo-flip-repo"
                    HEALTH="$FIX/forgejo-mirror-health"
                    CENSUS="$FIX/forgejo-census"
                    inject ${lib.getExe forgejoScripts.pushMirrorScript} "$PUSH"
                    inject ${lib.getExe forgejoScripts.flipRepoScript} "$FLIP"
                    inject ${lib.getExe forgejoScripts.mirrorHealthScript} "$HEALTH"
                    inject ${lib.getExe forgejoScripts.censusScript} "$CENSUS"

                    export FORGEJO_TOKEN=fxtok GITHUB_TOKEN=gxtok GITHUB_USER=LarsArtmann
                    rc=0; capt=""
                    # NOTE: capture var is `capt` — `out` is RESERVED (the
                    # derivation output path); shadowing it made the final
                    # `echo PASS > "$out"` redirect into a garbage filename.
                    run() { capt=$("$@" 2>&1) && rc=0 || rc=$?; }
                    need_rc() { [ "$rc" = "$2" ] || { echo "FAIL $1: rc=$rc want $2"; printf '%s\n' "$capt"; exit 1; }; }
                    need_has() { printf '%s\n' "$capt" | grep -qF "$2" || { echo "FAIL $1: missing text: $2"; printf '%s\n' "$capt"; exit 1; }; }

                    # ============ push-mirror (M05) ============
                    export FORGEJO_CANONICAL_REPOS="push-happy"
                    printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy.GET.code"
                    printf '{"mirror":false}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy.GET.body"
                    printf '[]' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.GET.code"
                    printf '[]' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.GET.body"
                    printf 201 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.POST.code"
                    run "$PUSH"; need_rc push-happy 0; need_has push-happy "push mirror attached"
                    # The M05 lesson, asserted: the POST MUST carry the
                    # interval field (the old code 400'd 18/18 without it).
                    grep -q '"interval": "8h"' "$STUB_STATE/req.localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.POST.1.json" \
                      || { echo "FAIL push-happy: POST payload lacks interval 8h"; cat "$STUB_STATE/req.localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.POST.1.json"; exit 1; }

                    export FORGEJO_CANONICAL_REPOS="push-stuck"
                    printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-stuck.GET.code"
                    printf '{"mirror":true}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-stuck.GET.body"
                    run "$PUSH"; need_rc push-stuck 1; need_has push-stuck "still a PULL mirror"

                    export FORGEJO_CANONICAL_REPOS="push-done"
                    printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done.GET.code"
                    printf '{"mirror":false}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done.GET.body"
                    printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done_push_mirrors.GET.code"
                    printf '[{"id":1}]' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done_push_mirrors.GET.body"
                    run "$PUSH"; need_rc push-done 0; need_has push-done "already attached"

                    export FORGEJO_CANONICAL_REPOS="push-ghost"
                    printf 404 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-ghost.GET.code"
                    run "$PUSH"; need_rc push-ghost 1; need_has push-ghost "not found on forgejo"
                    unset FORGEJO_CANONICAL_REPOS

                    # ============ flip (M06) ============
                    BASE=gh_repos_LarsArtmann_flip-pilot.body
                    printf '{"default_branch":"main","open_issues_count":3,"private":true,"description":"d"}' > "$STUB_HTTP/$BASE"
                    FJ=localhost_3000_api_v1_repos_lars_flip-pilot
                    # 3 sequential GET states: dry-run precondition (mirror),
                    # happy-run precondition (mirror), post-migrate (native).
                    printf 200 > "$STUB_HTTP/$FJ.GET.1.code"
                    printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/$FJ.GET.1.body"
                    printf 200 > "$STUB_HTTP/$FJ.GET.2.code"
                    printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/$FJ.GET.2.body"
                    printf 200 > "$STUB_HTTP/$FJ.GET.3.code"
                    printf '{"owner":{"login":"lars"},"mirror":false,"default_branch":"main","open_issues_count":3}' > "$STUB_HTTP/$FJ.GET.3.body"
                    printf 204 > "$STUB_HTTP/$FJ.DELETE.1.code"
                    MIG=localhost_3000_api_v1_repos_migrate.POST
                    printf 201 > "$STUB_HTTP/$MIG.1.code"
                    PM="$FJ"_push_mirrors
                    printf 200 > "$STUB_HTTP/$PM.GET.1.code"; printf '[]' > "$STUB_HTTP/$PM.GET.1.body"
                    printf 201 > "$STUB_HTTP/$PM.POST.1.code"
                    printf 200 > "$STUB_HTTP/$PM.GET.2.code"; printf '[{"id":7}]' > "$STUB_HTTP/$PM.GET.2.body"

                    run "$FLIP" flip-pilot --dry-run; need_rc flip-dry 0; need_has flip-dry "DRY RUN"
                    run "$FLIP" flip-pilot; need_rc flip-happy 0; need_has flip-happy "FLIPPED flip-pilot"
                    # sequential counters advanced by the dry-run's GETs: the
                    # happy path consumed .2 for the repo GET — re-arm both
                    # for the failure scenarios with fresh names.

                    # refuse: native repo
                    printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-native.GET.1.code"
                    printf '{"owner":{"login":"lars"},"mirror":false}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-native.GET.1.body"
                    run "$FLIP" flip-native; need_rc flip-native 1; need_has flip-native "NOT a pull mirror"

                    # refuse: pending reconcile verdict
                    RD="$FIX/reconcile"; mkdir -p "$RD"
                    printf 'flip-pending\n' > "$RD/pending-deletes.txt"
                    export FORGEJO_RECONCILE_STATE_DIR="$RD"
                    printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-pending.GET.1.code"
                    printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-pending.GET.1.body"
                    run "$FLIP" flip-pending; need_rc flip-pending 1; need_has flip-pending "pending reconcile verdict"
                    unset FORGEJO_RECONCILE_STATE_DIR

                    # mid-flip failure: migrate 422 AFTER the delete
                    printf '{"default_branch":"main","open_issues_count":0,"private":false,"description":""}' \
                      > "$STUB_HTTP/gh_repos_LarsArtmann_flip-mid.body"
                    FJM=localhost_3000_api_v1_repos_lars_flip-mid
                    printf 200 > "$STUB_HTTP/$FJM.GET.1.code"
                    printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/$FJM.GET.1.body"
                    printf 204 > "$STUB_HTTP/$FJM.DELETE.1.code"
                    printf 422 > "$STUB_HTTP/localhost_3000_api_v1_repos_migrate.POST.2.code"
                    run "$FLIP" flip-mid; need_rc flip-mid 1; need_has flip-mid "mirror already deleted"
                    # the migrate POST counter advanced — re-arm for census below if needed

                    # ============ mirror-health (M07) ============
                    TF="$FIX/tf"; mkdir -p "$TF"
                    export FORGEJO_MIRROR_HEALTH_TEXTFILE_DIR="$TF"
                    export FORGEJO_DB="$FIX/fake.db"; : > "$FORGEJO_DB"
                    STALE="$FIX/known-stale.txt"
                    export FORGEJO_KNOWN_STALE="$STALE"
                    printf 'darkblocks\ndialogueswebinterface\n' > "$STALE"

                    : > "$FIX/notices"
                    export STUB_SQLITE_OUT="$FIX/notices"
                    run "$HEALTH"; need_rc health-clean 0
                    grep -q '^forgejo_mirror_dead_candidates 0$' "$TF/forgejo_mirror_health.prom" \
                      || { echo "FAIL health-clean: prom missing dead_candidates 0"; exit 1; }

                    cat > "$FIX/notices" <<NOTICESEOF
                    Failed to update mirror repository '/var/lib/forgejo/data/gitea-repositories/lars/SystemNix.git': fatal: repository not found
                    Failed to update mirror repository '/var/lib/forgejo/data/gitea-repositories/lars/DarkBlocks.git': fatal: repository not found
                    Failed to update mirror repository wiki '/var/lib/forgejo/data/gitea-repositories/lars/SomeRepo.git.wiki': fatal: repository not found
                    Failed to delete repository '/var/lib/forgejo/data/gitea-repositories/lars/Other.git': unrelated notice type text
                    NOTICESEOF
                    run "$HEALTH"; need_rc health-dead 0; need_has health-dead "dead candidate: SystemNix"
                    grep -q '^forgejo_mirror_dead_candidates 1$' "$TF/forgejo_mirror_health.prom" \
                      || { echo "FAIL health-dead: expected exactly 1 candidate (DarkBlocks stale-subtracted, wiki+foreign ignored)"; cat "$TF/forgejo_mirror_health.prom"; exit 1; }

                    export FORGEJO_KNOWN_STALE="$FIX/does-not-exist.txt"
                    run "$HEALTH"; need_rc health-nostale 0
                    grep -q '^forgejo_mirror_health_scrape_errors 1$' "$TF/forgejo_mirror_health.prom" \
                      || { echo "FAIL health-nostale: scrape_errors 1 expected"; exit 1; }
                    if grep -q 'forgejo_mirror_dead_candidates' "$TF/forgejo_mirror_health.prom"; then
                      echo "FAIL health-nostale: dead_candidates must be ABSENT on scrape error"; exit 1
                    fi
                    export FORGEJO_KNOWN_STALE="$STALE"

                    # ============ census (M08) ============
                    unset STUB_SQLITE_OUT
                    printf 200 > "$STUB_HTTP/localhost_3000_api_v1_user_repos_limit_50_page_1.GET.code"
                    cat > "$STUB_HTTP/localhost_3000_api_v1_user_repos_limit_50_page_1.GET.body" <<'CENSUSEOF'
                    [
                      {"owner":{"login":"lars"},"mirror":true},
                      {"owner":{"login":"lars"},"mirror":false},
                      {"owner":{"login":"starred"},"mirror":true}
                    ]
                    CENSUSEOF
                    run "$CENSUS"; need_rc census 0
                    census_out=$(printf '%s\n' "$capt" | sed -n '/===/,$p' | tail -n +2 | jq -s '.[0]')
                    echo "$census_out" | jq -e '.total == 3 and .native == 1 and .mirror == 2' >/dev/null \
                      || { echo "FAIL census: wrong counts"; printf '%s\n' "$capt"; exit 1; }
                    echo "$census_out" | jq -e '(.per_owner | length) == 2' >/dev/null \
                      || { echo "FAIL census: per_owner grouping"; printf '%s\n' "$capt"; exit 1; }

                    echo "PASS: all forgejo staged-primary script fixtures" > "$out"
                  '';

              # Behavioral fixture for scripts/borg-restore-drill.sh
              # (2026-09-24 storage TODO; docs/status report §f.6). The
              # drill is a PLAIN bash script (no writeShellApplication
              # wrapper), so direct PATH stubs work — but it resolves borg
              # via `nix build --print-out-paths --impure --expr`, so the
              # `nix` binary must be stubbed TOO (it prints the stub tree
              # carrying bin/borg). Covers: root-gate die, bogus `--local`
              # die, repo-without-config die, PLACEHOLDER-repo tripwire
              # (fixture BORG_ENV_FILE + id-stub root) + its secrets-missing
              # sibling, happy-path PASS (--local with stubbed borg), and
              # the --verify-data deep-integrity branch (1.x --help probe →
              # --dry-run fallback). Plus a MUTATION NEGATIVE (2026-09-25):
              # a drill COPY with the root gate neutered must FAIL the
              # root-gate case's assertion — proves the fixture exercises
              # the real script content rather than passing vacuously
              # (behavioral twin of scripts/negative-test-lints.sh;
              # anchor-drift-guarded so a no-op sed fails loudly). NOT
              # reachable in the sandbox: the
              # real-mode /mnt/hot mountpoint gate sits BEHIND the
              # `/run/secrets/*` existence checks and `[ -e ]` is a bash
              # builtin that cannot be stubbed — the secrets-missing die is
              # its direct predecessor and is asserted instead.
              #
              # Env-path-pin negative case (folded 2026-09-25 per
              # TODO_LIST/storage.md): the eval-time assertion in
              # platforms/nixos/system/backup.nix pins the drill's
              # BORG_ENV_FILE default to the rendered borg-env sops template;
              # the 2026-09-23 drift probe was hand-run once and ephemeral, so
              # the folded asserts below are its standing regression
              # (test-sops-key-audit shape — pass/fail chosen at eval, fires on
              # every flake check incl. --no-build): control (real module
              # passes), script drift (a sed-drifted COPY of the drill fed to a
              # single-anchor copy of backup.nix — the module's lib import
              # stays lazy while dormant, so the toFile'd copy only needs the
              # script line rewritten), and template-path override (a forced
              # sops.templates."borg-env".path must fire the pin too). Both
              # drift directions run in a MINIMAL nixosSystem co-importing the
              # integration module: backup.nix defines services.integration
              # unconditionally and the empty definition at the undeclared path
              # errors otherwise; evo-x2's full assertions list is NOT forced
              # here — on the enabled shape it realizes the monitor365
              # prepared-source context, which cannot build (private crate).
              borg-restore-drill-fixture =
                let
                  pinMessage = "borg-restore-drill env-path pin";
                  failingPin =
                    assertions:
                    builtins.filter (
                      a: !a.assertion && lib.hasInfix pinMessage a.message
                    ) assertions;
                  pinAssertionsOf =
                    modules:
                    (inputs.nixpkgs.lib.nixosSystem {
                      inherit system;
                      modules = modules;
                    }).config.assertions;

                  scriptAnchor = "drillScript = builtins.readFile ../../../scripts/borg-restore-drill.sh;";
                  backupSrc = builtins.readFile ./platforms/nixos/system/backup.nix;
                  driftedScriptFile = builtins.toFile "borg-restore-drill-drifted.sh" (
                    lib.replaceStrings
                      [ "/run/secrets/rendered/borg-env" ]
                      [ "/run/secrets/rendered/borg-env-DRIFT" ]
                      (builtins.readFile ./scripts/borg-restore-drill.sh)
                  );
                  driftedBackupSrc = lib.replaceStrings
                    [ scriptAnchor ]
                    [ "drillScript = builtins.readFile ${toString driftedScriptFile};" ]
                    backupSrc;
                  driftedModule = import (builtins.toFile "backup-drifted.nix" driftedBackupSrc);

                  # enable=true + declared template so the guard consults the
                  # template's .path (while dormant it pins the sops-nix
                  # default shape, making a path override inert).
                  templateOverrideModules = [
                    inputs.self.nixosModules.integration
                    inputs.sops-nix.nixosModules.sops
                    ./platforms/nixos/system/backup.nix
                    {
                      services.offsite-borg.enable = true;
                      sops.templates."borg-env".content = "BORG_REPO=x";
                      sops.templates."borg-env".path =
                        lib.mkOverride 50 "/run/secrets/rendered/borg-env-DRIFT";
                    }
                  ];

                  controlFailing = failingPin (pinAssertionsOf [
                    inputs.self.nixosModules.integration
                    ./platforms/nixos/system/backup.nix
                  ]);
                  scriptDriftFailing = failingPin (pinAssertionsOf [
                    inputs.self.nixosModules.integration
                    driftedModule
                  ]);
                  templateDriftFailing = failingPin (pinAssertionsOf templateOverrideModules);

                  pinGuards =
                    if driftedBackupSrc == backupSrc then
                      throw "borg-restore-drill-fixture: env-pin negative-case anchor no longer matches platforms/nixos/system/backup.nix — update scriptAnchor in the fixture"
                    else
                      assert controlFailing == [ ];
                      assert scriptDriftFailing != [ ];
                      assert lib.hasInfix
                        ''BORG_ENV_FILE="''${BORG_ENV_FILE:-/run/secrets/rendered/borg-env}"''
                        (builtins.head scriptDriftFailing).message;
                      assert templateDriftFailing != [ ];
                      assert lib.hasInfix "borg-env-DRIFT" (builtins.head templateDriftFailing).message;
                      true;
                in
                builtins.deepSeq pinGuards (
                  pkgs.runCommand "borg-restore-drill-fixture"
                  {
                    nativeBuildInputs = with pkgs; [
                      bash
                      coreutils
                      gnugrep
                      gnused
                    ];
                  }
                  ''
                    set -euo pipefail
                    FIX=$(mktemp -d)
                    BIN="$FIX/bin"; mkdir -p "$BIN"
                    ROOT="$FIX/root"; ROOTBIN="$ROOT/bin"; mkdir -p "$ROOTBIN"
                    export XDG_STATE_HOME="$FIX/state"; mkdir -p "$XDG_STATE_HOME"
                    export STUB_NIX_OUT="$ROOT"

                    # ---- nix stub: the drill resolves borg through
                    # `nix build --no-link --print-out-paths --impure`; the
                    # stub prints the stub tree (bin/borg lives there).
                    cat > "$BIN/nix" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    echo "''${STUB_NIX_OUT:?STUB_NIX_OUT unset}"
                    STUBEOF

                    # ---- id stub: real mode's `[ "$(id -u)" -eq 0 ]` gate.
                    # STUB_ROOT=1 fakes root for the env-file die cases;
                    # unset → uid 1000 → the root-gate die (same observable
                    # outcome as the sandbox's real non-root builder).
                    cat > "$BIN/id" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    if [ "''${1:-}" = "-u" ]; then
                      if [ -n "''${STUB_ROOT:-}" ]; then echo 0; else echo 1000; fi
                      exit 0
                    fi
                    echo "uid=1000(fixture)"; exit 0
                    STUBEOF

                    # ---- borg stub: version/list/extract covering the
                    # drill's exact call shapes. extract writes the subset
                    # files into its CWD (the drill's scratch dir).
                    cat > "$ROOTBIN/borg" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    cmd="''${1:-}"
                    case "$cmd" in
                      --version) echo "borg 1.4.5-fixture-stub"; exit 0 ;;
                      list)
                        if [ "''${2:-}" = "--last" ]; then
                          echo "fixture-archive-$(date -u +%Y%m%d%H%M%S)  $(date -u +%Y-%m-%dT%H:%M:%S)  0000000000000000000000000000000000000000000000000000000000000000"
                        else
                          echo "fixture-archive-pinned  $(date -u +%Y-%m-%dT%H:%M:%S)  0000000000000000000000000000000000000000000000000000000000000000"
                        fi
                        exit 0 ;;
                      extract)
                        shift
                        dry=0; paths=()
                        while [ $# -gt 0 ]; do
                          case "$1" in
                            --list) shift ;;
                            --dry-run|--verify-data) [ "$1" = "--dry-run" ] && dry=1; shift ;;
                            ::*) shift ;;
                            *) paths+=("''$1"); shift ;;
                          esac
                        done
                        [ "$dry" = 1 ] && exit 0
                        for p in "''${paths[@]}"; do
                          mkdir -p "$(dirname "$p")"
                          printf 'borg-restore-drill-fixture: %s\n' "$p" > "$p"
                        done
                        exit 0 ;;
                      *) echo "borg stub: unhandled subcommand: $cmd" >&2; exit 2 ;;
                    esac
                    STUBEOF
                    chmod +x "$BIN/nix" "$BIN/id" "$ROOTBIN/borg"
                    export PATH="$ROOT/bin:$BIN:$PATH"

                    DRILL="$FIX/borg-restore-drill.sh"
                    cp ${./scripts/borg-restore-drill.sh} "$DRILL"
                    chmod +x "$DRILL"

                    rc=0; capt=""
                    run() { capt=$(bash "$DRILL" "''$@" 2>&1) && rc=0 || rc=$?; }
                    need_rc() { [ "$rc" = "$2" ] || { echo "FAIL $1: rc=$rc want $2"; printf '%s\n' "$capt"; exit 1; }; }
                    need_has() { printf '%s\n' "$capt" | grep -qF -- "$2" || { echo "FAIL $1: missing text: $2"; printf '%s\n' "$capt"; exit 1; }; }

                    # 1) real mode as non-root → root-gate die (record still
                    #    written: the header promises one from early deaths).
                    run; need_rc root-gate 1; need_has root-gate "real-repo mode needs root"
                    R=$(ls -1t "$XDG_STATE_HOME"/borg-restore-drill/drill-*.log | head -1)
                    grep -qF "result           : FAIL" "$R" || { echo "FAIL root-gate: no FAIL record"; cat "$R"; exit 1; }

                    # 2) bogus --local → die before any repo access
                    run --local "$FIX/does-not-exist"; need_rc bogus-local 1; need_has bogus-local "--local repo dir not found"

                    # 3) --local repo without a borg 'config' file
                    mkdir -p "$FIX/empty-repo"
                    run --local "$FIX/empty-repo"; need_rc no-config 1; need_has no-config "no borg 'config' file"

                    # 4) real mode, faked root, fixture env file with the
                    #    go-live PLACEHOLDER → tripwire die
                    ENVF="$FIX/borg-env"; printf 'BORG_REPO=ssh://PLACEHOLDER@example:23/./repo\n' > "$ENVF"
                    export BORG_ENV_FILE="$ENVF" STUB_ROOT=1
                    run; need_rc placeholder 1; need_has placeholder "go-live placeholder"

                    # 5) real mode, non-placeholder repo → the
                    #    /run/secrets/* existence checks fail (mountpoint
                    #    gate's direct predecessor; see header note)
                    printf 'BORG_REPO=ssh://user@host.example:23/./repo\n' > "$ENVF"
                    run; need_rc secrets-missing 1; need_has secrets-missing "/run/secrets/borg_password missing"
                    unset BORG_ENV_FILE STUB_ROOT

                    # 6) happy path: --local against a stub repo → PASS,
                    #    subset extracted + byte-verified, record says PASS
                    REPO="$FIX/repo"; mkdir -p "$REPO"; : > "$REPO/config"
                    run --local "$REPO"; need_rc happy-local 0; need_has happy-local "result           : PASS"
                    need_has happy-local "etc/hostname"
                    R=$(ls -1t "$XDG_STATE_HOME"/borg-restore-drill/drill-*.log | head -1)
                    grep -qF "result           : PASS" "$R" || { echo "FAIL happy-local: record not PASS"; cat "$R"; exit 1; }

                    # 7) --verify-data deep-integrity branch (stub --help has
                    #    no borg2 flag → 1.x --dry-run fallback) + --archive pin
                    run --local "$REPO" --verify-data --archive fixture-archive-pinned
                    need_rc deep 0; need_has deep "deep-integrity: OK"
                    need_has deep "result           : PASS"

                    # 8) mutation NEGATIVE (2026-09-25 storage TODO): a drill
                    #    COPY with the root gate neutered (test → `true`) must
                    #    FAIL case 1's assertion — proves this fixture
                    #    exercises the real script content instead of passing
                    #    vacuously (behavioral twin of negative-test-lints).
                    #    Anchor-drift-guarded: a sed that no longer matches
                    #    makes the "mutation" a silent no-op phantom, so the
                    #    case fails loudly instead.
                    MUT="$FIX/borg-restore-drill-mutated.sh"
                    sed 's/^\([[:space:]]*\)\[ "\$(id -u)" -eq 0 \]/\1true/' "$DRILL" > "$MUT"
                    grep -qF 'true ||' "$MUT" || { echo "FAIL mutation-negative: sed anchor no longer matches the root-gate line — mutation is a no-op"; exit 1; }
                    if grep -qF '[ "$(id -u)" -eq 0 ]' "$MUT"; then
                      echo "FAIL mutation-negative: root-gate test still present in mutated copy"
                      exit 1
                    fi
                    DRILL="$MUT"
                    run
                    DRILL="$FIX/borg-restore-drill.sh"
                    # uid-1000 stub + BORG_ENV_FILE unset → the neutered gate
                    # lets the run proceed one gate FURTHER: rc 1 (a die
                    # fired) with the env-file message PRESENT and the
                    # root-gate message ABSENT — the full inversion of
                    # case 1.
                    need_rc mutation-negative 1
                    if printf '%s\n' "$capt" | grep -qF "real-repo mode needs root"; then
                      echo "FAIL mutation-negative: root-gate die still fired on the mutated copy — fixture insensitive to script content"
                      printf '%s\n' "$capt"
                      exit 1
                    fi
                    need_has mutation-negative "rendered borg env not readable"

                    echo "PASS: borg-restore-drill fixture (root-gate, bogus-local, no-config, placeholder, secrets-missing, happy-local, verify-data, env-pin-drift, mutation-negative)" > "$out"
                  ''
                );

              # Behavioral fixture for the browser-history probe-registration
              # purge (2026-09-18 gate-verification residue). Runs the REAL
              # built script (its runtimeInputs supply the real sqlite3) —
              # no stubs — against a scratch DB seeded with the true schemas:
              # events (go-cqrs-lite sqlite dialect) + users_view (cqrs-htmx
              # usermgmt AutoMapperWithTombstone). Covers: email-scoped delete
              # incl. BLOB payloads (the CAST path), decoy survival, marker
              # lifecycle (created on success only), idempotent re-run, the
              # missing-db clean-skip, and argv guards (empty email).
              # The unit WIRING (ExecStartPre entry + non-fatal "-" prefix,
              # without clobbering the OIDC gate's entry) is pinned by the
              # self-assertion inside browser-history.nix's purge block.
              browser-history-probe-purge-fixture =
                pkgs.runCommand "browser-history-probe-purge-fixture"
                  {
                    nativeBuildInputs = with pkgs; [
                      sqlite
                      coreutils
                      gnugrep
                    ];
                    purgeBin =
                      lib.getExe
                        (import ./modules/nixos/services/_browser-history-scripts.nix { inherit pkgs; })
                        .probeRegistrationPurge;
                  }
                  ''
                    set -euo pipefail
                    FIX=$(mktemp -d)
                    STATE="$FIX/state"; mkdir -p "$STATE"
                    DB="$STATE/data.db"
                    PROBE='probe-gate@example.com'

                    sqlite3 "$DB" "
                    CREATE TABLE IF NOT EXISTS events (
                      id TEXT PRIMARY KEY, event_type TEXT NOT NULL, aggregate_type TEXT NOT NULL,
                      aggregate_id TEXT NOT NULL, version INTEGER NOT NULL,
                      schema_version INTEGER NOT NULL DEFAULT 1, payload BLOB,
                      payload_encoding TEXT NOT NULL DEFAULT 'json', metadata TEXT,
                      occurred_at TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT (datetime('now')),
                      UNIQUE(aggregate_type, aggregate_id, version));
                    CREATE TABLE IF NOT EXISTS users_view (
                      key TEXT PRIMARY KEY, email TEXT, display_name TEXT, email_verified INTEGER,
                      totp_enabled INTEGER, created_at TEXT, updated_at TEXT, data TEXT, tombstoned INTEGER);
                    "
                    sqlite3 "$DB" "
                    INSERT INTO events (id,event_type,aggregate_type,aggregate_id,version,payload,occurred_at) VALUES
                     ('evt-probe','UserRegistered','User','u-probe',1,'{\"schema_version\":1,\"email\":\"probe-gate@example.com\",\"roles\":[]}','2026-09-18T03:00:00Z'),
                     ('evt-probe-blob','UserRegistered','User','u-probe2',1,CAST('{\"email\":\"probe-gate@example.com\"}' AS BLOB),'2026-09-18T03:00:00Z'),
                     ('evt-decoy','UserRegistered','User','u-decoy',1,'{\"email\":\"other@example.com\"}','2026-09-18T03:00:00Z'),
                     ('evt-other','VisitSaved','Visit','v1',1,'{}','2026-09-18T03:00:00Z');
                    INSERT INTO users_view (key,email,display_name,tombstoned) VALUES
                     ('u-probe','probe-gate@example.com','Probe',0),
                     ('u-decoy','other@example.com','Other',0);
                    "

                    run() { STATE_DIRECTORY="$1" "$purgeBin" "$PROBE" >"$FIX/out" 2>&1; }

                    if STATE_DIRECTORY="$STATE" "$purgeBin" >/dev/null 2>&1; then
                      echo 'FAIL: empty argv must be refused'; exit 1
                    fi

                    run "$STATE"
                    grep -q 'events_deleted=2' "$FIX/out" || { echo 'FAIL: events_deleted != 2'; cat "$FIX/out"; exit 1; }
                    grep -q 'users_view_deleted=1' "$FIX/out" || { echo 'FAIL: users_view_deleted != 1'; cat "$FIX/out"; exit 1; }
                    c=$(sqlite3 "$DB" "SELECT count(*) FROM events WHERE event_type='UserRegistered';")
                    [ "$c" = "1" ] || { echo "FAIL: decoy UserRegistered must survive, got $c"; exit 1; }
                    c=$(sqlite3 "$DB" "SELECT count(*) FROM events WHERE event_type='UserRegistered' AND CAST(payload AS TEXT) LIKE '%probe-gate%';")
                    [ "$c" = "0" ] || { echo 'FAIL: probe events remain'; exit 1; }
                    c=$(sqlite3 "$DB" "SELECT count(*) FROM users_view;")
                    [ "$c" = "1" ] || { echo 'FAIL: users_view decoy must survive'; exit 1; }
                    c=$(sqlite3 "$DB" "SELECT count(*) FROM events;")
                    [ "$c" = "2" ] || { echo 'FAIL: non-registration events must survive'; exit 1; }
                    has_marker() { find "$1" -maxdepth 1 -name '.probe-registration-purged-*' -print -quit | grep -q .; }
                    # NOTE: find, not a bare ls-glob — stdenv runs check
                    # scripts with nullglob, so a non-matching marker glob
                    # silently expands to nothing and `ls` lists the CWD
                    # (the 2026-08-27 nullglob phantom-verdict class).
                    has_marker "$STATE" || { echo 'FAIL: marker missing'; exit 1; }

                    run "$STATE"
                    c=$(sqlite3 "$DB" "SELECT count(*) FROM events;")
                    [ "$c" = "2" ] || { echo 'FAIL: second run mutated state'; exit 1; }

                    STATE3="$FIX/state3"; mkdir -p "$STATE3"
                    run "$STATE3"
                    has_marker "$STATE3" && { echo 'FAIL: marker without db'; exit 1; }

                    STATE2="$FIX/state2"; mkdir -p "$STATE2"; echo notadb > "$STATE2/data.db"
                    if run "$STATE2"; then echo 'FAIL: corrupt db must fail'; exit 1; fi
                    has_marker "$STATE2" && { echo 'FAIL: marker on failure'; exit 1; }

                    echo 'PASS: browser-history probe-purge fixture' > "$out"
                  '';

              # Fixture test for scripts/migrate-forgejo-subvol.sh guard
              # branches (plan M02 debt): the REAL script against stubbed
              # btrfs/systemctl/chown (plain bash script — PATH stubs work
              # directly) with env-overridden state/subvol dirs and REAL
              # rsync/checksum verification.
              migrate-forgejo-subvol-fixture =
                pkgs.runCommand "migrate-forgejo-subvol-fixture"
                  {
                    nativeBuildInputs = with pkgs; [
                      bash
                      rsync
                      gawk
                      coreutils
                      gnused
                      findutils
                      gnugrep
                      diffutils
                    ];
                  }
                  ''
                    set -euo pipefail
                    FIX=$(mktemp -d)
                    STUB_BIN="$FIX/stub-bin"; mkdir -p "$STUB_BIN"

                    cat > "$STUB_BIN/btrfs" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    # btrfs subvolume <show|create> <path>: path is $3
                    cmd="''${1:-}/''${2:-}"; path="''${3:-}"
                    case "$cmd" in
                      subvolume/show) [ -f "$path.created" ] && exit 0; exit 1 ;;
                      subvolume/create) mkdir -p "$path" && touch "$path.created"; exit 0 ;;
                    esac
                    exit 1
                    STUBEOF
                    chmod +x "$STUB_BIN/btrfs"

                    cat > "$STUB_BIN/systemctl" <<'STUBEOF'
                    #!${pkgs.bash}/bin/bash
                    # is-active --quiet <unit>: mnt-hot.mount active unless
                    # STUB_MOUNT_DOWN=1; family units active iff
                    # STUB_FAMILY_ACTIVE=1; everything else inactive.
                    if [ "''${1:-}" = "is-active" ]; then
                      unit="''${3:-}"
                      if [ "$unit" = "mnt-hot.mount" ]; then
                        [ "''${STUB_MOUNT_DOWN:-0}" = 1 ] && exit 3
                        exit 0
                      fi
                      case "$unit" in
                        forgejo*) [ "''${STUB_FAMILY_ACTIVE:-0}" = 1 ] && exit 0; exit 3 ;;
                      esac
                      exit 3
                    fi
                    exit 0
                    STUBEOF
                    chmod +x "$STUB_BIN/systemctl"

                    printf '#!${pkgs.bash}/bin/bash\nexit 0\n' > "$STUB_BIN/chown"
                    chmod +x "$STUB_BIN/chown"

                    export PATH="$STUB_BIN:$PATH"
                    SCRIPT=${./scripts/migrate-forgejo-subvol.sh}
                    rc=0; capt=""
                    # NOTE: capture var is `capt` — `out` is RESERVED (the
                    # derivation output path); shadowing it made the final
                    # `echo PASS > "$out"` redirect into a garbage filename.
                    run() { capt=$(env MIGRATE_FORGEJO_STATE_DIR="$STATE" MIGRATE_FORGEJO_SUBVOL="$SUBVOL" bash "$SCRIPT" "$@" 2>&1) && rc=0 || rc=$?; }
                    need_rc() { [ "$rc" = "$2" ] || { echo "FAIL $1: rc=$rc want $2"; printf '%s\n' "$capt"; exit 1; }; }
                    need_has() { printf '%s\n' "$capt" | grep -qF "$2" || { echo "FAIL $1: missing text: $2"; printf '%s\n' "$capt"; exit 1; }; }

                    fresh() {
                      ROOT="$FIX/''${1:-case}"
                      rm -rf "$ROOT"
                      STATE="$ROOT/var-lib-forgejo"
                      SUBVOL="$ROOT/mnt-hot-hot-forgejo"
                      mkdir -p "$STATE/data" "$SUBVOL"
                      for i in $(seq 1 30); do
                        printf 'content-%s\n' "$i" > "$STATE/data/file-$i"
                      done
                    }

                    # 1. mount down -> prepare refuses
                    fresh mountdown
                    export STUB_MOUNT_DOWN=1
                    run prepare; need_rc mountdown 1; need_has mountdown "not mounted"
                    unset STUB_MOUNT_DOWN

                    # 2. prepare happy + idempotent
                    fresh prep
                    run prepare; need_rc prep 0; need_has prep "prepare done"
                    run prepare; need_rc prep2 0; need_has prep2 "subvol already exists"

                    # 3. finalize without prepare (empty subvol) refuses
                    fresh noprep
                    run finalize; need_rc noprep 1; need_has noprep "run" # mentions prepare requirement
                    printf '%s\n' "$capt" | grep -qi "prepare" || { echo "FAIL noprep: message lacks prepare hint"; exit 1; }

                    # 4. finalize with family active refuses
                    fresh fam
                    run prepare >/dev/null
                    export STUB_FAMILY_ACTIVE=1
                    run finalize; need_rc fam 1; need_has fam "still active"
                    unset STUB_FAMILY_ACTIVE

                    # 5. dry-run: plan only, no swap
                    fresh dry
                    run prepare >/dev/null
                    run finalize --dry-run; need_rc dry 0; need_has dry "DRY RUN"
                    [ -d "$STATE/data" ] || { echo "FAIL dry: state mutated"; exit 1; }
                    [ ! -e "$STATE.qlc-pre-subvol" ] || { echo "FAIL dry: safety copy created"; exit 1; }

                    # 6. happy finalize: verify + swap
                    fresh fin
                    run prepare >/dev/null
                    run finalize; need_rc fin 0; need_has fin "finalize DONE"
                    [ -d "$STATE.qlc-pre-subvol/data" ] || { echo "FAIL fin: safety copy missing"; exit 1; }
                    [ -d "$STATE" ] || { echo "FAIL fin: new mountpoint missing"; exit 1; }
                    [ -z "$(ls -A "$STATE")" ] || { echo "FAIL fin: mountpoint not empty"; exit 1; }
                    diff -r "$STATE.qlc-pre-subvol" "$SUBVOL" >/dev/null || { echo "FAIL fin: safety copy != subvol"; exit 1; }

                    # 7. verification guard: tamper the destination with
                    # IDENTICAL size and mtime so rsync's quick-check SKIPS
                    # the file — the sampled checksum must then catch it and
                    # refuse the swap (a plain tamper would just be healed by
                    # the delta rsync before verification runs).
                    fresh corrupt
                    run prepare >/dev/null
                    printf 'content-X\n' > "$SUBVOL/data/file-1"
                    touch -r "$STATE/data/file-1" "$SUBVOL/data/file-1"
                    run finalize; need_rc corrupt 1; need_has corrupt "checksum mismatch"
                    [ -d "$STATE/data" ] || { echo "FAIL corrupt: source was moved despite mismatch"; exit 1; }
                    [ ! -e "$STATE.qlc-pre-subvol" ] || { echo "FAIL corrupt: swapped despite mismatch"; exit 1; }

                    echo "PASS: migrate-forgejo-subvol guard branches" > "$out"
                  '';

              # Gatus pat() uses GLOB, not regex. Chars ? and + have
              # different meanings in glob (? = single-char wildcard) vs
              # regex (? = optional quantifier), causing silent false
              # negatives in health checks. { is allowed — Prometheus
              # labels use {label="value"} syntax.
              # Scope: ALL auto-discovered module files, not just
              # gatus-config.nix — since the services.integration registry
              # (2026-09-14), gatus endpoint conditions are authored in the
              # OWNING service modules (entry checks / extraEndpoints), and
              # pat() anywhere crosses the same Nix→YAML→Go glob layers.
              # The method lint stays gatus-config-scoped: mkHttpCheck and
              # the registry checks submodule expose no method field, so
              # method = "..." outside gatus-config.nix is not a gatus value.
              gatus-pattern-lint =
                let
                  gatusFiles = lib.filter (lib.hasSuffix ".nix") (lib.filesystem.listFilesRecursive ./modules/nixos);
                in
                pkgs.runCommand "gatus-pattern-lint" { } ''
                  files="${lib.concatStringsSep " " gatusFiles}"
                  for f in $files; do
                    if grep -v '^[[:space:]]*#' "$f" | grep -nE 'pat\(.*[?+]'; then
                      echo "FAIL: Gatus pat() patterns contain regex-only chars (? or +) in $f."
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
                    if grep -v '^[[:space:]]*#' "$f" | grep -nE 'pat\(\*[a-z_0-9]+ 1\*\)'; then
                      echo "FAIL: bare pat(*<metric> 1*) conditions match the metric's own HELP comment (in $f)."
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
                    if grep -v '^[[:space:]]*#' "$f" | grep -nE 'pat\(.*\\\\n'; then
                      echo "FAIL: pat() contains a literal backslash-n (nix source \"\\\\n\") in $f."
                      echo "filepath.Match treats '\\' as an ESCAPE, so this glob matches only the letter 'n'"
                      echo "and the condition can never match a real body. Write the newline as single-"
                      echo "backslash \"\\n\" in the double-quoted nix string — see gatus-config.nix anchored forms."
                      exit 1
                    fi
                  done
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

              # The pre-deploy §10 metric-absence classifier decides whether a
              # deploy is BLOCKED — twice on 2026-09-02 the downgrade branches
              # (node_textfile_scrape_error, forgejo scan-failed) had no tests
              # and blocked the deploy carrying their own fix. This check runs
              # the fixture selftest THROUGH nix so the tested artifact is the
              # same file pre-deploy-check.sh sources (never trust a script
              # test that greps its own copy).
              pre-deploy-metrics-selftest = pkgs.runCommand "pre-deploy-metrics-selftest" { } ''
                # Stage the repo layout the test script sources from
                # (it resolves scripts/lib/ relative to its own path — a bare
                # store file has no sibling lib).
                scratch=$(mktemp -d)
                mkdir -p "$scratch/scripts/lib"
                cp ${./scripts/test-pre-deploy-metrics.sh} "$scratch/scripts/test-pre-deploy-metrics.sh"
                cp ${./scripts/lib/metrics-gate.sh} "$scratch/scripts/lib/metrics-gate.sh"
                ${pkgs.bash}/bin/bash "$scratch/scripts/test-pre-deploy-metrics.sh"
                touch $out
              '';

              # The pre-commit hook's shellcheck leg is the stricter bar
              # (warning; CI's shellcheck job is error-level) but only fires
              # on STAGED files — this fixture proves it end-to-end so
              # "did shellcheck run when X first staged" (2026-09-23 borg
              # drill question) never has to be re-asked: positive run
              # against the REAL hook + a negative mutation (the leg's
              # fail-closed branch removed MUST fail the fixture's S5
              # assert). SHELLCHECK_BIN is pinned because `nix shell`
              # cannot run inside a build sandbox; on the host the test
              # defaults to the hook's exact invocation.
              precommit-shellcheck-leg-selftest =
                pkgs.runCommand "precommit-shellcheck-leg-selftest"
                  {
                    nativeBuildInputs = [
                      pkgs.git
                      pkgs.shellcheck
                    ];
                  }
                  ''
                    scratch=$(mktemp -d)
                    cp ${./scripts/test-precommit-shellcheck.sh} "$scratch/test.sh"
                    export SHELLCHECK_BIN=${pkgs.shellcheck}/bin/shellcheck
                    # The script copied to scratch cannot discover the repo,
                    # so pin the hook for the positive run too.
                    cp ${./.githooks/pre-commit} "$scratch/real-hook"
                    PRECOMMIT_HOOK="$scratch/real-hook" bash "$scratch/test.sh"
                    sed 's/all_passed=false/all_passed=true/' "$scratch/real-hook" > "$scratch/mutated-hook"
                    if PRECOMMIT_HOOK="$scratch/mutated-hook" bash "$scratch/test.sh" > "$scratch/mut.log" 2>&1; then
                      echo "FAIL: mutated hook (fail-closed branch removed) passed the fixture"
                      cat "$scratch/mut.log"
                      exit 1
                    fi
                    grep -q "S5 leg no longer fail-closed" "$scratch/mut.log" || {
                      echo "FAIL: mutation caught but not by the S5 assert"
                      cat "$scratch/mut.log"
                      exit 1
                    }
                    touch $out
                  '';

              # The post-deploy pressure verdicts must never call a storm
              # healthy (2026-09-02: PASS at memory PSI avg10 48-77% during
              # the evening storm). Fixture-driven through the SAME
              # scripts/lib/pressure-report.sh post-deploy-check.sh sources.
              post-deploy-pressure-selftest = pkgs.runCommand "post-deploy-pressure-selftest" { } ''
                scratch=$(mktemp -d)
                mkdir -p "$scratch/scripts/lib"
                cp ${./scripts/test-post-deploy-pressure.sh} "$scratch/scripts/test-post-deploy-pressure.sh"
                cp ${./scripts/lib/pressure-report.sh} "$scratch/scripts/lib/pressure-report.sh"
                ${pkgs.bash}/bin/bash "$scratch/scripts/test-post-deploy-pressure.sh"
                touch $out
              '';
              # The offsite-borg §13/§16 smoke verdicts BLOCK the go-live
              # deploy (and FAIL the post-deploy smoke); the blocks only fire
              # for real once services.offsite-borg.enable flips, so the
              # fixture is the ONLY pre-go-live exercise they get. Runs the
              # SAME scripts/lib/offsite-borg-smoke.sh the gates source
              # (never a drifted copy).
              offsite-borg-smoke-selftest =
                pkgs.runCommand "offsite-borg-smoke-selftest"
                  {
                    nativeBuildInputs = [ pkgs.jq ];
                  }
                  ''
                    scratch=$(mktemp -d)
                    mkdir -p "$scratch/scripts/lib"
                    cp ${./scripts/test-offsite-borg-smoke.sh} "$scratch/scripts/test-offsite-borg-smoke.sh"
                    cp ${./scripts/lib/offsite-borg-smoke.sh} "$scratch/scripts/lib/offsite-borg-smoke.sh"
                    ${pkgs.bash}/bin/bash "$scratch/scripts/test-offsite-borg-smoke.sh"
                    touch $out
                  '';

              # Offsite-borg positive-path render guard (2026-09-24 queue:
              # persists the 2026-09-23 §a6 hand probe that otherwise had to
              # be re-run at every dispatch). Renders evo-x2 with
              # services.offsite-borg.enable = true and asserts the FOUR
              # go-live deliverables land on the job unit at EVAL time:
              # BE/6 IO tier (the ioTier.background mkForce intact — both a
              # dropped force and a re-collide-to-nixpkgs-idle fail), the
              # go-live tripwire ExecStartPre, the .last_success freshness
              # marker ExecStartPost, and the borg-env EnvironmentFile
              # (compared against the sops template's own .path, so drift on
              # either side fails). Pure eval — fires on every
              # `nix flake check`, including --no-build (asserts run when
              # the check attr is forced; deepSeq pattern of
              # disko-samsung-tlc). The priority-50 override is required:
              # configuration.nix sets enable = false as a PLAIN value
              # (status report 2026-09-23_10-05 §a6).
              offsite-borg-positive-render =
                let
                  sys = inputs.self.nixosConfigurations.evo-x2.extendModules {
                    modules = [
                      {
                        services.offsite-borg.enable = lib.mkOverride 50 true;
                      }
                    ];
                  };
                  svc = sys.config.systemd.services.borgbackup-job-hetzner.serviceConfig;
                  envTemplate = sys.config.sops.templates."borg-env".path;
                  # Exec* lines render as a single string today; tolerate a
                  # list in case nixpkgs' borgbackup module ever merges its
                  # own Exec entries.
                  execLines = x: if lib.isList x then lib.concatStringsSep "\n" x else toString x;
                  renderGuards =
                    assert svc.IOSchedulingClass == "best-effort";
                    assert toString svc.IOSchedulingPriority == "6";
                    assert lib.hasInfix "borg-offsite-golive-check" (execLines svc.ExecStartPre);
                    assert lib.hasInfix "/var/lib/borg-offsite/.last_success" (execLines svc.ExecStartPost);
                    assert execLines svc.EnvironmentFile == envTemplate;
                    assert lib.hasSuffix "borg-env" envTemplate;
                    true;
                in
                builtins.deepSeq renderGuards (
                  pkgs.runCommand "offsite-borg-positive-render-check" { } ''
                    echo "offsite-borg positive-path render OK (BE/6 + tripwire + marker + borg-env)" > $out
                  ''
                );

              # Auto-discovered modules under modules/nixos/{services,desktop}/
              # are flake-parts wrappers: filename -> flake.nixosModules.<filename>.
              # A bare NixOS module evaluates its let-bindings in the WRONG
              # context and contributes NOTHING to hosts — no options, no
              # assertions, silently (2026-08-31 live: signoz-coverage shipped
              # bare; every nix command failed until a concurrent session
              # wrapped it, commit d7237d6c).
              module-shape-lint = pkgs.runCommand "module-shape-lint" { } ''
                fail=0
                for dir in ${./modules/nixos/services} ${./modules/nixos/desktop}; do
                  for f in "$dir"/*.nix; do
                    [ -e "$f" ] || continue
                    base=$(basename "$f")
                    case "$base" in _*) continue ;; esac
                    name="''${base%.nix}"
                    # Anchor on the ` =` of the declaration: a bare \b word
                    # boundary accepts RENAMED keys too (negative-test-lints
                    # caught it: `flake.nixosModules.caddy-mutant =` satisfied
                    # the `caddy\b` grep — hyphen is a boundary).
                    if ! grep -q "flake\.nixosModules\.''${name}[[:space:]]*=" "$f"; then
                      echo "FAIL: $base does not declare flake.nixosModules.''${name}"
                      echo "  Auto-discovered modules MUST be flake-parts wrappers; a bare NixOS"
                      echo "  module here evaluates silently and contributes NOTHING to hosts."
                      echo "  Shape: { flake.nixosModules.<filename> = { config, lib, pkgs, ... }: { ... }; }"
                      fail=1
                    fi
                  done
                done
                [ "$fail" -eq 0 ] || exit 1
                touch $out
              '';

              # Dead-guard lint (2026-09-15): writeShellApplication runs
              # errexit+pipefail, so `VAR=$(cmd)` WITHOUT `|| true` EXITS the
              # script when cmd fails — any `[ -z "$VAR" ]` degraded-path
              # guard below is unreachable (live class: website-deploy-monitor
              # failed the unit on every network transient and disk-growth-check
              # 226'd for days, both because the guard could never run).
              # Detection: assignment via command substitution with no
              # `|| true|:|echo|printf|exit` anywhere in the substitution span,
              # followed within 8 lines by a -z/-n guard on the same variable.
              # Exempt a deliberate shape with `# dead-guard-ok` on the line.
              # Heuristic (line-based over .nix sources, not a shell parser):
              # `local x=$(...)` and `[ "$x" = ... ]` guard forms are out of
              # scope for v1 — the fleet sweep validated the FP rate on the
              # real tree.
              dead-guard-lint =
                let
                  lintFiles = builtins.filter (lib.hasSuffix ".nix") (
                    lib.filesystem.listFilesRecursive ./modules
                    ++ lib.filesystem.listFilesRecursive ./platforms
                    ++ lib.filesystem.listFilesRecursive ./lib
                  );
                in
                pkgs.runCommand "dead-guard-lint" { } ''
                  fail=0
                  for f in ${lib.concatStringsSep " " lintFiles}; do
                    awk '
                      { lines[NR] = $0 }
                      END {
                        bad = 0
                        for (lnIdx = 1; lnIdx <= NR; lnIdx++) {
                          line = lines[lnIdx]
                          if (line ~ /# dead-guard-ok/) continue
                          if (match(line, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[[:space:]]*\$\(/)) {
                            # `$((` opens ARITHMETIC expansion, not a command
                            # substitution — `n=$((n + 1))` cannot fail the
                            # capture the way `n=$(cmd)` can (llama-rag
                            # leaked-instance counter, 2026-09-19 FP).
                            if (substr(line, RSTART + RLENGTH, 1) == "(") continue
                            varName = line
                            sub(/^[[:space:]]*/, "", varName)
                            sub(/=[[:space:]]*\$\(.*/, "", varName)
                            depth = 0
                            protected = 0
                            endIdx = lnIdx
                            for (endIdx = lnIdx; endIdx <= NR; endIdx++) {
                              cur = lines[endIdx]
                              # Protection = the failure path is HANDLED inline:
                              # `|| true`/`:`/degraded echo, a rescue
                              # reassignment like `|| val=0`, or the
                              # `VAR=$(cmd) && …` idiom (errexit does not fire
                              # on the left operand of &&/|| — signoz TTL
                              # retry loop shape).
                              if (cur ~ /\|\|[[:space:]]+(true|:|echo|printf|exit|return|break|continue)/) protected = 1
                              if (cur ~ /\|\|[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/) protected = 1
                              if (cur ~ /\|\|[[:space:]]*\{/) protected = 1
                              if (cur ~ /\)[[:space:]]*&&/) protected = 1
                              lineLen = length(cur)
                              for (charIdx = 1; charIdx <= lineLen; charIdx++) {
                                chr = substr(cur, charIdx, 1)
                                if (chr == "(") depth++
                                else if (chr == ")") depth--
                              }
                              if (depth <= 0) break
                            }
                            if (protected) continue
                            windowEnd = endIdx + 8
                            if (windowEnd > NR) windowEnd = NR
                            for (guardIdx = endIdx + 1; guardIdx <= windowEnd; guardIdx++) {
                              gl = lines[guardIdx]
                              if (index(gl, "-z \"$" varName "\"") || index(gl, "-n \"$" varName "\"") || index(gl, "-z \"''${" varName "}") || index(gl, "-n \"''${" varName "}")) {
                                print FILENAME ":" lnIdx ": DEAD GUARD: " varName "=$(...) lacks `|| true` — under errexit the failed capture exits before the [ -z \"$" varName "\" ] guard at line " guardIdx " can run. Add `|| true` (deliberate degradation) or `# dead-guard-ok`."
                                bad = 1
                                break
                              }
                            }
                          }
                        }
                        if (bad) exit 1
                      }
                    ' "$f" || fail=1
                  done
                  if [ "$fail" -ne 0 ]; then
                    echo "FAIL: dead-guard-lint found unreachable degraded-path guards — fix the captures above"
                    exit 1
                  fi
                  touch $out
                '';

              # Textfile-emission guard: a metric echo line without a VALUE
              # makes the node exporter reject the WHOLE .prom file — one
              # value-less line darked all 38 system_* metrics and blocked
              # every deploy (2026-09-02). Fail-level (baseline zero
              # findings at introduction): a snake_case token as the ONLY
              # quoted argument to echo/printf is the value-less shape;
              # append `# emission-ok` to exempt a deliberate one.
              textfile-emission-lint = pkgs.runCommand "textfile-emission-lint" { } ''
                fail=0
                for dir in ${./modules/nixos/services} ${./modules/nixos/desktop}; do
                  for f in "$dir"/*.nix; do
                    [ -e "$f" ] || continue
                    while IFS= read -r line; do
                      echo "$line" | grep -q 'emission-ok' && continue
                      echo "FAIL: $(basename "$f"): value-less metric echo (node exporter rejects the whole .prom):"
                      echo "  $line"
                      fail=1
                    done < <(grep -nE 'echo[[:space:]]+"[a-z][a-z0-9]*(_[a-z0-9]+)+"[[:space:]]*(>>|>[^>]|[[:space:]]*$)' "$f" || true)
                  done
                done
                [ "$fail" -eq 0 ] || exit 1
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
                                        # An empty blocklist makes trap 4's `for m in $metrics`
                                        # silently skip (empty-var for-list = zero iterations, even
                                        # without nullglob) — an emptied deadMetrics list must fail
                                        # LOUD, not phantom-green.
                                        if [ -z "$metrics" ]; then
                                        echo "FAIL: dead-metrics blocklist is empty — trap 4 would be a phantom green."
                                        exit 1
                                        fi
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

                                          # 5. dashboard layout overlaps: the SigNoz v2 validator
                                          # rejects the WHOLE dashboard with HTTP 400
                                          # ("spec.layouts[0].spec.items[N] and items[M] overlap")
                                          # and the provisioner HARD-fails the deploy by design
                                          # (2026-09-16: systemnix-overview Zone 6 panel). Panels
                                          # are rectangles x..x+width, y..y+height on a 12-col
                                          # grid; any pairwise intersection is fatal.
                                          # NOTE: the heredoc body below is written at this
                                          # block's minimal nix-indent level so the terminator
                                          # lands at column 0 after nix strips the common indent
                                          # (an indented terminator never matches and the heredoc
                                          # eats the rest of the script, bash "unexpected EOF").
                                          if ! overlap_out=$(${pkgs.python3}/bin/python3 - <<'PYOVERLAP'
                    import glob, itertools, json, sys
                    bad = 0
                    for f in sorted(glob.glob("${dashboards}/*.json")):
                        items = json.load(open(f))["spec"]["layouts"][0]["spec"]["items"]
                        for a, b in itertools.combinations(items, 2):
                            if (a["x"] < b["x"] + b["width"] and b["x"] < a["x"] + a["width"]
                                    and a["y"] < b["y"] + b["height"] and b["y"] < a["y"] + a["height"]):
                                print("%s: panels (x=%d,y=%d,w=%d,h=%d) and (x=%d,y=%d,w=%d,h=%d) intersect" %
                                      (f, a["x"], a["y"], a["width"], a["height"], b["x"], b["y"], b["width"], b["height"]))
                                bad = 1
                    sys.exit(bad)
                    PYOVERLAP
                    ); then
                                            echo "FAIL: dashboard layout overlap(s):"
                                            echo "$overlap_out"
                                            echo "SigNoz v2 rejects the whole dashboard (HTTP 400) and the provisioner unit"
                                            echo "fails the deploy. Give every panel a disjoint grid rectangle."
                                            exit 1
                                          fi

                                          [ "$fail" -eq 0 ] || exit 1
                                          touch $out
                  '';

              binary-coverage-lint = pkgs.runCommand "binary-coverage-lint" { } ''
                ${binaryCoverageScanner} ${./modules} ${./platforms} ${./lib}
                touch $out
              '';

              # Negative test THROUGH nix (the signoz-query-lint v1 nullglob
              # lesson: never trust an exit-0 check you wrote without proving
              # it fails on the historical bug shape). Fixtures carry the exact
              # incident shapes; the scanner must flag them and stay quiet on
              # the compliant twin.
              binary-coverage-selftest =
                let
                  evilAwk = pkgs.writeText "evil-awk.nix" ''
                    { config, ... }: {
                      systemd.services.evil-balance.serviceConfig.ExecStart =
                        "/bin/sh -c 'btrfs filesystem usage / | awk \"{print \\$3}\"'";
                    }
                  '';
                  evilPython = pkgs.writeText "evil-python.nix" ''
                    { config, ... }: {
                      # NB: single-line text on purpose — nested indented
                      # strings would need triple-quote escaping; a mid-line
                      # python3 mention is exactly what the usage-side grep
                      # sees in real modules.
                      environment.etc."evil-daemon.py".text = "#!/usr/bin/env python3\nimport time\ntime.sleep(3600)\n";
                    }
                  '';
                  goodTwin = pkgs.writeText "good-twin.nix" ''
                    { config, pkgs, ... }: {
                      systemd.services.good-balance = {
                        path = with pkgs; [ gawk btrfs-progs ];
                        serviceConfig.ExecStart = "/bin/sh -c 'btrfs filesystem usage / | awk \"{print \\$3}\"'";
                      };
                      systemd.services.good-daemon = {
                        path = [ pkgs.python3 ];
                        serviceConfig.ExecStart = "/bin/sh -c 'cat /etc/x > /dev/null'";
                        environment.etc."good.py".text = "#!/usr/bin/env python3\n";
                      };
                    }
                  '';
                  evilTree =
                    pkgs.runCommand "evil-tree" { }
                      "mkdir -p $out && cp ${evilAwk} ${evilPython} ${goodTwin} $out/";
                  goodTree = pkgs.runCommand "good-tree" { } "mkdir -p $out && cp ${goodTwin} $out/";
                  scan = tree: "${binaryCoverageScanner} ${tree} 2>&1";
                in
                pkgs.runCommand "binary-coverage-selftest" { } ''
                  # 1. compliant tree must PASS silently
                  if ! res=$( ${scan goodTree} ); then
                    echo "SELFTEST FAIL: scanner flagged the compliant fixture:"; echo "$res"; exit 1
                  fi
                  # 2. evil tree must FAIL and NAME both evil fixtures
                  if res=$( ${scan evilTree} ); then
                    echo "SELFTEST FAIL: scanner passed the evil fixtures (phantom-green lint)"; exit 1
                  fi
                  echo "$res" | grep -q 'evil-awk.nix' || { echo "SELFTEST FAIL: awk rule did not fire"; exit 1; }
                  echo "$res" | grep -q 'evil-python.nix' || { echo "SELFTEST FAIL: python3 rule did not fire"; exit 1; }
                  touch $out
                '';

              # Gitleaks positive-coverage selftest (2026-09-15, closes the
              # 40-hex saga): turns the retracted TODO rows 357/361 claims
              # into tested invariants. CORRECTED ATTRIBUTION (the harvested
              # claim was wrong twice — this selftest's first run caught it):
              # (1) `sq0atp-` keys the SQUARE access-token rule, NOT
              # sourcegraph-access-token; (2) sourcegraph-access-token's
              # bare-40-hex alternative fired with a rule keyword
              # (sgp_/sourcegraph) ANYWHERE in the file — that class
              # false-positived on flake.nix's ~15 `github:` rev pins
              # (2026-09-16: 17 findings blocking every hooked commit), so
              # .gitleaks.toml now OVERRIDES the rule to sgp_-prefixed
              # shapes only; the keyword-armed bare-hex positive became a
              # NEGATIVE (negative-hex-with-keyword.txt) and
              # positive-sourcegraph-local.txt covers the override's
              # sgp_local_ alternative. Fixtures live in
              # tests/fixtures/gitleaks/ with NO path allowlist — gitleaks
              # skips allowlisted paths at the WALKER level (a real token
              # pasted into an allowlisted file would be invisible), so the
              # fixtures must stay clean under the repo config on their
              # own; gitleaks entropy gates need realistic
              # literals (an all-'a' token passes the regex but dies at
              # entropy ≥2 — the original failure of this selftest).
              # Fixture tokens are TEMPLATES, never literals: @HEX40@ is
              # substituted with a deterministic sha256-derived hex at scan
              # time, because GitHub push protection pattern-matches raw
              # blobs and IGNORES .gitleaks.toml allowlists — a literal
              # sgp_ fixture blocked the 2026-09-15 master push (GH013).
              gitleaks-coverage-selftest = pkgs.runCommand "gitleaks-coverage-selftest" { } ''
                set -u
                cfg=${./.gitleaks.toml}
                fixtures=${./tests/fixtures/gitleaks}
                work=$(mktemp -d)
                trap 'rm -rf "$work"' EXIT
                expect_detect() {
                  local fixture="$1" label="$2" d
                  d=$(mktemp -d "$work/d.XXXXXX")
                  cp "$fixtures/$fixture" "$d/"
                  # Expand the @HEX40@ template (no-op where absent): entropy
                  # must stay realistic or the rule's entropy gate kills the
                  # detection this check exists to prove.
                  sed -i "s/@HEX40@/$(printf 'systemnix-gitleaks-coverage-fixture' | sha256sum | cut -c1-40)/" "$d/$fixture"
                  if ${pkgs.gitleaks}/bin/gitleaks detect --no-git --no-banner --source "$d" --config "$cfg" >/dev/null 2>&1; then
                    echo "SELFTEST FAIL: gitleaks did NOT detect $label (fixture: $fixture) — rule dead or fixture drifted (phantom coverage)"
                    exit 1
                  fi
                }
                expect_detect "positive-square.txt" "the sq0atp- Square access-token rule"
                expect_detect "positive-sourcegraph.txt" "the sgp_ sourcegraph access-token rule"
                expect_detect "positive-sourcegraph-local.txt" "the sgp_local_ sourcegraph access-token alternative"
                expect_clean() {
                  local fixture="$1" label="$2" d
                  d=$(mktemp -d "$work/d.XXXXXX")
                  cp "$fixtures/$fixture" "$d/"
                  # SAME template expansion as expect_detect — without it the
                  # negatives are scanned as the literal "@HEX40@" string
                  # (vacuously clean: no hex for any rule to match, and a
                  # corrupted fixture stays undetectable — caught by
                  # scripts/negative-test-lints.sh gitleaks/negative-fixture-corrupt
                  # on 2026-09-15).
                  sed -i "s/@HEX40@/$(printf 'systemnix-gitleaks-coverage-fixture' | sha256sum | cut -c1-40)/" "$d/$fixture"
                  if ! ${pkgs.gitleaks}/bin/gitleaks detect --no-git --no-banner --source "$d" --config "$cfg" >/dev/null 2>&1; then
                    echo "SELFTEST FAIL: $label tripped gitleaks (fixture: $fixture)"
                    ${pkgs.gitleaks}/bin/gitleaks detect --no-git --no-banner --source "$d" --config "$cfg" || true
                    exit 1
                  fi
                }
                expect_clean "negative-bare-hex.txt" "bare low-entropy 40-hex git SHA"
                expect_clean "negative-hex-no-keyword.txt" "HIGH-entropy 40-hex without rule keywords"
                expect_clean "negative-hex-with-keyword.txt" "bare 40-hex with rule keywords (sourcegraph rule overridden — the rev-pin false-positive class)"
                echo "gitleaks coverage: 3 positive classes detected, 3 negative classes clean"
                touch $out
              '';

              # Recursive chown/chmod walks in modules that also configure
              # Bind*Paths: systemd builds the mount namespace BEFORE any
              # ExecStartPre, so a recursive ownership walk descends into the
              # bind (EROFS on read-only binds; cross-filesystem mutation on
              # writable ones). -xdev does NOT protect same-filesystem binds
              # (shared st_dev on one BTRFS subvol) — prune the exact path.
              # FAILING since 2026-09-14 (multiple clean CI cycles passed
              # since the 2026-08-20 hermes incident).
              chown-vs-bind-audit = pkgs.runCommand "chown-vs-bind-audit" { } ''
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
                  echo "FAIL: recursive ownership walks coexist with bind mounts — fix the lines above (find with -prune on the bind target, never chown/chmod -R)"
                  exit 1
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

          apps =
            let
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
              deploy = mkApp "deploy" "Deploy NixOS config to evo-x2 via nh with post-deploy checks" [
                pkgs.nh
                pkgs.systemd
                pkgs.util-linux # flock — concurrent-deploy guard (T13)
                pkgs.procps # ps/pgrep — wedged switch-to-configuration detection
              ] ./scripts/deploy.sh;
              validate = mkApp "validate" "Validate flake without building" [ pkgs.nix ] ./scripts/validate.sh;
              io-psi-forensics =
                mkApp "io-psi-forensics"
                  "Snapshot per-cgroup I/O attribution + D-state stacks to /var/tmp (run during an I/O storm; same script the guard fires on trip)"
                  [
                    pkgs.coreutils
                    pkgs.procps
                    pkgs.gawk
                    pkgs.gnugrep
                    pkgs.findutils
                    pkgs.systemd
                  ]
                  ./scripts/io-psi-forensics.sh;
              fix-nixpkgs-lock =
                mkApp "fix-nixpkgs-lock"
                  "Restore the flake.lock nixpkgs node to github type (one-command recovery from the tarball regression)"
                  [ pkgs.nix pkgs.jq ]
                  ./scripts/fix-nixpkgs-lock.sh;
              pre-deploy-check =
                let
                  # mkApp single-files scripts, but pre-deploy-check.sh
                  # sources scripts/lib/metrics-gate.sh relative to its own
                  # path — package the lib as a sibling so the wrapper's
                  # runtime `source` resolves (2026-09-02: the refactor that
                  # extracted the gate shipped without this and every deploy
                  # aborted at the wrapper's runtime).
                  inner = pkgs.writeShellApplication {
                    name = "pre-deploy-check";
                    runtimeInputs = [
                      pkgs.nix
                      pkgs.jq
                      pkgs.systemd
                    ];
                    text = builtins.readFile ./scripts/pre-deploy-check.sh;
                  };
                in
                {
                  type = "app";
                  program = "${
                    pkgs.runCommand "pre-deploy-check" { } ''
                      mkdir -p $out/bin/lib
                      cp ${inner}/bin/pre-deploy-check $out/bin/pre-deploy-check
                      cp ${./scripts/lib/metrics-gate.sh} $out/bin/lib/metrics-gate.sh
                      # §13 sources the offsite-borg smoke lib the same way;
                      # unstaged = the gate dies at source time on EVERY deploy
                      # (the 2026-09-02 metrics-gate staging class).
                      cp ${./scripts/lib/offsite-borg-smoke.sh} $out/bin/lib/offsite-borg-smoke.sh
                      chmod +x $out/bin/pre-deploy-check
                    ''
                  }/bin/pre-deploy-check";
                  meta.description = "Pre-deploy validation: catches boot-breaking issues before switch";
                };
              post-deploy-check =
                let
                  # Same sibling-lib staging as pre-deploy-check: the script
                  # sources scripts/lib/pressure-report.sh relative to its own
                  # path, so package the lib next to the binary (2026-09-02
                  # 21:57 deploy: the bare mkApp app failed its own build on
                  # shellcheck SC1091/SC2016 and the smoke never ran).
                  inner = pkgs.writeShellApplication {
                    name = "post-deploy-check";
                    runtimeInputs = [
                      pkgs.coreutils # date, wc, head, tr, sleep, id
                      pkgs.curl
                      pkgs.fish
                      pkgs.gawk # lib/pressure-report.sh PSI/zram arithmetic
                      pkgs.glibc # getent
                      pkgs.gnugrep
                      pkgs.jq
                      pkgs.nix
                      pkgs.procps # pgrep
                      pkgs.systemd # systemctl, journalctl
                    ];
                    text = builtins.readFile ./scripts/post-deploy-check.sh;
                  };
                in
                {
                  type = "app";
                  program = "${
                    pkgs.runCommand "post-deploy-check" { } ''
                      mkdir -p $out/bin/lib
                      cp ${inner}/bin/post-deploy-check $out/bin/post-deploy-check
                      cp ${./scripts/lib/pressure-report.sh} $out/bin/lib/pressure-report.sh
                      # §16 sources the shared offsite-borg smoke lib; stage
                      # it like pressure-report.sh or the smoke dies at source
                      # time on every deploy.
                      cp ${./scripts/lib/offsite-borg-smoke.sh} $out/bin/lib/offsite-borg-smoke.sh
                      # The crush smoke section resolves helpers relative to
                      # BASH_SOURCE (the store bin dir), so stage the
                      # rc-test harness too or the check always fails with
                      # "No such file or directory" (2026-09-17 smoke).
                      cp ${./scripts/crush-rc-test.sh} $out/bin/crush-rc-test.sh
                      chmod +x $out/bin/post-deploy-check
                    ''
                  }/bin/post-deploy-check";
                  meta.description = "Post-deploy smoke test: verifies services are functional, not just alive";
                };
              pre-reboot-check =
                mkApp "pre-reboot-check"
                  "Pre-reboot boot-chain audit: loader default -> ESP assets -> init on live store -> three-way profile anchor -> closure sanity -> initrd devices -> GC anchoring (built after the 2026-09-07 stuck boot; hardened 2026-09-09)"
                  [
                    pkgs.btrfs-progs # filesystem show (MISSING device audit)
                    pkgs.coreutils # stat, timeout, dirname, awk-free parsing helpers
                    pkgs.diffutils # cmp (exit-4 predictor unit-file diffing) + boot-mirror tree diff
                    pkgs.efibootmgr # §11: mirror EFI entry / BootOrder audit
                    pkgs.gawk # loader.conf/entry parsing
                    pkgs.gnugrep
                    pkgs.nix # path-info closure sanity + nix-store gc-root queries
                    pkgs.systemd # systemctl (quiet-window advisories, nix-gc timer, bootctl)
                    pkgs.util-linux # findmnt + lsblk (mirror ESP device resolution)
                  ]
                  ./scripts/pre-reboot-check.sh;
              boot-mirror-activate =
                mkApp "boot-mirror-activate"
                  "Switch the firmware boot chain to the Samsung 2nd-boot-disk ESP: ensure its EFI entry exists and order it first (idempotent; QLC entries stay fallback)"
                  [
                    pkgs.coreutils # tr/cut/paste
                    pkgs.efibootmgr
                    pkgs.gnused
                    pkgs.gawk
                    pkgs.gnugrep
                    pkgs.systemd # bootctl is-installed
                    pkgs.util-linux # findmnt + lsblk
                  ]
                  ./scripts/boot-mirror-activate.sh;
              migrate-hot-db =
                mkApp "migrate-hot-db"
                  "User-run migration of a service dataDir onto the Samsung hot-DB tier (services.hot-db): prepare|finalize with pressure gate + verify"
                  [
                    pkgs.bash
                    pkgs.coreutils
                    pkgs.findutils
                    pkgs.gawk
                    pkgs.rsync
                    pkgs.util-linux
                  ]
                  ./scripts/migrate-hot-db.sh;
              btrfs-inventory = mkApp "btrfs-inventory" "List all BTRFS subvolumes, snapshots, and mount points" [
                pkgs.btrfs-progs
                pkgs.util-linux
                pkgs.coreutils
                pkgs.findutils
              ] ./scripts/btrfs-subvolume-inventory.sh;
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
              verify-io-tiers = mkApp "verify-io-tiers" "Verify BFQ I/O priority tiers are correctly applied" [
                pkgs.systemd
                pkgs.procps
              ] ./scripts/verify-io-tiers.sh;
              pocket-id-login-code =
                mkApp "pocket-id-login-code" "Generate a one-time Pocket ID login code for a new device"
                  [ pkgs.curl pkgs.jq ]
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
                    runtimeInputs = [ pkgs.systemd ];
                    text = "systemctl --user restart dms.service && echo 'DMS restarted'";
                  }
                }/bin/dms-restart";
                meta.description = "Restart DankMaterialShell desktop shell";
              };
              dms-locks = {
                type = "app";
                program = "${pkgs.callPackage ./pkgs/dms-lock.nix { inherit (theme) colors; }}/bin/dms-lock";
                meta.description = "Lock screen via DMS IPC (fallback: swaylock-effects with wallpaper + Catppuccin Mocha)";
              };
              dms-wallpaper-next = {
                type = "app";
                program = "${
                  pkgs.writeShellApplication {
                    name = "dms-wallpaper-next";
                    runtimeInputs = [ inputs.dankMaterialShell.packages.${system}.default ];
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
        lib = import ./lib { inherit (nixpkgs) lib; };

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
