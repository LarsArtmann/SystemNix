# oauth2-proxy: forward-auth bridge between Caddy and Pocket ID
_: {
  flake.nixosModules.oauth2-proxy = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.oauth2-proxy-config;
    inherit (config.networking) domain;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure serviceTypes;
    proxyPort = cfg.port;
  in {
    options.services.oauth2-proxy-config = {
      enable = lib.mkEnableOption "oauth2-proxy forward-auth with SystemNix configuration";
      port = serviceTypes.servicePort 4180 "Port for oauth2-proxy";
    };

    config = lib.mkIf cfg.enable {
      services.oauth2-proxy = {
        enable = true;
        provider = "oidc";
        oidcIssuerUrl = "https://auth.${domain}";
        clientID = "oauth2-proxy";
        clientSecretFile = config.sops.secrets.oauth2_proxy_client_secret.path;
        redirectURL = "https://auth.${domain}/oauth2/callback";
        httpAddress = "http://127.0.0.1:${toString proxyPort}";
        scope = "openid profile email";
        reverseProxy = true;
        trustedProxyIP = ["127.0.0.1"];
        setXauthrequest = true;
        email.domains = ["*"];
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
        after = ["pocket-id.service"];
        wants = ["pocket-id.service"];
        unitConfig = {
          StartLimitBurst = lib.mkForce 3;
          StartLimitIntervalSec = lib.mkForce 300;
        };
        serviceConfig =
          harden {}
          // serviceDefaults {}
          // {
            ExecStartPre = "+${pkgs.writeShellApplication {
              name = "check-cookie-secret";
              runtimeInputs = [pkgs.coreutils];
              text = ''
                secret_path="${config.sops.secrets.oauth2_proxy_cookie_secret.path}"
                if [ ! -f "$secret_path" ]; then
                  echo "oauth2-proxy: cookie_secret file not found: $secret_path" >&2
                  exit 1
                fi
                len=$(base64 -d < "$secret_path" | wc -c)
                if [ "$len" -ne 16 ] && [ "$len" -ne 24 ] && [ "$len" -ne 32 ]; then
                  echo "oauth2-proxy: cookie_secret must be 16, 24, or 32 bytes (base64-decoded), got $len" >&2
                  exit 1
                fi
              '';
            }}";
            ExecStartPost = "${pkgs.curl}/bin/curl -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://127.0.0.1:${toString proxyPort}/ping";
          };
      };
    };
  };
}
