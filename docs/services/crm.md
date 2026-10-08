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
| Backup     | `crm-backup.timer` 03:40 nightly — WAL-safe sqlite snapshots (backup API) of BOTH durable dbs → `/mnt/pool/backups/crm/{ledger,identity}-YYYY-MM-DD.db` (ledger 0644, identity 0600 — passkey/session bearer material), 30-day retention. LIVE since 2026-10-08 03:47 (first artifact). Timer note: a freshly-written stamp (first load of the unit) suppresses Persistent catch-up — first run waits for the next calendar slot. `api-token` deliberately NOT backed up (sops-owned, repo-recoverable) |
| State      | `~/.local/share/crm/` (journal + identity.db — adopted in place, 2026-09-18 standing decision: NO /var/lib migration) |

## Cutover (2026-10-02 micro-plan, T19–T44)

**T42 EXECUTED 2026-10-08** (owner-authorized after backup-green: first pool
artifact 03:47 integrity-ok + restore drill green with the production binary).
`twenty.enable = false` landed in `platforms/nixos/system/configuration.nix`;
that deploy flips `services.integration.crm-server.vHost.layer` from `"none"`
to `"plain"` atomically — the registry keys vHosts by subdomain, so the two
can never both claim it. The homepage tile, the "Ledger CRM" Gatus check
(HTTPS, `/login`), and the post-deploy-check gate switch over with it.
Twenty's containers stop; its Docker data stayed intact until the retirement
decision — the Twenty module + its runbooks were deleted 2026-10-08 with the
Docker removal (data reclaim tracked in `docs/todo/services.md`). Known
post-flip gap: `crm.larsartmann.cloud`
also proxies here but WebAuthn `-rpid` is `crm.home.lan` — passkey login works
on `crm.home.lan` only until the cloud-domain decision lands.

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
- **Artifact verification (quarterly)**: the sanctioned headless check is
  `crm-server -db <copy of the newest pool artifact> -export /tmp/crm-verify.jsonl`
  — auth-free, emits the exact rebuild truth (proven 2026-10-08: 29,053
  events). Page-render probes on scratch boots always gate at the login
  page (the journal persists auth-on).
- **The package builds from the PUSHED tip** of `github:LarsArtmann/crm`
  (flake input). Unpushed local commits are NOT deployed — push, then
  `nix flake lock --update-input crm`, then deploy.
