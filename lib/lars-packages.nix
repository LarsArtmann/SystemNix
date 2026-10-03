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
  # branching-flow shim DROPPED (2026-10-02): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 2a82b63a, whose flake
  # pins flowVendorHash = sha256-T0Q7PXNA… (the same "got" hash the stale
  # shim's FOD produced 2026-10-02; the old shim pinned the 2026-10-01 wave's
  # QUU2TvF7… for rev 5d4965c8 and re-broke the FOD it existed to fix —
  # the buildflow-shim lifecycle class). Re-add ONLY via nix-hash-fix
  # evidence, never by hand.
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
  buildflow =
    let
      pkg = flakePkg inputs.buildflow;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-0zQhoKtBZOVOYwBLSazCQkqftz+FzblOKq2gAjtLDa8=";
      };
  # TEMPORARY vendorHash shim (2026-10-01): same 12:13 lock-wave class —
  # cqrs-lint at the locked go-cqrs-lite rev (package version 4d4137ee)
  # no longer reproduces (got yonqp/FVG… vs specified YHWDwUiU…). Upstream
  # master (abb38b28) is ahead; drop when the lock moves past an
  # upstream-fixed rev. Null-safe: keeps the missing-package filter honest.
  cqrs-lint =
    let
      pkg = inputs.go-cqrs-lite.packages.${system}.cqrs-lint or null;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-yonqp/FVG61XlYlPbKWzlF6a6HTj4bMWMbJjiswtdCo=";
      };
  # TEMPORARY vendorHash shim (RE-PINNED 2026-10-03 — the 2026-10-01
  # value 53gE251C… stopped reproducing under the 2026-10-01 nixpkgs bump's
  # go 1.26.8; got vDCDafsa… at locked rev ff6cffa; class comment at
  # buildflow): drop when the lock moves past an upstream-fixed rev.
  erraudit =
    let
      pkg = flakePkg inputs.erraudit;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-vDCDafsaiklmIVxUd0cd388RGPIPxFn8tmSq5Zh/Mdc=";
      };
  # TEMPORARY vendorHash shim (2026-10-03, class comment at buildflow):
  # got ehwnSdmK… vs upstream-specified aUUDRHJq… at locked rev 523de68.
  go-auto-upgrade =
    let
      pkg = flakePkg inputs.go-auto-upgrade;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-ehwnSdmKoaLpg8ArmfOKN75YGoTlTNxEjpIQBktogQw=";
      };
  # TEMPORARY vendorHash shim (2026-10-03, class comment at buildflow):
  # got 0tQggc3i… vs upstream-specified 1e7f3SGh… at locked rev eb7ecab.
  go-humanize-linter =
    let
      pkg = flakePkg inputs.go-humanize-linter;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-0tQggc3iaMXzw5/Vxzh358JlNmd6LOxisShxYFjOzuk=";
      };
  go-structure-linter = flakePkg inputs.go-structure-linter;
  golangci-lint-auto-configure = flakePkg inputs.golangci-lint-auto-configure;
  # TEMPORARY vendorHash shim (2026-10-03, class comment at buildflow):
  # got mRy5adkB… vs upstream-specified n7AlfJzR… at locked rev ff6a493.
  library-policy =
    let
      pkg = flakePkg inputs.library-policy;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-mRy5adkB7U5jAE8mEyFl9AVaecmHlq1uOY0qhU/lLUc=";
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
  # TEMPORARY vendorHash shim (2026-10-03, class comment at buildflow):
  # got 05qifzqW… vs upstream-specified WARVEIZC… at locked rev c37517b
  # (upstream package name is "meta").
  project-meta =
    let
      pkg = flakePkg inputs.project-meta;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-05qifzqWumAD+Yy0gtWr+h/w/g6CVrPNBbaZBPTwV1M=";
      };
  project-discovery-daemon = flakePkg inputs.project-discovery-daemon;
  # TEMPORARY vendorHash shim (2026-10-03, class comment at buildflow):
  # got sNgwtT8V… vs upstream-specified +kBpR6ki… at locked rev 78b01da.
  projects-management-automation =
    let
      pkg = flakePkg inputs.projects-management-automation;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-sNgwtT8VFNgVVKrbouHTvY4Jn9BwvL7Z1ZLeJ4LxjxU=";
      };
  # TEMPORARY vendorHash shim (2026-10-03, class comment at buildflow):
  # got pTZB1Vaw… vs upstream-specified lp4uWTm6… at locked rev a18ed72.
  samber-linter =
    let
      pkg = flakePkg inputs.samber-linter;
    in
    if pkg == null then
      null
    else
      pkg.overrideAttrs {
        vendorHash = "sha256-pTZB1VawQ8kEby34hWQVJerhFNUvX6M8rSABfwnvzpU=";
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
  # flake adds git itself.
  tq = (flakePkg inputs.go-taskqueue).overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      inputs.nixpkgs.legacyPackages.${system}.git
    ];
  });
}
