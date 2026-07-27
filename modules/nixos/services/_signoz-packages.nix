# SigNoz package derivations: signoz, otel-collector, schema-migrator
# Extracted from signoz.nix to keep the module focused on service configuration.
{
  inputs,
  lib,
}:
let
  ports = (import ../../../lib/default.nix lib).ports;
  version = "0.127.1";
  collectorVersion = "0.144.5";
in
pkgs:
let
  src = inputs.signoz-src;
  collectorSrc = inputs.signoz-collector-src;

  buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_25; };

  collectorVendorHash = "sha256-Woj11mfGSyxiZvCUb32r1Jp86IyT+6Ymwl0ZhhnlzQk=";

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
    vendorHash = "sha256-4HkmDq+c7Oygei2QzlPFtdQNDdalS2M27p3ALxQKi24=";
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
  inherit signoz otelCollector schemaMigrator;
}
