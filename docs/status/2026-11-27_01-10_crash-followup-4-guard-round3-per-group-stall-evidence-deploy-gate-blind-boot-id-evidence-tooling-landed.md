# Crash follow-up, session 4 (2026-11-26 17:27 to 2026-11-27 01:20): the guard pauses only what is itself I/O-stalled, two blind gates see zone-6 trips again, the per-boot trip count gets a real boot identity, and the evidence tools say what they measured

Working session after `docs/status/2026-11-26_17-13_crash-followup-3-guard-vm-green-host-build-broken-live-pauses-froze-nix-daemon-sshd-monitors.md` (owner: "go and improve things", then "execute and verify one step at a time until everything works"). Same boot `0737ecd7` all session. Nothing was deployed: generation 1032 is still live and still runs the pre-fix guard.

## Scope line

Tree at report time: `551f11b54` (`git rev-parse --short HEAD`, 2026-11-27 01:18 CET). On top of it, uncommitted and waiting for the auto-commit daemon: `AGENTS.md`, `CHANGELOG.md`, `FEATURES.md`, `TODO_LIST.md`, `docs/agents/stability.md`, `docs/services/kdump-capture-path.md`, `docs/services/memory-emergency-guard.md`, the two `docs/status/tasks/2026-11-25_10-22_boot-*-evidence-pull.md` files, `docs/todo/{pipeline,stability,storage}.md`, `flake/parts/checks/selftests.nix` (unstaged half), `scripts/boot-evidence-pull.sh`, `scripts/crash-triage.sh`, `scripts/guard-sim.sh`, `scripts/lib/pstore-records.sh`. I committed nothing; the commits that carry my earlier edits are heuristic daemon commits (`e0913aef8` guard port, `513b96fdc` deploy gate, `c6b046702` crash triage, `4a62be45e` guard runbook). Running generation: `/nix/store/zm83sr9716xb1372iw2135p85nszfbl6-nixos-system-evo-x2-26.11.20261121.2786a2a` = `system-1032-link`, guard script `/nix/store/8pyscx087qqdlzhf4s8akj9sc32rfj5a-memory-emergency-guard-check`.

**Verified here (command and artifact, all under `~/.cache/freeze-triage-20261125/`):**

- VM suite on the round-3 guard (worktree `wt-dstate` at `982934d0a` plus the three ported files): `nix build --no-link .#checks.x86_64-linux.memory-emergency-guard -L`, exit 0, test script 114.65 s (`guard-vm-run5.log`). In the shared tree the same derivation was already in the store (11 s, no re-execution).
- `nix run .#guard-sim -- test` and `-- host`: 14 of 14 IO-PAUSE scenarios pass on both built shapes; `-- --units test|host`: 4 of 4 unit-call legs on both; `-- --live` (the script that runs right now): 6 pass, 8 fail (`guard-sim-app-{test,host,live}.out`, `guard-sim-units-{test,host}.out`).
- Reader control: `vanishservice` fails 3 of 3 on the live script ("no live headless process": the fixture is lost from the process map) and passes 5 of 5 plus 3 of 3 on the new builds (`work/sim-live*-vanishservice.out`, `work/sim-new*-{vanishservice,vanishscope}.out`).
- Eight guard checks built in the shared tree, exit 0 (`selftests-shared.log`): the four source anchors, three new ones, the host-shape build. `deploy-pipeline-selftest` (83 assertions), `crash-triage-selftest`, `boot-evidence-pull-selftest`, `pstore-records-selftest` built and green after the ports (`evidence-selftests-shared.log`).
- Mutation controls: 7 of 7 for the four guard anchor checks (`s3/neg-selftests.sh`), 3 of 3 for crash-triage (trip pattern, verdict for the running boot, failed read reported as none), 1 for the deploy gate (inside its selftest).
- Host proof in a worktree at `708573735` plus my eval-relevant files (`wt-ship`): evo-x2 toplevel build exit 0 in 1 min 13 s (`ship-toplevel-build.log`); `nix flake check --no-build --all-systems` "all checks passed", 9 min 7 s (`ship-flake-check.log`).
- Measurements: `s3/boot-epoch-probe.out` (22 of 40 samples differ from the stored boot epoch; stored baseline equals the lifetime counter 13535), `s3/sync-probe-1.out` (`sync -f` 353, 11, 6 ms against `sync FILE` 5, 5, 5 ms; strace shows syncfs against fsync), `s3/guard-correl2.out` (trip runs: median 29.7 MB written, p90 53.3 MB, max 543.1 MB, 86.71 GB in 2,668 runs; quiet runs: 0 MB), `s3/ch-control-2boots.out` (positive-control windows of both crashed boots), deploy logs (411 times "no guard trips in the last 60 min" against 0 `action taken` lines in 2,679 zone-6 trips).
- Live runs, read-only: `scripts/crash-triage.sh --boots 6` (`kdump=` on every boot line), `scripts/boot-evidence-pull.sh -b -1 -o -` (`bep-live-min1.out`: verdict `alive-behind`, 22 pstore records, `kdump: capture FAILED`, panic census 0).
- TODO gate after the harvest: `OK: TODO queue/library structure clean`, same WARN counts as before (`s3/todo-gate-{before,after}.out`); both new queue rows pair with their library entries (`scripts/tick-todo-rows.sh` dry run).
- `scripts/pre-vacuum-evidence-gate.sh`: pass, every boot still on disk has committed evidence (`s3/pre-vacuum-gate.out`).

**NOT verified here:**

- The round-3 guard has never run under the hardened unit on the host, and never in a real storm. The stall bar (a thread in D state in a quarter of the passes) was exercised with stand-ins only; whether real stalled writers cross it on this box is unproven.
- `sync "$PAUSE_FILE" "/var/lib/memory-emergency-guard"` (file plus directory) ran in the VM as plain root; under `harden{}` it was not exercised.
- The VM suite was not re-executed after HEAD moved past `982934d0a` with other sessions' commits; the shipping-candidate flake check covers their eval, not a new VM run.
- The `kdump-save` journal lines that `scripts/boot-evidence-pull.sh` matches come from the module source; no capture boot has ever produced one on this host.
- The 20 mutation controls of the evidence-script work are the subagent's run (`evidence/neg-controls.txt`); I re-ran the selftests and the live reads myself, not the mutations.
- The subagent's and my own scratch under `~/.cache/freeze-triage-20261125/` was partly left in place (worktrees `wt-dstate`, `wt-evidence`, `wt-ship` are removed; logs stay).
- Nothing was deployed, rebooted or crash-tested.

## TL;DR

1. **The guard fix is in the tree and verified six ways.** A process group is paused only with its own stall evidence inside a scope or a multi-group cgroup; the readers no longer truncate; the cap counts groups; each trip fsyncs its state instead of flushing the root filesystem; a memory trip no longer re-arms the units it just stopped; the per-boot trip count keys on the kernel boot id. VM green, 36 sim runs green on both shapes, the live script fails 8 of the same scenarios.
2. **The live guard kept doing damage while I worked.** 18:52 and 23:39 it froze the nix-daemon listener again (48 to 60 minutes each, every nix command on the box hung, including my own builds); 17:23, 18:27, 23:27 and 23:51 it froze login-scope bystanders again; 23:37 it took 13 groups of `system-health-metrics.service`. I released the listener, five idle workers and one sshd monitor by hand at 17:45 (sudo `kill -CONT`, build trees left paused).
3. **Two gates had been blind since 2026-10-28.** With `ioPause` on, a zone-6 trip logs no `action taken` line: the deploy gate and the crash census counted 0 of 2,679 trips in nine days. Both fixed and fixture-tested. Consequence: a deploy inside a trip-recent window is refused again and needs `DEPLOY_FORCE_PRESSURE=2`.
4. **The per-boot trip count never worked.** "Now minus uptime" flips between two values inside one boot; the baseline re-snapshotted on most runs and `trips_this_boot` read 0 through a boot with about 300 trips, so `load_bearing` and the per-boot storm latch could not fire.
5. **The evidence tools tell the truth now.** `crash-triage.sh` prints `kdump=` and `throttle_episodes`; `boot-evidence-pull.sh` decides `alive-fresher`, `alive-behind` or `dark` from a control window, counts only real crash signatures, renders the pstore section, and no longer leaks scratch. The "PIPELINE DARK" line in two committed evidence files was false (the tail was 10.1 s and 7.6 s behind the cut); both files carry a measured annotation.
6. **Not deployed.** The deploy gates need the owner's explicit token (pressure and trips), and that decision is not mine to take at night.

## 1. What the live guard did during this session

| Time | Trip | Paused | Released |
| ---- | ---- | ------ | -------- |
| 17:16:23 | #13531 | 9 groups, all in `system.slice/nix-daemon.service`: the listener (pgid 2970), 5 workers, 3 build trees | 17:45:04 by hand (listener, workers, sshd monitor); 18:15:52 hard cap |
| 17:23:26 | #13534 | pgid 3760051 `session-1653.scope` (the sshd-session monitor of that login) | 17:45:04 by hand |
| 18:27:29 | #13539 | pgid 2320493 `session-2120.scope` | 19:27:24 hard cap |
| 18:52:57 | #13542 | 10 groups incl. pgid 2970 again | 19:27:24 hard cap |
| 23:27:32 | #13569 | pgid 417936 `session-3487.scope` | 00:27:53 hard cap (one release for the four pauses below and this one) |
| 23:37:07 | #13572 | 13 groups in `system-health-metrics.service` | 00:27:53 hard cap |
| 23:39:48 | #13573 | 16 groups incl. pgid 2970 and 15 more in `nix-daemon.service` | 00:27:53 hard cap |
| 23:51:56 | #13575 | pgid 324416 `session-48.scope` | 00:27:53 hard cap |

The hard cap counts from the oldest entry of the pause file, so groups paused 25 minutes into a storm were released after 35 minutes, not 60.

## 2. What changed in the guard (in tree, not live)

| Change | Evidence |
| ------ | -------- |
| Stall evidence by structure: a `*.scope`, and any cgroup holding several process groups, needs per-group evidence (a thread in D state in at least a quarter of the passes of the sample window); a service holding exactly one group keeps the cgroup's bytes as evidence | VM legs b2, b3, b4; sim `scopetrick`, `scopedriver`, `sshshape`, `svcshape` |
| Readers: `find -print0` and one awk opening by `getline` for the cgroup walk, the process scan and the new thread-state pass | sim `vanishservice`, `vanishscope`; control against the live script |
| The cap counts process groups | VM leg b5 (9 stalled groups: 8 paused, the ninth named); sim `capshape` |
| `sync FILE` (fsync) instead of `sync -f` (syncfs) on the trip, zone and pause state | `guard-trip-persist-selftest`, strace |
| A churn stop holds for one IO action cooldown (150 s); `GUARD CHURN-REARM HELD` while it is young | VM 8a; unit leg `trip_restore_rearm` |
| Boot identity is `/proc/sys/kernel/random/boot_id` (`BOOT_ID_SRC` seam) | VM 6a-lb; `guard-boot-id-selftest` |
| New checks: `guard-reader-shape-selftest`, `guard-stall-evidence-selftest`, `guard-boot-id-selftest`; `guard-trip-persist-selftest` repaired (its log anchor matched a comment since 2026-11-26 12:30, the check had been red unnoticed) | `selftests-shared.log` |
| New app `nix run .#guard-sim` (`scripts/guard-sim.sh`): 14 IO-PAUSE scenarios and 4 unit-call legs, `test`, `host`, `--live`, `--guard` | app runs above |

## 3. The two blind gates

`scripts/deploy.sh` (trip-recency gate) and `scripts/crash-triage.sh` counted `MEMORY EMERGENCY action taken` only. With `ioPause` on (evo-x2 since the 2026-10-28 split) a zone-6 trip logs `IO-PAUSE (trip #N, zone 6)` and no `action taken` line: 0 such lines against 2,679 zone-6 trips in nine days of guard journal, and 411 deploy logs printed "OK (no guard trips in the last 60 min)". Both count both shapes now; `crash-triage.sh` also counts the observe-only wording of a memory trip (a third blind spot, mine since 2026-11-26 06:16). A sibling session's deploy at 23:28 still passed the old gate ("no guard trips", 4 minutes after trip #13569).

## 4. Evidence tooling

- `scripts/crash-triage.sh`: `kdump=` per boot (decoded by `scripts/lib/pstore-records.sh`, read from the next boot), `throttle_episodes` beside the deep-cap applications, an unreadable journal is flagged and never read as "none", default window is the six boots the stability doc names. Live: `capture-kernel-OOM` for `3aa71817`, `a95832c5`, `b4931451`, `8b31b428`; `none` for `27ec3ede`.
- `scripts/boot-evidence-pull.sh` and the library (written by a helper session in an isolated worktree, reviewed and ported by me): positive-control window of 600 s before the cut and the three verdicts; panic census limited to real crash signatures (the old one counted 4 benign lines on every boot); pstore section with the kdump capture line; `gaps=` empty when there are no records; a scratch leak closed (every successful pull left three files behind).
- Both crashed boots of 2026-11-25 measured: control window 11,154 and 9,958 rows, newest row 10.1 s and 7.6 s before the cut, pipeline emitting again 0.14 s after the next boot began.

## a) FULLY DONE

| Item | Evidence |
| ---- | -------- |
| Guard round 3 (seven changes of section 2) | VM run 5, sims, unit legs, eight checks |
| Port into the shared tree, byte-identical to the verified worktree | `cmp` on the three files |
| deploy gate and crash census count zone-6 trips | `deploy-pipeline-selftest` 83 assertions; `crash-triage-selftest`; controls |
| crash-triage: `kdump=`, `throttle_episodes`, library shipped into the sandbox | selftest with three mutation controls |
| Evidence pull: control window and verdicts, pstore section, panic census, `gaps`, scratch leak; library selftest | both selftests green in the shared tree; live pull of boot -1 |
| The two evidence files annotated with measured controls | appended sections |
| `guard-sim` app with both harnesses | app runs on both shapes and against the live script |
| Docs: guard runbook, `docs/agents/stability.md` (lessons, SIGSTOP rule, census shapes), AGENTS routing rows, kdump doc, FEATURES, CHANGELOG | committed or in the working tree |
| Harvest of the 00:36, 07:12 and 17:13 lists and of this session's follow-ups | `TODO_LIST.md`, `docs/todo/{stability,pipeline,storage}.md`; gate clean |
| Host proof: toplevel build and `nix flake check --no-build --all-systems` on the candidate tree | `ship-*.log` |

## b) PARTIALLY DONE

| Item | Works now | Open |
| ---- | --------- | ---- |
| Live hazard | fix in tree, six-way verified | not deployed: the gates refuse under the standing phantom pressure and the trip cadence |
| Guard VM coverage | legs b2 to b5, 8a held re-arm, 6a-lb on the boot id | no VM leg for the evo-x2 shape, no real-cgroup pause (queue row) |
| `load_bearing` | identity fixed | the running boot's baseline snapshots at the first run after the deploy and reads 0 for this boot |
| Evidence scripts | verdicts, pstore section, census | post-deploy section 26 has no fixture test (queue row); `kdump-save` journal identifier unobserved |

## c) NOT STARTED

- Deploy, ghostty window restarts, reboot, deliberate crash (owner).
- The decisions of section f.

## d) TOTALLY FUCKED UP

System level:

| # | What | Severity | State |
| - | ---- | -------- | ----- |
| 1 | The live guard froze the nix-daemon listener twice more (18:52, 23:39) and four more login bystanders | High: every nix command on the box hung for 48 to 60 minutes, mine included | fixed in tree, not deployed |
| 2 | The deploy gate's trip-recency leg saw no zone-6 trip for four weeks | High: every deploy into an IO storm passed that leg | fixed in tree, not live for deploys started before it |
| 3 | `trips_this_boot`, `load_bearing` and the per-boot storm latch never fired since 2026-10-25 | Medium: a load-bearing signal that reads 0 | fixed in tree |
| 4 | Each trip flushed the whole root filesystem | Medium: 87 GB of writes in nine days, walls up to 268 s | fixed in tree |
| 5 | `flake/parts/checks/selftests.nix` did not parse between 17:20 and 18:02 (`if ... then ... ''; else`), every flake eval failed for every session | High while it lasted | fixed by a sibling session (`982934d0a`); not mine, cost me one failed build |
| 6 | The deploy gate refuses the deploy that would end the phantom pressure, because of the phantom pressure | Structural | question 1 |

My own errors, in order of cost:

| # | Error | Cost | Fix forward |
| - | ----- | ---- | ----------- |
| 1 | I wired a flake app to a script before the script was tracked; a sibling's commit hook was running its flake check on the same tree | about 6 minutes in which any eval forcing `apps` failed for everyone | park the reference, `git add -N` the file, then wire; recorded in `docs/agents/stability.md` |
| 2 | A mis-indented loop in a patch helper wrote the helper's own source over the worktree's `selftests.nix` | a restore and a re-apply, private worktree only | write to the file that was read, in the same iteration |
| 3 | A `''` inside a Nix string (`'' | *[!0-9]*`) made the worktree module unparseable for a minute | none outside the worktree | never write two quotes inside a Nix indented string |
| 4 | My first vanish control was vacuous (every vanisher was dead before the guard read) and the harness had no exit trap, so failed runs left stopped sleepers and writers behind | an hour | time the deaths into the read window, trap the cleanup |
| 5 | A broken one-liner left a `sleep 300` behind and reported a job id where I expected a pid | minutes | harness code goes into script files, never one-liners |
| 6 | I read "6 passed" on the live script as expected without checking which six | none | the eight failures are named in the log |

## Self-review

1. **Forgotten:** the unit-call legs were almost left out of the repo (folded in at the end); the owner-facing consequence of the gate fix (deploys now need the second token) reached the docs but no owner yet.
2. **Better:** the control run against the live script turned every claim about the live defect into a reproduction; running the three reports' follow-ups against the code before writing rows removed about two thirds of them as already done.
3. **Still improve:** a VM leg on the real cgroup filesystem; the stall bar measured on a real storm; the deploy gate's relation to the phantom class.
4. **Did I lie?** No claim above rests on memory alone. The VM run in the shared tree was a cache hit, not a re-execution, and is labelled so. The subagent's mutation controls are labelled as its run.

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Fix |
| ------- | ------ | --- |
| A gate that greps one wording of a line the producer stopped emitting | four weeks of blind gating | the consumer's selftest carries the producer's line shapes and a control; the producer's runbook lists its consumers |
| Identity derived from two clocks | a baseline that resets at random | a kernel identifier (`boot_id`) |
| A whole-filesystem flush to persist one file | 87 GB of writes, long walls | fsync the file |
| Evidence from one group of a cgroup applied to all | frozen bystanders | evidence per group wherever a cgroup can hold several |
| A safety fix that waits for a gate the hazard itself keeps closed | the fix cannot land | owner decision (question 1) |

## f) Next tasks (ranked by impact; every row names its queue or library row)

| # | Task | Impact | Effort | Tag |
| - | ---- | ------ | ------ | --- |
| 1 | Deploy the tree with the explicit token, restart every ghostty window, verify the storm ends (`docs/todo/stability.md` "Deploy the guard round-3 tree, restart every ghostty window, and verify the storm ends") | Critical: ends the frozen listener and the phantom pressure | M | [blocked:user] |
| 2 | Reboot after `nix run .#pre-reboot-check` section 12, then one deliberate crash (`docs/todo/stability.md` "Make kdump capture one cut", retagged) | Critical: the capture path is boot-time and unproven on the host | M | [blocked:user] |
| 3 | Decide whether the phantom-pressure class gets a documented pass in the deploy gates: today the fix for the phantom needs `DEPLOY_FORCE_PRESSURE=1` for pressure and `=2` for trip recency (`docs/todo/stability.md` "Pressure-gate phantom auto-classification", owner said not now on 2026-11-12) | High: otherwise every fix for a phantom waits for a human token | S | [decision] |
| 4 | Zone-6 corroboration: discount S-state io_uring waiters or rank by per-cgroup `io.pressure` (library row of the same name) | Medium | M | [decision] |
| 5 | `llama-embeddings.service` in `ioPause.cgroupPatterns` (library row) | Medium | - | [decision] |
| 6 | Policy for raw `nh os switch` outside `deploy.sh` (existing row, occurrence of 2026-11-26 06:16 appended) | High as a process question | S | [decision] |
| 7 | `kernel.hung_task_panic`: keep 1 or relax (library row) | Medium | - | [decision] |
| 8 | Guard VM leg for the evo-x2 shape and a real-cgroup pause (queue row) | Medium | M | [ready] |
| 9 | Post-deploy section 26: fixture test and a failing exit code (queue row) | Medium | S | [ready] |
| 10 | Guard VM-test scenarios for the IO-PAUSE DISARMED counter (existing queue row) | Medium | M | [ready] |
| 11 | sev1-escalation VM leg for the IO-PAUSE DISARMED title (existing queue row) | Medium | M | [ready] |
| 12 | Three cross-project lessons for crush-config (library row) | Low | S | [blocked:user] |
| 13 | Delegate kdump-capture-path to nixos-modules once it booted once on the host (library row) | Low | S | [blocked:user] |
| 14 | Root btrfs fully chunked: inventory, then `balance -dusage=10` in a calm window, or accept (storage row, update appended) | Medium | M | [blocked:user] |
| 15 | The 10:56 compile burst of cut 2: owner input, then close (library row) | Low | S | [blocked:user] |
| 16 | Boot-census line in `boot-evidence-pull.sh` (existing queue row, whole-boot SIGSEGV count) | Low | S | [ready] |
| 17 | CI execution path for the script-fixture selftests (existing queue row); `guard-sim` and `pstore-records-selftest` are local-only today | Medium | M | [ready] |
| 18 | First execution of the sev1 VM leg and the script selftests through `nix flake check` (existing queue row; the script half ran green here) | Low | S | [ready] |

Dropped, not rowed: "find how the six `system-health-metrics` groups paused at 06:23 were released" (forensic curiosity, not worth a dispatch).

## g) Questions I can not answer myself

1. **The deploy.** The tree is verified (toplevel build, all-systems flake check, VM suite, 36 sim runs) and the live guard is still the broken one. `nix run .#deploy` will refuse: io PSI some avg10 is about 40 % (the ghostty phantom, fix in this same tree) and trips recur every few minutes. It needs `DEPLOY_FORCE_PRESSURE=2 nix run .#deploy`, the token your ladder reserves for a trip-recent window, after two forced deploys into real storms ended in watchdog deaths. I did not take that decision at night. Force it, or deploy after the pressure drains?
2. **The phantom and the gate.** The deploy gate refuses the deploy that ends the phantom pressure because of the phantom pressure. Should the phantom class (idle disks, high PSI, the ghostty signature the gate already prints) get a documented pass, or stay a human token every time?

## Harvest record

HARVESTED 2026-11-27 at authoring. Rows 1, 4 to 7, 12, 13 and 15 of section f are library rows in `docs/todo/stability.md` (rows 12, 13 and 15 tagged `[blocked:user]`, 4 to 7 `[decision]`); rows 8 and 9 are in `TODO_LIST.md` and their libraries; row 2 is the retagged kdump row; row 14 is the updated storage row; rows 6 and 10, 11, 16 to 18 are existing queue rows. The lists of the 00:36, 07:12 and 17:13 reports are closed by this harvest: their remaining open items are rows 1 to 15 above, everything else landed in the tree (CHANGELOG entries of 2026-11-26/27).
