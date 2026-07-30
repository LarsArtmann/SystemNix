# Monitor365 DuckDB Version Column + VendorHash Cascade

**Date:** 2026-07-24  
**Status:** ~~IN PROGRESS — monitor365-server crash-looping, build broken by vendorHash cascade~~ **RESOLVED** — see update below.

> **Update 2026-07-24:** Build and runtime both fixed. Upstream `0615301` added the `version` column migration; SystemNix pins monitor365 to `06153013945baa16d83a81bd7497433537235240`. `monitor365-schema-migrate.service` runs the migration before server start. All vendorHash cascades resolved (overview, crush-daily, discordsync). Server is healthy and deployed — `/health` returns `{"status":"ok","database":"connected"}`, agent running (PID alive). Full resolution documented in `2026-07-24_14-44_session-retrospective`.

---

## What Happened

### The Original Task
Fix two Nix build failures blocking `nixos-rebuild`:
1. monitor365-deps: 699 Rust compilation errors from empty `spa_sys` bindgen output
2. cqrs-lint: Go type mismatch (`string` vs `auditlog.ServiceName`)

Both were fixed and the system built successfully. The deploy activated but monitor365-server crash-looped at runtime.

### The Runtime Failure
monitor365-server crashes with:
```
Binder Error: Table "tenants" does not have a column named "version"
```

**Root cause:** Commit 0615301's `schema.sql` includes `version INTEGER NOT NULL DEFAULT 0` in `CREATE TABLE IF NOT EXISTS tenants`, but the existing DuckDB database was created by an older version without this column. `CREATE TABLE IF NOT EXISTS` is a no-op for existing tables, and no `ALTER TABLE` migration exists in the 61 migration files.

### What Went Wrong During The Fix Attempt

1. **First attempt — ExecStartPre with duckdb CLI inside hardened service:** The `SystemCallFilter=@system-service` blocks DuckDB's C++ thread creation (clone3 syscall). The `2>/dev/null || true` swallowed the error completely. The migration silently did nothing.

2. **Second attempt — Separate `monitor365-schema-migrate` service:** Correct approach (runs outside the hardened sandbox), but the SQL was wrong: `ALTER TABLE tenants ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 0;`. DuckDB doesn't support constraints in `ALTER TABLE ADD COLUMN` — error: `Adding columns with constraints not yet supported`.

3. **Third attempt — Fixed SQL but service didn't re-run:** `RemainAfterExit=true` makes the oneshot service a no-op on re-deploy. Added `restartTriggers` but deploy failed before reaching activation.

4. **Cascade of vendorHash mismatches:** Each `nix flake lock --update-input` cascaded ALL transitive inputs. This broke 6+ Go packages with stale vendorHashes: branching-flow, crush-daily, discordsync, dnsblockd, overview, mr-sync. Each required manual hash override.

5. **Concurrent agent sessions:** 46 commits appeared during this session from other agent processes modifying flake.lock, lars-packages.nix, and overlays/linux.nix. Files changed between bash calls, making edits unreliable.

### Current State (as of 2026-07-24 03:14)

**Code changes (all committed by concurrent sessions):**
- `flake.nix`: monitor365 pinned to 0615301, samber-do-auditlog follows
- `lib/lars-packages.nix`: overrideVendorHash helper + branching-flow hash override
- `overlays/linux.nix`: crush-daily, discordsync, dnsblockd vendorHash overrides
- `modules/nixos/services/monitor365.nix`: schema-migrate service with correct SQL
- `flake.lock`: updated by concurrent sessions

**Build status:** BROKEN — 3 remaining hash mismatches (overview, crush-daily, discordsync) because flake.lock changed since the overrides were written

**Runtime status:** monitor365-server crash-looping (restart counter 48+). The schema-migrate service ran once with wrong SQL and hasn't re-run.

---

## What I Forgot / Did Wrong

1. **Didn't verify the migration actually worked** — used `2>/dev/null || true` which hid the failure. Should have logged the output and checked journalctl immediately.

2. **Chased vendorHashes one at a time** instead of using `--keep-going` to collect ALL mismatches first. Wasted 10+ build cycles.

3. **Used `nix flake lock --update-input monitor365`** which cascaded ALL transitive inputs instead of manually editing just the monitor365 node in flake.lock.

4. **Didn't account for concurrent sessions** — another agent was modifying the same files. Should have checked `git log` before each edit and used `--no-update-lock-file` consistently.

5. **Forgot the DuckDB ALTER TABLE limitation** — DuckDB doesn't support `NOT NULL` or `DEFAULT` constraints in `ALTER TABLE ADD COLUMN`. The `COALESCE(version, 0)` in the Rust code already handles NULLs, so a bare `INTEGER` column is sufficient.

6. **Didn't commit after each small change** — accumulated too many uncommitted changes, making it impossible to track what worked.

---

## Remaining Work

1. Fix 3 vendorHash overrides (overview, crush-daily, discordsync) with current `got:` hashes
2. Build and deploy in a SINGLE atomic operation
3. Verify schema-migrate runs with correct SQL
4. Verify monitor365-server starts and /health responds
5. Run post-deploy smoke test
6. Push

---

## Lessons Learned

- **Never use `2>/dev/null || true` on critical migrations** — it hides failures completely
- **Use `--keep-going` to collect ALL build errors** before fixing any of them
- **Manually edit flake.lock for surgical changes** — never `nix flake lock --update-input` which cascades
- **Use `--no-update-lock-file`** when building to prevent nix from modifying the lock
- **DuckDB ALTER TABLE doesn't support constraints** — use bare column type, rely on COALESCE in queries
- **Check for concurrent modifications** before editing files in a shared repo
