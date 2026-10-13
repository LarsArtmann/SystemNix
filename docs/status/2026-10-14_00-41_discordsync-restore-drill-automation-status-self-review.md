# DiscordSync restore-drill automation: continuation session — status + brutal self-review

**Date:** 2026-10-14 00:41 CEST (work ran 2026-10-13 22:5x → 2026-10-14 00:4x)
**Session scope:** resumed from the 22:36 handoff awaiting owner answers; executed the non-gated next steps — paid the owed lints, trashed the leftover clone, re-verified gates and live state, implemented the weekly restore-drill end-to-end (script + unit + timer + fixture + docs), and re-synced every surface.
**Explicitly NOT done (owner-gated):** the deploy itself, Turso plan, Litestream trade. All three questions remain unanswered.

---

## §0 Verdict in one line

Closed every non-gated handoff item: owed lints clean, clone trashed, gates confirmed UNANSWERED, and the weekly restore-drill landed eval-only with an 8-case fixture PASS and a full `nix flake check --no-build` green — while discovering two real design facts (the dump is a gzipped BINARY db, not SQL; `created_at` is a Go time.Time string that breaks naive `unixepoch()` parsing), one new blind spot in my own alerting design (a dead drill timer is silent under the event-alert pattern — queued), and two of my own bugs caught by my own gates (a same-attrset duplicate-option eval error, a vacuous fixture truncation case).

---

## §a FULLY DONE

1. **Owed standalone lints on `discordsync.nix`** (prior report §d.1): alejandra `0 changed`, statix zero findings. Via surgical single-file `nix fmt`/`statix`, NOT repo-wide BuildFlow — a repo-wide format run would have rewritten the shared tree mid-storm with a parallel session active (BuildFlow loaded first; deviation recorded in §e.6). Prior report §d.1 CLOSED.
2. **`/tmp/discordsync-src` trashed** (85M): prior report §d.2 CLOSED (with a verb nitpick — see §d.7).
3. **Gate + live-state verification**: HEAD advanced only by daemon sweeps of my own work + one foreign parallel-session commit; live timer still renders the OLD single `03:45` window (hardening undeployed); the ten 0-byte corpses + two good dumps reconfirmed in `/mnt/pool/backups/discordsync`; journal shows no backup runs since noon; the 3 owner questions are UNANSWERED — all gated items held.
4. **Weekly restore-drill automation, end-to-end** (prior report §c.1 / storage.md row 190):
   - `scripts/discordsync-restore-drill.sh` (110 lines): newest `discordsync-db-*.sql.gz` → tmpfs gunzip → `PRAGMA integrity_check` → `messages`/`events`/`attachments` present AND non-empty → newest-message age ≤ 72h budget; env-overridable fixture hooks (`DRILL_DUMP_DIR`, `DRILL_MAX_MESSAGE_AGE_HOURS`); `bash -n` OK, shellcheck rc=0.
   - Unit + timer in `modules/nixos/services/discordsync.nix`: `discordsync-db-restore-drill` oneshot (User=discordsync, harden 1G, ioTier.background, TimeoutStartSec 15min, `wants` the backup unit so a repaired leg gets one more dump attempt first) + timer `Sun *-*-* 08:00:00` (past the 03:45 dump AND both catch-up windows) + `RequiresMountsFor` the backup dir; rendered evals verified (OnCalendar, ExecStart store path, merged monitored list).
   - System-health wiring: `extraMonitoredServices` combined definition carrying BOTH `discordsync-immich-verify` and `discordsync-db-restore-drill`.
   - Fixture: `checks.x86_64-linux.discordsync-restore-drill-fixture` — **8 cases PASS** (real sqlite3/gzip): happy-newest-of-two, torn gz, valid-gz-but-not-sqlite, 0-byte, no-dump, stale-vs-1h-budget, missing table, empty table, + post-run scratch cleanup. The dump is a GZIPPED BINARY sqlite db (`.backup` output — the `.sql.gz` suffix is historical; proven by the binary-file grep), so every fixture dump is built by importing rows through the real CLI.
   - Full-gate: `nix flake check --no-build` **all checks passed** (5m14s; the aarch64-darwin omission warning is the documented default).
5. **Evidence probes on the real 10-01 dump** (restored to tmpfs, then removed): tables `messages`/`events`/`attachments` confirmed; counts 43,617 / 68,020 / 5,474 match the manual drill exactly; `MAX(created_at)` = `2026-10-01 02:26:08.552999973 +0200 CEST` — a Go `time.Time` string that `unixepoch()` parses to NULL. The drill therefore parses `substr(created_at, 1, 19)`. Both facts are documented in the script, runbook, and queue rows.
6. **Docs, no drift**: TODO_LIST drill row → `[watch]` first-live-run row; the dump-verify row regained the **restic app-dumps pickup leg** its 10-13 rewrite had dropped (prior report §f.7 CLOSED); storage.md row 190 LANDED status; storage.md decision rows added: **VACUUM INTO vs .backup** (prior §c.3 missed-queue-item CLOSED) and **sqlite3_rsync warm standby** (prior §c.4 CLOSED); `docs/services/discordsync.md` runbook extended with the drill's failure gates + the timestamp trap. `scripts/check-todo-system.sh`: structure clean.
7. **Commits**: `3bcb6297` — the drill feature, daemon-swept then amended into a properly-messaged commit (pre-commit hook green; author identity resolved, no Unknown Author); `87212723` — the docs sync, same treatment. The foreign `06362509` (parallel session's status report doc) was verified foreign and left untouched.
8. **Self-caught hygiene fixes before commit**: 11 em dashes removed from the new script (convention violation); 3 wrong `2026-10-14` comment dates corrected to `2026-10-13` (the work date).

## §b PARTIALLY DONE

1. **The P0 itself (the 12-day RPO hole)** — still open, and by tonight's 03:45 it becomes 13 nights. Everything landed across both sessions (reschedule, quiet-gate, catch-up windows, quick_check gate, cleanup, drill) is PREPARATION; zero real-world effect until a deploy. Blocker: owner question 3 (deploy timing) + an ongoing IO storm (PSI some avg60 ~57% at session start, still elevated at 23:0x). Effort to finish: S (one `nix run .#deploy` at a quiescent window) + the post-deploy watch.
2. **The drill is fixture-proven, not live-proven** — never executed on the host. First live run = first Sunday 08:00 post-deploy (or a manual `systemctl start`; sudo is banned in agent shells). Two live-only behaviors to watch: (a) the `wants` edge fires one backup ATTEMPT before the drill when the leg is broken, so the 08:00 run can take up to the backup's 60min budget first; (b) while the leg stays broken the drill FAILS weekly BY DESIGN — the page is the honest RPO-hole signal, not a drill bug. Effort: S.
3. **Stopped-timer blind spot of my own alerting design** — OnFailure + system-health see failed RUNS; a never-firing timer is silent. Discovered during this report's self-review, self-harvested at authoring time into a `[ready]` row (three-numbers collector: backup age / drill age / lag). Not built. Effort: M.
4. **Restic offsite leg still unverified** (carried from prior §f.45): "app-dumps repo ships dumps offsite" is asserted from runbook text; the repo's remote leg has never been checked. Effort: M.
5. **History cosmetics**: the feature spans two heuristic daemon commits (`ca115110` script, `a3797740` module+fixture) whose messages remain "auto-commit (heuristic)" — only the TIP was amendable (the house no-reset rule + a foreign commit below block a deeper squash). Content is verified; only the messages are ugly.
6. **Multi-agent churn continued**: a NEW parallel session landed mid-report (`03d72f61`, a properly-messaged boot-evidence-pull script) and holds an uncommitted 1-line TODO_LIST edit I did not author — flagged per shared-tree discipline, untouched.

## §c NOT STARTED

1. **Turso plan execution** (upgrade → cloud mirror auto-resumes; or local-only → drop TURSO_* + the deliberately-red gatus check) — blocked on owner question 2. Still wanted: it decides whether the nightly dump stays the ONLY backup.
2. **Litestream v0.5.17 enablement** — blocked on owner question 3 (destination trade: pool-file vs B2/S3 vs skip). nixpkgs module exists; the local drill was executed upstream-side on 10-13.
3. **Silent lock-holder identification** (io.prom write counters + server journal at the failure second) — gated on the next failure window, which needs the deploy (windows) or the next 03:45. Backfill hypothesis still untested.
4. **Catch-up windows for the OTHER dump legs** (bank-sync, browser-history, paperless, miniflux, forgejo) — storage.md row 189; the discordsync leg is closed, five legs remain.
5. **VACUUM INTO / sqlite3_rsync decision analysis** — rows queued this session; no work done (owner-gated decisions).
6. **Three-numbers collector** — queued (§b.3), not started.
7. **Fleet sweep for other drill-less "only backup" legs** (browser-history day-1 dump is the sibling) — prior §f.49, never started.
8. **`docs/services/discordsync.md`-adjacent AGENTS.md update** — deliberately deferred until the first successful post-fix dump (2026-09-18 premature-success-claim lesson).

## §d TOTALLY FUCKED UP (honest; all caught by my own gates, none escaped)

1. **Wrote a same-attrset duplicate definition of `services.system-health.extraMonitoredServices`** — I added a second assignment in the same `config` attrset literal, assuming the module system would merge the two list definitions. It is a RAW eval error ("attribute already defined"), not a module-merge case: had it not been caught, EVERY host eval would have died. Caught by `nix fmt` (which evals the flake) before any commit. Root cause: I pattern-matched on cross-module list merging and did not grep the module for an existing assignment of the option I was extending. Mitigation: combined `lib.mkAfter` definition with `lib.optionals` per feature flag; lesson in §e.1.
2. **Fixture case 2 was vacuous on first build**: `head -c 1000` to simulate a torn gz — but the fixture dump gzips to well under 1000 bytes, so the "truncation" copied the file whole, and the torn-gz case passed as a second happy path (`FAIL torn: rc=0 want 1`). The HARNESS caught it (the fixture failed its first build — the gate worked), but the root cause was me writing a negative case incapable of failing. Fixed with a size-proportional cut (`head -c $((sz / 2))`).
3. **Two intermediate heuristic commits keep heuristic messages** (`ca115110`, `a3797740`) — see §b.5. Damage: history readability only. The no-reset rule plus the foreign commit underneath make this the correct trade; noting it because "the feature is properly committed" is only true for the tip.
4. **Three wrong dates in comments** (`2026-10-14` where the work happened `2026-10-13`) — caught in self-review after the commit, fixed in the docs commit. Root cause: writing dates from the handoff's "today" instead of `date`.
5. **11 em dashes in the new script** — violated the no-em-dash source convention on first write; caught by my own grep pass and rewritten to colons before commit. Root cause: the surrounding repo style uses them pervasively and I drifted with it.
6. **Two wasted edit attempts against the mod-time guard** — after `nix fmt` rewrote the file, I tried to edit on stale read-state (and used bash `sed` views, which do not refresh the edit tool's guard). Root cause: knowing the rule, not applying it under flow. Cost: two tool calls.
7. **`trash-put` of the 85M tmpfs clone wrote 85M onto the QLC root** mid-storm — the /tmp doctrine says plain deletion is the honest verb for tmpfs artifacts (trash under /tmp is reboot-equivalent). I followed the handoff's literal instruction over the doctrine. Harmless (data recoverable either way), but it was avoidable write IO on the storming disk.

## §e WHAT WE SHOULD IMPROVE

1. **Grep-before-add for option assignments**: before adding ANY `services.X.Y = …` line to a module, grep that module for existing assignments of the same option path — same-attrset duplicates are eval-fatal, and `mkMerge`/`mkAfter` combination is the fix. This is the config-wiring twin of the split-brain rule; it generalizes (candidate for `docs/CONTRIBUTING.md` module checklist).
2. **Negative fixture cases must be built to be capable of failing**: any fixture that simulates corruption must derive its destruction from the actual artifact size (or be anchor-guarded like the borg drill's mutation-negative). Doctrine precedent exists; this session is the second proof. Make "prove the negative case can fail" a standing step when authoring fixtures.
3. **Daemon-sweep verification after every long build step**: the daemon fired 3× during this session (22:57 foreign doc, 23:07 script, 23:09 module+fixture, 23:12 fixes, 23:16 docs). Amend-at-end worked, but checking `git log` between steps (not only at the end) would have caught the 23:09 sweep before I based edits on assumed working-tree state. The 00:36 foreign TODO_LIST touch reinforces it: content-pin before EVERY edit block, not once per session.
4. **Formatter runs invalidate edit read-state**: after any `nix fmt`, `view` the file before the next edit — bash-side reads don't refresh the guard. Trivial discipline, real call-cost.
5. **/tmp cleanup verb**: plain `rm` for tmpfs artifacts (doctrine), `trash` only for disk-backed data. The handoff-instruction-vs-doctrine conflict should resolve toward doctrine.
6. **Record the BuildFlow surgical-run pattern** (candidate for `docs/agents/shell-devtools.md` or CONTRIBUTING): repo-wide BuildFlow runs = quiescent-moment gate only; single-file `nix fmt <path>` / `statix check <file>` = the shared-tree default while storms or parallel sessions are active. This session's deviation was reasoned and safe; writing it down stops the next session from either blanket-running repo-wide format or skipping lints entirely.
7. **Prior lesson re-validated, keep applying**: "newest artifact missing is a failure signal on sight" — the corpse listing was re-read with that lens this session and matched expectations exactly; the pattern is earning its keep.
8. **Self-harvest rule worked under time pressure**: the stopped-timer gap went report-observation → `[ready]` row + queue one-liner in the same authoring pass. Keep the rule at authoring time, never deferred to a later pass.

## §f UP TO 50 THINGS TO GET DONE NEXT

Ranked by impact; surface status noted (row = already on a TODO/library surface; new rows were self-harvested at authoring time).

| # | Task | Impact | Effort | Category | Surface |
|---|------|--------|--------|----------|---------|
| 1 | Deploy hardening + drill at the first PSI-quiet window (`some avg60 < ~20%`); pre-deploy §11 FOD preview first | Critical | S | Bug (RPO hole) | rows 937/943; **owner-gated (Q1)** |
| 2 | Post-deploy: watch 03:45 → 05:15 → 06:45; confirm fresh non-zero dump + `backup_healthy{discordsync} 1` + **restic app-dumps pickup** (leg re-added to row 937) | Critical | S | Verification | row 937 |
| 3 | Post-deploy: confirm the ten 0-byte `.raw` corpses + any `.part` are gone after the first run | High | S | Verification | row 937 narrative |
| 4 | Post-deploy: first live drill run (Sunday 08:00 or manual start) — expect a FAILURE page while the leg is broken; verify the failure is the freshness gate with the honest message, and that the `wants`-fired backup attempt behaved | High | S | Verification | row 943 `[watch]` |
| 5 | If a window fails: pull `discordsync_unit_io_write_bytes` + server journal at the failure second to identify the silent lock holder | High | M | Bug (root cause) | row 45 fold |
| 6 | If holder = re-backfill: measure its wall-time to size the nightly quiet window properly | Medium | M | Bug | prior §f.35 |
| 7 | Turso plan: upgrade (cloud mirror auto-resumes) vs permanent local-only (drop TURSO_* + red gatus check) | High | S | Decision | storage.md `[decision]`; **owner (Q2)** |
| 8 | Litestream trade: pool-file replica vs B2/S3 vs skip | High | S+d | Decision | storage.md `[decision]`; **owner (Q3)** |
| 9 | Three-numbers collector (backup age / drill age / lag) — closes the stopped-timer blind spot | Medium | M | Feature (monitoring) | **NEW row, self-harvested today** |
| 10 | Once a fresh dump lands: mark the hot-db wave-5 gate GREEN in hot-db.md | High | S | Documentation | prior §f.27 |
| 11 | Restore-drill the FIRST post-fix dump explicitly (drill 10-01 proved the past, not the repair) | High | S | Verification | prior §f.9 (fold into #4) |
| 12 | Verify the restic app-dumps repo's REMOTE leg actually exists (offsite is asserted from runbook text only) + read the btrfs/offsite companions for the 3-2-1 posture | High | M | Verification | prior §f.45 |
| 13 | Catch-up windows for the other dump legs (bank-sync, browser-history, paperless, miniflux, forgejo) | Medium | L | Feature | row 189 |
| 14 | Run the full pre-deploy + post-deploy suites around the deploy carrying this work | High | S | Verification | prior §f.50 |
| 15 | VACUUM INTO vs .backup decision (forensic-clean compact dumps; trivial CPU at 380 MB) | Medium | S | Decision | storage.md `[decision]`, queued today |
| 16 | sqlite3_rsync warm-standby decision (needs wrapper derivation; nixpkgs gap) | Medium | S | Decision | storage.md `[decision]`, queued today |
| 17 | WAL-gate `discordsync-db-heal`'s unconditional integrity_check (re-proved starvation class) | Medium | S | Bug | existing `[ready]` row |
| 18 | Extend guard `ioChurnUnits` with discordsync-db-heal + crush-hot-db-migrate | Medium | S | Bug | existing `[ready]` row |
| 19 | Post-crash resumable-reader pause automation (holder hypothesis strengthens it) | Medium | M | Feature | existing `[ready]` row |
| 20 | Per-service journal-rate + sustained-CPU smoke guard (would have caught the reconcile hot loop) | Medium | M | Feature | existing `[ready]` row |
| 21 | Capture-gap alarm for `message.created` silence-while-connected | Medium | M | Feature | existing `[ready]` row |
| 22 | MemoryHigh reclaim-thrash review (bank-sync / discordsync 31.6k hits / geometrikks / inboxclean-web) | Medium | M | Bug | existing `[ready]` row |
| 23 | Triage the 10 throttled units from the 2026-10-10 §17 sweep (incl. the backup unit's missing MemoryHigh) | Medium | S | Bug | existing `[ready]` rows |
| 24 | Migrate `discordsync.nix` `'''` case patterns → `""` (typo-bait class, same file as the drill) | Low | S | Quality | existing `[ready]` row |
| 25 | Immich key paste → deploy → verify (cross-archive go-live chain) | High | S | Feature | existing `[blocked:deploy]` row; owner key |
| 26 | DiscordSync upstream Tier-3 fixes (release tag + ADR-062, nixos-module options, malformed healthCheck) | Medium | L | Bug (upstream) | existing row |
| 27 | Catalog integration-subdomains eval warning (21 names incl. discordsync) — entries or documented acceptance | Low | M | Quality | prior §f.26 |
| 28 | Verify the parallel session's `618d4593` re-lock wave evals green post-merge | Medium | S | Verification | prior §f.31 |
| 29 | gzip-integrity check of the 2026-09-30 dump too (30 seconds; only 10-01 was drilled) | Low | S | Verification | prior §f.46 |
| 30 | Add `backfill_progress` snapshot to the drill's freshness checks (table exists) | Low | S | Feature | prior §f.47 |
| 31 | Update AGENTS.md DiscordSync section ONLY after the first successful post-fix dump | Low | S | Documentation | prior §f.48 |
| 32 | Add the drill + catch-up-window pattern to CONTRIBUTING.md as the canonical dump-leg shape | Low | S | Documentation | prior §f.38 |
| 33 | Check the deliberately-red "Turso Sync Active" gatus check's noise level post-shadow-split | Low | S | Quality | prior §f.39 |
| 34 | GOTRACEBACK=all on discordsync + browser-history | Low | S | Quality | existing monitoring row |
| 35 | OTLP logs / trace-id correlation for discordsync | Low | M | Feature | existing monitoring row |
| 36 | Verify `discordsync-io-metrics` counters reset cleanly across the deploy restart | Low | S | Verification | prior §f.43 |
| 37 | Fleet sweep: other "only backup" legs that left snapshot coverage without a drill (browser-history sibling) | Medium | M | Verification | prior §f.49 |
| 38 | Fold the §9 three-numbers doctrine into system-health textfile collectors generally (superset of #9) | Medium | M | Feature | covered by #9 row |
| 39 | Record the BuildFlow surgical-run pattern in agent docs (§e.6) | Low | S | Documentation | §e.6, not yet queued |
| 40 | docs-health HARVEST pass over the 105 unharvested §f-bearing reports (checker named `2026-10-12_13-13_signoz-hosts-hostmetrics-implementation.md`) — pre-existing WARN, deliberately NOT harvested this session (out of session scope; docs-health owns the pass) | Low | M | Documentation | observed this session; docs-health domain |

Deliberately not queued: §d.3 history cosmetics (no action possible under the no-reset rule); §d.4-7 (fixed in-session); the drill-fails-by-design expectation (documented in runbook + rows, not a task).

## §g QUESTIONS ONLY THE OWNER CAN ANSWER (3; unchanged, now time-sensitive)

1. **Deploy timing** — may I switch the hardening + drill the moment PSI drains (possibly TODAY before 03:45, which would otherwise be the 13th consecutive stale night on the ONLY backup of the unsnapshotted hot-tier event store), or must it batch with the in-flight parallel work (the new session's boot-evidence work; the Immich key paste is also pending)? I verified the live timer still carries only the old single 03:45 window, so without a switch tonight fails again.
2. **Turso plan** — upgrade the plan (cloud mirror auto-resumes on next service start, zero config) or go permanent local-only (remove TURSO_* from the sops template, drop the deliberately-red gatus check, decide the frozen 2026-08-16 cloud DB's retention)? This decides whether the nightly dump remains the ONLY backup of the event store.
3. **Litestream trade** — local-file replica on the pool (free, same-host failure domain only), B2/S3 (true offsite, needs credentials + monthly cost), or skip Litestream and accept nightly-dump RPO with the new catch-up windows? The nixpkgs module + local drill are proven; only the destination policy is yours to set.

---

**Sources:** this session's journalctl/live probes (timer render, corpse listing, dump restore + schema probe); render + eval outputs (OnCalendar, ExecStart, extraMonitoredServices); fixture build log (`discordsync-restore-drill-fixture: PASS (8 cases)`); `nix flake check --no-build` (all checks passed, 5m14s); commits `3bcb6297`, `87212723`, foreign `06362509`, `03d72f61`; the 22:36 and 20:45 predecessor reports; `~/projects/reports/sqlite-continuous-backup-deep-dive-2026.md` §8.4/§9.
