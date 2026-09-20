# crush-hot-db — relocate per-project crush session DBs off the QLC root.
#
# The 2026-09-14 boot IO storm (docs/todo/storage.md): `~/projects/**/.crush/crush.db`
# (2-5 GB each + WALs, 5+ concurrent sessions) churns seeky SQLite on the QLC
# `@` subvolume, pinning io PSI some avg60 at 40-60% for hours while memory
# stays pristine — the exact memory-emergency-guard Zone 6 signature, which
# then cycles flm and force-gates deploys. This module moves each project's
# `.crush/` directory onto the Samsung TLC NVMe (`/mnt/hot`, see
# hardware-configuration.nix) and leaves a symlink in its place, so every
# future session write lands on the fast disk.
#
# Convergence: `crush-hot-db-migrate` is ENABLED (wantedBy
# multi-user.target — a static unit would silently skip deploy.sh's
# is-enabled-gated provisioner loop, the dnsblockd-bridge trap class) and
# runs at boot, from a daily timer, AND from deploy.sh's provisioner loop
# (deploy-restart-audit enforces the latter).
# A project is skipped while a crush session is LIVE ON THAT PROJECT
# (a comm=crush process holding an fd/cwd under its `.crush` — relocating
# the directory under a running writer would strand it on an unlinked
# inode) or while its DB was written in the last 10 minutes; the next run
# converges it. The guard is per-PROJECT (2026-09-21): the old blanket
# `pgrep -x crush` skip starved convergence on this box — 16-21 sessions
# are always live, so legal-cases/.crush sat unmigrated for 13 days after
# the freeze-interrupted first run. Failures exit non-zero (OnFailure +
# system-health see them); `CRUSH_HOT_DB_DRY_RUN=1` rehearses a run.
{
  flake.nixosModules.crush-hot-db =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        ioTier
        onFailure
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
          description = "Directory tree scanned for `.crush/` session dirs (any checkout down to depth 3, e.g. `<dir>/group/repo`).";
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
        systemd.services.crush-hot-db-migrate = {
          description = "Relocate per-project crush session DBs to the hot-DB disk";
          # Enabled, not static: deploy.sh's provisioner loop gates on
          # `systemctl is-enabled` (rc=1 for static units) — without this the
          # deploy-time restart silently never happens (dnsblockd-bridge trap).
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ cfg.mountPoint ];
          # List EVERY binary the script execs: the default unit PATH
          # (coreutils/findutils/gnugrep/gnused/systemd) has NO flock
          # (util-linux) — the awk phantom-binary class
          # (btrfs-verify-pool-backups 2026-08-18 lesson). pgrep is GONE:
          # the liveness guard reads /proc comm + fd links directly
          # (procps no longer needed).
          path = [
            pkgs.coreutils
            pkgs.findutils
            pkgs.util-linux
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              # tq-storage-dir shape: stays "active (exited)" so the deploy.sh
              # restart semantics apply (stc never restarts it on change).
              RemainAfterExit = true;
            }
            (harden {
              # chown for the hot-DB dir, CAP_FOWNER/CAP_DAC_OVERRIDE for the
              # rename over the project's dir + symlink swap (harden{}'s empty
              # bounding set would EPERM both — tq-storage-dir precedent).
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
              # MUST override harden{}'s ProtectHome default (`true`): systemd
              # maps yes/true to INACCESSIBLE-AND-EMPTY (/home becomes an empty
              # tmpfs inside the unit), so `find ~/projects` ENOENTs every run
              # (0 relocated, exit 0 — the phantom-green shape). Only a booting
              # unit exposes it (VM test regression 3); transient replicas that
              # probe with read-only pass and hide it.
              ProtectHome = "read-only";
              # The MOUNT ROOT — never the ${mountPoint}/crush subdir:
              # ReadWritePaths paths must exist BEFORE the unit starts
              # (systemd builds the mount namespace before any ExecStart;
              # a missing entry aborts 226/NAMESPACE and the script's own
              # mkdir can never create it — mount-gating-audit class).
              # RequiresMountsFor below guarantees the root exists; the
              # script's mkdir -p creates the subdir inside it.
              ReadWritePaths = [
                cfg.mountPoint
                cfg.projectsDir
              ];
            })
            # ~20 GB of QLC reads + SQLite churn — never contend with the
            # interactive tiers that motivated the move.
            ioTier.background
            (serviceOneshotDefaults { })
          ];
          # Row 58: a per-dir migration failure must PAGE, not log-and-exit-0.
          inherit onFailure;
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

            # Bounded-depth find covers NESTED checkouts too
            # ($projects/<group>/<repo>/.crush — archived/*, games/* — 35
            # nested dirs the old top-level-only glob left on the QLC root).
            # -prune: never descend into a matched .crush (session DBs are
            # huge; nothing nests inside a session dir). -type d does not
            # match the already-migrated symlinks. NUL-delimited mapfile:
            # checkout names may contain spaces.
            mapfile -d "" -t crushDirs < <(
              find "$projects" -mindepth 1 -maxdepth 3 -type d -name .crush -prune -print0 | sort -z
            )

            migrated=0
            for d in "''${crushDirs[@]}"; do
              # -d follows symlinks: an already-migrated project matches and is
              # skipped; the -L guard is belt-and-suspenders for a race between
              # find and the loop.
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
              # Nested names carry slashes (group/repo): the parent hierarchy
              # must exist before mv (root-owned intermediates stay traversable).
              parent="$(dirname "$target")"
              if [ ! -d "$parent" ]; then
                mkdir -p "$parent"
                chown ${primaryUser}:users "$parent"
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
