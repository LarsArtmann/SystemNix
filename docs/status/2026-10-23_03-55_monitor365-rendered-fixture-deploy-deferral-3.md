# Monitor365 rendered fixture + third deploy-deferral window (2026-10-23 03:55)

Follow-up session to `2026-10-23_02-00_monitor365-event-volume-fix-batch-self-review.md` and the executed `docs/planning/2026-10-23_02-26_SUPERB-monitor365-closeout-hardening.md` (deploy leg M8 still open).

## Shipped: the rendered-artifact fixture (row 446, `eb003d4a9`)

The 02:4x close-out of the retention fixture covered only the REPO file
(`checks.monitor365-retention-selftest`); the row's original ask — execute
the RENDERED `writeShellApplication` output — was still open, and that is
exactly the surface eval cannot see (the `vacuumHeadroomBytes` bare-var
class). Closed as `checks.monitor365-retention-rendered` (flake/parts/checks/selftests.nix):

1. Builds the REAL backup script via the evo-x2 config (`systemd.services.monitor365-server-backup.serviceConfig.ExecStart`) — the same rendered store artifact the 03:00 unit runs.
2. Asserts the rendered call-site contract: `RETENTION_DAYS` / `VACUUM_INTERVAL_S` / `VACUUM_HEADROOM_B` render as quoted numerics; zero uninterpolated Nix (`[$]{` scan) survives rendering; the referenced retention wrapper carries its own duckdb runtimeInput.
3. Executes the rendered retention script through the same 6-leg / 12-assert toy-DB harness (`MONITOR365_RETENTION_SCRIPT` override added to `scripts/test-monitor365-retention.sh`).

Evidence: in-check run green (nix log: ALL 12 PASS), standalone re-execution
against the store wrapper green ×2, `nix flake check --no-build` green,
shellcheck (pre-commit parity invocation) green. The fixture's first run
caught a real assertion bug (store-dir names never contain `/duckdb`; regex
fixed to the store-path form) — the check is live, not decorative.

## Verified: tonight's 03:00 fire (OLD script — pre-deploy baseline)

03:00:00 → 03:03:59 clean: 6.1 GB memory peak, 10.1 GB read, 6.5 GB written,
backup `monitor365.duckdb.backup_20261023T010003Z.db`, server revived by the
EXIT trap, unit inactive after. No WARNs. Old script = no retention leg, as
expected.

## Deploy: deferred a THIRD time — gate held (row stays armed)

- 01:42–02:00: some avg10 62–67% (prior session)
- 02:49: transient 32% lull, not sustained; avg60 back to 74%
- 02:56 (session start): avg10 32.4
- 03:18–03:51 (27 samples): some avg10 61–87, full avg10 51–81 — monotonically hostile

Per-cgroup attribution (io.pressure): the storm lives entirely in
`user.slice` (full 68) → three `app-niri-ghostty-*.scope` terminals
(~70–77 full each) — the owner-ruled interactive-battery class, never
swept. `system.slice` total 3.3; `nix-daemon` 0.00; **monitor365-server
0.00** (the volume-fix case against monitor365 remains airtight).

A deploy into an 80+% full-stall window risks the wedged-switch class; the
plan's guard #3 holds. Cost: one more day of OLD-script backups (harmless —
verified above).

Pre-deploy rendered-TOML baseline captured for the post-deploy spot-check
(`/nix/store/h97k1y47…-monitor365-config.toml`): `[collectors.keystrokes]
enabled = true`, `[collectors.mouse] enabled = true`,
`[collectors.fs_event] interval_seconds = 1`. Post-deploy expect
`false` / `false` / `60` at a NEW store path (extraction path pre-verified:
unit → `monitor365-start` wrapper → config path grep).

## Standing state (unchanged)

- Agent still owner-stopped (2026-10-21 03:10) — collector cuts inert until owner restart.
- 90 d retention window stands (owner confirm queued).
- First post-deploy 03:00 fire expectations: `monitor365-retention:` journal lines, DELETE boundary ≈ Apr–Jul events, rows-remaining count, VACUUM 25.1 GB → ~7–10 GB, window runs long ONCE.

## Harvest

Deliberately not harvested: no new follow-ups — the deploy watch row, first-fire
row, and owner gates all already exist (TODO_LIST :444/:445, docs/todo/services.md
:729; both surfaces extended this session with the third-window readings and the
rendered-fixture note).
