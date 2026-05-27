# Declarative Forgejo repository mirroring from GitHub with auto-sync
_: {
  flake.nixosModules.forgejo-repos = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.services.forgejo-repos;
    inherit (config.users) primaryUser;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure;
    forgejoPort = config.services.forgejo.settings.server.HTTP_PORT;
    forgejoUrl = "http://localhost:${toString forgejoPort}";

    ensureReposScript = pkgs.writeShellApplication {
      name = "forgejo-ensure-repos";
      runtimeInputs = [pkgs.curl pkgs.jq pkgs.gh];
      text = ''
        FORGEJO_URL="${forgejoUrl}"
        REPOS=(${lib.concatStringsSep " " (map (r: "\"${r}\"") cfg.repos)})

        FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
        GITHUB_TOKEN="''${GITHUB_TOKEN:-$(gh auth token)}"
        GITHUB_USER="''${GITHUB_USER:-}"

        if [[ -z "$FORGEJO_TOKEN" ]]; then
          echo "Error: FORGEJO_TOKEN not set in sops secrets"
          exit 1
        fi

        if [[ -z "$GITHUB_TOKEN" ]]; then
          echo "Error: Could not get GitHub token from gh CLI"
          echo "Run: gh auth login"
          exit 1
        fi

        if [[ -z "$GITHUB_USER" ]]; then
          echo "Error: GITHUB_USER not set in sops secrets"
          exit 1
        fi

        echo "=== Ensuring repos exist in Forgejo ==="
        echo "GitHub user: $GITHUB_USER"
        echo "Repos to check: ''${#REPOS[@]}"
        echo ""

        for repo_url in "''${REPOS[@]}"; do
          repo_name=$(basename "$repo_url" .git)
          echo "Processing: $repo_name"

          existing=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $FORGEJO_TOKEN" \
            "$FORGEJO_URL/api/v1/repos/$GITHUB_USER/$repo_name" 2>/dev/null || echo "000")

          if [[ "$existing" == "200" ]]; then
            echo "  ✓ Already mirrored: $repo_name"
            continue
          fi

          echo "  → Fetching info from GitHub..."
          repo_info=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/$GITHUB_USER/$repo_name")

          if echo "$repo_info" | jq -e '.message == "Not Found"' &>/dev/null; then
            echo "  ✗ Repo not found on GitHub: $repo_name"
            continue
          fi

          description=$(echo "$repo_info" | jq -r '.description // ""')
          private=$(echo "$repo_info" | jq -r '.private')
          clone_url=$(echo "$repo_info" | jq -r '.clone_url')

          echo "  → Creating mirror in Forgejo..."
          result=$(curl -s -X POST \
            -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Content-Type: application/json" \
            "$FORGEJO_URL/api/v1/repos/migrate" \
            -d "$(jq -n \
              --arg name "$repo_name" \
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
              }')" 2>/dev/null)

          if echo "$result" | jq -e '.name' &>/dev/null; then
            echo "  ✓ Created mirror: $repo_name"

            echo "  → Setting up push mirror to GitHub: $repo_name"
            curl -s -X POST \
              -H "Authorization: token $FORGEJO_TOKEN" \
              -H "Content-Type: application/json" \
              "$FORGEJO_URL/api/v1/repos/$GITHUB_USER/$repo_name/push_mirrors" \
              -d "$(jq -n \
                --arg remote "https://$GITHUB_USER:''${GITHUB_TOKEN}@github.com/$GITHUB_USER/$repo_name.git" \
                '{
                  remote_address: $remote,
                  sync_on_commit: true
                }')" 2>/dev/null || echo "  ⚠ Push mirror setup failed (may already exist)"
          else
            error_msg=$(echo "$result" | jq -r '.message // "Unknown error"')
            echo "  ✗ Failed: $error_msg"
          fi
        done

        echo ""
        echo "=== Done ==="
      '';
    };

    updateGithubTokenScript = pkgs.writeShellApplication {
      name = "forgejo-update-github-token";
      runtimeInputs = [pkgs.sops pkgs.gh pkgs.gnugrep pkgs.coreutils];
      text = ''
        AGE_KEY_FILE="/run/secrets.d/age-keys.txt"

        if ! sudo test -r "$AGE_KEY_FILE"; then
          echo "Error: Cannot read $AGE_KEY_FILE (need sudo)"
          exit 1
        fi

        sops_wrapper() {
          sudo env SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops "$@"
        }

        find_repo() {
          if [[ -n "''${FLAKE_ROOT:-}" ]] && [[ -d "$FLAKE_ROOT/platforms/nixos/secrets" ]]; then
            echo "$FLAKE_ROOT"
            return 0
          fi

          for dir in "$HOME/projects/SystemNix" "$HOME/SystemNix" "$HOME/Setup-Mac"; do
            if [[ -d "$dir/platforms/nixos/secrets" ]]; then
              echo "$dir"
              return 0
            fi
          done

          local curr="$PWD"
          while [[ "$curr" != "/" ]]; do
            if [[ -d "$curr/platforms/nixos/secrets" ]]; then
              echo "$curr"
              return 0
            fi
            curr="$(dirname "$curr")"
          done

          return 1
        }

        REPO_ROOT=$(find_repo) || {
          echo "Error: Could not find SystemNix repo"
          echo "Make sure you're in the repo directory or set FLAKE_ROOT"
          exit 1
        }

        SECRETS_FILE="$REPO_ROOT/platforms/nixos/secrets/secrets.yaml"

        echo "=== Update GitHub Token ==="
        echo "Repo: $REPO_ROOT"
        echo ""

        if ! command -v gh &> /dev/null; then
          echo "Error: gh CLI not found"
          exit 1
        fi

        GITHUB_TOKEN=$(gh auth token)

        if [[ -z "$GITHUB_TOKEN" ]]; then
          echo "Error: Could not get token from gh"
          echo "Run: gh auth login"
          exit 1
        fi

        echo "Got fresh token: ''${GITHUB_TOKEN:0:10}..."

        GITHUB_USER=$(gh api user -q .login 2>/dev/null || echo "")
        if [[ -z "$GITHUB_USER" ]]; then
          echo "Error: Could not get GitHub username"
          exit 1
        fi
        echo "GitHub user: $GITHUB_USER"
        echo ""

        echo "Updating sops secrets..."
        cd "$(dirname "$SECRETS_FILE")"

        sops_wrapper set "$SECRETS_FILE" '["github_token"]' "\"$GITHUB_TOKEN\""

        CURRENT_USER=$(sops_wrapper -d --extract '["github_user"]' "$SECRETS_FILE" 2>/dev/null || echo "")
        if [[ "$CURRENT_USER" != "$GITHUB_USER" ]]; then
          echo "Updating github_user: $CURRENT_USER → $GITHUB_USER"
          sops_wrapper set "$SECRETS_FILE" '["github_user"]' "\"$GITHUB_USER\""
        fi

        echo ""
        echo "✅ Token updated in sops!"
        echo ""
        echo "Next steps:"
        echo "  cd $REPO_ROOT && sudo nixos-rebuild switch --flake .#evo-x2"
      '';
    };

    waitForForgejo = pkgs.writeShellApplication {
      name = "wait-for-forgejo";
      runtimeInputs = [pkgs.curl];
      text = ''
        echo "Waiting for Forgejo to be ready..."
        for i in {1..30}; do
          if curl -s ${forgejoUrl}/api/v1/version &>/dev/null; then
            echo "Forgejo is ready!"
            exit 0
          fi
          echo "Forgejo not ready yet, attempt $i/30..."
          sleep 2
        done
        echo "Forgejo failed to become ready after 60 seconds"
        exit 1
      '';
    };
  in {
    options.services.forgejo-repos = {
      enable = lib.mkEnableOption "Declarative Forgejo repository mirroring";

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User account for running sync services (needs gh CLI access)";
      };

      repos = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of GitHub SSH URLs to mirror to Forgejo";
        example = ["git@github.com:user/repo.git"];
      };

      autoSync = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to automatically sync repos on rebuild";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [
        ensureReposScript
        updateGithubTokenScript
        pkgs.gh
        pkgs.sops
        pkgs.age
      ];

      systemd = lib.mkIf cfg.autoSync {
        services.forgejo-ensure-repos = {
          description = "Ensure GitHub repos are mirrored to Forgejo";
          after = ["forgejo.service" "forgejo-generate-token.service" "network-online.target"];
          wants = ["network-online.target"];
          requires = ["forgejo.service"];
          inherit onFailure;
          startLimitIntervalSec = 300;
          startLimitBurst = 3;
          path = [pkgs.curl pkgs.jq pkgs.gh pkgs.sops pkgs.bash];
          serviceConfig =
            {
              Type = "oneshot";
              User = cfg.user;
              EnvironmentFile = config.sops.templates."forgejo-sync.env".path;
              ExecStartPre = lib.getExe waitForForgejo;
              ExecStart = "${ensureReposScript}/bin/forgejo-ensure-repos";
            }
            // serviceDefaults {Restart = "on-failure";}
            // harden {
              ProtectSystem = "strict";
              MemoryMax = "512M";
            };
        };

        tmpfiles.rules = [
          "L /run/forgejo-repos-trigger - - - - ${ensureReposScript}/bin/forgejo-ensure-repos"
        ];

        timers.forgejo-ensure-repos = {
          description = "Ensure GitHub repos are mirrored to Forgejo (daily)";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
    };
  };
}
