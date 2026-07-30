# Status Report: Session Review — Helium, DNS, Monitor365

**Date:** 2026-07-24 17:36
**Session scope:** Three incidents fixed across this session
**Overall status:** ~~Code written and syntax-validated, **NOT fully deployed**~~ **All three deployed** — see update below.

> **Update 2026-07-24:** All three fixes deployed in the comprehensive audit deploy (generation built 18:14, after HEAD `d243f1ee`). (1) Helium empty-window crash loop: `helium-launch` wrapper deployed and running. (2) DNS blocker: `dnsblock.home.lan` resolves correctly (verified via `getent hosts`). (3) Monitor365 agent: watchdog runs as **root** (the critical bug flagged below is FIXED), agent process running. The `monitor365-agent-watchdog.timer` resets start-limit and restarts the agent when dead.

---

## Session Work Summary

Three independent issues were diagnosed and fixed in this session:

1. **Helium empty-window crash loop** — Deployed ✓
2. **DNS blocker dashboard unreachable** — Written, NOT deployed
3. **Monitor365 agent circuit-breaker deadlock** — Written, NOT deployed

---

## a) FULLY DONE

1. **Helium crash loop diagnosed and fixed** — Root cause: `helium.service` with `Restart=always` spawns empty windows when an existing instance is alive. Fix: `helium-launch` wrapper that waits for existing process to die. Deployed successfully at 06:25. AGENTS.md documented.

2. **DNS blocker subdomain missing** — `dnsblock` and `dnsblockd` were not in `dnsLocal.localSubdomains`. dnsblockd's embedded sdns resolver doesn't support wildcard `*.home.lan` records. Fix: added both subdomains to `dns-local.nix`. Smoke test fixed to probe `localhost:9090` directly instead of going through HTTPS vHost. AGENTS.md documented.

3. **Monitor365 root cause fully diagnosed** — Complete chain traced: server down → circuit breaker opens (716K failures) → agent burns 95% CPU on CB spam → buffer 95% full, dropping events → niri DRM zombie bounce triggers `graphical-restart.path` 6× in 1s → start-limit-hit → agent dead → deploy only resets start-limit, never starts agent.

4. **Monitor365 4-layer fix written** — (A) start limits, (B) graphical-restart debounce, (C) agent watchdog timer, (D) deploy.sh starts inactive services. All syntax-validated (`nix flake check --no-build` passes).

5. **Post-deploy smoke test upgraded** — Now checks BOTH sides of Monitor365: agent process alive + metrics (9191) AND server reports >0 connected devices. Auto-restarts if CB deadlocked.

6. **AGENTS.md documented** — Three new gotcha entries added (helium loop, DNS wildcard, monitor365 CB deadlock).

---

## b) PARTIALLY DONE

1. **DNS fix NOT deployed** — `dns-local.nix` change and smoke test fix are written but not deployed. `dnsblock.home.lan` still doesn't resolve on the live system.

2. **Monitor365 fix NOT deployed** — All 4 layers written but not deployed. Agent is still dead (`inactive/dead`, start-limit-hit). The fix needs `nix run .#deploy` to activate.

3. **Helium fix deployed but NOT verified** — I trusted the deploy output and syntax check. I did NOT verify post-deploy that the `helium-launch` wrapper actually works (e.g., kill helium, confirm the wrapper waits and relaunches cleanly).

---

## c) NOT STARTED

1. **Why was the Monitor365 server down in the first place?** — The entire cascade started from the server being unreachable. I fixed agent recovery but never investigated the original server outage. The DuckDB WAL corruption heal (`monitor365-duckdb-heal`) may have been involved, or the schema-migrate service.

2. **`monitor365-graphical-restart.path` and `.service` failed during deploy** — The deploy output explicitly showed `warning: the following units failed: monitor365-graphical-restart.path, monitor365-graphical-restart.service`. I did NOT investigate this. It may be related to the path unit firing before the service is ready.

3. **Monitor365 backup health failing** — Gatus reports `Monitor365 Backup Health: success=false`. The backup may be stale or the textfile collector isn't writing. Not investigated.

4. **DuckDB is 2 GB** — May need vacuuming or checkpoint. Not investigated whether this contributes to slowness.

5. **The stale wildcard `*.home.lan` record** — I added explicit subdomains to fix the immediate problem but left the no-op wildcard record (`"*.${domain}." = serverIP`) in `dns-blocker-config.nix:72`. It's misleading — it looks like it should work but doesn't. Should be removed or commented.

6. **Helium `PartOf` propagation failure** — Why did the Jul-23 helium process survive a graphical-session restart? `PartOf = [ "graphical-session.target" ]` should have stopped it. Uninvestigated. My fix is a band-aid.

7. **Timeout on `helium-launch` wait loop** — No timeout. Could hang forever on a zombie helium process.

---

## d) TOTALLY FUCKED UP

1. **CRITICAL BUG: `monitor365-agent-watchdog` runs as `monitor365` user but calls `systemctl start/restart`** — A regular system user CANNOT start system services without sudo/polkit. The watchdog will detect the agent is dead, print the message, then fail silently on `systemctl start`. The entire watchdog layer (Layer C) is broken as written. **Must run as root** (remove `User`/`Group` from serviceConfig) or use a different signaling mechanism.

2. **Did not give emergency stop command first** — When the user reported empty windows spawning, I jumped to diagnosis instead of triage. Should have led with `systemctl --user stop helium.service`.

3. **Did not verify the helium fix post-deploy** — Complacency. The deploy succeeded, syntax checked, but I never tested that `helium-launch` actually prevents the loop. The user could discover it's broken on the next niri restart.

4. **Deployed the helium fix without the DNS and Monitor365 fixes** — Three independent changes were made, but only one was deployed. The DNS fix is trivial and should have been deployed alongside. The Monitor365 fix is critical (agent is dead RIGHT NOW).

---

## e) WHAT WE SHOULD IMPROVE

1. **Fix the watchdog user** — Change `monitor365-agent-watchdog` to run as root (remove `User`/`Group`), or use polkit, or have it `touch` a trigger file that a root timer watches.

2. **Deploy ALL pending changes** — DNS fix + Monitor365 fix + watchdog fix. One deploy.

3. **Verify post-deploy** — After deploying: (a) check `dnsblock.home.lan` resolves, (b) check monitor365 agent is alive and server sees it connected, (c) kill helium and confirm `helium-launch` works.

4. **Remove the broken wildcard DNS record** — `"*.${domain}."` in `dns-blocker-config.nix:72` is a no-op in dnsblockd. Remove it or add a comment.

5. **Add timeout to `helium-launch`** — Wait at most 300s, then launch anyway.

6. **Investigate server stability** — The root cause of the Monitor365 cascade was the server going down. The WAL corruption heal is a band-aid. Need to understand why the server crashes.

7. **Fix `monitor365-graphical-restart` path/service failure** — These failed during deploy. Investigate why.

8. **Test the graphical-restart debounce logic** — The debounce script uses `date -d` parsing of systemd's `ActiveEnterTimestamp`. Verify this works correctly.

---

## f) Next Actions (up to 50)

### Critical (do now)
1. **Fix `monitor365-agent-watchdog` to run as root** — remove `User`/`Group` from serviceConfig
2. **Deploy all pending changes** — DNS + Monitor365 + watchdog fix in one `nix run .#deploy`
3. **Verify DNS resolution** — `getent hosts dnsblock.home.lan` after deploy
4. **Verify Monitor365 agent** — `curl localhost:9191/metrics` and `curl localhost:3001/health` after deploy
5. **Verify helium-launch** — kill helium main process, confirm wrapper relaunches cleanly

### High priority
6. **Investigate why Monitor365 server was down** — check WAL corruption history, DuckDB health
7. **Fix `monitor365-graphical-restart.path/.service` deploy failure** — investigate the activation error
8. **Check Monitor365 backup health** — Gatus reports failing; check textfile collector + backup freshness
9. **Remove or comment the broken `*.home.lan` wildcard record** in `dns-blocker-config.nix`
10. **Add timeout to `helium-launch` wrapper** — cap wait at 300s
11. **Investigate helium `PartOf` propagation** — why did Jul-23 process survive graphical-session restart?

### Medium priority
12. **Vacuum/checkpoint the 2GB DuckDB** — may reduce memory pressure
13. **Clear the stale Monitor365 agent buffer** — 95% full with events that may be corrupt from the CB deadlock period
14. **Add Gatus alert for DNS subdomain resolution** — catch missing subdomains before users notice
15. **Audit all systemd services for missing `StartLimitBurst`/`StartLimitIntervalSec`** — upstream modules may lack them
16. **Add the agent buffer pressure to the post-deploy check** — verify backlog isn't growing
17. **Test the watchdog timer end-to-end** — kill agent, wait 5min, confirm watchdog recovers it
18. **Add monitor365 agent to the pre-deploy check** — verify it's running BEFORE deploy (catches dead state)
19. **Document the dnsblockd wildcard limitation in `dns-blocker-config.nix` comments**
20. **Review all `Restart=always` services for the handoff-exit-0 bug class** — any service that "opens in existing session"

### Lower priority
21. **Consider `KillMode=mixed` + `TimeoutStopSec` on helium.service** — ensure clean shutdown on graphical-session stop
22. **Add a systemd unit dependency diagram** — visualize the monitor365 service dependency chain
23. **Consider a health endpoint on the agent** — not just Prometheus metrics, a simple `/health` 200
24. **Add circuit-breaker reset on server recovery** — agent should detect server is back and proactively reset CB
25. **Monitor the monitor365-schema-migrate service** — add Gatus check or system-health metric
26. **Review the `monitor365-graphical-restart.path` trigger conditions** — `PathExists` may fire on partial socket creation
27. **Add deploy.sh verification that critical services started** — not just `reset-failed` + `start`, but verify `is-active`
28. **Consider a pre-deploy agent drain** — graceful shutdown of agent before switch-to-configuration
29. **Add Monitor365 to the status-report.sh service list** — it's already there but verify coverage
30. **Review the 2GB DuckDB for event bloat** — may need retention/cleanup policy
31. **Consider adding `restartTriggers` for the watchdog unit** — so it picks up config changes
32. **Audit all sops secret ownership** — ensure agent can read its secrets
33. **Test API key rotation end-to-end** — rotate `cloud_auth_token`, deploy, verify both sides re-sync
34. **Add a Monitor365 integration test** — spin up server + agent in a test, verify device registration
35. **Review the circuit breaker configuration** — upstream CB may need tuning (failure threshold, reset timeout)
36. **Consider `Restart=on-failure` instead of `Restart=always`** for the agent — avoids restarting on clean exit
37. **Document the full Monitor365 recovery runbook** — step-by-step for when the agent is dead
38. **Add PromQL/SigNoz alerts for circuit breaker state** — not just Gatus, but actual metrics-based alerting
39. **Review the agent's CPU usage pattern** — 95% CPU on CB spam suggests tight retry loop without backoff
40. **Consider rate-limiting the agent's error logging** — 716K log entries is excessive journald pressure
41. **Add a `/api/v1/devices` endpoint test** — verify the server can list registered devices
42. **Test what happens when DuckDB is deleted entirely** — fresh bootstrap should work
43. **Review the `monitor365-server` WantedBy target** — currently `multi-user.target`, should it be `signoz.target`?
44. **Add health check for the agent's IPC socket** — `/run/monitor365/agent.sock` existence
45. **Consider a canary metric** — agent writes a heartbeat event every minute, server verifies receipt
46. **Review whether the agent buffer encryption is worth the CPU cost** — `encryption = true` adds overhead
47. **Add documentation for the graphical-restart debounce pattern** — reusable for other path-unit-triggered services
48. **Consider a systemd `ConditionPathIsSymbolicLink` on the graphical-restart path** — avoid false triggers
49. **Review the ` ProtectProc=default` override** — is it still needed after the debounce fix?
50. **Write an end-to-end Monitor365 test script** — `scripts/test-monitor365-connectivity.sh`

---

## g) Questions I Cannot Answer Myself

1. **Should the Monitor365 agent buffer be cleared?** It's at 95% capacity with events from the circuit-breaker deadlock period. These events were collected while the server was down — they may be valid telemetry worth uploading, or they may be corrupt/duplicated from the CB spam. Clearing (`rm /var/lib/monitor365/events.db`) loses data but ensures a clean start. Keeping it means the agent will try to upload 30GB+ of backlogged events when it reconnects, which may re-trigger the death spiral. I cannot determine the integrity of the buffered events without access to the encrypted SQLite store.

2. **Was the Monitor365 server crash caused by DuckDB WAL corruption or something else?** The `monitor365-duckdb-heal` ExecStartPre exists and removes WAL files, but I don't know if it actually fired on the crash that started this cascade. The server logs I checked (from the last hour) show it healthy now. I'd need to check historical logs from when the cascade started (possibly days ago) to determine the original cause. Should I dig into historical logs, or is the WAL heal sufficient as a band-aid?

3. **Should I deploy now, or do you want to review the watchdog user fix first?** The watchdog as written has a critical bug (runs as `monitor365` user, can't `systemctl start`). I need to fix this before deploying. But the DNS fix and the other Monitor365 layers (start limits, debounce, deploy.sh fix) are independent and ready. Do you want me to fix the watchdog and deploy everything together, or deploy the ready parts now?
