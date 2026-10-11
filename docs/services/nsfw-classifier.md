# nsfw-classifier (browser-extension image filter backend)

**Service:** `services.nsfw-classifier` — `modules/nixos/services/nsfw-classifier.nix` (Go/ONNX server from the `nsfw-classifier` flake input; models are the gitignored checkout at `/home/lars/projects/nsfw-classifier/models`, read-only — the `modelsDir` option default). Port 8104 (`lib/ports.nix`). URL: `nsfw.<domain>` — **Layer 1-style PLAIN vHost** (registry; deliberately NOT protected: the classify API's auth IS the pairing token, and a forward-auth gate would break the extension's direct clients). DNS `nsfw`.

Backend for the Helium NSFW extension (loaded via `--load-extension` from the source dir — see desktop.md): classifies images, pairs with the browser, serves verdicts.

## What it serves

| Route     | Auth                   | What                                          |
| --------- | ---------------------- | --------------------------------------------- |
| `/readyz` | none                   | Readiness (model load + warmup) — Gatus check |
| classify  | pairing token (in-app) | Image classification API (extension clients)  |

## Ops

- **Runs as `lars` (the `user` option default), NOT DynamicUser** — the multi-GB models checkout sits under the 0700 home; only the owner can traverse it. `ProtectHome = false` is deliberate for the same reason (ProtectSystem stays strict; everything else locked down, including `RestrictAddressFamilies = AF_INET/AF_INET6/AF_NETLINK/AF_UNIX`).
- **Full-ensemble posture, per-request fast** — the unit passes `--all`: EVERY NSFW-detection model exported in the checkout loads (17 of 18 registry entries; `jiechau` is product-moderation and excluded upstream). Registry order is preserved, so the extension's quick-scan path (`fast=true`) still gets a single-model verdict from falconsai — same latency as ever — while non-fast/stream requests get the full 17-model vote (~1-3s CPU per image under parallel inference). `--fast` would load ONLY the first model (`fastKey` takes keys[0], upstream `internal/app/app.go`); a lean explicit list is one `models` option away (null = `--all`). The aux evidence stack (nudenet/skinseg/face) is disk-gated and unaffected.
- **Storage follows value class (ADR-0016, upstream `docs/adr/0016-state-root-storage-placement.md`)** — TWO roots:
  - **State root** `/var/lib/nsfw-classifier/state/` (`StateDirectory=nsfw-classifier/state`, mode 0700): the DURABLE stores — `feedback.db` (irreplaceable golden human labels), `domains.db` (DNS-feed evidence journal), `history.db` + `history/` (unrepeatable captures). Wired via explicit `--feedback-db/--domain-db/--history-db/--history-dir` flags (the `stateRoot` option; `null` = upstream cache-dir defaults = migration rollback).
  - **Cache root** `/var/cache/nsfw-classifier/` (`CacheDirectory=` + `XDG_CACHE_HOME=/var/cache`, lars-owned): what STAYS — `verdicts.db` (recomputable by design), `feedback.jsonl` (derived mirror; rebuilt from the journal when missing), `pair-token` (extensions auto re-pair from `/readyz`).
- **Port binds BEFORE model load** (fast-fail on port-in-use; `Type=simple` is sufficient) — `/readyz` gates readiness during load + warmup; expect first-check red after a cold start, now with `TimeoutStartSec = 10min` (17 CPU model loads vs the global 3-min default).
- **Limits** — MemoryMax 16G (full ensemble; MemoryHigh derived 12.8G), ioTier.background, start-limit 5 starts / 5 min (test-pinned).
- **Alerting** — unit failures page via the `notify-failure@%n` template (Discord); Gatus probes `http://127.0.0.1:8104/readyz` every 30s with `[STATUS] == 200` + `[RESPONSE_TIME] < 500` (measured 0.3–10 ms live); unit-state metrics via the registry entry (`monitored`).
- **The extension half lives elsewhere** — the Chromium extension (`~/projects/nsfw-classifier/nsfw-extension`) is injected into every Helium instance by the wrapper flag; its ID is path-derived (SHA-256 of the load path), so the source dir path must stay stable or extension settings reset.
- **Extension port-drift guard boundary** — the `extension-default-url-port-drift` case in `tests/test-nsfw-classifier.nix` pins the FLAKE INPUT's `nsfw-extension/url-utils.js` (`DEFAULT_SERVER_URLS[0]` == resolved port). Helium loads the LIVE checkout, so a live `url-utils.js` port edit bypasses the guard until the input rev is bumped — that boundary is accepted: the guard fires at every input bump (flake check / CI), and live edits are the documented dev workflow (upstream repo owns its own pre-commit). A Nix eval cannot hermetically read a foreign working tree.
- **Open owner decisions** (queued in `docs/todo/services.md`, deliberately not agent-decided): GPU/ROCm fast mode vs CPU falconsai; whether `nsfw.home.lan` should count as "local" for auto-opt-in feedback; the LAN trust model for the unauthenticated `/readyz` pairing token (rate-limit flag exists upstream as mitigation). ~~Backup policy for `/var/cache/nsfw-classifier`~~ — RESOLVED 2026-10-12 by ADR-0016: durable stores moved to the state root (see Migration below); what remains in cache is regenerable by design, so no dedicated backup tier is owed to it.

## Storage migration & backup

### Migration: cache → state root (ADR-0016)

One-time move of the three durable stores. Pre-migration evidence (2026-10-12 01:04, unit up): `/metrics` `feedback.records == 7` (`by_verdict {miss:2, wrong:5}`, `hashes: 7`), `/readyz` 200 all-pass; `history/` = 2248 files / 124.6 MB.

Requires root (the agent cannot run these — owner executes):

```bash
# 0. Deploy the module change first: nixos-rebuild will rewrite the unit with
#    the state-root flags, but DO NOT let it restart into empty state roots —
#    stop the unit BEFORE switching (step 1), or use:
#    sudo nixos-rebuild test  # after stopping, see step 2
sudo systemctl stop nsfw-classifier

# 1. Pre-copy evidence (stopped unit = consistent WAL snapshot)
sudo sha256sum /var/cache/nsfw-classifier/{feedback.db,domain*,history.db,pair-token} \
  | sudo tee /var/cache/nsfw-classifier/migration-pre.sha256

# 2. Switch generation (creates StateDirectory /var/lib/nsfw-classifier/state, 0700 lars)
sudo nixos-rebuild test --flake .#evo-x2

# 3. Copy — ALL WAL/SHM siblings included, preserving owner/perms (-a)
sudo cp -a /var/cache/nsfw-classifier/feedback.db* \
           /var/cache/nsfw-classifier/domains.db* \
           /var/cache/nsfw-classifier/history.db* \
           /var/cache/nsfw-classifier/history \
           /var/lib/nsfw-classifier/state/

# 4. Post-copy evidence: checksums MUST match step 1
sudo sha256sum /var/lib/nsfw-classifier/state/feedback.db* \
               /var/lib/nsfw-classifier/state/domains.db* \
               /var/lib/nsfw-classifier/state/history.db* \
  | diff - <(sudo sha256sum /var/cache/nsfw-classifier/{feedback.db,domain*,history.db} | sed 's#/var/cache/nsfw-classifier#/var/lib/nsfw-classifier/state#')

# 5. Start + verify
sudo systemctl start nsfw-classifier
sleep 5 && curl -sf http://127.0.0.1:8104/readyz | jq '.status'   # "ok"
curl -s http://127.0.0.1:8104/metrics | jq '.feedback'            # records == 7, miss == 2, wrong == 5
# then: browser extension classify → works WITHOUT re-pairing (token untouched in cache)

# 6. After a soak period: remove the old cache-root DBs (rollback window closed)
sudo rm -i /var/cache/nsfw-classifier/{feedback.db,domain*,history.db}* /var/cache/nsfw-classifier/history
```

**Rollback** (any time before step 6): `sudo systemctl stop nsfw-classifier`, set `stateRoot = null` (or revert the module), `sudo nixos-rebuild test --flake .#evo-x2`, `sudo systemctl start nsfw-classifier` — the unit reopens the untouched cache-root files.

### Backup & restore drill

- **Coverage**: the state root sits on the `@` root subvolume → btrbk root snapshots (`/mnt/btrfs-root/.snapshots`, `snapshot_preserve_min=2d; 3d` + weekly) cover it identically to the old cache location. Same-disk snapshots are crash recovery, NOT a backup tier.
- **Offsite tier**: `services.offsite-borg` covers `/` subsets when enabled (currently DORMANT — enable decision stays with the owner in docs/services/offsite-borg.md). Once live, the state root rides the same root-path job; no extra config owed.
- **Restore drill** (after every btrbk retention change, at least quarterly):

```bash
# Restore latest root snapshot to a temp dir (read-only mount of the snapshot)
latest=$(ls -1d /mnt/btrfs-root/.snapshots/@.2026* | sort | tail -1)
sudo mkdir -p /tmp/nsfw-restore-drill
sudo cp -a "$latest/var/lib/nsfw-classifier/state/feedback.db"* /tmp/nsfw-restore-drill/
# Open read-only (no sqlite3 CLI on this box — python3 stdlib, WAL-safe URI):
python3 - <<'EOF'
import sqlite3
c = sqlite3.connect("file:/tmp/nsfw-restore-drill/feedback.db?mode=ro", uri=True)
print(c.execute("select count(*) from meta_stream_log").fetchone())  # expect 7+ events worth of streams
EOF
# Counts must match the /metrics feedback.records evidence above; then clean up:
sudo rm -rf /tmp/nsfw-restore-drill
```

## Related

- [docs/agents/desktop.md](../agents/desktop.md) — the Helium `--load-extension` wiring and path-stability rule
