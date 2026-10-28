# Runbook: docs/services/bank-sync.md
# bank-sync — SystemNix deployment overlay for the bank-sync service
#
# Upstream module (inputs.bank-sync.nixosModules.default, imported in
# systems/evo-x2.nix like the crush-daily wiring) declares services.bank-sync
# options + the systemd unit. SystemNix adds the house wiring:
#
#   - Dashboard binds 127.0.0.1:<ports.bank-sync> — Caddy vHost
#     banksync.<domain> (protectedVHost: LAN bypass + external forward-auth)
#     is the sole external entry point
#   - SQLite database on the mirrored HDD pool (/mnt/pool/services/bank-sync,
#     btrbk-pool snapshotted) instead of the QLC NVMe — same placement
#     decision as atticd (2026-08-18)
#   - Wise API key + AES-256 event encryption key from the sops template
#     "bank-sync-env" (see sops.nix)
#   - Optional Wise SCA one-time-token drop-in (EnvironmentFile "-"-prefixed,
#     absent by default — see docs/services/bank-sync-sca.md for the 90-day
#     renewal runbook)
#   - Pool-gated storage-dir oneshot + house hardening (harden {},
#     serviceDefaults, onFailure, start limits, background I/O tier)
{ inputs, ... }: {
  flake.nixosModules.bank-sync =
    {
      config,
      options,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.bank-sync;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ports
        ioTier
        mkSecretCheck
        ;
      envTemplate = config.sops.templates."bank-sync-env";
      # The paperless module is optional at eval scope (only evo-x2 + the
      # eval test carry it). nixpkgs assigns services.paperless.manage
      # (readOnly) ONLY when the service is enabled, so everything touching
      # it — the mint unit and the archival units it feeds — gates on the
      # same condition; the assertion below keeps the misconfig loud.
      paperlessPresent = options ? services.paperless;
      paperlessEnabled = paperlessPresent && config.services.paperless.enable;
      # Idempotent DRF token mint for the archival oneshot. drf_create_token
      # is get_or_create (rest_framework/authtoken management command): the
      # SAME admin token comes back on every run, so the unit is convergent
      # and safe to re-run before every archival start. The token exists
      # only in tmpfs (/run — RAM-backed, gone at reboot, never on disk);
      # this replaces the old paste-the-token-into-sops go-live, which is
      # why paperless archival can now be enabled with zero manual steps.
      # Inline `script` (not writeShellScript) so the eval regression test
      # can assert on the command content without IFD.
      # The mint runs as the paperless user (drf_create_token needs the
      # peer-auth PostgreSQL socket identity); the consumer unit runs as
      # bank-sync, so a root ExecStartPost ("+" prefix) hands the file over.
      mintChownScript = pkgs.writeShellScript "bank-sync-paperless-token-chown" ''
        chown bank-sync:bank-sync /run/bank-sync-paperless/env
        chmod 0400 /run/bank-sync-paperless/env
      '';
      # House policy: this deployment always encrypts events at rest. An
      # empty/missing sops key would silently downgrade bank-sync to
      # UNENCRYPTED (it treats an empty env var as "no key") — fail the unit
      # instead. A missing YAML key leaves the {{ marker unreplaced, which
      # bank-sync then rejects loudly at base64 decode; this check catches
      # the remaining silent case (key present but empty).
      checkEncryptionKey = mkSecretCheck pkgs {
        name = "bank-sync-encryption-key";
        secretPath = envTemplate.path;
        message = ''
          bank-sync: BANK_SYNC_SECURITY_ENCRYPTION_KEY is missing or empty in ${envTemplate.path}
            Re-create platforms/nixos/secrets/bank-sync-encryption.yaml (sops-encrypt a 32-byte base64 key to the host age public key in .sops.yaml), then redeploy.'';
        extraCheck = ''
          ${pkgs.gnugrep}/bin/grep -qE '^BANK_SYNC_SECURITY_ENCRYPTION_KEY=..' "$secret_path"
        '';
      };
      # Frozen Qonto CSV statement exports (pre-Wise era, 2022-12 →
      # 2023-05) in the bank-sync repo checkout on this host. The checkout
      # lives under DAC-private /home/lars, so service users can never read
      # it directly (the 2026-10-19 first-deploy lesson: ProtectHome=false
      # lifts only the sandbox layer, not file permissions) — the root
      # bank-sync-qonto-stage oneshot COPIES them into the dataDir below
      # and every consumer reads the staged copies. ConditionPathExists on
      # the SOURCES turns an absent checkout into a silent skip, never a
      # boot failure.
      qontoCsvTech = "/home/lars/projects/bank-sync/data/historical/qonto/transactions/technologies_gmbh.csv";
      qontoCsvHolding = "/home/lars/projects/bank-sync/data/historical/qonto/transactions/holding_gmbh.csv";
      # Full-history corpus (owner's Drive exports, 2025-02-24): OFX-converted
      # Qonto CSVs (Tech 2023-01-04→2025-02-24 x963, Holding
      # 2022-12-07→2025-02-05 x117; the 132 fragment rows above are bridged
      # onto their original UUIDs inside these files, so the idempotent
      # import skips them) + the 40 monthly statement PDFs the archival unit
      # uploads to Paperless (source of truth: repo commit 0ccc3a9b).
      qontoCsvTechFull = "/home/lars/projects/bank-sync/data/historical/qonto/transactions/technologies_gmbh_full_2025-02-24.csv";
      qontoCsvHoldingFull = "/home/lars/projects/bank-sync/data/historical/qonto/transactions/holding_gmbh_full_2025-02-24.csv";
      qontoStatementsSrc = "/home/lars/projects/bank-sync/data/historical/qonto/statements";
      # Staged copies (bank-sync-readable, btrbk-pool snapshotted with the
      # DB). The stage unit converges them on every activation/boot.
      qontoStageTech = "${cfg.dataDir}/qonto-import/technologies_gmbh.csv";
      qontoStageHolding = "${cfg.dataDir}/qonto-import/holding_gmbh.csv";
      qontoStageTechFull = "${cfg.dataDir}/qonto-import/technologies_gmbh_full_2025-02-24.csv";
      qontoStageHoldingFull = "${cfg.dataDir}/qonto-import/holding_gmbh_full_2025-02-24.csv";
      qontoStageStatements = "${cfg.dataDir}/qonto-import/statements";
    in
    {
      options.services.bank-sync.paperlessArchive = {
        enable = lib.mkEnableOption "weekly Paperless-ngx archival (statements + receipts)";

        timerCalendar = lib.mkOption {
          type = lib.types.str;
          default = "Sun *-*-* 03:00:00";
          description = ''
            systemd calendar for the archival timer. Default lands after the
            canary's Sunday 00:00 + 1h jitter window so the tripwire runs
            first and archival never alerts for an outage the canary already
            caught.
          '';
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          services.bank-sync = {
            # Caddy is the sole external entry point (defense-in-depth: the raw
            # HTTP server stays unreachable even if a firewall rule appears).
            addr = "127.0.0.1:${toString ports.bank-sync}";

            # SQLite on the mirrored HDD pool, snapshotted nightly by btrbk-pool.
            dataDir = lib.mkDefault "/mnt/pool/services/bank-sync";

            # sops template renders BANK_SYNC_WISE_API_KEY=... and
            # BANK_SYNC_SECURITY_ENCRYPTION_KEY=... (KEY=VALUE env file).
            wiseApiKeyFile = config.sops.templates."bank-sync-env".path;
            encryptionKeyFile = config.sops.templates."bank-sync-env".path;

            # Explicit package pin: SystemNix's nixpkgs carries no bank-sync
            # attr, so the module's mkPackageOption default cannot resolve.
            # vendorHash shim DROPPED 2026-10-07: upstream 4890be63's
            # flake.nix:424 declared exactly the got-hash (ax8CYIwS…) our
            # nixpkgs-followed graph computes — upstream ran the dance
            # themselves. SAME-DAY RECURRENCE: 728e719a bumped go.mod/go.sum
            # without redoing it and broke the deploy again; the fresh got
            # rd4R+EG5… was pasted UPSTREAM (ab2c9dcd, DiscordSync protocol).
            # The upstream-owned hash re-stales on every upstream source
            # touch — re-probe first, never re-pin blindly. Re-add a shim
            # only with a fresh first-hand got-hash (never invented) and
            # mirror it at the HM surface (systems/evo-x2.nix
            # programs.bank-sync) or the two surfaces build different drvs.
            package = lib.mkDefault inputs.bank-sync.packages.${pkgs.stdenv.hostPlatform.system}.default;
          };

          # The pool mounts nofail — systemd-tmpfiles could create the dir on the
          # ROOT filesystem under the /mnt/pool mountpoint before the pool is up
          # (contaminating the NVMe). This oneshot runs only while the pool is
          # actually mounted (RequiresMountsFor fails loudly on a detached DAS) and
          # creates the directory with the service-user ownership the upstream
          # module expects (createHome is deliberately false upstream).
          systemd.services.bank-sync-storage-dir = {
            description = "Create bank-sync data directory on the HDD pool";
            wantedBy = [ "multi-user.target" ];
            unitConfig.RequiresMountsFor = [ cfg.dataDir ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                RemainAfterExit = true;
              }
              (harden {
                # subvolume create needs CAP_SYS_ADMIN, chown CAP_CHOWN; chmod
                # AFTER chown (and on every re-run) targets a dir owned by
                # bank-sync, which requires CAP_FOWNER; harden{} defaults to an
                # empty bounding set which would EPERM all of them. Write access
                # to the PARENT is required to create the subvolume
                # (mkdir/chown/chmod on the dir itself is covered).
                CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
                ReadWritePaths = [ (dirOf cfg.dataDir) ];
              })
              (serviceOneshotDefaults { })
            ];
            script = ''
              dir=${toString cfg.dataDir}
              if [ ! -e "$dir" ]; then
                # Subvolume (not plain dir) so btrbk-pool can snapshot it —
                # mirrors the atticd pool placement. Falls back to a plain dir
                # only on non-btrfs filesystems.
                if ! ${pkgs.btrfs-progs}/bin/btrfs subvolume create "$dir"; then
                  mkdir -p "$dir"
                fi
              else
                mkdir -p "$dir"
              fi
              # chmod while root still owns a freshly created subvolume, chown
              # last — re-runs (dir already bank-sync-owned) rely on CAP_FOWNER
              # for the chmod, see the bounding set above.
              chmod 0750 "$dir"
              chown bank-sync:bank-sync "$dir"
            '';
          };

          # ONE-TIME fresh-start migration (2026-10-16, owner-ratified). The
          # 2026-10-14 hard pin (bank-sync 67dd64526) existed because any
          # post-re-pin binary crash-loops against the prod journal: the
          # go-cqrs-lite d15e0a48 key rendering addresses the existing
          # journal/snapshots under keys matching zero rows → exit-65
          # journal_snapshot_divergence (docs/services/bank-sync.md RE-FLOAT
          # gotcha). Instead of waiting on upstream key compatibility, the
          # cutover moves the prod dataDir aside ONCE so the floated binary
          # boots on an empty journal under the new key basis — all history is
          # Wise-derived and re-fetches via the full-history backfill after
          # the SCA re-approval. The archive dir IS the marker: re-runs and
          # every later boot no-op. Nothing is deleted (the archive keeps its
          # pre-move btrbk snapshots; the frozen subvolume drops out of
          # snapshots.nix, see docs/services/bank-sync.md). Same-FS rename is
          # atomic; the switch stops bank-sync before the start phase, and
          # Before= orders this ahead of both the daemon and storage-dir, so
          # the fresh subvolume is created only after the old one is moved.
          systemd.services.bank-sync-fresh-start = {
            description = "One-time bank-sync dataDir fresh-start migration (2026-10-16 key-basis cutover)";
            wantedBy = [ "multi-user.target" ];
            before = [
              "bank-sync.service"
              "bank-sync-storage-dir.service"
            ];
            unitConfig.RequiresMountsFor = [ cfg.dataDir ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                RemainAfterExit = true;
              }
              (harden {
                # Rename on the pool needs write access to the parent; root
                # bypasses DAC only with the override capability (storage-dir
                # precedent). No chown/chmod here — rename preserves the
                # subvolume and its ownership untouched.
                CapabilityBoundingSet = "CAP_DAC_OVERRIDE";
                ReadWritePaths = [ (dirOf cfg.dataDir) ];
              })
              (serviceOneshotDefaults { })
            ];
            script = ''
              data="${toString cfg.dataDir}"
              archive="''${data}-pre-keybump-20261016"
              if [ -e "$archive" ]; then
                echo "bank-sync-fresh-start: $archive already present — migration already done, no-op"
                exit 0
              fi
              if [ ! -e "$data" ]; then
                echo "bank-sync-fresh-start: no $data (fresh host) — nothing to move"
                exit 0
              fi
              ${pkgs.coreutils}/bin/mv "$data" "$archive"
              echo "bank-sync-fresh-start: moved $data -> $archive (old journal preserved; history re-fetches from Wise via full-history backfill after SCA re-approval)"
            '';
          };

          systemd.services.bank-sync = {
            after = [ "bank-sync-storage-dir.service" ];
            wants = [ "bank-sync-storage-dir.service" ];
            # docs/agents/integration-registry.md step 5: every service sets start-limit bounds + onFailure.
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            inherit onFailure;
            # OTel traces → local SigNoz collector (Go otlptracehttp: bare
            # host:port, no scheme). Upstream gained OTLP exporter support
            # 2026-08-31 (cmd/bank-sync/tracing.go, DiscordSync pattern); with
            # older pinned revs this is a harmless noop until the flake bump.
            # Enforced by services.signoz-coverage (wiring "upstream" → "env"
            # after the input bump lands spans).
            environment.OTEL_EXPORTER_OTLP_ENDPOINT = "localhost:${toString ports.signoz-otlp-http}";
            serviceConfig = lib.mkMerge [
              {
                ExecStartPre = [ (lib.getExe checkEncryptionKey) ];
                # Wise Strong Customer Authentication (SCA) one-time token (OTT).
                # Wise gates SCA-protected endpoints (balance statements for
                # UK/EEA profiles) behind a 403 challenge roughly every 90 days;
                # approval happens in the Wise app and the OTT is single-use, so
                # it must never live in sops or the nix store. The leading "-"
                # makes the absent file a no-op; systemd reads EnvironmentFile
                # as PID 1, so the drop-in can be root-owned 0400. mkMerge
                # appends to upstream's EnvironmentFile list.
                EnvironmentFile = [ "-/var/lib/bank-sync-sca/token.env" ];
              }
              (harden {
                MemoryMax = "512M";
              })
              (serviceDefaults { })
              # SQLite on spinning rust, synced every 15m — never compete with
              # the desktop for I/O.
              ioTier.background
            ];
          };

          # Weekly live-API canary (landed 2026-09-12, bank-sync master-plan
          # T8): read-only smoke of every configured non-demo provider against
          # the real Wise API. The 12-week SCA silence (2026-06→09) was
          # invisible precisely because no independent tripwire ran; this timer
          # is that tripwire. Fails closed — OnFailure routes to the house
          # notifier; the JSON report lands next to the DB for post-mortems.
          systemd.services.bank-sync-canary = {
            description = "Bank-Sync weekly provider canary";
            after = [
              "network-online.target"
              "bank-sync-storage-dir.service"
            ];
            wants = [
              "network-online.target"
              "bank-sync-storage-dir.service"
            ];
            # StandardOutput appends into the pool dataDir — gate on the mount
            # (mount-gating-audit class; a detached DAS must FAIL loudly, not
            # append the report onto a root-fs shadow dir).
            unitConfig.RequiresMountsFor = [ cfg.dataDir ];
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "bank-sync";
                Group = "bank-sync";
                # lib.getExe already yields <pkg>/bin/bank-sync — no /bin
                # concatenation (the 2026-08-29 draft's ExecStart bug).
                ExecStart = "${lib.getExe cfg.package} canary --provider all --json";
                # Same secret env as the daemon (Wise key; the encryption key
                # rides along harmlessly) plus the optional SCA OTT drop-in so
                # a pending approval clears the canary exactly like the daemon.
                EnvironmentFile = [
                  envTemplate.path
                  "-/var/lib/bank-sync-sca/token.env"
                ];
                # Post-mortem report next to the DB (bank-sync-owned dataDir;
                # weekly JSON lines, btrbk-pool snapshots it with the DB).
                StandardOutput = "append:${cfg.dataDir}/canary-last.json";
              }
              (harden {
                # Read-only against the system except the report's directory.
                ReadWritePaths = [ cfg.dataDir ];
              })
              (serviceOneshotDefaults { })
            ];
          };

          systemd.timers.bank-sync-canary = {
            description = "Bank-Sync weekly provider canary timer";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "weekly";
              # Catch up when the box was off; jitter avoids a fixed weekly
              # thunder minute.
              Persistent = true;
              RandomizedDelaySec = "1h";
            };
          };

          # Rev-drift tripwire: the RUNNING bank-sync binary must be the one
          # this generation declares. A unit that survives a switch without a
          # restart (failed restart, manual start from an old generation,
          # GC'd store path surfacing as '(deleted)') keeps serving stale
          # code while every config surface claims the new rev. ExecStart
          # embeds the store path, so a package bump normally restarts the
          # unit — this hourly /proc/<MainPID>/exe comparison is the
          # belt-and-suspenders that catches every path around that.
          # Runs as root: reading another unit's /proc/PID/exe needs it
          # (harden{} deliberately sets no Proc* keys, see lib/systemd docs).
          # Ordering only (never `wants`): a tripwire must not start the
          # service it monitors.
          systemd.services.bank-sync-rev-drift = {
            description = "Bank-Sync running-binary rev-drift tripwire";
            after = [ "bank-sync.service" ];
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
              }
              # CAP_SYS_PTRACE (2026-10-08): reading /proc/<pid>/exe of a
              # foreign-uid process (bank-sync runs as its own user) needs it;
              # the empty default CapabilityBoundingSet strips it from root,
              # readlink dies EACCES, and NixOS's implicit `set -e` in the
              # script wrapper then killed the unit BEFORE any diagnostic echo
              # — 40/40 silent false-positive failures since go-live (the
              # nix-build-cleanup CAP_DAC_OVERRIDE class).
              (harden { CapabilityBoundingSet = "CAP_SYS_PTRACE"; })
              (serviceOneshotDefaults { })
            ];
            script = ''
              expected="${lib.getExe cfg.package}"
              main_pid="$(${pkgs.systemd}/bin/systemctl show -p MainPID --value bank-sync.service)"
              if [ -z "$main_pid" ] || [ "$main_pid" = "0" ]; then
                echo "bank-sync-rev-drift: bank-sync.service has no MainPID (daemon down — the liveness check owns that alarm, failing here too so the state is never silent)" >&2
                exit 1
              fi
              # `|| true`: NixOS script wrappers run under `set -e` — a failed
              # readlink (EACCES/EPERM) must surface as the loud mismatch
              # report below, never a silent pre-echo death.
              running="$(${pkgs.coreutils}/bin/readlink "/proc/$main_pid/exe" || true)"
              if [ "$running" != "$expected" ]; then
                echo "bank-sync-rev-drift: running binary does not match the deployed generation." >&2
                echo "  running : $running" >&2
                echo "  expected: $expected" >&2
                echo "  The unit survived a generation switch without restarting onto the new binary. Re-run 'nix run .#deploy' and confirm bank-sync.service restarts; if it already did, find why the old binary is still live." >&2
                exit 1
              fi
              echo "bank-sync-rev-drift: OK ($running)"
            '';
          };

          systemd.timers.bank-sync-rev-drift = {
            description = "Bank-Sync rev-drift tripwire timer";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "hourly";
              # Catch up when the box was off; jitter avoids a fixed thunder
              # minute shared with other hourly units.
              Persistent = true;
              RandomizedDelaySec = "5m";
            };
          };

          assertions = lib.optionals paperlessPresent [
            {
              assertion = !cfg.paperlessArchive.enable || config.services.paperless.enable;
              message = "bank-sync paperlessArchive.enable requires services.paperless.enable: the archival token mint (bank-sync-paperless-token) runs drf_create_token against the paperless DB";
            }
          ];

          # Weekly Paperless-ngx archival (statements + transfer receipts).
          # Zero-secret go-live: the API token is minted at archival time by
          # the bank-sync-paperless-token oneshot (idempotent drf_create_token,
          # tmpfs-only storage), the URL derives from lib/ports.nix — nothing
          # is pasted into sops, so enabling the flag is the ONLY step. The
          # oneshot shares the daemon's DB and Wise key but NEVER restarts
          # the daemon: idempotent ledgers make concurrent runs safe, and a
          # failed archival run must not perturb continuous sync.
          systemd.services.bank-sync-paperless-token =
            lib.mkIf (cfg.paperlessArchive.enable && paperlessEnabled)
              {
                description = "Bank-Sync Paperless archival - API token mint";
                after = [
                  "network-online.target"
                  "postgresql.service"
                ];
                wants = [
                  "network-online.target"
                  "postgresql.service"
                ];
                inherit onFailure;
                startLimitBurst = 5;
                startLimitIntervalSec = 300;
                unitConfig.RequiresMountsFor = [ config.services.paperless.dataDir ];
                path = [
                  pkgs.coreutils
                  pkgs.gnugrep
                ];
                script = ''
                  MINT_OUT=/run/bank-sync-paperless/env
                  umask 077
                  # Unlink the previous run's env file FIRST: the root
                  # ExecStartPost hands it to bank-sync (0400 bank-sync),
                  # and opening a foreign-owned 0400 file for truncation
                  # EPERMs as the paperless user — the 2026-10-19 02:50
                  # second-run failure (the Oct 18 first run minted clean,
                  # every later run died). Unlink needs only directory
                  # write, and paperless owns the 0711 RuntimeDirectory.
                  rm -f "$MINT_OUT"
                  token="$(${config.services.paperless.manage}/bin/paperless-manage drf_create_token admin)"
                  hex="$(printf '%s\n' "$token" | grep -oE '[0-9a-f]{40}' | head -n1)"
                  if [ -z "$hex" ]; then
                    echo "bank-sync-paperless-token: token extraction failed (unexpected drf_create_token output)" >&2
                    exit 1
                  fi
                  printf 'BANK_SYNC_PAPERLESS_TOKEN=%s\n' "$hex" > "$MINT_OUT"
                '';
                serviceConfig = lib.mkMerge [
                  {
                    Type = "oneshot";
                    # Django system checks write a probe file into the dataDir
                    # (paperless checks.py, 2026-09-16 EROFS lesson in
                    # paperless.nix) — paperless-user identity + write access.
                    User = config.services.paperless.user;
                    ReadWritePaths = [ config.services.paperless.dataDir ];
                    RuntimeDirectory = "bank-sync-paperless";
                    # 0711: bank-sync must traverse to its 0400 env file.
                    RuntimeDirectoryMode = "0711";
                    # Default (no) would DELETE the dir when this oneshot
                    # deactivates — before the archival unit ever reads its
                    # EnvironmentFile. tmpfs semantics are untouched: /run is
                    # RAM-backed and cleared at reboot.
                    RuntimeDirectoryPreserve = true;
                    TimeoutStartSec = "3min";
                    ExecStartPost = "+${mintChownScript}";
                  }
                  (harden { ProtectSystem = "strict"; })
                  (serviceOneshotDefaults { })
                ];
              };

          systemd.services.bank-sync-paperless =
            lib.mkIf (config.services.bank-sync.paperlessArchive.enable && paperlessEnabled)
              {
                description = "Bank-Sync weekly Paperless-ngx archival";
                after = [
                  "network-online.target"
                  "bank-sync-storage-dir.service"
                  "bank-sync-paperless-token.service"
                ];
                wants = [
                  "network-online.target"
                  "bank-sync-storage-dir.service"
                ];
                requires = [ "bank-sync-paperless-token.service" ];
                # The run opens and WRITES the SQLite DB (ledger rows) — fail
                # loudly on a detached pool instead of touching the root fs.
                unitConfig.RequiresMountsFor = [ cfg.dataDir ];
                inherit onFailure;
                startLimitBurst = 5;
                startLimitIntervalSec = 300;
                serviceConfig = lib.mkMerge [
                  {
                    Type = "oneshot";
                    User = "bank-sync";
                    Group = "bank-sync";
                    ExecStart = "${lib.getExe cfg.package} paperless --receipts";
                    Environment = [
                      "BANK_SYNC_DATABASE_PATH=${cfg.dataDir}/data.db"
                      "BANK_SYNC_PAPERLESS_URL=http://127.0.0.1:${toString ports.paperless}"
                    ];
                    # Wise key + encryption key from the daemon env, the archive
                    # token from the runtime-minted tmpfs env file, optional SCA
                    # OTT drop-in (statements ride the same challenge flow).
                    EnvironmentFile = [
                      envTemplate.path
                      "/run/bank-sync-paperless/env"
                      "-/var/lib/bank-sync-sca/token.env"
                    ];
                  }
                  (harden {
                    # Ledger writes land next to the DB.
                    ReadWritePaths = [ cfg.dataDir ];
                  })
                  (serviceOneshotDefaults { })
                ];
              };

          systemd.timers.bank-sync-paperless =
            lib.mkIf (config.services.bank-sync.paperlessArchive.enable && paperlessEnabled)
              {
                description = "Bank-Sync weekly Paperless-ngx archival timer";
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = cfg.paperlessArchive.timerCalendar;
                  # Catch up when the box was off.
                  Persistent = true;
                  RandomizedDelaySec = "30m";
                };
              };

          # ── Qonto historical statements: import + Paperless archival ──
          #
          # The pre-Wise era lives as Qonto CSV exports in the bank-sync
          # repo checkout (data/historical/qonto/transactions/, frozen
          # 2022-12 → 2023-05 exports). Two convergent oneshots make the
          # live deployment serve them:
          #
          #   1. bank-sync-qonto-import: `bank-sync import` (idempotent —
          #      deterministic FNV-1a transaction IDs, stable derived
          #      profile/balance IDs; re-runs skip already-known rows) into
          #      the daemon's real data.db. EXPLICIT BANK_SYNC_DATABASE_PATH
          #      — the 2026-10-17 side-DB trap (a bare CLI run minted a
          #      bank-sync.db twin next to data.db). Safe while the daemon
          #      runs: SQLite WAL serializes writers, the import process's
          #      own projection host applies the read tables the daemon
          #      queries, and qonto streams are never touched by the Wise
          #      sync (no aggregate conflicts). The trailing junk row in
          #      the technologies export (line 106, date-only, no amount)
          #      is skipped with errors=1 in the log — the source file is
          #      a frozen export and stays untouched.
          #   2. bank-sync-qonto-paperless: uploads BOTH statement CSVs to
          #      Paperless-ngx with canonical metadata (correspondent
          #      Qonto, type Bank Statement, tags bank-sync+qonto, created
          #      = period end). Marker-gated in the dataDir; Paperless's
          #      checksum dedup absorbs any re-upload after a partial
          #      failure. Reuses the archival pair's runtime-minted token.
          #
          # Qonto ATTACHMENT receipts (paperless --provider qonto
          # --receipts) need Qonto Business API credentials that do not
          # exist yet — see docs/services/bank-sync.md §Qonto.
          #
          # The CSV paths reference the owner's repo checkout on this
          # host (see the let bindings above): ConditionPathExists turns a
          # moved/absent checkout into a silent skip (fresh hosts,
          # relocated repos), never a boot failure.
          # Root stage-copy: /home/lars is DAC-private, so the bank-sync
          # user cannot traverse to the repo checkout regardless of the
          # unit sandbox (live lesson 2026-10-19 02:51, first deploy:
          # import.open_file permission denied). Root reads the sources and
          # converges bank-sync-owned 0640 copies into the dataDir; every
          # consumer below reads the staged paths. Convergent on re-run;
          # never deletes; sources stay untouched.
          systemd.services.bank-sync-qonto-stage = {
            description = "Bank-Sync Qonto CSV stage-copy into the dataDir (root, convergent)";
            wantedBy = [ "multi-user.target" ];
            before = [
              "bank-sync-qonto-import.service"
              "bank-sync-qonto-paperless.service"
            ];
            after = [ "bank-sync-storage-dir.service" ];
            wants = [ "bank-sync-storage-dir.service" ];
            unitConfig = {
              RequiresMountsFor = [ cfg.dataDir ]
              # ~/projects READER (2026-10-28 projects-subvol plan D6): the
              # historical Qonto sources live under ~/projects — without this
              # gate, a detached Samsung makes the stage unit read the STALE
              # @ shadow copies (ConditionPathExists still passes on the
              # shadow dir) and silently stage old CSVs. Conditional on the
              # mount being declared (VM/test hosts unaffected).
              ++ lib.optionals (builtins.hasAttr "/home/lars/projects" config.fileSystems) [ "/home/lars/projects" ];
              ConditionPathExists = [
                qontoCsvTech
                qontoCsvHolding
                qontoCsvTechFull
                qontoCsvHoldingFull
                "${qontoStatementsSrc}/artmann-holding-gmbh"
                "${qontoStatementsSrc}/artmann-technologies-gmbh"
              ];
            };
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            path = [
              pkgs.coreutils
              pkgs.findutils
            ];
            script = ''
              install -D -m 0640 -o bank-sync -g bank-sync "${qontoCsvTech}" "${qontoStageTech}"
              install -D -m 0640 -o bank-sync -g bank-sync "${qontoCsvHolding}" "${qontoStageHolding}"
              install -D -m 0640 -o bank-sync -g bank-sync "${qontoCsvTechFull}" "${qontoStageTechFull}"
              install -D -m 0640 -o bank-sync -g bank-sync "${qontoCsvHoldingFull}" "${qontoStageHoldingFull}"
              # Statement PDFs: preserve the <org>/<year>/ tree — the
              # archival unit derives org + statement month from the path
              # and the YYYY-MM filename prefix.
              # NUL-delimited find -print0 loop: the usual -d with an empty
              # argument cannot be spelled inside a Nix indented string (the
              # empty-string delimiter syntax is two single quotes, which is
              # the Nix escape prefix), so use the ANSI-C NUL form instead.
              while IFS= read -r -d $'\0' src; do
                rel="${qontoStatementsSrc}/"
                install -D -m 0640 -o bank-sync -g bank-sync "$src" "${qontoStageStatements}/''${src#$rel}"
              done < <(find "${qontoStatementsSrc}" -type f -name '*.pdf' -print0)
              staged=$(find "${qontoStageStatements}" -type f | wc -l)
              echo "bank-sync-qonto-stage: staged 4 Qonto CSVs + $staged statement PDFs into ${cfg.dataDir}/qonto-import/"
            '';
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                TimeoutStartSec = "2min";
              }
              (harden {
                # Root must traverse the private /home/lars to read the
                # sources and needs chown/chmod on the staged files
                # (storage-dir capability precedent).
                ProtectHome = false;
                CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
                ReadWritePaths = [ cfg.dataDir ];
              })
              (serviceOneshotDefaults { })
              ioTier.maintenance
            ];
          };

          systemd.services.bank-sync-qonto-import = {
            description = "Bank-Sync Qonto historical CSV import (idempotent, convergent)";
            wantedBy = [ "multi-user.target" ];
            # After the daemon: a switch that restarts bank-sync.service has
            # its own journal catch-up — the import waits so the two
            # projection hosts never replay the same uncheckpointed events
            # in the same activation window.
            after = [
              "bank-sync-storage-dir.service"
              "bank-sync.service"
              "bank-sync-qonto-stage.service"
            ];
            wants = [
              "bank-sync-storage-dir.service"
              "bank-sync.service"
              "bank-sync-qonto-stage.service"
            ];
            unitConfig = {
              RequiresMountsFor = [ cfg.dataDir ];
              # Staged copies, not the repo checkout (see the stage unit).
              ConditionPathExists = [
                qontoStageTech
                qontoStageHolding
                qontoStageTechFull
                qontoStageHoldingFull
              ];
            };
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "bank-sync";
                Group = "bank-sync";
                # One ExecStart per org: profile names are permanent (they
                # derive stable IDs), so they are the legal entity names.
                # Fragments first, then the full-history exports: the
                # importer skips the 132 UUID-bridged overlap idempotently.
                ExecStart = [
                  "${lib.getExe cfg.package} import --file ${qontoStageTech} --profile \"Artmann Technologies GmbH\" --account \"Hauptkonto\" --currency EUR"
                  "${lib.getExe cfg.package} import --file ${qontoStageHolding} --profile \"Artmann Holding GmbH\" --account \"Hauptkonto\" --currency EUR"
                  "${lib.getExe cfg.package} import --file ${qontoStageTechFull} --profile \"Artmann Technologies GmbH\" --account \"Hauptkonto\" --currency EUR"
                  "${lib.getExe cfg.package} import --file ${qontoStageHoldingFull} --profile \"Artmann Holding GmbH\" --account \"Hauptkonto\" --currency EUR"
                ];
                Environment = [ "BANK_SYNC_DATABASE_PATH=${cfg.dataDir}/data.db" ];
                # Encryption key (events are encrypted at rest; the Wise
                # key rides along harmlessly and keeps the unit honest if
                # the import ever grows an API leg).
                EnvironmentFile = [ envTemplate.path ];
                TimeoutStartSec = "5min";
              }
              (harden {
                # Staged CSVs live inside the dataDir — no /home access
                # needed anymore. Journal + read tables land next to the DB.
                ReadWritePaths = [ cfg.dataDir ];
              })
              (serviceOneshotDefaults { })
              # One-time historical load on the HDD pool: never compete
              # with the daemon or the desktop for I/O.
              ioTier.maintenance
            ];
          };

          systemd.services.bank-sync-qonto-paperless =
            lib.mkIf (config.services.bank-sync.paperlessArchive.enable && paperlessEnabled)
              {
                description = "Bank-Sync Qonto statement PDFs -> Paperless-ngx archival (one-time, marker-gated)";
                wantedBy = [ "multi-user.target" ];
                after = [
                  "network-online.target"
                  "bank-sync-storage-dir.service"
                  "bank-sync-paperless-token.service"
                  "bank-sync-qonto-stage.service"
                ];
                wants = [
                  "network-online.target"
                  "bank-sync-storage-dir.service"
                  "bank-sync-qonto-stage.service"
                ];
                requires = [ "bank-sync-paperless-token.service" ];
                unitConfig = {
                  RequiresMountsFor = [ cfg.dataDir ];
                  # Staged statements tree (see the stage unit).
                  ConditionPathExists = [ "${qontoStageStatements}" ];
                };
                inherit onFailure;
                startLimitBurst = 5;
                startLimitIntervalSec = 300;
                path = [
                  pkgs.curl
                  pkgs.jq
                  pkgs.coreutils
                ];
                # Metadata is canonical at upload: correspondent/type/tags
                # are ensured find-or-create (the bank-sync SDK's own
                # ensure calls find the same objects later — same names).
                # Per-statement metadata derives from the staged tree shape
                # <org-dir>/<year>/YYYY-MM-*.pdf: title "Qonto Statement -
                # <legal entity> - YYYY-MM", created = first day of the
                # statement month. The org directory names are validated —
                # an unexpected tree is a loud failure, not a misfiled
                # archive document.
                script = ''
                  set -euo pipefail

                  # Per-set marker: the ORIGINAL unit uploaded the two span
                  # CSV extracts under qonto-paperless-import.done (2026-10-19
                  # 08:59, after the owner's manual DB restore) — this
                  # statements-only set carries its own marker so the 40
                  # monthly PDFs are not skipped by the old set's completion.
                  marker="${cfg.dataDir}/qonto-statements-paperless.done"
                  if [ -e "$marker" ]; then
                    echo "bank-sync-qonto-paperless: statements marker present - already archived, no-op"
                    exit 0
                  fi

                  base="$BANK_SYNC_PAPERLESS_URL"
                  token="$BANK_SYNC_PAPERLESS_TOKEN"

                  # --fail-with-body: a rejected upload must print the API's
                  # own error body to the journal (curl -f alone discards
                  # it — the 04:03 400 was opaque until this lesson).
                  api() {
                    curl -fsS --fail-with-body --retry 3 --retry-delay 2 -H "Authorization: Token $token" "$@"
                  }

                  # ensure_named <endpoint> <name> -> id (find-or-create by
                  # exact case-insensitive name). DRF name__iexact needs
                  # URL encoding for names with spaces (-G --data-urlencode).
                  # Diagnostics go to STDERR ONLY: this helper's stdout is
                  # consumed by $() capture — a create-echo on stdout
                  # pollutes the id with a multiline diagnostic and the
                  # upload then sends garbage form values (the 04:03
                  # HTTP-400 root cause: "correspondent=<created ...>"
                  # instead of a numeric id). The numeric guard makes any
                  # future pollution a loud unit failure, not a bad upload.
                  ensure_named() {
                    endpoint="$1"
                    name="$2"
                    id=$(api -G --data-urlencode "name__iexact=$name" "$base/api/$endpoint/" | jq -r '.results[0].id // empty' || true)
                    if [ -z "$id" ]; then
                      id=$(api -X POST -H 'Content-Type: application/json' -d "{\"name\":\"$name\"}" "$base/api/$endpoint/" | jq -r '.id')
                      echo "bank-sync-qonto-paperless: created $endpoint '$name' (id $id)" >&2
                    fi
                    case "$id" in
                      ""|*[!0-9]*)
                        echo "bank-sync-qonto-paperless: ensure_named($endpoint, '$name') produced a non-numeric id '$id' — refusing to upload with it" >&2
                        exit 1
                        ;;
                    esac
                    printf '%s' "$id"
                  }

                  correspondent_id=$(ensure_named correspondents Qonto)
                  doctype_id=$(ensure_named document_types "Bank Statement")
                  tag_banksync=$(ensure_named tags bank-sync)
                  tag_qonto=$(ensure_named tags qonto)
                  echo "bank-sync-qonto-paperless: correspondent=$correspondent_id doctype=$doctype_id tags=$tag_banksync,$tag_qonto"

                  # upload <file> <title> <created YYYY-MM-DD>
                  upload() {
                    echo "bank-sync-qonto-paperless: uploading $1 (created $3)"
                    api -X POST \
                      -F "document=@$1" \
                      -F "title=$2" \
                      -F "created=$3" \
                      -F "correspondent=$correspondent_id" \
                      -F "document_type=$doctype_id" \
                      -F "tags=$tag_banksync" \
                      -F "tags=$tag_qonto" \
                      "$base/api/documents/post_document/"
                  }

                  # Statement set: every staged PDF, sorted for a
                  # deterministic journal. Process substitution (not a pipe)
                  # keeps the counter in the main shell and exit fatal.
                  uploaded=0
                  while IFS= read -r -d $'\0' f; do
                    rel="''${f#"${qontoStageStatements}/"}"
                    org_dir="''${rel%%/*}"
                    # NB: NOT named `base` — that is the paperless API
                    # base URL used by upload()/api() (the 2026-10-20 09:52
                    # shadowing bug made curl resolve the filename as a
                    # host after the first iteration).
                    fname="''${rel##*/}"
                    # First 7 chars: YYYY-MM. (A ''${base%%-*} expansion
                    # strips from the FIRST hyphen and yields only the year
                    # - the 2026-10-20 09:13 activation failure.)
                    month=$(printf '%s' "$fname" | cut -c1-7)
                    case "$org_dir" in
                      artmann-holding-gmbh) org="Artmann Holding GmbH" ;;
                      artmann-technologies-gmbh) org="Artmann Technologies GmbH" ;;
                      *)
                        echo "bank-sync-qonto-paperless: unknown org directory '$org_dir' in staged tree ($rel) - refusing" >&2
                        exit 1
                        ;;
                    esac
                    case "$month" in
                      [0-9][0-9][0-9][0-9]-[0-9][0-9]) ;;
                      *)
                        echo "bank-sync-qonto-paperless: cannot derive YYYY-MM statement month from '$fname' - refusing" >&2
                        exit 1
                        ;;
                    esac
                    upload "$f" "Qonto Statement - $org - $month" "''${month}-01"
                    uploaded=$((uploaded + 1))
                  done < <(find "${qontoStageStatements}" -type f -name '*.pdf' -print0 | sort -z)

                  if [ "$uploaded" -lt 1 ]; then
                    echo "bank-sync-qonto-paperless: no statement PDFs found under ${qontoStageStatements} - not writing the marker" >&2
                    exit 1
                  fi

                  # Consumption is asynchronous (OCR + task queue, 2
                  # workers): poll until every uploaded statement is
                  # queryable by title + correspondent (paperless's own
                  # dedup/delete would leave a re-run's duplicates out of
                  # the count — the marker makes re-runs impossible anyway).
                  count=0
                  for _ in $(seq 1 60); do
                    count=$(api -G \
                      --data-urlencode "title__icontains=Qonto Statement" \
                      --data-urlencode "correspondent=$correspondent_id" \
                      "$base/api/documents/" | jq -r '.count')
                    if [ "$count" -ge "$uploaded" ]; then
                      break
                    fi
                    sleep 3
                  done

                  if [ "$count" -lt "$uploaded" ]; then
                    echo "bank-sync-qonto-paperless: only $count/$uploaded Qonto statements visible after the poll window - not writing the marker" >&2
                    exit 1
                  fi

                  echo "bank-sync-qonto-paperless: verified $count Qonto statement documents in the archive"
                  touch "$marker"
                  echo "bank-sync-qonto-paperless: marker written ($marker)"
                '';
                serviceConfig = lib.mkMerge [
                  {
                    Type = "oneshot";
                    User = "bank-sync";
                    Group = "bank-sync";
                    Environment = [ "BANK_SYNC_PAPERLESS_URL=http://127.0.0.1:${toString ports.paperless}" ];
                    # Runtime-minted DRF token from the archival pair.
                    EnvironmentFile = [ "/run/bank-sync-paperless/env" ];
                    TimeoutStartSec = "10min";
                  }
                  (harden {
                    # Staged CSVs live inside the dataDir — no /home access
                    # needed anymore. The completion marker lands in the dataDir.
                    ReadWritePaths = [ cfg.dataDir ];
                  })
                  (serviceOneshotDefaults { })
                  ioTier.service
                ];
              };
        })
        # Service-integration registry entry: fans out to the Caddy vHost
        # (Layer 2 — money data minimum exposure), the two Gatus checks
        # (dashboard + sync health), and the homepage tile. Replaces rows in
        # caddy.nix / gatus-config.nix / homepage.nix.
        (lib.optionalAttrs (options ? services.integration) {
          services.integration = lib.mkIf cfg.enable {
            bank-sync = {
              inherit (cfg) enable;
              subdomain = "banksync";
              port = ports.bank-sync;
              vHost.layer = "protected";
              # The daemon's DNS-rebinding guard 403s any non-localhost Host
              # on its loopback bind — rewrite the upstream Host to localhost.
              vHost.hostOverride = "localhost";
              checks = [
                {
                  name = "Bank-Sync";
                  group = "Finance";
                  url = "http://localhost:${toString ports.bank-sync}/";
                  interval = "60s";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 1000"
                    # Functional, not just liveness: the real dashboard (not
                    # an error shell) carries the page title.
                    "[BODY] == pat(*Bank-Sync Dashboard*)"
                  ];
                  alert = "Bank-Sync down — Wise transaction sync halted, dashboard at banksync.home.lan unreachable. Check: systemctl status bank-sync, journalctl -u bank-sync.";
                }
                # Sync-health probe: the dashboard check above stays GREEN
                # while every sync cycle fails (the 2026-08 invisible-outage
                # class). This endpoint pattern-matches /metrics instead:
                # sync_errors_total must be zero AND at least one successful
                # sync must have ever happened (the last-sync timestamp
                # metric only renders after a success). Gatus cannot compute
                # timestamp AGE — a stale-sync (synced once, then scheduler
                # died silently) needs PromQL; covered by the sync_total
                # delta in post-deploy checks until Prometheus alerting
                # lands here.
                {
                  name = "Bank-Sync Sync Health";
                  group = "Finance";
                  url = "http://localhost:${toString ports.bank-sync}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*bank_sync_sync_errors_total 0*)"
                    "[BODY] == pat(*bank_sync_last_sync_timestamp_seconds*)"
                  ];
                  alert = "Bank-Sync syncs are failing (or never succeeded) while the dashboard stays green — the August invisible-outage class. Check: journalctl -u bank-sync -n 100, then curl localhost:8097/metrics and read bank_sync_sync_errors_total + bank_sync_last_sync_timestamp_seconds.";
                }
                # SCA approval-pending sentinel: bank_sync_sca_approval_pending
                # flips to 1 while any balance waits on a Wise SCA approval —
                # statements paused, degraded transfers fallback active,
                # dashboard GREEN. That combination stayed silent for 12
                # weeks in 2026-06..09; this is the push that ends the
                # silence. Anchored value-line pattern (\n<metric> <val>\n):
                # HELP/TYPE comment lines can never satisfy it, so a help
                # rewording can't turn the check phantom-green
                # (docs/agents/monitoring.md pat() trap classes).
                {
                  name = "Bank-Sync SCA Approval";
                  group = "Finance";
                  url = "http://localhost:${toString ports.bank-sync}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nbank_sync_sca_approval_pending 0\n*)"
                  ];
                  alert = "Bank-Sync: a Wise SCA approval is pending — statements paused while the dashboard stays green. Approve via the dashboard approval flow or the Wise app (~90-day cadence, runbook docs/services/bank-sync-sca.md); the one-time token is never surfaced here.";
                }
                # Sustained-outage sentinel: bank_sync_sync_sustained_failure
                # flips to 1 once any provider fails >= 4 consecutive sync
                # cycles (~1h at the 15m default). The daemon owns the
                # windowing (single blips reset on recovery, streaks re-seed
                # after restart) so gatus only pattern-matches the text —
                # no PromQL for a ratio-over-time condition.
                {
                  name = "Bank-Sync Sync Sustained";
                  group = "Finance";
                  url = "http://localhost:${toString ports.bank-sync}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[BODY] == pat(*\nbank_sync_sync_sustained_failure 0\n*)"
                  ];
                  alert = "Bank-Sync: syncs failing >= 4 consecutive cycles (~1h) — sustained provider outage behind a green dashboard. Check journalctl -u bank-sync -n 100 and read bank_sync_sync_consecutive_failures per provider on /metrics.";
                }
              ];
              homepage = {
                name = "Bank Sync";
                group = "Sync & Backup";
                description = "Wise Transactions → SQLite (Event-Sourced)";
                # The bundled icon pack has no bank.png — google-finance is the
                # closest available finance glyph.
                icon = "google-finance.png";
              };
            };
          };
        })
      ];
    };
}
