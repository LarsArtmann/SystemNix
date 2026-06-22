{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (import ../../../lib/default.nix lib) harden onFailure;
  rootDevice = config.fileSystems."/".device;
  primaryUser = config.users.primaryUser;

  cacheSubvolumes = {
    "@cache-home" = "/home/${primaryUser}/.cache";
    "@go" = "/home/${primaryUser}/go";
    "@npm" = "/home/${primaryUser}/.npm";
    "@cargo" = "/home/${primaryUser}/.cargo";
  };

  cacheFileSystems =
    lib.mapAttrs' (subvol: mountPoint: {
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
    })
    cacheSubvolumes;

  # Rust projects whose target/ dirs should live on ext4 (/rust-cache)
  # instead of BTRFS — avoids COW fragmentation from 85K+ small files
  # and keeps them out of btrbk snapshots.
  rustCacheProjects = ["monitor365"];

  rustCacheDirs = builtins.map
    (p: "d /rust-cache/${p} 0755 ${primaryUser} users -")
    rustCacheProjects;

  rustCacheLinks = builtins.map
    (p: "L+ /home/${primaryUser}/projects/${p}/target - - - - /rust-cache/${p}")
    rustCacheProjects;
in {
  fileSystems =
    {
      "/mnt/btrfs-root" = {
        device = rootDevice;
        fsType = "btrfs";
        options = ["noatime" "compress=zstd" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=10min"];
      };
    }
    // cacheFileSystems;

  systemd.tmpfiles.rules = rustCacheDirs ++ rustCacheLinks;

  services.btrbk.instances."root" = {
    onCalendar = "daily";
    snapshotOnly = true;
    settings = {
      snapshot_preserve_min = "7d";
      snapshot_preserve = "14d 4w";
      volume."/mnt/btrfs-root" = {
        snapshot_dir = "/mnt/btrfs-root/.snapshots";
        subvolume."@" = {};
      };
    };
  };

  systemd.services."btrfs-verify-snapshots" = {
    description = "Verify BTRFS snapshot freshness";
    inherit onFailure;
    path = [pkgs.coreutils];
    serviceConfig =
      harden {}
      // {
        Type = "oneshot";
        ProtectSystem = "true";
        ReadWritePaths = [];
      };
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

      SNAP_EPOCH=$(stat -c %Y "$LATEST" 2>/dev/null || echo 0)
      NOW_EPOCH=$(date +%s)
      AGE_DAYS=$(( (NOW_EPOCH - SNAP_EPOCH) / 86400 ))

      if [ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ]; then
        echo "WARNING: Root snapshot is $AGE_DAYS days old (threshold: $MAX_AGE_DAYS)"
        exit 1
      fi

      echo "OK: Root snapshot is $AGE_DAYS day(s) old"
    '';
  };

  systemd.timers."btrfs-verify-snapshots" = {
    description = "Verify BTRFS snapshot freshness daily";
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    wantedBy = ["timers.target"];
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = ["/" "/data"];
  };
}
