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
# Prereqs: Gate G2 green (scripts/takeout-verify.sh), owner-created Immich API
# key (FULL access — album creation needs more than asset.read+asset.upload;
# delete the key after the migration) at <staging>/immich-api-key (0600).
#
# Usage:
#   bash scripts/takeout-ingest-photos.sh <staging-dir> [--dry-run]
set -euo pipefail

die() { echo "takeout-ingest-photos: ERROR: $*" >&2; exit 2; }
log() { echo "[$(date '+%F %T')] $*"; }

main() {
  [ $# -ge 1 ] || die "usage: $0 <staging-dir> [--dry-run]"
  local root=$1 dry="" extra=()
  [ "${2:-}" = "--dry-run" ] && dry=1 && extra+=(--dry-run)

  [ -d "$root/zips" ] || die "no staging at $root"
  [ -f "$root/photos-media-count.txt" ] || die "run scripts/takeout-verify.sh first (Gate G2) — photos-media-count.txt is the reconciliation base"
  local keyfile=$root/immich-api-key
  [ -f "$keyfile" ] || die "Immich API key missing at $keyfile — owner: Immich -> Account Settings -> API Keys (full access), then: install -m 600 <keyfile-with-value> $keyfile"
  [ "$(stat -c %a "$keyfile")" = "600" ] || die "$keyfile must be 0600 (secret-at-rest rule)"

  # manifest bridge: port NAME, never a literal (script-port-audit; degrade = fail loud here,
  # a wrong-port upload is worse than a stopped run)
  local manifest="${SYSTEMNIX_MANIFEST:-/etc/systemnix/integration-manifest.json}"
  [ -f "$manifest" ] || die "integration manifest missing at $manifest — run on evo-x2 (deployed host)"
  local port
  port=$(jq -r '.ports["immich"] // empty' < "$manifest")
  [ -n "$port" ] || die "immich port not found in manifest — is immich enabled?"

  local immich_go_bin=""
  if command -v immich-go > /dev/null 2>&1; then
    immich_go_bin=immich-go
  else
    log "immich-go not on PATH — resolving via nix shell nixpkgs#immich-go (0.32.0 pinned by flake lock at eval time)"
    immich_go_bin="nix shell nixpkgs#immich-go -c immich-go"
  fi

  mkdir -p "$root/logs"
  chmod 700 "$root/logs"
  log "expected media (from Gate G2 inventory):"; cat "$root/photos-media-count.txt"
  [ "${INGEST_TRASHED:-0}" = "1" ] && extra+=(--include-trashed)

  log "starting immich-go (dry-run: ${dry:-no}) — log: logs/immich-go.log"
  local rc=0
  (
    cd "$root"
    # shellcheck disable=SC2086 # immich_go_bin is a deliberately word-split command prefix
    $immich_go_bin \
      -server "http://localhost:$port" \
      -api-key "$(cat "$keyfile")" \
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
