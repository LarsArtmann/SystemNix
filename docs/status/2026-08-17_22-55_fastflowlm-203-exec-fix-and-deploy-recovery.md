# FastFlowLM 203/EXEC Fix — Full Status Report (2026-08-17)

**Session window:** ~13:45–16:45 (fix work + deploy saga), verification at 22:54
**Trigger:** User-pasted deploy log — `fastflowlm.service` failing `status=203/EXEC` → `start-limit-hit` → activation `exit 4`, blocking the whole switch.

---

## Root Cause (confirmed)

`pkgs/fastflowlm.nix` installed a **flat layout** (`flm` at `$out/flm`), while the module used `lib.getExe cfg.package` → `$out/bin/flm` — **a path that never existed**. systemd exec fails instantly (203/EXEC), restarts 5×, hits start-limit, blocks activation. Verified against the live store path `rhdj0pbm…-fastflowlm-1.0.1` (no `bin/` dir; the wrapper itself was fine — patched shebang, executable).

While reading the module I found **five additional latent bugs** that would have surfaced one-per-deploy after the 203 fix:

| # | Bug | Consequence if unfixed |
|---|-----|------------------------|
| 1 | `fastflowlm.socket` had no `Service=` override | Socket triggers the **backend directly**: the listening fd is passed to `flm` (nobody accepts it → clients hang forever) AND bypasses the proxy's cold-load wait gate |
| 2 | Backend `wantedBy = [ "multi-user.target" ]` | Model pins ~25 GB RAM at every boot — defeats the entire socket-activation design |
| 3 | `WorkingDirectory = /home/lars` + `harden {}`'s `ProtectHome=true` | Guaranteed `status=200/CHDIR` immediately after fixing 203 |
| 4 | `idleCheck` stopped `fastflowlm.socket` | Idle TTL kills the :52625 listener permanently — no re-activation until manual intervention |
| 5 | `XILINX_XRT=${lib.getExe …}` env (bogus `/bin/flm` path) | Harmless in practice (wrapper re-exports the correct value) but a lying config |

Plus one **pre-existing phantom metric** from the original integration commit (`541a6a1a`): Gatus checks `system_service_state_failed{service="fastflowlm"}` (gatus-config.nix:833) but **no emitter existed anywhere** — permanently-red check + a hard deploy blocker via pre-deploy metric validation.

---

## a) FULLY DONE (verified)

1. **Diagnosis** — root cause + 5 latent bugs identified and explained above.
2. **Package fix** (`pkgs/fastflowlm.nix`) — wrapper now at `$out/bin/flm` (honest `meta.mainProgram`/`lib.getExe`); upstream bash wrapper deleted (not just overwritten); `env-vars` stdenv leak from `cp -r .` removed; **layout self-check** added to installPhase (`test -x $out/bin/flm && test -x $out/flm-real && test -d $out/lib/x86_64-linux-gnu`) so layout drift fails the build. Runtime mkdir-symlink block dropped (tarball ships complete `lib/x86_64-linux-gnu/`; store is read-only anyway — verified against live paths).
3. **Module fix** (`modules/nixos/services/fastflowlm.nix`) — all 5 bugs: `socketConfig.Service = "fastflowlm-proxy.service"`; boot autostart removed (backend starts only via proxy pull-up); `StateDirectory=fastflowlm` + `HOME=/var/lib/fastflowlm` + `WorkingDirectory=/var/lib/fastflowlm` (flm-real reads/writes `$HOME/.config`; service now decoupled from user home); idle-check stops proxy+service but **never the socket**; proxy wait deadline 180s→300s with `TimeoutStartSec=6min` (cold load is 1–3 min under IO contention); `startLimitBurst/IntervalSec` added to proxy + idle units (top-level placement per systemd 261 rule).
4. **Phantom metric fixed** (`modules/nixos/services/system-health.nix`) — `system_service_state_failed{service=…}` now emitted per monitored service via `systemctl is-failed` (inactive ≠ failed), with HELP/TYPE headers. **Verified live at 22:54**: `system_service_state_failed{service="fastflowlm"} 0` present in `system_health.prom`.
5. **Prevention layer** (`scripts/pre-deploy-check.sh`, new check #12) — evaluates **all** `ExecStart` lines of the toplevel config via `nix eval --json … --apply`, tests each binary for existence/executability: hard-fail when the containing store output exists but the binary doesn't (the exact bug class — package built, layout wrong); warn when output not yet built (legit pre-build state). Verified: 169 ExecStart lines scanned, 0 missing, 4 correct "not built yet" warnings. This check would have caught the 203 **before** the first broken deploy shipped.
6. **Package verified end-to-end pre-deploy** — built; `flm validate` passes from the store path via `bin/flm`: kernel 7.1.8, NPU `/dev/accel/accel0` 8 columns, FW 1.1.2.65, amdxdna 0.8, memlock infinity.
7. **Deployed and active** — final deploy (16:42) activated the fixed config despite deploy.sh's misleading error (see d)). **Verified at 22:54:**
   - Live units on disk carry all fixes: `ExecStart=/nix/store/9zz3ba0g…-fastflowlm-1.0.1/bin/flm serve …`, `StateDirectory=fastflowlm`, socket `Service=fastflowlm-proxy.service`.
   - `fastflowlm.socket` **LISTENING on 127.0.0.1:52625** (checked `/proc/net/tcp`, port 0xCD91).
   - Boot autostart gone: no `multi-user.target.wants/fastflowlm.service`; socket symlinked in `sockets.target.wants`.
   - Backend process correctly **not running** (zero RAM/NPU at idle — the design working).
8. **Formatting/lint** — `nix fmt` clean on all touched files; toplevel eval passes.

## b) PARTIALLY DONE

1. **Deploy pipeline hygiene** — config activated, but deploy #3's **post-switch convergence steps were skipped** (see d)): `systemctl reset-failed`, 8 provisioner oneshot restarts, `buildcache-usb-recovery` start, `buildcache-gc` run, post-deploy smoke check. A later activation at **21:08** (another session — commit `e90c7f88` 21:41) re-ran a switch; whether it ran the full deploy.sh path including post-switch steps is **unverified**.
2. **Runtime verification of the service itself** — socket listens, but **no connection has ever been made** through :52625 since the fix. The cold-load path (proxy wait gate → backend start → 13.6 GB mmap → OpenAI API answering) is **untested in production wiring** (the binary itself proven via `flm validate`).
3. **`KNOWN_NEW_METRICS` cleanup** — `system_service_state_failed` was added to the temporary allow-list in pre-deploy-check.sh (line ~219) to let the deploy through. The metric is now confirmed live → **entry should be removed** (one-line change, not done).
4. **Git** — working tree is clean and the fixes are in history (auto-git daemon; HEAD amended 22:50), but the commit(s) carrying the fix are not cleanly attributable — no deliberate commit message describing the 203 fix exists.
5. **AGENTS.md** — not yet updated with this session's gotchas (see f).

## c) NOT STARTED

1. End-to-end cold-load test through :52625 (curl `/v1/models`, first-token timing).
2. Idle-TTL lifecycle test (wait 1h or temporarily lower `keepAlive`; verify proxy+service stop, socket keeps listening, next connection re-activates).
3. Gatus FastFlowLM endpoint green-state verification (`system_service_state_failed`/`start_limit_hit` conditions; note: check now fails-closed correctly instead of phantom-red).
4. Post-deploy-check suite run (`nix run .#post-deploy-check`).
5. Retirement of the hand install (`~/.local/share/fastflowlm/`, `~/.local/bin/flm`, `.bashrc` LD_LIBRARY_PATH exports) — explicitly gated on "deploy proves stable" per AGENTS.md.
6. PMA `OPENAI_BASE_URL` wire-up verification (local LLM for go-commit — separate concern but same service).
7. TODO_LIST.md line 175 (fastflowlm integration task) — not checked off.

## d) TOTALLY FUCKED UP (own goals, honestly listed)

1. **Deploy #2 — 1h42m CPU-starved build, then SIGKILL.** I launched the build while a concurrent Go test storm (another session: `cqrs-bench.test`, `gomod-verify` linking dozens of binaries) had the box at load 85–95. All 252 derivations were trivial; the wall time was pure starvation. At the finish line `nh os switch` died with `Signal(9)` — killer never identified (candidates: systemd-oomd under memory pressure — Gatus "Memory Pressure" endpoint was failing at 16:21 — kernel OOM, or hardware watchdogd). I did not gate on load before deploying. Silver lining: everything it built got cached, making deploy #3 ~5 min.
2. **Deploy #3 — false failure + skipped post-switch steps.** I ran `nix run .#deploy` from the Crush sandbox shell whose PATH is gutted: `deploy.sh` line 76 (`grep` on nh output for `Exited(4)`) failed with `grep: command not found`, printing "**config NOT activated**" — while the activation had **already succeeded** (journal: socket "Listening" 16:42:25). The abort then **skipped every post-switch convergence step**. The sandbox PATH warnings were visible earlier in the session (`tail`/`systemctl` failures) and I failed to connect the dots before launching a deploy from that shell.
3. **Output blackout by my own piping** — deploy #2/#3 outputs piped through `tail -45` → zero visibility for the entire 1h42m; the user had to ask "status?" twice and got a black box. Should have teed to a log file from the first attempt.
4. **Minor: wrong port hex in my own verification** — checked `0xCD31` (52529) instead of `0xCD91` (52625) in `/proc/net/tcp` and briefly concluded "not listening". Caught and corrected in the same verification pass, but it's exactly the class of sloppy check this repo's gotchas archive warns about.

## e) WHAT WE SHOULD IMPROVE (process, from this session)

1. **Tee deploy output to a timestamped log file always** (`nix run .#deploy 2>&1 | tee /tmp/deploy-$(date +%s).log`) — kills the blackout class entirely.
2. **deploy.sh should harden its own PATH** — it depends on `grep`/coreutils but inherits whatever PATH launched it; a `PATH=$(dirname $(which grep))`-style prologue or nix-provided runtime deps would make it sandbox-proof.
3. **Load/PSI gate in pre-deploy-check** — refuse (or warn loudly) when 1-min load > ~2× cores or PSI memory full > threshold. Would have saved 1h42m.
4. **Consider a NixOS VM test for fastflowlm** wiring (socket Service=, proxy wait) — the layout self-check + check #12 catch the static class, not the wiring class.
5. **eval-time guard idea:** a flake check asserting `builtins.match ".*/bin/.*" ExecStart` where packages are involved — weaker than check #12 but catches at `nix flake check` time on CI.
6. **Phantom-metric discipline** — the Gatus check for `system_service_state_failed` shipped in `541a6a1a` without an emitter and survived until a *later deploy* happened to be blocked by it. Pre-deploy metric validation only works if new checks and emitters land in the same change set — worth a CONTRIBUTING note.

## f) NEXT TASKS (prioritized)

**P0 — finish verifying this fix**
1. Cold-load E2E: `curl 127.0.0.1:52625/v1/models` (accepts 1–3 min cold load), then a chat completion; record TTFT.
2. Watch `fastflowlm-proxy` wait-gate behavior during cold load (journal).
3. Idle-TTL test: temporarily set `keepAlive = "5min"` (or wait), verify proxy+service stop, **socket still listening**, second curl re-activates.
4. Run `nix run .#post-deploy-check` (full smoke suite).
5. Remove `system_service_state_failed` from `KNOWN_NEW_METRICS` (metric confirmed live).
6. Verify Gatus "FastFlowLM" endpoints green (both pat conditions) in the Gatus UI/API.
7. Verify `system-health` crash-loop metric (`system_service_start_limit_hit`) still consistent with new emit order.

**P1 — hygiene & durability**
8. Deliberate git commit documenting the 203 fix + latent-bug fixes (clean attribution; the auto-daemon commit is not self-describing).
9. Update `AGENTS.md` fastflowlm section: bin/flm layout, socket `Service=`, no-boot-autostart, StateDirectory HOME, idle-never-stops-socket, check #12.
10. Add gotchas: "deploy.sh from restricted-PATH shells", "flat package layouts vs lib.getExe", "phantom metric same-changeset rule".
11. Annotate/archive the fastflowlm planning doc (`docs/planning/2026-08-15_19-22_…`) as EXECUTED with deviations (proxy architecture as-built).
12. Check off TODO_LIST.md:175; move residual verification items to TODO_LIST.
13. Investigate the `Signal(9)` on deploy #2 (oomd vs watchdogd vs kernel OOM) — journal has the window 16:20–16:40.

**P2 — deploy pipeline hardening**
14. deploy.sh PATH prologue (self-contained coreutils/grep).
15. Pre-deploy load/PSI gate.
16. Consider `--accept-flake-config` / eval-cache warm check to cut deploy eval time.
17. VM test for socket-activation wiring (fastflowlm or generic template).

**P3 — service polish**
18. After 48h stable: retire `~/.local/share/fastflowlm/`, `~/.local/bin/flm`, `.bashrc` exports (AGENTS.md instruction).
19. Update `~/projects/anime-comic-pipeline/docs/npu-fastflowlm-llm-server.md` to the systemd path.
20. Verify PMA `OPENAI_BASE_URL=http://127.0.0.1:52625/v1` actually generates commit messages once go-commit ≥ v0.8.0 propagates.
21. `systemd-analyze security fastflowlm.service` review — check the StateDirectory/ProtectHome interplay left no new holes.
22. Consider `warmCalendar` pre-load before work hours if cold load proves annoying in practice.

## g) QUESTIONS (cannot determine myself)

1. **Cold-load test now or later?** It pins ~25 GB RAM + NPU for up to the 1h idle TTL, while the concurrent session's Go build storm still has the box at high load. Verify now, or wait for that storm to finish?
2. **Post-switch steps for the 16:42 activation were skipped** (provisioner restarts, `buildcache-usb-recovery`, `buildcache-gc`). The 21:08 re-activation by the other session *may* have covered them. My shell cannot run `systemctl`/`sudo` (Crush security policy) — should I verify their state via journal only, or will you run the convergence steps / re-run deploy from a proper shell?
3. **The Go test storm (`cqrs-bench`, `gomod-verify`) belongs to your other session.** If deploys will continue tonight, should I gate on it (wait), or are you fine with deploys sharing the box?

---

**Bottom line:** root cause fixed and **deployed**; socket listening; zero RAM/NPU at idle by design; static checks in place so this class can't silently ship again. What remains is runtime proof (cold load + idle TTL) and cleanup — all queued above.
