# Browser-History "Firefox Zero" Verdict + Two Upstream Bugs + Behavioural Residue

- **When:** 2026-10-14, ~22:14–23:05 CEST (continuation session of tonight's browser-history stats-verdict + re-attribution work)
- **Agent session:** crush session on evo-x2, SystemNix cwd; read-only against prod (SQL + journal + source), zero writes to live services
- **Trigger:** owner asked "**Why is firefox zero? I just visited wikipedia!**" after the 22:03 zero-user→owner re-attribution
- **Deployed surface:** browser-history agent+server `8900354` = upstream HEAD = SystemNix flake.lock (unchanged tonight, verified earlier at 21:47)

---

## a) FULLY DONE

1. **Verdict delivered and layer-verified: firefox is NOT zero at the visit layer — the owner's 22:00 wikipedia visit is captured, ingested, owner-scoped, and on the dashboard.**
   - **places.sqlite** (WAL-aware copy; live file is `database is locked` under Firefox): `https://www.wikipedia.org/` present at 22:00:00 as **visit_type=2 (TYPED)** + 4 wikivoyage visits to 22:00:23 (owner searched "Appleton"). Profile = light secondary browser (682 visits total since Jan, newest-10 mostly file:// PDFs). Schema note: this Firefox `moz_historyvisits` has **no `visit_duration` column** (it carries `source`/`triggeringPlaceId` instead).
   - **Agent journal** (ticks 22:09/22:14/22:19/22:24): firefox reads `raw=2 filtered_out=2 kept=0 skipped_by_cursor=0` on every tick; the 3 kept visits (wikipedia + 2 wikivoyage) were ingested at the ~22:04 tick; helium healthy (kept 1–13/tick, all accepted, rejected=0).
   - **Server DB** (`/var/lib/private/browser-history/data.db`, sudo-wrapped sqlite): exactly **3 firefox rows today** — wikipedia.org 22:00:00 (typed_count=1), wikivoyage.org 22:00:14, search-redirect 22:00:22 — all `user_id=01M000JA6P0VR4Q1BNEPSJN3ME`, `last_visit_time` correct in **nanoseconds**.
2. **Why it LOOKS zero (the burial math):** the dashboard has NO per-browser count anywhere — no `GROUP BY browser` in any query, no browser strings in any template (the only firefox UI element is the static "Filter by browser" dropdown, `api/filter_options.go:23`). `visitsPerPage = 20` (`api/dashboard.go:22`); **24 owner rows are newer** than the newest firefox row (owner actively browses in helium — 23 helium keeps between 22:09 and 22:24 alone), so tonight's firefox rows sit off page 1 of the unfiltered recent-visits. Where to SEE them: Visits page → Filter by browser → Firefox → tonight's 3 rows at top.
3. **The two remaining "stuck" firefox visits are dropped BY DESIGN, proven in deployed source:** `extraction/transition.go` `FirefoxTransitionFromType` maps Firefox redirect types 5/6 onto `TransitionAutoSubframe` ("Redirect visit types collapse onto AutoSubframe so the shared redirect/popup filter handles them identically"), then `filter.go` `IsLikelyPopupOrRedirect` drops them. The 2 rows are the wikivoyage `Special:Search` and — notably — **the final `/wiki/Appleton` article the owner actually read** (the whole chain was redirect-typed). `cmd/browser-history-agent/main.go` `advanceCursor` runs on **kept visits only, after a successful POST**, so the cursor stays parked below them: the same 2 rows re-report `raw=2 kept=0` every tick forever until a newer kept firefox visit pushes the cursor past. This journal pattern means "cursor parked on filtered redirects", NOT a stuck agent.
4. **BUG #1 (upstream, ALL browsers): behavioural sync fails to marshal every tick.** Live journal 22:09–22:24: `behavioural sync failed (non-fatal) err="marshal behavioural: json: cannot marshal from Go time.Duration within \"/engagement/0/totalViewTime\": no default representation" total=133` (constant). Root: `domain/visit/behavioural.go:66-69` types `TotalViewTime`/`TypingTime`/`ScrollingTime` as `time.Duration`; the sync marshaler rejects the payload client-side, BEFORE any HTTP send. Consequence verified live: **`engagement_metrics` is EMPTY for all browsers** (and `logins` empty — separate question, likely genuine).
5. **BUG #2 (upstream, firefox-only): no search extraction at all.** `extraction/firefox.go` has zero search/omnibox paths (rg-verified); `search_queries` holds 225 helium (Chrome-family path) vs **0 firefox structurally** — a Firefox urlbar search can never appear under searches. This is the second "firefox zero" surface.
6. **NEW FINDING (22:58): behavioural-table zero-user residue.** The 22:03 re-attribution UPDATE covered **`visits` ONLY**. Six behavioural tables still hold **217 all-zeros-user rows**: search_queries 125, downloads 58, form_history 20, bookmarks 7, permissions 5, omnibox_inputs 2 (per-table GROUP BY user_id). Every dashboard query scopes `user_id = <session user>`, so the owner's searches/downloads/bookmarks pages UNDERCOUNT (visible helium searches = 100, not the 225 table-wide). Same agent-era provenance as the re-attributed visits, but the zero-overlap verification + owner authorization covered `visits` specifically — extending the op is queued [blocked:user], not self-executed.
7. **Close-out per queue discipline (all harvested at authoring time):**
   - `docs/services/browser-history.md`: dated entry 22:30 (verdict + redirect mechanics + cursor semantics + probe note "copy main+`-wal` to /tmp, `-readonly` fails") + dated entry 22:58 (behavioural residue).
   - `docs/todo/upstream.md`: +2 new `[ready]` rows (behavioural marshal fix; firefox search extraction), +1 `[decision]` row (redirect-chain landing loss), +1 `[ready]` row (downloads firefox=0 mechanism), reattribute row scope-expanded to "visits + behavioural tables + events".
   - `docs/todo/services.md`: +1 `[blocked:user]` row (217-row stop-window re-attribution), +1 `[ready]` row (render-proof the burial claim via repro harness).
   - `TODO_LIST.md`: matching one-liners for every new row; reattribute one-liner updated (no drift).
   - `bash scripts/check-todo-system.sh` → **`OK: TODO queue/library structure clean`** (the 111-unharvested WARNs are the pre-existing global corpus, incl. other sessions' reports — not mine to harvest).
   - Hygiene: /tmp places.sqlite copies trashed after use (they carry the owner's browsing data).

## b) PARTIALLY DONE

1. **Render-proof of the burial claim.** The "off page 1" conclusion rests on SQL (`24 newer rows`) + `visitsPerPage=20` + the `Limit: visitsPerPage` line at `dashboard.go:346` read as the shared page size — **no page was actually rendered with the owner's data** (the 21-47 repro recipe — fresh-DB registration + read-model re-attribution + session fetch — was available but not run). High confidence, explicitly NOT pixel-verified; same disclosure class as the 21-47 report's repro gaps. Queued `[ready]`.
2. **Dashboard section-limit trace.** Did not fully trace which consumer `dashboard.go:346` `Limit: visitsPerPage` feeds (assumed the recent-visits section). Folded into the render-proof row.
3. **downloads firefox=0 mechanism.** Not determined: `firefox_download_test.go` exists (downloads ARE wired for firefox), so the zero is either genuine (no downloads in this profile) or a live gap (profile path, downloads-store schema drift). Queued for determination.
4. **Marshaler identification for BUG #1.** Fix direction is clear (int64-nanos fields or custom MarshalJSON — stdlib `encoding/json` marshals `time.Duration` fine as an integer, so the failing marshaler is a schema-constrained non-stdlib codec, likely in the agent's client path); the exact library behind "no default representation" is unnamed in the queue row. At filing time, verify-before-filing covers it.

## c) NOT STARTED

- **Filing BUG #1/#2 upstream** (verify-before-filing gate + github-voice; pushes are owner-gated by standing policy regardless).
- **Firefox search extraction** (upstream feature decision: synthesize from TYPED visits vs declare Chrome-only).
- **The 217-row behavioural stop-window op** ([blocked:user] — needs explicit owner authorization; tonight's authorization covered `visits` only).
- **Render-proof repro run** (nothing was rendered this session).
- Nothing else from this session's ask remains.

## d) TOTALLY FUCKED UP

**Nothing shipped wrong.** No destructive ops, no wrong verdicts, prod untouched (read-only SQL, journal reads, source reading), server not restarted, no commits made (auto-commit daemon owns that). Two process stumbles, both caught in-session BEFORE they contaminated anything:

1. **Unit misread, repeated class.** I formatted `last_visit_time` as microseconds (`/1e6`) → NULL/empty datetimes; the column is **nanoseconds** (`/1e9`). This is the SAME class as tonight's 21-47 report retraction (journal `duration` ms-vs-ns misread). The lesson did not transfer to the new column — I self-caught only because the empty output looked impossible.
2. **False-negative near-miss.** My first wikipedia LIKE query "returned empty" — it had actually **parse-failed** (`no such column: visit_duration`), with stderr/stdout interleaving making the error look like it belonged to the NEXT command. For a moment the evidence read as "wikipedia absent from places.sqlite" — the exact wrong premise that would have flipped the whole verdict. Caught on the follow-up schema check. (An empty SQL result is only evidence after the error path is checked.)
3. *(Minor)* Two burned commands on the places.sqlite lock before going to the copy pattern; and one services.md edit raced the auto-commit daemon (`file modified since read`) — re-read and re-applied cleanly, no damage.

## e) WHAT WE SHOULD IMPROVE

1. **Unit-anchor discipline:** before any datetime formatting on an unfamiliar timestamp column, render ONE known-recent row and sanity-check the date before trusting bulk output. (Would have saved both tonight's misread and 21-47's.)
2. **Empty-result discipline:** empty query output + exit 0 must still be checked against stderr ordering; an interleaved parse error made a failed query LOOK like a clean empty result.
3. **Copy+WAL-first for live Firefox DBs:** `places.sqlite` is always WAL-locked by a running Firefox; the copy-both-files pattern should be the FIRST move (now a runbook probe note).
4. **Render-proof reflex:** any claim that is geometric/inferred ("buried below the fold") either gets the repro render or is explicitly labeled inferred — I labeled it, but the harness recipe (queued since the 21-47 report §f.13) still isn't a script, which is exactly why it felt too heavy to just run. Codify it once, use it every time.
5. **Re-attribution ops need a table-by-table completeness checklist:** tonight's op fixed `visits`; the same session's own verification (`post_zero=0` on visits) was TRUE but INCOMPLETE — 217 behavioural rows stayed orphaned until this follow-up looked. The upstream `reattribute` command row now demands ALL user-scoped surfaces; the local checklist should enumerate tables BEFORE declaring post_zero victory.
6. **Queue numbers state their scope:** the firefox-extraction row cites "225 helium" — correct table-wide, but the owner-VISIBLE number is 100 (rest is zero-user residue). When the whole point is what the owner sees, cite the owner-visible number with the table-wide number in parens.
7. **§f honest-sizing:** the "up to 50 next things" ask deserves a real answer, not padding — the dispatch queue already owns prioritized next-work; restating 30 existing rows inside a status report violates the one-ask-one-row discipline. §f below lists the new/advanced items explicitly and points at the queue for the rest.

## f) NEXT (harvested at authoring; queue owns the rest)

**New this report (rows written to `docs/todo/{services,upstream}.md` + `TODO_LIST.md`):**

| # | Item | Tag | Surface |
|---|------|-----|---------|
| 1 | Stop-window re-attribution of the 217 zero-user behavioural rows (6 tables; re-run zero-overlap + backup gates first) | `[blocked:user]` | services.md |
| 2 | Render-proof the firefox-burial claim via repro harness (+ trace `dashboard.go:346` consumer) | `[ready]` | services.md |
| 3 | Fix behavioural sync marshal failure (time.Duration fields; acceptance: one tick logs `behavioural sync complete`) | `[ready]` | upstream.md |
| 4 | Add Firefox search-query extraction (or declare Chrome-only + stop rendering the permanent zero) | `[ready]` | upstream.md |
| 5 | Determine downloads firefox=0 mechanism (genuine vs gap) | `[ready]` | upstream.md |
| 6 | `reattribute` command — scope EXPANDED: visits + behavioural tables + events (was visits+events) | `[ready]` | upstream.md |
| 7 | Redirect-chain landing-page-loss discussion (keep the last chain visit?) | `[decision]` | upstream.md |

**Advanced/validated by this session (already queued, not duplicated):**

| # | Item | Where |
|---|------|-------|
| 8 | Behavioural-fix filing gate (verify-before-filing: re-read behavioural.go/client.go at HEAD + issues) | upstream.md row 3 acceptance |
| 9 | Owner-visible vs table-wide counts become correct automatically once #1 lands (searches 100→225 for helium) | consequence of row 1 |

**The queue already owns the prioritized remainder** (hot-db-bootstrap diagnose, crowdsec first-activation failure, /run/current-system anchor, hot-db.md LIVE flip, migrate-hot-db checkpoint step, nightly btrbk watch, dnsblockd QLC reclaim, Python sweeper deletions, dnsblockd race filing, DiscordSync FOD invariance + lockstep port + 2 pre-existing test failures, templ-components v1.23 verification, .gitignore sweep, geometrikks ×2, go-taskqueue ×2, CI-watch wave, slow-render-burst watch, runbook-polish, upstream reattribute + the rows above). Per the TODO-system rules I will NOT restate them as new report items — the queue is the single source of truth. Explicitly NOT harvested: the missing-`visit_duration` Firefox schema observation (agent works without it; no action until something breaks).

## g) QUESTIONS FOR THE OWNER (cannot self-answer)

1. **WHERE did you see "firefox zero"?** (a) unfiltered dashboard recent-visits (my burial theory), (b) the Searches section, (c) the visits page with the Firefox filter selected, (d) somewhere else. This decides whether the render-proof run is even the right next move, and which fix surface matters.
2. **Redirect-chain landing pages:** current design drops the WHOLE chain — including the final article you actually read (`/wiki/Appleton` is invisible; only the redirect stub survived). Keep the design, or should I file the upstream discussion to keep redirect-terminal pages (the last visit of a chain, or any redirect above a duration threshold)?
3. **BUG #1 (behavioural sync marshal, engagement empty for ALL browsers):** it's your repo — do you want me to FIX it directly in LarsArtmann/browser-history (implement + tests; push stays owner-gated per standing policy), or file the issue only and move on?

---

*Evidence trail: places.sqlite WAL-copy queries, agent journal 21:55–22:24, live server DB via sudo-wrapped sqlite3, deployed-source reads at `8900354` (local checkout = upstream HEAD, clean). Prod untouched; no commits; auto-commit daemon owns the tree.*
