# Google Takeout pipeline — handoff intake complete, auth probe RED (2026-11-11 14:55 CET)

Session: takeout-retirement Phase 1 intake. Plan: `docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md` (EXECUTING). Prior session report: `2026-11-11_14-36_google-takeout-pipeline-phase0-status.md`.

## a) What was done

- Reconstructed `links.html` in the staging root from the owner's manage-archives page paste (23 `data-download-uri`/`data-size`/`data-filename` triplets, page order, entities encoded) → `takeout-download.sh ingest-html` → **`urls.txt` + `parts.tsv` exact: 23/23 rows, sum 944,513,645,689 B = 879.65 GiB (matches the page total), both 0600** inside the 0700 root.
- `cookies.json` (owner drop, JS `cookieStore.getAll()` export) inspected: 8 cookies, keys domain/expires/name/partitioned/path/sameSite/secure/value, ms-epoch expiry, domain `google.com`. Converted → Netscape `cookies.txt` (domain-suffix form, seconds expiry) at 0600; `cookies.json` tightened 0644→0600.
- Auth probe v1 (part 13, 565 B): **RED**. Probe v2 re-armed at `~/.cache/takeout-probe/probe.sh` targeting part 12 (176,785 B) so the retry fetch is a needed part (installs as `zips/part-12.zip` on green — zero wasted download budget).

## b) Probe evidence (the Q1 unknown, now decided)

`http=200 final_host=accounts.google.com bytes=947743 magic='<!'` — Google redirects the takeout download URI to a login page. The `rapt` token in the URL does NOT authorize downloads by itself, and a cookieStore export can never work: **HSID, SSID, `__Secure-1PSID`, `__Secure-3PSID`, PSIDTS are HttpOnly — invisible to `cookieStore` by construction.** The existing SID/APISID/SAPISID family is not sufficient.

## c) Consequence

- G1 (`start`) must NOT fire on the current cookies: every part would 302→login and burn the retry loop (each retry is a fresh GET of the link).
- No re-download budget was burned: the probe fetched real part 13 (held exact at `zips/part-13.zip`, 565 B, PK magic); part 12 is the designated re-probe part.
- Deadline unchanged: export expires **2026-11-18 03:13** (~6.5 d). Buffer remains comfortable for a 1–3 day download once cookies land.

## d) Owner ask — ONE blocking item (D3b)

While logged into `takeout.google.com` as racedriver8k, export cookies **including HttpOnly** with a local-only cookies.txt browser extension (e.g. the open-source "Get cookies.txt LOCALLY", Chrome/Firefox) and **overwrite** `/mnt/pool/archive/google-takeout/racedriver8k-2026-11-10/cookies.txt` (Netscape format; must contain HSID, SSID, `__Secure-1PSID`, `__Secure-3PSID`, PSIDTS alongside the SID family). File drop only — never paste values into chat/commands. Extension-free alternative: DevTools → Application → Cookies → takeout.google.com, manually add the 5 missing rows to the existing `cookies.txt`.

## e) Storage answer (owner Q2, "not 15 times")

Recorded in plan § Duplication: **one raw copy (the 23 zips, permanent escape hatch) + exactly ONE working copy per service** (Immich/OpenCloud/Paperless datadirs) + a transient `<staging>/extracted/` deleted after G4+G5 green. Services dedup server-side (Immich checksum, Paperless byte-identical rejection); cold products are never extracted. **≤ 2.7 TB peak, ~1.8 TB steady** vs 11 TB free. Optional later: pool BTRFS reflink dedup pass — never required for fit.

## f) Armed next steps (any session, after the cookie drop)

1. `bash ~/.cache/takeout-probe/probe.sh` — green = PK magic + 176,785 B exact, installs part-12.zip.
2. Fire `bash scripts/takeout-download.sh <staging> start` detached (systemd-run --user or tmux; survives sessions).
3. G1 supervision → `status` → G2 battery. G3 later needs `immich-api-key`; G4 needs an OpenCloud app password (both owner, non-blocking now).

## g) Drift control

TODO_LIST queue row re-worded `[ready]`→`[blocked:user]` (D3b); `docs/todo/services.md` handoff row updated to the REMAINDER ask + G1 row pre-gated on the re-probe; plan § Duplication extended with the anti-15× rules; this report closes the session. Secrets discipline held: URLs/cookies written only into 0600 files under the 0700 staging root; no values echoed (probe prints host/magic/size only).
