# OpenCloud — file sync & share platform (pilot)

**Status:** PILOT (2026-10-25, plan `docs/planning/2026-10-25_13-30_SUPERB-opencloud-pilot-adoption.md`) — complement mode (Google Drive stays canonical; google-sync/drive-paperless untouched), LAN/VPN-only exposure.

- **Unit:** `opencloud.service` (monolith: proxy + web + webfinger + storage + embedded IDM/LDAP; the embedded IDP is excluded)
- **Package:** `opencloud-production` 7.2.4 — the PRODUCTION release line. **No downgrade support across lines**: never switch an initialized instance to a different line.
- **Port:** 9200 (loopback only, `lib/ports.nix` `opencloud`), behind Caddy at `cloud.home.lan` (Layer 1 plain reverse_proxy — native OIDC)
- **State:** `/mnt/pool/services/opencloud` — pool SUBVOLUME (Set-B storage), snapshotted nightly by `btrbk-pool` (`services/opencloud` in the subvolume roster). posix storage driver: metadata in **xattrs**, no database.
- **Secrets:** exactly one — `opencloud_admin_password` (sops `platforms/nixos/secrets/opencloud.yaml`, template `opencloud-env` → `services.opencloud.environmentFile`). It feeds `opencloud init` ONLY; the embedded admin has no login surface (idp excluded). Nobody ever needs its value.

## Auth (Pocket ID, Layer 1 native OIDC)

All OpenCloud clients are PUBLIC PKCE clients with predefined client IDs, discovered via OpenCloud's webfinger service (`/.well-known/webfinger`):

| Client | Client ID | Redirect URIs | Scopes |
| --- | --- | --- | --- |
| Web | `web` | `https://cloud.home.lan/oidc-callback.html`, `https://cloud.home.lan/oidc-silent-redirect.html` | openid profile email **groups** |
| Desktop (≥4.0) | `OpenCloudDesktop` | `http://127.0.0.1`, `http://localhost` (loopback port exemption) | openid profile email offline_access **groups** |
| Android | `OpenCloudAndroid` | `oc://android.opencloud.eu` | openid profile email offline_access **groups** |

All three provisioned by `pocket-id-config.provision` (`isPublic = true`, `pkceEnabled = true` — web via the integration registry entry, desktop/android via `extraOidcClients` in `modules/nixos/services/opencloud.nix`).

**Role mapping (declarative, fail-closed):** `PROXY_ROLE_ASSIGNMENT_DRIVER=oidc` + `PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM=groups` + the UPSTREAM DEFAULT mapping — Pocket ID user groups `opencloudAdmin` → role admin, `opencloudUser` → role user. A login whose token carries neither group FAILS (`no roles in user claims`) — intended LAN-only posture; add the user to `opencloudUser` in Pocket ID, never relax the driver.

**Why `groups` in every webfinger scope:** the role mapping reads the groups claim from the token; a client that does not request `groups` produces the login failure above (the historical opencloud-eu/desktop#217 class — desktop <4.0 also ignored webfinger discovery entirely).

**Fallback if desktop breaks on the oidc driver:** flip `PROXY_ROLE_ASSIGNMENT_DRIVER` to `"default"` AND `GRAPH_ASSIGN_DEFAULT_USER_ROLE` to `"true"` in `modules/nixos/services/opencloud.nix` (ONE deploy). Roles already assigned persist; new users then get role `user` implicitly (logins no longer fail-closed on groups).

**Username mapping:** proxy defaults `preferred_username` → `username` (Pocket ID emits `preferred_username`), auto-provisioning on first login (`PROXY_AUTOPROVISION_ACCOUNTS=true`) writes users into the embedded IDM (LDAP).

## Config flow (why `settings` stays empty)

`services.opencloud.settings` is DELIBERATELY empty: the nixpkgs module runs `opencloud-init-config` (`opencloud init`) once — it generates and persists the IDM/service secrets into `/etc/opencloud/opencloud.yaml` (root fs; the running service cannot write there — read-only store config). Skipping init (by providing `settings.opencloud`) would re-generate random secrets on every restart and corrupt the embedded IDM. All overrides ride `services.opencloud.environment` — env vars override YAML deterministically.

`OC_INSECURE=true` (module default): loopback service behind Caddy's TLS; outbound verification to `auth.home.lan` is intentionally lax for the pilot.

## Traps

1. **`rsync -X` or lose the filesystem:** the posix driver stores metadata (trash, versions, shares) in **xattrs** — a plain `rsync -a` copy of the state tree silently drops them. Always `rsync -aX` (btrfs send/receive preserves them natively; btrbk-pool is safe).
2. **No downgrade across release lines** (`opencloud` rolling ↔ `opencloud-production`): upgrades ride future nixpkgs pin bumps — CHANGELOG review per bump.
3. **Role-claim fail-closed** (see above): the "cannot log in" symptom IS the group mapping, not a Pocket ID outage — check `journalctl -u opencloud | grep "no roles"` and the Pocket ID user groups.
4. **`/etc/opencloud/opencloud.yaml` holds the generated secrets** and lives on the ROOT fs — not covered by any snapshot set. Losing it means re-init (fresh secrets → embedded IDM user data is keyed to old secrets; files on the pool survive, users/groups need re-provisioning by logging in again). Documented pilot-acceptable risk.
5. **watch-fs**: not enabled (upstream can watch the posix tree for external changes; adds inotify load — enable deliberately if ever needed).
6. **The pool subvol is created by `opencloud-storage-dir`** (mount-gated oneshot, deploy.sh provisioner-restarted). Do NOT add tmpfiles rules for the stateDir (shadow-dir class); the nixpkgs module's tmpfiles rules are neutralized in the wrapper for exactly that reason.
7. **First deploy ordering:** `opencloud-storage-dir` → `opencloud-init-config` (needs `/etc/opencloud` writable + pool up) → `opencloud.service`. All mount-gated; a detached DAS fails them loudly (RequiresMountsFor).
8. **Internal port family:** ocis binds a band of loopback ports invisible to the port-registry audit (they live in binary defaults, not Exec text). Embedded NATS defaulted to **9234 = signoz-clickhouse-raft** → first deploy died in a bind/strike/start-limit loop; fixed via `NATS_PORT` → **9233** (`lib/ports.nix` `opencloud-nats`). The 9235+ internal gRPC ports are ocis-assigned — on any future internal bind failure, check `ss -ltn` against that band first.

## Verify recipes

```bash
systemctl status opencloud.service opencloud-storage-dir.service
journalctl -u opencloud --since today | grep -iE "error|panic"   # expect clean
ss -ltnp | grep 9200                                             # loopback listener
# Webfinger discovery (the client config surface):
printf 'GET /.well-known/webfinger?resource=https://cloud.home.lan HTTP/1.1\r\nHost: cloud.home.lan\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect $(getent hosts cloud.home.lan | awk '{print $1}'):443 -servername cloud.home.lan
# Gatus checks: OpenCloud + OpenCloud WebFinger Discovery (Files group)
# Trash/versions on posix (E7): delete a file in the web UI → it MUST appear in the trash; versions accumulate on overwrite.
```

## Rollback ladder

1. Config regression: redeploy previous generation (`nix run .#deploy` on the old commit; state tree is forward-compatible within the production line).
2. Service unwanted: `opencloud.enable = false` (one line) — state subvol + snapshots stay until owner reclaims (`btrfs subvolume delete` needs root).
3. Catastrophic: pool snapshots of `services/opencloud` (7d 4w) restore via btrbk receive-back or direct snapshot revert.

## Owner-hands items (cannot be agent-automated)

- First login at `https://cloud.home.lan` (passkey via Pocket ID) — creates the admin user via the opencloudAdmin group mapping.
- Desktop client (nixpkgs `opencloud-desktop`, installed on evo-x2): add server `https://cloud.home.lan`, browser SSO login.
- Android: F-Droid OpenCloud app, server URL, Pocket ID login. Camera upload stays OFF (Immich owns photos).
