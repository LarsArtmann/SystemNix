# Window closeout — IO-PSI guard tier, PSI/disk correlation, InvokeNamed sweep, two reviewer-fix loops

**Date:** 2026-09-15 06:10 CEST
**Window:** 2026-09-13 ~23:00 → 2026-09-14 03:00 (5 queue tasks, all `status=completed` in the tq journal)
**Method:** every claim below verified against `git show`, the tq journal (`tq facts`), and the code tree. No invented history.

## The window's tasks

| Task | What it was | Commit | Verified outcome |
| --- | --- | --- | --- |
| 000001a09ceb… | Reviewer finding (high): the gitleaks commit-message rewrite (`8e8be78c`) never landed on branch history; the fabricated-gitleaks commit `120ada36` was still reachable; the status report claimed otherwise | `695ffda8` | Re-performed as a `git filter-branch --msg-filter` message-only rewrite; ~~amended commit `0ae59e3b` IS an ancestor of HEAD~~ **REGRESSED 2026-09-15: the unpushed rewrite lineage was abandoned by rebases onto origin/master — `0ae59e3b` NOT an ancestor, `120ada36` reachable again (verified in the 07:32 re-run report)**; report carries an inline CORRECTION block plus corrected §-claims and verification transcript. Reachable counterpart: `638b91a3` |
| 000001a09d06… | Sweep ALL LarsArtmann Go repos for `InvokeNamed[interface]` on concrete `do` registrations (the DiscordSync 2-day crash-loop class) | `1483bde0` | 16-repo sweep report; ZERO live traps; only historical instance (DiscordSync) already fixed upstream `085fa539` |
| 000001a09d2b… | IO-PSI phantom-saturation by D-state tasks on dead automounts — deploy gate + gatus can lie (crash3) | `5daa85cc` | Code landed via the auto-commit daemon (`f0e3c493`); verified in tree: `scripts/deploy.sh` reads IO PSI some avg10 ≥20% and correlates with max per-disk `%util`; psi-metrics emits `node_disk_busy_percent_max` + `node_psi_io_phantom`; Gatus I/O Stall Rate alerts real saturation only (`_signoz-metrics.nix`, `gatus-config.nix`) |
| 000001a09d4250c0… | IO-PSI emergency guard tier (Zone 6) for the freeze #3/#4 class | `bc2d399c` | Work was ALREADY complete on arrival (parallel queue run): `memory-emergency-guard.nix` carries `ioPsiSomeAvg60ThresholdPercent` (40%), io_ticks-delta corroboration, `ioChurnUnits` stop-list, `zone6_trips_total` metric (verified at `modules/nixos/services/memory-emergency-guard.nix:340,591-593,670`). This task's run was an honest verification-only pass; zero code authored, correctly |
| 000001a09d42534b… | Reviewer finding (low): sweep report omitted cmdguard; repo count wrong (16 vs 17) | `449ef806` | cmdguard row added with the clean passthrough verdict (`pkg/cmdguard/v4/scope.go:194`, same-T provide/invoke); count corrected to 17; conclusion unchanged |

## a) FULLY DONE

1. **The fabricated-gitleaks sentence is gone from reachable history.** The first fix attempt (reviewer finding against `120ada36`) had "landed" `8e8be78c` on a SIBLING lineage — a false status-report claim the next reviewer caught. The window's fix (`695ffda8`) re-performed the message-only rewrite (`0ae59e3b`, ancestry-verified), deleted the `refs/original` backup, repointed `origin/master`, and corrected the report inline. Trees byte-identical; strictly message-only. **REGRESSED 2026-09-15 07:32 (re-run):** the rewrite was never pushed and did not survive — the 09-14 10:00 rebase onto origin/master plus the 09-15 04:11/05:08 rebases re-anchored master on the old lineage; `0ae59e3b` is NOT an ancestor of HEAD and `120ada36` is reachable again. The SHAs cited in this report's table (`695ffda8`, `1483bde0`, `5daa85cc`, `bc2d399c`, `449ef806`) are abandoned-lineage copies — reachable counterparts: `638b91a3`/`75e76712`/`b34b5fc8`/`a03143ef`/`b481c047`. See `2026-09-15_07-32_window-closeout-rerun-gitleaks-rewrite-regression.md` §d.1.
2. **The `InvokeNamed[interface]` sweep is complete and honest: 17 repos, zero live traps.** Cross-checked every call site against its registration's type parameter. DiscordSync remains the only historical instance, fixed upstream with a regression test. Reviewer's completeness finding (cmdguard) cured same window.
3. **The deploy pressure gate now reads IO PSI and classifies phantoms** (crash3 class closed): exit-12 gate on some avg10 ≥ 20% + per-disk `%util` correlation; D-state corpse-pile signature prints its top processes instead of reading as a real storm; gatus "I/O Stall Rate" fires only with disk corroboration. Verified present in `scripts/deploy.sh` and the psi/gatus modules.
4. **Zone 6 exists and is correctly documented** in the guard, the CHANGELOG, and AGENTS.md (the freeze #3/#4 io-PSI trip tier with churn-source stops, never-restarted, btrbk-pool-clean heals interrupted receives).
5. **All five tasks closed in TODO_LIST per convention** (`[x]` + DONE stamps + source pointers), and all five queue tasks are `status=completed` in the tq journal.

## b) PARTIALLY DONE

1. **Zone 6 verification gaps (the window's own report names them):** the verify-only run confirmed code existence + `nix flake check --no-build` green, but did NOT (a) rebuild the guard VM test in isolation, (b) probe the three new `memory_emergency_guard_*` metrics against the RUNNING textfile, (c) confirm deployed-generation parity on evo-x2. "Fix exists in git" and "fix protects the machine" are different done-states — all three probes are queued (see TODO_LIST additions).
2. **Provenance split-brain on the PSI fix:** the actual code rode an unlabeled auto-commit daemon commit (`f0e3c493`) while the footer-carrying commit (`5daa85cc`) closed only the TODO item. `git log --grep Task-Queue-ID` cannot find the code change for this task. Systemic, not fixed here.

## c) NOT STARTED (deliberately out of scope this window)

1. **Repo-generic CI do-analyzer** (provide/invoke type-parameter pairing across all Go repos) — named in the sweep report as future hardening, explicitly not done. Branching-flow's local analyzer covers only that repo.
2. **Zone 6 threshold recalibration** against the first real trip (40% avg60 / 20% disk-busy are first values; the crash3 §f.15 discipline demands calibration against actual incident telemetry).
3. **`memory_emergency_guard_zone6_churn_units_stopped`** forensics metric — not proposed in code, only in this window's report §f.22.
4. The still-owed evo-x2 reboot (flm :52626 corpse) — untouched, correctly; no queue item owned it.

## d) TOTALLY FUCKED UP

Nothing in this window broke gates or lost data. The honest dishonor roll:

1. **The false "clean rebase landed" claim (worst of the window).** The earlier fix session wrote a status report asserting `8e8be78c` was on branch history without running `git merge-base --is-ancestor` — the exact verify-your-own-work failure this repo's doctrine hammers. It took a reviewer finding + a second fix task to make reachable history match the report. Rule re-earned: a status report about git state MUST include the ancestry/verification transcript at write time.
2. **A fabricated gitleaks justification sat in a public commit message** (`120ada36` claimed a 40-char hex SHA trips gitleaks' sourcegraph rule — empirically false). One docs-only justification cannot be amended in place, so it took a filter-branch message rewrite. Root cause: inventing a plausible-sounding gate rationale instead of citing the real one.
3. **Two of five tasks needed reviewer rejection loops** for preventable slips (wrong repo count 16 vs 17; the false-rebase claim). The reviewer layer works, but both findings were catchable by a 30-second self-check.
4. **Meaningful code keeps landing in unlabeled daemon commits** (the PSI fix in `f0e3c493`), burying provenance under "heuristic" noise (see b.2).
5. **Pre-existing red inherited by the window:** `checks.x86_64-linux.cv` blocked the flake-check hook leg, so every docs commit ran `--no-verify` (documented precedent `73145250`). FIXED 2026-09-14 (CV_OIDC_CLIENT_SECRET fixture) per AGENTS.md — noted here because it colored the whole window's commit hygiene.

## e) WHAT WE SHOULD IMPROVE

1. **Ancestry-check discipline for any git-state claim:** `git merge-base --is-ancestor <sha> HEAD` (and `git log --all --grep`) belong in the report's verification transcript, not in a reviewer's finding.
2. **Never invent a tool's behavior as justification** (the gitleaks fabrication): run the tool on the input before claiming what it does.
3. **DONE stamps should carry the completing Task-Queue-ID** so verifying sessions skip daemon-commit archaeology.
4. **Queue-level work claiming:** two runs hit the same Zone 6 item within hours; a `TQ_CLAIMED` marker (or tq in-progress state surfaced to harvest) would dedupe.
5. **Verification-only runs should standardize a 3-step probe** — code exists, regression test executed, deployed-generation parity — and record which steps were skipped and why.
6. **AGENTS.md module-location sketch drift** cost the Zone-6 verify run a wrong-first-path tool call; reglob-verify location docs on touch.

## f) NEXT THINGS

Fed into TODO_LIST (see appended items): deployed-state verification of Zone 6, metric-liveness probe, isolated VM-test rebuild, counter-reset tolerance, SigNoz dashboard panels, trip-tier routing check, runbook entry, gate/guard division-of-labor doc, backup-staleness tripwire while btrbk is guard-stopped, scrub "deferred vs wedged" distinction, churn-units-stopped forensics metric, the do-analyzer CI hardening, plus the process items (Task-Queue-ID in DONE stamps, queue claiming, provenance convention).

## g) QUESTIONS FOR THE OWNER

1. Should verification-only runs mint an empty commit carrying the Task-Queue footer (queue `commit_sha` always resolves), or is "no commit + honest TQ_RESULT" the preferred contract?
2. Adopt "DONE-stamped TODO items carry the completing task's Task-Queue-ID" as a repo convention (and ask go-taskqueue for a daemon footer convention so auto-commits stay greppable)?
3. Zone 6 rides the next deploy — authorize a deploy + post-deploy metric probe now, or hold for the /nix soak window (~2026-09-17) alongside `crush-hot-db`?

## h) BAND DRIFT

`tq facts` over the window's timespan contains **no `task.reprioritized` facts** — none recorded. The only priority movement in the journal window was task lifecycle churn (claims/failures/dead-letters), not re-prioritization.

---
Task-Queue-ID: 000001a0a1f149f8469390a3b300fddf0914
