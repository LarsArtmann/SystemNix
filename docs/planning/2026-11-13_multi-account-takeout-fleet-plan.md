# Multi-Account Takeout Fleet — retirement + 2-monthly incremental backup

**Status:** active (2026-11-13). Baseline pipeline + gates:
[2026-11-11 Google Takeout retirement pipeline](./2026-11-11_09-30_google-takeout-retirement-pipeline.md).
Registry: [`scripts/takeout-accounts.tsv`](../../scripts/takeout-accounts.tsv).

## 1. Scope and the two per-account modes

| Account | Mode | Export | State (2026-11-13) |
| --- | --- | --- | --- |
| `racedriver8k` | **retire** | 880 GB / 23 parts, one-shot | owner browser clicks outstanding; expires 2026-11-18 03:13 |
| `lars@helpless.ai` | **keep** (recurring) | 22 GB / 7 parts on disk, `unzip -t` clean | expected part list unknown → owner saves the exports page (parts.tsv/products.tsv), then G2 |
| further accounts | TBD | owner reports ~3 TB total | names + modes must be added to the registry (owner decision §7) |

- **retire** — one full export, verify, ingest into self-hosted services, keep the zips
  **forever** as the immutable raw archive, account deleted by the owner last (the keeper
  is the archive + the services).
- **keep** — the account stays alive; a scheduled export runs **every 2 months**; zips are
  transport, not archive (Google remains the raw copy). Only the newest **N = 2 cycles**
  are retained on the pool; older cycles are trashed after a green import.

## 2. The pipeline — per account, per export/cycle

Same gates as the baseline plan; G2.5 is new and is what makes the fleet scale.

| Gate | What | Command / criterion |
| --- | --- | --- |
| G0 | request / schedule the export | owner in browser (takeout.google.com); retire = export once, keep = "Export every 2 months for 1 year" |
| G1 | download to pool | owner browser only (**rart re-auth wall** — no scripted client ever passes; proven 2026-11-11); browser download dir = `<staging>/zips`; part files land with Google names |
| G2 | completeness + integrity | `bash scripts/takeout-verify.sh <staging>` — parts.tsv sizes, `unzip -t`, product coverage (products.tsv), inventory + SHA256SUMS. NOTHING is ingested or deleted before green |
| **G2.5** | **dedup index + import plan** | `bash scripts/takeout-dedup.sh index --from-extract <staging>/extracted --account <a> --cycle <date>` then `plan …` — emits `new-files.txt`, buckets, unchanged/vanished/dup reports |
| G3 | Photos → Immich | `bash scripts/takeout-ingest-photos.sh <staging>` (immich-go on the zips; server-side checksum dedup makes re-runs and cross-account overlap safe) |
| G4 | Drive tree → OpenCloud | extract zips → rclone WebDAV (vendor=owncloud) using `dedup/new-files.txt` as `--files-from` (cycle 1: the whole tree) |
| G5 | Docs → Paperless | drive-paperless over the extract; byte-identical rejection is server-side |
| G6 | report | per-account verification report into `docs/status/`; ledger `report` for duplicate accounting |
| G7 | retention / close | retire: 7-day soak → data-ownership flip, secrets shred, account deletion stays with the owner. keep: trash cycles older than N after G3–G5 green |

Staging layout per export dir (already the convention): `zips/ logs/ extracted/ dedup/
parts.tsv urls.txt products.tsv OWNER-STEPS.md`. The dedup **ledger is global**:
`/mnt/pool/archive/google-takeout/.ledger/ledger.tsv` (0700 dir, 0600 file).

## 3. What "incremental" actually means

**Google Takeout exports are FULL snapshots — there is no delta option.** Incrementality is
ours, via the content-identity ledger (`scripts/takeout-dedup.sh`, selftested):

- **UNCHANGED** — `(account, relpath)` seen in a previous cycle with the same content hash →
  **skip** (already imported into the services).
- **NEW** — unseen path, or content changed since the latest prior cycle → **import**
  (file structure preserved; changed files become a new version where the destination
  supports it).
- **vanished** — path present in a prior cycle, absent now → **report only, never delete**
  from Immich/OpenCloud/Paperless. A backup never propagates deletes.
- **cross-account duplicate content** — same hash under another account → still imported
  (paths and structure are data), listed in the report so the fleet-wide overlap is known
  and the owner can decide later whether to collapse anything.
- **re-runs are idempotent** — crash-recovery safe; indexing twice is a no-op.

Per-destination dedup:

| Destination | Dedup mechanism | Notes |
| --- | --- | --- |
| Immich | server-side checksum | re-importing cycle N's photos costs transfer, never duplicates; pre-filter with `dedup/photos.txt` when it matters |
| Paperless | byte-identical rejection server-side | ledger pre-filter additionally saves OCR/AI consumption |
| OpenCloud | **none server-side** → ledger-gated | `rclone --files-from dedup/new-files.txt`; same path + changed hash = new version |
| pool archive | zips | retire: forever; keep: newest 2 cycles |

Ledger internals: TSV `ALGO HASH SIZE ACCOUNT CYCLE RELPATH`, append-only, merge-deduped;
hasher prefers `b3sum` (blake3, GB/s), falls back to `sha256sum` — the fast path is
`nix shell nixpkgs#b3sum -c bash scripts/takeout-dedup.sh …`. Indexed coverage = **extracted
products** (the Drive tree). Photos dedup is Immich's; cold products are never extracted, so
they never enter the ledger by design. Future refinement: mbox dedup by `Message-ID`
instead of file hash (each cycle's Mail mbox is a full snapshot).

## 4. Capacity and retention

Live baseline (2026-11-13): pool 15 TB, **11 TB free**; takeout archive currently 22 GB.

- Retire baselines (permanent zips): 880 GB + ~3 TB = **~3.9 TB**.
- Working copies in services: up to ~3.9 TB worst case, growing only as content is actually
  imported (Immich/Paperless/OpenCloud each hold one working copy — baseline plan anti-15×
  rules apply fleet-wide).
- Transient extract: **one account at a time**; ≈ that account's Drive-size portion only
  (cold products are never extracted) — delete after G4+G5 green, before the next account.

**Rule:** before any G4, require `free ≥ extract size × 1.2 + 500 GB`; if not, reclaim
(keep-mode old cycles, `/data/gcs-staging` 24 GB, `/data/docker` residue ~10 GB — all owner
reclaim decisions) instead of gambling on peak. Sequential processing keeps the worst-case
peak (≈10.8 TB with one 3 TB Drive extract) under the 11 TB free only because extracts are
transient and the big account is processed while working copies are still small — verify
`df` at every G4.

## 5. The semi-manual 2-monthly rhythm (keep mode)

Owner does the three things Google makes un-automatable; automation does the rest.

1. **Once per account** (or when a schedule lapses): takeout.google.com → all products →
   **"Export every 2 months for 1 year"** → `.zip` → link via email.
2. **Every ~2 months, when Google's email arrives** (~5–15 min owner time): set the browser
   download dir to the new cycle dir `<staging>-<export-date>/zips`, save the Takeout exports
   page into that dir (Ctrl+S — any filename), click every part download. The "Verify it's
   you" prompt may appear once; completing it is expected.
3. Then: one agent command-chain (runbook §6). The agent ingests the DOM → parts.tsv /
   products.tsv, runs G2, indexes + plans (G2.5), imports only the delta (G3–G5), reports,
   and trashes cycles older than N.

Because G1 is the only owner-critical step, a missed cycle is harmless: Google re-exports on
the next schedule, and the ledger still recognises everything already imported. If an export
expires before download (7 days), request a fresh one — the ledger makes the duplicate work
of re-downloading recognisable at G2.5, not duplicated in the services.

## 6. Runbook (copy-paste)

Retire account, from zero:

```bash
S=/mnt/pool/archive/google-takeout/<account>-<YYYY-MM-DD>
sudo install -d -o lars -g users -m 700 "$S"/{zips,logs,extracted}
bash scripts/takeout-download.sh init "$S"          # only for the racedriver8k template — otherwise seed parts.tsv from the DOM ingest
bash scripts/takeout-verify.sh "$S"                 # G2
unzip -q "$S"/zips/*.zip -d "$S"/extracted          # Drive tree only; never extract cold products
bash scripts/takeout-dedup.sh index --from-extract "$S"/extracted --account <account> --cycle <YYYY-MM-DD>
bash scripts/takeout-dedup.sh plan  --from-extract "$S"/extracted --account <account> --cycle <YYYY-MM-DD>
bash scripts/takeout-ingest-photos.sh "$S"          # G3
# G4: rclone copy "$S"/extracted <opencloud-remote>:… --files-from "$S"/dedup/new-files.txt --dry-run first
# G5: drive-paperless over "$S"/extracted (D4 = ALL docs)
bash scripts/takeout-dedup.sh report
```

Keep account, 2-monthly cycle: identical, plus retention — after G3–G5 green, trash the
cycle dirs older than N (registry `retain` column) with `trash`, never `rm`.

## 7. Open owner decisions

1. **Name the remaining accounts** (~3 TB total) and their modes (retire vs keep) so the
   registry can hold them; per-account Drive size drives the §4 capacity check.
2. **Retention window** for keep accounts — default 2 cycles (4 months of raw zips).
3. **Mail end-state** — cold archive (current plan) vs the mail-host mesh decision; if the
   latter, add Message-ID-based mbox dedup to this plan before the first repeat cycle.
4. **Insurance export** for `racedriver8k` — request a second export now (parallel 7-day
   clock) or only on failure? Its deadline (2026-11-18 03:13) is the fleet's tightest.
5. **PIM import** (Contacts/Calendar/Keep) — pending the 2026-10-29 mesh proposal; until
   decided these are cold-archive only, and each cycle's ICS/vCard snapshots are small.
6. **Shared-with-me eyeball** before each retiring account is deleted (Takeout cannot
   contain files never added to My Drive).
