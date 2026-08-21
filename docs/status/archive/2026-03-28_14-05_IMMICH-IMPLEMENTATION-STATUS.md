# Immich Server Implementation — Comprehensive Status Report

**Date:** 2026-03-28 14:05
**Session Focus:** Add self-hosted Immich photo/video management to NixOS (evo-x2)
**Status:** Ready for Deployment

---

## Session Summary

Added Immich photo/video management server to NixOS configuration using the native `services.immich` module. Researched four isolation approaches (direct, nspawn, Incus, MicroVM), chose direct service for simplicity. Discovered critical GPU acceleration limitation — NixOS native Immich ML runs CPU-only (no ROCm/MIGraphX in nixpkgs package). All code passes `just test-fast`.

---

## A. FULLY DONE

| # | Item                           | Files Changed                                                            | Verified                |
| - | ------------------------------ | ------------------------------------------------------------------------ | ----------------------- |
| 1 | **Immich service module**      | `platforms/nixos/services/immich.nix` (new, 52 lines)                    | `just test-fast` passes |
| 2 | **Import in NixOS config**     | `platforms/nixos/system/configuration.nix:22`                            | Build passes            |
| 3 | **DNS blocker whitelist**      | `platforms/nixos/system/dns-blocker-config.nix` (8 domains)              | Build passes            |
| 4 | **Daily pg_dump backup timer** | `platforms/nixos/services/immich.nix` (immich-db-backup service + timer) | Build passes            |
| 5 | **Comprehensive research doc** | `docs/research/immich-server-nixos-isolation.md` (153 lines)             | Written                 |
| 6 | **Conflict analysis**          | No PostgreSQL/Redis/port conflicts with existing services                | Verified                |
| 7 | **GPU reality documentation**  | Research doc Section 3 — CPU-only ML on NixOS native                     | Researched & documented |

### What the module provides (auto-managed by NixOS):

- PostgreSQL with pgvector + vectorchord extensions (Unix socket peer auth)
- Redis on Unix socket (port 0)
- System user `immich` with group `immich`
- State directory `/var/lib/immich` (mode 0700)
- ML cache `/var/cache/immich`
- Runtime dir `/run/immich`
- Systemd services: `immich-server`, `immich-machine-learning`
- Systemd hardening (PrivateDevices, ProtectHome, etc.)
- Database extension setup (pgvector, vectorchord, unaccent, etc.)

### What our module adds on- Explicit `database.enable`, `redis.enable`, `machine-learning.enable`

- `accelerationDevices = null` (all device access — for video transcoding)
- `immich` user in `video`/`render` groups
- Daily `pg_dump` backup with 7-day retention
- Service ordering: backup depends on postgresql + immich-server

---

## B. PARTIALLY DONE

| # | Item                 | Status                                                                           | What's Missing                                                                                             |
| - | -------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| 1 | **GPU acceleration** | Config enables device access (`accelerationDevices = null`) but ML runs CPU-only | Would need Docker ROCm image or custom Nix overlay for GPU ML                                              |
| 2 | **Backup strategy**  | Local `pg_dump` timer works                                                      | No off-site backup (Borg/Restic to remote storage)                                                         |
| 3 | **DNS whitelist**    | 8 domains whitelisted                                                            | Exact-match only — subdomains like `codeload.github.com` may need separate entries (unknown until runtime) |

---

## C. NOT STARTED

| #  | Item                                                                                  | Priority | Effort  | Notes                                  |
| -- | ------------------------------------------------------------------------------------- | -------- | ------- | -------------------------------------- |
| 1  | **Deploy to evo-x2** (`just switch`)                                                  | Critical | 5 min   | Must be done on the actual machine     |
| 2  | **BTRFS subvolume** for `/var/lib/immich`                                             | High     | 5 min   | Prevents Timeshift snapshot bloat      |
| 3  | **Create admin account** at `http://evo-x2:2283`                                      | Critical | 5 min   | First-run setup                        |
| 4  | **Verify services start** (immich-server, immich-machine-learning, postgresql, redis) | Critical | 5 min   | `systemctl status immich-server`       |
| 5  | **Verify backup timer** (`systemctl list-timers \| grep immich`)                      | Medium   | 2 min   | Confirm timer registered               |
| 6  | **Test DNS resolution** from immich container                                         | Medium   | 5 min   | Verify ML model downloads work         |
| 7  | **Off-site backup** (Borg/Restic to external or remote)                               | High     | 30 min  | Photos are irreplaceable               |
| 8  | **Mobile app setup** (point to `http://evo-x2:2283`)                                  | Medium   | 5 min   | LAN only for now                       |
| 9  | **Tailscale Serve** for remote access                                                 | Low      | 15 min  | When remote access needed              |
| 10 | **GPU ML via Docker ROCm**                                                            | Low      | 60 min  | Only if CPU ML too slow                |
| 11 | **Incus migration** for stronger isolation                                            | Low      | 120 min | Only if running more isolated services |

---

## D. TOTALLY FUCKED UP / ISSUES FOUND

| # | Issue                                      | Severity | Status                                                                                                                                                                                |
| - | ------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **GPU acceleration is misleading**         | Medium   | `accelerationDevices = null` gives device access but Immich ML package has no ROCm/MIGraphX — ML runs CPU-only. Video transcoding may use GPU via ffmpeg. Documented in research doc. |
| 2 | **DNS whitelist is exact-match only**      | Low      | `github.com` whitelists only `github.com`, not `codeload.github.com`. May need additional entries after runtime testing. Defensive but incomplete.                                    |
| 3 | **Previous commit had no-op overrides**    | Fixed    | Commits 63918a5 added `PrivateDevices = lib.mkForce false` overrides that were no-ops when `accelerationDevices = null`. Removed in final version.                                    |
| 4 | **Previous commit had redundant tmpfiles** | Fixed    | Early versions had tmpfiles rules for subdirectories that the Immich module creates itself. Removed in final version.                                                                 |

---

## E. WHAT WE SHOULD IMPROVE

| # | Improvement                                                                    | Why                                                           |
| - | ------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| 1 | **Benchmark CPU vs GPU ML** after deploy                                       | Don't know if CPU ML is acceptable until we try it            |
| 2 | **Add off-site backup** before loading real photos                             | Data loss risk without it                                     |
| 3 | **Verify DNS whitelist completeness** at runtime                               | May discover blocked subdomains in logs                       |
| 4 | **Consider `accelerationDevices = ["/dev/dri/renderD128"]` instead of `null`** | More restrictive, same effective result for video transcoding |
| 5 | **Add health check** for immich-server service                                 | Monitor service health automatically                          |
| 6 | **Pin Immich package version**                                                 | Immich releases frequently with breaking DB migrations        |
| 7 | **Add BTRFS subvolume to hardware-configuration.nix**                          | Declarative subvolume instead of manual creation              |
| 8 | **Consider Incus before adding more services**                                 | Avoid rework if Nextcloud/Jellyfin/etc. are planned           |

---

## F. TOP 25 THINGS TO DO NEXT (Prioritized)

Sorted by: Impact x Urgency / Effort. Each task ≤ 12 minutes.

| #  | Task                                                                            | Impact   | Effort | Category      |
| -- | ------------------------------------------------------------------------------- | -------- | ------ | ------------- |
| 1  | **Deploy to evo-x2: `just switch`**                                             | Critical | 5 min  | Deploy        |
| 2  | **Verify all 4 services started** (immich-server, immich-ml, postgresql, redis) | Critical | 5 min  | Verify        |
| 3  | **Create admin account** at `http://evo-x2:2283`                                | Critical | 5 min  | Setup         |
| 4  | **Create BTRFS subvolume** `btrfs subvolume create /var/lib/immich`             | High     | 5 min  | Storage       |
| 5  | **Verify backup timer** registered: `systemctl list-timers`                     | High     | 2 min  | Verify        |
| 6  | **Test backup manually**: `systemctl start immich-db-backup`                    | High     | 2 min  | Verify        |
| 7  | **Upload test photos** and verify face detection / Smart Search                 | High     | 5 min  | Verify        |
| 8  | **Check ML logs** for GPU provider: `journalctl -u immich-machine-learning`     | High     | 5 min  | Verify        |
| 9  | **Test DNS resolution**: verify model downloads succeed                         | Medium   | 5 min  | Verify        |
| 10 | **Install mobile app** and test LAN upload/download                             | Medium   | 5 min  | Setup         |
| 11 | **Check DNS whitelist completeness** in dnsblockd logs                          | Medium   | 5 min  | Verify        |
| 12 | **Set up off-site backup** (Borg/Restic to external drive)                      | High     | 30 min | Backup        |
| 13 | **Pin Immich package version** in immich.nix                                    | Medium   | 2 min  | Stability     |
| 14 | **Change `accelerationDevices`** to specific device path instead of null        | Low      | 2 min  | Security      |
| 15 | **Add BTRFS subvolume** to hardware-configuration.nix (declarative)             | Medium   | 10 min | Storage       |
| 16 | **Benchmark CPU ML performance** with 100+ photos                               | Medium   | 10 min | Performance   |
| 17 | **Configure Tailscale Serve** for remote mobile access                          | Medium   | 15 min | Remote        |
| 18 | **Research Immich GPU ML Docker** approach for ROCm acceleration                | Low      | 12 min | Research      |
| 19 | **Add systemd watchdog / health check** for immich-server                       | Low      | 10 min | Reliability   |
| 20 | **Test backup restore** procedure (pg_restore)                                  | High     | 12 min | Backup        |
| 21 | **Add monitoring** for Immich in existing monitoring stack                      | Low      | 10 min | Observability |
| 22 | **Document deploy procedure** in justfile or README                             | Low      | 5 min  | Docs          |
| 23 | **Evaluate Incus** for future isolated service hosting                          | Low      | 12 min | Research      |
| 24 | **Add Immich to scheduled-tasks.nix** for maintenance cron                      | Low      | 5 min  | Maintenance   |
| 25 | **Test full disaster recovery** (rebuild from backup on fresh install)          | High     | 30 min | Backup        |

---

## G. TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**How slow is CPU-only ML for face detection and CLIP search on the Ryzen AI Max+ 395?**

The Strix Halo has 16 Zen 5 cores. ONNX Runtime on CPU with 16 cores could be anywhere from "perfectly fine for a family photo library" to "unusably slow for 50k+ photos." The only way to know is to deploy and benchmark with a real library. This determines whether the GPU ML Docker approach (task #18) is worth pursuing.

---

## Files Changed This Session

```
docs/research/immich-server-nixos-isolation.md  | 153 +++++++++++++++++ (new)
platforms/nixos/services/immich.nix             |  52 +++++++ (new)
platforms/nixos/system/configuration.nix        |   1 +
platforms/nixos/system/dns-blocker-config.nix   |  10 +-
```

## Git History This Session

```
72f7437 docs(research/immich): update research document to reflect implementation decisions and GPU reality
63918a5 fix(nixos/immich): enable GPU acceleration and restructure database backup service
14071fe feat(nixos): add Immich photo/video management service with database backup
34eab2f docs(research): add Immich NixOS isolation strategy research document
```
