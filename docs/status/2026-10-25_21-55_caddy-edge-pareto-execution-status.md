# Caddy Edge Pareto Execution — M1–M27 Status (config landed, deploy pending)

**Session:** 2026-10-25, ~19:00–21:55 CET (single instance, `crush-glm-5.3-flash-caddy-edge` tombstone `65d60f3a6`)
**Plan:** `docs/planning/2026-10-25_17-57_SUPERB-caddy-edge-pareto-plan.md` (owner directive: execute EVERYTHING; gates G1–G3 answered by the same directive)
**Verdict up front:** 27 medium tasks — **7 done, 14 partial (all partials are "config + eval-verified, live verification waits on the deploy"), 6 not started.** Everything that touches the RUNNING edge is written, committed, eval-green, and (where possible) sandbox/live-API-proven; the deploy + post-deploy verification battery is the remaining ~half-day. One real pre-existing bug was found and fixed along the way (M26). Two of my own bugs were caught by the repo's gates before they could matter (doc-counts, vacuous drift guard) — details in §d.

Parallel sessions were LIVE the whole window (tracing work, papdashboard tile fix, flake.lock float, integration registry rework, opencloud plan tombstone at 21:53). Every collision is attributed in §d/e.

---

## a) FULLY DONE (verified at the strongest layer available without a deploy)

| Task | What landed | Proof |
|---|---|---|
| **M1** pre-flight | monitoring.md read; rendered-config diff vs audit claims; live `:2019` pull | adapt exit 0; **15 `caddy_http_*` families, ZERO host labels** (per_host absence live-confirmed); strict_sni/encode/tls/metrics claims all confirmed in rendered config |
| **M5** branded 502 pages | `serverErrorRoot` linkFarm (502/503/504, Catppuccin Mocha sibling of the 404 page) | **Sandbox proof F28: real caddy 2.11.7, dead backend → HTTP 502, branded page, `{err.status_code}` rewritten, status preserved** (`~/.cache/caddy-preflight/sandbox/`) |
| **M7** upstream-5xx branding | DECISION: stays pass-through, default-off, documented | upstream source check: `handle_response` page-serving loses the upstream status (file_server answers 200) + upstream 5xx bodies are API contracts; runbook "Error pages" section carries the pattern-if-ever-needed |
| **M16** research index | `docs/research/README.md` (32 reports: subject/date/refresh-trigger) + link from `docs/agents/README.md` | living-docs link check green in hook |
| **M19** blind-subdomain hygiene | alerts removal-candidate + seo keep-hand-rolled watch-notes added; F73/F74 verified ALREADY DONE by the parallel session (auth/seo/tasks/dnsblock un-blinded per owner §g.2/§g.3 answers; paperless justified+dated in-source) | `registryBlindSubdomains` comment block current |
| **M25** mint SAN zone guard | eval assertion: every dotted vHost key must end in a minted zone | **negative leg PROVEN: injected `foreign.example.test` vHost → eval throws naming the guard** (`CASES=caddy` run) |
| **M27** skill/artifact notes | 2 rows in `docs/todo/pipeline.md` (Context7-absent fallback recipe; `~/.cache/<topic>/` durable-home convention) | queued with Sources |

Also fully done, cross-cutting: doc-counts restamp (README 131→132 nixosModules, 51→52 mkRule; FEATURES 132/137), caddy-mint VM unblocked (minimal registry stub entries for the four un-blinded subdomains — the parallel session's new assertion was firing in the VM and blocking EVERY flake check), M1's F06/F07 legs, M12's source+rendered half (the `:80` matcher demonstrably covers `*.home.lan *.larsartmann.cloud`).

## b) PARTIALLY DONE (config committed + eval/live-API verified; live leg waits on deploy)

| Task | Done | Remaining |
|---|---|---|
| **M2** per_host | `metrics { per_host }` in globalConfig; narrow evals green | deploy → live cardinality check (F12: host-label count ≈ vHost count + `_other`) |
| **M3** dashboard rework | 8 panels (5xx/4xx tiles moved OFF the phantom `requests_total{code}` onto histogram counts; 3 by-host panels + top-hosts-5xx); **LIVE-converged via v2 API PUT (HTTP 200)**; dotted-name parse trap found+fixed (`{__name__=...}` form) | render verify once per_host series exist |
| **M4** per-host 5xx alert | `mkRule` in `_signoz-alerts.nix` (0.1/s per host, 5m, warning, G3 defaults documented in-rule); **query live-validated against the real query API** (parses, returns sane pre-per_host aggregate) | deploy → rule-load verify → FP observation window (F25, days) |
| **M6** error routes | `serverErrorRoute` in both proxy helpers + 5 hand-written proxy vHosts; catch-alls qualified to `handle_errors 404` + route added; 66 rendered vHosts carry it | deploy → live dead-backend probe via enable-gated vHost (F32) |
| **M8** read_body | `timeouts { read_body 15m }`; 10GB per-vHost cap confirmed deliberate (Immich) + documented | live config confirm (one admin-API read) |
| **M9** journald switch | `output stdout` + `format journald { wrap json }` (syntax adapt-validated against the real binary); geometrikks global access.log path dropped (+comment record); runbook Logs section rewritten; filelog row re-pointed in monitoring.md AND TODO_LIST.md (both surfaces); crowdsec verified safe (glob); F43 migration-test checked | deploy → journal priority prefixes → SigNoz `service.name=caddy` ingest → access.log stops growing |
| **M21** log hygiene | `log_skip @probe` (8 health paths) in commonConfig; per-vHost rolls 100MiB×3/168h + zstd (adapt-validated) | deploy → verify probe paths actually skipped + first zstd roll |
| **M12** :80 redirect | source + rendered config confirm both zones covered (`@subdomains host *.home.lan *.larsartmann.cloud`) | live plain-HTTP probe (F50) |
| **M13** dead-backend VM test | `test-caddy-auth.nix` third pattern: `:8083` dead backend + EXACT serverErrorRoute; asserts 502 + branded page + no unexpanded placeholder; instantiates clean | **VM never RUN** (see §d-8 — build+run it BEFORE the deploy) |
| **M14** drift lint | audit module shipped; vacuous `hasInfix` bug FOUND BY THE NEGATIVE LEG and fixed (exact-line trimmed match) | **rerun `CASES=caddy`** — the fix committed but the leg's green run is still owed |
| **M17** stance rows | F64 rate-limit stance `[decision]` row; F65 monitor365 row amended (**premise shift verified: the upstream fix is now PUSHED, origin tip `77b4a3aec` — chain unblocked**); F66 catchall row amended (caddy side resolved) | F67 Cache-Control backstop re-check note |
| **M22** supersession | caddy.md deep-dive section annotated ADOPTED per finding + refresh triggers + F84 granularity note + F85 cadence verification (lock 2026-10-23 carries 2.11.7 = latest) | HTML report annotation (docs-health ANNOTATE on the report file itself) |
| **M23** cadence+convention | F85 done (above); F86 precedent found (research arcs get CHANGELOG entries at closeout) | CHANGELOG entry for this arc (after deploy verification) |
| **M26** port map | helper-stamped `# proxy-port:` lines + marker-split parser; rendered map verified: **19 protected + 18 plain with REAL backend ports** (seo 3002, tasks 10222, paperless 2892, auth 1411), static/redirect stay `-` | live smoke re-verify (F92) post-deploy |

## c) NOT STARTED

- **M10** static vHost 404 branding probe/fix/pin (timers/catalog).
- **M11** SSE `write_idle` live verify (llama-chat long generation).
- **M15** harvest of post-deploy rows into TODO_LIST + domain libs (F25 FP window, log_skip path validation, journald ingest watch, immich-if-shifted).
- **M18** module-doc batch (enableReload rationale comment, XFF no-trust + redaction runbook lines, Permissions-Policy value review, hostOverride users audit) — skipped entirely so far; zero work landed.
- **M20** verification rails re-run (otel-endpoint-audit + signoz-coverage caddy legs) post-change.
- **M24** immich hybrid-auth regression probe (needs the deployed helper first).
- Deploy + anchor check + post-deploy-check caddy legs; plan-marker `done` flip; push (5 commits ahead).

## d) TOTALLY FUCKED UP (own bugs, own fumbles — full honesty)

1. **Vacuous drift guard (real bug, caught by my own gate).** The M14 audit used `hasInfix "per_host"` — my directive's explanatory COMMENT contains the same substring, so stripping the directive kept the assertion green forever. The negative leg caught it (its exact job); fixed to an exact-line trimmed match. Lesson: self-review assertions against every string in their own module BEFORE committing.
2. **Multiedit construction error** duplicated the `request_body` block into `tracing` (would have been a Caddyfile duplicate-directive error). Caught on the verification grep, reverted in the next call. Cause: assembling 12 edits in one shot without re-checking each old_string's surroundings.
3. **sed-for-JSON, twice.** Inserting `{__name__="..."}` into dashboard JSON with sed put RAW quotes inside JSON strings (HTTP 400), then a repair sed mangled the probe URL, then a third left `\\\"` in the curl. Three wasted cycles. `jq` or the edit tool was the right tool every time.
4. **`git status --short | head -5` truncation** made me believe my M26 edits were lost (they were lines 6+ of the status). Nearly triggered a pointless re-do. Read full status before concluding.
5. **Stale-read edit rejections, ~4×** (shared tree + my own commits re-touching files). Each cost a re-view + re-apply; one multiedit failed wholesale. The discipline (fresh view before EVERY edit) kept being under-applied under pace.
6. **index.lock collision**: two background commits in flight at once (06F never collected while 075 started). Serialized afterward.
7. **Sandbox fumbles**: `caddy validate` without `--adapter caddyfile` (config is a Caddyfile); `caddy` not in agent PATH; port 8091 already owned by a live service (303 from a stranger); site address defaulted to TLS ("Client sent an HTTP request to an HTTPS server"). Each cost a cycle; all were probes, zero production impact.
8. **VM tests written but never RUN.** I leaned on `nix-instantiate` + eval for M13 while the parallel session's queued row explicitly warns caddy "has never STARTED under this config". The right order is build+run `checks.caddy-auth-patterns` and `checks.caddy-mint` BEFORE the first real deploy — that is now the top of §f.
9. **`rg`-with-`-r` guard trips, 2 more** (`nix path-info -r` piped into `rg` in one line) — third-strike wording; the hook is right and my command assembly keeps flirting with it.
10. **Daemon-sweep attribution archaeology, 3×** — commits I fired landed split across heuristic daemon commits (caddy.nix across b93270de6/3347fb579, M3/M4/M9/M21 across 141a2bcc4/…). Content always verified at HEAD, but tighter edit→verify→commit lanes would remove the guesswork.

## e) WHAT WE SHOULD IMPROVE

- **Deploy-gated tasks should not have been interleaved with doc tasks.** The config half finished early; batching ALL deploys first would have unblocked ~10 verifications that are now queued behind one deploy.
- **Run the VM checks before, not after, the first real switch.** Cheap insurance the repo already queues (the caddy-mint boot-proof row).
- **JSON surgery: jq/edit only.** Sed + quotes = guaranteed 400.
- **Assertion self-review**: any `hasInfix` guard must be checked against the module's own comments (the vacuous class is now negative-tested — keep it that way).
- **One commit lane**: stop launching background commits while another is in flight; collect before firing.
- **The negative harness keeps paying**: it caught the vacuous guard and proved the SAN guard. Feed it every new eval gate (M14 leg rerun is owed).
- **Premise re-verification at row-amend time worked** (F65's "unpushed" was actually pushed) — keep live-verifying queue-row premises before amending.

## f) NEXT (ranked; ~50)

1. **Build+run `checks.x86_64-linux.caddy-mint`** (boots the REAL rendered config incl. today's changes — clears the parallel session's boot-proof row AND de-risks the deploy).
2. **Run `checks.x86_64-linux.caddy-auth-patterns`** (M13's VM, never executed).
3. **Rerun `CASES=caddy` negative group** → expect 3/3 (drift leg green after the vacuous fix).
4. **`nix run .#deploy`** at a PSI-calm window (restarts the web edge; expect seconds of 502s on external forward-auth paths — LAN bypass unaffected).
5. Anchor check: `readlink /run/current-system` == newest `system-N-link`.
6. `scripts/post-deploy-check.sh` caddy legs (auth-gateway sweep with the FIXED port map — M26's SKIP semantics proven live).
7. F12: `:2019` pull → host-label cardinality ≈ vHost count + `_other`; record the real number in the runbook.
8. M3 render verify: per-host series via query API + dashboard panels non-empty; provisioner logs "Unchanged: skipping" for `systemnix-caddy`.
9. M4: rule loaded (provisioner journal / rules API); route policies intact; start F25 FP observation (days).
10. M9: journal priority prefixes on caddy lines; SigNoz ingests `service.name=caddy`; geometrikks per-vHost file sources still green.
11. M9: confirm `/var/log/caddy/access.log` stops growing; per-vHost zstd on first roll.
12. M21: probe `/health` on a vHost → NO access-log line; `/` → line present.
13. M6: live dead-backend probe via an enable-gated vHost → 502 + branded page (never stop a live service).
14. M8: read `:2019/config` → `timeouts.read_body` present.
15. M24: immich LAN probe + `app.immich:///oauth-callback` bypass probe post-helper-change; document if shifted.
16. M26/F92: smoke SKIP semantics with real ports (a known-down backend now SKIPs, not FAILs).
17. M12: live `:80` probe for a cloud-zone name (openssl s_client to the LAN IP).
18. M10: timers/catalog unknown-path probe → 404 status + branded page; fix + pin if bare.
19. M11: llama-chat long-generation SSE stream under 2.11.6+ write_idle defaults; per-route timeouts only if stalls.
20. M20: re-run otel-endpoint-audit (grpc-url leg) + signoz-coverage caddy leg.
21. M15: harvest post-deploy rows (F25 window, log_skip validation, journald ingest watch, immich disposition) into TODO_LIST + services/monitoring libs with Sources.
22. F79 extension: diff the log_skip path set against the RENDERED gatus check paths; amend the matcher set.
23. F25: calendar the FP-window review (24–48h) and the tune-threshold note.
24. F67: Cache-Control backstop re-check note (caddy.md § Caching).
25. F86: CHANGELOG entry for the arc (post-verification, with evidence pointers).
26. F08: plan errata line — live-probe leg is a MANDATORY phase of future library deep dives.
27. M22: annotate the deep-dive HTML report itself (ADOPTED banners, docs-health ANNOTATE mode).
28. Flip plan marker to EXECUTED (`scripts/plan-marker.sh <plan> done`) + commit.
29. Push the 5+ execution commits (master flow; the plan push was owner-authorized — confirm or reuse).
30. SigNoz scrape health: `up`-equivalent for the caddy :2019 job post-change (metrics endpoint unchanged — verify anyway).
31. Watch `access_log_debug` rows go to zero (runtime lines no longer tail'd by geometrikks — the 1,113-restart-banner class should die).
32. ClickHouse cardinality receipt: count `caddy_http_request_duration_seconds.count` series with host label (per_host's real price) → runbook.
33. Verify crowdsec acquis still parses post-restart (mode-0640 open() caveat — deploy restarts, so files keep 0640; timer stays a no-op).
34. Journal-volume delta check (caddy runtime → journal): confirm no ingestion-rate regression (2026-08 CPU-burn class guard).
35. geometrikks UI: host filter count == per-vHost file count (LOGPARSER list shrank by one entry).
36. `/mnt/hot` headroom receipt for the new roll bounds (~23 GiB worst case uncompressed, zstd on roll).
37. Runbook: mint third-zone guard note (foreign-zone vHosts are eval-blocked, not runtime-discovered).
38. signoz-query-lint caddy leg specifically (deadMetrics/underscoreLive lists vs my dotted-form queries).
39. Consider re-pointing the filelog row's volume-anomaly alert at the journald `service.name=caddy` surface (harvest decision).
40. Verify no doc-count drift from the docs battery (research README is not policed — consider adding it to doc-counts).
41. Re-check the two remaining `evaluation warning`s my changes touch: ghost-entries warning in the mint VM is EXPECTED (document in the test header); evo-x2 ghost warning unchanged.
42. Check whether `services.caddy.enableReload` semantics changed anything for the journald switch (reload vs restart for output changes — caddy caveat already documented; verify the deploy did a RESTART).
43. Assert the mint VM stub entries did not leak into evo-x2 (they are VM-scoped; eval both).
44. Add the seo/paperless/auth/dnsblock/monitor stamps to the vhost-layers consumer docs (post-deploy-check header comment mentions "first proxy target" — now stale).
45. Sweep for OTHER stale "first localhost:" phrasings (runbook/scripts) post-M26.
46. Consider upstreaming the `{err.status_code}` page-rewrite pattern to the repo's caddy gotchas (docs/gotchas-archive.md if an incident ever hits).
47. F25 tuning: if the 0.1/s threshold false-fires on a chatty 5xx app, prefer per-host exclusion list over global threshold raise.
48. Double-check the `auth` map entry port semantics (1411 = pocket-id backend; the smoke treats it as the probed backend — correct, but document).
49. Owner-visible summary of what changed on the edge (this report + CHANGELOG cover it — link both from the plan's done-marker).
50. Schedule the next deep-dive refresh trigger check (next caddy major bump — the report's own trigger).

## g) Owner questions (cannot self-answer)

1. **Deploy timing:** the config restarts the whole web edge (seconds of external forward-auth 502s; LAN unaffected). Deploy NOW in this session at a PSI-calm moment, or do you want it parked for a specific window? (A parallel session just tombstoned the opencloud plan — if they intend edge-touching work tonight, coordinate.)
2. **G3 alert tuning:** keep the documented defaults (≥0.1 5xx/s per host, 5m window, warning severity, `_other` excluded) or name your own threshold/window/scope now?
3. **M7 upstream-5xx:** confirmed pass-through stays (API clients get real bodies), or do you want the opt-in `brandUpstreamErrors` param wired anyway for browser-only vHosts despite the status-loss caveat?

---

**Surfaces touched this session:** `modules/nixos/services/caddy.nix`, `caddy-perhost-drift-audit.nix` (new), `geometrikks.nix`, `_signoz-alerts.nix`, `dashboards/caddy.json`, `tests/test-caddy-auth.nix`, `tests/test-caddy-mint.nix`, `scripts/negative-test-lints.sh`, `docs/services/caddy.md`, `docs/research/README.md` (new), `docs/agents/README.md`, `docs/todo/{services,pipeline,monitoring}.md`, `TODO_LIST.md`, `README.md`, `FEATURES.md`. Commits: `65d60f3a6` (tombstone), `75ec4e45e`, `d4867c6dc` (mine), plus daemon-swept carriers — all content HEAD-verified.
