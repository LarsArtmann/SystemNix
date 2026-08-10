# Forgejo self-hosted Git forge: GitHub sync, Actions runner, admin setup
_: {
  flake.nixosModules.forgejo = {
    pkgs,
    lib,
    config,
    utils,
    ...
  }: let
    inherit (config.users) primaryUser;
    cfg = config.services.forgejo;
    forgejoPkg = cfg.package;
    inherit
      (import ../../../lib/default.nix lib)
      harden
      serviceDefaults
      serviceOneshotDefaults
      onFailure
      ports
      ioTier
      ;
    forgejoPort = config.services.forgejo.settings.server.HTTP_PORT;
    forgejoUrl = "http://localhost:${toString forgejoPort}";
    stateDir = config.services.forgejo.stateDir;
    hostName = config.networking.hostName;
    runnerLabels = [
      "ubuntu-latest:docker://node:22-bookworm"
      "ubuntu-22.04:docker://node:22-bookworm"
      "native:host"
    ];
    runnerSettings = {
      log.level = "info";
      runner.capacity = 2;
      container.network = "host";
    };
    runnerConfigFile = (pkgs.formats.yaml {}).generate "runner-config.yaml" runnerSettings;

    inherit
      (import ./_forgejo-scripts.nix {
        inherit
          pkgs
          lib
          config
          primaryUser
          cfg
          forgejoPkg
          forgejoUrl
          stateDir
          hostName
          runnerLabels
          runnerConfigFile
          ;
      })
      mirrorGithubScript
      mirrorStarredScript
      setupScript
      ensurePasswordFile
      adminSetup
      tokenGen
      genRunnerToken
      registerRunner
      oidcSetupScript
      addKeysScript
      ;

    # DNS gate for OIDC setup — dnsblockd may not be ready immediately
    # after deploy restart. The OIDC setup resolves auth.home.lan to
    # fetch the OpenID configuration from Pocket ID.
    forgejoOidcWaitDns = pkgs.writeShellApplication {
      name = "forgejo-oidc-wait-dns";
      runtimeInputs = [pkgs.getent];
      text = ''
        echo "forgejo-oidc: waiting for DNS resolution..."
        for _ in $(seq 1 30); do
          if getent hosts auth.home.lan >/dev/null 2>&1; then
            echo "forgejo-oidc: DNS resolution ready"
            exit 0
          fi
          sleep 2
        done
        echo "forgejo-oidc: DNS not ready after 60s — OIDC setup may fail" >&2
        exit 1
      '';
    };
  in {
    options = {
      services.forgejo.sshKeys = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = {};
        description = ''
          Declarative SSH public keys for Forgejo users. Keys are idempotent:
          existing keys are matched by their raw string and left unchanged.
          Defaults to the primary user's NixOS authorized keys.
        '';
      };
    };

    config = lib.mkIf config.services.forgejo.enable {
      services.forgejo = {
        sshKeys = lib.mkDefault {
          ${primaryUser} = config.users.users.${primaryUser}.openssh.authorizedKeys.keys;
        };

        package = pkgs.forgejo-lts;

        database.type = "sqlite3";

        lfs.enable = true;

        dump = {
          enable = true;
          interval = "weekly";
        };

        stateDir = "/var/lib/forgejo";

        settings = {
          DEFAULT.APP_NAME = "Local Git Forge";

          server = {
            HTTP_PORT = ports.forgejo;
            ROOT_URL = "https://forgejo.${config.networking.domain}/";
            DOMAIN = "forgejo.${config.networking.domain}";
          };

          repository = {
            DEFAULT_BRANCH = "main";
            ENABLE_PUSH_CREATE_USER = true;
            DEFAULT_PUSH_CREATE_PRIVATE = true;
          };

          mirror = {
            ENABLED = true;
            DEFAULT_INTERVAL = "8h";
            MIN_INTERVAL = "10m";
          };

          "cron.update_mirrors" = {
            ENABLED = true;
            SCHEDULE = "@every 30m";
            RUN_AT_START = false;
            PULL_LIMIT = 50;
            PUSH_LIMIT = 50;
          };

          ui = {
            DEFAULT_THEME = "forgejo-auto";
            THEMES = "forgejo-auto,forgejo-light,forgejo-dark,arc-green";
          };

          service = {
            DISABLE_REGISTRATION = true;
            REQUIRE_SIGNIN_VIEW = false;
            # SSO-only: hide password form, block password auth entirely.
            # Git HTTPS still works via access tokens (not affected).
            ENABLE_INTERNAL_SIGNIN = false;
            ENABLE_BASIC_AUTHENTICATION = false;
          };

          oauth2_client = {
            ENABLE_AUTO_REGISTRATION = true;
            USERNAME = "email";
            UPDATE_AVATAR = true;
            ACCOUNT_LINKING = "auto";
          };

          session = {
            COOKIE_SECURE = true;
          };

          log = {
            LEVEL = "Info";
            ROOT_PATH = "${stateDir}/log";
          };

          "git.timeout" = {
            MIRROR = 600;
            CLONE = 600;
            PULL = 600;
          };

          actions = {
            ENABLED = true;
            DEFAULT_ACTIONS_URL = "github";
          };

          other = {
            SHOW_FOOTER_VERSION = false;
            SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
          };

          federation = {
            ENABLED = true;
          };
        };
      };

      systemd = {
        services.forgejo = {
          unitConfig = {
            StartLimitBurst = lib.mkForce 3;
            StartLimitIntervalSec = lib.mkForce 300;
          };
          serviceConfig = lib.mkMerge [
            (harden {
              ProtectHome = lib.mkForce false;
              NoNewPrivileges = false;
            })
            (serviceDefaults {})
            {
              ExecStartPre = lib.mkBefore [("+" + lib.getExe ensurePasswordFile)];
              TimeoutStartSec = "3min";
            }
          ];
          preStart = lib.getExe adminSetup;
        };

        services.forgejo-github-sync = {
          description = "Sync all GitHub repos to Forgejo";
          after = [
            "forgejo.service"
            "forgejo-generate-token.service"
            "network-online.target"
          ];
          wants = ["network-online.target"];
          requires = ["forgejo.service"];
          inherit onFailure;
          restartTriggers = [(lib.getExe mirrorGithubScript)];
          path = [
            pkgs.curl
            pkgs.jq
            pkgs.gh
          ];
          serviceConfig = lib.mkMerge [
            {
              Type = "oneshot";
              User = primaryUser;
              EnvironmentFile = [
                config.sops.templates."forgejo-sync.env".path
                "-${stateDir}/.admin-token.env"
              ];
              ExecStart = lib.getExe mirrorGithubScript;
            }
            (harden {
              ProtectHome = false;
              ProtectSystem = false;
            })
          ];
        };

        timers.forgejo-github-sync = {
          description = "Sync GitHub repos to Forgejo every 6 hours";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "6h";
            Unit = "forgejo-github-sync.service";
            Persistent = true;
          };
        };
      };

      systemd.services.forgejo-generate-token = {
        description = "Generate Forgejo API token";
        after = ["forgejo.service"];
        wants = ["forgejo.service"];
        wantedBy = ["forgejo.service"];
        restartTriggers = [(lib.getExe tokenGen)];
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            User = "forgejo";
            Group = "forgejo";
            RemainAfterExit = true;
          }
          (harden {})
        ];
        script = lib.getExe tokenGen;
      };

      systemd.services.forgejo-oidc-setup = lib.mkIf config.services.pocket-id-config.enable {
        description = "Configure Forgejo OIDC authentication source (Pocket ID)";
        after = [
          "forgejo.service"
          "pocket-id-provision.service"
          "dnsblockd.service"
        ];
        wants = [
          "forgejo.service"
          "pocket-id-provision.service"
          "dnsblockd.service"
        ];
        wantedBy = ["forgejo.service"];
        restartTriggers = [(lib.getExe oidcSetupScript)];
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            User = "forgejo";
            Group = "forgejo";
            RemainAfterExit = true;
            LoadCredential = [
              "forgejo-oidc-client-secret:${config.services.pocket-id.dataDir}/client-secrets/forgejo"
            ];
            ExecStartPre = "+${lib.getExe forgejoOidcWaitDns}";
            TimeoutStartSec = "3min";
          }
          (harden {})
          (serviceOneshotDefaults {})
        ];
        script = lib.getExe oidcSetupScript;
      };

      systemd.services.forgejo-ssh-keys = {
        description = "Add declarative SSH keys to Forgejo users";
        after = [
          "forgejo.service"
          "forgejo-generate-token.service"
        ];
        wants = ["forgejo-generate-token.service"];
        wantedBy = ["forgejo.service"];
        startLimitBurst = 5;
        startLimitIntervalSec = 300;
        inherit onFailure;
        restartTriggers = [(lib.getExe addKeysScript)];
        serviceConfig = lib.mkMerge [
          {
            Type = "oneshot";
            User = "forgejo";
            Group = "forgejo";
            RemainAfterExit = true;
          }
          (harden {})
          (serviceOneshotDefaults {})
        ];
        script = lib.getExe addKeysScript;
      };

      services.gitea-actions-runner = {
        package = pkgs.forgejo-runner;
        instances.${hostName} = {
          enable = true;
          name = hostName;
          url = "${forgejoUrl}";
          tokenFile = "/run/forgejo-runner/token";
          labels = runnerLabels;
          settings = runnerSettings;
        };
      };

      systemd.services."gitea-runner-${utils.escapeSystemdPath hostName}" = {
        after = ["forgejo.service"];
        wants = ["forgejo.service"];
        startLimitBurst = 5;
        startLimitIntervalSec = 300;
        serviceConfig = lib.mkMerge [
          {
            EnvironmentFile = lib.mkForce "-/run/forgejo-runner/token";
            ExecStartPre = lib.mkForce [
              ("+" + lib.getExe genRunnerToken)
              (lib.getExe registerRunner)
            ];
            TimeoutStartSec = "3min";
            MemoryMax = "16G";
          }
          ioTier.build
        ];
      };

      # Fix ownership after Gitea→Forgejo data migration (recursively)
      systemd.tmpfiles.rules = [
        "Z ${stateDir} 0750 forgejo forgejo - -"
      ];

      environment.systemPackages = [
        mirrorGithubScript
        mirrorStarredScript
        setupScript
      ];
    };
  };
}
