# crush-hot-db — relocate per-project crush session DBs off the QLC root.
#
# The 2026-09-14 boot IO storm (TODO_LIST P1): `~/projects/**/.crush/crush.db`
# (2-5 GB each + WALs, 5+ concurrent sessions) churns seeky SQLite on the QLC
# `@` subvolume, pinning io PSI some avg60 at 40-60% for hours while memory
# stays pristine — the exact memory-emergency-guard Zone 6 signature, which
# then cycles flm and force-gates deploys. This module moves each project's
# `.crush/` directory onto the Samsung TLC NVMe (`/mnt/hot`, see
# hardware-configuration.nix) and leaves a symlink in its place, so every
# future session write lands on the fast disk.
#
# Convergence: `crush-hot-db-migrate` runs from a daily timer AND from
# deploy.sh's provisioner loop (deploy-restart-audit enforces the latter).
# A project is skipped while a crush session is live (relocating the
# directory under a running writer would strand it on an unlinked inode)
# or while its DB was written in the last 10 minutes; the next run
# converges it.
{
  flake.nixosModules.crush-hot-db =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        ioTier
        ;
      cfg = config.services.crush-hot-db;
      primaryUser = config.users.primaryUser or "lars";
    in
    {
      options.services.crush-hot-db = {
        enable = lib.mkEnableOption "relocate per-project crush session DBs to the hot-DB disk";
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/hot";
          description = "Hot-DB disk mount point (Samsung TLC NVMe, by-label tlc).";
        };
        projectsDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/projects";
          defaultText = lib.literalExpression ''"/home/${primaryUser}/projects"'';
          description = "Directory whose immediate children carry `.crush/` session dirs.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.crush-hot-db-migrate = {
          description = "Relocate per-project crush session DBs to the hot-DB disk";
          unitConfig.RequiresMountsFor = [ cfg.mountPoint ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            (harden {
              # chown for the hot-DB dir, CAP_FOWNER/CAP_DAC_OVERRIDE for the
              # rename over the project's dir + symlink swap (harden{}'s empty
              # bounding set would EPERM both — tq-storage-dir precedent).
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
              ReadWritePaths = [
                "${cfg.mountPoint}/crush"
                cfg.projectsDir
              ];
            })
            # ~20 GB of QLC reads + SQLite churn — never contend with the
            # interactive tiers that motivated the move.
            ioTier.background
            (serviceOneshotDefaults { })
          ];
          script = ''
            projects=${cfg.projectsDir}
            dest=${cfg.mountPoint}/crush

            # Single-flight: the daily timer and a deploy can overlap.
            if ! exec 9>/run/crush-hot-db-migrate.lock; then
              echo "skip: cannot open lock file" >&2
              exit 0
            fi
            if ! flock -n 9; then
              echo "skip: another migration run holds the lock"
              exit 0
            fi

            # Never relocate a directory out from under a live session:
            # the writer would keep writing to the moved-away inode.
            if pgrep -x crush >/dev/null; then
              echo "skip: crush session(s) active ($(pgrep -xc crush)) — next run converges"
              exit 0
            fi

            mkdir -p "$dest"
            chown ${primaryUser}:users "$dest"

            migrated=0
            for d in "$projects/.crush" "$projects"/*/.crush; do
              # -d follows symlinks: an already-migrated project matches and is
              # skipped; the -L guard is belt-and-suspenders for the literal
              # glob when nothing matches (nullglob-off shell).
              if [ ! -d "$d" ] || [ -L "$d" ]; then
                continue
              fi
              name="''${d#"$projects"/}"
              name="''${name%/.crush}"
              if [ "$name" = ".crush" ]; then
                name="projects-root"
              fi
              target="$dest/$name"

              # Fresh writes = a session may have JUST ended (or about to
              # checkpoint) — leave it one more cycle.
              if [ -n "$(find "$d" -maxdepth 1 -name 'crush.db*' -mmin -10 -print -quit)" ]; then
                echo "skip $name: crush.db written in the last 10 minutes"
                continue
              fi
              if [ -e "$target" ]; then
                echo "skip $name: target $target already exists (manual merge needed)"
                continue
              fi
              if mv "$d" "$target" && ln -s "$target" "$d"; then
                echo "migrated $name → $target"
                migrated=$((migrated + 1))
              else
                echo "FAILED to migrate $name" >&2
              fi
            done
            echo "crush-hot-db: $migrated project(s) relocated"
          '';
        };

        systemd.timers.crush-hot-db-migrate = {
          description = "Periodically converge per-project crush DBs onto the hot-DB disk";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            # Quiet window; Persistent catches up missed boots.
            OnCalendar = "*-*-* 04:10:00";
            Persistent = true;
          };
        };
      };
    };
}
