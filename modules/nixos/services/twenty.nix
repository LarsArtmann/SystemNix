# Twenty CRM via Docker Compose with PostgreSQL and Redis
_: let
  version = "latest";
in {
  flake.nixosModules.twenty = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.twenty;
    inherit (config.networking) domain;
    libHelpers = import ../../../lib/default.nix lib;
    inherit (libHelpers) serviceTypes;
    inherit (libHelpers.mkDockerServiceFactory {inherit pkgs;}) mkDockerService;

    serverPort = cfg.port;
    pgUser = "postgres";
    pgDb = "twenty";
    serverUrl = "https://crm.${domain}";

    composeFile =
      pkgs.writeText "twenty-docker-compose.yml"
      ''
        name: twenty

        services:
          server:
            image: twentycrm/twenty:${version}
            ports:
              - "127.0.0.1:${toString serverPort}:3000"
            environment:
              NODE_PORT: 3000
              PG_DATABASE_URL: postgres://${pgUser}:''${PG_DATABASE_PASSWORD}@db:5432/${pgDb}
              SERVER_URL: ${serverUrl}
              REDIS_URL: redis://redis:6379
              STORAGE_TYPE: local
              APP_SECRET: ''${APP_SECRET}
            volumes:
              - server-local-data:/app/packages/twenty-server/.local-storage
            depends_on:
              db:
                condition: service_healthy
              redis:
                condition: service_healthy
            healthcheck:
              test: curl --fail http://localhost:3000/healthz
              interval: 5s
              timeout: 5s
              retries: 30
            restart: always

          worker:
            image: twentycrm/twenty:${version}
            command: ["yarn", "worker:prod"]
            environment:
              PG_DATABASE_URL: postgres://${pgUser}:''${PG_DATABASE_PASSWORD}@db:5432/${pgDb}
              SERVER_URL: ${serverUrl}
              REDIS_URL: redis://redis:6379
              STORAGE_TYPE: local
              APP_SECRET: ''${APP_SECRET}
              DISABLE_DB_MIGRATIONS: "true"
              DISABLE_CRON_JOBS_REGISTRATION: "true"
            volumes:
              - server-local-data:/app/packages/twenty-server/.local-storage
            depends_on:
              db:
                condition: service_healthy
              server:
                condition: service_healthy
            restart: always

          db:
            image: postgres:16
            environment:
              POSTGRES_DB: ${pgDb}
              POSTGRES_PASSWORD: ''${PG_DATABASE_PASSWORD}
              POSTGRES_USER: ${pgUser}
            volumes:
              - db-data:/var/lib/postgresql/data
            healthcheck:
              test: pg_isready -U ${pgUser} -h localhost -d postgres
              interval: 5s
              timeout: 5s
              retries: 10
            restart: always

          redis:
            image: redis
            command: ["--maxmemory-policy", "noeviction"]
            healthcheck:
              test: ["CMD", "redis-cli", "ping"]
              interval: 5s
              timeout: 5s
              retries: 10
            restart: always

        volumes:
          db-data:
          server-local-data:
      '';

    docker = mkDockerService {
      name = "twenty";
      inherit composeFile;
      envTemplate = config.sops.templates."twenty-env".path;
      extraServiceConfig = {RestartSec = "10s";};
      backup = {
        execStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T db pg_dump -U ${pgUser} ${pgDb} > /var/lib/twenty/backup/$(date +%%Y%%m%%d_%%H%%M%%S).sql && find /var/lib/twenty/backup -name \"*.sql\" -mtime +30 -delete'";
      };
    };
  in {
    options.services.twenty = {
      enable = lib.mkEnableOption "Twenty CRM";
      port = serviceTypes.servicePort 3200 "Host port for the Twenty CRM server";
    };

    config = lib.mkIf cfg.enable {
      sops = {
        secrets.twenty_app_secret = {
          owner = "root";
          group = "root";
          restartUnits = ["twenty.service"];
        };
        secrets.twenty_db_password = {
          owner = "root";
          group = "root";
          restartUnits = ["twenty.service"];
        };
        templates."twenty-env" = {
          content = ''
            PG_DATABASE_PASSWORD=${config.sops.placeholder.twenty_db_password}
            APP_SECRET=${config.sops.placeholder.twenty_app_secret}
          '';
        };
      };

      systemd = {
        tmpfiles.rules = docker.tmpfiles;
        services = docker.services;
        timers = docker.timers;
      };
    };
  };
}
