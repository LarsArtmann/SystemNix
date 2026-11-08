# Integration manifest loader — sourced by scripts/post-deploy-check.sh and
# fixture-tested by scripts/test-integration-manifest-loader.sh + the
# integration-manifest-loader-selftest flake check (the T4.3 standing legs:
# absent-manifest WARN-skip, unknown-port drift WARN, real-manifest
# resolution are all pinned as fixtures, not just proven once live).
#
# Eval truth (services.catalog + services.integration + lib/ports.nix) baked
# into THIS generation as /etc/systemnix/integration-manifest.json (the
# manifest bridge, modules/nixos/services/integration-manifest.nix). Probes
# reference port NAMES, never literals — a port move (monitor365 9191→9421
# class) needs zero script edits.
#
# Degrade contract (T4.1): absent/unparseable manifest → one WARN here, then
# every port-driven section SKIPs (never FAILs — an old generation must not
# turn into a blocked deploy).
#
# Requires from the sourcing script: jq on PATH, a report_warn() helper,
# and VHOST_PROBE_TIMEOUT (the floor; this loader can only raise it).

# shellcheck shell=bash disable=SC2034  # sourced, never executed

MANIFEST_PATH="${SYSTEMNIX_MANIFEST:-/etc/systemnix/integration-manifest.json}"
MANIFEST_OK=false
if [ -r "$MANIFEST_PATH" ] && jq -e '(.ports | type == "object") and (.services | type == "object")' <"$MANIFEST_PATH" >/dev/null 2>&1; then
  MANIFEST_OK=true
else
  report_warn "integration manifest $MANIFEST_PATH absent or unparseable — port-driven sections below SKIP (generation without the manifest module, or a tree-run; deployed generations carry it)"
fi

# m_port <registry-name> → port number on stdout; rc 1 + a loud WARN when
# the name is missing from the manifest's ports registry (T4.2 drift leg:
# a probe targeting a port Nix does not own is drift, not a silent skip).
m_port() {
  local name="$1" p=""
  [ "$MANIFEST_OK" = true ] || return 1
  p="$(jq -r --arg n "$name" '.ports[$n] // empty' <"$MANIFEST_PATH" 2>/dev/null)" || p=""
  if [ -z "$p" ]; then
    report_warn "manifest drift: port '$name' not in the registry this generation exposes (script probes a name lib/ports.nix does not own)"
    return 1
  fi
  printf '%s' "$p"
}

# Resolve the port names this battery probes. Empty = the section SKIPs (the
# loader/m_port WARN above already named the cause). Registry names are
# host-independent, so they resolve even where the service is disabled.
PORT_POCKET_ID=""
PORT_DISCORDSYNC=""
PORT_M365_SERVER=""
PORT_M365_METRICS=""
PORT_SEARXNG=""
PORT_BROWSERHISTORY=""
PORT_RENAMER=""
PORT_CRUSH_DAILY=""
PORT_SIGNOZ=""
PORT_NODEEXPORTER=""
PORT_LLM_EMBED=""
PORT_LLM_RERANK=""
PORT_DNSBLOCK_STATS=""
if [ "$MANIFEST_OK" = true ]; then
  PORT_POCKET_ID="$(m_port pocket-id)" || true
  PORT_DISCORDSYNC="$(m_port discordsync-api)" || true
  PORT_M365_SERVER="$(m_port monitor365-server)" || true
  PORT_M365_METRICS="$(m_port monitor365-metrics)" || true
  PORT_SEARXNG="$(m_port searxng)" || true
  PORT_BROWSERHISTORY="$(m_port browser-history)" || true
  PORT_RENAMER="$(m_port file-and-image-renamer-health)" || true
  PORT_CRUSH_DAILY="$(m_port crush-daily)" || true
  PORT_SIGNOZ="$(m_port signoz)" || true
  PORT_NODEEXPORTER="$(m_port signoz-node-exporter)" || true
  PORT_LLM_EMBED="$(m_port llama-embeddings)" || true
  PORT_LLM_RERANK="$(m_port llama-reranker)" || true
  PORT_DNSBLOCK_STATS="$(m_port dns-blocker-stats)" || true

  # vHost probe budget from the same truth Gatus uses (plan T6): the max
  # client.timeout across all checks, never BELOW the caller's floor.
  _manifest_timeout_budget="$(jq -r '[.. | objects | select(has("timeout")) | .timeout | sub("s$";"") | tonumber] | if length == 0 then empty else max end' <"$MANIFEST_PATH" 2>/dev/null || true)"
  case "$_manifest_timeout_budget" in
  '' | *[!0-9]*) ;;
  *)
    if [ "$_manifest_timeout_budget" -gt "$VHOST_PROBE_TIMEOUT" ]; then
      VHOST_PROBE_TIMEOUT="$_manifest_timeout_budget"
    fi
    ;;
  esac
fi
