# Monitor365 Scan-Storm Attribution — Session Status (Part 2)

**Reported:** 2026-10-26 21:07 CET · **Instance:** same crush session as the 20-40 report (continuation: the owner flagged the ~430 GB IO bursts)
**Scope:** THIS interval only — 20:40 → 21:07, the IO-burst hunt. Part 1 (lock-float repair → gen-953 deploy) lives in `docs/status/2026-10-26_20-40_lock-float-repair-gen953-deploy-status.md`; its §f menu still stands.
**HEAD at report time:** `9ce2fb91f` · **Deployed:** gen-953 (unchanged this interval — no deploys, no config edits; one docs commit)

## The answer, up front

The ~430 GB evening bursts are **`monitor365-server.service` full-scanning its own DuckDB, which lives on the QLC root disk**. Verified LIVE: a 30-second cgroup io.stat delta showed monitor365-server reading **2,532 MB (~84 MB/s) while every other unit on the box read ≈ 0**, on device `259:3` = nvme0n1 (QLC root — NOT the pool, NOT the hot tier; `/mnt/hot` is nvme1n1). While scanning, the service starves its own connection pool: 32× `pool acquire failed: timed out` in 45 min, API 500s on `/api/v1/events/upload/binary` + `/devices/register`, agent SSE drops, and 18× `Binder Error: Table "e" does not have a column named "gen_app"` (schema drift between a dashboard MV-refresh query and the events table). The waves (PSI 85% → 14% observed live) ride a ~30-min cycle — exactly the guard's trip rhythm (trips #4400/#4401/#4402). The pre-deploy trips (17:47/18:08) hit the PRE-activation instance → the loop **survives restarts and is days old**, matching the 2026-10-25 monitor365 sick-list (COPY FROM DATABASE OOM, WAL-delete desync, 65/65 index rebuild).

**Ruled out with evidence:** pbx-backup-pull (16.4 s total, 347.5 MB written, journal "ok"), monitor365 backup/export/sync services (inactive), schema-migrate (15 s, clean). **Not executed:** a restart — it clears the wedged pool only until the next scan wave; owner call (see §g Q1).

## Timeline (compact)

| Time | Event |
| --- | --- |
| 20:41 | Hunt starts. PSI avg10 **85.4%** — burst LIVE. First diskstats awk produced garbage (field misalignment) — discarded unquoted. |
| 20:43 | journalctl sweep: `pbx-backup-pull` "Started 18:15" → suspect. |
| 20:44 | pbx-backup-pull EXONERATED (16.4 s, 347.5 MB, "ok" in journal). |
| 20:46 | First cgroup sampler (shell) botched its own snapshot sequencing → abandoned. |
| 20:47 | Python 30s delta: **monitor365-server 2,532 MB read, sole mover**. |
| 20:49 | Journal: pool starvation ×32, API 500s, SSE drops, `bg.stale_sweep` fallbacks. |
| 20:50 | Companion services all idle; schema-migrate clean (19:58, 15 s). gen_app Binder Error ×18. |
| 20:52 | Device pinned: `259:3` = nvme0n1 = QLC root (major:minor mapped; /mnt/hot cross-checked on nvme1n1). |
| 20:55 | Root-gated probes (/proc/PID/io, fd) permission-denied — cgroup io.stat remains the working channel. Second clean 30s delta: 1,969 MB read, write ≈ 0 — confirms sustained pure-read scan. |
| 20:57 | "Total since activation" awk printed **0 GB — my field bug again**, flagged as such, not quoted. PSI wave passed (85% → 14%). |
| 21:00 | `rg -rn` typed again — hook BLOCKED it (the hook's message: third strike of this exact trap on this host). |
| 21:04 | Row queued: services.md + TODO_LIST twin → commit `9ce2fb91f`. No restart. |

---

## a) FULLY DONE

1. **Burst source attributed to `monitor365-server.service`** — live 30s cgroup-io.stat delta: 2,532 MB read, all other units ≈ 0; corroborated by a second delta (1,969 MB) and by the guard's own system.slice attribution across trips #4400–#4402. Evidence: this transcript, cgroup io.stat, guard journal.
2. **Device + disk pinned** — cgroup io.stat per-device line `259:3`; mapped via /proc/diskstats to nvme0n1 = QLC root; `/mnt/hot` cross-checked to nvme1n1 via df (the nvme0/1 mapping flips across boots — resolved fresh, not trusted from AGENTS.md).
3. **pbx-backup-pull exonerated** — 16.4 s runtime, 409.7 M peak mem, 347.5 M written, "ok → /mnt/pool/backups/pbx/2026-10-26T171507Z" in its journal. (It LOOKED guilty: "Started 18:15" inside the 18:08→19:22 trip window.)
4. **All monitor365 companion services ruled out** — backup-export/backup/sync inactive, schema-migrate exited clean in 15 s (19:58). The reader is INSIDE the server process (DuckDB is embedded, single-file).
5. **Self-starvation quantified** — 32× pool-acquire timeouts + API 500s (upload/register) + agent SSE drop + `bg.stale_sweep` fixed-timeout fallbacks, all in a 45-min journal window, concurrent with the scan.
6. **Schema-drift symptom found** — `Binder Error: Table "e" does not have a column named "gen_app"` ×18/45 min, fired by `dashboard_mv_refresh` right after each successful `count=1` incremental refresh.
7. **Pre-deploy persistence established** — trips #4400/#4401 (17:47/18:08) pre-date the 19:55 activation → the scan loop is not deploy-caused and survives restarts; consistent with the 2026-10-25 sick-list. This also retroactively clears tonight's deploy as a suspect.
8. **Follow-up row queued and committed** — services.md + TODO_LIST twin, `9ce2fb91f`, TODO-gate-clean on the FIRST attempt this time.
9. **No risky action on a production control plane** — restart explicitly withheld pending owner decision (§g Q1); mitigation path documented in the row.

## b) PARTIALLY DONE

1. **Query-level attribution** — Works: the scanning is inside monitor365-server, read-only (~0 write), in waves, concurrent with gen_app binder errors. Open: WHICH query scans (the *successful* `dashboard_mv_refresh count=1` leg, `bg.stale_sweep`/retention over the `max_events_per_day=1B` events table, or something else) — not identified. Blocker: DuckDB file is root-locked (single-writer + perms; a read-only CLI probe was considered and rejected — the server holds the write lock), process /proc internals root-gated. Fix locus is the monitor365 repo regardless. Effort remaining: M (upstream session with a sudo ticket).
2. **The monitor365 `/health` row from `6491fd32a` needs reframing** — tonight's triage shows the smoke FAIL was NOT a settle transient: `/health` 308 + the pool starvation are the same sick service. The two rows (/health repoint vs scan-storm) are now two views of one incident and should be merged/linked when triaged — currently a TODO-system split-brain risk (see §e.3). Effort: S.
3. **Mitigation** — restart identified as temporary-only (scan loop re-enters); NOT executed. Effort: S once decided.
4. **Carried from Part 1, still open:** fastflowlm "started ≠ serving" verification (now survived two report cycles — see §d.5); float-register fixes; the 17:44 stale-eval anomaly.

## c) NOT STARTED

(Discovered this interval, untouched — with reason.)

1. **Identify the exact scanning query** (monitor365 upstream session; needs the repo + a root ticket for the live DB) — not started: upstream repo work beyond tonight's scope; the row owns it.
2. **Fix the gen_app schema drift** (migration vs dashboard/saved-view definition — see §g Q2) — not started: same upstream session.
3. **Relocate the DuckDB off the QLC root** (hot-tier subvol on the Samsung per the journal/caddy-logs pattern, or pool) — not started: architecture + storage-doctrine decision, owner's call (§g Q3); also needs the PSI-gated migrate-script pass.
4. **`scripts/io-attrib.sh` productization** — the python sampler (cgroup delta → top units → device map) worked perfectly twice; it exists only in this transcript. Not started: tooling work; strong harvest candidate (§e.1).
5. **Guard-trip suppression/context while the scan loop persists** — every ~30-min trip sheds sockets (fastflowlm/inboxclean paid tonight); until upstream fixes, responders need a note that trips #44xx-class are likely this scan. Not started: could be a SigNoz annotation, a gatus note, or a comment on the guard unit.
6. **Carried from Part 1 §c:** upstream got-hash pastes (15+ tools), FOD download-scope fix, float-register pipefix+marker, tmp subvol provisioning, pre-existing failed-unit triage (pocket-id-provision, buildcache-gc, service-health-check, ci-watchdog), shim-drop bookkeeping — all untouched, all still queued in their domain files.

## d) TOTALLY FUCKED UP

(Radical honesty — my mistakes in THIS interval.)

1. **Two awk field-mapping failures in 15 minutes** — the diskstats delta produced negative write_MB and absurd util_pct (paste/field misalignment), and the "total since activation" awk printed **0 GB** (wrong field). Both were CAUGHT (numbers absurd / obviously wrong) — but caught REACTIVELY, by absurdity, not proactively by the "verify one known value through the same pipeline before quoting" rule. The host rule (2026-10-26, quote-scrutiny) exists precisely because of yesterday-me; today-me re-committed the class twice in one hunt. Mitigation that actually held: nothing garbage entered a report or a row — but the process cost is real and this is my single worst recurring failure mode.
2. **`rg -rn` typed AGAIN — the hook's own message says THIRD STRIKE of this exact trap on this host.** The 2026-10-23 rule (and tonight's hook) exists; under cognitive load I re-typed the muscle-memory form. The hook saved the output; the round was still wasted. This needs a personal antidote (alias/habit: never `rg -r` unless REPLACE is truly intended), not another rule.
3. **First cgroup sampler was broken shell** — overwrote `/tmp/io1` before diffing (sequencing bug), in violation of both basic pipeline hygiene and the /tmp-volatility rule (intermediates belong in `~/.cache/<topic>/`). Abandoned for a clean python block. Cost: one wasted round.
4. **Root-gated probes attempted without pre-checking** — `/proc/PID/io` and fd on a foreign-UID process are permission-denied (ptrace/ownership); I should have gone straight to the cgroup io.stat, which I already knew was readable (I'd used it 8 minutes earlier). Minor, but it's probe-churn the playbook could omit.
5. **Part 1's monitor365 framing was too optimistic** — I logged the smoke FAIL as "stale-looking" and queued `/health` as an upstream route move. This interval proved the FAIL was a live symptom of the starving service (the "re-probe before triaging" lesson cuts BOTH ways: re-probing confirmed the UI worked AND that the deeper breakage persisted). The queued row is factually correct but incomplete — it needs the scan-storm link (→ §b.2).
6. **Playbook inefficiency, not error** — I chased the journal suspect (pbx-backup-pull) before running the cgroup delta that solved the case in one step. The cgroup delta should have been step 1: it's agent-readable, root-free, and names the unit directly. Cost: ~2 rounds.

## e) WHAT WE SHOULD IMPROVE

1. **Productize the IO attribution sampler** — the python block (cgroup io.stat delta → top units → device major:minor → map via /proc/diskstats) is now proven twice tonight and is the third session running to do ad-hoc IO attribution by hand (2026-10-25 §d.2's junk awk; tonight's two bugs). That crosses the docs/feedback-loop threshold: same improvement in 2+ reports → make the tool. Concrete: `scripts/io-attrib.sh [window_s]` printing top-10 units + device map + PSI snapshot. (→ §f)
2. **A 4-step IO-hunt playbook for the ops doc** — (1) PSI snapshot, (2) per-unit cgroup delta (NOT journal-guessing, NOT per-process — root-gated), (3) device from io.stat major:minor, (4) unit journal for the story. Tonight this path is 4 probes; the path I took was 8. Belongs next to the live-probe set in AGENTS.md or docs/agents/stability.md. (→ §f)
3. **Link related TODO rows at queueing time** — monitor365 `/health` (6491fd32a) and the scan-storm row (9ce2fb91f) are one incident in two rows; the TODO system has no cross-reference convention, so drift between them is now possible. Either one row per incident or a "See:" pointer convention. (→ §f)
4. **Smoke-FAIL disposition rule refined** — "re-probe before triaging a FAIL that quotes a just-restarted unit" stays, but add: a re-probe that CONFIRMS the failure upgrades it to live-incident; it does not downgrade to transient. Tonight the confirm-path signal was the most valuable line in the whole hunt.
5. **Open-questions ledger for long sessions** — fastflowlm "started ≠ serving" has now rolled through two reports unverified. A session-long checklist of asserted-but-unverified claims would stop items silently surviving report cycles. (Cheap: a section in the session's scratch notes; harvested or closed at report time.)
6. **The awk/quote-scrutiny antidote must be mechanical, not memorized** — two reactive catches in one night is the pattern repeating. The io-attrib script removes the MOST common pipeline (cgroup deltas) from hand-rolled awk entirely; the diskstats sampler should be part of it too. Rules don't survive cognitive load; tools do.

## f) NEXT THINGS (delta list + carried top items)

(Harvest status: this interval's ONE direct follow-up — the monitor365 scan-storm row — was harvested at authoring time, `9ce2fb91f`, per the self-harvest rule. The rest is deliberately a menu: Part 1's 50-item table still stands in `docs/status/2026-10-26_20-40_*`; this table is the re-ranked union with tonight's new findings promoted. Say the word and I harvest any subset.)

| # | Task | Impact | Effort | Category | Provenance |
| --- | --- | --- | --- | --- | --- |
| 1 | Identify monitor365's exact scanning query (MV-refresh leg vs stale_sweep/retention over the 1B-events table) in an upstream session with a sudo ticket | High | M | Bug | NEW tonight |
| 2 | Fix the gen_app schema drift (migration vs dashboard/saved-view definition — §g Q2 decides which) | High | S–M | Bug | NEW tonight |
| 3 | Decide + execute DuckDB relocation off the QLC root (hot-tier subvol on Samsung or pool; PSI-gated migrate pass) | High | M–L | Feature | NEW tonight |
| 4 | Restart monitor365-server to clear the wedged pool (temporary — loop re-enters; pair with #1) | Medium | S | Bug | NEW tonight |
| 5 | Write `scripts/io-attrib.sh` (cgroup-delta sampler + device map + PSI; kill the hand-rolled awk class) | High | S | Quality | NEW tonight |
| 6 | Add the 4-step IO-hunt playbook to the ops docs | Medium | S | Documentation | NEW tonight |
| 7 | Merge/link the two monitor365 rows (/health 308 + scan-storm) into one incident view | Medium | S | Documentation | NEW tonight |
| 8 | Annotate the guard/SigNoz so responders know trips of the #44xx class are likely this scan until #1 lands | Medium | S | Quality | NEW tonight |
| 9 | Verify fastflowlm actually serves (started ≠ serving; carried twice) | Medium | S | Bug | Carried |
| 10 | Identify the ~430 GB burst confirmation over a FULL wave (capture one complete 30-min cycle end-to-end: onset → trip → decay) — feeds the upstream bug report | Medium | S | Bug | NEW tonight |
| 11 | Fix float-register's silent green-proof death (`drifted=` `\|\| true` + selftest) ✅ harvested 847fd0388 | High | S | Bug | Carried |
| 12 | float-register proof-marker (lock-fingerprint stamp; registry==lock ≠ proven) | High | M | Quality | Carried |
| 13 | Upstream FOD download-scope fix (go-taskqueue + branching-flow), then lift pin-backs ✅ harvested 6491fd32a | High | M | Bug | Carried |
| 14 | Repoint monitor365 `/health` consumers off the 308 route (watchdog SERVER_HEALTH + gatus) ✅ harvested 6491fd32a — merge with #7 at triage | Medium | S | Bug | Carried |
| 15 | `scripts/vendor-sweep-list.sh <proof-log>` (mechanize the awk extraction + six-surface sweep) | High | S | Quality | Carried |
| 16 | Root-cause the 17:44 stale-eval anomaly (drv paths identical despite edited shims) | High | M | Quality | Carried |
| 17 | Provision `/mnt/hot/users/lars/tmp` subvol (fixes home-lars-tmp.mount + the D-state phantom class) | Medium | M | Bug | Carried |
| 18 | Diagnose pocket-id-provision exit-1 (pre-existing, 216 ms, OnFailure fired) | Medium | S | Bug | Carried |
| 19 | Diagnose buildcache-gc.service failure (pre-existing) | Medium | S | Bug | Carried |
| 20 | Upstream paste batch: all 15+ shimmed tools' got-hashes (cv, health-hub, crush-daily, renamer, mr-sync, pdd, overview, library-policy, buildflow, discordsync, erraudit, go-auto-upgrade, go-humanize-linter, project-meta, samber-linter, PMA) — one sweep session ends the treadmill | Medium | M | Cleanup | Carried |
| 21 | erraudit follower-divergence systematic fix (nixpkgs-unstable follow pattern; FRAGILE note fired twice) | Medium | M | Quality | Carried |
| 22 | Reconcile pre-deploy (7) vs post-activation (3) failed-unit sets — verify github-auto-assign / opencloud / inboxclean-sync actually healed | Low | S | Quality | Carried |
| 23 | inboxclean-sync + opencloud recovery confirmation (guard-shed class tonight) | Medium | S | Bug | Carried |
| 24 | service-health-check + ci-watchdog triage (one IS the notifier — its failure masks others) | Medium | S | Bug | Carried |
| 25 | Confirm home-lars-tmp.automount fails fast-loud without a fresh corpse pile on access | Low | S | Bug | Carried |
| 26 | Log pressure-override + gate-abort events persistently from deploy.sh | Low | S | Quality | Carried |
| 27 | CONTRIBUTING cheat sheet for the TODO gate (title-identity, wait-words, date-regex) | Low | S | Documentation | Carried |
| 28 | Pre-commit leg: vendorHash literal changes require dated evidence comments | Medium | M | Quality | Carried |
| 29 | AGENTS.md live-probe set: add LoadUnit-first unit probing + /dev/tcp plain-HTTP | Low | S | Documentation | Carried |
| 30 | Forensics on the 18:04:05 flake.lock mtime touch (content unchanged; toucher unknown) | Low | S | Quality | Carried |
| 31 | Next real `nix flake update && deploy` must ride float-register end-to-end (acceptance) | Medium | S | Quality | Carried |
| 32 | Root-fs watch: 50 G free and falling | Medium | S | Cleanup | Carried |
| 33 | Verify nix-build-cleanup cleared the 4 stale sandboxes | Low | S | Cleanup | Carried |
| 34 | Pre-commit hook idea: float message required when expected-locks.nix is staged | Low | S | Quality | Carried |
| 35 | Fold tonight's bursts into the 2026-10-25_17-45 junk-IO row (same instrument class, fresh evidence) | Low | S | Documentation | Carried |
| 36 | CHANGELOG entry for gen-953 (19-hash repair, 2 pin-backs, float-register bug) | Medium | S | Documentation | Carried |
| 37 | Batch-analyze shim-ledger drop economics (one upstream sweep vs per-float re-stale tax) | Medium | S | Cleanup | Carried |
| 38 | Bump the post-deploy-check "split not-listening from non-loopback" row (third stale-FAIL instance tonight) | Medium | S | Quality | Carried |
| 39 | Add session open-questions ledger convention (§e.5) to the session discipline docs | Low | S | Documentation | NEW tonight |
| 40 | TODO-system cross-reference convention ("See:" pointers between rows of one incident) — prevents the split-brain class §e.3 found | Low | S | Quality | NEW tonight |

(40 rows; the Part 1 table's remaining rows — 50-item menu minus the 14 re-listed here — remain standing in the 20-40 report.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Restart monitor365-server now, or leave it for the upstream fix session?** A restart clears the wedged pool and the 500s for a while, but the scan loop re-enters and the restart itself is a control-plane blip (dashboards, agent uploads, SSE). I can't weigh your tolerance for continued degradation vs a deliberate blip — and it's your actively-developed service.
2. **Is `gen_app` a column a dashboard/saved-view definition references (user-created content) or upstream schema history?** I cannot open the DuckDB (root-locked, single-writer). The answer decides the fix path: repair a dashboard definition vs chase an upstream migration — very different sessions.
3. **Do you want the DuckDB relocated off the QLC root as part of the fix?** The hot-tier subvol pattern (Samsung, like journal/caddy-logs) fits a high-churn DB and would delete the burst's teeth permanently — but it's a storage-doctrine decision (nodatacow, snapshot exclusion) plus a PSI-gated migrate pass, and monitor365 is mid-redesign upstream (2026-10-25 backup rework). Sequencing is yours.

---

*Self-harvest record (AGENTS.md rule): this interval's single direct follow-up — the monitor365 scan-storm triage row — was queued at authoring time, BEFORE this report (`9ce2fb91f`: services.md + TODO_LIST twin). The remaining §f rows are deliberately not harvested: Part 1's harvested set (847fd0388, 6491fd32a) already covers rows 11–14, the rest is a re-ranked menu awaiting owner prioritization (user instruction: report then WAIT); bulk-queueing a 40-row brainstorm violates the docs-health HARVEST routing anti-pattern.*

*Format note: `.md` per the user's explicit path demand (status-report skill is HTML-canonical; override honored, not propagated). Cross-reference: Part 1 = `docs/status/2026-10-26_20-40_lock-float-repair-gen953-deploy-status.md`.*
