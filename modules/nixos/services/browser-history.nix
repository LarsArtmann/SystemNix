# Browser History — SystemNix wrapper around upstream NixOS modules.
#
# The upstream modules (inputs.browser-history.nixosModules.browser-history-server
# and .browser-history-agent) provide all options, defaults, assertions, and
# security hardening. This file layers ONLY SystemNix-specific concerns:
#   - Package wiring from the flake input
#   - Port assignment from the central registry
#   - WebAuthn/OAuth2 domain configuration
#   - OTel endpoint
#   - Agent bearer token provisioning: a co-located agent gets a real bh_ DB
#     token minted NON-INTERACTIVELY by a provisioner oneshot (upstream
#     `agent-token ensure` CLI); remote agents fall back to the sops env token
#   - Pocket ID OIDC secret bridging (oneshot reads Pocket ID's provisioned
#     secret and writes an EnvironmentFile for browser-history)
#   - SSL_CERT_FILE for internal CA (OIDC discovery via Caddy's CA-signed cert)
#   - onFailure alert routing
#   - Agent runs as the primary desktop user (to read browser profiles)
#
# Both server and agent modules are imported. Machines enable whichever they need:
#   services.browser-history.enable = true;        # server (headless box)
#   services.browser-history-agent.enable = true;  # agent (desktop with browsers)
{ inputs, ... }: {
  flake.nixosModules.browser-history =
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
        mkOidcGate
        onFailure
        ports
        serviceOneshotDefaults
        ioTier
        ;

      cfg = config.services.browser-history;
      serverPkg =
        inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-server;
      agentPkg = inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-agent;
      primaryUser = config.users.primaryUser or "lars";
      sopsEnvPath = config.sops.templates."browser-history-env".path;

      # Co-located agent token provisioning. The upstream `agent-token ensure`
      # CLI mints a DB-backed bh_ token directly against the server's SQLite
      # store — idempotent, converging (revoked token → re-minted, lost file →
      # labeled rotation), and dashboard-revocable. This kills the manual
      # "click in the UI + paste into sops" flow entirely: the plaintext never
      # touches git or sops, it lives only in a root-owned StateDirectory and
      # is handed to the agent as an EnvironmentFile (systemd reads it as root
      # at EVERY agent run, so a rotation is picked up on the next timer tick).
      agentTokenDir = "/var/lib/browser-history-agent-token";
      agentEnvFile = "${agentTokenDir}/agent.env";

      # Pool-side DB backup target (dbBackup.enable opts the host in).
      backupDir = "/mnt/pool/backups/browser-history";

      textfileDir = "/var/lib/prometheus-node-exporter/textfile_collectors";

      agentTokenProvisionScript = pkgs.writeShellApplication {
        name = "browser-history-agent-token-provision";
        runtimeInputs = [
          pkgs.coreutils
        ];
        text = ''
          TOKEN_FILE="${agentTokenDir}/token"
          ENV_FILE="${agentEnvFile}"

          prev=""
          if [ -f "$ENV_FILE" ]; then
            # Root-owned env file we wrote ourselves.
            # shellcheck disable=SC1090
            . "$ENV_FILE"
            prev="''${BROWSER_HISTORY_AGENT_TOKEN:-}"
            unset BROWSER_HISTORY_AGENT_TOKEN
          fi

          "${lib.getExe serverPkg}" agent-token ensure \
            -db /var/lib/browser-history/data.db \
            -label "${machineId}" ${
              lib.optionalString (
                config.services.browser-history-agent.tokenUserEmail != null
              ) "-user-email \"${config.services.browser-history-agent.tokenUserEmail}\""
            } \
            -out "$TOKEN_FILE"

          token="$(cat "$TOKEN_FILE")"

          if [ "$token" = "$prev" ]; then
            echo "browser-history-agent-token-provision: already provisioned"
            exit 0
          fi

          tmp="$(mktemp "${agentTokenDir}/.agent.env.XXXXXX")"
          printf 'BROWSER_HISTORY_AGENT_TOKEN=%s\n' "$token" > "$tmp"
          chmod 0600 "$tmp"
          mv "$tmp" "$ENV_FILE"
          echo "browser-history-agent-token-provision: agent env file written"
        '';
      };

      # Health-gate: wait for the server to answer /health before the agent
      # starts pushing batches. Prevents 502 race during simultaneous restarts
      # (deploy stops both, starts both — server Type=simple is "active" before
      # Go binds the port, agent Type=oneshot fails after 4 retries = exit 1).
      waitServerReady = pkgs.writeShellApplication {
        name = "browser-history-agent-wait-server";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
        ];
        text = ''
          SERVER_URL="http://127.0.0.1:${toString ports.browser-history}/health"
          echo "browser-history-agent: waiting for server at $SERVER_URL ..."
          # The gate's job is to wait out the server's BIND / projection-drain
          # race — NOT to demand a fully-healthy 200. Since upstream's
          # agent-freshness health check (AGENT_FRESHNESS, lock 10fe5d8a+) a
          # restarted server answers 503 "degraded" until the FIRST agent
          # ingest lands; demanding 200 here deadlocks the pair — the agent
          # can never run (gate never passes), so the server never recovers
          # (live 2026-09-20: wedged 90+ min until the gate was fixed). Any
          # answered HTTP status (incl. 503) = server accepting connections =
          # ready for the agent to push the ingest that HEALS the server.
          # Budget: 7 min covers the projection-drain worst case (4m50s,
          # no persistent checkpoint store upstream) + margin.
          for _i in $(seq 1 60); do
            code="$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' "$SERVER_URL" 2>/dev/null || true)"
            case "$code" in
              [1-9][0-9][0-9])
                echo "browser-history-agent: server answering (HTTP $code) — proceeding"
                exit 0
                ;;
            esac
            sleep 7
          done
          echo "browser-history-agent: server not answering after 7min, aborting" >&2
          exit 1
        '';
      };

      # One-time probe-registration purge script lives in
      # _browser-history-scripts.nix so flake checks can exercise it directly.
      browserHistoryScripts = import ./_browser-history-scripts.nix { inherit pkgs; };

      domain = config.networking.domain;
      fqdn = "history.${domain}";
      pocketIdEnabled = config.services.pocket-id-config.enable;
      oauth2SecretsFile = "/var/lib/browser-history-oidc/oauth2-secrets.env";
      machineId = config.services.browser-history-agent.machineId or "evo-x2";
    in
    {
      imports = [
        inputs.browser-history.nixosModules.browser-history-server
        inputs.browser-history.nixosModules.browser-history-agent
      ];

      options.services.browser-history-agent.tokenUserEmail = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Email of the user the agent-token provisioner mints the DB token
          for. REQUIRED once the server has more than one registered user —
          the CLI refuses to pick one (live 2026-09-04: 5 bring-up users,
          provision oneshot failing "pass -user-email to disambiguate"
          every agent tick). null keeps the single-user auto-resolution.
        '';
      };

      options.services.browser-history.agentActivity = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Alert when ZERO agents are sending data: a root textfile collector
            reads agent_tokens.last_used_at (the server touches it on every
            authenticated ingest) and the "Browser History Agent Data" Gatus
            check fires when no agent token is fresh within maxAgeMinutes.
          '';
        };

        maxAgeMinutes = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = ''
            Ingest freshness window. The agent timer defaults to 5min, so 60
            tolerates ~12 missed ticks before the alert fires.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "5min";
          description = "Collection interval (OnUnitActiveSec).";
        };
      };

      options.services.browser-history.dbBackup = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Nightly online `sqlite3 .backup` of the server DB onto the HDD
            pool (/mnt/pool/backups/browser-history), 14d retention, watched
            via backup-coordination. Default OFF: the units hard-depend on
            the pool mount (RequiresMountsFor), so only hosts with the pool
            opt in (evo-x2 via configuration.nix).
          '';
        };
      };

      options.services.browser-history.probeRegistrationCleanup = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            One-time purge of a probe registration's residue (2026-09-18: the
            registration-gate verification created probe-gate@example.com on
            prod; the freeze reboots already dropped its users_view row, so
            only the UserRegistered journal event remains). Runs as a
            marker-guarded server ExecStartPre — the DynamicUser service owns
            the StateDirectory, so the service performs the delete itself:
            no root path, no concurrent-writer window (the server process is
            not running yet). Failure is non-fatal ("-"-prefixed): the server
            starts anyway and the purge retries on the next start.
          '';
        };

        email = lib.mkOption {
          type = lib.types.str;
          description = "Email of the probe registration to purge.";
        };
      };

      config = lib.mkMerge [
        # ── Server: deployment-specific values (upstream defaults handle the rest) ──
        #
        # Crash-loop protection: the server has an upstream bug where
        # usermgmt.NewService() fails during projection replay (cqrs-htmx v4.7.2).
        # Without aggressive backoff, the crash loop burns CPU/memory and can
        # cause system-wide memory pressure → WDT reset (2026-08-11 crash).
        (lib.mkIf cfg.enable {
          services.browser-history = {
            package = lib.mkDefault serverPkg;
            address = lib.mkDefault "127.0.0.1:${toString ports.browser-history}";
            webauthn.rpId = lib.mkDefault fqdn;
            webauthn.rpName = lib.mkDefault "BrowserHistory";
            webauthn.origins = lib.mkDefault [ "https://${fqdn}" ];
            # Scheme included on purpose: v0.5.0 normalizes the value for the
            # gRPC exporter (which wants bare host:port) while anything that
            # parses the env var as a URL (OTel spec) requires the scheme.
            otelEndpoint = lib.mkDefault "http://127.0.0.1:${toString ports.signoz-otlp-grpc}";
          };

          systemd.services.browser-history = {
            inherit onFailure;
            restartTriggers = [ serverPkg ];
            startLimitBurst = 3;
            startLimitIntervalSec = 600;

            # Agent token from sops. Systemd reads EnvironmentFile as root,
            # so root-owned sops template works for the DynamicUser server.
            serviceConfig = lib.mkMerge [
              {
                EnvironmentFile = [ sopsEnvPath ];
                Environment = [
                  "GOMEMLIMIT=384MiB"
                  "LOG_LEVEL=debug"
                  "MAX_USERS=1"
                ];
                # Must exceed the 300s OIDC gate budget (slow-boot dnsblockd)
                TimeoutStartSec = "6min";
                RestartSec = lib.mkForce "2min";
              }
              ioTier.background
            ];
          };
        })

        # ── Pocket ID OAuth2 integration ───────────────────────────────────────────
        (lib.mkIf (cfg.enable && pocketIdEnabled) (
          let
            oidcGate = mkOidcGate {
              inherit pkgs domain;
              serviceName = "browser-history";
              includeProvision = true;
            };

            # Bridges the Pocket ID client secret into an env file.
            # Uses systemd LoadCredential (like Forgejo) to read the secret from
            # /var/lib/pocket-id/client-secrets/browser-history inside the hardened
            # namespace. Writes all OAUTH2_POCKET_ID_* vars to an EnvironmentFile in
            # the oneshot's own StateDirectory (separate from the server's DynamicUser
            # StateDirectory, which is inaccessible to other services).
            # CLIENT_ID, CLIENT_SECRET, and ISSUER are ONLY set via this file, so
            # when the secret is missing, the server degrades to WebAuthn-only
            # instead of crash-looping on ProviderConfig.Validate().
            oidcSetupService = {
              description = "Browser History — Pocket ID OAuth2 secret provisioning";
              after = [ "pocket-id-provision.service" ];
              wants = [ "pocket-id-provision.service" ];
              before = [ "browser-history.service" ];
              wantedBy = [ "browser-history.service" ];
              startLimitBurst = 5;
              startLimitIntervalSec = 300;

              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "browser-history-oidc";
                  LoadCredential = [
                    "pocket-id-secret:${config.services.pocket-id.dataDir}/client-secrets/browser-history"
                  ];
                }
                (harden {
                  ProtectSystem = "strict";
                })
                (serviceOneshotDefaults { })
              ];

              path = [
                pkgs.coreutils
                pkgs.bash
              ];

              script = ''
                # Secret is injected via systemd LoadCredential (like Forgejo).
                # %d resolves to the per-service credentials directory.
                SECRET_FILE="''${CREDENTIALS_DIRECTORY}/pocket-id-secret"

                if [ ! -s "$SECRET_FILE" ]; then
                  echo "browser-history-oidc-setup: Pocket ID secret not found, starting in WebAuthn-only mode"
                  rm -f "${oauth2SecretsFile}"
                  exit 0
                fi

                install -d -m 0755 "$(dirname "${oauth2SecretsFile}")"
                {
                  echo "OAUTH2_POCKET_ID_CLIENT_ID=browser-history"
                  echo "OAUTH2_POCKET_ID_CLIENT_SECRET=$(cat "$SECRET_FILE")"
                  echo "OAUTH2_POCKET_ID_ISSUER=https://auth.${domain}"
                } > "${oauth2SecretsFile}"
                chmod 600 "${oauth2SecretsFile}"
                echo "browser-history-oidc-setup: Pocket ID OAuth2 secret written"
              '';
            };
          in
          {
            services.browser-history = {
              oauth2.redirectBase = lib.mkDefault "https://${fqdn}";
            };

            systemd.services.browser-history = {
              # The OIDC gate's curl probe (ExecStartPre) waits up to 2min for
              # auth.${domain}/.well-known/openid-configuration to respond —
              # required since browser-history v4.7.0 does OIDC discovery at
              # startup and exits 69 (UNAVAILABLE) if dnsblockd hasn't bound
              # 127.0.0.1:53 yet (the Go resolver falls through to 9.9.9.9
              # which has no auth.home.lan → exit code 69).
              after = oidcGate.after ++ [ "browser-history-oidc-setup.service" ];
              wants = oidcGate.wants ++ [ "browser-history-oidc-setup.service" ];

              # SSL_CERT_FILE: OIDC discovery calls auth.${domain} via HTTPS
              # (through Caddy). Without this, Go on NixOS may not find the
              # system cert pool (including the dnsblockd-CA that signs internal certs).
              environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";

              # "-" prefix = optional: won't fail if the file is missing (graceful
              # degradation to WebAuthn-only mode). Merges with the sops EnvironmentFile
              # from the server block above (NixOS list concatenation).
              serviceConfig = lib.mkMerge [
                { EnvironmentFile = [ "-${oauth2SecretsFile}" ]; }
                { ExecStartPre = oidcGate.serviceConfig.ExecStartPre; }
              ];
            };

            systemd.services.browser-history-oidc-setup = oidcSetupService;
          }
        ))

        # ── One-time probe-registration purge (see probeRegistrationCleanup) ─────
        # Appended AFTER the OIDC gate's ExecStartPre (list concatenation across
        # mkMerge branches, same mechanism as the EnvironmentFile pair above).
        (lib.mkIf (cfg.enable && cfg.probeRegistrationCleanup.enable) {
          # Guard against the split-brain failure mode: option on but the
          # ExecStartPre entry lost to a future refactor = a purge that never
          # runs (phantom no-op). Reads the FINAL merged unit config.
          assertions = [
            {
              assertion = lib.any (lib.hasInfix "browser-history-probe-registration-purge") (
                config.systemd.services.browser-history.serviceConfig.ExecStartPre or [ ]
              );
              message = "browser-history probeRegistrationCleanup is enabled but the purge script is absent from ExecStartPre";
            }
          ];

          systemd.services.browser-history.serviceConfig = lib.mkMerge [
            {
              ExecStartPre = [
                "-${lib.getExe browserHistoryScripts.probeRegistrationPurge} ${cfg.probeRegistrationCleanup.email}"
              ];
            }
          ];
        })

        # ── Agent: SystemNix defaults for machines that enable it ──────────────────
        # The agent extracts browser history from local profiles and pushes it
        # to the server. It must run as the desktop user to read browser data.
        # Enable per-machine:
        #   services.browser-history-agent = {
        #     enable = true;
        #     serverUrl = "https://history.${domain}";
        #     machineId = "evo-x2";
        #   };
        #
        # Crash-loop protection: the agent reads ~19,700 browser entries on every
        # spawn. Without aggressive backoff, the crash loop (when the server is
        # down) generates massive I/O churn and memory pressure → WDT reset.
        (lib.mkIf config.services.browser-history-agent.enable {
          services.browser-history-agent = {
            package = lib.mkDefault agentPkg;
            tokenFile = lib.mkDefault sopsEnvPath;
          };

          systemd.services.browser-history-agent = {
            inherit onFailure;

            # Run as the desktop user — browser profiles are mode 0700 and
            # not readable by other users. ProtectHome=read-only (from the
            # upstream module) still applies.
            serviceConfig = {
              User = primaryUser;
              MemoryMax = lib.mkDefault "512M";
            };
          };
        })

        # ── Co-located server+agent ordering ─────────────────────────────────────
        # When the agent and server run on the same machine (evo-x2), the agent
        # must wait for the server to accept HTTP requests before pushing batches.
        # During deploy, systemd stops and starts both simultaneously — the server
        # is Type=simple (marked "active" before Go binds the port), and the agent
        # is Type=oneshot with only 4 retries per batch (~7s). Without this gate,
        # the agent races ahead, gets 502 from Caddy, fails all 4 retries, exits 1,
        # and blocks the deploy with "Activation (test) failed: exit status 4".
        (lib.mkIf (config.services.browser-history-agent.enable && cfg.enable) {
          # Co-located: the agent gets a REAL user-attributed bh_ token via the
          # provisioner oneshot below (overrides the sops fallback above —
          # mkForce because two mkDefaults on a non-mergeable option conflict).
          services.browser-history-agent.tokenFile = lib.mkForce agentEnvFile;

          systemd.services.browser-history-agent = {
            after = [
              "browser-history.service"
              "browser-history-agent-token-provision.service"
            ];
            wants = [
              "browser-history.service"
              "browser-history-agent-token-provision.service"
            ];
            # The 5-min timer IS the retry mechanism. Restart=on-failure with
            # RestartSec=5min (previous setting) raced the timer: two start
            # requests land in the same window, the rejected one counts against
            # the rate limit, and burst=2/1800s turned ONE failed run into a
            # self-re-arming start-limit-hit that blocked runs for hours
            # (verified live 2026-08-18: alternating blocked/success timer
            # fires all day). No Restart + a generous short-window burst lets
            # the next timer tick always retry.
            startLimitBurst = 5;
            startLimitIntervalSec = 300;

            serviceConfig = lib.mkMerge [
              {
                ExecStartPre = "+${lib.getExe waitServerReady}";
                TimeoutStartSec = "9min";
                Restart = lib.mkForce "no";
              }
            ];
          };

          # Provisions the agent's DB-backed bh_ token non-interactively.
          # Fails LOUDLY (onFailure alert) until at least one user is
          # registered — on a fresh host, register via the dashboard once,
          # then `systemctl start` (or re-deploy) runs the provisioner again.
          systemd.services.browser-history-agent-token-provision = {
            inherit onFailure;

            after = [ "browser-history.service" ];
            wants = [ "browser-history.service" ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;

            serviceConfig = lib.mkMerge [
              (harden {
                # DAC_READ_SEARCH alone only reads: minting (or rotating) a
                # token WRITES the server's foreign-owned 0600 SQLite files
                # (VM-test-proven SQLITE_READONLY(8) without it).
                CapabilityBoundingSet = "CAP_DAC_READ_SEARCH CAP_DAC_OVERRIDE";
              })
              {
                Type = "oneshot";
                RemainAfterExit = true;
                StateDirectory = "browser-history-agent-token";
                ExecStart = lib.getExe agentTokenProvisionScript;
                # The server's DynamicUser StateDirectory
                # (/var/lib/browser-history) is 0700 owned by a random
                # dynamic UID — root cannot even stat through it without
                # CAP_DAC_READ_SEARCH (backup-coordination precedent).
                TimeoutStartSec = "3min";
              }
            ];
          };
        })

        # ── Agent ingest-freshness watch ───────────────────────────────────────
        # "Server up" is NOT "data flowing": a dead agent timer alerts
        # nowhere today (the health check pings the server, not the agents).
        # This collector reads agent_tokens.last_used_at — the server's auth
        # middleware touches it on EVERY authenticated /ingest batch
        # (upstream agent_token_store.go: synchronous single-row UPDATE) —
        # and publishes:
        #   browser_history_agent_tokens_total             registered DB tokens
        #   browser_history_agent_last_ingest_age_seconds  -1 = never used
        #   browser_history_agents_active                  1 = any token fresh
        #   browser_history_agent_scrape_errors            1 = DB unreadable
        # Fail-closed: on a scrape error the active metric is OMITTED, so the
        # Gatus check cannot phantom-green on a frozen textfile.
        # CAVEAT: agents on the legacy sops env-token path never touch
        # last_used_at (env resolution short-circuits before the DB lookup) —
        # only bh_ DB tokens (the co-located provisioner's output) are visible.
        (lib.mkIf (cfg.enable && cfg.agentActivity.enable) {
          systemd.services.browser-history-agent-metrics = {
            description = "Browser History agent ingest freshness (textfile collector)";
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            inherit onFailure;
            path = [
              pkgs.sqlite
              pkgs.coreutils
            ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                TimeoutStartSec = "3min";
              }
              (harden {
                ReadWritePaths = [ textfileDir ];
                # DAC_READ_SEARCH: the server's DynamicUser StateDirectory is
                # 0700 random-uid (token-provisioner precedent). FOWNER: the
                # sticky 1777 textfile dir rejects rename-over-foreign-owned
                # even for root (mail-relay 2026-09-02..06 class).
                CapabilityBoundingSet = "CAP_DAC_READ_SEARCH CAP_FOWNER";
                MemoryMax = "128M";
              })
              (serviceOneshotDefaults { })
            ];
            script = ''
              set -eu
              OUT="${textfileDir}/browser-history-agent.prom"
              mkdir -p "${textfileDir}"
              TMP="$(mktemp "$OUT.XXXXXX")"
              chmod 644 "$TMP"
              trap 'rm -f "$TMP"' EXIT

              DB="/var/lib/browser-history/data.db"
              MAX_AGE_S=$(( ${toString cfg.agentActivity.maxAgeMinutes} * 60 ))
              scrape_errors=0
              tokens=""
              newest_ns=""

              if [ ! -f "$DB" ]; then
                echo "browser-history-agent-metrics: server DB missing at $DB" >&2
                scrape_errors=1
              else
                tokens="$(sqlite3 -readonly "$DB" 'SELECT count(*) FROM agent_tokens;' 2>/dev/null)" || {
                  tokens=""
                  scrape_errors=1
                }
                newest_ns="$(sqlite3 -readonly "$DB" 'SELECT max(last_used_at) FROM agent_tokens;' 2>/dev/null)" || {
                  newest_ns=""
                  scrape_errors=1
                }
              fi

              active=0
              age=-1
              if [ "$scrape_errors" -eq 0 ] && [ -n "$newest_ns" ]; then
                now_ns="$(date +%s%N)"
                age=$(( (now_ns - newest_ns) / 1000000000 ))
                if [ "$age" -ge 0 ] && [ "$age" -le "$MAX_AGE_S" ]; then
                  active=1
                fi
              fi

              {
                echo "# HELP browser_history_agent_scrape_errors 1 when the server's agent_tokens table could not be read"
                echo "# TYPE browser_history_agent_scrape_errors gauge"
                echo "browser_history_agent_scrape_errors $scrape_errors"
                if [ "$scrape_errors" -eq 0 ]; then
                  echo "# HELP browser_history_agent_tokens_total Registered DB-backed browser-history agent tokens"
                  echo "# TYPE browser_history_agent_tokens_total gauge"
                  echo "browser_history_agent_tokens_total $tokens"
                  echo "# HELP browser_history_agent_last_ingest_age_seconds Seconds since the newest agent ingest (server clock); -1 = never"
                  echo "# TYPE browser_history_agent_last_ingest_age_seconds gauge"
                  echo "browser_history_agent_last_ingest_age_seconds $age"
                  echo "# HELP browser_history_agents_active 1 when at least one agent ingested within the freshness window"
                  echo "# TYPE browser_history_agents_active gauge"
                  echo "browser_history_agents_active $active"
                fi
              } >> "$TMP"

              mv "$TMP" "$OUT"
              echo "browser-history-agent-metrics: tokens=''${tokens:-?} active=$active age=''${age}s window=''${MAX_AGE_S}s scrape_errors=$scrape_errors"
            '';
          };

          systemd.timers.browser-history-agent-metrics = {
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = cfg.agentActivity.interval;
            };
            wantedBy = [ "timers.target" ];
          };
        })

        # ── Nightly DB backup onto the HDD pool ────────────────────────────────
        # Online `sqlite3 .backup` (safe against the live WAL writer) of
        # /var/lib/browser-history/data.db onto /mnt/pool/backups, 14d
        # retention (cv-backup pattern). Pool-leaf creation is mount-gated
        # (cv-backup-dir pattern — no tmpfiles rule under /mnt/pool, the
        # root-fs shadow-dir class). Default OFF: the units hard-depend on
        # the pool (RequiresMountsFor), which is host-shaped — evo-x2 opts
        # in via configuration.nix (profileProbe precedent).
        (lib.mkIf (cfg.enable && cfg.dbBackup.enable) {
          systemd.services.browser-history-backup-dir = {
            description = "Create Browser History DB backup directory on the HDD pool";
            wantedBy = [ "multi-user.target" ];
            unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                RemainAfterExit = true;
              }
              # ReadWritePaths targets the MOUNT ROOT (cv-backup-dir pattern):
              # a fresh pool has no backups/ leaf yet, and a ReadWritePaths
              # entry under the mountpoint would abort with 226/NAMESPACE
              # before the script can mkdir.
              (harden {
                MemoryMax = "128M";
                ReadWritePaths = [ "/mnt/pool" ];
                CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
            ];
            script = ''
              mkdir -p ${backupDir}
              chmod 0755 ${backupDir}
            '';
          };

          systemd.services.browser-history-backup = {
            description = "Browser History DB backup (online sqlite .backup)";
            after = [
              "browser-history.service"
              "browser-history-backup-dir.service"
            ];
            wants = [
              "browser-history.service"
              "browser-history-backup-dir.service"
            ];
            # Detached DAS fails the run as a clean dependency error, never
            # 226/NAMESPACE (btrbk doctrine).
            unitConfig.RequiresMountsFor = [ backupDir ];
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "browser-history-backup" ''
                  set -euo pipefail
                  db="/var/lib/browser-history/data.db"
                  if [ ! -f "$db" ]; then
                    echo "browser-history-backup: no data.db yet — nothing to back up"
                    exit 0
                  fi
                  dst="${backupDir}/browser-history-db-$(date +%Y-%m-%d).sqlite"
                  ${lib.getExe pkgs.sqlite} "$db" ".backup '$dst'"
                  # 14-day retention (cv/miniflux pattern): the online .backup
                  # rewrites every page, so nothing is shared between nights.
                  find ${backupDir} -name "browser-history-db-*.sqlite" -mtime +14 -delete
                  echo "browser-history-backup: wrote $dst"
                '';
                ReadWritePaths = [ backupDir ];
              }
              # The server's DynamicUser StateDirectory is 0700 owned by a
              # random uid — root cannot traverse it without CAP_DAC_READ_SEARCH
              # (cv-backup silent-no-op precedent: DAC-obeying root saw no DB
              # and exited 0 "nothing to back up" forever).
              (harden {
                MemoryMax = "512M";
                CapabilityBoundingSet = "CAP_DAC_READ_SEARCH";
              })
              (serviceOneshotDefaults { })
              ioTier.background
            ];
          };

          systemd.timers.browser-history-backup = {
            description = "Nightly Browser History DB backup";
            wantedBy = [ "timers.target" ];
            after = [ "mnt-pool.mount" ];
            timerConfig = {
              # 02:15 — staggered off paperless-db (02:00 + 10m jitter) and
              # miniflux (02:45).
              OnCalendar = "*-*-* 02:15:00";
              Persistent = true;
            };
          };
        })

        # Service-integration registry entries (modules/nixos/services/
        # integration.nix). enable-gated via the registry's own switch so
        # hosts without the integration module (VM tests) still evaluate.
        # The server entry REPLACES rows in caddy.nix (history vHost, plain:
        # native WebAuthn/OIDC — protectedVHost would break passkey flows),
        # gatus-config.nix (Browser History check), homepage.nix (tile), and
        # pocket-id.nix (OIDC client). The agent registers its own unit with
        # system-health (moved out of monitoredServices' default list).
        (lib.optionalAttrs (options ? services.integration) {
          services.integration = {
            browser-history = {
              inherit (cfg) enable;
              subdomain = "history";
              port = ports.browser-history;
              vHost.layer = "plain";
              monitored = true;
              checks = [
                {
                  name = "Browser History";
                  group = "Productivity";
                  url = "http://localhost:${toString ports.browser-history}/health";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    "[RESPONSE_TIME] < 500"
                  ];
                  alert = "Browser History server down — browsing analytics unavailable";
                }
              ]
              ++ lib.optionals cfg.agentActivity.enable [
                {
                  name = "Browser History Agent Data";
                  group = "Productivity";
                  # node_exporter textfile, not the service's own port.
                  url = "http://localhost:${toString ports.signoz-node-exporter}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    # Anchored (leading \n) so the metric's own HELP comment
                    # can never satisfy the pattern (2026-08-22 class).
                    "[BODY] == pat(*\nbrowser_history_agent_scrape_errors 0\n*)"
                    "[BODY] == pat(*\nbrowser_history_agents_active 1\n*)"
                  ];
                  alert = "Browser History has NO agent data — zero agent tokens ingested within the last ${toString cfg.agentActivity.maxAgeMinutes}min (agent timer dead, agent crash-looping, or ingest auth rejecting a revoked token). Check: systemctl status browser-history-agent.timer browser-history-agent.service; journalctl -u browser-history-agent -n 50. Note: legacy sops env-token agents never update last_used_at — DB (bh_) tokens only.";
                }
              ];
              homepage = {
                name = "Browser History";
                group = "Sync & Backup";
                description = "Browsing Analytics & Productivity Insights";
              };
              # DB dump freshness (browser-history-backup.timer, 02:15) —
              # gated so pool-less hosts register no phantom backup row.
              backup = lib.mkIf cfg.dbBackup.enable {
                directory = backupDir;
                filePattern = "browser-history-db-*.sqlite";
                maxAgeHours = 25;
              };
              oidc = {
                name = "Browser History";
                clientId = "browser-history";
                launchURL = "https://history.${domain}";
                callbackURLs = [ "https://history.${domain}/auth/oauth/pocket-id/callback" ];
              };
            };
            browser-history-agent = {
              enable = config.services.browser-history-agent.enable;
              vHost.layer = "none";
              monitored = true;
            };
          };
        })
      ];
    };
}
