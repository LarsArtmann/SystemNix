{ lib, inputs }: system:
let
  flakePkg = input: (input.packages.${system} or { }).default or null;
  overrideCqrsLint = pkg: if pkg == null then null else
    pkg.overrideAttrs (old: { goModules = old.goModules.overrideAttrs (_: { outputHash = "sha256-OxASLe2eemTxUYKODYE6JECm1uH/U4qIqE7xXDh6BnA="; }); });
  overrideVendorHash = hash: pkg: if pkg == null then null else
    pkg.overrideAttrs (old: { goModules = old.goModules.overrideAttrs (_: { outputHash = hash; }); });
in
lib.filterAttrs (_: v: v != null) {
  art-dupl = flakePkg inputs.art-dupl;
  branching-flow = overrideVendorHash "sha256-ycIZlqUi5MlVdczbMfelD5KwyTWE7P6cDfgQV4siMEg=" (flakePkg inputs.branching-flow);
  buildflow = flakePkg inputs.buildflow;
  cqrs-lint = overrideCqrsLint ((inputs.go-cqrs-lite.packages.${system} or { }).cqrs-lint or null);
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
