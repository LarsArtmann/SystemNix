# atticd (private Nix binary cache)

**Service:** `services.attic-config` — `modules/nixos/services/attic.nix` (wrapper over nixpkgs `services.atticd`; **DynamicUser**). Port 8200 (`lib/ports.nix`), loopback. URL: `cache.<domain>` (**Layer 0/plain** vHost — a substituter must answer unauthenticated NAR requests; Layer 0 semantics: infra, not user-facing). DNS `cache`. Consumed as the substituter `https://cache.<domain>/monitor365` (nix.settings when `cachePublicKey` is set).

CI (Forgejo Actions) pushes build outputs; LAN machines pull — avoiding redundant recompilation. **Storage is pool-native** (`/mnt/pool/services/atticd/storage`): pulls stream from the HDD pool over the shared DAS USB link — acceptable for a short-retention CI cache, wrong for hot storage.

## What it serves

| Route | Auth | What                                              |
| ----- | ---- | ------------------------------------------------- |
| `/`   | none | Nix cache API (NAR info + content, pull is public) |
| push  | JWT  | `attic push` with a token from atticadm            |

## Ops

- **JWT secret (sops `platforms/nixos/secrets/attic.yaml` → `attic-env`)** — `ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64` must be an **RS256 RSA PEM PKCS1 key, NOT a random string**: `openssl genrsa -traditional 4096 | base64 -w0`. Root-owned (DynamicUser reads via EnvironmentFile as PID 1).
- **Storage-dir lifecycle is mount-gated** — `atticd-storage-dir` (oneshot, `RequiresMountsFor`) creates the pool leaf ONLY while the pool is mounted; there is deliberately **NO tmpfiles rule** (tmpfiles can run before the pool mounts and would shadow-create the dir on the root fs). `atticd` itself also `RequiresMountsFor` the storage path — a detached DAS fails the unit loudly instead of writing NARs to the NVMe. deploy.sh restarts the storage-dir oneshot (oneshot+RemainAfterExit ignores restartTriggers).
- **`atticd-bootstrap` skips cleanly pool-less** — `ConditionPathIsDirectory` on the storage path: while the DAS is detached the unit exits "unmet condition" instead of failing every activation with connection-refused (the 2026-08-22/24 exit-4 class). Pool mounted + atticd wedged still fails LOUD at its readiness probe. It mints a 1h bootstrap token via atticadm, ensures the `monitor365` cache exists (public), and applies retention.
- **GC story** — built-in GC every 4h, retention 7d default (time-based ONLY upstream). The hard disk bound is `atticd-size-guard` (30min): over `maxStorageGigabytes` (20) it RESTARTS atticd — monolithic mode runs a GC sweep first thing at startup (source-verified gc.rs; that is the emergency trigger mechanism).
- **Metrics** — `atticd-metrics` (5-min textfile collector, mktemp+CAP_FOWNER pattern): `attic_storage_{bytes,gb,max_gb,over_threshold}` → Gatus "Attic Storage Size" + "Attic Binary Cache" liveness (registry checks).
- **Known exposure (nix 2.34 bug class)** — the substituter lives behind the DAS link; a connect-timeout against it can SIGABRT the nix daemon (nix#3768 — see nix-flakes.md). Failures here are fast (dnsblockd NXDOMAIN / Caddy 502), which is why the bug has never fired.
- **restartTriggers** on settings JSON + package (nixpkgs module sets none).

## Related

- [docs/agents/storage.md](../agents/storage.md) — pool tier + DAS outage semantics
- [docs/agents/nix-flakes.md](../agents/nix-flakes.md) — substituter config, the nix-daemon abort bug
- [forgejo.md](./forgejo.md) — the CI pusher
