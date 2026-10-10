# Runbook: docs/services/crm.md
# Kith CRM — LarsArtmann's own event-sourced personal CRM (Go +
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
#   - NATIVE OIDC (2026-10-10): Pocket ID sign-in rides BESIDE the
#     passkeys (Layer 1 in docs/agents/sso-dns.md — the oauth2-proxy
#     Layer 2 gate bypasses LAN clients, and crm.<domain> IS a LAN
#     hostname, so only in-app OIDC covers them). Passkeys stay as the
#     break-glass path; an unreachable Pocket ID at boot degrades to
#     passkey-only (crm-server logs loudly, stays up).
#   - the -api-token bearer gate (the Twenty-compatible /rest surface the
#     CV pipeline sync mirrors into) is INDEPENDENT of the passkey session
#     gate (api.go: "called OUTSIDE the CRM's session gate") — the CV
#     syncer keeps working headless with -auth on
#   - CUTOVER SEMANTICS: while services.twenty.enable is true, Twenty
#     keeps the crm.<domain> vHost and the dashboard tile; the Kith
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
      # Native OIDC (Pocket ID): clientId keys the provisioned Pocket ID
      # client AND the secret path the bridge reads; the provider key
      # "pocket-id" forms the callback route segment
      # /auth/oauth/pocket-id/callback (crm identity.go flag wiring).
      crmOidcClientId = "crm";
      # Where the crm-oidc-env bridge writes CRM_OIDC_CLIENT_SECRET (the
      # cv-oidc-env pattern: StateDirectory owns /var/lib/crm-oidc).
      oidcEnvFile = "/var/lib/crm-oidc/client-secret.env";
      # OIDC rides only when Pocket ID's provisioning layer is on (the cv
      # pattern): without it no client secret exists and the flags would
      # point at a client Pocket ID has never heard of.
      pocketIdProvisioned = config.services.pocket-id-config.provision.enable or false;
      # TEMPORARY vendorHash shim (RE-PINNED 2026-10-10 — class comment at
      # lib/lars-packages.nix): got t1CRZVb6… at local crm tip 9df0c4a
      # (native Pocket ID OIDC: new usermgmt/oauth2 require + sibling lock
      # bump; first-hand FOD build, git+file:///home/lars/projects/crm#default).
      # STRUCTURAL, not lock-wave drift: upstream bakes ITS OWN hash under
      # ITS pinned go-nix-helpers while our flake resolves crm's full lock
      # graph — the overview precedent: upstream's hash can never match our
      # graph, so this shim does not converge by lock movement alone.
      crmPkg = inputs.crm.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
        vendorHash = "sha256-t1CRZVb6uS3V6PYQvev/WR0i/yvJKgl+MAy89Srx0Is=";
      };
      twentyEnabled = config.services.twenty.enable or false;
    in
    {
      imports = [
        # Platform-truth catalog entry (ADR-008): unconditional — the
        # Kith CRM platform service exists wherever the module set is
        # imported, even where this host has it disabled. Requires
        # nixosModules.catalog (auto-discovered; VM tests must co-import).
        {
          services.catalog.crm = {
            subdomain = "crm";
            port = ports.crm;
            description = "Kith CRM (event-sourced, passkey-authed)";
            healthPath = "/healthz";
          };
        }
      ];

      options.services.crm-server = {
        enable = lib.mkEnableOption "Kith CRM (crm-server)";

        package = lib.mkOption {
          type = lib.types.package;
          default = crmPkg;
          defaultText = "inputs.crm.packages.<system>.default";
          description = "crm-server package from the github:LarsArtmann/crm flake";
        };

        port = serviceTypes.servicePort ports.crm "Host port for the Kith CRM server (loopback)";

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
            description = "Kith CRM (event-sourced personal CRM)";
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
                  ++ lib.optionals pocketIdProvisioned [
                    # Native OIDC (Pocket ID beside the passkey login).
                    # The client secret rides CRM_OIDC_CLIENT_SECRET from
                    # the crm-oidc-env bridge (environment, never argv).
                    "-oidc-issuer https://auth.${domain}"
                    "-oidc-client-id ${crmOidcClientId}"
                    "-oidc-redirect-url https://crm.${domain}/auth/oauth/pocket-id/callback"
                  ]
                );
                # Strict + exactly one writable carve-out: the journal dir.
                # Everything else on the filesystem is read-only to the
                # process (ported from deploy/crm-server.service).
              }
              (lib.mkIf pocketIdProvisioned {
                # EXTENDS the sops env file with the OIDC bridge's secret
                # file (cv-server mkForce pattern). A MISSING file (the
                # bridge removed it: no secret provisioned) is a systemd
                # warning, not a start failure — OIDC degrades off and the
                # passkey path keeps working.
                EnvironmentFile = lib.mkForce [
                  config.sops.templates."crm-server-env".path
                  oidcEnvFile
                ];
              })
              (harden {
                ProtectSystem = "strict";
                ProtectHome = "read-only";
                ReadWritePaths = [ stateDir ];
                MemoryMax = "1G";
              })
              (serviceDefaults { })
            ];
          };

          # Bridges the Pocket ID client secret into the env file
          # crm-server consumes (cv-oidc-env pattern). When the secret is
          # missing the unit exits 0 WITHOUT writing the env file, so OIDC
          # sign-in stays off instead of blocking the service (passkey
          # login is the break-glass path and always works).
          crm-oidc-env = lib.mkIf pocketIdProvisioned {
            description = "Kith CRM — Pocket ID OIDC client secret provisioning";
            after = [ "pocket-id-provision.service" ];
            wants = [ "pocket-id-provision.service" ];
            before = [ "crm-server.service" ];
            wantedBy = [ "crm-server.service" ];
            startLimitBurst = 5;
            startLimitIntervalSec = 300;

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              StateDirectory = "crm-oidc";
              LoadCredential = [
                "pocket-id-secret:${
                  config.services.pocket-id.dataDir or "/var/lib/pocket-id"
                }/client-secrets/${crmOidcClientId}"
              ];
            };

            path = [ pkgs.coreutils ];

            script = ''
              SECRET_FILE="$CREDENTIALS_DIRECTORY/pocket-id-secret"

              if [ ! -s "$SECRET_FILE" ]; then
                echo "crm-oidc-env: Pocket ID secret not found — removing env file so OIDC sign-in stays off"
                rm -f "${oidcEnvFile}"
                exit 0
              fi

              install -d -m 0755 "$(dirname "${oidcEnvFile}")"
              echo "CRM_OIDC_CLIENT_SECRET=$(cat "$SECRET_FILE")" > "${oidcEnvFile}"
              chmod 600 "${oidcEnvFile}"
              echo "crm-oidc-env: Pocket ID client secret written"
            '';
          };

          # Pool leaf creator (cv-backup-dir / miniflux-backup-dir pattern).
          crm-backup-dir = {
            description = "Create Kith CRM backup directory on the HDD pool";
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

          # Nightly WAL-safe snapshots of BOTH durable databases (the
          # sqlite backup API — a consistent standalone copy against a
          # RUNNING server; ported from the crm repo's scripts/backup-ledger.sh).
          # The journal is the source of truth: projections are disposable.
          # identity.db (users/passkeys/sessions) joined 2026-10-08 (owner
          # decision "full backups" — its loss previously cost a passkey
          # re-registration). The api-token is deliberately NOT here: it is
          # sops-owned (crm_api_token) and repo-recoverable — no secrets on
          # the pool.
          crm-backup = {
            description = "Kith CRM journal + identity backup (WAL-safe sqlite snapshots)";
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
            # script at unit TOP LEVEL (2026-10-07 fix): serviceConfig is a
            # freeform attrset — nested there, the script serialized
            # line-by-line as garbage [Service] keys (script=/dst=/src=…),
            # the unit rendered without ExecStart, and systemd refused to
            # LOAD it: backups never ran from the 2026-10-03 cutover deploy
            # until this hoist (docs/status/2026-10-07_15-50_* §a5/§d1).
            script = ''
              set -euo pipefail
              python3 - ${stateDir} ${backupDir} <<'PY'
              import datetime, os, sqlite3, sys

              state_dir, backup_dir = sys.argv[1], sys.argv[2]
              stamp = datetime.date.today().isoformat()
              for name in ("ledger", "identity"):
                  src_path = os.path.join(state_dir, name + ".db")
                  if not os.path.exists(src_path):
                      # sqlite would silently CREATE an empty db and mint a
                      # healthy-looking worthless artifact — refuse instead.
                      raise SystemExit(f"crm-backup: {src_path} missing — refusing empty backup")
                  dst_path = os.path.join(backup_dir, f"{name}-{stamp}.db")
                  src = sqlite3.connect(src_path)
                  dst = sqlite3.connect(dst_path)
                  src.backup(dst)
                  dst.close()
                  src.close()
                  # identity.db carries passkey/session tables (bearer
                  # material) — tighter mode than the journal snapshot.
                  os.chmod(dst_path, 0o600 if name == "identity" else 0o644)
                  print(f"crm-backup: wrote {dst_path}")
              PY
              # 30-day retention (twenty pg_dump pattern): one snapshot
              # per night per database, oldest fall off.
              find ${backupDir} \( -name "ledger-*.db" -o -name "identity-*.db" \) -mtime +30 -delete
            '';
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = user;
                Group = group;
                ReadWritePaths = [ backupDir ];
              }
              (serviceOneshotDefaults { })
              ioTier.background
            ];
          };
        };

        systemd.timers.crm-backup = {
          description = "Nightly Kith CRM backup (journal + identity)";
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
        # system-health monitored-unit metrics. Layer "plain": the Kith
        # carries its OWN auth — WebAuthn passkeys plus NATIVE Pocket ID
        # OIDC (the oidc entry below; a "protected" Layer 2 gate would
        # double-auth and bypasses LAN clients anyway).
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
                name = "Kith CRM";
                group = "Productivity";
                path = "/healthz";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                ];
                alert = "Kith CRM down — the event-sourced journal-serving surface is unreachable (unit crm-server). Check: systemctl status crm-server, journalctl -u crm-server";
              }
            ];
            # Tile appears with the vHost claim (cutover): while Twenty
            # lives, its "Twenty CRM" tile owns the crm.<domain> href.
            homepage =
              if twentyEnabled then
                null
              else
                {
                  name = "Kith CRM";
                  group = "Productivity";
                  description = "Event-sourced personal CRM (passkey)";
                };
            # Native OIDC (Pocket ID) beside the passkey login — the CV
            # pattern: the login page renders the provider button, success
            # mints the app session. The secret lands in
            # /var/lib/pocket-id/client-secrets/crm and reaches the server
            # via the crm-oidc-env bridge (above). PKCE S256 enforced.
            oidc = {
              name = "Kith CRM";
              clientId = crmOidcClientId;
              launchURL = "https://crm.${domain}";
              callbackURLs = [ "https://crm.${domain}/auth/oauth/pocket-id/callback" ];
              pkceEnabled = true;
            };
            backup = {
              # Nightly WAL-safe snapshots (crm-backup.timer, 03:40) onto
              # the mirrored pool: ledger-*.db AND identity-*.db. Freshness
              # deliberately anchors on the ledger file only — the journal
              # IS the source of truth; an identity-leg failure fails the
              # whole unit (set -e + onFailure paging), not freshness.
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
