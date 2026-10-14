# thermal-pstate-guard

**Module:** `modules/nixos/services/thermal-pstate-guard.nix` (`services.thermal-pstate-guard`)
**Script (single source of truth):** `scripts/thermal-pstate-guard.sh` — embedded into the unit via `builtins.readFile`, fixture-tested by `checks.thermal-pstate-guard-selftest` and pre-commit shellcheck.
**Enabled:** `platforms/nixos/system/configuration.nix` (evo-x2).
**Created:** 2026-10-04, freeze #14 session — the freeze #8–#14 thermal-ceiling family's enforcement leg.

## What it does

Flips the `amd_pstate` driver mode on thermal hysteresis, every 10 s tick (oneshot + timer, the memory-emergency-guard pattern):

| State         | Driver mode | Governor/EPP                           | Entered when                                 | Left when                                                            |
| ------------- | ----------- | -------------------------------------- | -------------------------------------------- | -------------------------------------------------------------------- |
| **normal**    | `active`    | performance + performance (max clocks) | default                                      | any sensor ≥ its high for 2 consecutive ticks → **guided**           |
| **throttled** | `guided`    | (firmware-managed)                     | transition snapshots governor/EPP per policy | ALL sensors ≤ their low for 12 consecutive ticks → snapshot restored |
| **deep-throttled** | `guided` + `scaling_max_freq` capped to 60% per policy | heat stays ≥ the high threshold 6 more ticks IN guided → max-freq snapshot + cap (first rung alone held 96–99 °C through freezes #16/#17) | heat breaks below the high threshold (middle/cool band), exit to active, or external override → maxima restored |

Default sensors (`services.thermal-pstate-guard.sensors`): k10temp 95/80 °C, nvme 70/60, amdgpu 90/75, acpitz 85/70. Sensors resolve by **hwmon `name`**, never by the unstable `hwmonN` index. Absent patterns never vote and increment `thermal_pstate_guard_sensors_missing`.

## Why (incident class)

Freezes #8–#14 (2026-10-01 → 10-04): Tctl pinned ~99 °C on a standing cooling deficit under the chronic zone-6 IO storm, instant EC power cut mid-traffic. The pstate configuration pinned max clocks under any load, so every storm rode the ceiling. The board exposes **no OS-side PPT control** (no ryzen_smu for Strix Halo, no RAPL, no BIOS platform profile), making the driver mode the only frequency lever. A written "no heavy builds" gate was violated within the hour it was written (freeze-14's death-minute nix burst) — this guard enforces the thermal ceiling in code.

**It does not replace the physical cooling inspection** (docs/todo/stability.md cooling row): if the firmware's guided policy is as weak as its fan control, only the inspection fixes the deficit. Zero fan telemetry + 81.5 °C at 46 W idle-ish remains the smoking gun for dead/clogged fans.

## State + metrics

- State files: `/var/lib/thermal-pstate-guard/` (`mode`, `enter-streak`, `exit-streak`, `deep-streak`, `trips`, `restores`, `deep-trips`, `throttle-log-epoch`, `governor-epp.snapshot`, `max-freq.snapshot`).
- Textfile: `thermal_pstate_guard_{throttled, deep_throttled, sensor_celsius{sensor=…}, sensors_missing, trips_total, restores_total, deep_trips_total, last_run_timestamp_seconds}` in the node_exporter textfile dir (atomic rewrite per tick; a frozen file = dead guard — the memory-guard freshness doctrine; Gatus wiring is a queued follow-up).
- Logs: transitions always; "still throttled" rate-limited to 1/600 s.

## Behavior rules

- **External-override adoption**: if sysfs mode ≠ state-file mode (operator echo, crash mid-transition), sysfs wins — the guard adopts it, resets streaks, and on adopting `active` restores the performance governor (snapshot if present, configured defaults otherwise). Never fights a human.
- **Middle band** (below high, above low): restore dwell resets silently; the second-rung frequency cap (if applied) drops — heat has broken below the rung's gate.
- **Blind guard** (no sensor matches): logs ERROR, writes metrics with `sensors_missing`, never touches the mode.
- Sysfs write failure: loud WARN/ERROR, state unchanged (no half-transitions).

## Post-deploy effectiveness criterion (2026-10-14, freeze-16/17 row)

**The guard is "mitigating" only if, while `thermal_pstate_guard_throttled == 1`, no k10temp sample reaches ≥95 °C at load.** Over any full boot: `max_over_time(thermal_pstate_guard_sensor_celsius{sensor="k10temp"}[1h])` sampled while throttled must stay <95 °C. If ≥95 °C samples persist across a whole boot even with `thermal_pstate_guard_deep_throttled == 1`, the guard is **deficit-masking, not mitigating** — the physical cooling inspection is the only remaining fix. The criterion would have flagged rung-1 insufficiency on day one of freeze #16.

## Verification

- `nix flake check` runs `thermal-pstate-guard-selftest` (fixture sysfs trees: debounce, dwell reset, snapshot restore, deep-rung cap + drop, external adoption, blind degradation — 30 assertions).
- Manual: `sudo systemctl start thermal-pstate-guard.service` then check `journalctl -u thermal-pstate-guard -n 5` and the `.prom` file.
- Live-threshold drill (post-deploy, calm window): drop k10temp thresholds in an override, watch the transition both ways, revert.

## Traps

- `amd_pstate=performance` (the pre-2026-10-04 boot param) is not a documented driver mode — the driver came up `active` regardless; the performance governor/EPP is what pins clocks. boot.nix now sets `amd_pstate=active` explicitly.
- Mode switches may reset per-policy governor/EPP — the guard always restores AFTER writing `status=active`.
- Writing `/sys/.../amd_pstate/status` requires root; the service runs as root under `harden{}` (ProtectSystem exempts /sys).
