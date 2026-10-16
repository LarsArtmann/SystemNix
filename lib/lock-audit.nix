# flake.lock infra-follows audit (2026-10-02 lock dedup).
#
# Nix locks one node per input-graph PATH: any root input that declares an
# infra dep (flake-parts, treefmt-nix, nixpkgs, systems, flake-utils,
# flake-compat, git-hooks) without a `follows` pin to the root carries its
# own duplicate lock copy. Before the 2026-10-02 dedup that accumulated 421
# lock nodes for 235 unique revs; a blanket lock wave regrows it silently.
# flake-compat + git-hooks joined the guarded set 2026-10-08 (root-promoted
# at the consumers' shared revs — see the input blocks above the
# infra-follows group in flake.nix). Alias detection was tightened to
# node-key IMAGE semantics 2026-10-14 (see the isAlias comment below).
#
# This audit runs at EVAL time (forced via builtins.seq in flake.nix outputs)
# and fails any eval when a NEW root-owned, unfollowed infra edge appears.
# Deep edges (a tool's copy of another tool locking infra) are ignored for
# all deps EXCEPT treefmt-nix: since 2026-10-14 every declared treefmt-nix
# edge anywhere in the graph must resolve to the root pin — Nix input
# overrides chain to any depth, so a deep treefmt copy IS fixable from
# SystemNix (the discordsync.inputs.art-dupl.inputs.treefmt-nix.follows
# class, see the infra-follows group in flake.nix) and is therefore
# guarded here. The other deep infra classes remain upstream-queued.
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
    "templ.nixpkgs" =
      "templ's go-modules FOD is validated against its own nixpkgs pin (root-promoted 2026-10-14 for the inboxclean/overview subtree collapse)";
    "crm.nixpkgs" =
      "same rev as root nixpkgs today (7fd4004); follow flip pending the crm follows [decision] (docs/todo/upstream.md wave5 note)";
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
    "flake-compat"
    "git-hooks"
  ];

  # A string dep value is a follows alias iff it names the node key a ROOT
  # input actually resolves to (the IMAGE of rootInputs), never merely a
  # root input NAME: node keys are allocation-order artifacts and CAN
  # collide with input names (2026-10-14 blind spot — art-dupl's edge value
  # "flake-parts" named the root INPUT while pointing at its own separate
  # "flake-parts" node; root's real node was "flake-parts_4"). Canonical
  # locks encode flake.nix follows as arrays; a plain string pointing at
  # root's own node (shared-node form, see the clean fixture) is an alias.
  rootNodeKeys = builtins.filter builtins.isString (builtins.attrValues rootInputs);
  isAlias = value: builtins.isString value && builtins.elem value rootNodeKeys;

  # Resolve a follow path (list of input names, root-relative) to a node
  # key; restarts at the root whenever a segment hits a nested follow
  # array (canonical locks compose chained follows that way).
  resolveFollow =
    seg0:
    let
      go =
        segs: cur:
        if segs == [ ] then
          cur
        else
          let
            v = (nodes.${cur}.inputs or { }).${builtins.head segs} or null;
          in
          if v == null then
            null
          else if builtins.isString v then
            go (builtins.tail segs) v
          else
            go (v ++ builtins.tail segs) (lock.root or "root");
    in
    go seg0 (lock.root or "root");

  rootTreefmtKey =
    let
      v = rootInputs.treefmt-nix or null;
    in
    if v == null then
      null
    else if builtins.isString v then
      v
    else
      resolveFollow v;

  # Deep treefmt-nix guard (2026-10-14): every declared treefmt-nix edge
  # in the whole graph — not just root-owned ones — must resolve to the
  # root pin. Catches both a re-grown deep copy (the discordsync →
  # art-dupl_3 → treefmt-nix_2 class) and a root override that went inert
  # (upstream dropped the input the override pointed through — the
  # latent-drift class in docs/agents/nix-flakes.md).
  deepTreefmtViolations = builtins.concatMap (
    nodeName:
    let
      value = (nodes.${nodeName}.inputs or { }).treefmt-nix or null;
      resolved =
        if builtins.isString value then
          value
        else if builtins.isList value then
          resolveFollow value
        else
          null;
    in
    if value == null || rootTreefmtKey == null || resolved == rootTreefmtKey then
      [ ]
    else if builtins.isString value then
      [
        "${nodeName} locks its own treefmt-nix deep copy (node ${value}, rev ${
          (nodes.${value}.locked or { }).rev or "?"
        }) — add a \'<consumer>.inputs.<owner>.inputs.treefmt-nix.follows = \"treefmt-nix\";' override to the infra-follows group in flake.nix"
      ]
    else
      [
        "${nodeName} treefmt-nix follow resolves to node ${
          if resolved == null then "<dangling-path>" else resolved
        }, not the root treefmt-nix pin (${rootTreefmtKey}) — a root override went inert or points elsewhere"
      ]
  ) (builtins.attrNames nodes);

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
edgeViolations ++ deepTreefmtViolations ++ staleDeliberate
