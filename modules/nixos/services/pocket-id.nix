# Pocket ID: passkey-only OIDC provider replacing Authelia
# Declaratively provisions admin user, OIDC clients, and avatar
_: {
  flake.nixosModules.pocket-id =
    {
      config,
      lib,
      pkgs,
      options,
      ...
    }:
    let
      cfg = config.services.pocket-id-config;
      inherit (config.networking) domain;
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        serviceOneshotDefaults
        onFailure
        serviceTypes
        ports
        mkSecretCheck
        ;
      pocketIdPort = cfg.port;
      inherit (cfg) metricsPort;

      dataDir = config.services.pocket-id.dataDir;
      clientSecretsDir = "${dataDir}/client-secrets";
      apiUrl = "http://127.0.0.1:${toString pocketIdPort}";
      pocketIdBackupDir = "/mnt/pool/backups/pocket-id";

      checkEncryptionKey = mkSecretCheck pkgs {
        name = "pocket-id-encryption-key";
        secretPath = config.sops.secrets.pocket_id_encryption_key.path;
        message = "pocket-id: ENCRYPTION_KEY is missing or empty (${config.sops.secrets.pocket_id_encryption_key.path})\n  Run: just auth-bootstrap";
      };

      checkStaticApiKey = mkSecretCheck pkgs {
        name = "pocket-id-static-api-key";
        secretPath = config.sops.secrets.pocket_id_static_api_key.path;
        message = "pocket-id: STATIC_API_KEY is missing or empty (${config.sops.secrets.pocket_id_static_api_key.path})\n  Run: just auth-bootstrap";
      };

      # Defense-in-depth: clear stale SQLite WAL/SHM files left by crash-looping
      # instances. Originally added for the francis SQLITE_BUSY cascade in v2.10.0.
      # Pocket ID 2.12.0 includes francis v0.1.0-beta.17+ which fixes the crash-loop,
      # but clearing stale WAL on startup is harmless and protects against any future
      # unclean shutdown (OOM, WDT reset, power loss).
      clearStaleWal = pkgs.writeShellApplication {
        name = "pocket-id-clear-stale-wal";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          rm -f "${dataDir}/data/pocket-id.db-wal" "${dataDir}/data/pocket-id.db-shm" 2>/dev/null || true
        '';
      };

      provisionScript = pkgs.writeShellApplication {
        name = "pocket-id-provision";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
        ];
        text = ''
          set -euo pipefail

          API_URL="${apiUrl}"
          API_KEY_FILE="${config.sops.secrets.pocket_id_static_api_key.path}"
          API_KEY="$(cat "$API_KEY_FILE")"
          CLIENT_SECRETS_DIR="${clientSecretsDir}"

          mkdir -p "$CLIENT_SECRETS_DIR"
          chown pocket-id:pocket-id "$CLIENT_SECRETS_DIR"
          chmod 750 "$CLIENT_SECRETS_DIR"

          echo "=== Pocket ID Provisioning ==="

          # ── Helper: authenticated API call ──
          api_get() {
            local path="$1"
            local resp
            resp=$(curl -s --compressed --max-time 10 --retry 3 --retry-delay 2 --retry-all-errors -H "X-API-Key: $API_KEY" "$API_URL$path" 2>&1) || true
            echo "$resp"
          }

          api_put() {
            local path="$1"
            local body="$2"
            curl -s --compressed --max-time 30 --retry 3 --retry-delay 2 -w '\n%{http_code}' -X PUT -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
              -d "$body" "$API_URL$path" 2>&1 || true
          }

          api_post() {
            local path="$1"
            local body="$2"
            curl -s --compressed --max-time 30 --retry 3 --retry-delay 2 -w '\n%{http_code}' -X POST -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
              -d "$body" "$API_URL$path" 2>&1 || true
          }

          # NOTE: POST /api/oidc/clients/{id}/secret ALWAYS generates a NEW secret
          # (rotating the old one). POST /api/oidc/clients does NOT auto-generate one.
          # The skip-if-exists check below prevents secret rotation on every provision run.
          # To force regeneration: rm the file, then `systemctl RESTART pocket-id-provision`
          # (NOT `start` — RemainAfterExit=true makes `start` a no-op on active service).
          # The secret file is load-bearing for services using systemd LoadCredential
          # (e.g. immich-server) — deleting it while the consumer runs causes crash-loops.

          # ── Step 1: Admin User ──
          ADMIN_USERNAME="${cfg.provision.adminUser.username}"
          ADMIN_EMAIL="${cfg.provision.adminUser.email}"
          ADMIN_FIRST="${cfg.provision.adminUser.firstName}"
          ADMIN_LAST="${cfg.provision.adminUser.lastName}"

          echo "Checking for admin user: $ADMIN_USERNAME..."
          ALL_USERS=$(api_get "/api/users?pagination%5Blimit%5D=100")
          echo "  Users API response: $(echo "$ALL_USERS" | head -c 200)"
          ADMIN_USER_ID=$(echo "$ALL_USERS" | jq -r '.data[] | select(.username == "'"$ADMIN_USERNAME"'") | .id // empty' 2>/dev/null | head -1)

          if [ -n "$ADMIN_USER_ID" ]; then
            echo "  Admin user '$ADMIN_USERNAME' already exists (ID: $ADMIN_USER_ID)."
          else
            echo "  Creating admin user: $ADMIN_USERNAME"
            USER_JSON=$(jq -n \
              --arg username "$ADMIN_USERNAME" \
              --arg email "$ADMIN_EMAIL" \
              --arg firstName "$ADMIN_FIRST" \
              --arg lastName "$ADMIN_LAST" \
              '{
                username: $username,
                email: $email,
                firstName: $firstName,
                lastName: $lastName,
                isAdmin: true
              }')

            CREATE_RESPONSE=$(api_post "/api/users" "$USER_JSON")
            HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
            RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
            echo "  API response (HTTP $HTTP_CODE): $RESPONSE_BODY"
            ADMIN_USER_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // empty' 2>/dev/null || true)

            if [ -n "$ADMIN_USER_ID" ]; then
              echo "  Created admin user with ID: $ADMIN_USER_ID"
            elif echo "$RESPONSE_BODY" | grep -qi "already in use"; then
              echo "  User already exists (race), fetching ID..."
              ALL_USERS2=$(api_get "/api/users?pagination%5Blimit%5D=100")
              echo "  Users response: $(echo "$ALL_USERS2" | head -c 200)"
              ADMIN_USER_ID=$(echo "$ALL_USERS2" | jq -r '.data[] | select(.username == "'"$ADMIN_USERNAME"'") | .id // empty' 2>/dev/null | head -1)
              if [ -z "$ADMIN_USER_ID" ]; then
                echo "  ERROR: User exists but could not fetch ID" >&2
                exit 1
              fi
            else
              echo "  ERROR: Failed to create admin user (HTTP $HTTP_CODE). Response: $RESPONSE_BODY" >&2
              exit 1
            fi
          fi

          # ── Step 2: Avatar ──
          AVATAR_FILE="${cfg.provision.avatarFile}"
          if [ -f "$AVATAR_FILE" ] && [ -n "$ADMIN_USER_ID" ]; then
            echo "Checking avatar..."
            AVATAR_RESPONSE=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' -X PUT \
              -H "X-API-Key: $API_KEY" \
              -F "file=@$AVATAR_FILE" \
              "$API_URL/api/users/$ADMIN_USER_ID/profile-picture" 2>&1 || true)

            if [ "$AVATAR_RESPONSE" = "200" ] || [ "$AVATAR_RESPONSE" = "204" ]; then
              echo "  Avatar uploaded successfully."
            else
              echo "  Avatar upload response: $AVATAR_RESPONSE"
            fi
          fi

          # ── Helper: upload client logo ──
          upload_logo() {
            local client_id="$1"
            local logo_file="$2"

            if [ -z "$logo_file" ] || [ "$logo_file" = "null" ]; then
              return 0
            fi

            if [ ! -f "$logo_file" ]; then
              echo "  WARNING: Logo file not found: $logo_file" >&2
              return 0
            fi

            echo "  Uploading logo for client $client_id..."
            LOGO_RESPONSE=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' -X POST \
              -H "X-API-Key: $API_KEY" \
              -F "file=@$logo_file" \
              "$API_URL/api/oidc/clients/$client_id/logo" 2>&1 || true)

            if [ "$LOGO_RESPONSE" = "200" ] || [ "$LOGO_RESPONSE" = "204" ]; then
              echo "  Logo uploaded successfully."
            else
              echo "  Logo upload response: $LOGO_RESPONSE"
            fi
          }

          # ── Step 3: OIDC Clients ──
          ${lib.concatMapStringsSep "\n" (
            client:
            let
              logoPath = if client.logoFile != null then toString client.logoFile else "";
              clientAttrs = {
                inherit (client) name;
                inherit (client) callbackURLs;
                logoutCallbackURLs = client.logoutCallbackURLs or [ ];
                inherit (client) isPublic;
                inherit (client) pkceEnabled;
                requiresReauthentication = client.requiresReauthentication or false;
              }
              // lib.optionalAttrs (client.launchURL or null != null) {
                inherit (client) launchURL;
              };
              createAttrs = clientAttrs // {
                id = client.clientId;
              };
            in
            ''
              echo "Checking OIDC client: ${client.name}..."
              ALL_CLIENTS=$(api_get "/api/oidc/clients?pagination%5Blimit%5D=100")
              echo "  Clients API response: $(echo "$ALL_CLIENTS" | head -c 200)"
              EXISTING_CLIENT=$(echo "$ALL_CLIENTS" | jq -r '.data[] | select(.id == "${client.clientId}") | .id // empty' 2>/dev/null | head -1)

              if [ -n "$EXISTING_CLIENT" ]; then
                echo "  Client '${client.name}' already exists (ID: $EXISTING_CLIENT). Updating..."
                UPDATE_RESPONSE=$(api_put "/api/oidc/clients/$EXISTING_CLIENT" '${builtins.toJSON clientAttrs}')
                HTTP_CODE=$(echo "$UPDATE_RESPONSE" | tail -1)
                RESPONSE_BODY=$(echo "$UPDATE_RESPONSE" | sed '$d')
                if [ "$HTTP_CODE" = "200" ]; then
                  echo "  Client '${client.name}' updated successfully."
                else
                  echo "  WARNING: Update failed (HTTP $HTTP_CODE): $RESPONSE_BODY" >&2
                fi
                CLIENT_ID="$EXISTING_CLIENT"
              else
                echo "  Creating OIDC client: ${client.name}"
                CREATE_RESPONSE=$(api_post "/api/oidc/clients" '${builtins.toJSON createAttrs}')
                echo "  Client create response: $CREATE_RESPONSE"
                HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
                RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
                CLIENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // empty' 2>/dev/null || true)

                if echo "$RESPONSE_BODY" | grep -qi "already exists"; then
                  echo "  Client '${client.name}' created in race, re-fetching..."
                  ALL_CLIENTS2=$(api_get "/api/oidc/clients?pagination%5Blimit%5D=100")
                  CLIENT_ID=$(echo "$ALL_CLIENTS2" | jq -r '.data[] | select(.id == "${client.clientId}") | .id // empty' 2>/dev/null | head -1)
                elif [ -z "$CLIENT_ID" ]; then
                  # POST may have succeeded server-side despite a curl timeout
                  # (SQLite SQLITE_BUSY contention can make writes take 10-15s).
                  # Wait briefly, then re-fetch before declaring failure.
                  echo "  WARNING: Create returned no client ID (HTTP $HTTP_CODE). Re-fetching in case of timeout..."
                  sleep 5
                  ALL_CLIENTS2=$(api_get "/api/oidc/clients?pagination%5Blimit%5D=100")
                  CLIENT_ID=$(echo "$ALL_CLIENTS2" | jq -r '.data[] | select(.id == "${client.clientId}") | .id // empty' 2>/dev/null | head -1)
                  if [ -n "$CLIENT_ID" ]; then
                    echo "  Client '${client.name}' was created despite timeout (ID: $CLIENT_ID)."
                  else
                    echo "  ERROR: Failed to create client '${client.name}'. Response: $RESPONSE_BODY" >&2
                    exit 1
                  fi
                else
                  echo "  Created client '${client.name}' with ID: $CLIENT_ID"
                fi
              fi

              # Upload logo if configured
              upload_logo "$CLIENT_ID" "${logoPath}"

              # Generate client secret — only when the file is missing.
              # Pocket ID's multi-secret API (current): POST /secrets (PLURAL)
              # with an OPTIONAL body, 201 returns {secret: ...} exactly once.
              # The old singular /secret route 404s — every NEW client created
              # after the pocket-id bump silently got no secret (live 2026-09-02:
              # Paperless provisioned, secret generation failed every run).
              SECRET_FILE="$CLIENT_SECRETS_DIR/${client.clientId}"
              ${lib.optionalString (builtins.elem client.clientId cfg.provision.regenerateSecretsFor) ''
                # Force regeneration: delete stale file so the skip-if-exists
                # check below falls through to POST /secret.
                if [ -f "$SECRET_FILE" ]; then
                  echo "  Force-regenerating secret (listed in regenerateSecretsFor)..."
                  rm -f "$SECRET_FILE"
                fi
              ''}
              if [ -f "$SECRET_FILE" ] && [ -s "$SECRET_FILE" ]; then
                echo "  Secret file already exists."
              else
                echo "  Generating client secret..."
                SECRET_RESPONSE=$(curl -s --compressed --max-time 30 -X POST \
                  -H "X-API-Key: $API_KEY" \
                  "$API_URL/api/oidc/clients/$CLIENT_ID/secrets" 2>&1 || true)
                CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | jq -r '.secret // empty' 2>/dev/null || true)

                if [ -n "$CLIENT_SECRET" ]; then
                  echo "$CLIENT_SECRET" > "$SECRET_FILE"
                  chmod 640 "$SECRET_FILE"
                  chown pocket-id:pocket-id "$SECRET_FILE"
                  echo "  Secret written to $SECRET_FILE"
                else
                  echo "  ERROR: Failed to generate secret for '${client.name}' — consumer service will crash-loop" >&2
                  exit 1
                fi
              fi
            ''
          ) cfg.provision.oidcClients}

          echo "=== Pocket ID Provisioning Complete ==="
        '';
      };

      paperlessOidcClientOk =
        client:
        client.clientId == "paperless"
        && client.pkceEnabled
        && builtins.elem "https://paperless.${domain}/accounts/oidc/pocket-id/login/callback/" client.callbackURLs;
    in
    {
      options.services.pocket-id-config = {
        enable = lib.mkEnableOption "Pocket ID passkey OIDC provider with SystemNix configuration";
        port = serviceTypes.servicePort ports.pocket-id "Port for Pocket ID";
        metricsPort = serviceTypes.servicePort ports.pocket-id-metrics "Port for Pocket ID Prometheus metrics";

        smtp = {
          host = lib.mkOption {
            type = lib.types.str;
            default = "smtp.resend.com";
            description = "SMTP server host for sending emails";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 465;
            description = "SMTP server port";
          };
          user = lib.mkOption {
            type = lib.types.str;
            default = "resend";
            description = "SMTP username for authentication";
          };
          from = lib.mkOption {
            type = lib.types.str;
            default = "noreply@${domain}";
            description = "From email address for outgoing emails";
          };
          skipSslVerify = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Skip SSL certificate verification for SMTP";
          };
        };

        provision = {
          enable = lib.mkEnableOption "automatic provisioning of admin user, OIDC clients, and avatar";
          adminUser = lib.mkOption {
            type = lib.types.submodule {
              options = {
                username = lib.mkOption {
                  type = lib.types.str;
                  description = "Admin username";
                };
                email = lib.mkOption {
                  type = lib.types.str;
                  description = "Admin email address";
                };
                firstName = lib.mkOption {
                  type = lib.types.str;
                  description = "Admin first name";
                };
                lastName = lib.mkOption {
                  type = lib.types.str;
                  description = "Admin last name";
                };
              };
            };
            description = "Admin user to create declaratively";
          };

          oidcClients = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Display name for the OIDC client";
                  };
                  clientId = lib.mkOption {
                    type = lib.types.str;
                    description = "Client ID (must be unique)";
                  };
                  callbackURLs = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Allowed callback URLs";
                  };
                  logoutCallbackURLs = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Allowed logout callback URLs";
                  };
                  launchURL = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Launch URL shown in Pocket ID UI (clicking the app redirects here)";
                  };
                  pkceEnabled = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether PKCE is enabled for this client";
                  };
                  isPublic = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether this is a public client (no client secret)";
                  };
                  requiresReauthentication = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Whether to force passkey re-authentication on each login";
                  };
                  logoFile = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Path to logo image for the client (PNG or SVG)";
                  };
                };
              }
            );
            default = [
              {
                name = "oauth2-proxy";
                clientId = "oauth2-proxy";
                callbackURLs = [ "https://auth.${domain}/oauth2/callback" ];
              }
              {
                name = "Immich";
                clientId = "immich";
                launchURL = "https://immich.${domain}";
                callbackURLs = [
                  "https://immich.${domain}/auth/login"
                  "https://immich.${domain}/user-settings"
                  "app.immich:///oauth-callback"
                ];
                logoutCallbackURLs = [ "https://immich.${domain}" ];
                pkceEnabled = true;
                logoFile = ../../../assets/immich-logo.svg;
              }
              {
                name = "Forgejo";
                clientId = "forgejo";
                launchURL = "https://forgejo.${domain}";
                callbackURLs = [ "https://forgejo.${domain}/user/oauth2/PocketID/callback" ];
              }
              {
                # Native OIDC (Gatus security.oidc block). Callback path is fixed
                # upstream at /authorization-code/callback.
                name = "Gatus";
                clientId = "gatus";
                launchURL = "https://status.${domain}";
                callbackURLs = [ "https://status.${domain}/authorization-code/callback" ];
              }
              {
                # Native OIDC via Monitor365's built-in SSO support.
                # PKCE (S256) is required by Monitor365's authorize flow.
                name = "Monitor365";
                clientId = "monitor365";
                launchURL = "https://monitor.${domain}";
                callbackURLs = [ "https://monitor.${domain}/v1/auth/sso/callback" ];
                pkceEnabled = true;
              }
              {
                # Native OIDC via browser-history's OAuth2 provider support.
                # Uses OIDC discovery (IssuerURL) at startup. Callback path is
                # /auth/oauth/pocket-id/callback — fixed by the oauth2prov library.
                name = "Browser History";
                clientId = "browser-history";
                launchURL = "https://history.${domain}";
                callbackURLs = [ "https://history.${domain}/auth/oauth/pocket-id/callback" ];
              }
              {
                # Native OIDC in dnsblockd itself (cqrs-htmx/usermgmt/oauth2
                # provider, authorization-code + PKCE S256). Binds dashboard
                # audit entries to the signed-in identity.
                name = "dnsblockd";
                clientId = "dnsblockd";
                launchURL = "https://dnsblock.${domain}";
                callbackURLs = [ "https://dnsblock.${domain}/auth/oidc/callback" ];
                pkceEnabled = true;
              }
              {
                # Native OIDC in paperless-ngx via django-allauth
                # (allauth.socialaccount.providers.openid_connect). Callback
                # path is fixed by allauth's URL routing:
                # /accounts/oidc/<provider_id>/login/callback/
                # allauth sends PKCE (OAUTH_PKCE_ENABLED in the provider JSON).
                name = "Paperless";
                clientId = "paperless";
                launchURL = "https://paperless.${domain}";
                callbackURLs = [
                  "https://paperless.${domain}/accounts/oidc/pocket-id/login/callback/"
                ];
                pkceEnabled = true;
              }
            ];
            description = "OIDC clients to create declaratively";
          };

          avatarFile = lib.mkOption {
            type = lib.types.path;
            default = ../../../assets/avatar.png;
            description = "Path to avatar image to seed for admin user";
          };

          regenerateSecretsFor = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Client IDs whose secrets should be force-regenerated on the next
              provision run. Use this to recover from client-secret file desync
              (stale file value that doesn't match Pocket ID's database).
              Clear the list after a successful deploy to prevent unwanted
              secret rotation on subsequent provision runs.
            '';
          };
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = !cfg.provision.enable || (config.sops.secrets ? pocket_id_static_api_key);
            message = "pocket-id: provision.enable requires pocket_id_static_api_key to be defined in sops secrets.\n  Generate one with: openssl rand -base64 32\n  Then add it to platforms/nixos/secrets/pocket-id.yaml";
          }
          {
            # Paperless is SSO-ONLY since 2026-09-02 (user decision: no
            # password logins): if this client registration drifts (wrong
            # callback, PKCE off, clientId renamed), every paperless login
            # breaks with NO fallback path. allauth's callback route is FIXED
            # at /accounts/oidc/<provider_id>/login/callback/ and both sides
            # run PKCE S256 (OAUTH_PKCE_ENABLED in the provider JSON written
            # by paperless-oidc-setup). Silent drift here is a full-auth
            # outage, so it must be an eval-time failure, not a runtime one.
            # Negative test (PROVEN 2026-09-03 — the extendModules eval recipe
            # below is DEPRECATED: it forces all assertion messages and hits
            # the sops-template owner=null coercion crash; use the
            # mutated-tree recipe instead):
            #   1. git archive HEAD | tar -x -C /tmp/t10; cd /tmp/t10
            #   2. Copy + `git add -f` the force-tracked gap (plain add -A
            #      skips ignore rules and eval dies on missing flake-source
            #      paths): diff the `git ls-files` sets vs the real repo —
            #      platforms/nixos/secrets/*, assets/avatar.png, .envrc,
            #      docs/reports/* — then commit.
            #   3. Mutate ONLY the client registration callback (line with
            #      `https://paperless.\${domain}/accounts/oidc/pocket-id/login/callback/`
            #      inside oidcClients' paperless default) — NOT the
            #      assertion's expected constant (same literal; a blanket sed
            #      mutates both and the test self-neutralizes, proven the
            #      hard way).
            #   4. nix flake check --no-build → "Failed assertions:" naming
            #      this message. Verified firing 2026-09-03.
            assertion =
              !cfg.provision.enable
              || !options ? services.paperless
              || !config.services.paperless.enable
              || builtins.any paperlessOidcClientOk cfg.provision.oidcClients;
            message = ''pocket-id: paperless is SSO-only but the paperless OIDC client registration is missing or malformed (expected clientId "paperless", pkceEnabled = true, exact callback "https://paperless.${domain}/accounts/oidc/pocket-id/login/callback/") — every paperless login would break with no fallback. Fix services.pocket-id-config.provision.oidcClients.'';
          }
        ];

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
            OTEL_METRICS_EXPORTER = "prometheus";
            LOG_LEVEL = "info";
            VERSION_CHECK_DISABLED = true;
            AUDIT_LOG_RETENTION_DAYS = "90";
            DB_CONNECTION_STRING = "data/pocket-id.db";
            # Bind the francis actor-host WebTransport (QUIC) server to localhost
            # only. Single-instance setup doesn't need P2P on 0.0.0.0:1414.
            ACTORS_HOST = "127.0.0.1";
            UPLOAD_PATH = "data/uploads";
            SMTP_HOST = cfg.smtp.host;
            SMTP_PORT = toString cfg.smtp.port;
            SMTP_USER = cfg.smtp.user;
            SMTP_FROM = cfg.smtp.from;
            SMTP_SKIP_SSL_VERIFY = cfg.smtp.skipSslVerify;
          };
          credentials = {
            ENCRYPTION_KEY = config.sops.secrets.pocket_id_encryption_key.path;
            SMTP_PASSWORD = config.sops.secrets.pocket_id_smtp_password.path;
          }
          // lib.optionalAttrs cfg.provision.enable {
            STATIC_API_KEY = config.sops.secrets.pocket_id_static_api_key.path;
          };
        };

        systemd = {
          tmpfiles.rules = [
            "d ${clientSecretsDir} 0750 pocket-id pocket-id -"
            "d ${pocketIdBackupDir} 0750 pocket-id pocket-id -"
          ];

          services = {
            pocket-id = {
              inherit onFailure;
              unitConfig = {
                StartLimitBurst = lib.mkForce 5;
                StartLimitIntervalSec = lib.mkForce 600;
              };
              serviceConfig = lib.mkMerge [
                (serviceDefaults { })
                (harden { MemoryMax = "1G"; })
                {
                  TimeoutStartSec = "180s";
                  Environment = [ "GOMEMLIMIT=768MiB" ];
                  ExecStartPre = [
                    "+${lib.getExe clearStaleWal}"
                    "+${lib.getExe checkEncryptionKey}"
                  ];
                  ExecStartPost = "${lib.getExe pkgs.curl} -sf --max-time 3 --retry 120 --retry-delay 1 --retry-all-errors http://127.0.0.1:${toString pocketIdPort}/healthz";
                }
                (lib.optionalAttrs cfg.provision.enable {
                  ExecStartPre = lib.mkForce [
                    "+${lib.getExe clearStaleWal}"
                    "+${lib.getExe checkEncryptionKey}"
                    "+${lib.getExe checkStaticApiKey}"
                  ];
                })
              ];
            };

            pocket-id-provision = lib.mkIf cfg.provision.enable {
              description = "Pocket ID Provisioning — admin user, OIDC clients, and avatar";
              after = [ "pocket-id.service" ];
              wants = [ "pocket-id.service" ];
              wantedBy = [ "pocket-id.service" ];
              inherit onFailure;
              restartTriggers = [ (lib.getExe provisionScript) ];
              path = [
                pkgs.curl
                pkgs.jq
                pkgs.coreutils
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                User = "root";
              };
              preStart = ''
                ${pkgs.coreutils}/bin/timeout 120 ${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString pocketIdPort}/healthz > /dev/null 2>&1; do sleep 2; done'
              '';
              script = ''
                ${lib.getExe provisionScript}
              '';
            };

            # Secret rotation health metrics — monitors OIDC client secret
            # file freshness. Alerts when any secret hasn't been rotated in >90d.
            pocket-id-secret-rotation = {
              description = "Pocket ID OIDC client secret rotation metrics";
              after = [ "pocket-id-provision.service" ];
              serviceConfig = {
                Type = "oneshot";
                ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
              };
              script = ''
                OUT="/var/lib/prometheus-node-exporter/textfile_collectors/secret-rotation.prom"
                NOW="$(${pkgs.coreutils}/bin/date +%s)"
                MAX_AGE_DAYS=90
                ANY_STALE=0
                TEMP="$OUT.tmp"
                : > "$TEMP"

                if [ -d "${clientSecretsDir}" ]; then
                  for f in "${clientSecretsDir}"/*; do
                    [ -f "$f" ] || continue
                    CLIENT="$(basename "$f")"
                    MTIME="$(${pkgs.coreutils}/bin/stat -c %Y "$f")"
                    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
                    STALE=0
                    [ "$AGE_DAYS" -gt "$MAX_AGE_DAYS" ] && STALE=1 && ANY_STALE=1
                    echo "secret_rotation_age_days{client=\"$CLIENT\"} $AGE_DAYS" >> "$TEMP"
                    echo "secret_rotation_stale{client=\"$CLIENT\"} $STALE" >> "$TEMP"
                  done
                fi

                echo "secret_rotation_all_fresh $([ "$ANY_STALE" -eq 0 ] && echo 1 || echo 0)" >> "$TEMP"
                mv "$TEMP" "$OUT"
              '';
            };

            # Pocket ID is the SSO backbone: losing its SQLite DB loses every
            # OIDC client, user, and keypair. Nightly sqlite3 `.backup` (WAL-safe
            # online copy) to the mirrored HDD pool (3-drive repurposing, 2026-08-16).
            pocket-id-backup = {
              description = "Pocket ID SQLite backup to the HDD pool";
              after = [ "pocket-id.service" ];
              wants = [ "pocket-id.service" ];
              inherit onFailure;
              unitConfig.RequiresMountsFor = [ pocketIdBackupDir ];
              path = [ pkgs.sqlite ];
              serviceConfig = lib.mkMerge [
                (harden {
                  MemoryMax = "256M";
                  ReadWritePaths = [ pocketIdBackupDir ];
                })
                (serviceOneshotDefaults { })
                {
                  Type = "oneshot";
                  User = "pocket-id";
                  Group = "pocket-id";
                }
              ];
              script = ''
                set -euo pipefail
                stamp="$(date +%Y%m%d-%H%M%S)"
                sqlite3 "${dataDir}/data/pocket-id.db" ".backup '${pocketIdBackupDir}/pocket-id-$stamp.db'"
                find ${pocketIdBackupDir} -name "pocket-id-*.db" -mtime +14 -delete
                echo "pocket-id-backup: wrote pocket-id-$stamp.db"
              '';
            };
          };

          timers.pocket-id-secret-rotation = {
            description = "Check OIDC client secret rotation freshness";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "10m";
              OnUnitActiveSec = "1h";
            };
          };

          timers.pocket-id-backup = {
            description = "Daily Pocket ID SQLite backup to the HDD pool";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 04:00:00";
              Persistent = true;
              RandomizedDelaySec = "15m";
            };
          };
        };
      };
    };
}
