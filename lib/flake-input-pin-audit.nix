# flake input URL pin audit (2026-10-14).
#
# The pin policy (user directive 2026-09-16, docs/agents/nix-flakes.md):
# "?ref=master/main on every flake input unless upstream is BROKEN — hard
# rev-in-URL pins carry ONLY documented valid reasons." A hard pin makes
# `nix flake lock --update-input <input>` a SILENT NO-OP, so bumps require
# flake.nix edits and pins rot unnoticed — the 2026-10-14 class: FOUR
# rollback pins (erraudit, bank-sync, crm, golangci-lint-auto-configure)
# landed in one lock wave, each hiding a stale upstream vendorHash behind
# an URL nobody remembers to lift.
#
# This audit runs at EVAL time (forced via builtins.seq in flake.nix
# outputs) and throws when an input URL carries a hardcoded version:
#
#   rev        — SHA-shaped segment in the URL path (github:o/r/<40hex>)
#                or a ?rev= query (the ?rev= class was previously guarded
#                inline in flake.nix; consolidated here 2026-10-14)
#   tag        — version/tag-shaped ref: refs/tags/*, v-prefix semver,
#                bare dotted versions (github:tobi/qmd/v2.8.3)
#
# Floating refs are ALLOWED: master, main, any refs/heads/<branch>, any
# bare branch name (fork, stable, nixos-unstable, nixos-24.05 — these
# track upstream and lock updates move them).
#
# Surfaces scanned:
#   - the DECLARED input URLs, extracted from the flake.nix SOURCE TEXT
#     (primary truth: catches pins even when flake.lock is stale — the
#     erraudit case, where the lock still held the pre-pin original).
#     WHY source text and not the outputs-level `inputs` binding: there
#     each input is the RESOLVED flake (an outputs attrset — it carries
#     no `url`, so an attrset scan is blind), and iterating those forces
#     every input flake's outputs inside our own guard (eager eval tax,
#     GC-eviction fetch risk, and `self` recurses into the guard itself —
#     both hit live 2026-10-14). A line-scanner over the `inputs = { … }`
#     attrset region handles both declaration forms (`name.url = "…"` and
#     `name = { url = "…"; };`) — the same source-scan method the repo's
#     other lint guards use.
#   - flake.lock `original` nodes for the ?rev= query class only (old
#     inline-guard parity — hand lock surgery). Original ref/rev fields
#     are deliberately NOT scanned: a stale lock lags lifted declarations
#     and would false-fire during every pin lift.
# Findings are deduplicated per input across surfaces.
#
# `git+file:` inputs are EXEMPT (interim local-checkout pins per
# docs/INTERIM-INPUT-PINS.md §A — CI cannot fetch them anyway; the pin
# moves in flake.lock, never the URL).
#
# `allowlist` registers deliberate pins: "<input>" -> "reason + LIFT
# condition". An allowlisted pin is traced on EVERY eval (visible warn);
# an allowlist entry whose input is no longer pinned is a VIOLATION
# (stale entry — the pin was lifted, remove the row and re-verify
# upstream green per the pin policy).
{
  flakeSource,
  lock,
  allowlist ? {
    nixpkgs-llama-rag = "REV-PINNED nixpkgs holding the llama.cpp 0.3.0 build (last build proven serving on gfx1150 before the 0.4.0 mid-model-load CPU-spin regression, live 2026-09-14). LIFT: 0.4.0+ spin regression fixed upstream + re-verified live — drop the input entirely, do not update it.";
    paperless-gpt-src = "TAG-PINNED at v0.28.0 so the vendorHash + npmDepsHash in pkgs/paperless-gpt.nix stay reproducible (a moving ref re-breaks the FODs on every lock update). LIFT: bump tag + both hashes together deliberately.";
    qmd = "TAG-PINNED at v2.8.3. LIFT: bump the tag deliberately and re-verify the CLI + `qmd mcp` (upstream's nodeModules FOD is only valid per-tag).";
    bank-sync = "Documented-ceiling rollback 2026-10-14 (second float): a lock-only rollback edit floated past the ceiling within hours and unanchored a deploy; hard URL pin + lock override make updates and blanket re-locks NO-OPs by design. LIFT: edit the URL (docs/services/bank-sync.md RE-FLOAT gotcha).";
  },
}:
let
  inherit (builtins)
    match
    elemAt
    hasAttr
    attrNames
    filter
    concatStringsSep
    concatLists
    split
    foldl'
    ;

  mapAttrsToList = f: set: builtins.attrValues (builtins.mapAttrs f set);

  # ── ref classification ──────────────────────────────────────────────

  isHexSha =
    s: match "[0-9a-f]+" s != null && builtins.stringLength s >= 7 && builtins.stringLength s <= 40;

  isVersionShaped = s: match "v[0-9].*" s != null || match "[0-9]+([.][0-9a-zA-Z]+)*" s != null;

  # master, main, refs/heads/*, bare branch names → floating. refs/tags/*
  # and version-shaped values → tag pins. SHA-shaped → rev pins.
  classifyRef =
    ref:
    if ref == "master" || ref == "main" then
      null
    else if match "refs/heads/.+" ref != null then
      null
    else if match "refs/tags/.+" ref != null then
      "VERSION/TAG pin (?ref=${ref} — force-movable upstream, silently rots)"
    else if isHexSha ref then
      "hard REV pin (?ref=${ref} — `nix flake lock --update-input` is a SILENT NO-OP)"
    else if isVersionShaped ref then
      "VERSION/TAG pin (?ref=${ref} — force-movable upstream, silently rots)"
    else
      null;

  # URL-path ref for the shorthand schemes (github:owner/repo/<ref>), or
  # null when the URL has none.
  pathRef =
    url:
    let
      m = match "(github|gitlab|sourcehut):([^/]+)/([^/?#]+)(/([^?#]*))?([?].*)?" url;
      r = if m == null then null else elemAt m 4;
    in
    if r == null || r == "" then null else r;

  queryRef =
    url:
    let
      m = match ".*[?&]ref=([^&]*)" url;
    in
    if m == null then null else elemAt m 0;

  hasRevQuery = url: match ".*[?&]rev=.*" url != null;
  isGitFile = url: match "git\\+file:.*" url != null;

  # All violation details for one URL (empty list = clean).
  classifyUrl =
    url:
    if url == null || isGitFile url then
      [ ]
    else
      (filter (d: d != null) [
        (
          if hasRevQuery url then
            "URL carries ?rev= (overrides flake.lock, silently re-pins on every lock re-run)"
          else
            null
        )
      ])
      ++ (filter (d: d != null) (
        map classifyRef (
          filter (r: r != null) [
            (pathRef url)
            (queryRef url)
          ]
        )
      ));

  # ── surface 1: declared URLs from the flake.nix source text ─────────
  # Line-scanner over the `inputs = { … };` region (stops at the 2-space
  # closer). Both declaration forms: `    name.url = "…";` (dotted,
  # 4-space) and `    name = {` opener + `      url = "…";` (6-space).

  declaredFindings =
    let
      lines = filter builtins.isString (split "\n" flakeSource);
      step =
        state: line:
        let
          dotted = match "    ([a-zA-Z0-9_-]+)[.]url = \"([^\"]*)\";" line;
          opener = match "    ([a-zA-Z0-9_-]+) = \\{" line;
          inner = match "      url = \"([^\"]*)\";" line;
          state' =
            if match "  };" line != null then
              state // { current = null; }
            else if dotted != null then
              state
              // {
                findings = state.findings ++ [
                  {
                    name = elemAt dotted 0;
                    url = elemAt dotted 1;
                  }
                ];
              }
            else if opener != null then
              state // { current = elemAt opener 0; }
            else if inner != null && state.current != null then
              state
              // {
                findings = state.findings ++ [
                  {
                    name = state.current;
                    url = elemAt inner 0;
                  }
                ];
              }
            else
              state;
        in
        state';
    in
    concatLists (
      map
        (
          f:
          map (detail: {
            inherit (f) name;
            inherit detail;
          }) (classifyUrl f.url)
        )
        (foldl' step {
          current = null;
          findings = [ ];
        } lines).findings
    );

  # ── surface 2: flake.lock originals (?rev= class only — old inline-guard
  # parity; original ref/rev fields are skipped so a stale lock lagging a
  # lifted declaration cannot false-fire) ──────────────────────────────

  lockFindings =
    let
      rootInputs = lock.nodes.${lock.root}.inputs or { };
    in
    filter (f: f != null) (
      mapAttrsToList (
        name: nodeKey:
        let
          url = (lock.nodes.${nodeKey}.original or { }).url or "";
        in
        if url != "" && !isGitFile url && hasRevQuery url then
          {
            inherit name;
            detail = "flake.lock original carries ?rev= (overrides the lock, silently re-pins on every lock re-run)";
          }
        else
          null
      ) rootInputs
    );

  # ── dedup per input, split allowlisted vs violations ────────────────

  findingsByInput = foldl' (
    acc: f:
    acc
    // {
      ${f.name} = (acc.${f.name} or [ ]) ++ [ f.detail ];
    }
  ) { } (declaredFindings ++ lockFindings);

  violations =
    map (name: "${name}: ${concatStringsSep "; " findingsByInput.${name}}") (
      filter (name: !hasAttr name allowlist) (attrNames findingsByInput)
    )
    ++ map (
      name:
      "allowlist entry '${name}' matches no live pin — the pin was LIFTED: remove the row from lib/flake-input-pin-audit.nix and re-verify upstream is green per the pin policy"
    ) (filter (name: !hasAttr name findingsByInput) (attrNames allowlist));

  warnings = map (name: "${name} is deliberately pinned — ${allowlist.${name}}") (
    filter (name: hasAttr name findingsByInput) (attrNames allowlist)
  );
in
{
  inherit violations warnings;
}
