# Pocket ID: passkey-only OIDC provider replacing Authelia
_: {
  flake.nixosModules.pocket-id = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.pocket-id-config;
    inherit (config.networking) domain;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure serviceTypes;
    pocketIdPort = cfg.port;
    metricsPort = cfg.metricsPort;

    inherit (import ../../../lib/default.nix lib) mkSecretCheck;
    checkEncryptionKey = mkSecretCheck pkgs {
      name = "pocket-id-encryption-key";
      secretPath = config.sops.secrets.pocket_id_encryption_key.path;
      message = "pocket-id: ENCRYPTION_KEY is missing or empty (${config.sops.secrets.pocket_id_encryption_key.path})\n  Run: just auth-bootstrap";
    };
  in {
    options.services.pocket-id-config = {
      enable = lib.mkEnableOption "Pocket ID passkey OIDC provider with SystemNix configuration";
      port = serviceTypes.servicePort 1411 "Port for Pocket ID";
      metricsPort = serviceTypes.servicePort 9464 "Port for Pocket ID Prometheus metrics";
    };

    config = lib.mkIf cfg.enable {
      services.pocket-id = {
        enable = true;
        settings = {
          APP_URL = "https://auth.${domain}";
          TRUST_PROXY = true;
          ANALYTICS_DISABLED = true;
          HOST = "127.0.0.1";
          PORT = toString pocketIdPort;
          METRICS_ENABLED = true;
          OTEL_EXPORTER_PROMETHEUS_HOST = "127.0.0.1";
          OTEL_EXPORTER_PROMETHEUS_PORT = toString metricsPort;
        };
        credentials = {
          ENCRYPTION_KEY = config.sops.secrets.pocket_id_encryption_key.path;
        };
      };

      systemd.services.pocket-id = {
        inherit onFailure;
        unitConfig = {
          StartLimitBurst = lib.mkForce 3;
          StartLimitIntervalSec = lib.mkForce 300;
        };
        serviceConfig =
          serviceDefaults {}
          // harden {MemoryMax = "512M";}
          // {
            ExecStartPre = "+${lib.getExe checkEncryptionKey}";
            ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://127.0.0.1:${toString pocketIdPort}/healthz";
          };
      };
    };
  };
}
