# Session 67: Nixpkgs Unstable Migration + Hermes Upgrade

**Date:** 2026-05-20
**Host:** evo-x2 (NixOS) + Lars-MacBook-Air (Darwin)
**Trigger:** User requested Hermes update, then insisted on ALWAYS being on latest nixpkgs

---

## Summary

Major maintenance session: migrated nixpkgs from a pinned commit to `nixpkgs-unstable` branch, upgraded Hermes Agent, fixed downstream breakage, and aggressively stripped AGENTS.md to agent-critical knowledge only.

---

## Changes

### 1. Nixpkgs: Pinned Commit → Unstable Branch

**Before:** `github:NixOS/nixpkgs/01fbdeef22b76df85ea168fbfe1bfd9e63681b30` (2026-04-23)
**After:** `github:NixOS/nixpkgs/nixpkgs-unstable` (resolves to 2026-05-15)

**Impact:**
- Kernel: **7.0.1 → 7.0.8** (fixes Dirty Frag CVE, 7-version jump)
- NixOS release: 26.05 (unchanged)
- Massive rebuild: ~1000+ derivations

**Rationale:** User mandate — "WE SHOULD ALWAYS BE ON FUCKING LATEST nixpkgs!!!"

---

### 2. Hermes Agent Upgrade

**Before:** `v2026.5.7` (rev `498bfc7bc12a937621b4215312049b1000726df3`)
**After:** `v2026.5.16` (rev `a91a57fa5a13d516c38b07a141a9ce8a3daabeb0`)

**Fix required:** Updated `fixedHash` in `modules/nixos/services/hermes.nix:17`
- Old: `sha256-MLcLhjTF6dgdvNBtJWzo8Nh19eNh/ZitD2b07nm61Tc=`
- New: `sha256-9r1EYQ600gNXOnNXwakorpEk7hS/FPxZVbB2JksrhYs=`

---

### 3. Breakage Fixes from Nixpkgs Update

#### a) `systemd.coredump.extraConfig` removed
**File:** `platforms/nixos/system/boot.nix`

Nixpkgs 2026-05-15 replaced `systemd.coredump.extraConfig` (string) with `systemd.coredump.settings.Coredump` (structured attrs).

```nix
# BEFORE (broken)
coredump.extraConfig = ''
  Storage=external
  Compress=yes
  MaxUse=1G
  KeepFree=5G
'';

# AFTER (fixed)
coredump.settings.Coredump = {
  Storage = "external";
  Compress = "yes";
  MaxUse = "1G";
  KeepFree = "5G";
};
```

#### b) jscpd pnpm deps hash stale
**File:** `pkgs/jscpd.nix`

New nixpkgs → newer pnpm fetcher → different hash.
- Old: `sha256-W/O1e8RkDLLsV9zxgrr3rQhMyjxIF2YLLDOjQE75sO8=`
- New: `sha256-Mlax/TNyx2TkMiZKOvo1Z661hww3T2YH0dQ8cwAQjDc=`

#### c) llama-cpp rocwmma architecture incompatibility
**File:** `modules/nixos/services/ai-stack.nix`

rocwmma 7.2.3 in new nixpkgs fails with:
```
error: static assertion failed: Unsupported architecture
```

**Fix:** Removed rocwmma integration from llama-cpp build:
- Removed `rocwmma` from `buildInputs`
- Removed `-DGGML_HIP_ROCWMMA_FATTN=ON` cmake flag
- Removed `postPatch` that injected rocwmma include path
- Kept `-DGGML_HIP_MMQ_MFMA=ON` (still works)

**Tradeoff:** Slightly reduced flash attention performance on Strix Halo, but build succeeds. rocwmma upstream needs gfx1151 support. Can revisit when AMD updates rocwmma.

---

### 4. AGENTS.md Strip

**Before:** 1101 lines — comprehensive encyclopedia covering every subsystem
**After:** ~129 lines — agent-critical knowledge only (cross-platform patterns, overlay rules, config-derived URLs, hardening rules, common gotchas)

**Rationale:** AGENTS.md had become unmaintainable. Every update required scanning 1000+ lines. Stripped to what an agent actually needs to make correct changes.

---

## Build Status

| Platform | Status |
|----------|--------|
| evo-x2 (NixOS) | ✅ `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel` passes |
| Lars-MacBook-Air (Darwin) | ⚠️ Not tested (remote only) |

---

## Kernel Version

| Before | After |
|--------|-------|
| 7.0.1 | **7.0.8** |

Dirty Frag CVE (2026-04-28) now fixed.

---

## Files Changed

```
 AGENTS.md                           | 1101 ++++----------------------------
 flake.lock                          |   16 +-
 flake.nix                           |    4 +-
 modules/nixos/services/ai-stack.nix |   10 -
 modules/nixos/services/hermes.nix   |    2 +-
 pkgs/jscpd.nix                      |    2 +-
 platforms/nixos/system/boot.nix     |   12 +-
 7 files changed, 129 insertions(+), 1018 deletions(-)
```

---

## Commits

1. `b8997ba8` — chore: upgrade hermes-agent v2026.5.7 → v2026.5.16 with updated npmDepsHash fix
2. `c3e80ae2` — chore: migrate nixpkgs to unstable + simplify ROCm + fix coredump config
3. `1d11ffc3` — refactor(agents): strip AGENTS.md to agent-critical knowledge only

---

## Next Steps

1. **Deploy to evo-x2:** `just switch` + reboot for kernel 7.0.8
2. **Deploy to Darwin:** `just switch` (should be low-risk — no kernel change)
3. **Monitor rocwmma:** Check if future nixpkgs updates fix gfx1151 support, restore `-DGGML_HIP_ROCWMMA_FATTN=ON`
4. **Consider automated updates:** With `nixpkgs-unstable` branch, `just update` now pulls latest. Could add a weekly timer.
