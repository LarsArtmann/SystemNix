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

            # TEMPORARY vendorHash shim RE-PINNED (2026-10-07, class comment
            # at lib/lars-packages.nix): the 2026-10-05 drop's condition broke
            # — `nix flake update bank-sync` moved the lock to upstream
            # 68ceffa3 whose declared hash xvAXxSvB… no longer reproduces
            # from our lock (got pE2+3UF1…, 09:25 evo-x2 keep-going
            # enumeration — first-hand build output, never invented).
            # Upstream genuinely stale at the locked rev: drop when the lock
            # moves past an upstream-fixed rev (fix upstream, push, re-lock —
            # DiscordSync protocol). MUST mirror the same override at the HM
            # surface (systems/evo-x2.nix programs.bank-sync) or the two
            # surfaces build different drvs.
            package = lib.mkDefault (
              inputs.bank-sync.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
                vendorHash = "sha256-pE2+3UF1eU+PC2E89nf9ueC84aEjcn/NUCLuQrvdepo=";
              }
            );
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
              (harden { })
              (serviceOneshotDefaults { })
            ];
            script = ''
              expected="${lib.getExe cfg.package}"
              main_pid="$(${pkgs.systemd}/bin/systemctl show -p MainPID --value bank-sync.service)"
              if [ -z "$main_pid" ] || [ "$main_pid" = "0" ]; then
                echo "bank-sync-rev-drift: bank-sync.service has no MainPID (daemon down — the liveness check owns that alarm, failing here too so the state is never silent)" >&2
                exit 1
              fi
              running="$(${pkgs.coreutils}/bin/readlink "/proc/$main_pid/exe")"
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
