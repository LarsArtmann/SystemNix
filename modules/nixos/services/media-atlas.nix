# Runbook: docs/services/media-atlas.md
# MediaAtlas federation hub — DELEGATION layer (SUPERB phase-2 F2,
# 2026-11-08): the product repo owns the generic hub contract
# (nix/nixos-module.nix in LarsArtmann/media-atlas — the `atlas serve`
# unit shape, the nightly timer family with its ordering semantics, the
# hub user), imported via inputs.media-atlas.nixosModules.default.
# SystemNix layers ONLY site specifics:
#   1. media_atlas PG role with READ-ONLY access to the immich DB
#      (smart_search embeddings for the hub's vector store) — converged by
#      a root oneshot (peer-auth postgres via runuser, the
#      discordsync-immich-key-provision pattern).
#   2. Optional: Immich read-only access to the DiscordSync attachment
#      archive (DiscordSync ADR-061 external-library runbook): the immich
#      user joins the discordsync group for DAC read, and
#      BindReadOnlyPaths enforces RO at the namespace level.
#   3. The media-atlas-key-provision converger that mints both API keys
#      (inbound hub key + outbound Immich key with asset.read/view/
#      statistics + tag.read + library.read) the discordsync-immich-key-
#      provision way: DB-level INSERT, idempotent by key name,
#      file-first reconcile, secret only ever in a 0400 file under the
#      state dir.
#   4. Fleet layer ON the upstream-owned units: harden bounds (serve 1G /
#      poll+lane 512M / umap 2G), ioTier.background (NOT on umap — its
#      idle-class nightly knobs come from upstream), onFailure toasts,
#      the postgresql + key-provision dependency edges on the serve unit.
#   5. The pool journal-DB backup family (dbBackup) + restic extraPaths +
#      the integration registry fan-out (map.home.lan, plain layer — the
#      hub's own API key is the single auth gate).
# Upstream-option surface (services.media-atlas.hub.*): enable, package,
# user, group, port, apiKeyFile, immich.{url,mlUrl,mlModel,keyFile},
# pollEmbeddings, umapNightly (incl. fitProgram), laneJoin — all declared
# UPSTREAM; this layer sets the site values and never re-declares them.
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

      # `atlas` from the repo flake (floating input): committed vendor/
      # tree, so the sandbox build needs no GOPRIVATE fetch setup.
      atlasPkg = inputs.media-atlas.packages.${pkgs.stdenv.hostPlatform.system}.atlas;

      # The UMAP sidecar wrapper from the SAME input (flake app: python3 +
      # umap-learn around scripts/umap_fit.py) — single provenance with
      # atlasPkg, no second lock surface to drift.
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
      # The generic hub contract (serve unit, nightly timers, hub user)
      # lives upstream — importing it here makes inputs.media-atlas the
      # single source of that truth.
      imports = [ inputs.media-atlas.nixosModules.default ];

      options.services.media-atlas = {
        enable = lib.mkEnableOption "MediaAtlas site layer: read-only Postgres role on the immich DB (smart_search) for the hub, optional Immich external-library read access to the DiscordSync archive, the API-key provisioner, pool journal backups, and the fleet layer over the upstream hub units (services.media-atlas.hub.* — declared by inputs.media-atlas.nixosModules.default)";

        database.name = lib.mkOption {
          type = lib.types.str;
          default = "immich";
          defaultText = "immich";
          description = "Target database for the read-only role (the shared-cluster immich DB).";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "media_atlas";
          description = "Hub OS user and matching PG role (peer auth on the local socket requires role name == OS user name); feeds services.media-atlas.hub.user.";
        };

        immichExternalLibrary.enable = lib.mkEnableOption "Immich read-only access to the DiscordSync attachments archive (external library, DiscordSync ADR-061 runbook: group read + namespace-level RO bind)";

        immichExternalLibrary.importPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          defaultText = "resolved from services.discordsync (attachmentsDir when set, else <dataDir>/attachments)";
          description = "Override for the archive path Immich reads (null = derive from the discordsync module).";
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
        # Peer-auth principal for the hub-less groundwork case (PG role +
        # external library alone). When the hub is enabled the UPSTREAM
        # module owns identity creation (same media_atlas principal via
        # the hub.user/group sets below) — creating it here too would
        # collide on the description string.
        (lib.mkIf (cfg.enable && !cfg.hub.enable) {
          users.groups.${cfg.user} = { };
          users.users.${cfg.user} = {
            isSystemUser = true;
            group = cfg.user;
            description = "MediaAtlas federation hub (read-only peer-auth PG access to immich smart_search)";
          };
        })

        # Site values for the upstream-owned hub options (single source:
        # the media-atlas flake input; port from the registry; loopback
        # Immich URLs). Set under the site gate so a bare hub.enable on an
        # enable=false host stays an assertion error instead of half-site.
        (lib.mkIf cfg.enable {
          services.media-atlas.hub = {
            package = atlasPkg;
            inherit (cfg) user;
            group = cfg.user;
            port = ports.media-atlas;
            immich = {
              url = "http://127.0.0.1:${toString (config.services.immich.port or 2283)}";
              mlUrl = "http://127.0.0.1:${toString ports.immich-ml}";
            };
            umapNightly.fitProgram = umapFitProgram;
          };
        })

        (lib.mkIf cfg.enable {
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
        })

        # ── Fleet layer on the UPSTREAM-owned hub units ──────────────────
        # The upstream module provides the full unit shapes (ExecStart,
        # StateDirectory, Type=notify without WatchdogSec, start-limit
        # window, the nightly ordering semantics); this layer adds only
        # what is site policy: fleet harden bounds, ioTier.background
        # (never on umap — its idle-class nightly knobs come from
        # upstream), onFailure toasts, and the serve unit's dependency
        # edges onto the site convergers.
        (lib.mkIf (cfg.enable && hubCfg.enable) {
          systemd.services.media-atlas = {
            inherit onFailure;
            after = [
              "postgresql.service"
              "media-atlas-key-provision.service"
            ];
            wants = [ "postgresql.service" ];
            # The provisioner must have converged (it owns the key files the
            # serve flags point at); if it failed, onFailure pages instead of
            # the hub flapping on a missing key file.
            requires = [ "media-atlas-key-provision.service" ];
            serviceConfig = lib.mkMerge [
              # ProtectSystem/ProtectHome passed INTO harden (not left at
              # its full/true defaults) so they match the upstream unit's
              # own mkDefault strict/read-only — equal values merge clean,
              # and strict (vs the old full) is the upstream contract:
              # StateDirectory keeps the journal + key files writable.
              (harden {
                MemoryMax = "1G";
                ProtectSystem = "strict";
                ProtectHome = "read-only";
              })
              (serviceDefaults { })
              # The journal rides the QLC root — never compete with the
              # desktop or Immich for I/O.
              ioTier.background
            ];
          };

          systemd.services.media-atlas-poll-embeddings = {
            inherit onFailure;
            after = [ "postgresql.service" ];
            wants = [ "postgresql.service" ];
            serviceConfig = lib.mkMerge [
              (harden { MemoryMax = "512M"; })
              # BE/6 background, NOT idle: a seconds-long PG join should not
              # stall behind transcription storms the way an idle-class job may.
              ioTier.background
              (serviceOneshotDefaults { })
            ];
          };

          systemd.services.media-atlas-umap = {
            inherit onFailure;
            serviceConfig = lib.mkMerge [
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
              (serviceOneshotDefaults { })
            ];
          };

          systemd.services.media-atlas-lane-join = {
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden { MemoryMax = "512M"; })
              # BE/6 background like the poll (NOT idle): same
              # seconds-walk-should-not-stall reasoning as the poll unit.
              ioTier.background
              (serviceOneshotDefaults { })
            ];
          };

          # ── Nightly journal DB backup onto the HDD pool (C10.3) ────────
          # Online `sqlite3 .backup` (safe against the live WAL writer) of
          # /var/lib/media-atlas/atlas.db onto /mnt/pool/backups, 14d
          # retention — the browser-history/cv pattern verbatim. Pool-leaf
          # creation is mount-gated (mkPoolDirUnit — no tmpfiles rule under
          # /mnt/pool). Default OFF: the units hard-depend on the pool
          # (RequiresMountsFor); evo-x2 opts in via configuration.nix.
          # The dir rides the restic app-dumps repo via that module's
          # extraPaths, and the freshness entry below (maxAge 26h) feeds
          # backup_healthy{backup="media-atlas"} — its per-backup freshness
          # gatus check pages when the nightly dump goes silent (the
          # aggregate check alone sat chronically red and masked this
          # outage; per-service checks landed 2026-11-04).
          systemd.services.media-atlas-backup-dir = lib.mkIf hubCfg.dbBackup.enable (mkPoolDirUnit {
            description = "Create MediaAtlas journal DB backup directory on the HDD pool";
            directory = "/mnt/pool/backups/media-atlas";
            # The backup unit runs as the peer-auth user (cfg.user), not
            # root — an unowned root:root 0755 leaf makes the nightly
            # `sqlite3 .backup` die on open (2026-11-03/04 failures).
            owner = cfg.user;
            mode = "0750";
          });

          systemd.services.media-atlas-backup = lib.mkIf hubCfg.dbBackup.enable {
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

          systemd.timers.media-atlas-backup = lib.mkIf hubCfg.dbBackup.enable {
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
          services.restic-app-dumps.extraPaths = lib.mkIf hubCfg.dbBackup.enable [
            "/mnt/pool/backups/media-atlas"
          ];

          # Service-integration registry entry: fans out to the Caddy vHost
          # (map.home.lan, PLAIN layer — the hub's own API key is the single
          # auth gate (OQ-5); oauth2-proxy forward-auth would double-gate),
          # the Gatus checks, and the dashboard tile.
          services.integration = lib.optionalAttrs (options ? services.integration) {
            "media-atlas" = {
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
              # The upstream module gates its units on hub.enable alone; the
              # site layer (key provisioner the serve unit hard-requires,
              # PG role, site option values) hangs off media-atlas.enable —
              # keep the old coupling explicit.
              assertion = !cfg.hub.enable || cfg.enable;
              message = "services.media-atlas.hub.enable requires services.media-atlas.enable (the site layer provides the key provisioner the serve unit requires).";
            }
            {
              assertion = !hubCfg.umapNightly.enable || cfg.hub.enable;
              message = "services.media-atlas.hub.umapNightly.enable requires hub.enable (shared state dir, journal path and peer-auth user).";
            }
            {
              assertion = !hubCfg.pollEmbeddings.enable || cfg.hub.enable;
              message = "services.media-atlas.hub.pollEmbeddings.enable requires hub.enable (peer-auth media_atlas user + journal path).";
            }
            {
              assertion = !hubCfg.laneJoin.enable || cfg.hub.enable;
              message = "services.media-atlas.hub.laneJoin.enable requires hub.enable (state dir + Immich key file).";
            }
            {
              assertion = !hubCfg.dbBackup.enable || cfg.hub.enable;
              message = "services.media-atlas.hub.dbBackup.enable requires hub.enable (journal path + peer-auth user).";
            }
          ];
        }
      ];
    };
}
