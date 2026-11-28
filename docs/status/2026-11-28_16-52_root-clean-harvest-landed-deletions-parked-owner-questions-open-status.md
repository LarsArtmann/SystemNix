# Root-disk cleanup: harvest landed, deletions parked, owner questions still open (status 2026-11-28 16:52)

**Scope line.** This report covers ONE session thread: the 09:20 owner ask to clean the
95%-full root disk. It has two halves: the morning (09:20 to ~11:38, already reported in
`docs/status/2026-11-28_11-38_root-95pct-clean-rescue-snapshot-pin-removed-78pct-wdt-reset-mid-purge-status.md`,
the "morning report") and the afternoon resume (14:17 to 16:52, this report).

**Verified this afternoon, with the command:**
- boot id `cat /proc/sys/kernel/random/boot_id` = `56ba232e-…` at 14:17, 14:4x and 16:52 (same boot as the 10:46 recovery, no further reset).
- IO PSI `head -1 /proc/pressure/io`: avg60 3.67 at 14:17, 7.23 at 14:4x, **42.08 at 16:52** (storm at report time).
- root fs `df -h /`: 536G used / 154G free / 78% at 14:17, 537G / 154G / 78% at 16:52.
- queue and library edits: `rg -c` for each inserted marker, each = 1; `git show --stat b55244e6b`.
- failed units: `systemctl show` + one journal read (read-only).
- extent sharing of the pre-shrink DB: `filefrag -v` (read-only).

**NOT verified, and why:**
- No deletion, purge, send or prune was run. The owner's three questions are unanswered, so nothing on disk changed beyond reads.
- Whether the pre-shrink DB shares extents with the LIVE monitor365 DB or only with the Nov-16 snapshot: `filefrag` reports "shared" for all 64,055 extents, and that flag does not say with whom. Undetermined.
- The cause of the 10:43:28 watchdog reset: unproven, not re-investigated (owner said do not research other things).
- The three still-failing units' root causes: read their state only. They belong to the parallel desktop-health-check session (`docs/status/2026-11-28_11-29_desktop-health-check-storm-…-status.md`).
- Whether a deploy carries anything: not touched, out of scope.

HEAD at report time: `bbff692f9`. My edits landed in daemon commit `b55244e6b`.

---

## a) FULLY DONE

| # | Item | Proof |
|---|------|-------|
| 1 | Morning: measurement of pins, trash bodies, orphaned caches, btrbk admission history | morning report §a |
| 2 | Morning: `~/.cache/.Trash-1000` emptied (249 entries) | morning report; ~0.3G real |
| 3 | Morning: `.rescue/zz-test-snap` (month-old full `@` snapshot) + `zz-test-delete` deleted inside one `chattr -a` … `+a` window | morning report; `lsattr -d /mnt/btrfs-root/.rescue` = `-----a---` |
| 4 | Morning: `~/pdg-cache` (43G) moved to the lars trash | `ls -d ~/.local/share/Trash/files/pdg-cache` still present at 14:4x |
| 5 | Morning: status report written and committed | 11:38 report, in git |
| 6 | Afternoon: **harvest of the morning report** (deferred at authoring per owner instruction) | daemon commit `b55244e6b` |
| 7 | Afternoon: read-only triage of the four failed units | see b/4 |
| 8 | Afternoon: extent-share probe on the pre-shrink DB | 64,055 of 64,055 extents flagged shared |

Harvest detail (item 6), each marker `rg -c` = 1:
- Ticked "Delete filesystem residue subvols" in `TODO_LIST.md` and `docs/todo/storage.md` (was a 2-minute task open for four weeks while the disk went to 95% twice).
- "QLC-root dead-bytes reclaim batch" in both files: marked half done (pdg-cache trashed, not purged; pre-shrink and archives untouched; still pinned).
- "Quiet-window btrbk unlock" in `TODO_LIST.md`: re-scoped, the "ARMED" state has been false since the Nov-25 reboot, do not relaunch the trigger.
- Owner runbook in `docs/agents/storage.md`: lars trash corrected 91G → 46G (43G of it pdg-cache); `@cache-home/.Trash-1000` marked emptied.
- Lesson added to `docs/agents/storage.md`: one metadata-heavy operation at a time, settle, abort on the first new guard trip, re-pin boot id after an interrupted tool call, `du` is an upper bound on btrfs, no reboot-dependent watcher as a transient unit.
- Two new rows, queue plus library: `.rescue` hygiene check; snapshot pin-age warning.

## b) PARTIALLY DONE

| # | Item | What is there | What is missing |
|---|------|---------------|-----------------|
| 1 | **pdg-cache purge (E2)** | 43G is in `~/.local/share/Trash/files/pdg-cache` | the purge (`chmod -R u+w` + `trash-rm`) was killed by the 10:43:28 reset and not restarted. Owner question 3 |
| 2 | **Disk relief** | 95% → 78%, 40G → 154G free | ~140G of dead bytes stay pinned by `.snapshots/@.20261116T2300`. `btrfs_health_critical` stays on (device fully allocated). Owner question 1 |
| 3 | **Nightly root backup** | diagnosed: refused 12 nights (Nov 17 to 28) by `btrbk-admission` | not fixed. The gate needs 60 min without a guard trip; the guard trips ~427 times a day |
| 4 | Failed units | `crm-alarm-byphone`: recovered on its own (exit 0 at 14:26, boot-order casualty). `hermes-perms-heal`: one timeout at 11:04 (`ExecMainStatus=15`). `inboxclean-sync`: exit 75 on each run (latest 14:26). `service-health-check`: exit 1 (latest 14:31), which is the reporter itself | root causes of the last three: not looked at, other session's lane |
| 5 | Extent-share question | all extents of the pre-shrink DB are shared | shared with the live DB or only with the snapshot: unknown. Decides whether the root trash is worth 39G or nothing |

## c) NOT STARTED (all owner-gated)

| # | Item | Gate |
|---|------|------|
| 1 | E3: `sudo trash` the monitor365 `.pre-shrink` (41.7G, runbook-sanctioned since Nov 12) + empty root trash (38.8G) | question 3 |
| 2 | E4: migrate monitor365 `archives` (16G, 10,440 files) to `/mnt/pool/services/monitor365/archives`, verify, remove local | question 3 |
| 3 | Pin unlock: capped incremental send, or hand-delete of the local Nov-16 snapshot | question 1 |
| 4 | cv-go build cache (`go clean -cache` on its GOCACHE sub-dir only, up to ~45G instant) | question 2 |
| 5 | Owner triage of the mixed `~/.cache` dirs: glac-fleet 25G, m365fix 22G, ds-gate 4.9G, ec-hub 3G | owner |
| 6 | `go-tmp` 15G writer hunt, `crush-flagtest` 9G owner hunt, session-scratch sweep | not touched (would add IO) |
| 7 | Restart the dead ledger walks (inventory2 died at the reset) | not touched |
| 8 | btrbk admission starvation fix (stability `[decision]` row) | owner decision |
| 9 | btrbk-data: `/data` has no backup younger than Nov 16 | owner call |

## d) TOTALLY FUCKED UP

| # | What | Honest accounting |
|---|------|-------------------|
| 1 | **The 10:43:28 watchdog reset.** I stacked three metadata-heavy operations (async snapshot drop + `chmod -R` + mass unlink of ~500k files) plus a `du` walk at IO PSI 35 to 40% | Cause unproven, but I built the conditions and broke the one-heavy-op doctrine. Cost: ~3 min down, one purge half-done, 4 failed units at boot. The kdump capture of this reset is what the parallel session is analysing (`docs/status/2026-11-28_12-15_freeze-66-…`) |
| 2 | **Inconsistent risk handling in the morning.** I asked before the capped send but not before the mass unlink | The less reversible-feeling step got the question; the step that actually hurt the box did not |
| 3 | **The 12-night backup starvation went unnoticed** until the disk was at 95% | The Nov-22 calm trigger was armed as a transient unit, died at the Nov-25 reboot, and its "ARMED" claim sat in the queue for three days. Fixed in the queue today; the backup gap itself is open |
| 4 | **The stray `.rescue/zz-test-snap`** sat a month in the append-only dir, stretching the pin window, while its TODO row was `[ready]` the whole time | Deleted today at 10:36. Queue row ticked today |
| 5 | **My pathspec commit was refused** by the pre-commit `audit-serviceconfig-merge` false positive (`llama-chat.nix:387`, another session's file); the daemon then committed my doc edits as "chore: auto-commit 5 changed file(s) (heuristic)" together with a foreign report and script | Not amended: an amend would absorb the foreign files under my message. Result is in git, message is meaningless |

## e) WHAT WE SHOULD IMPROVE

1. **Heavy-operation discipline as a rule, not a memory.** Encoded today in `docs/agents/storage.md`. Stronger form: a script wrapper that refuses to start a second heavy op while the first is unsettled.
2. **Ask once, for the whole batch.** Three questions have now been open for five hours; every deletion since sits parked. Next time: one message, every irreversible or heavy step, before the first one.
3. **Pin visibility.** The frozen send parent was invisible for 12 days. Row minted (pin-age metric + Gatus).
4. **Reserve-dir hygiene.** Row minted (`.rescue` contains only `@.rescue-*`).
5. **Nothing reboot-dependent as a transient unit.** The calm trigger design was wrong from the start.
6. **Admission gate versus guard cadence is a structural deadlock** (60 trip-free minutes required, a trip every ~3.4 min). Until it is decided, every "pinned until the parent rotates" row is unopenable.
7. **The pre-commit false positive blocks every intentional commit** in this tree right now. It is a foreign row, but it costs attribution on every session.
8. **`filefrag` cannot answer "shared with what".** For pin questions, measure with `btrfs filesystem du` on a settled box, or compare extent maps against the live file.

## f) Up to 50 next things (ranked; first eight are the ones that matter)

| # | Task | Impact | Who |
|---|------|--------|-----|
| 1 | **Answer question 1 (pin unlock)**, then run it | ~140G | owner → agent |
| 2 | Purge pdg-cache as ONE op, behind the calm gate | 43G once unpinned | agent, needs Q3 |
| 3 | E3: trash pre-shrink + empty root trash | up to 39 to 80G once unpinned | agent, needs Q3 |
| 4 | E4: archives → pool (rsync, verify, remove local) | 16G | agent, needs Q3 |
| 5 | **Answer question 2 (cv-go cache)** and run it | up to ~45G instant | owner → agent |
| 6 | **Answer question 3 (continue today or not)** | unblocks 2 to 4 | owner |
| 7 | Decide the btrbk admission fix (trip-independent admission under hard `io.max`, or a starvation slot) | backups, every pinned row | owner → agent |
| 8 | Close the 12-day root backup gap and look at the `/data` gap (btrbk-data, EIO tripwire) | backup safety | owner |
| 9 | Build the pin-age metric + Gatus check | early warning | agent |
| 10 | Build the `.rescue` hygiene check | guard | agent |
| 11 | Triage `inboxclean-sync` exit 75 | service health | owner of that lane |
| 12 | Triage `hermes-perms-heal` timeout | service health | owner of that lane |
| 13 | Fix the `service-health-check` reporter (covered by the desktop-health-check-storm session) | noise | that session |
| 14 | Classify the 10:43:28 reset (kdump pending in the parallel session) | stability | that session |
| 15 | Fix the cv / go-cqrs-lite `go-env.sh` GOCACHE leak at source | stops regrowth | agent |
| 16 | Owner triage: glac-fleet 25G | instant | owner |
| 17 | Owner triage: m365fix 22G | instant | owner |
| 18 | Owner triage: ds-gate 4.9G, ec-hub 3G | instant | owner |
| 19 | `go-tmp` 15G: find the writer, redirect to `/mnt/buildcache/agent-caches` | 15G | agent |
| 20 | `crush-flagtest` 9G: find the owning session | 9G | agent |
| 21 | Session-scratch sweep in `~/.cache` (liveness check, purge >7d idle) | 20 to 25G | agent |
| 22 | Extend `buildcache-agent-cache-gc` patterns (never the owner-triage dirs) | keeps it clean | agent |
| 23 | Projects shadow Phase F (132G, storage.md row) | 132G | owner-gated |
| 24 | `/data/docker` residue (~10 to 15G) owner reclaim | small | owner |
| 25 | `/data/gcs-staging` 24G owner reclaim | 24G (not root) | owner |
| 26 | Heavy-op wrapper script with settle gate | doctrine → code | agent |
| 27 | Heavy-op list in the storage doc → a lint or check for scripts that chain two | prevention | agent |
| 28 | Re-run the inventory2 ledger walk on a calm box | measurement | agent |
| 29 | Re-check the pre-shrink vs live-DB extent sharing after the pin rotates | measurement | agent |
| 30 | Retire the `~/.cache/btrbk-calm-trigger/trigger.sh` scratch file so nobody relaunches it | hygiene | agent |
| 31 | Fix the `audit-serviceconfig-merge` false positive (open row exists) | attribution | agent |
| 32 | Change daemon heuristic commits' handling: when a hook refuses a proper commit, the daemon lands a message-less one. Owner call whether the daemon should re-run the message | attribution | owner |
| 33 | `btrfs_health_critical` clears by itself once the pin rotates; confirm the alert does | monitoring | agent |
| 34 | Verify `btrbk-root` runs clean on the first night after the pin rotates | backup | agent |
| 35 | Consider `snapshot_preserve` semantics on the root instance (the force-preserved latest-common parent is what froze) | design | owner → agent |

(35 items. 36 to 50 deliberately not listed: everything else in this thread maps onto rows 1 to 35 or onto existing stability rows.)

## g) Questions I cannot answer myself

1. **Pin unlock.** ~140G wait on the Nov-16 snapshot. (A) capped incremental root send now, bypassing the admission gate that refused 12 nights (my recommendation; also closes the 12-day backup gap). (B) hand-delete the local Nov-16 snapshot (instant, zero IO; next send becomes a full ~570G). (C) keep waiting. Which one?
2. **cv-go (54G).** May I `go clean -cache` on its build cache only (the `pipeline.sqlite` under it is left alone), or must the non-cache payloads move out first?
3. **Continue today?** Purge pdg-cache, trash the pre-shrink, migrate the archives, one at a time behind a 15-minute no-trip gate, or leave the disk alone until the reset is classified?

---

## Harvest mapping

The morning report's harvest is DONE (section a/6). This report's section (f) is
**deliberately not harvested at authoring time**, because the owner instructed: report, then
wait. Mapping so the next pass is mechanical:
- Rows 1 to 8, 15 to 25, 28, 29, 33 to 35 map to rows that already exist (reclaim batch, calm-trigger re-scope, stability `[decision]`, storage.md owner-triage and Phase F rows, the morning report's f/10 to f/14, f/20, f/21).
- Rows 9, 10, 30 are covered by the two rows minted this afternoon (`.rescue` hygiene, pin age).
- Rows 11 to 14 belong to the parallel desktop-health-check and freeze-66 sessions.
- Rows 26, 27, 31, 32 are NEW candidates (heavy-op wrapper, heavy-op lint already exists as an open row for 31, daemon message handling). Session budget: 2 of 3 new rows used.
