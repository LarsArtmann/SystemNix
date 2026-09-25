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
        ports
        onFailure
        ioTier
        serviceOneshotDefaults
        ;
      cfg = config.services.discordsync;
      discordsyncPkg = inputs.discordsync.packages.${pkgs.stdenv.hostPlatform.system}.default;
      sopsEnvPath = config.sops.templates."discordsync-env".path;

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

      # Verify the Immich API key wired for the /lookup page's cross-archive
      # comparison (ADR-062). Catches a mistyped or wrongly-scoped key at
      # provisioning time instead of leaving every lookup auth-erroring
      # silently behind the "Immich unavailable" badge. Exit semantics:
      #   0 = key verified, PLACEHOLDER-inert, not rendered (integration
      #       off), or Immich unreachable (availability is the Gatus Immich
      #       check's job — Immich being down must not page as a DiscordSync
      #       misconfig)
      #   1 = Immich reachable but REJECTED the key (wrong secret or missing
      #       asset.read/asset.upload scope) — OnFailure alerts
      immichVerify = pkgs.writeShellApplication {
        name = "discordsync-immich-verify";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          env_file="${sopsEnvPath}"
          url=""
          key=""
          while IFS= read -r line; do
            case "$line" in
              IMMICH_URL=*) url="''${line#IMMICH_URL=}" ;;
              IMMICH_API_KEY=*) key="''${line#IMMICH_API_KEY=}" ;;
            esac
          done < "$env_file"
          if [ -z "$url" ] || [ -z "$key" ]; then
            echo "discordsync-immich-verify: IMMICH_URL/IMMICH_API_KEY not rendered — integration disabled, nothing to verify"
            exit 0
          fi
          case "$key" in
            PLACEHOLDER*)
              echo "discordsync-immich-verify: API key is still a PLACEHOLDER (inert by design) — create a key in Immich scoped to asset.read + asset.upload ONLY, then sops --set it into discordsync-immich.yaml"
              exit 0
              ;;
          esac
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
          };
        };

        # Daemon-less verification: no HTTP endpoint, so monitoring is
        # OnFailure (Discord) + the system-health state metrics
        # (github-auto-assign pattern). The options?-guard mirrors the
        # integration-registry convention for hosts that enable this module
        # without system-health.
        services.system-health.extraMonitoredServices = lib.mkIf (
          cfg.immich.enable && options ? services.system-health
        ) (lib.mkAfter [ "discordsync-immich-verify" ]);

        systemd.services.discordsync = {
          # SystemNix DNS-gate: dnsblockd must resolve before Discord connect.
          # DB-heal oneshot runs independently (not blocking deploy activation).
          after = [
            "sops-nix.service"
            "dnsblockd.service"
            "discordsync-db-heal.service"
          ]
          ++ lib.optionals (cfg.attachmentsDir != null) [
            "discordsync-attachments-dir.service"
          ];
          wants = [
            "sops-nix.service"
            "dnsblockd.service"
            "discordsync-db-heal.service"
          ]
          ++ lib.optionals (cfg.attachmentsDir != null) [
            "discordsync-attachments-dir.service"
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
        systemd.services.discordsync-attachments-dir = lib.mkIf (cfg.attachmentsDir != null) {
          description = "Create DiscordSync attachment directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            # ReadWritePaths targets the MOUNT ROOT (cv-backup-dir pattern):
            # on a fresh pool nothing pre-exists under the mountpoint, and a
            # ReadWritePaths leaf entry would abort with 226/NAMESPACE before
            # the script can mkdir. RequiresMountsFor guarantees /mnt/pool is
            # mounted, so the root scope always resolves.
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool" ];
              # chown to the service user flips the path non-root-owned; the
              # follow-up chmod then needs CAP_FOWNER (2026-09-20 lesson —
              # CAP_DAC_OVERRIDE does NOT cover chmod on foreign-owned paths).
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            # chmod while the dir is still root-owned (no CAP_FOWNER needed),
            # then hand over to the service user. chmod AFTER the chown flip
            # EPERM'd live on 2026-09-22 despite CAP_FOWNER in the bounding
            # set — this order is idempotent and cap-independent. 0770, NOT
            # 2770: setting the setgid bit on a group outside the sandbox's
            # groups needs CAP_FSETID (not in the bounding set) — and the bit
            # is decorative anyway (the writer runs as the dir's owner/user).
            mkdir -p ${cfg.attachmentsDir}
            chown root:root ${cfg.attachmentsDir}
            chmod 0770 ${cfg.attachmentsDir}
            chown ${cfg.user}:${cfg.group} ${cfg.attachmentsDir}
          '';
        };

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
          path = with pkgs; [
            rsync
            coreutils
            systemd
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
                # see AGENTS.md). Do not silence it.
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
            ];
            homepage = {
              name = "DiscordSync";
              group = "Sync & Backup";
              description = "Discord Backup Bot (Messages, Attachments, Reactions)";
              icon = "discord.png";
            };
            monitored = true;
          };
        };
      };
    };
}
