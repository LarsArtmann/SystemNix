# SystemNix Status Report — 2026-07-01 00:04 CEST

**Session 153** | Rofi → DMS Migration | Triggered by: niri OOM crash investigation

---

## Executive Summary

A rofi process leaked **7 GB RAM + 2.3 GB swap** over 5h22m, triggering a **global OOM cascade** that killed niri, ghostty, signal-desktop, pipewire, unbound, clickhouse, and immich. All 5 niri keybindings have been migrated to DankMaterialShell's native IPC (spotlight, clipboard, keybinds modal). Two community DMS plugins (emoji launcher, calculator) were added. The cliphist service was retired. The change is **deployed and verified** but **uncommitted to git**.

---

## a) FULLY DONE ✅

| # | Task | Evidence |
|---|------|----------|
| 1 | **Rofi → DMS migration** — 5 niri keybindings rewired | `hm.kdl` deployed, verified zero rofi refs |
| 2 | **Mod+D / Mod+Space** → `dms ipc call spotlight toggle` | Confirmed in deployed config |
| 3 | **Alt+C** → `dms ipc call clipboard toggle` | Confirmed in deployed config |
| 4 | **Mod+Shift+/** → `dms ipc call keybinds toggle niri` | Confirmed in deployed config |
| 5 | **Mod+period** → `dms ipc call spotlight toggleQuery ":e"` | Emoji plugin deployed |
| 6 | **Mod+Shift+C** → `dms ipc call spotlight toggleQuery "="` | Calc plugin deployed |
| 7 | **dms-emoji-launcher plugin** added via `fetchFromGitHub` | In `plugin_settings.json` (15 plugins) |
| 8 | **DankCalculator plugin** added via `fetchFromGitHub` | In `plugin_settings.json` (15 plugins) |
| 9 | **DMS MemoryMax=4G** — defense-in-depth guard | Confirmed in deployed `dms.service` |
| 10 | **cliphist service retired** — DMS owns clipboard | `cliphist.service` removed from generation |
| 11 | **Rofi kept for Sway backup WM only** — multi-wm.nix | Comment updated, Sway fallback preserved |
| 12 | **AGENTS.md updated** — migration + OOM root cause + cliphist | 4 edits applied |
| 13 | **FEATURES.md updated** — DMS spotlight/clipboard/keybinds entries | 5 edits applied |
| 14 | **TODO_LIST.md updated** — session 153 completed section | Added |
| 15 | **nix flake check --no-build** — all checks passed | ✅ |
| 16 | **nix eval toplevel** — clean eval | ✅ store path produced |
| 17 | **nix run .#deploy** — 0 failed units at switch | 15 derivations, cliphist.service removed |
| 18 | **Pre-deploy validation** — 13 passed, 2 warnings (disk) | ✅ |
| 19 | **Dead comment cleanup** — home.nix, multi-wm.nix | ✅ |

---

## b) PARTIALLY DONE 🔨

| # | Item | What's done | What's missing |
|---|------|-------------|----------------|
| 1 | **Live IPC verification** | Config verified in deployed files (hm.kdl, plugin_settings.json, dms.service) | Can't test `dms ipc call spotlight toggle` — no Wayland session active (OOM killed it, user is on SSH). Needs graphical login to smoke-test all 5 bindings |
| 2 | **gatus-config.nix health endpoints** | SigNoz + Monitor365 health endpoint paths improved (`/api/v1/health`, `/health`) — pre-existing change, not from this session | Needs commit + deploy verification |
| 3 | **73 commits undeployed (previous report)** | The deploy I ran brings the running system to current HEAD + uncommitted changes | The changes are uncommitted — a reboot would lose them if not committed |
| 4 | **SSO/OIDC** | Forgejo + Gatus native OIDC (Layer 1) deployed and live (Pocket ID serving Gatus login at 00:08) | Layer 1 SLO not wired per-app; SSO flows not E2E tested by user |

---

## c) NOT STARTED 📋

| # | Item | Source |
|---|------|--------|
| 1 | **Graphical session restart** to activate DMS + test bindings | OOM killed session; user needs to re-login or reboot |
| 2 | **BTRFS `/data` subvolume migration** | TODO_LIST.md P3 — Docker/Immich data unprotected |
| 3 | **Pi 3 DNS failover cluster** | TODO_LIST.md P6 — hardware required |
| 4 | **Auditd enablement** | TODO_LIST.md P6 — blocked on NixOS 26.05 bug #483085 |
| 5 | **AppArmor enablement** | TODO_LIST.md P6 — explicitly disabled |
| 6 | **Monitor365 agent→server auth** | TODO_LIST.md P6 — no auth, LAN-open |
| 7 | **Disabled service triage** (voice-agents, minecraft, photomap) | TODO_LIST.md P6 |

---

## d) TOTALLY FUCKED UP 💀

| # | Issue | Severity | Impact |
|---|-------|----------|--------|
| 1 | **Root disk at 90%** (78G free of 723G) | 🔴 Critical | Pre-deploy warned. nix-gc failed at 00:00 (likely BTRFS health guard aborting — actually correct behavior, but space is genuinely low). Build sandboxes accumulating. BTRFS snapshots hold references — freed space lags 14d. **A hard crash from BTRFS metadata ENOSPC (2026-06-26) can recur.** |
| 2 | **6.8 GB swap used on 93 GB RAM** | 🟠 High | Strix Halo reserves ~35 GB for GPU/NPU (93 GB visible of 128 GB). With heavy builds + services, memory pressure is chronic. The OOM cascade today proves the system has insufficient headroom under load. |
| 3 | **Portal service (GTK) crash-looping** | 🟡 Medium | `xdg-desktop-portal-gtk` failed 7+ times since 21:28. Likely missing fusermount3 in user session, or OOM damage. Needs investigation after graphical re-login. |
| 4 | **Forgejo OIDC setup failed at 23:54** | 🟡 Medium | `forgejo-oidc-setup.service` failed — likely timing (pocket-id-provision ordering). Pocket ID itself recovered and is serving OIDC (Gatus login active at 00:08). Needs `systemctl reset-failed` + restart. |
| 5 | **ActivityWatch Wayland watcher start-limit-hit** | 🟡 Medium | `aw-watcher-window-wayland` hit start-limit at 21:28 — likely OOM damage or no Wayland session. Needs reset-failed + restart after graphical login. |
| 6 | **Load average 21.90** | 🟡 Medium | Transient — nix Go builds + user dev work (golangci-lint, go vet, Python ML script, monitor365 BDD tests). Will normalize when builds complete. |

---

## e) WHAT WE SHOULD IMPROVE 🚀

| # | Area | Current State | Improvement |
|---|------|---------------|-------------|
| 1 | **OOM defense** | Per-service MemoryMax + user.slice limits | DMS now has MemoryMax=4G, but the 93GB-visible-RAM constraint (Strix Halo GPU reserve) means headroom is tight. Consider lowering user.slice MemoryMax from 64G to ~50G, or increasing GPU reservation transparency. |
| 2 | **Rofi full removal** | Rofi config kept for Sway; rofi-calc + rofi-emoji plugins still installed via HM | Once Sway is confirmed rarely-used, consider removing rofi HM module entirely (saves build time + closure size). Or install a DMS-compatible launcher for Sway. |
| 3 | **DMS plugin pinning** | Community plugins pinned by commit SHA via fetchFromGitHub | Good — but no update mechanism. Consider a flake input or periodic manual bump workflow. |
| 4 | **BTRFS space monitoring** | btrfs-health.nix gates nix-gc, collects metrics, Gatus alerts | Deployed but root disk still at 90%. The guard aborts GC when <10% device-unallocated — but doesn't proactively free space. Need automated old-generation cleanup + snapshot pruning. |
| 5 | **Session recovery** | OOM kills the entire graphical session; no auto-restart | niri has session save/restore, but DMS doesn't auto-start without a Wayland display. Consider a systemd user target that re-launches the compositor session after OOM recovery. |
| 6 | **Sway parity** | Sway has rofi but no DMS (niri-only). Sway also has no notification daemon, no polkit agent | If Sway is a real fallback WM, it needs its own notification/launcher/polkit stack. If it's vestigial, consider removing it. |
| 7 | **Health check granularity** | Gatus checks endpoints, not internal service health | SigNoz/Monitor365 now have `/health` endpoints (uncommitted gatus-config.nix change). Extend this pattern to all services. |

---

## f) TOP #25 THINGS TO GET DONE NEXT 🎯

Sorted by impact → effort → urgency.

| # | Priority | Task | Impact | Effort | Why |
|---|----------|------|--------|--------|-----|
| 1 | 🔴 P0 | **Commit the rofi→DMS migration** | ★★★★★ | 2m | Changes are deployed but uncommitted — a reboot/generation rollback loses everything |
| 2 | 🔴 P0 | **Reboot evo-x2** | ★★★★★ | 5m | Clears OOM damage, restarts Portal service, activates DMS with new bindings, clears swap. Verifies boot reliability. |
| 3 | 🔴 P0 | **Graphical login + smoke-test 5 DMS bindings** | ★★★★★ | 10m | Proves spotlight/clipboard/keybinds/emoji/calc actually work via keybindings |
| 4 | 🔴 P0 | **Free root disk space** (90% → <80%) | ★★★★★ | 15m | `nix-collect-garbage -d`, clear build sandboxes, check BTRFS snapshots. Prevents metadata ENOSPC recurrence. |
| 5 | 🟠 P1 | **`systemctl reset-failed` + restart failed services** | ★★★★☆ | 5m | forgejo-oidc-setup, ActivityWatch watcher, Portal — clear OOM damage |
| 6 | 🟠 P1 | **Commit gatus-config.nix health endpoints** | ★★★★☆ | 2m | SigNoz/Monitor365 health checks improved — uncommitted |
| 7 | 🟠 P1 | **Verify Gatus OIDC login works end-to-end** | ★★★★☆ | 5m | Pocket ID is serving (log shows Gatus auth flow at 00:08) — confirm token exchange + callback |
| 8 | 🟠 P1 | **Verify Forgejo OIDC login works end-to-end** | ★★★★☆ | 5m | forgejo-oidc-setup failed — needs reset + re-run, then test login |
| 9 | 🟠 P1 | **Investigate Portal service crash-loop** | ★★★☆☆ | 15m | xdg-desktop-portal-gtk failing repeatedly — check fusermount3 wrapper, OOM damage |
| 10 | 🟡 P2 | **E2E test all Layer 2 (oauth2-proxy) services** | ★★★★☆ | 20m | Homepage, SigNoz, Twenty, Dozzle, etc. — verify forward-auth still works post-deploy |
| 11 | 🟡 P2 | **BTRFS `/data` subvolume migration** | ★★★★☆ | 60m | Docker/Immich data unprotected by snapshots — high data-loss risk |
| 12 | 🟡 P2 | **Swap investigation** (6.8 GB used) | ★★★☆☆ | 15m | Run `smem -t -k | tail -20`, identify swap hogs, consider `swapoff -a && swapon -a` |
| 13 | 🟡 P2 | **Update TODO_LIST.md "Updated" date** | ★★☆☆☆ | 1m | Still says "session 152" — should be session 153 |
| 14 | 🟡 P2 | **Monitor365 upstream Rust panic fix** | ★★★☆☆ | 30m | Axum 0.7 route syntax — needs fix in github:LarsArtmann/monitor365 |
| 15 | 🟡 P2 | **Twenty CRM 502 monitoring** | ★★☆☆☆ | 5m | Was intermittent — verify resolved post-deploy |
| 16 | 🟡 P2 | **Hermes SSH deploy key + fallback model** | ★★★☆☆ | 10m | Manual steps blocked on human (TODO_LIST.md P2) |
| 17 | 🟡 P2 | **Pocket ID email verification test** | ★★★☆☆ | 5m | SMTP wired but untested (TODO_LIST.md P0) |
| 18 | 🟢 P3 | **Disabled service triage** (voice-agents, minecraft, photomap) | ★★☆☆☆ | 15m | Decide enable or remove — reduce closure size |
| 19 | 🟢 P3 | **Split large modules** (monitor365 716L, signoz 705L, forgejo 583L) | ★★☆☆☆ | 60m | Maintainability |
| 20 | 🟢 P3 | **Auditd enablement** (blocked on NixOS 26.05 bug) | ★★☆☆☆ | 5m | Check if bug fixed, re-enable if so |
| 21 | 🟢 P3 | **Sway backup WM decision** — keep or remove | ★★★☆☆ | 15m | If kept: needs launcher/notification/polkit parity. If removed: saves complexity. |
| 22 | 🟢 P3 | **Rofi HM module removal** (if Sway removed) | ★★☆☆☆ | 10m | Eliminates rofi-calc/rofi-emoji builds from closure |
| 23 | ⚪ P4 | **Upstream nixpkgs contributions** (7 items in TODO_LIST.md P5) | ★☆☆☆☆ | 2h+ | poetry-core, valkey tests, taskwarrior3 flags, etc. |
| 24 | ⚪ P4 | **Pi 3 DNS failover cluster** | ★★★☆☆ | 4h+ | Hardware required — entire DNS failover is planned-only |
| 25 | ⚪ P4 | **DMS plugin auto-update workflow** | ★★☆☆☆ | 30m | Community plugins pinned by SHA — add flake input or periodic bump |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF 🤔

> **Is the `dms ipc call spotlight toggleQuery ":e"` syntax correct for triggering the emoji plugin, or does the emoji plugin need to be explicitly enabled/scanned first?**
>
> The DMS documentation describes `toggleQuery` as pre-filling the spotlight search box with a query string. The emoji plugin uses `:e` as its trigger prefix. But I could not verify live whether DMS's spotlight recognizes plugin triggers via `toggleQuery` — it's possible the spotlight only searches apps/files by default and plugins need to be explicitly enabled via the Settings UI first (which requires a graphical session I don't have).
>
> If `toggleQuery ":e"` doesn't activate the emoji plugin, the fallback would be `dms ipc call spotlight toggleWith plugins` (switch to plugins tab) or configuring the plugin as enabled in `plugin_settings.json`.
>
> **I need someone to log in graphically, press Mod+period, and tell me if the emoji picker appears.**

---

## System Snapshot

| Metric | Value |
|--------|-------|
| **Date** | 2026-07-01 00:04 CEST |
| **Uptime** | 1 day 6h44m |
| **Load average** | 21.90 / 16.80 / 16.52 (transient — nix builds) |
| **Memory** | 62 GiB used / 93 GiB total (Strix Halo reserves ~35 GiB for GPU/NPU) |
| **Swap** | 6.8 GiB used / 9.4 GiB total |
| **Root disk** | 637 GiB used / 723 GiB (90%) — **critical** |
| **Data disk** | 686 GiB used / 1.1 TiB (67%) |
| **Deployed generation** | `phcp7q8a...` (2026-06-26 nixpkgs + uncommitted working tree) |
| **Commits ahead of origin** | 0 (changes uncommitted) |
| **OOM events today** | 1 cascade (19:25–19:38, rofi-triggered, 7 processes killed) |
| **Failed services** | Portal (GTK), forgejo-oidc-setup, nix-gc (expected), ActivityWatch watcher |
| **Pocket ID** | ✅ Running, serving OIDC (Gatus login active at 00:08) |

---

## Files Changed (Uncommitted)

```
 AGENTS.md                                |  8 +++---
 FEATURES.md                              | 16 +++++++-----
 TODO_LIST.md                             |  8 ++++++
 modules/nixos/desktop/multi-wm.nix       |  2 +-
 modules/nixos/services/gatus-config.nix  |  4 +--
 platforms/nixos/desktop/niri-wrapped.nix | 45 ++++++++------------------------
 platforms/nixos/desktop/quickshell.nix   | 37 +++++++++++++++++++++-----
 platforms/nixos/users/home.nix           |  5 ++--
 8 files changed, 70 insertions(+), 55 deletions(-)
```
