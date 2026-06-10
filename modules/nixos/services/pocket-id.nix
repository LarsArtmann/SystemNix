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
          curl -s -H "X-API-KEY: $API_KEY" "$API_URL$path" 2>/dev/null || true
        }

        api_post() {
          local path="$1"
          local body="$2"
          curl -s -w '\n%{http_code}' -X POST -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" \
            -d "$body" "$API_URL$path" 2>/dev/null || true
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
        ALL_USERS=$(api_get "/api/users?pagination[limit]=100")
        ADMIN_USER_ID=$(echo "$ALL_USERS" | jq -r '.data[] | select(.username == "'"$ADMIN_USERNAME"'") | .id // empty' | head -1)

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
              emailVerified: true,
              firstName: $firstName,
              lastName: $lastName,
              displayName: "\($firstName) \($lastName)",
              isAdmin: true,
              disabled: false
            }')

          CREATE_RESPONSE=$(api_post "/api/users" "$USER_JSON")
          HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -1)
          RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
          ADMIN_USER_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // empty')

          if [ -n "$ADMIN_USER_ID" ]; then
            echo "  Created admin user with ID: $ADMIN_USER_ID"
          elif echo "$RESPONSE_BODY" | jq -e '.error | test("already in use")' >/dev/null 2>&1; then
            echo "  User already exists (race), fetching ID..."
            ADMIN_USER_ID=$(api_get "/api/users?pagination[limit]=100" | jq -r '.data[] | select(.username == "'"$ADMIN_USERNAME"'") | .id // empty' | head -1)
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
            -H "X-API-KEY: $API_KEY" \
            -F "file=@$AVATAR_FILE" \
            "$API_URL/api/users/$ADMIN_USER_ID/profile-picture" 2>/dev/null || true)

          if [ "$AVATAR_RESPONSE" = "200" ] || [ "$AVATAR_RESPONSE" = "204" ]; then
            echo "  Avatar uploaded successfully."
          else
            echo "  Avatar upload response: $AVATAR_RESPONSE"
          fi
        fi

        # ── Step 3: OIDC Clients ──
        ${lib.concatMapStringsSep "\n" (client: ''
            echo "Checking OIDC client: ${client.name}..."
            ALL_CLIENTS=$(api_get "/api/oidc/clients?pagination[limit]=100")
            EXISTING_CLIENT=$(echo "$ALL_CLIENTS" | jq -r '.data[] | select(.name == "${client.name}") | .id // empty' | head -1)

            if [ -n "$EXISTING_CLIENT" ]; then
              echo "  Client '${client.name}' already exists (ID: $EXISTING_CLIENT)."
              CLIENT_ID="$EXISTING_CLIENT"
            else
              echo "  Creating OIDC client: ${client.name}"
              CLIENT_JSON=$(jq -n \
                --arg id "${client.clientId}" \
                --arg name "${client.name}" \
                --argjson callbacks '${builtins.toJSON client.callbackURLs}' \
                --argjson logouts '${builtins.toJSON (client.logoutCallbackURLs or [])}' \
                '{
                  id: $id,
                  name: $name,
                  callbackURLs: $callbacks,
                  logoutCallbackURLs: $logouts,
                  isPublic: false,
                  pkceEnabled: false,
                  credentials: {}
                }')

              CREATE_RESPONSE=$(api_post "/api/oidc/clients" "$CLIENT_JSON")
              RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | sed '$d')
              CLIENT_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // empty')

              if [ -z "$CLIENT_ID" ]; then
                echo "  ERROR: Failed to create client '${client.name}'. Response: $RESPONSE_BODY" >&2
              else
                echo "  Created client '${client.name}' with ID: $CLIENT_ID"
              fi
            fi

            # Generate/get client secret
            SECRET_FILE="$CLIENT_SECRETS_DIR/${client.clientId}"
            if [ -f "$SECRET_FILE" ] && [ -s "$SECRET_FILE" ]; then
              echo "  Secret file already exists."
            else
              echo "  Generating client secret..."
              SECRET_RESPONSE=$(curl -s -X POST \
                -H "X-API-KEY: $API_KEY" \
                "$API_URL/api/oidc/clients/$CLIENT_ID/secret" 2>/dev/null || true)
              CLIENT_SECRET=$(echo "$SECRET_RESPONSE" | jq -r '.secret // empty')

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
            };
          });
          default = [
            {
              name = "oauth2-proxy";
              clientId = "oauth2-proxy";
              callbackURLs = ["https://auth.${domain}/oauth2/callback"];
            }
            {
              name = "immich";
              clientId = "immich";
              callbackURLs = ["https://immich.${domain}/api/auth/callback"];
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
          LOG_LEVEL = "info";
          VERSION_CHECK_DISABLED = true;
          AUDIT_LOG_RETENTION_DAYS = "90";
          DB_CONNECTION_STRING = "data/pocket-id.db";
          UPLOAD_PATH = "data/uploads";
        };
        credentials =
          {
            ENCRYPTION_KEY = config.sops.secrets.pocket_id_encryption_key.path;
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
