# Immich Server Implementation — Final Status Report

**Date:** 2026-03-29 03:35
**Status:** Implementation Complete — Ready for Deployment on evo-x2
**Git:** Clean tree, all committed, build passes

---

## Session Summary

Added self-hosted Immich photo/video management to NixOS configuration. Researched 4 isolation approaches (direct, nspawn, Incus, MicroVM), chose direct NixOS service. Discovered GPU ML runs CPU-only on NixOS native. Caddy reverse proxy added for `immich.lan`. DNS blocker whitelisted for Immich domains. Daily PostgreSQL backup with 7-day rotation.

---

## A. FULLY DONE

| #  | Item                         | Files                                                                      | Verified                 |
| -- | ---------------------------- | -------------------------------------------------------------------------- | ------------------------ |
| 1  | Immich service module        | `platforms/nixos/services/immich.nix` (55 lines)                           | Build passes             |
| 2  | Caddy reverse proxy          | `platforms/nixos/services/caddy.nix` (17 lines)                            | Build passes             |
| 3  | Import in NixOS config       | `configuration.nix:22-23` (immich + caddy)                                 | Build passes             |
| 4  | DNS blocker whitelist        | `dns-blocker-config.nix` (8 domains)                                       | Build passes             |
| 5  | Daily pg_dump backup timer   | `immich-db-backup` timer + service                                         | Build passes             |
| 6  | Backup script hardening      | `set -euo pipefail`, timestamped filenames, 7-day rotation, completion log | Build passes             |
| 7  | Research doc                 | `docs/research/immich-server-nixos-isolation.md` (153 lines)               | Written                  |
| 8  | Justfile management commands | 6 recipes: status, logs, logs-ml, backup, backups, restart                 | Build passes             |
| 9  | Conflict analysis            | No PG/Redis/port conflicts with existing services                          | Verified                 |
| 10 | GPU reality documented       | CPU-only ML on NixOS native, ROCm 7.2 supports Strix Halo natively         | Researched               |
| 11 | Service name verification    | immich-server, immich-machine-learning, redis-immich, postgresql           | Verified against nixpkgs |
| 12 | Previous status report       | `docs/status/2026-03-28_14-05_IMMICH-IMPLEMENTATION-STATUS.md`             | Written                  |
| 13 | Formatting cleanup           | Removed stale stub files, fixed alejandra formatting                       | All checks pass          |

---

## B. PARTIALLY DONE

| # | Item             | What's Done                                                                       | What's Missing                                         |
| - | ---------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------ |
| 1 | GPU acceleration | Device access enabled (`accelerationDevices = null`), user in video/render groups | ML runs CPU-only — needs Docker ROCm image for GPU ML  |
| 2 | Backup strategy  | Local `pg_dump` with 7-day rotation, hardened script                              | No off-site backup (Borg/Restic to external/remote)    |
| 3 | DNS whitelist    | 8 domains whitelisted for Immich                                                  | Exact-match only; subdomains may need separate entries |

---

## C. NOT STARTED

| #  | Task                                         | Priority | Effort | Why Not Started            |
| -- | -------------------------------------------- | -------- | ------ | -------------------------- |
| 1  | Deploy to evo-x2 (`just switch`)             | Critical | 5 min  | Requires physical access   |
| 2  | Create BTRFS subvolume for `/var/lib/immich` | High     | 5 min  | Runtime operation          |
| 3  | Create admin account at `http://immich.lan`  | Critical | 5 min  | Requires deployed services |
| 4  | Verify all 4 services started                | Critical | 5 min  | Requires deployed services |
| 5  | Upload test photos, verify face detection    | High     | 5 min  | Requires running Immich    |
| 6  | Check ML logs for GPU/CPU provider           | High     | 5 min  | Requires running Immich    |
| 7  | Test backup manually (`just immich-backup`)  | High     | 2 min  | Requires running Immich    |
| 8  | Install mobile app, test LAN upload          | Medium   | 5 min  | User action                |
| 9  | Off-site backup (Borg/Restic)                | High     | 30 min | Needs external storage     |
| 10 | Tailscale Serve for remote access            | Low      | 15 min | LAN only for now           |

---

## D. TOTALLY FUCKED UP / LESSONS LEARNED

| # | Issue                                              | What Happened                                                                             | Fix                         |
| - | -------------------------------------------------- | ----------------------------------------------------------------------------------------- | --------------------------- |
| 1 | Added useless PrivateDevices/DeviceAllow overrides | `accelerationDevices = null` already sets `PrivateDevices = false` — override was a no-op | Removed in later iteration  |
| 2 | Added redundant tmpfiles rules                     | Module creates subdirectories at runtime                                                  | Removed in later iteration  |
| 3 | Misleading "GPU acceleration enabled" commit       | ML runs CPU-only. Only video transcoding might use GPU                                    | Documented CPU-only reality |
| 4 | Forgot `git add` before testing                    | Flake only sees tracked files                                                             | Fixed immediately           |
| 5 | Spun wheels comparing 4 approaches                 | Should have started with simplest option                                                  | Lesson learned              |

---

## E. WHAT WE SHOULD IMPROVE

| # | Improvement                                  | Impact                                       | Effort |
| - | -------------------------------------------- | -------------------------------------------- | ------ |
| 1 | Add Immich to AGENTS.md as a managed service | Future sessions need to know it exists       | 5 min  |
| 2 | Create services registry module              | Single source of truth for service inventory | 30 min |
| 3 | Extract backup pattern into reusable module  | Gitea and Immich both have backup timers     | 45 min |
| 4 | Pin Immich package version                   | Prevent surprise breaking DB migrations      | 2 min  |
| 5 | Add systemd watchdog to immich-server        | Auto-restart on hang                         | 10 min |
| 6 | Add immich commands to `just help` output    | Discoverability                              | 3 min  |
| 7 | Document backup restore procedure            | Backups useless without tested restore       | 15 min |
| 8 | Add header comment about CPU-only ML         | Next reader should know                      | 2 min  |

---

## F. TOP 25 THINGS TO DO NEXT

Sorted by Impact x Urgency / Effort. Each task ≤ 12 min.

| #  | Task                                                        | Impact   | Effort | Category    |
| -- | ----------------------------------------------------------- | -------- | ------ | ----------- |
| 1  | Deploy to evo-x2: `just switch`                             | Critical | 5 min  | Deploy      |
| 2  | Verify all services: `just immich-status`                   | Critical | 2 min  | Verify      |
| 3  | Create admin account at `http://immich.lan`                 | Critical | 5 min  | Setup       |
| 4  | Create BTRFS subvolume for `/var/lib/immich`                | High     | 5 min  | Storage     |
| 5  | Test backup: `just immich-backup`                           | High     | 2 min  | Verify      |
| 6  | Upload test photos, verify face detection                   | High     | 5 min  | Verify      |
| 7  | Check ML provider in logs: `just immich-logs-ml`            | High     | 2 min  | Verify      |
| 8  | Verify backup timer: `systemctl list-timers \| grep immich` | High     | 1 min  | Verify      |
| 9  | Verify Caddy serves `immich.lan`                            | High     | 2 min  | Verify      |
| 10 | Test DNS whitelist completeness                             | Medium   | 5 min  | Verify      |
| 11 | Pin Immich package version                                  | Medium   | 2 min  | Stability   |
| 12 | Add header comment about CPU-only ML to immich.nix          | Medium   | 2 min  | Docs        |
| 13 | Update AGENTS.md with Immich service details                | Medium   | 5 min  | Docs        |
| 14 | Install mobile app, test LAN upload                         | Medium   | 5 min  | Setup       |
| 15 | Add immich commands to `just help` output                   | Low      | 3 min  | Docs        |
| 16 | Add `WatchdogSec=120` to immich-server                      | Low      | 2 min  | Reliability |
| 17 | Set up off-site backup (Borg/Restic)                        | High     | 30 min | Backup      |
| 18 | Document backup restore procedure                           | Medium   | 12 min | Docs        |
| 19 | Test backup restore (`pg_restore` on test DB)               | High     | 12 min | Backup      |
| 20 | Benchmark CPU ML with 100+ photos                           | Medium   | 10 min | Performance |
| 21 | Configure Tailscale Serve for remote access                 | Medium   | 15 min | Remote      |
| 22 | Add BTRFS subvolume to hardware-configuration.nix           | Medium   | 10 min | Storage     |
| 23 | Research Immich GPU ML Docker/ROCm approach                 | Low      | 12 min | Research    |
| 24 | Evaluate Incus for future isolated services                 | Low      | 12 min | Research    |
| 25 | Test full disaster recovery                                 | High     | 30 min | Backup      |

---

## G. TOP #1 QUESTION I CANNOT FIGURE OUT

**How fast is CPU-only ML on the Ryzen AI Max+ 395 (16 Zen 5 cores)?**

ONNX Runtime with 16 CPU cores could handle face detection and CLIP search anywhere from "fine for a family library" to "unusable for 50k+ photos." Only deploying and benchmarking with real photos will answer this. This determines whether we need to invest in the Docker ROCm GPU approach.

---

## Key Files

```
platforms/nixos/services/immich.nix       # Immich service (55 lines)
platforms/nixos/services/caddy.nix        # Caddy reverse proxy for immich.lan
platforms/nixos/system/configuration.nix  # Imports both services
platforms/nixos/system/dns-blocker-config.nix  # Immich DNS whitelist
docs/research/immich-server-nixos-isolation.md  # Research doc
justfile                                  # 6 immich-* management recipes
```

## Relevant Commits

```
fb2f59d chore: remove stale status stub and fix formatting
257e261 docs(status): add Immich implementation final status report
328d0df feat(nixos): add Caddy reverse proxy and local DNS for immich.lan
6241885 feat(justfile): add Immich management commands and harden backup script
72f7437 docs(research/immich): update research document to reflect GPU reality
63918a5 fix(nixos/immich): enable GPU acceleration and restructure database backup
14071fe feat(nixos): add Immich photo/video management service with database backup
34eab2f docs(research): add Immich NixOS isolation strategy research document
```
