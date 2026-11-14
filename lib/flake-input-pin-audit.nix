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
#   - LOCK INTEGRITY (2026-10-23, surface 3): for every declared
#     rev-in-URL pin, the node the ROOT actually references must carry
#     that exact rev. Born from a real split brain — `nodes.nixpkgs` sat
#     ORPHANED at the broken tip 02c087f3 while root resolved to
#     `nixpkgs_4` (the pinned fe13242), and both the pre-commit tarball
#     guard and the CI compat step probed the orphan. Blind guards on a
#     split lock are worse than no guards, because they read green.
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
    paperless-gpt-src = "TAG-PINNED at v0.31.0 (bumped from v0.28.0 2026-11-06) so the vendorHash + npmDepsHash in pkgs/paperless-gpt.nix stay reproducible (a moving ref re-breaks the FODs on every lock update). LIFT: bump tag + both hashes together deliberately.";
    qmd = "TAG-PINNED at v2.8.3. LIFT: bump the tag deliberately and re-verify the CLI + `qmd mcp` (upstream's nodeModules FOD is only valid per-tag).";
    # ── 2026-11-12 deploy-unblock pin (the recurring hermes patchelf leg) ──
    # The poisoned patchelf-0.15.2 + executable-header-load-overlap pair
    # lives in hermes-agent's OWN nested lock, not the root nixpkgs: at
    # d1db1bc6 the pair rejects 4/6 hunks and poisons the
    # ffmpeg/node/pnpm/hermes chain (the 2026-11-09 gen-992 arc,
    # recurring; 2026-11-10 deploy-997 named it "known recurring; float
    # onto this graph = guaranteed red"). 21ae0e12 is the gen-992/gen-997
    # deployment-proven rev (live 2026-11-09/10) and carries the
    # env-bridge blessing (31561e37 is an ancestor). LIFT: upstream
    # re-syncs their nested patchelf packaging/patch pair + keep-going
    # toplevel proof with hermes-agent realized on the floated rev.
    hermes-agent = "REV-PINNED at 21ae0e12 (2026-11-12): upstream's nested patchelfFixed pair rejects 4/6 hunks (the 2026-11-09 gen-992 arc recurring). LIFT: upstream re-syncs their nested patchelf packaging + keep-going toplevel proof on the floated rev.";
    # ── 2026-11-12 root + hermes routing (the 0.15.2 patchelf mispairing) ──
    # nixpkgs (root): unstable tip still ships patchelf 0.15.2 (probed) and
    # its newer stdenv broke the 2026-11-11 tool floats (cvagent/journal/
    # discordsync/pma — proof4 red under tip, proof2 green under f4a03c00).
    # f4a03c00 is the proof2-proven graph; hermes's patchelf mispairing is
    # neutralized separately via nixpkgs-hermes. LIFT: unstable ships
    # patchelf >= 0.19 again AND the floated tools build green on the
    # floated rev (keep-going toplevel proof).
    nixpkgs = "REV-PINNED at f4a03c00 (2026-11-12): tip's stdenv broke the 2026-11-11 tool floats (proof4 vs proof2) and its patchelf 0.15.2 mispairs hermes — the hermes half is neutralized via nixpkgs-hermes. LIFT: unstable patchelf >= 0.19 + floated tools green on the floated rev.";
    nixpkgs-hermes = "REV-PINNED at f9a75f41 (2026-11-12): hermes-agent's patchelfFixed patch targets 0.19-era source; this dedicated input hands hermes the gen-992/997-proven graph while the root serves the fleet (nixpkgs-llama-rag precedent). LIFT: unstable's patchelf >= 0.19 again (probe + toplevel proof), then collapse the follows back to the root.";
    # ── 2026-10-23 deploy-rollback set (two of the original five remain) ─
    # The 2026-10-20 nixos-unstable tip broke the toplevel build in five
    # independent places at once and re-staled ten FOD hashes downstream.
    # These pins hold the last build-proven rev per input so neither the
    # weekly flake-update PR nor an ad-hoc `nix flake update` re-breaks the
    # tree unattended. Every LIFT condition names a concrete observable.
    #
    # templ, overview and dankMaterialShell were LIFTED 2026-10-25 on owner
    # directive ("always on latest") after the causes were re-attributed:
    # the overview break came from forcing the root templ CLI into
    # overview/inboxclean builds (`templ-cli.follows` / `templ.follows`),
    # not from either input's own rev. Removing those follows lines let all
    # three float; each consumer now builds with the templ CLI that matches
    # its go.mod.
    # ── 2026-10-23 deploy-rollback set — FULLY LIFTED 2026-11-06 ────────
    # The 2026-10-20 nixos-unstable tip broke the toplevel build in five
    # independent places at once and re-staled ten FOD hashes downstream,
    # so nixpkgs + signoz-src were pinned back per-input. Owner directive
    # 2026-11-06 ("EVERYTHING on the latest version") lifted both pins:
    # nixpkgs row REMOVED 2026-11-06 — re-floated to nixos-unstable,
    # proof-gated per the pin's own LIFT observable (keep-going toplevel
    # with aw-core AND linux-7.3-modules realized); anything still broken
    # upstream gets a fresh per-input pin, not a blanket rollback.
    # signoz-src row REMOVED 2026-11-06 — back on ?ref=main; the Go-1.26
    # sonic patches in modules/nixos/services/patches/ must come back
    # green (or be dropped where sonic >= 1.15 landed) in the re-proof.
    # templ, overview and dankMaterialShell were LIFTED 2026-10-25 on owner
    # directive ("always on latest") after the causes were re-attributed:
    # the overview break came from forcing the root templ CLI into
    # overview/inboxclean builds (`templ-cli.follows` / `templ.follows`),
    # not from either input's own rev. Removing those follows lines let all
    # three float; each consumer now builds with the templ CLI that matches
    # its go.mod.
    # ── 2026-11-02 04:12 lock-float proof holds ────────────────────────
    # The 03:16 + 04:12 blanket float moved ~70 inputs unproven (daemon
    # sweeps); the 04:32 keep-going enumeration left three roots that hash
    # shims cannot fix — upstream breakage classes, pinned back to the last
    # build-proven rev per input (log:
    # ~/.cache/lockfloat/float-proof-20261102-043225-lars.log).
    # monitor365 row REMOVED 2026-11-03: the wasm-bindgen 0.2.130 hash
    # paste (lofzu1Ubn…) landed on origin/master (ebfa4056f) — pin dropped,
    # input re-floated, toplevel proof green (lift ritual complete).
    # vision-review-agent row REMOVED 2026-11-03: upstream restored the
    # go.mod floor to 1.27.2 (59cc272, pushed) — pin dropped, probe build
    # green, toplevel proof green (lift ritual complete).
    # library-policy row REMOVED 2026-11-03: pin dropped that evening; the
    # a7aa44d "fix" was ineffective (go.mod bumps are cosmetic under the
    # flake deps map — the two-graphs trap), the real fix being
    # go-health-dashboard d4a6534 adopting the branded InstanceID plus
    # library-policy c1dc17a floating its own go-health inputs past the
    # break (worktree FOD green; .#library-policy green through this lock,
    # shim dropped — lift ritual complete).
    # project-discovery-daemon row REMOVED 2026-11-03 night: the corrected
    # root cause (pdd's own go-daemon flake pin stale at 138ce86e vs go.mod
    # v0.4.0 — NOT "symbol only in godmn's unpublished tree", which was
    # WRONG) was fixed upstream in a6dd6a3, pushed to origin/master — pin
    # dropped, input re-floated, toplevel proof re-run (lift ritual
    # complete).
    # ── 2026-11-02 04:12 lock-float proof holds ────────────────────────
    # The 03:16 + 04:12 blanket float moved ~70 inputs unproven (daemon
    # sweeps); the 04:32 keep-going enumeration left three roots that hash
    # shims cannot fix — upstream breakage classes, pinned back to the last
    # build-proven rev per input (log:
    # ~/.cache/lockfloat/float-proof-20261102-043225-lars.log).
    # monitor365 row REMOVED 2026-11-03: the wasm-bindgen 0.2.130 hash
    # paste (lofzu1Ubn…) landed on origin/master (ebfa4056f) — pin dropped,
    # input re-floated, toplevel proof green (lift ritual complete).
    # vision-review-agent row REMOVED 2026-11-03: upstream restored the
    # go.mod floor to 1.27.2 (59cc272, pushed) — pin dropped, probe build
    # green, toplevel proof green (lift ritual complete).
    # library-policy row REMOVED 2026-11-03: pin dropped that evening; the
    # a7aa44d "fix" was ineffective (go.mod bumps are cosmetic under the
    # flake deps map — the two-graphs trap), the real fix being
    # go-health-dashboard d4a6534 adopting the branded InstanceID plus
    # library-policy c1dc17a floating its own go-health inputs past the
    # break (worktree FOD green; .#library-policy green through this lock,
    # shim dropped — lift ritual complete).
    # project-discovery-daemon row REMOVED 2026-11-03 night: the corrected
    # root cause (pdd's own go-daemon flake pin stale at 138ce86e vs go.mod
    # v0.4.0 — NOT "symbol only in godmn's unpublished tree", which was
    # WRONG) was fixed upstream in a6dd6a3, pushed to origin/master — pin
    # dropped, input re-floated, toplevel proof re-run (lift ritual
    # complete).
    # cv row REMOVED 2026-11-06: the pin held build-hash stability only —
    # the cv-server SIGSEGV loop is REV-INDEPENDENT (nil-deref at
    # ChatstoreSessions.HealthCheck, sessions_chatstore.go:112), so the
    # pin guarded nothing runtime-side; lifted on the owner's
    # "everything latest" directive, vendorHash re-measure rides the
    # toplevel proof. Upstream fix (nil-guard + chunked rehydration)
    # remains the real LIFT for the crash-loop itself.
    # hermes-agent row REMOVED 2026-11-06: the 2026-10-25 pin (patchelf#672
    # patch context vs the root pin's patchelf 0.15.2) lifted itself when
    # the root nixpkgs floated to nixos-unstable — its patchelf contains
    # #672, so pm-ripgrep/pm-node patchPhase is the re-proof gate.
    # browser-history row REMOVED 2026-11-02 17:0x: the 15:28 doctor-series
    # split push healed — the full F2-F7 series landed on origin/master
    # (e506008..c6bcfab) and the pin + row were dropped together per the
    # lift ritual (re-lock, toplevel proof).
    # inboxclean row REMOVED 2026-10-25: the 2026-10-25 go-1.27.3-floor pin
    # was lifted by the nixpkgs-unstable follow (flake.nix) — the input
    # floats on upstream master again, and the FOD proves the toolchain.
    # bank-sync row REMOVED 2026-10-16: the 2026-10-14 ceiling pin was lifted
    # by the owner-ratified fresh-start cutover (prod journal archived once by
    # the bank-sync-fresh-start oneshot; see flake.nix bank-sync comment).
    # ── 2026-11-06 templ-API-removal pins ──────────────────────────────
    # a-h/templ v0.3.1100 DELETED templ.ResolveAttributeValue and
    # templ.JoinURLErrs (present in v0.3.1070, absent from the v0.3.1100
    # tag). Every generated *_templ.go produced by an older generator calls
    # them, so a daemon "chore(deps)" bump of the templ require line
    # silently breaks the compile of any repo that has not ALSO regenerated
    # its templates with the v0.3.1100 generator. The fleet is mid-wave:
    # some repos regenerated (buildflow ba3cd98), some only bumped go.mod
    # (DiscordSync 2f3b275). Evidence: templ v0.3.1100 runtime.go has no
    # ResolveAttributeValue (v0.3.1070 runtime.go:697 does); local probes:
    # library-policy@fca47ff + templ v0.3.1070 builds green, @v0.3.1100
    # dies "undefined: templ.ResolveAttributeValue".
    # Same class, one pin per app: each daemon "chore(deps)" commit bumped
    # the templ require line without regenerating that repo's templates.
    # Rows REMOVED 2026-11-11 (discordsync, library-policy, journal,
    # project-dependency-graph, golangci-lint-auto-configure, overview):
    # every upstream tip was fixed AT SOURCE (regen at templ v0.3.1100, the
    # disgo v0.20 CacheGuild migration, dedup/v4 + cmdguard/v5 deps-map
    # wiring, generator-parity pins) and lock-free package probes are green
    # at the pushed revs — lift ritual complete per input.
    # file-and-image-renamer row REMOVED 2026-11-13: pin lifted after the
    # upstream pin-alignment wave (cc4ed62a). The 2026-11-11 diagnosis was
    # wrong about the mechanism: vendor/ is GITIGNORED in that repo, so no
    # committed vendor refresh was ever the LIFT condition — the repo's
    # per-dep *-src flake pins had lagged its go.mod (templ-components
    # v1.26.0 vs v1.27.0, cqrs-htmx 357cdfc vs v4.16.0, cmdguard, go-output,
    # go-health, go-health-dashboard, go-datastar, go-sse). Aligned pins +
    # re-derived vendorHash -> clean package build green; input now floats
    # on ?ref=refs/heads/master.
    # crm row REMOVED 2026-11-13 (owner directive: always latest): the
    # deliberate policy pin is lifted and the input floats on
    # ?ref=refs/heads/master. Rationale in flake.nix: the "vendorHash
    # treadmill" that motivated the 10-14 pin is dead — upstream's own
    # vendorHash.nix bakes the correct hash from c626704 onward, and the
    # last four roll probes (through f6ccd43) built green with no
    # consumer-side override.
    # ── 2026-11-14 cv rollback pin round 2 (guard fix pushed, tip re-trips) ──
    # The morning's 066f76c row was briefly LIFTED when the owner pushed
    # the go-sum tidy fix (CV 9e3687b97, 10:00Z) — but master tip
    # eb951951 (12:30Z, "restore module-graph go.sum entries") re-added
    # entries the module graph drops (committed go.sum runs ~166 lines
    # fat of tidy), tripping the same fail-closed FOD guard. The input is
    # therefore re-pinned at 9e3687b97 ITSELF — the pushed fix rev (pure
    # go.sum drop), the only build-proven candidate between two broken
    # tips (f25e54c5 pre-fix, eb951951 post-restore).
    cv = "REV-PINNED at 9e3687b9 (2026-11-14): the pushed go-sum tidy fix itself — master tip eb951951 re-trips CV's fail-closed go-sum tidy guard by restoring module-graph entries. LIFT: a master tip at or past eb951951 whose go-modules FOD builds with the guard green (nix build of the cv go-modules FOD or toplevel keep-going) — drop the rev.";
    # ── 2026-11-14 deploy-blocker rollback (health-hub broken tip) ──────
    # Tip caf9970 is BROKEN upstream: cmd/health-hub imports
    # go-health-dashboard/internal/env, which no module in its graph
    # provides (compile failure in the go-modules FOD, first-hand
    # ~/.cache/signoz-fod-fix/keepgoing-post5.log). 30dee8fe is the last
    # build-proven rev (green through the full toplevel pre-float).
    go-health-dashboard = "REV-PINNED at 30dee8fe (2026-11-14): tip caf9970 is broken upstream (cmd/health-hub imports internal/env, no module provides it — FOD compile failure). LIFT: a master tip whose health-hub package builds green through the toplevel keep-going — float, prove, drop the rev.";
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

  declaredInputs =
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
    (foldl' step {
      current = null;
      findings = [ ];
    } lines).findings;

  declaredFindings = concatLists (
    map (
      f:
      map (detail: {
        inherit (f) name;
        inherit detail;
      }) (classifyUrl f.url)
    ) declaredInputs
  );

  # ── surface 3: declared rev pin vs the node root ACTUALLY resolves ───
  # A rev-in-URL pin is only durable if the node the ROOT references carries
  # that rev. 2026-10-23 split brain (this surface's origin): the lock held
  # `nodes.nixpkgs` — an ORPHAN at the broken tip 02c087f3 — alongside
  # `nixpkgs_4`, the node root resolved to (the pinned fe13242). Both the
  # pre-commit tarball guard and the CI compat step probed `nodes.nixpkgs`,
  # i.e. a node nothing builds from, so a regression on the LIVE node was
  # invisible. This surface also catches a lock hand-edited to a rev that is
  # not the declared one. Eval-enforced, so no script/CI wiring can drift.

  declaredRev =
    url:
    let
      m = match "(github|gitlab|sourcehut):[^/]+/[^/?#]+/([0-9a-f]{40})" url;
    in
    if m == null then null else elemAt m 1;

  rootNodeKey = inputName: lock.nodes.${lock.root}.inputs.${inputName} or null;

  lockIntegrityViolations = filter (v: v != null) (
    map (
      f:
      let
        rev = declaredRev f.url;
        nodeKey = rootNodeKey f.name;
        lockedRev = lock.nodes.${nodeKey}.locked.rev or null;
      in
      if rev == null then
        null
      else if nodeKey == null then
        "${f.name}: declared as a rev-in-URL pin but is not a root input of flake.lock"
      else if lockedRev != rev then
        "${f.name}: flake.nix pins rev ${rev} but the root-referenced lock node '${nodeKey}' is at ${
          if lockedRev == null then "no rev" else lockedRev
        } — the lock is split or stale; run `nix flake lock` and commit the result"
      else
        null
    ) declaredInputs
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
    lockIntegrityViolations
    ++ map (name: "${name}: ${concatStringsSep "; " findingsByInput.${name}}") (
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
  inherit violations warnings lockIntegrityViolations;
}
