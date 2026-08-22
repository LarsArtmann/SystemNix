# DNSBlockd OIDC Secret Desync — Diagnosis & Fix Applied (Not Yet Deployed)

**Date:** 2026-08-22 02:46
**Session start:** ~02:20
**Trigger:** User reported "The identity provider rejected the sign-in. Try again or check its logs." and asked to check dnsblockd logs.

---

## Executive Summary

The dnsblockd dashboard OIDC login (Pocket ID SSO) is broken with `invalid_client` errors. Root cause: the Pocket ID client secret for `dnsblockd` desynced from Pocket ID's database after crash-recovery boots (2026-08-22 00:32 and 00:48) recreated the OIDC client in Pocket ID's DB while the secret file on disk survived from before the crash. The provisioner's skip-if-exists check saw the stale secret file and never regenerated it. A fix (`regenerateSecretsFor = [ "dnsblockd" ]`) has been written to `configuration.nix` and passes `nix flake check --no-build`, but has **NOT been deployed yet**.

---

## a) FULLY DONE

1. **Read dnsblockd service logs** — Found the smoking gun at 02:23:22:
   ```
   oidc login exchange failed: oauth2: "invalid_client" "Client authentication failed
   (e.g., unknown client, no client authentication included, or unsupported authentication method)."
   ```
   The OIDC authorization-code → token exchange was rejected by Pocket ID.

2. **Read Pocket ID service logs** — Confirmed Pocket ID rejected the token exchange:
   ```
   ERR Failed to create access request error=invalid_client
   WRN status=401 method=POST path=/api/oidc/token
   ```
   The user authenticated successfully via passkey (webauthn login/finish returned 200), but the subsequent token exchange from dnsblockd failed because the client secret doesn't match what Pocket ID has in its database.

3. **Traced the full secret provisioning chain** — Used a sub-agent to map the entire flow:
   - `pocket-id-provision.service` → creates OIDC client + generates secret → writes to `/var/lib/pocket-id/client-secrets/dnsblockd` (0640, pocket-id:pocket-id)
   - `dnsblockd-oidc-secret.service` (oneshot) → reads secret via `LoadCredential` → writes to `/var/lib/dnsblockd-oidc/client-secret.env`
   - `dnsblockd.service` → reads `EnvironmentFile = [ "/var/lib/dnsblockd-oidc/client-secret.env" ]` → `DNSBLOCKD_OIDC_CLIENT_SECRET` env var

4. **Identified root cause** — The provisioner logs show:
   - At 00:32:59 (crash recovery boot 1): `Creating OIDC client: dnsblockd` — the client was RE-CREATED in Pocket ID's database (fresh DB after crash)
   - At 00:48:17 (crash recovery boot 2): `Creating OIDC client: dnsblockd` — client RE-CREATED AGAIN
   - Both times: `Secret file already exists.` — the provisioner saw the stale secret file from BEFORE the crash and skipped regeneration
   - Result: Pocket ID's DB has a NEW client with a NEW secret, but dnsblockd has the OLD secret from the file

5. **Applied the fix** — Added `regenerateSecretsFor = [ "dnsblockd" ]` to `configuration.nix` in the `pocket-id-config.provision` block. This forces the provisioner to delete the stale secret file and call `POST /api/oidc/clients/dnsblockd/secret` to generate a fresh one that matches Pocket ID's current database state.

6. **Validated the fix** — `nix flake check --no-build` passes cleanly (all checks passed, only the expected aarch64-darwin incompatibility warning).

---

## b) PARTIALLY DONE

1. **Deploy the fix** — The `regenerateSecretsFor` flag is in the config file and passes flake check, but `nix run .#deploy` has NOT been run yet. The running system still has the stale secret.

2. **Post-deploy verification** — Not possible until deploy runs. Need to verify:
   - Provisioner log shows `Force-regenerating secret (listed in regenerateSecretsFor)...`
   - `dnsblockd-oidc-secret.service` writes the new env file
   - dnsblockd service restarts with the new secret
   - OIDC login to dnsblockd dashboard succeeds

3. **Config cleanup** — The `regenerateSecretsFor = [ "dnsblockd" ]` flag is a TIME BOMB (documented footgun from prior incidents). It MUST be removed after the successful deploy and the system re-deployed, or the secret will rotate on every provision run.

---

## c) NOT STARTED

1. **Deploy** (`nix run .#deploy`)
2. **Verify OIDC login works** after deploy
3. **Remove `regenerateSecretsFor` flag** from configuration.nix
4. **Re-deploy** without the flag
5. **Update AGENTS.md** with the crash-recovery secret desync as a known trigger
6. **Link `docs/dnsblockd-oidc-recovery.md`** from the docs index (existing TODO_LIST item)

---

## d) TOTALLY FUCKED UP

1. **Nothing in this session was fucked up.** The diagnosis was clean and the fix is correct. However, the fix is INCOMPLETE because it hasn't been deployed yet.

2. **Broader systemic issue (not this session's fault):** The crash-recovery boots (kernel freeze at 00:27, documented in AGENTS.md "Hardware Instability" section) recreated the Pocket ID database from scratch, which invalidated ALL client secrets — not just dnsblockd. The other OIDC clients (oauth2-proxy, immich, forgejo, gatus, browser-history) may ALSO be desynced, but their logins haven't been tested yet. Only dnsblockd was tested because the user tried to log in to the dnsblockd dashboard.

3. **The provisioner's skip-if-exists check is fundamentally fragile against DB recreation.** When Pocket ID's database is recreated (fresh DB after crash), the client IDs exist but the secret hashes in the DB are fresh. The provisioner sees the client "already exists" and the secret file "already exists" and skips everything. There's no mechanism to detect that the DB-side secret has changed.

---

## e) WHAT WE SHOULD IMPROVE

1. **The `regenerateSecretsFor` mechanism is a known footgun** (documented in 5+ prior status reports). It requires a two-deploy lifecycle (set → deploy → clear → deploy) and if the clear step is forgotten, secrets rotate on every provision run. An auto-clear mechanism or a deploy-time assertion warning would prevent this class of mistake.

2. **The provisioner should detect DB recreation.** When Pocket ID's database is recreated from scratch (all clients re-created), the provisioner could detect this (e.g., by checking if the client was created in this run vs. already existed) and force-regenerate all secrets. Currently the "Secret file already exists" check is a silent failure path.

3. **All OIDC clients may be desynced, not just dnsblockd.** The crash-recovery boots recreated ALL clients in Pocket ID's DB. Only dnsblockd has been tested so far. A comprehensive post-recovery verification of ALL OIDC-dependent services (oauth2-proxy, immich, forgejo, gatus, browser-history) should be done.

4. **Pocket ID SQLITE_BUSY errors** were visible in the logs (01:33:08-01:33:17). These are collateral from discordsync IO storms on the same BTRFS filesystem (documented in AGENTS.md). Not the root cause but indicates database contention under load.

5. **The dnsblockd OIDC secret flow has a `dnsblockd-oidc-secret.service` that uses `RemainAfterExit=true`** — per AGENTS.md, this makes `start` a no-op on re-run. The deploy script must `RESTART` (not `start`) this service, or the new secret won't be picked up. Need to verify deploy.sh handles this.

---

## f) Up to 50 Things to Get Done Next

### Immediate (blocking — must do before session ends)
1. **Deploy the fix** — `nix run .#deploy`
2. **Verify provisioner force-regenerated the dnsblockd secret** — check journal for `Force-regenerating secret`
3. **Verify dnsblockd OIDC login works** — test the dashboard login flow
4. **Remove `regenerateSecretsFor = [ "dnsblockd" ]` from configuration.nix**
5. **Re-deploy without the flag** — clear the time bomb

### High priority (same session or next)
6. **Test ALL other OIDC client logins** — oauth2-proxy (any Layer 2 service), immich, forgejo, gatus, browser-history. The crash-recovery may have desynced ALL of them.
7. **If other clients are also desynced, add them to `regenerateSecretsFor`** and deploy
8. **Check if `dnsblockd-oidc-secret.service` was RESTARTED (not just started) by deploy.sh** — `RemainAfterExit=true` makes `start` a no-op
9. **Verify the `dnsblockd.service` actually restarted** and picked up the new `EnvironmentFile`

### Medium priority (improvements)
10. **Add an auto-clear mechanism for `regenerateSecretsFor`** — script-level: after successful regeneration, clear the flag (or at least warn loudly on every provision run while it's non-empty)
11. **Add a pre-deploy assertion/warning when `regenerateSecretsFor` is non-empty** — `nix flake check` or a deploy.sh check
12. **Consider a "DB recreation detection" heuristic in the provisioner** — if ALL clients were created (not "already exists") in a single run, force-regenerate all secrets
13. **Link `docs/dnsblockd-oidc-recovery.md` from AGENTS.md or docs index** — existing TODO_LIST item, would have made this diagnosis faster
14. **Document the crash-recovery secret desync class in AGENTS.md** — "After Pocket ID DB recreation (crash recovery), ALL OIDC client secrets may be desynced. The provisioner's skip-if-exists check does NOT detect this."
15. **Add a Gatus check for dnsblockd OIDC health** — currently there's no automated check that catches this class of failure (the dashboard login is the only signal)
16. **Review whether `pocket-id-provision.service` should run AFTER Pocket ID is fully ready** — the SQLITE_BUSY errors suggest timing issues under load
17. **Consider making the provisioner verify the secret works** — after writing the secret file, do a test token exchange to confirm it matches the DB
18. **Audit ALL `*-oidc-secret` / `*-oidc-setup` oneshots for the `RemainAfterExit=true` + deploy.sh restart pattern** — ensure deploy.sh RESTARTS (not starts) all of them

### Lower priority (nice to have)
19. **Add a "pocket-id DB recreation" detector** — compare client count or a checksum to detect a fresh DB
20. **Consider a `regenerateAllSecrets` option** — for post-crash-recovery scenarios
21. **Review the Pocket ID backup/restore flow** — does restoring from backup also invalidate secrets?
22. **Add a post-deploy smoke test for OIDC login** — `scripts/post-deploy-check.sh` should test at least one OIDC flow
23. **Consider moving OIDC client secrets to sops** — would survive DB recreation (but then Pocket ID can't rotate them)
24. **Review the `pkceEnabled = true` setting for dnsblockd** — PKCE + client secret is belt-and-suspenders, but the secret is still required for the token exchange
25. **Check if the kernel freeze root cause (zram full + flm model unevictable) has been addressed** — the `memory-emergency-guard.nix` module was added but needs verification
26. **Verify the NIC-present watchdog and DAS USB recovery from the crash are working** — AGENTS.md documents these as new additions
27. **Run `scripts/scan-history-secrets.sh`** — verify no new secret leaks from this session
28. **Update TODO_LIST.md** with the crash-recovery secret desync class
29. **Consider a "pocket-id-health" Gatus check that tests the OIDC discovery endpoint AND a test token exchange**
30. **Review whether the `pocket-id-provision` script should handle the "client created but no secret generated" case** — currently it creates the client, then checks the secret file, but if the file exists from a previous run with a different DB, it silently skips

---

## g) Questions I Cannot Answer Myself

1. **Should I deploy right now, or do you want to verify the diagnosis first?** The fix is ready (`regenerateSecretsFor = [ "dnsblockd" ]`), passes flake check, and the root cause is confirmed. But deploying will restart Pocket ID, dnsblockd, and potentially other services. Given the crash-recovery context (the machine froze at 00:27 and has been rebooted twice), I want to confirm you're ready for a deploy.

2. **Should I also add the other OIDC clients (oauth2-proxy, immich, forgejo, gatus, browser-history) to `regenerateSecretsFor` preemptively?** The crash-recovery boots likely desynced ALL of them, not just dnsblockd. Proactively regenerating all secrets would fix them all in one deploy, but would also invalidate ALL active sessions across ALL services. Alternatively, we fix dnsblockd first and test the others one by one.

3. **The `regenerateSecretsFor` flag requires a second deploy to clear it. Should I deploy the fix now, then immediately remove the flag and deploy again? Or wait for your verification between deploys?** The two-deploy lifecycle is the documented footgun — I can make it a single round-trip by setting the flag, deploying, verifying, removing the flag, and deploying again. But that's two full deploys in quick succession on a crash-recovered machine.

---

## Technical Details

### Error Evidence

**dnsblockd** (02:23:22):
```
level=ERROR msg="oidc login exchange failed" error="finishing oidc login: [transient:oauth2.finish_login] finish login: [transient:oauth2.token_exchange] exchange code: oauth2: \"invalid_client\" \"Client authentication failed (e.g., unknown client, no client authentication included, or unsupported authentication method).\""
```

**Pocket ID** (02:23:22):
```
ERR Failed to create access request error=invalid_client
WRN status=401 method=POST path=/api/oidc/token
```

### Root Cause Timeline

| Time | Event | Impact |
|------|-------|--------|
| 00:27 | Kernel freeze (zram full + flm model unevictable) | System hard-reset |
| 00:32 | Boot 1 — Pocket ID DB recreated from scratch | `dnsblockd` client re-created with NEW secret in DB |
| 00:32 | Provisioner: `Creating OIDC client: dnsblockd` + `Secret file already exists.` | Stale secret file survives, new DB secret not written to file |
| 00:48 | Boot 2 — same pattern repeats | Client re-created again, secret file still stale |
| 02:23 | User attempts OIDC login to dnsblockd dashboard | Token exchange fails: `invalid_client` |

### Fix Applied

**File:** `platforms/nixos/system/configuration.nix`
**Change:** Added `regenerateSecretsFor = [ "dnsblockd" ]` to `pocket-id-config.provision`

**Validation:** `nix flake check --no-build` — all checks passed.

### Secret Provisioning Chain (for reference)

```
pocket-id-provision.service
  → POST /api/oidc/clients/dnsblockd/secret (generates NEW secret in DB)
  → writes /var/lib/pocket-id/client-secrets/dnsblockd (0640, pocket-id:pocket-id)
    ↓
dnsblockd-oidc-secret.service (oneshot, LoadCredential)
  → reads /var/lib/pocket-id/client-secrets/dnsblockd
  → writes /var/lib/dnsblockd-oidc/client-secret.env (DNSBLOCKD_OIDC_CLIENT_SECRET=...)
    ↓
dnsblockd.service (EnvironmentFile)
  → reads DNSBLOCKD_OIDC_CLIENT_SECRET from env
  → OIDC authorization-code + PKCE S256 flow with Pocket ID
```

---

## RESOLUTION (2026-08-22 03:45) — fixed, verified, time bomb removed

The situation ESCALATED before the fix deploy ran: Pocket ID hit a fatal
SQLITE_BUSY chain (02:37–02:40, collateral of crash-recovery IO pressure),
exited, and after its 02:42 restart the `dnsblockd` client row was GONE from
the DB entirely — user-facing error changed to "The requested OAuth 2.0 Client
does not exist" (`invalid_client` on `/authorize`, not token exchange).

**Root causes fixed (three, stacked):**

1. **Client vanished from Pocket ID DB** (new failure class — SQLite crash
   fallout, distinct from secret desync). Healed by the provisioner's
   client-missing → POST create path at 03:05:49 (HTTP 201).
2. **Secret desync** (original diagnosis) — `regenerateSecretsFor =
   ["dnsblockd"]` rotated the secret at 03:05:49. Flag REMOVED and redeployed
   at 03:40 (provisioner now logs "Secret file already exists" — stable).
3. **Systemic deploy gap (the reason the first deploy didn't fix login)** —
   a rotated secret never reached the daemon: `dnsblockd-oidc-secret`
   (RemainAfterExit=true, `wantedBy=dnsblockd.service` → `is-enabled` rc=1
   "indirect" → silently skipped by deploy.sh's provisioner loop) and
   `dnsblockd.service` (reads EnvironmentFile at start only) were never
   restarted. deploy.sh now has a dedicated is-active-gated block restarting
   bridge + daemon in order (browser-history pattern).

**Verified end-to-end:** authorize probe → `302 /interaction` (client
recognized, was error-redirect before); bridge journal "client secret written"
03:42:04; dnsblockd restarted 03:42:04 after bridge; 0 OIDC errors in
dnsblockd journal since; DNS + dashboard :9090 healthy.

**Unrelated collateral this crash-recovery night (NOT fixed here):**
`/mnt/pool` unmounted (DAS USB dropped, needs physical reseat) → Immich,
Paperless, bank-sync, Attic down; `signoz-provision` failing is a concurrent
session's in-flight ClickHouse XFS migration (docs/planning/
2026-08-22_02-38_clickhouse-xfs-migration.md); Pocket ID SQLITE_BUSY was
transient IO-pressure collateral (clean at 03:44 smoke).
