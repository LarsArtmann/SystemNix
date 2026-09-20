# Boot-Mirror Deploy #2 — One Unit Left (cv-server), Profile Still Un-Anchored

**Date**: 2026-09-20 13:58 · **Session**: 13:15 → 13:58 (continuation of the 11:02 handoff)
**Headline**: Deploy #2 (13:44) shipped 5 root-cause fixes and shrank the activation failure list from 6 units to exactly ONE (`cv-server`). The profile is STILL `system-785` — one cv-server permissions issue away from anchoring. The running system IS the newest config (`/run/current-system` = `sja3gp7j…`). **A reboot still reverts.** Queue v7 is live and re-attempting every ~5 min (deadline 21:39).

## Context (one paragraph)

The 11:25 deploy exited rc=3 with an un-anchored profile. Diagnosis this session found the rc=3 smoke verdict was SECONDARY: the activation had ALSO exit-4'd on six failing units (cv-server, hot-user-caches ×2, discordsync-db-heal, buildcache automount, service-health-check), and exit-4 is what skips the profile bump. Both NEW smoke failures were also root-caused. Five of the six activation blockers were fixed by me this session; the sixth (cv-server) received a heal from a parallel session (`4cedd16d`, 12:59) that deploys and runs but does not converge.

## a) FULLY DONE

1. **Complete evidence-based diagnosis of every exit-4 contributor and both NEW smoke failures** — no speculation left: each has a mechanism, a journal line, and a fix or an owner.
2. **Browser History deadlock root-caused AND the gate fixed + verified live**: the flake input moved `0971fe9c → 10fe5d8a` in the 2026-09-18 18:47 mass lock update (`7acbdbe4`); the new binary's `AGENT_FRESHNESS` health component makes a restarted server answer 503 "degraded" (db ok, `agents.expected=true`) until the first agent ingest. The old gate (`curl -sf --retry-all-errors`) demanded 200 → agent never ran → zero ingests → server never recovered (90+ min wedged, verified: 0 `/ingest` requests 11:52→13:54). Gate now proceeds on any `[1-9][0-9][0-9]` status. **Live proof 13:54:51**: `server answering (HTTP 503) — proceeding` → agent ran → profiles extracted.
3. **hot-user-caches: 3 real bugs fixed** (`modules/nixos/services/hot-user-caches.nix`): (1) `chmod 0700` EPERM on the freshly chown'd subvol — `CAP_FOWNER` added (chmod is FOWNER-gated for non-owners; CAP_DAC_OVERRIDE does NOT cover it); (2) sysinit ordering cycle (`local-fs → automount → bootstrap → sysinit → local-fs`, "Transaction order is cyclic" in the 11:41 journal) — `unitConfig.DefaultDependencies = false` added; (3) the go-build cache entry mounted at an HM `mkOutOfStoreSymlink` path — systemd canonicalized it to `mnt-buildcache-go\x2dbuild.automount`, an autofs NESTED INSIDE the `/mnt/buildcache` autofs, failing at load — entry removed with full rationale in-module.
4. **forgejo-subvol-bootstrap latent sibling fixed** (`modules/nixos/services/forgejo.nix`): same missing-`CAP_FOWNER` pattern (would fail the day dedicated mode is enabled).
5. **discordsync-db-heal timeout 10→20min** (`modules/nixos/services/discordsync.nix`): the ~11G integrity check read 9.4G across its entire 10-min budget under deploy churn and was SIGTERM'd mid-check (11:41, exit-4 contributor). Post-fix: started CLEAN in deploy #2 (in the "new units started" list).
6. **deploy.sh provisioner list cleaned**: `hot-user-caches-go-build-bootstrap` removed with the cache entry (comment updated).
7. **tests/test-cv.nix: co-import of `deploy-restart-audit.nix`** — fixed a flake-check RED introduced by the parallel session's `allowUnits` exemption (the documented options?-guard-inside-mkIf trap: the def at an undeclared path errors the merge before its guard runs). `nix flake check --no-build` GREEN afterward.
8. **evo-x2 toplevel eval GREEN** with all fixes (drv `dj6q23ks…`), and the built system activated as `sja3gp7j…`.
9. **AGENTS.md harvest landed (6 doctrines, 4 edits)**: FOWNER-chmod rule, DefaultDependencies-for-before-automount rule, symlink-canonicalized-mounts rule, overlay-non-reach + drv-path-diff + harmful-shim-lifecycle, the browser-history gate-deadlock rule, anchor-check-first.
10. **Pocket ID NEW-failure classified as transient**: exactly 2 SQLITE_BUSY lines at 11:42:53 during the deploy restart storm (ratelimit-actor deactivation); journal clean in every window since.
11. **Side sweep**: the deploy's REMOVED paths confirmed expected (bank-sync fish completions, `51-hdmi-monitor-priority.conf` — the documented smart-audio resolution).
12. **Rogue llama finding documented**: two hermes-user llama-servers (PID 805159/805161, started 05:40, 8h runtime, 2.1G+2.0G RSS, one at 20.4% CPU) holding FOUR rogue listeners: 8848/8849 (llama-rag's config-DISABLED ports) + 8127/8128 (llama-vlm's dark ports). These kept memory PSI at 28-41% and closed the deploy pressure gate for ~5 min.

## b) PARTIALLY DONE (in progress)

1. **Deploy #2 anchoring**: build ✓, activation advanced `/run/current-system` to the newest config, but the profile stayed `system-785` because `cv-server.service` alone still fails during the transaction (exit 4 → bump skipped). The smoke was still running at report time; predicted outcome: the failure set equals the 11:53 baseline (CV ×4 + FastFlowLM, with browser-history 503 now same-as-baseline) → rc=0 → the queue enters its documented retry loop (redeploy every ~5 min re-attempts cv-server; each cycle restarts the provisioner set; deadline 21:39).
2. **Browser History: deadlock broken, degradation remains** — the agent now RUNS through the 503, but with quiet browsing it reports `no new visits to send` and sends NOTHING → the server's freshness (which counts only successful pushes) stays degraded. Functional data path is healthy; the 503 will clear on the first real browsing session (or an upstream empty-batch heartbeat).
3. **cv-server: heal deployed + running but NOT converging** — `cv-state-perms.service` (parallel session's fix) runs and "Finished" on every cv-server start attempt (13:50:40/45/50 ✓), but the upstream content-sync still hits `rm: cannot remove` EACCES ×90. Suspected: the heal's FAST PATH checks ownership only (`! -user cv -o ! -group cv`) and exits 0 when ownership is converged, never running the `chmod u+w` walk — a mode problem (dir without write bit) would persist invisible. Needs ONE root-side inspection to confirm (see question 1).
4. **Queue v7 lifecycle**: running as user unit `boot-mirror-deploy-v7.service`; I cannot stop it without `systemctl` (banned in my shell). If the user wants the cycling stopped: `systemctl --user stop boot-mirror-deploy-v7`.

## c) NOT STARTED

- F06-F09 mirror verification (blocked on anchor; the queue's SUCCESS block auto-captures findmnt/ls/df).
- F10 `nix run .#pre-reboot-check` exit 0.
- F11-F12 `nix run .#boot-mirror-activate` (Samsung FIRST in BootOrder).
- F13 post-activation pre-reboot-check.
- F14 CHANGELOG entries for THIS session's fixes (the cv-state-perms entry already landed from the parallel session).
- F15 plan-doc ticks 6/7/9 (leave 8 = reboot).
- F16 proper commit messages + push (my 5-file fix set rode daemon heuristic `e0f287ab`; push is authorized but deferred).
- F17 final report with M1-M12 + F01-F27 tables + reboot handoff.
- F18-F27 (user-gated / post-reboot / next-day).

## d) TOTALLY FUCKED UP (honest ledger)

1. **The 11:25 deploy (previous session) shipped with no triage plan** for a large nixpkgs delta, anchor checked LAST, and the rc=3 report framed the smoke regression as THE blocker — this session proved the anchor blocker was the activation exit-4 stack (6 units), which the smoke verdict only shadowed. Two deploys were needed where one honest anchor-check-first could have caught the shape at 11:53.
2. **My browser-history fix is half a fix**: I verified the gate logic locally but never checked whether a quiet-browsing agent run actually produces an ingest. It does not ("no new visits to send") — the server stays 503-degraded until real browsing occurs. The deadlock (agent permanently blocked) IS fixed; the symptom (503) is NOT.
3. **I did not scope the pressure source BEFORE launching queue v7** — it sat ~5 min on mem PSI from the rogue hermes llamas; five minutes of diagnosis first would have set expectations.
4. **cv-server was left to a parallel session's heal without a convergence proof**: I trusted `cv-state-perms` (committed 12:59) without verifying it actually fixes the rm EACCES — it does not (fast-path ownership check skips the chmod walk). I then hit a wall: no root access to inspect `/var/lib/cv/assets` permissions, so the LAST blocker is now user-gated when it could have been diagnosed at 13:50.
5. **Predicted-not-verified at report time**: the deploy #2 smoke verdict and queue behavior (retry loop) are PREDICTIONS from the baseline mechanics, not observed lines — the smoke had not finished when this report was written.

## e) IMPROVEMENTS (concrete, with file paths)

1. `modules/nixos/services/cv.nix` — `cv-state-perms` fast path must ALSO detect non-writable dirs (e.g. `find "$state" -xdev -type d ! -perm -u+w -print -quit`), or the chmod walk must run unconditionally when cv-server keeps failing (cheap; the walk is idempotent).
2. Upstream `~/projects/browser-history` — the agent should send an empty-batch heartbeat (or the server should count successful agent AUTHs/extracts, not only data pushes): quiet browsing days keep the server 503-degraded BY DESIGN, which is monitor noise, not an outage.
3. systemd-shape-audit candidate: reject `curl -sf`/`--fail` in ExecStartPre readiness gates (any-status-answered should be the house pattern — this session's deadlock is the canonical case).
4. Lint candidate: bootstrap scripts whose `chmod` runs under `harden{}` without `CAP_FOWNER` in the bounding set (static grep over module sources; today's two instances are the evidence).
5. Eval-time assertion candidate: `fileSystems` mountPoints must not be HM-managed symlink targets (the go-build canonicalization class).
6. `~/.local/state/boot-mirror-queue.sh` — on rc≠0 or rc=0-without-anchor, log WHY (name the failed units inline next to the rc line) so the next session doesn't re-grep the whole log.

## f) NEXT UP TO 50 THINGS (ordered)

1. Answer question 1 (root inspection of `/var/lib/cv/assets`) → confirm heal fast-path hypothesis.
2. Patch `cv-state-perms` fast-path per e.1 (2-line change) OR hand the finding to the owning parallel session.
3. Watch queue v7: next cycle re-attempts cv-server → if the heal is patched, activation goes clean → profile bumps past system-785 (F05 COMPLETE).
4. Verify anchor after next clean activation: `readlink /nix/var/nix/profiles/system` ≠ system-785 AND == `/run/current-system`.
5. Confirm the deploy #2 smoke verdict + queue state (predicted rc=0 retry loop; verify in log).
6. Decide the rogue llamas (question 2) — killing them frees 4.2G + 20% CPU + reopens the pressure gate headroom.
7. F06: `findmnt /boot-mirror` UUID `4F53-C156`, rw, vfat (queue SUCCESS block auto-logs this).
8. F07: `ls /boot-mirror` loader/EFI/entries (queue SUCCESS block; else via pre-reboot-check §11).
9. F08: `df -h /boot-mirror` sane vs 4G.
10. F09: `boot-mirror-sync` ran clean (§11 output).
11. F10: `nix run .#pre-reboot-check` → exit 0, §11 WARN-grade.
12. F11: `nix run .#boot-mirror-activate` → ✓ line.
13. F12: BootOrder Samsung FIRST, QLC `0x0001` SECOND (activate output).
14. F13: re-run pre-reboot-check → exit 0, §11 FAIL-grade.
15. F14: CHANGELOG entries — this session's 5 fixes + deploy #2 narrative (re-read CHANGELOG.md fresh first; parallel sessions keep it dirty).
16. F15: tick `docs/planning/2026-09-18_19-53_SAMSUNG-2ND-BOOT-DISK-PARETO-PLAN.md` items 6 (line 34), 7 (line 35), 9 (line 37); leave 8 (reboot).
17. F16: fold proper messages into the daemon commits (`git show --stat HEAD` first — amend ONLY if the commit is exactly my file set; else a `git commit --amend` on the right HEAD or note attribution in the push) → `git push` (authorized).
18. F17: final report with BOTH M1-M12 + F01-F27 tables (`docs/planning/2026-09-19_10-48_…` lines 48-95) + reboot handoff + post-reboot proof steps (`bootctl status` Current Boot Loader PARTUUID `023f66c0-…`).
19. Verify browser-history recovers to 200 on the user's next browsing session (or ship the upstream heartbeat first).
20. File the upstream browser-history heartbeat issue/PR (e.2) in `~/projects/browser-history`.
21. Confirm with user: was the 11:06 root nixpkgs bump (`8253c632`, e554fab → 20b1ddd) deliberate (unanswered since 12:15).
22. Confirm with user: was the 04:17 reboot user-initiated or a crash (forensics if crash; unanswered since 12:15).
23. Ask user for reboot timing (question 3) — the system is reboot-revertible until anchored.
24. After anchor + activate: hand the reboot to the user (F17/M7 — always user-owned).
25. Post-reboot (user-gated): F18 `bootctl status` PARTUUID proof.
26. Post-reboot: F19 pre-reboot-check green from booted state.
27. Post-reboot: F20 QLC fallback still second (+ optional firmware-menu fallback boot test).
28. Next morning: F21 first-nightly drift watch (boot-mirror-sync re-ran, no diff drift).
29. Flag the hot-user-caches go-build integration gap to the owning session (parked relocation; needs HM-symlink gating + boot-order design — rationale now in-module).
30. e.3: readiness-gate lint (`curl -sf` rejection) as a systemd-shape-audit class + negative test.
31. e.4: FOWNER-vs-chmod lint candidate.
32. e.5: mountPoint-vs-HM-symlink eval assertion candidate.
33. e.6: queue rc-line context improvement (failed-unit names inline).
34. Identify the 11:06 bumper session if not the user (git author was `Lars Artmann <git@lars.software>` = daemon; the driving session is whoever edited flake.lock before it).
35. Identify the 09:46-10:09 deploy-lock holder (parallel deploy during the morning — low priority).
36. `nix log` empty-output mystery from the morning session (low priority).
37. Attic/cache.home.lan substitution coverage spot-check (was partial in the morning build).
38. Note nvme enumeration drift: mirror ESP now `nvme1n1p1` (was nvme0n1p1 at handoff) — always derive by UUID `4F53-C156`; consider an AGENTS.md line if not already implied.
39. Watch the llama-rag-dark-guard Gatus check: it should be RED on the 8848/8849 rogues (working as designed) — confirm it fired.
40. If rogues are killed: confirm the dark-guard check clears and mem PSI drops below 20 sustained.
41. Review whether the queue's mem<20 gate should correlate with io PSI + zram (the freeze calibration) rather than raw memory PSI — the 69%-available box was deploy-blocked for 5 min by reclaim churn (owner doctrine decision, NOT a unilateral change).
42. Consider `Type=notify`/`sd_notify` support gaps: none — skip (no change needed; listed for completeness of the audit backlog).
43. Sweep `docs/todo/` domains for items unblocked by the anchor (storage.md mirror entries).
44. After F16 push: verify GitHub Actions nix-check goes green (CI was dark for private-input reasons — NIX_GITHUB_RO_TOKEN status unchanged).
45. CHANGELOG: also record the deploy #1→#2 un-anchored-generation lesson (already in AGENTS.md anchor-check-first).
46. Post-anchor: re-run `scripts/post-deploy-check.sh` standalone once to freeze a NEW baseline (Browser History 503 will age out of the baseline set on the first healthy run).
47. Confirm CV smoke checks go green once cv-server starts (the 4 baseline fails should clear — watch for NEW failures appearing from the CV content re-sync, e.g. /export/pdf typst).
48. cv.nix: the parallel session may still be iterating — coordinate before touching (content-pin + `git status` check).
49. The hermes llama-vlm usage (if rogues are legit work): wire the llama-vlm consumer properly or add idle-stop to the hermes-side spawns (owner decision).
50. Consider adding this session's report link to the 12:15 report (cross-reference chain for the next session).

## g) UP TO 3 QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **cv-server last blocker — I need one root-side inspection** (no root in my shell): `sudo ls -la /var/lib/cv/assets /var/lib/cv/assets/fonts | head -30` and `sudo namei -l /var/lib/cv/assets/fonts/montserrat/italic`. The heal chowns everything to cv:cv and its fast path then exits 0 — but the content-sync rm STILL gets EACCES ×90. I suspect directory MODE (no write bit) or a namespace/ReadWritePaths issue the ownership-only fast path cannot see. With that output I can ship the 2-line heal fix and the queue anchors on its next cycle.
2. **Rogue hermes llama-servers (PID 805159/805161, 8h old, 4.2 GB, ports 8848/8849/8127/8128, one at 20% CPU)**: kill them? They held the deploy pressure gate closed and pin memory. `sudo kill 805159 805161` — or leave them if hermes is actively working (they occupy llama-rag's DISABLED ports and llama-vlm's dark ports, i.e. the exact rogue class the dark-guard was built to catch).
3. **Reboot timing** (still unanswered from 12:15): until the profile anchors, ANY reboot/crash reverts the running system to system-785. When do you plan to reboot? This calibrates whether I should push the cv-server fix through the queue immediately (I will) and whether the mirror activation (F11) should wait for your presence.

## Ops state at report time

- Profile `system-785` (UN-ANCHORED); `/run/current-system` = `sja3gp7j…` (newest, carries all 5 session fixes + parallel session's cv heal + hermes/discordsync stop-exit fixes).
- cv-server: failed/start-limit-hit (the sole activation blocker). CV smoke checks baseline-fail.
- Browser History: agent syncing (gate fixed); server 503-degraded until first real browsing (upstream freshness design).
- FastFlowLM: dead until the owed reboot (corpse-pinned :52626, documented).
- Queue v7 cycling (re-attempts cv-server + provisioners every ~5 min; stops only on rc=3-class failure, anchor SUCCESS, or 21:39 deadline).
- Git: my 5-file fix set + AGENTS harvest committed via daemon heuristics (`e0f287ab` + later sweeps); push deferred to F16. Tree dirty only with in-flight parallel work if any.
- Do NOT reboot before the profile anchors.
