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
- **Port binds BEFORE model load** (fast-fail on port-in-use; `Type=simple` by default — any `watchdogSec` value flips the unit to `Type=notify`, see the deploy checklist) — `/readyz` gates readiness during load + warmup; expect first-check red after a cold start, now with `TimeoutStartSec = 10min` (17 CPU model loads vs the global 3-min default).
- **Limits** — MemoryMax 16G (full ensemble; MemoryHigh derived 12.8G), ioTier.background, start-limit 5 starts / 5 min (test-pinned).
- **Alerting** — unit failures page via the `notify-failure@%n` template (Discord); Gatus probes `http://127.0.0.1:8104/readyz` every 30s with `[STATUS] == 200` + `[RESPONSE_TIME] < 500` (measured 0.3–10 ms live), plus an x86_64-only `nsfw-classifier-provider` check on `/api/health` that alarms when the EFFECTIVE provider stops being `rocm` (the silent-CPU incident's tripwire, 2026-10-29); unit-state metrics via the registry entry (`monitored`).
- **CLI on PATH** — the module installs the unit's package (same ROCm wrapping) into `environment.systemPackages`: `nsfw <subcommand>` works in any shell (`server`, `classify`, `benchmark`, `batch-report`, `evaluate`, `human-review`, `latency-bench`, plus `faces`/`parts`/`immich`/`history`), and `bin/` also carries the `nsfw-server`/`nsfw-classify`/… compat shims. Don't casually run a second `nsfw server` against the live instance (port 8104 + shared cache/state roots; the running unit IS the server).
- **GPU runtime (ROCm/MIGraphX) — RESOLVED 2026-10-15, was the silent-CPU incident**: the `package` option defaults to the flake's `nsfw-classifier-go-rocm` build on x86_64 (`?`-guarded so a pre-rocm lock keeps evaluating on the CPU build). The CPU-wrapped package's ONNX Runtime (the Microsoft release) cannot enable MIGraphX at all — on this AMD host every model silently fell back to CPU inference on every restart since at least Oct 7 (journal: `auto-detected provider unavailable, falling back to CPU` per model), which held ~300ms fast verdicts only while the box was idle; under 2026-10-15's sibling-session load CPU inference hit 5-15s and the extension's 10s upload timeout failed every classify (fail-open reveals). Verify after every deploy: `/metrics` (Bearer pairing token) shows `"provider": "rocm"` and `provider_cpu_fallbacks: 0` — upstream surfaces the EFFECTIVE provider there since the incident; `"device": "auto"` alone is the request, not the reality. GPU cold start compiles MIGraphX kernels and is SLOW (measured 74m50s calm-cold; the old "~2min, cached under /var/cache" claim never held — see Startup timeline below).
- **The extension half lives elsewhere** — the Chromium extension (`~/projects/nsfw-classifier/nsfw-extension`) is injected into every Helium instance by the wrapper flag; its ID is path-derived (SHA-256 of the load path), so the source dir path must stay stable or extension settings reset.
- **Extension port-drift guard boundary** — the `extension-default-url-port-drift` case in `tests/test-nsfw-classifier.nix` pins the FLAKE INPUT's `nsfw-extension/url-utils.js` (`DEFAULT_SERVER_URLS[0]` == resolved port). Helium loads the LIVE checkout, so a live `url-utils.js` port edit bypasses the guard until the input rev is bumped — that boundary is accepted: the guard fires at every input bump (flake check / CI), and live edits are the documented dev workflow (upstream repo owns its own pre-commit). A Nix eval cannot hermetically read a foreign working tree.
- **Open owner decisions** (queued in `docs/todo/services.md`, deliberately not agent-decided): whether `nsfw.home.lan` should count as "local" for auto-opt-in feedback; the LAN trust model for the unauthenticated `/readyz` pairing token (rate-limit flag exists upstream as mitigation). ~~GPU/ROCm fast mode vs CPU falconsai~~ — RESOLVED 2026-10-15 by the silent-CPU incident: the unit runs the ROCm-wrapped package (see the GPU runtime bullet above). ~~Backup policy for `/var/cache/nsfw-classifier`~~ — RESOLVED 2026-10-12 by ADR-0016: durable stores moved to the state root (see Migration below); what remains in cache is regenerable by design, so no dedicated backup tier is owed to it.

## Deploy / lock-bump checklist (one page)

Every upstream bump re-lands weeks of gated hardening at once — the running
binary is ALWAYS the oldest code on the box. Live evidence 2026-10-29: the
unit runs upstream rev `58d398d` (2026-10-27), `provider: rocm` — the
2026-10-18 boot-hang blockers (concurrent-Run SEGV fix, inference run gate,
sd_notify binary support, `-rocm` default) ARE in that rev; what is still
MISSING is the systemd watchdog flip (the binary speaks sd_notify, the unit
never set `Type=notify`, so nothing pings) and routine lock currency.

Owner steps (agent cannot: root + deploy):

```bash
cd ~/projects/SystemNix
# 1. Bump the input (fold this into EVERY deploy — the bump IS the deploy)
nix flake lock --update-input nsfw-classifier
# 2. Flip the watchdog on the live host config (one-time, still pending):
#    services.nsfw-classifier.watchdogSec = 300;   # recommended floor; flips Type=notify
# 3. Build + switch (a RESTART costs the full boot timeline — see Startup
#    timeline; prefer the next natural restart window)
nixos-rebuild test --flake .#evo-x2
sudo systemctl restart nsfw-classifier
```

Post-verify (in order; all non-root):

1. **Provider truth** — `curl -s http://127.0.0.1:8104/api/health | jq .provider` must be `rocm` (the new `nsfw-classifier-provider` Gatus check now alarms on this automatically; `"device": "auto"` alone is the REQUEST, not the reality).
2. **Watchdog armed** — `systemctl show nsfw-classifier -p Type -p WatchdogUSec` → `Type=notify`, `WatchdogUSec=300000000`; the journal shows periodic WATCHDOG pings and upstream `/metrics` carries `nsfw_systemd_*` counters (scraped only under a notify socket).
3. **Readiness** — `/readyz` 200 after the (SLOW, normal) boot budget; first Gatus red after a cold start is expected.
4. **Extension classify** — a real image through the browser extension (pairing survives restarts; token lives in the cache root).
5. **No leaked sessions at shutdown** — the 2026-10-29 upstream lifecycle fix releases the skin/exposed/person ONNX sessions through `injector.Shutdown()`; the next stop/restart's journal must show zero leaked-session warnings (builds before that rev leak all three).
6. **Provider CPU fallbacks** — `/metrics` `provider_cpu_fallbacks: 0`.

Rollback: `nix flake lock --recreate-lock-file` is NOT the rollback — revert
`flake.lock` (git), `nixos-rebuild test`, restart. The state root is untouched
by lock bumps.

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

## Startup timeline (measured — long is NORMAL, never casually restart)

Port binds immediately; serving starts only after load + warmup. Measured sequence (2026-10-25 boot, warm page cache, load-40 storm):

1. `port bound, loading models` (bind, connections queue in the kernel backlog — `ss` Recv-Q growth is the expected mid-boot state, not a hang)
2. `classifier resolved mode=ensemble` (~1–4 min warm; the 15-model ensemble + per-model provider lines)
3. aux evidence stack: `skin segmenter resolved`, `exposed detector resolved`, `face service resolved` (several minutes, sparse logs)
4. store hydration: `verdict cache hydrated` (+ per-event WARN skips for undecodable journal events — non-fatal), then all six `* store resolved` lines within the same second
5. **warmup — SILENT** (MIGraphX kernel compile; no log lines by design; the `server warmup complete` line is not always emitted — 2026-10-25 serving began without it)
6. serving: gatus `/readyz` 200s every 30s, `client_ip=192.168.1.150` Caddy traffic

Budgets: calm cold boot **74m50s** (2026-10-17, boot ee085387); warm-page-cache boot under load-40 storm **22 min** (05:43:33 start → 06:05:21 first 200). A restart costs the FULL timeline — check the unit's `Started` timestamp before touching it.

**MIGraphX kernel cache does NOT persist** (2026-10-25): despite the earlier "~2min, cached under /var/cache" claim, NO kernel-cache directory has ever appeared under `/var/cache` (or `~/.cache`) — the cache-location premise came from the silent-CPU era and was never re-verified; every start recompiles. Persistence fix queued (docs/todo/services.md).

**Crash-loop signature (fixed 2026-10-25, upstream `61a5257c`)**: builds before `61a5257` SIGSEGV'd at store-build (`(*buildVerdictStoreError).Unwrap` nil-deref, `app.go:788`) AFTER all `store resolved` lines — the typed-nil bug made every fully-successful boot exit 2. 239 restarts in one boot (2026-10-20→25); the 5-start/5-min start-limit never trips because each cycle (~12–17 min) outlives the window. If you see `systemd[1]: Scheduled restart job` following a clean `store resolved` sequence, check the running binary's rev first.

## Related

- [docs/agents/desktop.md](../agents/desktop.md) — the Helium `--load-extension` wiring and path-stability rule

## Nightly Immich triage (nsfw-immich-scan, C7)

`nsfw immich` classifies NEW Immich assets and writes the verdicts back
as `nsfw:*` tags — the verdict PRODUCER for the media-atlas lane join
(nightly 04:00 `atlas pull --with-lanes` reads those tags). Deployment
only (ADR-061: the classifier repo stays change-free); the CLI is
upstream verbatim — incremental (--only-new provenance marker),
resumable (checkpoint under the cache dir), fail-open per asset.

Owner deploy steps (one-time):

1. Mint a DEDICATED Immich key for the scan: asset read (previews) AND
   tag write (the verdicts) — NOT the media-atlas hub's read-only key.
   Immich shows the secret only at creation.
2. Install it root/0400 at the apiKeyFile path you configure (default
   suggestion: /var/lib/nsfw-classifier/immich-key, owner lars).
3. Enable in configuration.nix:
   `services.nsfw-classifier.immichScan = { enable = true; apiKeyFile = "/var/lib/nsfw-classifier/immich-key"; };`
   (calendar default 01:00 — before the media-atlas 02:00 poll → 04:00
   lane join, so fresh verdicts land in the same night's lanes).
4. `nix run .#deploy`; first full pass over a five-figure library runs
   HOURS (TimeoutStartSec 6h) — subsequent nights are minutes.
5. Verify: `systemctl list-timers nsfw-immich-scan`, then the JSON run
   report at /var/lib/nsfw-classifier/state/immich-scan-<date>.json and
   `journalctl -u nsfw-immich-scan -n 50`.
