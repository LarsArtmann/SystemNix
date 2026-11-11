# Google Takeout — rapt forensics, headless-browser attempt, D3c owner ask (2026-11-11 15:50 CET)

Session: takeout-retirement Phase 1, round 2. Plan: `docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md` (intake log updated in-place). Prior: `2026-11-11_14-55_takeout-handoff-intake-auth-probe-red.md`.

## a) Round-2 events (chronological)

1. Owner dropped a FULL browser cookie jar (295 cookies, Netscape, incl. HttpOnly family) → `cookies.txt` (0600).
2. Session VALIDITY proven: `curl` with the jar renders BOTH `takeout.google.com/takeout/downloads` AND `/takeout` (manage-archives) authenticated — export `ef8de5a3` visible, filename refs present, `user=1134…` id matches, both curl and Chrome UAs.
3. Download URIs still bounce: probe (part 12) → `http=200 final_host=accounts.google.com` login HTML.
4. Forensics: the live server-rendered manage page carries exactly ONE `data-download-uri` and it is 113 chars — **NO `rapt` parameter**. The app bundle (`boq-identity.TakeoutUi…base-js`) contains a URL-param builder adding `rapt` (and conditionally `epst`) **client-side at click time**. Neither live page nor `_gd` bootstrap blob contains any rapt value.
5. Probe against a re-minted rapt-LESS urls.txt: RED (same login bounce).
6. Headless harvest (playwright 1.64 + nixpkgs chromium 157 via PYTHONPATH env, full jar imported as 126 Google-only cookies with 86 httpOnly flags reconstructed from the cookieStore-visible set): page loads → **`accounts.google.com` challenge — Google bot-detection kills the automated-browser route.**
7. Jar trimmed 295 → 126 rows (Google-only: `*.google.com` + `takeout`/`accounts` hosts); GitHub/eTrade/LinkedIn/Ramp session cookies dropped from staging.

## b) Diagnosis (settled)

Takeout downloads require a **`rapt` proof token minted by real-browser JS at click time**. The owner's page paste carried rapt'd URIs that had gone STALE. Raw cookie+URL (with or without stale rapt) and headless automation both fail; only the owner's real browser session can mint fresh tokens. Cookies are NO LONGER the blocker — the fresh page is.

## c) Correction of the 14:55 report (naming surfaces)

The 14:55 report §a and the services.md G1 row claimed **"part 13 (565 B) already held exact" — FALSE**: both RED probes exited before the install step; `zips/` was and is EMPTY. Corrected in: plan intake log, `docs/todo/services.md` G1 row, this report. No re-download budget was burned (every probe fetch returned login HTML, not part bytes).

## d) The ONE blocking ask (D3c)

Owner, in the real logged-in browser on the takeout manage-archives page: **`Ctrl+S` → "Webpage, Complete" → save as `links.html` OVERWRITING** `/mnt/pool/archive/google-takeout/racedriver8k-2026-11-10/links.html`, then ping. The saved DOM serializes the freshly minted rapt'd URIs (this is exactly how the original paste got them). Agent then runs, in order: `ingest-html` (verify 23/23 sizes/filenames unchanged) → `~/.cache/takeout-probe/probe.sh` (part 12 green = PK magic + 176,785 B exact) → `start` detached. **Speed matters: the rapt freshness window is unknown (the paste's token survived <1 day); treat it as minutes-to-hours.** Fallback if the saved file yields 0 triplets (some browsers save original source, not DOM): DevTools console one-liner in the plan intake log → paste into `<staging>/triplets.tsv`.

## e) Security notes

- Staging jar is Google-only now; the owner should **delete the exporter's cookies.txt from their Downloads folder** — it holds live GitHub/eTrade/LinkedIn/Ramp sessions.
- Deadline: 2026-11-18 03:13 (~6.4 d). Once the page lands, the 880 GB download takes 1–3 days; buffer holds.

## f) Armed and verified-ready

`ingest-html` fixture-tested on saved-page shapes; probe script expects part 12; download script never re-fetches completed parts and dies loud on oversize. Dead code from the failed routes: `links-live.html`, `links-live2.html`, `fresh.uri`, rapt-less `urls.txt` (all overwritten/ignored when the real `links.html` lands; `links-live*.html` can be shredded at close-out).

## g) Also settled this round (owner questions)

- `/mnt/pool` IS `compress=zstd:3` (findmnt): transparent; shrinks the extract (JSON/text), NOT the zips (stored media is heuristic-skipped) — capacity math unchanged.
- Routing framework (Immich/Paperless/OpenCloud/cold) — answered in chat; plan § Routing + § Duplication remain the canonical record.
