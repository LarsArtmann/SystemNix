# Homepage Dashboard with Catppuccin theme and service status monitoring
_: {
  flake.nixosModules.homepage = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.services.homepage;
    inherit (config.networking) domain;
    stateDir = "/var/lib/homepage-dashboard";

    svcUrl = subdomain: "https://${subdomain}.${domain}";
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure serviceTypes mkStateDir ports;
    theme = import ../../../platforms/common/theme.nix;
    colors = theme.colorScheme.palette;
  in {
    options.services.homepage = {
      enable = lib.mkEnableOption "Homepage Dashboard service";
      port = serviceTypes.servicePort ports.homepage "HTTP port for Homepage Dashboard";
    };

    config = lib.mkIf cfg.enable {
      systemd.services.homepage-dashboard = {
        description = "Homepage Dashboard";
        inherit onFailure;
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig =
          {
            ExecStart = lib.getExe pkgs.homepage-dashboard;
            WorkingDirectory = stateDir;
            Environment = [
              "PORT=${toString cfg.port}"
              "HOMEPAGE_CONFIG_DIR=${stateDir}"
              "NODE_OPTIONS=--max-old-space-size=192"
            ];
            User = "homepage";
            Group = "homepage";
            StateDirectory = "homepage-dashboard";
          }
          // harden {MemoryMax = "384M";}
          // serviceDefaults {};
      };

      users.users.homepage = {
        isSystemUser = true;
        group = "homepage";
        home = stateDir;
      };
      users.groups.homepage = {};

      environment.etc."homepage/settings.yaml".source = pkgs.writeText "homepage-settings.yaml" ''
        title: evo-x2
        favicon: https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/nixos.png
        theme: dark
        color: slate
        headerStyle: boxed
        layout:
          Infrastructure:
            style: row
            columns: 4
          Media:
            style: row
            columns: 4
          Development:
            style: row
            columns: 4
          Productivity:
            style: row
            columns: 4
          Monitoring:
            style: row
            columns: 4
      '';

      environment.etc."homepage/services.yaml".source = pkgs.writeText "homepage-services.yaml" ''
        - Infrastructure:
            - Pocket ID:
                href: ${svcUrl "auth"}
                description: Passkey OIDC Provider
                icon: pocket-id.png
                statusStyle: dot
                siteMonitor: ${svcUrl "auth"}/healthz
            - Caddy:
                href: ${svcUrl "dash"}
                description: Reverse Proxy
                icon: caddy.png
                statusStyle: dot
                siteMonitor: ${svcUrl "dash"}
            - Unbound DNS:
                description: DNS Resolver + Blocker
                icon: unbound.png
                statusStyle: dot
                # DNS runs on UDP/TCP 53 - no HTTP health check available
            - PostgreSQL:
                description: Database Server
                icon: postgres.png
            - Redis:
                description: Cache (Immich)
                icon: redis.png

        - Media:
            - Immich:
                href: ${svcUrl "immich"}
                description: Photo & Video Management
                icon: immich.png
                statusStyle: dot
                siteMonitor: ${svcUrl "immich"}/api/server-info/ping
            - DNS Blocker:
                href: http://localhost:${toString config.services.dns-blocker.statsPort}/stats
                description: DNS Block Stats
                icon: shield.png
                statusStyle: dot
                siteMonitor: http://localhost:${toString config.services.dns-blocker.statsPort}/health

        - Development:
            - Forgejo:
                href: ${svcUrl "forgejo"}
                description: Git Forge (GitHub Sync)
                icon: forgejo.png
                statusStyle: dot
                siteMonitor: ${svcUrl "forgejo"}/api/v1/nodeinfo
            - Ollama:
                description: Local AI Inference
                icon: ollama.png
                statusStyle: dot
                siteMonitor: http://localhost:${toString config.services.ollama.port}/api/tags

        - Monitoring:
            - SigNoz:
                href: ${svcUrl "signoz"}
                description: Observability Platform (Traces, Metrics, Logs)
                icon: signoz.png
                statusStyle: dot
                siteMonitor: ${svcUrl "signoz"}
            - Manifest:
                href: ${svcUrl "manifest"}
                description: Smart LLM Router (Cost Optimization)
                icon: ai.png
                statusStyle: dot
                siteMonitor: ${svcUrl "manifest"}/api/v1/health
            - Node Exporter:
                description: System Metrics (CPU, RAM, Disk, Network)
                icon: prometheus.png
                statusStyle: dot
                siteMonitor: http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics
            - cAdvisor:
                description: Container Metrics
                icon: docker.png
                statusStyle: dot
                siteMonitor: http://localhost:${toString config.services.signoz.settings.cadvisorPort}/metrics
            - dnsblockd:
                description: DNS Block Page Server
                icon: shield.png
                statusStyle: dot
                siteMonitor: http://localhost:${toString config.services.dns-blocker.statsPort}/metrics
            - EMEET PIXY:
                description: Webcam Auto-Management Daemon
                icon: camera.png
                statusStyle: dot
                siteMonitor: http://localhost:${toString ports.emeet-pixyd}/metrics

        - Productivity:
            - Twenty CRM:
                href: ${svcUrl "crm"}
                description: Customer Relationship Management
                icon: twenty.png
                statusStyle: dot
                siteMonitor: ${svcUrl "crm"}/healthz
            - Taskwarrior:
                href: ${svcUrl "tasks"}
                description: Task Sync Server (TaskChampion)
                icon: taskwarrior.png
                statusStyle: dot
                siteMonitor: ${svcUrl "tasks"}

            - Homepage:
                description: This Page
                icon: homepage.png
                statusStyle: dot
                siteMonitor: ${svcUrl "dash"}
            - OpenSEO:
                href: ${svcUrl "seo"}
                description: SEO Suite (Rank Tracking, Keywords, Backlinks)
                icon: search.png
                statusStyle: dot
                siteMonitor: ${svcUrl "seo"}
      '';

      systemd.tmpfiles.rules = [
        (mkStateDir stateDir "0755" "homepage" "homepage")
        "L+ ${stateDir}/services.yaml - - - - /etc/homepage/services.yaml"
        "L+ ${stateDir}/settings.yaml - - - - /etc/homepage/settings.yaml"
        "L+ ${stateDir}/bookmarks.yaml - - - - ${pkgs.writeText "bookmarks.yaml" ""}"
        "L+ ${stateDir}/widgets.yaml - - - - ${pkgs.writeText "widgets.yaml" ''
          - greeting:
              text: evo-x2 Dashboard
          - resources:
              cpu: true
              memory: true
              disk: /
              uptime: true
        ''}"
        "L+ ${stateDir}/docker.yaml - - - - ${pkgs.writeText "docker.yaml" ""}"
        "L+ ${stateDir}/custom.css - - - - ${pkgs.writeText "custom.css" ''
          :root {
            --catppuccin-base: #${colors.base00};
            --catppuccin-mantle: #${colors.base01};
            --catppuccin-crust: #${colors.crust};
            --catppuccin-surface0: #${colors.base02};
            --catppuccin-surface1: #${colors.base03};
            --catppuccin-overlay0: #${colors.overlay0};
            --catppuccin-text: #${colors.base05};
            --catppuccin-subtext: #${colors.subtext0};
            --catppuccin-lavender: #${colors.base07};
            --catppuccin-blue: #${colors.base0D};
            --catppuccin-green: #${colors.base0B};
            --catppuccin-red: #${colors.base08};
          }
          body { background-color: var(--catppuccin-crust) !important; color: var(--catppuccin-text) !important; }
          .page { background-color: var(--catppuccin-base) !important; }
          .service-card { background-color: var(--catppuccin-surface0) !important; border-radius: 12px !important; border: 1px solid var(--catppuccin-surface1) !important; color: var(--catppuccin-text) !important; }
          .service-card:hover { border-color: var(--catppuccin-blue) !important; box-shadow: 0 4px 12px #${colors.base0D}26 !important; }
          .service-card .service-name { color: var(--catppuccin-text) !important; }
          .service-card .service-description { color: var(--catppuccin-subtext) !important; }
          .service-card .service-url { color: var(--catppuccin-lavender) !important; }
          .group-heading { color: var(--catppuccin-lavender) !important; border-bottom: 1px solid var(--catppuccin-surface1) !important; }
          .widget { background-color: var(--catppuccin-mantle) !important; color: var(--catppuccin-text) !important; }
          .greeting-widget { color: var(--catppuccin-lavender) !important; }
          .resources-widget .resource-label { color: var(--catppuccin-subtext) !important; }
          .resources-widget .resource-value { color: var(--catppuccin-green) !important; }
          .status-dot.online { background-color: var(--catppuccin-green) !important; }
          .status-dot.offline { background-color: var(--catppuccin-red) !important; }
          .icon { color: var(--catppuccin-lavender) !important; }
          a { color: var(--catppuccin-blue) !important; }
          ::-webkit-scrollbar { width: 6px; }
          ::-webkit-scrollbar-track { background: var(--catppuccin-crust); }
          ::-webkit-scrollbar-thumb { background: var(--catppuccin-surface1); border-radius: 3px; }
          ::-webkit-scrollbar-thumb:hover { background: var(--catppuccin-overlay0); }
        ''}"
      ];
    };
  };
}
