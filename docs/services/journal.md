# journal (accounting kernel CLI)

**Not a service.** `journal` is an interactive CLI (no daemon, no port, no `services.integration` registry entry, no vHost, no Gatus check — deliberately). Double-entry bookkeeping kernel: chart of accounts, immutable journal, bank reconciliation against invoices, period close with gates, VAT determination. Upstream: `github:LarsArtmann/journal` (**PRIVATE** — CI deploy key `NIX_DEPLOY_KEY_JOURNAL`, read-only key id 166885168, wired in all four workflows' auth blocks). Consumes bank-sync's `transactions.v1` exports; feeds `postings.v1` to future reporting.

## Integration surfaces

| Surface                 | Where                                                                                          | Notes                                                                                                                       |
| ----------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| flake input             | `flake.nix` (`journal`, `?ref=refs/heads/master` master-tracking float)                         | github: URL; nix falls back to `git+ssh` for the private fetch (cv/crm pattern)                                             |
| lock follows            | infra-follows group: `flake-parts` follows root; deep `go-nix-helpers.inputs.treefmt-nix` too  | `nixpkgs` + `go-nix-helpers` deliberately NOT followed — `lib/lock-audit.nix` `deliberate` entry ("journal.nixpkgs")        |
| package                 | `lib/lars-packages.nix` (`flakePkg inputs.journal`) → `nix build .#journal`                     | Non-follower class: builds under its OWN nixpkgs (go 1.27.2 floor) + own go-nix-helpers — upstream's baked vendorHash governs |
| PATH (both hosts)       | `platforms/common/packages/base.nix` `attrValues larsPackages`                                 | Lands in `environment.systemPackages` on evo-x2 AND the MacBook (darwin package exists)                                     |
| pre-deploy §11 batch    | `quick-go` (`flake/parts/packages.nix`)                                                        | journal rides the FOD-preview batch automatically via mkLarsPackages                                                        |
| CI auth                 | `NIX_DEPLOY_KEY_JOURNAL` in nix-check (2 jobs), flake-update, go-deps-audit, negative-tests     | Its lock's only OTHER private node is `go-cqrs-lite` (existing `NIX_DEPLOY_KEY_GO_CQRS_LITE` covers it)                     |
| nightly GoBD backup     | `modules/nixos/services/journal-backup.nix` (`services.journal-backup`, enabled in configuration.nix) | The deployment-owned piece the journal repo's month-end runbook assigns to NixOS: `journal-backup.timer` 03:30 + 10m jitter, `Persistent`, oneshot as the primary user, `ReadWritePaths = ~/books` only, `onFailure` toast. Append-only `backups/journal-$(date +%F).db` with `--verify` (doctor battery on the copy); a missing books dir is a `ConditionPathExists` clean skip |

## Ops

- **Books home: `~/books/` (evo-x2, live 2026-10-23).** `journal.yaml` (the two real entities + all 7 in-scope Wise balance mappings + matcher settings + `export.account_map: skr04-technologies.yaml`), `journal.db` (initialized: both charts imported — technologies 18 accounts, holding 9 with the expected VAT role-gap warnings), `chart-*.yaml`, `skr04-technologies.yaml`, `entries/`, `exports/`, `out/`, `backups/`. Still USER data: nothing under `/var/lib`, no backup-coordination row. The config's `database: journal.db` is CWD-relative (`config.AbsoluteDatabase` → `filepath.Abs`) — always run the CLI with CWD = `~/books` (the month-end runbook's `$J` alias assumes exactly that).
- **Nightly backup is deploy-owned** (`journal-backup.timer`, see table). Pre-close and ad-hoc backups stay manual: `journal backup --out backups/journal-<name>.db --verify`. Health: `journal doctor` (SQLite integrity, event journal, read models) + `journal status` (queue depths, AR residual, closed periods). The month-end rhythm lives upstream: `~/projects/journal/docs/runbooks/month-end.md` (bank-sync exports → import → reconcile → close → DATEV).
- **vendorHash drift class**: NON-FOLLOWER — root nixpkgs bumps CANNOT re-hash journal's FOD (its own nixpkgs pin governs the go toolchain). It re-stales only when journal's own lock moves; upstream pushes genuinely fix it (crm class), so re-lock + probe, never a consumer-side shim: `nix build github:LarsArtmann/journal/<rev>#default` first (probe-before-lock), then `nix flake lock --update-input journal`.
- **License**: proprietary ("All rights reserved") — upstream's flake builds it under its own `allowUnfree` nixpkgs instance (Zlota44 pattern); consuming the built package needs no unfree allowlist downstream.
- **Dev** (outside Nix): Go 1.27+, `GOEXPERIMENT=jsonv2`, `GOPRIVATE=github.com/larsartmann/*,github.com/LarsArtmann/*` — see the repo's own AGENTS.md.

## Related

- [bank-sync.md](./bank-sync.md) — upstream transaction facts (transactions.v1 exports)
- [go-ecosystem.md](../agents/go-ecosystem.md) — deploy-key recipe, non-follower doctrine, vendorHash protocol
