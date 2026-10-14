# DiscordSync hardening LIVE: readonly-failure pivot — status + self-review

**Date:** 2026-10-14 05:17 CEST
**Reporting window:** since the 00:41 report (`2026-10-14_00-41_discordsync-restore-drill-automation-status-self-review.md`). During this window this session produced ONE chat answer (the Pareto prioritization) and zero repo edits until this report's harvest; everything else observed here happened AROUND the session (a parallel session's deploy train + queue harvest).
**Scope discipline:** only the DiscordSync backup P0 chain and what was directly noticed; no unrelated research.

---

## §0 Verdict in one line

The parallel session's deploy train took the hardening + restore-drill LIVE overnight (catch-up windows firing, corpses cleaned, drill timer deployed) — and both windows (03:45 + 05:15) still failed, but with a **NEW error class**: `attempt to write a readonly database`, an instant open-time refusal that is NOT the lock race both prior sessions chased; the silent-lock-holder hypothesis is likely obsolete, the dump is now 13+ days stale (14 by tonight), and the first diagnostic step (`sudo ls -la` of the agent-perm-blind DB dir for -wal/-shm sidecar ownership) needs an owner shell.

---

## §a FULLY DONE

1. **00:41 report landed** (`17169389` daemon sweep) with its self-harvest verified: the three-numbers `[ready]` row + queue one-liner are live on both surfaces.
2. **Pareto prioritization delivered** (chat): deploy+watch > owner decisions > offsite verification; explicitly ranked what NOT to do now (other legs' catch-up windows, three-numbers/VACUUM/rsync before the topology decisions).
3. **THE HARDENING AND DRILL ARE NOW LIVE** — landed by the parallel session's deploy train (stability work: tq-agent-pool IO gating `2af8cf11`, SIGSTOP standing rule `296dd162`, window closeout + queue harvest `7333beb3`), NOT by this session. Attribution is by journal + live-unit evidence:
   - The **03:45 AND 05:15 windows both fired** (the old timer had only 03:45) — the catch-up OnCalendar list is deployed.
   - **All ten 0-byte `.raw` corpses are gone** — the dumps dir now holds exactly the two good dumps (09-30, 10-01); the upfront stale-intermediate cleanup worked on its first run (prior §f.6/#3 CLOSED).
   - **The drill timer is live**: `/etc/systemd/system/discordsync-db-restore-drill.timer` → store unit, `OnCalendar=Sun *-*-* 08:00:00` (first fire 2026-10-18).
   - The **quiet-gate worked as designed**: the 03:45 run waited ~19 min on live GCS-reconcile journal lines (the pass ran past 03:42 tonight — LONGER than the 77-min model) before giving up at 04:04 and running anyway at its cap. Bounded, correct behavior.
4. **Rows re-synced at authoring time** (this report's harvest): storage.md row 45 STATUS now carries the readonly pivot; TODO_LIST row 948 rewritten to the new evidence (was: "verify on the NEXT deploy's windows"; now: windows observed, error class changed).

## §b PARTIALLY DONE

1. **The dump leg is STILL broken — 13th consecutive night, now with a different signature.** Both deployed windows failed all attempts: 03:45 (after the 19-min gate wait; run stats 19min33s wall / 1.1G mem peak / 752M read) and 05:15 (33s wall, no gate wait — reconcile silent by then). Every attempt is an INSTANT `Error: attempt to write a readonly database`, ~15s apart (fail + sleep) — the `.timeout 30000` never stretches, because nothing is busy: the open itself refuses. Last good dump: 2026-10-01 (14 days stale by tonight). The 06:45 window fires ~90 min after this report.
2. **Diagnosis of the readonly error: hypothesis only.** Prime suspect is readonly-open vs WAL/-shm state — either a hot `-wal` needing recovery (a readonly connection cannot run recovery, which requires write access) or root-owned `-wal`/`-shm` sidecars from the `+`-privileged db-heal / restart era (the EXACT uid-drift class the backup script's own `-readonly` comment warns about). The DB dir `/mnt/hot/hot/discordsync` is agent-perm-blind (`drwxrws---`), so the first decisive probe (`sudo ls -la` for sidecar ownership) needs an owner shell — see §g.3.
3. **Deploy-verify row (937/948) partially executed by events**: windows observed ✓, corpses ✓, gate ✓ — the fresh-dump / `backup_healthy 1` / restic-pickup legs remain red pending the readonly fix.
4. **PSI easing but not quiet**: some avg60 38% (was 57% at the last report) — deploy-window pressure is receding, irrelevant now that the hardening is already live.
5. **Owner questions 2 and 3 (Turso, Litestream) still unanswered** — three reports running; they are now decision-debt on the redundancy topology.

## §c NOT STARTED

1. **Readonly diagnosis + fix** (this report's top new item) — not started: perm-blind dir, sudo banned in agent shells, and the session was reporting, not working.
2. **Turso / Litestream decisions** — unchanged, owner-gated.
3. **Three-numbers collector, VACUUM INTO, sqlite3_rsync analysis** — queued earlier, deliberately waiting on the topology decisions.
4. **Holder identification (io.prom probe)** — now likely OBSOLETE as framed (the error is not a lock); what survives is identifying WHY the readonly open refuses (sidecar ownership vs hot-wal), which is item 1.
5. **Other dump-leg catch-up windows, fleet drill sweep, offsite remote verification, docs-health 105-report pass** — unchanged from the 00:41 report's §c.

## §d TOTALLY FUCKED UP (honest)

1. **Two sessions of lock-holder theory may have been chasing the wrong failure class.** The 10-13 investigation concluded "a different, silent writer held the lock" from `database is locked` evidence — that WAS the evidence then — but the 10-14 windows show the current blocker is a readonly refusal. Two possibilities and both are unflattering: (a) the failure mode CHANGED between 10-13 and 10-14 (e.g., sidecar state drifted after another restart), and nobody re-checked the error string before re-anchoring; or (b) the readonly condition was already the real blocker earlier and the "locked" readings masked it. Either way: the backfill-holder hypothesis that shaped the catch-up-window design was never validated, and the windows turned out to be retries against a NON-transient error (see #2).
2. **The catch-up windows were designed on a transience assumption that is false for this error.** I landed 05:15/06:45 as same-day retries for a transient lock race; against a persistent readonly refusal they are mechanical no-hopers (05:15 proved it: 3 instant refusals in 33 seconds). The design is not harmful (bounded, loud), but its premise should have been stated and tested: "retries help ONLY if the failure is transient". This report corrects the rows.
3. **The 00:41 §g.1 (deploy timing) aged out in under 3 hours** — a parallel deploy train answered it by events. Point-in-time questions age fast; the report flagged the risk but the lesson is to re-verify live state at EVERY report boundary (done this time: timer + journal + dumps dir probed before writing).
4. **No fresh backup was produced across the entire hardening effort so far.** Fourteen days of work on windows, gates, drills — and the RPO hole is as open as on day one, now for a THIRD distinct reason (busy_timeout=0 → lock race → readonly refusal). The honest framing: we have been hardening the retry AROUND an unroot-caused failure, not fixing the failure.
5. Nothing destructive, no prod mutation by this session, no data loss beyond the standing 13-day dump gap.

## §e WHAT WE SHOULD IMPROVE

1. **Diff the error STRING, not the outcome.** Every window-watch and every alert that reports this unit should key on the distinct failure text (`database is locked` ≠ `attempt to write a readonly database`) — tonight's pivot was visible in one journal line but the rows would have happily recorded another "failed window". Candidate: the OnFailure alert text should carry the last error line.
2. **State the transience assumption of any retry mechanism in its row** — "catch-up windows assume the failure is transient"; a persistent error needs a fix, not more attempts. Add to the CONTRIBUTING dump-leg pattern item (§f).
3. **Mine the code's own warnings before hypothesizing**: the backup script's `-readonly` comment documents the exact -wal/-shm root-ownership poisoning class that is now the prime suspect. The answer was in the file both sessions were editing.
4. **Root-cause before resilience**: the failed-run → add-retries → failed-again loop (timeout fix 10-11, reschedule 10-12, catch-up windows 10-13) consumed three nights against an unroot-caused error. The cheap decisive probes (sidecar ownership) should have run on night one — they were blocked by sudo, but ASKING for one owner-run `ls -la` on 10-13 would have beaten three design iterations.
5. **Parallel deploy trains moot open questions** — always re-probe live state (journal, deployed unit symlinks) at session/report boundaries; it took one `journalctl` + one `ls` to learn more tonight than in the whole prior evening.

## §f UP TO 50 THINGS TO GET DONE NEXT

| # | Task | Impact | Effort | Category | Surface |
|---|------|--------|--------|----------|---------|
| 1 | **Readonly diagnosis, step 0**: owner-run `sudo ls -la /mnt/hot/hot/discordsync` — ownership/mode of the DB, `-wal`, `-shm` (agent shells are perm-blind + sudo-banned) | Critical | S (owner) | Bug (root cause) | NEW; rows 45/948 updated |
| 2 | If sidecars root-owned: one-time chown to `discordsync:discordsync` + fix the CREATOR (db-heal `+`-privileged open, or any root-open of the WAL db) so it cannot recur; re-run backup same window | Critical | S | Bug | NEW (row 45 follow-on) |
| 3 | If instead a hot `-wal` needs recovery: decide the mechanism (a server-triggered checkpoint, or a brief root-assisted `.recover`/checkpoint before dump) — do NOT simply drop `-readonly` (that re-opens the poisoning class the flag exists to prevent) | Critical | S/M | Bug + Decision | NEW |
| 4 | Watch the 06:45 window after any fix; confirm fresh non-zero dump + `backup_healthy{discordsync} 1` + restic app-dumps pickup | Critical | S | Verification | row 948 |
| 5 | Once a dump lands: mark hot-db wave-5 gate GREEN in hot-db.md + update AGENTS.md DiscordSync section (premature-success ban lifts) | High | S | Documentation | prior §f.27/31 |
| 6 | Restore-drill the first post-fix dump (manual or wait for Sunday) | High | S | Verification | row 943 |
| 7 | Expect + verify the Sunday 08:00 drill run: while the leg is broken it FAILS by design (freshness gate, 14-day-old dump) — confirm the page fires with the honest message and the `wants`-triggered backup attempt precedes it | High | S | Verification | row 943 |
| 8 | Add the failure STRING to the backup unit's OnFailure alert text (locked vs readonly vs no-dump are different diagnoses) | High | S | Feature (alerting) | NEW (§e.1) |
| 9 | Fold "retries assume transient failures" into the CONTRIBUTING dump-leg pattern item | Medium | S | Documentation | prior §f.38 + §e.2 |
| 10 | Turso plan decision (upgrade vs local-only) | High | S | Decision | storage.md; **owner (Q1)** |
| 11 | Litestream trade decision (pool-file vs B2/S3 vs skip) | High | S | Decision | storage.md; **owner (Q2)** |
| 12 | Verify the restic app-dumps repo's remote leg exists (3-2-1 floor) + read the btrfs/offsite companions | High | M | Verification | prior §f.12 |
| 13 | Three-numbers collector (backup age / drill age / lag) — stopped-timer blind spot | Medium | M | Feature | queued 00:41 |
| 14 | Catch-up windows for the other dump legs (still snapshotted; no RPO exposure) | Medium | L | Feature | row 189 |
| 15 | VACUUM INTO vs .backup decision | Medium | S | Decision | storage.md |
| 16 | sqlite3_rsync warm-standby decision | Medium | S | Decision | storage.md |
| 17 | WAL-gate discordsync-db-heal's unconditional integrity_check | Medium | S | Bug | existing row |
| 18 | If the readonly fix touches db-heal: audit EVERY root-context open of the WAL db for sidecar-creation (the systemic version of #2) | High | M | Bug | NEW (row 45 follow-on) |
| 19 | Extend guard `ioChurnUnits` (db-heal + crush-hot-db-migrate) | Medium | S | Bug | existing row |
| 20 | Capture-gap alarm (message.created silence-while-connected) | Medium | M | Feature | existing row |
| 21 | Per-service journal-rate smoke guard | Medium | M | Feature | existing row |
| 22 | MemoryHigh reclaim-thrash review (discordsync 31.6k hits et al.) | Medium | M | Bug | existing row |
| 23 | Triage the 10 throttled units (§17 sweep) | Medium | S | Bug | existing row |
| 24 | `'''` → `""` case patterns in discordsync.nix | Low | S | Quality | existing row |
| 25 | Immich key paste → deploy → verify chain | High | S | Feature | existing row (owner key) |
| 26 | Upstream Tier-3 fixes (release tag, module options, healthCheck) | Medium | L | Bug (upstream) | existing row |
| 27 | Catalog subdomains eval warning (21 names) | Low | M | Quality | prior §f.26 |
| 28 | Verify the re-lock waves eval green post-merge (now several trains deep) | Medium | S | Verification | prior §f.31 |
| 29 | gzip-integrity check of the 09-30 dump | Low | S | Verification | prior §f.46 |
| 30 | `backfill_progress` freshness leg in the drill | Low | S | Feature | prior §f.47 |
| 31 | Turso-red gatus check noise review post-shadow-split | Low | S | Quality | prior §f.39 |
| 32 | GOTRACEBACK=all (discordsync + browser-history) | Low | S | Quality | existing row |
| 33 | OTLP logs / trace-id correlation | Low | M | Feature | existing row |
| 34 | io-metrics counter reset check across the next deploy restart | Low | S | Verification | prior §f.43 |
| 35 | Fleet sweep: other drill-less "only backup" legs | Medium | M | Verification | prior §f.49 |
| 36 | docs-health HARVEST pass over the 105 unharvested reports | Low | M | Documentation | observed 00:41; docs-health owns |
| 37 | Record the BuildFlow surgical-run pattern in agent docs | Low | S | Documentation | 00:41 §e.6 |
| 38 | Full pre/post-deploy suites around the NEXT deploy carrying any readonly fix | High | S | Verification | prior §f.50 |

Deliberately not queued: §d.3 (moot-question aging — process note), §d.4 (framing, fixed by this report's rows).

## §g QUESTIONS ONLY THE OWNER CAN ANSWER (3)

1. **Turso plan** (unchanged, third report): upgrade (cloud mirror auto-resumes; the dump stops being the only backup) or permanent local-only (drop TURSO_* + the deliberately-red gatus check)? This decides how much of §f is urgent vs optional.
2. **Litestream trade** (unchanged): pool-file replica (free, same-host failure domain), B2/S3 (true offsite, secrets + cost), or skip (nightly dump + catch-up windows only)? If the readonly diagnosis drags, Litestream is also the fastest path to ANY redundancy for the event store.
3. **One sudo probe to unblock the diagnosis** (NEW, permission-bound, not answerable by me): please run `sudo ls -la /mnt/hot/hot/discordsync/` and paste the output — the ownership/mode of the DB, `-wal`, and `-shm` files decides between the two fix paths (sidecar chown + creator fix vs checkpoint/recovery mechanism). Alternatively: authorize watching the 06:45 window journal-only and I proceed with whatever it shows.

---

**Sources:** `journalctl -u discordsync-db-backup` 2026-10-14 03:45–05:16 (gate wait, instant readonly refusals, per-run stats); `/mnt/pool/backups/discordsync` listing (corpses gone, two good dumps); `/etc/systemd/system/discordsync-db-restore-drill.timer` symlink + OnCalendar (drill live); `/proc/pressure/io` (easing); git log (`2af8cf11`, `296dd162`, `7333beb3` parallel train; `17169389` report sweep); the 00:41 and 22:36 predecessor reports; the backup script's own `-readonly` comment (uid-drift class).
