# AGENT-DOCS-DURABILITY-PLAN — EXECUTION SESSION 1 (Phase 0 complete)

**Date:** 2026-10-01 04:32 CEST
**Plan:** `docs/planning/2026-10-01_03-00_AGENT-DOCS-DURABILITY-PARETO-PLAN.md`
**Scope this session:** Phase 0 (T1 + T2 + T3 — the 4%/64% enforcement band). Stopped per user instruction after Phase 0 + this report; Phases 1–3 untouched.
**Parallel sessions active during the whole window:** dns-blocker max-adoption (M14–M16) + paperless SSO group-mapping work landed interleaved (commits `47b64574`, `70711934`, `a3f3308d` are theirs/mixed).

---

## a) Fully functional and complete (verified)

1. **T1 — pre-commit markdown leg** (landed inside daemon-swept mixed commit `f21be80a`): `.githooks/pre-commit` gained a staged-`.md`-keyed fast guard invoking `scripts/check-doc-links.sh` over the whole living-docs set (~0.6s). The whole docs/agents + docs/services structure can no longer rot silently — any markdown commit re-validates every relative link. Verified THREE ways: (i) planted broken link `docs/services/zz-link-fixture.md` → hook FAIL rc=1 naming the BROKEN target; (ii) valid relative link → leg prints `Living-docs link check passed`; (iii) a real docs-only commit (`99449fda`, the CHANGELOG entry) exercised the leg live and passed. Placement: directly after the moved-markdown guard, before the heavy legs — runs on every commit staging `.md`, no-op otherwise (NUL-delimited staged-path keying).
2. **T2 — anchor validation + selftest in `check-doc-links.sh`** (broken intermediate `e1ae591c` superseded; fixed content at HEAD via `3cc72123`, inside `a3f3308d` lineage — verified `link_re` present at HEAD): GitHub-slug semantics (lowercase, punctuation dropped keeping alnum/_/-, EACH whitespace char → `-` so `ZRAM & Memory Reclaim` → `#zram--memory-reclaim`, duplicate headings get `-1`/`-2`); `file.md#anchor` AND same-file `#anchor` validated against the target's heading set; links and headings inside ``` fences ignored (quoted markdown is not structure — also fixes fence-blindness for path links); `%20` now DECODES (the old encode direction was wrong both ways for spaced paths; zero live impact, no spaced filenames); `--selftest` pins 4 detections (bad file/anchor/same-file/dup-2/fenced-heading-ref) + 5 false-positive guards + a clean-file control. Full-tree run: green in 3.2s, exercising the real anchor corpus (dozens of same-file anchors incl. the ampersand double-hyphen class).
3. **T3 — CHANGELOG entry** (`99449fda`, properly messanged, pathspec-committed): the restructure entry under `[Unreleased] → Added` — sizes (605,658 B/1,327 L → 34,099 B/150 L, −94.4%), 12 domain files + 15 new runbooks + 21 appendices, the 0-of-1,021 zero-loss audit, commit chain, and the stray-merge lesson. All facts re-derived from git at write time (verify-before-writing), not copied from the prior summary. `check-todo-system.sh` green after insert.

**Gate consequence now live:** docs-only commits are fully gated (link + anchor + todo-system + gitleaks) while still riding the docs-only flake-check fast path; non-docs commits run the full flake eval as before.

## b) Partially complete

Nothing in Phase 0 — all three tasks whole. (Phase 1+ not started, so no partials exist.)

## c) Not started (next session's backlog — fully specified in the plan's §2/§3 tables)

- **Phase 1:** T4a pocket-id, T4b oauth2-proxy, T4c signoz, T4d immich runbooks; T5a twenty, T5c taskchampion, T5d dozzle, T5e openseo; T6a crush-daily, T6b atticd; T8 shell lessons; T17 queue-premise spot-check.
- **Phase 2:** T9 module→runbook pointers (~40 files); T10 integration-registry ↔ monitoring.md cross-links. T7a–e appendix folds remain **gated by D3** (per-file on-touch default).
- **Phase 3:** T11 superseded-chain cleanup; T12 AGENTS.md-mention sweep.
- **Gated/watch:** D1′ core slim to ~20KB; D2′/D2″ crush context-automation spike/build; W1 mr-sync post-deploy watch (parallel session's scope).

## d) Total fuckups (all resolved, none user-visible)

1. **Daemon race ×3.** (i) The hook edit was swept mid-verification into mixed `f21be80a` (6 files, 5 foreign) — cannot amend-forward (not exclusive), content verified correct instead. (ii) The daemon committed the SYNTAX-BROKEN intermediate of check-doc-links.sh as `e1ae591c` (the documented broken-intermediate class); the fixed worktree version landed after via `3cc72123`. (iii) My amend attempt over `e1ae591c` raced a daemon commit (`cannot lock ref … expected e1ae591c`) — aborted cleanly; HEAD already carried the fixed content, so no repair needed. Lesson reaffirmed: with 2 active sessions + daemon, stage→verify→commit windows must be minutes, not tens of minutes.
2. **First script draft: bash `[[ =~ ]]` tokenization error** — an unquoted ERE containing `[^]]` cannot parse; fixed via the regex-in-a-variable idiom (`link_re`). Caught by `bash -n` before anything committed.
3. **Draft bugs fixed pre-commit:** cross-file `in_fence` leak (unclosed fence in file A would skip all of file B); a bogus `%)\'` strip line; space-COLLAPSING slugification (GitHub is per-char — the tree's own `#zram--memory-reclaim` anchors prove per-char is required); pipe-SIGPIPE risk in `anchor_exists` → herestring form (the house false-FAIL class).
4. **My own verification fixture was wrong once:** `[ok](AGENTS.md)` planted in `docs/services/` is correctly BROKEN (relative-to-linking-file resolution) — the checker was right, the probe was wrong. Reran with `../../AGENTS.md` → PASS. Accidentally a bonus proof of relative resolution.
5. **~30 min of blocked non-docs commits:** the parallel session's mid-edit dns-blocker/test files made `nix flake check --all-systems` red (assertion `btrfs-scrub@ timerConfig`, then `dns-blocker-render`); per race doctrine I never touched their files and interleaved docs-only work (which rides the fast path) until their tree settled green (~04:25, proven by the amend's green flake leg).

## e) Improvements made beyond the strict plan

- Fixed the checker's pre-existing `%20` encode-direction bug (both directions were broken for spaced paths).
- Made path-link extraction fence-aware as a side effect of the anchor walk (fenced example links no longer false-flag).
- Discovered gap for §f: `docs/README.md` is a LIVING doc with links but is NOT in `LIVING_DOCS` — unvalidated today.

## f) Direct follow-ups (harvest candidates — NOT yet harvested into TODO_LIST/library, deliberately deferred by the user's stop-after-report instruction; the next session MUST harvest or explicitly re-defer)

1. [ready] Add `docs/README.md` to `LIVING_DOCS` in `scripts/check-doc-links.sh` + fix any links it surfaces (5 min).
2. [ready] Wire `scripts/check-doc-links.sh --selftest` into CI (`.github/workflows/nix-check.yml` trap-lint job) so the checker's own contract is machine-pinned beyond pre-commit (10 min).
3. [ready] T8 (plan): absorb the three session shell lessons into `docs/agents/shell-devtools.md` — `grep -qF -e "$line"` for leading-dash lines, never `$1` after `shift` (capture first), regex-in-variable for `[[ =~ ]]`, herestring over pipe for `-q` greps (25 min).
4. [ready] T17 (plan): spot-verify the 6 harvested queue rows' premises (20 min).
5. [watch] The 10-commit unpushed master (`origin/master` at `f21be80a`-era… recheck) needs a push decision — includes the parallel session's work, so owner/coordination call.
6. [watch] W1: after the next deploy, verify `mr-sync-dashboard` active + Gatus green (parallel session's fix).
7. [decision] D1 core size, D2 crush hook, D3 fold-wave timing — still owner-open (defaults standing).
8. [ready] Phase 1 runbooks T4a–T6b (10 files, individually dispatchable, docs-only = fast-path commits).

## g) Questions (max 3)

1. **Push?** master is 10 commits ahead of origin/master, mixing my Phase 0 with the parallel sessions' dns-blocker/paperless work — push now, or leave to the sessions' own closeouts?
2. **D2 (crush hook):** should the context-automation spike (design note only, no build) be dispatched, or does the routing-table+discipline default stand?
3. **D1/D3:** keep the 34KB core and on-touch fold defaults (standing), or order the ~20KB slim + the 5-runbook fold wave as explicit tasks?

---

**Bottom line:** Phase 0 (the enforcement band — the plan's 4%→64% slice) is DONE and verified: link AND anchor integrity is now machine-enforced on every markdown commit, with a selftest pinning the checker's own semantics, and the restructure is recorded in CHANGELOG. 16 of 19 tracked todos remain for Phases 1–3.
