# Eval-time guard: every declared sops secret key must EXIST in its
# (encrypted) sopsFile — BEFORE the deploy dies at activation with
#   sops-install-secrets: manifest is not valid … key 'X' cannot be found
#
# Incident class (2026-09-04): sops.nix declared browser_history_agent_db_token
# on master while the encrypted browser-history.yaml never gained the key.
# Every switch from master failed in the ACTIVATION phase (after a full
# build, at the worst possible moment). Because sops encrypts VALUES but
# keeps key NAMES in plaintext, existence needs no age key: a pure line-scan
# of the encrypted YAML at eval time.
#
# Scope:
#   - top-level keys only (every secret in this repo is top-level; secrets
#     with a nested `key = "a.b"` are skipped)
#   - secrets whose sopsFile is unreadable at eval time are skipped (runtime
#     paths like /run/secrets/sops-nix-age-key — quickshell.nix)
#
# Enforced wherever assertions are forced: `nix flake check` (pre-commit, CI).
#
# Negative test: tests/test-sops-key-audit.nix
{
  flake.nixosModules.sops-key-audit =
    {
      config,
      lib,
      ...
    }:
    let
      # Top-level YAML key names of an encrypted sops file.
      topLevelKeys =
        file:
        let
          lines = builtins.split "\n" (builtins.readFile file);
          keyLines = builtins.filter (l: builtins.match "[A-Za-z0-9_-]+:.*" l != null) lines;
        in
        map (l: builtins.head (builtins.match "([A-Za-z0-9_-]+):.*" l)) keyLines;

      checkSecret =
        name: secret:
        let
          parsed = builtins.tryEval (topLevelKeys secret.sopsFile);
        in
        if !parsed.success then
          null
        else if secret.key != name then
          null
        else if builtins.elem name parsed.value then
          null
        else
          {
            assertion = false;
            message = "sops-key-audit: secret '${name}' is declared but its key is MISSING from ${toString secret.sopsFile}. The deploy would fail at activation with \"sops-install-secrets: manifest is not valid\". Add the key to the encrypted file (sudo sops <file> from the repo root, or SOPS_AGE_KEY=... sops <file>) or remove the declaration.";
          };

      declaredSecrets =
        if config ? sops && config.sops ? secrets then config.sops.secrets else { };

      results = lib.mapAttrsToList checkSecret declaredSecrets;
    in
    {
      config.assertions = builtins.filter (r: r != null) results;
    };
}
