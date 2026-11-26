# Status 2026-11-26 05:37: plan v6, second execution leg — seven tasks done, three partial, sixteen open

**Written:** 2026-11-26 05:37 CET (`date`), boot `0737ecd7` (18.5 h up), HEAD `8441c5415`, `master` 27 commits ahead of `origin/master` and nothing pushed by this session. io PSI some avg10 49.8 %. Live system: gen-1031 (`6q9jp84a`), switched at 19:33 on 2026-11-25 by a sibling session's deploy, profile anchored. Tree at authoring: six uncommitted files; five are this report's own harvest (TODO_LIST.md, three libraries, the appendix on the 17:30 report), `modules/nixos/services/memory-emergency-guard.nix` belongs to a sibling session. The auto-commit daemon picks them up.

**Plan:** [2026-11-25 00:06 SUPERB backlog masterplan v6](../planning/2026-11-25_00-06_SUPERB-backlog-masterplan-v6.md). Its marker still reads `EXECUTING (instance crush-glm54-full-exec-1125-0818)`. Previous report of this session: [2026-11-25 17:30](./2026-11-25_17-30_plan-v6-full-execution-paused-t07-done-t08-in-tree-offsite-borg-key-unloadable-status.md).

**Scope line:** this report covers the work from that report (17:30 on 2026-11-25) to 05:37 on 2026-11-26: the Borg success-marker fix, plan tasks T05, T06, T08, T10, T11, T16 and T18, the preparation of T03, the data half of T09, and what the session noticed about the host. Each section ends with what was run and what was not.

## TL;DR

1. **The T08 fixes are live and hold.** A sibling's deploy switched gen-1031 at 19:33. Verified again at 05:38: the nightly audiblesync backup ran at 02:35, the Rust cache GC has its stamp, cvagent has zero throttle events since the switch, the Forgejo re-interval strike counter reached quarantine, and the Borg job is `Type=oneshot`.
2. **The offsite Borg backup is still dead and now says so.** Zero archives since go-live; the phantom success marker is gone and the metrics read `backup_ever_succeeded 0`. It waits on the owner's key.
3. **Plan v6 stands at 7 of 27 tasks done, 3 partial, 16 not started, 1 not due.** Done since 17:30: T06, T08, T10, T11, T16, T18, and the marker fix. The remaining thirteen agent tasks need about 14 hours of execution.
4. **The block ruling pack is ready.** 1,504 open rows (42.3 % of the queue) come from the 2026-11-07 bulk harvest. The dispatch pool reached none of them in the measured week: the harvester works the section heads and the block sits in the tail. A seeded sample of 30 closed 7 on one re-check.
5. **The box had no calm window all night.** io PSI stayed between 40 % and 58 % from about 19:00 on. Eight deploys were refused by the pressure gate (20:21 to 20:42). My two Nix edits of tonight are parse-checked but not evaluated.
6. **96 failed units at 05:38, 88 of them template instances** of the llama per-connection proxies. And the root snapshot chain has produced nothing for ten days (the verifiers say so; not triaged here).

## Scope: what was verified here, and what was not

Verified in this session, each by the command named:

| # | Claim | Command and result |
| --- | --- | --- |
| 1 | The Borg job is oneshot with both pre-flights | `grep -n '^Type=\|^ExecStartPre' /etc/systemd/system/borgbackup-job-hetzner.service`: line 38 `Type=oneshot`, golive check line 24, key check line 25 (05:38) |
| 2 | The Borg metrics tell the truth now | `grep offsite-borg …/backups.prom`: `backup_ever_succeeded 0`, `backup_healthy 0`, `backup_age_hours 999`; `sudo ls -A /var/lib/borg-offsite \| wc -l` → 0 |
| 3 | The nightly audiblesync backup ran | `journalctl -u audiblesync-backup.service --since '2026-11-26 00:00'`: `Finished` at 02:35:00; dir unit `active (exited)`; dir `root:root 755` |
| 4 | The Rust cache GC writes its stamp | `ls /var/lib/rust-cache-gc/`: `stamp` from 19:42; `systemctl show` → `Result=success` |
| 5 | cvagent no longer thrashes | unit lines 21 to 22: `MemoryHigh=3435973836`, `MemoryMax=4G`; `memory.events high 0`; root page since 19:33: 3,614 × 200, 6 × 500 |
| 6 | The re-interval strike logic runs | `forgejo_mirror_reinterval_quarantined 1`, `loud_failures 0`; `strike 1 of 3` in the 19:42 journal |
| 7 | `audiblesync` is a pull mirror on Forgejo | sudo API probe (token never printed): `mirror: true`, zero push mirrors; controls `domains` and `gogenfilter`: `mirror: false` with push mirrors |
| 8 | Every script of this session passes its selftest at HEAD `db2576666` | 05:41 to 05:47: `check-todo-system.sh --selftest`, `check-todo-bulk.sh --selftest`, `session-start-probe.sh --selftest`, `backlog-flow.sh --selftest`, `tick-todo-rows.sh --selftest`, `test-offsite-borg-smoke.sh`: all rc=0 |
| 9 | The Borg render guard and smoke pass | `nix build .#checks.x86_64-linux.offsite-borg-smoke-selftest` and `…offsite-borg-positive-render`: rc=0 (about 19:00) |
| 10 | CI state | `scripts/session-start-probe.sh --gate --logs` (01:50): 3 of 9 workflows green; 4 of the 5 red ones fail on auth or fetch of a private input; `secret-history-scan` fails on secrets in history |
| 11 | Queue numbers | `scripts/backlog-flow.sh .` (05:45): 3,557 open rows (ready 2,427), block 1,504 open = 42.3 %, gate 103 unharvested reports and 133 drifts |
| 12 | Pool numbers | `tq tasks --project SystemNix --since 168h --json` (01:11): 79 tasks; `tq stats`: read model 14,663 facts behind, counters empty |
| 13 | Failed units | `systemctl --failed` (05:38): 96 units |
| 14 | The work is committed | my named commits `ab44700cc`, `08969de87`, `2f1be02af`, `2380be0a0`, `328b045b6`; daemon commits that carry my edits: `799a776d7`, `58f6c01ee`, `164b91d31`, `87a47e9de`, `23ab0c2b8`, `7e04a5fa2`, `db2576666`, `0358090d0` |

Not verified here:

- **Two Nix edits were never evaluated.** `rust-cache-projects-links` is now ordered after `user@1000.service` (`platforms/nixos/system/snapshots.nix`), and the health hub federates `indexer-web` and `timesheets` (`platforms/nixos/system/configuration.nix`). Both are parse-checked only. The last full `nix flake check --no-build --all-systems` I ran was at 11:35 on 2026-11-25 on a different tree (rc=0). io PSI never dropped below 40 % afterwards, so no eval was run.
- The negative leg of the new render guard (a render with `Type=simple` must throw).
- The bulk guard's hook leg in a real commit. No commit went through the new hook after the edit (the later ones were daemon commits). `--ratchet-down` was never executed.
- The 06:30 Borg fire after the marker fix: it had not happened at authoring.
- Why the 88 llama proxy instances fail (counted, one instance's journal read), why the root snapshots are ten days old (two verifier lines read), who writes 22 GB a day to `/data`, why a store path vanished under `nix-optimise`.
- Whether the crash-capture fix of the sibling report at 00:36 is deployed. The report's title was read, not its body.
- Whether the four auth-red workflows are green once the owner's token lands. They can carry content failures underneath.
- The 1,467 block rows outside the 30-row sample.

## a) FULLY DONE

| What | Evidence | Where |
| --- | --- | --- |
| The Borg success marker can no longer be written by a failed run | job `Type = "oneshot"`; render guard asserts it; the §13/§16 deploy smoke gained a type leg and a key pre-flight leg (26 fixtures); the phantom marker was moved to root's trash at 21:04; metrics read 0 since the 21:21 tick | `platforms/nixos/system/backup.nix`, `flake/parts/checks/selftests.nix`, `scripts/lib/offsite-borg-smoke.sh`, `scripts/test-offsite-borg-smoke.sh`; commit `08969de87` |
| T07: master passes its own dead-guard lint | four captures rescued; check built rc=0 | commit `53592ed92` (earlier leg of this session) |
| T08: live-failure triage | five units fixed, all verified live again at 05:38 (table below) | commits `08969de87`, `58f6c01ee`; rows ticked |
| T16 and T18: sweeps of pipeline, stability and monitoring | 18 rows closed on both surfaces, each with its verdict and evidence | commit `ab44700cc` (27 rows) |
| T11: `scripts/backlog-flow.sh` | queue census at five date-resolved revisions, flow per window, block shape and pairing, seeded sample, gate counts; selftest on a dated fixture repository | commits `2f1be02af`, `164b91d31`; one sentence in AGENTS.md |
| T06: the NOW block | `### NOW (max 10)` under `## Queue`, ten bullet pointers; validator: 10 bullets, 10 distinct open titles, 0 problems | commits `2380be0a0`, `87a47e9de`, `23ab0c2b8`; AGENTS.md Session Discipline |
| T10: `scripts/session-start-probe.sh` | read-only, exit 0 always, selftest with stubbed `gh`, `tq`, `systemctl`; AGENTS.md CI row carries the measured state with a re-verify pointer | commit `328b045b6` |
| Block sample closes (part of T03's preparation) | 7 of 30 sampled rows closed with evidence, 2 annotated | daemon commit `799a776d7` (carries my edits under a heuristic message) |
| Ruling pack (T03, M13 to M15) | [2026-11-26 01:20 block ruling pack](../planning/2026-11-26_01-20_2026-11-07-block-ruling-pack.md) | in tree (`164b91d31`, `2f1be02af`) |

The five T08 units, read again at 05:38:

| Unit | Fix (live since 19:33) | Reading at 05:38 |
| --- | --- | --- |
| `audiblesync-backup-dir` | dir unit declares `owner = "root"` | `active (exited)`; dir `root:root 755`; the 02:35 `audiblesync-backup` run `Finished` |
| `rust-cache-gc` | stamp in a `StateDirectory` | stamp of 19:42 present; `Result=success` |
| `cvagent` | `MemoryMax 4G`, `MemoryHigh 3.2G` | `memory.events high 0`; root page 3,614 × 200 against 6 × 500 in ten hours |
| `forgejo-github-sync` (re-interval phase) | three strikes, then quarantine | `forgejo_mirror_reinterval_quarantined 1`, `loud_failures 0` |
| `borgbackup-job-hetzner` | key pre-flight names the secret and the fix | both pre-flights on the unit; the next fire is 06:30 |

Run: the commands of the scope table. Not run: the evals and the negative leg named under "not verified".

## b) PARTIALLY DONE

| Item | What works now | What remains | Blocker | Effort |
| --- | --- | --- | --- | --- |
| T05 intake control | open-row ratchet in `scripts/check-todo-system.sh` (`BACKLOG_MAX_OPEN=3558`, WARN by default, `CHECK_TODO_RATCHET=strict` fails, `--ratchet-down`); bulk guard `scripts/check-todo-bulk.sh` (a staged queue diff adding more than 50 open rows fails; owner override `TODO_BULK_HARVEST_OK=1`); hook leg in `.githooks/pre-commit`; queue header rules; AGENTS.md sentence; CHANGELOG. Both selftests rc=0 at HEAD `db2576666` | prove the hook leg with a real commit; run `--ratchet-down` after the next committed shrink; M32 (strict harvest gate once T15 is done) | none; it sits in daemon commits `7e04a5fa2` and `db2576666` without a named commit | S |
| T03 ruling pack | inventory, 30-row sample, three options with counts and rollback | the ruling (M16) and its `[decision]` row | owner | S for the row |
| T09 pool follow-through | the data: 79 SystemNix tasks in 7 days (40 incident fixes: 30 cancelled, 7 pending, 3 dead; 27 queue-row batches: 24 completed; 12 reviews, status and dlq-fix); budget spent today 1 of 30; read model 14,663 facts behind with empty counters; zero block rows dispatched | restarts against the 3 queued rows, dirty-tree refusals over 3 days, the budget one-pager and its ruling row (M46 to M50) | none | M |
| T02 CI auth | the remaining reds are classified: 4 of 5 are auth or fetch failures of private inputs, 1 is content | the owner's read-only PAT and deploy keys, a fresh run, 4 rows ticked with run ids | owner | S |
| NOW block | ten validated pointers | the panic bullet is stale: a sibling report at 00:36 says the capture path is fixed in tree; re-rank at the next session start | none | S |
| Plan close-out | CHANGELOG lines for everything landed are in | plan errata, the marker flip when the plan ends, the T25 probes from 2026-12-02 | the plan is not finished | S |

Run: the selftests of item T05 at 05:41 to 05:47; the pool numbers at 01:11. Not run: a commit through the new hook.

## c) NOT STARTED

16 of the 27 plan tasks, 59 % of the plan:

| Task | Why not |
| --- | --- |
| T01 keys | owner console actions |
| T04 scripted re-park | waits for the T03 ruling |
| T12 harness hardening | the row exists (created with the NOW block); no code |
| T13 local path for CI-only gates | after T12 |
| T14 honest harness run | after T12, needs a calm window |
| T15 unharvested report wave | 103 reports; no batch done |
| T17, T19, T20, T22, T23 sweeps and answer sheet | not reached |
| T21 VM-test and eval-guard backlog | needs a calm window |
| T24 upstream lane | not reached; owner pushes |
| T25 retro | not due before 2026-12-02 |
| T26 owner ceremonies one-pager | not written |
| T27 ROADMAP graduation | not written |

The session spent its time on four things instead: verifying and rowing T08, four tools (tick helper, `backlog-flow.sh`, `session-start-probe.sh`, bulk guard and ratchet), the ruling pack, and waiting for a calm window that did not come.

## d) TOTALLY FUCKED UP

| # | What | Severity | Root cause | Mitigation |
| --- | --- | --- | --- | --- |
| d1 | The offsite Borg backup has produced no archive since go-live (2026-11-16) | Critical: the third copy does not exist | the stored `borg_ssh_key` cannot load; its seed does not derive its own public half | monitoring is honest now (`backup_ever_succeeded 0`); fix is the owner's key |
| d2 | The root snapshot chain has produced nothing for ten days: `Root snapshot is 10 days old (threshold: 3)` (00:35), pool root backup ten days old (00:32), `btrbk-forgejo-clean` exit 10 (04:18) | Critical: local backup of the root subvolume | unknown; not triaged here | the storage row is annotated with tonight's lines; triage is next item 7 |
| d3 | 96 failed units at 05:38; 88 are template instances of `llama-chat@` (42) and `llama-vlm-cap@` (46) | High: `systemctl --failed` is no longer a signal | each proxy lives 29 min 59 s and exits 1 (sampled instance 20:18:15 to 20:48:15) | new row; the fix direction is an exit 0 on the idle end |
| d4 | `forgejo-github-sync` fails every hour at phase 5: `audiblesync` is listed as a native repo but is still a pull mirror | Medium: an hourly failed unit and an OnFailure page | the re-interval fix let the sync reach phase 5 again; the flip the config comment claims for 2026-11-15 did not hold | owner call: flip, or drop it from the canonical list (new row) |
| d5 | io PSI 40 % to 58 % from about 19:00 to 05:37; eight deploys refused (exit 12) between 20:21 and 20:42 | High: nothing in tree is deployed, nothing can be evaluated | not investigated here; the deploy logs name the ghostty terminal scopes as the most stalled cgroups | the patient path (`scripts/deploy-when-quiescent.sh`) is the tool; the box needs quiet |
| d6 | CI: `nix-check.yml` last green 2026-07-29 (120 days) | High: no gate between commit and deploy | four of five red workflows fail on auth or fetch of private inputs; one on two live keys | owner: read-only PAT and deploy keys (T02), key rotations (T01) |
| d7 | `/data` grew 22 GB in 24 h on two nights (threshold 5 GB) | Medium | not attributed | the `/data` watch row is annotated |
| d8 | cvagent answers 500 on `GET /` six times in ten hours while `/health` is 200 | Medium | the page scans the fact-set store on the request path (upstream) | the cap removal cut the rate from about 24 an hour to 0.6; upstream row exists |
| d9 | My own mistakes | see below | | |

My own mistakes of this leg:

1. **I lost the daemon race twice** by running a dry-run between applying edits and committing. Two batches of my work landed under heuristic messages (`58f6c01ee`, `799a776d7`). I had that rule in my own notes from the morning.
2. **The first draft of `backlog-flow.sh` was sloppy**: leftover expressions and dead branches. I rewrote it before it worked on the real repository, but it cost an hour.
3. **A scratch tool missed 7 untagged rows** in the block count (1,497 against 1,504). The committed tool counted right; I found it only because I reconciled the two numbers before writing the ruling pack.
4. **Thirteen plan tasks are untouched** after another twelve hours. I built tool where the plan asked for sweeps, and the tool serves the sweeps, but the sweeps did not run.
5. **Two Nix edits ride the next deploy unevaluated** (parse-checked only). They are small, and that is still a risk a two-minute eval would have removed.
6. **The NOW block's panic bullet went stale within hours** (sibling fix at 00:36). The block has no gate leg that would notice; the validator is a scratch script.
7. **I added a leg to a gate that already takes 30 seconds under load.** The TODO gate spawns thousands of greps in its pairing check; the session-start probe had to make the gate counts opt-in for that reason.

## e) WHAT WE SHOULD IMPROVE

| What is suboptimal | Impact | Fix |
| --- | --- | --- |
| Apply and commit are two tool calls in practice | the daemon sweeps in between; the commit history loses the message | a repo helper that applies a prepared edit set, runs the gate and commits with a pathspec in one call; until then: never a dry-run between apply and commit |
| The TODO gate spawns one grep per cited source (30 s under load) | strict modes are unaffordable in the hook; the probe drops the counts | one pass per library in `pairing_check` (batch the citations, grep once) |
| The NOW block can go stale silently | a reader trusts a bullet that a sibling already fixed | a WARN leg in the gate: a bullet whose row is closed, or more than ten bullets |
| Failed-unit probes list template instances one by one | 88 of 96 lines are one unit | collapse `@…` instances in the probe and in the health check |
| The harvester's order is a hidden policy | 2,055 `[ready]` rows in the tail sections are never dispatched; nobody decided that | make the order explicit, or park the tail deliberately (the T03 ruling) |
| Scratch tools next to committed tools | numbers disagree; the reader cannot tell which is right | reconcile before quoting; delete the scratch tool once the committed one exists |
| Plan v6's premise for T03 | the plan says the pool budget goes to the block; it does not | errata entry: the block costs file size and honesty, not dispatches |
| Plan v6's T08 list | grew by two root causes the plan did not name (phase 5 pull mirror, cvagent upstream scan) | errata entry; both have rows now |
| The session wrote three reports and two packs in 24 hours while thirteen tasks waited | the owner asked for each one | after this report: one uninterrupted execution leg for the thirteen tasks, in a calm window |

## f) Up to 50 things to get done next (ranked by impact)

| # | Task | Impact | Effort | Category | Who |
| --- | --- | --- | --- | --- | --- |
| 1 | Rule on the 2026-11-07 block: keep, re-park, or re-park and stamp (ruling pack, section 6 recommends C) | High | S | Decision | owner |
| 2 | Replace the unloadable `borg_ssh_key`: re-store the original r2 private key, or generate a pair and install its public half on the StorageBox | Critical | S | Bug | owner |
| 3 | Decide `audiblesync` on Forgejo: run `forgejo-flip@audiblesync` (Forgejo primary), or drop it from `forgejo.canonicalRepos` | High | S | Decision | owner |
| 4 | CI auth: read-only PAT (`NIX_GITHUB_RO_TOKEN`) and deploy keys for the four ssh inputs | High | S | Process | owner |
| 5 | Triage the root backup chain: why the root snapshot is ten days old, the pool root backup ten days, `btrbk-forgejo-clean` exit 10 | Critical | M | Bug | agent |
| 6 | Fix the llama proxy template instances so the failed list is a signal again (exit 0 on the idle end, or a reset leg) | High | S | Bug | agent |
| 7 | In a calm window: evaluate the two Nix edits, run `nix flake check --no-build --all-systems`, deploy through the gated path, tick the two `[blocked:deploy]` rows | High | S | Quality | agent |
| 8 | Negative leg for the Borg render guard (a render with `Type=simple` must throw) | Medium | S | Quality | agent |
| 9 | Prove the bulk guard's hook leg with a real commit; run `--ratchet-down` after the next committed shrink | Medium | S | Quality | agent |
| 10 | Re-rank the NOW block (panic bullet after the sibling's 00:36 report; the new failed-unit row) | Medium | S | Documentation | agent |
| 11 | T12 harness hardening (INFRA class, abort on a failed pristine fetch, live doc-count mutations, `--check-mutations`) | High | L | Quality | agent |
| 12 | T15 unharvested report wave 1 (48 of 103 reports, at most 3 new rows) | Medium | L | Documentation | agent |
| 13 | T13 local path for CI-only gates | Medium | M | Quality | agent |
| 14 | T14 honest harness run in a calm window | Medium | L | Quality | agent |
| 15 | T05 last step: harvest gate strict in the hook once T15 is done | Medium | S | Process | agent |
| 16 | T09 write-up: restarts against the 3 rows, dirty-tree refusals over 3 days, the budget one-pager | Medium | M | Process | agent |
| 17 | T17 services sweep wave 1 (25 rows, verify first) | Medium | M | Cleanup | agent |
| 18 | T19 blocked and watch sweep wave 1 | Medium | M | Cleanup | agent |
| 19 | T20 decisions answer sheet (60 rows, one pass for the owner) | Medium | M | Decision | agent |
| 20 | T04 re-park script skeleton with manifest and selftest, dry-run only (after the ruling) | High | M | Process | agent |
| 21 | T21 VM-test and eval-guard backlog (2 wirings, 1 fixture leg) | Medium | M | Quality | agent |
| 22 | T26 owner ceremonies one-pager (keys, CI auth, block ruling, pool budget, Borg key, audiblesync flip, InboxClean re-consent, zombie mirror, crash test) | Medium | S | Documentation | agent |
| 23 | T22 storage sweep wave 1 (du legs only in a calm window) | Low | M | Cleanup | agent |
| 24 | T23 desktop, ai-stack, security, pixel6 wave | Low | M | Cleanup | agent |
| 25 | T27 ROADMAP graduation and two proposal stubs | Low | S | Documentation | agent |
| 26 | T24 upstream lane batch 1: prepare 8 patches, the owner pushes | Low | M | Upstream | agent and owner |
| 27 | Plan v6 errata (T03 premise, T08 growth, task counts) and the marker flip when the plan ends | Medium | S | Documentation | agent |
| 28 | Batch the gate's pairing greps so the gate takes a second, not thirty | Medium | S | Quality | agent |
| 29 | NOW-block validator as a WARN leg of the gate | Medium | S | Quality | agent |
| 30 | Collapse template instances in the failed-unit probe and the health check | Medium | S | Quality | agent |
| 31 | Prune the ticked rows (`scripts/prune-done-todos.sh`, dry-run first) | Medium | M | Cleanup | agent |
| 32 | Attribute the 22 GB a day on `/data` | Medium | M | Bug | agent |
| 33 | `nix-optimise`: tolerate a path that vanishes mid-run, or order it after the garbage collector (one occurrence, watch row exists) | Low | S | Bug | agent |
| 34 | cvagent upstream: stop scanning the fact-set store on `GET /` (row exists, `[blocked:push]`) | Medium | M | Bug | owner pushes |
| 35 | tq read model: empty counters 14,663 facts behind (`tq stats` unusable) | Medium | M | Bug | upstream (go-taskqueue) |
| 36 | InboxClean `main`: `inboxclean auth` (re-consent) | Medium | S | Bug | owner |
| 37 | `lars/nixpkgs` zombie mirror: delete the half-created repo so the next sync re-creates it | Medium | S | Decision | owner |
| 38 | T01: delete the Gemini key, rotate the Context7 key (two live keys in public history) | Critical | S | Security | owner |
| 39 | Deploy the crash-capture fix and run the owner crash test (sibling report 00:36) | Critical | S | Bug | owner and agent |
| 40 | Session-start probe: cite it in the tq session template so pool sessions read CI and backlog before claiming rows | Low | S | Process | agent |

The list is a brainstorm past item 20, not a commitment. Items 1 to 4 and 36 to 39 are the owner's.

## g) Questions I cannot answer myself

1. **The block ruling.** Keep the 1,504 rows queued as they are (A), re-park them to their libraries (B), or re-park them and stamp each library row (C)? I recommend C in the [ruling pack](../planning/2026-11-26_01-20_2026-11-07-block-ruling-pack.md). I tried to answer it by measuring what the pool does with the block (nothing, by position) and by sampling it; the choice between a 30 % smaller queue file and an unchanged one is yours.
2. **The Borg key.** Do you still have the original r2 private key file to re-store, or should a new pair be generated and its public half installed on the StorageBox? I cannot know where the original lives, and I must not generate or copy key material.
3. **`audiblesync` on Forgejo.** Should Forgejo become its primary (I then run `forgejo-flip-check@audiblesync` as the dry-run, and you or I start the flip), or does it stay GitHub-primary and leave the canonical list? The config comment says the flip happened on 2026-11-15; the live repo says `mirror: true`.

## Plan v6: task state at 05:37

| State | Tasks | Count |
| --- | --- | ---: |
| Done | T06, T07, T08, T10, T11, T16, T18 | 7 |
| Partial | T03 (pack done, ruling open), T05 (hook leg unproven, M32 open), T09 (data only) | 3 |
| Not started | T01, T02 (only the classification), T04, T12, T13, T14, T15, T17, T19, T20, T21, T22, T23, T24, T26, T27 | 16 |
| Not due | T25 (first probes on 2026-12-02) | 1 |

## Live checks owed after the next deploy and the next boot

- 06:30 on 2026-11-26, Borg: the fire still fails on the key and must leave `/var/lib/borg-offsite` empty (watch row exists).
- After the next deploy: `health-dashboard-rediscover` exits 0 at its 11:21 run and health.home.lan shows the `indexer-web` and `timesheets` cards.
- After the next boot: `rust-cache-projects-links` is not failed and logs `rust-cache-links: done` in its first minute.
- After any commit that shrinks the queue: `bash scripts/check-todo-system.sh --ratchet-down`.

## Harvest log

Harvested at authoring, in the working tree (the daemon commits it):

- One new row pair, queue section `ai-stack` and `docs/todo/ai-stack.md`: "llama-chat and llama-vlm-cap proxy instances fail with exit 1 after 30 minutes and pile up in the failed-unit list" (from d3, next item 6).
- One library watch row in `docs/todo/pipeline.md`: "nix-optimise exits 1 when a source store path vanishes mid-run" (from the failed-unit list, next item 33).
- Two annotations on both surfaces: the "Backups stale beyond audiblesync" row (root snapshot and pool root backup ten days old, `btrbk-forgejo-clean` exit 10) and the `/data` watch row (22 GB a day, two nights).
- An appendix on the 2026-11-25 17:30 report recording what of its section f is now done.

Deliberately not harvested as rows: next items 1 to 4, 34 and 36 to 39 are owner asks whose rows exist (Borg key, pull mirror, InboxClean re-consent, CI auth, keys, cvagent upstream, zombie mirror); items 7 to 15, 17 to 21 and 23 to 27 are plan tasks that the plan file itself tracks; items 8, 9 and 10 are verification legs recorded in the section above; item 5 is covered by the annotated backups row; item 28 to 30 and 35 are tooling improvements that belong in the T05 and T12 follow-ups (the gate-speed fix is the first step of M32).
