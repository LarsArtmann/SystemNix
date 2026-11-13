#!/usr/bin/env bash
# check-contact-registry-drift.sh — advisory drift check for the contacts
# registry (T19, the 2026-11-13 contacts-data-architecture plan).
#
# The registry (docs/agents/data-ownership.md "Contact surfaces") is the ONE
# classification of every contacts surface in the fleet. Two silent drift
# classes killed surfaces before (the homepage-merge tile class, the stale
# "unexamined fourth surface" gap); this check names them mechanically:
#
#   1. BANNED DAV SERVER FAMILY in eval-reachable Nix (modules/, platforms/,
#      systems/, overlays/): services.radicale / baikal / davical /
#      sabredav — invariant 3 ("no second DAV endpoint") made greppable. A
#      docs MENTION (the registry's own banned-by-decision line, plans,
#      gotchas) is exempt — the scan reads eval modules only.
#   2. REGISTRY ROW LOSS: every known contacts-surface module name must
#      still appear in the registry file. A row deleted or renamed away
#      without a matching registry edit is exactly the silent-classification
#      loss this check exists for.
#
# ADVISORY by design (plan T19.2): exits 0 with WARN lines, exit 1 only
# with --strict. Wire-in point: pre-deploy-check.sh runs it WARN-first;
# promoting to a blocker is an owner decision after a quarantine window.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

REGISTRY="docs/agents/data-ownership.md"
strict=0
[[ "${1:-}" == "--strict" ]] && strict=1

drifts=0

warn() {
	echo "WARN: contact-registry drift: $1"
	drifts=$((drifts + 1))
}

# ── 1. the banned DAV server family in eval modules ────────────────────
while IFS= read -r match; do
	[[ -z "$match" ]] && continue
	warn "banned DAV server family referenced in eval module: $match (registry invariant 3)"
done < <(grep -rilE 'services\.(radicale|baikal|davical|sabredav)\b' modules/ platforms/ systems/ overlays/ 2>/dev/null)

# ── 2. every known surface module name still classified ───────────────
# The registry's own row names (lowercased module stems). A missing name
# means the registry lost its classification of that surface.
known_surfaces=(
	"pim-sync"
	"crm"
	"webphone"
	"inboxclean"
	"paperless"
	"opencloud"
	"stalwart"
)

for surface in "${known_surfaces[@]}"; do
	if ! grep -qi "$surface" "$REGISTRY"; then
		warn "registry no longer classifies surface '$surface' (docs/agents/data-ownership.md lost its row?)"
	fi
done

# ── verdict ─────────────────────────────────────────────────────────────
if ((drifts > 0)); then
	echo "contact-registry drift: $drifts finding(s)"
	((strict == 1)) && exit 1
	echo "(advisory — rerun with --strict to fail; promotion to blocker is an owner decision)"
	exit 0
fi

echo "contact-registry drift: clean"
exit 0
