# Runbook: docs/services/papdashboard.md
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
# Auth model (upstream re-pinned 2026-10-08, flake bump f12d5604 -> rev
# 81201c88; replaces the 2026-09-18 login-overlay model): the BROWSER surface
# (UI pages, /api/services, /api/system, fragments, SSE stream) is public AT
# THE APP by upstream contract (middleware/auth.go publicPaths, pinned by
# upstream auth_invariants tests) because SSE cannot carry headers, so an
# in-app key gate can never cover the stream. UI access control is the Caddy
# vHost: this service registers vHost.layer = "protected" (Pocket ID SSO for
# off-LAN; *.home.lan from the LAN is direct by design). The app-level
# PAP_API_KEY gate covers the MACHINE surface only (ingest, forwarder,
# dead-letter, batch/export); an empty key would disable it entirely, hence
# the mkSecretCheck ExecStartPre on the env template.
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

      # The vendorHash shim that rode this pin since the 2026-10-15 fleet
      # wave (re-measured ZNTUWEuj… on 2026-10-17 for the tile-logo bump)
      # is DROPPED 2026-10-17: upstream bakes the correct hash now
      # (PapDashboard vendorHash.nix = ZNTUWEuj…, commit d96ee6e), so the
      # override was a no-op re-stating upstream's own value. Re-add the
      # shim pattern only when a future lock bump hits a fresh FOD mismatch
      # upstream has not baked yet (class comment: lib/lars-packages.nix
      # flakePkgShim).
      # RE-ADDED 2026-10-23 (15:17 lock float): the new rev ships a go.sum
      # whose vendor output no longer matches its baked hash — first-hand
      # keep-going probe got sha256-mi1+rwiOkikTm7Xl9bfjDikP0y5/HwpqwZZHwI9ln+w
      # (specified g6Q8jl4X, got mi1+rwiO). Drop when upstream bakes it.
      papdashboardPkg =
        inputs.papdashboard.packages.${pkgs.stdenv.hostPlatform.system}.server.overrideAttrs
          {
            vendorHash = "sha256-mi1+rwiOkikTm7Xl9bfjDikP0y5/HwpqwZZHwI9ln+w=";
          };

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

      # Service icon pack for the dashboard tiles. Same upstream pack the
      # retired homepage-dashboard bundled (homarr-labs/dashboard-icons);
      # PapDashboard serves the copy below from PAP_ICONS_DIR at /icons/.
      # Rev/hash are pinned for the fixed-output source (hash prefetched with
      # `nix-prefetch-url --unpack`, 2026-10-17) — this is not a flake input,
      # so the flake-input pin audit does not apply.
      iconPackSrc = pkgs.fetchFromGitHub {
        owner = "homarr-labs";
        repo = "dashboard-icons";
        rev = "6d31345986eba2067a63eb41c1a5a87d4e8e850a";
        hash = "sha256-5Kf5QlzLpLQUVarqzmtRH7ZLqdPUM8VPvQG7viv/RPk=";
      };

      # Every tile the rendered config can emit (built-in groups + registry
      # fan-out), used for the icon gates below.
      allTiles = builtins.concatLists (map (g: g.tiles) cfg.dashboard.groups) ++ cfg.extraTiles;

      # A tile icon is legal as an absolute http(s) URL or as a pack file
      # name; anything else (mdi-*, si-*, a bare word) cannot resolve to a
      # file. PapDashboard rejects it at startup — the whole dashboard would
      # refuse to start on the next restart — so it fails the eval instead.
      iconIsValid =
        icon:
        icon == null
        || builtins.match "https?://.+" icon != null
        || builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*\\.(png|svg|webp|jpg|jpeg|gif|avif)" icon != null;

      invalidIconTiles = builtins.filter (t: !(iconIsValid (t.icon or null))) allTiles;

      # PapDashboard refuses to start when a group carries two tiles with
      # the same name ("group \"X\" tile \"Y\": duplicate name" → exit 75 →
      # start-limit-hit, live 2026-10-25 14:30 when the tile-coverage work
      # added registry homepage tiles that duplicated legacy manual ones).
      # Computed over allGroups (post-fold) so registry-fanout collisions
      # with manual tiles fail at EVAL time, not at the next restart.
      duplicateTileNames = lib.unique (
        lib.concatLists (
          map (
            g:
            map (t: "${g.name}/${t.name}") (
              builtins.filter (t: builtins.length (builtins.filter (x: x.name == t.name) g.tiles) > 1) g.tiles
            )
          ) allGroups
        )
      );

      # Pack-relative icon names (absolute URLs are external references and
      # stay unverified). Unique so the derivation is input-order independent.
      packIconNames = lib.unique (
        builtins.filter (icon: icon != null && !(lib.hasPrefix "http" icon)) (
          map (t: t.icon or null) allTiles
        )
      );

      # The icons the dashboard actually references, copied out of the pack.
      # Building this IS the missing-icon gate: a name the pack does not
      # carry fails the deploy's toplevel build (the unit env references this
      # path, so the gate cannot be skipped) instead of shipping a tile with
      # a broken logo.
      dashboardIcons = pkgs.runCommand "papdashboard-icons" { } ''
        pack="${iconPackSrc}"
        mkdir -p $out
        for name in ${lib.escapeShellArgs packIconNames}; do
          if [ -f "$pack/png/$name" ]; then
            cp "$pack/png/$name" "$out/$name"
          elif [ -f "$pack/svg/$name" ]; then
            cp "$pack/svg/$name" "$out/$name"
          else
            echo "papdashboard: icon '$name' is not in the dashboard-icons pack" >&2
            echo "  available under $pack/png — or use an absolute http(s) URL" >&2
            exit 1
          fi
        done
        cp "$pack/LICENSE" "$out/dashboard-icons-LICENSE"
      '';

      # Extra tile from the services.integration registry fan-out. `icon` is
      # the tile logo: a file name from the bundled dashboard-icons pack
      # (served by PapDashboard from PAP_ICONS_DIR) or an absolute image URL.
      # Names are verified against the pack at build time (dashboardIcons).
      tileJson =
        t:
        {
          inherit (t) name;
        }
        // lib.optionalAttrs (t.href != null) { inherit (t) href; }
        // lib.optionalAttrs (t.description != null) { inherit (t) description; }
        // lib.optionalAttrs (t.checkUrl != null) { inherit (t) checkUrl; }
        // lib.optionalAttrs (t.icon != null) { inherit (t) icon; };

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
            warnFrac = cfg.dashboard.system.warnFrac;
            critFrac = cfg.dashboard.system.critFrac;
          };
          groups = map (g: {
            inherit (g) name;
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
            inherit (b) name;
            links = map (
              l:
              {
                inherit (l) name;
                inherit (l) href;
              }
              // lib.optionalAttrs (l.abbr != null) { inherit (l) abbr; }
              // lib.optionalAttrs (l.description != null) { inherit (l) description; }
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
          icons=0
          icons_ok=0
          # Single parse gate: jq -e exits non-zero on invalid JSON or a
          # false expression, so the counting jq below only runs on a
          # verified-parsable file (set -e would abort the unit on an
          # unguarded failing assignment otherwise).
          if [ -r "$CFG" ] && jq -e '(.groups | type == "array") and (.groups | length > 0)' "$CFG" >/dev/null 2>&1; then
            groups="$(jq -r '.groups | length' "$CFG" 2>/dev/null || echo 0)"
            tiles="$(jq -r '[.groups[]? | (.tiles // []) | length] | add // 0' "$CFG" 2>/dev/null || echo 0)"
            icons="$(jq -r '[.groups[]? | (.tiles // [])[] | select(.icon != null and .icon != "")] | length' "$CFG" 2>/dev/null || echo 0)"
            if [ "$groups" -gt 0 ] && [ "$tiles" -gt 0 ]; then
              ok=1
            fi
            # Icon coverage (the 2026-10-17 "logos went dark" class): the
            # capability is healthy only when EVERY tile resolves a logo.
            if [ "$tiles" -gt 0 ] && [ "$icons" -eq "$tiles" ]; then
              icons_ok=1
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
            echo "# HELP papdashboard_services_json_icons Tiles carrying a tile icon"
            echo "# TYPE papdashboard_services_json_icons gauge"
            echo "papdashboard_services_json_icons $icons"
            echo "# HELP papdashboard_services_json_icons_ok 1 when every tile carries an icon (coverage complete)"
            echo "# TYPE papdashboard_services_json_icons_ok gauge"
            echo "papdashboard_services_json_icons_ok $icons_ok"
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
                    Tile logo: a file name from the bundled dashboard-icons
                    pack (e.g. "miniflux.png"; served at /icons/) or an
                    absolute http(s) image URL. Null renders the tile
                    monogram. Names are checked against the pack at build
                    time — see dashboardIcons in this module.
                  '';
                };
                checkUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = ''
                    Override probe URL for metrics-only registry tiles (the
                    built-in groups' tile type has the same field).
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
            warnFrac = lib.mkOption {
              type = lib.types.float;
              default = 0.8;
              description = ''
                Disk bar amber threshold as a fraction of total bytes
                (PapDashboard default 0.8 when unset).
              '';
            };
            critFrac = lib.mkOption {
              type = lib.types.float;
              default = 0.9;
              description = ''
                Disk bar red threshold as a fraction of total bytes; must be
                >= warnFrac (PapDashboard validates the pair at startup).
              '';
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
                          icon = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = ''
                              Tile logo (dashboard-icons pack file name or an
                              absolute image URL); null renders the monogram.
                              Same contract as extraTiles' icon.
                            '';
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
                    icon = "pocket-id.png";
                  }
                  {
                    name = "Caddy";
                    description = "Reverse Proxy";
                    checkUrl = "http://127.0.0.1:${toString ports.caddy-metrics}/metrics";
                    icon = "caddy.png";
                  }
                  # PostgreSQL and Redis are decorative tiles: neither exposes
                  # a public HTTP health endpoint (pg_isready is TCP-only;
                  # Redis exports to Prometheus only). Their dependents
                  # (Immich, Gatus) show errors when the DB/cache
                  # goes down — that's the real signal. All service health
                  # monitoring is owned by Gatus (Discord alerting); dashboard
                  # tiles are navigation, the dots are live probes.
                  {
                    name = "PostgreSQL";
                    description = "Database Server";
                    icon = "postgres.png";
                  }
                  {
                    name = "Redis";
                    description = "Cache (Immich)";
                    icon = "redis.png";
                  }
                  # Single DNS-blocker tile (merged 2026-10-17): the daemon
                  # is core network infra, not a media app. href opens the
                  # stats UI (Caddy proxies dnsblock.home.lan to the stats
                  # port); checkUrl probes the daemon directly so a dead
                  # daemon reds the dot even while Caddy still answers.
                  {
                    name = "DNS Blocker";
                    href = svcUrl "dnsblock";
                    description = "DNS Block Stats";
                    checkUrl = "http://127.0.0.1:${toString ports.dns-blocker-stats}/";
                    icon = "blocky.png";
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
                  # Immich arrives via the services.integration registry
                  # fan-out (immich.nix homepage, Media, with href) — the
                  # manual tile was removed 2026-10-25: it duplicated the
                  # registry tile and the floated PapDashboard binary
                  # refuses duplicate names per group (start-limit-hit).
                  {
                    name = "Paperless";
                    href = svcUrl "paperless";
                    description = "Document Management (OCR, Office/E-Mail, AI, Archive)";
                    icon = "paperless-ngx.png";
                  }
                ];
              }
              # Kept (even when empty) so registry tiles land in their
              # canonical group position — Forgejo arrives via the
              # services.integration registry fan-out (forgejo.nix homepage,
              # Development, with href). The manual tile was removed
              # 2026-10-25: it duplicated the registry tile and the floated
              # PapDashboard binary refuses duplicate names per group
              # (start-limit-hit, journal 2026-10-25 14:30).
              {
                name = "Development";
                tiles = [ ];
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
                    checkUrl = "http://127.0.0.1:${toString nodeExporterPort}/metrics";
                    icon = "prometheus.png";
                  }
                  # dnsblockd and EMEET PIXY tiles REMOVED 2026-10-17: both
                  # were probe-only/decorative halves of tiles that exist
                  # elsewhere. dnsblockd merged into the linked Infrastructure
                  # "DNS Blocker" tile above; EMEET PIXY arrives via the
                  # services.integration registry fan-out (emeet-pixyd.nix
                  # homepage, Infrastructure, with href).
                ];
              }
              {
                name = "Productivity";
                tiles = [
                  {
                    name = "Taskwarrior";
                    href = svcUrl "tasks";
                    description = "Task Sync Server (TaskChampion)";
                    icon = "taskcafe.png";
                  }
                  {
                    name = "OpenSEO";
                    href = svcUrl "seo";
                    description = "SEO Suite (Rank Tracking, Keywords, Backlinks)";
                    icon = "google-search-console.png";
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
        # Eval-time gate on the tile-icon FORM (existence is checked by
        # building dashboardIcons): PapDashboard validates icons at startup
        # and refuses to start on anything that is neither an http(s) URL nor
        # a pack file name, so a stale mdi-*/bare-word icon would take the
        # whole dashboard down at the next restart.
        assertions = [
          {
            assertion = invalidIconTiles == [ ];
            message = "services.papdashboard: tile icon(s) must be a dashboard-icons pack file name (e.g. \"miniflux.png\") or an http(s) URL. Offending tiles: ${
              lib.concatStringsSep "; " (map (t: "${t.name} → ${toString (t.icon or null)}") invalidIconTiles)
            }";
          }
          {
            assertion = duplicateTileNames == [ ];
            message = "services.papdashboard: tile names must be unique within a group — PapDashboard refuses to start on duplicates (exit 75 → start-limit-hit). Offending tiles: ${lib.concatStringsSep ", " duplicateTileNames}";
          }
        ];

        systemd.services.papdashboard = {
          description = "PapDashboard — alert hub with NPU insight enricher";
          wantedBy = [ "multi-user.target" ];
          # NO network-online.target: loopback binder + local icon pack;
          # Discord paging is runtime outbound, never a start-path dep
          # (network-online sweep 2026-10-17).
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
            # Service tile logos: the pack subset the rendered config asks
            # for, served by the app at /icons/<file>. Referencing the path
            # here is what forces the missing-icon gate to build on deploy.
            PAP_ICONS_DIR = "${dashboardIcons}";
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
        # (Layer 2 SSO — the ONLY auth layer on the browser surface since the
        # upstream auth re-pin 2026-10-08; the app-level key gate covers the
        # machine surface only) and the Gatus /api/health
        # check. The dashboard IS this service, so it carries no dashboard
        # tile of its own (noDashboardTile opt-out below).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          papdashboard = {
            inherit (cfg) enable;
            subdomain = "dash";
            inherit (cfg) port;
            vHost.layer = "protected";
            # The dashboard IS this service — a self-tile is a navigation
            # no-op (tile-coverage opt-out; see integration.nix assertion).
            noDashboardTile = true;
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
                # Asserted-1 anchored pair (docs/agents/monitoring.md pat() rules): the
                # != 0 arm is line-anchored on the trailing newline so a
                # HELP comment can never phantom-green it, and the == arm
                # proves the metric line exists at all — a dead collector
                # fails closed instead of freezing at its last values. The
                # icons_ok pair re-applies the same rules to tile-icon
                # coverage (a tile losing its logo goes red within 5 min
                # instead of silently rendering monograms).
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] != pat(*papdashboard_services_json_ok 0\n*)"
                  "[BODY] == pat(*\npapdashboard_services_json_ok *)"
                  "[BODY] != pat(*papdashboard_services_json_icons_ok 0\n*)"
                  "[BODY] == pat(*\npapdashboard_services_json_icons_ok *)"
                ];
                alert = "PapDashboard services.json drift — rendered config missing, unparsable, empty, or a tile lost its icon coverage, so the Services tab serves no (or logo-less) tiles until the unit restarts. Check: systemctl status papdashboard-services-json-check; ls -la /etc/papdashboard/services.json; curl -s localhost:9100/metrics | grep papdashboard_services_json_icons";
              }
            ];
          };
        };
      };
    };
}
