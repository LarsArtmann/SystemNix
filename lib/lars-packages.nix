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
  # RE-STALE 2026-11-06 lock float (no shim until now): the locked art-dupl
  # rev's baked hash no longer reproduces under the refreshed graph — the
  # build died "reading …/xo/terminfo/@v/v1.3.0.zip: no such file" because
  # the stale fixed-output path is keyed by the SPECIFIED hash (class
  # comment at flakePkgShim). Fresh fakeHash probe got iCINPEzo (first-hand,
  # drv g4i7z32v1rqr60qwsk13ii54c6zk6vjz-art-dupl-0.9.0-go-modules).
  art-dupl =
    flakePkgShim inputs.art-dupl "default"
      "sha256-AFkwR+czRL1litT7pMz0L1ZeUYfq/H23tACxWzgFn8I=";
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
  # RE-STALE 2026-10-27 lock float: branching-flow@f28419e still ships the
  # AAAA placeholder upstream; got iS5Z/XOU (first-hand keep-going proof,
  # ~/.cache/lockfloat/float-proof-20261027-172949.log).
  branching-flow =
    flakePkgShim inputs.branching-flow "default"
      "sha256-bCLzzRm6UMyitLSIWfIXmKd68gub+H3NR7lRbqyj43A=";
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
  # RE-STALE 2026-10-26 lock float: at 24dff818 spec 9y4NBzy3, got ffjf0h53
  # (first-hand keep-going, ~/.cache/lockfloat/float-proof-20261026-161006.log).
  # buildflow shim DROPPED (2026-10-28 blanket float — drop-protocol): the
  # locked rev ce10b79's OWN vendorHash.nix carries the got hash
  # "sha256-9SVsy6pMlBypghZHR0Otf1jtcgpZ9NsK463jRfn9zWA=", the exact value
  # our 2026-10-28 proof mismatched into
  # (~/.cache/lockfloat/float-proof-20261028-214409.log), so the override
  # only re-created the drift treadmill. Both surfaces dropped (this one +
  # platforms/nixos/system/configuration.nix). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # SHIM DROPPED AGAIN 2026-11-06 (drop-protocol): the SRdpoBO+ value added
  # earlier this session was MISATTRIBUTED — it was probed at a1d0c14 (drv
  # 96c9wjgjp4qkzy1pyii42izy9hl5y40m-buildflow-a1d0c14-go-modules) but pasted
  # onto the lock after it had already moved to ba3cd98. First-hand re-probe at
  # ba3cd98 (nix-store --realise of 23qjyl87…-buildflow-ba3cd98-go-modules.drv)
  # reported specified SRdpoBO+, got
  # sha256-7F+fM3mxTCysNBZJtoBILx48X1uFLovD762UAISwtJU= — which is EXACTLY what
  # upstream's own vendorHash.nix bakes at this rev (the raw
  # inputs.buildflow.packages.default derivation f1rndifs… declares the same
  # 7F+fM3). The override was therefore drift-treadmill only AND it created a
  # SECOND buildflow derivation in the closure (raw 7F+fM3 vs shim SRdpoBO+),
  # doubling the go-modules FOD build on every deploy.
  # Re-add ONLY via nix-hash-fix evidence taken at the SAME rev you apply it to.
  buildflow = flakePkg inputs.buildflow;
  # cvagent — git-history→CV-facts CLI (Code-To-CV-Agent): scan/mesh commands,
  # PATH consumer + the cvagent.nix scan+mesh timer. Upstream flakes
  # packages.default with its own baked vendorHash (no follows into it).
  cvagent = flakePkg inputs.cvagent;
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
  # RE-STALE 2026-11-05 float wave: at go-cqrs-lite@5dc057a spec EQe80wmz,
  # got xA/2yJ6o (float-proof-20261106-000533.log).
  # RE-STALE 2026-11-06 (same night, sibling re-float to 0b7aee4): spec
  # xA/2yJ6o, got 6mUToa7K (float-proof-20261106-010252.log).
  # shim RE-ADDED (2026-11-06, lock at 0b7aee4 — the state every proof
  # 2026-11-06 01:29+ actually evaluated through an external oscillation
  # d15e0a48↔0b7aee4): upstream bakes 5RcdyWcX there vs measured truth
  # 6mUToa7K (float-proof-20261106-010252 + -012906 + -014324 logs,
  # three independent FOD measurements). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # RE-STALE 2026-11-06 evening (lock now at 254e4839): spec 6mUToa7K, got
  # jxGg7Xa (first-hand, float-proof-20261106-225127.log — the crm
  # pin-wave proof enumerated it).
  # RE-STALE 2026-11-12 (lock at d17d29d8 after the 2026-11-11 float plus
  # today's tip re-float): spec jxGg7XaL, got 144yHjI2, first-hand from the
  # deploy6 keep-going enumeration (drv cqrs-lint-d17d29d8…-go-modules,
  # rev-matched). Two lock moves since the last paste.
  cqrs-lint =
    flakePkgShim inputs.go-cqrs-lite "cqrs-lint"
      "sha256-144yHjI2pE6zybH4rTNhOBTUG1iHKh9/ag9j6dYCvUU=";
  # docs-gates — the docs-health battery gates (freshness / annotate /
  # routing / cadence / strike) as one stdlib-only multi-call binary;
  # packages.default = the binary + the five legacy-name wrappers
  # (docs-freshness … docs-strike) that exec it, so PATH install covers
  # both the new verb surface and the pre-extraction fleet scripts.
  # Extracted from the pbx-artmann fleet 2026-11-03. NO shim ever:
  # upstream vendorHash = null by the stdlib-only contract — no FOD, no
  # toolchain-skew re-hash waves (the flake.nix nixpkgs follow is thereby
  # unconditionally safe).
  docs-gates = flakePkg inputs.docs-gates;
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
  # vendorHash shim RE-ADDED (2026-10-26 lock float — the 2026-10-18 FRAGILE
  # note fired: erraudit's own lock re-locked its nixpkgs past our root pin
  # again, so upstream's baked V22CgR4i… at 61a744ce staled under the
  # follower divergence; got EiJnFbX3… from the keep-going enumeration,
  # ~/.cache/lockfloat/float-proof-20261026-161006.log). Drop when upstream
  # bakes the got hash; re-add ONLY via nix-hash-fix evidence, never by hand.
  # RE-STALE (2026-10-28 toplevel keep-going, deploy-fix session):
  # erraudit@6fe130d spec EiJnFbX3…, got /Va1XfKr… (first-hand,
  # ~/.cache/lockfloat/toplevel-keepgoing-20261028-1655.log). Drop when
  # upstream bakes /Va1XfKr…; re-add ONLY via nix-hash-fix evidence.
  # RE-STALE 2026-11-05 float wave: at erraudit@3d1f7ed spec /Va1XfKr,
  # got skC3yysE (float-proof-20261106-000533.log).
  # DROPPED 2026-11-12 (treadmill drop-protocol): the daemon float to
  # d577858a re-staled xoynVQs (got prAXFWSn, toplevel-proof-
  # 20261112-drop.log), and upstream d577858a ALREADY BAKES exactly
  # prAXFWSn — got==bake, so the plain package reproduces under our
  # graph. Re-add ONLY via nix-hash-fix evidence, never by hand.
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
  # vendorHash shim RE-ADDED (2026-10-26 lock float, first-hand keep-going,
  # float-proof-20261026-161006.log): upstream's baked CqQx0A5w… at 3d6eded2
  # staled (own-lock re-lock class); got pUk8kT+7…. Drop when upstream bakes
  # the got hash; re-add ONLY via nix-hash-fix evidence, never by hand.
  # RE-STALE 2026-11-05 float wave: at go-auto-upgrade@e7f0307 spec
  # pUk8kT+7, got qfknf/Oa (float-proof-20261106-000533.log).
  # RE-STALE 2026-11-12 cache-eviction re-enumeration: at go-auto-upgrade
  # @dd5816c8 spec z0Na65DP, got gPZpkw4v (cqrs-shim-toplevel-proof.log;
  # cache-hit-green FODs re-exposed stale after store eviction). Drop when
  # upstream bakes the got hash.
  go-auto-upgrade =
    flakePkgShim inputs.go-auto-upgrade "default"
      "sha256-gPZpkw4vcIYKmRKsCirDOag9sBIsrvrRtZ6tSyiV+bk=";
  # TEMPORARY vendorHash shim DROPPED (2026-10-11): the lock moved
  # 4cee06df → 7f9b7b19, whose flake bakes the shim's OWN JrBhDyCx… value
  # (git show 7f9b7b19:flake.nix) — the override was bit-neutral at the
  # current lock. Re-add ONLY via nix-hash-fix evidence, never by hand.
  # go-humanize-linter shim DROPPED (2026-10-17 wave): upstream flake.nix:52
  # at tip/main f8845aeb bakes the shim's own /2zA0kMS… value — bit-neutral
  # override (go.sum/go.mod verified identical tip-vs-measured). Re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  # vendorHash shim RE-ADDED (2026-10-26 lock float, first-hand keep-going,
  # float-proof-20261026-161006.log): upstream's baked jh6zkdx… at ec19200c
  # staled; got k7GyCaMU…. Drop when upstream bakes the got hash; re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  # RE-STALE 2026-11-02 04:12 lock float (9ff1d1645+3709f06b0): at
  # go-humanize-linter@8ac99125 spec k7GyCaMU, got v6zJv2bV (first-hand
  # keep-going, ~/.cache/lockfloat/float-proof-20261102-043225-lars.log).
  # shim DROPPED (2026-11-10 lock float, first-hand evidence): upstream
  # flake.nix:52 at the locked rev 6f794637 now bakes exactly the got
  # hash (2tOFS9U1…, from the same failing FOD) — the plain package
  # reproduces; re-add ONLY via nix-hash-fix evidence, never by hand.
  go-humanize-linter = flakePkg inputs.go-humanize-linter;
  # go-structure-linter shim DROPPED (2026-10-18): upstream vendorHash.nix
  # at tip 25b9f6a7 bakes the shim's own O2hpYHSc… value — bit-neutral
  # override (graph verified identical tip-vs-lock). Re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  # RE-STALE 2026-10-26 lock float: spec cYR8eZnX, got eGuBIRDB (first-hand
  # keep-going, ~/.cache/lockfloat/float-proof-20261026-161006.log).
  # RE-STALE 2026-11-05 float wave: at go-structure-linter@96c2250 spec
  # eGuBIRDB, got BH1gH3zn (float-proof-20261106-000533.log).
  go-structure-linter =
    flakePkgShim inputs.go-structure-linter "default"
      "sha256-d9FFjVKgemLqu2l1yW30fDAhX+NlDbTC5Thz6GphsHY=";
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
  # RE-STALE 2026-10-26 lock float: spec 0VvVtsy3, got 6rIzqRAD (first-hand
  # keep-going, ~/.cache/lockfloat/float-proof-20261026-161006.log).
  # RE-STALE 2026-11-02 04:12 lock float: at
  # golangci-lint-auto-configure@f4df57a6 spec 6rIzqRAD, got Uvi1KtDo
  # (first-hand, ~/.cache/lockfloat/float-proof-20261102-043225-lars.log).
  # RE-STALE 2026-11-02 15:28 lock float: at
  # golangci-lint-auto-configure@1d6b445e spec Uvi1KtDo, got DIO+MXPj
  # (first-hand keep-going, float-proof-20261102-152823.log).
  # RE-STALE 2026-11-05 float wave: at
  # golangci-lint-auto-configure@28340f6 spec DIO+MXPj, got u/j9KmmO
  # (float-proof-20261106-000533.log).
  # RE-STALE 2026-11-11 pin-lift wave: at 41e6ed1 spec u/j9KmmO,
  # got 617A34e5 (pin-lift toplevel keep-going proof).
  # RE-STALE 2026-11-12 daemon float: at d338a0d1 spec 617A34e5, got
  # tXX142O1 (toplevel-proof-20261112-drop.log). Upstream vendorHash.nix
  # at d338a0d1 is STILL stale (buildflow-managed, paste pushed this
  # session) — shim carries the got-hash until a re-lock carries the
  # bake, then drop. Re-add ONLY via nix-hash-fix evidence, never by hand.
  golangci-lint-auto-configure =
    flakePkgShim inputs.golangci-lint-auto-configure "default"
      "sha256-tXX142O1SZhTSIB5BTlZQXcql+0bi6Fuu8Dh9RemwI4=";
  # invoices — billing CLI + dashboard backend (`invoices dashboard`,
  # deployed as the invoices-dashboard unit since 2026-11-10: loopback
  # 127.0.0.1:8110 behind the protected registry vHost invoices.home.lan;
  # runbook docs/services/invoices-dashboard.md). NON-FOLLOWER input (own
  # nixpkgs lock, no follows): upstream-baked vendorHash probed green at the
  # locked rev 5c8c6b17 — no consumer shim, re-probe on float, never re-pin.
  invoices = flakePkg inputs.invoices;
  # io-surface: the I/O surface manifest gate CLI (init/check/render/lint;
  # fleet I/O-BOM gate, InboxClean pilot consumer). NON-FOLLOWER input (own
  # nixpkgs lock, no follows): upstream-baked vendorHash probed green at the
  # locked rev (nix build .#io-surface, 2026-11-11); no consumer shim,
  # re-probe on float, never re-pin.
  io-surface = flakePkg inputs.io-surface;
  # journal — the accounting kernel CLI (chart, double-entry journal,
  # reconciliation, VAT) + in-repo Hauptbuch web dashboard (`journal serve`
  # — deployed as the journal-serve unit since 2026-10-26: loopback
  # 127.0.0.1:8484 behind the protected registry vHost journal.home.lan,
  # owner g-2 answer; upstream keeps the loopback-only bind until T16
  # passkey auth — serve refuses non-loopback binds; runbook).
  # Upstream repo is PRIVATE (github: input + CI deploy key, see flake.nix).
  # Non-follower class: builds under its own lock — probe-verified
  # 2026-10-19 (ba60fe0d, no shim needed). Rides PATH via base.nix
  # attrValues (both hosts) + the quick-go §11 pre-deploy batch.
  # RE-STALE 2026-10-29 float: journal@50b4941 bakes R6w7rVD9… but its
  # module graph fetches OzU6YCvB… (first-hand,
  # ~/.cache/lockfloat/float-proof-20261029-180630.log). Mirrored in
  # journal-serve.nix + journal-backup.nix package defaults — edit ALL THREE. Drop when upstream
  # bakes the got hash; re-add ONLY via nix-hash-fix evidence.
  # RE-STALE 2026-11-02 04:12 lock float: at journal@3542a958 spec
  # OzU6YCvB, got 1JuET6kA (first-hand,
  # ~/.cache/lockfloat/float-proof-20261102-043225-lars.log). Mirrored in
  # journal-serve.nix + journal-backup.nix package defaults — edit ALL THREE.
  # RE-STALE 2026-11-05 float wave: at journal@4a63e7f spec 1JuET6kA,
  # got 65uOOb5j (float-proof-20261106-000533.log). Mirrored in
  # journal-serve.nix + journal-backup.nix package defaults — edit ALL THREE.
  # RE-STALE 2026-11-11 pin-lift wave: at 0663476 spec KW+poESP,
  # got OBIY8Nxi (pin-lift toplevel keep-going proof).
  # DROPPED 2026-11-12 (treadmill drop-protocol): the daemon float to
  # 0ed74483 re-staled OBIY8Nxi (got ANZD3eOm, toplevel-proof-
  # 20261112-drop.log), and upstream 0ed74483 ALREADY BAKES exactly
  # ANZD3eOm (got==bake). All THREE surfaces un-shimmed in the same
  # pass (lars-packages.nix + journal-serve.nix + journal-backup.nix).
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
  # RE-STALE 2026-10-26 lock float (second value in one day — the input
  # keeps moving): spec 7EyJHHnw, got OTLxExVE (first-hand keep-going,
  # ~/.cache/lockfloat/float-proof-20261026-161006.log).
  # RE-STALE 2026-10-28 blanket float: library-policy@f3651092 spec
  # OTLxExVE, got UtUhdbS9 (float-proof-20261028-214409.log).
  # 2026-11-02 04:12 float: the input was REV-PINNED back to f3651092
  # (upstream beb8d9ed vendors a go-health-dashboard whose InstanceID
  # struct change breaks the library-policy build — flake.nix pin comment)
  # and the value below is f3651092's build-proven hash.
  # 2026-11-03: the day's lift attempt re-probed to X4A26/0R at 0a276fc0,
  # but the PACKAGE then died at buildPhase on the vendored v0.12.1
  # status.go (two-graphs trap — local go build green, FOD build red).
  # Pin RESTORED to f3651092 until the owner pushes library-policy's bump
  # to the fixed go-health-dashboard v0.12.2 (committed locally); re-probe
  # this shim on the next lift.
  # UNPINNED 2026-11-03 evening: the v0.12.2 fix landed (a7aa44d) — shim
  # re-probed at the new rev: spec UtUhdbS9 (f3651092's value), got
  # zpasin+t (first-hand build probe, go-modules FOD at a7aa44dec).
  # zpasin+t never served a green build: the package then died at
  # buildPhase on the vendored dashboard status.go:309 (branded
  # health.InstanceID vs string — the two-graphs trap one level deeper:
  # go.mod bumps are cosmetic when the flake deps map replaces both
  # go-health and go-health-dashboard).
  # library-policy shim DROPPED (2026-11-03 night): upstream c1dc17a
  # floats its own inputs past the break (go-health d783d78,
  # go-health-dashboard d4a6534, which adopted the branded type
  # end-to-end) and bakes the through-our-lock vendorHash jKv5SH…
  # (detached-worktree FOD probe at a7aa44d + the floated lock, binary
  # produced). Re-add ONLY via nix-hash-fix evidence, never by hand.
  # NEW shim 2026-11-05 float wave: at library-policy@72ed2d4 spec
  # jKv5SHgJ, got mHS57Ha6 (float-proof-20261106-000533.log). Drop when
  # upstream bakes the got hash; re-add ONLY via nix-hash-fix evidence.
  # RE-STALE 2026-11-11 pin-lift wave: at 088aaf2 spec mHS57Ha6,
  # got xOKxcFQm (pin-lift toplevel keep-going proof).
  # DROPPED 2026-11-12 (treadmill drop-protocol, the 2026-10-09/17 drop
  # conditions met a third time): the daemon float to e7a084ce re-staled
  # xOKxcFQm (got nh/9sRXW, toplevel-proof-20261112-drop.log), and
  # upstream e7a084ce ALREADY BAKES exactly nh/9sRXW (got==bake).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  library-policy = flakePkg inputs.library-policy;
  # TEMPORARY vendorHash shim DROPPED (2026-10-11, fix-upstream-and-re-lock
  # protocol): upstream 3f466de bakes the through-our-lock got hash
  # e+jOFi3m… (specified uF0J63iQ vs got e+jOFi3m, first-hand keep-going
  # enumeration) and already builds via go_1_27 — the toolchain override
  # leg went with it. Lock moved 5e70003 → 3f466de the same day. The
  # dirty-tree FOD built green standalone BEFORE the push. Re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  # NEW shim 2026-11-05 float wave: at md-go-validator@13a0e78 spec
  # e+jOFi3m, got 8aml4bav (float-proof-20261106-000533.log). Drop when
  # upstream bakes the got hash; re-add ONLY via nix-hash-fix evidence.
  md-go-validator =
    flakePkgShim inputs.md-go-validator "default"
      "sha256-8aml4bavcNSQiFrsBbvg87RZqUuoDUjdhR1lF5W0W1A=";
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
  # RE-STALE 2026-10-26 lock float: spec ZuiValdTR, got oS6SRESQ (first-hand
  # keep-going, ~/.cache/lockfloat/float-proof-20261026-161006.log).
  # RE-STALE 2026-11-05 float wave: at project-dependency-graph@8335670
  # spec oS6SRESQ, got S6Brmn7w (float-proof-20261106-000533.log).
  # RE-STALE 2026-11-11 pin-lift wave: at 05e5b1a spec S6Brmn7w,
  # got EQqX6jma (pin-lift toplevel keep-going proof — note this EQUALS the
  # hash upstream's own vendorHash.nix now bakes; the shim survives because
  # pdg's go-nix-helpers/nixpkgs edges re-derive the FOD under our graph).
  # RE-STALE 2026-11-12 cache-eviction re-enumeration: at 0faa5414 spec
  # EQqX6jma, got h6T875PJ (cqrs-shim-toplevel-proof.log). Same follower
  # re-derivation class. Drop when upstream bakes the got hash.
  project-dependency-graph =
    flakePkgShim inputs.project-dependency-graph "default"
      "sha256-h6T875PJxvvhn5K1EpU6LNd5dA6ohCW+Ztwkmm4zkh8=";
  # mr-sync: CLI to keep ~/.mrconfig in sync with GitHub repos.
  # Resolves samber-do-auditlog transitively at v0.8.1 via cmdguard v3.1.0+.
  # RE-STALE 2026-10-26 lock float: spec yB73mr06, got TENDT6NZ (first-hand
  # keep-going, ~/.cache/lockfloat/float-proof-20261026-161006.log).
  # RE-STALE 2026-10-27 lock float: spec TENDT6NZ, got p4C0Ob7i (first-hand
  # keep-going, ~/.cache/lockfloat/float-proof-20261027-172949.log).
  # RE-STALE 2026-11-05 float wave: at mr-sync@ffae30f spec p4C0Ob7i,
  # got z7ABeNjz (float-proof-20261106-000533.log).
  # RE-STALE 2026-11-12 cache-eviction re-enumeration: at 6df95cc9 spec
  # 1M7bvzM3, got kwqwPdAi (cqrs-shim-toplevel-proof.log). The module
  # surface (modules/nixos/services/mr-sync.nix) carries the same value.
  # DROPPED 2026-11-12 daemon-float re-stale (treadmill drop-protocol):
  # the go-cqrs-lite float moved mr-sync to 2ed7e7d1, re-staling
  # kwqwPdAi hours after this morning's paste (got bARGjKuO,
  # toplevel-proof-20261112-drop.log), and upstream 2ed7e7d1 ALREADY
  # BAKES exactly bARGjKuO (got==bake). Both surfaces un-shimmed in the
  # same pass. Re-add ONLY via nix-hash-fix evidence, never by hand.
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
  # vendorHash shim RE-ADDED (2026-10-26 lock float, first-hand keep-going,
  # float-proof-20261026-161006.log): upstream's baked ZRoq5Vdq… at 9ba321b2
  # staled; got +rbh2A6r…. Drop when upstream bakes the got hash; re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  # RE-STALE 2026-11-02 04:12 lock float: at project-meta@17dbf3d0 spec
  # +rbh2A6r, got CejG7L+F (first-hand,
  # ~/.cache/lockfloat/float-proof-20261102-043225-lars.log).
  # RE-STALE 2026-11-05 float wave: at project-meta@332065f spec CejG7L+F,
  # got IpBieRbI (float-proof-20261106-000533.log).
  # RE-STALE 2026-11-06 evening: spec IpBieRbI… lineage, got HfNEpdS
  # (first-hand, float-proof-20261106-225127.log — the crm pin-wave proof
  # enumerated it; the project-meta input floated again via the peer
  # daemon commits).
  # RE-STALE 2026-11-10 ~11:15: spec HfNEpdS, got hmFRcgHq (first-hand,
  # deploy-run-2.log — the nh os switch keep-going enumeration). NEW
  # DRIVER CLASS: not an upstream float — the nixpkgs pin re-land on
  # f9a75f41 (the f4a03c00 patchelf-regression revert) moved the shared
  # Go toolchain project-meta builds with, changing its go-modules FOD
  # content. The input follows our nixpkgs, so pin-level re-lands now
  # re-stale prepared-source vendorHashes; expect the whole consumer
  # family to re-probe after any future pin move.
  project-meta =
    flakePkgShim inputs.project-meta "default"
      "sha256-hmFRcgHqk35rEpYBKnQyK6jMI2466vhmODSHp3z9Vc0=";
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
  # RE-STALE 2026-10-26 lock float: spec jLpz/NzH, got XbZifGSt (first-hand
  # keep-going, ~/.cache/lockfloat/float-proof-20261026-161006.log).
  # project-discovery-daemon shim DROPPED (2026-11-03 night): upstream
  # a6dd6a3 bakes the through-its-own-lock vendorHash OW+eywme… (go-daemon
  # flake pin synced to v0.4.0 0a5d806f, own FOD green first-hand); pdd
  # does not follow our pins, so its own lock governs the FOD content and
  # the override could only re-stale it. Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # NEW shim 2026-11-05 float wave: at pdd@cfaaecd spec OW+eywme, got
  # hxcotRZ7 (float-proof-20261106-000533.log); pdd does not follow our
  # pins (own lock governs). Drop when upstream bakes the got hash;
  # re-add ONLY via nix-hash-fix evidence, never by hand.
  project-discovery-daemon =
    flakePkgShim inputs.project-discovery-daemon "default"
      "sha256-Rd4vxqsiyY1JuHthGNhbHxnsRHe9sQTF9oZzLIWFCXE=";
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
  # projects-management-automation shim DROPPED (2026-10-25): its own drop
  # condition is met — the upstream flake at the locked rev bdd12a3 bakes a
  # vendorHash that builds green THROUGH OUR LOCK (first-hand probe
  # 2026-10-25: inputs.projects-management-automation.packages.x86_64-linux
  # .default.goModules exited 0; only the 2026-10-23 NBQcjrwD… shim was
  # stale, re-breaking the FOD it existed to fix). Re-add ONLY via
  # nix-hash-fix evidence, never by hand.
  # vendorHash shim RE-ADDED (2026-10-26 lock float, first-hand keep-going,
  # float-proof-20261026-161006.log): upstream's baked xvAVnWua… at b13d2e21
  # staled one day after the 2026-10-25 green-through-our-lock probe (its
  # own lock moved again); got fWJuASoh…. The MODULE surface
  # (modules/nixos/services/projects-management-automation.nix) needs the
  # same value — it consumes the flake's own package attr. Drop when
  # upstream bakes the got hash; re-add ONLY via nix-hash-fix evidence,
  # never by hand.
  # RE-STALE 2026-10-28 blanket float: pma@fbd3b1a8 spec fWJuASoh, got
  # v9mUgqkE (float-proof-20261028-214409.log). RE-STALE 2026-10-29 23:15
  # keep-going after the 7-input lock revert (pma back at afccaf96, spec
  # v9mUgqkE, got uTanAcTC; ~/.cache/fixwave/keepgoing.log). The service
  # module (modules/nixos/services/projects-management-automation.nix)
  # carries the same value.
  # RE-STALE 2026-11-02 04:12 lock float: at pma@fde1c413 spec uTanAcTC,
  # got tR/Y9ul (first-hand,
  # ~/.cache/lockfloat/float-proof-20261102-043225-lars.log). The service
  # module (modules/nixos/services/projects-management-automation.nix)
  # carries the same value.
  # RE-STALE 2026-11-03 21:48 lock float: at pma@4053b2ed spec tR/Y9ul,
  # got R0Vv8yx (first-hand,
  # ~/.cache/lockfloat/float-proof-20261103-214837.log). The service
  # module (modules/nixos/services/projects-management-automation.nix)
  # carries the same value.
  # RE-STALE 2026-11-05 float wave: at pma@f598fc9 spec R0Vv8yx,
  # got ErtiXt04 (float-proof-20261106-000533.log). The service module
  # (modules/nixos/services/projects-management-automation.nix)
  # carries the same value.
  # RE-STALE 2026-11-10 nixpkgs-pin revert wave: at pma@da285ff spec
  # 7BFFSpEx, got qs1NJm2K (first-hand keep-going,
  # ~/.cache/toplevel-build-20261110-h.log). Both surfaces updated.
  # Drop when upstream bakes qs1NJm2K.
  # RE-STALE 2026-11-12 cache-eviction re-enumeration: at 5723954f spec
  # qs1NJm2K, got f8YgjTEG (cqrs-shim-toplevel-proof.log). Both surfaces
  # updated. Drop when upstream bakes f8YgjTEG.
  # DROPPED 2026-11-12: drop condition met the SAME DAY — the daemon
  # float moved pma to b1c9f8bc, whose upstream flake ALREADY BAKES the
  # new got 7yqBeT02 (toplevel-proof-20261112-drop.log, got==bake); the
  # morning's f8YgjTEG paste re-staled within hours. Both surfaces
  # un-shimmed in the same pass. Re-add ONLY via nix-hash-fix evidence.
  projects-management-automation = flakePkg inputs.projects-management-automation;
  # vendorHash shim DROPPED (2026-10-07 wave — drop-protocol,
  # docs/agents/nix-flakes.md): upstream 613725e7 ALREADY bakes the got
  # hash wH3k7WiK… (first-hand keep-going enumeration,
  # /tmp/toplevel-fix-20261007.log). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # samber-linter shim DROPPED (2026-10-18): upstream flake.nix at tip
  # 231a91b4 bakes the shim's own 79YZ0u7C… value — bit-neutral override
  # (graph verified identical tip-vs-lock). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
  # vendorHash shim RE-ADDED (2026-10-26 lock float, first-hand keep-going,
  # float-proof-20261026-161006.log): upstream's baked ui9IfWBc… at 2728734d
  # staled; got zrjjUEyK…. Drop when upstream bakes the got hash; re-add
  # ONLY via nix-hash-fix evidence, never by hand.
  # RE-STALE 2026-11-05 float wave: at samber-linter@5795e92 spec
  # zrjjUEyK, got w2Ejmery (float-proof-20261106-000533.log).
  # RE-STALE 2026-11-12 cache-eviction re-enumeration: at f0990463 spec
  # ddUyLNLv, got GLiro+Z0 (cqrs-shim-toplevel-proof.log). Drop when
  # upstream bakes the got hash.
  samber-linter =
    flakePkgShim inputs.samber-linter "default"
      "sha256-GLiro+Z0D35Cp0kda9J2mj4bIvV5bfgxFykrbUOg4vE=";
  # templ: the flake input (github:a-h/templ, floats on main per the owner
  # ALWAYS-LATEST directive) replaces nixpkgs' pkgs.templ, which still ships
  # 0.3.1020 at the rev-pinned nixpkgs — a generator whose output no longer
  # compiles against trees regenerated for templ >= v0.3.1100 (upstream
  # ADR-0004 removed templ.ResolveAttributeValue). Application consumers
  # keep their OWN templ inputs pinned to their go.mod runtimes, so this
  # binary never leaks into their builds.
  templ = flakePkg inputs.templ;
  # timesheets — timesheet CLI (`timesheet serve` deployed as the timesheets
  # unit since 2026-11-10: loopback 127.0.0.1:8109 behind the protected
  # registry vHost timesheets.home.lan; the CLI writes the same SQLite event
  # store via --db — this PATH binary and the unit share one store path;
  # runbook docs/services/timesheets.md). NON-FOLLOWER input (own nixpkgs
  # lock): upstream-baked vendorHash probed green at locked rev 0304e2ae.
  timesheets = flakePkg inputs.timesheets;
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
    # identical tip-vs-lock.
    # vendorHash re-pin RE-ADDED (2026-10-27 lock float): go-taskqueue@420d171
    # baked 2zqvcUaJ re-staled (a re-served dep moved the module graph), got
    # 7YE9PJMW (first-hand keep-going proof,
    # ~/.cache/lockfloat/float-proof-20261027-172949.log). Drop when
    # upstream bakes 7YE9PJMW.
    # RE-STALE 2026-10-28 blanket float: go-taskqueue@a0ed057 now requires
    # go-health v0.8.1, which the 7YE9PJMW FOD does NOT contain — and the
    # stale FOD was silently REUSED because a fixed-output store path is
    # content-addressed by the SPECIFIED hash, so a leftover build of an
    # older rev's module set short-circuits the build and the missing module
    # only surfaces at compile time ("reading …/go-health/@v/v0.8.1.mod: no
    # such file", float-proof-20261028-214409.log). Fresh fakeHash probe at
    # the locked rev got 4zISVNEX (tq-probe.log). Drop when upstream bakes
    # 4zISVNEX; re-add ONLY via nix-hash-fix evidence, never by hand.
    # RE-STALE 2026-11-02 04:12 lock float: at go-taskqueue@0e1679dd spec
    # 4zISVNEX, got wtkejgEG (first-hand,
    # ~/.cache/lockfloat/float-proof-20261102-043225-lars.log). Drop when
    # upstream bakes wtkejgEG; re-add ONLY via nix-hash-fix evidence.
    vendorHash = "sha256-+JIm293yLjRrZGzaZV2d+OEjfyDyL0judEoReC1Ir+Q=";
  });
}
