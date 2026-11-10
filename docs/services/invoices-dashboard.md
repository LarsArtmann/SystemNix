# invoices-dashboard (invoice CLI + read-model dashboard)

**Deployed as the invoices-dashboard unit + protected vHost (2026-11-10).** `invoices` is the billing CLI (invoice/solcom/importallocations with `--db`) plus `invoices dashboard`, a read-model web UI over the invoice SQLite DB (`modules/nixos/services/invoices-dashboard.nix`): binds **127.0.0.1:8110 BY UPSTREAM DESIGN** (`ports.invoices-dashboard`; internal/dashboard `defaultHost` "loopback only: single-user CLI dashboard, never LAN-exposed", pinned by upstream `server_loopback_test`), fronted by the registry vHost **invoices.home.lan** (`vHost.layer = "protected"` — oauth2-proxy forward-auth for external, LAN bypass). The dashboard has NO authentication of its own and shows revenue/client data — the journal-serve posture. Upstream: `github:LarsArtmann/invoices` (**PRIVATE** — CI deploy key `systemnix-ci-readonly`, key id 169358073, fp `SHA256:yX0Vani3x5LT0ZwimHEgdQUM/OEuIcp2i5EChqO4D8I`, served from `NIX_DEPLOY_KEYS_BUNDLE_2` `@REPO invoices`).

## BOOT CONTRACT (live-probed 2026-11-10)

`invoices dashboard` **REQUIRES `config.yaml` in the CWD** (viper `AddConfigPath "."`; NO `--config` flag exists) and **exits 69** without it (`[SYSTEM_CONFIGURATION_ERROR]`). Consequences:

- The unit's `WorkingDirectory` is the data dir `~/invoices`, and the unit carries `ConditionPathExists = ~/invoices/config.yaml` → a missing config is a CLEAN skip, not a crash loop.
- **`~/invoices/config.yaml` is the production config OF RECORD** (0600, `environment: "PRODUCTION"`, `debug: false`, a generated `jwt_secret` — NOT the repo placeholder). The repo checkout's `config.yaml` (`environment: "DEVELOPMENT"`) stays the dev copy; editing production config means editing `~/invoices/config.yaml` and `systemctl restart invoices-dashboard`.
- The dashboard **bootstraps a fresh DB** (inline schema + read-model backfill) when `--db` points at a missing file — first boot creates `invoices.db` from nothing.

## Integration surfaces

| Surface              | Where                                                                                                     | Notes                                                                                                                                                                                          |
| -------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| flake input          | `flake.nix` (`invoices`, `git+ssh://git@github.com/LarsArtmann/invoices?ref=refs/heads/master`)            | master-tracking float; non-follower class (own nixpkgs lock)                                                                                                                                                   |
| lock follows         | infra-follows group: `flake-parts` + `treefmt-nix` + `git-hooks` follow root                               | `nixpkgs` deliberately NOT followed — `lib/lock-audit.nix` `deliberate` entry ("invoices.nixpkgs": vendorHash probed 2026-11-10 at f72f78e via detached worktree)                                                               |
| package              | `lib/lars-packages.nix` (`invoices = flakePkg inputs.invoices`)                                            | Upstream `packages.default` = buildGoModule with a baked vendorHash (reproduces under its own lock; no consumer shim needed)                                                                                    |
| PATH (both hosts)    | `mkLarsPackages` → `platforms/common/packages/base.nix`                                                    | `invoices` CLI on PATH; same store path the unit runs                                                                                                                                                          |
| pre-deploy §11 batch | `quick-go` via mkLarsPackages                                                                              | rides the FOD-preview batch automatically                                                                                                                                                                      |
| CI auth              | `NIX_DEPLOY_KEYS_BUNDLE_2` `@REPO invoices` (all 5 workflow auth blocks concat bundle 1 + 2)               | bundle-2 material is sops-archived: `platforms/nixos/secrets/ci-deploy-keys-bundle2.yaml` `invoices_key`                                                                                                        |
| dashboard unit       | `modules/nixos/services/invoices-dashboard.nix` (`services.invoices-dashboard`, enabled in configuration.nix) | primary user, `harden` 1G + `ProtectHome=read-only` + `ReadWritePaths = ~/invoices`, `ioTier.background`, `onFailure` toast, `ConditionPathExists` config.yaml clean-skip. Registry entry: subdomain `invoices`, **protected vHost**, Finance tile (invoiceplane.png), `monitored` |
| nightly DB backup    | same module: `invoices-dashboard-backup.timer` 03:50 + 10m jitter, `Persistent`                            | oneshot as root: `sqlite3 -readonly .timeout 30000 .backup` ×3 retry + `quick_check` gate + gzip → `/mnt/pool/backups/invoices/invoices-db-YYYY-MM-DD.db.gz`, 14d retention; **plus an undated `config.yaml` snapshot** riding every backup (config truth is inside the backup set); `mkPoolDirUnit` + `RequiresMountsFor`; registry `backup` entry (filePattern `*-db-*.db.gz`, maxAgeHours 25) |

## Ops

- **Data home: `~/invoices/` (evo-x2).** `config.yaml` (of record) + `invoices.db` = the TRUTH for invoice records; the invoices CLI is the write path (`invoices … --db ~/invoices/invoices.db`), the dashboard is the read window + facts projection onto the same single store. USER data outside `/var/lib` deliberately (journal books precedent).
- **Serving**: `http://127.0.0.1:8110` (loopback, upstream-pinned); from LAN/VPN **https://invoices.home.lan** (oauth2-proxy protected; LAN bypass). Endpoints: `/health` (JSON `{"status":"healthy","checks":[database,read-models]}`; **503 honestly when a check fails**), `/` (title "Invoice Dashboard"), `/api/stats`, SSE facts at `/events/facts`. No host-header guard (any Host is accepted — the loopback bind + proxy are the boundary). Graceful shutdown: SIGINT/SIGTERM → 5s window, SSE watchers closed.
- **Restore drill (run at least once — 2026-11-10)**: `gunzip < /mnt/pool/backups/invoices/invoices-db-<date>.db.gz > /tmp/restore-check.db && sqlite3 /tmp/restore-check.db ".tables" | wc -w` — and diff the backup's `config.yaml` snapshot against `~/invoices/config.yaml` when debugging config drift.
- **vendorHash drift class**: NON-FOLLOWER — root nixpkgs bumps cannot re-hash its FOD. Re-stales only when invoices' own lock moves: probe at rev first (detached worktree `nix build path:.#default`), then `nix flake lock --update-input invoices`.
- **Repo churn caution**: the invoices repo is actively developed (parallel sessions + auto-commit daemon). The lock floats only through the reviewed float-register ceremony — never chase master by hand mid-deploy.

## Related

- [timesheets.md](./timesheets.md) — the sibling billing window (same posture, same deploy)
- [journal.md](./journal.md) — the posture precedent
- [go-ecosystem.md](../agents/go-ecosystem.md) — non-follower doctrine, bundle-2 CI recipe
