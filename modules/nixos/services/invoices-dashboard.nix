# Runbook: docs/services/invoices-dashboard.md
# invoices-dashboard — read-model dashboard over the invoice SQLite DB
# (`invoices dashboard`, github:LarsArtmann/invoices). Loopback
# 127.0.0.1:8110 BY UPSTREAM DESIGN (internal/dashboard defaultHost:
# "loopback only: single-user CLI dashboard, never LAN-exposed", pinned
# by server_loopback_test) behind the protected registry vHost
# invoices.home.lan (oauth2-proxy forward-auth for external clients, LAN
# bypass): the dashboard has NO authentication of its own and shows
# revenue/client data — the journal-serve posture.
#
# BOOT CONTRACT (live-probed 2026-11-10): `invoices dashboard` REQUIRES
# config.yaml in the CWD (viper AddConfigPath "."; no --config flag
# exists) and exits 69 without it. The unit's WorkingDirectory is
# therefore the data dir ~/invoices, and the PRODUCTION config.yaml
# lives there — the repo checkout's config.yaml (environment:
# DEVELOPMENT) stays the dev copy. The dashboard bootstraps a fresh DB
# (inline schema + read-model backfill) when --db points at a missing
# file; /health aggregates database + read-models checks and answers 503
# when either fails.
#
# Data ownership (docs/agents/data-ownership.md): the SQLite store in
# ~/invoices is the TRUTH for invoice records. The invoices CLI is the
# write path (invoice/solcom/importallocations commands with --db
# pointing here); the dashboard is the read window + facts projection
# onto the same single store. USER data outside /var/lib, deliberately
# (journal books precedent): the unit runs as the primary user with a
# single ReadWritePaths hole for the data dir.
#
# The dashboard handles its own graceful shutdown (SIGINT/SIGTERM →
# 5s window, SSE watchers closed by the server), so no TimeoutStopSec
# override.
{ inputs, ... }: {
  flake.nixosModules.invoices-dashboard =
    {
      config,
      lib,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.services.invoices-dashboard;
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
      dbPath = "${cfg.dataDir}/invoices.db";
      backupDir = "/mnt/pool/backups/invoices";
    in
    {
      options.services.invoices-dashboard = {
        enable = lib.mkEnableOption "the invoice dashboard web server (invoices dashboard, loopback-only by upstream design) with an authenticated registry vHost in front";

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.invoices-dashboard;
          description = "Loopback port for `invoices dashboard`; also fronts the registry vHost.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/${primaryUser}/invoices";
          description = ''
            Invoice data home holding the production config.yaml of
            record (REQUIRED in the unit's CWD — the dashboard exits 69
            without one) and the SQLite store (invoices.db). Owned by the
            primary user; the invoices CLI writes the same store via
            --db <dir>/invoices.db.
          '';
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = inputs.invoices.packages.${pkgs.stdenv.hostPlatform.system}.default;
          defaultText = lib.literalExpression "inputs.invoices.packages.\${pkgs.stdenv.hostPlatform.system}.default";
          description = "invoices package to serve the dashboard with.";
        };

        backupCalendar = lib.mkOption {
          type = lib.types.str;
          default = "*-*-* 03:50:00";
          description = "DB backup calendar (local time). Default: nightly 03:50, after discordsync (03:45).";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            # The data dir must exist before the unit's namespace binds its
            # ReadWritePaths hole (tmpfiles runs in sysinit, before services).
            systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0755 ${primaryUser} users - -" ];

            systemd.services.invoices-dashboard = {
              description = "Invoice dashboard web server (invoices dashboard, loopback; protected vHost invoices.home.lan in front)";
              inherit onFailure;
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;

              # config.yaml is a boot requirement (exit 69 without it): a
              # missing config skips cleanly instead of crash-looping —
              # the runbook's bootstrap step creates it once.
              unitConfig.ConditionPathExists = [ "${cfg.dataDir}/config.yaml" ];

              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "1G";
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
                  ExecStart = "${lib.getExe' cfg.package "invoices"} dashboard --port ${toString cfg.port} --db ${dbPath}";
                }
              ];
            };

            # Pool dir creator — the ONLY sanctioned creator of a directory
            # under the removable /mnt/pool mount (mkPoolDirUnit invariants).
            systemd.services.invoices-dashboard-backup-dir = mkPoolDirUnit {
              description = "Create invoices DB backup directory on the HDD pool";
              directory = backupDir;
            };

            systemd.services.invoices-dashboard-backup = {
              description = "Invoice DB backup (online sqlite .backup, gzipped, + config snapshot)";
              after = [
                "invoices-dashboard.service"
                "invoices-dashboard-backup-dir.service"
              ];
              wants = [
                "invoices-dashboard.service"
                "invoices-dashboard-backup-dir.service"
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
                  ExecStart = pkgs.writeShellScript "invoices-dashboard-backup" ''
                    set -euo pipefail
                    db="${dbPath}"
                    if [ ! -f "$db" ]; then
                      echo "invoices-dashboard-backup: no DB at $db — nothing to back up"
                      exit 0
                    fi
                    stamp=$(date +%Y-%m-%d)
                    raw="${backupDir}/.invoices-db-$stamp.raw"
                    dst="${backupDir}/invoices-db-$stamp.db.gz"
                    if [ -s "$dst" ]; then
                      echo "invoices-dashboard-backup: $dst already exists — nothing to do"
                      exit 0
                    fi
                    find ${backupDir} \( -name ".invoices-db-*" -o -name "*.part" \) -mtime +2 -delete
                    # -readonly: a read-write root open of the live WAL database
                    # can create/replace the -shm/-wal sidecars owned by this
                    # unit while the dashboard holds it, poisoning the next
                    # open with SQLITE_READONLY (browser-history 2026-09-22
                    # uid-drift class). .timeout rides through short write
                    # locks from the dashboard's own connections.
                    attempt=0
                    until err=$(${lib.getExe pkgs.sqlite} -readonly -cmd ".timeout 30000" "$db" ".backup '$raw'" 2>&1); do
                      attempt=$((attempt + 1))
                      if [ "$attempt" -ge 3 ]; then
                        echo "invoices-dashboard-backup: .backup failed after 3 attempts: $err" >&2
                        rm -f "$raw"
                        exit 1
                      fi
                      echo "invoices-dashboard-backup: .backup attempt $attempt failed, retrying: $err" >&2
                      sleep 15
                    done
                    check=$(${lib.getExe pkgs.sqlite} -readonly "$raw" "PRAGMA quick_check;" 2>&1) || true
                    if [ "$check" != "ok" ]; then
                      echo "invoices-dashboard-backup: quick_check failed on raw dump: $check" >&2
                      rm -f "$raw"
                      exit 1
                    fi
                    ${lib.getExe pkgs.gzip} -1 -c "$raw" > "$dst.part"
                    mv "$dst.part" "$dst"
                    rm -f "$raw"
                    # The production config of record rides along undated: a
                    # restore needs DB + config.yaml together, and only the
                    # latest config matters.
                    if [ -f "${cfg.dataDir}/config.yaml" ]; then
                      cp -f "${cfg.dataDir}/config.yaml" "${backupDir}/invoices-config.yaml"
                    fi
                    find ${backupDir} -name "invoices-db-*.db.gz" -mtime +14 -delete
                    find ${backupDir} -name ".invoices-db-*" -mtime +2 -delete
                    echo "invoices-dashboard-backup: wrote $dst ($(du -h "$dst" | cut -f1))"
                  '';
                  ReadWritePaths = [ backupDir ];
                }
                # The data dir is owned by the primary user; this unit runs as
                # root and only needs to READ the DB + config —
                # ProtectHome=read-only keeps /home visible read-only while
                # the pool dir carries the only RW hole.
                (harden {
                  MemoryMax = "1G";
                  ProtectHome = "read-only";
                })
                (serviceOneshotDefaults { })
                ioTier.background
              ];
            };

            systemd.timers.invoices-dashboard-backup = {
              description = "Nightly invoice DB backup";
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
              invoices-dashboard = {
                enable = true;
                inherit (cfg) port;
                subdomain = "invoices";
                vHost.layer = "protected";
                checks = [
                  {
                    name = "Invoices dashboard health";
                    group = "Finance";
                    path = "/health";
                    interval = "30s";
                    conditions = [
                      "[STATUS] == 200"
                      # Honest health: /health aggregates the database +
                      # read-models checks and answers 503 when either fails,
                      # so the body shape proves both legs, not just liveness.
                      "[BODY] == pat(*\"status\":\"healthy\"*)"
                    ];
                    alert = "Invoices dashboard down — invoices.home.lan unreachable or its DB/read-model checks fail. Check: systemctl status invoices-dashboard, journalctl -u invoices-dashboard -n 50.";
                  }
                  {
                    name = "Invoices dashboard page";
                    group = "Finance";
                    path = "/";
                    interval = "60s";
                    conditions = [
                      "[STATUS] == 200"
                      "[RESPONSE_TIME] < 1000"
                      # Functional, not just liveness: the dashboard page
                      # title is "Invoice Dashboard" — an error shell would
                      # not carry it.
                      "[BODY] == pat(*Invoice Dashboard*)"
                    ];
                    alert = "Invoices dashboard page broken — / no longer renders the Invoice Dashboard. Check: systemctl status invoices-dashboard, journalctl -u invoices-dashboard -n 50.";
                  }
                ];
                homepage = {
                  name = "Invoices";
                  group = "Finance";
                  description = "Invoice dashboard — revenue, status, live facts";
                  # Closest pack glyph for invoicing (dashboard-icons
                  # invoiceplane); no project-specific icon exists.
                  icon = "invoiceplane.png";
                };
                backup = {
                  directory = backupDir;
                  filePattern = "invoices-db-*.db.gz";
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
