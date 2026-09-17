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
#     auto-provisions the daily-driver account on first login). The
#     disableLocalAuth option flips to SSO-only (DISABLE_LOCAL_AUTH=1) —
#     gated on one proven live SSO login (see option description).
#   - Nightly pg_dump (custom format) onto the HDD pool, cv-backup pattern
#     (mount-gated dir oneshot + RequiresMountsFor + retention).
_: {
  flake.nixosModules.miniflux =
    {
      config,
      options,
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

      # Phase 1 (root, `+` ExecStartPre): resolve the Pocket ID user id
      # (== OIDC `sub`, source-verified v2.14.0) from Pocket ID's SQLite and
      # stage it in the unit's RuntimeDirectory. Loud failure prints the user
      # table — never a silent skip.
      minifluxOidcFetchScript = pkgs.writeShellScript "miniflux-oidc-setup-fetch" ''
        set -euo pipefail
        data_dir="${config.services.pocket-id.dataDir}/data"
        sub_file="/run/miniflux-oidc-setup/sub"
        username="${if cfg.oidcLink.username == null then "" else cfg.oidcLink.username}"
        sqlite3="${pkgs.sqlite}/bin/sqlite3"

        db="$data_dir/pocket-id.db"
        if [ ! -f "$db" ]; then
          db="$(ls -1 "$data_dir"/*.db 2>/dev/null | head -n1 || true)"
        fi
        if [ -z "$db" ] || [ ! -f "$db" ]; then
          echo "miniflux-oidc-setup: Pocket ID SQLite DB not found under $data_dir — is Pocket ID initialized?" >&2
          exit 1
        fi

        sub=""
        if [ -n "$username" ]; then
          sub="$($sqlite3 -readonly "$db" "SELECT id FROM users WHERE username = '$username' LIMIT 1;" || true)"
          if [ -z "$sub" ]; then
            sub="$($sqlite3 -readonly "$db" "SELECT id FROM users WHERE email LIKE '$username@%' LIMIT 1;" || true)"
          fi
        else
          count="$($sqlite3 -readonly "$db" "SELECT count(*) FROM users;")"
          if [ "$count" = "1" ]; then
            sub="$($sqlite3 -readonly "$db" "SELECT id FROM users LIMIT 1;")"
          fi
        fi

        if [ -z "$sub" ]; then
          echo "miniflux-oidc-setup: could not resolve the Pocket ID user (configured username: ''${username:-<auto>}). Users present:" >&2
          $sqlite3 -readonly "$db" "SELECT id, username, email FROM users;" >&2 || true
          exit 1
        fi
        case "$sub" in
          *[!A-Za-z0-9-]*)
            echo "miniflux-oidc-setup: resolved sub has unexpected characters — refusing to stage: $sub" >&2
            exit 1
            ;;
        esac

        printf '%s' "$sub" > "$sub_file"
        chmod 0644 "$sub_file"
        echo "miniflux-oidc-setup: resolved Pocket ID user -> sub=$sub (db=$db)"
      '';

      # Phase 2 (postgres, peer auth): converge users.openid_connect_id.
      # psql -v + :'var' quoting — no shell-interpolated SQL strings.
      minifluxOidcLinkScript = pkgs.writeShellScript "miniflux-oidc-setup-link" ''
        set -euo pipefail
        sub_file="/run/miniflux-oidc-setup/sub"
        username="${if cfg.oidcLink.username == null then "" else cfg.oidcLink.username}"
        # -d miniflux is load-bearing: bare psql connects to the database named
        # after the invoking USER (postgres), and the miniflux schema lives in
        # the "miniflux" database (upstream hardcodes the name — its dbsetup
        # unit runs `psql "miniflux"` for the same reason).
        psql="${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -d miniflux"

        sub="$(cat "$sub_file")"
        case "$sub" in
          *[!A-Za-z0-9-]*)
            echo "miniflux-oidc-setup: staged sub has unexpected characters — refusing: $sub" >&2
            exit 1
            ;;
        esac

        if [ -n "$username" ]; then
          # Bounded wait: CREATE_ADMIN seeds the break-glass user at miniflux
          # first start; on a fresh host that start races this unit.
          target=""
          for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
            count="$($psql -v u="$username" -tAc "SELECT count(*) FROM users WHERE username = :'u';" || true)"
            if [ "''${count:-0}" -ge 1 ] 2>/dev/null; then target="$username"; break; fi
            sleep 2
          done
        else
          # Bounded wait (same fresh-host race as the named branch): miniflux
          # CREATE_ADMIN seeds the table at first start. Retry while the DB is
          # empty or unready; fail immediately on 2+ users — auto mode refuses
          # to guess (never silently link the wrong account).
          target=""
          for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
            count="$($psql -tAc "SELECT count(*) FROM users;" || true)"
            case "''${count:-}" in
              1)
                target="$($psql -tAc "SELECT username FROM users LIMIT 1;")"
                break
                ;;
              "" | 0) sleep 2 ;;
              *) break ;;
            esac
          done
        fi
        if [ -z "''${target:-}" ]; then
          echo "miniflux-oidc-setup: no miniflux user matched (configured username: ''${username:-<auto>}). Users present:" >&2
          $psql -c "SELECT id, username, openid_connect_id FROM users;" >&2 || true
          exit 1
        fi

        current="$($psql -v u="$target" -tAc "SELECT openid_connect_id FROM users WHERE username = :'u' LIMIT 1;")"
        if [ "$current" = "$sub" ]; then
          echo "miniflux-oidc-setup: already linked (user=$target sub=$sub)"
          exit 0
        fi

        $psql -v u="$target" -v s="$sub" -c "UPDATE users SET openid_connect_id = :'s' WHERE username = :'u';"
        echo "miniflux-oidc-setup: linked miniflux user '$target' -> Pocket ID sub $sub (was: ''${current:-<empty>})"
        $psql -v u="$target" -c "SELECT id, username, openid_connect_id FROM users WHERE username = :'u';"
      '';
    in
    {
      options.services.miniflux.disableLocalAuth = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          SSO-only posture: sets DISABLE_LOCAL_AUTH=1, removing the password
          login form entirely. Requires enableOidc (the env var is refused
          otherwise — a deployment without OIDC and without local auth would
          be unreachable by design). GO-LIVE GATE: flip this only AFTER one
          successful live SSO login at https://rss.<domain>/ — enabling it in
          the same deploy as an unproven OIDC callback risks total lockout.
          Break-glass: set the option back to false (one line) and redeploy;
          the admin account stays in the database regardless.
        '';
      };

      options.services.miniflux.oidcLink = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Provision the miniflux ⇄ Pocket ID account link declaratively
            (miniflux-oidc-setup oneshot): resolve the Pocket ID user id
            (== the OIDC `sub` claim — source-verified v2.14.0) from Pocket
            ID's SQLite and converge miniflux's `users.openid_connect_id`.
            Without this link the FIRST SSO login hard-fails 400 "This user
            already exists." — the unauthenticated callback resolves users
            ONLY by openid_connect_id (never by username) and, with
            OAUTH2_USER_CREATION=1, tries to CREATE a colliding user instead.
            Idempotent: converges on every boot + deploy.sh provisioner run;
            re-links automatically if Pocket ID's DB is ever recreated (its
            user ids change — the 2026-08-22 SQLITE_BUSY DB-recreation class).
          '';
        };
        username = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Pocket ID username (or exact email prefix) of the human to link,
            and the miniflux user to attach it to. null = auto: exactly ONE
            user on each side is required, otherwise the unit fails loudly
            printing both user tables (browser-history fresh-host doctrine:
            converge when possible, never guess silently).
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = !cfg.oidcLink.enable || enableOidc;
            message = "services.miniflux.oidcLink.enable requires the Pocket ID OIDC stack (services.pocket-id-config.enable + provision.enable) — there is no Pocket ID sub to link without it.";
          }
        ];

        # Static system user, NOT DynamicUser: postgres peer auth must resolve
        # the connecting uid via /etc/passwd (files), never via the nscd/nsncd
        # path — system.nssModules is documented "Only works with nscd!", so a
        # wedged nsncd makes getpwuid(dynamic-uid) fail in postgres
        # ("could not look up local user ID …: user does not exist") and
        # miniflux crash-loops with "Peer authentication failed" (VM-proven
        # 2026-09-17: the VM test regressed exactly this way when nsncd lost
        # its boot race). Stateless app — the uid switch is transparent.
        users.users.miniflux = {
          isSystemUser = true;
          group = "miniflux";
          description = "Miniflux RSS reader service user";
        };
        users.groups.miniflux = { };

        services.miniflux = {
          config = {
            LISTEN_ADDR = "127.0.0.1:${toString ports.miniflux}";
            BASE_URL = "https://rss.${domain}/";
          }
          // (lib.optionalAttrs (enableOidc && cfg.disableLocalAuth) {
            DISABLE_LOCAL_AUTH = 1;
          })
          // (lib.optionalAttrs enableOidc {
            OAUTH2_PROVIDER = "oidc";
            OAUTH2_OIDC_PROVIDER_NAME = "Pocket ID";
            OAUTH2_CLIENT_ID = "miniflux";
            # MUST be set explicitly — OAUTH2_REDIRECT_URL defaults to ""
            # upstream (no BASE_URL derivation); without it the authorize
            # request lacks redirect_uri and Pocket ID answers
            # "The 'redirect_uri' parameter is required when using
            # OpenID Connect 1.0". Must match the pocket-id.nix callbackURL.
            OAUTH2_REDIRECT_URL = "https://rss.${domain}/oauth2/oidc/callback";
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

        systemd.services = {
          miniflux = {
            description = lib.mkForce "Miniflux RSS reader";
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            # The OIDC discovery/token calls go through Caddy's TLS (dnsblockd-CA
            # signed) — Go needs the system trust store (browser-history pattern).
            environment.SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
            inherit (oidcGate) after wants;
            serviceConfig = lib.mkMerge [
              {
                MemoryMax = "512M";
                DynamicUser = lib.mkForce false;
              }
              ioTier.background
              (lib.optionalAttrs enableOidc {
                LoadCredential = [
                  "miniflux-oidc-secret:${config.services.pocket-id.dataDir}/client-secrets/miniflux"
                ];
              })
              oidcGate.serviceConfig
            ];
          };
        }
        // lib.optionalAttrs (enableOidc && cfg.oidcLink.enable) {
          # Declarative account link (Pocket ID sub -> miniflux
          # users.openid_connect_id). Two-phase unit: the `+`-prefixed
          # ExecStartPre runs as ROOT (full privileges — reads Pocket ID's
          # 0700-pocket-id-owned SQLite) and drops the resolved sub into the
          # shared RuntimeDirectory; ExecStart runs as `postgres` (peer auth)
          # and converges the SQL. Split identity = no su/runuser (PAM dies
          # under harden{}), no CAP juggling: each phase owns its resource.
          # Convergence semantics (browser-history provisioner doctrine):
          # already-linked = no-op; Pocket ID DB recreation (new sub) = clean
          # re-link; unresolvable user = loud failure + OnFailure alert.
          # deploy-restart-audit: `-setup` suffix is a converger pattern —
          # restart per deploy via the scripts/deploy.sh provisioner loop.
          miniflux-oidc-setup = {
            description = "Link miniflux user to Pocket ID (openid_connect_id)";
            wantedBy = [ "multi-user.target" ];
            after = [
              "miniflux.service"
              "pocket-id.service"
            ];
            wants = [
              "miniflux.service"
              "pocket-id.service"
            ];
            inherit onFailure;
            startLimitBurst = 5;
            startLimitIntervalSec = 300;
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "postgres";
                Group = "postgres";
                RemainAfterExit = true;
                RuntimeDirectory = "miniflux-oidc-setup";
                RuntimeDirectoryMode = "0755";
                ExecStartPre = "+${minifluxOidcFetchScript}";
                ExecStart = "${minifluxOidcLinkScript}";
              }
              (harden { MemoryMax = "128M"; })
              (serviceOneshotDefaults { })
            ];
          };
        }
        // {
          # Nightly backup of the whole Miniflux state (PostgreSQL only — the
          # app is stateless). pg_dump custom format as the postgres superuser
          # over peer auth; cv-backup dir-oneshot pattern for the pool leaf.
          miniflux-backup-dir = {
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

          miniflux-backup = {
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

        # Service-integration registry entry (modules/nixos/services/
        # integration.nix): ONE declaration fans out to every cross-cutting
        # surface — Caddy vHost (plain, Layer 1: native OIDC, protectedVHost
        # would double-auth), Gatus checks, homepage tile, backup freshness,
        # system-health monitored unit, and the Pocket ID client. This entry
        # REPLACES rows that lived in caddy.nix / gatus-config.nix /
        # homepage.nix / configuration.nix (backup-coordination) /
        # system-health.nix (monitoredServices) / pocket-id.nix (oidcClients).
        # CAVEAT (flake-check-proven 2026-09-15): the options?-guard does
        # NOT keep a standalone import of this module evaluable when
        # cfg.enable is true — the enclosing config's mkIf(true) wraps the
        # empty optionalAttrs result and the mkIf-wrapped def at the
        # undeclared path still fires "option does not exist". VM tests MUST
        # co-import modules/nixos/services/integration.nix (test-miniflux
        # does).
        services.integration = lib.optionalAttrs (options ? services.integration) {
          miniflux = {
            subdomain = "rss";
            port = ports.miniflux;
            vHost.layer = "plain";
            checks = [
              {
                # Functional: /healthcheck verifies the DATABASE round-trip
                # (200 "OK" when healthy, 503 on DB failure) — liveness of the
                # process alone would stay green through a dead DB.
                name = "Miniflux";
                group = "Media";
                path = "/healthcheck";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[RESPONSE_TIME] < 1000"
                  "[BODY] == pat(*OK*)"
                ];
                alert = "Miniflux down — rss.${domain} unreachable (service or PostgreSQL failure). Check: systemctl status miniflux, journalctl -u miniflux";
              }
              {
                name = "Miniflux Login Renders";
                group = "Media";
                path = "/";
                interval = "5m";
                conditions = [
                  "[STATUS] == 200"
                  "[BODY] == pat(*<html*)"
                ];
                alert = "Miniflux login page not rendering HTML — check journalctl -u miniflux";
              }
            ];
            homepage = {
              name = "Miniflux";
              group = "Media";
              description = "RSS Reader (Pocket ID SSO, Keyboard-Driven)";
              icon = "miniflux.png";
            };
            backup = {
              # Nightly pg_dump (custom format) of the RSS reader DB
              # (miniflux-backup.timer, 02:45) onto the mirrored pool.
              directory = "/mnt/pool/backups/miniflux";
              filePattern = "miniflux-*.dump";
              maxAgeHours = 25;
            };
            monitored = true;
            # OAUTH2_REDIRECT_URL in the config block above MUST equal the
            # callback URL byte-for-byte (upstream default is EMPTY — no
            # BASE_URL derivation).
            oidc = {
              name = "Miniflux";
              clientId = "miniflux";
              launchURL = "https://rss.${domain}";
              callbackURLs = [ "https://rss.${domain}/oauth2/oidc/callback" ];
            };
          };
        };
      };
    };
}
