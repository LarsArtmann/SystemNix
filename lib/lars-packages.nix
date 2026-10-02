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
  # TEMPORARY vendorHash shim (2026-10-01): the 12:13 blanket lock update
  # (572ff71b) re-locked branching-flow to 5d4965c8 whose upstream
  # vendorHash no longer reproduces under the re-resolved FOD graph (got
  # QUU2TvF7… vs specified Gitg6V8+…; narHash matched — source is the exact
  # locked tree, the 2026-09-23 lock-wave class). Upstream master (2a82b63a)
  # is ahead; drop when the lock moves past an upstream-fixed rev.
  branching-flow = (flakePkg inputs.branching-flow).overrideAttrs {
    vendorHash = "sha256-QUU2TvF76UJRO/AjO+MFPWvYfWrvuBMQ+RiAMMJ5B0w=";
  };
  # buildflow shim DROPPED (2026-09-23): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 5b3483a, where the
  # vendorHash fix IS pushed (upstream vendorHash.nix = sha256-WIFsGVLBMsCK…,
  # the same "got" hash the old shim overrode with the stale fT34kjPX6…
  # value, re-breaking the FOD it existed to fix) and the package builds
  # clean (nix build .#buildflow verified in ~/projects/BuildFlow).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  buildflow = flakePkg inputs.buildflow;
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
  # TEMPORARY vendorHash shim (RE-ADDED 2026-10-01 — the 09-24 drop was
  # overtaken by the 12:13 blanket lock wave): erraudit at the locked rev
  # (c319d8ab) no longer reproduces (got 53gE251C… vs specified N3/5p5IB…).
  # Upstream master (ff6cffa6) is ahead; drop when the lock moves past an
  # upstream-fixed rev.
  erraudit = (flakePkg inputs.erraudit).overrideAttrs {
    vendorHash = "sha256-53gE251CxBy+Bd4kjQHPxLsVeUPA4SyrF8Hu4UVFenA=";
  };
  go-auto-upgrade = flakePkg inputs.go-auto-upgrade;
  go-humanize-linter = flakePkg inputs.go-humanize-linter;
  go-structure-linter = flakePkg inputs.go-structure-linter;
  golangci-lint-auto-configure = flakePkg inputs.golangci-lint-auto-configure;
  library-policy = flakePkg inputs.library-policy;
  md-go-validator = flakePkg inputs.md-go-validator;
  # mr-sync: CLI to keep ~/.mrconfig in sync with GitHub repos.
  # Resolves samber-do-auditlog transitively at v0.8.1 via cmdguard v3.1.0+.
  mr-sync = flakePkg inputs.mr-sync;
  project-meta = flakePkg inputs.project-meta;
  project-discovery-daemon = flakePkg inputs.project-discovery-daemon;
  projects-management-automation = flakePkg inputs.projects-management-automation;
  samber-linter = flakePkg inputs.samber-linter;
  todo-list-ai = flakePkg inputs.todo-list-ai;
  tq = flakePkg inputs.go-taskqueue;
}
