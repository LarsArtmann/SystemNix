# PhotoMapAI + Immich Integration — Status Report

**Date:** 2026-03-30 14:42 CEST
**Session Goal:** Add PhotoMapAI for 2D/3D vector-space visualization of Immich photos
**Status:** Partially Complete — Service wired, not yet deployed/verified

---

## a) FULLY DONE

### 1. Research Phase (Complete)

**Immich Built-in "Find Similar Photos"**

- Discovered Immich v1.141.1+ (Sep 2025) has native "Find similar photos" via context menu
- Uses CLIP embeddings + VectorChord (PostgreSQL extension) for cosine similarity search
- Returns flat list of similar images — no spatial/2D/3D visualization
- API: `POST /api/search/smart` with `queryAssetId` parameter (up to 1000 results)

**PhotoMapAI** ([github.com/lstein/PhotoMapAI](https://github.com/lstein/PhotoMapAI))

- Standalone tool by lstein (InvokeAI creator), 68 stars, MIT license
- Uses UMAP to reduce 512D CLIP embeddings → 2D scatter plot
- Interactive: zoom, pan, hover thumbnails, cluster navigation
- Image + text similarity search, DBSCAN clustering, album management
- Docker support: `lstein/photomapai:latest`, port 8050
- Config via YAML (`~/.config/photomap/config.yaml`)
- No Immich integration — purely local filesystem scanner

**ImmichAnalysis** ([github.com/Mustafa744/ImmichAnalysis](https://github.com/Mustafa744/ImmichAnalysis))

- Jupyter notebooks that connect to Immich's PostgreSQL directly
- Fetches CLIP embeddings from `smart_search` table
- Could be extended for custom UMAP/t-SNE visualization

**No existing Immich addon/plugin system** for UI extensions exists.

### 2. Service Configuration (Complete)

**New file: `modules/nixos/services/photomap.nix`**

- OCI container (Docker) running `lstein/photomapai:latest`
- Port: `127.0.0.1:8050` (localhost only, Caddy proxies)
- Volumes:
  - `/var/lib/immich/upload` → `/Pictures:ro` (Immich's actual photos, read-only)
  - `/var/lib/photomap/config` → `/root/.config/photomap` (persistent config)
  - `/var/lib/photomap/index` → `/root/.local/share/photomap` (UMAP index cache)
- Health checks: curl-based, 30s interval
- Auto-start on boot
- Systemd tmpfiles for data directory initialization

**Modified: `modules/nixos/services/caddy.nix`**

- Added `photomap.lan` virtual host
- Bound to `192.168.1.162`, TLS with dnsblockd certificates
- Reverse proxy to `localhost:8050`

**Modified: `platforms/nixos/system/dns-blocker-config.nix`**

- Added `photomap.lan` → `192.168.1.162` DNS A record
- Added HuggingFace CDN domains to whitelist:
  - `huggingface.co` (CLIP model download)
  - `cdn-lfs.huggingface.co`
  - `cdn-lfs-us-1.huggingface.co`

**Modified: `flake.nix`**

- Added `./modules/nixos/services/photomap.nix` to flake-parts imports
- Added `inputs.self.nixosModules.photomap` to evo-x2 modules

### 3. Git Commit (Complete)

- Commit `be873e5`: `feat(nixos/photomap): add PhotoMap AI service for geolocation mapping`
- All 4 files committed with detailed architecture diagram in commit message

---

## b) PARTIALLY DONE

### 1. Nix Flake Check — Timed Out / Not Verified

- `nix flake check --no-build` was running but took too long on this machine (macOS, building for x86_64-linux target)
- **Cannot verify correctness locally** — needs to be tested on evo-x2 or with remote builder
- The configuration is syntactically correct Nix but runtime correctness (OCI container options, volume paths) is unverified

### 2. PhotoMapAI ↔ Immich Integration Depth

- Current approach: read-only mount of `/var/lib/immich/upload` directory
- This gives PhotoMapAI access to the original uploaded files
- **NOT integrated**: PhotoMapAI generates its own CLIP embeddings independently (duplicates work Immich already does)
- The two systems run in parallel but don't share embeddings, metadata, or search indices

---

## c) NOT STARTED

### 1. Deployment to evo-x2

- `sudo nixos-rebuild switch --flake .#evo-x2` has not been run
- Container image `lstein/photomapai:latest` not pulled yet

### 2. PhotoMapAI Initial Setup

- First-launch album creation via web UI (Settings → Manage Albums)
- Point album to `/Pictures` inside the container
- Wait for CLIP embedding generation (potentially hours for large libraries)
- Wait for UMAP dimensionality reduction computation

### 3. Testing & Verification

- Verify container starts healthy: `docker ps` / `systemctl status docker-photomap`
- Verify Caddy proxy: `curl https://photomap.lan` from LAN
- Verify DNS resolution: `nslookup photomap.lan`
- Verify Immich photos are readable: check `/Pictures` inside container
- Verify HuggingFace model download works through DNS blocker

### 4. HuggingFace Whitelist Verification

- The CLIP model download domains were added to the whitelist but not verified
- PhotoMapAI may need additional domains not yet whitelisted
- First startup will reveal if the model download succeeds or gets blocked

### 5. Homepage Dashboard Integration

- `photomap.lan` not added to the Homepage dashboard (`modules/nixos/services/homepage.nix`)
- Should be added alongside existing services (Immich, Gitea, Grafana, etc.)

### 6. Monitoring Integration

- No Grafana dashboard for PhotoMapAI
- No Prometheus metrics export (PhotoMapAI may not expose any)
- Container health status not wired to existing monitoring stack

---

## d) TOTALLY FUCKED UP

### 1. Disk Space Crisis on Development Machine

- `/` partition was at 100% (147MB free) during this session
- Caused multiple tool failures ("no space left on device")
- Fixed by cleaning `.crush/` fetch cache (372MB) and `/tmp/` files
- **Root cause unresolved** — the 229G disk is nearly full

### 2. Flake Check Could Not Complete

- The `nix flake check --no-build` ran for 10+ minutes without completing
- Likely due to cross-compilation overhead (aarch64-darwin host → x86_64-linux target)
- Cannot verify NixOS module correctness from this machine in reasonable time

### 3. HuggingFace Whitelist — Possibly Wrong Approach

- Added HuggingFace to "whitelist" which means these domains BYPASS the ad blocker
- This is correct for model download, but the comment in the commit message said "privacy for AI service" and "blocks HuggingFace" which is WRONG
- The domains are WHITELISTED (allowed), not blocked
- The commit message rationale is misleading — it should say "allows HuggingFace for CLIP model download"

---

## e) WHAT WE SHOULD IMPROVE

### 1. PhotoMapAI Commit Message Was Misleading

The commit says "geolocation mapping" and "Blocks HuggingFace domains to prevent privacy leakage" but the actual feature is **semantic vector-space visualization** and HuggingFace is **whitelisted** (allowed), not blocked. Future readers will be confused.

### 2. Dual CLIP Embedding Computation

Both Immich and PhotoMapAI will compute CLIP embeddings independently for the same images. For large photo libraries, this means:

- Double the ML compute time
- Double the storage for embeddings
- Different embedding models may produce incompatible results

**Better approach**: Extract Immich's existing CLIP embeddings from PostgreSQL and feed them to a custom UMAP visualizer, skipping PhotoMapAI's redundant embedding step.

### 3. Immich Upload Directory Structure

Immich stores files under `/var/lib/immich/upload/` but the internal structure may be `upload/<user-id>/<year>/<month>/<day>/<file>` — nested UUIDs. PhotoMapAI scans recursively so this should work, but worth verifying the actual path structure on the running system.

### 4. Missing Homepage Dashboard Entry

Every other service (Immich, Gitea, Grafana, Homepage itself) is in the dashboard. PhotoMapAI should be too.

### 5. No Backup Strategy for PhotoMapAI Index

The UMAP index and CLIP embeddings in `/var/lib/photomap/index` take significant compute to regenerate. Should be included in the existing backup strategy alongside Immich's DB backup.

---

## f) Top #25 Things to Do Next

### Critical (Deploy what we have)

1. **Deploy to evo-x2**: `sudo nixos-rebuild switch --flake .#evo-x2` on the NixOS machine
2. **Verify container starts**: `docker ps | grep photomap` and check health status
3. **Verify DNS**: `nslookup photomap.lan` from another machine on LAN
4. **Verify Caddy proxy**: `curl -k https://photomap.lan` from LAN
5. **Complete first-launch setup**: Open `https://photomap.lan` in browser, create album pointing to `/Pictures`
6. **Monitor CLIP embedding generation**: First indexing may take hours — watch logs
7. **Verify HuggingFace model download**: Check that CLIP model downloads through DNS blocker whitelist

### Integration (Make it actually useful)

8. **Add PhotoMapAI to Homepage dashboard**: Edit `modules/nixos/services/homepage.nix`
9. **Fix misleading commit message**: Amend or add corrective documentation
10. **Verify Immich upload directory is readable**: `docker exec` into container, `ls /Pictures`
11. **Test image similarity search**: Upload an image and verify results make sense
12. **Test semantic map**: Verify UMAP scatter plot renders correctly
13. **Performance test**: Measure indexing time for full library

### Architecture (Better long-term approach)

14. **Research Immich PostgreSQL embedding extraction**: Connect to `smart_search` table directly
15. **Evaluate replacing PhotoMapAI with custom visualizer**: Use Immich's existing embeddings + UMAP + Plotly
16. **Build a lightweight FastAPI + Three.js visualizer**: Uses Immich API (`queryAssetId`) as backend
17. **Add embedding extraction cron job**: Periodically dump Immich embeddings for custom viz
18. **Investigate VectorChord SQL queries**: Direct cosine similarity from PostgreSQL

### Hardening (Production readiness)

19. **Add PhotoMapAI data to backup schedule**: Include `/var/lib/photomap/` in backups
20. **Add resource limits to container**: Memory/CPU limits for ML workloads
21. **Add container log rotation**: Prevent disk filling from container logs
22. **Pin container image version**: Replace `latest` tag with specific version hash
23. **Add Prometheus metrics**: If PhotoMapAI exposes any, wire to Grafana

### Quality of Life

24. **Add `just` command for PhotoMapAI management**: `just photomap-logs`, `just photomap-restart`
25. **Document the architecture decision**: Create ADR for PhotoMapAI vs custom visualizer choice

---

## g) Top #1 Question I Cannot Answer Myself

**What is the actual directory structure under `/var/lib/immich/upload/` on the running evo-x2 system?**

This is critical because:

- If it's flat files, PhotoMapAI scans them directly — works perfectly
- If it's nested by user UUID (Immich's default), PhotoMapAI still scans recursively but album organization may be confusing
- If it's storage templates with custom paths, the mount point may need adjustment
- Immich may also store files in `/var/lib/immich/library/` (the "external library" path) which we're NOT mounting

**Recommendation**: SSH into evo-x2 and run `ls -la /var/lib/immich/` and `find /var/lib/immich/upload -maxdepth 3 -type d | head -30` to verify the actual structure before deploying. We may need to mount both `upload/` and `library/` directories.
