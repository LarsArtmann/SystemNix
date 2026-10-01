# immich (photo/video management)

**Service:** nixpkgs `services.immich` — `modules/nixos/services/immich.nix` (wrapper: pool storage, OIDC, hardware transcode, backup). Port 2283 (`lib/ports.nix`), loopback. URL: `immich.<domain>` — **Layer 2 protected** vHost via the registry, combined with **native OIDC in-app** (password login disabled): a deliberate hybrid, see below. DNS `immich` in `platforms/common/dns-local.nix`.

Media lives on the HDD pool (`/mnt/pool/services/immich`) — immich-server, immich-machine-learning, and immich-db-backup all carry `RequiresMountsFor` on it: a detached DAS fails the units loudly instead of writing to a root-fs shadow (bank-sync precedent).

## What it serves

| Route                      | Auth                                    | What                                                        |
| -------------------------- | --------------------------------------- | ----------------------------------------------------------- |
| `/`                        | forward-auth (external) / open (LAN)    | Web UI                                                      |
| `/api/*`                   | immich session (OIDC)                   | App + mobile API                                            |
| `/auth/login`, `/user-settings` | immich session (OIDC)              | OAuth callback redirect targets (registered in Pocket ID)   |
| `app.immich:///oauth-callback` | immich session (OIDC)               | Mobile app callback scheme (LAN path — forward-auth exempt) |
| `/api/system_config`       | 401 unauthenticated                     | Gatus probe target — 401 PROVES API up + auth enforced      |

## Ops

- **Auth is a LAYER HYBRID** — in-app: native OIDC via Pocket ID (`oauth.enabled`, issuer `https://auth.<domain>`, clientId `immich`, secret via upstream `clientSecret._secret` from the provisioner path, `autoLaunch` + `autoRegister`, button "Login with Pocket ID"; `passwordLogin.enabled = false` — NO local password fallback). Routing: the registry renders the **protected** vHost — external browsers pass oauth2-proxy forward-auth first, then immich's auto-launch redirect reuses the live `auth.<domain>` session (no second prompt in practice); LAN traffic and the mobile app (a native OIDC flow that cannot carry forward-auth cookies) bypass forward-auth entirely. This is the ONE deliberate exception to "native OIDC ⇒ plain reverse_proxy" — do not "fix" either side without the other.
- **OIDC client registration** — via the registry entry's `oidc` field (fans into `pocket-id-config.provision.extraOidcClients`): callbacks `…/auth/login`, `…/user-settings`, `app.immich:///oauth-callback`; logout callback `https://immich.<domain>`; PKCE enabled. Secret lands in `/var/lib/pocket-id/client-secrets/immich`.
- **Transcoding** — VAAPI on the iGPU: `accelerationDevices = ["/dev/dri/renderD128"]`, `LIBVA_DRIVER_NAME=radeonsi`, user in `video` + `render` groups. ML enabled (face detection / CLIP): MemoryMax 4G, CPUQuota 300%, `HOME=/var/lib/immich`.
- **Redis dual transport** — the app talks to redis over the (faster) unix socket, but `immich.redis.port` opens a loopback-only TCP listener too, because the Gatus `tcp://127.0.0.1:6379` health check cannot reach a socket-only redis.
- **PostgreSQL** — `database.enable = true` on the host's shared local PG, tuned for the immich workload (`shared_buffers 512MB`, `effective_cache_size 2GB`, …) — the settings apply to the shared cluster; keep that in mind when other services join it.
- **DB backup** — `immich-db-backup` daily 01:00 (`Persistent`): `pg_dump --clean --if-exists` as user immich → `<mediaLocation>/database-backup/immich-<ts>.sql`, 7d retention, mount-gated, registered in backup-coordination (maxAge 25h). The media tree itself is covered by the pool's btrbk snapshot set, not a dump.
- **SMTP notifications are admin-UI-ONLY** (Administration → Settings → Notifications; stored in immich's DB — zero module options, survives deploys).
- **Gatus** — "Immich" (`/api/system-config` expecting **401**, 1s budget) in the Media group + redis TCP check; `monitored = true` in the registry (system-health unit watch).

## Related

- [docs/agents/sso-dns.md](../agents/sso-dns.md) — layer table + the immich hybrid footnote; PKCE/client registration flow
- [pocket-id.md](./pocket-id.md) — client provisioning + secret rotation (LoadCredential consumers crash-loop if the secret file vanishes while running)
- [IMMICH-BULL-BOARD-PATCH-GUIDE.md](./IMMICH-BULL-BOARD-PATCH-GUIDE.md) + `immich-bull-board.patch` — queue-inspection patch
- [docs/agents/storage.md](../agents/storage.md) — pool snapshot doctrine covering the media tree
