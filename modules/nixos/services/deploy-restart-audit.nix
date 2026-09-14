# Eval-time audit: CONVERGER ONESHOTS must be deploy-restartable.
#
# switch-to-configuration NEVER restarts a Type=oneshot + RemainAfterExit
# unit in response to restartTriggers — the deploy.sh provisioner loop /
# dedicated restart blocks are the ONLY mechanisms that re-run provisioning
# fixes (bank-sync-storage-dir sat failed for 6 deploys 2026-08-19 before
# being added; dnsblockd-oidc-secret caused a full SSO outage 2026-08-22
# because the INDIRECTLY-enabled bridge is invisible to the loop's
# is-enabled gate). This guard cross-references the unit tree against the
# deploy.sh text so a new converger can never ship without deploy handling.
#
# Candidates (must appear by NAME somewhere in scripts/deploy.sh):
#   - any Type=oneshot unit whose name matches a converger pattern
#     (-storage-dir / -backup-dir / -dirs / -provision / -setup /
#      -bootstrap / -oidc-secret / -oidc-env / -migrate)
#   - any oneshot + RemainAfterExit unit carrying restartTriggers
#     (inert by construction — the exact trap)
#
# Upstream nixpkgs plumbing that matches a pattern but is converged by its
# own module/timer lives in the default allowUnits (justified below).
# Assertions are forced by `nix flake check` (pre-commit + CI).
{
  flake.nixosModules.deploy-restart-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.deploy-restart-audit;

      deploySh = builtins.readFile ../../../scripts/deploy.sh;

      convergerPatterns = [
        ".*-storage-dir$"
        ".*-backup-dir$"
        ".*-dirs$"
        ".*-provision$"
        ".*-setup$"
        ".*-bootstrap$"
        ".*-oidc-secret$"
        ".*-oidc-env$"
        ".*-migrate$"
      ];

      offenders =
        let
          bad =
            lib.filterAttrs (
              name: svc:
              !builtins.elem name cfg.allowUnits
              && !lib.hasInfix name deploySh
              && (
                (
                  (svc.serviceConfig.Type or null) == "oneshot"
                  && builtins.any (p: builtins.match p name != null) convergerPatterns
                )
                || (
                  (svc.serviceConfig.Type or null) == "oneshot"
                  && (svc.serviceConfig.RemainAfterExit or false) == true
                  && (builtins.length (svc.restartTriggers or [ ])) > 0
                )
              )
            ) config.systemd.services;
        in
        lib.attrNames bad;
    in
    {
      options.services.deploy-restart-audit = {
        allowUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          # Upstream nixpkgs plumbing that matches a converger pattern but
          # is converged by its own module mechanics (activation scripts,
          # service restarts, timers) and must never be deploy-restarted:
          # - postfix-setup:   rendered maps regenerate via the postfix module
          # - postgresql-setup: instance bootstrap owned by the pg module
          # - systemd-tmpfiles-resetup: pulled by tmpfiles lifecycle itself
          # - resolvconf: default-enabled upstream oneshot whose
          #   restartTriggers inertia is an nixpkgs quirk, not ours (its
          #   config regenerates via its own activation path; evo-x2 uses a
          #   static resolv.conf and never even has the unit)
          default = [
            "postfix-setup"
            "postgresql-setup"
            "systemd-tmpfiles-resetup"
            "resolvconf"
          ];
          description = ''
            Units exempt from the deploy-restart requirement. Entries beyond
            the upstream defaults MUST carry a justification comment where
            they are set.
          '';
        };
      };

      config.assertions = [
        {
          assertion = offenders == [ ];
          message = ''
            deploy-restart-audit: converger oneshot(s) missing from scripts/deploy.sh:
            ${lib.concatStringsSep ", " offenders}
            switch-to-configuration NEVER restarts a oneshot+RemainAfterExit unit
            (restartTriggers are inert on them) — a deployed provisioning fix
            silently never re-runs (bank-sync-storage-dir 2026-08-19,
            dnsblockd-oidc-secret 2026-08-22). Fix: add the unit to the
            provisioner restart loop in scripts/deploy.sh — or, if it is only
            INDIRECTLY enabled (wantedBy=<service>), a dedicated is-active-gated
            restart block (dnsblockd-oidc-secret / cv-oidc-env pattern), because
            the loop's `systemctl is-enabled` gate skips indirect units. If a
            restartTriggers list is the offender, DELETE it — it is dead config.
            Deliberate exception:
              services.deploy-restart-audit.allowUnits = [ "<unit>" ];
            with a justification comment.
          '';
        }
      ];
    };
}
