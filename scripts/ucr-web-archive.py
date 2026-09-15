#!/usr/bin/env python3
"""Generate the browsable web archive (player + search) over the UCR call mirror.

Inputs:  the opus leg produced by scripts/ucr-mirror-encode.py
Output:  derived/web-archive/  (static, no server needed — open index.html;
         audio streams ../opus/... so no duplication)

Layout:
  index.html   player UI (search by contact/date, chronological list, keyboard control)
  data.js      const CALLS=[...] + const CONTACTS=[...] (file://-safe, no fetch)
  README.md    what this is + how to regenerate
"""

import argparse
import html
import json
import os
import re
import time

ROOT_DEFAULT = "/mnt/pool/backups/pixel6/2026-08-20"


def collect(opus_root):
    calls = []
    rx = re.compile(r"^(\d+)_(\d{13})\.wav$")
    for dirpath, _dirnames, filenames in os.walk(opus_root):
        for fn in sorted(filenames):
            if not fn.endswith(".opus"):
                continue
            rel = os.path.relpath(os.path.join(dirpath, fn), opus_root)
            stem = fn[:-5]
            m = rx.match(stem)
            prefix = m.group(1) if m else ""
            epoch_ms = int(m.group(2)) if m else 0
            contact = rel.split(os.sep)[0]
            year = rel.split(os.sep)[1] if len(rel.split(os.sep)) > 1 else ""
            size = os.path.getsize(os.path.join(dirpath, fn))
            calls.append({
                "prefix": prefix,
                "ts": epoch_ms,
                "contact": contact,
                "year": year,
                "size": size,
                "src": "../opus/" + rel.replace(os.sep, "/"),
            })
    calls.sort(key=lambda c: (c["ts"], c["src"]))
    return calls


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024.0


def page_template():
    return """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>UCR Call Archive</title>
<style>
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body { margin:0; font:15px/1.5 system-ui,-apple-system,sans-serif; background:#11131a; color:#dde1ea; }
header { padding:18px 24px 10px; border-bottom:1px solid #262a36; position:sticky; top:0; background:#11131af2; backdrop-filter:blur(6px); z-index:5; }
h1 { font-size:17px; margin:0 0 10px; font-weight:600; }
h1 small { color:#8a91a3; font-weight:400; }
#bar { display:flex; gap:10px; flex-wrap:wrap; }
#q { flex:1; min-width:220px; padding:8px 12px; border-radius:8px; border:1px solid #333a4c; background:#1a1e29; color:#dde1ea; font-size:15px; }
select { padding:8px; border-radius:8px; border:1px solid #333a4c; background:#1a1e29; color:#dde1ea; }
main { max-width:900px; margin:0 auto; padding:12px 16px 120px; }
.row { display:flex; align-items:center; gap:12px; padding:8px 10px; border-radius:8px; cursor:pointer; }
.row:hover { background:#1b202c; }
.row.active { background:#233047; }
.row .date { font-variant-numeric:tabular-nums; color:#aab2c5; width:150px; flex-shrink:0; }
.row .who { flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.row .who .c { font-weight:600; }
.row .who .f { color:#6d7589; font-size:12px; margin-left:8px; }
.row .dur { color:#8a91a3; font-variant-numeric:tabular-nums; }
.badge { font-size:11px; border:1px solid #3a415a; color:#7f8aa3; border-radius:5px; padding:1px 6px; }
#player { position:fixed; bottom:0; left:0; right:0; background:#171b26; border-top:1px solid #2a3040; padding:10px 18px; display:none; }
#player.on { display:block; }
#np { font-weight:600; margin-bottom:6px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
#controls { display:flex; align-items:center; gap:12px; }
#controls button { background:#242b3b; color:#dde1ea; border:none; border-radius:7px; padding:7px 12px; cursor:pointer; font-size:14px; }
#controls button:hover { background:#303a50; }
#seek { flex:1; accent-color:#6c8cff; }
#time { font-variant-numeric:tabular-nums; color:#8a91a3; min-width:96px; text-align:center; }
.empty { color:#6d7589; text-align:center; padding:40px 0; }
kbd { background:#242b3b; border-radius:4px; padding:0 5px; font-size:12px; }
</style></head><body>
<header>
  <h1>UCR Call Archive <small id="meta"></small></h1>
  <div id="bar">
    <input id="q" type="search" placeholder="Search contact or date (e.g. Luana, 2022-01, +49)" autofocus>
    <select id="contactFilter"><option value="">All contacts</option></select>
  </div>
</header>
<main id="list"></main>
<div id="player">
  <div id="np"></div>
  <div id="controls">
    <button id="prev" title="Previous call">⏮</button>
    <button id="back10" title="Back 10s">−10s</button>
    <button id="playpause">▶</button>
    <button id="fwd10" title="Forward 10s">+10s</button>
    <button id="next" title="Next call">⏭</button>
    <input id="seek" type="range" min="0" max="1000" value="0">
    <span id="time">0:00 / 0:00</span>
    <select id="speed"><option>0.75</option><option selected>1</option><option>1.25</option><option>1.5</option><option>2</option><option>3</option></select>
  </div>
  <audio id="audio"></audio>
</div>
<script src="data.js"></script>
<script>
const list = document.getElementById('list');
const q = document.getElementById('q');
const cf_ = document.getElementById('contactFilter');
const audio = document.getElementById('audio');
const player = document.getElementById('player');
let view = CALLS.slice(), cur = -1;

const fmtDur = s => isFinite(s) ? (s>=3600?`${Math.floor(s/3600)}:${String(Math.floor(s%3600/60)).padStart(2,'0')}:${String(Math.floor(s%60)).padStart(2,'0')}`:`${Math.floor(s/60)}:${String(Math.floor(s%60)).padStart(2,'0')}`) : '';
const fmtDate = ts => { const d = new Date(ts); if (isNaN(d)) return '(no date)'; const p = n => String(n).padStart(2,'0'); return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`; };
const esc = s => s.replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

document.getElementById('meta').textContent = `${CALLS.length} calls · ${TOTAL_SIZE}`;
[...new Set(CALLS.map(c => c.contact))].sort().forEach(c => { const o = document.createElement('option'); o.value = c; o.textContent = c; cf_.appendChild(o); });

function render() {
  const needle = q.value.toLowerCase().trim();
  const contact = cf_.value;
  view = CALLS.filter(c => (!contact || c.contact === contact) &&
    (!needle || c.contact.toLowerCase().includes(needle) || fmtDate(c.ts).includes(needle) || c.src.toLowerCase().includes(needle)));
  list.innerHTML = view.length ? '' : '<div class="empty">No calls match.</div>';
  view.forEach((c, i) => {
    const row = document.createElement('div');
    row.className = 'row' + (i === cur ? ' active' : '');
    row.innerHTML = `<span class="date">${fmtDate(c.ts)}</span>
      <span class="who"><span class="c">${esc(c.contact)}</span><span class="f">${esc(c.src.split('/').pop().replace('.opus',''))}</span></span>
      <span class="badge">${c.prefix ? 'prefix ' + c.prefix : ''}</span>
      <span class="dur">${fmtDur(c.dur || 0)}</span>`;
    row.onclick = () => play(i);
    list.appendChild(row);
  });
}
function play(i) {
  if (i < 0 || i >= view.length) return;
  cur = i; const c = view[i];
  audio.src = c.src; audio.playbackRate = parseFloat(speed.value);
  audio.play().catch(() => {});
  document.getElementById('np').textContent = `${c.contact} — ${fmtDate(c.ts)}`;
  player.classList.add('on');
  [...list.children].forEach((r, j) => r.classList.toggle('active', j === cur));
  const act = list.children[cur]; if (act) act.scrollIntoView({block:'nearest'});
}
q.oninput = render; cf_.onchange = render;
document.getElementById('playpause').onclick = () => audio.paused ? audio.play() : audio.pause();
document.getElementById('prev').onclick = () => play(cur - 1);
document.getElementById('next').onclick = () => play(cur + 1);
document.getElementById('back10').onclick = () => audio.currentTime = Math.max(0, audio.currentTime - 10);
document.getElementById('fwd10').onclick = () => audio.currentTime = Math.min(audio.duration || 0, audio.currentTime + 10);
speed.onchange = () => audio.playbackRate = parseFloat(speed.value);
audio.ontimeupdate = () => {
  document.getElementById('time').textContent = `${fmtDur(audio.currentTime)} / ${fmtDur(audio.duration)}`;
  if (audio.duration) seek.value = Math.floor(audio.currentTime / audio.duration * 1000);
};
seek.oninput = () => { if (audio.duration) audio.currentTime = seek.value / 1000 * audio.duration; };
audio.onended = () => play(cur + 1);
document.onkeydown = e => {
  if (e.target.tagName === 'INPUT' && e.code === 'Space') { e.preventDefault(); document.getElementById('playpause').click(); }
  if (e.target !== q && e.code === 'Space') { e.preventDefault(); document.getElementById('playpause').click(); }
};
render();
</script></body></html>
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=os.environ.get("UCR_ROOT", ROOT_DEFAULT))
    args = ap.parse_args()

    opus_root = os.path.join(args.root, "derived", "opus")
    out = os.path.join(args.root, "derived", "web-archive")
    if not os.path.isdir(opus_root):
        raise SystemExit(f"FATAL: {opus_root} missing — run scripts/ucr-mirror-encode.py first")

    calls = collect(opus_root)

    sweep_tsv = os.path.join(args.root, "universal-call-recorder",
                             "integrity-sweep", "encode-manifest.tsv")
    durs = {}
    if os.path.exists(sweep_tsv):
        import csv
        with open(sweep_tsv, newline="") as fh:
            for row in csv.DictReader(fh, delimiter="\t"):
                try:
                    durs[row["filename"][:-4]] = float(row["duration_s"])
                except (ValueError, KeyError, TypeError):
                    pass
    for c in calls:
        stem = os.path.basename(c["src"])[:-5]
        c["dur"] = durs.get(stem)

    total = sum(c["size"] for c in calls)
    data = "const CALLS = " + json.dumps(calls, ensure_ascii=False) + ";\n"
    data += f"const TOTAL_SIZE = {json.dumps(human(total))};\n"

    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "index.html"), "w") as fh:
        fh.write(page_template())
    with open(os.path.join(out, "data.js"), "w") as fh:
        fh.write(data)
    with open(os.path.join(out, "README.md"), "w") as fh:
        fh.write(f"""# UCR Call Archive — browsable web player

Generated {time.strftime('%Y-%m-%d %H:%M')} by `scripts/ucr-web-archive.py`.

- Open `index.html` in any browser (works from `file://`, no server needed).
- Audio streams the opus leg one level up (`../opus/...`) — regenerate that first.
- {len(calls)} calls, opus leg = {human(total)}.

Regenerate: `python3 scripts/ucr-web-archive.py` (after `scripts/ucr-mirror-encode.py`).
""")
    print(f"web archive: {len(calls)} calls, opus {human(total)} -> {out}")


if __name__ == "__main__":
    main()
