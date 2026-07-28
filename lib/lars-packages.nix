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
  buildflow = flakePkg inputs.buildflow;
  # cqrs-lint: temporarily disabled — go-cqrs-lite has broken transitive deps
  # (cmdguard/v3/pkg/cmdguard/v3 missing after private dep additions).
  # Re-enable once upstream is fixed.
  cqrs-lint = null;
  go-auto-upgrade = flakePkg inputs.go-auto-upgrade;
  go-structure-linter = flakePkg inputs.go-structure-linter;
  golangci-lint-auto-configure = flakePkg inputs.golangci-lint-auto-configure;
  hierarchical-errors = flakePkg inputs.hierarchical-errors;
  library-policy = flakePkg inputs.library-policy;
  md-go-validator = flakePkg inputs.md-go-validator;
  # mr-sync: re-enabled — samber-do-auditlog now pinned to v0.5.0 as top-level
  # flake input, which mkPreparedSource uses to override the v0.6.0+ API break.
  mr-sync = flakePkg inputs.mr-sync;
  project-meta = flakePkg inputs.project-meta;
  projects-management-automation = flakePkg inputs.projects-management-automation;
  todo-list-ai = flakePkg inputs.todo-list-ai;
}
