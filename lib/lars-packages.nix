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
  # TEMPORARY vendorHash shim (2026-10-05, class comment at buildflow): got
  # OBmrPDoU… vs upstream-specified PirjczMaw… at locked rev 05d8209f
  # (first-hand evidence: 07:37 deploy build, log
  # /var/log/systemnix-deploys/2026-10-05_07-37-03.log). The 2026-10-02 drop
  # went stale when the lock moved to a re-broken rev (upstream re-broke the
  # hash it had fixed; lifecycle class at buildflow). Bootstrap exception: the
  # upstream checkout is owned by a live parallel session mid version-sync
  # (0.2.0->0.6.4, fix at unpushed 65a4d189), so buildflow nix-hash-fix cannot
  # run there; hash pasted from first-hand build output, never invented. Drop
  # when the lock moves past a PUSHED upstream-fixed rev.
  branching-flow =
    let
      pkg = flakePkg inputs.branching-flow;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-OBmrPDoUGaHFUBzALSv/YzercrzA8lAQ/N4sl6D2vJU=";
      };
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
  buildflow =
    let
      pkg = flakePkg inputs.buildflow;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-PEVbgZ6J8/YvynKLkB8W8S9+EoORRR/AfUctpVJhT2Q=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): got heAweMaV… vs the 2026-10-01 shim value
  # yonqp/FVG… at locked rev 4d4137ee. Upstream master (abb38b28) is ahead;
  # drop when the lock moves past an upstream-fixed rev. Null-safe: keeps
  # the missing-package filter honest.
  cqrs-lint =
    let
      pkg = inputs.go-cqrs-lite.packages.${system}.cqrs-lint or null;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-heAweMaV7hMinU5eNAWOYrcYDVN8h192kxAaRl3nxZs=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): the 2026-10-03 value vDCDafsa… stopped
  # reproducing; got 96zTy5ij… at locked rev ff6cffa. Drop when the lock
  # moves past an upstream-fixed rev.
  erraudit =
    let
      pkg = flakePkg inputs.erraudit;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-96zTy5ij7yBNwcTb+YnWLyNWYB776S4Zbd949Ok6Jdk=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): got RAmyzsGd… at locked rev 523de68.
  go-auto-upgrade =
    let
      pkg = flakePkg inputs.go-auto-upgrade;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-RAmyzsGdgQbFsiErKKYgBu/IVvcbqiYXI5K63LycsEU=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): got cBUoF13V… at locked rev eb7ecab.
  go-humanize-linter =
    let
      pkg = flakePkg inputs.go-humanize-linter;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-cBUoF13VZohsIRvBARQChXH7nlmYjC657kvj0G25gWM=";
      };
  go-structure-linter = flakePkg inputs.go-structure-linter;
  # TEMPORARY vendorHash shim (2026-10-05, a7868a7 wave — class comment at
  # buildflow): got Ky0wHN9Z… vs upstream-specified AAFXbSdH… at locked rev
  # ec98ce76.
  golangci-lint-auto-configure =
    let
      pkg = flakePkg inputs.golangci-lint-auto-configure;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-Ky0wHN9ZmLYAxjwgRwgoxLzakqaeHFhnoim3Ixjn3Ag=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): got W9D93IZf… at locked rev ff6a493.
  library-policy =
    let
      pkg = flakePkg inputs.library-policy;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-W9D93IZfOwxE8Y1wEuz+qVWqNjxcAkTXruiuvO9osTw=";
      };
  # TEMPORARY go toolchain + vendorHash shim (2026-10-03): md-go-validator's
  # go.mod floor is 1.27.1 while nixpkgs' default go is 1.26.8 — the FOD
  # dies "go: go.mod requires go >= 1.27.1 (GOTOOLCHAIN=local)" (the
  # 2026-09-17 go 1.27 wave class; fix forward with go_1_27, never pin the
  # toolchain back). Upstream's package.nix hardcodes the toolchain (its
  # lambda takes no `go`), so the override rebinds `buildGoModule` itself
  # (the documented wiring point 3) — that propagates go_1_27 into the
  # go-modules FOD. vendorHash under go_1_27 LEARNED via the fakeHash
  # mismatch build (2026-10-03), then pasted below. Drop both when upstream
  # bumps its toolchain and re-pins its hash.
  md-go-validator =
    let
      pkg = flakePkg inputs.md-go-validator;
    in
    if pkg == null then
      null
    else
      (pkg.override {
        buildGoModule = inputs.nixpkgs.legacyPackages.${system}.buildGoModule.override {
          go = inputs.nixpkgs.legacyPackages.${system}.go_1_27;
        };
      }).overrideAttrs
        { vendorHash = "sha256-h3p6Hh2Ak1cPwnrtVNX+OTOJZMRpDRDPRDrb2r9JpS0="; };
  # mr-sync: CLI to keep ~/.mrconfig in sync with GitHub repos.
  # Resolves samber-do-auditlog transitively at v0.8.1 via cmdguard v3.1.0+.
  mr-sync = flakePkg inputs.mr-sync;
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): got mkVtnCAg… at locked rev c37517b
  # (upstream package name is "meta").
  project-meta =
    let
      pkg = flakePkg inputs.project-meta;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-mkVtnCAg/4zLUkPfnfamR1PIUTYcG51dphQzLiRmr2A=";
      };
  # TEMPORARY vendorHash shim (2026-10-05, a7868a7 wave — class comment at
  # buildflow): got Mrn25ftf… vs upstream-specified 8kSXYjwa… at locked rev
  # 1f9b57c.
  project-discovery-daemon =
    let
      pkg = flakePkg inputs.project-discovery-daemon;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-Mrn25ftfpqf9rov194lDd/JqiDeBbgiGSt9+r0hnYF8=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): got XFHNI8Cw… at locked rev 78b01da.
  projects-management-automation =
    let
      pkg = flakePkg inputs.projects-management-automation;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-XFHNI8CwnEE2GK74fXzm16XGil5y14RMCEs3RKBRQdY=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-05, a7868a7 wave — class
  # comment at buildflow): got 9w7D9nyu… at locked rev a18ed72.
  samber-linter =
    let
      pkg = flakePkg inputs.samber-linter;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-9w7D9nyuitluLTq3a5gW+T3BEYwfobB3HdxHu92fBdE=";
      };
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
  # flake adds git itself. vendorHash re-pinned 2026-10-05 (a7868a7 wave,
  # class comment at buildflow): got /fevyHgd… at locked rev.
  tq = (flakePkg inputs.go-taskqueue).overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      inputs.nixpkgs.legacyPackages.${system}.git
    ];
    vendorHash = "sha256-/fevyHgdr1ycM/mvjNQX8iassOS+q4UtS1yA6XsXwsQ=";
  });
}
