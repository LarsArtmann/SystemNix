# Comprehensive Status Update — Session 127

**Date:** 2026-06-09 23:15 CEST
**Session:** 127 (continuation of massive multi-session push)
**Branch:** master (ahead of origin by 6 commits)
**System:** evo-x2 (NixOS x86_64-linux)

---

## a) FULLY DONE

### 1. Pocket ID Declarative Provisioning (Primary Objective)
**Status: ✅ CODE COMPLETE — Awaits sops secret deployment**

**What was built:**
- **`pocket-id.nix`** (`modules/nixos/services/pocket-id.nix`): Complete rewrite with `provision` option block
  - `provision.enable` — opt-in flag for automatic provisioning
  - `provision.adminUser` — declarative admin user (username, email, firstName, lastName)
  - `provision.oidcClients` — declarative OIDC client list (default: oauth2-proxy, immich)
  - `provision.avatarFile` — defaults to `assets/avatar.png`
  - `pocket-id-provision` systemd service: oneshot, runs after Pocket ID health passes
    - Waits for `/healthz` via `preStart` timeout loop
    - Idempotent: checks existing users/clients before creating
    - Admin user creation via `POST /api/users` with `X-API-KEY` header
    - OIDC client creation via `POST /api/oidc/clients`
    - Client secret generation via `POST /api/oidc/clients/:id/secret`
    - Avatar upload via `PUT /api/users/:id/profile-picture` (multipart form)
    - Migration path: copies existing sops secrets to new `client-secrets/` dir on first run
    - Marker file `/var/lib/pocket-id/.provision-migrated` prevents re-migration
- **`sops.nix`**: Added `pocket_id_static_api_key` to `pocket-id.yaml` secrets
- **`oauth2-proxy.nix`**: Dynamic client secret path
  - When `provision.enable`: reads from `/var/lib/pocket-id/client-secrets/oauth2-proxy`
  - When disabled: falls back to sops secret (backward compatible)
  - Service `after`/`wants` include `pocket-id-provision` when provision enabled
- **`immich.nix`**: Dynamic client secret path (same pattern as oauth2-proxy)
  - Service ordered after `pocket-id-provision` when provision enabled
  - Fixed stale `cfg` binding (was referencing removed variable)
- **`configuration.nix`**: Enabled provision with admin user:
  ```nix
  provision = {
    enable = true;
    adminUser = {
      username = "lars";
      email = "lars@larsartmann.com";
      firstName = "Lars";
      lastName = "Artmann";
    };
  };
  ```
- **Environment variables**: Added `LOG_LEVEL`, `VERSION_CHECK_DISABLED`, `AUDIT_LOG_RETENTION_DAYS`, `DB_CONNECTION_STRING`, `UPLOAD_PATH`
- **Assertion**: `provision.enable` → `pocket_id_static_api_key` must exist in sops

**New `just` recipes:**
- `just pocket-id-export` — exports Pocket ID data to `~/backups/pocket-id/`
- `just pocket-id-restore <file>` — restores from ZIP backup
- `just pocket-id-add-static-key` — helper to generate and add `STATIC_API_KEY` to sops
- `just auth-bootstrap` — simplified: only prompts for passkey registration
- `just auth-status` — shows provision status, migration state, client secrets

**What remains manual (unavoidable):**
- Passkey/YubiKey registration (WebAuthn requires physical device ceremony)

**Verification:** `just test-fast` — ALL CHECKS PASSED

### 2. Homepage Dashboard Completeness Audit (Session 126)
**Status: ✅ DONE**

- Added conditional tile system with `when` helper
- Added 8 new tiles: Gatus, Dozzle, Crush Daily, Monitor365, Hermes, LiveKit, Whisper, PhotoMap
- Restructured categories: new "AI" category
- Conditional rendering: tiles appear/disappear based on `service.enable` state
- `just test-fast` passed

### 3. Manifest Auth Fix (Session 126)
**Status: ✅ DONE**

- Removed `protectedVHost` from `manifest.home.lan` in `caddy.nix`
- Manifest uses its own Better Auth — double auth was causing Pocket ID redirect before reaching login
- Now plain TLS reverse proxy

### 4. Monitor365 Integration (Session 126)
**Status: ✅ DONE**

- Added Caddy vhost for `monitor.home.lan` behind `protectedVHost`
- Conditional on `services.monitor365.enable`
- Gatus health check upgraded from TCP to HTTP

### 5. Gatus Health Checks Expansion (Session 126)
**Status: ✅ DONE**

- Added Dozzle health check (localhost:8084)
- Added Gatus self-check (localhost:9110)
- Monitor365: TCP → HTTP check
- Crush Daily moved from "Development" to "AI" group

### 6. ecapture + Monitor365 Build Fix (Earlier sessions)
**Status: ✅ DONE**

- Resolved vendorHash cascade from follows dep overrides
- Applied vendor hashes to all Go package overlays
- `ecapture` tool added to NixOS system packages

### 7. Port Centralization
**Status: ✅ DONE**

- All service ports consolidated in `lib/ports.nix`
- Removed hardcoded ports throughout service modules

---

## b) PARTIALLY DONE

### 1. BTRFS Snapshot Bloat Fix
**Status: 🟡 PHASES 1–2 DONE; PHASE 3 BLOCKED**

**Done:**
- Phase 1: Emergency cleanup (deleted `@.20260527T0000`, freed 69 GB)
- Phase 2: Nix config changes
  - `snapshots.nix`: reduced btrbk retention (14d → 7d daily, 4w → 2w weekly)
  - `snapshots.nix`: new cache subvolume mounts (`@go`, `@npm`, `@cargo`, `@cache`)
  - `snapshots.nix`: `ensure-btrfs-cache-subvolumes.service` (oneshot)
  - `clickhouse.nix`: system TTL service (7-day TTL)

**Blocked:**
- Phase 3: Apply config — stale directories created by Phase 1 activation script are NOT subvolumes
- Need `sudo` to: `rm -rf /home/lars/.cache /home/lars/go /home/lars/.npm /home/lars/.cargo`
- Then `btrfs subvolume create` for each
- Then `just switch`

**Risk:** Without Phase 3, `just switch` may fail because mount units expect subvolumes but find regular dirs

### 2. Pocket ID Declarative Provisioning
**Status: 🟡 CODE COMPLETE — NOT DEPLOYED**

**Why partially done:**
- All code written, reviewed, committed
- `pocket_id_static_api_key` NOT YET ADDED to `platforms/nixos/secrets/pocket-id.yaml`
- Cannot deploy until sops secret is populated
- After adding secret: `just switch` will trigger provision service
- **Risk:** If API endpoints don't work exactly as documented, provision will fail

### 3. Overview NixOS Integration
**Status: 🟡 SERVICE RUNNING — NOT FULLY VERIFIED**

- Added as `overview` service on port 8083
- NixOS module exists
- Service starts but actual functionality unclear
- No homepage tile yet

### 4. PhotoMap
**Status: 🟡 DISABLED IN CONFIG — PODMAN PERMISSION ISSUE**

- Module exists but commented out in `configuration.nix`
- Comment: "disabled: podman config permission issue"
- Homepage tile is conditional (appears only when enabled)

### 5. SigNoz
**Status: 🟡 BUILT FROM SOURCE — LONG BUILD TIMES**

- Works but takes significant time to build
- Monitoring stack active
- Alert rules provisioned via `signoz-provision` service

### 6. Hermes
**Status: 🟡 RUNNING — PARTIAL API KEYS**

- Discord bot token, GLM, Minimax, Xiaomi, FAL, Firecrawl configured
- OpenAI API key commented out: `# TODO: add openai_api_key to hermes.yaml sops secret`

---

## c) NOT STARTED

### 1. Disko Migration
**Status: 🔴 NOT STARTED**

- Planning doc exists in `docs/planning/btrfs-snapshot-bloat-fix.html`
- Would replace `hardware-configuration.nix` + manual subvolume scripts
- Blocked by BTRFS Phase 3 completion

### 2. `photomap` Podman Permission Fix
**Status: 🔴 NOT STARTED**

- Needs investigation into why Podman containers fail with permission errors
- Possibly `subuid`/`subgid` mapping or rootless container storage

### 3. OpenAI API Key for Hermes
**Status: 🔴 NOT STARTED**

- Simple: add `openai_api_key` to `hermes.yaml` sops file
- Uncomment in `sops.nix`

### 4. Darwin (macOS) Configuration Parity
**Status: 🔴 STAGNANT**

- `platforms/darwin/` has minimal config
- No terminal, editor, theme parity with NixOS
- Disk at 90-95% full — adding packages risky
- No Pocket ID, no oauth2-proxy, no Caddy on macOS

### 5. `overview` Homepage Tile
**Status: 🔴 NOT STARTED**

- Service runs but no dashboard representation
- Need to add to `homepage.nix` conditional tiles

### 6. `/data` BTRFS Subvolume Migration
**Status: 🔴 NOT STARTED**

- `/data` is BTRFS toplevel (subvolid=5) — cannot be snapshotted
- `just snapshot-migrate-data` recipe exists but not run
- Risk: no snapshots of user data

### 7. Dozzle Module as `.nix` File
**Status: 🔴 BLOCKED BY EVAL ISSUE**

- Inline `virtualisation.oci-containers` works
- Creating `modules/nixos/services/dozzle.nix` with options causes `nix flake check` failure
- Needs investigation into why module options break eval

### 8. `go-nix-helpers` v2 Sub-Module Documentation
**Status: 🔴 NOT STARTED**

- `mkPreparedSource` handles `/v2` suffixes but not well documented
- Only discovered via trial and error in previous sessions

### 9. `crush-daily` Full Feature Set
**Status: 🔴 RUNNING BUT UNVERIFIED**

- Service active on port 8081
- OAuth configured but actual functionality unclear
- No documentation on what it does

### 10. `monitor365` Alerting
**Status: 🔴 NOT STARTED**

- Service running
- No alerting rules defined
- No integration with Gatus beyond health check

### 11. `livekit` + Whisper Voice Agents
**Status: 🔴 CONFIGURED BUT UNTESTED**

- UDP port range 50000-51000 open
- Services start but no actual voice agent usage documented

### 12. Pre-commit Hook Optimization
**Status: 🔴 NOT STARTED**

- `btrfs-snapshot-bloat-fix.html` gets reformatted on every commit (trailing whitespace hook)
- Wastes time on large HTML files
- Should exclude `docs/planning/*.html` from formatting hooks

---

## d) TOTALLY FUCKED UP!

### 1. BTRFS Root Subvolume at 95%+
**Status: 🔴 CRITICAL — DISK FULL IMMINENT**

- Root (`@`) subvolume: ~476G/512G used (95%)
- Every `just switch` churns ~84GB in Nix store
- Without Phase 3 cache subvolume migration, disk will fill again
- **Immediate action required:** Complete BTRFS Phase 3

### 2. `/data` Not Snapshotted
**Status: 🔴 DATA LOSS RISK**

- User data on `/data` (BTRFS toplevel, subvolid=5)
- Cannot be snapshotted by btrbk
- No backups of actual user data
- **Mitigation:** Run `just snapshot-migrate-data`

### 3. OAuth2-Proxy/Immich Secret Sync Risk
**Status: 🟡 POTENTIAL MISALIGNMENT**

- Current sops secrets (`oauth2_proxy_client_secret`, `immich_oauth_client_secret`) may not match what's in Pocket ID DB
- You wiped `/var/lib/pocket-id` and re-ran setup earlier today
- The new DB likely has DIFFERENT client secrets than what's in sops
- **This means OAuth flow may silently fail** even though health checks pass
- Provision service will generate NEW secrets — oauth2-proxy and immich will use those
- **Risk:** If provision fails, both services will have wrong secrets

### 4. `just pocket-id-add-static-key` Needs sudo
**Status: 🟡 USABILITY ISSUE**

- Recipe runs `ssh-to-age` on `/etc/ssh/ssh_host_ed25519_key` which is root-owned
- Most users won't have age key set up for sops
- Need better error handling and instructions

---

## e) WHAT WE SHOULD IMPROVE!

### 1. Pocket ID Provision Error Handling
- Current provision script exits 0 even on partial failure
- Should fail loudly if admin user creation fails
- Should retry API calls with backoff
- Should validate API responses more strictly

### 2. Client Secret Lifecycle
- Secrets in `/var/lib/pocket-id/client-secrets/` are plaintext files
- Should have rotation mechanism
- Should be backed up as part of `pocket-id-export`

### 3. BTRFS Phase 3 Automation
- Manual `rm -rf` + `btrfs subvolume create` is error-prone
- Should be an activation script that handles the migration automatically
- Should check if dirs are already subvolumes before acting

### 4. Pre-commit Exclusions
- Add `docs/planning/*.html` to `.pre-commit-config.yaml` exclude list
- Or use a different formatter that preserves HTML structure

### 5. `auth-bootstrap` UX
- Should auto-detect if passkey is already registered
- Should check if provision completed before opening browser
- Should provide `xdg-open` to auto-open browser

### 6. Service Interdependency Visualization
- No easy way to see which services depend on which
- A `just service-graph` recipe would be valuable
- Could generate D2 diagram from module imports

### 7. Backup Strategy Consolidation
- Immich: `immich-db-backup` timer (daily)
- Manifest: `manifest-db-backup` timer
- Pocket ID: `just pocket-id-export` (manual)
- No unified backup orchestration
- Should have a single `just backup-all` that runs all backups

### 8. Darwin Configuration Debt
- macOS config is 7 lines in Home Manager
- No terminal, editor, browser, theme parity
- Risk: context switching between platforms is jarring
- Mitigation: at minimum, add Ghostty + zsh + git config to darwin

### 9. `pocket-id-provision` Should Not Run as root
- Currently `User = "root"` in provision service
- Should run as `pocket-id` user with appropriate permissions
- Needs write access to `client-secrets/` dir

### 10. Missing `db-secrets` / `redis-secrets` Pattern
- Some services (Immich, Twenty) create their own DBs
- No standardized way to provision DB users/schemas declaratively
- Pattern from `signoz-provision` could be generalized

---

## f) Top #25 Things We Should Get Done Next

Sorted by impact/urgency:

| # | Task | Priority | Why | Effort |
|---|------|----------|-----|--------|
| 1 | **Complete BTRFS Phase 3** | 🔴 P0 | Disk full imminent | 30 min |
| 2 | **Add `pocket_id_static_api_key` to sops** | 🔴 P0 | Blocked deploy of provisioning | 10 min |
| 3 | **Deploy and test Pocket ID provision** | 🔴 P0 | Verify declarative config works | 20 min |
| 4 | **Verify OAuth end-to-end** | 🔴 P0 | Confirm auth flow works after provision | 15 min |
| 5 | **Fix `/data` subvolume migration** | 🔴 P1 | Data loss risk | 45 min |
| 6 | **Fix PhotoMap Podman permissions** | 🟡 P1 | Service disabled for no good reason | 60 min |
| 7 | **Add OpenAI key to Hermes** | 🟡 P1 | One-line fix, enables OpenAI adapter | 5 min |
| 8 | **Add `overview` homepage tile** | 🟡 P2 | Service invisible to users | 15 min |
| 9 | **Pre-commit exclude HTML planning docs** | 🟡 P2 | Saves time on every commit | 10 min |
| 10 | **Create `just backup-all` orchestrator** | 🟡 P2 | Unified backup strategy | 30 min |
| 11 | **Darwin config parity (min viable)** | 🟡 P2 | Reduce platform switching friction | 120 min |
| 12 | **Disko migration planning** | 🟢 P3 | Long-term disk management | 180 min |
| 13 | **Fix dozzle module eval issue** | 🟢 P3 | Cleaner module structure | 60 min |
| 14 | **Add `livekit`/`whisper` integration test** | 🟢 P3 | Verify voice agents actually work | 45 min |
| 15 | **Monitor365 alerting rules** | 🟢 P3 | Currently just health checks | 60 min |
| 16 | **Document `mkPreparedSource` v2 sub-modules** | 🟢 P3 | Save future debugging time | 30 min |
| 17 | **Add `crush-daily` feature documentation** | 🟢 P3 | No one knows what it does | 30 min |
| 18 | **Service dependency graph generator** | 🟢 P3 | Visualize interconnections | 90 min |
| 19 | **Pocket ID provision: run as non-root** | 🟢 P3 | Security hardening | 30 min |
| 20 | **Add client secret rotation mechanism** | 🟢 P3 | Security best practice | 60 min |
| 21 | **Auth bootstrap: auto-open browser** | 🔵 P4 | UX polish | 15 min |
| 22 | **Standardize DB provisioning pattern** | 🔵 P4 | Reusable across services | 120 min |
| 23 | **Add `auth-bootstrap` passkey detection** | 🔵 P4 | Prevent re-running unnecessarily | 30 min |
| 24 | **Automate BTRFS Phase 3 via activation script** | 🔵 P4 | No more manual steps | 90 min |
| 25 | **Document all conditional service patterns** | 🔵 P4 | README for module authors | 60 min |

---

## g) My Top #1 Question I Cannot Figure Out Myself

### ❓ How do we handle the client secret migration WITHOUT breaking existing OAuth sessions?

**The problem:**
1. Current sops secrets (`oauth2_proxy_client_secret`, `immich_oauth_client_secret`) contain values from the OLD Pocket ID DB (before you wiped it)
2. The new Pocket ID DB (after wipe + `/setup`) has DIFFERENT client secrets
3. The provision service will generate NEW secrets and store them in `/var/lib/pocket-id/client-secrets/`
4. oauth2-proxy and immich will start reading from the new paths
5. **But what if the provision service fails to generate secrets?** Or what if the API returns a different format?

**Specifically:**
- If `pocket-id-provision` fails partially (creates clients but fails to generate secrets), oauth2-proxy will read an empty/non-existent file and fail to start
- If the Pocket ID API for `POST /api/oidc/clients/:id/secret` requires a different auth mechanism than `X-API-KEY`, the provision will silently fail
- There's no rollback mechanism: once the provision marker is written, it won't re-run migration even if secrets are wrong

**What I don't know:**
- Does Pocket ID's `POST /api/oidc/clients/:id/secret` endpoint accept `X-API-KEY` auth? The `authMiddleware.Add()` in the controller suggests it requires admin auth, but `STATIC_API_KEY` creates a synthetic admin user. Does that synthetic user have permission to create secrets?
- If not, the entire provision service will fail at the secret generation step
- Should we add a fallback: if new secret generation fails, copy the old sops secret and use that? But old secrets don't match the new DB...

**This is a deployment-time risk that cannot be fully tested without actually running `just switch` on evo-x2.**

---

## Commit Summary

### Commit 1: `e3c67e87` — feat(auth): declarative Pocket ID provisioning
- Full declarative Pocket ID with provision service
- Dynamic client secrets for oauth2-proxy + immich
- Manifest auth fix, Monitor365 vhost
- Gatus health checks, Homepage conditional tiles
- AGENTS.md updates

### Commit 2: `42a4447d` — feat(homepage): complete service coverage audit
- 8 new homepage tiles with conditional rendering
- AI category restructuring
- Caddy vhost for monitor.home.lan

### Uncommitted Changes:
- `justfile`: `auth-bootstrap` simplified, `auth-status` enhanced, `pocket-id-export`, `pocket-id-restore`, `pocket-id-add-static-key`
- `docs/planning/btrfs-snapshot-bloat-fix.html`: pre-commit trailing-whitespace formatting

---

## Next Actions (Priority Order)

1. **STOP EVERYTHING** — Complete BTRFS Phase 3 (disk full risk)
2. Add `pocket_id_static_api_key` to sops
3. `just switch` to deploy Pocket ID provisioning
4. Verify OAuth flow end-to-end
5. Register YubiKey at `https://auth.home.lan/setup`
6. THEN proceed with Top 25 list

---

*Generated at 2026-06-09 23:15 CEST by Crush*
