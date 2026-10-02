# Runbook: docs/services/crm.md
# Ledger CRM — LarsArtmann's own event-sourced personal CRM (Go +
# go-cqrs-lite), replacing the Twenty docker-compose stack. Self-contained
# module: the upstream flake (github:LarsArtmann/crm) exposes packages
# only, so this file owns the whole service shape, ported from the crm
# repo's deploy/crm-server.service (the 2026-09-18 pre-module unit):
#
#   - the LIVE journal stays at ~/.local/share/crm/ledger.db — NO data
#     migration on adoption (standing decision, crm repo deploy header;
#     a home-server move changes User=/paths only)
#   - WebAuthn passkey auth (-auth) rides the cqrs-htmx identity stack.
#     /healthz stays unauthenticated for Gatus (crm main.go: "always 200
#     while the process can serve at all ... deliberately OUTSIDE the
#     auth gate")
#   - the -api-token bearer gate (the Twenty-compatible /rest surface the
#     CV pipeline sync mirrors into) is INDEPENDENT of the passkey session
#     gate (api.go: "called OUTSIDE the CRM's session gate") — the CV
#     syncer keeps working headless with -auth on
#   - CUTOVER SEMANTICS: while services.twenty.enable is true, Twenty
#     keeps the crm.<domain> vHost and the dashboard tile; the Ledger
#     serves loopback only (still monitored + backed up). Flipping
#     twenty.enable = false (the freeze, 2026-10-02 cutover micro-plan
#     T42) hands the subdomain over ATOMICALLY in the same deploy — the
#     integration registry keys vHosts by subdomain and two claims would
#     collide loudly by design (integration.nix).
{ inputs, ... }:
{
  flake.nixosModules.crm =
    {
      config,
      options,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        ports
        serviceTypes
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        ioTier
        ;
      cfg = config.services.crm-server;
      domain = config.networking.domain;
      user = config.users.primaryUser;
      group = "users";
      # The LIVE journal directory (home, NOT StateDirectory — the standing
      # 2026-09-18 decision: the unit adopts the journal in place).
      stateDir = "/home/${user}/.local/share/crm";
      backupDir = "/mnt/pool/backups/crm";
      crmPkg = inputs.crm.packages.${pkgs.stdenv.hostPlatform.system}.default;
      twentyEnabled = config.services.twenty.enable or false;
    in
    {
      imports = [
        # Platform-truth catalog entry (ADR-008): unconditional — the
        # Ledger CRM platform service exists wherever the module set is
        # imported, even where this host has it disabled. Requires
        # nixosModules.catalog (auto-discovered; VM tests must co-import).
        {
          services.catalog.crm = {
            subdomain = "crm";
            port = ports.crm;
            description = "Ledger CRM (event-sourced, passkey-authed)";
            healthPath = "/healthz";
          };
        }
      ];

      options.services.crm-server = {
        enable = lib.mkEnableOption "Ledger CRM (crm-server)";

        package = lib.mkOption {
          type = lib.types.package;
          default = crmPkg;
          defaultText = "inputs.crm.packages.<system>.default";
          description = "crm-server package from the github:LarsArtmann/crm flake";
        };

        port = serviceTypes.servicePort ports.crm "Host port for the Ledger CRM server (loopback)";

        auth = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              WebAuthn passkey auth (-auth): every CRM route rides the
              cqrs-htmx identity session gate; /healthz and the bearer
              -api-token surface stay independent. First visit registers
              the sole passkey (MaxUsers=1 closes registration). Escape
              hatch if the ceremony is ever locked out: set to false and
              redeploy (docs/ops/PASSKEY-RECOVERY.md documents the API
              path in the crm repo).
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        # The raw secret is declared UNCONDITIONALLY (outside mkIf): the
        # sops cv-env template in sops.nix references
        # config.sops.placeholder.crm_api_token to activate the CV syncer
        # (CV_CRM_API_KEY), and a placeholder for an undeclared secret
        # fails activation wherever cv.nix lands without this module.
        # The VALUE (encrypted in platforms/nixos/secrets/crm.yaml with
        # the host age PUBLIC key — creatable without root, bank-sync-
        # encryption pattern) is the same token the pre-module era stored
        # at ~/.local/share/crm/api-token; cv.nix derives its base_url
        # from ports.crm.
        sops.secrets.crm_api_token = {
          sopsFile = ../../../platforms/nixos/secrets/crm.yaml;
          restartUnits = [ "crm-server.service" ];
        };

        sops.templates."crm-server-env" = {
          # PID 1 reads EnvironmentFile as root before dropping to the
          # unit user; root ownership matches the cv-env pattern.
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [ "crm-server.service" ];
          content = lib.generators.toKeyValue { } {
            # Guards the machine API (/api + /rest): the CV pipeline sync
            # surface. Read/rotate: sudo sops platforms/nixos/secrets/crm.yaml
            API_TOKEN = config.sops.placeholder.crm_api_token;
          };
        };

        systemd.services = {
          crm-server = {
            description = "Ledger CRM (event-sourced personal CRM)";
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            environment = {
              # Go GC ceiling under the unit MemoryMax (cv-server pattern).
              GOMEMLIMIT = "768MiB";
            };
            serviceConfig = lib.mkMerge [
              {
                User = user;
                Group = group;
                EnvironmentFile = [ config.sops.templates."crm-server-env".path ];
                ExecStart = lib.concatStringsSep " " (
                  [
                    "${cfg.package}/bin/crm-server"
                    "-addr 127.0.0.1:${toString cfg.port}"
                    "-db ${stateDir}/ledger.db"
                    "-identity-db ${stateDir}/identity.db"
                    "-api-token \${API_TOKEN}"
                  ]
                  ++ lib.optionals cfg.auth.enable [
                    "-auth"
                    "-rpid crm.${domain}"
                    "-origin https://crm.${domain}"
                    # HTTPS posture: Secure on session+CSRF cookies (the
                    # vHost serves TLS; loopback HTTP is not used).
                    "-secure true"
                  ]
                );
                # Strict + exactly one writable carve-out: the journal dir.
                # Everything else on the filesystem is read-only to the
                # process (ported from deploy/crm-server.service).
              }
              (harden {
                ProtectSystem = "strict";
                ProtectHome = "read-only";
                ReadWritePaths = [ stateDir ];
                MemoryMax = "1G";
              })
              (serviceDefaults { })
            ];
          };

          # Pool leaf creator (cv-backup-dir / miniflux-backup-dir pattern).
          crm-backup-dir = {
            description = "Create Ledger CRM backup directory on the HDD pool";
            wantedBy = [ "multi-user.target" ];
            unitConfig.RequiresMountsFor = [ "/mnt/pool" ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                RemainAfterExit = true;
              }
              # ReadWritePaths targets the MOUNT ROOT (226/NAMESPACE
              # lesson): on a fresh pool the leaf does not exist yet.
              # CAP_CHOWN survives the empty bounding set so the chown
              # below can run (miniflux-backup-dir pattern).
              (harden {
                MemoryMax = "128M";
                ReadWritePaths = [ "/mnt/pool" ];
                CapabilityBoundingSet = "CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE";
              })
              (serviceOneshotDefaults { })
            ];
            script = ''
              mkdir -p ${backupDir}
              chown ${user}:${group} ${backupDir}
              chmod 0755 ${backupDir}
            '';
          };

          # Nightly WAL-safe journal snapshot (the sqlite backup API — a
          # consistent standalone copy against a RUNNING server; ported
          # from the crm repo's scripts/backup-ledger.sh). The journal is
          # the source of truth: projections are disposable.
          crm-backup = {
            description = "Ledger CRM journal backup (WAL-safe sqlite snapshot)";
            after = [
              "crm-server.service"
              "crm-backup-dir.service"
            ];
            wants = [ "crm-backup-dir.service" ];
            # Order AFTER the pool mount: a detached DAS fails the run as
            # a clean dependency error instead of 226/NAMESPACE.
            unitConfig.RequiresMountsFor = [ backupDir ];
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            path = [ pkgs.python3 ];
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = user;
                Group = group;
                ReadWritePaths = [ backupDir ];
                script = ''
                  set -euo pipefail
                  dst="${backupDir}/ledger-$(date +%Y-%m-%d).db"
                  python3 - "${stateDir}/ledger.db" "$dst" <<'PY'
                  import sqlite3, sys

                  src = sqlite3.connect(sys.argv[1])
                  dst = sqlite3.connect(sys.argv[2])
                  src.backup(dst)
                  dst.close()
                  src.close()
                  PY
                  chmod 0644 "$dst"
                  # 30-day retention (twenty pg_dump pattern): one snapshot
                  # per night, oldest fall off.
                  find ${backupDir} -name "ledger-*.db" -mtime +30 -delete
                  echo "crm-backup: wrote $dst"
                '';
              }
              (serviceOneshotDefaults { })
              ioTier.background
            ];
          };
        };

        systemd.timers.crm-backup = {
          description = "Nightly Ledger CRM journal backup";
          wantedBy = [ "timers.target" ];
          after = [ "mnt-pool.mount" ];
          timerConfig = {
            # 03:40 — staggered after miniflux (02:45) and cv (03:17),
            # before work hours (the pre-module crm-backup.timer slot).
            OnCalendar = "*-*-* 03:40:00";
            RandomizedDelaySec = "10min";
            Persistent = true;
          };
        };

        # Service-integration registry entry: ONE declaration fans out to
        # Caddy vHost, Gatus checks, dashboard tile, backup freshness, and
        # system-health monitored-unit metrics. Layer "plain": the Ledger
        # carries its OWN auth (WebAuthn passkeys) — a "protected" layer
        # would double-auth (native-OIDC double-auth doctrine).
        # The vHost + tile stay dormant while Twenty owns the subdomain
        # (see the cutover note in the module header); the loopback health
        # check + backup + monitoring are live from day one.
        services.integration = lib.optionalAttrs (options ? services.integration) {
          crm-server = {
            subdomain = "crm";
            inherit (cfg) port;
            vHost.layer = if twentyEnabled then "none" else "plain";
            checks = [
              {
                # Functional liveness: /healthz is the server's own probe
                # (unauthenticated by design, main.go) — green means the
                # mux serves.
                name = "Ledger CRM";
                group = "Productivity";
                path = "/healthz";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "Ledger CRM down — the event-sourced journal-serving surface is unreachable (unit crm-server). Check: systemctl status crm-server, journalctl -u crm-server";
              }
            ];
            # Tile appears with the vHost claim (cutover): while Twenty
            # lives, its "Twenty CRM" tile owns the crm.<domain> href.
            homepage = if twentyEnabled then null else {
              name = "Ledger CRM";
              group = "Productivity";
              description = "Event-sourced personal CRM (passkey)";
            };
            backup = {
              # Nightly WAL-safe journal snapshot (crm-backup.timer, 03:40)
              # onto the mirrored pool.
              directory = "/mnt/pool/backups/crm";
              filePattern = "ledger-*.db";
              maxAgeHours = 26;
            };
            monitored = true;
          };
        };
      };
    };
}
