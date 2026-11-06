# trash-metrics

**Module:** `modules/nixos/services/trash-metrics.nix` (`services.trash-metrics`)
**Script (single source of truth):** `scripts/trash-size-metrics.sh` — embedded into the unit via `builtins.readFile`, selftested via `bash scripts/trash-size-metrics.sh selftest`, pre-commit shellcheck.
**Enabled:** `platforms/nixos/system/configuration.nix` (evo-x2).
**Created:** 2026-11-06 — the storage.md "make parked-trash size observable" row: 55G sat invisible in `~/.local/share/Trash` for a month (2026-10-08 →) with no metric, no alert, and no closing loop.

## What it does

Hourly oneshot (system service, root, bun-memory-watchdog pattern): `du -sb` every configured trash location and emit a `trash_size_bytes{path=...}` gauge into the node_exporter textfile dir. Default paths: `/home/lars/.local/share/Trash` and `/data/.Trash-1000` (`services.trash-metrics.paths`).

## Why (incident class)

Parked trash is invisible by construction — it leaves `df` deltas unexplained, inflates the home subvol snapshot pin window, and nothing on the box surfaced its size. The 2026-10-08 trash of ~55G tmp Go caches sat for a month until a human noticed. This collector plus two companion legs close the class:

- **trash-prune user timer** (`platforms/common/programs/trash-prune.nix`): weekly `trash-empty 30d` — the closing loop; journals before/after bytes so realized reclaim is greppable from `journalctl --user -u trash-prune`.
- **pre-deploy-check §20**: WARN (never block) when the home Trash is ≥10 GiB at a deploy window — the deploy-time backstop.

## Semantics

- **Missing dir emits 0** — an absent trash location is an honest zero, so gauge-based alerts never need absent-series handling.
- **Freshness stamp**: `trash_metrics_last_run_timestamp_seconds` is rewritten every tick (atomic mktemp+rename per the repo textfile doctrine); a frozen value = dead collector (node_exporter serves stale textfiles forever).
- **`/data/.Trash-1000` is observe-only here** — its purge policy is a separate owner `[decision]` row (snapshot pinning makes immediate purge worthless there); the timer deliberately does NOT touch it.

## State + metrics

- No persistent state — the collector is stateless; the .prom is fully derived per tick.
- Textfile: `trash_size_bytes{path}` + `trash_metrics_last_run_timestamp_seconds` in `/var/lib/prometheus-node-exporter/textfile_collectors/trash-metrics.prom`.

## Traps

- The unit runs as root to read user- and /data-owned trash trees; reads survive `ProtectSystem` (read-only is enough). Only the textfile dir is writable.
- `du -sb` (apparent size on the btrfs subvol) — close enough for threshold purposes; not an extent-exact reclaim predictor (snapshots pin extents regardless).
- Gatus alert wiring is deliberately NOT here (same as bun-memory-watchdog at introduction): pre-deploy §20 + the freshness stamp are the current consumers; wire an alert only if a burn-down regression actually fires.

## Verification

- `bash scripts/trash-size-metrics.sh selftest` — fixture: populated dir emits its `du -sb` bytes, missing dir emits 0, freshness stamp present.
- Live: after deploy, `cat /var/lib/prometheus-node-exporter/textfile_collectors/trash-metrics.prom`.
