# Kith CRM (crm-server)

LarsArtmann's own event-sourced personal CRM (Go + go-cqrs-lite) at
`github:LarsArtmann/crm` — the Twenty replacement. The journal
(`~/.local/share/crm/ledger.db`) is the source of truth; projections are
disposable. Upstream repo: `/home/lars/projects/crm` (runbooks in
`docs/ops/` there: CV-SYNC.md, PASSKEY-RECOVERY.md, RESTORE-DRILL.md).

## Surfaces

| Surface     | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unit        | `crm-server.service` (system, `User=lars`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Port        | `ports.crm` = 8091 (loopback only: `127.0.0.1:8091`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| vHost       | `crm.home.lan` — **plain layer** (own auth), claimed only once Twenty is frozen (see Cutover)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Auth        | **Pocket ID OIDC ONLY** (2026-10-17, `-passkeys=false`): the login page serves the provider button alone (`-auth`, `-secure true`, client `crm`, callback `/auth/oauth/pocket-id/callback`, PKCE); passkey ceremonies 401, the passkey settings page is off, registered credentials stay dormant in identity.db. Secret via `crm-oidc-env` bridge → `CRM_OIDC_CLIENT_SECRET` (never argv). `/healthz` + bearer API stay outside the session gate. **NO DEGRADE PATH**: an unreachable issuer or missing secret fails the BOOT (no fallback sign-in exists). **DNS-wait gate** (2026-10-12): the unit's `ExecStartPre` waits (bounded 120s, fail-open) for `auth.home.lan` to resolve before starting — discovery is one-shot at startup; post-deploy-check §20 verdicts the `oidc sign-in` readiness line |
| Machine API | `-api-token` bearer → `/api` + `/rest` (Twenty-compatible surface for the CV pipeline sync)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Secret      | `crm_api_token` in `platforms/nixos/secrets/crm.yaml` (age-public-key-encrypted; same value as the pre-module `~/.local/share/crm/api-token`) → sops template `crm-server-env` → `EnvironmentFile`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Gatus       | "Kith CRM" on `/healthz` (loopback, 5m) — live from day one                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Backup      | `crm-backup.timer` 03:40 nightly — WAL-safe sqlite snapshots (backup API) of BOTH durable dbs → `/mnt/pool/backups/crm/{ledger,identity}-YYYY-MM-DD.db` (ledger 0644, identity 0600 — passkey/session bearer material), 30-day retention. LIVE since 2026-10-08 03:47 (first artifact). Timer note: a freshly-written stamp (first load of the unit) suppresses Persistent catch-up — first run waits for the next calendar slot. `api-token` deliberately NOT backed up (sops-owned, repo-recoverable)                                                                                                                                                                                                                                       |
| State       | `~/.local/share/crm/` (journal + identity.db — adopted in place, 2026-09-18 standing decision: NO /var/lib migration)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |

## Cutover (2026-10-02 micro-plan, T19–T44)

**T42 EXECUTED 2026-10-08** (owner-authorized after backup-green: first pool
artifact 03:47 integrity-ok + restore drill green with the production binary).
`twenty.enable = false` landed in `platforms/nixos/system/configuration.nix`;
that deploy flips `services.integration.crm-server.vHost.layer` from `"none"`
to `"plain"` atomically — the registry keys vHosts by subdomain, so the two
can never both claim it. The homepage tile, the "Kith CRM" Gatus check
(HTTPS, `/login`), and the post-deploy-check gate switch over with it.
Twenty's containers stop; its Docker data stayed intact until the retirement
decision — the Twenty module + its runbooks were deleted 2026-10-08 with the
Docker removal (data reclaim tracked in `docs/todo/services.md`). Known
post-flip gap (re-based 2026-10-17): `crm.larsartmann.cloud`
also proxies here, but the Pocket ID client's callback allowlist carries
`crm.home.lan` only — a cloud-originated sign-in bounces at the IdP. The
2026-10-08 multi-RP-ID WebAuthn draft (per-domain passkeys) is OBSOLETE:
passkeys are off; a cloud sign-in would need a second registered callback,
not WebAuthn work. The cloud vHost stays as-is meanwhile.

Sign-in: visit `https://crm.home.lan` → the login page offers the Pocket ID
button alone; the existing user is linked by provider+subject (first
Pocket ID login 2026-10-10 linked it by email). Escape hatch if Pocket ID
is unreachable long-term: `services.crm-server.auth.enable = false` +
deploy lifts the session gate entirely (the bearer API path is documented
in the crm repo `docs/ops/PASSKEY-RECOVERY.md`; re-enabling passkeys
upstream restores the dormant credentials).

## Native OIDC (Pocket ID, 2026-10-10; ONLY method since 2026-10-17)

Pocket ID is the ONLY sign-in method (Layer 1 in
`docs/agents/sso-dns.md`): the login page renders the provider button
alone (`-passkeys=false` leaves the WebAuthn provider unconfigured
upstream), success mints the CRM session, and the user was linked at the
first Pocket ID login (usermgmt matchOrCreateUser: provider+subject
first, email fallback). Requirement REMAINS: the Pocket ID account email
must equal the registration email — a different email hits the
`MaxUsers=1` registration-closed rejection (linking works regardless of
Pocket ID's per-user `email_verified`, which defaults FALSE fleet-wide).
LAN coverage is the REASON for native OIDC here: the oauth2-proxy Layer 2
gate bypasses LAN clients, and `crm.home.lan` IS a LAN hostname. Wiring:
registry `oidc` entry (clientId `crm`) → `pocket-id-provision` mints the
client + secret → `crm-oidc-env` oneshot bridges the secret into
`/var/lib/crm-oidc/client-secret.env` → crm-server `EnvironmentFile`
reads it as `CRM_OIDC_CLIENT_SECRET`. Deploy-restart coupling lives in
`scripts/deploy.sh` (is-active-gated restart block, deploy-restart-audit
gate). **Fail semantics (changed 2026-10-17)**: with no passkey fallback,
an unreachable issuer at start OR a missing bridge secret is BOOT-FATAL
(the `-oidc-*` family turns partial / discovery errors) — the unit
restart-loops into start-limit-hit, Gatus catches the 502, and §20 of
post-deploy-check flags the missing `oidc sign-in enabled` line. Fix
Pocket ID, then restart crm-server.

## Traps

- **Pocket ID login bounces back to the login page = token_exchange/invalid_client, i.e. the bridge file's secret is not in Pocket ID's DB.** Diagnose: `journalctl -u crm-server | grep oauth_login_failed` (CRM side) + `journalctl -u pocket-id | grep invalid_client` (IdP side — client auth fails BEFORE grant/PKCE checks, so an `invalid_client` there is always the shared secret, never redirect/PKCE wiring). 2026-10-14 root cause: the crm client row was created THREE times on Oct 10 (Pocket ID crashed exit-1 twice under SQLite contention; each crash-recovery lost the just-created row while the provisioner's secret FILE survived outside the DB) — every re-create minted a fresh auto-secret and the skip-if-exists guard kept the orphaned file forever. Heal is declarative: `pocket-id-config.provision.regenerateSecretsFor = [ "crm" ]` → deploy → verify → REMOVE the entry (its guard fails later provision runs past the 24h window). Never hand-edit either side.
- **Provisioner create-echo used to leak `createdSecret` into the pocket-id journal** (fixed 2026-10-14: echo is now `jq del(.createdSecret)`-redacted, and force-regeneration PRUNES pre-rotation secrets so leaked/lost values die with the rotation). The Oct 10 journal still contains three now-dead secrets plus one the 2026-10-14 rotation pruned — treat pre-fix provision logs as credential-bearing.
- **A silent sign-in outage is now a LOUD one (2026-10-17)**: with
  `-passkeys=false` there is no passkey fallback — an unreachable Pocket
  ID or a missing bridge secret fails the crm-server BOOT (partial
  `-oidc-*` family / discovery error) instead of degrading. If
  crm-server restart-loops: `journalctl -u crm-server -b | tail -20`
  names the missing input. Never "fix" this by removing the `-oidc-*`
  flags — that keeps the boot alive with NO sign-in method and upstream
  refuses it anyway.
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
