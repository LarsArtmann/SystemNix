# NetBird leverage pass — status report

**Date:** 2026-10-29 23:18 CET (work window ~22:15–23:25)
**HEAD at writing:** post-d54072e49 (daemon swept; README + report pending sweep)
**Session ask:** "How can we better leverage the NetBird service and general advanced open source features?" — plan + execute + verify, Pareto-ordered.
**Plan artifact:** `docs/planning/2026-10-29_23-00-SUPERB-netbird-leverage-advanced-oss.html` (D2 graph inlined)
**Harvest:** this report's new follow-ups were landed at authoring time into `docs/todo/services.md` (2 rows), `docs/todo/monitoring.md` (1 row), `docs/todo/pipeline.md` (3 rows) — §f marks each item's status.

## Context

Pre-read honored: 2026-09-30 ratified net-vpn architecture (owner constraints C1–C7, decisions D1–D9), 2026-10-17 control-plane resilience plan (23 macros), `docs/services/net-vpn.md` runbook, today's parallel-session router/4G plan (`2026-10-29_22-18_SUPERB-4g-failover…`, PLAN ONLY, different domain — coexisted all session, its lock floats + paperless-gpt/inboxclean/configuration.nix edits interleaved with mine via the daemon). Upstream research: netbird 0.8x docs + v0.81.0 `profilemanager/config.go` source + pinned-nixpkgs `fe13242` netbird module (options, preStart jq merge, restartTriggers absence).

---

## a) FULLY DONE (evidence-cited)

1. **Mesh-state observability chain, config-complete** — client local Prometheus endpoint enabled declaratively (fragment keys `LocalMetricsEnabled`/`LocalMetricsAddress`, PascalCase Go field names source-verified against v0.81.0 — bool/string, immune to the url.URL crash class), port registered `ports.netbird-metrics = 9465` (ocis binds 9100–9304; NetBird's default 9191 collides), daemon `restartTriggers` added (nixpkgs wires none), Gatus "NetBird Mesh Connection" anchored-pair check (absence AND explicit-0 both fail closed), SigNoz scrape job + "NetBird Management Stream Down" rule (`min(netbird_management_connected) or vector(0)` < 1, critical). Files: `modules/nixos/services/netbird.nix`, `lib/ports.nix`, `modules/nixos/services/signoz.nix`, `modules/nixos/services/_signoz-alerts.nix`. This closes the exact blind spot of the 2026-10-17 8h outage (unit green, control plane dead).
2. **Multi-host parameterization** — `services.netbird-client.name` flows into client attr, `netbird-<name>` daemon/login units, state dir, config.d fragment path; default literal `"evox2"` so this host's enrolled identity (WireGuard key + dashboard peer) is untouched. deploy.sh needed zero change.
3. **Test pins** — cloud-domain test block: fragment keys + registered port + gatus check URL + restartTriggers non-empty + login-unit `requires == ["netbird-evox2.service"]` / `after` / `TimeoutStartSec == "2min"` + rpi3 rename probe (`netbird-rpi3*` units, `/var/lib/netbird-rpi3`).
4. **All gates green** — toplevel eval (`drvPath` resolves), `nix build` cloud-domain + gatus-pattern-lint + signoz-query-lint exit 0, doc-counts green after re-stamp, full `nix flake check --no-build` exit 0.
5. **Doc truthing** — runbook: new "Local metrics + mesh observability" section + v0.81 OSS feature-inventory table; README re-stamp gatus 252→253, mkRule 53→54, SigNoz 51→52 **plus line-18 quick-facts drift fixed (234→253 — it had silently lagged 19 endpoints; ungated anchor)**.
6. **Stale TODO rows closed with evidence** — "deploy the login-unit dependency fix" was ALREADY DONE (system-964 renders `Requires=netbird-evox2.service` only + 2min bound; oneshot journal shows clean NeedsLogin-guarded no-ops 20:20/21:22); the test-pin row and the parameterize row closed same day.
7. **New pbx-side row** — management `metricsPort` + `management_grpc_connected_streams` alert (server-side view of the same outage signal), `[blocked:user]`.
8. **Late verifications (ran after the first close-out, during this report's authoring)** — deployed netbird binary DOES carry `--enable-local-metrics`/`--local-metrics-address` (default 9191 confirmed via `--help`); `signoz-collector` HAS `restartTriggers` on `collector.yaml` (my scrape job activates on deploy); gatus config rides the module's yaml generation + gatus's own file watcher (endpoint waves on 10-28/29 landed live).
9. **Plan report** — self-contained HTML per the pareto-planning skill (Bauhaus template, stat cards, tiers, SVG execution graph, verification ledger, deploy handoff §07).

## b) PARTIALLY DONE

1. **THE DEPLOY NEVER HAPPENED — the pass's core value (a live signal) is not live.** Everything is eval/build-verified only. Reason: the parallel session was actively committing eval-relevant files minutes before my close-out (flake.lock floats, paperless-gpt, inboxclean, configuration.nix); deploying would have shipped THEIR in-flight tree — the documented deploy-vs-executor hazard. The quiescence procedure is written down (report §07) but unexecuted. Nothing on this host currently serves :9465, no SigNoz series, no gatus check live.
2. **My first test draft shipped a bug** — `netbirdPorts = import ../lib/ports.nix` then `netbirdPorts ? netbird-metrics` (top level is `{ ports = {...}; }`). The daemon committed it; `checks.cloud-domain` BUILD caught it; fixed by `.ports`. Root cause: my throwaway harness asserted the SAME wrong expression, so the harness gave false confidence — it validated the module correctly but mirrored my bug in the test. The layered pipeline did its job (build-time check caught what harness missed), but the harness should have used the repo's `lib/default.nix` import pattern from the start.
3. **Doc-counts re-stamp was reactive, not proactive** — I added a gatus endpoint + mkRule without grepping the README count anchors; the gate failed `nix flake check` and I re-stamped. The gate worked as designed; I paid a cycle I could have avoided with one grep.
4. **Time lost to truncated error output** — ~6 eval rounds burned because I kept piping errors through `tail -2/-3` and reading only the location trace while the actual message ("attribute 'netbird-metrics' missing", and twice my own `--raw`-with-int-output mistakes) scrolled past. The one time I read the head, the root cause fell out immediately.
5. **Plan-report timing deviates from the skill** — pareto-planning says plan FIRST, then execute; I executed the top tiers interactively and wrote the report artifact at the end. Defensible for a live session (the owner asked for execution), but recorded as a deviation.

## c) NOT STARTED (deliberately — evaluated, documented, not built)

1. **Deploy-time verification battery** — queued as a `[ready]` row gated on the deploy (9465 bound, fragment survived daemon rewrite, metric-exists, gatus green within 2 min, anchor check).
2. **rpi3 enrollment** — module is ready (`name = "rpi3"` + per-host sops key); owner-gated key mint; row added (with the one-reusable-key caveat pointing at the multi-peer decision row).
3. **SigNoz dashboard panels for `netbird_*` families** — rule lands without a panel; queued in monitoring.md (verify names against the store first — the metric-sweep doctrine).
4. **pbx management metrics** (nixpkgs `services.netbird.server.management.metricsPort`, `management_grpc_connected_streams`) — row added, pbx-artmann repo, owner deploy window.
5. **Exit node for the phone** — existing `[blocked:user]` row kept (dashboard-only: 0.0.0.0/0 route + distribution groups); burn-in since 10-15 arguably done — owner call.
6. **NetBird SSH / posture checks / peer search domains** — researched, documented in the runbook inventory, deliberately NOT adopted at a 3-peer single-user mesh (no user value; revisit triggers written down).
7. **Traffic-event logging / event streaming** — PAID (cloud/enterprise), excluded by C1 (no third-party control plane). Not revisitable without owner constraint change.

## d) TOTALLY FUCKED UP

Honestly: nothing destructive — no build breakage reached HEAD, no prod state was mutated outside deploys, no secrets touched, no other session's work reverted. The genuinely bad moments, named plainly:

1. **A broken test assertion rode a daemon commit** (`checks.cloud-domain` RED until my fix ~30 min later). The shared-tree daemon made it public before the gate caught it. Cost: a red main-branch check between commit and fix; attribution clean (mine), but it shipped.
2. **False-confidence self-verification** — the harness validated the module but ALSO validated my broken test idiom, because I wrote both from the same wrong mental model of ports.nix's shape. A verification method that shares a bug with the thing it verifies is not verification.
3. **Six wasted eval cycles on truncated error tails** — reading `tail` of Nix traces instead of the head; the third `rg -rn` strike even tripped the repo's own hook (which correctly blocked me — that guard is doing its job).
4. **Missed a 7-day fuse in the close-out** — the setup-key horizon `[decision]` row expires ~2026-11-05 (clock started 2026-10-06); I noticed it, tabled it in the report artifact, and did NOT surface it in my final message where it belongs (it blocks the rpi3 enrollment this pass just enabled).

## e) WHAT WE SHOULD IMPROVE

1. **Read error HEADS, not tails** — capture the full error to a file, read once; never pipe Nix traces through `tail` during debugging.
2. **Grep the doc-count anchors BEFORE adding endpoints/rules** — one `rg 'health checks|mkRule' README.md` before any gatus/signoz surface change.
3. **Use the repo import pattern in tests** (`inherit (import ../../../lib/default.nix lib) ports;`) — never raw `import ../lib/ports.nix` attribute paths; the shape trap cost a red check.
4. **Harness ≠ proof** — a throwaway harness is for option-surface sanity; the flake checks are the contract. Don't let harness-green license skipping the real gates.
5. **Check restartTriggers at authoring time** — I verified the collector trigger only NOW (post-close-out, prompted by writing this report). The "silently inert config" class applies to every config-file-driven service; make it part of the edit checklist, not the retrospective.
6. **Surface time-boxed decisions in the final message**, not just in artifacts — the owner reads the message; the expiry row was invisible there.
7. **Deploy decisions need the quiescence protocol as a first-class step** — my close-out said "deploy is the next step" without starting the poll loop; even a failed 4×60s poll with a recorded abort is more honest than deferring silently.
8. **Format MD/Nix immediately after every edit batch** — I did; keep it (it caught nothing this session, but the test-file "modified since read" race came from editing against a stale post-format view — re-read after fmt before editing).

## f) WHAT TO GET DONE NEXT (harvested per row)

**Immediate — this pass's completion:**
1. [ready-after-quiescence] Deploy evo-x2 (poll tree clean + no eval-relevant file <5min mtime ×≥4/60s → eval probe → `nix run .#deploy`) — §07 of the plan artifact. → services.md battery row
2. [ready] Post-deploy battery: 9465 bound / fragment survived / `metric-exists.sh netbird_management_connected` / gatus green / `netbird status` Connected / anchor == newest link. → services.md row
3. [ready] SigNoz dashboard panel(s) for `netbird_*` (p2p-vs-relay split sizes the phone-over-LTE path). → monitoring.md row
4. [ready] Observe the management-stream rule for a week: severity/interval tuning + confirm no false-fire during daemon restarts (1m gatus interval vs restart window).
5. [ready] doc-counts: add the README line-18 quick-facts anchor (ungated count drifted 19 deep). → pipeline.md row
6. [decision] Repo-native standalone module-eval harness (the `~/.cache/netbird-verify/minimal.nix` pattern) for eval-blocked windows. → pipeline.md row
7. [decision] Lint banning raw `lib/ports.nix` attribute paths in tests. → pipeline.md row
8. [ready] Mutation-test the `or vector(0)` absence leg (CASES=opt-in negative-test harness) so the rule's absence coverage is proven, not asserted.

**NetBird fleet (owner-gated):**
9. [blocked:user] rpi3 enrollment (`name = "rpi3"` + sops key; module + rename probe ready). → services.md row
10. [decision][7-DAY FUSE ~2026-11-05] Setup-key horizon 30d vs 365d — 4 surfaces move together; blocks item 9's key mint. Existing row.
11. [decision] Multi-peer setup keys + restricted policy BEFORE any non-Lars device (Kanyu) enrolls. Existing row.
12. [blocked:user] Exit node for the phone (roaming adblock + full encryption; closes the D5 plaintext non-matched-domain leak). Existing row.
13. [blocked:user] pbx management `metricsPort` + streams alert (server-side outage view; pair with the start-limit watchdog row). New row this pass.
14. [blocked:user] pbx netbird-management boot hardening deploy (M1/M12 gate rows). Existing.
15. [decision] MacBook darwin enrollment mechanism (app vs launchd CLI; headless setup-key doctrine). Existing.
16. [blocked:kanyunix] nix-netbird thin-client extraction (trigger: KanyuNix consumes a module). Existing.
17. [watch] After phone enrolls via LTE: confirm `netbird_peers_connected{connection_type="relay"}` appears and relay gatus check (404 leg) matches reality.
18. [watch] Fragment key stability across netbird client bumps (0.81 → next): re-verify `LocalMetrics*` field names on upgrade (the pinned-key drift class).
19. [watch] Textfile-collector fallback (`netbird status` → .prom) if local-metrics breaks on an upgrade — the repo-native pattern as plan B.
20. [watch] `disableAnonymousMetrics` on the pbx management server (C1 privacy: client push telemetry should stay off — pbx-side verify).
21. [watch] Networks/zero-trust resources: whole-/24 masquerade today; finer-grained resource exposure is a dashboard+provisioner change if the owner wants least-privilege LAN slices.
22. [watch] IPv6: the advertised route is v4-only; LAN has no IPv6 story (matches the router plan's posture row).
23. [decision] Phone `BlockLANAccess`/`BlockInbound` posture — the phone can currently reach the whole LAN; owner intent unknown.
24. [blocked:push] Upstream nixpkgs PRs: bound the login poll loop; `managementUrl` module option (the NB_MANAGEMENT_URL env workaround is a workaround). Existing rows, verify-before-filing first.

**Adjacent noticed (not this session's scope):**
25. [ready] node-exporter `connection reset by peer` scraper chronic resets (156k/day class) — pre-existing row, still live through gen-962.
26. [watch] monitor365 io.stat re-attribution (existing row).
27. [ready] monitor365 SSO-identity gatus assertion (existing row).
28. [ready] float-register 72-char subject + verify-commit-landed (existing rows — the float wave that unblocked my eval was theirs; discipline held).
29. [blocked:user] CI NIX_GITHUB_PAT for private lock-node tarball fetches (existing row; 300+ nodes 404 on CI).
30. [ready] signoz-coverage expiring last-verified dates (existing row — my pbx metrics row will eventually need one too).
31. [watch] The SUPERB-4g router plan (parallel session) — if the CPE becomes 192.168.1.1, the DNS nameserver group's 192.168.1.53 target and the LAN route stay valid, but re-verify post-cutover.
32. [watch] NetBird relay: if LTE CGNAT peers become primary, evaluate a second relay or TURN config (single-relay coupling accepted by D2).
33. [ready] Prune the three `[x]` rows I closed to CHANGELOG at the next prune pass (rules: prune per pass, expect WARN recount).
34. [watch] gatus 1m interval on the mesh check: journal noise budget (the 2026-09-28 130k-lines/day lesson) — confirm the INFO silence still holds with +1 check.
35. [decision] Whether the exit node should also carry the rpi3/roaming DNS resolver role (nameserver group currently → 192.168.1.53; exit-node DNS would ride evo-x2).
36. [ready] After deploy: clean `~/.cache/netbird-verify/` (keep until the battery passes — it holds the harness evidence).
37. [watch] Client 0.81 `--enable-json-socket` (HTTP daemon status without root) — alternative for future user-level collectors; not needed while collectors run as root.
38. [decision] SigNoz rule severity: management-stream is `critical` (8h-outage class) — confirm the owner wants mesh breakage paging at SEV1 vs warning.
39. [watch] The 154-WARN unharvested-report backlog (grew through tonight's parallel sessions; next docs-health HARVEST pass).
40. [watch] netbird events API (OSS) for enrollment/peer-change auditing via PAT — unexplored; low value now, nonzero once non-Lars devices exist (pairs with item 11).

## g) QUESTIONS (owner-only)

1. **Deploy go/no-go:** the tree is flake-check-green NOW, but the parallel session's paperless-gpt/inboxclean/configuration.nix changes are in the same tree. Do I deploy as soon as quiescence is met (shipping their work), or do you want to gate the deploy on their session declaring completion?
2. **Setup key horizon:** the enrollment key expires ~2026-11-05 (7 days). Rotate to 365d via the 4-surface move now, or keep 30d and re-mint per enrollment? This directly gates the rpi3 enrollment this pass just made trivial.
3. **Mesh paging severity + exit node:** should a lost management stream page at critical (Discord, as shipped), and is the phone exit node (burn-in done 2026-10-15) green-lit for dashboard config in the next owner window?

---
*Verification chains: harness `~/.cache/netbird-verify/` (minimal.nix + plan.d2/svg + built rule.json); live probes: busctl unit states, login oneshot journal 20:20/21:22, deployed unit text, `netbird up --help` flag surface; gates: toplevel eval, cloud-domain/gatus-pattern-lint/signoz-query-lint builds exit 0, doc-counts, full flake check exit 0. Errata: initial "deploy owed" row was stale (fix already deployed in system-964); `name` default deliberately deviates from the original hostName prescription (state-dir identity migration = silent re-enrollment risk), recorded in the closed row.*
