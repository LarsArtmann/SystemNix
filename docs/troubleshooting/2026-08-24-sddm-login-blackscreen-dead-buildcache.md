# 2026-08-24: SDDM login black-screen loop — dead buildcache automount + fish guard

## Symptom

Every SDDM login: screens go black, ~20 s later back to the login screen.
niri never started (zero `niri.service` activity in the user manager, empty
`~/.local/share/sddm/wayland-session.log`).

## Root cause

The SanDisk SDSSDA240G buildcache SSD was physically absent (USB enclosure
unplugged/flapped), but `mnt-buildcache.automount` stayed armed. Chain:

1. `hm-session-vars.sh` exports `GOCACHE`/`GOMODCACHE`/`GOLANGCI_LINT_CACHE`
   = `/mnt/buildcache/...` into every login session
   (`/etc/profile.d/`, sourced by SDDM's `wayland-session`).
2. Login shell is fish. `~/.config/fish/conf.d/00-go-cache-guard.fish`
   (added 2026-08-22) probes each cache var with a BARE `mkdir -p $val`.
3. Each probe triggers the automount and blocks the full
   `x-systemd.device-timeout=10s` in uninterruptible state — ~40 s across
   four probes. SIGTERM cannot interrupt the autofs wait; only SIGKILL can
   (TASK_KILLABLE).
4. `niri-session` never reached its first `systemctl --user` — niri never
   started, VT1 stayed black.
5. `display-watchdog.service` (30 s timer) saw: connector DP-1 connected +
   `enabled=disabled` + `dpms=Off`, a Class=user Type=wayland session, no
   niri process → restarted `display-manager.service` → back to SDDM.

The watchdog did exactly what it was designed for; the login chain was the
defect.

## Fix

- `~/.config/fish/conf.d/00-go-cache-guard.fish`: probes are now
  `timeout --signal=KILL 1 mkdir/touch` — bounded to 1 s per probe even on
  a dead automount. Login chain measured 3.1 s end-to-end (was 40+).
- Declarative owner: `platforms/nixos/users/home.nix`
  (`xdg.configFile."fish/conf.d/00-go-cache-guard.fish"`) — same content,
  so the next switch takes ownership without conflict.

## Lessons

- A login-shell config that touches an automount can brick graphical
  login without any trace in the session log — the hang happens before
  the session command runs.
- `timeout` (SIGTERM) cannot bound uninterruptible automount waits; use
  `--signal=KILL`.
- The eval-time session-boot-audit guard covers the systemd dependency
  graph, not shell startup — different black-screen class, same symptom.

## Open items

- The buildcache SSD is still absent (`/dev/disk/by-id` has no SanDisk):
  replug/replace it, or caches keep redirecting to `~/tmp` (QLC NVMe).
  smartd already tolerates absence (`-d removable`).
