# Eval-time drift guard (2026-10-25 caddy edge plan M14, finding 1 of the
# deep dive): the metrics global option MUST keep per_host. Without it every
# caddy_* series is edge-aggregate — the dashboard's by-host panels and the
# per-host 5xx alert silently render/evaluate EMPTY (no error anywhere), so
# a refactor that drops the line must fail eval instead of regressing the
# edge's observability. Negative-tested in scripts/negative-test-lints.sh
# group `caddy` (mutation comments the line out inside the Caddyfile string).
_: {
  flake.nixosModules.caddy-perhost-drift-audit =
    {
      config,
      lib,
      ...
    }:
    let
      # Exact-line match (trimmed): a bare hasInfix "per_host" is VACUOUS —
      # the directive's explanatory comment contains the same substring, so
      # stripping the directive while keeping the comment would pass. The
      # harness's drift mutation relies on this distinction.
      perHostDirectivePresent = lib.any (l: lib.strings.trim l == "per_host") (
        lib.splitString "\n" (config.services.caddy.globalConfig or "")
      );
    in
    {
      config.assertions = [
        {
          assertion = !(config.services.caddy.enable or false) || perHostDirectivePresent;
          message = ''
            caddy-perhost-drift-audit: services.caddy.globalConfig lost `per_host`.
            Without it all caddy_* metrics are edge-aggregate: the SigNoz caddy
            dashboard's by-host panels and the "Caddy Per-Host 5xx Rate High"
            alert go silently empty (they key on the host label that per_host
            adds; finding 1 of docs/research/2026-10-25_caddy-deep-dive.html).
            Restore the metrics block in modules/nixos/services/caddy.nix:
              metrics {
                per_host
              }
          '';
        }
      ];
    };
}
