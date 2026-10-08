[
  (_final: prev: {
    # TEMPORARY compat shim (2026-09-17): nixpkgs removed go_1_25 /
    # buildGo125Module (EOL 2026-09-15), but sops-nix master (13616fff,
    # still HEAD upstream) builds sops-install-secrets with buildGo125Module
    # and is evaluated against consumer nixpkgs. Aliased to the go_1_26
    # builders until upstream sops-nix bumps. Drop after sops-nix > 13616fff.
    buildGo125Module = prev.buildGo126Module;
    go_1_25 = prev.go_1_26;

    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_final: prev: {
        catppuccin = prev.catppuccin.overridePythonAttrs (_old: {
          pythonImportsCheck = [ ];
          doCheck = false;
        });
      })

      (_pythonFinal: pythonPrev: {
        # nixpkgs' django-polymorphic carries pytest-playwright in
        # nativeCheckInputs while DISABLING the playwright-dependent tests
        # — but its conftest.py UNCONDITIONALLY reads the plugin's
        # `--headed` option, so stripping the plugin alone makes pytest
        # INTERNALERROR at configure. The dep also drags playwright-python's
        # source FOD into every paperless build, and microsoft RE-TAGGED
        # v1.63.0 — cold fetches fail with a hash mismatch (live
        # 2026-09-17). Strip BOTH the dep and the check (paperless does not
        # need this leaf package's tests).
        # NOTE: overridePythonAttrs, NOT overrideAttrs — the python builder
        # folds nativeCheckInputs into the derivation before overrideAttrs
        # runs, so the stdenv-level override is a silent no-op here.
        # Drop when nixpkgs drops it or fixes the playwright pin.
        django-polymorphic = pythonPrev.django-polymorphic.overridePythonAttrs (old: {
          nativeCheckInputs = prev.lib.remove pythonPrev.pytest-playwright (old.nativeCheckInputs or [ ]);
          dontUsePytestCheck = true;
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
    # go-licenses must run from the go 1.27 generation on BOTH axes
    # (verified 2026-10-08; BuildFlow gotcha #188 class — an analyzer drives
    # a go of its own toolchain generation):
    #   buildGoModule bakes the binary's toolchain generation, AND
    #   go feeds package.nix's postInstall `--set GOROOT '${go}/share/go'`
    #     (upstream go-licenses#149 workaround). With only the builder
    #     overridden, a go1.27-built binary still reads the go1.26 std tree
    #     at runtime (env GOROOT beats the baked one) and FATALs identically
    #     with "package uuid is not in std".
    # Same one-way rule as pkgs/govalid.nix: build Go analyzers with the
    # NEWEST fleet toolchain (new reads old; old cannot read new). Drop the
    # whole block once nixpkgs' default go >= 1.27; if go_1_27 is removed
    # before that, alias forward like the sops-nix shim above.
    go-licenses = prev.go-licenses.override {
      buildGoModule = prev.buildGo127Module;
      go = prev.go_1_27;
    };
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
]
