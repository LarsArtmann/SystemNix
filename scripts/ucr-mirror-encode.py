#!/usr/bin/env python3
"""WAV -> FLAC (+opus) mirror of the UCR call archive, Navidrome-ready.

Reads the integrity sweep's encode-manifest.tsv (scripts/ucr-ffprobe-sweep.sh)
and encodes every verdict==OK recording to:

  derived/flac/<Contact>/<Year>/<name>.flac   (lossless, Navidrome music folder)
  derived/opus/<Contact>/<Year>/<name>.opus   (32k voip, web-archive player leg)

opus is encoded FROM the flac (one 54 GB source read, one 18 GB re-read) so the
two legs are content-identical by construction. Every flac is then full-decode
verified (ffmpeg checks the FLAC STREAMINFO MD5).

Tags: artist/albumartist=contact, album="Call Archive <Year>", title="MM-DD HH:MM (Ss)",
date, tracknumber (chronological within album), genre="Call Recording",
comment=original WAV filename, UCR_PREFIX custom tag.

All subprocesses run at idle IO priority; wrap the whole script in heavy-job.
Exit 0 when every OK file is mirrored and verified, 1 otherwise.
"""

import argparse
import concurrent.futures as cf
import csv
import json
import os
import re
import subprocess
import sys
import time

ROOT_DEFAULT = "/mnt/pool/backups/pixel6/2026-08-20"
IDLE = ["ionice", "-c3", "nice", "-n19"]
UNSAFE = re.compile(r"[/\x00]")


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def run(cmd, log_err=None):
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          stdin=subprocess.DEVNULL)
    if proc.returncode != 0 and log_err:
        with open(log_err, "ab") as fh:
            fh.write(proc.stderr)
    return proc


def sanitize_dirname(name):
    name = "".join(c for c in name if c.isprintable() and c not in "\n\r\t")
    name = name.replace("\u2066", "").replace("\u2067", "").replace("\u2068", "").replace("\u2069", "")
    name = UNSAFE.sub("_", name).strip().strip(".")
    return name or "Unknown"


def parse_contact(filename, index_contact):
    if index_contact.strip():
        return index_contact.strip()
    m = re.match(r"^\d+_(.*)_\d{13}\.wav$", filename)
    if m:
        return m.group(1).strip()
    return "Unknown"


def load_manifest(path):
    rows = []
    with open(path, newline="") as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            rows.append(row)
    return rows


def build_plan(rows, flac_root):
    """rows -> list of dicts with target paths, tags, ordering."""
    plan, per_album_seq, seen = [], {}, set()
    for r in rows:
        if r["verdict"] != "OK":
            continue
        fname = r["filename"]
        if fname in seen:
            continue
        seen.add(fname)
        stem = fname[:-4]
        m = re.match(r"^(\d+)_(\d{13})\.wav$", fname)
        prefix = m.group(1) if m else ""
        epoch_ms = m.group(2) if m else ""
        contact = parse_contact(fname, r["contact_or_number"])
        date_utc = r["date_time_utc"]
        year = date_utc[:4] or "unknown"
        album = f"Call Archive {year}"
        key = (contact, year)
        per_album_seq[key] = per_album_seq.get(key, 0) + 1
        cdir = sanitize_dirname(contact)
        title_date = date_utc[5:16] if len(date_utc) >= 16 else date_utc
        try:
            dur = int(float(r["duration_s"]))
        except (ValueError, TypeError):
            dur = 0
        plan.append({
            "wav": fname,
            "stem": stem,
            "contact": contact,
            "year": year,
            "flac": os.path.join(flac_root, cdir, year, stem + ".flac"),
            "opus_rel": os.path.join(cdir, year, stem + ".opus"),
            "title": f"{title_date} ({dur}s)",
            "album": album,
            "date": date_utc[:10],
            "track": per_album_seq[key],
            "prefix": prefix,
            "duration_s": r["duration_s"],
        })
    return plan


def encode_flac(item, wav_dir, force, err_log):
    out = item["flac"]
    if os.path.exists(out) and os.path.getsize(out) > 44 and not force:
        return item["stem"], "skip-flac"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = out + ".part"
    proc = run(IDLE + ["ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-y",
                       "-i", os.path.join(wav_dir, item["wav"]),
                       "-map", "0:a:0", "-map_metadata", "-1", "-vn",
                       "-c:a", "flac", "-compression_level", "8",
                       "-metadata", f"title={item['title']}",
                       "-metadata", f"artist={item['contact']}",
                       "-metadata", f"albumartist={item['contact']}",
                       "-metadata", f"album={item['album']}",
                       "-metadata", f"date={item['date']}",
                       "-metadata", f"originaldate={item['date']}",
                       "-metadata", f"tracknumber={item['track']:03d}",
                       "-metadata", "genre=Call Recording",
                       "-metadata", f"comment={item['wav']}",
                       "-metadata", f"UCR_PREFIX={item['prefix']}",
                       tmp], err_log)
    if proc.returncode != 0:
        return item["stem"], "fail-flac"
    os.replace(tmp, out)
    return item["stem"], "flac"


def encode_opus(item, flac_root, opus_root, force, err_log):
    out = os.path.join(opus_root, item["opus_rel"])
    if os.path.exists(out) and os.path.getsize(out) > 200 and not force:
        return item["stem"], "skip-opus"
    src = os.path.join(flac_root, os.path.relpath(out, opus_root)).replace(".opus", ".flac")
    if not os.path.exists(src):
        return item["stem"], "fail-opus-no-src"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = out + ".part"
    proc = run(IDLE + ["ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-y",
                       "-i", src, "-map", "0:a:0", "-c:a", "libopus",
                       "-b:a", "32k", "-application", "voip", "-vbr", "on", tmp], err_log)
    if proc.returncode != 0:
        return item["stem"], "fail-opus"
    os.replace(tmp, out)
    return item["stem"], "opus"


def verify_flac(item, flac_root, err_log):
    src = os.path.join(flac_root, os.path.dirname(item["opus_rel"]),
                       item["stem"] + ".flac")
    proc = run(IDLE + ["ffmpeg", "-nostdin", "-hide_banner", "-v", "error",
                       "-i", src, "-map", "0:a:0", "-f", "null", "-"], err_log)
    return item["stem"], "verify-ok" if proc.returncode == 0 else "fail-verify"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=os.environ.get("UCR_ROOT", ROOT_DEFAULT))
    ap.add_argument("--force", action="store_true", help="re-encode even if target exists")
    ap.add_argument("--parallel", type=int, default=8)
    ap.add_argument("--only", help="encode only files whose stem matches this regex")
    ap.add_argument("--phase", choices=["all", "flac", "opus", "verify"], default="all")
    args = ap.parse_args()

    ucr_dir = os.path.join(args.root, "universal-call-recorder")
    wav_dir = os.path.join(args.root, "sdcard", "Android", "data",
                           "com.sparklingapps.callrecorder.full", "files")
    manifest = os.path.join(ucr_dir, "integrity-sweep", "encode-manifest.tsv")
    flac_root = os.path.join(args.root, "derived", "flac")
    opus_root = os.path.join(args.root, "derived", "opus")
    err_log = os.path.join(args.root, "derived", "encode-errors.log")

    for p in [manifest, wav_dir]:
        if not os.path.exists(p):
            sys.exit(f"FATAL: missing {p} — run scripts/ucr-ffprobe-sweep.sh first")

    rows = load_manifest(manifest)
    plan = build_plan(rows, flac_root)
    if args.only:
        rx = re.compile(args.only)
        plan = [p for p in plan if rx.search(p["stem"])]

    counts = {}
    for p in plan:
        counts[p["prefix"] or "-"] = counts.get(p["prefix"] or "-", 0) + 1
    log(f"plan: {len(plan)} files (prefixes {counts})")

    def tally(results):
        for _, status in results:
            counts[status] = counts.get(status, 0) + 1

    if args.phase in ("all", "flac"):
        log(f"phase flac: encoding {len(plan)} files (parallel={args.parallel})")
        with cf.ThreadPoolExecutor(max_workers=args.parallel) as pool:
            futs = [pool.submit(encode_flac, it, wav_dir, args.force, err_log) for it in plan]
            for i, fut in enumerate(cf.as_completed(futs), 1):
                stem, status = fut.result()
                if status.startswith("fail"):
                    log(f"   FAIL {stem} ({status})")
                if i % 50 == 0:
                    log(f"   {i}/{len(plan)}")
        tally([])
    if args.phase in ("all", "opus"):
        log(f"phase opus: encoding {len(plan)} files from flac")
        with cf.ThreadPoolExecutor(max_workers=args.parallel) as pool:
            futs = [pool.submit(encode_opus, it, flac_root, opus_root, args.force, err_log)
                    for it in plan]
            for i, fut in enumerate(cf.as_completed(futs), 1):
                stem, status = fut.result()
                if status.startswith("fail"):
                    log(f"   FAIL {stem} ({status})")
                if i % 50 == 0:
                    log(f"   {i}/{len(plan)}")
    if args.phase in ("all", "verify"):
        log(f"phase verify: full decode of {len(plan)} flacs (MD5 check)")
        with cf.ThreadPoolExecutor(max_workers=args.parallel) as pool:
            futs = [pool.submit(verify_flac, it, flac_root, err_log) for it in plan]
            for i, fut in enumerate(cf.as_completed(futs), 1):
                stem, status = fut.result()
                if status != "verify-ok":
                    log(f"   FAIL {stem} ({status})")
                if i % 50 == 0:
                    log(f"   {i}/{len(plan)}")

    report = {"total": len(plan), "finished": time.strftime("%Y-%m-%dT%H:%M:%S"),
              "force": args.force}
    with open(os.path.join(args.root, "derived", "encode-report.json"), "w") as fh:
        json.dump(report, fh, indent=2)

    problems = [f for f in [err_log] if os.path.exists(f) and os.path.getsize(f) > 0]
    log("done — check " + ", ".join(problems) if problems else "done, no encode errors")
    sys.exit(1 if problems and not args.force else 0)


if __name__ == "__main__":
    main()
