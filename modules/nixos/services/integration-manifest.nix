# The manifest bridge (plan T1/T2, docs/planning/2026-11-08 nix-native
# modernization): bakes eval truth into the system build as ONE JSON file
# that operational scripts read from the RUNNING generation.
#
#   system.build.integration-manifest
#     → derivation whose checkPhase jq-validates the shape at BUILD time
#   environment.etc."systemnix/integration-manifest.json"
#     → /etc/systemnix/integration-manifest.json, riding the generation
#
# Why environment.etc and not runtime `nix eval`: the etc file ALWAYS matches
# the deployed generation (it IS part of it), while `nix eval` measures the
# tree — which can drift mid-deploy (the deploy-vs-executor race lesson) —
# and costs 30-90s of eval per invocation. Same bridge pattern as
# system.build.sops-nix-manifest (§19 gate precedent).
#
# Data owner: lib/integration-manifest.nix (pure builder, fixture-pinned by
# checks.integration-manifest-shape-selftest). This module only wires it.
#
# Downgrade contract (T4): consumers (post-deploy-check.sh) WARN-skip when
# the file is absent — an old generation running a new-tree script degrades
# loudly, never blocks a deploy.
_: {
  flake.nixosModules.integration-manifest =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      buildManifest = import ../../../lib/integration-manifest.nix lib;
      manifest = buildManifest {
        inherit (config.networking) domain;
        inherit ((import ../../../lib/ports.nix)) ports;
        # Guard-shaped reads (the integration.nix fan-out pattern): a host
        # importing a module subset must still evaluate.
        catalog = if options ? services.catalog then config.services.catalog else { };
        integration = if options ? services.integration then config.services.integration else { };
      };
    in
    {
      config = lib.mkMerge [
        {
          system.build.integration-manifest = pkgs.writeTextFile {
            name = "integration-manifest.json";
            text = manifest.json;
            checkPhase = ''
              ${lib.getExe pkgs.jq} -e '
                (.domain | type == "string")
                and (.ports | type == "object" and length > 0)
                and (.services | type == "object")
                and (all(.services[]; has("unit") or has("port")))
              ' "$target" >/dev/null || {
                echo "integration-manifest: FAILED build-time JSON shape check" >&2
                exit 1
              }
            '';
          };

          environment.etc."systemnix/integration-manifest.json" = {
            source = config.system.build.integration-manifest;
            mode = "0644"; # world-readable: post-deploy-check runs as a user
          };
        }
        (lib.optionalAttrs (options ? services.integration) {
          # Non-empty sanity leg: a builder regression that drops every service
          # must fail EVAL here, not silently ship an empty manifest.
          assertions = [
            {
              assertion = builtins.length (builtins.attrNames manifest.manifest.services) > 0;
              message = "integration-manifest: services set is empty — the catalog/integration merge produced nothing (builder regression in lib/integration-manifest.nix)";
            }
          ];
        })
      ];
    };
}
