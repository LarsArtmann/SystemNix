# Manifest smart LLM router with Ollama integration and DB backups
_: {
  flake.nixosModules.manifest = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.manifest;
    inherit (config.networking) domain;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;

    stateDir = "/var/lib/manifest";
    manifestPort = cfg.port;

    secretsDir = ./../../../platforms/nixos/secrets;

    composeFile =
      pkgs.writeText "manifest-docker-compose.yml"
      ''
        name: mnfst

        services:
          manifest:
            image: manifestdotbuild/manifest:${cfg.imageTag}
            ports:
              - "127.0.0.1:${toString manifestPort}:${toString manifestPort}"
            extra_hosts:
              - "host.docker.internal:host-gateway"
            environment:
              PORT: "${toString manifestPort}"
              DATABASE_URL: postgresql://manifest:''${DB_PASSWORD}@postgres:5432/manifest
              BETTER_AUTH_SECRET: ''${AUTH_SECRET}
              MANIFEST_ENCRYPTION_KEY: ''${ENCRYPTION_KEY}
              BETTER_AUTH_URL: https://manifest.${domain}
              OLLAMA_HOST: http://host.docker.internal:11434
              SEED_DATA: "false"
              NODE_ENV: production
              MANIFEST_MODE: selfhosted
              MANIFEST_TELEMETRY_DISABLED: "1"
              CORS_ORIGIN: "http://localhost:${toString manifestPort}"
            depends_on:
              postgres:
                condition: service_healthy
            healthcheck:
              test:
                - "CMD"
                - "node"
                - "-e"
                - "const p=process.env.PORT||'${toString manifestPort}';fetch(`http://127.0.0.1:$${p}/api/v1/health`).then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
              interval: 30s
              timeout: 5s
              start_period: 90s
              retries: 3
            logging:
              driver: json-file
              options:
                max-size: "10m"
                max-file: "5"
            read_only: true
            tmpfs:
              - /tmp:size=64m
            security_opt:
              - no-new-privileges:true
            cap_drop:
              - ALL
            mem_limit: 1g
            pids_limit: 512
            networks:
              - internal
              - frontend
            restart: always

          postgres:
            image: postgres:16-alpine@sha256:20edbde7749f822887a1a022ad526fde0a47d6b2be9a8364433605cf65099416
            environment:
              POSTGRES_USER: manifest
              POSTGRES_PASSWORD: ''${DB_PASSWORD}
              POSTGRES_DB: manifest
            volumes:
              - pgdata:/var/lib/postgresql/data
            healthcheck:
              test: pg_isready -U manifest
              interval: 5s
              timeout: 3s
              retries: 5
            logging:
              driver: json-file
              options:
                max-size: "10m"
                max-file: "5"
            security_opt:
              - no-new-privileges:true
            networks:
              - internal

        networks:
          internal:
            driver: bridge
            internal: true
          frontend:
            driver: bridge

        volumes:
          pgdata:
            name: manifest_pgdata
      '';
  in {
    options.services.manifest = {
      enable = lib.mkEnableOption "Manifest LLM router";
      port = serviceTypes.servicePort 2099 "Host port for the Manifest dashboard";
      imageTag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Docker image tag for manifestdotbuild/manifest";
      };
    };

    config = lib.mkIf cfg.enable {
      sops = {
        secrets = builtins.listToAttrs (map (name: {
          inherit name;
          value = {
            sopsFile = secretsDir + "/manifest.yaml";
            owner = "root";
            group = "root";
            restartUnits = ["manifest.service"];
          };
        }) ["manifest_auth_secret" "manifest_encryption_key" "manifest_db_password"]);
        templates."manifest-env" = {
          content = ''
            AUTH_SECRET=${config.sops.placeholder.manifest_auth_secret}
            ENCRYPTION_KEY=${config.sops.placeholder.manifest_encryption_key}
            DB_PASSWORD=${config.sops.placeholder.manifest_db_password}
          '';
        };
      };

      systemd.tmpfiles.rules = [
        "d ${stateDir} 0755 root root -"
        "d ${stateDir}/backup 0755 root root -"
      ];

      systemd = {
        services = {
          manifest = {
            description = "Manifest — Smart LLM Router";
            after = ["docker.service" "sops-nix.service"];
            requires = ["docker.service"];
            wants = ["sops-nix.service"];
            wantedBy = ["multi-user.target"];
            path = [pkgs.docker pkgs.docker-compose];

            preStart = ''
              ${pkgs.docker-compose}/bin/docker-compose --env-file ${stateDir}/.env -f ${composeFile} down --remove-orphans || true
              cp ${config.sops.templates."manifest-env".path} ${stateDir}/.env
              chmod 600 ${stateDir}/.env
            '';

            serviceConfig =
              {
                ExecStart = "${pkgs.docker-compose}/bin/docker-compose --env-file ${stateDir}/.env -f ${composeFile} up --remove-orphans";
                ExecStop = "${pkgs.docker-compose}/bin/docker-compose --env-file ${stateDir}/.env -f ${composeFile} down --timeout 30";
                WorkingDirectory = stateDir;
                TimeoutStopSec = "60";
                KillMode = "process";
              }
              // harden {
                MemoryMax = "2G";
                ReadWritePaths = [stateDir];
              }
              // serviceDefaults {RestartSec = "10s";};
          };

          manifest-db-backup = {
            description = "Manifest Database Backup";
            after = ["manifest.service"];
            requires = ["docker.service"];
            onFailure = ["notify-failure@%n.service"];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T postgres pg_dump -U manifest manifest > ${stateDir}/backup/$(date +%%Y%%m%%d_%%H%%M%%S).sql && find ${stateDir}/backup -name \"*.sql\" -mtime +30 -delete'";
              WorkingDirectory = stateDir;
            };
            preStart = "mkdir -p ${stateDir}/backup";
          };
        };

        timers.manifest-db-backup = {
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
    };
  };
}
