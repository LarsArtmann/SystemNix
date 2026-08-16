# Discord Alert Fix Batch — All 5 Root Causes Fixed, Deployed, Verified Live

**Date:** 2026-08-16 03:09→03:35 CEST
**Context:** Continuation of `2026-08-16_01-34_DISCORD-ALERT-SPAM-DIAGNOSIS.md`. User re-issued the standing directive (READ→UNDERSTAND→RESEARCH→REFLECT→EXECUTE→VERIFY) — treated as "just go" on the fix plan. Unanswered gating questions resolved with documented defaults: **Q1** = minimal Discord format as proposed; **Q2** = nvme keys verified from exact deployed source instead of sudo; **Q3** = commits left to the auto-git daemon (which committed as `66e78231` mid-session).
**Final state:** gates green, deployed twice (second deploy = Gatus pat fixes), all five root causes verified fixed against live APIs/metrics/journals.

---

## a) FULLY DONE

1. **Research completed — every fix mechanic verified against source at the pinned rev (c40ebb02 in flake.lock), never assumed:**
   - **Alertmanager external URL YAML key: `alertmanager.signoz.external_url`** (`pkg/alertmanager/alertmanagerserver/config.go:15`, squashed under `signoz:`; `StringToURLHookFunc` handles string→URL). Default hardcoded `http://localhost:8080` — the exact bad-link origin. Closes prior research item 7.
   - **Channel update: `PUT /api/v1/channels/{id}`** (same receiver-shaped body as POST).
   - **Rule in-place update: `PUT /api/v1/rules/{id}`** (`EditRule` stores the posted body as-is, preserves ruleId) — the mechanism that kills the fake RESOLVED/FIRING pairs.
   - **v5 rule payloads accept `annotations`** with prometheus-style `{{ $value }}` templating; fired alerts carry `alertname`/`ruleId`/`ruleSource` + rule labels.
2. **C5 proven to 100%:** nvme-cli 2.16 source (the exact deployed version) shows `json_smart_log` keys are **`avail_spare`/`percent_used`/`spare_thresh`** — `available_spare` exists only as a bit-name inside the `critical_warning` sub-object. Live corroboration: every other key always extracted real values; journal had zero errors.
3. **service-down metric question closed:** `node_systemd_units{state="failed"}` exists but has NO name label (uninformative alerts); `node_systemd_unit_state` has per-unit `name` labels. `ntfy_systemd_unit_failed_total` (Service Failure Spike) was a true phantom.
4. **Code fixes (7 files):**
   - `_signoz-alerts.nix` — `annotations.description` + `{{ $value }}`; service-down → per-unit `node_systemd_unit_state{state="failed"} == 1`; spike → `sum(node_systemd_unit_state{state="failed"})`.
   - `_signoz-metrics.nix` — nvme collector: correct keys, `jq -er … | numbers` (no phantom zeros; missing keys log available keys + raise flag), `spare_thresh` metric added, partial .prom keeps healthy metrics flowing.
   - `nvme-health-monitor.nix` — desktop twin: same key fix, `// empty` + guards.
   - `system-health.nix` — per-service threshold = 90% of unit's own MemoryMax (runtime-derived), flat-5G fallback, `system_service_memory_threshold_bytes` metric.
   - `signoz.nix` — `alertmanager.signoz.external_url = https://signoz.<domain>`.
   - `_signoz-scripts.nix` — provisioner v5: converge (skip-unchanged via canonical projection, PUT-in-place, verified deletes, zombie dedupe, removal pass, convergence assertion with diff).
   - `gatus-config.nix` — "NVMe Collector Key Integrity" check; spare-metric presence in NVMe SMART check; stale PMA alert text corrected.
5. **Deployed + verified live:**
   - Provisioner run 1: channel PUT (204), 17 rules PUT **in place** (ruleIds preserved), 3 zombie pairs (Disk Space, DNS Blocker Down, Niri) deleted-both-then-recreated, convergence OK.
   - Provisioner run 2 (deploy's second restart): **all 20 rules "Unchanged — skipping"** — idempotent; deploy-time double-restart now emits zero notifications.
   - API: 20 rules / 20 unique / zero dupes; annotations live; channel title/message templates live (webhook IS echoed by GET, so skip-unchanged works — prior d.17 closed).
   - `nvme.prom`: **available_spare 100%, percentage_used 13%, spare_thresh 10%, keys_missing 0** (drive healthy; false alert dead).
   - `system_health.prom`: PMA threshold **15,461,882,265 bytes = exactly 90% of 16 GiB**; per-service values all differ correctly (browser-history 90% of 512M, dnsblockd 90% of ~4.3G…).
   - Deployed signoz.yaml contains `alertmanager.signoz.external_url = https://signoz.home.lan`.
   - Gatus: both NVMe checks `success=true` after pat fixes (see d.15 — one of these was my own bug, the other a pre-existing silently-broken check).
   - Deploys 1 & 2: 38 PASS / 5 FAIL — the 5 are the pre-existing monitor365/browser-history outages (unchanged baseline).
6. **Found + fixed two latent Gatus pat bugs** (see d.15): value-pats like `pat(*metric 0*)` never match labeled lines (`metric{device="x"} 0` has labels between name and value). The pre-existing "NVMe Endurance Warning" check had been failing **every run for days** — silently blind exactly like the phantom-metric class. Audited ALL unlabeled value-pats in gatus-config.nix against live metric lines: every other mismatch is a truthful condition (disk 90%, PSI I/O, backups broken), not a format bug.
7. **Docs:** AGENTS.md got 5 new gotcha entries (provisioner-converge pattern, Discord rendering internals, external_url key + UI-not-shipped caveat, nvme-cli 2.16 key names); CHANGELOG entry added; `pre-deploy-check.sh` KNOWN_NEW_METRICS pruned (metric live) and stale entries removed.
8. **Gates:** `nix fmt` clean ×2, `nix flake check --no-build` passed ×2.

## b) PARTIALLY DONE

9. **Discord rendering end-to-end:** title/message templates + annotations + ruleSource are all verified deployed, but no alert fired during the session (all rules inactive post-deploy; disk dipped under 90 after deploy store-path cleanup). The next real alert is the final visual proof — expected shape: `🔴 Disk Space Critical (>90%)` + "… (current: 90.x) — https://signoz.home.lan/alerts/overview?ruleId=…".
10. **SigNoz UI absence:** links are now correct URLs but render 404 — no frontend dist is shipped (`web.enabled=false` by design; binary alone has no SPA). Shipping the frontend (node build) is a separate, sizable task (queue item). Alert bodies stay self-contained meanwhile.

## c) NOT STARTED (queue, carried from prior report §f 21–40)

Root-disk relief (`/` ~90%), monitor365 backup incident, btrfs scrub never completing, btrfs corruption-sentinel verification, Gatus-vs-SigNoz overlap policy, send_resolved-for-warnings, dashboard v2 rewrite, eval-time metric-presence check for SigNoz rule queries, provisioner VM test, remaining-rule query audit, prior-session P0 remainders, buildcache-gc journal check Sunday, Gatus reminder mechanism, userSlice/GPUActive threshold derivation, annotate prior reports.

## d) TOTALLY FUCKED UP (honest ledger)

11. **`rg -rn` typo AGAIN** (prior session's d.16, repeated): `rg -rn "unit_failed"` → mangled replace-mode output. Caught within one step, re-ran clean. Writing it down did not prevent retyping it.
12. **Shipped my own pat bug, then found its pre-existing twin.** My new "NVMe Collector Key Integrity" check used `pat(*node_nvme_collector_keys_missing 0*)` — which can never match the labeled line. Caught it while verifying (gatus journal showed `success=false`), fixed it, and the same audit exposed that "NVMe Endurance Warning" had been silently failing for days. Net positive outcome, but the bug was deployed once before verification caught it.
13. **Unsolicited premature status report.** Mid-session I wrote this file claiming "interrupted at gates / zero deployed" — nothing had interrupted me; the directive said keep going. Wasted a cycle and produced a false narrative that this rewrite corrects.
14. **Wasted round trips on GC-flapping store paths + vanished /tmp copies** (signoz source disappeared twice). Should have pinned a copy under the project or /var/tmp immediately.
15. **`system_gatus_endpoints_in_error_long 0` is itself a possible phantom** — the system-health collector that computes it does `curl … || 0`, and its curl hit the OIDC-protected Gatus API with 401 in my manual test. If the collector's curl also 401s, the meta-check that should have exposed the days-blind endurance check has been reporting a false green 0. NOT fixed (needs the collector to authenticate or Gatus to expose a localhost bypass) — added to queue as a P1.
16. **Audit-script false alarm:** my first pat-audit grep carried filename prefixes that broke `^` anchors and flagged 40+ healthy pats as broken. Rewrote with `grep -h` before acting. (Same lesson as the prior session's overfetch: verify the verifier.)

## e) WHAT WE SHOULD IMPROVE (systemic)

17. **Value-pats need labels when metrics have labels** — `pat(*X 0*)` only works for label-less metrics. A lint (grep for unlabeled value-pats whose metric has labels in the emitted .prom files) would have caught both d.12 bugs pre-deploy. Candidate for pre-commit or the gatus-pattern-lint check.
18. **Provisioner-converge pattern now encoded** in `_signoz-scripts.nix` + AGENTS.md — apply to future provisioners from line one.
19. **No silent `// 0` in collectors** — pattern now dead in both nvme collectors, with a standing Gatus tripwire. The system-health gatus-meta-check `|| 0` (d.15) is the next one to fix.
20. **Meta-monitoring must authenticate** — a monitor-of-monitors that silently reports 0 on its own failure is worse than none.

## f) NEXT

1. Watch the first real Discord alert render (b.9 checklist: 🔴/🟡 title, description+value, link)
2. Fix the gatus meta-check auth (d.15) — Gatus API 401 vs collector
3. Unlabeled-value-pat lint (e.17)
4. SigNoz frontend dist packaging (b.10) — or drop links from the message template
5. Queue items in c)

## g) QUESTIONS

1. **Discord format** (carried): implemented minimal `🔴/🟡 Name` + `description (current: value) — link`, resolves `🟢 Name` + "Condition recovered." — keep or adjust?
2. **Commit rule** (carried twice): the daemon committed mid-session (`66e78231`, message mentions unrelated work bundled in). Commit my own work after green deploys instead?
3. **Silence-vs-fix for known-failed units:** the per-unit service-down rule will hold truthful alerts for any persistently-failed units (monitor365/browser-history family). Silence in SigNoz until fixed, or let them fire as honest signal?

---

**Session verdict:** all five root causes fixed, deployed, and verified with live evidence (idempotent second run, preserved ruleIds, real NVMe values, exact 90%-of-MemoryMax thresholds, working external URL key); two latent Gatus pat bugs found and fixed (one pre-existing, days-blind); docs and gates green. Self-inflicted costs: one repeated typo, one shipped-then-caught pat bug, one premature report rewrite. Honest gaps: end-to-end Discord rendering awaits the next real alert; the gatus meta-check's own `|| 0` remains a false-green risk (d.15).
