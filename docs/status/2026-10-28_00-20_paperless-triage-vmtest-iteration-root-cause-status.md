# Status: paperless decision-triage P1 — VM test 13 iterations deep, root-cause chain nearly closed, deploy still pending

**Session:** 2026-10-27 21:40 → 2026-10-28 00:20 (ongoing; 3rd checkpoint report) · instance `crush-triage-exec-2026-10-27` · **Scope:** execute the decision-triage plan's agent tasks T1/T2/T6/T8. Earlier snapshots: 22-43 report (implementation landed). This report covers the VM-test iteration battle since.

---

## a) FULLY DONE (unchanged from the 22:43 report + new)

1. **T1 implementation** — `modules/nixos/services/paperless-triage.nix` complete (module, sweep script, token mint, timer, registry/catalog/monitoring, ai-meter client, configuration.nix wiring); **evo-x2 toplevel eval green** throughout.
2. **Verdict-provider swap, live-proven** — llama-chat logprobs (Faktura → margin +0.985, letter → −0.985); flm v1.0.2 logprobs absence binary-proven; documented in module + runbook + plan.
3. **T6** — declarative `ensureTags`/`ensureCustomFields` in paperless-dashboard + gpt-side declarations; DRIFT box resolved with root-cause reconstruction; runbook updated.
4. **T2** — margin scoring + mktemp fix in the bench script; offline re-run done (finding: Jev margin ALSO saturates on wrong answers — recorded).
5. **T8** — eval loop folded into the A24 quarterly re-audit cadence (runbook).
6. **Docs** — triage runbook section, llama-chat consumer note, plan §9 execution record, 22:43 status report.
7. **NEW since 22:43 — the test-helpers textfile-dir fix**: `tests/test-helpers.nix` created the shared Prometheus textfile dir as 0755 root while production is 1777 sticky — every service-user collector (paperless-tasks-collector included, pre-existing) mktemp-EACCES'd in VMs while passing on the real host. Fixed to 1777 (root-cause fix in the harness, not my call site).
8. **NEW — two VM-test hardening wins along the way**: provisioner boot-race convergence (test restarts `paperless-dashboard-provision` after the login page genuinely serves — the deploy.sh action; boot-triggered preStart's 60s budget is a load flake under host loadavg ~220) and the `psiMaxPercent` module option (default 30; tests widen it because the HOST's IO storm bleeds into the guest's `/proc/pressure/io` via virtiofs — avg10 measured 96-97% DURING the test runs).

## b) PARTIALLY DONE

1. **VM test `tests/test-paperless-triage.nix` — 13 build/run iterations, 12 distinct failures found and fixed, ONE known root cause just fixed, attempt 14 building:**
   - Fixed chain: missing flake-module wrapper (3 parse iterations) → shellcheck SC2034 → driver typecheck (`json` import) → ruff F541 → jq invalid `\s` escape (found by LOCAL jq testing first) → jq `// empty` short-circuit on the null-logprobs case (fixture 3 caught it) → provisioner boot-race (host-load flake) → PSI gate refusing in-VM (by design, host storm; made the band configurable) → **the real kicker, found at 00:1x: `maintenance-entry-gate: command not found` — my rewrite of the sweep script DROPPED `pkgs.maintenance-entry-gate` from runtimeInputs, and my `>/dev/null 2>&1` on the gate call HID the reason for four iterations.** The instrumented refusal line (new WARN carrying the gate's own output) named it instantly. runtimeInputs fix applied; attempt 14 building in background.
   - Test already proves GREEN through: boot, paperless+PG, mock verdict server, token mint artifacts (0400/paperless-triage), margin-parser selftest (in-VM), entity provisioning (needs-review tag + saved view, `ensured_tags=1`), document consumption (both docs with content), textfile dir 1777. The only unproven legs: the live verdict→tag routing assertions + metrics/idempotence (blocked entirely by the PATH bug).
2. **Deploy + live verification + surface close-outs** — still not started (gated on the VM test; parallel sessions active all night: monitor365, browser-history/ai-meter, crush-daily, cv — two mid-edit eval races hit, both self-resolved).

## c) NOT STARTED

- VM-test green → `nix run .#deploy` (quiescence discipline) → anchor verify → post-deploy-check → live sweep smoke.
- Post-deploy: entity verification, ai-meter logprobs passthrough probe, first real verdict through the proxy.
- Surfaces: services.md row 103 close-out, TODO_LIST sync, CHANGELOG, plan-marker `done`.

## d) TOTALLY FUCKED UP

1. **The runtimeInputs regression — MY bug, four iterations deep:** my first draft HAD the gate in runtimeInputs; the full-file rewrite dropped it. Worse: I routed the gate's stderr to /dev/null "for cleanliness", converting a loud `command not found` into a generic "IO PSI above band" WARN that sent me chasing PSI thresholds, env propagation, unit-file rendering, and gate semantics for ~90 minutes (three of those checks were CORRECT findings that ruled out real suspects — but the actual cause was unobservable by my own hand). The lesson is already house law in another shape: **never swallow the failure reason of a component you don't control** — the one-line instrumentation found it in a single build.
2. **My local gate repro was methodologically broken** (`PSI_MAX=100000 cmd --psi-max "${PSI_MAX:-30}"` — the expansion happens in the CURRENT shell before the prefix-assignment applies; I briefly "confirmed" the gate ignored env before re-testing correctly). The corrected export-form repro exonerated the gate — but only after I'd written a wrong intermediate conclusion into my working notes.
3. **Same pattern as earlier in the session, third instance:** one diagnostic iteration was wasted checking a hypothesis (attempt 12's env) I had ALREADY proven correct by eval — I lost track of which build carried which tree state across 13 rebuilds. A running build-log would have prevented it.

## e) WHAT WE SHOULD IMPROVE

1. **Sweep-script stderr discipline:** every external-tool failure inside service scripts should surface the tool's OWN error text (this repo's provisioners mostly do; my gate call didn't). The fix is in the module now — worth a one-line note in CONTRIBUTING's script section.
2. **Diff-driven rebuild ledger:** after ~5 rebuild iterations, I should have kept a one-line-per-attempt table (build id → tree delta → failure) — two times tonight I re-derived state that a ledger would have shown.
3. **The check pyramid is genuinely working:** every failure except the runtimeInputs bug was caught by a DIFFERENT layer (shellcheck, driver typecheck, ruff, local jq fixtures, in-VM selftest fixtures, the instrumented WARN). No failure shipped. The cost was iterations, not correctness.

## f) Next tasks

| # | Task | Impact | Effort | Cat. |
|---|------|--------|--------|------|
| 1 | Await attempt 14 (gate on PATH) → expect the verdict-path assertions to finally execute; fix whatever they surface (the mock-logprobs path is locally proven, so remaining risk is API-shape only) | High | S | Execute |
| 2 | VM green → `nix flake check --no-build` (whole-tree, parallel-session races tolerated with retry) → deploy under quiescence discipline → anchor + post-deploy-check + live sweep smoke (journal, tags, `.prom`, gatus checks green) | High | M | Execute |
| 3 | Post-deploy: `journalctl -u paperless-dashboard-provision | grep ensured` (tags/fields live again), one real verdict through ai-meter (logprobs passthrough), `Needs Review (triage)` view visible | High | S | Verify |
| 4 | Close surfaces: services.md row 103 → [x] with evidence, TODO_LIST sync, CHANGELOG entry, plan-marker `done`, final status report | Medium | S | Docs |
| 5 | If deploy stays blocked by parallel-session tree churn tonight: leave row 103 `[ready]` with an UPDATE noting "implementation+test green, deploy pending" and stop cleanly | Low | S | Contingency |

**Harvest record:** all five are this session's remaining plan-execution steps under the standing tombstone — no new queue/library rows needed (anti-duplicate: they close or update existing rows).

## g) Questions I cannot answer myself

1. **None.** (Owner-gated surfaces remain the plan §6 pack Q1–Q7 + the Cloudflare keys for the Clef arm + the 9-`general`-docs label audit — unchanged from the prior reports; nothing NEW is owner-blocked by tonight's work.)
