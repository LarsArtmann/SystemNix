# PapDashboard — event-sourced alert hub with NPU insight enricher
#
# Architecture (smart alerting, 2026-08):
#
#   Gatus ──(raw fast-path)──────────────────────────► Discord
#      │
#      └─(custom alerting provider, POST /api/ingest)► PapDashboard
#                                                        │ alert lifecycle (UI/SSE)
#                                                        ▼
#                                          insight enricher (this service)
#                                          correlates storm → collects evidence
#                                          (journalctl + HTTP metrics) → asks
#                                          FastFlowLM (NPU) for root cause →
#                                          publishes sourceApp="insight"
#                                                        │
#                                                        ▼
#                                          outbound Discord (FILTERED to
#                                          PAP_NOTIFY_SOURCE_APPS=insight)
#
# The raw Gatus→Discord path stays untouched (no single point of failure):
# if PapDashboard dies, raw alerts still flow. PapDashboard's outbound is
# filtered to insights only and targets its OWN webhook (sops
# papdashboard_insights_webhook_url), so raw alerts and LLM insights land
# in two separate Discord channels.
#
# The UI has no built-in auth (only the ingest API is key-gated) — external
# access goes through protectedVHost (Layer 2 SSO); LAN access is open.
#
# FastFlowLM cold-loads 2-5 min on first insight request (socket activation
# on :52625 wakes the model; v1.0.2 weights are 21.6 GB) — hence the generous
# default LLM timeout (upstream 300s default is marginal at the boundary).
{
  inputs,
  ...
}:
{
  flake.nixosModules.papdashboard =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.papdashboard;
      inherit (config.networking) domain;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        serviceTypes
        mkSecretCheck
        ioTier
        ports
        ;

      papdashboardPkg = inputs.papdashboard.packages.${pkgs.stdenv.hostPlatform.system}.server;

      checkEnv = mkSecretCheck pkgs {
        name = "papdashboard-env";
        secretPath = config.sops.templates."papdashboard-env".path;
        message = "papdashboard: environment file is missing or empty (${
          config.sops.templates."papdashboard-env".path
        }) — API-key-gated ingest and outbound Discord will misbehave";
      };

      svcUrl = subdomain: "https://${subdomain}.${domain}";

      # Not a dashboard option: the SearXNG gate decides the default search
      # provider and the Search bookmark group (the SearXNG tile itself moved
      # to services.integration.searxng.homepage).
      searxEnabled = config.services.searx.enable or false;

      # Extra tile from the services.integration registry fan-out. `icon` is
      # accepted for registry-shape compatibility but ignored: PapDashboard
      # renders monogram tiles, not an icon pack.
      tileJson =
        t:
        {
          name = t.name;
        }
        // lib.optionalAttrs (t.href != null) { href = t.href; }
        // lib.optionalAttrs (t.description != null) { description = t.description; };

      # Registry fan-out fold: a tile lands in the group whose name matches,
      # or opens a new group at the end. Mirrors homepage.nix's addTile so
      # registry tiles keep their canonical group position; groups whose
      # built-in list is empty are kept in the option default for positioning
      # and filtered here after the fold.
      addTile =
        accGroups: tile:
        let
          groupName = tile.group;
        in
        if lib.any (g: g.name == groupName) accGroups then
          map (g: if g.name == groupName then g // { tiles = g.tiles ++ [ tile ]; } else g) accGroups
        else
          accGroups
          ++ [
            {
              name = groupName;
              tiles = [ tile ];
            }
          ];

      allGroups = builtins.filter (g: g.tiles != [ ]) (
        builtins.foldl' addTile cfg.dashboard.groups cfg.extraTiles
      );

      servicesConfig = (pkgs.formats.json { }).generate "services.json" (
        {
          title = cfg.dashboard.title;
          system = {
            disks = cfg.dashboard.system.disks;
            tempMin = cfg.dashboard.system.tempMin;
            tempMax = cfg.dashboard.system.tempMax;
          };
          groups = map (g: {
            name = g.name;
            tiles = map tileJson g.tiles;
          }) allGroups;
        }
        // lib.optionalAttrs (cfg.dashboard.search != null) {
          search = {
            inherit (cfg.dashboard.search) name url;
          };
        }
        // lib.optionalAttrs (cfg.dashboard.bookmarks != [ ]) {
          bookmarks = map (b: {
            name = b.name;
            links = map (
              l:
              {
                name = l.name;
                href = l.href;
              }
              // lib.optionalAttrs (l.abbr != null) { abbr = l.abbr; }
              // lib.optionalAttrs (l.description != null) { description = l.description; }
            ) b.links;
          }) cfg.dashboard.bookmarks;
        }
      );

      # Drift guard for the rendered services.json. PapDashboard reads the
      # file ONCE at startup — later drift (empty render, partial write,
      # format regression) leaves the Services tab silently empty until the
      # next restart. This collector folds the file's health into
      # node_exporter textfile metrics so the Gatus check fails closed
      # (metric line absent = red) even when the collector itself dies.
      servicesJsonCheck = pkgs.writeShellApplication {
        name = "papdashboard-services-json-check";
        runtimeInputs = [
          pkgs.jq
          pkgs.coreutils
        ];
        text = ''
          OUT="/var/lib/prometheus-node-exporter/textfile_collectors/papdashboard_services.prom"
          CFG="/etc/papdashboard/services.json"
          # Unique tmp per run (mktemp): a fixed .tmp name collides with
          # stale foreign-owned leftovers in the sticky 1777 textfile dir.
          mkdir -p "/var/lib/prometheus-node-exporter/textfile_collectors"
          TMP="$(mktemp "/var/lib/prometheus-node-exporter/textfile_collectors/papdashboard_services.prom.XXXXXX")"
          chmod 644 "$TMP"
          trap 'rm -f "$TMP"' EXIT

          ok=0
          groups=0
          tiles=0
          # Single parse gate: jq -e exits non-zero on invalid JSON or a
          # false expression, so the counting jq below only runs on a
          # verified-parsable file (set -e would abort the unit on an
          # unguarded failing assignment otherwise).
          if [ -r "$CFG" ] && jq -e '(.groups | type == "array") and (.groups | length > 0)' "$CFG" >/dev/null 2>&1; then
            groups="$(jq -r '.groups | length' "$CFG" 2>/dev/null || echo 0)"
            tiles="$(jq -r '[.groups[]? | (.tiles // []) | length] | add // 0' "$CFG" 2>/dev/null || echo 0)"
            if [ "$groups" -gt 0 ] && [ "$tiles" -gt 0 ]; then
              ok=1
            fi
          fi

          {
            echo "# HELP papdashboard_services_json_ok Rendered services.json readable, valid JSON, and non-empty (1 = healthy)"
            echo "# TYPE papdashboard_services_json_ok gauge"
            echo "papdashboard_services_json_ok $ok"
            echo "# HELP papdashboard_services_json_groups Tile groups in the rendered services.json"
            echo "# TYPE papdashboard_services_json_groups gauge"
            echo "papdashboard_services_json_groups $groups"
            echo "# HELP papdashboard_services_json_tiles Dashboard tiles in the rendered services.json"
            echo "# TYPE papdashboard_services_json_tiles gauge"
            echo "papdashboard_services_json_tiles $tiles"
          } >"$TMP"

          mv "$TMP" "$OUT"
        '';
      };

      # The drift check probes the host's node_exporter /metrics (same
      # surface as every other textfile-metric check); fall back to the
      # registered port for hosts without the signoz exporter module.
      nodeExporterPort = config.services.prometheus.exporters.node.port or ports.signoz-node-exporter;
    in
    {
      options.services.papdashboard = {
        enable = lib.mkEnableOption "PapDashboard alert hub with NPU insight enricher";

        package = lib.mkOption {
          type = lib.types.package;
          default = papdashboardPkg;
          description = "PapDashboard server package.";
        };

        port = serviceTypes.servicePort ports.papdashboard "HTTP port for PapDashboard";

        environment = lib.mkOption {
          type = lib.types.enum [
            "production"
            "development"
          ];
          default = "production";
          description = "PAP_ENV for the server (development enables extra debug routes).";
        };

        llmBaseUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:${toString ports.fastflowlm}/v1";
          description = "OpenAI-compatible LLM API root for insight generation (FastFlowLM NPU).";
        };

        llmModel = lib.mkOption {
          type = lib.types.str;
          default = "qwen3.6-moe:35b-a3b";
          description = "Model name for insight generation.";
        };

        journalUnits = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "gatus.service"
            "caddy.service"
            "dnsblockd.service"
          ];
          description = "systemd units whose recent journal entries are collected as LLM evidence.";
        };

        evidenceURLs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "node-metrics=http://localhost:${toString ports.signoz-node-exporter}/metrics"
          ];
          description = ''Extra evidence endpoints as "label=url" entries (comma-joined into PAP_INSIGHT_EVIDENCE_URLS).'';
        };

        notifySourceApps = lib.mkOption {
          type = lib.types.str;
          default = "insight";
          description = "Comma-separated sourceApp allowlist for OUTBOUND notifications (insights only by default).";
        };

        # Services dashboard surface (the former homepage-dashboard, merged
        # 2026-09): rendered to /etc/papdashboard/services.json and consumed
        # via PAP_SERVICES_CONFIG. Tile status is probed SERVER-SIDE by
        # PapDashboard itself (http probes against href; ≥500 = down);
        # uptime history stays with Gatus.
        extraTiles = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Tile label shown on the dashboard";
                };
                group = lib.mkOption {
                  type = lib.types.str;
                  description = ''
                    Dashboard group the tile belongs to (existing group name
                    appends to that group; any other name opens a new group).
                  '';
                };
                href = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Link target; also the default probe URL (omit for decorative tiles)";
                };
                description = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Tile subtitle";
                };
                icon = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Registry-shape compatibility with services.integration
                    (…homepage tiles); accepted but ignored — PapDashboard
                    renders monogram tiles.
                  '';
                };
              };
            }
          );
          default = [ ];
          description = "Registry-managed dashboard tiles (services.integration fan-out)";
        };

        dashboard = {
          title = lib.mkOption {
            type = lib.types.str;
            default = config.networking.hostName;
            defaultText = lib.literalExpression "config.networking.hostName";
            description = "Dashboard title.";
          };

          search = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Provider label shown in the search box";
                  };
                  url = lib.mkOption {
                    type = lib.types.str;
                    description = "Search URL template ending in the query parameter (e.g. …/search?q=)";
                  };
                };
              }
            );
            default = {
              name = if searxEnabled then "SearXNG" else "DuckDuckGo";
              url = if searxEnabled then "https://search.${domain}/search?q=" else "https://duckduckgo.com/?q=";
            };
            description = "Quick-search provider (SearXNG when enabled, DuckDuckGo otherwise).";
          };

          system = {
            disks = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "/"
                "/data"
                "/mnt/pool"
              ];
              description = ''
                Filesystem paths shown in the stats strip. /data is a separate
                BTRFS partition (Docker volumes, Immich DB, AI models); /mnt/pool
                is the 2×16TB BTRFS RAID1 HDD pool receiving ALL backups
                (btrbk sends, forgejo/pocket-id dumps, Docker pg_dumps,
                Drive mirror): the highest-stakes mount on the box.
              '';
            };
            tempMin = lib.mkOption {
              type = lib.types.number;
              default = 30;
              description = ''
                Temperature gauge lower bound (°C). Strix Halo (AMD Ryzen AI
                Max+ 395) idles ~50°C, full load 90-95°C — bounds below color
                the gauge green/yellow/red.
              '';
            };
            tempMax = lib.mkOption {
              type = lib.types.number;
              default = 95;
              description = "Temperature gauge upper bound (°C).";
            };
          };

          groups = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Group heading on the dashboard";
                  };
                  tiles = lib.mkOption {
                    type = lib.types.listOf (
                      lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            description = "Tile label";
                          };
                          href = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Link target; probed server-side when set (omit for decorative tiles)";
                          };
                          description = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Tile subtitle";
                          };
                          checkUrl = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Override probe URL (default: href)";
                          };
                        };
                      }
                    );
                    default = [ ];
                    description = "Tiles in this group";
                  };
                };
              }
            );
            default = [
              {
                name = "Infrastructure";
                tiles = [
                  {
                    name = "Pocket ID";
                    href = svcUrl "auth";
                    description = "Passkey OIDC Provider";
                  }
                  {
                    name = "Caddy";
                    description = "Reverse Proxy";
                  }
                  # PostgreSQL and Redis are decorative tiles: neither exposes
                  # a public HTTP health endpoint (pg_isready is TCP-only;
                  # Redis exports to Prometheus only). Their dependents
                  # (Immich, Gatus, Manifest) show errors when the DB/cache
                  # goes down — that's the real signal. All service health
                  # monitoring is owned by Gatus (Discord alerting); dashboard
                  # tiles are navigation, the dots are live probes.
                  {
                    name = "PostgreSQL";
                    description = "Database Server";
                  }
                  {
                    name = "Redis";
                    description = "Cache (Immich)";
                  }
                ];
              }
              # Kept (even when empty) so registry tiles land in their
              # canonical group position — a registry-only group would
              # otherwise open at the end of the dashboard.
              {
                name = "Sync & Backup";
                tiles = [ ];
              }
              {
                name = "Media";
                tiles = [
                  {
                    name = "Immich";
                    href = svcUrl "immich";
                    description = "Photo & Video Management";
                  }
                  {
                    name = "Paperless";
                    href = svcUrl "paperless";
                    description = "Document Management (OCR, Office/E-Mail, AI, Archive)";
                  }
                  {
                    name = "DNS Blocker";
                    href = svcUrl "dnsblock";
                    description = "DNS Block Stats";
                  }
                ];
              }
              {
                name = "Development";
                tiles = [
                  {
                    name = "Forgejo";
                    href = svcUrl "forgejo";
                    description = "Git Forge (GitHub Sync)";
                  }
                ];
              }
              {
                name = "AI";
                tiles = [ ];
              }
              {
                name = "Monitoring";
                tiles = [
                  {
                    name = "Node Exporter";
                    description = "System Metrics (CPU, RAM, Disk, Network)";
                  }
                  {
                    name = "dnsblockd";
                    description = "Block-page HTTP server (localhost-only)";
                  }
                  {
                    name = "EMEET PIXY";
                    description = "Webcam Auto-Management Daemon";
                  }
                ];
              }
              {
                name = "Productivity";
                tiles = [
                  {
                    name = "Taskwarrior";
                    href = svcUrl "tasks";
                    description = "Task Sync Server (TaskChampion)";
                  }
                  {
                    name = "OpenSEO";
                    href = svcUrl "seo";
                    description = "SEO Suite (Rank Tracking, Keywords, Backlinks)";
                  }
                ];
              }
              {
                name = "Review Tools";
                tiles = [ ];
              }
            ];
            description = ''
              Dashboard groups in display order. Hermes / Google Sync /
              Overview / Gatus / FastFlowLM and friends arrive via the
              services.integration registry fan-out (extraTiles), not here.
            '';
          };

          bookmarks = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Bookmark group label";
                  };
                  links = lib.mkOption {
                    type = lib.types.listOf (
                      lib.types.submodule {
                        options = {
                          name = lib.mkOption {
                            type = lib.types.str;
                            description = "Link label";
                          };
                          abbr = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Two-letter chip abbreviation";
                          };
                          href = lib.mkOption {
                            type = lib.types.str;
                            description = "Link target";
                          };
                          description = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Link tooltip";
                          };
                        };
                      }
                    );
                    description = "Links in this group";
                  };
                };
              }
            );
            default = [
              {
                name = "Infrastructure";
                links = [
                  {
                    name = "Pocket-ID";
                    abbr = "PI";
                    href = svcUrl "auth";
                    description = "Passkey OIDC login";
                  }
                  {
                    name = "Gatus";
                    abbr = "GA";
                    href = svcUrl "status";
                    description = "Service uptime dashboard";
                  }
                  {
                    name = "SigNoz";
                    abbr = "SN";
                    href = svcUrl "signoz";
                    description = "Traces, metrics, logs";
                  }
                ];
              }
              {
                name = "Development";
                links = [
                  {
                    name = "Forgejo";
                    abbr = "FJ";
                    href = svcUrl "forgejo";
                    description = "Git forge";
                  }
                  {
                    name = "GitHub";
                    abbr = "GH";
                    href = "https://github.com/LarsArtmann";
                    description = "LarsArtmann GitHub";
                  }
                  {
                    name = "NixOS Options";
                    abbr = "NX";
                    href = "https://search.nixos.org/options";
                    description = "NixOS option search";
                  }
                  {
                    name = "Nix Package Search";
                    abbr = "NP";
                    href = "https://search.nixos.org/packages";
                    description = "Find packages";
                  }
                ];
              }
              {
                name = "Search";
                links = [
                  {
                    name = "DuckDuckGo";
                    abbr = "DD";
                    href = "https://duckduckgo.com";
                    description = "Privacy-first search";
                  }
                  {
                    name = "Kagi";
                    abbr = "KG";
                    href = "https://kagi.com";
                    description = "Paid, no-ads search";
                  }
                ]
                ++ lib.optional searxEnabled {
                  name = "SearXNG";
                  abbr = "SX";
                  href = svcUrl "search";
                  description = "Self-hosted metasearch";
                };
              }
            ];
            description = "Bookmark chip rows shown under the tiles.";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.papdashboard = {
          description = "PapDashboard — alert hub with NPU insight enricher";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          inherit onFailure;

          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          restartTriggers = [ servicesConfig ];
          environment = {
            PAP_ENV = cfg.environment;
            # OTel traces → local SigNoz OTLP/HTTP collector (Go otlptracehttp,
            # bare host:port). Noop until the binary links the otel package.
            OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "localhost:${toString ports.signoz-otlp-http}";
            PAP_NOTIFY_SOURCE_APPS = cfg.notifySourceApps;
            PAP_INSIGHT_ENABLED = "true";
            PAP_INSIGHT_LLM_BASE_URL = cfg.llmBaseUrl;
            PAP_INSIGHT_LLM_MODEL = cfg.llmModel;
            # Evidence collection (insight enricher)
            PAP_INSIGHT_JOURNALCTL_PATH = "/run/current-system/sw/bin/journalctl";
            PAP_INSIGHT_JOURNAL_UNITS = lib.concatStringsSep "," cfg.journalUnits;
            PAP_INSIGHT_EVIDENCE_URLS = lib.concatStringsSep "," cfg.evidenceURLs;
            # Services dashboard (tiles/status/bookmarks/vitals). The file is
            # read at startup; restartTriggers below restarts the unit when
            # the rendered config changes.
            PAP_SERVICES_CONFIG = "/etc/papdashboard/services.json";
          };

          serviceConfig = lib.mkMerge [
            {
              ExecStart = lib.getExe' cfg.package "server";
              ExecStartPre = [ "${checkEnv}/bin/check-papdashboard-env" ];
              EnvironmentFile = [ config.sops.templates."papdashboard-env".path ];
              # DynamicUser: no persistent uid; StateDirectory owns /var/lib/papdashboard.
              # systemd-journal supplementary group grants read access to the
              # journal files the insight enricher collects as evidence.
              DynamicUser = true;
              StateDirectory = "papdashboard";
              SupplementaryGroups = [ "systemd-journal" ];
              Environment = [
                "PAP_PORT=${toString cfg.port}"
                "PAP_DB_PATH=/var/lib/papdashboard/papdashboard.db"
                "GOMEMLIMIT=384MiB"
              ];
            }
            (harden { MemoryMax = "512M"; })
            (serviceDefaults { })
            ioTier.background
          ];
        };

        # Drift-guard collector: folds the rendered services.json health
        # into node_exporter textfile metrics (see servicesJsonCheck).
        systemd.services.papdashboard-services-json-check = {
          description = "PapDashboard services.json drift check for node_exporter textfile";
          inherit onFailure;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe servicesJsonCheck;
          };
        };

        systemd.timers.papdashboard-services-json-check = {
          description = "Check PapDashboard services.json every 60s";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "30s";
            OnUnitActiveSec = "60s";
          };
        };

        # Services dashboard config consumed by the unit (PAP_SERVICES_CONFIG
        # above). Store-path symlink: world-readable by construction, no
        # secrets in the file.
        environment.etc."papdashboard/services.json".source = servicesConfig;

        # Service-integration registry entry: fans out to the Caddy vHost
        # (Layer 2 — the UI has no built-in auth) and the Gatus /api/health
        # check. The dashboard IS this service, so it carries no dashboard
        # tile of its own (a self-tile is a navigation no-op).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          papdashboard = {
            inherit (cfg) enable;
            subdomain = "dash";
            inherit (cfg) port;
            vHost.layer = "protected";
            checks = [
              {
                name = "PapDashboard";
                group = "Monitoring";
                url = "http://localhost:${toString cfg.port}/api/health";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alert = "PapDashboard alert hub down — alert lifecycle UI and NPU insights unavailable (raw Discord alerts still flow)";
              }
              {
                name = "PapDashboard Services JSON";
                group = "Monitoring";
                url = "http://localhost:${toString nodeExporterPort}/metrics";
                interval = "5m";
                # Asserted-1 anchored pair (AGENTS.md pat() rules): the
                # != 0 arm is line-anchored on the trailing newline so a
                # HELP comment can never phantom-green it, and the == arm
                # proves the metric line exists at all — a dead collector
                # fails closed instead of freezing at its last values.
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] != pat(*papdashboard_services_json_ok 0\n*)"
                  "[BODY] == pat(*\npapdashboard_services_json_ok *)"
                ];
                alert = "PapDashboard services.json drift — rendered config missing, unparsable, or empty, so the Services tab serves no tiles until the unit restarts. Check: systemctl status papdashboard-services-json-check; ls -la /etc/papdashboard/services.json";
              }
            ];
          };
        };
      };
    };
}
