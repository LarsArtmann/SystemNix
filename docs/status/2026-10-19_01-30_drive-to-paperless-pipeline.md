# Drive → Paperless pipeline: google-sync pre-work closed, drive-paperless module shipped, go-live reduced to ONE flip

**Session:** 2026-10-19 ~00:5x → 01:4x CEST
**Task evolution:** "get all my Google Drive data into paperless-ngx, especially PDFs and business documents, from a small Workspace account (5-30 GB) and ~1.9 TB private Drive" → discovery: paperless-ngx LIVE since 2026-08, `services.google-sync` (rclone mirror of exactly these three remotes) built 2026-08-18 but DORMANT behind user OAuth, the queued pre-work row gated on go-live intent (now answered YES) → **ship the missing ingest pipeline + execute all agent-side pre-work + reduce the user's go-live to a single enable flip.**

## a. Shipped

| # | Artifact | Evidence |
|---|----------|----------|
| a1 | `modules/nixos/services/drive-paperless.nix` — new module: hourly Persistent oneshot, scans google-sync mirror defaults 1:1, document-extension filter, DRF-API upload with atomic metadata, journal idempotence, batch cap, fail-loud + freshness row | isolated nixosSystem evals green; all fixture legs green |
| a2 | `scripts/test-drive-paperless.sh` + `checks.x86_64-linux.drive-ingest-fixture` (flake/parts/checks/fixtures-drive-ingest.nix, imported in flake.nix) — 6 legs + eval pins | built + ran green (standalone replica; see §d for why not via `.#checks`) |
| a3 | `configuration.nix` — dormant coupled block: `google-sync.enable = false; drive-paperless.enable = config.services.google-sync.enable;` | one-flip go-live |
| a4 | Runbooks: google-sync.md ingest section (semantics, gotchas, monitoring), paperless.md incoming-import section | docs committed |
| a5 | TODO harvest: services.md pre-work row CLOSED (all 4 items done), go-live row (blocked:user), VM-test row (ready); TODO_LIST queue: 3 rows; CHANGELOG entry | §f self-harvest below |

## b. Design decisions (READ → RESEARCH → REFLECT trail)

1. **API upload, not the consume dir.** `POST /api/documents/post_document/` accepts correspondent/tags/title/created as multipart fields — **verified by reading the pinned paperless-ngx 3.3.1 source** (`src/documents/views.py` PostDocumentView + `serialisers.py` PostDocumentSerializer + `filters.py` CHAR_KWARGS `name__iexact`), not from docs/memory. The consume dir would need global `PAPERLESS_CONSUMER_RECURSIVE` + `SUBDIRS_AS_TAGS` flips that change semantics for every other consumer.
2. **Token: bank-sync-paperless runtime mint** (`drf_create_token` get_or_create as the paperless user, `/run/drive-paperless/env` tmpfs, `+`-prefixed root chown handover, `RuntimeDirectoryPreserve=true`) — zero sops, zero manual steps, convergent.
3. **Idempotence:** append-only journal `source TAB relpath TAB size`; size change (new Drive revision synced by rclone) re-uploads; paperless server-side sha256 dedup makes cross-account/cross-folder duplicates cost one rejected task.
4. **Storm discipline** (this box's PSI-freeze history): batch 200/run + hourly timer + `ioTier.background` + `TimeoutStartSec=30min`; a 1.9 TB tree can be six-digit files.
5. **Images OFF by default** (`ingestImages` option): photos belong in Immich; a photo-heavy Drive would flood the archive. Takeout ZIPs/videos extension-skipped; Google-native Docs arrive as real PDFs via the mirror's existing `--drive-export-formats pdf`.
6. **Coupled enable:** sources DEFAULT from `services.google-sync.mirrors` when in scope — the user flips exactly one switch.

## c. Live findings encoded (the fixtures earned their keep)

1. **`inherit_errexit` hole (module bug caught by fixture):** with bash's default, API failures inside `$( )` don't propagate — a dead paperless would have uploaded documents with EMPTY correspondent/tags silently. `shopt -s inherit_errexit` now in the script; proven by the broken-stub leg.
2. **rclone 1.75 `listremotes` hides sections without `type = drive`** — fixture INI with bare sections returned EMPTY list (rc=0); with `type = drive` all three remotes list. The go-live checklist + runbook now demand `type = drive` per section in the sops scaffold.
3. **`optionalAttrs (options ? …)` guards do NOT survive mkIf push-down** (documented integration.nix trap, re-proven on my own module + google-sync + backup-coordination in isolation): the freshness row is now UNGUARDED like google-sync's, and every fixture eval co-imports backup-coordination + integration.
4. **Nix indented-string `''` terminator:** bash `read -r -d ''` inside `''...''` terminates the Nix string — escaped as `'''` (parse-caught before any eval).
5. **Pipeline-subshell counter loss:** `find | while` forks the loop and drops uploaded/failed counters — process substitution `< <(find …)` instead.
6. **Pre-work row fully closed:** pool free-space live-verified **12 TB avail** (≥2 TB requirement); rclone 1.75.2 flags (`--drive-skip-checksum-gphotos`, `--drive-export-formats`, `--fast-list`) verified via `rclone help backend drive` + version; config-check fail-fast now FIXTURE-tested (stronger than the planned VM test: real rclone parse legs).

## d. Verification state (honest boundaries)

- **Standalone fixture: GREEN** — replicated the check as an isolated expression (`~/.cache/drive-paperless-dev/standalone-check.nix`, direct module-file imports, locked-nixpkgs nixosSystem) because **`nix build .#checks…` / evo-x2 toplevel eval / `nix flake check` are repo-wide RED from the parallel go-standard break** (`go.mod requires go 1.27.2 but the resolved toolchain is 1.27.1` — queued by the metricnames session, docs/todo/pipeline.md:14, NOT touched by this session; every perSystem attr forces it). The committed check will run green once that clears — it evaluates isolated nixosSystems and never touches the evo-x2 graph.
- **evo-x2 toplevel with the new module: NOT evaluable this session** (same break). The module's unit shapes are pinned by the fixture's eval-side asserts (ordering, requires, RequiresMountsFor, port-derived URL, user, timer, mint handover, RuntimeDirectoryPreserve).
- **shellcheck:** module script (inside writeShellApplication at build) + test script (manual run) — both clean. `nix fmt` ran (9 files canonicalized; 6 foreign files were left unformatted by parallel sessions — formatter output kept per AGENTS.md).
- **sops scaffold** `platforms/nixos/secrets/google-sync.yaml` present (2026-08-18 3-remote layout, placeholder).

## e. USER go-live (the only remaining path to live data)

1. Google Cloud OAuth client, Drive API enabled, publishing status **"In production"** (testing-mode refresh tokens die after 7 days).
2. `rclone authorize "drive"` per account: **gdrive** (private ~1.9 TB), **gdrive-shared** (own remote, `shared_with_me = true`), **gwork** (Workspace; `team_drive = <id>` only if data lives on a shared drive).
3. Fill all three sections in `sudo sops platforms/nixos/secrets/google-sync.yaml` — **keep `type = drive` per section** (see §c.2).
4. Flip `services.google-sync.enable = true` (platforms/nixos/system/configuration.nix — drive-paperless rides the same flip) + `nix run .#deploy` (after the go-standard break clears).
5. Verify: mirror seed (`journalctl -u google-sync -f`, 48h budget, `/mnt/pool/backups/google-drive*`), then hourly ingest (`journalctl -u drive-paperless`) — expect a LONG paperless OCR/AI consumption tail; watch paperless_tasks + the ingest freshness alerting.

## f. Self-harvested follow-ups (landed in TODO_LIST + docs/todo/services.md at authoring time)

1. **[ready] drive-paperless end-to-end VM test** (real DRF, not stubs; test-paperless.nix co-import pattern) — f.1 row in queue + services.md.
2. **[ready] Post-deploy battery for the go-live flip** (timers render, token mint result=success, first journal lines, backup_all_healthy row) — f.2 row.
3. **[blocked:user] the go-live itself** (§e) — queue + services.md row.

## g. Session-discipline notes

- Daemon heuristic commits `a454aa34e` + `2cbde1b6a` swept this session's in-flight files; **not amended** — 2cbde1b6a also carries a foreign deletion (`scripts/metric-sweep-expected-absent.txt`, metricnames session) and amending would absorb it. Pre-commit filetype legs may have been bypassed for the .sh files → shellcheck re-run manually (clean).
- The `nix fmt` canonicalization touched 6 foreign scripts (metric-*, negative-test-lints, plan-marker, test-hermes-*) — formatter output left in place per the AGENTS.md churn doctrine.
- No secrets, no deploys, no remote pushes. Throwaway eval/fixture artifacts under `~/.cache/drive-paperless-dev/` (not /tmp — volatility rule).
