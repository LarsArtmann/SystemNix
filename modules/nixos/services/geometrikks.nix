# GeoMetrikks — reverse-proxy access-log ingestion + geo-location analytics
# (services.geometrikks). Tails Caddy's per-vhost JSON access logs, geolocates
# every request (MaxMind GeoLite2), stores geo-events in TimescaleDB, and
# serves a live world map at geo.home.lan. Upstream is Docker-only
# (github:GilbN/geometrikks), so this follows the mkDockerService pattern
# (manifest.nix is the reference: app + DB sidecar, sops env template,
# pg_dump backup to the pool).
_: {
  flake.nixosModules.geometrikks =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.geometrikks;
      inherit (config.networking) domain;
      libHelpers = import ../../../lib/default.nix lib;
      inherit (libHelpers) serviceTypes images ports;
      inherit (libHelpers.mkDockerServiceFactory { inherit pkgs; }) mkDockerService;

      secretsDir = ./../../../platforms/nixos/secrets;

      # Tail every Caddy access-log sink. The nixpkgs caddy module writes each
      # vhost to access-<host>.log (file output => Caddy's default encoder is
      # JSON per caddyserver.com/docs/caddyfile/directives/log), and the
      # global access.log only receives un-matched traffic — so the FULL list
      # (global + every vhost) is the complete traffic picture. Filenames
      # replicate vhost-options.nix's own derivation: "/" and " " -> "_".
      # Derived from config.services.caddy.virtualHosts at eval time, so new
      # services are tracked automatically.
      logPaths = builtins.toJSON (
        [ "/var/log/access/access.log" ]
        ++ map (
          host:
          "/var/log/access/access-${
            lib.replaceStrings
              [
                "/"
                " "
              ]
              [
                "_"
                "_"
              ]
              host
          }.log"
        ) (builtins.attrNames config.services.caddy.virtualHosts)
      );

      composeFile = pkgs.writeText "geometrikks-docker-compose.yml" (
        builtins.toJSON {
          name = "geometrikks";
          services = {
            timescale_db = {
              image = images.geometrikks-timescale.ref;
              # restart=always is LOAD-BEARING (manifest precedent): docker
              # auto-starts these containers when the daemon comes up.
              restart = "always";
              shm_size = "256mb";
              # Upstream's tuned worker pool: ~32 TimescaleDB background jobs
              # + CAGG refresh policies fire on the same tick; the image
              # default (max_background_workers=16) is too small and logs
              # "failed to launch job ... out of background workers".
              command = [
                "-c"
                "timescaledb.max_background_workers=40"
                "-c"
                "max_parallel_workers=8"
                "-c"
                "max_worker_processes=51"
              ];
              environment = {
                POSTGRES_USER = "geouser";
                POSTGRES_PASSWORD = "\${DB_PASSWORD}";
                POSTGRES_DB = "geometrikks";
              };
              volumes = [ "timescale_data:/home/postgres/pgdata/data" ];
              # -d postgres, NOT -d geometrikks: pg_isready succeeds on a
              # nonexistent-db FATAL (it only checks that the server accepts
              # connections), so a -d geometrikks healthcheck reports healthy
              # while the app's target DB is missing — the 2026-09-20 outage
              # class (app crash-looped since bring-up; the 5s FATAL noise in
              # the journal was this healthcheck itself). init_db below owns
              # DB existence; this check owns server liveness only.
              healthcheck = {
                test = [
                  "CMD-SHELL"
                  "pg_isready -U geouser -d postgres"
                ];
                interval = "5s";
                timeout = "5s";
                retries = 5;
              };
              logging = {
                driver = "json-file";
                options = {
                  max-size = "10m";
                  max-file = "5";
                };
              };
              mem_limit = "2g";
              memswap_limit = "2g";
              security_opt = [ "no-new-privileges:true" ];
              networks = [ "internal" ];
            };
            # Idempotent DB bootstrap: the timescaledb-ha image does NOT
            # honor POSTGRES_DB when its data dir is non-empty (init scripts
            # only run on a fresh volume), so the app's database must be
            # created explicitly. Runs once per `compose up`, exits 0 when
            # the DB exists (created or pre-existing). The app gates on
            # service_completed_successfully — a failed bootstrap leaves the
            # app DOWN and the unit fails loudly (OnFailure) instead of
            # crash-looping the app against a missing DB.
            init_db = {
              image = images.geometrikks-timescale.ref;
              restart = "no";
              entrypoint = [
                "/bin/sh"
                "-c"
                "until pg_isready -h timescale_db -U geouser -d postgres >/dev/null 2>&1; do sleep 1; done; psql -d postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='geometrikks'\" | grep -q 1 || psql -d postgres -c 'CREATE DATABASE geometrikks OWNER geouser'"
              ];
              environment = {
                PGHOST = "timescale_db";
                PGUSER = "geouser";
                PGPASSWORD = "\${DB_PASSWORD}";
              };
              networks = [ "internal" ];
            };
            app = {
              image = images.geometrikks.ref;
              restart = "always";
              hostname = "geometrikks";
              # All config rides compose's ${VAR} substitution from the sops
              # --env-file (mkDockerService passes it on every exec) — same
              # pattern as manifest, no env_file directive (its relative
              # paths would resolve against the read-only store compose dir).
              environment = {
                DB_HOST = "timescale_db";
                DB_PASSWORD = "\${DB_PASSWORD}";
                PUID = "\${PUID}";
                PGID = "\${PGID}";
                APP_ADMIN_USER = "\${APP_ADMIN_USER}";
                APP_ADMIN_PASSWORD = "\${APP_ADMIN_PASSWORD}";
                APP_AUTH_DISABLED = "\${APP_AUTH_DISABLED}";
                APP_SESSION_SECURE = "\${APP_SESSION_SECURE}";
                APP_TRUSTED_PROXIES = "\${APP_TRUSTED_PROXIES}";
                MAXMINDDB_USER_ID = "\${MAXMINDDB_USER_ID}";
                MAXMINDDB_LICENSE_KEY = "\${MAXMINDDB_LICENSE_KEY}";
                MAP_CARTO_API_KEY = "\${MAP_CARTO_API_KEY}";
                LOGPARSER_LOG_PATHS = "\${LOGPARSER_LOG_PATHS}";
                LOGPARSER_HOST_NAME = "\${LOGPARSER_HOST_NAME}";
              };
              ports = [ "127.0.0.1:${toString cfg.port}:8000" ];
              volumes = [
                "geoip_data:/app/data/geoip"
                # Caddy's log dir (caddy:caddy 0600 files) read-only. The
                # container runs as root (PUID=0, see the env template) —
                # the only way to read 0600 foreign-owned files without
                # ACL/permission gymnastics, same trust level as every
                # mkDockerService container on this host.
                "/var/log/caddy:/var/log/access:ro"
              ];
              depends_on = {
                timescale_db.condition = "service_healthy";
                init_db.condition = "service_completed_successfully";
              };
              # Granian starts with --workers-kill-timeout 15; the default
              # 10s stop timeout SIGKILLs mid-teardown and drops the
              # in-flight ingestion batch (upstream compose).
              stop_grace_period = "20s";
              healthcheck = {
                test = [
                  "CMD-SHELL"
                  "python3 -c \"import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=5).status==200 else 1)\""
                ];
                interval = "30s";
                timeout = "10s";
                start_period = "90s";
                retries = 3;
              };
              logging = {
                driver = "json-file";
                options = {
                  max-size = "10m";
                  max-file = "5";
                };
              };
              # read_only is IMPOSSIBLE for this image (source-verified
              # entrypoint 2026-09-20): it chowns /app under `set -e` at
              # startup (EROFS → restart-loop exit 1) and the app rewrites
              # /app/.litestar.json via mkstemp+rename at runtime. The
              # entrypoint ALWAYS drops to the `geometrikks` user via gosu
              # (PUID=0 → uid-0 user, preserving the caddy-log reads);
              # blast-radius stays bounded by no-new-privileges, mem limits,
              # and the internal/frontend network split.
              read_only = false;
              tmpfs = [ "/tmp:size=64m" ];
              security_opt = [ "no-new-privileges:true" ];
              mem_limit = "1g";
              memswap_limit = "1g";
              pids_limit = 512;
              networks = [
                "internal"
                "frontend"
              ];
            };
          };
          networks = {
            internal = {
              driver = "bridge";
              internal = true;
            };
            # Subnet-pinned so APP_TRUSTED_PROXIES can trust X-Forwarded-For
            # from the Caddy hop deterministically (userland-proxy is off —
            # DNAT preserves Caddy's source = this bridge's gateway).
            frontend = {
              driver = "bridge";
              ipam.config = [
                {
                  subnet = "172.32.0.0/24";
                }
              ];
            };
          };
          volumes = {
            timescale_data.name = "geometrikks_timescale_data";
            geoip_data.name = "geometrikks_geoip_data";
          };
        }
      );

      docker = mkDockerService {
        name = "geometrikks";
        inherit composeFile;
        envTemplate = config.sops.templates."geometrikks-env".path;
        memoryMax = "4G";
        extraServiceConfig = {
          # First start pulls the timescaledb-ha image (~2.5 GB); the global
          # 3min DefaultTimeoutStartSec would kill the pull mid-flight.
          TimeoutStartSec = "15min";
          RestartSec = "10s";
        };
        backup = {
          # Plain pg_dump lands on the mirrored HDD pool (manifest pattern).
          # Restore needs TimescaleDB present — same image, documented in the
          # runbook.
          execStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T timescale_db pg_dump -U geouser geometrikks > /mnt/pool/backups/geometrikks/$(date +%%Y%%m%%d_%%H%%M%%S).sql && find /mnt/pool/backups/geometrikks -name \"*.sql\" -mtime +14 -delete'";
          schedule = "*-*-* 05:15:00";
          dir = "/mnt/pool/backups/geometrikks";
        };
      };
    in
    {
      options.services.geometrikks = {
        enable = lib.mkEnableOption "GeoMetrikks access-log geo analytics";
        port = serviceTypes.servicePort ports.geometrikks "Host port for the GeoMetrikks UI";
        imageTag = serviceTypes.dockerImageTag images.geometrikks.tag;
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.caddy.enable or false;
            message = "services.geometrikks needs services.caddy — it tails Caddy's access logs";
          }
        ];

        sops = {
          secrets =
            lib.genAttrs
              [
                "geometrikks_admin_password"
                "geometrikks_db_password"
                "geometrikks_maxmind_user_id"
                "geometrikks_maxmind_license_key"
                "geometrikks_carto_api_key"
              ]
              (_: {
                sopsFile = lib.path.append secretsDir "geometrikks.yaml";
                owner = "root";
                group = "root";
                restartUnits = [ "geometrikks.service" ];
              });
          templates."geometrikks-env" = {
            owner = "root";
            group = "root";
            mode = "0400";
            content = ''
              APP_ADMIN_USER=admin
              APP_ADMIN_PASSWORD=${config.sops.placeholder.geometrikks_admin_password}
              # The app ships its own single-admin session auth; the protected
              # vHost adds the oauth2-proxy layer for external access only.
              APP_AUTH_DISABLED=false
              APP_SESSION_SECURE=true
              APP_TRUSTED_PROXIES=172.32.0.0/24
              # Empty = geo-degraded (UI banner, no GeoLite2 download attempt)
              # — the go-live paste is user-gated (free maxmind.com signup).
              MAXMINDDB_USER_ID=${config.sops.placeholder.geometrikks_maxmind_user_id}
              MAXMINDDB_LICENSE_KEY=${config.sops.placeholder.geometrikks_maxmind_license_key}
              MAP_CARTO_API_KEY=${config.sops.placeholder.geometrikks_carto_api_key}
              LOGPARSER_LOG_PATHS=${logPaths}
              LOGPARSER_HOST_NAME=evo-x2
              DB_PASSWORD=${config.sops.placeholder.geometrikks_db_password}
              # 0 = container root: reads Caddy's 0600 caddy:caddy log files
              # through the read-only bind mount; the entrypoint's PUID drop
              # then runs the app as root in-container (contained by the
              # :ro mount + Docker seccomp, same trust level as the other
              # root containers on this host).
              PUID=0
              PGID=0
            '';
          };
        };

        systemd = {
          tmpfiles.rules = docker.tmpfiles;
          inherit (docker) services;
          inherit (docker) timers;
        };

        # Service-integration registry entry: the geo tile, the geo vHost
        # (Layer 2 — external access rides oauth2-proxy, the app's own login
        # still applies), pg_dump backup freshness, unit-state monitoring,
        # and the Gatus health check.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          geometrikks = {
            inherit (cfg) enable;
            subdomain = "geo";
            inherit (cfg) port;
            vHost.layer = "protected";
            monitored = true;
            checks = [
              {
                name = "GeoMetrikks";
                group = "Monitoring";
                url = "http://localhost:${toString cfg.port}/health/ready";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "GeoMetrikks down — access-log geo analytics unreachable";
              }
            ];
            homepage = {
              name = "GeoMetrikks";
              group = "Infrastructure";
              description = "Access-log geo analytics (live world map)";
              icon = "mdi-earth";
            };
            backup = {
              directory = "/mnt/pool/backups/geometrikks";
              maxAgeHours = 31;
            };
          };
        };
      };
    };
}
