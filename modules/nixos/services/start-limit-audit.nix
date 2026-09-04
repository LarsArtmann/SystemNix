# Eval-time assertion: StartLimitBurst/StartLimitIntervalSec must NEVER live in
# serviceConfig. systemd 261+ honors these directives ONLY in the [Unit]
# section — placed in [Service] they are silently ignored with a warning
# ("Unknown key 'StartLimitIntervalSec' in section [Service], ignoring"), so a
# Restart=on-failure service restarts INFINITELY with no rate limit while its
# author believes a limit exists.
#
# Correct placements (both map to [Unit]):
#   systemd.services.<name>.startLimitBurst = 5;         (NixOS top-level, camelCase)
#   systemd.services.<name>.startLimitIntervalSec = 300; (NixOS top-level, camelCase)
#   systemd.services.<name>.unitConfig.StartLimitBurst = 5;
#
# Bug class history: the 2026-08 systemd gotcha audit (service-defaults.nix
# lines 21-27 documents the rule). Zero violations existed then, but nothing
# PREVENTED one — this module is the eval-time guard. `nix flake check` and
# `nix eval ...config.system.build.toplevel` alone do NOT check assertions;
# only `nix flake check` (pre-commit + CI) forces them.
_: {
  flake.nixosModules.start-limit-audit =
    {
      config,
      lib,
      ...
    }:
    let
      # serviceConfig is a mix of typed (nullOr) options and freeform attrs:
      # `?` guards freeform absence, `!= null` guards typed-but-unset options.
      offenders = lib.filterAttrs (
        _name: svc:
        (svc.serviceConfig ? StartLimitBurst && svc.serviceConfig.StartLimitBurst != null)
        || (svc.serviceConfig ? StartLimitIntervalSec && svc.serviceConfig.StartLimitIntervalSec != null)
      ) config.systemd.services;
      offenderNames = lib.attrNames offenders;
    in
    {
      config.assertions = [
        {
          assertion = offenderNames == [ ];
          message = ''
            start-limit-audit: StartLimitBurst/StartLimitIntervalSec set in serviceConfig for:
            ${lib.concatStringsSep ", " offenderNames}
            systemd 261+ only honors these in [Unit] — in [Service] they are silently
            ignored and Restart=on-failure services restart infinitely with no limit.
            Fix (NixOS top-level options, outside serviceConfig):
              systemd.services.<name>.startLimitBurst = 5;
              systemd.services.<name>.startLimitIntervalSec = 300;
            or unitConfig.StartLimitBurst / unitConfig.StartLimitIntervalSec.
          '';
        }
      ];
    };
}
