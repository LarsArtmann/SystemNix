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
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.services.storage-collector;
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      historyRepo = "/mnt/pool/backups/restic-storage-history";
      historyPasswordFile = "/var/lib/restic-storage-history/password";
      historyMarker = "${historyRepo}/.last_success";
      historyPasswordSetup = pkgs.writeShellApplication {
        name = "restic-storage-history-password-setup";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          # 44-char base64 password, 0600 (umask 077) — created once; the
          # repo at ${historyRepo} is only readable with it.
          if [ ! -s "${historyPasswordFile}" ]; then
            head -c 32 /dev/urandom | base64 > "${historyPasswordFile}"
          fi
        '';
      };
      inherit (import ../../../lib/default.nix lib)
        harden
        onFailure
        ioTier
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
          # The 2026-09-20 `UMask = mkForce "0022"` workaround is retired:
          # the crate now chmods the published .prom to 0644 explicitly
          # (umask-independent, regression-tested in textfile.rs), so the
          # upstream UMask=0077 stands — dataDir files stay 0600 while the
          # .prom stays scrapable. Deploy coupling: SystemNix flake.lock
          # must point at a storage-collector revision containing the
          # explicit-0644 textfile write (landed 2026-10-12) BEFORE this
          # deploys, else the .prom regresses to 0600 until the bump.
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

        # Indefinite history tier — nightly restic repo on the HDD pool.
        # The rotation bound is deliberately small (hot window only), so
        # THIS is the tier that keeps the trend record: no pruneOpts, the
        # repo grows forever (~13 GB/yr logical at the 60 s cadence, less
        # in-repo — restic dedupes the rotation's rename-shift to zero
        # extra cost and compresses the JSONL; pool has ~12 TiB). Targets
        # the REAL StateDirectory under private/ — restic does not follow
        # a symlinked target dir. Machine-local password (repo is
        # pool-local until the offsite Borg leg covers it) — same pattern
        # as restic-app-dumps.nix.
        services.restic.backups.storage-history = {
          passwordFile = historyPasswordFile;
          repository = historyRepo;
          initialize = true;
          paths = [
            (
              if lib.hasPrefix "/var/lib/" cfg.dataDir then
                "/var/lib/private/${lib.removePrefix "/var/lib/" cfg.dataDir}"
              else
                cfg.dataDir
            )
          ];
          extraBackupArgs = [
            "--tag"
            "storage-history"
          ];
          # After the 01:00-04:00 dump window, clear of the 05:15/05:45
          # restic-app-dumps slot. The rotation's newest file may still be
          # open — restic snapshots what exists and the next night's dedup
          # picks up the appended tail.
          timerConfig = {
            OnCalendar = "*-*-* 04:20:00";
            Persistent = true;
            RandomizedDelaySec = "10m";
          };
        };

        # One-time repo password bootstrap — re-run by deploy.sh's
        # provisioner loop (idempotent).
        systemd.services.restic-storage-history-setup = {
          description = "Ensure the restic storage-history repo password exists";
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            (harden { })
            {
              Type = "oneshot";
              RemainAfterExit = true;
              StateDirectory = "restic-storage-history";
              UMask = "0077";
              ExecStart = lib.getExe historyPasswordSetup;
            }
          ];
        };

        systemd.services."restic-backups-storage-history" = {
          description = "restic archive of the storage-collector history to the HDD pool";
          inherit onFailure;
          after = [ "restic-storage-history-setup.service" ];
          wants = [ "restic-storage-history-setup.service" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          serviceConfig = lib.mkMerge [
            ioTier.background
            {
              MemoryMax = "1G";
              TimeoutStartSec = "1h";
              # Freshness marker for backup-coordination — runs only when
              # the backup itself succeeded (no prune step by design).
              ExecStartPost = "${pkgs.coreutils}/bin/touch ${historyMarker}";
            }
          ];
        };

        # Registry fan-out: freshness row (backup-coordination metric +
        # the aggregate "All Backups Healthy" Gatus check). Pool-side
        # backup infra — layer "none".
        services.integration = lib.optionalAttrs (options ? services.integration) {
          storage-history = {
            vHost.layer = "none";
            backup = {
              directory = historyRepo;
              filePattern = ".last_success";
              maxAgeHours = 25;
            };
          };
        };
      };
    };
}
