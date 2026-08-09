# Browser History — SystemNix wrapper around upstream NixOS modules.
#
# The upstream modules (inputs.browser-history.nixosModules.browser-history-server
# and .browser-history-agent) provide all options, defaults, assertions, and
# security hardening. This file layers ONLY SystemNix-specific concerns:
#   - Package wiring from the flake input
#   - Port assignment from the central registry
#   - WebAuthn/OAuth2 domain configuration
#   - OTel endpoint
#   - Agent token via sops (shared between server and agent)
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
        onFailure
        ports
        serviceOneshotDefaults
        ;

      cfg = config.services.browser-history;
      serverPkg =
        inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-server;
      agentPkg = inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-agent;
      primaryUser = config.users.primaryUser or "lars";
      sopsEnvPath = config.sops.templates."browser-history-env".path;

      domain = config.networking.domain;
      fqdn = "history.${domain}";
      pocketIdEnabled = config.services.pocket-id-config.enable;
      oauth2SecretsFile = "/var/lib/browser-history-oidc/oauth2-secrets.env";
    in
    {
      imports = [
        inputs.browser-history.nixosModules.browser-history-server
        inputs.browser-history.nixosModules.browser-history-agent
      ];

      config = lib.mkMerge [
        # ── Server: deployment-specific values (upstream defaults handle the rest) ──
        (lib.mkIf cfg.enable {
          services.browser-history = {
            package = lib.mkDefault serverPkg;
            address = lib.mkDefault "127.0.0.1:${toString ports.browser-history}";
            webauthn.rpId = lib.mkDefault fqdn;
            webauthn.rpName = lib.mkDefault "BrowserHistory";
            webauthn.origins = lib.mkDefault [ "https://${fqdn}" ];
            otelEndpoint = lib.mkDefault "127.0.0.1:${toString ports.signoz-otlp-grpc}";
          };

          systemd.services.browser-history = {
            onFailure = onFailure;
            restartTriggers = [ serverPkg ];

            # Agent token from sops. Systemd reads EnvironmentFile as root,
            # so root-owned sops template works for the DynamicUser server.
            serviceConfig.EnvironmentFile = [ sopsEnvPath ];
          };
        })

        # ── Pocket ID OAuth2 integration ───────────────────────────────────────────
        (lib.mkIf (cfg.enable && pocketIdEnabled) {
          services.browser-history = {
            oauth2.redirectBase = lib.mkDefault "https://${fqdn}";
          };

          systemd.services.browser-history = {
            after = [
              "pocket-id.service"
              "pocket-id-provision.service"
              "browser-history-oidc-setup.service"
            ];
            wants = [ "browser-history-oidc-setup.service" ];

            # SSL_CERT_FILE: OIDC discovery calls auth.${domain} via HTTPS
            # (through Caddy). Without this, Go on NixOS may not find the
            # system cert pool (including the dnsblockd-CA that signs internal certs).
            environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";

            # "-" prefix = optional: won't fail if the file is missing (graceful
            # degradation to WebAuthn-only mode). Merges with the sops EnvironmentFile
            # from the server block above (NixOS list concatenation).
            serviceConfig.EnvironmentFile = [ "-${oauth2SecretsFile}" ];
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
          systemd.services.browser-history-oidc-setup = {
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
                echo "browser-history-oidc-setup: Pocket ID secret not found — starting in WebAuthn-only mode"
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
        (lib.mkIf config.services.browser-history-agent.enable {
          services.browser-history-agent = {
            package = lib.mkDefault agentPkg;
            tokenFile = lib.mkDefault sopsEnvPath;
          };

          systemd.services.browser-history-agent = {
            onFailure = onFailure;

            # Run as the desktop user — browser profiles are mode 0700 and
            # not readable by other users. ProtectHome=read-only (from the
            # upstream module) still applies.
            serviceConfig = {
              User = primaryUser;
              MemoryMax = lib.mkDefault "512M";
            };
          };
        })
      ];
    };
}
