# Window Closeout — 5-Task Round: Forgejo Issue Filing, Mail-Relay Go-Live, Token Rotation, Paperless-Embeddings Verify, llama-rag Leak

**Date:** 2026-09-18 03:45 CEST · **Closer:** docs-health HARVEST/ANNOTATE pass over the 2026-09-18 00:00–03:30 agent window · **Repo:** LarsArtmann/SystemNix @ `9e3becb7` (clean at open)

**Window tasks (all with closeout reports read first):**

| Task                    | Item                                                       | Verdict                                                                   |
| ----------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------- |
| `000001a0b1666334580c`… | Forgejo upstream: file the 3 verified mirror-outage issues | BLOCKED (no Codeberg token)                                               |
| `000001a0b198bd1f0309…` | Mail Relay go-live (user steps)                            | PARTIAL — 3 of 5 steps proven; Resend now ACCEPTS (250)                   |
| `000001a0b1afa0754d96…` | Rotate InboxClean→Paperless API token                      | BLOCKED (sudo-gated; sandbox)                                             |
| `000001a0b1bd5c2d1492…` | Verify Paperless AI uses llama-rag embeddings E2E          | BLOCKED (llama-rag was disabled; DB read sudo-gated)                      |
| `000001a0b1d43f78d432…` | llama-rag restart leak + 0.4.0 spin regression             | DONE (landed by a parallel session; this run cross-verified + closed out) |

---

## a) FULLY DONE

1. **llama-rag leak + spin regression — fixed in-tree, re-enabled, cross-verified.** The engineering (rev-pinned `nixpkgs-llama-rag` input at `0968519e14f7…` holding the byte-identical 0.3.0 store path `sj4rpa8y…` of the proven 2026-09-05 build; `llama-rag.enable = true` restored; `TimeoutStopSec=2min` on both servers; `llama-rag-leak-metrics` fail-closed collector + Gatus "llama.cpp Leaked Instances") was landed by a parallel session earlier on 2026-09-18 and **independently cross-verified** by task `…d43f78` (`4a04b5f9`): flake check green, evo-x2 eval proves enable + stop-timeout + collector unit, functional re-verification live on a scratch port (4s bge-m3 cold load, `/health` 200, 1024-dim embedding). FEATURES.md and AGENTS.md carry the fix. TODO_LIST line 37 is `[x]`. **Activation still awaits the next deploy** (see b).
2. **Paperless-ngx reranker question closed as MOOT (source-verified).** Task `…1bd5c2d` proved against the deployed 3.1.3 store path that paperless-ngx has ZERO reranker code (no `PAPERLESS_AI_LLM_RERANKER_*` env, no `rerank` hits in `src/`) — the `:8849` reranker instance has no in-app consumer today. Embedding env wiring verified correct in the deployed unit; DB-over-env precedence confirmed from `paperless/config.py:253-259`. Findings durably encoded as a comment in `paperless.nix` (`c029cb07`) so no future session re-investigates.
3. **Mail relay: the 550 era is OVER — live E2E proof.** Task `…198bd1f` injected a real SMTP message through 127.0.0.1:25; postfix journal shows `status=sent (250 …), relay=smtp.resend.com:587, dsn=2.0.0`, queue drained, collector reports `credential_placeholder 0 / queue 0 / scrape_errors 0`. DNS evidence gathered: SPF at the registrar is STILL the lockdown `v=spf1 -all` (no `include:amazonses.com`), DKIM `resend._domainkey` present, no MX — the accepted 250 is Resend's account-owner-address allowance, NOT domain verification. Runbook (`docs/services/mail-relay.md`) and AGENTS.md updated with the 2026-09-18 status block incl. the REPLACE-don't-append SPF instruction (`23000f52`).
4. **Forgejo: all three mirror-outage bugs verified TWICE against current upstream, fully drafted, zero duplicates.** Task `…6663345` (two runs: `e2ef0c4e` drafts + `8f0183b1` independent re-verification) confirmed verbatim against the live codeberg `forgejo` branch: `TouchMirror` advancing `updated_unix` on failed syncs, the mirror-queue `ErrAlreadyInQueue` dedup-skip logged at `log.Trace` only, and the credential-helper `os.CreateTemp` failure aborting syncs without `CreateRepositoryNotice`. Drafts live in `docs/services/forgejo-upstream-issues.md` with `github-voice` checks clean. Daemon-era `💘` footer artifacts stripped from the doc body.
5. **Token-rotation feasibility diagnosis complete.** Task `…1afa075` verified every blocker first-hand (sandbox forbids `sudo`/`systemctl`; age key root-only; sops decrypt fails as user) and appended the correct safe-path knowledge (user-level `SOPS_AGE_KEY` one-liner FROM repo root) to the TODO row (`d9b77544`).
6. **Hygiene across the window:** every closeout ran pre-commit gates (gitleaks + flake check green), every commit carries the exact `Task-Queue-ID` footer, nothing pushed, tree clean. Four daemon-race amends were handled per the verify-`git show --stat` doctrine with zero foreign-file absorption.

## b) PARTIALLY DONE

1. **llama-rag activation:** the fix is one deploy away — units go ACTIVE at the next `nix run .#deploy`; until then :8848/:8849 stay dark and post-deploy smoke carries the known llama reds. The stc re-arm trap is now harmless (re-armed units serve instead of spinning). The `llama-rag-leak-metrics` collector has NEVER run in production (and must run as root — an agent-run as `lars` miscounts foreign-user servers as leaks).
2. **Mail-relay go-live:** 3 of 5 actionable steps proven. Remaining: (a) USER replaces the SPF record at the registrar + waits for Resend "Verified"; (b) post-verification test round (paperless share-link to a NON-owner inbox, forgejo notification, Pocket ID "Send test email"); (c) Immich SMTP in its admin UI. Effort to finish after the user's DNS step: S.
3. **Forgejo filing:** everything done except the actual `POST /api/v1/repos/forgejo/forgejo/issues` × 3 — hard-blocked on a Codeberg account/issue-write token that does not exist on this machine. Draft titles still lack Forgejo's `problem:`/`bug:` prefix convention (flagged for filing time).
4. **Paperless embeddings E2E:** blocked twice over — llama-rag was config-disabled at task time (now fixed in-tree, but still undeployed) and the `paperless_appconfig` UI-override check needs sudo. Resumes with zero re-diagnosis once llama-rag is live.
5. **Hermes Discord smoke (adjacent task `…9a1df77e`, same window, already committed `7dba37d0`):** `-v` verbosity fix + boot-scoped journal smoke assertion landed but NOT deployed; the check deliberately fails red until the deploy carries both.

## c) NOT STARTED

1. The filing, rotation, and go-live external steps above (all user/token-gated).
2. TODO 461 (forgejo `mirror_updated` freshness sensing — the local detection half of the dead-queue class) and 459 (llama-rag functional Gatus probes + GPU-util metric) — deliberately untouched.
3. `nixpkgs-llama-rag` pin-drop monitoring (upstream llama.cpp 0.4.0+ fix probe) — no schedule exists; the escape condition lives only in prose.
4. Paperless DRF-token lifecycle alerting (age metric, `pocket-id-secret-rotation` pattern) — proposed by the rotation task, not built.
5. Archival sweep of older `docs/status/2026-*` reports — no window report is fully closed (all carry open follow-ups), so nothing was moved to `docs/status/archived/` this pass; the 00-28/00-42 Forgejo pair is two point-in-time runs of the same task and stays as history.

## d) TOTALLY FUCKED UP

1. **Four-plus queue tasks dead-lettered on CV integration-test verify failures during this window (journal seq 4203–4249):** tasks `…b1ab0c8f22`, `…b1cfab9c99`, `…b1e1fb8907`, `…b1f8e16e98`, `…b1f44adf7c` each exhausted attempts on `GOEXPERIMENT=jsonv2 go test ./...` failing in `github.com/LarsArtmann/CV/tests/integration` (13.8s FAIL, log at `~/.local/state/tq/logs/<id>.verify-failure.log`), and `…b20b2decdd` was still cycling at window close. This is CV-repo work burning repeated dispatches on a deterministic red verify — a dead-letter loop, not flake. Needs triage upstream or a queue-side parked-state.
2. **The queue dispatched a knowingly-sudo-gated task to a sudo-less sandbox** (token rotation; its own title said "all steps sudo, user-run") — a full session spent producing a BLOCKED annotation. Same class: the paperless-embeddings DB check. Two of five window slots consumed by capability-mismatched dispatches.
3. **Same-day re-dispatch of an already-blocked item** (Forgejo filing: drafts + BLOCKED annotation existed from the 00:28 run when the 00:42 run was dispatched) — no dedup/skip gate for `BLOCKED:`-prefixed items.
4. **Four daemon-race commits this window** (heuristic commits sweeping task files before explicit commits) — all four were safely amended after `git show --stat` verification, but the friction recurred in every single task; each cost a pre-commit round.
5. No regressions, no broken gates, no repo damage: `nix flake check --no-build` green at every task close.

## e) WHAT WE SHOULD IMPROVE

1. **Privilege marker convention on queue items** (`[SUDO]`/`[USER-RUN]`) + a dispatch rule that sandboxed agents skip or reroute them — mechanically prevents the d2 class and halves this window's waste.
2. **`BLOCKED:`-skip convention for the queue walker** — an annotated item should not be re-dispatched the same day (d3).
3. **Verify-command health gating:** a task whose verify command has failed N consecutive times on the same error should park (dead-letter with reason) instead of re-claiming every few minutes (d1).
4. **Consolidated post-deploy verify checklist** in TODO_LIST — llama-rag re-enable, hermes `-v`, crush-hot-db first migration, scrub-mechanism fix, cv sops seeding all wait on the same sudo-gated deploy; make the next deploy's verification mechanical.
5. **Pin upstream verification revs in issue drafts** (branch-floating citations age; the Forgejo drafts cite "current branch 2026-09-18" without a SHA).
6. **Rotation runbook as a skill** — the mint→sops→deploy→death-detector→old-token-kill sequence keeps being re-derived; a `rotate-token` skill collapses it.
7. **FEATURES/AGENTS "Updated:" header stamps drift from body content** (FEATURES said 2026-09-17 while the body carried the 09-18 llama fix) — stamp the header in the same edit that touches a row.

## f) NEXT THINGS (harvest; the surviving ones are appended to TODO_LIST, dedup-checked against 431 open items)

Already tracked (do NOT re-add): the three blocked items themselves (lines 33/34/35/36 with BLOCKED annotations), llama-rag line 37 `[x]`, line 434/452/459 rows, the PERSISTENT NAG (line 10) which already absorbs the Resend/Context7 rotation state.

New this pass (see TODO_LIST for the appended text): mail-relay non-owner delivery probe; mail-relay `status=bounced` journal counter; paperless DRF-token age metric; forgejo filing one-liners + rev pin; re-scope-or-close TODO 434; llama-rag post-deploy verification chain; queue dead-letter triage for the CV verify loop; privilege-marker + BLOCKED-skip queue conventions.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Should sudo-gated queue items carry a dispatch-time privilege marker so sandboxed agents skip them, and should all secret rotation stay interactive forever, or do you want a minimal sanctioned privilege surface (allowlisted `paperless-manage` wrapper and/or an agent-scoped age recipient)?** Two of five window slots died on this single decision.
2. **Is the Resend key in `pocket-id.yaml` the same key as `mail-relay.yaml` (sudo-only byte comparison), and do you want a non-owner-address delivery probe added to post-deploy-check once `larsartmann.cloud` is verified?** Both decide whether one rotation covers all mail consumers and whether the monitoring sees the real failure mode.
3. **Deploy window for the pending batch (llama-rag re-enable + hermes `-v` + crush-hot-db first migration + scrub-mechanism fix): ASAP (RAG is user-visible dark) or batched behind a quieter IO window given the QLC PSI history?**

## h) BAND DRIFT (ADR-0015)

**None recorded.** `tq facts` (13,883 entries) contains zero `task.reprioritized` facts in the window (or at all in the scanned tail). Priority movement this window happened only via enqueue order; no marker/ai/unblock/importance re-prioritizations to account for.

---

_Point-in-time snapshot (2026-09-18 03:45 CEST). Closeout reports for each task are the authoritative per-task records; this file is the window-level harvest. Nothing pushed._
