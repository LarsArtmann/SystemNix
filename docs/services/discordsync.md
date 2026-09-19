# DiscordSync — Runbook

Discord backup bot (messages, attachments, reactions) — SystemNix wrapper around the upstream `nixosModules.default` (`inputs.discordsync`). Dashboard at `discordsync.home.lan` (Layer 2 protected vHost), API on loopback `127.0.0.1:8085` (`ports.discordsync-api`).

## Units

| Unit                     | Shape                                                    | Notes                                                                        |
| ------------------------ | -------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `discordsync.service`    | long-running daemon, `harden{}` + 2G / GOMEMLIMIT 1536MiB | API + Discord gateway; env from the `discordsync-env` sops template           |
| `discordsync-db-heal.service` | oneshot + RemainAfterExit, `+`-privileged           | SQLite integrity check → `.recover` → BTRFS snapshot restore cascade (10min) |
| `discordsync-immich-verify.service` | oneshot, daily timer, User=discordsync         | Verifies the Immich API key (see below); OnFailure pages                     |

## Secrets

`discordsync-env` (sops template, owner `discordsync`, 0400): `DISCORD_TOKEN`, `TURSO_URL`, `TURSO_AUTH_TOKEN`, `DISCORDSYNC_WEBHOOK_URL`, and — when `services.discordsync.immich.enable` — `IMMICH_URL` + `IMMICH_API_KEY`. Raw values live in `platforms/nixos/secrets/discordsync.yaml` and `discordsync-immich.yaml`.

**sops edits run as your user** with the SOPS_AGE_KEY one-liner (AGENTS.md, Sops + Age section). Plain `sudo sops` FAILS (root has no age identity).

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

| Exit | Meaning                                                                           | Action                                            |
| ---- | --------------------------------------------------------------------------------- | ------------------------------------------------- |
| 0    | key verified / PLACEHOLDER / integration off / **Immich unreachable**             | none (Immich availability is the Gatus Immich check's job) |
| 1    | Immich reachable but **rejected the key** (HTTP 401/403 — wrong secret or scope)  | OnFailure Discord alert; fix key/scope, redeploy  |

Rotation: repeat steps 2–3 (or just restart the verify unit after `sops --set` — the template's `restartUnits` already covers it).

## Monitoring

- Gatus "DiscordSync" (`/healthz`, 60s) — liveness after the thumb-hash backfill
- Gatus "DiscordSync Legacy DLQ Stable" + "DiscordSync Turso Sync Active" (the Turso check is DELIBERATELY RED while the cloud mirror is paused — local-first stance, do not silence)
- `discordsync` in system-health `monitoredServices`; `discordsync-immich-verify` in `extraMonitoredServices` (daemon-less → OnFailure + state metrics, github-auto-assign pattern)
- Prometheus mirrors (M07) live upstream in DiscordSync's `monitoring/alerts.yml`; DB-growth and sync-failure-count alerts stay Prometheus-only by design

## Turso sync state

`backend = "turso-sync"` + upstream quota fallback: the free plan's `BLOCKED` read error flips the service to fully-local SQLite with cloud sync disabled (journal `turso_local_only_mode`), resuming automatically on plan upgrade. Never "fix" the red Gatus check — it IS the standing stale-mirror signal.

## Known traps

- Upstream `healthCheck` (ExecStartPost readiness gate) is malformed (three-colon URL) — disabled here; Gatus owns liveness
- Always-on API server: `apiAddr` pinned to `127.0.0.1:8085` (upstream default `:8080` collides with SigNoz)
- `discordsync-db-heal` and `discordsync-immich-verify` are indirect units (`is-enabled` rc=1) — deploy.sh carries failed-gated restarts for both
