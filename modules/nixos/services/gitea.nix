_: {
  flake.nixosModules.gitea = {
    pkgs,
    lib,
    config,
    ...
  }: let
    inherit (config.users) primaryUser;
    giteaPkg = config.services.gitea.package;
    harden = import ../../../lib/systemd.nix {inherit lib;};
    serviceDefaults = (import ../../../lib/systemd/service-defaults.nix lib).serviceDefaults;

    # Script to mirror all user repos from GitHub
    mirrorGithubScript = pkgs.writeShellScriptBin "gitea-mirror-github" ''
      # Mirror all repos from GitHub to Gitea
      # Secrets managed via sops-nix (see platforms/nixos/services/sops.nix)
      set -euo pipefail

      REPOS_FILE=$(mktemp)
      trap 'rm -f "$REPOS_FILE"' EXIT

      GITEA_URL="http://localhost:3000"
      GITEA_TOKEN="''${GITEA_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-$(gh api user -q .login 2>/dev/null || echo "")}"

      if [[ -z "$GITEA_TOKEN" ]]; then
        echo "Error: GITEA_TOKEN not set"
        echo "Create a token at http://localhost:3000/user/settings/applications"
        exit 1
      fi

      if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "Error: GITHUB_TOKEN not set"
        echo "Create a token at https://github.com/settings/tokens (needs repo scope)"
        exit 1
      fi

      if [[ -z "$GITHUB_USER" ]]; then
        echo "Error: Could not detect GitHub username"
        echo "Set GITHUB_USER in ~/.config/gitea-sync.env"
        exit 1
      fi

      echo "Fetching repositories for GitHub user: $GITHUB_USER"

      # Handle pagination for users with many repos
      page=1
      repos=""
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
          -H "Authorization: token $GITEA_TOKEN" \
          "$GITEA_URL/api/v1/repos/$GITHUB_USER/$name")

        if [[ "$existing" == "200" ]]; then
          echo "✓ Already mirrored: $name"
          continue
        fi

        echo "→ Mirroring: $name"

        curl -s -X POST \
          -H "Authorization: token $GITEA_TOKEN" \
          -H "Content-Type: application/json" \
          "$GITEA_URL/api/v1/repos/migrate" \
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
            }')"
      done < "$REPOS_FILE"
      count=$(wc -l < "$REPOS_FILE")

      echo "✓ Done! $count repos processed"
    '';

    # Script to mirror all starred repos from GitHub
    mirrorStarredScript = pkgs.writeShellScriptBin "gitea-mirror-starred" ''
      # Mirror all starred repos from GitHub to Gitea
      set -euo pipefail

      STARRED_FILE=$(mktemp)
      trap 'rm -f "$STARRED_FILE"' EXIT

      GITEA_URL="http://localhost:3000"
      GITEA_TOKEN="''${GITEA_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-$(gh api user -q .login 2>/dev/null || echo "")}"
      GITEA_ORG="starred"

      if [[ -z "$GITEA_TOKEN" ]]; then
        echo "Error: GITEA_TOKEN not set"
        exit 1
      fi

      if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "Error: GITHUB_TOKEN not set"
        exit 1
      fi

      # Create org if it doesn't exist
      curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $GITEA_TOKEN" \
        "$GITEA_URL/api/v1/orgs/$GITEA_ORG" | grep -q "200" || {
        echo "Creating organization: $GITEA_ORG"
        curl -s -X POST \
          -H "Authorization: token $GITEA_TOKEN" \
          -H "Content-Type: application/json" \
          "$GITEA_URL/api/v1/orgs" \
          -d "{\"username\":\"$GITEA_ORG\",\"full_name\":\"Starred Repositories\"}"
      }

      echo "Fetching starred repositories..."

      # Handle pagination
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
          -H "Authorization: token $GITEA_TOKEN" \
          "$GITEA_URL/api/v1/repos/$GITEA_ORG/$name")

        if [[ "$existing" == "200" ]]; then
          echo "✓ Already mirrored: $name"
          continue
        fi

        echo "→ Mirroring: $full_name"

        curl -s -X POST \
          -H "Authorization: token $GITEA_TOKEN" \
          -H "Content-Type: application/json" \
          "$GITEA_URL/api/v1/repos/migrate" \
          -d "$(jq -n \
            --arg name "$name" \
            --arg clone_url "$clone_url" \
            --arg description "$description" \
            --arg org "$GITEA_ORG" \
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

    # Setup helper script
    setupScript = pkgs.writeShellScriptBin "gitea-setup" ''
      # Initial Gitea setup helper
      set -euo pipefail

      echo "=== Gitea Setup Helper ==="
      echo ""
      echo "1. Gitea is running at: http://localhost:3000"
      echo "2. Create your admin account in the web UI"
      echo ""
      echo "3. Create tokens:"
      echo "   - Gitea: http://localhost:3000/user/settings/applications"
      echo "   - GitHub: https://github.com/settings/tokens/new (select 'repo' scope)"
      echo ""
      echo "4. Create credentials file:"
      echo ""
      echo "   mkdir -p ~/.config"
      echo "   cat > ~/.config/gitea-sync.env << 'EOF'"
      echo "   GITEA_TOKEN=your-gitea-token"
      echo "   GITHUB_TOKEN=your-github-token"
      echo "   GITHUB_USER=your-github-username"
      echo "   EOF"
      echo ""
      echo "5. Run initial sync:"
      echo "   gitea-mirror-github      # Mirror your repos"
      echo "   gitea-mirror-starred     # Mirror starred repos"
      echo ""
      echo "After setup, mirrors sync automatically every 30 minutes."
      echo ""
      echo "Status:"
      systemctl is-active gitea && echo "✓ Gitea service: running" || echo "✗ Gitea service: stopped"
      systemctl is-active gitea-github-sync.timer && echo "✓ Sync timer: active" || echo "✗ Sync timer: inactive"
    '';
  in {
    config = lib.mkIf config.services.gitea.enable {
      services.gitea = {
        package = pkgs.gitea;

        # SQLite is fine for personal use (<50 repos)
        database.type = "sqlite3";

        # Enable Git LFS support
        lfs.enable = true;

        # Automatic weekly backups
        dump = {
          enable = true;
          interval = "weekly";
        };

        stateDir = "/var/lib/gitea";

        settings = {
          DEFAULT.APP_NAME = "Local Git Mirror";

          server = {
            HTTP_PORT = 3000;
            ROOT_URL = "https://gitea.${config.networking.domain}/";
            DOMAIN = "gitea.${config.networking.domain}";
          };

          repository = {
            DEFAULT_BRANCH = "main";
            ENABLE_PUSH_CREATE_USER = true;
            DEFAULT_PUSH_CREATE_PRIVATE = true;
          };

          # Mirror configuration
          mirror = {
            ENABLED = true;
            DEFAULT_INTERVAL = "8h";
            MIN_INTERVAL = "10m";
          };

          # Automatic mirror sync (runs every 30 min)
          "cron.update_mirrors" = {
            ENABLED = true;
            SCHEDULE = "@every 30m";
            RUN_AT_START = false;
            PULL_LIMIT = 50;
            PUSH_LIMIT = 50;
          };

          # UI preferences
          ui = {
            DEFAULT_THEME = "gitea-auto";
            THEMES = "gitea-auto,gitea-light,gitea-dark,arc-green";
          };

          # Security (single-user instance)
          service = {
            DISABLE_REGISTRATION = true;
            REQUIRE_SIGNIN_VIEW = false;
          };

          session = {
            COOKIE_SECURE = true; # Behind Caddy HTTPS reverse proxy
          };

          # Logging
          log = {
            LEVEL = "Info";
            ROOT_PATH = "/var/lib/gitea/log";
          };

          # Performance tuning
          "git.timeout" = {
            MIRROR = 600;
            CLONE = 600;
            PULL = 600;
          };

          # CI/CD via Gitea Actions
          actions = {
            ENABLED = true;
            DEFAULT_ACTIONS_URL = "github";
          };

          # Cleaner footer
          other = {
            SHOW_FOOTER_VERSION = false;
            SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
          };
        };
      };

      # Systemd configuration
      systemd = {
        # Harden the main Gitea service (managed by services.gitea)
        services.gitea = {
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
              WatchdogSec = lib.mkForce "30";
            };
          preStart = let
            adminSetup = pkgs.writeShellScript "gitea-admin-setup" ''
              set -euo pipefail

              ADMIN_USER="${primaryUser}"
              ADMIN_EMAIL="${primaryUser}@local"
              PASS_FILE="/var/lib/gitea/.admin-password"
              GITEA=${lib.getExe giteaPkg}

              # Generate password if not exists
              if [ ! -f "$PASS_FILE" ]; then
                ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > "$PASS_FILE"
                chmod 600 "$PASS_FILE"
              fi
              ADMIN_PASS="$(${pkgs.coreutils}/bin/head -n1 "$PASS_FILE" | ${pkgs.coreutils}/bin/tr -d '\n')"

              # Create admin user if not exists, sync password from file
              if ! $GITEA admin user list | grep -q "$ADMIN_USER"; then
                echo "Creating Gitea admin user: $ADMIN_USER"
                $GITEA admin user create \
                  --username "$ADMIN_USER" \
                  --password "$ADMIN_PASS" \
                  --email "$ADMIN_EMAIL" \
                  --admin \
                  --must-change-password=false
              else
                echo "Ensuring password matches for $ADMIN_USER"
                $GITEA admin user change-password \
                  --username "$ADMIN_USER" \
                  --password "$ADMIN_PASS" \
                  --must-change-password=false 2>/dev/null || true
              fi
            '';
          in "${adminSetup}";
        };

        # GitHub sync service
        services.gitea-github-sync = {
          description = "Sync all GitHub repos to Gitea";
          after = ["gitea.service" "gitea-generate-token.service" "network-online.target"];
          wants = ["network-online.target"];
          requires = ["gitea.service"];
          onFailure = ["notify-failure@%n.service"];
          path = [pkgs.curl pkgs.jq pkgs.gh];
          serviceConfig =
            {
              Type = "oneshot";
              User = primaryUser;
              EnvironmentFile = [
                config.sops.templates."gitea-sync.env".path
                "-/var/lib/gitea/.admin-token.env"
              ];
              ExecStart = "${mirrorGithubScript}/bin/gitea-mirror-github";
            }
            // harden {
              ProtectHome = false;
              ProtectSystem = false;
            };
        };

        # Schedule sync every 6 hours
        timers.gitea-github-sync = {
          description = "Sync GitHub repos to Gitea every 6 hours";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "6h";
            Unit = "gitea-github-sync.service";
            Persistent = true;
          };
        };
      };

      # Token generation (runs after Gitea is listening)
      systemd.services.gitea-generate-token = {
        description = "Generate Gitea API token";
        after = ["gitea.service"];
        wants = ["gitea.service"];
        wantedBy = ["gitea.service"];
        serviceConfig =
          {
            Type = "oneshot";
            User = "gitea";
            Group = "gitea";
            RemainAfterExit = true;
          }
          // harden {};
        script = let
          tokenGen = pkgs.writeShellScript "gitea-token-gen" ''
            set -euo pipefail

            ADMIN_USER="${primaryUser}"
            TOKEN_FILE="/var/lib/gitea/.admin-token.env"
            GITEA=${lib.getExe giteaPkg}
            export GITEA_WORK_DIR=/var/lib/gitea

            [ -f "$TOKEN_FILE" ] && exit 0

            # Wait for Gitea to be ready
            for i in $(seq 1 30); do
              if ${pkgs.curl}/bin/curl -s -o /dev/null -w "" "http://localhost:3000/"; then
                break
              fi
              sleep 1
            done

            TOKEN=""
            TOKEN_NAME="sync-$(date +%s)"

            # Generate new token via CLI (unique name avoids "already used" errors)
            TOKEN=$($GITEA admin user generate-access-token \
              --username "$ADMIN_USER" \
              --token-name "$TOKEN_NAME" \
              --scopes all \
              --raw 2>/dev/null) || TOKEN=""

            # Validate: token must be a 40-char hex string
            if ! echo "$TOKEN" | ${pkgs.gnugrep}/bin/grep -qE '^[0-9a-f]{40}$'; then
              echo "CLI token generation failed or returned invalid token, clearing"
              TOKEN=""
            fi

            if [ -n "$TOKEN" ]; then
              printf 'GITEA_TOKEN=%s\n' "$TOKEN" > "$TOKEN_FILE"
              chmod 600 "$TOKEN_FILE"
              echo "API token written to $TOKEN_FILE"
            else
              echo "WARNING: Failed to generate API token"
            fi
          '';
        in "${tokenGen}";
      };

      # Runner registration token generation
      systemd.services.gitea-runner-token = {
        description = "Generate Gitea Actions runner registration token";
        after = ["gitea.service"];
        wants = ["gitea.service"];
        wantedBy = ["gitea.service"];
        serviceConfig =
          {
            Type = "oneshot";
            User = "gitea";
            Group = "gitea";
            RemainAfterExit = true;
          }
          // harden {};
        script = let
          tokenGen = pkgs.writeShellScript "gitea-runner-token-gen" ''
            set -euo pipefail

            TOKEN_FILE="/var/lib/gitea/.runner-token"
            GITEA=${lib.getExe giteaPkg}
            export GITEA_WORK_DIR=/var/lib/gitea

            [ -f "$TOKEN_FILE" ] && exit 0

            for i in $(seq 1 30); do
              if ${pkgs.curl}/bin/curl -s -o /dev/null "http://localhost:3000/"; then
                break
              fi
              sleep 1
            done

            TOKEN=$($GITEA actions generate-runner-token 2>/dev/null) || TOKEN=""

            if [ -n "$TOKEN" ]; then
              printf 'TOKEN=%s\n' "$TOKEN" > "$TOKEN_FILE"
              chmod 600 "$TOKEN_FILE"
              echo "Runner registration token written to $TOKEN_FILE"
            else
              echo "WARNING: Failed to generate runner registration token"
            fi
          '';
        in "${tokenGen}";
      };

      # Gitea Actions Runner
      services.gitea-actions-runner = {
        package = pkgs.gitea-actions-runner;
        instances.${config.networking.hostName} = {
          enable = true;
          name = config.networking.hostName;
          url = "http://localhost:3000";
          tokenFile = "/var/lib/gitea/.runner-token";
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

      # Ensure runner starts after token generation
      systemd.services."gitea-runner-${config.networking.hostName}" = {
        after = ["gitea-runner-token.service"];
        requires = ["gitea-runner-token.service"];
      };

      # CLI tools
      environment.systemPackages = [
        mirrorGithubScript
        mirrorStarredScript
        setupScript
      ];
    };
  };
}
