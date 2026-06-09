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
  project-meta,
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
  (mkPackageOverlay library-policy "library-policy" (mkTidyOverride "sha256-5MBRPKVKX65FaPEazmXAnM9M1Ud5S56zsHqeLav9WDs="))
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-TSXISnjJ+7UJ+Gg4bJRo5FE5B9Oq+ifN8Il4TqYRzUw=";})

  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {vendorHash = "sha256-m5Y+RiJujRIANWnUR0Plc4PqX2lwLotDkOLLQyDG+mg=";})
  (mkPackageOverlay mr-sync "mr-sync" (mkTidyOverride "sha256-CEuoyksoPDmalGQB9sTH6GKvLLmrVaPy9hzlZqtZBpA="))
  (mkPackageOverlay buildflow "buildflow" {})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {vendorHash = "sha256-RwGNQ5m7DPXc9AGTcQRgqF+mc+wQe+2ISMlHIAvfico=";})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-jLc2LPW+zRT6n9WYMBDhJjU0f2AvvHFuBYAtcsrinjE=";})
  (mkPackageOverlay branching-flow "branching-flow" {})
  (mkPackageOverlay art-dupl "art-dupl" {vendorHash = "sha256-p8mldrn+sJYbpswh29zdEfxsqdBunwOmhWX+vTPZh1U=";})
  (mkPackageOverlay project-meta "project-meta" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
