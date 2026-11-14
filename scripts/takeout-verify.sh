#!/usr/bin/env bash
# takeout-verify.sh — completeness battery for the Google Takeout staging
# root (plan: docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md,
# Gate G2). NOTHING may be deleted or ingested-before-green anywhere in the
# pipeline until this exits 0.
#
# Gates:
#   G2.1 completeness  — every manifest part present and inside its size band
#   G2.2 integrity     — `unzip -t` CRC-clean for every part (reads all bytes)
# G2.3 coverage — every expected-PRESENT product found in the zip listings
#                        (fuzzy name match + override candidates); missing
#                        product = FAIL, unexpected folder = WARN. The
#                        expectation source MATTERS: a staging root with no
#                        products.tsv is self-derived from the zip listings
#                        (integrity still proven, completeness UNPROVEN —
#                        loud WARN), because the embedded 68-product manifest
#                        below describes ONE account (racedriver8k). Opt in
#                        explicitly with `--manifest racedriver8k`.
#   G2.4 inventory     — inventory.tsv (product, files, bytes) +
#                        photos-media-count.txt + SHA256SUMS + verification-report.md
#
# Usage:
#   bash scripts/takeout-verify.sh <staging-dir> [--no-hash] [--manifest racedriver8k]
#   bash scripts/takeout-verify.sh --selftest   # synthetic fixture battery in ~/.cache
set -euo pipefail

die() {
  echo "takeout-verify: ERROR: $*" >&2
  exit 1
}
log() { echo "[$(date '+%F %T')] $*"; }

# --- embedded product manifest (Takeout summary page 2026-11-10; 1=present, 0=no data found) ---
readonly PRODUCTS_MANIFEST='
Access Log Activity|7.2 MB|1
Alerts|<1 MB|1
Android Device Configuration Service||0
Android Studio||0
Arts & Culture||0
Assignments||0
Blogger||0
Calendar|474.3 KB|1
Chrome|273.2 KB|1
Classroom||0
Contacts|27.4 MB|1
Content returned from your appeal||0
Discover|<1 MB|1
Drive|543.33 GB|1
Firebase Dynamic Links||0
Fit|409.4 MB|1
Flow||0
Gemini|<1 MB|1
Gemini in Workspace||0
Google Account|13.2 KB|1
Google Ads||0
Google Business Profile|283.5 MB|1
Google Chat|<1 MB|1
Google Cloud Search||0
Google Developers|<1 MB|1
Google Earth||0
Google Feedback||0
Google Finance|<1 MB|1
Google Help Communities||0
Google Meet|<1 MB|1
Google One||0
Google Pay|153.2 KB|1
Google Photos|336.02 GB|1
Google Play Books|<1 MB|1
Google Play Console|74.5 KB|1
Google Play Games Services|27.7 KB|1
Google Play Movies & TV|<1 MB|1
Google Play Store|195.8 KB|1
Google Product Surveys||0
Google Shopping||0
Google Store|<1 MB|1
Google Translator Toolkit||0
Google Wallet|222.9 KB|1
Google Workspace Marketplace|<1 MB|1
Groups|12.7 KB|1
Home App|133.8 KB|1
Keep|2.2 MB|1
Mail|1.74 GB|1
Maps|216.3 MB|1
Maps (your places)|62.6 KB|1
My Activity|3.3 MB|1
My Maps||0
Nest||0
News||0
NotebookLM||0
Phone Audio||0
Pinpoint||0
Pixel||0
Profile|62.4 KB|1
Saved|13.9 KB|1
Search Contributions|4.1 KB|1
Search Notifications|<1 MB|1
Street View||0
Tasks|<1 MB|1
Tenor||0
Timeline|<1 MB|1
Workspace Studio||0
YouTube and YouTube Music|2.18 MB|1'

# display-name -> candidate Takeout folder names (first match wins)
override_candidates() {
  case "$1" in
  'Maps (your places)') echo 'Maps' ;;
  'Google Play Movies & TV') echo 'Google Play Movies;Google Play Movies & TV' ;;
  'Google Business Profile') echo 'Google My Business;Google Business Profile' ;;
  *) echo '' ;;
  esac
}

norm() {
  local r
  r=$(printf '%s' "$1" | tr -d '[:punct:][:space:]' | tr '[:upper:]' '[:lower:]')
  printf '%s\n' "$r"
}

# normalize harder for fuzzy compare: also drop a leading "google"
norm2() {
  local n
  n=$(norm "$1")
  n=${n#google}
  echo "$n"
}

size_band() {
  local spec=$1 lo hi amount unit
  case $spec in
  LESS1MB)
    echo "1 1600000"
    return
    ;;
  '')
    echo "expected-size string empty (absent product)"
    return 1
    ;;
  *[!0-9]*)
    amount=$(echo "$spec" | awk '{print $1}')
    unit=$(echo "$spec" | awk '{print $2}')
    case $unit in
    GB) amount=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1000000000 }') ;;
    MB) amount=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1000000 }') ;;
    KB) amount=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1000 }') ;;
    *) die "unknown size unit: $spec" ;;
    esac
    lo=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 0.85 }')
    hi=$(awk -v a="$amount" 'BEGIN { printf "%.0f", a * 1.15 }')
    echo "$lo $hi"
    ;;
  *) echo "$spec $spec" ;; # plain integer = EXACT size (ingested from the page)
  esac
}

# The embedded manifest describes the racedriver8k export ONLY (summary page
# 2026-11-10). It is OPT-IN (`--manifest racedriver8k`) — silently seeding it
# for another account's staging root produced confidently wrong coverage
# (2026-11-14).
seed_manifest_products_tsv() {
  local root=$1
  [ -f "$root/products.tsv" ] && return 0
  printf '# product\texpected-size\tpresent\n' >"$root/products.tsv"
  while IFS= read -r pline; do echo "${pline//|/$'\t'}" >>"$root/products.tsv"; done <<<"$PRODUCTS_MANIFEST"
}

# No manifest for this account: derive the expectation set from the zip
# listings themselves. Integrity/completeness of the PARTS is still proven;
# "nothing dropped relative to the export page" is NOT — hence the WARN.
derive_products_tsv_from_inventory() {
  local root=$1
  [ -f "$root/products.tsv" ] && return 0
  {
    printf '# product\texpected-size\tpresent\n'
    awk -F'\t' 'NR > 1 && $1 != "" { printf "%s\t%s\t1\n", $1, $3 }' "$root/inventory.tsv"
  } >"$root/products.tsv"
  manifest_derived=1
  echo "WARN G2.3: NO products manifest for this staging root — expectation set SELF-DERIVED from the zip listings ($(($(wc -l <"$root/products.tsv") - 1)) products). Part integrity is proven; completeness against the Takeout export page is UNPROVEN. Save the exports page or pass --manifest <account> for a real expectation." >&2
}

run_verify() {
  local root=$1 do_hash=${2:-1} manifest_mode=${3:-auto}
  [ -d "$root/zips" ] || die "no staging at $root (takeout-download.sh init first)"
  [ -f "$root/parts.tsv" ] || die "$root/parts.tsv missing (takeout-download.sh init first)"
  if [ "$manifest_mode" = "racedriver8k" ]; then
    seed_manifest_products_tsv "$root"
  fi
  mkdir -p "$root/logs"

  local failures=0 warnings=0 manifest_derived=0

  # --- G2.1 completeness ---
  # Declared zip set (authoritative): parts.tsv rows may carry an explicit
  # filename column (raw browser names, e.g. takeout-20261110T…-001.zip —
  # the 2026-11-14 zip-name divergence fix); without it the legacy
  # part-%02d.zip synthesis applies.
  local declared=$root/logs/declared-zips.txt
  awk -F'\t' 'NF >= 2 && $1 !~ /^#/ {
    printf "%s\n", ($3 != "" ? $3 : sprintf("part-%02d.zip", $1))
  }' "$root/parts.tsv" >"$declared"
  local part spec fname name size lo hi complete=0 total=0
  while IFS=$'\t' read -r part spec fname; do
    case $part in '' | '#'*) continue ;; esac
    total=$((total + 1))
    name=${fname:-$(printf 'part-%02d.zip' "$part")}
    if [ ! -f "$root/zips/$name" ]; then
      echo "FAIL G2.1: declared part missing from zips/: $name" >&2
      failures=$((failures + 1))
      continue
    fi
    size=$(stat -c %s "$root/zips/$name")
    read -r lo hi <<<"$(size_band "$spec")"
    if [ "$size" -ge "$lo" ] && [ "$size" -le "$hi" ]; then
      complete=$((complete + 1))
    else
      echo "FAIL G2.1: $name not in size band ($size bytes, band $lo..$hi)" >&2
      failures=$((failures + 1))
    fi
  done <"$root/parts.tsv"
  log "G2.1 completeness: $complete/$total parts in band"

  # --- G2.2 CRC integrity + listings pass (single read per DECLARED zip) ---
  local zip names_tsv=$root/logs/zip-entries.tsv
  : >"$names_tsv"
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    zip=$root/zips/$name
    if ! unzip -tqq "$zip" >"$root/logs/crc-$name.log" 2>&1; then
      echo "FAIL G2.2: $name failed the unzip CRC test (see logs/)" >&2
      failures=$((failures + 1))
      continue
    fi
    # len<TAB>name for every file entry (dirs end with / and are skipped)
    unzip -l "$zip" | awk '
      NF >= 4 && $1 ~ /^[0-9]+$/ && $4 != "" {
        name = substr($0, index($0, $4))
        if (name !~ /\/$/) printf "%s\t%s\n", $1, name
      }' >>"$names_tsv"
  done <"$declared"
  # undeclared zips (present in zips/ but not in parts.tsv): cannot be
  # assessed — WARN, never silently hashed or skipped invisibly
  for zip in "$root"/zips/*.zip; do
    [ -f "$zip" ] || continue
    if ! grep -qxF "$(basename "$zip")" "$declared"; then
      echo "WARN G2.2: zip not declared in parts.tsv (skipped): $(basename "$zip")" >&2
      warnings=$((warnings + 1))
    fi
  done
  log "G2.2 integrity: CRC-clean zips listed into logs/zip-entries.tsv ($(wc -l <"$names_tsv") entries)"

  # --- inventory per product (top-level folder under Takeout/) ---
  local inv=$root/inventory.tsv
  awk -F'\t' '
    {
      name = $2
      sub(/^Takeout\//, "", name)
      split(name, seg, "/")
      prod = (seg[1] != "" ? seg[1] : "(root)")
      files[prod]++; bytes[prod] += $1
      if (!seen[prod]++) order[++n] = prod
    }
    END {
      printf "# product\tfiles\tbytes\n"
      for (i = 1; i <= n; i++) { p = order[i]; printf "%s\t%d\t%d\n", p, files[p], bytes[p] }
    }' "$names_tsv" >"$inv"
  log "G2.4 inventory: $(wc -l <"$inv") product rows -> inventory.tsv"
  derive_products_tsv_from_inventory "$root"
  if [ "$manifest_derived" = "1" ]; then
    warnings=$((warnings + 1))
  fi

  # --- media counts for the Google Photos product (G3 reconciliation base) ---
  local pmc=$root/photos-media-count.txt
  awk -F'\t' '
    {
      name = $2
      sub(/^Takeout\//, "", name)
      split(name, seg, "/")
      prod = seg[1]
      np = tolower(prod); gsub(/[^a-z0-9]/, "", np)
      if (np != "googlephotos") next
      m = split(name, segs, "/"); fname = segs[m]
      n = split(fname, fp, "."); ext = (n > 1 ? tolower(fp[n]) : "")
      if (ext == "json") json++
      else if (ext ~ /^(jpg|jpeg|png|heic|heif|webp|gif|bmp|tif|tiff|avif|dng|cr2|cr3|nef|arw|raf|raw|mp4|mov|avi|mkv|webm|m4v|3gp|mpg|mts|m2ts|wmv)$/) media++
      else other++
    }
    END {
      printf "google_photos_media_files\t%d\n", media + 0
      printf "google_photos_json_sidecars\t%d\n", json + 0
      printf "google_photos_other_files\t%d\n", other + 0
    }' "$names_tsv" >"$pmc"

  # --- G2.3 coverage ---
  local found_folders
  found_folders=$(awk -F'\t' 'NR > 1 { print $1 }' "$inv")
  local coverage_tsv=$root/logs/coverage.tsv
  : >"$coverage_tsv"
  # normalized expected-name set (raw + google-stripped forms) for the extras check
  local expected_norms=$root/logs/expected-names.txt
  {
    while IFS=$'\t' read -r product _present; do
      case $product in '' | '#'*) continue ;; esac
      norm "$product"
      norm2 "$product"
    done <"$root/products.tsv"
  } >"$expected_norms"
  # folder match for one product: line-safe (names contain spaces), fuzzy, then overrides
  match_folder() {
    local product=$1 folder cand np n2s
    np=$(norm "$product")
    n2s=$(norm2 "$product")
    while IFS= read -r folder; do
      [ -n "$folder" ] || continue
      if [ "$(norm "$folder")" = "$np" ] || [ "$(norm2 "$folder")" = "$n2s" ]; then
        printf '%s' "$folder"
        return
      fi
    done <<<"$found_folders"
    for cand in $(override_candidates "$product" | tr ';' ' '); do
      while IFS= read -r folder; do
        [ -n "$folder" ] || continue
        if [ "$(norm "$folder")" = "$(norm "$cand")" ]; then
          printf '%s' "$folder"
          return
        fi
      done <<<"$found_folders"
    done
    return 1
  }
  local product expect_size present match
  while IFS=$'\t' read -r product expect_size present; do
    case $product in '' | '#'*) continue ;; esac
    match=$(match_folder "$product") || match=''
    if [ "$present" = "1" ]; then
      if [ -n "$match" ]; then
        printf 'OK\t%s\t-> %s\n' "$product" "$match" >>"$coverage_tsv"
      else
        echo "FAIL G2.3: expected-present product NOT FOUND in any zip: $product (expected size: $expect_size)" >&2
        printf 'MISSING\t%s\t(expected %s)\n' "$product" "$expect_size" >>"$coverage_tsv"
        failures=$((failures + 1))
      fi
    else
      if [ -n "$match" ]; then
        printf 'SURPRISE\t%s\t-> %s (page said no data)\n' "$product" "$match" >>"$coverage_tsv"
      else
        printf 'ABSENT\t%s\t(as expected)\n' "$product" >>"$coverage_tsv"
      fi
    fi
  done <"$root/products.tsv"
  # extras (folders with no expected product)
  local fnorm fn2
  while IFS= read -r folder; do
    [ -n "$folder" ] || continue
    fnorm=$(norm "$folder")
    fn2=$(norm2 "$folder")
    if ! grep -qxF "$fnorm" "$expected_norms" && ! grep -qxF "$fn2" "$expected_norms"; then
      echo "WARN G2.3: folder in zips with no matching expected product: $folder" >&2
      printf 'EXTRA\t?\t%s\n' "$folder" >>"$coverage_tsv"
      warnings=$((warnings + 1))
    fi
  done <<<"$found_folders"
  log "G2.3 coverage: see logs/coverage.tsv ($(grep -c '^OK' "$coverage_tsv") matched, $(grep -c '^MISSING' "$coverage_tsv") missing)"

  # --- G2.4 SHA256SUMS ---
  if [ "$do_hash" = "1" ]; then
    log "G2.4 hashing zips (reads every byte again — expect ~1-2 h for 880 GB)..."
    (cd "$root/zips" && while IFS= read -r name; do sha256sum "$name"; done <"$declared") >"$root/SHA256SUMS"
    log "G2.4 SHA256SUMS: $(wc -l <"$root/SHA256SUMS") entries"
  fi

  # --- report ---
  local report=$root/verification-report.md
  {
    echo "# Takeout verification report — $(date '+%F %T')"
    echo
    echo "- Parts in size band: $complete/$total"
    echo "- CRC failures: see G2.2 output above"
    echo "- Coverage: $(grep -c '^OK' "$coverage_tsv") OK / $(grep -c '^MISSING' "$coverage_tsv") MISSING / $(grep -c '^EXTRA' "$coverage_tsv") extra / $(grep -c '^SURPRISE' "$coverage_tsv") surprise-data"
    echo "- Hard failures: $failures; warnings: $warnings"
    if [ "$manifest_derived" = "1" ]; then
      echo "- Expectation source: SELF-DERIVED from the zip listings — part integrity proven, completeness vs the Takeout export page UNPROVEN"
    else
      echo "- Expectation source: products.tsv (account manifest)"
    fi
    echo
    echo '## Inventory'
    column -t -s $'\t' "$inv" 2>/dev/null || cat "$inv"
    echo
    echo '## Photos media count (G3 reconciliation base)'
    cat "$pmc"
    echo
    echo '## Coverage'
    cat "$coverage_tsv"
  } >"$report"
  log "report: $report"

  if [ "$failures" -gt 0 ]; then
    die "$failures hard gate failure(s) — NOTHING may be ingested or deleted until green (plan Gate G2)"
  fi
  log "G2 GREEN: all hard gates passed ($warnings warning(s))"
}

# --- selftest (synthetic fixtures; no network, no pool writes) ---
selftest() {
  local fx=${XDG_CACHE_HOME:-$HOME/.cache}/takeout-verify-selftest
  local rc=0 leg
  rm -rf "$fx"
  mkdir -p "$fx"/{zips,logs}

  build_fixture() {
    rm -rf "$fx"/{zips,logs}
    mkdir -p "$fx"/{zips,logs}
    printf '# part\texpected\n1\t3 MB\n2\tLESS1MB\n' >"$fx/parts.tsv"
    printf '# product\texpected-size\tpresent\n' >"$fx/products.tsv"
    printf '%s\n' 'Drive|543 GB|1' 'Google Photos|336 GB|1' 'Mail|1.74 GB|1' 'Blogger||0' |
      tr '|' '\t' >>"$fx/products.tsv"
    dd if=/dev/urandom of="$fx/blob" bs=1024 count=900 2>/dev/null
    (cd "$fx" && mkdir -p tk/Takeout/Drive tk/'Takeout/Google Photos' tk/Takeout/Mail &&
      cp blob 'tk/Takeout/Drive/a file.pdf' &&
      cp blob 'tk/Takeout/Google Photos/IMG_0001.jpg' &&
      echo '{}' >'tk/Takeout/Google Photos/IMG_0001.jpg.json' &&
      cp blob 'tk/Takeout/Google Photos/vid 2.mp4' &&
      echo hello >tk/Takeout/Mail/mbox.txt &&
      (cd tk && zip -qr "$fx/zips/part-01.zip" Takeout/Drive 'Takeout/Google Photos') &&
      (cd tk && zip -qr "$fx/zips/part-02.zip" Takeout/Mail))
  }

  leg=happy
  build_fixture
  if run_verify_selftest_quiet "$fx" >"$fx/leg-happy.log" 2>&1 &&
    grep -q 'G2 GREEN' "$fx/leg-happy.log"; then
    local media_count extras
    media_count=$(awk -F'\t' '$1=="google_photos_media_files"{print $2}' "$fx/photos-media-count.txt")
    extras=$(grep -c '^EXTRA' "$fx/logs/coverage.tsv" || true)
    if [ "${media_count:-x}" = "2" ] &&
      [ -s "$fx/SHA256SUMS" ] && [ -s "$fx/inventory.tsv" ] &&
      [ "$extras" = "0" ]; then
      echo "PASS: $leg (gates green, inventory + media counts + hashes written, no phantom extras)"
    else
      echo "FAIL: $leg (outputs incomplete: media=$media_count extras=$extras sha=$(wc -l <"$fx/SHA256SUMS" 2>/dev/null || echo 0) inv=$(wc -l <"$fx/inventory.tsv" 2>/dev/null || echo 0))"
      rc=1
    fi
  else
    echo "FAIL: $leg (verify did not pass on a good fixture — see $fx/leg-happy.log)"
    rc=1
  fi

  leg=crc
  build_fixture
  truncate -s 40 "$fx/zips/part-02.zip"
  if run_verify_selftest_quiet "$fx" >"$fx/leg-crc.log" 2>&1; then
    echo "FAIL: $leg (truncated zip passed)"
    rc=1
  elif grep -q 'CRC' "$fx/leg-crc.log"; then
    echo "PASS: $leg (truncated zip caught by CRC gate)"
  else
    echo "FAIL: $leg (failed but not via CRC gate — see $fx/leg-crc.log)"
    rc=1
  fi

  leg=coverage
  build_fixture
  (cd "$fx/tk" && rm -rf Takeout/Mail && rm "$fx/zips/part-02.zip" &&
    zip -qr "$fx/zips/part-02.zip" Takeout/Drive)
  if run_verify_selftest_quiet "$fx" >"$fx/leg-coverage.log" 2>&1; then
    echo "FAIL: $leg (missing product passed)"
    rc=1
  elif grep -q 'expected-present product NOT FOUND' "$fx/leg-coverage.log"; then
    echo "PASS: $leg (missing product caught)"
  else
    echo "FAIL: $leg (failed but not via coverage gate — see $fx/leg-coverage.log)"
    rc=1
  fi

  leg=missing-part
  build_fixture
  rm "$fx/zips/part-02.zip"
  if run_verify_selftest_quiet "$fx" >"$fx/leg-missing.log" 2>&1; then
    echo "FAIL: $leg (missing part passed)"
    rc=1
  elif grep -q 'declared part missing from zips' "$fx/leg-missing.log"; then
    echo "PASS: $leg (missing part caught)"
  else
    echo "FAIL: $leg (failed but not via completeness gate — see $fx/leg-missing.log)"
    rc=1
  fi

  # 2026-11-14: another account's staging root must NEVER inherit the
  # racedriver8k manifest (it did, silently, before this leg existed).
  leg=manifest-leak
  build_fixture
  rm "$fx/products.tsv"
  if run_verify_selftest_quiet "$fx" >"$fx/leg-leak.log" 2>&1 &&
    grep -q 'SELF-DERIVED' "$fx/leg-leak.log" &&
    ! grep -q '543.33 GB\|YouTube and YouTube Music' "$fx/products.tsv" &&
    grep -q 'completeness vs the Takeout export page UNPROVEN' "$fx/verification-report.md"; then
    echo "PASS: $leg (no foreign manifest; expectations self-derived + WARNed)"
  else
    echo "FAIL: $leg (foreign manifest leaked or derivation missing — see $fx/leg-leak.log)"
    rc=1
  fi

  leg=manifest-optin
  build_fixture
  rm "$fx/products.tsv"
  if run_verify_selftest_quiet "$fx" racedriver8k >"$fx/leg-optin.log" 2>&1; then
    echo "FAIL: $leg (racedriver8k manifest passed a foreign fixture)"
    rc=1
  elif grep -q 'expected-present product NOT FOUND' "$fx/leg-optin.log" &&
    grep -q '543.33 GB' "$fx/products.tsv"; then
    echo "PASS: $leg (explicit --manifest racedriver8k opt-in still works)"
  else
    echo "FAIL: $leg (opt-in did not seed/apply the manifest — see $fx/leg-optin.log)"
    rc=1
  fi

  # 2026-11-14 (zip-name divergence): parts.tsv may carry an explicit
  # filename column so raw browser-named zips verify without a rename pass.
  leg=raw-names
  build_fixture
  mv "$fx/zips/part-01.zip" "$fx/zips/takeout-20261110T224436Z-001.zip"
  mv "$fx/zips/part-02.zip" "$fx/zips/takeout-20261110T224438Z-1-001.zip"
  printf '# part\texpected\tfilename\n1\t3 MB\ttakeout-20261110T224436Z-001.zip\n2\tLESS1MB\ttakeout-20261110T224438Z-1-001.zip\n' >"$fx/parts.tsv"
  if run_verify_selftest_quiet "$fx" >"$fx/leg-rawnames.log" 2>&1 &&
    grep -q 'G2 GREEN' "$fx/leg-rawnames.log"; then
    echo "PASS: $leg (raw browser zip names verify via the filename column)"
  else
    echo "FAIL: $leg (raw-named zips did not pass — see $fx/leg-rawnames.log)"
    rc=1
  fi

  leg=raw-names-missing
  build_fixture
  mv "$fx/zips/part-01.zip" "$fx/zips/takeout-20261110T224436Z-001.zip"
  mv "$fx/zips/part-02.zip" "$fx/zips/takeout-20261110T224438Z-1-001.zip"
  printf '# part\texpected\tfilename\n1\t3 MB\ttakeout-20261110T224436Z-001.zip\n2\tLESS1MB\ttakeout-20261110T224438Z-1-001.zip\n' >"$fx/parts.tsv"
  rm "$fx/zips/takeout-20261110T224438Z-1-001.zip"
  if run_verify_selftest_quiet "$fx" >"$fx/leg-rawmissing.log" 2>&1; then
    echo "FAIL: $leg (declared raw-named part missing but passed)"
    rc=1
  elif grep -q 'declared part missing from zips' "$fx/leg-rawmissing.log"; then
    echo "PASS: $leg (declared raw-named part missing fails explicitly)"
  else
    echo "FAIL: $leg (failed but not via the missing-part gate — see $fx/leg-rawmissing.log)"
    rc=1
  fi

  leg=undeclared-zip
  build_fixture
  cp "$fx/zips/part-01.zip" "$fx/zips/takeout-stray-999.zip"
  if run_verify_selftest_quiet "$fx" >"$fx/leg-undeclared.log" 2>&1 &&
    grep -q 'not declared in parts.tsv' "$fx/leg-undeclared.log" &&
    grep -q 'G2 GREEN' "$fx/leg-undeclared.log"; then
    echo "PASS: $leg (undeclared zip WARNs, run stays green)"
  else
    echo "FAIL: $leg (undeclared zip not warned or run wrongly failed — see $fx/leg-undeclared.log)"
    rc=1
  fi

  if [ "$rc" -eq 0 ]; then
    rm -rf "$fx"
    echo "SELFTEST GREEN"
  else
    echo "SELFTEST RED (fixture kept at $fx for inspection)"
  fi
  return $rc
}

run_verify_selftest_quiet() {
  # subshell: run_verify's die() on negative legs must not kill the selftest driver.
  # Output is NOT discarded here — the caller redirects to a per-leg log and greps it.
  # $2 = manifest mode (auto | racedriver8k).
  (run_verify "$1" 1 "${2:-auto}")
}

main() {
  if [ "${1:-}" = "--selftest" ]; then
    command -v zip >/dev/null || die "selftest needs zip on PATH (nix shell nixpkgs#zip)"
    selftest
    return
  fi
  local root="" do_hash=1 manifest_mode=auto
  while [ $# -gt 0 ]; do
    case $1 in
    --no-hash) do_hash=0 ;;
    --manifest)
      shift
      [ $# -gt 0 ] || die "--manifest needs a value (racedriver8k)"
      manifest_mode=$1
      ;;
    --manifest=*) manifest_mode=${1#*=} ;;
    -*) die "unknown option: $1" ;;
    *)
      [ -z "$root" ] || die "unexpected argument: $1"
      root=$1
      ;;
    esac
    shift
  done
  [ -n "$root" ] || die "usage: $0 <staging-dir> [--no-hash] [--manifest racedriver8k] | --selftest"
  case $manifest_mode in
  auto | racedriver8k) ;;
  *) die "unknown manifest '$manifest_mode' (accepts: racedriver8k)" ;;
  esac
  run_verify "$root" "$do_hash" "$manifest_mode"
}

main "$@"
