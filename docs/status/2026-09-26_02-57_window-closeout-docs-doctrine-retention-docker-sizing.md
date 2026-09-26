# Window Closeout — Docs-Doctrine Round: Root-Window Reconciliation + Docker Sizing (5 tasks)

**Date:** 2026-09-26 02:57 CEST
**Window:** 2026-09-25 ~11:00 → 2026-09-26 02:33
**Reporter task:** `000001a0db1ee66ade1e10bded97efa994e2` (this report carries its footer)
**Scope:** the five completed queue tasks listed below + the docs-health pass over their surfaces. Docs-only window; zero code/config changes.

| # | Task | Commit(s) | Closeout report |
|---|------|-----------|-----------------|
| 1 | `000001a0d7c6e16844a893aafd7c9a19a748` — refresh the `/data/docker` doctrine-row sizing via no-sudo `docker system df` | work `6f7899a3` + report `050ec1ee` | `docs/status/2026-09-25_11-02_task-…748.md` |
| 2 | `000001a0d7ddc4c5db6b3a8da3acdfb9a1d8` — reconcile the root `@` retention anomaly, restate the doctrine root window | work `22a4e88f` + report+harvest `58cb44ae` | `docs/status/2026-09-25_11-51_task-…1d8.md` |
| 3 | `000001a0d80b8bec7736df65bb79e89dce1b` — reviewer-finding fix: stale `/data/docker` figure in the AGENTS.md Samsung section | work `fad88cbc` + report `7cfcafec` | `docs/status/2026-09-25_12-46_task-…e1b.md` |
| 4 | `000001a0d80b8ba29cede448b76050225c24` — sweep stale root-window echoes | work `eb844911` + report `e1c4e154` (first dispatch) + verification-only re-close `323de6cf` | `docs/status/2026-09-25_12-27_task-…c24.md` + `…12-56_task-…c24.md` |
| 5 | `000001a0da959282715434d3deed08352a8c` — reviewer-finding fix: alleged root-window contradictions in AGENTS.md (4th dispatch, NO-EDIT closure) | `563266db` + `5592c0c9` | `docs/status/2026-09-26_02-10_task-…a8c.md` |

**Observed in passing (same window, sibling ticket):** `000001a0dad1143cdb10aef5d1afc4accbb1` (FEATURES.md echo, run 1 actually fixed it: `3e3d718a`) + its disposition report `7ca80f55` — 3 surplus no-edit dispatches there too.

---

## a) FULLY DONE (verified against the tree, not just claimed)

1. **Root `@` retention reconciled from btrbk source, not folklore.** The "12-day-old weekly" was IN-SPEC: btrbk 0.32.7 `schedule()` (store-verified deployed version) retention buckets are CALENDAR-anchored — days start 00:00, weeks start Sunday (`preserve_day_of_week` default, matching the Sunday-dated weeklies); `snapshot_preserve 3d 1w` keeps all snapshots from the last 3 day-buckets plus the first snapshot of each of the TWO calendar weeks covered, so a Sunday-weekly lives exactly 14 days. The live set (09-13 + 09-20 weeklies, 09-21..24 dailies) matches the model 6/6. Doctrine restated in AGENTS.md: root `@` = **2w sharp** (was "≈ 1-2w approximate"); verified at AGENTS.md:660 (paragraph), :670/:671 (table rows), :699 (T14 caveat), :972 (ClickHouse note). Commits `22a4e88f` + `eb844911`.
2. **`/data/docker` sizing refreshed from a live no-sudo probe.** `docker system df` 2026-09-25: images 9.09G (8/26 active) + containers 4.4M (9/10) + volumes 4.34G (6/212 active, 4.09G/94% reclaimable) + build cache 2.08G (0/119 active) ≈ **15.5G total, ~9.9G/64% reclaimable**. Doctrine table row updated (AGENTS.md:669, dated provenance, supersedes the ~20G-era figure) — commit `6f7899a3`.
3. **The Samsung-section stale echo fixed (reviewer finding).** The second hand-synced copy of the docker figure (AGENTS.md:1228, "~20 G … ~88% pruneable garbage") now carries the 2026-09-25 figures + a pointer to the doctrine table — commit `fad88cbc`. Verified: no `~20 G`/`88% pruneable` survivors in live docs.
4. **Every stale root-window echo aligned.** `root ≈ 1-2w` has ZERO hits in AGENTS.md, docs/services/, docs/todo/, TODO_LIST.md, FEATURES.md, README (re-grepped fresh this pass, including unicode/spaced variants per run 4's method). Remaining hits are the three legal classes: live-config restatements (`snapshot_preserve 3d 1w`, FEATURES.md:289 deliberately kept), DONE-note history, and archived/planning historical records. The FEATURES.md:291 emergency-reserve row reads "root pin window = 2w sharp, calendar-anchored" (`3e3d718a`).
5. **The "prune gaps" framing retired as MISDIAGNOSIS** with its own closure (TODO_LIST:50, storage.md row): it was a speculative parenthetical for the same observation the calendar-anchor math proved in-spec; real guard/outage-killed btrbk events (DAS outage, Zone-6 trips) have their own incident records and shift prune ≤ +24h — immaterial to 14-day windows.
6. **Both todo surfaces stayed drift-free** through all five tasks: queue one-liners (TODO_LIST:47-50) and library rows (storage.md) ticked with consistent DONE notes; the FEATURES-echo review fix was folded back into row 49's DONE note.
7. **All pre-commit gates green on every work commit** (gitleaks, trailing whitespace, eval-only `nix flake check`), daemon races handled by the amend-forward doctrine each time (verified `git show --stat` before amending, never reset).

## b) PARTIALLY DONE

1. **The retention-reconciliation EPIC: understanding complete, prevention still missing.** The figure is right everywhere TODAY, but it lives in ≥6 prose surfaces with no mechanical gate — the durable fix (the grep-gate, storage.md:136) has been queued since 2026-09-25 12:27 and no dispatch has picked it up. Three sessions + one review were needed to catch 7 stale sites; the next figure change re-runs the circus. Mirrored into the queue this pass.
2. **2w-sharp evidence is derivation + inventory, not scheduler observation.** The bucket math was hand-derived from perl source and cross-checked against 6/6 live snapshots; a read-only btrbk dryrun/info output showing its own "preserve weekly" labels was never captured (11-51 §b2). Queued this pass.
3. **Reconciliation scope is root-only.** `/data` (14d 4w) and pool `services/*` (7d 4w) windows in the doctrine table remain the sweep's approximations (≈4-5w / ≈4w) — consistent with the model but unreconciled. Owner question (g1), now with a persistent blocked row.
4. **Docker figure de-duplication chosen-against.** The reviewer's pointer-only alternative was declined twice (inline-figures variant kept), so the figure still lives in 2 AGENTS.md places; the drift class is mitigated only by dated provenance. Queued as a small conversion item this pass.
5. **Run 5's own verification coverage** was complete in the finding's named scopes but trusted prior-run evidence for `scripts/migrate-clickhouse-xfs.sh` and the `22a4e88f`→`eb844911` transient timeline. Queued as a fresh re-close sweep this pass.

## c) NOT STARTED (window skips + inherited backlog untouched)

1. **The stale-figure grep-gate** (storage.md:136) — the single most important open item of this lineage.
2. **The snapshots.nix calendar-anchor comment** (storage.md:15, TODO_LIST:51) — verified still absent this pass (`snapshot_preserve = "3d 1w"` at snapshots.nix:219 carries only the pool-tier comment).
3. **The `@home-hermes` 09-16 snapshot investigation** (9 days old vs `snapshot_preserve 3d`) — the one live over-retention candidate; queued, untouched.
4. **Docker volume hygiene** — 212 volumes / 6 active / 4.09G (94%) reclaimable, no inventory, no owner; deliberately out of auto-prune. Queued this pass.
5. **On-disk provenance cross-check** of `/data/docker` (sudo `du`/`compsize` vs docker accounting) — the 20G→15.5G drop may be partly measurement-method. Queued.
6. All owner-gated storage backlog (offsite-borg go-live inputs, /data repair gates, ClickHouse restore drill, restic proof chain, deploy-authority decision) — untouched; queue pacing owns them.

## d) TOTALLY FUCKED UP (regressions, dead-lettered work, process damage)

Nothing in the window's own artifacts is broken — every landed claim re-verified green this pass. The honest damage list is process-level:

1. **The re-dispatch loop burned 7 surplus runs on closed findings.** Ticket …a8c (this window's task 5) dispatched FOUR times (reports 01-09, 01-35, 01-38, 02-10) against a finding whose every echo was already aligned on master — three footer-carrying no-edit closures existed before run 4 even started. The sibling FEATURES ticket repeated the pattern (fix + 2 re-verifies + a disposition). Root cause is outside repo visibility: either the queue's done-detection cannot see footer-carrying closure commits, or a reviewer keeps rejecting no-edit verdicts without a recorded objection. Existing blocked row TODO_LIST:322 covers the class; each surplus dispatch cost a full verify+report cycle and minted a public commit.
2. **Master transiently carried a self-contradicting doctrine** (~hours on 2026-09-25): `22a4e88f` shipped "2w sharp" in the paragraph while two table rows + the T14 caveat in the same section still said "1-2w"/"3d+1w", healed by `eb844911`. A wrong pin window is exactly what an operator consults before deleting multi-hundred-GB trees. Root cause: no gate; mitigation queued (a.1 above).
3. **The pre-commit store-warmth failure blocked an innocent docs-only commit** (run 4): `checks.x86_64-linux.hermes` died `path 'ix80s6aj…-source' is not valid` — a GC-evicted flake-input source only that eval forces. The multi-minute failed-gate window is precisely when the auto-commit daemon swept the report into heuristic commit `96da8a79` (recovered correctly via verified amend-forward). Root cause unidentified; heal recipe now recorded in AGENTS.md (this pass) and the root-cause + retry leg queued.
4. **The atomic-doc-sweep doctrine was violated knowingly in run 1** (docker sizing): the sweep grep FOUND the Samsung-section echo and queued it instead of fixing it — the exact pattern the 2026-09-06 two-line-fix owner permission forbids. The reviewer finding (task 3) was the direct bill for that.
5. **Report noise is compounding:** 4 no-edit reports for ticket …a8c + 3 for the sibling, each a commit in public history, none the durable fix. No "supersede, don't accumulate" convention exists for repeat-dispatched findings (proposed in run 4 §e5; owner question via TODO_LIST:316's blocked row).

## e) WHAT WE SHOULD IMPROVE

1. **Make figure hygiene mechanical, not mnemonic** — the grep-gate (storage.md:136) with the 7-site canonical hit list as fixtures, the three legal-context rules, unicode variants, negative-tested, same implementation in pre-commit AND CI. This is the family-ender for the whole echo class.
2. **Put the "why" where the figure is authored** — one calendar-anchor comment next to `snapshot_preserve = "3d 1w"` in snapshots.nix inoculates the source against the next misreading.
3. **Fix-on-sight for stale facts inside files already being edited** — run 1's queue-it-instead-of-fix decision produced a reviewer ticket, a second dispatch, and two extra commits for a one-line change. The 2026-09-06 owner permission already covers this; it needs to actually bind.
4. **Close the queue↔git closure handshake** — done-detection must credit footer-carrying no-edit closures, or re-dispatched verification runs should append "re-confirmed run N" to the existing report instead of minting file N+1 (TODO_LIST:316/322 blocked on the owner).
5. **Pre-commit resilience to store warmth** — classify `path '.*-source' is not valid` eval failures (loud WARN naming the heal, or retry-once-with-prefetch) so docs-only authors stop eating GC-timing failures (TODO_LIST:313 covers the WARN half; the prefetch leg is newly queued).
6. **Observation over derivation** when the observation is one command away — the btrbk dryrun labels would have made the 2w-sharp evidence self-documenting (queued).
7. **Figure provenance dating as a convention** — "(figures as of <date>)" on all sizing prose makes staleness greppable and would have flagged the 2026-09-06 `/data` composition figures automatically (queued).

## f) NEXT THINGS (harvest-routed; 9 new queue rows this pass — dedup-checked against TODO_LIST + storage.md)

New `[ready]`/`[watch]` rows appended to TODO_LIST.md (all point at docs/todo/storage.md unless noted):
1. Docker volume inventory (212/6/4.09G-94%) → keep/forgotten classification + prune-candidate list, NO auto-prune.
2. Sudo-window `du`/`compsize /data/docker` vs docker-reported 15.5G (provenance like-for-like).
3. Convert the Samsung-section docker prose to pointer-only (single-home the figure).
4. The grep-gate for stale root-window restatements (fixtures + context rules + negative tests + pre-commit AND CI).
5. Store-warmth root-cause + retry-once-with-prefetch leg (→ docs/todo/pipeline.md).
6. Fresh re-close of the trusted-not-re-derived echo surfaces (clickhouse script, darwin, docs/planning) + gate-scope decision for planning docs.
7. `/data` composition figure refresh + "(figures as of <date>)" convention.
8. `[watch]` post-Sunday prune verification (dangling images reclaimed; reclaimed figure + projected pin-free date).
9. btrbk dryrun observation proof for the 2w-sharp model.

New `BLOCKED` rows (owner answers, section g): reconciliation scope, final retention config, volume policy.

High-value existing rows this window re-endorses (NOT re-added — dedup): snapshots.nix calendar-anchor comment (TODO_LIST:51), `@home-hermes` 09-16 snapshot (TODO_LIST:52), queue dedup preflight (TODO_LIST:322), pre-commit WARN classification for invalid-path eval failures (TODO_LIST:313), docs-only fast path for the pre-commit flake-check leg (TODO_LIST:59), the deploy-authority decision gating every runtime-zero task (TODO_LIST:76).

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Reconciliation scope:** extend the calendar-anchor model to the `/data` (14d 4w) and pool `services/*` (7d 4w) doctrine windows now (live `.snapshots` probe), or is root-only the accepted scope? "Consistent with the model" is exactly what the root window claimed the day before it proved wrong.
2. **Final retention config:** is `snapshot_preserve 3d 1w` (every deleted NVMe byte pinned exactly 14 days) the intended end state on this historically-full box, or should it tighten? Decides whether the figure this ticket family chased changes again — and whether the grep-gate needs round-2 fixtures pre-seeded.
3. **Docker volume policy:** are the ~206 inactive volumes (4.09 GB, 94% of volume bytes) known-forgotten state safe to inventory toward prune candidates, or does any hold irreplaceable data (old compose DB-sidecars, manual experiments)? Gates the inventory item's depth.

*(A fourth question — why the queue re-dispatches closed findings — is already parked as blocked rows TODO_LIST:316/322 and is not duplicated here.)*

## h) BAND DRIFT (ADR-0015 accountability)

**None recorded.** `tq facts --type task.reprioritized` returns 0 facts across the entire journal (all types: 3,072 claimed / 1,976 requeued / 831 failed / 524 enqueued / 256 completed / 255 dead-lettered / 8 released / 7 cancelled — zero reprioritized). No priority moved in this window by any source (marker/ai/unblock/importance).

---

**Verification state at close:** working tree carries only this pass's docs changes (this report, TODO_LIST appends, CHANGELOG entry, one AGENTS.md gotcha, two inline report annotations); no code/config touched; no deploy; nothing pushed. Commits cited: `6f7899a3`, `050ec1ee`, `22a4e88f`, `58cb44ae`, `fad88cbc`, `7cfcafec`, `eb844911`, `e1c4e154`, `323de6cf`, `563266db`, `5592c0c9`, `3e3d718a`, `7ca80f55`.
