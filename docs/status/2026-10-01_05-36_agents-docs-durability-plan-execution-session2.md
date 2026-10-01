# AGENT-DOCS-DURABILITY-PLAN — EXECUTION SESSION 2 (Batch A landed; interrupted mid-Batch-B)

**Date:** 2026-10-01 05:36 CEST
**Plan:** `docs/planning/2026-10-01_03-00_AGENT-DOCS-DURABILITY-PARETO-PLAN.md`
**Scope this session:** resume after the session-1 stop → §f quick wins (Batch A), then the Phase 1–3 waves. Interrupted by user instruction to report and wait after Batch A landed.
**Parallel sessions live the whole window:** dns-blocker max-adoption M17–M18 (their session-6 report + queue edits) + the tq re-dispatch pool (buildcache re-fire verification, `bd253f78` lineage).

---

## a) Fully functional and complete (verified)

1. **Session-state re-assessment.** Session 1's open push question is MOOT: origin/master caught up on its own (`git rev-list --count origin/master..master` = 0 at resume). The dirty `docs/todo/services.md` at resume was identified as the dns-blocker session's in-flight M18 queue edit — untouched, per race doctrine. Current index additionally holds THEIR staged-uncommitted report `docs/status/2026-10-01_05-17_task-000001a0f4b8fac17b8e3519076b00000000.md` — also theirs, untouched.
2. **Research pass (READ/UNDERSTAND/REFLECT).** Mapped: the plan's full task set + gates; the two runbook shapes (new-runbook model = `docs/services/indexer-web.md` — Service header / what-it-serves / Ops / Related; appendix model = `emeet-pixyd.md`); the routing claims the runbooks must make true (AGENTS.md:25 "a few older services still lack runbooks", `docs/agents/README.md:11 "each service has a runbook"`); the restructure report's §e lessons + §f 15-item harvest; and the harvested queue rows for T17 (TODO_LIST:459 wire-gate, :462 runbook backfill, :229 editorial fold; `docs/todo/pipeline.md:220-222`; `docs/todo/services.md:167`). 12-item session todo list established.
3. **§f quick-win 1 — `docs/README.md` into `LIVING_DOCS`** (commit `c630b064`): the living-docs set now includes the docs index itself. Checker green; no broken links surfaced (the file currently carries no markdown links — membership future-proofs it).
4. **§f quick-win 2 — CI selftest + scan wiring** (same commit): new step "Living-docs link check (selftest + scan)" in `.github/workflows/nix-check.yml` (after the GOTOOLCHAIN guard selftest): `--selftest` pins the checker's own contract (GitHub slug semantics, fence immunity, dedup, SIGPIPE safety); the full scan backstops daemon-swept commits, which bypass the pre-commit markdown leg (documented bypass class, 2026-09-28). Verified: `bash -n`, python yaml parse, shellcheck (via hook), checker green (3.2s), selftest green, YAML structure consistent. The step rides the cheap lint job — no nix eval dependency, cannot be masked by eval failures.

## b) Partially complete

1. **Batch A commit mechanics (landed, noisy exit).** All pre-commit legs passed, then the command chain exited 128: `fatal: repository has been updated, but unable to write new index file`. Post-hoc verification: the commit LANDED (`c630b064`), the daemon had committed `cabe8a7a` mid-hook and the post-commit index refresh collided. Tree clean for both files; content verified at HEAD (1× `docs/README.md` in LIVING_DOCS, 1× the CI step). Disk NOT full (54G free on `/`; 93% used — noted, not urgent).
2. **T17 (queue premise spot-check): located, not verified.** The 6 restructure-harvested rows are mapped to their queue+library surfaces; the grep-verification pass itself did not start.

## c) Not started (the remaining plan backlog)

- **T8** shell lessons → `docs/agents/shell-devtools.md`.
- **T17 proper** + closing the three now-DONE harvested rows (`pipeline.md:220` wire-gate, `:221` anchor validation, `:222` CHANGELOG) in BOTH queue and library surfaces.
- **Runbook waves (10 files):** T4a pocket-id, T4b oauth2-proxy, T4c signoz (main; coverage/GCP sub-docs exist), T4d immich; T5a twenty, T5c taskchampion, T5d dozzle, T5e openseo (GSC exemption pointer); T6a crush-daily, T6b atticd (storage-dir + cache notes).
- **Post-backfill claim updates:** AGENTS.md:25 + `docs/agents/README.md:11`; close TODO_LIST:462 + `docs/todo/services.md:167`.
- **T9** module→runbook pointer comments (~40 modules, mapping first); **T10** cross-links integration-registry step 9 ↔ monitoring.md; **T11** superseded-chain cleanup (7 docs/agents files, verbatim-first with deletion records); **T12** repo-wide AGENTS.md mention sweep; closeout harvest.

## d) Total fuckups (all caught in-session; none user-visible)

1. **The exit-128 phantom-failure.** I initially read the Batch A command as FAILED and was one step from recovery actions; verification showed the commit had succeeded and only the index refresh raced. The error text's suggested recovery (`git restore --staged :/`) would have been pointless-to-confusing AFTER a landed commit. Rule: on git exit ≥128 with green hooks, VERIFY `git log`/`git status` BEFORE any recovery — never act on the error text blind.
2. **Convergent duplicate execution with the tq pool.** Both this session and the parallel re-dispatch pool executed harvested row `pipeline.md:220` (wire checker into a gate) inside the same ~15-min window. Mine landed first (`c630b064`); theirs landed as `3819027a`, whose MESSAGE describes my exact changes (near-verbatim rationale, same step name) but whose DIFF contains only their own payload (TODO_LIST row + dnsblockd session-6 report + pipeline.md edits) — git silently dropped their empty-diff files. Net effect: history now carries a commit CLAIMING work another commit carried (attribution noise); CONTENT converged correctly (HEAD has exactly one copy of each change, grep-verified ×2). Root cause: re-dispatched queue rows carry no in-flight claim, so the pool and the plan session double-fired — exactly the class the tq session is itself harvesting ("re-dispatch protocol findings").

## e) Improvements made beyond the strict plan

- CI leg placement: the doc-links step needs no nix evaluation, so it runs even when the flake-eval legs are red — a backstop that cannot be masked.
- Recovery discipline applied: post-failure state verification before any retry (prevented a double-commit).
- Noticed on sight, deliberately NOT fixed (foreign in-flight scope): (i) the dns-blocker session's dirty `docs/todo/services.md` edit contains a run-together line — the new `[blocked:push]` M18 row starts mid-line after `…§M18-` without a newline; (ii) their staged-uncommitted 05-17 report sits in the shared index (their commit mechanics likely hit the same daemon race).

## f) Direct follow-ups (harvest at closeout; owner may also dispatch)

1. [ready] Close `pipeline.md:220` + TODO_LIST:459 (wire-into-gate) as DONE — pre-commit leg (`f21be80a`) + CI scan (`c630b064`) both live. CHECK FIRST whether the tq session's `3819027a` pipeline.md edit already closed it (avoid double-close).
2. [ready] Close `pipeline.md:221` (anchor validation) as DONE via `3cc72123`; close `pipeline.md:222` (CHANGELOG) as DONE via `99449fda`.
3. [ready] T8: fold the shell lessons into `docs/agents/shell-devtools.md` — `grep -F -e` for leading-dash lines, capture-before-shift (`target=$1; shift`), regex-in-variable for `[[ =~ ]]`, herestring over pipe for `-q` greps, content-probe over `wc -l`.
4. [ready] T17 proper: grep-verify premises of the remaining harvested rows (backfill list accuracy, fold-row scope).
5. [ready] T4a pocket-id runbook (module + sso-dns/secrets knowledge; layout/ops/traps shape).
6. [ready] T4b oauth2-proxy runbook (Layer-2 forward-auth, whitelist-domain, partOf provision).
7. [ready] T4c signoz runbook (main service; link signoz-coverage + gcp-monitoring sub-docs).
8. [ready] T4d immich runbook (PG shared cluster, ML, backup legs).
9. [ready] T5a twenty runbook (mkDockerService pattern, migration-review gate).
10. [ready] T5c taskchampion runbook.
11. [ready] T5d dozzle runbook (attach-flavor daemon-restart caveat).
12. [ready] T5e openseo runbook (hand-rolled vHost GSC callback exemption).
13. [ready] T6a crush-daily runbook.
14. [ready] T6b atticd runbook (storage-dir gating, RS256, substituter).
15. [ready] Post-backfill: update AGENTS.md:25 + `docs/agents/README.md:11` routing claims; close TODO_LIST:462 + `services.md:167`.
16. [ready] T9: `# Runbook:` pointer comments in service modules (~40; generate module↔runbook mapping first; grep coverage 100% verify).
17. [ready] T10: bidirectional links integration-registry step 9 ↔ monitoring.md Gatus patterns (anchors must pass T2 checker).
18. [ready] T11: superseded-chain narrative cleanup in the 7 docs/agents files (verbatim-first; per-file deliberate-deletion records).
19. [ready] T12: repo-wide prose AGENTS.md mention classification (live-pointer vs historical claim).
20. [watch] The tq session's staged-uncommitted 05-17 report (shared index; their recovery, not ours).
21. [watch] Run-together queue line in `docs/todo/services.md` (dns-blocker session's scope; flag to them).
22. [watch] W1: mr-sync post-deploy verify (their fix, their scope).
23. [decision] D1 core size / D2 crush hook / D3 fold wave — standing defaults?
24. [watch] `/` at 93% (54G free) — fine now; watch before large build waves (box history).
25. [ready] Consider an in-flight-claim convention for re-dispatched queue rows (the §d2 collision class) — belongs to the tq/pipeline owners' harvest.
26. [ready] Closeout: harvest THIS report's §f per the self-harvest convention (deliberately deferred by the user's wait instruction).

## g) Questions (max 3)

1. **D1/D2/D3:** keep the standing defaults (34KB core; routing-table+discipline, no hook; folds on-touch), or order the core slim / crush-hook spike / fold wave as explicit tasks?
2. **Push policy:** origin is level right now; this session's remaining waves will accumulate commits — push at session closeout, or always leave pushes to you?
3. **Convergent execution:** the tq pool and this plan session double-fired the same harvested row (both wired the checker into CI; content converged, attribution tangled in `3819027a`'s message). Should in-flight row claims become a queue-system work item, or is the occasional benign collision accepted?

---

**Bottom line:** Batch A (both §f quick wins) is LANDED and verified (`c630b064`): the living-docs checker is now enforced at THREE layers (pre-commit leg, CI selftest, CI full scan) and covers `docs/README.md`. The commit exit-128 was a daemon index-refresh race, not a failure; the parallel tq session convergently executed the same queue row (content fine, attribution noted). Phases 1–3 remain queued per plan; this report rides the daemon sweep (index contended by the parallel session's staged file at authoring time).
