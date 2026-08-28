[
  (_final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_final: prev: {
        catppuccin = prev.catppuccin.overridePythonAttrs (_old: {
          pythonImportsCheck = [ ];
          doCheck = false;
        });
      })
    ];

    catppuccin-gtk = prev.catppuccin-gtk.override {
      python3 = prev.python312;
    };

    # ecapture links libpcap.a, whose rdmasniff module pulls undefined
    # ibv_* symbols when rdma-core is absent from the link line (nixpkgs
    # regression observed 2026-08-28: "undefined reference to ibv_get_device_list"
    # in ecapture-1.5.2). Drop the override once upstream links cleanly.
    ecapture = prev.ecapture.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ prev.rdma-core ];
    });
  })

  (_final: prev: {
    aw-watcher-utilization = prev.callPackage ../pkgs/aw-watcher-utilization.nix { };
  })

  (
    final: prev:
    let
      awPkgs =
        prev.qt6Packages.callPackage (prev.path + "/pkgs/applications/office/activitywatch/default.nix")
          {
            buildNpmPackage = args: prev.buildNpmPackage (args // { doCheck = false; });
          };
    in
    {
      inherit (awPkgs) aw-server-rust;
      activitywatch = prev.activitywatch.override {
        inherit (final) aw-server-rust;
      };
    }
  )

  (_final: prev: {
    jscpd = prev.callPackage ../pkgs/jscpd.nix { };
  })

  (_final: prev: {
    govalid = prev.callPackage ../pkgs/govalid.nix { };
  })

  (_final: prev: {
    systemd-timer-monitor = prev.callPackage ../pkgs/systemd-timer-monitor.nix { };
  })

  (
    _final: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
      openseo = prev.callPackage ../pkgs/openseo.nix { };
      fastflowlm = prev.callPackage ../pkgs/fastflowlm.nix { };
    }
  )

  (
    _final: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
      d2 = prev.callPackage (prev.path + "/pkgs/by-name/d2/d2/package.nix") {
        libgbm = prev.runCommand "libgbm-stub" { } "mkdir $out";
        playwright-driver = {
          browsers = prev.runCommand "playwright-stub" { } "mkdir $out";
        };
      };
    }
  )
]
