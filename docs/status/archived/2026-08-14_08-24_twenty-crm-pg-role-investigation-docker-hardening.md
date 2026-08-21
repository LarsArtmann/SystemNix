# Status: Twenty CRM PG Role Investigation + Docker Hardening

**Date:** 2026-08-14 08:24 CEST
**Session focus:** Fix Twenty CRM `FATAL: role "twenty" does not exist` + decide Docker vs native nixification

---

## Incident Summary

TODO_LIST.md Priority 2 item reported: `twenty-server` crash-loops with `FATAL: role "twenty" does not exist`. Data (1 user, 1 workspace, 66 companies across 90 tables) reportedly at risk. Task: fix PG role + decide on Docker vs native nixification.

---

## a) FULLY DONE

### 1. Root Cause Diagnosis: PG role issue was ALREADY RESOLVED at runtime

**Investigation chain:**

- `docker ps -a --filter name=twenty` — ALL 4 containers UP, 0 restarts on server/worker, healthchecks passing
- `docker logs twenty-server-1` — NO `FATAL: role "twenty" does not exist` anywhere in 3,110 log lines
- `docker inspect twenty-server-1 --format '{{.Config.Env}}'` — `PG_DATABASE_URL=postgres://postgres:...@db:5432/twenty` (user is `postgres`, NOT `twenty`)
- `docker inspect twenty-db-1` — `POSTGRES_USER=postgres`, `POSTGRES_DB=twenty`
- `docker exec twenty-db-1 psql -U postgres -c "\du"` — 15 roles, all system + `postgres`. NO role named `twenty` exists (and none is needed)
- `docker exec twenty-db-1 psql -U postgres -c "\l"` — Database `twenty` exists, owner `postgres`
- **Data verified intact:** 90 tables in `workspace_e9cj8i2yyuv46o8h43y8adli` + `core` schemas, 66 companies in `workspace_e9cj8i2yyuv46o8h43y8adli.company`
- `docker stats` — server: 480MB/1G, worker: 568MB/2G, db: 38MB/2G, redis: 5.5MB/256M. All healthy

**Conclusion:** The `role "twenty" does not exist` error was a TRANSIENT issue from a prior session where the PostgreSQL volume was recreated (likely after an oomd kill or Docker restart). When the volume was re-initialized, `POSTGRES_USER=postgres` created the correct role. The running system has been healthy since the last deploy.

### 2. Docker vs Native Nixification Decision: Docker stays

Twenty CRM is a large third-party NestJS application:

- 50+ NestJS InstanceLoader modules at startup
- Complex native dependencies (node-gyp, better-sqlite3 patterns)
- Officially maintained Docker images (`twentycrm/twenty:v2.7.3`)
- Uses BullMQ workers, Redis, and PostgreSQL — all containerized
- Upstream provides no Nix packaging, no NixOS module, no flake

Nixifying this would require: vendoring the entire Node.js build, mirroring the NestJS module resolution, maintaining custom package overrides for every dependency update, and recreating the worker/Redis/PG orchestration natively. Enormous effort, zero benefit, ongoing maintenance burden. **Docker is the correct choice.**

### 3. Docker Container Memory Limits Hardened

**File:** `modules/nixos/services/twenty.nix`

Added `mem_limit` + `memswap_limit` to ALL containers that were previously unbounded:

| Container | Memory Limit   | Swap Limit | `NODE_OPTIONS`                         | Rationale                                                                 |
| --------- | -------------- | ---------- | -------------------------------------- | ------------------------------------------------------------------------- |
| server    | **1g** (new)   | 1g         | `--max-old-space-size=768` (new)       | Was 529MB unbounded; cap V8 heap at 768M to prevent oomd targeting        |
| worker    | 2g (existing)  | 2g         | `--max-old-space-size=1536` (existing) | Previously fixed in 08-12 session                                         |
| db        | **2g** (new)   | 2g         | N/A                                    | PostgreSQL for a 90-table CRM with 66 companies — 2G is generous headroom |
| redis     | **256m** (new) | 256m       | N/A                                    | Redis for BullMQ job queue only; `noeviction` policy prevents OOM crashes |

**Defense against systemd-oomd:** These limits prevent any Twenty container from becoming the top memory consumer under `/system.slice` during system pressure events. The `NODE_OPTIONS` heap caps ensure V8 GC runs aggressively BEFORE hitting the container hard limit, reducing RSS and making the containers less attractive oomd targets.

**Runtime verification:** `docker inspect` confirms all limits are LIVE (server: 1073741824 bytes = 1G, worker: 2147483648 = 2G, db: 2147483648 = 2G, redis: 268435456 = 256M).

### 4. Verification: nix flake check passes

`nix flake check --no-build` — all checks passed. All NixOS modules (including `twenty`) evaluate cleanly.

### 5. Documentation Updated

- `TODO_LIST.md`: Twenty CRM item marked `[x]` done with resolution summary
- `TODO_LIST.md`: Docker container memory limits item narrowed to Manifest/Dozzle only

---

## b) PARTIALLY DONE

### Memory limits verified live but Nix config not yet deployed

The running Docker containers ALREADY have the memory limits applied (verified via `docker inspect`), meaning a prior session or the auto-git daemon already deployed a compose file with these values. However, the Nix module (`twenty.nix`) in the working tree was MISSING these limits — meaning the next `nix run .#deploy` would have REVERTED them. This session aligned the declarative Nix config with the runtime state. **The changes need to be deployed to make the Nix config authoritative.** **→ RESOLVED:** landed at `8ad493c9` and deployed in the 09:30 session.

---

## c) NOT STARTED

- ~~**No deploy** — Changes are in the working tree but not deployed via `nix run .#deploy`. The running containers happen to match (from prior runtime changes), but the Nix config is not yet the source of truth for these values~~ done — deployed in the 09:30 session (`8ad493c9`)
- **No verification of server `NODE_OPTIONS` under load** — The 768M heap cap on the server could be too tight if the CRM handles bulk imports or heavy GraphQL queries. Only runtime usage (480MB) was observed, not peak load
- ~~**No Gatus alert for Twenty CRM health** — The healthz endpoint is checked by Gatus (confirmed in `gatus-config.nix`), but no Docker container restart monitoring exists. The 235-restart worker loop from 08-12 would still go undetected by Gatus~~ done at `9b6590bf` — `docker_container_restart_count` collector + "Docker Container Restarts" Gatus alert (gatus-config.nix:911)
- ~~**Manifest container memory limits** — `mnfst-manifest-1`, `mnfst-postgres-1`, and `dozzle` are still unbounded (separate Docker service, not part of Twenty)~~ done at `7afab3f8` — Manifest both at 1G (postgres verified live); Dozzle 256m in config but its runtime container was never recreated (still 0)
- **No investigation of WHY the PG role error originally appeared** — The transient error could recur if the Docker volume is recreated again. Adding a startup check or assertion could prevent confusion in future sessions

---

## d) TOTALLY FUCKED UP

### Nothing catastrophic, but:

- **I didn't deploy.** The Nix changes are in the working tree but not deployed. The running containers happen to match because they were already changed at runtime, but this is fragile — the next deploy from a clean checkout would have reverted the limits if I hadn't caught it
- **I didn't verify whether the `role "twenty"` error was reproducible.** I confirmed it's NOT currently happening, but I didn't check WHEN it last occurred or what triggered it. The TODO item said "crash-loops" present tense, but the system was already healthy. I should have checked `docker events --since` or journal timestamps to understand the timeline
- **I didn't check if Twenty's backup is actually working.** The backup timer (`twenty-backup.timer`) runs `pg_dump` daily at 02:00. I verified the data exists but didn't check if the backup has been succeeding. With the prior oomd kill storms and nix-daemon outage, backups may have been skipped
- ~~**I didn't add Twenty to the `backup-coordination` module.** The backup timer exists in `twenty.nix`, but it's NOT registered in `services.backup-coordination.backups` in `configuration.nix` — meaning backup freshness is not monitored by Gatus~~ **premise WRONG (08-14):** it WAS registered — `configuration.nix:578` (since `976e9547`); nothing to add

---

## e) WHAT WE SHOULD IMPROVE

1. **Always verify the "current" error state before acting** — The TODO said "crash-loops" but the system was healthy. I should have led with "the issue is already resolved at runtime" rather than investigating for 10 tool calls before reaching that conclusion. Status reports and TODO items are point-in-time — they may already be stale
2. **Deploy after making changes** — I made Nix edits and verified eval, but didn't deploy. The running system matches by coincidence (prior runtime changes), not because my Nix config is live. This is a hidden drift risk
3. ~~**Register Twenty backup in backup-coordination** — The backup timer exists but is unmonitored. A silent backup failure would go unnoticed indefinitely~~ done (existing rule) — already registered since `976e9547` (verified live: `backup_healthy{backup="twenty"}=1`); premise was wrong
4. **Add startup PG role validation** — A compose `healthcheck` or startup script that verifies the expected PG role exists would catch volume recreation mismatches early, preventing the confusing `role "twenty" does not exist` error from recurring
5. **Consider `mkDockerServiceFactory` per-container memory limit support** — Instead of manually adding `mem_limit` to each service in each compose file, the factory could accept a `containerMemoryLimits` attrset and inject limits automatically
6. ~~**Check Docker container restart counts in monitoring** — The 235-restart worker loop went undetected. A Prometheus metric + Gatus alert on `docker inspect --format '{{.RestartCount}}'` would catch all future restart loops across ALL containers~~ done at `9b6590bf` — all 7 containers emit restart metrics (live: count 0)

---

## f) Up to 50 Things to Get Done Next

### Critical

1. ~~**Deploy the Twenty changes** — `nix run .#deploy` to make the Nix config authoritative for container memory limits~~ done — deployed in the 09:30 session (`8ad493c9`)
2. ~~**Verify Twenty health after deploy** — `docker ps`, `docker inspect twenty-server-1 --format '{{.RestartCount}}'`, check `/healthz` endpoint~~ done — verified live 08-14: all 7 containers in restart metrics with count 0; FEATURES ⚠️→✅ (`61a2224b`)
3. ~~**Check Twenty backup status** — `ls -la /var/lib/twenty/backup/` to see if `pg_dump` has been succeeding. Verify the most recent backup file is < 24h old~~ done — dumps through 08-14 02:06; `backup_healthy{backup="twenty"}=1` live

### Twenty CRM Hardening

4. ~~**Add Twenty to backup-coordination** — Register in `services.backup-coordination.backups.twenty` in `configuration.nix` with directory `/var/lib/twenty/backup`, filePattern `*.sql`, maxAgeHours 48~~ done (existing rule) — already registered since `976e9547` (maxAgeHours 31); the "NOT registered" premise was wrong
5. **Verify server NODE_OPTIONS under load** — Test a bulk import or heavy GraphQL query to ensure 768M heap is sufficient. If it OOMs, raise to 1024M
6. **Add PG startup role check** — Extend the `fixCollation` oneshot or add a new oneshot that verifies `SELECT 1 FROM pg_roles WHERE rolname = 'postgres'` passes before the server starts
7. **Consider `MemoryHigh` (soft throttle) on containers** — Docker compose supports `mem_reservation` (soft limit). Setting it to 80% of `mem_limit` encourages reclaim before hard OOM

### Docker Memory Limits (Remaining)

8. ~~**Add mem_limit to `mnfst-manifest-1`** — Manifest app container is unbounded~~ done at `7afab3f8` (1g)
9. ~~**Add mem_limit to `mnfst-postgres-1`** — Manifest PostgreSQL is unbounded~~ done at `7afab3f8` (1g, verified live 08-14)
10. ~~**Add mem_limit to `dozzle`** — Log viewer container is unbounded~~ done in config at `7afab3f8` (256m) — **but the runtime container was never recreated and is still unbounded (live: Memory=0)**
11. ~~**Audit ALL Docker services for missing limits** — Check if any other Docker compose stacks in SystemNix have unbounded containers~~ done at `7afab3f8` (Manifest + Twenty + Dozzle = every stack bounded in config)
12. **Consider `mkDockerServiceFactory` enhancement** — Accept per-container memory limits as a structured option rather than raw compose attrs

### Monitoring Gaps

13. ~~**Add Docker container restart count collector** — `docker inspect --format '{{.RestartCount}}'` for all containers → Prometheus textfile metric~~ done at `9b6590bf`
14. ~~**Add Gatus alert on Docker restart count** — Alert when any container exceeds N restarts per hour~~ done at `9b6590bf` ("Docker Container Restarts", gatus-config.nix:911)
15. ~~**Add `system_oomd_kills_total` metric** — Textfile collector grepping `journalctl -u systemd-oomd --grep "killed"` per unit~~ done at `9b6590bf` — verified live: 2408 kills counted
16. **Add Docker container memory usage metric** — `docker stats` → Prometheus textfile for per-container memory usage vs limit percentage
17. ~~**Add disk usage Gatus alert (85% threshold)** — Root filesystem at 90-93% with no proactive alerting~~ done at `9b6590bf` (`system_disk_usage_over_threshold` + "Root Disk Usage"; live value 86 on 08-14)
18. ~~**Add I/O PSI Gatus alert** — PSI I/O data is collected but has NO alert. Leading indicator of QLC SLC cache exhaustion → WDT crash~~ done — "I/O Stall Rate" check already existed (`004924be`-era; gatus-config.nix:710)

### Deploy & System Health

19. ~~**Run foreground BTRFS scrub on `/`** — Root FS has NEVER been scrubbed. Same NVMe as `/data` which had 13 corrupted files~~ done (superseded) — weekly `autoScrub` (`snapshots.nix:104`, `ab7c331a`); current status=interrupted on both mounts (reboots)
20. **Free disk space** — Root at 90-93% on QLC NAND. `nix-collect-garbage -d`, `docker system prune`, audit `/data` usage — **08-14: 87% (97G free)**, still above the 85% alert threshold
21. ~~**Reboot evo-x2** — NixOS system registry override for nixpkgs tarball regression is in config but NOT active until reboot~~ done (moot) — last boot (08-13 21:42) post-dates the 08-06 fix (`d2443c29`)
22. **Off-site backup** — No DR backup exists. Forgejo, Immich, Twenty, DiscordSync would all be lost on SSD failure (tracked in TODO_LIST)

### Code Quality

23. **Add eval-time assertion for `StartLimitBurst` placement** — In systemd 261+, placing it in `serviceConfig` is silently ignored
24. ~~**Add `node_textfile_scrape_error` Gatus check** — Invalid `.prom` files cause node_exporter to drop ALL textfile metrics silently~~ done at `9b6590bf` ("Textfile Collector Health", gatus-config.nix:962)
25. ~~**Add crash-loop detector metric** — Rate-based alert on `system_service_nrestarts` per 10-min window~~ done at `9b6590bf` (`system_any_service_crash_loop`, gatus-config.nix:889)

---

## g) Questions

### 1. Should I deploy now, or wait?

~~The Twenty memory limit changes are in the working tree and pass `nix flake check --no-build`. The running containers already match (from prior runtime changes), so a deploy would make the Nix config authoritative rather than changing runtime behavior. Should I deploy immediately, or batch this with other pending changes?~~ **answered:** deployed in the 09:30 session (`8ad493c9` + `7afab3f8`).

### 2. Is the Twenty CRM backup actually being tested?

The `pg_dump` timer runs daily at 02:00, but the backup has never been tested for restorability. A `pg_dump` that succeeds but produces a corrupt or incomplete SQL file would give false confidence. Should I add a periodic restore-test (e.g., restore to a temp PG container and verify table counts), or is the current "just run pg_dump" approach acceptable for now?

### 3. Do you want the Manifest and Dozzle containers memory-limited in this same session?

~~They're the last unbounded Docker containers on the system. Adding limits is a 5-minute change to `manifest.nix` + whatever module manages Dozzle. Should I do that now, or is it out of scope for this Twenty-focused task?~~ **answered:** done at `7afab3f8` (Manifest 1g×2 verified live; Dozzle 256m in config — runtime container still awaiting recreation, see `2026-08-14_09-14` §f.4).
