# Eval-time guard: a systemd unit carrying a startup gate (mkOidcGate /
# mkDnsGate / hand-rolled clones) MUST have a TimeoutStartSec that covers the
# gate's wait budget — or systemd kills the unit mid-gate and the failure
# looks like the service's own bug.
#
# Incident class (2026-08-31 boot 16:38): dnsblockd needs ~2min at boot to
# load its 3.9M-entry blocklist mapping. The OIDC gate's old 120s budget
# expired marginally → oauth2-proxy + gatus + browser-history failed into
# OnFailure Discord alerts on every slow boot, then self-healed 5s later.
# The same class existed for DNS gates: discordsync's hand-rolled 120s wait
# sat exactly against its own TimeoutStartSec=2min, and searxng's 3min was
# marginal against the (now) 180s mkDnsGate budget.
#
# Floors (budget + margin):
#   -wait-oidc (300s budget) → TimeoutStartSec ≥ 6min
#   -wait-dns  (180s budget) → TimeoutStartSec ≥ 4min
#
# Detection is by gate-script NAME in ExecStartPre ("<service>-wait-oidc" /
# "<service>-wait-dns" — the naming convention of lib/default.nix helpers and
# the discordsync clone). "infinity" passes. A missing/unparseable
# TimeoutStartSec fails the assertion — an explicit ceiling above the floor is
# required, deliberately NOT relying on the global DefaultTimeoutStartSec.
#
# Negative test (extendModules + force a violation, expect the assertion):
#   nix eval --impure --expr 'let f = builtins.getFlake (toString /home/lars/projects/SystemNix); in f.nixosConfigurations.evo-x2.extendModules { modules = [{ systemd.services.discordsync.serviceConfig.TimeoutStartSec = lib.mkForce "2min"; }]; }' \
#     --apply 'x: x.config.assertions'   # must contain the gate-timeout message
{
  flake.nixosModules.gate-timeout-audit =
    {
      config,
      lib,
      ...
    }:
    let
      floorOidcSec = 360;
      floorDnsSec = 240;

      unitSuffixes = {
        s = 1;
        sec = 1;
        seconds = 1;
        m = 60;
        min = 60;
        minutes = 60;
        h = 3600;
        hr = 3600;
        hours = 3600;
        d = 86400;
        days = 86400;
        w = 604800;
        weeks = 604800;
      };

      # "6min" | "300s" | "1min 30s" | "48h" → seconds; null if unparseable
      parseSystemdSeconds =
        value:
        if !lib.isString value then
          null
        else if lib.trim value == "infinity" then
          null
        else
          let
            tokens = builtins.filter (t: t != "") (lib.split "[[:space:]]+" (lib.trim value));
            parsed = map (tok: builtins.match "([0-9]+)([a-z]*)" tok) tokens;
            secondsOf =
              m:
              let
                n = lib.toIntBase10 (builtins.elemAt m 0);
                suffix = builtins.elemAt m 1;
              in
              if builtins.hasAttr suffix unitSuffixes then n * unitSuffixes.${suffix} else null;
            vals = map (m: if m == null then null else secondsOf m) parsed;
          in
          if parsed == [ ] || builtins.any (v: v == null) vals then null else lib.foldl' (a: b: a + b) 0 vals;

      # Effective TimeoutStartSec from serviceConfig (this repo's convention).
      # `or null` guards against the option being absent from a unit attrset.
      effectiveTimeout = svc: svc.serviceConfig.TimeoutStartSec or null;

      execStartPreStrings =
        svc:
        lib.filter lib.isString (
          lib.toList (svc.serviceConfig.ExecStartPre or null) ++ lib.toList (svc.serviceConfig.ExecStart or null)
        );

      hasWaitSuffix = svc: suffix: lib.any (e: lib.hasInfix suffix e) (execStartPreStrings svc);

      gateAudits =
        let
          gateUnits = lib.filterAttrs (
            name: svc:
            hasWaitSuffix svc "-wait-oidc" || hasWaitSuffix svc "-wait-dns"
          ) config.systemd.services;
        in
        lib.mapAttrsToList (
          name: svc:
          let
            isOidc = hasWaitSuffix svc "-wait-oidc";
            isDns = hasWaitSuffix svc "-wait-dns";
            floorSec =
              if isOidc then floorOidcSec else if isDns then floorDnsSec else 0;
            floorLabel =
              if isOidc then "6min (OIDC gate budget 300s)" else "4min (DNS gate budget 180s)";
            timeout = effectiveTimeout svc;
            seconds = parseSystemdSeconds timeout;
          in
          {
            assertion = seconds != null && seconds >= floorSec;
            message =
              "systemd.services.${name} has a startup gate (${if isOidc then "-wait-oidc" else "-wait-dns"}) but its TimeoutStartSec is "
              + "${if timeout == null then "not set" else "'${timeout}'"}"
              + " — must be ≥ ${floorLabel}, or systemd kills the unit mid-gate on slow boots (2026-08-31 class: dnsblockd needs ~2min at boot). See modules/nixos/services/gate-timeout-audit.nix";
          }
        ) gateUnits;
    in
    {
      config.assertions = gateAudits;
    };
}
