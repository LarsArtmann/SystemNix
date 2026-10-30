# media-atlas (federation hub)

**Service:** `modules/nixos/services/media-atlas.nix` — groundwork (v0.1 plan L11 + L03 enabler) PLUS the hub service (`services.media-atlas.hub.enable`, the L25 deploy; repo `~/projects/media-atlas`, forgejo-primary). Runbook source: media-atlas `docs/planning/2026-10-25_21-56_SUPERB-media-atlas-v0.1-build-plan.md` + `docs/deploy/flip-card.md`.

## What this deploys today

| Piece                       | What                                                                                                                                                                                                                                                                                                           |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `media_atlas` user + role   | Peer-auth principal: OS user == PG role, system user, no password (socket peer only; TCP stays password-gated)                                                                                                                                                                                                 |
| `media-atlas-pg-ro` oneshot | Root converger (discordsync-immich-key-provision pattern): `GRANT CONNECT/USAGE/SELECT` on the immich DB + `ALTER DEFAULT PRIVILEGES FOR ROLE immich` so future migrations stay readable; echoes the `smart_search` schema fingerprint + row count into the journal (Phase-0 evidence + `atlas doctor` anchor) |
| Immich archive read         | `immich` user joins the `discordsync` group (DAC read on `attachments/`, `drwxrwx---`) + `BindReadOnlyPaths` on `immich-server` (namespace-level RO) + `RequiresMountsFor` (mount-gated, 226 class) — DiscordSync ADR-061 external-library runbook                                                             |

## The hub service (`hub.enable`)

| Piece                       | What                                                                                                                                                                                                                                                                                                                               |
| --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `media-atlas` service       | `atlas serve` as `media_atlas`, loopback `:8493` (`ports.media-atlas`), `StateDirectory=media-atlas` (0750), `harden{}` + `ioTier.background`, journal on the pool QLC root                                                                                                                                                        |
| `media-atlas-key-provision` | Root converger (discordsync-immich-key-provision pattern): mints the INBOUND hub key (`hub-api-key`) once and the OUTBOUND Immich key (`immich-key`, api_key row `media-atlas-hub (nix-managed)`, scopes `asset.read asset.view asset.statistics tag.read library.read`), file-first reconcile, `try-restart`s the hub on rotation |
| vHost `map.home.lan`        | Registry entry, **plain layer** — the hub's own single API key gates `/api`, `/events`, `/thumb` (OQ-5); caddy-side auth would double-gate. TLS-only at caddy                                                                                                                                                                      |
| Gatus                       | `/health/ready` 30s + functional plate check (`Map · MediaAtlas` title) 60s, Discord alert on failure                                                                                                                                                                                                                              |
| Dashboard tile              | "MediaAtlas", group Media, photoprism icon (no atlas glyph in the pack)                                                                                                                                                                                                                                                            |
| `media-atlas-poll-embeddings` | Nightly 02:00 (+30m random, `hub.pollEmbeddings.*`): idempotent smart_search diff poll as the `media_atlas` peer-auth user; failure toasts                                                                                                                     |
| `media-atlas-umap`          | Nightly 03:00 (+30m random, `hub.umapNightly.*`): export → `umap-fit --mode auto` (persistent model, straggler transform) → `project-coords --run <date>`; IO/CPU-quiet knobs from the repo's reviewed shape (Nice 19, idle IO, MemoryMax 2G); failure toasts                                                                    |
| `media-atlas-lane-join`     | Nightly 04:00 (+30m random, `hub.laneJoin.*`): `atlas pull --with-lanes` (full walk — the tag walk needs the API key), order-only `after` the refit, own failure domain; BE/6 background, MemoryMax 512M; failure toasts                                                                                                        |

### Deploy sequence (owner, IO-quiet window)

1. Seed the production journal FIRST, from the hub repo: `docs/deploy/flip-card.md` (stage + `sudo -u media_atlas` embeddings join + metadata join). The service's `StateDirectory` is the same `/var/lib/media-atlas` the flip card stages, so the seeded journal becomes the live store.
2. Re-lock the input to the intended rev: `nix flake lock --update-input media-atlas` (branch-tracked; the lock is the pin — the repo's auto-commit daemon lands commits continuously, so never eval a moving tip un-reviewed).
3. `nix run .#deploy` (the provisioner loop re-converges keys; the hub unit starts after `media-atlas-key-provision` via `requires`).
4. Verify: gatus tile green + `atlas` plate at `https://map.home.lan` with the hub key.

### Ops

- **Key rotation** — hub key: `rm /var/lib/media-atlas/hub-api-key && systemctl restart media-atlas-key-provision` (mints + restarts the hub). Immich key: same with `immich-key`; the file-first reconcile re-inserts the row from the file plaintext on DB restore.
- **Legacy key cleanup** — the interactive 2026-10-29 mint (`media-atlas-hub (nix-managed pending L25)`) is superseded by the provisioner's row; delete it in the Immich UI after the first provisioned deploy.
- **Nightly timers** — LANDED 2026-10-29 (the repo's `docs/deploy/umap-nightly-timer.nix` shape lifted onto the flake outputs): `hub.pollEmbeddings.enable` (02:00 diff poll) + `hub.umapNightly.enable` (03:00 UMAP refit, `wants+after` the poll so a missed poll re-runs before the fit); both `Persistent=true` and enabled on evo-x2. The UMAP unit consumes the `umap-fit` flake app from the same rev-pinned input as the `atlas` package. **Lane-join LANDED 2026-10-30**: `hub.laneJoin.enable` (04:00 `atlas pull --with-lanes`) after the hub's merge-fold contract was pinned upstream (go-codec v0.3.3 + the `TestJoinLanes_LaneJoinPreservesEmbeddingAndCoords` pin) — order-only `after` the refit, own failure domain, coords/embeddings survive the join.

## Ops (groundwork)

- **Converger contract** — role creation is guarded, all grants idempotent; re-runs (every deploy via the provisioner loop, plus boot) converge. Missing `smart_search` is a WARN (Immich's ML toggle), never a grant failure.
- **External library** — the Immich library object itself is created via Immich's API (media-atlas plan L03; runbook: DiscordSync `docs/runbook/immich-external-library.md`), with the runbook's exclusion globs (`**/*.gz`, `**/*.zst`, `**/*.thumb.jpg`, `**/*.poster.jpg`). First scan runs in the IO-quiet window.
- **Hub read path** — the hub reads embeddings via this role (`smart_search`) and metadata via Immich's REST API; it never writes to the immich DB and never touches the archive filesystem directly (Immich owns ingestion).

## Backup

The hub's SQLite journal lives in `StateDirectory /var/lib/media-atlas` (pool QLC root). Backup policy rides the pool's existing snapshot cadence; a dedicated freshness check lands with the v0.1 follow-up (journal is rebuildable from Immich — it is a derived store, RPO = re-pull).
