{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) harden onFailure;
  rootDevice = config.fileSystems."/".device;
  primaryUser = config.users.primaryUser;

  cacheSubvolumes = {
    "@cache-home" = "/home/${primaryUser}/.cache";
    "@go" = "/home/${primaryUser}/go";
    "@npm" = "/home/${primaryUser}/.npm";
    "@cargo" = "/home/${primaryUser}/.cargo";
  };

  cacheFileSystems = lib.mapAttrs' (subvol: mountPoint: {
    name = mountPoint;
    value = {
      device = rootDevice;
      fsType = "btrfs";
      options = [
        "subvol=${subvol}"
        "compress=zstd"
        "noatime"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
      ];
    };
  }) cacheSubvolumes;

  # Rust projects whose target/ dirs should live on ext4 — avoids COW
  # fragmentation from 85K+ small files and keeps them out of btrbk snapshots.
  # Target dirs moved from the old /rust-cache NVMe partition (p9) to the USB
  # SSD build cache (services.buildcache) on 2026-08-14: removes build churn
  # from the QLC NVMe entirely. Dirs are created by buildcache-init (post-
  # mount); only the ~/projects/<p>/target symlinks are managed here.
  rustCacheProjects = [ "monitor365" ];

  rustCacheLinks = builtins.map (
    p: "L+ /home/${primaryUser}/projects/${p}/target - - - - /mnt/buildcache/rust/${p}"
  ) rustCacheProjects;
in
{
  fileSystems = {
    "/mnt/btrfs-root" = {
      device = rootDevice;
      fsType = "btrfs";
      options = [
        "noatime"
        "compress=zstd"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=10min"
      ];
    };
  }
  // cacheFileSystems;

  services = {
    btrbk.instances."root" = {
      # Stagger BEFORE nix-gc (which fires at 00:00) so expired snapshots are
      # deleted first. This lets GC reclaim data extents freed by snapshot expiry.
      # If btrbk and GC ran concurrently, GC couldn't free CoW-shared extents.
      # See docs/crash-analysis-2026-06-26.md — the metadata ratchet section.
      #
      # snapshotOnly=false since 2026-08-16: each nightly snapshot is also
      # sent incrementally to the mirrored HDD pool (/mnt/pool/backups/root).
      # This closes the #1 data-loss risk: all snapshots used to live on the
      # single QLC NVMe that dies with the machine. Offsite leg is covered by
      # the user's Google Photos/Drive (see the 3-drive repurposing plan doc).
      onCalendar = "23:00";
      snapshotOnly = false;
      settings = {
        snapshot_preserve_min = "7d";
        snapshot_preserve = "14d 4w";
        # Received copies on the pool keep longer retention than the local
        # snapshots — the pool is the safety net, not scratch space.
        target_preserve_min = "7d";
        target_preserve = "30d 12w";
        volume."/mnt/btrfs-root" = {
          snapshot_dir = "/mnt/btrfs-root/.snapshots";
          subvolume."@" = {
            target = "/mnt/pool/backups/root";
          };
        };
      };
    };

    # /data is a separate BTRFS filesystem (subvolid=5, toplevel) containing
    # Docker volumes, Immich DB, AI models. Snapshots are crash-consistent.
    # The "." subvolume refers to the BTRFS toplevel. Nested subvolumes (like
    # .snapshots itself) are automatically excluded from snapshots by BTRFS.
    # Since 2026-08-16 snapshots are also sent to /mnt/pool/backups/data.
    btrbk.instances."data" = {
      onCalendar = "23:30";
      snapshotOnly = false;
      settings = {
        snapshot_preserve_min = "7d";
        snapshot_preserve = "14d 4w";
        target_preserve_min = "7d";
        target_preserve = "30d 12w";
        volume."/data" = {
          snapshot_dir = "/data/.snapshots";
          subvolume."." = {
            target = "/mnt/pool/backups/data";
          };
        };
      };
    };

    # Local snapshots of the per-service subvolumes ON the pool itself
    # (23:45, after the NVMe instances, before nix-gc at 00:00). Protects
    # against app-level corruption / accidental deletion on the pool:
    # immich media, paperless documents. The other service subvols
    # (monitor365, discordsync, browser-history) are laid out empty for the
    # planned NVMe->pool migrations and snapshot as no-ops until then.
    btrbk.instances."pool" = {
      onCalendar = "23:45";
      snapshotOnly = true;
      settings = {
        snapshot_preserve_min = "2d";
        snapshot_preserve = "7d 4w";
        volume."/mnt/pool" = {
          snapshot_dir = "/mnt/pool/.snapshots";
          subvolume."services/immich" = { };
          subvolume."services/paperless" = { };
          subvolume."services/monitor365" = { };
          subvolume."services/discordsync" = { };
          subvolume."services/browser-history" = { };
        };
      };
    };

    # Weekly instead of monthly: the scrub needs ~2h to complete 707 GiB on /data
    # at idle I/O priority. With frequent reboots (58 unsafe shutdowns), a monthly
    # scrub window almost never completes before the next reboot interrupts it.
    # Weekly gives 4x more retry opportunities. The nixpkgs module sets
    # Before=shutdown.target + Conflicts=shutdown.target, so scrub never blocks
    # shutdown — it just gets cancelled and retried next week.
    btrfs.autoScrub = {
      enable = true;
      interval = "weekly";
      fileSystems = [
        "/"
        "/data"
        # Mirrored HDD pool: scrub verifies BOTH raid1 copies match. Weekly is
        # cheap while the pool is near-empty; scrub time grows with usage.
        "/mnt/pool"
      ];
    };

    # Rust target dirs now live on the USB SSD build cache (see rustCacheLinks
    # above). buildcache-init creates the directories after the mount is up.
    buildcache.rustProjects = rustCacheProjects;
  };

  systemd = {
    tmpfiles.rules = rustCacheLinks ++ [
      # btrbk-data needs /data/.snapshots to exist before it can create
      # snapshot subvolumes. Without this, btrbk-data fails with
      # "Failed to fetch subvolume detail for snapshot_dir".
      "d /data/.snapshots 0755 root root -"
      # Pool-side receive targets + snapshot dir. The trailing "-" keeps
      # boot clean when the DAS is detached (nofail); btrbk then fails loudly
      # at 23:00 via RequiresMountsFor + onFailure instead.
      "d /mnt/pool/.snapshots 0755 root root -"
      "d /mnt/pool/backups/root 0755 root root -"
      "d /mnt/pool/backups/data 0755 root root -"
    ];

    services = {
      # btrbk units are Type=oneshot with the global 3min
      # DefaultTimeoutStartSec — far too short for the initial full send
      # (~0.7T root + ~0.9T /data over the USB DAS). Daily incrementals
      # finish in minutes; the ceiling only matters for seeds/repairs.
      btrbk-root = {
        unitConfig.RequiresMountsFor = [
          "/mnt/pool"
          "/mnt/btrfs-root"
        ];
        serviceConfig.TimeoutStartSec = "6h";
        inherit onFailure;
      };
      btrbk-data = {
        unitConfig.RequiresMountsFor = [
          "/mnt/pool"
          "/data"
        ];
        serviceConfig.TimeoutStartSec = "6h";
        inherit onFailure;
      };
      btrbk-pool = {
        unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
        serviceConfig.TimeoutStartSec = "1h";
        inherit onFailure;
      };

      # Fail-loud guard for the pool safety net: mount presence, raid1 mirror
      # health (a single dropped member keeps serving but halves redundancy),
      # and freshness of the received NVMe backups on both targets. A silently
      # broken send must alert, not linger as a phantom backup.
      "btrfs-verify-pool-backups" = {
        description = "Verify pool mount, mirror health, and backup freshness";
        inherit onFailure;
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.coreutils
        ];
        serviceConfig = lib.mkMerge [
          (harden {
            PrivateDevices = false; # btrfs ioctls go through the mount path
            ProtectSystem = "true";
          })
          { Type = "oneshot"; }
        ];
        script = ''
          set -euo pipefail
          MAX_AGE_DAYS=3

          findmnt -n /mnt/pool >/dev/null || { echo "FAIL: /mnt/pool is not mounted"; exit 1; }

          if btrfs device stats /mnt/pool | awk '$NF+0 > 0 {found=1} END {exit !found}'; then
            echo "FAIL: btrfs device stats report errors on the pool:"
            btrfs device stats /mnt/pool
            exit 1
          fi

          for dir in /mnt/pool/backups/root /mnt/pool/backups/data; do
            latest=$(find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -1)
            if [ -z "$latest" ]; then
              echo "FAIL: no received backups found in $dir"
              exit 1
            fi

            # Received subvols keep the snapshot name: @.YYYYMMDDTHHMM /
            # data.YYYYMMDDTHHMM. Parse the date from the NAME (see
            # btrfs-verify-snapshots for why stat mtime lies here).
            name=$(basename "$latest")
            datestr="''${name##*.}"
            datestr="''${datestr%%T*}"
            if [ ''${#datestr} -ne 8 ]; then
              echo "FAIL: could not parse date from backup name: $name"
              exit 1
            fi
            snap_epoch=$(date -d "''${datestr:0:4}-''${datestr:4:2}-''${datestr:6:2}" +%s)
            age_days=$(( ($(date +%s) - snap_epoch) / 86400 ))
            if [ "$age_days" -gt "$MAX_AGE_DAYS" ]; then
              echo "FAIL: newest backup in $dir is $age_days days old (threshold: $MAX_AGE_DAYS)"
              exit 1
            fi
            echo "OK: $dir newest backup is $age_days day(s) old"
          done
        '';
      };

      "btrfs-verify-snapshots" = {
        description = "Verify BTRFS snapshot freshness";
        inherit onFailure;
        path = [ pkgs.coreutils ];
        serviceConfig = lib.mkMerge [
          (harden { })
          {
            Type = "oneshot";
            ProtectSystem = "true";
            ReadWritePaths = [ ];
          }
        ];
        script = ''
          set -euo pipefail
          MAX_AGE_DAYS=3

          SNAP_DIR="/mnt/btrfs-root/.snapshots"
          if [ ! -d "$SNAP_DIR" ]; then
            echo "WARNING: No snapshots directory ($SNAP_DIR)"
            exit 1
          fi

          LATEST=$(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@.*' | sort | tail -1)
          if [ -z "$LATEST" ]; then
            echo "WARNING: No root snapshots found"
            exit 1
          fi

          # Parse the snapshot creation date from the NAME, not from stat.
          # BTRFS snapshots inherit the source subvolume's root directory mtime,
          # so stat -c %Y returns the SOURCE mtime (e.g. Jun 26 when the root
          # dir was last changed), not when the snapshot was taken. This caused
          # false "24 days old" alerts despite daily snapshots being fresh.
          # btrbk names snapshots as @.YYYYMMDDTHHMM.
          SNAP_NAME=$(basename "$LATEST")
          SNAP_DATESTR="''${SNAP_NAME#@.}"
          SNAP_DATESTR="''${SNAP_DATESTR%%T*}"
          if [ ''${#SNAP_DATESTR} -ne 8 ]; then
            echo "WARNING: Could not parse date from snapshot name: $SNAP_NAME"
            exit 1
          fi
          SNAP_EPOCH=$(date -d "''${SNAP_DATESTR:0:4}-''${SNAP_DATESTR:4:2}-''${SNAP_DATESTR:6:2}" +%s)
          NOW_EPOCH=$(date +%s)
          AGE_DAYS=$(( (NOW_EPOCH - SNAP_EPOCH) / 86400 ))

          if [ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ]; then
            echo "WARNING: Root snapshot is $AGE_DAYS days old (threshold: $MAX_AGE_DAYS)"
            exit 1
          fi

          echo "OK: Root snapshot is $AGE_DAYS day(s) old"
        '';
      };
    };

    timers."btrfs-verify-snapshots" = {
      description = "Verify BTRFS snapshot freshness daily";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      wantedBy = [ "timers.target" ];
    };

    timers."btrfs-verify-pool-backups" = {
      description = "Verify pool safety net daily";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
