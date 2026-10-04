# Anchoring Verified, Collector Fix Storm-Gated 9h, tq-Agent Fleet = Storm Driver — Session Self-Review

**Session window:** 2026-10-03 ~17:05 → 2026-10-04 03:05 (continuation of the 16-55 storm-deploy session; 7h of it was gated-loop monitoring while the box churned).
**Mandate:** resume the anchoring-deploy verification; found+fixed one more layered bug; two gated deploy loops exhausted without the gate ever opening.
**Live at authoring:** profile **system-814 anchored** (reboot-safe), crm/geometrikks/tq/cv all HTTP 200, IO PSI some avg10 ~56 (CHRONIC — 11h+), guard trips #1777→#1808+, `paperless_tasks.prom` still being written by the broken collector every ~5 min (fix in tree, undeployed).

---

## a) FULLY DONE

1. **Anchoring deploy verified end-to-end** (owner fired it manually 17:00:07 from their SSH fish session — I traced process ancestry before touching anything; my 08B loop was still correctly holding). Deploy exit 0 at 17:07:41 after 450s; **system-814**: `/run/current-system` == `system-814-link` == `kjzj5qa9…`. Reboot no longer reverts.
2. **tq outage healed and verified**: tq-serve + tq-agent-pool restarted 17:05:07 (restartUnits fix from prior session), :8100 HTTP 200, **tq.home.lan gateway 200** (16:17's 502 gone), checkpoints resumed per logs.
3. **No third CV replay — proven**: deploy log carries `cv OIDC env unchanged — cv-server NOT restarted (avoids CRM replay duplication)`; the sha256 gate from the prior session fired as designed; cv :8098 /health/live 200 on the untouched process. CRM count still ~20,978.
4. **`system_*` metrics live**: 10 `system_unit_enabled_inactive` series with decoded unit names (`activitywatch-watcher-aw-watcher-utilization.service`) — the \x2d/\x5f escape fix works.
5. **paperless-gpt-token mint fixed and proven live**: `Finished` 17:06:10, no EPERM; smoke `PASS paperless-gpt - runtime-minted token file present`.
6. **NEW bug root-caused to evidence and fixed in tree**: `paperless_tasks.prom` fails node_exporter parsing (`line 18: expected float as value, got ""`). Two layers:
   - `WHERE t.slug = 'inbox'` — paperless ≥3.1 moved Tag to TreeNodeModel; **`slug` column no longer exists** (journal: `ERROR: column t.slug does not exist`; proven in 3.1.3 + 3.2.1 models AND the squashed migration, which has `is_inbox_tag` + `tn_parent`, no slug). Fix: `WHERE t.is_inbox_tag` (version-proof, exists in both).
   - **psql exits 0 on SQL errors by default** → `|| fail=1` never fired → `collector_success` read 1 while the value was empty → whole .prom rejected. Fix: `-v ON_ERROR_STOP=1` so fail-closed actually closes.
   Both landed in `modules/nixos/services/paperless.nix`; eval-verified (drv `3p2l1mvq…`); daemon-swept. Timer wiring confirmed (`systemd.timers.paperless-tasks-collector` at paperless.nix:1222; restartTriggers deliberately absent on oneshots — next timer tick picks the new script post-deploy).
7. **Baseline FAIL ownership map closed** (all 12 pre-existing, none new): forgejo = deliberate `ConditionPathExists=/var/lib/forgejo/.subvol-migrated` gate (subvol migration pending since 10-01, documented); flm = guard restore-cap, owner manual; CV render = ONLY the `/de/cv` leg (known IO-PSI false-FAIL row exists); bank-sync = Wise event `version_conflict` (restart-cumulative counter row exists; trace auto-captured); polkit = long-standing 2026-08-18 class; btrbk-pool-clean self-healed 17:06.
8. **TODO hygiene**: anchoring row narrowed on BOTH surfaces (queue + services.md, no drift); `check-todo-system.sh` EXIT=0; report Addendum 1+2 appended to the 16-55 source report.
9. **Two gated deploy loops run to exhaustion without ever falsely opening**: 0C7 (3h, 17:14–20:12) and 0EA (6h, 20:14–02:12). Gate condition (0 guard trips in trailing 60 min AND IO PSI some avg10 < 20) never held once in 9 hours — PSI dipped below 20 twice (19.81 at 17:58, 19.30 at 00:22) but never coincided with a trip-free hour. No forcing, per standing caution.

## b) PARTIALLY DONE

1. **Collector-fix deploy** — fix complete in tree (see a.6) but ACTIVATION is storm-gated; two loops exhausted. Verification checklist defined but not yet executable: `paperless_tasks_*` + `paperless_inbox_count` present on :9100, `node_textfile_scrape_error` 0, collector journal free of `t.slug` errors. Owner can force (`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`) — cached, metrics-only.
2. **Storm attribution** — slice-level all along (nix-daemon / user-1000 / clickhouse alternating), and at 02:54 the guard finally named the process-level dominant: **tq-agent-pool +139,223MB in 11 minutes** (trip #1808). But the full composition (which tq-dispatched agents, which repos, scan vs build ratio) is still unattributed.
3. **tq restart provenance** — I claimed "restarted via pool-usb-recovery converge"; strong inference (tq units unchanged in this generation, so switch-to-configuration wouldn't start them; deploy.sh runs pool-usb-recovery explicitly), but my journal proof grep hit a truncated journal file and returned nothing. Inference, not proof — stated as such.
4. **"All FAILs match baseline"** — that is deploy.sh's own assertion; I read the line but did not independently diff `/home/lars/.local/state/systemnix/smoke-fail-baseline.txt`. Trusted the tool's own gate.

## c) NOT STARTED (deliberately — owner-gated or out of mandate)

CRM dedupe (~10,489 dups); CV-repo durable replay checkpoint; crm-server token off ExecStart argv; flm socket manual restore; forgejo subvol migration run; 15-05 report §f harvest (32 items, "harvest when instructed"); thermal/cooling inspection (freeze #12). None of these are agent-actionable without owner input; all already tracked.

## d) TOTALLY FUCKED UP

1. **The IO storm is CHRONIC**: 11+ hours continuous (15:30 → 03:00+), guard trips #1777→#1808+ (~31 trips), PSI avg10 oscillating 20-73 all night. It is NOT weather — it is our own workload: tq-dispatched agent fleet (nix builds → nix-daemon bursts; repo scans → tq-agent-pool's 139GB/11min) running straight through a thermal freeze-window (freeze #12 14:14 yesterday, Tctl 99°C, owner cooling inspection still NOT done — stability.md:107/114 called it URGENT yesterday morning).
2. **tq-agent-pool is in NO guard list** (socketUnits/sacrificeUnits/ioChurnUnits checked last session) — the now-dominant IO producer is invisible to the guard's control surface. The guard sacrifices flm (a victim) while the actual churner runs unthrottled.
3. **CRM holds ~20,978 opportunities, half duplicates** — live bad data since 16:17 yesterday, dedupe owner-gated behind the CV checkpoint fix.
4. **paperless failed-tasks monitoring is DARK, and it's worse than "metrics missing"**: with `paperless_tasks.prom` rejected whole-file, the counts that Gatus alerts on are ABSENT — a real pile-up of failed paperless tasks (46 unacknowledged at last good read) is invisible to the alerting surface while the file renders `collector_success 1`. The fix exists but cannot deploy through the storm its sibling services are causing.
5. **flm socket down 12h+** (restore-capped 3/3 since 16:10 yesterday; owner manual restore pending PSI calm — which the storm prevents; circular blockage).
6. **My own process failures this session** (see also e): io.stat awk parser failed TWICE (guessed format instead of reading it); a journal-proof grep for tq provenance silently hit a truncated journal and I initially reported the tq-restart claim without labeling it inference.

## e) WHAT WE SHOULD IMPROVE

1. **Read the format before writing the parser** — io.stat cost me two failed attempts; `head` on the raw file first would have cost one call. (Generalizes: format-first debugging.)
2. **Fail-closed collectors must make their tools actually fail** — psql's exit-0-on-SQL-error defeats `|| fail=1` patterns; the class may exist in OTHER textfile collectors. Audit the class, not just the instance.
3. **Fixture-test the collectors** — `migrate-forgejo-subvol-fixture` proves the house pattern exists; a render-and-assert fixture for paperless-tasks-collector (valid .prom on success / SQL-error / empty paths) would have caught BOTH bugs pre-deploy.
4. **Durable "deploy-when-calm" mechanism** — two shell loops (children of my crush session) died at caps; the gate logic now exists in two places (my loop + deploy.sh — a small split brain I introduced). A `--when-calm` mode in deploy.sh itself (self-contained, survives sessions) kills both problems.
5. **Guard needs tq-agent-pool on its radar** — whether as ioChurnUnits or a dedicated throttle is an owner/stability-docs decision, but the guard currently can't see the top IO producer.
6. **Per-PID IO attribution helper** — the guard reports cgroup slices only; trip #1808 gave us tq-agent-pool by accident of unit-level io.stat. A sampler (top io.stat deltas under system.slice/*) would turn every future storm into a named culprit in minutes.
7. **Label inferences as inferences in close-outs** — "assert WHICH question your evidence answers" (existing rule); my tq-restart provenance claim should have carried its evidence class from the first mention.
8. **CHANGELOG gap** — no entry covers yesterday's six-fix batch or today's collector fix (CHANGELOG's latest 2026-10-03 entry is the nix-build-cleanup fix). The prune-to-CHANGELOG pass hasn't run for this lineage.

## f) Things to get done next (28 — marked NEW; the rest are already-tracked rows surfaced by this session)

1. **[NEW]** Deploy the paperless collector fix (force or wait-for-calm) + verify the metric trio (`paperless_tasks_*`, `paperless_inbox_count`, `node_textfile_scrape_error 0`).
2. **[NEW]** Textfile-collector class audit: exit-0-on-error + empty-value emission holes (psql ON_ERROR_STOP pattern generalized).
3. **[NEW]** paperless-tasks-collector fixture test (render script → assert valid .prom across success/error/empty paths; house pattern: migrate-forgejo-subvol-fixture).
4. **[NEW]** deploy.sh `--when-calm` mode (durable gated deploy; deletes the shell-loop split brain).
5. **[NEW]** Guard coverage decision: tq-agent-pool in ioChurnUnits or throttled (owner decision; evidence: 139GB/11min at trip #1808).
6. **[NEW]** Per-PID/unit io.stat top-consumer sampler for storm forensics.
7. **[NEW]** Smoke assertion: deploy output must carry `cv OIDC env unchanged` when the secret didn't rotate (locks the anti-replay gate against regressions).
8. **[NEW]** CHANGELOG entry for the 2026-10-03/04 fix batch (six fixes + collector parse fix).
9. **[NEW]** docs/agents/monitoring.md: record the psql-ON_ERROR_STOP + paperless Tag-schema (no slug, use is_inbox_tag) gotchas.
10. **[NEW]** Journal-proof the tq restart provenance (one grep on pool-usb-recovery.service around 17:05, non-truncated range).
11. CRM dedupe ~10,489 dups (blocked:user; after CV checkpoint).
12. CV-repo durable replay checkpoint + cross-restart opportunity idempotency (blocked:user).
13. crm-server token off ExecStart argv (blocked:user; cr-repo env/file option).
14. flm socket manual restore (blocked:user; PSI-calm precondition currently circular with the storm).
15. Thermal/cooling inspection (URGENT since yesterday 14:14; freeze #12).
16. Forgejo subvol migration (deliberately gated down since 10-01; migration runbook exists).
17. 15-05 report §f harvest — 32 items (owner said harvest-when-instructed; checker flags it every pass).
18. bank-sync Wise `version_conflict` diagnosis (trace file already captured under /mnt/pool/services/bank-sync/traces/).
19. `/de/cv` route abort diagnosis (CV repo; currently masked as smoke false-FAIL row).
20. pool-usb-recovery false-stale probe corroboration (watch; 20s ls probe under storm).
21. monitor365 :9191 connection refused (existing row).
22. CV render smoke IO-pressure-aware (existing row).
23. bank-sync smoke counter windowing (existing row).
24. BFQ tier attention for saturated IO (smoke WARN class).
25. Boot-mirror first-reboot verification (mirror activated 09-30; first reboot still pending — run `nix run .#pre-reboot-check` first).
26. Desktop polkit QQC2 module aborts (2026-08-18 class).
27. tq agent-fleet IO budget/cadence review (harvest/dead-pool scan frequency vs. storm cost).
28. Re-check `docs/status/2026-10-03_16-55*` Addendum 2 wording after the collector deploy lands (row close-out on both surfaces).

## g) Questions I cannot figure out myself

1. **Force-or-wait on the collector deploy?** It is cached and metrics-only, but the box has been storm-bound 11h and the gating exists for freeze-class reasons. `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (your precedent, twice yesterday) or wait out the tq fleet? Only you can weigh metric darkness against activation under load.
2. **Is the overnight tq agent fleet sanctioned to run through the thermal window?** tq-agent-pool did 139GB/11min at 02:43–02:54 and its dispatched agents drove nix-daemon bursts all night — during a freeze-#12 window where heavy builds were supposed to be paused pending your cooling inspection. I cannot know the fleet's authorization, priorities, or whether its 30/30 daily budget should simply run out before deploys resume.
3. **CRM dedupe sequencing** (carried unanswered from the 16-55 report §g): after the CV-repo checkpoint fix via UI/API as lars, or accept the duplicates for now?

---
*Self-review honesty notes: (1) two io.stat parse failures were mine; (2) the tq-restart provenance claim in the 16-55 addendum was inference-labeled-as-fact-adjacent until corrected here; (3) "all FAILs match baseline" is deploy.sh's assertion, independently unverified; (4) this report is Markdown per explicit user path demand (status-report skill default is HTML — override flagged); the brutal-self-review questions are consolidated into §d/§e rather than a second HTML file.*
