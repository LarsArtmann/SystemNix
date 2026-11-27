# Crash follow-up 2026-11-25/26: capture path fixed and VM-proven, storm writer named, IO-PAUSE guard was a no-op since 2026-10-28, three helpers lost to the provider usage limit

Execution of the 31 follow-ups of `docs/status/2026-11-25_18-02_crash-diagnosis-two-panic-reboot-cuts-kdump-capture-kernel-oom-session-status.md`. Work window 2026-11-25 18:57 to 2026-11-26 00:36 CET, same boot `0737ecd7` (uptime 13 h 28 m at report time, io PSI some avg10 45 %, load 12, no further cut).

## Scope line

**Verified here (command + artifact):** kernel 7.3 source order of `vpanic()` (read directly in `/home/lars/.cache/freeze-triage-20261125/kernel-7.3/linux-7.3/kernel/panic.c:577-779` and `fs/pstore/platform.c:277-374`, `drivers/firmware/efi/efi-pstore.c:204-245`); the nixpkgs capture definition (`/nix/store/qbr8hmkwvspln5nbs1qch660cfba6a1z-source/nixos/modules/misc/crashdump.nix`); live pstore parameters (`/sys/module/pstore/parameters/`); evo-x2 toplevel eval with the new module (`nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`, rc=0, 1 m 00 s, at tree `218c448bd`) and the rendered units (`nix eval --json`, `~/.cache/freeze-triage-20261125/eval2.out`); the VM regression test green (`nix build .#checks.x86_64-linux.kdump-capture-boot --no-link -L`, rc=0, 2 min 13 s, log `~/.cache/freeze-triage-20261125/vmtest5.log`); cut 1 telemetry (deduplicated ClickHouse join, `table-boot2.txt`) and journal tail; the storm workloads of both cuts (monitor365 target-dir artifact timestamps on `/mnt/rust-cache`, leftover `rustc` temp dirs, and the monitor365 session database tool-call timeline 08:00-11:06); the Nov 23 pstore archives (read by a helper with sudo, all 67 files); deep-throttle recount on the three boots; the IO-PAUSE candidate resolution reproduced under bash on the live cgroup fs (`work/guard-sim.sh`); the tmpfiles rule that deletes forensic bundles (`/etc/tmpfiles.d/00-nixos.conf:39`, three timeline fits in the journal); the log-pipeline row counts (ClickHouse, 10,041 rows for 10:57-11:06); `scripts/pre-reboot-check.sh selftest` OK, shellcheck clean on both gate scripts, `scripts/post-deploy-check.sh --section-26-only` run live; `nix-instantiate --parse` and `bash -n` on every file this session touched (all OK at 00:34).

**NOT verified here:** nothing was deployed, rebooted or crash-tested on the host (the fix is in the tree only, live after the next boot); the evo-x2 eval was NOT re-run after the later edits (session env caps in `home.nix`, the gate scripts, doc edits) and `nix flake check` was never run; the new post-deploy section 26 has no fixture test of its own (its author helper died before writing it); the false "PIPELINE DARK" verdict of `scripts/boot-evidence-pull.sh` is diagnosed only by measurement, its root cause in the script is not yet read; the IO-PAUSE fix is designed, not written; the forensic bundle store fix is designed, not written; `sudo` worked in this session tree (probed `sudo -n true`, rc=0) but every mutation path stayed unused; `amd_iommu=on` being rejected by the kernel ("AMD-Vi: Unknown option - 'on'") was seen in the boot log and not followed up; the 10:56 compile burst in cut 2 (871 artifacts in one minute, before the two known pipelines) has no named launcher; which kernel path panicked the main kernel is still unknown; the IO-PAUSE fix was not exercised; the provider usage limit ended three helpers mid-task, so items 9, 10, 15, 16, 17, 26, 28 have no implementation. Tree at report time: `e2887897b`.

## TL;DR

1. **The crash cause is now named.** Both cuts hit while a monitor365 agent session ran cargo/nix build-and-test batteries as unsupervised background jobs. Cut 2 (11:05:51): session `ff3fb1b8` started `nix develop -c cargo clippy --all-targets ... cargo nextest run` for `monitor365-db` (10:57:34) and `monitor365-server` (10:58:11), two minutes after the owner's SSH login from the MacBook (10:55:35, the first login of the boot). Cut 1 (08:57:47): session `a77506ad` stacked eleven background jobs between 08:10 and 08:42 (two crane `nix build`s, three `cargo test` runs, a `trunk build --release`, a `cargo build`, `nix run .#session-end`). In both boots the USB rust-cache SSD sat at 100 % busy until the cut (18 minutes in cut 1, 7 in cut 2).
2. **The capture path is fixed in the tree and proven in a VM.** `modules/nixos/services/kdump-capture-path.nix` keeps the host sysctl bag out of the capture boot and puts `crash_kexec_post_notifiers` on the kernel cmdline. In the VM the fixed node comes back from a deliberate panic with `/var/crash/<ts>/vmcore-dmesg.txt` containing the panic line and the main kernel's log in the pstore archive, 9 s after the crash; the unfixed control node captures nothing.
3. **Nothing is live yet.** The fix needs a deploy AND a reboot. Until then the next panic is lost exactly like the last four. `scripts/post-deploy-check.sh --section-26-only` says so right now: 3 FAIL, "the capture path is broken now AND after the next reboot" (the deployed generation predates the fix).
4. **Three of my own earlier claims were wrong and are corrected below:** the main kernel's pstore dump was never written (not evicted); the ClickHouse log pipeline was not dark (the evidence script's verdict is false); the EFI store is not a 22-record ring.
5. **Two structural defects found, neither fixed:** the IO-PAUSE guard could never pause anything (it resolved `cgroup.procs` under an `io.stat` file name; 13,311 trips, 0 pauses), and our own tmpfiles rule deletes every forensic bundle at every boot and every deploy.
6. **The provider usage limit killed three helpers at about 00:20** ("Usage limit reached for 5 hour", reset 2026-11-26 07:20:27). The tooling, guard and bundle-store work died with them; 569 lines of gate code landed without their author's verification pass (I re-verified the minimum at 00:35: selftest OK, shellcheck clean, live run OK).

## §0 Corrections to the 18:02 report

| Earlier claim | What is true | Evidence |
| ------------- | ------------ | -------- |
| The capture kernel's dump "evicted" the main kernel's from a ~22-record EFI ring | The main kernel's dump was NEVER written. `vpanic()` calls `__crash_kexec()` at `kernel/panic.c:670` before `kmsg_dump_desc(KMSG_DUMP_PANIC)` at `:685` unless `crash_kexec_post_notifiers` is set. There is no ring: `efi_pstore_write()` only calls `SetVariable`, nothing erases at write time, and a full store returns `-ENOSPC` | kernel source read; `fs/pstore/platform.c:277-374`; `/sys/module/pstore/parameters/kmsg_bytes` = 10240 |
| 22 records = ring capacity | 22 records is simply one dump: about 10 KB compressed, the newest ~36 KB of text. `systemd-pstore` erases them after archiving; the entries still listed under `/sys/firmware/efi/efivars` read back empty | `ls -l /var/lib/systemd-pstore/*/001/`, `head -c` on one stale variable |
| "ClickHouse log pipeline dark in both death windows" | The pipeline was alive: 10,041 rows in 10:57-11:06, 7,447 rows in 08:50-08:58, flat 5.1-5.3 s lag. Lost: the un-flushed tail (last row 11:05:40.89, journal runs to 11:05:51.18) and the 211 tail lines that were never replayed after the reboot | helper measurement on `signoz_logs.distributed_logs_v2`; the script's own verdict is the defect |
| #61 and #62 were "the box's baseline pathology, not agent-triggered" | Unknowable: both pstore archives hold the capture kernel's OOM dump (`131118 pages RAM`, `min:2097152kB`, panic at 9.6 s and 10.06 s). The capture-kernel OOM ate the evidence of four cuts: #61, #62, #64, #65 | all files of `1795409644` and `1795464749` read |
| "the capture boot applies sysctl via systemd-sysctl" (inference) | Confirmed in the VM: the unfixed capture boot dies right after "Starting Apply Kernel Variables" (5.2 s); the fixed one logs "Apply Kernel Variables skipped, unmet condition check ConditionPathExists=!/proc/vmcore" | `vmtest4.log`, `vmtest5.log` |
| Ledger deep-throttle counts 7 / 4 / 15 for #61-#63 | Those are throttle EPISODES (`THERMAL THROTTLE ENTER`). The ledger column is defined as deep-cap APPLICATIONS: 254 / 109 / 427. `crash-triage.sh` was right all along | full-journal recount per boot |
| "the guard was structurally powerless, writers not in its patterns" | The guard can never pause anything: it looks for `cgroup.procs` inside a file named `io.stat` | reproduction below |
| "3 bundles exist under /var/tmp, deleter unresolved" | 0 exist. Deleted by our own rule `R /var/tmp/io-psi-forensics-* - - - 30d`, executed with `--remove` (age ignored) at every boot and after every deploy | `modules/nixos/services/memory-emergency-guard.nix:1690`, `scripts/deploy.sh:845`, journal timeline |

Side findings, not followed up: the kernel rejects `amd_iommu=on` ("AMD-Vi: Unknown option - 'on'", first boot second); in the #61 capture boot the OOM aborted a btrfs transaction on the root filesystem ("forced readonly"), harmless only because the capture kernel never unmounted cleanly; `pma` and the PapDashboard enricher still call FastFlowLM on `127.0.0.1:52625`, disabled since 2026-11-05, so "commit failed" is their steady state (150 hits in this boot).

## §1 The two cuts, final reading

Common shape: a cargo battery writing into the USB rust-cache SSD (`sdc`) pins it at 100 % busy with small synchronous writes (0.7-2.2 GB/min), everything that reads from it queues behind that, io PSI climbs to 94-100 % some / 69-90 % full, load1 explodes, and the main kernel panics with the journal still logging. The kernel path that panics is unknown (candidates enabled by our sysctls: `hung_task_panic` after a 120 s D-state task, a lockup at 99 C, a driver `BUG()`); the first vmcore will tell.

| Item | Cut 1 (#64) | Cut 2 (#65) |
| ---- | ----------- | ----------- |
| Boot / window | `b4931451`, Nov 24 20:46:44 -> Nov 25 08:57:47 (12 h 11 m) | `8b31b428`, 08:58:54 -> 11:05:51 (2 h 07 m) |
| What ran | session `a77506ad`, 11 background jobs 08:10-08:42 | session `ff3fb1b8`, two clippy+nextest pipelines 10:57:34 / 10:58:11 |
| rust-cache at 100 % busy | 08:39:32 -> cut (18 min) | 11:00:02 -> cut (87 % already at 10:59:02) |
| load1 | 11 -> 28 (08:52:02) -> 281 -> 551 (08:54:02) -> 118 at the last sample | 17.8 (10:59:02) -> 351 -> 1066 (11:04:02) -> 930 at the last sample |
| io PSI some / full in the end | 97 / 88 (08:55:02), 99 / 86 (08:56:32) | 100 / 91 (11:01:32), 100 / 61 (11:05:32) |
| Tctl | sensor series absent in that boot | 99 C for the last 2.5 min |
| Guard trips | 230, all no-match | 15, all no-match (3 in the death window) |
| Leftover `rustc` temp dirs (killed compiles) | 14 at 08:52, 3 at 08:55 | 6 at 10:56, 31 at 10:59, 1 at 11:00 |
| Last journal line | 08:57:47.353 | 11:05:51.178 |

Attribution chain for cut 2, so it can be re-checked: `/mnt/rust-cache/rust/monitor365/debug/deps` holds 1,989 files written 10:56:26-11:00:01 (107 `.rlib` + 108 `.rmeta` at 10:56:20-40, then 35 + 195 + 52 `.rmeta` = the two clippy passes, then 161 `.o` at 10:59:30 = the nextest test binaries); the session database (`~/projects/monitor365/.crush/crush.db`, timestamps in seconds) holds the two `bash` tool calls as background jobs; the first SSH login of the boot is 10:55:35 with key `lars@Lars-MacBook-Air-2026-04`, followed by 14 more shells until 11:03:55. The 11:02-11:03 nix-daemon burst (24 + 26 connections) coincides with two crush-config sessions spawning nested Crush test harnesses (timing-based, inference). The 10:56 burst (871 artifacts, Tctl 98 C at 10:56:32) has no named launcher.

## §2 The capture-path fix

| Leg | Change | Proof |
| --- | ------ | ----- |
| 1 | `systemd-sysctl.service` gets `ConditionPathExists=!/proc/vmcore`; new `kdump-capture-boot-sysctl.service` (`ConditionPathExists=/proc/vmcore`) sets only `kernel.panic` to the host's value | rendered by the evo-x2 eval; VM: the unfixed capture boot dies at "Apply Kernel Variables", the fixed one skips it and reaches `kdump-save` |
| 2 | `crash_kexec_post_notifiers` added to `boot.kernelParams` | VM: `/var/lib/systemd-pstore` holds the main kernel's `sysrq triggered crash` after the fixed node's crash |
| 3 | `kdump-save`, `kdump-retention` and the `/var/crash` rule moved verbatim from `boot.nix` into `_kdump-capture-units.nix` (imported by the module); `kdump-save` now also records `capture-boot-meminfo.txt` and `capture-boot-uptime.txt` | rendered by the eval |
| - | Stale `pstore.record_console=true` and `pstore.max_reason=3` removed (not parameters of the kernel 7.3 pstore core); comments in `boot.nix` corrected | `/sys/module/pstore/parameters/`: backend, compress, kmsg_bytes, update_ms |

VM numbers (`vmtest5.log`): fixed node: panic, capture kernel, systemd-pstore archives 15 records at 6.0 s, `kdump-save: wrote /var/crash/20261125-202850/vmcore-dmesg.txt` at 9.05 s, reboot, next boot verified; capture-boot memory `MemTotal 202224 kB, MemAvailable 113532 kB` with a 256 MiB reservation. Control node: 0 files in `/var/crash`, empty pstore archive.

Timing constraint on the host: the crash image is loaded once per boot by nixpkgs (`boot.postBootCommands`), with the booting generation's init. A deploy does not reload it. Sequence to go live: deploy (clean activation, so the boot entry is written) -> reboot -> `nix run .#pre-reboot-check` (new section 12 audits the generation the reboot will boot) -> one deliberate crash.

## a) FULLY DONE

| Item | Evidence |
| ---- | -------- |
| 1 Capture boot definition read | nixpkgs `misc/crashdump.nix`: same kernel, same initrd, cmdline `init=... irqpoll maxcpus=1 reset_devices 1 boot.shell_on_fail`, loaded in `boot.postBootCommands` |
| 2 + 3 Capture-path fix written | `modules/nixos/services/kdump-capture-path.nix`, `_kdump-capture-units.nix`, `platforms/nixos/system/boot.nix`; evo-x2 eval rc=0 |
| VM regression test | `tests/test-kdump-capture-boot.nix`, registered as `kdump-capture-boot`, green |
| 5 Workload identified | §1 |
| 6 Cut 1 telemetry + journal tail | §1, `~/.cache/freeze-triage-20261125/table-boot2.txt` |
| 7 Kernel source | `vpanic()` order, `pstore_dump` newest-first with `kmsg_bytes` budget, `efi_pstore_write` without eviction, no clamp on `vm.min_free_kbytes`, "System is deadlocked on memory" = OOM killer without a victim, hung-task and lockup panic texts |
| 8 Nov 23 archives | both are capture-kernel OOM dumps; the May 6 dump is a main-kernel `Oops#1` (amdgpu unbind), unrelated |
| 11 Ledger rows #64 and #65 | `docs/agents/stability.md`, rows after #63 |
| 12 Doctrine corrections | kdump bullet, pstore rule, #61/#62 notes, four lesson bullets in the Crash Autopsy entry point |
| 13 Proof beyond `kexec_crash_loaded` | `scripts/pre-reboot-check.sh` section 12 (selftest OK, 13 verdict cases) and `scripts/post-deploy-check.sh` section 26 (live output in §3) |
| 21 Crash Autopsy lessons | read pstore first, answer within 10 minutes, an autopsy is load, agent batteries are a crash class |
| 22 Crash-loop unit and port 52625 | "UNIT CRASH LOOP" is the latched restart counter of `tq-agent-pool.service` (40 start refusals by its own io-PSI gate, then start-limit at 09:19:27; a victim); `hermes-perms-heal` is a one-off 10-minute timeout; port 52625 is FastFlowLM, disabled |
| 23 Deep-throttle counts | ledger cells corrected to 254 / 109 / 427 applications with the episode counts kept |
| 25 Log pipeline | premise falsified, real gap measured |
| New: runbook + doc counts | `docs/services/kdump-capture-path.md`; README and FEATURES re-stamped to 158 modules |

## b) PARTIALLY DONE

| Item | Works | Open |
| ---- | ----- | ---- |
| 14 Capture-boot headroom | VM: 113 MB free of 198 MB with a 256 MiB reservation; `kdump-save` now records meminfo and uptime | host number arrives with the first real capture (`reservedMemory = "512M"` unchanged) |
| 18 Build containment | session env caps in `home.nix` (`CARGO_BUILD_JOBS=12`, `RUST_TEST_THREADS=8`, `NEXTEST_JOBS=8`, `NEXTEST_TEST_THREADS=8`), parse OK; `nix develop -c` bypass of the PATH-shim cargo-gate verified and documented in `cargo-gate.sh` | eval not re-run after the edit, not deployed, no in-build suspend |
| 27 netconsole | facts: `CONFIG_NETCONSOLE=m` + dynamic, `eno1` is r8169 at 2.5 Gb/s; no receiver host identified (`rpi3-dns.home.lan` resolves to this box's own address) | evaluation written in f/24, nothing built |
| 13 Post-deploy proof | section 26 runs and gives the right verdict | no fixture test for section 26; exit-code behaviour on FAIL not checked (my `tail` pipeline hid it) |

## c) NOT STARTED

- 9, 10, 26, 28: pstore assembly and the `kdump=` verdict in `scripts/boot-evidence-pull.sh` / `scripts/crash-triage.sh`, census false positives, moving the extraction into the repo. A helper created `scripts/lib/pstore-records.sh` and nothing else; the file is unused and unverified.
- 15: forensic bundle store (deleter found; `/var/lib/systemnix-forensics/<boot-id>/` design with per-boot keep policy, tmpfiles `d` rule instead of `R`; no line changed).
- 16, 17: per-trip IO attribution to the journal, IO-PAUSE candidate fix.
- 19: thermal shed-load rung.
- 20: root btrfs space, analysis only: 722.52 GiB fully chunked, 49.10 GiB free inside data chunks, 14 GiB free in metadata chunks; normal writes are fine, balance and new-chunk allocation are not possible until chunks are emptied; `root-prune-guard` fires every 5 minutes at 92-93 %. Owner decision, no action taken.
- 24: re-run `scripts/crash-triage.sh --boots 6` and the pre-vacuum gate.
- 29: cache directory cleanup (now also VM logs and kernel sources; several hundred MB under `~/.cache/freeze-triage-20261125/`).
- 30: deploy.
- 31: harvest, see the harvest record.

## d) TOTALLY FUCKED UP

System level:

| # | What | Severity | Root cause | State |
| - | ---- | -------- | ---------- | ----- |
| 1 | IO-PAUSE guard never paused anything | every zone-6 storm since 2026-10-28 ran unprotected | `cg_rel` keeps the `/io.stat` suffix, the pause loop builds `<cgroup>/io.stat/cgroup.procs`, never readable; reproduction printed NOT-FOUND for every pattern (`system.slice/nix-daemon.service`, `session-21.scope`, `tq-agent-pool.service`) | found, designed, NOT fixed |
| 2 | Same block selects by lifetime bytes, not by current IO | after a suffix-only fix it would freeze `nix-daemon.service` or `tq-agent-pool.service` on every trip regardless of who is writing | design defect | fix design: rank by delta since the last snapshot, minimum 64 MB, exclude `*.slice` |
| 3 | Same walk forks one `awk` per cgroup inside a 10 s timeout | under a storm the trip took 11.36 s wall; an empty result reads as "no match" | design defect | fix design: one awk for all files, explicit "walk empty or timed out" line |
| 4 | Forensic bundles deleted at every boot and deploy | every autopsy since 2026-10-14 lost the death-window bundles | tmpfiles `R` rule executed by `systemd-tmpfiles --create --remove` | found, NOT fixed |
| 5 | `scripts/boot-evidence-pull.sh` reports a dark pipeline when it is not | my 18:02 report shipped it as a finding | not yet read in the script; `timestamp` is UInt64 nanoseconds, second- or millisecond bounds return 0 rows | measured, NOT fixed |
| 6 | Agent sessions can start unlimited build/test batteries | two cuts in one day | `nix develop -c cargo ...` bypasses the PATH-shim cargo-gate; default job count is 32 | env caps in tree, not deployed |

My own errors this session:

| # | Error | Cost | Fix forward |
| - | ----- | ---- | ----------- |
| 1 | I fanned out up to five helpers in parallel and never watched the provider budget | the 5-hour usage limit killed three write tasks mid-flight; one helper sat 4.5 h on a `job_output` wait; items 9, 10, 15, 16, 17 are unimplemented | at most two helpers at once, the critical-path work first, and never hand the critical fix to a helper |
| 2 | 569 lines of gate code landed in shared scripts without their author's verification pass | every deploy runs these scripts | I re-verified the minimum at 00:35 (selftest OK, shellcheck clean, live run OK); section 26 still has no fixture test |
| 3 | I wrote doc claims ahead of the code: the stability lesson and the runbook said `crash-triage.sh` prints a `kdump=` verdict while that code does not exist | a reader would trust a verdict that is never printed | corrected at 00:36, both files now say "queued" |
| 4 | I ran three VM builds, two evals and up to six helpers on a box that sat at io PSI 35-55 % all evening | unknown contribution to the standing pressure | serialize heavy work, one VM run at a time, wait below 30 % |
| 5 | The host eval was not repeated after the `home.nix` caps and the later tree moves, and `nix flake check` was never run | the tree is not proven as a whole | run both before any deploy |
| 6 | The VM test needed five runs (drop-in path, `grep -r` versus symlinks, `switch_root` versus `start`, a control assertion the VM cannot show) | about 6 minutes | read the framework first |
| 7 | I used `/tmp` for a scratch file in the last verification and `rm`-free but `/tmp`-based temp output | none | `~/.cache/<topic>/` only |
| 8 | I did not annotate the two committed evidence files that carry the false "PIPELINE DARK" lines | they still mislead | f/10 |

## Self-review

1. **Forgotten:** the re-run of `crash-triage` and the pre-vacuum gate (item 24), the `nix flake check`, the annotation of the two evidence files, the CHANGELOG entry for this session, the harvest, and the IO-PAUSE bug is still only a finding.
2. **Better:** land the smallest critical fix first (capture path), verify it, report, then widen. Instead I widened into eight parallel threads and lost three to the budget.
3. **Still improve:** the guard block needs a real regression test (a dummy process that must end up stopped); `boot-evidence-pull.sh` needs a known-positive control query so a unit bug can never read as darkness; the bundle store must leave `/var/tmp`.
4. **Did I lie?** No claim in this report rests on memory alone; every "verified" row names its artifact. The three wrong claims of my 18:02 report are listed in §0.

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Fix |
| ------- | ------ | --- |
| A guard whose action was never exercised | 13,311 no-op trips read as "writers outside the patterns" | every guard action gets one VM scenario that asserts the effect on a real process |
| Global tunables in one bag | the capture boot inherited a fatal watermark | done for sysctl; the same audit is open for tmpfiles and unit `Environment` |
| Evidence scripts emit verdicts without a positive control | "DARK" was false | control query, three verdict branches |
| State under `/var/tmp` with an `R` rule | bundles die at every boot and deploy | `/var/lib/systemnix-forensics/<boot-id>/`, `d` rule, per-boot keep policy |
| Forensics validated by "is it loaded" | four evidence-less cuts | pre-reboot section 12 + post-deploy section 26 + a deliberate crash after every kdump change |
| Build batteries as background jobs of an agent session | two cuts | env caps (in tree), then a build admission wrapper that also covers `nix develop -c` |

## f) Next tasks (34, ranked by impact; tags: [ready] [decision] [blocked:user])

Harvest record: **deliberately not harvested** into `TODO_LIST.md` / `docs/todo/stability.md` at authoring time: the owner asked for this report immediately while the provider usage limit was ending the session's helpers. f/1 is the harvest itself.

| # | Task | Impact | Effort | Tag |
| - | ---- | ------ | ------ | --- |
| 1 | Harvest this list into `TODO_LIST.md` + `docs/todo/stability.md` (and `services.md` for 11, 12) | High | S | [ready] |
| 2 | Harvest the 18:02 report's remaining items (rows 9, 10, 15, 16, 17, 18, 19, 20, 24, 26, 27, 28, 29, 30 there) | High | S | [ready] |
| 3 | Go live with the capture path: `nix flake check --no-build --all-systems`, deploy through `scripts/deploy-when-quiescent.sh`, reboot, `nix run .#pre-reboot-check`, then one deliberate crash; acceptance = `vmcore-dmesg.txt` in `/var/crash` + a main-kernel pstore dump | Critical | M | [blocked:user] |
| 4 | IO-PAUSE guard: strip `/io.stat` when resolving `cgroup.procs`; select by IO delta since the last snapshot (min 64 MB, no `*.slice`); one awk for the walk; explicit "walk empty or timed out"; IO-TOP journal line; VM scenarios (pause works on a headless dummy, TTY group skipped, idle heavyweight not paused) | Critical | M | [ready] |
| 5 | Decide whether `nix-daemon.service` stays in `ioPause.cgroupPatterns` for the first armed weeks (a trip would freeze every nix build until 10 min of calm) | High | - | [decision] |
| 6 | Forensic bundle store: `/var/lib/systemnix-forensics/<boot-id>/`, root default in `scripts/io-psi-forensics.sh`, per-boot keep policy (50 current, 20 other boots, 90 days, 500 total), replace the `R` rule with `d /var/lib/systemnix-forensics 0755 root root -`, selftest | High | M | [ready] |
| 7 | `scripts/boot-evidence-pull.sh`: find and fix the false "PIPELINE DARK" verdict (nanosecond bounds, known-positive control query), assemble the pstore dump, verdict `CAPTURE-KERNEL` / `MAIN-KERNEL`, `kdump capture FAILED` line; annotate the two committed evidence files | High | M | [ready] |
| 8 | `scripts/crash-triage.sh`: `kdump=` verdict per boot (`main-kernel-panic-captured`, `capture-kernel-OOM`, `capture-kernel-panicked`, `none`) plus `throttle_deep` and `throttle_episodes`; fixture selftest | High | M | [ready] |
| 9 | Remove the unused `scripts/lib/pstore-records.sh` or finish and test it (f/7, f/8) | Medium | S | [ready] |
| 10 | Post-deploy section 26: fixture test with teeth against the old script; check the exit code on FAIL | Medium | S | [ready] |
| 11 | Census false positives in `boot-evidence-pull.sh` (kernel cmdline text counted as panic lines) | Low | S | [ready] |
| 12 | Re-run `scripts/crash-triage.sh --boots 6` and `scripts/pre-vacuum-evidence-gate.sh` | Medium | S | [ready] |
| 13 | CHANGELOG entries for this session (capture path, VM test, gates, env caps, ledger) | Medium | S | [ready] |
| 14 | Session env caps: re-run the evo-x2 eval, document the override in the Build-Storm runbook, watch build times for a week | High | S | [ready] |
| 15 | Decide `kernel.hung_task_panic`: keep 1 (auto-reboot on a 120 s D-state task, evidence captured from now on) or relax | High | - | [decision] |
| 16 | A build admission wrapper that also covers `nix develop -c` and `nix build` (crane): in-build suspend at io PSI some avg10 >= 60 or Tctl >= 95 C, abort after 30 min | High | M | [decision] |
| 17 | Thermal shed-load rung (Tctl >= 98 C sustained under load1 > 100 pauses the attributed writer): allowed only for headless trees, the TTY rule stands | Medium | M | [decision] |
| 18 | Replay the dead boot's journal tail into ClickHouse after each boot (211 lines were never ingested) and add retry + persistent queue to the logs exporter | Medium | M | [ready] |
| 19 | Logs-only batch of 1 s in `signoz.nix` (loss at a hard reset drops from ~10 s to ~1-3 s; about 5x more inserts) | Medium | S | [decision] |
| 20 | Root btrfs fully chunked (49 GiB free inside chunks): inventory what consumes `/`, then `balance -dusage=10` in a calm window, or accept and monitor | High | M | [blocked:user] |
| 21 | `tq-agent-pool.service`: the start-refusal loop under io PSI latches "UNIT CRASH LOOP" for the rest of the boot; confirm the active-churn gate in `system-health.nix` covers it once deployed | Medium | S | [ready] |
| 22 | `hermes-perms-heal` timed out after 10 minutes in the boot storm (metadata walk at Nice 10): skip it while io PSI is high or raise its budget | Low | S | [ready] |
| 23 | `pma` and the PapDashboard enricher still point at FastFlowLM `127.0.0.1:52625` (disabled 2026-11-05): re-point or disable the commit feature | Medium | S | [blocked:user] |
| 24 | netconsole as second transport: feasible on the sender side (`CONFIG_NETCONSOLE=m`, dynamic targets, r8169); needs a receiver host that is always on (`rpi3-dns` name resolves to evo-x2 itself) | Medium | M | [decision] |
| 25 | Delegate `kdump-capture-path` to the `nixos-modules` collection once it has booted once on the host | Low | S | [ready] |
| 26 | Reload the crash image when the deployed generation changes (today: live only after a reboot) | Medium | M | [ready] |
| 27 | `nr_cpus=1` on the capture cmdline (kdump doc: saves memory versus `maxcpus=1`) after the first real meminfo | Low | S | [ready] |
| 28 | `amd_iommu=on` is rejected by the kernel ("AMD-Vi: Unknown option - 'on'"); check whether the IOMMU is on by default and fix the comment or the token | Medium | S | [ready] |
| 29 | The 10:56 compile burst in cut 2 (871 artifacts before the two known pipelines): owner input, then close | Low | S | [blocked:user] |
| 30 | Audit the capture boot against `tmpfiles` rules and unit `Environment` the way sysctl was audited | Medium | S | [ready] |
| 31 | Trash `~/.cache/freeze-triage-20261125/` (journals, kernel sources, VM logs; several hundred MB) after the report is accepted | Low | S | [ready] |
| 32 | AGENTS.md: one line in the stability routing row pointing at `docs/services/kdump-capture-path.md` | Low | S | [ready] |
| 33 | `docs/services/memory-emergency-guard.md`: document the io-pause no-op and the bundle deleter once fixed | Medium | S | [ready] |
| 34 | `docs/services/kdump-capture-path.md`: replace the by-hand pstore reading with the tool commands once f/7 and f/8 land | Low | S | [ready] |

## g) Questions I cannot answer myself

1. **Go-live:** may I deploy the tree through `scripts/deploy-when-quiescent.sh` as soon as the box is calm and the flake check is green, and will you then reboot and run the one deliberate crash (`echo c | sudo tee /proc/sysrq-trigger`)? Without the reboot the fix stays inert, and the box has sat at io PSI 45 % all evening.
2. **Arming the IO-PAUSE guard:** once the path bug is fixed it will, for the first time ever, SIGSTOP the top IO writers that match its patterns during zone-6 storms, `nix-daemon.service` and `tq-agent-pool.service` included, and resume them after 10 minutes of calm. Ship that as designed, or take `nix-daemon.service` out of the patterns for the first weeks?
3. **Two things only you know:** did you start anything by hand around 10:56 in the fresh MacBook shells (a compile ran one minute before the agent session's two pipelines), and do you want `kernel.hung_task_panic` kept at 1 (a 120 s D-state task reboots the box; from now on with evidence) or relaxed?

## Artifacts

- Repo: `modules/nixos/services/kdump-capture-path.nix`, `modules/nixos/services/_kdump-capture-units.nix`, `platforms/nixos/system/boot.nix`, `platforms/nixos/users/home.nix`, `platforms/common/programs/cargo-gate.sh`, `tests/test-kdump-capture-boot.nix`, `tests/default.nix`, `scripts/pre-reboot-check.sh`, `scripts/post-deploy-check.sh`, `scripts/lib/pstore-records.sh` (unused), `docs/services/kdump-capture-path.md`, `docs/agents/stability.md`, `README.md`, `FEATURES.md`. The auto-commit daemon swept all of it into heuristic commits; I committed nothing.
- Cache (`~/.cache/freeze-triage-20261125/`): `vmtest1..5.log`, `eval1.*`, `eval2.*`, `table-boot2.txt`, `metrics-boot2*.tsv`, `capture-kernel-cut2.log`, `w-storm-boot1.txt`, `w-cut1.txt`, `work/guard-sim.sh`, `work/crush_timeline.py`, `kernel-7.3/`.

Reproduce the core proofs:

```bash
nix build .#checks.x86_64-linux.kdump-capture-boot --no-link -L
bash scripts/pre-reboot-check.sh selftest
bash scripts/post-deploy-check.sh --section-26-only
bash ~/.cache/freeze-triage-20261125/work/guard-sim.sh
cat /proc/sys/kernel/random/boot_id
```


## Harvest log

HARVESTED 2026-11-27 (session 4). Rows f/7 to f/11 (the evidence scripts) and f/32 to f/34 (the AGENTS routing, the guard runbook, the kdump-capture-path tool commands) landed in the tree; the two evidence files of f/10 carry a measured annotation (the "PIPELINE DARK" line was false for both boots: the remote tail was 10.1 s and 7.6 s behind the cut). The decisions are library rows: f/15 (`kernel.hung_task_panic`), f/20 (root btrfs fully chunked, on the storage row) and f/29 (the 10:56 compile burst). The reboot and the crash test are the library row "Make kdump capture one cut". Full record: `docs/status/2026-11-27_01-10_crash-followup-4-guard-round3-per-group-stall-evidence-deploy-gate-blind-boot-id-evidence-tooling-landed.md`.
