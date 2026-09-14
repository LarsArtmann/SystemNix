# Session 15 (full): Hermes Overhaul + dnsblockd + Authelia + Access Control

**Date:** 2026-05-03 02:00 → 06:11 CEST
**Duration:** ~4 hours
**Branch:** master
**Commits:** 12 (see below)

---

## Executive Summary

Complete overhaul of the Hermes AI gateway service: migrated state directory, fixed Opus codec, enabled open user access, fixed silent migration bug, and granted filesystem access. Separately fixed dnsblockd OTel crash, golangci-lint-auto-configure build failure, Authelia password hash, and Caddy forward auth bypass for LAN clients.

---

## A) FULLY DONE ✅

### 1. Hermes State Migration (`/var/lib/hermes` → `/home/hermes`)

| Aspect             | Before                       | After                                           |
| ------------------ | ---------------------------- | ----------------------------------------------- |
| `stateDir` default | `/var/lib/hermes`            | `/home/hermes`                                  |
| User `home`        | `/var/lib/hermes`            | `/home/hermes`                                  |
| `createHome`       | `false`                      | `true`                                          |
| Old dead path      | `/home/.hermes`              | Removed                                         |
| Migration source   | Only `/home/.hermes`         | Both `/home/lars/.hermes` and `/var/lib/hermes` |
| Migration guard    | `ls -A` (broken by tmpfiles) | `state.db > 1MB` (correct)                      |
| `ProtectHome`      | `true` (blocked `/home/`)    | `false`                                         |
| User groups        | `hermes` only                | `hermes` + `users`                              |
| `/home/lars` perms | `700`                        | `770` (group rwx)                               |

**Two migration bugs fixed:**

- **Bug 1:** Migration script looked for `/home/.hermes` (wrong path). Fixed by listing both real source paths.
- **Bug 2:** `tmpfiles.rules` created empty subdirs before migration, making `ls -A` think target was populated. Fixed by checking `state.db` size > 1MB.

**Final state:** `/home/hermes` has full 1.3GB state (state.db 15MB, git repo, config.yaml, sessions, skills, memories).

### 2. Hermes GATEWAY_ALLOW_ALL_USERS

Added `GATEWAY_ALLOW_ALL_USERS=true` to systemd Environment. All Discord users can interact with the bot.

### 3. Hermes Opus Codec Fix

Replaced `pkgs.libopus` in service `path` with `pkgs.binutils`. The `ctypes.util.find_library("opus")` in Python 3.12 uses `_findLib_ld()` which requires `ld` from binutils. `LD_LIBRARY_PATH` to libopus was already set.

### 4. dnsblockd OTel Semconv Fix

**Upstream:** Changed `semconv/v1.26.0` → `semconv/v1.40.0` in `internal/otel/otel.go` to match OTel SDK v1.42.0's `resource.Default()` schema. Also updated vendorHash.

**Result:** dnsblockd starts clean, serves HTTP/HTTPS block pages.

### 5. golangci-lint-auto-configure Build Fix

Three-part fix for stale `go.mod` + Nix sandbox:

1. `go mod tidy` in `postPatch` with `dontFixup` guard (runs only in go-modules derivation which has network)
2. `modPostBuild = "go mod download all"` (ensures all transitive deps cached)
3. GOPROXY set to local go-modules output in main build's `postPatch` so `go mod tidy` resolves offline

### 6. Authelia Password Hash Migration

Migrated `users_database.yml` from bcrypt to argon2id to match the configured password algorithm. Without this, password resets and authentication could fail.

### 7. Caddy Forward Auth Bypass for LAN

Added bypass rule for local network clients (192.168.1.0/24) in Caddy forward auth. LAN clients accessing services don't need to go through Authelia for non-sensitive endpoints.

### 8. ~/.mrconfig Update

Commented out `[.hermes]` entry since hermes state no longer lives at `~/.hermes`.

### 9. Full Pipeline Verification

```
nix flake update                          → ✅ (rate-limited, cached)
nix flake check --all-systems -v          → ✅ all checks passed
nh os build . -v                          → ✅
nh os switch . -v                         → ✅ no failed units
nh os boot . -v                           → ✅ added to bootloader
```

---

## B) PARTIALLY DONE ⚠️

### 1. Old Hermes State Directories

- `/home/lars/.hermes` — 1.3GB, fully migrated. **Safe to delete.**
- `/var/lib/hermes` — 4KB empty. **Safe to delete.**

```bash
trash /home/lars/.hermes
sudo trash /var/lib/hermes
```

### 2. Authelia Password Reset UX

Password reset "emails" go to `/var/lib/authelia-main/notification.txt` (filesystem notifier, no SMTP). The UI says "check your email" but nothing arrives. User has to manually check the file. Not broken, but confusing UX.

---

## C) NOT STARTED ⏳

- SMTP or proper notification for Authelia password resets
- Hermes Discord bot end-to-end verification
- Hermes voice playback testing

---

## D) TOTALLY FUCKED UP 💥

### 1. Migration Script Silently Skipping (FIXED)

The migration script exited 0 (success) while doing nothing because `tmpfiles.rules` created empty subdirs that `ls -A` detected. The service started with 9.6MB of empty state instead of 1.3GB. This went undetected for ~30 minutes until we verified file counts.

**Root cause:** Checking directory content as a migration guard when tmpfiles creates subdirs.

### 2. golangci-lint-auto-configure Took 10+ Iterations

Went through many wrong approaches (LD_PRELOAD, GOFLAGS override, proxyVendor=false) before understanding `buildGoModule` internals. Should have read the source first.

---

## E) WHAT WE SHOULD IMPROVE

### Process

1. **Verify migration results immediately** — Don't just check service start, check file sizes
2. **Read buildGoModule source before fighting it** — `dontFixup`, `$goModules`, `modPostBuild` are all documented
3. **Test migrations with empty AND pre-populated targets** — The tmpfiles race condition would have been caught

### Code

4. **Authelia notifier should use SMTP** — filesystem notifier is confusing for users
5. **Migration should create its own dirs** — Don't depend on tmpfiles ordering
6. **Add post-migration verification** — `du -sh` + file count check
7. **`lib/systemd.nix` should auto-detect `/home/` state dirs** — Set `ProtectHome=false` automatically

---

## F) Top 25 Things We Should Get Done Next

| #  | Priority | Task                                                                                      | Impact        | Effort |
| -- | -------- | ----------------------------------------------------------------------------------------- | ------------- | ------ |
| 1  | P0       | **Trash `/home/lars/.hermes` (1.3GB)**                                                    | Cleanup       | 1min   |
| 2  | P0       | **Trash `/var/lib/hermes` (4KB)**                                                         | Cleanup       | 1min   |
| 3  | P0       | **Commit flake.lock** — monitor365-src bump uncommitted                                   | Git           | 1min   |
| 4  | P1       | **Configure Authelia SMTP notifier** — replace filesystem with real email                 | UX            | 30min  |
| 5  | P1       | **Test hermes Discord bot end-to-end** — send a message, verify response                  | Verification  | 5min   |
| 6  | P1       | **Test hermes voice playback** — join Discord voice channel                               | Verification  | 5min   |
| 7  | P1       | **Run `just health`** — full system health check                                          | Monitoring    | 5min   |
| 8  | P2       | **Add hermes state verification to justfile** — `just hermes-verify`                      | DX            | 15min  |
| 9  | P2       | **Update AGENTS.md with all session changes** — migration fix, group access, caddy bypass | Docs          | 15min  |
| 10 | P2       | **Push all commits to origin** — `git push`                                               | Git           | 1min   |
| 11 | P2       | **Run `just format`** — ensure all Nix files formatted                                    | Hygiene       | 2min   |
| 12 | P2       | **Document dontFixut + modPostBuild pattern in AGENTS.md**                                | Docs          | 10min  |
| 13 | P2       | **Document tmpfiles vs migration ordering gotcha**                                        | Docs          | 10min  |
| 14 | P3       | **Audit all services for ProtectHome conflicts**                                          | Security      | 15min  |
| 15 | P3       | **Add hermes to SigNoz monitoring**                                                       | Observability | 30min  |
| 16 | P3       | **Fix dnsblockd dependabot vulnerability** — check high-severity alert                    | Security      | 15min  |
| 17 | P3       | **Create `lib/buildGoModule.nix` helper** — extract go mod tidy pattern                   | DX            | 30min  |
| 18 | P3       | **Audit all buildGoModule packages** — dnsblockd, netwatch, monitor365                    | Reliability   | 30min  |
| 19 | P3       | **Add `just hermes-backup`** — backup state.db                                            | DX            | 15min  |
| 20 | P3       | **Add hermes service to homepage dashboard**                                              | UX            | 15min  |
| 21 | P4       | **Consider `ProtectHome = "read-only"` for hermes**                                       | Security      | 10min  |
| 22 | P4       | **Silence dnsblockd TLS handshake errors** — client unsupported versions noise            | Observability | 5min   |
| 23 | P4       | **Review systemd hardening across all services**                                          | Security      | 30min  |
| 24 | P4       | **Add password reset instructions to Authelia login page**                                | UX            | 15min  |
| 25 | P4       | **Write integration test for hermes migration script**                                    | Reliability   | 30min  |

---

## G) Top #1 Question I Cannot Figure Out Myself

**What SMTP credentials/server should Authelia use?** I can configure the Authelia notifier to use SMTP instead of filesystem, but I need to know:

- Which SMTP server (Gmail, SendGrid, self-hosted, etc.)
- The from address
- Whether credentials should go in sops secrets

---

## Commits This Session (all 12)

```
209ebbb fix(caddy): bypass forward auth for local network clients
302cb6f chore(deps): update nix-community/NUR to latest revision
4115f8E fix(authelia): migrate bcrypt password hash to argon2id for lars user
6fbf9ef fix(hermes): grant users group full rwx on /home/lars
feefbe8 feat(hermes): add hermes user to 'users' group and grant /home/lars traverse
8cdb3b0 fix(hermes): fix migration script silently skipping when tmpfiles create subdirs
e44721f chore(deps): update flake.inputs monitor365-src and nix-community/NUR to latest revisions
2e9faa1 fix(dnsblockd): update flake.lock with OTel semconv schema fix
a4f11bb chore: update flake.lock + hermes migration status report
a6dcf40 feat(nixos/services/hermes): add ProtectHome=false to systemd service hardening
fe0e7b3 fix(pkgs/golangci-lint-auto-configure): use fakeHash and add go mod tidy for vendor sync
54adbb9 chore: update flake inputs to latest revisions
```

## Files Changed This Session

| File                                    | Change                                                                                                                                                                                                    |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `modules/nixos/services/hermes.nix`     | stateDir → /home/hermes, migration rewrite, GATEWAY_ALLOW_ALL_USERS, binutils opus fix, ProtectHome=false, dontFixup guard, state.db > 1MB migration check, extraGroups=["users"], chmod g+rwx /home/lars |
| `pkgs/golangci-lint-auto-configure.nix` | proxyVendor=true, go mod tidy with dontFixut guard, modPostBuild, GOPROXY for main build, new vendorHash                                                                                                  |
| `justfile`                              | hermes-status path → /home/hermes                                                                                                                                                                         |
| `AGENTS.md`                             | Hermes docs: stateDir, paths, new features                                                                                                                                                                |
| `flake.lock`                            | dnsblockd a0b1879, monitor365-src, golangci-lint-auto-configure-src, NUR                                                                                                                                  |

## Upstream Commits (dnsblockd)

```
713df8c fix(otel): resolve conflicting schema URL error on startup
a0b1879 fix(nix): update vendorHash for semconv v1.40.0 migration
```

## System State

| Component                    | Status                                                                   |
| ---------------------------- | ------------------------------------------------------------------------ |
| Hermes                       | ✅ Running at `/home/hermes`, 1.3GB state, zero warnings                 |
| dnsblockd                    | ✅ Running, no OTel errors, serving block pages                          |
| Authelia                     | ✅ Running, processing requests, argon2id hashes                         |
| Caddy                        | ✅ Running, LAN bypass for forward auth                                  |
| golangci-lint-auto-configure | ✅ Builds successfully                                                   |
| Full pipeline                | ✅ update → check → build → switch → boot all pass                       |
| `/home/lars` perms           | `770 lars:users` — hermes has full access                                |
| `/home/hermes` perms         | `2770 hermes:hermes` — service-owned                                     |
| Old state dirs               | ⚠️ `/home/lars/.hermes` (1.3GB) + `/var/lib/hermes` (4KB) pending cleanup |
| flake.lock                   | ⚠️ monitor365-src bump uncommitted                                        |
