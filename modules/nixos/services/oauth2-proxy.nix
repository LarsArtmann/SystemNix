# oauth2-proxy: forward-auth bridge between Caddy and Pocket ID
_: {
  flake.nixosModules.oauth2-proxy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.oauth2-proxy-config;
      inherit (config.networking) domain;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        serviceTypes
        mkSecretCheck
        ports
        ;
      proxyPort = cfg.port;

      provisionEnabled = config.services.pocket-id-config.provision.enable;
      clientSecretPath =
        if provisionEnabled then
          "${config.services.pocket-id.dataDir}/client-secrets/oauth2-proxy"
        else
          config.sops.secrets.oauth2_proxy_client_secret.path;

      checkCookieSecret = mkSecretCheck pkgs {
        name = "oauth2-proxy-cookie-secret";
        secretPath = config.sops.secrets.oauth2_proxy_cookie_secret.path;
        message = "oauth2-proxy: cookie_secret file not found: ${config.sops.secrets.oauth2_proxy_cookie_secret.path}";
        extraCheck = ''
          len=$(base64 -d < "$secret_path" | wc -c)
          if [ "$len" -ne 16 ] && [ "$len" -ne 24 ] && [ "$len" -ne 32 ]; then
            echo "oauth2-proxy: cookie_secret must be 16, 24, or 32 bytes (base64-decoded), got $len" >&2
            exit 1
          fi
        '';
      };

      waitOidcReady = pkgs.writeShellApplication {
        name = "oauth2-proxy-wait-oidc";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          echo "oauth2-proxy: waiting for OIDC endpoint at auth.${domain}..."
          # No -k: TLS verification MUST succeed so oauth2-proxy (which verifies
          # TLS for token exchange) can actually reach Pocket ID.  A -k here
          # would mask a CA mismatch and produce mysterious 500s on callback.
          curl -sf --max-time 5 --retry 60 --retry-delay 2 --retry-all-errors \
            -o /dev/null "https://auth.${domain}/.well-known/openid-configuration" \
            || {
              echo "oauth2-proxy: OIDC endpoint unreachable or TLS verification failed after 120s" >&2
              echo "  If TLS failed, the dnsblockd-CA may not match the server cert." >&2
              echo "  Compare fingerprints:" >&2
              echo "    openssl x509 -fingerprint -sha1 -noout -in /run/secrets/dnsblockd_ca_cert" >&2
              echo "    Expected: 05:3B:B1:48:34:14:4D:94:84:85:DD:DB:AC:1B:83:33:8D:15:F7:B0" >&2
              exit 1
            }
          echo "oauth2-proxy: OIDC endpoint ready (TLS verified)"
        '';
      };
    in
    {
      options.services.oauth2-proxy-config = {
        enable = lib.mkEnableOption "oauth2-proxy forward-auth with SystemNix configuration";
        port = serviceTypes.servicePort ports.oauth2-proxy "Port for oauth2-proxy";
      };

      config = lib.mkIf cfg.enable {
        services.oauth2-proxy = {
          enable = true;
          provider = "oidc";
          oidcIssuerUrl = "https://auth.${domain}";
          clientID = "oauth2-proxy";
          clientSecretFile = clientSecretPath;
          redirectURL = "https://auth.${domain}/oauth2/callback";
          httpAddress = "http://127.0.0.1:${toString proxyPort}";
          scope = "openid profile email";
          reverseProxy = true;
          trustedProxyIP = [ "127.0.0.1" ];
          setXauthrequest = true;
          email.domains = [ "*" ];
          cookie = {
            domain = ".${domain}";
            secure = true;
            secretFile = config.sops.secrets.oauth2_proxy_cookie_secret.path;
          };
          extraConfig = {
            skip-provider-button = true;
          };
        };

        systemd.services.oauth2-proxy = {
          inherit onFailure;
          after = [
            "network-online.target"
            "pocket-id.service"
            "dnsblockd.service"
          ]
          ++ lib.optional provisionEnabled "pocket-id-provision.service";
          wants = [
            "network-online.target"
            "pocket-id.service"
            "dnsblockd.service"
          ]
          ++ lib.optional provisionEnabled "pocket-id-provision.service";
          unitConfig = {
            StartLimitBurst = lib.mkForce 10;
            StartLimitIntervalSec = lib.mkForce 300;
          };
          serviceConfig = lib.mkMerge [
            (harden { })
            (serviceDefaults { })
            {
              ExecStartPre = [
                "+${lib.getExe checkCookieSecret}"
                "+${lib.getExe waitOidcReady}"
              ];
              ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://127.0.0.1:${toString proxyPort}/ping";
            }
          ];
          # Explicit CA bundle path for Go's crypto/tls on NixOS.
          # /etc/ssl/certs/ca-certificates.crt is the NixOS-merged bundle that
          # includes both the Mozilla roots and the dnsblockd-CA from
          # security.pki.certificates.  Without SSL_CERT_FILE, some Go binaries
          # on NixOS silently fail to find the system cert pool, causing
          # token-exchange 500 errors against TLS-terminated upstreams.
          environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        };
      };
    };
}
