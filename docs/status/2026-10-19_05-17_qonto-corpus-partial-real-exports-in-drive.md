# Status — Qonto corpus is PARTIAL: the real full exports live in the owner's Drive folder (2026-10-19 05:17 CEST)

**Current date-time:** 2026-10-19 05:17:15 CEST, evo-x2.

**Trigger:** owner reaction to the imported volume ("That seems VERY little!") + the authoritative pointer: `https://drive.google.com/drive/folders/1_uW-afLLLEBy7y2k_PSzuhxymd5kAKHb` — the real Qonto exports for both Artmann orgs live there.

## What this session established this round

1. **The local corpus is provably partial.** `data/historical/qonto/transactions/*.csv` landed in git 2026-02-27 together with the import feature commit (606688f4) — a one-shot export set: Technologies only 2023-01-04→2023-03-20, Holding 2022-12-07→2023-05-18. For accounts that visibly moved €12k–€25k per transaction in Q1 2023 alone, these windows are fragments.
2. **Nothing more exists on the box:** searched `~/Downloads`, `~/data`, `~/projects/data`, the whole of `/home/lars` and `/mnt/pool` (bounded find) for `*qonto*` / `*export*transaction*` — only the two known CSVs (+ their labels/memberships siblings). The Drive-mirror paths the in-flight drive-paperless pipeline references (`/mnt/pool/backups/google-drive{,-work}`) do not exist yet — that pipeline is mid-build, not a live mirror.
3. **The Drive folder itself is not reachable from this session:** the public fetch returns nothing usable (auth/JS-gated), and wiring rclone/google-sync credentials is the google-sync arc's surface, not something to improvise mid-report.

## a) FULLY DONE

1. Everything from the prior reports stands: 132 rows of the PARTIAL local corpus live on the dashboard (amounts byte-exact), convergence proven, all unit fixes deployed, docs/lessons/P0 rows pushed.
2. This round: corpus-completeness audit executed (box-wide search + git provenance) with a definitive negative result; Drive folder identified as the authoritative source.

## b) PARTIALLY DONE

1. **Full Qonto history serving** — blocked on getting the Drive folder's contents onto the box. Once the files land in `data/historical/qonto/transactions/` (any format the importer reads — Qonto CSV), the deployed stage+import units absorb them automatically at the next activation (idempotent; new rows merge; new profiles/accounts derive stably). Verification recipe already committed.

## c) NOT STARTED

1. Enumerating/importing the Drive folder contents (access).
2. The standing external blockers: paperless DB restore (root, P0 row), Qonto attachment creds (owner), pma relock (push).

## d) TOTALLY FUCKED UP

1. In the first status reports I called the local two-CSV set "the corpus" without challenging its completeness — the windows were visibly narrow and I imported without flagging the gap to the owner. The "VERY little" reaction was earned; a completeness challenge ("these windows look fragmentary — is this everything?") belonged in the FIRST report.

## e) WHAT WE SHOULD IMPROVE

1. Historical imports get a coverage sanity-check against known account lifetimes BEFORE being declared done — narrow windows are a finding, not a detail.
2. Owner-data pointers (Drive links) should be captured into the repo/task the moment they appear (this report does that for the folder ID).

## f) NEXT

| # | Task | Impact | Effort | Owner |
|---|------|--------|--------|-------|
| 1 | Get the Drive folder contents onto the box (owner download-drop into the repo dir, OR wire the google-sync remote read-only, OR the drive-paperless ingest once live) | 🔴 completes the corpus | S-M | owner/me |
| 2 | Validate each new CSV (headers, windows, junk rows) + let the deployed units import; verify row counts + dashboard | 🔴 | S | me |
| 3 | Paperless DB restore (P0) → then the statement-upload verification (recipe committed) | 🔴 | S | root session |
| 4 | Extend the paperless statement upload to the FULL export set (titles/created per period) once the corpus is known | 🟠 | S | me |
| 5 | Qonto attachment creds → receipts archival | 🟠 | owner |
| 6 | pma forward relock | ⚪ | push |

## g) TOP 3 QUESTIONS

1. **Drive access:** how do you want the folder's exports to reach the box — (a) you download and drop them into `~/projects/bank-sync/data/historical/qonto/transactions/`, (b) I wire read-only access via the google-sync/rclone remote (which remote name is the right one?), or (c) wait for the drive-paperless ingest pipeline to go live?
2. Are the Drive exports **CSV transaction exports** (what the importer reads), or do they include other artifacts (attachments/PDF statements) that should also flow into Paperless-ngx?
3. Should the full-history import also extend the archive set (more statement documents per period), or keep the current two period-span CSVs as the archival representation?
