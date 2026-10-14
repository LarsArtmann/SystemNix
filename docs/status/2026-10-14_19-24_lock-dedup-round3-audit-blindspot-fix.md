# Flake Lock Dedup Round 3 (447→440) + Lock-Audit Blind-Spot Fix

**Date:** 2026-10-14 19:24 CEST
**Session shape:** user `cat flake.lock` → "looks like we could improve some things?" (analysis) → "fix?" (execution) → stepwise close-out under an active io-storm gate + one parallel session.

## Context

Lock stood at **447 nodes / 266 unique revs** (regrown from the 2026-10-08 collapse's 443 — the documented regrowth class). Analysis classified the duplication: ~190 nodes of deliberate hermetic per-tool Go tarball pins (doctrine: never follow), deep dups only fixable upstream ([blocked:push]), and a small root-fixable residue. Session targeted the residue.

## a) FULLY DONE (all verified)

1. **`art-dupl` infra follows** — flake-parts (same-rev no-op) + treefmt-nix (eval-only, 4cfe8d70→root's 0d6d7390) followed away. These had survived BOTH prior dedup passes.
2. **`templ` root-promotion** (github:a-h/templ/v0.3.1070) + `inboxclean.inputs.templ` / `overview.inputs.templ-cli` follows — collapsed the two identical 5-node subtrees (identical tag, byte-identical narHash; build-tool binary, no FOD exposure).
3. **Lock-audit alias-blindness FIXED** — `isAlias` matched root input NAMES (domain) instead of the node keys root resolves to (IMAGE). art-dupl's edge value `"flake-parts"` named the root input while pointing at its own separate node — invisible to the guard, which is why the dups survived. Fixed in `lib/lock-audit.nix` (`rootNodeKeys` image check), pinned by the **7th selftest leg** (`tests/fixtures/lock-audit/evil-alias-collision.lock`, the exact live shape).
4. **Deliberate table extended**: `templ.nixpkgs` (FOD build env), `crm.nixpkgs` (same-rev today; flip pending the open crm follows [decision] in upstream.md — deliberately NOT flipped without the owner).
5. **Lock reconciled** via the worktree-canonicalize pattern: **447→440 nodes**; root revs byte-identical except the new templ pin; node key-set delta exactly −7/+0; content multiset delta exactly the predicted removals; jq-replicated audit verdict `[]` pre-battery. Lock adopted; main == worktree byte-identical; committed at HEAD lineage (daemon).
6. **Battery ALL GREEN** (gate opened 19:07 after ~2 h storm wait): `lock-audit-selftest` built+ran — "7 legs green"; `nix flake check --no-build --all-systems` RC 0 "all checks passed!" with **ZERO** non-existent-input override warnings; evo-x2 toplevel drvPath eval green; `nix fmt --no-update-lock-file -- --ci` 0 changed.
7. **Docs**: CHANGELOG [Unreleased] gained 3 entries (rounds 1+2 retroactively — rows 48/49 asks — plus round 3 with battery evidence); `docs/agents/nix-flakes.md` "Infra follows" updated (447 re-measure, 440 collapse, domain-vs-image lesson); pipeline.md rows pruned: 2026-10-02 CHANGELOG row, flake-compat/git-hooks collapse row (done 2026-10-08, evidence was in nix-flakes.md), deferred-battery row (discharged by today's battery), todo-list-ai systems-override row (line already removed by an earlier wave; today's warning-grep is the post-check); fixed the dangling "the row above" reference in the override-warning-gate row.
8. **Cross-session coordination**: the parallel session's new `flake-input-pin-audit` guard hit an infinite recursion mid-session; they fixed it on main (19:07) AND absorbed my templ pin into their allowlist quoting my rationale. Main eval green with both changesets. Their work is theirs; the interaction is recorded here because my battery initially failed against their stale snapshot (see §d.4).

## b) PARTIALLY DONE

Nothing half-landed in code or lock. Close-out items (CHANGELOG battery sentence re-apply after mtime drift, battery worktree removal, self-harvest row) were completed during this report's authoring.

## c) NOT STARTED (deliberate, with owner/gate)

- **crm nixpkgs/gnh follows flip** — open [decision] in docs/todo/upstream.md; agent did not decide for the owner.
- **project-dependency-graph nixpkgs follow** — needs cv-style FOD analysis before flipping.
- **monitor365 disabled-input subtree** (crane + 6 collector source pins) — service-lifecycle call (monitor365 disabled since 2026-08-12, input still declared).
- **Fleet-wide infra-follows in the LarsArtmann tool repos** — the only fix for the deep-dup mass (~flake-parts ×8, treefmt-nix ×6, cross-tool go-* dups); queued [blocked:push].
- **Weekly flake-update bot token** (`NIX_GITHUB_RO_TOKEN`) — owner secret; unblocking it replaces manual evening waves (the regrowth + FOD-churn vector).
- **Override-warning CI gate** (pipeline row, stayed open by design — its premise row was closed, the ask stands).

## d) TOTALLY FUCKED UP (honest, this session)

1. **Stale-worktree battery failure (the big one)** — the battery waited ~2 h for the gate inside a worktree snapshotted BEFORE the wait; at gate-open it ran against the 17:01 snapshot of the parallel session's pin-audit (recursion bug) and failed with `infinite recursion`, costing a full diagnosis round. Root error: I copied the shared flake.nix into isolation without inventorying the unknown references it had accumulated (the `flakeInputPinAuditGuard` wiring at flake.nix:1090 was theirs, unexamined by me). Fixed by rebuilding the worktree at current HEAD → green untouched. Harvested as a queue row (§f.1).
2. **Destructive misedit in pipeline.md** — the row-52 prune was built wrong and replaced the PSI-aware row's full text with its title (gutting its body). Caught immediately and restored byte-identical. Same family as the earlier failures below: constructing edit anchors from memory instead of the freshly-read text.
3. **Two malformed tool-call batches** emitted after the battery (empty/broken JSON) — user cancelled; re-issued properly.
4. **First pipeline.md multiedit failed** (anchor omitted the interleaved row 50).
5. **CHANGELOG final edit blocked on mtime drift** (daemon commit at 19:06) — re-Viewed and re-applied at close-out; the "battery deferred" sentence lived in the tree for ~20 min after the battery had actually run (stale-claim window).
6. Minor: `flake.lock.orig` copy vanished (worked around via `git show HEAD:flake.lock`); my first multiset-diff awk mislabeled +/- semantics (replaced by authoritative key-set `comm`); two initial jq queries errored on shape assumptions.

## e) WHAT WE SHOULD IMPROVE (session lessons)

- **Name-domain vs resolved-key heuristics are a guard-bug class**: the lock-audit checked "does this string name a root input?" instead of "does this string name the node key a root input RESOLVES to?". Any guard comparing identifiers should compare against the resolved image, not the naming domain — two dedup passes and the audit's own selftests all missed it until a fixture pinned the exact live shape.
- **Isolation snapshots age during long waits**: any watcher that sleeps on a gate must re-sync from HEAD as its first gated action (harvested, §f.1).
- **Copying shared files into isolation carries unknown passengers**: my flake.nix copy included the parallel session's guard wiring silently. When forking a shared-tree file, diff it against your last-known read and inventory unknown references.
- **Line-number row pointers rot**: the closed deferred-battery row pointed at "TODO_LIST:486", which had drifted to an unrelated row. Queue pointers should be grep anchors, not line numbers.
- **Close-out sentences go stale fast on daemon-shared trees**: write result-dependent prose (battery status) only after the result exists, or expect a mtime-drift re-edit.

## f) NEXT TASKS (session-derived; 1 is newly harvested, the rest were already queued or owner-gated)

1. [HARVESTED → TODO_LIST + pipeline.md] Gate-waiting watcher scripts re-sync worktree from HEAD at gate-open.
2. [queued [decision]] crm nixpkgs/gnh follows flip (upstream.md).
3. [queued, needs analysis] project-dependency-graph nixpkgs follow (cv-style FOD protocol).
4. [owner call] monitor365 disabled-input subtree prune (crane + collector pins).
5. [queued [blocked:push]] Fleet-wide infra-follows in LarsArtmann tool repos — kills the deep-dup mass (the 443→447→440 breathing).
6. [owner secret] NIX_GITHUB_RO_TOKEN → unblock the weekly flake-update bot (merge-weekly-PR loop replaces manual waves).
7. [queued] Override-warning CI gate (pipeline row; premise case closed today, ask stands).
8. [queued] PSI-aware pre-commit fast-path (pipeline row; today's 2 h battery wait is another data point for it).
9. [observation] The 447→440 margin will regrow with every upstream wave that adds unfollowed infra edges in tool locks — the audit now catches root-owned regrowth, deep regrowth stays invisible until (5) lands.
10. [observation] `nixpkgs@7fd4004` one-hop same-rev copies under crm/project-dependency-graph are each −1 node once their flips land (2+3).
11. [observation] flake-parts ×8 / treefmt-nix ×6 same-rev dups inside tool-owned copies are the largest visible residual mass — upstream-only.
12. [housekeeping] The negative-test harness (nightly CI) will exercise the new alias-collision leg on its next run — no action unless it fires.

Deliberately NOT harvested (owner-gated or already queued verbatim above): 2–8.

## g) QUESTIONS FOR THE OWNER (cannot be answered from the tree)

1. **crm follows posture**: crm's nixpkgs (and go-nix-helpers wave5 divergence) sit at an open [decision] — flip crm onto root's pins (same-rev today, pure collapse) or keep its own pins pending the upstream decision?
2. **monitor365's flake input**: the service is disabled since 2026-08-12 but its input subtree (crane + 6 collector sources) still locks ~7+ nodes — prune the input now, or keep it for the service's potential return?
3. **`NIX_GITHUB_RO_TOKEN`**: are you willing to add the read-only GitHub token secret so the weekly flake-update bot can run? (This is the single highest-leverage change for lock hygiene: it replaces the manual evening waves that drive both regrowth and vendorHash churn.)

## Verification evidence

- selftest: `nix build …#checks.x86_64-linux.lock-audit-selftest -L` → `lock-audit: 7 legs green (clean, dup, drift, infra-dup, alias-collision, allowlisted, stale-deliberate)` RC 0
- `nix flake check /tmp/lock-battery-1014 --no-build --all-systems` → RC 0, "all checks passed!", `grep -c non-existent` = 0 (log: /tmp/flakecheck-1014.log)
- `nix eval …#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` → `/nix/store/0n6shrix…-nixos-system-evo-x2-26.11.20261011.7fd4004.drv`
- `nix fmt --no-update-lock-file -- --ci` → `formatted 3085 files (0 changed)`
- lock proof: `jq` node counts (447→440), root-rev diff (only `+templ 07dfb6e0`), key-set `comm` (−7/+0), content multiset (exact predicted removals), audit replica `[]`
