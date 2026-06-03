{
  todo-list-ai,
  library-policy,
  golangci-lint-auto-configure,
  mr-sync,
  hierarchical-errors,
  buildflow,
  go-auto-upgrade,
  go-structure-linter,
  branching-flow,
  art-dupl,
  projects-management-automation,
  mkPackageOverlay,
  ...
}: let
  awWatcherOverlay = _final: prev: {
    aw-watcher-utilization = prev.callPackage ../pkgs/aw-watcher-utilization.nix {};
  };

  activitywatchOverlay = final: prev: let
    awPkgs = prev.qt6Packages.callPackage (prev.path + "/pkgs/applications/office/activitywatch/default.nix") {
      buildNpmPackage = args: prev.buildNpmPackage (args // {doCheck = false;});
    };
  in {
    aw-server-rust = awPkgs.aw-server-rust;
    activitywatch = prev.activitywatch.override {
      aw-server-rust = final.aw-server-rust;
    };
  };

  jscpdOverlay = _final: prev: {
    jscpd = prev.callPackage ../pkgs/jscpd.nix {};
  };

  govalidOverlay = _final: prev: {
    govalid = prev.callPackage ../pkgs/govalid.nix {};
  };

  d2DarwinOverlay = _final: prev:
    prev.lib.optionalAttrs prev.stdenv.isDarwin {
      d2 = prev.callPackage (prev.path + "/pkgs/by-name/d2/d2/package.nix") {
        libgbm = prev.runCommand "libgbm-stub" {} "mkdir $out";
        playwright-driver = {browsers = prev.runCommand "playwright-stub" {} "mkdir $out";};
      };
    };
in [
  awWatcherOverlay
  activitywatchOverlay
  jscpdOverlay
  govalidOverlay
  (mkPackageOverlay library-policy "library-policy" {vendorHash = "sha256-8/Yn3hoW/GHgq+bUxxTlGVi6pjChw6Unq/baluyrj04=";})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-1+kYoA90tD+DSuoiHFBE+jyprPo4IWuiaOIMHcOYSNU=";})
  (mkPackageOverlay buildflow "buildflow" {})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {vendorHash = "sha256-EhKRJczms0gw0JniX+TFBanwIt0muK+PX0WMUk0EHxE=";})
  # go-structure-linter — BROKEN: template-LICENSE/types private dep not in _local_deps;
  # go mod tidy fails in sandbox. Needs upstream fix. VendorHash stale after go-finding update.
  # (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-pbXGL14SRnIF6OGjCw+5Cos4aANpKOXKzBO82bPTQnE=";})
  (mkPackageOverlay branching-flow "branching-flow" {vendorHash = "sha256-BGKYeWl9rxBDvZYOW5/IbMQRxv2toaxexmJm4iMKsic=";})
  (mkPackageOverlay art-dupl "art-dupl" {vendorHash = "sha256-HSgFUbQEOScJqVG8/J9JRwJtgjFtWfCdli8b7VcdYVY=";})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
