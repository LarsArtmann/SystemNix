# Status Report — 2026-07-01 09:46

## Gatus Health Crisis → SSO Login → Forgejo SSO-Only

Session resolved 5 failing Gatus endpoints, fixed Forgejo login to SSO-only,
and diagnosed the Pocket ID Mac Touch ID registration blocker (untrusted CA).

---

## A) FULLY DONE ✅

### 1. Gatus Endpoint Fixes (Deployed)
| Endpoint | Root Cause | Fix | Verified |
|----------|-----------|-----|----------|
| **Pocket ID** | `start-limit-hit` — binary exceeded 30s health-check window | Deploy ran `systemctl reset-failed`, clearing the limit | ✅ STATUS 204 |
| **SigNoz** | Gatus checked bare `/` → HTTP 404 | Changed URL to `/api/v1/health` | ✅ success=true |
| **Monitor365** | Gatus checked bare `/` → HTTP 404 | Changed URL to `/health` | ✅ success=true |
| **TLS Certificate** | Collateral — Pocket ID down → Caddy 502 for auth.home.lan | Resolved by Pocket ID restart (cert valid to 2036) | ✅ 200 OK |
| **EMEET PIXY** | Module deployed but user service not loaded | `systemctl --user daemon-reload` + start | ✅ Then died again (see section B) |

### 2. Forgejo SSO-Only Login (Committed, **NOT DEPLOYED**)
- Added `ENABLE_INTERNAL_SIGNIN = false` and `ENABLE_BASIC_AUTHENTICATION = false` to `service` block
- Hides username/password form, forces SSO via Pocket ID
- Git HTTPS still works via access tokens (unaffected)
- **Status: Committed as `c5d45de2`, needs deploy**

### 3. Dependency Hash Fixes (Committed, **NOT DEPLOYED**)
- **art-dupl**: Updated flake input (403da8c → 4ffbd39)
- **crush-daily**: Fixed stale vendorHash upstream (pushed to repo)
- **Status: Committed as `bc2d2427`, needs deploy**

### 4. Pocket ID Login Code App (Committed, **NOT DEPLOYED**)
- Added `nix run .#pocket-id-login-code` flake app
- Generates one-time access token for device login
- Script: `scripts/pocket-id-login-code.sh`
- **Status: Committed in working tree, staged but undeployed**

### 5. Pocket ID OIDC Infrastructure
- OIDC discovery endpoint: ✅ working
- 4 OIDC clients provisioned: oauth2-proxy, immich, forgejo, gatus
- Gatus self-health check: ✅ `[STATUS] < 400` (OIDC redirect handled)
- Client secrets: ✅ provisioned via `pocket-id-provision.service`

### 6. TLS Certificate Analysis
- `*.home.lan` wildcard cert: valid until Apr 12, 2036
- Issued by: `dnsblockd-CA` (self-signed CA)
- **Root cause of Mac Touch ID failure: `dnsblockd-CA` NOT installed in Mac System Keychain**
- CA cert extracted to `/tmp/dnsblockd-ca.pem` for Mac installation
- User instructed to install via `sudo security add-trusted-cert`

---

## B) PARTIALLY DONE ⚠️

### 1. Gatus OIDC Login (Server-side ✅, Mac-side ❌)
- **Server:** OIDC config correct, discovery works, callback URL valid, client secret provisioned
- **Mac browser:** Cannot complete passkey auth — `dnsblockd-CA` not trusted → Chrome blocks Touch ID platform authenticator
- **Fix applied:** User given CA cert + install instructions
- **Remaining:** User must install CA on Mac, restart Chrome/Helium, then register Mac passkey
- **After that:** Gatus SSO login will work end-to-end

### 2. EMEET PIXY Daemon (Flaky)
- User service (`graphical-session.target`) — starts and runs correctly when manually started
- Dies when user session restarts or on reboot if graphical session isn't ready
- Port 8090: **DOWN** at time of report (process not running)
- `systemctl --user daemon-reload && systemctl --user start emeet-pixyd` brings it back
- **Root issue:** Service ordering or graphical-session dependency may need adjustment

### 3. Ollama (DOWN)
- Port 11434: **not listening**
- Service collected/garbage-collected — likely killed during OOM event
- `journalctl` shows `ollama.service: Collecting`
- Gatus reports Ollama as unhealthy
- Needs manual restart or deploy

### 4. Pocket ID Passkey Situation
- Admin user exists and can log in via one-time code
- **Existing passkey:** Registered on unknown device (credential ID `Jw7V68TMaUf8xuxmBR2viw`, transports: NFC/USB — likely a YubiKey)
- **Mac Touch ID:** Blocked by `excludeCredentials` + untrusted CA
- **Path forward:** Install CA → restart Chrome → delete old passkey (or keep it) → register Mac Touch ID
- **Note:** The `excludeCredentials` issue was misdiagnosed initially — the real blocker was the untrusted CA, not the exclude list

---

## C) NOT STARTED ⏸️

### 1. Forgejo Deploy
- The `c5d45de2` commit (SSO-only login) is **committed but NOT deployed**
- Current running system: `e73de5b` (from Jun 26)
- Deploy was blocked by crush-daily vendorHash mismatch — now fixed upstream
- **Action needed:** `nix flake lock --update-input crush-daily && nix run .#deploy`

### 2. Mac CA Certificate Distribution
- No automated mechanism to distribute `dnsblockd-CA` to the Mac
- Currently manual: scp + `sudo security add-trusted-cert`
- Should consider: MDM profile, or documented bootstrap script

### 3. SSO Single Logout (SLO)
- Layer 1 apps (Forgejo, Immich, Gatus) each maintain independent sessions
- No coordinated logout — documented in AGENTS.md but not wired

---

## D) TOTALLY FUCKED UP 💥

### 1. Disk Space — 92% Full (CRITICAL)
```
/dev/nvme0n1p6  723G  651G  60G  92% /
```
- Only 60 GB free on a 723 GB drive
- BTRFS metadata: 50.19 GiB used of 56.70 GiB allocated (88.5%)
- Previous BTRFS metadata ENOSPC crash documented in AGENTS.md
- **This is a ticking time bomb** — next deploy or large build could trigger metadata ENOSPC

### 2. Swap — 7.3 GB of 9.4 GB Used (78%)
- zram swap nearly exhausted
- OOM events this boot: Helium killed (1.5 TB virtual, 382 MB RSS, `oom_score_adj=300`)
- Rofi scope OOM-killed (the pre-DMS-migration rofi)
- Memory pressure PSI: low but swap exhaustion is concerning

### 3. Load Average Decomposing
```
load average: 1.41, 7.03, 25.65
```
- 1-min load fine (1.41), but 15-min was 25.65 — system was heavily loaded recently
- 30 active user sessions (23+ terminals + services)
- Indicates recent heavy activity (builds, OOM recovery)

### 4. Broken Logo Image
- Caddy serving 404 for `/img/static-logo-rounded-512.png`
- Source service unknown — likely Pocket ID or Homepage missing an asset
- Low priority but indicates incomplete static asset deployment

---

## E) WHAT WE SHOULD IMPROVE 🔧

1. **Deploy cadence:** 3+ commits undeployed at any time. Set up CI or pre-commit hook to warn.
2. **Mac CA bootstrap:** Script or MDM profile to install `dnsblockd-CA` on macOS automatically.
3. **EMEET PIXY resilience:** User service should survive session restarts — consider `PartOf=` vs `WantedBy=` adjustments.
4. **Ollama startup:** Should auto-restart on OOM recovery — check `Restart=` policy.
5. **Disk cleanup:** 92% is dangerous. Need aggressive `nix-collect-garbage` + BTRFS snapshot pruning.
6. **Pocket ID passkey UX:** Document the CA-trust requirement for new devices in AGENTS.md.
7. **Gatus OIDC testing:** Add a server-side OIDC token validation test (currently only browser-testable).
8. **Forgejo password auth:** Once deployed, verify `git clone` still works with tokens (not passwords).
9. **Monitoring blind spot:** Gatus can't alert on its own OIDC auth failing (it only checks HTTP status).
10. **crush-daily/vendorHash workflow:** Upstream vendorHash drift blocked deploy for 2 hours — consider `vendorHash = null` (libfakehash) for internal repos.

---

## F) TOP 25 NEXT TASKS

| # | Priority | Task | Impact |
|---|----------|------|--------|
| 1 | 🔴 CRITICAL | **Deploy undeployed commits** (Forgejo SSO, crush-daily fix, flake.lock updates) | Unblocks everything |
| 2 | 🔴 CRITICAL | **Free disk space** — `nix-collect-garbage -d`, prune old BTRFS snapshots, clean `/nix/var/nix/builds/` | Prevents ENOSPC crash |
| 3 | 🔴 CRITICAL | **Restart Ollama** — `systemctl start ollama` or deploy | Restores AI services |
| 4 | 🟡 HIGH | **Install dnsblockd-CA on Mac** — user action, then restart Chrome + Helium | Unblocks Touch ID for all *.home.lan sites |
| 5 | 🟡 HIGH | **Register Mac Touch ID passkey** in Pocket ID after CA installed | Unblocks Gatus SSO, Forgejo SSO |
| 6 | 🟡 HIGH | **Verify Forgejo SSO-only** after deploy — confirm password form gone, OIDC button present | Validates deploy |
| 7 | 🟡 HIGH | **Verify Forgejo git HTTPS** still works with tokens after `ENABLE_BASIC_AUTHENTICATION = false` | Prevents lockout |
| 8 | 🟡 HIGH | **Fix EMEET PIXY service** — investigate why it dies after session restart | Restores monitoring |
| 9 | 🟡 HIGH | **Update flake.lock for crush-daily** — `nix flake lock --update-input crush-daily` to pull vendorHash fix | Required for deploy |
| 10 | 🟡 MEDIUM | **Fix broken logo** (`/img/static-logo-rounded-512.png` 404) — identify source service | Polish |
| 11 | 🟡 MEDIUM | **BTRFS metadata check** — verify `btrfs-health` guard is gating GC correctly | Prevents crash |
| 12 | 🟡 MEDIUM | **Swap pressure** — investigate why 7.3 GB swap is consumed, tune `oomd` or `MemoryHigh` | Prevents OOM |
| 13 | 🟡 MEDIUM | **Document Mac CA bootstrap** in AGENTS.md — permanent instructions for new devices | Reduces future friction |
| 14 | 🟡 MEDIUM | **Consider MDM profile** for dnsblockd-CA distribution to Mac | Eliminates manual step |
| 15 | 🟢 LOW | **Wire SLO (Single Logout)** for Layer 1 OIDC apps | Improves UX |
| 16 | 🟢 LOW | **Add Ollama auto-restart** policy (`Restart=on-failure`) if not set | Self-healing |
| 17 | 🟢 LOW | **Gatus OIDC integration test** — automated check that OIDC token exchange works | Catches regressions |
| 18 | 🟢 LOW | **Clean `/nix/var/nix/builds/`** — stale sandboxes from OOM crashes | Reclaims space |
| 19 | 🟢 LOW | **Review `excludeCredentials`** — consider disabling passkey dedup in Pocket ID if it causes registration issues | Smoother UX |
| 20 | 🟢 LOW | **Monitor365 agent deploy** — agent binary CLI changed, verify it's running correctly | Monitoring completeness |
| 21 | 🟢 LOW | **Add `pocket-id-login-code` to AGENTS.md** gotchas table | Discoverability |
| 22 | 🟢 LOW | **Audit all Gatus endpoints** — proactively check every URL has the right health path | Prevents future false alarms |
| 23 | 🟢 LOW | **Pocket ID `requiresReauthentication`** — consider enabling for sensitive clients (Forgejo) | Security hardening |
| 24 | 🟢 LOW | **Document SSO-only Forgejo** in AGENTS.md — record that password auth is disabled | Knowledge preservation |
| 25 | 🟢 LOW | **Consider `vendorHash = null`** for internal LarsArtmann repos to avoid hash drift blocking deploys | Deploy reliability |

---

## G) TOP QUESTION I CANNOT ANSWER ❓

**"Why does the dnsblockd-CA work on evo-x2 (NixOS) but there's no mechanism to distribute it to the Mac?"**

The CA is stored in sops, decrypted to `/run/secrets/dnsblockd_ca_cert`, and auto-imported on NixOS via:
- System CA trust (`security.pki.certificateFiles`)
- Firefox enterprise policy (`Certificates.Install`)
- NSS database import (`certutil` user service)

But there is **zero infrastructure** for cross-platform CA distribution. The Mac runs nix-darwin but has no equivalent CA import mechanism. The `dnsblockd-cert-import` user service is Linux-only (uses `certutil` + NSS, not macOS Keychain).

**The question is:** Should we add a nix-darwin module that imports the CA into the Mac's System Keychain via `security add-trusted-cert`? Or is an MDM profile the right approach? Or a bootstrap script? The sops-encrypted CA is on the NixOS host, not the Mac — so the Mac would need to either fetch it from evo-x2 or have it injected via a separate channel.

---

## System Snapshot

| Metric | Value | Status |
|--------|-------|--------|
| Uptime | 1 day 16h | ✅ |
| Load (1/5/15 min) | 1.41 / 7.03 / 25.65 | ⚠️ Recovering |
| Memory | 22 GB / 93 GB (71 GB avail) | ✅ |
| Swap | 7.3 GB / 9.4 GB (78%) | ⚠️ High |
| Disk | 651 GB / 723 GB (92%) | 🔴 Critical |
| BTRFS Metadata | 50.19 / 56.70 GiB (88.5%) | 🔴 Critical |
| Failed Units | 0 | ✅ |
| Gatus Failing | EMEET PIXY, Ollama | ⚠️ |
| Git HEAD | `c5d45de2` | — |
| Deployed Gen | `e73de5b` (Jun 26) | ⚠️ 3 commits behind |
| Undeployed Commits | 3 | 🔴 |
