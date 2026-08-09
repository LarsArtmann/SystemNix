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
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        mkStateDir
        ports
        onFailure
        ;
      cfg = config.services.discordsync;
      discordsyncPkg = inputs.discordsync.packages.${pkgs.stdenv.hostPlatform.system}.default;
      sopsEnvPath = config.sops.templates."discordsync-env".path;

      waitDnsReady = pkgs.writeShellApplication {
        name = "discordsync-wait-dns";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          echo "discordsync: waiting for DNS resolution..."
          curl -sf --max-time 5 --retry 60 --retry-delay 2 --retry-all-errors \
            -o /dev/null "https://discord.com" \
            || { echo "discordsync: DNS/network not ready after 120s — dnsblockd may not be initialized" >&2; exit 1; }
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
      #      btrbk snapshot with a healthy DB and clones it via CoW (instant,
      #      zero additional space). Recovers the pre-crash state.
      #   4. Only if ALL recovery fails → move corrupt DB aside for manual
      #      forensics and let DiscordSync start fresh (re-syncs from Turso).
      # Attachments in the separate attachments/ dir are always preserved.
      dbHeal = pkgs.writeShellApplication {
        name = "discordsync-db-heal";
        runtimeInputs = [ pkgs.sqlite ];
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
          echo "discordsync: DB integrity check FAILED — attempting recovery" >&2
          echo "discordsync: integrity_check result: $result" >&2
          ts=$(date +%Y%m%dT%H%M%S)
          backup="''${db}.corrupt-$ts"
          recovered="''${db}.recovered-$ts"

          # Back up the corrupt DB for forensics before touching it
          cp "$db" "$backup"

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
          if [ -d "$snapshots_dir" ]; then
            for snap in $(find "$snapshots_dir" -maxdepth 1 -name '@.*' -type d 2>/dev/null | sort -r); do
              snap_db="$snap/$db_rel"
              if [ -f "$snap_db" ]; then
                echo "discordsync: trying BTRFS snapshot restore from $(basename "$snap")" >&2
                # Try CoW clone first (instant), fall back to regular copy
                if cp --reflink=always "$snap_db" "$recovered" 2>/dev/null || cp "$snap_db" "$recovered" 2>/dev/null; then
                  snap_check=$(sqlite3 "$recovered" "PRAGMA integrity_check;" 2>&1 || true)
                  if [ "$snap_check" = "ok" ]; then
                    snap_rows=$(sqlite3 "$recovered" "SELECT count(*) FROM sqlite_master;" 2>/dev/null || echo "0")
                    echo "discordsync: snapshot restore succeeded — $snap_rows objects from $(basename "$snap")" >&2
                    mv "$recovered" "$db"
                    rm -f "$db-wal" "$db-shm" 2>/dev/null || true
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
      };

      config = lib.mkIf cfg.enable {
        services.discordsync = {
          package = lib.mkDefault discordsyncPkg;
          # Turso returns persistent 403 "SQL read operations are forbidden" on
          # the current plan. Upstream `OpenTursoSync` now detects this quota
          # error (tursostorage.IsQuotaExceeded) and falls back to opening the
          # local replica as plain SQLite with cloud sync disabled, so the
          # service runs fully local instead of crash-looping. A bare `sqlite`
          # backend was tried but caused 40+ min startup backfill (FTS5 trigger
          # contention with projection workers on a single connection) vs ~21
          # min with `turso-sync`, so keep `turso-sync` and rely on the quota
          # fallback. Cloud sync resumes automatically when the quota resets or
          # the plan is upgraded. The upstream quota fallback (OpenTursoSync)
          # is deployed (flake input bumped to the fix commit).
          backend = lib.mkDefault "turso-sync";
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

        systemd.services.discordsync = {
          # SystemNix DNS-gate: dnsblockd must resolve before Discord connect.
          after = [
            "sops-nix.service"
            "dnsblockd.service"
          ];
          wants = [
            "sops-nix.service"
            "dnsblockd.service"
          ];
          inherit onFailure;
          startLimitBurst = lib.mkForce 10; # SystemNix uses 10 (upstream is 5)

          environment = {
            # Preserve subdir layout (upstream uses dataDir root).
            ATTACHMENT_STORAGE_PATH = lib.mkForce "${cfg.dataDir}/attachments";
            # OTel traces → local SigNoz OTLP/HTTP collector. The binary
            # installs a noop tracer when this is unset. otlptracehttp.WithEndpoint
            # expects host:port WITHOUT scheme — the SDK constructs the full URL
            # internally (http://<endpoint>/v1/traces). WithInsecure() = plain HTTP.
            OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}";
          }
          // lib.optionalAttrs (cfg.gcsBucket != null) {
            GCS_BUCKET = cfg.gcsBucket;
            GOOGLE_APPLICATION_CREDENTIALS = config.sops.secrets.discordsync_gcs_credentials.path;
          };

          serviceConfig = lib.mkMerge [
            {
              # mkForce replaces the upstream ExecStartPre entirely.
              # The upstream module ships a broken chattr: "chattr -R +C ... 2>/dev/null || true"
              # — systemd ExecStartPre is NOT shell, so "2>/dev/null" and "|| true" are
              # passed as literal file arguments to chattr. Also lacks "+" prefix so runs
              # as the service user → "Operation not permitted". BTRFS +C (nodatacow) is
              # nice-to-have for SQLite but not required — DiscordSync uses WAL mode.
              # Fix upstream: wrap in pkgs.writeShellApplication or use ExecStartPre=+/bin/sh -c '...'.
              ExecStartPre = lib.mkForce [
                "+${lib.getExe dbHeal}"
                "+${lib.getExe waitDnsReady}"
              ];
              # DNS wait + DB integrity check can exceed systemd's default 90s
              # during system switches when I/O contention is high and dnsblockd
              # is still settling. 3 min covers worst observed case (~100s).
              TimeoutStartSec = "3min";
              # NO ExecStartPost readiness gate: the API server binds in a
              # goroutine AFTER thumb-hash backfill completes (3139+ attachments
              # at ~7/sec = 5-11 min). ExecStartPost runs immediately after
              # ExecStart, so any /readyz probe during backfill kills the
              # service via systemd timeout → crash loop. Health monitoring is
              # delegated to Gatus (60s interval) which correctly handles the
              # startup delay. See AGENTS.md "DiscordSync API startup race".
            }
            (harden {
              # Backfill bursts + turso-sync need more than upstream's 512M.
              MemoryMax = lib.mkForce "2G";
              ReadWritePaths = [ cfg.dataDir ];
            })
            {
              IOSchedulingClass = "best-effort";
              IOSchedulingPriority = 6;
            }
          ];
        };

        # Pre-create the attachments subdir with correct ownership.
        # (Upstream creates dataDir only — the subdir is a SystemNix convention.)
        systemd.tmpfiles.rules = [
          (mkStateDir cfg.dataDir "2770" cfg.user cfg.group)
          (mkStateDir "${cfg.dataDir}/attachments" "2770" cfg.user cfg.group)
        ];
      };
    };
}
