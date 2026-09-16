# Wiring test for the crush-config HM module (github:LarsArtmann/crush-config)
# — phase 2 (2026-09-15): the module renders the crushrc AND installs the
# global agent context (AGENTS.md + references/) from the repo.
#
# Pure eval against the LOCKED input rev — the same module source production
# consumes, so a repo-side regression cannot pass here after a lock bump.
# A consumer host that silently loses the agent-context install loads every
# crush session without the global guidelines (the phase-2 failure mode).
#
# Negative case note: pass/fail is decided at EVAL time, so a passing
# derivation always has the same store path (eval-cache trap). The mutation
# case below (agent-context entry removed must be CAUGHT) is what proves the
# checker bites; it was additionally hand-probed via extendModules before
# being trusted.
{
  pkgs,
  inputs,
}:
let
  inherit (pkgs) lib;
  inherit (inputs.crush-config.homeManagerModules) crush;

  # Stub module system: the HM module only writes xdg.configFile entries.
  eval =
    extra:
    (lib.evalModules {
      modules = [
        {
          options.xdg.configFile = lib.mkOption {
            type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
          };
        }
        crush
        {
          programs.crush-config = {
            enable = true;
            # evo-x2 shape (platforms/nixos/users/home.nix): the host-coupled
            # wrapper (as the user config writes it) + the qmd MCP.
            golangciLintLspCommand = "$HOME/.local/bin/golangci-lint-lsp-wrapper";
            mcps.qmd = {
              command = "qmd";
              args = [ "mcp" ];
            };
          };
        }
        extra
      ];
    }).config;

  cfg = eval { };
  files = cfg.xdg.configFile;
  rc = files."crush/crushrc".text;

  agentDocFiles = lib.filterAttrs (n: _: lib.hasPrefix "crush/" n && n != "crush/crushrc") files;

  # The exact phase-2 regression: the agent-context install vanishes (e.g.
  # someone reverts the module to crushrc-only). The checker must notice.
  strippedDocFiles = builtins.removeAttrs agentDocFiles [ "crush/AGENTS.md" ];
  strippedLooksWired = strippedDocFiles ? "crush/AGENTS.md";

  doubleBlank =
    m:
    lib.hasInfix "\n\n\n" m;

  cases = [
    {
      name = "agent-context-installed-from-repo";
      pass =
        agentDocFiles ? "crush/AGENTS.md"
        && lib.all (n: lib.hasPrefix "crush/references/" n) (
          builtins.attrNames (builtins.removeAttrs agentDocFiles [ "crush/AGENTS.md" ])
        )
        && builtins.length (builtins.attrNames agentDocFiles) > 2;
    }
    {
      name = "installed-agents-md-is-the-real-guidelines";
      pass =
        files ? "crush/AGENTS.md"
        && lib.hasInfix "# Parakletos" (builtins.readFile files."crush/AGENTS.md".source);
    }
    {
      name = "host-coupled-values-rendered-quoted";
      pass =
        lib.hasInfix "lsp add golangci_lint_ls --command \"$HOME/.local/bin/golangci-lint-lsp-wrapper\"" rc
        && lib.hasInfix "mcp add qmd --command \"qmd\" --args \"mcp\"" rc;
    }
    {
      name = "personal-set-rendered";
      pass =
        lib.hasInfix "crush_key synthetic synthetic_api_key" rc
        && lib.hasInfix "model add zai/glm-5.3-flash" rc
        && lib.hasInfix "option context-path $HOME/.config/crush/AGENTS.md" rc;
    }
    {
      name = "rc-blank-line-discipline";
      pass = !doubleBlank rc;
    }
    {
      name = "comment-sits-directly-above-its-statement";
      pass = !lib.hasInfix "disabled.\n\nprovider add minimax" rc;
    }
    {
      name = "removed-agent-context-caught";
      pass = !strippedLooksWired;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "test-crush-config" { } "touch $out"
else
  throw ''
    crush-config wiring regression: ${lib.concatStringsSep ", " broken}

    The locked github:LarsArtmann/crush-config rev no longer satisfies the
    phase-2 contract (crushrc render + AGENTS.md/references install). Either
    the lock needs bumping to a rev carrying the phase-2 module, or the
    module broke — check
    ${inputs.crush-config.outPath}/modules/home-manager/crush.nix
  ''
