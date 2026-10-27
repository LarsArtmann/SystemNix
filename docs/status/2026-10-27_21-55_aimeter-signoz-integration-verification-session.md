# ai-meter × SigNoz Integration Verification + Collector SEV1 — Session Status Report

**Date:** 2026-10-27 21:55 local (CET) · **HEAD:** `abd0ea93b` (master, daemon-commits continuing) · **Session type:** verification + outage diagnosis + todo harvest · **Instance:** Crush

**Scope note:** This session executed three asks: (1) the owner directive *"kimi-coding do not use anymore"*, (2) *"How well is the AI router integrated with SigNoz?"* with step-by-step execution + verification, (3) this report. No unrelated research was done; everything below is from this session's run. This report also CORRECTS two wrong claims in the 20:59 advisory report (see §d.1) — that report stays as written (point-in-time snapshot); the corrections live here per ANNOTATE-not-rewrite doctrine.

**Concurrent-tree flag:** multiple parallel sessions active throughout (daemon sweeps at 21:16/21:21 carried foreign files incl. a 177-line planning doc; a binfmt go-compile for pbx-artmann was live; `docs/todo/ai-stack.md` grew a foreign row mid-edit at 21:37 — my edits re-anchored after re-read, no overwrites). The signoz `project_id` fix was authored by ANOTHER session this evening — this session independently verified it.

---

## 0. Self-critique (the three questions answered first)

### What did I forget?
1. **The routing table says read the SERVICE RUNBOOK before domain work — I only read the agent doc.** `docs/agents/monitoring.md` (read, required) pointed at `scripts/metric-exists.sh`, but `docs/services/signoz.md` holds the ClickHouse probe cheat-sheet (table names, column names). Cost: three failed CH queries (wrong column `timestamp_time` → `timestamp_ms`; wrong table `samples_v2` (empty, retired) → `samples_v4`). The runbook would have saved all three.
2. **The deploy-7 report HAD the outage signal and I skimmed past it.** Per status-report pre-read discipline I read the 20:47 closeout report early — but grepped it for MY topic (ai-meter/crush), not for the SYSTEM I was about to diagnose. Its line 14 lists `signoz traces_missing` as battery FAIL #1. I only found that line when re-grepping for "signoz" 20 minutes into the diagnosis. Lesson: during an outage hunt, grep parallel reports for the AFFECTED COMPONENT, not just your question.
3. **The documented tool first.** I burned six fetch calls on the v1 query API before switching to the python3-urllib method that `docs/services/signoz.md` line 56 prescribes verbatim. (The API turned out broken for GET either way — but I proved it late, not first.)

### What could I have done better?
4. **"Series exist" ≠ "series are fresh."** My first probe (`metric-exists.sh`) returned 1258 series and I nearly called the integration "flowing". The probe proves REGISTRY registration, not ingestion. The truth (ingestion dead since 20:19:39) only surfaced via `samples_v4` freshness timestamps. The probe itself should grow a freshness column — queued (§f.29).
5. **The kimi removal left one assumption unverified for hours.** The blocked:deploy row asserted the crush-config `crush_key` helper "skips absent files" (from a comment) without reading the helper. This session closed it statically — `test -r "$f" || return 0`, so the provider is never even registered (stronger than "keyless"). One grep, done too late.
6. **I filed the v1-API regression nowhere until the report pass.** A control-verified finding ("GET queries empty for EVERYTHING incl. known-live metrics while rules still fire") sat in my head through the SEV1 write-up; it only landed as a monitoring.md row at report-authoring time. Self-harvest reflex is improving but still not instant.

### What could I still improve?
7. **Fourth strike of `rg -rn`** — the hook caught it again, and this time the AGENTS.md rule, the previous session's report (§d.4), AND the hook message itself all warned me. Two sessions, four strikes. The pattern needs to die: `rg` IS recursive; `-n` = line numbers; `-r` = REPLACE DISPLAY.
8. **Cross-repo formatter discipline:** I never ran crush-config's own `nix fmt` over my two-line removals there (their treefmt, their style). Harmless this time; sloppiness next time.
9. **Runbook state-sync:** `docs/services/ai-meter.md` documents the metric families but not that the dashboard + failure rule exist (state belongs in runbooks, not todo files). Small doc-sync item, queued (§f.28).

---

## a) FULLY DONE

| # | Done | Evidence |
| --- | --- | --- |
| A1 | **kimi-coding removed from ALL SystemNix surfaces** (owner directive) | home.nix extraRc line gone; ai-meter.nix upstream + sops copy gone; sops.nix declaration gone; `crush.yaml` key unset via `sops unset` (rc=0, grep-verified gone); crush-rc-test.sh alternation updated; runbook + crush.md + security.md updated; scoped `nix fmt` clean (0 changed) |
| A2 | **kimi removal eval-verified** | `nix eval …evo-x2…toplevel.drvPath` resolved (post-edit); sops-key-audit green by construction (declared set = yaml content) |
| A3 | **crush-config local removal** | `modules/home-manager/crush.nix:367` provider default + `flake.nix:358` rc-test assertion dropped in `~/projects/crush-config` (2 kimi refs repo-wide; 2 archived-doc mentions left deliberately) |
| A4 | **crush_key absent-file behavior STATICALLY verified** | `crush_key()` = `test -r "$f" \|\| return 0` + PLACEHOLDER skip (crush.nix:135-141) → unregistered provider, not keyless; row updated with the precise behavior |
| A5 | **Integration matrix verified end-to-end** | scrape job (signoz.nix:1329) · ClickHouse series (requests 1258 / cost 634 / ttft 530 / tokens 1902) · client×upstream×model attribution live (crush/inboxclean/paperless-gpt) · dashboard `systemnix-ai-meter` provisioned (13 panels, converged at 19:27 deploy) · "AI Upstream Failure Rate High (>30%)" rule provisioned (id `01a148a8-7c44…`, correctly inactive) · gatus endpoints answer (:8107/health ok, :8108 metrics serve) |
| A6 | **SEV1 outage discovered, root-caused, filed** | signoz-collector inactive/dead since 20:21:53; journal: `googlecloudmonitoring` receiver fatal `got: projects/` (InvalidArgument at descriptor prefetch) ×5 → start-limit-hit; samples_v4 freshness: ai_meter stops 20:19:39, node_cpu control 20:20:02; query-service/ClickHouse/gatus still active (stack-scale phantom-green); in-tree fix verified present; filed `[blocked:user]` SEV1 in docs/todo/monitoring.md + TODO_LIST queue incl. the detector-gap analysis |
| A7 | **Stale rows closed with live evidence** | "ai-meter: SigNoz dashboard + spend alert" watch row → `[x]` (premise was stale: built 2026-10-17; spend alert dispositioned: reference-cost overstate makes a spend alert a false-pager; ledger true-up owns real spend) · ai-meter BLOCKER premise-refresh row updated (ClickHouse + gatus legs resolved; only inboxclean turn owed) |
| A8 | **v1-API regression filed** | monitoring.md `[ready]` row: GET `/api/v1/query` returns `{"result":[]}` for EVERYTHING (control-verified: `up`, node_cpu, known-live textfile metrics) while the rules engine fires — the documented pre-verify workflow has no working live check until diagnosed |
| A9 | **Corrected the 20:59 report's wrong claims** | §d.1 below; the old report untouched (point-in-time) |

## b) PARTIALLY DONE

| # | Item | Works | Missing | Blocker | Effort |
| --- | --- | --- | --- | --- | --- |
| B1 | **AI-router × SigNoz integration** | Everything ABOVE the collector: config, scrape job, store attribution, dashboard, rule, gatus | Live ingestion since 20:21:53 (collector down — B2); p95 latency panels (no histograms — queued); monthly-spend alert (deliberately skipped — disposition recorded) | B2 | S after recovery |
| B2 | **signoz-collector recovery** | Fix IS in HEAD (project_id render + assertion + gatus receiver-lost alert; authored by the parallel session) | Deploy (root-session gated) + `reset-failed` + restart + post-verify chain; 20:19:39→recovery telemetry permanently lost (nothing buffered while down) | root session / owner-deployed | S (deploy is the long pole) |
| B3 | **kimi removal activation** | All repo surfaces done + statically verified | System switch (can ride the B2 recovery deploy); crush-config push + SystemNix flake.lock bump (separate leg) | deploy + push | S |
| B4 | **ai-meter BLOCKER-row closure** | Deployed, metering, store-verified, gatus-endpoint-verified | One inboxclean chat turn through the proxy (paperless leg dead upstream — FLM) | FLM decision | S |

## c) NOT STARTED

1. **Out-of-band collector-liveness detector** — the SEV1 was invisible to every in-band check by construction (the collector-down rule consumes metrics the dead collector scrapes; the gatus receiver-lost alert reads collector self-metrics). Fix shape named in the row (system-health textfile unit-state leg or gatus :8888 probe). Not started.
2. **v1 query-API contract diagnosis** — filed, not started. Until then dashboard/alert PromQL pre-verification is manual-CH-only.
3. **GCP receiver blast-radius decision** — one receiver's startup failure fatal'd the WHOLE collector (all pipelines). Isolate GCP scraping (separate collector instance), accept the risk, or disable-until-hardened: owner architecture call. Not started, filed as §g.3 question.
4. **Runbook sync (ai-meter.md dashboard/rule state) + metric-exists.sh freshness column** — noticed, queued, not started.
5. Everything carried from the previous report's §c (health-gate, openrouter/openseo, ledger consumer, histograms, 429 policy, retention check, crush-debug identity) — still not started, all queued with owners.

## d) TOTALLY FUCKED UP

| # | What | Severity | Root cause | Mitigation |
| --- | --- | --- | --- | --- |
| D1 | **My 20:59 advisory told you the router was "invisible to SigNoz — no dashboard, no alert" — WRONG on both counts** (dashboard + rule live since 2026-10-17; only the spend alert was genuinely absent). Medium: you received a false-gap report and I filed improvement items duplicating existing work | Medium (misinformation, now corrected) | I premise-checked the TODO ROW but not the CONFIG (never grepped signoz.nix / dashboards/ last session) — the exact "queue authors spot-verify config claims" rule, violated at advisory time | This report corrects the record; the stale row is closed with evidence; lesson logged in §e.6 |
| D2 | **The entire telemetry stack silently dark 20:21:53→now (~100 min at discovery)** | Critical (operational) | deploy-7 carried the 07:48 GCP re-arm that was explicitly "deploy gated on a root session" (2cb6e7901), without the project_id fix; receiver fatal at first live arm | Fix in HEAD; recovery queued; the gate-jump itself is §g.3's process question — I did NOT cause it and did NOT silently absorb it: flagged loudly instead |
| D3 | **Permanent telemetry gap 20:19:39→recovery** | Medium (data loss, bounded) | push/scrape telemetry doesn't buffer while the collector is dead | Recorded in the SEV1 row so nobody expects backfill |
| D4 | **`rg -rn` — FOURTH strike across two sessions** | None (hook) | muscle memory, repeatedly warned | See §0.7; the hook works, the operator doesn't |
| D5 | **Six wasted fetch probes on a broken API path before using the documented python3 method** | Low (time) | instinct (curl-shaped tool) over doctrine (documented method) | §0.3 |

## e) WHAT WE SHOULD IMPROVE

1. **Recovery first**: deploy the collector fix in a root session, `reset-failed`, verify ingestion resumed; ride the kimi-removal activation on the SAME deploy (one switch, two closures).
2. **Monitor-the-monitor must be out-of-band**: any detector whose data path passes through the component it watches is decorative during that component's death (proven at stack scale today). The system-health textfile unit-state leg (or gatus probing :8888) closes the class for the collector; audit the OTHER self-referential detectors for the same shape.
3. **Gated-changes must not ride arbitrary deploys**: `2cb6e7901` said "deploy gated on a root session"; deploy-7 carried it anyway — into a fatal. Mechanism needed: a eval-time or pre-deploy-check gate that recognizes armed-but-ungated changes (the assertion exists for empty-projects; it cannot catch "the gate was about deploy timing").
4. **Premise-check by GREPPING THE CONFIG, not the todo row** (D1's lesson, now twice-paid): advisories about feature existence must cite config evidence (`rg signoz.nix dashboards/`), not stale rows.
5. **Probe verification workflows when docs are the only witness**: the v1-API regression sat undetected since whenever the GET contract changed — nothing in the repo exercises the DOCUMENTED verification method itself. A tiny selftest (fire one known-live query through the documented path, fail on empty) would have caught it the day it broke.
6. **Read the service runbook before domain queries** (schema stumbles were all pre-documented) and **grep parallel reports for the affected component**, not your topic.
7. **`rg -rn` goes to zero.** No more strikes to spend.

## f) Things we should get done next (30 — brainstorm-framed per skill guidance; NEW items already harvested to TODO_LIST/monitoring.md per the self-harvest rule; T4 items are pre-existing rows restated one-line)

**T0 — Telemetry recovery (now)**
1. Root-session deploy carrying the collector fix + `systemctl reset-failed signoz-collector` — Critical · S (deploy) · Bug · NEW, queued `[blocked:user]`
2. Post-recovery verification chain: samples_v4 fresh, journald flowing, traces_coverage reporting, rule states re-evaluating — Critical · S · Quality · RESIDUE of 1
3. Out-of-band collector-liveness detector (system-health unit-state leg or gatus :8888 probe) — Critical · M · Feature · NEW, in the SEV1 row
4. GCP receiver blast-radius decision: isolate into a second collector vs accept vs disable-until-hardened — High · decision · NEW, §g.3
5. Diagnose the v1 query-API GET regression + re-validate the documented pre-verify workflow + update monitoring.md/signoz.md — High · M · Bug · NEW, queued
6. Accept + document the permanent 20:19:39→recovery telemetry gap (no backfill exists) — Medium · S · Documentation · part of row 1

**T1 — ai-meter × SigNoz residue**
7. One inboxclean chat turn through the proxy (last BLOCKER-row leg) — High · S · Quality · EXISTING
8. gemini live smoke: declare a model in crush-config + one proxied session + cost entries — High · M · Feature · EXISTING (cross-repo)
9. ai-meter ledger report consumer (`pkgs/ai-meter/reports/` empty) — Medium · M · Feature · EXISTING
10. Histogram latency families (p95 TTFT panels) — Medium · S · Feature · EXISTING
11. In-proxy 429 policy decision (transparent vs retry-after; kimi-failover dead) — High · decision · EXISTING
12. usage.jsonl retention/rotation check — Medium · S · Cleanup · EXISTING
13. crushrc extraRc health-gate (shape per §g.1) — Critical · S · Feature · EXISTING
14. crush-debug client identity (attribution polish) — Low · S · Feature · EXISTING

**T2 — kimi removal legs**
15. Activate the kimi removal on the recovery deploy + verify chain (no /run/secrets key, 404 on /v1/kimi, no kimi series, provider absent from picker) — High · S · Quality · NEW, queued `[blocked:deploy]`
16. Push crush-config kimi-coding removal + bump SystemNix flake.lock — High · S · Cleanup · NEW, queued `[blocked:push]`

**T3 — GCP/SigNoz hardening (from today's incident)**
17. Answer §g.3, then implement: separate gcp-collector instance with its own unit + dashboards unaffected — High · L · Feature · NOT STARTED
18. Eval-gate for armed-but-deploy-gated changes (prevent the deploy-7 jump) — Medium · M · Quality · NEW (implicit in the SEV1 row)
19. metric-exists.sh: add last-sample timestamp (freshness) to the output — Medium · S · Quality · NEW
20. signoz.md cheat-sheet: samples_v4 schema + freshness probe + (post-5) the working query invocation — Medium · S · Documentation · NEW
21. ai-meter.md runbook: document dashboard + failure-rule existence (state lives in runbooks) — Low · S · Documentation · NEW
22. Verify `system_gatus_meta_*` textfile metrics actually flow (queries returned empty pre-recovery — API-broken confound, re-check after 1) — Low · S · Quality · NEW

**T4 — Pre-existing AI-stack rows surfaced by this session (one-liners, all already in the library)**
23. FLM disable-or-pin owner decision (blocks paperless leg) — Critical · decision · EXISTING
24. FLM 512-token batch starvation fix — High · EXISTING
25. hermes rogue reranker :8849 kill-or-bless — High · decision · EXISTING
26. llama-chat better-model bench (abliterated-only) — Medium · EXISTING
27. Vulkan llama.cpp owner-gated soak — Medium · EXISTING `[blocked:user]`
28. llama-chat gatus live verification — High · EXISTING `[blocked:deploy]`
29. NPU-telemetry premise-check — Medium · EXISTING
30. openrouter upstream re-add + openseo route (key landed 2026-10-26) — High · EXISTING

## g) Three questions I cannot figure out myself

**Q1 — Proxy-down doctrine (carried from 20:59, still blocking).** When ai-meter is dead, should crush fall back to DIRECT calls (availability first) or fail closed (no AI without metering)? The extraRc health-gate shape depends on it; today's behavior is accidental (dead sessions).

**Q2 — 429 policy (carried, now sharper).** 31×429 today on zai. Keep transparent (manual switch), bounded retry-after, or is failover dead now that kimi is gone and glm-5.3-flash is the only same-family fallback? With kimi retired the "failover" option has no target — does that settle it to transparent+documented-manual-switch?

**Q3 — GCP receiver blast-radius (new, born from today's SEV1).** One receiver's startup failure took down the ENTIRE collector (all signals). After recovery: (a) keep GCP scraping in-collector and accept that a GCP config bug can black out all telemetry again, (b) isolate GCP into its own collector process (blast-radius containment, +1 unit to monitor), or (c) disable-until-hardened? I can implement any of the three; the risk tradeoff is yours.

---

**Format note:** `.md` per your explicit instruction (skill-canonical is styled HTML; flagged as one-off override, not propagated). **Commit:** skipped per harness rule (daemon picks it up). **Harvest status:** complete — A7/A8 rows + SEV1 row landed BEFORE this report; T4 items pre-existed and were not duplicated.

**NEXT: WAITING FOR INSTRUCTIONS.**
