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
#   - NATIVE OIDC (2026-10-10), PASSKEYS OFF (2026-10-17): Pocket ID is
#     the ONLY sign-in method (Layer 1 in docs/agents/sso-dns.md — the
#     oauth2-proxy Layer 2 gate bypasses LAN clients, and crm.<domain> IS
#     a LAN hostname, so only in-app OIDC covers them). -passkeys=false
#     leaves the WebAuthn provider unconfigured upstream: the login page
#     serves the Pocket ID button alone, ceremonies 401, and the passkey
#     settings page turns off. NO DEGRADE PATH: an unreachable IdP or a
#     missing client secret fails the boot (no second sign-in method
#     exists to fall back to) — Gatus catches the 502; fix Pocket ID and
#     restart. Escape hatches: the -api-token bearer surface stays
#     outside the session gate (CV sync keeps working), and
#     services.crm-server.auth.enable = false + redeploy lifts the gate.
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
      # TEMPORARY vendorHash shim RE-PINNED (2026-10-14): the master-tracking
      # flip (flake.nix, owner directive) landed crm on a410024b, whose
      # kith-crm specified hash gFpBC++z49… no longer reproduces. Got
      # AtAQS+x0Oj… from a first-hand FOD probe of
      # services.crm-server.package at the locked rev. Non-follower class,
      # so upstream pasting the got hash genuinely fixes it; drop then, or
      # when the lock moves past an upstream-fixed rev. Re-add ONLY via
      # nix-hash-fix evidence, never by hand.
      # TEMPORARY vendorHash shim RE-PINNED (2026-10-15 fleet wave): the
      # overnight lock float landed crm on a0341a0; the shim's AtAQS…
      # (measured at a410024b) was the SPECIFIED hash in the 02:46 nh
      # mismatch. Got WOZ2Iwqw… first-hand. Drop per the standing conditions.
      # VERIFIED UNCHANGED at d3f740b (2026-10-17, passkeys-off flip): the
      # commit touches no go.mod/go.sum, and a first-hand FOD build of the
      # full chain (prepared-source → go-modules → kith-crm) went green
      # with this exact hash — no re-pin needed.
      crmPkg = inputs.crm.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
        vendorHash = "sha256-R9ui8Fb7LMg5THOullEsoBYrQa1zH3qrfwb3K5acuVE=";
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
            description = "Kith CRM (event-sourced, Pocket ID auth)";
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
              Session gate (-auth): every CRM route rides the cqrs-htmx
              identity session gate; /healthz and the bearer -api-token
              surface stay independent. Sign-in is Pocket ID OIDC only
              (-passkeys=false, 2026-10-17): passkey ceremonies 401, the
              passkey settings page is off, registered credentials stay
              dormant in the identity db. Escape hatch if Pocket ID is
              unreachable long-term: set to false and redeploy (the
              bearer API keeps working; the crm repo's
              docs/ops/PASSKEY-RECOVERY.md documents re-enabling).
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
                    # Pocket ID OIDC is the ONLY sign-in method
                    # (2026-10-17): -passkeys=false leaves the WebAuthn
                    # provider unconfigured upstream — no -rpid/-origin
                    # (they only shaped the passkey ceremony).
                    "-passkeys=false"
                    # HTTPS posture: Secure on session+CSRF cookies (the
                    # vHost serves TLS; loopback HTTP is not used).
                    "-secure true"
                  ]
                  ++ lib.optionals pocketIdProvisioned [
                    # Native OIDC — the only sign-in method since
                    # -passkeys=false. The client secret rides
                    # CRM_OIDC_CLIENT_SECRET from the crm-oidc-env bridge
                    # (environment, never argv).
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
                # bridge removed it: no secret provisioned) is only a
                # systemd warning HERE — but with -passkeys=false the
                # empty CRM_OIDC_CLIENT_SECRET leaves crm-server's -oidc-*
                # family partial and the server REFUSES to boot (no
                # fallback sign-in method). Loud by design; fix the
                # provisioner.
                EnvironmentFile = lib.mkForce [
                  config.sops.templates."crm-server-env".path
                  oidcEnvFile
                ];
                # Boot/deploy-race gate (2026-10-12): OIDC discovery runs once
                # at startup; a start before auth.<domain> is RESOLVABLE
                # failed discovery — pre-2026-10-17 that silently degraded
                # crm.<domain> to passkey-only for days; since -passkeys=false
                # it fails the BOOT, so the gate matters more. Both observed
                # failure modes were `lookup … no such host` (boot ordering
                # AND the deploy's own dnsblockd restart window), so the gate
                # waits on local DNS — NOT a TCP probe: :1411 (Pocket ID
                # loopback) is not the served surface (Caddy :443 is) and a
                # :1411 probe burned its full 120s while discovery succeeded
                # (first attempt, fixed same day). Bounded, fail-open
                # (cv-server's wait idiom).
                ExecStartPre = [
                  "${pkgs.bash}/bin/bash -c 'deadline=$$((SECONDS + 120)); until ${pkgs.getent}/bin/getent hosts auth.${domain} >/dev/null 2>&1; do if [ \"$$SECONDS\" -ge \"$$deadline\" ]; then echo \"crm-server: auth.${domain} not resolvable within 120s — starting anyway (sign-in needs Pocket ID; restart once DNS is up)\" >&2; exit 0; fi; sleep 1; done'"
                ];
                # The wait window lives under the default 90s start budget
                # (systemd.md: ExecStartPre-heavy units need an explicit
                # TimeoutStartSec or switches report false start failures).
                TimeoutStartSec = "3min";
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
