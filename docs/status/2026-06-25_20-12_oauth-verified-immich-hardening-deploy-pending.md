# OAuth Fix Verified, Immich Password-Lock, Hardening Sweep — Full Comprehensive Status

**Date:** 2026-06-25 20:12 CEST
**System:** evo-x2 (NixOS, x86_64-linux, AMD Ryzen AI Max+ 395, 128GB RAM)
**Session:** 153–154
**Uptime:** 2 days, 14 hours (since 2026-06-23 boot after BTRFS crisis)
**Git:** master, up to date with origin, working tree clean
**Deployed:** NO — latest generation is in git but NOT activated on the live system

---

## Executive Summary

The OAuth secret-desync crisis is **resolved and verified working**. The root cause was fully diagnosed (pocket-id-provision migration block seeding stale secrets), the fix is committed (migration block removed, `serviceOneshotDefaults` added), and OAuth login via Pocket ID → Immich succeeded at 19:37:07 (token endpoint returned 200). Immich is back online.

This session also delivered: Immich password login disabled (OAuth-only), OAuth auto-launch enabled, pre-deploy disk-space checks, stale-build cleanup scheduling, `serviceOneshotDefaults` library helper, and 3 new AGENTS.md gotchas.

**One critical caveat:** The latest generation (containing all these fixes) has **not been deployed**. The running system was manually recovered by restarting pocket-id-provision + immich-server, but the declarative changes need `nix run .#deploy` to take permanent effect.

---

## a) FULLY DONE

### OAuth Crisis Resolved

| Item | Detail | Verification |
|------|--------|-------------|
| Root cause identified | pocket-id-provision migration block seeded old sops secret → skip-if-exists → permanent desync | Pocket ID source code confirmed: `POST /secret` always generates NEW; `POST /clients` does NOT auto-generate |
| Migration block removed | Dead code (one-shot, marker already set) eliminated from `pocket-id.nix` | Commit `e1d6aa47` — 34 lines removed |
| Recovery procedure corrected | `systemctl RESTART` (not `start`) — `RemainAfterExit=true` makes start a no-op | AGENTS.md gotcha updated with full explanation |
| OAuth verified working | Token exchange succeeded at 19:37:07 (status=200) | Pocket ID journal: `POST /api/oidc/token status=200 body_size=2510` |
| Immich back online | Server listening on 127.0.0.1:2283 since 19:36:51 | Journal: `Immich Server is listening` |

### Immich Security Hardening

| Setting | Old | New | Commit |
|---------|-----|-----|--------|
| `passwordLogin.enabled` | (not set — defaulted to true) | `false` — password login disabled | `7ecd6301` |
| `oauth.autoLaunch` | `false` — showed login page | `true` — redirects straight to Pocket ID | `7ecd6301` |

### Infrastructure Hardening (from parallel session)

| Item | Detail | Commit |
|------|--------|--------|
| `serviceOneshotDefaults` library helper | Prevents `Restart=always` on `Type=oneshot` services (systemd refuses to start). Defaults to `Restart=no` | `00c3e7b0` |
| Refactored 2 services to `serviceOneshotDefaults` | `dual-wan` (mptcp-endpoint-manager), `forgejo-repos` (ensure-repos) — removed manual `Restart=no` overrides | `37a13d52` |
| Pre-deploy disk-space check | Blocks deploy at ≥95% root usage, warns at ≥85% | `0318ebe2` |
| Pre-deploy stale-build check | Alerts on stale sandboxes in `/nix/var/nix/builds` | `0318ebe2` |
| nix-build-cleanup timer | Every 4h + on boot (was daily — allowed 197 stale builds / 112 GB to accumulate) | `c91e958d` |
| 3 new AGENTS.md gotchas | Stale builds after OOM, BTRFS CoW space reclamation, serviceOneshotDefaults | `bca5f64e` |

### Session Commits (since last status report)

```
bca5f64e docs(agents): add stale-build, BTRFS CoW, serviceOneshotDefaults gotchas
c91e958d fix(scheduled-tasks): run nix-build-cleanup every 4h + on boot
37a13d52 refactor(services): use serviceOneshotDefaults for oneshot services
00c3e7b0 refactor(lib): add serviceOneshotDefaults to prevent Restart=always crash
0318ebe2 feat(scripts): add disk-space and stale-build checks to pre-deploy-check
7ecd6301 feat(immich): disable password login, auto-launch OAuth
e1d6aa47 fix(pocket-id): remove dead migration block, fix recovery procedure
```

**7 commits, 9 files changed, +59 insertions, -42 deletions**

---

## b) PARTIALLY DONE

| Item | What's Done | What Remains |
|------|-------------|--------------|
| **Deploy latest generation** | All changes committed and pushed | **NOT deployed** — running system is old generation. Immich password-disable, autoLaunch, DMS_DISABLE_MATUGEN, serviceOneshotDefaults, pre-deploy checks are all in git but not live |
| OAuth hardening | Password login disabled in code, autoLaunch enabled | Not active until deploy — Immich still accepts passwords on the running generation |
| DMS matugen suppression | `DMS_DISABLE_MATUGEN=1` in quickshell.nix | Not deployed — DMS may still log matugen warnings on next restart |
| Root disk cleanup | nix-build-cleanup timer improved to 4h+boot | Disk still at **96% (487G/512G)** — CRITICAL. Timer hasn't run yet under new schedule |
| SigNoz | Module exists, was running | **Failing** — query logger dir creation issue. Pre-existing, not caused by this session |

---

## c) NOT STARTED

| Item | Context |
|------|---------|
| Reboot evo-x2 | TODO P0: verify boot time (~35s target after NVMe APST fix). 2+ days uptime |
| Pocket ID email verification | TODO P0: test SMTP login notification |
| BTRFS `/data` subvolume migration | TODO P3: `/data` is BTRFS toplevel (subvolid=5), no snapshot protection |
| Cloud backup (off-site) | No BorgBackup/Restic to Hetzner StorageBox yet |
| Pi 3 DNS failover provisioning | Hardware not purchased |
| Gatus OAuth health check | Detect token-endpoint failures proactively |
| Upstream nixpkgs PRs (7 items) | All documented in TODO_LIST.md Priority 5 |

---

## d) TOTALLY FUCKED UP

### My Recovery Recommendation Was Wrong (Fixed)

**What happened:** I recommended `sudo systemctl start pocket-id-provision.service` to regenerate the secret. This was a **no-op** because the service has `RemainAfterExit = true` — after completing, it stays "active (exited)" and `start` skips re-execution.

**Impact:** The secret file was deleted but never regenerated. Immich crashed with `status=243/CREDENTIALS` (LoadCredential couldn't find the file), hit start-limit after 5 retries, and went fully offline.

**Root cause of my mistake:** I didn't read the systemd service definition before recommending the recovery. The `RemainAfterExit = true` was right there at `pocket-id.nix:489`. I also didn't understand that `LoadCredential` makes the file load-bearing at service-start time.

**What I learned:**
1. `systemctl start` on `RemainAfterExit=true` service = no-op. Use `restart`.
2. `LoadCredential` files are load-bearing — never delete while consumer runs.
3. **Research before recommending.** I should have read the service definition and tested the API semantics (which I did do in the follow-up session — confirmed via Pocket ID source that POST /secret always rotates).

**Fix applied:** AGENTS.md gotcha corrected with proper recovery procedure. Migration block removed from provision script. User manually recovered using `systemctl restart`.

### Immich Plugin Warning (Pre-existing, Non-critical)

```
ERROR [Microservices:PluginService] Failed to load plugin immich-core:
  path: '/nix/store/syi1yjpwgmrhf73rqza4yy42rd970rfl-immich-2.6.1/lib/node_modules/immich/build/corePlugin/dist/plugin.wasm'
```

Immich 2.7.5 is running but referencing a `plugin.wasm` from the **2.6.1** Nix store path. This is a stale path reference — likely a Nix packaging issue where the plugin path wasn't updated on version bump. Non-critical: Immich starts and serves normally, but the core plugin system may be degraded. Should be investigated but is not blocking.

---

## e) WHAT WE SHOULD IMPROVE

### Immediate

| Issue | Impact | Fix |
|-------|--------|-----|
| **Changes not deployed** | Immich still accepts passwords, DMS still logs matugen warnings, serviceOneshotDefaults not active | `nix run .#deploy` |
| **Root disk at 96%** | CRITICAL — risk of emergency shell | `nix-collect-garbage -d` or wait for improved cleanup timer |
| **SigNoz failing** | Observability gap | Investigate query logger dir creation |
| **Immich stale plugin.wasm** | Core plugin system degraded | Check nixpkgs immich derivation for version-path mismatch |

### Architecture

| Issue | Impact | Fix |
|-------|--------|-----|
| **No OAuth health check** | OAuth failures invisible until user tries to log in | Add Gatus check that probes the OIDC token endpoint |
| **Provision has no secret verification** | "Secret written" logged but never validated against the DB | After writing secret, do a test token-exchange |
| **Immich `IMMICH_CONFIG_FILE` is powerful but undocumented in our config** | Admin UI changes are silently overridden on restart | Add comment in immich.nix explaining this behavior |
| **`RemainAfterExit=true` on provision is a footgun** | `start` vs `restart` confusion caused an outage | Consider `RemainAfterExit = false` (re-runs every boot) or document prominently |

### Process

| Issue | Fix |
|-------|-----|
| **I recommended a fix without reading the service definition** | READ the systemd unit before recommending systemctl commands |
| **I recommended deleting a file without understanding LoadCredential** | Understand systemd credentials before touching secret files |
| **Session handoff gap** | Parallel session made 5 commits I wasn't aware of — need to check `git log` before starting work |

---

## f) Top 25 Things To Do Next

### Critical

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy latest generation** — `nix run .#deploy` | Activates: password-disable, autoLaunch, matugen fix, serviceOneshotDefaults, pre-deploy checks | 5 min |
| 2 | **Root disk cleanup** — `nix-collect-garbage -d` (96% full!) | Prevents emergency shell | 10 min |
| 3 | **Reboot evo-x2** — verify boot time, clear stale state | TODO P0, 2+ days uptime | 12 min |

### High Priority

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 4 | **Verify Immich password-login disabled** — try password login, confirm it's rejected | Security verification | 2 min |
| 5 | **Verify OAuth auto-launch** — visit immich.home.lan, confirm redirect to Pocket ID | UX verification | 2 min |
| 6 | **Fix SigNoz** — query logger dir creation failure | Restores observability | 30 min |
| 7 | **Verify Pocket ID email sending** — test SMTP notification | TODO P0 | 5 min |
| 8 | **Investigate immich plugin.wasm** — stale 2.6.1 path on 2.7.5 install | Plugin system health | 20 min |
| 9 | **Swap investigation** — 7.4 GiB swap on 93 GiB RAM (79%) | Memory pressure | 15 min |

### Medium Priority

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 10 | **Add OAuth health check to Gatus** — probe OIDC token endpoint | Detect OAuth breakage proactively | 30 min |
| 11 | **Add secret verification to provision script** — test token-exchange after write | Catch desync at provision time | 30 min |
| 12 | **BTRFS `/data` subvolume migration** — create `@data`, update fstab, add to btrbk | Snapshot protection for Docker/Immich/AI | 1-2h |
| 13 | **Hermes: add OpenAI API key to sops** | Enables secondary LLM | 5 min |
| 14 | **Monitor365 upstream fix** — Axum 0.7 route syntax | Unblocks monitoring | 30 min |
| 15 | **Fix deprecated `system` warnings** — replace with `stdenv.hostPlatform.system` | Clean evaluation | 15 min |
| 16 | **Document IMMICH_CONFIG_FILE behavior** — add comment in immich.nix | Prevent confusion about admin UI changes | 5 min |

### Architecture & Quality

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 17 | **Split large modules** — monitor365 (716L), signoz (705L), forgejo (583L) | Maintainability | 2-3h |
| 18 | **Typed NixOS module options** — ports, paths, timeouts | Validation + testing | 3-4h |
| 19 | **Extract dnsblockd** — ~930 lines of Go in Nix config | Standalone repo | 4-6h |
| 20 | **Firewall deny-by-default** — explicit allowlist | Security hardening | 2h |
| 21 | **Remove photomap** — decided to remove, niche + maintenance | Cleanup | 15 min |

### Upstream & Ecosystem

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 22 | **nixpkgs: aw-watcher-utilization poetry-core migration** | Removes custom overlay | 1h |
| 23 | **nixpkgs: KeePassXC Chromium manifests** | Removes workaround | 30 min |
| 24 | **Cloud backup setup** — BorgBackup to Hetzner StorageBox | Disaster recovery | 3-4h |
| 25 | **library-policy: commit correct go.sum upstream** | Removes mkTidyOverride | 30 min |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Should the latest generation be deployed now, given the root disk is at 96%?**

The latest generation contains 7 commits of fixes (OAuth fix, password-disable, matugen suppression, serviceOneshotDefaults, pre-deploy checks, cleanup timer). But deploying requires building a new generation, which needs disk space. At **487G/512G (96%)**, there's only 24G free.

The pre-deploy check I just added (`0318ebe2`) will **block the deploy at ≥95%**. So `nix run .#deploy` may fail on the new check — which is actually correct behavior (I built the check specifically to prevent deploying into a disk-full situation).

The question is: should we:
1. Run `nix-collect-garbage -d` first (frees space from old generations), then deploy?
2. Or deploy first (the new generation is already built — `/nix/store/hwjfnq6...` exists), then garbage collect?

I cannot determine this because I can't run `nix-collect-garbage` (needs root) or `nix run .#deploy` (needs sudo). The user needs to decide the order based on how much space the GC will free.

---

## Runtime Snapshot

```
System:         evo-x2 (NixOS, x86_64-linux, AMD Ryzen AI Max+ 395)
Uptime:         2 days, 14 hours (since 2026-06-23 BTRFS crisis recovery)
Memory:         24G used / 93G total (69G available, 72G buff/cache)
Swap:           7.4G used / 9.4G total (79% — HIGH)
Root disk:      487G / 512G (96% — CRITICAL)
Data disk:      631G / 1.0T (62%)

Immich:         ONLINE (PID 1985401, listening on 127.0.0.1:2283)
OAuth:          WORKING (token exchange verified 19:37:07)
Pocket ID:      ONLINE (v2.8.0)
SigNoz:         FAILING (query logger dir creation)

Deployed:       /nix/store/h6kmhhbgkffys386lxr2zaly24q5wfwy-... (OLD generation)
Latest in git:  /nix/store/hwjfnq609qk9jplsdp0bk85nkqnqfcm5-... (NOT deployed)

Git:            master, up to date with origin, clean working tree
```

---

## Session Timeline

| Time | Event |
|------|-------|
| 18:52 | User asked "Why does PocketID think OAuth works but Immich does not?" |
| 19:03 | Diagnosed: `invalid client secret` at token exchange. Two errors found (state mismatch + secret mismatch) |
| 19:20 | Recommended `sudo rm + systemctl start + restart immich` — **backfired** (RemainAfterExit no-op, LoadCredential crash) |
| 19:20–19:20 | Immich crash-loop: status=243/CREDENTIALS → start-limit-hit |
| 19:36 | User manually recovered: `systemctl restart pocket-id-provision` → secret regenerated → immich started |
| 19:37 | OAuth verified: token exchange 200, user logged in successfully |
| 19:40+ | Deep research: Pocket ID source confirmed API semantics, migration block removed, AGENTS.md corrected |
| 19:50 | Immich password login disabled, autoLaunch enabled |
| 20:00+ | Parallel session: serviceOneshotDefaults, pre-deploy checks, cleanup timer, 3 new gotchas |
| 20:12 | This status report |

---

## File Change Summary (Session 153–154)

### Code changes

| File | Change |
|------|--------|
| `modules/nixos/services/pocket-id.nix` | Removed dead migration block (34→9 lines), added safety comments, removed MIGRATION_MARKER var |
| `modules/nixos/services/immich.nix` | `passwordLogin.enabled = false`, `autoLaunch = true` |
| `lib/systemd/service-defaults.nix` | Added `serviceOneshotDefaults` helper (Restart=no for oneshots) |
| `lib/default.nix` | Export `serviceOneshotDefaults` |
| `modules/nixos/services/dual-wan.nix` | Use `serviceOneshotDefaults` |
| `modules/nixos/services/forgejo-repos.nix` | Use `serviceOneshotDefaults` |
| `platforms/nixos/system/scheduled-tasks.nix` | nix-build-cleanup every 4h + on boot |
| `scripts/pre-deploy-check.sh` | Disk-space (≥95% block, ≥85% warn) + stale-build checks |

### Documentation changes

| File | Change |
|------|--------|
| `AGENTS.md` | Corrected PocketID desync gotcha (restart not start), added stale-builds, BTRFS CoW, serviceOneshotDefaults gotchas |

### Status reports

| File | Change |
|------|--------|
| `docs/status/2026-06-25_19-20_oauth-diagnosis-immich-outage-dms-matugen-fix.md` | Previous report (OAuth diagnosis + outage) |
| `docs/status/2026-06-25_20-12_oauth-verified-immich-hardening-deploy-pending.md` | This report |
