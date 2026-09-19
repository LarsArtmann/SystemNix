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

  (
    _final: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
      # nixpkgs 26.11.20260916's playwright-webkit is cold-build-broken
      # (auto-patchelf: libmanette-0.2.so.0 missing from webkit-linux
      # buildInputs). d2 only needs ONE browser for PNG export — serve it
      # the chromium-only preset until nixpkgs repairs the webkit bundle.
      # Drop when nixpkgs' playwright-webkit builds from source again.
      d2 = prev.d2.override {
        playwright-driver = prev.playwright-driver // {
          browsers = prev.playwright-driver.browsers-chromium;
        };
      };
    }
  )

  (
    _final: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
      # nodejs 26.9.0's test-fs-cp-async-file-modes chmods a file to 0o4755
      # and fails EPERM in sandboxed builds (nixpkgs issue #564449 — Hydra
      # reproduces; every other test passes). nixpkgs disabled the test in
      # commit 089b82f9 "nodejs_26: disable failing test" (non-Darwin only,
      # which isLinux matches); drop this shim once the lock carries it.
      # nodejs_26/nodejs_latest/npm-12/hermes/llama-cpp all derive from
      # nodejs-slim_26, so this single override covers the chain.
      nodejs-slim_26 = prev.nodejs-slim_26.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          rm -f test/parallel/test-fs-cp-async-file-modes.mjs
        '';
      });
    }
  )
]
