# CrowdSec Wave Session 2 Continuation — Battery CLOSED, All Legs LIVE (2026-10-16 17:00–19:55)

**Session scope:** continuation after `2026-10-16_16-20_crowdsec-1943-patchapply-live-obs-battery.md`. Owner directive: verify the 16:19 deploy, run the fix-batch battery, close surfaces, wait. Mid-session the owner added the comprehensive-status-update ask (this report).

**Headline:** the entire CrowdSec fix batch is now **LIVE and battery-green on gen 913 (anchored)**. The parallel session deployed at 17:07:55 (switch ~17:14) carrying my 16:55 fix commit; the engine restarted 17:14:48 with the corrected ExecStartPre; the caddy acquis leg — the last dark leg — is parsing 37 file sources at 100% (951 hits on auth.home.lan alone). FEATURES CrowdSec row flipped 🟡→✅.

**Live state at 19:54:** gen 913 anchored (`bal3sxif…` == system-913-link). PSI storm STILL ongoing (avg10 34.9, avg60 62.7, avg300 67.2 — 3h+ sustained; attributed to the owner's own niri/ghostty session + a launched run-scope, both ≥89% io-stall). 5 commits unpushed on master.

---

## §0 Self-review (what did I forget / do worse / could improve)

**What I forgot:**
1. **Process-age-first.** I ran time-windowed journal checks (`--since 16:25`) against an engine that had started at **08:14:28** — the "zero tail errors" I initially measured was an artifact of the window, not progress. The basic "which process am I probing, how old is it" step would have saved ~15 minutes of misdirection. It also produced the session's most useful discovery (failed tail setups drop the source for the process lifetime — a real CrowdSec behavior worth a runbook gotcha), so the error was productive, but it was still an error.
2. **The deploy log.** The gen-913 deploy (`17-07-55.log`) landed **at 17:14, while I was watching PSI** — I didn't notice until 19:50 and spent 2.5 idle hours "waiting for a lull" to do a deploy that had already happened. I watched PSI but never polled for generation changes. Cheap fix, big cost.
3. **The render test's blind spot.** My morning render pin asserted the group-read timer's EXISTENCE, not its ExecStart's executable shape — the exact class (derivation-directory-as-ExecStart → 203/EXEC) that then shipped broken for 45+ minutes of 5-minute timer failures. Tests must assert the failure mode you fear, not the presence of the thing.

**What I could have done better:**
4. Shipped the 203/EXEC bug at all: I rendered and eyeballed the unit in the morning but read the ExecStart as "the script is there" without resolving what the interpolation PRODUCES. One `ls` on the store path would have caught it pre-deploy.
5. The deploy bookkeeping: I framed the whole session around "the 16:19 deploy carries the fix" — but the fix had ridden gens 908/910 since 08:xx. The summary's framing primed me; content-pin discipline should extend to "which generation first carried which commit" before planning deploy-dependent work.
6. PSI patience: 60 minutes of passive watching without a decision checkpoint. After ~30 min I should have escalated to either the owner (is this storm yours? is deploying during it acceptable?) or a different strategy (fold the deploy into the parallel session's obvious deploy loop — which is in fact what happened without me).

**What could still improve:**
7. The `AmbientCapabilities = CAP_DAC_READ_SEARCH` is still mounted in crowdsec.service though now double-proven inert (userns) and superseded by group+mode — drop candidate, queued.
8. No automated guard exists for the `ExecStart = pkgs.writeShellApplication {…}` class; I grepped the repo manually (zero other instances — the bug is contained), but "verified by one human grep today" rots. Lint-guard queued (§f.1).
9. Cross-session situational awareness: a `git rev-parse HEAD` + deploy-log + generation check at the top of EVERY session block (not just the first) would have caught the 17:14 deploy 2.5 h earlier.

## §a FULLY DONE

1. **16:19-deploy verdict:** landed, and superseded — gen 911/912 raced mid-deploy (the 16:19 run's exit-14 UNANCHORED readout was a concurrent-switch artifact; converged cleanly). 16:32 parallel retry died at the PSI gate in 3s (correct refusal). Stale lock non-issue (flock releases on holder exit — verified protocol in scripts/deploy.sh:40-75).
2. **203/EXEC timer bug found, root-caused, fixed, render-pinned, deployed, live-proven** (`crowdsec-caddy-logs-readable`): derivation-directory ExecStart → bin/ path; strengthened render assertion (`caddy-logs-groupread-timer-execstart-not-bin`) so the class can't ship again.
3. **Engine-restart convergence layer** (`+`-privileged ExecStartPre chmod in crowdsec.service, mkAfter the ln re-assert; restartTriggers += the chmod script): deployed 17:14, ran clean, engine opened all caddy tails.
4. **Caddy acquis leg: LIVE.** "Adding file … to datasources" ×37; acquisition table 100% parsed (auth.home.lan 948/948, banksync 314/314, cache 408/408); `cs_parser_hits_total` 37 caddy series, 951 on auth.home.lan; timer zero EXEC failures since 17:14 (clean "Finished" at 19:47:29).
5. **T14.4 CLOSED:** counts.prom 0644, all 4 gauges, fresh (19:47); ClickHouse `distributed_time_series_v4` carries all 7 crowdsec metric names; `distributed_samples_v4` freshness 10–25s at probe. No phantom job.
6. **T15 CLOSED:** SigNoz provisioner converged **44 rules, exact set, zero duplicates** (17:14:45); all 3 CrowdSec rules provisioned + actively evaluating in the wrapper journal.
7. **#1943 patch-apply: LIVE-PROVEN** (271+ sshd hits accumulating on the fresh engine; cscli local/taint intact).
8. **Stage-2 + geo watch rows closed on morning-battery evidence** (register converged 07:10:50/08:05:01/08:14:29; bouncer valid/streaming; 401 password_login_disabled + 36500-day retention on 11 tables; OIDC login_success 06:43).
9. **First-activation failure row closed** (superseded by the live-proven idempotent prereq redesign).
10. **Surfaces synced, no drift:** docs/services/crowdsec.md (3 edits: acquis caveats + new gotcha "failed file-source setup drops the source for the engine's lifetime" with 3 corollaries), docs/todo/services.md (522/529/532/534/535), docs/todo/monitoring.md (144/145), TODO_LIST.md (1321/1348/1350/1353/1354), FEATURES.md (row 🟡→✅ + header chain).
11. **Bug-class audit:** grepped all services + platform modules for `ExecStart = pkgs.writeShellApplication` — zero other instances; the bug is contained to the one fixed unit.
12. **Anchor discipline:** gen 913 verified anchored at 19:50 (current-system == system-913-link == bal3sxif…).

## §b PARTIALLY DONE

1. **Battery leg "one synthetic request parsed":** satisfied in substance by real traffic parsing (951 hits on auth.home.lan = live requests), but I never sent a DEDICATED probe request. Cosmetic gap.
2. **Ambient cap drop candidate:** proven inert + superseded, still mounted (queued, §f.2 — one-line `mkForce []` removal + render-pin update).
3. **Status-report harvesting of THIS report:** the §f direct follow-ups (f.1 lint guard, f.2 cap drop) are queued at authoring time per the harvest rule; the rest are deliberately not harvested (owner-gated or existing rows).
4. **Post-deploy-check.sh full run:** not re-run post-17:14 (last full run was the 16:19 deploy's own: 148 PASS / 5 FAIL / 5 SKIP / 12 WARN / 1 STORM-SUSPECT, all FAILs at baseline). The 5 baseline FAILs are pre-existing and unexamined this session.
5. **PR #1943 upstream tracking:** override is live and hub-update-safe; no mechanism watches for the merge (removal is manual when it happens).

## §c NOT STARTED

1. **Stage 3 (firewall bouncer enforcement):** deliberately gated on the 7-day clean-alert window opened 2026-10-16 (earliest ~2026-10-23).
2. **The 5 baseline post-deploy FAILs** (pre-existing, not this session's scope — listed in the 16:19 log tail; not diagnosed here).
3. **CI workflow un-red (NIX_GITHUB_RO_TOKEN)** — owner-blocked, untouched.
4. **Vendored systemd-audit.py ratify/port decision** — owner decision, untouched.
5. **/data/docker residue reclaim** — owner decision, untouched.

## §d TOTALLY FUCKED UP

1. **I shipped a broken systemd unit to prod** (dc09d036, the 203/EXEC timer): my first writeShellApplication-as-ExecStart; the render pin I wrote the same day asserted its existence and PASSED while it was broken — a test that cannot fail is worse than no test. Caught it live at 16:47, fixed by 17:00, deployed 17:14, proven 19:47. Blast radius was small (a belt-and-suspenders chmod timer; caddy's own 0640-on-create carried most of the fix) but the "quality bar" claim of the original batch was false for 45 minutes of wall-clock and every 5-minute tick in between.
2. **2.5 hours of idle waiting on a deploy that had already happened** (see §0.2) — the session's biggest waste, caused by watching the wrong signal.

## §e WHAT WE SHOULD IMPROVE

1. **Render pins must assert executable shape, not existence** — pattern for every future `writeShellApplication`/script unit: assert `/bin/<name>` (or `lib.getExe`) in the rendered ExecStart. Now done for crowdsec; generalize via §f.1's lint guard.
2. **Probe process age before time-windowed journal conclusions** — one `ps -o lstart=` beats a wrong `--since`. Runbook gotcha added for the CrowdSec-specific mechanism; the discipline is general.
3. **Waiting loops need a second signal:** when blocked on PSI, poll deploy logs + generation links too — the state can converge without you.
4. **Deploy-intent convention (existing queue row 1334)** gained fresh evidence today: two sessions deploying concurrently produced a gen-race (exit-14 artifact at 16:31), a 3s gate refusal (16:32), and an unnoticed 17:14 landing. That row deserves priority.
5. **The io storm itself:** 3+ hours of avg300 60–77 io-PSI from user-1000 scopes is the deploy script's own "crash #3 precursor class". The 2026-08-22 freezes had builds as contributing load. This is an owner-workload pattern worth a look (what launched `run-p16433-i4647.scope`?).
6. **Test-assertion reviews:** when adding a check, write the negative case FIRST (what breakage should it catch?).

## §f Up to 50 things to get done next

**CrowdSec (direct follow-ups, harvested at authoring time):**
1. Add an eval-time/pre-commit lint guard: reject `ExecStart = pkgs.writeShellApplication {…}` (derivation-dir interpolation) across modules — assert `/bin/` interpolation (HARVESTED → pipeline.md + TODO_LIST).
2. Drop the inert `AmbientCapabilities/CapabilityBoundingSet = CAP_DAC_READ_SEARCH` from crowdsec.service + update the module comment + render pin (HARVESTED → services.md + TODO_LIST).
3. Send one dedicated synthetic HTTPS request through a caddy vhost and watch it parse end-to-end (openssl s_client pattern, LAN IP) — closes §b.1 cosmetically.
4. Watch PR #1943; on merge: remove pr1943Parser + the ExecStartPre ln + restartTriggers entry, `cscli` hub restore check, render-pin update (removal condition documented in three places).
5. Stage-3 firewall bouncer decision + rollout after the 7-day window (~2026-10-23): bouncer type, nftables integration, dry-run mode first.
6. Verify stage-3's SigNoz/gatus coverage needs before enabling (new metrics/rules for the firewall bouncer).
7. Re-run post-deploy-check.sh at a calm window; triage the 5 baseline FAILs (§b.4).
8. Confirm the 44-rule set survives the next provisioner convergence unchanged (drift check, one week out).
9. Consider `lib.getExe` migration for the remaining hand-interpolated `${pkg}/bin/…` ExecStarts (style; zero known bugs).
10. CrowdSec bump drill when nixpkgs moves past 1.8.1 (runbook §Bump drill — three local mitigations + PrivateUsers recheck).

**Deploy/pipeline (from today's evidence):**
11. Prioritize queue row 1334 (deploy-intent convention: jitter + pressure-aware backoff + quiet-tree precondition) — today produced a gen-race, a gate refusal, and an unnoticed landing under concurrent sessions.
12. Fixture-test deploy.sh's PSI entry gates beyond the trip leg (existing row 1346).
13. Investigate the 3h+ io storm source (`run-p16433-i4647.scope` — what launched it; is it recurring?) — freeze-precursor class per the deploy script's own wording.
14. Consider a `docs/agents/systemd.md` note: "identical unit content across deploys does NOT restart a service" (today's convergence lesson, generalized beyond CrowdSec).
15. Push the 5 unpushed master commits when the tree is quiet (owner call on timing).

**Owner-gated (untouched, for visibility):**
16. CI un-red: provide NIX_GITHUB_RO_TOKEN (or publicize/vendor branching-flow).
17. Ratify-or-port the vendored systemd-audit.py (last first-party-adjacent Python).
18. /data/docker ~15.5 GB reclaim (volumes may hold the pre-cutover Twenty DB).
19. Answer the §g questions below.
20. GeoMetrikks theme "green" pick in the UI (no server knob; owner-only action).
21. hermes-agent lock forward after the upstream TS1484 fix (existing watch row).
22. Real-push Actions-run health check on the G2-flipped repos (existing row).
23. browser-history: read the 01:45 deploy log's post-deploy battery verdict (existing row 380).
24. browser-history: /register OAuth-only live probe (existing row 382).
25. browser-history: census legacy WebAuthn credentials (existing row 383).
26. migrate-hot-db: pre-stop WAL checkpoint + outcome-aware abort branch (existing row 524).
27. Owner-authorized claim-orphaned run for the 217 zero-user behavioural rows (existing row 525).
28. hot-db bootstrap CAP_DAC_OVERRIDE deploy at a lull (existing row 527).
29. Tracked-*.py allowlist gate (existing row).
30. CHANGELOG row for the 2026-10-15 wave2 (existing row).
31. $STATE_DIRECTORY colon-list hardening for paperless.nix ×2 + pool-smart-metrics.nix (existing row).
32. First nightly btrbk cycle vs hot/dnsblockd watch (existing row).
33. Weekly CrowdSec drift check: 44 rules + acquis sources + bouncer gauge freshness (fold into a monthly ops pass).
34. decide whether `crowdsec-counts` should also export LAPI counters (cs_lapi_*) for graphing — nice-to-have.
35. Gatus check for the caddy-logs-readable timer itself (a timer that silently 203s for 45 min was only caught by hand — a "timer last-run failed" check class).

**Deliberately NOT harvested:** items 3, 5–10, 33–35 are queued/or referenced above only if they map to existing rows; the remainder are owner-gated or cosmetic and live in this report as visibility, not queue rows. (Harvest rule: §f.1 and §f.2 are this work's direct obligations and were queued at authoring time; everything else was already queued or is not agent-actionable.)

## §g Questions for the owner (cannot self-answer)

1. **Stage-3 timing:** the 7-day clean-alert window opened 2026-10-16 (earliest ~10-23). Do you want the firewall bouncer enabled right at window-close, held longer for more parse-history, or skipped entirely (crowdsec stays detect-only)?
2. **Override patience:** if hub PR #1943 is still unmerged in ~2 weeks, do you want the taint override kept indefinitely (it is hub-update-safe by design), or should I ping/nudge the PR (comment/rebase) on your GitHub voice at some checkpoint?
3. **Deploy ownership during concurrent sessions:** today's 17:14 deploy (which carried my fix) was the parallel session's, taken mid-storm while I was explicitly PSI-waiting. Do you want a single-owner deploy convention per time window (row 1334), and should agent sessions deploy at all while your interactive session is generating io storms like today's 3-hour one?

---
*Report: docs/status/2026-10-16_19-54_crowdsec-battery-closed-all-legs-live.md · author: Crush (glm-5.3-flash) session continuation · all probes read-only except none (no state mutated this session beyond docs).*
