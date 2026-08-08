# Browser History — Go CQRS/ES server with WebAuthn auth and Pocket ID SSO.
#
# browser-history has its OWN WebAuthn/Passkey auth system PLUS native OAuth2/OIDC
# support. When Pocket ID is enabled on the host, browser-history is automatically
# wired with Pocket ID as an OAuth2 provider — a "Login with Pocket ID" button
# appears alongside the built-in passkey registration.
#
# Caddy uses a direct TLS proxy (NOT protectedVHost) because forward-auth would
# intercept WebAuthn/OAuth2 API calls and break the registration/login flow.
#
# Secret bridging: Pocket ID provisions the client secret to
# /var/lib/pocket-id/client-secrets/browser-history (owned pocket-id:pocket-id, 640).
# The browser-history-oidc-setup oneshot reads it (as root) and writes an
# EnvironmentFile at /var/lib/browser-history/oauth2-secrets.env that the main
# service loads. This mirrors the Forgejo OIDC setup pattern.
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
        serviceDefaults
        onFailure
        ports
        ;
      cfg = config.services.browser-history;
      serverPkg =
        inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-server;
      domain = config.networking.domain;
      fqdn = "history.${domain}";
      pocketIdEnabled = config.services.pocket-id-config.enable;
      oauth2SecretsFile = "${cfg.dataDir}/oauth2-secrets.env";
    in
    {
      options.services.browser-history = {
        enable = lib.mkEnableOption "Browser History intelligence server";

        port = lib.mkOption {
          type = lib.types.port;
          default = ports.browser-history;
          description = "HTTP port for the browser-history server";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/browser-history";
          description = "Directory for the SQLite database";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.browser-history = {
          description = "Browser History intelligence server";
          inherit onFailure;
          wantedBy = [ "multi-user.target" ];
          after = [
            "network.target"
          ]
          ++ lib.optionals pocketIdEnabled [
            "pocket-id.service"
            "pocket-id-provision.service"
            "browser-history-oidc-setup.service"
          ];
          wants = lib.optionals pocketIdEnabled [ "browser-history-oidc-setup.service" ];
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          restartTriggers = [ serverPkg ];

          serviceConfig = lib.mkMerge [
            {
              ExecStart = lib.getExe serverPkg;
              WorkingDirectory = cfg.dataDir;
              StateDirectory = "browser-history";
              Environment = [
                "ADDR=127.0.0.1:${toString cfg.port}"
                "DB_PATH=${cfg.dataDir}/browser-history.db"
                "WEBAUTHN_RPID=${fqdn}"
                "WEBAUTHN_RP_NAME=BrowserHistory"
                "WEBAUTHN_ORIGINS=https://${fqdn}"
                "COOKIE_SECURE=true"
                "CSRF_ENABLED=true"
                "REQUIRE_AUTH=true"
                "OTEL_EXPORTER_OTLP_ENDPOINT=127.0.0.1:${toString ports.signoz-otlp-grpc}"
              ]
              ++ lib.optionals pocketIdEnabled [
                "OAUTH2_REDIRECT_BASE=https://${fqdn}"
                "OAUTH2_POCKET_ID_ISSUER=https://auth.${domain}"
                # OIDC discovery calls auth.${domain} via HTTPS (through Caddy).
                # Without SSL_CERT_FILE, Go on NixOS may not find the system cert
                # pool (including the dnsblockd-CA that signs internal certs).
                "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
              ];
              EnvironmentFile = lib.mkIf pocketIdEnabled [ "-${oauth2SecretsFile}" ];
            }
            (harden {
              MemoryMax = "512M";
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceDefaults { })
          ];
        };

        # Bridges the Pocket ID client secret into an env file for browser-history.
        # Pocket ID writes the secret to /var/lib/pocket-id/client-secrets/browser-history
        # (owned pocket-id:pocket-id, 640). This oneshot reads it as root and writes
        # both OAUTH2_POCKET_ID_CLIENT_ID and OAUTH2_POCKET_ID_CLIENT_SECRET to an
        # EnvironmentFile that browser-history loads via systemd.
        #
        # Writing BOTH values (not just the secret) ensures browser-history only
        # activates the Pocket ID provider when the secret is actually available.
        # If the secret is missing, the env file is removed and browser-history
        # starts in WebAuthn-only mode.
        systemd.services.browser-history-oidc-setup = lib.mkIf pocketIdEnabled {
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
      };
    };
}
