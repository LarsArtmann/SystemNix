# PhotoMapAI + Gitea-Repos + DNS Blocker — Comprehensive Status Report

**Date:** 2026-03-31 14:39
**Session Span:** 2026-03-30 — 2026-03-31
**Git Branch:** master (1 commit ahead of origin/master)
**Author:** Crush (assisted by multiple models)

---

## Executive Summary

Three major features were worked on across this session:

1. **PhotoMapAI** — CLIP embedding 2D/3D vector-space visualization tool, NixOS module created and committed
2. **Gitea-Repo Mirroring** — Declarative GitHub-to-Gitea mirroring with sops-nix, committed and partially debugged
3. **DNS Blocker Refactoring** — Temp allowlist removed, then reverted, then refactored to use unbound-control

**The critical blocker:** Neither PhotoMapAI nor Gitea-Repos have been deployed to evo-x2 yet. Everything is config-only (in git, not on the machine). SSH is blocked from the macOS dev terminal.

---

## a) FULLY DONE

### PhotoMapAI NixOS Module (Code Complete, Not Deployed)

All NixOS configuration files have been written, wired into the flake, verified via `nix flake check --no-build` (passed), and committed to git.

| Component             | File                                                            | Status                   |
| --------------------- | --------------------------------------------------------------- | ------------------------ |
| Service module        | `modules/nixos/services/photomap.nix`                           | Committed, eval verified |
| Caddy reverse proxy   | `modules/nixos/services/caddy.nix` (lines 51-57)                | Committed, eval verified |
| DNS A record          | `platforms/nixos/system/dns-blocker-config.nix` (line 171)      | Committed, eval verified |
| HuggingFace whitelist | `platforms/nixos/system/dns-blocker-config.nix` (lines 126-128) | Committed, eval verified |
| Homepage dashboard    | `modules/nixos/services/homepage.nix` (lines 83-87)             | Committed, eval verified |
| Flake wiring          | `flake.nix` (lines 145, 332)                                    | Committed, eval verified |

**Key design decisions:**

- Docker container (`lstein/photomapai:latest`) on port 8050, bound to localhost only
- Immich's `/var/lib/immich/upload` mounted read-only at `/Pictures/upload`
- PhotoMapAI's `photomap_index/` directory separated into its own writable volume (`/var/lib/photomap/photomap-index` → `/Pictures/upload/photomap_index`) to avoid writing into Immich's read-only media
- Health check uses `python3` (available in `python:3.11-slim` base image) instead of `curl`
- Systemd service ordering: `docker-photomap` starts after `immich-server.service`
- HuggingFace CDN domains whitelisted in DNS blocker for CLIP model downloads

**Research completed:**

- Immich NixOS module analyzed: `mediaLocation = "/var/lib/immich"`, only top-level dir created by module, subdirs (`upload/`, `thumbs/`, etc.) created by Immich at runtime
- PhotoMapAI analyzed: uses `os.walk()` for recursive scan, 100KB minimum file size filter (skips thumbnails), CLIP ViT-B/32, creates `photomap_index/` in first image folder, Docker image is CPU-only PyTorch
- Immich v1.141.1+ "Find similar" feature: flat list only, no spatial visualization — PhotoMapAI justified

### DNS Blocker Refactoring

- Temp allowlist feature removed, then reverted (commit `9146312`), then properly refactored to use `unbound-control` directly (commit `e365f93`)
- DNS cache flush added (commit `5d13c12`)

### SSH Reliability

- ServerAliveInterval 60s, TCPKeepAlive enabled (commit `ce06182`)
- Hypridle suspend prevention when active SSH sessions detected (commit `ae514f8`)

### Flake Verification

- `nix flake check --no-build` passes cleanly — all 12 NixOS modules evaluated successfully
- No eval errors in `photomap`, `gitea-repos`, or any other module

---

## b) PARTIALLY DONE

### Gitea-Repo Mirroring

**Module created and committed** but has an unresolved issue with sops age key conversion.

| Component                                | Status      | Notes                                                                                                |
| ---------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------- |
| `modules/nixos/services/gitea-repos.nix` | Committed   | Script logic complete                                                                                |
| `scripts/fix-gitea-token.sh`             | Committed   | Workaround for sops SSH→age key                                                                      |
| `justfile` commands                      | Committed   | `gitea-update-token`, `gitea-sync-repos`, `gitea-setup`                                              |
| `configuration.nix` enablement           | Committed   | `services.gitea-repos.enable = true`                                                                 |
| Sops secret template                     | Committed   | `gitea-sync.env` template in `sops.nix`                                                              |
| Token actually working                   | **Unknown** | `SOPS_AGE_SSH_PRIVATE_KEY_FILE` doesn't work with modern age/sops — requires `ssh-to-age` conversion |
| Deployed to evo-x2                       | **No**      | Not deployed yet                                                                                     |
| Tested                                   | **No**      | Cannot test without deployment                                                                       |

**Blocking issue:** `sops-nix` with SSH host keys requires `ssh-to-age` key conversion. The `scripts/fix-gitea-token.sh` is a workaround. This needs testing on evo-x2.

### PhotoMapAI — Deployment

Config is 100% complete but **zero deployment steps** have been executed:

- Not deployed to evo-x2
- Container not started
- DNS/proxy not verified
- First-launch album setup not done
- Unknown whether Immich stores photos in `upload/` only or also `library/`

---

## c) NOT STARTED

1. **PhotoMapAI deployment to evo-x2** — `sudo nixos-rebuild switch --flake .#evo-x2`
2. **PhotoMapAI first-launch album setup** — Create album pointing to `/Pictures/upload`
3. **PhotoMapAI GPU acceleration** — Docker image is CPU-only; custom CUDA image not built
4. **PhotoMapAI container image pinning** — Using `:latest`, should pin to specific digest
5. **PhotoMapAI backup** — UMAP index (`/var/lib/photomap/photomap-index`) not in any backup schedule
6. **PhotoMapAI library directory** — If Immich uses `library/` for external imports, it's not mounted
7. **Custom CLIP embedding visualizer** — Long-term improvement to reuse Immich's existing embeddings from `smart_search` PostgreSQL table instead of PhotoMapAI's duplicate CLIP computation
8. **Gitea-repos actual deployment and testing** on evo-x2
9. **Gitea-repos sops age key issue** — Proper fix for `ssh-to-age` conversion
10. **Push unpushed commit** — `b3b2651` is 1 commit ahead of origin/master

---

## d) TOTALLY FUCKED UP

### Nothing is truly broken, but these are concerning:

1. **Disk space on dev machine** — Was at 99% (229G disk, 3.8G free). Cleaned 1.5G temporarily during session but this will recur. The `/tmp/tmp.*` files and `.crush/crush-fetch-*` cache files fill up fast.

2. **Cross-compilation timeout** — `nix flake check` (full build, not `--no-build`) times out on aarch64-darwin when evaluating x86_64-linux targets. This means we can only do `--no-build` verification locally, not full build testing. Full build must happen on evo-x2.

3. **SOPS age key SSH incompatibility** — Modern `sops` with `age` backend doesn't natively support SSH keys anymore. Requires `ssh-to-age` conversion tool. The `fix-gitea-token.sh` script is a band-aid. This affects ALL sops secret management, not just gitea-repos.

4. **PhotoMapAI Docker image is CPU-only** — For a machine with AMD Ryzen AI Max+ 395 (powerful NPU/GPU), running CLIP inference on CPU is ~10x slower. Indexing a large photo library could take hours instead of minutes. No CUDA/ROCm support out of the box.

5. **`configuration.nix` has `services.gitea-repos` enabled** — If the sops secrets aren't properly set up on evo-x2, the next rebuild will fail when systemd tries to start `gitea-ensure-repos` service. This could block deployment of PhotoMapAI.

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Stop duplicating CLIP embeddings** — Immich already computes 512D CLIP embeddings stored in PostgreSQL `smart_search` table via VectorChord. PhotoMapAI re-computes them independently. Long-term: build a custom visualizer that queries Immich's existing embeddings, runs UMAP locally, and renders the scatter plot. This eliminates ~50% of the compute and storage overhead.

2. **GPU acceleration** — The evo-x2 has an AMD Ryzen AI Max+ 395 with ROCm support. Build a custom PhotoMapAI Docker image with ROCm-enabled PyTorch instead of CPU-only.

3. **Disk space management** — Dev machine is chronically at 99%. Need automated cleanup: old crush caches, `/tmp` files, nix store GC. Add to justfile or cron.

4. **Deployment pipeline** — Currently SSH is blocked from dev terminal, requiring manual deployment on evo-x2. Consider adding a `just deploy-remote` command that SSHes from evo-x2 itself or uses Nix's built-in remote build.

### Code Quality

5. **Pin Docker image versions** — `lstein/photomapai:latest` is a floating tag. Should pin to a specific digest for reproducibility.

6. **Validate Immich directory structure** — Before mounting, verify what Immich actually creates under `/var/lib/immich/` on evo-x2. May need both `upload/` and `library/` mounts.

7. **Test the sops age key flow end-to-end** — The `ssh-to-age` conversion issue could block all secret management. Needs a proper fix, not a workaround script.

### Documentation

8. **Status reports have drifted** — 10 status reports in `docs/status/` over 2 days. Should consolidate into a single living document or remove stale ones.

9. **AGENTS.md memory update** — PhotoMapAI and gitea-repos patterns should be documented in the project AGENTS.md for future sessions.

---

## f) Top 25 Things to Get Done Next

### Priority 1 — Get PhotoMapAI Running (Deploy)

1. **Push unpushed commit** to origin/master (`git push`)
2. **SSH to evo-x2** and pull latest config
3. **Check Immich directory structure**: `ls -la /var/lib/immich/` and `find /var/lib/immich/upload -maxdepth 3 -type d | head -20`
4. **Check if `library/` exists**: `find /var/lib/immich/library -maxdepth 3 -type d 2>/dev/null | head -10`
5. **If library/ exists, update photomap.nix** to mount both `upload/` and `library/`
6. **Deploy**: `sudo nixos-rebuild switch --flake .#evo-x2`
7. **Verify container**: `docker ps | grep photomap` and `docker logs photomap`
8. **Verify DNS**: `nslookup photomap.lan` from LAN machine
9. **Verify proxy**: `curl -k https://photomap.lan`
10. **First-launch setup**: Open `https://photomap.lan`, create album with `/Pictures/upload`

### Priority 2 — Stabilize Gitea-Repos

11. **Fix sops age key issue** properly (not workaround script)
12. **Deploy gitea-repos** to evo-x2
13. **Test mirror sync** with `gitea-ensure-repos` on evo-x2
14. **Verify GitHub token refresh** via `just gitea-update-token`

### Priority 3 — Harden PhotoMapAI

15. **Pin container image** to specific version/digest
16. **Add backup** for `/var/lib/photomap/` (UMAP index)
17. **Monitor first indexing** — watch `docker logs -f photomap` for errors
18. **Check CLIP model download** — HuggingFace whitelist should work, verify
19. **Assess performance** — How long does indexing take? Is CPU acceptable?

### Priority 4 — Infrastructure Improvements

20. **Build ROCm-enabled PhotoMapAI image** for GPU acceleration
21. **Disk space cleanup automation** on dev machine
22. **Consolidate status reports** — Remove stale ones, keep latest
23. **Update AGENTS.md** with PhotoMapAI and gitea-repos patterns
24. **Evaluate custom CLIP visualizer** that reuses Immich's embeddings
25. **Set up monitoring/alerting** for PhotoMapAI container health

---

## g) Top #1 Question I Cannot Figure Out Myself

**What is the actual directory structure under `/var/lib/immich/` on evo-x2?**

This is THE blocking question. Everything else is configurable, but the mount paths in `photomap.nix` are hardcoded based on the assumption that Immich stores photos in `upload/`. If the user has configured Immich with external libraries (mounted from NAS, etc.), photos may be in `library/` or custom paths. The current config only mounts `upload/`.

To answer, someone needs to run on evo-x2:

```bash
ls -la /var/lib/immich/
find /var/lib/immich/upload -maxdepth 3 -type d | head -30
find /var/lib/immich/library -maxdepth 3 -type d 2>/dev/null | head -30
du -sh /var/lib/immich/upload /var/lib/immich/library 2>/dev/null
```

---

## Files Changed This Session (All Committed)

| Commit    | Description                                                                      | Files                                                                                           |
| --------- | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `14d02a4` | feat(gitea): add declarative GitHub-to-Gitea repo mirroring + PhotoMapAI updates | `flake.nix`, `justfile`, `gitea-repos.nix`, `homepage.nix`, `photomap.nix`, `configuration.nix` |
| `ce06182` | feat(ssh): add evo-x2 workstation host and enable global keepalive               | SSH config                                                                                      |
| `ae514f8` | fix(nixos): prevent hypridle suspend when active SSH sessions exist              | Hypridle config                                                                                 |
| `39b3ea4` | fix(nixos): add linkedin.com to DNS blocker whitelist                            | DNS blocker config                                                                              |
| `0ca8f4d` | chore(flake.lock): update flake inputs to latest versions                        | `flake.lock`                                                                                    |
| `9146312` | Revert "refactor(dnsblockd): remove temporary allowlist feature"                 | DNS blocker                                                                                     |
| `0cec348` | refactor(dnsblockd): remove temporary allowlist feature                          | DNS blocker                                                                                     |
| `5d13c12` | fix(dns-blocker): fix temp-allowlist tmpfiles and add DNS cache flush            | DNS blocker                                                                                     |
| `ee1f4d1` | feat(gitea-repos): add auto-detection of SystemNix repo location                 | `gitea-repos.nix`                                                                               |
| `e365f93` | refactor(dnsblockd): use unbound-control directly                                | DNS blocker Go code                                                                             |
| `fb68584` | fix(gitea-repos): use absolute sops path                                         | `gitea-repos.nix`                                                                               |
| `b3b2651` | feat(gitea-repos): add declarative GitHub repo mirroring with sops-nix           | `gitea-repos.nix`, status report, fix script                                                    |

**Unpushed:** `b3b2651` (1 commit ahead of origin/master)

---

## System State

| Item                    | Status                                    |
| ----------------------- | ----------------------------------------- |
| Git working tree        | Clean                                     |
| Flake check --no-build  | Passes                                    |
| PhotoMapAI config       | Committed, eval verified                  |
| PhotoMapAI deployed     | **NO**                                    |
| Gitea-repos config      | Committed, eval verified                  |
| Gitea-repos deployed    | **NO**                                    |
| DNS blocker             | Committed, deployed (last known state)    |
| Dev machine disk        | 99% full (3.8G free of 229G)              |
| Target machine (evo-x2) | Unknown — no SSH access from dev terminal |
