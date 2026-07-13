# Homepage Dashboard with Catppuccin theme and service status monitoring
# SSO: Homepage has NO built-in authentication. By design it relies on an
# external reverse proxy. Access is gated by oauth2-proxy forward-auth
# (Layer 2 SSO) on dash.<domain> — this is intentional, not a gap.
_: {
  flake.nixosModules.homepage =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.homepage;
      inherit (config.networking) domain;
      stateDir = "/var/lib/homepage-dashboard";

      # enableLocalIcons bundles the homarr-labs/dashboard-icons pack into
      # public/icons/ — without it, every service icon request 404s
      homepagePkg = pkgs.homepage-dashboard.override { enableLocalIcons = true; };

      svcUrl = subdomain: "https://${subdomain}.${domain}";
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        serviceTypes
        mkStateDir
        ports
        ;

      hasContainer = name: config.virtualisation.oci-containers.containers ? ${name};

      signozEnabled = config.services.signoz.enable;
      twentyEnabled = config.services.twenty.enable;
      manifestEnabled = config.services.manifest.enable;
      ollamaEnabled = config.services.ai-stack.enable;
      crushDailyEnabled = config.services.crush-daily.enable;
      gatusEnabled = config.services.gatus-config.enable;
      dozzleEnabled = hasContainer "dozzle";
      hermesEnabled = config.services.hermes.enable;
      monitor365Enabled = config.services.monitor365-server.enable or false;
      voiceAgentsEnabled = config.services.voice-agents.enable;
      discordsyncEnabled = config.services.discordsync.enable;
      overviewEnabled = config.services.overview.enable;
      fileAndImageRenamerEnabled = config.services.file-and-image-renamer.enable or false;

      theme = import ../../../platforms/common/theme.nix;
      colors = theme.colorScheme.palette;
    in
    {
      options.services.homepage = {
        enable = lib.mkEnableOption "Homepage Dashboard service";
        port = serviceTypes.servicePort ports.homepage "HTTP port for Homepage Dashboard";
      };

      config = lib.mkIf cfg.enable {
        systemd.services.homepage-dashboard = {
          description = "Homepage Dashboard";
          inherit onFailure;
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              ExecStart = lib.getExe homepagePkg;
              WorkingDirectory = stateDir;
              Environment = [
                "PORT=${toString cfg.port}"
                "HOMEPAGE_CONFIG_DIR=${stateDir}"
                "HOMEPAGE_ALLOWED_HOSTS=dash.${domain}"
                "NODE_OPTIONS=--max-old-space-size=192"
              ];
              User = "homepage";
              Group = "homepage";
              StateDirectory = "homepage-dashboard";
            }
            (harden { MemoryMax = "384M"; })
            (serviceDefaults { })
          ];
        };

        users.users.homepage = {
          isSystemUser = true;
          group = "homepage";
          home = stateDir;
        };
        users.groups.homepage = { };

        environment.etc."homepage/settings.yaml".source =
          (pkgs.formats.yaml { }).generate "homepage-settings.yaml"
            {
              title = "evo-x2";
              favicon = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/nixos.png";
              theme = "dark";
              color = "slate";
              headerStyle = "boxed";
              hideVersion = true;
              disableUpdateCheck = true;
              useEqualHeights = true;
              target = "_blank";
              quicklaunch = {
                searchDescriptions = true;
                hideInternetSearch = false;
                showSearchSuggestions = true;
              };
              layout = {
                Infrastructure = {
                  style = "row";
                  columns = 4;
                };
                Media = {
                  style = "row";
                  columns = 4;
                };
                Development = {
                  style = "row";
                  columns = 4;
                };
                AI = {
                  style = "row";
                  columns = 4;
                };
                Monitoring = {
                  style = "row";
                  columns = 4;
                };
                Productivity = {
                  style = "row";
                  columns = 4;
                };
              };
            };

        environment.etc."homepage/services.yaml".source =
          let
            mkService = name: props: { ${name} = props; };

            infraServices = [
              (mkService "Pocket ID" {
                href = svcUrl "auth";
                description = "Passkey OIDC Provider";
                icon = "pocket-id.png";
                statusStyle = "dot";
                siteMonitor = "${svcUrl "auth"}/healthz";
              })
              (mkService "Caddy" {
                href = svcUrl "dash";
                description = "Reverse Proxy";
                icon = "caddy.png";
                statusStyle = "dot";
                siteMonitor = svcUrl "dash";
              })
              (mkService "dnsblockd" {
                description = "DNS Resolver + Blocker";
                icon = "adguard-home.png";
                statusStyle = "dot";
              })
              (mkService "PostgreSQL" {
                description = "Database Server";
                icon = "postgres.png";
              })
              (mkService "Redis" {
                description = "Cache (Immich)";
                icon = "redis.png";
              })
            ]
            ++ lib.optional hermesEnabled (
              mkService "Hermes" {
                description = "AI Agent Gateway (Discord, Cron, Messaging)";
                icon = "self-hosted-gateway.png";
                statusStyle = "dot";
              }
            )
            ++ lib.optional discordsyncEnabled (
              mkService "DiscordSync" {
                href = svcUrl "discordsync";
                description = "Discord Backup Bot (Messages, Attachments, Reactions)";
                icon = "discord.png";
                statusStyle = "dot";
                siteMonitor = "http://localhost:${toString ports.discordsync-api}/healthz";
              }
            );

            mediaServices = [
              (mkService "Immich" {
                href = svcUrl "immich";
                description = "Photo & Video Management";
                icon = "immich.png";
                statusStyle = "dot";
                siteMonitor = "${svcUrl "immich"}/api/server/ping";
              })
              (mkService "DNS Blocker" {
                href = "http://localhost:${toString config.services.dns-blocker.statsPort}/stats";
                description = "DNS Block Stats";
                icon = "blocky.png";
                statusStyle = "dot";
                siteMonitor = "http://localhost:${toString config.services.dns-blocker.statsPort}/health";
              })
            ];

            devServices = [
              (mkService "Forgejo" {
                href = svcUrl "forgejo";
                description = "Git Forge (GitHub Sync)";
                icon = "forgejo.png";
                statusStyle = "dot";
                siteMonitor = "${svcUrl "forgejo"}/api/v1/nodeinfo";
              })
            ]
            ++ lib.optional overviewEnabled (
              mkService "Overview" {
                href = svcUrl "overview";
                description = "Project Dashboard (Git Repos, Stats, Activity)";
                icon = "code.png";
                statusStyle = "dot";
                siteMonitor = "http://localhost:${toString ports.overview}";
              }
            );

            aiServices =
              lib.optional crushDailyEnabled (
                mkService "Crush Daily" {
                  href = svcUrl "daily";
                  description = "AI-Powered Development Insights";
                  icon = "openai.png";
                  statusStyle = "dot";
                  siteMonitor = "${svcUrl "daily"}/api/health";
                }
              )
              ++ lib.optional manifestEnabled (
                mkService "Manifest" {
                  href = svcUrl "manifest";
                  description = "Smart LLM Router (Cost Optimization)";
                  icon = "openai.png";
                  statusStyle = "dot";
                  siteMonitor = "${svcUrl "manifest"}/api/v1/health";
                }
              )
              ++ lib.optional ollamaEnabled (
                mkService "Ollama" {
                  description = "Local AI Inference";
                  icon = "ollama.png";
                  statusStyle = "dot";
                  siteMonitor = "http://localhost:${toString config.services.ollama.port}/api/tags";
                }
              )
              ++ lib.optionals voiceAgentsEnabled [
                (mkService "LiveKit" {
                  href = svcUrl "voice";
                  description = "Real-Time Voice Infrastructure";
                  icon = "voip-info.png";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "voice";
                })
                (mkService "Whisper ASR" {
                  href = svcUrl "whisper";
                  description = "Speech-to-Text (Gradio)";
                  icon = "web-whisper.png";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "whisper";
                })
              ];

            monitoringServices =
              lib.optional gatusEnabled (
                mkService "Gatus" {
                  href = svcUrl "status";
                  description = "Uptime & Health Check Dashboard";
                  icon = "gatus.png";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "status";
                }
              )
              ++ lib.optional signozEnabled (
                mkService "SigNoz" {
                  href = svcUrl "signoz";
                  description = "Observability Platform (Traces, Metrics, Logs)";
                  icon = "signoz.png";
                  statusStyle = "dot";
                  siteMonitor = "http://localhost:${toString config.services.signoz.settings.queryService.port}";
                }
              )
              ++ lib.optional dozzleEnabled (
                mkService "Dozzle" {
                  href = svcUrl "logs";
                  description = "Docker Log Viewer";
                  icon = "docker.png";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "logs";
                }
              )
              ++ [
                (mkService "Node Exporter" {
                  description = "System Metrics (CPU, RAM, Disk, Network)";
                  icon = "prometheus.png";
                  statusStyle = "dot";
                  siteMonitor = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                })
              ]
              ++ lib.optional signozEnabled (
                mkService "cAdvisor" {
                  description = "Container Metrics";
                  icon = "docker.png";
                  statusStyle = "dot";
                  siteMonitor = "http://localhost:${toString config.services.signoz.settings.cadvisorPort}/metrics";
                }
              )
              ++ [
                (mkService "dnsblockd" {
                  description = "DNS Block Page Server";
                  icon = "blocky.png";
                  statusStyle = "dot";
                  siteMonitor = "http://localhost:${toString config.services.dns-blocker.statsPort}/metrics";
                })
                (mkService "EMEET PIXY" {
                  description = "Webcam Auto-Management Daemon";
                  icon = "camera-ui.png";
                  statusStyle = "dot";
                  siteMonitor = "http://localhost:${toString ports.emeet-pixyd}/metrics";
                })
              ]
              ++ lib.optional monitor365Enabled (
                mkService "Monitor365" {
                  href = svcUrl "monitor";
                  description = "Device Monitoring Agent";
                  icon = "uptime-kuma.png";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "monitor";
                }
              );

            productivityServices =
              lib.optional twentyEnabled (
                mkService "Twenty CRM" {
                  href = svcUrl "crm";
                  description = "Customer Relationship Management";
                  icon = "espocrm.png";
                  statusStyle = "dot";
                  siteMonitor = "${svcUrl "crm"}/healthz";
                }
              )
              ++ lib.optional fileAndImageRenamerEnabled (
                mkService "File Renamer" {
                  href = svcUrl "renamer";
                  description = "AI-Powered File & Image Renaming";
                  icon = "mdi-file-rename-outline";
                  statusStyle = "dot";
                  siteMonitor = "http://localhost:${toString ports.file-and-image-renamer-health}/status";
                }
              )
              ++ [
                (mkService "Taskwarrior" {
                  href = svcUrl "tasks";
                  description = "Task Sync Server (TaskChampion)";
                  icon = "taskcafe.png";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "tasks";
                })
                (mkService "Homepage" {
                  description = "This Page";
                  icon = "homepage.png";
                  target = "_self";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "dash";
                })
                (mkService "OpenSEO" {
                  href = svcUrl "seo";
                  description = "SEO Suite (Rank Tracking, Keywords, Backlinks)";
                  icon = "google-search-console.png";
                  statusStyle = "dot";
                  siteMonitor = svcUrl "seo";
                })
              ];

            groups = [
              { Infrastructure = infraServices; }
              { Media = mediaServices; }
              { Development = devServices; }
            ]
            ++ lib.optional (aiServices != [ ]) { AI = aiServices; }
            ++ [
              { Monitoring = monitoringServices; }
              { Productivity = productivityServices; }
            ];
          in
          (pkgs.formats.yaml { }).generate "homepage-services.yaml" groups;

        systemd.tmpfiles.rules = [
          (mkStateDir stateDir "0755" "homepage" "homepage")
          "d /var/cache/homepage-dashboard 0755 homepage homepage -"
          "L+ ${stateDir}/services.yaml - - - - /etc/homepage/services.yaml"
          "L+ ${stateDir}/settings.yaml - - - - /etc/homepage/settings.yaml"
          "L+ ${stateDir}/bookmarks.yaml - - - - ${pkgs.writeText "bookmarks.yaml" ""}"
          "L+ ${stateDir}/widgets.yaml - - - - ${
            (pkgs.formats.yaml { }).generate "widgets.yaml" [
              { greeting.text = "evo-x2 Dashboard"; }
              {
                datetime = {
                  text_size = "xl";
                  format = {
                    timeStyle = "short";
                    dateStyle = "medium";
                  };
                };
              }
              {
                search = {
                  provider = "duckduckgo";
                  target = "_blank";
                  showSearchSuggestions = true;
                };
              }
              {
                resources = {
                  cpu = true;
                  memory = true;
                  disk = "/";
                  cputemp = true;
                  network = true;
                  uptime = true;
                };
              }
            ]
          }"
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
