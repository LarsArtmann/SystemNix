# Monitor365 Data-Governance Batch — Executed, Deploy Force-Deferred (2026-10-23 07:55)

Plan: `docs/planning/2026-10-23_07-05_SUPERB-monitor365-data-governance.md` (EXECUTED marker).
Owner steer implemented: right data at right intervals; IO/s over storage.

## Shipped (pushed through 1d2583c39 + close-out)

1. **Cadence set LIVE in-tree** (`configuration.nix`, inert until owner restarts the agent): process 5 s sampling, network/battery 300 s, location 900 s — only the collectors the module defaults left realtime/unbounded; sane defaults untouched; human-paced collectors realtime by decision. Scoped evals verified (5/300/300/900/60, mouse/keystrokes false). Cloud sync/batch pin DROPPED after verifying the live TOML already renders `[cloud] sync 60 / batch 100` — zero-effect pins are surface, not safety.
2. **Governor doctrine pinned in-config + runbook**: tenant daily cap (10 k default, 1 B post-drain, admin-JWT-gated — live-probed: `/health` is the only unauthenticated route) must be restored by the OWNER before any agent restart; rec 250 k/day. Cap-without-cadence = the 113-day/597M buffer balloon; documented at every surface.
3. **Upstream rows (4)**: bounded offline queue (drop-oldest + dropped-counter), environ opt-in/once-per-app (bulk + secrets-in-DB smell), rollup tables (the retention endgame), cap + daily-usage observability in the admin API.
4. **Lock-audit red HEALED in-scope**: papdashboard's treefmt-nix follows was flat against a nested-only input — replaced with the nested attrpath form (4cf457561, flake.lock byte-identical; the "override for a non-existent input" warning dies with it).

## Forced-defer: the deploy is DOUBLE-blocked

- **PSI**: 61–87 avg10 through the night; 29.4 at 07:5x (finally dipping — irrelevant now, see next).
- **Foreign blanket-wave eval red** (three lock waves tonight, hermes a4072ce→bf0203a among them): `nix build .#nixosConfigurations.evo-x2…toplevel` fails on (1) the documented hermes-python IFD class and (2) a crowdsec module arriving from an UNFETCHED nixpkgs source (root nixpkgs unchanged — a moved input's nixosModules walk their own pin) whose restructured `settings` submodule conflicts with our `settings.general`. deploy.sh validation would fail. Both documented with remediation paths in the pipeline lock-heal [decision] row; flake.lock stays sacred to this batch — reconciliation needs the owner's call (this session on your word, or the wave-owning session).

## Verification ledger

- Cadence evals: 5/300/300/900/60 + cuts confirmed (scoped eval — full check is wave-red, foreign).
- Probe: monitor.home.lan (192.168.1.150) — /health 200, all admin/tenant paths 404 behind JWT → owner-gated cap verification, row updated.
- Tonight's 03:00 (old script) already verified clean earlier; next fire 2026-10-24 03:00 runs old script again until deploy + both blockers clear.

## Standing owner gates (unchanged + one new)

1. Restore the tenant cap (rec 250 k/day) BEFORE restarting the agent — admin API/sudo.
2. Agent restart after cap + buffer-backlog measurement (sudo du, row exists).
3. Lock-wave reconciliation ownership: my word → I execute the documented hermes rollback + crowdsec source fix; else the wave-owning session.
