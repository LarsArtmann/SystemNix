# Paperless-ngx metadata extraction: fix pass — 2026-10-30 02:10 CET

Continuation of `2026-10-29_23-23_paperless-metadata-extraction-audit-status.md` (the audit). This session was instructed to **"fix all issues"**. The pipeline now runs end-to-end for the first time: one real document was enriched live, and every blocker that kept it idle is either fixed-and-deployed, fixed-and-pending-deploy, or explicitly blocked on an owner input.

**Deployed:** `system-966` (`/run/current-system` == newest `system-966-link`, anchor verified). **Tree:** one uncommitted file (`scripts/paperless-repair-empty-content.sh`, work in progress).

---

## §0 Proof that extraction now works (the thing the audit could not show)

Document **1001738** (Vercel receipt), tagged `paperless-gpt-auto` at 01:51, processed by `paperless-gpt` through `ai-meter → llama-chat`:

| Field | Before | After |
| --- | --- | --- |
| title | `Your receipt from Vercel Inc. #2492-0258` | `Rechnung Vercel Inc. #2492-0258 - Artmann Technologies GmbH` |
| document_type | **none** | **Invoice** (id 1000004, one of the 8 types added this session) |
| tags | gmail, new | gmail, new, **faktura**, **paperless-gpt-auto-complete** (trigger tag removed) |
| correspondent | Vercel Inc. | Vercel Inc. (unchanged, matched) |
| created | 2024-03-03 | 2024-03-03 (unchanged, already correct) |
| custom fields | none | `Brutto in PLN = USD20.00`, `VAT in PLN = USD0.00` (**wrong fields — see §4**) |

Journal: `Suggested title…` / `Suggested tags…: [faktura gmail new]` / `Suggested correspondent…: Vercel Inc.` / `Suggested document type…: Invoice` / `Suggested createdDate…: 2024-03-03` / `Document 1001738 processed successfully. Runtime: 00:05:10`.

Two more documents (`1001750`, `1001742`) are still queued at report time: **~5 min per document** on the CPU model (§5 improvement 1).

---

## §1 (a) FULLY DONE

| # | Item | Evidence |
| --- | --- | --- |
| a1 | **`paperless-gpt` env-var names fixed** (camelCase → `MANUAL_TAG`/`AUTO_TAG`/`AUTO_TAG_COMPLETE`/`FAIL_TAG`) — previously a silent no-op because upstream defaults coincided | `nixos/services/paperless-gpt.nix`; deployed unit carries `AUTO_TAG=paperless-gpt-auto`; `/api/config` no longer reports `None` |
| a2 | **`AUTO_GENERATE_*` pinned explicitly** (title/tags/correspondent/type/date) | `/api/config`: all `'true'` |
| a3 | **LLM route moved off the NPU server to `llama-chat`** with evidence: FastFlowLM v1.0.2 **hangs at ~1.5k prompt tokens (600 s) then dies `double free or corruption (!prev)`, SIGABRT** — live-proven by a probe, and extraction sends six prompts/doc plus the whole tag/correspondent/type vocabulary | `llmUpstream` option (default `llama-chat`); `OPENAI_BASE_URL=http://127.0.0.1:8107/v1/llama-chat`; route probe `http=200 "OK"` |
| a4 | **Prompt budget bounded**: `TOKEN_LIMIT=6000`, `CORRESPONDENT_PROMPT_LIMIT=80` (was unbounded + all 235 correspondent names) | deployed unit env |
| a5 | **triage PSI band re-calibrated 30 → 75** with measured justification; the unit no longer refuses on pressure | `PSI_MAX=75` in the deployed unit; journal shows no "admission gate refused" |
| a6 | **Polish added to the paperless OCR language set** (`deu+eng+pol`) so PL documents stop losing every diacritic | deployed `PAPERLESS_OCR_LANGUAGE=deu+eng+pol` |
| a7 | **Document-type taxonomy declared and provisioned** (`ensureDocumentTypes`): 3 → **11** types (`Invoice`, `Receipt`, `Contract`, `Letter`, `Tax Document`, `Insurance`, `Payslip`, `Identity Document`) | provisioner log `ensured_doctypes=8`; DB now lists 11 |
| a8 | **AUTO tag matching eliminated** (`enforceTagMatchingNone`, enforced not create-only): `new`, `gmail`, `sweaty`, `ai-generated`, `Accounting`, `empty-content`, `encrypted`, `needs-review` → `matching_algorithm=0`. The live DB now has **zero AUTO tags** (the 2026-09-06 classifier incident class is closed) | provisioner log `matching_fixed=6`; DB query `auto_tags == []` |
| a9 | **`empty-content` tag + "No text (needs attention)" saved view** provisioned (the 382-doc gap is now a first-class, visible object) | provisioner log `created saved view 'No text (needs attention)'` |
| a10 | **`llama-embeddings --ubatch-size 2048` is live** (the nightly `llm_index` 500 "input too large" cause; the fix itself came from a parallel session, this session deployed it) | `systemctl show llama-embeddings` → `--ctx-size`, `--ubatch-size` |
| a11 | **End-to-end extraction proven live** (§0) | doc 1001738 before/after |
| a12 | **Repair tool written and its OCR leg proven**: `gs` sanitize + paperless's own `ocrmypdf`/tesseract → 1,773 and 1,938 characters recovered from two signed Qonto/SCHEIBER receipts that paperless refuses to OCR | script run log |
| a13 | **README gatus-endpoint count re-stamped** 253 → 254 (the `doc-counts` eval gate blocked the deploy; a sibling session's endpoint wave landed without a re-stamp) | `nix flake check --no-build` exit 0 |
| a14 | **Cleanup of my own mistake**: the two debug documents I accidentally uploaded were deleted to trash (HTTP 204) | newest-doc probe shows only real documents |

## §2 (b) PARTIALLY DONE

| # | Item | State |
| --- | --- | --- |
| b1 | Backlog enrichment | 1 of 3 test docs finished; 2 still queued (~5 min/doc). Full backlog would take days (§5.1) |
| b2 | **triage routing** | The **second** live bug was found and fixed in the tree but **is not deployed**: the stored watermark `2026-10-28T18:30:44.755977+01:00` used raw in the query string has its `+` decoded as a space → paperless answers `400 {"added__gt":["Enter a valid date/time."]}`, so every sweep since 2026-10-28 18:30 refused at "candidate fetch". Fix = percent-encode the offset (`urlenc_ts`). Verified by hand: unencoded 400, encoded 200 |
| b3 | Signed-PDF repair | OCR works; the **upload step 400s** and is being diagnosed. Script now surfaces the server body (`-o/-w`) instead of a bare `curl: (22)` |
| b4 | `empty-content` tagging of the 382 docs | Tag + view exist; no document carries the tag yet (deliberately run AFTER the repair so it reflects the final state) |
| b5 | Coverage observability | Not added (planned: `paperless_documents_empty_content`, `_untyped`, `_gpt_complete` gauges in the existing tasks collector) |
| b6 | Runbook / todo / FEATURES updates | Not written (this report only) |

## §3 (c) NOT STARTED

1. Deploy of the triage watermark fix and a triage sweep end-to-end (route → `paperless-gpt-auto` or `needs-review`).
2. Repair run for the **83** signed PDFs.
3. The **15** password-protected statements — **blocked**: no age identity is available to either `lars` or root in this session (`sops -d` fails "failed to load age identities"), so the stored bank password cannot be read.
4. Per-image audit of the 284 empty images.
5. Manual `llm_index` verification (post-`ubatch`).
6. Backfilling document types for 1,780 untyped docs by bulk-tagging with `paperless-gpt-auto`.
7. Backfilling `created` for the 350 `created==added` docs.
8. `document_renamer` pass after repair (avoids `_01` filename suffixes from the replace-upload).
9. Prometheus/Gatus alerts for "gpt processed 0 in 24 h", "triage decisions stuck at 0", "empty content > 25%".
10. gpt custom-field currency handling (§4).

## §4 (d) TOTALLY FUCKED UP / STILL WRONG

| # | Item | Detail |
| --- | --- | --- |
| d1 | **Wrote 2 documents into the live archive** | While debugging the upload 400, two probe uploads (`ocr-out.pdf`, `probe title`) consumed successfully and became documents 1001756/1001757. **Fixed**: both deleted to the 30-day trash (HTTP 204). Root cause: I probed the production API with real files instead of a dry payload. |
| d2 | **Wrong currency in the accounting fields** | The model wrote `Brutto in PLN = USD20.00`, `VAT in PLN = USD0.00` for a USD receipt. The field names carry a currency that the prompt never enforces, so every non-PLN invoice that passes through gpt will pollute the PLN columns. Not fixed: it needs an owner decision on the schema or a prompt/prompt-selection rule (§6 Q2). |
| d3 | **Four repair-script iterations** | (i) `find -path '*-python*o*ocrmypdf-*'` never matched; (ii) `grep -E '\t'` is not a tab (POSIX ERE), so the candidate list came back empty ("0 documents"); (iii) ocrmypdf refused to write into my cache dir (`OutputFileAccessError`) because the paperless user cannot write there; (iv) upload diagnostics were swallowed. Each cost a full run. The correct design (run OCR inside paperless's own interpreter, scratch under the dataDir) should have been the first version. |
| d4 | **Second deploy needed** | I edited the triage watermark fix **after** the deploy, so the fix is in the tree but not live. Sequencing error: collect all fixes, then deploy once. |
| d5 | **`sudo` typed directly** | One call was blocked by the tool guard (`sudo -n bash scripts/… > log`); the log stayed empty and I mis-read the exit code as a script failure. Use the wrapper-script pattern from the start. |
| d6 | **`nix eval` warnings mistaken for failure** | The flake-input pin audit prints the pin list on every eval; I initially treated output volume as failure. Harmless, but it cost a read. |

## §5 (e) WHAT WE SHOULD IMPROVE

1. **Throughput.** `llama-chat` on CPU takes ~5 min/document (6 sequential prompts). 1,780 untyped documents = ~6 days serial with `SUGGESTION_WORKERS=1`. Options: raise `SUGGESTION_WORKERS`, use FastFlowLM for short documents (it handles ≤~700 tokens fine), or batch by document type.
2. **Currency-aware custom fields.** Either rename the fields to currency-neutral names, or restrict the selected fields per correspondent/currency, or add a prompt rule "if the field name names a currency, only fill it when the document's currency matches".
3. **Stale context in the custom-field prompt** (upstream): `app_llm.go:403` passes the *original* title/created/type, not the values suggested seconds earlier.
4. **`LLM_LANGUAGE=German`** is injected as "The content is likely in German" into 4 of 6 prompts on a PL/DE/EN archive; Polish receipts are told the wrong language.
5. **Triage drain rate**: `TRIAGE_MAX_DOCS=5` per 5-min sweep against a ~411-document watermark backlog = 13 hours just to catch up, and each admitted doc then costs 5 min of gpt time.
6. **Retry semantics**: `AUTO_TAG_MAX_RETRIES=3` poll cycles (~30 s) vs 5 min per document is still a razor-thin margin; a slow LLM can fail-tag a document that is still being processed.
7. **The one-gate-for-everything admission model**: a 30% IO-PSI band is unreachable on this host; other light timers may be silently starved the same way (this session fixed only triage).
8. **Address unknown**: nobody was alerted that triage had zero decisions for 2 days or that gpt had processed zero documents ever.
9. **`paperless-gpt` state is runtime-only** (`config/settings.json`, `prompts/`, `db/`) — a restore loses the selected custom fields. Declaring them would match the `ensureTags`/`ensureCustomFields` doctrine.
10. **Repair path needs a first-class citizen**: 21% of the archive was unsearchable for months without a signal; the script should become a scheduled, report-only job.

## §6 (f) NEXT 50 ITEMS

**Finish the in-flight work (1–6)**
1. Deploy the triage `urlenc_ts` fix.
2. Trigger a sweep; confirm `sweep done - processed>0` and a document gains `paperless-gpt-auto` or `needs-review`.
3. Fix the repair upload 400 (server body now printed); confirm one document is replaced and the original lands in trash.
4. Run the repair for all 83 signed PDFs (`--apply`), watching `failed=0`.
5. Tag every still-empty document with `empty-content`; verify the new saved view lists them.
6. Run `paperless-manage document_renamer` to drop `_01` filename suffixes after the repair.

**Verify the AI surface (7–13)**
7. Manually run `llm_index` and confirm success (RAG no longer dark).
8. Run `scripts/paperless-ai-stage0-eval.sh` and compare native-AI suggestions with gpt output on the same 10 docs.
9. Record gpt latency per document and size a real backlog plan.
10. Verify `ai_suggestions` works again through `:52625` after `systemctl start fastflowlm.socket`.
11. Decide whether native paperless AI and gpt should share `llama-chat` too (single endpoint, one model to warm).
12. Check `PAPERLESS_AI_LLM_CONTEXT_SIZE` vs the 32k llama-chat window.
13. Confirm `check_workflows`/`train_classifier` stay green for 24 h after the matching_algorithm change.

**Backfill the metadata (14–21)**
14. Bulk-tag untyped documents with `paperless-gpt-auto` in batches of ~20; watch for `paperless-gpt-failed`.
15. Re-run for documents that fail, after diagnosing (token limit? empty content?).
16. Backfill `created` for the 350 `created==added` docs (gpt suggests dates when it processes them).
17. Populate correspondents for the 300 unassigned documents (gpt creates them).
18. Audit which of the 11 document types are actually used after the backfill; retire unused ones.
19. Add `needs-review` triage for the documents gpt could not confidently type.
20. Decide the fate of `sweaty` (589 docs) and `ai-generated` (2 docs) — they are not a taxonomy.
21. Re-check the four *select*-type fields (`NIP`, `VAT percentages`, `Payment status`) — decide manual or workflow-driven.

**Repair the remaining content gap (22–27)**
22. Decrypt-repair the 15 password-protected statements (needs the age key; `inboxclean paperless --backfill --decrypt-repair --dry-run` first).
23. Audit the 284 images: sample 30 and classify "photo, no text" vs "text lost".
24. For images with text, add a vision-OCR path (needs a second LLM base URL or the ollama provider) — or accept them as photo evidence.
25. Consider `PAPERLESS_REMOTE_OCR_ENGINE` for the hardest scans.
26. Re-run the audit numbers after every bulk pass (the §0 inventory is the baseline).
27. Add a nightly "documents with empty content" gauge so the gap can only shrink visibly.

**Observability (28–34)**
28. Emit `paperless_documents_empty_content`, `_untyped`, `_no_correspondent`, `_gpt_complete` from the existing tasks collector.
29. Add a Gatus/SigNoz alert on "gpt processed 0 documents in 24 h".
30. Add an alert on "triage decisions total unchanged for 24 h".
31. Alert on `paperless_llmindex_last_success_age_seconds > 48h` (it was 32 failures deep, silently).
32. Log the triage refusal reason as a metric label (PSI vs API vs verdict), not just a WARN line.
33. Add a metric for gpt per-document runtime (sizing the backlog).
34. Re-run the `negative-tests.yml` harness if any of these become eval-time assertions.

**Code quality / upstream (35–42)**
35. Patch upstream `app_llm.go:403` to feed the freshly suggested title/date/type into the custom-field prompt.
36. Add a currency rule to `custom_field_prompt.tmpl` and make prompt overrides declarative (seeded `cp -rn` means operator edits survive deploys but are invisible to git).
37. Declare gpt's `settings.json` (selected custom fields, write mode) instead of leaving it runtime-only.
38. Add a VM test leg: "a signed PDF is repaired and the replacement carries the original metadata".
39. Add a VM test leg: "the watermark with a `+01:00` offset is queried correctly".
40. Reason about `AUTO_TAG_MAX_RETRIES` vs per-document runtime; either raise the cap or make it time-based.
41. Consider a `--class images` mode in the repair script.
42. Consider making the repair script report-only by default in a timer (no `--apply`).

**Docs & process (43–50)**
43. Update `docs/services/paperless.md` with: the inventory, the three empty-content classes, the pipeline's four failure modes, the `llama-chat` decision + evidence, the watermark bug, the currency caveat.
44. Record the traps: camelCase env in `systemd.services.*.environment`; `redo_ocr` vs `reprocess`; `?name=` not a filter; `+` in query strings; `accepts` vs `checks`; ocrmypdf needs a writable output dir owned by its user.
45. Add `docs/todo/services.md` rows for items 14–27 with lifecycle tags.
46. Update `FEATURES.md`: AI extraction is now "wired AND proven on one document", not "done".
47. Note the FastFlowLM ~1k-token ceiling in `docs/services/fastflowlm.md` (it hangs, then core-dumps).
48. Raise the flm restore budget with whoever owns the memory guard (3/day is not a paperless service level).
49. Add the parallel-session `buildflow` storm to the deploy-blocker playbook (it gated two sessions tonight).
50. Delete or promote my `~/.cache/paperless-audit/` probes; the useful ones belong in `scripts/`.

## §7 (g) THREE QUESTIONS I CANNOT ANSWER MYSELF

**Q1 — Backlog policy.** `llama-chat` on CPU costs ~5 min/document, so enriching all 1,780 untyped documents is ~6 days of continuous inference. Should I (a) leave the pipeline to only new arrivals, (b) bulk-admit everything and let it grind for a week, (c) raise `SUGGESTION_WORKERS` and accept more CPU pressure, or (d) route short documents through the NPU (`fastflowlm`, safe up to ~700 tokens) and only long ones through `llama-chat`?

**Q2 — Currency handling for `Brutto in PLN` / `VAT in PLN`.** The model put `USD20.00` into a PLN-named field. Do you want the fields renamed currency-neutral (`Brutto`/`VAT`), the selection limited to PLN documents, or a prompt rule that only fills them when the document currency matches (leaving foreign invoices empty)?

**Q3 — Authorization + key for the remaining repairs.** May I upload a sanitized+OCR'd copy of each **83 signed bank receipts** and then delete the original (30-day trash), knowing the replacement may land at a `_01` filename variant? And can you make the sops age identity available (it is not readable by root in my session) so the **15 password-protected statements** can be decrypted and repaired the same way?

---

### Evidence commands used (reproducible)

```bash
# deployed wiring
sudo grep -E 'AUTO_TAG|OPENAI_BASE_URL|TOKEN_LIMIT' /etc/systemd/system/paperless-gpt.service
curl -s http://127.0.0.1:8106/api/config
# provisioner convergence
sudo journalctl -u paperless-dashboard-provision -o cat -n 40
# triage watermark bug (unencoded then encoded)
curl -H "Authorization: Token <t>" 'http://127.0.0.1:2892/api/documents/?added__gt=2026-10-28T18:30:44.755977+01:00'   # 400
curl -H "Authorization: Token <t>" 'http://127.0.0.1:2892/api/documents/?added__gt=2026-10-28T18%3A30%3A44.755977%2B01%3A00' # 200
# end-to-end proof
sudo journalctl -u paperless-gpt -o cat --since "-10min" | grep -i 'suggested\|processed'
```
