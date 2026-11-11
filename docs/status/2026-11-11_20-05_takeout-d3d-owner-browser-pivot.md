# Google Takeout — agent clients exhausted, D3d owner-browser download pivot (2026-11-11 20:05 CET)

Session: takeout-retirement Phase 1, round 3 (continuation of `2026-11-11_15-50_takeout-rapt-forensics-d3c-owner-ask.md`). Plan intake log holds the canonical narrative; this report is the round-3 evidence + pivot record.

## a) The fresh page arrived and was GOOD

Owner saved the manage-archives DOM as `Google Takeout.html` (17:37, 1.46 MB): all 23 parts present as **href-form `takeout/download?…&rapt=…` links** (24 hrefs = i=0..23; i=23 is the see-report link), one **shared fresh rapt**, `user=1134…` on every URI. Extracted → `urls.txt` (i=0..22, page order). Bug found+fixed in my own extraction: bare `sort -n` on tab-joined lines mis-ordered (line 12 was i=10); correct form is `sort -t$'\t' -k1,1n` — verified sequence 0..22 after rebuild.

## b) Even a FRESH rapt does not authorize non-browser clients (all RED)

| Client | Result |
| --- | --- |
| curl + full Google-only jar + fresh rapt | 302→`accounts.google.com` login HTML |
| curl + SAPISIDHASH Authorization (computed exactly as Google JS: `SHA1(SAPISID origin ts)`), Origin/Referer, Chrome UA | RED (1.19 MB login page) |
| headless chromium (playwright + nixpkgs chromium 157) + jar, cookies VERIFIED applied (21 visible for takeout.google.com — the earlier "bot-challenge" theory also had a host-only-domain cookie-loader bug, fixed, outcome unchanged) + real-Chrome UA, direct-to-URL navigation | RED (`accounts.google.com`, no download event) |

Conclusion: the takeout download is bound to the real browser environment (TLS/JS/device signals) beyond anything cookies+headers can reproduce. Same jar renders takeout pages authed in curl — the gate is specific to the download action.

## c) Pivot D3d — owner's real browser downloads (the intended UX)

- `<staging>/download-all.html` generated (0600): all 23 fresh-rapt links, labeled part/filename/size, with instructions.
- `scripts/takeout-browser-rename.sh` committed (fixture-tested: exact-size→rename+0600, mismatch→held, unmapped→listed; dry-run default, `--apply` to rename).
- `takeout-g1-rename` systemd --user unit runs the rename loop every 5 min, logs to `logs/rename-loop.log`, exits at 23/23 → G1 green.
- `takeout-g1-watch` (the D3c auto-fire watcher) STOPPED 17:44 — superseded by the browser flow.
- After G1: `takeout-verify.sh` (G2, hours of CRC), then the routing phases unchanged.

## d) Owner instruction (single remaining ask)

In the logged-in browser: open `download-all.html` from the staging root, set the browser download folder to `<staging>/zips`, click the 23 links top-to-bottom — **today** (rapt minted 17:37; freshness window unknown). A failed download: click its link again. Everything else is automatic.

## e) Attribution incident (own goal, recorded)

My post-lock-wait `git commit --amend` (470a0431e) violated the daemon-race rule ("verify WHAT the daemon staged before amending" — AGENTS.md): it was HEAD-blind after the wait-loop and rewrote a FOREIGN session's commit message (monitor365 rows; content fully intact, and that session re-landed its attribution in 68260eb1e). No data affected; history left as-is (a second rewrite on a busy tree is the greater risk). Lesson re-confirmed: amends must run `git show --stat HEAD` verification INSIDE the same atomic step, never after a blind wait.

## f) State at handoff

zips/ empty (0/23, rename loop live); deadline 2026-11-18 03:13; Google Takeout jar trimmed Google-only (reminder stands: delete the exporter's cookies.txt from Downloads — eTrade/GitHub/LinkedIn sessions); G2–G5 tooling unchanged and green.
