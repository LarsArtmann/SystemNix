# pim-sync (Google People ↔ Stalwart CardDAV contacts sync) — Agent Notes

> Module: `modules/nixos/services/pim-sync.nix` (thin wrapper around upstream `inputs.pim-sync.nixosModules.default`). Upstream repo: `github:LarsArtmann/pim-sync` (PRIVATE, git+ssh input, ref-tracked `refs/heads/master`, lock-pinned — monitor365/media-atlas pattern).

## State: flip-ready DISABLED (2026-11-04)

`services.pim-sync.enable = false` in `platforms/nixos/system/configuration.nix` (dormant cluster, audible-sync precedent). The wrapper pre-wires everything that is safe to pre-wire: the package pin, OnFailure routing, the integration entry (`monitored`, headless — no vHost/subdomain/port/tile), and the unconditional catalog entry. Nothing else exists at enable=false (upstream config is entirely `mkIf cfg.enable` — zero eval footprint).

**Why disabled:** upstream has NO idle no-op — `discoverAccounts` errors on an empty tokensDir (`cmd/pim-sync/sync.go:359`), so an enabled unit without token files fails every 5 min and rides OnFailure into an alert storm (plus the failed-unit exit-4 deploy trap, dmarc-monitor class).

## Flip ladder (owner-gated — plan: docs/planning/2026-11-04_19-35_pim-sync-systemnix-integration-wave.md)

1. 🧑 **Owner gates**: GCP OAuth client secret (publishing mode "In production" — testing-mode tokens die after 7 days, the InboxClean lesson) + Stalwart DAV creds (`PIMSYNC_DAV_USER`/`PIMSYNC_DAV_PASS`) + per-account browser-consent tokens. Path contract: `~/projects/pim-sync` `docs/oauth-setup.md`. sops declarations land ONLY together with the values (sops-key-audit throws on declared-but-missing keys).
2. **agent**: wire sops (`environmentFile`/`secretFile`/`tokenSeedDir`), set `enable = true`, keep `live = false` (dry-run timer) → deploy → first dry-run journal review 🧑 (Stalwart-single-truth plan §7.5 gate).
3. 🧑 **GO** → **agent**: `live = true` + `maxChanges` cap + `metricsFile` textfile wiring + Gatus freshness check on `pimsync_leg_last_success_unix{leg,account}` (anchored-pat doctrine; dry-run never settles it — 0 = never — hence deferred to this step). Textfile dir precedent: `btrfs-health.nix` (`/var/lib/prometheus-node-exporter/textfile_collectors`); metrics file is mode 0600 owned by the service user — collector readability needs the shared-group pattern from that precedent.
4. Real Twenty import stays its own owner gate (docs/todo/services.md).

## Gotchas

- **Package pin lives in the wrapper** (`services.pim-sync.package = inputs.pim-sync.packages.x86_64-linux.default`) because upstream's `package` option has NO default (bank-sync/index pattern). Do not "fix" it to a mkPackageOption — nixpkgs has no pim-sync attr.
- **Token rotation**: `tokenSeedDir` seeds ONLY empty slots; once the service refreshes a token, `/var/lib/pim-sync/tokens` owns it (sops is the seed, never the runtime store — the 7-day-rotation lesson).
- **Kill switch**: `systemctl disable --now pim-sync.timer` stops everything; nothing else runs on its own.
- **vendorHash**: upstream's FOD was measured against its own nixpkgs pin; SystemNix follows nixpkgs (root pin, go 1.27.3 ≥ upstream floor 1.27.2). If a future nixpkgs bump invalidates the hash: fix UPSTREAM first (fresh hash into upstream flake.nix), downstream `overrideAttrs` shim only as documented interim (drift-treadmill doctrine).
- Infra follows (flake.nix): `flake-parts`, `go-nix-helpers` (+ deep `go-nix-helpers.inputs.treefmt-nix`), `nixpkgs` — the deep edge kills pim-sync's nested treefmt copy (deep-treefmt audit leg; journal/papdashboard precedent).
