# Eval-time audit: CAPABILITY-GRANT CONFUSION on non-root units.
#
# CapabilityBoundingSet only LIMITS which caps may exist; AmbientCapabilities
# is what actually GRANTS caps to a non-root User= unit. A bounding-set entry
# on a non-root unit without the matching ambient grant is dead weight — the
# service runs WITHOUT the cap its author intended to give it (root processes
# acquire bounding-set caps on their own, which is why root-run precedents
# mislead). Live incident: geometrikks 2026-09-29→10-07 ingested ZERO caddy
# events because its unit set CapabilityBoundingSet=CAP_DAC_READ_SEARCH with
# User=geometrikks and no AmbientCapabilities — EACCES on every log file,
# /health 200 the whole time (see docs/agents/systemd.md gotchas + the
# mail-relay.nix AmbientCapabilities precedent).
#
# Flagged shape: system service with a non-root User= (or DynamicUser) whose
# CapabilityBoundingSet lists DAC-class file-access caps
# (CAP_DAC_READ_SEARCH/CAP_DAC_OVERRIDE/CAP_FOWNER/CAP_CHOWN/CAP_FSETID)
# that AmbientCapabilities does not fully cover. Non-DAC caps are not
# flagged — the false-precedent history here is specifically the file-access
# class. Root/User-unset units are skipped: the bounding set DOES grant there.
#
# Deliberate no-grant exceptions (bounding entry kept purely as documentation
# or future root flip) go in services.capability-grant-audit.allow WITH a
# justification comment at the definition site.
#
# Assertions are forced by `nix flake check` (pre-commit + CI); a bare
# `nix eval ...toplevel.drvPath` does NOT check them.
{
  flake.nixosModules.capability-grant-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.capability-grant-audit;

      dacCaps = [
        "CAP_DAC_READ_SEARCH"
        "CAP_DAC_OVERRIDE"
        "CAP_FOWNER"
        "CAP_CHOWN"
        "CAP_FSETID"
      ];

      capList =
        v: lib.filter (s: s != "") (lib.concatMap (s: lib.splitString " " s) (lib.toList (toString v)));

      isNonRoot =
        svc:
        let
          user = svc.serviceConfig.User or null;
          dynamic = svc.serviceConfig.DynamicUser or false;
        in
        dynamic == true || (user != null && user != "root");

      ungrantedDacCaps =
        name: svc:
        let
          bound = capList (svc.serviceConfig.CapabilityBoundingSet or [ ]);
          ambient = capList (svc.serviceConfig.AmbientCapabilities or [ ]);
        in
        lib.filter (c: builtins.elem c dacCaps && !builtins.elem c ambient) bound;

      offenders =
        lib.mapAttrsToList
          (name: svc: {
            inherit name;
            caps = ungrantedDacCaps name svc;
          })
          (
            lib.filterAttrs (
              name: svc: isNonRoot svc && ungrantedDacCaps name svc != [ ] && !builtins.elem name cfg.allow
            ) config.systemd.services
          );
    in
    {
      options.services.capability-grant-audit = {
        allow = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Units whose ungranted DAC-class bounding entries are deliberate
            (bounding kept as documentation or for a future root flip).
            Every entry MUST carry a justification comment where it is set.
          '';
        };
      };

      config.assertions = [
        {
          assertion = offenders == [ ];
          message = ''
            capability-grant-audit: non-root unit(s) with DAC-class caps in
            CapabilityBoundingSet that AmbientCapabilities never grants:
            ${lib.concatStringsSep ", " (map (o: "${o.name} [${lib.concatStringsSep " " o.caps}]") offenders)}
            CapabilityBoundingSet only LIMITS which caps may exist — for a
            non-root User= unit only AmbientCapabilities GRANTS them (root
            processes acquire bounding-set caps on their own, which is why
            root-run precedents mislead). The ungranted caps are dead weight
            and the service hits EACCES where its author expected access
            (geometrikks 2026-09-29→10-07: zero ingested events, /health 200).
            Fix: set AmbientCapabilities to the same cap list, e.g.
              AmbientCapabilities = "CAP_DAC_READ_SEARCH";
            Deliberate no-grant exception:
              services.capability-grant-audit.allow = [ "<unit>" ];
            with a justification comment.
          '';
        }
      ];
    };
}
