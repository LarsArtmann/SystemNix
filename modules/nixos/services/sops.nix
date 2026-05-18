# sops-nix secret definitions for all SystemNix services
_: let
  secretsDir = ./../../../platforms/nixos/secrets;

  mkSecrets = file: defaults: names:
    names
    |> map (name: {
      inherit name;
      value = defaults // {sopsFile = secretsDir + "/${file}";};
    })
    |> builtins.listToAttrs;

  mkKeyedSecrets = file: defaults: keyMap:
    keyMap
    |> builtins.mapAttrs (_name: key:
      defaults
      // {
        sopsFile = secretsDir + "/${file}";
        inherit key;
      });
in {
  flake.nixosModules.sops = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.sops-config;
    inherit (config.users) primaryUser;
  in {
    options.services.sops-config = {
      enable = lib.mkEnableOption "sops-nix secret definitions for SystemNix services";
    };

    config = lib.mkIf cfg.enable {
      system.activationScripts.sops-provision-vrrp-password = lib.stringAfter ["etc"] ''
        secretsFile="${secretsDir}/secrets.yaml"
        key="dns_failover_vrrp_password"

        if ${pkgs.yq-go}/bin/yq ".$key" "$secretsFile" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "null"; then
          echo "[sops-provision] Adding $key to secrets.yaml..."
          export SOPS_AGE_KEY=$(${lib.getExe pkgs.ssh-to-age} -private < /etc/ssh/ssh_host_ed25519_key 2>/dev/null)
          ${lib.getExe pkgs.sops} --set "[\"$key\"] \"DNSClusterVRRP-evox2\"" "$secretsFile"
          echo "[sops-provision] Done."
          unset SOPS_AGE_KEY
        else
          echo "[sops-provision] $key already exists in secrets.yaml, skipping."
        fi
      '';

      sops = {
        defaultSopsFile = secretsDir + "/secrets.yaml";
        age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

        secrets =
          {}
          // mkSecrets "secrets.yaml" {
            owner = primaryUser;
            group = "users";
            restartUnits = ["gitea-github-sync.service" "gitea-ensure-repos.service"];
          } ["gitea_token" "github_token" "github_user"]
          // mkSecrets "authelia-secrets.yaml" {
            owner = "authelia-main";
            group = "authelia-main";
            restartUnits = ["authelia-main.service"];
          } ["authelia_jwt_secret" "authelia_storage_encryption_key" "authelia_oidc_hmac_secret"]
          // {
            authelia_oidc_issuer_private_key = {
              sopsFile = secretsDir + "/authelia-secrets.yaml";
              owner = "authelia-main";
              group = "authelia-main";
              mode = "0400";
              restartUnits = ["authelia-main.service"];
            };
          }
          // {
            immich_oauth_client_secret = {
              sopsFile = secretsDir + "/authelia-secrets.yaml";
              owner = "immich";
              group = "immich";
              restartUnits = ["immich-server.service"];
            };
          }
          // mkSecrets "dnsblockd-certs.yaml" {} ["dnsblockd_ca_cert"]
          // {
            dnsblockd_ca_key = {
              sopsFile = secretsDir + "/dnsblockd-certs.yaml";
              mode = "0400";
            };
            dnsblockd_server_cert = {
              sopsFile = secretsDir + "/dnsblockd-certs.yaml";
              owner = "caddy";
              group = "caddy";
            };
            dnsblockd_server_key = {
              sopsFile = secretsDir + "/dnsblockd-certs.yaml";
              owner = "caddy";
              group = "caddy";
              mode = "0400";
            };
          }
          // mkSecrets "voice-agents.yaml" {
            restartUnits = ["livekit.service"];
          } ["livekit_keys"]
          // mkKeyedSecrets "hermes.yaml" {
            owner = "hermes";
            group = "hermes";
            restartUnits = ["hermes.service"];
          } {
            hermes_discord_bot_token = "discord_bot_token";
            hermes_glm_api_key = "glm_api_key";
            hermes_minimax_api_key = "minimax_api_key";
            hermes_xiaomi_api_key = "xiaomi_api_key";
            hermes_fal_key = "fal_key";
            hermes_firecrawl_api_key = "firecrawl_api_key";
          }
          // mkSecrets "openseo.yaml" {
            owner = "root";
            group = "root";
            restartUnits = ["openseo.service"];
          } ["dataforseo_api_key"]
          // mkSecrets "monitor365.yaml" {
            owner = primaryUser;
            group = "users";
            restartUnits = ["monitor365.service" "monitor365-server.service"];
          } ["cloud_auth_token" "server_jwt_secret"]
          // mkSecrets "signoz.yaml" {
            owner = "signoz";
            group = "signoz";
            restartUnits = ["signoz-provision.service"];
          } ["discord_alert_webhook_url"]
          // mkSecrets "secrets.yaml" {
            restartUnits = ["keepalived.service"];
          } ["dns_failover_vrrp_password"];

        templates = {
          "gatus-env" = {
            owner = "root";
            group = "root";
            restartUnits = ["gatus.service"];
            content = ''
              DISCORD_WEBHOOK_URL=${config.sops.placeholder.discord_alert_webhook_url}
            '';
          };
          "gitea-sync.env" = {
            owner = primaryUser;
            group = "users";
            content = ''
              GITEA_TOKEN=${config.sops.placeholder.gitea_token}
              GITHUB_TOKEN=${config.sops.placeholder.github_token}
              GITHUB_USER=${config.sops.placeholder.github_user}
            '';
          };

          "hermes-env" = {
            owner = "hermes";
            group = "hermes";
            mode = "0400";
            restartUnits = ["hermes.service"];
            content = ''
              DISCORD_BOT_TOKEN=${config.sops.placeholder.hermes_discord_bot_token}
              GLM_API_KEY=${config.sops.placeholder.hermes_glm_api_key}
              MINIMAX_API_KEY=${config.sops.placeholder.hermes_minimax_api_key}
              XIAOMI_API_KEY=${config.sops.placeholder.hermes_xiaomi_api_key}
              FAL_KEY=${config.sops.placeholder.hermes_fal_key}
              FIRECRAWL_API_KEY=${config.sops.placeholder.hermes_firecrawl_api_key}
            '';
          };

          "monitor365-env" = {
            owner = primaryUser;
            group = "users";
            restartUnits = ["monitor365.service" "monitor365-server.service"];
            content = ''
              MONITOR365_SERVER__JWT_SECRET=${config.sops.placeholder.server_jwt_secret}
            '';
          };

          "openseo-env" = {
            owner = "root";
            group = "root";
            mode = "0400";
            restartUnits = ["openseo.service"];
            content = ''
              DATAFORSEO_API_KEY=${config.sops.placeholder.dataforseo_api_key}
            '';
          };

          "keepalived-vrrp-env" = {
            owner = "root";
            group = "root";
            restartUnits = ["keepalived.service"];
            content = ''
              VRRP_AUTH_PASSWORD=${config.sops.placeholder.dns_failover_vrrp_password}
            '';
          };
        };
      };
    };
  };
}
