#!/usr/bin/env python3
"""RAG query CLI over the UCR call archive: "when did we first talk about X".

Rides the whisper-transcription row's output. Transcripts land in
derived/transcripts/<wav-stem>.{json,srt,vtt,txt} (one transcript per call),
then:

  ucr-rag.py init                 # (re)build schema + call metadata from the mirror
  ucr-rag.py import [PATHS...]    # ingest transcripts (dir or files; formats auto-detected)
  ucr-rag.py embed                # optional: per-call bge-m3 embeddings via :8848
  ucr-rag.py ask "when did we first talk about the Eiffel Tower" [--all] [--semantic]
  ucr-rag.py stats

`ask` answers with the EARLIEST mention by default (date, contact, [mm:ss],
snippet, audio path). Lexical search = sqlite FTS5 (always available). With
--semantic, per-call embeddings on the llama-rag server (:8848) add call-level
matches for paraphrases FTS misses; if that server is down the CLI says so and
answers lexically. Exit 0 on success, 1 on usage/infra errors.
"""

import argparse
import json
import math
import os
import re
import sqlite3
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT_DEFAULT = "/mnt/pool/backups/pixel6/2026-08-20"
EMBED_PORT = 8848
EMBED_MODEL = "bge-m3"

SCHEMA = """
CREATE TABLE IF NOT EXISTS calls(
  filename TEXT PRIMARY KEY, stem TEXT UNIQUE, contact TEXT,
  ts_utc TEXT, duration_s REAL, audio_rel TEXT);
CREATE VIRTUAL TABLE IF NOT EXISTS seg_fts USING fts5(
  text, call_id UNINDEXED, start_s UNINDEXED);
CREATE TABLE IF NOT EXISTS call_vec(
  stem TEXT PRIMARY KEY, vec BLOB, dim INTEGER, model TEXT, embedded_at TEXT);
"""


def db_path(root):
    return os.path.join(root, "derived", "rag", "transcripts.db")


def connect(root):
    path = db_path(root)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    con = sqlite3.connect(path)
    con.executescript(SCHEMA)
    return con


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%S")


# ---------------------------------------------------------------- init


def cmd_init(root):
    manifest = os.path.join(root, "universal-call-recorder", "integrity-sweep",
                            "encode-manifest.tsv")
    if not os.path.exists(manifest):
        sys.exit("FATAL: run scripts/ucr-ffprobe-sweep.sh first (manifest missing)")
    con = connect(root)
    con.execute("DELETE FROM calls")
    import csv
    rows = 0
    with open(manifest, newline="") as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            stem = r["filename"][:-4]
            cdir = r["contact_or_number"].strip() or "Unknown"
            cdir = "".join(c for c in cdir if c.isprintable() and c not in "\n\r\t/") or "Unknown"
            con.execute(
                "INSERT OR REPLACE INTO calls VALUES (?,?,?,?,?,?)",
                (r["filename"], stem, cdir, r["date_time_utc"],
                 float(r["duration_s"] or 0),
                 f"../opus/{cdir}/{r['date_time_utc'][:4]}/{stem}.opus"))
            rows += 1
    con.commit()
    n = con.execute("SELECT count(*) FROM seg_fts").fetchone()[0]
    print(f"calls indexed: {rows}; existing transcript segments: {n}")
    print("next: drop whisper output into derived/transcripts/<stem>.json|srt|vtt|txt and run `import`")


# ---------------------------------------------------------------- import


def parse_srt(text):
    cues = []
    block = []
    for line in text.replace("\r\n", "\n").split("\n") + [""]:
        if line.strip() == "":
            if block:
                times = re.search(r"(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)",
                                  "\n".join(block))
                if times:
                    g = [int(x) for x in times.groups()]
                    start = g[0] * 3600 + g[1] * 60 + g[2] + g[3] / 1000
                    end = g[4] * 3600 + g[5] * 60 + g[6] + g[7] / 1000
                    body = " ".join(l.strip() for l in block[1:] if l.strip() and "-->" not in l
                                    and not re.fullmatch(r"\d+", l.strip()))
                    if body:
                        cues.append((start, end, body))
                block = []
        else:
            block.append(line)
    return cues


def parse_whisper_json(data):
    """Accept openai-whisper/whisper.cpp/faster-whisper/faster-output json shapes."""
    if isinstance(data, dict):
        segs = data.get("segments")
        if segs is None:
            tr = data.get("transcription")
            if isinstance(tr, list):  # whisper.cpp
                segs = tr
            elif isinstance(tr, dict):
                segs = tr.get("segments")
        if isinstance(segs, list):
            out = []
            for s in segs:
                if not isinstance(s, dict):
                    continue
                text = (s.get("text") or "").strip()
                if not text:
                    continue
                if "start" in s:
                    start, end = float(s["start"]), float(s.get("end", s["start"]))
                elif "offsets" in s:  # whisper.cpp: milliseconds
                    start = s["offsets"].get("from", 0) / 1000.0
                    end = s["offsets"].get("to", 0) / 1000.0
                else:
                    start = end = 0.0
                out.append((start, end, text))
            return out
        if data.get("text"):
            return [(0.0, 0.0, str(data["text"]).strip())]
    return []


def transcript_cues(path):
    raw = open(path, "rb").read()
    text = raw.decode("utf-8-sig", "replace")
    ext = path.lower().rsplit(".", 1)[-1]
    if ext == "json":
        try:
            return parse_whisper_json(json.loads(text))
        except json.JSONDecodeError:
            return []
    if ext == "srt":
        return parse_srt(text)
    if ext == "vtt":
        return parse_srt(text.split("WEBVTT", 1)[-1] if "WEBVTT" in text[:16] else text)
    body = " ".join(text.split())
    return [(0.0, 0.0, body)] if body else []


def cmd_import(root, paths, force=False):
    trans_dir = os.path.join(root, "derived", "transcripts")
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += [os.path.join(p, f) for f in sorted(os.listdir(p))]
        elif os.path.exists(p):
            files.append(p)
        else:
            print(f"WARN: {p} not found", file=sys.stderr)
    files = [f for f in files if f.lower().rsplit(".", 1)[-1] in ("json", "srt", "vtt", "txt")]
    if not files:
        sys.exit(f"no transcripts found (looked in: {', '.join(paths) or trans_dir})")

    con = connect(root)
    stems = {r[0]: r[1] for r in con.execute("SELECT stem, filename FROM calls")}
    imported, orphaned, skipped = 0, [], []
    for f in files:
        stem = os.path.basename(f).rsplit(".", 1)[0]
        stem = re.sub(r"\.[a-z]{2}(-[A-Z]{2})?$", "", stem)  # strip lang suffix foo.de.json
        stem = re.sub(r"\.(wav|mp3|m4a|ogg|opus|flac)$", "", stem)  # whisper-cli foo.wav.json
        if stem not in stems:
            orphaned.append(os.path.basename(f))
            continue
        cues = transcript_cues(f)
        if not cues:
            print(f"WARN: no cues parsed from {f}", file=sys.stderr)
            continue
        call_id = con.execute("SELECT rowid FROM calls WHERE stem=?", (stem,)).fetchone()[0]
        existing = con.execute("SELECT count(*) FROM seg_fts WHERE call_id=?", (call_id,)).fetchone()[0]
        if existing and not force:
            skipped.append(os.path.basename(f))
            continue
        con.execute("DELETE FROM seg_fts WHERE call_id=?", (call_id,))
        con.executemany("INSERT INTO seg_fts(text, call_id, start_s) VALUES (?,?,?)",
                        [(t, call_id, s) for s, _e, t in cues])
        con.execute("DELETE FROM call_vec WHERE stem=?", (stem,))
        imported += 1
    con.commit()
    total = con.execute("SELECT count(*) FROM seg_fts").fetchone()[0]
    calls = con.execute("SELECT count(DISTINCT call_id) FROM seg_fts").fetchone()[0]
    print(f"imported {imported} transcripts ({calls} calls, {total} segments)")
    if skipped:
        print(f"kept existing transcript for {len(skipped)} calls (use --force to replace): "
              + ", ".join(skipped[:5]))
    if orphaned:
        print(f"WARNING: {len(orphaned)} transcripts match no known call (run init first?): "
              + ", ".join(orphaned[:5]))


# ---------------------------------------------------------------- embed


def embed_request(texts):
    req = urllib.request.Request(
        f"http://127.0.0.1:{EMBED_PORT}/v1/embeddings",
        data=json.dumps({"model": EMBED_MODEL, "input": texts}).encode(),
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.load(resp)
    return [d["embedding"] for d in sorted(data["data"], key=lambda d: d["index"])]


def cmd_embed(root, batch=16):
    con = connect(root)
    todo = [r[0] for r in con.execute(
        "SELECT c.stem FROM calls c LEFT JOIN call_vec v ON c.stem=v.stem "
        "WHERE v.stem IS NULL AND EXISTS (SELECT 1 FROM seg_fts f WHERE f.call_id=c.rowid)")]
    if not todo:
        print("nothing to embed (all transcribed calls already embedded, or no transcripts)")
        return
    print(f"embedding {len(todo)} calls via :{EMBED_PORT} ({EMBED_MODEL})")
    done = 0
    for i in range(0, len(todo), batch):
        chunk = todo[i:i + batch]
        texts = ["\n".join(r[0] for r in con.execute(
            "SELECT text FROM seg_fts WHERE call_id=(SELECT rowid FROM calls WHERE stem=?) "
            "ORDER BY start_s", (stem,)))[:12000] for stem in chunk]
        try:
            vecs = embed_request(texts)
        except (urllib.error.URLError, OSError, json.JSONDecodeError) as e:
            print(f"embeddings unavailable ({e}) — leaving {len(todo) - done} calls unembedded; "
                  "lexical search still works", file=sys.stderr)
            sys.exit(2)
        for stem, vec in zip(chunk, vecs):
            con.execute("INSERT OR REPLACE INTO call_vec VALUES (?,?,?,?)",
                        (stem, struct.pack(f"{len(vec)}f", *vec), len(vec), EMBED_MODEL, now()))
        done += len(chunk)
        if done % 50 == 0 or done == len(todo):
            print(f"   {done}/{len(todo)}")
    con.commit()
    print(f"embedded {done} calls")


# ---------------------------------------------------------------- ask


def fts_escape(q):
    return " ".join('"' + w.replace('"', '""') + '"' for w in q.split())


def cosine(a_blob, b, dim):
    a = struct.unpack(f"{dim}f", a_blob)
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb or 1.0)


def cmd_ask(root, query, n, semantic):
    con = connect(root)
    ftsq = fts_escape(query)
    try:
        rows = con.execute(
            "SELECT seg_fts.rowid, calls.stem, calls.contact, calls.ts_utc, calls.audio_rel,"
            " seg_fts.start_s, snippet(seg_fts, 0, '»', '«', '…', 14), calls.filename"
            " FROM seg_fts JOIN calls ON calls.rowid = seg_fts.call_id"
            " WHERE seg_fts MATCH ? ORDER BY calls.ts_utc, seg_fts.start_s LIMIT ?",
            (ftsq, n)).fetchall()
    except sqlite3.OperationalError as e:
        sys.exit(f"FTS query failed ({e}); try simpler terms")

    if not rows:
        print(f"no transcript mentions '{query}' (lexical).")
        print("transcribed coverage: "
              f"{con.execute('SELECT count(DISTINCT call_id) FROM seg_fts').fetchone()[0]} calls "
              f"of {con.execute('SELECT count(*) FROM calls').fetchone()[0]} indexed")
        return

    def mmss(s):
        return f"{int(s // 60)}:{int(s % 60):02d}"

    print(f"earliest mention: {rows[0][3]} — {rows[0][2]} [{mmss(rows[0][5])}]")
    print()
    for _r, stem, contact, ts, audio, start, snip, _fn in rows:
        print(f"{ts}  {contact:28.28} [{mmss(start):>6}] {audio}")
        print(f"{'':14} {snip.strip()}")
    covered = con.execute("SELECT count(DISTINCT call_id) FROM seg_fts").fetchone()[0]
    total = con.execute("SELECT count(*) FROM calls").fetchone()[0]
    print(f"\n({min(len(rows), n)} lexical hits; transcript coverage {covered}/{total} calls)")

    if not semantic:
        return
    try:
        qvec = embed_request([query])[0]
    except (urllib.error.URLError, OSError) as e:
        print(f"semantic layer unavailable ({e}) — lexical answer stands", file=sys.stderr)
        return
    seen = {r[1] for r in rows}
    sem = [(cosine(v, qvec, d), stem) for stem, v, d in
           con.execute("SELECT stem, vec, dim FROM call_vec")]
    sem.sort(reverse=True)
    extra = [(score, stem) for score, stem in sem[:n] if stem not in seen]
    if extra:
        print("\nsemantic call-level matches (no literal term hit):")
        for score, stem in extra[:5]:
            call = con.execute("SELECT contact, ts_utc, audio_rel FROM calls WHERE stem=?",
                               (stem,)).fetchone()
            print(f"  {score:.3f}  {call[1]}  {call[0]:28.28} {call[2]}")


def cmd_stats(root):
    con = connect(root)
    calls = con.execute("SELECT count(*) FROM calls").fetchone()[0]
    transcribed = con.execute("SELECT count(DISTINCT call_id) FROM seg_fts").fetchone()[0]
    segs = con.execute("SELECT count(*) FROM seg_fts").fetchone()[0]
    embedded = con.execute("SELECT count(*) FROM call_vec").fetchone()[0]
    hours = con.execute("SELECT sum(duration_s)/3600.0 FROM calls").fetchone()[0] or 0
    print(f"calls indexed: {calls} ({hours:.1f} h audio)")
    print(f"transcripts:   {transcribed} calls, {segs} segments")
    print(f"embeddings:    {embedded} calls (semantic layer ready)" if embedded
          else "embeddings:    none yet (optional `embed` step)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=os.environ.get("UCR_ROOT", ROOT_DEFAULT))
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init")
    imp = sub.add_parser("import")
    imp.add_argument("paths", nargs="*")
    imp.add_argument("--force", action="store_true", help="replace existing transcripts")
    emb = sub.add_parser("embed")
    emb.add_argument("--batch", type=int, default=16)
    ask = sub.add_parser("ask")
    ask.add_argument("query")
    ask.add_argument("-n", type=int, default=10)
    ask.add_argument("--semantic", action="store_true")
    sub.add_parser("stats")
    args = ap.parse_args()

    if args.cmd == "init":
        cmd_init(args.root)
    elif args.cmd == "import":
        cmd_import(args.root, args.paths or [os.path.join(args.root, "derived", "transcripts")],
                   args.force)
    elif args.cmd == "embed":
        cmd_embed(args.root, args.batch)
    elif args.cmd == "ask":
        cmd_ask(args.root, args.query, args.n, args.semantic)
    elif args.cmd == "stats":
        cmd_stats(args.root)


if __name__ == "__main__":
    main()
