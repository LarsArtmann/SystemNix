# Status: paperless decision-triage P1 execution — module landed, VM test iterating, deploy pending

**Session:** 2026-10-27 21:40–22:43+ (ongoing) · instance `crush-triage-exec-2026-10-27` (plan tombstone `65a2a3aa1`-era) · **Scope:** execute the decision-triage productionization plan's agent-owned tasks T1/T2/T6/T8 (plan `docs/planning/2026-10-27_21-17_paperless-decision-triage-productionization-plan.md`, EXECUTING marker written before any work).

---

## a) FULLY DONE (as of 22:43)

1. **Plan tombstone** — EXECUTING marker written + committed (rode daemon batch `65a2a3aa1`); the `**Written:**` header aligned to the house `**Created:**` form the marker script anchors on.
2. **T1 implementation — `modules/nixos/services/paperless-triage.nix`** (new, ~640 lines): confidence-gate sweep oneshot + 5-min timer in front of paperless-gpt; runtime-minted paperless token (paperless-gpt-token pattern, zero sops); ai-meter client registration (`paperless-triage`, OPENAI_API_KEY envKey) honoring the owner's single-endpoint direction; registry entry (vHost.layer none, 2 gatus checks: unit-state via system-health collector + verdict-down absence-check on the textfile metric); backup-coordination freshness repurposed onto `/var/lib/paperless-triage/last-sweep` (1 h tolerance); catalog entry (port null); declarative `needs-review` tag + "Needs Review (triage)" saved view through the dashboard provisioner; PSI admission gate as an in-script soft skip. Wired in `configuration.nix`. **evo-x2 toplevel eval GREEN.**
3. **The verdict-provider root-cause swap (load-bearing):** the plan's "local FastFlowLM margin-verdict" premise was tested against the DEPLOYED stack and failed it — flm v1.0.2 has NO logprobs (whole-deployment binary strings scan: zero `top_logprobs`; the upstream logprobs docs postdate our pin, and the bump is blocked by the v1.0.3 NPU start-failure rule). llama-server 0.6.0 (llama-chat :8850) carries top_logprobs binary-proven AND **live-proven this session: Faktura sample → margin +0.985, letter → −0.985, exact variant-token folding my parser handles.** Verdicts route through ai-meter's `llama-chat` upstream; paperless-gpt EXTRACTION stays on flm. Both corrections documented in the module header + plan execution record.
4. **T6 — accounting-field drift reconciled declaratively:** `services.paperless-dashboard` gained `ensureTags` + `ensureCustomFields` (create-only, provisioner-ordered BEFORE saved views resolve — the ordering fix); `paperless-gpt.nix` now declares its lifecycle tags + `faktura` + `Invoice number`(string) + `Issue date`(date). Live-probe root-cause reconstruction: EVERY 2026-10-19-created entity vanished (faktura, fields 1000012/13, `paperless-gpt-auto` 1000010) while ALL pre-pilot entities survived — consistent with the SUPERB restore clobbering exactly the pilot-evening DB state. Runbook DRIFT box → RESOLVED with the declarative path + `journalctl -u paperless-dashboard-provision | grep ensured` verify step.
5. **T2 — margin scoring in `scripts/paperless-decision-bench.sh --score`:** per-doc top-2 MARGIN column + margin≥0.6 gate simulation alongside confidence≥0.9; `.b64-*` temp files mktemp'd (row 105d). **Offline re-run done.** Finding: **Jev's top-2 margin ALSO saturates on wrong doc_class answers** (mean-margin wrong = 1.00 image / 0.99 text; margin gate error-inside ≈ confidence gate's) — threshold choice cannot fix label noise; the P2 shadow stays the only honest accuracy number. Recorded in plan execution record + runbook.
6. **T8 — eval loop folded into the A24 quarterly re-audit** (runbook §Quarterly re-audit now carries corpus regeneration + `--score` re-run + golden-label folding; ONE cadence, next 2027-01-02).
7. **Docs:** paperless.md §"Decision-triage gate" (full runbook section incl. watermark semantics + failure posture); llama-chat.md consumer note; plan §9 execution record.
8. **VM test written** — `tests/test-paperless-triage.nix` (real paperless+PG VM, options-only llama-chat/fastflowlm/pocket-id/mail-relay mocks, in-VM python mock verdict server with the exact logprobs shape, consume-two-docs end-to-end: Faktura→PASS tag, letter→needs-review, entity provisioning, metrics assertions, idempotence leg) + registered in tests/default.nix.

## b) PARTIALLY DONE

1. **VM test leg — three build iterations fixed, not yet green:** (1) writeShellApplication shellcheck SC2034 (dead `status` var in api() — removed); (2) driver typecheck `json` unresolved (import added); (3) ruff F541 f-string-without-placeholders (fixed). Fourth build running at report time. Each failure was caught by the check machinery doing its job — no fix was speculative.
2. **Deploy not started** — gated on the VM test + the 2026-10-25 quiescence discipline (clean tree + no eval-relevant mtime < 5 min across ≥4 polls; a parallel session is ACTIVE tonight: monitor365 watchdog edits, browser-history/ai-meter rewiring, crush-daily tile work — two mid-edit races already hit this session, both self-resolved).

## c) NOT STARTED

- Deploy + anchor verification + post-deploy check + live sweep smoke (the P1 go-live).
- Post-deploy entity verification (`paperless-dashboard-provision` ensured_tags/ensured_fields).
- ai-meter logprobs PASSTHROUGH verification (verdicts through :8107/v1/llama-chat — binary-proven on llama-server direct, proxy leg untested).
- TODO surface close-outs (row 103 → [x] after verify; TODO_LIST line sync; CHANGELOG).

## d) TOTALLY FUCKED UP

1. **First module draft shipped without the `flake.nixosModules.<name>` wrapper** — the file landed as a raw module in the flake-parts context (`assertions`/`services.*` don't exist there), failing every flake eval with a misleading error chain. Root cause: I wrote the module from the paperless-gpt PATTERN memory instead of copying its STRUCTURE. Cost: one eval cycle. Also fumbled the wrapper's closing brace + a `...,` ellipsis-comma syntax error in the same fix — three parse iterations for a mechanical wrapping mistake.
2. **Environment misread — twice:** (a) probed flm cold-load INTO an active memory emergency (guard tripped, FLM RESTORE CAPPED, ZRAM CRITICAL — the 22:06 backend start was stopped by the idle-TTL at 22:10 mid-load; my queued curls got empty responses). The runbook says do NOT race a trip zone with the 21.6 GB cold load — I started the socket before checking guard state. No harm (the guard + TTL contained it), but the probe was wasted and fought the box's own protections. (b) llama-chat direct probe timed out at 120 s under loadavg 226 (the 21:40 session's TTFT row documented exactly this) — fixed by re-probing at 600 s in the background, which landed the live proof.
3. **A dead code block (half-written jq state persist) shipped in the first sweep-script draft** — caught by my own re-read before any build, but it should never have been written past-tense like that; draft discipline.

## e) WHAT WE SHOULD IMPROVE

1. **Wrapper-first module authoring:** new service modules must START from `cp paperless-gpt.nix` (or any sibling) and edit inside — the discovery mechanism is invisible until it bites. A 10-line template note could live in docs/CONTRIBUTING.md's module section.
2. **Check machine state BEFORE any LLM-adjacent probe:** one `journalctl --since -5min | grep -i 'guard\|sev1'` before touching flm/llama sockets would have shown the trip zone for free. The sev1-bridge-check lines are loud and were simply unread.
3. **The live-probe ladder worked and should be repeated:** upstream docs → binary strings scan (cheap, zero-load) → long-timeout background live probe → post-deploy smoke. Each rung caught what the previous couldn't (docs ≠ deployed version; strings ≠ endpoint behavior).

## f) Next tasks

| # | Task | Impact | Effort | Cat. |
|---|------|--------|--------|------|
| 1 | VM test to green (iteration 4 building) → deploy via `nix run .#deploy` under the quiescence discipline → anchor verify → post-deploy-check → live sweep smoke (journal + tags + `.prom`) | High | M | Execute |
| 2 | Post-deploy: verify ensured tags/fields in the paperless DB + `Needs Review (triage)` view + ai-meter logprobs passthrough (one manual sweep with a real consumed doc) | High | S | Verify |
| 3 | Close surfaces: services.md row 103 → [x] (with evidence), TODO_LIST line sync, CHANGELOG entry, plan-marker `done` | Medium | S | Docs |
| 4 | If the deploy is blocked tonight by the parallel-session tree: re-dispatch under the same tombstone (row 103 stays [ready] with an UPDATE note) | Low | S | Contingency |

**Harvest record:** f.1–f.3 are THIS session's remaining plan-execution steps (tracked by the plan tombstone + this report, not new queue rows — anti-duplicate discipline); f.4 is the contingency that becomes row 103's UPDATE if hit. No new domain-library rows created: every durable follow-up already rides row 103 (closes on verify), row 105 (Clef/pricing, owner keys), or the plan §6 pack (P2/P3).

## g) Questions I cannot answer myself

1. **None new.** The plan §6 owner pack (Q1–Q7, silence-defaults documented) remains the only owner-gated surface; P2/P3 stay parked behind it. The verdict-provider swap (llama-chat, not flm) is an implementation correction inside P1's already-dispatched scope — flagged here and in the module header for visibility, not re-asked.
