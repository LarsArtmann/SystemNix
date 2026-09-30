# Task re-fire-3 close-out — Guard scrub-stop phantom (000001a0eaf255cff90e3b85a22accf257e2)

**Date:** 2026-09-30 06:25 CEST (session ~04:00-06:25)
**Work item:** TODO_LIST "Guard scrub-stop may be a PHANTOM … verify + make the guard cancel scrubs" (Source: `docs/status/2026-09-29_01-45_memory-guard-4-fixes-implemented-backup-starvation-catchup-slot.md` §e.2)
**Dispatch context:** third fire of this ID. Fire 1 (2026-09-29 ~22:59 session) landed the fix (`777fa972`); fire 2 (23:20, `e8b2f3af`) verified eval-only; fire 2b (04:50, verdict-corrected report) re-verified + updated docs and EXPLICITLY deferred the VM test to a quiet-IO window. This fire executed that deferred verification — and it found a real bug.

## Verdict

The landed fix is CORRECT and is now **proven by execution**: `checks.x86_64-linux.memory-emergency-guard` builds rc 0 ("test script finished in 33.02s", store output `dmp0x3l1xify…`), with scenarios 1-8 proving the trip stops the correctly-named `btrfs-scrub@-` instance, the unit's `ExecStop=btrfs-scrub-maybe-cancel` runs (marker file), the re-arm leaves the scrub dead with the disclosure line, and the churn forensics name the stopped instance.

## What this fire found and fixed

**The first-ever execution of the guard VM test was RED** at scenario 9 (backup catch-up slot, `AssertionError: the granted backup unit must leave the churn-stopped window`): the guard computed the `memory_emergency_guard_churn_units_stopped` metrics block BEFORE the catch-up grant block pruned the just-started backup unit from `churn-stopped`, so the grant run emitted a stale still-stopped `btrbk-root.service`. The scenario was authored 2026-09-28/29 and never executed (both prior reports confirm the VM leg was skipped), and `nix flake check --no-build` cannot see VM failures — a latent red that would have failed CI on the next VM-test run.

**Fix (smallest correct change):** moved the churn-window metrics computation to after BOTH mutation points (the re-arm clear and the catch-up grant prune) in `modules/nixos/services/memory-emergency-guard.nix`, with a comment naming the ordering constraint. Re-run: full VM test GREEN including all later scenarios (9b slot protection, 9c attribution, 10+). The script derivation rides daemon batch `9d9c17ea` (the module hunk in that commit is this fix).

## Verification evidence (this fire)

- Deployed `btrfs-scrub@.service` template read from the live store path: `Type=simple` + `ExecStop="…-btrfs-scrub-maybe-cancel" %f`; helper content read: `btrfs scrub cancel` + argv, rc=2 (no scrub running) tolerated. The AGENTS.md mechanism claim is accurate.
- Deployed guard script (`khzdgdihl…`) carries the three template instances in `CHURN_UNITS` and the `scrub_rearm_skipped` case-skip + disclosure line — the fix is LIVE on evo-x2 (trips #1463-1468 fired post-deploy under the new list; no scrub was running during those trips, so the cancel path's live proof is the VM test).
- `nix eval` of the edited module green (fresh script store path `nrfzpdx5…`).
- Full VM test green after the fix (above).

## Queue-surface closure

- `TODO_LIST.md`: the one-liner is ABSENT — pruned/removed by the parallel queue passes between 01:13 and 05:06 (the file's own terminal state for done items; the done-library-entry pairing holds). Nothing re-added: a done row must not persist in the queue.
- `docs/todo/stability.md` row 30: `[x]` DONE, now extended with the re-fire-3 execution evidence (VM green + the sibling ordering bug + fix commit).

## §f sweep scope statement (protocol clause b)

Scope: ITEM-DERIVED obligations of `…2026-09-29_01-45…md` §e.2 only. Its one direct follow-through (eval-time stray-unit lint) is already a `[ready]` row in `docs/todo/stability.md` (line 72). The §f table's other rows (f.1/f.2-3/f.4/f.9/f.11/f.12/f.17) were harvested by the prior fires and live as their own queue/library rows — not re-swept here. NEW follow-up harvested this fire: the "authored-but-never-executed VM scenarios" class → queue row + `docs/todo/pipeline.md` library entry (the guard test is the proof case: a scenario sat unexecuted for ~1 day and its first run was red).
