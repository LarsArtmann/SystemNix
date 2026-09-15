#!/usr/bin/env python3
"""Pixel 6 contacts: archive evidence registry + VCF decode to per-contact cards.

Subcommands:
  derive              Scan Cube ACR JSONs + UCR filenames for contact evidence
                      (names, numbers, call counts, first/last seen) ->
                      derived/contacts/contacts-evidence.json

  decode-vcf [FILES]  Decode vCard 2.1/3.0/4.0 (unfolding, QUOTED-PRINTABLE,
                      BASE64 photos) into:
                        derived/contacts/vcf/<NN>_<name>.vcf   clean per-contact cards
                        derived/contacts/photos/<NN>.jpg       decoded photos
                        derived/contacts/contacts.json         structured cards
                        derived/contacts/index.html            browsable cards
                      Merges the archive evidence registry (call counts, first/last
                      seen) onto matching contacts by number or name.
                      With no FILES: decodes everything found in contacts/incoming/.

Typical flow (after the on-phone VCF export):
  cp <phone-export>.vcf /mnt/pool/backups/pixel6/2026-08-20/contacts/incoming/
  python3 scripts/pixel6-contacts.py derive
  python3 scripts/pixel6-contacts.py decode-vcf
"""

import argparse
import base64
import binascii
import csv
import json
import os
import quopri
import re
import sys
import time
from html import escape

ROOT_DEFAULT = "/mnt/pool/backups/pixel6/2026-08-20"
ISOLATION = dict.fromkeys(map(ord, "\u2066\u2067\u2068\u2069\u200e\u200f\u202a\u202b\u202c\u202d\u202e"))


def clean_name(raw):
    if not raw:
        return ""
    name = raw.translate(ISOLATION)
    name = re.sub(r"\s*---\s*", " ", name)
    name = re.sub(r"\s+", " ", name).strip(" -_")
    return name


def norm_number(num):
    if not num:
        return ""
    digits = re.sub(r"\D", "", num)
    return digits


def looks_like_number(s):
    if not s:
        return False
    s = s.translate(ISOLATION)
    return bool(re.fullmatch(r"[+()\d\s\-./]+", s)) and any(c.isdigit() for c in s)


# ---------------------------------------------------------------- evidence


def ucr_evidence(root):
    index = os.path.join(root, "universal-call-recorder", "index.csv")
    out = {}
    if not os.path.exists(index):
        return out
    rx = re.compile(r"^(\d+)_(.*)_(\d{13})\.wav$")
    with open(index, newline="") as fh:
        for row in csv.DictReader(fh):
            ts = row["date_time_utc"]
            m = rx.match(row["filename"])
            name_or_number = ""
            if m and m.group(2):
                name_or_number = m.group(2).strip()
            elif row["contact_or_number"].strip():
                name_or_number = row["contact_or_number"].strip()
            if not name_or_number:
                continue
            if looks_like_number(name_or_number):
                key = ("num", norm_number(name_or_number))
                disp = name_or_number
            else:
                key = ("name", name_or_number.casefold())
                disp = name_or_number
            e = out.setdefault(key, {"display": disp, "names": set(), "numbers": set(),
                                     "ucr_calls": 0, "ucr_first": ts, "ucr_last": ts,
                                     "cube_calls": 0, "cube_first": "", "cube_last": ""})
            e["ucr_calls"] += 1
            e["ucr_first"] = min(e["ucr_first"], ts)
            e["ucr_last"] = max(e["ucr_last"], ts)
            if looks_like_number(name_or_number):
                e["numbers"].add(norm_number(name_or_number))
            else:
                e["names"].add(name_or_number)
    return out


def cube_evidence(root):
    props = os.path.join(root, "sdcard", "Documents", "CubeCallRecorder", "All", ".props")
    out = {}
    if not os.path.isdir(props):
        return out

    def entry(key, disp):
        return out.setdefault(key, {"display": disp, "names": set(), "numbers": set(),
                                    "ucr_calls": 0, "ucr_first": "", "ucr_last": "",
                                    "cube_calls": 0, "cube_first": "", "cube_last": ""})

    for fn in os.listdir(props):
        if not fn.endswith(".json"):
            continue
        try:
            meta = json.load(open(os.path.join(props, fn), encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError, OSError):
            continue
        m = re.match(r"^[a-z]+_(\d{8})-(\d{6})[_ ](.*)\.json$", clean_name(fn), re.S)
        date = ""
        stem_name = ""
        if m:
            date = f"{m.group(1)[:4]}-{m.group(1)[4:6]}-{m.group(1)[6:]} {m.group(2)[:2]}:{m.group(2)[2:]}"
            stem_name = clean_name(m.group(3))
        callee = clean_name((meta.get("callee") or "").strip())

        num_part = callee if callee and looks_like_number(callee) else \
            (stem_name if stem_name and looks_like_number(stem_name) else "")
        name_part = callee if callee and not looks_like_number(callee) else \
            (stem_name if stem_name and not looks_like_number(stem_name) and stem_name not in ("Call ended", "Unknown") else "")
        if not num_part and not name_part:
            continue

        norm = norm_number(num_part)
        if name_part:
            e = entry(("name", name_part.casefold()), name_part)
        else:
            e = entry(("num", norm), num_part)
        e["cube_calls"] += 1
        if date:
            e["cube_first"] = min((x for x in (e["cube_first"], date) if x), default=date)
            e["cube_last"] = max((x for x in (e["cube_last"], date) if x), default=date)
        if name_part:
            e["names"].add(name_part)
        if norm:
            e["numbers"].add(norm)
        if name_part and norm:
            e["display"] = name_part
    return out


def derive(root):
    out_dir = os.path.join(root, "derived", "contacts")
    os.makedirs(out_dir, exist_ok=True)
    merged = {}
    for registry in (ucr_evidence(root), cube_evidence(root)):
        for key, e in registry.items():
            if key not in merged:
                merged[key] = e
                continue
            m = merged[key]
            m["names"] |= e["names"]
            m["numbers"] |= e["numbers"]
            m["ucr_calls"] += e["ucr_calls"]
            m["cube_calls"] += e["cube_calls"]
            for f in ("ucr_first", "ucr_last", "cube_first", "cube_last"):
                if e[f]:
                    m[f] = min((x for x in (m[f], e[f]) if x), default=e[f]) if f.endswith("first") \
                        else max((x for x in (m[f], e[f]) if x), default=e[f])
            if not looks_like_number(m["display"]) or (e["names"] and looks_like_number(m["display"])):
                named = sorted(e["names"])[0] if e["names"] else m["display"]
                m["display"] = named

    contacts = sorted(merged.values(), key=lambda e: (-(e["ucr_calls"] + e["cube_calls"]), e["display"]))
    payload = [{"display": e["display"], "names": sorted(e["names"]), "numbers": sorted(e["numbers"]),
                "ucr_calls": e["ucr_calls"], "ucr_first": e["ucr_first"], "ucr_last": e["ucr_last"],
                "cube_calls": e["cube_calls"], "cube_first": e["cube_first"], "cube_last": e["cube_last"]}
               for e in contacts]
    path = os.path.join(out_dir, "contacts-evidence.json")
    with open(path, "w") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    print(f"evidence registry: {len(payload)} contacts -> {path}")
    named = sum(1 for c in payload if not looks_like_number(c["display"]))
    print(f"  {named} with real names, {len(payload) - named} number-only")
    return payload


# ---------------------------------------------------------------- vCard


def unfold(text):
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out = []
    for line in lines:
        if line[:1] in (" ", "\t") and out:
            out[-1] += line[1:]
        elif line:
            out.append(line)
    return out


def decode_value(params, value):
    enc = ""
    charset = "utf-8"
    for p in params[1:]:
        pl = p.lower()
        if pl.startswith("encoding="):
            enc = pl.split("=", 1)[1]
        elif pl.startswith("charset="):
            charset = pl.split("=", 1)[1]
        elif pl in ("quoted-printable", "qp", "base64", "b"):
            enc = enc or pl
    if enc in ("quoted-printable", "qp"):
        return quopri.decodestring(value.encode()).decode(charset, "replace")
    if enc in ("base64", "b"):
        return base64.b64decode(re.sub(r"\s+", "", value))
    if value.startswith("data:") and ";base64," in value:
        return base64.b64decode(value.split(";base64,", 1)[1])
    return value


def parse_vcard(text):
    cards, cur = [], None
    for line in unfold(text):
        if line.upper().startswith("BEGIN:VCARD"):
            cur = {"props": []}
            continue
        if line.upper().startswith("END:VCARD"):
            if cur is not None:
                cards.append(cur)
            cur = None
            continue
        if cur is None or ":" not in line:
            continue
        head, value = line.split(":", 1)
        parts = head.split(";")
        prop = parts[0].upper()
        if prop.startswith("ITEM") and "." in prop:
            prop = prop.split(".", 1)[1]
        cur["props"].append((prop, parts, value))
    return cards


def extract_card(card):
    def values(prop):
        return [(params, decode_value(params, value)) for p, params, value in card["props"]
                if p == prop and value]

    def types(params):
        t = []
        for p in params[1:]:
            pl = p.lower()
            if "=" in pl:
                key, v = pl.split("=", 1)
                if key == "type" and v:
                    t.append(v.upper())
            elif pl and pl not in ("voice", "pref", "internet"):
                t.append(pl.upper())
        return "/".join(sorted(set(t)))

    fn = next((v for _, v in values("FN")), "")
    n_parts = next((v for _, v in values("N")), "")
    if not fn and n_parts:
        pieces = [p for p in n_parts.split(";") if p]
        fn = " ".join(reversed(pieces[:2])) if len(pieces) > 1 else (pieces[0] if pieces else "")
    tels = [{"number": v, "type": types(params)} for params, v in values("TEL")]
    emails = [{"address": v, "type": types(params)} for params, v in values("EMAIL")]
    org = "; ".join(v for _, v in values("ORG") if v).strip("; ")
    title = next((v for _, v in values("TITLE")), "")
    note = next((v for _, v in values("NOTE")), "")
    bday = next((v for _, v in values("BDAY")), "")
    uid = next((v for _, v in values("UID")), "")
    photo = next((v for _, v in values("PHOTO")), None)
    return {"fn": clean_name(fn) or clean_name(title), "n": n_parts, "tels": tels, "emails": emails,
            "org": org, "title": title, "note": note, "bday": bday, "uid": uid, "photo": photo}


def safe_filename(name, idx):
    s = clean_name(name) or "unnamed"
    s = re.sub(r"[^\w\s.-]", "", s, flags=re.UNICODE).strip().replace(" ", "_")[:60]
    return f"{idx:03d}_{s or 'unnamed'}"


def merge_evidence(card, evidence):
    """Union ALL evidence entries matching any of the card's numbers or its name."""
    my_nums = {norm_number(t["number"]) for t in card["tels"]} - {""}
    my_name = card["fn"].casefold() if card["fn"] else None
    matches = []
    for key, e in evidence.items():
        hit = False
        if key[0] == "num" and key[1]:
            hit = any(n == key[1] or (len(n) >= 9 and n.endswith(key[1][-9:]))
                      for n in my_nums)
        elif key[0] == "name" and my_name:
            hit = key[1] == my_name
        if not hit:
            continue
        cross = any(any(n == x or (len(n) >= 9 and n.endswith(x[-9:]))
                        for n in my_nums) for x in e.get("numbers", ()))
        if key[0] == "num" or cross or key[1] == my_name:
            matches.append(e)
    if not matches:
        return None
    firsts = [e["ucr_first"] for e in matches if e["ucr_first"]]
    lasts = [e["ucr_last"] for e in matches if e["ucr_last"]]
    return {"archive_calls": sum(e["ucr_calls"] + e["cube_calls"] for e in matches),
            "ucr_calls": sum(e["ucr_calls"] for e in matches),
            "cube_calls": sum(e["cube_calls"] for e in matches),
            "ucr_first": min(firsts) if firsts else "",
            "ucr_last": max(lasts) if lasts else "",
            "evidence_names": sorted({n for e in matches for n in e.get("names", ())})}


def write_card_vcf(card, path):
    lines = ["BEGIN:VCARD", "VERSION:3.0", f"FN:{card['fn']}"]
    if card["n"]:
        lines.append(f"N:{card['n']}")
    for tel in card["tels"]:
        lines.append(f"TEL;TYPE={tel['type'] or 'VOICE'}:{tel['number']}")
    for mail in card["emails"]:
        lines.append(f"EMAIL;TYPE={mail['type'] or 'INTERNET'}:{mail['address']}")
    if card["org"]:
        lines.append(f"ORG:{card['org']}")
    if card["title"]:
        lines.append(f"TITLE:{card['title']}")
    if card["bday"]:
        lines.append(f"BDAY:{card['bday']}")
    if card["note"]:
        lines.append("NOTE:" + card["note"].replace("\n", "\\n"))
    lines.append("END:VCARD")
    with open(path, "w") as fh:
        fh.write("\r\n".join(lines) + "\r\n")


def cards_html(cards, out_path):
    def card_html(i, c):
        tels = "".join(
            f"<div><code>{escape(t['number'])}</code>"
            + (f" <span class='ty'>{escape(t['type'])}</span>" if t["type"] else "")
            + (f" <span class='arch'>{'★' * min(c['match']['archive_calls'], 5)} {c['match']['archive_calls']} calls</span>"
               if c.get("match") else "")
            + "</div>" for t in c["tels"]) or "<div class='none'>no phone</div>"
        emails = "".join(f"<div><a href='mailto:{escape(m['address'])}'>{escape(m['address'])}</a></div>"
                         for m in c["emails"])
        org = escape(c["org"] + (" · " + c["title"] if c["title"] else "")) if c["org"] or c["title"] else ""
        note = f"<p class='note'>{escape(c['note'][:400])}</p>" if c["note"] else ""
        match = ""
        if c.get("match"):
            m = c["match"]
            span = " → ".join(x[:10] for x in (m["ucr_first"], m["ucr_last"]) if x)
            match = (f"<p class='match'>Call archive: {m['ucr_calls']} UCR ({escape(span)})"
                     f" + {m['cube_calls']} Cube</p>")
        photo = f"<img src='photos/{escape(os.path.basename(c['photo_file']))}' alt=''>" if c.get("photo_file") else ""
        return (f"<div class='card' data-search='{escape((c['fn'] + ' ' + ' '.join(t['number'] for t in c['tels']) + ' ' + c['org']).lower())}'>"
                f"<div class='avatar'>{photo}{escape((c['fn'] or '?')[:1].upper())}</div>"
                f"<h2>{escape(c['fn'] or '(unnamed)')}</h2>{org}{tels}{emails}{note}{match}</div>")

    html = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Contacts</title>
<style>
:root {{ color-scheme: dark; }}
body {{ margin:0; font:15px/1.5 system-ui,sans-serif; background:#11131a; color:#dde1ea; }}
header {{ padding:18px 24px; position:sticky; top:0; background:#11131af2; backdrop-filter:blur(6px); border-bottom:1px solid #262a36; }}
h1 {{ font-size:17px; margin:0 0 10px; }}
#q {{ padding:8px 12px; border-radius:8px; border:1px solid #333a4c; background:#1a1e29; color:#dde1ea; width:min(420px, 90vw); }}
#grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:14px; padding:18px; }}
.card {{ background:#171b26; border:1px solid #262a36; border-radius:12px; padding:16px; }}
.avatar {{ width:48px; height:48px; border-radius:50%; background:#242b3b; display:flex; align-items:center; justify-content:center; font-size:20px; font-weight:700; overflow:hidden; margin-bottom:8px; }}
.avatar img {{ width:100%; height:100%; object-fit:cover; }}
h2 {{ font-size:16px; margin:0 0 4px; }}
code {{ color:#9fb6ff; }}
.ty {{ color:#6d7589; font-size:11px; }}
.arch {{ color:#e8b74a; font-size:12px; }}
.none {{ color:#5b6274; }}
.note {{ color:#8a91a3; font-size:13px; }}
.match {{ color:#57c99b; font-size:12px; margin:6px 0 0; }}
.hidden {{ display:none; }}
</style></head><body>
<header><h1>Contacts — {len(cards)}</h1><input id="q" type="search" placeholder="Search name or number"></header>
<div id="grid">{''.join(card_html(i, c) for i, c in enumerate(cards))}</div>
<script>
q.oninput = () => {{ const n = q.value.toLowerCase();
  document.querySelectorAll('.card').forEach(c => c.classList.toggle('hidden', n && !c.dataset.search.includes(n))); }};
</script></body></html>"""
    with open(out_path, "w") as fh:
        fh.write(html)
    return out_path


def decode_vcf(root, vcf_files):
    out_dir = os.path.join(root, "derived", "contacts")
    photos_dir = os.path.join(out_dir, "photos")
    vcf_dir = os.path.join(out_dir, "vcf")
    for d in (photos_dir, vcf_dir):
        os.makedirs(d, exist_ok=True)
    evidence = {}
    reg_path = os.path.join(out_dir, "contacts-evidence.json")
    if os.path.exists(reg_path):
        for e in json.load(open(reg_path)):
            for n in e["numbers"]:
                evidence[("num", n)] = e
            for n in e["names"]:
                evidence[("name", n.casefold())] = e

    cards = []
    for path in vcf_files:
        raw = open(path, "rb").read()
        for enc in ("utf-8-sig", "utf-8", "latin-1"):
            try:
                text = raw.decode(enc)
                break
            except UnicodeDecodeError:
                continue
        else:
            print(f"SKIP {path}: cannot decode", file=sys.stderr)
            continue
        parsed = parse_vcard(text)
        print(f"{os.path.basename(path)}: {len(parsed)} vCards")
        for c in parsed:
            cards.append(extract_card(c))

    for i, card in enumerate(cards, 1):
        card["match"] = merge_evidence(card, evidence)
        if card["photo"]:
            ext = "jpg" if card["photo"][:3] == b"\xff\xd8\xff" else ("png" if card["photo"][:4] == b"\x89PNG" else "bin")
            pf = os.path.join(photos_dir, f"{safe_filename(card['fn'], i)}.{ext}")
            with open(pf, "wb") as fh:
                fh.write(card["photo"])
            card["photo_file"] = os.path.basename(pf)
        write_card_vcf(card, os.path.join(vcf_dir, safe_filename(card["fn"], i) + ".vcf"))
        card.pop("photo", None)

    payload = [{k: v for k, v in c.items()} for c in cards]
    with open(os.path.join(out_dir, "contacts.json"), "w") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    cards_html(payload, os.path.join(out_dir, "index.html"))
    matched = sum(1 for c in cards if c.get("match"))
    print(f"decoded {len(cards)} contacts ({matched} matched to call-archive evidence)")
    print(f"  cards: {vcf_dir}/  photos: {photos_dir}/  browse: {out_dir}/index.html")
    return cards


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("subcommand", choices=["derive", "decode-vcf"])
    ap.add_argument("--root", default=os.environ.get("UCR_ROOT", ROOT_DEFAULT))
    ap.add_argument("files", nargs="*", help="VCF files (decode-vcf; default: contacts/incoming/*)")
    args = ap.parse_args()

    if args.subcommand == "derive":
        derive(args.root)
        return
    files = args.files
    if not files:
        incoming = os.path.join(args.root, "contacts", "incoming")
        if os.path.isdir(incoming):
            files = sorted(os.path.join(incoming, f) for f in os.listdir(incoming)
                           if f.lower().endswith(".vcf"))
        if not files:
            inc = os.path.join(args.root, "contacts", "incoming")
            sys.exit(f"No VCF given and none found in {inc}\n"
                     f"On the phone: Contacts app → export/share → save the .vcf, pull it, "
                     f"copy it into {inc}, then re-run.")
    decode_vcf(args.root, files)


if __name__ == "__main__":
    main()
