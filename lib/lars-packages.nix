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
  # TEMPORARY vendorHash shim (2026-09-23): the root nixpkgs move (44a9189 →
  # 6774f7bc) re-resolved the go-modules FOD graph, so the upstream
  # vendorHash no longer reproduces (got fmLiSd6d… vs specified a/Fx2E5Z…).
  # The fix IS committed upstream on fork (eabf846c) but UNPUSHED (origin/fork
  # 440b8df5 still carries the stale hash). Drop when the lock moves past a
  # pushed upstream-fixed rev. Same class + shape as the buildflow shim.
  art-dupl = (flakePkg inputs.art-dupl).overrideAttrs {
    vendorHash = "sha256-fmLiSd6dN0Z85m+vDks3tQUD7yb76ZeytiE5j3FEp4E=";
  };
  branching-flow = flakePkg inputs.branching-flow;
  # buildflow shim DROPPED (2026-09-23): its drop condition ("lock moves
  # past an upstream-fixed rev") is met — the lock holds 5b3483a, where the
  # vendorHash fix IS pushed (upstream vendorHash.nix = sha256-WIFsGVLBMsCK…,
  # the same "got" hash the old shim overrode with the stale fT34kjPX6…
  # value, re-breaking the FOD it existed to fix) and the package builds
  # clean (nix build .#buildflow verified in ~/projects/BuildFlow).
  # Re-add ONLY via nix-hash-fix evidence, never by hand.
  buildflow = flakePkg inputs.buildflow;
  cqrs-lint = inputs.go-cqrs-lite.packages.${system}.cqrs-lint or null;
  # erraudit shim DROPPED (2026-09-24): lock erraudit_3 = 1c85610 whose
  # upstream flake bakes the reproducing vendorHash (eGg9GDlf…) — the
  # shim's own drop condition is met.
  erraudit = flakePkg inputs.erraudit;
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
  todo-list-ai = flakePkg inputs.todo-list-ai;
  tq = flakePkg inputs.go-taskqueue;
}
