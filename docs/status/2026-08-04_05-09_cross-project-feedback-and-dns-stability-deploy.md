# Status: Cross-Project Feedback Files + DNS Stability Deploy

**Date:** 2026-08-04 05:09
**Session scope:** (1) Root-cause dnsblockd DNS instability, fix, deploy. (2) Write actionable feedback files for all affected upstream repos.

---

## a) FULLY DONE

### 1. DNS Stability Root Cause + Fix Deployed (dnsblockd OOM)
- **Root cause found:** dnsblockd OOM-killed ~hourly (20+ kills in 7 days). Each kill = ~10s DNS outage. Three OTEL instruments use unbounded-cardinality labels (`dns_domain`, `http_path`, `proxy_domain`) that retain one in-memory time series per unique value forever — no eviction, no cardinality cap.
- **Secondary cause:** DNS observer dispatches tracking writes synchronously per-query (no semaphore), unlike the HTTP path which has a 32-slot bounded semaphore.
- **Mitigation deployed:** `MemoryMax` 1G → 2G + `GOMEMLIMIT=1500MiB` in `dns-blocker.nix`. Forces Go GC to run below MemoryMax.
- **Deploy verified:** 29 PASS, 0 FAIL, 2 SKIP. All external vHost checks pass. `getent hosts dash.home.lan` → `192.168.1.150`. 0 OOM-kills since deploy.

### 2. resolv.conf Restored
- The user had manually replaced the Nix-managed symlink with a regular file containing `nameserver 9.9.9.9` BEFORE `127.0.0.1`. glibc accepts the first NXDOMAIN (Quad9 for `*.home.lan`) and never queries dnsblockd.
- Deploy restored the Nix-managed symlink: only `nameserver 127.0.0.1`.

### 3. DiscordSync chattr Fixed
- Upstream module ships `chattr -R +C ... 2>/dev/null || true` as ExecStartPre — systemd treats shell syntax as literal file arguments. Also missing `+` prefix (runs as service user → permission denied).
- Fixed with `lib.mkForce` in `discordsync.nix` — replaces upstream ExecStartPre entirely.

### 4. 7 Feedback Files Written Across 7 Repos

| Repo | File | Severity | Bug |
|---|---|---|---|
| **dnsblockd** | `otel-cardinality-memory-leak-and-dns-observer-backpressure.md` (20KB) | Critical | Unbounded OTEL labels + synchronous DNS tracking dispatch |
| **DiscordSync** | `chattr-execstartpre-shell-syntax-bug.md` | Critical | Shell syntax in non-shell ExecStartPre |
| **monitor365** | `hardcoded-10k-event-limit-blocks-backlog.md` | High | 10K/day limit makes 597M backlog take 163 years to drain |
| **PMA** | `type-notify-without-sd-notify-crash-loop.md` | Critical | Type=notify set but Go binary never calls sd_notify |
| **mr-sync** | `outputs-signature-missing-ellipsis.md` | Medium | outputs function missing `...` breaks flake eval |
| **crush-daily** | `test-dsns-missing-file-prefix.md` | Low | Test DSNs missing `file:` prefix (masks prod-only bugs) |
| **file-and-image-renamer** | `init-service-or-warn-nil-swallow-antipattern.md` | Medium | initServiceOrWarn swallows errors, returns nil → panics |

Each file was verified against actual source code (exact file:line references, code snippets, confirmed whether the bug was already fixed or still present). Projects where the bugs were already fixed (go-commit git-config, crush-daily errgroup/timezone, monitor365 COALESCE/circuit-breaker) were NOT written — no point reporting fixed issues.

### 5. AGENTS.md Updated (SystemNix)
- 3 new gotcha entries: dnsblockd OOM memory leak, manual resolv.conf 9.9.9.9 addition, DiscordSync upstream chattr shell-syntax bug.
- Memory cap verification value updated from 64G → 90G.

### 6. Prior Status Report Written
- `docs/status/2026-08-04_01-20_crash-recovery-deploy-results-and-issues.md` (earlier this session)

---

## b) PARTIALLY DONE

### 1. dnsblockd Memory Leak — Mitigated, NOT Fixed
- GOMEMLIMIT + 2G MemoryMax reduces OOM frequency but does not eliminate the leak. OTEL series are reachable (held by Prometheus registry) — GC cannot collect them. Over days/weeks of uptime, memory will still creep toward 2G.
- **The real fix** is upstream in dnsblockd: drop/bucket the high-cardinality OTEL labels. Feedback file written but no code changes made to dnsblockd.

### 2. DiscordSync Service Health — chattr Fixed, Turso Sync Still Failing
- The chattr crash-loop is fixed. The dbHeal cascade runs correctly.
- BUT DiscordSync now fails on `turso: error: sync engine operation failed: database sync engine error: unexpected EOF`. The dbHeal cascade created a fresh local DB; Turso cloud sync can't re-initialize. Service is still crash-looping on this error.
- Needs root access to investigate (`sudo`/`systemctl` blocked for assistant).

### 3. Feedback Files Written But NOT Committed
- Only the feedback `.md` files were written to disk. The auto-commit daemon may pick them up, but they are currently uncommitted in their respective repos:
  - `dnsblockd`: 2 files modified (FEATURES.md, TODO_LIST.md — pre-existing, not ours) + untracked feedback file
  - `DiscordSync`: 2 files modified (pre-existing) + untracked feedback file
  - `file-and-image-renamer`: untracked `docs/feedback/` directory
  - `monitor365`, `PMA`, `mr-sync`, `crush-daily`: untracked feedback files (auto-commit daemon may have already committed these)

### 4. crush-daily Has a Typo Directory (`docs/feeback/`)
- Pre-existing typo: `docs/feeback/new/` (missing 'd') exists alongside the correct `docs/feedback/new/`. The typo dir is empty but should be cleaned up or renamed.

---

## c) NOT STARTED

1. **Fix the actual dnsblockd OTEL labels upstream** — drop `dns_domain`, `http_path`, `proxy_domain` from `telemetry.go` or bucket them. Feedback file written, code not changed.
2. **Fix the DiscordSync chattr upstream** — replace the broken ExecStartPre with a `writeShellApplication` wrapper. Feedback file written, code not changed.
3. **Fix the PMA Type=notify upstream** — change to `Type=exec` or implement `sd_notify` in Go. Feedback file written, code not changed.
4. **Fix the mr-sync outputs signature upstream** — add `...` to the outputs function. Feedback file written, code not changed.
5. **Fix the crush-daily test DSNs** — add `file:` prefix to all test `sql.Open` calls. Feedback file written, code not changed.
6. **Fix the file-and-image-renamer initServiceOrWarn** — add `initServiceOrFail` for required deps. Feedback file written, code not changed.
7. **Fix the monitor365 10K/day limit** — make configurable via config file. Feedback file written, code not changed.
8. ~~**DiscordSync Turso sync failure** — needs root access to diagnose and fix.~~ done (switched to sqlite-only backend; Turso abandoned)
9. ~~**monitor365-server DuckDB pool timeout** — `pool acquire failed: timed out waiting for connection`. Not investigated (separate from this session's scope).~~ mitigated at `183925f4` (server health watchdog; root cause tracked TODO_LIST P6)
10. **Push 3 unpushed SystemNix commits** to origin/master.
11. **Clean up crush-daily typo directory** (`docs/feeback/` → should not exist).

---

## d) TOTALLY FUCKED UP

### 1. Wrote Feedback for Already-Fixed Bugs (Partially Caught)
I initially planned 8 feedback files. During research, I discovered that 4 of the planned bugs were ALREADY FIXED upstream:
- **go-commit:** `git config` via exec.Command — FIXED (commit `fd9a9664`). Verified in `pkg/commit/git/gogit.go:91-108`. Skipped.
- **crush-daily errgroup:** Uses plain `errgroup.Group` with manual error collection — FIXED (commit `868fe33`). Verified in `internal/insights/insights.go:201`. Skipped.
- **crush-daily Yesterday():** Uses `time.Date()` for local midnight — FIXED. Verified in `internal/collector/collector.go:437-445`. Skipped.
- **monitor365 COALESCE:** Uses qualified table prefix — FIXED (commit `b900d3454`). Verified in `crates/db/src/tenant.rs:7`. Skipped.

I caught these during the research phase and did NOT write feedback for them. Good. But the fact that I had them on my initial todo list means I was relying on the AGENTS.md gotcha table (which documents the fix history) rather than checking the current code state first. I should have verified code state BEFORE building the todo list.

### 2. Did NOT Push Any Feedback Files
The feedback files are sitting on disk uncommitted/unpushed in 7 different repos. If the auto-commit daemon doesn't pick them up (some repos may not have it configured), they'll rot. I should have committed and pushed each one, or at least verified the auto-commit daemon would handle them.

### 3. Did NOT Fix Any Upstream Code
I wrote 7 feedback files describing bugs with exact fixes (including code snippets), but did NOT apply ANY of the fixes. The feedback files are detailed enough to be actionable, but writing a `.md` file is not the same as fixing the bug. For bugs that are a 1-line fix (mr-sync `...`, crush-daily `file:` prefix), I should have just fixed them.

### 4. Did NOT Verify DiscordSync Service Health After chattr Fix
The post-deploy smoke test SKIPped DiscordSync (expected during startup backfill). I declared success without verifying that the service actually stays running after the backfill completes. In reality, it crash-loops on the Turso sync error. I should have set up a deferred check or monitored the journal for 10+ minutes.

### 5. Did NOT Investigate the Generation Mismatch
Deployed generation (`ki7kj...`) differs from evaluated generation (`x8fb3...`). I noted it as "cosmetic — doc commit after deploy" but did NOT verify this claim. If the mismatch is from something other than the doc commit, the deployed config may not include all fixes.

---

## e) WHAT WE SHOULD IMPROVE

1. **Fix bugs instead of writing feedback files.** For 1-line fixes (mr-sync `...`, crush-daily `file:` prefix, PMA `Type=exec`), just fix the code, commit, and push. Feedback files are for complex architectural issues that need discussion — not trivial fixes.
2. **Verify code state BEFORE planning.** Don't rely on AGENTS.md gotcha history to determine what's still broken. Read the current source first, then plan.
3. **Push or verify auto-commit for all repos.** Feedback files on local disk that aren't pushed are invisible to anyone who doesn't have local access.
4. **Set up deferred health checks for slow-starting services.** DiscordSync's 5-11 minute startup backfill means the post-deploy smoke test always SKIPs it. A `systemd-run --on-active=10min` deferred check would catch the Turso crash-loop.
5. **Monitor dnsblockd memory for 24h.** The GOMEMLIMIT+2G mitigation is a guess. Without empirical data, we don't know if it actually stops the OOM pattern.

---

## f) Up to 50 Things We Should Get Done Next

### Critical (P0)
1. **Fix DiscordSync Turso sync failure** — service is crash-looping. Needs root access to diagnose.
2. **Apply the mr-sync `...` fix** — 1-line fix, commit, push, unpin in SystemNix.
3. **Apply the crush-daily test DSN `file:` fix** — mechanical fix, 8 lines.
4. **Apply the PMA `Type=exec` fix** — 2-line fix in `nix/module.nix`.
5. **Apply the DiscordSync chattr fix upstream** — replace broken ExecStartPre with `writeShellApplication`.
6. **Monitor dnsblockd memory for 24h** — verify GOMEMLIMIT+2G stops OOM pattern.

### High Priority (P1)
7. **Apply the dnsblockd OTEL label fix** — drop or bucket `dns_domain`, `http_path`, `proxy_domain` in `telemetry.go`.
8. **Fix the dnsblockd DNS observer dispatch** — add semaphore + async dispatch (pattern from HTTP middleware).
9. **Push 3 unpushed SystemNix commits** (`9bf6fc47`, `fa43db84`, `095e763a`).
10. **Push/commit feedback files in all 7 repos** (or verify auto-commit handles them).
11. **Investigate monitor365-server DuckDB pool timeout** — `pool acquire failed`.
12. **Add DNS check to pre-deploy-check.sh** — `getent hosts dash.home.lan`.
13. **Re-deploy to sync generation** — deployed ≠ evaluated.

### Medium Priority (P2)
14. **Fix crush-daily typo directory** — `docs/feeback/` → remove or rename.
15. **Apply the file-and-image-renamer `initServiceOrFail` fix** — add for required deps.
16. **Apply the monitor365 configurable event limit** — add config option for `max_events_per_day`.
17. **Add GOMEMLIMIT to all Go services** in SystemNix (not just dnsblockd).
18. **Add dnsblockd memory Gatus alert** — alert when cgroup `memory.current` > 80% of MemoryMax.
19. **Add ExecStartPre shell-syntax linter** to pre-commit hooks in all repos.
20. **Write standalone BTRFS DB recovery script** (`scripts/recover-db.sh`).
21. **Clean 13 stale build sandboxes** in `/nix/var/nix/builds/`.
22. **Add deferred post-deploy recheck** for services with startup delays.
23. **Consider making dnsblockd sdns CacheSize configurable** — currently hardcoded at 256K.
24. **Add `PRAGMA mmap_size` to dnsblockd tracking DB DSN** — reduce GC pressure.
25. **Test DNS failover** — stop dnsblockd on evo-x2, verify rpi3-dns picks up via VRRP.

### Lower Priority (P3)
26. **Audit all upstream NixOS modules** for ExecStartPre shell-syntax bugs.
27. **Add cardinality regression test** to dnsblockd — scrape `/metrics`, assert bounded label count.
28. **Consider dnsblockd `tracking_mode = "MINIMAL"`** — only track blocks, not resolves.
29. **Batch dnsblockd tracking writes** — accumulate in ring buffer, flush periodically.
30. **Add monitor365 admin API endpoint** for adjusting tenant limits.
31. **Consider backlog-aware burst mode** in monitor365 — temporarily raise limit to drain.
32. **Document GOMEMLIMIT pattern** in AGENTS.md as Go service best practice.
33. **Add DNS resolution latency tracking** — Gatus check for DNS response time trends.
34. **Review all `ref=master` flake inputs** — pin to tags/commits for stability.
35. **Add `systemd-analyze security dnsblockd` output** to docs.
36. **Consider Go pprof endpoint** on dnsblockd for heap analysis.
37. **Add DNS blocklist update monitoring** — alert when blocklist entries drop.
38. **Consider shorter dnsblockd retention** — 7/30 instead of 30/90.
39. **Audit all services for `ProtectHome` + MemoryMax interaction.**
40. **Consider `dns_exit_on_failure = false`** — keep block-page HTTP alive when resolver fails.
41. **Add systemd `RestrictNetworkInterfaces`** to dnsblockd.
42. **Document the full DNS resolution chain** in SystemNix docs.
43. **Add Prometheus alert for Turso sync failures** — DiscordSync crash-loops silently.
44. **Consider SQLite `PRAGMA mmap_size` tuning** for all SQLite-based services.
45. **Review dnsblockd rate limiter config** for homelab traffic patterns.
46. **Add BTRFS filesystem health** to post-deploy check.
47. **Consider a Go pprof dump on next dnsblockd OOM** — set `GOTRACEBACK=crash`.
48. **Document hourly-OOM pattern** in dnsblockd's upstream AGENTS.md.
49. **Add network dependency graph** — which services depend on dnsblockd and fail order.
50. **Create dnsblockd integration test** — VM test for DNS resolution + memory stability.

---

## g) Questions for User

### Q1: Should I Fix the Trivial Bugs Directly Instead of Leaving Feedback Files?
The mr-sync `...` fix (1 line), the crush-daily test DSN `file:` prefix (8 lines), and the PMA `Type=exec` (2 lines) are trivial mechanical fixes. Should I:
- **A) Go fix them now** — commit and push in each repo, then bump flake inputs in SystemNix.
- **B) Leave the feedback files** — you'll review and decide when to apply them.
- **C) Fix some but not others** — which ones?

### Q2: DiscordSync Turso Sync — How to Handle?
DiscordSync is crash-looping on Turso `unexpected EOF` after the dbHeal cascade created a fresh DB. This needs root access to diagnose. Should I:
- **A) Wait for you to investigate** — you have sudo access.
- **B) Disable Turso sync in the config** — run local-only until sorted.
- **C) Write a Turso re-initialization ExecStartPre** — delete local sync state so Turso re-syncs from scratch.

### Q3: dnsblockd OTEL Fix — Fix Now or Monitor First?
The GOMEMLIMIT+2G mitigation is deployed but the real fix is dropping high-cardinality OTEL labels in dnsblockd's Go code. Should I:
- **A) Fix it now** — go to dnsblockd repo, drop the labels, test, bump flake input.
- **B) Monitor 24h first** — see if the mitigation holds, then decide.
- **C) Just raise MemoryMax to 4G** — throw RAM at it (you have 93G), defer the code fix.

---

*Status generated 2026-08-04 05:09. System: evo-x2, NixOS 26.11 unstable, kernel 7.1.5, 93 GB RAM. dnsblockd 0 OOM-kills since deploy (~3h ago). DiscordSync crash-looping on Turso EOF. 7 feedback files written across 7 repos.*
