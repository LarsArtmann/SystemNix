# OpenSEO — Docker to NixOS Native Module Migration Plan

**Date:** 2026-07-11
**Scope:** Migrate OpenSEO from Docker container (`ghcr.io/every-app/open-seo`) to a NixOS-native systemd service built from source
**Current State:** Docker compose module at `modules/nixos/services/openseo.nix` (port 3002, Layer 2 SSO via oauth2-proxy)

---

## 1. Feasibility Assessment

### Honest Verdict: HIGH RISK, HIGH EFFORT, CONDITIONALLY FEASIBLE

OpenSEO is **not a typical web app**. It is a **Cloudflare Workers** application built on TanStack Start + Vite 7 + React 19. Its entire runtime — D1 (SQLite), KV namespaces, R2 object storage, Durable Objects, and Cloudflare Workflows — is designed for the Cloudflare edge platform. The Docker self-host image works by running `vite preview`, which proxies through `workerd` (Cloudflare's local runtime emulator) bundled inside the `wrangler` pnpm package.

### Key Blockers & Mitigations

| #   | Blocker                                                                                      | Impact                                                              | Mitigation                                                                                                                                                                                                            |
| --- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **`workerd` not in nixpkgs** (issue #355460, closed "not planned" — bazel build too complex) | Critical: the runtime depends on `workerd`                          | The `wrangler` pnpm package bundles a pre-compiled `workerd` binary for linux-x64. We use that binary directly. It should work in Nix if it can find its shared libraries (typically just glibc, which NixOS provides) |
| 2   | **No `buildPnpmPackage`** in nixpkgs                                                         | High: manual pnpm packaging required                                | Use `fetchPnpmDeps` + `pnpmConfigHook` pattern (project precedent: `pkgs/jscpd.nix`). Requires checked-in `pnpm-lock.yaml`                                                                                            |
| 3   | **Build-time env var inlining** (`AUTH_MODE` baked into client bundle by `vite build`)       | Medium: Docker rebuilds at container start to handle this           | SystemNix always uses `AUTH_MODE=local_noauth` — hardcode at Nix build time                                                                                                                                           |
| 4   | **4GB heap build** (~7400 Vite modules)                                                      | Low: evo-x2 has 128GB RAM                                           | Set `NODE_OPTIONS=--max-old-space-size=4096` in `buildPhase`                                                                                                                                                          |
| 5   | **Runtime needs full project tree** (node_modules + dist + wrangler config + workerd binary) | Medium: large closure, can't just serve static files                | Copy entire build output to `$out/lib/openseo/`, create wrapper script                                                                                                                                                |
| 6   | **D1 SQLite persistence** (`.wrangler/state/`)                                               | Medium: needs writable persistent state                             | Mount from `/var/lib/openseo/.wrangler` via systemd `StateDirectory`                                                                                                                                                  |
| 7   | **`vite preview` is dev-grade**                                                              | Low: upstream-sanctioned for self-host (Docker image uses the same) | Accept this limitation — it's the only option without Cloudflare deployment                                                                                                                                           |
| 8   | **pnpm workspace** (`pnpm-workspace.yaml`)                                                   | Medium: `fetchPnpmDeps` may need workspace-aware handling           | Include `pnpm-workspace.yaml` in the fetch source; may need `postPatch` fixes                                                                                                                                         |

### What Stays the Same

- Port 3002 (from `lib/ports.nix`)
- Caddy vHost `seo.${domain}` via `protectedVHost` (Layer 2 SSO)
- Homepage tile in Productivity group
- Gatus health check with Discord alert
- Sops secret `dataforseo_api_key` → `openseo-env` template
- `AUTH_MODE=local_noauth` (no built-in auth, relies on oauth2-proxy)

### What Changes

| Before (Docker)                            | After (Native)                                            |
| ------------------------------------------ | --------------------------------------------------------- |
| Docker container via `mkDockerService`     | Systemd service via `harden {} // serviceDefaults {}`     |
| Image `ghcr.io/every-app/open-seo:v0.0.15` | Nix-built package from `github:every-app/open-seo` source |
| Volume `openseo_data:/app/.wrangler`       | `StateDirectory=openseo` → `/var/lib/openseo`             |
| Compose YAML in Nix                        | Native `systemd.services.openseo`                         |
| `mem_limit: 2g` in compose                 | `MemoryMax=2G` in systemd harden                          |
| Docker tmpfs for `/tmp`                    | systemd `TemporaryFileSystem=/tmp`                        |

---

## 2. Architecture: Current vs Target

### Current (Docker)

```
[Docker Engine]
  └── [Container: openseo]
      ├── node:22 base image
      ├── pnpm install (at every container start)
      ├── vite build (at every container start, 4GB heap)
      ├── wrangler d1 migrations apply --local
      └── vite preview --host 0.0.0.0 --port 3002
          └── workerd (local Cloudflare runtime emulator)
              ├── D1 (SQLite in /app/.wrangler/state/)
              ├── KV (2 namespaces, in-memory/local)
              ├── R2 (local filesystem)
              ├── Durable Objects (2, SQLite-backed)
              └── Workflows (2, local)
```

### Target (Native)

```
[Nix Build Time]
  └── fetchPnpmDeps (hermetic dependency fetch)
  └── pnpm install --offline --frozen-lockfile
  └── vite build (AUTH_MODE=local_noauth hardcoded, 4GB heap)
  └── Output: $out/lib/openseo/ (node_modules + dist + config + workerd binary)

[NixOS Runtime]
  └── systemd service: openseo.service
      ├── ExecStartPre: wrangler d1 migrations apply --local
      ├── ExecStart: vite preview --host 127.0.0.1 --port 3002
      ├── StateDirectory: /var/lib/openseo (persistent D1 SQLite)
      ├── Environment: DATAFORSEO_API_KEY from sops
      └── hardened: MemoryMax=2G, ProtectSystem, etc.
```

---

## 3. Phase-by-Phase Execution Plan

### Phase 1: Nix Package (`pkgs/openseo.nix`)

**Goal:** Build OpenSEO from source as a Nix derivation.

**Deliverables:**

- `pkgs/openseo-pnpm-lock.yaml` — vendored lock file (from upstream)
- `pkgs/openseo.nix` — derivation using `fetchPnpmDeps` + `pnpmConfigHook`
- Package output includes: built `dist/`, `node_modules/`, vite/wrangler configs, and a wrapper script

**Steps:**

1. Fetch `pnpm-lock.yaml` and `pnpm-workspace.yaml` from upstream
2. Create derivation with `fetchFromGitHub` for source
3. Use `fetchPnpmDeps` for hermetic dependency fetch (will need hash — set to `""` first, read from error)
4. Build phase: `AUTH_MODE=local_noauth NODE_OPTIONS=--max-old-space-size=4096 pnpm run build`
5. Install phase: copy project tree to `$out/lib/openseo/`, create `bin/openseo-migrate` and `bin/openseo-serve` wrappers

**Risk:** `workerd` binary from pnpm may fail in Nix sandbox (missing shared libs, ELF patching needed). If so, will need `autoPatchelfHook`.

**Verification:** `nix build .#openseo` succeeds, `ls result/lib/openseo/dist/` shows built assets.

### Phase 2: Flake Wiring

**Goal:** Make the package available in the flake.

**Steps:**

1. Add `open-seo` as a flake input OR use `fetchFromGitHub` inside the package (prefer the latter — no new flake input needed)
2. Add overlay entry in `overlays/shared.nix`: `openseo = prev.callPackage ../pkgs/openseo.nix {};`
3. Add to `flake.nix` packages output: `inherit (pkgs) openseo;`

**Verification:** `nix build .#openseo` works from the flake.

### Phase 3: NixOS Module Rewrite

**Goal:** Replace Docker-based module with native systemd service.

**Deliverables:**

- Rewritten `modules/nixos/services/openseo.nix` — no Docker, uses native package
- Keeps same options: `enable`, `port`, drops `imageTag` (no longer needed)

**Service definition:**

```nix
systemd.services.openseo = {
  description = "OpenSEO — self-hosted SEO suite";
  wantedBy = ["multi-user.target"];
  after = ["network.target" "sops-nix.service"];
  startLimitBurst = 5;
  startLimitIntervalSec = 300;

  serviceConfig = lib.mkMerge [
    (harden {
      MemoryMax = "2G";
      ProtectHome = false;  # not needed but explicit
    })
    (serviceDefaults {})
    {
      User = "openseo";
      Group = "openseo";
      StateDirectory = "openseo";
      WorkingDirectory = "${pkg}/lib/openseo";
      EnvironmentFile = config.sops.templates."openseo-env".path;

      Environment = [
        "PORT=${toString cfg.port}"
        "AUTH_MODE=local_noauth"
        "ALLOWED_HOST=seo.${domain}"
        "VITE_SHOW_DEVTOOLS=false"
        "NODE_OPTIONS=--max-old-space-size=2048"
      ];

      ExecStartPre = "${pkg}/bin/openseo-migrate";
      ExecStart = "${pkg}/bin/openseo-serve --port ${toString cfg.port}";
    }
  ];
};
```

**State directory handling:**

- `StateDirectory = "openseo"` → `/var/lib/openseo`
- Symlink or bind-mount `.wrangler` from state dir into the package's working directory
- Actually: set `HOME=/var/lib/openseo` and run from a writable copy, OR use `WRANGLER_HOME` env var

**Sops secrets:** Same as before — `dataforseo_api_key` in `openseo.yaml`, rendered to `openseo-env` template.

**Verification:** `nix eval .#nixosConfigurations.evo-x2.config.systemd.services.openseo` shows the service.

### Phase 4: Cleanup & Updates

**Steps:**

1. Remove `openseo` entry from `lib/images.nix` (no longer using Docker image)
2. Keep `openseo` port in `lib/ports.nix` (still needed)
3. Remove `imageTag` option from the module
4. Update `AGENTS.md` — move from Docker references to native package
5. Update `FEATURES.md` if needed
6. Update `README.md` service table

**Verification:** `nix flake check --no-build` passes.

### Phase 5: Deploy & Test

**Steps:**

1. `nix run .#pre-deploy-check` — validate no boot-breaking issues
2. `nix run .#deploy` — build and deploy
3. Verify service: `systemctl status openseo`
4. Verify endpoint: `curl http://localhost:3002`
5. Verify vHost: `curl https://seo.${domain}` (through Caddy + oauth2-proxy)
6. Verify Gatus health check picks it up
7. Run post-deploy check: `nix run .#post-deploy-check`

---

## 4. Risk Assessment

| Risk                                                            | Probability | Impact                             | Mitigation                                                                                              |
| --------------------------------------------------------------- | ----------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `workerd` binary fails in Nix (missing libs)                    | Medium      | Critical (blocks entire migration) | Use `autoPatchelfHook`; if it still fails, fall back to Docker                                          |
| `fetchPnpmDeps` doesn't handle pnpm workspaces                  | Medium      | High                               | May need to flatten workspace or use a custom fetch derivation                                          |
| Vite build fails in Nix sandbox (network access needed)         | Low         | High                               | Vite build should be offline after `pnpm install`. If not, use `--offline`                              |
| Cloudflare bindings don't work in `vite preview` outside Docker | Low         | Medium                             | The `@cloudflare/vite-plugin` handles this the same way Docker does                                     |
| Data migration from Docker volume to native state dir           | Medium      | Medium                             | Copy `/var/lib/docker/volumes/openseo_data/_data/` to `/var/lib/openseo/.wrangler/` before first deploy |
| Build takes too long (>30min)                                   | Low         | Low                                | Acceptable on evo-x2 (128GB RAM, fast NVMe)                                                             |

---

## 5. Rollback Plan

If the migration fails at any phase:

1. The old Docker-based module is preserved in git history
2. `git revert` the migration commit to restore Docker module
3. Docker volume data is untouched (Docker daemon still running)
4. No data loss — the D1 SQLite is the same format in both paths

---

## 6. Fallback: Docker Image from Nix Build

If `workerd` proves impossible to run outside Docker, a **hybrid approach** is possible:

- Build a Docker image with `pkgs.dockerTools.buildImage` (reproducible, Nix-built)
- Run via the existing `oci-containers` infrastructure (no Docker compose, just a container)
- This gives Nix reproducibility without the `workerd` binary headache

This is NOT the primary plan but documented as Plan B.

---

## 7. Completion Status (2026-07-11)

### Phases Completed

| Phase                 | Status  | Notes                                                                                                                                                                                                                                            |
| --------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Phase 1: Nix Package  | DONE    | `pkgs/openseo.nix` builds v0.0.26 from source. `autoPatchelfHook` + `stdenv.cc.cc.lib` patches all native addons (workerd, sharp, lightningcss, libsql, oxlint, tailwindcss-oxide). `LD_LIBRARY_PATH` in `preBuild` avoids `/build/` RPATH leaks |
| Phase 2: Flake Wiring | DONE    | Overlay in `overlays/shared.nix` (Linux-only), exposed in `flake.nix` packages                                                                                                                                                                   |
| Phase 3: NixOS Module | DONE    | Native systemd service, no Docker. Staging script symlinks Nix store to `/var/lib/openseo/project/`. ExecStartPre runs stage + D1 migrations                                                                                                     |
| Phase 4: Cleanup      | DONE    | Removed Docker image from `lib/images.nix`. Updated AGENTS.md + FEATURES.md                                                                                                                                                                      |
| Phase 5: Deploy       | PENDING | Code ready — requires deploy-time data migration (below)                                                                                                                                                                                         |

### Verification

- `nix build .#openseo` — succeeds, `workerd` properly patched with Nix glibc
- `nix flake check --no-build` — all checks passed
- `nix eval` full system — succeeds

### Deploy-Time Data Migration

```bash
# 1. Stop the old Docker-based service
sudo systemctl stop openseo.service

# 2. Copy D1 SQLite data from Docker volume to native state dir
sudo mkdir -p /var/lib/openseo/.wrangler
sudo cp -r /var/lib/docker/volumes/openseo_data/_data/* /var/lib/openseo/.wrangler/
sudo chown -R openseo:openseo /var/lib/openseo/

# 3. Deploy the new native module
nix run .#deploy

# 4. Verify
sudo systemctl status openseo
curl -s http://localhost:3002 | head -5
```

### Version Upgrade

This migration also upgrades OpenSEO from v0.0.15 (old Docker image) to v0.0.26 (latest). D1 migrations run automatically at `ExecStartPre`.
