#!/usr/bin/env bash
# forgejo-attach-org-push-mirrors.sh — attach outbound GitHub push mirrors
# to the NATIVE forgejo repos that correspond to a GitHub ORG's repositories.
#
# WHY THIS EXISTS: the declarative push-mirror phase (forgejo-github-sync
# phase 3, services.forgejo.canonicalRepos in _forgejo-scripts.nix) hardcodes
# the remote as $GITHUB_USER/<name> and cannot target an org namespace. Org
# repos canonical on forgejo get their GitHub backup mirror attached by this
# script instead.
#
# NAME-LEAK DELIBERATE (do not "fix"): the repo list is enumerated at RUNTIME
# from the GitHub org API + forgejo API. NO repo names and NO org name are
# hardcoded in this file — org repo names are private and this script is
# tracked in a PUBLIC repo. Pass the org as an argument.
#
# Idempotent: repos that already have a push mirror are skipped; repos that
# are still PULL mirrors are refused loudly (flip them native first — see
# forgejo-flip@<name>.service).
#
# USAGE:
#   GITHUB_TOKEN=$(gh auth token) bash scripts/forgejo-attach-org-push-mirrors.sh <github-org> [forgejo-owner]
#
# Example (org elided deliberately):
#   GITHUB_TOKEN=$(gh auth token) bash scripts/forgejo-attach-org-push-mirrors.sh <org> lars
#
# Mirrors attached with: interval 8h, sync_on_commit, initial sync triggered.
# The GitHub PAT is stored by forgejo as the push remote's credential — the
# same secret class forgejo already holds for pull migrations.
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "usage: GITHUB_TOKEN=\$(gh auth token) bash $0 <github-org> [forgejo-owner]" >&2
	exit 1
fi

GITHUB_ORG="$1"
FORGEJO_OWNER="${2:-lars}"
FORGEJO_URL="http://localhost:3000"
TOKEN_FILE="/var/lib/forgejo/.admin-token.env"

if [[ $EUID -ne 0 ]]; then
	exec sudo -n env GITHUB_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN must be passed through env}" bash "$0" "$@"
fi

export PATH="/run/current-system/sw/bin:$PATH"

LARS_TOKEN=$(grep -E '^FORGEJO_TOKEN=[0-9a-f]{40}$' "$TOKEN_FILE" | cut -d= -f2)
[[ -n "$LARS_TOKEN" ]] || { echo "ERROR: forgejo token missing at $TOKEN_FILE (forgejo-generate-token.service healthy?)" >&2; exit 1; }
[[ -n "${GITHUB_TOKEN:-}" ]] || { echo "ERROR: GITHUB_TOKEN not passed (run via: GITHUB_TOKEN=\$(gh auth token) bash $0 …)" >&2; exit 1; }

GITHUB_PAT_OWNER=$(curl -sf -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/user" | jq -r '.login')
[[ -n "$GITHUB_PAT_OWNER" && "$GITHUB_PAT_OWNER" != "null" ]] || { echo "ERROR: could not resolve GitHub PAT owner" >&2; exit 1; }

# Runtime enumeration — page through the org's repos (100/page covers orgs
# up to that size; extend with ?page=N if ever needed).
mapfile -t REPOS < <(curl -sf -H "Authorization: token $GITHUB_TOKEN" \
	"https://api.github.com/orgs/$GITHUB_ORG/repos?per_page=100" \
	| jq -r '.[].name' | sort)
[[ ${#REPOS[@]} -gt 0 ]] || { echo "ERROR: no repos enumerated for org '$GITHUB_ORG' (token lacks org access?)" >&2; exit 1; }

echo "=== Attaching push mirrors: org=$GITHUB_ORG forgejo-owner=$FORGEJO_OWNER repos=${#REPOS[@]} pat-owner=$GITHUB_PAT_OWNER ==="

FAILED=0
for name in "${REPOS[@]}"; do
	repo=$(curl -sf -H "Authorization: token $LARS_TOKEN" "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name") || {
		echo "✗ $name: not found on forgejo (create/push it natively first)"
		FAILED=1
		continue
	}
	if [[ "$(echo "$repo" | jq -r '.mirror')" == "true" ]]; then
		echo "✗ $name: still a PULL mirror — refusing (flip first: sudo systemctl start forgejo-flip@$name.service)"
		FAILED=1
		continue
	fi
	existing=$(curl -sf -H "Authorization: token $LARS_TOKEN" "$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" | jq 'length') || existing=0
	if [[ "$existing" != "0" ]]; then
		echo "✓ $name: push mirror already attached"
		continue
	fi
	code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
		-H "Authorization: token $LARS_TOKEN" -H "Content-Type: application/json" \
		"$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors" \
		-d "$(jq -n \
			--arg remote "https://github.com/$GITHUB_ORG/$name.git" \
			--arg username "$GITHUB_PAT_OWNER" \
			--arg password "$GITHUB_TOKEN" \
			'{remote_address: $remote, remote_username: $username, remote_password: $password, interval: "8h", sync_on_commit: true}')")
	if [[ "$code" == "200" || "$code" == "201" ]]; then
		sync_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
			-H "Authorization: token $LARS_TOKEN" \
			"$FORGEJO_URL/api/v1/repos/$FORGEJO_OWNER/$name/push_mirrors-sync" || echo "000")
		echo "✓ $name: attached (sync trigger HTTP $sync_code)"
	else
		echo "✗ $name: attach failed HTTP $code"
		FAILED=1
	fi
done

echo "=== Done (failures: $FAILED) ==="
exit "$FAILED"
