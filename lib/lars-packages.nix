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

  # Workaround: go-branded-id v0.5.0 ships a prebuilt ELF binary (`namer`) in
  # its module root. The binary's debug_info references the Go compiler store
  # path, which breaks the fixed-output `go-modules` derivation. Switch to
  # vendored module mode, drop the `go-finding` local replace (so the vendor
  # directory does not record a Nix store path), and strip the binary from the
  # vendor directory before it is hashed. Remove once upstream drops the binary
  # from the published module.
  stripPrebuiltGoBinaries =
    pkg: vendorHash:
    let
      pkgWithoutReplace = pkg.override { go-finding-src = null; };
    in
    pkgWithoutReplace.overrideAttrs (old: {
      inherit vendorHash;
      proxyVendor = false;
      modPostBuild =
        (old.modPostBuild or "")
        + ''
          if [ -d vendor/github.com/larsartmann/go-branded-id ]; then
            echo "stripPrebuiltGoBinaries: removing prebuilt namer binary from vendor"
            rm -f vendor/github.com/larsartmann/go-branded-id/namer
          fi
        '';
    });

in
lib.filterAttrs (_: v: v != null) {
  art-dupl = flakePkg inputs.art-dupl;
  branching-flow = flakePkg inputs.branching-flow;
  buildflow = flakePkg inputs.buildflow;
  # cqrs-lint temporarily disabled: same cmdguard/samber-do-auditlog v0.6.0+ break
  # cqrs-lint = overrideCqrsLint ((inputs.go-cqrs-lite.packages.${system} or { }).cqrs-lint or null);
  go-auto-upgrade = flakePkg inputs.go-auto-upgrade;
  go-structure-linter = flakePkg inputs.go-structure-linter;
  golangci-lint-auto-configure = flakePkg inputs.golangci-lint-auto-configure;
  hierarchical-errors = flakePkg inputs.hierarchical-errors;
  library-policy = flakePkg inputs.library-policy;
  md-go-validator = stripPrebuiltGoBinaries (flakePkg inputs.md-go-validator) "sha256-4haqiQNHHDvXkcgnk2WlrKcnC7j6xF8FuOPT456JStU=";
  # mr-sync temporarily disabled: cmdguard/samber-do-auditlog v0.6.0+ API break
  # (ServiceByName takes ServiceName type, not bare string). Re-enable when
  # upstream cmdguard is updated or samber-do-auditlog is pinned via mkPreparedSource.
  # mr-sync = flakePkg inputs.mr-sync;
  project-meta = flakePkg inputs.project-meta;
  projects-management-automation = flakePkg inputs.projects-management-automation;
  todo-list-ai = flakePkg inputs.todo-list-ai;
}
