#!/usr/bin/env bash
# takeout-dedup.sh — content-identity ledger + import planner for Google
# Takeout across accounts and 2-monthly export cycles.
# Fleet plan: docs/planning/2026-11-13_multi-account-takeout-fleet-plan.md
#
# Why: Takeout exports are FULL snapshots, never deltas. Incrementality is
# ours: skip (account, relpath) pairs whose CONTENT hash did not change since
# the latest previous cycle, import changed/new paths (structure preserved),
# report cross-account duplicate content, and never propagate deletions.
#
# Commands:
#   index   --from-extract DIR --account A --cycle C [--force]
#   plan    --from-extract DIR --account A --cycle C [--out DIR]
#   balance --staging S --account A --cycle C [--skip-products "Mail,YouTube"]
#           [--summary | --preflight]   summary = one aggregate line,
#           preflight = the same gate in PASS/FAIL form for import scripts
#   report
#   --selftest
#
# RELPATH is stored WITHOUT the `Takeout/` prefix (normalized 2026-11-14):
# `Takeout/Drive/a.pdf` is ledgered as `Drive/a.pdf`, so a second cycle with a
# different archive layout cannot fork the identity space. Recovery, if a
# hand-edit ever goes wrong: delete the account's rows (`awk` on col 4) or the
# whole ledger, then re-run `index` — the ledger is derived state, the zips
# are ground truth.
#
# Ledger: $TAKEOUT_LEDGER
#   default /mnt/pool/archive/google-takeout/.ledger/ledger.tsv
#   format: ALGO <tab> HASH <tab> SIZE <tab> ACCOUNT <tab> CYCLE <tab> RELPATH
#   append-only, one header line, cycles are sortable strings (YYYY-MM-DD)
#
# Ledger scope: EXTRACTED products (the Drive tree at G4). Photos dedup is
# Immich's server-side checksum; cold products stay zips-only (no extraction),
# so they never enter the ledger by design.
set -euo pipefail

die() {
  echo "takeout-dedup: ERROR: $*" >&2
  exit 1
}
log() { echo "[$(date '+%F %T')] $*"; }

LEDGER=${TAKEOUT_LEDGER:-/mnt/pool/archive/google-takeout/.ledger/ledger.tsv}
ALGO=
HASHER=
readonly LEDGER_HEADER=$'ALGO\tHASH\tSIZE\tACCOUNT\tCYCLE\tRELPATH'

resolve_hasher() {
  if command -v b3sum >/dev/null 2>&1; then
    HASHER=b3sum
    ALGO=blake3
  elif command -v sha256sum >/dev/null 2>&1; then
    HASHER=sha256sum
    ALGO=sha256
  else
    die "need b3sum or sha256sum on PATH"
  fi
}

ensure_ledger() {
  if [ ! -f "$LEDGER" ]; then
    mkdir -p "$(dirname "$LEDGER")" 2>/dev/null ||
      die "cannot create $(dirname "$LEDGER") — one-time owner command: sudo install -d -o lars -g users -m 700 $(dirname "$LEDGER")"
    printf '%s\n' "$LEDGER_HEADER" >"$LEDGER"
    log "ledger created at $LEDGER"
  fi
  chmod 600 "$LEDGER" 2>/dev/null || true
}

hash_file() { "$HASHER" -- "$1" | cut -d' ' -f1; }

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# --- index: hash every regular file under DIR, append new ledger rows ---
cmd_index() {
  local dir='' account='' cycle='' force=0
  while [ $# -gt 0 ]; do
    case $1 in
    --from-extract)
      dir=$2
      shift 2
      ;;
    --account)
      account=$2
      shift 2
      ;;
    --cycle)
      cycle=$2
      shift 2
      ;;
    --force)
      force=1
      shift
      ;;
    *) die "index: unknown argument: $1" ;;
    esac
  done
  [ -d "$dir" ] || die "index: --from-extract DIR missing or not a directory: '$dir'"
  [ -n "$account" ] || die "index: --account is required"
  [ -n "$cycle" ] || die "index: --cycle is required"
  dir=${dir%/}

  resolve_hasher
  ensure_ledger

  if [ "$force" -eq 0 ] && grep -qF $'\t'"$account"$'\t'"$cycle"$'\t' "$LEDGER"; then
    log "account=$account cycle=$cycle already indexed — nothing to do (use --force to re-hash)"
    return 0
  fi

  local tmp files=0 bytes=0
  tmp=$(mktemp)
  local f rel size hash
  while IFS= read -r -d '' f; do
    rel=${f#"$dir"/}
    case $rel in
    *$'\t'*)
      log "WARN: tab in path, not indexable: $rel"
      continue
      ;;
    esac
    size=$(stat -c %s "$f")
    hash=$(hash_file "$f")
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$ALGO" "$hash" "$size" "$account" "$cycle" "$rel" >>"$tmp"
    files=$((files + 1))
    bytes=$((bytes + size))
    # Progress every 250 files: a 3 TB fleet index is a multi-hour run with no
    # other output, and "is it alive?" was unanswerable without a heartbeat.
    if [ $((files % 250)) -eq 0 ]; then
      log "indexing… $files files / $bytes bytes hashed"
    fi
  done < <(find "$dir" -type f -print0)

  local before after
  before=$(wc -l <"$LEDGER")
  {
    grep -v $'^ALGO\tHASH\t' "$LEDGER" || true
    cat "$tmp"
  } | LC_ALL=C sort -u >"$tmp.merged"
  {
    printf '%s\n' "$LEDGER_HEADER"
    cat "$tmp.merged"
  } >"$tmp.next"
  mv "$tmp.next" "$LEDGER"
  rm -f "$tmp" "$tmp.merged"
  after=$(wc -l <"$LEDGER")
  log "indexed $files files (algo=$ALGO) — new rows: $((after - before)), already known: $((files - (after - before))), ledger now: $((after - 1)) rows"
}

# --- plan: classify the current cycle against previous cycles ---
cmd_plan() {
  local dir='' account='' cycle='' out=''
  while [ $# -gt 0 ]; do
    case $1 in
    --from-extract)
      dir=$2
      shift 2
      ;;
    --account)
      account=$2
      shift 2
      ;;
    --cycle)
      cycle=$2
      shift 2
      ;;
    --out)
      out=$2
      shift 2
      ;;
    *) die "plan: unknown argument: $1" ;;
    esac
  done
  [ -n "$account" ] || die "plan: --account is required"
  [ -n "$cycle" ] || die "plan: --cycle is required"
  ensure_ledger
  out=${out:-${dir:-.}/dedup}

  local ncur
  ncur=$(awk -F'\t' -v a="$account" -v c="$cycle" 'NR > 1 && $4 == a && $5 == c { n++ } END { print n + 0 }' "$LEDGER")
  [ "$ncur" -gt 0 ] || die "plan: no ledger rows for account=$account cycle=$cycle — run 'index' first"

  mkdir -p "$out"
  rm -f "$out"/new-files.txt "$out"/new-files.tsv "$out"/cross-cycle-content-dups.tsv \
    "$out"/vanished-since-prev-cycle.txt "$out"/unchanged.txt

  # One awk pass over the ledger:
  #   prior_hash[relpath] = hash from the LATEST prior cycle of THIS account
  #   known_hash[hash]    = seen in ANY earlier cycle of ANY account
  #   NEW:       relpath unseen, or hash != prior hash (changed content)
  #   UNCHANGED: relpath seen in a prior cycle with the same hash -> skip
  #   vanished:  relpath seen in a prior cycle, absent now -> report only
  awk -F'\t' -v OFS='\t' -v a="$account" -v c="$cycle" -v out="$out" '
    NR == 1 { next }
    $4 == a && $5 == c { cur_hash[$6] = $2; cur_size[$6] = $3; seen[$6] = 1; next }
    {
      rel = $6
      if ($4 == a && (!(rel in prior_cycle) || $5 > prior_cycle[rel])) {
        prior_cycle[rel] = $5
        prior_hash[rel] = $2
      }
      known_hash[$2] = 1
    }
    END {
      for (rel in cur_hash) {
        if (rel in prior_hash && prior_hash[rel] == cur_hash[rel]) {
          print rel >> (out "/unchanged.txt")
          unch_bytes += cur_size[rel]
        } else {
          print rel >> (out "/new-files.txt")
          print rel, cur_hash[rel], cur_size[rel] >> (out "/new-files.tsv")
          new_bytes += cur_size[rel]
          if (cur_hash[rel] in known_hash) {
            print rel, cur_hash[rel] >> (out "/cross-cycle-content-dups.tsv")
            dup_bytes += cur_size[rel]
          }
        }
      }
      printf "new-bytes\t%d\nunchanged-bytes\t%d\ndup-bytes\t%d\n", new_bytes, unch_bytes, dup_bytes > (out "/totals.tsv")
      for (rel in prior_cycle)
        if (!(rel in seen)) print rel >> (out "/vanished-since-prev-cycle.txt")
    }
  ' "$LEDGER"

  for f in new-files.txt new-files.tsv cross-cycle-content-dups.tsv vanished-since-prev-cycle.txt unchanged.txt; do
    touch "$out/$f"
  done

  # destination buckets from the new-file list (extension heuristics; the
  # fleet plan owns the authoritative routing rules)
  local photosdocs
  photosdocs="jpg jpeg png heic heif webp gif bmp tif tiff dng cr2 nef arw mp4 mov 3gp mkv avi m4v webm"
  : >"$out/photos.txt"
  : >"$out/other.txt"
  if [ -s "$out/new-files.txt" ]; then
    while IFS= read -r rel; do
      ext=${rel##*.}
      ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
      case " $photosdocs " in
      *" $ext "*) printf '%s\n' "$rel" >>"$out/photos.txt" ;;
      *) printf '%s\n' "$rel" >>"$out/other.txt" ;;
      esac
    done <"$out/new-files.txt"
  fi

  local nnew nunch nvan ndup newb unchb dupb
  nnew=$(wc -l <"$out/new-files.txt")
  nunch=$(wc -l <"$out/unchanged.txt")
  nvan=$(wc -l <"$out/vanished-since-prev-cycle.txt")
  ndup=$(wc -l <"$out/cross-cycle-content-dups.tsv")
  newb=$(awk -F'\t' '$1 == "new-bytes" { print $2 }' "$out/totals.tsv" 2>/dev/null || echo 0)
  unchb=$(awk -F'\t' '$1 == "unchanged-bytes" { print $2 }' "$out/totals.tsv" 2>/dev/null || echo 0)
  dupb=$(awk -F'\t' '$1 == "dup-bytes" { print $2 }' "$out/totals.tsv" 2>/dev/null || echo 0)
  {
    printf 'account: %s\ncycle:   %s\n' "$account" "$cycle"
    printf 'new (import):            %s files / %s bytes\n' "$nnew" "${newb:-0}"
    printf 'unchanged (skip):        %s files / %s bytes\n' "$nunch" "${unchb:-0}"
    printf 'vanished (report only):  %s\n' "$nvan"
    printf 'new-but-content-known:   %s files / %s bytes (already held elsewhere — still import; destinations dedup server-side)\n' "$ndup" "${dupb:-0}"
    printf '\nOutputs in %s:\n  new-files.txt / .tsv  (rclone --files-from, immich pre-filter)\n  photos.txt, other.txt (destination buckets)\n  unchanged.txt, vanished-since-prev-cycle.txt, cross-cycle-content-dups.tsv, totals.tsv\n' "$out"
  } >"$out/SUMMARY.txt"
  cat "$out/SUMMARY.txt"
}

# --- balance: Gate G6 accounting — zips (ground truth) vs indexed extract ---
# Every product that was EXTRACTED must match the zip side file-for-file and
# byte-for-byte; products deliberately not extracted show as COLD. A mismatch
# means the extract is incomplete (or the wrong member filter ran) and no
# destination import may proceed.
cmd_balance() {
  local staging='' account='' cycle='' skip='' mode=table
  while [ $# -gt 0 ]; do
    case $1 in
    --staging)
      staging=$2
      shift 2
      ;;
    --account)
      account=$2
      shift 2
      ;;
    --cycle)
      cycle=$2
      shift 2
      ;;
    --skip-products)
      skip=$2
      shift 2
      ;;
    --summary)
      mode=summary
      shift
      ;;
    --preflight)
      mode=preflight
      shift
      ;;
    *) die "balance: unknown argument: $1" ;;
    esac
  done
  [ -n "$staging" ] || die "balance: --staging is required"
  [ -n "$account" ] || die "balance: --account is required"
  [ -n "$cycle" ] || die "balance: --cycle is required"
  [ -d "$staging/zips" ] || die "balance: no $staging/zips"
  ensure_ledger

  local ztmp ltmp rc=0 z
  ztmp=$(mktemp)
  ltmp=$(mktemp)
  for z in "$staging"/zips/*.zip; do
    [ -f "$z" ] || continue
    unzip -l "$z" | awk '
      /^ *[0-9]+ / && $0 !~ /\/$/ && match($0, /Takeout\/([^\/]+)\//, m) { f[m[1]]++; b[m[1]] += $1 }
      END { for (p in f) printf "%s\t%d\t%d\n", p, f[p], b[p] }
    ' >>"$ztmp"
  done
  awk -F'\t' -v a="$account" -v c="$cycle" '
    NR > 1 && $4 == a && $5 == c {
      rel = $6
      sub(/^Takeout\//, "", rel)
      n = split(rel, parts, "/")
      p = (n > 1) ? parts[1] : "(root)"
      f[p]++
      b[p] += $3
    }
    END { for (p in f) printf "%s\t%d\t%d\n", p, f[p], b[p] }
  ' "$LEDGER" >"$ltmp"

  awk -F'\t' -v skip="$skip" -v mode="$mode" '
    # ARGV[1] (not FNR == NR): an EMPTY zip listing leaves FNR == NR true on
    # the first ledger record, which silently promoted the LEDGER to the zip
    # side and made an empty staging root report BALANCED (2026-11-14).
    FILENAME == ARGV[1] { zf[$1] = $2; zb[$1] = $3; zp[$1] = 1; next }
    { lf[$1] = $2; lb[$1] = $3; lp[$1] = 1 }
    END {
      nskip = split(skip, s, ",")
      for (i = 1; i <= nskip; i++) if (s[i] != "") sk[s[i]] = 1
      if (mode == "table") printf "%-30s %8s %18s %8s %18s  %s\n", "PRODUCT", "zip#", "zip bytes", "idx#", "idx bytes", "status"
      bad = 0
      np = 0
      nok = ncold = nskipn = 0
      zf_t = zb_t = lb_t = 0
      for (p in zp) {
        np++
        if (p in sk) {
          nskipn++
          if (mode == "table") printf "%-30s %8d %18d %8s %18s  SKIPPED\n", p, zf[p], zb[p], "-", "-"
          continue
        }
        zf_t += zf[p]
        zb_t += zb[p]
        if (!(p in lp)) {
          ncold++
          if (mode == "table") printf "%-30s %8d %18d %8s %18s  COLD (not extracted)\n", p, zf[p], zb[p], "-", "-"
          continue
        }
        st = (zf[p] == lf[p] && zb[p] == lb[p]) ? "OK" : "MISMATCH"
        if (st == "MISMATCH") bad++
        else nok++
        lb_t += lb[p]
        if (mode == "table") printf "%-30s %8d %18d %8d %18d  %s\n", p, zf[p], zb[p], lf[p], lb[p], st
      }
      for (p in lp) if (!(p in zp)) {
        if (mode == "table") printf "%-30s %8s %18s %8d %18d  EXTRACT-ONLY\n", p, "-", "-", lf[p], lb[p]
        bad++
      }
      if (mode != "table") {
        printf "products: %d (%d OK, %d COLD, %d SKIPPED, %d MISMATCH) — zip %d files / %d bytes, indexed %d bytes\n", np, nok, ncold, nskipn, bad, zf_t, zb_t, lb_t
      } else print ""
      # Fail-closed: an EMPTY zip side makes every check vacuously true, which
      # is exactly how a "BALANCED" verdict can be a lie (no zips downloaded /
      # wrong staging root). Zero products is never a pass.
      if (np == 0) {
        print (mode == "preflight" ? "PREFLIGHT: FAIL" : "RESULT: NO ZIP CONTENT") " — no Takeout/* members found in " (mode == "preflight" ? "the staging zips" : "any zip (wrong root or nothing downloaded yet)")
        exit 2
      }
      if (bad > 0) print (mode == "preflight" ? "PREFLIGHT: FAIL" : "RESULT: MISMATCH") " (" bad " product(s)) — reconcile before any import or deletion"
      else print (mode == "preflight" ? "PREFLIGHT: PASS" : "RESULT: BALANCED") " — every extracted product matches the zips byte-for-byte"
      exit (bad > 0 ? 1 : 0)
    }
  ' "$ztmp" "$ltmp" || rc=$?
  rm -f "$ztmp" "$ltmp"
  return "$rc"
}

# --- report: ledger-wide totals + duplicate content accounting ---
cmd_report() {
  ensure_ledger
  awk -F'\t' '
    NR == 1 { next }
    {
      key = $4 "\t" $5
      rows[key]++
      bytes[key] += $3
      hkey = $1 "\t" $2
      pair = $4 "\t" $6
      if (!(pair in seenpair)) {
        seenpair[pair] = 1
        paths[hkey]++
        size_by_hash[hkey] = $3
        acct_of[hkey] = acct_of[hkey] " " $4
      }
    }
    END {
      print "ACCOUNT          CYCLE       FILES      BYTES"
      for (k in rows) {
        split(k, parts, "\t")
        printf "%-16s %-11s %-10s %s\n", parts[1], parts[2], rows[k], bytes[k]
      }
      print ""
      dupsets = 0
      dupbytes = 0
      for (h in paths) {
        if (paths[h] > 1) {
          dupsets++
          dupbytes += size_by_hash[h] * (paths[h] - 1)
        }
      }
      print "duplicate-content sets (same hash, >1 distinct account+path):", dupsets
      print "redundant bytes beyond first copy:", dupbytes
    }
  ' "$LEDGER"
}

selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-dedup-selftest
  local rc=0
  rm -rf "$fx"
  mkdir -p "$fx"/{c1,c2,out}
  export TAKEOUT_LEDGER=$fx/ledger.tsv

  printf 'alpha\n' >"$fx/c1/a.txt"
  printf 'alpha\n' >"$fx/c1/b.txt"
  printf 'pdf-one\n' >"$fx/c1/c.pdf"
  printf 'bin\n' >"$fx/c1/d.bin"
  printf 'alpha\n' >"$fx/c2/a.txt"
  printf 'pdf-two\n' >"$fx/c2/c.pdf"
  printf 'bin\n' >"$fx/c2/e.txt" # new path, content already known from c1/d.bin

  check() { # name expected actual
    if [ "$2" = "$3" ]; then
      echo "leg $1: OK ($3)"
    else
      echo "leg $1: FAIL (expected '$2', got '$3')"
      rc=1
    fi
  }

  "$0" index --from-extract "$fx/c1" --account acctA --cycle 2026-01-01 >/dev/null
  check index1-rows 5 "$(wc -l <"$TAKEOUT_LEDGER")"
  "$0" index --from-extract "$fx/c1" --account acctA --cycle 2026-01-01 >/dev/null
  check index1-idempotent 5 "$(wc -l <"$TAKEOUT_LEDGER")"

  "$0" plan --from-extract "$fx/c1" --account acctA --cycle 2026-01-01 --out "$fx/out1" >/dev/null
  check plan1-new 4 "$(wc -l <"$fx/out1/new-files.txt")"
  check plan1-unchanged 0 "$(wc -l <"$fx/out1/unchanged.txt")"
  check plan1-tsv-tab-separated 4 "$(awk -F'\t' 'NF == 3' "$fx/out1/new-files.tsv" | wc -l)"
  # byte totals (2026-11-14): 6+6+8+4 bytes for a.txt, b.txt, c.pdf, d.bin
  check plan1-new-bytes 24 "$(awk -F'\t' '$1 == "new-bytes" { print $2 }' "$fx/out1/totals.tsv")"
  check plan1-summary-bytes yes "$(grep -q 'new (import):            4 files / 24 bytes' "$fx/out1/SUMMARY.txt" && echo yes || echo no)"

  "$0" index --from-extract "$fx/c2" --account acctA --cycle 2026-03-01 >/dev/null
  "$0" plan --from-extract "$fx/c2" --account acctA --cycle 2026-03-01 --out "$fx/out2" >/dev/null
  check plan2-new 2 "$(wc -l <"$fx/out2/new-files.txt")"
  check plan2-unchanged 1 "$(wc -l <"$fx/out2/unchanged.txt")"
  check plan2-vanished 2 "$(wc -l <"$fx/out2/vanished-since-prev-cycle.txt")"
  check plan2-contentdup 1 "$(wc -l <"$fx/out2/cross-cycle-content-dups.tsv")"
  if grep -qx 'e.txt' "$fx/out2/new-files.txt"; then echo "leg plan2-e-new: OK"; else
    echo "leg plan2-e-new: FAIL"
    rc=1
  fi
  if grep -qx 'c.pdf' "$fx/out2/new-files.txt"; then echo "leg plan2-c-changed: OK"; else
    echo "leg plan2-c-changed: FAIL"
    rc=1
  fi

  "$0" plan --from-extract "$fx/c2" --account acctA --cycle 2026-03-01 --out "$fx/out2" >/dev/null
  check plan2-rerun-idempotent 2 "$(wc -l <"$fx/out2/new-files.txt")"

  "$0" index --from-extract "$fx/c1" --account acctB --cycle 2026-03-01 >/dev/null
  "$0" plan --from-extract "$fx/c1" --account acctB --cycle 2026-03-01 --out "$fx/out3" >/dev/null
  check plan3-accountB-all-new 4 "$(wc -l <"$fx/out3/new-files.txt")"
  check plan3-accountB-crossacct-dup 4 "$(wc -l <"$fx/out3/cross-cycle-content-dups.tsv")"

  if command -v zip >/dev/null 2>&1; then
    mkdir -p "$fx/bal/zips" "$fx/bal/extracted/Takeout/Drive"
    printf 'one\n' >"$fx/bal/extracted/Takeout/Drive/a.txt"
    printf 'two\n' >"$fx/bal/extracted/Takeout/Drive/b.txt"
    (cd "$fx/bal/extracted" && zip -qr "$fx/bal/zips/t.zip" Takeout/Drive)
    bash "$0" index --from-extract "$fx/bal/extracted" --account balAcct --cycle 2030-01-01 >/dev/null
    check balance-balanced 0 "$(bash "$0" balance --staging "$fx/bal" --account balAcct --cycle 2030-01-01 >/dev/null 2>&1 && echo 0 || echo 1)"

    mkdir -p "$fx/bal2/zips" "$fx/bal2/extracted/Takeout/Drive"
    cp "$fx/bal/zips/t.zip" "$fx/bal2/zips/"
    printf 'one\n' >"$fx/bal2/extracted/Takeout/Drive/a.txt"
    bash "$0" index --from-extract "$fx/bal2/extracted" --account balAcct2 --cycle 2030-01-01 >/dev/null
    check balance-mismatch-detected 1 "$(bash "$0" balance --staging "$fx/bal2" --account balAcct2 --cycle 2030-01-01 >/dev/null 2>&1 && echo 0 || echo 1)"

    sum_out=$(bash "$0" balance --staging "$fx/bal" --account balAcct --cycle 2030-01-01 --summary 2>&1) || true
    check balance-summary-aggregate yes "$(printf '%s\n' "$sum_out" | grep -q '^products: 1 (1 OK' && printf '%s\n' "$sum_out" | grep -q 'RESULT: BALANCED' && echo yes || echo no)"
    pf_out=$(bash "$0" balance --staging "$fx/bal" --account balAcct --cycle 2030-01-01 --preflight 2>&1) || true
    check balance-preflight-pass yes "$(printf '%s\n' "$pf_out" | grep -q 'PREFLIGHT: PASS' && echo yes || echo no)"

    # Fail-closed leg (2026-11-14): an empty zip side made every comparison
    # vacuously true and reported BALANCED — a lying verdict for "nothing
    # downloaded yet" / wrong staging root.
    mkdir -p "$fx/bal3/zips" "$fx/bal3/extracted/Takeout/Drive"
    printf 'one\n' >"$fx/bal3/extracted/Takeout/Drive/a.txt"
    bash "$0" index --from-extract "$fx/bal3/extracted" --account emptyAcct --cycle 2030-01-01 >/dev/null
    if bash "$0" balance --staging "$fx/bal3" --account emptyAcct --cycle 2030-01-01 >"$fx/bal3.log" 2>&1; then
      echo "leg balance-empty-zips-fail-closed: FAIL (empty zip side reported BALANCED)"
      rc=1
    elif grep -q 'NO ZIP CONTENT' "$fx/bal3.log"; then
      echo "leg balance-empty-zips-fail-closed: OK (no vacuous BALANCED)"
    else
      echo "leg balance-empty-zips-fail-closed: FAIL (wrong failure mode — see $fx/bal3.log)"
      rc=1
    fi
  else
    echo "leg balance: SKIPPED (no zip binary on PATH)"
  fi

  if [ "$rc" -eq 0 ]; then echo "takeout-dedup selftest: PASS"; else echo "takeout-dedup selftest: FAIL"; fi
  return "$rc"
}

main() {
  [ $# -gt 0 ] || usage
  case $1 in
  index)
    shift
    cmd_index "$@"
    ;;
  plan)
    shift
    cmd_plan "$@"
    ;;
  balance)
    shift
    cmd_balance "$@"
    ;;
  report)
    shift
    cmd_report "$@"
    ;;
  --selftest) selftest ;;
  -h | --help) usage ;;
  *) die "unknown command: $1 (index|plan|balance|report|--selftest)" ;;
  esac
}

main "$@"
