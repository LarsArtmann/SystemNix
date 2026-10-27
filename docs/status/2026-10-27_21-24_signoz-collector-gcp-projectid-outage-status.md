# Status: SigNoz Collector Outage — GCP `project_id` Diagnosis + Fix (2026-10-27 ~21:24)

**Session scope:** single ad-hoc diagnosis session ("Why does our SigNoz looks dead?") — live probing, root-cause isolation, source-level verification, in-tree fix, doc/runbook corrections, TODO dispatch rows. **No deploy was performed** (non-quiescent tree, see §b/§g).

**Report format note:** skill default is a styled HTML dashboard; the operator prompt explicitly demanded `.md` at `docs/status/` — honored as the user-explicit override.

**Repo state at authoring:** HEAD `ddc3ababb` ("status: deploy-7 landed (system-956), opencloud first start fixed"); working tree carries (1) my signoz fix + docs, (2) a PARALLEL session's uncommitted ai-meter/browser-history work in `configuration.nix` + `browser-history.nix` — flagged, not mine, not touched beyond the signoz comment block I own.

---

## Incident summary (what the user actually asked about)

- Symptom: "SigNoz looks dead." Live truth: **UI + query service + ClickHouse were up the whole time** (`signoz.service` active/running, :8080/:9000 listening). What was dead: **`signoz-collector.service` — inactive/start-limit-hit since 20:21:53**, so OTLP ingest (:4317/:4318) and self-metrics (:8888) stopped → no new traces/logs/metrics → dashboards frozen.
- Trigger: the 20:20 deploy (deploy-7 generation) re-armed `services.signoz.gcpMonitoring` (16 projects → 23 `googlecloudmonitoring/*` receivers, first live run since the 2026-09-29 containment).
- Root cause (source-verified against upstream contrib v0.144.0 `receiver.go` + `config.go`): the receivers shipped **without `project_id`**. Upstream has NO ADC-credentials fallback — every API request is built as `"projects/" + ProjectID`; config validation does NOT require the field; the Start()-time metric-descriptor prefetch died with `InvalidArgument ... got: projects/` → fatal → crash-loop → start-limit-hit. The 2026-09-29 containment had masked this second latent bug (the placeholder key died earlier, at token fetch, before any project was used).
- **Detection gap (found during the report pass, ~1h late):** 52 SigNoz rules were live-evaluated mid-outage and only 3 fired — "DNS Blocker Stats API Wedged", "Git Head Stale", "Git Push Lag" — **none about the collector**. Scrape-derived series FREEZE instead of expiring, so unit-state-gauge liveness rules sat phantom-green under exactly the outage they exist for. Queued as a follow-up row.

---

## a) FULLY DONE

1. **Diagnosis chain, live-probed end-to-end** — unit states via busctl (all 12 signoz units enumerated; collector the only dead one), port audit (:8080/:9000/:9363 up; :4317/:4318/:8888 absent), journal read to the exact fatal line, rendered-config inspection (all 23 GCP receivers present, none carrying `project_id`), and finally **upstream source verification** (fetched contrib v0.144.0 `receiver.go`/`config.go` from the locked fork's go.mod graph — pinned the no-fallback + Start()-time-prefetch + validation-passes-empty mechanics). No doc-parroting anywhere in the chain.
2. **The fix, in tree** — `modules/nixos/services/signoz.nix` `mkReceiver` now takes `projectId` and bakes `project_id` into every receiver (both call sites). Eval-verified: `nix eval` of the rendered collector.yaml shows **23/23 receivers with `project_id`, 0 missing**; formatted canonical by the pinned treefmt; evo-x2 eval green with the fix in place (eval-time assertions unaffected).
3. **Runbook correction** — `docs/services/signoz-gcp-monitoring.md`: added the "second falsification" bullet (2026-10-27, the re-arm deploy) beside the 09-29 first falsification, with the exact failure signature (`got: projects/`), the masking relationship, the fix location, and the rule for future hand-added receivers.
4. **Stale-comment corrections on sight** — the falsified "placeholder key … fails 403 per interval without touching the rest of the pipeline" comment in `signoz.nix` (I had READ it during diagnosis and initially moved on — see §d) and the outdated post-deploy checklist pointer in `configuration.nix` (now names BOTH fatal signatures: `400 invalid_grant` AND `got: projects/`). Careful mid-edit re-read of `configuration.nix` before touching it (parallel session owns an adjacent hunk there).
5. **Dispatch rows queued (queue + library, both surfaces)** — (i) deploy-the-fix + verification battery row in `TODO_LIST.md` + `docs/todo/monitoring.md`; (ii) collector-death alerting-gap row (the §-summary detection gap) in both surfaces. Verified formats against the file conventions (single physical lines, `**Source:**` pointers).
6. **SigNoz self-watch probe** — `/api/v1/rules` queried mid-outage: 52 rules, 3 firing, none collector-related. This converted "I suspect nothing paged" into evidence.

## b) PARTIALLY DONE

1. **Telemetry recovery** — the fix is in tree but NOT deployed. Blocked deliberately: the tree is non-quiescent (parallel session's uncommitted ai-meter/browser-history work); deploying now would ship their half-done state (2026-10-25 deploy-race discipline). Collector stays dark until that deploy. **This is the single most consequential open item.**
2. **Outage alerting audit** — SigNoz-rules side probed (silent, see above); **gatus side NOT probed**: "SigNoz Traces Coverage" / "Logs Pipeline Fresh" checks read a textfile fed by the coverage collector, which itself reads ClickHouse directly — they *should* have gone stale mid-outage, and whether they paged Discord is unverified (gatus sqlite needs root; agent shells blocked). Folded into the follow-up row.
3. **Fix verification depth** — eval-level only. The documented boot-test (`timeout 25 <collector-bin> --config <rendered>`) requires `GOOGLE_APPLICATION_CREDENTIALS` (sops-rendered, 0400 signoz) and is only safe while prod collector is down (it IS down) — but agent shells cannot read the secret (sudo banned). So the residual runtime risk (does Start() succeed with the real key + project_id against the live API) is unverified until deploy. Mitigations already on record: 16/16 projects verified HTTP 200 AS the SA on 09-29.
4. **Receiver count precision** — journal/config eyeballing suggested 25 receivers; the eval probe says **23** (12 run-projects + 4 functions-projects with overlaps merged + storage receivers). Corrected everywhere I had written it, but it cost a correction pass — see §e.

## c) NOT STARTED

1. Post-deploy verification battery for the fix (journal free of `InvalidArgument`/`invalid_grant`; 4317/4318/8888 listening; `receiver="googlecloudmonitoring/` labels in :8888/metrics; `dnsblockd` whitelist `dig` probe returning a Google IP; coverage/coverage-gap metrics recovering; the 3 currently-firing rules re-checked for legitimacy).
2. GCP Fleet dashboard live verification (`dashboards/gcp.json` queries are doc-derived; label keys esp.) — only meaningful once series flow.
3. Collector-death detection composite design (mirror deadman pattern / ingestion-freshness metric — queued row exists, design work not started).
4. Eval-time assertion: every `gcpReceivers` entry must carry a non-empty `project_id` (upstream `Validate()` will never catch it for us).
5. Gotchas-archive entry for this outage (2026-10-27 class: masked-second-failure on re-arm after containment).
6. Upstream issue candidate: contrib `googlecloudmonitoringreceiver.Config.Validate()` should reject empty `project_id` (verify-before-filing gate first — the source-level evidence is already gathered).

## d) TOTALLY FUCKED UP

1. **The re-arm deploy itself (not my session's work, but it is the live mess):** the 20:20 deploy shipped 23 receivers that were structurally incapable of working (missing `project_id`), killing ALL telemetry ingestion for the whole box — and did so **silently**: not one SigNoz rule, and (unverified but likely) not one Discord page, for ~1h until a human eyeballed it. Two falsified "safety" assumptions on the same integration (09-29, 10-27) is a pattern: this receiver family has NEVER had a green boot.
2. **I read the falsified placeholder-key comment during diagnosis and didn't fix it until the report pass.** "Fix on sight" is a standing rule; I treated it as context, not debt. Same for the outdated checklist pointer in `configuration.nix`. Both fixed now, but the rule is fix-at-first-read, not fix-at-report-time.
3. **The alerting-gap discovery came ~55 minutes into the incident, during the report pass, not during diagnosis.** An "X looks dead" diagnosis should include "and here is what the monitoring stack said about it" as a standard probe — the detection path is part of the incident. It took one API call.
4. **Receiver-count sloppiness:** I quoted "25 receivers" from eyeballing the rendered config before the eval probe returned 23. Small, corrected, but it is exactly the quote-scrutiny class the repo keeps re-learning.

Nothing I shipped this session is broken: the fix evals green, formats canonical, and all doc edits are consistent with the evidence. The "fucked up" bucket is the live outage + my detection/latency misses inside it.

## e) WHAT WE SHOULD IMPROVE

1. **Probe the monitoring stack as part of any outage diagnosis, first-class** — "what did the alerts say" belongs beside "what does the journal say". Codify in AGENTS.md Session Discipline (candidate bullet).
2. **Fix-on-sight means at first read.** Two stale comments sat through a full diagnosis because I classified them as "context". If I read it and know it's wrong, edit it in the same pass as the fix.
3. **Counts come from eval, not eyeballs** — rendered-config receiver lists, rule counts, port sets: all probeable in seconds; quote only probed numbers.
4. **"Disabled for containment" must record WHAT specifically failed, not just that it failed** — the 09-29 containment note recorded the token-fetch failure but the latent missing-`project_id` bug behind it stayed invisible until the re-arm. Masked-failure chains deserve explicit "what we have NOT yet proven" lines.
5. **Every fail-fast Start() path needs a config-shape eval gate** — upstream validation passing while runtime dies is a recurring class here (match_type empty 10-12, project_id empty 10-27). The module should assert receiver invariants eval-time rather than trust upstream.
6. **Boot-test harness needs a secret-free mode** so config-shape regressions can be caught pre-deploy without violating the secret-handling rules.

## f) NEXT — up to 50 things (brainstorm, NOT a commitment list; harvested rows marked)

**Harvested this session (rows live in TODO_LIST.md + docs/todo/monitoring.md):**
1. Deploy the `project_id` fix + full verification battery (quiescent tree only).
2. Collector-death detection composite (mirror deadman / freshness metric / absence rule — probe before choosing shape).
3. Gatus red-state audit for the outage window + Discord delivery check (root-gated leg).

**Fix-adjacent (this session, actionable soon):**
4. Eval-time assertion: non-empty `project_id` on every GCP receiver.
5. Secret-free structural boot-test for rendered collector.yaml (pre-deploy config-shape gate).
6. Post-deploy `dig monitoring.googleapis.com` whitelist probe (runbook checklist leg).
7. GCP Fleet dashboard live verification once series flow (label keys esp.).
8. Descriptor-prefetch burst cost per collector restart (23 receivers × Start-time calls) vs the 1M/month free quota — measure once.
9. Post-recovery: confirm whether the 3 firing rules (DNS wedged / git stale / push lag) are real conditions or stale-frozen ghosts of the outage.
10. Annotate `docs/services/signoz.md` §Ops "GCP … currently containment-disabled" line — stale since the re-arm.
11. Annotate gcp-monitoring runbook line 208 ("re-arm … is the remaining go-live step") — outdated; the re-arm happened and failed; the fix is queued.
12. Post-incident gotchas-archive entry (masked-second-failure-on-rearm class).
13. Upstream issue candidate: reject empty `project_id` in `Config.Validate()` (after verify-before-filing).
14. Fork-patch candidate: make the Start()-time descriptor prefetch non-fatal / retryable (would have contained this outage to the GCP leg) — design + upstream first.
15. "Ingestion freshness" composite metric (newest-sample age across traces/logs/metrics families) — catches silent ingestion stops regardless of cause.
16. Receiver-label breadth gatus check: all 23 expected `receiver="googlecloudmonitoring/` labels present in :8888/metrics.

**Pre-existing open rows I READ this session (not started, owned elsewhere — listed for visibility, not re-queued):**
17. Dead-view ClickHouse sweep (`distributed_signoz_spans`, bare `serviceName =` predicates) — monitoring.md row.
18. `otel-endpoint-audit` exporter-protocol↔port-kind assertion — monitoring.md row.
19. Gatus multi-label `pat()` lint (S7 phantom-green class) + negative-test group — queued row.
20. Balance-failure alerting (`status: -28` silent 84 min) — queued row.
21. Root-fs 100% alerting row: fix committed, **deploy-verify leg open** (must go RED at 94% and page).
22. Evaluator-deadman "both die together" coverage — owner decision row.
23. node_exporter duplicate-metric whole-scrape-kill self-check (10-18..25 class corollary) — queued in monitoring.md.
24. Exemplar-columns recheck on next signoz/otel lock bump — watch-note.
25. `metric-sweep.sh` E4-style whole-sweep as post-lock-bump ritual — monitoring.md doctrine.
26. ClickHouse permanently-READ-ONLY zombie tables (~10 GiB) human-DROP decision.
27. `/data/docker` ~15.5G owner reclaim — services.md row (agent `du` is permission-blind).
28. monitor365 `max_events_per_day` cap restore before next agent restart — `[blocked:user]`.
29. `scripts/io-attrib.sh` (fourth hand-roll noted) — queued row.
30. storage-collect storm hardening — queued row.
31. `pin-audit-selftest` dirty-tree fixture fix — queued row.
32. pre-deploy-check full-output tee to `~/.cache` — queued row.
33. Storm-aware runtime probes in pre-deploy-check (owner policy pending) — queued row.
34. AGENTS.md bullet: wrong unit name silently empties every journalctl form — queued row.
35. dnsblockd duplicate tracking DBs (724M) verify/trash — queued row.
36. Forgejo `qlc-pre-subvol` 67G root-trash emptying after S2 drill — queued row.
37. Samsung boot-mirror third-reversion persistence-guard question (watch row) — storage.md.
38. signal-backups staleness window via `storage_googleapis_com_api_request_count` (runbook standing context) — recheck once GCP series flow.

**Process/record hygiene noticed this session:**
39. Status-report skill: `.md` override used here — flag pattern works, keep honoring explicit user formats.
40. Consider a "re-arm after containment" checklist template: what was NEVER proven before containment, prove each in isolation before re-enabling.
41. The 52-rule list includes repo-hygiene rules (git head/push) that fired during a heavy multi-session day — decide if thresholds need tuning vs noise budget.
42. TODO_SYSTEM: my two harvest rows cite this report's §-anchors — verify the reverse-links resolve after this file lands.
43. `signoz-src` rev-pin lift condition (patches apply) — unchanged, still gated (pin-audit trace noticed during fmt run).
44. hermes-agent patchelf pin lift — same trace, still gated.
45. nixpkgs fe13242 rev-pin lift conditions (aw-core + linux-7.3 realized) — unchanged.
46. GCP scope decision: 16 projects is the blast radius of every Start() failure — consider trimming to highest-value subset or a standalone sidecar collector (needs owner input → see §g).
47. Docs: the integration's "16 projects verified" phrasing vs 23 receivers vs 12+4+9 preset math — one reconciliation sentence in the runbook would stop the next miscount.
48. Coverage collector already reads ClickHouse directly — it is the natural home for the collector-alive gauge (row 2 shape decision input).
49. The 3 firing rules' Discord delivery mid-outage is itself evidence about the alert pipeline under partial outage — capture before it clears.
50. After deploy lands: re-run `scripts/metric-sweep.sh` (new GCP metric families entering the store will trip nothing, but the sweep is the cheap drift net).

Items 4–16 + 39–50 are brainstorm fuel; the harvested set is 1–3 (+ the earlier deploy row from the pre-report turn). Per the skill: most of §f belongs in ROADMAP/routing review, not the dispatch queue.

## g) Questions I cannot answer myself

1. **Deploy timing vs the parallel session:** the tree currently carries another session's uncommitted ai-meter/browser-history work. Do I deploy the signoz fix NOW (shipping their half-done state into a generation) or wait for quiescence — and if wait, is the telemetry outage acceptable until their arc lands?
2. **Risk appetite for the third attempt:** after two live falsifications on this integration, do you want GCP ingestion re-armed as-is on the next deploy, or containment-disabled again until a green boot-test (or the fork-patch making Start() non-fatal) proves a collector crash can only take the GCP leg, not the whole pipeline?
3. **What actually tipped you off** — frozen dashboards, or Discord silence/presence? Specifically: did ANY Discord page arrive between 20:21 and 21:15 (the three firing rules should have generated some traffic)? That single data point decides how much of the row-2 detection work is about rules vs delivery.

---

**Waiting for instructions.** No commit performed (harness contract); the auto-commit daemon will sweep the report + fix + doc edits.
