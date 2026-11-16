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
DOWNLOAD=${TAKEOUT_DOWNLOAD:-$REPO/scripts/takeout-download.sh}

staging_for() {
  awk -F'\t' -v a="$1" '$1 == a { print $3; exit }' "$REGISTRY"
}

# non-dying gate predicate: echoes the verdict (MATCH|MISMATCH|NO-EMAIL) and
# returns 0 only on MATCH
account_gate_verdict() {
  local page=$1 account=$2
  local emails e
  emails=$(grep -oiE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$page" 2>/dev/null | sort -u | head -5)
  if [ -z "$emails" ]; then
    echo NO-EMAIL
    return 1
  fi
  local e_local a_local
  a_local=${account%%@*}
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    e_local=${e%%@*}
    if [ "${e,,}" = "${account,,}" ] || [ "${e_local,,}" = "${a_local,,}" ]; then
      echo MATCH
      return 0
    fi
  done <<<"$emails"
  echo "MISMATCH ($emails)"
  return 1
}

verify_account_page() {
  local page=$1 account=$2 verdict
  verdict=$(account_gate_verdict "$page" "$account")
  case $verdict in
  MATCH)
    log "account gate: page email matches account '$account'"
    ;;
  NO-EMAIL)
    die "no account email found on $page — cannot prove whose exports these are (save the page WHILE LOGGED IN as $account, or pass --force)"
    ;;
  *)
    die "account gate FAILED: $page belongs to '$verdict', not '$account' — refusing to install (a wrong-account page would poison parts.tsv; --force to override)"
    ;;
  esac
}

intake() {
  local account='' from='' dry=0 do_ingest=0 do_list=0 force=0
  while [ $# -gt 0 ]; do
    case $1 in
    --account)
      account=$2
      shift 2
      ;;
    --from)
      from=$2
      shift 2
      ;;
    --dry-run)
      dry=1
      shift
      ;;
    --ingest)
      do_ingest=1
      shift
      ;;
    --list)
      do_list=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
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

  local gate
  if [ "$force" -eq 1 ]; then
    gate=FORCED
    log "WARN: --force set — skipping the account-email gate"
  else
    gate=$(account_gate_verdict "$candidate" "$account") || true
  fi

  if [ "$do_list" -eq 1 ]; then
    log "LIST ONLY — candidate: $candidate (account gate: $gate)"
    return 0
  fi

  if [ "$gate" != FORCED ]; then
    verify_account_page "$candidate" "$account"
  fi

  if [ -f "$staging/links.html" ] && cmp -s "$candidate" "$staging/links.html"; then
    log "already installed (identical content) — nothing to do"
    if [ "$do_ingest" -eq 1 ]; then chain_ingest "$staging"; fi
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
  log "next: bash $DOWNLOAD '$staging' ingest-html"
  if [ "$do_ingest" -eq 1 ]; then chain_ingest "$staging"; fi
}

chain_ingest() {
  local staging=$1
  [ -f "$DOWNLOAD" ] || die "chained ingest target missing: $DOWNLOAD"
  log "chaining: $DOWNLOAD '$staging' ingest-html"
  bash "$DOWNLOAD" "$staging" ingest-html
}

selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-intake-selftest
  local rc=0
  rm -rf "$fx"
  mkdir -p "$fx"/{dl,stage}
  printf '# fixture registry\naccount\tmode\tstaging_root\tcadence\tstatus\tretain\tnotes\ntestacct\tkeep\t%s\t2-monthly\tg1\te\tfixture\n' "$fx/stage" >"$fx/registry.tsv"
  export TAKEOUT_REGISTRY=$fx/registry.tsv
  export TAKEOUT_DOWNLOAD=$fx/fake-download.sh
  cat >"$fx/fake-download.sh" <<'STUB'
#!/usr/bin/env bash
# selftest stub: records invocations, one per line (log path via env —
# $0-relative paths proved unportable in the local agent shell)
echo "$*" >>"$TAKEOUT_STUB_LOG"
STUB
  chmod +x "$fx/fake-download.sh"
  export TAKEOUT_STUB_LOG=$fx/download-calls.log
  printf '<html>not a takeout page</html>\n' >"$fx/dl/old.html"
  printf '<div>testacct@gmail.com</div><a data-download-uri="takeout/download?x=1" data-size="1 MB" data-filename="a.zip">x</a>\n' >"$fx/dl/Google Takeout.html"
  mkdir -p "$fx"/dl-foreign "$fx"/dl-emailless "$fx"/empty
  printf '<div>someone-else@other.org</div><a data-download-uri="takeout/download?y=2" data-size="2 MB" data-filename="b.zip">y</a>\n' >"$fx/dl-foreign/Google Takeout.html"
  printf '<a data-download-uri="takeout/download?z=3" data-size="3 MB" data-filename="c.zip">z</a>\n' >"$fx/dl-emailless/Google Takeout.html"

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

  bash "$0" --account testacct --from "$fx/dl-foreign" >/dev/null 2>&1 && rc_bad=0 || rc_bad=1
  check wrong-account-page-rejected 1 "$rc_bad"

  bash "$0" --account testacct --from "$fx/dl-emailless" >/dev/null 2>&1 && rc_bad=0 || rc_bad=1
  check emailless-page-rejected 1 "$rc_bad"

  rm -f "$fx/stage/links.html"
  bash "$0" --account testacct --from "$fx/dl-foreign" --force --dry-run >/dev/null 2>&1 && rc_ok=0 || rc_ok=1
  check force-overrides-gate 0 "$rc_ok"

  bash "$0" --account testacct --from "$fx/dl" --list >/dev/null 2>&1
  check list-no-install no "$([ -f "$fx/stage/links.html" ] && echo yes || echo no)"

  bash "$0" --account testacct --from "$fx/dl" --ingest >/dev/null 2>&1
  check ingest-chained chained "$([ -f "$fx/download-calls.log" ] && grep -q 'ingest-html' "$fx/download-calls.log" && echo chained || echo not-called)"

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
