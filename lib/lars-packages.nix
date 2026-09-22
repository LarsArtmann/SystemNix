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
  art-dupl = flakePkg inputs.art-dupl;
  branching-flow = flakePkg inputs.branching-flow;
  # TEMPORARY vendorHash shim (2026-09-22): lock holds 7e1fbfe (last
  # deploy-proven rev, gen 797), but the root nixpkgs moved (44a9189 ->
  # 6774f7bc) and the prepared-source graph re-resolved, so the upstream
  # FOD no longer reproduces (ultraviolet@2026-09-22 absent from the
  # cached vendor tree — the browser-history 2026-09-22 rollback class).
  # Upstream master (bc999b4) is worse: package COMPILE fails (gvafix.*
  # undefined; fixes unpushed in ~/projects/BuildFlow). Drop this shim
  # when the lock moves past an upstream-fixed rev.
  buildflow = (flakePkg inputs.buildflow).overrideAttrs {
    vendorHash = "sha256-fT34kjPX6hH6fe/vwVbkDZQNL4Qy7bw0x1KFUCAkS0U=";
  };
  cqrs-lint = inputs.go-cqrs-lite.packages.${system}.cqrs-lint or null;
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
