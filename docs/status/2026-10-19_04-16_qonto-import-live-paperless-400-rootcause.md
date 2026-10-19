# Status — Qonto arc deploy #2: IMPORT LIVE (132 rows served), mint healed, paperless 400 root-caused to a stderr bug (2026-10-19 04:16 CEST)

**Current date-time:** 2026-10-19 04:16:09 CEST, evo-x2.

**One-line verdict:** the 04:03 deploy landed the core deliverable — **the live dashboard now serves all 132 Qonto statement rows** (verified by HTTP probe: both org profiles, transaction rows, totals panel), the token-mint second-run bug is healed (unit Finished), and the ONLY remaining failure is the Paperless-ngx upload dying on HTTP 400 — root-caused (below) to `ensure_named` printing its create-diagnostic to stdout, which the `$(...)` capture pollutes the ID variables with → invalid form values → 400. One-line fix pending the owner's go.

## Deploy #2 facts (04:03–04:04 activation)

- `bank-sync-qonto-stage`: staged both CSVs into `/mnt/pool/services/bank-sync/qonto-import/` (root copy fix worked).
- `bank-sync-qonto-import`: **imported=104 errors=1 (the known junk tail row) + imported=28 errors=0** — live data.db now holds the full Qonto corpus; idempotent re-runs skip.
- `bank-sync-paperless-token`: **Finished successfully** (the rm-before-write fix healed the second-run EPERM class).
- `bank-sync-qonto-paperless`: FAILED — curl 22 / HTTP 400 on the first `post_document` call. Marker NOT written (re-run safe).
- Activation exit-4 (that one unit); anchor self-repaired to system-930; post-deploy smoke rc=0 overall.
- Also during this window: fixed the foreign `forgejo-family-condition-selftest` coercion bug (one word: `legs` not `{ inherit legs; }`) that was aborting the deploy script's own §1 flake-syntax gate, and gated the nixpkgs-rendered `forgejo-dump`/`forgejo-secrets` units per the new family audit's prescription (unblocked master eval).

## a) FULLY DONE

1. **Live serving of the Qonto statements (the 51%):** 132 rows in prod, dashboard verified rendering (probe evidence above). Rehearsed first on a throwaway DB (104/1 + 28 + idempotent skip), then deployed.
2. **Token-mint heal:** root-caused (bank-sync-owned 0400 env from the ExecStartPost handover blocks every later paperless-user rewrite; unlink needs only dir-write) and fixed; unit green.
3. Stage-copy root oneshot (DAC-private /home/lars lesson) — deployed, working.
4. Foreign eval/check unblocks on record: forgejo family gates (395f99c09), selftest env fix, both with detailed commits.
5. Plan artifact: `docs/planning/2026-10-19_03-18_SUPERB-qonto-serving-completion.md` (Pareto tiers, 12 medium tasks, 27 micro-tasks, mermaid graph) — committed + pushed (8b06c5fdb).

## b) PARTIALLY DONE

1. **Paperless-ngx archival (the 13% to 64%):** unit runs, token works, uploads start — dies at HTTP 400. Root cause found in my script: `ensure_named`'s create-diagnostic `echo` goes to stdout, so first-run creations (correspondent/tag objects) pollute the captured IDs; paperless rejects the malformed correspondent/tags form values. Fix designed: echo diagnostics to stderr (`>&2`) + numeric guard on the returned id; optionally `--fail-with-body` so any future 400 shows its body in the journal. Not yet applied/deployed — awaiting your go (this report is the checkpoint).
2. Docs closeout (runbook numbers, TODO strikes, status finalization) — pending the paperless fix so the report closes complete.

## c) NOT STARTED

1. Qonto attachment receipts (owner credentials — unchanged).
2. pma forward relock (parallel session's upstream fix — unchanged).

## d) TOTALLY FUCKED UP

1. The `ensure_named` stdout pollution is exactly the class I should have caught by REHEARSING the paperless script against the live API before shipping it (I rehearsed the import but not the upload — the one command I couldn't safely dry-run, I didn't fixture). Second rehearsal-lesson violation this arc; the fix list now says: fixture or rehearse EVERY unit script, not just the convenient ones.
2. Burned a full deploy cycle on the foreign selftest coercion bug because I ran the deploy before re-running `nix flake check --no-build` after the tree moved under me (the parallel session landed between my build and my deploy). Lesson: re-run the cheap checks in the same breath as the deploy, on a moving tree.

## e) WHAT WE SHOULD IMPROVE

1. `ensure_named`-style helpers in unit scripts: diagnostics to stderr ALWAYS (command substitution is the default consumer).
2. `curl -f` hides response bodies — use `--fail-with-body` in any API-calling unit script so failures are self-describing in the journal.
3. On a multi-session box: gate-check → build → deploy must be one atomic sequence; anything between lets the tree drift.

## f) NEXT (ordered)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | Apply the stderr+guard fix to `ensure_named` (+ `--fail-with-body`), eval, commit | 🔴 | 10min |
| 2 | Redeploy → verify qonto-paperless green: 2 uploads, count=2, metadata (Qonto / Bank Statement / tags / created), marker written | 🔴 | 30min |
| 3 | Dashboard battery detail: balance amounts, sync-state counters, provider filter UX | 🟠 | 20min |
| 4 | Docs closeout: runbook §Qonto executed-state + numbers, TODO strikes, this report finalized | 🟡 | 30min |
| 5 | Commit + push the arc (authorized) | ⚡ | 10min |
| 6 | Owner: Qonto Business API creds → wire attachment receipts | 🟠 | owner |
| 7 | pma forward relock when upstream lands | ⚪ | 30min |

## g) TOP 3 QUESTIONS

1. Apply fix + redeploy now (items 1–2), or hold?
2. Same force-deploy policy as the last two activations (case-by-case, on-record) — still your preference while the storm rows stay open?
3. The two foreign fixes I landed to unblock the box (forgejo gates + selftest env) — keep as-is, or do you want their owning sessions to re-own/refactor them?
