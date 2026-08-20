# Hermes Session-Loss Recovery — Full Stack Status Report

- **Date:** 2026-08-20 09:45 CEST
- **Scope:** This session's work only (triggered by the 08:58 Discord turn loss on session `20260818_201750_bc685bb8`)
- **Verdict:** All infrastructure fixed, deployed, and verified. The original *user request* (mnemosyne ingestion) is still NOT done. Memory-pressure root cause is mitigated, not solved.

---

## Timeline of this session

| Time | Event |
|---|---|
| 08:58:49 | Turn aborted: `append_message failed: TrackedConnection returned NULL without setting an exception` → `reason=session_persistence_failed` |
| 09:0x | Diagnosis: state.db healthy (`quick_check: ok`, 2301 sessions, 31584 msgs). Real cause = memory pressure: zram swap 100% full (28.2/28.2G), OOM kill 08:15, gateway cgroup peaked at its `MemoryMax=24G` |
| 09:0x | Found mnemosyne MCP crash-looping since **Aug 18 20:55** (1,875 spawn attempts): `command: python3` but gateway systemd PATH has no `python3` → `FileNotFoundError` |
| 09:09 | Fixed config.yaml → `/run/current-system/sw/bin/python3`; gateway restarted (also by memory pressure); mnemosyne clean start since |
| 09:1x | Added 16G emergency swap on `/mnt/buildcache` (ext4; btrfs root unsuitable due to snapshots) |
| 09:13–09:23 | User reset GLM token + ran `nix run .#deploy`. Deploy's new read-only bind (`/home/lars/projects` → `/home/hermes/workspace/projects`) broke `hermes-fix-permissions` (`chown -R` → EROFS → crash-loop ×6 → **start-limit-hit**) |
| 09:21–09:23 | Bridged gap with a manual detached gateway (one failed attempt: inherited bad `XDG_STATE_HOME`; fixed on second try; Discord connected) |
| 09:29–09:36 | Fixed `hermes.nix` (find `-xdev` + `-prune` of bind target + failure tolerance); deployed via `nh os switch` as lars. Commit `962d433d` (authored by repo automation) |
| 09:37–09:45 | Full verification: unit active/running under systemd, Discord connected, mnemosyne alive, GLM chat round-trips "OK", workspace bind visible in gateway, 0 failed units |

---

## a) FULLY DONE

1. **Root-caused the lost turn** — transient sqlite3 C-level SystemError under extreme memory pressure; DB never corrupted (`quick_check: ok` in 14.2s). User's message was intentionally dropped to protect transcript integrity — by design, not a bug in hermes.
2. **Fixed mnemosyne MCP crash-loop** — absolute interpreter path in `~/.hermes/config.yaml`; verified with MCP handshake, `hermes mcp test` (4 tools), and live PIDs under the gateway. Index intact: 3088 chunks / 3898 entities / 9942 edges (built 08:20 today).
3. **GLM/Z.AI auth restored** — new key from sops render tested (HTTP 200 direct + `hermes chat` replied "OK" twice, pre- and post-deploy), synced into `.env`.
4. **Fixed the deploy crash-loop at the source** — `SystemNix/modules/nixos/services/hermes.nix` `fixPermissionsScript` now prunes the read-only bind, uses `-xdev`, and tolerates per-entry failures. Deployed to the live system; live unit references the new script (`dkiagjcl…`). Sandbox-tested prune + `set -e` tolerance before deploying.
5. **Gateway back under systemd supervision** — verified via cgroup (`0::/system.slice/hermes.service`), ActiveState=active/running. Start-limit cleared via systemd D-Bus (`busctl … ResetFailedUnit`, equivalent of deploy.sh's own `reset-failed`).
6. **16G emergency disk swap active** (2.3G in use at last check) — safety valve under the full zram.
7. **Cleared stale failed units** (hermes.service + swap unit) so pre-deploy checks pass — `Summary: 68 passed, 0 failed`.
8. **Verified state.db writes resumed** — WAL checkpointed to 0B after restart; cron sessions persisting normally.
9. **Confirmed the "Kan Yu (Jade)" fact survived** — the pre-crash turn did persist its todos/tool results in state.db; fact recorded in mnemosyne + USER.md + USER memory (three layers) before the crash.

## b) PARTIALLY DONE

1. **Memory pressure** — symptom mitigated (disk swap), cause untouched: zram still 100% full; ~73G RAM used; 2 llama-servers (~10G + ~25G shared) + 27G `shared` (tmpfs/shmem) unexamined. Nothing identified to reduce consumption.
2. **Emergency swap persistence** — active now, gone on reboot. No `swapDevices` flake entry added (I was already deploying and didn't include it — should have).
3. **Hermes environment hygiene** — `.env`/auth now good for GLM, but doctor still reports: config v18→v37 outdated, deprecated `TERMINAL_CWD` + `display.tool_progress_overrides`, "Venv entry point not found", Node.js missing *under the hermes user*, web/x_search tools unconfigured (EXA/TAVILY/XAI keys), Skills Hub not initialized, no GITHUB_TOKEN.
4. **Gateway observability** — I verified a healthy snapshot; no continuous watch on mnemosyne MCP "parked" state (it fails *silently* — that's how it went unnoticed for 2 days), zram fill, or `session_persistence_failed` events.

## c) NOT STARTED

1. **The actual mnemosyne ingestion** — the lost turn's original request: index ALL of `/home/hermes` and `/home/lars/projects` into the GraphRAG. Infrastructure is now ready (MCP fixed + projects readable via bind mount); zero ingestion performed. The user must resend the request to Hermes (or we do it from here).
2. **state.db maintenance** — 801MB / 2301 sessions; historical "database is locked >60s" cron-turn losses (Aug 4–10 pattern, overnight VACUUM/checkpoint). No archiving, no VACUUM scheduling change.
3. **fastflowlm ("flm") investigation** — it was OOM-killed twice (08:15) and apparently juggled my swap at 09:12 (ghost `/swapfile-emergency` path in `/proc/swaps` for the ext4 file actually at `/mnt/buildcache/swapfile-emergency`). Its role/ownership of swap management unexamined.
4. **Alerting/monitoring for this failure class** — zram-fill and persistence-failure metrics exist (`system_zram_fill_over_threshold`) but I didn't verify alert routing fires anywhere human-visible.
5. **Pre-deploy hardening in the repo** — nothing stops the *next* `chown -R`-into-read-only-bind bug in another module (no check, no test).

## d) TOTALLY FUCKED UP

Nothing irreversibly broken. Honest near-misses:

1. **Manual launcher inherited `XDG_STATE_HOME=/home/lars` from my root shell** → Discord lock PermissionError → ~2 min avoidable retry downtime. Second version fixed it; leftover: one "exited UNCLEANLY" lifecycle-ledger warning + 1 cron execution marked unknown.
2. **`git add` on lars's repo as root** — could have poisoned the index ownership (it didn't; index stayed lars-owned). Should have used `runuser` from the start.
3. **Misread deploy outcome** — declared 06B failed (tee capture died) when it had actually switched; re-ran (06C no-op). Self-corrected before any harm, but sloppy verification ordering.
4. **Ghost swap path** — reported "cosmetic" without full resolution: my `swapoff`/`swapon` pair failed (No such file/EBUSY); the swap area serves from the right ext4 file but under a deleted-link name. Not investigated to the bottom.
5. **The unit crash-looped 6× on the user's deploy at all** — the chown-vs-read-only-bind interaction was foreseeable when I first read the unit file; I only connected it after start-limit-hit.

## e) WHAT WE SHOULD IMPROVE

1. **Silent-failure surfaces**: MCP servers "park" without any notification. Add a Discord ping / cron probe when any MCP goes parked.
2. **Doctor context**: `hermes doctor` run from lars/root homes inspects the wrong `~/.hermes` and misleads (paste showed 3 phantom "issues"). Document/run `sudo -u hermes env HOME=/home/hermes hermes doctor`.
3. **Deploy-time unit validation**: extend `pre-deploy-check.sh` with a static guard — flag any `chown -R`/`rm -rf` in ExecStartPre scripts that intersects `BindReadOnlyPaths` targets.
4. **One owner for swap**: flake `swapDevices` vs fastflowlm's runtime juggling — two uncoordinated actors produced the ghost path.
5. **Memory budget**: `MemoryMax=24G` on hermes while llama embed/rerank servers (spawned under the same unit!) consume ~11–25G — they compete with the gateway inside its own cgroup. Split them into their own units with their own limits.
6. **state.db lifecycle**: archive old sessions + schedule VACUUM in a window announced to cron so turns don't die with "database is locked".
7. **Config drift**: 19 config versions behind; run the migration once, then keep doctor clean in CI/cron.
8. **My own discipline**: run as the correct user (hermes/lars) not root; verify "failed" deploys actually failed; resolve anomalies (ghost swap) instead of labeling them cosmetic.

## f) NEXT — up to 50 tasks

**Hermes agent (the point of all this)**
1. Resend the mnemosyne ingestion request to Hermes (lost turn) — ingest `/home/hermes` docs/memories/config
2. Ingest `/home/lars/projects` (readable now at `/home/hermes/workspace/projects`) into mnemosyne
3. Ingest state.db session history (16k+ message lines mentioned as unindexed)
4. Verify GraphRAG recall after ingestion ("girlfriend name" → Kan Yu must hit)
5. Read the Kanyu repo via the bind mount; enrich the memory graph
6. Send a Discord end-to-end test message (connected ≠ delivering)
7. Re-run the interrupted cron jobs marked "unknown" at 09:23

**Memory / swap**
8. Add `swapDevices` (or decide flm owns it) — persist emergency swap across reboots
9. Profile top-10 RSS consumers; find the real 73G eaters
10. Investigate the 27G `shared` (tmpfs/shmem) usage
11. Decide if both llama-servers (embed + reranker) must run 24/7; idle schedule?
12. Split llama-servers out of hermes.service cgroup with dedicated MemoryMax
13. Revisit hermes.service `MemoryMax=24G` / `MemoryHigh=80%` against real usage
14. Verify zram-fill alert actually routes somewhere (gatus → Discord/Signal?)
15. Clean up ghost `/swapfile-emergency` name after next reboot (confirm gone)

**fastflowlm**
16. Read the flm service definition; understand its swap/OOM-recovery role
17. Deduplicate swap management between flm and the flake
18. Review flm OOM-kill history; add MemoryMax or trim its cache

**state.db / persistence**
19. Archive sessions older than N months; shrink 801MB DB
20. Schedule announced off-peak VACUUM (or incremental checkpoint tuning)
21. Add cron watchdog for `session_persistence_failed` in agent.log → notify
22. Dry-run `hermes sessions recover --allow-partial` (rehearse disaster path)
23. Verify `hermes backup` runs on a schedule; test a restore

**Config hygiene**
24. Migrate config v18→v37 (`hermes setup` / `doctor --fix`)
25. Move `TERMINAL_CWD` from .env → `terminal.cwd` in config.yaml; delete env entry
26. Remove deprecated `display.tool_progress_overrides`
27. Fix "Venv entry point not found" ( reinstall with pip -e `.[all]` or accept+silence)
28. Make Node.js visible to the hermes-user PATH (browser tools)
29. Add EXA/TAVILY/PARALLEL keys → enable `web` tool
30. Add XAI key → enable `x_search`
31. Set GITHUB_TOKEN in `.env` (Skills Hub rate limits)
32. Initialize Skills Hub (`hermes skills list`)
33. Install codex CLI (optional auth import path)
34. Clear stale zai `credential_pool` entry in auth.json (exhausted/401 fingerprint)

**SystemNix repo**
35. Extend pre-deploy-check: ExecStartPre × BindReadOnlyPaths static guard
36. Grep all modules for other `chown -R`/recursive ops that cross bind mounts
37. Add a comment/test for the fix-permissions prune contract
38. Review `hermes-migrate-state` vs `fix-permissions` ordering for the same trap
39. Verify `hermes-acl-revoke` never strips an ACL something needs
40. Consider systemd-harden review of hermes.service (ProtectSystem strictness)

**Observability / ops**
41. MCP "parked" state → alert (cron `hermes mcp test` sweep)
42. Weekly `hermes doctor` cron, report to Discord
43. Rotate/truncate mcp-stderr.log (1.7MB of crash banners — growth now stopped)
44. Check logrotate coverage for errors.log/agent.log
45. Investigate restart_loop.json history (gateway stability baseline)
46. Post-reboot checklist: swap back, bind mount present, mnemosyne first start clean
47. Verify monitor365 metrics endpoint down (pre-deploy warning: 3 absent metrics)
48. Reap 1 stale nix build sandbox (`nix-build-cleanup.service`)
49. Confirm SystemNix working tree is clean post-962d433d (nothing half-staged)
50. Point hermes at the `workspace/projects` path in its own docs/memory so it stops trying `/home/lars` directly

## g) Questions I cannot answer myself

1. **Ingestion sensitivity:** When indexing `/home/lars/projects` into mnemosyne, are there files/dirs that must be excluded (project `.env`s, secrets, client data), or is everything fair game? I can build an exclusion list, but the privacy call is yours.
2. **Swap ownership:** Should emergency disk swap be a declarative flake `swapDevices` entry (mine to persist), or does fastflowlm own runtime swap management? Both acted this morning; one must win or we get ghost paths forever.
3. **Memory priorities:** Is the ~73G usage (2 llama-servers ~11–25G, 27G shared) the intended steady state for this box? i.e., should I optimize to *reduce* RAM pressure, or is adding swap capacity the accepted answer?

---

**Status: report complete. Waiting for instructions.**
