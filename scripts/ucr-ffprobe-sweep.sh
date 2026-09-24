#!/usr/bin/env bash
# Full integrity sweep over the 591 UCR WAV call recordings on the pixel6 pool archive.
#
# Phases (all idle IO priority; wrap the whole thing in heavy-job at the caller):
#   1. sha256sum -c against the 2026-08-20 manifest (bitrot since extraction)
#   2. RIFF header parse: declared data-chunk size vs actual bytes available (truncation)
#   3. ffprobe metadata (codec / rate / channels / duration)
#   4. ffmpeg full decode to null (catches mid-stream corruption that headers miss)
#   5. reconcile vs index.csv + manifest vs disk, write encode manifest + summary
#
# Outputs under <root>/universal-call-recorder/integrity-sweep/:
#   sweep.jsonl            one JSON object per file
#   encode-manifest.tsv    filename, date_utc, contact, duration_s, verdict
#   summary.txt            human verdict
#   decode-stderr/         per-file ffmpeg stderr (empty when clean)
# Exit: 0 = all clean, 2 = problems found (reports still written), 1 = setup error.
#
# Run:  heavy-job scripts/ucr-ffprobe-sweep.sh
set -euo pipefail

ROOT="${UCR_ROOT:-/mnt/pool/backups/pixel6/2026-08-20}"
UCR_DIR="$ROOT/universal-call-recorder"
WAV_DIR="$ROOT/sdcard/Android/data/com.sparklingapps.callrecorder.full/files"
OUT="$UCR_DIR/integrity-sweep"
PARALLEL="${PARALLEL:-2}"

for tool in ffprobe ffmpeg sha256sum python3 ionice jq; do
  command -v "$tool" >/dev/null || {
    echo "FATAL: missing tool: $tool" >&2
    exit 1
  }
done
[ -d "$WAV_DIR" ] || {
  echo "FATAL: WAV dir missing: $WAV_DIR" >&2
  exit 1
}
[ -s "$UCR_DIR/SHA256SUMS" ] || {
  echo "FATAL: manifest missing: $UCR_DIR/SHA256SUMS" >&2
  exit 1
}
[ -s "$UCR_DIR/index.csv" ] || {
  echo "FATAL: index.csv missing" >&2
  exit 1
}

mkdir -p "$OUT" "$OUT/decode-stderr"
SHA_LOG="$OUT/sha256-verify.log"

PSI=$(awk '/^some avg10/{print int($2)}' /proc/pressure/io)
if [ "${PSI:-0}" -ge 20 ]; then
  echo "NOTE: io PSI some avg10=${PSI}% — idle priority keeps this harmless, but passes will be slow." >&2
fi

echo "== Phase 1: sha256 manifest verification (serial, idle priority)"
(
  cd "$WAV_DIR"
  ionice -c3 nice -n19 sha256sum -c "$UCR_DIR/SHA256SUMS" >"$SHA_LOG" 2>&1 || true
)
SHA_OK=$(grep -c ': OK$' "$SHA_LOG" || true)
SHA_BAD=$(grep -cv ': OK$' "$SHA_LOG" || true)
echo "   sha256: $SHA_OK OK, $SHA_BAD failed/missing"
export SHA_LOG

echo "== Phases 2-4: RIFF + ffprobe + full decode (parallel=$PARALLEL, idle priority)"

python3 - "$WAV_DIR" "$OUT" "$PARALLEL" <<'PYEOF'
import concurrent.futures as cf
import json, os, struct, subprocess, sys

wav_dir, out, parallel = sys.argv[1], sys.argv[2], int(sys.argv[3])
sweep_jsonl = os.path.join(out, "sweep.jsonl")
err_dir = os.path.join(out, "decode-stderr")

sha_ok_files = set()
with open(os.environ["SHA_LOG"]) as fh:
    for line in fh:
        line = line.rstrip()
        if line.endswith(": OK"):
            sha_ok_files.add(line[: -len(": OK")])

files = sorted(f for f in os.listdir(wav_dir) if f.lower().endswith(".wav"))


def riff_check(path):
    """Return (declared_data_size, bytes_after_header) or raises."""
    size = os.path.getsize(path)
    declared = None
    with open(path, "rb") as fh:
        riff = fh.read(12)
        if riff[0:4] != b"RIFF" or riff[8:12] != b"WAVE":
            raise ValueError("not a RIFF/WAVE file")
        while True:
            hdr = fh.read(8)
            if len(hdr) < 8:
                raise ValueError("RIFF chunk table runs past EOF (header itself truncated)")
            cid, csz = struct.unpack("<4sI", hdr)
            if cid == b"data":
                declared = csz
                break
            fh.seek(csz + (csz & 1), 1)
        after_header = size - fh.tell()
    return size, declared, after_header


def run(cmd, err_path=None):
    err_fh = open(err_path, "wb") if err_path else subprocess.DEVNULL
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=err_fh, stdin=subprocess.DEVNULL)
        return proc.returncode, proc.stdout
    finally:
        if err_fh is not subprocess.DEVNULL:
            err_fh.close()


IDLE = ["ionice", "-c3", "nice", "-n19"]


def sweep_one(fname):
    path = os.path.join(wav_dir, fname)
    rec = {"file": fname, "verdict": "OK"}

    try:
        size, declared, after_header = riff_check(path)
        rec.update(actual_size=size, header_data_size=declared,
                   bytes_after_header=after_header)
        if declared is not None and after_header < declared:
            rec["verdict"] = "TRUNCATED"
    except (ValueError, OSError) as e:
        rec["verdict"] = "HEADER_ERROR"
        rec["header_error"] = str(e)
        rec["decode_ok"] = False
        rec["decode_errors"] = [str(e)]
        rec["sha_ok"] = fname in sha_ok_files
        return rec

    rc, pout = run(IDLE + ["ffprobe", "-v", "error", "-print_format", "json",
                           "-show_format", "-show_streams", "-select_streams", "a:0", path],
                   os.path.join(err_dir, fname + ".probe.err"))
    try:
        probe = json.loads(pout)
    except json.JSONDecodeError:
        probe = {}
    st = (probe.get("streams") or [{}])[0]
    fmt = probe.get("format") or {}
    rec.update(codec=st.get("codec_name", "none"),
               sample_rate=int(st.get("sample_rate", 0) or 0),
               channels=int(st.get("channels", 0) or 0),
               bits_per_sample=int(st.get("bits_per_sample", 0) or 0),
               duration_s=float(fmt.get("duration", 0) or 0))

    err_path = os.path.join(err_dir, fname + ".err")
    open(err_path, "wb").close()  # truncate from any previous run
    rc, _ = run(IDLE + ["ffmpeg", "-nostdin", "-hide_banner", "-v", "error",
                        "-i", path, "-map", "0:a:0", "-f", "null", "-"], err_path)
    rec["decode_ok"] = rc == 0
    with open(err_path, "rb") as fh:
        raw_errors = [l.decode("utf-8", "replace") for l in fh.read().splitlines() if l.strip()]
    rec["decode_errors"] = raw_errors

    if rec["verdict"] == "OK":
        if rc != 0:
            rec["verdict"] = "DECODE_ERROR"
        elif raw_errors:
            rec["verdict"] = "DECODE_WARNINGS"

    rec["sha_ok"] = fname in sha_ok_files
    if rec["verdict"] == "OK" and not rec["sha_ok"]:
        rec["verdict"] = "SHA_MISMATCH"
    return rec


with open(sweep_jsonl, "w") as out_fh:
    with cf.ThreadPoolExecutor(max_workers=parallel) as pool:
        futures = {pool.submit(sweep_one, f): f for f in files}
        done = 0
        for fut in cf.as_completed(futures):
            rec = fut.result()
            out_fh.write(json.dumps(rec) + "\n")
            out_fh.flush()
            done += 1
            if done % 50 == 0:
                print(f"   {done}/{len(files)} swept", flush=True)
print(f"   {len(files)}/{len(files)} swept")
PYEOF

echo "== Phase 5: reconcile + encode manifest + summary"
python3 - "$UCR_DIR" "$OUT" "$WAV_DIR" "$SHA_OK" "$SHA_BAD" <<'PYEOF'
import csv, json, os, sys

ucr_dir, out, wav_dir = sys.argv[1], sys.argv[2], sys.argv[3]
sha_ok, sha_bad = sys.argv[4], sys.argv[5]

idx = {}
with open(os.path.join(ucr_dir, "index.csv"), newline="") as fh:
    for row in csv.DictReader(fh):
        idx[row["filename"]] = row

records = sorted((json.loads(l) for l in open(os.path.join(out, "sweep.jsonl")) if l.strip()),
                 key=lambda r: r["file"])
swept = {r["file"] for r in records}
on_disk = {f for f in os.listdir(wav_dir) if f.lower().endswith(".wav")}
in_manifest = set()
with open(os.path.join(ucr_dir, "SHA256SUMS")) as fh:
    for line in fh:
        if line.strip():
            in_manifest.add(line.rstrip("\n").split("  ", 1)[1])

dur_notes = []
verdicts = {}
for r in records:
    verdicts[r["verdict"]] = verdicts.get(r["verdict"], 0) + 1
    i = idx.get(r["file"])
    if i:
        try:
            if abs(float(i["duration_s"]) - r.get("duration_s", 0)) > 2.0:
                dur_notes.append((r["file"], i["duration_s"], r.get("duration_s")))
        except (ValueError, TypeError):
            pass

with open(os.path.join(out, "encode-manifest.tsv"), "w", newline="") as fh:
    w = csv.writer(fh, delimiter="\t")
    w.writerow(["filename", "date_time_utc", "contact_or_number", "duration_s", "verdict"])
    for r in records:
        i = idx.get(r["file"], {})
        w.writerow([r["file"], i.get("date_time_utc", ""),
                    i.get("contact_or_number", ""), r.get("duration_s", 0), r["verdict"]])

problems = [r for r in records if r["verdict"] != "OK"]
missing_on_disk = sorted(in_manifest - on_disk)
unmanifested = sorted(on_disk - in_manifest)
not_swept = sorted(in_manifest - swept)

lines = [f"UCR WAV integrity sweep — {len(records)} files swept",
         f"verdicts: {verdicts}",
         f"sha256: {sha_ok} OK / {sha_bad} failed-or-missing",
         f"manifest vs disk: {len(missing_on_disk)} missing, {len(unmanifested)} unmanifested",
         f"index.csv duration mismatches >2s: {len(dur_notes)}"]
for name, a, b in dur_notes[:10]:
    lines.append(f"  duration drift: {name}: index={a}s probed={b}s")
if missing_on_disk:
    lines.append("MISSING (in manifest, not on disk): " + ", ".join(missing_on_disk[:10]))
if unmanifested:
    lines.append("UNMANIFESTED (on disk, not in manifest): " + ", ".join(unmanifested[:10]))
if not_swept:
    lines.append("NOT SWEPT: " + ", ".join(not_swept[:10]))
if problems:
    lines.append("")
    lines.append("PROBLEM FILES:")
    for r in problems:
        first_err = (r.get("decode_errors") or [""])[0][:100]
        lines.append(f"  {r['verdict']:16} {r['file']}  {first_err}")
lines.append("")
lines.append("VERDICT: " + ("CLEAN — every file header-consistent, fully decodable, hash-matched"
                          if not problems and not missing_on_disk and not unmanifested and not not_swept
                          else f"{len(problems)} problem file(s), see above"))
open(os.path.join(out, "summary.txt"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(2 if (problems or missing_on_disk or unmanifested or not_swept) else 0)
PYEOF
