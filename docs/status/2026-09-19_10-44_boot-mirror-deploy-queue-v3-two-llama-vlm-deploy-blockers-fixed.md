# Samsung Boot Mirror — Deploy Queue v3 In Flight, Two llama-vlm Deploy Blockers Fixed (Continuation)

_Sequence: continuation of `2026-09-19_09-48_samsung-boot-mirror-queue-recovery-llama-vlm-fix-parallel-deploy.md` (that report ended "wait for instructions"; the user then ordered full autonomous execution + self-review). Covers 10:03–10:44._

---

## (a) Snapshot

| What                                | Where                                                                                                                                                                                                                      | Status                                      |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| Boot-mirror code                    | committed `260f86ef` (09-18), byte-intact vs HEAD (re-verified 10:05: boot-mirror.nix/activate script/pre-reboot-check untouched; flake/config/deploy.sh gained only parallel-session lines, our markers grep-verified)    | DONE                                        |
| Deploy                              | queue v3b (shell 065) FIRED 10:37:01, in pre-deploy validation §1 as of 10:44                                                                                                                                              | IN FLIGHT                                   |
| llama-vlm blocker #1 (eval)         | `types.path`→`types.str` + quoted literals — fixed 09:26 (`f0cfff20`), eval green                                                                                                                                          | DONE (prior report)                         |
| llama-vlm blocker #2 (§12)          | ExecStart was a LIST of argv tokens = multiple systemd ExecStart LINES (unit would fail at load). Fixed 10:29: `lib.concatStringsSep " "` + comment. Eval-verified single line                                             | DONE this session                           |
| Why nothing shipped all morning     | BOTH parallel deploys (09:40 PID 1721988, ~10:03 PID 2008816) died at pre-deploy §12 on llama-vlm's missing `/data` model files — released the lock in ~10 min with NO activation. Profile stuck at system-785 all morning | ROOT-CAUSED                                 |
| Observer                            | shell 04B finished 09:50 ("deploy lock released. profile=system current=" — its readlink parse was garbage, but the DIRECT check confirmed profile=785, current=system-785's store path)                                   | DONE                                        |
| AGENTS.md lessons                   | ops-artifacts-never-in-/tmp + deploy rc=12/13 surface bullet; `lib.types.path`-on-multi-GB-files bullet                                                                                                                    | WRITTEN 10:15                               |
| 09-18 report staleness              | Deploy row + next-step 16 referenced the tmp-cleaner-eaten `/tmp` script — both annotated SUPERSEDED/DEAD with pointers                                                                                                    | WRITTEN 10:15                               |
| CHANGELOG entry                     | pending deploy outcome (will carry real generation number)                                                                                                                                                                 | PENDING                                     |
| Plan-doc checklist 6–9              | 6 deploy / 7 activate / 8 reboot / 9 docs — ticked as each completes                                                                                                                                                       | PENDING                                     |
| Activation (`boot-mirror-activate`) | after deploy verifies + pre-reboot-check §11 WARN-grade green                                                                                                                                                              | PENDING (autonomous, reversible NVRAM flip) |
| Reboot                              | the ONLY step I will not take autonomously — kills the user's desktop session                                                                                                                                              | USER-GATED                                  |

## (b) FULLY and COMPLETELY DONE (verified)

1. **Root-caused the silent morning**: no deploy ever activated — both parallel attempts died at pre-deploy §12 (`llama-vlm-cap`/`-e4b` ExecStart referenced absent `/data` model .gguf files as separate LINES). The "carrier" theory from the 09-48 report was WRONG in the useful direction: the parallel deploys were dying, not shipping.
2. **llama-vlm ExecStart fix** (`modules/nixos/services/llama-vlm.nix`): `execStart = s: [ …tokens ]` → `lib.concatStringsSep " " ( [ … ] ++ optionals ++ extraArgs )`. Verified: `nix eval …llama-vlm-cap.serviceConfig.ExecStart` = ONE line (`llama-server -m <gguf> --port 8138 -c 8192 --mmproj <gguf>`). Also verified the backend is NOT boot-pulled (`wantedBy = []`, flm socket-activation pattern; socket on `sockets.target` = harmless listener) — so deploying with models-not-yet-downloaded is safe: the backend only starts on first connection.
3. **§12 pre-deploy check validated by a real catch**: it flagged the gguf paths as `would fail 203/EXEC` because a Nix list ExecStart makes each absolute-path token its own ExecStart LINE — systemd rejects the unit at load. The check did EXACTLY what it was built for (the fastflowlm 203/EXEC class). No check change needed; the MODULE was wrong.
4. **Docs closeout (state-independent half)**: AGENTS.md +2 bullets (see a); 09-18 report pointer fixes; verified the boot-mirror runbook EXISTS in AGENTS.md:1126 (the morning handoff's "runbook missing" impression was a head-truncated grep artifact).
5. **Queue v3/v3b doctrine implemented live**: inline poller (no /tmp file), heartbeat every 45s, persistent log `~/.local/state/boot-mirror-deploy.log`, retries rc=12 (pressure) AND rc=13 (lock — with parallel-carrier detection via profile-anchoring check at every loop iteration), 6h deadline + gave-up breadcrumb, stop-and-diagnose on anything else.

## (c) PARTIALLY DONE / in flight

1. **THE DEPLOY (queue v3b, shell 065)**: fired 10:37:01 on gate-green x2 (io 16–17%). In pre-deploy validation (§1 at 10:44; the previous validation pass took ~15 min under load — expect build+switch by ~11:00–11:15). Expected outcome: §12 now warns-not-fails on llama-vlm (`llama-server` store path "not built yet" = WARN class), everything else unchanged from the 10:21 run (61 passed).
2. After deploy SUCCESS: verify mirror live → pre-reboot-check §11 (WARN-grade) → `nix run .#boot-mirror-activate` → pre-reboot-check again (§11 FAIL-grade green) → CHANGELOG + plan ticks 6/7/9 → hand reboot decision to user.

## (d) NOT STARTED

1. Item 8 (reboot + BootCurrent verification) — user-gated by design.
2. CHANGELOG entry + plan-doc checklist ticks — deliberately sequenced AFTER deploy/activation so they record real outcomes (generation number, BootOrder).
3. Post-deploy §15 mirror-freshness assert + system-health mirror-age metric (plan-doc items 13/14 — optional hardening, unchanged stance).

## (e) What I fucked up / got wrong (self-review)

1. **The 09-48 report's "parallel deploy plausibly carries our module" was a wrong-frame speculation.** The observer's 09:50 line `profile=system current=` was malformed output I never dug into; the direct readlink check this session immediately showed profile=785 + no activation. I then spent the morning's first queue attempt (v3, fired ~10:06) firing a deploy without first asking "why did the LAST TWO deploys die?" — it burned ~15 min to re-discover at §12 what the observer already hinted. Lesson: before queueing a retry, autopsy the previous failure even when the failure "belongs" to a parallel session.
2. **The AGENTS.md edit bounced twice on staleness** (daemon commits at 10:06) before I re-viewed and applied — the freshness race documented in Critical Rules, handled correctly on the third try, but I should re-read immediately before EVERY edit in this tree, not after the first bounce.
3. **First tail of the deploy log was misleadingly truncated** (showed validation header twice from two different runs interleaved in one log). Mitigated by timestamped queue lines; future: grep the last `deploy rc=` line instead of tail.

## (f) What went RIGHT (keep doing)

1. Fixed the second llama-vlm blocker surgically (types-only/list-join only, zero semantic change, eval-verified, comment explains the systemd semantics) and flagged both fixes as another session's work per doctrine — they were fleet-wide deploy blockers, which is the sanctioned justification.
2. Did NOT fight the storm: queue waited out 3 parallel `nix build` runs + onnxruntime/Triton C++ compiles (load 102) and fired only on 2× gate-green.
3. Docs closeout done DURING the wait window instead of serially after.

## (g) Next things (prioritized; not all mine)

1. Deploy completes → verify `/boot-mirror` mount (by-uuid `4F53-C156`), `loader/loader.conf`, `EFI/systemd/systemd-bootx64.efi`, kernel entries, ESP df
2. `nix run .#pre-reboot-check` → §11 WARN-grade green, exit 0
3. `nix run .#boot-mirror-activate` → must print the ✓ line; QLC stays second
4. pre-reboot-check again → §11 FAIL-grade green
5. CHANGELOG entry (boot-mirror + both llama-vlm fixes + deploy rc 12/13 doctrine)
6. Plan-doc ticks 6, 7, 9 (leave 8 unchecked until reboot)
7. Ask user: reboot timing
8. Post-reboot: `bootctl status` Current Boot Loader PARTUUID `023f66c0-…`, pre-reboot-check green, QLC fallback intact
9. Watch first nightly sync for drift alerts
10. Optional: deliberate firmware-menu QLC fallback boot test
11. ESP growth watch (configurationLimit 50 × mirrored kernels)
12. Optional §15 mirror-freshness post-deploy assert
13. Optional system-health mirror-age metric
14. Root `@` off QLC (separate task — question 2)
15. llama-vlm models still absent from `/data` — owner decision (download paths are in configuration.nix e4b/cap entries); until then the sockets accept + backends fail on connect (safe, but the feature is dark)
16. Tell the llama-vlm owning session about BOTH fixes (types + ExecStart) so they don't re-break them
17. Consider a check-lint for list-shaped ExecStart (systemd-shape-audit candidate: `builtins.isList ExecStart` with >1 element on non-oneshot units is almost always the argv mistake — §12 catches it late, an eval-time audit would catch it at flake check)
18. The stale `/tmp/.systemnix-deploy.lock` PID content (2008816) is cosmetic — flock is free; deploy.sh's liveness check handles it; no action
19. If deploy exit-4s on `boot-mirror-sync` start: fix module, re-queue (known recoverable risk from the plan doc)
20. If rc=13 recurs: another session is deploying the same tree — profile-anchoring check decides wait-vs-done

## Questions I could NOT figure out myself

1. **Reboot timing** — activation is reversible NVRAM-only and I will do it autonomously once gates are green; the REBOOT kills your desktop + all sessions. You pick the moment (before the 23:00 btrbk window? tomorrow?). Until then the mirror + firmware entry are armed but the box keeps running the QLC chain.
2. **End-state scope** — ESP + `/nix` redundancy is the finish line for "2nd boot disk" (root `@` stays on QLC). Migrate root `@` off QLC next as a separate task, or is this the end state you wanted?
3. **llama-vlm models** — the parallel session's feature ships dark (sockets listen, backends fail `failed to open model` until the /data GGUFs are downloaded). Download them (paths are in configuration.nix), or leave for the owning session?
