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
  # flakePkgShim: consumer-side vendorHash shim (attrset overrideAttrs form
  # — .override does NOT exist on upstream-flake packages). 2026-10-15
  # fleet wave: the overnight master-tracking lock float re-staled ~22
  # go-modules FODs with root nixpkgs STATIC (source churn, not toolchain
  # drift). Every value below is a first-hand fakeHash FOD probe at the
  # locked rev (/tmp/got-probe-20261015.log; cross-checked against the
  # user's 02:46 nh enumeration). Drop per-tool when upstream bakes the
  # got hash or the lock moves past an upstream-fixed rev; re-add ONLY
  # via nix-hash-fix evidence, never by hand.
  flakePkgShim =
    input: attr: hash:
    let
      pkg = (input.packages.${system} or { }).${attr} or null;
    in
    if pkg == null then null else pkg.overrideAttrs { vendorHash = hash; };
in
lib.filterAttrs (_: v: v != null) {
  # art-dupl source-rename shim (2026-10-17): the locked fork rev f8724119
  # commits a HAND-WRITTEN printer/actionability/actionability_templ.go
  # (defines isTemplChildrenIdiom), but upstream's preBuild runs bare
  # `templ generate`, which claims the *_templ.go name as its generated-output
  # namespace — the clean build then fails `undefined: isTemplChildrenIdiom`
  # (first-hand: evo-x2 toplevel --keep-going 2026-10-17 05:41, drv
  # cvzvrblb…; the file IS tracked at f8724119 via 4095c7bf). The rename
  # moves it out of templ's namespace; semantics identical. DROP when
  # upstream renames the file and pushes (re-lock past that rev).
  # art-dupl rename shim DROPPED (2026-10-17): its condition ("upstream
  # renames the file and pushes") is met — fork tip 41980118 renames the
  # hand-written actionability_templ.go → actionability_templ_idioms.go
  # (out of bare `templ generate`'s output namespace; pushed this session).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  art-dupl = flakePkg inputs.art-dupl;
  # vendorHash shim DROPPED (2026-10-07 wave — the 13:14/14:59 lock commits
  # moved the input; drop-protocol, docs/agents/nix-flakes.md): upstream
  # 60a91081 ALREADY bakes the got hash A8ZHASMR… (first-hand: evo-x2
  # toplevel --keep-going enumeration, /tmp/toplevel-fix-20261007.log), so
  # the override only re-created the drift treadmill. Re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  branching-flow =
    flakePkgShim inputs.branching-flow "default"
      # fleet-wave 2026-10-15 (see flakePkgShim class comment)
      "sha256-0IxhvfLipHbgCDkOOt4gzot/y8vdYl2KZyMwaHWKE+w=";
  # brandid-lint CLI from the go-branded-id repo's flake (packages.default);
  # master-tracked per the 2026-10-11 owner decision. CV's change-gate
  # brandid leg consumes this via PATH instead of a hand-built binary.
  # (Input is named brandid-lint, not go-branded-id: that name is taken
  # by an older non-flake source pin in flake.nix.)
  brandid-lint = flakePkg inputs.brandid-lint;
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
  # buildflow shim DROPPED (2026-10-17 wave): upstream root vendorHash.nix
  # at tip ef32fa02 bakes the shim's own 5OQbyOHy… value — the override was
  # bit-neutral; re-lock moves the input defa7c0-era → ef32fa02 and the
  # probe build arbitrates (go.mod differs at tip → hash may re-stale;
  # if so, `nix run .#update-vendor-hash` upstream is the blessed path).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
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
  # cqrs-lint vendorHash shim DROPPED (2026-10-12): the lock moved
  # f12a849b → d15e0a48 — the "re-evaluate on the next lock move" trigger
  # the 2026-10-11 re-pin note named — and upstream d15e0a48 bakes a GREEN
  # through-our-lock hash (first-hand probe: inputs.go-cqrs-lite.packages.
  # x86_64-linux.cqrs-lint.goModules built clean, store wzc06wa9…; the
  # shim's 7wijvzQm… value was measured at f12a849b and hash-mismatched at
  # d15e0a48 in the 2026-10-12 toplevel keep-going enumeration). The
  # queued paste-upstream → push cycle is thereby closed upstream-side:
  # no go-cqrs-lite edit was needed. Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  cqrs-lint =
    let
      pkg = (inputs.go-cqrs-lite.packages.${system} or { }).cqrs-lint or null;
    in
    # vendorHash shim DROPPED (2026-10-17): the lock re-locks past 60f2be41
    # to tip 7fe2e0ad, whose upstream flake bakes 9y6O/R2f… — the shim's
    # J7gNXzrV… (measured at 60f2be41) does not govern the new rev; the
    # probe build arbitrates. go.mod differs tip-vs-measured → if upstream's
    # value goes stale under the followed graph, paste the fresh got
    # upstream and push (non-follower class). Re-add ONLY via nix-hash-fix
    # evidence, never by hand.
    if pkg == null then null else pkg;
  # TEMPORARY vendorHash shim RE-PINNED (2026-10-14): the master-tracking
  # flip (flake.nix, owner directive) landed erraudit on 492c233, whose
  # specified hash /D4X81jj… no longer reproduces under the followed
  # nixpkgs graph (follower class — upstream can never converge). Got
  # LzoxcvFT… from a first-hand `nix build .#erraudit` FOD probe at the
  # locked rev. Drop when upstream bakes the got hash or the lock moves
  # past an upstream-fixed rev; re-add ONLY via nix-hash-fix evidence,
  # never by hand.
  erraudit =
    let
      pkg = flakePkg inputs.erraudit;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        # fleet-wave re-pin (lock float bb57433 → 100ce1c): sKya91ES… lived
        # one wave; got ICUaudG… from the 2026-10-16 toplevel enumeration
        # at the locked rev (see flakePkgShim class comment)
        vendorHash = "sha256-ICUaudG+K7ZayDgCN/91zXG7ZIEyWSUfkHjgN6HCL6A=";
      };
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 74baca53 ALREADY bakes the got
  # hash G0hMfZId… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  go-auto-upgrade =
    flakePkgShim inputs.go-auto-upgrade "default"
      # fleet-wave 2026-10-15 (see flakePkgShim class comment)
      "sha256-D5DnebMFnB4B455Sjm1hlPM8+IeshshLAhkys0F3cZg=";
  # TEMPORARY vendorHash shim DROPPED (2026-10-11): the lock moved
  # 4cee06df → 7f9b7b19, whose flake bakes the shim's OWN JrBhDyCx… value
  # (git show 7f9b7b19:flake.nix) — the override was bit-neutral at the
  # current lock. Re-add ONLY via nix-hash-fix evidence, never by hand.
  # go-humanize-linter shim DROPPED (2026-10-17 wave): upstream flake.nix:52
  # at tip/main f8845aeb bakes the shim's own /2zA0kMS… value — bit-neutral
  # override (go.sum/go.mod verified identical tip-vs-measured). Re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  go-humanize-linter = flakePkg inputs.go-humanize-linter;
  go-structure-linter =
    flakePkgShim inputs.go-structure-linter "default"
      # fleet-wave 2026-10-15 (see flakePkgShim class comment)
      "sha256-O2hpYHScgY0UlxTg94dVJ9wuWSJEnz0ourXRRFoIV3Q=";
  # TEMPORARY vendorHash shim RE-PINNED (2026-10-14): the master-tracking
  # flip (flake.nix, owner directive) landed golangci-lint-auto-configure
  # on 81446302, whose vendorHash.nix still pins zg+6ICkRu2… — 69 commits
  # of source churn since the ddb54527 pin without a hash refresh. Got
  # EgfteIUmqz… from a first-hand `nix build .#golangci-lint-auto-configure`
  # FOD probe at the locked rev. Drop when upstream bakes the got hash or
  # the lock moves past an upstream-fixed rev; re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  # golangci-lint-auto-configure shim DROPPED (2026-10-17 wave): the lock
  # already sits at tip 431eea03 and upstream vendorHash.nix bakes the
  # shim's own IGt6Neha… value ("Managed by buildflow nix-checker") —
  # bit-neutral override. Re-add ONLY via nix-hash-fix evidence, never by
  # hand.
  golangci-lint-auto-configure = flakePkg inputs.golangci-lint-auto-configure;
  # library-policy shim DROPPED (2026-10-09): its drop condition ("lock
  # moves past an upstream-fixed rev") is met — the lock holds 5d2a670,
  # whose flake bakes vendorHash Qey6w74G… (the same "got" hash the stale
  # shim overrode with MUWz8cpf…, re-breaking the FOD it existed to fix)
  # and `nix build .#library-policy` builds clean (verified 2026-10-09).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  # library-policy shim DROPPED (2026-10-17 wave): upstream flake.nix:110
  # at tip aab411b9 bakes the shim's own SIbgnu0y… value — bit-neutral
  # override (lock == tip). Re-add ONLY via nix-hash-fix evidence, never
  # by hand.
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
  project-dependency-graph =
    flakePkgShim inputs.project-dependency-graph "default"
      # fleet-wave 2026-10-15 (see flakePkgShim class comment)
      "sha256-lSE3snyu9xFnSekT4pBX23qaKeI22GI+R8rQzEFC3Bw=";
  # mr-sync: CLI to keep ~/.mrconfig in sync with GitHub repos.
  # Resolves samber-do-auditlog transitively at v0.8.1 via cmdguard v3.1.0+.
  mr-sync = flakePkg inputs.mr-sync;
  # mr-sync shim DROPPED (2026-10-17 wave): upstream flake.nix:126 at tip
  # 71d6b0d4 bakes the shim's own KaDlWefE… value — bit-neutral override
  # (lock == tip; module surface dropped in the same pass). Re-add ONLY
  # via nix-hash-fix evidence, never by hand.
  # vendorHash shim DROPPED (2026-10-10): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 7567b4ec, whose
  # flake bakes vendorHash HWYco+tb… (the same "got" hash the stale shim
  # overrode with KDFDf97T…; first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261009b.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # project-meta shim DROPPED (2026-10-17 wave): upstream flake.nix:69 at
  # tip d905380c bakes the shim's own paiQbA3x… value — bit-neutral
  # override (lock == tip). Re-add ONLY via nix-hash-fix evidence, never
  # by hand.
  project-meta = flakePkg inputs.project-meta;
  # TEMPORARY vendorHash shim DROPPED (2026-10-11, fix-upstream-and-re-lock
  # protocol): upstream ea6e8ce bakes the got hash 6ZDAkBB… (specified
  # 8kSXYjwa vs got Mrn25ftf at 1f9b57c, then re-measured 6ZDAkBB at
  # fec79c1 — pdd's OWN flake.lock moved between the revs and it does NOT
  # follow our pins, so its own lock governs the FOD content; two push
  # rounds, first-hand keep-going enumerations both times). Lock moved
  # 1f9b57c → ea6e8ce the same day. Re-add ONLY via nix-hash-fix evidence,
  # never by hand.
  project-discovery-daemon =
    flakePkgShim inputs.project-discovery-daemon "default"
      # fleet-wave 2026-10-15 (see flakePkgShim class comment; the module
      # default in project-discovery-daemon.nix carries the same value)
      "sha256-nNKXDH5NoVlkjJMQbYICImrthGVxMvZybQgf5QcJBkY=";
  # vendorHash shim DROPPED (2026-10-09): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 96fd9304, whose
  # flake bakes vendorHash Bvuf0KUY… (the same "got" hash the stale shim
  # overrode with +/NGC//7…, re-breaking the FOD it existed to fix;
  # first-hand keep-going enumeration, /tmp/toplevel-fix-20261009.log).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  # projects-management-automation shim DROPPED (2026-10-17 wave): upstream
  # flake.nix:111 at tip 849573de bakes the shim's own 5WOy3BHv… value —
  # bit-neutral override (lock == tip; service surface dropped in the same
  # pass). Re-add ONLY via nix-hash-fix evidence, never by hand.
  projects-management-automation = flakePkg inputs.projects-management-automation;
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 613725e7 ALREADY bakes the got
  # hash wH3k7WiK… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  samber-linter =
    flakePkgShim inputs.samber-linter "default"
      # fleet-wave 2026-10-15 (see flakePkgShim class comment)
      "sha256-79YZ0u7C+7oFhZS4YTMJzi3qroanbYTYbOkA2oDiKqY=";
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
    # vendorHash re-pin DROPPED (2026-10-17): upstream tip 4b3d1fc3 bakes
    # the shim's own rYQJIQB… value (flake.nix:49); go.sum verified
    # identical tip-vs-lock. Re-add only with a fresh first-hand got-hash
    # that upstream's own flake lacks.
  });
}
