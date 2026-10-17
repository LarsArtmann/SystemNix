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
# jq note: short options only; this is a child script so the direnv
# DIRENV_DIFF jq-arg trap does not reach it (verified 2026-10-17).
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
				description = e.homepage.description;
			}) (c.services.integration or {});
			catalog = c.services.catalog or {};
		}
	" >"$tmp/$host.json" 2>"$tmp/$host.err"; then
		:
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

# Union: catalog rows declare EXISTENCE (any host's declaration counts),
# integration rows with enable=true add DEPLOYMENTS on that host. First
# non-null wins for descriptive fields (catalog rows are emitted before
# integration rows per host; hosts in fixed order); services sort by name.
jq -s --arg stamp "$stamp" '
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
' "$tmp"/*.json
