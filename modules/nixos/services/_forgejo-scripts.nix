# Forgejo shell scripts: mirror sync, admin setup, OIDC, runner registration
# Extracted from forgejo.nix to keep the module focused on service configuration.
{
  pkgs,
  lib,
  config,
  primaryUser,
  cfg,
  forgejoPkg,
  forgejoUrl,
  stateDir,
  hostName,
  runnerLabels,
  runnerConfigFile,
}:
let
  # 'or {}' so a standalone nixosModules.forgejo consumer that does not import
  # nixosModules.hermes evaluates without error (the deliver script and unit
  # are only wired when hermes is enabled — see forgejo.nix).
  hermesCfg = config.services.hermes or { };
in
{
  mirrorGithubScript = pkgs.writeShellApplication {
    name = "forgejo-mirror-github";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.gh
    ];
    text = ''
      REPOS_FILE=$(mktemp)
      trap 'rm -f "$REPOS_FILE"' EXIT

      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_OWNER="${primaryUser}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-$(gh api user -q .login 2>/dev/null || echo "")}"

      if [[ -z "$FORGEJO_TOKEN" ]]; then
        echo "Error: FORGEJO_TOKEN not set (is forgejo-generate-token.service healthy?)"
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
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/users/$GITHUB_USER/repos?per_page=100&page=$page&type=all")
        echo "$response" | jq -r '.[] | "\(.name)|\(.clone_url)|\(.private)|\(.description // "")"' >> "$REPOS_FILE"
        [[ $(echo "$response" | jq 'length') -lt 100 ]] && break
        page=$((page + 1))
      done

      FAILED=0

      while IFS='|' read -r name clone_url private description; do
        [[ -z "$name" ]] && continue

        existing=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name")

        if [[ "$existing" == "200" ]]; then
          echo "✓ Already mirrored: $name"
          continue
        fi

        # Clear any orphan git dir left by an interrupted migrate (past OOM/crash).
        # This is safe: the GET above confirmed the repo has NO DB record, so the
        # endpoint can only touch unadopted on-disk dirs, never a registered repo.
        # 204 = orphan deleted, 404 = no orphan existed (normal for never-migrated repos).
        curl -s -o /dev/null -X DELETE \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/admin/unadopted/$FORGEJO_OWNER/$name"

        echo "→ Mirroring: $name"

        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H "Content-Type: application/json" \
          "$FORGEJO_URL/api/v1/repos/migrate" \
          -d "$(jq -n \
            --arg name "$name" \
            --arg clone_url "$clone_url" \
            --argjson private "$private" \
            --arg description "$description" \
            --arg auth_token "$GITHUB_TOKEN" \
            --arg uid "1" \
            '{
              clone_addr: $clone_url,
              repo_name: $name,
              uid: ($uid | tonumber),
              auth_token: $auth_token,
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
            }')")

        if [[ "$code" == "200" || "$code" == "201" ]]; then
          echo "  ✓ Created mirror: $name"

          echo "  → Setting up push mirror to GitHub: $name"
          pmirror=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
            -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Content-Type: application/json" \
            "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" \
            -d "$(jq -n \
              --arg remote "https://$GITHUB_USER:''${GITHUB_TOKEN}@github.com/$GITHUB_USER/$name.git" \
              '{
                remote_address: $remote,
                sync_on_commit: true
              }')")
          if [[ "$pmirror" != "200" && "$pmirror" != "201" ]]; then
            echo "  ⚠ Push mirror setup HTTP $pmirror (may already exist)"
          fi
        else
          echo "  ✗ Failed (HTTP $code): $name"
          FAILED=$((FAILED + 1))
        fi
      done < "$REPOS_FILE"

      count=$(wc -l < "$REPOS_FILE")
      echo "✓ Done! $count repos processed, $FAILED failed"

      if [[ "$FAILED" -gt 0 ]]; then
        exit 1
      fi
    '';
  };

  mirrorStarredScript = pkgs.writeShellApplication {
    name = "forgejo-mirror-starred";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.gh
    ];
    text = ''
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
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
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
  };

  setupScript = pkgs.writeShellApplication {
    name = "forgejo-setup";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
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
  };

  ensurePasswordFile = pkgs.writeShellApplication {
    name = "forgejo-ensure-password-file";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      PASS_FILE="${stateDir}/.admin-password"
      if [ ! -f "$PASS_FILE" ]; then
        head -c 32 /dev/urandom | base64 > "$PASS_FILE"
      fi
      chown forgejo:forgejo "$PASS_FILE"
      chmod 600 "$PASS_FILE"
    '';
  };

  adminSetup = pkgs.writeShellApplication {
    name = "forgejo-admin-setup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      ADMIN_USER="${primaryUser}"
      ADMIN_EMAIL="${primaryUser}@local"
      PASS_FILE="${stateDir}/.admin-password"
      FORGEJO=${lib.getExe forgejoPkg}

      ADMIN_PASS="$(head -n1 "$PASS_FILE" | tr -d '\n')"

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
  };

  # Runs AS the forgejo user (tokenGen idiom): the CLI talks to the DB
  # directly, no runuser/PAM needed (runuser cannot init a PAM session inside
  # harden {}, documented gotcha). The staged token is delivered to /run by
  # hermesForgejoTokenDeliver via the unit's "+"-prefixed ExecStartPost.
  hermesForgejoToken = pkgs.writeShellApplication {
    name = "forgejo-hermes-token";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
      pkgs.curl
    ];
    text = ''
      # Idempotent: create hermes-agent user (unprivileged, no UI login needed),
      # mint a read:repository-scoped token, stage it for hermes delivery.
      #
      # NOT --restricted: restricted users cannot see other users' PUBLIC repos,
      # which would defeat the purpose. Least privilege here = normal user that
      # owns nothing + token scoped to read:repository (sees exactly what an
      # anonymous visitor sees, plus any private repo explicitly granted later).
      set -euo pipefail

      FORGEJO=${lib.getExe forgejoPkg}
      export FORGEJO_WORK_DIR=${stateDir}
      # Persisted forgejo-only staging file: survives reboots so the reuse path
      # works and tokens do not accumulate. The /run copy is (re)installed by
      # ExecStartPost on every run.
      STAGED_TOKEN_FILE=${stateDir}/hermes-agent.token
      FORGEJO_USER_NAME=hermes-agent
      FORGEJO_USER_EMAIL=hermes-agent@noreply.forgejo.home.lan

      # Fail fast if Forgejo never comes up: --fail treats HTTP errors as errors,
      # bounded connect/total timeouts prevent a hung curl per iteration.
      for _ in $(seq 1 30); do
        curl -sf --connect-timeout 3 --max-time 5 -o /dev/null "${forgejoUrl}/" && break
        sleep 1
      done
      curl -sf --connect-timeout 3 --max-time 5 -o /dev/null "${forgejoUrl}/" || {
        echo "ERROR: Forgejo not reachable at ${forgejoUrl} after 30 attempts" >&2
        exit 1
      }

      # 1. user (create-or-verify; password is random and never delivered —
      #    the token is the only credential that leaves this box).
      #    The user list is the pinned forgejo CLI table (tabwriter with
      #    padchar '\t', so every cell is terminated by EXACTLY one tab and
      #    no field can contain one). Parse columns by the header row's
      #    positions, match the EXACT username, then verify that row's email:
      #    a plain email grep false-positives on any other user whose address
      #    merely contains "hermes-agent", skipping creation and failing much
      #    later at token generation with a confusing user-not-found error.
      USER_LIST=$("$FORGEJO" admin user list) || {
        echo "ERROR: forgejo admin user list failed" >&2
        exit 1
      }
      FOUND_EMAIL=$(printf '%s\n' "$USER_LIST" | awk -F'\t' -v want="$FORGEJO_USER_NAME" '
        NR == 1 {
          for (i = 1; i <= NF; i++) {
            col = $i; sub(/^[[:space:]]+/, "", col); sub(/[[:space:]]+$/, "", col)
            if (col == "Username") user_col = i
            if (col == "Email") email_col = i
          }
          if (!user_col || !email_col) {
            print "ERROR: forgejo admin user list output has no Username/Email columns" > "/dev/stderr"
            exit 2
          }
          next
        }
        $user_col == want { print $email_col }
      ') || {
        echo "ERROR: could not parse forgejo admin user list output" >&2
        exit 1
      }
      if [ -z "$FOUND_EMAIL" ]; then
        echo "Creating Forgejo user: $FORGEJO_USER_NAME"
        "$FORGEJO" admin user create \
          --username "$FORGEJO_USER_NAME" \
          --email "$FORGEJO_USER_EMAIL" \
          --random-password \
          --must-change-password=false
      elif [ "$FOUND_EMAIL" != "$FORGEJO_USER_EMAIL" ]; then
        echo "ERROR: Forgejo user $FORGEJO_USER_NAME exists with email '$FOUND_EMAIL' (expected '$FORGEJO_USER_EMAIL') — fix the account or the configured email" >&2
        exit 1
      else
        echo "User $FORGEJO_USER_NAME already exists"
      fi

      # 2. token — reuse if still valid, else mint a new one.
      #    The validity probe MUST stay in the repository scope category:
      #    GET /api/v1/user requires the "user" scope (403 for a
      #    read:repository-only token), and GET /api/v1/user/repos requires
      #    BOTH user and repository categories (group middleware composes
      #    AND-style; verified against forgejo 15.0.6 routers/api/v1/api.go +
      #    modules/web/route.go). GET /api/v1/repos/search sits in the
      #    repository-scoped group only: 200 for this token, 401 once revoked
      #    (invalid tokens are rejected by the auth middleware before routing).
      TOKEN=""
      if [ -s "$STAGED_TOKEN_FILE" ]; then
        TOKEN=$(cat "$STAGED_TOKEN_FILE")
        if curl -sf --connect-timeout 3 --max-time 10 \
          -H "Authorization: token $TOKEN" \
          "${forgejoUrl}/api/v1/repos/search?limit=1" >/dev/null 2>&1; then
          echo "Existing hermes-agent token still valid"
          exit 0
        fi
        echo "Existing token invalid; regenerating"
      fi

      TOKEN=$("$FORGEJO" admin user generate-access-token \
        --username "$FORGEJO_USER_NAME" \
        --token-name "hermes-agent-$(date +%s)" \
        --scopes read:repository \
        --raw) || TOKEN=""

      if ! echo "$TOKEN" | grep -qE '^[0-9a-f]{40}$'; then
        echo "ERROR: token generation failed for hermes-agent" >&2
        exit 1
      fi

      # 3. stage forgejo-only; ExecStartPost installs the hermes copy at
      #    /run/hermes-forgejo-token (0400 hermes:hermes, tmpfs)
      #    Atomic install: the existing 0400 file is read-only even for the
      #    forgejo owner, so a bare redirect would EACCES on regeneration.
      TMP_TOKEN_FILE=$(mktemp "$STAGED_TOKEN_FILE.XXXXXX")
      trap 'rm -f "$TMP_TOKEN_FILE"' EXIT
      printf '%s' "$TOKEN" > "$TMP_TOKEN_FILE"
      install -m 0400 "$TMP_TOKEN_FILE" "$STAGED_TOKEN_FILE"
      rm -f "$TMP_TOKEN_FILE"
      echo "hermes-agent token staged at $STAGED_TOKEN_FILE"
    '';
  };

  # Installed by forgejo-hermes-token's "+"-prefixed ExecStartPost: runs with
  # FULL privileges (outside harden {}), where chown to the hermes user works
  # without capabilities on the sandboxed main process (gitea-runner's
  # +forgejo-gen-runner-token idiom).
  # hermesCfg (defined in the let binding above) falls back to {} when the
  # hermes module is absent, so this script still builds for standalone forgejo.
  inherit hermesCfg;
  hermesForgejoTokenDeliver = pkgs.writeShellApplication {
    name = "forgejo-hermes-token-deliver";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail
      install \
        -o ${hermesCfg.user or "hermes"} \
        -g ${hermesCfg.group or "hermes"} \
        -m 0400 \
        ${stateDir}/hermes-agent.token \
        /run/hermes-forgejo-token
    '';
  };

  tokenGen = pkgs.writeShellApplication {
    name = "forgejo-token-gen";
    runtimeInputs = [
      pkgs.curl
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      ADMIN_USER="${primaryUser}"
      TOKEN_FILE="${stateDir}/.admin-token.env"
      FORGEJO=${lib.getExe forgejoPkg}
      export FORGEJO_WORK_DIR=${stateDir}

      for _ in $(seq 1 30); do
        if curl -s -o /dev/null -w "" "${forgejoUrl}/"; then
          break
        fi
        sleep 1
      done

      FORGEJO_TOKEN=""
      if [ -f "$TOKEN_FILE" ]; then
        if grep -qE '^FORGEJO_TOKEN=[0-9a-f]{40}$' "$TOKEN_FILE" 2>/dev/null; then
          FORGEJO_TOKEN=$(grep -E '^FORGEJO_TOKEN=[0-9a-f]{40}$' "$TOKEN_FILE" | cut -d= -f2)
        fi
        if [ -n "$FORGEJO_TOKEN" ] && curl -sf -H "Authorization: token $FORGEJO_TOKEN" "${forgejoUrl}/api/v1/user" >/dev/null 2>&1; then
          echo "Forgejo API token still valid, skipping regeneration"
          exit 0
        fi
        echo "Existing token missing or invalid; regenerating"
        FORGEJO_TOKEN=""
      fi

      TOKEN=""
      TOKEN_NAME="sync-$(date +%s)"

      TOKEN=$($FORGEJO admin user generate-access-token \
        --username "$ADMIN_USER" \
        --token-name "$TOKEN_NAME" \
        --scopes all \
        --raw 2>/dev/null) || TOKEN=""

      if ! echo "$TOKEN" | grep -qE '^[0-9a-f]{40}$'; then
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
  };

  genRunnerToken = pkgs.writeShellApplication {
    name = "forgejo-gen-runner-token";
    runtimeInputs = [
      pkgs.curl
      pkgs.util-linux
    ];
    text = ''
      TOKEN_FILE="/run/forgejo-runner/token"
      mkdir -p "$(dirname "$TOKEN_FILE")"

      for _ in $(seq 1 60); do
        curl -sf -o /dev/null "${forgejoUrl}/" && break
        sleep 1
      done

      TOKEN=$(runuser -u forgejo -- \
        env FORGEJO_WORK_DIR=${stateDir} \
        ${lib.getExe forgejoPkg} actions generate-runner-token) || {
          echo "ERROR: Failed to generate runner registration token"
          exit 1
        }

      printf 'TOKEN=%s\n' "$TOKEN" > "$TOKEN_FILE"
      chmod 644 "$TOKEN_FILE"
    '';
  };

  registerRunner = pkgs.writeShellApplication {
    name = "forgejo-register-runner";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.forgejo-runner
    ];
    text = ''
      export INSTANCE_DIR="$STATE_DIRECTORY/${hostName}"
      mkdir -vp "$INSTANCE_DIR"
      cd "$INSTANCE_DIR"

      # shellcheck source=/dev/null
      source /run/forgejo-runner/token

      if [ ! -f "$INSTANCE_DIR/.forgejo-migrated" ]; then
        echo "Forcing runner re-registration (Gitea→Forgejo migration)"
        rm -f "$INSTANCE_DIR/.runner"
        touch "$INSTANCE_DIR/.forgejo-migrated"
      fi

      export LABELS_FILE="$INSTANCE_DIR/.labels"
      LABELS_WANTED="$(echo ${lib.escapeShellArg (lib.concatStringsSep "\n" runnerLabels)} | sort)"
      LABELS_CURRENT="$(cat "$LABELS_FILE" 2>/dev/null || echo "")"

      if [ ! -e "$INSTANCE_DIR/.runner" ] || [ "$LABELS_WANTED" != "$LABELS_CURRENT" ]; then
        rm -f "$INSTANCE_DIR/.runner"

        act_runner register --no-interactive \
          --instance ${lib.escapeShellArg forgejoUrl} \
          --token "$TOKEN" \
          --name ${lib.escapeShellArg hostName} \
          --labels ${lib.escapeShellArg (lib.concatStringsSep "," runnerLabels)} \
          --config ${runnerConfigFile}

        echo "$LABELS_WANTED" > "$LABELS_FILE"
      fi
    '';
  };

  oidcSetupScript = pkgs.writeShellApplication {
    name = "forgejo-oidc-setup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
      pkgs.util-linux
      pkgs.curl
    ];
    text = ''
      set -euo pipefail

      runuser() { shift 2; shift; "$@"; }

      FORGEJO=${lib.getExe forgejoPkg}
      WORK_DIR=${stateDir}
      CLIENT_ID="forgejo"
      AUTH_NAME="PocketID"
      DISCOVERY_URL="https://auth.${config.networking.domain}/.well-known/openid-configuration"

      echo "=== Forgejo OIDC Setup ==="

      for _ in $(seq 1 30); do
        curl -sf -o /dev/null "${forgejoUrl}/" && break
        sleep 2
      done

      CLIENT_SECRET="$(cat "$CREDENTIALS_DIRECTORY/forgejo-oidc-client-secret")"

      EXISTING_ID=$(runuser -u forgejo -- \
        env FORGEJO_WORK_DIR="$WORK_DIR" \
        "$FORGEJO" admin auth list 2>/dev/null \
        | grep "$AUTH_NAME" | awk '{print $1}' || true)

      if [ -n "$EXISTING_ID" ]; then
        echo "Updating OAuth2 auth source '$AUTH_NAME' (id=$EXISTING_ID)..."
        runuser -u forgejo -- \
          env FORGEJO_WORK_DIR="$WORK_DIR" \
          "$FORGEJO" admin auth update-oauth \
            --id "$EXISTING_ID" \
            --name "$AUTH_NAME" \
            --provider "openidConnect" \
            --key "$CLIENT_ID" \
            --secret "$CLIENT_SECRET" \
            --auto-discover-url "$DISCOVERY_URL" \
            --scopes "openid profile email" \
            --skip-local-2fa
      else
        echo "Creating OAuth2 auth source '$AUTH_NAME'..."
        runuser -u forgejo -- \
          env FORGEJO_WORK_DIR="$WORK_DIR" \
          "$FORGEJO" admin auth add-oauth \
            --name "$AUTH_NAME" \
            --provider "openidConnect" \
            --key "$CLIENT_ID" \
            --secret "$CLIENT_SECRET" \
            --auto-discover-url "$DISCOVERY_URL" \
            --scopes "openid profile email" \
            --skip-local-2fa
      fi

      echo "✓ OIDC auth source '$AUTH_NAME' configured."
    '';
  };

  addKeysScript = pkgs.writeShellApplication {
    name = "forgejo-ssh-keys";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      TOKEN_FILE="${stateDir}/.admin-token.env"
      FORGEJO_TOKEN=""
      if [ -f "$TOKEN_FILE" ]; then
        FORGEJO_TOKEN=$(grep -E '^FORGEJO_TOKEN=[0-9a-f]{40}$' "$TOKEN_FILE" 2>/dev/null | cut -d= -f2 || true)
      fi

      if [[ -z "$FORGEJO_TOKEN" ]]; then
        echo "Error: FORGEJO_TOKEN not found in $TOKEN_FILE"
        exit 1
      fi

      KEYS_FILE=${lib.escapeShellArg (pkgs.writeText "forgejo-ssh-keys.json" (builtins.toJSON cfg.sshKeys))}

      existing_keys=$(mktemp)
      trap 'rm -f "$existing_keys"' EXIT

      for user in $(jq -r 'keys[]' "$KEYS_FILE"); do
        echo "Syncing SSH keys for Forgejo user: $user"

        curl -sf --compressed -H "Authorization: token $FORGEJO_TOKEN" \
          "${forgejoUrl}/api/v1/users/$user/keys" > "$existing_keys"

        mapfile -t keys < <(jq -r --arg user "$user" '.[$user][]' "$KEYS_FILE")

        for key in "''${keys[@]}"; do
          [[ -z "$key" ]] && continue

          if jq -e --arg key "$key" '.[] | select(.key == $key)' "$existing_keys" >/dev/null 2>&1; then
            echo "  ✓ Key already exists"
            continue
          fi

          title="nix-declared"
          response=$(curl -s --compressed -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Content-Type: application/json" \
            "${forgejoUrl}/api/v1/admin/users/$user/keys" \
            -d "$(jq -n --arg key "$key" --arg title "$title" '{key: $key, title: $title}')")

          http_code=$(echo "$response" | tail -n1)
          body=$(echo "$response" | sed '$d')

          if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
            echo "  ✓ Added key"
          else
            echo "  ✗ Failed to add key (HTTP $http_code): $body"
            exit 1
          fi
        done
      done
    '';
  };
}
