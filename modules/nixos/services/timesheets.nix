# Runbook: docs/services/timesheets.md
# timesheets — event-sourced timesheet API server (`timesheet serve`,
# github:LarsArtmann/timesheets). Loopback 127.0.0.1:8109 behind the
# protected registry vHost timesheets.home.lan (oauth2-proxy forward-auth
# for external clients, LAN bypass): the API has NO authentication of its
# own and carries billing data — the journal-serve posture (owner g-2
# 2026-10-26 applied to the sibling billing service).
#
# Data ownership (docs/agents/data-ownership.md): the SQLite event store
# in ~/timesheets is the TRUTH for recorded timesheets. The timesheet CLI
# is the primary write path (create/add-entry/import with --db pointing
# here); serve is the API window onto the same single store. USER data
# outside /var/lib, deliberately (journal books precedent): the unit runs
# as the primary user with a single ReadWritePaths hole for the data dir,
# so CLI and daemon share one store with no uid drift.
#
# serve handles its own graceful drain (SIGTERM → context cancel, 10s
# shutdown window marking /readyz 503 for the whole drain), so no
# TimeoutStopSec override. CSRF stays ON (token-based, proxy-safe —
# NOT origin-based). --health-detail adds the per-DI-service checks to
# /health for operator diagnostics (boot-time flag).
{ inputs, ... }: {
  flake.nixosModules.timesheets =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.services.timesheets;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        mkPoolDirUnit
        onFailure
        ports
        ioTier
        ;
      primaryUser = config.users.primaryUser;
      dbPath = "${cfg.dataDir}/timesheets.db";
      backupDir = "/mnt/pool/backups/timesheets";
    in
    {
      options.services.timesheets = {
        enable = lib.mkEnableOption "the timesheet HTTP API server (timesheet serve, loopback-only) with an authenticated registry vHost in front";

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.timesheets;
          description = "Loopback port for `timesheet serve`; also fronts the registry vHost.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/timesheets";
          description = ''
            Timesheet data home holding the SQLite event store
            (timesheets.db). Owned by the primary user; the timesheet CLI
            writes the same store via --db <dir>/timesheets.db.
          '';
        };

        package = lib.mkOption {
          type = lib.types.package;
          # shim DROPPED 2026-11-12 (treadmill drop-protocol): the daemon
          # float moved timesheets c2acd98 → 0304e2ae, the parallel
          # session's drop-proof probed upstream-baked green at 0304e2ae
          # (lib surface, toplevel-proof-20261112-drop.log era), and this
          # service surface consumed the SAME drv — the morning shim
          # (XAx3aw3b, measured at c2acd98) would mismatch at the new rev.
          # Re-add ONLY via nix-hash-fix evidence, never by hand.
          default = inputs.timesheets.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultText = lib.literalExpression "inputs.timesheets.packages.\${pkgs.stdenv.hostPlatform.system}.default";
          description = "timesheet package to serve the API with.";
        };

        backupCalendar = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 03:20:00";
          description = "DB backup calendar (local time). Default: nightly 03:20, between cv (03:17) and journal (03:30).";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            # The data dir must exist before the unit's namespace binds its
            # ReadWritePaths hole (tmpfiles runs in sysinit, before services).
            systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0755 ${primaryUser} users - -" ];

            systemd.services.timesheets = {
              description = "Timesheet API server (timesheet serve, loopback; protected vHost timesheets.home.lan in front)";
              inherit onFailure;
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;

              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "512M";
                  ProtectHome = "read-only";
                  ReadWritePaths = [ cfg.dataDir ];
                })
                (serviceDefaults { })
                ioTier.background
                {
                  User = primaryUser;
                  Group = "users";
                  WorkingDirectory = cfg.dataDir;
                  Environment = [ "HOME=/home/${primaryUser}" ];
                  ExecStart = "${lib.getExe' cfg.package "timesheet"} serve --addr 127.0.0.1:${toString cfg.port} --db ${dbPath} --health-detail";
                }
              ];
            };

            # Pool dir creator — the ONLY sanctioned creator of a directory
            # under the removable /mnt/pool mount (mkPoolDirUnit invariants).
            systemd.services.timesheets-backup-dir = mkPoolDirUnit {
              description = "Create timesheets DB backup directory on the HDD pool";
              directory = backupDir;
            };

            systemd.services.timesheets-backup = {
              description = "Timesheet event-store backup (online sqlite .backup, gzipped)";
              after = [
                "timesheets.service"
                "timesheets-backup-dir.service"
              ];
              wants = [
                "timesheets.service"
                "timesheets-backup-dir.service"
              ];
              # Detached DAS fails the run as a clean dependency error, never
              # 226/NAMESPACE (btrbk doctrine).
              unitConfig.RequiresMountsFor = [ backupDir ];
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  TimeoutStartSec = "10min";
                  ExecStart = pkgs.writeShellScript "timesheets-backup" ''
                    set -euo pipefail
                    db="${dbPath}"
                    if [ ! -f "$db" ]; then
                      echo "timesheets-backup: no DB at $db — nothing to back up"
                      exit 0
                    fi
                    stamp=$(date +%Y-%m-%d)
                    raw="${backupDir}/.timesheets-db-$stamp.raw"
                    dst="${backupDir}/timesheets-db-$stamp.db.gz"
                    if [ -s "$dst" ]; then
                      echo "timesheets-backup: $dst already exists — nothing to do"
                      exit 0
                    fi
                    find ${backupDir} \( -name ".timesheets-db-*" -o -name "*.part" \) -mtime +2 -delete
                    # -readonly: a read-write root open of the live WAL database
                    # can create/replace the -shm/-wal sidecars owned by this
                    # unit while serve holds it, poisoning the next open with
                    # SQLITE_READONLY (browser-history 2026-09-22 uid-drift
                    # class). .timeout rides through short write locks from the
                    # serve process's own connections.
                    attempt=0
                    until err=$(${lib.getExe pkgs.sqlite} -readonly -cmd ".timeout 30000" "$db" ".backup '$raw'" 2>&1); do
                      attempt=$((attempt + 1))
                      if [ "$attempt" -ge 3 ]; then
                        echo "timesheets-backup: .backup failed after 3 attempts: $err" >&2
                        rm -f "$raw"
                        exit 1
                      fi
                      echo "timesheets-backup: .backup attempt $attempt failed, retrying: $err" >&2
                      sleep 15
                    done
                    check=$(${lib.getExe pkgs.sqlite} -readonly "$raw" "PRAGMA quick_check;" 2>&1) || true
                    if [ "$check" != "ok" ]; then
                      echo "timesheets-backup: quick_check failed on raw dump: $check" >&2
                      rm -f "$raw"
                      exit 1
                    fi
                    ${lib.getExe pkgs.gzip} -1 -c "$raw" > "$dst.part"
                    mv "$dst.part" "$dst"
                    rm -f "$raw"
                    find ${backupDir} -name "timesheets-db-*.db.gz" -mtime +14 -delete
                    find ${backupDir} -name ".timesheets-db-*" -mtime +2 -delete
                    echo "timesheets-backup: wrote $dst ($(du -h "$dst" | cut -f1))"
                  '';
                  ReadWritePaths = [ backupDir ];
                }
                # The data dir is owned by the primary user; this unit runs as
                # root and only needs to READ the DB — ProtectHome=read-only
                # keeps /home visible read-only (0644 DB, 0755 dir; no caps
                # needed) while the pool dir carries the only RW hole.
                # CAP_DAC_READ_SEARCH: /home/<user> itself is 0700, and
                # harden{}'s empty default CapabilityBoundingSet strips
                # root's DAC bypass, so without this cap the unit cannot
                # even STAT the DB (live 2026-11-10: "no DB — nothing to
                # back up" while the file existed; cv-backup precedent).
                # READ_SEARCH grants traversal+read only — pool writes stay
                # ordinary root-owner DAC (cv.nix backup pattern).
                (harden {
                  MemoryMax = "1G";
                  ProtectHome = "read-only";
                  CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
                })
                (serviceOneshotDefaults { })
                ioTier.background
              ];
            };

            systemd.timers.timesheets-backup = {
              description = "Nightly timesheet event-store backup";
              wantedBy = [ "timers.target" ];
              after = [ "mnt-pool.mount" ];
              timerConfig = {
                OnCalendar = cfg.backupCalendar;
                RandomizedDelaySec = "10min";
                Persistent = true;
              };
            };
          }

          # Service-integration registry entry: fans out to the Caddy vHost
          # (protected — billing data, no app auth), the Gatus checks, the
          # dashboard tile, backup freshness, and system-health metrics.
          (lib.optionalAttrs (options ? services.integration) {
            services.integration = {
              timesheets = {
                enable = true;
                inherit (cfg) port;
                subdomain = "timesheets";
                vHost.layer = "protected";
                checks = [
                  {
                    name = "Timesheets readyz";
                    group = "Finance";
                    path = "/readyz";
                    interval = "30s";
                    conditions = [ "[STATUS] == 200" ];
                    alert = "Timesheets API down — timesheets.home.lan unreachable. /readyz gates on the domain aggregate (SQLite ping + projection workers). Check: systemctl status timesheets, journalctl -u timesheets -n 50.";
                  }
                  {
                    name = "Timesheets health page";
                    group = "Finance";
                    path = "/health";
                    interval = "60s";
                    conditions = [
                      "[STATUS] == 200"
                      "[RESPONSE_TIME] < 1000"
                      # Functional, not just liveness: the go-health dashboard
                      # page title is "Timesheets" (dashboard.WithTitle) — an
                      # error shell would not carry it.
                      "[BODY] == pat(*Timesheets*)"
                    ];
                    alert = "Timesheets health dashboard broken — /health no longer renders the Timesheets status page. Check: systemctl status timesheets, journalctl -u timesheets -n 50.";
                  }
                ];
                homepage = {
                  name = "Timesheets";
                  group = "Finance";
                  description = "Timesheet recording API — event-sourced store, approval workflow";
                  # Closest pack glyph for time tracking (dashboard-icons
                  # solidtime); no timesheet-specific icon exists.
                  icon = "solidtime.png";
                };
                backup = {
                  directory = backupDir;
                  filePattern = "timesheets-db-*.db.gz";
                  maxAgeHours = 25;
                };
                monitored = true;
              };
            };
          })
        ]
      );
    };
}
