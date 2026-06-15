# Pocket ID: passkey-only OIDC provider replacing Authelia
# Declaratively provisions admin user, OIDC clients, and avatar
_: {
  flake.nixosModules.pocket-id = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.pocket-id-config;
    inherit (config.networking) domain;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure serviceTypes ports mkSecretCheck;
    pocketIdPort = cfg.port;
    metricsPort = cfg.metricsPort;

    dataDir = config.services.pocket-id.dataDir;
    clientSecretsDir = "${dataDir}/client-secrets";
    apiUrl = "http://127.0.0.1:${toString pocketIdPort}";

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

    provisionScript = pkgs.writeShellApplication {
      name = "pocket-id-provision";
      runtimeInputs = [pkgs.curl pkgs.jq pkgs.coreutils];
      text = ''
        set -euo pipefail

        API_URL="${apiUrl}"
        API_KEY_FILE="${config.sops.secrets.pocket_id_static_api_key.path}"
        API_KEY="$(cat "$API_KEY_FILE")"
        CLIENT_SECRETS_DIR="${clientSecretsDir}"
        MIGRATION_MARKER="${dataDir}/.provision-migrated"

        mkdir -p "$CLIENT_SECRETS_DIR"
        chown pocket-id:pocket-id "$CLIENT_SECRETS_DIR"
        chmod 750 "$CLIENT_SECRETS_DIR"

        echo "=== Pocket ID Provisioning ==="

        # ── Helper: authenticated API call ──
        api_get() {
          local path="$1"
          local resp
          resp=$(curl -s -H "X-API-Key: $API_KEY" "$API_URL$path" 2>&1) || true
          echo "$resp"
        }

        api_put() {
          local path="$1"
          local body="$2"
          curl -s -w '\n%{http_code}' -X PUT -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
            -d "$body" "$API_URL$path" 2>&1 || true
        }

        api_post() {
          local path="$1"
          local body="$2"
          curl -s -w '\n%{http_code}' -X POST -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
            -d "$body" "$API_URL$path" 2>&1 || true
        }

        # ── Migration: copy old sops secrets on first run ──
        if [ ! -f "$MIGRATION_MARKER" ]; then
          echo "First run: migrating existing sops secrets..."
          ${lib.optionalString (config.sops.secrets ? oauth2_proxy_client_secret) ''
          OLD_SECRET="${config.sops.secrets.oauth2_proxy_client_secret.path}"
          if [ -f "$OLD_SECRET" ]; then
            cp "$OLD_SECRET" "$CLIENT_SECRETS_DIR/oauth2-proxy"
            chown pocket-id:pocket-id "$CLIENT_SECRETS_DIR/oauth2-proxy"
            chmod 640 "$CLIENT_SECRETS_DIR/oauth2-proxy"
            echo "  Migrated oauth2-proxy secret."
          fi
        ''}
          ${lib.optionalString (config.sops.secrets ? immich_oauth_client_secret) ''
          OLD_SECRET="${config.sops.secrets.immich_oauth_client_secret.path}"
          if [ -f "$OLD_SECRET" ]; then
            cp "$OLD_SECRET" "$CLIENT_SECRETS_DIR/immich"
            chown pocket-id:pocket-id "$CLIENT_SECRETS_DIR/immich"
            chmod 640 "$CLIENT_SECRETS_DIR/immich"
            echo "  Migrated immich secret."
          fi
        ''}
          touch "$MIGRATION_MARKER"
          chown pocket-id:pocket-id "$MIGRATION_MARKER"
        fi

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
          AVATAR_RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
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
          LOGO_RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
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
        ${lib.concatMapStringsSep "\n" (client: let
            logoPath =
              if client.logoFile != null
              then toString client.logoFile
              else "";
            clientAttrs =
              {
                name = client.name;
                callbackURLs = client.callbackURLs;
                logoutCallbackURLs = client.logoutCallbackURLs or [];
                isPublic = client.isPublic;
                pkceEnabled = client.pkceEnabled;
                requiresReauthentication = client.requiresReauthentication or false;
              }
              // lib.optionalAttrs (client.launchURL or null != null) {
                launchURL = client.launchURL;
              };
            createAttrs = clientAttrs // {id = client.clientId;};
          in ''
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
              RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
              CLIENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // empty' 2>/dev/null || true)

              if echo "$RESPONSE_BODY" | grep -qi "already exists"; then
                echo "  Client '${client.name}' created in race, re-fetching..."
                ALL_CLIENTS2=$(api_get "/api/oidc/clients?pagination%5Blimit%5D=100")
                CLIENT_ID=$(echo "$ALL_CLIENTS2" | jq -r '.data[] | select(.id == "${client.clientId}") | .id // empty' 2>/dev/null | head -1)
              elif [ -z "$CLIENT_ID" ]; then
                echo "  ERROR: Failed to create client '${client.name}'. Response: $RESPONSE_BODY" >&2
              else
                echo "  Created client '${client.name}' with ID: $CLIENT_ID"
              fi
            fi

            # Upload logo if configured
            upload_logo "$CLIENT_ID" "${logoPath}"

            # Generate/get client secret
            SECRET_FILE="$CLIENT_SECRETS_DIR/${client.clientId}"
            if [ -f "$SECRET_FILE" ] && [ -s "$SECRET_FILE" ]; then
              echo "  Secret file already exists."
            else
              echo "  Generating client secret..."
              SECRET_RESPONSE=$(curl -s -X POST \
                -H "X-API-Key: $API_KEY" \
                "$API_URL/api/oidc/clients/$CLIENT_ID/secret" 2>&1 || true)
              CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | jq -r '.secret // empty' 2>/dev/null || true)

              if [ -n "$CLIENT_SECRET" ]; then
                echo "$CLIENT_SECRET" > "$SECRET_FILE"
                chmod 640 "$SECRET_FILE"
                chown pocket-id:pocket-id "$SECRET_FILE"
                echo "  Secret written to $SECRET_FILE"
              else
                echo "  WARNING: Failed to generate secret for '${client.name}'" >&2
              fi
            fi
          '')
          cfg.provision.oidcClients}

        echo "=== Pocket ID Provisioning Complete ==="
      '';
    };
  in {
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
          default = "noreply@cloud.larsartmann.com";
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
          type = lib.types.listOf (lib.types.submodule {
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
                default = [];
                description = "Allowed callback URLs";
              };
              logoutCallbackURLs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [];
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
          });
          default = [
            {
              name = "oauth2-proxy";
              clientId = "oauth2-proxy";
              callbackURLs = ["https://auth.${domain}/oauth2/callback"];
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
              logoutCallbackURLs = ["https://immich.${domain}"];
              pkceEnabled = true;
              logoFile = ../../../assets/immich-logo.svg;
            }
          ];
          description = "OIDC clients to create declaratively";
        };

        avatarFile = lib.mkOption {
          type = lib.types.path;
          default = ../../../assets/avatar.png;
          description = "Path to avatar image to seed for admin user";
        };
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !cfg.provision.enable || (config.sops.secrets ? pocket_id_static_api_key);
          message = "pocket-id: provision.enable requires pocket_id_static_api_key to be defined in sops secrets.\n  Generate one with: openssl rand -base64 32\n  Then add it to platforms/nixos/secrets/pocket-id.yaml";
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
          UPLOAD_PATH = "data/uploads";
          SMTP_HOST = cfg.smtp.host;
          SMTP_PORT = toString cfg.smtp.port;
          SMTP_USER = cfg.smtp.user;
          SMTP_FROM = cfg.smtp.from;
          SMTP_SKIP_SSL_VERIFY = cfg.smtp.skipSslVerify;
        };
        credentials =
          {
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
        ];

        services.pocket-id = {
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
            }
            // lib.optionalAttrs cfg.provision.enable {
              ExecStartPre = lib.mkForce [
                "+${lib.getExe checkEncryptionKey}"
                "+${lib.getExe checkStaticApiKey}"
              ];
            };
        };

        services.pocket-id-provision = lib.mkIf cfg.provision.enable {
          description = "Pocket ID Provisioning — admin user, OIDC clients, and avatar";
          after = ["pocket-id.service"];
          wants = ["pocket-id.service"];
          wantedBy = ["pocket-id.service"];
          inherit onFailure;
          path = [pkgs.curl pkgs.jq pkgs.coreutils];
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
      };
    };
  };
}
