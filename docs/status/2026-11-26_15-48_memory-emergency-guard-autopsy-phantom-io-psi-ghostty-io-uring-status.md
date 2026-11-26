# Memory Emergency Guard dead-letter autopsy: the sustained IO pressure was ghostty's io_uring waits

**Dispatch:** autopsy of task queue `000001a21402bb6ab7cc4d8fbae700000000` (run as `000001a21474f8f4c6ce2349da8100000000`). Error: Gatus `Monitoring/Memory Emergency Guard` failing, first seen 2026-11-25 19:36 CET.
**Sibling reports read first (status-report pre-read rule):** `docs/status/2026-11-26_07-33_memory-emergency-guard-regression-llama-embeddings-thrash-status.md`, `docs/status/2026-11-26_08-05_llama-embeddings-wedge-memory-throttle-status.md`.
**Session window:** 2026-11-26 15:48-16:30 CET, HEAD at start `1d6aa1cf8`. Everything below is read-only and unprivileged except the private headless compositor and the probe cgroups.

## Verdict

- **Why the check is red:** the guard trips Zone 6 every 5-20 min (trips #13523 16:03, #13524 16:11). Zone 6 needs io PSI some avg60 >= 40% plus any disk >= 20% busy. Real bursts supply the disk half (nvme1n1 at ~45% busy in both gate crosschecks at 11:24 and 11:31, 70-102% on the USB DAS at 11:18); the 40-65% io PSI is the half that never drains.
- **The 40-65% is not disk I/O.** The kernel books a thread parked in an io_uring completion wait as IO-stalled once its ring has handled one request, disks idle or not. Ghostty's default `async-backend` is `auto`, which picks io_uring, so every ghostty window reads as an IO-stalled cgroup most of the time. The four monitor windows the owner opened at 2026-11-25 19:57:34 (nvtop x2, iotop-c, btop) held the system reading there for 20 h.
- **This is what deadlocked the deploy.** The pre-deploy gate refuses at io PSI some avg10 >= 20%. Today's 40 attempts: 34 exit 12, 3 exit 13, 3 exit 1. Twenty-two consecutive gate evaluations between 09:07 and 11:06 read "IDLE disks" at PSI 42-62% with the two ghostty scopes as the top stalled cgroups.
- **Initiating cause, already fixed in git:** llama-embeddings thrash under `MemoryMax=2G` / `MemoryHigh=1.6G` was real at 19:36 (07:33 report). Its fix (`37c9f5e25` memoryMax 4G, `0792bfa75` `--parallel 1`) is in the tree and NOT deployed: `system-1032` is still running, `/etc/systemd/system/llama-embeddings.service` still has the 2G cap. At 16:18 the unit's own io.pressure read 0.00 while root io PSI read 61%: the unit no longer explains the sustained reading.
- **Fix landed (this session):** the `async-backend = "epoll"` setting in `platforms/nixos/users/home.nix` (commit: see `git log -- platforms/nixos/users/home.nix -1`). NOT LIVE: it needs a deploy and a full restart of every ghostty window.
- **Why the task dead-lettered:** both earlier attempts died at their deadline on zai 429 (ai-meter admission), unrelated to the error.

## Evidence

| # | Finding | Probe |
| - | ------- | ----- |
| 1 | System io PSI some avg60 60-68% while every physical disk was <= 5.3% busy (12 s window); zram0 5.2% | two-snapshot `/proc/diskstats` join, 15:58 |
| 2 | Top stalled cgroups were the four `app-niri-ghostty-3282*.scope` at 84/77/60/40% io.pressure some avg60; next cgroup 2.1%; zero threads in D state | `find /sys/fs/cgroup -name io.pressure` census, 60 thread sweeps, 15:52 |
| 3 | Those scopes' `[io]` and `[renderer]` threads sit in `io_cqring_wait` (state S); their rings hold 0 SQEs and 0 CQEs; the threads moved <= 13 KB in 12 s, no disk bytes | `/proc/<pid>/task/<tid>/{wchan,io}`, `/proc/<pid>/fdinfo/{12,16}` |
| 4 | Idle io_uring wait is counted only after the ring has handled a request | probe scopes, 14 s each: no history 0.00%; one completed NOP then idle wait 100%; one completed READ then idle wait 100%; armed POLL_ADD 100%; plain `sleep` 0.00% |
| 5 | Ghostty off-screen A/B, ghostty 1.4.0, private headless sway (pixman, no real device), one window running `sleep 55` | default backend: 2 io_uring fds, `[io]` + `[renderer]` in `io_cqring_wait`, io.pressure some avg10 46.6% at 22 s and 63.2% at 48 s (27.6 s of stall in a ~48 s run); `async-backend = epoll`: 0 io_uring fds, both threads in `do_epoll_wait`, io.pressure 0.00 (total 3.8 ms); 106 threads in both |
| 6 | The gate saw the same all day: the top-3 stalled cgroups start with a ghostty scope in 35 of the 36 evaluations that printed a list (06:12-11:31); the exception is the 11:18 DAS storm | `/var/log/systemnix-deploys/2026-11-26_*.log` |
| 7 | The one real storm today: 11:18:49, PSI 96.79%, `session-1653.scope` 96.9%, sda/sdc/sdd at 70-102% (USB DAS) | same logs |
| 8 | Kernel contract: `IORING_ENTER_NO_IOWAIT` (1U << 7) and `IORING_FEAT_NO_IOWAIT` (1U << 17) exist; the probe ring advertises the feature bit | `linux/io_uring.h` of the glibc dev input, `io_uring_params.features` = 0x3ffff |
| 9 | llama-embeddings is still thrashing on memory, not IO: 7.10M -> 7.56M `high` events 15:49 -> 16:18, 1.73 GiB charged against a 1.6 GiB watermark, io.pressure 0.00, main thread in `amdgpu_amdkfd_gpuvm_alloc_memory_of_gpu` | `/sys/fs/cgroup/system.slice/llama-embeddings.service/memory.*` |

## What this corrects in the sibling reports

- 07:33 report: "the check fails because llama-embeddings thrashes" holds for the 19:36 trigger and for the overnight window it measured (05:5x-07:36). It does not hold for the reading now. The "second stall driver outside the cgroup limit" it could not name is the ghostty phantom plus the KFD wedge.
- 08:05 report: "crush -y sessions + builds produced 44-60% io PSI all morning". The 55-61% with idle disks from 09:07 to 11:06 is the phantom. Real bursts exist (llama-vlm-cap-idle 316 MB/s at 13:15, the 11:18 DAS storm) but they are intermittent and cannot hold a 60 s average.
- The guard's per-trip IO-TOP line names llama-embeddings as "top mover" at 30-40 MB/s. Those bytes are zram swap-out (`io.stat` wios 242M equals `pswpout` 242.6M on device 253:0), not disk reads. A byte-mover ranking cannot see a phantom that moves no bytes; rank by per-cgroup `io.pressure` instead.

## What is NOT proven

- That the Gatus check goes green live. The fix is in git, not deployed. Agents cannot deploy (sudo is dead under NNP in this shell type) and the gate refuses while the phantom holds PSI >= 20%.
- The kernel rule's exact source condition. Measured: a ring that never had a request is not counted; a ring that handled one request is counted for the whole idle wait. Not audited in kernel source.
- How much of the earlier Zone-6 storm history (freeze #4-#26 era "IO PSI 40-90%") carried this phantom. Ghostty has been the primary terminal throughout; nobody ranked cgroups by io.pressure before 2026-11-26.

## Fix and its gates

- `platforms/nixos/users/home.nix`: `async-backend = "epoll"` with a load-bearing comment. Commit `8a5896295` (amended from daemon commit `012cf7edd`, which swept the edit before my own commit and skipped the hook's Nix legs).
- Rendered config: `async-backend = epoll` is line 1 of the generated `ghostty-config` store file; `ghostty +validate-config` on it rc=0.
- `nix-instantiate --parse` OK; `nix fmt -- platforms/nixos/users/home.nix` clean on the second run; deadnix 0/0; statix 47 findings before and after, identical classes (all pre-existing).

## Owner steps (need root)

1. Close the four monitor windows (or accept that they keep the phantom until restarted).
2. Deploy. With the windows closed the gate should pass on its own; otherwise `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`. The same deploy carries `37c9f5e25` and `0792bfa75`.
3. Restart every ghostty window, then verify: `grep async-backend ~/.config/ghostty/config`; no ghostty scope above a few percent in a per-cgroup `io.pressure` census; root io PSI some avg60 < 20% with idle disks; zero Zone-6 trips for 30 min; `/etc/systemd/system/llama-embeddings.service` shows `--parallel 1` and `MemoryMax=4G`.

## Follow-up harvesting

- Codified in `docs/agents/stability.md` ("IO-PSI Storm Attribution": step 0) and `docs/services/memory-emergency-guard.md` (phantom class section).
- Appended to the existing `[watch]` row "Boot-time IO storm after the 2026-11-25 hard resets: attribution data points" in `docs/todo/stability.md`. No queue row minted (intake rule).
- Deliberately NOT minted as queue rows, listed here for the next harvest: (1) upstream: libxev / GTK should pass `IORING_ENTER_NO_IOWAIT` when no request is in flight; (2) guard Zone 6 and the deploy gate's phantom branch should discount S-state io_uring waiters (the gate already prints the per-cgroup census that separates the two); (3) fleet sweep for other io_uring event-loop apps (`ls -l /proc/<pid>/fd | grep io_uring`); (4) the 07:33 report's follow-ups 1-4 are still unharvested.

## Re-dispatch verification (attempt 2, 2026-11-26 16:49-17:05 CET)

Attempt 1 committed the fix and the docs, then died at its deadline on zai 429 before it could record a verdict, so the task fired again. This run followed the five-step re-dispatch protocol in `docs/CONTRIBUTING.md`: verify what landed, neither redo it nor skip it. HEAD at start `d360bd33c`, tree clean.

| Step | Result |
| ---- | ------ |
| 1. Footers and queue surfaces | `8a5896295` (fix), `6a3bcfc3c` (report) and `d360bd33c` (docs) carry `Task-Queue-ID: 000001a21474f8f4c6ce2349da8100000000` and are ancestors of HEAD. No queue row names this task (`TODO_LIST.md`, `docs/todo/stability.md`, `docs/todo/monitoring.md`), so there was nothing to tick. |
| 2. Live spot-check at 16:53, unprivileged, independent of attempt 1 | Root io PSI some avg60 54.01% (full 42.98%) while every whole disk was at most 2.0% busy over 12 s (nvme0n1 1.99%, nvme1n1 1.00%, sda 0.16%, sdd 0.32%). zram0 read 45.1% busy and cannot corroborate a trip: the guard's disk list is whole sd and nvme devices only. The four stalled cgroups are `app-niri-ghostty-3282784`, `-3282457`, `-3282455` and `-3282458` at 81.3, 75.0, 56.5 and 40.2% io.pressure some avg60; the next is prometheus-node-exporter at 4.27%. Of 6433 threads, exactly 8 sit in `io_cqring_wait`, all state S: the `[io]` and `[renderer]` thread of each of those four scopes. No other io_uring waiter exists on the box. Guard journal since 2026-11-25 19:00: 197 logged trips, #13331 (19:30:26) to #13527 (16:41:53), every one Zone 6, no restore. |
| 3. Fix re-proved | Off-screen A/B re-run from 17:01:26 to 17:02:14 with attempt 1's harness (copy under `~/.cache/guard-autopsy/ab/`): ghostty 1.4.0 in a private headless sway, one window running `sleep 55`. Default: `libxev default backend=io_uring`, 2 io_uring fds, `[io]` and `[renderer]` in `io_cqring_wait`, cgroup io.pressure some avg10 40.47% at 22 s and 46.37% at 47 s, 22.5 s stalled in a 47 s life. `async-backend = epoll`: `libxev manual backend=epoll`, 0 io_uring fds, both threads in `do_epoll_wait`, io.pressure 0.00%, total stall 1.97 ms. 106 threads in both. The owner's `wayland-1` socket was untouched. `nix fmt -- --fail-on-change platforms/nixos/users/home.nix` changed 0 files. |
| 4. Follow-up sweep, scoped to this task's report | The three codified places are present: step 0 in `docs/agents/stability.md`, the phantom section in `docs/services/memory-emergency-guard.md`, and the addendum on the boot-storm watch row. The four deliberately unminted decisions above stay unminted (intake rule; each needs an owner decision). The 07:33 sibling report's follow-ups 2-4 are still unharvested, as recorded there; its follow-up 1 is the same owner step as below. |
| 5. Stale BLOCKED re-stamp | The `docs/todo/monitoring.md` row "Deploy PSI gate vs the 4 monitor terminals (owner scopes)" now records that the source fix is in tree and that closing the four windows is what lets the gate pass. The row stays `[blocked:user]`. |

**Verdict: fixed in git, verified, unchanged from attempt 1. Not live.**

- `~/.config/ghostty/config` is still the gen-1032 store symlink and has no `async-backend` line. No deploy has been attempted since 11:31.
- `sudo -n true` in this agent shell fails on the no-new-privileges flag, so no agent session can deploy. The owner steps above stand unchanged.
- The check cannot go green before that: root io PSI some avg60 was 54.64% at 17:03 with the four windows still open.

**Why the task dead-lettered (provider capacity, not the error):** the ai-meter admission comment in `modules/nixos/services/ai-meter.nix` cites this host's ledger: z.ai rejections rise from 3% at 5 calls in flight to 31% at 6, 65% at 9 and 78% at 10. At 17:03, 35 `crush` processes were alive on the box. The proxy the dead runs talked to held each call 30 s and then answered 429 (every retry line in the dead run's log), and the run's deadline expired mid-work. The tree already carries `max_wait_seconds = 270` (owner direction 2026-11-26) and rides the same deploy. Nothing changed here.
