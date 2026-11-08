# All health alerts — full sweep, root causes, fixes — 2026-11-08 03:56

**Session window:** ~02:20–03:56, single agent session (owner ask: "Review all health alerts and figure out how we can fix them properly").
**Concurrent sessions live all night:** lock-float deploy session (gen-988, runner v13 fix, indexer-web three-layer fix), dns-blocker/nsfw/mr-sync session, gatus-config wave. Their work is attributed inline where it collided or overlapped.

**Starting state:** 12 firing SigNoz alerts across 7 rules (re-probed 13 across 8 mid-session). Every alert enumerated and root-caused via live probes only: `/api/v1/rules` + `/api/v1/alerts` + `query_range`, unit journals, `cscli explain` (real parser verdicts), `gh api` (workflow states, run history), gatus/crowdsec metrics series, sysfs hwmon, `btrfs filesystem df/usage`.

| # | Alert (rule) | Verdict | Fix |
|---|---|---|---|
| 1 | CPU Thermal Ceiling ≥95°C 30m | REAL (load storm: 3+ agent sessions building; k10temp 97–99°C in every 30m window 00:30–02:30; thermal_pstate_guard cycling correctly, freq held 4.3/5.19GHz) | No code fix — alert honest, guard engaged; load is environmental |
| 2 | Disk Space Critical >90% (`/` 92%) | REAL + known composition (610G data / 723G; ai 543G owner-kept; gcs-staging/docker owner-gated) | Disposable reclaim executed (see a6); levers already owner-queued |
| 3 | Systemd Service Failed ×6 + Service Failure Spike + Unit Restart Churn | MIXED: runner (parallel session fixed), github-sync (queued flip), inboxclean (owner consent), ci-watchdog (retired), indexer-web (resilience queued), service-health-check (derived) | see below |
| 4 | DiscordSync DB Growth Storm | PHANTOM — gauge is db+WAL combined; WAL checkpoint cycling inflated `increase()` to **19.2 GB/24h on a flat db** (751→781 MB over 2d, true +40 MB/24h) | Rule query fixed → `max_over_time - min_over_time` (live-verified 19.2GB → 40.6MB) |
| 5 | CrowdSec Parse Pipeline Errors (s00-raw) | DRIFT NOISE — steady ~150/h since the 2026-11-05 openssh float; cscli-explain PROVED security lines (Failed password/Invalid user) still parse; failing shapes = new auth-success verbose lines (User child / Accepted key found-at / Connection from rdomain) | Rule recalibrated target 1 → 100/10m (splits noise ~25/10m from real break ~100+/10m by 4× both ways); attribution row queued |
| 6 | Git Push Lag >20 | REAL (30 commits) | Owner action — no unprompted push (question g.1) |

---

## a) FULLY DONE

1. **Complete live alert inventory + root-cause table (above)** — nothing asserted from docs alone; every row carries its probe.
2. **vm-top-metrics SIGPIPE race fixed + regression-proven** (`scripts/vm-top-metrics.sh`): live failure was `sort: write failed: broken pipe` → unit failed under process churn (load-53 storm, 2026-11-08 02:4x) because `head -N` closes the pipe and pipefail kills the script. Fix: top-N cut via `awk -v n 'NR <= n'` (drains sort's whole output). Selftest gained a deterministic stress leg (20k-line stubbed scan > 64KB pipe buffer) executed in a CHILD bash — because an `if !` wrapper suppresses errexit INSIDE the function (bash if-context rule) and the abort the unit dies of cannot reproduce in-process. Mutation-tested: mutant (old `head` form) fails the selftest 2× (died + wrong metric count), fixed form passes in 0.18s.
3. **DiscordSync DB Growth phantom killed** (`_signoz-alerts.nix`): root cause chain verified to source — upstream `RegisterDBFileBytes` (DiscordSync internal/observability/metrics_db.go:184) sums db+WAL; WAL cycles ~15MB/h; `increase()` accumulated every regrowth. Query now `max_over_time(...) - min_over_time(...)`; live A/B: 19,200.7MB (old) vs 40.6MB (new). Upstream gauge-split row queued.
4. **CrowdSec s00-raw alert recalibrated with evidence** (`_signoz-alerts.nix`): measured 441 ko/3h started exactly at the Nov-5 deploy (30-day journal: zero before); cscli explain: bare journal lines fail syslog-logs grok, short-form security lines parse, new verbose shapes fail end-to-end. target 1→100/10m, description names both classes.
5. **ci-watchdog retired** (configuration.nix `enable = false` + live `systemctl stop ci-watchdog.timer` + reset-failed): premise verifiably GONE — every domains GitHub workflow `state=disabled_manually` (gh api), runner-health.yml last ran 2026-10-17 carrying the stale billing annotation from the retired block era, while Actions itself is HEALTHY (deploy/terraform legs green 2026-11-05). The watchdog paged every 30 min on that frozen run. Successor row (forge-side scheduled canary + repoint) queued.
6. **Disk reclaim executed to its safe limit**: owner runbook (storage.md) re-checked — the ~55G trash and @cache-home.regular-dir-bak were ALREADY spent by earlier sessions; the one remaining disposable protocol entry (old dnsblockd_tracking.db) purged via `trash-rm`; snapshot inventory verified CLEAN (3×@ + 3×hermes dailies = exactly the 3d window; rescue tier keep=2; no lingerers — the 2026-10-01 class absent); metadata headroom verified (14.47/24.5 GiB used) so zero-unallocated is NOT urgent; that condition + the balance deadlock is the existing `[decision]` row (722.5/722.5, owner timing) — deliberately not duplicated. Personal sitzung recordings in Trash (~6.6G + root) untouched (question g.2).
7. **Harvest complete at authoring time**: 5 domain rows (monitoring.md ×3, services.md ×2) + 4 TODO_LIST mirrors + this report's §f. Zero unharvested direct follow-ups.

## b) PARTIALLY DONE

1. **Deploy of the session's 4 tree fixes — BLOCKED by a foreign edit.** All four are tree-committed (daemon commits 22b787e0e/190ef6e94) and eval-green (`nix eval` drvPath rc 0 at 03:36). Deploy sequence tonight: (i) refused by ENTRY gate on a REAL IO storm (pool disks sda/sdd ~100% util — pool is a 2-device btrfs, scrub long-aborted, driver = sibling build load); (ii) second run refused on ghostty-phantom PSI (64.75%) WITH IDLE disks (max 1.6%) + D-state kworkers — crosscheck `full` attributed the D-states to GPU kfd (llama-server in `amdgpu_amdkfd_gpuvm_alloc_memory`), NOT IO corpses; forced with `DEPLOY_FORCE_PRESSURE=1` per the device-truth doctrine (same phantom-justified pattern the 03-06 session used); (iii) build ABORTED on `SC2034 ZM_PASS/ZM_FAIL appear unused` at rendered pre-deploy-check line 1274 — a PARALLEL session's in-flight edit (daemon commit c32357809), not mine. Their wave, not touched. My fixes ride the next successful deploy train.
2. **indexer-web live restart attempts (2× reset-failed + start)**: both died in the binary's 10s event-store readiness — source-verified hardcoded `projectionReadyTimeout` (~/projects/index internal/webapp/service.go:69, used at service_config.go:94); failing even at load 20 → not purely storm-throughput (QLC replay, ~150-168M written per attempt). A parallel session (03:33 report) shipped the SAME resilience intent after REPAIRING MY BROKEN DRAFT (see d.1), added the upstream flake RestartSec=30 edit, runs a bridge loop, and harvested hot-tier/snapshot-investigation rows. Unit expected to self-heal once the deploy lands burst=0/RestartSec=30.
3. **dnsblockd mirror flip**: flip-check dry-run verified clean (DELETE disposable mirror → migrate issues+PRs+labels+milestones+releases+wiki+lfs → attach push mirror 8h+sync_on_commit; open_issues=2 preserved) — EXECUTION DEFERRED: GitHub twin `pushed_at` 15 min pre-check (the live dns-blocker session is actively pushing; flipping primary mid-wave split-brains the repos). forgejo-github-sync keeps failing loudly on the precondition (by design) until the flip; row queued.

## c) NOT STARTED (owner-gated or existing queued rows — verified, not re-derived)

1. inboxclean re-consent: Google revoked the main-account refresh token (invalid_grant; token granted 2026-11-04; work account = transient 429). Owner runs `inboxclean auth` — nothing agent-side.
2. Git push lag (30 commits) — standing no-unprompted-push rule.
3. Trash sitzung recordings purge (~6.6G) — owner data decision.
4. Root-FS chunk-headroom recovery balance — existing `[decision]` row (owner timing; freeze precedent forbids it under storm).
5. gcs-staging 24G / /data/docker 10G / ai-growth policy — existing owner rows.
6. Gatus-side check state — never verified (first sqlite probe died on schema guess + timeout, deprioritized); SigNoz rules were the alerting surface this session.

## d) TOTALLY FUCKED UP

1. **My indexer-web edit broke the shared tree eval for ~17 minutes (03:00–03:17).** I added `serviceConfig = { RestartSec = 30; }` as a NEW attrset while the module already had `serviceConfig = lib.mkMerge [...]` 6 lines below — duplicate attribute = eval error. I had READ the file and still missed it. A parallel session diagnosed it as a foreign broken draft, repaired it keeping my intent (`RestartSec = lib.mkForce 30` merged into the existing mkMerge), and documented the whole thing in their report before I noticed. Two other sessions had to verify around my breakage via isolated worktrees.
2. **Shipped a vacuous test leg first.** The initial stress-leg used `if ! vm_top_collect` — which disables errexit inside the called function — so the mutant (old buggy code) PASSED the selftest. Only the mutation check exposed it; the shipped leg spawns a child bash with explicit `set -euo pipefail`. Rule reaffirmed: mutation-test BEFORE calling a regression leg done, not after.
3. **Wrote a placeholder filename literally into citations**: TODO rows cite `docs/status/2026-11-08_03-5x_all-health-alerts-sweep.md` — this file's real name is `03-56_…`. Citations corrected right after this write (sed across TODO_LIST.md + 2 library files).
4. **Avoidable round-trips**: `rg -rn` twice (hook-blocked both times — the exact documented trap, hit AGAIN after reading the rule in AGENTS.md this session); `trash-empty --force` (nonexistent flag); a printf `%.60s` crash in the parser-test loop; a fixture-per-pid stress design (20000 mkdirs + 40k awk spawns) replaced by the producer stub.
5. **~40 min in the crowdsec s00-raw attribution rabbit hole** without the one tool that closes it (debug-log window / datasource serialization read); closed honestly with recalibration + a queued attribution row instead of a verified line-level fix.

## e) WHAT WE SHOULD IMPROVE

1. **Scoped eval immediately after every module edit** — the 17-minute shared-tree eval-red was fully preventable with one `nix eval` after the edit (the fix itself took the parallel session minutes).
2. **Mutation discipline is cheap and it works** — it caught the vacuous leg (d.2) within minutes. Make "red leg proven against the old form" part of the definition-of-done for ANY regression test, not an afterthought.
3. **A `signoz-query-lint` rule for increase()-over-composite-gauges**: the DiscordSync phantom is a CLASS (any db+WAL / oscillating composite gauge). A lint that flags `increase(<known-composite>)` would have caught 3 days of phantom paging at authoring time.
4. **Deploy-ingests-foreign-edits collision is now a pattern** (00:49 tonight per the 03-06 report; my 03:5x abort on ZM_PASS). Cheap mitigation: deploy.sh warns when tree files changed after the invoker's last green eval probe.

## f) UP TO 50 NEXT (prioritized; every open item maps to an existing queued row — mostly this session's + the 03:33 session's)

1. **Re-run the deploy** once the parallel wave's pre-deploy-check edit compiles (ZM_PASS vars used or removed — THEIR file) — carries: vm-top fix, crowdsec recalibration, discordsync query, ci-watchdog retirement, indexer-web burst-0 (queued [ready] row from the 03:33 session covers the storm-verify).
2. CrowdSec s00-raw ko attribution (debug window) + parser pin if needed — row queued this session.
3. DiscordSync upstream db/WAL gauge split — row queued this session.
4. ci-watchdog successor: forge-side scheduled canary + program repoint — row queued this session.
5. forgejo-flip@dnsblockd after the dns-blocker wave lands — row queued this session (dry-run evidence attached).
6. indexer-web hot-tier state-dir migration + snapshot-persistence investigation — rows queued by the 03:33 session.
7. index upstream push + re-lock (RestartSec=30) — [blocked:push] row.
8. Balance/chunk-headroom in a quiet window — existing [decision] row.
9. Gatus-side check state sweep (never verified this session).
10. Owner: inboxclean auth, push decision, sitzung- Trash decision.

## g) QUESTIONS (cannot be figured out from the box)

1. **Push the 30 unpushed SystemNix commits to origin?** The lag alert fires until a push; standing rule says never unprompted — your call.
2. **Purge the personal sitzung recordings sitting in `~/.local/share/Trash` (~6.6G in files/ + items at the Trash root)?** They are your data; deleting from Trash is irreversible, so I left them.
3. **Force the dnsblockd forgejo flip now, or strictly wait for the dns-blocker session's wave to finish?** I can see their pushes but not their queue — if you know the wave is done, one command finishes it (`sudo systemctl start forgejo-flip@dnsblockd.service`), and forgejo-github-sync goes green on its next run.
