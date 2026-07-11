# sops-nix secret definitions for all SystemNix services
_: let
  secretsDir = ./../../../platforms/nixos/secrets;

  mkSecrets = file: defaults: names:
    names
    |> map (name: {
      inherit name;
      value =
        defaults
        // {
          sopsFile = secretsDir + "/${file}";
        };
    })
    |> builtins.listToAttrs;

  mkKeyedSecrets = file: defaults: keyMap:
    keyMap
    |> builtins.mapAttrs (
      _name: key:
        defaults
        // {
          sopsFile = secretsDir + "/${file}";
          inherit key;
        }
    );
in {
  flake.nixosModules.sops = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.sops-config;
    inherit (config.users) primaryUser;
    svcEnabled = name: (config.services.${name} or {}).enable or false;
  in {
    options.services.sops-config = {
      enable = lib.mkEnableOption "sops-nix secret definitions for SystemNix services";
    };

    config = lib.mkIf cfg.enable {
      sops = {
        defaultSopsFile = lib.path.append secretsDir "secrets.yaml";
        age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
        gnupg.sshKeyPaths = [];

        secrets =
          {}
          // mkSecrets "secrets.yaml"
          {
            owner = primaryUser;
            group = "users";
            restartUnits = [
              "forgejo-github-sync.service"
              "forgejo-ensure-repos.service"
            ];
          }
          [
            "forgejo_token"
            "github_token"
            "github_user"
          ]
          // mkSecrets "pocket-id.yaml"
          {
            owner = "pocket-id";
            group = "pocket-id";
            restartUnits = ["pocket-id.service"];
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
              restartUnits = ["oauth2-proxy.service"];
            };
            oauth2_proxy_cookie_secret = {
              sopsFile = lib.path.append secretsDir "pocket-id.yaml";
              owner = "oauth2-proxy";
              group = "oauth2-proxy";
              restartUnits = ["oauth2-proxy.service"];
            };
          }
          // {
            immich_oauth_client_secret = {
              sopsFile = lib.path.append secretsDir "pocket-id.yaml";
              owner = "immich";
              group = "immich";
              restartUnits = ["immich-server.service"];
            };
          }
          // mkSecrets "dnsblockd-certs.yaml" {} ["dnsblockd_ca_cert"]
          // {
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
              restartUnits = ["livekit.service"];
            } ["livekit_keys"]
          )
          // lib.optionalAttrs (svcEnabled "hermes") (
            mkKeyedSecrets "hermes.yaml"
            {
              owner = "hermes";
              group = "hermes";
              restartUnits = ["hermes.service"];
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
          // lib.optionalAttrs (svcEnabled "crush-daily") (
            mkSecrets "crush-daily.yaml" {
              owner = "crush-daily";
              group = "crush-daily";
              restartUnits = ["crush-daily.service"];
            } ["synthetic_api_key"]
          )
          // lib.optionalAttrs (svcEnabled "openseo") (
            mkSecrets "openseo.yaml" {
              owner = "root";
              group = "root";
              restartUnits = ["openseo.service"];
            } ["dataforseo_api_key"]
          )
          # cloud_auth_token: single tenant-level API key shared by ALL monitor365
          # consumers (server bootstrap, system agent, desktop agent).  The same
          # YAML key is materialised as two sops secret entries because sops-nix
          # grants file ownership per entry — the desktop user and the
          # monitor365-server system user need separately-owned file handles.
          # Desktop agent secret — owned by desktop user (user service)
          // lib.optionalAttrs (svcEnabled "monitor365-desktop") (
            mkSecrets "monitor365.yaml"
            {
              owner = primaryUser;
              group = "users";
              restartUnits = ["monitor365-desktop.service"];
            }
            ["cloud_auth_token"]
          )
          # Server + system agent secrets — owned by dedicated system user
          // lib.optionalAttrs (svcEnabled "monitor365-server") (
            mkSecrets "monitor365.yaml"
            {
              owner = "monitor365-server";
              group = "monitor365-server";
              restartUnits = ["monitor365-server.service" "monitor365.service"];
            }
            ["server_jwt_secret" "cloud_auth_token"]
          )
          // lib.optionalAttrs (svcEnabled "signoz" || svcEnabled "gatus-config") (
            mkSecrets "signoz.yaml" {
              owner = "root";
              group = "root";
              restartUnits = [
                "signoz-provision.service"
                "gatus.service"
              ];
            } ["discord_alert_webhook_url"]
          )
          // lib.optionalAttrs (svcEnabled "discordsync") (
            mkSecrets "discordsync.yaml"
            {
              owner = "discordsync";
              group = "discordsync";
              restartUnits = ["discordsync.service"];
            }
            [
              "discordsync_discord_token"
              "discordsync_turso_url"
              "discordsync_turso_auth_token"
            ]
          )
          // lib.optionalAttrs
          (svcEnabled "discordsync" && (config.services.discordsync.gcsBucket or null) != null)
          {
            discordsync_gcs_credentials = {
              sopsFile = lib.path.append secretsDir "discordsync.yaml";
              owner = "discordsync";
              group = "discordsync";
              restartUnits = ["discordsync.service"];
            };
          }
          // lib.optionalAttrs (svcEnabled "dns-failover") (
            mkSecrets "dns-failover.yaml" {} ["vrrp_auth_password"]
          );

        templates =
          {
            "forgejo-sync.env" = {
              owner = primaryUser;
              group = "users";
              content = lib.generators.toKeyValue {} {
                FORGEJO_TOKEN = config.sops.placeholder.forgejo_token;
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
              restartUnits = ["hermes.service"];
              content = lib.generators.toKeyValue {} {
                DISCORD_BOT_TOKEN = config.sops.placeholder.hermes_discord_bot_token;
                GLM_API_KEY = config.sops.placeholder.hermes_glm_api_key;
                MINIMAX_API_KEY = config.sops.placeholder.hermes_minimax_api_key;
                XIAOMI_API_KEY = config.sops.placeholder.hermes_xiaomi_api_key;
                FAL_KEY = config.sops.placeholder.hermes_fal_key;
                FIRECRAWL_API_KEY = config.sops.placeholder.hermes_firecrawl_api_key;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "hermes" && svcEnabled "projects-management-automation") {
            "pma-env" = {
              owner = primaryUser;
              group = "users";
              restartUnits = ["projects-management-automation.service"];
              content = lib.generators.toKeyValue {} {
                MINIMAX_API_KEY = config.sops.placeholder.hermes_minimax_api_key;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "monitor365-desktop") {
            # Desktop agent env: injects the tenant API key as MONITOR365__CLOUD__AUTH_TOKEN
            "monitor365-desktop-agent-env" = {
              owner = primaryUser;
              group = "users";
              restartUnits = ["monitor365-desktop.service"];
              content = lib.generators.toKeyValue {} {
                MONITOR365__CLOUD__AUTH_TOKEN = config.sops.placeholder.cloud_auth_token;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "monitor365-server") {
            "monitor365-server-env" = {
              owner = "monitor365-server";
              group = "monitor365-server";
              restartUnits = ["monitor365-server.service"];
              content = lib.generators.toKeyValue {} {
                MONITOR365_SERVER__JWT_SECRET = config.sops.placeholder.server_jwt_secret;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "openseo") {
            "openseo-env" = {
              owner = "root";
              group = "root";
              mode = "0400";
              restartUnits = ["openseo.service"];
              content = lib.generators.toKeyValue {} {
                DATAFORSEO_API_KEY = config.sops.placeholder.dataforseo_api_key;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "crush-daily") {
            "crush-daily-env" = {
              owner = "crush-daily";
              group = "crush-daily";
              mode = "0400";
              restartUnits = ["crush-daily.service"];
              content = lib.generators.toKeyValue {} {
                CRUSH_DAILY_LLM_API_KEY = config.sops.placeholder.synthetic_api_key;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "gatus-config") {
            "gatus-env" = {
              owner = "root";
              group = "root";
              restartUnits = ["gatus.service"];
              content = lib.generators.toKeyValue {} {
                DISCORD_WEBHOOK_URL = config.sops.placeholder.discord_alert_webhook_url;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "discordsync") {
            "discordsync-env" = {
              owner = "discordsync";
              group = "discordsync";
              mode = "0400";
              restartUnits = ["discordsync.service"];
              content = lib.generators.toKeyValue {} {
                DISCORD_TOKEN = config.sops.placeholder.discordsync_discord_token;
                TURSO_URL = config.sops.placeholder.discordsync_turso_url;
                TURSO_AUTH_TOKEN = config.sops.placeholder.discordsync_turso_auth_token;
              };
            };
          }
          // lib.optionalAttrs (svcEnabled "dns-failover") {
            "dns-failover-env" = {
              content = lib.generators.toKeyValue {} {
                VRRP_AUTH_PASSWORD = config.sops.placeholder.vrrp_auth_password;
              };
            };
          };
      };
    };
  };
}
