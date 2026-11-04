# OpenCloud — file sync & share platform (pilot)

**Status:** PILOT (2026-10-25, plan `docs/planning/2026-10-25_13-30_SUPERB-opencloud-pilot-adoption.md`) — complement mode (Google Drive stays canonical; google-sync/drive-paperless untouched), LAN/VPN-only exposure.

- **Unit:** `opencloud.service` (monolith: proxy + web + webfinger + storage + embedded IDM/LDAP; the embedded IDP is excluded)
- **Package:** `opencloud-production` 7.2.4 — the PRODUCTION release line. **No downgrade support across lines**: never switch an initialized instance to a different line.
- **Port:** 9200 (loopback only, `lib/ports.nix` `opencloud`), behind Caddy at `cloud.home.lan` (Layer 1 plain reverse_proxy — native OIDC)
- **State:** `/mnt/pool/services/opencloud` — pool SUBVOLUME (Set-B storage), snapshotted nightly by `btrbk-pool` (`services/opencloud` in the subvolume roster). posix storage driver: metadata in **xattrs**, no database.
- **Secrets:** exactly one — `opencloud_admin_password` (sops `platforms/nixos/secrets/opencloud.yaml`, template `opencloud-env` → `services.opencloud.environmentFile`). It feeds `opencloud init` ONLY; the embedded admin has no login surface (idp excluded). Nobody ever needs its value.

## Auth (Pocket ID, Layer 1 native OIDC)

All OpenCloud clients are PUBLIC PKCE clients with predefined client IDs, discovered via OpenCloud's webfinger service (`/.well-known/webfinger`):

| Client         | Client ID          | Redirect URIs                                                                                   | Scopes                                         |
| -------------- | ------------------ | ----------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Web            | `web`              | `https://cloud.home.lan/oidc-callback.html`, `https://cloud.home.lan/oidc-silent-redirect.html` | openid profile email **groups**                |
| Desktop (≥4.0) | `OpenCloudDesktop` | `http://127.0.0.1`, `http://localhost` (loopback port exemption)                                | openid profile email offline_access **groups** |
| Android        | `OpenCloudAndroid` | `oc://android.opencloud.eu`                                                                     | openid profile email offline_access **groups** |

All three provisioned by `pocket-id-config.provision` (`isPublic = true`, `pkceEnabled = true` — web via the integration registry entry, desktop/android via `extraOidcClients` in `modules/nixos/services/opencloud.nix`).

**Role mapping (declarative, fail-closed):** `PROXY_ROLE_ASSIGNMENT_DRIVER=oidc` + `PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM=groups` + the UPSTREAM DEFAULT mapping — Pocket ID user groups `opencloudAdmin` → role admin, `opencloudUser` → role user. A login whose token carries neither group FAILS (`no roles in user claims`) — intended LAN-only posture; add the user to `opencloudUser` in Pocket ID, never relax the driver.

**Why `groups` in every webfinger scope:** the role mapping reads the groups claim from the token; a client that does not request `groups` produces the login failure above (the historical opencloud-eu/desktop#217 class — desktop <4.0 also ignored webfinger discovery entirely).

**Fallback if desktop breaks on the oidc driver:** flip `PROXY_ROLE_ASSIGNMENT_DRIVER` to `"default"` AND `GRAPH_ASSIGN_DEFAULT_USER_ROLE` to `"true"` in `modules/nixos/services/opencloud.nix` (ONE deploy). Roles already assigned persist; new users then get role `user` implicitly (logins no longer fail-closed on groups).

**Username mapping:** proxy defaults `preferred_username` → `username` (Pocket ID emits `preferred_username`), auto-provisioning on first login (`PROXY_AUTOPROVISION_ACCOUNTS=true`) writes users into the embedded IDM (LDAP).

**Role audit (source-verified v7.2.4 + live 2026-11-04):** the default mapping iterates opencloudAdmin→admin, opencloudSpaceAdmin→spaceadmin, opencloudUser→user, opencloudGuest→user-light and the FIRST claim match wins — `opencloudAdmin` beats `opencloudUser` when a user holds both (our provision adds the primary user to BOTH; admin wins). The oidc driver re-evaluates the role from the token's groups claim on EVERY request — Pocket ID group changes take effect at the next login, no deploy. Assigned roles persist in the settings service, which stores them via the storage METADATA backend (there is NO `settings/` dir in stateDir): assignments + bundles are greppable JSON blobs under `/mnt/pool/services/opencloud/storage/metadata/spaces/f1/<space-id>/blobs/`. The embedded IDM auto-creates its groups from the same claim values (SyncGroupMemberships) — a `cn=opencloud*` group in `idm.boltdb` is proof the login token carried that group.

## Config flow (why `settings` stays empty)

`services.opencloud.settings` is DELIBERATELY empty: the nixpkgs module runs `opencloud-init-config` (`opencloud init`) once — it generates and persists the IDM/service secrets into `/etc/opencloud/opencloud.yaml` (root fs; the running service cannot write there — read-only store config). Skipping init (by providing `settings.opencloud`) would re-generate random secrets on every restart and corrupt the embedded IDM. All overrides ride `services.opencloud.environment` — env vars override YAML deterministically.

`OC_INSECURE` is NOT set (a 2026-10-25 draft claimed "module default true" — wrong, live-verified against the unit env 2026-11-02): outbound verification to `auth.home.lan` uses real TLS against the dnsblockd CA, which the whole system trusts via `security.pki.certificates` in `platforms/nixos/system/dns-blocker-config.nix`. The loopback proxy port itself is plain HTTP (PROXY_TLS=false, trap #11) — TLS terminates at Caddy.

## Traps

1. **`rsync -X` or lose the filesystem:** the posix driver stores metadata (trash, versions, shares) in **xattrs** — a plain `rsync -a` copy of the state tree silently drops them. Always `rsync -aX` (btrfs send/receive preserves them natively; btrbk-pool is safe).
2. **No downgrade across release lines** (`opencloud` rolling ↔ `opencloud-production`): upgrades ride future nixpkgs pin bumps — CHANGELOG review per bump.
3. **Role-claim fail-closed** (see above): the "cannot log in" symptom IS the group mapping, not a Pocket ID outage — check `journalctl -u opencloud | grep "no roles"` and the Pocket ID user groups.
4. **`/etc/opencloud/opencloud.yaml` holds the generated secrets** and lives on the ROOT fs — not covered by any snapshot set. Losing it means re-init (fresh secrets → embedded IDM user data is keyed to old secrets; files on the pool survive, users/groups need re-provisioning by logging in again). Documented pilot-acceptable risk.
5. **watch-fs**: not enabled (upstream can watch the posix tree for external changes; adds inotify load — enable deliberately if ever needed).
6. **The pool subvol is created by `opencloud-storage-dir`** (mount-gated oneshot, deploy.sh provisioner-restarted). Do NOT add tmpfiles rules for the stateDir (shadow-dir class); the nixpkgs module's tmpfiles rules are neutralized in the wrapper for exactly that reason.
7. **First deploy ordering:** `opencloud-storage-dir` → `opencloud-init-config` (needs `/etc/opencloud` writable + pool up) → `opencloud.service`. All mount-gated; a detached DAS fails them loudly (RequiresMountsFor).
8. **Internal port family:** ocis binds a band of loopback ports invisible to the port-registry audit (they live in binary defaults, not Exec text). The embedded NATS binds **9233** (live-verified 2026-10-27: NATS INFO answers on 9233; 9234 is an ocis HTTP service) and opencloud 7.2.4 **ignores `NATS_PORT`** — so `signoz-clickhouse-raft` moved 9234 → **9430** instead (keeper raft is single-node self-talk; zero clients; 9239 itself fell inside ocis's band — the whole 9100–9304 range is ocis-internal). The 9235+ internal gRPC ports are ocis-assigned — on any future internal bind failure, check `ss -ltn` against that band first. **9222 RESOLVED pre-emptively (2026-10-27, owner-directed):** hermes's headless-Chromium CDP moved 9222 → **9322** (`PORT=` in /home/hermes/scripts/ensure-chromium-cdp.sh + `cdp_url` in /home/hermes/config.yaml; timestamped .baks kept; Chromium 156 relaunched + verified on 9322) — 9222 is now free for whatever ocis service wants it. Related: the pre-deploy §10 metric gate learned a port-migration fallback (tree port dark → probe the RUNNING collector's listen address) — port moves no longer phantom-block their own carry-deploy.
9. **~~The proxy ignores `PROXY_HTTP_ADDR`~~ — SUPERSEDED, both halves of this note were wrong (corrected 2026-11-02 03:40 + 12:47):** the env IS honored (bind follows the configured port exactly — strace-proven; the "compiled-in 9100" answer was the standalone `web` service), and the live port is **9500** (web owns compiled-in 9100; the 9100 choice raced it, `ports.opencloud = 9500`). The "bodiless 400s through Caddy" symptom this trap described was REAL but its cause was the TLS port mismatch (trap #11), not the port number. **Kept for the lesson: a listener on the configured port does not prove WHICH service bound it — verify by process/inode, not by port answer.**
10. **Corrupt bleve search index crash-loops the whole service (2026-10-27, live first-start):** an aborted start (killed mid-index-creation) leaves `<stateDir>/search/bleve/root.bolt` seeded but WITHOUT its mapping record — every later start dies instantly in the `search` service on `error parsing mapping JSON: unexpected end of JSON input` (5 crashes in <1 s → start-limit-hit). Fix: quarantine `<stateDir>/search/bleve` (mv aside — it is derived data, rebuilds on next start), `systemctl reset-failed opencloud && systemctl start opencloud`. The quarantined copy lives at `search/bleve.corrupt-20261027`.
11. **The proxy serves TLS on its port by default — `PROXY_TLS=false` is REQUIRED behind Caddy (2026-11-02, live):** upstream default `PROXY_TLS=true` made the proxy speak HTTPS (self-signed `O=Acme Corp, CN=OpenCloud`) on its configured loopback port; Caddy's Layer-1 plain `reverse_proxy` then got Go's `400 Client sent an HTTP request to an HTTPS server` on every request — browser surface: `ERR_HTTP2_PROTOCOL_ERROR`, gatus check red. Diagnostic signature: direct plain-HTTP probe of the proxy port returns exactly that 400 message. Fix: `PROXY_TLS = "false"` in `modules/nixos/services/opencloud.nix` (one deploy; TLS stays at Caddy, `OC_URL` stays https). History note: the 2026-10-27 "proxy answers 200 with the SPA on 9100" observation was actually the standalone **web** service (plain HTTP, compiled-in 9100) — the proxy has NEVER answered plain HTTP through Caddy on any port (the pilot was never UI-reachable via browser until this fix).
12. **The external IdP origin must be added to the proxy CSP — the login dies in the BROWSER otherwise (2026-11-02, live):** with PROXY_TLS fixed the SPA loads (vHost 200) but sign-in fails with `Refused to connect ... violates Content Security Policy directive: connect-src` — the proxy's built-in default CSP (`services/proxy/pkg/config/csp.yaml`, kebab-case keys under a `directives:` map) has no `auth.home.lan`, and `IDP_DOMAIN` does NOT feed the CSP. Fix: `PROXY_CSP_CONFIG_FILE_LOCATION` pointing at a Nix-built additions file (`connect-src` + `frame-src` entries for `https://auth.<domain>`) — source-verified (v7.2.4 security.go): that file is **deep-merged into the default** (maps merged, slices concatenated + deduped), so the additions file needs ONLY the new entries; `PROXY_CSP_CONFIG_FILE_OVERRIDE_LOCATION` would REPLACE the default instead. Verify: CSP header on the vHost response must list `https://auth.home.lan` in both connect-src and frame-src.
13. **Empty-IDM-tree auth 500 — the bootstrap-skip-forever class (2026-11-03, live first-ever login):** Pocket ID round-trip OK, then proxy 500 `Autoprovisioning user failed` with idm `bind_dn uid=reva|uid=libregraph,ou=sysusers,o=libregraph-idm … "not found"`. Root cause (upstream v7.2.4 `services/idm/pkg/command/server.go`): the IDM bootstrap seeds the sysusers ONLY when `<stateDir>/idm/idm.boltdb` does not EXIST, and a failed bootstrap is NON-fatal (logged, then the server starts anyway) — `bolt.Open` inside `Configure()` creates the file BEFORE seeding, so a failed/partial first bootstrap leaves a 32 KiB empty-buckets DB that every later start treats as initialized; the tree stays empty forever. Signature: DB present since the first-ever start, exactly 32768 bytes, sysusers absent, zero earlier bind attempts (the failure is LAZY — nothing binds to IDM until a login hits autoprovisioning, so a day-one breakage can go unnoticed for weeks). Fix: quarantine the DB (pure config-derived seed data until the FIRST successful login creates a user — zero data loss), restart; bootstrap re-runs from `/etc/opencloud/opencloud.yaml` (config unchanged since init → passwords symmetric with what graph/proxy bind with). Verified 2026-11-03 20:04: re-seeded DB 65536 bytes, DN-string proof `uid={admin,idp,libregraph,reva}` + users/groups OUs present, 0 error-level journal lines since restart. Quarantined evidence: `idm/idm.boltdb.broken-20261103-bootstrap-skipped-empty-tree`. Future IDM-shaped login failure: `strings` the DB for `o=libregraph-idm` DNs FIRST — a poisoned empty tree is invisible in the journal.

14. **IdP avatars are NOT imported — the OIDC `picture` claim is ignored (v7.2.4, source-verified 2026-11-04):** autoprovisioning (`cs3backend.libregraphUserFromClaims`) consumes only `preferred_username`/`name`/`mail`/`sub`/`iss`, and `UpdateUserIfNeeded` updates only displayName+mail — no avatar sync; the web avatar is the initials placeholder unless a photo is uploaded locally. Pocket ID DOES emit `picture` (v2.18.0: `<baseURL>/api/users/<id>/profile-picture.png` under the `profile` scope we already request) — the IdP side is fine. Upstream fix is OPEN PR opencloud-eu/opencloud#2704 (`PROXY_OIDC_PICTURE_CLAIM` + `GRAPH_PROFILE_PICTURE_URL_ALLOWLIST`, fixes #1499) — unmerged in 7.2.4; re-check on the next `opencloud-production` nixpkgs pin bump. Stopgap: upload once in the web UI (Account → Profile → profile picture, `PATCH /graph/v1.0/me/photo/$value`).

## Verify recipes

```bash
systemctl status opencloud.service opencloud-storage-dir.service
journalctl -u opencloud --since today | grep -iE "error|panic"   # expect clean
ss -ltnp | grep -E '9500|9233'                                    # proxy + nats loopback listeners (trap #9: live proxy port is 9500)
# Webfinger discovery (the client config surface):
printf 'GET /.well-known/webfinger?resource=https://cloud.home.lan HTTP/1.1\r\nHost: cloud.home.lan\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect $(getent hosts cloud.home.lan | awk '{print $1}'):443 -servername cloud.home.lan
# IDM tree sanity — root; sysusers + users/groups OUs must be in the BoltDB (trap #13):
sudo strings /mnt/pool/services/opencloud/idm/idm.boltdb | grep -oE 'uid=[a-z-]+,ou=[a-z-]+,o=libregraph-idm' | sort -u   # expect uid=admin, uid=idp, uid=libregraph, uid=reva
# Role audit — assigned role per user (settings metadata blobs, greppable JSON; the Admin bundle self-identifies "name":"admin"):
sudo grep -rhoE '"accountUuid":"[^"]+","roleId":"[^"]+"' /mnt/pool/services/opencloud/storage/metadata/spaces/f1/*/blobs/ | sort -u
# Pocket ID groups of the primary user (read-only sqlite, WAL-safe):
sudo sqlite3 -readonly /var/lib/pocket-id/data/pocket-id.db "SELECT ug.name FROM user_groups ug JOIN user_groups_users m ON m.user_group_id = ug.id JOIN users u ON u.id = m.user_id WHERE u.username = 'lars';"
# Gatus checks: OpenCloud + OpenCloud WebFinger Discovery (Files group)
# Trash/versions on posix (E7): delete a file in the web UI → it MUST appear in the trash; versions accumulate on overwrite.
```

## Rollback ladder

1. Config regression: redeploy previous generation (`nix run .#deploy` on the old commit; state tree is forward-compatible within the production line).
2. Service unwanted: `opencloud.enable = false` (one line) — state subvol + snapshots stay until owner reclaims (`btrfs subvolume delete` needs root).
3. Catastrophic: pool snapshots of `services/opencloud` (7d 4w) restore via btrbk receive-back or direct snapshot revert.

## Owner-hands items (cannot be agent-automated)

- First login at `https://cloud.home.lan` (passkey via Pocket ID) — creates the admin user via the opencloudAdmin group mapping. (2026-11-03: IDM tree re-seeded after the trap-#13 empty-DB bootstrap skip; this login is the final auth verification — a 500 here means trap #13 recurred.)
- Desktop client (nixpkgs `opencloud-desktop`, installed on evo-x2): add server `https://cloud.home.lan`, browser SSO login.
- Android: F-Droid OpenCloud app, server URL, Pocket ID login. Camera upload stays OFF (Immich owns photos).
