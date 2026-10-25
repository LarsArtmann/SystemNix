# Lock-float eval gate (2026-10-25, fleet-stabilization F07-F10).
#
# A blanket `nix flake update` floats many revs in one change; the 2026-10-23
# wave carried four eval-breaking floats (hermes-python IFD at hermes
# bf0203a, a transitive crowdsec module in an unfetched nixpkgs copy) that
# surfaced only as a DOA deploy mid-wave — deploy.sh validation failed after
# the wave had already landed. This gate makes every root-input rev float a
# CONSCIOUS act: flake/expected-locks.nix is the reviewed registry of the rev
# each root input must lock at; a mismatch fails eval (and therefore
# pre-commit, CI, and deploy validation) naming the drifted inputs.
#
# There is no separate allowlist: updating the registry in the same change IS
# the deliberate-float mechanism, and the registry's git history is the float
# audit log. The float procedure (also spelled out in the registry header and
# the throw message in flake.nix): prove the new revs evaluate
#   nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel \
#     --keep-going --no-link
# then regenerate flake/expected-locks.nix and commit lock + registry
# TOGETHER.
#
# Semantics: for each root input name N (string node-key form — follows
# arrays carry no own node and are skipped):
#   - node carries a locked.rev:
#       expected.<N> absent        -> violation "unregistered input"
#       expected.<N> != locked.rev -> violation "floated rev"
#   - node carries NO locked.rev (path inputs, follows-shared nodes without
#     revs): expected.<N> must ALSO be absent -> else "stale registry entry"
#     (table rot — the lock-audit stale-deliberate class; registry and lock
#     must move together in BOTH directions).
#
# Shared-node string aliases (a follows encoded as a plain string pointing at
# root's own node — see lib/lock-audit.nix isAlias) intentionally register
# under BOTH names: a follow flip changes the aliased input's resolution and
# deserves the same conscious registry update as a rev float.
#
# Returns a list of violation strings ([] = green). `lock` is the parsed
# flake.lock; `expected` is the attrset from flake/expected-locks.nix.
{
  lock,
  expected,
}:
let
  inherit (lock) nodes;
  rootInputs = nodes.root.inputs;

  entries = builtins.filter (e: builtins.isString e.nodeKey) (
    builtins.attrValues (
      builtins.mapAttrs (name: nodeKey: {
        inherit name nodeKey;
      }) rootInputs
    )
  );

  violations = builtins.foldl' (
    acc: entry:
    let
      node = nodes.${entry.nodeKey} or null;
      actual = if node == null then null else node.locked.rev or null;
      registered = expected.${entry.name} or null;
    in
    if actual != null && registered == null then
      acc
      ++ [
        "${entry.name}: locks rev ${actual} but has NO registry entry — register it in flake/expected-locks.nix (never delete entries to go green)"
      ]
    else if actual != null && registered != actual then
      acc
      ++ [
        "${entry.name}: floated rev ${actual}, registry expects ${registered}"
      ]
    else if actual == null && registered != null then
      acc
      ++ [
        "${entry.name}: registry entry ${registered} is stale — the input no longer locks a rev (follows/path flip); remove the entry in the same change"
      ]
    else
      acc
  ) [ ] entries;
in
violations
