{
  todo-list-ai,
  buildflow,
  library-policy,
  hierarchical-errors,
  golangci-lint-auto-configure,
  mr-sync,
  go-auto-upgrade,
  go-structure-linter,
  art-dupl,
  branching-flow,
  project-meta,
  projects-management-automation,
  mkPackageOverlay,
  ...
}: let
  tidyGoBuild = ''
    export HOME=$TMPDIR
    go mod tidy
  '';

  mkTidyOverride = vendorHash: old: {
    inherit vendorHash;
    proxyVendor = true;
    preBuild = tidyGoBuild;
    passthru =
      (old.passthru or {})
      // {
        overrideModAttrs = _: {preBuild = tidyGoBuild;};
      };
  };

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
  (mkPackageOverlay library-policy "library-policy" (mkTidyOverride "sha256-v0Ia3pkXJugfXzfP4UUzBBMKWn61LuUjsLq6xZHjog8="))
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {})
  (mkPackageOverlay mr-sync "mr-sync" (mkTidyOverride "sha256-IqE04potoexKr2LVAq643hjZs1Z5HOknY8giWOaxpoQ="))
  (mkPackageOverlay buildflow "buildflow" {})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {})
  (mkPackageOverlay branching-flow "branching-flow" {})
  (mkPackageOverlay art-dupl "art-dupl" {})
  (mkPackageOverlay project-meta "project-meta" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
