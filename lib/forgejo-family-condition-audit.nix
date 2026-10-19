# Forgejo stateful-family condition audit (2026-10-19, freeze-18 §e.2 follow-up).
#
# The dedicated-subvolume generation gates every forgejo-state-consuming unit
# on the `.subvol-migrated` marker (scripts/migrate-forgejo-subvol.sh
# `finalize` touches it inside the subvol): a dedicated generation deployed
# BEFORE finalize must skip its family cleanly instead of running against an
# empty/stale subvol. The gate was historically copy-pasted per unit and the
# gitea-runner unit was missed — its `forgejo-gen-runner-token` ExecStartPre
# hammered the skipped forgejo every ~63 s across boots (freeze #18 collateral,
# fixed ad-hoc 2026-10-06). This scanner makes the family gate a construction
# rule: every unit named `forgejo*`/`gitea*` must carry the marker in
# unitConfig.ConditionPathExists unless it is explicitly exempted.
#
# Pure function so the lint-static selftest can fixture it without a NixOS
# eval; modules/nixos/services/forgejo-family-condition-audit.nix wires it to
# config.systemd.services at eval time.
#
# Args:
#   lib          — nixpkgs lib
#   units        — the config.systemd.services attrset (or any name→unit slice)
#   stateDir     — the forgejo state dir (services.forgejo.stateDir)
#   exemptUnits  — unit names deliberately ungated (each with a reason in the
#                  declaring module; additions must update that rationale)
{
  lib,
  units,
  stateDir,
  exemptUnits ? [ ],
}:
let
  marker = "${stateDir}/.subvol-migrated";

  isFamilyUnit =
    name:
    lib.hasPrefix "forgejo" name || lib.hasPrefix "gitea" name;

  # ConditionPathExists is option-merged to a list on real units, but
  # unitConfig is free-form attrsOf — tolerate a bare string too.
  conditionsOf =
    unit:
    let
      cond = (unit.unitConfig or { }).ConditionPathExists or [ ];
    in
    if lib.isList cond then cond else [ cond ];

  offenders = lib.sort (a: b: a < b) (
    lib.filter (name: !lib.elem name exemptUnits) (
      lib.attrNames (
        lib.filterAttrs (
          name: unit:
            isFamilyUnit name && !lib.elem marker (conditionsOf unit)
        ) units
      )
    )
  );
in
{
  inherit marker offenders;
}
