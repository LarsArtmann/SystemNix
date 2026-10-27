# Status: decision-model bench BUILT + first LIVE Jev run (receipts/invoices/scans) — Clef arm still key-blocked

**Session:** 2026-10-27 19:5x–20:5x · **HEAD at start:** cac27ad (bench build session continued) · **Scope:** this session = Jev×paperless exploration continuation: bench design + build, corpus staging from live paperless, first live Jev run after owner pasted the TypeSafe key. Nothing deployed; no config/modules touched; one new script + one new sops file + doc/queue rows.

---

## a) FULLY DONE

1. **API surfaces source-verified** (verify-external-claims discipline applied properly this time — every claim traced to a primary doc fetched in-session): TypeSafe `POST api.typesafe.ai/v1/systemone` from their published OpenAPI (Choice/Noul/Score/Box schemas, `TypeSafe-Danger-Zone-Images: true` header requirement, Bearer auth, `jev-latest` alias, output tokens free); Cloudflare Clef from developers.cloudflare.com model page (`@cf/cloudflare/clef`, 27B multimodal, $0.24/M input, 32×32-patch image tokenization ≤1024 tokens/image); the earlier OpenRouter multimodal-decisions page cross-confirmed the shared question schema.
2. **`scripts/paperless-decision-bench.sh` BUILT and LIVE-VERIFIED** — 5 modes (`--probe/--corpus/--bench/--score/--setup-secrets`), shellcheck-clean (warning-level), self-elevating sudo (typed `sudo` is guard-blocked; everything root-touching lives inside the script), runtime-minted DRF token (dashboard-provision pattern, zero sops for paperless).
3. **Corpus staged from the live archive** — 28 page-1 images (9 receipts = the Bill-doctype paragony; 10 invoices = gmail Hetzner/GitHub/Google/faktura-VAT; 9 general = drive-import untyped) + 8 encrypted statements (text-arm only, never imaged — the egress line held). Ground truth = owner-curated paperless metadata.
4. **First LIVE Jev run complete — all 66 calls answered** (28 image + 38 text incl. the 8 empty-content encrypted docs):
   - **Receipts 9/9 image-arm, 10/10 text-arm; invoices 10/10 both arms.**
   - Headline (with the corrected truth mapping, see d): **image arm 23/28 (82%)**, text arm 26/38 (68%) — every remaining miss sits in the label-noisy `general` class and most are semantically defensible model answers (Starbucks→receipt, Registerauskunft→letter_or_other, Google Payment→invoice).
   - Latency p50: **368ms text / 446ms image**. Tokens: 33,865 text + 114,075 image (~148k total; Jev output tokens free → cost ≈ sub-cent scale, exact $ unknown until pricing checked).
   - Encrypted statements: `is_accounting` noul 0.09–0.1 — correctly excluded from accounting even with empty content.
5. **sops `decision-bench.yaml`** created via the repo creation rule with PLACEHOLDERs; owner pasted the real `typesafe_api_key` mid-session (Cloudflare pair still PLACEHOLDER).
6. Bookkeeping landed: runbook drift-warning (paperless.md §Accounting), 3 queue rows + 3 library rows, TODO gate clean.

## b) PARTIALLY DONE

1. **Clef arm NOT RUN** — blocked on the 2 Cloudflare keys (account id + Workers AI Read+Run token) still PLACEHOLDER. Everything else for that arm is built and now battle-tested by the Jev run (same payload path). Effort to finish: owner paste + one command.
2. **Calibration verdict is provisional**: Jev's confidence is near-saturated on this corpus (mean conf ≈1.0 on both correct AND wrong rows; the ≥0.9 gate excludes exactly 1 doc). But the "wrong" rows are dominated by MY label noise, not demonstrable model errors — the gate-simulation numbers (18.5%/34.3% err-inside-gate) measure label noise, not model risk. A ~10-min owner label audit of the 9 general docs would separate the two.
3. **Extraction task not attempted by design** — decision models return choices/probabilities, not free-form values (the Brutto/VAT pilot values can't come from Choice/Noul); that stays with paperless-gpt/the removed extraction pipeline.

## c) NOT STARTED

- Clef vs Jev comparison (needs Cloudflare keys).
- Label audit of the 9-doc `general` class (owner eyes; would firm up every accuracy number).
- Jev pricing check + cost-per-1k-docs figure (tokens recorded; $ not yet computed).
- Any production wiring (gate design row in services.md owns that; nothing here deploys).

## d) TOTALLY FUCKED UP (all caught and fixed live — kept honest)

1. **Three successive payload bugs in the image arm, each found by the run itself:** (i) jq `--rawfile` on a BINARY jpeg silently corrupts bytes (UTF-8 sanitization) → all 28 calls failed; (ii) after base64ing outside jq, the string as `--arg` hit Linux `MAX_ARG_STRLEN` (128KB/arg) → 15 larger images failed (`Argument list too long`); (iii) `curl --data-binary "$req"` hit the same argv limit. Fixes: base64 to temp text file + `--rawfile` (ASCII-safe), curl `--data-binary @-` via stdin. Lesson encoded: **binary payloads never cross argv — stdin or temp files, always.**
2. **Scorer truth-mapping bug:** my corpus class `general` maps to model option `letter_or_other`, but the scorer compared raw labels → 5–6 correct answers counted wrong, poisoning the first gate-simulation output (0%→32%→64%→**82%** across the three fix iterations). Reported numbers above are the post-fix ones.
3. **load_secrets loaded ALL providers regardless of the requested arm** — the owner's "(exit code 1)" was exactly this: a Jev-only run died on the Cloudflare PLACEHOLDER check. Fixed to per-provider requirement.
4. Process note: my own typed-line debugging hit the documented direnv jq bug (`--rawfile` parsed as filter code) — AGENTS.md's `env -u DIRENV_DIFF` workaround worked; the script's own env is unaffected.

## e) WHAT WE SHOULD IMPROVE

1. **Bench-script binary-payload rule** (from d.1) belongs in AGENTS.md shell-devtools notes: argv is capped at 128KB per argument; jq/curl/base64 must stream via files/stdin for image-scale payloads.
2. **Corpus label quality is the real benchmark risk** — my `general` rule (untyped + `new` tag) swept semantically-receipt/invoice docs into `general`. Next corpus build should exclude title patterns that look receipt/invoice-like from `general` (or let the owner pre-audit labels in the TSV before any run).
3. **Confidence-gated routing needs a margin check, not just confidence** — with saturated confidence, the margin between top-2 probabilities (available in every answer's `probabilities`) is the more informative gate signal; add it to `--score` before this bench informs the §f.2 gate design.
4. Report numbers must state which scorer version produced them (the 0%→82% drift shows unversioned numbers in a terminal scrollback are untrustworthy).

## f) Next tasks (session-derived; 12 real items — not padded to 50)

| # | Task | Impact | Effort | Cat. |
|---|------|--------|--------|------|
| 1 | Owner: paste Cloudflare `account_id` + Workers AI Read+Run token into `decision-bench.yaml`, then `--bench clef` | High | S | Decision |
| 2 | Owner: label-audit the 9 `general` docs in `corpus.tsv` (which are truly letter/other vs mislabeled receipts/invoices) | High | S | Decision |
| 3 | Add top-2 probability margin to `--score` + re-run; compare margin vs confidence as the gate signal | High | S | Quality |
| 4 | Check Jev pricing page; compute $/1k-docs for both arms; record in the results table | Low | S | Research |
| 5 | After #1: the Clef-vs-Jev table (accuracy, p50, $/doc) → feeds the services.md gate-design row | High | S | Feature |
| 6 | Encode the 128KB-argv rule (d.1) into AGENTS.md shell-devtools section | Medium | S | Docs |
| 7 | Reconcile accounting-extraction runbook drift (row already queued — root-cause vs SUPERB restore, re-provision or retire) | Medium | M | Debt |
| 8 | If owner blesses a direction: write the §f.2 confidence-gate design doc with THESE numbers as the evidence base | High | M | Feature |
| 9 | Fold a Jev/Clef triage question into the paperless consume path as a dry-run workflow (no writes; log-only) if #5 supports it | Medium | M | Feature |
| 10 | Re-run bench after the drive-import backlog settles (corpus is 80%-`new`-tagged right now; classes will stabilize) | Low | M | Watch |
| 11 | Consider `--n 20` + seed for a stabler corpus before quoting numbers anywhere durable | Low | S | Quality |
| 12 | Prune the `.b64-*` temp files pattern to a mktemp name (cleanup-on-exit trap) — minor hygiene in the script | Low | S | Cleanup |

**Harvest Record:** f.1 rides the existing `[blocked:user]` run row (updated by this report's existence); f.2 is new owner-decision — NOT harvested into the queue yet (asked below, lands with the answer); f.3/f.4/f.12 → folded into the bench-continuation row (services.md, updated this session); f.6/f.7 already queued (pipeline/docs surfaces); f.8/f.9 gated on #1/#5; f.10/f.11 watch/quality, recorded here deliberately (would duplicate the run row).

## g) Questions I cannot answer myself

1. **Cloudflare keys:** can you paste `cloudflare_account_id` + a Workers AI (Read+Run) API token into `platforms/nixos/secrets/decision-bench.yaml` (same sops editor command as before) so the Clef arm can run? Without it the comparison half of the bench stays dark.
2. **Label audit (2 minutes):** of the 9 `general` docs, are Starbucks / Super-Pharm / Google Payment ×2 / Artmann-Holding-payment really "letter_or_other" ground truth for you — or receipts/invoices (i.e., the model was right and my labels were wrong)? This single answer moves every accuracy number.
3. **Direction:** given receipts+invoices scored 20/20 with sub-500ms latency — do you want the dry-run consume-path triage (f.9) prioritized, or is the benchmark's job done once Clef runs?

---

*Session artifacts: scripts/paperless-decision-bench.sh (live-verified), platforms/nixos/secrets/decision-bench.yaml (1 of 3 keys real), ~/.cache/paperless-decision-bench/{corpus.tsv, images/ (28), results-jev-{image,text}.jsonl}. Parallel-session note: flake/expected-locks.nix was modified by another session mid-bench-build (flagged at the time, daemon-committed since — not mine). No deploys, no manual commits (daemon owns the tree).*
