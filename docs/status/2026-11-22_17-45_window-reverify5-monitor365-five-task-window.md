# Window re-verification #5: monitor365 five-task window (5th fire, verification-only)

**Session:** 2026-11-22 17:45 CET (done-prompt re-fire)
**Window span:** 2026-11-22 ~03:00 → ~14:30 CET (earliest Completed: task …a1ff786b7a, commit f9b0d027d 03:27; latest: reviewer-fix task …a2022ba94c896, closeout 14:21)
**Dispatch-time dedup:** HIT — the 15-46 window-closeout report covers all five task IDs, and 16-05 / 16-16 / 17-04 are the 1st–4th verification-only passes. This is a **FIFTH dispatch of the identical window** → verification-only pass. Sections a)–d) satisfied by citation; landings re-grepped fresh at HEAD `cd145269e`; band drift (h) read fresh from the journal.

---

## a) FULLY DONE

**By citation:** 15-46 report §a + 16-16 landing table. All headline landings re-verified GREEN at HEAD `cd145269e`: `ioTier.heavyDB` fragment (`monitor365.nix:634`, comment at :599), `StartLimitBurst = mkForce 10` (`monitor365.nix:641`), phantom-prom purge tmpfiles rule (`backup-coordination.nix:157`), drive-paperless e2e test (`tests/test-drive-paperless-e2e.nix` present). The five commits since the 17-04 pass (`65ff22d01`..`cd145269e`) touch only forgejo runbook docs, todo ticks, boot-mirror agent docs, and daemon-heuristic commits — no landing surface in range. No contradiction found.

## b) PARTIALLY DONE

**By citation:** 15-46 report §b — unchanged. Storm-wedge fixes, ioTier precedence/identity-DB perms, phantom-prom purge, and the 2026-10-17 battery remain tree-only pending the next owner-gated PSI-calm deploy; no deploy has fired since the 17-04 pass either (deploy-log window unchanged).

## c) NOT STARTED

**By citation:** 15-46 report §c — compsize starvation fix (524), btrbk-data last-green (3853), upstream shutdown-drain fix (push-gated), paging-leg proof (3854), VM-test legs (3855-3858), claim-vs-diff sweep (3864). None moved.

## d) TOTALLY FUCKED UP

**By citation:** 15-46 report §d. No new damage: this pass writes only this report + the README addendum line.

## e) WHAT WE SHOULD IMPROVE

1. **FIFTH dispatch of the same closed window (15:46 → 16:05 → 16:16 → 17:04 → 17:45 this).** The dedup contract contained every pass (verification-only), but the re-fire loop keeps minting paid dispatches for a window whose last task closed 14:21 — 3¼ hours of repeated re-verification. TODO_LIST:1518 (done-prompt re-fire guard) remains the dedup-clean home for this finding; the guard fix itself has still not landed and has now accumulated FIVE same-day instances (2026-10-15 + 2026-11-22 ×4). No new row appended.

## f) NEXT THINGS

None appended. Prior passes queued their (f) subsets; all rows remain open and dedup-clean.

## g) OWNER QUESTIONS

**By citation to the 15-46 report §g (still unanswered, encoded in rows 496/3848):**

1. When is the next acceptable PSI-calm deploy window?
2. Guard appetite: claim-vs-diff commit check — blocking pre-commit leg or WARN-only selftest?

## h) BAND DRIFT

**None recorded.** Fresh read this session: `tq facts --db /mnt/pool/services/tq/tq.db --type task.reprioritized` → `(0 facts)`. Fifth consecutive independent read with the same result.

---

_Verification-only pass per the dispatch-time dedup contract. Canonical report: `docs/status/2026-11-22_15-46_window-closeout-monitor365-btrbk-drive-paperless.md`; prior re-verifies: 16-05, 16-16, and 17-04 reports._
