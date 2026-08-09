# DiscordSync Crash-Loop Diagnosis and Fix

**Date:** 2026-07-28 21:21+02:00
**System:** evo-x2 (NixOS)
**Service:** `discordsync.service`

## Summary

DiscordSync is in a `start-limit-hit` crash loop. The immediate cause is a migration failure in `internal/db/backfill_nulls.go`: it backfills nullable foreign-key columns (`channels.guild_id`, `threads.owner_id`) to `''`, which violates SQLite `REFERENCES` constraints. A secondary issue is that the Gatus health check uses `/readyz` with `[STATUS] < 400`, which silently misses connection failures when the service is down.

I initially started implementing a local SystemNix patch, then realized per project convention that the real fix belongs in `/home/lars/projects/DiscordSync`. I paused to write this status report before proceeding.

## Resolution

Resolved on 2026-07-28. The crash-loop root cause was fixed upstream in `/home/lars/projects/DiscordSync` (`backfill_nulls.go` no longer backfills nullable FK columns with `''`), a regression test was added, and the fix was pushed to `github.com/LarsArtmann/DiscordSync` master. SystemNix consumed the upstream fix via `nix flake lock --update-input discordsync`, the temporary local patch and `patches/discordsync-backfill-nullable-fk.patch` were removed, and the configuration was deployed with `nix run .#deploy`. `discordsync.service` started successfully and `/healthz` returned 200 once the thumb-hash backfill completed. The Gatus `/healthz` change was kept.

The persistent Turso 403 (`SQL read operations are forbidden`) was addressed by switching the SystemNix module default backend from `turso-sync` to `sqlite`, eliminating the failing sync goroutine and DB lock contention. See the follow-up report `2026-07-28_23-20_discordsync-fix-deploy-progress.md` for deploy details.

## Fully Done

- Located DiscordSync module, service config, and related services in `/home/lars/projects/SystemNix`.
- Read `modules/nixos/services/discordsync.nix` and understood the SystemNix wrapper around upstream `inputs.discordsync.nixosModules.default`.
- Queried `journalctl -u discordsync.service` and identified the repeating crash pattern.
- Found that failures started around `2026-07-28 20:08:50` (after a deploy/restart) and the service is currently `start-limit-hit`.
- Identified two independent log errors:
  1. **Turso 403:** `initial turso pull failed ... status=403, body={"error":"Operation was blocked: SQL read operations are forbidden (reads are blocked, do you need to upgrade your plan?")` — service falls back to local mode.
  2. **Migration FK failure:** `failed to backfill NULL columns: ... backfill NULL text columns: turso: constraint failed: immediate foreign key constraint failed`.
- Located the current upstream source in the Nix store: `/nix/store/...-discordsync-prepared-source-62cb343`.
- Read the migration code in `internal/db/backfill_nulls.go`, `internal/db/migrate.go`, and the relational schema (`internal/db/schema_relational_base.go`, `internal/db/schema_relational_phase2.go`).
- Confirmed the root cause: `nullTextBackfills` contains:
  - `UPDATE channels SET guild_id = '' WHERE guild_id IS NULL` — `channels.guild_id` is nullable and references `guilds(id)`.
  - `UPDATE threads SET owner_id = '' WHERE owner_id IS NULL` — `threads.owner_id` is nullable and references `users(id)`.
  - `''` is not a valid parent key, so SQLite/Turso rejects the UPDATE with an immediate FK constraint failure.
- Checked Gatus configuration and logs. Gatus reports `success=true` for DiscordSync even while it is crash-looping because the check uses `/readyz` with `[STATUS] < 400`; connection failures produce a status of `0`, which passes the condition.
- Applied a SystemNix-only Gatus fix: switched the DiscordSync endpoint to `/healthz` with `[STATUS] == 200` so down state is detected.

## Completed (Was Partially Done)

- **SystemNix patch for migration bug reverted.** The temporary `overrideAttrs` patch overlay and `/home/lars/projects/SystemNix/patches/discordsync-backfill-nullable-fk.patch` were deleted; the fix lives upstream in DiscordSync instead.
- `nix flake check --no-build` passed with the upstream fix + Gatus change.

## Completed (Was Not Started)

- ✅ Fixed the upstream `backfill_nulls.go` in `/home/lars/projects/DiscordSync`.
- ✅ Added regression test `TestBackfillNullColumns_KeepsNullableFKNull` in `internal/db/null_scan_test.go`.
- ✅ Ran `GOWORK=off GOEXPERIMENT=jsonv2 go test ./internal/db/...` — PASS.
- ✅ Committed and pushed the upstream fix to `github.com/LarsArtmann/DiscordSync` master (`d785fdfa` + auto-daemon commits).
- ✅ Updated `flake.lock` in SystemNix (`nix flake lock --update-input discordsync`).
- ✅ Reverted the temporary SystemNix patch overlay and deleted `patches/discordsync-backfill-nullable-fk.patch`.
- ✅ Deployed with `nix run .#deploy`.
- ✅ Verified DiscordSync starts successfully and `/healthz` returns 200 after the thumb-hash backfill.
- ✅ Verified `/readyz` returns 200 once the bot is connected.
- ✅ Verified Gatus now correctly alerts when DiscordSync is down (uses `/healthz` + `[STATUS] == 200`).
- ✅ Confirmed `notify-failure@discordsync.service` delivers alerts to Discord (via `onFailure` in the SystemNix wrapper).
- ✅ Addressed the Turso 403 by switching the module default backend to `sqlite` (local-only), eliminating sync failures and lock contention. Revert to `turso-sync` if the Turso plan is upgraded.

## What I Got Wrong

- **Wrong layer for the fix.** I started writing a SystemNix patch for an upstream code bug. The project convention is to fix LarsArtmann Go repos at their source (`/home/lars/projects/DiscordSync`) and then bump the flake input. A downstream patch is a last resort, not a first choice.
- The temporary patch file had formatting issues and required several iterations; it should never have been created in the first place.
- I did not realize `/home/lars/projects/DiscordSync` was available locally until the user pointed it out.

## Completed Steps

1. ✅ Reverted the SystemNix patch overlay in `modules/nixos/services/discordsync.nix`.
2. ✅ Deleted `/home/lars/projects/SystemNix/patches/discordsync-backfill-nullable-fk.patch`.
3. ✅ In `/home/lars/projects/DiscordSync`:
   - Edited `internal/db/backfill_nulls.go` and removed:
     - `UPDATE channels SET guild_id = '' WHERE guild_id IS NULL`
     - `UPDATE threads SET owner_id = '' WHERE owner_id IS NULL`
   - Added regression test `TestBackfillNullColumns_KeepsNullableFKNull`.
   - Ran `GOWORK=off GOEXPERIMENT=jsonv2 go test ./internal/db/...` — PASS.
   - Committed and pushed to `github.com/LarsArtmann/DiscordSync` master.
4. ✅ Returned to `/home/lars/projects/SystemNix` and ran `nix flake lock --update-input discordsync`.
5. ✅ Ran `nix flake check --no-build`.
6. ✅ Ran `nix run .#deploy` (deploy succeeded; activation had the unrelated `crush-daily` sops user error, which was handled by the deploy script).
7. ✅ Verified with `journalctl -u discordsync.service` and `fetch http://127.0.0.1:8085/healthz`.
8. ✅ Kept the Gatus `/healthz` change; it correctly detects crash loops and startup delays are handled by the 60s interval.
9. ✅ Switched the module default backend to `sqlite` to stop the persistent Turso 403 sync failures.

## Open Questions → Resolved

1. **Gatus check trade-off.** ✅ Keeping `/healthz` with `[STATUS] == 200`. The 60s interval tolerates the thumb-hash backfill startup window; it correctly detected the crash-loop and connection failures, while `/readyz` with `< 400` missed them.
2. **Turso 403.** ✅ Switched the module default backend to `sqlite` (local-only). The 403 is a Turso plan/billing restriction (`SQL read operations are forbidden`). Revert to `turso-sync` if the Turso plan is upgraded and cloud replication is desired.
3. **Upstream commit flow.** ✅ Fix was pushed directly to `master` on `github.com/LarsArtmann/DiscordSync` (commit `d785fdfa` for the test plus the auto-daemon commits containing the functional fix).

---


## Item Resolution (2026-07-30)

No numbered action items in this report — all work was completed within the session or is tracked in TODO_LIST.md / CHANGELOG.md.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
