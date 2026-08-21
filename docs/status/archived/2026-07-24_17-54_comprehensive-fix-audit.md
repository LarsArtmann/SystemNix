# Status Report: Comprehensive Fix Audit — All Bugs Found and Fixed

**Date:** 2026-07-24 17:54
**Scope:** Full audit of all session changes — found and fixed 5 bugs across 4 files
**Status:** ~~All changes validated, ready for deploy~~ **Deployed** — generation built 2026-07-24 18:14 (after HEAD `d243f1ee`). All 5 bug fixes are live: shellcheck fix in deploy.sh, `${ELAPSED}` escaping, watchdog runs as root, dead-code removal, helium-launch timeout, post-deploy pgrep. Monitor365 server healthy, agent running, DNS resolving.

---

## Bugs Found During Audit

### BUG 1 (critical): Shellcheck SC2043 — deploy.sh `for` loop with single element

- **File:** `scripts/deploy.sh`
- **Problem:** `for svc in monitor365.service; do` — shellcheck rejects single-element loops
- **Build impact:** BLOCKED `nix run .#deploy` — derivation build failed
- **Fix:** Replaced `for` loop with direct `if` statement

### BUG 2 (critical): Nix string escaping broke `${ELAPSED}` in graphical-restart script

- **File:** `modules/nixos/services/monitor365.nix:454`
- **Problem:** `\'\'${ELAPSED}` in Nix `''` string produced `'\${ELAPSED}` in bash — the `\$` prevented variable expansion, printing the literal string `${ELAPSED}` instead of the elapsed seconds value
- **Verified:** `nix eval` of generated script confirmed the fix produces `${ELAPSED}` (correct bash expansion)
- **Fix:** Changed to `''${ELAPSED}` — Nix `''` before `$` produces literal `$` in output

### BUG 3 (critical): Watchdog ran as `monitor365` user — couldn't call `systemctl start`

- **File:** `modules/nixos/services/monitor365.nix:331-341`
- **Problem:** `User = "monitor365"` + `Group = "monitor365"` — regular users cannot start system services. The entire watchdog layer was broken
- **Fix:** Removed `User`/`Group` — service now runs as root (required for `systemctl start/restart`)

### BUG 4 (medium): Watchdog had dead code and didn't detect circuit-breaker deadlock

- **File:** `modules/nixos/services/monitor365.nix:342-375`
- **Problem:** `SERVER_HEALTH` variable was defined but never used. The watchdog checked if the agent was alive but NOT if it was actually connected to the server — the exact bug we were fixing
- **Fix:** Added check 3: queries server `/health` with `jq`, if `realtime` shows "connected (0 devices)", restarts agent to clear CB. Added `jq` to `path`.

### BUG 5 (low): helium-launch had no timeout — could hang forever on zombie

- **File:** `platforms/nixos/desktop/niri-wrapped.nix:62-77`
- **Problem:** `while pgrep ... ; do sleep 5; done` — infinite loop if helium process is zombie
- **Fix:** Added 300s timeout — breaks out and launches anyway

### BUG 6 (low): post-deploy-check used `pgrep` without `procps` in runtime inputs

- **File:** `scripts/post-deploy-check.sh:207`
- **Problem:** `pgrep -x monitor365` — `procps` not in `writeShellApplication` runtime inputs, could fail silently
- **Fix:** Removed `pgrep` check entirely — the `curl` check on port 9191 is more reliable and doesn't need extra dependencies

---

## Validation Results

| Check                                            | Result                   |
| ------------------------------------------------ | ------------------------ |
| `nix flake check --no-build`                     | ✓ all checks passed      |
| deploy.sh shellcheck (via `nix run .#deploy`)    | ✓ builds successfully    |
| post-deploy-check.sh shellcheck (via `nix eval`) | ✓ builds successfully    |
| `bash -n deploy.sh`                              | ✓ OK                     |
| `bash -n post-deploy-check.sh`                   | ✓ OK                     |
| `${ELAPSED}` in generated script                 | ✓ correct bash expansion |
| Watchdog script content                          | ✓ all 3 checks present   |
| Timer config (OnBootSec/OnUnitActiveSec)         | ✓ 2min / 5min            |
| startLimitBurst on monitor365.service            | ✓ 10                     |

---

## Complete Change Inventory

| File                                       | Changes                                                                        |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| `platforms/nixos/desktop/niri-wrapped.nix` | `helium-launch` wrapper (empty-window fix) + 300s timeout                      |
| `platforms/common/dns-local.nix`           | Added `dnsblock` and `dnsblockd` subdomains                                    |
| `modules/nixos/services/monitor365.nix`    | Start limits + graphical-restart debounce + agent watchdog (root, 3-check, jq) |
| `scripts/deploy.sh`                        | Start enabled-but-inactive monitor365 after deploy                             |
| `scripts/post-deploy-check.sh`             | Full Monitor365 agent↔server test + DNS blocker local check                    |
| `AGENTS.md`                                | 3 new gotcha entries                                                           |

---

## Ready for Deploy

All changes are syntax-validated and bug-fixed. Run:

```
nix run .#deploy
```

---

## Item Resolution (2026-07-30)

No numbered action items in this report — all work was completed within the session or is tracked in TODO_LIST.md / CHANGELOG.md.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
