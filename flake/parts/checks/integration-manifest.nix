# Fixture check for the integration-manifest builder (plan T1.4,
# docs/planning/2026-11-08 nix-native modernization): pins the manifest
# CONTRACT on stub data so a builder change that silently alters the shape
# fails `nix flake check`, not a jq parse at deploy time.
#
# What is pinned (extend here when extending lib/integration-manifest.nix):
#   - catalog-only entries carry exactly the catalog field group
#   - integration-only entries carry unit/vHostLayer/monitored/checks
#   - names in BOTH surfaces merge both field groups (union view)
#   - relative check URLs resolve against the integration entry's port;
#     absolute URLs pass through verbatim (integration.nix checkUrl parity)
#   - per-check timeout rides client.timeout when set
#   - DISABLED integration entries vanish from services
#   - the whole tree is JSON (assertJsonSafe) and round-trips through jq
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    lib.mkIf (system == "x86_64-linux") {
      checks.integration-manifest-shape-selftest =
        let
          buildManifest = import (root + "/lib/integration-manifest.nix") lib;
          stub = buildManifest {
            domain = "home.lan";
            ports = {
              pocket-id = 1411;
              gatus = 9410;
            };
            catalog = {
              auth = {
                subdomain = "auth";
                port = 1411;
                owner = "lars";
                description = "OIDC provider";
                healthPath = "/healthz";
              };
              forgejo = {
                subdomain = "forgejo";
                port = 3000;
                owner = "lars";
                description = "git";
                healthPath = "/api/v1/version";
              };
            };
            integration = {
              # Different NAME from its catalog sibling (catalog.auth): the
              # union view keeps the two surfaces SEPARATE — services.auth
              # carries the catalog fields, services["pocket-id"] the
              # integration fields. No subdomain join (fragile by design).
              pocket-id = {
                enable = true;
                unit = null;
                subdomain = "auth";
                port = 1411;
                checks = [
                  {
                    name = "pocket-id healthz";
                    group = "Infrastructure";
                    path = "/healthz";
                    url = null;
                    interval = "30s";
                    conditions = [ "[STATUS] == 200" ];
                    alert = null;
                    client = {
                      timeout = 10;
                    };
                    headers = { };
                  }
                  {
                    name = "pocket-id metrics";
                    group = "Infrastructure";
                    path = "/metrics";
                    url = "http://127.0.0.1:9464/metrics";
                    interval = "60s";
                    conditions = [ "[STATUS] == 200" ];
                    alert = null;
                    client = { };
                    headers = { };
                  }
                ];
                homepage = null;
                backup = null;
                monitored = true;
                noDashboardTile = false;
                oidc = null;
                otel = null;
                vHost = {
                  layer = "protected";
                  root = null;
                  hostOverride = null;
                };
              };
              # SAME name as catalog.forgejo: the one case where both field
              # groups land on one entry.
              forgejo = {
                enable = true;
                unit = "forgejo";
                subdomain = "forgejo";
                port = 3000;
                checks = [ ];
                homepage = null;
                backup = null;
                monitored = false;
                noDashboardTile = false;
                oidc = null;
                otel = null;
                vHost = {
                  layer = "plain";
                  root = null;
                  hostOverride = null;
                };
              };
              # Disabled: must NOT appear in services.
              dormant = {
                enable = false;
                unit = null;
                subdomain = null;
                port = 9999;
                checks = [ ];
                homepage = null;
                backup = null;
                monitored = false;
                noDashboardTile = false;
                oidc = null;
                otel = null;
                vHost = {
                  layer = "none";
                  root = null;
                  hostOverride = null;
                };
              };
            };
          };
          stubJson = pkgs.writeText "integration-manifest-stub.json" stub.json;
        in
        pkgs.runCommand "integration-manifest-shape-selftest"
          {
            nativeBuildInputs = [ pkgs.jq ];
          }
          ''
            set -euo pipefail
            fail() { echo "integration-manifest-shape-selftest: $1" >&2; exit 1; }

            # --- union view -------------------------------------------------
            jq -e '.domain == "home.lan"' <${stubJson} >/dev/null || fail "domain missing/wrong"
            jq -e '.ports["pocket-id"] == 1411 and .ports.gatus == 9410' <${stubJson} >/dev/null \
              || fail "ports registry not carried verbatim"

            # catalog-only entry: exactly the catalog field group
            jq -e '(.services.auth | keys | sort) == (["description","healthPath","port","subdomain"] | sort)' <${stubJson} >/dev/null \
              || fail "catalog-only entry carries unexpected keys: $(jq -c '.services.auth | keys' <${stubJson})"

            # integration-only entry: integration fields + port, NO catalog
            # fields (catalog.auth is a different name — no subdomain join)
            jq -e '.services["pocket-id"].unit == "pocket-id" and .services["pocket-id"].vHostLayer == "protected" and .services["pocket-id"].monitored == true' <${stubJson} >/dev/null \
              || fail "integration-only entry missing integration fields"
            jq -e '(.services["pocket-id"] | has("healthPath")) | not' <${stubJson} >/dev/null \
              || fail "integration-only entry unexpectedly joined a catalog sibling (subdomain join must not happen)"

            # same-NAME pair: both field groups on one entry
            jq -e '.services.forgejo.port == 3000 and .services.forgejo.healthPath == "/api/v1/version" and .services.forgejo.unit == "forgejo" and .services.forgejo.vHostLayer == "plain"' <${stubJson} >/dev/null \
              || fail "same-name catalog+integration pair did not merge both field groups"

            # disabled entries vanish
            jq -e '.services | has("dormant") | not' <${stubJson} >/dev/null \
              || fail "disabled integration entry leaked into services"

            # --- check URL resolution (integration.nix checkUrl parity) ----
            jq -e '.services["pocket-id"].checks[0].url == "http://127.0.0.1:1411/healthz"' <${stubJson} >/dev/null \
              || fail "relative check URL did not resolve against the entry port"
            jq -e '.services["pocket-id"].checks[1].url == "http://127.0.0.1:9464/metrics"' <${stubJson} >/dev/null \
              || fail "absolute check URL was not passed through verbatim"
            jq -e '.services["pocket-id"].checks[0].timeout == 10' <${stubJson} >/dev/null \
              || fail "client.timeout not carried per check"
            jq -e '(.services["pocket-id"].checks[1] | has("timeout")) | not' <${stubJson} >/dev/null \
              || fail "timeout key emitted for a check without client.timeout"

            echo "integration-manifest-shape-selftest: contract pinned (union view, same-name merge, URL resolution, timeout, disabled-filter)" > $out
          '';
    };
}
