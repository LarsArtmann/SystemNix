[
  (_final: prev: {
    aw-watcher-utilization = prev.callPackage ../pkgs/aw-watcher-utilization.nix {};
  })

  (final: prev: let
    awPkgs = prev.qt6Packages.callPackage (prev.path + "/pkgs/applications/office/activitywatch/default.nix") {
      buildNpmPackage = args: prev.buildNpmPackage (args // {doCheck = false;});
    };
  in {
    aw-server-rust = awPkgs.aw-server-rust;
    activitywatch = prev.activitywatch.override {
      aw-server-rust = final.aw-server-rust;
    };
  })

  (_final: prev: {
    jscpd = prev.callPackage ../pkgs/jscpd.nix {};
  })

  (_final: prev: {
    govalid = prev.callPackage ../pkgs/govalid.nix {};
  })

  (_final: prev:
    prev.lib.optionalAttrs prev.stdenv.isDarwin {
      d2 = prev.callPackage (prev.path + "/pkgs/by-name/d2/d2/package.nix") {
        libgbm = prev.runCommand "libgbm-stub" {} "mkdir $out";
        playwright-driver = {browsers = prev.runCommand "playwright-stub" {} "mkdir $out";};
      };
    })
]
