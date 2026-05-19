# Forgejo self-hosted Git forge: GitHub sync, Actions runner, admin setup
_: {
  flake.nixosModules.forgejo = {
    pkgs,
    lib,
    config,
    ...
  }: let
    inherit (config.users) primaryUser;
    forgejoPkg = config.services.forgejo.package;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure;
    forgejoPort = config.services.forgejo.settings.server.HTTP_PORT;
    forgejoUrl = "http://localhost:${toString forgejoPort}";
    stateDir = config.services.forgejo.stateDir;

    mirrorGithubScript = pkgs.writeShellScriptBin "forgejo-mirror-github" ''
      # Mirror all repos from GitHub to Forgejo
      # Secrets managed via sops-nix (see modules/nixos/services/sops.nix)
      set -euo pipefail

      REPOS_FILE=$(mktemp)
      trap 'rm -f "$REPOS_FILE"' EXIT

      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-$(gh api user -q .login 2>/dev/null || echo "")}"

      if [[ -z "$FORGEJO_TOKEN" ]]; then
        echo "Error: FORGEJO_TOKEN not set"
        echo "Create a token at ${forgejoUrl}/user/settings/applications"
        exit 1
      fi

      if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "Error: GITHUB_TOKEN not set"
        echo "Create a token at https://github.com/settings/tokens (needs repo scope)"
        exit 1
      fi

      if [[ -z "$GITHUB_USER" ]]; then
        echo "Error: Could not detect GitHub username"
        echo "Set GITHUB_USER in sops secrets"
        exit 1
      fi

      echo "Fetching repositories for GitHub user: $GITHUB_USER"

      page=1
      while true; do
        response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/users/$GITHUB_USER/repos?per_page=100&page=$page&type=all")
        echo "$response" | jq -r '.[] | "\(.name)|\(.clone_url)|\(.private)|\(.description // "")"' >> "$REPOS_FILE"
        [[ $(echo "$response" | jq 'length') -lt 100 ]] && break
        page=$((page + 1))
      done

      while IFS='|' read -r name clone_url private description; do
        [[ -z "$name" ]] && continue

        existing=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/repos/$GITHUB_USER/$name")

        if [[ "$existing" == "200" ]]; then
          echo "✓ Already mirrored: $name"
          continue
        fi

        echo "→ Mirroring: $name"

        curl -s -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H "Content-Type: application/json" \
          "$FORGEJO_URL/api/v1/repos/migrate" \
          -d "$(jq -n \
            --arg name "$name" \
            --arg clone_url "$clone_url" \
            --argjson private "$private" \
            --arg description "$description" \
            --arg uid "1" \
            '{
              clone_addr: $clone_url,
              repo_name: $name,
              uid: ($uid | tonumber),
              private: $private,
              description: $description,
              mirror: true,
              wiki: true,
              labels: true,
              issues: true,
              pull_requests: true,
              releases: true,
              milestones: true,
              service: "git"
            }')" 2>/dev/null && {
          echo "  ✓ Created mirror: $name"

          echo "  → Setting up push mirror to GitHub: $name"
          curl -s -X POST \
            -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Content-Type: application/json" \
            "$FORGEJO_URL/api/v1/repos/$GITHUB_USER/$name/push_mirrors" \
            -d "$(jq -n \
              --arg remote "https://$GITHUB_USER:''${GITHUB_TOKEN}@github.com/$GITHUB_USER/$name.git" \
              '{
                remote_address: $remote,
                sync_on_commit: true
              }')" 2>/dev/null || echo "  ⚠ Push mirror setup failed (may already exist)"
        } || echo "  ✗ Failed: $name"
      done < "$REPOS_FILE"
      count=$(wc -l < "$REPOS_FILE")

      echo "✓ Done! $count repos processed"
    '';

    mirrorStarredScript = pkgs.writeShellScriptBin "forgejo-mirror-starred" ''
      # Mirror all starred repos from GitHub to Forgejo
      set -euo pipefail

      STARRED_FILE=$(mktemp)
      trap 'rm -f "$STARRED_FILE"' EXIT

      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-$(gh api user -q .login 2>/dev/null || echo "")}"
      FORGEJO_ORG="starred"

      if [[ -z "$FORGEJO_TOKEN" ]]; then
        echo "Error: FORGEJO_TOKEN not set"
        exit 1
      fi

      if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "Error: GITHUB_TOKEN not set"
        exit 1
      fi

      curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $FORGEJO_TOKEN" \
        "$FORGEJO_URL/api/v1/orgs/$FORGEJO_ORG" | grep -q "200" || {
        echo "Creating organization: $FORGEJO_ORG"
        curl -s -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H "Content-Type: application/json" \
          "$FORGEJO_URL/api/v1/orgs" \
          -d "{\"username\":\"$FORGEJO_ORG\",\"full_name\":\"Starred Repositories\"}"
      }

      echo "Fetching starred repositories..."

      page=1
      while true; do
        response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/users/$GITHUB_USER/starred?per_page=100&page=$page")
        echo "$response" | jq -r '.[] | "\(.full_name)|\(.clone_url)|\(.description // "")"' >> "$STARRED_FILE"
        [[ $(echo "$response" | jq 'length') -lt 100 ]] && break
        page=$((page + 1))
      done

      while IFS='|' read -r full_name clone_url description; do
        [[ -z "$full_name" ]] && continue
        name=$(echo "$full_name" | tr '/' '-')

        existing=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/repos/$FORGEJO_ORG/$name")

        if [[ "$existing" == "200" ]]; then
          echo "✓ Already mirrored: $name"
          continue
        fi

        echo "→ Mirroring: $full_name"

        curl -s -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H "Content-Type: application/json" \
          "$FORGEJO_URL/api/v1/repos/migrate" \
          -d "$(jq -n \
            --arg name "$name" \
            --arg clone_url "$clone_url" \
            --arg description "$description" \
            --arg org "$FORGEJO_ORG" \
            '{
              clone_addr: $clone_url,
              repo_name: $name,
              org: $org,
              private: false,
              description: $description,
              mirror: true,
              wiki: true,
              labels: true,
              issues: true,
              pull_requests: true,
              releases: true,
              milestones: true,
              service: "git"
            }')"
      done < "$STARRED_FILE"

      echo "✓ Done!"
    '';

    setupScript = pkgs.writeShellScriptBin "forgejo-setup" ''
      # Initial Forgejo setup helper
      set -euo pipefail

      echo "=== Forgejo Setup Helper ==="
      echo ""
      echo "1. Forgejo is running at: ${forgejoUrl}"
      echo "2. Create your admin account in the web UI"
      echo ""
      echo "3. Create tokens:"
      echo "   - Forgejo: ${forgejoUrl}/user/settings/applications"
      echo "   - GitHub: https://github.com/settings/tokens/new (select 'repo' scope)"
      echo ""
      echo "4. Run initial sync:"
      echo "   forgejo-mirror-github      # Mirror your repos"
      echo "   forgejo-mirror-starred     # Mirror starred repos"
      echo ""
      echo "After setup, mirrors sync automatically every 30 minutes."
      echo ""
      echo "Status:"
      systemctl is-active forgejo && echo "✓ Forgejo service: running" || echo "✗ Forgejo service: stopped"
      systemctl is-active forgejo-github-sync.timer && echo "✓ Sync timer: active" || echo "✗ Sync timer: inactive"
    '';
  in {
    config = lib.mkIf config.services.forgejo.enable {
      services.forgejo = {
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
            HTTP_PORT = 3000;
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
          serviceConfig =
            harden {
              ProtectHome = lib.mkForce false;
              NoNewPrivileges = false;
            }
            // serviceDefaults {}
            // {
              ExecStartPre = let
                ensurePasswordFile = pkgs.writeShellScript "forgejo-ensure-password-file" ''
                  PASS_FILE="${stateDir}/.admin-password"
                  if [ ! -f "$PASS_FILE" ]; then
                    ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > "$PASS_FILE"
                  fi
                  chown forgejo:forgejo "$PASS_FILE"
                  chmod 600 "$PASS_FILE"
                '';
              in
                lib.mkBefore [("+" + ensurePasswordFile)];
            };
          preStart = let
            adminSetup = pkgs.writeShellScript "forgejo-admin-setup" ''
              set -euo pipefail

              ADMIN_USER="${primaryUser}"
              ADMIN_EMAIL="${primaryUser}@local"
              PASS_FILE="${stateDir}/.admin-password"
              FORGEJO=${lib.getExe forgejoPkg}

              if [ ! -f "$PASS_FILE" ]; then
                ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > "$PASS_FILE"
                chmod 600 "$PASS_FILE"
              fi
              ADMIN_PASS="$(${pkgs.coreutils}/bin/head -n1 "$PASS_FILE" | ${pkgs.coreutils}/bin/tr -d '\n')"

              if ! $FORGEJO admin user list | grep -q "$ADMIN_USER"; then
                echo "Creating Forgejo admin user: $ADMIN_USER"
                $FORGEJO admin user create \
                  --username "$ADMIN_USER" \
                  --password "$ADMIN_PASS" \
                  --email "$ADMIN_EMAIL" \
                  --admin \
                  --must-change-password=false
              else
                echo "Ensuring password matches for $ADMIN_USER"
                $FORGEJO admin user change-password \
                  --username "$ADMIN_USER" \
                  --password "$ADMIN_PASS" \
                  --must-change-password=false 2>/dev/null || true
              fi
            '';
          in "${adminSetup}";
        };

        services.forgejo-github-sync = {
          description = "Sync all GitHub repos to Forgejo";
          after = ["forgejo.service" "forgejo-generate-token.service" "network-online.target"];
          wants = ["network-online.target"];
          requires = ["forgejo.service"];
          inherit onFailure;
          path = [pkgs.curl pkgs.jq pkgs.gh];
          serviceConfig =
            {
              Type = "oneshot";
              User = primaryUser;
              EnvironmentFile = [
                config.sops.templates."forgejo-sync.env".path
                "-${stateDir}/.admin-token.env"
              ];
              ExecStart = "${mirrorGithubScript}/bin/forgejo-mirror-github";
            }
            // harden {
              ProtectHome = false;
              ProtectSystem = false;
            };
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
        serviceConfig =
          {
            Type = "oneshot";
            User = "forgejo";
            Group = "forgejo";
            RemainAfterExit = true;
          }
          // harden {};
        script = let
          tokenGen = pkgs.writeShellScript "forgejo-token-gen" ''
            set -euo pipefail

            ADMIN_USER="${primaryUser}"
            TOKEN_FILE="${stateDir}/.admin-token.env"
            FORGEJO=${lib.getExe forgejoPkg}
            export FORGEJO_WORK_DIR=${stateDir}

            [ -f "$TOKEN_FILE" ] && exit 0

            for i in $(seq 1 30); do
              if ${pkgs.curl}/bin/curl -s -o /dev/null -w "" "${forgejoUrl}/"; then
                break
              fi
              sleep 1
            done

            TOKEN=""
            TOKEN_NAME="sync-$(date +%s)"

            TOKEN=$($FORGEJO admin user generate-access-token \
              --username "$ADMIN_USER" \
              --token-name "$TOKEN_NAME" \
              --scopes all \
              --raw 2>/dev/null) || TOKEN=""

            if ! echo "$TOKEN" | ${pkgs.gnugrep}/bin/grep -qE '^[0-9a-f]{40}$'; then
              echo "CLI token generation failed or returned invalid token, clearing"
              TOKEN=""
            fi

            if [ -n "$TOKEN" ]; then
              printf 'FORGEJO_TOKEN=%s\n' "$TOKEN" > "$TOKEN_FILE"
              chmod 600 "$TOKEN_FILE"
              echo "API token written to $TOKEN_FILE"
            else
              echo "WARNING: Failed to generate API token"
            fi
          '';
        in "${tokenGen}";
      };

      systemd.services.forgejo-runner-token = {
        description = "Generate Forgejo Actions runner registration token";
        after = ["forgejo.service"];
        wants = ["forgejo.service"];
        wantedBy = ["forgejo.service"];
        serviceConfig =
          {
            Type = "oneshot";
            User = "forgejo";
            Group = "forgejo";
            RemainAfterExit = true;
          }
          // harden {};
        script = let
          tokenGen = pkgs.writeShellScript "forgejo-runner-token-gen" ''
            set -euo pipefail

            TOKEN_FILE="/run/forgejo-runner-token"
            FORGEJO=${lib.getExe forgejoPkg}
            export FORGEJO_WORK_DIR=${stateDir}

            for i in $(seq 1 30); do
              if ${pkgs.curl}/bin/curl -s -o /dev/null "${forgejoUrl}/"; then
                break
              fi
              sleep 1
            done

            TOKEN=$($FORGEJO actions generate-runner-token 2>/dev/null) || TOKEN=""

            if [ -n "$TOKEN" ]; then
              printf 'TOKEN=%s\n' "$TOKEN" > "$TOKEN_FILE"
              chmod 644 "$TOKEN_FILE"
              echo "Runner registration token written to $TOKEN_FILE"
            else
              echo "WARNING: Failed to generate runner registration token"
            fi
          '';
        in "${tokenGen}";
      };

      services.gitea-actions-runner = {
        package = pkgs.forgejo-runner;
        instances.${config.networking.hostName} = {
          enable = true;
          name = config.networking.hostName;
          url = "${forgejoUrl}";
          tokenFile = "/run/forgejo-runner-token";
          labels = [
            "ubuntu-latest:docker://node:22-bookworm"
            "ubuntu-22.04:docker://node:22-bookworm"
            "native:host"
          ];
          settings = {
            log.level = "info";
            runner.capacity = 2;
            container = {
              network = "host";
            };
          };
        };
      };

      # The nixpkgs gitea-actions-runner module names services "gitea-runner-*".
      # Can't rename externally — just wire ordering.
      systemd.services."gitea-runner-${config.networking.hostName}" = {
        after = ["forgejo-runner-token.service"];
        requires = ["forgejo-runner-token.service"];
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
