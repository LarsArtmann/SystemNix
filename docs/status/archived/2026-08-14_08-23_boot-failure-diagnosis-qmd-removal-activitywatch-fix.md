# Status: Boot Failure Diagnosis, qmd Removal, ActivityWatch Fix

**Date:** 2026-08-14 08:23
**Session start:** User reported many service failures + unsafe shutdowns on reboot, and a boot hang at GLMtec logo
**Session end:** 08:23 — changes made, NOT deployed

---

## What Was Reported

1. **Many service failures on reboot** — "Why did we have so many fails and show shutdowns when I rebooted?"
2. **Boot hang at GLMtec logo** — "Why did I get stuck at the GLMtec logo at boot until I clicked the power button, unplugged the DAS, and restarted?"

---

## A) FULLY DONE

### 1. Root Cause Diagnosis (3 boot failure causes identified)

| # | Service | Root Cause | Severity |
|---|---------|------------|----------|
| A | **Gatus** (23 panics) | No DNS/OIDC gate — gatus starts before dnsblockd loads 3.9M blocklist entries (~16s) and before Pocket-ID/Caddy HTTPS is ready (~90s). Each panic triggers systemd restart + OnFailure notification. Eventually self-recovers after ~2 min. | HIGH — journal flood, Discord alert storm |
| B | **qmd-mcp** (permanently dead) | `spawn node ENOENT` — wrapper starts node for main process but child processes can't find `node` on PATH. Crash-loops 5x in 10s, hits start-limit, stays dead permanently. | MEDIUM — service dead until manual restart |
| C | **aw-watcher-window-wayland** (permanently dead) | `After = [ "graphical-session.target" ]` but NOT `After = [ "niri.service" ]`. Target triggers niri to start but doesn't guarantee it's running. Watcher connects to non-existent Wayland display, panics, hits start-limit, stays dead. | LOW — activity tracking lost |

### 2. GLMtec Logo Boot Hang Diagnosed

**Root cause:** BIOS/UEFI POST issue, NOT NixOS. The DAS (JMicron JMS567 USB bridge + 2x Toshiba MG08ACA16TE 16TB 7200RPM drives) causes the BIOS to hang during USB device enumeration. 16TB drives take ~30s each to spin up. The BIOS either tries to enumerate all USB mass storage before continuing POST or has USB in its boot priority list.

**Fix:** BIOS settings change (manual, not NixOS):
1. Disable USB boot entirely
2. Enable Fast Boot (skips exhaustive USB enumeration)
3. Set boot device priority to NVMe only

### 3. Gatus OIDC Readiness Gate (COMMITTED in `28564898`)

Added `after = [ "dnsblockd.service" "pocket-id.service" "pocket-id-provision.service" ]` + curl-based `waitOidcReady` ExecStartPre to `gatus-config.nix`. Same pattern as oauth2-proxy. This prevents the 23x panic crash-loop.

**File:** `modules/nixos/services/gatus-config.nix:66-78, 1036-1057`

### 4. qmd Completely Removed (UNCOMMITTED)

User said "I do not need qmd-mcp". Full removal:

| File | Action |
|------|--------|
| `modules/nixos/services/qmd-config.nix` | **DELETED** (trashed) |
| `pkgs/qmd.nix` | **DELETED** (trashed) |
| `platforms/nixos/system/configuration.nix:453-466` | Removed `qmd-config.enable = true` block |
| `platforms/common/packages/base.nix:258-261` | Removed `qmd` from system packages |
| `lib/ports.nix:66` | Removed `qmd = 8181` port |
| `overlays/shared.nix:42-44` | Removed qmd overlay |
| `flake.nix:589` | Removed `qmd` from flake packages output |
| `modules/nixos/services/gatus-config.nix:965-979` | Removed qmd Gatus health check |
| `AGENTS.md` | Removed Qmd section (lines 133-148), 2 gotcha entries, 1 reference in StartLimitBurst gotcha |

### 5. ActivityWatch Wayland Watcher Fixed (UNCOMMITTED)

Added `"niri.service"` to the `After` list in `activitywatch.nix:31-34`. Same pattern as XDG portal drop-ins in `configuration.nix:125,131`.

**File:** `platforms/common/programs/activitywatch.nix:31-34`

### 6. Verification

`nix flake check --no-build` passes after all changes.

---

## B) PARTIALLY DONE

### 1. qmd Doc Cleanup — INCOMPLETE

Still references qmd in these non-historical files:
- `CHANGELOG.md` — ~~historical entries (OK to leave)~~ done (moot) — historical entries stay by design
- `FEATURES.md` — ~~feature table row needs marking as REMOVED~~ done at `7afab3f8` (both rows marked ❌ Removed)
- `TODO_LIST.md:50` — ~~references qmd in `criticalSystemServices`~~ done — the list (`scheduled-tasks.nix:197`) has no qmd
- `pkgs/README.md` — ~~packaging table row~~ done — 0 qmd refs remain
- `docs/gotchas-archive.md:87-89` — ~~3 qmd gotcha entries (enduring rules)~~ done at `7afab3f8` — 0 qmd refs remain
- `platforms/nixos/scripts/service-health-check` — ~~may reference qmd port~~ done (moot) — script has no qmd refs; planning-doc stragglers tracked in TODO_LIST

### 2. Gatus Fix — Not "Nix-Native"

User explicitly asked "Can we do something even more Nix native?" about the curl ExecStartPre pattern. I started researching (found 6 duplicated implementations of the OIDC/DNS wait pattern across services) but was redirected before delivering a solution. A shared `mkOidcGate` helper in `lib/` would DRY this up — this is still open. **→ RESOLVED:** `mkOidcGate`/`mkDnsGate` shipped at `7afab3f8` (`lib/default.nix:265,316`); 4 services refactored onto them (see `2026-08-14_09-30`).

---

## C) NOT STARTED

1. ~~**Deploy** — `nix run .#deploy` has NOT been run. All uncommitted changes are live in the working tree only.~~ done — landed at `7afab3f8`/`8ad493c9` and deployed in the 09:30 session (see `2026-08-14_09-30`)
2. **Reboot test** — no verification that the fixes actually prevent the boot failures on next reboot.
3. **BIOS fix** — requires manual BIOS configuration (disable USB boot, enable Fast Boot). Cannot be done from NixOS.
4. ~~**Shared DNS/OIDC gate helper** — the `mkDnsGate` / `mkOidcGate` helper in `lib/` was proposed but never built. 6 services duplicate the pattern: oauth2-proxy, gatus, forgejo, searxng, discordsync, browser-history.~~ done at `7afab3f8` (mkOidcGate + mkDnsGate in `lib/default.nix`)

---

## D) TOTALLY FUCKED UP

### 1. qmd PATH Fix Was Applied Then Reverted

I added `--prefix PATH : ${nodejs}/bin` to `pkgs/qmd.nix` to fix the `spawn node ENOENT` error. Then the user said they don't need qmd-mcp, so I reverted the PATH fix and removed qmd entirely. The intermediate commit `28564898` contains the gatus fix AND the qmd PATH fix — the qmd PATH fix is now dead code since the file was deleted. Not harmful, just wasteful churn.

### 2. Left PMA/Previous Session Changes Unexplained

The working tree has changes I did NOT make: `smart-audio.nix` (staged add), `system-health.nix` (modified), `twenty.nix` (modified), `TODO_LIST.md` (modified). These are from the PMA daemon or a previous session. I did not investigate, verify, or mention them. They will be included in the next deploy if not reviewed.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Patterns

1. **Shared OIDC readiness gate** — The curl-in-ExecStartPre OIDC wait pattern is duplicated across 6 services with slight variations. A `mkOidcGate` helper in `lib/` (or a custom systemd target `auth-ready.target` that fires after Pocket-ID is healthy) would eliminate the duplication and make it harder to forget when adding new OIDC services.

2. **`graphical-session.target` is insufficient for Wayland services** — Services that need a running Wayland compositor should use `After = [ "niri.service" ]` directly, not rely on the transitive `graphical-session.target` activation. The target fires when the compositor *starts*, not when it's *ready*. Consider auditing all HM user services that use `graphical-session.target`.

3. **DNS gate for all auth.home.lan consumers** — Gatus was missing the DNS gate that 5 other services have. There's no eval-time or CI check that catches this omission. A flake check that verifies any service referencing `auth.${domain}` has `after = [ "dnsblockd.service" ]` would prevent regressions.

### Operational

4. **Deploy after changes** — Changes are uncommitted and undeployed. The fixes won't take effect until `nix run .#deploy`.

5. **BIOS USB boot** — The GLMtec hang will recur on every cold boot with the DAS connected until BIOS settings are changed. This is the most impactful remaining fix.

6. **Unsafe shutdown count** — The watchdog reset from Aug 11 inflated the count. This is historical and doesn't reflect current stability, but the metric is misleading.

---

## F) NEXT TASKS (Prioritized)

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | ~~**Deploy** all changes (`nix run .#deploy`)~~ done — deployed in the 09:30 session (`7afab3f8`, `8ad493c9`) | Critical — fixes are inert until deployed | 10 min |
| 2 | **Fix BIOS settings** (disable USB boot, enable Fast Boot) | Critical — prevents boot hang | 5 min (manual) |
| 3 | ~~Clean up remaining qmd references: `FEATURES.md`, `TODO_LIST.md`, `pkgs/README.md`~~ done at `7afab3f8` (all named files clean; planning-doc stragglers in TODO_LIST) | Medium — stale docs | 10 min |
| 4 | ~~Build shared `mkOidcGate` helper in `lib/` to DRY 6 duplicated implementations~~ done at `7afab3f8` | High — prevents future "forgot the DNS gate" bugs | 30 min |
| 5 | Audit all HM user services using `graphical-session.target` — add `niri.service` ordering where needed | Medium — prevents start-limit-hit on other Wayland services | 20 min |
| 6 | Add eval-time check: any service referencing `auth.${domain}` must have `dnsblockd.service` in after/wants | High — catches missing DNS gates at build time | 30 min |
| 7 | Clean up `docs/services/HOME-MANAGER-ACTIVITYWATCH-GRAPHICAL-SESSION-PATCH.md` — document the `niri.service` fix | Low — documentation accuracy | 10 min |
| 8 | ~~Review and commit/trash the unexplained `smart-audio.nix`, `system-health.nix`, `twenty.nix` changes~~ done — smart-audio + Twenty landed at `8ad493c9`, system-health at `9b6590bf` | Medium — these will deploy if not reviewed | 15 min |
| 9 | ~~Remove qmd from Crush MCP config (crush.json) if present~~ done (moot) — no qmd in any crush config | Low — prevents connection errors in Crush | 5 min |
| 10 | Reboot test after deploy to verify all 3 boot failures are resolved | High — validates the fixes | 10 min |
| 11 | ~~Check `platforms/nixos/scripts/service-health-check` for qmd port reference~~ done (moot) — no qmd refs in the script | Low — stale reference | 5 min |
| 12 | ~~Consider `auth-ready.target` systemd target as the Nix-native alternative to curl gates~~ done (superseded) — `mkOidcGate`/`mkDnsGate` (`7afab3f8`) won; curl lives inside the helper | High — architectural improvement | 1-2h |
| 13 | ~~Remove qmd gotcha entries from `docs/gotchas-archive.md:87-89`~~ done at `7afab3f8` | Low — stale rules | 5 min |
| 14 | Verify the `overview.service` Gatus check recovers cleanly on next reboot (it was failing briefly) | Low — monitoring hygiene | 5 min |
| 15 | ~~Check if qmd GGUF models in `~/.cache/qmd/models/` should be cleaned up (~2GB)~~ done (moot) — models already gone; only 184K `index.sqlite` remains (TODO_LIST entry is stale) | Low — disk space | 5 min |

---

## G) QUESTIONS

1. ~~**Should I deploy now?** The gatus fix, qmd removal, and activitywatch fix are all uncommitted and undeployed. There are also unexplained changes from PMA/previous sessions (`smart-audio.nix`, `system-health.nix`, `twenty.nix`) in the working tree. Should I deploy everything, or do you want to review the non-session changes first?~~ answered — deployed in the 09:30 session; the "unexplained" changes landed as smart-audio + Twenty hardening (`8ad493c9`) and system-health checks (`9b6590bf`)

2. ~~**Do you want the Nix-native OIDC gate now?** You asked "Can we do something even more Nix native?" — I can build either a shared `mkOidcGate` helper or a systemd `auth-ready.target` that fires after Pocket-ID passes its healthz check. The target approach eliminates curl entirely — services just add `after = [ "auth-ready.target" ]`. Should I build this before deploying?~~ answered — `mkOidcGate`/`mkDnsGate` built at `7afab3f8`; `auth-ready.target` not pursued (curl retained inside the helper)

3. ~~**Should I clean up the qmd cache (~2GB in `~/.cache/qmd/`)?** The models and SQLite index are still on disk. Worth reclaiming, but `trash` on cache dirs can be slow on BTRFS.~~ answered (moot) — the GGUF models are already gone; only a 184K `index.sqlite` remains
