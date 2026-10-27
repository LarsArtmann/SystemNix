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
      # Emit-then-sweep crash-orphan pre-start (monitoring.md:127): every
      # `.state.json.*.tmp` under the data dir is the residue of a writer
      # that died mid-atomic-rename — a free crash-count signal. The count
      # is recorded durably (journal lines + a dedicated textfile gauge)
      # BEFORE the sweep deletes the evidence. Journal lines age out under
      # vacuum pressure; the gauge survives until the next daemon start
      # rewrites it.
      crashOrphanSweep = pkgs.writeShellApplication {
        name = "storage-collector-crash-orphan-sweep";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          dataDir="${cfg.dataDir}"
          promFile="${textfileDir}/storage-collector-crash-orphans.prom"

          mapfile -t orphans < <(find "$dataDir" -maxdepth 1 -name '.state.json.*.tmp' -print)
          count=''${#orphans[@]}

          if (( count > 0 )); then
            echo "storage-collector: $count crash-orphaned state tmp file(s) found (writer died mid-atomic-rename):"
            printf '  %s\n' "''${orphans[@]}"
          fi

          # Explicit 0644: the unit's UMask=0077 stands (crate-side
          # doctrine) and node_exporter must be able to read the gauge.
          # mktemp + trap per audit-textfile-tmp.sh class A: a fixed tmp
          # name can collide with a foreign-owned leftover in the sticky
          # 1777 dir (CAP_FOWNER on the unit covers the final rename).
          tmp="$(mktemp "${textfileDir}/storage-collector-crash-orphans.prom.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          {
            echo "# HELP storage_collector_crash_orphans_total Crash-orphaned .state.json tmp files found at daemon start (emit-then-sweep)"
            echo "# TYPE storage_collector_crash_orphans_total gauge"
            # NO trailing timestamp: node_exporter's textfile collector
            # rejects client-side timestamps ("contains unsupported
            # client-side timestamps, skipping entire file") — the whole
            # file was being dropped, setting node_textfile_scrape_error=1
            # on every scrape (live 2026-10-25, F18).
            printf 'storage_collector_crash_orphans_total %d\n' "$count"
          } > "$tmp"
          chmod 0644 "$tmp"
          mv -f "$tmp" "$promFile"
          trap - EXIT

          find "$dataDir" -maxdepth 1 -name '.state.json.*.tmp' -delete
          echo "storage-collector: crash-orphan sweep complete ($count removed, gauge emitted)"
        '';
      };
      inherit (import ../../../lib/default.nix lib)
        harden
        onFailure
        ioTier
        serviceOneshotDefaults
        ;
      scanInterval = "5m";
      # Freshness sidecar (S25): staleness detector for the daemon's textfile
      # gauges. Reads storage_collector_last_write_unix_secs from the
      # daemon's own .prom and republishes storage_collector_fresh 1|0 —
      # stale means older than 10 daemon cycles (600 s at intervalSecs=60).
      freshnessScript = pkgs.writeShellApplication {
        name = "storage-collector-freshness";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          set -euo pipefail
          PROM="${textfileDir}/storage-collector.prom"
          NOW="$(date +%s)"
          STALE_AFTER=600
          LAST="$(grep -E '^storage_collector_last_write_unix_secs ' "$PROM" 2>/dev/null | awk '{print $2}' || true)"
          FRESH=0
          if [ -n "$LAST" ] && [ "$LAST" -gt 0 ] && [ $((NOW - LAST)) -le "$STALE_AFTER" ]; then
            FRESH=1
          fi
          TMP="$(mktemp "${textfileDir}/storage-collector-fresh.prom.XXXXXX")"
          trap 'rm -f "$TMP"' EXIT
          {
            echo "# HELP storage_collector_fresh 1 when the daemon wrote its textfile gauges within 10 cycles"
            echo "# TYPE storage_collector_fresh gauge"
            echo "storage_collector_fresh $FRESH"
          } > "$TMP"
          chmod 0644 "$TMP"
          mv -f "$TMP" "${textfileDir}/storage-collector-fresh.prom"
          trap - EXIT
        '';
      };
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
          # Crash-orphan sweep (2026-10-12) — emit-first since 2026-10-23:
          # the atomic state rewrite (tmp + rename) leaves
          # `.state.json.*.tmp` behind whenever the process dies mid-write
          # — three live orphans (Sep 19 ×2 + the Oct 10 23:22 crash cut,
          # journal-attributed boot) proved nothing else cleans them; one
          # orphan per crash doubles as a free crash-count signal, so the
          # sweep counts and records it before deleting. Best-effort (`-`
          # prefix): a DynamicUser UID rotation could leave an old orphan
          # undeletable, which must never block the daemon from starting.
          ExecStartPre = [
            "-${lib.getExe crashOrphanSweep}"
          ];
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

        # ── Storm hardening + freshness alert (2026-10-27 plan S25) ────
        # During the 2026-10-26 balance the collector sat D-state and its
        # dmesg helper SIGSYS-crashed 4×/5min exactly when the storage
        # metrics mattered (monitoring.md row; uid 966 = this unit's
        # DynamicUser). Three SystemNix-side fixes:
        #   1. ProtectKernelLogs OFF for THIS unit: the crate reads kernel
        #      log via dmesg by design (btrfs space metadata); the harden
        #      preset's kernel-log isolation turned that read into SIGSYS.
        #   2. Slower restart cadence: RestartSec 30 + a start limit, so an
        #      IO-storm D-state death does not become a restart storm.
        #   3. Freshness sidecar below: the textfile gauges going stale was
        #      INVISIBLE — the health check owns the gauge VALUE, nothing
        #      owned the gauge AGE.
        systemd.services.storage-collector = {
          startLimitBurst = 8;
          startLimitIntervalSec = 300;
          serviceConfig = {
            RestartSec = lib.mkDefault "30s";
            TimeoutStopSec = "60s";
            ProtectKernelLogs = lib.mkForce false;
          };
        };

        # Freshness sidecar: reads the daemon's own
        # storage_collector_last_write_unix_secs gauge and publishes
        # storage_collector_fresh 0|1 (stale = older than 10 cycles =
        # 600 s at the 60 s cadence). Mirrors the guard-fresh pattern.
        systemd.services.storage-collector-freshness = {
          description = "storage-collector: textfile freshness gauge (stale-write detector)";
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = "${lib.getExe freshnessScript}";
              User = "root";
              TimeoutStartSec = "1min";
            }
            (harden {
              MemoryMax = "128M";
              CapabilityBoundingSet = [ "CAP_FOWNER" ];
              ReadWritePaths = [ textfileDir ];
            })
            (serviceOneshotDefaults { })
          ];
        };

        systemd.timers.storage-collector-freshness = {
          description = "storage-collector freshness gauge (${scanInterval} cadence)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "4m";
            OnUnitActiveSec = scanInterval;
          };
        };

        services.integration = (lib.optionalAttrs (options ? services.integration)) {
          storage-collector-freshness = {
            enable = true;
            vHost.layer = "none";
            checks = [
              {
                name = "Storage Textfile Freshness";
                group = "Monitoring";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\nstorage_collector_fresh 1\n*)"
                ];
                alert = "storage-collector textfile gauges are STALE (no successful daemon write within 10 cycles / 600s) — during IO storms this is exactly when capacity/btrfs metrics matter; check systemctl status storage-collector and /var/lib/prometheus-node-exporter/textfile_collectors/storage-collector.prom mtime";
              }
            ];
          };
        };
      };
    };
}
