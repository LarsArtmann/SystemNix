# Health-hub federation session — brutal self-review + full status

**Date:** 2026-11-02, session ~04:30→06:00 CEST (report at 05:58)
**Base request:** "health.home.lan still has very little registered services, like 1 WHY!?!??" → follow-up "Do we have some auto discover e.g. via DNS?" → this review.
**Scope of this report:** THIS session only, per instruction. No new research.
**My commits:** `1f4956d6b` (module sweep, daemon-swept), `644be6d59` (8-remote list, daemon-swept), `3fbb45e7d` (docs, amended daemon sweep), `35497cbd6` (prior status report + [blocked:deploy] row).

---

## a) FULLY DONE

1. **Root cause identified and proven** — `services.health-dashboard.remotes` held only CV because it embodied the 2026-09-22 fleet inventory ("NO other fleet service speaks go-health"), which went stale as five services adopted go-health v0.8.x over five weeks. Nothing obligated anyone to re-probe: the failure mode was a manual inventory with no guard.
2. **Full-registry live sweep executed** — all 77 `lib/ports.nix` ports probed (`/health`, `/readyz`, `/healthz`, `Accept: application/json`; go-health discriminator = status pass/warn/fail/off AND a checks object). Found **8 speakers**: cv (:8098), discordsync (:8085), renamer (:8086), renamer-watcher (:8089), tq (:8100), pma (:9420/readyz), dnsblockd (:9090/readyz), nsfw (:8104). Every federated URL live-verified HTTP 200 + go-health JSON (federation hard-requires 200 — non-200 becomes a `name/reachable` FAIL row; source-verified in go-health `federation/federation.go:415`).
3. **All 8 remotes wired** in `platforms/nixos/system/configuration.nix` (interpolated `ports.*` names, zero literals — port-registry-audit clean by construction).
4. **Autodiscovery question answered + the structural fix shipped** — DNS/SRV discovery: NO (records derive from the platform catalog, but the catalog has no health-protocol marker and the hub takes a static `HEALTH_HUB_REMOTES` env; blind derivation would federate every custom-JSON service into permanent FAIL rows). Shipped instead: `health-dashboard-rediscover` — daily oneshot (15m after boot, 24h, Persistent), re-runs the exact sweep minus the hub itself (self-federation recurses), FAILS via `onFailure` with the exact remotes line to add. Refused/4xx/undecodable bodies are skipped → the only failure mode is positive go-health evidence; no false-positive class by construction.
5. **Sweep logic validated live, mutation-style** — (i) mutation run: CV removed from the federated set → exactly 1 DRIFT naming CV; (ii) production run: 8 federated → clean exit, only the hub itself (excluded by design in the module) appears; (iii) discriminator proven against every fleet body class: `"ok"`/`"up"`/`"ready"`/`"healthy"` statuses, HTML catch-alls (geometrikks), rate-limited 429 (monitor365), 401 (papdashboard) — all correctly rejected.
6. **Module eval PROVEN green outside the blocked host eval** — standalone `eval-config` (catalog + integration stub + my module): `ExecStart` renders to a real store path, `Environment` renders correctly, `Type=oneshot`, timer `24h`. This bypasses nothing — it is the AGENTS-sanctioned throwaway-eval verification pattern, never touching the tree or the gated host assembly.
7. **The rediscover script ARTIFACT fully build- and runtime-proven (upgraded from (b) at 06:0x)** — a throwaway toplevel carrying the module BUILT green (writeShellApplication's checkPhase = shellcheck on the real hand-escaped Nix string — passed), and the REAL built binary (`/nix/store/34hk9scp…-health-dashboard-rediscover`) was RUN against the live fleet: with only CV baked into its test-config federated set, it found EXACTLY the other 7 speakers (all 7 now in my remotes list), each with the copy-paste `remotes` line, exit 1. Escaping, jq discriminator, port comparison, hub self-exclusion: verified in the actual artifact, not a replica. Harness iteration cost: 4 attempts (missing catalog co-import, the documented options?-guard trap, boot stubs, integration-stub `enable` option) — see (d)-5.
8. **Docs landed** — runbook rewritten (speaker table + sweep section + autodiscovery answer), 2026-09-22 [decision] row closed with the sweep verdict, CHANGELOG entry, session status report, [blocked:deploy] verification row queued.
9. **Multi-agent discipline held** — read the parallel sessions' status reports BEFORE acting (the 04-20 CV-warn report changed my deploy plan); never co-touched their files (the in-flight `platforms/nixos/secrets/cv.yaml` stayed untouched via pathspec commits); both daemon-swept code commits verified single-file-content before amend.

## b) PARTIALLY DONE

1. **Deploy not executed** — blocked by the parallel float-repair wave (monitor365/project-discovery-daemon/vision-review-agent registry drift fails every evo-x2 host eval — THEIR commits, their active work, documented in their 04-20 report). The armed watcher (`watch-and-deploy2.sh`, PID 3155131) fires on eval-green + quiescence and carries my whole tree. My [blocked:deploy] checklist covers the post-deploy half. Everything code-side is proven (see a-6/a-7); only the switch itself is pending.
2. **Fetch-load decision deferred** — 8 remotes × 2s merge-on-read ≈ 345k loopback req/day total, ~43k/day per remote service. All reads hit atomic-cached state upstream (cheap by design), and CV already ran this cadence alone for weeks — but the 2s-vs-30s [decision] row is now live data it never had. Flagged in the checklist, not decided (not mine to decide).

## c) NOT STARTED

1. Post-deploy verification battery (8 cards visible, sweep exits 0, federation Gatus check green with tq's warn rows present, anchor discipline) — queued, deploy-gated.
2. Wiring `HEALTH_HUB_TIMEOUT`/push-interval as module options (the parked [ready] row) — upstream binary gap first.
3. Any upstream work (go-health-dashboard: cadence option, DNS/SRV discovery if ever wanted; go-health: nothing needed).

## d) TOTALLY FUCKED UP (honest ledger)

1. **`rg -rn` typed TWICE in my opening tool calls** — the exact replace-mode trap documented in SystemNix AGENTS as "third strike on this host"; the hook caught both. My strikes are now on that tally. I read the rule AFTER firing, not before.
2. **`curl` blocked, then `awk -match` (invalid flag), then a sed that ate `; do`** — three broken one-liners in five tool calls, each a wasted round trip. The curl block is ALSO pre-documented in AGENTS; I re-derived it empirically.
3. **Shipped an overclaiming intermediate state** — my first remotes edit (5 entries, daemon commit `cf3ae039c`) carried the comment "Remotes = the fleet's go-health speakers, live-re-probed 2026-11-02" while I had probed only a ~19-port SHORTLIST from memory. The claim was false at that moment; the full-registry sweep corrected it minutes later. Immutable history now contains it. Root cause: I enumerated candidates from MEMORY of ports.nix instead of from ports.nix itself.
4. **First probe missed 3 of 8 speakers** (dnsblockd :9090, renamer-watcher :8089, nsfw :8104) — same root cause as (3). Had I not built the full-registry harness for the module, I would have shipped a confident 5-remote answer to a "WHY is it incomplete" question. This is the session's scariest near-miss: the error class was exactly the one I was fixing.
5. **Re-hit a documented module gotcha** — my first standalone eval failed on the `options ? services.integration` guard because the 2026-09-15 VM-test note ("the options?-guard does NOT survive an enclosing mkIf with enable=true") applies to my harness too. I debugged it instead of grepping the docs first.

## e) WHAT WE SHOULD IMPROVE (systemic, from this session's evidence)

1. **Registry-first enumeration** — any "what speaks X on this host" question must start from `lib/ports.nix` (or the catalog), never from a hand-typed shortlist. This session is the proof: hand-list 5, registry 8. The rediscover sweep mechanizes it for go-health; the LESSON generalizes to every protocol probe.
2. **Guard stale inventories structurally, not prose-ly** — the 2026-09-22 "nobody else speaks go-health" claim survived five weeks in three surfaces (config comment, runbook, TODO row) with no mechanical challenge. Sweep-style runtime guards (fail-loudly on drift) beat doc freshness every time. Candidate for a fleet pattern: one sweep unit per "inventory that can silently rot".
3. **Status-report pre-read worked — keep it** — reading the parallel session's 04-20 report before acting saved me from colliding with the float wave and from re-triaging CV's warns. This discipline is earning its cost.
4. **The TODO-gate `--no-verify` path needs its triage row prioritized** — I now have three same-day precedents (64472a8ef, my 3fbb45e7d, this report's commits). Every session pays the disclosure tax; the gate hard-fails for everyone (161 unharvested reports).
5. **Nix string escaping in unit scripts deserves a build-gate habit** — hand-escaped `''${}` bash inside writeShellApplication should get a standalone build before the shared window whenever the host eval is blocked (this session: done retroactively in background).

## f) Up to 50 things to get done next (session-scoped, ranked by impact)

**Deploy-gated (rides the shared window):**
1. Post-deploy: verify 8 cards at health.home.lan, no `*/reachable` rows.
2. Post-deploy: `systemctl start health-dashboard-rediscover` exits 0; timer armed (`list-timers`).
3. Post-deploy: Gatus "Health Hub Federation" green with tq's warn rows present (warn≠fail proof).
4. Post-deploy: anchor discipline (`readlink /run/current-system` == newest `system-N-link`) + `pre-reboot-check` if any reboot planned.
5. ~~Confirm the background throwaway toplevel build (script shellcheck) result~~ DONE 06:0x — build green AND the real binary run live (see a-7); zero residual.
6. Watch the federation check's RESPONSE_TIME for a week — 8 remotes × 5s worst-case deadline stays under the 8s condition; revisit if storms push it.

**Hub/federation hardening:**
7. Decide the cadence row (2s vs 30s/1m) with the new 8-remote load data; if 30s, needs upstream `WithPushInterval` exposure in health-hub env wiring first.
8. Expose `fetchTimeout` as a module option (the parked [ready] row) once (7) is decided.
9. Consider `WithMaxSSEConnections` + `WithRateLimit` for the hub vHost (the parked hardening [decision] row) — now that the hub is a fleet centerpiece.
10. Consider `WithWebhook` → Discord transition pushes (same parked row).
11. Revisit the pma/dnsblockd path choice AFTER a real fail: does the 503→`reachable FAIL` display lose check-level detail vs a `/health` route? (Both 503 on fail today; only observability of the failing check name differs.)
12. Upstream (go-health-dashboard): document the `remotes` naming constraints next to the env var in the health-hub README (the module had to re-document them).
13. Upstream (go-health-dashboard): consider a `--remotes-file` or SRV discovery hook if the fleet grows past ~12 remotes (config-line length is fine today at ~250 chars).

**Fleet go-health adoption (the 9th+ speaker pipeline):**
14. browser-history: closest candidate — already has a checks-shaped object with custom statuses; adopting go-health upstream is likely a small change.
15. gatusAlertRelay: custom JSON, single object — trivial go-health port.
16. bank-sync / papdashboard / media-atlas: all `{"status":"up"}` — one shared go-health wiring each.
17. monitor365: custom health JSON + a 429-rate-limited `/healthz` — if it ever adopts go-health, exempt the hub's fetches from the limiter or it will flap.
18. overview / geometrikks / inboxclean: custom JSON surfaces; adoption is upstream work per service.
19. Make "adopt go-health" a deliberate fleet directive or keep opt-in (owner policy — see question 2).
20. tq: 515 dead-lettered tasks surfaced by my probe (its own /health says `dlq: warn`) — dispatch a tq dlq triage (NOT hub work, but the hub now makes it visible daily).

**nsfw-classifier stability (noticed via TODO row 290 + my probe):**
21. nsfw answered `pass` at 05:10 but the 2026-10-31 owner stop batch calls it sick (503s, 192% CPU, 98°C) and the deploy re-armed it — reconcile: recovered or flapping? (The hub will now surface this honestly either way.)
22. Its 8104 card will page via the aggregate readyz if it fails — decide if that's wanted while its stability verdict is open.

**Housekeeping from this session:**
23. Close the (b)-1 build proof once the background job lands (update this report's appendix, not a new file).
24. Sweep the runbook speaker table's freshness when the 9th speaker arrives — the sweep unit's failure message points at configuration.nix, add "update the runbook table" to that message (one-line script change).
25. Consider a tiny eval-time assertion: every remote URL's port ∈ lib/ports.nix (catches typos in remotes; port-registry-audit only reads unit text, and the URLs ride an env var it does parse — verify it actually catches a bad port before claiming the gap).
26. SystemNix: the jq-direnv and rg-r traps now have fresh strike evidence — candidates for the hook to auto-correct instead of block-and-lecture (the rg hook already does this well; jq remains trap-y).
27. This session re-proved "read the runbook BEFORE the module" — the health-dashboard runbook's stale section was the fastest possible root-cause anchor; keep runbooks authoritative when they carry dated inventories (they rot; sweeps don't).

**Wider observations parked (NOT auto-harvested — owner triage):**
28. CV's 2 remaining warns (database, graphrag) await the parallel session's owner decisions — visible daily on the hub now.
29. The parallel float wave's three drifted inputs block EVERY host eval — the fleet's single biggest deploy friction this week.
30. monitor365's aggressive healthz rate-limiting (429 within ~2 probes from one client) would starve any naive federator — worth an upstream note if it adopts go-health.
31. `expected-locks.nix` re-registration is the float-repair endgame; until then the armed watcher holds the whole fleet's deploys (including two sessions' in-tree fixes).
32–50. RESERVED — no padding. 31 real items; inventing 19 more would be the brainstorm anti-pattern the status-report skill warns about (larger N is ROADMAP fuel, not commitment). Harvest rigor applies to 1–31, not to synthetic filler.

## g) Questions I can NOT figure out myself

1. **Hub cadence policy:** with 8 remotes (soon more), is near-live 2s freshness worth ~43k loopback req/day per service, or should the hub drop to 30s/1m (needs one upstream env exposure first)? This is a freshness-vs-noise preference — yours, and the parked [decision] row is now unblocked for data but not for preference.
2. **nsfw-classifier intent:** the 2026-10-31 batch says you stopped it as sick; the deploy re-armed it and it answers `pass` now. Keep it federated on the hub (its flaps become visible pages — my default), or hold it out until you've settled its stability verdict?
3. **go-health as fleet standard:** should "adopt go-health" become a standing directive for every LarsArtmann service (I'd file per-repo upstream TODOs — ~8 candidates listed in f14–18), or is hub membership deliberately opt-in per service?

---

## Appendix: verification evidence pointers

- Live sweep harness + runs: `~/.cache/health-hub-rediscover-test/run-all.sh` (registry-wide), mutation + production outputs in session log.
- Standalone module eval (green): ExecStart `/nix/store/34hk9scpx13p5vyqi7ncwkshlj43zx8m-health-dashboard-rediscover/bin/health-dashboard-rediscover`, env `HEALTH_HUB_REMOTES=cv=...`, `Type=oneshot`, timer `24h`.
- REAL-artifact runtime proof: the built binary (test-config remotes = cv only) run against the live fleet reports EXACTLY the 7 other speakers with remediation lines, exit 1 — the production module bakes all 8 remotes, so the deployed sweep exits 0 (harness-verified equivalence).
- Throwaway toplevel build: green (script shellcheck passed inside checkPhase); harness stubs needed: catalog co-import, integration stub with per-entry `enable`, boot/fileSystems stubs.
- Federation 200-requirement: go-health `federation/federation.go:415-422`.
- Parallel-session context: `docs/status/2026-11-02_04-20_health-hub-cv-warns-fix-session.md` (watcher, wave, deploy gates).
