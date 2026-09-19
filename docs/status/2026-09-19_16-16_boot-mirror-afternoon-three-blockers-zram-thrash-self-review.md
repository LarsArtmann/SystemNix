# Boot-Mirror Deploy — Self-Review Status Report (2026-09-19 16:16)

_Sequence: continuation of `2026-09-19_10-44_boot-mirror-deploy-queue-v3-two-llama-vlm-deploy-blockers-fixed.md` (queue v3b was mid-validation at handoff). Covers 10:50–16:16 — the afternoon the deploy never shipped, and why (three separate gate-blocking causes, two of them fixed). Per user instruction: full self-review, then WAIT FOR INSTRUCTIONS._

## What This Session Did

1. **Resumed polling the v3b deploy** (context had been canceled mid-poll). v3b's deploy hit the pressure gate at 10:51:09 → rc=12 → auto-retried, as designed.
2. **Diagnosed the all-afternoon storm — two distinct phases:**
   - **Phase 1 (10:37–13:20), real build IO:** parallel sessions' onnxruntime/Triton C++ compiles + aarch64 VM-test qemu builds + 27–31 crush sessions. Disk busy up to 105%, load 102–150. The gate correctly refused to fire (freeze #3/#5 class).
   - **Phase 2 (13:20–now), zram refault thrash:** builds finished (load 6, disks ~2% busy) but io PSI stayed 40–70%. Root-caused with three independent probes: (a) per-task `delayacct_blkio_ticks` delta over 10s = ZERO across all processes (delayacct IS enabled on this kernel), (b) diskstats io_ticks delta ~235ms/10s (~2% busy), (c) vmstat `si`+`so` both >100MB/s with `bi` ≈ `si` exactly — **all "block IO" is zram swap**. The build storm pushed ~16GB into zram (user-1000.slice at 44.9G vs memory.high=80G); the 27+ crush sessions fault those pages back in a sustained loop. RAM-backed swap still counts toward io PSI, so the deploy gate (io avg10 < 20) stays red with idle disks. This is a REAL freeze-class signal (freeze #1 was exactly "zram refault burn"), NOT phantom — the gate is right to hold.
3. **Deploy attempt #3 (13:52, queue v3c) — fixed a NEW fleet-wide blocker first:** the parallel session's 13:01 flake.lock bump to nixpkgs `e554fab` (20260917) staled `pkgs/openseo.nix`'s `fetchPnpmDeps` hash (deploy #2 at 13:42 died rc=1: `openseo-pnpm-deps` specified `FDFfff…` got `qTuljy…`). Fixed by pasting the got-hash with a dated comment; FOD verified green from the new lock (`nix build …openseo.pnpmDeps` → store path). Fix daemon-committed as `3cde5040`. Same concurrent-session doctrine as the two llama-vlm fixes: surgical, zero semantic change, hard blocker to EVERY deploy.
4. **Queue v3c relaunched** (fresh 6h deadline 19:52): fired at 13:52:50 on 2× gate-green, ran validation, hit the pressure gate again at 13:56:32 (rc=12) when the storm bounced — auto-retrying since, correctly.
5. **Parallel-deploy lock contention at 13:14** (rc=13 path exercised live): the queue waited 180s; the parallel deploy did NOT ship (profile unchanged, no lock holder after) — carrier-detection logic never needed to fire.

## Verification Matrix

| Item                                                                 | Evidence                                                                                                                                                                                                                               | State                                        |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| openseo pnpmDeps fix                                                 | FOD builds green: `k1a0ccz…-openseo-pnpm-deps`; committed `3cde5040` (content verified via git show)                                                                                                                                   | DONE                                         |
| zram-thrash root cause                                               | delayacct delta 0µs/10s + diskstats ~2% busy + si/so >100MB/s each, bi≈si (three independent probes agree)                                                                                                                             | ROOT-CAUSED (ongoing, load-driven)           |
| Queue v3c health                                                     | polls every 45s w/ heartbeat; fired once (13:52), rc=12 retry loop live; deadline 19:52 + gave-up breadcrumb                                                                                                                            | RUNNING                                      |
| Nothing shipped today                                                | profile = `system-785-link`, current-system = `qg1ijnzj…b1b8759` — unchanged since 09-18                                                                                                                                               | CONFIRMED (deploy still pending)             |
| Boot-mirror code integrity                                           | committed `260f86ef` (09-18); flake/deploy.sh/config gained only parallel-session lines (10:05 re-verification stands)                                                                                                                  | INTACT                                       |
| /boot-mirror state                                                   | NOT mounted (expected — mounts at deploy via `boot-mirror-sync`)                                                                                                                                                                       | PENDING DEPLOY                               |

## What Went Wrong / Could Be Better

1. **Three fleet-wide deploy blockers today, all from parallel-session churn:** llama-vlm list-ExecStart (fixed 10:22), llama-vlm `types.path` (fixed 09:26, prior session), openseo pnpmDeps (fixed 13:52). Each cost a full validation cycle (~15 min) to discover because pre-deploy §1–§12 only surfaces the NEXT failure after the previous one is fixed. `--keep-going` on the toplevel build exists for exactly this (Critical Rules) but the deploy script's validation phases re-run serially regardless.
2. **The zram-thrash gate hold is open-ended:** the queue can wait forever while crush sessions + parallel builds keep the refault loop alive. Deadline 19:52 will breadcrumb-exit if no green window appears; re-launching is trivial but the STRUCTURAL fix (crush-hot-db Phase-2 migration so session DBs leave the QLC root; the 04:10 daily migration skips whenever crush is running — which is always) is the real answer. Also: 27–31 crush sessions is above the Gatus >6 alert threshold — nothing paged because the metric exists but nobody was watching.
3. **My v3c log breadcrumb hardcoded a wrong time ("13:58" vs real 13:52)** — cost a brief confusion audit. Trivial, but timestamps in logs must come from `date`, never from my estimate.
4. **avail dropped to ~15–19% with zram at 58–61% during the 16:05–16:15 phase** — the storm re-intensified (new builds + swap-out 53MB/s). If avail drops <10% the guard may sacrifice flm; that is by design, but it means the afternoon load is genuinely approaching the guard's zones. Deploy stays queued; no action needed from me.

## Decisions Made (and Their Basis)

- **Pasted the openseo got-hash rather than pinning nixpkgs back:** the lock bump is committed and consistent; rolling back one session's lock to unblock another's deploy is the exact history-churn AGENTS warns about. Forward fix, dated comment, FOD-verified.
- **Did NOT force-deploy (`DEPLOY_FORCE_PRESSURE=1`)** despite hours of red gate: freeze #5 died 9s into a switch during an IO storm; the user's "switching asap" cannot override the box's physical limits. The queue is the sanctioned path.
- **Did NOT touch the crush sessions / hermes llama-servers / rogue orphans:** they belong to parallel sessions and users; killing them would be sabotage of live work.

## Open Questions (for user)

1. **Reboot timing** — once the deploy lands and firmware flips, the reboot (user-owned, desktop-killing) is the last step. Boot into the Samsung mirror at your next natural break; `nix run .#pre-reboot-check` gates it.
2. **Crush-session load** — 27–31 concurrent sessions drove the entire afternoon's thrash. Consider a pool/user-level `MemoryHigh` or session cap if this recurs; the structural crush-hot-db Phase-2 item remains the real fix.
3. **llama-vlm models** — still not downloaded (ships dark, socket-activated). Owner session's call.

## Next Steps (awaiting instructions, queue keeps running autonomously)

1. Queue v3c keeps polling; on green×2 it deploys (validation ~15 min, build+switch, then SUCCESS verification: profile ≠ system-785, `/boot-mirror` mounted UUID `4F53-C156`).
2. After deploy: F06–F13 per the 10-48 plan (mirror verify → pre-reboot-check WARN → `boot-mirror-activate` → pre-reboot-check FAIL).
3. Then CHANGELOG + plan-doc ticks + pathspec commit + push (authorized), final report with both table views, reboot handed to user.

_Ops state: log at `~/.local/state/boot-mirror-deploy.log` (v3c loop, deadline 19:52). Profile `system-785`. No units touched by this session besides the tree fixes above._
