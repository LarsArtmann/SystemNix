# Caddy Edge OTel Tracing — All vHosts (2026-10-25)

**Status:** code + docs LANDED (daemon commits `08c2540b9` code / docs rows following), eval-verified, pre-deploy-validated. **Deploy BLOCKED by the deploy entry gate** (I/O storm — see §d); one command completes it. `nix run .#deploy` at a PSI-calm window, then §e verification.

## a. What

Forgejo-OTel dead-ended upstream (PR #3972 merged 2024-08-05, reverted 2024-08-07 over EUPL-1.2-vs-GPLv3-or-later; never shipped any release; author refuses relicense AND calls his own traces flat/near-useless without major context-propagation refactors — forgejo#7216). The edge sees every request anyway, so instrument THERE: Caddy's core `tracing` directive (standard module since 2.5, no plugins) in `commonConfig` — the single block every vHost renders through (hand-written, registry fan-out, static roots, catch-alls, cloud mirrors; **76 rendered site blocks**).

- Span name = requested host (`span {http.request.host}`) → spanmetrics cardinality bounded by vHost count; spans carry OTel HTTP semantic attrs (method/route/status/duration/client). Service name `caddy`.
- Unit env: `OTEL_SERVICE_NAME=caddy`, `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317` (gRPC, scheme REQUIRED — otel-go otlptracegrpc is a URL parser, the 2026-08-14 hang class).
- Audit rails registered: `otel-endpoint-audit` `caddy = "grpc-url"`; `signoz-coverage.expected.caddy` wiring `env`, 26h request-driven budget (gatus probes hit backends directly, NOT through caddy — spans flow on human/smoke traffic).
- Edge spans ONLY: caddy cannot continue trace context into backends (no client-side instrumentation anywhere).

## b. Pre-deploy proof (all green)

1. Directive validated against the DEPLOYED caddy 2.11.7 binary (`caddy validate`, tracing + placeholder span name).
2. Full rendered evo-x2 Caddyfile: `caddy adapt` clean, 76 `tracing {` blocks. (A/B note: `caddy validate` as non-root hits `open /var/log/caddy/access.log: permission denied` on the DEFAULT-LOG writer — the CURRENT deployed config errors identically; environmental, not from this change.)
3. `nix flake check --no-build` green (all hosts; audit + coverage assertions satisfied).
4. Unit mechanism: `reloadIfChanged = false` / `restartIfChanged = true` → the switch RESTARTS caddy, so the new Environment goes live (a graceful reload would have kept the old env — checked deliberately).
5. Foreign-tree audit: the deploy delta carries the parallel session's committed `catalog-platform.nix` (not enabled, no build) + 2-line `system-health.nix` edit — eval-green, no FODs, light build.

## c. Files

- `modules/nixos/services/caddy.nix` — tracing directive in `commonConfig` + unit env.
- `modules/nixos/services/otel-endpoint-audit.nix` — `caddy = "grpc-url"` expectation.
- `modules/nixos/services/signoz-coverage.nix` — `caddy = env "caddy" 26`.
- `docs/services/caddy.md` — new "Edge tracing" section (incl. live-verify query).
- `CHANGELOG.md` — feature row.
- Daemon-race note: my 3 code files were swept into `08c2540b9` MIXED with the parallel session's `docs/todo/stability.md` + `system-health.nix` — no amend (would absorb foreign work); heuristic messages stand.

## d. Deploy gate (why not deployed)

`nix run .#deploy` blocked at the ENTRY gates 2026-10-25 ~17:10: io PSI some avg10 35.8% **with disk busy 102%** (nvme0n1+sdb at 101% util) — "crash #3 precursor class"; top stalled cgroups = the owner's own ghostty/app.slice. Poll 17:17–17:42: 36 → 42 → 34 → 49 → 53 → **74%** (worsening; the day's sustained Zone-6 storm, freeze-31/33 already burned today). Did NOT `DEPLOY_FORCE_PRESSURE=1` — three freezes today; a config-only deploy is not worth the precursor class. Storm attribution attempt: page-cache writers are sccache (agent Rust builds), 4+ concurrent crush agents, owner's browser — volumes too small for 101% util; likely fsync-churn (ClickHouse merges / btrfs), not chased further.

## e. Deploy + verify (one calm window)

1. `nix run .#deploy` (entry gates must pass clean — no force).
2. Anchor: `readlink /run/current-system` == newest `system-N-link` by NUMBER; full process tree drained.
3. Probe any vhost (raw HTTPS recipe), wait ~15 s, then:
   `clickhouse-client --query "SELECT count() FROM signoz_traces.distributed_signoz_index_v3 WHERE timestamp > now() - 300 AND serviceName = 'caddy'"` → > 0.
4. Next coverage scrape: `signoz_traces_reporting{service="caddy"} 1`.
5. If zero spans: caddy journal for exporter errors first (`OTEL` grep), then the runbook §Edge tracing.

Follow-ups harvested: TODO_LIST queue row + docs/todo/monitoring.md row (this report is their Source).
