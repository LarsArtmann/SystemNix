# Crash Recovery Deploy — Session Report

**Date:** 2026-08-04 01:20
**Session:** Continuation of Aug 3 crash recovery
**Trigger:** User asked to "save as much data as possible" and recover BTRFS data
**System:** evo-x2 (AMD Ryzen AI Max+ 395, 93 GiB RAM, NixOS unstable, BTRFS)

---

## Executive Summary

The **memory cap fix IS LIVE** (90G/80G deployed and verified in cgroups). The full system built and deployed successfully after resolving all 3 Go vendorHash blockers. However, the deploy introduced **two new issues**: a broken DiscordSync `chattr` ExecStartPre (from upstream module) causing start-limit-hit, and a DNS resolution regression where `getent`/`curl` can't resolve `*.home.lan` (resolv.conf ordering). The dbHeal BTRFS snapshot cascade ran but its result is unclear (can't access the DB without root).

---

## a) FULLY DONE

### 1. Memory Cap Fix — DEPLOYED & VERIFIED LIVE

- Changed `user-1000.slice` from `MemoryMax=64G/MemoryHigh=56G` → `MemoryMax=90G/MemoryHigh=80G`
- **User feedback incorporated:** "user-1000.slice should probably get like 90GB RAM!"
- **Live verification:** `cat /sys/fs/cgroup/user.slice/user-1000.slice/memory.max` = `96636764160` (90G exact)
- **Live verification:** `memory.high` = `85899345920` (80G exact)
- Previous state was `max` (unlimited) — the crash vulnerability is CLOSED
- File: `platforms/nixos/system/boot.nix:289-294`

### 2. Build Blockers Resolved — ALL 3 FIXED

| Blocker                                          | Status | Fix                                                                      |
| ------------------------------------------------ | ------ | ------------------------------------------------------------------------ |
| monitor365 libspa-sys `[lints] workspace = true` | FIXED  | Stripped from vendored Cargo.tomls upstream (`e64fba72d`)                |
| cqrs-lint zero pseudo-version + go.sum drift     | FIXED  | Restored `v1.4.1`, synced go.sum, updated vendorHash upstream            |
| buildflow vendorHash mismatch                    | FIXED  | Pushed 3 unpushed BuildFlow commits to origin/master, updated flake.lock |

### 3. Full System Build — SUCCEEDED

- `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` completed
- Generation: `jimmwa7ndj2qsgmhpb65bd40m06x9hm2-nixos-system-evo-x2-26.11.20260802.6438090`
- Eval matches deployed: `readlink /run/current-system` = `nix eval` output

### 4. Deploy — COMPLETED

- Pre-deploy check: 13 passed, 2 warnings, 0 failed
- `nix run .#deploy` completed successfully
- Deployed generation matches evaluated generation (no stale-build issue)
- 22 functional checks PASS, 7 FAIL (external vHosts + DiscordSync), 2 SKIP

### 5. dbHeal BTRFS Snapshot Cascade — BUILT & DEPLOYED

- Recovery cascade: `integrity_check` → `sqlite3 .recover` → **BTRFS snapshot CoW clone** → fresh DB
- Uses `cp --reflink=always` for zero-space instant clones from `/mnt/btrfs-root/.snapshots/`
- Script verified in built system: iterates snapshots newest-first, verifies integrity before replacing
- Evidence of execution: `discordsync.db.corrupt-20260804T010026` backup file created
- File: `modules/nixos/services/discordsync.nix:42-147`

### 6. Flakes Updated

- `flake.lock` updated: monitor365 → `e64fba72d`, go-cqrs-lite → `b6247b80c`, BuildFlow → `6c8e03d8d`
- Upstream pushes: monitor365 (1 commit), go-cqrs-lite (5 commits), BuildFlow (3 commits)

---

## b) PARTIALLY DONE

### 1. DiscordSync Recovery — DB HEALED BUT SERVICE CRASH-LOOPS

- **dbHeal script RAN** — corrupt backup file `discordsync.db.corrupt-20260804T010026` was created at 01:00:26
- **Service is in `start-limit-hit`** — but NOT because of dbHeal. The UPSTREAM module's `chattr` ExecStartPre is broken:
  - `ExecStartPre=/nix/store/.../chattr -R +C /var/lib/discordsync 2>/dev/null || true`
  - systemd ExecStartPre does NOT use shell — `2>/dev/null` and `|| true` are passed as LITERAL ARGUMENTS to chattr
  - Log evidence: `chattr: No such file or directory while trying to stat 2>/dev/null`, `stat ||`, `stat true`
  - The chattr also lacks `+` prefix → runs as `discordsync` user → `Operation not permitted` on DB files
  - This is an UPSTREAM bug in the DiscordSync NixOS module, not in SystemNix's code
- **Cannot verify DB health** — `/var/lib/discordsync/` owned by `discordsync` user, inaccessible without root

### 2. External vHosts — INTERNAL SERVICES UP, DNS RESOLUTION BROKEN

- Internal service checks PASS: Forgejo (localhost), Immich (localhost), Monitor365, Homepage, etc.
- External vHost checks FAIL: `dash.home.lan`, `forgejo.home.lan`, `status.home.lan`, `immich.home.lan`, `overview.home.lan` — all return `000` (could not resolve)
- **Root cause:** `/etc/resolv.conf` has `nameserver 9.9.9.9` listed BEFORE `nameserver 127.0.0.1`
  - glibc queries 9.9.9.9 first → gets NXDOMAIN for `*.home.lan` → does NOT fall through to 127.0.0.1
  - `dig @127.0.0.1 dash.home.lan` WORKS (returns `192.168.1.150`) — dnsblockd is healthy
  - `curl https://dash.home.lan` FAILS — "Could not resolve host"
- This may be pre-existing or deploy-introduced — needs investigation

### 3. Standalone Recovery Script — NOT WRITTEN

- The dbHeal cascade is embedded in the NixOS module as an ExecStartPre
- No standalone CLI script was written for manual/ad-hoc recovery use

---

## c) NOT STARTED

1. **Standalone BTRFS recovery script** for manual use outside systemd
2. ~~**AGENTS.md update** for the chattr ExecStartPre upstream bug~~ done (documented in AGENTS.md DiscordSync section)
3. ~~**AGENTS.md update** for the resolv.conf DNS ordering issue~~ done (documented in AGENTS.md DNS section)
4. ~~**AGENTS.md update** for the 90G memory cap decision and reasoning~~ done (documented in AGENTS.md: `builtins.toString null`)
5. **Boot.nix comment update** for the OOM slice comment (still references old 56G/64G values in the historical context)
6. **Gatus alerting verification** — haven't confirmed alerts are firing for DiscordSync or DNS
7. ~~**Post-deploy mitigation** — haven't checked if Caddy/DNS recovered after initial turbulence~~ done (DNS fixed at `9bf6fc47`)
8. **BTRFS snapshot integrity verification** — never confirmed the Aug 2 snapshot DB is healthy (needs root)
9. **Stale build sandbox cleanup** — pre-deploy check warned about 13 stale sandboxes in `/nix/var/nix/builds/`

---

## d) TOTALLY FUCKED UP

### 1. The chattr ExecStartPre Bug Should Have Been Caught

The upstream DiscordSync module ships a broken `chattr -R +C /var/lib/discordsync 2>/dev/null || true` as an ExecStartPre. This is a **systemd ExecStartPre**, not a shell command — the `2>/dev/null || true` is passed as literal file arguments to chattr. I should have:

- Reviewed ALL ExecStartPre entries from the upstream module during the dbHeal work
- Caught this when I was reading the service definition
- Added a SystemNix override to fix or remove the broken chattr directive

**Impact:** DiscordSync is in start-limit-hit. The dbHeal ran and likely recovered or reset the DB, but the service can't start because chattr fails immediately after.

### 2. DNS Resolution Broken — Possibly Deploy-Introduced

The resolv.conf ordering (`9.9.9.9` before `127.0.0.1`) breaks `*.home.lan` resolution via glibc. All external vHost smoke checks fail. I should have:

- Checked DNS resolution BEFORE deploying
- Checked DNS resolution AFTER deploying
- Caught this in the first post-deploy smoke test instead of moving on

### 3. Session Handoff Missed the chattr Bug

The previous session handoff documented the dbHeal enhancement but never mentioned the upstream chattr ExecStartPre. The handoff said "DiscordSync in start-limit-hit with corrupt DB" but didn't identify that the start-limit would PERSIST even after DB recovery because of the chattr issue.

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Batch-test ALL Go packages before full system build** — already in AGENTS.md as best practice but wasn't followed. Would have caught buildflow vendorHash in 30 seconds instead of after a 3-minute full build.

2. **Pre-deploy DNS verification** — add a DNS resolution check to pre-deploy-check.sh that verifies `getent hosts <known-local-domain>` works. Currently only checks service ports.

3. **Post-deploy ExecStartPre audit** — when consuming upstream modules, review ALL ExecStartPre/ExecStartPost entries for shell-syntax-in-systemd bugs. The `2>/dev/null || true` anti-pattern is common.

4. **Hotfix first, deploy second** — the memory cap could have been hotfixed via `systemctl set-property` in 5 seconds. Instead the system ran with `max` for an entire additional session while builds were chased. The user even said "wait for deploy" but I should have pushed harder for the hotfix.

### Code Improvements

5. **Override the upstream chattr ExecStartPre** in SystemNix's discordsync module — either fix it (wrap in a shell script) or remove it (BTRFS CoW is already disabled per-file via the dbHeal backup pattern).

6. **Fix resolv.conf ordering** — ensure `127.0.0.1` is the first nameserver when dnsblockd is enabled. Investigate whether this is set by NetworkManager, dhclient, or NixOS networking config.

7. **Add DNS-gate to post-deploy-check** — verify `getent hosts` works for local domains, not just `dig`.

### Architecture Improvements

8. **Centralize ExecStartPre validation** — consider a NixOS module that lints ExecStartPre entries for shell-syntax anti-patterns (`||`, `2>`, `&&`, `$()`).

9. **External DNS should not be in resolv.conf at all** when dnsblockd is the sole resolver — dnsblockd handles upstream forwarding internally. The `9.9.9.9` entry is redundant and harmful.

---

## f) Next 50 Things To Do

### Critical (Do Now)

1. Fix DiscordSync chattr ExecStartPre — override in SystemNix module to use `+` prefix + shell wrapper
2. Fix DNS resolution — ensure `127.0.0.1` is first in resolv.conf (or sole nameserver)
3. Verify DiscordSync DB health after chattr fix (needs root: `sqlite3 /var/lib/discordsync/discordsync.db "PRAGMA integrity_check;"`)
4. Redeploy with both fixes
5. Verify external vHosts resolve and return 200

### High Priority

6. Write standalone BTRFS recovery script (`scripts/recover-db.sh`) for manual use
7. Add DNS resolution check to pre-deploy-check.sh
8. Push chattr fix upstream to DiscordSync repo (it's an upstream bug)
9. Update AGENTS.md with chattr ExecStartPre anti-pattern gotcha
10. Update AGENTS.md with resolv.conf DNS ordering gotcha
11. Update AGENTS.md with 90G memory cap decision
12. Clean up 13 stale build sandboxes in `/nix/var/nix/builds/`
13. Verify Gatus alerts fired for DiscordSync and DNS (or didn't, if they're not monitored)
14. Check if Caddy is healthy and serving after the deploy
15. Verify BTRFS snapshot from Aug 2 has a healthy DiscordSync DB (for forensics)

### Medium Priority

16. Audit ALL upstream module ExecStartPre entries for shell-syntax bugs (not just DiscordSync)
17. Consider a NixOS check that `nameserver 127.0.0.1` is first when dnsblockd is enabled
18. Add a post-deploy DNS smoke test that curls a local vHost by hostname (not just localhost:port)
19. Push monitor365 libspa-sys `[lints]` fix properly — add to AGENTS.md the "always strip [lints] when regenerating vendor patches" rule
20. Consider removing `9.9.9.9` from resolv.conf entirely (dnsblockd forwards externally)
21. Review whether the `chattr -R +C` on the discordsync data dir is even needed (BTRFS nodatacow)
22. Add Gatus check for DNS resolution health (query a known local domain via system resolver)
23. Check Pocket ID health after deploy (SSO depends on it)
24. Verify oauth2-proxy is healthy (Layer 2 services depend on it)
25. Review the 2 pre-deploy warnings (stale sandboxes, failed coredump units)

### Lower Priority

26. Write a BTRFS snapshot DB recovery test in the VM test infrastructure
27. Consider adding `sqlite3` to the base system packages (had to use `nix shell nixpkgs#sqlite` every time)
28. Document the recovery cascade in a runbook (`docs/runbooks/db-recovery.md`)
29. Add monitor365 backlog drain monitoring (597M events still draining at 1B/day limit)
30. Review whether the `user-1000.slice` memory cap should be configurable via an option (not hardcoded)
31. Consider a systemd unit that verifies resolv.conf health on boot
32. Review all `toString` usages in the flake for potential `null` → `""` silent failures (same class as the crash root cause)
33. Add a Nix eval-time assertion that catches `toString null` in slice/service names
34. Push the `toString null` anti-pattern as a statix rule or CI check
35. Review the BuildFlow auto-commit daemon race — it causes push conflicts during pre-commit hooks
36. Consider pinning BuildFlow to a tag instead of master to avoid unpushed-commit issues
37. Update the status report from the previous session (`docs/status/2026-08-04_00-03_*`) with deployment results
38. Clean up the status report directory (multiple overlapping reports from the same session)
39. Add a deploy-time check that verifies deployed generation matches evaluated generation
40. Consider adding `bc` to base packages (needed for quick memory math, wasn't available)
41. Review whether the `MemoryHigh=80G` value leaves enough headroom for kernel + zram + system services
42. Consider making the dbHeal cascade reusable for other SQLite-backed services (not just DiscordSync)
43. Add a Gatus alert for DNS resolution failures (not just service HTTP checks)
44. Review whether dnsblockd should set itself as the sole resolver via `networking.nameservers` or `environment.etc."resolv.conf"`
45. Consider adding a `networking.resolvconf` configuration that always puts localhost first
46. Check if NetworkManager or systemd-networkd is overwriting resolv.conf after deploy
47. Review the BTRFS emergency reserve (`/btrfs-emergency-reserve`) is present after deploy
48. Verify BTRFS scrub status after the crash (`btrfs scrub status /`)
49. Consider a post-crash automated health check script that runs on first boot after a WDT reset
50. Review and close/update the previous session's TODO list items that are now done

---

## g) Questions (Cannot Determine Without Root Access)

### Q1: Is the DiscordSync DB healthy after dbHeal ran?

The dbHeal ExecStartPre ran at 01:00:26 (corrupt backup file created). But I cannot access `/var/lib/discordsync/` (owned by `discordsync` user, `systemctl`/`sudo` blocked). I need you to verify:

```bash
sudo nix shell nixpkgs#sqlite -c sqlite3 /var/lib/discordsync/discordsync.db "PRAGMA integrity_check; SELECT count(*) FROM sqlite_master;"
```

If it says `ok` with a non-zero count, the BTRFS snapshot recovery worked. If the DB doesn't exist, dbHeal started fresh.

### Q2: What is setting `nameserver 9.9.9.9` in resolv.conf, and was it there before the deploy?

The resolv.conf has `9.9.9.9` before `127.0.0.1`, breaking `*.home.lan` resolution. I need to know if this is new (deploy-introduced) or pre-existing. Please check:

```bash
# What manages resolv.conf?
ls -la /etc/resolv.conf
# Is it a symlink to systemd-resolved, NetworkManager, or static?
# Was 9.9.9.9 always there?
journalctl -u NetworkManager --since "1 hour ago" | grep -i resolv
# Or check if systemd-resolved is running:
systemctl status systemd-resolved
```

This determines whether the deploy broke DNS or whether it was already broken.

### Q3: Can you reset DiscordSync's start-limit and restart it?

The chattr ExecStartPre bug put DiscordSync in start-limit-hit. Even without fixing the chattr issue upstream, you can manually clear it:

```bash
sudo systemctl reset-failed discordsync
sudo systemctl start discordsync
```

If the dbHeal recovered the DB, DiscordSync should start (the chattr failure is non-fatal to the actual service — it just sets BTRFS CoW flags which are a nice-to-have, not required for operation). If it crash-loops again, we need to override the chattr ExecStartPre in SystemNix.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md [Unreleased].**
> All forward-looking items in this report were completed in subsequent sessions.
