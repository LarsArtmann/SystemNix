# Freeze #66 (2026-11-28 10:43:28): the llama-chat idle-TTL engine drove a 60-minute storm into a kernel panic, on the last pre-fix capture path

Session status + self-review for the question "Why did we crash ~20 minutes ago?". Work window 10:57-12:20 CET, all on the recovery boot `56ba232e` (gen-1033, booted 10:46:06). Ledger row: #66 in `docs/agents/stability.md`. Evidence: `docs/status/tasks/2026-11-28_11-04_boot-0737ecd7-evidence-pull.md`.

## Scope line

**Verified here (command + artifact, all run 2026-11-28 10:57-12:10 CET):** boot list and the reset reason of the recovery boot's kernel log; the dying boot's kernel cmdline from its own kernel log; `scripts/crash-triage.sh --boots 6` (census); the EFI pstore archive of the cut (both `dmesg.txt` files, read with `sudo -n cat`, copies in `~/.cache/crash-20261128/`); the last 74 minutes of the dying boot's journal as one JSON dump (126,133 lines, `~/.cache/crash-20261128/death-0930.jsonl`); unit-scoped journal reads for llama-chat, llama-vlm-cap, the thermal guard and the idle checks; the idle-check script of the running generation; the deploy logs of `/var/log/systemnix-deploys/`; the boot anchor (profile `system-1033-link` = `/run/current-system` = booted `init=`).

**NOT verified here:** the main kernel's panic reason (no artifact exists, §2); what the 4 clients polling llama-chat every 30 s are; which process read the 110 GB booked to `user.slice` 10:00-10:11; which of the ~20 collectors that fire together every 10 minutes causes the 3-6 s request stalls; the ClickHouse death window (verdict `alive-behind`, no rows after the cut); the post-fix capture path (never run yet); whether the tree's evo-x2 evaluation is green again after the 09:33 refusal.

## TL;DR: the answer

1. **The kernel panicked at about 10:43:29, the hardware watchdog reset the box, and it was back at 10:46:06, 158 s after the cut.** Reset reason `0x02000800` (hardware watchdog timer expired) is only half the story: the EFI pstore holds 16 `Panic#1` records of a 512 MiB kernel with uptime 7.30-9.48 s that died with `System is deadlocked on memory`. That is the kdump capture kernel, and it only runs when the main kernel panics. The box did not livelock to death like the #34-#63 WDT cuts; it hit a panic path (`nmi_watchdog=panic` and `softlockup_panic=1` are armed).
2. **The storm it died in was manufactured by llama-chat's idle check.** The idle check deployed in gen-1033 (2026-11-27 10:27) runs a store DIRECTORY instead of its activity probe (`template-activity-since: Is a directory`, exit 126). The `if` falls through and the check stops the backend 11-15 min after every load, while clients are still polling it. The socket starts it again 3-15 s later, and every start is a 23.4 GB read from the QLC. Six loads between 09:07 and 10:33; three of the five completed ones outlasted the start contract (curl, 400 retries, about 13.3 min, exit 22), failed, and were restarted from byte 0. At the cut, load number six was 9 m 54 s in.
3. **It stacked on top of the usual morning load:** llama-vlm-cap's 9.1 GB cold load every 20 min, nix builds (431 nix-daemon build-user connections in 10:20-10:30 alone, the host Forgejo runner in `[CI/buildflow]` nix jobs the same minutes), the system-health-metrics collector at 35-157 MB/s, forgejo. Result: io PSI some avg60 42-44 % with the disk at 100 % and memory healthy (49-54 % available) at every guard heartbeat from 10:00, and the CPU in deep throttle at 98-99 °C for the last 58 m 42 s without one exit.
4. **The panic reason is lost, and this was the last cut where that is expected.** The dying boot started 2026-11-25 11:06:51, before the capture-path fix; its cmdline has no `crash_kexec_post_notifiers`, so kexec ran before the kmsg dump. The recovery boot runs gen-1033, the first generation with the post-fix capture image. It is live and unproven.
5. **The engine is still running right now.** In the recovery boot llama-chat has been loaded 5 times in 67 min and idle-stopped 3 times (11:36, 11:51, 12:06). The fix is in tree since 2818c0751 (03:09 today) and is not deployed: the 09:33 deploy was blocked by 4 pre-deploy failures, the 11:26 attempt by the trip-recency gate (exit 12).

Nothing was deployed, stopped or masked by this session. Changes: the evidence file, ledger row #66, this report, and the TODO updates named in §f.

## §0 The cut at a glance

| Item                           | Value                                                                                                                        |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| Boot                           | `0737ecd796a143208516dbcff4e46e07` (boot -1), gen `gwfgxm1v…` at boot, gen-1033 from 2026-11-27 10:27                        |
| Window                         | 2026-11-25 11:06:51 -> 2026-11-28 10:43:28 (71 h 36 m 37 s, longest boot since #59)                                         |
| Last journal line              | 10:43:28.396 (crm-server 403 µs and 1.175 ms, cv health 72 µs: sub-millisecond to the last line)                              |
| Reset reason (recovery boot)   | `0x02000800` hardware watchdog timer expired                                                                                 |
| Cut -> next boot gap           | 158 s (10:46:06)                                                                                                             |
| pstore                         | 16 records `Panic#1 Part16..1`, epochs 1795859024 and 1795859022 (10:43:42-44), 131118 pages RAM, `min:2432kB`, panic at 9.477 s |
| kdump verdict                  | `capture-kernel-OOM`: no kdump-save line, no vmcore                                                                           |
| Kernel lines in the last 28 min | one (journald "Under memory pressure, flushing caches" 10:26:16); no Oops, BUG, lockup or GPU line reached the journal     |
| Guard trips                    | 577 whole boot (#13327->#13903, 8.1/h); 7 in the final 44 min; last #13903 at 10:42:50, 37 s before the cut                  |
| Thermal                        | 354 deep-cap applications and 315 guided episodes whole boot (353 drops, 314 exits: the last episode of each kind never ended); 9 guided episodes 07:00->cut, 8 exited; DEEP ENTER 09:44:46 @ 98 °C, never exited |
| OOM                            | none in the death window (the boot's one kill: Nov 27 06:31:24, llama-server, 10.4 GB anon-rss)                             |
| Anchor                         | intact: profile `system-1033-link` = `/run/current-system` = booted `init=`                                                  |

## §1 Mechanism chain

1. `modules/nixos/services/_llama-idle-activity.nix` landed 2026-11-26 13:33 (1d6aa1cf8) exporting `templateActivity` as the bare `writeShellApplication` derivation. `llama-chat.nix` splices it as `if ${templateActivity} 'llama-chat@' "60min"`. Bash runs the store path, which is a directory: `line 34: /nix/store/py7wqi619z6n9aswrg0aqc8iwh6qbrmv-template-activity-since: Is a directory`, exit 126, false branch, `systemctl stop 'llama-chat@*.service' llama-chat.service`. Verified in the running generation's script (line 34 of `wm86q2wd…-llama-chat-idle-check`). 83 such probe errors across the three idle checks (llama-chat, llama-vlm-cap, llama-vlm-e4b) between the 2026-11-27 10:27 deploy and the cut's eve.
2. The stop happens at the first 5-minute check that finds no live bridge and a backend at least 10 min old. Clients that poll every 30 s (`llama-chat.socket: Too many incoming connections (4), dropping connection` at 10:33:15, 10:41:45, 10:42:15, 10:42:45, 10:43:16) rarely have a bridge live at that instant.
3. Timeline of the crash morning (journal, `-u llama-chat.service -u llama-vlm-cap.service`):

| Time     | Event                                                                                              |
| -------- | -------------------------------------------------------------------------------------------------- |
| 09:07:15 | Started (load 1)                                                                                   |
| 09:18:00 | idle-check stop ("Is a directory"), 10 m 45 s after the start                                      |
| 09:18:15 | load 2 -> 09:32:36 control process exit 22 (23.3 GB read, 19.3 GB peak)                            |
| 09:32:47 | load 3, gate admits 09:36:17 -> Started 09:45:32 (22 GB read, 32.9 GB peak)                        |
| 09:58:00 | idle-check stop, 12 m 28 s after Started, 9 s after a bridge had served                            |
| 09:58:15 | load 4, gate admits 10:04:45 -> 10:18:07 exit 22 (13.8 GB read, 9.8 GB peak)                       |
| 10:18:17 | load 5, gate admits 10:19:47 -> 10:33:09 exit 22 (15.8 GB read, 15.9 GB peak)                      |
| 10:33:33 | load 6, gate admits at once, still loading at 10:42:50 (21 MB/s in the guard's sample) -> cut     |

4. "Control process exited, code=exited, status=22" is the start contract: `ExecStartPost = curl -sf --max-time 3 --retry 400 --retry-delay 2 --retry-all-errors …/health` (curl's 22 is an HTTP error under `-f`; 400 retries at 2 s is about 13.3 min). A load that needs longer than that under the storm is killed and `Restart = "on-failure"` remaps 23.4 GB from byte 0. The module comment records the same failure on 2026-10-12 with the 240-retry budget; the budget grew, the storm grew with it.
5. The guard could not touch the engine: `IO-PAUSE skip: pgid 3772897 in system.slice/llama-chat.service was not I/O-stalled in the trip sample (0 of 8 passes with a thread in D state)`. An mmap page-in has no long-lived D-state thread, so the pausability test skips it. Two escalations followed (10:40:07, 10:42:38: "4 zone-6 trips with driver trees already paused, the writer is outside the pausable set").
6. The psi-wait-gate worked as designed and shows the storm's level: llama-vlm-cap was held through 13 consecutive checks, 361 s, at io PSI some avg10 32.72 / 38.46 / 36.76 / 39.35 / 44.51 / 40.08 / 40.87 / 51.72 / 47.96 / 38.78 / 40.18 / 40.91 / 41.33 %.
7. Stalls grew through the window: crm `/api/contacts/by-phone` has a 0.50 ms median all morning and maxima of 3.0-5.7 s at 09:49, 09:59, 10:09, 10:10, 10:20, 10:30 and 10:40 (those minutes returned 4-40 fewer of their 121 requests), one 32.17 s crowdsec heartbeat at 10:42:47, 16,302 `broken pipe` lines from node_exporter at 10:38:40 (a scrape that timed out).
8. At ~10:43:29 the main kernel panicked. Nothing after 10:43:28.396 reached the journal. The capture kernel started at about 10:43:32 (first dump record 10:43:42 minus its 9.5 s uptime), its systemd (PID 1) requested a tty (`n_tty_open` vmalloc), the first OOM kill came at 7.296 s (`mount`, in `sysroot-nix.mount`), journald at 9.393 s, then `Out of memory and no killable processes` and the panic at 9.476 s. Its memory profile at death: shmem 129 MiB, slab 102 MiB, btrfs page arrays 66.7 MiB, iommu 44.1 MiB, execmem 29.0 MiB.
9. Reset by the watchdog, not by software. That is consistent with `kernel.panic` still 0 in the capture boot because its sysctl bag had not been applied yet, which the `min:2432kB` reading supports (the #64/#65 dumps read `min:2097152kB` and reset through 0xCF9). It is an inference: the dump does not print the sysctl.

## §2 Why the panic reason is unrecoverable

The dying boot booted gen `gwfgxm1v…` on 2026-11-25 11:06:51, nine hours before the capture-path fix was written. Its cmdline: `… crashkernel=512M nmi_watchdog=panic softlockup_panic=1`, no `crash_kexec_post_notifiers`. The module's own header states both legs are boot-time. So this cut repeated the #64/#65 evidence hole by construction: kexec before the kmsg dump, no main-kernel pstore records, a capture kernel that boots the full systemd userspace into 512 MiB, no vmcore.

The recovery boot's cmdline carries `crash_kexec_post_notifiers` and its crash image was loaded from gen-1033. The next panic-class cut is the first live test of the fix, unless the deliberate crash runs first.

## §3 Recovery boot at 12:06

- Anchor intact (see §0). Deploy state clean: no generation newer than 1033.
- The engine is live: llama-chat loaded 10:59, 11:12, 11:36, 11:51, 12:06; idle-check stops at 11:36:03, 11:51:04, 12:06:06; one start-contract failure at 11:12:31; 7 `Is a directory` lines by 12:00.
- Guard: trips #13904->#13910 by 11:19:59 (heartbeats at io PSI some avg60 41.3 % and 45.8 %, disk 100 %, MemAvailable 61 %). Pressure at 12:07: io PSI some avg10 11.5 %, memory some avg10 1.4 %, load 19.3.
- Deploy path: `2026-11-28_09-33-12.log` exit 1 (149 passed, 362 warnings, 4 failed, one root: the evo-x2 evaluation was red at tree 302b798, `modules/nixos/services/ai-meter.nix` "expected a set but found a string", which failed the flake check, the toplevel dry-run and the sops manifest); `2026-11-28_11-26-54.log` exit 12 (trip recency, 10 trips in 60 min).

## a) FULLY DONE

Class, mechanism, drivers, recovery-boot state, evidence pull, ledger row #66.

## b) PARTIALLY DONE

Death-window attribution: llama-chat and llama-vlm-cap are named from unit lifecycle lines; the nix builds, forgejo's 187 MB/s at 10:11, the 110 GB under `user.slice` and the collector-pile stalls are measured but not attributed to a process.

## c) NOT STARTED

Client attribution for the 4 polling connections. Collector isolation for the 10-minute stalls. Any fix beyond the in-tree one.

## d) TOTALLY FUCKED UP

- The interim answer came at ~11:28, 31 minutes after the question, not inside the ~10 minutes the autopsy rule asks for. The triage script alone ran about 5 minutes and was launched before the cheap first five probes were all read.
- Three throw-away `paste`/`awk` one-liners for disk busy produced garbage (field offsets, `%llu` in mawk, a division by zero). Their numbers were discarded and none is quoted here, but they cost four round trips.
- A first draft of this report and of the ledger row called the boot "longest since #52" (false, #59 ran 91.7 h) and mislabeled the thermal counters; both corrected against the full-boot thermal read before any commit.

## Self-review

- **Does the evidence answer the question asked?** "Why did we crash": the storm's engine is named from unit lines and the deployed script; the panic itself is classified but not explained. The answer says so.
- **Which surface did each correction touch?** Ledger (#66), report, `docs/todo/stability.md` rows 61 and 469, `TODO_LIST.md` NOW bullet, the kdump queue line and one new stability queue line.
- **Privilege labels.** `/sys/fs/pstore` and `/var/crash` are root-only; this session had working `sudo -n` (probed, rc 0) and used it for two `cat`s. The `ls /sys/fs/pstore` permission denial was not read as "empty".
- **Absence claims.** "No kernel line in the last 28 min" is a full read of `_TRANSPORT=kernel` since 10:15 (one journald line). "No main-kernel pstore records" is the full 16-record intake of `SYSLOG_IDENTIFIER=systemd-pstore` in boot 0. "Never exited" is 354 DEEP ENTERs against 353 DROPs and 315 guided ENTERs against 314 EXITs over the whole boot.

## e) WHAT WE SHOULD IMPROVE

- The autopsy entry point should print the five class-deciding probes first and run the 6-boot census after the interim answer.
- `boot-evidence-pull.sh` reads the dying boot's cmdline into its first section but does not say whether `crash_kexec_post_notifiers` is present; one line there would have saved a journal read.

## f) Next tasks (harvest state named per item)

1. **Deploy the idle-activity fix and verify the keep-alive window** (`2818c0751`, in tree, undeployed). Existing row updated: `docs/todo/stability.md` "Deploy the llama idle-check fix and verify: sub-second idle checks, no failed-bridge pile, keep-alive honored" (it described the 2026-11-26 version, which carried this bug); its queue line added under stability in `TODO_LIST.md` (the library row had none). Tag stays `[ready]`. The deploy must not be forced: both 2026-11-28 attempts were refused for real reasons.
2. **Run the deliberate crash test on the post-fix capture path** (owner: pre-reboot-check, `echo c | sudo tee /proc/sysrq-trigger`). Existing row updated in both surfaces: `docs/todo/stability.md` "Make kdump capture one cut", its queue line and its NOW bullet. `[blocked:user]`.
3. NOT HARVESTED: "start contract shorter than a storm-time cold load". Deliberately not a row because the deploy in (1) removes the trigger (loads become rare); mint it if a start-contract failure recurs after that deploy.
4. NOT HARVESTED: "3-6 s request stalls at every 10-minute collector pile". Deliberately not a row because unattributed; it is a lead for the next storm anatomy.
5. NOT HARVESTED: "IO-PAUSE skips an mmap page-in engine (no D-state thread)". Same reason as (3): the engine stops with the deploy.

## g) Questions I cannot answer myself

- Which clients poll llama-chat every 30 s in fours, and whether they need the model resident (a resident 32.9 GB backend versus a 23.4 GB read per load is an owner trade-off).
- Whether the capture kernel's 512 MiB is enough for the post-fix boot (shmem 129 + slab 102 + btrfs 67 MiB here were not caused by the watermark). Only the crash test answers it.

## Artifacts

- `docs/status/tasks/2026-11-28_11-04_boot-0737ecd7-evidence-pull.md` (2.1 MB, canonical sections)
- `~/.cache/crash-20261128/`: `triage.txt`, `pstore-A-dmesg.txt`, `pstore-B-dmesg.txt`, `pstore.jsonl`, `death-0930.jsonl`, `idle-checks.txt`, `thermal-boot.txt`
- `docs/agents/stability.md` freeze census row #66
