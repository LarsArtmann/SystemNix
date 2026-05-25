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
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure serviceTypes mkStateDir;
  in {
    options.services.homepage = {
      enable = lib.mkEnableOption "Homepage Dashboard service";
      port = serviceTypes.servicePort 8082 "HTTP port for Homepage Dashboard";
    };

    config = lib.mkIf cfg.enable {
      systemd.services.homepage-dashboard = {
        description = "Homepage Dashboard";
        inherit onFailure;
        wantedBy = ["multi-user.target"];
        after = ["network.target"];
        serviceConfig =
          {
            ExecStart = "${pkgs.homepage-dashboard}/bin/homepage";
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
                siteMonitor: http://localhost:8090/metrics

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
            --catppuccin-base: #1e1e2e;
            --catppuccin-mantle: #181825;
            --catppuccin-crust: #11111b;
            --catppuccin-surface0: #313244;
            --catppuccin-surface1: #45475a;
            --catppuccin-overlay0: #6c7086;
            --catppuccin-text: #cdd6f4;
            --catppuccin-subtext: #a6adc8;
            --catppuccin-lavender: #b4befe;
            --catppuccin-blue: #89b4fa;
            --catppuccin-green: #a6e3a1;
            --catppuccin-red: #f38ba8;
          }
          body { background-color: var(--catppuccin-crust) !important; color: var(--catppuccin-text) !important; }
          .page { background-color: var(--catppuccin-base) !important; }
          .service-card { background-color: var(--catppuccin-surface0) !important; border-radius: 12px !important; border: 1px solid var(--catppuccin-surface1) !important; color: var(--catppuccin-text) !important; }
          .service-card:hover { border-color: var(--catppuccin-blue) !important; box-shadow: 0 4px 12px rgba(137,180,250,0.15) !important; }
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
