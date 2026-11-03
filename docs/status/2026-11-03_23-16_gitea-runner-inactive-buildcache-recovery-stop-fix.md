# Gitea runner "INACTIVE" smoke FAIL — root cause was the buildcache recovery teardown, not an ordering cycle

**Date:** 2026-11-03 23:16 CET
**Session scope:** diagnose one pasted post-deploy FAIL, fix the class, prove it in a VM
**Starting HEAD:** `b6379612a` (tree already dirty from parallel sessions)
**Ending HEAD:** `fd900d10d` (my work landed inside two daemon heuristic commits)
**Verdict:** diagnosis COMPLETE and proven; **fix committed but NOT DEPLOYED** — the live generation still runs the old script and the defect is still armed.

---

## 0. The pasted failure, and what it actually meant

```
FAIL Gitea runner - INACTIVE: start job deleted by a cycle breaker or unit stopped
(journalctl -u 'gitea-runner-evo\x2dx2.service' --since -30min;
 eval gate: modules/nixos/services/ordering-cycle-audit.nix)
```

That text comes from `scripts/post-deploy-check.sh` §21 (the ordering-cycle gate's runner canary,
line 202 pre-fix). **The message's own hypothesis was wrong.** Live evidence:

| Time (precise) | Event |
| --- | --- |
| 21:11:01.895 | `Starting Recover buildcache mount after USB hotplug (zombie reaper + remount)` (fired by **deploy.sh**, sudo TTY pts/42, `systemctl start buildcache-usb-recovery.service`) |
| 21:11:01.913 | `mnt-buildcache.automount: Deactivated successfully` |
| 21:11:01.915 | `mnt-buildcache.mount: Deactivated successfully` |
| 21:11:01.920 | `Stopping Gitea Actions Runner...` |
| 21:11:01.944 | `gitea-runner-evo\x2dx2.service: Deactivated successfully` / `Stopped` |
| 21:11:01.958 → :02.270 | automount re-armed, `/mnt/buildcache` remounted (`/dev/sdb1`) |
| 21:12:13 | `gitea-runner-ensure: gitea-runner-evo\x2dx2.service not active — clearing start-limit, starting (no-block)` → runner back |

* **Zero** `deleted to break ordering cycle` lines in the window (`journalctl --since 21:00 | grep -c` = 0). The 2026-10-25/26 cycle class was NOT the cause.
* The runner was stopped by **stop propagation**: the rendered unit carries
  `RequiresMountsFor=/mnt/buildcache/ci-runner-cache` (forgejo.nix), which systemd turns into
  `Requires=mnt-buildcache.mount` + `After=`. `buildcache-usb-recovery` step 1 stops that mount
  **unconditionally, on every deploy**, so every buildcache-bound daemon dies with it.
* Nothing converged it back inside the deploy: the runner is `wantedBy=forgejo.service` (correct —
  it must not be pulled by multi-user), and the only re-pull was the **5-minute** ensure timer,
  which fired **72 s later**. The smoke ran in that gap → FAIL.
* Runner was already processing CI again when I arrived (poller launched 21:12:14); at report time
  it is active (`pid 124051`) and running an `act` workflow (`pid 180086`).

Truth in one line: **a deploy-time "recovery" tore down a healthy mount, and the mount's
`Requires=` edge killed the CI runner.**

---

## a) FULLY DONE

1. **Root cause established from live evidence** (not from the FAIL text): deploy.sh → `buildcache-usb-recovery` → `systemctl stop mnt-buildcache.mount` → `RequiresMountsFor` stop propagation → runner TERMed. Verified with `-o short-precise` journal ordering, the generated unit file (`/nix/store/...-unit-gitea-runner-evo-x2dx2.service`), and the sudo journal line naming the recovery start.
2. **`buildcache-usb-recovery` no longer tears down a healthy mount** — new `mount_healthy()` gate (device node present, devt identity `%t:%T` vs the by-id device, ext4, real-I/O `ls`) plus a **step 0 fast path** that converges consumers and exits. Unmounted-but-armed automount is handled (one access pulls it, `findmnt` re-check refuses the root-fs shadow dir).
3. **Consumer convergence added** (new: `converge_consumers()`): restarts FAILED units, starts enabled-but-INACTIVE units, skips disabled/masked, `--no-block` so recovery never serializes behind the slowest consumer; called on the healthy path AND after a real recovery (step 7).
4. **Concurrency guard**: `flock -n /run/buildcache-usb-recovery.lock` (udev + deploy.sh + manual runs could previously race a teardown/remount).
5. **New options + eval-time coverage gate** (`modules/nixos/services/buildcache.nix`): `services.buildcache.recoveryRestartUnits`, `...recoveryRestartUnitsExempt`, and a `config.assertions` check (mirrors `pool-recovery`, 2026-10-04 doctrine) that fails eval when a **buildcache-bound daemon** (RequiresMountsFor under the mount point + explicit non-`no` Restart) is missing from the converge list.
6. **Runner registered** in that list from the module that owns it (`forgejo.nix`: `services.buildcache.recoveryRestartUnits = [ "gitea-runner-<escaped>.service" ]`), with the fourth-stop-class narrative in the comment. Eval proves `["gitea-runner-evo\\x2dx2.service"]` and **zero failing assertions** on evo-x2.
7. **VM test `checks.x86_64-linux.buildcache-recovery` (new, 3 scenarios) — PASSES (exit 0)**:
   healthy run leaves the mount and the consumer untouched; externally stopped consumer is converged; real mount-stop stops the consumer (production mechanism) and the recovery brings both mount and consumer back.
8. **Smoke message corrected** (`scripts/post-deploy-check.sh`): no longer asserts a cycle-breaker diagnosis, names both candidate classes, points at the right eval gates, fixes the doubled `\\x2d` in the copy-paste `journalctl -u` command.
9. **Live state confirmed** at report time: runner active (`busctl … ActiveState = "active"/"running"`), `/mnt/buildcache` = `/dev/sdb1 ext4`, automount armed.
10. Committed (by the auto-commit daemon) as `bc2869e40` + `798a921ef`: buildcache.nix, forgejo.nix, post-deploy-check.sh, tests/default.nix, tests/test-buildcache-recovery.nix.

## b) PARTIALLY DONE

1. **Documentation** — code comments are thorough, but the operator docs are untouched: `docs/agents/storage.md` (line 108 buildcache self-heal bullet), `docs/services/forgejo.md` (runner stop-class table), `CHANGELOG.md` entry. I was mid-read of `docs/services/forgejo.md` when interrupted.
2. **Verification breadth** — targeted evals green (evo-x2 `systemd.services.*`, `assertions`, rendered `script`), plus the new VM test green. **Not** run: `nix flake check --no-build --all-systems` (the ~20 GB/4-7 min walk), `nix fmt -- <changed files>`, shellcheck on the edited `post-deploy-check.sh`.
3. **Commit hygiene** — work sits in two anonymous `chore: auto-commit N changed file(s) (heuristic)` commits instead of one proper message (project doctrine says amend daemon-swept work; I did not, because the tree also carries 2 other sessions' files).
4. **`rust-cache-usb-recovery` twin** — diagnosed as the same defect class in reasoning, but **not** touched (see §c/§f).

## c) NOT STARTED

1. **DEPLOY.** `nix run .#deploy` not run. Until it runs, the live unit still executes the old unconditional-teardown script.
2. `TODO_LIST.md` + `docs/todo/*` harvest rows for the follow-ups in §f (deliberately not harvested this pass — you asked for the report and then to wait; the exact rows are listed in §h so the next action is mechanical).
3. CHANGELOG entry for the fix.
4. Zombie/foreign-fs VM scenario (the 2026-08-16 class the old code existed for) — my test covers healthy + unmounted-dead, not "device node gone but mount table stale" and not "foreign fs at the mountpoint".
5. Concurrency VM assertion (two simultaneous recovery runs must not double-remount).
6. Same healthy-fast-path + converge treatment for `modules/nixos/services/rust-cache.nix` (structural twin; a deploy-time teardown there still yanks `/mnt/rust-cache` out from under in-flight cargo/rust CI steps).
7. Pre-deploy/post-deploy fixture check that no selftest asserts the OLD smoke wording.
8. Investigation of the adjacent live defect I hit (see §d.4).

## d) TOTALLY FUCKED UP

1. **The fix is not live.** Committed ≠ fixed: the running generation still tears the mount down on every deploy, so the very next deploy can reproduce the pasted FAIL. This is the honest state of the ticket.
2. **I trusted the FAIL message's diagnosis for the first pass.** "start job deleted by a cycle breaker" is a *hypothesis baked into a check message*, and it sent me into the ordering-cycle audit before I had looked at causality. The journal had the answer in 5 precise timestamps. Cost: ~10 minutes and a near-miss on the report's premise. (Message fixed — a smoke line should point at evidence, never assert a cause.)
3. **Two VM iterations wasted on the guest's udev timing.** The production-shaped `x-systemd.device-timeout=2s` fails the *first* boot mount in the guest (udev socket comes up at 11.7 s, the boot transaction queues `dev-vdb.device` at 11.5 s) → `dev-vdb.device/start timed out`, consumer dependency-failed. I should have reasoned about switch-root udev settle before the first run.
4. **Discovered, not fixed, an adjacent live breakage**: `home-lars-tmp.mount` is in state **`failed`** (`Mount process exited, status=32`), `/home/lars/tmp` is not mounted, and the resulting `ENODEV` defeats `buildcache-gc`'s *optional* `ReadWritePaths` entries (`-${home}/tmp/go-lint`) — the `-` prefix only tolerates ENOENT, not ENODEV — so `buildcache-gc` died `226/NAMESPACE` at 21:11:04 during the same deploy. Currently `/home/lars/tmp` is gone (nothing mounts it), so the next GC run will likely fail the same way. Root cause not investigated (out of the ticket's scope; the mount is not declared anywhere in this repo — only `cv.nix` *uses* the path).
5. **I did not re-verify the live runner after a *real* recovery run** (would require either deploying or manually running the store script against the live mount). So the "deploy no longer kills the runner" claim is VM-proven and eval-proven, not live-proven.

## e) WHAT WE SHOULD IMPROVE

1. **Stop-ownership audit for mount-gated daemons.** We now have *three* instances of the same class: pool remount stops pool daemons (2026-10-04, `pool-recovery.restartUnits`), buildcache remount stops buildcache daemons (2026-11-03, this fix), rust-cache remount would do the same (not yet wired). The eval-guard pattern should be **generic and shared** (one helper that, for any mount point, computes bound daemons and asserts convergence coverage) instead of copy-pasted per module — `pool-recovery` and `buildcache` now duplicate ~30 lines of identical filter logic.
2. **Destructive "recovery" units must be idempotent no-ops on healthy state.** Both `buildcache-usb-recovery` and `rust-cache-usb-recovery` (and, historically, `mnt-buildcache.mount` start jobs) assume "run me = something is broken". deploy.sh calls them unconditionally after every switch. Rule proposal: *any unit deploy.sh fires after every switch must be a no-op when the system is healthy*.
3. **Every smoke FAIL message must be evidence, not diagnosis.** `post-deploy-check.sh` has other messages with embedded hypotheses (`cycle breaker`, `phantom metrics`, etc.). Audit them all for the same "wrong premise costs a dispatch cycle" bug. Twice this repo has paid for it (2026-10-23 stale premise, this one).
4. **5-minute convergence is too slow for a CI runner.** The ensure timer cadence (`OnUnitActiveSec=5min`) is the only safety net for three separate stop classes. Consider 60 s, or event-driven (`PathChanged`/mount-comes-back trigger) — the timer is the fallback of last resort, not the design.
5. **Optional path prefixes (`-`) do not cover ENODEV.** Our hardening helper and every `ReadWritePaths` that names a path *under a mount point* inherits this trap. Worth a lint: `ReadWritePaths` under a `fileSystems` mount point should be flagged (or at least documented in `docs/agents/systemd.md`).
6. **`journalctl -u` needs the systemd-escaped unit name.** `-u gitea-runner-evo-x2.service` returned `-- No entries --` and nearly convinced me the unit did not exist; the real name is `gitea-runner-evo\x2dx2.service` (path escaping turns `-` into `\x2d`). Add to `docs/agents/systemd.md` / `shell-devtools.md`: resolve unit names via `busctl … ListUnits` or `systemctl list-units`-equivalent, never by typing hostnames.
7. **Parallel-session churn is the dominant risk to verification claims.** During this session the tree gained: my 5 files committed by the daemon, `flake.lock` dirty then clean, `TODO_LIST.md` + `docs/todo/pipeline.md` dirty, and 6 unrelated commits (T-02 pool backup work). Any "flake check passed" I could produce would cover only my files.
8. **Test cost vs value**: the new VM test builds in ~1.5 min wall (cached tarball) — cheap enough to run on every change to either cache-SSD module; wire it into the negative-test nightly alongside `pool-recovery`.

## f) UP TO 50 THINGS TO GET DONE NEXT (priority order)

1. Run `nix run .#pre-reboot-check` (unrelated to the fix, but the deploy path expects it) — actually only needed for reboots; skip.
2. **Deploy the fix** (`nix run .#deploy`) at a quiescent moment, then read the post-deploy smoke: the runner line must PASS.
3. After that deploy, prove the healthy fast path live: `journalctl -u buildcache-usb-recovery.service --since -10min` must show `buildcache healthy (/mnt/buildcache) - no teardown` and the runner must be the **same PID** across the switch.
4. Amend the two daemon heuristic commits into one properly-messaged commit (`bc2869e40` + `798a921ef`), only if still unpushed and after confirming no foreign files ride them.
5. Write the CHANGELOG entry (why it exists, what changed, what is still not live).
6. Update `docs/agents/storage.md` line 108 bullet with the 2026-11-03 class + the fast path + the converge list.
7. Update `docs/services/forgejo.md` runner section: **fourth stop class** (mount-stop propagation) with the evidence table from §0.
8. Harvest rows: `docs/todo/storage.md` (rust-cache twin parity), `docs/todo/services.md` (runner observe-after-deploy), `TODO_LIST.md` one-liners.
9. Add the §e.1 shared helper: extract the "bound daemons under mount point" filter into `lib/` and use it from both `pool-recovery` and `buildcache`.
10. Apply the healthy fast path + converge + eval gate to `modules/nixos/services/rust-cache.nix`.
11. Add `recoveryRestartUnits` peers for any future rust-cache-bound daemon; add the same `flock` there.
12. Extend `tests/test-buildcache-recovery.nix` with the zombie scenario (stop automount+mount, then `mount` a *different* ext4 disk at the mountpoint; recovery must reap it and remount the real device).
13. Add a concurrency leg to that VM test: two `systemctl start` calls racing must not double-remount (assert one `buildcache recovered` line).
14. Audit `scripts/post-deploy-check.sh` for other hypothesis-as-fact messages (§e.3).
15. Consider a retry window for the runner canary (2-3 probes over ~60 s) so a legitimate in-flight restart is not a FAIL.
16. Investigate `home-lars-tmp.mount` (status=32, nothing mounts `/home/lars/tmp`): is it a stale unit from an old generation, a hand-written fstab entry, or a leftover automount? Then decide: drop the unit, or make `buildcache-gc` not reference `${home}/tmp/*`.
17. Regardless of 16, make `buildcache-gc` fail-soft on ENODEV for the optional paths (e.g. drop the `-` entries and let step 2.5 skip absent hosts, or gate with `ConditionPathIsDirectory`).
18. Document the `-` prefix only-tolerates-ENOENT trap in `docs/agents/systemd.md`.
19. Document `journalctl -u <escaped-unit-name>` in `docs/agents/systemd.md` + `docs/agents/shell-devtools.md`.
20. Add a `checks`-level assertion that `buildcache-usb-recovery`'s rendered script still contains `mount_healthy` + `converge_consumers` (a cheap anti-regression render check, in the style of `offsite-borg-positive-render`).
21. Add a negative-test leg that neuters `mount_healthy` and proves the VM test goes RED (negative-test harness discipline).
22. Run `nix flake check --no-build --all-systems` once the tree is quiet.
23. Run `nix fmt -- modules/nixos/services/buildcache.nix modules/nixos/services/forgejo.nix tests/test-buildcache-recovery.nix tests/default.nix`.
24. Run shellcheck (or `nix run .#lint`) over `scripts/post-deploy-check.sh` after the message edit.
25. Check whether any selftest/fixture asserts the old runner-canary wording (`scripts/test-post-deploy-*.sh`).
26. Re-check the coordinator (`deploy.sh`) restart list: is `buildcache-usb-recovery` still wanted post-fix, now that it is a no-op when healthy? (Yes, keep: it heals real faults. But document that it is idempotent.)
27. Consider moving the runner's cache binding off `/mnt/buildcache/ci-runner-cache` onto a path that is *not* Requires-gated (e.g. env-only, no mount dependency) if we ever want deploys to be able to remount the cache while CI runs. Trade-off: churn-to-shadow-dir risk. Currently the mount gate is right; keep it.
28. Measure: how often does a real USB flap occur (journal count of `buildcache recovered` per month)? If frequent, reconsider the SSD/bridge (JMS567 flap history).
29. Gatus: is there a check that catches "runner inactive" independently of the deploy smoke? If not, add a `gitea-runner` metric/health check (the ensure timer masks outages).
30. Add `buildcache_recovery_would_teardown` / `_healthy_skips` counters to `buildcache-metrics` so "deploys stopped killing consumers" is observable.
31. Review `deploy.sh`'s ordering: recovery runs *after* the switch; if a consumer starts *between* mount stop and remount it will fail once. Converge handles it; verify with a real deploy.
32. Audit other `RequiresMountsFor`-gated daemons fleet-wide (beyond pool/buildcache/rust-cache): a one-off eval that lists every daemon + its bound mount point.
33. Extend `pool-recovery`'s audit to also flag *oneshots* that name optional paths under a mount (§e.5 class).
34. Add the class to `docs/agents/storage.md` "USB hotplug self-healing stack" as an explicit invariant list.
35. Consider a `systemd-shape-audit` rule: a unit with `RequiresMountsFor` + `Restart != no` and no convergence registration = eval warning fleet-wide.
36. Re-verify the escape form: `utils.escapeSystemdPath` escapes `-`, producing `\x2d` — is that the systemd-consistent expectation here (a path-escape, not a plain name)? If yes, document; if it was accidental, fix (unit name is now load-bearing in three places: unit, ensure timer, converge list).
37. Add a VM test for the ensure timer's own convergence (reset-failed + start) since it is now the third line of defense.
38. Check `startLimitBurst`/`IntervalSec` interactions: the fast path starts `buildcache-init` + `buildcache-metrics` best-effort (`|| true`) — confirm no start-limit clustering over many deploys.
39. Re-run the full new VM test after any of 12/13/20/21 land.
40. Report the fix on the Forgejo runbook "deploy status" ledger so the next operator knows the class is closed in code, open live.
41. Verify the smoke's `journalctl --since '-30min'` grep is cheap enough at current journal size (it was ~42k lines in 7 min of a deploy).
42. Consider `journalctl -u buildcache-usb-recovery -o cat` parse stability for future automated checks (message strings are now load-bearing: `buildcache healthy`, `buildcache recovered`, `starting enabled-but-inactive buildcache consumer`).
43. Add the message strings to the VM test as the single source of truth (§42) — they already are; keep them in sync with docs.
44. Double-check that `converge_consumers`'s `is-enabled` branch behaves for units installed via `wantedBy=forgejo.service` (it did in the VM for the fixture; the runner case is `enabled` per its `.wants` symlink — verify live after deploy).
45. Add an operator note: the recovery unit deliberately does NOT use `harden {}` (namespace) and now also needs `/run` — confirm `ReadWritePaths` is unset (it is; no ProtectSystem).
46. Re-read the whole `buildcache.nix` diff for style drift after formatting (2-space indentation, comment width).
47. Ensure `tests/default.nix` ordering/naming matches the convention (`buildcache-recovery` next to `pool-recovery` — done).
48. Add the new check to `flake/parts/checks/vm-tests.nix` docs/README counts if any doc enumerates VM checks.
49. If `flake.lock` is dirty on the shared tree again, do not touch it; verify nobody floated an input mid-session before deploying.
50. After deploy: re-run `nix run .#post-deploy-check` standalone and compare the runner line against the pre-fix FAIL to close the loop with real evidence.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Deploy authority right now?** The fix is committed but undeployed, and a CI job is running on the runner (`act` pid 180086); a deploy restarts the runner with `shutdown_timeout=0` and cancels it. Do you want me to deploy immediately (cancelling that run), or wait for the runner to go idle — and who picks that moment?
2. **The two daemon commits with my work (`bc2869e40`, `798a921ef`)** — should I amend them into one properly-messaged commit while three other sessions are committing into the same tree, or leave them as heuristic commits and only document the fix in the CHANGELOG?
3. **`/home/lars/tmp`**: `home-lars-tmp.mount` has been failing (`status=32`) and nothing mounts that path today; it already broke `buildcache-gc` (`226/NAMESPACE`) and `cv.nix` still points `PLAYWRIGHT_BROWSERS_PATH` at it. Is `/home/lars/tmp` an intentional (tmpfs/SSD) mount I should repair, or a retired artifact I should remove from the config surface?

## h) HARVEST LEDGER (deliberately deferred this pass)

You asked for the report and then to wait, so nothing was written into the TODO system. The rows to add the moment you say go:

| Target file | Row |
| --- | --- |
| `TODO_LIST.md` | `[blocked:deploy] Deploy + live-verify the buildcache-recovery fast path (runner must keep its PID across the switch; journal shows "buildcache healthy")` |
| `docs/todo/storage.md` | `[ready] Give rust-cache-usb-recovery the same healthy-fast-path + converge + eval coverage gate` · `[ready] Extract the "bound daemons under a mount point" filter into lib/ and reuse it from pool-recovery + buildcache` |
| `docs/todo/services.md` | `[ready] Fix home-lars-tmp.mount (failed, status=32) or remove ${home}/tmp from buildcache-gc ReadWritePaths + cv.nix playwright path` · `[watch] gitea-runner has no independent liveness check (ensure timer masks outages)` |
| `docs/todo/pipeline.md` | `[ready] VM test legs: zombie/foreign-fs scenario, concurrency, mutation-negative for mount_healthy` |

## i) EVIDENCE INDEX (commands used, all re-runnable)

```bash
journalctl --since '2026-11-03 21:10:58' --until '2026-11-03 21:11:05' -t systemd -o short-precise | rg -i 'buildcache|runner'
journalctl --since '2026-11-03 21:00:00' | rg -c 'deleted to break ordering cycle'      # 0
journalctl --since '2026-11-03 21:09:30' --until '21:12:30' | rg 'COMMAND=.*buildcache-usb-recovery'
cat '/nix/store/1p8l9ky55h7rl7s9myi9cccqlcjch9c3-unit-gitea-runner-evo-x2dx2.service/gitea-runner-evo\x2dx2.service'
busctl get-property org.freedesktop.systemd1 /org/freedesktop/systemd1/unit/gitea_2drunner_2devo_5cx2dx2_2eservice \
  org.freedesktop.systemd1.Unit ActiveState                                                # "active"
nix eval --json .#nixosConfigurations.evo-x2.config.services.buildcache.recoveryRestartUnits
nix eval --json .#nixosConfigurations.evo-x2.config.assertions --apply 'as: builtins.filter (a: !a.assertion) as'   # []
nix build .#checks.x86_64-linux.buildcache-recovery --no-link                            # exit 0
```
