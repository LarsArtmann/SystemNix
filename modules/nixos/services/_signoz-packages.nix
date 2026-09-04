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

  buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_25; };

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
      hash = "sha256-gbwNnGuSgAEvN+gnZquzF4EYCGO3wwm3X48YvSjq1Uw=";
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

    meta = with pkgs.lib; {
      description = "SigNoz frontend (community edition)";
      homepage = "https://signoz.io";
      license = licenses.asl20;
      platforms = platforms.linux;
    };
  });

  collectorVendorHash = "sha256-41K2izMlUTpYrIXW+1rpy4F/yosSMQvvbO/EpOwQJvE=";

  schemaMigrator = buildGoModule {
    pname = "signoz-schema-migrator";
    version = collectorVersion;
    src = collectorSrc;
    vendorHash = collectorVendorHash;
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
    src = collectorSrc;
    vendorHash = collectorVendorHash;
    subPackages = [ "cmd/signozotelcollector" ];
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
    inherit src;
    vendorHash = "sha256-1+X3TRfwh1aA/SsZZ84bUXX9RC+wp4uyM2kYNH+Qe3Y=";
    subPackages = [ "cmd/community" ];
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
