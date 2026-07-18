# Immich Server on NixOS: Isolation Strategy Research

**Date:** 2026-03-28
**Status:** Research Complete — Implementation Done
**Target Host:** evo-x2 (GMKtec AMD Ryzen AI Max+ 395, Strix Halo)
**Filesystem:** BTRFS (single NVMe, compress=zstd, noatime)

---

## Executive Summary

Immich is a self-hosted Google Photos alternative with native NixOS module support. Four isolation approaches were evaluated. **Direct NixOS service** chosen for initial deployment. **Incus/LXC** recommended if more isolated services are planned later.

---

## 1. Immich Requirements

### Dependencies (auto-managed by NixOS module)

| Component                           | Purpose                                   | Notes                                  |
| ----------------------------------- | ----------------------------------------- | -------------------------------------- |
| PostgreSQL + pgvector + vectorchord | Metadata + vector search                  | Auto-configured, uses Unix socket auth |
| Redis                               | Caching/queues                            | Auto-configured, Unix socket (port 0)  |
| Machine Learning                    | Face detection, CLIP search, Smart Search | CPU-only on NixOS (see below)          |

### Hardware Requirements

| Component | Minimum            | Recommended |
| --------- | ------------------ | ----------- |
| RAM       | 6 GB               | 8 GB+       |
| CPU       | 2 cores            | 4 cores     |
| Storage   | Library size + 20% | SSD for DB  |

---

## 2. Isolation Approaches Compared

| Factor               | Direct Service    | nspawn          | Incus         | MicroVM   |
| -------------------- | ----------------- | --------------- | ------------- | --------- |
| Setup effort         | Minimal           | Low             | Medium        | High      |
| Isolation strength   | Weak              | Medium          | Strong        | Strongest |
| GPU passthrough      | Module handles it | Manual          | Clean         | Complex   |
| BTRFS snapshots      | Host-level        | Host-level      | Native driver | N/A       |
| Network isolation    | None              | Private network | Bridge/NAT    | Full      |
| Resource limits      | systemd           | Partial         | cgroups v2    | Full      |
| Web management       | No                | No              | Yes           | No        |
| Multi-service future | No                | Yes             | Yes           | Yes       |
| Fully declarative    | Yes               | Yes             | Partial       | Yes       |

---

## 3. Chosen Approach: Direct NixOS Service

### Module Hardening (built into NixOS module)

| `accelerationDevices` | `PrivateDevices` | Effective Access                                          |
| --------------------- | ---------------- | --------------------------------------------------------- |
| `[]` (default)        | `true`           | No devices                                                |
| `null`                | `false`          | All devices                                               |
| `["/dev/dri/..."]`    | `false`          | All devices (DeviceAllow is no-op without PrivateDevices) |

### GPU Acceleration — Likely CPU-Only

The NixOS Immich ML package is built **without ROCm/MIGraphX**. The Docker image bundles ROCm 7.2 with MIGraphX, but the native NixOS package uses CPU-only ONNX Runtime.

- `accelerationDevices = null` gives the service access to `/dev/dri` but the ML code **won't use the GPU**
- Face detection, CLIP search, Smart Search will run on **CPU** (slower but functional)
- GPU acceleration would require running in Docker/Podman with the ROCm image, or a custom NixOS overlay
- ROCm 7.2 (in nixpkgs) supports Strix Halo (gfx1151) natively — no `HSA_OVERRIDE_GFX_VERSION` needed
- The Immich ML component falls back to `CPUExecutionProvider` automatically if GPU init fails

### Ollama GPU Competition

Ollama (`ai-stack.nix`, port 11434) shares the same AMD GPU. Since Immich ML runs CPU-only, there is **no conflict**. If GPU acceleration is added later, both services would compete for GPU memory.

---

## 4. Considerations for This Setup

### DNS Blocker Whitelist

Added to `dns-blocker-config.nix`:

- `api.immich.app`, `immich.app` — version checks
- `github.com`, `github-releases.githubusercontent.com`, `objects.githubusercontent.com` — ML model downloads
- `nominatim.openstreetmap.org`, `tile.openstreetmap.org` — reverse geocoding, map tiles

### Storage Layout (BTRFS)

Consider a dedicated subvolume for Immich data:

- `@immich` — media, thumbnails, transcoded video
- Keeps Timeshift snapshots from bloating with media data
- BTRFS compression (`zstd`) helps with thumbnails
- Single NVMe means DB and media share the same physical device
- Create at deploy time: `btrfs subvolume create /var/lib/immich`

### Backup Strategy

Daily `pg_dump` timer configured. Photos are irreplaceable — add off-site backup:

1. DB consistency: `pg_dump` before backup (configured)
2. Local backup: Borg/Restic to external drive or NAS
3. Off-site backup: Borg to remote storage (e.g., rsync.net, S3)

### Reverse Proxy / Remote Access (Future)

Mobile app requires a reachable HTTPS URL. Options:

- Tailscale Serve/Funnel — cleanest for LAN-only
- Caddy + Let's Encrypt — if exposing publicly

### Existing Service Conflicts

- **Docker**: Coexists fine. Immich uses native NixOS services, not Docker.
- **PostgreSQL**: Immich module auto-provisions its own PG instance (Unix socket, peer auth). No port conflict (Gitea uses SQLite).
- **Redis**: No other Redis service exists in the config.
- **Ollama**: Shares GPU but no conflict since Immich ML is CPU-only.

---

## 5. Implementation Status

### Completed

- [x] `platforms/nixos/services/immich.nix` — service module with backup timer
- [x] Import in `configuration.nix`
- [x] DNS blocker whitelist for Immich domains
- [x] Build verification (`just test-fast` passes)
- [x] Research doc

### Deploy Steps (on evo-x2)

1. `git add platforms/nixos/services/immich.nix` (already staged)
2. `just switch`
3. Optionally create BTRFS subvolume first: `btrfs subvolume create /var/lib/immich`
4. Access `http://evo-x2:2283` to create admin account
5. Install mobile app, point to `http://evo-x2:2283`

### Future Work

- [ ] Off-site backup (Borg/Restic)
- [ ] Tailscale Serve for remote access
- [ ] GPU acceleration via Docker ROCm image (if CPU ML is too slow)
- [ ] Incus migration if more isolated services needed

---

## Sources

- NixOS Immich module: `nixpkgs/nixos/modules/services/web-apps/immich.nix`
- NixOS Incus module: `nixpkgs/nixos/modules/virtualisation/incus.nix`
- NixOS Wiki: https://wiki.nixos.org/wiki/Immich
- Immich docs: https://immich.app/docs/overview
- Incus docs: https://linuxcontainers.org/incus/
- Declarative Incus issue: https://github.com/NixOS/nixpkgs/issues/386841
- AMD Strix Halo ROCm: https://github.com/th3cavalry/GZ302-Linux-Setup
