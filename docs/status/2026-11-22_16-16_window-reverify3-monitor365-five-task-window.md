# Window re-verification #3: monitor365 five-task window (3rd fire, verification-only)

**Session:** 2026-11-22 16:16 CET (done-prompt re-fire)
**Window span:** 2026-11-22 ~03:00 → ~14:30 CET (earliest Completed: task …a1ff786b7a, commit f9b0d027d 03:27; latest: reviewer-fix task …a2022ba94c896, closeout 14:21)
**Dispatch-time dedup:** HIT — `docs/status/2026-11-22_15-46_window-closeout-monitor365-btrbk-drive-paperless.md` covers ALL five of this window's task IDs (…a1ff786b7a, …a2012fe866, …a202070cf, …a202271815, …a2022ba94c896; span 03:00→14:30), and `docs/status/2026-11-22_16-05_window-reverify-monitor365-five-task-window.md` is already the mandated verification-only 2nd-fire pass over the same set. This is a **THIRD dispatch of the identical window** → verification-only pass per the dedup contract. Sections a)–d) are satisfied by citation to both prior reports; landings re-grepped fresh at HEAD below; band drift (h) read fresh from the tq journal.

---

## a) FULLY DONE

**By citation:** the 15-46 report §a (five items: monitor365 runbook refresh; storm-wedge ioTier/start-limit batch; btrbk BE/6 + compsize first-night watch; drive-paperless e2e VM test; bootmetrics attribution correction) and the 16-05 report's green landing table. All headline landings re-verified GREEN at HEAD `f0f45a573`:

| Landing                                                                        | Re-check at HEAD                                                  | Verdict |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------- | ------- |
| `ioTier.heavyDB` serviceConfig on monitor365-server (fragment, not `//`-merge) | `modules/nixos/services/monitor365.nix:634`                       | GREEN   |
| `StartLimitBurst = mkForce 10`                                                 | `monitor365.nix:641`                                              | GREEN   |
| Phantom `monitor365-backup.prom` tmpfiles purge rule                           | `modules/nixos/services/backup-coordination.nix:157`              | GREEN   |
| dnsblockd `/etc/hosts`-shadow runbook section                                  | `docs/services/dnsblockd.md:19`                                   | GREEN   |
| bootmetrics `transaction_open` OPEN-path fixture                               | `flake/parts/checks/selftests.nix:113-118`                        | GREEN   |
| drive-paperless e2e VM test                                                    | `tests/test-drive-paperless-e2e.nix` present (commit `b15d03ec8`) | GREEN   |

No landing regressed between the 16-05 pass (HEAD `4b2786cd3`) and this pass (HEAD `f0f45a573`). The delta between those heads is exactly one foreign auto-commit (`f0f45a573`, forgejo fixture/script/module files, 16:10) — parallel session, does not touch any of this window's surfaces (noted in passing, attributed honestly per the shared-tree rule).

## b) PARTIALLY DONE

**By citation:** 15-46 report §b — unchanged. Storm-wedge fixes, ioTier precedence/identity-DB perms fixes (`1f1517f8e`), phantom-prom purge, and the 2026-10-17 post-deploy battery all remain tree-only pending the next owner-gated PSI-calm deploy; no deploy has fired since 16:05 (no new generation observed).

## c) NOT STARTED

**By citation:** 15-46 report §c — compsize starvation fix (TODO_LIST:524), btrbk-data last-green (3853), upstream shutdown-drain fix (push-gated), paging-leg proof (3854), VM-test legs (3855-3858), sibling commit claim-vs-diff sweep (3864). None moved.

## d) TOTALLY FUCKED UP

**By citation:** 15-46 report §d (four items). No new damage this window: this dispatch writes only this report + the README addendum line.

## e) WHAT WE SHOULD IMPROVE

1. **THIRD dispatch of the same window in ~30 minutes (15:46 full closeout → 16:05 re-verify → 16:16 this pass).** The dispatch-time dedup contract worked exactly as designed each time (hit detected before derivation, verification-only cost), but the queue is still minting re-fires. TODO_LIST:1518 (done-prompt re-fire guard: all-window footer commits + existing `*_window-closeout_*` report ⇒ verified no-op close) is the dedup-clean home for this finding and has now fired a THIRD time (2026-10-15, 2026-11-22 ×2) — its dispatch priority should rise. No new row appended.
2. The verification pass itself is now cheap and stable: one index grep + one task-ID grep + one landing-grep batch + one tq-facts read, all in three tool calls. No friction found.

## f) NEXT THINGS

None appended. The 15-46 report queued its (f) subset the same day and all rows remain open and dedup-clean; row 1518 already covers this pass's only new finding. This pass's outputs are this report + the README addendum line only.

## g) OWNER QUESTIONS

**By citation to the 15-46 report §g (both still unanswered; already encoded in queue rows 496/3848 for the deploy window):**

1. When is the next acceptable PSI-calm deploy window? Six verification legs across four batches are blocked on it.
2. Guard appetite: claim-vs-diff commit check — blocking pre-commit leg or WARN-only selftest?

## h) BAND DRIFT

**None recorded.** Fresh read this session: `tq facts --db /mnt/pool/services/tq/tq.db --type task.reprioritized` → 0 facts. Third consecutive independent read with the same result (15-46 and 16-05 reports each re-read it fresh too).

---

_Verification-only pass per the dispatch-time dedup contract. Canonical report: `docs/status/2026-11-22_15-46_window-closeout-monitor365-btrbk-drive-paperless.md`; prior re-verify: `docs/status/2026-11-22_16-05_window-reverify-monitor365-five-task-window.md`._
