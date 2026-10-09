# Window Closeout — reap-list single-sourcing lineage + two fix tickets (2026-10-01 00:46 → 2026-10-02 ~09:00, task queue)

**Date:** 2026-10-03 01:15 CEST
**Window:** 6 dispatched tasks (4 work items + 2 reviewer-fix tickets); heavy re-fire tail on two of them.
**Sources read:** all 6 window closeout reports; window commits `51d990a6`, `bba88c9e`, `8187b1c1`, `5844537b`, `ca60b35b`, `0ddc0a9e`, `0fdbf2d7`; TODO_LIST.md; docs/todo/storage.md + pipeline.md; CHANGELOG.md; tq facts journal.

---

## a) FULLY DONE (verified)

1. **Env-less cache reap inventories single-sourced** (`0fdbf2d7`, task 000001a0f466950f…): `scripts/lib/buildcache-reap-names.sh` is the canonical list (7 cache dirs + 2 home-relative dirs); `lib/buildcache-cache-names.nix` parses it at eval (throws on missing/malformed); all four reap loops (deploy.sh pre-switch, buildcache-usb-recovery step 2.5, home.nix activation) consume it. The home.nix activation reap widened 3 → 9 paths — a real drift class closed, not just centralized. Verified by the 00-46 report's functional probes (rendered recovery script + HM activate script, `nix flake check --no-build --all-systems` green).
2. **Follow-up harvest landed** (`51d990a6`): the 00-46 report's §f.1–3 (parity assertion, das-check convergence, stale-comment sweep) were queued at authoring time — and all three subsequently SHIPPED:
   - **Parity assertion** — home.nix HM `assertions` fail eval when a buildcache `mkOutOfStoreSymlink` lacks a reap-names entry; the probe found a REAL gap (`.local/share/pnpm/store` missing from `BUILDCACHE_REAP_HOME_DIRS`) and fixed it (TODO_LIST.md:27 `[x]`).
   - **das-link-recovery-check convergence** (`8187b1c1` + follow-ons): the check sources the canonical lib (fail-loud), derives `CACHE_SYMLINKS` (reap cache-dirs minus the new fallback-only split) and `FALLBACK_CACHE_DIRS`; grew from a drifted 4-entry subset to all 7 HM symlinks; drive-by fix for the `[5]` findmnt autofs-row `set -e` kill (TODO_LIST.md:37 `[x]`).
   - **"kept in sync" phrase sweep** — verified clean twice independently (07-16, 07-40 reports); zero live occurrences, zero private reap-name copies (TODO_LIST.md:38 `[x]`).
3. **KNOWN_CACHE_ENTRIES reconciled with `buildcacheDirs`** (task 000001a0f97e2c06…, landed at re-fire 1, 2026-10-02): known list extended to 18 entries; ~20M of rebuildable debris trashed; drive-by fix stopped `check_mount` false-flagging healthy multi-member btrfs mounts as ZOMBIE; live `[6]` flags exactly `alt-nix` + `scratch` (both owner-gated) (TODO_LIST.md:28 `[x]`).
4. **Fix ticket 000001a0f46b28e2… (reviewer finding on the Phase-2 plan doc)** (`bba88c9e`): the empty `Status (2026-09-30)` column in the F-step table removed; minimal-change contract held; verified in the 01-21 report.
5. **Fix ticket 000001a0fada… — finding closed as already-applied, 9+ times over**: the 07-16 report's false "00-46 names NO sites" claim was corrected (`4eb7fc12`/`b26c11b7` era); every re-fire re-verified via the fix-ticket disposition protocol (`git cat-file -e 5844537b` → anchor-text grep on the current tree → no-op). The final re-fire-9 report's protocol execution is itself a reusable precedent.
6. **Queue + library hygiene:** every window closeout self-harvested its §f follow-ups onto both surfaces (queue + domain library); the re-fire-5 and re-fire-7 §f sweeps caught and repaired three real harvest gaps (stamp compaction, gitleaks invocation pin, adversarial §f cross-check, stale fish-guard .backup).

## b) PARTIALLY DONE

1. **The re-fire loops never retired.** Task 000001a0f97e2c06… was dispatched **10 times** after completion; fix ticket 000001a0fada… **9+ times**. Each clean fire appended verification rows to already-`[x]` queue surfaces — TODO_LIST.md:28 is now a single ~15 KB line carrying RE-FIRE-2..10 narratives. The queued dedup-gate and evidence-landing-spot items (TODO_LIST.md:340, 659; pipeline.md:273, 280) remain unimplemented, so the churn is structurally unbounded.
2. **`alt-nix` (530M) + `scratch/eventcatalog-t0` (2.7G) dispositions** — deliberately flagged by the check, blocked on the owner (TODO_LIST.md:30).
3. **The 08-40 report's sudo-gated end-to-end script run** — re-fire 8 ran the das-check end-to-end once; fires 9–10 fell back to extraction-equivalence (sandbox blocks sudo). The invariant is covered, but not by the script's own output each time.
4. **Fix-ticket report §f lists deliberately thin** (the 01-21 fix report populated 6 of 50 slots and said so honestly) — correct behavior, noted for the record.

## c) NOT STARTED (in the window's blast radius)

- The `golangci-lint-analysis` writer hunt (recreated 4× on 2026-10-02; queued TODO_LIST.md:32).
- `[6]` empty-dir churn signal (queued :33); `buildcacheDirs`↔KNOWN parity as a scripted selftesting check (queued :646).
- NVMe fallback regrowth triage (`~/.cache/go-build` growing, queued :31).
- All pipeline-domain convention items this lineage queued: stamp compaction (:34), gitleaks pin (:35), adversarial §f cross-check (:36), re-fire evidence landing spot (:659), Task-ID dedup gate + rejected-SHA leg (:340), fix-ticket disposition protocol (:341), correction-surface sweep (:330), negative-provenance scanner (:331), no-op re-fire report compaction (:499), anchor-quote hygiene (:500), stale dedup-gate pointers (:501), re-fire appendix convention (:522).
- CHANGELOG had no entry for the 2026-10-02 KNOWN_CACHE_ENTRIES reconciliation — added by this pass.

## d) TOTALLY FUCKED UP

1. **The re-fire loop is self-feeding queue churn.** 10 fires + 9+ fires on two already-`[x]` items in ~36 hours; six-plus fires ran after the dedup gate was queued. Root causes per the reports: completion detection keys on footer commits that rode heuristic auto-commits (`8187b1c1`); fix tickets key on Task-ID, not rejected-SHA state; clean fires append rows that may themselves re-feed the harvest pool. Each fire is a paid dispatch for zero delta.
2. **Report entombment:** 17 near-duplicate status-report files exist for the two ticket lineages (14 fada + 3 f5c6). The re-fire appendix convention (practiced live at fires 6/8) exists but was never codified, so later fires authored new files anyway.
3. **The original false claim** (07-16 report asserting "00-46 names NO sites" without reading that report's §a.5) — a categorical negative-provenance claim caught only by the reviewer; corrected, but it cost the entire 9-fire fada ticket lineage.
4. **Pre-commit still partially dark:** the window's first commit needed `--no-verify` because the pre-existing `audit-serviceconfig-merge` selftest red (queued `e79b30a4`) blocks every commit — every agent in this tree pays that tax.
5. **Git index.lock contention** burned ~10 minutes on the 01-21 fix run before the wait-for-lock + PATHSPEC pattern was used (should be the default first attempt on this shared tree).

## e) WHAT WE SHOULD IMPROVE

1. **Land the re-fire dedup gate for real** (Task-ID + rejected-SHA, ≥3rd dispatch → stop + page). Six consecutive fires passed it by. Highest-leverage fix in this window; everything else is secondary.
2. **Retirement clause:** after 3 consecutive clean fires with zero tree delta, retire the item ("stable across N fires") and stop appending. Owner decision, but it must be DECIDED (queued below as blocked).
3. **Canonical re-fire evidence landing spot:** a single log file (e.g. `docs/status/_refire-log.md`) instead of unbounded inline growth on queue rows, plus migration of the existing RE-FIRE-2..10 stamps off TODO_LIST.md:28 (both queued: :659, :34).
4. **Queue-side pre-dispatch done-grep:** before dispatching an item whose close-out says DONE, grep the named file for the implementation (the 06-27 dispatch proved this class — the work item arrived fully implemented and closed).
5. **Footer-commit discipline:** when a daemon heuristic commit sweeps a queue task's work, amend the footer in while unpushed (the daemon-race policy exists; it wasn't used, and the miss caused the 06-27 re-fire).
6. **Verify-only re-dispatches should re-run the cheap gates** (shellcheck + `nix flake check --no-build`), not just greps — three fires each invented their own grep-variant list; the negative claim is only as strong as the union of variants tried (queued below).
7. **Categorical-negative discipline in reports:** never assert "file X names no sites" without quoting the file's relevant section. The negative-provenance scanner candidate (:331) addresses this mechanically.
8. **Archive no-op re-fire reports** instead of entombing them in docs/status/ — this pass archived the uncited fada-lineage duplicates (see below) and added a manifest.

## f) NEXT THINGS (the harvested subset lives in TODO_LIST.md; full list below)

Direct descendants (queued this pass unless already queued — noted):

1. Land the re-fire dedup gate (Task-ID + rejected-SHA, ≥3 fires → halt) — already queued :340/pipeline:273.
2. Re-fire retirement clause decision — queued below as blocked:user.
3. Re-fire evidence landing spot + row migration — already queued :659/pipeline:280.
4. Sweep ALL tables in the SAMSUNG-PHASE2 plan doc for other empty status columns — queued below (new).
5. Markdown table-shape lint (header cells == row cells) in the docs pre-commit path — queued below (new).
6. Verify-only re-dispatches re-run the cheapest gates (shellcheck + flake check) — queued below (new).
7. Codify the DONE-no-op-sweep library-row convention (one sentence in CONTRIBUTING's TODO-system section) — queued below (new).
8. `golangci-lint-analysis` writer hunt — queued :32.
9. `[6]` empty-dir churn signal — queued :33.
10. buildcacheDirs↔KNOWN parity as selftesting repo check — queued :646.
11. NVMe fallback regrowth triage — queued :31.
12. alt-nix + scratch disposition — queued :30 (blocked:user).
13. buildcacheSymlinkPaths split-brain (derive home.file from ONE list + negative-test) — queued :39.
14. Stub test for the destructive discordsync-attachments-migrate oneshot — queued :42.
15. Restic post-deploy proof chain — queued :40.
16. Pre-existing serviceconfig-merge selftest red (re-arms a blocking pre-commit leg) — standing queue item.
17. Queue-side pre-dispatch done-grep — new observation; queued below.
18. Stamp compaction for 3+-stamp queue rows — queued :34.
19. Anchor-quote hygiene + no-op report compaction — queued :499/:500.
20. Boot-mirror first reboot + post-reboot verify — queued :21 (owner).

(21–50 deliberately not enumerated: the standing backlog in TODO_LIST.md + docs/todo/* already owns fleet-wide work; padding this list with restatements would fabricate backlog — same rule the 07-40 report applied.)

**Self-harvest statement (HARVESTED 2026-10-03):** items 4–7 and 17 appended to TODO_LIST.md this pass (Phase-2 table sweep, table-shape lint, verify-only cheap gates, pre-dispatch done-grep); items 1–3, 8–13 already queued (:340, :659, :32, :33, :646, :31, :30, :39); item 16 standing; item 20 owner-gated (:21); §g questions appended as BLOCKED rows.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Re-fire retirement clause:** is "3 consecutive clean fires with zero tree delta → retire + stop appending" the intended terminal state for re-dispatched verification items? Without a threshold the loop is structurally infinite (10 and 9 fires and counting).
2. **Is the harvest pool re-feeding from the appended re-fire rows?** Confirming the harvest source (tq state file vs the `[x]`-row text) turns the dedup-gate fix from a guess into a one-dispatch fix.
3. **Do DONE no-op sweep items need library rows?** The 07-40 report found a completed sweep whose close-out points at a storage.md library that never held it — one sentence of convention either way in CONTRIBUTING settles it.

## h) BAND DRIFT

**None recorded.** `tq facts` holds zero `task.reprioritized` events for the entire journal (checked 2026-10-03 01:15), and none in the window's timespan. All six window tasks kept their enqueue priority throughout; the dispatch order observed (work items → fix tickets → re-fires) followed queue mechanics, not priority moves.

---

**Archived this pass:** the 10 uncited no-op re-fire reports of the fada lineage (06-41, 06-57, 07-12, 07-23, 07-44, 07-57, 08-07, 08-18, 08-59, re-fire9) moved to `docs/status/archived/` with resolution banners; manifest in `docs/status/archived/README.md`. All cited lineage reports (06-25, 07-35, 08-30, 08-31 fada; 06-47/07-16/07-40 f5c6; 00-46, 01-21, 06-27, 08-40 sources) deliberately left in place — TODO_LIST.md, docs/todo/pipeline.md, and this report reference them; moving them would dangle live pointers.
