# Pin for the geometrikks capability grant on the evo-x2 render (pure eval,
# no VM; 2026-10-07 zero-ingestion incident).
#
# geometrikks ingested ZERO caddy events 2026-09-29→10-07 because its unit
# carried CapabilityBoundingSet without AmbientCapabilities — a bounding set
# only LIMITS; AmbientCapabilities is what GRANTS a cap to a non-root User=
# unit (root acquires bounding-set caps on its own, which is why root-run
# precedents mislead). Verified by manual nix eval at fix time only — this
# check makes the grant a tested invariant so a refactor cannot silently
# drop either half.
#
# The capability-grant-audit leg also pins the AUDIT WIRING: the module must
# contribute its assertion to the evo-x2 config (eval-time class sweep for
# future non-root units).
{
  pkgs,
  inputs,
}:
let
  lib = inputs.nixpkgs.lib;

  evox2 = inputs.self.nixosConfigurations.evo-x2.config;
  sc = evox2.systemd.services.geometrikks.serviceConfig;

  auditWired = builtins.any (
    a: lib.hasInfix "capability-grant-audit" (a.message or "")
  ) evox2.assertions;

  cases = [
    {
      name = "ambient-cap-grant-vanished";
      pass = sc.AmbientCapabilities or "" == "CAP_DAC_READ_SEARCH";
    }
    {
      name = "bounding-set-no-longer-restricts-to-the-grant";
      pass = sc.CapabilityBoundingSet or "" == "CAP_DAC_READ_SEARCH";
    }
    {
      name = "unit-no-longer-non-root";
      pass = sc.User or "" == "geometrikks";
    }
    {
      name = "nonewprivileges-dropped-ambient-would-not-survive-exec";
      pass = (sc.NoNewPrivileges or false) == true;
    }
    {
      name = "capability-grant-audit-not-imported-into-evo-x2";
      pass = auditWired;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "geometrikks-caps-render-test" { } "touch $out"
else
  pkgs.runCommand "geometrikks-caps-render-test" { } ''
    echo "geometrikks capability render test FAILED for: ${lib.concatStringsSep ", " broken}"
    exit 1
  ''
