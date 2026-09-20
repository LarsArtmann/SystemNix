# Status Report: Deploy Review system-787 + Textfile-Poison Fix Wave

**Date:** 2026-09-20 16:31 CEST
**Session scope:** Review of the 15:06–15:25 deploy sequence (user-run `nh os switch` + `nix run .#deploy`), root-cause work on the broken node_exporter textfile collector, triage of all 4 smoke FAILs, three repo fixes (committed, **not yet deployed**).
**Branch state at report time:** `master` ahead of origin by **5 commits** (unpushed). My fixes ride `514dba99` (daemon batch-commit, 8 files — mixes my 3 files with a parallel session's inboxclean.nix/AGENTS/todo/disk-layout changes). Working tree clean; fixes verified intact after 2 later daemon commits from the parallel session.

---

## 1. What this session actually did (chronological)

1. **Reviewed the pasted deploy session** (ssh from MacBook → `nh os switch . -v` → `git sync` push → `nix run .#deploy`): build green (22 drvs), activation clean, `system-787` anchored (`/run/current-system` == numbered profile, verified live), post-deploy convergence ran fully (provisioners, bridges, pool recovery, collectors), smoke 103 PASS / 4 FAIL / 6 SKIP / 4 WARN with all 4 FAILs matching the pre-existing baseline.
2. **Diagnosed `node_textfile_scrape_error=1`** (the deploy's biggest WARN — 7 metrics dark, whole-file rejection):
   - Validated every `.prom` in the textfile dir with a python exposition parser → `system_health.prom` had 5 malformed lines: `system_service_nrestarts{service="..."} [not` (truncated `[not set]`).
   - Read the emitter: `modules/nixos/services/system-health.nix` — the restart-state **writer** (merged CPU+NRestarts single-read, 2026-09-19 refactor) bypassed the existing `systemctl_value()` `[not set]` sanitizer and persisted literal `[not set]` rows into `.system_health_restart_state` for stopped/absent units (monitor365, monitor365-server, fastflowlm, health-dashboard, mr-sync-dashboard — confirmed by reading the live state file).
   - The emitter (line ~336) re-served those rows raw → invalid exposition → node_exporter rejected the **whole file** → `system_zram_*`, `system_stuck_dstate_processes`, `system_niri_metrics_fresh`, `system_signoz_alert_rules_healthy`, `system_emeet_pixyd_expected_down` + friends dark across deploys while every eval stayed green. Textbook state-file round-trip guard-bypass.
   - Second, independent cause found in the same dir: `storage-collector.prom` was `0600 storage-collector:storage-collector` (upstream module pins `UMask=0077` under DynamicUser) → node_exporter cannot read it at all.
3. **Fixed both, plus the rofi rename warning** (all committed in `514dba99`):
   - `system-health.nix`: integer `case` guards at the state WRITE site and the EMIT site (fail-closed, heals the already-poisoned state file on first collector run post-deploy). Fixture-tested the guard semantics standalone (`[not set]` → 0, real values preserved). Verified the guards render into the built script text path and the toplevel evals green.
   - `storage-collector.nix`: `UMask = lib.mkForce "0022"` in the wrapper serviceConfig (first plain attempt conflicted with upstream's own `0077` — eval named both files; `mkForce` needed). Self-heals on the crate's next 60s write cycle. Durable fix belongs upstream — noted in a code comment, not done.
   - `platforms/nixos/programs/rofi.nix`: `extraConfig` → `settings` (nixpkgs rename); eval warning gone (0 mentions in eval stderr).
4. **Triage of the 4 baseline smoke FAILs** (evidence-based, no fixes attempted where user-gated/by-design):
   - **FastFlowLM `:52625` unreachable** — the memory-emergency-guard's Zone-6 (I/O PSI) tripped **#648–653 today** (io avg60 43–63%, disk busy 99–100%); restore budget **capped 3/3** → socket stays down by design. The two 24.6G/23.4G cold loads in the journal were stc/deploy socket re-arm churn, wasted mid-load. **Important positive finding: the `:52626` EADDRINUSE corpse is GONE** — the backend now loads the model fully, so the freeze-#5 hard reset cleared it; the long-standing "reboot owed" state is resolved. Manual restart is now safe whenever wanted.
   - **Bank-Sync sync errors** — Wise SCA challenge ACTIVE: journal shows `statements paused pending SCA approval` + degraded transfers-only fallback on 6 balance IDs at 15:43. This is the ~90-day SCA gate (`docs/services/bank-sync-sca.md`), user action required. Not a regression.
   - **Browser-history 503** — expected under the 2026-09-20 AGENT_FRESHNESS design: server stays degraded until the first agent ingest; the 15:44 agent run extracted profiles but had "no new visits to send" → no ingest → 503 persists until the user actually browses. Self-heals, no action.
   - **CV render smoke (`/admin` ERR_ABORTED)** — CV journal at the same minute shows `sqlite event store: query all failed error="context deadline exceeded"` (deploy-window IO storm); a direct fetch of `/admin` at ~16:00 rendered the full operator cockpit (200). Transient-under-load, not a regression. PDF export, /cv, /pipeline all passed even during the storm.
5. **Process/multi-agent hygiene**: caught that the daemon batched my 3 files with a parallel session's work into `514dba99`; flagged it. Reverted my own `nix fmt --ci` side-effect on the parallel session's in-flight HTML (see §4 — that was my mistake). Survived two `index.lock` contentions with the parallel session/daemon without corrupting anything.
6. **AGENTS.md**: recorded the state-file round-trip guard-bypass lesson inline in the value-less-metric gotcha bullet (line ~906).

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| Deploy review of the full paste (nh switch + deploy + smoke) | §1.1 above; anchoring verified live (`readlink` both paths) |
| Root cause of `node_textfile_scrape_error=1` (nrestarts poison) | State file read live; emitter code read; both sides identified |
| Root cause of absent `storage_collector_health` (0600 prom) | Live `ls`/unit file inspection; upstream `UMask=0077` located in the conflict error |
| Fix: integer guards write+emit in `system-health.nix` | Committed `514dba99`; eval RC=0; rendered script contains the guards; standalone fixture test passes (`[not set]`→0, `5`→5) |
| Fix: `UMask=mkForce "0022"` in `storage-collector.nix` | Committed; eval green after the mkForce correction |
| Fix: rofi `extraConfig`→`settings` | Committed; rofi warning count in eval stderr: 0 |
| Triage all 4 smoke FAILs with evidence | Guard journal (#648–653, restore-capped lines), bank-sync journal (SCA lines), BH agent journal (no visits), CV journal + live 200 fetch |
| AGENTS.md lesson recorded | Line ~906, state-file round-trip paragraph |
| Boot-anchoring + tree-state verification | `system-787` profile == `/run/current-system`; my files intact in HEAD after later daemon commits |

## b) PARTIALLY DONE

| Item | Done | Missing |
|---|---|---|
| Textfile monitoring repair | Code fixed, committed, eval-verified | **Not deployed** — the RUNNING system still has the broken textfile right now; 7 Gatus checks stay dark until `nix run .#deploy` + one collector tick (~2 min) |
| storage-collector perm fix | SystemNix wrapper workaround (mkForce) | Upstream crate/module fix (chmod 644 in `~/projects/storage-collector` or module-level) NOT done — mkForce is a wrapper-layer patch over an upstream pin |
| FastFlowLM recovery | Proved corpse is gone; guard state mapped | Socket still down (restore-capped); no restart performed (needs sudo/systemctl, sandbox-blocked for me) |
| Multi-agent attribution | Flagged the mixed `514dba99` batch | Did not diff-review the co-committed `inboxclean.nix` change (+6/-? lines) from the parallel session |
| Formatter hygiene | Reverted my side-effect on the parallel session's HTML | Did not re-run a final whole-tree fmt check afterwards (deliberately — their tree, their fmt pass) |

## c) NOT STARTED (observed, consciously deferred)

- Deploying the fixes (user ritual; ~12 min; pressure gate currently green).
- Regression test in `tests/` for the nrestarts guard (repo doctrine: guards get regression tests; I only fixture-tested standalone).
- Wise SCA approval (user-only: dashboard approval flow or `bank-sync sca approve`).
- Post-SCA watch item: the phantom RFC3339 `statement_coverage` writer (AGENTS: if it returns, dump goroutines).
- FastFlowLM staged v1.0.3→ current go-live decision (journal banner: upstream now at **v1.0.6**; we hold v1.0.2).
- python3-3.13.15 vs python3-3.14.7 system-path collision — flagged, no `why-depends` investigation.
- fastflowlm-bundled XRT libs vs `pkgs.xrt` collision in system-path — flagged as inert (RPATH), not cleaned.
- Stale textfile-dir litter: `niri.prom.tmp` (lars-owned, Sep 3 — the 2026-09-04 class name), ~6 zero-byte `*.prom.XXXX` mktemp leftovers (ignored by node_exporter, still junk).
- nh switch "new units" oddity: `docker-prune`, `mandb`, `NM-dispatcher` listed as NEW on a 30-path diff — only `fastflowlm.socket` (guard re-arm) explained; others unresolved.
- The `llama-vlm` eval warning's demanded SOAK-TEST (parallel session's outstanding item, surfaced twice in this deploy).
- llama-rag re-enable investigation (disabled since freeze #5; ROCm-runtime suspicion untested).
- CV sqlite event-store deadline errors under load (upstream CV concern — indexes/WAL/IO tier).
- Quickshell journal "1 error line" smoke WARN — never looked.
- 5 unpushed commits (origin parity; CI + deploy gates want the push).

## d) TOTALLY FUCKED UP (honest list)

1. **`nix fmt --ci` is not read-only — and I ran it while a parallel session owned the tree.** treefmt's `--fail-on-change` APPLIES the formatting in place, then fails. It reformatted 2 of my files (fine) and the parallel session's 204K-line in-flight `docs/planning/2026-09-20_15-17_disk-layout-current-and-target.html` (NOT fine). This directly violates the documented "never run nix fmt while a parallel session owns the tree" doctrine — I used the sanctioned `--no-update-lock-file -- --ci` flags but wrongly believed `--ci` = check-only. Had to `git restore` their file back to HEAD (after surviving an `index.lock` collision with their live git process). Luck, not discipline, kept this cheap.
2. **Fixes committed but not deployed — the box is still bleeding.** The whole point of the fix wave was restoring the dark metrics; until the user deploys, `node_textfile_scrape_error=1` persists and 7 Gatus checks stay dark/failing. I delivered a "fixed" state that is only true in git, not on the machine. Should have either deployed (with permission) or led the summary with "NOT ACTIVE UNTIL DEPLOY".
3. **First UMask attempt was wrong** (plain assignment → eval conflict with upstream `0077`). Cost one full eval cycle. Should have checked upstream's module for the key BEFORE writing the override — I had the input locally and greppable.
4. **No repo regression test for the guard fix.** The repo's own doctrine (negative-test convention, `tests/test-scripts.nix` fixture pattern) demands it; a standalone shell fixture is weaker — the rendered-script + CI layers remain untested for this class.
5. **Minor process sloppiness:** two commands auto-backgrounded mid-verification (eval/fmt slowness) instead of being structured as background from the start; the `git restore` collided with the parallel session's `index.lock` on first attempt (8s wait resolved it — no damage, but avoidable with a lock check).

## e) WHAT WE SHOULD IMPROVE (systemic, from this session)

1. **Guards must live at data BOUNDARIES, not call sites.** The `[not set]` bug existed because a sanitizer guarded one of two write paths. Rule now recorded in AGENTS.md; consider enforcing mechanically (see f/11).
2. **A repo-wide lint for unguarded `systemctl show --value` / state-file writes** would have caught this class at commit time — same shape as `audit-textfile-tmp.sh`.
3. **`node_textfile_scrape_error` itself may be unwatched by Gatus** (pre-deploy §10 consumes it; I saw no dedicated check). The monitor-of-monitor doctrine says it deserves a check that pages when 1.
4. **The smoke baseline lulls.** 4 standing FAILs read as wallpaper; two of them (CV render, BH 503) are self-healing/transient and one (bank-sync) is a user-gated SCA gate. A per-FAIL "expected-clearance condition" annotation in the baseline file would make staleness visible.
5. **Restore-cap + stc re-arm churn paid for two 24G cold loads today** (kill mid-load, re-arm, reload). The guard and stc fight over the socket every deploy. An interlock (guard leaves a sentinel the post-switch deploy guard respects; or corpse-aware restore skip promoted from P1) stops paying 24G for nothing during storms.
6. **Deploy-window IO storms keep recurring** (io avg10 26% at smoke, guard trips #648–653, CV sqlite deadlines). The deploy pipeline itself (build + provisioner-restart burst + collector runs + crush-hot-db resume attempts) is a stacked-reader source; staggering the provisioner restart burst is candidate mitigation.
7. **Daemon batch-commits still mix sessions' work** (`514dba99` = my 3 files + their 5). Pathspec-per-session commits in the PMA daemon would make attribution and revert honest.
8. **Ops artifacts in /tmp** — the CV render smoke log lives at `/tmp/.smoke-cv-render.log`; the 2026-09-19 deploy-queue doctrine says `~/.local/state/`. One-line script fix, matches doctrine.
9. **`nix fmt --ci` semantics deserve an AGENTS.md gotcha** (applies changes in place before failing; never run during parallel ownership — today's live proof).
10. **Verify-before-trusting eval-green:** this bug survived days of green evals because the poison was runtime-state, not config. Runtime-state invariants need runtime checks (the python exposition validator I ran ad-hoc is a candidate flake check / smoke step).

## f) NEXT THINGS (prioritized, ~40 — grounded in this session)

**Immediate (this machine, today):**
1. `nix run .#deploy` → land the guard + UMask + rofi fixes; confirm `node_textfile_scrape_error` returns 0 within ~2 min of the switch.
2. Verify the 7 previously-dark metrics present again (zram fill, stuck-dstate, niri-fresh, signoz-rules, emeet, storage_collector_health, …) and the associated Gatus checks green.
3. Push the 5 unpushed commits (origin parity for CI/deploys).
4. Approve Wise SCA via the bank-sync dashboard (or `bank-sync sca approve`) → bank_sync_sync_errors clears; statements resume.
5. `systemctl start fastflowlm.socket` (corpse gone, memory healthy) — or hold for the v1.0.6 decision, owner's call.
6. Browse one page in Helium → BH agent ingests → browser-history /health 200 → smoke FAIL clears.
7. After 1–6: prune the smoke-fail baseline to zero (or annotate) so the next real regression is visible.

**Repo hardening (me, next session):**
8. Add `tests/` regression for the nrestarts integer guards (fixture: poisoned state file → collector renders 0s).
9. Candidate flake check / smoke step: run the python exposition validator over the LIVE textfile dir (the ad-hoc scan that found this bug, made permanent).
10. Investigate whether Gatus watches `node_textfile_scrape_error`; add a meta-check if not (monitoring the monitor).
11. Consider an audit script rejecting unguarded `systemctl show --value` capture into persisted state (the guard-bypass class).
12. Sweep `scripts/post-deploy-check.sh`: move the CV render log to `~/.local/state/systemnix/`; add one retry-after-settle to the CV `/admin` render probe (IO-transient class).
13. Pre-deploy §10: register the CV :8098 endpoint in the WARN opt-ins with the `X-API-Key` header so it stops warning "not responding" on every deploy.
14. Update AGENTS.md flm narrative: corpse cleared by the 09-18 hard reset; "reboot owed" text is stale; record today's restore-cap + re-arm churn pattern (two 24G loads wasted).
15. AGENTS.md gotcha: `nix fmt --ci` applies formatting in place before failing (today's lesson).
16. Diff-review the co-committed `inboxclean.nix` change from the parallel session (attribution hygiene).

**Owner decisions / user-gated:**
17. FastFlowLM: bump to v1.0.6 upstream (v1.0.2 held since Aug; staged go-live discipline incl. re-pull + soak) or stay held.
18. Guard interlock: stop stc/deploy re-arms from re-waking a restore-capped socket (sentinel file the deploy guard respects) — ends the 24G churn loop.
19. Bank-sync: post-SCA, watch one sync cycle for the RFC3339 writer resurrection (goroutine dump if seen).
20. storage-collector upstream: fix `.prom` perms in the crate (chmod before rename) at `~/projects/storage-collector`; then drop the SystemNix mkForce.
21. CV upstream: sqlite event-store `context deadline exceeded` under IO load (indexes? WAL checkpointing? ioTier?).
22. Two pythons in system-path: identify the python3.13 consumer (`nix why-depends`), collapse to one interpreter.
23. fastflowlm XRT lib collisions vs `pkgs.xrt`: accept-and-document or remove one source from systemPackages.
24. llama-vlm SOAK-TEST under real units before decommissioning any manual llama-server (the eval warning's own demand).
25. llama-rag: keep disabled vs systemd-run sandbox-soak investigation of the pinned-build spin (ROCm-runtime suspicion).

**Cleanup / hygiene:**
26. Clean textfile-dir litter: `niri.prom.tmp` (Sep 3, lars-owned), zero-byte `*.prom.XXXX` leftovers (root; needs sudo).
27. Resolve the nh "new units" oddity (docker-prune/mandb/NM-dispatcher listed as new on a 30-path diff) — stc semantics note for AGENTS if benign.
28. docs/planning generated HTML (204K+ lines) is repo bloat; move generated reports out of git or into a build artifact (docs-health doctrine).
29. Rofi: verify the `settings` migration actually renders on next Sway-fallback use — or delete rofi.nix entirely if Sway backup WM is dead weight (YAGNI).
30. Verify health-dashboard's `[not set]` row turns into a real value once health-hub deploys (guard now emits 0 meanwhile).
31. Verify mr-sync-dashboard's nrestarts reads a real number post-deploy (it was in the poisoned set while supposedly running — worth one look at why NRestarts was `[not set]` for an active unit).
32. Quickshell journal error line (smoke WARN) — identify and classify.
33. Re-measure fish startup on a calm IO window (773ms was pressure-attributed; calm baseline 60–70ms).
34. crush-hot-db-migrate keeps skipping with 18–22 crush sessions active — consider a quiet-window trigger or confirm convergence-on-idle is acceptable.
35. Fold `crush-hot-db` interim module into the ratified `services.hot-db` Phase-2 (still pending in AGENTS).
36. Stagger deploy.sh's provisioner restart burst to shave the deploy IO spike (candidate against the storm class).
37. Consider a "post-deploy collector convergence" step: after switch, force-run the textfile collectors once and assert `node_textfile_scrape_error=0` in the smoke (closes today's gap mechanically).
38. Mail relay: SPF `-all` lockdown record still stands (AGENTS standing item) — replace with Resend's include to finish domain verification (user, DNS provider).
39. `pre-reboot-check` before the next planned reboot (boot-mirror first-entry landed recently; §11 should pass — confirm once).
40. PMA daemon: per-session pathspec commits so batch commits stop mixing parallel work (today's `514dba99` is the recurring example).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy now or later?** The fixes are inert until `nix run .#deploy`. Pressure gate is currently green (io avg10 ~7%, zram ~20%, MemAvail ~65%). Do you want me to run it, or is the next deploy yours (e.g. batched with the parallel session's inboxclean work)?
2. **FastFlowLM: restart or hold?** The `:52626` corpse is confirmed gone and memory is healthy, so a manual `systemctl start fastflowlm.socket` is safe — but the restore budget is spent and consumers will re-pay a 21.6G cold load immediately. Start it now, or hold and bundle the decision with a staged v1.0.2→v1.0.6 go-live?
3. **Was the parallel session's `inboxclean.nix` change (+6 lines, committed in `514dba99` alongside my fixes) yours and expected?** I flagged it per multi-agent discipline but deliberately did not review foreign in-flight work — confirm it's intentional so I can stop treating that batch as mixed-authorship.

---

*Report ends. Waiting for instructions.*
