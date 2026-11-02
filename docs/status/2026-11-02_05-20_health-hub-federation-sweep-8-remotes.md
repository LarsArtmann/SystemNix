# Health-hub federation sweep — 1 → 8 remotes, daily rediscover guard, deploy rides the shared window

**Date:** 2026-11-02, session ~04:30→05:20 CEST
**Base request:** "health.home.lan still has very little registered services, like 1 WHY!?!??" (+ follow-up: "Do we have some auto discover e.g. via DNS?")
**Commits:** 1f4956d6b (module sweep, daemon-swept), 644be6d59 (remotes list, daemon-swept), 3fbb45e7d (docs; amends the daemon's 3-file sweep).

## Verdict

The hub federated exactly ONE remote because `services.health-dashboard.remotes` was still the 2026-09-22 inventory's conclusion — "NO other fleet service speaks go-health" — and that inventory went stale as services adopted go-health v0.8.x over the following five weeks. Nobody re-probed because nothing obligated anyone to.

A live sweep over ALL 77 `lib/ports.nix` ports (Accept: application/json on /health, /readyz, /healthz; go-health = status pass/warn/fail/off AND a checks object) found EIGHT speakers — the manual port shortlist found only 5 of them; the full-registry harness found dnsblockd (:9090/readyz — the stats port serves the canonical document, not just Prometheus), renamer-watcher (:8089), and nsfw (:8104) that the first pass missed. All 8 are now in `remotes`.

## Autodiscovery answer (the follow-up question)

- **DNS: no.** `*.home.lan` records DERIVE from the platform catalog (ADR-008), but the catalog carries no health-PROTOCOL marker (its `healthPath` is generic), and the hub binary consumes a static `HEALTH_HUB_REMOTES` env. Blind derivation from `healthPath` would federate every custom-JSON service into permanent `name/reachable` FAIL rows (federation refuses non-go-health bodies by design). True DNS/SRV discovery would be an upstream health-hub feature.
- **What shipped instead:** `health-dashboard-rediscover.service` — the honest autodiscovery equivalent for this fleet. Daily oneshot (15m after boot, 24h cadence, Persistent) re-runs the exact sweep minus the hub itself (self-federation would recurse) and FAILS via `onFailure` with the exact `remotes` line to add when a registry port serves an unfederated go-health document. Connection-refused/4xx/undecodable bodies are skipped → the only failure mode is positive go-health evidence; no false-positive class exists by construction.

## Verification (pre-deploy)

- Sweep logic validated live against ALL 77 registry ports: mutation run (CV removed from federated set → 1 DRIFT naming CV) and production run (8 federated → clean exit, only the hub itself excluded by design).
- Every federated URL live-verified HTTP 200 + go-health JSON (federation requires 200; non-200 = reachable FAIL row — pma/dnsblockd wired on /readyz for exactly the canonical document).
- Both nix files format-canonical (`nix fmt --` scoped); daemon-swept commits verified single-file-content before amend.
- Full evo-x2 toplevel eval UNOBTAINABLE this session: the parallel float-repair wave's registry drift (monitor365/project-discovery-daemon/vision-review-agent) fails every host eval — their active work, not co-touched (concurrent-edit discipline). The armed deploy watcher (~/.cache/cv-deploy/watch-and-deploy2.sh, PID 3155131 at write time) gates on eval-green and will carry this whole tree.

## Post-deploy checklist (pending half)

1. `https://health.home.lan` (or 127.0.0.1:8103 with Accept: application/json) shows EIGHT cards: cv, discordsync, renamer, renamer-watcher, tq, pma, dnsblockd, nsfw — no `*/reachable` rows.
2. `systemctl list-timers health-dashboard-rediscover` armed; `systemctl start health-dashboard-rediscover` exits 0 (clean sweep with all 8 federated).
3. Gatus "Health Hub Federation" stays green (warn from tq's dlq/workers rows must NOT trip it — warn≠fail).
4. Fetch-load sanity: 8 remotes × merge-on-read at the 2s push cadence ≈ 345k loopback req/day — watch the hub's own RESPONSE_TIME on the federation check; the [decision] cadence row (2s vs 30s) becomes live data.
5. Deploy anchor discipline: readlink /run/current-system == newest system-N-link.

## Self-harvest

- docs/todo/services.md: the 2026-09-22 [decision] remotes row closed with the sweep verdict (in 3fbb45e7d).
- docs/todo/services.md: new [blocked:deploy] row — this checklist.
- Runbook rewritten (speaker table + sweep section + autodiscovery answer): docs/services/health-dashboard.md.
- CHANGELOG entry landed.
