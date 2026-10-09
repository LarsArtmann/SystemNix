# file-and-image-renamer (AI screenshot renaming watcher)

**Service:** `services.file-and-image-renamer` — `modules/nixos/services/file-and-image-renamer.nix` (flake input package). Two units: the watcher (inotify on watch paths, renames new screenshots via AI vision) and the health dashboard (**Layer 2 protected** `renamer.<domain>`, registry entry, health port 8086 in `lib/ports.nix`). Runs as the primary user (watch dirs live under the 0700 home).

## What it serves

| Route | Auth                    | What                                            |
| ----- | ----------------------- | ----------------------------------------------- |
| `/`   | forward-auth / open LAN | Health dashboard (queue, dead letters, history) |

## Ops

- **AI providers** — ZAI GLM vision (`apiKeyFile` → `ZAI_API_KEY_FILE`, optional) + Synthetic (`syntheticApiKeyFile`, `synthetic:*` models — same key family as crush-daily). Either can be null; the watcher degrades to whichever is configured.
- **State lives in `~/.file-renamer/`** (dead-letter.json, hashdb, history, logs) — tmpfiles-created 0750. The health unit redirects `HISTORY_FILE_PATH`/`HASHDB_PATH` there explicitly: its defaults (`~/.renamer-history.json`) sit outside the unit's `ReadWritePaths` and nil-deref the handlers into HTTP 500s.
- **Health dashboard is a SYSTEM service** (Caddy-proxied; must not depend on the graphical session), watcher likewise headless. Both carry ProtectHome=read-only with watch paths + dataDir in ReadWritePaths.
- **OTel** — both units export to `localhost:4318`; event-driven cadence (renames happen when screenshots happen) — registered in signoz-coverage accordingly.
- **Limits** — watcher MemoryMax 512M, health 256M; RestartSec 10s/15s.
- **Dead letters** — failed renames park in `dead-letter.json` (dashboard surfaces them); nothing is ever deleted by the watcher itself.

## Related

- [signoz.md](./signoz.md) — span destination
- [docs/agents/desktop.md](../agents/desktop.md) — screenshot workflow context (Helium)
