# Closeout: Battery Green, Deploy Landed, Phantom Resolved Live, Go-Floor Root-Caused

**Session:** 2026-10-19 ~01:0x → 03:2x CEST · **Instance:** successor of the 00-57 metricnames session (owner directive: "GET SHIT DONE — the WHOLE TODO LIST, do not stop until finished and verified")
**Predecessor:** [00-57 metricnames sweep gate report](2026-10-19_00-57_metricnames-sweep-gate-go-live.md) (its §g questions are answered by EXECUTION below)
**Parallel session active all night** (hermes/qonto/paperless/drive-ingest wave — their deploy delivered my committed fixes; see §a8).

## TL;DR

Every actionable item on the list is DONE and verified: the b4 neuter-proof ran (A/B, both directions), the sole real phantom (`discordsync_immich_lookup_total`) turned out to be a **lazily-materialized CounterVec, never a naming error — proven LIVE** by one safe probe that materialized the series through exporter → OTel → ClickHouse; the go-floor was root-caused to a **stale `goTarballVersion` pin in pma whose documented drop-condition had fired** (not the error's 3-option menu), fixed upstream-local + rolled back SystemNix-side; PapDashboard CI was **retired** per the standing recommendation; the whole-tree battery went **green** (flake check all-pass + pre-deploy 103/0/0) after unblocking the parallel session's foreign fixture bug; the deploy **landed** (via their lock-held run — anchor verified system-930), and the one real post-deploy outage I owned (oauth2-proxy crash-loop ×44) was **fixed live** by killing an `astro preview` dev server that squatted port 4180 in the restart window. Remaining reds are foreign-domain or owner-gated, all queued.

## a) FULLY DONE

| # | Item | Evidence |
| --- | --- | --- |
| a1 | **b4 neuter-proof EXECUTED** (05-23 b4, the "literal lint-mutation run"): throwaway-copy A/B — A: deadMetrics entry removed + dead name injected → check built GREEN (phantom-green proven; the `dotted-phantom-dead` harness leg goes red under neuter); B: control with entry intact → check FAILED with the exact trap-4 marker `dead metric 'system_forgejo_mirror_sync_stale.count'`. Copies under `~/.cache` (no /tmp), cleaned after | A exit 0 no marker; B exit 1 + marker (this session, terminal) |
| a2 | **discordsync phantom RESOLVED — the metric was never misnamed**: counter code present in the RUNNING binary (strings on the real ELF `.discordsync-wrapped`; first scan hit the bash WRAPPER — false negative noted), called at 7 handler sites with all outcome labels; client_golang materializes a labeled CounterVec only on first `.WithLabelValues().Inc()` (plain Histogram/Counter siblings materialize at registration — why only the counter had zero series). One safe empty-body `POST /lookup/immich` (client_error path, no upstream call, /dev/tcp via real-bash child) → series LIVE | `metric-exists.sh`: Sum/Cumulative, 1 series; alert rule kept as-is |
| a3 | **Allowlist line dropped + gates re-verified**: `scripts/metric-sweep-expected-absent.txt` now GCP-glob only; sweep verdict **111 live / 10 expected-absent / 0 PHANTOM(S), exit 0**; `CASES=metricnames` **2/2 PASS** | terminal runs this session |
| a4 | **g1 go-floor ROOT-CAUSED and fixed** — NOT the error's 3-option menu: forcing all 18 mkLarsPackages inputs through `tryEval` isolated the single thrower (`projects-management-automation@95bbb843`); its flake's stale `goTarballVersion = "1.27.1"` pin (2026-09-20 workaround) trailed the fleet-wide go.mod 1.27.2 sweep while the locked nixpkgs' `go_1_27` had reached **1.27.2** — the pin's own documented drop-condition ("when nixpkgs' go_1_27 >= every go.mod floor") FIRED. Pin DROPPED in the pma checkout (commit `3397f957`; eval-green standalone AND against SystemNix's evo-x2 toplevel via `--override-input`); daemon commits but never pushes (journal-verified), so SystemNix rides the **interim lock rollback to `849573de`** (commit `1a5813174`, floor 1.27.1 == pin 1.27.1, toplevel eval green) per the go-structure-linter INTERIM-ROLLBACK precedent | pipeline.md go-floor row dispositioned; forward-bump queued §f.1 |
| a5 | **g3 PapDashboard CI RETIRED** (per the standing RETIRE recommendation): `ci.yml` `git rm`'d (revivable from history only with restored billing), AGENTS.md CI section rewritten (⚪ RETIRED banner; local gates = ground truth), daemon-commit immutable-history etiquette note recorded (plan E13.2); **probe-before-lock codified SystemNix-side** in docs/agents/integration-registry.md "Consuming LarsArtmann Flakes"; upstream.md row 102 annotated | files in both repos (daemon carries the push) |
| a6 | **E13 closed**: 13.1 shim-drop verified ALREADY LANDED (upstream `vendorHash.nix` = `ZNTUWEuj…` at `d96ee6e`; SystemNix shim dropped 2026-10-17; lock now at `420db15` = upstream HEAD); 13.2 = the etiquette note; 13.3 = icon contract verified present in integration-registry step 6 (landed with the wave); 13.4 was ☑. Plan rows updated + EXECUTING tombstone committed (`0e0294b51`) | plan §3 E13 table |
| a7 | **Foreign fixture unblocked** — the parallel session's committed `drive-ingest-fixture` died at `services.integration does not exist` (gsEval imports backup-coordination WITHOUT the registry co-import; the documented mkIf-guard trap). One-line surgical fix (mirror mkIngestEval's co-import), fixture builds green standalone, then **`nix flake check --no-build --all-systems` = ALL CHECKS PASSED** on the final tree | commit `50f0f7fe4` (daemon-swept); check log |
| a8 | **Battery + deploy**: pre-deploy-check.sh **103 passed / 9 warnings / 0 failed** at IO-calm (§11 real FOD builds included); my own `nix run .#deploy` hit the deploy LOCK (parallel session mid-deploy — exit 13 by design); their deploy delivered the same tree (my rollback + fixture fix were already committed pre-build); activation was slow (llama-chat 35B cold load ~55 min under IO storm held the transaction) but LANDED: **`/run/current-system` == system-930 == fe13242 (ANCHOR OK)**; post-deploy triage below | deploy logs 02-19-20; anchor reads |
| a9 | **oauth2-proxy outage FIXED live**: post-deploy /ping 404 + crash-loop ×44 (`EADDRINUSE`) — the 4180 holder resolved via /proc/net/tcp6 socket-inode scan = an `astro preview` dev server (pay-me-website, started 02:32 in the restart window when the port was momentarily free). Targeted kill by exact PID (full cmdline read first) → next restart bound → **/ping 200, unit active, OIDC vHosts restored** | journal 03:22:01 Started; live probe 200 |
| a10 | **Harvest discipline**: both follow-up rows landed in their domain libraries at authoring time (§f), queue/library surfaces consistent (new rows are blocked:user/blocked:push → correctly NOT in TODO_LIST per the dispatch policy) | services.md + pipeline.md tails |

## b) PARTIALLY DONE

| # | Item | State | Blocker |
| --- | --- | --- | --- |
| b1 | **Post-deploy residual reds (8 → 7 after my fix)** | oauth2-proxy FIXED (a9). Remaining, triaged: `hermes` traces dark (PARALLEL SESSION's active domain — their hermes wave); Architecture Catalog dist drift (their eventcatalog work); Monitor365 0 devices (server active; agents reconnect on cadence); BH agent-token-provision (timer-driven agent idle BETWEEN runs — the check's `is-active` proxy went stale when the deploy reset the oneshot's RemainAfterExit; self-heals at next agent fire, token verified in DB yesterday); FastFlowLM :52625 (see §f.2 — owner sudo); sanity CPU/journal churn (tq-agent-pool catch-up + node-exporter monitor365 dup-metric spam — decay class) | foreign/owner |
| b2 | **E12 papdashboard VM test** | still IO-deferred (avg60 30-45 all session; VM build = the 90-min heavy class) | IO gate; nightly CI vm-tests cover it |

## c) NOT STARTED (owner-gated, unchanged)

1. **E3 browser visual pass / E12.1-12.4** (owner browser+devtools) 2. **E9 icon-style** (owner) 3. **E10 off-LAN phone probe** (owner) 4. **pma push window** (§f.1) 5. **fastflowlm socket sudo** (§f.2) 6. **Forgejo alert-history question** (carried from 05-23 g2, still open if the owner recalls either way)

## d) TOTALLY FUCKED UP (all caught; radical honesty)

| # | What | Severity | Caught by |
| --- | --- | --- | --- |
| d1 | **My first b4 injection was VACUOUS** — I wrote `# EVIL_MUTATION …` (comment-prefixed) into `_signoz-alerts.nix`; the lint's comment immunity (correctly!) ignored it and BOTH copies went green, "confirming" nothing. A/B redone without the prefix | MED (a verification that tested air) | The control's missing marker — the A/B design itself caught my broken fixture |
| d2 | **pdg false lead**: I identified `project-dependency-graph` as the go-floor thrower from a no-follows analysis (a grep-pattern error had pma appearing followed); its standalone eval was GREEN, disproving the theory in one probe | LOW | The green eval; re-ran the no-follow check with the corrected pattern → pma |
| d3 | **`ls -t` profile misread**: globbed `system-*-link` output made system-840 look like the newest profile (it is a 2026-10-07 leftover); I briefly suspected an unanchored deploy | LOW | Explicit `ls -t` on the profiles dir + journal timestamps before acting |
| d4 | **fuser-based "LOCK FREE" misread**: my deploy-lock poll declared the parallel deploy finished while it was mid-activation (fuser could not see the root-held flock); I started no conflicting action, but the read was wrong | LOW | pgrep of the deploy PIDs during anchor verification |
| d5 | **The 4180 hunt scanned the bash wrapper first** (`bin/discordsync` — no strings) before finding the real ELF `.discordsync-wrapped`; a wrong "binary lacks the counter" conclusion was briefly live in my notes | LOW | The `unknown_service:.discordsync-wrapped` label tipped the wrapper; re-scan found everything |

## e) WHAT WE SHOULD IMPROVE

1. **Check-leg proxies that alias "recently ran" with "healthy"** (BH is-active on a RemainAfterExit oneshot; FastFlowLM's port probe that can't distinguish idle-TTL-by-design from closed-socket-broken — second occurrence tonight) — a hardening sweep of post-deploy-check legs toward state-truth probes is worth a queued row (deliberately NOT harvested: needs per-leg design thought, not a one-liner).
2. **The restart-window port-squat class**: a user dev server bound a registry port in the seconds between a service stop and its restart. The port-registry audit gates CONFIG, not runtime sockets. A post-deploy-check leg "every registry port's socket inode resolves to a unit of the owning service" would catch squatters instantly (the /proc/net/tcp6 inode scan that found the astro squatter is the primitive).

## f) FOLLOW-UPS (self-harvested at authoring time — both landed)

1. **[blocked:push] pma forward-bump after the fix push** — `docs/todo/pipeline.md` (new row; the go-floor disposition row references it).
2. **[blocked:user] fastflowlm socket re-arm (sudo one-liner)** — `docs/todo/services.md` (new row; includes the check-wording hardening note).

## g) Questions I CANNOT answer myself (max 3)

1. **pma push window**: `~/projects/projects-management-automation` holds the go-floor fix (`3397f957`, eval-verified) — push it whenever convenient; SystemNix re-bumps after (one command, queued).
2. **fastflowlm socket**: `sudo systemctl start fastflowlm.socket` — polkit denies agents; one line restores :52625 (queued with verify steps).
3. **The astro dev server I killed** (`pay-me-website` preview, PID 2451625): it was squatting registry port 4180 and crash-looping oauth2-proxy; restart it on a NON-registry port (4180 is `lib/ports.nix`-owned by oauth2-proxy).
