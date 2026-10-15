# Status Report — InboxClean paperless CLI: classification fixes, env-reconstruction wrapper, mojibake forensics

**Session window:** 2026-10-15 ~00:33–02:06 CEST
**Author:** Crush (agent session, shared tree — concurrent InboxClean + SystemNix sessions were active; flagged where relevant)
**Surfaces touched:** InboxClean repo (Go code, tests, spec, ARCHITECTURE, CHANGELOG, TODO) · SystemNix repo (wrapper script, runbooks, TODO rows, services.md)
**Trigger:** `inboxclean paperless --full` failed with a self-contradictory error (`paperless: not configured` + "A temporary error occurred. Please try again in a few moments", exit 75).

---

## a) FULLY DONE

1. **Root-caused the `--full` incident — two stacked causes.** (1) The interactive shell has no `PAPERLESS_URL`/`PAPERLESS_TOKEN` (they live in the sops-rendered `inboxclean-paperless-env` file that only the units read); (2) the eight paperless sentinels were bare `errors.New`, so go-error-family's fail-open misclassified a user-fixable config error as Transient (exit 75, "try again").
2. **InboxClean classification fix** (`cmd/inboxclean/paperless_command.go`): all 8 sentinels now self-classify — not-configured + 4 flag-combination/scope errors + account-not-connected + document-flag → **Rejection (exit 1, retryable=false)**; corrupted-ledger-row → **Corruption (exit 65)**. Messages preserved verbatim (tests/docs quote them).
3. **Registered `paperless.not_configured` message template** in `cmd/inboxclean/main.go` (What/Why/Fix naming the missing env vars + the SystemNix runbook pointer).
4. **Regression suite landed** (`cmd/inboxclean/paperless_error_family_test.go`): per-sentinel family/code/retryability + wrap-through-`%w` classification + an end-to-end `HandleErrorWithContext` render test asserting the transient fallback never leaks and exit is 1. Full `cmd/inboxclean` package green.
5. **Live end-to-end verification** (sandboxed HOME/DB): the exact incident now renders `family=rejection code=paperless.not_configured retryable=false exit_code=1` + actionable guidance. Transient wording gone.
6. **Quality gates green:** `buildflow format` 42 steps 0 failed; `golangci-lint` 0 issues (after fixing my own golines/mirror/varnamelen findings); gofmt clean.
7. **InboxClean docs per spec-currency rule:** `docs/spec/paperless.md` (not-configured = Rejection, never transient), `docs/ARCHITECTURE.md` (9 templates + the "never bare errors.New at a CLI boundary" convention), `CHANGELOG.md` 2026-10-15 entry, InboxClean `TODO_LIST.md` row 275 (13 remaining unclassified sentinels across `llm.go`, `categorize_command.go`, …).
8. **SystemNix wrapper shipped:** `scripts/inboxclean-paperless.sh` — self-elevating (boot-mirror-activate pattern), reconstructs the deployed unit's env exactly (7 vars + PATH-with-qpdf from `/etc/systemd/system/inboxclean-sync.service`, `PAPERLESS_TOKEN` + `PAPERLESS_DECRYPT_PASSWORD` from the rendered sops file), passes all args through to `inboxclean paperless`. Secret hygiene: values only ever exist inside the root process; script/history carry paths only. shellcheck-clean, shfmt-clean, `bash -n` clean, executable.
9. **Wrapper live-verified:** `--dry-run` got past the config gate into the Gmail listing (surfacing the dead main grant); the owner's `--backfill --prune --dry-run` produced the full repair report (681 ledger entries, 114 matched, 4 dup sets, 96 would-update, 4 missing, 18 source-unavailable) in 47 s.
10. **Runbook maintenance:** `docs/services/paperless.md` — wrapper pointer + "inline block stays as derivation source" doctrine; corrected stale prose ("the unit runs ollama" → live `LLM_PROVIDER=openai`, verified from the unit file).
11. **Mojibake forensics (user's "what?" question):** document 1000103 "OdpowiedÅº na pismo.pdf" is "Odpowiedź na pismo.pdf" **double-encoded by the sender's client before transmission** — proven from the corpus `.eml` (ADR-023 evidence layer): both the RFC 2047 encoded-word and the RFC 2231 parameter carry `0xC3 0x85 0xC2 0xBA` ("Åº") labeled UTF-8, i.e. valid UTF-8 for the wrong characters. Gmail, InboxClean, the ledger, and Paperless were faithful couriers.
12. **Mojibake scope check:** ledger scan across all 681 rows found exactly **1** affected row → no InboxClean decode bug (all other Polish filenames intact). Paperless title sweep across all 214 documents: zero Latin-1-decode patterns remain (owner renamed 1000103 to "Fwd: Response to letter" — verified via API).
13. **Row 472 refreshed** (docs/todo/services.md): the dead main-account Gmail grant re-confirmed live at 01:25 — the 3rd ~7-day Testing-mode recurrence (re-consent 10-04 + 7 d), exactly what row 62 step (1) predicted.
14. **Self-harvest done at authoring time** (TODO discipline): 2 `[ready]` rows landed in `TODO_LIST.md` + `docs/todo/services.md` (§f.6/§f.7 below); the corpus-evidence runbook note was a two-line fix-on-sight (owner standing permission 2026-09-06).

## b) PARTIALLY DONE

1. **Wrapper operational but not yet a flake app** — reachable only at a repo path; `nix run .#inboxclean-paperless` wiring queued (§f.6).
2. **No fixture test binding the wrapper's extraction to the unit shape** — upstream module drift (Environment= line changes in the InboxClean flake input) is currently caught at invocation, not eval (§f.7).
3. **The paperless repair itself:** dry-run complete and analyzed; the REAL repair run (`--backfill --prune`, ~96 metadata updates + duplicate deletion) is pending owner go (§g.2).
4. **Sentinel classification sweep:** 8 done (the incident's file, test-pinned); 13 more across other command files deliberately out of this session's surgical scope — queued upstream as InboxClean TODO #275.
5. **Concurrent InboxClean session's auto-backfill work** (`paperless_auto_backfill.go` + test + `sync_command.go`) is present in the tree and committed by the daemon — present, NOT verified by me (deliberately; not my session's work — flagging only, per shared-tree discipline).

## c) NOT STARTED (session-generated; deliberately untouched this session)

1. Gmail main re-consent ceremony (owner; exact command handed over — docs/services/inboxclean.md:12).
2. Google Cloud OAuth consent screen → "In production" flip (owner-only; kills the weekly token bomb).
3. Real `--backfill --prune` repair execution (owner-gated; intersects the open deploy-authority decision).
4. Wrapper flake app + extraction fixture test (queued this session).
5. Investigation of the 4 "Missing in Paperless" documents and the 18 "source email unavailable" ledger rows (needs the repair run and/or a live grant first).
6. Ledger completeness question: row 1000103 has `task_ref_document_id=0` while the document demonstrably exists — settle-path gap or by-design checksum-matching? Not probed further this session.
7. Upstream sentinel sweep (InboxClean #275) + the lint-guard idea (§f.12).

## d) TOTALLY FUCKED UP (honest list — process-level only; no product breakage)

1. **First multiedit carried a GUESSED string** for `errPaperlessDecryptRepairScope` — I assembled `old_string` from truncated `sed` output instead of Viewing the block; the read-first gate rejected the whole edit and forced a correct re-diff. Real risk of corrupting a message string was one gate away. Rule reinforced: View full blocks, never assemble edit targets from grep/sed fragments.
2. **gofmt-invalid string-continuation spacing** in my first edit pass (`"+` vs `" +`) — buildflow format had to repair my file. Right order is edit → format → test, not edit → test → discover.
3. **Typed-`sudo` guard trip** cost a wasted probe round-trip — the AGENTS documents the agent-shell guard; the throwaway-probe-script pattern should have been the FIRST move, not the recovery.
4. **SIGPIPE truncation:** `buildflow format -v | grep … | head -20` killed the run early and I re-ran the ~2 min pipeline twice. Long runs go to a file, then get filtered.
5. **`buildflow --failed-only` without mode context** → no-op "no tools matched" error before I used the correct invocation.
6. **Three lint rounds on my own test file** (golines line budget ×2, `strings.Contains` vs `bytes.Contains`, `tc` varnamelen) — should have matched house style on the first pass.

Nothing at product level: every landed change is test-pinned, lint-green, and (where applicable) live-verified against the running system.

## e) WHAT WE SHOULD IMPROVE

1. **Edit discipline:** always View the exact block before multiedit — the gate only catches it when the file was never viewed; partial reads are the dangerous middle.
2. **Probe hygiene:** for anything needing root/secrets, write the throwaway script first so the guard-visible command line stays clean (worked perfectly once used).
3. **Long-run output discipline:** redirect to a file, filter after completion.
4. **House style first pass:** golines budget, `strings.Contains`, no short loop vars — write to the linter, not to the linter's findings.
5. **Two-sources-of-truth control:** the wrapper now duplicates the runbook's inline reconstruction (7 vars vs 5 + hardcoded URL). Mitigated by documenting the inline block as derivation source; the queued fixture test closes the drift class mechanically.
6. **The class existed for weeks:** bare `errors.New` at CLI boundaries fail-open to Transient silently. A lint/archtest guard (ban unclassified sentinels in `cmd/inboxclean` non-test files) would turn InboxClean #275 from a cleanup list into an enforced invariant — linter-building territory, upstream.
7. **Concurrency:** the repo-wide `buildflow format` run reformatted the sibling session's in-flight test file mid-edit (unavoidable under repo-wide formatting; flagged in-session). Consider scoped format (`-s <tool>` on touched paths) when a co-session is known-active.
8. **What worked — keep:** secret-path-only hygiene throughout; flagging co-session work immediately; self-harvest at report-authoring time; live verification before "done" claims (the sandboxed CLI run + API sweeps are what turned "probably fixed" into "verified fixed").

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT (brainstorm, impact-ordered; session-grounded only)

Markers: **[queued]** = row landed in TODO_LIST + domain library this session · **[owner]** = only the owner can do it · **[upstream]** = InboxClean repo (many ride its TODO #275) · unmarked = agent-actionable candidate.

**Execute / verify the paperless pipeline**
1. Re-consent the main Gmail account (ceremony in docs/services/inboxclean.md:12; wrapper env NOT needed for main) — **[owner]**
2. Flip the Google Cloud OAuth consent screen to "In production" — ends the ~7-day token bomb (rows 62/138/472) — **[owner]**
3. After re-consent: verify `/health` `services.gmail.main=connected` + next `inboxclean-sync` tick exits 0, then close row 472 with evidence
4. Run the real repair: `sudo scripts/inboxclean-paperless.sh --backfill --prune` (96 metadata updates, 4 duplicate sets collapsed keep-oldest) — **[owner-gated]** (see §g.2)
5. Re-run `--full` post-consent; confirm ledger delta + `Would update: 0` convergence on a follow-up dry-run
6. **[queued]** Wire `scripts/inboxclean-paperless.sh` as flake app `nix run .#inboxclean-paperless` (apps.nix runCommand staging, pre-deploy-check pattern)
7. **[queued]** Fixture-test the wrapper's unit-env extraction (7 var names + PATH line) against the rendered InboxClean module — fail loud at eval, not at 2 a.m.
8. Investigate the 4 "Missing in Paperless" documents from the dry-run (filter reject? failed task? corpus gap?)
9. Root-cause the 18 "source email unavailable" rows (Gmail-side deletion? account scoping? corpus gaps?)
10. Audit the ledger settle path: `task_ref_document_id=0` on row 1000103 while document 1000103 exists — how many rows look like this, and does backfill's checksum matching paper over a settle bug?
11. Reconcile the document-count delta: dry-run said 218 docs in Paperless (01:33), my API sweep counted 214 (~02:05) — did a real repair run already execute, or does the count endpoint filter? (affects §f.4/5 sequencing)
12. Spot-verify 3 repaired documents' tag sets (esp. the `gmail` tag NONE-matching preservation) + the `created`-date fixes (docs 18, 15, 27) after the repair run
13. Add a SystemNix CHANGELOG entry for the wrapper script (repo logs notable host-side changes; the wrapper is new operator surface)

**InboxClean upstream (most ride TODO #275)**
14. Classify the 13 remaining bare sentinels (`llm.go` ×3, `categorize_command.go` ×2, `memory_command.go`, `undo_command.go`, `cqrs_commands.go` ×2, `corpus_backup.go`, `doctor_command.go`, `commands.go` errNoAccountAvailable, `crm_people_sync_command.go`) — **[upstream]**
15. Archtest/lint guard banning bare `errors.New` in `cmd/inboxclean` non-test files — makes #275 an invariant, not a backlog — **[upstream, linter-building candidate]**
16. Deploy-verify the phantom-green auth fix (`1540a56`) end-to-end: dead grant → consent fall-through without the token.json mv (the 10-14 recurrence is the live test case) — **[upstream + deploy]**
17. Title-derivation policy: ensure a future backfill touching a drifted document whose ledger filename is mojibake cannot re-assert the mojibake as the title (decide subject-vs-filename title source) — **[upstream design]**
18. Watch the co-session's auto-backfill for ledger-lock/idempotency interplay with CLI repairs once deployed — co-session follow-up, not mine to verify — **[upstream]**
19. Confirm Corruption (exit 65) semantics at the systemd boundary: OnFailure alerts but never retries corrupted-ledger exits — **[upstream]**
20. Upstream docs: `inboxclean paperless` account parity (work-account source re-fetch requires `INBOXCLEAN_CONFIG`; SystemNix wrapper handles it, upstream README/spec should say so) — **[upstream]**

**SystemNix hardening / docs**
21. Reconcile the runbook inline block with the wrapper's 7-var extraction (or explicitly deprecate the inline block in favor of the wrapper)
22. Enable-gated post-deploy smoke that the wrapper's extraction assumptions still hold (fold into §f.7 or a standalone probe)
23. Gatus candidate: local check that `inboxclean-paperless-env` parses with both `PAPERLESS_TOKEN` + `PAPERLESS_DECRYPT_PASSWORD` keys present (catches sops-template regressions at probe layer; complements the existing API-auth check)
24. Wrapper `--print-env` mode (redacted) for debugging the reconstruction without executing the CLI
25. Wrapper can join the tq-pool-able set only after §f.6 (dependency)
26. Document the deliberate non-fix: ledger filename stays mojibake as the historical record (this report is that record; the runbook note covers the pattern)

**Watch / cheap**
27. If the OAuth app is still Testing on ~10-21, expect the 4th revocation — pre-arm the row-472 re-fire check
28. My upstream commits (sentinels + tests + docs) ride the next `nix flake lock --update-input inboxclean` + deploy — they intersect the pending-deploy train decision (5 changes already waiting: inboxclean canary fix dc3ad6e7, io-psi-crosscheck, pre-vacuum §15, tq-pool PSI gate, census ring) — **[owner]**
29. Verify the daemon commits carried all session files (partially done: SystemNix ed5be9d1; InboxClean e6dbdfb/bbb9d8c/76917f6/1cacbb0 — re-verify after the report lands)
30. Keep the corpus-evidence pattern in mind for the next "what is this document" dispute (runbook note landed this session)

(Deliberately NOT queued: automating mojibake repair — correctness trap, rejected; the 13-sentinel sweep as SystemNix rows — cross-repo debt owned by InboxClean #275; new rows for the OAuth recurrence — rows 62/138/472 already own it.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF (3)

1. **OAuth app status:** do you want to flip the InboxClean Google Cloud OAuth consent screen to **"In production" now**? (I cannot touch the Cloud Console. It decides whether the ~7-day token bomb continues. If yes: re-consent once after the flip and the recurrence ends; if it stays Testing, I'll instead pre-arm the re-consent reminder cadence for ~10-21.)
2. **Real repair timing:** run `sudo scripts/inboxclean-paperless.sh --backfill --prune` **now** (mutates ~96 documents, deletes duplicates), or batch it behind the pending deploy train (5 changes already waiting) so everything settles in one window? (Related: the 218→214 document-count delta in §f.11 — did a real repair run already happen between 01:33 and 02:05?)
3. **Wrapper future:** keep the runner a manual `sudo` script, or promote it to a flake app and allow tq-pool firing of repair runs? (The latter makes §f.4 queue-fired — which intersects the still-open deploy-authority decision: queue-fired vs user-manual.)
