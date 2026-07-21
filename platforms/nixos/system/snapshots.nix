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

  # Rust projects whose target/ dirs should live on ext4 (/rust-cache)
  # instead of BTRFS — avoids COW fragmentation from 85K+ small files
  # and keeps them out of btrbk snapshots.
  rustCacheProjects = [ "monitor365" ];

  rustCacheDirs = builtins.map (
    p: "d /rust-cache/${p} 0755 ${primaryUser} users -"
  ) rustCacheProjects;

  rustCacheLinks = builtins.map (
    p: "L+ /home/${primaryUser}/projects/${p}/target - - - - /rust-cache/${p}"
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
      onCalendar = "23:00";
      snapshotOnly = true;
      settings = {
        snapshot_preserve_min = "7d";
        snapshot_preserve = "14d 4w";
        volume."/mnt/btrfs-root" = {
          snapshot_dir = "/mnt/btrfs-root/.snapshots";
          subvolume."@" = { };
        };
      };
    };

    # /data is a separate BTRFS filesystem (subvolid=5, toplevel) containing
    # Docker volumes, Immich DB, AI models. Snapshots are crash-consistent.
    # The "." subvolume refers to the BTRFS toplevel. Nested subvolumes (like
    # .snapshots itself) are automatically excluded from snapshots by BTRFS.
    btrbk.instances."data" = {
      onCalendar = "23:30";
      snapshotOnly = true;
      settings = {
        snapshot_preserve_min = "7d";
        snapshot_preserve = "14d 4w";
        volume."/data" = {
          snapshot_dir = "/data/.snapshots";
          subvolume."." = { };
        };
      };
    };

    btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = [
        "/"
        "/data"
      ];
    };
  };

  systemd = {
    tmpfiles.rules =
      rustCacheDirs
      ++ rustCacheLinks
      ++ [
        # btrbk-data needs /data/.snapshots to exist before it can create
        # snapshot subvolumes. Without this, btrbk-data fails with
        # "Failed to fetch subvolume detail for snapshot_dir".
        "d /data/.snapshots 0755 root root -"
      ];

    services."btrfs-verify-snapshots" = {
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

    timers."btrfs-verify-snapshots" = {
      description = "Verify BTRFS snapshot freshness daily";
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
      wantedBy = [ "timers.target" ];
    };
  };
}
