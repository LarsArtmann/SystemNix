# Dispatch batch — capture-once doctrine, stateVersion wall (91→0), FEATURES re-stamp, drift recount

**Session:** 2026-11-06 04:5x–05:30 CET, resume instance of the 04-37 close-out (parked awaiting owner §g answers — none arrived yet; this session executed only the non-owner-gated [ready] legs).
**Storm:** io PSI avg10 98.5 at 05:0x, load 156 — full-storm throughout; every full flake check ran in a clean-HEAD worktree (`~/.cache/systemnix-verify`, see §c trap).

## a) What ran (all verified)

1. **Capture-once-then-grep doctrine (pipeline.md:380, 01-52 §f.7) — DONE, `6ba980df0`.** AGENTS.md "Build & Deploy" now carries the rule beside the flake-check memory-profile note: heavy-command output destined for repeated inspection is teed to `~/.cache/` first — one eval, N inspections (the 2026-09-26 §d-1 case: same full eval 4× in 10 min). This session then PRACTICED it: every walk below ran once into `~/.cache/stateversion/`, all greps hit the files.
2. **stateVersion warning wall (pipeline.md:381, 01-52 §f.19) — DONE, `7ee80ef51`.** See §b — the row's premise was half-wrong and the measurement corrected it.
3. **FEATURES.md doc-counts re-stamp — DONE (daemon-batched `f6da605c3`).** HEAD was RED: `doc-counts: FEATURES nixosModules asserts 146, eval truth is 147` — the trash-metrics module (2026-11-06) re-stamped README only (`f6a942ef1`); that re-stamp was docs-only so its pre-commit hook skipped the flake check (the exact eval-irrelevant-skip seam) and the drift shipped. FEATURES line 28 + header now say 147/152 files; doc-counts evals green (after-walk rc=0).
4. **docs-gates `--audit-all` item-counter recount — DONE (my 04-37 report §f.9 obligation discharged).** `docs-freshness --audit-all`: **12,638 unharvested items / 2,521 reports** (baseline 03:3x: 12,628 / 2,516). +10 items / +5 reports — five new sibling-session reports out-added batch-1's annotations of the six 2026-09-26 files. Drift row (pipeline.md:400) updated with the number and the watch-the-delta guidance.
5. **T11 probe:** io PSI avg10 = 98.5 at 05:0x (needs <20 sustained 3 min) — gate decisively unmet, stays pending. No bench attempted.

## b) stateVersion wall — premise corrected by measurement

- Row premise: "VM-test fixtures emit dozens of warnings per eval." **Live wall (keep-going walk at HEAD): 91 warnings — NONE from VM fixtures.** Emitters: the 15 bare `nixosSystem` audit helpers (systemd-shape-audit ×10, port-registry ×10, mount-gating ×9, stray-unit ×8, hot-db-assertions ×8, gatus-coverage ×7, sops-key ×6, integration ×6, deploy-restart ×6, tmp-cleaner ×4, session-boot ×4, sops-recipient ×2, inboxclean ×2, catalog ×2, tq-agent-pool ×1) + the borg-restore-drill fixture (×3 on both systems).
- Mechanism (read from pinned version.nix): `stateVersion.apply` fires `warnIf` ONLY at option-default priority (1500) when the value is read. Fix: pin `{ system.stateVersion = "26.11"; }` — **equal to the pin's own `cfg.release` default, zero behavior delta** — into every audit helper; VM family via runNixOSTest's own `defaults` key (merged into all nodes by testing/nodes.nix) with `mkDefault`, so per-test sets (boot's 25.11) still win.
- First attempt (wrapping each node in `[ node base ]`) was REJECTED by the tester — `nodes.<name>` is typed single-module ("not of type submodule") — caught by the A/B walk (37 errors), reshaped to `defaults`. Why `defaults` is safe was verified against the pinned nixpkgs source, not memory.
- **A/B evidence (clean-HEAD worktree, `flake check --no-build --all-systems --keep-going`): before 91 warnings + doc-counts error; after 0 warnings, 0 errors, rc=0.** Main-tree == worktree content verified file-by-file before the after-walk.

## c) Traps hit this session (worth remembering)

1. **A parallel session's UNCOMMITTED flake.lock made every main-tree eval throw the infra-follows audit error** (go-nix-helpers' treefmt-nix deep copy, rev 27b3b12a): `nix eval`, `nix fmt`, all blocked ~40 min. Workaround: clean-HEAD `git worktree` as the eval surface (this is the documented safe-verification pattern earning its keep for evals, not just extendModules). The sibling's lock then landed via DAEMON heuristic commits (`edd685d2f` + `f6da605c3` + `430022405`) — still with the regrown node; **HEAD remained red on the lock audit at session close** (see §e). I did not touch their lock (their update, their follows intent).
2. Daemon swept my in-flight edits in three heuristic batches (16-file sweep, tests/default.nix, FEATURES+lock); contents verified mine via `git show --stat` per policy; HEAD amend landed as `7ee80ef51`.
3. My own `cp` roundtrips tripped the edit tool's mtime guard twice — re-view + re-edit is the cure, not a fight.

## d) Owner-gated remains (unchanged from 04-37 §g)

1. **D2 deploy authorization** — float gate closed (`f1a898dd5`), PSI extreme-band gate holding correctly; anchor still gen-983. NOTE: the sibling lock churn is now ALSO deploy-relevant (the float register consumes local revs; a red lock audit blocks the toplevel proof).
2. **Archive policy** for the six resolved 2026-09-26 sweep files.
3. **T26 pacing** (batch 2 = 2026-09-27 pair) — recommend holding until the lock settles + one calm deploy window.

## e) Open at close

1. **HEAD red on `lib/lock-audit.nix` infra-follows** (sibling's in-flight flake.lock regrew `treefmt-nix` deep copy @27b3b12a; root pin = `treefmt-nix_2` @0d6d739a; flake.nix:1066 already follows the root edge). If the sibling session went quiet leaving it red, the fix is their prescribed one-line consumer follows (or a lock re-regen) — flagging rather than fighting an active session's surface.
2. T11 (PSI gate), T15/T16/T27 (deploy-gated), pushes (owner+churn) — unchanged.

## f) Follow-ups

1. Watch the lock-audit state at next session start; if still red AND the sibling is gone, queue the consumer-follows one-liner (NOT executed here — attribution discipline).
2. The eval-irrelevant-skip seam that shipped the FEATURES drift (docs-only re-stamp skips the flake check that would catch it): consider a `doc-counts` cheap pre-commit leg (grep FEATURES/README counts vs `nix eval` when the staged diff touches FEATURES.md/README.md only) — bounded, but a new gate; owner-visible as a suggestion only.
3. Worktree `~/.cache/systemnix-verify` kept until the lock settles (next session's cheap eval surface); remove with `git worktree remove --force` after.

> HARVESTED 2026-11-06 (this report): item 1 → watch row above (deliberately not queued: attribution discipline — the fix belongs to the active lock session, re-queue if it goes quiet-red); item 2 → docs/todo/pipeline.md row (doc-counts pre-commit leg suggestion, [decision]); item 3 → transient scratch, no row needed.
