# Miniflux — minimalist self-hosted RSS reader (single Go binary + PostgreSQL).
# Wraps the nixpkgs module (services.miniflux) with SystemNix wiring:
#   - Layer 1 native OIDC via Pocket ID. Miniflux reads the client secret from
#     a FILE (OAUTH2_CLIENT_SECRET_FILE), so the Pocket ID provisioner's secret
#     reaches the DynamicUser service via systemd LoadCredential (%d) — zero
#     bridge oneshots, no EnvironmentFile surgery. OIDC discovery is lazy
#     (per-login request, non-fatal when unreachable — verified in miniflux
#     internal/oauth2/manager.go), so the mkOidcGate only needs to prove the
#     TLS/DNS chain is ready, not bootstrap the provider.
#   - sops admin credentials (break-glass password login; OIDC user creation
#     auto-provisions the daily-driver account on first login).
#   - Nightly pg_dump (custom format) onto the HDD pool, cv-backup pattern
#     (mount-gated dir oneshot + RequiresMountsFor + retention).
_: {
  flake.nixosModules.miniflux =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.miniflux;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        ports
        mkOidcGate
        ;
      domain = config.networking.domain;
      backupDir = "/mnt/pool/backups/miniflux";

      # Native OIDC (Layer 1) — plain reverse_proxy in caddy.nix, NEVER
      # protectedVHost (forward-auth + the app's own OIDC login = double-auth).
      enableOidc =
        (config.services.pocket-id-config.enable or false)
        && (config.services.pocket-id-config.provision.enable or false);
      oidcGate = mkOidcGate {
        inherit pkgs domain;
        serviceName = "miniflux";
      };
    in
    {
      config = lib.mkIf cfg.enable {
        services.miniflux = {
          config = {
            LISTEN_ADDR = "127.0.0.1:${toString ports.miniflux}";
            BASE_URL = "https://rss.${domain}/";
          }
          // (lib.optionalAttrs enableOidc {
            OAUTH2_PROVIDER = "oidc";
            OAUTH2_OIDC_PROVIDER_NAME = "Pocket ID";
            OAUTH2_CLIENT_ID = "miniflux";
            # %d = the unit's CREDENTIALS_DIRECTORY (systemd specifier); the file
            # is bind-mounted from the Pocket ID provisioner via LoadCredential.
            OAUTH2_CLIENT_SECRET_FILE = "%d/miniflux-oidc-secret";
            # The OIDC library appends .well-known/openid-configuration itself —
            # pass the bare issuer URL (miniflux docs requirement).
            OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://auth.${domain}";
            OAUTH2_USER_CREATION = 1;
          });
          adminCredentialsFile = config.sops.secrets."miniflux_admin_credentials".path;
        };

        sops.secrets = lib.optionalAttrs cfg.enable {
          "miniflux_admin_credentials" = {
            sopsFile = ../../../platforms/nixos/secrets/miniflux.yaml;
            # DynamicUser service: systemd (PID 1) reads EnvironmentFile as
            # root — the miniflux user does not exist to own files.
            # Default owner root satisfies dynamic-user-audit.
            restartUnits = [ "miniflux.service" ];
          };
        };

        systemd.services.miniflux = {
          description = lib.mkForce "Miniflux RSS reader";
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          # The OIDC discovery/token calls go through Caddy's TLS (dnsblockd-CA
          # signed) — Go needs the system trust store (browser-history pattern).
          environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
          inherit (oidcGate) after wants;
          serviceConfig = lib.mkMerge [
            { MemoryMax = "512M"; }
            ioTier.background
            (lib.optionalAttrs enableOidc {
              LoadCredential = [
                "miniflux-oidc-secret:${config.services.pocket-id.dataDir}/client-secrets/miniflux"
              ];
            })
            oidcGate.serviceConfig
          ];
        };

        # Nightly backup of the whole Miniflux state (PostgreSQL only — the
        # app is stateless). pg_dump custom format as the postgres superuser
        # over peer auth; cv-backup dir-oneshot pattern for the pool leaf.
        systemd.services.miniflux-backup-dir = {
          description = "Create Miniflux backup directory on the HDD pool";
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "root";
              RemainAfterExit = true;
            }
            # ReadWritePaths targets the MOUNT ROOT (cv-backup-dir 226/NAMESPACE
            # lesson): on a fresh pool the leaf does not exist yet.
            (harden {
              MemoryMax = "128M";
              ReadWritePaths = [ "/mnt/pool" ];
              # chown to postgres so the dumper (User=postgres) can write;
              # harden{}'s empty bounding set would strip CAP_CHOWN.
              CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
            })
            (serviceOneshotDefaults { })
          ];
          script = ''
            mkdir -p ${backupDir}
            chown postgres:postgres ${backupDir}
            chmod 0755 ${backupDir}
          '';
        };

        systemd.services.miniflux-backup = {
          description = "Miniflux PostgreSQL backup (pg_dump custom format)";
          after = [
            "postgresql.target"
            "miniflux.service"
            "miniflux-backup-dir.service"
          ];
          wants = [
            "miniflux-backup-dir.service"
            "postgresql.target"
          ];
          # Order AFTER the pool mount: a detached DAS fails the run as a clean
          # dependency error instead of 226/NAMESPACE (btrbk doctrine).
          unitConfig.RequiresMountsFor = [ backupDir ];
          inherit onFailure;
          startLimitBurst = 5;
          startLimitIntervalSec = 300;
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = "postgres";
              Group = "postgres";
              ExecStart = pkgs.writeShellScript "miniflux-backup" ''
                set -euo pipefail
                dst="${backupDir}/miniflux-$(date +%Y-%m-%d).dump"
                ${config.services.postgresql.package}/bin/pg_dump \
                  --format=custom --file="$dst" miniflux
                chmod 0644 "$dst"
                # 14-day retention (cv-backup pattern): full dump each night.
                find ${backupDir} -name "miniflux-*.dump" -mtime +14 -delete
                echo "miniflux-backup: wrote $dst"
              '';
              ReadWritePaths = [ backupDir ];
            }
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        systemd.timers.miniflux-backup = {
          description = "Nightly Miniflux PostgreSQL backup";
          wantedBy = [ "timers.target" ];
          after = [ "mnt-pool.mount" ];
          timerConfig = {
            # 02:45 — staggered between manifest (02:30) and cv (03:17).
            OnCalendar = "*-*-* 02:45:00";
            RandomizedDelaySec = "10min";
            Persistent = true;
          };
        };
      };
    };
}
