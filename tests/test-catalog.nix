# Pure-eval regression test for the services.catalog platform registry
# (ADR-008, plan T03/T04) — the same pattern as test-integration.nix.
#
# Proves, against the REAL catalog + integration modules:
#   1. A catalog entry is VISIBLE on a host where the service is disabled —
#      the entire point of "what exists" being unconditional.
#   2. The cross-check warning fires for an integration subdomain missing
#      from the catalog.
#   3. The warning stays silent when the catalog covers the subdomain.
#   4. The derived subdomain set (T05's DNS source) equals the catalog.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;

  catalogModule = (import ../modules/nixos/services/catalog.nix { }).flake.nixosModules.catalog;
  integrationModule =
    (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration;

  evalConfig =
    extra:
    (lib.nixosSystem {
      inherit system;
      modules = [
        {
          networking.domain = "home.lan";
        }
        catalogModule
        integrationModule
      ]
      ++ extra;
    }).config;

  catalogWarnings = config: builtins.filter (lib.hasPrefix "catalog:") config.warnings;

  # 1+3: catalog entry for a DISABLED service stays visible, and no warning
  # fires because the catalog covers the subdomain.
  covered = evalConfig [
    {
      services.catalog = {
        demo = {
          subdomain = "graph";
          port = 8099;
          description = "Demo service";
          healthPath = "/health";
        };
      };
      services.integration.demo = {
        enable = false; # disabled, yet its catalog entry must exist
        subdomain = "graph";
        port = 8099;
      };
    }
  ];

  # 2: integration declares a subdomain the catalog does not know.
  uncovered = evalConfig [
    {
      services.catalog.demo.subdomain = "graph";
      services.integration.demo = {
        subdomain = "ghost-zone";
        port = 8099;
      };
    }
  ];

  positiveVisible = covered.services.catalog ? demo;
  coveredClean = catalogWarnings covered == [ ];
  negativeFires = lib.any (lib.hasSuffix "ghost-zone") (catalogWarnings uncovered);

  # 4: the T05 derivation mechanism — catalog subdomains fold to the DNS
  # record set exactly as the derivation will consume them.
  derivedSubdomains = builtins.sort (a: b: a < b) (
    lib.catAttrs "subdomain" (
      lib.attrValues (lib.filterAttrs (_: e: e.subdomain != null) covered.services.catalog)
    )
  );
  derivedMatches = derivedSubdomains == [ "graph" ];
in
if !positiveVisible then
  pkgs.runCommand "catalog-test" { } ''
    echo "catalog entry invisible while service disabled — host-independence broken"
    exit 1
  ''
else if !coveredClean then
  pkgs.runCommand "catalog-test" { } ''
    echo "unexpected catalog warning despite covered subdomain: ''${builtins.toJSON (catalogWarnings covered)}"
    exit 1
  ''
else if !negativeFires then
  pkgs.runCommand "catalog-test" { } ''
    echo "cross-check warning did NOT fire for ghost-zone"
    exit 1
  ''
else if !derivedMatches then
  pkgs.runCommand "catalog-test" { } ''
    echo "derived subdomain set mismatch: ''${builtins.toJSON derivedSubdomains}"
    exit 1
  ''
else
  pkgs.runCommand "catalog-test" { } ''
    echo "services.catalog: host-independence, cross-check, and derivation mechanism OK" > $out
  ''
