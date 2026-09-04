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
            -label "${machineId}" \
            ${lib.optionalString (config.services.browser-history-agent.tokenUserEmail != null) ''-user-email "${config.services.browser-history-agent.tokenUserEmail}" \''}
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
        runtimeInputs = [ pkgs.curl ];
        text = ''
          SERVER_URL="http://127.0.0.1:${toString ports.browser-history}/health"
          echo "browser-history-agent: waiting for server at $SERVER_URL ..."
          # The server's projection drain after a restart takes up to ~5 min
          # (no persistent checkpoint store upstream; replays ALL events).
          # A 60s gate aborted during every deploy window, and with the
          # deliberate startLimitBurst=2 that bricked the agent until a manual
          # reset-failed. 7 min covers the observed worst case (4m50s) + margin.
          curl -sf --max-time 5 --retry 60 --retry-delay 7 --retry-all-errors \
            -o /dev/null "$SERVER_URL" \
            || { echo "browser-history-agent: server not ready after 7min, aborting" >&2; exit 1; }
          echo "browser-history-agent: server ready"
        '';
      };

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
      ];
    };
}
