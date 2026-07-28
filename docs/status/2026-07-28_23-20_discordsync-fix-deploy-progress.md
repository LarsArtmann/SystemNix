# DiscordSync Fix — Deploy Progress

**Date:** 2026-07-28 23:20+02:00  
**System:** evo-x2 (NixOS)  
**Status:** Crash-loop root cause fixed; service is running and completing startup backfill.

## What Was Done

1. **Reverted the wrong-layer SystemNix patch.**
   - Removed the `overrideAttrs` patch overlay from `modules/nixos/services/discordsync.nix`.
   - Deleted `/home/lars/projects/SystemNix/patches/discordsync-backfill-nullable-fk.patch`.

2. **Fixed the bug upstream in `/home/lars/projects/DiscordSync`.**
   - Removed the two offending backfills from `internal/db/backfill_nulls.go`:
     - `UPDATE channels SET guild_id = '' WHERE guild_id IS NULL`
     - `UPDATE threads SET owner_id = '' WHERE owner_id IS NULL`
   - Added a comment explaining why nullable foreign-key columns must be skipped.
   - Added regression test `TestBackfillNullColumns_KeepsNullableFKNull` in `internal/db/null_scan_test.go`.
   - Ran `GOWORK=off GOEXPERIMENT=jsonv2 go test ./internal/db/...` — **PASS**.

3. **Pushed upstream fix.**
   - Commits landed on `github.com/LarsArtmann/DiscordSync` `master`:
     - `d785fdfa test(db): add NULL value scanning tests`
     - (plus the auto-daemon commits containing the functional fix)

4. **Updated SystemNix and deployed.**
   - `nix flake lock --update-input discordsync` → pulled new upstream `d785fdfa`.
   - `nix flake check --no-build` → **all checks passed**.
   - `nix run .#deploy` → completed; `discordsync.service` started.

## Current Service State

From `journalctl -u discordsync.service`:

- Migration now succeeds: `database migrated schema_version=2 meta_version=1 fts=false`.
- Projection workers started.
- Thumb-hash backfill is in progress (`attachments":3148`).
- Turso sync still fails with **403 "SQL read operations are forbidden"**, but the service falls back to local-only mode.
- **No more crash-loop.** Service has been running since `23:17:09`.

## Blockers for Full Verification

- The Bash tool now rejects `curl` as a security-sensitive command, so I cannot run `curl http://localhost:8085/healthz` directly to verify the endpoint.
- I need instructions on whether to:
  - Wait for the thumb-hash backfill to finish and use an alternative health-check method,
  - Switch DiscordSync to `backend = "local"` because of the persistent Turso 403,
  - Investigate the unrelated SearXNG smoke-check 404 and the `crush-daily` sops user error.

## Outstanding/Unrelated Issues Observed During Deploy

- **SearXNG smoke check failed** with `404` on `http://localhost:8888/healthz` — not caused by this work.
- **Activation script error:** `failed to lookup user 'crush-daily': user: unknown user crush-daily` — sops secret owner references a non-existent user; unrelated to DiscordSync.

## Next Steps (Pending Your Go-Ahead)

1. Verify `/healthz` returns 200 once the thumb-hash backfill completes.
2. Verify `/readyz` returns 200 once the bot is connected.
3. Confirm Gatus now alerts if DiscordSync goes down (using `/healthz` + `[STATUS] == 200`).
4. Decide whether to address the Turso 403 by switching to local backend or fixing the Turso plan.
5. Update `AGENTS.md` with the lesson: fix LarsArtmann Go repos upstream, not via SystemNix patches.
6. Update the first status report (`2026-07-28_21-21_discordsync-crash-loop-diagnosis-and-fix.md`) with completion notes.

Waiting for instructions before proceeding.
