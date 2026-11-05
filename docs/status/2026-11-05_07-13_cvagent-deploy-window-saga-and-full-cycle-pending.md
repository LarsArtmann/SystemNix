# Status report — cvagent deploy-window saga: three pages, one storm, the fix still riding a parallel deploy

**When:** 2026-11-05 07:13 CET
**Session:** continuation of the 2026-11-05_02-45 report. Covers 02:36 → 07:13: the overnight attempt to deploy the 90min `TimeoutStartSec` fix, three truthful OnFailure pages (all the OLD 20min generation), the deploy-gate wars (including a self-inflicted eval storm), the discovery that a PARALLEL session is deploying evo-x2 tonight, and the currently-running gen-wait chain that will trigger the first FULL production cycle the moment their gen lands.
**Predecessors:** 2026-11-04_20-46 (dead unit + fix), 2026-11-05_02-45 (AI wave + timeout discovery).

---

## Scope line — what this report VERIFIES vs does NOT verify

**Verified with fresh commands/artifacts:**

| Claim | Evidence |
| --- | --- |
| Page #3 fired (06:17) — the 05:53 timer ran the OLD gen | `journalctl -u cvagent.service --since "2026-11-05 02:34"` → `06:17:00 start operation timed out … Failed with result 'timeout'` (20min budget, ~13 repos again) |
| The 90min fix is COMMITTED but NEVER DEPLOYED | `grep -c 90min modules/nixos/services/cvagent.nix` = 1; file NOT dirty (daemon-swept); latest profile still `system-982-link` (02:07); live unit says `TimeoutStartSec=20` (read from the resolved store unit) |
| Deploy gate refused repeatedly — with real reasons each time | 00:37: PSI 29.5% + nvme 97%; 01:01: PSI 37.4% + both nvmes ~100% + ghostty-6994 (MY scope — the retry evals); 06:48: PSI 50% + **sdb (pool disk) 103.6%** + ghostty-7353/7130 (other sessions) |
| A parallel crush session is deploying evo-x2 tonight | deploy lock holder PID 257366 → parent `crush -y`, cwd `/home/lars/projects/quotaboard`; its switches: gen 980 (23:22), 981 (01:35), 982 (02:07); at 07:11 ANOTHER of its deploys held the lock (PID 3421838, pre-deploy-check `nix flake check` running) |
| My 07:11 trigger ran the OLD gen and its run is in flight | gen still 982 at 07:12; unit started 07:11 with `TimeoutStartSec=20` → expected TERM ~07:31 (page #4, truthful); journal check at 07:12 showed no failure yet (still running) |
| The passive-watch pattern itself worked | `deploy-passive.sh` caught sustained calm at 01:03 in 3 polls; `deploy-today.sh` caught it at 06:53 and 07:11 — the failures after that were LOCK conflicts and gate legs, not detection failures |
| The 02:45 report's chain died with the harness cycle | `job_output 04F` → "background shell not found" at 06:39; the box had sat unwatched 02:38–06:39 (hence page #3 landed unhandled) |
| HEAD carries every fix | 90min fix + wave all daemon-committed; `git log` shows `290700b66` (another session's freeze-gate work) on top |

**NOT verified here (and why):**

- **`done: scanned=24 failed=0`** — still never printed. The gen-wait chain (`wait-deploy-battery.sh`, live) triggers + verifies the moment the parallel deploy lands (horizon 20:00; 12:00 fallback = deploy ourselves if their deploy stalls).
- **Mesh artifacts in the CV checkout** — every cycle so far died pre-mesh; nothing shipped yet.
- **Pages #4** — expected ~07:31 (old-gen run my 07:11 trigger started); journal not yet showing it at write time (still running at 07:12).
- **What saturated sdb this morning** — 103.6% util observed twice (06:48, ~07:00); the owning job was not identified (storage-domain forensics out of this session's scope; morning backup/blocklist class suspected, NOT verified).
- **gen 980/981 authors** — 981 (01:35) landed during my lock-conflict window; attribution between the quotaboard session's two deploys not separated.

---

## a) FULLY DONE

| Work | Evidence | Scope |
| --- | --- | --- |
| 90min budget fix, live numbers in comment | cvagent.nix `TimeoutStartSec = "90min"`; eval green; committed (tree clean) | cvagent.nix |
| Deploy-orchestration pattern PROVEN (passive watch) | caught sustained-calm windows 01:03, 06:53, 07:11 with zero-eval polls | ~/.cache/cvagent scripts |
| Self-storm root cause found and eliminated | 01:01 gate dump: stalled cgroup = own ghostty scope; loop redesign to /proc-only polls | process |
| Gate-refusal taxonomy mapped | three distinct refusal causes observed and handled: PSI storm, deploy lock, gate legs | live system |
| All wave work committed on HEAD (rides every future deploy) | HEAD `290700b66` includes 90min fix + AI wave; parallel deploy carries it | git |
| Page taxonomy documented: 05:56 (PATH bug), 02:33 (my budget), 06:17 (timer on old gen), ~07:31 (expected, my trigger on old gen) | journal evidence per page | live system |
| 02:45 report + harvest complete | 3 rows queued; questions asked (interrupted by owner's execute directive — defaults stand) | docs/todo |

## b) PARTIALLY DONE

1. **First full 24-repo production cycle** — TWO partial cycles banked AI facts per-repo (02:14 and 06:07 runs, ~13 repos each pass, facts persist); the run STILL has never reached mesh. Waiting on: gen > 982 (quotaboard deploy in flight) → auto-trigger → ~60min scan. Chain live (`wait-deploy-battery.sh`). Effort: S (automatic).
2. **The 90min fix's deployment** — committed, not live; owned by the parallel session's in-flight deploy (or my 12:00 fallback in the chain). Everything else in the wave is already LIVE on gen 982.

## c) NOT STARTED

| Planned | Why | Priority |
| --- | --- | --- |
| sdb saturation owner (06:4x storm source) | storage-domain job — needs the storage runbook lens, not this session | Medium (watch) |
| post-deploy-check §-leg / runtimeInputs audit / health preflight | queued 2026-11-04 20:49, untouched | High/Medium |
| week-one AI-facts review + upstream maxCommitSample knob | queued 02:45, untouched | Medium |
| Cross-session deploy coordination probe (who-is-deploying check before wait loops) | identified tonight (§e), not built | Low |

## d) TOTALLY FUCKED UP

1. **The harness cycle silently killed my overnight deploy chain** — job 04F "background shell not found" at 06:39; the box sat unwatched 02:38–06:39, the 05:53 timer fired the OLD gen unhandled, and page #3 landed with no one on the wall. The lesson is structural: background jobs do NOT survive harness cycles — anything that must eventually happen needs either (a) a systemd unit/timer (the repo's own doctrine: convergers ride deploys) or (b) re-establishment on every session resume. My chain should have been a oneshot timer, not a shell job.
2. **Four truthful pages in one day for ONE root cause chain** (05:56 PATH bug — pre-existing; 02:33 my 20min budget; 06:17 timer on old gen; ~07:31 my trigger on old gen). Pages 2–4 are all MY sequencing: I sized a budget from an assumption, then triggered a unit on a generation that predated the fix. The correct sequence — deploy-landed CHECK before trigger — existed in the plan but my script fired 45s after a lock-conflict "deploy" that never deployed.
3. **My deploy script treated a lock-conflict as success** (grep only for `DEPLOY_FORCE_PRESSURE`) — the 07:11 "deploy" never deployed, yet the script proceeded to trigger the unit and label the outcome UNIT-FAILED, sending me chasing the wrong layer. The failure taxonomy (gate-refusal / lock-conflict / gen-not-bumped) was only complete after this fourth page.
4. **The gate wars cost ~4 hours** across self-storming eval loops (00:27–01:00), a miscalibrated busy proxy, harness-cycle death (02:38–06:39 gap), and lock conflicts (07:11). The DEPLOY ITSELF was never the problem — the tree was green and committed since 02:34.

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Suggested fix |
| --- | --- | --- |
| Long-running intent dies with the session | page #3 landed unhandled | "intent that must survive = systemd timer, not background shell" — a `cvagent-deploy-when-calm.timer` class pattern, or the tq-gate precedent: converge via units, not loops |
| Trigger-before-verified-deploy | page #4 | any post-deploy trigger must assert `readlink /run/current-system` == newest gen AND the expected unit content (grep the live unit file) BEFORE `StartUnit` |
| Deploy failure taxonomy | lock-conflict misread as success | the deploy script family should classify: gate-refusal / lock-conflict / success — by output grep, not exit code |
| Multiple sessions deploying one box | three switches tonight, all uncoordinated, all green (the lock works) but each session wastes rounds discovering the others | before waiting loops: `/proc` fd-scan the deploy lock + `readlink` the profile — one command answers "someone else is deploying HEAD" |
| The 20min→90min class of error | one page | measured-numbers-in-comments (now in the module); extend to a checklists line in CONTRIBUTING: timeout changes cite measurements |

## f) 50 things to get done next (disposition-marked)

**NEW-HARVEST** = queued with this report. **QUEUED** = existing rows. **RIDES-CHAIN** = the live gen-wait chain completes them. **UPSTREAM** = Code-To-CV-Agent. **ROADMAP** = brainstorm/decision fuel.

| # | Task | Impact | Effort | Category | Disposition |
| --- | --- | --- | --- | --- | --- |
| 1 | First full cycle: `done: scanned=24 failed=0` + extractor mix + CV artifacts + anchor | Critical | S | Bug | RIDES-CHAIN (auto after gen > 982) |
| 2 | Make deploy-intent survive sessions: systemd-timer convergence pattern for deploy-when-calm | High | M | Infra | NEW-HARVEST |
| 3 | Deploy scripts: outcome classification (gate/lock/success) + assert gen bump before triggers | High | S | Quality | NEW-HARVEST |
| 4 | Identify the sdb saturation job (06:4x storage storm) via storage runbook | Medium | S | Bug | NEW-HARVEST |
| 5 | Cross-session "who is deploying" probe into the deploy docs | Low | S | Tooling | ROADMAP |
| 6 | Week-one AI-facts quality review | High | M | Quality | QUEUED (02:45) |
| 7 | Upstream `ai.maxcommitsample` knob | Medium | S | Feature | QUEUED (02:45) |
| 8 | post-deploy-check §-leg for cvagent | High | S | Quality | QUEUED |
| 9 | Eval-time audit: writeShellApplication vs runtimeInputs | High | M | Quality | QUEUED |
| 10 | `cvagent health` preflight in unit | Medium | S | Quality | QUEUED |
| 11 | system-health oneshot metric verification | Medium | S | Quality | QUEUED |
| 12 | Clean /home/lars/.cache/cvagent script zoo (4 deploy variants + probe; keep 2) | Low | S | Cleanup | ROADMAP |
| 13 | Deploy monitor365 tmpfiles mkBefore + legs | High | S | Bug | QUEUED |
| 14 | Why tmpfiles-setup didn't re-run on 977/978 | High | M | Bug | QUEUED |
| 15 | monitor365 dmesg SECCOMP loop | High | S | Bug | QUEUED |
| 16 | tq-agent-pool first calm window | Medium | S | Ops | QUEUED |
| 17 | PMA stale-binary check | High | S | Quality | QUEUED |
| 18 | OTel 4318 refusals owning unit | Medium | S | Bug | QUEUED |
| 19 | freeze-#46 residuals | Medium | M | Bug | QUEUED |
| 20 | Stalwart CalDAV probe | Medium | S | Verify | QUEUED |
| 21 | All-Backups-Healthy gatus deploy | High | S | Bug | QUEUED |
| 22 | mkPoolDirUnit audit | Medium | M | Quality | QUEUED |
| 23 | pim-sync flip ladder | High | M | Feature | QUEUED (blocked:user) |
| 24 | indexer-web smoke + ioTier | Medium | S | Quality | QUEUED |
| 25 | paperless-tasks-collector fixture | Medium | M | Quality | QUEUED |
| 26 | buildcache-recovery VM legs | Medium | M | Quality | QUEUED |
| 27 | FOD probe productization + lock-node doc | Medium | S | Tooling | QUEUED |
| 28 | Upstream: humanize residue commit status | High | S | Hygiene | UPSTREAM |
| 29 | Upstream: technologys export propagation | Medium | S | Bug | UPSTREAM |
| 30 | Upstream: "1 repos" bug | Low | S | Bug | UPSTREAM |
| 31 | Upstream: watch two-pass E2E | Low | M | Quality | UPSTREAM |
| 32 | Upstream: a11y audit | Low | M | Quality | UPSTREAM |
| 33 | Upstream: hermetic CSS | Low | M | Quality | UPSTREAM |
| 34 | Upstream: CI unblock | Medium | — | Infra | UPSTREAM (blocked:user) |
| 35 | Upstream: determinism E2E | Low | S | Quality | UPSTREAM |
| 36 | Upstream: AI E2E vs mock | Low | M | Quality | UPSTREAM |
| 37 | Decide: repo-list cutline after first full cycle | Medium | — | Decision | ROADMAP (owner) |
| 38 | Decide: GLM credit budget | Medium | — | Decision | ROADMAP (owner) |
| 39 | Decide: AI-facts review cadence | Medium | — | Decision | ROADMAP (owner) |
| 40 | Decide: cvagent input rev-pin | Low | — | Decision | ROADMAP |
| 41 | Decide: cvagent.db backup leg | Low | — | Decision | ROADMAP |
| 42 | mesh diff-preview before PMA commit | Low | M | Feature | ROADMAP |
| 43 | per-oneshot duration metric | Low | M | Feature | ROADMAP |
| 44 | cvagent on darwin? | Low | — | Decision | ROADMAP |
| 45 | facts-explorer tile | Low | M | Feature | ROADMAP |
| 46 | event-journal retention policy | Low | S | Quality | ROADMAP |
| 47 | keyword drift report | Low | M | Feature | ROADMAP |
| 48 | 05:53 slot collision check | Low | S | Verify | ROADMAP |
| 49 | integration-registry: first-fire rule + manual≠unit rule (cvagent case) | High | S | Process | ROADMAP |
| 50 | Upstream: mesh --dry-run; prove-or-retire watch | Low | M/S | Feature/Cleanup | ROADMAP |

## Self-harvest ledger

- **Harvested NOW (07:13)**: §f 2 → TODO_LIST.md + pipeline.md (deploy-intent-as-timer + outcome classification are pipeline-domain); §f 4 → TODO_LIST.md + storage.md. The first-full-cycle completion row (02:45) remains the umbrella for §f 1 — updated there, not duplicated.
- **Deliberately NOT harvested**: §f 5, 12 (session-local scripts/process, recorded here); §f 28–36 (cvagent repo's own queue); §f 37–50 ROADMAP fuel with owner decisions marked.

## g) Questions I cannot answer myself

Three surfaced at report time (same set as 02:45 — the interrupted ask): GLM credit budget for ~24 daily calls; AI-facts quality gate (auto-ship vs review pass); accept 60–90min daily scan window or trade scope. Defaults I proceed on until answered: watch ai-meter, week-one review row stands, 90min budget stands.

---

*Then wait for instructions.*

---

## ADDENDUM 2 — first full cycle DONE + owner answers applied (2026-11-05 21:3x)

**Owner answers (Q1/Q2/Q3):** set a credit ceiling; week-one review stands; keep the 60–90min window. All three applied.

| Item | State | Evidence |
| --- | --- | --- |
| FIRST FULL PRODUCTION CYCLE | DONE 09:43 | journal: `done: scanned=23 failed=1` (gen 983's 90min budget, ~60 min run; carried by the parallel quotaboard-session deploy) |
| Production AI facts | 506 ai / 50 rule-based | `cvagent facts --json` extractor counts; 2 z.ai timeouts fell back cleanly (09:06, 09:37) |
| Mesh artifacts | LANDED | `data/cv/lars_artmann-en-cvagent.patch.json` (23 KB) + 26 files in `data/projects-v2/` (22 generated pages); PMA committed |
| The 1 failed repo | buildflow — NO checkout exists (`stat: no such file or directory`; meta lists it at 95) | journal 08:40:40; REMOVED from the list (23 repos now); clone decision queued |
| Credit ceiling (Q1) | WIRED in tree | `aiDailyFactCap = 600` run-level gate (rule-based day when today's ai facts ≥ 600); awk counter VERIFIED against production (506/600 = under); constructs proven via standalone writeShellApplication build (shellcheck+bash -n green) + execution rc=0. Ceiling is fact-count-based until ai-meter proxy routing lands (queued row — cvagent AND cv-agent bypass the meter today) |
| Week-one review (Q2) | MATERIAL READY | `~/.cache/cvagent/delta-week1.html` (110 KB, `cv render --variant cvagent`); patch = 50 add-ops (keywords like Bash / Go concurrency / Go modules) |
| Scan window (Q3) | STANDS | 90min live on gen 983; measured 60 min sequential |
| Ceiling eval verification | BLOCKED externally | the freeze-49 session's still-running float wave holds the lock-float audit red fleet-wide (art-dupl/bank-sync/branching-flow + more drifted vs expected-locks.nix; their Go-cache move commit landed 21:1x mid-wave). NOT fixed by this session per the registry-proof doctrine (never green the registry without proven FODs). The ceiling rides the next green eval/deploy — before tomorrow's 05:53 timer either way |
| Fleet breakage flag (not mine) | OPEN | the red lock-float audit blocks ALL deploys/evals until the freeze-49 wave lands its expected-locks rows — flagged per the attribution rule |

**Not harvested:** the delta-review pass itself is the queued week-one row (material path recorded here); the Go-cache hot-tier move and freeze-49 residuals belong to their sessions.
