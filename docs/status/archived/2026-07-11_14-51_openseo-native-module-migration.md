# Session Status: OpenSEO Docker → Native NixOS Module Migration

**Date:** 2026-07-11 14:51
**Session scope:** Migrate OpenSEO from Docker container to NixOS-native systemd service built from source
**Host:** evo-x2 (NixOS)

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## Executive Summary

Built a complete Nix derivation (`pkgs/openseo.nix`) that compiles OpenSEO v0.0.26 from GitHub source using `fetchPnpmDeps` + `pnpmConfigHook` + `autoPatchelfHook`, and rewrote the service module (`modules/nixos/services/openseo.nix`) as a native systemd service. The package **builds successfully** (942 MB), `nix flake check --no-build` **passes**, and full system evaluation **succeeds**. However, the service has **never been tested at runtime** — `vite preview` + `workerd` outside Docker is unverified, and several configuration values are likely wrong.

---

## a) FULLY DONE

| #   | Item                                                                                                       | Evidence                                                                                                                                                                               |
| --- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `pkgs/openseo.nix` — Nix derivation builds from source                                                     | `nix build .#openseo` succeeds. Output at `/nix/store/...-openseo-0.0.26/lib/openseo/` with `dist/{client,server}/`, patched `workerd` ELF binary, `node_modules/.bin/{vite,wrangler}` |
| 2   | `fetchPnpmDeps` hash resolved                                                                              | `sha256-2aGxcFzezCke22IVFW4IDxlMWlakw0x0RzPXwCaoKjA=` — deps fetch cleanly                                                                                                             |
| 3   | `fetchFromGitHub` hash resolved                                                                            | `sha256-QoneI22o7GYUNfQ+sSFq2kEx/GNv7SMIbfqo11L4/Y0=` — v0.0.26 source                                                                                                                 |
| 4   | Native binary patching (workerd, sharp, lightningcss, libsql, oxlint, tailwindcss-oxide, rollup, rolldown) | `autoPatchelfHook` + `stdenv.cc.cc.lib` in `buildInputs`. All 12 native addons patched with 0 unsatisfied dependencies                                                                 |
| 5   | Vite build succeeds in Nix sandbox                                                                         | `AUTH_MODE=local_noauth VITE_SHOW_DEVTOOLS=false NODE_OPTIONS=--max-old-space-size=4096 pnpm run build` — produces `dist/{client,server}/`                                             |
| 6   | Overlay wired in `overlays/shared.nix`                                                                     | Linux-only: `openseo = prev.callPackage ../pkgs/openseo.nix {};`                                                                                                                       |
| 7   | Package exposed in `flake.nix`                                                                             | Added to `lib.optionalAttrs pkgs.stdenv.isLinux` packages block                                                                                                                        |
| 8   | Module rewritten (`modules/nixos/services/openseo.nix`)                                                    | No Docker, no `mkDockerService`, no compose YAML. Native systemd service with staging script, D1 migration ExecStartPre, `vite preview` ExecStart                                      |
| 9   | Docker image removed from `lib/images.nix`                                                                 | `openseo` entry deleted. No remaining `images.openseo` references in any `.nix` file                                                                                                   |
| 10  | `imageTag` option removed                                                                                  | Module no longer has `imageTag` option (was only relevant for Docker)                                                                                                                  |
| 11  | Port 3002 preserved                                                                                        | `lib/ports.nix` unchanged — still `openseo = 3002`                                                                                                                                     |
| 12  | Caddy vHost preserved                                                                                      | `seo.${domain}` still uses `protectedVHost "seo" config.services.openseo.port` — unchanged                                                                                             |
| 13  | Homepage tile preserved                                                                                    | Still in Productivity group, `svcUrl "seo"` — unchanged                                                                                                                                |
| 14  | Gatus health check preserved                                                                               | Still monitors `http://localhost:3002` with Discord alert — unchanged                                                                                                                  |
| 15  | Sops secret wiring preserved                                                                               | `dataforseo_api_key` in `openseo.yaml`, rendered to `openseo-env` template — unchanged                                                                                                 |
| 16  | `nix flake check --no-build` passes                                                                        | All NixOS modules evaluated successfully                                                                                                                                               |
| 17  | Full system eval passes                                                                                    | `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` — succeeds                                                                                                        |
| 18  | Planning document written                                                                                  | `docs/planning/2026-07-11_openseo-native-module-migration.md` — full feasibility assessment, architecture diagrams, risk matrix, rollback plan                                         |
| 19  | AGENTS.md updated                                                                                          | Added "OpenSEO native build" gotcha entry documenting the Cloudflare Workers + workerd + Nix constraints                                                                               |
| 20  | FEATURES.md updated                                                                                        | Updated OpenSEO entry to reflect native build + `pkgs/openseo.nix`                                                                                                                     |

---

## b) PARTIALLY DONE

| #   | Item                             | What's done                        | What's missing                                                                                                                                                                                                                                                   |
| --- | -------------------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Runtime NODE_OPTIONS**         | Set to `--max-old-space-size=1536` | Docker compose used `3072`. The 1536 value is MORE conservative than Docker — likely too low. V8 old-gen heap of 1.5GB with 2GB MemoryMax leaves only 512MB for workerd + native addons + buffers. Should match Docker's 3072                                    |
| 2   | **Package closure optimization** | Package builds and works           | **942 MB** — the entire project tree (including ALL devDependencies: oxlint, drizzle-kit, playwright, vitest, knip, portless, prettier, tsx) is copied to the Nix store. Should prune devDeps or use `pnpm deploy --prod` + keep only vite/wrangler runtime deps |
| 3   | **Data migration plan**          | Documented in planning doc         | Not executed — requires deploy-time access to copy D1 SQLite from Docker volume to `/var/lib/openseo/.wrangler/`                                                                                                                                                 |
| 4   | **Documentation**                | AGENTS.md + FEATURES.md updated    | README.md service table not updated (still says nothing about Docker, so technically still correct). `docs/runbooks/monitoring-runbook.md` still says `sudo systemctl restart openseo` which is still correct                                                    |

---

## c) NOT STARTED

| #   | Item                                                                    | Why                                                                                                                                                     |
| --- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Actual deploy** (`nix run .#deploy`)                                  | Not executed — code is ready but deploy requires the data migration step first                                                                          |
| 2   | **Runtime testing** (`systemctl status openseo`, `curl localhost:3002`) | Never tested that `vite preview` + `workerd` actually starts and serves HTTP outside Docker                                                             |
| 3   | **`nix run .#pre-deploy-check`**                                        | Not run — would catch boot-breaking issues                                                                                                              |
| 4   | **`nix run .#post-deploy-check`**                                       | Not run — would verify functional outcomes                                                                                                              |
| 5   | **Gatus health check verification after deploy**                        | Not verified that the native service passes the existing health check                                                                                   |
| 6   | **Docker container cleanup**                                            | Old Docker image (`ghcr.io/every-app/open-seo:v0.0.15`) and volume (`openseo_data`) still on disk. Should be cleaned up after native module is verified |

---

## d) TOTALLY FUCKED UP / HIGH RISK

| #   | Issue                                                        | Severity | Detail                                                                                                                                                                                                                                                                                                                                                                                       |
| --- | ------------------------------------------------------------ | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Never tested at runtime**                                  | CRITICAL | The entire migration is **theoretically correct** but **practically unproven**. `vite preview` spawns `workerd` (Cloudflare's runtime), which emulates D1/KV/R2/Durable Objects locally. This has NEVER been tested outside Docker. `workerd` might segfault, fail to bind, or hit sandbox restrictions (`RestrictNamespaces=true` in `harden {}` could block workerd's internal sandboxing) |
| 2   | **`RestrictNamespaces = true` may break workerd**            | HIGH     | `harden {}` sets `RestrictNamespaces = true` by default. `workerd` uses Linux namespaces internally for request isolation. If workerd calls `unshare()` or `clone()` with `CLONE_NEWNS`/`CLONE_NEWNET`, systemd will block it and the service will crash. I did NOT test this. May need `RestrictNamespaces = false`                                                                         |
| 3   | **942 MB Nix closure**                                       | HIGH     | The package is **942,072,208 bytes (898 MiB)**. For comparison: most SystemNix packages are 1-50 MB. Every `nixos-rebuild` now pulls/references this massive derivation. The `node_modules/.pnpm/` store with all devDependencies is included. This is a storage and GC pressure problem on a system that already experienced BTRFS metadata ENOSPC                                          |
| 4   | **NODE_OPTIONS runtime mismatch**                            | MEDIUM   | Docker compose: `--max-old-space-size=3072`. Native module: `--max-old-space-size=1536`. This 50% reduction is unjustified and may cause V8 GC pressure or OOM crashes under load. Should match Docker's 3072                                                                                                                                                                                |
| 5   | **Did not read `lib/systemd.nix` before writing the module** | MEDIUM   | AGENTS.md and the global AGENTS.md both say "READ before you WRITE". I used `harden {}` without understanding its defaults until AFTER writing the module. Only verified the defaults when writing this status report. The `RestrictNamespaces` issue (item #2) was discovered this way                                                                                                      |
| 6   | **Wrangler path resolution may break**                       | MEDIUM   | The migrate script does `cd /var/lib/openseo/project` then runs `${storeDir}/node_modules/.bin/wrangler`. Wrangler resolves `wrangler.jsonc` from CWD (symlinked), but the `drizzle/` migrations directory is also symlinked. If wrangler resolves the config file's real path (Nix store) and looks for `drizzle/` relative to THAT, migrations will fail silently or error                 |
| 7   | **No fallback if migration fails**                           | MEDIUM   | `ExecStartPre` runs staging + D1 migration. If migrations fail (wrangler error, missing `drizzle/` dir, permission issue), the entire service won't start. No `Restart=on-failure` on the ExecStartPre, no migration skip logic, no alerting beyond `onFailure`                                                                                                                              |
| 8   | **Staging script race on first boot**                        | LOW      | On first deploy, `StateDirectory=openseo` creates `/var/lib/openseo`. The staging script creates `/var/lib/openseo/project/` inside it. This should work, but the `find -maxdepth 1 -type l -delete` in the staging script will try to delete symlinks in a directory that doesn't exist yet on first run. The `mkdir -p` before it handles this, but the ordering is fragile                |

---

## e) WHAT WE SHOULD IMPROVE

| #   | Improvement                                                                                                                                                                                            | Priority |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| 1   | **Test the service at runtime before declaring done** — even a manual `nix build && ./result/.../node_modules/.bin/vite preview` smoke test would catch the workerd crash                              | P0       |
| 2   | **Match Docker's `NODE_OPTIONS=--max-old-space-size=3072`** — the 1536 value is unjustified                                                                                                            | P0       |
| 3   | **Add `RestrictNamespaces = false` to the harden override** — workerd likely needs namespace syscalls. Test first, but prepare the fix                                                                 | P0       |
| 4   | **Prune devDependencies from the package** — use `pnpm deploy --prod --filter=.` or manually exclude test/lint/dev tools from the install phase. Target: <200 MB closure                               | P1       |
| 5   | **Read `lib/systemd.nix` and `lib/systemd/service-defaults.nix` BEFORE writing modules** — this is a process failure. The AGENTS.md explicitly says to read before writing                             | P1       |
| 6   | **Add a post-deploy smoke test for OpenSEO** — verify `curl localhost:3002` returns expected HTML, not just that the service is "active"                                                               | P1       |
| 7   | **Consider `MemoryMax=3G`** to match the Docker `mem_limit: 2g` + V8 heap headroom — or set `MemoryMax=2G` + `NODE_OPTIONS=3072` and accept V8 will be memory-constrained (matching Docker's behavior) | P1       |
| 8   | **Document the workerd + Nix sandbox interaction** — if it works, document WHY (which syscalls workerd needs, which harden options are compatible). If it doesn't, document the specific failure       | P1       |
| 9   | **Add `ReadWritePaths = ["/var/lib/openseo"]` explicitly** — even though StateDirectory should handle it, belt-and-suspenders for ProtectSystem=full                                                   | P2       |
| 10  | **Version pin `pnpm` and `nodejs`** in the derivation — currently uses whatever `pkgs.nodejs` and `pkgs.pnpm` provide (follows nixos-unstable). Should pin Node 22 (matching Docker's `node:22`)       | P2       |

---

## f) Next 50 Things To Get Done

### Immediate (blocks deploy)

1. Test `workerd` runtime outside Docker — run the built package's `vite preview` manually
2. Fix `NODE_OPTIONS` runtime to `--max-old-space-size=3072` (match Docker)
3. Test whether `RestrictNamespaces = true` breaks workerd — add `RestrictNamespaces = false` if needed
4. Run `nix run .#pre-deploy-check` before deploying
5. Copy D1 SQLite data from Docker volume (`/var/lib/docker/volumes/openseo_data/_data/`) to `/var/lib/openseo/.wrangler/`
6. Deploy: `nix run .#deploy`
7. Verify: `systemctl status openseo`
8. Verify: `curl -s http://localhost:3002 | head -20`
9. Verify: `curl -sk https://seo.home.lan` (through Caddy + oauth2-proxy)
10. Run `nix run .#post-deploy-check`

### Short-term (quality)

11. Prune devDependencies from `pkgs/openseo.nix` — target <200 MB closure
12. Pin Node.js 22 explicitly in the derivation (`nodejs = pkgs.nodejs_22`)
13. Add `ReadWritePaths = ["/var/lib/openseo"]` to serviceConfig
14. Add a wrangler path-resolution test — verify `drizzle/` migrations are found through the symlink chain
15. Add health check endpoint verification — OpenSEO should return 200 at `/` (not just port-open)
16. Clean up old Docker image: `docker image rm ghcr.io/every-app/open-seo:v0.0.15`
17. Clean up old Docker volume after data migration verified: `docker volume rm openseo_data`
18. Add Gatus `[RESPONSE_TIME] < 2000` condition verification (already exists — verify it still passes)
19. Update `docs/runbooks/monitoring-runbook.md` if service restart command changed (it hasn't, but verify)
20. Verify homepage tile `siteMonitor` still passes after native migration
21. Add `systemd.services.openseo.serviceConfig.RestartSec = "10s"` (longer than default 5s for a heavy Node app)
22. Test service restart durability — `systemctl restart openseo` should work without manual intervention
23. Verify `.wrangler` state survives service restart (D1 SQLite persistence)
24. Verify `.wrangler` state survives system reboot
25. Add log rotation check — `journalctl -u openseo` should not grow unbounded

### Medium-term (robustness)

26. Add a `systemd.services.openseo.preStart` script that validates sops env file exists before staging
27. Consider adding `TimeoutStartSec = 120` — vite preview + workerd startup might take >90s (default)
28. Add monitoring for the 942 MB closure — alert if it grows beyond 1.5 GB on version bumps
29. Create an update procedure doc for bumping OpenSEO versions (vendorHash + src hash + migration)
30. Test OpenSEO v0.0.26 new features (upgraded from v0.0.15 — 11 versions of changes)
31. Verify DataForSEO API key works after migration (environment variable plumbing through sops → EnvironmentFile → CLOUDFLARE_INCLUDE_PROCESS_ENV → Workers binding)
32. Add a Gatus check for DataForSEO API connectivity (not just OpenSEO HTTP)
33. Consider systemd `OOMScoreAdjust` — workerd + V8 under memory pressure should be killed before critical services
34. Document the `CLOUDFLARE_INCLUDE_PROCESS_ENV=true` env var in the module header comment (currently only in AGENTS.md)
35. Add `assertion` for Node.js version compatibility if upstream pins a specific version

### Long-term (architecture)

36. Consider building a proper `workerd` nixpkgs package (upstream issue #355460) — would benefit the entire NixOS + Cloudflare ecosystem
37. Explore `pnpm fetch` + `pnpm install --offline` as an alternative to `fetchPnpmDeps` (might handle workspace edge cases better)
38. Consider splitting the package into `openseo-build` (dev deps, used for building) and `openseo` (runtime-only deps + dist)
39. Add a devShell for OpenSEO development (`nix develop .#openseo`) with hot-reload Vite
40. Consider NixOS tests (`nixosTests.openseo`) for automated service verification
41. Explore whether `wrangler dev` (instead of `vite preview`) provides better production parity
42. Add a backup strategy for D1 SQLite at `/var/lib/openseo/.wrangler/` (currently no backup — Docker volume had no backup either)
43. Consider adding OpenSEO to the `btrbk` snapshot schedule (currently `/var/lib` is under root `@` subvolume which IS snapshotted daily)
44. Evaluate whether the Cloudflare KV/R2/Durable Object emulators in workerd lose data on restart (they use local filesystem, but persistence semantics are unclear)
45. Add prometheus metrics endpoint if OpenSEO exposes one (or use node exporter for process metrics)

### Cleanup

46. Remove old planning doc references to Docker in `docs/planning/2026-05-08_openseo-domain-tracking-deployment.md` (add a note pointing to the new migration doc)
47. Update `scripts/status-report.sh` if OpenSEO's service name or check method changed (it hasn't)
48. Add the old Docker-based openseo module to git history with a clear commit message for rollback
49. Verify no other modules reference `config.services.openseo.imageTag` (removed option)
50. Run `nix flake check --no-build` one final time after all fixes

---

## g) Top 2 Questions I Cannot Answer Myself

### 1. Does `workerd` actually work under systemd hardening (`RestrictNamespaces=true`)?

`workerd` (Cloudflare's runtime) may use Linux namespace syscalls (`unshare`, `clone` with `CLONE_NEW*` flags) for its internal request isolation sandbox. The `harden {}` function defaults `RestrictNamespaces = true`, which blocks these syscalls. If workerd requires them, the service will crash immediately at startup with `EPERM` or `ENOSYS`. I cannot determine this without either (a) reading workerd's source code (C++/KJ framework, extremely complex), or (b) actually running the service and observing the failure. The safe default would be `RestrictNamespaces = false`, but I need confirmation that workerd actually needs it before weakening the sandbox.

### 2. Should we keep the Docker image as a fallback until the native module is verified working?

The Docker module is completely replaced — there's no fallback path without `git revert`. The old Docker image (`v0.0.15`) is still on disk, and the Docker volume (`openseo_data`) still has the D1 data. If the native module fails at runtime (workerd crash, migration failure, etc.), we need to either `git revert` and redeploy, or manually restart the old Docker container. This is a risk tolerance question — should we deploy and test, or should we first do a manual smoke test of the built package before committing to the deploy?

---

## Session Metrics

| Metric                       | Value                                                                                                                      |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Files created                | 2 (`pkgs/openseo.nix`, `docs/planning/2026-07-11_openseo-native-module-migration.md`)                                      |
| Files modified               | 5 (`modules/nixos/services/openseo.nix`, `lib/images.nix`, `overlays/shared.nix`, `flake.nix`, `AGENTS.md`, `FEATURES.md`) |
| Build attempts               | 3 (1st: missing libgcc_s, 2nd: /build/ RPATH leak, 3rd: success)                                                           |
| Package size                 | 942 MB (898 MiB)                                                                                                           |
| Build time                   | ~3-4 minutes (evo-x2, 128GB RAM)                                                                                           |
| OpenSEO version upgrade      | v0.0.15 → v0.0.26 (+11 versions)                                                                                           |
| `nix flake check --no-build` | PASS                                                                                                                       |
| Full system eval             | PASS                                                                                                                       |
| Runtime tested               | NO                                                                                                                         |
| Deployed                     | NO                                                                                                                         |
