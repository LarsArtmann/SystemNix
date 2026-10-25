# Runbook: docs/services/discordsync.md
# DiscordSync — SystemNix wrapper around upstream nixos-module.
#
# The upstream module (inputs.discordsync.nixosModules.default) provides every
# option (enable, package, user, group, discordTokenFile, dataDir, backend,
# databasePath, tursoUrl, tursoAuthTokenFile, backfillOnStartup, apiAddr,
# apiKeyFile, healthCheck) plus the systemd service with strong hardening and a
# SIGHUP ExecReload. This file layers ONLY the SystemNix-specific concerns on
# top: sops template wiring, DNS-gate, onFailure alert routing, GCS attachment
# backup option, OTel tracing, and a correct readiness gate (upstream's is
# malformed — see healthCheck note below).
{ inputs, ... }: {
  flake.nixosModules.discordsync =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        mkStateDir
        mkPoolDirUnit
        ports
        onFailure
        ioTier
        serviceOneshotDefaults
        ;
      cfg = config.services.discordsync;
      # discordsync vendorHash shims DROPPED twice (2026-10-12 and
      # 2026-10-15): each time the lock moved past the rev the shim was
      # measured at and upstream re-baked a hash that is GREEN through our
      # lock. The 2026-10-15 drop evidence: `nix flake update discordsync`
      # moved bf7e459 → 0089b997, the shim (measured at cac57aa,
      # UnFb4VRSMfx…) hash-mismatched in the 19:21 toplevel keep-going
      # enumeration (got 3dje+f7TFwv13yGGCesJFhfiBpjWl2RPaQF1Dou1f50=),
      # and upstream vendorHash.nix at 0089b997 bakes exactly that got hash
      # (gh api; upstream's lock nixpkgs node 55bfb4d matches our
      # discordsync/nixpkgs node, so the FOD environments are identical).
      # Re-add ONLY via nix-hash-fix evidence, never by hand (class comment:
      # lib/lars-packages.nix flakePkgShim; drop-first protocol:
      # docs/agents/nix-flakes.md).
      # RE-ADDED 2026-10-19 wave: keep-going toplevel enumeration
      # (/tmp/toplevel-build-20261019.log) mismatched the upstream-baked
      # 3dje+f7T… at the new locked rev e88c0d8; got 1O/b94qj….
      discordsyncPkg =
        inputs.discordsync.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          {
            vendorHash = "sha256-1O/b94qjAysB41hXQN2Bujd3NmIgicBqEQ4RYvoVJQo=";
          };
      sopsEnvPath = config.sops.templates."discordsync-env".path;
      # Immich lookup key pair (IMMICH_URL/IMMICH_API_KEY), rendered by the
      # discordsync-immich-key-provision converger — NOT a sops template:
      # the token is machine-minted (direct api_key table insert via
      # peer-auth postgres), so there is no secret to encrypt.
      provisionedEnvPath = "${cfg.dataDir}/immich-api-env";

      dbBackupDir = "/mnt/pool/backups/discordsync";

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      # T17 (sweep-storm plan): expose the discordsync unit's cumulative disk
      # I/O so a read/write storm is attributable in one command (the
      # 2026-09-02 integrity-sweep read storm was invisible until it had
      # saturated the SSD). Uses systemd's cgroup-level IOAccounting (enabled
      # on the unit below) via `systemctl show` — no /proc/<pid>/io ptrace
      # games, and the numbers cover EVERY process in the unit's cgroup, not
      # just MainPID. systemctl-under-harden{} is the proven system-health
      # pattern.
      discordsyncIoMetrics = pkgs.writeShellApplication {
        name = "discordsync-io-metrics";
        runtimeInputs = [
          pkgs.systemd
          pkgs.coreutils
        ];
        text = ''
          OUT="${textfileDir}/discordsync_io.prom"
          # Unique tmp per run (mktemp): a fixed .tmp name collides with
          # stale foreign-owned leftovers in the sticky 1777 textfile dir
          # (mail-relay 2026-09-02..06 outage class).
          mkdir -p "${textfileDir}"
          TMP="$(mktemp "${textfileDir}/discordsync_io.prom.XXXXXX")"
          chmod 644 "$TMP"
          trap 'rm -f "$TMP"' EXIT

          values=$(systemctl show discordsync.service -p IOReadBytes -p IOWriteBytes --value 2>/dev/null) || true
          # systemctl --value prints one property per line, in order.
          read_bytes=$(printf '%s\n' "$values" | head -n 1)
          write_bytes=$(printf '%s\n' "$values" | tail -n 1)

          # systemctl --value prints "[not set]" (or empty) when IOAccounting
          # is off or the unit has no cgroup yet — an unguarded write poisons
          # the textfile and node_exporter rejects the whole file
          # (system-health nrestarts="[not" incident, 2026-09-20).
          case "$read_bytes" in '''|*[!0-9]*) read_bytes=0 ;; esac
          case "$write_bytes" in '''|*[!0-9]*) write_bytes=0 ;; esac

          {
            echo "# HELP discordsync_unit_io_read_bytes Cumulative disk read bytes of the discordsync unit cgroup (systemd IOAccounting; resets on unit restart)"
            echo "# TYPE discordsync_unit_io_read_bytes counter"
            echo "discordsync_unit_io_read_bytes $read_bytes"
            echo "# HELP discordsync_unit_io_write_bytes Cumulative disk write bytes of the discordsync unit cgroup (systemd IOAccounting; resets on unit restart)"
            echo "# TYPE discordsync_unit_io_write_bytes counter"
            echo "discordsync_unit_io_write_bytes $write_bytes"
          } > "$TMP"
          mv "$TMP" "$OUT"
        '';
      };

      waitDnsReady = pkgs.writeShellApplication {
        name = "discordsync-wait-dns";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          echo "discordsync: waiting for DNS resolution..."
          # 150 retries × 2s = 300s budget: dnsblockd needs ~2min at boot to
          # load its blocklist mapping (2026-08-31 boot class). The unit's
          # TimeoutStartSec (6min) MUST stay above this budget —
          # gate-timeout-audit.nix enforces it at eval time.
          curl -sf --max-time 5 --retry 150 --retry-delay 2 --retry-all-errors \
            -o /dev/null "https://discord.com" \
            || { echo "discordsync: DNS/network not ready after 300s — dnsblockd may not be initialized" >&2; exit 1; }
          echo "discordsync: DNS resolution ready"
        '';
      };

      # Self-heal corrupted SQLite DB from unclean shutdown (WDT reset, OOM kill).
      # The libSQL/Go binding panics with "cell_index_read_payload_ptr called on
      # non-index page" when B-tree pages are corrupted. PRAGMA integrity_check
      # catches this before the Go binary hits it.
      #
      # Recovery cascade (preserves maximum data at every step):
      #   1. If integrity_check = ok → proceed normally
      #   2. If corrupt → run `sqlite3 .recover` which scans pages directly and
      #      rebuilds a new DB with all salvageable rows. This can recover most
      #      data even when the B-tree structure is damaged.
      #   3. If .recover fails → try BTRFS snapshot restore. Finds the newest
      #     btrbk snapshot with a healthy DB (main file + its -wal — the WAL
      #     holds every commit since the last checkpoint) and clones the pair
      #     via CoW (instant, zero additional space). Recovers the pre-crash
      #     state. REFUSED for hot-tier DBs (own BTRFS subvolume): @ snapshots
      #     do not track them — restoring would roll the live DB back to the
      #     frozen shadow (2026-10-14 01:03 lost ~29k messages this way).
      #   4. Only if ALL recovery fails → move corrupt DB aside for manual
      #      forensics and let DiscordSync start fresh (re-syncs from Turso).
      # Attachments in the separate attachments/ dir are always preserved.
      dbHeal = pkgs.writeShellApplication {
        name = "discordsync-db-heal";
        runtimeInputs = [
          pkgs.sqlite
          pkgs.btrfs-progs
        ];
        text = ''
          db="${cfg.databasePath}"
          if [ ! -f "$db" ]; then
            echo "discordsync: DB does not exist yet — first run, nothing to heal"
            exit 0
          fi
          result=$(sqlite3 "$db" "PRAGMA integrity_check;" 2>&1 || true)
          if [ "$result" = "ok" ]; then
            echo "discordsync: DB integrity check passed"
            exit 0
          fi
          # A lock is NOT corruption: a running writer (the daemon, a backup)
          # holds the write lock and integrity_check cannot even start.
          # Healing here destroyed a healthy DB on 2026-10-14 01:03 — the
          # locked DB was "recovered" (failed) and the BTRFS snapshot fallback
          # rolled it back hours. Skip; the next quiet run re-checks.
          case "$result" in
            *"database is locked"*|*"database table is locked"*)
              echo "discordsync: DB locked by a running writer — integrity check inconclusive, skipping heal" >&2
              exit 0
              ;;
          esac
          echo "discordsync: DB integrity check FAILED — attempting recovery" >&2
          echo "discordsync: integrity_check result: $result" >&2
          ts=$(date +%Y%m%dT%H%M%S)
          backup="''${db}.corrupt-$ts"
          recovered="''${db}.recovered-$ts"

          # Back up the corrupt DB for forensics before touching it. The -wal
          # holds every commit since the last checkpoint — a main-file-only
          # quarantine silently truncates at the checkpoint boundary (the
          # 2026-10-14 quarantine lost its WAL tail to the rm below).
          cp "$db" "$backup"
          if [ -f "$db-wal" ]; then
            cp "$db-wal" "$backup-wal"
          fi

          # Attempt recovery: .recover scans pages directly, bypassing the
          # damaged B-tree structure, and writes all salvageable rows to a new DB.
          if sqlite3 "$db" ".recover" | sqlite3 "$recovered" 2>/dev/null; then
            recovered_rows=$(sqlite3 "$recovered" "SELECT count(*) FROM sqlite_master;" 2>/dev/null || echo "0")
            if [ "$recovered_rows" -gt 0 ]; then
              echo "discordsync: recovery succeeded — $recovered_rows objects recovered" >&2
              # Verify the recovered DB is structurally sound
              recovered_check=$(sqlite3 "$recovered" "PRAGMA integrity_check;" 2>&1 || true)
              if [ "$recovered_check" = "ok" ]; then
                mv "$recovered" "$db"
                # The heal runs privileged (root) but the SERVICE user needs
                # write — a root-owned DB makes every write SQLITE_READONLY
                # forever (live 2026-10-14: silent since the 01:03 heal,
                # found via the 6h crash-loop it caused).
                chown ${cfg.user}:${cfg.group} "$db"
                rm -f "$db-wal" "$db-shm" 2>/dev/null || true
                echo "discordsync: recovered DB verified and replaces corrupt DB. Backup at $backup" >&2
                exit 0
              else
                echo "discordsync: recovered DB failed integrity check ($recovered_check) — falling back to fresh DB" >&2
                rm -f "$recovered" 2>/dev/null || true
              fi
            else
              echo "discordsync: .recover produced empty DB — falling back to fresh DB" >&2
              rm -f "$recovered" 2>/dev/null || true
            fi
          else
            echo "discordsync: .recover failed completely — trying BTRFS snapshot restore" >&2
            rm -f "$recovered" 2>/dev/null || true
          fi

          # BTRFS snapshot recovery: find the newest snapshot with a healthy DB.
          # btrbk snapshots are BTRFS subvolumes — `cp --reflink=always` makes
          # an instant CoW clone (zero additional disk space). This recovers the
          # pre-crash state when .recover can't salvage enough from the corrupt DB.
          # Snapshots live at /mnt/btrfs-root/.snapshots/@.YYYYMMDDTHHMM/
          db_rel="''${db#/}"
          snapshots_dir="/mnt/btrfs-root/.snapshots"
          # STRUCTURAL GUARD (2026-10-15, closes the Oct 2-14 data-loss class):
          # a DB living in its own BTRFS subvolume is hot-tier (services.hot-db,
          # doctrine C: unsnapshotted, dump-only RPO). The @ btrbk snapshots
          # belong to the ROOT subvolume and do NOT track it — the newest
          # snapshot holds the frozen pre-cutover shadow, so "restoring" it
          # over the live DB rolls the service back to the cutover moment
          # (2026-10-14 01:03 discarded ~29k messages exactly this way). The
          # runbook warning is not a control: refuse the restore outright.
          # Legitimate hot-tier recovery sources: the dump leg
          # (/mnt/pool/backups/discordsync) and the shadowed QLC store
          # (docs/services/hot-db.md hold banner).
          if btrfs subvolume show "$(dirname "$db")" >/dev/null 2>&1; then
            echo "discordsync: DB is hot-tier (own BTRFS subvolume) — @ snapshots do not track it, snapshot restore REFUSED" >&2
            echo "discordsync: hot-tier recovery sources: dump leg /mnt/pool/backups/discordsync, shadowed QLC store (docs/services/hot-db.md)" >&2
          elif [ -d "$snapshots_dir" ]; then
            for snap in $(find "$snapshots_dir" -maxdepth 1 -name '@.*' -type d 2>/dev/null | sort -r); do
              snap_db="$snap/$db_rel"
              if [ -f "$snap_db" ]; then
                echo "discordsync: trying BTRFS snapshot restore from $(basename "$snap")" >&2
                # Try CoW clone first (instant), fall back to regular copy
                if cp --reflink=always "$snap_db" "$recovered" 2>/dev/null || cp "$snap_db" "$recovered" 2>/dev/null; then
                  # The snapshot's -wal holds every commit since the main
                  # file's last checkpoint — cloning only the main DB restored
                  # a days-stale file on 2026-10-14 01:03 (data through Oct 1
                  # from an Oct 13 snapshot; the WAL beside it held the rest).
                  # Copy the pair: sqlite applies the WAL on first open, so the
                  # verify below sees the snapshot's true content.
                  if [ -f "$snap_db-wal" ]; then
                    cp --reflink=always "$snap_db-wal" "$recovered-wal" 2>/dev/null || cp "$snap_db-wal" "$recovered-wal"
                  fi
                  snap_check=$(sqlite3 "$recovered" "PRAGMA integrity_check;" 2>&1 || true)
                  if [ "$snap_check" = "ok" ]; then
                    snap_rows=$(sqlite3 "$recovered" "SELECT count(*) FROM sqlite_master;" 2>/dev/null || echo "0")
                    echo "discordsync: snapshot restore succeeded — $snap_rows objects from $(basename "$snap")" >&2
                    mv "$recovered" "$db"
                    if [ -f "$recovered-wal" ]; then
                      mv "$recovered-wal" "$db-wal"
                      chown ${cfg.user}:${cfg.group} "$db-wal"
                    fi
                    chown ${cfg.user}:${cfg.group} "$db"
                    rm -f "$db-shm" 2>/dev/null || true
                    echo "discordsync: snapshot DB verified and replaces corrupt DB. Corrupt backup at $backup" >&2
                    exit 0
                  else
                    echo "discordsync: snapshot DB also corrupt — trying older snapshot" >&2
                    rm -f "$recovered" 2>/dev/null || true
                  fi
                fi
              fi
            done
            echo "discordsync: no healthy DB found in any BTRFS snapshot" >&2
          else
            echo "discordsync: snapshots dir not found ($snapshots_dir) — skipping snapshot restore" >&2
          fi

          # Last resort: ALL recovery attempts failed. Move the corrupt DB aside
          # for manual forensics (never just delete — the backup may have data
          # salvageable by expert tools). DiscordSync starts fresh and re-syncs
          # from Turso cloud (or runs local-only if quota-exhausted).
          rm -f "$db" "$db-wal" "$db-shm" 2>/dev/null || true
          echo "discordsync: all recovery attempts exhausted. Corrupt DB preserved at $backup. Starting fresh." >&2
        '';
      };

      # Verify the Immich API key wired for the /lookup page's cross-archive
      # comparison (ADR-062). The key itself is minted by
      # discordsync-immich-key-provision (below) straight into Immich's
      # api_key table — this script is the end-to-end pager: it proves the
      # rendered env file actually authenticates against the live Immich.
      # Exit semantics:
      #   0 = key verified, env file not rendered yet (provision has not
      #       run — it owns paging for its own failures), or Immich
      #       unreachable (availability is the Gatus Immich check's job —
      #       Immich being down must not page as a DiscordSync misconfig)
      #   1 = Immich reachable but REJECTED the key (wrong secret or missing
      #       asset.read/asset.upload scope) — OnFailure alerts
      immichVerify = pkgs.writeShellApplication {
        name = "discordsync-immich-verify";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          env_file="${provisionedEnvPath}"
          url="${cfg.immich.url}"
          key=""
          [ -r "$env_file" ] && key=$(sed -n 's/^IMMICH_API_KEY=//p' "$env_file")
          if [ -z "$key" ]; then
            echo "discordsync-immich-verify: env file $env_file missing/empty — provision oneshot has not converged; check discordsync-immich-key-provision"
            exit 0
          fi
          if ! curl -sf --max-time 10 "$url/api/server/ping" -o /dev/null; then
            echo "discordsync-immich-verify: WARN Immich unreachable at $url — availability is owned by the Gatus Immich check; skipping key verification"
            exit 0
          fi
          code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H "X-Api-Key: $key" "$url/api/users/me" || echo 000)
          case "$code" in
            200)
              echo "discordsync-immich-verify: Immich API key verified against $url"
              ;;
            401|403)
              echo "discordsync-immich-verify: FAIL Immich rejected the API key (HTTP $code) — wrong secret or scope; bulk-upload-check needs asset.read + asset.upload" >&2
              exit 1
              ;;
            *)
              echo "discordsync-immich-verify: FAIL unexpected response from $url/api/users/me (HTTP $code)" >&2
              exit 1
              ;;
          esac
        '';
      };

      # Root converger for the Immich lookup key (2026-10-25 — replaces the
      # sops PLACEHOLDER paste path entirely). Immich is OIDC-only (no local
      # password an API-level provisioner could authenticate with), but its
      # Postgres runs on the same host with peer auth for the postgres OS
      # user — a privilege root ALREADY holds, so this converger grants no
      # new trust. It inserts the scoped key (asset.read + asset.upload,
      # matching the service's bulk-upload-check permission guard) directly
      # into Immich's api_key table and renders the 0400 env file the daemon
      # and the verify unit read. Convergence states:
      #   file exists + hash in DB  -> no-op (idempotent)
      #   file exists, row gone     -> re-insert from file plaintext (DB
      #                                restore/migration); file unchanged,
      #                                no restart needed
      #   file missing              -> mint token, insert, write file,
      #                                try-restart daemon + verify
      # The verify unit is restarted after every fresh mint, closing the
      # loop end-to-end (a bad mint pages within seconds, not a day).
      # Rotation: rm the env file + restart THIS unit (a UI-side deletion is
      # resurrected by the file-reinsert path BY DESIGN — the key is
      # nix-managed; rotate, don't revoke).
      immichKeyProvision = pkgs.writeShellApplication {
        name = "discordsync-immich-key-provision";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.openssl
          pkgs.util-linux
          pkgs.systemd
          config.services.postgresql.package
        ];
        text = ''
          set -euo pipefail
          keyfile="${provisionedEnvPath}"
          url="${cfg.immich.url}"
          keyname="discordsync-lookup (nix-managed)"
          db="${config.services.immich.database.name or "immich"}"
          psql() { runuser -u postgres -- ${config.services.postgresql.package}/bin/psql -d "$db" -v ON_ERROR_STOP=1 "$@"; }

          # Schema guard (loud, not silent): the INSERT below is coupled to
          # Immich's api_key shape. Verified live 2026-10-25 against 3.3.3
          # (table renamed api_keys -> api_key by StandardizeNames; key is
          # BYTEA holding the raw sha256 digest of the token).
          key_type=$(psql -At -c "SELECT data_type FROM information_schema.columns WHERE table_name = 'api_key' AND column_name = 'key'")
          if [ "$key_type" != "bytea" ]; then
            echo "discordsync-immich-key-provision: FAIL api_key.key is '$key_type', expected bytea — Immich schema drifted past this converger; resurrect the sops paste path (runbook) instead of forcing" >&2
            exit 1
          fi
          uid=$(psql -At -c "SELECT id FROM \"user\" WHERE \"isAdmin\" IS TRUE ORDER BY \"createdAt\" LIMIT 1")
          if [ -z "$uid" ]; then
            echo "discordsync-immich-key-provision: FAIL no admin user in Immich DB" >&2
            exit 1
          fi

          token=""
          if [ -r "$keyfile" ]; then
            token=$(sed -n 's/^IMMICH_API_KEY=//p' "$keyfile")
          fi

          if [ -n "$token" ]; then
            hex=$(printf '%s' "$token" | openssl dgst -sha256 -hex | awk '{print $NF}')
            cnt=$(psql -At -c "SELECT count(*) FROM api_key WHERE key = decode('$hex', 'hex')")
            if [ "$cnt" -ge 1 ]; then
              echo "discordsync-immich-key-provision: converged (env file + api_key row consistent)"
              exit 0
            fi
            echo "discordsync-immich-key-provision: env file present but row missing (DB restore?) — re-inserting from file plaintext"
            psql -c "INSERT INTO api_key (name, key, \"userId\", permissions) VALUES ('$keyname', decode('$hex', 'hex'), '$uid', ARRAY['asset.read','asset.upload']::varchar[])"
            exit 0
          fi

          token=$(openssl rand -base64 32 | tr -d '/+=')
          case "$token" in
            *[!A-Za-z0-9]*) echo "discordsync-immich-key-provision: FAIL generated token contains unexpected characters" >&2; exit 1 ;;
          esac
          hex=$(printf '%s' "$token" | openssl dgst -sha256 -hex | awk '{print $NF}')
          # Drop stale rows of THIS key name (orphaned hashes from a deleted
          # env file can never re-validate; other keys are untouched).
          for rid in $(psql -At -c "SELECT id FROM api_key WHERE name = '$keyname'"); do
            psql -c "DELETE FROM api_key WHERE id = '$rid'"
          done
          psql -c "INSERT INTO api_key (name, key, \"userId\", permissions) VALUES ('$keyname', decode('$hex', 'hex'), '$uid', ARRAY['asset.read','asset.upload']::varchar[])"
          mkdir -p "$(dirname "$keyfile")"
          tmp=$(mktemp "$(dirname "$keyfile")/.immich-api-env.XXXXXX")
          printf 'IMMICH_URL=%s\nIMMICH_API_KEY=%s\n' "$url" "$token" > "$tmp"
          chown ${cfg.user}:${cfg.group} "$tmp"
          chmod 0400 "$tmp"
          mv -f "$tmp" "$keyfile"
          echo "discordsync-immich-key-provision: minted new Immich API key + rendered $keyfile — restarting consumer units"
          systemctl try-restart discordsync.service discordsync-immich-verify.service
        '';
      };
    in
    {
      imports = [ inputs.discordsync.nixosModules.default ];

      options.services.discordsync = {
        # Opt-in GCS attachment backup. Upstream has no equivalent option; the
        # binary reads GCS_BUCKET + GOOGLE_APPLICATION_CREDENTIALS env vars.
        gcsBucket = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "GCS bucket name for cloud attachment backup (requires discordsync_gcs_credentials sops secret)";
        };

        # Attachments (BLOBs) directory. null keeps the legacy in-state layout
        # (${dataDir}/attachments, tmpfiles-created). Set it to a pool path to
        # move the ~40 GB attachment archive off the NVMe (2026-09-22
        # re-scope of the Own-tools NVMe→pool leg: the DB stays put — the
        # Phase-2 hot-db wave owns it — only BLOBs belong on the HDD pool).
        # Setting it wires the mount-gated leaf creator, the service's
        # RequiresMountsFor/ReadWritePaths gating, and the one-time migrate
        # oneshot (rsync → verify → rm source, activitywatch-data-to-pool
        # pattern). A detached DAS then fails the service as a clean
        # dependency (bank-sync pool-native precedent); pool-recovery
        # converges it after remount.
        attachmentsDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Pool directory for the attachment archive (null = legacy in-state <dataDir>/attachments layout)";
        };

        # Deliberate data-loss override (upstream incident 2026-10-12):
        # quarantine + re-replicate-from-remote discards the local replica
        # file, so a STALE remote (quota-frozen pushes) silently rolls local
        # data back. Upstream `refuseRemoteRebaseline` refuses unless this
        # opt-in env is set and falls back to plain-SQLite local-only mode
        # instead. Only enable after VERIFYING the remote is current.
        allowRemoteRebaseline = lib.mkEnableOption ''
          remote re-baselining: letting DiscordSync quarantine the local Turso
          replica and re-replicate it from the remote on corruption-classified
          open failures. This DISCARDS local data — only enable after verifying
          the remote is current (2026-10-12: a quota-frozen remote rolled the
          read model back five weeks). Default (false) keeps the local file and
          serves it in local-only mode; recovery runbook:
          docs/runbook/stale-remote-rebaseline.md in the DiscordSync repo.
        '';

        # Nightly online sqlite .backup of the event store onto the HDD pool
        # — the dump-only RPO leg for the hot-db tier migration (2026-09-30):
        # once the DB leaves the btrbk `@` snapshot set its only other
        # redundancy is the Turso cloud sync, which is free-plan BLOCKED
        # (local-first stance). Default off: pool-less hosts/VMs register no
        # units and no phantom backup-coordination row.
        dbBackup.enable = lib.mkEnableOption "nightly gzipped sqlite .backup of the DiscordSync event store onto /mnt/pool/backups/discordsync (dump-only RPO leg for the hot-db wave)";

        immich = {
          enable = lib.mkEnableOption "Immich cross-archive comparison on the /lookup page (ADR-062: the server proxies hex SHA-1 hashes to Immich's bulk-upload-check; IMMICH_URL + IMMICH_API_KEY are cold config validated both-or-neither by the binary at startup)";
          url = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1:${toString ports.immich}";
            defaultText = "http://127.0.0.1:<ports.immich>";
            description = ''
              Base URL of the Immich server the /lookup page compares against.
              Loopback by default: the two services are co-located, so skipping
              Caddy/DNS/TLS removes two boot-order dependencies from the
              lookup path (the API key never leaves the server either way).
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        services.discordsync = {
          package = lib.mkDefault discordsyncPkg;
          # Served by the plain engine (2026-10-14, operator decision): the
          # remote is quota-frozen (since Sep-04) and the live DB is restored
          # from the Oct-1 plain dump (docs/runbook/stale-remote-rebaseline.md
          # in DiscordSync). The turso-sync engine opening a PLAIN file does
          # NOT fall back on the 403 quota pull — it logs "initial turso pull
          # failed, continuing with local data" and keeps the sync engine,
          # which then fails migrations because the sync build has no FTS5
          # ("no such module: fts5"; the create-indexes step died on the
          # restored schema — observed 2026-10-14 19:49). The quota-fallback
          # assumption documented below was wrong for the restored-file case.
          # The sqlite backend is the deterministic serving path while the
          # remote stays frozen; revisit only with the Turso endgame decision
          # (upgrade plan vs deprovision) AND a fresh sync-engine-formatted
          # replica.
          # (Historical, superseded: turso-sync was kept because the quota
          # fallback was believed to serve local data on 403, and a bare
          # sqlite backend had caused a 40+ min startup backfill — FTS5
          # trigger contention with projection workers on a single
          # connection. The backfill contention is now handled by disabling
          # backfillOnStartup during the restore window, see below.)
          backend = lib.mkDefault "sqlite";
          # ON for the post-salvage convergence sweep (2026-10-15): the salvage
          # replay is done, the Oct 2-14 read-model gap is still open (zero
          # messages Oct 2-13 live-verified via /partials/activity-data), and
          # all backfill progress rows were reset via POST /api/backfill/restart
          # (44/44, 2026-10-15 ~21:20) so the next gateway GUILD_AVAILABLE
          # re-walks every channel from scratch (idempotent, covers everything
          # Discord still serves). The old contention rationale is gone: the
          # quadratic startup FTS sync was fixed upstream (rowid watermark,
          # deployed 2026-10-15 20:10 — startup now ~7s, sync_fts 3.6s) and the
          # sweep is rate-limited (5 req/s). Flip back to false after the sweep
          # converges if the per-connect full-skip walk ever shows up as noise.
          backfillOnStartup = lib.mkDefault true;
          apiAddr = lib.mkDefault "127.0.0.1:${toString ports.discordsync-api}";
          # Upstream's ExecStartPost curls http://localhost:${cfg.apiAddr}/readyz
          # which expands to http://localhost:127.0.0.1:8085/readyz — a malformed
          # URL (three colon-separated authority parts). Disabled here; a correct
          # readiness gate is wired in serviceConfig.ExecStartPost below.
          # TODO: drop this override once upstream fixes the URL template.
          healthCheck = lib.mkDefault false;
          # Both token paths point to the single sops template (contains
          # DISCORD_TOKEN, TURSO_URL, TURSO_AUTH_TOKEN). The duplicate entry in
          # upstream's EnvironmentFile list is harmless (systemd re-parses).
          discordTokenFile = lib.mkDefault sopsEnvPath;
          tursoAuthTokenFile = lib.mkDefault sopsEnvPath;
        };

        # T17 io-metrics collector (script defined in the let block): a 30s
        # oneshot timer writing discordsync_io.prom into the shared textfile
        # dir. harden{} + CAP_FOWNER (sticky-dir rename class). The sticky
        # dir's tmpfiles rule is merged into the existing rules list below.
        systemd.services.discordsync-io-metrics = {
          description = "DiscordSync unit disk-I/O textfile collector for node_exporter";
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "64M";
              # Sticky-dir rename over a foreign-owned prom (mail-relay class).
              CapabilityBoundingSet = "CAP_FOWNER";
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              ExecStart = lib.getExe discordsyncIoMetrics;
              ReadWritePaths = [ textfileDir ];
            }
          ];
        };

        systemd.timers.discordsync-io-metrics = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "45s";
            OnUnitActiveSec = "30s";
          };
        };

        systemd.services.discordsync-db-heal = {
          description = "DiscordSync SQLite DB integrity check and recovery";
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            (harden {
              MemoryMax = "256M";
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "+${lib.getExe dbHeal}";
              # The ~11 GB integrity check is IO-bound: under deploy/boot
              # churn it read 9.4G across its whole 10-min budget and was
              # SIGTERM'd mid-check (2026-09-20 11:41 activation, exit-4
              # contributor; the 04:17 boot hit the same class). 20min
              # absorbs churn; idle runs stay in the 2-5 min range.
              TimeoutStartSec = "20min";
            }
            ioTier.background
          ];
        };

        systemd.services.discordsync-immich-verify = lib.mkIf cfg.immich.enable {
          description = "DiscordSync Immich API key verification (lookup cross-archive comparison)";
          # Not ordered after immich.service: an unreachable Immich is a WARN
          # skip inside the script, not a dependency (availability belongs to
          # Gatus; the daily timer re-runs this regardless of boot order).
          after = [ "sops-nix.service" ];
          wants = [ "sops-nix.service" ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          serviceConfig = lib.mkMerge [
            (harden { MemoryMax = "128M"; })
            (serviceOneshotDefaults { })
            {
              Type = "oneshot";
              # Runs as the service user so it can read the 0400
              # discordsync:discordsync sops template.
              User = cfg.user;
              Group = cfg.group;
              ExecStart = lib.getExe immichVerify;
              TimeoutStartSec = "2min";
            }
            ioTier.background
          ];
        };

        systemd.timers.discordsync-immich-verify = lib.mkIf cfg.immich.enable {
          description = "Daily DiscordSync Immich API key verification";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            # Off 00:00 sharp: the daily nix-gc window starts there and the
            # verify's curl probes should not race the GC store walk
            # (bank-sync daily-timer precedent).
            RandomizedDelaySec = "1h";
          };
        };

        systemd.services.discordsync-immich-key-provision = lib.mkIf cfg.immich.enable {
          description = "DiscordSync Immich lookup key provisioner (root; direct api_key table insert via peer-auth postgres)";
          after = [ "postgresql.service" ];
          wants = [ "postgresql.service" ];
          # multi-user-wanted (crowdsec-setup pattern): the deploy.sh
          # provisioner loop's is-enabled gate admits it, so every deploy
          # re-converges the key. Boot-time run covers DB-restore healing.
          wantedBy = [ "multi-user.target" ];
          inherit onFailure;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = lib.getExe immichKeyProvision;
            TimeoutStartSec = "2min";
            # Root BY DESIGN: peer-auth postgres via runuser (no secret exists
            # to authenticate with), discordsync-owned env file write, and a
            # try-restart of the consumer units. NoNewPrivileges stays OFF —
            # runuser is setuid and the script legitimately needs it.
            NoNewPrivileges = false;
            ProtectSystem = "strict";
            ReadWritePaths = [ cfg.dataDir ];
            PrivateTmp = true;
          };
        };

        systemd.timers.discordsync-immich-key-provision = lib.mkIf cfg.immich.enable {
          description = "Daily DiscordSync Immich key convergence (DB-restore self-heal)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            # Anywhere in the 00:00-06:00 window: must precede nothing; the
            # verify unit (00:00 + 1h jitter) may run before or after it —
            # a 401 from a DB-restored key self-heals at THIS unit's next
            # run and pages via the verify's FAIL in between.
            RandomizedDelaySec = "6h";
          };
        };

        # Daemon-less verification: no HTTP endpoint, so monitoring is
        # OnFailure (Discord) + the system-health state metrics
        # (github-auto-assign pattern). The options?-guard mirrors the
        # integration-registry convention for hosts that enable this module
        # without system-health. One COMBINED definition: the restore
        # drill (dbBackup.enable, below) must never become a second
        # same-attrset definition of this option (that is a raw
        # attribute-already-defined eval error, caught by nix fmt
        # 2026-10-13, not a module-system merge).
        services.system-health.extraMonitoredServices = lib.mkIf (options ? services.system-health) (
          lib.mkAfter (
            lib.optionals cfg.immich.enable [ "discordsync-immich-verify" ]
            ++ lib.optionals cfg.dbBackup.enable [ "discordsync-db-restore-drill" ]
          )
        );

        systemd.services.discordsync = {
          # SystemNix DNS-gate: dnsblockd must resolve before Discord connect.
          # DB-heal oneshot runs independently (not blocking deploy activation).
          # immich-key-provision: the daemon's second EnvironmentFile is
          # rendered by that oneshot — a missing file FAILS the unit at
          # start, so the order is load-bearing (immich shape only).
          after = [
            "sops-nix.service"
            "dnsblockd.service"
            "discordsync-db-heal.service"
          ]
          ++ lib.optionals (cfg.attachmentsDir != null) [
            "discordsync-attachments-dir.service"
          ]
          ++ lib.optionals cfg.immich.enable [
            "discordsync-immich-key-provision.service"
          ];
          wants = [
            "sops-nix.service"
            "dnsblockd.service"
            "discordsync-db-heal.service"
          ]
          ++ lib.optionals (cfg.attachmentsDir != null) [
            "discordsync-attachments-dir.service"
          ]
          ++ lib.optionals cfg.immich.enable [
            "discordsync-immich-key-provision.service"
          ];
          inherit onFailure;
          startLimitBurst = lib.mkForce 10; # SystemNix uses 10 (upstream is 5)

          environment = {
            # Pool-native attachment archive when attachmentsDir is set
            # (2026-09-22 BLOB re-scope); legacy in-state subdir otherwise
            # (upstream uses dataDir root).
            ATTACHMENT_STORAGE_PATH = lib.mkForce (
              if cfg.attachmentsDir != null then cfg.attachmentsDir else "${cfg.dataDir}/attachments"
            );
            # OTel traces → local SigNoz OTLP/HTTP collector. The binary
            # installs a noop tracer when this is unset. otlptracehttp.WithEndpoint
            # expects host:port WITHOUT scheme — the SDK constructs the full URL
            # internally (http://<endpoint>/v1/traces). WithInsecure() = plain HTTP.
            OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}";
            # 2026-09-02 incident: the startup integrity sweep re-read and
            # re-hashed the whole ~40 GB archive on every boot, saturating the
            # SSD at 100% IO and starving SQLite (zombie gateway, 40s healthz,
            # SIGKILL on shutdown). Re-enabled 2026-09-04 after upstream T1
            # (byte-rate pacing) + T2 (resumable oldest-first sweep) shipped:
            # reads are paced at 100 MB/s and ionice'd, and an interrupted
            # pass resumes from the oldest-unverified frontier on the next
            # pass — a 30-min timeout abort is now bounded I/O with retained
            # progress, and the SweepInterrupted alert makes it observable.
            INTEGRITY_CHECK_ON_STARTUP = "true";
            INTEGRITY_CHECK_INTERVAL = "12h";
            # Byte-rate pacing cap for integrity sweeps (upstream T1,
            # 2026-09-04). Bounds worst-case sweep read throughput so a cold
            # cache can never storm the shared SSD again. 100 MB/s ≈ the
            # upstream default, kept explicit here so the operator-visible env
            # map documents the intent; ~18% of a SATA SSD's sequential
            # bandwidth and further cushioned by ioTier.background (ionice).
            INTEGRITY_SWEEP_MAX_MBPS = "100";
            # Remote re-baseline data-loss gate (upstream incident 2026-10-12).
            # Kept explicit (always present) so the operator-visible env map
            # documents the policy; flipping it requires a config change, which
            # is the point. See the allowRemoteRebaseline option above.
            TURSO_SYNC_ALLOW_REMOTE_REBASELINE = lib.boolToString cfg.allowRemoteRebaseline;
          }
          // lib.optionalAttrs (cfg.gcsBucket != null) {
            GCS_BUCKET = cfg.gcsBucket;
            GOOGLE_APPLICATION_CREDENTIALS = config.sops.secrets.discordsync_gcs_credentials.path;
          };

          serviceConfig = lib.mkMerge [
            {
              # mkForce replaces the upstream ExecStartPre entirely.
              # Upstream's chattr ExecStartPre was repaired 2026-08-05
              # (0e72e7b1: writeShellApplication wrapper + "+" privileged prefix),
              # so the drop below is NO LONGER about the chattr bug — the
              # remaining reason is replacing upstream's ExecStartPre chain with
              # the DNS-gate only (db-heal lives in discordsync-db-heal.service;
              # NOCOW is nice-to-have for SQLite, WAL mode already bounds the
              # write-amplification damage).
              #
              # DB heal extracted to discordsync-db-heal.service oneshot (see above).
              # Only DNS wait remains in ExecStartPre — fast (~2-10s).
              ExecStartPre = lib.mkForce [
                "+${lib.getExe waitDnsReady}"
              ];
              TimeoutStartSec = "6min";
              # Stop drains (event loop + SQLite flush) exceed the 90s
              # default under IO pressure — 4 stop-timeout SIGKILLs on
              # 2026-09-20 alone (02:24, 03:34, 03:51, 11:31); the SIGKILL
              # marks the unit failed and exit-4s any activation that
              # restarts it. 5min absorbs the drain without wedging
              # activation.
              TimeoutStopSec = "5min";
              # T17: cgroup-level disk I/O accounting for the io-metrics
              # textfile collector (negligible BPF cost).
              IOAccounting = true;
            }
            (harden {
              # Backfill bursts + turso-sync need more than upstream's 512M.
              MemoryMax = lib.mkForce "2G";
              # CPUQuota decision (2026-09-24, plan T20 remnant): 200%, not
              # 100%. The integrity-sweep hasher is single-threaded, but the
              # Go GC runs concurrent background workers and the download
              # pipeline is goroutine-parallel; 100% would throttle GC +
              # worker onto one core and reproduce the zombie-gateway shape
              # (missed heartbeats) under backfill load. 200% covers GC
              # concurrency plus one busy worker while still capping a
              # runaway hot loop (decode spin, retry storm) at 2 of 32 cores,
              # leaving the rest of the host untouched. mkForce REQUIRED:
              # upstream nixos-module.nix declares CPUQuota = "100%" at plain
              # priority, which beats harden{}'s mkDefault (eval-proven
              # 2026-09-25: rendered 100% until forced; same class as
              # MemoryMax above).
              CPUQuota = lib.mkForce "200%";
            })
            # Upstream declares ReadWritePaths = [ dataDir ] at plain
            # priority, which beats harden{}'s mkDefault — the pool leaf is
            # added via mkForce (dataDir kept; nothing else defines the list).
            {
              ReadWritePaths = lib.mkForce (
                [ cfg.dataDir ] ++ lib.optionals (cfg.attachmentsDir != null) [ cfg.attachmentsDir ]
              );
            }
            ioTier.background
            {
              Environment = [ "GOMEMLIMIT=1536MiB" ];
            }
            (lib.mkIf cfg.immich.enable {
              # Second EnvironmentFile: the provisioned Immich key pair
              # (IMMICH_URL/IMMICH_API_KEY). Merging into the upstream list
              # CONCATENATES (list option) — systemd applies files in order
              # and later files override earlier keys; the key sets are
              # disjoint, so ordering carries no semantics. Ordered after the
              # provision unit (after/wants above) because a missing
              # EnvironmentFile fails the unit at start.
              EnvironmentFile = [ provisionedEnvPath ];
            })
          ];

          # The attachment archive is pool-native when attachmentsDir is set:
          # a detached DAS must fail the service as a clean dependency, never
          # let attachment writes land in a root-fs shadow dir under the
          # mountpoint (226/mount-gating doctrine). The audit's
          # RequiresMountsFor gate is satisfied by the exact-path form.
          unitConfig = lib.optionalAttrs (cfg.attachmentsDir != null) {
            RequiresMountsFor = [ cfg.attachmentsDir ];
          };
        };

        # Pool attachment archive wiring (attachmentsDir != null only).
        # Single-phase chown (mkPoolDirUnit default) reaches the same final
        # state as the old root-flip two-phase: user:group + 0770, with
        # CAP_CHOWN/FOWNER/DAC_OVERRIDE in the bounding set the whole way.
        systemd.services.discordsync-attachments-dir =
          lib.mkIf (cfg.attachmentsDir != null)
            (mkPoolDirUnit {
              description = "Create DiscordSync attachment directory on the HDD pool";
              directory = cfg.attachmentsDir;
              owner = cfg.user;
              group = cfg.group;
              mode = "0770";
            });

        # One-time move of the in-state attachment archive onto the pool
        # (activitywatch-data-to-pool pattern): runs only while the legacy
        # dir still exists, stops the service for a consistent copy, rsyncs,
        # checksum-verifies, then removes the source (rm, not trash — ~40 GB
        # would write back onto the NVMe this migration frees; the pool copy
        # is checksum-verified + btrbk-pool snapshotted). Static unit, started
        # by deploy.sh's dedicated no-block block (the copy must not block the
        # switch flow on the shared USB HDD link); ConditionPathIsDirectory
        # makes every later boot/deploy a clean instant skip.
        systemd.services.discordsync-attachments-migrate = lib.mkIf (cfg.attachmentsDir != null) {
          description = "One-time migration: discordsync attachments → HDD pool";
          unitConfig = {
            ConditionPathIsDirectory = "${cfg.dataDir}/attachments";
            RequiresMountsFor = [ "/mnt/pool" ];
          };
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          path = [
            pkgs.rsync
            pkgs.coreutils
            pkgs.systemd
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              # ~40 GB copy + full checksum verify on the shared USB HDD link
              # under contention; generously above the real cost.
              TimeoutStartSec = "6h";
            }
            (harden {
              MemoryMax = "512M";
              ReadWritePaths = [
                cfg.dataDir
                "/mnt/pool"
              ];
              # DAC_READ_SEARCH: the state dir is 0700 discordsync:discordsync
              # — root cannot even stat through it without it (cv-backup
              # silent-no-op precedent). CHOWN/FOWNER/DAC_OVERRIDE: rsync -aHAX
              # ownership preservation + the final rm -rf of foreign-owned
              # files. FSETID: rsync -a preserves the source dirs' setgid
              # bits on discordsync-group dirs — setting sgid on a group
              # outside the sandbox's groups EPERMs without it (the
              # 2026-09-22 chmod-2770 class, caught live on the first
              # migration run).
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE CAP_DAC_READ_SEARCH CAP_FSETID";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
          script = ''
            set -u
            src="${cfg.dataDir}/attachments"
            dest="${cfg.attachmentsDir}"
            failures=0

            # Quiesce the writer: a live rsync of files under capture is not a
            # consistent copy. Stop is a no-op when the service is down; if
            # the stop itself fails, refuse to move (house pattern).
            if ! systemctl stop discordsync.service; then
              echo "discordsync-attachments-migrate: STOP FAILED — cannot take a consistent copy (source kept)"
              exit 1
            fi

            echo "discordsync-attachments-migrate: copying $src → $dest"
            mkdir -p "$dest"
            chown root:root "$dest"
            chmod 0770 "$dest"
            chown ${cfg.user}:${cfg.group} "$dest"
            # --no-perms (BOTH passes) + perm-error tolerance: rsync
            # mode-preservation EPERMs on foreign-group dirs even with
            # CAP_FSETID in the bounding set (sandbox setattr semantics,
            # 2026-09-22, mechanism unresolved — chown works; owner rwx via
            # umask-default modes is all the service needs). rsync still
            # attempts a handful of dir-mode sets ("." + a few shards) —
            # those lines are tolerated when they are the ONLY errors; any
            # other stderr line fails the copy.
            copy_err=$(mktemp)
            copy_rc=0
            rsync -aHAX --no-perms --info=stats1 "$src"/ "$dest"/ 2>"$copy_err" || copy_rc=$?
            if [ "$copy_rc" -ne 0 ] && grep -qv "failed to set permissions" "$copy_err"; then
              echo "discordsync-attachments-migrate: COPY FAILED (source kept) — stderr:"
              head -20 "$copy_err"
              failures=1
            elif [ "$copy_rc" -ne 0 ]; then
              echo "discordsync-attachments-migrate: WARN rsync exit $copy_rc with only mode-set errors (sandbox setattr limit) — tolerated, content synced"
            fi
            rm -f "$copy_err"
            if [ "$failures" -eq 0 ]; then
              diff=""
              # Content-only verify: itemized lines starting with '>' or 'c'
              # (transfer/checksum). Mode-only lines (".dp…") are the same
              # tolerated setattr class and MUST NOT fail the gate.
              diff=$(rsync -aHAXn --no-perms -c -i "$src"/ "$dest"/ 2>/dev/null | grep -E '^[><ch]' || true)
              if [ -n "$diff" ]; then
                echo "discordsync-attachments-migrate: VERIFY FAILED — differences remain (source kept):"
                printf '%s\n' "$diff" | head -20
                failures=1
              elif ! rm -rf -- "$src"; then
                echo "discordsync-attachments-migrate: SOURCE REMOVAL FAILED (data is safe on the pool)"
                failures=1
              else
                echo "discordsync-attachments-migrate: verified identical, source removed — service reads ${cfg.attachmentsDir}"
              fi
            fi

            if ! systemctl start discordsync.service; then
              echo "discordsync-attachments-migrate: RESTART FAILED — start discordsync.service manually"
              failures=1
            fi

            if [ "$failures" -ne 0 ]; then
              echo "discordsync-attachments-migrate: FAILED — migration incomplete; source kept where verified"
              exit 1
            fi
            echo "discordsync-attachments-migrate: complete"
          '';
        };

        # Pre-create the in-state attachments subdir with correct ownership
        # (legacy layout only — the pool leaf has its own mount-gated creator;
        # a tmpfiles rule under /mnt/pool would land on the root fs during a
        # DAS outage and shadow the pool copy).
        systemd.tmpfiles.rules = [
          (mkStateDir cfg.dataDir "2770" cfg.user cfg.group)
          # T17: the shared node_exporter textfile dir (sticky 1777; also
          # declared by gpu-active — mkStateDir is idempotent).
          (mkStateDir textfileDir "1777" "nobody" "nogroup")
        ]
        ++ lib.optionals (cfg.attachmentsDir == null) [
          (mkStateDir "${cfg.dataDir}/attachments" "2770" cfg.user cfg.group)
        ];

        # ── Event-store dump leg (dbBackup.enable) ─────────────────────
        # browser-history-backup pattern: mount-gated pool leaf creator +
        # online sqlite .backup. The raw intermediate is gzip -1'd in place
        # (message text compresses ~3x; the restic repo dedups further).
        systemd.services.discordsync-db-backup-dir = lib.mkIf cfg.dbBackup.enable (mkPoolDirUnit {
          description = "Create DiscordSync DB backup directory on the HDD pool";
          directory = dbBackupDir;
        });

        systemd.services.discordsync-db-backup = lib.mkIf cfg.dbBackup.enable {
          description = "DiscordSync event-store backup (online sqlite .backup, gzipped)";
          after = [
            "discordsync.service"
            "discordsync-db-backup-dir.service"
          ];
          wants = [
            "discordsync.service"
            "discordsync-db-backup-dir.service"
          ];
          # Detached DAS fails the run as a clean dependency error, never
          # 226/NAMESPACE (btrbk doctrine).
          unitConfig.RequiresMountsFor = [ dbBackupDir ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # 11 GB event store: .backup read + gzip write ≈ minutes on the
              # pool HDDs; the quiet-gate below can legitimately wait out the
              # tail of the nightly GCS reconcile pass, so bounded well above
              # the global 3min default.
              TimeoutStartSec = "60min";
              ExecStart = pkgs.writeShellScript "discordsync-db-backup" ''
                set -euo pipefail
                db="${cfg.databasePath}"
                if [ ! -f "$db" ]; then
                  echo "discordsync-db-backup: no DB at $db — nothing to back up"
                  exit 0
                fi
                stamp=$(date +%Y-%m-%d)
                raw="${dbBackupDir}/.discordsync-db-$stamp.raw"
                dst="${dbBackupDir}/discordsync-db-$stamp.sql.gz"
                # Idempotency for the catch-up windows (timer OnCalendar
                # list): once today's dump exists, later windows are no-ops.
                if [ -s "$dst" ]; then
                  echo "discordsync-db-backup: $dst already exists — nothing to do"
                  exit 0
                fi
                # Clean stale intermediates up front: the retention sweep at
                # the bottom only runs on success, so a failure streak would
                # otherwise litter the dir (2026-10-02..11 0-byte .raw
                # corpses). .part can also outlive a mid-run failure.
                find ${dbBackupDir} \( -name ".discordsync-db-*" -o -name "*.part" \) -mtime +2 -delete
                # -readonly: a read-write root open of the live WAL database
                # can create/replace the -shm/-wal sidecars ROOT-owned while
                # the server (own user) holds it, poisoning the next open
                # with SQLITE_READONLY (the browser-history 2026-09-22
                # uid-drift class).
                # The nightly GCS-URL reconcile pass (02:00 sharp start,
                # 77+ min span observed 2026-10-12, DB writes ~12/sec) holds
                # locks against a readonly open for its WHOLE span — the old
                # 02:30 timer sat dead-center (9 instant failures
                # 2026-10-03..11; the deployed timeout+retry still lost after
                # 90 s on 2026-10-12). The timer now runs 03:45 AND this gate
                # waits out any pass tail before the first open: pass over =
                # 3 min of reconcile journal silence (bounded, runs anyway at
                # the cap).
                waits=0
                until ! journalctl -u discordsync.service --since "-3 min" -g "refreshing GCS signed URLs" -q; do
                  waits=$((waits + 1))
                  if [ "$waits" -ge 25 ]; then
                    echo "discordsync-db-backup: GCS reconcile still active after 25 min — running anyway" >&2
                    break
                  fi
                  sleep 60
                done
                # The CLI defaults to busy_timeout=0: one transient lock from
                # the server's near-continuous write churn (GCS-URL refresh
                # loop, turso-sync backoff retries) failed 9 consecutive
                # 02:30 runs instantly (2026-10-03..11, 0-byte .raw litter).
                # .timeout rides through short txns (the server's own
                # connections use busy_timeout=15s for the same churn);
                # the retry loop covers pathological seconds.
                attempt=0
                until err=$(${lib.getExe pkgs.sqlite} -readonly -cmd ".timeout 30000" "$db" ".backup '$raw'" 2>&1); do
                  attempt=$((attempt + 1))
                  if [ "$attempt" -ge 3 ]; then
                    echo "discordsync-db-backup: .backup failed after 3 attempts: $err" >&2
                    rm -f "$raw"
                    exit 1
                  fi
                  echo "discordsync-db-backup: .backup attempt $attempt failed, retrying: $err" >&2
                  sleep 15
                done
                # Gate BEFORE anything becomes visible at the archive path:
                # a torn .backup must never be archivable, and the raw file is
                # the exact content about to be gzipped. quick_check reads the
                # ~380 MB raw once — noise next to the dump read itself.
                check=$(${lib.getExe pkgs.sqlite} -readonly "$raw" "PRAGMA quick_check;" 2>&1) || true
                if [ "$check" != "ok" ]; then
                  echo "discordsync-db-backup: quick_check failed on raw dump: $check" >&2
                  rm -f "$raw"
                  exit 1
                fi
                ${lib.getExe pkgs.gzip} -1 -c "$raw" > "$dst.part"
                mv "$dst.part" "$dst"
                rm -f "$raw"
                # 7-day retention + failed-run intermediates older than 2d.
                find ${dbBackupDir} -name "discordsync-db-*.sql.gz" -mtime +7 -delete
                find ${dbBackupDir} -name ".discordsync-db-*" -mtime +2 -delete
                echo "discordsync-db-backup: wrote $dst ($(du -h "$dst" | cut -f1))"
              '';
              ReadWritePaths = [ dbBackupDir ];
            }
            # The dataDir is 2770 discordsync:discordsync — DAC-obeying root
            # cannot traverse it without CAP_DAC_READ_SEARCH (cv-backup
            # silent-no-op precedent).
            (harden {
              MemoryMax = "2G";
              CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.discordsync-db-backup = lib.mkIf cfg.dbBackup.enable {
          description = "Nightly DiscordSync event-store backup";
          wantedBy = [ "timers.target" ];
          after = [ "mnt-pool.mount" ];
          timerConfig = {
            # 03:45 primary — moved out of the 02:30 slot that collided with
            # the GCS-URL reconcile pass for 10 nights (2026-10-03..12).
            # Stagger: paperless-db 02:00, browser-history 02:15, miniflux
            # 02:45, this 03:45. 2026-10-13 update: the first 03:45 run STILL
            # lost the lock race WITH the reconcile quiet-gate passing on
            # 3-min silence — a different, silent writer held it (the
            # post-shadow-split re-backfill after the 2026-10-12 21:52
            # restart is the prime suspect). Persistent re-fires MISSED
            # activations, never FAILED runs, so catch-up windows are the
            # same-day retry; the script's already-today guard makes a
            # catch-up after a successful primary a no-op.
            OnCalendar = [
              "*-*-* 03:45:00"
              "*-*-* 05:15:00"
              "*-*-* 06:45:00"
            ];
            Persistent = true;
          };
        };

        # Weekly restore drill for the dump leg above (2026-10-13): a
        # backup that was never restored is a rumor, and the 2026-10-13
        # manual drill of the 10-01 dump was the FIRST restore this leg
        # ever had (12+ days into its life). Restores the newest dump
        # into tmpfs scratch and proves integrity_check + read-model
        # counts + message freshness; any failure exits 1 so the unit
        # FAILS and OnFailure pages (forgejo-restore-drill pattern: a
        # drill is an event, not a continuous signal, so deliberately
        # no metric/gatus layer). Fixture-tested:
        # checks.x86_64-linux.discordsync-restore-drill-fixture.
        systemd.services.discordsync-db-restore-drill = lib.mkIf cfg.dbBackup.enable {
          description = "Weekly DiscordSync restore drill (newest dump: integrity + counts + freshness)";
          # Ordering the backup unit in means a Sunday-morning drill can
          # never race a still-running dump; the backup's already-today
          # guard makes that start an instant no-op when the leg is
          # healthy, and one extra dump ATTEMPT when it is not (drill
          # then honestly fails freshness on the stale dump: the page IS
          # the signal that the leg is still broken).
          after = [ "discordsync-db-backup.service" ];
          wants = [ "discordsync-db-backup.service" ];
          unitConfig.RequiresMountsFor = [ dbBackupDir ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          path = [
            pkgs.coreutils
            pkgs.gzip
            pkgs.sqlite
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              # Gunzip + thorough integrity_check of the ~380 MB DB under
              # IO churn; idle runs land near 1 min.
              TimeoutStartSec = "15min";
              ExecStart = "${pkgs.bash}/bin/bash ${../../../scripts/discordsync-restore-drill.sh}";
              # Dumps are 0644 root:root in the 0755 backup dir: the
              # service user reads them without any capability grant,
              # and the scratch lives in the unit's PrivateTmp.
              User = cfg.user;
              Group = cfg.group;
            }
            (harden { MemoryMax = "1G"; })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.discordsync-db-restore-drill = lib.mkIf cfg.dbBackup.enable {
          description = "Weekly DiscordSync restore drill";
          wantedBy = [ "timers.target" ];
          after = [ "mnt-pool.mount" ];
          timerConfig = {
            # Sunday 08:00: after the 03:45 dump AND both same-day
            # catch-up windows (05:15/06:45), so a repaired leg's fresh
            # dump is what gets drilled.
            OnCalendar = "Sun *-*-* 08:00:00";
            Persistent = true;
          };
        };

        # Service-integration registry entry: fans out to the Caddy vHost
        # (Layer 2), the three Gatus checks (liveness + DLQ + Turso sync),
        # and the homepage tile. Replaces rows in caddy.nix /
        # gatus-config.nix / homepage.nix.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          discordsync = {
            inherit (cfg) enable;
            subdomain = "discordsync";
            port = ports.discordsync-api;
            vHost.layer = "protected";
            checks = [
              {
                # Use /healthz for liveness: it returns 200 once the API server is
                # bound (after the long thumb-hash backfill), and fails hard
                # (connection refused) when the process is down. /readyz returns 503
                # during startup which made the previous < 400 condition miss
                # connection failures (status 0).
                name = "DiscordSync";
                group = "Infrastructure";
                url = "http://localhost:${toString ports.discordsync-api}/healthz";
                interval = "60s";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 500"
                ];
                alert = "DiscordSync backup bot down — Discord messages not being captured";
              }
              # M07 alert mirrors (DiscordSync plan F40): an independent
              # second layer on top of the Prometheus rules in DiscordSync's
              # monitoring/alerts.yml. /metrics is auth-exempt on localhost.
              # gatus body patterns can only express "== 0" (prefix match on
              # the value line), so each check pins a sticky zero-state.
              # Deliberately NOT mirrored: DB-growth (500 MB/day rate) and
              # sync-failure COUNT (>5) alerts; a gatus absolute-byte ceiling
              # or a zero-failure check would false-fire on transients.
              # Those stay Prometheus-only.
              {
                # Renamed from "Legacy DLQ Empty" (2026-08-25): production
                # permanently carries 11,404 frozen legacy dead letters
                # until the M09 event-store replay recovers them — a
                # depth==0 condition fired Discord every 5 min forever.
                # The depth gauge's companion flag (upstream 2862b613)
                # pre-computes "unchanged since previous scrape": only NEW
                # legacy dead letters (the Jul 3-6 silent-loss class
                # regressing) flip it to 0. Anchored form is mandatory —
                # the HELP embeds "<metric> 1 if ..." (phantom-green trap).
                name = "DiscordSync Legacy DLQ Stable";
                group = "Infrastructure";
                url = "http://localhost:${toString ports.discordsync-api}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] != pat(*discordsync_projection_dlq_legacy_unchanged 0\n*)"
                  "[BODY] == pat(*\ndiscordsync_projection_dlq_legacy_unchanged *)"
                ];
                alert = "DiscordSync legacy DLQ GREW: new entries joined the frozen pre-v4.3 backlog (Jul 3-6 silent-loss incident class regressing). Check journalctl -u discordsync for decode failures; recovery of the frozen 11,404 remains plan M09";
              }
              {
                # Deliberately RED while local-only — the standing
                # stale-mirror signal (Turso free plan, decision-pending;
                # see docs/services/discordsync.md). Do not silence it.
                name = "DiscordSync Turso Sync Active";
                group = "Infrastructure";
                url = "http://localhost:${toString ports.discordsync-api}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*discordsync_turso_local_only_mode 0*)"
                ];
                alert = "DiscordSync in Turso local-only mode: cloud mirror paused (quota exhausted or sync gave up). Local archive intact, mirror is stale";
              }
              {
                # GCS visibility mirror (C11(8), 2026-09-27). The in-repo
                # DiscordSyncGCSBytesSpike alert is a RATE alert (24h growth)
                # which gatus body patterns cannot express — per the standing
                # policy above it stays Prometheus-only. The gatus-expressible
                # slice is scrape sanity: the discordsync_gcs_objects gauge
                # must exist, i.e. the reconcile stats pass is still running.
                # Its disappearance means the stats pass (or the GCS client)
                # died and bucket-growth visibility is dark.
                name = "DiscordSync GCS Stats Present";
                group = "Infrastructure";
                url = "http://localhost:${toString ports.discordsync-api}/metrics";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*\ndiscordsync_gcs_objects *)"
                ];
                alert = "DiscordSync GCS bucket gauges vanished from /metrics: the reconcile stats pass stopped publishing (stats pass or GCS client down). Bucket-growth visibility is dark";
              }
            ];
            homepage = {
              name = "DiscordSync";
              group = "Sync & Backup";
              description = "Discord Backup Bot (Messages, Attachments, Reactions)";
              icon = "discord.png";
            };
            monitored = true;
            # Event-store dump freshness (discordsync-db-backup.timer, 03:45)
            # — gated so pool-less hosts register no phantom backup row. The
            # dump-only RPO leg for the hot-db wave: Turso sync is
            # free-plan blocked, so this dump is the event store's only
            # backup once the DB leaves the `@` snapshot set.
            backup = lib.mkIf cfg.dbBackup.enable {
              directory = dbBackupDir;
              filePattern = "discordsync-db-*.sql.gz";
              maxAgeHours = 25;
            };
          };
        };
      };
    };
}
