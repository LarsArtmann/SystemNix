# Eval-time assertion: no unit may glob-delete /tmp/* inline without
# excluding systemd-private-*.
#
# Bug class history (2026-08-18 → 2026-08-30, 12 days):
# the tmp-cleanup timer globbed /tmp/* and rm -rf'd entries stale for >4h
# without excluding systemd-private-* — the PrivateTmp backing dirs of ~70
# services. Deleting the backing dir unlinks the bind-mount source, and every
# file creation inside the unit's private /tmp then returns ENOENT (the mount
# resolves to a disconnected dentry). Four services hit it:
#   forgejo 16,318 mirror-sync errors (all credentialed pull mirrors dead),
#   discordsync 550 attachment-download failures (self-healed via reconcile),
#   paperless-task-queue 5 celery pymp-* crashes,
#   immich-machine-learning 2 wgunicorn tempfile crashes.
# An idle or already-broken service writes nothing into its private tmp, so
# its backing dir ALWAYS profiles as stale — the failure is self-perpetuating
# (broken service → empty dir → looks stale → stays deleted). systemd's own
# tmpfiles-clean excludes these dirs; custom cleaners must too.
#
# This audit catches the INLINE variant of the mistake (rm + /tmp/* glob
# written directly into an Exec* or script option, where the text is visible
# at eval time). The deployed tmp-cleanup script itself is a store-path
# derivation (invisible here) — it is guarded by a dedicated self-assertion
# in platforms/nixos/system/scheduled-tasks.nix and behaviorally by
# tests/test-tmp-cleanup.nix. See AGENTS.md "NEVER let any /tmp cleaner
# touch systemd-private-*".
_: {
  flake.nixosModules.tmp-cleaner-audit =
    {
      lib,
      config,
      ...
    }:
    let
      # Every command-bearing string a unit can carry: the serviceConfig
      # exec hooks plus the NixOS convenience script options (which become
      # ExecStart/ExecStartPre at render time — script = "for f in /tmp/*..."
      # must be caught just like an inline ExecStart would).
      unitCommandStrings =
        unit:
        let
          flatten =
            v:
            if v == null then
              [ ]
            else if builtins.isList v then
              lib.concatMap flatten v
            else
              [ v ];
          scriptOptions = [
            (unit.script or null)
            (unit.preStart or null)
            (unit.postStart or null)
            (unit.preStop or null)
            (unit.postStop or null)
          ];
          execOptions = [
            (unit.serviceConfig.ExecStart or null)
            (unit.serviceConfig.ExecStartPre or null)
            (unit.serviceConfig.ExecStartPost or null)
            (unit.serviceConfig.ExecStop or null)
            (unit.serviceConfig.ExecStopPost or null)
          ];
        in
        lib.concatMap flatten (scriptOptions ++ execOptions);

      # The dangerous shape: a /tmp/* glob (top-level sweep) combined with
      # rm, and no systemd-private exclusion anywhere in the same string.
      # A store-path ExecStart contains no glob text and never matches.
      isOffender =
        s: lib.hasInfix "/tmp/*" s && lib.hasInfix "rm " s && !(lib.hasInfix "systemd-private" s);

      offenders = lib.concatLists (
        lib.mapAttrsToList (
          name: unit:
          map (s: {
            inherit name s;
          }) (builtins.filter isOffender (unitCommandStrings unit))
        ) config.systemd.services
      );

      offenderLines = map (o: "${o.name}: ${lib.strings.substring 0 160 o.s}") offenders;
    in
    {
      config.assertions = [
        {
          assertion = offenders == [ ];
          message = ''
            tmp-cleaner-audit: unit command(s) glob-delete /tmp/* without a
            systemd-private-* exclusion:
              ${lib.concatStringsSep "\n  " offenderLines}
            Deleting systemd-private-* backing dirs unlinks the PrivateTmp
            bind-mount source — every file creation inside the unit's private
            /tmp then fails ENOENT, and the failure is self-perpetuating
            (idle services never refresh their private tmp). 2026-08-18..30:
            forgejo mirrors dead 12 days (16,318 errors), discordsync
            attachment downloads, paperless celery, immich-ml all hit it.
            Skip systemd-private-* like systemd's own tmpfiles-clean does, or
            match only your OWN named temp prefix instead of /tmp/*.
          '';
        }
      ];
    };
}
