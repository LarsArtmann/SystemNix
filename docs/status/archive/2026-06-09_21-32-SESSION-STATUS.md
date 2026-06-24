# Status Update — 2026-06-09 21:32 CEST

## 1. What Was Done (This Session)

### SystemNix — Add ecapture
- **Added `ecapture` (v1.5.2 from nixpkgs)** to `platforms/common/packages/base.nix:247` in the `linuxUtilities` block.
- **Updated docs:** `docs/cybersecurity-tools-evo-x2.md` now lists ecapture alongside tcpdump/netsniff-ng.
- **Committed:** `578f00ea` — "feat: add ecapture SSL/TLS eBPF capture tool to NixOS system packages"
- **Pushed to origin/master.**
- **Verified:** `just test-fast` passes. `nix eval` confirms ecapture is in evo-x2 system packages.

### monitor365 — Fix `monitor365-ui` Nix Build (Pre-existing Failure)
The `monitor365-ui` trunk/WASM build was broken (documented since at least 2026-06-09 in status docs). This blocked `just switch` / `nh os boot` on evo-x2 because `monitor365-server` depends on it.

**Root causes fixed:**
1. **Trunk.toml target misconfiguration** — `target = "wasm32-unknown-unknown"` was interpreted by trunk 0.21.14 as an HTML file path. Fixed to `target = "index.html"` + `target_wasm_arch = "wasm32-unknown-unknown"`.
2. **Workspace isolation** — `src = ./crates/server-ui` didn't include workspace root `Cargo.toml`, breaking `cargo metadata`. Fixed to `src = builtins.path { path = ./.; }` with `cd crates/server-ui` in buildPhase.
3. **Cargo vendor deps missing** — trunk runs `cargo build` inside sandbox with no network. Added `cargoDeps = rustPlatform.importCargoLock { lockFile = ./Cargo.lock; }` + `cargoSetupHook`.
4. **Data URI favicon** — trunk 0.21.14 treats `data:image/svg+xml` hrefs as file paths. Fixed via `postPatch` sed to remove `data-trunk` from the favicon `<link>`.
5. **wasm-opt incompatibility** — binaryen 129 can't validate current Rust wasm output. Fixed via `postPatch` sed to set `data-wasm-opt="0"` (disables wasm-opt).
6. **Cargo target dir mismatch** — trunk (in `crates/server-ui/`) looked for artifacts in local `target/`, but cargo (workspace mode) puts them in workspace root `target/`. Fixed via `ln -s ../../target target` in buildPhase.
7. **Cargo.toml crate type** — server-ui was a plain lib crate; trunk needs `crate-type = ["cdylib"]` to produce `.wasm`. Added `[lib] crate-type = ["cdylib"]`.
8. **wasm-bindgen entry point** — added `#[wasm_bindgen(start)]` to `pub fn main()` in `src/lib.rs`.
9. **monitor365-server install path** — `cp -r ${monitor365-ui}/* $out/share/monitor365/ui/` failed because `ui/` dir didn't exist. Fixed `mkdir -p` to include `ui/`.

**Build verification:**
- `nix build .#monitor365-ui` — ✅ passes (with clean working tree)
- `nix build .#monitor365-server` — ✅ passes (with clean working tree)

**Note:** The fixes were committed in `054a46f3` (docs/readme + flake(nix) cleanup) via automated commit flow.

---

## 2. Current State

### SystemNix
| Check | Status |
|-------|--------|
| `just test-fast` | ✅ Passes |
| `nix eval` ecapture in system packages | ✅ Confirmed |
| `just switch` / `nh os boot` | ❌ Blocked by monitor365-server build failure |

### monitor365
| Check | Status |
|-------|--------|
| `nix build .#monitor365-ui` (clean tree) | ✅ Passes |
| `nix build .#monitor365-server` (clean tree) | ✅ Passes |
| `nix build .#monitor365-ui` (current tree) | ❌ Fails — Rust compile errors in `domain` crate |
| `nix build .#monitor365-server` (current tree) | ❌ Fails — cascades from UI failure |

**The monitor365 build failure is NOT from our nix fixes.** It comes from **uncommitted working tree changes** related to an in-progress "Audio & Microphone Monitoring" feature:
- Modified: `crates/domain/src/event_type/category.rs`, `enum.rs`, `events/mod.rs`, `lib.rs`
- Modified: `crates/collectors/common/src/lib.rs`, `linux/src/lib.rs`, `config/src/collector.rs`
- Untracked: `crates/collectors/common/src/mic_monitor.rs`, `linux/src/mic_monitor.rs`, `domain/src/events/audio.rs`

The `EventCategory` enum was extended with `Audio` variant in some files but the module `audio.rs` is untracked and `category.rs`/`enum.rs` modifications are incomplete — causing `error[E0583]: file not found for module audio` and `error[E0599]: variant Audio not found in EventCategory`.

---

## 3. What Works

1. **SystemNix syntax validation** — `just test-fast` passes.
2. **ecapture package inclusion** — Evaluates correctly, available in nixpkgs cache.
3. **monitor365 nix build (clean tree)** — Both `monitor365-ui` and `monitor365-server` build successfully when the working tree is clean (no uncommitted Rust changes).
4. **SystemNix commit & push** — Done. `578f00ea` is on origin/master.

---

## 4. What Needs Work

### Blocker: monitor365 Uncommitted Rust Changes
The `just switch` / `nh os boot` command on evo-x2 fails because it builds the entire system closure, which includes `monitor365-server` from the monitor365 flake input. The monitor365 working tree has uncommitted Rust changes that break compilation.

**Options to resolve:**

| Option | Effort | Impact |
|--------|--------|--------|
| A. Commit or revert the audio/mic monitoring changes in monitor365 | 5-30 min | Unblocks SystemNix `switch` immediately |
| B. Temporarily disable monitor365 in SystemNix `configuration.nix` | 2 min | Quick workaround, loses monitoring feature |
| C. Finish the audio/mic monitoring feature properly | 1-4 hours | Proper fix, but requires understanding the feature |

**Recommended:** Option A — decide whether to commit the partial audio feature or stash/revert it. The feature appears to be in-progress (untracked `audio.rs`, partial enum modifications). Either:
- `git add` all the files and commit as WIP, OR
- `git stash` / `git checkout --` to clean the tree

### Secondary: verify SystemNix full build
Once monitor365 is clean, run `nh os boot .` on evo-x2 to verify the ecapture addition doesn't introduce any new issues.

---

## 5. Execution Plan (Sorted by Impact vs Effort)

| # | Task | Effort | Impact | Owner |
|---|------|--------|--------|-------|
| 1 | **Decide fate of monitor365 audio/mic feature** — commit WIP or stash/revert | 5 min | 🔥 Critical — unblocks all SystemNix deploys | User |
| 2 | **Run `nh os boot .` on evo-x2** to verify full system closure | 15-30 min | High — confirms ecapture + monitor365 both work | User |
| 3 | **Verify ecapture runtime** — `ecapture --help` on evo-x2 after deploy | 2 min | Low — sanity check | User |
| 4 | **Document ecapture usage** in `docs/cybersecurity-tools-evo-x2.md` | 10 min | Medium — operational value | Optional |
| 5 | **Monitor365: complete audio/mic monitoring feature** | 1-4 hours | Medium — feature completion | Future session |
| 6 | **Re-enable wasm-opt** in monitor365 when binaryen catches up | 5 min | Low — performance optimization | Future |

---

## 6. Key Files Changed

### SystemNix (committed + pushed)
- `platforms/common/packages/base.nix` — Added `ecapture` to `linuxUtilities`
- `docs/cybersecurity-tools-evo-x2.md` — Documented ecapture availability

### monitor365 (committed in `054a46f3`)
- `flake.nix` — Complete rewrite of `monitor365-ui` derivation + `monitor365-server` install path fix
- `crates/server-ui/Trunk.toml` — Fixed `target`/`target_wasm_arch`
- `crates/server-ui/Cargo.toml` — Added `crate-type = ["cdylib"]`
- `crates/server-ui/src/lib.rs` — Added `#[wasm_bindgen(start)]` to `main()`

### monitor365 (uncommitted — causing build failure)
- `crates/domain/src/event_type/category.rs`
- `crates/domain/src/event_type/enum.rs`
- `crates/domain/src/events/mod.rs`
- `crates/domain/src/lib.rs`
- `crates/collectors/common/src/lib.rs`
- `crates/collectors/linux/src/lib.rs`
- `crates/config/src/collector.rs`
- `crates/collectors/common/src/mic_monitor.rs` (untracked)
- `crates/collectors/linux/src/mic_monitor.rs` (untracked)
- `crates/domain/src/events/audio.rs` (untracked)

---

## 7. Decision Needed

**The monitor365 working tree has uncommitted audio/mic monitoring changes that break compilation.** This blocks SystemNix system deploys (`nh os boot`).

**Question for you:** Should I:
- **(a)** Commit these as a WIP (work-in-progress) commit so the tree is clean and builds pass?
- **(b)** Stash/revert them so the tree is clean, preserving them for later?
- **(c)** Try to fix the compilation errors and complete the feature now?

Please advise — this is the only blocker remaining.
