# bun-memory-watchdog

**Module:** `modules/nixos/services/bun-memory-watchdog.nix` (`services.bun-memory-watchdog`)
**Script (single source of truth):** `scripts/bun-memory-watchdog.sh` — embedded into the unit via `builtins.readFile`, fixture-tested by `checks.bun-memory-watchdog-selftest` and pre-commit shellcheck.
**Enabled:** `platforms/nixos/system/configuration.nix` (evo-x2).
**Created:** 2026-10-10 — the `bun test` 70 GB near-freeze session's enforcement leg.

## What it does

Every 30 s tick (oneshot + timer, the memory-emergency-guard pattern), sweeps `/proc` and **SIGKILLs any process whose resolved `/proc/PID/exe` basename is `bun` once its `VmRSS` is at or above the kill threshold** (default 16 GiB, `services.bun-memory-watchdog.thresholdGiB`).

Why a sweep and not a systemd `MemoryMax`: agent sessions (Crush) spawn the qmd-mcp bun runtimes as plain user processes inside session scopes — there is no unit to cap, and a `user-1000.slice` cap would take the whole desktop down with the offender. The sweep is launcher-agnostic.

## Why (incident class)

2026-10-10: `bun test` (qmd mcp toolchain) climbed past 70 GB RSS on the 128 GB host with no natural ceiling and pushed the box toward the memory-emergency-guard's trip zone. Bun has no per-process memory ceiling of its own (`bun test` grew unbounded), so the containment is external and blunt by design: the user-facing contract is "crash kill" — a bun already past 16 GiB has nothing worth saving.

## Safety rails

- **Exact exe match only** — the resolved `/proc/PID/exe` basename must equal an entry of `services.bun-memory-watchdog.processNames` (default `["bun"]`). Never a cmdline substring, never a pattern.
- **PID-reuse guard** — the exe is re-read immediately before the kill; a PID that changed identity between scan and kill is skipped.
- **Shared accounting path** — dry-run and real kills both update the kill counter/state, so what the fixture tests is what production executes.
- **Dry-run mode** — `BUN_WATCHDOG_DRY_RUN_FILE=<file>` turns kills into append-only pid records (selftest + manual drills). The production unit never sets it.

## State + metrics

- State files: `/var/lib/bun-memory-watchdog/` (`kills.count`, `last-kill-pid`, `last-kill-rss-kb`, `last-kill-epoch`).
- Textfile: `bun_memory_watchdog_{kills_total, last_kill_pid, last_kill_rss_gib, last_kill_timestamp_seconds, last_run_timestamp_seconds}` in the node_exporter textfile dir (atomic rewrite per tick; a frozen file = dead watchdog — the memory-guard freshness doctrine; Gatus wiring is a queued follow-up, same as the thermal guard at introduction).
- Logs: every kill logs pid, RSS, cgroup, and cmdline to the journal (`KILLED bun pid=… rss=…kB cgroup=… cmd=…`); kill failures (process gone / EPERM) log loudly. Clean sweeps log one line per run.

## Behavior rules

- **Survivor re-kill**: a process that ignores SIGKILL (D-state) is killed again on every tick until it dies — intended.
- **Threshold semantics**: `>=` — a bun sitting exactly at 16 GiB is killed (fixture-tested).
- **Multiple offenders**: all over-threshold buns are killed in one sweep.
- The watchdog never kills itself: the sweep process's exe is bash, never a match.

## Verification

- `nix flake check` runs `bun-memory-watchdog-selftest` (fixture proc tree: 17 GiB bun killed, exactly-16-GiB bun killed, 15 GiB bun spared, over-threshold non-bun spared, counter accumulates across sweeps, killed pids do not re-appear — modeling real process death).
- Manual drill (no deploy needed): `BUN_WATCHDOG_DRY_RUN_FILE=/tmp/kills.txt bash scripts/bun-memory-watchdog.sh` after pointing `BUN_WATCHDOG_OUT`/`BUN_WATCHDOG_STATE_DIR` at /tmp.
