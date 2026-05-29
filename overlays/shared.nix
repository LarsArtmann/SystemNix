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

  # aw-webui jest tests fail with missing vue-template-compiler.
  # The aw-webui package is not a top-level nixpkgs attribute — it's defined
  # inside pkgs/applications/office/activitywatch/default.nix and passed to
  # aw-server-rust via AW_WEBUI_DIR. We can't easily override it via overlays.
  # Instead, override activitywatch to skip the broken npm test phase.
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
  (mkPackageOverlay library-policy "library-policy" {})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {vendorHash = "sha256-XVOiKTiNpBOjAaCJ7NkrZUTxWFN6odOSa/m8NjrkukE=";})
  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-E0m7aGN2kD85hrC1ZzJlcs5vo5a5Z3+89iGRXYmiUtE=";})
  (mkPackageOverlay buildflow "buildflow" {vendorHash = "sha256-rox2xM38x2euD6+JJCV76QJT7MlsBX0L4EgM+EExDuA=";})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-+qtWbvT+M4MZFdPBGvo/422PTmWfbt/q88Y33oFMmpk=";})
  (mkPackageOverlay branching-flow "branching-flow" {})
  (mkPackageOverlay art-dupl "art-dupl" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
