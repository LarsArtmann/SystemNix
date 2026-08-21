{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib) harden onFailure serviceOneshotDefaults;
  rootDevice = config.fileSystems."/".device;
  primaryUser = config.users.primaryUser;

  # Only @cache-home remains as a cache subvolume. The other three
  # (@go, @npm, @cargo) were removed 2026-08-17: their contents moved to
  # /mnt/buildcache (GOMODCACHE, npm_config_cache) or were stale, and plain
  # ~/go / ~/.npm dirs inside @ hold nothing churning. @cache-home stays
  # because it still carries ~16 GB of LIVE app caches that have no
  # buildcache home (nix flake eval cache 6G, browser caches, gopls…) —
  # its snapshot-exclusion from btrbk's @ snapshots is exactly its job.
  # Deleting it would push all that churn into daily @ snapshots + pool
  # sends. Revisit only if those caches get their own off-NVMe home.
  cacheSubvolumes = {
    "@cache-home" = "/home/${primaryUser}/.cache";
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
        # LOCAL retention ~1/4 of the old policy (was 14d 4w, user decision
        # 2026-08-21): snapshots pin deleted extents on the space-tight QLC
        # NVMe; local tier only needs rollback + incremental-send-parent duty.
        # The pool (below) is the real history tier.
        snapshot_preserve_min = "2d";
        snapshot_preserve = "3d 1w";
        # Pool = FOREVER (user decision 2026-08-21): target_preserve_min = "all"
        # disables automatic deletion of received backups entirely. Space cost
        # stays near raw data churn — received subvolumes share extents via CoW
        # on the pool (snapshot count is ~free; every DELETED byte on the NVMe
        # is pinned pool-side forever, which is the point). 16T RAID1 headroom
        # makes this viable for years; revisit only if pool usage crosses ~50%.
        target_preserve_min = "all";
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
    # immich media, paperless documents, atticd NAR storage, monitor365
    # buffer. monitor365 + atticd were populated by the 2026-08-18
    # data-to-pool-migration; discordsync + browser-history remain laid out
    # empty for their planned NVMe->pool migrations and snapshot as no-ops
    # until then.
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
          subvolume."services/atticd" = { };
          subvolume."services/monitor365" = { };
          subvolume."services/discordsync" = { };
          subvolume."services/browser-history" = { };
          subvolume."services/bank-sync" = { };
          subvolume."services/activitywatch" = { };
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
      # DefaultTimeoutStartSec — far too short for send phases. Observed
      # 2026-08-17: the initial catch-up seed sustained only ~17 MB/s
      # effective through the USB DAS (metadata-heavy nix store + concurrent
      # weekly scrubs) — 6h covered just ~60% of the root send before
      # TimeoutStartSec killed it mid-stream. 24h covers seeds; daily
      # incrementals finish in minutes and never approach the ceiling.
      # Nightly runs are also naturally serialized: a still-active run makes
      # the timer fire skip (systemd does not restart a running oneshot).
      btrbk-root = {
        unitConfig.RequiresMountsFor = [
          "/mnt/pool"
          "/mnt/btrfs-root"
        ];
        serviceConfig.TimeoutStartSec = "24h";
        inherit onFailure;
      };
      btrbk-data = {
        unitConfig.RequiresMountsFor = [
          "/mnt/pool"
          "/data"
        ];
        serviceConfig.TimeoutStartSec = "24h";
        inherit onFailure;
      };
      btrbk-pool = {
        unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
        serviceConfig.TimeoutStartSec = "1h";
        inherit onFailure;
      };

      # Mirrored-pool Prometheus metrics (mount presence with real-I/O gate,
      # usage, free/total). Same always-write-the-.prom contract as
      # buildcache-metrics: a detached DAS flips pool_mounted to 0 and Gatus
      # alerts instead of serving a stale green file. df on an unmounted
      # /mnt/pool would report the ROOT filesystem's numbers — the mounted
      # gate must run before any usage math.
      pool-metrics = {
        description = "Mirrored HDD pool Prometheus metrics";
        startLimitBurst = 3;
        startLimitIntervalSec = 300;
        path = [
          pkgs.util-linux
          pkgs.coreutils
          pkgs.gnugrep
        ];
        inherit onFailure;
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            User = "root";
          }
          (harden {
            ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
            MemoryMax = "128M";
          })
          (serviceOneshotDefaults { })
        ];
        script = ''
          set -eu
          OUT="/var/lib/prometheus-node-exporter/textfile_collectors/pool.prom"
          TMP="''${OUT}.tmp"
          mnt="/mnt/pool"
          threshold=85

          mounted=0
          if
            findmnt -n -o TARGET "$mnt" 2>/dev/null | grep -qx "$mnt" \
              && timeout 15 ls -A "$mnt" >/dev/null 2>&1
          then
            mounted=1
          fi

          usage=0
          over=0
          free_bytes=0
          total_bytes=0
          if [ "$mounted" = 1 ]; then
            usage="$(df --output=pcent "$mnt" | tail -n1 | tr -dc '0-9')"
            free_bytes="$(df -B1 --output=avail "$mnt" | tail -n1 | tr -dc '0-9')"
            total_bytes="$(df -B1 --output=size "$mnt" | tail -n1 | tr -dc '0-9')"
            if [ "''${usage:-0}" -ge "$threshold" ] 2>/dev/null; then
              over=1
            fi
          fi

          mkdir -p "/var/lib/prometheus-node-exporter/textfile_collectors"
          cat > "$TMP" <<METRICS
          # HELP pool_mounted 1 if the mirrored HDD pool is mounted, 0 otherwise
          # TYPE pool_mounted gauge
          pool_mounted ''${mounted}
          # HELP pool_usage_percent Pool filesystem usage percentage (0-100)
          # TYPE pool_usage_percent gauge
          pool_usage_percent ''${usage}
          # HELP pool_usage_over_threshold 1 if usage >= 85%
          # TYPE pool_usage_over_threshold gauge
          pool_usage_over_threshold ''${over}
          # HELP pool_free_bytes Free bytes on the pool filesystem
          # TYPE pool_free_bytes gauge
          pool_free_bytes ''${free_bytes}
          # HELP pool_total_bytes Total bytes on the pool filesystem
          # TYPE pool_total_bytes gauge
          pool_total_bytes ''${total_bytes}
          METRICS
          mv "$TMP" "$OUT"
        '';
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
          pkgs.findutils
          # gawk is REQUIRED by the mirror-health check below. Without it the
          # `if btrfs device stats | awk …` condition evaluates false on
          # "command not found" (pipefail inside `if` is non-fatal) and the
          # check silently passes — a phantom green observed live 2026-08-18
          # ("awk: command not found" in the unit journal while the unit
          # reported the device-stats branch as clean).
          pkgs.gawk
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

    timers.pool-metrics = {
      description = "Collect mirrored pool metrics every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        Persistent = true;
      };
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
