# Forgejo Phase-1 Session — Self-Review: What I Forgot, What to Improve

**Session date:** 2026-09-18, ~17:30-20:11 CEST (Phase-0 handoff → Phase-1 complete; factual report at `2026-09-18_20-10_forgejo-primary-phase1-capability-inert.md` — THIS one is the critical layer on top)
**Host:** evo-x2 (SystemNix master; work carried by daemon batch commits + 1 pathspec commit)

---

## a) FULLY DONE (this session, verified)

1. **M05 push-mirror** — `canonicalRepos` option (inert default, eval-proven 2→3 sync phases), `forgejo-push-mirror` phase 3, swagger-verified schema, fixture asserts `interval:"8h"` in the POST payload.
2. **M06 flip mechanics** — `forgejo-flip-repo` + `forgejo-flip@` / `forgejo-flip-check@` template units (env + OnFailure, no secrets on command lines); dry-run twin; mid-flip migrate-failure fixture; lossiness runbook section.
3. **M07 dead-mirror monitoring — REDESIGNED on evidence** — plan heuristic falsified (TouchMirror advances `mirror_updated` on failed syncs; idle-healthy vs dead indistinguishable), replaced with notice-table collector + known-stale subtraction (`known-stale.txt` now persisted by every completed reconcile run) + fail-closed Gatus check.
4. **M08 census** — `forgejo-census` unit (run at G2).
5. **Session debts** — migrate-script fixture (7 branches), calendar proof (`05,13,21:40` normalizes, 8h spacing), plan-doc sync (§10 addendum + falsification record), F76 supersede annotation, runbook + AGENTS.md sections, status report.
6. **Verification** — `nix flake check --no-build` green ×2 (the green that matters ran against the exact committed tree via the docs-commit pre-commit); both fixture checks build-green; extendModules gating evals; live-host inert-shape eval.

## b) PARTIALLY DONE

| Item | What remains | Why it stopped |
| --- | --- | --- |
| Reconcile `known-stale.txt` persistence | **NO fixture asserts the new persistence block** (sort-into-state-file + atomic mv) — the only code I added this session without a committed test | Scoped it out citing the parallel session's live validation of reconcile generally; that argument covers the OLD logic, not my NEW lines. 10-minute job, not done |
| Flip unit full-config eval | I eval-verified ExecStart/%i and the sync-unit gating, never the flip/flip-check units' complete serviceConfig (EnvironmentFile resolution, harden merge) | Checked the interesting parts only; flake check covers module EVAL but I never eyeballed the rendered flip unit end-to-end |
| Fixture mutation-negative | Both fixtures caught my own authoring bugs (they CAN fail), but no deliberate break-a-branch negative pass (repo discipline for lints; behavior checks are adjacent) | Time; noted as next-action |
| Dead-mirror check vs pre-deploy §10 | The new metrics should be auto-loaned by the rendered-gatus diff; I reasoned it, never ran `pre-deploy-check.sh` §10 dry | No deploy was in scope; first real deploy confirms |

## c) NOT STARTED (owner-gated or later phases, by design)

- **G1** (storage migration: deploy → prepare → build → finalize → flip option → deploy → verify) and **G2** (P1 batch deploy + live push-mirror 201 + census) — both sudo/owner.
- M09-M11 (shim/audit, pilot, rollout), M12-M15 (CI port, Renovate, backup tightening), M16 (VM test), M17 (size measurement), M18-M23.
- Q1-Q3 from the 17-28 report remain UNANSWERED (G1 window, GitHub-issues policy, off-LAN stance).
- Parallel-session leftovers touching this domain (not mine): du measurement, Artmann-Minecraft disposition, 32 frozen archives, `forgejo-ensure-repos` collapse, commit-graph.lock cleanup.

## d) TOTALLY FUCKED UP (all caught in-session, all fixed before anything shipped)

| What | Cost | Lesson |
| --- | --- | --- |
| Nearly built M07 on the plan's falsified heuristic | 30-second live-data check saved a permanently-blind monitoring layer | A detector's signal must be shown to SEPARATE healthy from broken on real data before implementation; "TouchMirror-proof" was a label, not a verification |
| Capture var `out` shadowed nix's `$out` in BOTH fixture checks | ~40 min of misdirected sandbox-log archaeology (blamed line numbers, heredocs, stubs) | `out` is reserved in build scripts; and when a sandbox build fails inexplicably, EXTRACT the script (`nix derivation show` → `.derivations[].env.buildCommand`) and run it locally — I found that move 5 rounds too late |
| sed PATH-injection dropped the opening quote | 1 build round + local repro | Quote-bearing sed matches need quote-bearing replacements; `bash -n` the injected copy immediately |
| Two sloppy edit payloads (one garbage new_string, two stale old_strings after daemon mid-edit commits) | 2 wasted rounds | Re-read after EVERY daemon commit that races you; the file-changed guard exists for a reason |
| `printf ''`, `/usr/bin/env` shebangs, btrfs stub arg-index — three fixture-infra bugs | 3 build rounds | Stub bugs look like script bugs; check the stub's view of the call shape first |
| Corrupt-scenario tamper would have been healed by the delta rsync | Caught at design time | Reaching a verification branch requires defeating the thing that normally makes verification trivially true (size+mtime-preserving tamper) |

## e) WHAT WE SHOULD IMPROVE (durable)

1. **Detector-evidence gate** (from d1): new monitoring checks cite live separation evidence in their PR/description — the M07 falsification is the template.
2. **Committed fixtures > ad-hoc fixtures**: the parallel session's /tmp-only script verifications are now superseded for the new scripts by derivation checks that run on every pre-commit + CI. Keep that bar for every new operational script.
3. **Sandbox debugging runbook**: `nix derivation show <drv>` → jq `.derivations[].env.buildCommand` → run locally with `bash -x`. Should live in AGENTS (the Nix gotchas section) — I learned it here the hard way; next session shouldn't.
4. **The daemon race tax is real but bounded**: 3+ sweeps this session. Pathspec commits + `git show --stat` verification + never amending foreign batches worked; the alternative (fighting for clean commits) is not worth it.

## f) Up to 50 next things (priority order; owner-gated marked ★)

**Gates & owner decisions**
1. ★ G1 storage migration window + execution (migrate-forgejo-subvol.sh header, 4 steps)
2. ★ Answer Q2: GitHub-issues policy post-flip (freeze vs one-way import) — gates M06 usage
3. ★ Answer Q3: off-LAN stance (re-open or confirm LAN-only)
4. ★ G2 deploy of the P1 batch + scratch-repo push-mirror 201 probe + census run → runbook
5. ★ Notices-table growth policy (NEW this session): frozen mirrors write ~1.6k notice rows/day forever — periodic admin purge acceptable, or resolve the frozen set (delete 32 archives / re-home 2 transfers) first?

**Session-debt closeout (next session, no owner needed)**
6. Fixture-assert `known-stale.txt` persistence in the reconcile path (extend forgejo-scripts-fixture)
7. Full rendered-unit eyeball: `forgejo-flip@` complete serviceConfig (EnvironmentFile + harden merge) via nix eval
8. Mutation-negative pass: break one branch per script, confirm both fixtures go red, revert
9. First-deploy watch: confirm §10 auto-loans `forgejo_mirror_dead_candidates`/`health_scrape_errors`; expect ONE red dead-mirror cycle until the first reconcile publishes known-stale.txt — pre-brief the Discord channel
10. Add the sandbox-debugging runbook (d2/e3) to AGENTS.md Nix gotchas

**Plan continuation (after G2)**
11. M09: `scripts/forgejo-remote-audit.sh` + flag-gated insteadOf shim (SHIPS DISABLED)
12. M10: pilot flip end-to-end (F45-F48 incl. scratch-nix `github:` resolution proof)
13. G3 burn-in (one full 6h/8h cycle green)
14. M11 rollout batches + GitHub branch-protection seatbelts (F50-F54)
15. M12-M13 CI port (`.forgejo/workflows/`, `DEFAULT_ACTIONS_URL`, retention, migrations allowlist)
16. M14 Renovate on platform=forgejo
17. M15 backup-coordination tightening + offsite pointer
18. M16 `tests/test-forgejo.nix` VM test (fold in flip/push-mirror units)
19. M18 owner-decision packet (7 decisions, one table)
20. M19-M23 docs/watchlist/upstream/both-ways R&D per plan

**Noticed in passing (other sessions' domains — pointers only, NOT verified)**
21. A freeze-6 diagnosis report appeared at 20:06 (parallel session) — IO-storm class; my deploy-order note (9) matters MORE if storms continue
22. A Samsung 2nd-boot-disk pareto plan (19:53) touched flake.nix + pre-reboot-check.sh in the same commits that carried my code — content-verify before touching either file
23. Two foreign untracked status reports sit in docs/status/ (not mine, not committed)

## g) Questions I cannot answer myself

1. **When is the G1 window?** The migration takes forgejo DOWN for minutes and wants a quiet-IO window (the box froze at 15:27 today per the parallel freeze-5/6 reports — timing is yours to pick). Q1 carry-over.
2. **GitHub Issues post-flip: freeze read-only (my recommendation) or keep-live with one-way import?** Gates how M06's flips are operated at scale (Q2 carry-over).
3. **The notices-table growth (f5):** purge-on-a-cadence vs resolving the 34 frozen mirrors first — a data-retention call only you can make; it also decides whether `forgejo_mirror_dead_candidates` ever has a permanently-excluded baseline set.

---

**Evidence trail:** the 20-10 report's evidence section stands (fixture PASS lines, gating evals, falsification jq+source citations, calendar proof). Commit topology: code + docs carried by daemon batches `8a999bcb..566649e0`, my pathspec commit `7044e595`; tree clean of my files at close.

