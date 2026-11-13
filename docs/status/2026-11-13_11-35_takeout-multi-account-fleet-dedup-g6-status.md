# Takeout Multi-Account Fleet — Dedup Ledger, G6 Reconciliation, Deletion-Readiness Audit

**Date:** 2026-11-13 11:35 CET (Friday) · **Host:** evo-x2 · **Branch:** master
**Session scope:** account #2 staging + review, multi-account import/dedup planning,
"2-monthly incremental semi-manual" design, tooling implementation, and a critical
re-audit of my own first plan.

**Commits this session:** `3dbeaa85f` (doc rows + baseline cross-link), `41a2e4577`
(library rows), plus three auto-commit-daemon sweeps carrying my work with heuristic
messages: `e5456f359` (intake + rename CRC + downloader flag), `509d8775f` (fleet plan
revision + dedup balance + queue rows), `4883dd8a9` (first fleet plan + registry + dedup
core; this one also carried a **foreign session's `flake.lock`**, so no amend).

**Live state at report time:** pool `/mnt/pool` 15 TB total, **11 TB free** (3.9 TB used).
`racedriver8k` G1 = **0/23** (rename loop alive, last cycle 10:24:34; export expires
**2026-11-18 03:13**). `lars@helpless.ai` = **7 parts / 22 GB on disk**, 7/7 `unzip -t`
clean, expected part list still unknown. Global dedup ledger created and empty (first real
index happens at G4). Tree clean for all takeout paths.

---

## a) FULLY DONE

### a1. `lars@helpless.ai` staging on the pool (created 10:26)

`/mnt/pool/archive/google-takeout/lars-helpless-ai-2026-11-13/` — 0700 `lars:users` with
`zips/ logs/ extracted/`, header-only `parts.tsv`/`urls.txt` (0600), `OWNER-STEPS.md`
(owner click-path, updated twice to match reality), `products-from-zips.tsv` (review
artifact, explicitly **not** the authoritative manifest).

Note: the parent `google-takeout/` is root:root 755, so staging creation needs the one-time
`sudo install -d -o lars -g users …` (this session used working sudo; the 2026-11-05
"sudo is dead" rule is superseded for yolo sessions — probed `sudo -n true` rc=0 first).

### a2. Live review of the downloaded export (the requested "view and review")

7 parts, 22 GB compressed, all `unzip -t` CRC-clean, sizes stable, no in-flight temp files:

| Product | Files | Uncompressed |
| --- | --- | --- |
| Google Photos | 5,282 | 17.88 GB |
| Mail | 1 (mbox) | 7.44 GB |
| Drive | 1,300 | 1.53 GB |
| Access Log Activity | 2 | 217 MB |
| NotebookLM | 198 | 215 MB |
| My Activity | 22 | 66 MB |
| YouTube and YouTube Music | 13 | 11 MB |
| Voice | 507 | 7.9 MB |
| Calendar / Chrome / Contacts / Keep / Wallet / Profile / Play / Chat / Meet / Earth / Maps / Gemini / +small | ~130 | < 1 MB each |

Export groups: `takeout-20261110T224436Z-001.zip` (archive_browser.html only) and
`takeout-20261110T224438Z-{1..6}-00N.zip`. **Completeness is unproven** — Google's export
page is the only authoritative part list (see b1).

### a3. Account registry — `scripts/takeout-accounts.tsv`

Single machine-readable source: account, mode (`retire|keep`), staging root, cadence,
status, retention, notes. Rows: `racedriver8k` (retire/baseline, 880 GB, deadline),
`lars@helpless.ai` (keep/2 cycles, 22 GB on disk), plus a commented template row.

### a4. Content-identity ledger + planner — `scripts/takeout-dedup.sh`

Commands: `index`, `plan`, `balance`, `report`, `--selftest`. Global ledger
`/mnt/pool/archive/google-takeout/.ledger/ledger.tsv` (dir 0700, file 0600, header written;
currently 0 rows). Semantics implemented and tested:

- `index` — hashes every regular file of an extract (b3sum preferred, sha256 fallback),
  append-only merge-dedup, skip-if-already-indexed (`--force` to redo), tab-path guard.
- `plan` — NEW / UNCHANGED / vanished-since-prev-cycle / cross-cycle (cross-account)
  content dups; compares `(account, relpath)` against the latest PRIOR cycle; re-runs are
  idempotent (outputs truncated, current-cycle rows excluded from the comparison);
  destination buckets `photos.txt` / `other.txt` + `new-files.tsv`.
- `balance` (G6) — per product, zips (ground truth, directory entries excluded) vs indexed
  extract: files + uncompressed bytes; `COLD (not extracted)` products pass by design;
  `MISMATCH` and `EXTRACT-ONLY` exit non-zero.
- `report` — per account/cycle files+bytes, duplicate-content sets, redundant bytes.

Verification: **15-leg selftest PASS**, shellcheck clean, plus a real-data smoke run on the
smallest real part (15 real Takeout files indexed+planned) and a real `balance` run against
the 22 GB staging (all products COLD, rc 0, as expected).

### a5. Glob intake — `scripts/takeout-intake.sh`

Registry-aware: installs the newest HTML that actually carries Takeout download links from
`~/Downloads` (or `--from`) as `<staging>/links.html` (0600), idempotent, `--dry-run`.
Closes the 2026-11-11 magic-filename failure (`links.html` vs the browser's
"Google Takeout.html"). **7-leg selftest PASS**, shellcheck clean.

### a6. Fold-path robustness — `scripts/takeout-browser-rename.sh`

Size check promoted to **size + CRC** (`unzip -t`) before folding a part to `part-NN.zip`,
with a `.crc-failed-<name>` marker so a corrupt 50 GB part is not re-read every 5-minute
cycle. Verified safe for the live loop: the loop re-invokes the repo script each cycle, so
the edit went live without restarting anything.

### a7. Manifest-decoupling footgun removed — `scripts/takeout-download.sh init --no-manifest`

`init` no longer seeds racedriver8k's 23-part embedded manifest into a new account's
`parts.tsv` (it would have poisoned account #3+). Header now carries the filename column.

### a8. Fleet plan — `docs/planning/2026-11-13_multi-account-takeout-fleet-plan.md`

Gates G0–G7 with new **G2.5** (dedup index/plan) and **G6** (reconciliation); two modes;
source matrix; incrementality semantics; retention/capacity rules; §4b deletion readiness;
§5 the "incremental semi-manual export and backup" rhythm; §6 runbook; §7 decisions.
Baseline plan updated with the account-#2 note and a fleet cross-link.

### a9. Own-plan re-audit (the "is this the BEST plan?" pass)

Found and fixed three real holes: (1) **no offsite copy** before account deletion (§4b,
with the live facts: btrbk mirrors onto the same pool; offsite Borg deployed but dormant);
(2) **Takeout as universal source** was wrong for keep accounts → source matrix
(google-sync live mirror for Drive, IMAP/InboxClean for Mail, Takeout for Photos + small
products); (3) **no reconciliation gate** → G6 `balance`. Also fixed the runbook's
extraction line (it extracted all products, contradicting the cold-product rule), tightened
retention (trash cycle N only after N+1's G6), and documented scale-out hooks.

### a10. Queue + library synced (both surfaces, every pass)

Rows: account-#2 premise correction (export existed; 7 parts/22 GB clean), fleet account
inventory, deletion gate (§4b), keep-mode source matrix, glob-intake status, plus the
earlier G7 close-out row amended with the deletion gate. Committed.

---

## b) PARTIALLY DONE

1. **helpless.ai G1 (7 parts on disk, completeness unknown).** No exports-page save → no
   `parts.tsv`/`products.tsv` → no fold, no G2. Owner step is ~2 minutes; everything after
   is automated. `products-from-zips.tsv` is a draft only — deriving the expected list from
   the very zips under test is self-fulfilling.
2. **Fleet plan decisions (§7).** Eight items open, all owner-gated except two I can now
   prepare further (see f).
3. **Deletion readiness (§4b).** Gate documented and queued; offsite Borg is still dormant
   (`services.offsite-borg.enable = false`, system-796, owner-held StorageBox inputs), so
   **no retire-mode account may be deleted yet**.
4. **Keep-mode source matrix.** Recommended and documented; needs owner confirmation, and
   the `google-sync` OAuth go-live (already a `[blocked:user]` row) is its prerequisite.
5. **Ledger.** Created, selftested, real-zip smoke-tested — but **0 production rows**; its
   first real run is the racedriver8k 543 GB Drive extract at G4. Unknown: throughput at
   that scale (sha256 fallback ≈ 500 MB/s ⇒ ~20 min per pass; b3sum would be ~3-5× faster
   and is **not installed** on this host).
6. **Intake.** On-demand done; automatic trigger (systemd user path unit) not built —
   deliberately left as a decision, not a requirement.
7. **`products.tsv` for account #2.** Still missing (see d3 — the verify script would seed
   a foreign product list).
8. **Runbook.** Corrected and now self-consistent, but **not executed end-to-end** for any
   account yet (no G2+ has ever run in this session).

---

## c) NOT STARTED

1. racedriver8k: owner's 23 browser clicks (0/23), G2 (CRC over 880 GB), G3–G6, G7 soak.
2. helpless.ai: page save → `takeout-intake` → `ingest-html` → G2 → G2.5 → G3–G6.
3. Photos pre-filter scale-out (`index --from-zips`, trigger > ~100 GB Photos).
4. Mail `Message-ID` dedup (only needed if keep-mode Mail stays Takeout; source matrix
   would remove the need).
5. `duperemove` scheduling for cross-account physical dedup.
6. Offsite Borg go-live + restore drill → unblocks §4b.
7. Insurance export for racedriver8k (parallel 7-day clock) — decision + execution.
8. Registry rows for accounts #3..N (blocked on names/modes).
9. CHANGELOG entry for this session's tooling.
10. Selftest wiring into `flake/parts/checks/selftests.nix` (today: run by hand only).
11. Generic rename-loop wrapper in `scripts/` (the live one is a hardcoded `~/.cache` copy).
12. End-to-end rehearsal of the keep-mode cycle on a fixture staging root.

---

## d) TOTALLY FUCKED UP (own goals, in order of discovery)

1. **`mkdir` under a root-owned parent without probing rights first** → three permission-
   denied lines on the first staging attempt. I had read the parent's ownership minutes
   earlier and still typed plain `mkdir`; fixed by probing `sudo -n true` and using
   `sudo install`. Cost: one wasted call, zero damage.
2. **First dedup script write shipped dead code** — a placeholder `awk` bucket block and a
   `trap … RETURN` that could fire early. Caught by my own immediate re-read/rewrite before
   any run; no user impact, but it was sloppy first-draft hygiene.
3. **Three genuine bugs in the first dedup implementation**, all caught by my own selftest:
   `plan` appended instead of truncating (re-run duplicated the file list), `known_hash` was
   only populated for the same account (cross-account duplicate detection returned 0), and
   the vanished-count expectation was wrong (I forgot `d.bin` had also vanished). Fixed;
   the selftest exists precisely because hand-checking missed them.
4. **`balance` counted zip directory entries as files** → false MISMATCH. Caught by the
   selftest leg I wrote; fixed by excluding trailing-slash entries (also corrected the
   reported inventory: Drive 1,305 → 1,300 files).
5. **Intake selftest ran `"$0"` on a non-executable file** → `Permission denied`. Fixed by
   `chmod +x` plus `bash "$0"` in the selftest; the first intake file also had a mangled
   `main()` block that I replaced wholesale.
6. **Typed `rg -rn` again** (third strike on this host, per the hook's own message) even
   though the rule is in AGENTS.md. Blocked by the hook; re-ran as `rg -n`. No damage.
7. **OWNER-STEPS v1 asserted the export still had to be requested** while 7 parts were
   already downloaded. Live review corrected it; also my earlier browser-download guidance
   to you was written against a stale premise.
8. **Fleet-plan runbook v1 extracted every product** (`unzip zips/*.zip`) — directly
   contradicting the anti-15× rule and the capacity model (would have extracted the 7.4 GB
   Mail mbox plus all cold products). Self-caught in the audit; replaced with a
   member-scoped `Takeout/Drive/*` extraction.
9. **Latent trap noticed while reading the verify script but NOT acted on:** it calls
   `write_products_tsv`, which seeds `products.tsv` from the **embedded racedriver8k
   product manifest** whenever the file is absent (line 151-156). Account #2's G2 would
   therefore compare its zips against a foreign product list and **fail spuriously** (or
   worse, "pass" the wrong coverage). This is the single most important unfinished
   obligation from this session — queued as the top follow-up.
10. **Three waves of my work were swept into heuristic-message commit-daemon commits.** I
    did not rewrite them (shared tree, daemon races, one sweep also carried a foreign
    `flake.lock`) — accepted, with only the final commit carrying a proper message. The
    history is honest but the fleet-plan change is poorly discoverable by message.

---

## e) WHAT WE SHOULD IMPROVE

1. **Fix the verify-manifest trap before any G2.** `takeout-verify.sh` must never seed a
   foreign product list: add `--products-from-zips` (provisional, loudly labelled) and/or
   derive `products.tsv` from the saved export page; make absence of `products.tsv` an
   explicit decision, not an implicit racedriver8k inheritance.
2. **Put these selftests in CI.** 15 + 7 legs caught four real bugs in one afternoon; they
   currently run only when an agent remembers. Wire both into `checks/selftests.nix` and add
   a CRC fixture for the rename script.
3. **Install/provision `b3sum`.** At 3.9 TB the hash pass is hours with sha256; b3sum is the
   documented fast path but absent from PATH. Add it to the repo toolset or make the script
   resolve it through `nix shell` once (not per file).
4. **Commit smaller and immediately.** Three daemon sweeps in ~20 minutes cost the plan
   revision a meaningful message. Land each file group the moment it is verified.
5. **Intake must prove the page belongs to the requested account** (the export page carries
   the account email) before installing `links.html` — a wrong-account save currently
   installs silently and would poison `parts.tsv` with foreign counts.
6. **Promote the rename-loop wrapper into `scripts/`.** The live loop is a hardcoded
   `~/.cache/takeout-probe/rename-loop.sh` pinned to racedriver8k; account #2+ has nothing.
7. **Single-source the per-account manifests.** Embedded racedriver8k data now lives in
   three scripts (downloader parts, verify products, watcher's exactly-23 rule). The fleet
   plan needs manifest-less scripts + per-staging data files.
8. **Encode the capacity rule.** `free ≥ 1.2×extract + 500 GB` is prose; make it a
   `balance --preflight` or a CLI check so nobody extracts into a nearly-full pool.
9. **State maintenance discipline for `OWNER-STEPS.md`.** It went stale in 20 minutes; every
   staging-state change should update it in the same pass.
10. **Document that the ledger is itself single-site** (on the pool, not backed up) and
    either accept re-derivability or include it in the offsite selection.
11. **G2 must be defined as "after products.tsv exists"** in the runbook — the gate order is
    currently implicit.
12. **Keep the plan's honesty hooks**: every future audit pass should re-check §4b (offsite)
    and the source matrix, because both depend on owner decisions that can change.

---

## f) Up to 50 things to get done next

Agent-actionable `[ready]` (harvested into queue + library in this pass, marked ★):

1. ★ Fix `takeout-verify.sh` product seeding (`--products-from-zips` + explicit WARN; never
   inherit racedriver8k's list).
2. ★ Wire `takeout-dedup.sh --selftest`, `takeout-intake.sh --selftest` and a CRC fixture
   for `takeout-browser-rename.sh` into `checks/selftests.nix`.
3. ★ Harden `takeout-intake.sh`: verify the page's account email matches `--account`;
   optional `--ingest` to chain `ingest-html`.
4. ★ Promote a generic rename-loop wrapper (staging root + expected count from `parts.tsv`)
   into `scripts/`, replacing the hardcoded `~/.cache` copy.
5. Provision `b3sum` (repo toolset/devshell) so the 3.9 TB index pass is minutes, not hours.
6. Add `takeout-dedup.sh balance --preflight` (free-space rule encoded) and call it in the
   runbook before extraction.
7. Derive `products.tsv` from the saved export page (or add a `products --from-dom` helper)
   so G2.3 is authoritative for every account.
8. Add `--from-zips` indexing (streaming member hashes) behind the >100 GB Photos trigger.
9. Add a `verify --no-products` mode for provisional runs (loudly labelled) so account #2
   can be CRC-tested before the page save.
10. CHANGELOG entry for the fleet tooling (dedup ledger, intake, balance, CRC fold).
11. Re-derive/refresh `products-from-zips.tsv` after G2 completes (same artifact, labelled).
12. Add `takeout-dedup.sh` unit legs for `report` totals + duplicate bytes (currently only
    smoke-checked).
13. Add a fixture test for `takeout-download.sh init --no-manifest` (empty parts.tsv, no
    seeded rows).
14. Add a `--json` output to `report`/`balance` for future dashboards.
15. Write the account-#3 walkthrough as a fixture-based rehearsal (no real account needed).
16. Document the ledger schema + recovery (delete-and-reindex) in the fleet plan.
17. Add `--skip-products` examples to the runbook (Mail, YouTube).
18. Add a `takeout-intake.sh --list` mode showing candidates without installing.
19. Add a dry-run "cycle diff" report (new/unchanged/vanished counts) to §5 of the plan as a
    standard output for the owner.
20. Persist per-cycle `SUMMARY.txt` into the staging `dedup/` dir (already emitted) and
    reference it from the owner report.
21. Add `duperemove` scheduling as a documented optional post-import step.
22. Add Message-ID extraction for mbox files (decision-gated; small standalone helper).
23. Add a `retain` pruner helper (lists cycle dirs older than N; never deletes without
    `--apply` + trash).
24. Capture `df` before/after each gate into the staging log for the capacity audit trail.
25. Add an `OWNER-STEPS.md` template into the fleet plan so account #3+ starts correct.
26. Add a `takeout-accounts.tsv` validator (unique accounts, absolute paths, mode enum).
27. Add shellcheck + selftest for `takeout-watch.sh` if it stays.
28. Retire or document-fence `takeout-watch.sh` (superseded by intake + browser flow).
29. Add `--cycle` validation (YYYY-MM-DD) to dedup commands (bad cycle strings currently
    sort wrongly).
30. Add a `--account` existence check against the registry in dedup commands.
31. Record hash-algorithm mixing warnings in `report` (blake3 vs sha256 rows).
32. Add a "no ledger rows yet" hint to `balance` (currently prints an empty table).
33. Fix `takeout-download.sh` status sizing for exact-byte parts.tsv rows (verify the
    human-size band parser accepts raw byte counts).
34. Pre-stage account #2's `products.tsv` decision in OWNER-STEPS (page-save note added).
35. Add `takeout-verify.sh --selftest` re-run to this session's evidence set (not re-run
    today).
36. Verify `takeout-verify.sh` selftest still passes after the fleet changes.
37. Add a `takeout-dedup.sh plan --emit-immich-list` (photos-only, structure-preserving).
38. Add size accounting to `plan` SUMMARY (new/unchanged bytes per bucket).
39. Document the OpenCloud versioning rule (same path + changed hash = new version) in the
    plan's G4 row (already noted; add the pass criteria).
40. Add a small `takeout-report.sh` that stitches balance + plan + report into one status
    block for the owner.

Owner-gated / decision-gated (deliberately **not** queued per queue policy):
41. Name accounts #3..N + modes (registry needs real rows).
42. Decide deletion readiness (offsite Borg go-live vs signed single-site acceptance).
43. Confirm keep-mode source matrix (google-sync + IMAP + Takeout-Photos) and its priority.
44. Decide retention window (default 2 cycles).
45. Decide Mail end-state (cold archive vs mail-host mesh).
46. Decide insurance export for racedriver8k.
47. Decide PIM (Contacts/Calendar/Keep) import timing (mesh proposal).
48. Do the shared-with-me eyeball before each retire deletion.
49. Do the racedriver8k 23 clicks (deadline 2026-11-18 03:13).
50. Save the helpless.ai exports page (2 min) so G2 can run.

---

## g) Questions I cannot answer myself (3)

1. **Which Google accounts remain (~3 TB total), and which mode does each get — `retire`
   (one-shot, zips forever, account deleted later) or `keep` (2-monthly cycles, newest 2
   zips)?** The registry, the capacity model and the fleet-wide dedup report all key off
   this; I cannot invent account names or their sizes.
2. **Deletion readiness: do we go live on offsite Borg now (I need the Hetzner StorageBox
   hostname + username and the `ssh-keyscan -p 23` host-key pin), or do you sign a
   single-site risk acceptance so retire close-outs can proceed with everything on one
   chassis?** Until one is recorded, no retire-mode account may be deleted — that is the
   gate I added today.
3. **Do you approve the keep-mode source matrix (Drive via `google-sync` live mirror, Mail
   via IMAP/InboxClean, Takeout only for Photos + small products), and should the
   `google-sync` OAuth go-live be prioritized now?** It removes the full Drive re-download
   per cycle and the mtime loss; if you prefer Takeout-only for every account, the fleet
   plan must budget the transfer and keep the rart-wall owner step for Drive too.

---

## h) Harvest record (repo rule: self-harvest direct follow-ups)

- **Harvested now (queue + `docs/todo/services.md`):** f1–f4 (★) as `[ready]` rows.
- **Already queued earlier this session:** deletion gate (§4b), keep-mode source matrix,
  account inventory, glob-intake status, account-#2 G1 remainder, fleet tooling row.
- **Deliberately not harvested (reason):** f5–f40 are refinements/scale-out hooks — most are
  either gated on the first real G2/G4 run (ledger throughput, zip indexing) or belong in
  the plan as design hooks; f41–f50 are owner/decision-gated and the queue intentionally
  carries only agent-actionable `[ready]` one-liners. They live in this report and the fleet
  plan §7.

**Top risk right now:** racedriver8k's export clock (2026-11-18 03:13) with 0/23 clicks,
followed by the verify-manifest trap (d9) that would corrupt account #2's first G2 result.
