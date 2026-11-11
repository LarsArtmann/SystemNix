#!/usr/bin/env bash
# print-safe fault-injection test — proves the 2026-11-10 hardening fires.
#
# Exercises the two observed imagetoraster failure modes (2026-11-10
# incident, see tracking-papers docs/printer-log.md):
#   attempt 1: crash with EMPTY output          -> bad-magic validation catches it
#   attempt 2: crash with a TRUNCATED raster    -> exact-size validation catches it
#   attempt 3: delegates to the real filter     -> pipeline completes
#
# Requires: the real host filters + PPD (production paths), a rebuilt
# print-safe with PRINT_SAFE_FILTER_DIR support, poppler (pdftoppm),
# python3, coreutils. Runs print-safe in DRY RUN — nothing reaches the
# printer.
#
# Usage: bash pkgs/print-safe-fault-test.sh [path-to-print-safe]
set -euo pipefail

PS="${1:-$HOME/.local/bin/print-safe}"
REAL_FILTER_DIR="/var/lib/cups/path/lib/cups/filter"
STUB="$(mktemp -d /tmp/print-safe-fault.XXXXXX)"
trap 'rm -rf "$STUB" "$WORK"' EXIT
WORK="$(mktemp -d /tmp/print-safe-fault-work.XXXXXX)"

fail() {
  echo "FAULT-TEST FAIL: $*" >&2
  exit 1
}

# Stub dir: rastertogutenprint delegates straight through; imagetoraster
# injects two failures then delegates.
ln -s "$REAL_FILTER_DIR/rastertogutenprint.5.3" "$STUB/rastertogutenprint.5.3"
cat >"$STUB/imagetoraster" <<'STUB'
#!/usr/bin/env bash
COUNT_FILE="${PS_FAULT_COUNT:?PS_FAULT_COUNT must be set}"
REAL="/var/lib/cups/path/lib/cups/filter/imagetoraster"
n=$(($(cat "$COUNT_FILE" 2>/dev/null || echo 0) + 1))
echo "$n" > "$COUNT_FILE"
# stdout is the raster (caller redirects to page.raster).
case $n in
  1) exit 1 ;;                                              # empty output
  2) printf '3Sa'; dd if=/dev/zero bs=1k count=2000 2>/dev/null
     exit 1 ;;                                              # valid magic, wrong size
  *) exec "$REAL" "$@" ;;
esac
STUB
chmod +x "$STUB/imagetoraster"

# Minimal blank single-page PDF (renders a white A4-ish page).
cat >"$WORK/blank.pdf" <<'PDF'
%PDF-1.4
1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] >> endobj
xref
0 4
trailer << /Size 4 /Root 1 0 R >>
%%EOF
PDF

COUNT=0
export PS_FAULT_COUNT="$STUB/count"
echo 0 >"$PS_FAULT_COUNT"

OUT="$WORK/out"
export PRINT_SAFE_FILTER_DIR="$STUB"
PRINT_SAFE_DRY_RUN=1 "$PS" "$WORK/blank.pdf" >"$OUT.stdout" 2>"$OUT.stderr" &&
  PASS=1 || PASS=0
unset PRINT_SAFE_FILTER_DIR

grep -q "attempt 1 failed validation" "$OUT.stderr" || fail "no retry log for attempt 1 (empty-output crash)"
grep -q "attempt 2 failed validation" "$OUT.stderr" || fail "no retry log for attempt 2 (truncated crash)"
grep -q "dry run — stream verified" "$OUT.stdout" || fail "dry run did not complete after retries"
[ "$PASS" = 1 ] || fail "print-safe exited nonzero despite eventual success"
n=$(cat "$PS_FAULT_COUNT")
[ "$n" -ge 3 ] || fail "imagetoraster stub called only $n times — expected >= 3"

echo "FAULT-TEST PASS: empty-crash and truncated-crash both retried, pipeline completed on attempt 3 ($n stub calls)"
