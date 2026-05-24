{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (import ../../../lib/default.nix lib) harden onFailure;
  # Derive root BTRFS device from hardware-configuration.nix (single source of truth)
  rootDevice = config.fileSystems."/".device;
in {
  # BTRFS snapshot management
  #
  # Root (@ subvolume): btrbk — policy-based daily snapshots, auto-pruning
  # /data:              NOT snapshotted — mounted as BTRFS toplevel (subvolid=5)
  #                     See `just snapshot-migrate-data` to convert to @data subvolume
  #
  # Pre-deploy: `just switch` auto-snapshots root before every deploy

  # Mount BTRFS toplevel for root device (needed by btrbk for snapshot operations)
  # Uses automount — only mounted when accessed, unmounts after 10min idle
  fileSystems."/mnt/btrfs-root" = {
    device = rootDevice;
    fsType = "btrfs";
    options = ["noatime" "compress=zstd" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=10min"];
  };

  # btrbk: policy-based BTRFS snapshots for root (@) subvolume
  # Snapshots stored as /mnt/btrfs-root/.snapshots/@.YYYYMMDDTHHMMSS
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

  # Snapshot freshness verification — alerts if root snapshots are stale
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

      # Use filesystem modification time — immune to naming convention changes
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

  # BTRFS integrity scrub
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = ["/" "/data"];
  };
}
