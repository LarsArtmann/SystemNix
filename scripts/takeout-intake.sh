#!/usr/bin/env bash
# takeout-intake.sh — install the owner's saved Takeout exports page into an
# account's staging root, WHATEVER the browser named it.
#
# Closes the magic-filename failure (the 2026-11-11 D3c watcher never fired
# because the browser saved "Google Takeout.html", not links.html): the newest
# HTML in the source dir that actually carries Takeout download links wins.
#
# Usage:
#   bash scripts/takeout-intake.sh --account <account> [--from DIR] [--dry-run]
#   bash scripts/takeout-intake.sh --selftest
#
# Registry: scripts/takeout-accounts.tsv (override TAKEOUT_REGISTRY).
# Installs as <staging>/links.html (0600). Next step is printed:
#   bash scripts/takeout-download.sh <staging> ingest-html
set -euo pipefail

die() {
  echo "takeout-intake: ERROR: $*" >&2
  exit 1
}
log() { echo "[$(date '+%F %T')] $*"; }

REPO=$(cd "$(dirname "$0")/.." && pwd)
REGISTRY=${TAKEOUT_REGISTRY:-$REPO/scripts/takeout-accounts.tsv}

staging_for() {
  awk -F'\t' -v a="$1" '$1 == a { print $3; exit }' "$REGISTRY"
}

intake() {
  local account='' from='' dry=0
  while [ $# -gt 0 ]; do
    case $1 in
      --account) account=$2; shift 2 ;;
      --from) from=$2; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  [ -n "$account" ] || die "--account is required"
  [ -f "$REGISTRY" ] || die "registry not found: $REGISTRY"
  local staging
  staging=$(staging_for "$account")
  [ -n "$staging" ] || die "account '$account' not in $REGISTRY (add a row first)"
  from=${from:-$HOME/Downloads}
  [ -d "$from" ] || die "source dir not found: $from"

  local candidate=''
  local f
  while IFS= read -r f; do
    case ${f,,} in
      *.html | *.htm) ;;
      *) continue ;;
    esac
    if grep -qE 'data-download-uri="takeout/download|takeout/download\?' "$f" 2>/dev/null; then
      candidate=$f
      break
    fi
  done < <(find "$from" -maxdepth 1 -type f -printf '%T@\t%p\n' | sort -rn | cut -f2-)

  [ -n "$candidate" ] || die "no Takeout exports page found in $from (save the takeout.google.com exports page as any *.html there)"
  log "candidate: $candidate"

  if [ -f "$staging/links.html" ] && cmp -s "$candidate" "$staging/links.html"; then
    log "already installed (identical content) — nothing to do"
    return 0
  fi
  if [ "$dry" -eq 1 ]; then
    log "DRY RUN — would install as $staging/links.html"
    return 0
  fi
  mkdir -p "$staging"
  chmod 700 "$staging" 2>/dev/null || true
  install -m 600 "$candidate" "$staging/links.html"
  log "installed $staging/links.html"
  log "next: bash $REPO/scripts/takeout-download.sh '$staging' ingest-html"
}

selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-intake-selftest
  local rc=0
  rm -rf "$fx"
  mkdir -p "$fx"/{dl,stage}
  printf '# fixture registry\naccount\tmode\tstaging_root\tcadence\tstatus\tretain\tnotes\ntestacct\tkeep\t%s\t2-monthly\tg1\te\tfixture\n' "$fx/stage" >"$fx/registry.tsv"
  export TAKEOUT_REGISTRY=$fx/registry.tsv
  printf '<html>not a takeout page</html>\n' >"$fx/dl/old.html"
  printf '<a data-download-uri="takeout/download?x=1" data-size="1 MB" data-filename="a.zip">x</a>\n' >"$fx/dl/Google Takeout.html"

  check() { # name expected actual
    if [ "$2" = "$3" ]; then
      echo "leg $1: OK ($3)"
    else
      echo "leg $1: FAIL (expected '$2', got '$3')"
      rc=1
    fi
  }

  bash "$0" --account testacct --from "$fx/dl" --dry-run >/dev/null
  check dryrun-no-install no "$([ -f "$fx/stage/links.html" ] && echo yes || echo no)"

  bash "$0" --account testacct --from "$fx/dl" >/dev/null
  check install-exists yes "$([ -f "$fx/stage/links.html" ] && echo yes || echo no)"
  check install-mode 600 "$(stat -c %a "$fx/stage/links.html")"
  check install-content same "$(cmp -s "$fx/dl/Google Takeout.html" "$fx/stage/links.html" && echo same || echo diff)"

  check rerun-idempotent 0 "$(bash "$0" --account testacct --from "$fx/dl" >/dev/null && echo 0 || echo 1)"

  bash "$0" --account nosuch --from "$fx/dl" >/dev/null 2>&1 && rc_bad=0 || rc_bad=1
  check unknown-account-rejected 1 "$rc_bad"

  mkdir -p "$fx/empty"
  bash "$0" --account testacct --from "$fx/empty" >/dev/null 2>&1 && rc_bad=0 || rc_bad=1
  check no-candidate-rejected 1 "$rc_bad"

  if [ "$rc" -eq 0 ]; then echo "takeout-intake selftest: PASS"; else echo "takeout-intake selftest: FAIL"; fi
  return "$rc"
}

main() {
  [ $# -gt 0 ] || {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
  }
  case $1 in
    --selftest) selftest ;;
    -h | --help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) intake "$@" ;;
  esac
}

main "$@"
