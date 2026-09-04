# Deploy Exit(4) Triage: flm Corpse Pins :52626 (Reboot-Only) + niri-health-metrics Fixed-Tmp Bug (FIXED)

**Date:** 2026-09-05 00:33 CEST
**Session scope:** Triage of the 2026-09-04 22:28 `nix run .#deploy` failure (two failed units: `fastflowlm.service`, `niri-health-metrics.service`), root-cause both, fix what is fixable in config, verify, document.

---

## Executive Summary

| Unit | Verdict | Action |
| --- | --- | --- |
| `fastflowlm.service` (exit 1, `bind: Address already in use` on :52626) | **Environmental corpse, NOT a config bug.** The Sep-02 `flm-real` thread group died mid-exit; its shared fd table still pins the :52626 LISTEN socket. No live process to kill; SIGKILL meaningless. | **Reboot is the only fix.** No module change. Documented. |
| `niri-health-metrics.service` (`Permission denied` on `niri.prom.tmp`, every 30s tick) | **Real config bug. FIXED this session.** Stale foreign-owned fixed-name `.tmp` in the sticky 1777 textfile dir + `harden{}`'s empty CapabilityBoundingSet = root cannot truncate a file it does not own. | `mktemp`-unique tmp + `chmod 644` + `trap` cleanup + `CAP_FOWNER CAP_DAC_OVERRIDE`. Committed `e2ee6182`. Verified. Deploys unblocked after next `nix run .#deploy`. |

The deploy itself DID activate (config switched) but nh reported `Exited(4)` because of the failed units. Both failures are now fully explained; one is fixed in HEAD; one requires the already-owed reboot.

---

## Evidence Chain (fastflowlm — the corpse)

1. Journal: backend dies in <1s (`Mem peak ~78M`, never reaches model load) with `Error: bind: Address already in use` at every start 22:28–22:35 → restart loop → `start-limit-hit`. Each `:52625` client connection re-requests a start ("immediately on client request").
2. `ss`: :52626 LISTEN with backlog Recv-Q **1862** — a listener that never accepts.
3. `pgrep`/`ps aux`: **no live flm process** — only `[flm-real] <defunct>` (PID 3956893, zombie since Sep 02, parent PID 1, state `Zsl`).
4. `/proc/net/tcp`: the 52626 LISTEN socket is uid **1000** (the fastflowlm service user = `primaryUser`), inode 1268847184, plus **1,771 CLOSE_WAIT** entries on 52626 (probe connections completed by the kernel into the backlog, never accept()ed, peers gone).
5. Thread-group forensics: `ls /proc/3956893/task/` shows TWO tasks — the zombie leader + one X-state sibling. The group's shared fd table keeps the listen socket pinned after the leader is "gone". Non-leader threads are invisible to plain `ps aux` — which is exactly why the wedge "looks like no process at all".
6. Conclusion: the same amdxdna-wedge incident class documented 2026-09-04 (llama corpses). The flm-real group wedged mid-death on Sep 02; nothing running can release the socket. **Reboot-only.** 33 D-state processes remain on the box as of 00:33.

## Root Cause + Fix (niri-health-metrics)

- **Mechanism:** the textfile dir is sticky `1777 nobody:nogroup` (world-writable by design). A manual run of the collector as `lars` during the 2026-09-03 00:2x deploy-blocker debugging session left `niri.prom.tmp` behind (mtime Sep 3 01:13, owner `lars:users`, 0644). The root timer unit carries `harden{}` = empty `CapabilityBoundingSet`, so root's DAC_OVERRIDE/FOWNER are stripped: `open(O_WRONLY|O_TRUNC)` on a file owned by someone else → `EACCES` at the redirect every 30s tick. The failing oneshot fails test-activation → `Exited(4)` blocks every deploy.
- **Why ~2 days undetected as a "fix":** the 2026-09-03 12:28 status report claims `niri.prom` was "freshly written by the root timer" — but the file mtime at triage was Sep 3 01:13. The claim does not match the file evidence (phantom verification); the stale tmp was already blocking by then.
- **Fix (modules/nixos/desktop/niri-config.nix:188-197, 374):**
  - `TMP=$(mktemp "$TEXTFILE_DIR/niri.prom.XXXXXX")` — unique per run; a foreign-owned leftover can never collide again.
  - `chmod 644 "$TMP"` — mktemp is 0600; DynamicUser node_exporter needs o+r (previous redirect+umask produced 0644).
  - `trap 'rm -f "$TMP"' EXIT` — no tmp leak when any later step fails.
  - `CapabilityBoundingSet = "CAP_FOWNER CAP_DAC_OVERRIDE"` on the unit — belt-and-braces so the final `mv` over a foreign-owned target also cannot wedge (memory-emergency-guard precedent, live-proven in this same dir since 2026-08-22).
- **Verification:** derivation builds clean (writeShellApplication + shellcheck); standalone run as lars: the redirect now succeeds, the failure moved to the root-only `mv` (expected for lars), trap cleaned up — `files_before=2, files_after=2`, zero tmp leak, stale file untouched; unit evals with the caps; `nix flake check --no-build`: **all checks passed**.
- **Committed:** niri fix `e2ee6182`; AGENTS.md updates `153b9b71` (+ daemon batch commits; HEAD content verified).

## Documentation (AGENTS.md, committed)

1. FastFlowLM section: corrected the stale "Bumped to v1.0.3 on 2026-08-31" claim — repo pin AND deployed ExecStart are **v1.0.2** (bump `013d1146` was reverted by `49ac851e` "flm v1.0.2 held"; flm self-reports "current v1.0.2, latest v1.0.4").
2. llama/NPU wedge section: new bullet — flm's own corpse pins :52626, full rootless diagnosis recipe (`/proc/net/tcp` uid, `task/` count, `ps -eLo` Z+X pair), reboot-only, do-not-"fix".
3. Desktop gotchas: new rule — hardened-root textfile collectors must use `mktemp` unique tmps, never fixed `$OUT.tmp`; the 1777 dir invites foreign-owned leftovers from any stray manual run.

---

## a) FULLY DONE

1. fastflowlm EADDRINUSE root-caused to the wedged thread group with a complete, rootless, reproducible evidence chain (no sudo needed at any point).
2. Verdict established: environmental, reboot-only; no config change warranted (prevents future agents from "fixing" the module into a second source of truth).
3. niri-health-metrics fixed (mktemp + trap + chmod + caps), committed, shellcheck-clean.
4. Fix verified three ways: derivation build, standalone mechanics run (zero side effects, zero leak), full `nix flake check --no-build` green.
5. AGENTS.md updated with 3 entries + one stale-claim correction (v1.0.3 → held at v1.0.2).
6. Bonus finding while in scope: 8848/8849 each have exactly ONE fresh uid-1000 listener (the deploy's llama starts bound; no duplicate-bind conflict there).

## b) PARTIALLY DONE

1. **Deploy unblocking:** fix is committed but NOT deployed (sudo blocked in this session). The running system still executes the OLD collector and `Exited(4)` recurs on every deploy until the next switch. The config from 22:28 IS activated otherwise.
2. **flm recovery:** root-caused + documented, but the actual recovery is the user's reboot (sudo + desktop-session teardown).
3. **Stale `niri.prom.tmp`:** now permanently inert (never touched by the fixed script) but still on disk; removal needs root.

## c) NOT STARTED

1. Repo-wide sweep for OTHER fixed-name `.tmp` textfile writers under hardened-root units (the class is now documented, not yet audited; ~20 collectors write to that dir).
2. Post-deploy verification run (`nix run .#post-deploy-check`) for the niri fix.
3. Post-reboot verification battery: flm binds + cold load + `/v1/models` E2E smoke; zram ~50% device size; MemTotal reflects the 512 MiB carveout; D-state count → 0; llama `/v1/embeddings` + `/v1/rerank` functional; PMA go-commit + papdashboard enricher recover against the woken NPU.
4. Whether Gatus paged about stale niri metrics / flm failures during the ~2-day window (Discord-side state invisible to this session).

## d) TOTALLY FUCKED UP

Nothing was destroyed or broken by this session (lars-run test provably side-effect-free; no reverts; no foreign changes touched). Honest negatives:

1. **Missed mitigation in the final report:** `sudo systemctl stop fastflowlm.socket` until reboot would make clients fail FAST (ECONNREFUSED) instead of hanging into probe/backlog timeouts, and stops the per-connection start-request churn against a corpse-pinned backend.
2. **Did not check llama unit health post-deploy during triage** (only caught it writing this report; checked ports — one fresh listener each, functional state still unverified until Gatus/smoke).
3. **Inherited phantom (not mine, but worth saying out loud):** the 2026-09-03 session's "niri fixed + live: freshly written by the root timer" claim contradicts file evidence — that phantom verification is precisely what allowed this deploy blocker to survive 2 days. The repo lesson "re-verify status-report claims against fresh evidence" applies to our own reports too.

## e) WHAT WE SHOULD IMPROVE

1. Apply the mktemp+caps pattern to every hardened-root textfile collector (or at least audit and fix where a fixed tmp name exists).
2. Treat any "fixed + live" claim in status reports as unverified until backed by runtime evidence (file mtime, journal line, or probe) — annotation/correction culture for old reports (docs-health ANNOTATE mode).
3. flm thread-group death (zombie leader + X sibling pinning sockets) may be worth an upstream FastFlowLM report (verify-before-filing first: needs a repro + kernel-level confirmation).
4. Consider a Gatus/system-health signal for "backend bound but never accepting" (the Recv-Q backlog signature) — currently only unit-failure metrics fire, and the socket holder class produces NO unit failure at all.

## f) NEXT UP TO 50 (prioritized; P0 = before/with next reboot, P1 = this week)

**P0 — recovery path**
1. `nix run .#deploy` — land the niri fix, stop the Exited(4) churn.
2. `nix run .#post-deploy-check` after the switch.
3. Decide reboot window (clears flm corpse, NPU wedge, 33 D-state corpses, 1.7k CLOSE_WAIT sockets, and activates zram 50% + 512 MiB carveout).
4. Optional until reboot: `sudo systemctl stop fastflowlm.socket` (fail-fast clients, no more start-request churn).
5. Reboot.
6. Post-reboot: verify `/run/booted-system` == `/run/current-system` (crash-era lesson).
7. Post-reboot: flm `/v1/models` E2E smoke through :52625 (post-deploy-check § covers it).
8. Post-reboot: confirm zram0 size ≈ 50% of visible RAM.
9. Post-reboot: confirm MemTotal reflects the 512 MiB carveout (~125 GiB expected).
10. Post-reboot: D-state count → 0; `system_stuck_dstate_processes` green.
11. Post-reboot: llama 8848 `/v1/embeddings` (1024-dim) + 8849 `/v1/rerank` functional smokes.
12. Post-reboot: PMA commit pipeline + papdashboard insight enricher recover (flm back).
13. Post-reboot: verify niri collector writes `niri.prom` fresh every 30s as root (the fix, live).
14. Post-reboot: Gatus fleet green again (niri checks, FastFlowLM-derived system_service metrics).

**P1 — class elimination**
15. Sweep all textfile collectors for fixed-name `.tmp` writes under hardened units; apply mktemp pattern where found.
16. Add the mktemp pattern to docs/CONTRIBUTING.md module template if one exists for collectors.
17. `sudo trash /var/lib/prometheus-node-exporter/textfile_collectors/niri.prom.tmp` (hygiene; inert but clutter).
18. Check the stale root-owned `btrfs-compression.prom.tmp` (16:42) — is that collector's timer healthy?
19. Verify flm idle-check works post-reboot (cold-load blind spot: "TCP connection established" lines absent during load).
20. Evaluate flm v1.0.4 bump AFTER reboot stability (held discipline: live-serve validation + one-time re-pull budget).
21. Confirm whether Gatus alerted during the 2-day niri staleness (alert-fatigue audit; if silent → why, fail-closed checks should have fired).
22. Verify SigNoz received the flm restart storm + start-limit hits (telemetry check).
23. Consider "bound but not accepting" detection (Recv-Q backlog gauge in a textfile collector + Gatus condition).
24. Consider unit-level guard: backend that fails bind N times → stop the public socket until manual/automated reset (generalizes the guard's socket-sacrifice doctrine to the bind-wedge class).
25. Annotate/correct the 2026-09-03 status report's phantom "fixed + live" claim (docs-health ANNOTATE).
26. Decide whether the fastflowlm restart backoff should ALSO apply to client-requested immediate restarts (the "immediately on client request" line bypasses backoff pacing by design; quantify the churn first).

**P2 — standing debt noticed this session (unchanged, tracked for completeness)**
27. InboxClean OAuth re-auth status unknown from this session (Testing-mode 7-day expiry incident was earlier on 2026-09-04; verify both accounts re-authed AND consent screen flipped to production).
28. 2026-09-04 llama incident: confirm `rocm.deviceCgroup` held (no NEW corpse pairs created by the 22:28 deploy's llama restarts).
29. /data EIO inode (btrbk-data aborts) — still open from TODO_LIST.
30. ClickHouse backup coverage gap (btrbk excludes telemetry) — still open.
31. Samsung 970 EVO Plus role assignment (XFS hot-DBs + BTRFS /nix plan) — still pending execution.
32. pending secret-history purge decision (held; rotation-first doctrine) — unchanged.
33. review the 9 auto-commit daemon commits from this window for message quality/batching (heuristic commits mixed files across sessions).
34. Keep fastflowlm v1.0.2 hold rationale in AGENTS.md until the 7.2.2-kernel retry actually happens.

(34 items — the remaining slots intentionally left empty rather than padded with filler.)

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **Reboot timing:** when is an acceptable window for the reboot (it also flips zram 50% + the 512 MiB carveout), and do you want `fastflowlm.socket` stopped until then so clients fail fast instead of hanging?
2. **Order of operations:** deploy first (lands the niri fix while the box is up) then reboot — or straight to reboot and deploy after? (My recommendation: deploy now, reboot after green.)
3. **Alert visibility:** did any Gatus/Discord alerts reach you during the ~2-day niri-collector outage and today's flm restart storm (niri metric staleness, `system_service_start_limit_hit`, llama units)? If Discord stayed silent, that is a separate monitoring bug I should chase — I cannot see Discord state from here.
