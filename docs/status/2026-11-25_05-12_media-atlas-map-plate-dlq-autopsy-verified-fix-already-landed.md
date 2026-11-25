# MediaAtlas map plate DLQ autopsy: fix already landed, verdict lost to a context deadline

**Autopsy task:** 000001a210ba6a23fc0cc47e150f00000000, of dead task 000001a20f598692b387d6d4e14300000000 — 2026-11-25 05:12 CET

The dead task's error was the gatus page for `Media/MediaAtlas map plate` (2026-11-24 21:46:27). Its own second attempt had already committed the fix (`3ee08bbae`, 04:14:16) when a context deadline cancelled the run (DLQ alert 04:21:10). No verdict was recorded, so the queue dead-lettered a fixed task. This dispatch is verify and close: it changes no code.

## 1. Root cause of the page (in this repo, read first-hand)

`scripts/deploy.sh` restarted the hub's provisioners one `systemctl restart` per unit. The hub unit `Requires=` two of them (`systemctl show media-atlas.service -p Requires`: `immich-api-key-provision.service media-atlas-key-provision.service`), so each transaction also bounced the hub. Deploy `2026-11-24_21-20-43`, provisioner convergence phase (systemd journal + sudo `COMMAND=` lines, this boot):

| Time (CET)       | Event                                                                                                                                             |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| 21:43:31.235     | `sudo systemctl restart immich-api-key-provision.service`; hub `Stopping` 6 ms later, old instance gone 21:43:37.366                       |
| 21:43:37.506     | hub `Starting` (first start: journal replay)                                                                                                      |
| 21:43:37.599     | `systemctl restart media-atlas-pg-ro.service` (no bounce: not in the hub's `Requires=`)                                                            |
| 21:43:37.795     | `systemctl restart media-atlas-key-provision.service`: the hub stop job lands 0.29 s into the first start                                           |
| 21:45:07.806     | `State 'stop-sigterm' timed out. Killing.` (90 s `TimeoutStopUSec`): SIGKILL, `Failed with result 'timeout'`                                       |
| 21:45:10.480     | hub `Starting` again from zero                                                                                                                    |
| 21:54:03.901     | `Started` (8 min 53 s); gatus initial alert 21:46:27.091                                                                                          |

The hub does not observe SIGTERM while blocked in the replay, so the second stop could only end in the 90 s kill. Same shape on 2026-11-20 23:13 and 2026-11-23 05:07 (unit journal since 11-19). Control: the 2026-11-24 23:34 deploy ran the same three transactions in a calm window; the hub came back in 26 s and both bounces were clean.

## 2. The fix already in HEAD

- `17b6930ef` — `scripts/deploy.sh`: `restart_media_atlas_provisioners` restarts `immich-api-key-provision`, `media-atlas-pg-ro` and `media-atlas-key-provision` in ONE transaction; the three left the per-unit loop.
- `b725ff4de` + `a3260ad54` + `fd20f095a` — `scripts/test-deploy-pipeline.sh` group F (19 assertions, negative legs included).
- `ef91b3d3c` — `docs/services/media-atlas.md` runbook entry.
- `3ee08bbae` — queue rows on both surfaces + the task footer (04:14:16).

## 3. Independent verification in this dispatch

- `bash scripts/test-deploy-pipeline.sh`: `deploy-pipeline selftest: 61 assertions hold` (group F 19 of 19 ok).
- `bash -n` on both scripts: ok. shellcheck: `deploy.sh` 0 findings before and after the fix; the test script 8 note-level findings before and after, none in group F.
- Live systemd probe (262, throwaway transient units in the invoking user's manager, removed afterwards): a unit that `Requires=` two oneshots is restarted 2 times by two separate `systemctl restart` calls and 1 time by a single call carrying both.
- Live host state (05:0x): `media-atlas.service` active, PID 3367603 since 2026-11-24 23:34:53, `NRestarts=0`; `GET /` 200 in 65-80 ms with the `MediaAtlas` body marker, `/health/ready` and `/health/timers` 200; the gatus journal holds exactly one map-plate alert since 2026-11-24 21:30 (21:46:27).
- `deploy-restart-audit.nix` matches unit names with `hasInfix` over the whole `scripts/deploy.sh` text, so the three units leaving the loop cannot trip it, and the `deployrestart` negative-test fixture (sed over every occurrence) stays valid.

## 4. Why the task died (dead-letter cause, outside the reported error)

From the session store (`.crush/crush.db`, session `0000b5aa-1ac4-4a68-824d-414c278a4f82`) and the pool journal:

- Attempt 1: prompt 03:18:39, ended by 03:48:42 at the latest, when the pool preflight refused the re-dispatch on the dirty tree (`M scripts/deploy.sh`); the auto-commit daemon committed that file at 03:49:31.
- Attempt 2: prompt 03:50:53 (same session continued). Selftest 04:07, runbook 04:11, footer commit 04:14:16. At 04:16:24 it launched `.tq-verify` (`nix flake check --no-build`) by hand in a background job. Last recorded message 04:17:38. DLQ alert 04:21:10 (30 min 17 s after the prompt); autopsy enqueued 04:23:02.
- Both attempts ended with `agent run cancelled (context deadline exceeded)` at about 30 minutes, while `modules/nixos/services/tq-agent-pool.nix` sets `task-timeout = "180m"`. The layer that owns the 30-minute wall was not located (§f.3).
- The manual gate run was not needed: the queue runs the verify gate after the run, and by the repo's own predicate (`scripts/lib/eval-relevant-paths.sh`) none of the fix's paths can change a `--no-build` eval.

This is the class of the open verdict-durability row (`docs/todo/pipeline.md` + `TODO_LIST.md`, "write `$TQ_RESULT_FILE` immediately after the report commit"). This dispatch therefore wrote its verdict file first (05:12) and this report second.

## 5. Re-dispatch protocol (docs/CONTRIBUTING.md)

1. Footers + queue surfaces: the landed work carries the dead task's footer (`3ee08bbae`); both TODO surfaces carry the same 2026-11-25 update on the slow-start row, which stays open for the replay leg. No drift.
2. Live spot-check: section 3.
3. Source §f sweep: the dead run wrote no status report, so no §f exists to sweep; its open leg (the replay read) is on the slow-start row.
4. Footer: this commit carries this task's footer.
5. BLOCKED reasons: none on this item.

Verdict: verified, the fix stands.

## 6. Not verified here

- The fix in a real deploy. The first candidate (deploy `2026-11-25_04-59-27`) was mid-switch at 05:09; §f.1.
- `nix flake check --no-build` was not run: eval-irrelevant paths, io PSI about 50, another session's eval in flight.
- Which layer owns the 30-minute context deadline (§f.3).
- `CHANGELOG.md` has no entry for the batch fix. Not added here.

## Residue

- One bounce per deploy remains by design; inside an IO stall the replay alone takes minutes and still pages (open slow-start row, `TODO_LIST.md` + `docs/todo/services.md`).
- Two transient probe units left by two failed probe starts were stopped by explicit unit name; `systemctl --user list-units 'tqautopsy-*'` is empty.

## §f Follow-ups

- §f.1 Verify the first post-fix deploy bounces the hub exactly once. HARVESTED: `docs/todo/services.md` (watch row).
- §f.2 Verdict-durability class. Already tracked (`docs/todo/pipeline.md` "Verdict-durability rule" + its `TODO_LIST.md` pair); no new row.
- §f.3 Locate the 30-minute context deadline. HARVESTED: `docs/todo/pipeline.md` + `TODO_LIST.md` (ready pair).

HARVESTED 2026-11-25: §f.1 and §f.3 as listed above; §f.2 deliberately not re-harvested because an open ready pair already covers it.
