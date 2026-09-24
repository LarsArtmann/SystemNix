# Status: mr-sync go-floor unblock — three deploy attempts, zero activations

**Session:** 2026-09-24, ~11:00–12:08 CEST (diagnoses reach back to the 2026-09-23 22:14 deploy paste)
**Scope:** this session's work only — unblocking `nix run .#deploy` after `nix flake update mr-sync bank-sync branching-flow go-taskqueue`
**State at report time:** every build/gate blocker cleared and committed; the deploy itself has NOT been re-run. Four input bumps (mr-sync `6c1d3f6d`, bank-sync `2a286f47`, branching-flow `2fec285c`, go-taskqueue `e5c386e`) are still **not live**.

---

## Timeline (what actually happened)

| Time | Event |
| --- | --- |
| 09-23 ~21:5x | User ran `nix flake update mr-sync bank-sync branching-flow go-taskqueue` |
| 09-23 22:14 | Deploy attempt 1 — mr-sync package fails `go: updates to go.mod needed; to update it: go mod tidy` |
| 09-24 ~00:12 | This session fixed mr-sync `go.mod` (`go 1.27` → `go 1.27.1`); daemon committed upstream as `6c1d3f6d` |
| 09-24 ~11:0x | Deploy attempt 2 — dies building `pre-deploy-check` itself: shellcheck SC2034/SC2329 on the OB_* verdict callbacks |
| 09-24 11:19 | Deploy attempt 3 — mr-sync fails AGAIN with the identical error: build graph still on rev `26174a1e` |
| 09-24 11:4x | Root cause: the user's morning re-lock (→ `6c1d3f6d`) was silently reverted to `26174a1e` in the working tree (parallel-session/daemon race) |
| 09-24 11:58 | Re-locked to `6c1d3f6d`, verified package + toplevel build, lock committed by daemon (`5f9740c4`) |
| 09-24 12:08 | This report — tree clean, lock anchored, deploy awaiting a calm window |

---

## a) FULLY DONE

1. **mr-sync build failure root-caused and fixed upstream.**
   - Symptom: `mr-sync-<rev>.drv` fails in buildPhase with `go: updates to go.mod needed`.
   - Root cause: mr-sync's `go.mod` declared `go 1.27` while two pinned flake-input deps (`project-discovery-sdk`, `go-branded-id`, copied into the prepared source as directory replaces) declare `go 1.27.1`. Under `GOTOOLCHAIN=local` + readonly mode Go refuses to load the graph.
   - **The breakage was NOT new:** last successfully *built* mr-sync is `6996d9bb`; revs `905e61c`, `57ea030`, `3f1b097`, `26174a1e` were all equally unbuildable — the SystemNix lock had sat on unbuildable revs since the 3f1b097 lock move, and today's input bump merely forced the first rebuild that exposed it. The `ssetest` require added by a daemon commit was a red herring.
   - Why local `go mod tidy` reported "clean": the raw repo resolves those deps from the **Go proxy** (published tags with lower go floors); only the Nix prepared-source `replace => _local_deps/` trees surface the 1.27.1 floors — the documented "local tidy lies" class, now with a new variant (tidy-clean ≠ buildable; diff the *prepared* graph).
   - Fix: `mr-sync/go.mod` `go 1.27` → `go 1.27.1` (upstream rev `6c1d3f6d`, daemon-committed 00:12). Verified: `nix build .#mr-sync` from the fixed tree, then rebuilt from OUR lock (`4dipiwlk…-mr-sync-6c1d3f6d…`).
2. **Pre/post-deploy-check shellcheck failures fixed.**
   - Cause: a parallel session's offsite-borg-smoke lib extraction (09-23 evening) introduced verdict callbacks (`OB_PASS`/`OB_FAIL`/`OB_SKIP`, `ob_pre_skip`) that are invoked only via `"$OB_SKIP"` dispatch inside the sourced lib — shellcheck sees dead code and the `writeShellApplication` wrapper build fails. Wrapper builds are the FIRST thing that shellchecks those scripts → the failure surfaced as "deploy aborted — fix pre-deploy failures first".
   - Fix: `# shellcheck disable=SC2034` / `disable=SC2329` annotations per the repo's established pattern — `scripts/pre-deploy-check.sh:52-58` and `scripts/post-deploy-check.sh:166-168` (the post one would have failed the same way one step later). Both wrappers verified building (`nix build <drv>^out` green). All committed (tree clean at 12:08).
3. **flake.lock revert race diagnosed and repaired.**
   - The user's morning `nix flake lock --update-input mr-sync` (output: `26174a1e → 6c1d3f6d`) was silently clobbered back to `26174a1e` in the working tree before the 11:19 deploy — last lock-touching commit was 09-23 22:13, working tree matched it, so attempt 3 rebuilt the broken rev from the identical drv.
   - Re-locked (`nix flake update mr-sync`), lock now at `6c1d3f6d` **and committed** (`5f9740c4`, 11:58) — anchored against another working-tree revert.
4. **Verification chain from our lock:** mr-sync package builds; `evo-x2` toplevel evaluates (`gyndiv0g…-nixos-system-…6774f7b.drv`).

## b) PARTIALLY DONE

1. **The deploy.** Three attempts, three distinct blockers (mr-sync go floor → check-script shellcheck → lock revert), all cleared — but **I did not re-run it** (deliberate: I/O PSI 62% with idle disks, guard tripped 2×/last hour, both pressure gates overridable only by force; freeze #5/#6 doctrine). Someone must fire it in a sane window.
2. **Race containment, not race prevention.** The lock is committed now, but the writer of the revert was never identified (candidates: the 22:13 session, the 07:12 "shellcheck proof" session, a formatter re-lock, or the daemon). Nothing structural stops a recurrence.
3. **mr-sync dashboard cutover** — new binary proven buildable; not deployed, so `mr-sync.home.lan` still runs the `6996d9bb`-era binary.

## c) NOT STARTED

1. **btrbk-data, btrbk-root, btrfs-verify-pool-backups are now FAILED** — attempt 3's pre-check listed 5 failed units vs 2 in attempt 1. The three new ones smell like Zone-6 guard-killed btrbk sends mid-storm (interrupted-receive garble; `btrbk-pool-clean` heal class) — completely undiagnosed, only noticed.
2. **inboxclean-sync failure** (pre-existing in both attempts, plus `service-health-check` which just reports it).
3. **The owed reboot decision** — corpse-pile signature got *worse* across attempts (I/O PSI 51→62% with idle disks, guard trips 1→2/h, flm EADDRINUSE corpse: "only a reboot clears", flm backend already stopped by the guard).
4. **cv :8098 metrics not responding** (both attempts) — unverified whether this is the known auth-gated WARN branch or a new gap.
5. **Root fs creep 87% → 88%** (95G → 89G free) between attempts — noticed, not acted on.

## d) TOTALLY FUCKED UP

1. **Attempt 3 was a wasted deploy cycle caused by my handoff.** After attempt 1 I told the user "re-lock + deploy" with no lock-state verification step; the revert race silently invalidated the re-lock and the user burned ~25 minutes on a deploy that was guaranteed to fail identically. The "verify `jq '.nodes["mr-sync"].locked.rev'` before deploying" advice existed in my head and only reached the user AFTER the damage.
2. **Red-herring detour in attempt 1:** I chased the `ssetest` require / go.sum delta before running the prepared-source `tidy -diff` that pinned the real cause in one command. Two tool calls of chasing the wrong diff.
3. **Toolchain assumption:** my first local tidy probe ran go 1.26.7 against a `go 1.27` floor and initially looked like the nix error — wrong environment, one wasted probe.
4. **jq syntax slip:** `.nodes.mr-sync.locked.rev` parses as subtraction (`sync/0` not defined) — hyphenated keys need `["mr-sync"]`. One wasted probe, corrected in place.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy-time-only shellcheck is too late.** The check scripts only get shellchecked when their `writeShellApplication` wrapper BUILDS — i.e., during a deploy. A parallel session already added/proved pre-commit shellcheck coverage for `scripts/*.sh` this morning (07:12, `e55c4d7d`) — the OB_* lines slipped in before that landed. Belt: also add pre/post-deploy-check wrapper builds to `checks` so `nix flake check` fails on the class.
2. **Assert lock state inside the deploy path.** A pre-deploy §0 that records `flake.lock` input revs and diffs them against the previous run (or simply `git diff --exit-code flake.lock` awareness) would have turned attempt 3's cryptic "same error again" into "lock reverted since last attempt". The revert class cost a full cycle.
3. **Go-floor waves must bump consumers.** Family deps moved to `go 1.27.1` floors; mr-sync's own `go` directive lagged and ONLY the Nix prepared graph caught it (local tidy stays clean). The dep-sweep/PMA wave policy should bump every consumer's main-module `go` line in the same wave — otherwise each consumer eats a broken-lock window discovered only at the next forced rebuild.
4. **Check for live parallel sessions before blaming the daemon.** At least three sessions touched this repo in 14 hours (22:13 lock mover, 07:12/07:38 shellcheck/tq session, this one). The race doctrine exists; I invoked it late.
5. **Pre-deploy §6 should DIFF failed units, not list them.** 2 → 5 failed units between runs was the loudest signal in the output (btrbk regressions) and it scrolled past unremarked by the gate itself.

## f) NEXT (prioritized, session-derived)

1. Re-run `nix run .#deploy` in a calm window (or forced, owner's call) — four input bumps pending.
2. After deploy: verify profile anchoring (`readlink /run/current-system` == `/nix/var/nix/profiles/system`) given the exit-4 history on this box.
3. Post-deploy smokes: mr-sync-dashboard serves `6c1d3f6d`, tq `0.3.1`, bank-sync `2a286f47`, branching-flow `2fec285c`.
4. Decide + execute the **owed reboot** (run `nix run .#pre-reboot-check` first); expect it to clear the D-state corpse pile, the flm :52626 corpse, and the phantom I/O PSI.
5. Diagnose btrbk-data / btrbk-root / btrfs-verify-pool-backups failures (check for guard-killed mid-receive garble → `btrbk-pool-clean` heal; check `/mnt/pool` freshness rows).
6. Diagnose inboxclean-sync (exit class unknown; check the invalid_grant/re-auth classes first).
7. Verify cv :8098 metrics-absent is the known auth-gated WARN branch, not a new gap.
8. Add pre/post-deploy-check wrapper builds to flake `checks` (shellcheck class caught by `nix flake check`).
9. Add a lock-rev assertion / diff to `scripts/deploy.sh` (attempt-3 class).
10. Ecosystem: sweep LarsArtmann consumer repos for `go 1.27` main-module directives < their pinned deps' floors (mr-sync class) — library-policy, PMA, crush-daily, overview, etc.
11. Update AGENTS.md (mr-sync section + Nix gotchas) with: the go-directive-floor variant of "local tidy lies" and the 2026-09-24 lock-revert instance.
12. Pre-deploy §6: emit a failed-units DELTA vs the previous run.
13. Root fs usage: 88% and climbing during builds — check btrbk retention interplay before it gates a deploy at 95%.
14. Verify hermes in-flight sessions drained cleanly on the deploy restart (attempt 3 warned "3 lines in last 10 min").
15. Confirm the architecture-catalog metric loan (`architecture_catalog_fresh`/`scrape_errors`) retires itself post-deploy.
16. If the lock reverts AGAIN: identify the writer (audit parallel sessions / daemon logs) before re-locking a third time.
17. Consider a `git town`/session-ownership convention for flake.lock edits (pathspec commits already doctrine; lock edits are the hottest shared file).

## g) QUESTIONS (cannot resolve myself)

1. **Reboot:** may I schedule/perform the owed reboot once the deploy lands (it will drain hermes/in-flight sessions)? Now, post-deploy, or you pick the window?
2. **Ownership:** are the btrbk×2 / btrfs-verify / inboxclean-sync failures mine to diagnose next, or does a parallel session/tq task (e.g. the 07:38 `000001a0…` shellcheck item session) already own them?
3. **Deploy execution:** do you want ME to fire `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` now despite the guard-trip/PSI warnings, or will you run it manually in a calmer window (the freeze #5/#6 doctrine argues against racing the storm)?

---

**Bottom line:** all three blockers (go floor, shellcheck, lock race) are fixed, committed, and verified from the lock; nothing is deployed yet; the box itself (corpse pile, failing btrbk trio, climbing PSI) is the bigger open front.

*Reported by: crush session 2026-09-24 12:08 CEST — waiting for instructions.*
