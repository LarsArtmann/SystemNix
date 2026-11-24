# Window re-verification: monitor365 five-task window (2nd fire, verification-only)

**Session:** 2026-11-22 16:05 CET (done-prompt re-fire)
**Window span:** 2026-11-22 ~03:00 → ~14:30 CET (earliest Completed: task …a1ff786b7a, commit f9b0d027d 03:27; latest: reviewer-fix task …a2022ba94c896, closeout 14:21)
**Dispatch-time dedup:** HIT — `docs/status/2026-11-22_15-46_window-closeout-monitor365-btrbk-drive-paperless.md` covers ALL five of this window's task IDs (its **Tasks:** line names …a1ff786b7a, …a2012fe866, …a202070cf, …a202271815, …a2022ba94c896; span 03:00→14:30). SAME-WINDOW report → **verification-only pass** per the dispatch-time dedup contract. Sections a)–d) are satisfied by citation to that report; landings re-grepped fresh at HEAD below; band drift (h) read fresh from the tq journal.

---

## a) FULLY DONE

**By citation:** the 15-46 report §a (five items: monitor365 runbook refresh; storm-wedge ioTier/start-limit batch; btrbk BE/6 + compsize first-night watch; drive-paperless e2e VM test; bootmetrics attribution correction). All headline landings re-verified GREEN at HEAD `4b2786cd3`:

| Landing                                             | Re-check at HEAD                                                                                                                                              | Verdict |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `ioTier.heavyDB` serviceConfig on monitor365-server | `modules/nixos/services/monitor365.nix:634` (fragment applied, not `//`-merged — the shallow-merge form `// ioTier` is GONE at HEAD, fixed by `1f1517f8e`)    | GREEN   |
| `StartLimitBurst = mkForce 10`                      | `monitor365.nix:641`                                                                                                                                          | GREEN   |
| Phantom `monitor365-backup.prom` purge rule         | `modules/nixos/services/backup-coordination.nix:157` tmpfiles `r` rule present                                                                                | GREEN   |
| dnsblockd `/etc/hosts`-shadow runbook section       | `docs/services/dnsblockd.md:19` present                                                                                                                       | GREEN   |
| bootmetrics `transaction_open` OPEN-path fixture    | `flake/parts/checks/selftests.nix:113-118` present; TODO row 521 `[x]` with the attribution correction appended (names `95fd92e85` as the real wiring commit) | GREEN   |
| drive-paperless e2e VM test                         | `tests/test-drive-paperless-e2e.nix` + `tests/default.nix` present (commit `b15d03ec8`); go-live rows BLOCKED on owner OAuth inputs (`7edc9fa60`)             | GREEN   |
| Runbook-refresh row ticks                           | `f9b0d027d` present in history; TODO row 523 `[x]` with the OBSERVED narrative                                                                                | GREEN   |
| ioTier precedence + identity-DB perms fixes         | `1f1517f8e` in history; battery fold-in row appended (TODO_LIST tail)                                                                                         | GREEN   |

## b) PARTIALLY DONE

**By citation:** 15-46 report §b — unchanged at re-verify time. The storm-wedge fix, ioTier precedence/perms fixes, phantom-prom purge, and the 2026-10-17 battery all remain tree-only pending the next owner-gated PSI-calm deploy (no deploy has fired since 15:46 — no new `system-*` generation observed; nothing in this window's 15 minutes could have changed that).

## c) NOT STARTED

**By citation:** 15-46 report §c — compsize starvation fix (row 524, `[ready]`, verified present at TODO_LIST:524), btrbk-data last-green (row 3853), upstream shutdown-drain fix (push-gated), paging-leg proof (row 3854), VM-test legs 3855-3858. None moved during the re-fire window.

## d) TOTALLY FUCKED UP

**By citation:** 15-46 report §d (four items). No new damage in this window: this dispatch changed only docs (this report + README index line).

## e) WHAT WE SHOULD IMPROVE

1. **This dispatch is itself the improvement finding the dedup contract names: the queue re-fired a window whose full closeout report landed ~15 minutes earlier (15:46 report, 16:00 re-fire).** The dedup check worked as designed at DISPATCH time this run (hit detected before any derivation), so the cost was one verification-only pass, not a duplicate closeout — but the re-fire should not have been minted at all. Existing guard row TODO_LIST:1518 ("Add a done-prompt re-fire guard: a window whose task IDs all carry footer commits AND an existing `*_window-closeout_*` report closes as a verified no-op") covers exactly this class and predates this instance — it has now fired a SECOND time (2026-10-15 instance, 2026-11-22 instance), which strengthens the case for dispatching row 1518. No new row appended (1518 is the dedup-clean home for this finding).
2. The re-verification contract itself performed well: one grep pass over the index + task-ID search located the same-window report, and every §a landing re-checked in a single command batch. No friction found.

## f) NEXT THINGS

None appended. The 15-46 report queued its (f) subset the same day (TODO_LIST tail: ioTier battery fold-in, drive-paperless citation refresh, blocked:deploy enumeration; rows 524, 3849-3863 for the rest) and all remain open and dedup-clean. This pass adds no rows — its only outputs are this report and the README index line.

## g) OWNER QUESTIONS

**By citation to the 15-46 report §g (both still unanswered):**

1. When is the next acceptable PSI-calm deploy window? Six verification legs across four batches are blocked on it. — BLOCKED: when do you want the next `nix run .#deploy`?
2. Guard appetite: claim-vs-diff commit check — blocking pre-commit leg or WARN-only selftest?

## h) BAND DRIFT

**None recorded.** Fresh read this session: `tq facts --db /mnt/pool/services/tq/tq.db --type task.reprioritized` → 0 facts; the full fact-type histogram holds no `task.reprioritized` type at all (types present: cancelled 82, cancel-requested 1, claimed 9823, completed 1162, dead-lettered 570, enqueued 1800, failed 1908, question-asked 15, released 195, requeued 6555). Matches the 15-46 report's §h verdict independently.

---

_Verification-only pass per the dispatch-time dedup contract. Canonical report: `docs/status/2026-11-22_15-46_window-closeout-monitor365-btrbk-drive-paperless.md`._
