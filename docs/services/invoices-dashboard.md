# invoices-dashboard (invoice CLI + read-model dashboard)

**Deployed as the invoices-dashboard unit + protected vHost (2026-11-10).** `invoices` is the billing CLI (invoice/solcom/importallocations with `--db`) plus `invoices dashboard`, a read-model web UI over the invoice SQLite DB (`modules/nixos/services/invoices-dashboard.nix`): binds **127.0.0.1:8110 BY UPSTREAM DESIGN** (`ports.invoices-dashboard`; internal/dashboard `defaultHost` "loopback only: single-user CLI dashboard, never LAN-exposed", pinned by upstream `server_loopback_test`), fronted by the registry vHost **invoices.home.lan** (`vHost.layer = "protected"` — oauth2-proxy forward-auth for external, LAN bypass). The dashboard has NO authentication of its own and shows revenue/client data — the journal-serve posture. Upstream: `github:LarsArtmann/invoices` (**PRIVATE** — CI deploy key `systemnix-ci-readonly`, key id 169358073, fp `SHA256:yX0Vani3x5LT0ZwimHEgdQUM/OEuIcp2i5EChqO4D8I`, served from `NIX_DEPLOY_KEYS_BUNDLE_2` `@REPO invoices`).

## BOOT CONTRACT (live-probed 2026-11-10)


`invoices dashboard` **REQUIRES `config.yaml` in the CWD** (viper `AddConfigPath "."`; NO `--config` flag exists) and **exits 69** without it (`[SYSTEM_CONFIGURATION_ERROR]`). Consequences:

- The unit's `WorkingDirectory` is the data dir `~/invoices`, and the unit carries `ConditionPathExists = ~/invoices/config.yaml` → a missing config is a CLEAN skip, not a crash loop.
- **`~/invoices/config.yaml` is the production config OF RECORD** (0600, `environment: "PRODUCTION"`, `debug: false`, a generated `jwt_secret` — NOT the repo placeholder). The repo checkout's `config.yaml` (`environment: "DEVELOPMENT"`) stays the dev copy; editing production config means editing `~/invoices/config.yaml` and `systemctl restart invoices-dashboard`.
- The dashboard **bootstraps a fresh DB** (inline schema + read-model backfill) when `--db` points at a missing file — first boot creates `invoices.db` from nothing.

## Schema heal: pre-2026-11-13 invoices tables (fixed 2026-11-15)

`InitializeSchema` heals databases whose `invoices` table predates the PARTLY paylinks status: SQLite cannot ALTER a CHECK constraint, so the table is rebuilt. That heal **crash-looped the dashboard on 2026-11-14** (exit 75 → `start-limit-hit` → 502 at the vHost) for two reasons, both fixed upstream in `invoices` 935a044d:

- the rebuild replayed `CREATE INDEX idx_invoices_invoice_number …` while the BOOT path had already created that index (index names survive a table rename), so every boot died on `index idx_invoices_invoice_number already exists`;
- the embedded migration SQL was a splintered copy that could not have parsed past that point.

The rebuild now follows SQLite's documented table-rebuild procedure in Go (`internal/db/connection/turso.go` → `rebuildInvoicesForPartlyStatus`): drop legacy artifacts, `PRAGMA foreign_keys=OFF` on a dedicated connection (else dropping the referenced table cascades into `invoice_work_entries`), build `invoices_new`, copy through an intersected column list (primary keys preserved), swap, recreate indexes, gate on `PRAGMA foreign_key_check`. One DDL template feeds both the fresh-boot path and the rebuild, and `schema_heal_internal_test.go` fails on drift with `sql/sqlite/migrations/2026-11-13_partly_status.sql`.

**Triage shortcut:** `exit 75/TEMPFAIL` + an `already exists` line in `journalctl -u invoices-dashboard` = this class; the fix belongs upstream, never in a pinned input (owner-pin doctrine).

**Known split brain (not yet fixed):** `sql/sqlite/migrations/../schema/invoices.sql` still differs from the runtime bootstrap — its `invoice_type` CHECK lists `FAKTURA` but not `REVERSE_CHARGE`, and it adds an unused FTS5 mirror plus five extra indexes that no boot path creates. Nothing queries `invoices_fts`.

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
- **Restore drill (RUN 2026-11-10, receipt live)**: `gunzip < /mnt/pool/backups/invoices/invoices-db-2026-11-10.db.gz > scratch.db && sqlite3 scratch.db "PRAGMA quick_check"` → `ok`, 14 tables incl. `invoices`/`invoice_work_entries`/`audit_ledger`; the backup's `config.yaml` snapshot hash-matched the live `~/invoices/config.yaml` (`1dcaa9bd…`). First artifact produced 2026-11-10 by a cap-fixed backup run (CAP_DAC_READ_SEARCH note below); nightly timer 03:50 carries it from there.
- **vendorHash drift class**: NON-FOLLOWER — root nixpkgs bumps cannot re-hash its FOD. Re-stales only when invoices' own lock moves: probe at rev first (detached worktree `nix build path:.#default`), then `nix flake lock --update-input invoices`.
- **Repo churn caution**: the invoices repo is actively developed (parallel sessions + auto-commit daemon). The lock floats only through the reviewed float-register ceremony — never chase master by hand mid-deploy.

## Related

- [timesheets.md](./timesheets.md) — the sibling billing window (same posture, same deploy)
- [journal.md](./journal.md) — the posture precedent
- [go-ecosystem.md](../agents/go-ecosystem.md) — non-follower doctrine, bundle-2 CI recipe
