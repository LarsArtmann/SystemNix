# Runbook: docs/services/reports-system.md
# reports-system — report management web app (`server`,
# github:LarsArtmann/testing, product reports-system).
#
# DELEGATED to the upstream module (inputs.reports-system.nixosModules
# .reports-system, repo nix/module.nix — VM-tested upstream by its
# checks.module-vm): options, the unit, the system user, the state
# directory and portable hardening all live upstream. This file layers
# ONLY the SystemNix concerns, per the DiscordSync/Monitor365 pattern
# (docs/agents/integration-registry.md):
#   - port from the central registry
#   - the two secrets the server refuses to start without (sops template)
#   - onFailure alert routing, Restart defaults, ioTier
#   - nightly backup of BOTH state stores to the HDD pool
#   - integration-registry entry (vHost, Gatus checks, tile, backup
#     freshness, system-health metrics)
#
# - Binds 127.0.0.1:${ports.reports-system}. The registry vHost is Layer 2
#   protected (oauth2-proxy for external clients, LAN bypass): the app has
#   its own login and no OIDC, so external clients authenticate twice
#   (gateway, then the app).
# - Registration is `bootstrap` outside development (upstream default
#   `auto`): the FIRST account created becomes the administrator and
#   registration closes. Until that account exists anyone who reaches the
#   app can take it, so do the first-run registration right after a deploy.
# - Truth for reports AND accounts: the two SQLite stores in
#   /var/lib/reports-system (reports.db, cqrs.db). Back up both; an account
#   without its cqrs.db journal is not restorable from reports.db alone.
# - No OTLP: the binary ships no OTLP exporter (tracing.endpoint is a dead
#   config key upstream), so no OTEL_EXPORTER_OTLP_ENDPOINT here.
{
  inputs,
  ...
}:
{
  flake.nixosModules.reports-system =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.reports-system;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        mkPoolDirUnit
        onFailure
        ports
        ioTier
        ;
      stateDir = "/var/lib/reports-system";
      backupDir = "/mnt/pool/backups/reports-system";
      serviceUnit = "reports-system.service";
      secretsFile = ../../../platforms/nixos/secrets/reports-system.yaml;
    in
    # INERT until the `reports-system` flake input is registered in
    # flake.nix. This module landed on 2026-11-28 at 06:08 without that
    # input, and the missing `inputs.reports-system` broke EVERY evo-x2 eval
    # for every session plus the 08:07 deploy ("attribute 'reports-system'
    # missing"). An empty module is the neutral shape: nothing is declared,
    # nothing is enabled. Drop this guard in the SAME change that registers
    # the input.
    lib.optionalAttrs (inputs ? reports-system)
    {
      imports = [
        inputs.reports-system.nixosModules.reports-system
        # Platform-truth catalog entry (ADR-008): unconditional — the app
        # exists platform-wide even where a host has it disabled. The
        # catalog OPTION comes from nixosModules.catalog, which every host
        # importing this module must co-import (a missing import fails
        # loudly at eval, never silently).
        {
          services.catalog.reports-system = {
            subdomain = "reports";
            port = ports.reports-system;
            description = "Report management web app";
            healthPath = "/ready";
          };
        }
      ];

      options.services.reports-system.backupCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:25:00";
        description = "State backup calendar (local time). Default: nightly 03:25, between timesheets (03:20) and journal (03:30).";
      };

      config = lib.mkIf cfg.enable {
        services.reports-system = {
          port = ports.reports-system;
          environmentFile = config.sops.templates."reports-system-env".path;
        };

        # Both secrets are agent-generated random values (runbook). Root-
        # owned ON PURPOSE: systemd reads EnvironmentFile as PID 1 and
        # injects the variables into the service process — the service
        # user never needs file access.
        sops.secrets = {
          reports_system_session_secret = {
            sopsFile = secretsFile;
            restartUnits = [ serviceUnit ];
          };
          reports_system_jwt_secret = {
            sopsFile = secretsFile;
            restartUnits = [ serviceUnit ];
          };
        };

        sops.templates."reports-system-env" = {
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ serviceUnit ];
          content = ''
            REPORTS_SECURITY_SESSION_SECRET=${config.sops.placeholder.reports_system_session_secret}
            REPORTS_SECURITY_JWT_SECRET=${config.sops.placeholder.reports_system_jwt_secret}
          '';
        };

        systemd.services.reports-system = {
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            # ProtectSystem must equal the upstream value ("strict"): both
            # sides are mkDefault, and two different values at one priority
            # conflict at eval.
            (harden {
              MemoryMax = "1G";
              ProtectSystem = "strict";
            })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # Pool dir creator — the ONLY sanctioned creator of a directory
        # under the removable /mnt/pool mount (mkPoolDirUnit invariants).
        # Owned by the service user so the backup unit needs no root
        # capability: it reads the stores as their own owner.
        systemd.services.reports-system-backup-dir = mkPoolDirUnit {
          description = "Create reports-system backup directory on the HDD pool";
          directory = backupDir;
          owner = "reports-system";
          mode = "0750";
        };

        systemd.services.reports-system-backup = {
          description = "reports-system state backup (online sqlite .backup of both stores, gzipped)";
          after = [
            serviceUnit
            "reports-system-backup-dir.service"
          ];
          wants = [
            serviceUnit
            "reports-system-backup-dir.service"
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
              ExecStart = pkgs.writeShellScript "reports-system-backup" ''
                set -euo pipefail
                stamp=$(date +%Y-%m-%d)
                for name in reports cqrs; do
                  db="${stateDir}/$name.db"
                  dst="${backupDir}/$name-db-$stamp.db.gz"
                  if [ ! -f "$db" ]; then
                    echo "reports-system-backup: no store at $db, nothing to back up"
                    continue
                  fi
                  if [ -s "$dst" ]; then
                    echo "reports-system-backup: $dst already exists, nothing to do"
                    continue
                  fi
                  raw="${backupDir}/.$name-db-$stamp.raw"
                  # -readonly: a read-write open of the live WAL store can
                  # create or replace its -shm/-wal sidecars. .timeout rides
                  # through short write locks held by the server's own
                  # connections.
                  attempt=0
                  until err=$(${lib.getExe pkgs.sqlite} -readonly -cmd ".timeout 30000" "$db" ".backup '$raw'" 2>&1); do
                    attempt=$((attempt + 1))
                    if [ "$attempt" -ge 3 ]; then
                      echo "reports-system-backup: $name .backup failed after 3 attempts: $err" >&2
                      rm -f "$raw"
                      exit 1
                    fi
                    echo "reports-system-backup: $name .backup attempt $attempt failed, retrying: $err" >&2
                    sleep 15
                  done
                  check=$(${lib.getExe pkgs.sqlite} -readonly "$raw" "PRAGMA quick_check;" 2>&1) || true
                  if [ "$check" != "ok" ]; then
                    echo "reports-system-backup: quick_check failed on the $name copy: $check" >&2
                    rm -f "$raw"
                    exit 1
                  fi
                  ${lib.getExe pkgs.gzip} -1 -c "$raw" > "$dst.part"
                  mv "$dst.part" "$dst"
                  rm -f "$raw"
                  echo "reports-system-backup: wrote $dst ($(du -h "$dst" | cut -f1))"
                done
                find ${backupDir} -name "*-db-*.db.gz" -mtime +14 -delete
                find ${backupDir} -name ".*-db-*.raw" -mtime +2 -delete
              '';
              ReadWritePaths = [ backupDir ];
            }
            (harden {
              MemoryMax = "512M";
              ProtectSystem = "strict";
            })
            (serviceOneshotDefaults { })
            ioTier.background
            {
              User = "reports-system";
              Group = "reports-system";
            }
          ];
        };

        systemd.timers.reports-system-backup = {
          description = "Nightly reports-system state backup";
          wantedBy = [ "timers.target" ];
          after = [ "mnt-pool.mount" ];
          timerConfig = {
            OnCalendar = cfg.backupCalendar;
            RandomizedDelaySec = "5min";
            Persistent = true;
          };
        };

        # Service-integration registry entry: fans out to the Caddy vHost
        # (protected), the Gatus checks, the dashboard tile, backup
        # freshness, and system-health metrics.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          reports-system = {
            enable = true;
            inherit (cfg) port;
            subdomain = "reports";
            vHost.layer = "protected";
            checks = [
              {
                name = "Reports live";
                group = "Productivity";
                path = "/live";
                interval = "30s";
                conditions = [ "[STATUS] == 200" ];
                alert = "Reports app down, reports.home.lan unreachable. Check: systemctl status reports-system, journalctl -u reports-system -n 50.";
              }
              {
                name = "Reports ready";
                group = "Productivity";
                path = "/ready";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  # Functional, not just liveness: readiness answers 503
                  # when the database check fails, and the body names the
                  # service — an error shell would carry neither.
                  "[BODY] == pat(*\"service\":\"reports-system\"*)"
                  "[RESPONSE_TIME] < 1500"
                ];
                alert = "Reports app not ready, its database check fails. Check: systemctl status reports-system, journalctl -u reports-system -n 50.";
              }
              {
                name = "Reports version";
                group = "Productivity";
                path = "/version";
                interval = "5m";
                # Text body is "<service> <version>": proves the build
                # metadata is stamped and the binary serving is reports-system.
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(reports-system *)"
                ];
                alert = "Reports app version probe broken, /version no longer names reports-system. Check: systemctl status reports-system, journalctl -u reports-system -n 50.";
              }
            ];
            homepage = {
              name = "Reports";
              group = "Productivity";
              description = "Report management — drafts, review, analytics";
              # Generic pack glyph (dashboard-icons text-document): the
              # project ships no brand mark.
              icon = "text-document.png";
            };
            backup = {
              directory = backupDir;
              filePattern = "*-db-*.db.gz";
              maxAgeHours = 25;
            };
            monitored = true;
          };
        };
      };
    };
}
