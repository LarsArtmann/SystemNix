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
  # branching-flow shim DROPPED (2026-10-18): the input re-locked to tip
  # f129ca8a and the probe build arbitrates against upstream's own tip
  # hashes (fFMTnbQ6…/hGfwb0GZ… — two buildGoModule packages); neither
  # matched the shim's 0IxhvfLi… so the override was NOT bit-neutral —
  # this drop is EVIDENCE-BASED only if the build stays green; re-add via
  # nix-hash-fix evidence, never by hand.
  # TEMPORARY vendorHash shims (2026-10-19 wave — first-hand keep-going
  # toplevel enumeration, /tmp/toplevel-build-20261019.log; class comment
  # at flakePkgShim above): the overnight master-tracking lock float
  # re-staled the locked revs' baked hashes under the followed nixpkgs
  # graph. Drop per-tool when upstream bakes the got hash or the lock
  # moves past an upstream-fixed rev; re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # branching-flow shim RE-ADDED (2026-10-19): upstream flake at the locked
  # rev carries a raw fakeHash placeholder (specified sha256-AAAA…), so the
  # probe was mandatory; got r/LYNVd+….
  branching-flow =
    flakePkgShim inputs.branching-flow "default"
      "sha256-r/LYNVd+eGLWyVEpTQxk53Lkzo06kq8nixpHi0fkndc=";
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
  buildflow =
    flakePkgShim inputs.buildflow "default"
      "sha256-9y4NBzy3H8EYw5+TMnNIJYma5hCFrF4TlK3qWNRNXHg=";
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
  # cqrs-lint vendorHash shim RE-ADDED (2026-10-23, first-hand FOD evidence):
  # the nixpkgs rollback fe13242 → (away from 02c087f3) re-tooled the
  # go-modules builder graph, so upstream's baked J7gNXzrV… at the locked rev
  # a7a033c no longer reproduces. Probe: `cqrs-lint-a7a033c…-go-modules` in
  # the evo-x2 toplevel --keep-going enumeration, specified
  # sha256-J7gNXzrVQ4cPdAXBHTjwu7mvvHZskDsFYIURJuoBIEM= vs got
  # sha256-EQe80wmzlsTM1PjjLKcsOPW/oEXJG4mV3dsJhR9+ZOE= (narHash matched →
  # toolchain drift, not source drift). This was the SOLE root failure of the
  # whole enumeration; everything else cascaded from it. DROP when upstream
  # bakes the got hash or the lock moves past an upstream-fixed rev; re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  cqrs-lint = flakePkgShim inputs.go-cqrs-lite "cqrs-lint" "sha256-EQe80wmzlsTM1PjjLKcsOPW/oEXJG4mV3dsJhR9+ZOE=";
  # TEMPORARY vendorHash shim RE-PINNED (2026-10-14): the master-tracking
  # flip (flake.nix, owner directive) landed erraudit on 492c233, whose
  # specified hash /D4X81jj… no longer reproduces under the followed
  # nixpkgs graph (follower class — upstream can never converge). Got
  # LzoxcvFT… from a first-hand `nix build .#erraudit` FOD probe at the
  # locked rev. Drop when upstream bakes the got hash or the lock moves
  # past an upstream-fixed rev; re-add ONLY via nix-hash-fix evidence,
  # never by hand.
  # erraudit shim DROPPED (2026-10-18, owner-directed root-bump path): the
  # follower divergence TRANSIENTLY closed — erraudit's own lock nixpkgs
  # (channel-tracking nixos-unstable) has drifted onto 55bfb4d, the same
  # root SystemNix pins, so tip 0cc8ee2c's baked hash rIf6DO2D… governs
  # under our graph too. The input re-locks to tip in the same pass and
  # the probe build arbitrates. FRAGILE: when nixos-unstable moves past
  # our root again, the shim class re-fires (ledger row owns the watch).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  erraudit = flakePkg inputs.erraudit;
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 74baca53 ALREADY bakes the got
  # hash G0hMfZId… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # go-auto-upgrade shim DROPPED (2026-10-18): upstream flake.nix at tip
  # 88ccfef0 bakes the shim's own D5DnebMF… value — bit-neutral override
  # (graph verified identical tip-vs-lock). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  go-auto-upgrade = flakePkg inputs.go-auto-upgrade;
  # TEMPORARY vendorHash shim DROPPED (2026-10-11): the lock moved
  # 4cee06df → 7f9b7b19, whose flake bakes the shim's OWN JrBhDyCx… value
  # (git show 7f9b7b19:flake.nix) — the override was bit-neutral at the
  # current lock. Re-add ONLY via nix-hash-fix evidence, never by hand.
  # go-humanize-linter shim DROPPED (2026-10-17 wave): upstream flake.nix:52
  # at tip/main f8845aeb bakes the shim's own /2zA0kMS… value — bit-neutral
  # override (go.sum/go.mod verified identical tip-vs-measured). Re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  go-humanize-linter = flakePkg inputs.go-humanize-linter;
  # go-structure-linter shim DROPPED (2026-10-18): upstream vendorHash.nix
  # at tip 25b9f6a7 bakes the shim's own O2hpYHSc… value — bit-neutral
  # override (graph verified identical tip-vs-lock). Re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  go-structure-linter =
    flakePkgShim inputs.go-structure-linter "default"
      "sha256-cYR8eZnXCST90Pc2xGA0uO4tspIrkGIG2cVKPeyRRAw=";
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
  golangci-lint-auto-configure =
    flakePkgShim inputs.golangci-lint-auto-configure "default"
      "sha256-0VvVtsy3kjSoqtplM9p6SwR+OMRwVwKqOa5DI9NeCnE=";
  # journal — the accounting kernel CLI (chart, double-entry journal,
  # reconciliation, VAT). Pure interactive tool: no daemon, no port, no
  # service module. Upstream repo is PRIVATE (github: input + CI deploy
  # key, see flake.nix). Non-follower class: builds under its own lock —
  # probe-verified 2026-10-19 (ba60fe0d, no shim needed). Rides PATH via
  # base.nix attrValues (both hosts) + the quick-go §11 pre-deploy batch.
  journal = flakePkg inputs.journal;
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
  # library-policy shim RE-ADDED (2026-10-23 lock float): the 15:17 float
  # moved the input past the tip whose baked hash matched our locked rev;
  # first-hand keep-going probe got sha256-7EyJHHnw83kphWvvpSNgo7hoRhtNdMpdc9Sb3LkrMdo
  # (specified JKl9E1Rg, got 7EyJHHnw). Drop when upstream bakes this value.
  library-policy =
    flakePkgShim inputs.library-policy "default"
      "sha256-7EyJHHnw83kphWvvpSNgo7hoRhtNdMpdc9Sb3LkrMdo=";
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
  # project-dependency-graph shim DROPPED (2026-10-18): upstream
  # vendorHash.nix at tip f341c715 bakes the shim's own lSE3snyu… value —
  # bit-neutral override (graph verified identical tip-vs-lock). Re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  project-dependency-graph =
    flakePkgShim inputs.project-dependency-graph "default"
      "sha256-ZuiValdTRHYZZJ6OSXPSrrFIg9k+eyk4JxvQ/McTHdY=";
  # mr-sync: CLI to keep ~/.mrconfig in sync with GitHub repos.
  # Resolves samber-do-auditlog transitively at v0.8.1 via cmdguard v3.1.0+.
  mr-sync =
    flakePkgShim inputs.mr-sync "default"
      "sha256-yB73mr06xZTAzAx5M1qyBmM75umJ7baOuPo+RcokFOg=";
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
  # project-discovery-daemon shim DROPPED (2026-10-18): upstream flake.nix
  # at tip 3e4b57f6 bakes the shim's own nNKXDH5N… value — bit-neutral
  # override (graph verified identical tip-vs-lock; value identity makes
  # provenance moot even though pdd does not follow our pins). Re-add ONLY
  # via nix-hash-fix evidence, never by hand.
  project-discovery-daemon =
    flakePkgShim inputs.project-discovery-daemon "default"
      "sha256-jLpz/NzHqndZbeHYX/afHaXif/u/70iBuqkGPtPy0oo=";
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
  # projects-management-automation shim RE-ADDED (2026-10-23 lock float):
  # first-hand keep-going probe got sha256-NBQcjrwDfb5Eqeic7hpAN/1M4FI5XAA4YldmKXXpnt0
  # (specified U9F6gATv, got NBQcjrwD). Drop when upstream bakes this value.
  projects-management-automation =
    flakePkgShim inputs.projects-management-automation "default"
      "sha256-NBQcjrwDfb5Eqeic7hpAN/1M4FI5XAA4YldmKXXpnt0=";
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 613725e7 ALREADY bakes the got
  # hash wH3k7WiK… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # samber-linter shim DROPPED (2026-10-18): upstream flake.nix at tip
  # 231a91b4 bakes the shim's own 79YZ0u7C… value — bit-neutral override
  # (graph verified identical tip-vs-lock). Re-add ONLY via nix-hash-fix
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
    # vendorHash re-pin DROPPED (2026-10-17): upstream tip 4b3d1fc3 bakes
    # the shim's own rYQJIQB… value (flake.nix:49); go.sum verified
    # identical tip-vs-lock. Re-add only with a fresh first-hand got-hash
    # that upstream's own flake lacks.
  });
}
