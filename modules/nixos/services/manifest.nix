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
    libHelpers = import ../../../lib/default.nix lib;
    inherit (libHelpers) serviceTypes images ports;
    inherit (libHelpers.mkDockerServiceFactory {inherit pkgs;}) mkDockerService;

    manifestPort = cfg.port;

    secretsDir = ./../../../platforms/nixos/secrets;

    composeFile = pkgs.writeText "manifest-docker-compose.yml" ''
      name: mnfst

      services:
        manifest:
          image: ${images.manifest.ref}
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
            OLLAMA_HOST: http://host.docker.internal:${toString ports.ollama}
            SEED_DATA: "false"
            NODE_ENV: production
            MANIFEST_MODE: selfhosted
            MANIFEST_TELEMETRY_DISABLED: "1"
            CORS_ORIGIN: "https://manifest.${domain}"
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
          image: ${images.manifest-postgres.ref}
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

    docker = mkDockerService {
      name = "manifest";
      inherit composeFile;
      envTemplate = config.sops.templates."manifest-env".path;
      extraServiceConfig = {
        RestartSec = "10s";
      };
      backup = {
        execStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T postgres pg_dump -U manifest manifest > /var/lib/manifest/backup/$(date +%%Y%%m%%d_%%H%%M%%S).sql && find /var/lib/manifest/backup -name \"*.sql\" -mtime +30 -delete'";
      };
    };
  in {
    options.services.manifest = {
      enable = lib.mkEnableOption "Manifest LLM router";
      port = serviceTypes.servicePort ports.manifest "Host port for the Manifest dashboard";
      imageTag = serviceTypes.dockerImageTag images.manifest.tag;
    };

    config = lib.mkIf cfg.enable {
      sops = {
        secrets = builtins.listToAttrs (
          map
          (name: {
            inherit name;
            value = {
              sopsFile = secretsDir + "/manifest.yaml";
              owner = "root";
              group = "root";
              restartUnits = ["manifest.service"];
            };
          })
          [
            "manifest_auth_secret"
            "manifest_encryption_key"
            "manifest_db_password"
          ]
        );
        templates."manifest-env" = {
          content = ''
            AUTH_SECRET=${config.sops.placeholder.manifest_auth_secret}
            ENCRYPTION_KEY=${config.sops.placeholder.manifest_encryption_key}
            DB_PASSWORD=${config.sops.placeholder.manifest_db_password}
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
