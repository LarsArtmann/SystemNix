# OpenSEO self-hosted SEO suite (keyword research, rank tracking, audits)
_: {
  flake.nixosModules.openseo = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.openseo;
    inherit (config.networking) domain;
    libHelpers = import ../../../lib/default.nix lib;
    inherit (libHelpers) serviceTypes images ports;
    inherit (libHelpers.mkDockerServiceFactory {inherit pkgs;}) mkDockerService;

    composeFile =
      pkgs.writeText "openseo-docker-compose.yml"
      ''
        name: openseo

        services:
          openseo:
            image: ${images.openseo.ref}
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

    docker = mkDockerService {
      name = "openseo";
      inherit composeFile;
      envTemplate = config.sops.templates."openseo-env".path;
      extraHarden = {
        ProtectHome = false;
        NoNewPrivileges = false;
      };
    };
  in {
    options.services.openseo = {
      enable = lib.mkEnableOption "OpenSEO — self-hosted SEO suite (keyword research, rank tracking, backlinks, site audits)";
      port = serviceTypes.servicePort ports.openseo "HTTP port for OpenSEO dashboard";
      imageTag = serviceTypes.dockerImageTag images.openseo.tag;
    };

    config = lib.mkIf cfg.enable {
      systemd.tmpfiles.rules = docker.tmpfiles;
      systemd.services = docker.services;
    };
  };
}
