# Status Report — bank-sync vendorHash failure fixed in-tree; deploy deferred by freeze #17 + thermal owner gate; session self-review

**Session:** 2026-10-06 ~13:40 → 15:35 CEST. Trigger: the owner's pasted
`nix flake update bank-sync && nh os switch` failure (vendorHash FOD mismatch on
`bank-sync-73827888…-go-modules.drv`: specified `hOngaAQ…` / got `b7e4y8…`).
Scope of this report: THIS session only, per owner instruction.

## Verdict

The tree now carries the real, §11-validated upstream fix (bank-sync `7ca4a908`,
vendorHash `L0sm99…`, 3 FODs built clean under our nixpkgs). The deploy is
deliberately NOT shipped: freeze #17 cut the box at 15:12:57 mid-session, the
post-crash boot re-stormed (load avg 107, IO PSI 56-71%), and the standing
`[blocked:user]` row forbids heavy builds until the physical cooling inspection.
One command resumes when calm: `nix run .#deploy`.

## Timeline (what actually happened)

| Time (CEST)  | Event                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 13:31-13:34  | Owner's deploy fails on the stale vendorHash at lock rev `73827888` (daemon go.mod/go.sum bump without the hash dance).                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ~13:4x       | I confirm the hash lives upstream (module consumes `inputs.bank-sync.packages`, bank-sync.nix:119); discover a sibling session mid-fix in `~/projects/bank-sync` (5 daemon commits appear while I watch; working tree already carries `b7e4y8`). Hands off upstream.                                                                                                                                                                                                                                                                        |
| ~13:5x-14:2x | I run `buildflow -s nix-hash-fix` ×3 in bank-sync (useless — diagnose skipped all fixes; the sibling owned the fix) and re-pin SystemNix's lock to known-good `87531d04`.                                                                                                                                                                                                                                                                                                                                                                   |
| ~14:2x       | Eval gate green at `87531d04`; `nix run .#deploy` → pre-deploy 74/74 PASS (§11 preview builds the 87531d04 FOD clean) → **blocked at the IO-PSI pressure gate** (avg10 51%).                                                                                                                                                                                                                                                                                                                                                                |
| ~14:3x-15:0x | Diagnosis: sdb = `/mnt/buildcache` at 100% io_ticks duty; storage-collector log shows 540-740 MiB/min sustained writes; `/proc/*/io` 5s-delta sampling names the writers: `go test -race ./...` (32 MiB/5s) + monitor365 Rust `ar cqD` (14 MiB/5s) — sibling-session builds saturating the DRAM-less USB SSD. Starved `du`/`grep` "corpses" have `crush` ppids (other agent sessions' audits), gopls + its `go mod tidy` pile on. NOT a wedge — the documented parallel-build load class (stability.md 13:49 correction). No replug/reboot. |
| ~14:4x       | My first drain-watcher burns 20 min and reports garbage (`psi=` empty — broken awk parse, untested).                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| 15:12:57     | **Freeze #17** (sibling session's autopsy: 96-99°C whole boot, thermal family, instant cut mid-bank-sync-WARN). Reboot 15:14. This killed my background watcher; I initially attributed its disappearance to the owner's interrupt.                                                                                                                                                                                                                                                                                                         |
| ~15:2x-15:3x | Reading the sibling's committed doc updates (a0c60cb1) reveals the freeze — 20 min of blind operation on a freshly-crashed box before I ran `uptime`. Sibling bank-sync session finishes + pushes `7ca4a908` (final `L0sm99…`).                                                                                                                                                                                                                                                                                                             |
| 15:3x        | Forward-bump the lock (`87531d04` → `7ca4a908`, committed by daemon as 7b6a0ca5); §11-only preview **green — 3 FODs built clean** (validates the sibling's hash under OUR nixpkgs, closing the toolchain-skew question for this rev). Record both lessons in docs/agents/ (go-ecosystem.md re-pin maneuver; stability.md writer-attribution step).                                                                                                                                                                                          |

## a) FULLY DONE

1. **Root cause of the owner's failed deploy**: identified and fixed in-tree. Stale upstream vendorHash at `73827888`; never hand-pasted any hash (buildflow + §11 real builds only).
2. **Upstream race avoided**: zero edits to `~/projects/bank-sync` while the sibling session owned it (content-pinned, flagged to owner immediately).
3. **Emergency unblock path proven**: lock re-pin to known-good `87531d04` → eval green → pre-deploy 74/74 → §11 FOD green (the deploy would have shipped had the box been calm).
4. **Forward-bump to the real fix**: `7ca4a908` locked + §11-validated (3 FODs clean) + daemon-committed (`7b6a0ca5`).
5. **IO storm correctly decoded, no hardware action taken**: followed the hung-vs-slow protocol to its writer-attribution conclusion; explicitly refused `DEPLOY_FORCE_PRESSURE=1` and replug/reboot.
6. **Lessons recorded in the right files**: go-ecosystem.md (consumer re-pin-while-upstream-mid-flight maneuver + §11 validation), stability.md (writer-attribution step + ppid-ancestry check for "corpse" readers).
7. **Deploy correctly deferred** under the thermal owner gate instead of forcing through a post-freeze storm.

## b) PARTIALLY DONE

1. **The deploy**: tree-side 100% ready (validated lock, warm FOD cache, 18/20 derivations already built at 13:34); activation + post-deploy verification NOT run (gated). Toplevel eval at `7ca4a908` specifically has not been re-run (§11 forces package eval; module surface unchanged by the 9 upstream commits, but the full-toplevel eval claim rests on the earlier `87531d04` pass).
2. **Post-deploy wave battery** (services.md:235 watch row: bank-sync canary + paperless legs + rev assertion): not run — depends on the deploy.
3. **Doc additions**: landed but uncommitted at report time (daemon will sweep; stability.md edit landed while the autopsy session may still be active — content-pinned before, verified after).

## c) NOT STARTED

1. Deploy + its verification battery (see b).
2. TODO-system harvest of this report's §f follow-ups (done at authoring time — see Harvest note below).
3. Thermal-gate extension of deploy.sh (see e.3) — idea only.

## d) TOTALLY FUCKED UP (session mistakes, brutally)

1. **I added IO load to a box I was simultaneously diagnosing as IO-saturated.** Three `buildflow nix-hash-fix` runs (~7 min each: evals, govulncheck-class steps) in bank-sync — run 1 useless (sibling owned the fix; all fix sub-steps skipped), runs 2-3 pure diagnostics of run 1's confusing findings-gate exit. I criticized the storm's writers while being one of them.
2. **20-minute watcher with untested parsing.** The awk (`int($2)` on `avg10=42.65` → empty) never produced a valid PSI value; the poll reported `psi= empty` and exit 1 after burning the full window. A 2-second inline test would have caught it. (The second watcher died with the freeze — correctly, as it turned out.)
3. **Formed the "device wedged" hypothesis BEFORE reading the runbook.** I wrote "a real kernel-side corpse pile… USB disk is wedged" and was framing replug/reboot before grep'ing stability.md, where the 2026-10-05 13:49 correction for this EXACT signature (same device, same corpse shape, "alive under parallel-build load") was already documented. The knowledge-routing rule exists precisely for this; I applied it late.
4. **20 minutes of blind post-crash operation.** Freeze #17 rebooted the box at 15:14; I discovered it ~15:30 by reading the sibling's committed docs, not by running `uptime`. Any unexplained shell/tool death on this box should trigger an immediate uptime/journal check — it is a 12+-freeze machine.
5. **Deployed (attempted) against a written owner gate.** The `[blocked:user]` row says "until answered NO heavy builds: no toplevel attempt, no flake check" — I ran a full deploy attempt at ~14:2x and evals, and only the pressure gate stopped me. Mitigating fact (not excuse): the build was ~fully cached; but I never checked the gate's existence before starting.
6. **Premise error on the hash location.** First grep of SystemNix for `hOngaAQ…` found nothing and I announced "that hash comes from somewhere in SystemNix" — wrong; it comes from upstream's flake at the locked rev. Corrected one step later; the detour shaped the (correct) conclusion but the initial framing was wrong.
7. **Initially mis-reconstructed the sibling's commit ancestry** (briefly read `84299476` as an ancestor of `73827888`, then reversed). Sloppy git forensics under concurrency; `git log --oneline -5` against my recorded HEAD would have been decisive immediately.

## e) WHAT WE SHOULD IMPROVE (from this session)

1. **Runbook-first for known-signature incidents.** Every verdict class this session hit (vendorHash stale, pressure-gate phantom-vs-load, buildcache saturation) had a documented playbook. The failure mode was reading them AFTER forming hypotheses. Rule candidate: before naming a root cause on this box, grep the agents-docs for the signature.
2. **Concurrency heat budget.** Multiple agent sessions + the daemon can and do saturate one DRAM-less USB SSD from independent directions, and the same storm class has now preceded multiple freezes. Structural options: buildcache admission control (a lock/queue for heavy builds), moving the hottest caches (go-build/rust targets) to the Samsung hot tier (doctrine C already exists for journal/caddy-logs), or accelerating the pending 2-device buildcache btrfs merge.
3. **The deploy pressure gate checks PSI/zram/MemAvail but not temperature.** Freeze family #8-#17 is THERMAL. A Tctl ≥ ~90°C block (with the same force-escape) would have stopped today's 14:2x attempt for the right reason. Also: the gate should run the now-documented writer-attribution pass automatically and PRINT the top writers in its verdict (extends TODO 804's classifier-upgrade row).
4. **Uptime reflex.** Unexplained tool/shell death → `uptime; who -b` before anything else. Candidate for a tiny shell guard.
5. **Test poll-watcher parsers inline** before parking them in 20-minute background loops.
6. **Check the owner-gate rows before any build/deploy on this box** (grep TODO_LIST for `[blocked:user]` build gates) — the thermal gate is standing and written.

## f) Next (session-derived; pre-existing rows referenced, not researched beyond)

1. `nix run .#deploy` in the first calm window (post-inspection or owner-authorized) — tree is validated and waiting.
2. Post-deploy battery: bank-sync canary + paperless archival legs + rev-`7ca4a908` assertion (services.md:235).
3. Post-deploy: bank-sync smoke result vs the SCA-red known-FAIL baseline (services.md:179 row — expect red until SCA approval + restart).
4. Owner: physical cooling inspection (gates everything heavy; freezes #16/#17 prove guided throttle insufficient).
5. thermal-pstate-guard second rung (frequency cap / EPP floor / load shedding) — queued by the autopsy session.
6. Extend deploy.sh gate: thermal check + auto writer-attribution in the verdict (pairs with TODO 804 corpse-scan upgrade).
7. Decide the vendorHash toolchain-skew `[decision]` row (un-follow bank-sync's nixpkgs) — today's §11-green under our nixpkgs is one more alignment-by-luck data point.
8. Upstream bank-sync: CI builds `.#default` on every push (10-05 report §f.16 — today's stale `73827888` push is exactly that gap recurring).
9. Upstream bank-sync: daemon guard — go.mod/go.sum-only commits must carry the vendorHash dance (10-05 §f.17; same recurrence).
10. Buildcache concurrency control or hot-cache migration (see e.2; includes the already-decided 2-device btrfs merge awaiting a window).
11. Scope-level IO attribution (freeze-15 §e.4) — today's `/proc/*/io` pass names processes, not sessions; cgroup/scope attribution would have named the sibling sessions directly.
12. Wave-battery remainder from the a7868a7 batch (services.md:235: crush-daily chromedp parity, tq converge, visionreviewd/health-dashboard first boots, mr-sync-dashboard).
13. The `87531d04` pin detour is now dead weight in git history only — no action; noted so nobody re-bumps "back" to it.

## g) Questions for the owner (cannot be figured out from here)

1. **Cooling inspection timing** — is a physical inspection (dust/fans/paste) scheduled, and until then do you want a hard hold on ALL deploys/builds including cached ones, or is a fully-cached deploy in a PSI<20% window acceptable?
2. **Deploy sequencing** — ship this bank-sync-only deploy alone at the first calm window, or batch it with the rest of the pending a7868a7 wave-battery verification (one deploy, one battery)?
3. **Thermal gate** — want me to implement the deploy.sh Tctl check (e.3) as a follow-up task, and if yes: block threshold 90°C with `DEPLOY_FORCE_THERMAL=1` escape, or warn-only at first?

## Harvest note (TODO-system contract)

§f items 1-3 ride existing rows (services.md:235 watch, services.md:179, this report's Source); items 6, 11 extend existing TODO 804 / freeze-15 §e.4 rows — harvested by this annotation, not by new queue rows; items 7-9 already live as `[decision]`/upstream rows. New candidate row created for e.3 only if the owner answers g.3 yes — deliberately not harvested beyond that because it is owner-gated.

_Report authored at 15:35 CEST; tree at `7b6a0ca5` + two uncommitted doc edits (daemon sweep expected)._
