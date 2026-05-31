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
  (mkPackageOverlay library-policy "library-policy" {vendorHash = "sha256-MH4E5+SpDPSGBaRE23Ez+qjRAgkEMs4/Y/FUT6sXz3U=";})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-oerBC3M2vcec6dD4tdi3e7ZwqUGwFTNykrbPQSyceEg=";})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {vendorHash = "sha256-MMVy22Zx0ui4LCYxGe3bbu1lz7ODolYeef1eq/xrG5Y=";})
  (mkPackageOverlay mr-sync "mr-sync" {})
  (mkPackageOverlay buildflow "buildflow" {vendorHash = "";})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {vendorHash = "sha256-WwiJCOCEOggCIeqL930SxtirurrNO8rT8vuKLFZvEgU=";})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-PrcJm4ZgMOMgxFF2C5bBF997b9upQBE5I+0EtSTWvTw=";})
  (mkPackageOverlay branching-flow "branching-flow" {vendorHash = "sha256-eL+rRV9nTzMod+U1vzMnMtbrl6GLEHOP2E1DJTKkbZk=";})
  (mkPackageOverlay art-dupl "art-dupl" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
