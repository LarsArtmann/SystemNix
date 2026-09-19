# Deploy-Fix Session: systemd-graph Hash Mispatch + New Toplevel Blocker

**Date:** 2026-09-19, 16:53 CEST
**Session scope:** Fix the failed `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (build-time hash mismatch), get the deploy unblocked.
**Verdict:** The reported failure is FIXED and verified. The deploy is STILL BLOCKED by a second, deeper failure (nodejs-slim-26.9.0 build failure) that was hidden behind the first.

---

## What happened (timeline)

| Time (CEST) | Event |
| --- | --- |
| ~14:01 | Parallel session's work daemon-committed as `7af9fbf9`: it flipped `pkgs/systemd-graph/webui.nix` line 19 (source fetch hash) FROM the proven `yb3w6/...` TO `MkUfxSvF...`. |
| 14:08 | User's deploy failed: `hash mismatch` in `*-source.drv` (webui.nix's `fetchFromGitHub`) — `specified: MkUfxSvF...`, `got: yb3w6/...`. 44s, 8 errors, config NOT activated. |
| ~15:00 | This session: diagnosed via git history that `7af9fbf9` regressed a hash that had been green since Aug 19 (`995f4f8d`). Reverted line 19 to `yb3w6/...`. |
| ~15:05 | Built `.#systemd-graph` → SECOND hash mismatch surfaced: the `pnpmDeps` FOD (`zZQ2/...` stale, `got: MkUfxSvF...`). |
| ~15:07 | **Root cause understood:** the nixpkgs bump (26.11.20260917.e554fab) staled the `fetchPnpmDeps` hash; the parallel session computed the new got-hash `MkUfxSvF...` and **pasted it into the WRONG attr** — the `fetchFromGitHub` source `hash` (line 19) instead of the `pnpmDeps` `hash` (line 35). My line-19 revert + placing `MkUfxSvF...` at line 35 fixed both. |
| ~15:10 | Full systemd-graph chain builds GREEN (pnpm-deps FOD, vite build, go-modules, final binary `w8ja1d28.../bin/systemd-graph`, 8 MB, correctly renamed from `server`). |
| ~15:12 | Waited out the parallel session's 21-min toplevel build (PID 3673071) to avoid stacking build IO (IO PSI avg10 was 35-43% all session). |
| ~15:15 | Ran my own toplevel `--keep-going`: **35 build errors**. Piped through `tail -30` → saw only the cascade tail. |
| ~15:23 | Re-ran with full log capture → `~/.local/state/deploy-logs/toplevel-151231.log`. Root cause of ALL remaining failures: **`nodejs-slim-26.9.0` — "builder failed with exit code 2"** (a real compile failure, not a hash mismatch). Everything else (nodejs, npm, hermes-tui/web/agent-0.21.3, llama-cpp-0.4.1, llama-server-rocm, llama-vlm units, man-paths, system-path, polkit/dbus-broker units, system-units/user-units/etc/activate/toplevel) is cascade. |
| 16:53 | Tree state verified clean: my fix daemon-committed (`570a2fa8` + `4137c79c`), both hashes correct in HEAD. A parallel session was building `.#telephony-browser` (PID 81166) during the session. |

## Direct answers to the three questions

**What did you forget?**
- I did not re-check `git status` immediately before each edit to a file a parallel session had touched 20 minutes earlier (multi-agent rule). I got lucky; the file could have been mid-edit.
- I did not consider that a `got:` hash has THREE possible destinations in one package (source hash / pnpmDeps hash / vendorHash) and asked "which attr is stale?" only implicitly — the parallel session's mispaste proves this ambiguity is a real trap class. I initially assumed the source-hash story was the whole story; only building it revealed the second stale hash.
- I did not verify my own verification step: the second log run's root-error grep came back EMPTY and I proceeded to report time without interrogating why (answer: the nodejs-slim failure was CACHED, so the re-run printed only "Reason: builder failed..." summaries with no build body, and my `error:` pattern missed `error (ignored):`; I needed `-L` for build logs).

**What could you have done better?**
- NEVER pipe build output through `tail -30` when failure analysis is the goal — capture to a file first, then filter. The AGENTS.md grep-capture lesson exists for exactly this; I repeated it and wasted a full toplevel eval cycle (~8 min) re-running.
- Check for concurrent `nix build` processes BEFORE starting my own, and read their exit/results — the parallel session's 21-min build had already attempted nodejs-slim; its failure was knowable earlier.
- Run the failing FOD directly with `-L` (`nix build /nix/store/...-nodejs-slim-26.9.0.drv -L`) to get the actual compiler error instead of stopping at the cascade.

**What could you still improve?**
- Deploy under force-pressure was racing a storm (IO PSI avg10 35→52% during my builds; freeze #5 died 9s into a deploy). I queued my heavy build behind the parallel one but still built into rising pressure.
- The deploy fix should have been PATHSPEC-committed with a real message immediately (daemon buried it in heuristic commits instead — acceptable but lossy for history).
- No fencing against the parallel session reverting my fix (it flipped this exact line 20 min earlier). Verified intact at 16:53, but the race window was real.

---

## a) FULLY DONE

1. Root-caused the 14:08 deploy failure: `7af9fbf9` (daemon commit of parallel-session work) regressed `webui.nix:19` from the proven source hash `yb3w6/...` to `MkUfxSvF...`.
2. Understood the TRUE mechanism: `MkUfxSvF...` is the NEW `fetchPnpmDeps` got-hash (staled by the nixpkgs bump); it was pasted into the source-fetch hash attr by mistake. Both hash slots are now correct (line 19 `yb3w6/...`, line 35 `MkUfxSvF...`).
3. Verified end-to-end: `nix build .#systemd-graph` green — pnpm-deps FOD, webui vite build, go-modules (vendorHash still valid), final 8 MB binary correctly renamed (`bin/systemd-graph`).
4. Fix is committed (daemon `570a2fa8`/`4137c79c`) and verified intact in HEAD at 16:53.
5. Full toplevel failure inventory captured to a persistent log: `~/.local/state/deploy-logs/toplevel-151231.log` (227 lines, 35 Cannot-build lines, exactly ONE root failure).
6. Avoided IO stacking with the parallel session's 21-min toplevel build (polled with heartbeats, started only after it exited).

## b) PARTIALLY DONE

1. **Toplevel build enumeration:** done once with full logging; root failure identified (nodejs-slim-26.9.0, exit code 2) but the ACTUAL compiler/build error is still unknown (cached failure hides the body; needs `-L` re-run).
2. **Deploy:** not re-attempted — still blocked by the nodejs cascade (~18 derivations downstream: nodejs/npm, hermes-agent-0.21.3 chain, llama-cpp-0.4.1 + llama-vlm units, man-paths/system-path, polkit/dbus-broker units, system-units/user-units/etc/activate).
3. **Multi-agent coordination:** parallel session flagged (it authored both the mispaste and a concurrent `.#telephony-browser` build) but not contacted/fenced.
4. Post-deploy verification: designed but not executable (deploy hasn't happened).

## c) NOT STARTED

1. Diagnosing WHY nodejs-slim-26.9.0 dies with exit code 2 (`-L` build log needed).
2. Fixing it / working around it (OOM? nixpkgs 26.9.0 genuine breakage? disk?).
3. The actual deploy + pressure-gated retry semantics (exit 12 pressure / exit 13 lock handling).
4. Post-deploy verification suite: anchoring check (`/run/current-system` vs numbered profile), failed units, `nix run .#post-deploy-check`.
5. Verifying the §10 auto-loan metrics materialize post-deploy (`forgejo_mirror_dead_candidates`, `forgejo_mirror_health_scrape_errors`, `papdashboard_services_json_ok`, `system_units_enabled_inactive{,_scrape_errors}`).
6. Hermes 0.21.0 → 0.21.3 post-deploy health check (rode this batch).
7. llama-vlm (cap/e4b) SOAK-TEST under the real units — the module's own deploy warning demands it (freeze-5 lesson: direct-run green ≠ unit green).
8. cv-server :8098 metrics investigation (pre-deploy §10 said "not responding" — auth-gated-401 class vs real outage, undetermined).

## d) TOTALLY FUCKED UP

1. **`tail -30` on the first toplevel build.** Destroyed the root-cause evidence, forced a full re-run. This is the exact "grep-only error capture" class documented in AGENTS.md, repeated by me, today.
2. **Accepted an empty grep result as "log captured".** My root-error extraction returned nothing and I moved on without asking why — the same pipeline-masking discipline failure. The extraction wasn't wrong (cached failures print no bodies), but I didn't KNOW that; I got the right conclusion (root identified) only because I finally read the raw log.
3. **Built into rising IO pressure** (avg10 43→52%) while a parallel session built concurrently, on a box with six recorded freezes, two of them mid-deploy. The deploy gate was force-overridden by the user at 45%; my own heavy commands had no such gate at all.

## e) WHAT WE SHOULD IMPROVE

1. Capture build output to a file FIRST, filter second — make it a reflex, especially for `--keep-going` runs whose value is the full failure enumeration.
2. Every diagnostic grep/pipeline must be followed by "is empty = green or broken?" disambiguation before proceeding.
3. Document the three-destination got-hash trap (source hash vs pnpmDeps hash vs vendorHash) in AGENTS.md Non-Obvious Gotchas — one sentence: "a `got:` hash belongs to exactly ONE FOD; match it to the failing drv name before pasting."
4. Per-session IO budget: check `/proc/pressure/io` before ANY `nix build`, not just deploys; queue behind existing builds (`pgrep -af 'nix build'`).
5. Multi-agent fencing: when a file was modified by another session <1h ago, re-read + re-check `git status` immediately before AND after the edit, and prefer an immediate authorized PATHSPEC commit over waiting for the daemon.
6. When a `got:` hash appears, paste it ONLY into the attr whose drv name matches the error line.
7. deploy.sh printed the `=== Pre-Deploy Validation ===` banner twice — cosmetic script bug.
8. pre-deploy §11 (vendorHash freshness) warned "unable to determine status" for 6 local Go packages — the check is degraded and caught nothing; the real catch came from the actual build.
9. The daemon committing a regression (`7af9fbf9` flipped a proven hash) with a heuristic message shows shared-file commits need build-before-commit discipline from ALL sessions.

## f) NEXT (50)

**Finish the deploy:**
1. `nix build /nix/store/njhj371sv6q9b1h2lwxj49gf8yckyb6f-nodejs-slim-26.9.0.drv^* -L` — capture the real build failure.
2. Diagnose + fix nodejs-slim (OOM vs nixpkgs breakage vs disk; check dmesg/oomd, `/nix` free space, nixpkgs issues).
3. Re-run toplevel `--keep-going` with output to file until zero root failures.
4. Pre-deploy: re-verify webui.nix hashes + `git status` (clobber check) + no untracked files under modules/.
5. Pre-deploy: check `/proc/pressure/io`; queue the deploy if avg10 ≥20% with disk-busy corroboration (freeze-5 rule) — ask user whether to force again.
6. `nix run .#deploy` (without FORCE if green; handle exit 12 = wait, exit 13 = check if parallel session's deploy advanced the profile first).
7. Post-switch anchoring: `readlink /run/current-system` == `/nix/var/nix/profiles/system`.
8. `systemctl --failed` clean (via `nix run .#post-deploy-check`).
9. Verify systemd-graph live: unit active, `graph.home.lan` serves, running binary == `w8ja1d28...`.
10. Verify §10 loan metrics now exist in `/metrics`.
11. Hermes 0.21.3 health: unit active, no new ERROR classes in journal vs 0.21.0 baseline.
12. llama-vlm: if enabled, soak-test under REAL units (module header instruction) before anyone decommissions anything.
13. Confirm llama-rag still config-disabled.
14. flm: confirm no EADDRINUSE corpse recurrence post-deploy (pre-deploy said clean).
15. cv :8098: determine why metrics were "not responding" pre-deploy.
16. Verify mandb unit (new in batch) ran; man-paths built.
17. Watch dbus-broker/polkit/accounts-daemon restart churn post-switch (all rebuilt in this batch).
18. Check memory-emergency-guard Zone 6 trips during the deploy window.
19. Confirm no start-limit-hit units accumulated (flm socket re-arm trap).
20. Root disk headroom after new generations (was 83%/125G free).

**Parallel-session batch follow-ups:**
21. Identify `telephony-browser` (new package another session is building) — status, owner, whether it's tracked.
22. Coordinate with the parallel session: their `7af9fbf9` mispaste caused this incident; their batch (hermes/llama-vlm) owns most remaining cascade failures.
23. PATHSPEC-commit any of MY future fixes with real messages (with authorization) instead of relying on the daemon.
24. Verify pnpm-deps hash determinism: one clean rebuild of the webui FOD (content-addressed; one observation so far).
25. Refresh `docs/services/systemd-graph.md` with the two-hash layout + this incident if it documents packaging.

**Monitoring/hygiene observed this session:**
26. IO PSI avg10 sat 35-52% for ~2h with no obvious single owner — identify the driver (parallel builds, crush-hot-db migration tail, QLC churn).
27. Verify crush-hot-db first migration FINISHED (pending since 2026-09-18: symlink sweep + PSI vs 40-60% baseline).
28. Verify last night's btrbk sends completed (guard-killed 2026-09-18; backup freshness).
29. Verify discordsync-db-heal completed post-freeze-6 (crash-loop amplifier class).
30. Pre-deploy §10: retire monitor365 metrics WARN noise (service disabled since 2026-08-12; permanent WARN every deploy).
31. Fix §11 vendorHash checker (6 false "unable to determine" WARNs).
32. Fix double `=== Pre-Deploy Validation ===` banner in deploy.sh.
33. Sweep eval warnings: `stdenv.isDarwin/isLinux` deprecations + `system` rename across pkgs/.
34. Migrate `programs.rofi.extraConfig` → `programs.rofi.settings` (HM rename warning; rofi is Sway-backup only now).
35. Investigate why nodejs-26.9.0 wasn't substituted (Hydra cache gap for the new nixpkgs?).
36. Consider pre-deploy §0: WARN when concurrent `nix build` processes are active (freeze-6 lesson).
37. After deploy settles: SigNoz traces coverage still green (`signoz_traces_reporting`), Gatus fleet green.
38. Add the got-hash-misplace gotcha to AGENTS.md (see e.3).
39. Harvest the remaining blocker (nodejs-slim) into `docs/todo/` under the owning domain once diagnosed.
40. Rotate old files in `~/.local/state/deploy-logs/` (keep bounded).

**Backlog candidates surfaced by the batch:**
41. hermes-tui/web builds need nodejs — document hermes' node dependency in its runbook.
42. llama-cpp 0.4.1 chain: confirm why it depends on nodejs (web dist?) and whether it can build without it.
43. llama-vlm module: confirm its eval-warning soak-test instructions made it into its docs.
44. §12 listed 6 ExecStart binaries "not built yet" — verify all exist post-build (203/EXEC prevention).
45. eval-cache `error (ignored): SQLite busy` — two concurrent evals contended; cosmetic but noisy.
46. Check whether `.#telephony-browser` belongs in `packages` exposure or needs flake check coverage.
47. Confirm DMS settings backup/restore ran clean in the deploy (deploy.sh step).
48. After green deploy: re-run `nix run .#pre-reboot-check` before any planned reboot (ladder/boot-mirror §11 state).
49. Consider naming the "one root failure hides behind N cascades" pattern in pre-deploy docs — `--keep-going` + root-cause extraction should be a documented one-liner.
50. Report the incident to the parallel session via the shared status-report channel (attribution duty; it may still believe its flip was correct).

## g) Questions I cannot answer myself

1. **Is the parallel session still active and does it own the remaining failures?** It flipped webui.nix 20 min before my fix, daemon-committed it, and is building `.#telephony-browser`. If it is mid-diagnosis of nodejs-slim, we will collide. Should I take the remaining toplevel failures, or hand them back?
2. **Do you want the next deploy HARD-GATED on IO pressure (<20% avg10, no disk-busy corroboration), even if that means waiting hours?** You forced at 45%; freeze #5 died 9 s into a deploy under exactly this class. The nodejs-slim rebuild will itself add significant build IO — deploying fix under storm is the documented exception, but I won't choose it unilaterally.
3. **The tree the deploy carries is a MULTI-SESSION batch** (hermes 0.21.3, llama-vlm cap/e4b, llama-cpp 0.4.1, systemd-graph webui, possibly telephony-browser, DMS/rofi bits). Should the deploy proceed as one batch once nodejs-slim is fixed, or do you want the parallel session's half-landed work excluded/coordinated first?

---

## Evidence pointers

- Failing deploy log (user-provided): `specified MkUfxSvF...` vs `got yb3w6/...` on `*-source.drv`, 14:08:09.
- Regression commit: `7af9fbf9` (2026-09-19 14:01, daemon, 1 file) — diff flips webui.nix line 19 `yb3w6/...` → `MkUfxSvF...`.
- Proven-good hash lineage: `995f4f8d` (2026-08-19, systemd-graph build fixes) — source hash `yb3w6/...` green since.
- My fix (committed by daemon): `570a2fa8`, `4137c79c` — webui.nix lines 19/35 now `yb3w6/...` / `MkUfxSvF...`.
- Green verification build: `/nix/store/w8ja1d286j7393zs346g9kxszrlq69d3-systemd-graph-0-unstable-2026-06-08/bin/systemd-graph`.
- Root blocker: `~/.local/state/deploy-logs/toplevel-151231.log` line 55-56 — `nodejs-slim-26.9.0.drv: builder failed with exit code 2`; 34 downstream cascade failures.
