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

    # ecapture statically links libpcap.a; nixpkgs' default libpcap builds
    # the rdmasniff module in (--enable-rdma), whose ibv_* symbols have no
    # static counterpart and broke the link (2026-08-28: "undefined
    # reference to ibv_get_device_list"). A no-rdma libpcap matches the
    # static eBPF tool's needs. Drop once upstream picks a compatible pair.
    ecapture = prev.ecapture.override {
      libpcap = prev.libpcap.override { withRdma = false; };
    };
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
