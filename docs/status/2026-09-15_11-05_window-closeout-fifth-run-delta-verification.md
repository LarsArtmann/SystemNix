# Window closeout — FIFTH run: delta verification of the IO-PSI / InvokeNamed window

**Date:** 2026-09-15 11:05 CEST
**Window:** 2026-09-14 00:56 → 02:59 (5 queue tasks, commits `695ffda8`/`1483bde0`/`5daa85cc`/`bc2d399c`/`449ef806` — all ABANDONED-lineage SHAs; reachable counterparts on HEAD: `638b91a3`/`75e76712`/`b34b5fc8`/`a03143ef`/`b481c047`, all five ancestry-verified 11:05)
**Run context:** this same window has now been closed out FIVE times (06:10, 07:32, 08:50, 10:45, this run). This report is a DELTA pass: fresh verification of every window claim against the current tree, plus what changed since the fourth run (10:45). No invented history; every claim below re-checked at write time.

## a) FULLY DONE (re-verified this run)

1. **All five window commits exist as reachable counterparts on HEAD.** `git merge-base --is-ancestor` green for `638b91a3` (gitleaks report correction), `75e76712` (InvokeNamed sweep), `b34b5fc8` (PSI/disk correlation), `a03143ef` (Zone 6 verify-only report), `b481c047` (cmdguard reviewer fix). Trees unchanged since the fourth run's verification.
2. **The InvokeNamed sweep conclusion stands: 17 repos, zero live traps** (sweep report + cmdguard row in `docs/status/archived/2026-09-14_01-41_task-000001a09d06…md`).
3. **The PSI/disk-correlation code is in the tree:** `scripts/deploy.sh` IO-PSI gate + `%util` classification, `node_disk_busy_percent_max` + `node_psi_io_phantom` in the psi-metrics/signoz modules (verified via grep + `f0e3c493`-counterpart diffstat; CHANGELOG 2026-09-14 entry present).
4. **Guard Zone 6 is in the tree and documented:** `memory-emergency-guard.nix:340` (threshold), `ioChurnUnits` option (:682), `zone6_trips_total` metrics (:539-541); AGENTS + FEATURES + CHANGELOG all carry it.
5. **TODO_LIST closure convention held:** the window's five items carry `[x]` DONE stamps; the 106 live status reports include the window's own task reports already archived under `docs/status/archived/2026-09-14_0*`.

## b) PARTIALLY DONE (carried, unchanged since run 4)

1. **Zone 6 verification probes still open:** VM-test re-execution, live `memory_emergency_guard_*` metric probe, deployed-generation parity (TODO items exist from run 1).
2. **The gitleaks message-rewrite is durably NOT landed:** `120ada36` (the fabricated "40-hex trips gitleaks" sentence) is **reachable on origin/master** (verified this run: `git merge-base --is-ancestor 120ada36 origin/master` → yes). The local `0ae59e3b` rewrite lineage stays abandoned; the sentence dies only at the held purge runbook's push-time re-filter or via key rotation. This matches the 07:32 regression finding; no further local message-only rewrites (doctrine recorded in TODO 07:32 section).
3. **Local == origin** (`origin/master` = `c7e8f9d1` = HEAD): the ~39-commit GH013 backlog push held; nothing of this window is unpushed.

## c) NOT STARTED (window scope boundaries, unchanged)

1. Repo-generic CI do-analyzer (provide/invoke pairing lint) — TODO item exists.
2. Zone 6 threshold recalibration against a first real trip — TODO item exists.
3. The owed evo-x2 reboot (flm :52626 corpse) — untouched, correctly; no queue item owns it.

## d) TOTALLY FUCKED UP (this run's dishonor roll)

1. **NEW REGRESSION (not this window's tasks — the parallel integration-registry work): `checks.x86_64-linux.wifi-failover` is RED right now.** Verified 11:05 via `nix eval .#checks.x86_64-linux.wifi-failover.drvPath`: `The option 'nodes.machine.services.integration' does not exist`. The wifi-failover module now declares a `services.integration` entry inside `mkIf cfg.enable` (the 2026-09-15 registry-migration P2 work), but `tests/test-wifi-failover.nix` does NOT co-import `modules/nixos/services/integration.nix` — exactly the AGENTS-documented trap ("the options?-guard does NOT survive an enclosing mkIf with enable=true: VM tests MUST co-import integration.nix"). Every pre-commit `nix flake check` leg is blocked by this until fixed. REPORTED, not fixed (hard scope rule). TODO item added.
2. **`tq facts` journal output is polluted with full `nix flake check` stderr** (derivation eval traces, stateVersion warnings — observed while reading the journal this run). A preflight hook leaks child-process stderr into the journal render; cosmetic but degrades the ADR-0015 audit trail. TODO item added (go-taskqueue side).
3. **Queue starvation continues:** the journal shows this closeout task claimed+requeued 4× between 10:49 and 10:55 ("repo has uncommitted changes") before the 11:04 claim — the dirty-tree lane problem from run 3's report persists (blocked owner decision already recorded).
4. **Closeout dedup gap, now five-fold:** the same window has five closeout reports. The blocked "dedup/claim/rate-limit repeated closeouts" owner question from run 4 covers it; this run complied with the queue rather than refusing, but the marginal value of runs 4→5 was small and the cost (reviewer noise, SHA-drift risk) is real.

## e) WHAT WE SHOULD IMPROVE

1. **Never cite pre-rebase SHAs in queue artifacts** — the window's task descriptions carry five dangling SHAs; every closeout run since has had to re-resolve counterparts. The "reachable SHAs only" TODO rule from run 3 should be enforced at ENQUEUE time (the queue's task text generator), not just in reports.
2. **VM-test authoring checklist needs the integration co-import line** — the registry migration landed module changes with test updates missing; a `nix flake check --keep-going` run BEFORE declaring the migration step done would have caught `wifi-failover` immediately.
3. **Preflight stderr hygiene in go-taskqueue** — capture child stderr to a file, reference it in the fact, never inline it into the journal stream.
4. **Delta-contract for repeated closeouts** — runs ≥2 of the same window should emit a short delta report (like this one), not a full re-closeout; the queue can signal "window already closed out N times" in the prompt.

## f) NEXT THINGS

(New items appended to TODO_LIST this run; existing open items from runs 1-4 are NOT restated here.)

1. Fix `checks.x86_64-linux.wifi-failover`: co-import `modules/nixos/services/integration.nix` in `tests/test-wifi-failover.nix` (verified red 2026-09-15 11:05).
2. Enumerate-and-fix any OTHER VM test enabling a module that declares `services.integration` (run `nix flake check --keep-going`, fix each missing co-import; the options?-guard does not survive mkIf).
3. Evaluate a mkIf-survivable shape for the `services.integration` registry fan-out so individual VM tests do not need the co-import at all (one design fix vs N test edits).
4. Verify the parallel session's nix-email work settled: `tests/test-nix-email.nix` green in flake check, flake.nix/flake.lock edits committed (daemon-committed 10:50-10:59).
5. go-taskqueue preflight: capture child-process stderr (the `tq facts` journal currently inlines full nix eval traces).

## g) QUESTIONS FOR THE OWNER

1. Redesign the `services.integration` declaration guard to survive an enclosing `mkIf` (repo-wide API change), or keep the co-import convention and patch each VM test? — BLOCKED: owner design decision.
2. Is the wifi-failover `services.integration` declaration settled on master, or still mid-flight from the registry-migration P2 session (should the co-import fix wait)? — BLOCKED: owner/owning-session confirmation.

## h) BAND DRIFT

`tq facts` (3,639 facts through 2026-09-15 11:04) contains **zero `task.reprioritized` facts** — none recorded. Priority movement this window happened only via the queue's own requeue churn (dirty-tree preflight refusals, claims 3629-3639), which is availability, not band drift.

---
*Point-in-time snapshot. Fifth closeout of the 2026-09-14 window; see also runs 1-4: `2026-09-15_06-10`, `_07-32`, `_08-50`, `_10-45`.*
