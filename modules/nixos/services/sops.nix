# sops-nix secret definitions for all SystemNix services
_:
let
  secretsDir = ./../../../platforms/nixos/secrets;

  mkSecrets =
    file: defaults: names:
    names
    |> map (name: {
      inherit name;
      value = defaults // {
        sopsFile = secretsDir + "/${file}";
      };
    })
    |> builtins.listToAttrs;

  mkKeyedSecrets =
    file: defaults: keyMap:
    keyMap
    |> builtins.mapAttrs (
      _name: key:
      defaults
      // {
        sopsFile = secretsDir + "/${file}";
        inherit key;
      }
    );
in
{
  flake.nixosModules.sops =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.sops-config;
      inherit (config.users) primaryUser;
      svcEnabled = name: (config.services.${name} or { }).enable or false;
    in
    {
      options.services.sops-config = {
        enable = lib.mkEnableOption "sops-nix secret definitions for SystemNix services";
      };

      config = lib.mkIf cfg.enable {
        sops = {
          defaultSopsFile = lib.path.append secretsDir "secrets.yaml";
          age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          gnupg.sshKeyPaths = [ ];

          secrets =
            { }
            //
              mkSecrets "secrets.yaml"
                {
                  owner = primaryUser;
                  group = "users";
                  restartUnits = [
                    "forgejo-github-sync.service"
                    "forgejo-ensure-repos.service"
                  ];
                }
                [
                  "github_token"
                  "github_user"
                ]
            //
              mkSecrets "pocket-id.yaml"
                {
                  owner = "pocket-id";
                  group = "pocket-id";
                  restartUnits = [ "pocket-id.service" ];
                }
                [
                  "pocket_id_encryption_key"
                  "pocket_id_static_api_key"
                  "pocket_id_smtp_password"
                ]
            // {
              oauth2_proxy_client_secret = {
                sopsFile = lib.path.append secretsDir "pocket-id.yaml";
                owner = "oauth2-proxy";
                group = "oauth2-proxy";
                restartUnits = [ "oauth2-proxy.service" ];
              };
              oauth2_proxy_cookie_secret = {
                sopsFile = lib.path.append secretsDir "pocket-id.yaml";
                owner = "oauth2-proxy";
                group = "oauth2-proxy";
                restartUnits = [ "oauth2-proxy.service" ];
              };
            }
            // {
              immich_oauth_client_secret = {
                sopsFile = lib.path.append secretsDir "pocket-id.yaml";
                owner = "immich";
                group = "immich";
                restartUnits = [ "immich-server.service" ];
              };
            }
            // {
              paperless_admin_password = {
                sopsFile = lib.path.append secretsDir "paperless.yaml";
                # Root-owned: paperless-scheduler reads it via systemd
                # LoadCredential (PID 1 reads the file, not the service user).
                restartUnits = [ "paperless-scheduler.service" ];
              };
            }
            // {
              # The CA cert is PUBLIC material (every browser trust store gets
              # a copy by design). It MUST be world-readable: the
              # dnsblockd-cert-import USER unit runs certutil as the session
              # user, and Firefox policies read the same path at startup.
              # root:root 0400 made both fail with EACCES (certutil exit 255,
              # 2026-08-22 boot).
              dnsblockd_ca_cert = {
                sopsFile = lib.path.append secretsDir "dnsblockd-certs.yaml";
                mode = "0444";
              };
              dnsblockd_ca_key = {
                sopsFile = lib.path.append secretsDir "dnsblockd-certs.yaml";
                mode = "0400";
              };
              dnsblockd_server_cert = {
                sopsFile = lib.path.append secretsDir "dnsblockd-certs.yaml";
                owner = "caddy";
                group = "caddy";
              };
              dnsblockd_server_key = {
                sopsFile = lib.path.append secretsDir "dnsblockd-certs.yaml";
                owner = "caddy";
                group = "caddy";
                mode = "0400";
              };
            }
            // lib.optionalAttrs (svcEnabled "voice-agents") (
              mkSecrets "voice-agents.yaml" {
                restartUnits = [ "livekit.service" ];
              } [ "livekit_keys" ]
            )
            // lib.optionalAttrs (svcEnabled "hermes") (
              mkKeyedSecrets "hermes.yaml"
                {
                  owner = "hermes";
                  group = "hermes";
                  restartUnits = [ "hermes.service" ];
                }
                {
                  hermes_discord_bot_token = "discord_bot_token";
                  hermes_glm_api_key = "glm_api_key";
                  hermes_minimax_api_key = "minimax_api_key";
                  hermes_xiaomi_api_key = "xiaomi_api_key";
                  hermes_fal_key = "fal_key";
                  hermes_firecrawl_api_key = "firecrawl_api_key";
                }
            )
            // lib.optionalAttrs (svcEnabled "hermes") (
              # Read-only GitHub PAT for private-repo clones (T14, user
              # decision 2026-08-20: read-only, permanently no-push). Own
              # file because hermes.yaml is modifiable only with the host
              # age PRIVATE key — this one was created public-key-only, so
              # the user can `sops --set` the real token in after creating
              # a fine-grained PAT (Contents: Read-only). Ships as a
              # PLACEHOLDER: every consumer treats non-github_pat_/ghp_
              # values as "no token" and stays inert.
              mkKeyedSecrets "hermes-github-token.yaml"
                {
                  owner = "hermes";
                  group = "hermes";
                  restartUnits = [
                    "hermes.service"
                    "hermes-github-verify.service"
                  ];
                }
                {
                  hermes_github_read_token = "github_read_token";
                }
            )
            // lib.optionalAttrs (svcEnabled "crush-daily") (
              mkSecrets "crush-daily.yaml" {
                owner = primaryUser;
                group = "users";
                restartUnits = [ "crush-daily.service" ];
              } [ "synthetic_api_key" ]
            )
            # Interactive crush provider keys (user sessions), relocated
            # 2026-08-31 out of the machine auth store
            # (~/.local/share/crush/crush.json) — plaintext keys readable by
            # every agent running as the user. Consumed by the HM crushrc
            # (`provider add --api-key "$(cat /run/secrets/<name>)"`), which
            # never persists the keys back. No restartUnits: read
            # interactively at crush session start. hyper stays store-owned
            # (OAuth refresh state, self-rotating — not a static key).
            //
              mkSecrets "crush.yaml"
                {
                  owner = primaryUser;
                  group = "users";
                  mode = "0400";
                }
                [
                  "zai_api_key"
                  "gemini_api_key"
                  "minimax_api_key"
                  "kimi_api_key"
                ]
            // lib.optionalAttrs (svcEnabled "bank-sync") (
              # The AES key lives in its own file: bank-sync.yaml holds the
              # real Wise token and is decryptable only with the host key
              # (root), so the encryption key was sops-encrypted to the
              # host age PUBLIC key in a separate file instead.
              mkSecrets "bank-sync.yaml" {
                owner = "bank-sync";
                group = "bank-sync";
                restartUnits = [ "bank-sync.service" ];
              } [ "wise_api_key" ]
              // mkSecrets "bank-sync-encryption.yaml" {
                owner = "bank-sync";
                group = "bank-sync";
                restartUnits = [ "bank-sync.service" ];
              } [ "encryption_key" ]
            )
            // lib.optionalAttrs (svcEnabled "file-and-image-renamer") (
              mkKeyedSecrets "crush-daily.yaml"
                {
                  owner = primaryUser;
                  group = "users";
                  restartUnits = [ "file-and-image-renamer.service" ];
                }
                {
                  # Same encrypted key as crush-daily's synthetic_api_key, but
                  # owned by primaryUser so the HM user service can read it.
                  file_renamer_synthetic_api_key = "synthetic_api_key";
                }
            )
            // lib.optionalAttrs (svcEnabled "openseo") (
              mkSecrets "openseo.yaml"
                {
                  owner = "root";
                  group = "root";
                  restartUnits = [ "openseo.service" ];
                }
                (
                  [ "dataforseo_api_key" ]
                  ++ lib.optionals config.services.openseo.googleSearchConsole.enable [
                    "google_client_id"
                    "google_client_secret"
                    "better_auth_secret"
                  ]
                  ++ lib.optionals config.services.openseo.aiFeatures.enable [
                    "openrouter_api_key"
                  ]
                )
            )
            # cloud_auth_token: single tenant-level API key shared by ALL monitor365
            # consumers (server bootstrap, unified agent).  The same YAML key is
            # materialised as a sops secret entry owned by the monitor365-server
            # system user.
            # Server + agent secrets — owned by dedicated system user
            // lib.optionalAttrs (svcEnabled "monitor365-server") (
              mkSecrets "monitor365.yaml"
                {
                  owner = "monitor365-server";
                  group = "monitor365-server";
                  restartUnits = [
                    "monitor365-server.service"
                    "monitor365.service"
                  ];
                }
                [
                  "server_jwt_secret"
                  "cloud_auth_token"
                ]
            )
            //
              lib.optionalAttrs
                (
                  svcEnabled "signoz"
                  || svcEnabled "gatus-config"
                  || svcEnabled "discordsync"
                  || svcEnabled "papdashboard"
                )
                (
                  mkSecrets "signoz.yaml" {
                    owner = "root";
                    group = "root";
                    restartUnits = [
                      "signoz-provision.service"
                      "gatus.service"
                    ]
                    ++ lib.optional (svcEnabled "discordsync") "discordsync.service"
                    ++ lib.optional (svcEnabled "papdashboard") "papdashboard.service";
                  } [ "discord_alert_webhook_url" ]
                )
            // lib.optionalAttrs (svcEnabled "papdashboard") (
              mkSecrets "papdashboard.yaml" {
                owner = "root";
                group = "root";
                restartUnits = [ "papdashboard.service" ];
              } [ "papdashboard_api_key" ]
            )
            // lib.optionalAttrs (svcEnabled "papdashboard") (
              # Dedicated insights-channel webhook (channel 1539383848549486632) —
              # raw Gatus alerts keep the shared discord_alert_webhook_url, so
              # the two streams land in two different Discord channels.
              mkSecrets "papdashboard-discord.yaml" {
                owner = "root";
                group = "root";
                restartUnits = [ "papdashboard.service" ];
              } [ "papdashboard_insights_webhook_url" ]
            )
            // lib.optionalAttrs (svcEnabled "discordsync") (
              mkSecrets "discordsync.yaml"
                {
                  owner = "discordsync";
                  group = "discordsync";
                  restartUnits = [ "discordsync.service" ];
                }
                [
                  "discordsync_discord_token"
                  "discordsync_turso_url"
                  "discordsync_turso_auth_token"
                ]
            )
            //
              lib.optionalAttrs
                (svcEnabled "discordsync" && (config.services.discordsync.gcsBucket or null) != null)
                {
                  discordsync_gcs_credentials = {
                    sopsFile = lib.path.append secretsDir "discordsync.yaml";
                    owner = "discordsync";
                    group = "discordsync";
                    restartUnits = [ "discordsync.service" ];
                  };
                }
            // lib.optionalAttrs (svcEnabled "dns-failover") (
              mkSecrets "dns-failover.yaml" { } [ "vrrp_auth_password" ]
            )
            // lib.optionalAttrs (svcEnabled "cv-server") (
              # Root-owned raw secret; the service consumes the "cv-env"
              # template (owner cv) which interpolates the placeholder.
              mkSecrets "cv.yaml" {
                owner = "root";
                group = "root";
                restartUnits = [ "cv-server.service" ];
              } [ "cv_api_key" ]
            )
            // lib.optionalAttrs (svcEnabled "inboxclean") (
              # Raw Google OAuth client credentials.json; the upstream module's
              # ExecStartPre seed script runs as User=inboxclean and copies it
              # into /var/lib/inboxclean/credentials.json on every start.
              mkSecrets "inboxclean.yaml" {
                owner = "inboxclean";
                group = "inboxclean";
                restartUnits = [
                  "inboxclean-web.service"
                  "inboxclean-sync.service"
                ];
              } [ "inboxclean_gmail_credentials" ]
            )
            // lib.optionalAttrs (svcEnabled "attic-config") (
              # atticd runs with DynamicUser=true (nixpkgs module default), so the
              # "atticd" user does NOT exist at sops-decrypt time and cannot own
              # files — same constraint as Gatus. The EnvironmentFile is read by
              # systemd (PID 1, root) and the env vars injected into the atticd
              # process, so a root-owned file is correct and secure.
              mkSecrets "attic.yaml" {
                owner = "root";
                group = "root";
                restartUnits = [ "atticd.service" ];
              } [ "attic_token_rs256_secret_base64" ]
            )
            // lib.optionalAttrs (svcEnabled "browser-history") (
              mkSecrets "browser-history.yaml" {
                owner = "root";
                group = "root";
                restartUnits = [ "browser-history.service" ];
              } [ "browser_history_agent_token" ]
            )
            // lib.optionalAttrs (svcEnabled "google-sync") (
              # Full rclone.conf INI for the Drive mirror (token is a JSON blob —
              # a file, not an env var: systemd EnvironmentFile quote-stripping
              # around embedded double quotes is a footgun). Root-owned: the
              # sync unit runs as root to write /mnt/pool.
              mkSecrets "google-sync.yaml" {
                owner = "root";
                restartUnits = [ "google-sync.service" ];
              } [ "google_sync_rclone_config" ]
            );

          templates = {
            "forgejo-sync.env" = {
              owner = primaryUser;
              group = "users";
              content = lib.generators.toKeyValue { } {
                GITHUB_TOKEN = config.sops.placeholder.github_token;
                GITHUB_USER = config.sops.placeholder.github_user;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "hermes") {
            "hermes-env" = {
              owner = "hermes";
              group = "hermes";
              mode = "0400";
              restartUnits = [ "hermes.service" ];
              content = lib.generators.toKeyValue { } {
                DISCORD_BOT_TOKEN = config.sops.placeholder.hermes_discord_bot_token;
                GLM_API_KEY = config.sops.placeholder.hermes_glm_api_key;
                MINIMAX_API_KEY = config.sops.placeholder.hermes_minimax_api_key;
                XIAOMI_API_KEY = config.sops.placeholder.hermes_xiaomi_api_key;
                FAL_KEY = config.sops.placeholder.hermes_fal_key;
                FIRECRAWL_API_KEY = config.sops.placeholder.hermes_firecrawl_api_key;
                HERMES_GITHUB_READ_TOKEN = config.sops.placeholder.hermes_github_read_token;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "projects-management-automation") {
            "pma-env" = {
              owner = primaryUser;
              group = "users";
              restartUnits = [ "projects-management-automation.service" ];
              content = lib.generators.toKeyValue { } (
                lib.optionalAttrs (svcEnabled "hermes") {
                  MINIMAX_API_KEY = config.sops.placeholder.hermes_minimax_api_key;
                }
              );
            };
          }
          // lib.optionalAttrs (svcEnabled "monitor365-server") {
            "monitor365-server-env" = {
              owner = "monitor365-server";
              group = "monitor365-server";
              restartUnits = [ "monitor365-server.service" ];
              content = lib.generators.toKeyValue { } {
                MONITOR365_SERVER__JWT_SECRET = config.sops.placeholder.server_jwt_secret;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "openseo") {
            "openseo-env" = {
              owner = "root";
              group = "root";
              mode = "0400";
              restartUnits = [ "openseo.service" ];
              content = lib.generators.toKeyValue { } (
                {
                  DATAFORSEO_API_KEY = config.sops.placeholder.dataforseo_api_key;
                }
                // lib.optionalAttrs config.services.openseo.googleSearchConsole.enable {
                  GOOGLE_CLIENT_ID = config.sops.placeholder.google_client_id;
                  GOOGLE_CLIENT_SECRET = config.sops.placeholder.google_client_secret;
                  BETTER_AUTH_SECRET = config.sops.placeholder.better_auth_secret;
                }
                // lib.optionalAttrs config.services.openseo.aiFeatures.enable {
                  OPENROUTER_API_KEY = config.sops.placeholder.openrouter_api_key;
                }
              );
            };
          }
          // lib.optionalAttrs (svcEnabled "crush-daily") {
            "crush-daily-env" = {
              owner = primaryUser;
              group = "users";
              mode = "0400";
              restartUnits = [ "crush-daily.service" ];
              content = lib.generators.toKeyValue { } {
                CRUSH_DAILY_LLM_API_KEY = config.sops.placeholder.synthetic_api_key;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "bank-sync") {
            "bank-sync-env" = {
              owner = "bank-sync";
              group = "bank-sync";
              mode = "0400";
              restartUnits = [ "bank-sync.service" ];
              content = lib.generators.toKeyValue { } {
                BANK_SYNC_WISE_API_KEY = config.sops.placeholder.wise_api_key;
                BANK_SYNC_SECURITY_ENCRYPTION_KEY = config.sops.placeholder.encryption_key;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "gatus-config") {
            "gatus-env" = {
              owner = "root";
              group = "root";
              restartUnits = [ "gatus.service" ];
              content = lib.generators.toKeyValue { } (
                {
                  DISCORD_WEBHOOK_URL = config.sops.placeholder.discord_alert_webhook_url;
                }
                // lib.optionalAttrs (svcEnabled "papdashboard") {
                  # Bearer key for the PapDashboard ingest custom alerting provider.
                  PAPDASHBOARD_INGEST_KEY = config.sops.placeholder.papdashboard_api_key;
                }
                // lib.optionalAttrs (svcEnabled "cv-server") {
                  # X-API-Key for the "CV Funnel Freshness" check: the same
                  # secret the cv-scan timer authenticates with, so gatus
                  # reads the guarded sse-stats endpoint.
                  CV_API_KEY = config.sops.placeholder.cv_api_key;
                }
              );
            };
          }
          // lib.optionalAttrs (svcEnabled "papdashboard") {
            "papdashboard-env" = {
              owner = "root";
              group = "root";
              mode = "0400";
              restartUnits = [ "papdashboard.service" ];
              content = lib.generators.toKeyValue { } {
                PAP_API_KEY = config.sops.placeholder.papdashboard_api_key;
                # Insights go to their OWN Discord channel; raw Gatus alerts
                # stay on the shared discord_alert_webhook_url channel.
                PAP_DISCORD_WEBHOOK = config.sops.placeholder.papdashboard_insights_webhook_url;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "discordsync") {
            "discordsync-env" = {
              owner = "discordsync";
              group = "discordsync";
              mode = "0400";
              restartUnits = [ "discordsync.service" ];
              content = lib.generators.toKeyValue { } {
                DISCORD_TOKEN = config.sops.placeholder.discordsync_discord_token;
                TURSO_URL = config.sops.placeholder.discordsync_turso_url;
                TURSO_AUTH_TOKEN = config.sops.placeholder.discordsync_turso_auth_token;
                # Self-alerting: the binary POSTs critical errors to this Discord webhook.
                # Sourced from the shared signoz.yaml secret (always decrypted alongside).
                DISCORDSYNC_WEBHOOK_URL = config.sops.placeholder.discord_alert_webhook_url;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "dns-failover") {
            "dns-failover-env" = {
              # Explicit owner: sops-nix's template assertions interpolate
              # `owner` into the message even when the assertion PASSES —
              # a null owner crashes `nix eval --json …config.assertions`.
              # uid/gid default to 0, so root:root preserves semantics.
              owner = "root";
              group = "root";
              mode = "0400";
              content = lib.generators.toKeyValue { } {
                VRRP_AUTH_PASSWORD = config.sops.placeholder.vrrp_auth_password;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "cv-server") {
            "cv-env" = {
              owner = "cv";
              group = "cv";
              mode = "0400";
              restartUnits = [ "cv-server.service" ];
              content = lib.generators.toKeyValue { } {
                # Guards mutating/admin API routes (X-API-Key header).
                # Read/rotate: sudo sops platforms/nixos/secrets/cv.yaml
                CV_API_KEY = config.sops.placeholder.cv_api_key;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "attic-config") {
            # RS256 (RSA PEM PKCS1), NOT HS256 — the nixpkgs atticd module reads
            # ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64. Generate with:
            #   openssl genrsa -traditional 4096 | base64 -w0
            # root-owned: atticd is a DynamicUser (see secrets block above).
            "attic-env" = {
              owner = "root";
              group = "root";
              mode = "0400";
              restartUnits = [ "atticd.service" ];
              content = lib.generators.toKeyValue { } {
                ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64 = config.sops.placeholder.attic_token_rs256_secret_base64;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "browser-history") {
            # Shared by server (DynamicUser) and agent (user). Both use
            # EnvironmentFile= which is read by systemd (root), so root-owned
            # is correct for both consumers.
            "browser-history-env" = {
              owner = "root";
              group = "root";
              mode = "0400";
              restartUnits = [
                "browser-history.service"
                "browser-history-agent.service"
              ];
              content = lib.generators.toKeyValue { } {
                BROWSER_HISTORY_AGENT_TOKEN = config.sops.placeholder.browser_history_agent_token;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "dns-blocker") {
            # Retired 2026-08-21: the Bearer token (DNSBLOCKD_AUTH_TOKEN) was
            # dropped in favor of OIDC SSO as the only dashboard credential.
            # When Pocket ID grows machine credentials, provision them here.
          };
        };
      };
    };
}
