# One-time data migration: /data → mirrored HDD pool (/mnt/pool)
#
# Moves three NVMe /data trees onto the pool (2026-08-18):
#   /data/atticd             → /mnt/pool/services/atticd             (live subvol, btrbk-pool snapshotted)
#   /data/monitor365         → /mnt/pool/services/monitor365         (subvol reserved at 2026-08-16 pool bring-up; service disabled since 2026-08-12)
#   /data/monitor365-archive → /mnt/pool/archive/monitor365-archive  (cold archive tier: RAID1 redundancy only, NOT snapshotted by btrbk-pool)
#
# Why a systemd unit instead of a manual root shell: agent sessions have no
# sudo/systemctl access. deploy.sh starts this unit post-switch (--no-block)
# so the migration runs with deploy-time privileges. Idempotent and
# ConditionPathExists-gated: once all three sources are gone the unit skips
# instantly on every later deploy/boot.
#
# Safety model per source: rsync -aHAX (numeric owners preserved —
# /data/monitor365 is uid 966:956 from the disabled-service era) → checksum
# dry-run must report ZERO differences → only then rm -rf the source. rm (not
# trash) is deliberate: trashing ~63 GB would copy it onto the NVMe home
# partition this migration exists to free (same reasoning as buildcache-gc).
# Old copies stay recoverable from the nightly /data btrbk snapshots (14d
# local, 30d+12w pool-side) while they age out.
_: {
  flake.nixosModules.data-to-pool-migration =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.data-to-pool-migration;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        ;
    in
    {
      options.services.data-to-pool-migration = {
        enable = lib.mkEnableOption "one-time /data → HDD pool migration (atticd, monitor365, monitor365-archive)";
      };

      config = lib.mkIf cfg.enable {
        systemd.services.data-to-pool-migration = {
          description = "One-time migration: /data/{atticd,monitor365,monitor365-archive} → /mnt/pool";
          # OR-prefixed conditions: the unit runs while ANY source remains and
          # skips cleanly (condition failed) once all are migrated.
          unitConfig = {
            ConditionPathExists = [
              "|/data/atticd"
              "|/data/monitor365"
              "|/data/monitor365-archive"
            ];
            RequiresMountsFor = [
              "/mnt/pool"
              "/data"
            ];
          };
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          path = with pkgs; [
            rsync
            btrfs-progs
            coreutils
            gnugrep
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              # ~63 GB over the shared USB DAS link, worst case including the
              # checksum verification re-read of both sides.
              TimeoutStartSec = "4h";
            }
            (harden {
              MemoryMax = "512M";
              # btrfs subvolume create needs CAP_SYS_ADMIN; rsync -a preserving
              # foreign numeric owners (uid 966 / lars) needs CAP_CHOWN +
              # CAP_DAC_OVERRIDE + CAP_FOWNER, and reading the 0750 uid-966
              # source tree needs CAP_DAC_READ_SEARCH (harden defaults to an
              # empty bounding set — first run shipped CAP_SYS_ADMIN only and
              # every chown failed with EPERM; the checksum verify caught it
              # and kept the sources).
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH";
              ReadWritePaths = [
                "/data"
                "/mnt/pool"
              ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
          script = ''
            set -u
            failures=0

            migrate() {
              local src="$1" dest="$2"
              if [ ! -e "$src" ]; then
                echo "data-to-pool-migration: skip (already migrated): $src"
                return 0
              fi
              echo "data-to-pool-migration: copying $src → $dest"
              mkdir -p "$dest"
              if ! rsync -aHAX --info=stats1 "$src"/ "$dest"/; then
                echo "data-to-pool-migration: COPY FAILED: $src (source kept)"
                failures=1
                return 0
              fi
              # Verify: checksum every file on both sides; the itemized dry-run
              # must produce zero output. Anything else keeps the source.
              local diff=""
              if ! diff=$(rsync -aHAXn -c -i "$src"/ "$dest"/); then
                echo "data-to-pool-migration: VERIFY COMMAND FAILED: $src (source kept)"
                failures=1
                return 0
              fi
              if [ -n "$diff" ]; then
                echo "data-to-pool-migration: VERIFY DIFF FAILED: $src (source kept)"
                printf '%s\n' "$diff" | head -20
                failures=1
                return 0
              fi
              # Carry the source top-dir ownership/permissions onto the dest
              # root (numeric: keeps the stale monitor365 uid 966:956 intact).
              chown --reference="$src" "$dest"
              chmod --reference="$src" "$dest"
              echo "data-to-pool-migration: verified identical ($(du -sh "$src" | cut -f1)): $src"
              rm -rf -- "$src"
              echo "data-to-pool-migration: source removed: $src"
            }

            # 1. Live-service subvol for atticd storage (flip happens in a
            #    follow-up deploy that repoints services.attic-config.storagePath).
            if ! btrfs subvolume show /mnt/pool/services/atticd >/dev/null 2>&1; then
              echo "data-to-pool-migration: creating subvolume /mnt/pool/services/atticd"
              btrfs subvolume create /mnt/pool/services/atticd
            fi

            # 2. The data moves. Archive first (largest, irreplaceable DuckDB),
            #    then the empty attic tree, then the monitor365 buffer.
            mkdir -p /mnt/pool/archive
            migrate /data/monitor365-archive /mnt/pool/archive/monitor365-archive
            migrate /data/atticd /mnt/pool/services/atticd
            migrate /data/monitor365 /mnt/pool/services/monitor365

            # 3. Provenance sidecar for the archive copy (house rule: every
            #    archive gets one at creation time).
            if [ -d /mnt/pool/archive/monitor365-archive ] && [ ! -e /mnt/pool/archive/monitor365-archive/README-migration.md ]; then
              printf '%s\n' \
                "# monitor365 archive — migrated from /data/monitor365-archive" \
                "" \
                "Migrated $(date -Is) by data-to-pool-migration.service on evo-x2." \
                "Reason: /data (NVMe) repurposing — cold archive moves to the RAID1 HDD pool." \
                "Contents: monitor365-events.db (28G live DuckDB at disable time 2026-08-02)," \
                "TSV exports and compressed DBs. Service disabled since 2026-08-12." \
                "Method: rsync -aHAX as root; rsync -c checksum dry-run verified zero" \
                "differences before the source was deleted." \
                "Tier note: archive/ is NOT snapshotted by btrbk-pool — RAID1 is the" \
                "only redundancy for this copy (cold data; nightly /data snapshots on" \
                "the pool keep older copies until their retention expires)." \
                > /mnt/pool/archive/monitor365-archive/README-migration.md
              echo "data-to-pool-migration: wrote provenance README"
            fi

            if [ "$failures" -ne 0 ]; then
              echo "data-to-pool-migration: FAILED — at least one source was not migrated; source dirs kept"
              exit 1
            fi
            echo "data-to-pool-migration: complete — all sources migrated, verified and removed"
          '';
        };
      };
    };
}
