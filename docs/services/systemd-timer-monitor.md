# systemd-timer-monitor

Read-only systemd services + timers audit, served as static HTML at
`https://timers.home.lan`.

## Overview

Python script (zero dependencies) that runs `systemctl list-units` and
`systemctl list-timers`, identifies failed services and mis-scheduled timers,
and writes an HTML report + JSON status to a state directory served by
Caddy's `file_server`.

- **Upstream**: [cappy-dev/systemd-timer-monitor](https://github.com/cappy-dev/systemd-timer-monitor)
- **URL**: `https://timers.home.lan/`
- **Auth**: None (LAN-only, read-only public systemd data)
- **State**: `/var/lib/systemd-timer-monitor/` (report.html, status.json)

## Architecture

- **Timer-driven oneshot**: runs every 5 minutes via
  `systemd-timer-monitor-audit.timer` (`OnBootSec=2min`, `OnUnitActiveSec=5min`)
- **Output**: `report.html` (human-readable) + `status.json` (machine-readable)
  written to `StateDirectory`, served by Caddy `file_server`
- **Caddy**: `timers.home.lan` vHost serves the state directory with a
  `@report` matcher rewriting `/`, `/index.html`, `/report` -> `/report.html`

## Service Details

- **Type**: `oneshot` (root, for accurate failed-unit counts)
- **I/O tier**: `background`
- **startLimitBurst**: 5/300s
- **Restart**: `no` (timer is the retry mechanism)
- **Hardening**: `harden {}` + `serviceOneshotDefaults {}`

## Gotchas

- **`python3` must be in `runtimeInputs`** — The `systemd-audit` script has
  a `#!/usr/bin/env python3` shebang. Under `harden {}`, the service PATH
  doesn't include `python3` by default. Without `pkgs.python3` in
  `runtimeInputs`, the service fails with `env: 'python3': No such file or
  directory` (exit 127).
- **Exit code 1 = "issues found"** — The audit script returns non-zero when
  it detects failed services. This is expected monitoring behavior, not a
  service failure. The wrapper script uses `|| true` so systemd doesn't mark
  the oneshot as failed.
- **Timer may not fire immediately after deploy** — `OnBootSec=2min` is
  boot-based, not deploy-based. `deploy.sh` explicitly starts the service
  after activation to generate a fresh report.

## Module Options

| Option     | Default  | Description                   |
| ---------- | -------- | ----------------------------- |
| `enable`   | `false`  | Enable the service            |
| `interval` | `"5min"` | How often to re-run the audit |

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

- **systemd-timer-monitor (cappy-dev/systemd-timer-monitor)** — Read-only Python audit of systemd services+timers at `timers.home.lan`. Timer-driven oneshot (every 5 min), root user, writes `report.html` + `status.json` to `StateDirectory` served by Caddy `file_server`. LAN-only (no auth). **`python3` MUST be in `runtimeInputs`** — the `systemd-audit` script uses `#!/usr/bin/env python3`; under `harden {}` the service PATH doesn't include it by default (exit 127: `env: 'python3': No such file or directory`). **Exit code 1 = "issues found"** — the audit script returns non-zero when it detects failed services; `|| true` in the wrapper prevents systemd from marking the oneshot as failed. `deploy.sh` explicitly starts the service after activation (timer's `OnBootSec=2min` is boot-based, not deploy-based). Docs: `docs/services/systemd-timer-monitor.md`
