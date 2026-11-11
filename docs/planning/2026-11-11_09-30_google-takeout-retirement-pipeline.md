# Google Account Retirement — Takeout 880 GB Pipeline

**EXECUTING (instance takeout-retirement session (Phase 0), HEAD 59967d2ec, 2026-11-11 11:54 CET, HEAD `59967d2ec`):** executing (see AGENTS.md plan-execution tombstone)

## Trigger and deadline

Owner request (2026-11-11): retire Google accounts; the first export (68 products, **880.08 GB**, 23 zip
parts) must be downloaded **fully** to the HDDs and ingested — **without data or metadata loss** — into
Immich (photos), OpenCloud (files), Paperless-ngx (documents), with everything else archived.

**Hard deadline: the export expires 2026-11-18 03:13 (7 days).** After that the links are dead and a new
export must be requested. Download must START within ~48h to leave verification + ingestion buffer.

Export facts (from the Takeout summary page, paste 2026-11-11):

- 23 parts: `550.6 MB · 43.34 · 44.41 · 41.83 GB · 839 MB · 50.01 · 50 · 50 · 50 · 49.62 GB · 226.2 MB · <1 MB · <1 MB · 49.97 · 50 · 49.96 · 49.94 · 50 · 50 · 49.98 · 50 · 50 GB · 49 GB`
- Big three: **Drive 543.33 GB · Google Photos 336.02 GB · Mail 1.74 GB**; 39 products with data, 29 "No data found"
- Every part: "Number of times already downloaded: 0" — links have a limited re-download count; do not burn fetches on partial tests (resume ranges, not re-GETs)

## Verified live state (2026-11-11 probes)

| Fact | Evidence |
| --- | --- |
| `/mnt/pool` = 2×16 TB BTRFS RAID1, **11 TB free** | `df -h /mnt/pool` |
| Pool `archive/` is root-owned (agent cannot mkdir; owner runs one `sudo install`) | `test -w` probe 2026-11-11 |
| Immich LIVE, media on `/mnt/pool/services/immich` (btrbk-snapshotted), port 2283, API v3 checksum-dedup | `docs/services/immich.md` |
| OpenCloud pilot LIVE (production line 7.2.4), state `/mnt/pool/services/opencloud` (posix + xattrs), WebDAV at `cloud.home.lan` | `docs/services/opencloud.md` |
| Paperless LIVE, `dataDir=/mnt/pool/services/paperless`, DRF API upload + duplicate rejection | `docs/services/paperless.md` |
| `services.google-sync` (rclone Drive→pool mirror, mtimes preserved, 30d deletion grace) + `services.drive-paperless` (hourly doc→Paperless / image→Immich routing, batched 200/run) — BOTH DORMANT, go-live = owner OAuth sequence | `docs/services/google-sync.md` |
| `immich-go` 0.32.0 in nixpkgs; `upload from-google-photos` eats Takeout **zips directly**, `--sync-albums` (albums from album folders), partner/archived included, `--dry-run` available — CLI verified live 2026-11-11 | `nix shell nixpkgs#immich-go` |
| Photos Library API is CLOSED to third-party originals (since 2025-03-31) — Takeout is the ONLY photos path | `docs/status/archived/2026-08-18_00-40_*` (verified research) |
| This pipeline IS the "two Google accounts' export/Takeout escape hatch" P0 deliverable from the contacts/calendar doctrine | `docs/status/2026-10-29_21-43_*` §c.10 |

## Routing (what goes where)

| Takeout product | Destination | Mechanism | Metadata fidelity |
| --- | --- | --- | --- |
| Google Photos (336 GB) | **Immich** | `immich-go upload from-google-photos` directly on the zips | Albums (`--sync-albums`), descriptions, GPS, timestamps from JSON sidecars; `--include-unmatched` REQUIRED (modern Takeouts ship no sidecar for unedited photos — skipping unmatched would be mass data loss) |
| Drive (543 GB) | **OpenCloud** + pool archive | **D1 = B (owner, 2026-11-11):** Takeout extract → WebDAV (rclone, vendor=owncloud) into OpenCloud; the rclone live-mirror is the queued ROADMAP fidelity upgrade | B's known losses on record (mtimes, shared-with-me); zip entries carry original timestamps where Google provides them |
| Drive documents (pdf/office/txt/eml/…) | **Paperless** | `drive-paperless` pipeline over the canonical Drive tree (the D1-B extract) — account-named correspondents, per-remote tags, batched, journal-idempotent; **D4 = ALL docs (owner)** | designed semantics; byte-identical dedup server-side |
| Drive raster images | **Immich** | same pipeline with `ingestImages = true` (extension routing, `fileCreatedAt/fileModifiedAt` from Drive mtime) | needs the `drive_paperless_immich_api_key` sops go-live (sub-checklist in google-sync.md) |
| Mail (1.74 GB mbox) | pool archive (cold) | keep as archive | successor: mail-host import is a separate decision (mesh proposal), NOT this pipeline |
| Contacts (vCard) / Calendar (ICS) / Keep / Tasks / Maps / Fit / everything else | pool archive (cold) | keep as archive; `takeout-verify.sh` proves completeness | successor: D1-mesh PIM import (`docs/planning/2026-10-29_21-18_contacts-calendar-mesh-proposal.html`) consumes these on decision |
| All 23 zips (880 GB) | **kept forever** (default) as the immutable raw archive on `/mnt/pool/archive` | — | the "escape hatch" cold copy; deletion is a later owner decision |

**Duplication is by design — and capped at one raw copy + one working copy per service.** Peak pool need ≈ 880
(zips) + ~880 (extract staging, D1-B only, deleted again after G4+G5) + ~336 (Immich) + ~543 (OpenCloud) ≈
**≤ 2.7 TB peak, ~1.8 TB steady** — fits the 11 TB free with margin. Nothing ever touches QLC (`/` 60 G
free, `/data` 363 G). Anti-15× rules: (1) the zips are the ONLY raw copy — cold products
(Mail/Contacts/Calendar/…) are never extracted outside on-demand reads; (2) each service holds exactly ONE
working copy in its own datadir (Immich, OpenCloud, Paperless under `/mnt/pool/services/…`) — no second
mirror (D1-A declined), no agent-side caches; (3) services dedup server-side (Immich by checksum, Paperless
byte-identical rejection), so Photos∩Drive overlap costs nothing extra; (4) `<staging>/extracted/` is
TRANSIENT — deleted once G4 (`rclone check` clean) AND G5 (Paperless converged) are green, since OpenCloud
then holds the files, Paperless the docs, and the zips everything; (5) optional later: a pool-level BTRFS
reflink dedup pass (duperemove) if steady-state ever needs shaving — never required for fit.

## Decisions (owner, answered 2026-11-11)

- **D1 — Drive ingest path: B, Takeout-only for this retirement** (owner answer). The rclone live-mirror (path A: mtimes + shared-with-me fidelity) is queued as a ROADMAP item instead. **Accepted B risks, on record:** Drive file mtimes are LOST (zip export-time), and shared-with-me files never added to My Drive are NOT in the Takeout — before account deletion the owner should eyeball https://drive.google.com → "Shared with me" once.
- **D2 — staging root:** `/mnt/pool/archive/google-takeout/racedriver8k-2026-11-10/` (account named for the multi-account retirement; created by ONE owner sudo command).
- **D3 — link handoff: save-the-page flow.** Owner (logged in as racedriver8k) opens the Takeout "manage archives" page, `Ctrl+S` saves it as `links.html` into the staging root; `takeout-download.sh start` extracts the 23 download hrefs into `urls.txt` itself (page order, entities decoded — fixture-tested 23/23 with noise links excluded). `cookies.txt` (Netscape format, local-only browser exporter) rides along at 0600. Fallback if extraction ≠ 23: right-click → Copy Link Address × 23 into `urls.txt`.
- **D4 — Paperless scope: ALL Drive document-types** via the batched drive-paperless pipeline.
- **Raw archive: the 23 zips are kept permanently** on `/mnt/pool/archive` (owner answer) — the escape-hatch cold copy.

## Phases and gates

### Phase 0 — prep (this session; no owner input)

1. Plan doc (this file) + `plan-marker.sh start`. ✅
2. `scripts/takeout-download.sh` — manifest-driven downloader (23 parts, sizes embedded; curl resume; stall-detect; size-band gate; SHA256SUMS; cookies optional). ✅
3. `scripts/takeout-verify.sh` — completeness battery + `--selftest` fixture leg. ✅
4. `scripts/takeout-ingest-photos.sh` — immich-go wrapper (port via integration manifest, key from staging file, `-u` pinned, `--dry-run` passthrough). ✅
5. shellcheck + selftest green, TODO harvest, CHANGELOG. ✅

### Phase 1 — staging + download (owner: D2 mkdir + D3 links.html + cookies; deadline-aware)

```bash
# owner, once (agent shells cannot sudo; archive/ is root-owned):
sudo install -d -o lars -g users -m 700 /mnt/pool/archive/google-takeout/racedriver8k-2026-11-10
```

Owner, logged in as racedriver8k on takeout.google.com → manage-archives page:
1. `Ctrl+S` → save the page as `links.html` INTO the staging dir above.
2. Export `cookies.txt` (Netscape format) for takeout.google.com with a LOCAL-ONLY
   browser cookie exporter, drop it in the same dir.

```bash
# agent or owner, in tmux (runs 1–3 days):
bash scripts/takeout-download.sh /mnt/pool/archive/google-takeout/racedriver8k-2026-11-10 start
bash scripts/takeout-download.sh /mnt/pool/archive/google-takeout/racedriver8k-2026-11-10 status
```

**Intake log (2026-11-11, agent; latest state LAST):**
- **14:48** Links arrived as a page PASTE (not Ctrl+S): reconstructed `links.html` from the 23
  `data-download-uri`/`data-size`/`data-filename` triplets → `ingest-html` → `urls.txt` + `parts.tsv` EXACT
  (23/23, sum 944,513,645,689 B = 879.65 GiB, matches the page; 0600). Cookies arrived as `cookies.json`
  (JS cookieStore export, 8 cookies, NO HttpOnly family) → converted to Netscape `cookies.txt`.
- **14:52 Probe RED:** part fetch → http 200 but final host `accounts.google.com`, login HTML — cookieStore
  exports cannot work by construction. **CORRECTION of an earlier draft of this log: NO part is held — RED
  probes exit before install; `zips/` is EMPTY and no re-download budget was burned (all probe fetches
  landed on login pages, not part bytes).**
- **15:14–15:45 round 2 (owner dropped full browser jar, 295 cookies incl. HttpOnly):** jar is a VALID
  session — `curl` renders both the downloads and manage-archives pages authed (export visible, user id
  matches). Download URIs STILL bounce to `accounts.google.com`. Forensics: server-rendered HTML carries NO
  `rapt` param at all (113-char URI; the app bundle adds `rapt` client-side at click time) — the paste's
  token had gone stale. Probe without rapt: RED. Headless chromium (playwright + nixpkgs chromium, full
  jar imported, 86 HttpOnly): **challenged** by Google bot detection. Jar trimmed to Google-only (295→126
  rows; GitHub/eTrade/LinkedIn etc. dropped — owner should also delete the exporter's cookies.txt from
  their Downloads folder).
- **BLOCKING ask D3c (replaces the cookie ask — cookies are FINE now):** owner, in the REAL logged-in
  browser on the manage-archives page, `Ctrl+S` → "Webpage, Complete" → save as `links.html` OVERWRITING
  the one in the staging root, then ping. The saved DOM carries freshly minted `rapt`'d URIs; agent then
  `ingest-html` (verify 23/23 sizes/filenames unchanged) → probe part 12 → `start` detached, immediately
  (rapt freshness window unknown — treat as minutes-to-hours). Fallback if the save yields 0 triplets
  (browser saved original source instead of DOM): DevTools console
  `copy([...document.querySelectorAll('[data-download-uri]')].map(e=>[e.getAttribute('data-download-uri'),e.getAttribute('data-size'),e.getAttribute('data-filename')].join('\t')).join('\n'))`
  → paste into `<staging>/triplets.tsv`.
- **16:07 watcher ARMED** (systemd --user unit `takeout-g1-watch` running the committed
  `scripts/takeout-watch.sh`; probe: `scripts/takeout-probe.sh`; commit `ddf40c737`): the D3c save now
  AUTO-FIRES G1 — quiescence → validate (23 triplets, exact multiset vs `parts.tsv.known`) → `ingest-html`
  → probe part 12 → `start`, all under the unit; refusals exit loud to `logs/watcher.log` and re-arm
  manually. Do NOT hand-run a second `start`/watcher while the unit lives (`pgrep -f takeout-watch.sh`).
  Self-tested: positive DRY leg + two refusal legs (22 attrs; size-mutated) all behave.
- **17:37–17:55 round 3 — every agent-side client is BLOCKED by Google; PIVOT D3d = owner's real
  browser downloads.** The owner's DOM save ("Google Takeout.html") carries all 23 parts as href-form
  `takeout/download?…&rapt=…` links (i=0..23, one shared FRESH rapt, user id matches) — extracted into
  `urls.txt` i-ordered (an earlier numeric-sort bug shipped i=10 at line 12; fixed with tab-key
  `sort -k1,1n`). Despite the fresh rapt: curl RED; curl + SAPISIDHASH Authorization + Origin/Referer +
  Chrome UA RED; headless chromium with cookies VERIFIED applied (21 visible for takeout.google.com) +
  real-Chrome UA, direct-to-URL navigation: RED (accounts.google.com) — the download is bound to the
  real browser environment beyond cookies/headers. **Owner flow (D3d):** open
  `<staging>/download-all.html` in the logged-in browser, point the browser's download dir at
  `<staging>/zips`, click the 23 links top-to-bottom TODAY (rapt window). `scripts/takeout-browser-rename.sh`
  (committed; dry-run default, `--apply`, exact-size verified; fixture-tested ×3 legs) folds Google-named
  files into `part-NN.zip`; the `takeout-g1-rename` systemd --user loop applies it every 5 min, exits at
  23/23 → G1 green → `takeout-verify.sh` (G2). `takeout-g1-watch` STOPPED 17:44 (superseded).

Gate G1: 23/23 parts present, every size within band, SHA256SUMS complete. Re-run resumes; do NOT
re-fetch completed parts. If a link exhausts its download count: request a NEW export (same selection)
— there is no other recovery; the clock restarts, which is why download starts immediately after handoff.

### Phase 2 — completeness verification

```bash
bash scripts/takeout-verify.sh /mnt/pool/archive/google-takeout/racedriver8k-2026-11-10
```

Gate G2 (ALL must pass before ANY deletion anywhere):
- every zip `unzip -t` clean (CRC over all 880 GB);
- product coverage matrix: all 39 expected-present products found in the zip listings (fuzzy name match); 29 expected-absent recorded; extras WARN;
- `inventory.tsv` per product: file count + bytes (the numbers every later gate reconciles against);
- `verification-report.md` written into staging.

### Phase 3 — Photos → Immich

```bash
# dry-run first (counts vs inventory), then real (days of upload + ML queue):
bash scripts/takeout-ingest-photos.sh <staging> --dry-run
bash scripts/takeout-ingest-photos.sh <staging>
```

Needs: owner-created Immich API key (Account Settings → API Keys; scope asset.read+asset.upload is NOT
enough for immich-go album creation — create a FULL-access key for the migration, delete it after) at
`<staging>/immich-api-key` 0600. Gate G3: immich-go exit 0; uploaded-count + duplicate-count +
error-count == expected media count from `inventory.tsv` (Photos product); albums present in Immich;
`--on-errors continue` NEVER used silently — the wrapper stops on first error by default.

### Phase 4 — Drive → OpenCloud (Takeout path, D1 = B)

Extract the Drive zips to `<staging>/extracted/` → owner creates an OpenCloud app
password (web UI → Devices & apps) → `rclone copy` extract → WebDAV (`cloud.home.lan`,
vendor=owncloud) → `rclone check` clean. Known fidelity losses on record (mtimes,
shared-with-me — see Decisions). The rclone live-mirror fidelity upgrade is the queued
ROADMAP item and can run ANY TIME before the account is deleted (it does not gate this
pipeline).
Gate G4: `rclone check` zero diffs; file count == inventory Drive row.

### Phase 5 — Drive docs → Paperless (+ images → Immich)

`services.drive-paperless` sources point at the canonical Drive tree (the D1-B extract),
`ingestImages` per owner preference; deploy; watch the hourly batches drain (200/run → days at scale);
journal + `last_success` + backup-coordination row green. Gate G5: journal upload-count converges to
inventory doc-type count; zero `failed.log` entries.

### Phase 6 — small products

Contacts/Calendar/Keep/Mail/etc. stay in `<staging>/extracted/` (or zips) — verified by G2, consumed by
the mesh proposal later. No service ingestion (deliberate: contacts/calendar owner = D1-mesh decision).

### Phase 7 — close-out and account retirement

- Reconcile every gate count against `inventory.tsv`; spot-check 10 random assets in Immich UI (dates, album, location), 5 docs in Paperless (OCR content), 5 files in OpenCloud (versions/xattrs sane).
- Soak 7 days (services re-index, nothing rots), THEN the owner's account-retirement checklist: Google-side final re-export diff (optional), Workspace transfers off, recovery email/phone detached LAST, then deletion. The account is NOT deleted by anything in this pipeline.
- Paperwork: verification report → `docs/status/`, CHANGELOG, data-ownership inventory update (Drive/Photos rows flip from Google-canonical to self-hosted), plan tombstone `done`, TODO rows ticked.

## Security rules (binding)

- `urls.txt`/`cookies.txt`/`immich-api-key`/app passwords: 0600, live ONLY inside the 0700 staging root, never in the repo, never on a command line, never in chat. Shred cookies + API key when their phase is green (`truncate -s 0` + `trash`, or `sops` if made permanent).
- The staging tree contains Mail + My Activity + full PII: never web-served, never copied off the pool, `chmod -R go-rwx` enforced by the scripts.
- Nothing in this pipeline ever writes a secret value into a commit, log line, or journal.

## Follow-ups harvested

See TODO_LIST queue rows sourced to this plan (staging handoff, download supervision, per-phase gates,
data-ownership inventory flip). rclone resolution note: no system-wide rclone binary — Phase 4 resolves
it via the google-sync module's own package or `nix shell nixpkgs#rclone` (pinned by the flake lock at
run time).
