#!/usr/bin/env bash
# Full integrity sweep over the 591 UCR WAV call recordings on the pixel6 pool archive.
#
# Phases (all idle IO priority; wrap the whole thing in heavy-job at the caller):
#   1. sha256sum -c against the 2026-08-20 manifest (bitrot since extraction)
#   2. RIFF header parse: declared data-chunk size vs actual file size (truncation)
#   3. ffprobe metadata (codec/rate/channels/real duration)
#   4. ffmpeg full decode to null (catches mid-stream corruption headers miss)
#
# Outputs under <root>/universal-call-recorder/integrity-sweep/:
#   sweep.jsonl            one JSON object per file
#   encode-manifest.tsv    filename, contact, date_utc, duration_s, ok-to-encode
#   summary.txt            human verdict
# Exit: 0 = all clean, 2 = problems found (reports still written), 1 = setup error.
#
# Run:  heavy-job nix run .#ucr-ffprobe-sweep   (or bash scripts/ucr-ffprobe-sweep.sh)
set -euo pipefail

ROOT="${UCR_ROOT:-/mnt/pool/backups/pixel6/2026-08-20}"
UCR_DIR="$ROOT/universal-call-recorder"
WAV_DIR="$ROOT/sdcard/Android/data/com.sparklingapps.callrecorder.full/files"
OUT="$UCR_DIR/integrity-sweep"
PARALLEL="${PARALLEL:-2}"

for tool in ffprobe ffmpeg sha256sum python3 ionice; do
  command -v "$tool" >/dev/null || { echo "FATAL: missing tool: $tool" >&2; exit 1; }
done
[ -d "$WAV_DIR" ] || { echo "FATAL: WAV dir missing: $WAV_DIR" >&2; exit 1; }
[ -s "$UCR_DIR/SHA256SUMS" ] || { echo "FATAL: manifest missing: $UCR_DIR/SHA256SUMS" >&2; exit 1; }
[ -s "$UCR_DIR/index.csv" ] || { echo "FATAL: index.csv missing" >&2; exit 1; }

mkdir -p "$OUT"
SWEEP_JSONL="$OUT/sweep.jsonl"
TSV="$OUT/encode-manifest.tsv"
SUMMARY="$OUT/summary.txt"
DECODE_ERRS="$OUT/decode-stderr"
mkdir -p "$DECODE_ERRS"
: > "$SWEEP_JSONL"

PSI=$(awk '/^some avg10/{print int($2)}' /proc/pressure/io)
if [ "$PSI" -ge 20 ]; then
  echo "NOTE: io PSI some avg10=${PSI}% — running at idle priority anyway; expect slow passes." >&2
fi

echo "== Phase 1: sha256 manifest verification (idle priority, serial)"
SHA_LOG="$OUT/sha256-verify.log"
(
  cd "$WAV_DIR"
  ionice -c3 nice -n19 sha256sum -c "$UCR_DIR/SHA256SUMS" > "$SHA_LOG" 2>&1 || true
)
SHA_FAILED=$(grep -cv ': OK$' "$SHA_LOG" || true)
SHA_OK=$(grep -c ': OK$' "$SHA_LOG" || true)
echo "   sha256: $SHA_OK OK, $SHA_FAILED failed/missing"

echo "== Phases 2-4: RIFF header + ffprobe + full decode (parallel=$PARALLEL, idle priority)"

export OUT SWEEP_JSONL DECODE_ERRS WAV_DIR PARALLEL

per_file() {
  f="$1"
  path="$WAV_DIR/$f"
  base="${f%.wav}"
  errfile="$DECODE_ERRS/$base.err"

  python3 - "$path" <<'PYEOF' > "$OUT/.hdr.json" 2>>"$OUT/.hdr-errors.log" || { echo "{\"file\": \"$f\", \"verdict\": \"HEADER_PARSE_ERROR\"}"; exit 0; }
import json, struct, sys
path = sys.argv[1]
info = {"file": path.split("/")[-1]}
try:
    size = __import__("os").path.getsize(path)
    info["actual_size"] = size
    with open(path, "rb") as fh:
        riff = fh.read(12)
        if riff[0:4] != b"RIFF" or riff[8:12] != b"WAVE":
            info["header_error"] = "not a RIFF/WAVE file"
        else:
            declared = None
            while True:
                hdr = fh.read(8)
                if len(hdr) < 8:
                    break
                cid, csz = struct.unpack("<4sI", hdr)
                if cid == b"data":
                    declared = csz
                    break
                fh.seek(csz + (csz & 1), 1)
            info["header_data_size"] = declared
            if declared is not None and size - (fh.tell()) < declared - (declared and 0):
                # position check done below via actual bytes available after header
                pass
            info["bytes_available_after_header"] = max(0, size - fh.tell())
            if declared is not None:
                info["truncated"] = size - fh.tell() < declared
except Exception as e:  # noqa: BLE001
    info["header_error"] = str(e)
print(json.dumps(info))
PYEOF

  hdr=$(cat "$OUT/.hdr.json")
  truncated=$(echo "$hdr" | jq -r '.truncated // false')

  probe=$(ionice -c3 nice -n19 ffprobe -v error -print_format json -show_format -show_streams -select_streams a:0 "$path" 2>"$errfile.probe" || echo '{}')
  codec=$(echo "$probe" | jq -r '.streams[0].codec_name // "none"')
  rate=$(echo "$probe" | jq -r '.streams[0].sample_rate // "0"')
  ch=$(echo "$probe" | jq -r '.streams[0].channels // "0"')
  bits=$(echo "$probe" | jq -r '.streams[0].bits_per_sample // "0"')
  dur=$(echo "$probe" | jq -r '.format.duration // "0"')

  : > "$errfile"
  ionice -c3 nice -n19 ffmpeg -nostdin -hide_banner -v error -i "$path" -map 0:a:0 -f null - 2>>"$errfile" || rc=$?
  rc="${rc:-0}"
  unset rc

  errs=$(jq -R . "$errfile" 2>/dev/null | jq -s . || echo '[]')
  nerr=$(echo "$errs" | jq 'length')

  verdict="OK"
  [ "$truncated" = "true" ] && verdict="TRUNCATED"
  [ "$rc" -ne 0 ] && verdict="DECODE_ERROR"
  [ "$truncated" = "false" ] && [ "$rc" -eq 0 ] && [ "$nerr" -gt 0 ] && verdict="DECODE_WARNINGS"
  sha_line=$(grep -F "  $f" "$SHA_LOG" | tail -1 || true)
  case "$sha_line" in
    *": OK") sha_ok=true ;;
    *) sha_ok=false; [ "$verdict" = "OK" ] && verdict="SHA_MISMATCH" ;;
  esac

  jq -n \
    --arg file "$f" --argjson hdr "$hdr" \
    --arg codec "$codec" --arg rate "$rate" --arg ch "$ch" --arg bits "$bits" \
    --arg dur "$dur" --argjson decode_ok "$([ "$rc" -eq 0 ] && echo true || echo false)" \
    --argjson errors "$errs" --arg verdict "$verdict" --argjson sha_ok "$sha_ok" \
    '{file: $file} + $hdr + {codec: $codec, sample_rate: ($rate|tonumber? // 0),
      channels: ($ch|tonumber? // 0), bits_per_sample: ($bits|tonumber? // 0),
      duration_s: ($dur|tonumber? // 0), decode_ok: $decode_ok,
      decode_errors: $errors, sha_ok: $sha_ok, verdict: $verdict}' >> "$SWEEP_JSONL"
}
export -f per_file

cat "$UCR_DIR/SHA256SUMS" | awk '{print $2}' | \
  xargs -P "$PARALLEL" -I{} bash -c 'per_file "$@"' _ {}

echo "== Phase 5: reconcile with index.csv + write encode manifest + summary"
python3 - "$UCR_DIR" "$OUT" <<'PYEOF'
import csv, json, sys
ucr_dir, out = sys.argv[1], sys.argv[2]

idx = {}
with open(f"{ucr_dir}/index.csv", newline="") as fh:
    for row in csv.DictReader(fh):
        idx[row["filename"]] = row

records = [json.loads(l) for l in open(f"{out}/sweep.jsonl") if l.strip()]
records.sort(key=lambda r: r["file"])

verdicts = {}
dur_notes = 0
for r in records:
    v = r["verdict"]
    verdicts[v] = verdicts.get(v, 0) + 1
    i = idx.get(r["file"])
    if i and abs(float(i["duration_s"]) - r.get("duration_s", 0)) > 2.0:
        dur_notes += 1

with open(f"{out}/encode-manifest.tsv", "w", newline="") as fh:
    w = csv.writer(fh, delimiter="\t")
    w.writerow(["filename", "date_time_utc", "contact_or_number", "duration_s", "verdict"])
    for r in records:
        i = idx.get(r["file"], {})
        w.writerow([r["file"], i.get("date_time_utc", ""),
                    i.get("contact_or_number", ""), r.get("duration_s", 0), r["verdict"]])

problems = [r for r in records if r["verdict"] != "OK"]
lines = []
lines.append(f"UCR WAV integrity sweep — {len(records)} files")
lines.append(f"verdicts: {verdicts}")
lines.append(f"sha256: {SHA_OK} OK / {SHA_FAILED} failed")
lines.append(f"index.csv duration mismatches >2s: {dur_notes}")
if problems:
    lines.append("")
    lines.append("PROBLEM FILES:")
    for r in problems:
        lines.append(f"  {r['verdict']:16} {r['file']}  errors={len(r.get('decode_errors', []))}")
lines.append("")
lines.append("VERDICT: " + ("CLEAN — all files decode fully" if not problems else f"{len(problems)} PROBLEM FILE(S)"))
open(f"{out}/summary.txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(2 if problems else 0)
PYEOF
