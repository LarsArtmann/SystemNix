_: {
  flake.nixosModules.openseo = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.openseo;
    inherit (config.networking) domain;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults serviceTypes;

    stateDir = "/var/lib/openseo";

    composeFile =
      pkgs.writeText "openseo-docker-compose.yml"
      ''
        name: openseo

        services:
          openseo:
            image: ghcr.io/every-app/open-seo:${cfg.imageTag}
            restart: unless-stopped
            environment:
              PORT: "${toString cfg.port}"
              AUTH_MODE: local_noauth
              DATAFORSEO_API_KEY: ''${DATAFORSEO_API_KEY}
              ALLOWED_HOST: seo.${domain}
              VITE_SHOW_DEVTOOLS: "false"
              NODE_OPTIONS: "--max-old-space-size=3072"
            ports:
              - "127.0.0.1:${toString cfg.port}:${toString cfg.port}"
            volumes:
              - openseo_data:/app/.wrangler
            tmpfs:
              - /tmp:size=64m
              - /app/node_modules/.vite-temp:size=64m
            security_opt:
              - no-new-privileges:true
            cap_drop:
              - ALL
            mem_limit: 2g
            pids_limit: 100
            logging:
              driver: json-file
              options:
                max-size: "10m"
                max-file: "5"

        volumes:
          openseo_data:
            name: openseo_data
      '';
  in {
    options.services.openseo = {
      enable = lib.mkEnableOption "OpenSEO — self-hosted SEO suite (keyword research, rank tracking, backlinks, site audits)";
      port = serviceTypes.servicePort 3001 "HTTP port for OpenSEO dashboard";
      imageTag = lib.mkOption {
        type = lib.types.str;
        default = "latest";
        description = "Docker image tag for ghcr.io/every-app/open-seo";
      };
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = [
        "d ${stateDir} 0755 root root -"
      ];

      systemd.services.openseo = {
        description = "OpenSEO — Self-hosted SEO suite";
        after = ["docker.service" "sops-nix.service"];
        requires = ["docker.service"];
        wants = ["sops-nix.service"];
        wantedBy = ["multi-user.target"];
        path = [pkgs.docker pkgs.docker-compose];

        preStart = ''
          rm -f ${stateDir}/.env
          ${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} down --remove-orphans || true
          install -m 600 ${config.sops.templates."openseo-env".path} ${stateDir}/.env
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
            ProtectHome = false;
            NoNewPrivileges = false;
          }
          // serviceDefaults {};
      };
    };
  };
}
