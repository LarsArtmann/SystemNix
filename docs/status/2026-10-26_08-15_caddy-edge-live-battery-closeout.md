# Caddy Edge Pareto — Live Battery Closeout (gen-949 carried the batch)

**Report:** 2026-10-26 ~08:15 CET · single agent (crush, caddy-edge executor resumed) · evo-x2
**Context:** the 2026-10-25 21:55 status report left everything waiting on ONE deploy. That deploy happened WITHOUT this session: **gen-949 went live at 21:05:59 (battery 113/0/5), carried by the deploy-unblock session, and it already contained every eval-relevant caddy-edge commit** (`d4867c6dc` and ancestors). This session therefore skipped the deploy step and ran the LIVE verification battery against gen-949 instead.

## a) Battery verdict (§f items, live evidence)

| §f | Item | Verdict | Evidence |
|----|------|---------|----------|
| 4/5 | deploy + anchor | ✓ (done by the parallel session) | gen-949 anchored, `readlink /run/current-system` == system-949-link (their §a8) |
| 6 | post-deploy caddy legs | ✓ 158 PASS / 3 SKIP | auth-gateway sweep with the FIXED port map; `SKIP emeet-pixyd.home.lan (backend :8090 not listening)` = **M26/F92 SKIP semantics live** |
| 7 | F12 cardinality | ✓ **32 distinct host labels**, ~2.7k labelled series, 0 `_other` | `:2019/metrics` (Host header script); recorded in caddy.md §Monitoring |
| 8 | M3 dashboard | ✓ per-host query returns live data | `sum by (host)(rate(...count[5m]))` → auth/banksync/cache/… series; dashboard converged via v2 PUT (id `01a00c5e…`, 200) |
| 9 | M4 rule | ✓ loaded, state `inactive` (armed) | rules API: "Caddy Per-Host 5xx Rate High"; **F25 FP window starts now** (24–48h watch row harvested) |
| 10 | M9 ingest | ✓ `caddy.service` rows flowing, severity split live (INFO/WARN/ERROR/FATAL) | ClickHouse via resource-join; NOTE: 381k rows/h = the export-failure flood (see §b); label is `caddy.service` (unit form), NOT `caddy` — queried wrong first |
| 11 | M9 access.log | ✓ global access.log GONE | `/var/log/caddy/access.log` absent; per-vHost files root-gated to this agent (deferred live read; geometrikks UI is the owner-visible surface) |
| 12 | M21 log_skip | partial-verified | matcher present in live config + rendered-gatus diff landed (`/dex/healthz`); the file-line ABSENCE check needs root (queued with the filelog row) |
| 13 | M6 dead backend | ✓ **502 + branded page live** | `https://emeet-pixyd.home.lan/` → 502, `<title>502 - Service not responding</title>` (no service was stopped — already down) |
| 14 | M8 read_body | ✓ **900000000000 ns = 15m** | live config `srv0.read_timeout`; the Caddyfile `timeouts { read_body }` form RENDERS AS `read_timeout` (adapter rename — runbook noted) |
| 15 | M24 immich | ✓ no shift | `/` 200, `/api/server/ping` 200; `app.immich:///oauth-callback` is a deep-link redirect URI (pocket-id side), no caddy surface |
| 17 | M12 :80 redirect | config-verified | live config: `host *.home.lan,*.larsartmann.cloud → static_response 301 https://{host}{uri}`; plaintext :80 probe needs the LAN IP from an owner shell (getent/hostname -I unavailable here) |
| 18 | M10 static 404 | ✗ gap → **FIXED** | `timers` unknown path = **zero-byte 404**; catalog masked it (SPA-on-404 via the catch-all's route, first-match-wins with inherited root). staticVHost + timers now carry the branded notFoundRoot 404; **VM-pinned as Pattern 4** in `checks.caddy-auth-patterns` (re-run green); rides next deploy |
| 19 | M11 SSE | ✓ no stalls | 0 stream/timeout lines in caddy + inboxclean journals since 21:05; write_idle 2.11.7 default active (no override). llama-chat is consumed server-side by InboxClean — the only SSE-through-edge surface is its dashboard chat (owner-browser smoke optional) |
| 20 | M20 rails | ✓ | toplevel eval green, 0 caddy/otel/signoz warnings (audits throw on violation); F78 budget note annotated accurate |
| 21 | M15 harvest | ✓ | 2 durable watch rows (F25 window, journald volume) on both surfaces; mint boot-proof row PRUNED (VM passed) |
| 22 | F79 diff | ✓ | `/dex/healthz` was logging every gatus cycle; matcher extended |
| 27 | M22 annotate | ✓ | deep-dive HTML: ADOPTED banners on all 3 findings |
| 26 | F08 errata | ✓ | plan errata + research README doctrine: live-probe leg mandatory |

## b) THE CATCH: edge-tracing exporter bug (spans dark on gen-949)

Caddy's `tracing` ships the **OTLP/HTTP** exporter, but the unit env pointed at the **gRPC** collector port `:4317` (the audit expectation wrongly asserted `grpc-url`/otlptracegrpc). Live signature in the caddy journal: `traces export: Post "http://localhost:4317/v1/traces": malformed HTTP response "\x00\x00\x06\x04…"` — the collector answering an HTTP/1.1 POST with an **h2c SETTINGS frame**. Consequences: zero spans in SigNoz (ClickHouse `serviceName='caddy'` = 0 over 6h), the 26h coverage env false-pages ~23:05 tonight, and the failed-export retry loop floods the journal at ~100 lines/s (the 381k-rows/h "ingest success" above IS the flood).

**Fixed in `7adaabf04`**: endpoint → `:4318` (`ports.signoz-otlp-http`), audit expectation → `http-url`, runbook port history written. Eval green. **Rides the next deploy** (the opencloud/tracing sessions' pending switch carries it). Tracing verify recipe (probe → ClickHouse count → coverage gauge) stays in monitoring.md row + 17-45 report §e. Lesson recorded: the endpoint-audit checked URL *shape*, never *protocol-port agreement*.

## c) Not mine, flagged (shared-tree honesty)

- `M README.md` (opencloud ports row + Gatus 232→234) + `M flake.nix`/`flake.lock`/`expected-locks.nix` (journal input note + a Go-inputs lock bump) — parallel sessions' in-flight work, untouched, uncommitted by me.
- DiscordSync "Immich verify" FAIL in the battery: **pre-existing** (already under diagnosis in `docs/status/2026-10-25_08-07_discordsync-immich-lookup-placeholder-diagnosis-status.md`; DiscordSync hits Immich at loopback :2283 directly — zero caddy involvement; Immich journal shows 0 rejections since 20:00).
- fastflowlm 191% CPU + node-exporter 382 journal-lines/min: pre-existing warning-class, not caddy.
- Stale `.git/index.lock` (45 min old, no holder — the 07:14 daemon commit crashed mid-op) removed to unblock commits for ALL sessions.

## d) Answers to the 3 open owner questions (as far as execution settles them)

1. **Deploy window** — moot for this batch: gen-949 carried it. The REMAINING deploy (carries :4318 fix + /dex/healthz + static-404 branding) slots into the opencloud session's pending switch; nothing here needs a dedicated window.
2. **G3 alert 0.1/s defaults** — deployed + armed (`inactive`); F25 FP window running with the per-host-exclusion-list tuning rule documented. Confirm or retune after 24–48h.
3. **M7 pass-through** — decision stands as documented (upstream 5xx pass-through, only edge-generated 5xx branded); no code, runbook §Error pages owns it.

## e) Surfaces touched this session

`7adaabf04` (9 files): caddy.nix (endpoint + 404s + matcher), test-caddy-auth.nix (Pattern 4), caddy.md (port history + F12 receipt + M18 block + F67/F78 notes), research README + HTML annotations, plan errata + marker, monitoring.md + TODO_LIST.md + services.md rows. Closeout commits follow (CHANGELOG + this report + marker).

## f) Remaining (deliberately open)

- **Next-deploy riders**: :4318 span fix, /dex/healthz log_skip, branded static 404s — all committed, all verified at eval/VM layer; each flips to live-verify on the next switch (tracing recipe in monitoring.md).
- Root-gated: per-vHost access-file inventory + the log_skip file-line absence check (fold into the filelog row's next window).
- Owner 30-seconders: :80 plaintext redirect probe; optional inboxclean SSE chat smoke.
- F25 FP window review at 24–48h (watch row), journald volume watch (flood should DIE when :4318 deploys — the watch row now has the 381k/h baseline to compare against).
