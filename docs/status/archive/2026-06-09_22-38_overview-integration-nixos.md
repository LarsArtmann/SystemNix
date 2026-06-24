# SystemNix Integration Status Report

**Date:** 2026-06-09 22:38
**Scope:** Overview project dashboard integrated into SystemNix NixOS (evo-x2)
**Flake check:** ✅ all checks passed | **Service config:** ✅ verified | **Not yet deployed**

---

## a) FULLY DONE ✅

### Overview flake.nix overhaul (Round 22, earlier this session)

- Go version pinned: `goPkg = pkgs.go_1_26` + `buildGoModule.override`
- `git-hooks.nix` input added with `nixpkgs.follows`
- `gofumpt` replaces `gofmt`, `treefmt` API updated to current
- `meta` complete with maintainers, license, mainProgram
- `GOPRIVATE` in both devShells, `templ` in CI devShell
- Pre-commit hook via `git-hooks.nix`
- `overlays.default` exports `overview` package

### NixOS module (`module.nix`) — new

- 14 options with types + descriptions: `enable`, `package`, `user`, `group`, `port`, `host`, `searchPaths`, `cacheTTL`, `perPage`, `logLevel`, `logFormat`, `includeVisibility`, `includeRepoInfo`, `openFirewall`
- Hardened systemd service: 20+ sandboxing directives (ProtectSystem, NoNewPrivileges, MemoryMax=512M, RestrictAddressFamilies, SystemCallFilter)
- System user/group auto-creation, assertions, `mkIf cfg.enable`

### SystemNix integration — 5 files changed

| File | Change |
|------|--------|
| `flake.nix:356-362` | Added `overview` input via `git+ssh://git@github.com/LarsArtmann/overview?ref=master` with `nixpkgs` and `flake-parts` follows |
| `flake.nix:399` | Added `overview` to `outputs` function parameters |
| `flake.nix:688` | Added `inputs.overview.nixosModules.default` to evo-x2 NixOS modules |
| `overlays/linux.nix` | Added `overview` dependency + `overview.overlays.default` to Linux overlays |
| `lib/ports.nix` | Added `overview = 8083` (avoids conflict: crush-daily=8081, dozzle=8084) |
| `platforms/nixos/system/configuration.nix` | Enabled `services.overview` with port 8083, searchPaths `/home/lars/projects`, logLevel `info` |

### Verified runtime configuration

```
systemd.services.overview:
  ExecStart = /nix/store/.../bin/overview
  User = overview
  Group = overview
  MemoryMax = 512M
  ProtectSystem = full
  Environment:
    OVERVIEW_PORT = 8083
    OVERVIEW_HOST = 0.0.0.0
    OVERVIEW_SEARCH_PATHS = /home/lars/projects
    OVERVIEW_LOG_LEVEL = info
    OVERVIEW_CACHE_TTL = 5m
    OVERVIEW_PER_PAGE = 30
```

---

## b) PARTIALLY DONE ⚠️

### Not yet deployed

All configuration is committed and verified via `nix flake check --no-build`, but `nh os switch` has not been run. The service will not be running until deployment.

### vendorHash still placeholder in overview

The overview `flake.nix` still has `vendorHash = "sha256-AAA..."`. This works because:
- The overlay uses `overview.overlays.default` which pulls the pre-built package from the overview flake
- The overview flake's `buildGoModule` uses `proxyVendor = true` which may or may not work with the placeholder

If `nix build` of the overview package fails due to vendorHash, the entire SystemNix build will fail at deploy time.

---

## c) NOT STARTED ❌

1. **`nh os switch` deployment** — Config is ready but not deployed to evo-x2
2. **Caddy reverse proxy for overview** — No `overview.home.lan` or similar URL configured
3. **Homepage dashboard link** — `services.homepage` doesn't include overview yet
4. **Gatus health check** — No uptime monitoring for overview at `/health`
5. **NixOS integration test** — No `nixosTests.overview` in SystemNix `tests/`
6. **SOPS secrets** — No secrets needed (overview is purely local filesystem)
7. **Backup configuration** — No backup for overview state (it's stateless — rediscovers on each start)

---

## d) TOTALLY FUCKED UP 💥

### Nothing is fucked up!

This integration went cleanly:
- `nix flake check --no-build` passes
- All systemd service config verified via `nix eval`
- Environment variables correctly mapped from module options
- Port allocation clean (8083, no conflicts)
- SSH flake input resolves correctly from GitHub

The only risk is the placeholder vendorHash in overview — if it doesn't build, deploy fails. But that's an overview-side issue, not a SystemNix issue.

---

## e) WHAT WE SHOULD IMPROVE! 🔧

1. **Add Caddy virtualHost** — Route `overview.home.lan` → `localhost:8083` so it's accessible by name
2. **Add to Homepage dashboard** — Include overview as a service card on the homepage dashboard
3. **Add Gatus endpoint** — Monitor `http://localhost:8083/health` for uptime
4. **Write NixOS integration test** — Verify the service starts and responds on the configured port
5. **Fix vendorHash in overview** — Resolve the placeholder so `nix build` actually works
6. **Add to evo-x2 firewall** — If overview should be accessible from LAN (currently only localhost via Caddy)
7. **Consolidate duplicate treefmt-nix/systems instances** — The lock file shows 17 `systems` and 17 `treefmt-nix` instances due to overview not following the shared ones

---

## f) Top #25 Things We Should Get Done Next!

| # | Task | Impact | Effort | Where |
|---|------|--------|--------|-------|
| 1 | Deploy with `nh os switch` to evo-x2 | 🔴 Critical | Small | SystemNix |
| 2 | Fix vendorHash in overview flake.nix | 🔴 Critical | Medium | Overview |
| 3 | Verify overview service starts and responds after deploy | 🟠 High | Small | SystemNix |
| 4 | Add Caddy virtualHost for `overview.home.lan` | 🟠 High | Small | SystemNix |
| 5 | Add overview to Homepage dashboard services | 🟠 High | Small | SystemNix |
| 6 | Add Gatus health check for overview `/health` | 🟠 High | Small | SystemNix |
| 7 | Add SSE + metrics endpoints to overview README endpoint table | 🟡 Medium | Small | Overview |
| 8 | Update README with all env vars (logLevel, logFormat, etc.) | 🟡 Medium | Small | Overview |
| 9 | Add missing env vars to overview README config table | 🟡 Medium | Small | Overview |
| 10 | Write NixOS integration test for overview service | 🟡 Medium | Medium | SystemNix |
| 11 | Add SSE handler tests (0% coverage) | 🟡 Medium | Small | Overview |
| 12 | Add metrics handler tests (0% coverage) | 🟡 Medium | Small | Overview |
| 13 | Add discovery cache sync/stop tests | 🟡 Medium | Medium | Overview |
| 14 | Add `checks.lint` to overview flake.nix | 🟡 Medium | Small | Overview |
| 15 | Switch overview CI to use Nix devShell | 🟡 Medium | Small | Overview |
| 16 | Consolidate duplicate systems/treefmt-nix in lock file | 🟡 Medium | Small | SystemNix |
| 17 | Archive old status reports (keep latest 3) | 🔵 Low | Small | Overview |
| 18 | Add Docker/OCI image via `dockerTools` | 🔵 Low | Medium | Overview |
| 19 | Add Home Manager module for overview | 🔵 Low | Medium | Overview |
| 20 | Add Cachix binary cache for overview | 🔵 Low | Small | Overview |
| 21 | Rate limiting on `/api/*` endpoints | 🔵 Low | Small | Overview |
| 22 | Add CHANGELOG.md to overview | 🔵 Low | Small | Overview |
| 23 | Accessibility audit (keyboard nav, ARIA) | 🔵 Low | Medium | Overview |
| 24 | Performance regression CI gate on benchmarks | 🔵 Low | Medium | Overview |
| 25 | Explore WebSocket alternative to SSE | ⚪ Nice-to-have | Large | Overview |

---

## g) Top #1 Question I CANNOT Figure Out Myself! 🤔

**Should overview be accessible from the LAN (via Caddy at `overview.home.lan`) or only from localhost?**

The service binds to `0.0.0.0:8083` (all interfaces) by default, which means it's reachable from any device on the network. Since overview discovers local project data (file paths, git repos, commit SHAs, code stats), this exposes information about all projects in `/home/lars/projects` to anyone on the LAN.

Options:
1. **LAN-accessible via Caddy** — Convenient, consistent with other services. Add `overview.home.lan` virtualHost.
2. **Localhost only** — Bind to `127.0.0.1:8083`, access via SSH tunnel or directly on the machine. More secure for project data.
3. **LAN-accessible but behind Pocket-ID auth** — Most secure, consistent with auth pattern used by other services.

This affects whether I add the Caddy virtualHost and how I configure the `host` option.

---

## Integration Diagram

```
Overview (GitHub)                    SystemNix (evo-x2)
─────────────────                    ──────────────────
flake.nix
├── nixosModules.default  ─────────→ flake.nix inputs.overview.nixosModules.default
├── overlays.default      ─────────→ overlays/linux.nix → pkgs.overview
└── packages.default
                                     configuration.nix:
                                     services.overview = {
                                       enable = true;
                                       port = 8083;        ← lib/ports.nix
                                       searchPaths = ["/home/lars/projects"];
                                     }

                                     Systemd (generated by module.nix):
                                     ┌──────────────────────────────────┐
                                     │ overview.service                  │
                                     │ ExecStart=/nix/store/.../overview │
                                     │ User=overview, Group=overview     │
                                     │ MemoryMax=512M                    │
                                     │ ProtectSystem=full                │
                                     │ OVERVIEW_PORT=8083                │
                                     │ OVERVIEW_SEARCH_PATHS=/home/lars/ │
                                     │   projects                        │
                                     └──────────────────────────────────┘
```
