# Full status report — Takeout fleet + Immich key posture

**2026-11-13 14:25 CET** · HEAD `472b84e4a` (tree clean; this turn's three files
were swept by the auto-commit daemon) · host `evo-x2`

Scope of this report: everything done this session (Google account retirement,
account 1 of N + `lars@helpless.ai` backup), the live numbers, every gate with
its true state, and the **unfinished** Immich-API-key rework from the final
turn. It deliberately separates *verified* from *written but unproven*.

---

## 0. What the owner asked, and what exists

| Ask | State |
| --- | --- |
| Get `racedriver8k`'s 880 GB / 23-part Takeout out of Google | **0/23 downloaded.** Owner-side browser click is the only path (re-auth wall proven). Not data loss: the account stays alive. |
| Back up `lars@helpless.ai` into self-hosted services | **Partial:** 7 parts / 22 GB downloaded and CRC-clean; Drive extracted + indexed; **nothing imported yet** (Photos→Immich, Drive→OpenCloud, docs→Paperless all blocked). |
| Plan superb imports + dedup across ~3 TB | **Plan exists, tooling exists, first real run done.** No import has happened. |
| 2-monthly incremental semi-manual export/backup rhythm | Planned (fleet plan §5), not yet exercised. |
| Extract-first; deletion not for a long time | Honored: deletion gate is `[watch]`, extraction is the active objective. |

**Nothing has been ingested into Immich, OpenCloud, or Paperless. Nothing has
been deleted anywhere. The raw zips are the only complete copy of the
helpless.ai export on this box.**

---

## 1. Live numbers (verified this turn)

```
/mnt/pool        15T total   3.9T used   11T free   27%
takeout archive  24 GB
helpless.ai zips 7 parts, 22 GB, unzip -t clean
ledger           1,300 data rows + header (sha256)
```

Destinations listening: Immich `127.0.0.1:2283`, OpenCloud `127.0.0.1:9500`
(+NATS 9233), Paperless `127.0.0.1:2892`.

---

## 2. Gates G0–G7 — true state

| Gate | What it means | State |
| --- | --- | --- |
| **G0** | account registry | Done: `scripts/takeout-accounts.tsv` (racedriver8k retire/baseline, lars@helpless.ai keep/2 cycles). |
| **G1** | complete zip set per account | `racedriver8k` **0/23**; `lars@helpless.ai` **7 parts present, completeness UNPROVEN** (no exports-page save = no authoritative part list). |
| **G2** | integrity + inventory | racedriver8k: n/a. helpless.ai: CRC clean, but `takeout-verify.sh` **must not be run as-is** — it seeds the embedded racedriver8k product manifest (trap still live, `scripts/takeout-verify.sh:151-156`). |
| **G2.5** | dedup/ledger | **Green for helpless.ai Drive**: 1,300 rows indexed; `plan` → 1,300 NEW (243 photos / 1,057 other); `balance` → **BALANCED** (1,528,919,192 B); `report` → 80 duplicate-content sets, 91,235,063 redundant bytes inside Drive. |
| **G3** | Photos → Immich | **Blocked**: needs a key (see §4) + a real extraction of `Takeout/Google Photos`. Untested against Immich. |
| **G4** | Drive → OpenCloud | **Blocked**: no OpenCloud app password, `rclone` not on PATH. Extraction done (1,300 files). |
| **G5** | docs → Paperless | **Blocked**: not started; needs the `other.txt` rating pass first. |
| **G6** | reconciliation after ingest | Tooling green (`balance`), nothing to reconcile yet. |
| **G7** | capacity | Rule recorded: `free ≥ 1.2×extract + 500 GB` before any bulk extract. 11 TB free today. |

---

## 3. Tooling built and tested (committed)

- `scripts/takeout-dedup.sh` — `index | plan | balance | report | --selftest`
  (16 selftest legs PASS, shellcheck-clean). Append-only TSV ledger, per
  `(account, cycle)` index skip, cross-cycle + cross-account duplicate
  detection, balance excludes zip directory entries and exits non-zero on
  MISMATCH/EXTRACT-ONLY.
- `scripts/takeout-intake.sh` — glob intake of a saved exports page into
  `<staging>/links.html` (0600, idempotent, `--dry-run`), 7 selftest legs.
- `scripts/takeout-browser-rename.sh` — browser-named → `part-NN.zip` folder
  with exact-size check **plus `unzip -t` CRC**, `.crc-failed-<name>` marker.
- `scripts/takeout-download.sh` — `init --no-manifest` (no longer seeds the
  racedriver8k `PARTS_MANIFEST` into another account's staging).
- `scripts/takeout-accounts.tsv` — fleet registry.
- Ledger measured throughput: 1.5 GB in 13.9 s (~107 MB/s sha256) ⇒ ~85 min for
  racedriver8k's 543 GB Drive, ~10 h for 3.9 TB.

Docs: fleet plan (`docs/planning/2026-11-13_multi-account-takeout-fleet-plan.md`,
incl. G2.5/G6, incrementality semantics, capacity rule, deletion demoted to
"future gate"), retirement-pipeline account-#2 note, two status reports
(11:35, 12:00), TODO queue + `docs/todo/services.md` synced.

---

## 4. The Immich API key — the question asked, the honest answer

**The objection is correct.** `<staging>/immich-api-key` is a bad place for a
key: it is a data directory on the pool (backed up, copied by hand, easy to
forget), and the fleet plan itself says "never in a data dir". The repo already
has the right mechanism, twice: `discordsync-immich-key-provision` and
`media-atlas-key-provision` mint keys **directly into Immich's `api_key`
table** through peer-auth postgres (`runuser -u postgres` — a privilege root
already holds; Immich is OIDC-only, so there is no API bootstrap) and render a
0400 file. **The owner never handles the key at all.**

### What I committed this turn (`472b84e4a`)

1. `lib/immich-api-key-provision.nix` (new, 151 lines) — the canonical
   converger extracted from that pattern: schema guard (`api_key.key` is
   `bytea` = raw sha256), file-first reconcile (converged / re-insert after DB
   restore / mint), 0400 render, `env` or `plain` file format, per-key
   `restartUnits` (fresh mint only), `|| fail=1` per key so one bad key does
   not mask the others.
2. `services.immich.apiKeys.<name>` option in
   `modules/nixos/services/immich.nix` — `permissions`, `keyFile`, `owner`,
   `group`, `url`, `restartUnits`, with a documented rotation contract.
3. `lib/default.nix` exports `mkImmichApiKeyProvision`.

### What is NOT done — the feature is dead code right now

- **No systemd unit and no timer are generated** from the option.
- **No consumer is declared** (`immich.apiKeys.takeout-import` does not exist).
- `scripts/takeout-ingest-photos.sh` still requires
  `<staging>/immich-api-key` (`:39`) — the bad location still stands.
- No `scripts/deploy.sh` converger entry (the `deploy-restart-audit` eval gate
  will fail the moment a unit exists).
- No docs/TODO/CHANGELOG update; no eval, no shellcheck, no build of the new
  script; the helper has never been executed.
- No decision recorded on the takeout key's scope. The intended scope (from
  immich-go's own docs) is `asset.read/statistics/update/upload/copy/download`,
  `album.create/read`, `albumAsset.create`, `server.about`, `stack.create`,
  `tag.asset`, `tag.create`, `user.read` plus `job.create/job.read`
  (admin-linked, for pausing jobs) — deliberately **without** `asset.delete`.

Intended end state: `immich.apiKeys.takeout-import` renders
`/var/lib/immich-api-keys/takeout-import.env` (`IMMICH_URL`,
`IMMICH_API_KEY`, 0400 `lars:users`); the ingest script reads that env file and
takes `IMMICH_API_KEY` from the environment as an override. The migration key
is then revocable by deleting one file and restarting one unit.

---

## 5. What I got wrong

1. **I left the key rework half-finished and said nothing.** Options + helper
   landed; unit, declaration, script change, deploy wiring, docs and any
   verification did not. That is worse than not starting: it reads as done.
2. Earlier this session the same class appeared in the plan: no offsite copy,
   wrong "universal source" assumption, no reconciliation gate — all three were
   caught by the forced self-audit, but only after the first plan shipped.
3. `takeout-verify.sh` still carries the racedriver8k manifest trap; I recorded
   it as a `[ready]` row instead of fixing it, and it now gates G2 for the
   account that actually has data.
4. The extraction loop hides `unzip` rc 11 behind `|| true`, which is a silent
   "zero members matched" and can mask real I/O failures.
5. Two bespoke copies of the key converger (discordsync, media-atlas) still
   exist next to the new canonical one — three implementations, one contract.

---

## 6. Blocked, and on whom

| Blocker | Owner action | Why it cannot be agent-side |
| --- | --- | --- |
| racedriver8k 23 parts | Switch browser to `racedriver8k`, set download dir, open `<staging>/download-all.html`, click 23 links | Google's re-auth wall rejects every non-browser client (proven) |
| helpless.ai part list | Save the exports page (Ctrl+S) while logged in | Page is behind the same wall |
| Immich key (G3) | **Nothing** — after §4 is finished, the converger mints it | Only the module work is missing |
| OpenCloud app password (G4) | Create it in OpenCloud, hand it over via sops or a 0600 file | Account action |
| Paperless (G5) | Decide doc selection from `other.txt` | Requires judgment |
| Accounts 3–N | Name them + mode (retire/keep) + cadence | Unknown to me |

---

## 7. Exact next actions, in order

1. Finish §4: generate `immich-api-key-provision.service` (+ daily timer) from
   `services.immich.apiKeys`, declare `takeout-import`, point
   `takeout-ingest-photos.sh` at the env file, add the unit to
   `scripts/deploy.sh`, then `nix eval` the unit and build the wrapper
   (shellcheck) before claiming anything.
2. Fix `takeout-verify.sh`: never inherit the racedriver8k product manifest;
   derive products from the zips (provisional, loud WARN) or from the saved
   page. Re-run its selftest.
3. Wire `takeout-dedup.sh --selftest`, `takeout-intake.sh --selftest` and a CRC
   fixture into `flake/parts/checks/selftests.nix`.
4. Normalize ledger relpaths (strip `Takeout/`) before a second cycle exists.
5. `takeout-extract.sh` (member-scoped, rc-11-aware, capacity-gated) + `index`
   progress + `plan` byte totals + `balance --summary`.
6. Close the three owner answers (accounts + modes; ingest path for
   helpless.ai; whether the 7-part download is complete).

---

## 8. Evidence pointers

- Fleet plan: `docs/planning/2026-11-13_multi-account-takeout-fleet-plan.md`
- Prior reports: `docs/status/2026-11-13_11-35_…`, `…_12-00_…`
- Ledger: `/mnt/pool/archive/google-takeout/.ledger/ledger.tsv` (0600)
- helpless.ai staging: `/mnt/pool/archive/google-takeout/lars-helpless-ai-2026-11-13/`
  (`dedup/SUMMARY.txt`, `products-from-zips.tsv` = review-only draft)
- racedriver8k staging: `/mnt/pool/archive/google-takeout/racedriver8k-2026-11-10/`
  (`zips/` empty, rename loop log last cycle 11:59:35)
- This turn's commit: `472b84e4a` (3 files, 231 insertions — daemon sweep)
