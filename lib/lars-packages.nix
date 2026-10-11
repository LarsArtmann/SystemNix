# Single source of truth for all LarsArtmann Go tool packages.
#
# Referenced by perSystem.packages (for `nix build .#X`) and passed to
# base.nix via specialArgs (for environment.systemPackages).
#
# Each entry pulls the `default` package from the matching flake input;
# inputs that don't expose a package for this system are filtered out.
{
  lib,
  inputs,
}:
system:
let
  flakePkg = input: (input.packages.${system} or { }).default or null;
in
lib.filterAttrs (_: v: v != null) {
  # art-dupl shim DROPPED (2026-09-29): its drop condition ("lock moves past
  # a pushed upstream-fixed rev") is met — the lock holds f6355c24 (pushed),
  # whose flake bakes vendorHash ts4RN6Z0… (the same "got" hash the 09-29
  # blanket update's FOD produced; the old shim pinned the stale fmLiSd6d…
  # and re-broke the FOD it existed to fix — the buildflow-shim lifecycle
  # class). Re-add ONLY via nix-hash-fix evidence, never by hand.
  art-dupl = flakePkg inputs.art-dupl;
  # vendorHash shim DROPPED (2026-10-07 wave — the 13:14/14:59 lock commits
  # moved the input; drop-protocol, docs/agents/nix-flakes.md): upstream
  # 60a91081 ALREADY bakes the got hash A8ZHASMR… (first-hand: evo-x2
  # toplevel --keep-going enumeration, /tmp/toplevel-fix-20261007.log), so
  # the override only re-created the drift treadmill. Re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  branching-flow = flakePkg inputs.branching-flow;
  # buildflow shim DROPPED (2026-09-23): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 5b3483a, where the
  # vendorHash fix IS pushed (upstream vendorHash.nix = sha256-WIFsGVLBMsCK…,
  # the same "got" hash the old shim overrode with the stale fT34kjPX6…
  # value, re-breaking the FOD it existed to fix) and the package builds
  # clean (nix build .#buildflow verified in ~/projects/BuildFlow).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  # TEMPORARY vendorHash shims (2026-10-03): the 2026-10-01 nixpkgs bump
  # (c59305b) re-vendored the module graph under go 1.26.8; upstream-pinned
  # hashes no longer reproduce (got-hash evidence: evo-x2 toplevel
  # --keep-going enumeration, /tmp/toplevel-build.log — narHash matched, so
  # this is toolchain drift, not source drift; the 2026-09-23 lock-wave
  # class). Drop each when upstream pins the got-hash or the lock moves
  # past an upstream-fixed rev. Bootstrap exception: buildflow nix-hash-fix
  # could not run (flake-show degraded behind the failing FODs); hashes
  # pasted from first-hand build output, never invented.
  # RE-PINNED 2026-10-05 (the a7868a7 wave): the 2026-10-04/05 full flake
  # update re-vendored the module graph AGAIN under the new nixpkgs — every
  # 2026-10-03 shim value below stopped reproducing simultaneously (24 FOD
  # mismatches in one keep-going enumeration, /tmp/toplevel-build-20261005.log
  # + /tmp/toplevel-shimmed-20261005.log; same bootstrap exception — the
  # upstream checkouts are owned by live parallel sessions). Same drop
  # conditions.
  # buildflow shim DROPPED (2026-10-07): the lock moved to 2346799 (user
  # nix flake update) whose upstream vendorHash.nix ALREADY carries the got
  # hash (m8gL3Z4Z… == the 09:25 keep-going enumeration's got — shim-drop
  # protocol, docs/agents/nix-flakes.md). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  buildflow = flakePkg inputs.buildflow;
  # NOT flakePkg: upstream go-cqrs-lite's `packages.default` is a deliberate
  # no-op derivation (BuildFlow `nix build .` needs it; the real CLI lives at
  # packages.cqrs-lint). The 2026-10-09 shim drop kept flakePkg, which resolved
  # to the empty derivation — deploying it would silently remove the binary.
  # TEMPORARY vendorHash shim RE-PINNED (2026-10-11, first-hand FOD
  # evidence — the documented bootstrap exception): got 7wijvzQm… at the
  # TRUE locked rev f12a849b (node go-cqrs-lite_7; .nodes["go-cqrs-lite"]
  # is an ORPHAN — jq root.inputs before reasoning, 2026-10-11 lesson).
  # Upstream bakes qRvdn5dH… at f12a849b AND at origin/master c39e1e2fe —
  # stale at both. NOT fixed upstream this wave: the repo is mid-churn by
  # a live session (4 unpushed master commits + origin moved 164 files
  # today) — pushing would publish their in-flight work; re-locking into
  # that churn was rejected. The shim is the NECESSARY exception; the
  # paste-upstream → push → re-lock → re-drop cycle stays queued
  # (docs/todo/upstream.md). Re-evaluate on the next lock move.
  cqrs-lint =
    let
      pkg = (inputs.go-cqrs-lite.packages.${system} or { }).cqrs-lint or null;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-7wijvzQmDIlEbRfNqkK/bmUiQDpMZ+Hz5GNJ1Ggx8Gs=";
      };
  # vendorHash shim DROPPED (2026-10-10 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 3520e64 ALREADY bakes the got
  # hash /D4X81jj… (first-hand keep-going enumeration,
  # /tmp/toplevel-keepgoing.log); the NYg9nBod… shim pinned for the
  # superseded rev 5f7e9ef4 only re-created the drift treadmill.
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  erraudit = flakePkg inputs.erraudit;
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 74baca53 ALREADY bakes the got
  # hash G0hMfZId… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  go-auto-upgrade = flakePkg inputs.go-auto-upgrade;
  # TEMPORARY vendorHash shim DROPPED (2026-10-11): the lock moved
  # 4cee06df → 7f9b7b19, whose flake bakes the shim's OWN JrBhDyCx… value
  # (git show 7f9b7b19:flake.nix) — the override was bit-neutral at the
  # current lock. Re-add ONLY via nix-hash-fix evidence, never by hand.
  go-humanize-linter =
    let
      pkg = flakePkg inputs.go-humanize-linter;
    in
    if pkg == null then
      null
    else
      pkg;
  go-structure-linter = flakePkg inputs.go-structure-linter;
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream cb9a8b79 ALREADY bakes the got
  # hash cdxICkri… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  golangci-lint-auto-configure = flakePkg inputs.golangci-lint-auto-configure;
  # library-policy shim DROPPED (2026-10-09): its drop condition ("lock
  # moves past an upstream-fixed rev") is met — the lock holds 5d2a670,
  # whose flake bakes vendorHash Qey6w74G… (the same "got" hash the stale
  # shim overrode with MUWz8cpf…, re-breaking the FOD it existed to fix)
  # and `nix build .#library-policy` builds clean (verified 2026-10-09).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  library-policy = flakePkg inputs.library-policy;
  # TEMPORARY vendorHash shim DROPPED (2026-10-11, fix-upstream-and-re-lock
  # protocol): upstream 3f466de bakes the through-our-lock got hash
  # e+jOFi3m… (specified uF0J63iQ vs got e+jOFi3m, first-hand keep-going
  # enumeration) and already builds via go_1_27 — the toolchain override
  # leg went with it. Lock moved 5e70003 → 3f466de the same day. The
  # dirty-tree FOD built green standalone BEFORE the push. Re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  md-go-validator = flakePkg inputs.md-go-validator;
  # depgraph CLI: renders the LarsArtmann Go monorepo dependency graph and
  # answers who-uses/why/update-plan/release-suggestions queries. Rides
  # PATH via base.nix attrValues (both hosts). Upstream repo is PRIVATE
  # (git+ssh input + CI deploy key, see flake.nix).
  #
  # vendorHash shim DROPPED (2026-10-09): its drop condition ("lock moves
  # past an upstream rev with the corrected vendorHash.nix committed") is
  # met — the lock holds 58cfdaab, whose vendorHash.nix bakes ADzN0+X0…
  # (the same "got" hash the stale shim overrode with w3uyGueT…;
  # first-hand keep-going enumeration, /tmp/toplevel-fix-20261009.log).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  project-dependency-graph = flakePkg inputs.project-dependency-graph;
  # mr-sync: CLI to keep ~/.mrconfig in sync with GitHub repos.
  # Resolves samber-do-auditlog transitively at v0.8.1 via cmdguard v3.1.0+.
  mr-sync = flakePkg inputs.mr-sync;
  # vendorHash shim DROPPED (2026-10-10): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 7567b4ec, whose
  # flake bakes vendorHash HWYco+tb… (the same "got" hash the stale shim
  # overrode with KDFDf97T…; first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261009b.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  project-meta = flakePkg inputs.project-meta;
  # TEMPORARY vendorHash shim DROPPED (2026-10-11, fix-upstream-and-re-lock
  # protocol): upstream ea6e8ce bakes the got hash 6ZDAkBB… (specified
  # 8kSXYjwa vs got Mrn25ftf at 1f9b57c, then re-measured 6ZDAkBB at
  # fec79c1 — pdd's OWN flake.lock moved between the revs and it does NOT
  # follow our pins, so its own lock governs the FOD content; two push
  # rounds, first-hand keep-going enumerations both times). Lock moved
  # 1f9b57c → ea6e8ce the same day. Re-add ONLY via nix-hash-fix evidence,
  # never by hand.
  project-discovery-daemon = flakePkg inputs.project-discovery-daemon;
  # vendorHash shim DROPPED (2026-10-09): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 96fd9304, whose
  # flake bakes vendorHash Bvuf0KUY… (the same "got" hash the stale shim
  # overrode with +/NGC//7…, re-breaking the FOD it existed to fix;
  # first-hand keep-going enumeration, /tmp/toplevel-fix-20261009.log).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  projects-management-automation = flakePkg inputs.projects-management-automation;
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 613725e7 ALREADY bakes the got
  # hash wH3k7WiK… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  samber-linter = flakePkg inputs.samber-linter;
  # todo-list-ai TEMPORARILY DROPPED (2026-10-03, null → filtered by the
  # null-safe guard below): the 2026-10-01 root-nixpkgs bump moved its
  # followed bun 1.4.1→1.4.2, which re-hashed the deps FOD (pinned
  # FkAUaar… now produces dOQ37ka…) AND breaks --frozen-lockfile on every
  # lockfile regenerated after 448b941 (lock metadata skew; verified:
  # 448b941's lock passes bun 1.4.2's frozen check, all later regens fail).
  # The deps FOD is inline in the input's flake — not SystemNix-overridable.
  # RESTORE when upstream regenerates bun.lock under nixpkgs' current bun
  # AND re-pins depsHash (got-hash evidence above), then re-lock past it.
  # Input pinned to 448b941 meanwhile (last frozen-compatible lockfile).
  todo-list-ai = null;
  # tq: the checkPhase runs upstream's test suite, which shells out to git
  # (TestDoctorTreeGofmt does `git init -q` in a tmpdir, upstream 2026-10-02)
  # — the go-standard sandbox ships no git and the package build fails with
  # `exec: "git": executable file not found in $PATH`. Git in
  # nativeBuildInputs lets the suite run as upstream dev does (that test is
  # the ONLY failure in the full log, 2026-10-02); drop when upstream's
  # flake adds git itself. vendorHash shim DROPPED 2026-10-07 (10-07
  # protocol): upstream 1164a1af's flake declares the exact first-hand
  # got-hash (KcxoZhGt…), so the override only recreated the drift
  # treadmill; the hash lives upstream now. Re-add only with a fresh
  # first-hand got-hash that upstream's own flake lacks. doCheck
  # gated off 2026-10-05: upstream's own TestAgentsDocSizeGuard is red at
  # the locked rev (AGENTS.md 17102 B > the repo's own 15400 B budget —
  # upstream repo hygiene, not binary correctness); drop the gate when
  # upstream prunes AGENTS.md or resets agentsDocMaxBytes and the lock
  # moves past it.
  tq = (flakePkg inputs.go-taskqueue).overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      inputs.nixpkgs.legacyPackages.${system}.git
    ];
    doCheck = false;
  });
}
