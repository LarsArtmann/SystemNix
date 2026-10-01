# nsfw-classifier (browser-extension image filter backend)

**Service:** `services.nsfw-classifier` — `modules/nixos/services/nsfw-classifier.nix` (Go/ONNX server from the `nsfw-classifier` flake input; models are the gitignored checkout at `/home/lars/projects/nsfw-classifier/models`, read-only). Port 8104 (`lib/ports.nix`). URL: `nsfw.<domain>` — **Layer 1-style PLAIN vHost** (registry; deliberately NOT protected: the classify API's auth IS the pairing token, and a forward-auth gate would break the extension's direct clients). DNS `nsfw`.

Backend for the Helium NSFW extension (loaded via `--load-extension` from the source dir — see desktop.md): classifies images, pairs with the browser, serves verdicts.

## What it serves

| Route     | Auth                          | What                                            |
| --------- | ----------------------------- | ----------------------------------------------- |
| `/readyz` | none                          | Readiness (model load + warmup) — Gatus check   |
| classify  | pairing token (in-app)        | Image classification API (extension clients)    |

## Ops

- **Runs as `lars`, NOT DynamicUser** — the multi-GB models checkout sits under the 0700 home; only the owner can traverse it. `ProtectHome = false` is deliberate for the same reason (ProtectSystem stays strict; everything else locked down).
- **Persistent state via `XDG_CACHE_HOME=/var/cache`** — `CacheDirectory=nsfw-classifier` (systemd-created, lars-owned): pairing token, verdict cache, feedback JSONL survive restarts, so the extension stays paired.
- **Port binds BEFORE model load** (fast-fail on port-in-use; `Type=simple` is sufficient) — `/readyz` gates readiness during load + warmup; expect first-check red after a cold start.
- **Limits** — MemoryMax 2G (ONNX runtime), ioTier.background; unit-state monitoring via the registry entry (monitored).
- **The extension half lives elsewhere** — the Chromium extension (`~/projects/nsfw-classifier/nsfw-extension`) is injected into every Helium instance by the wrapper flag; its ID is path-derived (SHA-256 of the load path), so the source dir path must stay stable or extension settings reset.

## Related

- [docs/agents/desktop.md](../agents/desktop.md) — the Helium `--load-extension` wiring and path-stability rule
