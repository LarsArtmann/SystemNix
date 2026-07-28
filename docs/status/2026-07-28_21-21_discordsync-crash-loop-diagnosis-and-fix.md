# DiscordSync Crash-Loop Diagnosis and Fix

**Date:** 2026-07-28 21:21+02:00
**System:** evo-x2 (NixOS)
**Service:** `discordsync.service`

## Summary

DiscordSync is in a `start-limit-hit` crash loop. The immediate cause is a migration failure in `internal/db/backfill_nulls.go`: it backfills nullable foreign-key columns (`channels.guild_id`, `threads.owner_id`) to `''`, which violates SQLite `REFERENCES` constraints. A secondary issue is that the Gatus health check uses `/readyz` with `[STATUS] < 400`, which silently misses connection failures when the service is down.

I initially started implementing a local SystemNix patch, then realized per project convention that the real fix belongs in `/home/lars/projects/DiscordSync`. I paused to write this status report before proceeding.

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

## Partially Done

- **SystemNix patch for migration bug:** I created `/home/lars/projects/SystemNix/patches/discordsync-backfill-nullable-fk.patch` and modified `modules/nixos/services/discordsync.nix` to apply it via `overrideAttrs`. After user feedback, I stopped this approach because the real fix belongs in `/home/lars/projects/DiscordSync`. The SystemNix changes and patch file still need to be reverted.
- `nix flake check --no-build` passed with the SystemNix patch + Gatus change applied.

## Not Started

- Fix the upstream `backfill_nulls.go` in `/home/lars/projects/DiscordSync`.
- Update or add upstream tests (e.g., `internal/db/null_scan_test.go`) to prevent regression.
- Run upstream Go tests.
- Commit and push the upstream fix.
- Update `flake.lock` in SystemNix (`nix flake lock --update-input discordsync`).
- Revert the temporary SystemNix patch overlay and delete `patches/discordsync-backfill-nullable-fk.patch`.
- Deploy with `nix run .#deploy`.
- Verify DiscordSync starts successfully and `/healthz` returns 200 after the thumb-hash backfill.
- Verify `/readyz` eventually returns 200 once the bot is connected.
- Verify Gatus now correctly alerts when DiscordSync is down.
- Confirm `notify-failure@discordsync.service` delivers alerts to Discord.
- Investigate the Turso 403 billing/plan issue separately.

## What I Got Wrong

- **Wrong layer for the fix.** I started writing a SystemNix patch for an upstream code bug. The project convention is to fix LarsArtmann Go repos at their source (`/home/lars/projects/DiscordSync`) and then bump the flake input. A downstream patch is a last resort, not a first choice.
- The temporary patch file had formatting issues and required several iterations; it should never have been created in the first place.
- I did not realize `/home/lars/projects/DiscordSync` was available locally until the user pointed it out.

## Recommended Next Steps

1. Revert the SystemNix patch overlay in `modules/nixos/services/discordsync.nix`.
2. Delete `/home/lars/projects/SystemNix/patches/discordsync-backfill-nullable-fk.patch`.
3. In `/home/lars/projects/DiscordSync`:
   - Edit `internal/db/backfill_nulls.go` and remove:
     - `UPDATE channels SET guild_id = '' WHERE guild_id IS NULL`
     - `UPDATE threads SET owner_id = '' WHERE owner_id IS NULL`
   - Update `internal/db/null_scan_test.go` if it asserts those backfills run.
   - Run `go test ./internal/db/...`.
   - Commit and push.
4. Return to `/home/lars/projects/SystemNix` and run `nix flake lock --update-input discordsync`.
5. Run `nix flake check --no-build`.
6. Run `nix run .#deploy`.
7. Verify with `journalctl -u discordsync.service -f` and `curl http://localhost:8085/healthz`.
8. Keep the Gatus `/healthz` change unless it proves too noisy during startup.

## Open Questions

1. **Gatus check trade-off.** I switched the DiscordSync Gatus check from `/readyz` (`[STATUS] < 400`) to `/healthz` (`[STATUS] == 200`) so crash loops are detected. This will cause alerts during the 5–11 min thumb-hash backfill startup window. Is that acceptable, or should we keep `/readyz` and add a `[CONNECTED] == true` TCP check instead?
2. **Turso 403.** The upstream service gets `403: SQL read operations are forbidden` from Turso on every start and falls back to local mode. Is this a known billing issue, and should we temporarily set `backend = "local"` or fix the Turso plan?
3. **Upstream commit flow.** Should I push the `backfill_nulls.go` fix directly to `master` on `github.com/LarsArtmann/DiscordSync`, or open a PR for review first?
