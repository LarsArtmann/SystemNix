# Monitor365 IO Storm — Root Cause, Quiesce Verification, SystemNix Fix (Part 3)

**Reported:** 2026-10-26 23:43 CET · **Instance:** third session tonight (directive: "review what takes so much I/O" after Part 2's attribution)
**HEAD at report time:** `ac4f9dc3a` + this session's commits · **Deployed:** gen-954 (22:55, the 22:55 "reboot" was this deploy, not a crash)

## The answer

The storm's full mechanism is now SOLVED and its fuel line is CUT — but by quiesce, not yet by fix. Independent review this session (source-read at the deployed rev `77b4a3ae` + live journal/busctl) converged with a PARALLEL session's deeper analysis (found mid-flight in `~/projects/monitor365/docs/status/2026-10-26_23-24_live-io-storm-root-cause-and-fixes.md` — the 10-second status-report pre-read rule caught it before I duplicated their repo work).

**The chain (all evidence-backed):** agent `batch_size=100` (upstream init/pair default) → 500 POSTs per sync cycle → each POST runs a `MAX(sequence)` full-table scan over ~200M events rows (index unused, 1.4–2.6 s each) → DuckDB pool (5) exhausts → uploads 500 → **380M-event backlog never acks → retries forever**. Layered on top: gen_* migrations never applied (DuckDB can't ADD generated columns post-creation; failures log at DEBUG → weeks of invisible Binder Errors every 5 min), watchdog restart churn (33/24h; each start re-fires the startup full MV refresh because `cleanup_cycle` seeds at 0 — my independent source find), dmesg SIGSYS coredump/min, xdotool ERROR/30s.

## What this session did

1. **Journal forensics** — restart-cycling proven from PID churn (6 PIDs in 90 min, all `status=9/KILL`); watchdog journal shows the kill-loop driver (`health check failed (HTTP 000000) — restarting server`); SEV1 bridge flagged `UNIT CRASH LOOP` 23:09.
2. **Source-read at the DEPLOYED rev** (local HEAD ≠ lock rev — caught before reading the wrong code): `cleanup_cycle=0` startup full refresh (`background.rs:162` + `materialized_views.rs:200` full-table COUNT), `gen_app` = generated column whose migrations can never apply, batch_size option located (settings.nix `ints.between 1 10000, default 100`).
3. **Quiesce verified, actor attributed** — watchdog timer explicitly stopped 23:10:48, server killed 23:11:04, agent inactive: a deliberate safe-order quiesce by the owner/another session (NOT this instance). Live 20s cgroup delta post-quiesce: **0.0 MB IO across every unit** (sampler sanity-checked top-5-unconditional first, per the quote-scrutiny rule).
4. **SystemNix fix landed** — `batch_size = lib.mkDefault 5000` in `modules/nixos/services/monitor365.nix` (request amplification ÷50; eval-verified `5000`; inert until the agent starts — correct posture).
5. **Docs** — runbook section (state + do-not-restart warning + ship path), scan-storm row → `[blocked:push]` ship-path row (services.md + TODO_LIST twins), new upstream row for the `cleanup_cycle` startup-refresh fix.

## Coordination flags

- **Parallel session owns the monitor365 repo RIGHT NOW** — five fixes implemented, verification gates in progress, unpushed (origin/master == deployed `77b4a3ae`; local ahead 6). I did NOT touch that repo. The SystemNix deploy is `[blocked:push]` on their gates.
- **Third session deployed gen-954 22:55** (gitea-runner ordering fix) — explains the 22:55 reboot; their runner-row edit sat uncommitted in services.md and rides this session's services.md commit (attribution noted).
- Carried unverified: fastflowlm "started ≠ serving"; the pre/post-deploy failed-unit reconciliation — still queued.

## Next

1. Upstream session: finish gates → push (their §8.1–15).
2. Then SystemNix: `nix flake lock` bump to the pushed rev → `nix run .#deploy` → post-deploy verify (pool errors must stay 0, journal clean).
3. Owner decisions before un-quiesce: agent restart timing (380M backlog drain class), max_events_per_day cap value (250k/day recommended, still unverified live), DuckDB relocation (separate).
