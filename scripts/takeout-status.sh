#!/usr/bin/env bash
# takeout-status.sh — one command of pipeline truth per Takeout account
# (fleet plan: docs/planning/2026-11-13_multi-account-takeout-fleet-plan.md).
#
# For every account in scripts/takeout-accounts.tsv it reports, on ONE line:
#   parts N/M      declared parts (parts.tsv rows) present in zips/
#   ledger         rows + bytes this account contributed (takeout-dedup ledger)
#   preflight      balance --preflight verdict (PASS/FAIL/SKIP — the honest
#                  "nothing mismatches / nothing imported yet" gate)
#   last verify    the staging's verification-report.md stamp (G2 GREEN/FAIL
#                  + report date) — the last time G2 ran on this staging
#
# Usage:
#   bash scripts/takeout-status.sh                # table for all accounts
#   bash scripts/takeout-status.sh --account <a>  # one account
#   bash scripts/takeout-status.sh --tsv          # raw TAB-separated (script-friendly)
#   bash scripts/takeout-status.sh --selftest     # synthetic fixture battery
#
# Read-only: nothing here mutates a staging root, the ledger, or Immich.
set -euo pipefail

die() {
  echo "takeout-status: ERROR: $*" >&2
  exit 1
}

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEDUP="$SELF_DIR/takeout-dedup.sh"
REGISTRY=${TAKEOUT_REGISTRY:-$SELF_DIR/takeout-accounts.tsv}
LEDGER=${TAKEOUT_LEDGER:-/mnt/pool/archive/google-takeout/.ledger/ledger.tsv}

ledger_stats() {
  # rows/bytes for one account from the dedup ledger (0/0 when absent).
  local account=$1
  if [ -f "$LEDGER" ]; then
    awk -F'\t' -v a="$account" '
      NR > 1 && $4 == a { rows++; bytes += $3 }
      END { printf "%d %d\n", rows + 0, bytes + 0 }' "$LEDGER"
  else
    echo "0 0"
  fi
}

parts_stats() {
  # N/M = parts present in zips/ of the parts.tsv-declared set.
  local root=$1
  local declared name
  [ -f "$root/parts.tsv" ] || {
    echo "0/0"
    return
  }
  declared=$(awk -F'\t' 'NF >= 2 && $1 !~ /^#/ { print ($3 != "" ? $3 : sprintf("part-%02d.zip", $1)) }' "$root/parts.tsv")
  local total=0 found=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    total=$((total + 1))
    [ -f "$root/zips/$name" ] && found=$((found + 1))
  done <<<"$declared"
  echo "$found/$total"
}

verify_stamp() {
  # "GREEN 2026-11-14 16:16" / "FAIL(3) 2026-…" / "-" when never verified.
  local root=$1 report
  report=$root/verification-report.md
  [ -f "$report" ] || {
    echo "-"
    return
  }
  local stamp failures
  stamp=$(sed -n '1s/.*report — //p' "$report")
  failures=$(sed -n 's/.*- Hard failures: \([0-9]*\).*/\1/p' "$report" | head -n1)
  failures=${failures:-?}
  if [ "$failures" = "0" ]; then
    echo "GREEN ${stamp:-unknown-date}"
  else
    echo "FAIL($failures) ${stamp:-unknown-date}"
  fi
}

preflight_verdict() {
  # PASS / FAIL: <line> / SKIP (no zips) / SKIP (no script) for one staging.
  local root=$1 account=$2 cycle out rc
  if [ ! -f "$DEDUP" ]; then
    echo "SKIP (dedup script missing)"
    return
  fi
  if [ ! -d "$root/zips" ] || ! ls "$root"/zips/*.zip >/dev/null 2>&1; then
    echo "SKIP (no zips downloaded yet)"
    return
  fi
  cycle=$(basename "$root" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}$' || true)
  if [ -z "$cycle" ] && [ -f "$LEDGER" ]; then
    # No date suffix on the staging root: fall back to the LATEST cycle the
    # ledger holds for this account. A bare "unknown" here would filter the
    # ledger to zero rows and make balance report a VACUOUS PASS (the same
    # empty-side lie balance itself guards against) — live-caught in the
    # selftest 2026-11-17.
    cycle=$(awk -F'\t' -v a="$account" '
      NR > 1 && $4 == a && $5 > latest { latest = $5 }
      END { print latest }' "$LEDGER")
  fi
  cycle=${cycle:-unknown}
  if out=$(bash "$DEDUP" balance --staging "$root" --account "$account" --cycle "$cycle" --preflight 2>&1); then
    echo "PASS"
  else
    rc=$?
    echo "FAIL rc=$rc: $(printf '%s' "$out" | grep 'PREFLIGHT' | head -n1)"
  fi
}

fmt_bytes() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1000000000000) printf "%.2f TB", b / 1000000000000
    else if (b >= 1000000000) printf "%.2f GB", b / 1000000000
    else if (b >= 1000000) printf "%.1f MB", b / 1000000
    else printf "%d B", b
  }'
}

emit_row() {
  local tsv=$1 acct=$2 mode=$3 root=$4
  local parts lrows lbytes pf stamp
  if [ ! -d "$root" ]; then
    if [ "$tsv" = "1" ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$acct" "$mode" "0/0" "0 rows / 0 B" "SKIP (staging root missing)" "-"
    else
      printf '%-24s %-6s %-9s %-16s %-40s %s\n' "$acct" "$mode" "0/0" "0 rows / 0 B" "SKIP (staging root missing)" "-"
    fi
    return
  fi
  parts=$(parts_stats "$root")
  read -r lrows lbytes <<<"$(ledger_stats "$acct")"
  pf=$(preflight_verdict "$root" "$acct")
  stamp=$(verify_stamp "$root")
  if [ "$tsv" = "1" ]; then
    printf '%s\t%s\t%s\t%s rows / %s\t%s\t%s\n' "$acct" "$mode" "$parts" "$lrows" "$(fmt_bytes "$lbytes")" "$pf" "$stamp"
  else
    printf '%-24s %-6s %-9s %-16s %-40s %s\n' "$acct" "$mode" "$parts" "$lrows rows / $(fmt_bytes "$lbytes")" "$pf" "$stamp"
  fi
}

main() {
  local only='' tsv=0
  while [ $# -gt 0 ]; do
    case $1 in
    --account)
      shift
      [ $# -gt 0 ] || die "--account needs a value"
      only=$1
      ;;
    --account=*) only=${1#*=} ;;
    --tsv) tsv=1 ;;
    --selftest)
      selftest
      return
      ;;
    -*) die "unknown option: $1" ;;
    *) die "unexpected argument: $1 (usage: $0 [--account <a>] [--tsv] | --selftest)" ;;
    esac
    shift
  done
  [ -f "$REGISTRY" ] || die "fleet registry not found: $REGISTRY"

  if [ "$tsv" != "1" ]; then
    printf '%-24s %-6s %-9s %-16s %-40s %s\n' "ACCOUNT" "MODE" "PARTS" "LEDGER" "PREFLIGHT" "LAST VERIFY"
    printf '%-24s %-6s %-9s %-16s %-40s %s\n' "-------" "----" "-----" "------" "---------" "-----------"
  fi
  local acct mode root
  while IFS=$'\t' read -r acct mode root _rest; do
    case $acct in '' | '#'*) continue ;; esac
    [ "$acct" = "account" ] && continue
    if [ -n "$only" ] && [ "$acct" != "$only" ]; then continue; fi
    emit_row "$tsv" "$acct" "$mode" "$root"
  done <"$REGISTRY"
}

# --- selftest (synthetic fixtures; no network, no pool writes) ---
selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-status-selftest
  local rc=0 got
  rm -rf "$fx"
  mkdir -p "$fx/reg1/zips" "$fx/reg2/zips"

  check() {
    local name=$1 want=$2 got=$3
    if [ "$want" = "$got" ]; then
      echo "leg $name: OK"
    else
      echo "leg $name: FAIL (want '$want', got '$got')"
      rc=1
    fi
  }

  # Registry fixture: two accounts, one with parts+verify+balanced zips,
  # one with a missing staging root entirely.
  printf '# account\tmode\tstaging_root\tcadence\tstatus\tretain\tnotes\n' >"$fx/accounts.tsv"
  printf 'acctA\tkeep\t%s/reg1\t2-monthly\tg3-photos\t2\tnote\n' "$fx" >>"$fx/accounts.tsv"
  printf 'acctB\tretire\t%s/reg2\tone-shot\tg0-requested\tbaseline\tnote\n' "$fx" >>"$fx/accounts.tsv"

  run_status() {
    TAKEOUT_REGISTRY="$fx/accounts.tsv" TAKEOUT_LEDGER="$fx/ledger.tsv" bash "$SELF_DIR/takeout-status.sh" --tsv "$@"
  }

  run_status_ledger() {
    # Same runner against a DIFFERENT ledger — the cycle-fallback leg below
    # brings its own copy so the mutating preflight-fail leg can never
    # pollute its fixture state.
    TAKEOUT_REGISTRY="$fx/accounts.tsv" TAKEOUT_LEDGER="$1" bash "$SELF_DIR/takeout-status.sh" --tsv "${@:2}"
  }

  # Account A: parts.tsv declares 3 parts, 2 REAL zips exist (unzip -l must
  # succeed — balance reads the zip listings). Ledger rows a=100 B, b=200 B
  # mirror the zip members exactly, so preflight sees a balanced state with
  # the third declared part still missing (parts 2/3). 2030-01-02 report
  # says 0 hard failures.
  printf '# part\texpected\n1\t1 GB\n2\t1 GB\n3\t1 GB\n' >"$fx/reg1/parts.tsv"
  mkdir -p "$fx/tk1/Takeout/Drive"
  head -c 100 /dev/zero | tr '\0' 'a' >"$fx/tk1/Takeout/Drive/a"
  head -c 200 /dev/zero | tr '\0' 'b' >"$fx/tk1/Takeout/Drive/b"
  (cd "$fx/tk1" && zip -qr "$fx/reg1/zips/part-01.zip" Takeout/Drive)
  rm "$fx/tk1/Takeout/Drive/a" "$fx/tk1/Takeout/Drive/b"
  mkdir -p "$fx/tk1/Takeout/Mail"
  printf 'mailbox' >"$fx/tk1/Takeout/Mail/m"
  (cd "$fx/tk1" && zip -qr "$fx/reg1/zips/part-02.zip" Takeout/Mail)
  printf '# Takeout verification report — 2030-01-02 03:04:05\n\n- Hard failures: 0; warnings: 1\n' >"$fx/reg1/verification-report.md"
  printf 'ALGO\tHASH\tSIZE\tACCOUNT\tCYCLE\tRELPATH\n' >"$fx/ledger.tsv"
  printf 'sha256\th1\t100\tacctA\t2030-01-01\tTakeout/Drive/a\n' >>"$fx/ledger.tsv"
  printf 'sha256\th2\t200\tacctA\t2030-01-01\tTakeout/Drive/b\n' >>"$fx/ledger.tsv"

  check parts-count "2/3" "$(run_status --account acctA | awk -F'\t' 'NR == 1 { print $3 }')"

  check ledger-rows "2 rows / 300 B" "$(run_status --account acctA | awk -F'\t' 'NR == 1 { print $4 }')"

  # reg1 HAS zips -> preflight runs (PASS with COLD products); the missing-
  # staging account is the SKIP leg below.
  check preflight-pass "PASS" "$(run_status --account acctA | awk -F'\t' 'NR == 1 { print $5 }')"

  check verify-stamp-green "GREEN 2030-01-02 03:04:05" "$(run_status --account acctA | awk -F'\t' 'NR == 1 { print $6 }')"

  printf '# Takeout verification report — 2030-02-03 04:05:06\n\n- Hard failures: 3; warnings: 0\n' >"$fx/reg1/verification-report.md"
  check verify-stamp-fail "FAIL(3) 2030-02-03 04:05:06" "$(run_status --account acctA | awk -F'\t' 'NR == 1 { print $6 }')"
  printf '# Takeout verification report — 2030-01-02 03:04:05\n\n- Hard failures: 0; warnings: 1\n' >"$fx/reg1/verification-report.md"

  # reg2 exists but has NO parts.tsv and no zips — the row must tolerate a
  # staging without manifests: parts 0/0 + preflight SKIP.
  check missing-staging-skip "SKIP (no zips downloaded yet)" "$(run_status --account acctB | awk -F'\t' 'NR == 1 { print $5 }')"

  printf 'acctC\tretire\t/nonexistent/takeout-path\tone-shot\tg0\tbaseline\tnote\n' >>"$fx/accounts.tsv"
  check missing-staging-root "SKIP (staging root missing)" "$(run_status --account acctC | awk -F'\t' 'NR == 1 { print $5 }')"

  # 2026-11-19 (cycle fallback, §25 re-verify): a staging basename WITHOUT a
  # date suffix must resolve the cycle from the LATEST ledger partition — a
  # bare "unknown" filters the ledger to zero rows and balance reports a
  # VACUOUS PASS. The fixture plants TWO cycles: the older (2030-01-01)
  # row matches the zip bytes exactly, the latest (2030-01-02) claims 999 B
  # vs the real 300 B. Verdict must FAIL — proof the fallback engaged the
  # LATEST partition (an older-cycle pick or a bare-unknown vacuous PASS
  # both show up as PASS and fail this leg). Own ledger copy: immune to the
  # mutating preflight-fail leg below.
  mkdir -p "$fx/reg3/zips" "$fx/tk3/Takeout/Drive"
  head -c 300 /dev/zero | tr '\0' c >"$fx/tk3/Takeout/Drive/c"
  (cd "$fx/tk3" && zip -qr "$fx/reg3/zips/part-01.zip" Takeout/Drive)
  printf '# part\texpected\n1\t1 KB\n' >"$fx/reg3/parts.tsv"
  printf 'ALGO\tHASH\tSIZE\tACCOUNT\tCYCLE\tRELPATH\n' >"$fx/ledger-fallback.tsv"
  printf 'sha256\told\t300\tacctD\t2030-01-01\tTakeout/Drive/c\n' >>"$fx/ledger-fallback.tsv"
  printf 'sha256\th9\t999\tacctD\t2030-01-02\tTakeout/Drive/c\n' >>"$fx/ledger-fallback.tsv"
  printf 'acctD\tkeep\t%s/reg3\t2-monthly\tg3\t2\tnote\n' "$fx" >>"$fx/accounts.tsv"
  got=$(run_status_ledger "$fx/ledger-fallback.tsv" --account acctD | awk -F'\t' 'NR == 1 { print $5 }')
  case $got in
  FAIL*) echo "leg cycle-fallback-latest: OK" ;;
  *)
    echo "leg cycle-fallback-latest: FAIL (want FAIL* via the LATEST ledger cycle, got '$got' — bare-unknown or older-cycle pick)"
    rc=1
    ;;
  esac

  # Unbalanced extract must surface as preflight FAIL (mismatch is the
  # fail-closed signal that blocks imports).
  printf 'sha256\th3\t999\tacctA\t2030-01-01\tTakeout/Drive/c\n' >>"$fx/ledger.tsv"
  mkdir -p "$fx/reg1/extracted/Takeout/Drive"
  printf 'wrong-bytes' >"$fx/reg1/extracted/Takeout/Drive/c"
  (cd "$fx/reg1/extracted" && TAKEOUT_LEDGER="$fx/ledger.tsv" bash "$SELF_DIR/takeout-dedup.sh" index --from-extract . --account acctA --cycle 2030-01-01 >/dev/null 2>&1) || true
  got=$(run_status --account acctA | awk -F'\t' 'NR == 1 { print $5 }')
  case $got in
  FAIL*) echo "leg preflight-fail-on-mismatch: OK" ;;
  *)
    echo "leg preflight-fail-on-mismatch: FAIL (want FAIL*, got '$got')"
    rc=1
    ;;
  esac

  if [ "$rc" -eq 0 ]; then
    rm -rf "$fx"
    echo "SELFTEST GREEN"
  else
    echo "SELFTEST RED (fixture kept at $fx for inspection)"
  fi
  return $rc
}

main "$@"
