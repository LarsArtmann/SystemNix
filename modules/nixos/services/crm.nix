# Runbook: docs/services/crm.md
# Kith CRM — LarsArtmann's own event-sourced personal CRM (Go +
# go-cqrs-lite), replacing the Twenty docker-compose stack.
#
# DELEGATED 2026-11-08 (own-project upstreaming wave): the product
# deployment contract (options, the crm-server unit — loopback bind, the
# ledger/identity sqlite pair, auth flags, native OIDC + the bounded DNS
# gate, portable hardening) lives upstream —
# inputs.crm.nixosModules.default. SystemNix layers ONLY site specifics:
# the vendorHash shim, the primary-user identity, the sops API_TOKEN
# template, the Pocket ID client-secret bridge, pool backups, alarms, and
# the catalog/integration fan-out.
#
# Standing decisions carried by the layer:
#   - the LIVE journal stays at ~/.local/share/crm/ledger.db — NO data
#     migration on adoption (standing decision, crm repo deploy header;
#     a home-server move changes User=/paths only)
#   - NATIVE OIDC (2026-10-10), PASSKEYS OFF (2026-10-17): Pocket ID is
#     the ONLY sign-in method (Layer 1 in docs/agents/sso-dns.md). NO
#     DEGRADE PATH: an unreachable IdP or a missing client secret fails
#     the boot — Gatus catches the 502; fix Pocket ID and restart.
#     Escape hatches: the -api-token bearer surface stays outside the
#     session gate (CV sync keeps working), and
#     services.crm-server.auth.enable = false + redeploy lifts the gate.
#   - CUTOVER SEMANTICS: while services.twenty.enable is true, Twenty
#     keeps the crm.<domain> vHost and the dashboard tile; the Kith
#     serves loopback only (still monitored + backed up). Flipping
#     twenty.enable = false hands the subdomain over ATOMICALLY in the
#     same deploy (integration.nix keys vHosts by subdomain).
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
        serviceOneshotDefaults
        harden
        serviceDefaults
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
      # vendorHash shim lineage (full history in the git log of this file;
      # every re-pin was first-hand FOD evidence, never by hand):
      # k0Inp4g measured at the 2026-11-06 pin wave (5302527); RE-STALE at
      # the 2026-11-08 pin roll f32f4c0 (float-proof-20261108-172105.log,
      # spec k0Inp4g got EzVPIaj — the doc+module commits shifted the
      # vendored set through the module graph, the catalog-bump class).
      # Drop when upstream bakes the hash and the lock moves past an
      # upstream-fixed rev; re-add ONLY via nix-hash-fix evidence.
      crmPkg = inputs.crm.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
        vendorHash = "sha256-EzVPIajPg1tS3PW4eEzPUEv+4H8c1o+eHQKg13xKji0=";
      };
      twentyEnabled = config.services.twenty.enable or false;
    in
    {
      imports = [
        inputs.crm.nixosModules.default
        # Platform-truth catalog entry (ADR-008): unconditional — the
        # Kith CRM platform service exists wherever the module set is
        # imported, even where this host has it disabled. Requires
        # nixosModules.catalog (auto-discovered; VM tests must co-import).
        {
          services.catalog.crm = {
            subdomain = "crm";
            port = ports.crm;
            description = "Kith CRM (event-sourced, Pocket ID auth) — the contacts source of truth; Stalwart CardDAV is a planned mirror fed from it";
            healthPath = "/healthz";
          };
        }
      ];

      config = lib.mkIf cfg.enable {
        services.crm-server = {
          package = crmPkg;
          # Operator identity: the LIVE journal lives in the owner's home
          # (adopted in place, 2026-09-18) — a system user cannot reach a
          # 0700 home.
          inherit user group;
          port = ports.crm;
          inherit stateDir;
          environmentFiles =
            [ config.sops.templates."crm-server-env".path ]
            ++ lib.optionals pocketIdProvisioned [ oidcEnvFile ];
          auth.enable = true;
          oidc = lib.optionalAttrs pocketIdProvisioned {
            issuer = "https://auth.${domain}";
            clientId = crmOidcClientId;
            redirectUrl = "https://crm.${domain}/auth/oauth/pocket-id/callback";
          };
        };

        # The `crm` CLI rides the same package as the server binary; putting
        # the package on the system PATH exposes the owner-facing client
        # (contact-add/note/find) without touching the unit's store-path
        # execution (2026-10-27, crm repo Pareto M21: the CLI shipped but
        # was unreachable from the shell).
        environment.systemPackages = [ crmPkg ];

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
          # Fleet layer over the upstream unit: onFailure alerting and
          # the SystemNix-owned harden bound (the upstream mkDefaults
          # hold the same values; this keeps the fleet bound explicit and
          # registry-auditable).
          crm-server = {
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              (harden { MemoryMax = lib.mkForce "1G"; })
              (serviceDefaults { })
            ];
          };

          # Bridges the Pocket ID client secret into the env file
          # crm-server consumes (cv-oidc-env pattern). When the secret is
          # missing the unit exits 0 WITHOUT writing the env file; with
          # -passkeys=false that leaves crm-server's -oidc-* family
          # partial, so the server refuses to boot until the provisioner
          # is fixed — no silent no-sign-in degrade.
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

          # Alarm pair (docs/ops/ALARMS.md is the unit-shaped source of
          # truth — keep both sides in sync): by-phone storm watch every
          # 10 minutes, journal-growth watch nightly. The checks are
          # read-only, exit 0 clean / 2 ALARM / 1 operational failure;
          # onFailure relays BOTH alarm and failure (any non-zero rc) to
          # the host's failure unit, and the journal line distinguishes
          # them. Scripts run from the working checkout (the blessed path
          # in ALARMS.md); growth keeps its state file under
          # ~/.local/state/crm/ (XDG state convention, lars-owned).
          crm-alarm-byphone = {
            description = "Kith CRM by-phone storm alarm (>=5 5xx or >=20 >2.5s per 10 min)";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = user;
                Group = group;
                ExecStart =
                  "/run/current-system/sw/bin/python3 /home/lars/projects/crm/scripts/byphone-health-check.py";
              }
              (serviceOneshotDefaults { })
            ];
          };

          crm-alarm-journal-growth = {
            description = "Kith CRM journal-growth alarm (>100k events/day or >250 MB/day)";
            inherit onFailure;
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = user;
                Group = group;
                ExecStart =
                  "/run/current-system/sw/bin/python3 /home/lars/projects/crm/scripts/journal-growth-check.py";
              }
              (serviceOneshotDefaults { })
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

        systemd.timers.crm-alarm-byphone = {
          description = "Kith CRM by-phone storm alarm schedule (every 10 min)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "10min";
            OnUnitActiveSec = "10min";
            AccuracySec = "1min";
            Persistent = true;
          };
        };

        systemd.timers.crm-alarm-journal-growth = {
          description = "Kith CRM journal-growth alarm schedule (nightly)";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            # 04:10 — after the backup window, before work hours.
            OnCalendar = "*-*-* 04:10:00";
            RandomizedDelaySec = "10min";
            Persistent = true;
          };
        };

        # Service-integration registry entry: ONE declaration fans out to
        # Caddy vHost, Gatus checks, dashboard tile, backup freshness, and
        # system-health monitored-unit metrics. Layer "plain": the Kith
        # carries its OWN auth — Pocket ID OIDC ONLY since 2026-10-17
        # (-passkeys=false upstream; a "protected" Layer 2 gate would
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
                  description = "Event-sourced personal CRM (Pocket ID)";
                  icon = "monica.png";
                };
            # Native OIDC (Pocket ID) — the ONLY sign-in method since
            # 2026-10-17: the login page renders the provider button
            # alone, success mints the app session. The secret lands in
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
