# SystemNix — Full Comprehensive Status Report

**Date:** 2026-06-05 07:27 CEST
**Session:** 119 (overlay cleanup + flake lock build fix sprint)
**Branch:** master @ `b5f92c07`
**Build:** `nh os boot .` — GREEN (40.5 GiB → 38.9 GiB, -1.66 GiB)

---

## A. Fully Done

### This Session (6 commits, 2026-06-05)

| Commit | What | Impact |
|--------|------|--------|
| `38974be` | PMA: wire excludePaths for forks/archived, update flake lock | PMA filters out forked/archived repos from discovery |
| `d27bb68` | Fix all Go package builds after flake.lock update | Fixed 8+ vendor hash mismatches (art-dupl, hierarchical-errors, golangci-lint-auto-configure, buildflow, etc.) |
| `cdc3ff3` | Remove fragile sed/patch workarounds for emeet-pixyd and hierarchical-errors | Eliminated 2 Nix-level hacks, converted to clean passthrough overlays |
| `1d51567` | Update hierarchical-errors flake input and vendorHash | Removed `proxyVendor` workaround, clean vendorHash override only |
| `ce45876` | Update emeet-pixyd flake input after upstream httputil removal | Zero overlay overrides needed — upstream inlined the trivial Chain() function |
| `b5f92c0` | Update go-filewatcher flake input to fix PMA build | Root cause: SystemNix lock had go-filewatcher 28 commits behind PMA's lock |

### Upstream Fixes Done (External Repos)

| Repo | What | How |
|------|------|-----|
| **emeet-pixyd** | Removed `httputil` dependency | Inlined `Chain()` middleware (4-line for loop) directly into `middleware.go` |
| **hierarchical-errors** | Fixed incomplete `go.sum` | `go mod tidy` to add missing transitive deps (go-gitignore, etc.) |
| **PMA** (projects-management-automation) | Fixed Go module build for cmdguard v2 | Changed imports to `/v2` prefix, added missing submodules (daemon, testutil, enrichment/*), postPatch for cmdguard v2 replace directive |
| **PMA** | Added go-filewatcher subModules | Ensured all nested submodules (testhelpers/graphtest, etc.) are declared in mkPreparedSource |

### Fully Done (Prior Sessions, Still Valid)

- Cross-platform Nix flake (Darwin + NixOS) — stable
- 37 service modules auto-discovered via flake-parts
- All overlays extracted to `overlays/` directory
- SOPS + age secret management via SSH host keys
- Caddy reverse proxy with forward-auth (oauth2-proxy + Pocket ID)
- Forgejo with Actions runner, declarative repo mirroring
- SigNoz observability (traces/metrics/logs, 7 alert rules, dashboard provisioning)
- Immich with VA-API hardware transcoding
- Dozzle Docker log viewer
- BTRFS snapshot automation (btrbk daily, verify timer)
- SystemD hardening helpers (harden, hardenUser, serviceDefaults)
- mkDockerServiceFactory, mkStateDir, mkSecretCheck, mkHttpCheck helpers
- Centralized port registry (`lib/ports.nix`)
- Pinned container images (`lib/images.nix`)
- Stale LSP cleanup timer (daily, kills processes >24h)
- Disk growth check timer (daily, alerts if /data grows >5G/24h)
- Ghostty migration from Kitty as primary terminal
- All `writeShellScript`/`writeShellScriptBin` migration complete

---

## B. Partially Done

| Area | Status | Gap |
|------|--------|-----|
| **PMA flake.lock** | PMA uses `path:` override in SystemNix | Needs revert to `git+ssh://` after PMA is pushed to GitHub |
| **PMA upstream push** | Committed locally (`ce5105d`) | NOT pushed to GitHub yet — blocks flake.lock revert |
| **Darwin parity** | Home Manager has 7 lines | No terminal, editor, theme parity with NixOS (4h estimate) |
| **Flake inputs audit** | 48 inputs identified | Not audited for stale/unused entries |
| **nix-colors integration** | Input exists in flake | Not wired to Home Manager — 17+ hardcoded colors remain |
| **Photomap** | Module exists, disabled | CLIP embedding visualization, port 8051, not deployed |
| **Minecraft** | Module exists, disabled | JDK 25, ZGC, whitelist — not deployed |
| **DNS failover (rpi3)** | Module + config exist | Hardware not provisioned |

---

## C. Not Started

- [ ] Configure secondary LLM provider for Hermes (OpenRouter/OpenAI) as GLM-5.1 fallback
- [ ] Hermes git remote access — SSH deploy key for sandbox
- [ ] Monitor GLM-5.1 rate limit — verify cron jobs recovered
- [ ] Add per-threshold SigNoz channel routing (critical→Discord, warning→log)
- [ ] Create `just status` command for automated status report generation
- [ ] Provision Raspberry Pi 3 for DNS failover cluster
- [ ] Create shared flake-parts template (mkGoPackage, checks, devshells)
- [ ] Convert go-auto-upgrade `path:` inputs to SSH URLs
- [ ] Verify boot time (~35s target with all optimizations)
- [ ] Test Discord alert channel (`POST /api/v1/channels/test`)
- [ ] Check SigNoz provision logs (channel + rule creation, 4 new dashboards)
- [ ] Verify Gatus endpoints at `status.home.lan`

---

## D. Totally Fucked Up / Critical Issues

### D1. PMA flake.lock is on `path:` Override (BLOCKS DEPLOYMENT)

The SystemNix `flake.lock` has PMA locked as:
```json
"locked": { "type": "path", "path": "/home/lars/projects/projects-management-automation" }
```
This means:
- **Cannot reproduce on another machine** — absolute local path
- **Cannot deploy to NixOS** — `nh os boot .` succeeds but `just switch` would use this path dependency
- PMA is committed locally (`ce5105d`) but **NOT pushed to GitHub**

**Fix:** Push PMA → revert flake.lock to `git+ssh://`

### D2. Vendor Hash Fragility Pattern

Every time ANY upstream Go dependency changes (even transitive), all consumer `vendorHash` values break. This session fixed 8+ packages in a cascade. There is no automated mechanism to:
- Detect which package broke
- Update only the affected vendorHash
- Validate all packages build after an update

**Impact:** `nix flake lock --update-input X` frequently breaks 3-5 unrelated packages.

### D3. SystemNix Lock vs. PMA Lock Drift

The go-filewatcher incident (PMA's lock at `e8326ce`, SystemNix's at `85d643a` — 28 commits behind) revealed that **when PMA is a SystemNix input with `follows`**, its dependency inputs come from SystemNix's lock, not PMA's own lock. This means:
- SystemNix must manually keep ALL of PMA's transitive inputs up to date
- No automated check detects this drift
- Build failures appear as "undefined symbol" Go compile errors, not Nix eval errors

### D4. Darwin Disk Constraints Ongoing

256GB SSD at 90%+ full. Every build risks disk exhaustion. `nix-collect-garbage` hangs on Darwin.

---

## E. What We Should Improve

### E1. Automated Vendor Hash Update

Create a `just update-vendor-hashes` command that:
1. Sets `vendorHash = ""` for each Go overlay
2. Builds each package
3. Captures the `got:` hash
4. Updates the Nix file
5. Reports pass/fail per package

This already exists in the justfile but doesn't handle the cascade case.

### E2. Flake Lock Consistency Check

A CI or pre-commit check that verifies: for every flake input that uses `follows`, the locked rev in SystemNix's lock is >= the locked rev in the upstream's own lock. Would catch the go-filewatcher drift.

### E3. Reduce Overlay Complexity

After this session, overlays are cleaner. But art-dupl still needs a postBuild that copies templ/runtime into vendor. This should be fixed upstream in art-dupl (add a `go.mod` replace or vendor the runtime package).

### E4. Dozzle Module Should Be a Proper Service Module

Currently inline in `configuration.nix` because creating a module with options caused `nix flake check` failure. This is a known issue — should investigate and create a proper `modules/nixos/services/dozzle.nix`.

### E5. Go Submodule Discovery Automation

`mkPreparedSource` requires manually listing all submodules. When upstream adds a new Go submodule, builds break with cryptic "cannot find module" errors. A discovery step or `go list` integration would prevent this.

### E6. Darwin Home Manager Parity

Darwin has 7 lines of Home Manager config. NixOS has full terminal/editor/theme setup. Either invest in parity or formally de-prioritize Darwin.

### E7. Status Report Automation

Too many manual status reports (120+ files in `docs/status/`). A `just status` command that auto-generates from git log, service states, and build status would save significant time.

### E8. PMA's cmdguard v2 Hack

PMA's `postPatch` manually copies cmdguard into `_local_deps/`, fixes test imports, and injects a replace directive. This is fragile — cmdguard should be properly handled by `mkPreparedSource` (needs support for dual module paths with `/v2` suffix).

---

## F. Top 25 Things We Should Get Done Next

### Critical (Must Do This Session)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Push PMA to GitHub** | Unblocks flake.lock revert | 30 sec |
| 2 | **Revert SystemNix PMA flake.lock to `git+ssh://`** | Reproducible builds | 1 min |
| 3 | **Run `just switch`** | Deploy all changes to evo-x2 | 3 min |

### High Priority (This Week)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 4 | **Verify boot time** — target ~35s | Performance baseline | 5 min |
| 5 | **Test Discord alert channel** via `POST /api/v1/channels/test` | Alerting reliability | 5 min |
| 6 | **Check SigNoz provision logs** — channel + rule + dashboard creation | Observability verification | 10 min |
| 7 | **Flake inputs audit** — 48 inputs, remove stale/unused | Maintenance burden reduction | 30 min |
| 8 | **Create `just status` command** for automated status reports | DX improvement | 1h |
| 9 | **Fix art-dupl upstream** — inline templ/runtime vendor hack | Last remaining Nix-level patch | 30 min |

### Medium Priority (Next 2 Weeks)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 10 | **Flake lock consistency check** — detect `follows` drift | Prevent go-filewatcher-type failures | 2h |
| 11 | **Improve `just update-vendor-hashes`** — cascade detection | Reduce manual cascade fixing | 2h |
| 12 | **Convert Dozzle from inline to proper service module** | Code quality, consistency | 1h |
| 13 | **Configure secondary LLM provider for Hermes** | Reliability | 30 min |
| 14 | **Fix PMA cmdguard v2 handling in mkPreparedSource** | Eliminate fragile postPatch | 2h |
| 15 | **nix-colors integration** — wire to Home Manager | Theme consistency | 6h |
| 16 | **Add per-threshold SigNoz channel routing** | Alert quality | 30 min |
| 17 | **Hermes git remote access** — SSH deploy key | Agent functionality | 30 min |

### Lower Priority (Next Month)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 18 | **Darwin Home Manager parity** — terminal, editor, theme | Cross-platform consistency | 4h |
| 19 | **Go submodule discovery automation** in mkPreparedSource | Prevent manual listing errors | 3h |
| 20 | **Provision Raspberry Pi 3** for DNS failover cluster | Infrastructure redundancy | 4h (hardware) |
| 21 | **Wire Pi 3 as secondary DNS** | DNS resilience | 2h |
| 22 | **Create shared flake-parts template** (mkGoPackage, checks, devshells) | Ecosystem standardization | 4h |
| 23 | **Convert go-auto-upgrade `path:` inputs to SSH URLs** | Reproducibility | 30 min |
| 24 | **Photomap deployment** — enable and test CLIP visualization | Feature completion | 1h |
| 25 | **Minecraft server deployment** — enable and test | Fun | 30 min |

---

## G. Top #1 Question I Cannot Answer Myself

**Should Darwin be actively maintained to parity with NixOS, or formally de-prioritized?**

The Darwin config (macOS, `Lars-MacBook-Air`) has:
- 7 lines of Home Manager config (vs 200+ for NixOS)
- No terminal/editor/theme configuration
- 256GB SSD at 90%+ capacity (every build is risky)
- No desktop config
- Actively used as a machine (per AGENTS.md)

Investing in parity means ~4h of work + ongoing maintenance of a severely resource-constrained machine. Not investing means Darwin becomes a second-class citizen that slowly bit-rots. This is a product/usage decision I can't make — it depends on how heavily Darwin is actually used day-to-day vs. being a secondary/travel machine.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Commits this session | 6 |
| External repo fixes | 3 (emeet-pixyd, hierarchical-errors, PMA) |
| Overlay hacks removed | 2 (sed postPatch, proxyVendor workaround) |
| Build status | GREEN |
| Closure size delta | -1.66 GiB (40.5 → 38.9) |
| Uncommitted changes | None |
| Blocking issues | PMA path: override (needs upstream push) |
