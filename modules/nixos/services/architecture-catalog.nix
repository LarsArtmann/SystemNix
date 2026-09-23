# Architecture Catalog — license-free federated EventCatalog hub.
#
# Serves the STATIC dist/ tree that the eventcatalog-hub CI (Forgejo
# runner, native:host) publishes to the `dist` branch of
# forgejo.home.lan/lars/eventcatalog-hub. Zero runtime daemons and zero
# Node: this module only (1) pulls that branch on a timer into a fresh
# generation dir and atomically swaps the `current` symlink, and (2) lets
# the registry render the catalog.home.lan vHost as a Layer 2 PROTECTED
# STATIC file_server (external clients hit oauth2-proxy forward-auth,
# LAN bypasses — same posture as dash/mr-sync).
#
#   - The serving root is /var/lib/architecture-catalog/current — a
#     RELATIVE symlink into generations/<timestamp>. Caddy (ProtectSystem
#     hardening only) reads it; every file is chmod a+rX after the pull.
#   - The sync token is a Forgejo PAT with read:repository scope (sops,
#     env-file format, root-owned — systemd reads EnvironmentFile as PID 1).
#     Ships PLACEHOLDER-inert: until the owner pastes a real token the sync
#     unit skips cleanly with a journal WARN (setup runbook:
#     scripts/setup-forgejo.sh in the hub repo), and the Gatus checks stay
#     red as the standing "not live yet" signal (discordsync Turso
#     doctrine).
#   - mkDnsGate: the clone needs dnsblockd answering forgejo.home.lan —
#     at boot that is ~2min away (blocklist load), so the gate budget is
#     the default 180s (TimeoutStartSec floor 4min via the fragment).
#   - No deploy.sh provisioner entry: `architecture-catalog-sync` matches
#     no converger pattern, and the hourly Persistent timer converges
#     after every boot/deploy anyway.
_: {
  flake.nixosModules.architecture-catalog =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.architecture-catalog;
      domain = config.networking.domain;
      stateDir = "/var/lib/architecture-catalog";
      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        mkDnsGate
        ;

      dnsGate = mkDnsGate {
        inherit pkgs;
        serviceName = "architecture-catalog-sync";
        hostname = cfg.host;
      };

      syncScript = pkgs.writeShellApplication {
        name = "architecture-catalog-sync";
        runtimeInputs = [
          pkgs.git
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnused
        ];
        text = ''
          set -euo pipefail
          STATE="${stateDir}"
          GENS="$STATE/generations"
          TOKEN="''${ARCHITECTURE_CATALOG_SYNC_TOKEN:-}"

          case "$TOKEN" in
            PLACEHOLDER*|"")
              echo "architecture-catalog-sync: sync token is PLACEHOLDER — skipping." \
                "Run scripts/setup-forgejo.sh in the eventcatalog-hub repo, then sops-paste" \
                "the minted token into platforms/nixos/secrets/architecture-catalog.yaml."
              exit 0
              ;;
          esac

          stamp="$(date +%Y%m%d-%H%M%S)"
          incoming="$STATE/.incoming-$stamp"
          # Sync targets are rebuildable cache-class data, never user files —
          # plain rm is the honest verb here (buildcache-gc doctrine).
          rm -rf "$incoming"
          clone_url="https://x-access-token:$TOKEN@${cfg.host}/${cfg.repo}.git"
          # Redact the token from any clone failure we surface to the journal.
          if ! err="$(git clone --depth 1 --branch "${cfg.branch}" "$clone_url" "$incoming" 2>&1)"; then
            echo "architecture-catalog-sync: clone of ${cfg.repo} (${cfg.branch}) failed: $(printf '%s' "$err" | sed "s|$TOKEN|REDACTED|g")" >&2
            exit 1
          fi
          rm -rf "$incoming/.git"

          if [ ! -f "$incoming/index.html" ]; then
            echo "architecture-catalog-sync: fetched ${cfg.branch} branch carries no index.html — refusing to swap (keep last-good generation)" >&2
            rm -rf "$incoming"
            exit 1
          fi

          target="$GENS/$stamp"
          mv "$incoming" "$target"
          # Caddy reads the tree as its own user: world-readable files,
          # traversable dirs.
          chmod -R a+rX "$target"

          # Atomic swap: build the symlink aside, rename over `current`
          # (ln -sfn is unlink+symlink — a reader can catch the gap).
          ln -s "generations/$stamp" "$STATE/.current.tmp.$$"
          mv -T "$STATE/.current.tmp.$$" "$STATE/current"

          # Keep only the newest generations (find, not ls): the SC2012 lint
          # rule rejects `ls | sort`, and find exits 0 on an empty dir
          # instead of dying under pipefail.
          find "$GENS" -mindepth 1 -maxdepth 1 | sort | head -n -${toString cfg.maxGenerations} | while read -r old; do
            rm -rf "$old"
          done

          echo "architecture-catalog-sync: serving generation $stamp from ${cfg.repo}@${cfg.branch}"
        '';
      };
    in
    {
      options.services.architecture-catalog = {
        enable = lib.mkEnableOption "federated EventCatalog architecture hub (static, CI-built)";

        host = lib.mkOption {
          type = lib.types.str;
          default = "forgejo.home.lan";
          description = "Forgejo host serving the hub repo's dist branch";
        };

        repo = lib.mkOption {
          type = lib.types.str;
          default = "lars/eventcatalog-hub";
          description = "Instance-owner-qualified hub repository path";
        };

        branch = lib.mkOption {
          type = lib.types.str;
          default = "dist";
          description = "Branch CI publishes the static build to";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "hourly";
          description = "Sync timer interval (systemd OnCalendar)";
        };

        maxGenerations = lib.mkOption {
          type = lib.types.int;
          default = 3;
          description = "Served generations to keep on disk (current + rollback margin)";
        };

        freshMaxAgeHours = lib.mkOption {
          type = lib.types.int;
          default = 36;
          description = ''
            CI-build age budget for architecture_catalog_fresh. The hub CI
            runs nightly (03:23) + on every push, so a healthy build is
            always <24h old; 36h absorbs one missed nightly before paging.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.tmpfiles.rules = [
          "d ${stateDir} 0755 root root -"
          "d ${stateDir}/generations 0755 root root -"
        ];

        sops.secrets.architecture_catalog_sync_token = {
          sopsFile = ../../../platforms/nixos/secrets/architecture-catalog.yaml;
          # Root-owned 0400: systemd (PID 1) reads the EnvironmentFile as
          # root; nothing else ever needs the token. sops rotation restarts
          # the sync unit so a fresh token converges within one tick.
          restartUnits = [ "architecture-catalog-sync.service" ];
        };

        systemd.services.architecture-catalog-sync = {
          description = "Pull the CI-built EventCatalog dist into the serving root";
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          after = dnsGate.after;
          wants = dnsGate.wants;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              ExecStart = lib.getExe syncScript;
              EnvironmentFile = config.sops.secrets.architecture_catalog_sync_token.path;
            }
            (harden {
              ReadWritePaths = [ stateDir ];
            })
            (serviceOneshotDefaults { })
            ioTier.background
            dnsGate.serviceConfig
          ];
        };

        systemd.timers.architecture-catalog-sync = {
          description = "Hourly EventCatalog dist sync";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.interval;
            Persistent = true;
            Unit = "architecture-catalog-sync.service";
          };
        };

        # Freshness collector (pool-smart-metrics pattern): turns the CI's
        # build-stamp.json into Prometheus gauges. Fail-closed — on a scrape
        # error ONLY scrape_errors is emitted so the anchored Gatus pats go
        # red instead of phantom-greening on a frozen textfile. Pre-go-live
        # (PLACEHOLDER token, no dist ever synced) is NOT a scrape error:
        # dist_present/fresh honestly report zero and the Gatus checks stay
        # red as the standing not-live-yet signal.
        systemd.services.architecture-catalog-metrics = {
          description = "Architecture Catalog freshness metrics (textfile)";
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          inherit onFailure;
          path = [
            pkgs.jq
            pkgs.coreutils
            pkgs.gnugrep
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
            }
            (harden {
              ReadWritePaths = [ textfileDir ];
              # CAP_FOWNER: rename over a foreign-owned prom in the sticky
              # 1777 textfile dir (mail-relay 2026-09-02..06 class).
              CapabilityBoundingSet = "CAP_FOWNER";
              MemoryMax = "128M";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            set -eu
            OUT="${textfileDir}/architecture-catalog.prom"
            mkdir -p "${textfileDir}"
            TMP="$(mktemp "${textfileDir}/architecture-catalog.prom.XXXXXX")"
            chmod 644 "$TMP"
            trap 'rm -f "$TMP"' EXIT

            fresh_budget_seconds=$(( ${toString cfg.freshMaxAgeHours} * 3600 ))
            stamp="${stateDir}/current/build-stamp.json"
            dist_index="${stateDir}/current/index.html"

            emit() {
              {
                echo "# HELP architecture_catalog_dist_present Whether a served dist generation exists under the serving root"
                echo "# TYPE architecture_catalog_dist_present gauge"
                echo "architecture_catalog_dist_present $1"
                echo "# HELP architecture_catalog_fresh Whether the served CI build is inside the freshness budget"
                echo "# TYPE architecture_catalog_fresh gauge"
                echo "architecture_catalog_fresh $2"
                echo "# HELP architecture_catalog_stamp_age_seconds Age of the served CI build in seconds, negative when no stamp is readable"
                echo "# TYPE architecture_catalog_stamp_age_seconds gauge"
                echo "architecture_catalog_stamp_age_seconds $3"
                echo "# HELP architecture_catalog_scrape_errors Nonzero when the collector itself failed; the value metrics above are omitted in that case"
                echo "# TYPE architecture_catalog_scrape_errors gauge"
                echo "architecture_catalog_scrape_errors 0"
              } > "$TMP"
              mv "$TMP" "$OUT"
            }

            if [ ! -f "$dist_index" ]; then
              # Honest absence (never synced / pre-go-live) — not a scrape error.
              emit 0 0 -1
              exit 0
            fi

            built_at="$(jq -r '.builtAt // empty' "$stamp" 2>/dev/null || true)"
            if [ -z "$built_at" ]; then
              # dist exists but the stamp is unreadable/missing — the sync
              # landed something unexpected; surface as scrape error.
              {
                echo "# HELP architecture_catalog_scrape_errors Nonzero when the collector itself failed; the value metrics above are omitted in that case"
                echo "# TYPE architecture_catalog_scrape_errors gauge"
                echo "architecture_catalog_scrape_errors 1"
              } > "$TMP"
              mv "$TMP" "$OUT"
              exit 0
            fi

            built_epoch="$(date -d "$built_at" +%s 2>/dev/null || true)"
            if [ -z "$built_epoch" ]; then
              echo "architecture-catalog-metrics: unparseable builtAt '$built_at'" >&2
              exit 1
            fi
            age=$(( $(date +%s) - built_epoch ))
            if [ "$age" -le "$fresh_budget_seconds" ]; then
              emit 1 1 "$age"
            else
              emit 1 0 "$age"
            fi
          '';
        };

        systemd.timers.architecture-catalog-metrics = {
          description = "Collect Architecture Catalog freshness metrics every 5 minutes";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "5min";
            Persistent = true;
          };
        };

        # Service-integration registry entry: ONE declaration fans out to
        # the Caddy vHost (Layer 2 protected, STATIC root — no port, no
        # daemon), the Gatus checks, the dashboard tile, and system-health
        # unit monitoring. No backup (fully rebuildable from the dist
        # branch), no OTel (no process), no OIDC (Layer 2 owns external
        # auth).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          architecture-catalog = {
            subdomain = "catalog";
            vHost.layer = "protected";
            vHost.root = "${stateDir}/current";
            # No port: static file_server. Checks are therefore ABSOLUTE
            # URLs — they exercise the real serving path (dnsblockd TLS +
            # caddy + LAN bypass + static root). The rendered <title> is
            # verified from a real dist build (EventCatalog's config title
            # does not reach the template — do not "fix" the pattern to a
            # config-derived one).
            checks = [
              {
                name = "Architecture Catalog";
                group = "Development";
                url = "https://catalog.${domain}/";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*<title>EventCatalog*)"
                  "[RESPONSE_TIME] < 2000"
                ];
              }
              {
                name = "Architecture Catalog llms.txt";
                group = "Development";
                url = "https://catalog.${domain}/llms.txt";
                interval = "30m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*EventCatalog*)"
                ];
                alert = ""; # secondary surface — the main check owns paging
              }
              {
                # Freshness = the CI kept building AND the sync kept pulling.
                # Anchored pats (HELP lines embed metric names — the \n anchor
                # keeps this from matching the collector's own comments).
                name = "Architecture Catalog Freshness";
                group = "Development";
                url = "http://localhost:${toString config.services.prometheus.exporters.node.port}/metrics";
                interval = "15m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] != pat(*architecture_catalog_scrape_errors 1\n*)"
                  "[BODY] == pat(*\narchitecture_catalog_scrape_errors *)"
                  "[BODY] == pat(*\narchitecture_catalog_fresh 1*)"
                ];
                alert = "Architecture Catalog stale — the served EventCatalog build exceeds the freshness budget (hub CI dead, or the dist sync is failing while the last-good generation keeps serving). Check: journalctl -u architecture-catalog-sync; hub CI runs at https://forgejo.home.lan/lars/eventcatalog-hub/actions (nightly 03:23 + push-triggered).";
              }
            ];
            homepage = {
              name = "Architecture Catalog";
              group = "Development";
              description = "Federated EventCatalog of all services";
              icon = "mdi-sitemap";
            };
            unit = "architecture-catalog-sync";
            monitored = true;
          };
        };
      };
    };
}
