# taskchampion (Taskwarrior sync server)

**Service:** `services.taskchampion-config` — `modules/nixos/services/taskchampion.nix` (thin wrapper over nixpkgs `services.taskchampion-sync-server`). Port 10222 (`lib/ports.nix`), loopback. URL: `tasks.<domain>` — a **hand-written** `protectedVHost` in `caddy.nix` (NO registry entry; the vHost + Gatus check are hand-wired there and in `gatus-config.nix`). DNS `tasks`.

Sync endpoint for Taskwarrior clients (`task sync` against the taskchampion protocol).

## What it serves

| Route    | Auth                        | What                                    |
| -------- | --------------------------- | --------------------------------------- |
| sync API | forward-auth / open LAN     | Taskwarrior task sync (binary protocol) |
| `:10222` | Gatus TCP probe (loopback)  | "TaskChampion Sync" check (connect-only)|

## Ops

- **Snapshots** — `snapshot.versions = 100; snapshot.days = 14` (nixpkgs option): the server keeps sync history for point-in-time recovery; clients can roll back operations.
- **Unit limits** — deliberately tight StartLimit (3/60s): the sync server is small (`harden{}` + serviceDefaults, no custom MemoryMax — upstream defaults hold); rapid restarts indicate a data problem, not a flaky boot.
- **Auth model** — the server itself has no auth; taskwarrior client credentials are managed in-app (`task sync init`), and EXTERNAL access is gated by the protected vHost only. LAN is open.
- **Adding it to monitoring surfaces** — because there is no registry entry, any new tile/check/vHost change is a hand-edit in `caddy.nix` + `gatus-config.nix` (the registry-era pattern would fold it in via `services.integration.taskchampion` — optional cleanup, not required).

## Related

- [oauth2-proxy.md](./oauth2-proxy.md) — the forward-auth layer gating external access
- Taskwarrior usage: `task sync` after configuring the server URL in `~/.taskrc` (`.taskrc` `sync.server.url=https://tasks.<domain>` + credentials from `task sync init`)
