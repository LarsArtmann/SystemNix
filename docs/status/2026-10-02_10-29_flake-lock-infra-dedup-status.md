# Status Report: flake.lock infra dedup session (2026-10-02)

**Date:** 2026-10-02 10:29 (CLI `date`)
**Session scope:** user directive "can we be smarter?" → full Pareto-planned execution of flake.lock duplicate collapse + eval-time lock-hygiene gate, from commit `24ce034b` (clean start) to now.
**Plan doc:** `docs/planning/2026-10-02_09-47_flake-lock-infra-dedup.md` (close-out section has measured metrics)

---

## a) FULLY DONE

1. **Root-cause analysis of the lock duplication** — 421 lock nodes for 235 unique revs; per-dep duplicate inventory (flake-parts ×24/2 revs, treefmt-nix ×18, nixpkgs ×8/3 revs, systems ×7, flake-compat ×7, git-hooks ×5, flake-utils ×2); root-input vs deep-edge attribution computed from the lock graph (python one-hop analysis, reproducible).
2. **Hermes gate restoration** (commit `9f75621d`) — the 09:31 auto lock update had re-locked hermes-agent to `10c6188d`, whose flake eval-forces the `hermes-python-source` FOD (IFD class), breaking `nix flake check --no-build` (the pre-commit gate) for EVERY commit in the repo. Restored to eval-clean `bafb42b4` via the discordsync rollback pattern; discovered + documented the `original.rev` re-float trap along the way (eval silently re-floats when lock-original ≠ flake spec — stripped the rev so the pin is stable). Verified: hermes check eval green, evo-x2 toplevel eval green, lock stable across repeated evals.
3. **Infra-follows collapse** — 33 attrpath follows lines for 21 inputs (data-derived one-hop edges, including `emeet-pixyd`, whose lock entry was typo'd `emeet-pixd` and renamed during the reconcile). Result: **421 → 387 lock nodes**, **zero root-input rev floats** (byte-verified by script), treefmt-nix 18→9, flake-parts 24→9, systems 7→4, flake-utils 2→1, nixpkgs 8→5 (remaining non-root revs are the 3 documented deliberate ones). Only real rev flip: papdashboard nixpkgs `7a0f122f` → root rev.
4. **Eval-time lock-hygiene gate** — `lib/lock-audit.nix`: pure-Nix audit wired into the existing `allEvalGuards` seq-chain in flake.nix outputs; throws on any root-input-owned unfollowed infra edge (the exact shape a blanket lock wave regrows) and on stale `deliberate` allowlist entries. Proven live: its first run caught the real `emeet-pixyd` miss; end-to-end negative test (remove one follows line → every eval throws with the self-describing fix; restore → green).
5. **Self-testing check** — `checks.x86_64-linux.lock-audit-selftest`, 5 fixture legs (clean / same-rev dup / foreign-rev drift / deliberate-allowlisted / stale-deliberate), all green, built via `nix build`. Follows the gitleaks-coverage-selftest house pattern (no guard without a positive fixture).
6. **Doctrine + queue hygiene** — `docs/agents/nix-flakes.md` gained the "Infra follows & lock hygiene" section (rules, why the lock cannot be computed, enforcement, known residuals); stale 420-node counts updated. Follow-ups queued on BOTH surfaces (TODO_LIST.md + domain libraries): flake-compat/git-hooks root-promotion (pipeline), legacy hand-follows migration (pipeline), fleet-wide upstream follows (upstream, blocked:push).

## b) PARTIALLY DONE

1. **Full `nix flake check --no-build --all-systems`** — GREEN, exit 0, "all checks passed!" (re-verified with proper exit-code capture after authoring; only the 9 pre-existing dead-override warnings remain). Moved to done: item 3 below is closed.
2. **evo-x2 toplevel build** (job 064, `--keep-going`, covers the papdashboard nixpkgs flip) — launched ~10:15, still running at 10:29. Eval of the same toplevel is green; build verdict pending.
3. **Named implementation commit + push (original directive item 8)** — NOT done: the daemon swept my in-flight work into 8 heuristic commits (`9722711d`…`6c94fbec`) mid-session; I amended only the hermes rollback (`9f75621d`). The dedup implementation exists as a clean tree but its history is heuristic-message commits; 9 commits total are unpushed. Remains: one properly-messaged implementation commit (squash the heuristic stack via `git reset --soft` to `9f75621d` and re-commit) + push.

## c) NOT STARTED

1. **flake-compat + git-hooks collapse** (12 nodes) — needs root-input promotion first (rev-drift exposure for 5 repos' pre-commit evals); queued pipeline.
2. **Upstream fleet follows** (the deep tool-locks-tool dups: `discordsync → art-dupl_3 → flake-parts_*` class) — only fixable in the LarsArtmann tool repos' own flakes; queued upstream, blocked:push.
3. **Legacy hand-follows migration** (~100 per-block lines into the infra-follows group) — queued pipeline, opportunistic.
4. **CHANGELOG entry for the dedup** — repo convention check + entry not done.

## d) TOTALLY FUCKED UP

1. **The repo's commit gate was broken repo-wide before this session started** — the 09:31 daemon blanket lock update (commit `eff84ca8`) shipped a hermes rev that breaks `nix flake check --no-build` for EVERYONE; nothing could commit until the rollback landed. Root cause: unattended full-lock update + an upstream flake that eval-forces an FOD. Severity: was blocking all work; mitigated this session (a), but the CLASS remains: the weekly flake-update bot (when unblocked) can re-ship exactly this.
2. **Session raced the auto-commit daemon ~6 times** — my in-flight edits were swept into heuristic commits mid-verification repeatedly (c2e8587c, 6e997c4b, 9722711d, 93bcfa1f, 8740fe85, 9d11d5f6, 6c94fbec); one amend happened only after the daemon pre-empted a pathspec commit. A foreign session's change (`samber-linter` line in `lib/lars-packages.nix`) rode my daemon commit `8740fe85` — flagged, not touched, but it means the unpushed stack is NOT cleanly attributable without the squash.
3. **My first overlay design was wrong twice** — (i) computed `inputs` via `let … in` (rejected: "expected a set but got a thunk" — the flake input parser is syntactic); (ii) `//`-merge fallback also rejected. Cost: ~2 iterations; fixed by the literal attrpath group. Lesson recorded in nix-flakes.md so the next session doesn't re-try it.

## e) WHAT WE SHOULD IMPROVE

1. **Verification pipes must propagate exit codes** — my first baseline check reported "BASELINE-EXIT:0" while actually RED (the `$?` was `tail`'s). Two later gates repeated the pattern until corrected. Fix pattern: `set -o pipefail` or capture to file + echo the code from the file. (Same class as the repo's documented "pipeline masking" lessons.)
2. **The weekly flake-update bot needs an eval-gate guard for exactly the hermes class** — a bot PR whose own check bricks on one input re-locks the repo's gate for everyone. The bot runbook should include per-input rollback-on-red (the discordsync/hermes pattern is now twice-proven).
3. **Dead override warnings (9 inputs with `systems` follows that no longer declare it)** — pre-existing, warns on EVERY nix invocation, class already documented for go-cqrs-lite in nix-flakes.md. Cheap cleanup, rides the queued legacy-follows migration.
4. **Lock-audit scope** — flake-compat/git-hooks not yet in `infraDeps` (deliberate until promoted); when promoted, add them so the audit guards the full infra set.
5. **AGENTS.md prevention-layer table** doesn't yet name `lib/lock-audit.nix` in the eval-time row — the gate is only discoverable via nix-flakes.md; one line in the table closes the gap.

## f) Next things (ranked)

| #  | Task                                                                                                                  | Impact   | Effort | Category |
| -- | --------------------------------------------------------------------------------------------------------------------- | -------- | ------ | -------- |
| 1  | Squash heuristic commit stack into named implementation commit + push (original directive finish)                     | Critical | S      | Pipeline |
| 2  | Confirm toplevel build (job 064) green → papdashboard flip proven at build level                                      | Critical | S      | Quality  |
| 3  | ~~Re-verify flake check~~ DONE at 10:33: exit 0, all checks passed                                                    | Critical | S      | Quality  |
| 4  | flake-compat + git-hooks root-promotion + follows (12 nodes) — queued                                                 | High     | M      | Quality  |
| 5  | Add hermes-class rollback-on-red to the flake-update bot runbook                                                      | High     | S      | Pipeline |
| 6  | Remove 9 dead `systems` override lines (warnings on every eval)                                                       | Medium   | S      | Cleanup  |
| 7  | Add lock-audit to AGENTS.md eval-time prevention table                                                                | Medium   | S      | Docs     |
| 8  | CHANGELOG entry for the dedup                                                                                         | Medium   | S      | Docs     |
| 9  | Upstream fleet follows (deep dup class) — blocked:push, queued upstream                                               | High     | L      | Upstream |
| 10 | Legacy hand-follows migration into the infra-follows group — queued                                                   | Low      | M      | Cleanup  |
| 11 | nsfw-classifier nixpkgs flip when its FODs next regenerate (drop one `deliberate` entry)                              | Low      | S      | Quality  |
| 12 | Drop hermes rollback when an upstream rev evals green under --no-build                                                | Medium   | S      | Watch    |
| 13 | Drop the 3 vendorHash shims in lars-packages.nix when locks move past upstream-fixed revs (pre-existing, owner-gated) | Medium   | S      | Quality  |

Items 1–3 are this session's own unfinished obligations; 4 and 6–8 harvested to TODO_LIST.md + docs/todo/pipeline.md at authoring time (1–3 are session-blocked on user instruction below, 5 harvested to pipeline, 9 already in upstream library, 10 already queued, 11–13 are watch/owner-gated conditions recorded on existing rows and deliberately not re-queued).

## g) Questions I cannot answer myself

1. **Push authorization scope:** you asked for commit + push, but the unpushed stack includes another session's in-flight `samber-linter` change (rode daemon commit `8740fe85`). Push the whole stack as-is after squashing MY files, or hold the push until the samber-linter session lands its own commit?
2. **nsfw-classifier nixpkgs:** keep the deliberate non-follow (own build env, `git+file` local checkout) or flip it to root nixpkgs now — I cannot verify from here whether its FODs are validated against its own nixpkgs.
3. **Hermes forward-path:** the lock sits at the rolled-back `bafb42b4` while upstream master has the IFD-class break — should the weekly flake-update bot (when it goes live) pin `hermes-agent` updates behind a per-input eval probe, or is a manual drop-condition check acceptable?

---

_Verification narrative sources: plan doc close-out table; jobs 062 (check output), 064 (toplevel build, pending), 06F (check exit, pending); commit `9f75621d` message._
