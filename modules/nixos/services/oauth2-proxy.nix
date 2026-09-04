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
        mkOidcGate
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
            # PKCE (Proof Key for Code Exchange) — prevents authorization code
            # interception attacks. Pocket ID supports S256 (SHA-256 hash method).
            # Immich and Monitor365 already use PKCE with Pocket ID successfully.
            code-challenge-method = "S256";
            # Allow post-login redirect back to any *.home.lan service protected
            # by this oauth2-proxy instance. Without this, the OIDC callback
            # succeeds but the final redirect to the original vHost is rejected
            # with "domain / port not in whitelist" and the user sees a 500.
            whitelist-domain = [ ".${domain}" ];
          };
        };

        systemd.services.oauth2-proxy =
          let
            oidcGate = mkOidcGate {
              inherit pkgs domain;
              serviceName = "oauth2-proxy";
              includeProvision = provisionEnabled;
            };
          in
          {
            inherit onFailure;
            # Restart when provision runs: oauth2-proxy loads the client secret
            # via systemd LoadCredential at start time. If provision regenerates
            # the secret (e.g. after desync recovery), oauth2-proxy must restart
            # to pick up the new credential.
            partOf = lib.optional provisionEnabled "pocket-id-provision.service";
            inherit (oidcGate) after;
            inherit (oidcGate) wants;
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
                ]
                ++ oidcGate.serviceConfig.ExecStartPre;
                # Must exceed the 300s OIDC gate budget (slow-boot dnsblockd)
                TimeoutStartSec = "6min";
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
