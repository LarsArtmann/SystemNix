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
}: system: let
  flakePkg = input: (input.packages.${system} or {}).default or null;
in
  lib.filterAttrs (_: v: v != null) {
    art-dupl = flakePkg inputs.art-dupl;
    branching-flow = flakePkg inputs.branching-flow;
    buildflow = flakePkg inputs.buildflow;
    go-auto-upgrade = flakePkg inputs.go-auto-upgrade;
    go-structure-linter = flakePkg inputs.go-structure-linter;
    golangci-lint-auto-configure = flakePkg inputs.golangci-lint-auto-configure;
    hierarchical-errors = flakePkg inputs.hierarchical-errors;
    library-policy = flakePkg inputs.library-policy;
    md-go-validator = flakePkg inputs.md-go-validator;
    mr-sync = flakePkg inputs.mr-sync;
    project-meta = flakePkg inputs.project-meta;
    projects-management-automation = flakePkg inputs.projects-management-automation;
    todo-list-ai = flakePkg inputs.todo-list-ai;
  }
