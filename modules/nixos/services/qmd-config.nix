# qmd — on-device hybrid search engine (BM25 + vector + LLM reranking)
#
# Two pieces:
#
#   1. **CLI package** (`pkgs.qmd`) — exposed to all users via base.nix.
#      `qmd search`, `qmd get`, `qmd collection add` etc. all work directly
#      after `nixos-rebuild switch`. The CLI is also stdio-MCP-compatible
#      (`qmd mcp`) and auto-discovered by any MCP client that has `qmd` on
#      PATH (Claude Code plugin, Crush stdio discovery).
#
#   2. **Long-lived HTTP MCP server** (`qmd mcp --http`) — runs as a Home
#      Manager **user** systemd service so embedding/reranker LLM models
#      stay loaded across requests. Served on localhost only.
#
# Why HTTP-over-stdio:
#   qmd loads three GGUF models (~2 GiB total) on the first search query.
#   StdIO mode spawns a fresh process per MCP connection — every reconnect
#   pays the full model-load cost (~5-15s). HTTP keeps models warm across
#   Crush/Claude/other clients. Models unload after 5 min idle and reload
#   on next request (~1s penalty, models remain loaded).
#
# Why user (HM) service, not system:
#   - Index collections live in $HOME (`~/.cache/qmd/`, `~/.config/qmd/`)
#   - collection paths point at user-owned directories
#   - Tightens blast radius: qmd can't read outside `$HOME`
#   - Follows the same pattern as monitor365-graphical-helper
#
# `ProtectHome = false` is required because qmd must read user collections
# (~/notes, ~/Documents, etc.) AND write to ~/.cache/qmd/index.sqlite.
# `ReadWritePaths` further restricts writes to the qmd cache + config dirs.
#
# Auto-discovered by flake-parts (modules/nixos/services/qmd.nix). The
# filename IS the module name `services.qmd-config`, filename MUST be unique
# across the services/ and desktop/ directories.
_: {
  flake.nixosModules.qmd-config = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.qmd-config;
    sd = import ../../../lib/default.nix lib;
    inherit (sd) hardenUser ports serviceDefaultsUser;
    inherit (config.users) primaryUser;
    userHome = config.users.users.${primaryUser}.home;
  in {
    options.services.qmd-config = {
      enable = lib.mkEnableOption "qmd — on-device markdown hybrid search (CLI + persistent HTTP MCP server)";

      package = lib.mkPackageOption pkgs "qmd" {};

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User account the HTTP MCP service runs as (and whose collections it indexes)";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = ports.qmd;
        defaultText = "ports.qmd (8181)";
        description = "TCP port for the HTTP MCP server (binds 127.0.0.1 only). Coexists with stdio MCP mode — clients pick either.";
      };

      # GGUF model role overrides — see qmd docs. Defaults are tuned for
      # English; set `qmdEmbedModel = "hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf"`
      # for multilingual (CJK) coverage. The model URL is fetched on first
      # use and cached in ~/.cache/qmd/models/ — re-embed after switching.
      qmdEmbedModel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Override the default embedding GGUF model (see qmd --models / model roles in index.yml). Omit to use built-in default.";
      };

      qmdForceCpu = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Disable GPU inference via QMD_FORCE_CPU=1.
          Default true: node-llama-cpp Vulkan probing is brittle on Strix
          Halo and competes with Ollama for VRAM. User can opt in by
          overriding to false and configuring QMD_LLAMA_GPU explicitly.
        '';
      };

      # Optional extra collections to seed on first activation. Per-user
      # ad-hoc collection management happens via `qmd collection add`
      # interactively — this is for declarative bootstrap only.
      bootstrapCollections = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
        example = [
          {
            name = "notes";
            path = "/home/lars/notes";
            pattern = "**/*.md";
            context = "Personal notes and ideas";
          }
        ];
        description = ''
          Declarative collections to register on first activation.
          Entries are upserted in the user's qmd config; if the user
          adds or removes collections via the CLI they win.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      # Make `qmd` available system-wide too (PATH for shells + helpers that
      # shell out to it). Home Manager also installs a copy into the user's
      # profile, but this gives root access for debugging.
      environment.systemPackages = [cfg.package];

      # The HTTP MCP server is a HOME service — it must read user-owned
      # collections and write the qmd SQLite cache. Run as the primary
      # user via Home Manager systemd.
      home-manager.users.${cfg.user} = let
        qmdConfigDir = "${userHome}/.config/qmd";
        qmdCacheDir = "${userHome}/.cache/qmd";
      in {
        # Make `qmd` discoverable on PATH inside the user shell too
        # (base.nix places it system-wide; this is belt-and-braces for
        # any user who hasn't opened a new login shell).
        home.packages = [cfg.package];

        # Seed bootstrap collections on first activation. Writing the
        # YAML directly via Nix is idempotent: qmd merges with whatever
        # the user has added via the CLI. Collections listed here are
        # always present (re-created on deploy if deleted).
        xdg.configFile."qmd/index.yml" = let
          collectionAttrs = {
            global_context = "SystemNix knowledge base — markdown notes, meeting transcripts, and project docs indexed for hybrid search.";
          };
          existingCollections = lib.listToAttrs (
            map (c: {
              name = c.name;
              value = lib.filterAttrs (n: _: n != "name") c;
            })
            cfg.bootstrapCollections
          );
          allCollections =
            collectionAttrs
            // {
              collections = existingCollections;
            };
        in
          lib.mkIf (cfg.bootstrapCollections != [])
          {
            text = builtins.toJSON allCollections;
            onChange = "qmd update --quiet -c ${lib.concatMapStringsSep " " (c: c.name) cfg.bootstrapCollections}";
          };

        # Long-lived HTTP MCP server. Embedding/reranker models stay
        # loaded across requests — stdio mode pays full reload cost
        # (~5-15s) on every reconnect.
        systemd.user.services.qmd-mcp = {
          Unit = {
            Description = "qmd MCP HTTP server (persistent model-loaded search for AI agents)";
            Documentation = "https://github.com/tobi/qmd#http-transport";
            After = ["network.target"];
            Wants = ["network.target"];
            StartLimitIntervalSec = 600;
            StartLimitBurst = 5;
            ConditionPathExists = qmdConfigDir;
          };

          Service = lib.mkMerge [
            (serviceDefaultsUser {RestartSec = "5";})
            (hardenUser {MemoryMax = "4G";})
            {
              Type = "simple";
              ExecStart = lib.escapeShellArgs [
                (lib.getExe cfg.package)
                "mcp"
                "--http"
                "--host"
                "127.0.0.1"
                "--port"
                (toString cfg.port)
              ];
              Environment =
                lib.optional cfg.qmdForceCpu "QMD_FORCE_CPU=1"
                ++ lib.optional (cfg.qmdEmbedModel != null) "QMD_EMBED_MODEL=${cfg.qmdEmbedModel}";
              WorkingDirectory = userHome;
              StandardOutput = "journal";
              StandardError = "journal";
            }
          ];

          Install = {
            WantedBy = ["default.target"];
          };
        };

        # Ensure cache + config dirs exist with correct ownership so the
        # user service can write into them without HOMEDIR-not-writable
        # errors. qmd auto-creates index.sqlite on first use.
        systemd.user.tmpfiles.rules = [
          "d ${qmdConfigDir} 0755 ${cfg.user} users -"
          "d ${qmdCacheDir} 0755 ${cfg.user} users -"
        ];
      };
    };
  };
}
