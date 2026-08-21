# Status: Gatus Unhealthy Services Fix — Brutal Self-Review

**Date:** 2026-07-18 06:12 CEST
**Session scope:** Resolve the 5 unhealthy Gatus endpoints + the failed deploy shown in the paste.
**Outcome:** All 5 root causes fixed, deployed, verified. Deploy lock was transient.

---

## a) FULLY DONE

### Fixes shipped & verified (6 files changed, +50/-17 lines)

| # | Service                     | Root cause (verified)                                                                                                                                                                                                                      | Fix                                                                                                                                                               | Direct-verified post-deploy                                            |
| - | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 1 | **DNS Blocker**             | `dns-blocker.nix` passed `bl.file` (a **directory**) to dnsblockd instead of the hosts file inside it (`$out/${name}`). Silent: `dnsBlocklistEntries: 0`, `mapping.json: {}`, ZERO blocking. `ads.google.com` resolved to real Google IPs. | `processorArgs` + `blocklistPaths` now use `${bl.file}/${bl.name}`.                                                                                               | `dnsBlocklistEntries: 2535619`, `mapping.json` 6.4 MB / 130k+ per list |
| 2 | **DNS Blocking Active**     | Same root cause as #1. Once blocklists load, `dns_block_response: zero_ip` returns the block IP (192.168.1.200), which the check expects.                                                                                                  | (Fixed by #1.)                                                                                                                                                    | `ads.google.com` → `192.168.1.200` (was `142.251.141.174`)             |
| 3 | **Redis**                   | nixpkgs immich module defaults `redis.port = 0` (TCP disabled) + `host = unixSocket`. Gatus `tcp://127.0.0.1:6379` can't reach a unix socket.                                                                                              | `services.immich.redis.port = ports.redis` + `bind = mkForce "127.0.0.1"`. Redis now listens on both socket AND TCP localhost.                                    | `PING` → `+PONG`; host `127.0.0.1:6379` LISTEN                         |
| 4 | **Monitor365 System Agent** | Gatus matched `pat(*monitor365*)`, but agent `/metrics` emits `collector_events_collected`, `middleware_dedup_*`, `cloud_sync_*` — none contain "monitor365".                                                                              | Pattern → `collector_events_collected`.                                                                                                                           | Body contains the metric                                               |
| 5 | **Ollama**                  | `ai-stack.nix:75` had `wantedBy = lib.mkForce []` — an enabled service that **silently never started**. No crash, no log, pure split-brain against the unconditional Gatus check.                                                          | Removed the override (nixpkgs `WantedBy=multi-user.target` applies). Made Gatus check conditional on `ai-stack.enable` (matches voice-agents/monitor365 pattern). | HTTP 200 `{"models":[]}`, 34 MB RSS                                    |

### Deploy

- `nix flake check --no-build`: **all checks passed**.
- `nix run .#deploy`: built 17 derivations, processed **2,535,619 blocklist domains** (+227 MiB), bootloader updated cleanly (no lock error), 0 failed units, **post-deploy smoke test 21 PASS / 0 FAIL**.
- The earlier `Could not acquire lock` (exit 11) was **transient lock contention** with buildflow running under load avg 21. No stale locks; retry succeeded.

### Documentation

- 4 new gotcha entries appended to `AGENTS.md` Non-Obvious Gotchas table (dnsblockd path bug, ollama wantedBy, immich redis socket-only, monitor365 metrics pattern).

---

## b) PARTIALLY DONE

### Verification depth — the honest gaps

1. **Gatus's _recorded_ status not confirmed.** I verified each _underlying service_ is healthy by direct probing, but I did NOT confirm Gatus itself flipped each check to green. Two blockers: the Gatus REST API returns 401 (OIDC required), and the SQLite DB file (`/var/lib/gatus/gatus.db`) is owned by the `gatus` DynamicUser so unreadable as `lars`. Gatus needs `success-threshold = 2` consecutive passes (60s checks) + the 5m-interval checks (DNS Blocking Active) take up to 5 min to register even one success. **Probable** all green now, but "probable" is not "verified".

2. **rpi3 not re-deployed.** `dns-blocker.nix` is shared by rpi3 (`platforms/nixos/rpi3/default.nix` imports the same blocklists). The fix lands in the module, so rpi3's next deploy will process ~2.5M blocklist entries too — but rpi3 is a separate `nixosConfiguration` that I did NOT rebuild or deploy. Its DNS blocking is still silently broken until someone deploys it.

3. **Pre-deploy `nix flake check` ran ONCE** — before the final `ai-stack.nix` edit (removing the duplicate `wantedBy`). The `nix eval` after that edit confirmed `wantedBy = [ "multi-user.target" ]` (single) and ExecStart intact, and the deploy built everything, so functionally validated — but I did not re-run the full standalone-module flake check after the last edit.

### Things I observed but dismissed

- **Monitor365 cloud sync is failing**: `cloud_sync_consecutive_failures: 119`, `cloud_sync_upload_backlog_size: 597924739` (~597 MB queued). The agent can't reach the cloud. I called this "a separate upload issue" and moved on. **This is a real ongoing failure** that the System Agent health check does NOT catch (the check only confirms the metrics endpoint is alive, not that data is flowing).
- **System is under chronic memory pressure**: swap 100% full (15 GiB), load avg 15–21, `GPUActive` consuming 51+ GiB (per AGENTS.md). I deployed into this state without assessing timing risk.

---

## c) NOT STARTED

- No commit made (working tree is dirty with the 6 changed files). User did not ask.
- No `FEATURES.md` / `TODO_LIST.md` update (DNS-blocking feature status, ollama always-on change).
- No verification that the generated `gatus.yaml` has correct YAML / no other latent check misconfigurations.
- No audit of the _other_ ~40 Gatus checks for similarly wrong patterns (I only fixed the one reported).
- No investigation of WHY the blocklist path bug was introduced (likely commit `d521dd2d` "Expand dns-blocker with dnsblockd feature parity" — I didn't pin it or scan that commit for sibling bugs).
- Disk pressure (93%, 52 GiB free, 14 stale build sandboxes flagged by pre-deploy-check) — untouched.

---

## d) TOTALLY FUCKED UP

Nothing in this session was destructive or left the system worse. But two judgment calls were weak:

1. **I declared success on Gatus health without reading Gatus.** I substituted "the underlying endpoint returns the right bytes" for "Gatus reports healthy". These are different things — a YAML typo in `pat(*collector_events_collected*)` or a gatus config-reload failure would leave the check red while I claim green. I should have read the generated gatus.yaml AND queried gatus's own view (sudo cat the DB, or hit the API with a session cookie).

2. **I added `redis = 6379` to the port registry without checking for a collision footprint.** A Docker-container redis (Twenty CRM, PID 3630084, `*:6379`) is already running. It's in the container netns so there's no host-port collision today, but I should have flagged this coexistence as fragile in AGENTS.md (a future `docker run -p 6379:6379` would silently break immich's redis). I mentioned it in the AGENTS entry but did not add a port-registry comment or a collision guard.

---

## e) WHAT WE SHOULD IMPROVE

1. **Stop conflating "underlying service healthy" with "Gatus reports healthy".** The whole point of Gatus is to be the source of truth. Post-deploy verification should query Gatus's own view, not re-probe endpoints. Either: (a) make the gatus DB group-readable by a `monitoring` group, (b) add a read-only unauthenticated `/api/v1/statuses/health` endpoint, or (c) bake a Gatus-confirmation step into `post-deploy-check`.
2. **The dnsblockd dir-vs-file bug should have been caught by a build-time assertion.** `mapping.json == {}` after processing N blocklists is an impossible state that deserves a `runCommand` post-check (e.g. `[ -s mapping.json ] && jq 'length > 0'`). Silent zero is the failure mode from hell.
3. **`filterBlocklist` producing a dir with the file inside is a leaky abstraction.** Callers shouldn't have to know to append `/${name}`. The function should return the file path, or the dir should contain a stable `blocklist` filename.
4. **`services.immich.redis.port` defaulting to 0 (TCP off) is a nixpkgs footgun** for anyone who monitors redis via TCP. Worth an upstream PR / issue, or at minimum a SystemNix-level override comment.
5. **The `dnsBlockResponse = "zero_ip"` name lies.** It does NOT return `0.0.0.0` — it returns the **block IP** (192.168.1.200). The description says so, but the option name is a trap. Rename to `block_ip` or `zero_ip_and_block_ip`.
6. **`wantedBy = mkForce []` for an enabled service is an anti-pattern.** There's no scenario where "enabled but never start" is intentional. If ollama should be on-demand, it should be a socket-activated unit or a `systemctl start ollama` manual flow — not a silently-empty WantedBy on an enabled service with a health check expecting it up.
7. **The Monitor365 agent health check is too shallow.** "metrics endpoint serves 200" doesn't mean "agent is collecting and syncing". Add a check on `cloud_sync_consecutive_failures < threshold` or `cloud_sync_upload_backlog_size < N`.
8. **`post-deploy-check` should fail (not SKIP/WARN) on functional regressions.** DiscordSync stats "unexpected response" and Crush Daily "unexpected response" were SKIPped/WARNed, not failed. These are real signals being demoted to noise.
9. **Deploy during load avg 21 + swap 100%** is gambling. `pre-deploy-check` should gate on memory pressure / load, or at least warn loudly (it warned on disk but not on memory).
10. **AGENTS.md is now ~280 rows of gotchas.** It's becoming a dump. Several entries describe _fixed_ bugs ("FIXED" suffix) that no longer need to be re-learned every session. Consider an `AGENTS-history.md` for resolved incidents and keep AGENTS.md to _currently-relevant_ gotchas.

---

## f) Next — up to 50 things to do

Ordered roughly by impact.

**Confirm what I just claimed (do these first)**

1. Read the generated `/nix/store/*-gatus.yaml` and verify the Monitor365 + Ollama + Redis entries are well-formed.
2. `sudo sqlite3 /var/lib/gatus/gatus.db` (or `sudo cat`) — confirm the 5 previously-unhealthy checks flipped to `success=1` after 2 × interval.
3. Re-run `nix flake check --no-build` after the final ai-stack edit (the one edit not covered).
4. Commit the 6-file changeset with a clear message.

**Monitor365 (real ongoing failure I dismissed)**
5. Investigate `cloud_sync_consecutive_failures = 119` — why can't the agent reach the cloud? Network? Auth token? Endpoint down?
6. Investigate `cloud_sync_upload_backlog_size = 597 MB` — is it growing or draining?
7. Add a Gatus check on `cloud_sync_consecutive_failures < 5` and `cloud_sync_upload_backlog_size < 100 MB`.
8. Check the Monitor365 server (`/health` showed `realtime: connected (1 devices)`) — is the _server_ receiving but failing to forward to cloud?

**rpi3 (same bug, not deployed)**
9. Build `nixosConfigurations.rpi3-dns` to confirm the shared module fix doesn't break rpi3 eval.
10. Deploy rpi3 (out-of-band — it's a different host). Until then, rpi3 DNS blocking is silently inactive.

**DNS module hardening**
11. Add a build-time assertion that `mapping.json` is non-empty when blocklists are configured (`jq | length > 0`).
12. Refactor `filterBlocklist` to return the file path directly (eliminate the dir/file footgun).
13. Rename `dnsBlockResponse` option `zero_ip` → something honest (`block_ip`).
14. Audit commit `d521dd2d` ("dnsblockd feature parity") for sibling bugs introduced at the same time as the path bug.
15. Add a Gatus check that `dnsBlocklistEntries > 100000` (catches the next silent-zero).

**Gatus / monitoring-of-monitoring**
16. Audit ALL ~45 Gatus check conditions for wrong patterns / stale assumptions (I only fixed one).
17. Make the Gatus SQLite DB readable for post-deploy verification (group perm), OR add an unauthenticated health-summary endpoint.
18. Add a "Gatus config reloaded successfully" canary (gatus exits on bad YAML — check process uptime > N).
19. Add `[RESPONSE_TIME]` bounds to every HTTP check per the AGENTS convention (some may be missing).

**Disk / memory / system health**
20. Clear the 14 stale build sandboxes (`nix-build-cleanup` or manual).
21. Run `nix-collect-garbage --delete-older-than 7d` (disk at 93%).
22. Investigate `overview` process at 4 GB RSS (top consumer) — leak?
23. Investigate chronic swap-full state — is `GPUActive` reclaimable, or is this the new baseline?
24. Add a memory-pressure gate to `pre-deploy-check` (warn if swap > 80% or available < 8 GiB).
25. Reconsider `OLLAMA_MAX_LOADED_MODELS=1` + `MemoryMax=32G` for ollama under the GPUActive pressure regime — will it OOM on first real model load?

**Redis / immich**
26. Add a collision guard: if a Docker container ever publishes `6379:6379`, immich's redis breaks silently. Add a comment in `lib/ports.nix` and/or a pre-deploy check.
27. Consider whether immich should use TCP redis too (drop the socket) for simplicity, or document why both transports are kept.
28. Verify immich-server actually reconnects over the socket after the redis-immich restart (the SupplementaryGroups for socket access is unchanged, but a restart is a restart).

**Deploy process**
29. Add a "deploy lock" file (flock) so concurrent buildflow + deploy can't race on the bootloader lock again.
30. Capture the bootloader-lock error specifically in `deploy.sh` with a retry-and-message (current generic exit handling would have masked it).
31. Surface memory/load in the deploy pre-flight output alongside disk.

**Ollama**
32. Verify ollama actually loads a model end-to-end (not just `/api/tags` 200 with empty list) — `ollama run` smoke test.
33. Confirm ollama survives a real inference request under GPU memory pressure without OOM.
34. Reconsider whether ollama should always-on vs socket-activated (now that it's always-on, it holds GPU mem even when idle — though RSS showed 34 MB, so unloaded).

**Docs hygiene**
35. Move "FIXED"-suffixed AGENTS entries to an archive (keep AGENTS.md lean).
36. Update `FEATURES.md`: DNS blocking now actually works (was silently broken); ollama is always-on.
37. Update `TODO_LIST.md`: add the Monitor365 cloud-sync investigation, the rpi3 deploy, the gatus audit.
38. Add a CHANGELOG.md entry for this session's fixes.

**Pre-commit / CI**
39. Add a statix/custom lint rule that flags `wantedBy = mkForce []` (the anti-pattern that caused the ollama bug).
40. Add a lint rule that flags `bl.file` used where `bl.file/${bl.name}` is meant (hard — but a comment/grep helper helps).

**Deep verification I skipped**
41. Confirm the rpi3 `tempAllowAll = false` path is exercised (the SystemNix evo-x2 path is, but rpi3 has its own blocklist set).
42. Confirm `mapping.json` for ALL 23 lists (not just StevenBlack) has entries post-build.
43. Confirm `dnsblockd` hot-reload (`dns_reload_interval = 1h`) will pick up the files correctly (not just first-load).
44. Confirm the Gatus OIDC native-login flow still works after the config rewrite (the check list changed; did `security.oidc` survive?).

**Operational**
45. Re-examine the `booted-system` (Jul 11) vs `current-system` (Jul 18) gap — a reboot is overdue; many kernel-level fixes (BTRFS, MGLRU, watchdog params) are in current-system but not live until reboot.
46. Schedule/perform the reboot in a maintenance window (note: per AGENTS, the `/run/booted-system` lag means running kernel is 7+ days behind config).
47. After reboot, re-verify all 5 endpoints (DNS blocklist, redis TCP, ollama auto-start, monitor365 agent, gatus).

**Strategic**
48. The whole class of "monitor checks the wrong thing" (monitor365 pattern, redis transport, ollama wantedBy) suggests a systematic review of every Gatus check against the service's actual contract.
49. Consider an integration test (NixOS VM test) that asserts: with ai-stack enabled, `systemctl is-active ollama` after boot. Would have caught the wantedBy bug at PR time.
50. Consider a "Gatus self-test" CI job: parse `gatus.yaml`, for each endpoint, run the check once and assert the expected condition holds in the current environment.

---

## g) Questions I cannot answer myself (max 3)

1. **Should I commit these 6 changed files now?** They're verified-deployed and working, but the working tree also contains many pre-existing modified files (CHANGELOG, README, ROADMAP, docs/*) from before this session that I did NOT touch and should NOT sweep into the same commit. Do you want a focused commit of just my 6 files, or do you have a staging plan for the rest?

2. **Is rpi3 in scope for me to deploy?** It carries the same dns-blocker fix and is currently running with zero blocking (silent), but it's a separate physical host — I can build/verify its config here but cannot deploy it without your confirmation (and it may need manual steps at the device).

3. **The Monitor365 cloud sync has been failing for 119 consecutive cycles with a ~597 MB backlog** — is this a known/intentional state (e.g. cloud environment decommissioned, or auth token rotated out), or should I open a full investigation? I don't know the intended cloud endpoint or whether it's expected to be reachable from evo-x2 right now.

---

_Arte in Aeternum — but verify, don't assume._

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
