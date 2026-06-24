# Quickshell Implementation Status — Session 2

**Date:** 2026-06-24 11:41
**Branch:** master
**Last commit:** ce43e8e0 — docs(status): Quickshell implementation status
**Eval status:** PASSING (`nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel --apply "x: true"` → `true`)
**Deploy status:** NEVER RUN — zero runtime verification

---

## a) FULLY DONE (eval-verified code committed)

| # | Area | What | Files | Commit |
|---|------|------|-------|--------|
| 1 | Flake | `dankMaterialShell` input added, locked (quickshell comes transitively) | `flake.nix`, `flake.lock` | f94722c7 |
| 2 | HM Module | `platforms/nixos/desktop/quickshell.nix` created, imports DMS niri + dank-material-shell upstream modules | `quickshell.nix` | f94722c7 |
| 3 | Enable | `programs.systemnix-quickshell.enable = true` in `home.nix` | `home.nix` | f94722c7 |
| 4 | Kill Dunst | `services.dunst.enable = lib.mkForce false` | `home.nix` | d90ade6d |
| 5 | Kill polkit_gnome | Removed from security-hardening.nix | `security-hardening.nix` | d90ade6d |
| 6 | Kill wlogout | Import + program removed | `home.nix` | d90ade6d |
| 7 | Package cleanup | `dunst`, `wlogout`, `wl-clip-persist` removed from home.packages | `home.nix` | d90ade6d |
| 8 | DevShell | `nix develop .#quickshell` with qmlls + qtdeclarative | `flake.nix` | d90ade6d |
| 9 | AGENTS.md | Architecture, procedures, 4 new gotchas added | `AGENTS.md` | ea151191 |
| 10 | Brainstorm docs | Vision HTML + Nix implementations research MD | `docs/brainstorming/` | bea5ec40 |
| 11 | Implementation plan | 80-task HTML report with D2 graph | `docs/planning/` | bea5ec40 |
| 12 | Status report | Previous session status HTML | `docs/status/` | ce43e8e0 |

**Total: 12 items fully done (eval-verified)**

---

## b) PARTIALLY DONE (code exists but incomplete/untested/unwired)

| # | Area | What exists | What's missing | Severity |
|---|------|-------------|----------------|----------|
| 1 | DMS plugins | 7 of 10 plugins created (ollama, dns, gpu, tasks, health, btrfs, voice) — each with plugin.json + widget QML + settings QML | 3 plugins not started (camera, servers, crm). None tested. None packaged in Nix. None installed to `~/.config/DankMaterialShell/plugins/` | HIGH |
| 2 | Standalone QML widgets | 16 files in `pkgs/quickshell-widgets/` (old approach, pre-plugin discovery) | These are DEPRECATED by the DMS plugin approach. Should be removed or archived. They have wrong base class (`Singleton` instead of `PluginComponent`) | MEDIUM |
| 3 | Lock screen | `LockScreen.qml` written (WlSessionLock + PAM + clock + media) | Not wired — niri still spawns `swaylock`. swayidle still calls swaylock for before-sleep | MEDIUM |
| 4 | Mission Control OSD | `MissionControl.qml` written (volume/brightness/Wi-Fi/BT/DND/caffeine/power) | Not wired to any keybind or DMS integration | MEDIUM |
| 5 | Clipboard manager | `ClipboardManager.qml` written | Not wired. Rofi-based cliphist picker still active in niri keybinds | LOW |
| 6 | Immich memories | `ImmichMemory.qml` written | Not wired to lock screen. API key not configured | LOW |
| 7 | Catppuccin theme | DMS supports Catppuccin via `registryThemeVariants` | NOT configured in `quickshell.nix` — DMS uses default theme | HIGH |
| 8 | Port templating | All QML widgets hardcode ports (9090, 11434, etc.) | Not templated from `lib/ports.nix` | MEDIUM |
| 9 | Waybar parallel | Intentionally kept running alongside DMS | Not yet retired. 7 shell scripts still in `waybar.nix` | LOW (safety) |

**Total: 9 items partially done**

---

## c) NOT STARTED

| # | Task | Blocks on | Impact |
|---|------|-----------|--------|
| 1 | **Deploy to evo-x2** (`nix run .#deploy`) | Nothing — this is THE blocker | CRITICAL |
| 2 | Runtime test: DMS bar appears | #1 | CRITICAL |
| 3 | Runtime test: notifications (notify-send) | #1 | CRITICAL |
| 4 | Runtime test: polkit prompt (pkexec) | #1 | HIGH |
| 5 | Runtime test: system tray (SNI host) | #1 | HIGH |
| 6 | Install plugins to DMS plugins dir | #1, #7 (understand DMS plugin loading at runtime) | HIGH |
| 7 | Catppuccin Mocha theme application | #1 | HIGH |
| 8 | Update niri keybinds (lock screen, remove dunstctl) | #1 | MEDIUM |
| 9 | Update swayidle before-sleep | #1 | MEDIUM |
| 10 | Retire Waybar (remove import, package, scripts) | #2, #3, #4, #5 verified | HIGH |
| 11 | Dual-WAN failover widget | Plugin system understanding | MEDIUM |
| 12 | NPU utilization widget (amd-npu sysfs) | Plugin system understanding | LOW |
| 13 | sops secret health widget | Plugin system understanding | LOW |
| 14 | Camera DMS plugin (systemnix-camera) | Plugin template | LOW |
| 15 | Server pulse DMS plugin (systemnix-servers) | Plugin template | LOW |
| 16 | CRM pipeline DMS plugin (systemnix-crm) | Plugin template | LOW |
| 17 | X-Restart-Triggers for hot-reload on switch | HM module authoring | MEDIUM |
| 18 | Custom HM module (caelestia pattern) | After widgets proven | LOW |
| 19 | greetd greeter | After in-session shell proven | LOW |
| 20 | Package plugins declaratively in Nix | After plugins tested at runtime | MEDIUM |
| 21 | Update FEATURES.md | After deploy verified | LOW |
| 22 | FEATURES.md | After deploy | LOW |

**Total: 22 items not started**

---

## d) TOTALLY FUCKED UP

**Nothing is broken.** `nix eval` passes. No errors in the flake. The honest assessment is "calm before the storm" — everything looks correct in eval but nothing has been runtime-tested.

**However, there IS a conceptual problem I discovered:**

The original `pkgs/quickshell-widgets/` directory (16 QML files) was written using `Singleton` as the base class — these were designed to be imported as Quickshell singletons. But DMS uses a **plugin system** where widgets must extend `PluginComponent` and provide `plugin.json` manifests. The old widgets are architecturally wrong for DMS.

**The fix:** The new `pkgs/dms-plugins/` directory has the correct architecture (7 of 10 plugins done with proper `PluginComponent` + `plugin.json`). The old `quickshell-widgets/` directory should be removed once all plugins are migrated.

---

## e) WHAT WE SHOULD IMPROVE

| # | Issue | Why it matters | Fix |
|---|-------|----------------|-----|
| 1 | **Deploy before more code** | Every additional QML file written without runtime testing compounds unverified assumptions. The next hour of coding is worth less than 5 minutes of deploy. | Stop coding, deploy, verify |
| 2 | **Remove deprecated quickshell-widgets/** | 16 orphaned files with wrong base class. Confusing for future readers. Delete after confirming dms-plugins/ is the right approach. | `trash pkgs/quickshell-widgets/` |
| 3 | **Apply Catppuccin theme** | The entire system uses Catppuccin Mocha. DMS running with its default theme looks visually inconsistent. | Set `registryThemeVariants` in settings |
| 4 | **Port templating** | AGENTS.md says "never hardcode ports." Every QML widget hardcodes them. | Use DMS plugin settings to inject port values from Nix config |
| 5 | **Plugin packaging in Nix** | Currently plugins are source files that need manual `~/.config/DankMaterialShell/plugins/` installation. Should be packaged declaratively. | Use `xdg.configFile` to symlink plugins from Nix store |
| 6 | **Niri keybinds stale** | `Mod+Shift+N` references `dunstctl` (Dunst is disabled). `Mod+Shift+Escape` spawns `swaylock` (should be DMS lock). | Update niri config after DMS is proven |
| 7 | **Two notification daemons risk** | Dunst is `mkForce false` but if DMS doesn't grab the DBus notification name, you get ZERO notifications silently. | Test `notify-send` immediately after deploy |

---

## f) Top 25 Things to Get Done Next

Sorted by impact × customer value / effort.

| # | Task | Impact | Effort | Blocks on |
|---|------|--------|--------|-----------|
| 1 | **Deploy to evo-x2**: `nix run .#deploy` | CRITICAL | 10m | Nothing |
| 2 | Verify DMS bar renders + niri workspaces | CRITICAL | 5m | #1 |
| 3 | Test `notify-send "test"` → DMS handles it | CRITICAL | 2m | #1 |
| 4 | Test `pkexec true` → DMS polkit prompt | HIGH | 2m | #1 |
| 5 | Verify system tray (SNI host) | HIGH | 5m | #1 |
| 6 | Apply Catppuccin Mocha theme to DMS | HIGH | 10m | #1 |
| 7 | Install 7 plugins to `~/.config/DankMaterialShell/plugins/` | HIGH | 10m | #1 |
| 8 | Write remaining 3 plugins (camera, servers, crm) | LOW | 30m | #7 pattern |
| 9 | Remove deprecated `pkgs/quickshell-widgets/` | MEDIUM | 5m | #7 verified |
| 10 | Package plugins declaratively via `xdg.configFile` | MEDIUM | 20m | #7 verified |
| 11 | Update niri `Mod+Shift+Escape` → DMS lock screen | MEDIUM | 5m | #2 |
| 12 | Update niri `Mod+Shift+N` → remove dunstctl | LOW | 3m | #3 |
| 13 | Update swayidle before-sleep → DMS lock | MEDIUM | 5m | #2 |
| 14 | Remove `programs.swaylock` from HM | MEDIUM | 5m | #11 |
| 15 | Template port numbers from `lib/ports.nix` | MEDIUM | 15m | #10 |
| 16 | Retire Waybar (import, package, service, scripts) | HIGH | 15m | #2-5 verified |
| 17 | Strip 7 `waybar*` shell scripts from `waybar.nix` | MEDIUM | 12m | #16 |
| 18 | Test Mission Control OSD popup | MEDIUM | 10m | #1 |
| 19 | Test Clipboard Manager popup | MEDIUM | 10m | #1 |
| 20 | Write Dual-WAN failover widget | MEDIUM | 12m | #7 |
| 21 | Write NPU utilization widget | LOW | 12m | #7 |
| 22 | Write sops secret health widget | LOW | 12m | #7 |
| 23 | Add `X-Restart-Triggers` to HM module | MEDIUM | 10m | #16 |
| 24 | Update FEATURES.md with Quickshell features | LOW | 10m | #16 |
| 25 | Write NixOS evaluation test for quickshell module | LOW | 10m | #10 |

---

## g) The #1 Question I Cannot Answer Myself

**Should I deploy right now?**

Every piece of code written — 7 DMS plugins, the HM module, the flake input, all the tool kills — is verified by `nix eval` but has NEVER been loaded by a running Quickshell instance. I cannot deploy from this session because it requires the evo-x2 runtime environment.

The single highest-value action remaining is:

```bash
nix run .#deploy
```

This would answer:
1. Does DMS start at all alongside niri?
2. Does DMS grab the notification DBus name (or are we in silent no-notification land)?
3. Does the polkit agent activate?
4. Does the system tray work?
5. Is the visual default theme acceptable, or is Catppuccin urgent?

If the answer is "yes, deploy now" — I'll deploy, verify all 5 questions, then continue wiring plugins.
If the answer is "no, wire more first" — I'll finish the remaining 3 plugins, package them in Nix, apply the theme, and update keybinds. But none of that will be runtime-verified.

**My recommendation: deploy now.** Waybar is still running in parallel as a safety net. If DMS fails, Waybar is still there. The worst case is DMS doesn't start — and then we see the error and fix it.

---

## Commit History (this Quickshell project)

```
ce43e8e0 docs(status): Quickshell implementation status — 52 tasks code-complete
ea151191 feat(quickshell): lock screen, OSD, clipboard manager, docs (P3-P4)
d90ade6d feat(quickshell): kill Dunst/polkit/wlogout + write SystemNix service widgets (P1-P2)
f94722c7 feat(quickshell): add DankMaterialShell flake input and HM module (P0)
bea5ec40 docs(planning): add Quickshell 80-task implementation plan with D2 architecture diagram
```

**Uncommitted work:** `pkgs/dms-plugins/` (7 plugin directories, 21 files — the corrected DMS plugin architecture)
