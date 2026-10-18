#!/usr/bin/env bash
# Fixture test for the drive-paperless ingest pipeline + the google-sync
# config-check go-live gate.
#
# Usage: test-drive-paperless.sh <ingest-main> <ingest-batch1> <ingest-cap1> <google-sync-config-check>
#
# The three ingest variants are the REAL rendered wrappers (writeShellApplication,
# shellcheck already ran at build time) with (a) the curl wrapper-PATH entry
# sed-prepended with a stub bin dir (controlled API responses, arg logging,
# failure injection) and (b) the baked /mnt/pool source paths sed-rewritten
# onto scratch trees (discordsync-attachments-migrate fixture pattern).
# jq/coreutils/find/grep stay REAL from the wrapper PATH.
#
# Legs:
#   1  happy path: 3 docs uploaded (pdf/docx/txt), extensions+images+zip
#      skipped, metadata fields asserted, journal written, second run = 0
#      uploads (idempotent), last_success touched, missing second source
#      (gwork) skipped without failing the run
#   2  batch cap 1: exactly one upload per run, sorted order, drain over runs
#   3  size cap 1MB: oversized file skipped
#   4  upload failure injection: unit exits non-zero, no journal advance,
#      no last_success, failed.log populated
#   5  changed file size re-uploads (Drive revision semantics)
#   6  google-sync config-check: placeholder INI fails with checklist
#      pointer, valid 3-remote INI passes, missing remote fails
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

MAIN_SCRIPT="${1:?usage: test-drive-paperless.sh <main> <batch1> <cap1> <gs-config-check>}"
BATCH1_SCRIPT="${2:?}"
CAP1_SCRIPT="${3:?}"
GS_CONFIG_CHECK="${4:?}"

scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
stub="$scratch/stub"
mirror="$scratch/mirror"
state="$scratch/state"
log="$scratch/curl-invocations.log"
counter="$scratch/id-counter"
mkdir -p "$stub/bin" "$mirror/sub" "$state"

# --- stub curl: logs one INV line per call, serves canned responses -------
# Shebang is rewritten to the sandbox bash (/usr/bin/env does not exist in
# the nix build sandbox — proven live 2026-10-19).
cat >"$stub/bin/curl" <<'STUB'
#!/STUB_SHEBANG_PLACEHOLDER
log="${CURL_LOG:?stub curl needs CURL_LOG}"
{
  printf 'INV BEGIN\n'
  for a in "$@"; do printf 'ARG [%s]\n' "$a"; done
  printf 'INV END\n'
} >>"$log"
if [[ "$*" == *"post_document"* ]]; then
  if [ -n "${CURL_FAIL_DOCUMENT:-}" ]; then
    echo "stub curl: injected failure" >&2
    exit 22
  fi
  printf 'ok\n'
  exit 0
fi
if [[ "$*" == *"-X POST"* ]]; then
  n="$(cat "${CURL_COUNTER:?stub curl needs CURL_COUNTER}" 2>/dev/null || echo 100)"
  n=$((n + 1))
  echo "$n" >"$CURL_COUNTER"
  printf '{"id": %d, "name": "created-%d"}\n' "$n" "$n"
  exit 0
fi
if [[ "$*" == *"/api/correspondents/"* ]] || [[ "$*" == *"/api/tags/"* ]]; then
  printf '{"count": 0, "results": []}\n'
  exit 0
fi
printf 'ok\n'
STUB
chmod +x "$stub/bin/curl"
sed -i "1s|.*|#!$(command -v bash)|" "$stub/bin/curl"

inv_count() { grep -c '^INV BEGIN' "$log" 2>/dev/null || true; }
docs_uploaded() { grep -c 'ARG \[http://127.0.0.1:1/api/documents/post_document/\]' "$log" 2>/dev/null || true; }
reset_log() { : >"$log"; }

# prep <script> <out>: PATH-stub + source-path rewrite onto scratch
prep() {
  sed -e "s|^export PATH=\"|export PATH=\"$stub/bin:|" \
    -e "s|/mnt/pool/backups/google-drive-work|$scratch/nonexistent-gwork|g" \
    -e "s|/mnt/pool/backups/google-drive|$mirror|g" "$1" >"$2"
  chmod +x "$2"
}

run_ingest() { # <prepared-script> [extra env as VAR=val before script? no — via env command]
  env \
    DRIVE_PAPERLESS_URL="http://127.0.0.1:1" \
    DRIVE_PAPERLESS_TOKEN="testtoken" \
    DRIVE_PAPERLESS_STATE="$state" \
    CURL_LOG="$log" \
    CURL_COUNTER="$counter" \
    bash "$1"
}

# --- fixture tree ----------------------------------------------------------
printf '%%PDF-1.4 test a' >"$mirror/a.pdf"
printf 'doc b' >"$mirror/sub/b.docx"
printf 'text c' >"$mirror/c.txt"
printf 'photo bytes' >"$mirror/photo.jpg"
printf 'video bytes' >"$mirror/video.mp4"
printf 'zip bytes' >"$mirror/takeout-2026.zip"
printf 'x' >"$mirror/$(printf 'we\nird').pdf"
touch -d '2024-03-05 12:00' "$mirror/a.pdf"

prep "$MAIN_SCRIPT" "$scratch/main.sh"
prep "$BATCH1_SCRIPT" "$scratch/batch1.sh"
prep "$CAP1_SCRIPT" "$scratch/cap1.sh"

# big file for the size-cap variant (2MB > 1MB cap)
head -c 2097152 /dev/zero >"$mirror/toolarge.pdf" 2>/dev/null || dd if=/dev/zero of="$mirror/toolarge.pdf" bs=1024 count=2048 status=none

echo "== leg 1: happy path =="
out="$(run_ingest "$scratch/main.sh")" || fail "leg1: run exited non-zero: $out"
echo "$out" | grep -q 'uploaded=4' || fail "leg1: expected uploaded=4 (incl. 2MB toolarge.pdf under the 100MB cap), got: $out"
echo "$out" | grep -q 'failed=0' || fail "leg1: expected failed=0"
echo "$out" | grep -q 'missing_source=1' || fail "leg1: expected missing_source=1 (absent gwork source)"
[ -f "$state/last_success" ] || fail "leg1: last_success not touched"
[ "$(wc -l <"$state/journal.tsv")" -eq 4 ] || fail "leg1: journal must have 4 lines, has $(wc -l <"$state/journal.tsv")"
grep -q $'gdrive\ta.pdf\t' "$state/journal.tsv" || fail "leg1: a.pdf not journaled"
# uploads in sorted order, correct fields
grep -q 'ARG \[document=@'"$mirror"'/a.pdf\]' "$log" || fail "leg1: a.pdf not uploaded"
grep -q 'ARG \[document=@'"$mirror"'/c.txt\]' "$log" || fail "leg1: c.txt not uploaded"
grep -q 'ARG \[document=@'"$mirror"'/sub/b.docx\]' "$log" || fail "leg1: sub/b.docx not uploaded"
grep -q 'ARG \[title=b\]' "$log" || fail "leg1: title=b (stem) missing"
grep -Eq 'ARG \[created=[0-9]{4}-[0-9]{2}-[0-9]{2}\]' "$log" || fail "leg1: created date field missing"
grep -Eq 'ARG \[correspondent=[0-9]+\]' "$log" || fail "leg1: correspondent field missing"
# two tags per upload (global + source)
tag_args=$(grep -Ec 'ARG \[tags=[0-9]+\]' "$log" || true)
[ "$tag_args" -ge 8 ] || fail "leg1: expected >=8 tags args (4 docs x 2), got $tag_args"
# skips: image, video, zip, newline-name
grep -q 'photo.jpg' "$log" && fail "leg1: photo.jpg must be skipped (images off)"
grep -q 'video.mp4' "$log" && fail "leg1: video.mp4 must be skipped"
grep -q 'takeout' "$log" && fail "leg1: takeout zip must be skipped"
grep -q 'ird.pdf' "$log" && fail "leg1: newline-in-name file must be skipped"
# metadata ensured via API before uploads
grep -q '/api/correspondents/' "$log" || fail "leg1: correspondent ensure call missing"
grep -q '/api/tags/' "$log" || fail "leg1: tag ensure call missing"
first_doc=$(grep -n 'post_document' "$log" | head -1 | cut -d: -f1)
first_tag=$(grep -n '/api/tags/' "$log" | head -1 | cut -d: -f1)
[ "$first_tag" -lt "$first_doc" ] || fail "leg1: metadata must be ensured before uploads"

echo "== leg 1b: idempotent second run =="
reset_log
out="$(run_ingest "$scratch/main.sh")" || fail "leg1b: second run exited non-zero"
echo "$out" | grep -q 'uploaded=0' || fail "leg1b: expected uploaded=0, got: $out"
[ "$(docs_uploaded)" -eq 0 ] || fail "leg1b: no upload calls expected"

echo "== leg 2: batch cap =="
state2="$scratch/state-batch1"
mkdir -p "$state2"
for i in 1 2 3 4; do
  reset_log
  env DRIVE_PAPERLESS_URL="http://127.0.0.1:1" DRIVE_PAPERLESS_TOKEN=t \
    DRIVE_PAPERLESS_STATE="$state2" CURL_LOG="$log" CURL_COUNTER="$counter" \
    bash "$scratch/batch1.sh" >"$scratch/batch1-$i.out" 2>&1 \
    || fail "leg2: run $i exited non-zero: $(cat "$scratch/batch1-$i.out")"
  [ "$(docs_uploaded)" -eq 1 ] || fail "leg2: run $i must upload exactly 1, got $(docs_uploaded)"
done
reset_log
env DRIVE_PAPERLESS_URL="http://127.0.0.1:1" DRIVE_PAPERLESS_TOKEN=t \
  DRIVE_PAPERLESS_STATE="$state2" CURL_LOG="$log" CURL_COUNTER="$counter" \
  bash "$scratch/batch1.sh" >"$scratch/batch1-5.out" 2>&1 \
  || fail "leg2: run 5 exited non-zero"
[ "$(docs_uploaded)" -eq 0 ] || fail "leg2: run 5 must upload 0 (queue drained)"
[ "$(wc -l <"$state2/journal.tsv")" -eq 4 ] || fail "leg2: journal must hold 4 after drain"

echo "== leg 3: size cap =="
state3="$scratch/state-cap1"
mkdir -p "$state3"
reset_log
env DRIVE_PAPERLESS_URL="http://127.0.0.1:1" DRIVE_PAPERLESS_TOKEN=t \
  DRIVE_PAPERLESS_STATE="$state3" CURL_LOG="$log" CURL_COUNTER="$counter" \
  bash "$scratch/cap1.sh" >"$scratch/cap1.out" 2>&1 \
  || fail "leg3: run exited non-zero: $(cat "$scratch/cap1.out")"
grep -q 'toolarge' "$log" && fail "leg3: oversized file must be skipped"

echo "== leg 4: upload failure =="
state4="$scratch/state-fail"
mkdir -p "$state4"
reset_log
env DRIVE_PAPERLESS_URL="http://127.0.0.1:1" DRIVE_PAPERLESS_TOKEN=t \
  DRIVE_PAPERLESS_STATE="$state4" CURL_LOG="$log" CURL_COUNTER="$counter" \
  CURL_FAIL_DOCUMENT=1 bash "$scratch/main.sh" >"$scratch/fail.out" 2>&1 \
  && fail "leg4: run must exit non-zero when uploads fail"
[ -f "$state4/last_success" ] && fail "leg4: last_success must NOT be touched on failures"
[ -s "$state4/failed.log" ] || fail "leg4: failed.log must record failures"
[ "$(wc -l <"$state4/journal.tsv" 2>/dev/null || echo 0)" -eq 0 ] || fail "leg4: journal must stay empty on failures"

echo "== leg 5: changed size re-uploads =="
printf '%%PDF-1.4 test a REVISED longer content' >"$mirror/a.pdf"
reset_log
out="$(run_ingest "$scratch/main.sh")" || fail "leg5: run exited non-zero"
echo "$out" | grep -q 'uploaded=1' || fail "leg5: expected uploaded=1 for revised a.pdf, got: $out"

echo "== leg 6: google-sync config-check =="
gsbad="$scratch/rclone-placeholder.conf"
cat >"$gsbad" <<'EOF'
[gdrive]
type = drive
token = REPLACE_WITH_TOKEN_JSON
EOF
if RCLONE_CONFIG_PATH="$gsbad" "$GS_CONFIG_CHECK" >"$scratch/gs1.out" 2>&1; then
  fail "leg6: placeholder config must fail the check"
fi
grep -q 'OAuth placeholders' "$scratch/gs1.out" || fail "leg6: failure must point at the go-live checklist"

gsok="$scratch/rclone-ok.conf"
cat >"$gsok" <<'EOF'
[gdrive]
type = drive
token = {"access_token":"x"}
[gdrive-shared]
type = drive
shared_with_me = true
token = {"access_token":"x"}
[gwork]
type = drive
team_drive = 0AAFake
token = {"access_token":"x"}
EOF
RCLONE_CONFIG_PATH="$gsok" "$GS_CONFIG_CHECK" >"$scratch/gs2.out" 2>&1 \
  || fail "leg6: valid 3-remote config must pass: $(cat "$scratch/gs2.out")"

gsmiss="$scratch/rclone-missing.conf"
cat >"$gsmiss" <<'EOF'
[gdrive]
type = drive
token = {"access_token":"x"}
[gdrive-shared]
type = drive
token = {"access_token":"x"}
EOF
if RCLONE_CONFIG_PATH="$gsmiss" "$GS_CONFIG_CHECK" >"$scratch/gs3.out" 2>&1; then
  fail "leg6: config missing a configured remote must fail"
fi
grep -q "remote 'gwork:' missing" "$scratch/gs3.out" || fail "leg6: failure must name the missing remote"

echo "PASS: drive-paperless fixture all legs green"
