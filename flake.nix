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
      # INTERIM: pinned to pre-2026-09-13-update rev (upstream HEAD has a stale
      # vendorHash from source-only churn; no CI to catch it). Drop pin when fixed.
      url = "github:SigNoz/signoz/e0da06f76d6d6a84c4f02fe1f4775d8acae7032f";
      flake = false;
    };
    signoz-collector-src = {
      # INTERIM: pinned to pre-2026-09-13-update rev (stale vendorHash upstream).
      url = "github:SigNoz/signoz-otel-collector/b514eb4a60aab6b2233288052446d33c60ceadec";
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
    # Was INTERIM-pinned to f9f3b335 (2026-09-13: auto-commit left the frozen
    # bun lockfile stale); master verified BUILDABLE at HEAD 2026-09-16
    # (package build probe passed) — pin dropped per the pin policy.
    todo-list-ai = {
      url = "github:LarsArtmann/todo-list-ai?ref=master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # library-policy — Banned/vulnerable library detector for Go projects
    library-policy = {
      # INTERIM: pinned to pre-2026-09-13-update rev (stale vendorHash upstream).
      url = "github:LarsArtmann/library-policy/1bf02c1173caf6c9a77bc873fb993123d89657aa";
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
    # INTERIM git+file since 2026-09-16: the vendorHash refresh for the
    # "go-taskqueue-0.3.0-go-modules hash mismatch" deploy block lives in
    # upstream master (1a4eb48) but the PUSH to origin is BLOCKED by
    # GitHub push protection (a fake, shape-valid Slack token in
    # internal/executor/redact_test.go — redaction-test fixture, 4
    # local-only historical commits). Resolution is the push-protection
    # unblock URL (reason "used in tests"), then FLIP BACK to
    # github:LarsArtmann/go-taskqueue?ref=master. ?rev= is REQUIRED on
    # git+file inputs (dirtyRev trap). CI cannot fetch git+file.
    # go-nix-helpers deliberately NOT followed (bank-sync FOD-mismatch
    # trap): the vendorHash was validated with upstream's locked helper.
    go-taskqueue = {
      url = "git+file:///home/lars/projects/go-taskqueue?rev=1a4eb480367648a7c950df12227db5928a732632";
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
      # Was INTERIM `git+file:///home/lars/projects/BuildFlow` - a local-path
      # pin that broke every CI eval. 9d11c8fee (the stale-vendorHash fix;
      # rev 56dc3660 fails every consumer with a go-modules hash mismatch) is
      # now origin/master HEAD (verified identical via compare API,
      # 2026-09-16). git+ssh fetches on CI via the NIX_DEPLOY_KEY_BUILDFLOW
      # read-only deploy key. Branch-ref governed (pin policy 2026-09-16:
      # ?ref=master as much as possible; the lock holds the exact rev until
      # an explicit update).
      url = "git+ssh://git@github.com/LarsArtmann/BuildFlow?ref=refs/heads/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
      };
    };

    # go-auto-upgrade — Automate Go library upgrades
    go-auto-upgrade = {
      # INTERIM: pinned to pre-2026-09-13-update rev (stale vendorHash upstream).
      url = "github:LarsArtmann/go-auto-upgrade/eb97a8b2bdce894b90a6ba5749c3062beccb0b9c";
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
      # Was INTERIM `git+file:///home/lars/worktrees/go-cqrs-lite-hashfix` - a
      # local-path input that broke every CI eval (same class as art-dupl,
      # 2026-09-15). The vendorHash refresh commit now lives on the pushed
      # branch `cqrs-lint-vendorhash-fix` (d84e4d6a); git+ssh fetches on CI
      # via the deploy key. master still carries the stale hash, so the
      # branch ref stays until master catches up (art-dupl
      # `refs/heads/fork` precedent). Branch-ref governed (pin policy
      # 2026-09-16): the lock holds the exact rev until an explicit update.
      url = "git+ssh://git@github.com/LarsArtmann/go-cqrs-lite?ref=refs/heads/cqrs-lint-vendorhash-fix";
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
      # INTERIM: pinned to pre-2026-09-13-update rev (stale vendorHash upstream).
      url = "github:LarsArtmann/projects-management-automation/9bbc7dfb9ecc02358b1502fbc34a8ffbffed05be";
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
      # INTERIM: pinned to pre-2026-09-13-update rev (stale vendorHash upstream).
      url = "github:LarsArtmann/overview/73738794dcaadc242519e98042c942ab3df96df2";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        go-nix-helpers.follows = "go-nix-helpers";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # DiscordSync — Continuous Discord backup with Turso cloud sync
    # Rev-pinned at c0604e46 (2026-09-05, third lift): febc42a7 → c0604e46
    # brings the command-audit search-corruption fixes (URL-escape +
    # LIKE-wildcard escaping), the storage-growth guild filter, the typed
    # chart pipeline, the stats-rollup per-message WARN flood fix, ingest
    # dispatch logs demoted to Debug, and gofumpt folded into verify.
    # Upstream re-derived vendorHash (sha256-n5OcBbjU+SslcLkZjcZpUDpwOXOWZVy4ZcLfj2CKCMs=)
    # after the daemon's go-health/go-health-dashboard bumps and
    # build-verified in its own flake; the lift followed the hold's own
    # rule: `nix build` of the quick-go batch (discordsync included) ran
    # to COMPLETION in this flake's context BEFORE deploying. Keep pinning
    # explicit revs — the 02:59 switch failure of 2026-09-04 came from a
    # moving `?ref=master` resolving past the fix. First hold history
    # (2026-08-25 → 2026-09-04, upstream Go floor > nixpkgs go) is moot: the
    # input deliberately does not follow our nixpkgs, so the FOD's go comes
    # from upstream's own lock.
    discordsync = {
      url = "github:LarsArtmann/DiscordSync/c0604e46";
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
    # verified against the nixpkgs services.stalwart module (0.15.5) at its
    # own lock rev, and both repos pin the SAME rev on purpose (compat
    # doctrine - bump both together). Deliberately NOT pinned inside
    # nix-email are its tests' VM runtime, so no other follows exist: the
    # flake has nixpkgs as its only input.
    nix-email = {
      url = "github:LarsArtmann/nix-email/v0.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
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
        inherit nix-ssh-config crush-config;
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

          # Use treefmt-full-flake's formatter which includes alejandra in PATH
          formatter = treefmt-full-flake.formatter.${system};

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
              # NOT included: bank-sync (upstream flake still pins a
              # stale vendorHash; the module-level override unblocks
              # deploys — drop the exclusion when the DROP-ME override in
              # bank-sync.nix goes), monitor365 (its wireguard-collector
              # git dep is a PRIVATE crate that 404s on anonymous fetch —
              # the documented reason the service is disabled since
              # 2026-08-12; a permanent red, not drift — first quick-go
              # run proved exactly this), cv (built with its real
              # module-level package by checks.x86_64-linux.cv), hermes
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
              # bare-40-hex alternative fires only with a rule keyword
              # (sgp_/sourcegraph) in the chunk — bare hex WITHOUT keywords
              # stays clean at ANY entropy, so the retracted row-357 premise
              # ("bare SHAs never trip gitleaks") was directionally right but
              # keyword-scoped. Fixtures live in tests/fixtures/gitleaks/
              # (allowlisted in .gitleaks.toml — they are rule-shape strings,
              # not credentials); gitleaks entropy gates need realistic
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
                expect_detect "positive-hex-with-keyword.txt" "bare 40-hex gated by the sourcegraph keyword"
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
                echo "gitleaks coverage: 3 positive classes detected, 2 negative classes clean"
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
                    pkgs.diffutils # cmp (exit-4 predictor unit-file diffing)
                    pkgs.gawk # loader.conf/entry parsing
                    pkgs.gnugrep
                    pkgs.nix # path-info closure sanity + nix-store gc-root queries
                    pkgs.systemd # systemctl (quiet-window advisories, nix-gc timer)
                    pkgs.util-linux # findmnt
                  ]
                  ./scripts/pre-reboot-check.sh;
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
