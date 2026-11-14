# Runbook: docs/services/audiblesync.md
# audiblesync — AudibleSync WebUI (event-sourced Audible library tracker).
#
# The companion UI to the audible-sync archive oneshot: a long-running Go
# WebUI (templ + HTMX, go-cqrs-lite system + metaengine over SQLite, SSE
# live updates) tracking the Audible library and each book's LOCAL sync
# state. Its "Sync now" button delegates to audible-cli for a SINGLE ASIN
# against the SAME pool dirs + sops auth the weekly archive oneshot uses —
# the two services intentionally share the `audible-sync` identity, which
# is why this module ASSERTS co-enable instead of declaring a second user.
#
# Upstream (github:LarsArtmann/audiblesync) exports packages.default ONLY —
# no nixosModules — so this wrapper hand-rolls the unit (bank-sync wrapper
# pattern, pre-upstreaming state; the extraction recipe in
# docs/agents/integration-registry.md applies when upstream grows a module).
#
# The app ships WITHOUT auth of its own (cqrs-htmx Path A: the CSRF guard
# only closes cross-site form-POSTs), so the vHost sits at the PROTECTED
# layer (oauth2-proxy forward-auth, LAN bypass). The loopback bind is the
# sole backend; Caddy is the only entry point.
{ inputs, ... }: {
  flake.nixosModules.audiblesync =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        ports
        ioTier
        mkPoolDirUnit
        mkSqliteBackupUnit
        ;

      cfg = config.services.audiblesync;

      # The WebUI and the weekly archive oneshot share ONE identity: the
      # `audible-sync` user (sops auth file owner + pool dir owner). Both
      # modules ship enabled together on evo-x2; flipping audiblesync on
      # without the archive would leave the sync button auth-less and the
      # unit without its user — fail the eval instead.
      archivePresent = options ? services.audible-sync;
      archiveEnabled = archivePresent && config.services.audible-sync.enable;

      poolDir = "/mnt/pool/services/audible";
      backupDir = "/mnt/pool/backups/audiblesync";
      stateDir = "/var/lib/audiblesync";

      # Single-book sync runner the WebUI shells out to (the app runs the
      # configured command via `sh -c`, substituting {asin} textually).
      # Mirrors the archive oneshot's PROVEN AAX pipeline (AAXC vouchers
      # are refused for this account under every auth shape — audible-sync
      # runbook): skip-if-on-disk, single-ASIN download, ffmpeg remux with
      # the account activation bytes, raw AAX dropped on success.
      audibleBookSync = pkgs.writeShellApplication {
        name = "audible-book-sync";
        runtimeInputs = [
          pkgs.audible-cli
          pkgs.ffmpeg
          pkgs.coreutils
          pkgs.findutils
          pkgs.jq
        ];
        text = ''
          set -euo pipefail

          asin="''${1:-}"
          if [[ ! "$asin" =~ ^[0-9A-Z]{10}$ ]]; then
            echo "audible-book-sync: not a valid ASIN: '$asin' (expected 10 chars [0-9A-Z])" >&2
            exit 2
          fi

          bookDir="${poolDir}/books"
          dlDir="${poolDir}/downloads"

          # Idempotent: the archive names files ASIN-prefixed
          # (--filename-mode asin_ascii), so a prefix glob is the
          # on-disk test. Already present = nothing to sync.
          if compgen -G "$bookDir/''${asin}*.m4b" > /dev/null; then
            echo "audible-book-sync: $asin already in $bookDir"
            exit 0
          fi

          # AAX path (proven for this account; audible-cli skip-if-exists
          # is a no-op for previously downloaded side files). One book, no
          # --ignore-errors: the WebUI records the failure verdict from
          # this exit code, so any refusal must FAIL here.
          audible download -a "$asin" --aax --chapter --cover --pdf \
            --filename-mode asin_ascii -y -j 1 -o "$dlDir"

          authFile="''${AUDIBLE_SYNC_AUTH_FILE:?AUDIBLE_SYNC_AUTH_FILE not set}"
          activationBytes=$(jq -er '.activation_bytes | select(. != null and length > 0)' < "$authFile") || {
            echo "audible-book-sync: activation_bytes missing in $authFile — fetch once with: AUDIBLE_CONFIG_DIR=<cfg> audible activation-bytes" >&2
            exit 1
          }

          aax=$(find "$dlDir" -maxdepth 1 -name "''${asin}*.aax" -type f -printf '%T@ %p\n' \
            | sort -n | tail -1 | cut -d' ' -f2-)
          if [ -z "$aax" ]; then
            echo "audible-book-sync: no AAX for $asin appeared in $dlDir (download refused? see journal)" >&2
            exit 1
          fi

          out="$bookDir/$(basename "''${aax%.aax}").m4b"
          if ffmpeg -nostdin -loglevel error -activation_bytes "$activationBytes" \
            -i "$aax" -c copy -movflags use_metadata_tags "$out"; then
            rm -f "$aax"
            echo "audible-book-sync: $asin synced to $out"
          else
            rm -f "$out"
            echo "audible-book-sync: decrypt FAILED for $aax (raw AAX kept for retry)" >&2
            exit 1
          fi
        '';
      };
    in
    {
      options.services.audiblesync = {
        enable = lib.mkEnableOption "AudibleSync WebUI (Audible library tracker)";

        package = lib.mkOption {
          type = lib.types.package;
          description = ''
            The audiblesync package (single Go binary, templ + HTMX
            embedded). Defaults to the locked flake input; the
            vendorHash is upstream-owned — re-probe before re-pinning
            (bank-sync treadmill doctrine).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = archiveEnabled;
            message = ''
              services.audiblesync requires services.audible-sync.enable: the two
              services share the `audible-sync` user, the sops-rendered Audible
              auth (audible_sync_auth_json), and the /mnt/pool/services/audible
              tree. Enable the archive oneshot alongside the WebUI — or split
              the identity deliberately (new user + secret grant) instead of
              loosening this assertion.
            '';
          }
        ];

        services.audiblesync.package =
          lib.mkDefault
            inputs.audiblesync.packages.${pkgs.stdenv.hostPlatform.system}.default;

        systemd = lib.mkMerge [
          {
            services.audiblesync = {
              description = "AudibleSync — Audible library tracker WebUI (audiblesync.home.lan)";
              # audible-sync-dirs creates the pool leaf dirs the sync
              # child writes into; the namespace setup (ReadWritePaths)
              # needs them EXISTING at unit start (226 class).
              after = [ "audible-sync-dirs.service" ];
              wants = [ "audible-sync-dirs.service" ];
              inherit onFailure;
              startLimitBurst = 5;
              startLimitIntervalSec = 300;
              # The pool mounts nofail — a detached DAS fails the unit as
              # a clean dependency error instead of a 226/NAMESPACE
              # (mount-gating audit; the WebUI tracks books ON the pool).
              unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "1G";
                  # The "Sync now" child writes downloads/ + books/ under
                  # the archive tree; the SQLite DB lives in the
                  # StateDirectory below (auto-writable).
                  ReadWritePaths = [ poolDir ];
                })
                (serviceDefaults { })
                ioTier.service
                {
                  User = "audible-sync";
                  Group = "audible-sync";
                  StateDirectory = "audiblesync";
                  Environment = [
                    "AUDIBLESYNC_ADDR=127.0.0.1:${toString ports.audiblesync}"
                    "AUDIBLESYNC_DB=${stateDir}/audiblesync.db"
                    "AUDIBLESYNC_SYNC_CMD=${lib.getExe audibleBookSync} {asin}"
                  ]
                  ++ lib.optionals archiveEnabled [
                    # The sync child reuses the archive's rendered
                    # audible-cli config (auth.json symlink farm in
                    # /var/lib/audible-sync/config, created by the
                    # archive unit's config-check ExecStartPre).
                    "AUDIBLE_CONFIG_DIR=/var/lib/audible-sync/config"
                    "AUDIBLE_SYNC_AUTH_FILE=${config.sops.secrets.audible_sync_auth_json.path}"
                  ];
                  ExecStart = lib.getExe cfg.package;
                }
              ];
            };

            services.audiblesync-backup-dir = mkPoolDirUnit {
              description = "Create AudibleSync DB backup directory on the HDD pool";
              directory = backupDir;
              owner = "audible-sync";
            };
          }

          # Nightly WAL-safe SQLite online backup (lib generator, plan E1):
          # 02:35 — staggered off paperless-db (02:00), browser-history
          # (02:15), and miniflux (02:45). Root reads the audible-sync-owned
          # StateDirectory directly (no DynamicUser 0700 — no caps needed).
          (mkSqliteBackupUnit {
            inherit pkgs;
            name = "audiblesync-backup";
            description = "AudibleSync DB backup (online sqlite .backup)";
            dbPath = "${stateDir}/audiblesync.db";
            inherit backupDir;
            prefix = "audiblesync-db-";
            retentionDays = 14;
            startAt = {
              OnCalendar = "*-*-* 02:35:00";
            };
            serviceDeps = [
              "audiblesync.service"
              "audiblesync-backup-dir.service"
            ];
            timerAfter = [ "mnt-pool.mount" ];
            onFailureDeps = onFailure;
            extraServiceConfig = [ ioTier.background ];
          })
        ];

        # Service-integration registry entry: ONE declaration fans out the
        # Caddy vHost (protected layer — the app has NO auth of its own),
        # dnsblockd record, Gatus checks, PapDashboard tile, and backup
        # freshness (integration.nix; miniflux is the reference entry).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          audiblesync = {
            inherit (cfg) enable;
            port = ports.audiblesync;
            subdomain = "audiblesync";
            vHost.layer = "protected";
            monitored = true;
            checks = [
              {
                name = "AudibleSync health";
                group = "Media";
                path = "/healthz";
                conditions = [
                  "[STATUS] == 200"
                  # Honest health: /healthz pings the system composition
                  # root AND the read model (503 + "error" status on
                  # failure), so the body shape proves both legs.
                  "[BODY] == pat(*\"status\":\"ok\"*)"
                ];
              }
              {
                name = "AudibleSync dashboard";
                group = "Media";
                path = "/";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
              }
            ];
            homepage = {
              name = "AudibleSync";
              group = "Media";
              description = "Audible library sync tracker";
              # No Audible glyph exists in the dashboard-icons pack (checked
              # upstream 2026-11-01 for the archive tile); openaudible.png
              # is the nearest semantic one and the same one the archive
              # pool tile already renders.
              icon = "openaudible.png";
            };
            backup = {
              directory = backupDir;
              filePattern = "audiblesync-db-*.sqlite";
              maxAgeHours = 25;
            };
          };
        };
      };
    };
}
