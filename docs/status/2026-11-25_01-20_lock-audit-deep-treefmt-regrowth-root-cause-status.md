# Lock-audit deep-treefmt regrowth — root-cause fix status (deploy-eval block)

**Session:** 2026-11-25 ~00:49–01:25 CET · agent session on `master`
**HEAD at report time:** `1c2a3bf` (this report, the queue rows, and the formatter-canonical `lib/lock-audit.nix` are the only uncommitted changes of mine)
**Trigger (owner paste):** `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` → `error: flake.lock infra-follows audit failed: art-dupl_5 locks its own treefmt-nix deep copy …` — ask: "fix root cause".

**Verdict: the deploy-eval layer is GREEN again. The class re-fired ONCE during the session (a parallel session's brand-new input) and was fixed the same way. The recurring ROOT CAUSE is structural — Nix locks one node per input-graph PATH and a follows override can only be written after the path exists — so no one-time edit kills it; what landed is (1) both missing follows + canonical relocks, (2) a self-describing guard message (resolved input path + paste-ready line + regeneration recipe; it printed a renumber-prone node key and placeholders), (3) the automation and the throw-vs-warn decision queued with evidence (§f).**

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Root-caused instance #1 | Lock-wave commit `477059e` (00:32) floated `library-policy` 8d2b87bf → 3cbeffb6; that revision carried a NEW upstream input `art-dupl` (v0.10.0). Nix locked it as node `art-dupl_5` with art-dupl's OWN treefmt-nix edge (node `treefmt-nix`, SAME rev as root's `treefmt-nix_2` — a pure duplicate, eval-only, zero build effect). Lock walk before the fix: exactly 1 non-root treefmt-nix edge in 610 nodes |
| 2 | Fixed #1 | `library-policy.inputs.art-dupl.inputs.treefmt-nix.follows = "treefmt-nix";` (deep-collapse group) + canonical relock via throwaway worktree `nix flake lock`: 0.43 s, `• Updated input 'library-policy/art-dupl/treefmt-nix' … → follows 'treefmt-nix'`, orphaned copy pruned, 610 → 609 nodes, NO rev moved, the parallel session's uncommitted library-policy float preserved. Landed in daemon commit `8abb7e9` |
| 3 | Proved the deploy's eval layer | evo-x2 toplevel eval in an ISOLATED worktree: rc=0 at the `8abb7e9` state (`psz0sv8x…drv`) and at the final state (`6hcply19…drv`). The same eval in the shared tree died rc=102 "contents have changed … Make sure files do not change during evaluation" — parallel-session file churn mid-eval, not config |
| 4 | Guard diagnostics (`a442fd8`) | `lib/lock-audit.nix`: a deep-copy violation now names the input PATH and one paste-ready `<consumer>.inputs.<owner>.inputs.treefmt-nix.follows` line per consumer of the copy (shared copy → every line at once), an orphan copy gets a regenerate-the-lock verdict, and the message carries the regeneration recipe (`1c2a3bf`). `flake.nix` guard tail: the `deliberate` escape is scoped to root-owned edges (it never suppressed deep copies) |
| 5 | Selftest | 9th leg `deep-treefmt-paths` + `tests/fixtures/lock-audit/evil-deep-treefmt-paths.lock`. NEGATIVE proof: old audit + new leg → `SELFTEST FAIL: evil-deep-treefmt violation names neither its input path nor the paste-ready override …` rc=1; POSITIVE: `lock-audit: 9 legs green` rc=0. Path resolution stress-tested on the real 610-node graph and 3 synthetic variants (root input, dangling follow, shared node) at 0.03 s each |
| 6 | Class re-fired mid-session — instance #2 | A parallel session added root input `tracking-papers` (`5a2e9f9`, 01:04); its `go-nix-helpers` copy (`go-nix-helpers_19`) locked its own treefmt-nix (rev 0ba5d672 ≠ root's a0a97e31) → every eval RED again. The NEW message named `tracking-papers/go-nix-helpers` + the exact line on its first live use. Fixed identically (`tracking-papers.inputs.go-nix-helpers.inputs.treefmt-nix.follows`, the journal/bank-sync shape — the go-nix-helpers edge itself stays deliberately unfollowed): 613 → 612 nodes, no rev moved, landed in `1c2a3bf` |
| 7 | Formatter conformance | `nix fmt --no-update-lock-file -- --ci` on the changed `.nix` files: `flake.nix` + `lint-static.nix` canonical as written; `lib/lock-audit.nix` adopted in the formatter's layout (AST-identical to the committed blob, `nix-instantiate --parse` compared) |
| 8 | Docs / memory / queue | docs/agents/nix-flakes.md (regrowth rule + fix loop + unstable-node-key lesson, 9th leg); CHANGELOG 2026-11-25 entry; the stale `art-dupl_5` node-key comment in flake.nix corrected; the 2026-11-24 art-dupl_5 rows ticked on BOTH surfaces; §f rows harvested |

## b) PARTIALLY DONE

- **The root cause is structural, so it is contained, not eliminated.** Any float that CREATES a consumer path (an upstream gaining an input, a brand-new root input) regrows the class: 3 instances in 17h (2026-11-24 07:54 nsfw-classifier/art-dupl; 2026-11-25 00:32 library-policy/art-dupl; 01:04 tracking-papers/go-nix-helpers). After this session each instance is a ~2-minute mechanical fix (paste the printed line → worktree `nix flake lock` → deploy). Removing the human step and the fleet-wide brick are queued (§f), not built unasked.

## c) NOT STARTED

- `scripts/lock-follows-fix.sh` (§f.1) — a new pipeline stage; specced, not built.
- Throw vs warn for the deep leg (§f.2) — reverses a recorded owner design (2026-10-14 "fails eval on ANY declared treefmt-nix edge"); owner call.
- Upstream follows in the LarsArtmann tool repos (the `library-policy → art-dupl` deep flake-parts/gogenfilter/nixpkgs copies) — existing `[blocked:push]` row in docs/todo/upstream.md, instance noted there.

## d) TOTALLY FUCKED UP (honest ledger)

1. **Bricked every eval for ~2 minutes with my own edit.** I developed the `lib/lock-audit.nix` change directly in the shared tree; the first edit carried a list-literal syntax slip (`[ a ++ b ]` — operators need parens inside `[ ]`), a parse error in a file forced by EVERY eval (00:56–00:58). Caught by my own direct-eval test; no daemon commit landed in the window (`f4d4f85`, 00:56:23, did not include the file). The two later edits were developed in the isolated worktree first — where a second slip (an unescaped `"` inside a Nix string) died harmlessly. Rule: eval-forced files are developed, parse-checked and negative-tested in a worktree, then ported atomically.
2. **Misread the formatter contract.** I assumed `--ci` never writes; this repo's treefmt rewrites AND fails on change. My first "unchanged by formatter" comparison was vacuous (baseline copied after the rewrite). Caught by diffing the worktree copy against the committed blob.
3. **Over-escaped edit parameters** (`\\\"` vs `\"`) cost one failed `old_string`; the file's `\'` was a real escape, not display noise — resolved by `cat -A`.
4. **Two wasted probe runs** (a python typo; a "hot fan-in" variant whose node had no inputs).

## e) WHAT WE SHOULD IMPROVE

- **An eval-time guard that throws must print the exact remediation** (path + line + verb). The placeholder form plus an unstable node key made every instance archaeology and had already rotted one flake.nix comment and two TODO rows (`art-dupl_5` was nsfw-classifier's copy on 11-24, library-policy's by 00:32).
- **A plain `nix flake lock` on an otherwise in-sync lock is path-local** (proved twice tonight: one edge flipped, orphan pruned, zero rev moves, sub-second). The 2026-10-03 "blanket re-lock" hazard applies only while flake.nix carries pending unfollowed overrides. Keep the worktree form as the default recipe — it proves canonicity for free.
- **Lock node keys are not identifiers.** Both relocks renamed root's treefmt node (`treefmt-nix_2` ↔ `treefmt-nix`). Cite input paths.

## f) NEXT (self-harvested at authoring time)

1. **[ready]** Productize the fix: `scripts/lock-follows-fix.sh` (plan → insert → worktree `nix flake lock` → adopt → verify) — **HARVESTED** → `TODO_LIST.md` + `docs/todo/pipeline.md`.
2. **[decision]** Deep-treefmt guard severity: keep throw (+ automation) or downgrade the deep leg to warn + one-command repair — **HARVESTED** → `docs/todo/pipeline.md` (library-only by design: `[decision]` rows are not harvested into the queue).

**Harvest log:** §f.1 → TODO_LIST.md + docs/todo/pipeline.md; §f.2 → docs/todo/pipeline.md.

## g) QUESTIONS FOR THE OWNER

1. Keep the deep treefmt leg at `throw` (with §f.1 automation), or downgrade it to a visible warning plus the one-command repair (§f.2)?
2. Should the fix script also run from the pre-commit hook when `flake.lock` is staged (auto-repair + restage), or stay a manual one-command step?

---

*Report scope: this session only. Parallel-session note (flagged, not co-verified): the 00:32 library-policy lock wave `477059e`, further library-policy floats through 00:46, the `tracking-papers` input + supplements-weekly-print work (`5a2e9f9`), and the ai-meter dashboard files are other sessions' changes that rode the same daemon commits.*
