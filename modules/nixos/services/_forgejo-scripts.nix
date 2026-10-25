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
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ];
    text = ''
      REPOS_FILE=$(mktemp)
      ORGS_FILE=$(mktemp)
      trap 'rm -f "$REPOS_FILE" "$ORGS_FILE"' EXIT

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

      # Fail loud on non-array listing responses (rate limit, auth failure,
      # HTML error pages): without this guard .[] yields nothing, `length` sees
      # <100, the loop breaks, and the run reports success with ZERO repos
      # processed — a phantom green that silently stops all mirror creation.
      gh_list_guard() {
        if ! echo "$1" | jq -e 'type == "array"' > /dev/null; then
          echo "Error: $2 did not return an array:"
          echo "$1" | jq -r '.message // tostring' 2>/dev/null | head -3
          exit 1
        fi
      }

      echo "Fetching repositories for GitHub user: $GITHUB_USER (owned, public+private)"

      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user/repos?visibility=all&affiliation=owner&per_page=100&page=$page")
        gh_list_guard "$response" "GitHub repo listing (page $page)"
        echo "$response" | jq -r --arg owner "$FORGEJO_OWNER" \
          '.[] | "\($owner)|\(.name)|\(.clone_url)|\(.private)|\(.description // "")"' >> "$REPOS_FILE"
        [[ $(echo "$response" | jq 'length') -lt 100 ]] && break
        page=$((page + 1))
      done

      # ALL orgs the token can see (owner directive 2026-10-02: full backups
      # include every org). Each org mirrors into a same-named forgejo org
      # namespace; private org repos appear when the token has access.
      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user/orgs?per_page=100&page=$page")
        gh_list_guard "$response" "GitHub org listing (page $page)"
        echo "$response" | jq -r '.[].login' >> "$ORGS_FILE"
        [[ $(echo "$response" | jq 'length') -lt 100 ]] && break
        page=$((page + 1))
      done
      sort -u -o "$ORGS_FILE" "$ORGS_FILE"

      while read -r org; do
        [[ -z "$org" ]] && continue
        echo "Fetching repositories for GitHub org: $org"
        page=1
        while true; do
          response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/orgs/$org/repos?type=all&per_page=100&page=$page")
          gh_list_guard "$response" "GitHub org repo listing: $org (page $page)"
          echo "$response" | jq -r --arg owner "$org" \
            '.[] | "\($owner)|\(.name)|\(.clone_url)|\(.private)|\(.description // "")"' >> "$REPOS_FILE"
          [[ $(echo "$response" | jq 'length') -lt 100 ]] && break
          page=$((page + 1))
        done
      done < "$ORGS_FILE"

      FAILED=0

      # The migrate endpoint is uid-keyed: resolve the forgejo user's uid once.
      FJ_USER_UID=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
        "$FORGEJO_URL/api/v1/user" | jq -r '.id // empty' 2>/dev/null)
      if [[ ! "$FJ_USER_UID" =~ ^[0-9]+$ ]]; then
        echo "Error: could not resolve forgejo user id via $FORGEJO_URL/api/v1/user"
        exit 1
      fi

      # org create-if-missing; echoes the org's numeric forgejo id, or fails.
      # A transient org-GET failure is self-healing: the create POST 422s
      # (already exists) and the re-GET then resolves the id.
      ensure_org() {
        local org="$1" org_id code
        org_id=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/orgs/$org" | jq -r '.id // empty' 2>/dev/null)
        # NOTE: progress output MUST go to stderr — the caller captures this
        # function's stdout as the numeric org id.
        if [[ ! "$org_id" =~ ^[0-9]+$ ]]; then
          code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
            -H "Authorization: token $FORGEJO_TOKEN" \
            -H "Content-Type: application/json" \
            "$FORGEJO_URL/api/v1/orgs" \
            -d "$(jq -n --arg u "$org" '{username: $u}')")
          if [[ "$code" == "200" || "$code" == "201" ]]; then
            echo "  + Created forgejo org: $org" >&2
            org_id=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
              "$FORGEJO_URL/api/v1/orgs/$org" | jq -r '.id // empty' 2>/dev/null)
          else
            echo "  ✗ Failed to create forgejo org $org (HTTP $code)" >&2
            return 1
          fi
        fi
        [[ "$org_id" =~ ^[0-9]+$ ]] || return 1
        echo "$org_id"
      }

      while IFS='|' read -r dest name clone_url private description; do
        [[ -z "$name" ]] && continue

        existing=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/repos/$dest/$name")

        if [[ "$existing" == "200" ]]; then
          echo "✓ Already mirrored: $dest/$name"
          continue
        fi

        dest_uid="$FJ_USER_UID"
        if [[ "$dest" != "$FORGEJO_OWNER" ]]; then
          if ! dest_uid=$(ensure_org "$dest"); then
            echo "  ✗ Failed (org unavailable): $dest/$name"
            FAILED=$((FAILED + 1))
            continue
          fi
        fi

        # Clear any orphan git dir left by an interrupted migrate (past OOM/crash).
        # This is safe: the GET above confirmed the repo has NO DB record, so the
        # endpoint can only touch unadopted on-disk dirs, never a registered repo.
        # 204 = orphan deleted, 404 = no orphan existed (normal for never-migrated repos).
        curl -s -o /dev/null -X DELETE \
          -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/admin/unadopted/$dest/$name"

        echo "→ Mirroring: $dest/$name"

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
            --arg uid "$dest_uid" \
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
          echo "  ✓ Created mirror: $dest/$name"
        else
          echo "  ✗ Failed (HTTP $code): $dest/$name"
          FAILED=$((FAILED + 1))
        fi
      done < "$REPOS_FILE"

      count=$(wc -l < "$REPOS_FILE")
      org_count=$(awk -F'|' -v owner="$FORGEJO_OWNER" '$1 != owner' "$REPOS_FILE" | wc -l)
      echo "✓ Done! $count repos processed ($((count - org_count)) user + $org_count org), $FAILED failed"

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
      ORGS=$(mktemp)
      FJMIRRORS=$(mktemp)
      STALE=$(mktemp)
      DELETED=$(mktemp)
      TRANSFERRED=$(mktemp)
      PENDING_NEW=$(mktemp)
      PENDING_TMP=$(mktemp)
      trap 'rm -f "$CANONICAL" "$ORGS" "$FJMIRRORS" "$STALE" "$DELETED" "$TRANSFERRED" "$PENDING_NEW" "$PENDING_TMP"' EXIT

      echo "=== Forgejo mirror reconciliation (owner: $GITHUB_USER) ==="

      # 1. Canonical GitHub owner/name pairs — user repos + ALL org repos
      # (the mirror script's listing sources; org-inclusive since 2026-10-02).
      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user/repos?visibility=all&affiliation=owner&per_page=100&page=$page")
        n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end') || n=""
        [[ -z "$n" || "$n" == "-1" ]] && { echo "Error: GitHub listing failed: $(echo "$response" | jq -r '.message // "unknown"')"; exit 1; }
        echo "$response" | jq -r '.[] | "\(.owner.login)/\(.name)"' | tr '[:upper:]' '[:lower:]' >> "$CANONICAL"
        [[ "$n" -lt 100 ]] && break
        page=$((page + 1))
      done

      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user/orgs?per_page=100&page=$page")
        n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end') || n=""
        [[ -z "$n" || "$n" == "-1" ]] && { echo "Error: GitHub org listing failed: $(echo "$response" | jq -r '.message // "unknown"')"; exit 1; }
        echo "$response" | jq -r '.[].login' | tr '[:upper:]' '[:lower:]' >> "$ORGS"
        [[ "$n" -lt 100 ]] && break
        page=$((page + 1))
      done
      sort -u -o "$ORGS" "$ORGS"

      while read -r org; do
        [[ -z "$org" ]] && continue
        page=1
        while true; do
          response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/orgs/$org/repos?type=all&per_page=100&page=$page")
          n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end') || n=""
          [[ -z "$n" || "$n" == "-1" ]] && { echo "Error: GitHub org repo listing failed ($org): $(echo "$response" | jq -r '.message // "unknown"')"; exit 1; }
          echo "$response" | jq -r --arg org "$org" '.[] | "\($org)/\(.name)"' | tr '[:upper:]' '[:lower:]' >> "$CANONICAL"
          [[ "$n" -lt 100 ]] && break
          page=$((page + 1))
        done
      done < "$ORGS"
      sort -u -o "$CANONICAL" "$CANONICAL"

      # 2. Forgejo pull mirrors, as GitHub-style owner/name pairs: the user
      # namespace maps to $GITHUB_USER, every mirrored org namespace keeps
      # its org login. Out-of-scope namespaces (e.g. the local `starred` org
      # whose upstreams are strangers' repos by design) are skipped and
      # counted, never reconciled.
      skipped_out_of_scope=0
      page=1
      while true; do
        response=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/user/repos?limit=50&page=$page")
        n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end') || n=""
        [[ -z "$n" || "$n" == "-1" ]] && { echo "Error: Forgejo listing failed: $(echo "$response" | jq -r '.message // "unknown"')"; exit 1; }
        while IFS=$'\t' read -r login name; do
          [[ -z "$login" ]] && continue
          if [[ "''${login,,}" == "''${FORGEJO_OWNER,,}" ]]; then
            echo "$GITHUB_USER/$name" >> "$FJMIRRORS"
          elif grep -qixF "$login" "$ORGS"; then
            echo "$login/$name" >> "$FJMIRRORS"
          else
            skipped_out_of_scope=$((skipped_out_of_scope + 1))
          fi
        done < <(echo "$response" | jq -r '.[] | select(.mirror == true) | "\(.owner.login)\t\(.name)"')
        [[ "$n" -lt 50 ]] && break
        page=$((page + 1))
      done

      total=$(wc -l < "$FJMIRRORS")

      # 3. Stale = forgejo pairs no longer canonical upstream.
      sort -u -o "$FJMIRRORS" "$FJMIRRORS"
      comm -23 <(tr '[:upper:]' '[:lower:]' < "$FJMIRRORS" | sort -u) "$CANONICAL" > "$STALE"
      stale_count=$(wc -l < "$STALE")

      # 4. Classify each stale pair by probing its (old) GitHub path.
      # gh api prints HTTP error BODIES to stdout even on failure (live-proven
      # 2026-09-18: every 404 leaked {"message":"Not Found",...} into $probe and
      # upstream-deleted repos misclassified as "transferred" with a garbage
      # owner). Trust the EXIT CODE plus an owner/name shape check, never the
      # captured stdout alone.
      # pending-deletes.txt switched to owner/name PAIRS 2026-10-02; the live
      # file was empty (0 pending) at the switch, any legacy flat name simply
      # never matches a pair and ages out — pending only gates deletes, never
      # causes them.
      : > "$PENDING_NEW"
      while read -r lower_pair; do
        # recover the original-case forgejo pair for API calls
        pair=$(grep -ixF "$lower_pair" "$FJMIRRORS" | head -1)
        gh_owner="''${pair%%/*}"
        name="''${pair##*/}"
        # errexit-safe: a 404/network failure must not kill the loop
        rc=0
        probe=$(gh api "repos/$gh_owner/$name" --jq .full_name 2>/dev/null) || rc=$?
        if [[ "$rc" -eq 0 && "$probe" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
          :
        elif [[ "$rc" -eq 0 ]]; then
          # exit 0 but no owner/name shape (jq oddity) — never classify on garbage
          echo "  unresolved probe (will retry): $pair (raw: ''${probe:0:60})"
          continue
        else
          # gh HTTP/network error — 404 is the overwhelmingly common case here
          # (the pair is already absent from the listing). A rare network blip
          # misclassifies as archived for ONE report-only run; next run heals.
          echo "$pair" >> "$DELETED"
          continue
        fi
        up_owner="''${probe%%/*}"
        up_name="''${probe##*/}"
        if [[ "''${up_owner,,}" == "''${gh_owner,,}" ]]; then
          if grep -qxF "''${up_owner,,}/''${up_name,,}" "$CANONICAL" && grep -ixF "$up_owner/$up_name" "$FJMIRRORS" &>/dev/null; then
            # canonical-named mirror already exists → stale copy is redundant.
            # Two-run confirmation: delete only when the verdict repeats.
            if grep -qxF "$lower_pair" "$PENDING"; then
              # forgejo-side owner: user namespace maps back to FORGEJO_OWNER
              if [[ "''${gh_owner,,}" == "''${GITHUB_USER,,}" ]]; then
                fj_owner="$FORGEJO_OWNER"
              else
                fj_owner="$gh_owner"
              fi
              is_mirror=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
                "$FORGEJO_URL/api/v1/repos/$fj_owner/$name" | jq -r '.mirror // false')
              if [[ "$is_mirror" == "true" ]]; then
                code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
                  -H "Authorization: token $FORGEJO_TOKEN" \
                  "$FORGEJO_URL/api/v1/repos/$fj_owner/$name")
                if [[ "$code" == "204" || "$code" == "200" ]]; then
                  echo "  healed rename: deleted stale '$pair' (canonical '$up_owner/$up_name' mirrored)"
                else
                  echo "  FAILED to delete stale '$pair' (HTTP $code) — kept"
                  echo "$lower_pair" >> "$PENDING_NEW"
                fi
              else
                echo "  refusing to delete '$pair': no longer a pull mirror"
              fi
              grep -vxF "$lower_pair" "$PENDING" > "$PENDING_TMP" || true
              mv "$PENDING_TMP" "$PENDING"
            else
              echo "  rename confirmed (1st pass, will delete next run): $pair → $up_owner/$up_name"
              echo "$lower_pair" >> "$PENDING_NEW"
            fi
          else
            # canonical mirror not created yet — the mirror phase creates it; reset any pending verdict
            echo "  rename pending creation: $pair → $up_owner/$up_name"
            grep -vxF "$lower_pair" "$PENDING" > "$PENDING_TMP" || true
            mv "$PENDING_TMP" "$PENDING"
          fi
        else
          echo "$pair ($probe)" >> "$TRANSFERRED"
        fi
      done < "$STALE"
      mv "$PENDING_NEW" "$PENDING"

      # Persist the stale set for the dead-mirror collector
      # (forgejo-mirror-health). known-stale.txt stays FLAT-NAMED because the
      # collector greps flat names from notice paths — a same-named live repo
      # in another namespace suppresses that name's dead-candidate count
      # (superset semantics, accepted). The pair file carries full fidelity.
      # Atomic writes: the 5-min collector may read concurrently.
      stale_tmp=$(mktemp "$STATE_DIR/known-stale.XXXXXX")
      sort -u "$STALE" | cut -d/ -f2 > "$stale_tmp"
      mv "$stale_tmp" "$STATE_DIR/known-stale.txt"
      stale_tmp=$(mktemp "$STATE_DIR/known-stale.XXXXXX")
      sort -u "$STALE" > "$stale_tmp"
      mv "$stale_tmp" "$STATE_DIR/known-stale-pairs.txt"

      org_mirrors=$(awk -F'/' -v u="''${GITHUB_USER,,}" 'tolower($1) != u' "$FJMIRRORS" | wc -l)

      echo "=== Reconcile summary ==="
      echo "forgejo pull mirrors: $total ($org_mirrors in org namespaces, $skipped_out_of_scope out-of-scope skipped)"
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
        echo "forgejo_mirror_org_mirrors $org_mirrors"
        echo "forgejo_mirror_stale_names $stale_count"
        echo "forgejo_mirror_upstream_deleted_archived $(wc -l < "$DELETED")"
        echo "forgejo_mirror_transferred $(wc -l < "$TRANSFERRED")"
        echo "forgejo_mirror_pending_deletes $(wc -l < "$PENDING")"
        echo "forgejo_mirror_reconcile_last_run_timestamp $(date +%s)"
      } | publish_prom
    '';
  };

  # Converger: PATCHes every pull mirror's sync interval to
  # FORGEJO_TARGET_INTERVAL (default 2h). mirror.DEFAULT_INTERVAL only
  # applies at mirror-CREATION time, so pre-existing mirrors keep their old
  # 8h forever until this pass rewrites them (461 mirrors verified at
  # 8h0m0s live 2026-10-12, one with an empty interval). Idempotent: repos
  # already at the target are counted, never PATCHed — a converged run is
  # ~470 localhost GETs, seconds. Also normalizes the empty-interval
  # mirror (Go duration "" parses to 0 seconds = a PATCH target).
  reintervalScript = pkgs.writeShellApplication {
    name = "forgejo-reinterval-mirrors";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ];
    text = ''
      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      TARGET_INTERVAL="''${FORGEJO_TARGET_INTERVAL:-2h}"

      if [[ -z "$FORGEJO_TOKEN" ]]; then
        echo "Error: FORGEJO_TOKEN not set (is forgejo-generate-token.service healthy?)"
        exit 1
      fi

      # Go duration strings ("8h0m0s", "30m0s", "2h", "") → seconds.
      dur_sec() {
        local d=$1 h=0 m=0 s=0
        [[ "$d" =~ ([0-9]+)h ]] && h=''${BASH_REMATCH[1]}
        [[ "$d" =~ ([0-9]+)m ]] && m=''${BASH_REMATCH[1]}
        [[ "$d" =~ ([0-9]+)s ]] && s=''${BASH_REMATCH[1]}
        echo $((10#$h * 3600 + 10#$m * 60 + 10#$s))
      }
      target_sec=$(dur_sec "$TARGET_INTERVAL")
      if [[ "$target_sec" -eq 0 ]]; then
        echo "Error: FORGEJO_TARGET_INTERVAL='$TARGET_INTERVAL' parses to 0 seconds"
        exit 1
      fi

      echo "=== Forgejo mirror re-interval (target: $TARGET_INTERVAL) ==="

      checked=0
      patched=0
      already=0
      failed=0
      page=1
      while true; do
        response=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" \
          "$FORGEJO_URL/api/v1/user/repos?limit=50&page=$page")
        # Fail loud on non-array listings (rate limit / auth): the same
        # phantom-green guard as reconcile — without it a failed listing
        # "succeeds" having checked zero mirrors.
        if ! echo "$response" | jq -e 'type == "array"' > /dev/null; then
          echo "Error: Forgejo listing (page $page) did not return an array:"
          echo "$response" | jq -r '.message // tostring' 2>/dev/null | head -3
          exit 1
        fi
        while IFS=$'\t' read -r owner name cur; do
          [[ -z "$owner" ]] && continue
          checked=$((checked + 1))
          if [[ "$(dur_sec "$cur")" -eq "$target_sec" ]]; then
            already=$((already + 1))
            continue
          fi
          code=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH \
            -H "Authorization: token $FORGEJO_TOKEN" \
            -H 'Content-Type: application/json' \
            -d "{\"mirror_interval\":\"$TARGET_INTERVAL\"}" \
            "$FORGEJO_URL/api/v1/repos/$owner/$name")
          if [[ "$code" == "200" ]]; then
            echo "  $owner/$name: '$cur' -> $TARGET_INTERVAL"
            patched=$((patched + 1))
          else
            echo "  warn: PATCH $owner/$name failed (HTTP $code) — retried next run"
            failed=$((failed + 1))
          fi
        done < <(echo "$response" | jq -r '.[] | select(.mirror == true) | "\(.owner.login)\t\(.name)\t\(.mirror_interval // "")"')
        [[ $(echo "$response" | jq 'length') -lt 50 ]] && break
        page=$((page + 1))
      done

      echo "=== Re-interval summary: checked=$checked patched=$patched already-at-target=$already failed=$failed"
      # Fail loud AFTER the full pass: a transient PATCH 5xx must not skip
      # the remaining repos; the next hourly timer run retries the misses.
      [[ "$failed" -eq 0 ]]
    '';
  };

  # Avatar parity sync (GitHub -> Forgejo), phase 4 of forgejo-github-sync.
  #
  # WHY: mirror-github creates orgs create-if-missing with {username} only, so
  # every forgejo org wears the default generated avatar while its GitHub twin
  # has the real one. This phase converges the USER + ORG avatars so the
  # mirror instance reads like the GitHub account it backs up.
  #
  # CONTRACT (verified against the deployed swagger.v1.json, Forgejo 15.0.10):
  #   POST /orgs/{org}/avatar  body {"image": base64} -> 204 (orgUpdateAvatar)
  #   POST /user/avatar        body {"image": base64} -> 204 (userUpdateAvatar)
  #   GitHub /user and /user/orgs responses both carry avatar_url.
  #
  # CONVERGENCE: stateless byte-compare — hash the GitHub avatar bytes and the
  # bytes currently served at the forgejo target's avatar_url; skip when equal
  # (forgejo stores uploads verbatim, so run 2 goes quiet; if forgejo ever
  # re-encodes, the worst case is one idempotent re-upload per target per run).
  # No state file, no drift: a manual UI avatar change is re-converged hourly.
  #
  # The USER side overlaps the OIDC flow (oauth2_client.UPDATE_AVATAR=true
  # rewrites the user avatar from the Pocket ID picture claim on every SSO
  # login — same face, different source). OWNER DECISION 2026-10-16: OIDC >
  # GitHub for the user avatar — the default is FORGEJO_AVATAR_SYNC_USER=false
  # (Pocket ID owns it); set =true to opt the user back into GitHub sync.
  # Orgs are unaffected by the flag and are the reason this phase exists.
  avatarSyncScript = pkgs.writeShellApplication {
    name = "forgejo-avatar-sync";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      FORGEJO_URL="${forgejoUrl}"
      FORGEJO_TOKEN="''${FORGEJO_TOKEN:-}"
      GITHUB_TOKEN="''${GITHUB_TOKEN:-}"
      GITHUB_USER="''${GITHUB_USER:-unknown}"
      TEXTFILE_DIR="''${FORGEJO_AVATAR_TEXTFILE_DIR:-/var/lib/prometheus-node-exporter/textfile_collectors}"
      # Default false (owner decision 2026-10-16): Pocket ID owns the user
      # avatar via the OIDC picture claim; orgs always sync from GitHub.
      SYNC_USER="''${FORGEJO_AVATAR_SYNC_USER:-false}"

      if [[ -z "$FORGEJO_TOKEN" || -z "$GITHUB_TOKEN" ]]; then
        echo "Error: FORGEJO_TOKEN / GITHUB_TOKEN must both be set"
        exit 1
      fi

      AVATAR_TMP=$(mktemp)
      # The GitHub bytes must survive the forgejo-side compare fetch: the
      # avatar_url GET overwrites AVATAR_TMP before push_avatar reads it
      # (upload-the-old-bytes-back bug, fixture-caught 2026-10-16).
      GH_AVATAR_TMP=$(mktemp)
      ORGS_FILE=$(mktemp)
      trap 'rm -f "$AVATAR_TMP" "$GH_AVATAR_TMP" "$ORGS_FILE"' EXIT

      # Fail loud on non-array listing responses (rate limit, auth failure):
      # the same phantom-green guard as every other GitHub-listing phase.
      gh_list_guard() {
        if ! echo "$1" | jq -e 'type == "array"' > /dev/null; then
          echo "Error: $2 did not return an array:"
          echo "$1" | jq -r '.message // tostring' 2>/dev/null | head -3
          exit 1
        fi
      }

      # $1=url $2=token -> bytes in $AVATAR_TMP. Empty/leftover files are the
      # caller's problem (checked via -s), never this function's.
      fetch_avatar() {
        curl -s -f -L --max-time 60 -H "Authorization: token $2" "$1" -o "$AVATAR_TMP"
      }

      # $1=forgejo api url (the GET url); the avatar POST endpoint is the
      # GET url + /avatar (/api/v1/user -> /api/v1/user/avatar, /api/v1/orgs/
      # <org> -> /api/v1/orgs/<org>/avatar). Bytes in $GH_AVATAR_TMP.
      # base64 -w0 first (NOT jq -Rs on the raw bytes: that embeds them
      # UNENCODED and chokes on binary PNG input); --rawfile then builds the
      # JSON without argv-size limits.
      push_avatar() {
        local api="$1/avatar" code json
        json=$(mktemp)
        base64 -w0 < "$GH_AVATAR_TMP" > "$GH_AVATAR_TMP.b64"
        jq -n --rawfile img "$GH_AVATAR_TMP.b64" '{image: $img}' > "$json"
        rm -f "$GH_AVATAR_TMP.b64"
        code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
          -H "Authorization: token $FORGEJO_TOKEN" \
          -H 'Content-Type: application/json' \
          --data-binary "@$json" \
          "$api")
        rm -f "$json"
        echo "$code"
      }

      targets=0
      uploaded=0
      in_sync=0
      failed=0
      skipped=0

      # $1=label $2=GitHub avatar_url $3=forgejo api url (GET .avatar_url /
      # POST avatar). Per-target failures WARN and count; the unit fails AFTER
      # the full pass so the next hourly run retries the misses.
      sync_one() {
        local label="$1" gh_url="$2" fj_api="$3"
        local gh_sha="" fj_url="" fj_sha="" code
        targets=$((targets + 1))
        if ! fetch_avatar "$gh_url" "$GITHUB_TOKEN" \
          || [[ ! -s "$AVATAR_TMP" ]] \
          || [[ $(wc -c < "$AVATAR_TMP") -gt 1048576 ]]; then
          echo "  warn: $label: GitHub avatar unavailable (network or >1MiB) — retried next run"
          failed=$((failed + 1))
          return 0
        fi
        gh_sha=$(sha256sum "$AVATAR_TMP" | cut -d' ' -f1) || gh_sha=""
        if [[ -z "$gh_sha" ]]; then
          echo "  warn: $label: hash failed — retried next run"
          failed=$((failed + 1))
          return 0
        fi
        cp "$AVATAR_TMP" "$GH_AVATAR_TMP"
        fj_url=$(curl -s -H "Authorization: token $FORGEJO_TOKEN" "$fj_api" \
          | jq -r '.avatar_url // empty' || true)
        if [[ -z "$fj_url" ]]; then
          # An org with nothing mirrored under it has no local twin (orgs are
          # created create-if-missing by the MIRROR phase, repo by repo) — the
          # avatar POST would 404 and fail the unit every hour for an org
          # that legitimately has nothing here (org:vonArtmann since
          # 2026-10-17, live-404-proven). Distinguish absent-target (skip,
          # converges automatically once a repo under it gets mirrored)
          # from a real push failure.
          local exists
          exists=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: token $FORGEJO_TOKEN" "$fj_api")
          if [[ "$exists" == "404" ]]; then
            echo "  skip: $label: no local twin (nothing mirrored under it) — avatar converges when one is"
            skipped=$((skipped + 1))
            return 0
          fi
        fi
        if [[ -n "$fj_url" ]] \
          && fetch_avatar "$fj_url" "$FORGEJO_TOKEN" \
          && [[ -s "$AVATAR_TMP" ]]; then
          fj_sha=$(sha256sum "$AVATAR_TMP" | cut -d' ' -f1) || fj_sha=""
          if [[ -n "$fj_sha" && "$fj_sha" == "$gh_sha" ]]; then
            in_sync=$((in_sync + 1))
            return 0
          fi
        fi
        code=$(push_avatar "$fj_api")
        if [[ "$code" == "204" ]]; then
          echo "  $label: avatar updated"
          uploaded=$((uploaded + 1))
        else
          echo "  warn: $label: avatar POST failed (HTTP $code) — retried next run"
          failed=$((failed + 1))
        fi
        return 0
      }

      publish_metrics() {
        if [[ ! -d "$TEXTFILE_DIR" ]]; then
          return 0
        fi
        local tmp
        tmp=$(mktemp "$TEXTFILE_DIR/forgejo_avatar_sync.XXXXXX") || return 0
        {
          echo "# TYPE forgejo_avatar_targets gauge"
          echo "forgejo_avatar_targets $targets"
          echo "# TYPE forgejo_avatar_uploaded gauge"
          echo "forgejo_avatar_uploaded $uploaded"
          echo "# TYPE forgejo_avatar_in_sync gauge"
          echo "forgejo_avatar_in_sync $in_sync"
          echo "# TYPE forgejo_avatar_failed gauge"
          echo "forgejo_avatar_failed $failed"
          echo "# TYPE forgejo_avatar_skipped gauge"
          echo "forgejo_avatar_skipped $skipped"
          echo "forgejo_avatar_last_run_timestamp_seconds $(date +%s)"
        } > "$tmp"
        chmod 644 "$tmp"
        mv "$tmp" "$TEXTFILE_DIR/forgejo_avatar_sync.prom" 2>/dev/null || {
          echo "  warn: cannot publish forgejo_avatar_sync.prom (foreign-owned leftover?)"
          rm -f "$tmp"
        }
      }

      echo "=== Forgejo avatar sync (GitHub -> Forgejo) ==="

      # Orgs come straight from the GitHub org listing — each entry already
      # carries avatar_url, no per-org GitHub GET needed.
      page=1
      while true; do
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user/orgs?per_page=100&page=$page")
        gh_list_guard "$response" "GitHub org listing (page $page)"
        echo "$response" | jq -r '.[] | "\(.login)|\(.avatar_url // "")"' >> "$ORGS_FILE"
        [[ $(echo "$response" | jq 'length') -lt 100 ]] && break
        page=$((page + 1))
      done
      sort -u -o "$ORGS_FILE" "$ORGS_FILE"

      while IFS='|' read -r org org_gh_url; do
        [[ -z "$org" || -z "$org_gh_url" ]] && continue
        sync_one "org:$org" "$org_gh_url" "$FORGEJO_URL/api/v1/orgs/$org"
      done < "$ORGS_FILE"

      if [[ "$SYNC_USER" == "false" || "$SYNC_USER" == "0" || "$SYNC_USER" == "no" ]]; then
        echo "User avatar sync skipped (FORGEJO_AVATAR_SYNC_USER=$SYNC_USER) — OIDC (Pocket ID) owns it"
      else
        response=$(curl -s --compressed -H "Authorization: token $GITHUB_TOKEN" \
          "https://api.github.com/user")
        USER_URL=$(echo "$response" | jq -r '.avatar_url // empty' || true)
        if [[ -z "$USER_URL" ]]; then
          echo "  warn: GitHub /user listing failed: $(echo "$response" | jq -r '.message // "unknown"' 2>/dev/null | head -1) — orgs already synced; retried next run"
          failed=$((failed + 1))
        else
          sync_one "user:$GITHUB_USER" "$USER_URL" "$FORGEJO_URL/api/v1/user"
        fi
      fi

      echo "=== Avatar sync summary: targets=$targets updated=$uploaded in-sync=$in_sync failed=$failed skipped=$skipped"
      publish_metrics
      # Fail loud AFTER the full pass (reinterval doctrine): the next hourly
      # timer run retries the misses.
      [[ "$failed" -eq 0 ]]
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
  # - A migrate that SUCCEEDS but lands wrong (e.g. the 2026-10-16
  #   eventcatalog-hub flip whose payload said service "git" and
  #   silently skipped issue/PR import) is NOT re-runnable: the repo
  #   is now native and the guard above refuses. Recovery = confirm
  #   GitHub still holds the missing data, delete the native repo via
  #   the API, let forgejo-mirror-github recreate the mirror, re-flip.
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
            service: "github"
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
      # GitHub's open_issues_count counts issues AND pull requests; Forgejo
      # splits the same population into open_issues_count (issues only) and
      # open_pr_counter. Compare like-for-like — a PR-only repo (0 real
      # issues) must not false-fail the verify AFTER a successful import
      # (gogenfilter flip 2026-10-25: 11 open PRs imported, script died here
      # and skipped the push-mirror attach).
      fj_issues=$(echo "$repo2" | jq -r '.open_issues_count')
      fj_prs=$(echo "$repo2" | jq -r '.open_pr_counter')
      if [[ "$gh_issues" -gt 0 && $((fj_issues + fj_prs)) -eq 0 ]]; then
        die "post-flip verify failed: GitHub had $gh_issues open issues+PRs but forgejo imported 0 (issues=$fj_issues prs=$fj_prs)"
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
        n=$(echo "$response" | jq -r 'if type == "array" then length else -1 end') || n="-1"
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
      pkgs.jq
    ];
    text = ''
      # Idempotent: create hermes-agent user (unprivileged, no UI login needed),
      # mint a write:repository-scoped token, grant write on every repo owned
      # by the primary user, stage the token for hermes delivery.
      #
      # Owner decision 2026-09-23: hermes-agent gets READ+WRITE on all
      # lars-owned forgejo repos (supersedes the 2026-08-19 read-only
      # bring-up). Repo-level deletion stays structurally impossible:
      # DELETE /repos/{owner}/{repo} requires OWNER/ADMIN on the repo, and a
      # write-role collaborator never has it. Within a repo, write DOES allow
      # branch/tag/file deletion and force-push — if that ever needs limiting,
      # per-repo branch protection rules are the lever.
      # NOT --restricted: restricted users cannot see other users' PUBLIC repos,
      # which would defeat the purpose. Least privilege here = normal user that
      # owns nothing + write:repository token + per-repo collaborator grants.
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

      # 2. token — reuse only when BOTH valid AND write-scoped; else mint.
      #    Scope is fixed at forgejo-token creation, so the 2026-09-23
      #    read->write upgrade is detected via a marker file next to the
      #    staged token: a missing/mismatched marker forces regeneration even
      #    though the old read-only token is still cryptographically valid.
      #    The validity probe MUST stay in the repository scope category:
      #    GET /api/v1/user requires the "user" scope (403 for a
      #    repository-only token), and GET /api/v1/user/repos requires
      #    BOTH user and repository categories (group middleware composes
      #    AND-style; verified against forgejo 15.0.6 routers/api/v1/api.go +
      #    modules/web/route.go). GET /api/v1/repos/search sits in the
      #    repository-scoped group only: 200 for this token, 401 once revoked
      #    (invalid tokens are rejected by the auth middleware before routing).
      #    NO early exit on the valid path: the collaborator sweep below must
      #    run on EVERY run so newly created repos converge.
      WANT_SCOPE=write:repository,write:user  # 2026-10-16 owner decision: +write:user so hermes-agent can sync its own avatar
      SCOPE_MARKER=${stateDir}/hermes-agent.token.scope
      MARKER_SCOPE=""
      if [ -f "$SCOPE_MARKER" ]; then
        MARKER_SCOPE=$(cat "$SCOPE_MARKER")
      fi

      NEED_MINT=1
      if [ -s "$STAGED_TOKEN_FILE" ]; then
        CANDIDATE=$(cat "$STAGED_TOKEN_FILE")
        if [ "$MARKER_SCOPE" != "$WANT_SCOPE" ]; then
          echo "Existing token scope is ''${MARKER_SCOPE:-UNSET}, want '$WANT_SCOPE'; regenerating (owner decision 2026-09-23)"
        elif curl -sf --connect-timeout 3 --max-time 10 \
          -H "Authorization: token $CANDIDATE" \
          "${forgejoUrl}/api/v1/repos/search?limit=1" >/dev/null 2>&1; then
          echo "Existing hermes-agent token still valid ($WANT_SCOPE)"
          NEED_MINT=0
        else
          echo "Existing token invalid; regenerating"
        fi
      fi

      if [ "$NEED_MINT" -eq 1 ]; then
        TOKEN=$("$FORGEJO" admin user generate-access-token \
          --username "$FORGEJO_USER_NAME" \
          --token-name "hermes-agent-$(date +%s)" \
          --scopes "$WANT_SCOPE" \
          --raw) || TOKEN=""

        if ! echo "$TOKEN" | grep -qE '^[0-9a-f]{40}$'; then
          echo "ERROR: token generation failed for hermes-agent" >&2
          exit 1
        fi

        # 3. stage forgejo-only; ExecStartPost installs the hermes copy at
        #    /run/hermes-forgejo-token (0400 hermes:hermes, tmpfs)
        #    Atomic install: the existing 0400 file is read-only even for the
        #    forgejo owner, so a bare redirect would EACCES on regeneration.
        #    The scope marker rides the same mktemp (NOT a secret — readable).
        TMP_TOKEN_FILE=$(mktemp "$STAGED_TOKEN_FILE.XXXXXX")
        trap 'rm -f "$TMP_TOKEN_FILE"' EXIT
        printf '%s' "$TOKEN" > "$TMP_TOKEN_FILE"
        install -m 0400 "$TMP_TOKEN_FILE" "$STAGED_TOKEN_FILE"
        printf '%s' "$WANT_SCOPE" > "$TMP_TOKEN_FILE"
        install -m 0444 "$TMP_TOKEN_FILE" "$SCOPE_MARKER"
        rm -f "$TMP_TOKEN_FILE"
        trap - EXIT
        echo "hermes-agent token staged at $STAGED_TOKEN_FILE (scope: $WANT_SCOPE)"
      fi

      # 4. grant write on every repo owned by the primary user (converger:
      #    this unit re-runs on boot + every deploy, so NEW repos pick up
      #    the grant automatically). Personal repos cannot be bulk-shared
      #    in forgejo — the per-repo collaborator PUT is the only mechanism
      #    (org teams would need a repo migration; org-owned repos are
      #    deliberately out of scope). Uses the primary user's provisioning
      #    token (forgejo-generate-token, --scopes all); the unit already
      #    orders after that service. PUT /repos/{owner}/{repo}/collaborators/
      #    hermes-agent is idempotent (200/204). Mirror repos reject pushes
      #    at the forgejo level, so the grant is inert there. Listing
      #    failure is SYSTEMIC -> exit 1 (OnFailure pages). Per-repo failures
      #    WARN (github-auto-assign threshold doctrine): only a 100%-failure
      #    sweep counts as systemic.
      ADMIN_TOKEN_FILE=${stateDir}/.admin-token.env
      LARS_TOKEN=""
      if [ -f "$ADMIN_TOKEN_FILE" ]; then
        LARS_TOKEN=$(grep -E '^FORGEJO_TOKEN=[0-9a-f]{40}$' "$ADMIN_TOKEN_FILE" | cut -d= -f2) || LARS_TOKEN=""
      fi
      if [ -z "$LARS_TOKEN" ]; then
        echo "ERROR: primary-user API token missing/invalid at $ADMIN_TOKEN_FILE — forgejo-generate-token must have run first" >&2
        exit 1
      fi

      GRANTED=0
      FAILED=0
      page=1
      while :; do
        REPOS_JSON=$(curl -sf --connect-timeout 3 --max-time 20 \
          -H "Authorization: token $LARS_TOKEN" \
          "${forgejoUrl}/api/v1/user/repos?type=owner&limit=50&page=$page") || {
          echo "ERROR: repo listing failed (page $page) — API token lacks scope or forgejo is degraded" >&2
          exit 1
        }
        COUNT=$(printf '%s' "$REPOS_JSON" | jq 'length')
        if [ "$COUNT" -eq 0 ]; then break; fi
        mapfile -t REPO_NAMES < <(printf '%s' "$REPOS_JSON" | jq -r '.[].full_name')
        for fn in "''${REPO_NAMES[@]}"; do
          code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 20 \
            -X PUT \
            -H "Authorization: token $LARS_TOKEN" \
            -H 'Content-Type: application/json' \
            -d '{"permission":"write"}' \
            "${forgejoUrl}/api/v1/repos/$fn/collaborators/hermes-agent") || code="000"
          case "$code" in
            200|204) GRANTED=$((GRANTED + 1)) ;;
            *)
              FAILED=$((FAILED + 1))
              echo "WARN: collaborator grant failed for $fn (HTTP $code)" >&2
              ;;
          esac
        done
        page=$((page + 1))
      done
      echo "Collaborator sweep: $GRANTED repo(s) granted/confirmed, $FAILED failure(s)"
      if [ "$GRANTED" -eq 0 ] && [ "$FAILED" -gt 0 ]; then
        echo "ERROR: every collaborator grant failed — systemic misconfiguration (token scope? API downgrade?)" >&2
        exit 1
      fi
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
      # STATE_DIRECTORY is a colon-joined LIST since nixpkgs 55bfb4d (the
      # gitea-actions-runner module now declares StateDirectory =
      # [ "gitea-runner" "gitea-runner/<name>" ]); the naive
      # "$STATE_DIRECTORY/${hostName}" interpolation produced the bogus path
      # /var/lib/gitea-runner:/… (mkdir EROFS in the sandboxed ExecStartPre,
      # 5 rapid failures → start-limit-hit, 2026-10-15 20:10 switch). Take
      # the FIRST list entry — the instance dir lives under it, matching the
      # module's own WorkingDirectory = /var/lib/gitea-runner/<name>.
      export INSTANCE_DIR="''${STATE_DIRECTORY%%:*}/${hostName}"
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
