# Status Report — SigNoz Infrastructure/Hosts fix (hostmetrics) — 2026-10-12 13:13 CEST

**Session scope:** diagnose why SigNoz `Infrastructure → Hosts` was broken → implement the fix → deploy → verify.
**Report basis:** this session's work and observations only (per owner instruction). No fresh research into unrelated domains.

---

## 0. TL;DR

The Hosts page was empty because the OTel `hostmetrics` receiver was **never configured** in this deployment. The fix is **implemented, committed, validated, and now LIVE on evo-x2** (switched in by a deploy at 12:38 that this session did not run). Post-deploy data verification is **incomplete** because the box **rebooted at 13:05** and ClickHouse was still down at report time. En route, this session found and fixed **pre-existing deploy-path breakage** (all deploys were blocked before my session's change even mattered).

---

## a) FULLY DONE

| # | Item                                                                                                                                                                                                                                                                               | Evidence                                              |
| - | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| 1 | **Root-cause diagnosis** — Hosts page queries only hostmetrics metric names (`system.cpu.time/load`) keyed by `host.name`; receiver never configured (empty `git log -S hostmetrics` history; 0 such series in ClickHouse; live collector.yaml had zero hostmetrics)               | 5 independent live evidence points probed 02:0x–03:00 |
| 2 | **Implementation** — `hostmetrics` receiver (30s, cpu/load/memory/disk/filesystem/network/paging, 21 pseudo-fs exclusions), `resourcedetection` processor (system detector, `override=false`), both wired into the metrics pipeline (`modules/nixos/services/signoz.nix`, 3 edits) | rendered config verified via `nix eval`               |
| 3 | **Component-availability verification before writing config** — `receiver.hostmetricsreceiver` and `processor.resourcedetection` confirmed compiled into the deployed collector binary (feature-gate flags in `--help`)                                                            | binary probe, 03:0x                                   |
| 4 | **Config validation** — real binary parsed the rendered YAML end-to-end (expected `:8888` bind collision with the live collector = post-validation startup stage); `nix flake check --no-build` PASS                                                                               | 02:59 / 03:0x                                         |
| 5 | **Fixed pre-existing deploy blocker #1** — `scripts/pre-deploy-check.sh:63` `STH_PASS/STH_FAIL` sat outside the `disable=SC2034` directive (added by the storage-history §14 sweep) → the pre-deploy-check wrapper FAILED TO BUILD → **every deploy was aborted**                  | deploy run 1, 03:0x                                   |
| 6 | **Fixed pre-existing deploy blocker #2** — `scripts/lib/storage-history-smoke.sh` was sourced (§14 pre, §19 post) but **staged in neither wrapper** (`flake/parts/apps.nix`) — the exact documented 2026-09-02 "unstaged-source class", recurred. Staged in BOTH wrappers          | deploy run 2, 03:0x                                   |
| 7 | **Pre-deploy checks green** — 84 passed / 0 failed on tree `38ff446*` incl. §11 vendorHash FOD preview (1 uncached go-modules FOD built clean) and all 9 §14 storage-history legs                                                                                                  | deploy run 4                                          |
| 8 | **Config is LIVE on evo-x2** — `/etc/signoz/collector.yaml` on the running system contains `hostmetrics` + `resourcedetection`; the 12:38:57 deploy log shows the switch + full convergence sequence ran (pre-deploy "79 passed, 16 warnings, 0 failed", pressure override used)   | deploy logs 2026-10-12_12-38-57                       |

## b) PARTIALLY DONE

| # | Item                                                                                                                                                                                                                                                                                                                                                                                    | Gap                                                          |
| - | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| 1 | **Post-deploy verification of hostmetrics data flow** — the fix is live by config, but `system.cpu.time` series in ClickHouse / Hosts page population is **UNVERIFIED**: the box **rebooted at 13:05:39** and at 13:13 ClickHouse was still not listening (`:9000` refused), signoz `:8080` not yet listening, collector export failures ("context deadline exceeded") while CH is down | Needs one API probe + one Hosts-page look after CH converges |
| 2 | **Series-churn watch** — `resourcedetection` adds `host.name`/`host.id`/`os.type` to ALL metrics in the metrics pipeline (scraped + OTLP) → one-time fingerprint churn; existing alert rules were assessed unaffected by inspection but no post-deploy alert/panel regression sweep ran (impossible pre-reboot)                                                                         | Sweep after CH converges                                     |
| 3 | **Deploy completion** — my session never completed its own switch (blocked ~70 min at the pressure gate by other sessions' builds + the nightly backup window; escalation question interrupted). The 12:38 deploy (not mine) landed the config using `DEPLOY_FORCE_PRESSURE=1`. Reconciliation of which session ran it is open                                                          | See question 3 in §g                                         |

## c) NOT STARTED (all deliberately deferred — owner said report, then wait)

1. Knowledge write-back: `docs/agents/monitoring.md` bullet for the hostmetrics/Hosts-page contract + the 2026-10-12 recurrence of the unstaged-source class.
2. `TODO_LIST.md` + `docs/todo/monitoring.md` harvest of §f below (AGENTS.md self-harvest rule — deferred per "wait for instructions"; the report stands as the source until harvested).
3. Changelog entries for the three fixes (signoz.nix, pre-deploy-check.sh, apps.nix).
4. Gatus/tile wiring for host-inventory presence (e.g. assert `system.cpu.time` freshness) — nothing currently alerts if hostmetrics silently dies, which is the phantom-green class this repo keeps re-learning.
5. Update the hwmon fingerprint table / docs if `host.name`-labeled series change dashboard queries.
6. Investigation of §10 warnings seen twice in pre-deploy: `storage_collector_fs_used_percent` / `storage_collector_health` ABSENT on the running system (flagged "infrastructure signal" by the gate itself; pre-existing, untouched — out of scope).

## d) TOTALLY FUCKED UP

Nothing this session authored is broken. Two adjacent discoveries that ARE ugly:

1. **The deploy path was already broken tree-wide before this session** — since the storage-history §14 commit (c854c670, swept into the tree by the auto-commit daemon), the pre-deploy-check wrapper failed to BUILD (SC2034) → `nix run .#deploy` aborted for EVERYONE. The daemon commits bypass the gate legs (documented daemon-race class); a commit landed that could never have passed the deploy it gates. Proven live: deploy runs 1–2.
2. **The box went down ~04:26→13:05 and rebooted at 13:05** — `last -x` shows no clean shutdown record; the previous boot's journal ends with niri DRM `DeviceMissing` warnings at 13:04. Given the freeze history this is either an owner-initiated reboot or a hang; **not triaged** (out of session scope, flagged for the owner). Overnight crash-vs-clean determination is the single most important open safety question.

## e) WHAT WE SHOULD IMPROVE

1. **Fix-on-sight worked, but the blockers existed at all**: the storage-history sweep shipped (a) a shellcheck-unshielded line and (b) two unstaged source lines — three failures of the SAME documented class (2026-09-02) in one commit. Consider a selftest that greps every `source …/lib/*.sh` line in pre/post-deploy-check.sh against the wrapper staging lists (eval-time, cheap) — the class has now recurred twice with deploy-blocking effect.
2. **Deploy-vs-daemon race is self-inflicted damage**: editing three files and starting a 10-min gated deploy while the ~10-min daemon commits predictably voided §11 once (a full real-FOD preview wasted). Better: pre-commit my own files (or pathspec-commit them) BEFORE starting long gated runs.
3. **My PSI poll tooling was wrong twice**: decimal parse fed to `-lt` produced a false "pressure drained" verdict (run 1), and burst-rebound made "2 consecutive sub-20" meaningless (run 2). The corrected logic (4×sub-15, integer-truncated) still never saw a window. A tiny `scripts/psi-wait.sh` with correct parsing + burst detection would end this recurring improvisation.
4. **Escalate timing tradeoffs earlier**: I burned ~70 min waiting before surfacing the override-vs-wait choice; the right moment was ~30 min (two polls, clear trend).
5. **Verify live data before claiming the feature done**: config-live ≠ feature-working (the repo's own rule — "assert WHICH question your evidence answers"). Post-reboot convergence blocked this; it must complete before the task is closable.
6. **BuildFlow**: `.buildflow.yml` exists; I loaded the skill and ran project-native gates per project AGENTS.md. Defensible, but the choice should be stated up front in future sessions, not implicit.

## f) WHAT WE SHOULD GET DONE NEXT (impact-ordered; brainstorm per skill norm — harvest with rigor)
> **Harvest disposition (docs-health 2026-10-18):** NOT HARVESTED — because the authoring instruction was report-then-wait (owner-gated; note above). Continuation of this work stream is tracked in docs/planning/2026-10-18_02-35_DOCS-CORPUS-PARETO-COMPLETION-PLAN.md.

1. **Verify hostmetrics live data + Hosts page populated** (this task's close-out; blocked only on ClickHouse convergence post-reboot).
2. **Determine 13:05 reboot nature** (clean vs freeze) — journal `journalctl -b -1 -e`, PSI/PSI-memory around 13:04, niri DRM error cause.
3. **Post-deploy alert/panel regression sweep** after resourcedetection's label additions (one-time churn check).
4. **Deploy-path integrity selftest**: eval-time check that every lib sourced by pre/post-deploy-check.sh has a matching staging line in `flake/parts/apps.nix` (kills the recurring unstaged-source class).
5. **Shellcheck directive hygiene**: one-pass audit that every "read inside sourced lib" var group in pre/post-deploy-check.sh sits under a `disable=SC2034` directive (SC2034 now blocks the BUILD — worst possible failure mode for a typo).
6. **Add a freshness check for hostmetrics** (Gatus or SigNoz rule on `system.cpu.time` staleness) — a silently dead receiver = empty Hosts page again, phantom-green everywhere else.
7. **Harvest this report's §f into TODO_LIST.md + docs/todo/monitoring.md** (the report's own protocol obligation).
8. **Knowledge write-back**: monitoring.md hostmetrics bullet; CONTRIBUTING.md note that lib-staging + SC2034 both now block `pre-deploy-check` at BUILD time.
9. **Investigate §10 warnings**: `storage_collector_fs_used_percent`/`storage_collector_health` absent on the running system (the gate's own "infrastructure signal" — storage textfile collector possibly broken since before this session).
10. **`scripts/psi-wait.sh`**: correct decimal-safe PSI parse + burst detection + exit codes; replaces ad-hoc polling loops (two buggy improvisations this session).
11. **Daemon-race mitigation for gated runs**: convention to pathspec-commit own files before starting `nix run .#deploy` (or a deploy.sh pre-step that commits/stashes-detects uncommitted eval-relevant files and warns).
12. **Reconcile the 04:26–13:05 deploys**: five deploys (10:35, 10:51, 11:10, 12:26 exit=12, 12:38 OK) all used `DEPLOY_FORCE_PRESSURE=1`; 12:26 died code=12. Confirm which session/user ran them and whether any carried unintended tree state (the daemon had multiple sessions' files in flight).
13. **Hosts-page tile/Gatus entry**: wire evo-x2 host presence into the tiles/gatus-coverage registry so an absent host metric is eval-time-visible.
14. **Re-check exemplar columns** (`system.columns`) at next signoz-src lock bump — standing watch-note due for its routine pass.
15. **Bump `memory_limiter` headroom review** — hostmetrics adds ingestion volume to the metrics pipeline; 768 MiB limit was sized pre-hostmetrics (healthy margin likely, but it's a new constant consumer).
16. **Decide filesystem scraper exclusion list ownership** — the 21-entry fs list is a judgment call; confirm the ESP (vfat) and any DAS mounts still report, per owner preference.
17. **Consider `rootfs_context` / mount-point filtering for the disk scraper** once data shape is visible (avoid duplicate series noise from bind-style mounts).
18. **Document the resourcedetection churn semantics** in monitoring.md (one-time fingerprint change; old series age out; queries grouping by host.name gain a dimension).
19. **Add the storage-history §14/§19 wrapper staging to the pre-commit fixture tests** (the selftests.nix fixtures exist for the libs; add one for the WRAPPER staging lists) — overlaps #4, pick one home.
20. **Post-reboot ClickHouse-start latency check**: CH took >8 min post-boot to listen (or failed); check for a slow-start/repair cause while the boot is fresh in the journal.
21. **Confirm route policies survived** — signoz.service was NOT restarted by my change (same PID pre-reboot), but the REBOOT restarted everything; the 2026-08-16 class says API-created route policies don't survive restarts unless re-provisioned. Verify all 20 policies are back (the v6 provisioner should have re-created them; verify, don't assume).
22. **Verify dashboards converged post-reboot** (provisioner convergence assertion) — same restart class.
23. ** Overnight monitoring-gap report**: anything that paged/fired during the 04:26–13:05 dead window and how alerting behaved (host down = Discord should have fired via unit-state rules; confirm).
24. **hwmon fingerprint table refresh** — post-reboot bus renumbering risk (documented post-crash class); re-derive `node_hwmon_temp_celsius` chip labels vs the 2026-10-10 table.
25. **Gatus "host down" posture review**: if the box reboots, which check pages, and did it this morning? (The SigNoz rules run ON the box — a dead box may be alarm-silent; gatus is local too. Any EXTERNAL monitor is the only real page. Decide if acceptable.)
26. **§12 dnsblockd ExecStart warning** (recurring "binary not built yet — verify layout after build"): confirm it resolved in the 12:38 build or retire the warning.
27. **pocket-id-provision + network-local-commands §12 warnings**: same verify-or-retire pass.
28. **Decide deploy-window policy vs nightly jobs** (03:00 backup stack + 04:20 restic): pre-deploy §-gate sleeps inside backup windows are now a recurring 60+ min stall; either shift backup schedule or add a deploy-window hint to the gate message.
29. **Review DEPLOY_FORCE_PRESSURE usage logging**: five overrides this morning — the gate's override is documented but there's no journal/audit trail of WHO overrode and WHY; add a prompt or a mandatory reason env var.
30. **scrape_timeout 25s vs hostmetrics**: hostmetrics scrapes are local/instant, but the §11-warmed go-module cache is now stale-prone; next deploy after a nixpkgs bump re-pays the FOD — note in deploy docs.
31. **AGENTS.md GPU/dashboard note**: gpu.json was mid-edit by another session during mine (concurrent-session trap held — verify its final state passed flake check + provisioner after the 12:38 deploy).
32. **Add host.name dimension to the GPU dashboard panels** (optional polish once host attrs exist — consistency with the new resource shape).
33. **Confirm `system_signoz_alert_rules_healthy` stayed green through the churn** (§10 metric exists; check post-reboot value).
34. **Write the deploy-log incident note**: two of my aborted runs (§11 void, pressure) + the external override run — 2026-10-12 morning was a deploy-storm day; the deploy log dir now holds the full forensic record (30d retention).
35. **Upskill the pre-deploy §-gate docs**: the gate now has 14 checks; its README/comment block still says "13" in AGENTS.md prevention-layers table (drift I noticed, did not fix).
36. ** Consider `collection_interval` 60s for hostmetrics** if 30s proves chatty (14.7k-series-class growth check after 24h).
37. **Evaluate whether `paging` + `load` scrapers earn their series** (Hosts page uses cpu/mem primarily; trim YAGNI scrapers if dashboards won't use them).
38. **storage-history restic first-run verification**: §14 wiring went live this morning; confirm the 04:20 (±10m) run actually wrote a snapshot + marker (first real fire of the new tier).
39. **Check clickhouse-db-backup 03:00 run health** (finished 03:12:38, BACKUP_CREATED — but with the collector export failures starting ~12:32, confirm no CH corruption/wal-replay is behind the slow post-reboot start).
40. **Owner decision queue**: /data/docker ~15.5 GB reclaim (pre-existing, docs/todo/services.md) — still pending, resurfaced in my env reading.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Was the 13:05 reboot intentional, and did the box hang/freeze overnight (~04:30–13:04)?** Previous boot ended with niri DRM `DeviceMissing` spam and no clean shutdown record; given the freeze history this decides crash-triage vs non-event, and whether the overnight 04:26–13:05 monitoring dead window needs a post-mortem.
2. **Who ran the 10:35–12:38 deploys and deliberately overrode the pressure gate five times** (`DEPLOY_FORCE_PRESSURE=1`)? I need to know whether the 12:38 switch was a sanctioned manual deploy (it carried my config in, which I verified) or another agent session acting on the now-green pre-deploy tree — this affects attribution and whether the override policy needs tightening.
3. **Deploy-window policy going forward:** when a real I/O storm from your other sessions blocks a deploy, do you want (a) wait-it-out indefinitely, (b) auto-override after N minutes with a log note, or (c) always ask like this session did (~70 min spent waiting)? I burned most of an hour on (c) and the config still switched in via someone else's override — I'd like the default fixed.

---

**Report format note:** skill canon is styled-HTML dashboards; owner explicitly demanded `.md` at `docs/status/` — honored the explicit instruction (task-queue-dispatch-style standing exception applies).
**Harvest note:** §f deliberately NOT harvested into TODO_LIST.md / docs/todo at authoring time — owner instruction "THEN WAIT FOR INSTRUCTIONS"; this section is the harvest source when instructed.
