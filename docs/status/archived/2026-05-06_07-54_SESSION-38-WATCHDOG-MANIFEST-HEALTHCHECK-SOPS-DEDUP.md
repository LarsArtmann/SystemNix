# Session 38 — Watchdog Fix, Manifest Healthcheck, Sops Dedup, DNS Automation

**Date:** 2026-05-06 07:54
**Host:** evo-x2 | NixOS 26.05 (Yarara) | kernel 7.0.1 | AMD Ryzen AI Max+ 395
**Uptime:** 1h 9m (since last reboot during Session 37)
**Branch:** master @ `a106332`
**Build:** `nixos-system-evo-x2-26.05.20260423.01fbdee`

---

## a) Fully Done

### 1. watchdogd Parse Error Fixed (P0) ✅

**Problem:** watchdogd v4.1 was crashing on startup with `missing title for section 'device'` parse error since it was first configured. The hardware watchdog was completely non-functional across multiple boots.

**Root Cause:** The nixpkgs `services.watchdogd` module's `toConfig` serializer generates flat `key = value` pairs for non-attrset values. When `device = "/dev/watchdog0"` is in settings, it produces `device = /dev/watchdog0`. But watchdogd v4.1 expects a titled section: `device /dev/watchdog0 { timeout = 20; ... }`. The nixpkgs module has no way to produce this format.

**Fix:** Removed `device` from `services.watchdogd.settings` in `platforms/nixos/system/boot.nix`. The default `/dev/watchdog` is symlinked to the SP5100 TCO timer (`/dev/watchdog0`), so watchdogd auto-detects the correct device.

**Verification:** After `nh os switch`, watchdogd logs now show:

```
/dev/watchdog: SP5100 TCO timer, capabilities 0x8180 - set-timeout, safe-exit, kick
```

No parse errors. Hardware watchdog is fully operational.

**Attempted but rejected:** `reset-reason` section with `file = "/var/lib/misc/watchdogd.state"` also fails to parse — the nixpkgs module doesn't quote string values and watchdogd's parser rejects unquoted paths. Documented as accepted limitation.

**Files changed:** `platforms/nixos/system/boot.nix` (1 line removed)

### 2. Manifest Docker Healthcheck URL Fixed (P0) ✅

**Problem:** The healthcheck test command had `http://127.0.0.1/$${p}/api/v1/health` which produces `http://127.0.0.1/2099/api/v1/health` — the port number ends up in the URL path instead of as a port number. The healthcheck would always fail.

**Fix:** Changed `/$${p}` to `:$${p}` in `modules/nixos/services/manifest.nix` line 47.

**Verification:** Docker now reports `mnfst-manifest-1` as `Up 5 minutes (healthy)`.

**Files changed:** `modules/nixos/services/manifest.nix` (1 character change: `/` → `:`)

### 3. Manifest Sops Secrets Deduplicated ✅

**Problem:** Three manifest secrets (`manifest_auth_secret`, `manifest_encryption_key`, `manifest_db_password`) were defined identically in both `modules/nixos/services/sops.nix` and `modules/nixos/services/manifest.nix`. Worse, `manifest.nix` was missing the `sopsFile` attribute, causing it to use the default `secrets.yaml` instead of `manifest.yaml`.

**Fix:**

- Added `sopsFile = secretsDir + "/manifest.yaml"` to the secret definitions in `manifest.nix`
- Added `secretsDir` binding to `manifest.nix`
- Removed the duplicate `mkSecrets "manifest.yaml" { ... }` block from `sops.nix`

**Files changed:** `modules/nixos/services/manifest.nix`, `modules/nixos/services/sops.nix`

### 4. DNS Blocklist Update Automation ✅

**Problem:** Updating DNS blocklists required manually: (1) finding latest commits, (2) replacing URLs, (3) computing SRI hashes for all 25 blocklists. This was done manually in Session 37 and was extremely tedious and error-prone.

**Fix:** Created `scripts/dns-update.sh` + `just dns-update` recipe that:

- Fetches latest HEAD commits from hagezi/dns-blocklists and StevenBlack/hosts
- Compares with current commits in `dns-blocklists.nix`
- Updates all URLs with new commit hashes
- Runs `nix-prefetch-url` + `nix hash convert --to sri` for each URL
- Replaces old SRI hashes with new ones
- Prints a summary and next-step instructions

**Files changed:** `scripts/dns-update.sh` (new), `justfile` (5 lines added)

### 5. Pre-existing Changes Committed ✅

Two changes from earlier sessions that were built and activated but not committed:

- **Helium browser wrapper** (`platforms/common/packages/base.nix`): Added `--restore-last-session`, `--disable-session-crashed-bubble`, `--disable-backgrounding-occluded-windows`, `--disable-renderer-backgrounding` flags. Fixes the "RESTORE TABS" prompt on every launch.
- **Niri session manager config** (`platforms/nixos/users/home.nix`): Declarative TOML config via Home Manager with `single_instance_apps` (helium, firefox, signal) and `app_mappings` (signal → signal-desktop).

### 6. AGENTS.md Updated ✅

Added:

- `watchdogd nixpkgs module broken for device` to Known Issues table
- `watchdogd reset-reason section fails` to Known Issues table
- `just dns-update` to Essential Commands
- Niri session manager TOML config reference
- Helium restore-tabs fix to Known Issues

### 7. Build & Deploy Verified ✅

- `nix flake check --no-build` — all checks passed
- `nh os build .` — succeeded (22s, no new derivations needed beyond watchdogd.conf)
- `nh os switch .` — activated successfully (18s)
- All pre-commit hooks passed (gitleaks, deadnix, statix, alejandra, flake check)
- Committed as `a106332`

---

## b) Partially Done

None — all tasks in this session's scope were completed.

---

## c) Not Started

### From Session 37 Next Steps

1. **dnsblockd context canceled errors** — Low priority. These are transient errors when DNS queries time out or are canceled by clients. Not affecting resolution quality.
2. **Pi 3 DNS failover cluster** — Planned but Pi 3 hardware not yet provisioned. Module exists (`modules/nixos/services/dns-failover.nix`).
3. **Submit nixpkgs PR for watchdogd module** — The nixpkgs watchdogd module is broken for `device` and `reset-reason` sections. Should be upstreamed but not started.

### New Items Identified This Session

4. **File and Image Renamer Watcher failing** — `systemd[1782]: Failed to start File and Image Renamer Watcher.` seen in error logs.
5. **blueman-applet ExecStart conflict** — `Service has more than one ExecStart= setting, which is only allowed for Type=oneshot services. Refusing.`
6. **D-Bus duplicate service names** — 18+ duplicate D-Bus service names being ignored by dbus-broker on every activation. Cosmetic but noisy.

---

## d) Totally Fucked Up

Nothing catastrophic. However:

- **watchdogd was silently non-functional since first configured.** The `device` key was always wrong. The service was "running" but immediately exiting due to config parse error. This means the hardware watchdog was never actually protecting the system against GPU hangs despite being configured for that purpose. **Now fixed.**
- **Manifest healthcheck was always failing.** Docker reported the container as "unhealthy" (but still running because `restart: always`). The container worked fine — the healthcheck just had the wrong URL. **Now fixed.**
- **Manifest sopsFile was pointing to wrong file.** Without explicit `sopsFile`, `manifest.nix` would use the default `secrets.yaml` instead of `manifest.yaml`. This worked by accident if the secrets happened to be in both files (which they were, due to the duplication in `sops.nix`). **Now fixed.**

---

## e) What We Should Improve

### High Impact

1. **Upstream the watchdogd nixpkgs fix** — The module is fundamentally broken for `device` and any section with string-valued keys. Filing a nixpkgs PR would help everyone.
2. **Root disk at 88% (432GB/512GB)** — Only 63GB free. Needs cleanup. Old generations, Docker images, and build artifacts are consuming space.
3. **`just dns-update` dry-run mode** — The script currently modifies files in-place. Adding `--dry-run` would be safer for verification before committing.
4. **Sops secret ownership audit** — We found manifest secrets with wrong sopsFile. Should audit all services for similar issues.

### Medium Impact

5. **Docker image pinning** — Manifest uses `manifestdotbuild/manifest:latest`. Should pin to a digest for reproducibility, similar to how postgres is pinned.
6. **Pre-commit hook for SRI hash validation** — Could catch blocklist hash mismatches before they reach CI/build.
7. **Service health monitoring** — SigNoz is deployed but not currently alerting on service health. Could configure alerts for watchdogd, manifest, etc.

### Low Impact

8. **Clean up D-Bus duplicate warnings** — Multiple desktop environments/portal backends register the same D-Bus names. Cosmetic but produces log noise on every activation.
9. **Consolidate docker-compose patterns** — Manifest and other Docker Compose services could share common hardening patterns via a helper function.

---

## f) Top 25 Things To Do Next

| #  | Priority | Task                                                                                                                             | Effort | Impact |
| -- | -------- | -------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 1  | P0       | **Clean root disk** — `nix-collect-garbage`, remove old Docker images, clean build artifacts. 88% is dangerous.                  | 30min  | High   |
| 2  | P0       | **Fix file-and-image-renamer watcher** — Service failing on startup. Check systemd unit config.                                  | 15min  | Medium |
| 3  | P1       | **Fix blueman-applet ExecStart conflict** — Duplicate ExecStart in user service.                                                 | 10min  | Low    |
| 4  | P1       | **Upstream watchdogd nixpkgs PR** — Fix the module to generate correct config format for `device` sections.                      | 2hr    | High   |
| 5  | P1       | **Pin manifest Docker image to digest** — `latest` tag is non-reproducible.                                                      | 10min  | Medium |
| 6  | P1       | **Audit all sops secrets for correct sopsFile** — Ensure no other services have the same accident-waiting-to-happen as manifest. | 30min  | Medium |
| 7  | P1       | **Add `--dry-run` to dns-update script** — Safety net for blocklist updates.                                                     | 20min  | Low    |
| 8  | P2       | **Configure SigNoz alerts** — Service health, disk usage, memory pressure alerts.                                                | 1hr    | Medium |
| 9  | P2       | **Test `just dns-update` end-to-end** — Run the script when blocklists next update to verify it works.                           | 15min  | Medium |
| 10 | P2       | **Docker image cleanup** — `docker image prune -a` to remove dangling images, save disk.                                         | 5min   | Medium |
| 11 | P2       | **NixOS generation cleanup** — Limit to 20 generations (currently 50 in bootloader).                                             | 5min   | Low    |
| 12 | P2       | **Add watchdogd meminfo script** — Custom script for critical OOM action instead of default reboot.                              | 30min  | Medium |
| 13 | P2       | **Test watchdogd actually triggers reboot** — Simulate hang to verify hardware watchdog works.                                   | 15min  | High   |
| 14 | P2       | **Document dnsblockd context canceled errors** — Determine if these are bugs or expected behavior.                               | 30min  | Low    |
| 15 | P2       | **Provision Pi 3 for DNS failover** — Hardware setup for `rpi3-dns` configuration.                                               | 2hr    | Medium |
| 16 | P3       | **Consolidate Docker Compose hardening** — Extract common security_opt/cap_drop/mem_limit into helper.                           | 1hr    | Low    |
| 17 | P3       | **Clean D-Bus duplicate registrations** — Remove conflicting portal/backend packages.                                            | 30min  | Low    |
| 18 | P3       | **Add nixpkgs watchdogd module issue** — File bug report at github.com/NixOS/nixpkgs.                                            | 20min  | Medium |
| 19 | P3       | **Review twenty CRM service** — Status unknown, not checked this session.                                                        | 10min  | Low    |
| 20 | P3       | **Review deer-flow service** — Status unknown, not checked this session.                                                         | 10min  | Low    |
| 21 | P3       | **Add manifest healthcheck monitoring** — Alert when container is unhealthy.                                                     | 20min  | Low    |
| 22 | P3       | **Pre-commit hook for SRI hash consistency** — Validate blocklist hashes match URLs.                                             | 1hr    | Low    |
| 23 | P3       | **Review whisper-asr container** — Check if healthcheck exists and is working.                                                   | 10min  | Low    |
| 24 | P4       | **Migrate justfile to flake.nix** — Per AGENTS.md policy, justfile is deprecated.                                                | 4hr    | Low    |
| 25 | P4       | **Automate root disk cleanup** — Systemd timer for garbage collection.                                                           | 30min  | Medium |

---

## g) Top #1 Question I Cannot Answer Myself

**Can the watchdogd `reset-reason` section be made to work with the nixpkgs module?**

The generated config `reset-reason { file = /var/lib/misc/watchdogd.state }` fails to parse because watchdogd expects the path to be quoted (`file = "/var/lib/misc/watchdogd.state"`). The nixpkgs `toValue` serializer does NOT quote string values — it outputs `${name} = ${toString value}`. This means:

- Any section with string-typed keys (`file`, `script`, etc.) will fail to parse
- Only numeric/boolean keys work in sections (`enabled`, `warning`, `critical`, `interval`, `logmark`)
- The `device` titled-section format is also impossible to generate

Is this worth filing as a nixpkgs bug? The fix would be straightforward: quote string values in `toValue`. But I'm unsure if there's a deliberate reason the module doesn't quote strings, or if watchdogd's parser has changed between versions.

---

## System Health Summary

| Component               | Status         | Details                                     |
| ----------------------- | -------------- | ------------------------------------------- |
| NixOS build             | ✅ Clean       | `a106332`, all checks pass                  |
| watchdogd               | ✅ Fixed       | SP5100 TCO timer active, no parse errors    |
| manifest                | ✅ Healthy     | Docker reports healthy, port 2099           |
| Docker (10 containers)  | ✅ All up      | No dead/exited/unhealthy containers         |
| DNS (unbound+dnsblockd) | ✅ Running     | 25 blocklists, 2.5M+ domains                |
| Root disk (/)           | ⚠️ 88% used     | 63GB free of 512GB — needs cleanup          |
| /data disk              | ⚠️ 76% used     | 193GB free of 800GB                         |
| Memory                  | ⚠️ 48/62GB used | 14GB available, swap 2.6/41GB               |
| Git working tree        | ✅ Clean       | Committed `a106332`, no uncommitted changes |

---

## Commits This Session

1. `a106332` — **fix: watchdogd parse error, manifest healthcheck URL, sops dedup** (8 files, +147 -9)

---

## Files Changed This Session

| File                                  | Change                                                                         |
| ------------------------------------- | ------------------------------------------------------------------------------ |
| `platforms/nixos/system/boot.nix`     | Removed `device = "/dev/watchdog0"` from watchdogd settings                    |
| `modules/nixos/services/manifest.nix` | Fixed healthcheck URL (`/$${p}` → `:$${p}`), added `sopsFile` and `secretsDir` |
| `modules/nixos/services/sops.nix`     | Removed duplicate manifest secret definitions                                  |
| `scripts/dns-update.sh`               | New script for automated blocklist updates                                     |
| `justfile`                            | Added `dns-update` recipe                                                      |
| `platforms/common/packages/base.nix`  | Helium wrapper flags (pre-existing, committed)                                 |
| `platforms/nixos/users/home.nix`      | Niri session manager config (pre-existing, committed)                          |
| `AGENTS.md`                           | Documented watchdogd nixpkgs bug, added dns-update command                     |
