# DiscordSync — Runbook

Discord backup bot (messages, attachments, reactions) — SystemNix wrapper around the upstream `nixosModules.default` (`inputs.discordsync`). Dashboard at `discordsync.home.lan` (Layer 2 protected vHost), API on loopback `127.0.0.1:8085` (`ports.discordsync-api`).

## Units

| Unit                                | Shape                                                     | Notes                                                                                                  |
| ----------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `discordsync.service`               | long-running daemon, `harden{}` + 2G / GOMEMLIMIT 1536MiB | API + Discord gateway; env from the `discordsync-env` sops template                                    |
| `discordsync-io-metrics.service`    | oneshot + 30s timer, hardened + CAP_FOWNER                | Writes `discordsync_io.prom` (cgroup IO counters, mktemp doctrine) into the node-exporter textfile dir |
| `discordsync-db-heal.service`       | oneshot + RemainAfterExit, `+`-privileged                 | SQLite integrity check → `.recover` → BTRFS snapshot restore cascade (10min)                           |
| `discordsync-immich-verify.service` | oneshot, daily timer, User=discordsync                    | Verifies the Immich API key (see below); OnFailure pages                                               |

## Resource policy

Values below are eval-proven against the evo-x2 topology; the upstream module declares CPUQuota/MemoryMax at plain priority, so this module's overrides ride `mkForce` (a plain-assignment override silently loses to upstream — proven 2026-09-25 when CPUQuota rendered 100% until forced).

- **CPUQuota 200%** (upstream ships 100%): the integrity-sweep hasher is single-threaded, but the Go GC's background workers and the download pipeline are concurrent — 100% throttles GC onto one core and reproduces the zombie-gateway shape (missed heartbeats) under backfill load. 2 of 32 cores still caps a runaway hot loop.
- **MemoryMax 2G / GOMEMLIMIT 1536MiB** (upstream 512M): backfill bursts + turso-sync.
- **Restart backoff ladder (T25)**: `RestartSec=10`, `RestartSteps=10`, `RestartMaxDelaySec=5min`, `StartLimitBurst=10` per `StartLimitIntervalSec=1800` — repeated crashes back off toward 5 minutes instead of hot-looping the gateway into Discord rate limits, while 10 starts per 30min still let a genuine crash loop reach the OnFailure page.
- **Integrity-sweep jitter (T26)**: the sweep start is jittered ±`INTEGRITY_CHECK_JITTER_PERCENT` (default 10, max 50, hot-reloadable) so sweep storms do not re-lockstep after fleet-wide restarts; the 24h `DiscordSyncContentIntegrityStale` alert carries the margin (12h interval × 1.1 = 13.2h ≪ 24h).

## Secrets

`discordsync-env` (sops template, owner `discordsync`, 0400): `DISCORD_TOKEN`, `TURSO_URL`, `TURSO_AUTH_TOKEN`, `DISCORDSYNC_WEBHOOK_URL`, and — when `services.discordsync.immich.enable` — `IMMICH_URL` + `IMMICH_API_KEY`. Raw values live in `platforms/nixos/secrets/discordsync.yaml` and `discordsync-immich.yaml`.

**sops edits run as your user** with the SOPS_AGE_KEY one-liner (docs/agents/secrets.md, Sops + Age section). Plain `sudo sops` FAILS (root has no age identity).

## Immich cross-archive comparison (`/lookup` page, ADR-062)

The `/lookup` page gains an "Also check Immich" toggle: the browser computes SHA-1, the server proxies hex hashes to Immich's `POST /api/assets/bulk-upload-check` (`internal/immichclient`), cards render found/not-found with asset links. Only hashes cross the network — never file bytes. `IMMICH_URL` + `IMMICH_API_KEY` are COLD config with both-or-neither startup validation (`ErrImmichConfigIncomplete`).

Wiring on evo-x2:

- `services.discordsync.immich.enable = true` (configuration.nix)
- `services.discordsync.immich.url` defaults to `http://127.0.0.1:<ports.immich>` (loopback — co-located, no Caddy/DNS/TLS dependency on the lookup path)
- The API key never leaves the server process; scope it in Immich to **`asset.read` + `asset.upload` ONLY** (bulk-upload-check's permission guard demands `asset.upload` even though nothing is uploaded — never grant delete/update)

### Go-live (paste the real key)

1. Immich UI → account → API Keys → create key, scope `asset.read` + `asset.upload`.
2. Paste it (interactive `sops` editor — never a command-line value):

   ```bash
   SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops platforms/nixos/secrets/discordsync-immich.yaml
   ```

3. Deploy. The secret's `restartUnits` restarts `discordsync` + `discordsync-immich-verify`, so the verify runs immediately.
4. Confirm: `journalctl -u discordsync-immich-verify` → `Immich API key verified against http://127.0.0.1:2283`.

Until step 2 happens, the shipped PLACEHOLDER is inert by design: the verify unit logs and exits 0, the toggle renders, and lookups answer the "Immich unavailable" badge (upstream auth_error degradation).

### `discordsync-immich-verify` exit semantics

| Exit | Meaning                                                                          | Action                                                     |
| ---- | -------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 0    | key verified / PLACEHOLDER / integration off / **Immich unreachable**            | none (Immich availability is the Gatus Immich check's job) |
| 1    | Immich reachable but **rejected the key** (HTTP 401/403 — wrong secret or scope) | OnFailure Discord alert; fix key/scope, redeploy           |

Rotation: repeat steps 2–3 (or just restart the verify unit after `sops --set` — the template's `restartUnits` already covers it).

## Monitoring

- Gatus "DiscordSync" (`/healthz`, 60s) — liveness after the thumb-hash backfill
- Gatus "DiscordSync Legacy DLQ Stable" + "DiscordSync Turso Sync Active" (the Turso check is DELIBERATELY RED while the cloud mirror is paused — local-first stance, do not silence)
- `discordsync` in system-health `monitoredServices`; `discordsync-immich-verify` in `extraMonitoredServices` (daemon-less → OnFailure + state metrics, github-auto-assign pattern)
- Prometheus mirrors (M07) live upstream in DiscordSync's `monitoring/alerts.yml`; DB-growth and sync-failure-count alerts stay Prometheus-only by design
- Textfile counters `discordsync_unit_io_read_bytes` / `discordsync_unit_io_write_bytes` (30s, unit-cgroup IOAccounting; reset on unit restart) in `discordsync_io.prom`; SigNoz rule `discordsync-read-storm` (>150MB/s over 10m) attributes read storms — the 2026-09-02 integrity-sweep class. Audit fixed-name `.tmp` writers with `bash scripts/audit-textfile-tmp.sh`

## Turso sync state

`backend = "turso-sync"` + upstream quota fallback: the free plan's `BLOCKED` read error flips the service to fully-local SQLite with cloud sync disabled (journal `turso_local_only_mode`), resuming automatically on plan upgrade. Never "fix" the red Gatus check — it IS the standing stale-mirror signal.

## Known traps

- Upstream `healthCheck` (ExecStartPost readiness gate) is malformed (three-colon URL) — disabled here; Gatus owns liveness
- Always-on API server: `apiAddr` pinned to `127.0.0.1:8085` (upstream default `:8080` collides with SigNoz)
- `discordsync-db-heal` and `discordsync-immich-verify` are indirect units (`is-enabled` rc=1) — deploy.sh carries failed-gated restarts for both

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### DiscordSync

- **Always-on API server** — Upstream ALWAYS starts HTTP API on `:8080` (conflicts with SigNoz). Override `apiAddr` to `127.0.0.1:8085`.
- **Event-store dump leg (2026-09-30, `dbBackup.enable = true` on evo-x2)**: `discordsync-db-backup` (02:30, Persistent, 30min budget, ioTier.background) runs an online `sqlite3 -readonly .backup` of `cfg.databasePath` + `gzip -1` → `/mnt/pool/backups/discordsync` (7d retention; mount-gated `discordsync-db-backup-dir` leaf, deploy.sh provisioner-restarted; registered in backup-coordination + the restic app-dumps repo). This is the dump-only RPO leg for the hot-db wave: once the DB leaves the btrbk `@` snapshot set and with the Turso sync free-plan blocked, this dump is the event store's ONLY backup. `-readonly` is load-bearing (root-owned -wal/-shm poisoning class, browser-history precedent).
- **Attachments are pool-native (2026-09-22, MIGRATION COMPLETE — 20.5 GB verified identical, NVMe source removed, API green)** — the 2026-09-21 Phase-2 re-scope of the Own-tools NVMe→pool leg moved ONLY the BLOBs: `services.discordsync.attachmentsDir = /mnt/pool/services/discordsync/attachments` (the attachment archive; the DB stays on NVMe — the Phase-2 hot-db wave owns it). The option wires: `ATTACHMENT_STORAGE_PATH` → the pool path, the mount-gated `discordsync-attachments-dir` leaf creator (provisioner-restarted), the service's `RequiresMountsFor` + `ReadWritePaths` pool gating (a detached DAS fails the service as a clean dependency — bank-sync pool-native precedent; `pool-recovery` converges it), and the one-time `discordsync-attachments-migrate` oneshot (STATIC unit — deploy.sh's dedicated no-block block starts it, the provisioner loop's is-enabled gate skips static units): stops discordsync, `rsync -aHAX --no-perms`, content-only checksum-verify, `rm -rf` source (rm, not trash — the blob bytes would write back onto the NVMe), restarts discordsync; ConditionPathIsDirectory makes every later run a clean skip. `null` (default) restores the legacy in-state `<dataDir>/attachments` layout incl. its tmpfiles rule — pool-less hosts/VMs are unaffected. **Bring-up lessons (2026-09-22, three failed migration runs before green): (1) `chmod 2770` (setgid) on a group outside the sandbox's groups EPERMs EVEN with CAP_FSETID in the bounding set — the dir-creator now does `chown root:root` → `chmod 0770` (no setgid — decorative anyway) → `chown user:group`, idempotent and cap-independent; (2) `rsync -a` mode-preservation hits the same class on every foreign-group dir — the migrate uses `--no-perms` on BOTH passes and tolerates perm-only rsync stderr (any non-"failed to set permissions" line still fails the copy; the verify pass filters itemized output to `^[><ch]` content-only lines); (3) the FSETID/sandbox setattr MECHANISM is unresolved (works as plain user on the same fs, fails as root+caps in the unit) — see the Systemd gotchas.**
- **API startup race (5-11 min)** — API binds after thumb-hash backfill. NEVER add `ExecStartPost` readiness gate — it crash-loops the service. Use Gatus (60s interval).
- **SQLite corruption self-heal** — `ExecStartPre` runs `PRAGMA integrity_check`; corrupt DB moved to `.corrupt-<timestamp>`. Re-syncs from Turso cloud.
- **Module consumption pattern** — `imports = [ inputs.X.nixosModules.default ]` + layer SystemNix specifics via `lib.mkMerge`. See Monitor365 as gold standard.
- **samber/do `InvokeNamed[Interface]` on concrete registrations is ALWAYS a startup-fatal (2026-08-16/18 outage)** — `do.InvokeNamed[T]` matches T against the registration's exact type parameter (stored wrapper is `serviceWrapper[T]`); an interface type NEVER equals a concrete `ProvideNamedValue` registration, even when the value implements it. DiscordSync rev `e71e8086` resolved its four named health checkers as `do.HealthcheckerWithContext` → every startup fataled `DI: service found, but type mismatch` → exit 69, delayed ~30 min by the thumb-hash livelock → Gatus red for 2 days, 404k `database is locked` errors, message loss via capture-DLQ write failures. Fixed upstream `085fa539` (invoke by concrete type + `TestInvokeHealthCheckServices_ResolvesNamedCheckers` guard). Diagnosis trick: a uniform ~30-min exit-69 cadence with `Consumed 29min 57s CPU` in systemd's unit log = startup-path livelock before the fatal; `API server stopped: http: Server closed` with the process STILL ALIVE = a shutdown that hung mid-exit (zombie — restart manually). Pocket ID SQLITE_BUSY spikes are collateral of discordsync IO storms on the same BTRFS filesystem.
- **Turso cloud sync DECISION-PENDING — local-first stance ENCODED (2026-09-11, task queue; live journal verified)** — the Turso free plan is hard-blocked since 2026-08-16: the journal logs `turso push failed … SQL read operations are forbidden (reads are blocked, do you need to upgrade your plan?) code: BLOCKED` on every push attempt (~5-min cadence; upstream circuit breaker trips after 5 consecutive failures → 1h backoff, live-verified 2026-09-11 08:34 — 167 failures/24h, so the noise is bounded, not literally every 5 min). The token AUTHENTICATES (an auth failure looks different), so **re-auth cannot fix this — the only paths are a user Turso plan upgrade or permanent local-only**. The module already encodes the superior local-first posture (`discordsync.nix`): `backend = "turso-sync"` + upstream `OpenTursoSync` quota fallback = fully local SQLite operation with AUTOMATIC cloud-resume the moment the plan is upgraded, whereas a bare `sqlite` backend would BOTH lose auto-resume AND cost a 40+ min startup backfill (FTS5 trigger contention, live-measured vs ~21 min). The Gatus "DiscordSync Turso Sync Active" check (`discordsync_turso_local_only_mode`) deliberately stays RED while local-only — that IS the standing stale-mirror signal; do not silence it. Sops keys (`discordsync_turso_url/auth_token`) stay declared for the auto-resume. Re-open as a task only when the user decides: upgrade (sync resumes on next service start, zero config change) or permanent local-only (then remove the TURSO_* env from the sops template + drop the Gatus check). The remaining WARNs (5 per attempt-run, then 1h silence via backoff) are upstream logging noise, harmless.
- **Capture-DLQ churn from cgroup OOM under a zram-full box (2026-09-02 incident)** — 13 `Failed with result 'oom-kill'` cycles in one afternoon (zero in the prior 3 days): with zram 100% full + flm's 24.6 GB unevictable model resident + a concurrent build storm stalling btrfs writeback, discordsync's cgroup filled to `MemoryMax=2G` with un-cleanable dirty page cache → kernel cgroup OOM kill every 7-25 min → in-flight appends dead-lettered → `/api/health/backup` critical (1927 capture-DLQ events). The DLQ did exactly its job (zero loss). **Runbook:** replay = `POST /api/capture-dlq/replay` on loopback :8085 (no auth key configured; INSERT OR IGNORE idempotent, batch of 1000 per call — loop until GET depth 0; entries survive a mid-replay kill). Projection DLQ replay needs the projection NAME (`POST /api/dlq/replay?projection=<name>`); the 2 legacy poison events (messages `no rows` on a parent-less message.updated, reactions FK-fail on a missing parent — 2026-08-16 loss-era orphans) fail deterministically on every replay and evaluate "ok" — do NOT purge them (they are the only record of the gap). **Trap: the API itself 503s while its DB is busy** (post-restart backfill window; body says "Service Busy"), and Gatus 60s checks flap green between kills — judge health by the journal/restart churn, not the endpoint check. Upstream fix shipped in DiscordSync (2026-09-02): `/api/dlq` list + dashboard DLQ view scanned TEXT `failed_at` into `time.Time` → every list request 503'd (`unsupported Scan`), dead letters unlistable since the endpoint shipped; now returns the raw stored string, regression-tested (`TestHandleDLQ_ListReturnsStoredFailedAtText`). The box-level fix is the reboot pending the 2026-09-02 zram 50% sizing, not anything in discordsync.
- **Immich cross-archive comparison (LIVE config 2026-09-19, key paste pending)** — `services.discordsync.immich.enable = true` wires the /lookup page's "Also check Immich" toggle (upstream ADR-062, in the locked rev `06a06b00`): the server proxies hex SHA-1 hashes to Immich's `bulk-upload-check` (`internal/immichclient`; key scoped to `asset.read` + `asset.upload` ONLY — the endpoint's permission guard demands `asset.upload` even though nothing is uploaded). `IMMICH_URL`/`IMMICH_API_KEY` are COLD config validated both-or-neither by the binary (`ErrImmichConfigIncomplete`); both ride the `discordsync-env` sops template, rendered ONLY when the option is on, with the URL defaulting to LOOPBACK `http://127.0.0.1:<ports.immich>` (co-located — no Caddy/DNS/TLS on the lookup path). **The key lives in its own encrypted file `discordsync-immich.yaml`** (split-file precedent): agent sessions can encrypt a NEW file with the public key but CANNOT add a key to `discordsync.yaml` (needs the host age identity; `sudo` is blocked in agent sandboxes). Ships PLACEHOLDER-inert; go-live = create the key in Immich UI → interactive `sops` edit of the yaml → deploy (runbook: docs/services/discordsync.md). `discordsync-immich-verify` (oneshot, daily timer, User=discordsync, reads the rendered template) is the misconfig pager: 401/403 from a REACHABLE Immich = exit 1 + OnFailure (wrong key/scope), while unreachable Immich = WARN skip exit 0 (availability is the Gatus Immich check's job — a down Immich must not double-page as a DiscordSync misconfig). In system-health `extraMonitoredServices`; template's `restartUnits` includes the verify unit CONDITIONALLY (restartUnits must never name a unit absent from the generation — the immich-disabled shape would fail activation).

