# file-and-image-renamer (AI screenshot renaming watcher)

**Service:** `services.file-and-image-renamer` — `modules/nixos/services/file-and-image-renamer.nix` (flake input package). Two units: the watcher (inotify on watch paths, renames new screenshots via AI vision) and the health dashboard (**Layer 2 protected** `renamer.<domain>`, registry entry, health port 8086 in `lib/ports.nix`). Runs as the primary user (watch dirs live under the 0700 home).

## What it serves

| Route | Auth                    | What                                            |
| ----- | ----------------------- | ----------------------------------------------- |
| `/`   | forward-auth / open LAN | Health dashboard (queue, dead letters, history) |

## Ops

- **AI providers** — ZAI GLM vision (`apiKeyFile` → `ZAI_API_KEY_FILE`, optional) + Synthetic (`syntheticApiKeyFile`, `synthetic:*` models — same key family as crush-daily). Either can be null; the watcher degrades to whichever is configured.
- **State lives in `~/.file-renamer/`** (`cqrs-events.db` — the SQLite CQRS event store/projections — and `logs/`) — tmpfiles-created 0750. Since the 2026-10-19 migration to the upstream module, BOTH units set `CQRS_DB_PATH` and `LOG_DIR` there explicitly (the module lives in the file-and-image-renamer repo as `flake.nixosModules.file-and-image-renamer`; this repo only wraps machine integration). The legacy `dead-letter.json`/`hashdb`/`history.json` stores were deleted upstream 2026-09-18 — dead letters now live in the event store and surface via the dashboard's DLQ view.
- **Health dashboard is a SYSTEM service** (Caddy-proxied; must not depend on the graphical session), watcher likewise headless. Both carry ProtectHome=read-only with watch paths + dataDir in ReadWritePaths.
- **OTel** — both units export to `localhost:4318`; event-driven cadence (renames happen when screenshots happen) — registered in signoz-coverage accordingly.
- **Limits** — watcher MemoryMax 512M, health 256M; RestartSec 10s/15s.
- **Dead letters** — failed renames park in the CQRS dead-letter store inside `cqrs-events.db` (dashboard DLQ view surfaces them); nothing is ever deleted by the watcher itself. Since 2026-11-06 (build 973dd38) the watcher SELF-HEALS the DLQ: a 30s-after-boot sweep re-queues failed files every 15m with exponential backoff + per-stream jitter, gated on the AI-provider doctor (only retries when a provider tier is healthy), skips deterministic-failure classes, and re-queues retrying streams older than 24h as orphaned sagas. `DLQ_SWEEP_INTERVAL=0` disables the whole mechanism.
- **Watcher health surface** — the watcher unit serves loopback `127.0.0.1:8089` (`WATCHER_HEALTH_ADDR`, registry port `file-and-image-renamer-watcher`): `/healthz` (the Gatus "File Renamer Watcher" check target), `/readyz` and `/startupz`. The dashboard's 8086 stays the only Caddy-proxied port.

## Related

- [signoz.md](./signoz.md) — span destination
- [docs/agents/desktop.md](../agents/desktop.md) — screenshot workflow context (Helium)
