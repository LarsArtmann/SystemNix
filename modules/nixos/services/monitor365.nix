# Runbook: docs/services/monitor365.md
# Monitor365: thin SystemNix wrapper around upstream NixOS modules.
#
# Heavy lifting (TOML generation, systemd services, hardening, collector
# schema, bootstrap/SSO) is in the monitor365 flake:
#   nix/module.nix         → services.monitor365 (unified agent with IPC)
#   nix/server-module.nix  → services.monitor365-server (control plane)
#
# This file only adds SystemNix-specific defaults: port wiring, sops
# secret wiring, runtime deps, and pocket-id SSO integration.
#
# ── Unified Agent Architecture ──────────────────────────────
# A single agent instance runs on each monitored machine:
#
#   services.monitor365 (system service, survives logout)
#      - Dedicated 'monitor365' system user with linger
#      - Headless collectors: network, process, system_info, battery, etc.
#      - Desktop collectors: screenshots, camera, keystrokes, etc.
#        Display env discovered from active sessions via the graphical helper;
#        skip gracefully if no session
#      - IPC socket at /run/monitor365/agent.sock for graphical helper
#      - Auth via LoadCredential (reads sops secret as root)
#      - graphicalUsers: login users granted IPC group access
#
# Both collectors sync to the local server as one device.
#
# ── Auth Model ──────────────────────────────────────────────
# The server bootstrap generates (or reads from sops) ONE tenant-level
# API key.  This key is shared by all agents in the tenant — it proves
# tenant membership, not device identity.  Per-device identity is
# established via hardware fingerprint headers (x-device-fingerprint,
# x-hardware-fingerprint, x-host-id) sent alongside the API key.
#
# The same sops secret value (cloud_auth_token) is materialised with
# different owners (desktop user vs monitor365-server system user) because
# sops-nix grants file ownership per entry.
#
# In a multi-machine deployment each machine would have its own sops
# file but with the same tenant key value.  If a machine is compromised
# the admin rotates the key in sops and redeploys.
{ inputs, ... }: {
  flake.nixosModules.monitor365 =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (config.users) primaryUser;
      inherit (import ../../../lib/default.nix lib)
        ports
        ioTier
        harden
        serviceOneshotDefaults
        onFailure
        ;
      domain = config.networking.domain;

      # Agent event buffer lives on the mirrored HDD pool (subvol reserved at
      # the 2026-08-16 pool bring-up, populated 2026-08-18 by
      # data-to-pool-migration.service) instead of the NVMe /data partition.
      # The buffer can grow to 30 GiB (max_size_mb). /mnt/pool mounts nofail;
      # a detached DAS fails the agent loudly via RequiresMountsFor instead of
      # contaminating the root filesystem — acceptable for a non-critical
      # monitoring service.
      # NOTE: the migrated files carry the stale uid 966:956 of the
      # monitor365 user from before the service was disabled. Re-enabling
      # requires re-chowning this tree if the recreated user gets a different
      # uid.
      agentStoragePath = "/mnt/pool/services/monitor365";

      # Off-NVMe interim DB backup copy (2026-10-27 storage-crisis plan S5):
      # the ONLY copy of the monitor365 DuckDB outside the QLC NVMe was a
      # 5d-stale T04 pool archive — until the S8 hot-tier migration lands,
      # this nightly copy is the disaster leg (NVMe loss = live DB + local
      # backups gone; this file survives). Same subvol as the agent buffer,
      # own subdir, service-user-owned.
      poolBackupDir = "${agentStoragePath}/backups";

      # Event retention (2026-10-23): the server ingested ~5.3M events/day
      # (597M backlog era average) with NO upstream retention — the DuckDB
      # hit 25.1 GB. DELETE-by-age runs nightly inside the quiesced backup
      # window; VACUUM (file rewrite — DuckDB never truncates after deletes)
      # runs weekly, stamp-gated + disk-headroom-guarded. Raise/lower the
      # window here; 90d balances dashboard history vs DB size (~2-6 GB
      # steady-state at post-cut collection rates).
      retentionDays = 90;
      vacuumIntervalSeconds = 604800; # 7 days
      vacuumHeadroomBytes = 5368709120; # 5 GiB free required on top of DB size

      systemAgentCfg = config.services.monitor365;
      serverCfg = config.services.monitor365-server;

      # The Pocket ID identity monitor365 matches SSO logins against (email
      # ONLY — no JIT provisioning, runbook docs/services/monitor365.md).
      # Must equal the Pocket ID account email; if that ever changes,
      # update this line.
      ssoAdminEmail = "lars@larsartmann.cloud";

      # Runtime deps — CLI tools for system + desktop collectors.
      # Wired into the systemd service PATH by the upstream module.
      # X11 tools (xdotool, xprintidle, scrot, wmctrl) are kept for upstream
      # compatibility but are non-functional on niri (Wayland-only).
      # Wayland equivalents (grim, slurp, wtype) are provided for the
      # screenshot/keyboard collectors once upstream supports them.
      runtimeDeps = [
        pkgs.procps
        pkgs.util-linux
        pkgs.coreutils
        pkgs.lm_sensors
        pkgs.networkmanager
        # hardware_identity mac_permanent collector: ethtool -P reads the
        # etched NIC address (stable under Wi-Fi MAC randomization)
        pkgs.ethtool
        pkgs.bluez
        # X11 (legacy — evo-x2 runs Wayland-only niri)
        pkgs.xdotool
        pkgs.xprintidle
        pkgs.scrot
        pkgs.wmctrl
        # Wayland (functional on niri)
        pkgs.grim
        pkgs.slurp
        pkgs.wtype
      ];

      # RETIRED 2026-10-27: monitor365-schema-migrate (ALTER tenants.version +
      # UPDATE max_events_per_day = 1B on every boot).
      # - tenants.version: current upstream ships migration 062
      #   (062_add_version_columns.sql, ADD COLUMN IF NOT EXISTS) — the
      #   out-of-band ALTER is redundant against any DB the pinned+later
      #   upstream touches.
      # - max_events_per_day = 1B: upstream NEVER resets limits of existing
      #   tenants at boot (source-verified 2026-10-27: the existing-tenant
      #   bootstrap path only re-syncs the API key; no startup code writes
      #   max_events_per_day). The "server re-syncs upstream default on
      #   bootstrap" premise was stale. The declarative replacement is the
      #   MONITOR365_SERVER__BOOTSTRAP__MAX_EVENTS_PER_DAY env below, which
      #   covers the fresh-DB/restore case; once the monitor365 flake input
      #   is bumped past 2026-10-27, migrate to the upstream module options
      #   (services.monitor365-server.bootstrap.maxEventsPerDay/maxDevices).

      # Heal DuckDB before the server starts: remove a stale WAL from an
      # unclean shutdown (DuckDB checkpoints + deletes the WAL on graceful
      # exit, so a present WAL always means a crash) and restore the main DB
      # from the newest nightly backup if it is missing or empty.
      duckdbHealScript = pkgs.writeShellApplication {
        name = "monitor365-duckdb-heal";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
        ];
        text = ''
          DB_DIR="${serverCfg.stateDir}"
          WAL="$DB_DIR/monitor365.duckdb.wal"
          MAIN_DB="$DB_DIR/monitor365.duckdb"

          if [ -f "$WAL" ]; then
            echo "monitor365-duckdb-heal: WAL from unclean shutdown found, removing to prevent replay crash"
            rm -f "$WAL"
          fi

          # If the main DB is missing or empty, restore from the most
          # recent nightly backup before the server starts.
          if [ ! -f "$MAIN_DB" ] || [ ! -s "$MAIN_DB" ]; then
            LATEST_BACKUP="$(
              find "$DB_DIR" -maxdepth 1 -name '*.backup_*.db' -printf '%T@\t%p\n' 2>/dev/null \
                | sort -rn | cut -f2- | head -1 || true
            )"
            if [ -n "$LATEST_BACKUP" ]; then
              echo "monitor365-duckdb-heal: main DB missing/empty, restoring from backup: $LATEST_BACKUP"
              cp "$LATEST_BACKUP" "$MAIN_DB"
            else
              echo "monitor365-duckdb-heal: main DB missing/empty, no backup found — server will create fresh DB"
            fi
          fi
        '';
      };

      # Ensure the Pocket ID SSO identity exists in the tenant DB before the
      # server starts (idempotent boot-time heal). Monitor365 matches SSO
      # logins on email ONLY and has NO JIT provisioning: a DB restored from
      # a pre-provisioning backup (or a projection rebuild losing the user
      # row) breaks EVERY SSO login with "Unauthorized: SSO user not found"
      # while agents keep working (live 2026-10-25, again 2026-10-28 — the
      # manual create-admin heal was lost to the Oct-26/27 backup-restore
      # churn). Upstream bootstrap provisions the admin only on a
      # tenant-EMPTY DB (the existing-tenant path re-syncs the API key only
      # — crates/server/src/bootstrap/mod.rs, source-verified 2026-10-28),
      # so this ExecStartPre is the declarative replacement for the manual
      # create-admin runbook step. Runs as the service user BEFORE the
      # server takes the single-writer lock; the upstream CLI's
      # duplicate-email rejection is the idempotency signal.
      ssoIdentityScript = pkgs.writeShellApplication {
        name = "monitor365-ensure-sso-identity";
        runtimeInputs = [
          pkgs.coreutils
        ];
        text = ''
          if OUT="$(monitor365-server create-admin --email '${ssoAdminEmail}' 2>&1)"; then
            echo "monitor365-ensure-sso-identity: created SSO admin ${ssoAdminEmail}"
          else
            case "$OUT" in
              # Duplicate-email rejection comes in TWO upstream wordings —
              # the CLI's friendly one and the DuckDB unique-constraint
              # error (the 2026-10-29 01:32 start-limit outage: the
              # constraint form has NO "already exists" substring, so the
              # missing pattern exit-1'd the ExecStartPre on every start
              # after the first heal and the unit burned its start budget).
              # BOTH mean the identity is present = success.
              *"already exists"*|*"violates unique constraint"*)
                echo "monitor365-ensure-sso-identity: SSO admin ${ssoAdminEmail} already exists"
                ;;
              *"No tenants found"*)
                echo "monitor365-ensure-sso-identity: WARNING: no tenants yet — in-server bootstrap provisions tenant+admin when fully configured" >&2
                ;;
              *)
                echo "monitor365-ensure-sso-identity: ERROR: $OUT" >&2
                exit 1
                ;;
            esac
          fi
        '';
      };

      # Server DB backup, quiesced. Upstream's backup (admin_cmd.rs
      # run_backup) opens the live DuckDB directly, and DuckDB is
      # single-writer-per-file — while the upstream unit orders
      # After+Wants monitor365-server.service, so EVERY fire dies with
      # "Conflicting lock is held" (2026-10-18 01:42 deploy failure).
      # DuckDB has no read-only side door against a writer's lock, so the
      # only consistent export is server-stopped (discordsync-migrate
      # idiom). ~1min dashboard outage at 03:00 / boot catch-up.
      monitor365RetentionScript = pkgs.writeShellApplication {
        name = "monitor365-retention";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.duckdb
        ];
        # Standalone + repo-file-backed so the fixture
        # (checks.monitor365-retention-selftest) executes the SAME text
        # the 03:00 window runs — eval cannot see interpolation or logic
        # bugs in unattended-window scripts.
        text = builtins.readFile ../../../scripts/monitor365-retention.sh;
      };

      monitor365BackupScript = pkgs.writeShellApplication {
        name = "monitor365-server-backup-quiesced";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.findutils
          pkgs.systemd
          pkgs.duckdb
        ];
        text = ''
          STATE_DIR="${serverCfg.stateDir}"
          SERVER="monitor365-server.service"
          WATCHDOG_TIMER="monitor365-server-watchdog.timer"
          KEEP="${toString serverCfg.backup.keep}"

          cd "$STATE_DIR"

          # Pause the watchdog first: its is-active check auto-STARTS an
          # inactive server, which would re-grab the DuckDB lock mid-backup.
          if ! systemctl stop "$WATCHDOG_TIMER"; then
            echo "monitor365-server-backup: WATCHDOG PAUSE FAILED — refusing to stop the server (backup skipped)"
            exit 1
          fi
          if ! systemctl stop "$SERVER"; then
            echo "monitor365-server-backup: SERVER STOP FAILED — aborting before any DB access; restarting watchdog"
            systemctl start "$WATCHDOG_TIMER" || true
            exit 1
          fi
          restore() {
            systemctl start "$SERVER" \
              || echo "monitor365-server-backup: CRITICAL — server RESTART FAILED; start $SERVER manually"
            systemctl start "$WATCHDOG_TIMER" || true
          }
          trap restore EXIT TERM INT

          # Backup export (2026-10-25 third redesign): upstream's
          # `monitor365-server backup` (DuckDB ATTACH + COPY FROM DATABASE)
          # OOM-aborts on this DB regardless of memory_limit — 1.86 GiB
          # default on 2026-10-25 03:01, then a VALID 6GB limit (5.5 GiB
          # applied, shape-verified) still died "backup copy failed: Failed
          # to commit: failed to pin block" ~3 min in at ~7-8 GB written
          # (first-hand forced fire 2026-10-25 16:12; the Oct 24/25
          # 7-8 GB "backups" are partial corpses of the same class — last
          # FULL export is 2026-10-23). COPY FROM DATABASE pins target
          # blocks until commit and cannot stream a 30 GB DB under any
          # sane cgroup. Replace it with the owner-ratified NVMe-safety
          # pattern: the server is STOPPED (single writer quiesced) and
          # the on-disk file CHECKPOINTed, so a file copy IS a consistent
          # backup. --reflink=always on the same BTRFS subvol makes the
          # copy instant and IO-free (CoW); plain-copy fallback kept for
          # exotic layouts. Same *.backup_*.db naming the prune below and
          # the heal script's restore path already speak.
          # Run as root, NOT via `runuser -u monitor365-server`: the unit's
          # harden preset blocks runuser's setuid under the systemd 261
          # sandbox ("cannot set user id: Operation not permitted", first-fire
          # evidence 2026-10-25 17:13 — CAP_SETUID present and @setuid is
          # inside @system-service, yet still EPERM). Root-run duckdb on the
          # quiesced DB is the pattern the 2026-10-25 out-of-band index
          # rebuild already proved live-safe; the chown net right after
          # returns any WAL/tmp residue to the service user so the next
          # server start stays writable (root-owned files are the hazard).
          duckdb "$STATE_DIR/monitor365.duckdb" \
            -c "SET memory_limit='6GB'; SET threads=2; CHECKPOINT;"
          chown -R monitor365-server:monitor365-server "$STATE_DIR"
          STAMP=$(date -u +%Y%m%dT%H%M%SZ)
          DEST="$STATE_DIR/monitor365.duckdb.backup_$STAMP.db"
          if ! cp --reflink=always "$STATE_DIR/monitor365.duckdb" "$DEST"; then
            echo "monitor365-server-backup: reflink unavailable — falling back to full copy"
            cp "$STATE_DIR/monitor365.duckdb" "$DEST"
          fi
          chown monitor365-server:monitor365-server "$DEST"
          chmod 0600 "$DEST"
          SIZE=$(stat -c '%s' "$DEST")
          echo "monitor365-server-backup: export landed (reflink) $DEST ($SIZE bytes)"

          # Retain only the newest KEEP backups (upstream's ls -t prune,
          # re-expressed with find for the nullglob audit).
          find "$STATE_DIR" -maxdepth 1 -name '*.backup_*.db' -printf '%T@\t%p\n' 2>/dev/null \
            | sort -rn | tail -n +"$((KEEP + 1))" | cut -f2- | xargs -r rm -f

          # ── Event retention (2026-10-23) ─────────────────────────────
          # Runs INSIDE the quiesce window (server stopped = the only
          # single-writer slot), AFTER the export above — the backup just
          # written is the rollback copy for tonight's DELETE. Logic +
          # guards live in scripts/monitor365-retention.sh (fixture-
          # tested); WARN-not-die by design so this EXIT trap still
          # restores the server.
          STATE_DIR="$STATE_DIR" \
          RETENTION_DAYS="${toString retentionDays}" \
          VACUUM_INTERVAL_S="${toString vacuumIntervalSeconds}" \
          VACUUM_HEADROOM_B="${toString vacuumHeadroomBytes}" \
          ${lib.getExe monitor365RetentionScript}

          echo "monitor365-server-backup: backup complete, server restored"
        '';
      };
    in
    {
      imports = [
        inputs.monitor365.nixosModules.monitor365
        inputs.monitor365.nixosModules.monitor365-server
      ];

      config = lib.mkMerge [
        # ── Unified agent defaults ────────────────────────────────
        (lib.mkIf systemAgentCfg.enable {
          services.monitor365 = {
            runtimeDeps = lib.mkDefault runtimeDeps;
            graphicalUsers = lib.mkDefault [ primaryUser ];
            # Display discovery: the upstream start script uses pgrep to find
            # the displayUser's compositor (niri), reads DISPLAY/WAYLAND_DISPLAY/
            # XAUTHORITY/etc from /proc/<pid>/environ, and exports them before
            # exec. ProtectProc is relaxed to "default" below so pgrep can see
            # niri's PID. See the detailed comment near the ProtectProc override
            # for the full timing + restart mechanism.
            displayUser = lib.mkDefault primaryUser;

            settings = {
              device = {
                name = lib.mkDefault "${config.networking.hostName}";
                type = lib.mkDefault "server";
              };

              storage = {
                path = lib.mkDefault agentStoragePath;
                encryption = lib.mkDefault true;
                encryption_key_file = lib.mkDefault "${agentStoragePath}/storage_key";
                max_size_mb = lib.mkDefault (30 * 1024);
              };

              logging.level = lib.mkDefault "warn";
              metrics = {
                enabled = lib.mkDefault true;
                bind_address = lib.mkDefault "127.0.0.1:${toString ports.monitor365-metrics}";
              };

              # Agent authenticates via LoadCredential — systemd reads
              # the sops secret as root and provisions it to the service.
              cloud = lib.mkIf serverCfg.enable {
                endpoint = lib.mkDefault "http://localhost:${toString ports.monitor365-server}";
                sync_interval_seconds = lib.mkDefault 60;
                # 2026-10-27 CORRECTION (upstream source-verified): the
                # upstream sync loop NEVER reads cloud.batch_size — uploads
                # are chunked by the cloud client at 5000 events/POST
                # (size_aware_chunks, DEFAULT_MAX_BATCH_SIZE) plus an 8 MB
                # payload cap, 50K events/cycle = ~10 POSTs, regardless of
                # this key. The earlier "50x amplification" mechanism was
                # wrong (the storm's driver was the per-append MAX(sequence)
                # full-table scan, fixed upstream 2026-10-26). Keeping 5000
                # anyway: harmless, documents intent, and matches the real
                # chunk size if upstream ever wires the field.
                batch_size = lib.mkDefault 5000;
                authTokenFile = lib.mkDefault config.sops.secrets.cloud_auth_token.path;

                # 2026-10-27 BACKLOG DRAIN (owner-approved T04/T06): discard
                # the two worthless backlog families locally instead of
                # uploading them — analytics.* is the 2026-09 correlation-
                # flood debris, system.cgroup is per-cycle batch noise. The
                # cutoff bounds the drain to events older than today, so
                # live telemetry can never match. DISARM after the drain
                # (T09 window): delete this drain_filter block, then
                # `nixos-rebuild switch` — no other change needed.
                drain_filter = {
                  discard_event_types = [
                    "analytics.*"
                    "system.cgroup"
                  ];
                  discard_events_before = "2026-10-27T00:00:00Z";
                };
              };
            };
          };
        })

        # ── Server defaults ────────────────────────────────────────
        (lib.mkIf serverCfg.enable {
          services.monitor365-server = {
            listenAddr = lib.mkDefault "0.0.0.0:${toString ports.monitor365-server}";
            port = lib.mkDefault ports.monitor365-server;
            dashboardUrl = lib.mkDefault "https://monitor.${domain}/ui/";

            # CORS is unnecessary for this deployment: the WASM dashboard and
            # API are served from the same origin behind Caddy (monitor.<domain>).
            # The upstream module CAN emit MONITOR365_SERVER__CORS_ORIGINS as a
            # comma-separated string — the Rust config parser uses figment's
            # with_list_parse_key to correctly parse it into Vec<String> (fixed
            # upstream 2026-05-08, commit 1a11bc034). Set corsOrigins here only
            # if the dashboard is served from a different origin than the API.

            jwtSecretFile = lib.mkDefault config.sops.secrets.server_jwt_secret.path;
            environmentFile = lib.mkDefault config.sops.templates."monitor365-server-env".path;

            bootstrap = {
              enable = lib.mkDefault true;
              # Pre-provisioned tenant API key from sops — server and agent
              # all read the same underlying value.
              apiKeyFile = lib.mkDefault config.sops.secrets.cloud_auth_token.path;
            };

            sso = lib.mkIf (config.services.pocket-id.enable or false) {
              issuer = lib.mkDefault "https://auth.${domain}";
              clientSecretFile = lib.mkDefault "${
                config.services.pocket-id.dataDir or "/var/lib/pocket-id"
              }/client-secrets/monitor365";
              redirectUri = lib.mkDefault "https://monitor.${domain}/v1/auth/sso/callback";
            };
          }
          # 2026-10-27 BACKLOG DRAIN (owner-approved T05): widen compaction
          # so Apr–Aug backlog events arriving during the drain are NOT
          # compacted on arrival (default was 90d/180d). Existence-guarded
          # (2026-10-27): upstream master does not define these options yet
          # (drain support in-flight upstream — the unguarded pair killed
          # every evo-x2 eval at any lock rev); the values apply automatically
          # on the first upstream rev that declares them. TIGHTEN BACK to
          # the defaults after the drain completes — delete this block (T09),
          # the upstream module defaults restore 90/180.
          //
            lib.optionalAttrs
              (
                options ? services.monitor365-server
                && options.services.monitor365-server ? compactionExtendedRetentionDays
              )
              {
                compactionRetentionDays = lib.mkDefault 365;
                compactionExtendedRetentionDays = lib.mkDefault 365;
              };

          users.users.monitor365-server.extraGroups = lib.optional (
            serverCfg.sso.enable && (config.services.pocket-id.enable or false)
          ) "pocket-id";
        })

        # Backup health monitoring consolidated into the generic
        # backup-coordination module (services.backup-coordination.backups.monitor365).
        # That module writes backup_healthy{backup="monitor365"} to the shared
        # textfile collector, replacing the former monitor365_backup_* metrics.

        # Restart both agent and server when the sops secret or package changes.
        # Package triggers ensure services restart after flake updates even if
        # switch-to-configuration doesn't detect the unit-file change.
        (lib.mkIf (systemAgentCfg.enable || serverCfg.enable) {
          systemd.services.monitor365.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
            systemAgentCfg.package
          ];
          systemd.services.monitor365-server.restartTriggers = [
            config.sops.secrets.cloud_auth_token.path
            serverCfg.package
          ];
        })

        # DuckDB WAL corruption self-healing — same defensive pattern as the
        # SigNoz migration-lock clear. When the server crashes mid-write (OOM,
        # WDT reset, power loss), the WAL file can end up corrupt: DuckDB's
        # replay fails with "Failure while replaying WAL file … Calling
        # DatabaseManager::GetDefaultDatabase with no default database set"
        # (an INTERNAL/assertion error). The server crash-loops indefinitely
        # (291+ restarts observed), leaving port 3001 unreachable — the
        # agent's circuit breaker opens (220K+ consecutive failures), all
        # telemetry accumulates in the disk buffer, and events are dropped.
        #
        # DuckDB checkpoints the WAL into the main DB on graceful shutdown and
        # deletes the .wal file. A .wal present at startup ALWAYS means the
        # previous shutdown was unclean. Always removing it eliminates this
        # crash class entirely. The data loss is limited to events from the
        # last uncheckpointed session (acceptable for a monitoring dashboard).
        # If the main DB is also gone, restore from the nightly backup.
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-server = {
            serviceConfig = {
              ExecStartPre = lib.mkBefore (
                [
                  (lib.getExe duckdbHealScript)
                ]
                # After the heal: the identity check opens the DB only once
                # the WAL/restore state is resolved. Order matters.
                ++ lib.optionals (serverCfg.sso.enable or false) [
                  (lib.getExe ssoIdentityScript)
                ]
              );
              TimeoutStartSec = "3min";
            };
          };
        })

        # OTel traces → local SigNoz OTLP/gRPC collector (tonic). The otel
        # cargo feature must be enabled in the build (see upstream flake.nix
        # commonArgs). Tonic requires http:// scheme in the endpoint.
        # When unset, noop tracer is used (zero overhead).
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-server.environment = {
            OTEL_EXPORTER_OTLP_ENDPOINT = lib.mkDefault "http://localhost:${toString ports.signoz-otlp-grpc}";
          };
          # Upstream build enables the otel cargo feature (--features otel,
          # upstream flake.nix commonArgs), so spans actually flow — register
          # the unit in the signoz-coverage census (reverse assertion refuses
          # env-var silent noops). Request-driven budget: 26h.
          services.signoz-coverage.expected.monitor365-server = {
            serviceName = "monitor365-server";
            wiring = "env";
            maxAgeHours = 26;
          };
        })

        # (Schema-migrate oneshot unit RETIRED 2026-10-27 — see the note at
        # the former schemaMigrateScript site. Upstream owns migrations now.)

        # Declarative tenant limits (replaces the retired schema-migrate
        # UPDATE hack): consumed by upstream bootstrap ONLY when it actually
        # provisions a fresh database (restore-from-backup / re-init). An
        # existing tenant's limits are never touched at boot. Env-var form
        # works against any pinned upstream; migrate to the module options
        # after the next monitor365 input bump.
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-server.environment = {
            MONITOR365_SERVER__BOOTSTRAP__MAX_EVENTS_PER_DAY = "1000000000";
            MONITOR365_SERVER__BOOTSTRAP__MAX_DEVICES = "1000";
          };
        })

        # Backup unit override: quiesce the server around the DuckDB export
        # (see monitor365BackupScript). Root-run because the script drives
        # systemctl; StateDirectory dropped — with User=root systemd would
        # chown the state dir away from the server user (root:root) and the
        # next server start would be unable to write its own DB.
        (lib.mkIf (serverCfg.enable && serverCfg.backup.enable) {
          systemd.services.monitor365-server-backup = {
            restartTriggers = [ (lib.getExe monitor365BackupScript) ];
            serviceConfig = lib.mkMerge [
              {
                ExecStart = lib.mkForce (lib.getExe monitor365BackupScript);
                User = lib.mkForce "root";
                Group = lib.mkForce "root";
                StateDirectory = lib.mkForce null;
                # The export + retention + weekly VACUUM window: observed
                # exports ran 2.5-6 min; a 25 GB VACUUM on the QLC root
                # needs the rest of the budget. mkForce: upstream
                # server-module.nix hard-sets 10min, which a bare
                # definition turns into a conflicting-definition eval error.
                TimeoutStartSec = lib.mkForce "30min";
                # Observed memory peaks 7.4-20.8 GB across the 2026-10-19
                # ..23 fires (systemd Consumed lines) — the root-run
                # override previously carried NO cap at 03:00 while other
                # nightly jobs run. 8G/12G keeps the watermark coherent
                # (MemoryHigh >= 50% of MemoryMax, memory-watermark-audit)
                # with headroom above the 10.2 GB observed peak.
                MemoryHigh = "8G";
                MemoryMax = "12G";
              }
              ioTier.background
            ];
          };
        })

        # ── Pool-interim off-NVMe copy (2026-10-27 plan S5) ─────────
        # Copies the NEWEST nightly backup to the HDD pool 25 min after the
        # 03:00 quiesced backup (After= holds the start if the backup window
        # — export + retention + VACUUM attempt, 30min budget — is still
        # running). Runs as the service user: the source dir is its own
        # 0750 stateDir, the dest is its own tmpfiles dir — no capabilities
        # needed, DAC-clean by construction. Pool-side freshness is wired
        # into backup-coordination below (stale >25h = alert).
        (lib.mkIf (serverCfg.enable && serverCfg.backup.enable) {
          systemd.services.monitor365-pool-copy = {
            description = "Monitor365 newest DB backup copy to the HDD pool (off-NVMe interim leg)";
            after = [ "monitor365-server-backup.service" ];
            wants = [ "monitor365-server-backup.service" ];
            inherit onFailure;
            unitConfig.RequiresMountsFor = [
              serverCfg.stateDir
              poolBackupDir
            ];
            path = [
              pkgs.coreutils
              pkgs.findutils
            ];
            serviceConfig = lib.mkMerge [
              (harden {
                MemoryMax = "512M";
                ReadWritePaths = [ poolBackupDir ];
              })
              (serviceOneshotDefaults { })
              ioTier.background
              {
                Type = "oneshot";
                User = "monitor365-server";
                Group = "monitor365-server";
                TimeoutStartSec = "60min";
              }
            ];
            script = ''
              set -euo pipefail
              STATE_DIR="${serverCfg.stateDir}"
              SRC="$(find "$STATE_DIR" -maxdepth 1 -name '*.backup_*.db' -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2)"
              if [ -z "$SRC" ]; then
                echo "monitor365-pool-copy: no backup file in $STATE_DIR — did the 03:00 backup run?" >&2
                exit 1
              fi
              DEST="${poolBackupDir}/$(basename "$SRC")"
              if [ ! -e "$DEST" ]; then
                # Plain cp: cross-filesystem (QLC→HDD pool), no reflink
                # possible. mtime = copy time, which is exactly what the
                # freshness collector reads.
                cp -- "$SRC" "$DEST"
              fi
              SRC_SIZE="$(stat -c '%s' "$SRC")"
              DEST_SIZE="$(stat -c '%s' "$DEST")"
              if [ "$SRC_SIZE" != "$DEST_SIZE" ]; then
                echo "monitor365-pool-copy: size mismatch after copy ($SRC_SIZE vs $DEST_SIZE) — removing partial" >&2
                rm -f "$DEST"
                exit 1
              fi
              # Pool-side retention: newest 3 (the local side keeps 2; the
              # pool leg buys NVMe-loss rollback depth, not indefinite
              # history — 3×33G on a 12T-free pool is noise).
              find "${poolBackupDir}" -maxdepth 1 -name '*.backup_*.db' -printf '%T@\t%p\n' 2>/dev/null \
                | sort -rn | tail -n +4 | cut -f2 | xargs -r rm -f
              echo "monitor365-pool-copy: $DEST ($DEST_SIZE bytes) — off-NVMe leg fresh"
            '';
          };

          systemd.timers.monitor365-pool-copy = {
            description = "Nightly monitor365 backup copy to the HDD pool";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 03:25:00";
              Persistent = true;
              RandomizedDelaySec = "10m";
            };
          };

          systemd.tmpfiles.rules = [
            # The PARENT must grant traverse to the server-backup unit user:
            # tmpfiles only modes the FINAL component (forgejo ci-runner
            # lesson 2026-10-16), and agentStoragePath is owned by the AGENT
            # user 0750 — monitor365-server cannot cross it (live cp EPERM
            # in the 2026-10-27 22:04 force-run). 0711 = owner rwx (agent
            # unchanged), everyone else traverse-only.
            "d ${agentStoragePath} 0711 monitor365 monitor365 - -"
            "d ${poolBackupDir} 0750 monitor365-server monitor365-server - -"
          ];

          # Pool-side freshness entry: the local backup_healthy row only
          # proves the NVMe copy ran; this one proves the disaster leg is
          # current (stale >25h = the copy unit failed while the backup
          # kept succeeding — exactly the silent gap S5 closes).
          services.backup-coordination = lib.optionalAttrs (options ? services.backup-coordination) {
            backups.monitor365-pool = {
              directory = poolBackupDir;
              filePattern = "*.backup_*.db";
              maxAgeHours = 25;
            };
          };
        })

        # ── Agent resilience: start-limit + self-healing ──────────────
        # The upstream module doesn't set StartLimitBurst/StartLimitIntervalSec,
        # so systemd defaults (5/10s) apply. When the agent exits rapidly
        # (e.g. niri restart triggering graphical-restart path unit multiple
        # times in 1 second), the default limit is hit immediately and the
        # agent stays dead until the next deploy. Set generous limits so
        # transient crashes self-heal.
        (lib.mkIf systemAgentCfg.enable {
          systemd.services.monitor365 = {
            startLimitBurst = 10;
            startLimitIntervalSec = 300;
            serviceConfig.CPUQuota = "200%"; # Cap at 2 cores — prevents CB busy-loop runaway
            # Detached DAS fails the agent loudly instead of writing the event
            # buffer onto the root filesystem under the /mnt/pool mountpoint
            # (same RequiresMountsFor mount-gating semantics the deleted
            # mkDockerService backup.dir used to enforce).
            unitConfig.RequiresMountsFor = [ agentStoragePath ];
          };
        })

        # Agent health watchdog: periodically verify the agent is running,
        # its metrics endpoint responds, and the server sees it as a connected
        # device. If any check fails, reset start-limit and restart the agent.
        # This breaks the circuit-breaker deadlock (CB is in-memory; restart
        # clears it) and ensures the agent recovers from crashes that deploy.sh
        # misses (deploy only does reset-failed, not start).
        (lib.mkIf (systemAgentCfg.enable && serverCfg.enable) {
          systemd.services.monitor365-agent-watchdog = {
            description = "Monitor365 agent health watchdog";
            after = [
              "monitor365-server.service"
              "monitor365.service"
            ];
            serviceConfig = {
              Type = "oneshot";
              # Must run as root — the watchdog calls `systemctl start/restart`
              # on system services, which requires root. The monitor365 user
              # cannot start system services.
              NoNewPrivileges = true;
              PrivateTmp = true;
            };
            path = [
              pkgs.systemd
              pkgs.curl
              pkgs.jq
            ];
            script = ''
              AGENT_METRICS="http://localhost:${toString ports.monitor365-metrics}/metrics"
              SERVER_HEALTH="http://localhost:${toString ports.monitor365-server}/health"
              # 0-device restarts are BOUNDED. The "circuit breaker deadlock"
              # mitigation only helps when the deadlock is transient; when the
              # server reports 0 devices because device registration itself is
              # broken, an unbounded loop re-fires the whole event drain every
              # 5 min and never converges (live 2026-10-27: 7 restarts/hour,
              # ~1.3 GB re-drained per restart). Three attempts, then stop and
              # let the alerting surface the real fault.
              ZERO_DEVICE_STAMP="/run/monitor365-agent-watchdog.zero-device-restarts"
              ZERO_DEVICE_MAX=3

              # 1. Is the agent process alive?
              if ! systemctl is-active --quiet monitor365.service; then
                echo "monitor365-agent-watchdog: agent is NOT active — resetting start-limit and starting"
                systemctl reset-failed monitor365.service 2>/dev/null || true
                systemctl start monitor365.service || true
                exit 0
              fi

              # 2. Is the agent's metrics endpoint responding?
              if ! curl -sf -m 5 "$AGENT_METRICS" >/dev/null 2>&1; then
                echo "monitor365-agent-watchdog: agent metrics endpoint unreachable — restarting"
                systemctl restart monitor365.service || true
                exit 0
              fi

              # 3. Is the server itself healthy?
              # If the server's /health fails (DuckDB pool deadlock, OOM, etc.),
              # the agent's circuit breaker opens and it busy-loops at ~200%
              # CPU. Restart the agent to clear the in-memory CB and stop CPU
              # burn. The server watchdog will restart the server separately.
              SERVER_HTTP=$(curl -sf -m 10 -o /dev/null -w "%{http_code}" "$SERVER_HEALTH" 2>/dev/null || echo "000")
              if [ "$SERVER_HTTP" != "200" ]; then
                echo "monitor365-agent-watchdog: server unhealthy (HTTP $SERVER_HTTP) — restarting agent to clear circuit breaker"
                systemctl restart monitor365.service || true
                exit 0
              fi

              # 4. Does the server see the agent as a connected device?
              # This catches the circuit-breaker deadlock: agent is alive and
              # metrics respond, but it can't upload to the server (CB open
              # with 700K+ failures). Restarting clears the in-memory CB.
              REALTIME=$(curl -sf --compressed -m 5 "$SERVER_HEALTH" 2>/dev/null \
                | jq -r '.realtime // empty' 2>/dev/null || echo "")
              if [ -n "$REALTIME" ] && echo "$REALTIME" | grep -q "connected (0 devices)"; then
                ZERO_DEVICE_RESTARTS=$(cat "$ZERO_DEVICE_STAMP" 2>/dev/null || echo 0)
                if ! echo "$ZERO_DEVICE_RESTARTS" | grep -qE '^[0-9]+$'; then ZERO_DEVICE_RESTARTS=0; fi
                if [ "$ZERO_DEVICE_RESTARTS" -ge "$ZERO_DEVICE_MAX" ]; then
                  echo "monitor365-agent-watchdog: server still reports 0 devices after $ZERO_DEVICE_RESTARTS restarts — NOT restarting again (restarts do not converge; fix device registration — see the agent's upload/device errors)"
                  exit 0
                fi
                ZERO_DEVICE_RESTARTS=$((ZERO_DEVICE_RESTARTS + 1))
                echo "$ZERO_DEVICE_RESTARTS" >"$ZERO_DEVICE_STAMP" 2>/dev/null || true
                echo "monitor365-agent-watchdog: server reports 0 devices — circuit breaker deadlock, restarting agent ($ZERO_DEVICE_RESTARTS/$ZERO_DEVICE_MAX)"
                systemctl restart monitor365.service || true
                exit 0
              fi

              # Devices are flowing again — clear the bounded counter so a
              # future transient deadlock still gets its full restart budget.
              rm -f "$ZERO_DEVICE_STAMP" 2>/dev/null || true
              echo "monitor365-agent-watchdog: agent healthy (process active, metrics responding, server connected)"
            '';
          };

          systemd.timers.monitor365-agent-watchdog = {
            description = "Periodic Monitor365 agent health check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = "5min";
            };
          };
        })

        # ── Server resilience: start-limit + CPUQuota + MemoryMax ──────
        # Same pattern as the agent: the upstream module doesn't set
        # StartLimitBurst/StartLimitIntervalSec or CPUQuota. The server
        # can enter a DuckDB pool deadlock where all background tasks fail
        # with "pool acquire failed" — the process stays alive (Restart=always
        # never triggers) but becomes functionally broken, burning ~1 core
        # on retry loops. The watchdog below detects and recovers from this.
        #
        # MemoryMax override: the upstream module sets 3G, but DuckDB needs
        # room for batch INSERT operations. Under I/O pressure (SLC cache
        # exhaustion), DuckDB's appender falls back to individual INSERTs
        # when it can't allocate enough working memory — a 100x slowdown
        # that cascades into buffer overflow and event drops. 4G gives
        # DuckDB's default 2GB PRAGMA memory_limit enough cgroup headroom
        # to avoid this fallback path.
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-server = {
            # 2026-10-23 lock-float migration: upstream server-module now
            # sets the typed top-level StartLimit* itself (1200s/5, with the
            # 150s-secret-retry rationale — systemd 261+ ignores them in
            # serviceConfig), so the SystemNix workaround values (600/5 +
            # serviceConfig mkForce-nulls) are gone; a plain duplicate here
            # made startLimitIntervalSec a conflicting-definition eval error.
            serviceConfig = lib.mkMerge [
              {
                CPUQuota = "200%"; # Cap at 2 cores — prevents retry-loop runaway
                # 2026-10-25 crash-loop class: schema init (CREATE INDEX
                # IF NOT EXISTS at boot) must be able to rebuild indexes
                # over the 25 GB events table, but the upstream default
                # DuckDB memory_limit is "2GB" (decimal 2e9 = 1.86 GiB —
                # the "1.8 GiB/1.8 GiB used" OOM). Raise it via env to 4GB
                # (config.rs reads MONITOR365_SERVER__MEMORY_LIMIT; the
                # value MUST match <digits>(KB|MB|GB|TB) — memory_limit.rs
                # silently rejects "4G"-style shapes and falls back to the
                # default) and keep cgroup headroom above it for process
                # overhead (was 3G/4G, sized for steady state only).
                Environment = [ "MONITOR365_SERVER__MEMORY_LIMIT=4GB" ];
                MemoryMax = lib.mkForce "8G";
                MemoryHigh = lib.mkForce "6G";
              }
              ioTier.heavyDB
            ];
          };
        })

        # Server health watchdog: detects DuckDB pool deadlock and other
        # degraded-but-alive states. The server's Restart=always only fires
        # when the process EXITS — a pool deadlock keeps the process running
        # (consuming ~1 core of CPU on retry loops) while every query fails.
        #
        # This watchdog performs two checks:
        #   1. /health endpoint returns 200 within 10s (catches process-level
        #      degradation, TCP backlog exhaustion from CPU saturation)
        #   2. Journal "pool acquire failed" error count in last 5 min > 20
        #      (catches DuckDB pool deadlock even when /health doesn't require
        #      a DB connection)
        #
        # Without this, a pool deadlock persisted for 14+ hours (2026-08-04
        # incident) because the process never exited and no health check
        # existed for the server (only the agent had a watchdog).
        (lib.mkIf serverCfg.enable {
          systemd.services.monitor365-server-watchdog = {
            description = "Monitor365 server health watchdog";
            after = [ "monitor365-server.service" ];
            serviceConfig = {
              Type = "oneshot";
              NoNewPrivileges = true;
              PrivateTmp = true;
            };
            path = [
              pkgs.systemd
              pkgs.curl
              pkgs.coreutils
            ];
            script = ''
              SERVER_HEALTH="http://localhost:${toString ports.monitor365-server}/health"

              # 1. Is the server process active?
              if ! systemctl is-active --quiet monitor365-server.service; then
                echo "monitor365-server-watchdog: server is NOT active — resetting start-limit and starting"
                systemctl reset-failed monitor365-server.service 2>/dev/null || true
                systemctl start monitor365-server.service || true
                exit 0
              fi

              # 2. Does /health return 200 within 10s?
              # Pool deadlock causes /health to return 500 or time out.
              # The 10s timeout matches the DuckDB pool acquire timeout.
              HTTP_CODE=$(curl -sf -m 10 -o /dev/null -w "%{http_code}" "$SERVER_HEALTH" 2>/dev/null || echo "000")
              if [ "$HTTP_CODE" != "200" ]; then
                echo "monitor365-server-watchdog: health check failed (HTTP $HTTP_CODE) — restarting server"
                systemctl restart monitor365-server.service || true
                exit 0
              fi

              # 3. DuckDB pool exhaustion detection via journal.
              # The /health endpoint might not require a DB connection, so it
              # can return 200 even when the pool is locked. This secondary
              # check counts "pool acquire failed" errors in the last 5 min.
              # Threshold: 21 errors/5min = ~4/min (one every ~15s). Normal
              # operation has zero. Pool deadlock generates 10+/min.
              #
              # Performance: --grep filters INSIDE journalctl (avoids serializing
              # + piping all entries through grep), and -n 21 caps the output so
              # journalctl stops reading once it finds 21 matches (early
              # termination in the error case). Without --grep, this command read
              # 270+ MB and burned 98% CPU every 5 minutes because it serialized
              # every journal entry through a pipe.
              POOL_ERRORS=$(journalctl --grep "pool acquire failed" -u monitor365-server.service --since "5 min ago" -n 21 --no-pager --output cat 2>/dev/null | wc -l)
              if [ "''${POOL_ERRORS:-0}" -ge 21 ]; then
                echo "monitor365-server-watchdog: >=21 pool acquire failures in last 5 min — DuckDB deadlock, restarting server"
                systemctl restart monitor365-server.service || true
                exit 0
              fi

              echo "monitor365-server-watchdog: server healthy (HTTP 200, ''${POOL_ERRORS:-0} pool errors in 5 min)"
            '';
          };

          systemd.timers.monitor365-server-watchdog = {
            description = "Periodic Monitor365 server health check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "3min";
              OnUnitActiveSec = "5min";
            };
          };
        })

        # Display discovery: the upstream module's start script uses pgrep to
        # find the displayUser's compositor PID, reads DISPLAY, WAYLAND_DISPLAY,
        # XAUTHORITY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS from
        # /proc/<pid>/environ, and exports them before exec. This is verified
        # working — the heredoc command-substitution correctly propagates exports
        # to the exec'd binary (the prior "subshell issue" diagnosis was wrong:
        # the real blockers were ProtectProc=invisible hiding niri's PID, now
        # fixed via mkForce "default", and the service starting before login).
        #
        # Graphical input collectors (keystroke, mouse) need /dev/input/event*
        # read access — the input group grants this. Camera needs the video group
        # for V4L2 device access.
        #
        # Timing: monitor365 starts at boot (default.target) before any graphical
        # session. Graphical collectors fail 3 times and are "permanently disabled"
        # for the process lifetime. A systemd path unit below restarts the agent
        # when the Wayland socket appears (user login), re-running display
        # discovery so collectors initialize correctly.
        (lib.mkIf (systemAgentCfg.enable && systemAgentCfg.displayUser != null) {
          systemd = {
            services.monitor365 = {
              serviceConfig.ProtectProc = lib.mkForce "default";
            };

            # Restart the agent when the user's Wayland session appears so
            # display discovery runs after login (the service starts at boot
            # before niri exists, leaving graphical collectors disabled until
            # restart). Uses uid 1000 — deterministic on evo-x2 (SDDM+niri,
            # primary user lars). Update if a multi-host deployment is added.
            #
            # PathChanged (not PathExists!) is CRITICAL: PathExists re-fires in
            # a tight loop during deploy — the file already exists, the service
            # exits 0, systemd re-evaluates the condition, fires again → 8
            # starts in 1 second → start-limit-hit on both the service AND the
            # path unit. PathChanged only fires when the file is CREATED or
            # MODIFIED, not when the path unit starts with the file already
            # present. During deploy (user logged in), the socket doesn't change
            # → no trigger. After boot (user logs in), the socket is created →
            # triggers once → agent restarts with display discovery.
            #
            # The oneshot script adds a 60s debounce to handle niri bouncing
            # the Wayland socket during DRM zombie recovery.
            paths.monitor365-graphical-restart = {
              description = "Restart Monitor365 agent when graphical session starts";
              wantedBy = [ "paths.target" ];
              pathConfig = {
                PathChanged = "/run/user/1000/wayland-1";
                Unit = "monitor365-graphical-restart.service";
              };
            };

            services.monitor365-graphical-restart = {
              description = "Restart Monitor365 agent after graphical session starts";
              serviceConfig = {
                Type = "oneshot";
              };
              script = ''
                # Skip if the service is not running (start-limit-hit, dead, etc.)
                if ! ${pkgs.systemd}/bin/systemctl is-active --quiet monitor365.service; then
                  echo "monitor365-graphical-restart: agent not active, skipping restart (watchdog will recover)"
                  exit 0
                fi

                # Skip if the agent was started less than 60s ago (debounce:
                # prevents rapid-restart storm during niri Wayland socket bounce)
                AGENT_UPTIME=$(${pkgs.systemd}/bin/systemctl show -p ActiveEnterTimestamp --value monitor365.service 2>/dev/null) || true || true
                if [ -n "$AGENT_UPTIME" ]; then
                  NOW=$(${pkgs.coreutils}/bin/date +%s)
                  STARTED=$(${pkgs.coreutils}/bin/date -d "$AGENT_UPTIME" +%s 2>/dev/null || echo 0)
                  if [ "$STARTED" -gt 0 ]; then
                    ELAPSED=$((NOW - STARTED))
                    if [ "$ELAPSED" -lt 60 ]; then
                      echo "monitor365-graphical-restart: agent started ''${ELAPSED}s ago, skipping (debounce <60s)"
                      exit 0
                    fi
                  fi
                fi

                echo "monitor365-graphical-restart: restarting agent for display discovery"
                ${pkgs.systemd}/bin/systemctl restart monitor365.service
              '';
            };
          };

          # Grant device access for graphical input + camera collectors.
          users.users.monitor365.extraGroups = [
            "input" # keystroke + mouse (/dev/input/event*)
            "video" # camera (V4L2 /dev/video*)
          ];
        })

        # Service-integration registry entries: the agent/server Gatus
        # checks, the server backup-freshness row, system-health monitoring
        # of both units, and the Monitor365 tile. The monitor vHost STAYS
        # hand-written in caddy.nix (SSO-conditional @noCache custom
        # block — beyond the registry's plain/protected seam). Replaces
        # rows in gatus-config.nix / homepage.nix / configuration.nix.
        (lib.optionalAttrs (options ? services.integration) {
          services.integration = {
            monitor365 = {
              inherit (systemAgentCfg) enable;
              vHost.layer = "none";
              monitored = true;
              checks = [
                {
                  name = "Monitor365 System Agent";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.monitor365-metrics}/metrics";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*collector_events_collected*)"
                  ];
                  alert = "Monitor365 system agent down — headless device telemetry collector not running";
                }
                {
                  name = "Monitor365 Cloud Sync Health";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.monitor365-metrics}/metrics";
                  interval = "2m";
                  # Gatus 5.36.0 cannot do numeric comparison on Prometheus text
                  # metrics ([BODY].jsonpath is broken, pat() is presence-only).
                  # We verify the sync subsystem is ACTIVE by checking both the
                  # backlog gauge and the consecutive-failures gauge exist.
                  # NOTE: cloud_sync_consecutive_failures is always emitted (set
                  # on every sync cycle: 0 on success, incremented on failure).
                  # The previous condition used cloud_sync_upload_rejected_events_total
                  # which is only emitted when rejections > 0, so it's ABSENT when
                  # the agent has zero rejections — a permanent false negative.
                  # This check catches the agent STOPPING sync entirely (circuit
                  # breaker stuck open, crash loop, auth failure). For VALUE-based
                  # alerting (backlog > N threshold), wire Prometheus/SigNoz
                  # to scrape this endpoint and add an alert rule there.
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*cloud_sync_upload_backlog_size*)"
                    "[BODY] == pat(*cloud_sync_consecutive_failures*)"
                  ];
                  alert = "Monitor365 cloud sync subsystem not emitting metrics — agent may have stopped syncing (circuit breaker open, auth failure, or crash loop). Check: journalctl -u monitor365 -n 50";
                }
              ];
            };
            monitor365-server = {
              inherit (serverCfg) enable;
              subdomain = "monitor";
              port = ports.monitor365-server;
              # Custom vHost (SSO-conditional @noCache headers) stays
              # hand-written in caddy.nix — registry layer "none" keeps the
              # DNS record + tile href while caddy owns the proxy.
              vHost.layer = "none";
              monitored = true;
              backup = {
                # Only meaningful while the server runs — a disabled service
                # must not fire permanent stale-backup alerts (entry enable
                # gates the fan-out, same as the old configuration.nix
                # optionalAttrs row).
                directory = "/var/lib/monitor365-server";
                filePattern = "*.backup_*.db";
                maxAgeHours = 25;
              };
              checks = [
                {
                  name = "Monitor365 Server";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.monitor365-server}/health";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 500"
                  ];
                  alert = "Monitor365 server down — device telemetry unavailable";
                }
                {
                  name = "Monitor365 Bootstrap";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.monitor365-server}/health/bootstrap";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY].bootstrapped == true"
                  ];
                  alert = "Monitor365 bootstrap incomplete — tenant/SSO provisioning may have failed on first boot";
                }
                {
                  name = "Monitor365 UI";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.monitor365-server}/ui/";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*<html*)"
                  ];
                  alert = "Monitor365 UI not serving — WASM dashboard missing";
                }
                {
                  name = "Monitor365 External";
                  group = "Monitoring";
                  url = "https://monitor.${domain}/health";
                  interval = "2m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                  ];
                  alert = "Monitor365 external endpoint down — reverse proxy or TLS issue";
                }
                {
                  name = "Monitor365 Agent Connected";
                  group = "Monitoring";
                  url = "http://localhost:${toString ports.monitor365-server}/health";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    # Gatus 5.36.0's [BODY].jsonpath is broken — use pat() instead.
                    # Match "connected (N devices)" where N >= 1. The [1-9] character
                    # class ensures at least one digit from 1-9 (excludes 0 devices).
                    # NOTE: Gatus pat() uses glob, NOT regex — do NOT prefix with ?
                    # (glob ? = single-char wildcard, which would consume the digit).
                    "[BODY] == pat(*connected ([1-9]* devices)*)"
                  ];
                  alert = "Monitor365 agent not connected to server — API key desync or agent crash";
                }
              ];
              oidc = {
                # Native OIDC via Monitor365's built-in SSO support.
                # PKCE (S256) is required by Monitor365's authorize flow.
                name = "Monitor365";
                clientId = "monitor365";
                launchURL = "https://monitor.${domain}";
                callbackURLs = [ "https://monitor.${domain}/v1/auth/sso/callback" ];
                pkceEnabled = true;
              };
              homepage = {
                name = "Monitor365";
                group = "Monitoring";
                description = "Device Monitoring Agent";
                icon = "uptime-kuma.png";
              };
            };
          };
        })
      ];
    };
}
