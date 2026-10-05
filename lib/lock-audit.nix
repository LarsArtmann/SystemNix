# flake.lock infra-follows audit (2026-10-02 lock dedup).
#
# Nix locks one node per input-graph PATH: any root input that declares an
# infra dep (flake-parts, treefmt-nix, nixpkgs, systems, flake-utils) without
# a `follows` pin to the root carries its own duplicate lock copy. Before the
# 2026-10-02 dedup that accumulated 421 lock nodes for 235 unique revs; a
# blanket lock wave regrows it silently.
#
# This audit runs at EVAL time (forced via builtins.seq in flake.nix outputs)
# and fails any eval when a NEW root-owned, unfollowed infra edge appears.
# Deep edges (a tool's copy of another tool locking infra) are IGNORED here —
# they are only fixable upstream in the LarsArtmann tool repos (queued).
#
# Semantics: for each root input X and infra dep D, the entry
# nodes.X.inputs.D must be either
#   - absent,
#   - a follows alias (a string naming a root input), or
#   - a path array (["<root-input>" ...]),
# and NEVER a plain node-key string of its own. Anything else is a violation
# unless listed in `deliberate` below with a reason.
#
# fix for a violation: add `<input>.inputs.<dep>.follows = "<dep>";` to the
# infra-follows group at the end of the inputs attrset in flake.nix
# (eval-only deps are ALWAYS safe to follow). Only if the consumer's FODs
# were validated against its own pin (qmd bun, discordsync rollback class)
# add a documented entry to `deliberate` instead — never both.
# `lock` is the parsed flake.lock; `deliberate` (optional, attrset
# "<input>.<dep>" -> reason) overrides the built-in non-follow table — used
# by the self-test fixtures, which contain none of the real edges.
{
  lock,
  deliberate ? {
    "discordsync.nixpkgs" =
      "FOD cache-hit interim rollback (2026-09-23): upstream vendorHash validated against its own locked nixpkgs";
    "project-dependency-graph.nixpkgs" =
      "vendorHash validated against upstream's own locked nixpkgs (go 1.27.1 via nixos-unstable; following would re-tool the go-modules FOD on every root-nixpkgs bump — the 2026-10-05 a7868a7 wave class)";
    "qmd.nixpkgs" = "bun nodeModules FOD hash validated against upstream's own nixpkgs bun";
    "nsfw-classifier.nixpkgs" =
      "git+file local dev checkout; own build env until its FODs are next regenerated";
  },
}:
let
  inherit (lock) nodes;
  rootInputs = nodes.root.inputs;

  infraDeps = [
    "flake-parts"
    "treefmt-nix"
    "nixpkgs"
    "systems"
    "flake-utils"
  ];

  # A dep value is a follows alias iff the string names a root input (alias
  # semantics dominate: the lock generator suffixes node keys on collision,
  # so a plain node-key string can never collide with a root input name).
  isAlias = value: builtins.isString value && builtins.hasAttr value rootInputs;

  edgeViolations =
    let
      checkInput =
        inputName: nodeKey:
        let
          nodeInputs = nodes.${nodeKey}.inputs or { };
        in
        builtins.concatMap (
          dep:
          let
            value = nodeInputs.${dep} or null;
            isDeliberate = builtins.hasAttr "${inputName}.${dep}" deliberate;
            bad = value != null && !isAlias value && !builtins.isList value && !isDeliberate;
          in
          if bad then
            [
              "${inputName} locks its own '${dep}' (node ${value}, rev ${
                (nodes.${value}.locked or { }).rev or "?"
              }) — add '${inputName}.inputs.${dep}.follows = \"${dep}\";' to the infra-follows group in flake.nix"
            ]
          else
            [ ]
        ) infraDeps;
    in
    builtins.concatMap (
      inputName:
      let
        ref = rootInputs.${inputName};
      in
      if builtins.isString ref && builtins.hasAttr ref nodes then checkInput inputName ref else [ ]
    ) (builtins.attrNames rootInputs);

  # A deliberate entry pointing at an edge that no longer exists is stale
  # configuration — fail so the table cannot rot.
  staleDeliberate =
    let
      activeEdges = builtins.concatLists (
        builtins.map (
          inputName:
          let
            ref = rootInputs.${inputName};
          in
          if builtins.isString ref && builtins.hasAttr ref nodes then
            builtins.map (dep: "${inputName}.${dep}") (builtins.attrNames (nodes.${ref}.inputs or { }))
          else
            [ ]
        ) (builtins.attrNames rootInputs)
      );
    in
    builtins.map (key: "deliberate allowlist entry '${key}' matches no live edge — remove it") (
      builtins.filter (key: !builtins.elem key activeEdges) (builtins.attrNames deliberate)
    );
in
edgeViolations ++ staleDeliberate
