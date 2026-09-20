# storage-collector — long-term filesystem capacity tracking.
#
# A lightweight standalone daemon (Rust) that tracks every real mounted
# filesystem each cycle — capacity, usage, inodes — and appends a rotating
# JSONL record under /var/lib/storage-collector. This is the storage-trend
# data source that keeps working while monitor365 is disabled (see the
# monitor365.nix module for that blocker); the crate is built for later
# adoption as a monitor365 extracted collector.
#
# What it gives this fleet:
#   - /mnt/pool (16T btrfs DAS), /data, NVMe subvolumes, /tmp tmpfs —
#     growth history per mount instead of point-in-time df thresholds.
#   - Threshold events at warn% with hysteresis (default 85/80), so a
#     filesystem hovering at the boundary emits one event, not a flood.
#   - Removal debounce: a mount must be missing 3 consecutive cycles
#     before it is reported removed (absorbs statvfs flaps and USB DAS
#     re-enumeration windows).
#   - IO-domain gauges (PSI bp, disk in-flight, btrfs metadata fill,
#     zram fill) into the node_exporter textfile dir — the 2026-09-18/19
#     IO-audit observability surface.
#
# The service module (options: intervalSecs, warnPercent, clearPercent,
# removalCycles, textfile, skipFsTypes, trackFsTypes, maxFileMb,
# keepFiles, dataDir) lives in the storage-collector flake.
{
  inputs,
  ...
}:
{
  flake.nixosModules.storage-collector =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.storage-collector;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      inherit (import ../../../lib/default.nix lib)
        harden
        onFailure
        serviceOneshotDefaults
        ;
    in
    {
      imports = [ inputs.storage-collector.nixosModules.default ];

      config = lib.mkIf config.services.storage-collector.enable {
        services.storage-collector = {
          # 60 s cycles → ~525k telemetry lines/year per mount before
          # rotation; maxFileMb=10 with keepFiles=5 bounds disk use at
          # ~60 MiB regardless.
          intervalSecs = lib.mkDefault 60;
          dataDir = lib.mkDefault "/var/lib/storage-collector";
          # Gauge surface for Gatus/node_exporter (PSI bp, in-flight,
          # btrfs metadata fill, zram fill, health) — see the I/O Stall
          # Rate + Storage Collector Health checks in gatus-config.nix.
          textfile = lib.mkDefault "${textfileDir}/storage-collector.prom";
        };

        systemd.services.storage-collector.serviceConfig = {
          # Sticky-1777 textfile doctrine (mail-relay 2026-09-02..06 class:
          # 845+ failed runs, Gatus red 4 days): after a DynamicUser
          # restart the daemon's final rename lands on a foreign-owned
          # .prom — CAP_FOWNER is the house fix. The crate writes a
          # pid-unique tmp so the tmp itself never collides.
          AmbientCapabilities = [ "CAP_FOWNER" ];
          CapabilityBoundingSet = [ "CAP_FOWNER" ];
          # ProtectSystem=strict upstream: the textfile dir must be
          # writable next to the StateDirectory.
          ReadWritePaths = [ textfileDir ];
          # Upstream pins UMask=0077 (DynamicUser), so the crate's tmp+rename
          # lands a 0600 .prom that node_exporter cannot read
          # (node_textfile_scrape_error=1, storage metrics absent, 2026-09-20).
          # 0022 yields 0644 and self-heals on the next write cycle. The
          # durable fix is upstream (chmod the .prom, keep 0077 for dataDir).
          UMask = lib.mkForce "0022";
        };

        # Record integrity probe: verify parses the whole JSONL record and
        # exits non-zero on findings — the exit code IS the cron-facing
        # alerting primitive (same contract as `--once`), so a failed unit
        # routes through notify-failure@. Runs as root because the daemon's
        # DynamicUser is per-service and the StateDirectory files are 0600;
        # CAP_DAC_READ_SEARCH is the read-only door (no DAC_OVERRIDE).
        systemd.services.storage-collector-verify = {
          description = "storage-collector: verify the JSONL record (parse + integrity)";
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = "${lib.getExe cfg.package} verify --data-dir ${cfg.dataDir}";
              User = "root";
            }
            (harden {
              CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
            })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.storage-collector-verify = {
          description = "Hourly storage-collector record verification";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "hourly";
            Persistent = true;
            RandomizedDelaySec = "5m";
          };
        };
      };
    };
}
