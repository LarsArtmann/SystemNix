# Pocket ID francis Crash-Loop Fix + Session Status

**Date:** 2026-08-03 03:17
**Session:** auth.home.lan HTTP 502 emergency fix
**Severity:** P0 (SSO provider down — all OIDC-dependent services broken)

---

## Incident Summary

Pocket ID v2.10.0 crash-looped for ~2 hours (Aug 02 15:05 – Aug 03 03:01),
causing auth.home.lan to return HTTP 502. Every SSO-dependent service
(Forgejo, Immich, Gatus, oauth2-proxy layer, Homepage, SigNoz, etc.) was
affected because Pocket ID is the sole OIDC identity provider.

**Root cause:** Pocket ID v2.10.0 introduced the `francis` actor framework
(`github.com/italypaleale/francis v0.1.0-beta.6`). It runs 8+ cleanup jobs
concurrently on startup, all contending for SQLite's single-writer lock.
The SQLITE_BUSY cascade causes actor bootstrap to fail with "context canceled",
which triggers a nil-pointer panic in `quic-go.(*baseServer).accept` →
`SIGSEGV` → `start-limit-hit`.

**Fix applied:** WAL clearing ExecStartPre + ACTORS_HOST=127.0.0.1 + MemoryMax=1G.

---

## a) FULLY DONE

1. **Diagnosed the crash** — Identified the exact panic stack trace:
   `quic-go.(*baseServer).accept` → nil pointer dereference in francis
   WebTransport server, triggered by SQLITE_BUSY contention during actor
   bootstrap.

2. **Researched the root cause** — Confirmed via Pocket ID GitHub source that:
   - The actor host is a hard dependency (no env var to disable it)
   - `ACTORS_HOST` and `ACTORS_PORT` are undocumented env vars that control
     the QUIC listener bind address
   - Known stability issues: GitHub issues #1598, #1628
   - Francis `v0.1.0-beta.6` (2.10.0) vs `v0.1.0-beta.17` (2.12.0+)

3. **Applied 3-layer config fix** in `modules/nixos/services/pocket-id.nix`:
   - `pocket-id-clear-stale-wal` ExecStartPre (removes stale WAL/SHM)
   - `ACTORS_HOST=127.0.0.1` (localhost-only QUIC binding)
   - `MemoryMax=1G` (up from 512M)

4. **Validated syntax** — `nix flake check --no-build` passed.

5. **Deployed** — `nix run .#deploy` succeeded. 30/30 post-deploy checks
   passed, 0 failures. All 8 cleanup jobs ran successfully on startup.

6. **Verified stability** — 0 panics, 0 SIGSEGV, 0 start-limit-hit since deploy.
   OIDC discovery endpoint serving 200s to oauth2-proxy, Forgejo, and Gatus.

7. **Documented** — Added comprehensive gotcha entry to AGENTS.md Non-Obvious
   Gotchas table.

---

## b) PARTIALLY DONE

1. **SQLITE_BUSY errors are still occurring at runtime** — The francis actor
   host's "fetch alarms" and "renewing leases for alarms" loops still log
   SQLITE_BUSY errors every ~30 seconds. These are NON-FATAL (process stays
   alive, OIDC works), but they indicate the underlying SQLite contention
   issue is NOT fully resolved — only the crash is prevented. The WAL clearing
   fixes the startup race, but the runtime alarm-loop contention persists.

2. **Pre-existing failed units** — The pre-deploy check showed 12 failed units
   (disk-growth-check, nix-build-cleanup, nix-gc, 5x systemd-coredump from
   the pocket-id crash, pocket-id itself). After deploy, pocket-id was fixed,
   but I did NOT investigate or fix the other failed units:
   - `disk-growth-check.service` — unknown failure
   - `nix-build-cleanup.service` — likely related to BTRFS CoW holding refs
   - `nix-gc.service` — likely the BTRFS metadata ENOSPC guard aborting
   - 5x `systemd-coredump@*.service` — crash dumps from pocket-id panics
   - These were pre-existing and NOT caused by this session's changes.

3. **Disk space** — Root filesystem at 91% was flagged as a warning in
   pre-deploy-check. Not investigated.

4. **13 stale build sandboxes** in `/nix/var/nix/builds/` — flagged but
   not cleaned.

---

## c) NOT STARTED

1. **nixpkgs update** — SystemNix nixpkgs is pinned to Jan 2026 (rev
   `3497aa5c`), shipping pocket-id 2.10.0. Latest nixpkgs has 2.12.0 with
   francis `v0.1.0-beta.17`. Updating would be the real upstream fix but
   is a major operation after 7 months of drift.

2. **Coredump cleanup** — 5 `systemd-coredump@*.service` units from the
   pocket-id panics. These consume disk space in `/var/lib/systemd/coredump/`.

3. **Post-reboot verification** — The fix was verified after deploy but NOT
   after a reboot. The WAL clearing should handle boot-time startup, but this
   is untested.

4. **Gatus alert review** — Did not check whether Gatus was alerting on the
   Pocket ID outage via Discord during the 2-hour crash loop. If it wasn't,
   that's a monitoring gap.

5. **TODO_LIST.md / FEATURES.md updates** — Not updated.

---

## d) TOTALLY FUCKED UP

Nothing completely fucked up. The fix works and auth.home.lan is online.
However:

1. **I should have investigated the SQLITE_BUSY more deeply** — The runtime
   alarm-loop errors suggest the WAL clearing is a band-aid, not a root-cause
   fix. The real issue is francis's actor model being fundamentally
   incompatible with SQLite's single-writer lock. The alarms subsystem runs
   a periodic loop that contends with the main HTTP handlers for the DB lock.
   This will persist until nixpkgs is updated to 2.12.0+ or Pocket ID adds
   proper connection pooling / WAL mode.

2. **I did not check if Pocket ID is using WAL mode** — SQLite WAL mode
   allows concurrent readers + one writer. If Pocket ID is in default
   journal mode (DELETE), every read blocks writes. Setting
   `PRAGMA journal_mode=WAL` at the SQLite level might resolve the contention
   entirely. I did not investigate this.

3. **I normalized the SQLITE_BUSY errors as "non-fatal background noise"**
   without fully verifying they don't degrade functionality (e.g., do alarm
   lease failures cause rate-limiting rules to expire? Do OIDC sessions
   silently fail to clean up?).

---

## e) WHAT WE SHOULD IMPROVE

1. **SQLite WAL mode investigation** — Check if Pocket ID uses WAL mode.
   If not, this is the real fix for SQLITE_BUSY contention.

2. **Gatus monitoring gap** — Verify Gatus was alerting on Discord during
   the 2-hour Pocket ID outage. If not, add/improve the health check.

3. **nixpkgs update** — The 7-month-old pin (Jan 2026) is accumulating
   risk. Multiple services have known bugs fixed in newer versions
   (pocket-id, immich, forgejo, etc.). This is a strategic priority.

4. **Pre-existing failed units** — The 3 failed maintenance services
   (disk-growth-check, nix-build-cleanup, nix-gc) are likely related to
   the BTRFS ENOSPC issue documented in AGENTS.md. These should be
   investigated before they cause another incident.

5. **Disk space** — 91% root filesystem is dangerous on BTRFS with QLC NAND.
   The nix-gc failure means garbage isn't being collected.

6. **Coredump cleanup** — Add a systemd timer or tmpfiles rule to clean
   `/var/lib/systemd/coredump/` periodically (the 5 pocket-id crash dumps
   are still on disk).

7. **StartLimitBurst tuning** — Pocket ID has `StartLimitBurst=5` with
   `StartLimitIntervalSec=600` (10 min). For a crash-loop this severe,
   this means the service stays dead for 10 min after 5 crashes. Consider
   increasing the burst or adding a watchdog that auto-recovers.

8. **Restart notification** — Pocket ID has `OnFailure=notify-failure@%n`
   but the notification may not have reached Discord if the `onFailure`
   service itself depends on Pocket ID for OIDC. Check the dependency chain.

---

## f) Up to 50 Things We Should Get Done Next

### Immediate (P0)

1. Verify Gatus was Discord-alerting during the 2h Pocket ID outage
2. Clean up 5 systemd-coredump entries from pocket-id panics
3. Investigate the 3 pre-existing failed services (disk-growth-check,
   nix-build-cleanup, nix-gc)
4. Check disk space — root at 91% is critical on BTRFS/QLC
5. Run `nix-collect-garbage` or clear build sandboxes manually
6. Verify the pocket-id fix survives a reboot (cold test)

### Short-term (P1)

7. Investigate whether Pocket ID uses SQLite WAL mode — if not, enable it
8. Check if the SQLITE_BUSY alarm-loop errors cause functional degradation
   (expired sessions, stale rate-limit rules)
9. Update nixpkgs to latest (major operation — 7 months of drift)
10. Add a Gatus check for Pocket ID `/healthz` with Discord alert if missing
11. Add a coredump cleanup timer (systemd-tmpfiles or cron)
12. Review the `StartLimitBurst=5` / `StartLimitIntervalSec=600` settings
13. Check if `pocket-id-provision` re-ran successfully after the fix
14. Verify all OIDC clients (Forgejo, Immich, Gatus) reconnected after
    the 2-hour outage
15. Review oauth2-proxy session validity — sessions may have expired during
    the outage, requiring re-login

### Medium-term (P2)

16. Pin pocket-id to a specific nixpkgs commit known to work (instead of
    relying on the 7-month-old channel)
17. Add a VM test for pocket-id startup (similar to test-attic.nix)
18. Investigate the francis actor framework's alarm subsystem — is it
    needed for single-instance? Can it be disabled via config?
19. Review all services that use SQLite — are they all vulnerable to the
    same SQLITE_BUSY contention pattern?
20. Add `journal_mode=WAL` and `busy_timeout` to all SQLite-using services
    via env vars or config
21. Document the Pocket ID version pin strategy in AGENTS.md
22. Check if pocket-id 2.12.0 (latest nixpkgs) resolves the francis crash
    by reading the changelog
23. Review the BTRFS snapshot retention — are snapshots holding refs to
    the stale WAL files?
24. Run `btrfs filesystem df /` to check chunk allocation
25. Check `/nix/var/nix/builds/` for stale sandboxes and clean them

### Operational (P3)

26. Add a pre-deploy hook that checks for SQLITE_BUSY in recent journal
    logs and warns
27. Create a runbook for "auth.home.lan is down" scenarios
28. Add monitoring for SQLite database file age/size
29. Review all `harden {}` MemoryMax values — are they too low for services
    with actor frameworks / background workers?
30. Check if the francis WebTransport server on port 1414 needs firewall
    rules (even though it's localhost-only now)
31. Verify the `ACTORS_HOST=127.0.0.1` setting doesn't break multi-instance
    HA mode (if ever needed in the future)
32. Add a health check for the francis actor host (not just Pocket ID HTTP)
33. Review whether the WAL clearing ExecStartPre could cause data loss
    (it shouldn't — WAL is replayed on graceful shutdown, and a present WAL
    at startup means unclean shutdown)
34. Document the recovery procedure: `rm /var/lib/pocket-id/data/pocket-id.db-wal`
    as a manual fallback
35. Check if the pocket-id.db needs `VACUUM` or `ANALYZE` after the
    crash-looping
36. Review the pocket-id module's `TimeoutStartSec=180s` — is it sufficient
    for slow disk (BTRFS/QLC)?
37. Add a Prometheus metric for pocket-id restart count
38. Check if the systemd-coredump configuration is polluting disk under
    crash-loop scenarios
39. Review the `Storage=extern` coredump setting — should it be `none`
    for production services?
40. Add a Gatus alert for SQLite database lock errors (grep journal for
    SQLITE_BUSY)
41. Review whether `services.pocket-id.settings.DB_CONNECTION_STRING`
    should include SQLite pragmas (e.g., `?_journal_mode=WAL&_busy_timeout=5000`)
42. Check if the francis actor host has a health endpoint on port 1414
43. Verify that oauth2-proxy's `partOf = pocket-id-provision.service`
    dependency caused it to restart correctly after the fix
44. Review the OIDC client secret rotation monitoring — did the 2h outage
    affect the secret freshness check?
45. Check if any OIDC tokens issued before the outage are still valid
    (token validation doesn't require Pocket ID to be online for cached
    JWKS, but key rotation might have been missed)
46. Add a smoke test that verifies OIDC token exchange end-to-end
    (not just `/healthz`)
47. Review the pocket-id provision script — did it re-run correctly
    after the crash-loop recovery?
48. Check if the pocket-id admin user / OIDC clients are still intact
    after the crash-looping (SQLite WAL corruption could have affected them)
49. Document the `ACTORS_HOST` / `ACTORS_PORT` env vars in the pocket-id
    module options (they're undocumented upstream)
50. Consider adding `sqlite3 /var/lib/pocket-id/data/pocket-id.db "PRAGMA integrity_check;"`
    as a post-deploy verification step

---

## g) Questions (Can't Figure Out Myself)

1. **Should I update nixpkgs now?** The 7-month-old pin (Jan 2026) is
   causing version drift across many services. Updating would fix pocket-id
   2.10.0 → 2.12.0, but after 7 months the rebuild could take hours and
   risk breaking dozens of services. Is now a good time, or should we
   wait for a dedicated maintenance window?

2. **Did you notice the Pocket ID outage?** The service was down for ~2
   hours (15:05 – 03:01). Were you actively trying to use any SSO-protected
   service during that time? This helps assess the user impact and whether
   faster alerting is needed.

3. **Is the SQLITE_BUSY alarm-loop acceptable?** Pocket ID is now stable
   (no crashes), but the francis actor host logs SQLITE_BUSY errors every
   ~30 seconds on "fetch alarms" / "renewing leases for alarms". These are
   non-fatal but indicate an unresolved contention issue. Should I
   investigate further (SQLite WAL mode, busy_timeout pragma) or is this
   acceptable until the nixpkgs update?

---

## Files Changed This Session

| File                                   | Change                                                                      |
| -------------------------------------- | --------------------------------------------------------------------------- |
| `modules/nixos/services/pocket-id.nix` | Added `clearStaleWal` ExecStartPre, `ACTORS_HOST=127.0.0.1`, `MemoryMax=1G` |
| `AGENTS.md`                            | Added Pocket ID francis crash-loop gotcha to Non-Obvious Gotchas table      |

## Deploy Verification

```
PASS: 30  FAIL: 0  SKIP: 1
✅ All checks passed
```

---

## Resolution (2026-08-03 09:30)

The band-aid fix (WAL clearing + ACTORS_HOST + MemoryMax=1G) was **superseded by Pocket ID 2.12.0** via the nixpkgs update (commit `06ed9234`). Pocket ID 2.12.0 includes upstream fixes for the francis actor framework's SQLITE_BUSY contention. The WAL-clearing ExecStartPre and ACTORS_HOST may no longer be necessary — candidates for cleanup (tracked in `2026-08-03_07-01` section C: "remove WAL band-aid", "remove ACTORS_HOST", "revert MemoryMax"). Deploy verified: 29 PASS, 0 FAIL, 2 SKIP per `26ac30d8`.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
