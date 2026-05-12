# Declarative Gitea repository mirroring from GitHub with auto-sync
_: {
  flake.nixosModules.gitea-repos = {
    pkgs,
    lib,
    config,
    ...
  }: let
    cfg = config.services.gitea-repos;
    inherit (config.users) primaryUser;
    inherit (import ../../../lib/default.nix lib) harden serviceDefaults;
    giteaPort = config.services.gitea.settings.server.HTTP_PORT;
    giteaUrl = "http://localhost:${toString giteaPort}";

    # Script to ensure specific GitHub repos are mirrored to Gitea
    ensureReposScript = pkgs.writeShellScriptBin "gitea-ensure-repos" ''
      # Ensure specific GitHub repos are mirrored to Gitea
      # Gets GitHub token fresh from gh CLI each run
      set -euo pipefail

      GITEA_URL="${giteaUrl}"
      REPOS=(${lib.concatStringsSep " " (map (r: "\"${r}\"") cfg.repos)})

      # Get tokens from environment (provided via sops template EnvironmentFile)
      GITEA_TOKEN="''${GITEA_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-$(gh auth token)}"
      GITHUB_USER="''${GITHUB_USER:-}"

      if [[ -z "$GITEA_TOKEN" ]]; then
        echo "Error: GITEA_TOKEN not set in sops secrets"
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

      echo "=== Ensuring repos exist in Gitea ==="
      echo "GitHub user: $GITHUB_USER"
      echo "Repos to check: ''${#REPOS[@]}"
      echo ""

      for repo_url in "''${REPOS[@]}"; do
        # Extract repo name from SSH URL (git@github.com:user/repo.git)
        repo_name=$(basename "$repo_url" .git)
        echo "Processing: $repo_name"

        # Check if already exists in Gitea
        existing=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "Authorization: token $GITEA_TOKEN" \
          "$GITEA_URL/api/v1/repos/$GITHUB_USER/$repo_name" 2>/dev/null || echo "000")

        if [[ "$existing" == "200" ]]; then
          echo "  ✓ Already mirrored: $repo_name"
          continue
        fi

        # Get repo info from GitHub API
        echo "  → Fetching info from GitHub..."
        repo_info=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/repos/$GITHUB_USER/$repo_name")

        # Check if repo exists on GitHub
        if echo "$repo_info" | jq -e '.message == "Not Found"' &>/dev/null; then
          echo "  ✗ Repo not found on GitHub: $repo_name"
          continue
        fi

        description=$(echo "$repo_info" | jq -r '.description // ""')
        private=$(echo "$repo_info" | jq -r '.private')
        clone_url=$(echo "$repo_info" | jq -r '.clone_url')

        echo "  → Creating mirror in Gitea..."
        result=$(curl -s -X POST \
          -H "Authorization: token $GITEA_TOKEN" \
          -H "Content-Type: application/json" \
          "$GITEA_URL/api/v1/repos/migrate" \
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
        else
          error_msg=$(echo "$result" | jq -r '.message // "Unknown error"')
          echo "  ✗ Failed: $error_msg"
        fi
      done

      echo ""
      echo "=== Done ==="
    '';

    # Script to update GitHub token in sops (run manually)
    # sops needs the age key derived from the SSH host key to decrypt.
    # sops-nix stores this at /run/secrets.d/age-keys.txt (root:root 0600),
    # so all sops calls must run via sudo with SOPS_AGE_KEY_FILE set.
    updateGithubTokenScript = pkgs.writeShellScriptBin "gitea-update-github-token" ''
      SOPS="${pkgs.sops}/bin/sops"
      AGE_KEY_FILE="/run/secrets.d/age-keys.txt"
      set -euo pipefail

      # Verify we can escalate to access the age key
      if ! sudo test -r "$AGE_KEY_FILE"; then
        echo "Error: Cannot read $AGE_KEY_FILE (need sudo)"
        exit 1
      fi

      sops_wrapper() {
        sudo env SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" "$SOPS" "$@"
      }

      # Find the SystemNix repo
      find_repo() {
        # Check FLAKE_ROOT first (set by nix commands)
        if [[ -n "''${FLAKE_ROOT:-}" ]] && [[ -d "$FLAKE_ROOT/platforms/nixos/secrets" ]]; then
          echo "$FLAKE_ROOT"
          return 0
        fi

        # Check common locations
        for dir in "$HOME/projects/SystemNix" "$HOME/SystemNix" "$HOME/Setup-Mac"; do
          if [[ -d "$dir/platforms/nixos/secrets" ]]; then
            echo "$dir"
            return 0
          fi
        done

        # Try to find from current directory
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

      # Get token from gh CLI
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

      # Get GitHub username
      GITHUB_USER=$(gh api user -q .login 2>/dev/null || echo "")
      if [[ -z "$GITHUB_USER" ]]; then
        echo "Error: Could not get GitHub username"
        exit 1
      fi
      echo "GitHub user: $GITHUB_USER"
      echo ""

      # Update secrets using sops (via sudo with age key)
      echo "Updating sops secrets..."
      cd "$(dirname "$SECRETS_FILE")"

      sops_wrapper set "$SECRETS_FILE" '["github_token"]' "\"$GITHUB_TOKEN\""

      # Update github_user if needed
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
  in {
    options.services.gitea-repos = {
      enable = lib.mkEnableOption "Declarative Gitea repository mirroring";

      user = lib.mkOption {
        type = lib.types.str;
        default = primaryUser;
        description = "User account for running sync services (needs gh CLI access)";
      };

      repos = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "List of GitHub SSH URLs to mirror to Gitea";
        example = ["git@github.com:user/repo.git"];
      };

      autoSync = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to automatically sync repos on rebuild";
      };
    };

    config = lib.mkIf cfg.enable {
      # Ensure gh, sops, and age are available
      environment.systemPackages = [
        ensureReposScript
        updateGithubTokenScript
        pkgs.gh
        pkgs.sops
        pkgs.age
      ];

      # Systemd configuration
      systemd = lib.mkIf cfg.autoSync {
        services.gitea-ensure-repos = {
          description = "Ensure GitHub repos are mirrored to Gitea";
          after = ["gitea.service" "gitea-generate-token.service" "network-online.target"];
          wants = ["network-online.target"];
          requires = ["gitea.service"];
          onFailure = ["notify-failure@%n.service"];
          startLimitIntervalSec = 300;
          startLimitBurst = 3;
          path = [pkgs.curl pkgs.jq pkgs.gh pkgs.sops pkgs.bash];
          serviceConfig =
            {
              Type = "oneshot";
              User = cfg.user;
              EnvironmentFile = config.sops.templates."gitea-sync.env".path;
              ExecStartPre = pkgs.writeShellScript "wait-for-gitea" ''
                echo "Waiting for Gitea to be ready..."
                for i in {1..30}; do
                  if curl -s ${giteaUrl}/api/v1/version &>/dev/null; then
                    echo "Gitea is ready!"
                    exit 0
                  fi
                  echo "Gitea not ready yet, attempt $i/30..."
                  sleep 2
                done
                echo "Gitea failed to become ready after 60 seconds"
                exit 1
              '';
              ExecStart = "${ensureReposScript}/bin/gitea-ensure-repos";
            }
            // serviceDefaults {Restart = "on-failure";}
            // harden {
              ProtectSystem = "strict";
              MemoryMax = "512M";
            };
        };

        # Trigger on rebuild if autoSync is enabled
        tmpfiles.rules = [
          "L /run/gitea-repos-trigger - - - - ${ensureReposScript}/bin/gitea-ensure-repos"
        ];

        # Periodic timer to catch newly-added repos between rebuilds
        timers.gitea-ensure-repos = {
          description = "Ensure GitHub repos are mirrored to Gitea (daily)";
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
