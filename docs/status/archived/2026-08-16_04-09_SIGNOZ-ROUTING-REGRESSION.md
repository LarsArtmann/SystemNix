# SigNoz→Discord Routing Regression — Found, Root-Caused, Live-Fixed (Report, then STOP)

**Date:** 2026-08-16 04:09 CEST
**Arc:** Resumed the alert-fix queue (test render → gatus meta-check → pat lint → …). The "watch first real alert" item turned into the discovery that **the entire SigNoz→Discord pipeline has been silently dead since ~02:45** — the previous session's "deployed and verified" state contained a false green. Root cause found in pinned upstream source + live APIs, fixed live via API, permanent fix designed.

---

## a) FULLY DONE

1. **Todo list corrected** — stale items (gates/deploy/docs) marked complete, queue loaded.
2. **Prior state re-verified (point-in-time discipline):** provisioner idempotent (20/20 "Unchanged", convergence OK at 03:26), live rules carry the NEW queries (`node_systemd_unit_state{state="failed"} == 1`, `sum(...)`, no ntfy phantom) and `annotations.description`; nvme metrics real (100% spare / 13% used / 10% thresh, `keys_missing 0`). `Systemd Service Failed` inactive is truthful — zero units in `failed` state right now.
3. **`hardware-configuration.nix` diff triaged:** deliberate parallel work (rust-cache mount removal, dated today, documented in-comment). Left untouched.
4. **CRITICAL DISCOVERY — routing regression (the big one):**
   - SigNoz's **custom dispatcher** routes alerts exclusively via `notificationManager.Match(orgID, ruleId, labels)` → **route policies named exactly by ruleId** (GetAllByName → expr-lang expression over alert labels → channels). The route tree shown in `/api/v1/alerts` (`default-receiver`) is display-only and irrelevant.
   - Route policies are auto-created only for rules carrying `notificationSettings` (the UI's v2alpha1 path). Our v1-API provisioned rules (`preferredChannels` only) never get them.
   - Legacy per-channel `ruleId` regex bindings are built once at signoz startup; the provisioner v5's recreate/dedupe cycles (02:45, 03:14) minted **new rule UUIDs with no bindings** → `Match` returns zero channels → **silent drop**. Notifications actually stopped between 03:07 and 03:19; the Disk >90% alert has been firing since 03:19 with **zero Discord deliveries**.
   - **Empirical proof chain:** PUT/POST of rules does NOT create policies (list stayed empty). A manually created policy (name=ruleId, `ruleId == "<uuid>"`, channels=[Discord Alerts]) + a test rule with a >256-rune alertname produced `"Truncated title"` from the **Discord notifier** at 04:08:09 with `group_key receiver="Discord Alerts"` → eval → push → dispatch → Match → Discord notify all demonstrably fired.
5. **LIVE FIX APPLIED:** 20 route policies created via `POST /api/v1/route_policies` (one per rule, name=ruleId, channels=[Discord Alerts], tags=[systemnix, auto-provisioned]). Real alerts deliver again — expect 🔴 "Disk Space Critical (>90%)" in Discord (delivery itself is journal-silent; chain proven separately).
6. **Two more latent bugs diagnosed:**
   - `ruleSource` label still `http://localhost:8080/...` — `alertmanager.signoz.external_url` does **not** control the rule engine's GeneratorURL (different `externalURL` setting feeds `BaseRule.GeneratorURL`). Correct key not yet identified.
   - `{{ $value }}` in annotations renders **empty** ("current: ") — template context for promql-rule annotations apparently lacks `$value`. Verify or drop.
7. **Gatus meta-check fix fully designed** (not yet written): OIDC-401 false-green confirmed in code (curl → `|| 0`). Fix = read `/var/lib/gatus/gatus.db` directly with `sqlite3 -readonly` — schema pinned from gatus v5.36.0 source (`endpoints`, `endpoint_results`, `success INTEGER`, WAL mode, gatus prunes its own window → whole-table EXISTS/NOT-EXISTS = sustained failure); freshness via db+wal mtime; `system_gatus_meta_scrape_errors` + `system_gatus_results_stale` flags; primary metric emitted only on success (absence = red). Permissions analyzed: collector is root with empty CapabilityBoundingSet; `/var/lib/private` is root:root 0700 (root owns → traverses), StateDirectoryMode 0755 + umask 022 → 0644 db readable via other-bits.
8. **Sources pinned in-repo** (`.cache/`): gatus v5.36.0 + signoz c40ebb02 tarballs — /tmp and store paths proved volatile (again).

## b) PARTIALLY DONE

1. **~~Chain-proof test artifacts still live~~ resolved** — deleted by the 06-38 session (CHANGELOG "Test artifacts from the routing-regression diagnosis removed"; live state re-verified 20 rules/20 policies).
2. **~~Permanent provisioner fix designed, not implemented~~ resolved** — provisioner v6 policy convergence deployed + live-proven by the 06-38 session (recreated 20 wiped policies in 13s; second run idempotent). — GET `/api/v1/route_policies` (they're visible now), create-if-absent (name=ruleId, expression `ruleId == "<id>"`, channels), delete orphans **filtered by systemnix tag** (never touch user policies), convergence assertion = exactly one policy per rule. Must go into `_signoz-scripts.nix` + the VM test.
3. ~~Gatus meta-check: design complete (a.7), code not written (`system-health.nix` collector + `gatus-config.nix` conditions + `pkgs.sqlite` runtimeInput).~~ resolved — sqlite-direct rewrite shipped by the 06-38 session
4. Truncation warnings (02:52–03:07) explained: REAL deliveries through stale bindings using the OLD default title (label-dump >256 runes). Our custom short title was live and fine all along — no bug in the templates.

## c) NOT STARTED (carried queue)

Unlabeled-value-pat lint; provisioner idempotency VM test (now must cover policy convergence); dashboards v2-vs-delete (ghost 400'd again at 04:01); root-disk relief (~90% — the Disk alert is real); Gatus-vs-SigNoz overlap policy; send_resolved policy; prior-session P0s.

## d) TOTALLY FUCKED UP (honest ledger)

1. **The previous session shipped a false green:** "no alerts since deploy" was read as "nothing to send" while alerts were firing and being silently dropped. Journal silence was ambiguous (successful notifies are log-silent) and the session concluded "awaiting next genuine event" instead of forcing a test. This session's forced test exposed the dead pipeline within minutes.
2. I initially misread "Truncated title" warnings as "custom template broken/ignored" — they were old-template deliveries; the templates were fine. Wrong hypothesis, cost a detour.
3. Deep source-dive detour on WHY SigNoz's auto-policy-generation doesn't fire for v1-API rules (processRuleDefaults materializes notificationSettings in-memory; CreateRoutePolicies evidently still doesn't persist — exact upstream reason **unverified**). Bypassed empirically; direct API provisioning is verified working.
4. First test rule was eaten by a parallel deploy (04:01 `switch-to-configuration test` — user/other session, not me) mid-proof; second attempt succeeded. Also repeated the known `/tmp` volatility hazard for the rid note.
5. Parallel deploy at 04:01 also re-ran provisioning: all 20 rules "Unchanged" (idempotency held through a third party restart — good), but it deleted test rule 1 and left its policy orphaned.

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **Absence of errors is not delivery.** Every "verified" claim needs a positive signal. The truncation-warning trick (force a warning-class log line through the real path) is one cheap probe; a periodic canary alert would make delivery permanently self-proving.
2. Three silent-failure layers surfaced this arc (gatus meta-check auth, SigNoz routing, phantom-zero collectors). Pattern: every pipeline stage needs its own probe — prose assurances keep failing, checks haven't.
3. Pin upstream source tarballs in-repo at first deep-dive, not after they vanish.

## f) NEXT (priority order)

1. Delete chain-proof rule `01a00852-8bee-7537-bea3-6066077c8499` + its route policy (and the orphaned policy of deleted test rule 1, name `01a00838-4e10-74eb-9380-dcb93fd3fb8d`).
2. Provisioner: route-policy convergence + orphan cleanup + assertion (design in b.2), then VM test.
3. Fix `ruleSource` GeneratorURL (find the rules-engine external-URL config key) and the empty `{{ $value }}`.
4. Gatus meta-check sqlite rewrite (design in a.7).
5. Pat lint; dashboards ghost decision; root-disk relief (~90% — now actively alerting, correctly).
6. Carried queue (monitor365 backup, btrfs items, overlap policy, …).

## g) QUESTIONS

1. Commit rule for sessions (asked repeatedly, still unanswered)?
2. **Now urgent:** known-failed services (monitor365/browser-history family) will genuinely ping Discord once their alerts fire — silence them until fixed, or let them fire as honest signal? Same for the real Disk >90%.
3. Dashboards: v2 rewrite or delete the ghost provisioning?
4. Add a permanent daily canary alert to Discord (self-proving delivery) — yes/no?

---

**Session verdict:** the standing queue's first item ("watch first real alert render") exposed that there was nothing to watch — the pipeline was dead. Root-caused to route-policy routing in SigNoz's custom dispatcher, fixed live (20 policies), delivery chain machine-proven end-to-end at 04:08:09. Permanent fixes designed but NOT deployed — see f.1–f.4. STOPPING here per instruction.

---

## Resolution (2026-08-17, docs-health pass)

All b-section items resolved by the 06-38 permanent-fix session (struck above; its report is the authoritative record). Carried queue (c): unlabeled-value-pat lint → TODO_LIST P3 (HTML-needle variant); provisioner VM test → P3; dashboards → DONE (23-27, 251→5 native-v2); root-disk relief → P0; overlap policy + send_resolved → untracked. f-list: f.1 done (artifacts cleaned), f.2 done (v6 convergence), f.3 done (external URL + `{{$value}}` fixed), f.4 done (sqlite meta-check), f.5 — dashboards done / pat lint routed / root disk P0, f.6 moot (monitor365 disabled). g.2 — monitor365 moot (disabled), browser-history recovered; disk alert doing its job (P0). g.4 (daily canary) → untracked (delivery proven via probe). Archived as resolution-complete.
