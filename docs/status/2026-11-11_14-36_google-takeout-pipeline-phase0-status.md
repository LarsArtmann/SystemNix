# Google Takeout Retirement Pipeline — Phase 0 Status + Handoff Received

**Session:** 2026-11-11 09:27 → 14:36 (single agent session, no deploys, no Nix eval changes)
**Scope:** the 880.08 GB racedriver8k Takeout (68 products, 23 parts, expires **2026-11-18 03:13**): plan + tooling + owner decisions + handoff intake. No bytes downloaded yet.
**Plan:** [docs/planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md](../planning/2026-11-11_09-30_google-takeout-retirement-pipeline.md) (EXECUTING marker live; D1=B, D4=all, zips kept, staging `racedriver8k-2026-11-10`).
**Parallel-session note:** a sibling session restructured the lock-float audit mid-flight (deleted `flake/expected-locks.nix`, `lib/lock-float-audit.nix`, `scripts/float-register.sh` — their work, untouched); evo-x2 toplevel eval was red on their cv float at 11:5x and their tree is still dirty. My commits are docs+scripts only (eval-irrelevant per `scripts/lib/eval-relevant-paths.sh`).

## a) FULLY DONE

1. **The plan doc** — 8 phases, gates G1–G5 + close-out, routing table, storage math (peak ≤ 2.7 TB on the 11 TB-free pool), security rules, retirement checklist (account deletion is owner-last). Committed + harvested.
2. **`scripts/takeout-download.sh`** — manifest-driven downloader: curl resume (`-C -`, outer attempt loop), stall-detect (`--speed-time 300 --speed-limit 10240`), size gate, **exact-byte manifest support** (plain-integer spec ⇒ lo==hi), **`ingest-html`** subcommand (parses the saved manage-archives page's `data-download-uri`/`data-size`/`data-filename` triplets → urls.txt + parts.tsv with EXACT sizes + filenames; href-only fallback; relative-URI absolutizer; "See report" link naturally excluded), cookies optional with 0600 enforcement. Fixture-tested 3/3 parts with the report link present.
3. **`scripts/takeout-verify.sh`** — Gate G2 battery (unzip CRC over all bytes, 68-product coverage matrix w/ fuzzy+override matching, inventory.tsv, photos-media-count.txt, SHA256SUMS, verification-report.md) + **4-leg `--selftest`** (happy / CRC-corrupt / missing-product / missing-part) — GREEN. The selftest caught three real bugs before they could bite (see d).
4. **`scripts/takeout-ingest-photos.sh`** — immich-go 0.32.0 wrapper, `--include-unmatched` PINNED (modern Takeouts ship no JSON sidecar for unedited photos — the default would skip most of the library = mass data loss), port via integration manifest (stdin-form jq, direnv-safe), key-file 0600 gate, `--dry-run` passthrough, loud failure paths (tested: no-staging, no-key).
5. **Owner decisions landed** (D1=B Takeout-only + rclone→ROADMAP; D4=all docs; zips kept permanently; D3 save-the-page flow) — recorded in the plan § Decisions, ROADMAP entry, google-sync.md pointer, queue + 6 library rows. TODO gate green at commit time.
6. **Handoff received (in chat):** the owner created the staging dir, dropped `cookies.json` (cookieStore export: 8 cookies — `SID, APISID, SAPISID, __Secure-1PAPISID, __Secure-3PAPISID, SIDCC, OTZ, SEARCH_SAMESITE`), and pasted the **full manage-archives page HTML** (all 23 `data-download-uri`/`data-size`/`data-filename` triplets, i=0..22, exact byte sizes 577345224 … 52610731378, sum ≈ 879.65 GB ✓).

## b) PARTIALLY DONE

1. **Staging artifacts NOT yet written.** The paste's 23 URLs + exact sizes + filenames are verified in-chat but `urls.txt`/`parts.tsv` are not yet generated into the staging root (script ready: `ingest-html` against a links.html assembled from the triplets — assembly pending).
2. **cookies.json → cookies.txt conversion NOT done** (jq → Netscape TSV, 0600) and **auth NOT probed**: the cookieStore export lacks the HttpOnly family (`HSID, SSID, __Secure-1PSID, __Secure-3PSID, __Secure-*PSIDTS`) — cookieStore cannot see HttpOnly. Whether `SID`+`SAPISID`+`SIDCC` suffice for takeout download auth is UNKNOWN until the part-13 probe (565 bytes — a legitimate part, costs one download of a 565 B file). If insufficient: owner exports via DevTools → Application → Cookies (shows HttpOnly) or a LOCAL-ONLY exporter extension.
3. **The exact-size/ingest-html upgrade is UNCOMMITTED** (working tree; shellcheck-clean, fixture-green as of 14:36). The committed state (39834d449) still carries the rounded-band manifest + the broken `/download/<token>` regex.

## c) NOT STARTED

1. Gate G1 — the download itself (0/23 parts; ~6.6 days of deadline left).
2. Gate G2 — completeness battery over the real zips.
3. Gate G3 — Photos → Immich (needs owner Immich API key at `<staging>/immich-api-key`).
4. Gates G4/G5 — Drive extract → OpenCloud WebDAV + drive-paperless over the extract (needs owner OpenCloud app password for the rclone leg).
5. Phase 6/7 — small-product archive handling, data-ownership inventory flip, retirement checklist.

## d) TOTALLY FUCKED UP!

1. **I built the links.html extractor against an INVENTED page shape.** First implementation matched only absolute `https://takeout.google.com/takeout/download/<token>` URLs; the REAL page uses relative query-form URIs (`takeout/download?j=…&i=N&…`) carried in `data-download-uri` attributes (with the "See report" link differing only by `i=23`). Would have extracted 0 links. Fixed by the ingest-html rework after the real HTML arrived — but the fixture-driven test culture failed me here: my fixture encoded my assumption, not reality. The new fixture replicates the REAL shape (attrs + entities + report link) — derived from the owner's actual page.
2. **A multiedit shipped a two-lines-into-one awk syntax error** (the newline-eating edit in the media-count block) while shellcheck was clean on the previous run — caught only by the selftest happy leg dying with empty output. Lesson re-learned: after EVERY edit, re-run the full battery, not just `bash -n`.
3. **My download "test" fired REAL network curl attempts** at fabricated takeout URLs with retry loops (killed via job_kill ~1 min in). A test that touches the network path must use a stubbed URL (file:// or a refused port), never a real hostname — worst case it burns link-download quota or trips Google-side rate shaping.
4. **Three edit-tool rejections from stale reads** (file-modified-since-read; grep-via-bash does not refresh the edit tool's view). Known house rule; cost 3 round-trips.
5. **Manifest-format churn:** parts.tsv grew a filename column v2; both scripts' readers were updated, but any EARLIER staging dir initialized with v1 + later re-verified with v2 would still parse (spec column takes field 1 via awk) — verified by reasoning, NOT by a v1→v2 compat fixture (gap, noted).
6. **Commit-message subject 82 chars** on the first paperwork commit attempt (hook rejected; retried shorter). Cosmetic, zero damage.

## e) WHAT WE SHOULD IMPROVE

1. **Parse the real artifact before writing the parser** — when a handoff artifact (page HTML, API response) is expected, build the fixture FROM it, not from imagination. This is now done for takeout; make it the standing rule for every handoff-consuming script.
2. **Network-touching tests get stubbed transports** (`--url file://…` style seams or env-pointed hosts), never real hostnames in "test" runs.
3. **Commit after each verified green state** — the exact-size upgrade sat uncommitted across a question round; a daemon sweep could have grabbed the BROKEN intermediate (the one from d.2) instead.

## f) Top next tasks (ranked)

| # | Task | Impact | Effort | State |
| --- | --- | --- | --- | --- |
| 1 | Assemble links.html from the verified triplets → `ingest-html` → staging urls.txt + parts.tsv (exact) | Critical | S | [ready] — everything verified, one command chain |
| 2 | Convert cookies.json → cookies.txt (Netscape, 0600) | Critical | S | [ready] |
| 3 | Probe auth: fetch part 13 (565 B) with cookies; if 302→accounts.google.com → request proper cookie export (DevTools shows HttpOnly) | Critical | S | [ready] |
| 4 | Fire Gate G1 (`takeout-download.sh start` under tmux; 1–3 days) | Critical | M | [ready] after 1–3 |
| 5 | Gate G2 verify battery + report | Critical | M | queued row exists |
| 6 | Gate G3: owner Immich API key → dry-run → real ingest (days) | High | M | queued row exists |
| 7 | Gates G4/G5: OpenCloud app password → rclone WebDAV + drive-paperless | High | L | queued row exists |
| 8 | Commit the exact-size/ingest-html upgrade (shellcheck-green fixture-green NOW) | Medium | S | [ready] |

**Harvest status:** rows for 1/3/4/5/6/7 already live in `docs/todo/services.md` (Takeout block) + the G1 queue row in TODO_LIST; the handoff row needs its D3 text updated (cookies.json form factor + probe step) — will ride the next commit.

## g) Questions I cannot answer myself

**Q1 — Cookie sufficiency:** is a DevTools/extension cookie export available if the cookieStore set proves insufficient? (The probe decides; if it 302s to accounts.google.com, I need one more drop — the HttpOnly family is not obtainable from `cookieStore.getAll()` by construction.)
**Q2 — Token custody:** the page HTML you pasted carries the `rapt` token (account-data-bearing). I will write it into staging files at 0600 inside the 0700 staging root and never echo it again — same custody class as cookies. Shout if you want it rotated after the download instead.

## Verification log

| Check | Command | Result |
| --- | --- | --- |
| Syntax | `bash -n` ×3 scripts | clean |
| Lint | `shellcheck` ×3 scripts | clean (SC2318/SC2001 fixed, not suppressed) |
| Downloader fixture | synthetic links.html (attrs + entities + report link) via `ingest-html` | 3/3 parts, exact sizes+filenames, report excluded, 3 absolute URLs |
| Verify battery selftest | `takeout-verify.sh --selftest` | 4/4 legs GREEN (happy/CRC/coverage/missing-part) |
| Ingest failure paths | no-staging, no-key | loud, correct pointers |
| Exact-size sum | triplets from the real page | ≈ 879.65 GB — matches the page's stated total |
| TODO gate | `check-todo-system.sh` (at last commit) | OK (WARNs = known baseline) |
| Cookie inventory | `jq .[].name` (names only, no values) | 8 cookies, HttpOnly family absent |
