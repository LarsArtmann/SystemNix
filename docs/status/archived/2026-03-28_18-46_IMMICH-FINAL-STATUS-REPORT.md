# Immich Server Implementation — Final Status Report

**Date:** 2026-03-28 18:46
**Status:** Implementation Complete — Ready for Deployment on evo-x2
**Git:** Clean tree, all committed, build passes

---

## A. FULLY DONE

| #  | Item                              | Files                                                              | Verified                        |
| -- | --------------------------------- | ------------------------------------------------------------------ | ------------------------------- |
| 1  | Immich service module             | `platforms/nixos/services/immich.nix` (55 lines)                   | `just test-fast` passes         |
| 2  | Import in NixOS configuration     | `platforms/nixos/system/configuration.nix:22`                      | Build passes                    |
| 3  | DNS blocker whitelist (8 domains) | `platforms/nixos/system/dns-blocker-config.nix`                    | Build passes                    |
| 4  | Daily pg_dump backup timer        | `immich-db-backup` service + timer                                 | Build passes                    |
| 5  | Backup script hardening           | `set -euo pipefail`, timestamped filenames, completion log         | Build passes                    |
| 6  | Comprehensive research doc        | `docs/research/immich-server-nixos-isolation.md` (153 lines)       | Written                         |
| 7  | Justfile management commands      | 6 recipes: status, logs, logs-ml, backup, backups, restart         | Build passes                    |
| 8  | Conflict analysis                 | No PG/Redis/port conflicts                                         | Verified                        |
| 9  | GPU reality documented            | CPU-only ML on NixOS native, ROCm 7.2 supports Strix Halo natively | Researched                      |
| 10 | Service name verification         | immich-server, immich-machine-learning, redis-immich, postgresql   | Verified against nixpkgs source |
| 11 | Previous status report            | `docs/status/2026-03-28_14-05_IMMICH-IMPLEMENTATION-STATUS.md`     | Written                         |

---

## B. PARTIALLY DONE

| # | Item             | What's Done                                                                       | What's Missing                                                                 |
| - | ---------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 1 | GPU acceleration | Device access enabled (`accelerationDevices = null`), user in video/render groups | ML runs CPU-only — needs Docker ROCm image for GPU ML                          |
| 2 | Backup strategy  | Local `pg_dump` with 7-day retention, hardened script                             | No off-site backup (Borg/Restic)                                               |
| 3 | DNS whitelist    | 8 domains whitelisted for Immich                                                  | Exact-match only; subdomains may need separate entries (unknown until runtime) |

---

## C. NOT STARTED

| #  | Task                                         | Priority | Effort  | Why Not Started                                 |
| -- | -------------------------------------------- | -------- | ------- | ----------------------------------------------- |
| 1  | Deploy to evo-x2 (`just switch`)             | Critical | 5 min   | Requires access to the machine                  |
| 2  | Create BTRFS subvolume for Immich            | High     | 5 min   | Runtime operation on evo-x2                     |
| 3  | Create admin account at `http://evo-x2:2283` | Critical | 5 min   | Requires deployed services                      |
| 4  | Verify all 4 services started                | Critical | 5 min   | Requires deployed services                      |
| 5  | Upload test photos                           | High     | 5 min   | Requires running Immich                         |
| 6  | Check ML logs for GPU/CPU provider           | High     | 5 min   | Requires running Immich                         |
| 7  | Test backup manually                         | High     | 2 min   | Requires running Immich                         |
| 8  | Install mobile app                           | Medium   | 5 min   | User action                                     |
| 9  | Off-site backup (Borg/Restic)                | High     | 30 min  | Needs external storage config                   |
| 10 | Tailscale Serve for remote access            | Low      | 15 min  | Deferred per user preference (LAN only for now) |
| 11 | GPU ML via Docker ROCm                       | Low      | 60 min  | Only if CPU ML too slow                         |
| 12 | Incus migration for isolation                | Low      | 120 min | Only if more isolated services needed           |

---

## D. TOTALLY FUCKED UP / LESSONS LEARNED

| # | Issue                                                    | What Happened                                                                                                                                                                             | Fix                                         |
| - | -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| 1 | **Added useless PrivateDevices/DeviceAllow overrides**   | Early commits set `PrivateDevices = lib.mkForce false` — a no-op when `accelerationDevices = null` already sets it false. `DeviceAllow` doesn't restrict without `PrivateDevices = true`. | Removed in later iteration                  |
| 2 | **Added redundant tmpfiles rules**                       | Created tmpfiles for subdirectories that the Immich NixOS module already creates at runtime.                                                                                              | Removed in later iteration                  |
| 3 | **Misleading "GPU acceleration enabled" commit message** | Commit 63918a5 says "enable GPU acceleration" but ML runs CPU-only on NixOS native. Only video transcoding might use GPU via ffmpeg.                                                      | Documented CPU-only reality in research doc |
| 4 | **Forgot to add file to git before testing**             | First `just test-fast` failed because `immich.nix` was untracked. Flakes only see git-tracked files.                                                                                      | `git add` before test                       |
| 5 | **Backup script had no error handling initially**        | Missing `set -euo pipefail`, would silently succeed on partial failure                                                                                                                    | Fixed with hardening                        |
| 6 | **Spun wheels on Incus/nspawn/MicroVM comparison**       | Spent time comparing 4 approaches before landing on the simplest one. Could have started with direct service and iterated.                                                                | Lesson: start simple                        |
| 7 | **DNS whitelist entries are mostly defensive no-ops**    | StevenBlack blocklist doesn't contain github.com, immich.app, or openstreetmap.org. The whitelist doesn't hurt but doesn't help either — yet.                                             | Acceptable defensive measure                |

---

## E. WHAT WE SHOULD IMPROVE

### Architecture

| # | Improvement                                                                                                           | Impact                                                                        | Effort |
| - | --------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------ |
| 1 | **Add Immich to AGENTS.md** as a managed service                                                                      | Future sessions need to know it exists                                        | 5 min  |
| 2 | **Create a services overview module** (like `services/registry.nix`) that lists all services, ports, and dependencies | Single source of truth for service inventory                                  | 30 min |
| 3 | **Extract backup pattern into reusable module**                                                                       | Gitea and Immich both have backup timers — common pattern could be abstracted | 45 min |
| 4 | **Add health check endpoint monitoring**                                                                              | Auto-detect service failures                                                  | 20 min |

### Code Quality

| # | Improvement                                      | Impact                                        | Effort |
| - | ------------------------------------------------ | --------------------------------------------- | ------ |
| 5 | **Use `lib.mkDefault` for overridable defaults** | Allows future overrides without `lib.mkForce` | 5 min  |
| 6 | **Pin Immich package version**                   | Prevents surprise breaking DB migrations      | 2 min  |
| 7 | **Add systemd watchdog** to immich-server        | Auto-restart on hang                          | 10 min |

### Documentation

| #  | Improvement                                                  | Impact                                      | Effort |
| -- | ------------------------------------------------------------ | ------------------------------------------- | ------ |
| 8  | **Add deploy checklist to justfile help**                    | `just help` doesn't mention immich commands | 5 min  |
| 9  | **Document backup restore procedure**                        | Backups are useless without tested restore  | 15 min |
| 10 | **Note CPU-only ML limitation in immich.nix header comment** | Next person reading the file should know    | 2 min  |

---

## F. TOP 25 THINGS TO DO NEXT

Sorted by: Impact x Urgency / Effort (highest first). Each <= 12 min.

| #  | Task                                                                   | Impact   | Effort | Category    |
| -- | ---------------------------------------------------------------------- | -------- | ------ | ----------- |
| 1  | Deploy to evo-x2: `just switch`                                        | Critical | 5 min  | Deploy      |
| 2  | Verify all services started: `just immich-status`                      | Critical | 2 min  | Verify      |
| 3  | Create admin account at `http://evo-x2:2283`                           | Critical | 5 min  | Setup       |
| 4  | Create BTRFS subvolume: `btrfs subvolume create /var/lib/immich`       | High     | 5 min  | Storage     |
| 5  | Test backup: `just immich-backup`                                      | High     | 2 min  | Verify      |
| 6  | Upload test photos, verify face detection works                        | High     | 5 min  | Verify      |
| 7  | Check ML provider: `just immich-logs-ml \| grep -i provider`           | High     | 2 min  | Verify      |
| 8  | Verify backup timer registered: `systemctl list-timers \| grep immich` | High     | 1 min  | Verify      |
| 9  | Pin Immich version in immich.nix                                       | Medium   | 2 min  | Stability   |
| 10 | Add header comment to immich.nix about CPU-only ML                     | Medium   | 2 min  | Docs        |
| 11 | Update AGENTS.md with Immich service details                           | Medium   | 5 min  | Docs        |
| 12 | Test DNS whitelist completeness from immich logs                       | Medium   | 5 min  | Verify      |
| 13 | Add immich commands to `just help` output                              | Low      | 3 min  | Docs        |
| 14 | Add `WatchdogSec=120` to immich-server service                         | Low      | 2 min  | Reliability |
| 15 | Install mobile app, test LAN upload                                    | Medium   | 5 min  | Setup       |
| 16 | Verify DNS whitelist: check immich ML model download succeeds          | Medium   | 5 min  | Verify      |
| 17 | Set up off-site backup (Borg/Restic to external)                       | High     | 30 min | Backup      |
| 18 | Document backup restore procedure                                      | Medium   | 12 min | Docs        |
| 19 | Test full backup restore: `pg_restore` on a test DB                    | High     | 12 min | Backup      |
| 20 | Benchmark CPU ML with 100+ photos                                      | Medium   | 10 min | Performance |
| 21 | Configure Tailscale Serve for remote access                            | Medium   | 15 min | Remote      |
| 22 | Add BTRFS subvolume to hardware-configuration.nix                      | Medium   | 10 min | Storage     |
| 23 | Research Immich GPU ML Docker/ROCm approach                            | Low      | 12 min | Research    |
| 24 | Evaluate Incus for future isolated services                            | Low      | 12 min | Research    |
| 25 | Test full disaster recovery (rebuild from backup)                      | High     | 30 min | Backup      |

---

## G. TOP #1 QUESTION I CANNOT FIGURE OUT

**How fast is CPU-only ML on the Ryzen AI Max+ 395 (16 Zen 5 cores)?**

ONNX Runtime with 16 CPU cores could handle face detection and CLIP search anywhere from "fine for a family library" to "unusable for 50k+ photos." The only way to know is to deploy and benchmark. This determines whether we invest in the Docker ROCm GPU approach.

---

## Git History This Session (Immich-related)

```
0ff6b44 feat(niri): switch to niri-unstable and add window management rules
6241885 feat(justfile): add Immich management commands and harden backup script
61158f7 fix(niri): convert warp-mouse-to-focus to nested enable attribute
6241885 feat(justfile): add Immich management commands and harden backup script
8d55f73 docs(status): add Immich implementation status report for NixOS deployment
72f7437 docs(research/immich): update research document to reflect GPU reality
63918a5 fix(nixos/immich): enable GPU acceleration and restructure database backup service
14071fe feat(nixos): add Immich photo/video management service with database backup
34eab2f docs(research): add Immich NixOS isolation strategy research document
```

## Files Changed (Immich-related)

```
docs/research/immich-server-nixos-isolation.md  | 153 +++ (new)
docs/status/2026-03-28_14-05_IMMICH-*.md        | 140 +++ (new)
platforms/nixos/services/immich.nix              |  55 +++ (new)
platforms/nixos/system/configuration.nix         |   1 +
platforms/nixos/system/dns-blocker-config.nix    |  10 +-
justfile                                         |  73 +++ (immich-* recipes)
```
