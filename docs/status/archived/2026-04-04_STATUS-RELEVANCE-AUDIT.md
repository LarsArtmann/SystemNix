# Status Document Relevance Audit

**Date:** 2026-04-04
**Source:** `docs/status/2026-04-04_00-39_COMPREHENSIVE-PROJECT-STATUS.md`

---

## Summary

Of the 30+ items in the original status report, **7 were already fixed**, **14 were still broken**, and this audit **fixed 10 of those 14**.

## Already Fixed (No Longer Relevant)

| #   | Original Issue                            | Fixed By                                         |
| --- | ----------------------------------------- | ------------------------------------------------ |
| d.1 | Ollama `HSA_OVERRIDE_GFX_VERSION` missing | Set to `"11.5.1"` in ai-stack.nix:63             |
| b.1 | `HSA_ENABLE_SDMA=0` missing               | Set in ai-stack.nix:65                           |
| d.6 | Flake inputs use macOS-only paths         | Both use `github:` URLs now                      |
| d.4 | SigNoz fake vendor hashes                 | Real hashes in modules/nixos/services/signoz.nix |
| d.5 | `/data` partition not persisted           | Defined in hardware-configuration.nix:33         |
| e.7 | `pavucontrol` needs replacement           | Already replaced with `pwvucontrol`              |
| e.8 | `private-cloud/README.md` orphan          | Already removed                                  |

## Fixed By This Audit

| #    | Issue                                               | File Changed                                              |
| ---- | --------------------------------------------------- | --------------------------------------------------------- |
| d.3  | `WorkingDirectory` points to `/home/lars/Setup-Mac` | scheduled-tasks.nix:50 → `/home/lars/projects/SystemNix`  |
| e.12 | Plain `ollama` (CPU) in systemPackages              | ai-stack.nix — removed                                    |
| e.5  | `tesseract4` outdated                               | ai-stack.nix → `tesseract5`                               |
| e.1  | Duplicate `kitty` in packages AND programs          | home.nix — removed from home.packages                     |
| e.1  | Duplicate `nvtopPackages.amd` in 2 files            | monitoring.nix — removed (kept in amd-gpu.nix)            |
| e.1  | Duplicate `swaylock-effects` in 2 places            | multi-wm.nix — removed (kept via programs.swaylock)       |
| e.9  | Two notification daemons (mako + dunst)             | multi-wm.nix — removed mako (dunst via home-manager)      |
| e.2  | `wofi` unmaintained, installed twice                | multi-wm.nix — removed (rofi is the primary launcher)     |
| e.3  | GPU device mode `0666` world-rw                     | amd-gpu.nix → `0660` (render group only)                  |
| e.8  | Orphaned `pkgs/signoz/nixos-module.nix`             | Deleted (superseded by modules/nixos/services/signoz.nix) |
| e.8  | Orphaned `pkgs/dnsblockd-cert.nix`                  | Deleted (no references)                                   |

## Still Outstanding

| #  | Issue                                                                     | Priority | Effort |
| -- | ------------------------------------------------------------------------- | -------- | ------ |
| 1  | **bash.initExtra deprecated** (HM 26.05) — in shells.nix (both platforms) | LOW      | 30min  |
| 2  | **vm.overcommit_memory=1** not set for AI workloads                       | MEDIUM   | 15min  |
| 3  | **OMP_NUM_THREADS** not set for AI workloads                              | MEDIUM   | 15min  |
| 4  | **systemd.oomd** not configured for AI services                           | MEDIUM   | 2h     |
| 5  | **Duplicate xkb** in multi-wm.nix + display-manager.nix                   | LOW      | 5min   |
| 6  | **SigNoz module** — built but untested on hardware                        | LOW      | 3-4h   |
| 7  | **Unsloth Studio** — GPU detection untested on evo-x2                     | HIGH     | 2h     |
| 8  | **llama.cpp rocWMMA** — never benchmarked                                 | MEDIUM   | 4h     |
| 9  | **vLLM integration** — not started                                        | LOW      | 4-8h   |
| 10 | **Documentation cleanup** — 140+ status files                             | LOW      | 4h     |

## Items No Longer Applicable

| Item                           | Reason                                                                |
| ------------------------------ | --------------------------------------------------------------------- |
| c.8 "Ollama API serving"       | Ollama already exposes OpenAI-compatible API on port 11434 by default |
| d.2 "Unsloth GPU not detected" | LD_LIBRARY_PATH fix committed; needs deploy to verify                 |
| b.6 "/data not persisted"      | Fixed — mount in hardware-configuration.nix                           |

## Build Verification

`nix flake check --no-build` passes after all changes.
