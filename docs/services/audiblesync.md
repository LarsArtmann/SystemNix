# AudibleSync (Audible library tracker WebUI) — Agent Notes

> Module: `modules/nixos/services/audiblesync.nix`. Created 2026-11-14 (wrapper-first; see "Upstreaming state" below). Upstream: `github:LarsArtmann/audiblesync` (Go + templ + go-cqrs-lite system/metaengine + cqrs-htmx, v0.1.0).

## STATUS: INTEGRATED 2026-11-14 (enable = true; locked at upstream `e8ef419`, probe-built green before the lock per probe-before-lock). Deploy-gated at authoring time — verify the deploy anchor + live probes below before trusting anything runtime-shaped.

**What it is:** the companion UI to the `audible-sync` weekly archive oneshot — a long-running event-sourced WebUI tracking the Audible library and each book's LOCAL sync state (per-book `Sync now` / `Mark synced` / `Reset` / `Remove`, activity feed from the event journal, SSE live updates). SQLite DB at `/var/lib/audiblesync/audiblesync.db` (StateDirectory), loopback-only on `127.0.0.1:8481` (upstream CLI default, registered as `ports.audiblesync` — cvagent-dashboard precedent).

## Fleet wiring (one registry entry fans it all out)

- **Domain:** `audiblesync.home.lan` — `subdomain = "audiblesync"` in the integration entry + `platforms/common/dns-local.nix`; **vHost layer `protected`** (oauth2-proxy forward-auth, LAN bypass) because the app has NO auth of its own (cqrs-htmx Path A: its CSRF guard only closes cross-site form-POSTs by Origin attestation).
- **Tile:** PapDashboard Media group, "AudibleSync", `openaudible.png` (the dashboard-icons pack has NO Audible glyph — checked upstream 2026-11-01 for the archive tile; this is the pack-wide answer, not a per-tile choice).
- **Gatus:** `AudibleSync health` (`GET /healthz`, asserts `[STATUS] == 200` AND body `"status":"ok"` — the endpoint pings the system composition root AND the read model, 503 + `"error"` on failure) + `AudibleSync dashboard` (60s, `< 1000ms`).
- **Backups:** nightly `audiblesync-backup` (02:35, WAL-safe online `.backup` via `mkSqliteBackupUnit`, quick_check before atomic rename, 14d retention) → `/mnt/pool/backups/audiblesync` (mount-gated `audiblesync-backup-dir` pool-leaf unit, in deploy.sh's provisioner loop). Registry `backup` row: maxAge 25h (nightly cadence).
- **pool-recovery:** `audiblesync` is pool-bound (`RequiresMountsFor /mnt/pool`), so it rides `services.pool-recovery.restartUnits` — a stale-mount remount restarts it (2026-10-04 dark-daemon class).
- **system-health:** `monitored = true` (state/restart/crash-loop metrics).

## The shared identity (read before touching either service)

The WebUI and the weekly archive oneshot **share the `audible-sync` identity on purpose**: same service user, same sops auth (`audible_sync_auth_json`), same `/mnt/pool/services/audible` tree. The module ASSERTS co-enable at eval (`services.audible-sync.enable` must hold) — flipping audiblesync on alone leaves the sync button auth-less and the unit without its user. `Sync now` runs the module's `audible-book-sync` wrapper (via the app's `{asin}`-substituted `sh -c` template):

1. Already-on-disk check (prefix glob `${ASIN}*.m4b` in `books/` — the archive names files ASIN-prefixed via `--filename-mode asin_ascii`) → idempotent no-op when present.
2. `audible download -a <ASIN> --aax --chapter --cover --pdf` → `downloads/` (the PROVEN AAX path for this account; AAXC vouchers are refused server-side — see the audible-sync runbook's 2026-11-11 pivot. No `--ignore-errors`: the WebUI records the verdict from this exit code).
3. ffmpeg `-activation_bytes` remux → `books/`, raw AAX deleted on success (kept on failure for retry). Needs `activation_bytes` non-null in the sops auth (one-time `audible activation-bytes` fetch, already done for the archive).

## Known gaps (deliberate, not oversights)

- **Local files page is OFF** (no `AUDIBLESYNC_LIBRARY_DIR`): the app scans for files named EXACTLY `<ASIN>.m4b` (`^([0-9A-Z]{10})\.m4b$`, `internal/app/files.go`), while the archive's `asin_ascii` naming is `<ASIN>_<title>.m4b`. Pointing the knob at `books/` would render the page permanently empty. Fix paths: an upstream pattern-configuration option, or a symlink-farm oneshot — not wired yet (cosmetic page; the library table carries the real state).
- **OTel not wired:** the app has no OTel instrumentation of its own (indirect deps only; its own library-review verdict: "no telemetry backend exists" for a LAN tool). No `OTEL_EXPORTER_OTLP_ENDPOINT` → no signoz-coverage registration needed (the audit only gates units carrying the env).

## Upstreaming state (2026-11-08 doctrine: product repos own their modules)

The flake exports `packages.default` ONLY — no `nixosModules` — so the SystemNix wrapper hand-rolls the unit (bank-sync/crm interim). The portable set is NOT small (options + unit shape + the `audible-book-sync` script), so the extraction recipe in `docs/agents/integration-registry.md` applies: extract `nixosModules.default` upstream, then delegate the wrapper to `imports = [ inputs.audiblesync.nixosModules.default ]` + rendered-unit parity. What stays fleet-side NO MATTER WHAT: the integration registry entry (tile/checks/vHost/backup freshness — fleet-side always), `lib/ports.nix`, `dns-local.nix`, sops wiring, `ioTier`/`onFailure`, the backup generators, deploy.sh provisioning, and the co-enable assertion with the archive oneshot.

## Upstream traps already paid for (do not relearn)

- **flake.nix `self`-binding deadnix strip (3rd recurrence, fixed `e8ef419` 2026-11-14):** the auto-commit daemon swept a deadnix run that removed the schema-mandated `self` argument AND the `.buildflow.yml` deadnix-skip guard in one commit — flake eval + every consumer died with `function 'outputs' called with unexpected argument 'self'`. The push of that broken rev rode this session's lock wave. `.buildflow.yml` is restored upstream-side; keep it.
- **`nix build` needs files git-tracked** (git-tree fetcher) — upstream-side rule; `git add` before any build claim.
- **Single-instance flock** — the app holds an exclusive DB lock; a second instance fails fast (`ErrAnotherInstance`). Don't run a manual instance against the prod DB path while the unit is up.

## Verify (post-deploy)

```
ss -ltnp | grep 8481                                  # loopback bind
getent hosts audiblesync.home.lan                     # dnsblockd record
printf 'GET /healthz HTTP/1.1\r\nHost: audiblesync.home.lan\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect 192.168.1.150:443 -servername audiblesync.home.lan   # curl-banned; LAN IP only
journalctl -u audiblesync --since today
ls /mnt/pool/backups/audiblesync/                     # after the first 02:35 tick
```

Tile: PapDashboard → Media tab. Gatus: `AudibleSync health` + `AudibleSync dashboard` endpoints.
