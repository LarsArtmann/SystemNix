# Window RE-VERIFICATION (same-window dispatch): monitor365 batch + reviewer-fix wave (2026-11-20 02:39 → 2026-11-21 02:09)

**Report time:** 2026-11-21 19:57 CET (filled through ~20:1x) · **HEAD at write:** `c702d9147` · **Window:** 5 completed tasks (`…a1f663640671c2715a50a`, `…a1f6b5cea37af43db6b541`, `…a1f7315ef9d55acfb2d91b`, `…a1f73f3fc5d86081479e34`, `…a1f73f3f65a75321626872`) · **Dispatch-time dedup:** HIT — `docs/status/2026-11-21_02-14_window-closeout-monitor365-batch-plus-reviewfix-wave.md` (commit `8ef8d3807`) covers this EXACT task set (all 5 IDs in its header; its own dedup section already excluded the 2026-11-20 03:04 window as a different five). This is the protocol's verification-only re-pass: a)–d) satisfied by citation to that report, each §a landing re-grepped green/red at HEAD below, live state probed fresh, band drift read fresh. The double dispatch itself is recorded as §e.1 and minted as a TODO row.

**Verification method:** earlier report read FIRST; its §a landings re-grepped at HEAD (`c702d9147`); live claims probed against the running system (`/run/current-system`, `/nix/var/nix/profiles`, `/var/log/systemnix-deploys/`, journalctl windows 2026-11-21 00:00→06:00 and now); tq facts table (`/mnt/pool/services/tq/tq.db`) re-read with corrected epoch math; TODO_LIST rows re-read for tick eligibility. Nothing re-derived from the closeouts beyond what HEAD/live confirms.

## a) FULLY DONE

Satisfied by citation: the earlier report's §a (all 5 tasks itemized). Re-verification of each headline landing at HEAD `c702d9147` — **all GREEN**:

| # | Task                | Landing                                                                       | HEAD evidence                                                                                                                                                                                                                              | Verdict |
| - | ------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- |
| 1 | `…a1f663` item 1    | PapDashboard pre-commit reds repaired, out-of-scope legs minted               | rows present (file-size wave, go-directive wave)                                                                                                                                                                                           | GREEN   |
| 1 | `…a1f663` item 4    | SSO identity heal row reworded to SESSION-level (fix `88096cdb2`)             | TODO_LIST:499 + `docs/todo/services.md:1236` both carry the session-level caveat                                                                                                                                                           | GREEN   |
| 1 | `…a1f663` item 5    | buffer-pressure alert TEXT rewritten to real cgroup-memory-pressure semantics | `system-health.nix:3129` — "cgroup memory pressure: usage >= N% of memory.max or an OOM kill this boot. Post-shrink floor is ~1G/8G"                                                                                                       | GREEN   |
| 2 | `…a1f6b5` item 1    | retention stderr capture                                                      | `scripts/monitor365-retention.sh:54,85,116` (both failure paths + journal WARNING naming the file)                                                                                                                                         | GREEN   |
| 2 | `…a1f6b5` item 2    | one-shot stamp-gated compact, ARMED                                           | `monitor365-retention.sh:124-136` (RETENTION_COMPACT block + stamp)                                                                                                                                                                        | GREEN   |
| 2 | `…a1f6b5` item 3    | pool-copy `wants` edge dropped                                                | no pool-copy wants lines at HEAD; ordering comment replaced by guard reference (`monitor365.nix:712`)                                                                                                                                      | GREEN   |
| 2 | `…a1f6b5` items 4-5 | fs_event semantics source-verified + 90d ratified                             | `monitor365.nix:101-103` ("CONFIRMED 90d hot window (2026-11-20, task 000001a1f6b5)")                                                                                                                                                      | GREEN   |
| 3 | `…a1f7315`          | reviewer fix: session-level rewording on both surfaces                        | TODO_LIST:499 + services.md:1236 verified verbatim                                                                                                                                                                                         | GREEN   |
| 4 | `…a1f73f3fc5`       | count-gate diagnostics (`fae398442`)                                          | `monitor365-retention.sh:155` — real diagnostics line, no stale-stderr `LOG_ERR` clobber                                                                                                                                                   | GREEN   |
| 5 | `…a1f73f3f65`       | After= truth + fail-closed pool-copy guard (`7b81bfd3e`)                      | `scripts/monitor365-pool-copy-guard.sh` + `scripts/test-monitor365-pool-copy-guard.sh` on disk; `checks.monitor365-pool-copy-guard-selftest` wired at `flake/parts/checks/selftests.nix:341`; guard referenced in `monitor365.nix:712,751` | GREEN   |

**NEW since the earlier report — the deploy-gated night-1 evidence LANDED CLEAN tonight (2026-11-21 03:00 window, gen-1020):**

1. **Compact fired exactly once**: journal `03:01:07 monitor365-retention: compact done — file 13090435072 -> 3846713344 bytes (1579353 rows preserved)` — 13.09 GB → 3.85 GB, count-gate PASSED (no `count-gate FAILED` line, no `count-gate mismatch`), so the feared pre-`fae398442` diagnostics branch was never exercised.
2. **Backup fired exactly ONCE** (03:00:00 start → 03:01:10 Finished; NO ~03:25 second export+retention) — the un-couple's double-fire is dead in production.
3. **Pool-copy fired exactly once** (03:27:45, its timer, no backup-restart upstream) and **landed the fresh copy**: `04:10:42 …/backups/monitor365.duckdb.backup_20261121T020011Z.db (13090435072 bytes) — off-NVMe leg fresh`.
4. Retention DELETE boundary ran clean (0 due, window 90d, 1,579,353 rows remaining); no failure → the retention-stderr.log mechanism stays live-unverified by design (its row needs a REAL failure, `[blocked:deploy]`, unchanged).

## b) PARTIALLY DONE

1. **The carrying deploy was MID-FLIGHT at report time.** The deploy that carries the two undeployed fix-waves (count-gate diagnostics `fae398442`, pool-copy guard `7b81bfd3e`) plus the rider wave (paperless ALLOWED_HOSTS `14ec73b28`, summit-planner, crm fixes, audio_stream collector) started **19:27:50** (log `/var/log/systemnix-deploys/2026-11-21_19-27-50.log`; holder pid 2387084 alive at 19:57; log tail shows the switch in progress — user-unit reloads + start list including `monitor365-server.service`, `paperless-web.service`, `paperless-gpt-token.service`, `crm-server.service`, `gatus.service`). Rival attempts bounced rc=14 foreign-lock (19:30:18, 19:35:09 — correct refusal behavior). **Newest profile was still `system-1020-link` when last read**; per anchor discipline this deploy's outcome is PENDING at write time — judged by nobody until the full process tree exits and `readlink /run/current-system` matches the newest `system-N-link` by NUMBER. The v2 orchestrator that owned this fire (deadline 19:27:53, per `docs/status/2026-11-21_14-13_v2-orchestrator-armed-eval-broken-monitor365-wave.md`) expires exactly at the observed start.
2. **Night-2 legs pending (tomorrow ~03:1x)**: compact must NOT re-fire (stamp suppression) and backup/pool-copy must stay single-fire → then row 3813 (`[blocked:deploy]` fire-once + disarm) becomes tickable and the `RETENTION_COMPACT="1"` env line gets deleted. Row 3814 (pool-copy no-re-fire) was satisfied by its own one-night terms TONIGHT and is ticked by this pass (see queue-surface changes).
3. **Post-deploy verification chain** (once the in-flight deploy anchors): paperless-gpt green + DisallowedHost recount, paperless loopback fix live-verify, §17 memory sweep, gatus sweep, crm 3-fix-wave battery legs, summit-planner checks — all pre-tracked rows (paperless row; 14-13 report §c.1); nothing new minted.
4. **Owner-gated rows unchanged**: fresh SSO login capture (row 3797), pre-shrink trash 39G (row 498), compact-upstream decision (row 3822), rider-wave prioritization row.
5. **02-39 batch residuals unchanged**: volume-batch re-fire + storage-history ledger items ride their existing rows.

## c) NOT STARTED

Cited from the earlier report §c; re-verified still-unchecked at HEAD today: `scripts/tick-todo-row.sh` helper, scripts/ evidence-truncation sweep, fleet oneshot-wants audit, compact fixture legs (must target the NEW count-gate branch shape post-`fae398442`), compact runbook row, upstream `[decision]`, SSO login + pre-shrink trash (owner-gated), plus the 02-14 closeout's own minted rows 3833–3837 (standalone script re-verify, gatus-text sweep, journal-consumer check, systemd.md gotcha, runbook guard line). None moved this window; no silent drops.

## d) TOTALLY FUCKED UP

Cited from the earlier report §d (footer-invisible fifth-task landing in daemon commit `7b81bfd3e`; false `After=` claim costing a paid re-dispatch; count-gate bug shipped armed before its diagnostic fix; evidence-scope overclaim on the SSO row; 04-49 session's ~40% wall-time churn). Observed fresh this pass:

1. **796c85450** (today): a shellcheck SC2034 (`fed_err` unused local in `pap_section22`, introduced by the §22 federation-gate commit `7566a4728` earlier today) broke the pre-deploy-check build and **blocked every deploy** until fixed. Same silent-gate-blocks-deploys class as the day's eval break (below): two separate deploy-blocking regressions in ~10 h, neither surfaced by a gate — both found by deploy attempts failing. Fixed same-day; noted for the record.
2. **The eval-broken regime 09:25→14:05 today** (`audio_stream` lock-float class, owned in the 14-13 report) — adjacent window, already self-reviewed there; counted here only because it + (1) means the deploy chain spent most of the day blocked by two independent silent regressions.
3. **Method flaw found in the earlier report's §h (conclusion unaffected)**: its band-drift query used epoch `1763602800000` labeled "2026-11-20 00:00 CET" — the literal actually decodes to 2025-09-20, i.e. the query effectively scanned ALL history. My fresh read with corrected math confirms the same verdict (see §h), so the cited conclusion stands, but epoch literals in analysis queries need the same known-value check the quote-scrutiny rule gives pipeline numbers.
4. In passing: the 19:30/19:35 rc=14 foreign-lock refusals were the lock guard working as designed against the live 19:27 holder — rivalry, not damage.

## e) WHAT WE SHOULD IMPROVE

1. **THE DOUBLE DISPATCH (this pass's own finding):** the queue re-fired a done-prompt for a window whose canonical closeout landed ~17.5 h earlier (02:14 today, verdict recorded, every task `completed`). The dispatch-time dedup check caught it (this re-pass instead of a duplicate full derivation), but the ROOT fix is queue-side: a done-prompt window should be watermarked by the max `completed_at` it covers — a later fire covering a strictly older window is a no-op candidate, not a dispatch. Minted as a `[ready]` TODO row (pipeline).
2. **Epoch literals are quoted numbers**: the §d.3 method flaw generalizes the quote-scrutiny rule — any timestamp/epoch constant in an analysis query gets one known-value decode before its result enters a report.
3. **Multi-night verification rows should name their evidence file**: rows 3813/3814 spanned nights and the night-1 evidence lived only in tonight's journal; this report is now the durable citation. Convention: the closeout that mints a `[blocked:deploy]` verify row says WHERE the per-night evidence will be recorded (the next window report).
4. The earlier report's §e items (premise-check semantic claims; reviewer-fix daemon-race exposure; armed-vs-diagnostic sequencing; generation-recording on deploy-gated rows; daemon-swept re-verify; lock-wait discipline line) all remain open and correct — carried, not re-derived.

## f) NEXT THINGS

1. **Tonight/tomorrow ~03:1x (2026-11-22)**: night-2 journal read — compact must NOT re-fire (stamp), backup + pool-copy single-fire again → then tick row 3813 and delete the dead `RETENTION_COMPACT="1"` env line (the disarm half of that row).
2. **Verify the in-flight 19:27:50 deploy**: full process tree exits → anchor-by-number (`readlink /run/current-system` == newest `system-N-link`) → then the post-deploy battery: paperless-gpt active + DisallowedHost ~0, paperless loopback fix live, crm unit green (TimeoutStartSec), summit-planner `/healthz` + :7612, gatus sweep, §17 memory re-read (all pre-tracked rows).
3. **Row 3833 standalone re-verify** — now twice-overdue: run `scripts/test-monitor365-pool-copy-guard.sh` + shellcheck the three scripts + confirm the selftest evals (the deploy now carries them; daemon commits bypassed the lint legs at landing).
4. **Minted this pass**: post-deploy confirm the LIVE generation's `monitor365-pool-copy` unit carries the ExecStartPre guard + the deployed retention script carries the `fae398442` count-gate branch (live-unit check, distinct from row 3833's script-level re-verify).
5. Compact fixture legs (row 3818) — target the NEW diagnostics branch shape.
6. Compact runbook row + guard runbook line (rows 3837 + runbook row) — fold together, post-compact figures (3.85G observed) into `docs/services/monitor365.md`.
7. gatus alert-text sweep (row 3834), journal-consumer check (row 3835), systemd.md `After=` gotcha (row 3836).
8. tick-todo-row helper, evidence-truncation sweep, fleet oneshot-wants audit (existing rows).
9. tq window-watermark improvement (minted this pass, §e.1).
10. Owner-gated standbys: SSO login capture (3797), pre-shrink trash (498), upstream compact decision (3822), pool-copy freshness-alert verify row.
11. After the deploy anchors: SigNoz/quarantine rule row + `events` row-count gauge (pre-existing, unchanged).

## g) QUESTIONS FOR THE OWNER

None new — the window's only owner question (3838, disarm-vs-accept the compact) was overtaken by tonight's clean fire and is ticked with evidence below. Standing owner-gated rows (SSO login, pre-shrink trash, deploy prioritization, push authorities) remain queued unchanged.

## h) BAND DRIFT

**None recorded.** Fresh read of the tq facts table (2026-11-21 20:0x, corrected epoch math, window 2026-11-20 00:00 CET → now): ZERO `task.reprioritized` facts — and in fact zero in the table's entire history (facts span 2026-09-10 02:21 → 2026-11-21 20:00, 0 rows matching `%repriorit%` at any time). No priority movement to account for; ordering moved only implicitly via harvest/tick commits. Note: the earlier report's §h reached the same verdict via a mis-decoded epoch (§d.3) — its conclusion is confirmed by the corrected query.
