# media-atlas (federation hub — groundwork)

**Service:** `modules/nixos/services/media-atlas.nix` — groundwork only (v0.1 plan L11 + L03 enabler; repo `~/projects/media-atlas`). The hub binary, port, `map.local` vHost, and gatus check land with the L25 deploy PR. Runbook source: media-atlas `docs/planning/2026-10-25_21-56_SUPERB-media-atlas-v0.1-build-plan.md`.

## What this deploys today

| Piece                     | What                                                                                                                      |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `media_atlas` user + role | Peer-auth principal: OS user == PG role, system user, no password (socket peer only; TCP stays password-gated)             |
| `media-atlas-pg-ro` oneshot | Root converger (discordsync-immich-key-provision pattern): `GRANT CONNECT/USAGE/SELECT` on the immich DB + `ALTER DEFAULT PRIVILEGES FOR ROLE immich` so future migrations stay readable; echoes the `smart_search` schema fingerprint + row count into the journal (Phase-0 evidence + `atlas doctor` anchor) |
| Immich archive read       | `immich` user joins the `discordsync` group (DAC read on `attachments/`, `drwxrwx---`) + `BindReadOnlyPaths` on `immich-server` (namespace-level RO) + `RequiresMountsFor` (mount-gated, 226 class) — DiscordSync ADR-061 external-library runbook |

## Ops

- **Converger contract** — role creation is guarded, all grants idempotent; re-runs (every deploy via the provisioner loop, plus boot) converge. Missing `smart_search` is a WARN (Immich's ML toggle), never a grant failure.
- **External library** — the Immich library object itself is created via Immich's API (media-atlas plan L03; runbook: DiscordSync `docs/runbook/immich-external-library.md`), with the runbook's exclusion globs (`**/*.gz`, `**/*.zst`, `**/*.thumb.jpg`, `**/*.poster.jpg`). First scan runs in the IO-quiet window.
- **Hub read path** — the hub reads embeddings via this role (`smart_search`) and metadata via Immich's REST API; it never writes to the immich DB and never touches the archive filesystem directly (Immich owns ingestion).

## Backup

None yet (no state). The hub's own SQLite store + its pool backup land with L25.
