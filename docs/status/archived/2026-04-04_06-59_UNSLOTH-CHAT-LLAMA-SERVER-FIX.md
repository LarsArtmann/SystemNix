# Status Report: Unsloth Chat Fix + AI Stack ROCm Hardening

**Date:** 2026-04-04 06:59
**Author:** Crush AI Agent
**Scope:** `platforms/nixos/desktop/ai-stack.nix`
**Machine:** evo-x2 (AMD Ryzen AI Max+ 395, gfx1151 / Strix Halo)

---

## Executive Summary

Unsloth Studio's chat feature failed because `llama-server` binary was not discoverable by the Studio backend. The root cause was a missing `llama-cpp-rocwmma` package in the `unsloth-studio` systemd service's PATH, compounded by a complete absence of ROCm GPU runtime environment variables. The fix involved three layers: binary discovery, GPU runtime configuration, and architectural deduplication.

---

## A) FULLY DONE

### 1. llama-server Binary Discovery Fix

**Problem:** Unsloth Studio's `_find_llama_server_binary()` (in `studio/backend/core/inference/llama_cpp.py`) searched 8 locations in priority order and failed at every one. The Nix-installed `llama-server` at `/run/current-system/sw/bin/llama-server` was visible to user shells but NOT to the `unsloth-studio` systemd service, which had a minimal PATH of only `git` and `python313`.

**Fix applied:**

- Added `llama-cpp-rocwmma` to `systemd.services.unsloth-studio.path` — enables `shutil.which("llama-server")` fallback (priority 7 in Unsloth's search)
- Set `LLAMA_SERVER_PATH = "${llama-cpp-rocwmma}/bin/llama-server"` env var — direct path bypass, highest priority (priority 1 in Unsloth's search)

**File:** `platforms/nixos/desktop/ai-stack.nix:216-222`

### 2. ROCm GPU Runtime Environment for Unsloth Studio

**Problem:** The `ollama` service had three critical ROCm environment variables (`HSA_OVERRIDE_GFX_VERSION=11.5.1`, `ROCBLAS_USE_HIPBLASLT=1`, `HSA_ENABLE_SDMA=0`) but `unsloth-studio` had **none of them**. Without these, `llama-server` built with ROCm support would either:

- Fail to detect the AMD Strix Halo GPU (gfx1151) → fall back to CPU
- Hit SDMA bugs on gfx11 APUs → crash or hang
- Miss HIPBLASLt optimizations → degraded performance

**Fix applied:**

- Injected shared `rocmEnv` attrset into `unsloth-studio.environment` via Nix attr merge (`rocmEnv // { ... }`)
- All three GPU vars now present in both `ollama` and `unsloth-studio` services

**File:** `platforms/nixos/desktop/ai-stack.nix:8-12, 217-218`

### 3. Missing ROCm Runtime Libraries

**Problem:** `LD_LIBRARY_PATH` in the unsloth-studio service was missing `rocm-runtime` and `rocm-comgr`, which are runtime dependencies of `llama-cpp-rocwmma` for JIT kernel compilation and ROCm device management.

**Fix applied:**

- Added `rocmPackages.rocm-runtime` and `rocmPackages.rocm-comgr` to shared `rocmRuntimeLibs` list
- Used `lib.makeLibraryPath rocmRuntimeLibs` in the service environment

**File:** `platforms/nixos/desktop/ai-stack.nix:14-23, 222`

### 4. Architectural Deduplication (rocmEnv + rocmRuntimeLibs)

**Problem:** ROCm env vars and library paths were duplicated between ollama config and unsloth-studio config. Adding them to unsloth-studio would have tripled the duplication (ollama + unsloth-studio + sessionVariables).

**Fix applied:**

- Extracted `rocmEnv` attrset: `{ ROCBLAS_USE_HIPBLASLT, HSA_OVERRIDE_GFX_VERSION, HSA_ENABLE_SDMA }`
- Extracted `rocmRuntimeLibs` list: 8 ROCm/C++ runtime library packages
- Both defined once in `let` bindings, consumed by `services.ollama.environmentVariables` and `systemd.services.unsloth-studio.environment`
- Ollama config simplified to `rocmEnv // { OLLAMA_FLASH_ATTENTION = "1"; ... }`

**File:** `platforms/nixos/desktop/ai-stack.nix:8-23`

### 5. Verification

All changes verified:

- `nix eval` confirms `HSA_OVERRIDE_GFX_VERSION = "11.5.1"` in unsloth-studio
- `nix eval` confirms `LLAMA_SERVER_PATH` points to correct ROCm binary
- `nix eval` confirms `rocm-runtime` and `rocm-comgr` in `LD_LIBRARY_PATH`
- `nix flake check --no-build` passes
- Pre-commit hooks pass for `ai-stack.nix` (deadnix, alejandra, gitleaks)

---

## B) PARTIALLY DONE

### 1. Session-Level ROCm Env Vars

**Status:** `environment.sessionVariables.ROCBLAS_USE_HIPBLASLT` is still set as a standalone string (line 264). It should ideally reference `rocmEnv` for single-source-of-truth, but `sessionVariables` is a top-level NixOS option and can't trivially merge with the `let` binding without restructuring. The other two vars (`HSA_OVERRIDE_GFX_VERSION`, `HSA_ENABLE_SDMA`) are NOT in session variables, which means interactive `llama-server` usage from a shell won't have them.

### 2. Pre-commit Hook Warnings (Pre-existing)

The pre-commit hook (`statix`) flagged warnings in **other files** that predate this session:

- `flake.nix:257` — repeated `nixpkgs` key (W20)
- `flake.nix:332` — repeated `nixpkgs` key (W20)
- `modules/nixos/services/signoz.nix:41` — assignment instead of inherit (W03)
- `modules/nixos/services/signoz.nix:82` — assignment instead of inherit from (W04)

These are **not caused by our changes** but block commits with `--verify`. They should be fixed separately.

---

## C) NOT STARTED

### 1. Runtime Verification on evo-x2

The config changes have NOT been deployed to the machine yet. Needs `sudo nixos-rebuild switch --flake .#evo-x2` and then testing Unsloth's chat feature.

### 2. Unsloth Chat End-to-End Test

After deploy, need to:

1. Open Unsloth Studio at http://127.0.0.1:8888
2. Load a GGUF model
3. Start a chat conversation
4. Verify `llama-server` spawns with ROCm GPU acceleration (check `rocm-smi` during inference)

### 3. Session Variables for Interactive llama-server

`HSA_OVERRIDE_GFX_VERSION` and `HSA_ENABLE_SDMA` should also be in `environment.sessionVariables` so that running `llama-server` manually from a shell also works with GPU acceleration.

---

## D) TOTALLY FUCKED UP

### Nothing catastrophically broken.

The original bug was straightforward — missing binary in service PATH + missing ROCm env vars. The fix is clean and well-structured. No data loss, no broken configs, no revert needed.

**One process concern:** In the first pass, I only fixed the binary discovery (PATH + LLAMA_SERVER_PATH) but completely missed the ROCm runtime environment. This is the kind of thing that would have resulted in a "still broken" after deploy — `llama-server` would have been found but run in CPU-only mode or crashed on the Strix Halo GPU.

---

## E) WHAT WE SHOULD IMPROVE

### 1. Pattern: Service Environment Parity Checklist

When a new systemd service needs GPU access, there should be a checklist:

- [ ] ROCm env vars (from `rocmEnv`)
- [ ] ROCm runtime libs in `LD_LIBRARY_PATH` (from `rocmRuntimeLibs`)
- [ ] Binary in `path`
- [ ] `SupplementaryGroups = ["render"]`
- [ ] `Group = "video"`

This should be documented in AGENTS.md or extracted into a NixOS module option.

### 2. Pattern: Extract ROCm Config into a Shared NixOS Module

`rocmEnv` and `rocmRuntimeLibs` are good `let` bindings, but a proper NixOS module with `options` would let any service opt-in with `services.myapp.rocm = true` and automatically get the right env vars, library paths, and groups. This is the idiomatic NixOS pattern.

### 3. Pattern: Pre-commit Hook Noise

The `statix` warnings in `flake.nix` and `signoz.nix` are pre-existing noise that reduce signal when reviewing pre-commit output. Should be fixed or suppressed per-file.

### 4. Pattern: Service Health Monitoring

Neither `ollama` nor `unsloth-studio` have health checks or monitoring. If `llama-server` crashes during inference, the only recovery is the `Restart=on-failure` policy. Should add `WatchdogSec` or a health check timer.

---

## F) Top 25 Things to Do Next

**Priority 1 — Immediate (fix the actual user problem):**

1. **Deploy to evo-x2** — `sudo nixos-rebuild switch --flake .#evo-x2` to apply all changes
2. **Test Unsloth chat** — Load a GGUF model, start chat, verify inference works
3. **Verify GPU usage during inference** — `rocm-smi` should show GPU activity when chatting

**Priority 2 — This Session's Loose Ends:**

4. **Add `HSA_OVERRIDE_GFX_VERSION` and `HSA_ENABLE_SDMA` to sessionVariables** — so manual `llama-server` from shell also gets GPU
5. **Fix statix warnings in `flake.nix`** — consolidate repeated `nixpkgs` keys
6. **Fix statix warnings in `signoz.nix`** — use `inherit` syntax

**Priority 3 — AI Stack Robustness:**

7. **Create a `rocm-gpu.nix` NixOS module** — shared module that any service can import for GPU access
8. **Add `WatchdogSec` to unsloth-studio** — auto-restart if backend becomes unresponsive
9. **Add health check endpoint** — Unsloth run.py already has a health endpoint, add systemd watchdog
10. **Test Ollama with ROCm after deploy** — verify ollama still works with shared `rocmEnv`
11. **Add `HSA_ENABLE_SDMA=0` to sessionVariables** — prevent interactive ROCm crashes

**Priority 4 — Monitoring & Observability:**

12. **Add netdata alert for GPU memory** — monitor VRAM usage during inference
13. **Add journald rate limiting for unsloth-studio** — prevent log spam on restart loops
14. **Create Grafana dashboard for AI stack** — ollama + unsloth + GPU metrics

**Priority 5 — Architecture:**

15. **Move `unsloth-setup` to use `pkgs.buildEnv` or `symlinkJoin`** — the inline pip install script is fragile
16. **Pin unsloth version** — `@ git+https://github.com/unslothai/unsloth` is a moving target
17. **Add `nix flake check` with actual build** — current `--no-build` misses runtime issues
18. **Create integration test for ai-stack** — `nixosTests` that verify ollama + unsloth service startup
19. **Extract tmpfiles.rules into shared function** — the `unslothDataDir` subtree rules are repetitive

**Priority 6 — Developer Experience:**

20. **Add `just unsloth-chat` command** — one command to open browser to studio
21. **Add `just ai-status` command** — show all AI services status + GPU utilization
22. **Document AI stack in AGENTS.md** — how to use, troubleshoot, and extend
23. **Add shell alias for `llama-server` with ROCm** — `llama-server-rocm` with env vars baked in

**Priority 7 — Security:**

24. **Review `User = "lars"` in unsloth services** — services running as user have full user perms
25. **Add `PrivateTmp=true` to unsloth services** — isolate temp directories

---

## G) Top #1 Question I Cannot Figure Out Myself

**Does the Unsloth Studio chat feature actually work end-to-end after these fixes?**

I can verify the Nix config evaluates correctly and that all env vars/binaries are in the right places. But I cannot:

1. Deploy the config to evo-x2 (requires `sudo nixos-rebuild switch`)
2. Open Unsloth Studio in a browser
3. Load a GGUF model and start a chat
4. Verify `llama-server` spawns with ROCm GPU acceleration

The user must perform these steps. If `llama-server` still fails after deploy, the next debug step is:

```bash
journalctl -u unsloth-studio -f
# Then trigger chat in the UI
```

---

## Commits Made This Session

| Commit    | Description                                                        |
| --------- | ------------------------------------------------------------------ |
| `5c2ea34` | Add shared `rocmEnv` and `rocmRuntimeLibs` let bindings            |
| `cf9a51a` | Restructure systemd services + inject ROCm env into unsloth-studio |

---

## Files Changed

| File                                   | Changes                                                                                                                                        |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `platforms/nixos/desktop/ai-stack.nix` | Added `rocmEnv`, `rocmRuntimeLibs`, `llama-cpp-rocwmma` in path, `LLAMA_SERVER_PATH`, ROCm env vars in unsloth-studio, deduplicated ollama env |

---

_Report generated by Crush AI Agent on 2026-04-04_
