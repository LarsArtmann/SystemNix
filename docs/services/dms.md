# dms (DankMaterialShell) — desktop shell runbook

**Service:** user unit `dms.service` (upstream HM module `dankMaterialShell.homeModules.dank-material-shell`, wrapped by `programs.systemnix-quickshell` in `platforms/nixos/desktop/quickshell.nix`, enabled at `platforms/nixos/users/home.nix:197`). Input: `github:AvengeMedia/DankMaterialShell` (floats on `?ref=master` — bump-verify per the flake comment: `nix build .#dms-shell`, then a fresh-session HM check). DMS is Quickshell-based and replaces Waybar, Dunst, wlogout, rofi, and the standalone polkit agent. It starts with the compositor (`wayland.systemd.target` = `niri.service`) — no graphical session, no dms. Deep agent reference: [docs/agents/desktop.md](../agents/desktop.md).

## Polkit: DMS owns the slot exclusively (2026-10-04)

- **Winner, named in wiring:** DMS's compiled agent (`Quickshell.Services.Polkit` inside quickshell, dialog rendered by DMS's themed `Modals/PolkitAuth*.qml`) is the sole `org.freedesktop.PolicyKit1.AuthenticationAgent` on the session bus. The competitor — niri-flake's `niri-flake-polkit.service` (`polkit-kde-agent-1`) — is disabled in `modules/nixos/desktop/niri-config.nix` (`systemd.user.services.niri-flake-polkit.enable = false`; deployed rendering: `/etc/systemd/user/niri-flake-polkit.service` symlinks the `-disabled` unit). Never re-enable it: its Qt env cannot resolve its QQC2 style (`module "fusion" is not installed` → KCrash on EVERY prompt, the 2026-10-03 191-crash loop), and it registers before DMS, so re-enabling re-loses DMS's registration by race.
- **Registration does not retry:** DMS's `PolkitService` registers once at startup; a failed registration (slot already taken) is one WARN and auth stays dead until the shell restarts or re-login. Consequence: after ANY change to who-races-the-slot, `systemctl --user restart dms` (or re-login) on a RUNNING session. Deployed generations shipping the disable don't need the restart at next login — a fresh session start registers cleanly.
- **Live ownership probe** (agent-safe; `busctl --user` fails bare — export the address first, gdbus works):
  ```bash
  export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
  gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.GetNameOwner org.freedesktop.PolicyKit1.AuthenticationAgent
  ```
  Owner string = agent alive; `NameHasNoOwner` with an active graphical session = GUI auth dead (with no session it is legitimate — SSH-only periods have no agent). Gatus slot-ownership paging is a parked idea ([watch] row in `docs/todo/monitoring.md`); post-deploy-check asserts the same probe (added 2026-11-23).
- **Opt-out env:** `DMS_DISABLE_POLKIT=1` disables DMS's agent — NEVER set it here (0 hits in the tree; setting it would leave the slot unowned with no fallback agent). The KDE-agent defect is queued upstream (`docs/todo/upstream.md`, verify-before-filing gate applies).

## Env + unit hardening (quickshell.nix Service overrides)

| Knob | Value | Why |
| ---- | ----- | ---- |
| `DMS_DISABLE_MATUGEN` | `1` | matugen package removed (`enableDynamicTheming = false`); DMS still probes `which matugen` and warns — the env skips the probe (Theme.qml). |
| `DMS_DISABLE_POLKIT` | unset | See above — DMS must keep the polkit slot. |
| `MemoryMax` | `4G` | Defense-in-depth after the 2026-06-30 rofi OOM (7 GB leak → compositor killed); DMS is now launcher, clipboard, and all modals. One real polkit prompt also exercises this cap. |
| `Restart` | `always`, `RestartSec 2` | Upstream Quickshell ScriptModel UAF (issue #863) fires on rapid toplevel churn (polkit dialogs, window storms) — crashes are expected, recovery must be fast, backoff prevents the 2026-07-11 288-restart storm. |
| `StartLimitBurst` | `30` / 5 min | Losing the shell is worse than quick restarts; clear with `systemctl --user reset-failed dms`. |

## Settings split-brain (HM symlink vs DMS runtime file)

- `plugin_settings.json` is the HM-managed symlink (declarative). `settings.json` STARTED as an HM symlink but DMS replaces it with a real file at runtime (expands 19 declarative keys to 530+ with defaults + UI changes); since 2026-09-29 it is a DMS-owned runtime file — DMS watches it and hot-reloads external edits (jq + atomic mv is a supported mutation path; a parse error makes DMS keep its in-memory copy and log, never clobber). UI edits to either file are ephemeral across rebuilds — only Nix-declared settings survive.
- `scripts/deploy.sh` backs up real-file versions of both (`settings.json` + `plugin_settings.json` → `<name>.pre-deploy.<timestamp>.bak`) before `nh os switch` overwrites them with symlinks. Restores are manual: diff the newest `.pre-deploy.*.bak`, re-apply wanted keys into the Nix declarations (durable) or the runtime file (ephemeral).
- **Plugin id == nix key:** a plugin's `plugin.json` `id` MUST equal the `plugins.<attr>` key or the `enabled: true` written to `plugin_settings.json` misses `getPluginSetting(manifest.id, "enabled")` — all embedded systemnix plugins follow id == key == dir name. Community plugins showing `[disabled]` in `dms ipc call plugins list` still work: launcher instances are created on trigger-demand, bypassing the enabled gate.
- **A running DMS does not see new plugin dirs or settings changes from a deploy** — `dms ipc call plugins reload <id>` re-reads QML for EXISTING plugins only, not first-time discovery or startup-loaded settings; restart the unit (`pkill bin/dms` — `Restart=always` supervises — or `systemctl --user restart dms` when available).

## Ops quick reference

- **Restart:** `systemctl --user restart dms` (owner/interactive shell; agent shells are NNP-sandboxed — ask the owner or use an owner-launched session).
- **Notifications:** DND semantics, per-app mute rules, `dms ipc call notifications enableDoNotDisturbFor <minutes>`, `dms notify` — full matrix in [docs/agents/desktop.md](../agents/desktop.md) (2026-09-29 storm aftermath; `notificationDndAllowCritical: false` lives in the runtime settings.json).
- **Desktop-death monitoring:** `niri-health-metrics` textfile collector + Gatus "Niri Compositor" freshness composite own the liveness paging (desktop died / crash loop); DMS itself has no dedicated check — slot-ownership paging is the parked [watch] row.
- **Open verification (owner at machine):** one real polkit prompt must render DMS-themed under the 4G cap, zero `is not installed` aborts (verified zero in the retained journal window 2026-11-15→23; window pre-dates the disable's deploy, so the 24h leg needs the next graphical-login cycle to complete). → `docs/todo/desktop.md` blocked:user row.

## Related

- [docs/agents/desktop.md](../agents/desktop.md) — full desktop reference (DMS/Quickshell/niri/session manager, plugin split-brain detail)
- [docs/services/forgejo.md](./forgejo.md)-style runbook conventions; the polkit race narrative: `docs/status/2026-10-04_10-53_polkit-agent-registration-race-fix-and-daemon-amend-damage-report.md`
