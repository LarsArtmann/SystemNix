# pim-sync (Google People ↔ Stalwart CardDAV contacts sync) — Agent Notes

> Module: `modules/nixos/services/pim-sync.nix` (thin wrapper around upstream `inputs.pim-sync.nixosModules.default`). Upstream repo: `github:LarsArtmann/pim-sync` (PRIVATE, git+ssh input, ref-tracked `refs/heads/master`, lock-pinned — monitor365/media-atlas pattern).

## State: flip-ready DISABLED (2026-11-04); sops scaffold LANDED (2026-11-10)

`services.pim-sync.enable = false` in `platforms/nixos/system/configuration.nix` (dormant cluster, audible-sync precedent). The wrapper pre-wires everything that is safe to pre-wire: the package pin, OnFailure routing, the integration entry (`monitored`, headless — no vHost/subdomain/port/tile), and the unconditional catalog entry. Nothing else exists at enable=false (upstream config is entirely `mkIf cfg.enable` — zero eval footprint).

**2026-11-10 sops scaffold:** the full secret wiring landed as PLACEHOLDER (audible-sync precedent) — `platforms/nixos/secrets/pim-sync.yaml` holds 7 keys (`pim_sync_oauth_client_secret`, `pim_sync_token_{personal,work}{,_calendar}`, `pim_sync_stalwart_dav_{user,pass}`); the wrapper renders the DAV env template, points `secretFile`/`environmentFile`/`tokenSeedDir` (`/var/lib/pim-sync-seed`, per-secret rendered paths in sops.nix) and adds a config-check ExecStartPre that fails loudly with this checklist while any placeholder remains. **Enabling with placeholders is still forbidden** (alert storm) — the owner paste below is the gate.

**Why disabled:** upstream has NO idle no-op — `discoverAccounts` errors on an empty tokensDir (`cmd/pim-sync/sync.go:359`), so an enabled unit without token files fails every 5 min and rides OnFailure into an alert storm (plus the failed-unit exit-4 deploy trap, dmarc-monitor class).

## Flip ladder (owner-gated — plan: docs/planning/2026-11-04_19-35_pim-sync-systemnix-integration-wave.md)

1. 🧑 **Owner gates** (values into the landed scaffold — sops editor, never a command line):
   - GCP OAuth client secret JSON (publishing mode "In production" — testing-mode tokens die after 7 days, the InboxClean lesson) → `pim_sync_oauth_client_secret`. Path contract: `~/projects/pim-sync` `docs/oauth-setup.md` §2.
   - Stalwart DAV creds — dedicated `bot:pim-sync` account (or app password) on `pbx.artmann.tech`, never the owner login → `pim_sync_stalwart_dav_user` / `pim_sync_stalwart_dav_pass`.
   - Per-account consents (client JSON must land first): run in the owner's terminal
     `mkdir -p ~/.config/pim-sync-tokens && PIMSYNC_SECRET=<downloaded-client-json> PIMSYNC_TOKENS_DIR=~/.config/pim-sync-tokens nix run ~/projects/pim-sync#pim-sync -- auth --account personal` (repeat `work`, plus `--calendar` variants) → the agent ingests the 4 token JSONs into `pim_sync_token_*` (runtime-variable expansion, never inline).
2. **agent**: wire sops — DONE 2026-11-10 as the placeholder scaffold (environmentFile template / secretFile / tokenSeedDir + config-check). Remaining at flip: set `enable = true`, keep `live = false` (dry-run timer) → deploy → first dry-run journal review 🧑 (Stalwart-single-truth plan §7.5 gate).
3. 🧑 **GO** → **agent**: `live = true` + `maxChanges` cap + `metricsFile` textfile wiring + Gatus freshness check on `pimsync_leg_last_success_unix{leg,account}` (anchored-pat doctrine; dry-run never settles it — 0 = never — hence deferred to this step). Textfile dir precedent: `btrfs-health.nix` (`/var/lib/prometheus-node-exporter/textfile_collectors`); metrics file is mode 0600 owned by the service user — collector readability needs the shared-group pattern from that precedent.
4. Real Twenty import stays its own owner gate (docs/todo/services.md).

## Mesh invariants (2026-11-13 review)

Verified against the pim-sync source at the locked rev; the review is
`docs/architecture-understanding/2026-11-13_11-45_contacts-data-architecture.html`.

- **One book per source.** A full Google listing quarantines every book card
  absent from it, explicitly including foreign and hand-made cards
  (`internal/contactsin/quarantine.go:45`). Never merge two sources into one
  book, and never share a book across accounts: `--book` applies to *every*
  account in one invocation (`cmd/pim-sync/account.go:169-172`).
- **The cap is live even in dry-run, and defaults to 50.** A first run against
  a fresh book projects more creates than the cap and aborts with exit 3
  without `--live` (`internal/guard/guard.go:80-100`,
  `cmd/pim-sync/sync.go:30`). Read the projected count from the dry-run report,
  then set `maxChanges` above it for the first live run.
- **`--live` without an explicit cap is refused** (fail-closed, `ErrNoCap`);
  `--clear-deletion` is the only way a held deletion may propagate, keyed
  `contact:<uid>` / `event:<iCalUID>`.
- **Dry-runs leave nothing behind.** No state mutation, no receipt; the report
  goes to stdout and is not persisted (`cmd/pim-sync/report.go:10-45`). The
  only durable per-run record is the overwritten `last_report` in each
  account's state file. There is no per-change audit ledger yet.
- **Run `pim-sync doctor` before the first flip.** It exists
  (`cmd/pim-sync/doctor.go:16-45`, registered at `main.go:44`), checks token
  shapes, state dir and DAV books, and deliberately makes no Google API call;
  it has not yet run against real credentials.
- **One DAV endpoint and one Stalwart credential pair.** Multiple Google
  accounts are token stems (`personal`, `work`) processed sequentially; there
  is no second CardDAV server option. Do not add one.
- **No merge engine.** Duplicates are reported, conflicts are counted but not
  queued for review, and nothing auto-merges (`README.md:138`,
  `docs/CONTRACT.md:63-65`).
- **The model is lossy by design.** Only FN/first/last, one email, org and
  indexed phones cross the seam (`internal/personcard/personcard.go:44-50`);
  addresses, birthdays, notes, photos and extra emails live in the vCard but do
  not participate in field merge.
- **Metrics carry `{leg,account}` only** — five gauges
  (`changes`, `conflicts`, `quarantined`, `quarantine_depth`,
  `last_success_unix`), no `source`/`book` label
  (`internal/metrics/metrics.go:169-193`). README lists four (drift).
- **Twenty import is one-way into its own book** (`Twenty import`,
  `twenty:`-scoped UIDs); the 139-row rehearsal ran against an in-memory fake
  CardDAV server, not the production book.

## Gotchas

- **Package pin lives in the wrapper** (`services.pim-sync.package = inputs.pim-sync.packages.x86_64-linux.default`) because upstream's `package` option has NO default (bank-sync/index pattern). Do not "fix" it to a mkPackageOption — nixpkgs has no pim-sync attr.
- **Token rotation**: `tokenSeedDir` seeds ONLY empty slots; once the service refreshes a token, `/var/lib/pim-sync/tokens` owns it (sops is the seed, never the runtime store — the 7-day-rotation lesson).
- **Kill switch**: `systemctl disable --now pim-sync.timer` stops everything; nothing else runs on its own.
- **vendorHash**: upstream's FOD was measured against its own nixpkgs pin; SystemNix follows nixpkgs (root pin, go 1.27.3 ≥ upstream floor 1.27.2). If a future nixpkgs bump invalidates the hash: fix UPSTREAM first (fresh hash into upstream flake.nix), downstream `overrideAttrs` shim only as documented interim (drift-treadmill doctrine).
- Infra follows (flake.nix): `flake-parts`, `go-nix-helpers` (+ deep `go-nix-helpers.inputs.treefmt-nix`), `nixpkgs` — the deep edge kills pim-sync's nested treefmt copy (deep-treefmt audit leg; journal/papdashboard precedent).
