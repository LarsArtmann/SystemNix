# Ledger CRM (crm-server)

LarsArtmann's own event-sourced personal CRM (Go + go-cqrs-lite) at
`github:LarsArtmann/crm` — the Twenty replacement. The journal
(`~/.local/share/crm/ledger.db`) is the source of truth; projections are
disposable. Upstream repo: `/home/lars/projects/crm` (runbooks in
`docs/ops/` there: CV-SYNC.md, PASSKEY-RECOVERY.md, RESTORE-DRILL.md).

## Surfaces

| Surface    | Value                                                        |
| ---------- | ------------------------------------------------------------ |
| Unit       | `crm-server.service` (system, `User=lars`)                   |
| Port       | `ports.crm` = 8091 (loopback only: `127.0.0.1:8091`)         |
| vHost      | `crm.home.lan` — **plain layer** (own auth), claimed only once Twenty is frozen (see Cutover) |
| Auth       | WebAuthn passkey (`-auth`, `-rpid crm.home.lan`, `-secure true`); `/healthz` + bearer API stay outside the session gate |
| Machine API| `-api-token` bearer → `/api` + `/rest` (Twenty-compatible surface for the CV pipeline sync) |
| Secret     | `crm_api_token` in `platforms/nixos/secrets/crm.yaml` (age-public-key-encrypted; same value as the pre-module `~/.local/share/crm/api-token`) → sops template `crm-server-env` → `EnvironmentFile` |
| Gatus      | "Ledger CRM" on `/healthz` (loopback, 5m) — live from day one |
| Backup     | `crm-backup.timer` 03:40 nightly — WAL-safe sqlite snapshot (backup API) → `/mnt/pool/backups/crm/ledger-YYYY-MM-DD.db`, 30-day retention |
| State      | `~/.local/share/crm/` (journal + identity.db — adopted in place, 2026-09-18 standing decision: NO /var/lib migration) |

## Cutover (2026-10-02 micro-plan, T19–T44)

While `services.twenty.enable = true`, Twenty keeps the `crm` vHost and
the dashboard tile; crm-server serves loopback only (monitored + backed
up). **Freezing Twenty** (`services.twenty.enable = false` +
`nix run .#deploy`) flips `services.integration.crm-server.vHost.layer`
from `"none"` to `"plain"` atomically in that same deploy — the registry
keys vHosts by subdomain, so the two can never both claim it. The
homepage tile and the post-deploy-check gate (`Ledger CRM (HTTPS)` on
`/login`) switch over with it.

First login: visit `https://crm.home.lan` → register the sole passkey
(MaxUsers=1 closes registration). Escape hatch: `services.crm-server.auth.enable
= false` + redeploy; API path documented in the crm repo
`docs/ops/PASSKEY-RECOVERY.md`.

## Traps

- **Never serve -auth without the vHost origin matching**: `-rpid`/`-origin`
  derive from `crm.${domain}`; a mismatched origin breaks the WebAuthn
  ceremony silently (browser-side).
- **The token is load-bearing for CV**: the same `crm_api_token` value
  activates the CV syncer (`CV_CRM_API_KEY` in sops.nix's cv-env template).
  Rotating = rotate BOTH the secret and nothing else (CV reads it from the
  same sops key).
- **Restore**: stop crm-server, move the journal aside, copy a pool
  snapshot back, start (full drill: crm repo `docs/ops/RESTORE-DRILL.md`).
- **The package builds from the PUSHED tip** of `github:LarsArtmann/crm`
  (flake input). Unpushed local commits are NOT deployed — push, then
  `nix flake lock --update-input crm`, then deploy.
