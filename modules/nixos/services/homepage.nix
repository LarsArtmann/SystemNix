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
      cacheDir = "/var/cache/homepage-dashboard";

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
      browserHistoryEnabled = config.services.browser-history.enable or false;
      searxEnabled = config.services.searx.enable or false;
      atticEnabled = config.services.attic-config.enable or false;

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
          restartTriggers = [ homepagePkg ];
          # Clear stale Next.js prerender cache on restart.
          # Without this, a package upgrade changes the buildId but old cached
          # pages still reference the old chunk hashes → 404 on _next/static/*.
          # See: nixpkgs#346016, gethomepage/homepage#4560
          preStart = ''
            rm -rf "${cacheDir}"/* 2>/dev/null || true
          '';
          serviceConfig = lib.mkMerge [
            {
              ExecStart = lib.getExe homepagePkg;
              WorkingDirectory = stateDir;
              Environment = [
                "PORT=${toString cfg.port}"
                "HOMEPAGE_CONFIG_DIR=${stateDir}"
                "HOMEPAGE_ALLOWED_HOSTS=dash.${domain}"
                "NIXPKGS_HOMEPAGE_CACHE_DIR=${cacheDir}"
                "NODE_OPTIONS=--max-old-space-size=192"
              ];
              User = "homepage";
              Group = "homepage";
              StateDirectory = "homepage-dashboard";
              CacheDirectory = "homepage-dashboard";
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
              favicon = "/icons/nixos.png";
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
              })
              (mkService "Caddy" {
                description = "Reverse Proxy";
                icon = "caddy.png";
              })
              # Note: dnsblockd is intentionally NOT a separate tile here.
              # The user-facing "DNS Blocker" tile (in Media) already points
              # at https://dnsblock.<domain>/health with a clickable link
              # and a visible status dot. The bare daemon exposes only an
              # internal /metrics endpoint (Prometheus scrapes it directly),
              # which has no value as a clickable dashboard tile.
              # PostgreSQL and Redis are decorative tiles: neither exposes a
              # public HTTP health endpoint (pg_isready is TCP-only; Redis
              # exports to Prometheus only). Their dependents (Immich, Gatus,
              # Manifest) will show errors when the DB/cache goes down — that's
              # the real signal. All service health monitoring is owned by Gatus
              # (Discord alerting). Homepage tiles are navigation only.
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
              }
            )
            ++ lib.optional discordsyncEnabled (
              mkService "DiscordSync" {
                href = svcUrl "discordsync";
                description = "Discord Backup Bot (Messages, Attachments, Reactions)";
                icon = "discord.png";
              }
            )
            ++ lib.optional browserHistoryEnabled (
              mkService "Browser History" {
                href = svcUrl "history";
                description = "Browsing Analytics & Productivity Insights";
              }
            )
            ++ lib.optional atticEnabled (
              mkService "Attic Cache" {
                href = svcUrl "cache";
                description = "Self-hosted Nix Binary Cache (CI build artifacts)";
                icon = "nixos.png";
              }
            );

            mediaServices = [
              (mkService "Immich" {
                href = svcUrl "immich";
                description = "Photo & Video Management";
                icon = "immich.png";
              })
              (mkService "Paperless" {
                href = svcUrl "paperless";
                description = "Document Management (OCR, Scan, Archive)";
                icon = "paperless.png";
              })
              (mkService "DNS Blocker" {
                href = svcUrl "dnsblock";
                description = "DNS Block Stats";
                icon = "blocky.png";
              })
            ];

            devServices = [
              (mkService "Forgejo" {
                href = svcUrl "forgejo";
                description = "Git Forge (GitHub Sync)";
                icon = "forgejo.png";
              })
            ]
            ++ lib.optional overviewEnabled (
              mkService "Overview" {
                href = svcUrl "overview";
                description = "Project Dashboard (Git Repos, Stats, Activity)";
                icon = "code.png";
              }
            );

            aiServices =
              lib.optional crushDailyEnabled (
                mkService "Crush Daily" {
                  href = svcUrl "daily";
                  description = "AI-Powered Development Insights";
                  icon = "openai.png";
                }
              )
              ++ lib.optional manifestEnabled (
                mkService "Manifest" {
                  href = svcUrl "manifest";
                  description = "Smart LLM Router (Cost Optimization)";
                  icon = "openai.png";
                }
              )
              ++ lib.optional ollamaEnabled (
                mkService "Ollama" {
                  description = "Local AI Inference";
                  icon = "ollama.png";
                }
              )
              ++ lib.optionals voiceAgentsEnabled [
                (mkService "LiveKit" {
                  href = svcUrl "voice";
                  description = "Real-Time Voice Infrastructure";
                  icon = "voip-info.png";
                })
                (mkService "Whisper ASR" {
                  href = svcUrl "whisper";
                  description = "Speech-to-Text (Gradio)";
                  icon = "web-whisper.png";
                })
              ];

            monitoringServices =
              lib.optional gatusEnabled (
                mkService "Gatus" {
                  href = svcUrl "status";
                  description = "Uptime & Health Check Dashboard";
                  icon = "gatus.png";
                }
              )
              ++ lib.optional signozEnabled (
                mkService "SigNoz" {
                  href = svcUrl "signoz";
                  description = "Observability Platform (Traces, Metrics, Logs)";
                  icon = "signoz.png";
                }
              )
              ++ lib.optional dozzleEnabled (
                mkService "Dozzle" {
                  href = svcUrl "logs";
                  description = "Docker Log Viewer";
                  icon = "docker.png";
                }
              )
              ++ [
                (mkService "Node Exporter" {
                  description = "System Metrics (CPU, RAM, Disk, Network)";
                  icon = "prometheus.png";
                })
              ]
              ++ lib.optional signozEnabled (
                mkService "cAdvisor" {
                  description = "Container Metrics";
                  icon = "docker.png";
                }
              )
              ++ [
                (mkService "dnsblockd" {
                  # Tile exists for parity with other infra services (Node Exporter,
                  # cAdvisor, EMEET PIXY) that expose a metrics-only health check.
                  description = "Block-page HTTP server (localhost-only)";
                  icon = "blocky.png";
                })
                (mkService "EMEET PIXY" {
                  description = "Webcam Auto-Management Daemon";
                  icon = "camera-ui.png";
                })
              ]
              ++ lib.optional monitor365Enabled (
                mkService "Monitor365" {
                  href = svcUrl "monitor";
                  description = "Device Monitoring Agent";
                  icon = "uptime-kuma.png";
                }
              );

            productivityServices =
              lib.optional twentyEnabled (
                mkService "Twenty CRM" {
                  href = svcUrl "crm";
                  description = "Customer Relationship Management";
                  icon = "espocrm.png";
                }
              )
              ++ lib.optional fileAndImageRenamerEnabled (
                mkService "File Renamer" {
                  href = svcUrl "renamer";
                  description = "AI-Powered File & Image Renaming";
                  # filebot.png: bundled icon pack has no 'mdi-*' mdi-style icons;
                  # filebot is the canonical self-hosted file-rename tool icon.
                  icon = "filebot.png";
                }
              )
              ++ [
                (mkService "Taskwarrior" {
                  href = svcUrl "tasks";
                  description = "Task Sync Server (TaskChampion)";
                  icon = "taskcafe.png";
                })
                # The "Homepage" self-tile was removed: clicking it while
                # already on the dashboard is a no-op (`target = "_self"`
                # would just reload). The dashboard IS the entry point,
                # so a tile pointing to itself adds no value.
                (mkService "OpenSEO" {
                  href = svcUrl "seo";
                  description = "SEO Suite (Rank Tracking, Keywords, Backlinks)";
                  icon = "google-search-console.png";
                })
              ]
              ++ lib.optional searxEnabled (
                mkService "SearXNG" {
                  href = svcUrl "search";
                  description = "Privacy Metasearch Engine";
                  icon = "searxng.png";
                }
              );

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
          "L+ ${stateDir}/bookmarks.yaml - - - - ${
            # Homepage bookmark schema (from src/skeleton/bookmarks.yaml):
            # each service name maps to a LIST of one props object,
            # NOT a bare object. Using a bare object makes Homepage's
            # parser feed the wrong value to `new URL()`, crashing the
            # whole page with "Failed to construct 'URL': Invalid URL".
            (pkgs.formats.yaml { }).generate "bookmarks.yaml" [
              {
                Infrastructure = [
                  {
                    Pocket-ID = [
                      {
                        abbr = "PI";
                        href = svcUrl "auth";
                        description = "Passkey OIDC login";
                      }
                    ];
                  }
                  {
                    Gatus = [
                      {
                        abbr = "GA";
                        href = svcUrl "status";
                        description = "Service uptime dashboard";
                      }
                    ];
                  }
                  {
                    SigNoz = [
                      {
                        abbr = "SN";
                        href = svcUrl "signoz";
                        description = "Traces, metrics, logs";
                      }
                    ];
                  }
                ];
              }
              {
                Development = [
                  {
                    Forgejo = [
                      {
                        abbr = "FJ";
                        href = svcUrl "forgejo";
                        description = "Git forge";
                      }
                    ];
                  }
                  {
                    GitHub = [
                      {
                        abbr = "GH";
                        href = "https://github.com/LarsArtmann";
                        description = "LarsArtmann GitHub";
                      }
                    ];
                  }
                  {
                    "NixOS Options" = [
                      {
                        abbr = "NX";
                        href = "https://search.nixos.org/options";
                        description = "NixOS option search";
                      }
                    ];
                  }
                  {
                    "Nix Package Search" = [
                      {
                        abbr = "NP";
                        href = "https://search.nixos.org/packages";
                        description = "Find packages";
                      }
                    ];
                  }
                ];
              }
              {
                Search = [
                  {
                    DuckDuckGo = [
                      {
                        abbr = "DD";
                        href = "https://duckduckgo.com";
                        description = "Privacy-first search";
                      }
                    ];
                  }
                  {
                    Kagi = [
                      {
                        abbr = "KG";
                        href = "https://kagi.com";
                        description = "Paid, no-ads search";
                      }
                    ];
                  }
                  {
                    SearXNG = [
                      {
                        abbr = "SX";
                        href = svcUrl "search";
                        description = "Self-hosted metasearch";
                      }
                    ];
                  }
                ];
              }
            ]
          }"
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
                search =
                  if searxEnabled then
                    {
                      provider = "custom";
                      url = "https://search.${domain}/search?q=";
                      suggestionsUrl = "https://search.${domain}/autocompleter?q=";
                      target = "_blank";
                      showSearchSuggestions = true;
                    }
                  else
                    {
                      provider = "duckduckgo";
                      target = "_blank";
                      showSearchSuggestions = true;
                    };
              }
              {
                resources = {
                  label = "System";
                  cpu = true;
                  memory = true;
                  cputemp = true;
                  # Strix Halo (AMD Ryzen AI Max+ 395) idle ~50°C, full load
                  # 90-95°C. Bounds below color the gauge green/yellow/red.
                  tempmin = 30;
                  tempmax = 95;
                  network = true;
                  uptime = true;
                };
              }
              {
                # /data is a separate BTRFS partition (per AGENTS.md):
                # Docker volumes, Immich DB, AI models. Losing this disk
                # is the #1 data-loss risk — monitor it explicitly. Disk
                # widget reports usage of the mountpoint passed in.
                resources = {
                  label = "Storage";
                  disk = [
                    "/"
                    "/data"
                  ];
                  expanded = true;
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
