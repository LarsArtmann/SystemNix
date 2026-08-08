# Browser History — SystemNix wrapper around upstream NixOS modules.
#
# The upstream modules (inputs.browser-history.nixosModules.browser-history-server
# and .browser-history-agent) provide all options, defaults, assertions, and
# security hardening. This file layers ONLY SystemNix-specific concerns:
#   - Package wiring from the flake input
#   - Port assignment from the central registry
#   - WebAuthn/OAuth2 domain configuration
#   - OTel endpoint
#   - Pocket ID OIDC secret bridging (oneshot reads Pocket ID's provisioned
#     secret and writes an EnvironmentFile for browser-history)
#   - SSL_CERT_FILE for internal CA (OIDC discovery via Caddy's CA-signed cert)
#   - onFailure alert routing
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
        onFailure
        ports
        ;

      cfg = config.services.browser-history;
      serverPkg = inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-server;
      agentPkg = inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-agent;

      domain = config.networking.domain;
      fqdn = "history.${domain}";
      pocketIdEnabled = config.services.pocket-id-config.enable;
      oauth2SecretsFile = "/var/lib/browser-history/oauth2-secrets.env";
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
          };
        })

        # ── Pocket ID OAuth2 integration ───────────────────────────────────────────
        (lib.mkIf (cfg.enable && pocketIdEnabled) {
          services.browser-history = {
            oauth2.redirectBase = lib.mkDefault "https://${fqdn}";
            oauth2.pocketId.clientId = lib.mkDefault "browser-history";
            oauth2.pocketId.issuer = lib.mkDefault "https://auth.${domain}";
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
            # degradation to WebAuthn-only mode).
            serviceConfig.EnvironmentFile = [ "-${oauth2SecretsFile}" ];
          };

          # Bridges the Pocket ID client secret into an env file.
          # Pocket ID writes the secret to /var/lib/pocket-id/client-secrets/browser-history
          # (owned pocket-id:pocket-id, 640). This oneshot reads it as root and writes
          # an EnvironmentFile at /var/lib/browser-history/oauth2-secrets.env that
          # browser-history loads via systemd.
          systemd.services.browser-history-oidc-setup = {
            description = "Browser History — Pocket ID OAuth2 secret provisioning";
            after = [ "pocket-id-provision.service" ];
            wants = [ "pocket-id-provision.service" ];
            before = [ "browser-history.service" ];
            wantedBy = [ "browser-history.service" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };

            path = [
              pkgs.coreutils
              pkgs.bash
            ];

            script = ''
              SECRET_FILE="/var/lib/pocket-id/client-secrets/browser-history"

              # Wait up to 120s for Pocket ID to provision the client secret.
              timeout 120 bash -c 'until [ -s "$1" ]; do sleep 2; done' _ "$SECRET_FILE" || true

              if [ ! -s "$SECRET_FILE" ]; then
                echo "browser-history-oidc-setup: Pocket ID secret not found — starting in WebAuthn-only mode"
                rm -f "${oauth2SecretsFile}"
                exit 0
              fi

              install -d -m 0755 "$(dirname "${oauth2SecretsFile}")"
              {
                echo "OAUTH2_POCKET_ID_CLIENT_ID=browser-history"
                echo "OAUTH2_POCKET_ID_CLIENT_SECRET=$(cat "$SECRET_FILE")"
              } > "${oauth2SecretsFile}"
              chmod 600 "${oauth2SecretsFile}"
              echo "browser-history-oidc-setup: Pocket ID OAuth2 secret written"
            '';
          };
        })

        # ── Agent: defaults for machines that enable it ────────────────────────────
        # Individual machines enable + configure the agent in their configuration:
        #   services.browser-history-agent = {
        #     enable = true;
        #     package = inputs.browser-history.packages.${system}.browser-history-agent;
        #     serverUrl = "https://history.${domain}";
        #     tokenFile = ...;
        #     machineId = "desktop";
        #   };
        (lib.mkIf config.services.browser-history-agent.enable {
          services.browser-history-agent.package = lib.mkDefault agentPkg;
        })
      ];
    };
}
