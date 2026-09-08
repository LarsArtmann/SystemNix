# go-taskqueue (tq) — agent pool + dashboard

**Modules:** `modules/nixos/services/tq-agent-pool.nix` (house layer) over
`inputs.go-taskqueue.nixosModules.default` (upstream `deploy/nixos/tq-agent-pool.nix`).
**Units:** `tq-agent-pool.service`, `tq-serve.service`, `tq-storage-dir.service` (oneshot), `tq-bootstrap.service` (oneshot).
**Dashboard:** `https://tq.home.lan` (protectedVHost: LAN bypass + external oauth2 forward-auth) → `127.0.0.1:8100` (`ports.tq`).
**Journal:** `/mnt/pool/services/tq/tq.db` (HDD pool subvolume, btrbk-pool snapshotted nightly; created by `tq-storage-dir`, `RequiresMountsFor`-gated).
**CLI:** `tq` on system PATH; `TQ_DB=/mnt/pool/services/tq/tq.db` is a session var for lars — `tq stats`, `tq dlq`, `tq tail -f` just work.

The pool harvests open items from `TODO_LIST.md` in `CV`, `SystemNix`,
`go-taskqueue` (poolSettings `repos`) every 5m and runs headless crush
agents against them (budget 30 enqueues/day, max 3/tick, 2 concurrent,
project-exclusive, review on — calibrated from the live round-9 dogfood
window). The model is pinned per-repo by the `.crushrc` managed block the
`tq-bootstrap` oneshot ensures at every deploy (`zai/glm-5.3-flash`,
reasoning xhigh) and commits locally (never pushes). SystemNix carries an
explicit verify gate (`--verify SystemNix=nix flake check --no-build`);
go-taskqueue keeps its own `.tq-verify`.

Dead-lettered tasks and budget exhaustion alert through the PapDashboard
bridge (`alert-url` poolSetting + `TQ_PAP_API_KEY` from the dedicated
`tq-agent-pool-env` sops template — deliberately a separate template: agent
payloads inherit the pool environment, so no other service's secrets ride
along). Gatus checks: "tq Dashboard" (functional body pattern on :8100) and
"tq Agent Pool Service" (`system_service_state_failed` via system-health;
the pool has no HTTP surface by design). Both units + tq-bootstrap are in
system-health `monitoredServices`.

**Input note:** the flake input is `git+file:///home/lars/projects/go-taskqueue`
INTERIM (upstream master is ahead of origin, owner-blocked push). Flip to
`github:LarsArtmann/go-taskqueue?ref=master` after the push lands; CI cannot
fetch git+file inputs until then. `go-nix-helpers` is deliberately not
followed (bank-sync vendorHash FOD trap).

## Cutover from the manual round-9 pool (one-time)

The pre-systemd dogfood pool ran `/tmp/tq agent-pool` + `/tmp/tq serve :8090`
against `~/projects/go-taskqueue/tasks.db`. Cutover preserves that journal:

```bash
# 1. stop the manual processes (graceful: the pool drains in-flight agents,
#    first SIGINT only signals; wait or move on — the DB copy needs quiesce)
kill -INT <agent-pool-pid> && kill <serve-pid>
# 2. deploy (creates /mnt/pool/services/tq, starts all units; tq-bootstrap
#    seeds rails in the three repos)
nix run .#deploy
# 3. carry the dogfood journal over (systemd pool must be idle: it just
#    started and only harvests after its first 5m tick — copy immediately)
sudo systemctl stop tq-agent-pool tq-serve
cp ~/projects/go-taskqueue/tasks.db /mnt/pool/services/tq/tq.db   # + -wal/-shm if present
sudo systemctl start tq-serve tq-agent-pool
# 4. verify: tq stats (facts present), dashboard at tq.home.lan, first tick
journalctl -u tq-agent-pool -f
```

Skipping step 3 is also fine — a fresh journal loses only dogfood history
and watermarks (the pool bootstraps watermarks at journal head, so nothing
replays).

## Misbehavior runbook

- **Runaway/broken agent tasks:** `systemctl stop tq-agent-pool` (SIGINT,
  in-flight agents finish within the 45min stop window; `systemctl kill`
  only if urgent). Inspect `tq stats`, `tq dlq`, `tq show <id>`.
- **Rescue a dead letter:** `tq dlq --rescue <TASK_ID> [--max-attempts N]`.
  **Cancel instead:** `tq cancel <TASK_ID> --force` (cooperative cancel of
  a running task).
- **Dedup zombie:** a cancelled task HOLDS its dedup key; to make harvest
  re-arm an item, edit the item text in the repo's TODO_LIST.md.
- **Repo refuses agents ("dirty tree"):** deliberate fail-safe
  (`allow-dirty=false`) — the PMA auto-commit daemon converges trees within
  minutes; no action needed.
- **Budget exhaustion:** alerts arrive via PapDashboard; the cap resets at
  midnight (calendar day). Raise `daily-budget` in the house module if the
  queue should burn faster.

## Rollback

`services.tq-agent-pool.enable = false` in `configuration.nix` + redeploy
( everything is enable-gated: units, vHost, DNS tile, Gatus checks, sops
template). Fallback to the non-systemd path: `tq bootstrap --install`
renders a user unit + `~/.config/tq/pool.conf` (linger), pointing at the
same journal.

## Module maintenance

- Upstream module invariants (DO NOT break): `KillSignal=SIGINT`,
  `KillMode=process`, `TimeoutStopSec=45min` (in-flight agents must finish
  and record outcomes), `ProtectSystem=full` + NO ProtectHome restriction
  (agents write/commit inside `$HOME`), `Restart=on-failure` (config errors
  rate-limit instead of looping).
- No house `harden{}` on the pool unit — same reason (ProtectHome=read-only
  would break every agent at first repo write). The serve unit IS hardened
  (`ReadWritePaths` covers the WAL/SHM siblings even for the read-only
  dashboard).
- `pool.conf` keys are agent-pool flag spellings; unknown keys fail the unit
  loudly at start (by upstream design — typos must never silently default).
  Precedence: `extraArgs` flags > environment > `poolSettings` file.
- vendorHash lives upstream (`go-standard.vendorHash`); a go.mod/go.sum bump
  needs the fakeHash dance THERE, then `nix flake lock --update-input
  go-taskqueue` here. `nix build .#tq` (quick-go batch) surfaces drift
  before a deploy.
