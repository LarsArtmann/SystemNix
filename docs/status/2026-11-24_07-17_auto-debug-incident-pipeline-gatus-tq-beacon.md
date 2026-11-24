# Auto-Debug Incident Pipeline: Gatus Failures + Client Errors → go-taskqueue Agent Fix Tasks — Mid-Flight Status

**Author:** Crush (glm-5.3), interactive session, 2026-11-24 ~04:30–07:17 CET
**Ask (owner):** fully automatically send all failing health checks, web client-side errors, and "basically problems" to the go-taskqueue instance with high priority + a high-quality model so AI agents debug them ASAP.
**Interrupted by:** owner status-report + WAIT instruction before the deploy/verify phase. Not yet deployed.

---

## The design that is landing (research → decision)

- **Ingestion surface already existed upstream**: go-taskqueue ADR-0021 (2026-10-08, in the locked 0.4.2) defines the incident pipeline: `tq api` exposes token-gated `POST /api/v1/errors`; the running agent pool's `incident-policy` sweeper (unconditional, `cmd/tq/main.go:1467/1584`) mints `agent` fix tasks at **hot band 120** (first occurrence) and **machine band 150** (regression), with fingerprint grouping, storm dedup (1,000 reports → 1 task), occurrence counting, and regression reopen. High priority is satisfied **by design**.
- **Gatus → tq goes THROUGH the existing gatus-alert-relay** (not a new gatus custom provider): the relay already receives every Discord-bound alert and already owns the noise gates (boot-grace 900s, SEV1 mute, flap-collapse, re-arm guard). A direct gatus→tq provider would bypass those gates and mint ~25 agent tasks per deploy reboot — exactly the storm class T-007 built the relay to kill. One gate, two sinks.
- **Report shape**: `Message` = stable `"Gatus health check failing: <Group/Name>"` (fingerprint stability = one incident per check across its lifecycle); failure detail (count, conditions, alert description lines) rides `Breadcrumbs`, which `fixPrompt` renders into the minted task's prompt. Resolves and unparseable payloads are never reported.
- **High-quality model**: upstream RETIRED the pool-level `--model` flag (a payload-level model resets crush reasoning effort; per-repo `.crushrc` managed block is the sanctioned mechanism — `cmd/tq/agentpool.go:544-551`). Therefore the SystemNix `tq-bootstrap` unit now pins **SystemNix → `zai/glm-5.3` (full) @ xhigh** while CV + go-taskqueue keep Flash. Every incident-minted task targets repo SystemNix → full model. Spend stays capped by `daily-budget = 30`. A per-incident-model upstream seam is designed and queued (§f/13) but NOT implemented.
- **Web client errors**: new `problems.home.lan` Caddy vHost (protected layer semantics): `/report` proxies to tq-api with the bearer token injected by Caddy (browser never sees it) + CORS; `/beacon.js` is an embeddable classic script (`data-project="<repo>"`) hooking `window.onerror` + `unhandledrejection`, deduped, ≤5/page. External `/report` dies at the forward-auth gate by design (sendBeacon cannot complete OAuth; an internet-open error sink would mint junk tasks). App-side adoption (embedding the script) is per-repo follow-up work.

## a) FULLY DONE (this session, in tree, verified as far as possible pre-deploy)

1. **Research**: read go-taskqueue ADR-0008/ADR-0021, `internal/incident` (Report/Clip/Fingerprint/Policy mint+fixPrompt), `cmd/tq` api/bootstrap/agentpool flags, executor `AgentPayload` (has `Model`, no `Reasoning`); SystemNix tq overlay, gatus-config custom-provider pattern, relay module+source, sops/caddy/integration-registry conventions (routing-table pre-read honored; sops skill loaded before secret work).
2. **Relay Go code** (`pkgs/gatus-alert-relay/`): new `tq.go` (`reportIfTriggered`, `buildIncidentReport`, bearer POST, 2-attempt retry, 4xx = permanent-fail log); `main.go` (`-tq-url`/`-tq-token`/`-tq-project` flags, refuse-to-start on URL-without-token, live + replay hooks, startup banner); `policy.go` (`parseAlert` now returns description lines; `tqReports`/`tqFailed` counters surfaced in `/healthz`). `go vet` clean, **`go test ./...` green** (4 new tests in `tq_test.go`: parsed-trigger POST shape/auth/message-stability, skips resolve/garbage/disabled, 4xx permanent-failure counting, breadcrumb clipping).
3. **Port**: `lib/ports.nix` → `tqApi = 8112` (8091 is taken by crm-server; 8110/8111 taken).
4. **Secret**: `platforms/nixos/secrets/tq.yaml` created (`tq_api_token`, 48-hex, plaintext existed only inside a single shell pipeline — value never in argv literals, never echoed); **decrypt round-trip verified** with the host age key (48 chars, hex).
5. **sops.nix**: `tq_api_token` secret (guarded on `tq-agent-pool` enable; restartUnits `tq-api`) + root-owned 0400 **`tq-api-env` template** (`TQ_API_TOKEN`) consumed by tq-api / gatus-alert-relay / caddy (rotation restarts all three).
6. **`tq-api` service** (overlay in `tq-agent-pool.nix`): `tq api --addr 127.0.0.1:8112 --db /mnt/pool/services/tq/tq.db --read-model=false` (serve owns the `.readmodel.db` fold lock), User=primaryUser, ReadWritePaths on the pool DB dir, harden+serviceDefaults+ioTier.background, after/wants tq-storage-dir, onFailure.
7. **Bootstrap model split** (`tq-bootstrap` oneshot, two `ExecStart` lines): CV + go-taskqueue → `zai/glm-5.3-flash`; SystemNix → `zai/glm-5.3 --reasoning xhigh` + keeps the `SystemNix=nix flake check --no-build` verify gate. Converges the `.crushrc` managed blocks on next run.
8. **Registry entry `tq-api`**: subdomain `problems`, `vHost.layer = "none"` (the beacon vHost is hand-written — token injection + CORS are not expressible in the vHost fan-out), `noDashboardTile = true` with justification, port 8112, gatus check "tq Write API" probing `:8112/api/v1/healthz` with `[STATUS] == 401` (401 = alive AND auth enforced; 000/5xx = pipeline dark) + a pointed alert text.
9. **Relay module**: conditional `-tq-url http://127.0.0.1:8112/api/v1/errors` + `tq-api-env` EnvironmentFile + after/wants `tq-api.service` (all gated on the tq pool being enabled).
10. **Caddy**: `beaconRoot` (`writeTextDir` with the full beacon.js — no `${`/`''` collisions); `problems.home.lan` vHost with source-order-sensitive route chain (preflight 204 → `@external` forward-auth gate → `/report` CORS+token-injected proxy → `/beacon.js` static → info catch-all), `# proxy-port:8112` stamp (post-deploy smoke classifies it protected with backend-skip); caddy unit gains the `tq-api-env` EnvironmentFile.
11. **DNS**: `"problems"` added to `localSubdomains` (registry↔DNS assertion satisfied).
12. **Targeted evals GREEN** (full toplevel blocked by foreign breakage, see §d): `tq-api` ExecStart renders exactly right; relay ExecStart carries `-tq-url …:8112/api/v1/errors`; EnvironmentFile renders `/run/secrets/rendered/tq-api-env`.

## b) PARTIALLY DONE

- **Eval verification**: my surfaces prove out via targeted option evals; the **full `nix flake check`/toplevel build has NOT run** (blocked, §d). Relay **nix package build** (buildGo126Module `doCheck` re-runs the tests in-build) not yet run.
- **Docs**: no runbook changes yet (`docs/services/tq.md`, `docs/services/gatus-alert-relay.md`), no README gatus-count re-stamp (+1 check → the doc-counts anchor row), no DOMAIN_LANGUAGE terms. Report §f lists the exact edits.

## c) NOT STARTED

- **Deploy + E2E verification** (the whole point): switch → tq-api up → 401 probe → relay banner "incident sink on" → controlled incident POST → `tq incidents` shows it → pool sweep (≤5m) mints a prio-120 task → cancel/cleanup (verify `tq cancel` exists; do NOT let a synthetic error burn a real agent run unchecked) → `.crushrc` managed-block convergence check for SystemNix (and CV/tq unchanged).
- **Beacon adoption**: no app embeds `/beacon.js` yet (per-repo work; CV or PapDashboard pilot proposed).
- **Upstream incident-model seam** (per-incident model without repo-wide pin): designed, not implemented (needs a go-taskqueue change + owner push; see §f/13).
- **Self-harvest of this report's follow-ups**: DELIBERATELY deferred — owner WAIT instruction arrived mid-session and a sibling session is active in the tree (its `docs/status/2026-11-24_05-21_*` file rode the same daemon commit 0fc5a73ff as my work; TODO_LIST mid-edit race risk). The next dispatch must harvest §f rows 1–14 into TODO_LIST + domain libraries.

## d) TOTALLY FUCKED UP (caught & repaired — nothing unrepaired left in tree)

1. **Wrong-unit edit in caddy.nix**: my EnvironmentFile edit anchored on `inherit onFailure; serviceConfig = lib.mkMerge [` and landed in `dnsblockd-cert-mint` (first match), mangling its serviceConfig. Caught by immediate re-read, fully reverted, re-applied at the real caddy unit. Lesson: anchor on unique context, not shared boilerplate.
2. **`-flap-max Ns` typo** introduced while rewriting the relay ExecStart (int flag, no `s` suffix) — caught in the same breath, fixed.
3. **Duplicate `after` key** in the relay unit (added mine instead of merging) — caught by the first toplevel eval, merged (the formatter then normalized the shape).
4. **Stale-read edit**: one edit hit a file modified since my last read (concurrent session/formatter) — the tool refused; I re-pinned (`git status`/`git log`) and re-read before touching it again.
5. One `rg -rn` slip (replace-flag trap) — hook-blocked, corrected to `rg -n`; no corrupted readings made it into any decision.

## e) WHAT WE SHOULD IMPROVE (session-level reflections)

- **Edit anchors**: two of my three self-inflicted defects came from under-specified `old_string` anchors on boilerplate shared across units. Anchor on option-name context unique to the target unit, or view the target region immediately before.
- **Foreign-red-tree awareness**: the full-gate blockage (timesheets `brandAssets`) was discoverable before my first heavy eval — a 5-second `git log --since 1h --oneline` over `modules/` would have shown the sibling's daemon-committed half-landing and set expectations. Targeted evals were the right fallback; do that FIRST next time in a known-active tree.
- **Relay package version**: I did not bump `version = "1.0.0"` in `pkgs/gatus-alert-relay.nix` despite shipping a feature — do it in the deploy wave (store-path change forces rebuild regardless, but the version should tell the story).
- **Todo hygiene**: the session todo list went stale after the research phase; work continued correctly but tracking lagged.
- **Beacon fingerprint fragmentation** (accepted for now): client stacks fingerprint on message + top frame; minified frames vary per build, so one bug can span incidents across releases. ADR-0021 accepts message-normalization as the grouping key; revisit only if real data shows fragmentation.

## f) NEXT — up to 50, in rough priority order

1. Re-run full eval once the sibling timesheets `brandAssets` lands: `nix flake check --no-build --all-systems` (capture-once to file).
2. Build the relay via nix (in-build `doCheck` re-runs relay tests under the pinned toolchain).
3. Toplevel build `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` (one pass, all dominoes).
4. Deploy via the quiescence path (`scripts/deploy-when-quiescent.sh --fire` or `nix run .#deploy` after §0.5 advisory).
5. Post-deploy: `ss -ltn` shows 8112; tokenless `GET /api/v1/healthz` → 401.
6. Post-deploy: relay journal shows `relay incident sink on http://127.0.0.1:8112/api/v1/errors (project SystemNix)`.
7. Post-deploy: `/run/secrets/rendered/tq-api-env` populated; gatus-alert-relay + caddy restarted by the secret switch.
8. E2E controlled incident: POST a valid report (project SystemNix, synthetic message marked `SYNTHETIC-PROBE`), verify `tq incidents` open state.
9. E2E mint: within one pool tick (≤5m) a prio-120 agent task appears (`tq tasks`); then **cancel it** (verify `tq cancel` / `tq rescue` semantics first) so no budget burns on a synthetic error; if cancel is impossible, document and let the owner decide.
10. Verify `.crushrc` managed block: SystemNix = `zai/glm-5.3 … xhigh`, CV + go-taskqueue still Flash (bootstrap oneshot ran at switch).
11. Verify `problems.home.lan` resolves (dnsblockd localSubdomains took effect) and `https://problems.home.lan/beacon.js` serves (openssl s_client probe per the shell rules).
12. Verify `/report` CORS preflight (OPTIONS → 204 + headers) and a LAN POST with a tiny JSON body → 202 (this mints nothing until valid — use an invalid body for a pure 400 liveness probe).
13. Verify gatus "tq Write API" check green (401 condition).
14. Harvest §f rows 1–13 + the doc rows into `TODO_LIST.md` + domain libraries (monitoring/services/upstream) — the deferred self-harvest.
15. `docs/services/tq.md`: tq-api unit, incident pipeline flow, token rotation runbook (sops key + template + three restartUnits).
16. `docs/services/gatus-alert-relay.md`: tq sink section (gates apply, resolves never reported, counters in /healthz).
17. README gatus-check count re-stamp (+1; doc-counts anchor row update in the same pass).
18. `docs/DOMAIN_LANGUAGE.md`: **Incident pipeline**, **Error beacon** terms.
19. Upstream row (docs/todo/upstream.md): incident-model seam — `PolicyConfig.Model` + minted `AgentPayload.Model` AND a `Reasoning` payload field so `--model` + `--reasoning-effort` travel together (dissolves the retirement rationale "resets reasoning effort"); pool.conf key `incident-model`. Blocked on owner push discipline.
20. Beacon pilot: embed in one app (CV suggested) with `data-project="CV"`; watch one real client error flow to a minted task.
21. Relay version bump 1.0.0 → 1.1.0 (`pkgs/gatus-alert-relay.nix`).
22. Consider a gatus/SigNoz visibility leg for sink health: relay `/healthz` `tq_failures` counter (alert when the sink goes dark quietly).
23. Verify no eval WARN from the `noDashboardTile` + subdomain pair (icon-less registry tile warning class).
24. Confirm post-deploy-check.sh smoke covers `problems.home.lan` as protected with backend 8112 (vhostLayerLines stamp).
25. Confirm caddy's `TQ_API_TOKEN` env is present in the rendered unit (`systemctl show caddy -p Environment`-class probe via /proc or deploy log).
26. Watch the first REAL gatus trigger end-to-end (relay log `tq-report=ok`, `tq incidents` occurrence, minted task).
27. Document effective ingestion latency: gatus failure-threshold 3 + relay gates + pool tick ≤5m — incidents debug within ~10min of a persistent failure.
28. Consider `report-problem` CLI wrapper for agents/operators (reads token from the rendered env path; manifest-port-aware; script-port-audit compliant).
29. Consider PapDashboard visibility: incidents could surface as a feed (upstream webui follow-up; ADR-0021 lists it).
30. Revisit `daily-budget = 30` after a week of incident traffic (full-model SystemNix tasks are pricier than Flash).
31. Consider per-repo `.tq-agents` carve-outs for incident tasks (max attempts already 2 upstream).
32. Beacon: opt-in `data-endpoint` override documented; default derives from flake `domain`.
33. Beacon: consider `document.addEventListener('visibilitychange')` flush? YAGNI unless data loss observed.
34. Confirm incident prompt renders breadcrumbs (fixPrompt verified in source; spot-check one minted task's payload).
35. VM/selftest leg for the problems vHost route chain (preflight/gate/report ordering) — caddy-mint VM precedent.
36. Add `problems.home.lan` info page to the pre-deploy §16-style tile/icon inventory? (No tile by design — nothing to do unless the owner wants one.)
37. Check crowdsec behavior on beacon POST bursts (should be trivial; watch for false positives).
38. Watch tq-api + pool SQLite coexistence on first shared-write window (WAL/busy_timeout by design; journal for `database is locked`).
39. Consider tq-api OTel wiring (upstream has none — `wiring = "upstream"` gap note if registered).
40. Registry blind-subdomain audit: confirm `problems` needs NO blind row (registry entry exists — expect clean).
41. Lock/pin audits: no new pins introduced (go-taskqueue input untouched) — confirm flake-input-pin-audit silence.
42. Gatus coverage audit: 8112 now probed by the registry check — expect the loopback-URL rule satisfied via `checkUrl` localhost form.
43. Daemon-commit contents check: verify 0fc5a73ff carried exactly my 5 files + the sibling's 2 (attribution hygiene).
44. Consider extending `sev1MuteEndpoints` reasoning to the tq sink: currently SEV1-muted endpoints also skip incident reports — intended (known-storm checks), document in relay runbook.
45. Beacon security note in tq.md: LAN-only reporting, token never client-side, junk bounded by incident dedup + daily budget.
46. Owner decisions from §g (model scope, deploy timing, budget) → fold answers into the deploy wave.
47. After first real mint: sanity-check the minted task's prompt quality (breadcrumbs rendered, constraints sane) and file upstream nits if any.
48. Consider `send-on-resolved`-style incident resolve events (tq has none — incidents heal only via fix completion or regression; leave as designed).
49. Sweep: remove `docs/status/2026-11-24_05-21_*` sibling-file attribution ambiguity in the next closeout (not mine, co-rode the daemon commit).
50. Retro: add "wrong-unit edit anchor" to personal lessons (candidate for `references/lessons.md` in crush-config — cross-project class).

## g) Questions the owner must answer (cannot be derived)

1. **Model scope**: the landed mechanism pins the WHOLE SystemNix repo (backlog TODO items too) to full `zai/glm-5.3` @ xhigh — incidents get the good model immediately, but every pool-harvested SystemNix task also upgrades (~5–10× token cost, still capped by daily-budget 30). Acceptable, or should I build the upstream per-incident model seam (§f/19) so backlog stays Flash and only incident tasks upgrade?
2. **Deploy authorization**: the tree is currently RED from the sibling timesheets session (`cfg.package.brandAssets` missing — their in-flight work, daemon-committed at 0fc5a73ff). When it greens: deploy immediately without further confirmation, or stop and ask first? (This wave also flips SystemNix's `.crushrc` model and restarts caddy.)
3. **Synthetic E2E proof**: verifying the full chain end-to-end requires one real mint (a prio-120 agent task for a synthetic error I then cancel — costs nothing if cancel works, one cheap agent run if it doesn't). Green light for that controlled probe, or restrict verification to non-minting 400/401 probes + wait for the first real check failure?

---

_Arte in Aeternum — pipeline built, gates green where the tree allows, deploy withheld by instruction._
