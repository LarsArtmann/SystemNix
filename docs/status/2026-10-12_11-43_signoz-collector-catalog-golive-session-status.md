# Session Status — signoz-collector match_type fix + Architecture Catalog go-live (2026-10-12, ~05:00–11:45 CEST)

**Session scope:** two production incidents plus closeout — (1) the signoz-collector
crash-loop that blinded fleet telemetry from 05:10, (2) the Architecture Catalog
404/pre-go-live WARNs, (3) the go-live closeout after the owner completed the sops
paste. Context: a 12h+ tq-dispatched Crush session in `~/projects/go-taskqueue`
saturated the box (io PSI waves 17–80%, QLC 98% busy, guard trips 6×/60min) for the
entire session; every deploy had to fight it.

---

## a) FULLY DONE

| Work                                                                                                                                                                                                                                                                                                                                   | Evidence                                                                                                                                                                                                                                                                            |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **signoz-collector root-cause + fix** (`match_type = "strict"` in `modules/nixos/services/signoz.nix:1176`) — otelcol v0.144 rejects `exclude_fs_types` with empty `match_type`; the 05:09 deploy crash-looped the collector to `start-limit-hit`, fleet telemetry (OTLP 4317/4318, prometheus scrapes, journald pipeline) fully blind | Collector started once at 07:37:36 (`Everything is ready` in 1s), zero restarts since; ports 4317/4318/8888 bound; **20,401 logs + 3,073 traces in 10 min** post-fix                                                                                                                |
| **Pre-deploy verification method established** — no `validate` subcommand in the signoz fork, so: render yaml via `nix eval --raw … --apply`, boot the real binary under `timeout 25`; exit 124 after `Everything is ready` = healthy                                                                                                  | Found the config bug in a 25s sandboxed boot instead of a deploy cycle; recipe + caveat recorded in `docs/services/signoz.md` (§Ops first bullets)                                                                                                                                  |
| **Hostmetrics feature actually works now** (the original intent of the config that crashed)                                                                                                                                                                                                                                            | `system.cpu.time` + 512 `system.*` series in ClickHouse; Infrastructure → Hosts page can populate                                                                                                                                                                                   |
| **Architecture Catalog 404 diagnosis** — two independent gaps: sync unit cloned the read-only GitHub mirror (`lars/eventcatalog-hub`) instead of the CI's new `lars/eventcatalog-hub-dist` publish target (hub `c00a61a`), AND the sync token was never sops-pasted (PLACEHOLDER skip, journal-verified)                               | `configuration.nix` `repo` override landed + eval-verified; live unit binary contains `eventcatalog-hub-dist`                                                                                                                                                                       |
| **Runbook + TODO hygiene for the catalog**                                                                                                                                                                                                                                                                                             | `docs/services/architecture-catalog.md` go-live checklist steps 0–6 all carry dated DONE stamps; PLACEHOLDER section marked HISTORICAL; go-live row → `[x] GO-LIVE COMPLETE` in `docs/todo/services.md`; `[watch]` tile row stamped condition-met; CHANGELOG entry under Unreleased |
| **Go-live verified end-state** (after owner paste + system-872)                                                                                                                                                                                                                                                                        | `current → generations/20261012-113522`, `dist_present 1 / fresh 1 / scrape_errors 0`, vHost 200 + EventCatalog title marker, sync log `serving generation … from lars/eventcatalog-hub-dist@dist` — the PAT read the dist repo first try (scope watch-item did not fire)           |
| **Boot-anchor incident detected + healed** — first catalog deploy shipped **exit 14 UNANCHORED** (reboot would have reverted the box); second deploy anchored **system-871**, user's deploy then anchored **system-872**                                                                                                               | `readlink /run/current-system` == `system-871-link` verified before handoff; deploy.sh anchor assertion now exercised and understood                                                                                                                                                |
| **Throttle-sweep finding harvested** — inboxclean-web MemoryHigh hits grew 136k → 1.26M (~9×/2d)                                                                                                                                                                                                                                       | Stamped onto `docs/todo/monitoring.md` continuous-throttle row (no parallel row minted)                                                                                                                                                                                             |
| **Session follow-ups self-harvested at authoring time** (this report)                                                                                                                                                                                                                                                                  | 4 new rows: llama-chat start budget (ai-stack), deploy.sh anchor gap (pipeline), `node_textfile_scrape_error` root-cause (monitoring + queue), signoz-collector MemoryMax watch (monitoring); queue one-liners in TODO_LIST                                                         |

## b) PARTIALLY DONE

1. **The I/O storm was attributed but not mitigated.** Culprit identified precisely
   (crush pid 1953246, go-taskqueue, 42 GB cumulative IO, go build/lint loop,
   tq-dispatched per the TODO_LIST pool header) and flagged to the user — but it ran
   all session and is presumably still running. Deploys were forced around it rather
   than the load being shed.
2. **`node_textfile_scrape_error=1`** — seen on every deploy today (7 metric families
   absent: storage_collector__, system_niri_metrics_fresh, system_signoz_alert_rules_healthy,
   system_stuck_dstate_processes, system_zram__, system_emeet_pixyd_expected_down),
   downgraded to WARN each time, never root-caused → now queued (§f.3).
3. **signoz-collector memory posture after hostmetrics** — §17 showed 2,195 → 3,069
   MemoryHigh hits; counter is since-boot (crash-loop era included), so it is
   inconclusive whether the new receiver squeezes the 1G budget → queued as `[watch]`.
4. **deploy.sh anchor gap** — root-caused and worked around (re-deploy), the fix is
   only a queued row (§f.2); deploy.sh itself still has the misleading
   "config already active" path.

## c) NOT STARTED (noticed this session, untouched)

1. `architecture-catalog` VM test (services.md row — module still has none).
2. SigNoz dashboard tile for catalog freshness (condition met today; not built).
3. Forgejo v15 token-semantics runbook capture row (services.md, still `[ready]`).
4. Pocket ID auto-rotation `"apply"` flip (another session shipped dry-run, deploy pending).
5. 4 orphaned all-scope Forgejo setup PATs (owner UI cleanup row).
6. The `catalog:` eval warning listing 19 integration subdomains without catalog
   entries — printed by EVERY eval today (ADR-008 migration residue; pre-existing program).
7. FastFlowLM :52625 FAIL + bank-sync `sync_errors_total > 0` + node-exporter 332/min
   journal rate — baseline-matched advisories in all three smoke runs today; not chased
   (bank-sync storm-class is documented; FastFlowLM has its own decision row).

## d) TOTALLY FUCKED UP

1. **The 2h27m telemetry outage itself (05:10–07:37).** Another session shipped the
   hostmetrics receiver with a config the pinned collector rejects, and the deploy
   pipeline has NO pre-activation validation for rendered service configs — the bug
   class survived eval, flake check, pre-deploy §1–14, and only detonated at
   switch-to-configuration. The fix is one line; the outage was the process gap.
2. **The unanchored window (~08:23–08:40).** My catalog deploy hit the llama-chat
   timeout (20G model load, 8m11s off a 98%-busy QLC) → nh aborted BEFORE its profile
   bump → deploy.sh then printed the wrong diagnosis ("config already active") and
   shipped exit 14 reboot-revertible. I had force-deployed through a guard-trip-recency
   warning (6 trips/60min) — the exact class that produced it. Healed same session, but
   for ~17 minutes a reboot would have rolled the box back to 07:38.
3. **The daemon committed a broken tree to HEAD** (`0d3d27af`, the other session's
   `${BASH_REMATCH}` eval error): auto-commits gate on NOTHING eval-related, so every
   agent on the box was eval-blocked until the author self-fixed. Systemic, still true.
4. **My own misses this session** (explicit): (a) saw `node_textfile_scrape_error=1`
   five times and never opened the journal — reported now, chased never; (b) diagnosed
   the llama-chat timeout and did NOT ticket it at diagnosis time (harvested only now,
   under the report obligation); (c) boot-tested the full collector config against prod
   ports while treating it as harmless — it worked only because prod was dead; the
   recipe as I first wrote it was a footgun (caveat added post-hoc); (d) reported
   "one owner step left" without realizing the user's paste+deploy would still have to
   survive the storm gates (they managed fine, but I could have pre-flighted the
   guard-trip state for them).

## e) WHAT WE SHOULD IMPROVE

1. **Rendered-config boot tests belong IN the pipeline**, not in agent judgment:
   a flake check / pre-deploy § that starts each new/changed otelcol-family config
   (signoz collector, dnsblockd, anything with a big YAML contract) against its real
   binary with throwaway ports. The signoz.md recipe is tribal knowledge until then.
2. **deploy.sh anchor semantics** (§f.2): heal-or-fail-loud; never print
   "already active" when current-system != profile.
3. **Storm policy for deploys** — today's pattern (prebuild toplevel →
   DEPLOY_FORCE_PRESSURE → switch-only IO) worked three times; it should be a
   documented runbook path with explicit preconditions (FODs cached, no balance/scrub
   running, PSI dipping) instead of agent improvisation.
4. **tq pool IO-awareness** (owner question §g.1): the go-taskqueue session degraded
   the whole box for 12h+ — harvest-time PSI check or per-session IO budgets.
5. **Multi-session deploy etiquette worked, but barely** — two deploys raced twice;
   the lock held, but the other session's deploy burned 17 min then exited without
   activating, which looked identical to a crash. A deploy that releases the lock
   without activating should say so somewhere durable.
6. **Baseline FAIL staleness** — FastFlowLM/bank-sync/node-exporter advisories have
   ridden the smoke baseline all day; baseline rows should carry a "first seen" date
   so staleness is visible.

## f) NEXT (harvest-marked; [H] = landed in TODO files this session, [N] = noticed only)

**Direct follow-ups of this session**

1. [H] deploy.sh anchor heal-or-fail-loud (pipeline.md + queue)
2. [H] llama-chat start budget vs storm cold loads (ai-stack.md + queue)
3. [H] Root-cause `node_textfile_scrape_error=1` (monitoring.md + queue)
4. [H] signoz-collector MemoryMax=1G adequacy watch (monitoring.md)
5. [DONE inline] signoz.md boot-test recipe port-collision caveat
6. [N] Codify the storm-deploy runbook path (prebuild → force → verify anchor) into
   `docs/agents/nix-flakes.md` or the deploy.sh help
7. [N] Codify the per-cgroup `io.pressure` storm-attribution one-liner battery into
   `docs/agents/stability.md` (it worked first-try today; it is currently session lore)
8. [N] Negative-test for the signoz gotcha: a fixture asserting `exclude_fs_types`
   blocks carry `match_type` (the config-lint class that would have caught today's bug)
9. [N] When the box is calm: re-run post-deploy-check to clear the 2 STORM-SUSPECT
   (unverified) checks from system-872's smoke
10. [N] Re-check the bank-sync MemoryHigh pairing (5,480 hits) — its §17 WARN repeated
    on every deploy today

**Catalog / observability**
11. [N] `architecture-catalog` VM test (services.md row)
12. [N] SigNoz freshness tile (condition met; row stamped)
13. [N] Runbook-capture row: v15 token semantics etc. (services.md)
14. [N] Hub-side: `eventcatalog-hub-dist` should get the same keep-N/CI-docs treatment
the runbook now documents (hub repo TODO owns it)
15. [N] `catalog:` eval warning — finish the ADR-008 catalog-entry migration for the 19
listed subdomains (pre-existing program, re-surfaced all day)

**Storm / stability (bigger rocks)**
16. [N→Q1] tq-pool IO-awareness policy (owner)
17. [N] Guard trip-recency gate: wire actual trip timestamps into the deploy gate
(already queued by the wave7 session — reaffirmed by today's llama-chat ride)
18. [N] PSI pre-check before the 72-check suite (already queued by the wave7 session)
19. [N] Investigate whether the storm's `node-exporter 332/min` journal rate is its own
hotloop or storm-echo (§18 FAIL in every smoke today)
20. [N] Storm-night btrbk send verification (queued by wave7 session — still open)

**Pre-existing rows I re-verified as still open (no action this session)**
21. [N] Pocket ID auto-rotation → `"apply"` flip (owner-gated review window)
22. [N] 4 orphaned Forgejo setup PATs (owner UI)
23. [N] monitoring.md:103 mislabeled `system_service_memory_events_high` gauge
24. [N] monitoring.md:104 continuous throttle textfile metric + SigNoz rule (my 10-12
stamp strengthened the case: inboxclean 9×/2d)
25. [N] monitoring.md:105 HM user-slice sweep leg
26. [N] trash-prune mechanism + the 55G Trash park (storage rows)
27. [N] FastFlowLM staged go-live decision row (ai-stack)
28. [N] llama-vlm soak + live verification (ai-stack watch row)
29. [N] NPU-telemetry premise-check row (ai-stack, queued by the 03:17 session)
30. [N] Em-dash style ruling for source code (pipeline decision row — directly relevant:
today's commits mix both styles)

**Hygiene / docs**
31. [N] This session produced no `docs/status/` report until now — earlier turns should
have authored one per phase; keep one report per session, not per incident
32. [N] `docs/agents/monitoring.md` ClickHouse table still cites the pre-hostmetrics
era for host.name sourcing — revisit after the Hosts page has data for a week
33. [N] The 19-subdomain warning text in evals is 4 lines of noise per eval — consider
a once-per-day warning or a progress counter
34. [N] smoke-fail-baseline.txt rows could carry first-seen dates (see e.6)
35. [N] `architecture-catalog-sync` retry: currently a failed clone exits 1 with hourly
retry only — a 5-min backoff for the first 3 retries would converge faster after
CI publishes (minor; hourly is fine for freshness)

**Nice-to-have surfaced but deliberately not harvested**
36. [N] Collector self-metrics scrape could add a `hostmetrics` receiver-accepted gauge
panel to the SigNoz self-watch (part of item 12's tile work)
37. [N] `signoz.md` cheat-sheet could gain the boot-test one-liner as a copy-paste block
(it is in Ops prose today)
38. [N] deploy.sh could echo the profile bump as a first-class step line (it does — but
the "No new profile generation" branch needs the §f.1 fix first)
39. [N] tq agent sessions could log their cgroup path at start for instant attribution
40. [N] The `docs/todo/pipeline.md` anchor row and the wave7 gate rows should be done
together (same file, same flow)

## g) QUESTIONS (owner-only)

1. **Storm policy for tq-dispatched sessions:** when a session's builds saturate the
   box (PSI ≥40% / guard trips) and block deploys or re-create freeze-class load —
   should future agents SIGSTOP/pause the offending session (freeze-25 precedent
   requires owner license) or always wait it out? Today I waited + forced around it;
   the box stayed up, but it cost ~2h of telemetry outage runway.
2. **deploy.sh anchor semantics:** when an activation completes with failed units and
   the profile did not bump — auto-heal (deploy.sh sets the profile itself, accepting
   the reboot target includes the new config with a known-failed unit) or fail-loud
   (exit non-zero with the exact heal command)? I lean fail-loud; your call.
3. **Force-deploy ratification:** I used `DEPLOY_FORCE_PRESSURE=1` three times today
   (twice with prod down, once for the anchor heal, each with a prebuilt toplevel and
   verified FOD cache). Is that the standing policy when the alternative is extended
   prod degradation, or do you want storm-gated deploys to always ask first?

---

## Harvest log (self-harvest at authoring time, per AGENTS.md TODO System)

- `docs/todo/ai-stack.md`: +llama-chat start-budget row
- `docs/todo/pipeline.md`: +deploy.sh anchor-gap row
- `docs/todo/monitoring.md`: +textfile_scrape_error row, +signoz-collector MemoryMax watch row
- `TODO_LIST.md`: +3 queue one-liners (anchor gap, llama-chat budget, scrape_error)
- `docs/services/signoz.md`: boot-test caveat amended into the existing gotcha (no row needed)
- Deliberately NOT harvested: §c/§f items 6–35 (pre-existing rows already tracked, or
  noticed-only items without a concrete ask yet — items 11–13 etc. live in their rows)

---

## Post-go-live verification battery (2026-10-12 ~20:15 CEST — Pareto plan Wave 1)

Executive finding first: **Gatus itself was DOWN** (crash loop since 18:11 — a
backslash inside an alert description on the `monitoring_system-health-metrics`
endpoint failed config parse; fixed in `c18a78d6`, deploy pending an IO-pressure
window), so check-state could NOT be read from Gatus; every verdict below comes
from the underlying surfaces directly.

| # | Surface (WHAT) | Verdict | Evidence (WHERE) |
| --- | --- | --- | --- |
| 1 | vHost `catalog.home.lan/` | PASS | `200` + `<title>EventCatalog \| EventCatalog</title>` via 192.168.1.150:443 (the chain Gatus checks; evo-x2 Caddy `.200:443` answers the dnsblockd block page for this SNI — .150 terminates protected vHosts) |
| 2 | `/llms.txt` | PASS (stale host) | `200`, 5.5KB body, all 4 source domains present, 10/10 sampled links resolve in the served tree — but links carry `eventcatalog.dev` (served dist predates the run-68 homepageLink fix; hub §b.1's frozen-serving warning materialized) |
| 3 | `/llms-full.txt` | PASS | `200` |
| 4 | `/schemas.txt` | **FAIL — does not exist** | `404` live; served tree has `schemas/` dir (no index) + `llms-full.txt`. Runbook documented a phantom surface — corrected in the runbook 2026-10-12 |
| 5 | Freshness gauges | PASS | textfile prom: `dist_present 1`, `fresh 1`, `stamp_age_seconds 49907` (~13.9h), `scrape_errors 0` |
| 6 | build-stamp | PASS | `builtAt 2026-10-12T03:26:18Z` (nightly cron build), all 4 sources with revs |
| 7 | Serving freshness window | **WATCH — frozen** | `current → generations/20261012-140000`; sync succeeded 12:00/13:00/14:00, then 401s (sync token rotated by today's 3 setup-forgejo.sh runs). dist advanced to run-68 but cannot serve. **Time-to-red ≈ 2026-10-13 15:26 UTC (17:26 CEST)** unless the sops token is re-pasted (owner action, hub report §g.1) |
| 8 | Nightly cron TZ | TRUTH STAMPED | `build.yml` cron `23 3 * * *` = TZ-less UTC → **05:23 CEST**. Runbook (×3 spots) + Gatus alert text now say UTC |
| 9 | Mesh content QA | PASS | orders-svc 6 pages + billing-svc 11 pages, real titles (no template fallback); `docs/domains/{banking,invoicing,ordering}`; 173 index.html total |
| 10 | ID-collision audit | PASS | Zero cross-source collisions in the 4-source union (`order.cancelled/created`=demo, `order.completed/placed`=mesh, `balance_sync.*`=bank-sync; services 4 distinct). Latent risk: `order.*` prefix shared by demo+mesh — merge.py first-source-wins would silently shadow a future overlap (hub ROADMAP item 39 is the structural fix) |
| 11 | Mirror cadence | MEASURED | Pull mirrors sync every **2h** (`forgejo.nix` `mirror.DEFAULT_INTERVAL`); hub scripts' "6h" comments stale. Worst-case staleness ≈27h < 36h budget; runbook freshness paragraph carries the arithmetic |

Incident found en route: Gatus config-parse crash loop (400+ restarts, ALL
monitoring dark 18:11→fix) — root cause `\\x2d` in an alert description,
fixed + eval-guarded (`gatus-alert-text-audit` assertion over all 388 alert
descriptions) in `c18a78d6`.

