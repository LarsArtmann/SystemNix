# go-taskqueue (tq) — agent pool + dashboard

**Modules:** `modules/nixos/services/tq-agent-pool.nix` (house layer) over
`inputs.go-taskqueue.nixosModules.default` (upstream `deploy/nixos/tq-agent-pool.nix`).
**Units:** `tq-agent-pool.service`, `tq-serve.service`, `tq-api.service` (incident write API, :8112 loopback), `tq-storage-dir.service` (oneshot), `tq-bootstrap.service` (oneshot).
**Dashboard:** `https://tq.home.lan` (protectedVHost: LAN bypass + external oauth2 forward-auth) → `127.0.0.1:8100` (`ports.tq`).
**Journal:** `/mnt/pool/services/tq/tq.db` (HDD pool subvolume, btrbk-pool snapshotted nightly; created by `tq-storage-dir`, `RequiresMountsFor`-gated).
**CLI:** `tq` on system PATH; `TQ_DB=/mnt/pool/services/tq/tq.db` is a session var for lars — `tq stats`, `tq dlq`, `tq tail -f` just work.

The pool harvests open items from `TODO_LIST.md` in `CV`, `SystemNix`,
`go-taskqueue` (poolSettings `repos`) every 5m and runs headless crush
agents against them (budget 30 enqueues/day, max 3/tick, 2 concurrent,
project-exclusive, review on — calibrated from the live round-9 dogfood
window). **Since the 2026-09-19 TODO split, SystemNix's `TODO_LIST.md` is
the DISPATCH QUEUE only** (agent-actionable `[ready]` one-liners; the full
entries + blocked/watch/decision items live in `docs/todo/*.md` libraries —
see AGENTS.md → "TODO System"). Blocked items are deliberately outside the
harvest so agents stop being dispatched at sudo/push/browser-gated work. The model is pinned per-repo by the `.crushrc` managed block the
`tq-bootstrap` oneshot ensures at every deploy and commits locally (never
pushes): **SystemNix → `zai/glm-5.4` (flagship) @ xhigh** (2026-11-24 split,
upgraded from glm-5.3 the same day — incident-minted fix tasks target
SystemNix and get the big model; spend stays capped by `daily-budget = 30`),
**CV + go-taskqueue → `zai/glm-5.3-flash` @ xhigh**. Thinking is not a slot
flag in either tier: it rides the model declaration in the global crushrc
(`model add … --thinking always`, crush-config repo), which survives slot
routing, so the managed block only carries the reasoning effort. SystemNix
carries an explicit verify gate (`--verify SystemNix=nix flake check
--no-build`); go-taskqueue keeps its own `.tq-verify`.

Dead-lettered tasks and budget exhaustion alert through the PapDashboard
bridge (`alert-url` poolSetting + `TQ_PAP_API_KEY` from the dedicated
`tq-agent-pool-env` sops template — deliberately a separate template: agent
payloads inherit the pool environment, so no other service's secrets ride
along). Gatus checks: "tq Dashboard" (functional body pattern on :8100) and
"tq Agent Pool Service" (`system_service_state_failed` via system-health;
the pool has no HTTP surface by design). Both units + tq-bootstrap are in
system-health `monitoredServices`.

**Input note:** the flake input is `github:LarsArtmann/go-taskqueue?ref=master`
(the interim `git+file://` pin was flipped 2026-09-17 once the push backlog
landed on origin). `go-nix-helpers` is deliberately not followed (bank-sync
vendorHash FOD trap).

## Incident pipeline — auto-debug (2026-11-24)

Failing gatus checks and web client errors become agent fix tasks
AUTOMATICALLY (owner request: "problems get high priority + a high-quality
model, AI agents debug them ASAP"):

```
gatus trigger ──▶ gatus-alert-relay (noise gates) ──▶ POST /api/v1/errors (tq-api :8112)
web client    ──▶ problems.home.lan/beacon.js ──▶ /report (Caddy injects Bearer) ──┘
                                      │
                                      ▼
            incident:<sha256 fingerprint> stream (error.observed facts)
                                      │  pool tick ≤ 5 min, unconditional sweeper
                                      ▼
            prio-120 agent task (first occurrence) / prio-150 (regression)
```

- **tq-api unit**: `tq api --addr 127.0.0.1:8112 --db <journal> --read-model=false`
  (upstream ADR-0008 write API; `--read-model=false` because tq-serve owns
  reads on :8100). Runs as the primary user (same journal/WAL as pool +
  serve — SQLite WAL + busy_timeout by design; watch for `database is
  locked` on first shared-write windows). Token-gated: every request needs
  `Authorization: Bearer <TQ_API_TOKEN>`; tokenless `/api/v1/healthz` → 401
  (the gatus check "tq Write API" asserts exactly that). Registry entry
  `tq-api`, subdomain `problems`, layer "none" (no direct vHost proxying —
  Caddy hand-writes the route), `noDashboardTile` by design.
- **Fingerprint** = sha256(project | kind | normalized message | top stack
  frame). The relay sends a STABLE message per endpoint
  (`Gatus health check failing: <Group/Name>`, detail in breadcrumbs) so one
  flapper stays one incident. Client-side minified-build stack churn WILL
  fragment fingerprints — accepted per ADR-0021.
- **Latency budget**: gatus failure-threshold (3 × interval) + relay gates
  (boot-grace ≤15 min, rearm 10 min; flap-collapse lossy) + pool tick ≤5 min
  ⇒ a persistent failure dispatches an agent ~10–20 min after onset.
- **Web beacon**: `https://problems.home.lan/beacon.js` (classic script,
  `data-project="<repo>"`, optional `data-endpoint` override — default
derives from the flake domain). Captures `onerror` +
  `unhandledrejection`, dedup, ≤5 events/page, `fetch keepalive`. LAN
  reporting is open (CORS on `/report`); EXTERNAL reporting dies at the
  oauth2 forward-auth gate by design — the token never reaches the browser
  (Caddy injects the Bearer server-side from the same `tq-api-env` template).
  Junk is bounded by incident dedup + `daily-budget`.
- **Token rotation** (owner, sops workflow): edit
  `platforms/nixos/secrets/tq.yaml` key `tq_api_token` via the sops editor
  (NEVER a `--set` command line), deploy — the `tq-api-env` template's
  restartUnits (tq-api, gatus-alert-relay, caddy) roll all three consumers
  in one switch. Value shape: 48-hex.
- **Synthetic-probe hygiene**: a controlled E2E mint is POST → verify →
  `tq cancel <id> --force`; cancelled tasks HOLD their dedup key, so mark
  synthetic messages `SYNTHETIC-PROBE` (never reuse a real endpoint's
  message text or you permanently pre-dedup its first real incident).

## Boot placement & PSI entry gate

The pool orders itself `After=multi-user.target` (2026-10-19, stability trio
item 1) while staying wanted-by it (upstream) — the post-gate pattern from
llama-chat/netbird-evox2-login. Why: the house `ExecStartPre` entry gate
(`maintenance-entry-gate --psi-max 30`, the freeze-19/20/21 storm protection)
REFUSES starts into a live io-PSI storm, and upstream's
`Restart=on-failure`/`RestartSec=30s` then refires until a refusal passes —
on boot 0 (2026-10-18) that loop held the boot transaction ~2min because each
auto-restart kept the unit "activating" inside multi-user.target's wait set.
Post-gate, the churn runs outside the boot; a calm boot starts the pool
seconds after the target. Two bounds keep the churn sane at ANY start
attempt: the 2026-10-14 `startLimitBurst` 40/1800s headroom (a storm longer
than ~20min still terminates with OnFailure → PapDashboard alert, pool down
until the next deploy or a manual `systemctl start` once calm) and the gate
itself (a refusal is free — no work enters the storm). Do NOT replace the
ExecStartPre gate with `ExecCondition`: a skip would silently forgo the
retry-until-calm at deploy time and leave the pool down with no refire.
Ordering + want-edge + gate are pinned by `tests/test-tq-agent-pool.nix`.

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
  re-arm an item, edit the item text in the repo's TODO_LIST.md (queue
  one-liners link into `docs/todo/*.md` — edit the library entry too so
  they cannot drift apart).
- **Repo refuses agents ("dirty tree"):** deliberate fail-safe
  (`allow-dirty=false`) — the PMA auto-commit daemon converges trees within
  minutes; no action needed.
- **Budget exhaustion:** alerts arrive via PapDashboard; the cap resets at
  midnight (calendar day). Raise `daily-budget` in the house module if the
  queue should burn faster.

## Verify-failure classification (before burning attempts)

A failed verify gate is NOT automatically a task failure. With
`maxAttempts=3`, one more environmental/slow cycle dead-letters a task that
was actually DONE — the 2026-09-25 repair-recipe item (`000001a0d686…`) was
complete since attempt 1 and burned attempts 2-3 on gate failures alone.
Classify BEFORE counting the attempt against the task:

1. **Pre-existing / environmental (gate dead at the PRE-attempt rev)** —
   the gate fails where the pre-attempt baseline already failed
   (e.g. `/run/binfmt` missing from the tmpfiles-cycle class, GC-evicted
   flake-input sources, stale nix-daemon fetch cache). → **Gate-dead
   holding state + alert; NOT a task failure.** Probe order:
   `/run/binfmt` exists → `nix flake check --no-build` at clean HEAD
   (pre-existing vs introduced) → nix-daemon restart (stale-fetch class).
2. **Deadline-timeout-with-progress** — the verify died on the queue's
   time budget while the evaluation was ADVANCING (signature:
   `context deadline exceeded` with exit_code 0; tq fact 6663: attempt 2
   killed 30 min after claim, mid-`checks.lsblk-column-names`, under
   ~50-56% IO PSI). The measured verify budget is ~30 min (2026-09-25); a
   cold eval cache under an IO storm exceeds it. → **Gate-slow; retry with
   a warm eval cache; NOT a task failure.**
3. **Introduced** — the gate fails where the pre-attempt baseline PASSED.
   → The ONLY shape that counts against the task's attempt budget.

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
- **Crush-server flip (STAGED 2026-11-01, not active)**: routing every
  agent turn through a pool-owned `crush server` ships upstream
  (`crushServerSocket` option + keeper supervisor + `[crush-server]`
  no-burn death class + prompt-baked verdict/ask rails, all pinned by
  two zero-spend smokes). The staged line sits commented in
  `modules/nixos/services/tq-agent-pool.nix` — activate it IN THE SAME
  change as the `nix flake lock --update-input go-taskqueue` that moves
  past 2026-11-01 (version-coupling rule above), then watch ONE routed
  wave: `tq tasks` (attempts sane), `tq dlq` (empty, or rows carrying
  `[crush-server]` that re-ran cleanly), closeout reports carry verdict
  facts, dashboard `/agents/live` pane shows live turns. Rollback =
  remove the line (in-process runs return, zero residue); `tq doctor`
  WARNs if host crush ≠ the smokes-proven pin. L4 fleet ruling sheet:
  go-taskqueue `docs/planning/2026-11-01_19-50_L4-FLEET-GO-NO-GO-SHEET.md`.

---

## Agent Notes (migrated from AGENTS.md 2026-10-01)

Knowledge below moved verbatim from the root AGENTS.md restructure — it is the authoritative deep context for this service.

### tq Agent Pool (go-taskqueue dogfood, 2026-09-08)

**Modules:** house `modules/nixos/services/tq-agent-pool.nix` over upstream `inputs.go-taskqueue.nixosModules.default` — units `tq-agent-pool` (harvest + headless crush agents over CV/SystemNix/go-taskqueue TODO_LISTs), `tq-serve` (read-only dashboard, `tq.home.lan` Layer 2, `ports.tq` 8100), `tq-storage-dir` (pool-gated subvol), `tq-bootstrap` (seeds `.tq-verify`/`.crushrc` rails, commits them, never pushes). Journal on `/mnt/pool/services/tq/tq.db` (btrbk-pool snapshotted); CLI on PATH with `TQ_DB` session var. Runbook incl. the round-9 manual-pool cutover: `docs/services/tq.md`.

- **Pool unit hardening is upstream-owned and deliberately looser than `harden{}`**: `ProtectSystem=full`, NO ProtectHome restriction, `KillSignal=SIGINT` + `KillMode=process` + `TimeoutStopSec=45min` (in-flight agents must finish; a shared drain deadline strands tasks in `running` forever). Never wrap the pool in `harden{}` (ProtectHome=read-only kills every agent at first repo write); the serve unit IS hardened (ReadWritePaths covers SQLite WAL/SHM for the read-only dashboard).
- **Runs as the primary user** (browser-history-agent precedent): agents commit in `~/projects` with that user's git identity + crush config. Model pinned per-repo by the `.crushrc` managed block (SystemNix: `zai/glm-5.4` @ xhigh, thinking via the global crushrc model declaration; CV/go-taskqueue: `zai/glm-5.3-flash` @ xhigh) — a pool-level `--model` would RESET reasoning effort (upstream bootstrap.go comment); budget 30/day + max-per-tick 3 cap spend.
- **PapDashboard bridge key rides a DEDICATED sops template** (`tq-agent-pool-env`, root-owned): agent payloads inherit the pool env, so sharing `papdashboard-env`/`gatus-env` would leak other services' secrets into every agent process tree.
- **Flake input flipped to `github:LarsArtmann/go-taskqueue?ref=master` (2026-09-18, deployed gen 784)** — the interim `git+file:?rev=1a4eb480` pin is GONE: upstream push landed, CI can fetch, `nix flake lock --update-input go-taskqueue` works (live `tq 0.3.0, go1.27.1`). `go-nix-helpers` NOT followed (bank-sync vendorHash FOD trap). vendorHash refresh dances happen UPSTREAM (`nix build .#tq` in the quick-go batch surfaces drift pre-deploy).
- **pool.conf typos fail loudly** at unit start (upstream design: unknown key = error, never silent default) → start-limit + onFailure alert. Misbehavior runbook (stop → `tq dlq` → rescue/cancel), rollback, and watermarks: `docs/services/tq.md`. **2026-10-07 incident, upgrade of the rule:** this is not just about typos — every poolSettings key is VERSION-COUPLED to the locked tq binary. Landing a key for a future tq (the `done-preflight` gate went in 2026-10-06 23:57, "takes effect at the next input bump") crash-looped the pool at the very next deploy (02:01 `unknown key "done-preflight"`, 5 restarts → start-limit-hit, service-health-check red via its `systemctl --failed` catch-all). Gate keys land in the SAME commit as the flake.lock bump that ships them — never earlier. Key removed same day; re-add queued in the post-push consumption row (TODO_LIST.md → docs/todo/upstream.md).
