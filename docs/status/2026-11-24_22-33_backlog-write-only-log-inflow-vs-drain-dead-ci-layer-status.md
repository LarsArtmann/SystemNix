# Backlog Is a Write-Only Log: Inflow vs Drain, a Dead CI Layer, and This Session's Self-Critique

**2026-11-24 22:33 CET · Crush agent (GLM-5.4) · trigger: owner ask "What is something all other models missed that we should improve?" → "What did you forget / could have done better / still improve?" + full status update**

---

## Scope

**Verified here** (fresh commands between ~21:50 and 22:30 CET; the tree described is pinned at `6a5ecfd`, the HEAD of the lint build, the row counts and the last HEAD probe. The session started at `cc4adb1`; HEAD was `4166e71` when this file was written at ~22:41, moved by sibling-session commits `9e0f4de` and `4166e71`. TODO row line numbers are as of 22:41 and rot with every parallel commit; each cited row is unique by its title):

- **CI**: `gh run list --workflow <wf> --limit 1000 --json conclusion,createdAt,event,databaseId` for 5 workflows, summarized with python; `gh run list --workflow <wf> --status success --limit 3` per workflow; `gh run view <id> --log[-failed]` for runs 45484418826 (Go deps audit), 45484418746 (Secret history scan), 45484418690 (Negative lint tests), 45484418850 (Nix flake check, job list).
- **Lint**: `nix build .#checks.x86_64-linux.dead-guard-lint --no-link` at `6a5ecfd` → rc=1, 4 findings.
- **Harness rot**: `grep -c` for the 3 doc-count mutation anchors → 0 hits in `README.md` and `FEATURES.md`; the `platforms/nixos/system/snapshots.nix` anchor is present at `:905`.
- **Live units**: `busctl call … ListUnitsFiltered as 1 failed` → 5 system units; `journalctl -u <unit> --since "4 days ago"` for each; `journalctl -u tq-agent-pool.service --since "2026-11-22 00:00"` (3,414 lines), template-summarized with python.
- **Backlog**: row-event diff (`git log -p --unified=0` since the 2026-09-19 split: 2,504 commits, 16,343 row events) AND an independent recount of open rows at 5 past revisions. The two methods agree within 2.5% on 30 days (+4,369 vs +4,474) and within 1 row on 7 days (+293 vs +294).
- **Tracking**: `rg` over `TODO_LIST.md`, `docs/todo/*.md`, `docs/agents/*.md`, `AGENTS.md`, `ROADMAP.md` for each candidate finding.
- **Visibility**: `gh repo view LarsArtmann/SystemNix --json visibility` → PUBLIC.

**NOT verified here** (and why):

- Whether the leaked keys named in `docs/todo/security.md:14` are still live. A leaked credential is never tested; the repo's own row is the only source and says "re-verified LIVE 2026-10-05".
- The full negative-test harness locally (not run: 95 eval/build cases on a box whose calm-gate refused at 21:46:56, "still storming after 60 min / 241 probe(s)").
- `nix flake check` (not run, heavy).
- Whether the 54 harness cases that failed on the CI fetch error pass locally. Only their CI cause was classified.
- Root cause of the `tq-agent-pool` restart loop (counted, not diagnosed).
- Actual task completions per day by the pool. My completion-line pattern matched 0 to 1 lines and is not trusted; the drain side of the argument rests on tick events in git, not on pool accounting.
- Whether `audiblesync-backup` depends on the failing `audiblesync-backup-dir` unit.
- Why the harness sed expression for the `snapshots.nix` case is invalid.
- The queue-size token figure is an estimate (4 characters per token), not a measurement.
- Why `service-health-check.service` exits non-zero (inferred from its output: it lists the failed set, then exits 1; source not read).
- Whether an AGENTS.md size reduction is already queued (not searched).

---

## Verdict

The question was answered with one finding that survived a tracking check: the backlog grows about 5 rows for every row closed, and nothing measures or caps it. Three other candidates (dead CI, unrotated public keys, a red lint on master) turned out to be already queued, which is itself the evidence: real problems get a row and then sit in it. This session changed nothing in the repo other than this report.

---

## 0) Self-Critique (what I forgot, could have done better, can still improve)

### Forgot

1. **Session-start skill.** `next-queue` says "Use at the START of any work session". It was loaded mid-session, only while checking for an owner-escalation path.
2. **Live failed units were left out of the first answer.** They were read at ~22:00 (5 system units + 1 user unit). One of them, `audiblesync-backup-dir.service`, is failing since 21:36:57 and has 0 mentions in the TODO corpus (checked for this report).
3. **The pool restart loop was left out of the first answer.** 87 restarts were in the journal read before that answer.
4. **Two prescribed outputs of the loaded `brutal-self-review` skill were skipped silently**: the HTML report under `docs/reviews/` and the commit-after-each-change loop. The skip was deliberate (the owner asked a question; a repo write was not requested), but the answer should have said so.

### Could have done better

5. **Evidence before dedupe.** The case for "CI is red" was built first and checked for existing rows afterwards. It had 4 rows. Same for the unrotated keys (2 rows) and `dead-guard-lint` red on master (1 row, queued 2026-10-29). Dedupe-first would have saved about half the session.
6. **Five throwaway probes returned empty or errored on first use**, each caught only because the result was implausible: a busctl signature (`s` instead of `as`), an awk regex that cannot match a diff line (`/^- \[ \]/` against `-- [ ]`), `git log --name-only -p` (name-only suppresses the patch), a journal-template regex with one token too many, a `sed` pretty-printer error. Zero is a failed read, not a result; one known value should go through a new pipeline before it is trusted.
7. **A silent parser gap.** The harness classifier dropped the 4 `HARNESS BUG:` verdicts: its verdict regex required a space after the keyword, so those lines were folded into the previous block (91 of 95 verdicts classified). The arithmetic (60 = 54 + 2 + 4) reconciled it by hand; the parser did not.
8. **Head-truncated first read.** The first look at the negative-test log was `tail -80`. It showed the last 60 verdicts only; the full log was pulled afterwards. No wrong conclusion followed, but the first read was incomplete by construction.

### Can still improve (open work left by this session)

9. Nothing proposed below is implemented or harvested (by instruction: "THEN WAIT FOR INSTRUCTIONS").
10. The inflow/drain numbers were computed ad hoc (python over a 15 MB diff dump plus a 5-point recount). They belong in a one-command script (§f item 28).
11. The four `dead-guard-lint` sites are a small fix, but `modules/nixos/services/rust-cache.nix` and `modules/nixos/services/cv.nix` are being edited by sibling sessions right now (staged TODO edits from the rust-cache session; a `rust-cache-gc` failure at 21:51). The fix needs the owning session or a quiet window.
12. This report adds to the corpus it critiques (file 1,399 under `docs/status/`). Kept to one file and no rows.

---

## a) FULLY DONE

1. **The owner's question answered with a verified finding.** The backlog is net-additive (+4,369 rows in 30 days, 870 closed) and no gate, row, or doc measures it. Evidence: tables in §d.1; `rg` for growth/size terms across the planning corpus returns no matching row; `scripts/check-todo-system.sh` has no size or age check (`rg "wc -l|max_|limit|budget|ratchet"` → 0 hits).
2. **Candidate elimination with row pointers.** Three of four candidate "misses" were confirmed already queued, so the answer does not re-report known items: CI red (`docs/todo/pipeline.md:44`, `:73`, `:225`), key rotation (`docs/todo/security.md:13`, `:14`), `dead-guard-lint` (`TODO_LIST.md:1859`).
3. **Ghost-file check of the Prevention Layers table**: all 36 files named in the AGENTS.md table exist (`test -e` loop, 36/36).
4. **Hook arming**: `git config core.hooksPath` → `.githooks`.
5. **`dead-guard-lint` red on master confirmed locally** at `6a5ecfd` (rc=1, 4 findings, §d.4).
6. **Backlog flow cross-validated by two independent methods** (diff events and row counts at past revisions), see Scope.
7. **No repo changes** other than this report.

---

## b) PARTIALLY DONE

1. **CI classification.** Done: last-green date and retained-run tally per workflow; failure cause for the latest run of each of the 4 red workflows. Open: when each went red for content versus infrastructure, across history. Effort: S. Blocker: none.
2. **Negative-test harness classification.** Done: latest run only (95 verdicts: 35 pass, 54 one-cause fetch error, 2 real, 4 harness bugs). Open: whether the 54 pass locally. Effort: M. Blocker: IO-sensitive box (calm-gate refusal at 21:46:56).
3. **Pool throughput.** Done: refusals, rate-limit requeues, budget blocks and restarts counted per day. Open: completions per day (not measured, see Scope). Effort: M. Blocker: completion semantics live in the `go-taskqueue` repo (out of scope this session).
4. **Live failed units.** Done: 5 system units + 1 user unit seen and journaled; tracking checked for all six (§d.7, §f items 20 to 23). Open: root cause of the `audiblesync-backup-dir` failure. Effort: S.
5. **Improvements specified, not built** (§e, §f). Effort: S to L per item. Blocker: waiting for instruction.

---

## c) NOT STARTED

All of it by instruction ("THEN WAIT FOR INSTRUCTIONS"); priority votes in §f.

1. Every §f implementation item (size ratchet, "now" list, harness verdict split, AGENTS.md dead-layer marking, the 4 dead-guard fixes, the `audiblesync-backup-dir` triage).
2. Harvest of §f into `TODO_LIST.md` + the domain libraries (see "Harvest" below).
3. The `brutal-self-review` HTML report under `docs/reviews/` (deliberate deviation, §0 item 4).
4. AGENTS.md / memory update for the facts learned here (deliberate deviation: adding text was the finding).

---

## d) TOTALLY FUCKED UP

### 1. The backlog is a write-only log

Severity: high. It is the mechanism behind items 2 to 5. Root cause: every rule pushes sessions to add rows (mandatory self-harvest, the queue row plus the library row by rule, "otherwise ticket it"); none pushes to close, age out, or decline; the gate checks pairing, not size. Mitigation: none today.

Open rows (`git show <rev>:<file> | grep -c '^- \[ \]'` over `TODO_LIST.md` + `docs/todo/*.md`):

| Date | Rev | Queue open | Library open | Total | Bytes |
| --- | --- | ---: | ---: | ---: | ---: |
| 2026-09-19 (split day) | `816d177` | 213 | 447 | 660 | 226,055 |
| 2026-09-30 | `dfcfa95` | 458 | 664 | 1,122 | 541,782 |
| 2026-10-24 | `6ce9696` | 1,367 | 1,773 | 3,140 | 2,136,590 |
| 2026-11-17 | `98dfd86` | 3,386 | 3,934 | 7,320 | 3,472,786 |
| 2026-11-24 (HEAD at count time) | n/a | 3,536 | 4,078 | 7,614 | 3,829,914 |

Row events (`git log -p --unified=0` over the same files; "ticked" = a row flipped `[ ]` to `[x]`):

| Window | Open-row lines added | Removed | Net | Rows ticked | Ticked rows pruned |
| --- | ---: | ---: | ---: | ---: | ---: |
| 7 days | 588 | 295 | +293 | 167 | 24 |
| 30 days | 5,862 | 1,493 | +4,369 | 870 | 375 |
| Since the 09-19 split | 10,424 | 3,239 | +7,185 | 1,592 | 1,088 |

- In 30 days: 5,862 open-row lines added against 870 rows closed. About 6.7 added per closure; net +5 per closure.
- The queue (`TODO_LIST.md`): 3,982 lines, 1,492,594 bytes, 3,536 open rows, of which 2,432 `[ready]` and 156 `[blocked:user]`.
- Libraries: 4,078 open rows (2,718 `[ready]`, 315 `[blocked:user]`, 101 `[blocked:push]`, 78 `[blocked:deploy]`, 364 `[watch]`, 480 `[decision]`).
- Human-gated rows across both surfaces: 471 `[blocked:user]` + 480 `[decision]` = 951, spread over 11 files, with no severity dimension.
- Age proxy for the queue's 2,432 `[ready]` rows, by the earliest date mentioned in the row: 1,399 carry no date newer than October, 697 November, 336 no date at all. (A proxy: the earliest date in a row is not its queueing date.)
- 30-day flow by tag (added / removed open-row lines; "added" includes re-added edited rows): ready +4,221 / −1,097; blocked:user +431 / −144; blocked:push +131 / −47; blocked:deploy +93 / −57; watch +420 / −70; decision +566 / −78.
- Corpus weight: `AGENTS.md` 92,624 bytes in 193 lines (loaded by every session); `docs/agents/stability.md` 217,110 bytes; `docs/status/` 1,398 top-level reports, 71 MB for the tree.

### 2. The CI prevention layer is dead

Severity: high. Every gate that exists only in CI (VM tests, the negative-test harness, the built lint-static checks, the dep audit, the history scan) has had no green run for months. Root cause: private `git+ssh` inputs that Actions cannot fetch (`docs/todo/pipeline.md:44`, `:73`), one local-path input (`flake.nix:966`, `project-meta = "git+file:///home/lars/projects/project-meta"`), plus content reds (the `nix-check` job fails at step "Run statix linter"; `dead-guard-lint`). Mitigation: local gated builds only. The owner row for the read-only token dates from 2026-09-03 (82 days); the deploy-key rows are younger (`docs/todo/pipeline.md:44` was found 2026-10-05, `:116` on 2026-11-21).

| Workflow | Runs retained (window) | Successes | Last green |
| --- | --- | ---: | --- |
| Nix flake check | 1,000 (2026-09-17 to now, cap hit) | 0 | 2026-07-29 (118 days) |
| Negative lint tests | 502 (2026-10-10 to now) | 0 | none in the API's history |
| Secret history scan | 1,000 (2026-09-17 to now, cap hit) | 0 | none in the API's history |
| Go deps audit | 583 (2026-09-02 to now) | 7 (all 2026-10-29 to 10-31) | 2026-10-31 |
| nixpkgs compatibility | 110 (2026-08-07 to now) | 110 | 2026-11-24 |

Latest runs: `nix-check` run 45484418850 → `shellcheck` success, `nix-check` failed at "Run statix linter", all 23 `vm-tests (*)` jobs failed. Go deps audit run 45484418826 → "FATAL: nix eval of input outPaths failed", exit 2. The AGENTS.md Prevention Layers table still lists CI as a live layer, with no dead marker.

### 3. Leaked keys in public history, unrotated (by the repo's own record)

Severity: critical if still live. This repository is PUBLIC. `docs/todo/security.md:14` records two still-live keys (one Google, one Context7), last verified live 2026-10-05, discovered 2026-08-18 (98 days), leaked 2026-02-09 (288 days per `scripts/scan-history-secrets.sh`'s header). Root cause: dashboard-only actions, `[blocked:user]` at line 13 to 14 of a library file. Mitigation: none. Not verified here whether the keys are still live (Scope).

### 4. `dead-guard-lint` is red on master

Severity: medium (a lint, but the tree fails a check the repo advertises, and nothing local runs it). Root cause: 4 captures without `|| true`; the pre-commit hook runs `nix flake check --no-build`, which never builds the lint-static checks (`.githooks/pre-commit:457`, "EVAL, never BUILDS"). Mitigation: none. Queued `[ready]` since 2026-10-29 (`TODO_LIST.md:1859`, 26 days).

Local build at `6a5ecfd`, rc=1:

| File:line | Capture |
| --- | --- |
| `modules/nixos/services/cv.nix:1850` | `expiry=$(...)` |
| `modules/nixos/services/cv.nix:1870` | `d=$(...)` |
| `modules/nixos/services/journal-import.nix:231` | `MAPPED=$(...)` |
| `modules/nixos/services/rust-cache.nix:592` | `pct=$(...)` |

### 5. The negative-test harness has never been green, and its signal is buried

Severity: medium. Latest run 45484418690 (head `2ed765c`): "35 passed, 60 failed" of 95.

| Verdict class | Count | Meaning |
| --- | ---: | --- |
| PASS | 35 | control or mutation behaved as expected |
| FAIL, one cause | 54 | `Failed to fetch git repository` for the private `audiblesync` input |
| FAIL, real | 2 | `dead-guard-lint` control + `deadguard/exempt-capture-guard` (item 4) |
| HARNESS BUG | 4 | the mutation no longer applies to the tree |

The 2 real failures sat between 54 identical infrastructure errors. The 4 harness bugs are untracked (`rg "HARNESS BUG|mutation (was a )?NO-OP|expr matched nothing"` over the planning corpus → 0 hits). Three are hardcoded doc counts that drifted: README now says 156 modules (harness mutates "→ 141;"), `FEATURES.md` says 54 packages (harness mutates "46 packages in"), README no longer contains "` → 247;`". The fourth is an invalid sed expression against `platforms/nixos/system/snapshots.nix` (anchor present at `:905`; cause not verified).

### 6. The drain side: `tq-agent-pool` is capped, refused, and restarting

Severity: high for the backlog. Config: `daily-budget = "30"` (`modules/nixos/services/tq-agent-pool.nix:242`), shared by three repos ("3 agent(s) over CV,SystemNix,go-taskqueue" in its own startup log). Journal line counts per day (raw; the "harvest: enqueued" lines appear twice per item in this journal, so that column is an upper bound):

| Date | Harvest enqueued (lines) | Preflight refused: repo has uncommitted changes | Provider rate-limited requeues | Budget blocks / skipped ticks | Unit restarts |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2026-11-22 | 49 | 345 | 22 | 83 | 0 |
| 2026-11-23 | 42 | 112 | 66 | 63 | 73 |
| 2026-11-24 | 51 | 159 | 52 | 27 | 14 |
| Total | 142 | 616 | 140 | 173 | 87 |

- 87 restarts (88 "process exited, code=exited, status=1/FAILURE" lines) between 11-23 05:12 and 11-24. Root cause: not diagnosed.
- Budget line at 21:58: "daily budget exhausted: 39/30 tasks enqueued today; 10 derived runs: 993027 prompt + 2035 completion tokens".
- Arithmetically: ~196 open-row lines added per day (30-day average) against a 30-task daily budget for three repos and 29 rows closed per day in total.

### 7. Live failed units at 22:00 (5 system + 1 user)

| Unit | Observed | Tracked |
| --- | --- | --- |
| `audiblesync-backup-dir.service` | `chmod: changing permissions of '/mnt/pool/backups/audiblesync': Operation not permitted`; first failure 2026-11-24 21:36:57, 3 failures since 11-23; succeeded at 20:46:54 the same day | NO: 0 mentions in the TODO corpus |
| `rust-cache-gc.service` | `touch: cannot touch '/mnt/rust-cache/.gc-stamp': Permission denied` at 21:51:00 | No open row found by the `gc-stamp` grep; probably owned by the active rust-cache session (its report is 21:58) |
| `forgejo-github-sync.service` | exit 1; "Re-interval summary: checked=488 patched=0 already-at-target=487 failed=1" | YES: `docs/todo/services.md:1274` |
| `post-crash-calm-gate.service` | designed REFUSE after 60 min storming | YES: `docs/todo/stability.md:531` (the llama-embeddings re-arm) |
| `service-health-check.service` | lists the failed set, exits 1 (inferred reporter) | not checked |
| `nextd-refresh.service` (user) | listed as failed by the reporter | YES (watch): `docs/todo/services.md:768` |

### 8. This session's own mistakes

Listed in §0: omissions in the first answer (items 2, 3, 4), five failed first probes (item 6), a silent parser gap (item 7).

---

## e) WHAT WE SHOULD IMPROVE

1. **Backlog intake control.** Impact: +4,369 rows per 30 days; the queue cannot be loaded by any agent, so it only ever gets grepped. Fix: a size ratchet in `scripts/check-todo-system.sh` that only moves down (the same pattern as the `audit_max` ratchet in crush-config), plus a per-session rule: close before you open, or at most 3 new rows per session.
2. **Severity before lifecycle.** Impact: 951 human-gated rows carry no severity; the public-key rotation sits at line 13 of a library file. Fix: a "now" list of at most 10 rows at the top of `TODO_LIST.md`, read at session start; everything else waits.
3. **One source for the backlog.** Impact: every item exists twice by rule ("Queue one-liners and their library entries must not drift: edit both"), and rows `docs/todo/pipeline.md:217`, `:227`, `:228` exist only to lint that duplication. Fix: the library is the store, the queue is a generated view; retire the drift lints with it.
4. **Age-out.** Impact: 1,399 of 2,432 `[ready]` rows carry no date newer than October (proxy). Fix: `[ready]` rows unclaimed for 30 days move to `ROADMAP.md`.
5. **Dead-gate marking.** Impact: sessions keep writing "negative-tested" and "CI" into AGENTS.md as if the layer ran. Fix: one sentence in the Prevention Layers table per dead gate with its last-green date, and a session-start probe (last-green age per workflow, open-row delta, pool budget state).
6. **Harness verdict taxonomy.** Impact: 58 of 60 current failures are infrastructure or rot, which hides the 2 real ones. Fix: an INFRA verdict distinct from FAIL, abort the eval groups when the pristine control fails on an input fetch, and derive the doc-count mutations from the live text instead of hardcoded numbers.
7. **A local execution path for the CI-only gates.** Impact: no green run since 2026-07-29 for anything that needs a build. Fix: a PSI-gated nightly timer that builds the lint-static checks and runs the harness and the history scan, with results in the textfile collector.
8. **Pool intake arithmetic.** Impact: 30 tasks per day for three repos against ~196 added rows per day. Fix: an explicit decision (cut intake, raise the budget, or both); and check whether the dirty-tree preflight (616 refusals in 3 days) should run in a clean worktree instead of refusing.
9. **Secret history scan design.** Impact: "intentionally red" means a new hit is invisible among the known ones. Fix: after rotation, exit non-zero only on hits outside a digest baseline; report the known set as a warning with its age.
10. **`ci-watchdog` scope.** Impact: it watches the `domains` canary for an Actions outage, not this repo's workflow conclusions. Fix: extend it to this repo's own workflows once CI can go green.

---

## f) Next tasks (28; not padded to 50: everything below comes from this session's observations, more would be invention)

Impact: Critical / High / Medium / Low. Effort: S (<30 min) / M (30 min to 2 h) / L (>2 h).

| # | Task | Impact | Effort | Category | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | Kill the two public-history keys (delete the Google key in the console project named in the row; rotate the Context7 key) | Critical | S | Security | QUEUED: `docs/todo/security.md:13`, `:14` |
| 2 | Un-dark CI: create the read-only PAT and finish the deploy-key bundles (summit-planner, audiblesync) | Critical | S | Bug | QUEUED: `docs/todo/pipeline.md:73`, `:225`, `:116`, `:44` |
| 3 | Decide the backlog policy: cap intake per session, raise the pool budget, or both | High | S | Decision | NEW |
| 4 | Rule on a bulk age-out of old `[ready]` rows (data-deletion class, needs an owner call) | Medium | S | Decision | NEW |
| 5 | Fix the 4 `dead-guard-lint` captures and rebuild the check locally | High | S | Bug | QUEUED: `TODO_LIST.md:1859` |
| 6 | Triage `audiblesync-backup-dir.service` (chmod EPERM since 21:36:57): stat the directory, check whether `audiblesync-backup` depends on it | High | S | Bug | NEW |
| 7 | Mark the CI layer dead in the AGENTS.md Prevention Layers table, with last-green dates | High | S | Documentation | NEW |
| 8 | Add the backlog size ratchet to `scripts/check-todo-system.sh` | High | S | Quality | NEW |
| 9 | Put a severity-ranked "now" list (max 10 rows) at the top of `TODO_LIST.md`; read it at session start | High | M | Process | NEW |
| 10 | Add the 3-command session-start probe (workflow last-green ages, open-row delta, pool budget state) | Medium | S | Process | NEW |
| 11 | Harness: derive the 3 doc-count mutations from the live text; fix the invalid sed expression (`snapshots.nix` case) | Medium | S | Quality | NEW |
| 12 | Harness: INFRA verdict separate from FAIL; abort eval groups when the pristine control fails on an input fetch | Medium | S | Quality | NEW |
| 13 | Age-out policy: `[ready]` unclaimed for 30 days moves to `ROADMAP.md` | Medium | M | Process | NEW (after 4) |
| 14 | Single-source the backlog (library = store, queue = generated view); retire the drift lints `docs/todo/pipeline.md:217`, `:227`, `:228` | Medium | L | Cleanup | NEW |
| 15 | Diagnose the `tq-agent-pool` restart loop (87 restarts, status=1, 11-23 05:12 onward) | High | M | Bug | PARTLY QUEUED: `docs/todo/services.md:168`, `:470` |
| 16 | Pool dirty-tree preflight: decide between refusing (616 refusals in 3 days) and running in a clean worktree | Medium | M | Design | NEW (related: `docs/todo/services.md:471`) |
| 17 | Local execution path for the CI-only gates (PSI-gated nightly: lint-static build, harness, history scan) | High | M | Feature | related: `docs/todo/pipeline.md:108`, `:31` |
| 18 | Secret history scan: baseline-delta design (green on the known digest set, red on new hits) | Medium | S | Quality | NEW (`docs/todo/security.md:14` covers the allowlist decision only) |
| 19 | `ci-watchdog`: cover this repo's own workflow conclusions once CI can go green | Medium | S | Feature | NEW |
| 20 | `rust-cache-gc` `.gc-stamp` Permission denied (21:51:00): confirm the rust-cache session owns it, else queue | Medium | S | Bug | NEW (unverified) |
| 21 | Re-arm llama-embeddings after the calm-gate refusal | High | S | Bug | QUEUED: `docs/todo/stability.md:531` |
| 22 | `forgejo-github-sync`: one failed PATCH fails the unit (488 checked, 1 failed) | Medium | S | Bug | QUEUED: `docs/todo/services.md:1274` |
| 23 | `nextd-refresh` (user unit) failed | Low | S | Bug | QUEUED (watch): `docs/todo/services.md:768` |
| 24 | AGENTS.md context tax (92,624 bytes in 193 lines) and `docs/agents/stability.md` (217,110 bytes): move dated narratives to the archive | Medium | M | Documentation | NEW (tracking not checked) |
| 25 | After un-dark: first honest full-harness run and re-baseline of the 4 harness-bug cases | High | M | Quality | QUEUED: `TODO_LIST.md:3583` |
| 26 | History purge: purge vs rotation-only decision | Medium | S | Decision | QUEUED: `docs/todo/security.md:23` |
| 27 | A designed refusal (`post-crash-calm-gate` REFUSE) ends as a failed unit and triggers `OnFailure=`; decide whether that should be a non-failed result | Low | S | Design | NEW (tracking not checked) |
| 28 | `scripts/backlog-flow.sh`: one command that prints the inflow/drain tables of §d.1 | Medium | S | Feature | NEW |

---

## g) Questions I can not answer myself

1. **Are the two keys in public history dead yet?** Your row says last verified live 2026-10-05. I can not and will not test a leaked credential, and no doc records a rotation since. If they are live, this is the first ten minutes.
2. **Cap intake or raise the budget?** The pool has a 30-task daily budget shared by three repos while about 196 open-row lines are added per day. That is a money and policy call, not something I can read from the repo.
3. **May I bulk age-out, or must every row be triaged individually?** 1,399 of the 2,432 `[ready]` rows carry no date newer than October (proxy). A scripted move to `ROADMAP.md` is a data-loss-class change, so I will not decide it.

---

## Harvest

NOT HARVESTED. Deliberate, recorded here per the AGENTS.md escape clause ("or explicitly recorded as deliberately not harvested because X"):

1. The owner instruction for this report ends with "THEN WAIT FOR INSTRUCTIONS".
2. 9 of the 28 §f items already have rows (cited in the Status column); re-queuing them would duplicate.
3. The remaining 19 new items (f 3, 4, 6 to 14, 16 to 20, 24, 27, 28) would be added to a backlog this report measures as net +4,369 rows in 30 days. They are written row-ready above so one pass can land them without re-derivation, once instructed.

---

## Reproduce

```bash
gh run list --workflow "Nix flake check" --limit 1000 --json conclusion,createdAt
gh run list --workflow "Negative lint tests" --status success --limit 3
gh run view 45484418690 --log                                   # negative-test harness, latest
nix build .#checks.x86_64-linux.dead-guard-lint --no-link         # rc=1 at 6a5ecfd
busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager ListUnitsFiltered as 1 failed
git show 6ce9696:TODO_LIST.md | grep -c '^- \[ \]'               # queue open rows at a past rev
git log --since="30 days ago" --format='@@@%ad' --date=short -p --unified=0 -- TODO_LIST.md 'docs/todo/*.md'
journalctl -u tq-agent-pool.service --since "2026-11-22 00:00" --no-pager -o short-iso
```

---

## Correction (2026-11-25, appended by the same session; nothing above was rewritten)

**§d.1 names the wrong cause.** The counts stand: 660 open rows on 2026-09-19, 7,614 at 22:20 on 2026-11-24, +4,369 in 30 days, 870 rows ticked. The sentence "every rule pushes sessions to add rows" does not explain them. Measured later the same night: 1,538 rows were added to `TODO_LIST.md` on 2026-11-07 in one bulk harvest (1,114 `[ready]` add events, 73 percent of the dated ones from reports 7 or more days old) while v5's T03 and T04 were being executed. 1,509 of them are still open, 43 percent of the open queue, with 26 closed in 17 days. The weekly ready-line adds around that day were 222 (week of 10-26), 1,350 (week of 11-02), 284 (11-09) and 183 (11-16). So the organic inflow is 26 to 40 ready-line adds per day, and one day's harvest is the bulk of the growth. Corrected statement: the queue is net-additive, and a single bulk harvest accounts for about 1,500 of its rows. Source: `docs/status/2026-11-24_23-38_planning-run-queue-tripled-by-11-07-bulk-harvest-masterplan-lineage-v5-status.md` §d.1.

**The age proxy in §d.1 reads differently with that known:** the 1,393 `[ready]` rows whose earliest date is September or October are mostly that back-harvest, not slow organic aging.

## Harvest log (2026-11-25; docs-health HARVEST; premise re-checked 2026-11-25 for every row)

28 items: 17 new rows covering 18 items (9 `[ready]` rows with a queue line, 8 library-only gated rows), 9 existing rows, 1 declined.

| Source (report §item) | Disposition | Destination / reason |
| --- | --- | --- |
| §f.1 keys | existing row | `docs/todo/security.md`: the PERSISTENT NAG row and the "scan stays red until 2 rotations" row; owner action |
| §f.2 CI auth | existing row | `docs/todo/pipeline.md`: 4 rows (branching-flow input, read-only PAT, summit-planner key, create the token); owner action |
| §f.3 intake policy | new row | `docs/todo/pipeline.md` `[decision]`: Backlog intake policy: per-session cap or close-before-open |
| §f.4 age-out ruling, §f.13 age-out policy | merged | one new `[decision]` row in `docs/todo/pipeline.md`: The 2026-11-07 harvest block (1,509 open queue rows) |
| §f.5 dead-guard-lint | existing row | `TODO_LIST.md`: Fix dead-guard-lint control failure blocking the CI negative-test harness |
| §f.6 audiblesync-backup-dir | new row | queue + `docs/todo/services.md` `[ready]`: Triage audiblesync-backup-dir.service: chmod EPERM on the backup directory |
| §f.7 AGENTS.md dead marking | new row | queue + `docs/todo/pipeline.md` `[ready]` |
| §f.8 size ratchet | new row | queue + `docs/todo/pipeline.md` `[ready]` |
| §f.9 NOW list | new row | queue + `docs/todo/pipeline.md` `[ready]` |
| §f.10 session-start probe | new row | queue + `docs/todo/pipeline.md` `[ready]` |
| §f.11 harness doc-count mutations | new row | queue + `docs/todo/pipeline.md` `[ready]` |
| §f.12 harness INFRA verdict | new row | queue + `docs/todo/pipeline.md` `[ready]` |
| §f.14 single-source | new row | `docs/todo/pipeline.md` `[decision]` |
| §f.15 pool restart loop | existing row | `docs/todo/services.md`: 3 pool rows (start-limit placement, unstick, gate refusals); annotate at execution, no new row |
| §f.16 pool dirty-tree preflight | new row | `docs/todo/services.md` `[decision]`: Pool: dirty-tree preflight and the 30-per-day budget shared by three repos |
| §f.17 local gate path | new row | queue + `docs/todo/pipeline.md` `[ready]` |
| §f.18 secret-scan baseline | new row | `docs/todo/security.md` `[decision]` |
| §f.19 ci-watchdog extension | new row | `docs/todo/services.md` `[blocked:user]` |
| §f.20 rust-cache-gc stamp | declined | no journal entry since the 21:51 failure and the rust-cache session owns the unit; reason to re-evaluate: a new EPERM line at its next run |
| §f.21 llama re-arm | existing row | `docs/todo/stability.md`: the calm-gate failure row |
| §f.22 forgejo-github-sync | existing row | `docs/todo/services.md`: the failing exit 1 row |
| §f.23 nextd-refresh | existing row | `docs/todo/services.md`: the watch row; the fix lives in the nextd repo |
| §f.24 AGENTS.md context tax | new row | `docs/todo/pipeline.md` `[decision]` |
| §f.25 honest harness run | existing row | `TODO_LIST.md`: the Red-CI pair row |
| §f.26 history purge | existing row | `docs/todo/security.md`: the purge versus rotation-only row |
| §f.27 designed refusals | new row | `docs/todo/pipeline.md` `[decision]` |
| §f.28 backlog-flow script | new row | queue + `docs/todo/pipeline.md` `[ready]` |
