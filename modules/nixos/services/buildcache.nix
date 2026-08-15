# Build cache SSD — SanDisk SDSSDA240G on USB 3.0 (SandForce SF-2000, DRAM-less).
#
# Purpose: keep rebuildable build caches (Go build/module cache, golangci-lint,
# goimports, Rust target dirs, npm/pnpm, pip, Playwright browsers) OFF the QLC
# NVMe. The NVMe's SLC cache exhaustion incidents (2026-08-12 WDT crashes, 93%
# disk crisis) were driven by exactly this ephemeral churn. Cache data is
# disposable: if the 10-year-old drive dies, everything rebuilds.
#
# Why ext4 + data=writeback: build caches are small-file, stat-heavy workloads
# where ext4 measured 2x lower random latency than btrfs on this drive (234us
# vs 503us). data=writeback removes the ordered-mode journal double-write
# (136 -> ~280 MB/s sequential). Corruption risk from writeback + no PLP +
# 34 dirty shutdowns is acceptable: every consumer verifies content hashes
# (go-build) or rebuilds on anomaly (cargo clean, pnpm store prune). See
# docs/status/2026-08-14_12-30_ssd-recovery-benchmarking-session.md for the
# benchmark and architecture analysis.
#
# TRIM does NOT pass through the USB bridge (lsblk -D reports DISC-MAX 0B).
# If write performance degrades over months from stale-block pressure, the fix
# is a reformat — the drive is a cache:
#   mkfs.ext4 -L buildcache /dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1
#
# Migration of existing caches: `nix run .#migrate-buildcache` (run BEFORE the
# first deploy of this module — it creates dirs the deploy expects, and moves
# ~/.cache/goimports + ~/.cache/go aside so home-manager symlinks cleanly).
{
  flake.nixosModules.buildcache =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        mkFilesystem
        harden
        ioTier
        serviceOneshotDefaults
        onFailure
        ;

      cfg = config.services.buildcache;

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      primaryUser = config.users.primaryUser;
      homeDir = config.users.users.${primaryUser}.home;

      buildcacheDirs = [
        "go-build"
        "go-mod"
        "golangci-lint"
        "goimports"
        "go"
        "npm"
        "pip"
        "pnpm-store"
        "playwright"
        "rust"
        "sccache"
      ];

      rustProjectDirs = map (project: "rust/${project}") cfg.rustProjects;
    in
    {
      options.services.buildcache = {
        enable = lib.mkEnableOption "USB SSD build cache at /mnt/buildcache (keeps build caches off the QLC NVMe)";

        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/buildcache";
          description = "Mount point for the build cache ext4 filesystem.";
        };

        device = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1";
          description = ''
            Partition device. by-id (ata- serial form) is stable across sdb/sdc
            letter swaps between the two USB-attached SSDs; the kernel creates it
            via SAT passthrough even though the USB bridge hides the model at the
            plain SCSI layer.
          '';
        };

        wholeDiskDevice = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311";
          description = "Whole-disk device for SMART queries (smartctl -d sat).";
        };

        rustProjects = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Rust project names that get a target/ dir symlinked from
            ~/projects/<name>/target into the cache (see snapshots.nix — same
            pattern the old /rust-cache NVMe partition used, minus COW).
          '';
        };

        usageThresholdPercent = lib.mkOption {
          type = lib.types.int;
          default = 85;
          description = "Usage percentage at which the Gatus alert fires (240 GB drive; caches should be pruned before full).";
        };

        gc = {
          enable = lib.mkEnableOption "weekly build cache garbage collection (npm/pnpm prune, stale rust targets, high-watermark go clean)";

          maxAgeDays = lib.mkOption {
            type = lib.types.int;
            default = 14;
            description = ''
              Rust target/ dirs under <mountPoint>/rust untouched for this many
              days are deleted. Safe with sccache: a deleted target dir rebuilds
              from sccache hits without re-invoking rustc for dependencies.
            '';
          };

          highWatermarkPercent = lib.mkOption {
            type = lib.types.int;
            default = 90;
            description = ''
              If usage is at or above this percentage after the regular pruning
              steps, the nuclear option runs: go clean -cache. Rationale: Go's
              native 5-day LRU trim is defeated by gopls refreshing mtimes
              (markUsed), so an unbounded go-build is the one cache that CAN
              wedge the disk — a cold rebuild is always preferable to a full
              disk failing all builds.
            '';
          };

          calendar = lib.mkOption {
            type = lib.types.str;
            default = "Sun *-*-* 05:00:00";
            description = "OnCalendar for the GC timer (default: Sunday 05:00 — after btrbk 23:00/23:30, before Monday BTRFS balances, idle I/O tier).";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # nofail: a dead/absent USB drive must never block boot. automount: mount
        # on first access rather than at boot, tolerating late DAS power-up.
        # device-timeout bounds the wait if the enclosure is unplugged.
        fileSystems.${cfg.mountPoint} = mkFilesystem {
          inherit (cfg) device;
          fsType = "ext4";
          options = [
            "noatime"
            "lazytime"
            "data=writeback"
            "commit=120"
            "nofail"
            "x-systemd.automount"
            "x-systemd.device-timeout=10s"
          ];
        };

        # Runs on EVERY boot, deliberately: mkdir/chown/chmod are idempotent,
        # and an init-once `.initialized` gate (removed 2026-08-15) made any
        # newly-added buildcacheDirs entry inert — the sccache dir had to be
        # provisioned by hand after the drive was already initialized.
        systemd.services.buildcache-init = {
          description = "Initialize build cache directories on the USB SSD";
          wantedBy = [ "multi-user.target" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          unitConfig = {
            # With x-systemd.automount the mount happens on first ACCESS;
            # RequiresMountsFor + ExecStart touching the path trigger it.
            RequiresMountsFor = cfg.mountPoint;
            # Guard against root-fs contamination: if the automount unit is dead
            # and the drive absent, mkdir would create dirs on the NVMe root.
            # While the automount is active the path IS a mountpoint (autofs),
            # and a blocked trigger fails the mkdir instead of falling through.
            ConditionPathIsMountPoint = cfg.mountPoint;
          };
          path = [
            pkgs.coreutils
            pkgs.util-linux
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            # Root oneshot doing ownership ops: overrides REPLACE harden's empty
            # default (which drops all capabilities). CAP_CHOWN for chown(2),
            # CAP_FOWNER/CAP_DAC_OVERRIDE for chmod/traversal on re-init.
            (harden {
              ReadWritePaths = [ cfg.mountPoint ];
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
              MemoryMax = "64M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            for dir in ${lib.concatStringsSep " " (buildcacheDirs ++ rustProjectDirs)}; do
              mkdir -p "${cfg.mountPoint}/$dir"
              chown ${primaryUser}:users "${cfg.mountPoint}/$dir"
              chmod 0755 "${cfg.mountPoint}/$dir"
            done
            echo "buildcache initialized at ${cfg.mountPoint}"
          '';
        };

        # Always writes the .prom file — including when the drive is absent — so a
        # dead/unmounted drive flips buildcache_mounted to 0 and Gatus alerts,
        # instead of silently serving a stale green file.
        systemd.services.buildcache-metrics = {
          description = "Build cache SSD Prometheus metrics (mount, usage, SMART)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          path = [
            pkgs.smartmontools
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
              ReadWritePaths = [ textfileDir ];
              CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_SYS_RAWIO";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            OUT="${textfileDir}/buildcache.prom"
            TMP="''${OUT}.tmp"
            mnt="${cfg.mountPoint}"
            dev="${cfg.wholeDiskDevice}"
            threshold=${toString cfg.usageThresholdPercent}

            mounted=0
            if findmnt -n -o TARGET "$mnt" 2>/dev/null | grep -qx "$mnt"; then
              mounted=1
            fi

            smart_healthy=0
            if smartctl -d sat -H "$dev" 2>/dev/null | grep -q "PASSED"; then
              smart_healthy=1
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

            mkdir -p "${textfileDir}"
            cat > "$TMP" <<METRICS
            # HELP buildcache_mounted 1 if the build cache SSD is mounted, 0 otherwise
            # TYPE buildcache_mounted gauge
            buildcache_mounted ''${mounted}
            # HELP buildcache_smart_healthy 1 if SMART overall-health self-assessment is PASSED
            # TYPE buildcache_smart_healthy gauge
            buildcache_smart_healthy ''${smart_healthy}
            # HELP buildcache_usage_percent Build cache filesystem usage percentage (0-100)
            # TYPE buildcache_usage_percent gauge
            buildcache_usage_percent ''${usage}
            # HELP buildcache_usage_over_threshold 1 if usage >= ${toString cfg.usageThresholdPercent}%
            # TYPE buildcache_usage_over_threshold gauge
            buildcache_usage_over_threshold ''${over}
            # HELP buildcache_free_bytes Free bytes on the build cache filesystem
            # TYPE buildcache_free_bytes gauge
            buildcache_free_bytes ''${free_bytes}
            # HELP buildcache_total_bytes Total bytes on the build cache filesystem
            # TYPE buildcache_total_bytes gauge
            buildcache_total_bytes ''${total_bytes}
            METRICS
            mv "$TMP" "$OUT"
          '';
        };

        systemd.timers.buildcache-metrics = {
          description = "Collect build cache SSD metrics every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
            Persistent = true;
          };
        };

        # Weekly cache GC. Runs as the primary user (all cache dirs are
        # user-owned). rm on stale rust targets instead of trash is deliberate:
        # trashing 30G of rebuildable cache would write it to the NVMe trash —
        # the exact I/O this SSD exists to keep OFF the NVMe. Cache data only,
        # never user data; paths are anchored under the mount point.
        systemd.services.buildcache-gc = lib.mkIf cfg.gc.enable {
          description = "Build cache garbage collection (npm/pnpm prune, stale rust targets, high-watermark go clean)";
          startLimitBurst = 3;
          startLimitIntervalSec = 300;
          unitConfig = {
            RequiresMountsFor = cfg.mountPoint;
            ConditionPathIsMountPoint = cfg.mountPoint;
          };
          environment = {
            GOCACHE = "${cfg.mountPoint}/go-build";
            npm_config_cache = "${cfg.mountPoint}/npm";
          };
          path = [
            pkgs.go
            pkgs.nodejs
            pkgs.pnpm
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnused
          ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              # 45min: `go clean -cache` at high-watermark scale (100G+ of
              # small files) and rust-target rm -rf are metadata-bound on a
              # DRAM-less USB SSD — 20min was too tight to survive the exact
              # scenario the watermark guard exists for.
              TimeoutStartSec = "45min";
            }
            (harden {
              # pnpm store prune updates its state dir (~/.cache/pnpm: dlx +
              # project registries, verified live 2026-08-15) — without this
              # hole prune fails under read-only home every week.
              ProtectHome = "read-only";
              ReadWritePaths = [
                cfg.mountPoint
                "${homeDir}/.cache/pnpm"
              ];
              MemoryMax = "512M";
            })
            ioTier.maintenance
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            mnt="${cfg.mountPoint}"
            max_age=${toString cfg.gc.maxAgeDays}
            watermark=${toString cfg.gc.highWatermarkPercent}

            usage() {
              df --output=pcent "$mnt" | tail -n1 | tr -dc '0-9'
            }

            echo "buildcache-gc: start at $(usage)% usage"

            # 1. npm: verify garbage-collects corrupt/old tarballs
            npm cache verify || echo "buildcache-gc: npm cache verify failed (non-fatal)"

            # 2. pnpm: remove packages no longer referenced by any project
            pnpm store prune || echo "buildcache-gc: pnpm store prune failed (non-fatal)"

            # 3. Stale rust target dirs — cheap to lose with sccache
            find "$mnt/rust" -mindepth 1 -maxdepth 1 -type d -mtime "+$max_age" -print -exec rm -rf -- {} + || true

            # 4. High watermark: go-build is the only unbounded cache (gopls
            #    mtime refresh defeats Go's 5-day LRU trim). Cold it if needed.
            pct=$(usage)
            if [ -z "''${pct:-}" ]; then
              echo "buildcache-gc: usage unavailable — mount vanished mid-run?" >&2
              exit 1
            fi
            echo "buildcache-gc: after pruning at ''${pct}% usage"
            if [ "$pct" -ge "$watermark" ]; then
              echo "buildcache-gc: usage >= $watermark% — running go clean -cache (cold rebuild is better than a full disk)"
              go clean -cache
              echo "buildcache-gc: post-clean usage: $(usage)%"
            fi

            echo "buildcache-gc: done"
          '';
        };

        systemd.timers.buildcache-gc = lib.mkIf cfg.gc.enable {
          description = "Weekly build cache garbage collection";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.gc.calendar;
            Persistent = true;
            Unit = "buildcache-gc.service";
          };
        };
      };
    };
}
