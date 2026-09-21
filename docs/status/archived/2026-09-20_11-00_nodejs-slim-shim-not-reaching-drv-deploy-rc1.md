# Boot-Mirror Deploy: rc=1 Root-Caused — nodejs-slim Test Failure, Shim Present but NOT Reaching the Derivation

> **[docs-health 2026-09-21] RESOLVED + ARCHIVED** — the blocked deploy landed the same day (system-786 anchored 14:08 `fc49dbe5`, then 787/791); the shim-vs-bump question was decided by the root-nixpkgs bump carrying upstream fix `089b82f9` (`8253c632`), the harmful shim removed (`1bfe5ae2`), and the overlay-reach doctrine harvested into AGENTS.md ("SystemNix overlays can NEVER reach packages built inside followed input flakes"). Every open item below is struck inline with its evidence.

**Session:** 2026-09-20 10:56 → 11:00 (short diagnosis session, resumed from the 10:38 handoff report)
**Task:** Samsung boot-mirror deploy verification chain (F05–F17), queue-driven, full autonomy
**State at session end:** deploy BLOCKED again — root cause identified, fix path defined, NOT yet applied. Profile still `system-785`. Queue unit exited (stopped for diagnosis as designed).

---

## Timeline of this session

| Time | Event |
|------|-------|
| 10:56 | Resumed from handoff; restored todo list; checked queue v5 outcome |
| 10:56 | Finding: the 10:21:46 deploy **failed rc=1 at 10:53:17** (`nh os switch` build failure). Queue stopped itself for diagnosis ("non-gate failure rc=1 — STOPPING") exactly as designed |
| 10:57–10:59 | Extracted full failure context from `~/.local/state/boot-mirror-deploy.log`: root failure = **`nodejs-slim-26.9.0` exit 2 in checkPhase after 28m11s** — 1 of 5770 tests failed: `test/parallel/test-fs-cp-async-file-modes.mjs`. Everything else in the graph (npm-12, nodejs-26.9.0, hermes-agent-0.21.3, system-path, unit-hermes.service, …, toplevel) is cascade |
| 10:58 | Probed `nixpkgs/e554fab#nodejs-slim.version` → **24.20.0**: nodejs-slim_26 is a non-default attr consumed by the hermes/npm/llama-cpp chain, not the default toolchain |
| 10:59 | **Key discovery:** `overlays/shared.nix:123-140` ALREADY carries a shim (parallel session, daemon commit `8740c661`, 2026-09-19 19:31:31) that `rm -f`s exactly this test via `postPatch` on `nodejs-slim_26` — citing nixpkgs issue #564449 (chmod 0o4755 → EPERM in sandbox, **deterministic**, Hydra reproduces) and upstream nixpkgs fix commit `089b82f9` ("drop once the lock carries it") |
| 11:00 | **The shim does NOT reach the failing derivation.** Evidence: the failing drv path is `/nix/store/njhj371sv6q9b1h2lwxj49gf8yckyb6f-nodejs-slim-26.9.0.drv` — **byte-identical** to the drv that failed on 09-19 15:23 (cited in `docs/status/2026-09-19_16-53_…`). The shim landed 19:31, AFTER that failure. A `postPatch` change necessarily changes the drv path. Same path today ⇒ the drv the 10:21 deploy built **never saw the shim** (consumer resolves nodejs from outside our overlay — likely hermes/llama-cpp's own locked nixpkgs subtree, or a differently-named attr) |
| 11:00 | User requested this report; session halted before verifying the non-reach mechanism |

Also observed: 6 consecutive `rc=13` (deploy-lock contention) queue attempts 09:46–10:09 before the 10:21 success — another deploy process held the lock ~25 min; not investigated who (profile did not advance, so it did not ship anything). Parallel sessions are STILL landing work (commits `c9dc44a6`, `067cbe97`, `8dc0bd82` — hot-db tier close-out — arrived during this diagnosis).

---

## a) FULLY DONE (this session)

1. **Queue v5 outcome determined**: rc=1 at 10:53:17, queue self-stopped correctly, no orphan processes left behind by me
2. **Root cause isolated to a single derivation**: nodejs-slim-26.9.0 checkPhase, test `test-fs-cp-async-file-modes.mjs`; full cascade map extracted from the nh dependency graph (hermes-agent-0.21.3 → npm-12.0.2 → nodejs chain → toplevel)
3. **False long-pole model corrected**: the "2h15m from source" framing was wrong — the 10:21 run reached checkPhase in ~28 min on a calm box. The actual pole was never compile time; it is a **deterministic test failure** (per the shim's own comment: EPERM on setuid-bit chmod in sandbox, Hydra-reproduced). Retrying cannot fix it
4. **Shim discovered + empirically proven ineffective**: drv-path identity across pre-shim (09-19 15:23) and post-shim (09-20 10:21) failures is conclusive — no re-eval needed to know the shim never entered this build
5. **nixpkgs context pinned**: lock `e554fab` (20260917) predates upstream fix `089b82f9`; default `nodejs-slim` in the lock is 24.20.0, so this is entirely the hermes/llama-cpp `_26` chain
6. Todo list restored and re-anchored to reality (deploy blocked, F06+ deferred)

## b) PARTIALLY DONE

1. ~~**Root-cause chain: ~90%.** WHAT fails and THAT the shim misses it is proven. **WHY** the shim misses it is not yet verified — candidate mechanisms (unverified): (a) hermes/llama-cpp resolve nodejs from their own flake-input nixpkgs subtree (unfollowed lock), not the root overlaid instance; (b) the consumer uses a different attr name (`nodejs_26` / dash-form) than the shimmed `nodejs-slim_26`; (c) the overlay's `optionalAttrs isLinux` gating mis-fires somewhere in the path. The 10-minute verification: eval the nodejs-slim drv **from the toplevel's perspective** (`nix eval .#nixosConfigurations.evo-x2.config...` or `nix path-info` on the rebuilt input) and compare against `njhj371…`~~ done (mechanism proven via nix why-depends — hermes evaluates overlay-less against the followed nixpkgs; doctrine in the AGENTS.md nodejs-slim saga bullet)
2. ~~**F05 (deploy lands)**: validation green, eval fixes in tree, but the build leg failed — blocked, not abandoned~~ done (deploy landed — system-786 anchored 14:08 (fc49dbe5), 787, then 791)

## c) NOT STARTED (all gated on the deploy)

1. ~~F06–F09: mirror live verify (findmnt /boot-mirror, contents, df)~~ done (F06–F09 done per 2026-09-20_15-30 (mirror verified, 312M/4.0G))
2. ~~F10: pre-reboot-check §11 WARN-grade~~ done (pre-reboot-check §11 WARN grade done per 15-30)
3. ~~F11–F12: `nix run .#boot-mirror-activate` (Samsung first in BootOrder)~~ done (boot-mirror-activate ran — Boot000C Samsung-first per 15-30)
4. ~~F13: pre-reboot-check §11 FAIL-grade~~ done (F13 23-pass/0-fail strict grade per 15-30)
5. ~~F14–F15: CHANGELOG entry + plan-doc checklist ticks 6/7/9 (`docs/planning/2026-09-18_19-53_SAMSUNG-2ND-BOOT-DISK-PARETO-PLAN.md`)~~ done (CHANGELOG boot-mirror entry + plan ticks 6/7/9 per 15-57 §a.8)
6. ~~F16: pathspec commits + push (authorized)~~ done (pushed 541fab97 (15-57 §a.9))
7. ~~F17: final report with M1–M12/F01–F27 tables + reboot handoff~~ done (artifact = docs/status/2026-09-20_15-30_boot-mirror-armed-samsung-first-bootorder.md)
8. ~~The shim-reach fix itself (and deciding shim-vs-nixpkgs-bump)~~ **Won't implement — superseded — root nixpkgs bumped carrying upstream fix (8253c632); harmful shim removed 1bfe5ae2.**

## d) TOTALLY FUCKED UP

Nothing destructive this session (no edits, no commits, no state changes beyond todos). Honest failures, mostly inherited from prior context but validated by today's evidence:

1. **The shim was declared a fix without a drv-path proof.** A parallel session (or the tree's collective narrative) treated "shim committed" as "blocker removed". Nobody ran the 10-second check that the failing drv path CHANGED. Result: today's deploy burned a 31-minute queue cycle (plus the parallel session's earlier attempts) on a build that was known-doomed at eval time. This is the same class as the "email_state fixture ≠ prod truth" lesson: validate against the artifact, not the source text
2. **The 10:38 handoff report (prior context) said "validation passed with all fixes in tree" — misleading.** Eval-validation cannot see an ineffective override. "Validation passed" and "the fix reaches the derivation" are different claims; the report conflated them
3. **The overnight 2h45m build was doomed from the start** (deterministic test failure), but was framed as "long pole needs quiet time". I (prior context) modeled the blocker as TIME when it was CORRECTNESS. Today's 28m11s run falsifies the time model definitively
4. **Queue design gap (minor):** the queue treats rc=1 as "stop for diagnosis" (correct), but had this been rc=12 it would have retried a deterministically-failing build forever within the 8h deadline. A "same drv failed twice → stop" guard would self-diagnose this class

## e) WHAT WE SHOULD IMPROVE

1. **Drv-path diffing as the standard fix-verification for any overlay/override change**: before declaring a nixpkgs-level blocker fixed, `nix eval` the affected derivation path from the CONSUMING flake's perspective and assert it differs from the previously-failing path. Ten seconds, would have saved hours
2. **"Validation passed" language discipline**: status reports should say *what kind* of validation (eval-only vs drv-identity vs build) — eval-green is the WEAKEST signal and must never headline a blocker-closeout
3. **Queue v6 hardening** (when relaunched): stop-on-same-drv-twice, and log the failing drv path into the log on rc=1 for instant diffing
4. **When a shim exists but the failure persists, check reach FIRST, mechanism SECOND** — the empirical drv-path proof outranks reading the overlay code for why it *should* work
5. **Consider fixing this class at the lock instead of the overlay**: nixpkgs `089b82f9` disables the test upstream; if a newer nixpkgs rev is otherwise acceptable, a lock bump makes the shim (and its reach problem) disappear. Tradeoff: full-rebuild cost + parallel-session coordination on a shared lock — a user/policy call, not mine to make unilaterally (see question 3)

## f) NEXT WORK (priority order, not all 50)

1. ~~**Verify shim non-reach mechanism**: eval nodejs-slim drv from evo-x2's package set; compare to `njhj371…` (10 min)~~ done (mechanism proven via nix why-depends; rule harvested to AGENTS.md)
2. ~~**Fix the reach**: either extend the shim to the actual consumer path (hermes.nix / llama-cpp pin) or bump the specific input whose subtree owns the nodejs drv~~ **Won't implement — superseded — lock bump picked up the upstream fix (see c.8).**
3. ~~Confirm the fix by drv-path change + `nix build` of just that drv (`^*` with `-L`), NOT a full deploy~~ done (drv rebuilt clean post-bump; deploys system-786→791 landed)
4. ~~Relaunch queue v6 (`systemd-run --user --unit=boot-mirror-deploy-v6 --collect $HOME/.local/state/boot-mirror-queue.sh`) — expect ~30–40 min build now that everything else is warm~~ done (queue v6/v7 ran to success)
5. ~~If rc=0 + profile advanced → F05 done; run the F06–F17 chain as scripted in the 10:38 handoff~~ **Won't implement — moot — rc=0 path taken.**
6. ~~If rc=13 again: wait 180 s, check whether the parallel carrier shipped our tree (profile ≠ system-785 AND /boot-mirror mounted = success path)~~ **Won't implement — moot — rc=0 path taken.**
7. ~~Sweep the rc=13 lock-holder mystery (09:46–10:09): identify what held the deploy lock 25 min without advancing the profile~~ done (holders identified as the parallel deploy.sh/nh pair (12-26 §d.1))
8. ~~Investigate why `nix log` on the failed drv returned empty (GC'd log? need `-L` rebuild?) — low priority, `-L` rebuild in step 3 supersedes~~ **Won't implement — superseded by the -L rebuild.**
9. ~~Check whether cache.home.lan (attic) can/should serve the e554fab-era nodejs chain (recurring gap: second from-source nodejs build this week)~~ **Won't implement — moot — zero nodejs drvs post-bump.**
10. ~~After F16: harvest the "drv-path diff" rule into AGENTS.md Nix & Nixpkgs gotchas + the shim comment (once the real mechanism is known)~~ done (landed in the AGENTS.md nodejs-slim saga bullet)
11. ~~After deploy lands: mirror verify (F06–F09), pre-reboot-check WARN (F10), activate (F11–F12), pre-reboot-check FAIL (F13)~~ done (F06–F13 done per the 15-30 report)
12. ~~CHANGELOG + plan-doc ticks 6/7/9 (F14–F15), pathspec commits + push (F16)~~ done (CHANGELOG entry + ticks + push 541fab97)
13. ~~Final report with M1–M12 + F01–F27 tables, reboot handoff (F17)~~ done (final reports = 2026-09-20_15-30 + 15-57)
14. ~~Post-activation backlog (from prior reports): 04:17 reboot forensics if not user-initiated; crush-session load policy; llama-vlm model downloads; hot-db Phase-2 module fold-in (parallel session's close-out)~~ done (04:17 attributed (19-47 §a.9); hot-db Phase-2 module landed dormant; llama-vlm routed to docs/todo/ai-stack.md)
15. ~~Queue script hygiene: fix the "queue v4:" prefix in v5+ logs; add drv-path logging~~ **Won't implement — moot — queue v6/v7 retired after success.**

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. ~~**The 04:17 reboot — was it you?** (Unanswered since the prior report.) If not user-initiated, it needs crash forensics (it killed a 2h45m build; journal cut mid-build would confirm crash vs clean shutdown) — and it would be freeze/crash #7 territory~~ done (answered — 04:17 reboot attributed to the parallel deploy session (19-47 §a.9))
2. ~~**Is the parallel session that authored the nodejs shim (commits around `8740c661`, 09-19 19:31) still active and owning the nodejs/hermes chain?** I can see its commits (hot-db close-out landed during this diagnosis) but not its intent — if it is mid-diagnosis of the same non-reach problem we will collide on the fix~~ **Won't implement — moot — shim removed, no owner active on it.**
3. ~~**Shim-fix vs nixpkgs lock bump:** nixpkgs upstream already disabled this test (`089b82f9`). Fixing the shim's reach keeps the lock stable but adds a local override to maintain; bumping nixpkgs picks up the upstream fix but forces a full system rebuild on a multi-session tree mid-deploy-queue. Which do you prefer (or: bump only if the rebuild cost is acceptable)?~~ **Won't implement — decided — lock bump over shim (8253c632; shim removal 1bfe5ae2).**

---

**Bottom line:** the deploy is blocked by ONE deterministic test failure in ONE derivation. The fix for it already exists in the tree but provably never reaches the failing build. Next session: prove the reach mechanism (10 min), fix it, rebuild the single drv, relaunch queue v6. Everything downstream (F06–F17) is unchanged and waiting.

*Waiting for instructions.*
