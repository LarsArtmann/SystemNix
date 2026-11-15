# Takeout arc: verify name-tolerance proven GREEN, extract + G2.5 exact, ingest tool fixed — import deploy-gated

**Session:** 2026-11-14 16:00 → 2026-11-15 ~08:00 CET (continuation of the 12-49 closeout arc). Scope: the resumption briefing's afternoon chain — real G2 on helpless.ai, tick the zip-name row, converger acceptance, G1.1 extract, ingest.

**TL;DR:** the name-tolerance fix was proven on the real staging (G2 GREEN, 7/7 raw-named parts, 45/45 products), the SAME divergence was caught and fixed in a third script (`takeout-ingest-photos.sh` fed immich-go a `part-*.zip` glob that matches nothing on this staging — now consumes verify's declared list, hand-verified 4 legs), the Google Photos extract landed byte-exact (5,282 files / 17,879,323,461 B, reconcile 0 missing 0 extra), and G2.5 index/plan/balance-preflight is PASS — after catching and repairing a self-inflicted vacuous pass (plan artifacts written into the index root, then ledgered by the forced re-index; one trash-cross-volume detour later, the ledger is surgically clean and both extracted products verify OK). The Immich import itself is BLOCKED on the immich-api-key converger, which is mid-saga in a parallel session (StateDirectory → caps → setpriv → CAP_CHOWN; gen-1010 still lacks it) and on the 16-h IO storm that refused every deploy attempt since 13:47 yesterday (gate exit 12 ×2, one mid-eval death).

---

## a) Verify name-tolerance: proven on the real staging

1. The verify work (committed by the daemon as `0bf029c0a`, exactly the 2 intended files, 81 insertions — amend impossible past 5 later commits; content grep-verified `want_pass=9` + new FAIL/WARN messages present). Selftest re-run on the committed tree: **9/9 PASS** + `shellcheck -x` clean.
2. **Real G2 on `/mnt/pool/archive/google-takeout/lars-helpless-ai-2026-11-13`**: GREEN rc=0 (~8 min, 23.6 GB re-read on the pool). G2.1 7/7 parts in band under RAW browser names via parts.tsv's filename column; G2.2 CRC-clean, 7,496 entries into logs/zip-entries.tsv; G2.3 45/45 products covered (self-derived expectation — the accepted WARN posture per the manifest-trap fix; completeness = owner attestation + CRC + product coverage); G2.4 SHA256SUMS 7 entries. `photos-media-count.txt` reconcile base: **2,640 media files** + 2,641 JSON sidecars + 1 other = 5,282 members (the "5,282 media" shorthand in earlier notes overstates media by 2×; Gate G3 reconciles immich-go's uploaded+duplicate counts against 2,640).

## b) Third instance of the divergence class: ingest fixed + verified

`takeout-ingest-photos.sh` fed immich-go `zips/part-*.zip` (line 113) — on the helpless.ai staging that glob matches NOTHING; immich-go would upload an empty set or die on the nullglob. Fix (`bbca90c60`): the zip list now comes from verify's `logs/declared-zips.txt` (name-tolerant, same G2.1 doctrine), with a legacy `part-*.zip` glob fallback, an explicit die for declared-but-missing parts, and a fail-closed die when no zips resolve. Hand-verified with the 04:11 stub-immich-go pattern, 4 legs: (1) raw names fed verbatim (`zips/takeout-20261110T…-001.zip …`), key contract intact (`-api-key TOK`, manifest-fallback URL); (2) legacy fallback globs part-01/02; (3) empty staging dies rc=2; (4) declared-part-missing dies rc=2; happy leg rc=0. `shellcheck -x` + `bash -n` clean. The 3 zip-list legs joined row 456 (TODO_LIST:456 + services.md:127) so the queued CI wiring covers them.

## c) G1.1 extract + G2.5: exact, after catching my own vacuous pass

1. **Deploy gates held through a 16-h storm**: every attempt since 13:47 refused (exit 12) or died; the overnight gen-1008…1010 deploys were parallel sessions' forced/waiter fires (the band-80 takeover report documents them). This session did NOT force (twice-fatal class, owner-unruled) — see §e.
2. **G1.1 extract fired on the idle pool**: per-device util check showed the storm lives on nvme1n1 (86%) + sdc (100%) while the pool (sda) sat at 0% — the runbook's same-device livelock class doesn't apply to a sequential unzip on an idle disk (MemAvailable 21 G). Result: **5,282 files / 17,879,323,461 bytes extracted in 17 min, reconcile EXACT (missing 0, extra 0)**, 6 zips correctly rc-11-skipped (no Photos members).
3. **G2.5 first pass was VACUOUS — caught, not shipped**: `index` without `--force` logged "already indexed — nothing to do" (the prior session's Drive-only rows blocked re-hash), so plan re-emitted the OLD 1,300-file plan and balance passed with Photos sitting in the COLD bucket — the PREFLIGHT: PASS answered "do ledgered products match", not "is the new extract covered" (the assert-WHICH-question rule, caught by reading the numbers: indexed 1.5 GB vs 19.4 GB expected).
4. **The forced re-run then MISMATCHed — self-pollution**: my first plan invocation (no `--out`) had written its 9 output files into `extracted/dedup/` (653,789 B); the forced index ledgered them; balance flagged product `dedup` EXTRACT-ONLY. Repairs: artifacts moved out of the index root to `logs/stray-plan-artifacts-20261115/` (same-volume rename; `trash` cannot cross volumes to the pool — no creatable `.Trash-1000`), and the 9 ledger rows surgically purged (backup `ledger.tsv.bak-20261115-stray`, awk account+cycle+relpath filter, 6,591→6,582 rows, 0 `dedup/` rows after).
5. **Final state — honest PASS**: re-index `--force` 6,591 files hashed (5,291 new rows, 1,300 already known); plan: 6,591 files / 19,408,896,442 B new (Drive+Photos+stray, superseded); balance `--preflight`: **44 products (2 OK = Drive 1,300 + Google Photos, 42 COLD, 0 SKIPPED, 0 MISMATCH), indexed 19,408,242,653 B = Drive+Photos exactly — PREFLIGHT: PASS.**

## d) Queue/docs hygiene (all committed)

- Zip-name row ticked BOTH surfaces (`6e0a28618`: TODO_LIST:457 + services.md:128) with the DONE note (9/9 legs, real G2 evidence); account-2 exports-page row superseded to `[ready]` on both surfaces (attestation + G2 green; remaining = extract→ingest, no owner steps); CHANGELOG entry added (name-tolerance + attestation supersession).
- Row 456 extended with the 3 zip-list legs (`e0d68f168`); fleet registry `takeout-accounts.tsv` helpless.ai row → `g3-photos` with the attestation note (`a2f0eed21`); staging `OWNER-STEPS.md` now reads "No owner steps remain for this account".
- Commit-message evidence: every "dies / green" claim above is a first-hand run from this session.

## e) Blocked: the import, behind the converger + the storm

- The 3-probe acceptance (env file 0400 + `takeout-import (nix-managed)|16` api_key row + ingest preflight) ran against gen-1010: probe 1 FAILED (`/var/lib/immich-api-keys/` absent). Root cause chain, all fixed in-tree by the PARALLEL converger session (standing off — their file was touched at 07:24, their commits `d8b7b4baa`/`8e3b24a84`/`a667d6bdd`/`740a9f3ec`): StateDirectory 226/NAMESPACE (landed gen-1009) → runuser caps → **CAP_CHOWN/CAP_FOWNER for the key-file handoff chown (live journal evidence 02:25: `chown: … Operation not permitted` AFTER the DB row converged DELETE 1 + INSERT 0 1)** — the api_key row is ALREADY in the DB; only the 0400 env file write fails. gen-1010 renders caps WITHOUT CHOWN; the fix awaits the next deploy.
- Postgres read path for probe 2 validated: `sudo -n runuser -u postgres -- psql` works in this (yolo-class) session; current api_key table listed (5 keys, no takeout-import yet).
- The storm: the session-26 monitor365 nextest battery has run ~16 h (222-226 rustc/sccache procs, psi10 95-99 in waves, quiet phases only 57-76 — nightly maintenance stacking). Overnight deploys 19:03 (forced =2), 19:39 (forced =2, io 54/disk 101), 22:12, 00:16 landed gens 1008-1010 through it; this morning 07:35 refused (exit 12), 07:48 died mid-eval. A calm+quiescence watch is armed; if the window opens and no parallel session fires first, the committed tree (ae3075a1d+) deploys and the acceptance + ingest proceed.

## f) Follow-ups (self-harvested — all landed in TODO_LIST + services.md)

1. **plan --out default self-pollution** (§c.4): plan without `--out` writes into the extract root → next index --force ledgeres the artifacts → balance MISMATCH on a phantom product. Default to the staging dedup/ or refuse without --out. QUEUED.
2. **index --force never purges stale same-cycle rows** (§c.4): the sort -u merge keeps rows whose relpath vanished from disk; manual ledger surgery was needed. --force should atomically replace the account+cycle partition. QUEUED.
3. **trash has no pool answer** (§c.4): no `/mnt/pool/.Trash-1000` creatable (parent absent, pool root root-owned) — the trash-not-rm rule dead-ends on the pool; needs a tmpfiles-created XDG trash dir or a documented staging-local convention. QUEUED.
4. **Ingest blocked on converger deploy** (§e): [blocked:deploy] row; resume = 3-probe acceptance → ingest --dry-run → reconcile vs 2,640 media → real import → 3-album spot check. QUEUED.
5. Push + CI green on the tip (§f9 of the 12-49 report still open from this lineage) — executes at session close.

## g) Open questions for the owner (unchanged)

None new. The ledger-schema and account-#2 questions from the 12-49 report remain the only owner gates, neither blocking this import.
