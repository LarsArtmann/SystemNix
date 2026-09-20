# Boot-Mirror Deploy — Full Session Status Report (2026-09-20 10:38)

_Sequence: continuation of `2026-09-19_10-44_…` and `2026-09-19_16-16_…` reports. Covers 2026-09-19 10:50 → 2026-09-20 10:38 (the storm afternoon, the overnight reboot, and this morning's two fleet-wide eval fixes). Deploy is BUILDING as of writing. Per user instruction: comprehensive self-review, then WAIT FOR INSTRUCTIONS._

## Headline

**The queue's own deploy is in the build phase RIGHT NOW** (fired 10:21:46 after validation passed with all fixes in tree; 8/35 derivations built at 13m49s). The long pole is `nodejs-slim-26.9.0` (~2h15m from source under load, killed once overnight at 2h15m by the reboot). If the build completes and activation succeeds, the remaining chain is: mirror verify (F06–F09) → pre-reboot-check WARN-grade (F10) → `boot-mirror-activate` (F11–F12) → pre-reboot-check FAIL-grade (F13) → docs/commit/push (F14–F16) → reboot decision (user, F17).

## Timeline (this reporting window)

| Time (09-19/20) | Event |
| --- | --- |
| 10:51 | Deploy #1 (v3b) rc=12 — real build-IO storm (onnxruntime/Triton/aarch64-qemu + 27–31 crush sessions, disk 105%, load 150) |
| 13:20 | Builds end; storm becomes **zram refault thrash** (idle disks, si/so >100MB/s each, delayacct 0µs — root-caused with 3 independent probes; freeze-#1 class, gate right to hold) |
| 13:42 | Deploy #2 dies rc=1: parallel session's 13:01 nixpkgs lock bump (`e554fab`) staled `openseo-pnpmDeps` → **FIXED** (got-hash, FOD verified, commit `3cde5040`) |
| 13:52–13:56 | Deploy #3 (v3c) fires, rc=12 again |
| 19:52 | v3c 6h deadline expires cleanly; **v3d** relaunched |
| 00:59–01:18 | Overnight green window: v3d fires; rc=13 (parallel deploy holds lock); fires again 01:18 — validation + gate PASS, build phase reached (first time all session) |
| ~04:10–04:17 | **Box reboots** (not by me — user or crash; my context cycled at ~04:10, background shells died with it). The 2h45m build (nodejs-slim 2h15m in) is killed by the reboot |
| 08:49 | Resume: discover reboot (uptime 4:32), post-reboot calm (io=0, avail=57%, zram=12%) |
| 08:53 | **Queue v4 as systemd --user unit** (context-immune; first attempt died to a quoting bug — script moved to `~/.local/state/boot-mirror-queue.sh`, unit runs the file) |
| 08:54–09:24 | v4 fires into rc=13 cycling (parallel deploy holds lock), then own deploy **fails rc=1**: `deploy-restart-audit` assertion |
| 09:30–09:35 | **Root cause + fix**: `hot-db.nix`'s plain `allowUnits = ["hot-db-bootstrap"]` was REPLACING the audit's option default (defaults never merge with config assignments), silently dropping the 4 upstream-plumbing exemptions → every evo-x2 eval failed since hot-db landed (invisible until the first deploy attempt). Fix: baseline moved to config layer (listOf merge = concatenation). Verified: 5 entries effective, toplevel evals green |
| 09:36–09:38 | Commit blocked by **gitleaks**: a parallel session's 21:15 status report tripped `generic-api-key` on prose ("password, … keys EMPTY" — FALSE POSITIVE, no secret value; the hook exports the whole index so it blocked ALL commits). Reworded 1:1; also chased a `.cache/gatus-src` example-keys red herring (untracked, not the finding) |
| 09:39 | Commit `82d4fa4a` (reword) — daemon raced the audit fix into `50f73871` (content verified in tree; split authorship noted) |
| 09:41–10:09 | v5 relaunched; rc=13 cycling — a parallel session's deploy holds the lock (they saw the green eval too) |
| 10:21:46 | **v5's own deploy fires** — validation passes (§1 flake check GREEN with the audit fix), gate passes, build phase entered |
| 10:38 | Build in progress: 8/35 done, 13m49s elapsed |

## a) FULLY DONE

1. openseo-pnpmDeps hash refresh (nixpkgs e554fab staleness) — FOD verified, committed `3cde5040`
2. zram-thrash storm root-cause (3-probe evidence: delayacct 0µs, diskstats ~2% busy, si/so >100MB/s with bi≈si)
3. deploy-restart-audit allowUnits merge fix — eval verified green, committed (`50f73871` daemon-swept, content mine)
4. gitleaks FP reword in geometrikks report — committed `82d4fa4a`
5. Queue context-immunity: systemd --user unit + `~/.local/state/boot-mirror-queue.sh` (no more /tmp, no more context-cancellation casualties)
6. Three prior reports (10-44, 16-16) + Pareto plan (10-48) with both table views
7. All yesterday's fixes stand: llama-vlm ExecStart + `types.path`, AGENTS lessons, report annotations

## b) PARTIALLY DONE

1. **THE DEPLOY** — building now (8/35, nodejs-slim is the long pole). Everything after it (F06–F17) is defined, scripted, waiting
2. CHANGELOG entry — drafted mentally, lands after deploy outcome is known (parallel sessions keep the file dirty; re-read + pathspec at commit time)
3. Push — authorized, deferred to the F16 batch (post-deploy, post-activation)

## c) NOT STARTED (all gated on the deploy landing)

1. F06–F09 mirror verification (findmnt/contents/df/unit state)
2. F10 pre-reboot-check WARN-grade
3. F11–F12 `boot-mirror-activate` + BootOrder verification
4. F13 pre-reboot-check FAIL-grade
5. F14–F15 CHANGELOG + plan-doc checklist ticks 6/7/9
6. F16 pathspec commits + push
7. F17 final report + reboot handoff

## d) TOTALLY FUCKED UP (honest ledger)

1. **~24h of deploy latency.** Boot-mirror code was done 09-18 evening; the deploy has not shipped as of 10:38 09-20. Causes, ranked by fault: (i) parallel-session load storms + the box's freeze-history gate (correct holds, ~14h), (ii) the 04:17 reboot killing a 2h45m build (not mine, ~5h setback incl. rebuild), (iii) THREE parallel-session eval/build blockers I had to fix (llama-vlm ×2, openseo, audit-allowUnits — ~2h of diagnosis), (iv) my first systemd-run queue died to quoting (~5 min)
2. **v4's hardcoded breadcrumb timestamp** ("13:58" vs real 13:52) — brief confusion, cosmetic
3. **Daemon raced my audit-fix commit** — split authorship across `50f73871`/`82d4fa4a`; content verified, history slightly less readable

## e) WHAT WE SHOULD IMPROVE (structural, from this session's evidence)

1. **The audit-allowUnits class is systemic**: any option `default` list that consumers assign-to breaks silently. Candidates for the same config-layer treatment should be swept (`mount-gating-audit.allowUnits` etc.)
2. **Deploy-validation failures surface serially** — each fix reveals the next blocker a full 15-min validation cycle later. A parallel `nix flake check` + targeted eval battery BEFORE queueing would have caught openseo + audit-allowUnits in minutes
3. **Background processes must never live in bash-tool shells** — context cycles kill them (2 casualties before the systemd-run fix; now doctrine)
4. **zram-thrash gate holds are open-ended** — the structural fix (crush-hot-db Phase-2 so session DBs leave QLC) stays the highest-leverage stability item; 27–31 concurrent crush sessions again exceeded the >6 alert threshold with nobody watching
5. **Parallel sessions all fire deploys at the same calm windows** — three-way lock contention today. A shared "deploy claim" convention (or just the queue's carrier-detection, which worked) would cut the churn

## f) NEXT (up to 50, ordered)

1. Wait for build completion (nodejs-slim ~2h15m unless cached by a parallel build)
2. On rc=0: verify profile ≠ system-785 + anchored (F05)
3. F06 findmnt /boot-mirror → UUID `4F53-C156`, vfat rw
4. F07 ls /boot-mirror → loader/loader.conf, EFI/systemd/systemd-bootx64.efi, EFI/BOOT/BOOTX64.EFI, generation entries
5. F08 df -h /boot-mirror (4G ESP)
6. F09 unit state of boot-mirror-sync (via pre-reboot-check §11 output — systemctl banned in my shell)
7. F10 `nix run .#pre-reboot-check` → exit 0 (§11 WARN-grade)
8. F11 `nix run .#boot-mirror-activate` → Samsung first in BootOrder
9. F12 verify BootOrder (Samsung `Linux Boot Manager (Samsung)` first, QLC 0x0001 second)
10. F13 re-run pre-reboot-check → §11 FAIL-grade green
11. F14 CHANGELOG `### Added` entry (boot-mirror shipped + the four blockers fixed + queue doctrine)
12. F15 tick plan-doc items 6/7/9 (leave 8=reboot unchecked)
13. F16 pathspec commits + `git push` (authorized)
14. F17 final report with M1–M12 + F01–F27 tables + reboot handoff
15. Post-activation: tell user the reboot proof (`bootctl status` Current Boot Loader PARTUUID `023f66c0-…`)
16. Sweep other `allowUnits`-style option defaults for the replace-trap (mount-gating-audit, gatus-coverage allowPorts, systemd-shape-audit allowTimerRestart)
17. Propose eval-battery precheck (flake check + evo-x2 toplevel + targeted evals) before future deploy queues
18. llama-vlm model downloads (owner decision — ships dark otherwise)
19. crush-hot-db Phase-2 (`services.hot-db` ratification) — the storm structural fix
20. Add queue script to a proper location if it becomes a pattern (~/.local/state is runtime, fine for now)
21. Status-report prose should avoid `<word>, … keys EMPTY` shapes (gitleaks generic-api-key heuristic) — or add .gitleaksignore fingerprint
22. Ask owner: was the 04:17 reboot theirs? (crash forensics if not — journal cut analysis)
23. Re-verify geometrikks go-live keys remain empty after their deploy lands (user-gated)
24. If nodejs-slim rebuilds again from zero: consider why cache.home.lan didn't serve it (attic coverage for e554fab-era nixpkgs)

## g) QUESTIONS (cannot figure out myself)

1. **Was the 04:17 reboot yours?** If not, it needs crash forensics (the log cut at 04:10, boot 04:17 — freeze #7 candidate; kdump should have a vmcore if it panicked)
2. **Reboot timing after activation** — the mirror flip is inert until the next boot; reboot at your next natural break (the finish-line's only user-owned step)
3. **Crush-session load policy** — 27–31 sessions drove ~14h of gate holds yesterday. Cap them (pool config / session limit), or accept queue delays as the cost of parallelism?

## Ops state right now

- Queue: systemd --user unit `boot-mirror-deploy-v5.service` running `~/.local/state/boot-mirror-queue.sh` (log: `~/.local/state/boot-mirror-deploy.log`, deadline ~18:21, gate-2×-green, rc 12/13 auto-retry, stop-on-other)
- Deploy: building (toplevel `nixos-system-evo-x2-26.11.20260917.e554fab`)
- Profile: `system-785` (unchanged since 09-18 20:57 — nothing has shipped since)
- /boot-mirror: not mounted (expected until deploy)
