# AGENT-DOCS-DURABILITY-PLAN — EXECUTION SESSION 3 (T8 + T17 landed; runbook research begun)

**Date:** 2026-10-01 12:03 CEST
**Plan:** `docs/planning/2026-10-01_03-00_AGENT-DOCS-DURABILITY-PARETO-PLAN.md`
**Scope this session:** resume after session 2's write-and-wait stop → verify prior landings survive the churn → T8 (shell lessons) → T17 (premise check + close 5 rows) → begin the runbook wave. Interrupted for this report after the wave's research phase (shape model + module/port mapping), before any runbook was written.
**Commits this session:** `80d43055` (T8), `53f34af0` (T17) — both carried to origin by a parallel session's push (verified `53f34af0` is an ancestor of origin/master; only 2 daemon heuristic commits remain unpushed).

---

## a) Fully functional and complete (verified)

1. **Session-state re-assessment.** Origin had moved: 7 unpushed commits at resume (parallel sessions: fifty-todos closes `b260baed`, buildcache queueing `9742be40`, caddy-logs-hot work in tree). My session-2 report WAS daemon-swept and is in history. Parallel-session files (caddy-logs-hot.nix, tests, their task HTML) identified and untouched throughout; by report time the daemon had swept them and the tree is clean.
2. **Re-verified every session-1/2 landing lives at HEAD** (survived ~9 intervening heuristic commits): T1 pre-commit markdown leg (`.githooks/pre-commit:171`), T2 anchor validation + `--selftest` (`scripts/check-doc-links.sh:157/244`), T3 CHANGELOG entry (`CHANGELOG.md:13`), Batch A CI step (`.github/workflows/nix-check.yml:163` + `docs/README.md` in `LIVING_DOCS`).
3. **T17 premise verification FIRST, closes second.** Before closing any row, grep-verified each harvested row's claim: `--selftest` exists; "21 runbook appendices" = 22 banner files (21 runbooks + CONTRIBUTING — matches the claim exactly); the 10-service backfill list is accurate (none of the 10 runbooks exist). Also verified the tq session's convergent duplicate `3819027a` did NOT touch the pipeline.md rows (no double-close risk) and `b260baed`'s 13 closures did not overlap my set.
4. **T8 DONE — `80d43055`.** Four new lesson bullets in `docs/agents/shell-devtools.md`: `grep -F -e` for leading-dash lines; capture-before-shift (the `$1`-after-`shift` 21-file misdirect); regex-in-variable for `[[ =~ ]]`; content-probe over `wc -l`. The herestring/SIGPIPE lesson was already documented (line 18) — referenced in the commit, not duplicated. `check-doc-links.sh` green post-edit (OK line).
5. **T17 DONE — `53f34af0`.** Closed 5 rows in BOTH queue and library surfaces using the exact close convention learned from `b260baed` first (`[x]` + strikethrough + `— DONE <date> (<session>): <evidence>`): TODO_LIST:465 (wire-gate) + :466 (anchor); `docs/todo/pipeline.md`:221 (wire-gate), :222 (anchor), :223 (CHANGELOG). `check-todo-system.sh` green on structure; the 58-report unharvested WARN is the known standing backlog owned by an existing queue row, not a new finding of mine.
6. **Runbook wave research begun.** Shape model locked from `docs/services/indexer-web.md` (Service header → prose → "What it serves" table → Ops → Related). All 10 target modules located: `pocket-id.nix`, `oauth2-proxy.nix`, `signoz.nix`, `immich.nix`, `twenty.nix`, `taskchampion.nix`, `dozzle.nix`, `openseo.nix`, `crush-daily.nix`, `attic.nix`; ports mapped from `lib/ports.nix` (1411/9464, 4180, 8080+12 more, 2283, 3200, 10222, 8084, 3002, 8081, 8200).

## b) Partially complete

1. **Runbook wave: research ~20% done.** The wave-level research (shape + module inventory + ports) is complete; per-service module reading (units, secrets, checks, traps) has NOT started — that is the bulk of each runbook's source material.
2. **Session-2 §f harvest obligation (carried):** items 1–4 of session 2's §f are now satisfied by this session's T8/T17 (closes + lessons landed); items 5–26 remain an unharvested set — most are the plan's own remaining tasks, tracked canonically by the plan doc + the already-queued backfill/fold/decision rows.

## c) Not started

- **T4a–T4d runbooks:** pocket-id, oauth2-proxy, signoz (main; link coverage/GCP sub-docs), immich.
- **T5a/c/d/e runbooks:** twenty, taskchampion, dozzle (attach-flavor caveat), openseo (GSC exemption pointer).
- **T6a/b runbooks:** crush-daily, atticd (storage-dir gating, RS256, substituter).
- **Post-backfill claim updates:** AGENTS.md:25 ("a few older services still lack runbooks") + `docs/agents/README.md:11` ("each service has a runbook"); close the backfill rows in TODO_LIST + `docs/todo/services.md`.
- **T9** module→runbook `# Runbook:` pointer comments (~40 modules; mapping first, batches of ~8, grep coverage 100%).
- **T10** bidirectional cross-link `docs/agents/integration-registry.md` step 9 ↔ `docs/agents/monitoring.md` Gatus patterns.
- **T11** superseded-chain narrative cleanup (7 docs/agents files; verbatim-first, per-file deletion records).
- **T12** repo-wide prose AGENTS.md mention classification sweep.
- **Closeout:** harvest this report's §f (see the deliberate-deferral note inside §f), final claim audit.

## d) Total fuckups

**None this session.** Both commits landed cleanly, no daemon races, no phantom greens, no edit-tool mismatches. The session-2 fuckup classes (exit-128 phantom failure, convergent duplicate execution) did not recur — and the discipline that prevents them (verify state before acting; verify premises before closing; learn the convention from an existing commit before editing) was applied throughout.

## e) What we should improve

1. **Convention-learning-before-editing worked** — reading `b260baed`'s close shape before marking rows produced zero convention drift on my 5 closes; keep this as the standing first step for any first-of-a-kind edit in this repo.
2. **Recorded deviation from plan micro-task M2.6:** the plan said "note in shell-devtools that anchors are now gated" — no such note exists in `shell-devtools.md`; I recorded the anchor-gating enforcement state in the row closures (pipeline.md + TODO_LIST) instead, judging it pipeline fact rather than shell fact. Owner may overrule and want the one-liner in shell-devtools (§f item 33).
3. **Noticed on sight, not fixed (foreign scope):** the standing "Close the 53-report unharvested backlog" queue row cites 53 reports while the live WARN count has grown to 58 — the row's count is stale (the drift class). Noted for whoever owns that row's next pass.
4. **Push-policy observation:** a parallel session's push carried my commits to origin mid-session — coordination by side-effect. Fine under the shared-tree model, but it means "never push" and "work is public anyway" now coexist; the §g2 question is about making this explicit rather than accidental.

## f) Next (remaining plan work; deliberately NOT harvested into the queue at authoring time per the user's write-and-wait instruction — the plan doc + existing backfill/fold/decision rows are the canonical tracking; harvest on resume)

1. T4a: pocket-id runbook (module + sso-dns/secrets knowledge; layout/ops/traps).
2. T4b: oauth2-proxy runbook (Layer-2 forward-auth, whitelist-domain, partOf provision).
3. T4c: signoz runbook (main service; link signoz-coverage + signoz-gcp-monitoring sub-docs).
4. T4d: immich runbook (shared PG cluster, ML, backup legs).
5. T5a: twenty runbook (mkDockerService pattern, migration-review gate; note the pending v2.43.0 bump row).
6. T5c: taskchampion runbook.
7. T5d: dozzle runbook (attach-flavor daemon-restart caveat).
8. T5e: openseo runbook (hand-rolled vHost GSC callback exemption).
9. T6a: crush-daily runbook.
10. T6b: atticd runbook (storage-dir gating, RS256, substituter cache.home.lan).
11. Post-backfill: update AGENTS.md:25 routing claim.
12. Post-backfill: update docs/agents/README.md:11 claim.
13. Post-backfill: close the runbook-backfill queue row + services.md library row (both surfaces, convention above).
14. T9: generate module↔runbook mapping (ls + test).
15. T9: pointer-comment batch 1 (~8 modules).
16. T9: batch 2.
17. T9: batch 3.
18. T9: batch 4.
19. T9: batch 5 + final `grep` coverage proof (100% of modules with runbooks carry the pointer).
20. T10: cross-link integration-registry step 9 ↔ monitoring.md (anchors must pass the gated checker).
21. T11: superseded cleanup — docs/agents/nix-flakes.md.
22. T11: systemd.md.
23. T11: storage.md.
24. T11: stability.md.
25. T11: secrets.md.
26. T11: desktop.md.
27. T11: monitoring.md.
28. T12: grep all remaining prose AGENTS.md mentions; classify live-pointer vs historical claim (table).
29. T12: fix stale live-pointers on sight; commit.
30. Closeout: harvest THIS report's §f (or re-defer explicitly) per the self-harvest convention.
31. Update the stale "53-report" count on the unharvested-backlog row (53→58, drift noted in §e3).
32. [decision] D1: keep the ~34KB core (standing default) or order the ~20KB slim.
33. [decision] M2.6 follow-up: anchor-gating one-liner in shell-devtools — row-closure record sufficient, or add the note?
34. [decision] D2: crush context-automation hook — spike or keep routing-table discipline.
35. [watch] W1: mr-sync `wantedBy` fix post-deploy verify (parallel session's scope).
36. [watch] `/` at 93% used (54G free) — watch before large build waves.
37. [watch] D3: appendix folds stay per-file-on-touch (5 individually dispatchable fold tasks exist in the plan).

## g) Questions (cannot figure these out myself)

1. **D1/D2/D3 defaults (carried from session 2, still unanswered):** keep the standing defaults — ~34KB core, routing table + discipline (no crush hook), appendix folds on-touch only — or order any of the gated tasks now?
2. **Push policy (re-scoped):** my commits reached origin via a parallel session's push. For the REMAINING waves: should this session push its own commits at closeout, or keep leaving pushes to you/parallel sessions?
3. **Convergent execution (carried):** session 2 and the tq pool double-fired the same harvested queue row (content converged; attribution tangled in `3819027a`). Should in-flight row claims become a queue-system work item, or are occasional benign collisions accepted?

---

**Bottom line:** Plan Phases 0 (enforcement, sessions 1–2) and the Phase-1 quick wins (T8 shell lessons `80d43055`, T17 closes `53f34af0`) are LANDED, verified at HEAD, and already on origin. The runbook wave (10 files, the plan's 80% band) is researched but not yet authored — shape model and module/port inventory complete, per-module reading next. Zero fuckups this session; both carried decisions and the three §g questions above remain the only blockers on continuing exactly where this stopped.
