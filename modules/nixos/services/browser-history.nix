# Runbook: docs/services/browser-history.md
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
        mkPoolDirUnit
        onFailure
        ports
        serviceOneshotDefaults
        ioTier
        ;

      cfg = config.services.browser-history;
      # TEMPORARY vendorHash shims (2026-10-06, re-pinned 2026-10-07) DROPPED
      # 2026-10-07 at the 3ebbfbf lock move: upstream re-pinned the server
      # got-hash (dQN6dTxU…, first-hand --keep-going toplevel evidence) and
      # carries the agent hash (l6ATO1jf…) in its own flake.nix, so the
      # overrideAttrs shims went stale-again (4Rrty… broke the 2026-10-07
      # deploy while upstream was already green). Upstream owns its hashes —
      # re-add ONLY via nix-hash-fix evidence, never by hand (class comment
      # at buildflow; probe protocol docs/agents/go-ecosystem.md).
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

      domain = config.networking.domain;
      fqdn = "history.${domain}";
      pocketIdEnabled = config.services.pocket-id-config.enable;
      oauth2SecretsFile = "/var/lib/browser-history-oidc/oauth2-secrets.env";
      # Machine identity has ONE source: the upstream agent module's machineId
      # option (required, no default). It drives BOTH the agent's X-Machine-ID
      # header (--machine-id flag) and the provisioner's token label above, so
      # the two cannot drift. No `. or` fallback on purpose: an upstream option
      # rename must fail eval loudly instead of silently relabeling every
      # token "evo-x2" while visits keep carrying the agent's own header value.
      machineId = config.services.browser-history-agent.machineId;

      # Interactive AI rides the ai-meter proxy → llama-chat upstream when
      # both are in scope (evo-x2). Option-guarded, NOT `.enable or false`:
      # this module evals standalone (flake.nixosModules.browser-history /
      # VM tests import it alone, no ai-meter module present).
      aiMeterEnabled = (options.services ? ai-meter) && config.services.ai-meter.enable;
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
            tolerates ~12 missed ticks before the alert fires. ALSO drives the
            server's agentFreshness /health window (single-sourced binding in
            the config block below, 2026-10-15) so gatus and /health agree.
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

            # AI suite — INTERACTIVE AI (summaries + /chat) must ride an
            # always-on endpoint. The 2026-10-15 wiring pointed here at
            # FastFlowLM directly and the feature NEVER worked from the UI:
            # flm is the memory-emergency-guard's designated sacrifice —
            # trips stop fastflowlm.socket (the re-activation listener) and
            # the 3/day restore cap leaves :52625 REFUSED for hours (live
            # 2026-10-27: guard SEV1 "FLM RESTORE CAPPED", browser-history
            # journal full of "dial tcp 127.0.0.1:52625: connect: connection
            # refused" since boot). llama-chat is always-on CPU, same
            # Qwen3.6-35B-A3B family, instant first token — and through
            # ai-meter it is metered like every other AI call on the host.
            # Key: runtime-minted ai-meter client key via EnvironmentFile on
            # the unit below; the server treats AI as unconfigured until
            # LLM_API_KEY is non-empty (api/server.go:557 gate) — if the
            # mint ever fails, AI fails VISIBLE-unconfigured, never silent
            # 401s. The direct-flm values remain ONLY as the standalone-
            # module fallback (VM tests, no ai-meter in scope). Model is
            # single-sourced from the serving module WHEN in scope.
            llm.baseUrl = lib.mkDefault (
              if aiMeterEnabled then
                "http://127.0.0.1:${toString ports.ai-meter}/v1/llama-chat"
              else
                "http://127.0.0.1:${toString ports.fastflowlm}/v1"
            );
            llm.model = lib.mkDefault (
              if aiMeterEnabled && (options.services ? llama-chat) then
                config.services.llama-chat.alias
              else if options.services ? fastflowlm then
                config.services.fastflowlm.model
              else
                "qwen3.6-moe:35b-a3b"
            );
            llm.timeout = lib.mkDefault "10m";

            # Module options, not unit-level env twins (2026-10-15 audit F4):
            # upstream renders LOG_LEVEL from logLevel and loads the sops
            # file from environmentFile — unit-level duplicates only worked
            # via systemd last-wins-by-merge-order.
            logLevel = lib.mkDefault "debug";
            environmentFile = lib.mkDefault sopsEnvPath;
            # One freshness window for BOTH clocks (audit F6): the server's
            # /health agent-freshness gate and the agentActivity textfile
            # collector read the same maxAgeMinutes value, so gatus and
            # /health cannot disagree. "0" would disable the server leg.
            agentFreshness = lib.mkDefault "${toString config.services.browser-history.agentActivity.maxAgeMinutes}m";
          };

          systemd.services.browser-history = {
            inherit onFailure;
            restartTriggers = [ serverPkg ];
            startLimitBurst = 3;
            startLimitIntervalSec = 600;

            # The minted ai-meter env-file key must exist before the server
            # reads its environment (ai-meter-keys mints at boot; deploy.sh's
            # provisioner loop re-runs it before daemon restarts on deploys).
            after = lib.optionals aiMeterEnabled [ "ai-meter-keys.service" ];
            wants = lib.optionals aiMeterEnabled [ "ai-meter-keys.service" ];

            # Agent token from sops loads via the upstream environmentFile
            # option above (systemd reads EnvironmentFile as root, so the
            # root-owned sops template works for the DynamicUser server).
            # LOG_LEVEL likewise comes from the logLevel option.
            serviceConfig = lib.mkMerge [
              {
                Environment = [
                  "GOMEMLIMIT=384MiB"
                  "MAX_USERS=1"
                ]
                ++ lib.optionals (!aiMeterEnabled) [
                  # Standalone-fallback AI gate: LLM_API_KEY non-empty
                  # flips the provider on ("local" dummy — flm ignores
                  # Authorization, PMA precedent). Through ai-meter the
                  # real minted key rides the EnvironmentFile below
                  # instead (files override Environment= entries).
                  "LLM_API_KEY=local"
                ]
                ++ [
                  # CHAT_DB_PATH enables /chat (env-only upstream, lives
                  # beside data.db in the DynamicUser StateDirectory).
                  "CHAT_DB_PATH=/var/lib/browser-history/chat.db"
                ];
                # Runtime-minted ai-meter client key as LLM_API_KEY — minted
                # root-owned by ai-meter-keys; systemd reads EnvironmentFile
                # as root for the DynamicUser server, so root ownership is
                # the correct shape here (same delivery as the sops file).
                EnvironmentFile = lib.optionals aiMeterEnabled [
                  "/run/ai-meter-keys/browser-history.env"
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
              # OAuth-only sign-in (owner policy 2026-10-16): passkeys
              # disabled, Pocket ID the only auth method. Gated on Pocket ID
              # PRESENCE (not just cfg.enable) because upstream eval-asserts
              # a configured OAuth2 provider for every disable — the VM test
              # exercises the passkeys-on default shape without Pocket ID.
              # Upstream renders PASSKEYS_DISABLED=true; the non-secret client
              # ID rides the option while the secret keeps flowing via
              # browser-history-oidc-setup's env file (a missing secret then
              # fails the boot BY DESIGN — fail closed beats serving a
              # login-less server).
              webauthn.enable = false;
              oauth2.pocketId.clientId = lib.mkDefault "browser-history";
              oauth2.redirectBase = lib.mkDefault "https://${fqdn}";
            };

            systemd.services.browser-history = {
              # late-applications (2026-10-26 ordering-cycle class fix;
              # mkForce over the upstream browser-history module's
              # multi-user default).
              wantedBy = lib.mkForce [ "late-applications.target" ];
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

        # ── DynamicUser uid-drift ownership heal ───────────────────────────
        # systemd re-resolves the dynamic uid on every unit stop/start; a mass
        # restart (deploy activation) can hand the unit a DIFFERENT uid while
        # pre-existing DB/WAL files keep the old one → SQLITE_READONLY(8) at
        # the first write (2026-09-22: crash-loop after the 13:04 activation
        # although the binary had run healthy for 1.5 days — systemd chowns
        # only the state DIRECTORY, never files within). `+` runs as root
        # (chown needs it); --reference copies the directory's (already
        # correct) owner onto everything inside. No-op when consistent.
        (lib.mkIf cfg.enable {
          systemd.services.browser-history.serviceConfig = {
            ExecStartPre = [
              "+${pkgs.writeShellScript "browser-history-ownership-heal" ''
                # Operate on the REAL path: /var/lib/browser-history is a
                # symlink into private/ (DynamicUser layout) and chown/chmod
                # -R never follow a symlink top-level arg — healing through
                # the link is a silent no-op (2026-09-22). The drift itself:
                # systemd chowns only the state DIRECTORY, never files
                # within; the dynamic uid is normally deterministic per unit
                # name (65293 since Aug 9) but a mass-restart shuffle can
                # allocate a different one → pre-existing DB files stay
                # foreign-owned → SQLITE_READONLY(8) at the first write.
                ${pkgs.coreutils}/bin/ls -lan /var/lib/private/browser-history || true
                ${pkgs.coreutils}/bin/chown -R --reference=/var/lib/private/browser-history /var/lib/private/browser-history
                ${pkgs.coreutils}/bin/chmod -R u+rwX /var/lib/private/browser-history
              ''}"
            ];
          };
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
            # Run as the desktop user — browser profiles are mode 0700 and
            # not readable by other users. ProtectHome=read-only (from the
            # upstream module) still applies; StateDirectory ownership
            # follows this user. Upstream option (agent-module user), not a
            # unit-level twin (2026-10-15 audit F4).
            user = lib.mkDefault primaryUser;
          };

          systemd.services.browser-history-agent = {
            inherit onFailure;

            serviceConfig = {
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
          systemd.services.browser-history-backup-dir = mkPoolDirUnit {
            description = "Create Browser History DB backup directory on the HDD pool";
            directory = backupDir;
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
                  # Crash-interrupted-run healing (the 2026-10-15 freeze-29/30
                  # class): a run killed mid-.backup leaves a
                  # <dst>-journal remnant whose sqlite "recovery" silently
                  # ROLLS BACK any later copy of the sibling .sqlite (the
                  # repro-harness landmine, 2026-10-15 session-2 §d1). The
                  # journal present at run start is ALWAYS stale garbage (no
                  # concurrent writer to this dir) — the journal+sqlite pair
                  # is untrustworthy as a backup, so drop BOTH loudly; a
                  # torn sibling must never look like a good backup. Orphan
                  # journals without a sibling just go.
                  find ${backupDir} -name "browser-history-db-*.sqlite-journal" | while read -r j; do
                    echo "browser-history-backup: healing crash-interrupted backup remnant: $j (+ sibling)"
                    rm -f "$j" "''${j%-journal}"
                  done
                  # -readonly: a read-write root open of the live WAL database
                  # can create/replace the -shm/-wal sidecars ROOT-owned while
                  # the server is down, poisoning the next server start with
                  # SQLITE_READONLY (the 2026-09-22 uid-drift class; the
                  # ownership-heal ExecStartPre covers any residue anyway).
                  ${lib.getExe pkgs.sqlite} -readonly "$db" ".backup '$dst'"
                  # 14-day retention (cv/miniflux pattern): the online .backup
                  # rewrites every page, so nothing is shared between nights.
                  # Journals are matched too (belt for orphans that predate
                  # the healing step or slip in after it).
                  find ${backupDir} \( -name "browser-history-db-*.sqlite" -o -name "browser-history-db-*.sqlite-journal" \) -mtime +14 -delete
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
        # the app handles OIDC natively — protectedVHost would double-auth
        # the OAuth redirect flow; passkeys are disabled server-side since
        # 2026-10-16, webauthn.enable = false above),
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
                  alert = "Browser History server down — browsing analytics unavailable. An exactly-10.0s response time is the Gatus client-timeout signature (server never answered within max-time — the 2026-10-12 burst-2 class: precedes/coincides with IO PSI 33%+ nvme write bursts; check the I/O Stall Rate check + /proc/pressure/io before blaming the server)";
                }
                {
                  # Registration-bypass + deletion/rollback detector (2026-10-15,
                  # row services.md:170): the count-gap exploitation class is
                  # invisible to MAX_USERS alone. Baseline 9 = 1 real user + 8
                  # zombie bring-up dupes (revoke queued [blocked:user]).
                  name = "Browser History User Count";
                  group = "Productivity";
                  url = "http://localhost:${toString ports.browser-history}/metrics";
                  interval = "5m";
                  conditions = [
                    "[STATUS] == 200"
                    # Anchored pat (leading \n) so the HELP comment can never
                    # satisfy the pattern (2026-08-22 class).
                    "[BODY] == pat(*\nbrowser_history_users 9\n*)"
                  ];
                  alert = "Browser History user count changed from the 2026-10-15 baseline of 9: an INCREASE = registration bypass (count-gap class — verify the MAX_USERS gate + /auth/import reachability); a DECREASE = deletion or read-model rollback. If you JUST revoked bring-up dupes ([blocked:user] row), this red is the expected confirmation — update the baseline literal in browser-history.nix and close the row.";
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
                icon = "firefox.png";
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
