# SigNoz package derivations: signoz, otel-collector, schema-migrator
# Extracted from signoz.nix to keep the module focused on service configuration.
{
  inputs,
  lib,
}:
let
  inherit ((import ../../../lib/default.nix lib)) ports;
  version = inputs.signoz-src.shortRev or "latest";
  collectorVersion = inputs.signoz-collector-src.shortRev or "latest";
in
pkgs:
let
  src = inputs.signoz-src;
  collectorSrc = inputs.signoz-collector-src;

  # go_1_25 was removed from nixpkgs (EOL 2026-09). go_1_26 needs the
  # source patches below: the pinned revs' transitive bytedance/sonic
  # v1.14.x does not compile on Go >= 1.26 (undefined GoMapIterator —
  # sonic added Go 1.26 support in v1.15.0). The patches bump
  # sonic + loader in go.mod/go.sum; with proxyVendor = true the
  # committed vendor/ tree is bypassed and the FOD downloads the patched
  # graph. Drop the patches when the pinned SigNoz revs move and carry a
  # Go-1.26-compatible sonic on their own.
  # `name` is REQUIRED since the 2026-09-17 nixpkgs bump: applyPatches
  # now throws when src is a fetched flake tree (attrset without a name).
  collectorSrcPatched = pkgs.applyPatches {
    name = "signoz-otel-collector-${collectorVersion}-patched";
    src = collectorSrc;
    patches = [ ./patches/signoz-collector-sonic-go126.patch ];
  };
  srcPatched = pkgs.applyPatches {
    name = "signoz-${version}-patched";
    inherit src;
    patches = [ ./patches/signoz-sonic-go126.patch ];
  };

  buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_26; };

  # SigNoz frontend: pnpm 10 workspace (engines pin ">=10 <11"), rolldown-vite
  # (npm-aliased as "vite"), built to a static dist served by the Go binary
  # via web.directory (default /etc/signoz/web) when web.enabled=true.
  # postinstall (ignored under --ignore-scripts) generates
  # i18n-translations-hash.json, which src/ReactI18 imports — run it manually.
  frontend = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "signoz-frontend";
    inherit version;
    inherit src;
    sourceRoot = "source/frontend";

    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) src sourceRoot pname;
      pnpm = pkgs.pnpm_10;
      fetcherVersion = 3;
      # STAMPED 2026-11-18: the signoz-src float to b106d86 changed the
      # frontend lockfile (adds moment@2.31.0 — the old hash died
      # ERR_PNPM_NO_OFFLINE_TARBALL in the 12:1x keep-going enumeration).
      # Probe-then-stamp per the fetchPnpmDeps failure recipe: hash ""
      # build at xiwhlhap…-signoz-frontend-pnpm-deps got KWzSc1U4
      # (first-hand, ~/.cache/toplevel-fix-20261118/signoz-pnpm-probe.log).
      # npm tarballs are immutable, so unlike the private-Go FODs this
      # stamp is deterministic — no flap risk.
      # RE-STALE 2026-11-24 nixpkgs-root float wave: spec KWzSc1U4, got
      # rYGPHPNb (first-hand keep-going,
      # ~/.cache/gtd-pipeline/toplevel-build3.log).
      hash = "sha256-rYGPHPNbzLrLaQ0snkwktH2QN4myTiV81qAfbbTOd5k=";
    };

    nativeBuildInputs = [
      pkgs.nodejs_22
      pkgs.pnpm_10
      pkgs.pnpmConfigHook
      pkgs.autoPatchelfHook
    ];

    # Native napi addons (rolldown, sharp, lightningcss, esbuild) need libstdc++.
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    preBuild = ''
      export LD_LIBRARY_PATH="${
        pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]
      }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      node ./i18-generate-hash.cjs
    '';

    buildPhase = ''
      runHook preBuild
      CI=1 NODE_OPTIONS=--max-old-space-size=8192 pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/signoz
      cp -r build $out/share/signoz/web
      runHook postInstall
    '';

    meta = {
      description = "SigNoz frontend (community edition)";
      homepage = "https://signoz.io";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux;
    };
  });

  # RE-PINNED 2026-10-07 wave (first-hand keep-going enumeration, got
  # R0nm9HFa… at locked signoz-otel-collector rev e0c4766,
  # /tmp/toplevel-fix-20261007.log) — the signoz-* sources ride ?ref=main
  # and the lock wave re-vendored both module graphs.
  collectorVendorHash = "sha256-R0nm9HFaO1CM4uhl3+gS0R+/2odhowDxzOmhEP1s+GI=";

  schemaMigrator = buildGoModule {
    pname = "signoz-schema-migrator";
    version = collectorVersion;
    src = collectorSrcPatched;
    vendorHash = collectorVendorHash;
    proxyVendor = true;
    subPackages = [ "cmd/signozschemamigrator" ];
    ldflags = [
      "-s"
      "-w"
    ];
    postInstall = "mv $out/bin/signozschemamigrator $out/bin/signoz-schema-migrator";
  };

  otelCollector = buildGoModule {
    pname = "signoz-otel-collector";
    version = collectorVersion;
    src = collectorSrcPatched;
    vendorHash = collectorVendorHash;
    subPackages = [ "cmd/signozotelcollector" ];
    proxyVendor = true;
    ldflags = [
      "-s"
      "-w"
    ];
    postInstall = "mv $out/bin/signozotelcollector $out/bin/signoz-otel-collector";
    meta.mainProgram = "signoz-otel-collector";
  };

  signoz = buildGoModule {
    pname = "signoz";
    inherit version;
    src = srcPatched;
    # RE-PINNED 2026-10-07 wave (got 4SEPk/O9… at locked signoz rev
    # bb62c9c; same enumeration as collectorVendorHash above).
    # RE-STALE 2026-11-12 cache-eviction re-enumeration: at 88e9ad7 spec
    # 4SEPk/O9, got GBAtMNzj (cqrs-shim-toplevel-proof.log).
    # RE-STALE 2026-11-12 daemon float: at d00471c spec GBAtMNzj, got
    # 5o/Yfxo3 (toplevel-proof-20261112-drop.log). Tree-side hash —
    # SigNoz is not ours; this file is the fix locus.
    # RE-STALE 2026-11-14 (rev-independent class): at d038407 spec
    # 5o/Yfxo3, got 7NLbdQuy; IDENTICAL got at ca7daf8 too — the FOD
    # re-resolves dep content from the module proxy, so it can go stale
    # WITHOUT a rev move (keepgoing-pre.log + audiblesync triage 08-43).
    # RE-STALE 2026-11-24 nixpkgs-root float wave: spec 7NLbdQuy, got
    # wHHylQe3 (first-hand keep-going, toplevel-build3.log).
    vendorHash = "sha256-wHHylQe3BT7bTPFh+sPZ+1R8uvbjxFyI/3a7Lj6Vbr8=";
    subPackages = [ "cmd/community" ];
    proxyVendor = true;
    tags = [ "timetzdata" ];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/SigNoz/signoz/pkg/version.version=${version}"
      "-X github.com/SigNoz/signoz/pkg/version.variant=community"
      "-X github.com/SigNoz/signoz/pkg/version.hash=nix"
      "-X github.com/SigNoz/signoz/pkg/version.time=1970-01-01T00:00:00Z"
      "-X github.com/SigNoz/signoz/pkg/version.branch=nix"
      "-X github.com/SigNoz/signoz/pkg/query-service/constants.HTTPHostPort=0.0.0.0:${toString ports.signoz}"
    ];

    postInstall = ''
      mv $out/bin/community $out/bin/signoz
      mkdir -p $out/share/signoz
      cp -r $src/conf $out/share/signoz/ 2>/dev/null || true
      cp -r $src/templates $out/share/signoz/ 2>/dev/null || true
    '';

    meta = with lib; {
      description = "SigNoz observability platform (community edition)";
      homepage = "https://signoz.io";
      license = licenses.asl20;
      platforms = platforms.linux;
      mainProgram = "signoz";
    };
  };
in
{
  inherit
    signoz
    frontend
    otelCollector
    schemaMigrator
    ;
}
