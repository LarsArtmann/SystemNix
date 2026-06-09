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
  (mkPackageOverlay library-policy "library-policy" {vendorHash = "sha256-h5wkT10v14GEnN7RBtWqKTXRMsX6+Qj0AanE4dOSz8U=";})
  (mkPackageOverlay hierarchical-errors "hierarchical-errors" {})

  (mkPackageOverlay golangci-lint-auto-configure "golangci-lint-auto-configure" {vendorHash = "sha256-Wiu9zbLx9ukznrzlJg4oumHA/Qx3Bh6xLPfwe4MEjgQ=";})
  (mkPackageOverlay mr-sync "mr-sync" {vendorHash = "sha256-6WcsIlYdwo4IvlddwHs8Df2v6f5RpWpXkCkCJHg5qF4=";})
  (mkPackageOverlay buildflow "buildflow" {vendorHash = "sha256-RKvH3M8n2X3+5xGjolhYje8ElvIs+cP4XhJ8hjdwK7g=";})
  (mkPackageOverlay go-auto-upgrade "go-auto-upgrade" {vendorHash = "sha256-bTdDHFF4wKpsfcEmnHzphXG/JsfTo2z6wy80+zNUR7w=";})
  (mkPackageOverlay go-structure-linter "go-structure-linter" {vendorHash = "sha256-Bt0ZxNcvDg31AtFE6Xm/kryUC9OOqtoBbQfsE3sB8Ks=";})
  (mkPackageOverlay branching-flow "branching-flow" {vendorHash = "sha256-bv1wRqBTEYThsNp7uTF41FbqoZ/Uq3yrgcn/REFmfRE=";})
  (mkPackageOverlay art-dupl "art-dupl" {vendorHash = "sha256-p8mldrn+sJYbpswh29zdEfxsqdBunwOmhWX+vTPZh1U=";})
  (mkPackageOverlay project-meta "project-meta" {})
  (mkPackageOverlay projects-management-automation "projects-management-automation" {})
  (mkPackageOverlay todo-list-ai "todo-list-ai" {})
  d2DarwinOverlay
]
