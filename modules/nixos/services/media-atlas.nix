# Runbook: docs/services/media-atlas.md
# MediaAtlas federation hub — GROUNDWORK module (v0.1 plan L11 + L03
# enabler, repo ~/projects/media-atlas):
#   1. media_atlas PG role with READ-ONLY access to the immich DB
#      (smart_search embeddings for the hub's vector store) — converged by
#      a root oneshot (peer-auth postgres via runuser, the
#      discordsync-immich-key-provision pattern).
#   2. Optional: Immich read-only access to the DiscordSync attachment
#      archive (DiscordSync ADR-061 external-library runbook): the immich
#      user joins the discordsync group for DAC read, and
#      BindReadOnlyPaths enforces RO at the namespace level (the runbook's
#      "read-only from Immich's perspective" defense in depth).
#   3. The hub service itself (hub.enable): `atlas serve` on loopback
#      behind the map.home.lan registry vHost (plain layer — the hub's own
#      single API key gates /api,/events,/thumb, so caddy-side auth would
#      double-gate), plus the media-atlas-key-provision converger that
#      mints both API keys (inbound hub key + outbound Immich key with
#      asset.read/view/statistics + tag.read + library.read) the
#      discordsync-immich-key-provision way: DB-level INSERT, idempotent
#      by key name, file-first reconcile, secret only ever in a 0400 file
#      under the state dir.
# Deploy: owner-gated (calm window); the flip card in the repo's
# docs/deploy/flip-card.md seeds the production journal first.
{ inputs, ... }:
{
  flake.nixosModules.media-atlas =
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
        ;
      cfg = config.services.media-atlas;
      hubCfg = cfg.hub;
      archivePath =
        if cfg.immichExternalLibrary.importPath != null then
          cfg.immichExternalLibrary.importPath
        else if config.services.discordsync.attachmentsDir != null then
          config.services.discordsync.attachmentsDir
        else
          "${config.services.discordsync.dataDir}/attachments";

      # The hub's state (journal DB + both key files) — systemd
      # StateDirectory=media-atlas owns creation/permissions for the serve
      # unit; the key provisioner install -d's it the same way so the
      # FIRST boot converges before the service starts.
      stateDirName = "media-atlas";
      stateDir = "/var/lib/${stateDirName}";

      # Root converger: idempotent read-only grants for the hub role. Peer
      # auth on the local socket means the LOGIN role is only usable by the
      # OS user of the same name (TCP requires a password this role does not
      # have) — zero new trust surface.
      pgRoConverger = pkgs.writeShellApplication {
        name = "media-atlas-pg-ro";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.postgresql
          pkgs.util-linux
        ];
        text = ''
          set -euo pipefail
          role="${cfg.user}"
          db="${cfg.database.name}"
          psql() { runuser -u postgres -- psql -d "$db" -v ON_ERROR_STOP=1 "$@"; }

          if ! psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$role'" | grep -q 1; then
            psql -c "CREATE ROLE $role LOGIN"
            echo "media-atlas-pg-ro: created role $role"
          fi
          psql -c "GRANT CONNECT ON DATABASE $db TO $role" >/dev/null
          psql -c "GRANT USAGE ON SCHEMA public TO $role" >/dev/null
          psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $role" >/dev/null
          # Keep tables created by FUTURE Immich migrations readable: Immich
          # runs its migrations as the immich role, so default privileges are
          # set FOR ROLE immich (requires the superuser this converger runs as).
          psql -c "ALTER DEFAULT PRIVILEGES FOR ROLE immich IN SCHEMA public GRANT SELECT ON TABLES TO $role" >/dev/null
          echo "media-atlas-pg-ro: converged ($role has read-only access to db $db)"

          # Schema fingerprint: Phase-0 evidence (media-atlas TODO item 1) and
          # the anchor the hub's `atlas doctor` pins against the deployed Immich
          # version (plan L16). Absent table = WARN, not FAIL — the grants above
          # are the convergence contract; smart_search presence is Immich's
          # business (ML smart-search toggle), not this converger's.
          if psql -tAc "SELECT to_regclass('smart_search')" | grep -q smart_search; then
            echo "media-atlas-pg-ro: smart_search schema fingerprint:"
            psql -c "SELECT column_name || ' ' || data_type FROM information_schema.columns WHERE table_name='smart_search' ORDER BY ordinal_position"
            echo "media-atlas-pg-ro: smart_search rows: $(psql -tAc 'SELECT count(*) FROM smart_search')"
          else
            echo "media-atlas-pg-ro: WARN smart_search table not found in $db (ML smart search disabled or schema drifted past the converger)" >&2
          fi
        '';
      };

      # `atlas` from the repo flake (rev-pinned input): committed vendor/
      # tree, so the sandbox build needs no GOPRIVATE fetch setup.
      atlasPkg = inputs.media-atlas.packages.${pkgs.stdenv.hostPlatform.system}.atlas;

      # Root converger for BOTH API keys (discordsync-immich-key-provision
      # pattern — DB-level INSERT, idempotent, file-first reconcile):
      #   hub-api-key — the INBOUND key the serve unit requires on /api,
      #     /events and /thumb (OQ-5 single-key posture). Generated once;
      #     rotation = delete the file + restart this unit (the serve unit
      #     restarts via try-restart below).
      #   immich-key — the OUTBOUND key the hub's pulls and nightly timers
      #     use against Immich, minted as the api_key row
      #     "media-atlas-hub (nix-managed)" with the hub's least-privilege
      #     scope set (asset.read/view/statistics + tag.read for the NSFW
      #     lane join + library.read for scan-status checks).
      keyProvision = pkgs.writeShellApplication {
        name = "media-atlas-key-provision";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gawk
          pkgs.openssl
          pkgs.util-linux
          pkgs.systemd
          # psql CLIENT from pkgs (not config.services.postgresql.package):
          # no value when postgres is disabled and eval must not break on
          # immich-less hosts (discordsync provisioner rationale).
          pkgs.postgresql
        ];
        text = ''
          set -euo pipefail
          state="${stateDir}"
          hubkey="$state/hub-api-key"
          immkey="$state/immich-key"
          url="${hubCfg.immich.url}"
          keyname="media-atlas-hub (nix-managed)"
          db="${config.services.immich.database.name or "immich"}"
          psql() { runuser -u postgres -- psql -d "$db" -v ON_ERROR_STOP=1 "$@"; }

          install -d -o ${cfg.user} -g ${cfg.user} -m 0750 "$state"

          # Schema guard (loud): the INSERT below couples to Immich's api_key
          # shape — key is BYTEA holding the raw sha256 digest of the token
          # (api_keys renamed api_key by StandardizeNames; verified live on
          # 3.3.3 by the discordsync converger, 2026-10-25).
          key_type=$(psql -At -c "SELECT data_type FROM information_schema.columns WHERE table_name = 'api_key' AND column_name = 'key'")
          if [ "$key_type" != "bytea" ]; then
            echo "media-atlas-key-provision: FAIL api_key.key is '$key_type', expected bytea — Immich schema drifted past this converger" >&2
            exit 1
          fi
          uid=$(psql -At -c "SELECT id FROM \"user\" WHERE \"isAdmin\" IS TRUE ORDER BY \"createdAt\" LIMIT 1" || true)
          if [ -z "$uid" ]; then
            echo "media-atlas-key-provision: FAIL no admin user in Immich DB" >&2
            exit 1
          fi

          # --- inbound hub key: generate once, never rotate silently ---
          if [ ! -s "$hubkey" ]; then
            token=$(openssl rand -base64 32 | tr -d '/+=')
            case "$token" in
              *[!A-Za-z0-9]*) echo "media-atlas-key-provision: FAIL generated hub key contains unexpected characters" >&2; exit 1 ;;
            esac
            tmp=$(mktemp "$state/.hub-api-key.XXXXXX")
            printf '%s' "$token" > "$tmp"
            chown ${cfg.user}:${cfg.user} "$tmp"
            chmod 0400 "$tmp"
            mv -f "$tmp" "$hubkey"
            echo "media-atlas-key-provision: minted hub API key"
          else
            echo "media-atlas-key-provision: hub API key present (rotation = rm the file + restart this unit)"
          fi

          # --- outbound Immich key: file-first reconcile ---
          token=""
          if [ -r "$immkey" ]; then
            token=$(cat "$immkey")
          fi

          insert_key() {
            psql -c "INSERT INTO api_key (name, key, \"userId\", permissions) VALUES ('$keyname', decode('$1', 'hex'), '$uid', ARRAY['asset.read','asset.view','asset.statistics','tag.read','library.read']::varchar[])"
          }

          if [ -n "$token" ]; then
            hex=$(printf '%s' "$token" | openssl dgst -sha256 -hex | awk '{print $NF}')
            cnt=$(psql -At -c "SELECT count(*) FROM api_key WHERE key = decode('$hex', 'hex')")
            if [ "$cnt" -ge 1 ]; then
              echo "media-atlas-key-provision: converged (immich-key file + api_key row consistent)"
              systemctl try-restart media-atlas.service || true
              exit 0
            fi
            echo "media-atlas-key-provision: immich-key file present but row missing (DB restore?) — re-inserting from file plaintext"
            insert_key "$hex"
          else
            token=$(openssl rand -base64 32 | tr -d '/+=')
            case "$token" in
              *[!A-Za-z0-9]*) echo "media-atlas-key-provision: FAIL generated Immich token contains unexpected characters" >&2; exit 1 ;;
            esac
            hex=$(printf '%s' "$token" | openssl dgst -sha256 -hex | awk '{print $NF}')
            # Drop stale rows of THIS key name (orphaned hashes from a
            # deleted file can never re-validate; other keys are untouched).
            for rid in $(psql -At -c "SELECT id FROM api_key WHERE name = '$keyname'"); do
              psql -c "DELETE FROM api_key WHERE id = '$rid'"
            done
            insert_key "$hex"
            tmp=$(mktemp "$state/.immich-key.XXXXXX")
            printf '%s' "$token" > "$tmp"
            chown ${cfg.user}:${cfg.user} "$tmp"
            chmod 0400 "$tmp"
            mv -f "$tmp" "$immkey"
            echo "media-atlas-key-provision: minted Immich API key ($keyname)"
          fi
          systemctl try-restart media-atlas.service || true
        '';
      };
    in
    {
      options.services.media-atlas = {
        enable = lib.mkEnableOption "MediaAtlas hub groundwork: read-only Postgres role on the immich DB (smart_search) plus optional Immich external-library read access to the DiscordSync archive. The hub service itself (unit, port, vHost) lands in a later PR.";

        database.name = lib.mkOption {
          type = lib.types.str;
          default = "immich";
          defaultText = "immich";
          description = "Target database for the read-only role (the shared-cluster immich DB).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "media_atlas";
          description = "Hub OS user and matching PG role (peer auth on the local socket requires role name == OS user name).";
        };

        immichExternalLibrary.enable = lib.mkEnableOption "Immich read-only access to the DiscordSync attachments archive (external library, DiscordSync ADR-061 runbook: group read + namespace-level RO bind)";

        immichExternalLibrary.importPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          defaultText = "resolved from services.discordsync (attachmentsDir when set, else <dataDir>/attachments)";
          description = "Override for the archive path Immich reads (null = derive from the discordsync module).";
        };

        hub.enable = lib.mkEnableOption "the MediaAtlas hub service: `atlas serve` on loopback behind the map.home.lan vHost, with the media-atlas-key-provision converger minting the inbound hub key and the outbound Immich key";

        hub.package = lib.mkOption {
          type = lib.types.package;
          default = atlasPkg;
          defaultText = lib.literalExpression "inputs.media-atlas.packages.\${pkgs.stdenv.hostPlatform.system}.atlas";
          description = "atlas package serving the hub (single source of truth: the rev-pinned flake input).";
        };

        hub.port = lib.mkOption {
          type = lib.types.port;
          default = ports.media-atlas;
          defaultText = "ports.media-atlas (8493)";
          description = "Loopback port for `atlas serve` (lib/ports.nix; dev instances squat 8491/8492).";
        };

        hub.immich.url = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:${toString config.services.immich.port or 2283}";
          defaultText = "http://127.0.0.1:2283";
          description = "Immich base URL for the hub's pulls and proxies (loopback http on the same host; https at the caddy name would TLS-double-hop).";
        };

        hub.immich.mlUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:${toString ports.immich-ml}";
          defaultText = "http://127.0.0.1:3003";
          description = "Immich machine-learning service base URL (text-query embeddings, the upstream CLI default).";
        };
      };

      config = lib.mkIf cfg.enable {
        # Peer-auth principal for the hub: OS user == PG role. The hub service
        # unit (L25) runs as this user and connects over the local socket.
        users.groups.${cfg.user} = { };
        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.user;
          description = "MediaAtlas federation hub (read-only peer-auth PG access to immich smart_search)";
        };

        systemd.services.media-atlas-pg-ro = {
          description = "MediaAtlas read-only Postgres role converger (grants on the immich DB via peer-auth postgres)";
          after = [
            "postgresql.service"
          ];
          wants = [
            "postgresql.service"
          ];
          # multi-user-wanted (crowdsec-setup pattern): the deploy.sh
          # provisioner loop's is-enabled gate admits it, so every deploy
          # re-converges the grants. Boot-time run covers DB-restore healing.
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe pgRoConverger;
              TimeoutStartSec = "2min";
              # Root BY DESIGN (discordsync-immich-key-provision pattern):
              # peer-auth postgres via runuser and ALTER DEFAULT PRIVILEGES FOR
              # ROLE immich need superuser; no secret exists to authenticate
              # with. NoNewPrivileges stays OFF — runuser is setuid and the
              # script legitimately needs it.
              NoNewPrivileges = false;
              ProtectSystem = "strict";
              PrivateTmp = true;
            }
            # io-tier-coverage-audit: every boot-gated unit carries a tier.
            ioTier.background
          ];
        };

        # --- Immich external-library read access (ADR-061 runbook) ---
        users.users.immich.extraGroups = lib.mkIf cfg.immichExternalLibrary.enable [
          config.services.discordsync.group
        ];
        systemd.services.immich-server = lib.mkIf cfg.immichExternalLibrary.enable {
          # Mount-gated (226 class): a detached DAS fails the unit loudly
          # instead of scanning a root-fs shadow path.
          unitConfig.RequiresMountsFor = [ archivePath ];
          # Namespace-level RO over the group-rwx archive dir: Immich never
          # writes external-library files, and the bind makes that a kernel
          # guarantee instead of an application promise.
          serviceConfig.BindReadOnlyPaths = [ archivePath ];
        };

        # --- The hub service (v0.1 deploy, L25) ---
        systemd.services.media-atlas-key-provision = lib.mkIf hubCfg.enable {
          description = "MediaAtlas API key provisioner (inbound hub key + outbound Immich key, idempotent converger)";
          after = [
            "postgresql.service"
            "media-atlas-pg-ro.service"
          ];
          wants = [ "postgresql.service" ];
          # multi-user-wanted (pg-ro pattern): every deploy re-converges the
          # keys; boot-time run covers DB-restore healing.
          wantedBy = [ "multi-user.target" ];
          # Keys must exist before the hub reads them at first start.
          before = [ "media-atlas.service" ];
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = lib.getExe keyProvision;
              TimeoutStartSec = "2min";
              # Root BY DESIGN (pg-ro/discordsync-provision pattern): peer
              # auth psql via runuser; no secret exists to authenticate with.
              NoNewPrivileges = false;
              ProtectSystem = "strict";
              PrivateTmp = true;
              ReadWritePaths = [ stateDir ];
            }
            ioTier.background
          ];
        };

        systemd.services.media-atlas = lib.mkIf hubCfg.enable {
          description = "MediaAtlas federation hub (atlas serve, loopback behind the map vHost)";
          inherit onFailure;
          after = [
            "network.target"
            "postgresql.service"
            "media-atlas-key-provision.service"
          ];
          wants = [ "postgresql.service" ];
          wantedBy = [ "multi-user.target" ];

          # The provisioner must have converged (it owns the key files the
          # flags below point at); if it failed, onFailure pages instead of
          # the hub flapping on a missing key file.
          requires = [ "media-atlas-key-provision.service" ];

          # SQLite WAL on the pool — flapping restart-hammers it for no
          # gain; generous start-limit window (journal-serve pattern).
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "1G";
            })
            (serviceDefaults { })
            # The journal rides the QLC root — never compete with the
            # desktop or Immich for I/O.
            ioTier.background
            {
              User = cfg.user;
              Group = cfg.user;
              StateDirectory = stateDirName;
              StateDirectoryMode = "0750";
              ExecStart = lib.concatStringsSep " " [
                "${lib.getExe hubCfg.package} serve"
                "--db ${stateDir}/atlas.db"
                "--addr 127.0.0.1:${toString hubCfg.port}"
                "--api-key-file ${stateDir}/hub-api-key"
                "--immich-url ${hubCfg.immich.url}"
                "--immich-ml-url ${hubCfg.immich.mlUrl}"
                "--immich-key-file ${stateDir}/immich-key"
              ];
            }
          ];
        };

        # Service-integration registry entry: fans out to the Caddy vHost
        # (map.home.lan, PLAIN layer — the hub's own API key is the single
        # auth gate (OQ-5); oauth2-proxy forward-auth would double-gate),
        # the Gatus checks, and the dashboard tile.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          "media-atlas" = lib.mkIf hubCfg.enable {
            enable = true;
            port = hubCfg.port;
            subdomain = "map";
            vHost.layer = "plain";
            checks = [
              {
                name = "MediaAtlas hub ready";
                group = "Media";
                path = "/health/ready";
              }
              {
                name = "MediaAtlas map plate";
                group = "Media";
                path = "/";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                  # Functional, not just liveness: every plate carries the
                  # "Map · MediaAtlas" title (the templ page head) — an
                  # error shell would not.
                  "[BODY] == pat(*MediaAtlas*)"
                ];
                alert = "MediaAtlas map down — the federation hub at map.home.lan is unreachable. Check: systemctl status media-atlas, journalctl -u media-atlas -n 50.";
              }
            ];
            homepage = {
              name = "MediaAtlas";
              group = "Media";
              description = "Federated semantic media map (Immich + DiscordSync)";
              # No atlas glyph in the homepage icon pack; photoprism is the
              # photo-map icon (the hub IS the map layer over Immich).
              icon = "photoprism.png";
            };
          };
        };
      };
    };
}
