# Window re-verification #4: monitor365 five-task window (4th fire, verification-only)

**Session:** 2026-11-22 17:04 CET (done-prompt re-fire)
**Window span:** 2026-11-22 ~03:00 → ~14:30 CET (earliest Completed: task …a1ff786b7a, commit f9b0d027d 03:27; latest: reviewer-fix task …a2022ba94c896, closeout 14:21)
**Dispatch-time dedup:** HIT — `docs/status/2026-11-22_15-46_window-closeout-monitor365-btrbk-drive-paperless.md` covers all five of this window's task IDs; `2026-11-22_16-05_window-reverify-monitor365-five-task-window.md` and `2026-11-22_16-16_window-reverify3-monitor365-five-task-window.md` are already the 2nd and 3rd verification-only passes. This is a **FOURTH dispatch of the identical window** → verification-only pass. Sections a)–d) satisfied by citation to the 15-46 report and the 16-16 re-verify; landings re-grepped fresh at HEAD `d59c7a984`; band drift (h) read fresh.

---

## a) FULLY DONE

**By citation:** 15-46 report §a (five items) + 16-16 report landing table. All headline landings re-verified GREEN at HEAD `d59c7a984`: `ioTier.heavyDB` fragment (`monitor365.nix:634`), `StartLimitBurst = mkForce 10` (`monitor365.nix:641`), phantom-prom purge rule (`backup-coordination.nix:157`), drive-paperless e2e test (`tests/test-drive-paperless-e2e.nix` present). (dnsblockd runbook section and bootmetrics fixture verified green in the two prior passes; no surface in the 16:16→17:04 commit range touches them — the three intervening commits are forgejo runbook + todo rows.) No contradiction found.

## b) PARTIALLY DONE

**By citation:** 15-46 report §b — unchanged. Storm-wedge fixes, ioTier precedence/identity-DB perms (`1f1517f8e`), phantom-prom purge, and the 2026-10-17 battery remain tree-only pending the next owner-gated PSI-calm deploy; no deploy has fired since.

## c) NOT STARTED

**By citation:** 15-46 report §c — compsize starvation fix (524), btrbk-data last-green (3853), upstream shutdown-drain fix (push-gated), paging-leg proof (3854), VM-test legs (3855-3858), claim-vs-diff sweep (3864). None moved.

## d) TOTALLY FUCKED UP

**By citation:** 15-46 report §d. No new damage: this pass writes only this report + the README addendum line. (Process note recorded in §e.1.)

## e) WHAT WE SHOULD IMPROVE

1. **FOURTH dispatch of the same window in ~80 minutes (15:46 closeout → 16:05 → 16:16 → 17:04 this).** The dedup contract contained the cost each time (verification-only, no re-derivation), but the queue keeps minting re-fires for an already-closed window. TODO_LIST:1518 (done-prompt re-fire guard) is the dedup-clean home for this finding and has now fired a FOURTH time (2026-10-15, 2026-11-22 ×3). No new row appended.
2. One repair worth naming: during the 16:16 pass, the final `--amend` briefly absorbed the daemon's forgejo auto-commit (`f0f45a573`) before it was detected and repaired by `git reset --soft` back to the daemon commit + clean pathspec recommit (`119bfe8fb`) — the exact daemon-race rule AGENTS.md documents (verify `git show --stat HEAD` before amending). The repair verified clean; no action needed beyond the standing rule.

## f) NEXT THINGS

None appended. Prior passes queued their (f) subsets; all rows remain open and dedup-clean. Outputs of this pass: this report + the README addendum line only.

## g) OWNER QUESTIONS

**By citation to the 15-46 report §g (still unanswered, already encoded in rows 496/3848):**

1. When is the next acceptable PSI-calm deploy window?
2. Guard appetite: claim-vs-diff commit check — blocking pre-commit leg or WARN-only selftest?

## h) BAND DRIFT

**None recorded.** Fresh read this session: `tq facts --db /mnt/pool/services/tq/tq.db --type task.reprioritized` → 0 facts. Fourth consecutive independent read with the same result.

---

_Verification-only pass per the dispatch-time dedup contract. Canonical report: `docs/status/2026-11-22_15-46_window-closeout-monitor365-btrbk-drive-paperless.md`; prior re-verifies: 16-05 and 16-16 reports._
