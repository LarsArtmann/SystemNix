# Browser History — Go CQRS/ES server with WebAuthn auth and productivity scoring.
#
# browser-history has its OWN WebAuthn/Passkey auth system (not Pocket ID/OIDC).
# Caddy uses a direct TLS proxy (NOT protectedVHost) because forward-auth would
# intercept WebAuthn API calls and break the registration/login flow. The app's
# built-in auth is the sole access control.
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
      serverPkg = inputs.browser-history.packages.${pkgs.stdenv.hostPlatform.system}.browser-history-server;
      domain = config.networking.domain;
      fqdn = "history.${domain}";
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
          after = [ "network.target" ];
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
              ];
            }
            (harden {
              MemoryMax = "512M";
              ReadWritePaths = [ cfg.dataDir ];
            })
            (serviceDefaults { })
          ];
        };
      };
    };
}
