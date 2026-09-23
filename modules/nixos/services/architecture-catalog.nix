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

          # Keep only the newest generations.
          ls -1d "$GENS"/* 2>/dev/null | sort | head -n -${toString cfg.maxGenerations} | while read -r old; do
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
            serviceOneshotDefaults
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
