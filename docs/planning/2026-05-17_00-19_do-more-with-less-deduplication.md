# SystemNix: Do More With Less — Deduplication & Simplification Plan

**Date:** 2026-05-17
**Scope:** Eliminate dead code, fix bugs, consolidate duplications, reduce flake.nix from 620→~500 lines
**Principle:** Every abstraction in this project exists (`lib/`, `overlays/`, `platforms/common/`) — we just aren't using them consistently.

---

## Pareto Analysis

| Tier | Tasks | Impact |
|------|-------|--------|
| **1% → 51%** | 6 quick-win tasks (~45 min total) | Fix bugs, kill dead code, remove split brains |
| **4% → 64%** | 7 deduplication tasks (~70 min total) | Merge duplications, consolidate abstractions |
| **20% → 80%** | 10 structural tasks (~100 min total) | Extract misplaced code, reduce flake.nix size |
| **80% → 100%** | 6 polish tasks (~50 min total) | Nice-to-haves, consistency, future-proofing |

**Total:** 29 tasks | ~265 min (~4.5 hours) | ~111 Nix files, 620-line flake.nix

---

## Tier 1: 1% → 51% Impact (Quick Wins — Bugs & Dead Code)

| # | Task | File(s) | What | Impact | Effort | Time |
|---|------|---------|------|--------|--------|------|
| T1.1 | Fix broken `dns-update.sh` path | `scripts/dns-update.sh:4` | Change `platforms/shared/` → `platforms/common/` | **BUG FIX** — script is completely broken | 1 line | 2 min |
| T1.2 | Remove dead `allowUnfreePredicate` | `platforms/common/nix-settings.nix:68-85` | Delete the 17-line allowlist — `allowUnfree = true` in flake.nix overrides it everywhere. Remove entire `nixpkgs.config` block. | Eliminates false confidence + 17 lines dead code | 17 lines | 3 min |
| T1.3 | Remove duplicate `nix.gc` from networking.nix | `platforms/nixos/system/networking.nix:81-85` | Delete the `nix.gc` block — already defined in `nix-settings.nix` (shared across platforms) AND `modules/nixos/services/default.nix`. Keep only the one in `nix-settings.nix`. | Fixes triple-defined GC config | 5 lines | 4 min |
| T1.4 | Remove duplicate `nix.gc` from services/default.nix | `modules/nixos/services/default.nix:28-32` | Same as T1.3 — the canonical location is `nix-settings.nix` (shared). Delete from here too. | Completes GC dedup | 5 lines | 3 min |
| T1.5 | Remove 28 lines of dead commented code | `modules/nixos/services/security-hardening.nix:27-53,72,110` | Delete commented-out `auditd` config, `audit.rules`, `journald.audit`, `auditd` group. Track upstream bug via ADR or comment, not 28 lines of dead Nix. | Removes code smell | 28 lines | 4 min |
| T1.6 | Remove offensive security tools | `modules/nixos/services/security-hardening.nix:130,131,148,153-156,159` | Remove `aircrack-ng`, `netscanner`, `masscan`, `sqlmap`, `nikto`, `nuclei`, `sleuthkit`, `tor-browser` from system packages. Keep only defensive tools (nmap, wireshark, lynis, aide, etc.). | Removes 8 attack tools from daily-driver desktop | 8 lines | 4 min |

---

## Tier 2: 4% → 64% Impact (Deduplication & Consolidation)

| # | Task | File(s) | What | Impact | Effort | Time |
|---|------|---------|------|--------|--------|------|
| T2.1 | Fix double overlay imports | `overlays/default.nix:2,3,18,19` | Use already-imported `shared` and `linux` attrs instead of re-importing: `sharedOverlays = [nur.overlays.default] ++ shared; linuxOnlyOverlays = linux;` | Eliminates double evaluation | 2 lines | 3 min |
| T2.2 | Merge `hardenUser` into `harden` with mode param | `lib/systemd.nix`, `lib/user-harden.nix`, `lib/default.nix` | Add `mode ? "system"` param to `harden`. System-only fields gated by `mode == "system"`. Delete `user-harden.nix`. Update `lib/default.nix` to export `hardenUser = args: harden (args // { mode = "user"; });`. Update all 3 callers. | Eliminates 1 file, 5 lines duplicated helpers, 7 duplicated keys | ~30 lines | 10 min |
| T2.3 | Extract `colorScheme`/`colorSchemeLib` to shared module | NEW: `platforms/common/color-scheme.nix`, EDIT: `platforms/darwin/default.nix`, `platforms/nixos/system/configuration.nix` | Create shared module with `colorScheme` + `colorSchemeLib` options. Both platforms import it. Remove duplicate option declarations from both configs. Also remove `colorScheme` from `flake.nix:266` `sharedHomeManagerSpecialArgs`. | Eliminates copy-pasted options across 2 platforms | ~20 lines | 10 min |
| T2.4 | Move misplaced Firefox UI policies out of dns-blocker | `modules/nixos/services/dns-blocker.nix:222-250` | Move 5 browser UI policies (`shell.checkDefaultBrowser`, `disable-swipe-tracker`, swipe gestures, autofocus) to `chromium-policies.nix` (rename to `browser-policies.nix`) or a new `firefox-policies.nix`. Keep only DNS-over-HTTPS + CA cert policies in dns-blocker. | Separation of concerns | ~30 lines | 8 min |
| T2.5 | Fix `internet-diagnostic.sh` to source `lib.sh` | `scripts/internet-diagnostic.sh:5-13` | Replace reimplemented `ok/fail/warn/info` functions with `source "$(dirname "$0")/lib.sh"`. Remove 9 lines of duplicated color vars + functions. | Eliminates script function duplication | 9 lines | 3 min |
| T2.6 | Fix `route-health-monitor.sh` shebang placement | `scripts/route-health-monitor.sh:1-17` | Move `set -euo pipefail` to line 2 (after shebang), move 15-line comment block below it. Matches project convention. | Consistency | 2 lines moved | 2 min |
| T2.7 | Remove duplicate `colorSchemeLib` assignment | `platforms/darwin/default.nix:52-53`, `platforms/nixos/system/configuration.nix:47` | Both files set `config.colorSchemeLib = nix-colors.lib;` which duplicates the default in the option declaration. Remove these after T2.3 creates the shared module. | Removes redundant config assignments | 2 lines | 2 min |

---

## Tier 3: 20% → 80% Impact (Structural Improvements)

| # | Task | File(s) | What | Impact | Effort | Time |
|---|------|---------|------|--------|--------|------|
| T3.1 | Deduplicate 34-entry module list in flake.nix | `flake.nix:273-310, 537-573` | Define `serviceModulePaths` list once in the top-level `let`. Use it in both `imports` (flake-parts) and `modules` (nixosConfigurations). External modules (niri, sops, etc.) stay inline. | **Eliminates 34 lines + sync headache forever** | ~40 lines | 12 min |
| T3.2 | Extract gitea mirror scripts to `scripts/` | `modules/nixos/services/gitea.nix:16-229` | Extract 3 large shell scripts (`gitea-mirror-github`, `gitea-mirror-starred`, `gitea-setup`) to `scripts/gitea-mirror-github.sh`, etc. Reference via `pkgs.writeShellApplication` or `builtins.readFile` like `niri-config.nix` does. | Reduces gitea.nix by ~200 lines (from 555→~350) | ~200 lines | 12 min |
| T3.3 | Extract gitea token/runner scripts to `scripts/` | `modules/nixos/services/gitea.nix:341-513` | Extract remaining 3 shell scripts (`gitea-admin-setup`, `gitea-token-gen`, `gitea-runner-token-gen`) to `scripts/`. Same pattern as T3.2. | Reduces gitea.nix by another ~100 lines (to ~250) | ~100 lines | 12 min |
| T3.4 | Move `d2DarwinOverlay` out of shared.nix | `overlays/shared.nix:63-69,85` | Move to a new `overlays/darwin.nix` or inline in the darwin config in `flake.nix`. A Darwin-only overlay should not be in the shared file evaluated for all platforms. | Correct abstraction placement | ~10 lines | 5 min |
| T3.5 | Make `mkPackageOverlay` available to linux.nix | `overlays/shared.nix:15-17`, `overlays/linux.nix:12-14` | Move `mkPackageOverlay` to `overlays/default.nix` so both `shared.nix` and `linux.nix` can use it. Then convert `dnsblockdOverlay` in linux.nix to use it. | Consistency — same pattern everywhere | ~10 lines | 5 min |
| T3.6 | Replace hardcoded `/home/lars` in comfyui.nix | `modules/nixos/services/comfyui.nix:30,36` | Replace `/home/lars/projects/anime-comic-pipeline/` with module options (`services.comfyui.pipelineDir` or use `config.users.users.${primaryUser}.home`). | Removes hardcoded user paths from modules | ~10 lines | 8 min |
| T3.7 | Replace hardcoded `/home/lars` in hermes.nix | `modules/nixos/services/hermes.nix:42` | Replace `/home/lars/.hermes` migration path with `config.users.users.${cfg.user}.home` derivation. Already has `cfg.stateDir` for the main path. | Removes last hardcoded home path | ~5 lines | 5 min |
| T3.8 | Consolidate overlay composition in flake.nix | `flake.nix:324-327,441,502-508,591-593` | Create helper functions: `mkOverlays { linux ? false, niri ? false }` that compose the overlay list. Reduces 4 scattered compositions to 1 shared helper. | Reduces flake.nix boilerplate | ~20 lines | 10 min |
| T3.9 | Merge `monitoring.nix` into base packages | `modules/nixos/services/monitoring.nix` | This 35-line module installs 5 packages and has ghost comments about things "moved elsewhere". Merge its packages into `platforms/common/packages/base.nix` or `platforms/nixos/` packages. Delete the module and remove from flake.nix imports. | Eliminates 1 unnecessary module + flake.nix entry | ~35 lines | 8 min |
| T3.10 | Add `just validate-scripts` CI for path references | `scripts/dns-update.sh` (and others) | Add a simple test that verifies all file paths referenced in scripts actually exist. Prevents future `shared/` → `common/` style regressions. | Prevents broken scripts silently | ~15 lines | 8 min |

---

## Tier 4: 80% → 100% Impact (Polish & Future-Proofing)

| # | Task | File(s) | What | Impact | Effort | Time |
|---|------|---------|------|--------|--------|------|
| T4.1 | Rename `chromium-policies.nix` → `browser-policies.nix` | `modules/nixos/services/chromium-policies.nix` | After T2.4 moves Firefox policies here, rename to reflect that it handles both browsers. Update flake.nix module name. | Accurate naming | ~10 lines | 5 min |
| T4.2 | Remove `tor-browser` and `openvpn` from system packages | `modules/nixos/services/security-hardening.nix:148-149` | `tor-browser` is a 500MB package for anonymous browsing — not a "hardening" tool. `openvpn` is unused (system uses WireGuard). Remove both. | Saves disk space + removes unnecessary packages | 2 lines | 2 min |
| T4.3 | Extract shell script hardcoded IPs to env vars | `scripts/route-health-monitor.sh:19`, `scripts/mptcp-endpoint-manager.sh:13`, `scripts/internet-diagnostic.sh:123-128` | Replace hardcoded `192.168.1.x` with `${GATEWAY:-192.168.1.1}` / `${LAN_IP:-192.168.1.150}` fallbacks. Scripts get injected env from Nix config. | Scripts respect network config changes | ~15 lines | 8 min |
| T4.4 | Add `apparmor.enable = lib.mkDefault false` with TODO comment | `modules/nixos/services/security-hardening.nix:56` | Replace bare `apparmor.enable = false` with `lib.mkDefault false` + a comment explaining the path to enable. | Clear path forward for AppArmor | 1 line | 2 min |
| T4.5 | Verify `disableTests` overlay is applied consistently | `flake.nix:324-327 vs 502-508` | `disableTests` is in perSystem but not in nixosConfigurations. Verify if this is intentional (perSystem uses it for devShell checks) or a bug. Document decision. | Correctness verification | 0 lines (just verify) | 5 min |
| T4.6 | Update AGENTS.md with all changes made | `AGENTS.md` | Remove references to deleted patterns (triple GC, allowUnfreePredicate, user-harden.nix). Update overlay section. Document new patterns (shared module list, merged harden). | Keeps documentation honest | ~20 lines | 8 min |

---

## Execution Order (sorted by impact/effort ratio)

### Phase 1: Quick Wins (45 min) — DO FIRST
```
T1.1 → T1.2 → T1.3 → T1.4 → T1.5 → T1.6
```

### Phase 2: Deduplication (70 min)
```
T2.1 → T2.5 → T2.6 → T2.7 → T2.2 → T2.3 → T2.4
```

### Phase 3: Structural (100 min)
```
T3.5 → T3.4 → T3.1 → T3.8 → T3.2 → T3.3 → T3.6 → T3.7 → T3.9 → T3.10
```

### Phase 4: Polish (50 min)
```
T4.5 → T4.2 → T4.4 → T4.1 → T4.3 → T4.6
```

---

## D2 Execution Graph

```d2
title: SystemNix — Do More With Less

direction: right

phase1: {
  label: "Phase 1: Quick Wins (45 min)"
  shape: rectangle
  style.fill: "#2d5a3d"

  T1_1: "T1.1 Fix dns-update.sh path" {style.fill: "#a3be8c"}
  T1_2: "T1.2 Remove dead allowUnfreePredicate" {style.fill: "#a3be8c"}
  T1_3: "T1.3 Remove nix.gc from networking" {style.fill: "#a3be8c"}
  T1_4: "T1.4 Remove nix.gc from services/default" {style.fill: "#a3be8c"}
  T1_5: "T1.5 Remove 28L dead comments" {style.fill: "#a3be8c"}
  T1_6: "T1.6 Remove offensive tools" {style.fill: "#a3be8c"}

  T1_1 -> T1_2 -> T1_3 -> T1_4 -> T1_5 -> T1_6
}

phase2: {
  label: "Phase 2: Deduplication (70 min)"
  shape: rectangle
  style.fill: "#2d4a6a"

  T2_1: "T2.1 Fix double overlay imports" {style.fill: "#81a1c1"}
  T2_5: "T2.5 Fix internet-diagnostic lib.sh" {style.fill: "#81a1c1"}
  T2_6: "T2.6 Fix route-health shebang" {style.fill: "#81a1c1"}
  T2_7: "T2.7 Remove duplicate colorSchemeLib" {style.fill: "#81a1c1"}
  T2_2: "T2.2 Merge harden/hardenUser" {style.fill: "#5e81ac"}
  T2_3: "T2.3 Extract colorScheme shared module" {style.fill: "#5e81ac"}
  T2_4: "T2.4 Move Firefox policies" {style.fill: "#5e81ac"}

  T2_1 -> T2_5 -> T2_6 -> T2_7 -> T2_2 -> T2_3 -> T2_4
}

phase3: {
  label: "Phase 3: Structural (100 min)"
  shape: rectangle
  style.fill: "#5a3d2d"

  T3_5: "T3.5 mkPackageOverlay to default.nix" {style.fill: "#d08770"}
  T3_4: "T3.4 Move d2DarwinOverlay" {style.fill: "#d08770"}
  T3_1: "T3.1 Deduplicate 34-module list" {style.fill: "#bf616a"}
  T3_8: "T3.8 Consolidate overlay composition" {style.fill: "#bf616a"}
  T3_2: "T3.2 Extract gitea mirror scripts" {style.fill: "#d08770"}
  T3_3: "T3.3 Extract gitea token scripts" {style.fill: "#d08770"}
  T3_6: "T3.6 Replace hardcoded /home/lars comfyui" {style.fill: "#d08770"}
  T3_7: "T3.7 Replace hardcoded /home/lars hermes" {style.fill: "#d08770"}
  T3_9: "T3.9 Merge monitoring.nix into base" {style.fill: "#d08770"}
  T3_10: "T3.10 Add path validation test" {style.fill: "#d08770"}

  T3_5 -> T3_4 -> T3_1 -> T3_8 -> T3_2 -> T3_3 -> T3_6 -> T3_7 -> T3_9 -> T3_10
}

phase4: {
  label: "Phase 4: Polish (50 min)"
  shape: rectangle
  style.fill: "#4a4a5a"

  T4_5: "T4.5 Verify disableTests overlay" {style.fill: "#b48ead"}
  T4_2: "T4.2 Remove tor-browser + openvpn" {style.fill: "#b48ead"}
  T4_4: "T4.4 mkDefault for apparmor" {style.fill: "#b48ead"}
  T4_1: "T4.1 Rename to browser-policies" {style.fill: "#b48ead"}
  T4_3: "T4.3 Shell script IPs to env vars" {style.fill: "#b48ead"}
  T4_6: "T4.6 Update AGENTS.md" {style.fill: "#b48ead"}

  T4_5 -> T4_2 -> T4_4 -> T4_1 -> T4_3 -> T4_6
}

phase1 -> phase2: "then" {style.stroke-dash: 3}
phase2 -> phase3: "then" {style.stroke-dash: 3}
phase3 -> phase4: "then" {style.stroke-dash: 3}
```

---

## Metrics

| Metric | Before | After (target) | Delta |
|--------|--------|----------------|-------|
| flake.nix lines | 620 | ~500 | -120 lines |
| Duplicate nix.gc definitions | 3 | 1 | -2 |
| Duplicate overlay imports | 2 files × 2 | 0 | -4 imports |
| Dead code lines | ~45 | ~0 | -45 lines |
| Offensive security packages | 8 | 0 | -8 packages |
| Hardcoded `/home/lars` in modules | 3 | 0 | -3 paths |
| Duplicate option declarations | 2 platforms × 2 opts | 1 shared module | -1 copy |
| Separate harden/hardenUser files | 2 | 1 | -1 file |
| Shell scripts reimplementing lib.sh | 1 | 0 | -1 script |
| Broken scripts (wrong paths) | 1 | 0 | -1 bug |
| Embedded shell in gitea.nix | ~310 lines | ~0 | -310 lines |
| Total Nix files | 111 | ~110 | -1 file |
