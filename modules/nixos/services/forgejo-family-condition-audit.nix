# Eval-time assertion: every forgejo*/gitea* stateful unit in the
# dedicated-subvolume generation condition-gates on the .subvol-migrated
# marker — by construction, not copy-paste.
#
# Freeze #18 collateral class (docs/status/2026-10-06_16-02_* §e.2): the
# subvol gate was pasted per unit and gitea-runner's token-gen ExecStartPre
# was missed — it hammered the marker-skipped forgejo every ~63 s across
# boots (fail-loop). The ad-hoc 2026-10-06 fix closed that one unit; this
# audit closes the CLASS: any family unit without the marker condition (or
# without an explicit, reasoned exemption below) fails `nix flake check`.
#
# Exemption = a deliberate claim that the unit never consumes forgejo STATE
# (the DB/config inside the subvol). Adding a family unit: either carry
# `unitConfig.ConditionPathExists = [ "<stateDir>/.subvol-migrated" ]`
# (with RequiresMountsFor on the stateDir, per the family pattern in
# forgejo.nix) or justify an exemptUnits entry here. A rename that orphaned
# an exemption fails eval — prune it.
_: {
  flake.nixosModules.forgejo-family-condition-audit =
    {
      lib,
      config,
      options,
      ...
    }:
    let
      cfg = config.services.forgejo-family-condition-audit;
      # Standalone-eval safe (VM tests may import this module alone): the
      # option-presence guard tolerates a missing forgejo module instead of
      # assuming it (the browser-history:256 brick class).
      dedicated =
        options ? services.forgejo.dedicatedSubvolume && config.services.forgejo.dedicatedSubvolume;
      stateDir =
        if options ? services.forgejo.stateDir then
          config.services.forgejo.stateDir
        else
          "/var/lib/forgejo";
      audit = import ../../../lib/forgejo-family-condition-audit.nix;
      result = audit {
        inherit lib stateDir;
        units = config.systemd.services;
        exemptUnits = cfg.exemptUnits;
      };
    in
    {
      options.services.forgejo-family-condition-audit = {
        exemptUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            # Creates the subvol the marker lives in — must run BEFORE
            # finalize can ever touch the marker (mkIf dedicated).
            "forgejo-subvol-bootstrap"
            # Report-only backup-freshness probe over btrbk snapshot state;
            # designed to never fail on marker absence (the 2026-10-08
            # chronic-FAIL doctrine in scheduled-tasks.nix).
            "forgejo-subvol-backup-metrics"
            # btrbk receive-target cleanup on pool/hot — not a forgejo-state
            # consumer.
            "btrbk-forgejo-clean"
            # Restore-side drill (dump zip + received-subvol copies), not the
            # live state.
            "forgejo-restore-drill"
            # On-demand templates (manual systemctl start, no timer): a
            # skipped forgejo fails them once with OnFailure routing — no
            # fail-loop cadence; pure API/git surface, never stateDir.
            "forgejo-flip@"
            "forgejo-flip-check@"
            # Report-only API + reconcile-state readers (never-fail doctrine).
            "forgejo-mirror-health"
            "forgejo-census"
          ];
          description = ''
            forgejo*/gitea* systemd services deliberately exempt from the
            .subvol-migrated condition gate. Every entry claims the unit
            never consumes forgejo state inside the dedicated subvol — the
            reason lives in the default-value comments of
            modules/nixos/services/forgejo-family-condition-audit.nix.
          '';
        };
      };

      config.assertions = lib.optionals dedicated [
        {
          assertion = result.offenders == [ ];
          message = ''
            forgejo-family-condition-audit: forgejo*/gitea* unit(s) in the
            dedicated-subvolume generation without the .subvol-migrated
            condition gate: ${lib.concatStringsSep ", " result.offenders}

            A dedicated generation deployed before `finalize` must skip its
            stateful family cleanly (marker absent → ConditionPathExists
            fails → unit never runs) instead of hammering or corrupting an
            empty/stale subvol — the gitea-runner ~63 s fail-loop of
            freeze #18. Fix: on each unit add
              unitConfig.ConditionPathExists = [ "${result.marker}" ];
            (plus RequiresMountsFor on "${stateDir}", matching the family
            pattern in forgejo.nix), or — only if the unit provably never
            consumes forgejo state — add it to
            services.forgejo-family-condition-audit.exemptUnits with a
            reason comment.
          '';
        }
      ];
    };
}
