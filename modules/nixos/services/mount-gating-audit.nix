# Eval-time audit: ReadWritePaths under /mnt/ WITHOUT mount gating
# (the 226/NAMESPACE + root-fs contamination class).
#
# systemd builds a unit's mount namespace BEFORE any ExecStartPre, so a
# ReadWritePaths entry pointing at a path that does not exist aborts the
# unit with status=226/NAMESPACE — an in-unit mkdir can NEVER fix it.
# Worse, when only a subdirectory is missing (pool mounted, dir never
# created), a root-fs SHADOW directory under the mountpoint silently
# absorbs the writes (cv-backup 2026-08-31: "no pipeline.sqlite" for 9
# days against a shadow copy; btrbk received the wrong tree). The
# sanctioned gating forms, all with live precedent in this repo:
#
#   - unitConfig.RequiresMountsFor = <path>  — fails LOUDLY on a detached
#     DAS (mkDockerService / cv-backup / bank-sync pattern). A descendant
#     entry gates every ancestor on the same mount and vice versa
#     (atticd-storage-dir uses the descendant form deliberately).
#   - ConditionPathIsMountPoint = <path>     — SKIPS cleanly when the
#     mount is absent (buildcache-gc pattern).
#
# ConditionPathIsDirectory does NOT count: a shadow dir under the
# mountpoint satisfies it (that is exactly the masking bug).
#
# Scope: /mnt/ only. /data is a fixed internal partition that mounts at
# boot or the system has far bigger problems — it has never been the
# incident class, and flagging it would force meaningless gating on
# every model dir under /data/ai.
#
# Assertions are forced by `nix flake check` (pre-commit + CI); a bare
# `nix eval ...toplevel.drvPath` does NOT check them.
{
  flake.nixosModules.mount-gating-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.mount-gating-audit;

      asList = v: if v == null then [ ] else lib.toList v;

      # Path-component-aware: "/mnt/pool" is an ancestor of
      # "/mnt/pool/backups/cv" but NOT of "/mnt/poolx".
      isAncestorOrEqual = ancestor: p: ancestor == p || lib.hasPrefix "${ancestor}/" p;

      # A RequiresMountsFor entry gates the mount containing it, so it
      # covers the entry itself, everything BELOW it, and every ancestor
      # on the same mount.
      rmfCovers = rmf: p: isAncestorOrEqual rmf p || lib.hasPrefix "${p}/" rmf;

      condCovers = cond: p: isAncestorOrEqual cond p;

      isMntPath = p: lib.hasPrefix "/mnt/" (toString p);

      offenders =
        let
          checked = lib.filterAttrs (_n: _v: !builtins.elem _n cfg.allowUnits) config.systemd.services;
          bad = lib.concatLists (
            lib.mapAttrsToList (
              name: svc:
              let
                sc = svc.serviceConfig or { };
                rmf = map toString (asList ((svc.unitConfig or { }).RequiresMountsFor or null));
                conds = map toString (
                  asList (sc.ConditionPathIsMountPoint or null)
                  ++ asList ((svc.unitConfig or { }).ConditionPathIsMountPoint or null)
                );
                mntPaths = builtins.filter isMntPath (map toString (asList (sc.ReadWritePaths or null)));
                ungated = builtins.filter (
                  p: !(builtins.any (r: rmfCovers r p) rmf || builtins.any (c: condCovers c p) conds)
                ) mntPaths;
              in
              map (p: "${name}: ${p}") ungated
            ) checked
          );
        in
        bad;
    in
    {
      options.services.mount-gating-audit = {
        allowUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Units exempt from the ReadWritePaths mount-gating audit. Every
            entry MUST carry a justification comment where it is set.
          '';
        };
      };

      config.assertions = [
        {
          assertion = offenders == [ ];
          message = ''
            mount-gating-audit: ReadWritePaths under /mnt/ without mount gating:
            ${lib.concatStringsSep "\n  " offenders}
            systemd builds the mount namespace BEFORE ExecStartPre — a missing
            path aborts with 226/NAMESPACE, and a root-fs shadow dir silently
            absorbs writes (cv-backup 2026-08-31). Gate the mount instead:
              unitConfig.RequiresMountsFor = [ "<path or mount root>" ];
            (fails loudly on a detached DAS) or
              serviceConfig.ConditionPathIsMountPoint = "<mount root>";
            (skips cleanly). ConditionPathIsDirectory does NOT count.
            Deliberate exception:
              services.mount-gating-audit.allowUnits = [ "<unit>" ];
            with a justification comment.
          '';
        }
      ];
    };
}
