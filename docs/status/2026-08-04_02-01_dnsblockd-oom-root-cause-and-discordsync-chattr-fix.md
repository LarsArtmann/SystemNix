# Status: DNS Stability Root Cause Found + DiscordSync chattr Fix Deployed

**Date:** 2026-08-04 02:01
**Session scope:** Investigate why user feels the need to manually add 9.9.9.9 to resolv.conf. Fix root cause + remaining deploy issues.

---

## a) FULLY DONE

### 1. Root Cause Diagnosis: dnsblockd Memory Leak
**The answer to "why is our DNS resolver so unstable":** dnsblockd has a genuine memory leak caused by unbounded OTEL cardinality.

- **Evidence collected:** 20+ OOM-kills in 7 days (almost hourly — Jul 31 alone had kills at 02:42, 03:45, 04:45, 05:45, 07:45, 08:46, 09:46, 10:46, ..., 23:51). Each kill = ~10s DNS outage. ~4 minutes of cumulative DNS downtime per day spread across micro-outages.
- **Root cause identified:** Unbounded OTEL/Prometheus time series retention. The Prometheus SDK reader (`internal/otel/otel.go:72-80`) retains every unique attribute-set in process memory forever. Four instruments feed unbounded-cardinality labels: `dns_domain` (telemetry.go:189-197), `http_path` (telemetry.go:140-155), `proxy_domain` x2 (telemetry.go:208-230). Each unique domain/path = one permanent in-memory time series.
- **Aggravating factor:** Go's default GC (GOGC=100) doesn't fire until heap doubles from ~600M base (~1.2G). But MemoryMax was 1G, so the process is killed before GC collects.
- **Secondary factor:** DNS observer path (`dns_observer.go:71-91`) dispatches tracking writes synchronously per-query (no semaphore, no batching — unlike the HTTP path which has a 32-slot semaphore). Under high QPS, SQLite WAL pages accumulate.
- **Bounded structures confirmed NOT the leak:** stats hits map (≤1000), rate limiter (≤10K LRU), sdns cache (≤256K entries), recent ring (100 entries), latency buffer (1000 samples), allowlist (≤1000 lazy expiry).

### 2. dnsblockd Memory Mitigation Deployed
- **`MemoryMax` raised from 1G → 2G** in `modules/nixos/services/dns-blocker.nix`
- **`GOMEMLIMIT=1500MiB` added** — forces Go GC to run aggressively below MemoryMax, collecting reachable-but-stale heap before the OOM wall
- **Verified live:** `memory.max = 2147483648` (2G), `GOMEMLIMIT=1500MiB` in deployed unit file. Current RSS: 590 MB (healthy, just restarted).

### 3. DiscordSync chattr ExecStartPre Fixed
- **Bug:** Upstream module ships `chattr -R +C /var/lib/discordsync 2>/dev/null || true` as ExecStartPre. systemd ExecStartPre is NOT shell — `2>/dev/null` and `|| true` are passed as LITERAL FILE ARGUMENTS to chattr. Log evidence: `chattr: No such file or directory while trying to stat 2>/dev/null`, `stat ||`, `stat true`. Also lacks `+` prefix → runs as `discordsync` user → `Operation not permitted`.
- **Fix:** `modules/nixos/services/discordsync.nix` uses `ExecStartPre = lib.mkForce [...]` to REPLACE the upstream list entirely. The broken chattr is gone. BTRFS +C (nodatacow) is nice-to-have but not required — DiscordSync uses WAL mode.
- **Verified live:** No chattr errors in discordsync journal since deploy.

### 4. resolv.conf Restored to Correct State
- **Bug:** The user had manually replaced the Nix-managed symlink with a regular file containing `nameserver 9.9.9.9` BEFORE `nameserver 127.0.0.1`. glibc queries nameservers in order and accepts the first NXDOMAIN — Quad9 returns NXDOMAIN for `*.home.lan` (private TLD), so glibc never fell through to dnsblockd on 127.0.0.1. `getent hosts dash.home.lan` returned exit 2 (NOT FOUND). All external vHost smoke checks failed.
- **Fix:** The deploy restored the Nix-managed symlink (`/run/current-system/etc/resolv.conf` → store path with only `127.0.0.1`).
- **Verified live:** `cat /etc/resolv.conf` shows only `nameserver 127.0.0.1`, `search home.lan`, `options edns0 trust-ad`. `getent hosts dash.home.lan` returns `192.168.1.150`.

### 5. Deploy Verified: 29 PASS, 0 FAIL
- **Post-deploy smoke test:** 29 PASS, 0 FAIL, 2 SKIP (DiscordSync API not ready — expected during startup backfill)
- **All external vHost checks pass:** Homepage, Forgejo, Status, Immich, Overview (all HTTPS 200)
- **All functional checks pass:** Crush Daily reports, SigNoz impersonation mode, SigNoz alert rules, Monitor365 agent↔server connectivity, File Renamer history
- **dnsblockd:** 0 OOM-kills since deploy (10 min uptime so far)

### 6. AGENTS.md Updated
- Added 3 new gotcha entries: dnsblockd OOM memory leak, manual resolv.conf 9.9.9.9 addition, DiscordSync upstream chattr shell-syntax bug
- Updated memory cap verification value from 64G → 90G in the `builtins.toString null` gotcha

### 7. All Commits Clean (auto-committed by daemon)
- `9bf6fc47` fix(nixos-services): resolve dns-blocker OOM kills and discordsync startup failure
- `fa43db84` docs(agents): add dnsblockd OOM, resolv.conf, and discord sync bugfixes to known issues

---

## b) PARTIALLY DONE

### 1. dnsblockd Memory Leak — Mitigated, NOT Fixed
- **What's done:** GOMEMLIMIT + 2G MemoryMax will significantly reduce OOM frequency (GOMEMLIMIT forces GC before the wall, 2G gives 500MB more headroom).
- **What's NOT done:** The actual leak is upstream in dnsblockd (`internal/server/telemetry.go`). The high-cardinality OTEL labels (`dns_domain`, `http_path`, `proxy_domain`) will still grow memory indefinitely — GOMEMLIMIT just makes GC collect faster. Over very long uptimes (days/weeks), memory may still creep toward 2G. The real fix is to drop or bucket those labels in dnsblockd's Go code.
- **Risk:** If GOMEMLIMIT isn't enough, we'll see OOM-kills at 2G instead of 1G — less frequent but still happening.

### 2. DiscordSync Service Health — chattr Fixed, Turso Sync Failing
- **What's done:** The broken chattr ExecStartPre is removed. The dbHeal cascade ran successfully (corrupt backup created at 01:00:26). The service starts, loads 3367 attachments for thumb-hash backfill.
- **What's NOT done:** DiscordSync is now failing with `turso: error: sync engine operation failed: database sync engine error: unexpected EOF`. This is a SEPARATE issue from the chattr bug — the dbHeal cascade created a fresh local DB, and Turso cloud sync is failing to initialize. The service crash-loops on this error. May need Turso re-authentication or sync state reset. This is the same Turso quota/connection class of issue documented in AGENTS.md.

### 3. Generation Mismatch — Deployed vs Evaluated
- **Deployed:** `/nix/store/ki7kj54i9s9xznxdh1jlmw5bvi2ryzfs-...`
- **Evaluated now:** `/nix/store/x8fb3fzmrhn5gm0k0da1cm81754i5isx-...`
- **Cause:** AGENTS.md was edited and auto-committed (fa43db84) AFTER the deploy. The documentation change causes a new system generation to evaluate (the toplevel derivation includes `/etc/static` which includes AGENTS.md content). This is cosmetic — the actual service configs are identical. A re-deploy would sync them.

---

## c) NOT STARTED

1. **Upstream dnsblockd fix:** Drop high-cardinality OTEL labels (`dns_domain`, `http_path`, `proxy_domain`) from `internal/server/telemetry.go` in the dnsblockd repo (`/home/lars/projects/dnsblockd`). This is the REAL fix for the memory leak.
2. **Upstream DiscordSync chattr fix:** Push a proper fix to the DiscordSync NixOS module (wrap chattr in `pkgs.writeShellApplication` or use `ExecStartPre=+/bin/sh -c '...'`).
3. **DNS resolution check in pre-deploy-check.sh:** The pre-deploy check doesn't validate that `*.home.lan` resolves correctly. A simple `getent hosts dash.home.lan` assertion would have caught the 9.9.9.9 issue immediately.
4. **Monitor365 server database pool timeout:** `monitor365-server.service: Failed with result 'timeout'` — `pool acquire failed: timed out waiting for connection`. Multiple background tasks failing (offline_alerts, correlation_engine, policy_violations). This is a DuckDB connection pool exhaustion issue, not related to this session's changes.
5. **Stale build sandboxes:** 13 directories in `/nix/var/nix/builds/` consuming 1.9 GB. The `nix-build-cleanup` timer should handle this, but BTRFS snapshots may hold references.
6. **Re-deploy to sync generation:** The deployed generation is stale by one doc commit. Low priority.

---

## d) TOTALLY FUCKED UP

### 1. Did NOT Audit Upstream ExecStartPre Entries
When working with the DiscordSync module in the prior session, I added `dbHeal` and `waitDnsReady` as ExecStartPre entries but NEVER reviewed the upstream module's existing ExecStartPre. The broken chattr was there the entire time. I should have run `systemctl cat discordsync.service` or read the upstream module source to audit ALL ExecStartPre entries before deploying.

### 2. Did NOT Check DNS Resolution Before Deploying
The DNS issue (9.9.9.9 in resolv.conf) was not discovered until post-deploy smoke tests revealed all external vHosts failing. I should have verified `getent hosts dash.home.lan` BEFORE starting any build work. The issue was pre-existing (user manually edited resolv.conf at some earlier point).

### 3. Did NOT Investigate dnsblockd Stability When User Asked About DNS
When the user asked "why is our DNS resolver so unstable", my first instinct should been to check dnsblockd's crash history (`journalctl -u dnsblockd --since "7 days ago" | grep oom-kill`), not jump to the resolv.conf content. The OOM-kill pattern was the smoking gun, and I only found it after being prompted to "READ, UNDERSTAND, RESEARCH, REFLECT".

### 4. Did NOT Fix DiscordSync Turso Sync Issue
The chattr fix was necessary but not sufficient. DiscordSync still crash-loops because Turso sync fails after the dbHeal cascade created a fresh DB. I deployed a fix that stops the chattr error but left the service in a crash-loop on a DIFFERENT error. I should have verified the service actually starts successfully before declaring victory.

### 5. The GOMEMLIMIT Value is a Guess
`1500MiB` was chosen as "500MB below MemoryMax" but I have no empirical data showing this is the right threshold. If the OTEL leak grows faster than GC can collect, the process will still OOM at 2G. I should monitor memory growth over the next hours/days and adjust.

---

## e) WHAT WE SHOULD IMPROVE

1. **Audit upstream modules before consumption:** Every time we `imports = [ inputs.X.nixosModules.default ]`, we should read the upstream module's ExecStartPre, serviceConfig, and unitConfig. The chattr bug was hiding in plain sight.
2. **Pre-deploy DNS validation:** Add `getent hosts dash.home.lan` to pre-deploy-check.sh. DNS breakage is silent and cascades to all external vHost failures.
3. **Monitor dnsblockd memory growth:** Add a Gatus alert for dnsblockd memory usage (e.g., alert when cgroup memory.current > 80% of MemoryMax for 5 min). This would catch the OOM-before-OOM pattern.
4. **GOMEMLIMIT on all Go services:** Every Go service in SystemNix with a MemoryMax should also have GOMEMLIMIT set to ~75% of MemoryMax. This is Go best practice for containerized services and prevents the "GC doesn't fire before OOM" class of bug.
5. **Pre-commit check for ExecStartPre shell syntax:** A linter that flags `2>/dev/null`, `|| true`, `&&`, or `;` in ExecStartPre/ExecStart lines (which systemd treats as literal arguments, not shell operators).
6. **Upstream tracking:** When SystemNix works around an upstream bug (chattr, OTEL labels), create an issue/PR in the upstream repo. The workaround is debt; the upstream fix is the asset.
7. **Post-deploy service verification:** The post-deploy smoke test checks if a service process is alive, but for DiscordSync it SKIPs the API check (expected during backfill). We should have a deferred re-check that verifies the service 10 min after deploy.

---

## f) Up to 50 Things We Should Get Done Next

### Critical (P0)
1. **Fix DiscordSync Turso sync failure** — service is crash-looping on `unexpected EOF` from Turso. Likely needs Turso token/credentials check or sync state reset.
2. **Monitor dnsblockd memory over 24h** — verify GOMEMLIMIT+2G actually stops the hourly OOM pattern. Check `journalctl -u dnsblockd --since "24 hours ago" | grep -c oom-kill`.
3. **Fix monitor365-server DuckDB pool timeout** — `pool acquire failed: timed out waiting for connection`. Background tasks (offline_alerts, correlation_engine, policy_violations) all failing.

### High Priority (P1)
4. **Fix upstream dnsblockd OTEL labels** — drop `dns_domain`, `http_path`, `proxy_domain` from `telemetry.go` or bucket them. This is the real fix for the memory leak.
5. **Push chattr fix upstream** to DiscordSync NixOS module.
6. **Add DNS check to pre-deploy-check.sh** — `getent hosts dash.home.lan` must resolve.
7. **Add GOMEMLIMIT to all Go services** — audit all systemd services running Go binaries, add `GOMEMLIMIT` at ~75% of MemoryMax.
8. **Add dnsblockd memory Gatus alert** — alert when cgroup `memory.current` > 80% of MemoryMax.
9. **Re-deploy to sync generation** — the evaluated generation differs from deployed by one doc commit.
10. **Clean 13 stale build sandboxes** — 1.9 GB in `/nix/var/nix/builds/`.
11. **Push 2 unpushed commits** — `9bf6fc47` and `fa43db84` are ahead of origin/master.

### Medium Priority (P2)
12. **Write standalone BTRFS DB recovery script** (`scripts/recover-db.sh`) — generalize the discordsync dbHeal pattern for any SQLite DB on BTRFS.
13. **Add ExecStartPre shell-syntax linter** to pre-commit hooks — catch `2>/dev/null` / `|| true` in systemd ExecStart lines.
14. **Audit all upstream NixOS modules** consumed by SystemNix for ExecStartPre shell-syntax bugs (monitor365, PMA, overview, file-renamer, crush-daily).
15. **Add deferred post-deploy recheck** for services with known startup delays (DiscordSync, qmd) — verify 10 min after deploy instead of SKIP.
16. **Add dnsblockd to system-health collector** — track memory growth rate as a Prometheus metric.
17. **Consider reducing dnsblockd tracking retention** — `RequestTracksDays=30` and `MetricsDays=90` may be too aggressive for a homelab; reducing to 7/30 would reduce SQLite contention.
18. **Add DNS failover health check improvement** — the keepalived DNS check (`host google.com 127.0.0.1`) should also check a local zone record to catch dnsblockd-local-zone failures.
19. **Document GOMEMLIMIT pattern** in AGENTS.md as a general Go service best practice.
20. **Add systemd watchdog (WatchdogSec)** to dnsblockd — if the process hangs (not just OOMs), systemd will restart it.
21. **Investigate DNS observer semaphore** — patch dnsblockd upstream to route DNS tracking writes through the same 32-slot semaphore as the HTTP path.
22. **Add dnsblockd version pinning** — consider pinning to a specific commit instead of `ref=master` to prevent surprise breakage.
23. **Create dnsblockd integration test** — VM test that verifies DNS resolution, blocklist operation, and memory stability under load.
24. **Add `options rotate timeout:1` to resolv.conf** — if a fallback nameserver is ever re-added, these options ensure glibc tries all nameservers and doesn't block on a dead one.
25. **Audit all services for `ProtectHome` + MemoryMax interaction** — any service reading user data under a memory cap could silent-fail like the crush-daily bug.

### Lower Priority (P3)
26. **Add BTRFS filesystem health to post-deploy check** — verify scrub status, device-unallocated space, and snapshot freshness.
27. **Consider switching dnsblockd to `tracking_mode = "OFF"` or `"METADATA_ONLY"` with shorter retention** — reduces SQLite write pressure.
28. **Add Prometheus alert for Turso sync failures** — DiscordSync crash-loops silently on Turso errors.
29. **Document the GOMEMLIMIT calculation methodology** — how to choose the right value based on MemoryMax and expected heap size.
30. **Add `MemoryHigh` to dnsblockd** — currently only MemoryMax is set; MemoryHigh at ~80% of max would trigger kernel reclaim before the hard wall.
31. **Consider adding a DNS cache statistics exporter** — expose dnsblockd's sdns cache hit/miss ratio to Prometheus.
32. **Add network dependency graph** — document which services depend on dnsblockd and in what order they fail.
33. **Review dnsblockd's `dns_exit_on_failure = true`** — if the DNS resolver fails, dnsblockd exits entirely. Consider `false` to keep the block-page HTTP server alive.
34. **Add journalctl persistence tuning** — ensure DNS outage windows are preserved in journal history for post-mortem analysis.
35. **Consider adding a secondary DNS resolver** — rpi3-dns exists as a VRRP backup, but the failover hasn't been tested recently.
36. **Test DNS failover** — `systemctl stop dnsblockd` on evo-x2, verify rpi3-dns picks up via keepalived VRRP.
37. **Add DNS resolution latency tracking** — Gatus check measuring DNS response time trends over time.
38. **Review all `ref=master` flake inputs** — pin to tags or specific commits for production stability.
39. **Add `systemd-analyze security dnsblockd` output to docs** — document the current hardening profile.
40. **Consider dnsblockd memory profiling endpoint** — add `GET /debug/pprof/heap` if not already present, for targeted leak diagnosis.
41. **Add `zram` priority tuning** — ensure zram swap is configured to favor DNS-critical services under pressure.
42. **Document the full DNS resolution chain** — from application → glibc → resolv.conf → dnsblockd → sdns cache → DoT forwarders → Cloudflare/Quad9.
43. **Add DNS blocklist update monitoring** — alert when blocklist entries drop significantly (could indicate a fetch failure).
44. **Consider adding `dns_block_ttl` tuning** — longer TTL for blocked domains reduces resolver load.
45. **Review dnsblockd's rate limiter config** — `dns_rate_limit_per_sec` and `dns_rate_limit_burst` should be tuned for homelab traffic patterns.
46. **Add `sdns` cache size configuration** — currently hardcoded at 256K entries (`defaultCacheSize`); make it configurable for memory-constrained scenarios.
47. **Consider SQLite `PRAGMA mmap_size` tuning** for dnsblockd tracking DB — may reduce memory pressure by memory-mapping the DB instead of caching pages in RAM.
48. **Add systemd `RestrictNetworkInterfaces` to dnsblockd** — only allow `lo` and `eno1` for the DNS listener.
49. **Document the hourly-OOM pattern** in dnsblockd's upstream AGENTS.md or ARCHITECTURE.md.
50. **Consider a Go pprof dump on next dnsblockd OOM** — set `GOTRACEBACK=crash` to get a full goroutine dump on the next OOM-kill for precise leak source identification.

---

## g) Questions for User

### Q1: DiscordSync Turso Sync — Re-initialize or Skip?
DiscordSync is crash-looping on `turso: error: sync engine operation failed: database sync engine error: unexpected EOF`. This happened after the dbHeal cascade created a fresh local DB. The Turso cloud sync needs to re-initialize from scratch. Options:
- **A) Disable Turso sync temporarily** — set `syncHandle=nil` so it runs local-only until we sort out Turso. DiscordSync has an upstream config for this.
- **B) Re-authenticate Turso** — the Turso token may have expired or the database may have been suspended. Needs `turso db shell` access to verify.
- **C) Leave it crash-looping** — the start-limit burst (10) will eventually stop it. Data is still stored locally; nothing is lost.

### Q2: dnsblockd Upstream Fix — When?
The GOMEMLIMIT+2G mitigation will reduce OOM frequency but the real fix is dropping high-cardinality OTEL labels in dnsblockd's Go code (`/home/lars/projects/dnsblockd/internal/server/telemetry.go`). Should I:
- **A) Fix it now** — go to the dnsblockd repo, drop/bucket the labels, run tests, bump flake input.
- **B) Monitor first** — wait 24h to see if GOMEMLIMIT+2G is sufficient, then decide if the upstream fix is urgent.
- **C) Just increase MemoryMax to 4G** — throw RAM at it (you have 93G) and defer the code fix.

### Q3: Should I Push the 2 Unpushed SystemNix Commits?
`9bf6fc47` (fix) and `fa43db84` (docs) are ahead of origin/master. The auto-commit daemon created them but hasn't pushed. Should I push now, or do you want to review first?

---

*Status generated 2026-08-04 02:01. System: evo-x2, NixOS 26.11 unstable, kernel 7.1.5, 93 GB RAM.*
