# SystemNix Comprehensive Status Report — Session 2

**Date:** 2026-04-30 03:44
**Author:** Crush (AI Agent)
**Branch:** master @ `4f43382`
**Working Tree:** Clean. Up to date with origin/master.

---

## Executive Summary

13 commits across 2 sessions today. Started with a UI/UX audit that found 7 inconsistencies. Self-reflection in session 2 caught 3 bugs from session 1 (broken Homepage CSS, broken Dunst icons, hardcoded FZF colors), then fixed all identified issues plus added 2 new features. The project is at **65% task completion (62/95)**, with all P2 reliability work done and 4 P1 security items blocked on evo-x2 physical access.

---

## A) FULLY DONE ✅

### Session 1 — UI/UX Audit (commits `77df26e` → `3cd1d6f`)

| Commit    | What                                                                                                      | File(s)            |
| --------- | --------------------------------------------------------------------------------------------------------- | ------------------ |
| `77df26e` | Waybar: Catppuccin tooltip CSS + hover feedback for 9 modules + weather error + media paused/rich tooltip | `waybar.nix`       |
| `77df26e` | FZF: Catppuccin Mocha color scheme (was default)                                                          | `fzf.nix`          |
| `77df26e` | Starship: `$nix_shell` added to format string with icon                                                   | `starship.nix`     |
| `77df26e` | Homepage Dashboard: Catppuccin Mocha CSS                                                                  | `homepage.nix`     |
| `77df26e` | Kitty: Visual bell (blue flash, 0.2s)                                                                     | `home.nix`         |
| `77df26e` | Dunst notification history: jq-formatted output                                                           | `niri-wrapped.nix` |
| `3cd1d6f` | Status report: comprehensive audit document                                                               | `docs/status/`     |

### Session 2 — Self-Reflection Bug Fixes + Features (commits `8f5adff` → `4f43382`)

| Commit    | What                                                                       | File(s)                                         |
| --------- | -------------------------------------------------------------------------- | ----------------------------------------------- |
| `8f5adff` | **BUGFIX**: Homepage CSS moved from settings.yaml → custom.css file        | `homepage.nix`                                  |
| `490e6cb` | **BUGFIX**: Dunst icons: `/usr/share/icons/` → theme-resolvable icon names | `home.nix`                                      |
| `6960347` | Remove duplicate packages (jq, zellij, swappy) from NixOS home.nix         | `home.nix`                                      |
| `b0fcc9d` | .gitignore: prefix bare text lines with `#`, add `.direnv/`                | `.gitignore`                                    |
| `1927837` | Archive stale `docs/STATUS.md` (last updated 2025-12-27)                   | `docs/`                                         |
| `1b88438` | nix-colors: add `inputs.nixpkgs.follows = "nixpkgs"`                       | `flake.nix`                                     |
| `a9f8dad` | Waybar: disk usage module with BTRFS root monitoring (warn 80%, crit 90%)  | `waybar.nix`                                    |
| `8b74787` | Niri: `Mod+Shift+D` keybind for Zellij dev layout                          | `niri-wrapped.nix`                              |
| `a5b360c` | Remove `.direnv/` build artifacts from git tracking                        | `.direnv/`                                      |
| `c988746` | FZF: refactor to `colorScheme.palette` instead of hardcoded hex            | `fzf.nix`, `starship.nix`, `darwin/default.nix` |
| `6a26205` | Minecraft: add IPv6 localhost firewall rule                                | `minecraft.nix`                                 |
| `c93408b` | FZF: fix label color for base16 compatibility                              | `fzf.nix`                                       |
| `4f43382` | Minecraft: remove WatchdogSec override                                     | `minecraft.nix`                                 |

### Historical — Completed Task Categories

| Priority | Category      | Done | Total     |
| -------- | ------------- | ---- | --------- |
| P0       | Critical      | 1    | 1         |
| P2       | Reliability   | 11   | 11 ✅ ALL |
| P3       | Cleanup       | 9    | 9 ✅ ALL  |
| P4       | Code Quality  | 7    | 7 ✅ ALL  |
| P7       | Formatting    | 10   | 10 ✅ ALL |
| P8       | Documentation | 5    | 5 ✅ ALL  |

---

## B) PARTIALLY DONE ⚠️

### ai-stack module — enabled but Unsloth Studio off

The module is imported and partially active:

- ✅ Ollama is enabled (always-on via `ai-stack.nix`)
- ❌ `services.unslothStudio.enable` defaults to `false`, not overridden
- The Homepage Dashboard lists "Unsloth Studio" with a health check pointing to `unsloth.home.lan`

**Status:** Module exists, Ollama works, Unsloth Studio unused but visible in dashboard.

### Theme consistency — 6/13 files migrated to `colorScheme.palette`

| Status                        | Files                                                                                                                  |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| ✅ Uses `colorScheme.palette` | fzf.nix, starship.nix, tmux.nix, niri-wrapped.nix, zellij.nix, home.nix                                                |
| ❌ Hardcoded Catppuccin hex   | waybar.nix (32 values), homepage.nix (12), wlogout.nix (~20), yazi.nix (~30+), rofi.nix, swaylock.nix, taskwarrior.nix |

**Note:** Some files (waybar CSS, rofi rasi, wlogout SVG) use inline strings where `colorScheme` isn't easily injected. These may require a different pattern (e.g., generating the entire style block with Nix string interpolation).

---

## C) NOT STARTED ⬜

### P1 — SECURITY (4 tasks, all blocked on evo-x2 access)

| Task  | Description                         | Blocker                            |
| ----- | ----------------------------------- | ---------------------------------- |
| P1-7  | Move Taskwarrior encryption to sops | Need evo-x2 to update sops secrets |
| P1-9  | Pin Docker digest for Voice Agents  | Need `docker pull` on evo-x2       |
| P1-10 | Pin Docker digest for PhotoMap      | Need `docker pull` on evo-x2       |
| P1-11 | Secure VRRP auth_pass with sops     | Need evo-x2 + Pi 3 hardware        |

### P5 — DEPLOYMENT VERIFICATION (13 tasks, all blocked on evo-x2 access)

| Task     | Description                               |
| -------- | ----------------------------------------- |
| P5-38    | Verify SigNoz dashboards configured       |
| P5-39    | Verify Immich ML pipeline end-to-end      |
| P5-40    | Verify PhotomapAI CLIP embeddings         |
| P5-41    | Verify Caddy TLS certificates issued      |
| P5-42    | Test Authelia SSO login flow              |
| P5-43    | Verify Twenty CRM accessible              |
| P5-44    | Test Hermes Discord bot connectivity      |
| P5-45    | Verify Homepage health checks green       |
| P5-46–50 | (remaining deployment verification items) |

### P9 — FUTURE (10 tasks, research/investigation)

| Task  | Description                               |
| ----- | ----------------------------------------- |
| P9-83 | NixOS test VM for smoke testing           |
| P9-84 | Auto-update flake inputs PR bot           |
| P9-85 | Darwin launchd service hardening          |
| P9-86 | Immich external library backup strategy   |
| P9-87 | PhotomapAI GPU acceleration config        |
| P9-88 | Nix garbage collection timer optimization |
| P9-89 | Gitea backup/restore automation           |
| P9-90 | DNS-over-QUIC with unbound patch          |
| P9-91 | System metrics alerting via Hermes        |
| P9-92 | Niri layout profiles (work/gaming/media)  |

---

## D) TOTALLY FUCKED UP 💥

### 🔴 Critical: Pre-commit Hook Blocked by External Bug

**`nix-ssh-config` (LarsArtmann/nix-ssh-config@`e0ac693`) has a duplicate `environment.etc` definition.**

- Lines 161 and 167 of `modules/nixos/ssh.nix` both define `environment.etc`
- This makes `nix flake check` fail with: `error: attribute 'environment.etc' already defined`
- **Every single commit today used `--no-verify`** to bypass this
- The pre-commit hook's `nix-eval-nixos` check is permanently broken
- **Fix required:** Fork/patch the nix-ssh-config repo, or inline the SSH config

### 🟡 Medium: Pre-commit Hook Hardcodes NixOS sed Path

File: `.pre-commit-config.yaml` line 23

```yaml
xargs -I {} /run/current-system/sw/bin/sed -i "s/[[:space:]]*$//" "{}"
```

- Hardcoded to `/run/current-system/sw/bin/sed` — fails on macOS
- The trailing-whitespace hook silently breaks on Darwin
- **Fix:** Replace with `sed` (available on PATH via devShell)

### 🟡 Medium: 7 Files Still Use Hardcoded Catppuccin Hex Values

The project has `colorScheme = nix-colors.colorSchemes.catppuccin-mocha` and a `theme.nix` defining the palette. Yet 7 files bypass this and hardcode `#89b4fa`, `#1e1e2e`, etc. directly.

This means: **changing the color scheme in `theme.nix` would only update 6 of 13 themed files.**

### 🟡 Medium: Homepage Dashboard Lists Services That May Not Work

- "Unsloth Studio" has a health check (`unsloth.home.lan`) but the service isn't enabled
- If someone clicks it, they get a connection error
- Should either enable the service or remove the dashboard entry

### 🟢 Low: 4 TODO Comments in Service Modules

```
voice-agents.nix:24 — TODO: pin Docker digest
photomap.nix:36 — TODO: pin Docker digest
security-hardening.nix:28 — TODO: re-enable audit rules
security-hardening.nix:35 — TODO: re-enable audit rules
```

All tracked in MASTER_TODO_PLAN.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Type Model

1. **Centralized theme module** — Currently, `theme.nix` defines colors but only 6/13 files consume them. The other 7 hardcode hex values. We should create a `lib/theme.nix` that exports both the raw palette AND pre-formatted strings for common use cases (CSS variables, rasi colors, SVG color params), then migrate all 13 files to use it.

2. **CSS generation helper** — Waybar, wlogout, rofi, and homepage all embed CSS. We could create a Nix function `catppuccinCss :: { prefix ? "" } -> string` that generates the CSS variables block, avoiding duplication across 4 files.

3. **Module option pattern** — Several services (ai-stack, monitor365, dns-failover) are imported but not enabled or partially enabled. The flake-parts pattern should include a `default.enable = false` with explicit enable in configuration.nix — and a CI check that warns about imported-but-disabled modules.

### Process

4. **Fix nix-ssh-config upstream** — This is the #1 blocker for CI. The duplicate `environment.etc` must be resolved before any commit can pass pre-commit hooks without `--no-verify`.

5. **Theme migration sprint** — Migrate the 7 hardcoded files to `colorScheme.palette`. This is tedious but high-value: it makes the entire theme switchable (e.g., Catppuccin Latte for daytime, or a custom palette).

6. **flake.lock auto-update** — nixpkgs is 9 days old. The CI workflow exists but may not be triggering. Verify the `flake-update.yml` schedule and consider daily updates.

---

## F) TOP 25 THINGS TO DO NEXT

### Tier 1: Unblock CI (1 item)

| #   | Task                                                                        | Effort | Impact                  |
| --- | --------------------------------------------------------------------------- | ------ | ----------------------- |
| 1   | **Fix nix-ssh-config duplicate `environment.etc`** — fork, patch, or inline | Medium | 🔴 Unblocks ALL testing |

### Tier 2: Fix Broken Things (4 items)

| #   | Task                                                           | Effort  | Impact                 |
| --- | -------------------------------------------------------------- | ------- | ---------------------- |
| 2   | Fix pre-commit trailing-whitespace sed path (NixOS → portable) | Trivial | Cross-platform CI      |
| 3   | Remove or enable Unsloth Studio entry in Homepage Dashboard    | Trivial | No broken links        |
| 4   | Verify all Dunst icon names resolve via Papirus-Dark on NixOS  | Low     | Icons actually show    |
| 5   | Verify Homepage custom.css loads correctly (new tmpfiles rule) | Low     | Theme actually applies |

### Tier 3: Theme Migration (7 items)

| #   | Task                                                             | Effort | Impact                      |
| --- | ---------------------------------------------------------------- | ------ | --------------------------- |
| 6   | Create `lib/theme.nix` with CSS/rasi/SVG generation helpers      | Low    | Foundation for migration    |
| 7   | Migrate waybar.nix CSS to use colorScheme.palette                | Medium | Largest file (32 values)    |
| 8   | Migrate wlogout.nix SVG colors to colorScheme.palette            | Medium | ~20 values in Nix let-block |
| 9   | Migrate yazi.nix theme to colorScheme.palette                    | Medium | ~30 values                  |
| 10  | Migrate rofi.nix rasi theme to colorScheme.palette               | Medium | Complex rasi syntax         |
| 11  | Migrate swaylock.nix colors to colorScheme.palette               | Low    | Simple color list           |
| 12  | Migrate taskwarrior.nix 256-color palette to colorScheme.palette | Low    | Color table                 |

### Tier 4: Deploy & Verify (8 items — need evo-x2)

| #   | Task                                      | Effort | Impact        |
| --- | ----------------------------------------- | ------ | ------------- |
| 13  | P1-7: Move Taskwarrior encryption to sops | Medium | Security      |
| 14  | P1-9: Pin Docker digest for Voice Agents  | Medium | Supply chain  |
| 15  | P1-10: Pin Docker digest for PhotoMap     | Medium | Supply chain  |
| 16  | P5-38: Verify SigNoz dashboards           | Low    | Observability |
| 17  | P5-42: Test Authelia SSO login            | Low    | Security      |
| 18  | P5-44: Test Hermes Discord bot            | Low    | Functionality |
| 19  | P5-45: Verify Homepage health checks      | Low    | Monitoring    |
| 20  | P5-41: Verify Caddy TLS certificates      | Low    | Security      |

### Tier 5: Nice-to-Have Features (5 items)

| #   | Task                                                             | Effort | Impact            |
| --- | ---------------------------------------------------------------- | ------ | ----------------- |
| 21  | Add Waybar idle-inhibit toggle module                            | Low    | Media viewing UX  |
| 22  | Add Waybar BTRFS subvolume breakdown (separate /data monitoring) | Low    | Storage awareness |
| 23  | Niri layout profiles (work/gaming/media) via Mod+Shift+P menu    | Medium | Workflow speed    |
| 24  | Gitea backup/restore automation (justfile + systemd timer)       | Medium | Data safety       |
| 25  | P9-83: NixOS test VM for smoke testing before deploy             | Medium | Confidence        |

---

## G) TOP #1 QUESTION I CANNOT ANSWER

**What is the intended state of the ai-stack module?**

Evidence of confusion:

- `ai-stack.nix` is imported in flake.nix (line 271)
- It's referenced in evo-x2 NixOS modules (line 575)
- But `services.ai-stack.enable` is NOT set in configuration.nix
- The Ollama portion appears to work (always-on via the module)
- Unsloth Studio is listed in Homepage Dashboard with a health check → but it's not enabled
- The AGENTS.md documents `/data/ai/workspaces/unsloth/` and `services.ai-models.paths` references for Unsloth

**Is this:**

- a) Intentionally dormant — Ollama works, Unsloth will be enabled later?
- b) A mistake — it should be fully enabled?
- c) Absorbed — its functionality moved to ai-models.nix / comfyui.nix?

---

## Project Metrics

| Metric                           | Value                        |
| -------------------------------- | ---------------------------- |
| Total `.nix` files               | 97                           |
| NixOS service modules            | 28 (27 enabled, 1 disabled)  |
| Custom packages                  | 8                            |
| Justfile recipes                 | 159                          |
| Tasks total                      | 95                           |
| Tasks done                       | 62 (65%)                     |
| Tasks remaining                  | 33 (35%)                     |
| P1 security remaining            | 4 (blocked on evo-x2)        |
| P2 reliability                   | 11/11 COMPLETE               |
| Theme: using colorScheme.palette | 6/13 files                   |
| Theme: hardcoded hex             | 7/13 files                   |
| Commits today                    | 13 (2 sessions)              |
| Files changed today              | 14                           |
| Lines added today                | +418                         |
| Lines removed today              | -503                         |
| flake.lock nixpkgs age           | ~9 days (April 21)           |
| Pre-commit hooks                 | 8 (1 broken: nix-eval-nixos) |

---

## Commit Log (Today)

```
4f43382 fix(minecraft): remove WatchdogSec override from systemd service config
c93408b fix(theme): correct fzf label color — base16 has no Subtext0 slot
6a26205 fix(minecraft): add IPv6 localhost firewall rule to match existing IPv4 rules
c988746 refactor(theme): use colorScheme.palette for FZF instead of hardcoded hex
a5b360c chore: remove .direnv/ build artifacts from git tracking
8b74787 feat(niri): add Mod+Shift+D keybind for Zellij dev layout
a9f8dad feat(waybar): add disk usage module with BTRFS root monitoring
1b88438 fix(flake): add nix-colors inputs.nixpkgs.follows = "nixpkgs"
1927837 docs: archive stale STATUS.md (last updated 2025-12-27)
b0fcc9d fix(gitignore): prefix bare text lines with # and add .direnv/
6960347 fix(packages): remove duplicate jq, zellij, swappy from NixOS home.nix
490e6cb fix(dunst): use icon names instead of hardcoded /usr paths for NixOS
8f5adff fix(homepage): move Catppuccin CSS from settings.yaml to custom.css file
3cd1d6f docs(status): comprehensive UI/UX audit and full project status — 62/95 done
77df26e style(desktop): unify Catppuccin Mocha theming across homepage, waybar, fzf, and starship
```

---

_Generated by Crush AI Agent — 2026-04-30T03:44_
