# Comprehensive SystemNix Status Report

**Date:** 2026-03-31 20:31 CEST
**Branch:** master
**Ahead of origin:** 1 commit (not pushed)
**Platform:** macOS (development) → NixOS evo-x2 (deployment target)

---

## a) FULLY DONE

### 1. PhotoMapAI + Immich Integration — Root Cause Fixed

**Problem:** PhotoMapAI was not automatically discovering all images from the local Immich server.

**Root causes identified and fixed:**

| Root Cause                                          | Impact                                                                                                             | Fix                                                                              |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| Only `upload/` mounted, not `library/`              | Immich migrates processed photos to `library/` via storage templates — those were invisible to PhotoMapAI          | Added `library/` as separate read-only mount                                     |
| No `config.yaml` provided                           | PhotoMapAI requires a YAML config defining albums with `image_paths` — empty config dir meant zero albums          | Declarative `config.yaml` generated via `pkgs.writeText`, symlinked via tmpfiles |
| `photomap_index` mounted inside `/Pictures/upload/` | Index volume nested inside Immich's directory tree — pollution risk, permission issues, breaks read-only guarantee | Separate `/Pictures/index` writable volume outside Immich tree                   |

**Commit:** `76de011` — `feat(photomap): refactor container configuration with read-only volumes and declarative config`

**Current `photomap.nix` architecture:**

- **Volumes:**
  - `/var/lib/immich/upload` → `/Pictures/upload:ro` (read-only)
  - `/var/lib/immich/library` → `/Pictures/library:ro` (read-only)
  - `/var/lib/photomap/index` → `/Pictures/index` (writable, for embeddings)
  - `/var/lib/photomap/config` → `/root/.config/photomap` (config dir)
  - `/var/lib/photomap/data` → `/root/.local/share/photomap` (data dir)
- **Config:** Declarative `config.yaml` with `immich` album pointing to both `/Pictures/upload` and `/Pictures/library`
- **Index:** `immich-embeddings.npz` stored in dedicated writable volume
- **Startup:** `ExecStartPre` waits for Immich health check (up to 60s), `Restart=on-failure`, `RestartSec=10s`

### 2. PhotoMapAI Container Startup Fix

**Commit:** `6cd668e` — `fix(services): resolve photomap container startup and caddy port conflicts`

- Added `ExecStartPre` wait script polling `localhost:2283/api/server-info/ping`
- Added `Restart=on-failure` and `RestartSec=10s`
- Added `network-online.target` dependency
- Fixed Caddy `auto_https off` to prevent port 80 conflict with dnsblockd

### 3. ContainerService Type System

**Commit:** `d20d18c` — `feat(types): add ContainerService type system for OCI containers`

- `ContainerTypes.nix`: HealthCheck, Dependency, Volume, Port, ContainerService types
- `ContainerService.nix`: `mkContainerService`, `mkContainerServices`, `mkWaitScript` helpers
- Automatic tmpfiles rules and systemd restart policy generation

### 4. pnpm Package Fix

**Commit:** `3a5547a` — `fix(packages): replace nodePackages.pnpm with top-level pnpm`

- `nodePackages` removed from nixpkgs on 2026-03-03
- Replaced with top-level `pnpm` attribute

### 5. SilentSDDM Integration

**Commits:** `1437c98`, `ad268ce`, `4cf7df9`, `287825f`

- SilentSDDM theme with catppuccin-mocha colors
- Display manager consolidation with `defaultSession = "niri"`
- Alejandra formatting fixes

### 6. Niri Compositor Refinements

**Commits:** `39fae5b`, `0cf35ef`, `b7ce7cb`

- Switched from Hyprland to Niri (complete)
- 95% opacity on non-floating windows
- Removed deprecated `swww` init

### 7. Flake Lock Updates

**Commit:** `e022038` — All inputs updated to latest revisions

### 8. DNS Blocker `.lan` Domain Filtering (unstaged)

Three files modified to skip `.lan` domains in the DNS blocker pipeline:

- `pkgs/dns-blocklist.nix` — Nix blocklist parser skips `.lan` suffix
- `pkgs/dnsblockd-processor/main.go` — Go processor skips `.lan` domains
- `platforms/nixos/programs/dnsblockd/main.go` — Added `isLANDomain()` helper, returns 403 for `.lan` in block handler

**Status:** Code changes complete, NOT YET COMMITTED.

---

## b) PARTIALLY DONE

### 1. PhotoMapAI Deployment to evo-x2

- Configuration is complete and passes `nix flake check --no-build`
- **NOT deployed yet** — `sudo nixos-rebuild switch --flake .#evo-x2` has not been run on the NixOS machine
- Container image `lstein/photomapai:latest` not pulled yet
- First-launch album creation and CLIP embedding generation not started

### 2. DNS Blocker `.lan` Domain Protection

- Code changes are complete in all 3 files
- Passes Go compilation checks
- **NOT committed** — changes sitting in working tree
- **NOT deployed** — needs `nixos-rebuild switch` on evo-x2
- Binaries (`dnsblockd`, `dnsblockd-processor`) are compiled but untracked in git — should be gitignored

### 3. ContainerService Type System → Not Yet Applied to photomap.nix

- Type definitions created in `platforms/common/core/ContainerService.nix`
- `photomap.nix` still uses raw `virtualisation.oci-containers` — not refactored to use the type system
- The type system is available but not consumed by any actual service module yet

---

## c) NOT STARTED

### 1. PhotoMapAI Homepage Dashboard Integration

- `photomap.lan` not added to `modules/nixos/services/homepage.nix`
- Every other service (Immich, Gitea, Grafana) has an entry

### 2. PhotoMapAI Monitoring

- No Grafana dashboard
- No Prometheus metrics
- Container health not wired to monitoring stack

### 3. PhotoMapAI Backup Strategy

- UMAP index and CLIP embeddings in `/var/lib/photomap/index` are not backed up
- Regenerating embeddings takes hours for large libraries
- Should be included alongside Immich's DB backup timer

### 4. PhotoMapAI Just Commands

- No `just photomap-logs`, `just photomap-status`, `just photomap-restart`
- Existing pattern: Immich has `just immich-*` commands

### 5. Container Image Version Pinning

- `lstein/photomapai:latest` is unpinned — could break on upstream changes
- Should pin to specific digest or version tag

### 6. Container Resource Limits

- No memory/CPU limits for ML workloads
- PhotoMapAI's CLIP embedding generation is CPU/GPU intensive

### 7. Container Log Rotation

- No log rotation configured for `docker-photomap`
- Long-running ML operations could fill disk with logs

### 8. Verify Immich `library/` Directory Exists

- The `library/` directory may not exist if Immich's storage template migration hasn't been run
- If empty, PhotoMapAI will only see `upload/` contents anyway

---

## d) TOTALLY FUCKED UP

### 1. Compiled Binaries in Working Tree

- `pkgs/dnsblockd-processor/dnsblockd-processor` (untracked binary)
- `platforms/nixos/programs/dnsblockd/dnsblockd` (untracked binary)
- These should be in `.gitignore` — they're compiled outputs, not source
- If accidentally committed, they bloat the repo and cause platform-specific issues

### 2. Branch Ahead of Origin by 1 Commit

- The pnpm fix (`3a5547a`) is pushed to origin, but the branch report says ahead by 1
- This could be the SilentSDDM commit or another unpushed commit
- Should verify and push to keep origin in sync

### 3. Dual CLIP Embedding Computation

- Both Immich and PhotoMapAI independently compute CLIP embeddings for the same images
- Double ML compute time, double storage
- Different models may produce incompatible embeddings
- **Architectural improvement needed**: Extract Immich's existing CLIP embeddings from PostgreSQL `smart_search` table and feed them to PhotoMapAI, skipping redundant computation

---

## e) WHAT WE SHOULD IMPROVE

### 1. Refactor `photomap.nix` to Use ContainerService Type System

The type system was built (`d20d18c`) but never applied. `photomap.nix` should be the first consumer:

- Replace raw `virtualisation.oci-containers` with `mkContainerService`
- Automatic tmpfiles generation
- Type-safe health checks and dependency management

### 2. Immich Library Directory Verification

Before deploying, SSH into evo-x2 and verify:

```bash
ls -la /var/lib/immich/
ls -la /var/lib/immich/library/
ls -la /var/lib/immich/upload/
find /var/lib/immich/upload -maxdepth 3 -type d | head -30
find /var/lib/immich/library -maxdepth 3 -type d | head -30
```

If `library/` doesn't exist or is empty, the Immich storage template migration hasn't run yet, and all photos are still in `upload/`.

### 3. Add `.gitignore` Rules for Compiled Binaries

Add patterns to prevent accidental commits:

```
pkgs/dnsblockd-processor/dnsblockd-processor
platforms/nixos/programs/dnsblockd/dnsblockd
```

### 4. PhotoMapAI Image Watching / Auto-Refresh

Currently PhotoMapAI scans images once. When new photos are added to Immich, PhotoMapAI won't know. Options:

- Cron job to trigger re-indexing via PhotoMapAI API
- Immich webhook → PhotoMapAI re-scan
- Periodic systemd timer

### 5. PhotoMapAI + Immich Embedding Sharing

Long-term: Skip PhotoMapAI's CLIP embedding entirely. Extract Immich's existing embeddings from PostgreSQL:

```sql
SELECT a."id", a."originalPath", e."embedding"
FROM assets a
JOIN smart_search e ON a."id" = e."assetId";
```

Feed these directly to a custom UMAP visualizer or PhotoMapAI (if it supports pre-computed embeddings).

### 6. HuggingFace Whitelist Verification

HuggingFace CDN domains were whitelisted in the DNS blocker for CLIP model download:

- `huggingface.co`, `cdn-lfs.huggingface.co`, `cdn-lfs-us-1.huggingface.co`
- Not verified that PhotoMapAI's model download actually works through the DNS blocker
- First container start will reveal if additional domains are needed

---

## f) Top #25 Things to Do Next

### Critical — Deploy What We Have

1. **Commit dnsblockd `.lan` filtering** — Stage and commit the 3 modified files
2. **Clean compiled binaries** — Add to `.gitignore`, delete from working tree
3. **Push to origin** — Get branch in sync with remote
4. **Deploy to evo-x2** — `sudo nixos-rebuild switch --flake .#evo-x2`
5. **Verify PhotoMapAI container** — `docker ps | grep photomap`, check health
6. **Verify Immich photos readable** — `docker exec` into container, `ls /Pictures/upload` and `ls /Pictures/library`
7. **Monitor CLIP embedding generation** — First indexing may take hours
8. **Verify HuggingFace model download** — Check logs for model download success/failure
9. **Test PhotoMapAI web UI** — Open `https://photomap.lan`, verify album appears

### Integration — Make It Actually Useful

10. **Add PhotoMapAI to Homepage dashboard** — Edit `modules/nixos/services/homepage.nix`
11. **Add `just photomap-*` commands** — Logs, status, restart following Immich pattern
12. **Verify DNS resolution** — `nslookup photomap.lan` from LAN
13. **Test image similarity search** — Verify semantic search returns sensible results
14. **Test UMAP scatter plot** — Verify 2D visualization renders correctly
15. **Performance test** — Measure indexing time for full library

### Hardening — Production Readiness

16. **Pin container image version** — Replace `latest` with specific digest
17. **Add resource limits** — Memory/CPU caps for ML workloads
18. **Add container log rotation** — Prevent disk filling
19. **Add PhotoMapAI backup** — Include `/var/lib/photomap/` in backup schedule
20. **Refactor to ContainerService types** — Apply the type system built in `d20d18c`

### Architecture — Long-Term Improvements

21. **Research Immich embedding extraction** — Connect to `smart_search` table
22. **Evaluate custom visualizer** — Use Immich API + UMAP + Plotly instead of PhotoMapAI
23. **Add auto-refresh mechanism** — Cron/timer/webhook for new photo detection
24. **Create ADR** — Document PhotoMapAI vs custom visualizer decision
25. **Monitoring integration** — Grafana dashboard, Prometheus metrics (if available)

---

## g) Top #1 Question I Cannot Answer Myself

**Does `/var/lib/immich/library/` actually exist and contain photos on evo-x2?**

This is critical because:

- If Immich's **storage template migration** hasn't been enabled/run, ALL photos remain in `upload/` and `library/` is empty or nonexistent
- Our fix mounts both `upload/` and `library/` — but `library/` being empty is fine (PhotoMapAI scans both)
- However, if `library/` doesn't exist as a directory, the Docker volume mount will create an empty directory, which is harmless but indicates the mount is unnecessary until migration runs
- Conversely, if ALL photos have been migrated to `library/` and `upload/` is empty, then our original config was missing the actual photo location entirely

**Recommendation:** Before deploying, SSH into evo-x2 and run:

```bash
ls -la /var/lib/immich/
du -sh /var/lib/immich/upload/ /var/lib/immich/library/ 2>/dev/null
find /var/lib/immich/upload -type f | wc -l
find /var/lib/immich/library -type f 2>/dev/null | wc -l
```

This reveals the actual distribution of photos between the two directories.

---

## Recent Commit History (Last 10)

```
3a5547a fix(packages): replace nodePackages.pnpm with top-level pnpm
d20d18c feat(types): add ContainerService type system for OCI containers
287825f docs(status): add comprehensive post-SilentSDDM integration status report
6cd668e fix(services): resolve photomap container startup and caddy port conflicts
0fd3d6b docs(status): add comprehensive full project status report and statix linting tool
e022038 chore(deps): update flake.lock with latest revisions for all inputs
39fae5b style(niri): add 95% opacity to non-floating windows
ad268ce style(display-manager): fix alejandra formatting for SilentSDDM config
1437c98 feat(sddm): integrate SilentSDDM theme with catppuccin-mocha
76de011 feat(photomap): refactor container configuration with read-only volumes and declarative config
```

## Working Tree Status

- **Modified (unstaged):** `pkgs/dns-blocklist.nix`, `pkgs/dnsblockd-processor/main.go`, `platforms/nixos/programs/dnsblockd/main.go`
- **Untracked:** `pkgs/dnsblockd-processor/dnsblockd-processor` (binary), `platforms/nixos/programs/dnsblockd/dnsblockd` (binary)
- **Ahead of origin:** 1 commit
