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
    };

    home-manager = {
      url = "github:nix-community/home-manager";
    };

    # Add flake-parts for modular architecture
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    # Single flake-utils source — all inputs follow this to avoid 10+ duplicate instances
    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    # Single nix-systems source — flake-utils follows this
    systems.url = "github:nix-systems/default";

    # uv2nix ecosystem — builds Python apps from uv.lock hermetically.
    # Consumed by pkgs/geometrikks.nix (services.geometrikks). Upstream org
    # renamed pyproject.build-systems -> build-system-pkgs; all three follow
    # our nixpkgs so the venv toolchain matches the host python313.
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
    };

    # Single treefmt-nix source — dnsblockd, niri-session-manager follow this
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
    };

    # Add NUR (Nix User Repository) for other packages
    nur = {
      url = "github:nix-community/NUR";
    };

    # Helium Browser
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
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
    };

    # OpenTelemetry TUI viewer
    otel-tui = {
      url = "github:ymtdzzz/otel-tui";
    };

    # Superfile terminal file manager (upstream flake — nixpkgs stuck at 1.3.3,
    # upstream v1.6.0 ships bubbletea-v2 preview reliability + sidebar config)
    superfile = {
      url = "github:yorukot/superfile";
    };

    # AMD NPU (XDNA) driver for Ryzen AI Max+ Strix Halo
    nix-amd-npu = {
      url = "github:robcohen/nix-amd-npu";
    };

    # Secrets management via sops + age
    sops-nix = {
      url = "github:Mic92/sops-nix";
    };

    # SilentSDDM - customizable SDDM theme with Catppuccin support
    silent-sddm = {
      url = "github:uiriansan/SilentSDDM";
    };

    # Declarative disk partitioning — geometry-spec only for SystemNix:
    # diskoConfigurations.samsung-tlc is an eval-checked reference of the
    # live Samsung layout (NOT imported by nixosConfigurations — see
    # disko/samsung-tlc.nix). No module consumers; input kept for the
    # disko CLI (dry-run script rendering / rescue use).
    disko = {
      url = "github:nix-community/disko";
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

    # paperless-gpt — AI metadata enrichment + custom-field extraction for
    # Paperless-ngx (github:icereed/paperless-gpt, MIT). TAG-PINNED at the
    # v0.28.0 release so the vendorHash + npmDepsHash in
    # pkgs/paperless-gpt.nix stay reproducible; bump tag + both hashes
    # together (a moving ref would re-break the FODs on every lock update —
    # the vendorHash-shim churn class documented in lib/lars-packages.nix).
    paperless-gpt-src = {
      url = "github:icereed/paperless-gpt/v0.28.0";
      flake = false;
    };

    nix-ssh-config = {
      url = "github:LarsArtmann/nix-ssh-config";
    };

    # Crush AI Agent Configuration — global AI assistant settings
    # This ensures AGENTS.md and all references are synced across machines
    crush-config = {
      url = "git+ssh://git@github.com/LarsArtmann/crush-config?ref=refs/heads/master";
    };

    # dnsblockd — DNS blocklist service with block pages and blocklist processing
    dnsblockd = {
      url = "git+ssh://git@github.com/LarsArtmann/dnsblockd?ref=refs/heads/master";
    };

    wallpapers-src = {
      url = "git+ssh://git@github.com/LarsArtmann/wallpapers?ref=refs/heads/master";
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
      # INTERIM-ROLLBACK (2026-10-02): the 09:31 auto lock update re-locked
      # hermes-agent to 10c6188d, whose flake eval-forces the
      # `hermes-python-source` FOD (IFD class) — `nix flake check --no-build`
      # (the pre-commit gate) fails with "path …-hermes-python-source is not
      # valid" while bafb42b4 evals clean (verified by lock swap 2026-10-02).
      # The url above stays unpinned so a later
      # `nix flake lock --update-input hermes-agent` can move forward;
      # do NOT blanket-update back to a rev that breaks the eval gate. Drop
      # this rollback once an upstream rev evals green under --no-build.
      # ROLLBACK REPLAY (2026-10-07 19:00): the daemon's blanket lock updates
      # advanced 0e21933 (via 489c1ac) whose WEB frontend fails TypeScript
      # typecheck (TS1484 'SessionFilterCategory' type-only import under
      # verbatimModuleSyntax, web-0.0.0 buildPhase) — deploy blocked until
      # pinned back to e76fb95, the rev behind the proven 17:22 generation.
      # Blanket `nix flake update` keeps re-introducing this class; move the
      # input forward ONLY after `nix build
      # .#nixosConfigurations.evo-x2.config.system.build.toplevel` passes.
      url = "github:NousResearch/hermes-agent";
    };

    # monitor365 — Device monitoring agent (Rust)
    monitor365 = {
      url = "git+ssh://git@github.com/LarsArtmann/monitor365?ref=refs/heads/master";
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
      url = "git+ssh://git@github.com/LarsArtmann/storage-collector?ref=refs/heads/master";
    };

    # PapDashboard — event-sourced alert hub with NPU insight enricher (Go)
    papdashboard = {
      url = "git+ssh://git@github.com/LarsArtmann/PapDashboard?ref=refs/heads/master";
      # nixpkgs deliberately NOT followed (bank-sync/qmd vendorHash doctrine):
      # upstream derives its vendorHash against ITS pinned buildGoModule —
      # following our nixpkgs invalidates it on every bump (2026-09-17: 4
      # revs hunted in one evening, every one hash-mismatched under the
      # b1b87598 buildGoModule).
    };

    # InboxClean — Gmail AI assistant: web dashboard + incremental sync (Go)
    inboxclean = {
      url = "git+ssh://git@github.com/LarsArtmann/InboxClean?ref=refs/heads/master";
    };

    # NixOS hardware profiles (Raspberry Pi, etc.)
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };

    # EMEET PIXY webcam auto-activation daemon
    emeet-pixyd = {
      url = "github:LarsArtmann/emeet-pixyd?ref=master";
    };

    # Niri session manager — automatic window save/restore
    niri-session-manager = {
      url = "github:LarsArtmann/niri-session-manager";
    };

    # Treefmt formatter with auto-discovery for nix fmt
    treefmt-full-flake = {
      url = "github:LarsArtmann/treefmt-full-flake";
    };

    # todo-list-ai — AI-powered CLI tool for extracting TODOs from codebases
    # Was INTERIM-pinned to f9f3b335 (2026-09-13: auto-commit left the frozen
    # bun lockfile stale); master verified BUILDABLE at HEAD 2026-09-16
    # (package build probe passed) — pin dropped per the pin policy.
    todo-list-ai = {
      url = "git+ssh://git@github.com/LarsArtmann/todo-list-ai?ref=refs/heads/master";
    };

    # library-policy — Banned/vulnerable library detector for Go projects
    # ?ref=master since 2026-09-17: upstream ef02247 fixed the build chain
    # (toolchain bumped to go_1_27 for the samber-do-auditlog go.mod floor,
    # vendorHash refreshed; FOD + package verified). Bumps flow via
    # `nix flake lock --update-input library-policy --refresh`.
    library-policy = {
      url = "git+ssh://git@github.com/LarsArtmann/library-policy?ref=refs/heads/master";
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
      url = "git+ssh://git@github.com/LarsArtmann/file-and-image-renamer";
    };

    # nsfw-classifier — Go/ONNX NSFW image classifier. Backend for the
    # browser extension that helium auto-loads (platforms/common/packages/
    # base.nix --load-extension): with default settings the extension
    # auto-discovers nsfw.home.lan:<ports.nsfw> and pairs via the /readyz
    # token that services.nsfw-classifier provides (--pair-token auto).
    # nixpkgs FOLLOWS root since 2026-10-07: root (a7868a72) carries
    # go_1_27 = 1.27.1 — the same minor the flake pins — and the go-modules
    # FOD rebuild on the flip verified the vendorHash holds. Deliberate
    # entry dropped from lib/lock-audit.nix in the same change.
    nsfw-classifier = {
      # INTERIM `git+file` pin — the vendorHash fix (46f02bb) exists only as
      # an unpushed local commit (origin/master is 4d159f9); a remote pin
      # would build the STALE vendorHash. The ?rev= is the SANCTIONED
      # git+file-only pin form (the inputUrlRevGuard allows it here alone):
      # the checkout's worktree churns under the auto-commit daemon, and a
      # dirty worktree breaks the go-modules FOD (source-dependent hash) —
      # the rev pin builds the COMMITTED state only. Flip condition: push
      # 46f02bb to origin/master, then switch to
      # git+ssh://git@github.com/LarsArtmann/nsfw-classifier?ref=refs/heads/master
      # (deploy-key fetch, same pattern as file-and-image-renamer), drop the
      # ?rev=, bump the lock, and remove the INTERIM row in
      # docs/INTERIM-INPUT-PINS.md.
      url = "git+file:///home/lars/projects/nsfw-classifier";
    };

    # crush-daily — Daily AI-powered insights from Crush development databases
    crush-daily = {
      url = "git+ssh://git@github.com/LarsArtmann/crush-daily?ref=refs/heads/master";
    };

    # bank-sync — Wise/Qonto bank transaction sync into SQLite + dashboard
    bank-sync = {
      url = "git+ssh://git@github.com/LarsArtmann/bank-sync?ref=refs/heads/master";
    };

    # index — project documentation indexer; the docs-archive-stats
    # home-manager timer records the dated-docs history TSV (which lives in
    # the index repo and rides its auto-commit) daily at 06:15.
    # go-nix-helpers deliberately NOT followed (bank-sync FOD-mismatch trap).
    index = {
      url = "git+ssh://git@github.com/LarsArtmann/index?ref=refs/heads/master";
    };

    # go-taskqueue — projects-aware task work queue + agent pool (tq CLI).
    # 2026-09-17: interim git+file FLIPPED to github:?ref=master — the push
    # backlog landed on origin (master = 1c48478, incl. the vendorHash fix
    # from 1a4eb48). go-nix-helpers deliberately NOT followed (bank-sync
    # FOD-mismatch trap): the vendorHash was validated with upstream's
    # locked helper.
    go-taskqueue = {
      url = "github:LarsArtmann/go-taskqueue?ref=master";
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
    };

    # mr-sync — CLI to keep ~/.mrconfig in sync with GitHub repos
    # NOTE: Go-module replace deps (go-output, go-branded-id, cmdguard) are NOT
    # followed — overriding them changes vendored content and breaks vendorHash.
    # Only build-infra inputs are followed.
    mr-sync = {
      url = "git+ssh://git@github.com/LarsArtmann/mr-sync?ref=refs/heads/master";
    };

    # go-health-dashboard — federated go-health hub (health.home.lan).
    # Consumed for its packages.health-hub buildGoModule output (the flake
    # owns the go_1_27 + GOEXPERIMENT=jsonv2 toolchain wiring).
    go-health-dashboard = {
      url = "github:LarsArtmann/go-health-dashboard?ref=master";
    };

    # erraudit — Error handling pattern analyzer for Go projects
    # (GitHub renamed the repo from hierarchical-errors; the input name and
    # the mkLarsPackages attr follow the new name. 2026-09-17.)
    erraudit = {
      url = "git+ssh://git@github.com/LarsArtmann/erraudit?ref=refs/heads/master";
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
    };

    # go-auto-upgrade — Automate Go library upgrades
    # ?ref=master since 2026-09-17: upstream a6d1e65 refreshed the stale
    # vendorHash (FOD + package verified). Bumps flow via
    # `nix flake lock --update-input go-auto-upgrade --refresh`.
    go-auto-upgrade = {
      url = "git+ssh://git@github.com/LarsArtmann/go-auto-upgrade?ref=refs/heads/master";
    };

    # go-structure-linter — Go project structure validator
    go-structure-linter = {
      # INTERIM-ROLLBACK (2026-09-23): the wave re-locked to 721c62a0, whose
      # go.mod floor (1.27.1) exceeds the followed nixpkgs go (1.26.7) — the
      # go-modules FOD dies under GOTOOLCHAIN=local. The lock node was rolled
      # back to 96b6a01f (gen-797-proven). Do NOT update-input until upstream
      # wires go_1_27 (the library-policy three-wiring-points pattern).
      url = "git+ssh://git@github.com/LarsArtmann/go-structure-linter?ref=refs/heads/master";
    };

    # samber-linter — static analyzer detecting health-washing in samber/do v2 containers
    # No goPkgAttr upstream: go-standard auto-selects go_1_27 (go.mod floor
    # 1.27.1, nixpkgs default go is 1.26). GOEXPERIMENT=jsonv2 rides the
    # upstream extraBuildAttrs; vendorHash lives upstream.
    samber-linter = {
      url = "github:LarsArtmann/samber-linter?ref=master";
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
      url = "github:LarsArtmann/go-cqrs-lite/master";
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
    };

    # art-dupl raw source — consumed transitively by dnsblockd (follows this input)
    art-dupl-src = {
      url = "github:LarsArtmann/art-dupl";
      flake = false;
    };

    # go-commit — Conventional commit helper (consumed by PMA via mkPreparedSource).
    go-commit = {
      url = "git+ssh://git@github.com/LarsArtmann/go-commit?ref=refs/heads/master";
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
      url = "git+ssh://git@github.com/LarsArtmann/projects-management-automation?ref=refs/heads/master";
    };

    # project-discovery-daemon — standalone discovery daemon owning
    # /run/project-discovery/daemon.sock (flipped from PMA's co-located
    # embedded daemon 2026-09-07). Must be at a rev that supports
    # PROJECT_DISCOVERY_SEARCH_PATHS and PROJECT_DISCOVERY_SOCKET_MODE.
    project-discovery-daemon = {
      url = "git+ssh://git@github.com/LarsArtmann/project-discovery-daemon?ref=refs/heads/master";
    };

    # project-dependency-graph — depgraph CLI: renders the LarsArtmann Go
    # monorepo dependency graph (D2/HTML/JSON/…) and answers who-uses/why/
    # update-plan/release-suggestions queries. PRIVATE repo → git+ssh
    # (deploy-key recipe; see docs/agents/go-ecosystem.md). nixpkgs and
    # go-nix-helpers deliberately NOT followed (discordsync/bank-sync
    # precedent): the vendorHash is validated against upstream's OWN lock —
    # following re-tools the FOD under SystemNix's nixpkgs and re-hashes it
    # on every root-nixpkgs bump (the 2026-10-05 a7868a7 wave class).
    project-dependency-graph = {
      url = "git+ssh://git@github.com/LarsArtmann/project-dependency-graph?ref=refs/heads/master";
    };

    # project-meta — Per-project metadata management CLI
    project-meta = {
      url = "git+ssh://git@github.com/LarsArtmann/project-meta?ref=refs/heads/master";
    };

    # Overview — local project dashboard (discovers and browses git repos via web UI)
    overview = {
      # ?ref=master since 2026-09-17: upstream a0cfbc2 refreshed the stale
      # vendorHash (FOD + package verified). Bumps flow via
      # `nix flake lock --update-input overview --refresh`.
      url = "git+ssh://git@github.com/LarsArtmann/overview?ref=refs/heads/master";
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
      url = "git+ssh://git@github.com/LarsArtmann/DiscordSync?ref=refs/heads/master";
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
      url = "github:LarsArtmann/nix-email";
    };

    # vision-review-agent — visionreviewd, the event-sourced UI review daemon
    # (returned 2026-09-22 after the 2026-09-15 dormant-integration removal;
    # this time enabled on evo-x2, pointed at llama-vlm's captioner endpoint)
    vision-review-agent = {
      url = "github:LarsArtmann/vision-review-agent?ref=master";
    };

    # md-go-validator — Validate code blocks embedded in Markdown/MDX docs
    # Was INTERIM-pinned to 5b72f894 (2026-09-13 vendorHash wave); master
    # verified BUILDABLE at HEAD 2026-09-16 (goModules FOD probe passed) —
    # pin dropped per the pin policy (?ref=master everywhere possible).
    md-go-validator = {
      url = "github:LarsArtmann/md-go-validator?ref=master";
    };

    # browser-history — Browser history intelligence server (CQRS/ES, WebAuthn)
    # Branch-ref governed (pin policy 2026-09-16): the lock still holds
    # 0971fe9c until an explicit `nix flake lock --update-input
    # browser-history` — probe the go-modules FOD at the target rev first
    # (its build rides published cqrs-htmx tags; docs/agents/go-ecosystem.md probe protocol).
    browser-history = {
      url = "git+ssh://git@github.com/LarsArtmann/browser-history?ref=refs/heads/master";
    };

    # CV — resume generator + career pipeline server (PRIVATE repo: git+ssh).
    # No follows on purpose (discordsync precedent): CV's vendorHash was
    # validated against its own locked nixpkgs/go-nix-helpers — and CV builds
    # its own go 1.26.6 from the go.dev tarball (nixpkgs has 1.26.5 while the
    # go.mod floor is 1.26.6), so it must consume its own build environment.
    cv = {
      url = "git+ssh://git@github.com/LarsArtmann/CV?ref=master";
    };

    # Kith CRM — LarsArtmann's own event-sourced CRM (PRIVATE repo:
    # git+ssh, cv pattern). Builds Go 1.27 via its own go-nix-helpers lock
    # (go.mod floor 1.27.1), so NO nixpkgs follows — it must consume its
    # own build environment. Consumed by modules/nixos/services/crm.nix
    # (services.crm-server unit); the CV syncer targets its REST surface.
    crm = {
      url = "git+ssh://git@github.com/LarsArtmann/crm?ref=master";
    };

    # DankMaterialShell — Quickshell-based desktop shell (Niri + Hyprland)
    # Brings quickshell transitively — no separate quickshell input needed
    dankMaterialShell = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
    };

    # herdr — Agent multiplexer for the terminal (runs multiple AI coding agents with real panes)
    herdr = {
      url = "github:ogulcancelik/herdr";
    };

    # rust-overlay — herdr's Rust toolchain provider. Declared as a root
    # input purely to pin herdr's transitive resolve (see herdr block) at a
    # rev with the stdenv.hostPlatform.* migration.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
    };

    # go-humanize-linter — AST linter detecting hand-rolled reimplementations of go-humanize
    # Go dep inputs (go-finding, go-linter-sdk, go-error-family) are NOT followed —
    # they are flake=false git+ssh inputs fetched by the upstream flake itself.
    go-humanize-linter = {
      url = "github:LarsArtmann/go-humanize-linter?ref=main";
    };

    # git-hooks.nix + flake-compat — root inputs declared SOLELY to own the
    # shared pin for the infra-follows group (2026-10-08 collapse of 5×
    # git-hooks + 7× flake-compat duplicate lock nodes; rust-overlay
    # precedent: never consumed by any output directly). FLOATING
    # (?ref=master, owner decision 2026-10-08 — the pin-policy default):
    # both currently lock exactly the rev every consumer already shared
    # (verified: 1 distinct rev + 1 narHash per group), so the collapse is
    # a no-op build-wise, but a lock wave MAY move them. A git-hooks move
    # changes 5 repos' pre-commit evals (bank-sync, inboxclean,
    # library-policy, overview, project-meta) — run `nix flake check
    # --no-build --all-systems` after any wave that touches them;
    # flake-compat is tarball-only (flake = false, safe).
    git-hooks.url = "github:cachix/git-hooks.nix?ref=master";
    flake-compat = {
      url = "github:NixOS/flake-compat?ref=master";
      flake = false;
    };

    # Infra follows (2026-10-02 lock dedup): Nix locks one node per
    # input-graph PATH, so every consumer that declared flake-parts /
    # treefmt-nix / systems / nixpkgs without a follows pin carried its own
    # duplicate lock copy (421 lock nodes for 235 unique revs). These
    # attrpath follows collapse them onto the root pins; the list is
    # DATA-DERIVED from the lock graph (docs/planning/
    # 2026-10-02_09-47_flake-lock-infra-dedup.md) and lib/lock-audit.nix
    # fails eval if a NEW unfollowed edge appears — extend this group (or
    # allowlist it in the audit), never hand-pin around it.
    # RULES (docs/agents/nix-flakes.md "Infra follows"):
    # - Eval-only deps (flake-parts, treefmt-nix, systems, flake-utils,
    #   flake-compat, git-hooks) are always safe to follow — they never enter
    #   FOD hashes. flake-compat/git-hooks joined the guarded set 2026-10-08
    #   (root-promoted at the consumers' shared revs; see the input blocks
    #   above).
    # - nixpkgs follows change the consumer's build env: papdashboard is the
    #   only real rev flip below; go-nix-helpers/projects-management-automation
    #   copies already sat at the root rev (pure alias collapse). Deliberate
    #   non-follows: qmd nixpkgs (bun nodeModules FOD), discordsync nixpkgs
    #   (FOD cache-hit rollback 2026-09-23).
    # - NEVER follow Go MODULE tarballs (go-*) INTO Go tool flakes: that
    #   changes vendored module content and breaks vendorHash FODs
    #   (2026-08-25 got-hash drift class). The helper itself is the one
    #   sanctioned exception for LarsArtmann tools (NAR-hash MUST-rule,
    #   docs/agents/nix-flakes.md) — bank-sync rides it under the got-hash
    #   protocol; the go-nix-helpers line below follows NIXPKGS INTO the
    #   helper flake (eval-only for its lib), not the helper into tools.
    # The promoted git-hooks input needs its OWN nested edges followed too:
    # without these, a re-lock un-follows them (git-hooks locks its own
    # nixpkgs-unstable pin + a floating flake-compat copy — verified in the
    # 2026-10-08 worktree canonicalization pass).
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.flake-compat.follows = "flake-compat";
    emeet-pixyd.inputs.flake-parts.follows = "flake-parts";
    emeet-pixyd.inputs.treefmt-nix.follows = "treefmt-nix";
    # bank-sync follows the helper onto the root node (2026-10-08, owner
    # option a): its own lock node had moved in lockstep with root's
    # through 3 rev waves with builds green each time (ad423c8f,
    # content-identical), so this makes the lockstep structural. Helper
    # bumps may re-hash bank-sync's FOD — got-hash protocol (probe at rev,
    # paste upstream, re-lock); that protocol covers the 2026-08-18
    # mismatch class.
    bank-sync.inputs.go-nix-helpers.follows = "go-nix-helpers";
    bank-sync.inputs.git-hooks.follows = "git-hooks";
    buildflow.inputs.flake-parts.follows = "flake-parts";
    cv.inputs.flake-parts.follows = "flake-parts";
    cv.inputs.treefmt-nix.follows = "treefmt-nix";
    # cv's own nixpkgs pin sat at the SAME rev as root nixpkgs (verified
    # 2026-10-02 before following) — no-op build-wise, keeps the lock-audit
    # dedup honest when a re-lock re-resolves cv's transitive inputs.
    cv.inputs.nixpkgs.follows = "nixpkgs";
    # crm has no direct treefmt-nix input (it arrives nested under its
    # pinned go-nix-helpers); flake-parts is its only direct infra edge.
    crm.inputs.flake-parts.follows = "flake-parts";
    crush-config.inputs.treefmt-nix.follows = "treefmt-nix";
    dankMaterialShell.inputs.flake-compat.follows = "flake-compat";
    erraudit.inputs.flake-parts.follows = "flake-parts";
    go-auto-upgrade.inputs.flake-parts.follows = "flake-parts";
    go-nix-helpers.inputs.flake-parts.follows = "flake-parts";
    go-nix-helpers.inputs.treefmt-nix.follows = "treefmt-nix";
    go-nix-helpers.inputs.nixpkgs.follows = "nixpkgs";
    go-structure-linter.inputs.flake-parts.follows = "flake-parts";
    go-structure-linter.inputs.treefmt-nix.follows = "treefmt-nix";
    go-taskqueue.inputs.flake-parts.follows = "flake-parts";
    golangci-lint-auto-configure.inputs.flake-parts.follows = "flake-parts";
    inboxclean.inputs.flake-parts.follows = "flake-parts";
    inboxclean.inputs.treefmt-nix.follows = "treefmt-nix";
    inboxclean.inputs.git-hooks.follows = "git-hooks";
    library-policy.inputs.git-hooks.follows = "git-hooks";
    index.inputs.flake-parts.follows = "flake-parts";
    monitor365.inputs.flake-parts.follows = "flake-parts";
    monitor365.inputs.treefmt-nix.follows = "treefmt-nix";
    nsfw-classifier.inputs.flake-parts.follows = "flake-parts";
    nsfw-classifier.inputs.nixpkgs.follows = "nixpkgs";
    nsfw-classifier.inputs.treefmt-nix.follows = "treefmt-nix";
    papdashboard.inputs.flake-parts.follows = "flake-parts";
    papdashboard.inputs.treefmt-nix.follows = "treefmt-nix";
    papdashboard.inputs.nixpkgs.follows = "nixpkgs";
    overview.inputs.git-hooks.follows = "git-hooks";
    project-meta.inputs.git-hooks.follows = "git-hooks";
    projects-management-automation.inputs.nixpkgs.follows = "nixpkgs";
    samber-linter.inputs.flake-parts.follows = "flake-parts";
    qmd.inputs.flake-utils.follows = "flake-utils";
    storage-collector.inputs.flake-parts.follows = "flake-parts";
    superfile.inputs.flake-compat.follows = "flake-compat";
    todo-list-ai.inputs.flake-parts.follows = "flake-parts";
    todo-list-ai.inputs.treefmt-nix.follows = "treefmt-nix";
    art-dupl.inputs.nixpkgs.follows = "nixpkgs";
    bank-sync.inputs.flake-parts.follows = "flake-parts";
    bank-sync.inputs.nixpkgs.follows = "nixpkgs";
    bank-sync.inputs.treefmt-nix.follows = "treefmt-nix";
    branching-flow.inputs.flake-parts.follows = "flake-parts";
    branching-flow.inputs.go-nix-helpers.follows = "go-nix-helpers";
    branching-flow.inputs.nixpkgs.follows = "nixpkgs";
    branching-flow.inputs.treefmt-nix.follows = "treefmt-nix";
    browser-history.inputs.flake-parts.follows = "flake-parts";
    browser-history.inputs.go-nix-helpers.follows = "go-nix-helpers";
    browser-history.inputs.nixpkgs.follows = "nixpkgs";
    browser-history.inputs.treefmt-nix.follows = "treefmt-nix";
    buildflow.inputs.go-nix-helpers.follows = "go-nix-helpers";
    buildflow.inputs.nixpkgs.follows = "nixpkgs";
    # crm pins its own go-nix-helpers (lock node go-nix-helpers_2,
    # e8075ef8) which predates go-standard's proxyVendor mkDefault fix —
    # its prepared-source (deps) packages default proxyVendor = true and
    # emit "go-standard.proxyVendor = true is ignored when deps are set"
    # on every evo-x2 eval. Follow our root pin (64f2927b) which defaults
    # proxyVendor off for deps consumers.
    crm.inputs.go-nix-helpers.follows = "go-nix-helpers";
    crush-config.inputs.flake-parts.follows = "flake-parts";
    crush-config.inputs.nixpkgs.follows = "nixpkgs";
    crush-daily.inputs.flake-parts.follows = "flake-parts";
    crush-daily.inputs.go-nix-helpers.follows = "go-nix-helpers";
    crush-daily.inputs.nixpkgs.follows = "nixpkgs";
    crush-daily.inputs.systems.follows = "systems";
    crush-daily.inputs.treefmt-nix.follows = "treefmt-nix";
    dankMaterialShell.inputs.nixpkgs.follows = "nixpkgs";
    discordsync.inputs.flake-parts.follows = "flake-parts";
    discordsync.inputs.treefmt-nix.follows = "treefmt-nix";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    dnsblockd.inputs.flake-parts.follows = "flake-parts";
    dnsblockd.inputs.go-nix-helpers.follows = "go-nix-helpers";
    dnsblockd.inputs.nixpkgs.follows = "nixpkgs";
    emeet-pixyd.inputs.nixpkgs.follows = "nixpkgs";
    erraudit.inputs.go-nix-helpers.follows = "go-nix-helpers";
    erraudit.inputs.nixpkgs.follows = "nixpkgs";
    file-and-image-renamer.inputs.flake-parts.follows = "flake-parts";
    # Without this, the input locks its own go-nix-helpers via git+ssh:
    # (git insteadOf pollution) — divergent narHash vs the top-level
    # github: fetch, the "NAR hash mismatch" daemon-cache trap (docs/agents/nix-flakes.md).
    file-and-image-renamer.inputs.go-nix-helpers.follows = "go-nix-helpers";
    file-and-image-renamer.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-utils.inputs.systems.follows = "systems";
    go-auto-upgrade.inputs.go-nix-helpers.follows = "go-nix-helpers";
    go-auto-upgrade.inputs.nixpkgs.follows = "nixpkgs";
    go-cqrs-lite.inputs.flake-parts.follows = "flake-parts";
    go-cqrs-lite.inputs.go-nix-helpers.follows = "go-nix-helpers";
    go-cqrs-lite.inputs.nixpkgs.follows = "nixpkgs";
    go-cqrs-lite.inputs.treefmt-nix.follows = "treefmt-nix";
    go-health-dashboard.inputs.flake-parts.follows = "flake-parts";
    go-health-dashboard.inputs.nixpkgs.follows = "nixpkgs";
    go-health-dashboard.inputs.treefmt-nix.follows = "treefmt-nix";
    go-humanize-linter.inputs.flake-parts.follows = "flake-parts";
    go-humanize-linter.inputs.go-nix-helpers.follows = "go-nix-helpers";
    go-humanize-linter.inputs.nixpkgs.follows = "nixpkgs";
    go-structure-linter.inputs.go-nix-helpers.follows = "go-nix-helpers";
    go-structure-linter.inputs.nixpkgs.follows = "nixpkgs";
    go-taskqueue.inputs.nixpkgs.follows = "nixpkgs";
    golangci-lint-auto-configure.inputs.go-nix-helpers.follows = "go-nix-helpers";
    golangci-lint-auto-configure.inputs.nixpkgs.follows = "nixpkgs";
    helium.inputs.nixpkgs.follows = "nixpkgs";
    helium.inputs.utils.follows = "flake-utils";
    herdr.inputs.nixpkgs.follows = "nixpkgs";
    # herdr resolves rust-overlay from the lock graph (node rust-overlay,
    # 4cdea398) whose lib/mk-aggregated.nix still uses the deprecated
    # stdenv.isLinux/isDarwin accessors — eval warnings on every evo-x2
    # eval that renders the herdr Rust toolchain. Follow our explicit root
    # pin (master, migrated to stdenv.hostPlatform.*).
    herdr.inputs.rust-overlay.follows = "rust-overlay";
    hermes-agent.inputs.flake-parts.follows = "flake-parts";
    hermes-agent.inputs.nixpkgs.follows = "nixpkgs";
    # Upstream pins its own uv2nix (2026-07-28) whose lib/build.nix still
    # uses the deprecated stdenv.isDarwin/isLinux accessors — eval warnings
    # on every hermes eval. Follow our root pin (a24323e9, migrated to
    # stdenv.hostPlatform.*) instead.
    hermes-agent.inputs.uv2nix.follows = "uv2nix";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    inboxclean.inputs.nixpkgs.follows = "nixpkgs";
    index.inputs.nixpkgs.follows = "nixpkgs";
    library-policy.inputs.flake-parts.follows = "flake-parts";
    library-policy.inputs.go-nix-helpers.follows = "go-nix-helpers";
    library-policy.inputs.nixpkgs.follows = "nixpkgs";
    md-go-validator.inputs.flake-parts.follows = "flake-parts";
    md-go-validator.inputs.nixpkgs.follows = "nixpkgs";
    md-go-validator.inputs.treefmt-nix.follows = "treefmt-nix";
    monitor365.inputs.nixpkgs.follows = "nixpkgs";
    mr-sync.inputs.flake-parts.follows = "flake-parts";
    mr-sync.inputs.go-nix-helpers.follows = "go-nix-helpers";
    mr-sync.inputs.nixpkgs.follows = "nixpkgs";
    niri.inputs.nixpkgs.follows = "nixpkgs";
    niri-session-manager.inputs.nixpkgs.follows = "nixpkgs";
    niri-session-manager.inputs.treefmt-nix.follows = "treefmt-nix";
    nix-amd-npu.inputs.flake-parts.follows = "flake-parts";
    nix-amd-npu.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-email.inputs.flake-parts.follows = "flake-parts";
    nix-email.inputs.nixpkgs.follows = "nixpkgs";
    nix-ssh-config.inputs.flake-parts.follows = "flake-parts";
    nix-ssh-config.inputs.home-manager.follows = "home-manager";
    nix-ssh-config.inputs.nixpkgs.follows = "nixpkgs";
    nix-ssh-config.inputs.treefmt-nix.follows = "treefmt-nix";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";
    nur.inputs.flake-parts.follows = "flake-parts";
    nur.inputs.nixpkgs.follows = "nixpkgs";
    otel-tui.inputs.flake-utils.follows = "flake-utils";
    otel-tui.inputs.nixpkgs.follows = "nixpkgs";
    overview.inputs.flake-parts.follows = "flake-parts";
    overview.inputs.go-nix-helpers.follows = "go-nix-helpers";
    overview.inputs.nixpkgs.follows = "nixpkgs";
    overview.inputs.treefmt-nix.follows = "treefmt-nix";
    project-dependency-graph.inputs.flake-parts.follows = "flake-parts";
    project-discovery-daemon.inputs.flake-parts.follows = "flake-parts";
    project-discovery-daemon.inputs.go-nix-helpers.follows = "go-nix-helpers";
    project-discovery-daemon.inputs.nixpkgs.follows = "nixpkgs";
    project-meta.inputs.flake-parts.follows = "flake-parts";
    project-meta.inputs.go-nix-helpers.follows = "go-nix-helpers";
    project-meta.inputs.nixpkgs.follows = "nixpkgs";
    projects-management-automation.inputs.flake-parts.follows = "flake-parts";
    pyproject-build-systems.inputs.nixpkgs.follows = "nixpkgs";
    pyproject-build-systems.inputs.pyproject-nix.follows = "pyproject-nix";
    pyproject-build-systems.inputs.uv2nix.follows = "uv2nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    samber-linter.inputs.go-nix-helpers.follows = "go-nix-helpers";
    samber-linter.inputs.nixpkgs.follows = "nixpkgs";
    silent-sddm.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    storage-collector.inputs.nixpkgs.follows = "nixpkgs";
    superfile.inputs.flake-utils.follows = "flake-utils";
    superfile.inputs.nixpkgs.follows = "nixpkgs";
    todo-list-ai.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-full-flake.inputs.flake-parts.follows = "flake-parts";
    treefmt-full-flake.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-full-flake.inputs.treefmt-nix.follows = "treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
    vision-review-agent.inputs.flake-parts.follows = "flake-parts";
    vision-review-agent.inputs.nixpkgs.follows = "nixpkgs";
    vision-review-agent.inputs.treefmt-nix.follows = "treefmt-nix";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      nix-ssh-config,
      crush-config,
      superfile,
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
      # flake.lock hygiene gate (2026-10-02 dedup): fails eval when a root
      # input re-grows its own infra-dep lock node (blanket lock waves do
      # this silently). Semantics + deliberate non-follows: lib/lock-audit.nix.
      lockAuditViolations = import ./lib/lock-audit.nix {
        lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      };
      lockAuditGuard =
        assert
          lockAuditViolations == [ ]
          || throw ''
            flake.lock infra-follows audit failed:
              ${lib.concatStringsSep "\n  " lockAuditViolations}
            Fix: add '<input>.inputs.<dep>.follows = "<dep>";' to the infra-follows group at the end of the inputs attrset in flake.nix (eval-only deps are always safe to follow) — or, only if the consumer's FODs were validated against its own pin, a documented entry in lib/lock-audit.nix `deliberate`.
          '';
        true;
      allEvalGuards = builtins.seq nixpkgsTarballGuard (builtins.seq inputUrlRevGuard lockAuditGuard);
    in
    builtins.seq allEvalGuards flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      # Import the split perSystem parts (formatter, packages, devShells,
      # checks, apps — flake/parts/) + the auto-discovered service modules —
      # registered as flake-parts modules (inputs.self.nixosModules.*).
      # Part files receive `inputs` via mkFlake specialArgs and the shared
      # bindings below via _module.args (see docs/agents/nix-flakes.md).
      imports = [
        ./flake/parts/formatter.nix
      ]
      ++ discoveredModulePaths;

      # Values the part files need that are NOT raw flake inputs: computed
      # once here (they also feed systems/*.nix below) and injected as module
      # args. `root` is the flake source root — part files use it instead of
      # `./.`-relative paths (their own directory differs).
      _module.args = {
        inherit
          mkLarsPackages
          sharedOverlays
          linuxOnlyOverlays
          disableTests
          theme
          ;
        root = ./.;
      };

      # Executable disk-geometry specs (docs, not applied by any host —
      # see disko/samsung-tlc.nix for the discovery-trap rationale).
      flake.diskoConfigurations.samsung-tlc = import ./disko/samsung-tlc.nix;

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
