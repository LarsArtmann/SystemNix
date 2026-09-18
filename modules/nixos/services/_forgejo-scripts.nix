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
  # Listing endpoint: GET /user/repos?visibility=all&affiliation=owner.
  # The previous endpoint (GET /users/$USER/repos?type=all) only ever returned
  # PUBLIC repos — private repos were never auto-mirrored (only the two in the
  # declarative forgejo-repos list were). affiliation=owner covers owned
  # public+private+forks; org/collaborator repos stay out of scope (they were
  # never mirrored either — every live mirror is LarsArtmann-owned, verified
  # 2026-09-18).
  #
  # Push mirrors REMOVED (dead code, never worked): the POST omitted the
  # mandatory `interval` field, so forgejo's time.ParseDuration("") 400'd on
  # ALL 18 attempts ever journaled — no push mirror was ever created. A push
  # mirror on a PULL mirror is also incoherent here (the next pull clobbers
  # any forgejo-side commit), so the step is gone rather than fixed. If
  # forgejo→GitHub push is ever wanted, re-add the POST with interval: "8h"
  # AND first settle the pull-vs-push clobber design.
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

      echo "Fetching repositories for GitHub user: $GITHUB_USER (owned, public+private)"

      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user/repos?visibility=all&affiliation=owner&per_page=100&page=$page")
        # Fail loud on non-array responses (rate limit, auth failure, HTML error
        # pages): without this guard .[] yields nothing, `length` sees <100, the
        # loop breaks, and the run reports success with ZERO repos processed —
        # a phantom green that silently stops all mirror creation.
        echo "$response" | jq -e 'type == "array"' > /dev/null || {
          echo "Error: GitHub repo listing (page $page) did not return an array:"
          echo "$response" | jq -r '.message // tostring' 2>/dev/null | head -3
          exit 1
        }
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

  # Rename/transfer/deletion reconciliation for pull mirrors.
  #
  # WHY THIS EXISTS: Forgejo v15 hardens pull mirrors against SSRF by setting
  # http.followRedirects=false on every mirror (ModernizePullMirrorConfig).
  # GitHub answers renamed/transferred repos with a 301 redirect — so the
  # moment a repo moves, its Forgejo mirror STOPS syncing (git refuses the
  # redirect) and the mirror freezes at the pre-move state. Nothing else
  # repairs this: the mirror API has no "update pull-mirror address"
  # endpoint (verified against the deployed swagger.v1.json), and the mirror
  # scripts are name-keyed create-if-missing (a rename also creates a
  # DUPLICATE mirror under the new name while the stale one stays broken).
  #
  # Classes handled (safe-by-default):
  #   renamed within account  → phase 1 creates the new-name mirror; this
  #                             script deletes the stale-name mirror ONLY
  #                             after the canonical mirror exists AND the
  #                             same verdict was seen on a previous run
  #                             (state file, two-run confirmation).
  #   transferred away        → REPORT ONLY (frozen archive kept; owner
  #                             decides: delete or re-mirror into an org).
  #   upstream deleted        → REPORT ONLY (the Forgejo copy is the only
  #                             remaining copy — 32 such archives exist).
  #   transient probe failure → retry next run, never classify.
  reconcileMirrorsScript = pkgs.writeShellApplication {
    name = "forgejo-reconcile-mirrors";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.gh
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ];
    text = ''
      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_OWNER="${primaryUser}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || echo "")}"
      GITHUB_USER="''${GITHUB_USER:-$(gh api user -q .login 2>/dev/null || echo "")}"
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/forgejo-mirror-reconcile"
      PENDING="$STATE_DIR/pending-deletes.txt"
      # node_exporter textfile dir (sticky 1777): this unit is the ONLY writer of
      # forgejo_mirror_reconcile.prom, so mktemp+mv over an own-owned target is
      # legal without CAP_FOWNER. Best-effort: a foreign-owned leftover must
      # WARN (metrics go stale -> gatus fires), never fail the reconcile.
      # Env override exists for fixture tests (stubbed runs redirect it).
      TEXTFILE_DIR="''${FORGEJO_MIRROR_TEXTFILE_DIR:-/var/lib/prometheus-node-exporter/textfile_collectors}"
      publish_prom() {
        if [[ ! -d "$TEXTFILE_DIR" ]]; then
          echo "  (metrics: textfile dir absent — skipping prom publish)"
          return 0
        fi
        local tmp
        tmp=$(mktemp "$TEXTFILE_DIR/forgejo_mirror_reconcile.XXXXXX") || {
          echo "  warn: mktemp in textfile dir failed"
          return 0
        }
        cat > "$tmp"
        chmod 644 "$tmp"
        mv "$tmp" "$TEXTFILE_DIR/forgejo_mirror_reconcile.prom" 2>/dev/null || {
          echo "  warn: cannot publish forgejo_mirror_reconcile.prom (foreign-owned leftover?)"
          rm -f "$tmp"
        }
      }

      if [[ -z "$FORGEJO_TOKEN" || -z "$GITHUB_TOKEN" || -z "$GITHUB_USER" ]]; then
        echo "Error: FORGEJO_TOKEN / GITHUB_TOKEN / GITHUB_USER must all be set"
        exit 1
      fi

      mkdir -p "$STATE_DIR"
      touch "$PENDING"
      CANONICAL=$(mktemp)
      FJMIRRORS=$(mktemp)
      STALE=$(mktemp)
      DELETED=$(mktemp)
      TRANSFERRED=$(mktemp)
      PENDING_NEW=$(mktemp)
      PENDING_TMP=$(mktemp)
      trap 'rm -f "$CANONICAL" "$FJMIRRORS" "$STALE" "$DELETED" "$TRANSFERRED" "$PENDING_NEW" "$PENDING_TMP"' EXIT

      echo "=== Forgejo mirror reconciliation (owner: $GITHUB_USER) ==="

      # 1. Canonical GitHub repo names (same listing source as the mirror script).
      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user/repos?visibility=all&affiliation=owner&per_page=100&page=$page")
        n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end')
        [[ "$n" == "-1" ]] && { echo "Error: GitHub listing failed: $(echo "$response" | jq -r '.message // "unknown"')"; exit 1; }
        echo "$response" | jq -r '.[].name' | tr '[:upper:]' '[:lower:]' >> "$CANONICAL"
        [[ "$n" -lt 100 ]] && break
        page=$((page + 1))
      done
      sort -u -o "$CANONICAL" "$CANONICAL"

      # 2. Forgejo pull mirrors owned by the forgejo account.
      page=1
      while true; do
        response=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/user/repos?limit=50&page=$page")
        n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end')
        [[ "$n" == "-1" ]] && { echo "Error: Forgejo listing failed: $(echo "$response" | jq -r '.message // "unknown"')"; exit 1; }
        echo "$response" | jq -r --arg owner "$FORGEJO_OWNER" \
          '.[] | select((.owner.login | ascii_downcase) == ($owner | ascii_downcase)) | select(.mirror == true) | .name' \
          >> "$FJMIRRORS"
        [[ "$n" -lt 50 ]] && break
        page=$((page + 1))
      done

      total=$(wc -l < "$FJMIRRORS")

      # 3. Stale = forgejo mirrors whose name is no longer a canonical GitHub name.
      sort -u -o "$FJMIRRORS" "$FJMIRRORS"
      comm -23 <(tr '[:upper:]' '[:lower:]' < "$FJMIRRORS" | sort -u) "$CANONICAL" > "$STALE"
      stale_count=$(wc -l < "$STALE")

      # 4. Classify each stale mirror by probing its (old) GitHub path.
      # gh api prints HTTP error BODIES to stdout even on failure (live-proven
      # 2026-09-18: every 404 leaked {"message":"Not Found",...} into $probe and
      # upstream-deleted repos misclassified as "transferred" with a garbage
      # owner). Trust the EXIT CODE plus an owner/name shape check, never the
      # captured stdout alone.
      : > "$PENDING_NEW"
      while read -r lower; do
        # recover the original-case forgejo name for API calls
        name=$(grep -ixF "$lower" "$FJMIRRORS" | head -1)
        # errexit-safe: a 404/network failure must not kill the loop
        rc=0
        probe=$(gh api "repos/$GITHUB_USER/$name" --jq .full_name 2>/dev/null) || rc=$?
        if [[ "$rc" -eq 0 && "$probe" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
          :
        elif [[ "$rc" -eq 0 ]]; then
          # exit 0 but no owner/name shape (jq oddity) — never classify on garbage
          echo "  unresolved probe (will retry): $name (raw: ''${probe:0:60})"
          continue
        else
          # gh HTTP/network error — 404 is the overwhelmingly common case here
          # (the name is already absent from the listing). A rare network blip
          # misclassifies as archived for ONE report-only run; next run heals.
          echo "$name" >> "$DELETED"
          continue
        fi
        up_owner="''${probe%%/*}"
        up_name="''${probe##*/}"
        if [[ "''${up_owner,,}" == "''${GITHUB_USER,,}" ]]; then
          if grep -qxF "''${up_name,,}" "$CANONICAL" && grep -ixF "$up_name" "$FJMIRRORS" &>/dev/null; then
            # canonical-named mirror already exists → stale copy is redundant.
            # Two-run confirmation: delete only when the verdict repeats.
            if grep -qxF "$name" "$PENDING"; then
              is_mirror=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
                "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name" | jq -r '.mirror // false')
              if [[ "$is_mirror" == "true" ]]; then
                code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
                  -H "Authorization: token $FORGEJO_TOKEN" \
                  "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name")
                if [[ "$code" == "204" || "$code" == "200" ]]; then
                  echo "  healed rename: deleted stale '$name' (canonical '$up_name' mirrored)"
                else
                  echo "  FAILED to delete stale '$name' (HTTP $code) — kept"
                  echo "$name" >> "$PENDING_NEW"
                fi
              else
                echo "  refusing to delete '$name': no longer a pull mirror"
              fi
              grep -vxF "$name" "$PENDING" > "$PENDING_TMP" || true
              mv "$PENDING_TMP" "$PENDING"
            else
              echo "  rename confirmed (1st pass, will delete next run): $name → $up_name"
              echo "$name" >> "$PENDING_NEW"
            fi
          else
            # canonical mirror not created yet — phase 1 creates it; reset any pending verdict
            echo "  rename pending creation: $name → $up_name"
            grep -vxF "$name" "$PENDING" > "$PENDING_TMP" || true
            mv "$PENDING_TMP" "$PENDING"
          fi
        else
          echo "$name ($probe)" >> "$TRANSFERRED"
        fi
      done < "$STALE"
      mv "$PENDING_NEW" "$PENDING"

      # Persist the full stale-name set (lowercase) for the dead-mirror
      # collector (forgejo-mirror-health): known-stale = every mirror name
      # that is NOT a canonical GitHub name (renamed / transferred /
      # upstream-deleted). Those fail their dead remotes forever BY DESIGN
      # and must never count as dead candidates. Atomic write: the 5-min
      # collector may read it concurrently.
      stale_tmp=$(mktemp "$STATE_DIR/known-stale.XXXXXX")
      sort -u "$STALE" > "$stale_tmp"
      mv "$stale_tmp" "$STATE_DIR/known-stale.txt"

      echo "=== Reconcile summary ==="
      echo "forgejo pull mirrors: $total"
      echo "stale names examined: $stale_count"
      echo "upstream deleted (kept as frozen archive): $(wc -l < "$DELETED")"
      cat "$DELETED" | sed 's/^/  archived: /'
      echo "transferred away (kept, owner decision): $(wc -l < "$TRANSFERRED")"
      cat "$TRANSFERRED" | sed 's/^/  transferred: /'

      # Reconcile-outcome metrics (report-only classes must not be journal-only —
      # the phantom-green class this repo keeps fighting). Published ONLY on a
      # completed run: a mid-run death leaves the previous file in place, and
      # the unit-state alert (forgejo-github-sync in system-health) owns that
      # failure mode. Leading comment guarantees every metric line has a
      # preceding newline for gatus's anchored pat() forms.
      {
        echo "# forgejo mirror reconcile metrics"
        echo "forgejo_mirror_reconcile_scrape_errors 0"
        echo "forgejo_mirror_total $total"
        echo "forgejo_mirror_stale_names $stale_count"
        echo "forgejo_mirror_upstream_deleted_archived $(wc -l < "$DELETED")"
        echo "forgejo_mirror_transferred $(wc -l < "$TRANSFERRED")"
        echo "forgejo_mirror_pending_deletes $(wc -l < "$PENDING")"
        echo "forgejo_mirror_reconcile_last_run_timestamp $(date +%s)"
      } | publish_prom
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

  # Outbound GitHub push mirrors for CANONICAL (native, non-mirror) repos
  # (staged-primary plan M05). The 2026-09-18 audit proved the OLD push
  # mirror code never worked: the POST omitted the mandatory `interval`
  # field and forgejo's time.ParseDuration("") 400'd on all 18 attempts
  # ever journaled. This rebuild always sends interval:"8h" (schema
  # verified against the deployed v15.0.8 swagger: remote_address /
  # remote_username / remote_password / interval / sync_on_commit).
  #
  # Clobber guard: REFUSES any repo where mirror==true — a push mirror on
  # a PULL mirror is incoherent (the next pull overwrites forgejo-side
  # commits). Canonical repos must be flipped native first
  # (forgejo-flip-repo / forgejo-flip@<name>.service).
  #
  # Auth: the GitHub PAT is stored by forgejo as the push remote's
  # credential — the same secret forgejo already holds for pull
  # migrations. Wired as phase 3 of forgejo-github-sync behind
  # services.forgejo.canonicalRepos (default [] = this script never runs).
  pushMirrorScript = pkgs.writeShellApplication {
    name = "forgejo-push-mirror";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_OWNER="${primaryUser}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-}"
      REPOS="''${FORGEJO_CANONICAL_REPOS:-}"

      if [[ -z "$FORGEJO_TOKEN" || -z "$GITHUB_TOKEN" || -z "$GITHUB_USER" ]]; then
        echo "Error: FORGEJO_TOKEN / GITHUB_TOKEN / GITHUB_USER must all be set" >&2
        exit 1
      fi
      if [[ -z "$REPOS" ]]; then
        echo "forgejo-push-mirror: canonicalRepos empty — nothing to do"
        exit 0
      fi

      read -r -a repos <<< "$REPOS"
      FAILED=0
      for name in "''${repos[@]}"; do
        repo=$(curl -sf --compressed \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name") || {
          echo "✗ $name: not found on forgejo (canonicalRepos drift? create it natively or flip it)" >&2
          FAILED=1
          continue
        }
        if [[ "$(echo "$repo" | jq -r '.mirror')" == "true" ]]; then
          echo "✗ $name: still a PULL mirror — refusing (flip first: sudo systemctl start forgejo-flip@$name.service)" >&2
          FAILED=1
          continue
        fi
        existing=$(curl -sf --compressed \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" \
          | jq 'length') || existing=0
        if [[ "$existing" != "0" ]]; then
          echo "✓ $name: push mirror already attached"
          continue
        fi
        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H "Content-Type: application/json" \
          "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" \
          -d "$(jq -n \
            --arg remote "https://github.com/$GITHUB_USER/$name.git" \
            --arg username "$GITHUB_USER" \
            --arg password "$GITHUB_TOKEN" \
            '{remote_address: $remote, remote_username: $username, remote_password: $password, interval: "8h", sync_on_commit: true}')")
        if [[ "$code" == "200" || "$code" == "201" ]]; then
          echo "✓ $name: push mirror attached (interval 8h, sync_on_commit)"
        else
          echo "✗ $name: push mirror POST failed (HTTP $code)" >&2
          FAILED=1
        fi
      done
      exit "$FAILED"
    '';
  };

  # Convert a disposable PULL mirror into a NATIVE canonical repo with a
  # one-time FULL import (issues/PRs/labels/milestones/releases/wiki/LFS),
  # then attach the GitHub push mirror (staged-primary plan M06).
  #
  # Safety model:
  # - The mirror is disposable BY DEFINITION (a byte-copy of GitHub):
  #   deleting it loses nothing GitHub does not still have.
  # - Refuses anything that is not a pull mirror — a native repo would be
  #   PRIMARY data, and the plan guardrail "no repository DELETE outside
  #   forgejo-flip-repo" applies to this script too.
  # - Refuses names with a pending reconcile verdict (rename in flight).
  # - On migrate failure AFTER the delete: the repo is gone on forgejo;
  #   recovery = re-run this script, or forgejo-mirror-github recreates
  #   the mirror. GitHub never lost anything.
  #
  # Operator paths: `sudo systemctl start forgejo-flip@<name>.service`
  # (env + onFailure wired), `forgejo-flip-check@<name>` for the dry-run
  # twin, or the PATH binary with the sync unit's env for fixture tests.
  flipRepoScript = pkgs.writeShellApplication {
    name = "forgejo-flip-repo";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.gh
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      usage() {
        echo "Usage: forgejo-flip-repo <name> [--dry-run]" >&2
        exit 1
      }
      die() { echo "ERROR: $*" >&2; exit 1; }

      [[ $# -ge 1 && $# -le 2 ]] || usage
      name="$1"
      dry_run=0
      [[ "''${2:-}" == "--dry-run" ]] && dry_run=1
      [[ $# -eq 2 && "$dry_run" -eq 0 ]] && usage

      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_OWNER="${primaryUser}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-}"
      RECONCILE_DIR="''${FORGEJO_RECONCILE_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/forgejo-mirror-reconcile}"

      [[ -n "$FORGEJO_TOKEN" && -n "$GITHUB_TOKEN" && -n "$GITHUB_USER" ]] \
        || die "FORGEJO_TOKEN / GITHUB_TOKEN / GITHUB_USER must all be set"

      echo "=== forgejo-flip-repo: $name ==="

      repo=$(curl -sf --compressed \
        -H "Authorization: token $FORGEJO_TOKEN" \
        "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name") \
        || die "$name not found on forgejo"
      [[ "$(echo "$repo" | jq -r '.owner.login')" == "$FORGEJO_OWNER" ]] \
        || die "$name is not owned by $FORGEJO_OWNER (starred org?) — out of scope"
      [[ "$(echo "$repo" | jq -r '.mirror')" == "true" ]] \
        || die "$name is NOT a pull mirror — native repos are primary data, refusing"
      if [[ -f "$RECONCILE_DIR/pending-deletes.txt" ]] \
        && grep -ixqF "$name" "$RECONCILE_DIR/pending-deletes.txt"; then
        die "$name has a pending reconcile verdict (rename in flight) — resolve first"
      fi

      gh_repo=$(gh api "repos/$GITHUB_USER/$name") \
        || die "$name not found on GitHub ($GITHUB_USER) — nothing to import from"
      gh_branch=$(echo "$gh_repo" | jq -r '.default_branch')
      gh_issues=$(echo "$gh_repo" | jq -r '.open_issues_count')
      gh_private=$(echo "$gh_repo" | jq -r '.private')
      gh_desc=$(echo "$gh_repo" | jq -r '.description // ""')

      echo "  source: github.com/$GITHUB_USER/$name (branch=$gh_branch open_issues=$gh_issues private=$gh_private)"
      echo "  plan:   DELETE disposable mirror -> migrate mirror:false (issues+PRs+labels+milestones+releases+wiki+lfs) -> attach push mirror (8h, sync_on_commit)"
      if [[ "$dry_run" -eq 1 ]]; then
        echo "DRY RUN: no changes made"
        exit 0
      fi

      code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: token $FORGEJO_TOKEN" \
        "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name")
      [[ "$code" == "204" || "$code" == "200" ]] \
        || die "DELETE of mirror $name failed (HTTP $code) — nothing changed, aborting"

      code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Authorization: token $FORGEJO_TOKEN" \
        -H "Content-Type: application/json" \
        "$FORGEJO_URL/api/v1/repos/migrate" \
        -d "$(jq -n \
          --arg clone "https://github.com/$GITHUB_USER/$name.git" \
          --arg repo_name "$name" \
          --arg description "$gh_desc" \
          --argjson private "$gh_private" \
          --arg auth "$GITHUB_TOKEN" \
          --argjson uid 1 \
          '{
            clone_addr: $clone,
            repo_name: $repo_name,
            uid: $uid,
            auth_token: $auth,
            mirror: false,
            private: $private,
            description: $description,
            wiki: true,
            labels: true,
            issues: true,
            pull_requests: true,
            releases: true,
            milestones: true,
            lfs: true,
            service: "git"
          }')")
      if [[ "$code" != "200" && "$code" != "201" ]]; then
        die "migrate of $name failed (HTTP $code) — mirror already deleted. Recovery: re-run this script, or forgejo-mirror-github recreates the mirror"
      fi

      repo2=$(curl -sf --compressed \
        -H "Authorization: token $FORGEJO_TOKEN" \
        "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name") \
        || die "post-flip GET failed — repo not readable after migrate"
      [[ "$(echo "$repo2" | jq -r '.mirror')" == "false" ]] \
        || die "post-flip verify failed: mirror flag still true"
      fj_branch=$(echo "$repo2" | jq -r '.default_branch')
      [[ "$fj_branch" == "$gh_branch" ]] \
        || die "post-flip verify failed: default branch '$fj_branch' != GitHub '$gh_branch'"
      fj_issues=$(echo "$repo2" | jq -r '.open_issues_count')
      if [[ "$gh_issues" -gt 0 && "$fj_issues" -eq 0 ]]; then
        die "post-flip verify failed: GitHub had $gh_issues open issues but forgejo imported 0"
      fi

      attached=$(curl -sf --compressed \
        -H "Authorization: token $FORGEJO_TOKEN" \
        "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" | jq 'length') || attached=0
      if [[ "$attached" == "0" ]]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H "Content-Type: application/json" \
          "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" \
          -d "$(jq -n \
            --arg remote "https://github.com/$GITHUB_USER/$name.git" \
            --arg username "$GITHUB_USER" \
            --arg password "$GITHUB_TOKEN" \
            '{remote_address: $remote, remote_username: $username, remote_password: $password, interval: "8h", sync_on_commit: true}')")
        [[ "$code" == "200" || "$code" == "201" ]] \
          || die "push mirror attach failed (HTTP $code) — repo is native+imported; attach via forgejo-push-mirror later"
      fi
      listed=$(curl -sf --compressed \
        -H "Authorization: token $FORGEJO_TOKEN" \
        "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" | jq 'length') || listed=0
      [[ "$listed" != "0" ]] || die "post-flip verify failed: no push mirror listed"

      echo "FLIPPED $name: native + full import (branch=$fj_branch issues=$fj_issues) + push mirror attached"
    '';
  };

  # Dead pull-mirror detection (staged-primary plan M07 — REDESIGNED
  # 2026-09-18 after the plan's mirror_updated-vs-updated_at heuristic was
  # falsified against the live forgejo: every mirror, including the known
  # frozen ones, carries a FRESH mirror_updated because TouchMirror
  # advances the same column on FAILED syncs (services/mirror/mirror_pull.go
  # SyncPullMirror -> models/repo TouchMirror), and idle-but-healthy
  # mirrors carry frozen updated_at — the pair cannot separate dead from
  # idle). Authoritative per-repo signal: the `notice` table — every FAILED
  # pull-mirror sync writes a Type=1 row "Failed to update mirror
  # repository '<path>.git'" (runSync -> CreateRepositoryNotice). Known
  # stale names (renamed / transferred / upstream-deleted — they 404
  # forever by design) are subtracted via the reconcile script's
  # known-stale.txt state file.
  #
  # Fail-closed: unreadable DB, unreadable stale file, or sqlite failure
  # => scrape_errors 1 and the dead_candidates line is ABSENT (the Gatus
  # check goes red; no phantom zeros).
  mirrorHealthScript = pkgs.writeShellApplication {
    name = "forgejo-mirror-health";
    runtimeInputs = [
      pkgs.sqlite
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      DB="''${FORGEJO_DB:-${stateDir}/data/forgejo.db}"
      STALE_FILE="''${FORGEJO_KNOWN_STALE:-/home/${primaryUser}/.local/state/forgejo-mirror-reconcile/known-stale.txt}"
      WINDOW="''${FORGEJO_DEAD_WINDOW:-86400}"
      TF_DIR="''${FORGEJO_MIRROR_HEALTH_TEXTFILE_DIR:-/var/lib/prometheus-node-exporter/textfile_collectors}"

      publish() {
        if [[ ! -d "$TF_DIR" ]]; then
          echo "(metrics: textfile dir absent — skipping prom publish)"
          return 0
        fi
        local tmp
        tmp=$(mktemp "$TF_DIR/forgejo-mirror-health.XXXXXX") || return 0
        cat > "$tmp"
        chmod 644 "$tmp"
        mv "$tmp" "$TF_DIR/forgejo_mirror_health.prom" 2>/dev/null \
          || { echo "warn: cannot publish forgejo_mirror_health.prom" >&2; rm -f "$tmp"; }
      }

      if [[ ! -r "$DB" ]]; then
        echo "forgejo-mirror-health: DB not readable: $DB" >&2
        printf '# forgejo mirror health metrics\nforgejo_mirror_health_scrape_errors 1\n' | publish
        exit 0
      fi
      if [[ ! -r "$STALE_FILE" ]]; then
        echo "forgejo-mirror-health: known-stale file missing: $STALE_FILE (first reconcile run after deploy publishes it)" >&2
        printf '# forgejo mirror health metrics\nforgejo_mirror_health_scrape_errors 1\n' | publish
        exit 0
      fi

      cutoff=$(( $(date +%s) - WINDOW ))
      rc=0
      rows=$(sqlite3 -readonly "$DB" ".timeout 5000" \
        "SELECT description FROM notice WHERE type = 1 AND created_unix > $cutoff" 2>/dev/null) || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        echo "forgejo-mirror-health: sqlite query failed (rc=$rc)" >&2
        printf '# forgejo mirror health metrics\nforgejo_mirror_health_scrape_errors 1\n' | publish
        exit 0
      fi

      dead=0
      while IFS= read -r n; do
        [[ -n "$n" ]] || continue
        grep -ixqF "$n" "$STALE_FILE" && continue
        dead=$((dead + 1))
        echo "  dead candidate: $n (syncs failing 24h+, not known-stale)"
      done < <(printf '%s\n' "$rows" \
        | grep "Failed to update mirror repository '" \
        | grep -v " repository wiki '" \
        | cut -d"'" -f2 \
        | while IFS= read -r p; do basename "$p" .git; done \
        | sort -u)

      {
        echo "# forgejo mirror health metrics"
        echo "forgejo_mirror_health_scrape_errors 0"
        echo "forgejo_mirror_dead_candidates $dead"
      } | publish
    '';
  };

  # Live-forge census (staged-primary plan M08): native-vs-mirror split
  # per owner/org — the flip-rollout tracking numbers. Operator-run at
  # gates (sudo systemctl start forgejo-census; journalctl -u forgejo-census).
  censusScript = pkgs.writeShellApplication {
    name = "forgejo-census";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"

      if [[ -z "$FORGEJO_TOKEN" ]]; then
        echo "Error: FORGEJO_TOKEN not set" >&2
        exit 1
      fi

      ALL=$(mktemp)
      trap 'rm -f "$ALL"' EXIT

      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/user/repos?limit=50&page=$page")
        n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end')
        [[ "$n" == "-1" ]] && { echo "Error: forgejo listing failed: $(echo "$response" | jq -r '.message // "unknown"')" >&2; exit 1; }
        echo "$response" >> "$ALL"
        [[ "$n" -lt 50 ]] && break
        page=$((page + 1))
      done

      echo "=== forgejo census ($(date -u +%FT%TZ)) ==="
      jq -s '
        add
        | {
            total: length,
            native: ([.[] | select(.mirror != true)] | length),
            mirror: ([.[] | select(.mirror == true)] | length),
            per_owner: (
              [group_by(.owner.login)[] | {
                owner: .[0].owner.login,
                native: ([.[] | select(.mirror != true)] | length),
                mirror: ([.[] | select(.mirror == true)] | length)
              }]
            )
          }
      ' "$ALL"
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
      #    Parse the pinned forgejo CLI table (verified against the 15.0.7
      #    binary + source: header format "ID\tUsername\tEmail\tIsActive\t
      #    IsAdmin\t2FA" rendered by tabwriter.NewWriter(5, 0, 1, ' ', 0),
      #    i.e. SPACE-padded columns — no literal tabs in the output).
      #    Usernames and emails cannot contain whitespace, so whitespace
      #    field-splitting is exact; mapping columns by the header row keeps
      #    the parser order-independent. Match the EXACT username first, then
      #    verify that row's email: a plain email grep false-positives on any
      #    other user whose address merely contains "hermes-agent", skipping
      #    creation and failing much later at token generation with a
      #    confusing user-not-found error.
      USER_LIST=$("$FORGEJO" admin user list) || {
        echo "ERROR: forgejo admin user list failed" >&2
        exit 1
      }
      FOUND_EMAIL=$(printf '%s\n' "$USER_LIST" | awk -v want="$FORGEJO_USER_NAME" '
        NR == 1 {
          for (i = 1; i <= NF; i++) {
            if ($i == "Username") user_col = i
            if ($i == "Email") email_col = i
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
          FORGEJO_TOKEN=$(grep -E '^FORGEJO_TOKEN=[0-9a-f]{40}$' "$TOKEN_FILE" | cut -d= -f2)  # dead-guard-ok: exempt: guarded by the preceding grep -q pre-check
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
