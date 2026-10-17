#!/usr/bin/env bash
# catalog-inventory.sh — export the full platform service inventory as JSON
# for the federated EventCatalog (catalog.home.lan).
#
# Owner directive 2026-10-17: "Everything should be in catalog.home.lan and
# it should say something about known deployment locations (which can be
# zero)." This script is the DATA side: one entry per service that exists
# ANYWHERE — the union of services.catalog ("what exists", declared
# unconditionally) and services.integration ("what runs here", per-host
# enable) across the REAL hosts. A declared service enabled nowhere ships
# deployments: [].
#
# Hosts: evo-x2 + rpi3-dns (NixOS) + Lars-MacBook-Air (darwin — imports no
# NixOS service modules, so it legitimately contributes zero deployments
# today; the `or {}` guards keep that a LIVE fact, not an assumption).
# zfs-vm is EXCLUDED: a VM test scaffold is not a deployment location.
#
# Output (stdout, JSON, deterministic apart from generatedAt): { generatedAt,
#   hosts: [ {host, platform} ], services: [ { name, description, owner,
#   subdomain, port, healthPath, layer, deployments: [ { host,
#   platform, url, port } ] } ] }
#
# Consumed by the eventcatalog-hub's scripts/generate-inventory.sh →
# committed inventory.json → render-inventory.py at build time. Drift
# checks compare everything EXCEPT generatedAt (jq 'del(.generatedAt)').
#
# Env:
#   SYSTEMNIX_FLAKE                     flake to eval (default: this checkout)
#   CATALOG_INVENTORY_REQUIRE_ALL_HOSTS=1  a failed host eval is FATAL instead
#                                       of WARN+skip. Interactive runs keep the
#                                       forgiving default; the automated
#                                       catalog-inventory-sync timer sets it —
#                                       an automated regeneration must never
#                                       silently shrink the committed union
#                                       (a dropped host = dropped deployments).
#
# Usage:
#   scripts/catalog-inventory.sh               # export (3 live host evals)
#   scripts/catalog-inventory.sh --self-test   # fixture-test the jq assembly
#
# jq note: short options only; this is a child script so the direnv
# DIRENV_DIFF jq-arg trap does not reach it (verified 2026-10-17).
# UNION_FILTER's single quotes trip SC2016 — the $-names inside are JQ
# variables ($hs/$g/$stamp), not shell expansions; the quotes are the
# mechanism.
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
# nix run .#catalog-inventory bakes this text into the store — BASH_SOURCE
# points into /nix/store, and the repo root must come from the env (or the
# canonical clone path).
if [[ ! -f "$REPO_ROOT/flake.nix" ]]; then
  REPO_ROOT="$HOME/projects/SystemNix"
fi
FLAKE_REF="${SYSTEMNIX_FLAKE:-$REPO_ROOT}"

# Union: catalog rows declare EXISTENCE (any host's declaration counts),
# integration rows with enable=true add DEPLOYMENTS on that host. First
# non-null wins for descriptive fields (catalog rows are emitted before
# integration rows per host; hosts in fixed order); services sort by name.
# Hoisted into one variable so --self-test exercises the EXACT production
# program (the eval legs stay live-only — the assembly is the part that
# can regress silently).
UNION_FILTER='
	[.[] | select(. != null)] as $hs
	| [
		$hs[] | . as $h
		| (
			(.catalog // {}) | to_entries[] | {
				name: .key,
				owner: .value.owner,
				description: .value.description,
				healthPath: .value.healthPath,
				subdomain: .value.subdomain,
				port: .value.port,
				layer: null,
				deployed: false,
				host: $h.host,
				platform: $h.platform,
				domain: $h.domain
			}
		), (
			(.integration // {}) | to_entries[] | {
				name: .key,
				owner: null,
				description: .value.description,
				healthPath: null,
				subdomain: .value.subdomain,
				port: .value.port,
				layer: .value.layer,
				deployed: .value.enable,
				host: $h.host,
				platform: $h.platform,
				domain: $h.domain
			}
		)
	]
	| group_by(.name)
	| map(
		. as $g
		| {
			name: $g[0].name,
			owner: ($g | map(.owner) | map(select(. != null)) | first),
			description: ($g | map(.description) | map(select(. != null)) | first),
			healthPath: ($g | map(.healthPath) | map(select(. != null)) | first),
			subdomain: ($g | map(.subdomain) | map(select(. != null)) | first),
			port: ($g | map(.port) | map(select(. != null)) | first),
			layer: ($g | map(.layer) | map(select(. != null)) | first),
			deployments: (
				$g
				| map(select(.deployed))
				| map({
					host,
					platform,
					url: (if .subdomain != null then "https://" + .subdomain + "." + .domain else null end),
					port
				})
				| unique_by(.host)
				| sort_by(.host)
			)
		}
	)
	| sort_by(.name)
	| {
		generatedAt: $stamp,
		hosts: [$hs[] | {host, platform}],
		services: .
	}
'

# self_test — fixture host docs (the exact eval_host output shape) through
# the SAME UNION_FILTER, asserting the assembly contract:
#   1. union by name + alphabetical service order
#   2. first-non-null field precedence (catalog description/port beat
#      integration's, regardless of host order)
#   3. deployments only from enable=true rows, per-host URLs, port from the
#      DEPLOYING host's integration row, sorted by host
#   4. enable=false and catalog-only entries → zero-deploy shape ([])
#   5. a service-less host (darwin shape) contributes nothing but stays in
#      the hosts list, in input order
self_test() {
  local tmp rc=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  cat >"$tmp/01-evo.json" <<'EOF'
{"host":"evo-x2","platform":"nixos","domain":"home.lan",
 "integration":{
   "alpha":{"enable":true,"subdomain":"alpha","port":8401,"layer":"app","description":"Integration description loses"},
   "bravo":{"enable":false,"subdomain":"bravo","port":8402,"layer":"app","description":"Disabled on every host"}
 },
 "catalog":{
   "alpha":{"owner":"team-a","description":"Catalog description wins","healthPath":"/healthz","subdomain":"alpha","port":8401},
   "charlie":{"owner":"team-c","description":"Declared, deployed nowhere","healthPath":null,"subdomain":null,"port":null}
 }}
EOF
  cat >"$tmp/02-rpi.json" <<'EOF'
{"host":"rpi3-dns","platform":"nixos","domain":"home.lan",
 "integration":{"alpha":{"enable":true,"subdomain":"alpha","port":8403,"layer":null,"description":null}},
 "catalog":{}}
EOF
  cat >"$tmp/03-darwin.json" <<'EOF'
{"host":"Lars-MacBook-Air","platform":"darwin","domain":"home.lan",
 "integration":{},"catalog":{}}
EOF

  jq -s --arg stamp "SELFTEST" "$UNION_FILTER" "$tmp"/[0-9]*.json >"$tmp/out.json"

  check() {
    local desc="$1" expr="$2"
    if jq -e "$expr" "$tmp/out.json" >/dev/null 2>&1; then
      echo "PASS [catalog-inventory]: $desc"
    else
      echo "FAIL [catalog-inventory]: $desc  (expr: $expr)" >&2
      rc=1
    fi
  }

  check "services unioned by name, alphabetical" \
    '.services | map(.name) == ["alpha","bravo","charlie"]'
  check "catalog description wins over integration" \
    '.services[0].description == "Catalog description wins"'
  check "catalog port wins over the other host's integration port" \
    '.services[0].port == 8401'
  check "owner/healthPath/layer unioned from their owning rows" \
    '.services[0] | .owner == "team-a" and .healthPath == "/healthz" and .layer == "app"'
  check "deployments from enable=true rows only, per-host URL, integration port, host-sorted" \
    '.services[0].deployments == [{"host":"evo-x2","platform":"nixos","url":"https://alpha.home.lan","port":8401},{"host":"rpi3-dns","platform":"nixos","url":"https://alpha.home.lan","port":8403}]'
  check "enable=false integration → zero-deploy shape" \
    '.services[1].deployments == []'
  check "catalog-only entry → zero-deploy shape" \
    '.services[2].deployments == [] and .services[2].owner == "team-c"'
  check "service-less host contributes no services but stays in hosts, input order" \
    '.hosts == [{"host":"evo-x2","platform":"nixos"},{"host":"rpi3-dns","platform":"nixos"},{"host":"Lars-MacBook-Air","platform":"darwin"}]'
  check "generatedAt carried through" \
    '.generatedAt == "SELFTEST"'

  if [ "$rc" -eq 0 ]; then
    echo "catalog-inventory: self-test OK"
  fi
  exit "$rc"
}

case "${1:-}" in
--self-test) self_test ;;
"") : ;;
*)
  echo "usage: $0 [--self-test]" >&2
  exit 2
  ;;
esac

if [[ ! -f "$FLAKE_REF/flake.nix" ]]; then
  echo "ERROR [catalog-inventory]: no flake.nix at $FLAKE_REF (set SYSTEMNIX_FLAKE)" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

eval_host() {
  local attr="$1" host="$2" platform="$3"
  echo "==> evaluating $host ($attr)" >&2
  if nix eval --json "$FLAKE_REF#$attr.config" --apply "
		c: {
			host = \"$host\";
			platform = \"$platform\";
			domain = c.networking.domain or \"home.lan\";
			integration = builtins.mapAttrs (n: e: {
				enable = e.enable;
				subdomain = e.subdomain;
				port = e.port;
				layer = e.vHost.layer;
				description = (if e.homepage == null then null else e.homepage.description);
			}) (c.services.integration or {});
			catalog = c.services.catalog or {};
		}
	" >"$tmp/$host.json" 2>"$tmp/$host.err"; then
    :
  elif [[ ${CATALOG_INVENTORY_REQUIRE_ALL_HOSTS:-} == "1" ]]; then
    echo "ERROR [catalog-inventory]: eval failed for $host and CATALOG_INVENTORY_REQUIRE_ALL_HOSTS=1 — aborting WITHOUT shrinking the union (a missing host would silently drop its deployments)" >&2
    cat "$tmp/$host.err" >&2
    exit 1
  else
    echo "WARN [catalog-inventory]: eval failed for $host — skipping host (see stderr below); its deployments will be missing" >&2
    cat "$tmp/$host.err" >&2
    echo "null" >"$tmp/$host.json"
  fi
}

eval_host nixosConfigurations.evo-x2 evo-x2 nixos
eval_host nixosConfigurations.rpi3-dns rpi3-dns nixos
eval_host darwinConfigurations.Lars-MacBook-Air Lars-MacBook-Air darwin

stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -s --arg stamp "$stamp" "$UNION_FILTER" "$tmp"/*.json
