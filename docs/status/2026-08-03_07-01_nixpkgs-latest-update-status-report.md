# Status Report: nixpkgs Latest Update — 2026-08-03 07:01

## Context

User demanded: "You know I like to have ALL my software on the fucking latest version!" — nixpkgs was pinned to Jan 2026 (7 months stale), Pocket ID pinned to 2.10.0 via overlay. Full update needed across the board.

---

## a) FULLY DONE

| # | Task | Detail |
|---|------|--------|
| 1 | **Disk space freed (user GC)** | `nix-collect-garbage -d` freed 5.2 GiB (4431 paths). Then post-build disk dropped to 63% (264G free) — massive improvement |
| 2 | **Removed pocketIdUpgradeOverlay** | `overlays/linux.nix` — removed 34-line overlay that pinned pocket-id to v2.10.0. Now uses nixpkgs default (2.12.0) |
| 3 | **Updated nixpkgs to Aug 1, 2026** | Rev `148bab9c1c3c53136ecb44a6ea356a0ed5b39b06` (was `3497aa5` from Jan 8, 2026). Required manual `jq` edit of flake.lock because the lock entry was a tarball (`channels.nixos.org`) not a GitHub flake — `nix flake update` silently re-resolved the stale tarball |
| 4 | **Updated ALL other flake inputs** | All LarsArtmann repos + community tools updated to latest via `nix flake update` |
| 5 | **Fixed monitor365 segment-buffer cargo hash (crane path)** | Pushed upstream: added `outputHashes` for git dependency `segment-buffer-0.6.0` to crane's `commonArgs` |
| 6 | **Fixed monitor365 segment-buffer cargo hash (importCargoLock path)** | Pushed upstream: `monitor365-ui` uses `rustPlatform.importCargoLock` (NOT crane) — also needed `outputHashes` added |
| 7 | **Fixed monitor365 vendor-patches Cargo.toml** | Cargo 1.95.0 (in new nixpkgs) is stricter: `[lints] workspace = true` in standalone vendored crates (`libspa-sys`, `pipewire-sys`) causes `workspace.lints was not defined` error. Removed the section from both |
| 8 | **monitor365 builds successfully** | Package builds clean after all 3 upstream fixes |
| 9 | **Eval passes** | `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` succeeds — no module errors from 7-month nixpkgs jump |
| 10 | **Pocket ID now 2.12.0** | Upgraded from 2.10.0 → 2.12.0 (fixes the francis actor framework crash-loop that caused the original auth.home.lan outage) |

---

## b) PARTIALLY DONE

| # | Task | What's done | What remains |
|---|------|-------------|--------------|
| 1 | **Full system build** | Most derivations build. monitor365, emeet-pixyd, Go tools all build. | `crush-daily` go-modules vendorHash mismatch: `sha256-rPlixV...` → `sha256-HhlLe+...`. Need to update vendorHash in upstream crush-daily flake. |
| 2 | **Pre-deploy checks** | Not reached — build not complete | Run after build succeeds |
| 3 | **Deploy** | Not reached | Run after build + pre-deploy pass |
| 4 | **Post-deploy verification** | Not reached | Run after deploy |
| 5 | **Pocket ID 2.12.0 runtime verification** | Package version confirmed via eval | Need post-deploy health check + journalctl for francis crash absence |

---

## c) NOT STARTED

| # | Task |
|---|------|
| 1 | Fix crush-daily vendorHash mismatch |
| 2 | Continue fixing any remaining build errors |
| 3 | Run `nix run .#pre-deploy-check` |
| 4 | Run `nix run .#deploy` |
| 5 | Run `nix run .#post-deploy-check` (must be 30/30) |
| 6 | Verify Pocket ID auth.home.lan responds, no francis panics in journalctl |
| 7 | Post-build garbage collection |
| 8 | Update AGENTS.md with: new nixpkgs version, removed pocket-id overlay, new gotchas (tarball lock, Cargo 1.95 lints, segment-buffer outputHashes) |
| 9 | Remove the WAL-clearing band-aid from pocket-id.nix if 2.12.0 no longer needs it |
| 10 | Verify all 30+ services work with new nixpkgs versions |
| 11 | Post-reboot verification (the fix is untested after cold boot) |

---

## d) TOTALLY FUCKED UP / MISTAKES

| # | Mistake | Impact | Lesson |
|---|---------|--------|--------|
| 1 | **Didn't read the flake.lock carefully before running `nix flake update`** | The nixpkgs lock entry was a **tarball** (`https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz`), not a GitHub entry. `nix flake update` silently re-resolved the stale tarball. Ran `nix flake update nixpkgs` 4+ times before noticing the lock wasn't changing. Wasted ~10 min. | **Always `jq '.nodes.nixpkgs'` the lock file BEFORE trying to update.** If `original.type` is `"tarball"`, manual surgery is required. |
| 2 | **Wrong crane API for segment-buffer hash** | First tried `cargoLock = { lockFile; outputHashes; }` nested in commonArgs. Crane's `mkCargoDerivation` can't coerce an attrset to string. Then tried `cargoVendorDir = craneLib.vendorCargoDeps { cargoLock = { ... }; }` — same error. Finally learned the correct API: `outputHashes` is a top-level key in commonArgs, and the key format is the full git source URL (not the package name). Wasted ~3 build cycles. | **Read the library's API docs BEFORE guessing.** Used `agentic_fetch` to read crane source — should have done that FIRST. |
| 3 | **Missed that monitor365 has TWO separate cargo build paths** | Fixed crane's `commonArgs.outputHashes` but the `monitor365-ui` derivation uses `rustPlatform.importCargoLock` (completely different vendoring mechanism). The eval error was coming from the UI path, not the CLI path. Had to trace the error with `--show-trace` to find it. | **When a project has multiple build systems (crane + nixpkgs rustPlatform), BOTH need the same git-dep hashes.** Always `grep -r 'importCargoLock\|outputHashes\|cargoLock'` the entire upstream flake. |
| 4 | **Cargo fmt pre-push hook rejection** | Pushed to monitor365 without running `cargo fmt --check`. Pre-push hook rejected. Had to `nix develop -c cargo fmt --all`, amend, re-push. | **Always run formatter before pushing to repos with pre-push hooks.** |
| 5 | **Didn't check for MORE build errors before the full system build** | Ran the full system build after only verifying eval. The eval doesn't catch vendorHash mismatches (fixed-output derivations evaluate but fail at build time). The crush-daily vendorHash failure was predictable. | **For a 7-month nixpkgs jump, expect 5-10 vendorHash breaks. Build individual Go packages first (`nix build .#crush-daily` etc.) before attempting the full system build.** |

---

## e) WHAT WE SHOULD IMPROVE

| # | Improvement | Why |
|---|-------------|-----|
| 1 | **Automate `nix flake update` validation** | The tarball lock entry silently defeated updates. A pre-commit check that `original.type == "github"` for nixpkgs would catch this. |
| 2 | **Build a "vendorHash update" script** | When nixpkgs jumps, every `buildGoModule` / `buildRustPackage` vendorHash may break. A script that sets `vendorHash = ""`, builds, extracts `got:` hash, and patches would save 30+ min of manual work per package. |
| 3 | **CI matrix for nixpkgs updates** | A GitHub Actions workflow that tries building against latest nixos-unstable weekly would catch drift before it becomes a 7-month cliff. |
| 4 | **Don't overlay-pin packages to specific versions** | The pocketIdUpgradeOverlay was a workaround for a bug that was fixed upstream months ago. Overlay version pins should have expiry comments or be re-evaluated regularly. |
| 5 | **The Pocket ID WAL-clearing band-aid may be unnecessary now** | Pocket ID 2.12.0 includes francis v0.1.0-beta.17+ which fixes the crash-loop. The WAL clearing + ACTORS_HOST + MemoryMax overrides in `pocket-id.nix` should be re-evaluated — they may be dead code now. |
| 6 | **Read more carefully before acting** | Multiple wasted cycles from not reading the lock file format, not checking the crane API docs, and not scanning for all cargo build paths. The "READ → UNDERSTAND → RESEARCH → REFLECT" loop was followed but not deeply enough on the first pass. |
| 7 | **Segment-buffer should be published to crates.io** | The entire outputHashes problem exists because segment-buffer is a private git dep. Publishing it would eliminate the cargoLock complexity for both crane and importCargoLock paths. |

---

## f) NEXT THINGS TO DO (up to 50)

### Immediate (blocking deploy)

| # | Task | Est. time |
|---|------|-----------|
| 1 | Fix crush-daily vendorHash: `nix eval` the flake, set `vendorHash = ""`, build, paste `got:` hash | 10 min |
| 2 | Check for other Go vendorHash breaks: `nix build .#discordsync`, `.#overview`, `.#projects-management-automation`, `.#file-and-image-renamer` | 10 min |
| 3 | Check SigNoz packages: `nix build .#signoz`, `.#signoz-otel-collector`, `.#signoz-schema-migrator` (use `go_1_25`, may need `go_1_26` now) | 10 min |
| 4 | Re-run full system build | 5-10 min |
| 5 | Run `nix run .#pre-deploy-check` | 2 min |
| 6 | Run `nix run .#deploy` | 5-10 min |
| 7 | Run `nix run .#post-deploy-check` | 2 min |
| 8 | Verify `auth.home.lan` responds with 200 | 1 min |
| 9 | Check `journalctl -u pocket-id.service` for francis panics | 1 min |

### Post-deploy verification

| # | Task | Est. time |
|---|------|-----------|
| 10 | Verify all Gatus endpoints pass (30+ checks) | 2 min |
| 11 | Verify nixpkgs version: `nixos-version` should show `26.11.20260801.148bab9` | 1 min |
| 12 | Check `journalctl -u pocket-id.service` for SQLITE_BUSY errors — 2.12.0 may have fixed the alarm-loop contention | 2 min |
| 13 | Check DMS/Quickshell for Qt 6.x compatibility crashes | 2 min |
| 14 | Check Docker 29.x compatibility (nixpkgs may have updated Docker) | 2 min |
| 15 | Check Caddy v2 config compatibility (any breaking changes in nixpkgs Caddy module?) | 2 min |
| 16 | Check Homepage dashboard renders (Next.js version may have changed) | 2 min |
| 17 | Check Immich (nixpkgs may have bumped Immich version) | 2 min |
| 18 | Check SigNoz (custom-built from source — may need Go version update) | 5 min |
| 19 | Check SearXNG (settings schema may have changed) | 2 min |
| 20 | Check SearXNG `redis` → `valkey` migration (already done but verify with new nixpkgs) | 2 min |

### Cleanup

| # | Task | Est. time |
|---|------|-----------|
| 21 | Remove Pocket ID WAL-clearing band-aid if 2.12.0 doesn't need it | 5 min |
| 22 | Remove `ACTORS_HOST = "127.0.0.1"` if 2.12.0 fixes the QUIC binding | 5 min |
| 23 | Revert `MemoryMax` to 512M if francis memory usage is fixed | 2 min |
| 24 | Run `nix-collect-garbage -d` post-deploy to reclaim old nixpkgs closure | 5 min |
| 25 | Clean up systemd-coredump entries from pocket-id panics | 2 min |
| 26 | Update AGENTS.md with: new nixpkgs version, removed overlay, new gotchas | 10 min |
| 27 | Update the Pocket ID gotcha in AGENTS.md to note 2.12.0 fixes the crash | 2 min |
| 28 | Commit all changes to SystemNix | 2 min |

### Improvements

| # | Task | Est. time |
|---|------|-----------|
| 29 | Add a `nix flake update --check` script that validates lock entries are GitHub type | 15 min |
| 30 | Add CI job for weekly nixpkgs-unstable build check | 30 min |
| 31 | Publish segment-buffer to crates.io to eliminate outputHashes complexity | 30 min |
| 32 | Add vendorHash update helper script | 30 min |
| 33 | Audit all overlay version pins for staleness | 15 min |
| 34 | Check if `python313Packages` → `python314Packages` migration is needed (new nixpkgs may default to 3.14) | 10 min |
| 35 | Check if `go_1_25` → `go_1_26` is needed for SigNoz packages | 5 min |
| 36 | Verify `catppuccin-gtk` overlay still needed (Python 3.14 fix may be upstream now) | 10 min |
| 37 | Verify `aiocache` / `valkey` / `timm` / `xformers` test-disabling overlays still needed | 10 min |
| 38 | Check if Docker 29.x `userland-proxy-path` gotcha is still relevant in new nixpkgs | 5 min |
| 39 | Check if `homepage-dashboard` `enableLocalIcons` default changed | 5 min |
| 40 | Verify Niri flake compatibility with new nixpkgs | 5 min |

### Long-term

| # | Task | Est. time |
|---|------|-----------|
| 41 | Set up Attic binary cache for the new nixpkgs closure | 30 min |
| 42 | Consider switching to `nixos-small` channel for faster updates (if binary cache coverage is good) | 15 min research |
| 43 | Post-reboot verification of Pocket ID (cold boot test) | 10 min |
| 44 | Review all 90+ gotchas in AGENTS.md for relevance with new nixpkgs | 30 min |
| 45 | Check if `systemd` version changed significantly (may affect service hardening) | 10 min |
| 46 | Check kernel version (may need new boot params, module loading changes) | 5 min |
| 47 | Verify BTRFS module compatibility (scrub, balance, qgroups behavior) | 10 min |
| 48 | Check AMD GPU driver / ROCm compatibility with new kernel/Mesa | 15 min |
| 49 | Run `nix flake check --no-build` on Darwin config too (aarch64-darwin) | 5 min |
| 50 | Schedule next nixpkgs update for <1 month out (prevent 7-month drift cliff) | 2 min |

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **The pre-existing failed units** (`disk-growth-check.service`, `nix-gc.service`, `nix-build-cleanup.service`) were failing before this session. Root FS is now at 63% (was 91%) — the build freed significant space. Should I investigate why `nix-gc` was failing, or is the disk space improvement sufficient to consider it resolved? The auto-git daemon and background builds may have resolved the underlying ENOSPC condition, but I cannot verify `systemctl status nix-gc` (systemctl is blocked in this environment).

2. **There's an NVMe data corruption discovery report** (`docs/status/2026-08-03_06-51_nvme-data-corruption-discovery.md`) that was modified in this session by another process (209 insertions, 49 deletions). I did not create or modify this file. Should I investigate what it contains, or is this from a parallel session/process that I should leave alone?

3. **The monitor365 upstream repo had uncommitted local changes** beyond what I pushed (the `cargo fmt` produced `crates/collectors/common/src/audio_levels.rs` — a refactoring I did not author). My commit `7cf8162c1` includes changes from a parallel process. Should I be concerned about this, or is the auto-formatter/refactoring expected behavior in the monitor365 dev workflow?

---

## Technical Details

### nixpkgs tarball lock issue (root cause)

The flake.lock `nixpkgs.original` was:
```json
{"type": "tarball", "url": "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz"}
```

Even though `flake.nix` declares `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`, the nix registry has:
```
global flake:nixpkgs/nixos-unstable https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz
```

Nix resolved the GitHub URL through the registry, which rewrote it to a tarball. The tarball URL on `channels.nixos.org` was stale (pointing to Jan 2026). `nix flake update` re-fetched the same stale tarball. Fix: manually `jq` the lock to use `type: "github"` and set the correct rev/narHash.

### Build errors encountered and fixed

| Error | Package | Fix | Status |
|-------|---------|-----|--------|
| `segment-buffer-0.6.0` missing cargo hash (crane path) | monitor365 CLI | Added `outputHashes` to commonArgs with full git source URL as key | FIXED (upstream `c86673ab`) |
| `segment-buffer-0.6.0` missing cargo hash (importCargoLock path) | monitor365 UI | Added `outputHashes` to `rustPlatform.importCargoLock` with package-version key | FIXED (upstream `cd0e10966`) |
| `workspace.lints was not defined` | monitor365 vendor-patches | Removed `[lints] workspace = true` from libspa-sys + pipewire-sys Cargo.toml | FIXED (upstream `7cf8162c1`) |
| vendorHash mismatch: `sha256-rPlixV...` → `sha256-HhlLe+...` | crush-daily | Not yet fixed | BLOCKING |

### Files modified in SystemNix (all auto-committed by git daemon)

| File | Change |
|------|--------|
| `overlays/linux.nix` | Removed `pocketIdUpgradeOverlay` (34 lines) |
| `flake.lock` | nixpkgs → Aug 2026, all inputs updated, monitor365 → `7cf8162c1` |
| `modules/nixos/services/pocket-id.nix` | (From previous session) WAL clearing + ACTORS_HOST + MemoryMax |

### Files modified in monitor365 (pushed to GitHub)

| Commit | Change |
|--------|--------|
| `c86673ab` | Added `outputHashes` for segment-buffer in crane commonArgs |
| `cd0e10966` | Added `outputHashes` for segment-buffer in importCargoLock (monitor365-ui) |
| `7cf8162c1` | Removed `[lints] workspace = true` from vendor-patches Cargo.toml files |

---

_Generated: 2026-08-03 07:01 CEST_
