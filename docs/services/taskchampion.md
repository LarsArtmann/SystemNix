# taskchampion (Taskwarrior sync server)

**Service:** `services.taskchampion-config` — `modules/nixos/services/taskchampion.nix` (thin wrapper over nixpkgs `services.taskchampion-sync-server`). Port 10222 (`lib/ports.nix`), loopback. URL: `tasks.<domain>` — a **hand-written** `protectedVHost` in `caddy.nix` (NO registry entry; the vHost + Gatus check are hand-wired there and in `gatus-config.nix`). DNS `tasks`.

Sync endpoint for Taskwarrior clients (`task sync` against the taskchampion protocol).

## What it serves

| Route    | Auth                       | What                                     |
| -------- | -------------------------- | ---------------------------------------- |
| sync API | forward-auth / open LAN    | Taskwarrior task sync (binary protocol)  |
| `:10222` | Gatus TCP probe (loopback) | "TaskChampion Sync" check (connect-only) |

## Ops

- **Snapshots** — `snapshot.versions = 100; snapshot.days = 14` (nixpkgs option): the server keeps sync history for point-in-time recovery; clients can roll back operations.
- **Unit limits** — deliberately tight StartLimit (3/60s): the sync server is small (`harden{}` + serviceDefaults, no custom MemoryMax — upstream defaults hold); rapid restarts indicate a data problem, not a flaky boot.
- **Auth model** — the server itself has no auth; taskwarrior client credentials are managed in-app (`task sync init`), and EXTERNAL access is gated by the protected vHost only. LAN is open.
- **Adding it to monitoring surfaces** — because there is no registry entry, any new tile/check/vHost change is a hand-edit in `caddy.nix` + `gatus-config.nix` (the registry-era pattern would fold it in via `services.integration.taskchampion` — optional cleanup, not required).

## Restore (verified 2026-11-17)

The state dir `/var/lib/taskchampion-sync-server/` (one 24 KB SQLite file, `taskchampion-sync-server.sqlite3`, tables `clients` + `versions`, WAL mode) rides the **root subvol backup fabric** — no dedicated dump leg, and none is warranted at this size class:

1. **Nightly btrbk `@` snapshot** (`platforms/nixos/system/snapshots.nix`, root instance, 23:00): local `/mnt/btrfs-root/.snapshots/@.*` (2d min / 3d preserve) + incremental send to `/mnt/pool/backups/root` with **forever retention** (`target_preserve_min = "all"`; 96 received snapshots live as of 2026-11-17). Restore = `btrfs send/receive` or snapshot-mount the wanted `@.<date>` and copy the state dir back.
2. **Crash-consistency** — the SQLite file is in WAL mode; a snapshot instant equals a power-cut instant, and SQLite replays the WAL on next open. Integrity probe (`PRAGMA integrity_check`) clean on the live file 2026-11-17.
3. **Client replicas** — every Taskwarrior client holds a full task-DB replica; the server is re-initializable from any client (`task sync init` → sync). This is the protocol-level safety net and covers clean-install/walked-away recovery even beyond snapshot history.
4. The in-app `snapshot.versions/days` option is sync-history retention, NOT a backup — do not confuse it with the restore path above.

## Related

- [oauth2-proxy.md](./oauth2-proxy.md) — the forward-auth layer gating external access
- Taskwarrior usage: `task sync` after configuring the server URL in `~/.taskrc` (`.taskrc` `sync.server.url=https://tasks.<domain>` + credentials from `task sync init`)
