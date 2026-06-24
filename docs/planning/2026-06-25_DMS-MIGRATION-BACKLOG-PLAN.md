# DMS Migration + SystemNix Backlog — Comprehensive Execution Plan

**Generated:** 2026-06-25
**Scope:** ALL open TODOs across DMS migration status, TODO_LIST.md, ROADMAP.md, FEATURES.md gaps
**Constraint:** Every task ≤ 12 min. Sorted by impact / effort / customer-value.

---

## Priority Tiers

| Tier | Meaning |
|------|---------|
| **P0** | CRITICAL — system integrity at risk (undeployed changes, dual wallpaper managers, stale processes) |
| **P1** | HIGH — runtime verification of untested critical paths + broken services |
| **P2** | MEDIUM — documentation accuracy + declarative theme + infrastructure health |
| **P3** | LOW — plugin polish + desktop enhancements |
| **P4** | LONG-TERM — upstream contributions + future vision |

---

## Full Task Table

### P0 — CRITICAL (Deploy & Stabilize)

| ID | Task | ≤12 min chunk | Est | Impact | Effort | Depends |
|----|------|---------------|-----|--------|--------|---------|
| P0.1 | Deploy wallpaper migration | Run `nix run .#deploy` (or `nix run .#pre-deploy-check` first) | 12m | 10 | S | — |
| P0.2 | Verify DMS wallpaper set | `dms ipc call wallpaper get` → confirm path is in `~/.local/share/wallpapers/` | 2m | 9 | XS | P0.1 |
| P0.3 | Verify DMS wallpaper cycling | `dms ipc call wallpaper next` → wallpaper changes; Mod+W | 2m | 9 | XS | P0.1 |
| P0.4 | Verify awww fully gone | `systemctl --user status awww-daemon awww-wallpaper` → "not-loaded" | 2m | 9 | XS | P0.1 |
| P0.5 | Confirm dms-wallpaper-init ran | `systemctl --user status dms-wallpaper-init` → active (exited) | 2m | 8 | XS | P0.1 |
| P0.6 | Reboot evo-x2 | Reboot → clears stale polkit-gnome, applies new generation fully | 12m | 9 | M | P0.1 |
| P0.7 | Post-reboot: DMS owns notifications | `busctl --user list \| grep Notifications` → quickshell owns it | 3m | 8 | XS | P0.6 |
| P0.8 | Post-reboot: polkit agent clean | `journalctl --user -u dms.service \| grep polkit` → no "already exists" warning | 3m | 7 | XS | P0.6 |

### P1 — HIGH (Runtime Verification + Broken Services)

| ID | Task | ≤12 min chunk | Est | Impact | Effort | Depends |
|----|------|---------------|-----|--------|--------|---------|
| P1.1 | Test notification delivery | `notify-send "DMS test"` → DMS popup appears | 2m | 9 | XS | P0.6 |
| P1.2 | Test DMS lock screen (IPC) | `dms ipc lock lock` → screen locks | 2m | 9 | XS | P0.6 |
| P1.3 | Test lock on real suspend | `systemctl suspend` → wakes to locked screen | 5m | 9 | S | P0.6 |
| P1.4 | Verify all 13 plugins load | `journalctl --user -u dms.service \| grep "Plugin loaded"` → 13 entries, 0 errors | 3m | 8 | XS | P0.6 |
| P1.5 | Run `dms doctor` | Execute + read output + note any issues | 5m | 7 | XS | P0.6 |
| P1.6 | Reset Monitor365 failed state | `systemctl --user reset-failed monitor365-server` | 1m | 6 | XS | P0.6 |
| P1.7 | Verify Pocket ID email sending | Trigger login notification, check delivery | 5m | 6 | S | P0.6 |
| P1.8 | Fix Twenty CRM 502s — diagnose | `docker logs twenty-server-1 --tail=100` → identify cause | 8m | 7 | S | — |
| P1.9 | Fix Twenty CRM 502s — apply fix | Apply fix based on P1.8 findings (OOM/connection limit) | 12m | 7 | M | P1.8 |
| P1.10 | Audit Gatus health checks | Check 6 DOWN services for wrong URLs (SigNoz, Immich, etc.) | 12m | 6 | S | — |

### P2 — MEDIUM (Docs + Theme Decision + Infra)

| ID | Task | ≤12 min chunk | Est | Impact | Effort | Depends |
|----|------|---------------|-----|--------|--------|---------|
| P2.1 | **DECISION: matugen vs Catppuccin** | Read both systems, decide: dynamic Material You OR static Catppuccin Mocha | 10m | 9 | S | P0.6 |
| P2.2 | Implement theme decision | If static: set `enableDynamicTheming=false` + `DMS_DISABLE_MATUGEN=1`. If dynamic: remove static colorScheme from DMS-themed apps | 12m | 8 | M | P2.1 |
| P2.3 | FEATURES.md — remove retired desktop components | Delete Waybar/Swaylock/Wlogout/Dunst/Awww rows (§4 Desktop Components) | 8m | 7 | XS | — |
| P2.4 | FEATURES.md — add DMS section | New subsection: DMS shell, 13 plugins, wallpaper, lock, OSD, clipboard | 12m | 7 | XS | — |
| P2.5 | FEATURES.md — fix OOM/health refs | `waybar` → `dms` in OOM protection + other references | 5m | 5 | XS | — |
| P2.6 | FEATURES.md — update ADR-004 | Mark ADR-004 (PartOf vs BindsTo wallpaper) as historical (awww retired) | 3m | 4 | XS | — |
| P2.7 | ROADMAP.md — mark QuickShell DONE | Change line 33 from "future exploration" to completed; move to deferred/done | 5m | 6 | XS | — |
| P2.8 | ROADMAP.md — add DMS follow-ups | Add matugen decision result, plugin auto-detection, declarative theme as roadmap items | 5m | 4 | XS | P2.1 |
| P2.9 | Create dms-matugen.service (if dynamic) | Systemd user service: applies Catppuccin accent on login via `dms matugen generate` | 12m | 6 | S | P2.1 |
| P2.10 | Add `dms doctor` to pre-deploy-check | Wire `dms doctor` into `scripts/pre-deploy-check.sh` | 8m | 5 | S | P1.5 |
| P2.11 | Archive old status reports (batch 1) | Move pre-session-100 files to `docs/status/archive/` (first 50) | 12m | 4 | XS | — |
| P2.12 | Archive old status reports (batch 2) | Move remaining pre-session-100 files (next 50) | 12m | 4 | XS | P2.11 |
| P2.13 | Archive old status reports (batch 3) | Move final batch, verify ~30 current remain | 8m | 4 | XS | P2.12 |
| P2.14 | Swap investigation | `smem -t -k \| tail -20`; consider `swapoff -a && swapon -a` | 10m | 5 | S | — |

### P3 — LOW (Plugin Polish + Desktop Enhancements)

| ID | Task | ≤12 min chunk | Est | Impact | Effort | Depends |
|----|------|---------------|-----|--------|--------|---------|
| P3.1 | Auto-detect WAN interfaces (Dual-WAN) | Replace hardcoded `enp2s0`/`wlp1s0` with `/sys/class/net` probe in plugin QML | 12m | 5 | M | — |
| P3.2 | Add GPU temp to GPU Monitor plugin | Read `temp1_input` from hwmon in QML, add to bar pill | 8m | 5 | S | — |
| P3.3 | Add BTRFS disk usage to Btrfs plugin | `df` on `/` → show % used alongside snapshot age | 8m | 4 | S | — |
| P3.4 | DMS bar widget ordering | Configure which systemnix plugins appear left/right in DMS settings | 12m | 4 | S | P0.6 |
| P3.5 | Create DMS plugin template | Skeleton dir: `PluginComponent` + `plugin.json` + example Process pattern | 12m | 5 | S | — |
| P3.6 | NPU devfreq path detection | Probe for NPU device name instead of hardcoded search | 8m | 3 | S | — |
| P3.7 | Ollama model download progress | Add active download status to Ollama plugin (API polling) | 12m | 4 | M | — |
| P3.8 | DNS block rate per-hour graph | Add simple sparkline/trend to DNS Stats plugin | 12m | 4 | M | — |
| P3.9 | Port ImmichMemory widget | Photo-of-the-day DMS plugin (was standalone, never ported) | 12m | 3 | M | — |

### P4 — LONG-TERM (Upstream + Future Vision)

| ID | Task | ≤12 min chunk | Est | Impact | Effort | Depends |
|----|------|---------------|-----|--------|--------|---------|
| P4.1 | NixOS test for DMS plugin loading | Write `nixosTests` that builds + checks plugin QML validity | 12m | 6 | L | P0.6 |
| P4.2 | DMS CLI wrapper for NixOps | `nix run .#dms-restart`, `nix run .#dms-locks` flake apps | 12m | 4 | M | — |
| P4.3 | Document settings.json tradeoff | AGENTS.md note: DMS UI changes don't persist; plugin_settings is declarative | 8m | 5 | XS | — |
| P4.4 | DMS plugin dev guide | Document Process + StdioCollector + Timer patterns for future plugins | 12m | 4 | S | P3.5 |
| P4.5 | Migrate rofi → DMS launcher | Evaluate DMS launcher maturity; port if ready | 12m | 3 | L | P0.6 |
| P4.6 | DMS theme overlay (Catppuccin) | Inject Catppuccin colors via DMS theme system (alt to P2.1) | 12m | 4 | L | P2.1 |
| P4.7 | BTRFS /data subvolume migration (plan) | Document steps: create subvol, update fstab, rsync data, reboot | 12m | 7 | S | — |
| P4.8 | BTRFS /data subvolume migration (exec) | Execute the migration (requires downtime window) | 12m | 8 | L | P4.7 |
| P4.9 | Cloud backup eval | Evaluate BorgBackup to Hetzner StorageBox (read research doc) | 10m | 7 | S | — |
| P4.10 | Hermes: add OpenAI API key | sops edit hermes.yaml, add `openai_api_key` | 5m | 6 | XS | — |
| P4.11 | Hermes: install SSH deploy key | Copy private key, add pubkey to GitHub deploy keys | 5m | 5 | XS | — |
| P4.12 | Hermes: set fallback model | `sudo -u hermes hermes config set fallback_model openrouter/gpt-4o` | 2m | 5 | XS | — |
| P4.13 | Upstream: aw-watcher-utilization | PR poetry-core migration to nixpkgs | 12m | 3 | M | — |
| P4.14 | Upstream: KeePassXC Chromium manifests | PR to nixpkgs | 12m | 3 | M | — |
| P4.15 | Upstream: taskwarrior3 build flags | PR SYSTEM_CORROSION + TLS_NATIVE_ROOTS defaults | 12m | 3 | M | — |
| P4.16 | Disabled service triage | Decide enable/remove for voice-agents, minecraft, photomap | 10m | 4 | S | — |

---

## Summary Statistics

| Tier | Tasks | Total Est | Avg Impact | Key Theme |
|------|-------|-----------|------------|-----------|
| P0 Critical | 8 | ~38m | 8.6 | Deploy + stabilize |
| P1 High | 10 | ~58m | 7.5 | Runtime verification + broken services |
| P2 Medium | 14 | ~120m | 5.6 | Docs + theme decision + infra |
| P3 Low | 9 | ~98m | 4.1 | Plugin polish |
| P4 Long-term | 16 | ~160m | 4.8 | Upstream + future vision |
| **TOTAL** | **57** | **~474m (~8h)** | — | — |

## Critical Path

```
P0.1 (deploy) → P0.6 (reboot) → P1.1-P1.4 (verify) → P2.1 (theme decision) → P2.2 (implement)
                                                              ↓
                                              P2.3-P2.8 (docs) can run in parallel
```

## Top 5 by Impact/Effort Ratio

| Rank | Task | Impact | Effort | Ratio |
|------|------|--------|--------|-------|
| 1 | P1.1 Test notification delivery | 9 | XS | 9.0 |
| 2 | P1.2 Test DMS lock screen | 9 | XS | 9.0 |
| 3 | P0.2 Verify wallpaper set | 9 | XS | 9.0 |
| 4 | P0.3 Verify wallpaper cycling | 9 | XS | 9.0 |
| 5 | P0.4 Confirm awww gone | 9 | XS | 9.0 |
