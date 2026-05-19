# Authelia SSO/IDP: OIDC, TOTP, WebAuthn, file-based user backend
_: {
  flake.nixosModules.authelia = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.authelia-config;
    inherit (config.networking) domain;
    authHost = "auth.${domain}";
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure serviceTypes mkStateDir;
    authPort = cfg.port;

    mkClient = {
      client_id,
      client_name,
      redirect_uris,
      ...
    }: {
      inherit client_id client_name redirect_uris;
      client_secret = "$pbkdf2-sha512$310000$c8p78n7pUMln0jzvd4aK4Q$JNRBzwAo0ek5qKn50cFzzvE9RXV88h1wJn5KGiHrD0YKtZaR/nCb2CJPOsKaPK0hjf.9yHxzQGZziziccp6Yng";
      public = false;
      authorization_policy = "two_factor";
      require_pkce = true;
      pkce_challenge_method = "S256";
      scopes = ["openid" "profile" "email" "groups"];
      response_types = ["code"];
      grant_types = ["authorization_code"];
      access_token_signed_response_alg = "none";
      userinfo_signed_response_alg = "none";
      token_endpoint_auth_method = "client_secret_basic";
    };
  in {
    options.services.authelia-config = {
      enable = lib.mkEnableOption "Authelia SSO/IDP with SystemNix configuration";
      port = serviceTypes.servicePort 9091 "Port for the Authelia authentication server";
    };

    config = lib.mkIf cfg.enable {
      services.authelia.instances.main = {
        enable = true;

        secrets = {
          jwtSecretFile = config.sops.secrets.authelia_jwt_secret.path;
          storageEncryptionKeyFile = config.sops.secrets.authelia_storage_encryption_key.path;
          oidcHmacSecretFile = config.sops.secrets.authelia_oidc_hmac_secret.path;
          oidcIssuerPrivateKeyFile = config.sops.secrets.authelia_oidc_issuer_private_key.path;
        };

        settings = {
          theme = "dark";
          default_2fa_method = "totp";

          server = {
            address = "tcp://127.0.0.1:${toString authPort}/";
            endpoints = {
              enable_pprof = false;
              enable_expvars = false;
            };
          };

          log = {
            level = "info";
            format = "text";
          };

          telemetry.metrics = {
            enabled = true;
            address = "tcp://127.0.0.1:9959";
          };

          totp = {
            disable = false;
            issuer = "evo-x2";
            algorithm = "SHA256";
            digits = 6;
            period = 30;
            skew = 1;
          };

          webauthn = {
            disable = false;
            display_name = "evo-x2";
            attestation_conveyance_preference = "indirect";
            selection_criteria = {
              user_verification = "preferred";
            };
          };

          authentication_backend = {
            password_reset.disable = false;
            refresh_interval = "5m";
            file = {
              path = "/var/lib/authelia-main/users_database.yml";
              password = {
                algorithm = "argon2";
                argon2 = {
                  variant = "argon2id";
                  iterations = 3;
                  memory = 65536;
                  parallelism = 4;
                  key_length = 32;
                  salt_length = 16;
                };
              };
            };
          };

          password_policy = {
            standard = {
              enabled = true;
              min_length = 8;
              max_length = 128;
              require_uppercase = true;
              require_lowercase = true;
              require_number = true;
              require_special = true;
            };
          };

          session = {
            name = "authelia_session";
            same_site = "lax";
            expiration = "1h";
            inactivity = "5m";
            remember_me = "1M";
            cookies = [
              {
                name = "authelia_session";
                inherit domain;
                authelia_url = "https://${authHost}";
                default_redirection_url = "https://dash.${domain}";
                same_site = "lax";
                expiration = "1h";
                inactivity = "5m";
                remember_me = "1M";
              }
            ];
          };

          regulation = {
            max_retries = 3;
            find_time = "2m";
            ban_time = "5m";
          };

          storage.local.path = "/var/lib/authelia-main/db.sqlite3";

          notifier = {
            disable_startup_check = true;
            filesystem.filename = "/var/lib/authelia-main/notification.txt";
          };

          access_control = {
            default_policy = "deny";
            rules = [
              {
                domain = authHost;
                policy = "bypass";
              }
              {
                domain = "*.${domain}";
                policy = "two_factor";
                subject = ["user:lars"];
              }
            ];
          };

          identity_providers.oidc = {
            lifespans = {
              access_token = "1h";
              authorize_code = "1m";
              id_token = "1h";
              refresh_token = "90m";
            };
            cors = {
              allowed_origins = ["https://*.${domain}"];
              endpoints = [
                "authorization"
                "token"
                "revocation"
                "introspection"
                "userinfo"
              ];
            };
            clients = [
              (mkClient {
                client_id = "immich";
                client_name = "Immich";
                redirect_uris = [
                  "https://immich.${domain}/auth/login"
                  "https://immich.${domain}/user-settings"
                  "app.immich:///oauth-callback"
                ];
              })
              (mkClient {
                client_id = "forgejo";
                client_name = "Forgejo";
                redirect_uris = [
                  "https://forgejo.${domain}/user/oauth2/authelia/callback"
                ];
              })
            ];
          };
        };
      };

      systemd.services.authelia-main = {
        inherit onFailure;
        unitConfig = {
          StartLimitBurst = lib.mkForce 3;
          StartLimitIntervalSec = lib.mkForce 300;
        };
        serviceConfig =
          harden {}
          // serviceDefaults {}
          // {
            StateDirectory = lib.mkForce "authelia-main";
            StateDirectoryMode = lib.mkForce "0750";
            ExecStartPost = "${pkgs.curl}/bin/curl -sf --max-time 3 --retry 30 --retry-delay 1 --retry-all-errors http://127.0.0.1:${toString authPort}/api/health";
          };
      };

      environment.etc."authelia/users_database.yml".source = config.sops.templates.authelia-users-db.path;

      sops.templates."authelia-users-db" = {
        owner = "authelia-main";
        group = "authelia-main";
        content = ''
          users:
            lars:
              displayname: "Lars"
              password: "$argon2id$v=19$m=65536,t=3,p=4$SFxuhCS1FXCGDpMEyoLgJQ$geJt46OkKpzTfofZeHKNzU6vgr3WtjXzgaOAv9NAo/g"
              email: "lars@auth.home.lan"
              groups:
                - admin
                - dev
        '';
      };

      systemd.tmpfiles.rules = [
        (mkStateDir "/var/lib/authelia-main" "0750" "authelia-main" "authelia-main")
        "L+ /var/lib/authelia-main/users_database.yml - - - - /etc/authelia/users_database.yml"
      ];
    };
  };
}
