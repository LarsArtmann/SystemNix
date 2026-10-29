# Paperless decision-triage productionization — design + owner decision pack

**Created:** 2026-10-27 21:17 CEST (session following the 20:55 bench-status report)
**EXECUTING (instance crush-triage-exec-2026-10-27, 2026-10-27 21:40 CET, HEAD `65a2a3aa1`):** executing (see AGENTS.md plan-execution tombstone)
**Inputs:** [Jev×paperless exploration](../status/2026-10-27_19-46_jev-decision-models-paperless-exploration-status.md) · [Bench + live Jev run](../status/2026-10-27_20-55_decision-model-bench-built-jev-live-run-status.md) · [Bench results dashboard](../research/2026-10-27_paperless-decision-bench-results.html) · [AI-MAX plan](./2026-10-02_13-32_PAPERLESS-AI-MAX-EXECUTION-PLAN.md) (A7/A8 landed = paperless-gpt live) · bank-sync [ledger kernel design](file:///home/lars/projects/bank-sync/docs/planning/2026-10-02_11-50_ledger-accounting-kernel-design.html) + [target mesh](file:///home/lars/projects/bank-sync/docs/planning/2026-10-04_04-05_target-mesh.d2) · journal README/AGENTS (the kernel)
**Status:** DESIGN — Stages P1 is dispatchable today; P2+ gated on the decision pack (§6). Nothing here is deployed.

---

## 0. Recommendation (one paragraph)

Productionize as a **triage gate in front of the existing paperless-gpt pipeline**, not as a new parallel writer. Stage P1 (a local, FastFlowLM-verdict confidence gate) fixes the live 2026-10-19 burn class (70 receipts → 210 attempts → 0 successes → terminal `paperless-gpt-failed`, no confidence check anywhere) with zero cloud dependency and is implementable now. Stage P2 adds Jev/Clef classification as a **log-only shadow** over the consume path; Stage P3 turns triage output into paperless custom fields — which is precisely the join-key surface `documents.v1` already pulls for journal/bank-sync; Stage P4 is the mesh consuming it. The vocabulary must be fixed **now** because journal (the accounting kernel) is young — its SCHEMA_CONTRACT does not yet mention documents.v1 — and the classifier's output fields should be designed into that contract before it hardens.

## 1. Evidence base (what the bench actually proved)

| Fact | Number | Source |
|---|---|---|
| Receipts+invoices (the accounting classes) | **38/38 across both arms** | results dashboard §per-class |
| Image arm overall (incl. label-noisy `general`) | 23/28 (82%) | dashboard |
| Text arm overall | 34/38 (90%) | dashboard |
| p50 latency | 446 ms image / 368 ms text | dashboard |
| Token spend | 147,940 input tokens, 66 calls, all answered | dashboard |
| Encrypted statements → `noul` is_accounting | ≈0.09 (correctly "not accounting") | dashboard |
| Known weakness | confidence saturates near 1.0 on right AND wrong answers → **top-2 probability margin is the gate signal, not confidence** | bench §d |

Open holes (from the 20:55 report §f): Clef arm (owner keys), owner label audit of the 9 `general` docs, margin scoring not yet implemented, $/1k-docs not computed.

## 2. Where this lands in the Artmann financial mesh

The mesh (bank-sync target-mesh + kernel design, both source-read this session):

```
InboxClean ──files──▶ Paperless-ngx (evidence store) ◀──sync-back metas/attachments── bank-sync
                        │
                        ▼ documents.v1 (pull: id, checksum, CUSTOM FIELDS, OCR text)
                     journal (kernel: reconcile, VAT, period close) ──postings.v1──▶ reporting
```

- **Paperless is already the mesh's evidence store** and `documents.v1` already carries **custom fields as join keys** (kernel design: "join keys already in bank-sync's V11/V12 ledgers"; REST pull verified 2026-10-02 via ListDocumentMetas + ListDocumentChecksums + UpdateDocument + DownloadDocument, webhook optional).
- **journal's `Entry.Document DocumentRef`** = paperless document_id + checksum — every booked entry can cite its evidence. Reconciliation tiers (0–2 auto-book, 3 propose) match `(transaction, candidate documents, paperless links)`.
- **bank-sync ↔ paperless V11/V12 ledgers** already track statement uploads by checksum — typed statements close the bank-side evidence loop.

**Therefore:** a reliable `doc_class` + `is_accounting` on every document (a) shrinks journal's tier-3 proposal queue by excluding non-accounting docs from candidate sets, (b) routes receipts vs invoices vs statements to the right reconciliation tier, (c) gives bank-sync's matcher a candidate filter (`is_accounting=false` never matches a bank tx), and (d) does all of it through a contract that already exists — no mesh changes needed, only field vocabulary agreement (§5, P4).

**Sequencing argument (why now):** journal's SCHEMA_CONTRACT.md currently has **no documents.v1 section** (verified by grep this session). The kernel's paperless leg is the natural consumer of triage output; agreeing the field names BEFORE journal writes that section costs one conversation, after it costs a migration.

**Drift warning the mesh already taught us:** the 2026-10-27 DRIFT box in `docs/services/paperless.md` (accounting custom fields wiped by the SUPERB restore, `Invoice number`/`Issue date` fields absent, gpt tag counters 0) is exactly the fragility journal's `verify-drift` exists for. P3 must ship with field-schema re-provisioning (the queued runbook-reconciliation row) and the restore runbooks must treat custom fields as state, not decoration.

## 3. Target architecture — four stages

### P1 — Confidence gate (LOCAL, no cloud, fixes a live burn class) — dispatchable now

A `paperless-triage` oneshot (systemd service + timer, PSI-gated like every sweep here) that sits **in front of the existing tag-gated paperless-gpt pipeline**:

```
consumption finished → triage oneshot:
  doc has paperless-gpt-auto tag? (or inbox?) → ask LOCAL FastFlowLM verdict:
    "Does this document contain extractable <field> values? {yes,no} + margin"
  above threshold  → leave/apply `paperless-gpt-auto` (existing pipeline runs)
  below threshold  → apply `needs-review` tag → existing saved-view pattern
  flm unreachable  → apply nothing, exit nonzero (NO terminal fail — trap §7.1)
```

Why a wrapper and not a paperless-gpt patch: paperless-gpt's `AUTO_TAG_MAX_RETRIES=3` terminal-fails on ~30–60 s of LLM unavailability (runbook trap #1) and has no confidence hook upstream. The tag is the seam — the triage unit owns admission, paperless-gpt keeps extraction. This also retires the need for the DISABLED consumption workflow 1000003 (trap §7.2): tag-gating replaces doctype-matching entirely.

Gate signal: yes/no verdict **margin** (probability gap), not raw confidence — the bench's saturation finding. Threshold initial value 0.6, tuned from the P2 shadow data.

### P2 — Dry-run shadow classification (CLOUD, log-only) — gated on pack Q1–Q3

Same unit, `--shadow` mode: for each consumed doc, one decision-model call (contract §4), result written to journald + a local JSONL ledger (`/var/lib/paperless-triage/shadow.jsonl`) + textfile metrics. **Zero writes to paperless.** Runs 2 weeks; the diff between shadow decisions and the archive's actual owner-maintained classes IS the production accuracy number (the bench corpus was 80% `new`-tagged and label-noisy — shadow mode replaces label audit with lived truth). Also where the margin threshold is calibrated.

Privacy line (carried from the bench): shadow sends page-1 images of receipts/invoices/general ONLY; statements and anything tag-`encrypted` are excluded in code, not by policy comment.

### P3 — Gated writes (routing + custom fields) — gated on pack Q4–Q6

Triager writes, on pass: tags (`triage-invoice` etc. — existing-tag vocabulary only, `CREATE_NEW_TAGS=false` discipline) and custom fields `doc_class` + `is_accounting` + `triage_margin` + `triage_ts`. Routing rule: `doc_class=receipt|invoice` → add `paperless-gpt-auto` (extraction pipeline). Below margin → `needs-review`. **Never writes `document_type`** while the workflow-matching anomaly is unresolved (§7.2). Field creation goes through the same declarative DRF provisioning as the 2026-10-19 pilot, plus a restore-proof re-provision oneshot (the SUPERB lesson).

### P4 — Mesh consumption (cross-repo, no SystemNix deploy)

- journal: documents.v1 contract addendum — `doc_class`, `is_accounting`, `triage_margin` as documented join keys; candidate filtering + tier routing as §2.
- bank-sync: matcher candidate filter `is_accounting=true` (its side of the V11/V12 metas).
- Both are sovereign repos; their own sessions do the work. This plan is the input they cite.

### SystemNix implementation shape (P1–P3, per integration-registry checklist)

- `modules/nixos/services/paperless-triage.nix` — loopback only, NO vHost, NO dashboard tile (not user-facing; registry entry with `vHost.layer = "none"`), catalog entry co-imported.
- Port: none needed (oneshot + timer, not a daemon) — no `lib/ports.nix` entry until/unless a daemon emerges.
- Secrets: `platforms/nixos/secrets/decision-bench.yaml` already holds the TypeSafe key (rename/extend when promoted: `typesafe_api_key` + provider config); cloud provider stays sops, paperless token runtime-minted (bank-sync pattern, same as paperless-gpt-token).
- Hardening: `harden {} // serviceDefaults {}`, `ioschedulingclass`/PSI gate per the maintenance-entry discipline, startLimitBurst 5.
- Monitoring: textfile collector `paperless-triage.prom` (§5), Gatus freshness check (sweep age < 2× interval) via registry `checks`, SigNoz rule for refusal-rate drift; unit in `signoz-coverage` only if OTel-instrumented (shell oneshot: no — journald + textfile is the honest surface).
- Tests: VM-test leg asserting unit + timer render and the needs-review tag path with a stubbed verdict; fixture leg for the margin parser; `deploy-restart-audit` picks the timer up automatically.

## 4. What we ask the model (per-call question contract)

One call per document, two questions (both bench-validated; keep v1 minimal — routing only, **extraction stays with paperless-gpt**, no overlap):

```json
{
  "model": "jev-latest",
  "questions": {
    "doc_class": {
      "type": "choice",
      "instructions": "Classify this document's first page.",
      "criteria": "receipt | invoice | bank_statement | letter_or_other"
    },
    "is_accounting": {
      "type": "noul",
      "instructions": "Is this document accounting-relevant evidence (receipt, invoice, statement)?",
      "criteria": "Answer 'none' if the document is neither financial evidence nor a bank statement."
    }
  }
}
```

- `state` = page-1 image asset (P2/P3) or OCR text (fallback when image egress is denied — pack Q1).
- Computed locally, never asked: **margin = p(top1) − p(top2)** from the returned `probabilities`.
- Deliberately NOT in v1: amount/currency/VAT (paperless-gpt owns extraction; the `Invoice number`/`Issue date` fields already model this), correspondent (native suggestions own it), contract class (waits for gbc/contracts.v1, M4+). The v1.5 candidate is `reference_number` (Box) — a join hint for journal's matcher — but only after P2 proves the base classes.

## 5. What we send back (telemetry + eval loop)

**Textfile metrics** (Prometheus, per sweep):

| Metric | Labels | Purpose |
|---|---|---|
| `paperless_triage_decisions_total` | `class`, `arm` | volume + distribution drift |
| `paperless_triage_margin_bucket` | `arm` | calibration; threshold tuning |
| `paperless_triage_refusals_total` | `reason=margin\|api_error\|skip_class` | gate rate = the drift alarm |
| `paperless_triage_latency_seconds` (buckets) | `arm` | p50/p95 vs the 446 ms bench number |
| `paperless_triage_input_tokens_total` | `arm` | spend accounting → $/1k-docs |
| `paperless_triage_backlog` | — | sweep liveness |

**Gatus:** sweep freshness (last-success age). **SigNoz rule:** refusal rate >20% over 24 h → "triage drift" (label noise or model change — the dashboard's core lesson: watch the labels, not just the model).

**Eval loop (the actually-valuable send-back):** every owner correction of a triage-written tag/field is a golden label. Record corrections as `paperless_triage_corrections_total{from,to}` via a lightweight document-audit listener (or the weekly digest script reading modification history), and regenerate the bench corpus + re-run `--score` quarterly — fold into the existing AI quarterly re-audit (next due 2027-01-02) so there is ONE cadence, not two.

## 6. Owner decision pack (silence = default, house convention)

| # | Question | Default if unanswered |
|---|---|---|
| Q1 | **Egress classes:** may page-1 IMAGES of receipts/invoices/general leave the LAN to a metered cloud decision API? (Statements + encrypted: never, in code.) | YES for those 3 classes; statements text-arm-only stays local-forever |
| Q2 | **Spend ceiling:** monthly USD cap for decision calls (bench burn-rate ≈ 66 calls ≈ trivial; production est. tens of docs/week)? | $5/mo hard cap with circuit-breaker → local-verdict-only mode |
| Q3 | **Backend:** cloud Jev vs Cloudflare Clef vs local (AnyJev-on-llama-server, still unverified) vs none (P1 gate only)? | Decide after the Clef arm + pricing land (the two open bench items) |
| Q4 | **Autonomy ladder:** P2 shadow (2 wk) → P3 tag+field writes? | Shadow 2 weeks, then tags+fields (never `document_type`) |
| Q5 | **Write targets:** tags vs custom fields vs document_type | Tags + `doc_class`/`is_accounting` custom fields; `document_type` stays manual (workflow 1000003 anomaly) |
| Q6 | **Cloud-down policy:** queue-and-retry vs skip-to-review | Skip-to-review tag, zero terminal fails (2026-10-19 lesson) |
| Q7 | **Label authority:** when triage disagrees with an owner tag | Owner tag wins; disagreement → review view + eval-corpus record (feeds §5 loop) |

Q1/Q2 extend the existing `[decision]` cloud-API-policy row (services.md); Q3 folds the Clef/pricing bench continuations; Q4–Q7 are new with this pack.

## 7. Traps encoded (each one is live history in this repo)

1. **Retry-cap terminal-fail** (2026-10-19): 70 receipts, 210 attempts, 0 successes, `paperless-gpt-failed` terminal. The triage unit must NEVER let an upstream-outage path end in a terminal state — the gate exists to make burn classes impossible, not to add one.
2. **Workflow matching anomaly** (3.3.1 consumption workflow matched UNTYPED docs; hit twice): P3 writes tags/fields only; the doctype-writing path stays closed until the anomaly is root-caused.
3. **Confidence saturation**: gate on margin, never confidence (bench §d).
4. **Custom-field fragility across restores** (SUPERB wipe, 2026-10-27 DRIFT box): fields are state — declarative provisioning + restore-runbook line + journal verify-drift coverage.
5. **Label noise > model noise**: every accuracy claim is provisional until the owner label audit / shadow-diff lands; the bench's 82%/90% are LABEL-limited numbers.
6. **Egress discipline**: class-exclusion in code (§3 P2), `TypeSafe-Danger-Zone-Images` header only ever wraps allowlisted classes; the sops file never gains statement-class keys.

## 8. Execution tasks (maps to TODO surfaces)

| # | Task | Stage | Owner | Maps to |
|---|---|---|---|---|
| T1 | Implement `paperless-triage` P1 (local verdict gate in front of paperless-gpt, needs-review routing, metrics, VM test) | P1 | agent | services.md gate-design row (updated: design landed here §3) |
| T2 | Margin scoring in `--score` + re-run bench (calibrates T1's threshold) | P1 | agent | services.md run row continuation (b) |
| T3 | Clef arm + pricing → $/1k-docs (pack Q3 input) | P2 | **owner keys** → agent | services.md run row continuation (a)/(c) |
| T4 | P2 shadow mode behind `--shadow` flag (2-week timer, JSONL ledger, metrics) | P2 | agent (after Q1–Q3) | new row, gated on pack |
| T5 | P3 writes: DRF field provisioning (incl. re-provision oneshot), tag routing, negative-test legs | P3 | agent (after Q4–Q6) | new row, gated on pack |
| T6 | Accounting-extraction drift reconciliation (field re-provision or retire — prerequisite for P3's field set) | P3 | agent | existing services.md row |
| T7 | journal documents.v1 contract addendum + bank-sync candidate filter | P4 | **cross-repo sessions** (journal/bank-sync; cite this plan §2/§4) | foreign repos — owner hands them this plan |
| T8 | Quarterly eval regeneration folded into the AI re-audit cadence | P4 | agent | services.md re-audit row (2027-01-02) |

## 9. Harvest record (this doc's own obligations)

> **EXECUTION RECORD (crush-triage-exec-2026-10-27, T1/T2/T6/T8):** P1
> LANDED with two evidence-driven design corrections, both binary/live
> verified and documented in `modules/nixos/services/paperless-triage.nix`
> + `docs/services/paperless.md` Decision-triage-gate section: (1) the
> verdict provider is **llama-chat via ai-meter, NOT FastFlowLM** —
> deployed flm v1.0.2 has zero logprobs support (whole-deployment strings
> scan; the upstream logprobs docs postdate our pin) while llama-server
> 0.6.0 carries top_logprobs (live-proven: +0.985/-0.985 sample margins);
> (2) verdict-down exits 0 + refusal metric + Gatus absence-check instead
> of nonzero — repeated nonzero exits brick a 5-min timer unit via
> startLimitBurst (worse visibility than the metric pair). T2 landed in
> `--score` (per-doc MARGIN column + margin>=0.6 gate sim) and its output
> SHARPENS the saturation trap: Jev's top-2 margin ALSO saturates on wrong
> doc_class answers (mean-margin wrong = 1.00/0.99) — threshold choice
> cannot fix label noise; the P2 shadow remains the only honest accuracy
> number. T6 landed as declarative ensureTags/ensureCustomFields in
> paperless-dashboard (gpt lifecycle tags + faktura + both pilot fields;
> DRIFT box resolved with root-cause reconstruction). T8 folded the eval
> loop into the A24 quarterly re-audit (runbook Quarterly re-audit
> section).

- T1: services.md gate-design row **updated this session** (design landed → implement), TODO_LIST queue row synced.
- Q1/Q2: folded into the existing cloud-API-policy `[decision]` row (pointer to §6 added).
- T4/T5: NOT queued as `[ready]` (pack-gated); recorded here + in the pack table as the waiting state. They become rows when the pack answers.
- T7: cross-repo — cannot ride the SystemNix queue; this section is the record that it is deliberately not harvested (owner hands §2 to the journal session).
- T2/T3/T6/T8: already tracked (run row continuation / existing rows); no duplicates created.

> **EXECUTION RECORD addendum (2026-10-29, T1d VM iterations 14–18):** the
> VM test caught two REAL paperless-3.3.1 API contract bugs plus two script
> bugs that live-API probes had missed (live probes never exercised a
> bulk_edit write or a name→id lookup against an existing tag population):
> (a) `bulk_edit modify_tags` requires BOTH `add_tags` AND `remove_tags`
> keys — every production sweep would have 400'd on every write; (b)
> `/api/tags/?name=` is not a server-side filter in 3.3.1 (declared lookups
> are `name__iexact` etc.) — lookups silently return ALL tags, and the T6
> provisioner's existence check built on it meant the drift-heal would
> create NOTHING once any tag existed (the exact SUPERB-restore scenario it
> was built for); both now exact-match client-side. Script bugs: the
> selftest EXIT trap outlived its function-local temp var (nounset kills
> the script at exit 0, bash reports "line 1"), and `ensure_tag` logged
> "created tag" to stdout — polluting the captured tag id into invalid
> JSON on any fresh/restored instance. Fixed + documented as runbook traps
> 1–3 in paperless.md §Decision-triage gate.
