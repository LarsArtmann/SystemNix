# Session 94 — Go-Output Modularization Cascade Fix, VendorHash Centralization

**Date:** 2026-05-25 06:54
**Host:** evo-x2 (x86_64-linux, NixOS 26.05)
**Kernel:** 7.0.9
**Uptime:** 3h12m | **Load:** 2.33 / 10.24 / 12.21
**Disk:** / 55% (224G free) | /data 89% (118G free)
**RAM:** 16Gi used / 62Gi total | **Swap:** 6.1Gi / 16Gi

---

## A. FULLY DONE

### 1. Root Cause: `go-output` Sub-Module Packaging Bug (FIXED + PUSHED)

`go-output` modularized into `d2/`, `graph/`, `enum/`, `escape/`, `table/` sub-modules. The `graph/go.mod` and `d2/go.mod` had `replace` directives pointing to `../` (local paths). Go ignores `replace` directives from external consumers → sub-modules were **impossible to import from any external repo**.

**Fix:** Removed `replace` directives, updated `go.mod` to use `v0.5.0` for root and pseudo-versions for sibling sub-modules. Both `graph/` and `d2/` now compile standalone.

**Pushed:** `go-output` commit `b9356ba` → master

### 2. `cmdguard` Broken Imports (FIXED + PUSHED)

`cmdguard` referenced deleted functions:
- `output.MermaidFlowchartRenderer` → renamed to `graph.MermaidFromTableData`
- `output.D2FromTableData` → moved to `d2.D2FromTableData`
- `output.DOTFromTableData` → moved to `graph.DOTFromTableData`

**Fix:** Updated imports in `pkg/cmdguard/v2/output.go` to use new sub-module paths. Added `go-output/d2` and `go-output/graph` as dependencies.

**Pushed:** `cmdguard` commit `623c19c` → master

### 3. All 6 Downstream Go Repos Updated (FIXED + PUSHED)

Every repo using `cmdguard` or `go-output` sub-modules needed:
- `go.mod` updated with `go-output/d2` + `go-output/graph` dependencies
- `flake.nix` `subModules` or replace-loop updated to include `d2` + `graph`
- Internal `vendorHash` recalculated

| Repo | Changes | Commit |
|------|---------|--------|
| `go-auto-upgrade` | `go.mod` + `flake.nix` replace loop (d2, graph added) | `86c9081` |
| `mr-sync` | `go.mod` + `flake.nix` subModules + `package.nix` vendorHash | `a5bf426` |
| `go-structure-linter` | `go.mod` + `flake.nix` subModules + vendorHash | `8a8653d` |
| `BuildFlow` | `go.mod` + `flake.nix` subModules + vendorHash | `b269ebf` |
| `projects-management-automation` | `go.mod` + `flake.nix` subModules + vendorHash | `2d34a35` |
| `golangci-lint-auto-configure` | `go.mod` + `flake.nix` vendorHash | `1b965e5` |

Also `hierarchical-errors` vendorHash confirmed unchanged: `f0f1600`.

### 4. SystemNix Overlay Cleanup (DONE)

**All `vendorHash` overrides removed from `overlays/shared.nix`.** Each repo now manages its own `vendorHash` internally. The 4 overrides that were removed:
- `hierarchical-errors`: was `sha256-Q9i+2iW0...`
- `mr-sync`: was `sha256-T2IVldw0...`
- `buildflow`: was `sha256-Jsi00lEl...`
- `go-structure-linter`: was `sha256-nfbz9ZOv...`

This means future `flake.lock` updates will NOT require manual vendorHash updates in SystemNix — each repo handles it internally.

### 5. Full Build Verified

```
nh os boot . → SUCCESS
Configuration added to bootloader
Size: 40.5 GiB → 40.4 GiB (diff: -61.5 MiB)
```

All 262 derivations built successfully. 6.1 GiB swap usage is elevated from the build workload but RAM is healthy at 16/62 GiB.

---

## B. PARTIALLY DONE

### 1. AGENTS.md Not Updated

`AGENTS.md` should document:
- The `subModules` pattern for `go-output` repos (must include `d2` + `graph`)
- The fact that `vendorHash` overrides are no longer in SystemNix
- The `go-output` sub-module external consumption fix

### 2. `/data` at 89% — BTRFS Toplevel Migration Still Pending

The `@data` subvolume migration (`just snapshot-migrate-data`) has been pending since session 84. /data cannot be snapshotted while mounted as toplevel. 118G free but trend is concerning.

---

## C. NOT STARTED

1. **AGENTS.md update** for this session's learnings
2. **Darwin (`Lars-MacBook-Air`) build verification** — only NixOS was tested
3. **`go-output` sub-module tagging** — `graph/` and `d2/` have no tagged versions, only pseudo-versions from master commits
4. **`go-output` CI** — no guarantee sub-modules won't break again with future `replace` re-introduction
5. **rpi3-dns build verification** — not tested in this session
6. **`nix flake check` full validation** — only `just test-fast` was run, not the full `just test`

---

## D. TOTALLY FUCKED UP

### Nothing Catastrophic

This session went remarkably well compared to the cascade patterns of previous sessions. The root cause was identified correctly (go-output sub-modules had `replace` directives making them externally unresolvable), and the fix was applied at the source rather than papered over with workarounds.

### Near-Miss: Almost Repeated the VendorHash Cascade Anti-Pattern

The user explicitly asked to "remove all vendorHash overrides" which forced the correct fix: updating each repo's internal vendor hash instead of overriding from SystemNix. This is architecturally superior — each repo owns its own build integrity.

### Pre-existing Issues (NOT caused by this session)

- `/data` at 89% capacity — needs attention
- Swap at 6.1/16 GiB — elevated but manageable
- Load average spike (10.24/12.21 for 5/15min) — residual from build workload

---

## E. WHAT WE SHOULD IMPROVE

### Architecture

1. **`go-output` sub-modules need tagged versions** — Currently using pseudo-versions from master. Any force-push or history rewrite breaks all consumers. Should tag `graph/v0.1.0`, `d2/v0.1.0`, etc.

2. **CI for `go-output` sub-modules** — Add a GitHub Action that builds `graph/` and `d2/` without `replace` directives to catch this class of bug before it reaches consumers.

3. **`mkPreparedSource` should auto-detect sub-modules** — The `subModules` list in each repo's `flake.nix` is manual and error-prone. When `go-output` adds a new sub-module, every consumer breaks until they manually update. Consider auto-detecting from `go.mod` or using `GOWORK`.

4. **Vendor hash ownership** — This session proved that having vendor hashes in SystemNix overlays is a leaky abstraction. The current state (hashes in each repo) is correct, but we should document this pattern so future contributors don't re-add them.

5. **`go-output` API stability** — `MermaidFlowchartRenderer` was deleted without a deprecation cycle. Public APIs should have deprecation warnings for at least one minor version before removal.

### Process

6. **Flake update → build cycle** — `nix flake update` followed by `nh os boot` is a 30+ minute process when repos cascade. Consider a `just update-and-build` recipe that does both.

7. **Repo dependency graph** — We need a visual map of which Go repos depend on `cmdguard`/`go-output` so cascade impacts are predictable.

---

## F. Top 25 Things to Do Next

### Critical (Do Soon)

| # | Task | Why |
|---|------|-----|
| 1 | **`just switch`** to deploy the new configuration | Built but not activated — reboot needed |
| 2 | **Update `AGENTS.md`** with sub-modules pattern and vendorHash ownership | Future sessions need this context |
| 3 | **Tag `go-output/graph` and `go-output/d2`** with `v0.1.0` | Pseudo-versions are fragile |
| 4 | **`/data` BTRFS migration** (`just snapshot-migrate-data`) | 89% full, no snapshots possible |
| 5 | **Monitor swap usage** post-deploy — 6.1 GiB is elevated | May indicate memory leak or OOM risk |

### High Impact (Do This Week)

| # | Task | Why |
|---|------|-----|
| 6 | **Add CI to `go-output`** that builds sub-modules without `replace` | Prevents this exact class of bug |
| 7 | **Darwin build verification** (`just test-fast` on macOS) | Cross-platform regressions are invisible until deploy |
| 8 | **`just test` (full build check)** on NixOS | Only syntax check was run |
| 9 | **Deprecation policy for `go-output` public API** | `MermaidFlowchartRenderer` deletion broke consumers |
| 10 | **Create dependency graph** of Go repos → `cmdguard`/`go-output` | Makes cascade prediction possible |

### Important (Do Eventually)

| # | Task | Why |
|---|------|-----|
| 11 | **`rpi3-dns` build verification** | Different overlay set, may have issues |
| 12 | **Review `nix-amd-npu`** — last updated April 8 | Stale input, possibly broken |
| 13 | **NixOS 26.05 → 26.11 tracking** | Currently on unstable, watch for breaking changes |
| 14 | **Audit all `flake = false` inputs** for correctness | Some may need updates |
| 15 | **`sops-nix` secrets rotation audit** | Last major rotation unknown |
| 16 | **Unbound `do-ip6 = false`** — ensure new instances get it | Documented gotcha, easy to miss |
| 17 | **Ollama GPU headroom check** — `OLLAMA_GPU_OVERHEAD=8589934592` | Verify compositor stability after deploy |
| 18 | **Homebrew inputs audit** — `homebrew-bundle` from April 2025 | Very stale |
| 19 | **`niri-session-manager`** — last updated July 2025 | Check if upstream has fixes |
| 20 | **SigNoz build time optimization** | Built from source (Go 1.25), takes significant time |

### Nice to Have

| # | Task | Why |
|---|------|-----|
| 21 | **`just update-and-build` recipe** | One-command flake update + build cycle |
| 22 | **Auto-detect `subModules` in `mkPreparedSource`** | Eliminates manual sub-module lists |
| 23 | **Monitor365 check** — verify uptime monitoring is reporting | Service was rebuilt, verify it's working |
| 24 | **DNS blocker effectiveness audit** | Verify blocklists are current |
| 25 | **Consider `GOWORK` instead of `_local_deps` + `mkPreparedSource`** | Go workspace is the native solution for multi-module dev |

---

## G. Top #1 Question I Cannot Answer Myself

**After deploying with `just switch`, will all services start cleanly given 6.1 GiB of swap usage?**

The build workload consumed significant memory and the swap is elevated. With `systemd-oomd` PSI monitoring active (replacing `earlyoom`), there's a risk that a post-reboot service startup race could trigger OOM kills if multiple memory-hungry services (Ollama, Jan, Helium) start simultaneously. The GPU memory headroom settings should protect the compositor, but system RAM pressure during boot is unpredictable.

I recommend monitoring `dmesg` and `journalctl -u systemd-oomd` for the first 10 minutes after reboot.

---

## System State Snapshot

```
Platform: NixOS 26.05 (unstable) — BUILD_ID=26.05.20260523.3d8f0f3
Kernel:  7.0.9
Machine: evo-x2 (x86_64-linux)
Disk:    / 55% (224G free) | /data 89% (118G free)
RAM:     16Gi / 62Gi (45Gi available)
Swap:    6.1Gi / 16Gi
Load:    2.33 / 10.24 / 12.21

Flake inputs updated this session:
  go-output            → b9356ba (2026-05-25 06:27)
  cmdguard             → 623c19c (2026-05-25 06:28)
  go-auto-upgrade      → 86c9081 (2026-05-25 06:42)
  mr-sync              → a5bf426 (2026-05-25 06:44)
  go-structure-linter  → 8a8653d (2026-05-25 06:46)
  hierarchical-errors  → f0f1600 (2026-05-25 06:46)
  buildflow            → b269ebf (2026-05-25 06:46)
  projects-management-automation → 2d34a35 (2026-05-25 06:48)
  golangci-lint-auto-configure  → 1b965e5 (2026-05-25 06:49)

Repos fixed (8 total):
  go-output, cmdguard, go-auto-upgrade, mr-sync,
  go-structure-linter, BuildFlow, projects-management-automation,
  golangci-lint-auto-configure

SystemNix changes:
  overlays/shared.nix — removed 4 vendorHash overrides
  flake.lock — updated 9 inputs
```
