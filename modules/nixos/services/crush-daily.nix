# Runbook: docs/services/crush-daily.md
# crush-daily — SystemNix hardening overlay for the crush-daily service
#
# The upstream crush-daily flake module (flake.nix) now declares
# `services.crush-daily.runAsUser`. SystemNix just wires SystemNix-specific
# hardening: directory traversal permissions and per-host overrides.
_: {
  flake.nixosModules.crush-daily =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.crush-daily;
      inherit (import ../../../lib/default.nix lib)
        harden
        mkStateDir
        mkPoolDirUnit
        serviceDefaults
        onFailure
        ports
        ;
      primaryUser = config.users.primaryUser;
      crushDbDir = "/home/${primaryUser}/.local/share/crush/.crush";
      # True when the backup target lives on the removable HDD pool: the leaf
      # then needs the mount-gated creator unit and the backup a mount dep.
      poolBackup = lib.hasPrefix "/mnt/pool/" cfg.backup.directory;
      # Mirrors the upstream module's own resolution: runAsUser wins over the
      # dedicated system user. The pool leaf is chowned to whoever writes the
      # backups, so this must not drift from the upstream backup unit's User=.
      serviceUser = if cfg.runAsUser == null then "crush-daily" else cfg.runAsUser;
      # The leaf's GROUP is the user's primary group, not a group named after
      # the user. On evo-x2 lars' gid is `users` (100) — there is no `lars`
      # group at all — so `chown lars:lars` failed the leaf unit on every boot
      # and the backup service, which runs as that unprivileged user, then had
      # no writable destination under the root-owned /mnt/pool/backups. Found
      # by the VM test on its first boot (2026-11-02); the flake check could
      # not see it because it renders the script without a user database.
      serviceGroup = config.users.users.${serviceUser}.group;
    in
    {
      config = lib.mkIf cfg.enable {
        services.crush-daily.port = lib.mkDefault ports.crush-daily;

        # When running as the default `crush-daily` system user (no
        # runAsUser override), ensure the system user can traverse the path
        # to the primary user's ~/.local/share/crush/.crush to read the
        # database. tmpfiles `d` type sets mode on existing dirs too.
        systemd.tmpfiles.rules = lib.mkIf (cfg.runAsUser == null) [
          (mkStateDir "/home/${primaryUser}/.local" "0750" primaryUser "users")
          (mkStateDir "/home/${primaryUser}/.local/share" "0750" primaryUser "users")
          (mkStateDir "/home/${primaryUser}/.local/share/crush/.crush" "0750" primaryUser "users")
        ];

        # Pool-resident backup leg (2026-11-02): when the operator points
        # backup.directory at the HDD pool, the leaf must be created by a
        # mount-gated unit (cv-backup-dir pattern) — a tmpfiles rule under
        # /mnt/pool would create it BEFORE the mount and shadow the pool copy
        # on the root fs (the 9-day DAS shadow-dir incident). The unit is also
        # what gives the backup service a directory it can write: the parent
        # /mnt/pool/backups is root-owned and the backup runs as serviceUser.
        systemd.services.crush-daily-backup-dir = lib.mkIf (cfg.backup.enable && poolBackup) (
          mkPoolDirUnit {
            description = "Create Crush Daily backup directory on the HDD pool";
            directory = cfg.backup.directory;
            owner = serviceUser;
            group = serviceGroup;
            mode = "0750";
          }
        );

        systemd.services.crush-daily-backup = lib.mkIf (cfg.backup.enable && poolBackup) {
          after = [ "crush-daily-backup-dir.service" ];
          wants = [ "crush-daily-backup-dir.service" ];
          # Detached DAS fails the run as a clean dependency error, never as a
          # silent write onto the root filesystem.
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
        };

        systemd.services.crush-daily = {
          inherit onFailure;
          path = [ pkgs.crush ];
          startLimitBurst = 3;
          startLimitIntervalSec = 60;

          # OTel traces → local SigNoz OTLP/HTTP collector. Uses go-cqrs-lite
          # otel package which auto-initializes from this env var (noop tracer
          # when unset). See docs/service-integration-ideas.md appendix.
          environment = {
            OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
          };

          # When runAsUser is set, take ownership of the existing data dir so
          # the new user can write the SQLite DB and read prior reports. The
          # dir is owned by `crush-daily:crush-daily` from historical runs
          # under the system user. systemd's StateDirectory only creates the
          # dir on first run — it does not chown existing data.
          #
          # The migration MUST run with the ExecStartPre "+" (full-privilege)
          # prefix: as the service User it SIGSYS'd at every boot (upstream
          # SystemCallFilter ~@privileged blocks fchownat; verified 2026-08-18
          # "Bad system call" core dumps) and even unfiltered, a non-root user
          # cannot chown files owned by another user (silent EPERM).
          serviceConfig = lib.mkMerge [
            (lib.mkIf (cfg.runAsUser != null) {
              ExecStartPre = [
                "+${
                  pkgs.writeShellApplication {
                    name = "crush-daily-migrate-ownership";
                    runtimeInputs = [
                      pkgs.coreutils
                      pkgs.findutils
                    ];
                    text = ''
                      mkdir -p ${lib.escapeShellArg cfg.dataDir}
                      chown -R ${lib.escapeShellArg cfg.runAsUser} ${lib.escapeShellArg cfg.dataDir}
                      find ${lib.escapeShellArg cfg.dataDir} -type d -exec chmod 0750 {} \;
                      find ${lib.escapeShellArg cfg.dataDir} -type f -exec chmod 0640 {} \;
                    '';
                  }
                }/bin/crush-daily-migrate-ownership"
              ];
            })
            (harden {
              MemoryMax = "1G";
              # ReadOnlyPaths / SupplementaryGroups only needed when running
              # as the default system user (the primary user's /home is
              # mode 750 + ACL mask; supplementary group `users` is required
              # for traversal). When runAsUser is set, the service IS the
              # primary user and has access to /home/<user> directly.
              SupplementaryGroups = lib.mkIf (cfg.runAsUser == null) "users";
              ReadOnlyPaths = lib.mkIf (cfg.runAsUser == null) [ crushDbDir ];
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceDefaults { })
            {
              TimeoutStartSec = "3min";
              Environment = [ "GOMEMLIMIT=768MiB" ];
            }
          ];
        };

        # Service-integration registry entry: the Crush Daily homepage tile, the
        # daily vHost (Layer 2 — no native auth), and the Gatus health
        # check.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          crush-daily = {
            inherit (cfg) enable;
            subdomain = "daily";
            inherit (cfg) port;
            vHost.layer = "protected";
            checks = [
              {
                name = "Crush Daily";
                group = "AI";
                url = "http://localhost:${toString cfg.port}/api/health";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "Crush Daily unhealthy — /api/health returned non-200. The endpoint is dependency-aware: a 503 names the failing check in its JSON body while the process may still be up. Two checks exist. (1) event_store = SQLite event store unreachable/closed — the DB or its WAL cannot be read. (2) collect_freshness = the event store has not been written for over 36h, which means the collector stopped producing data (scheduler dead, discovery returning 0 projects, or every project database unreadable) even though the HTTP server is fine. Before 2026-11-02 only check (1) existed, so a healthy-looking service with a dead collector stayed green for days. Check: curl -s localhost:8081/api/doctor for the full diagnosis, then journalctl -u crush-daily for the collect accounting line (discovered/collected/failed + per-reason breakdown)";
              }
            ];
            homepage = {
              name = "Crush Daily";
              group = "AI";
              description = "AI-Powered Development Insights";
              # The product's own brand mark (docs/brand/, four ascending
              # violet bars), served by the app itself at /favicon.svg —
              # the small-size-optimized variant. Absolute URLs bypass the
              # pack gate by design (see papdashboard.nix); browser tile
              # loads carry the SSO session, so the protected vHost
              # serves it.
              icon = "https://daily.${config.networking.domain}/favicon.svg";
            };
            # DB dump freshness (crush-daily-backup.timer, daily 00:00 +
            # Persistent) — gated so a host without the backup leg registers
            # no phantom row. Feeds backup-coordination's
            # backup_healthy/backup_age_hours metrics and the aggregate
            # "All Backups Healthy" Gatus check.
            backup = lib.mkIf cfg.backup.enable {
              directory = cfg.backup.directory;
              filePattern = "crush-daily-*.db";
              maxAgeHours = 25;
            };
          };
        };
      };
    };
}
