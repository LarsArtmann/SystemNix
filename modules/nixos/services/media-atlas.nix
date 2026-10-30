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
#   4. Nightly refresh timers (hub.pollEmbeddings / hub.umapNightly /
#      hub.laneJoin, the v0.1 follow-up lifting the repo's
#      docs/deploy/umap-nightly-timer.nix shape onto the real flake
#      outputs): smart_search embeddings diff poll (02:00) + UMAP refit
#      (03:00, IO/CPU-quiet knobs verbatim from the reviewed shape) + NSFW
#      lane join (04:00, landed 2026-10-30 once the hub's joinLanes
#      merge-fold contract was pinned by
#      TestJoinLanes_LaneJoinPreservesEmbeddingAndCoords — the earlier
#      MapSet-strip concern is closed upstream of this module).
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
        mkPoolDirUnit
        serviceDefaults
        serviceOneshotDefaults
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

      # The UMAP sidecar wrapper from the SAME rev-pinned input (flake app:
      # python3 + umap-learn around scripts/umap_fit.py) — single
      # provenance with atlasPkg, no second lock surface to drift.
      umapFitProgram = inputs.media-atlas.apps.${pkgs.stdenv.hostPlatform.system}.umap-fit.program;

      # Root converger: make the DiscordSync attachment tree group-readable
      # so the Immich crawler can walk it (ADR-061 external-library grant:
      # the immich user IS in the discordsync group, and the archive ROOT
      # is 0770 discordsync:discordsync). The per-channel subdirs the
      # DiscordSync writer creates carry a restrictive umask though — the
      # FIRST scan EACCES'd on attachments/00 while the root listed fine
      # (2026-10-29, immich-server journal). chmod g+rX is idempotent and
      # cheap on the ~5.5k-file tree; the deploy loop re-runs it so new
      # subdirs converge. Durable writer-side fix (UMask on the DiscordSync
      # unit) stays a DiscordSync-lane follow-up — ADR-061 keeps that repo
      # change-free for MVP.
      archivePermConverger = pkgs.writeShellApplication {
        name = "media-atlas-archive-perms";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          set -euo pipefail
          archive="${archivePath}"
          if [ ! -d "$archive" ]; then
            echo "media-atlas-archive-perms: $archive missing (pool unmounted?) — nothing to converge" >&2
            exit 0
          fi
          find "$archive" -depth -exec chmod g+rX -- {} +
          echo "media-atlas-archive-perms: converged group-read on the archive tree"
        '';
      };

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

        hub.immich.mlModel = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "CLIP model for the hub's text queries — MUST equal the Immich smart-search model (Immich admin → machine learning, live: ViT-B-32__openai on this deployment). Empty = /api/search answers 502 with a config hint; embeddings from a different model would not share the stored vectors' space.";
        };

        hub.pollEmbeddings = {
          enable = lib.mkEnableOption "the nightly smart_search embeddings diff poll (`atlas poll-embeddings` — idempotent, unchanged embeddings emit nothing; new assets still enter via pull/tail)";

          calendar = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 02:00";
            description = "OnCalendar for the embeddings diff poll (ahead of the UMAP refit window).";
          };
        };

        hub.umapNightly = {
          enable = lib.mkEnableOption "the nightly UMAP refit (export → fit/transform → project-coords), lifting the repo's docs/deploy/umap-nightly-timer.nix shape onto the flake outputs";

          calendar = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 03:00";
            description = "OnCalendar for the UMAP refit (03:00 + RandomizedDelaySec avoids the other nightly windows on evo-x2).";
          };
        };

        hub.laneJoin = {
          enable = lib.mkEnableOption "the nightly NSFW verdict lane join (atlas pull --with-lanes: metadata walk + Immich tag walk, landed once the hub's lane-join merge-fold contract was pinned)";

          calendar = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 04:00";
            description = "OnCalendar for the lane join (after the UMAP window; own failure domain — it never wants the poll or the refit).";
          };
        };

        hub.dbBackup = {
          enable = lib.mkEnableOption "the nightly journal DB dump onto the HDD pool (online sqlite .backup, 14d retention, browser-history/cv pattern; the dir rides restic-app-dumps via extraPaths)";

          calendar = lib.mkOption {
            type = lib.types.str;
            default = "*-*-* 05:00";
            description = "OnCalendar for the journal dump (after the nightly refresh windows, before restic-app-dumps' 05:45 pickup).";
          };
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
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
          systemd.services.media-atlas-archive-perms = lib.mkIf cfg.immichExternalLibrary.enable {
            description = "MediaAtlas archive permission converger (group-read on the DiscordSync attachment tree for the Immich crawler)";
            # Mount-gated (226 class): a detached DAS skips cleanly via the
            # converger's -d guard, never shadow-writes a root-fs path.
            unitConfig.RequiresMountsFor = [ archivePath ];
            wantedBy = [ "multi-user.target" ];
            # Converge BEFORE the crawler can scan.
            before = [ "immich-server.service" ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = lib.getExe archivePermConverger;
                TimeoutStartSec = "10min";
                # chmod on a discordsync-owned tree needs root; no secret, no
                # runuser — NoNewPrivileges stays ON.
                ProtectSystem = "strict";
                PrivateTmp = true;
                ReadWritePaths = [ archivePath ];
              }
              ioTier.background
            ];
          };

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
                  "--immich-ml-model ${hubCfg.immich.mlModel}"
                  "--immich-key-file ${stateDir}/immich-key"
                ];
              }
            ];
          };

          # --- Nightly refresh timers (v0.1 follow-up, plan L25.1) ---
          # The repo's reviewed shape (docs/deploy/umap-nightly-timer.nix)
          # lifted onto the real flake outputs. All three timers are
          # idempotent; failures toast via onFailure (a silently stale map is
          # the exact failure mode these exist to prevent). The NSFW
          # lane-join timer landed 2026-10-30: the hub's joinLanes
          # MapSet-strip concern closed upstream (merge-fold contract pinned
          # by TestJoinLanes_LaneJoinPreservesEmbeddingAndCoords), so the
          # join now runs nightly AFTER the refit — coords and embeddings
          # written tonight survive tomorrow's join.

          # Embeddings diff poll: re-joins smart_search onto the existing
          # inventory through the peer-auth local socket, so the unit MUST
          # run as the media_atlas OS user (same principal as the hub).
          systemd.services.media-atlas-poll-embeddings =
            lib.mkIf (hubCfg.enable && hubCfg.pollEmbeddings.enable)
              {
                description = "MediaAtlas smart_search embeddings diff poll (atlas poll-embeddings, idempotent)";
                inherit onFailure;
                after = [ "postgresql.service" ];
                wants = [ "postgresql.service" ];
                path = [ pkgs.coreutils ];
                serviceConfig = lib.mkMerge [
                  {
                    Type = "oneshot";
                    User = cfg.user;
                    Group = cfg.user;
                    StateDirectory = stateDirName;
                    TimeoutStartSec = "10min";
                  }
                  (harden { MemoryMax = "512M"; })
                  # BE/6 background, NOT idle: a seconds-long PG join should not
                  # stall behind transcription storms the way an idle-class job may.
                  ioTier.background
                  (serviceOneshotDefaults { })
                ];
                script = ''
                  set -eu
                  # The trailing stamp is the C10 freshness contract: the
                  # hub's /health/timers reads it and gatus alerts when the
                  # age blows the 36h budget (set -eu: a failed poll never
                  # stamps).
                  ${lib.getExe hubCfg.package} poll-embeddings --db ${stateDir}/atlas.db
                  date +%s > ${stateDir}/last-success-poll-embeddings
                '';
              };

          systemd.timers.media-atlas-poll-embeddings =
            lib.mkIf (hubCfg.enable && hubCfg.pollEmbeddings.enable)
              {
                description = "Nightly MediaAtlas embeddings diff poll";
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = hubCfg.pollEmbeddings.calendar;
                  Persistent = true;
                  RandomizedDelaySec = "30m";
                };
              };

          # UMAP refit: export → fit/transform (--mode auto keeps the model
          # persistent, transforming only stragglers) → project-coords, all
          # against the live journal (SQLite WAL: coexists with the hub).
          systemd.services.media-atlas-umap = lib.mkIf (hubCfg.enable && hubCfg.umapNightly.enable) {
            description = "MediaAtlas UMAP nightly refit (export -> fit/transform -> project-coords)";
            inherit onFailure;
            # Freshness semantics, precisely: a MISSED poll (host was down;
            # the unit never ran tonight) is pulled in and re-run before the
            # fit by the wants+after pair. A FAILED poll does NOT block the
            # fit — Wants= (not Requires=) lets the refit proceed on the
            # last-good matrix while the poll's onFailure toast reports the
            # gap; Persistent=true still catches the missed-run case on boot.
            after = lib.optional hubCfg.pollEmbeddings.enable "media-atlas-poll-embeddings.service";
            wants = lib.optional hubCfg.pollEmbeddings.enable "media-atlas-poll-embeddings.service";
            path = [ pkgs.coreutils ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = cfg.user;
                Group = cfg.user;
                StateDirectory = [
                  stateDirName
                  "${stateDirName}/umap"
                ];
                TimeoutStartSec = "30min";
              }
              # IO/CPU-quiet knobs carried verbatim from the reviewed shape:
              # the nightly must never be the load that competes with live
              # services on the QLC root (2026-10-27 lesson: load-300
              # transcription batches).
              (harden {
                MemoryMax = "2G"; # generous headroom, not a tight bound: numba JIT dominates
                ProtectSystem = "strict";
                # Root state dir included explicitly (not just the umap
                # subtree): project-coords writes the journal + WAL next
                # to atlas.db under strict — do not rely on the
                # StateDirectory exemption subtlety.
                ReadWritePaths = [
                  stateDir
                  "${stateDir}/umap"
                ];
              })
              {
                Nice = 19;
                IOSchedulingClass = "idle";
                CPUWeight = 20;
                IOWeight = 50;
              }
              (serviceOneshotDefaults { })
            ];
            script = ''
              set -eu
              ${lib.getExe hubCfg.package} export --db ${stateDir}/atlas.db --out ${stateDir}/umap/export.json
              ${umapFitProgram} --input ${stateDir}/umap/export.json --output ${stateDir}/umap/coords.json --model-dir ${stateDir}/umap/model --mode auto
              ${lib.getExe hubCfg.package} project-coords --db ${stateDir}/atlas.db --in ${stateDir}/umap/coords.json --run "$(date +%F)"
              # C10 freshness stamp (see the poll unit) — only a COMPLETE
              # refit stamps: export/fit/project all had to succeed.
              date +%s > ${stateDir}/last-success-umap
            '';
          };

          systemd.timers.media-atlas-umap = lib.mkIf (hubCfg.enable && hubCfg.umapNightly.enable) {
            description = "Nightly MediaAtlas UMAP refit";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = hubCfg.umapNightly.calendar;
              Persistent = true;
              RandomizedDelaySec = "30m";
            };
          };

          # NSFW verdict lane join: `atlas pull --with-lanes` (full walk —
          # --skip-metadata is rejected by design there: the tag walk needs
          # the API key from the metadata half). Own failure domain BY
          # ORDER ONLY: after= the refit so a lane-joined asset's coords
          # are already in the journal, but NO wants= — a failed refit must
          # not block the join and vice versa (each toasts independently;
          # the join is ~6s and idempotent, the refit is the expensive one).
          systemd.services.media-atlas-lane-join = lib.mkIf (hubCfg.enable && hubCfg.laneJoin.enable) {
            description = "MediaAtlas NSFW verdict lane join (atlas pull --with-lanes, idempotent)";
            inherit onFailure;
            after = lib.optional hubCfg.umapNightly.enable "media-atlas-umap.service";
            path = [ pkgs.coreutils ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = cfg.user;
                Group = cfg.user;
                StateDirectory = stateDirName;
                TimeoutStartSec = "10min";
              }
              (harden { MemoryMax = "512M"; })
              # BE/6 background like the poll (NOT idle): same
              # seconds-walk-should-not-stall reasoning as the poll unit.
              ioTier.background
              (serviceOneshotDefaults { })
            ];
            script = ''
              set -eu
              # C10 freshness stamp (see the poll unit).
              ${lib.getExe hubCfg.package} pull --db ${stateDir}/atlas.db --immich-url ${hubCfg.immich.url} --immich-key-file ${stateDir}/immich-key --with-lanes
              date +%s > ${stateDir}/last-success-lane-join
            '';
          };

          systemd.timers.media-atlas-lane-join = lib.mkIf (hubCfg.enable && hubCfg.laneJoin.enable) {
            description = "Nightly MediaAtlas NSFW verdict lane join";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = hubCfg.laneJoin.calendar;
              Persistent = true;
              RandomizedDelaySec = "30m";
            };
          };

          # ── Nightly journal DB backup onto the HDD pool (C10.3) ───────────
          # Online `sqlite3 .backup` (safe against the live WAL writer) of
          # /var/lib/media-atlas/atlas.db onto /mnt/pool/backups, 14d
          # retention — the browser-history/cv pattern verbatim. Pool-leaf
          # creation is mount-gated (mkPoolDirUnit — no tmpfiles rule under
          # /mnt/pool). Default OFF: the units hard-depend on the pool
          # (RequiresMountsFor); evo-x2 opts in via configuration.nix.
          # The dir rides the restic app-dumps repo via that module's
          # extraPaths, and the freshness entry below (maxAge 26h) alerts
          # when the nightly dump goes silent.
          systemd.services.media-atlas-backup-dir =
            lib.mkIf (hubCfg.enable && hubCfg.dbBackup.enable)
              (mkPoolDirUnit {
                description = "Create MediaAtlas journal DB backup directory on the HDD pool";
                directory = "/mnt/pool/backups/media-atlas";
              });

          systemd.services.media-atlas-backup = lib.mkIf (hubCfg.enable && hubCfg.dbBackup.enable) {
            description = "MediaAtlas journal DB backup (online sqlite .backup)";
            after = [
              "media-atlas.service"
              "media-atlas-backup-dir.service"
            ];
            wants = [ "media-atlas-backup-dir.service" ];
            # Detached DAS fails the run as a clean dependency error, never
            # 226/NAMESPACE (btrbk doctrine).
            unitConfig.RequiresMountsFor = [ "/mnt/pool/backups/media-atlas" ];
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            path = [ pkgs.coreutils ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = cfg.user;
                Group = cfg.user;
                StateDirectory = stateDirName;
                TimeoutStartSec = "10min";
                ExecStart = pkgs.writeShellScript "media-atlas-backup" ''
                  set -euo pipefail
                  db="${stateDir}/atlas.db"
                  if [ ! -f "$db" ]; then
                    echo "media-atlas-backup: no atlas.db yet — nothing to back up"
                    exit 0
                  fi
                  dst="/mnt/pool/backups/media-atlas/atlas-$(date +%Y-%m-%d).db"
                  # -readonly: a read-write open of the live WAL database
                  # can create/replace the -shm/-wal sidecars while the hub
                  # is down, poisoning the next hub start with
                  # SQLITE_READONLY (the 2026-09-22 uid-drift class).
                  ${lib.getExe pkgs.sqlite} -readonly "$db" ".backup '$dst'"
                  # 14-day retention (browser-history/cv pattern); the
                  # online .backup rewrites every page, nothing shared
                  # between nights.
                  find /mnt/pool/backups/media-atlas -name "atlas-*.db" -mtime +14 -delete
                  echo "media-atlas-backup: wrote $dst"
                '';
                ReadWritePaths = [ "/mnt/pool/backups/media-atlas" ];
              }
              (harden { MemoryMax = "512M"; })
              ioTier.background
              (serviceOneshotDefaults { })
            ];
          };

          systemd.timers.media-atlas-backup = lib.mkIf (hubCfg.enable && hubCfg.dbBackup.enable) {
            description = "Nightly MediaAtlas journal DB backup";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = hubCfg.dbBackup.calendar;
              Persistent = true;
              RandomizedDelaySec = "10m";
            };
          };

          # The dump dir joins the restic app-dumps repo (extraPaths —
          # extend, never redefine the fleet default list).
          services.restic-app-dumps.extraPaths = lib.mkIf (hubCfg.enable && hubCfg.dbBackup.enable) [
            "/mnt/pool/backups/media-atlas"
          ];

          # Service-integration registry entry: fans out to the Caddy vHost
          # (map.home.lan, PLAIN layer — the hub's own API key is the single
          # auth gate (OQ-5); oauth2-proxy forward-auth would double-gate),
          # the Gatus checks, and the dashboard tile.
          services.integration = lib.optionalAttrs (options ? services.integration) {
            "media-atlas" = lib.mkIf hubCfg.enable {
              enable = true;
              inherit (hubCfg) port;
              subdomain = "map";
              vHost.layer = "plain";
              checks = [
                {
                  name = "MediaAtlas hub ready";
                  group = "Media";
                  path = "/health/ready";
                }
                {
                  # The hub's search lane dials Immich ML (—immich-ml-url);
                  # probe the dependency so an ML outage pages here instead
                  # of surfacing as mystery 502s on the map.
                  name = "Immich ML (media-atlas search dependency)";
                  group = "Media";
                  url = "tcp://127.0.0.1:${toString ports.immich-ml}";
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
                {
                  # C10.2: the nightlies' last-success stamps (poll 02:00,
                  # umap 03:00, lane-join 04:00) as the hub reports them —
                  # "fresh" means every stamp exists and is inside the 36h
                  # budget (one missed night still passes: Persistent=true
                  # catches up). "unknown" fires pre-first-run on a fresh
                  # deploy and clears at 02:00.
                  name = "MediaAtlas nightlies fresh";
                  group = "Media";
                  path = "/health/timers";
                  interval = "15m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\"rollup\":\"fresh\"*)"
                  ];
                  alert = "MediaAtlas nightly stale — a last-success stamp is missing or >36h old (per-timer ages on /health/timers). Check: journalctl -u media-atlas-poll-embeddings -u media-atlas-umap -u media-atlas-lane-join -n 50.";
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

              # C10.3: backup-coordination freshness over the pool dump dir
              # (the nightly media-atlas-backup writes atlas-YYYY-MM-DD.db
              # there; restic-app-dumps mirrors the dir via extraPaths). The
              # registry's mtime check alerts when the nightly dump goes
              # silent — the journal is the irreplaceable artifact ( Immich
              # and DiscordSync can be re-walked; the ingested history and
              # projections cannot).
              backup = lib.mkIf hubCfg.dbBackup.enable {
                directory = "/mnt/pool/backups/media-atlas";
                filePattern = "atlas-*.db";
                maxAgeHours = 26;
              };
            };
          };
        })
        {
          assertions = [
            {
              assertion = !hubCfg.umapNightly.enable || hubCfg.enable;
              message = "services.media-atlas.hub.umapNightly.enable requires hub.enable (shared state dir, journal path and peer-auth user).";
            }
            {
              assertion = !hubCfg.pollEmbeddings.enable || hubCfg.enable;
              message = "services.media-atlas.hub.pollEmbeddings.enable requires hub.enable (peer-auth media_atlas user + journal path).";
            }
            {
              assertion = !hubCfg.laneJoin.enable || hubCfg.enable;
              message = "services.media-atlas.hub.laneJoin.enable requires hub.enable (state dir + Immich key file).";
            }
            {
              assertion = !hubCfg.dbBackup.enable || hubCfg.enable;
              message = "services.media-atlas.hub.dbBackup.enable requires hub.enable (journal path + peer-auth user).";
            }
          ];
        }
      ];
    };
}
