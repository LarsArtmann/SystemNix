#!/usr/bin/env bash
# takeout-ingest-photos.sh — Google Photos Takeout -> Immich (Gate G3; plan:
# docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md).
#
# Wraps immich-go 0.32.0 (`upload from-google-photos` eats the Takeout ZIPs
# directly — no extraction). Pinned flags and why:
#   --include-unmatched   REQUIRED for no-data-loss: modern Takeouts ship no
#                         JSON sidecar for unedited photos; without this flag
#                         immich-go would SKIP most of the library.
#   --sync-albums         recreate Google Photos albums as Immich albums
#   --include-archived/-partner  archived + partner-shared content is data too
#   --on-errors stop      (immich-go default) — a failing upload FAILS the run;
#                         never bulk-continue silently
# Env opt-ins: INGEST_TRASHED=1 adds --include-trashed (deleted-in-Google
# content; default OFF to keep Immich clean — count them first via
# logs/zip-entries.tsv if in doubt).
#
# Prereqs: Gate G2 green (scripts/takeout-verify.sh) and an Immich API key
# rendered by the `immich-api-key-provision` converger from
# services.immich.apiKeys.takeout-import (0400 env file, default
# /var/lib/immich-api-keys/takeout-import.env; override with
# TAKEOUT_IMMICH_ENV). No key ever lives in the staging directory: the
# converger owns minting, scope, and rotation. IMMICH_API_KEY in the
# environment wins over the file (ephemeral/override runs).
#
# Usage:
#   bash scripts/takeout-ingest-photos.sh <staging-dir> [--dry-run]
set -euo pipefail

die() {
  echo "takeout-ingest-photos: ERROR: $*" >&2
  exit 2
}
log() { echo "[$(date '+%F %T')] $*"; }

main() {
  [ $# -ge 1 ] || die "usage: $0 <staging-dir> [--dry-run]"
  local root=$1 dry="" extra=()
  [ "${2:-}" = "--dry-run" ] && dry=1 && extra+=(--dry-run)

  [ -d "$root/zips" ] || die "no staging at $root"
  [ -f "$root/photos-media-count.txt" ] || die "run scripts/takeout-verify.sh first (Gate G2) — photos-media-count.txt is the reconciliation base"

  # Immich key: converger-rendered env file (services.immich.apiKeys.takeout-import).
  # Scope lives in Nix, never here — this script only consumes the rendered file.
  local envfile=${TAKEOUT_IMMICH_ENV:-/var/lib/immich-api-keys/takeout-import.env}
  local apikey="" apiurl=""
  if [ -n "${IMMICH_API_KEY:-}" ]; then
    apikey=$IMMICH_API_KEY
    log "using IMMICH_API_KEY from the environment (converger env file not consulted)"
  elif [ -r "$envfile" ]; then
    [ "$(stat -c %a "$envfile")" = "400" ] ||
      die "$envfile must be 0400 (secret-at-rest rule) — it is $(stat -c %a "$envfile"); re-run: sudo systemctl restart immich-api-key-provision"
    apikey=$(sed -n 's/^IMMICH_API_KEY=//p' "$envfile")
    apiurl=$(sed -n 's/^IMMICH_URL=//p' "$envfile")
    [ -n "$apikey" ] || die "$envfile has no IMMICH_API_KEY line — re-render: sudo systemctl restart immich-api-key-provision"
    log "using converger key from $envfile"
  else
    die "no Immich API key: $envfile absent and IMMICH_API_KEY unset.
  The key is machine-minted (Immich is OIDC-only) by the root converger:
    sudo systemctl start immich-api-key-provision
  Declared scope: services.immich.apiKeys.takeout-import (platforms/nixos/system/configuration.nix).
  Rotation: rm $envfile && sudo systemctl restart immich-api-key-provision"
  fi

  # URL: the converger bakes IMMICH_URL into env-format keys. Manifest port
  # lookup is only a fallback (plain-format keys), never a hardcoded literal
  # (script-port-audit).
  if [ -z "$apiurl" ]; then
    local manifest="${SYSTEMNIX_MANIFEST:-/etc/systemnix/integration-manifest.json}"
    [ -f "$manifest" ] || die "integration manifest missing at $manifest — run on evo-x2 (deployed host)"
    local port
    port=$(jq -r '.ports["immich"] // empty' <"$manifest")
    [ -n "$port" ] || die "immich port not found in manifest — is immich enabled?"
    apiurl="http://localhost:$port"
  fi

  local immich_go_bin=""
  if command -v immich-go >/dev/null 2>&1; then
    immich_go_bin=immich-go
  else
    log "immich-go not on PATH — resolving via nix shell nixpkgs#immich-go (0.32.0 pinned by flake lock at eval time)"
    immich_go_bin="nix shell nixpkgs#immich-go -c immich-go"
  fi

  mkdir -p "$root/logs"
  chmod 700 "$root/logs"
  log "expected media (from Gate G2 inventory):"
  cat "$root/photos-media-count.txt"
  [ "${INGEST_TRASHED:-0}" = "1" ] && extra+=(--include-trashed)

  log "starting immich-go (dry-run: ${dry:-no}) — log: logs/immich-go.log"
  local rc=0
  (
    cd "$root"
    # shellcheck disable=SC2086 # immich_go_bin is a deliberately word-split command prefix
    $immich_go_bin \
      -server "$apiurl" \
      -api-key "$apikey" \
      --no-ui \
      --client-timeout 30m \
      --log-file logs/immich-go.log \
      --log-level INFO \
      upload from-google-photos \
      --include-unmatched \
      --include-archived \
      --include-partner \
      --sync-albums \
      --people-tag \
      --takeout-tag \
      --on-errors stop \
      "${extra[@]}" \
      zips/part-*.zip
  ) || rc=$?

  if [ "$rc" -ne 0 ]; then
    die "immich-go exited $rc — last 30 log lines follow; reconcile counts before ANY retry (duplicates are safe: checksum dedup)\n$(tail -30 "$root/logs/immich-go.log" 2>/dev/null)"
  fi
  log "immich-go finished clean — reconcile its reported uploaded+duplicate counts against photos-media-count.txt above (Gate G3), then check albums in the Immich UI"
}

main "$@"
