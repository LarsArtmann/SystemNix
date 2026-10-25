# Status Report — Caddy Feature Deep Dive Session

**Date:** 2026-10-25 17:44 CET
**HEAD at authoring:** 8740dba10 (auto-commit daemon; report HTML swept into it)
**Scope:** ONE task this session — the Caddy library deep dive (skill: `library-deep-dive`), end to end. Nothing else was researched or changed, per instruction.
**Session outputs:**
1. `docs/research/2026-10-25_caddy-deep-dive.html` — the audit (41-row capability inventory, score 89/100, 3 findings, how-to-verify appendix)
2. `docs/services/caddy.md` — "Feature deep dive (2026-10-25)" memory section (verdict + refresh triggers)
3. Verification artifacts in `~/.cache/caddy-deep-dive/` (3 screenshot crops)

**Format note:** the status-report skill is HTML-canonical; this report is `.md`
because the operator explicitly named the `.md` path in the dispatch. Flagged
per the skill's override rule; not propagated back into the skill.

**Harvest disposition (AGENTS.md §f rule):** the §f items below are
deliberately NOT yet harvested into `TODO_LIST.md` / `docs/todo/services.md`
because the dispatch ordered "report, THEN WAIT FOR INSTRUCTIONS". The direct
follow-ups are marked `[harvest-candidate]`; queue them on owner approval
(see question g1).

---

## a) FULLY DONE

Each item verifiably complete with evidence.

| # | Done | Evidence |
|---|------|----------|
| a1 | **Phase 0 — prior-report + domain pre-read.** Confirmed no prior Caddy deep dive in `docs/research/` (33 existing reports checked by listing); read `docs/services/caddy.md` (244 lines) + `docs/agents/sso-dns.md` per the AGENTS.md routing table before touching the domain. | session tool log; no `*caddy*` in docs/research/ before today |
| a2 | **Phase 1 — full project discovery.** Read `modules/nixos/services/caddy.nix` end to end (941 lines); cataloged the touched Caddy surface (directives: tls/header/encode/request_body/tracing/reverse_proxy/forward_auth/handle_errors/redir/respond/root/file_server/rewrite/metrics/log + matchers); mapped consumers (SigNoz scrape signoz.nix:1210, gatus :2019 check, crowdsec acquis crowdsec.nix:83-95, geometrikks tails geometrikks.nix:56-75); registry vHost shape (integration.nix); VM tests (test-caddy-{auth,logs-hot,mint}.nix); port registry entry (caddy-metrics 2019). | grep inventories in session; directive counts extracted |
| a3 | **Phase 2 — capability research from upstream.** Full Caddyfile directive list (39 directives incl. intercept/log_append/log_skip/log_name); changelog 2.10.x→2.11.7; `metrics { per_host }` semantics + 2.11 cardinality bounding + 2.11.2 per-route CPU fix (#7492); reverse_proxy health-check/LB/flush_interval/XFF-trust semantics (2.8+ default: no trusted proxies); servers timeouts (2.11.6 slowloris defaults); `format journald` encoder (2.11.3, #7623); log filters/sampling; the critical `handle_errors` vs proxy-502 semantics (dial failures → error routes; upstream 5xx responses do NOT trigger them — caddyserver/caddy#7283 maintainer quote); `caddy.withPlugins` verified callable in this nixpkgs (`__functor` eval → true). | fetched docs pages + releases in session; eval command output |
| a4 | **Version currency established.** `nix eval nixpkgs#caddy.version` → 2.11.7 = upstream latest (v2.11.7, 2026-10-03). Zero version gap; all 2.11 CVE fixes + slowloris defaults live. | eval output in session |
| a5 | **Phase 3+4 — gap analysis + scoring with published rubric.** 41 capability rows graded: 24 fully leveraged, 3 missed opportunities, 14 N/A (each with a reason), 0 misused. Score = round(100 × 24/27) = **89/100 — very high**. Inputs published in the report's derivation block. | appendix table + derivation block in the HTML |
| a6 | **Phase 5 — HTML report written correctly.** Copied the editorial template (no line-splicing) and replaced all demo content: hero, 5 scorecards, summary, 10 strengths with citations, 5 findings, version table (6 rows), Pareto opportunities (5 rows), 41-row appendix inventory, score derivation, how-to-verify appendix. Final size 64,923 bytes, 7 sections. | `docs/research/2026-10-25_caddy-deep-dive.html`; `grep -c "<section"` → 7 |
| a7 | **Self-consistency gates run AND one real bug caught+fixed.** Denominator re-count via grep: 24 FL / 3 MO / 14 NA = 41 rows ✓. Priority table verified sorted 25/15/10/8/3 ✓. **Caught:** the report's own verify commands (`grep -o 'st-FL'`) would have self-matched their code-block copies and printed 26/5/16 — replaced with a non-self-matching pattern (`grep -oE 'class=.st-(FL|MO|NA)' … | sort | uniq -c` → now yields 24/3/14). Also chased a suspected span imbalance (72 opens vs 67 closes) to ground truth: the template's split-line `</span\n>` style — balanced 72/72, not a bug. | gate outputs in session log |
| a8 | **Phase 8 done-bar: quality gate green.** `nix flake check --no-build` → "all checks passed!" (aarch64-darwin omission warning is the documented expectation). | background shell 01D output |
| a9 | **Phase 8 done-bar: browser screenshot verification.** Headless chromium (playwright build from /nix/store) — three crops verified visually: hero/scorecards/strengths/finding-1; findings 2-4; version table/opportunities/full inventory/derivation/verify/footer. No broken layout; score cards show the derived numbers. | `~/.cache/caddy-deep-dive/report-{top,findings,mid}.jpg` viewed in session |
| a10 | **Phase 8 done-bar: memory written.** `docs/services/caddy.md` gained "Feature deep dive (2026-10-25)" — verdict line, the 3 findings with file refs, refresh triggers (next caddy major bump / finding adoption / helper-architecture change). | section present at caddy.md (pre-"2026-09-30 config review") |
| a11 | **Concurrent-session discipline held.** Two live collisions handled by re-read-then-edit (report file modified-under-me; caddy.md modified by a parallel session at 17:03). No foreign work reverted, no stale writes landed. | edit-tool rejects + recovery in session log |

## b) PARTIALLY DONE

| # | Item | What works | What remains | Blocker / effort |
|---|------|-----------|--------------|------------------|
| b1 | **Live-loop closure of the audit.** The audit graded the Nix SOURCE with doc+changelog verification, but never probed the LIVE host: no `caddy validate --config /etc/caddy/caddy_config`, no rendered-config diff, no live `:2019/metrics` pull to confirm `caddy_http_*` series names before writing dashboard queries. | Source-level claims all cited; series names cross-checked against the existing dashboard's queries | the two live probes | None — S each. (Runbook documents `caddy validate` as available.) |
| b2 | **§f harvest.** Items marked `[harvest-candidate]` in §f are fully specified but NOT queued. | full spec written here | `TODO_LIST.md` + `docs/todo/services.md` rows | Waiting on g1. S. |
| b3 | **`docs/research/README.md` index.** Does not exist (verified in Phase 0). Skill says: add a row if it exists, else note in handoff — noted here only; index not created. | handoff note (this report + chat) | creating the index for all 34 reports | Scope call, S. |
| b4 | **Commit state.** No manual commit (harness forbids without explicit "commit" — critical rule 6). The daemon swept the report mid-edit (fa8f5b6f9) and again with the final-ish file (8740dba10, 8 files, MIXED sessions). caddy.md memory edit was still uncommitted at authoring time. | report is committed (daemon); working tree clean of my other changes | caddy.md edit rides the next daemon tick | None. Attribution blur → see d3. |
| b5 | **Citation verification depth.** Every finding cites file:line and docs URLs, and key claims were grep-verified during the session; but I did not re-verify every one of the 41 rows' citations after the final edits. | the load-bearing citations (findings, score inputs, consumer paths) were checked; spot-check commands are embedded in the report's appendix for the reader | a full line-by-line citation sweep | S-M; the appendix's how-to-verify block IS the tool for this. |

## c) NOT STARTED

Planned outputs of this session that produced zero code/config changes (by design — the session was an audit; adoption is follow-on work). All are fully specified in the deep-dive report.

| # | Planned | Why not started | Priority |
|---|---------|-----------------|----------|
| c1 | `metrics { per_host }` adoption + dashboard host panels + per-host 5xx alert | audit-only session; waiting on owner go | Critical (finding 1) |
| c2 | Branded 502/503/504 error route in the vHost helpers | same | High (finding 2) |
| c3 | Runtime logs → journald (finding 3) — BLOCKED on the geometrikks access.log tradeoff decision (g2) | owner decision | High, blocked |
| c4 | Explicit `read_body` timeout pin | polish, queue anytime | Medium |
| c5 | Rate-limit stance row (crowdsec stage-3 primary, caddy-ratelimit recorded alternative) | documentation row, queue anytime | Low |
| c6 | Deep-dive refresh on next caddy major bump | trigger not fired | watch |

If §c is ~half the report: that is the correct shape for an AUDIT session — the deliverable is the finding set, not the fixes.

## d) TOTALLY FUCKED UP

Nothing is broken in the repo, no data was lost, and no deploy was touched. Four honest closest-misses, all self-caught (per the "be too gentle" pitfall, these are named exactly):

| # | What happened | Severity | Root cause | Mitigation / status |
|---|--------------|----------|-----------|---------------------|
| d1 | **Self-matching verify commands shipped into the report draft.** The how-to-verify block's `grep -o 'st-FL'` pattern would have counted its own code-block occurrences (26/5/16 instead of 24/3/14) — a report whose own verification instructions return wrong numbers. | Would have been a credibility defect in the deliverable | Didn't think about self-reference when writing the commands | **Caught by my own consistency gate before final**; fixed with a non-self-matching pattern; re-run confirms 24/3/14. Closed. |
| d2 | **`rg -rn` replace-trap tripped the guard TWICE at session start.** The exact mangled-output class AGENTS.md documents (third-strike trap on this host) — I typed the known-wrong flag form twice in my first two searches. | Zero damage (hook blocked at parse; no mangled output was ever displayed or cited) | Pattern-matched grep's `-rn` muscle memory | Hook caught both; corrected to `rg -n` / grep tool for the rest of the session. Closed, but it's the same trap for the third documented time — see e6. |
| d3 | **The report rode mixed daemon commits.** An intermediate HALF-EDITED draft (demo content + 5 real sections) is in history via fa8f5b6f9; the final file landed in 8740dba10 together with a parallel session's files. A history bisect would find a broken-looking report; blame on 8740dba10 is blurred across sessions. | Cosmetic (point-in-time snapshots; daemon behavior is documented doctrine) | Auto-commit daemon sweeps every ~10 min by design | None needed; flagged per the concurrent-agent attribution rule. |
| d4 | **Four wasted edit calls on stale read-state.** One transient "file not found" (file existed), one "modified since read" on the report, two on caddy.md — because I edited from bash-grep freshness instead of View freshness while a parallel session was live. | Zero damage; all retries clean | Forgot my own session discipline: in a shared tree, `view` immediately before every `edit` | Re-read each time; all edits landed. Closed — see e2. |

## e) WHAT WE SHOULD IMPROVE

Process and craft improvements from this session — answering the three asked questions directly.

### What did I forget?
- **The live loop (b1).** The runbook hands me `caddy validate --config /etc/caddy/caddy_config` and a scraped :2019 — I audited the source and the docs and never once probed the running proxy. A "verified" label on a config audit should ideally cover the rendered config too, not just the Nix that generates it.
- **`docs/agents/monitoring.md`.** The routing table says read it before working on SigNoz rules/dashboards — and findings 1-3 land exactly there. I read the caddy + sso docs but not the monitoring agent doc. Item f49.
- **Format double-check speed.** The skill is HTML-canonical; I should have flagged the `.md` override expectation in my FIRST message instead of at the end (it is flagged now, per the skill's rule).

### What could I have done better?
- **Precise intermediate verification (e1).** One mid-session check was `grep -c "strength\|Derived smoke"` → "19" and I moved on. That number verified nothing. The final gates were rigorous; the intermediate ones should have been too.
- **View-before-edit in shared trees (d4).** Four tool calls burned on stale read-state. In this repo the daemon + parallel sessions touch files continuously — `view` immediately before `edit` is the standing discipline and I lapsed on it.
- **One-pass screenshot coverage.** I took the 3600px top shot, then re-shot at 12000px and cropped twice more. One full-page shot + three planned crops from the start would have been two fewer browser launches.
- **Inventory granularity (f20).** Rows #8/#9 bundle 9+ directives into single N/A rows. Defensible grouping, but per-directive rows would make the next refresh a diff instead of a re-audit.

### What could we still improve?
- **e1. Precise asserts at every verification step** — a check whose output you didn't predict is not a check. Impact: catches drift bugs (like d1) at authoring time. Fix: every intermediate gate gets an expected value written BEFORE running it.
- **e2. View-before-edit as reflex in this repo** — Impact: avoids stale-write risks, not just wasted calls. Fix: personal discipline + this report as the reminder.
- **e3. Live-probe leg as a standard audit phase** — source-level library audits in this repo should end with the runbook's live probes (validate + rendered-config diff + metrics pull). Fix: fold into how the deep-dive skill is applied here (f11/f12).
- **e4. `docs/research/README.md` index** — 34 reports, zero index; discoverability currently depends on `ls`. Fix: one table (subject, date, refresh trigger) (f21).
- **e5. Audit report format override recording** — when a dispatch demands `.md`, the report should carry the override flag in its header (done here) so format conventions stay auditable.
- **e6. The `-rn` rg trap keeps recurring across sessions (documented third strike).** Impact: guard-blocked calls, near-miss corruption of readings. Fix candidate for skill/tooling feedback-loop: a shell alias/whitelist note in the agent rc, or add to the session-start banner.
- **e7. Screenshot artifacts live in `~/.cache`** — survives longer than /tmp but is still cache; if re-verification evidence matters, it needs a durable home or the report's commands must be able to regenerate it (they can — the appendix includes them).

## f) TOP 50 THINGS WE SHOULD GET DONE NEXT

Ranked by impact. Effort: S <30min, M 30min-2hr, L >2hr. `[harvest-candidate]` = direct follow-up of this session's findings, ready to queue on owner approval (see g1).

**Adopt the findings:**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Enable `metrics { per_host }` in caddy.nix `globalConfig` (one word) `[harvest-candidate]` | Critical | S | Feature |
| 2 | Add host-dimension queries to `dashboards/caddy.json` panels (currently 7× aggregate `sum()`) `[harvest-candidate]` | High | M | Feature |
| 3 | Add SigNoz alert: per-host 5xx rate from `caddy_http_requests_total{code=~"5.."}` `[harvest-candidate]` | High | M | Feature |
| 4 | Create branded 502/503/504 page derivation (sibling of `notFoundRoot` linkFarm) `[harvest-candidate]` | High | S | Feature |
| 5 | Wire `handle_errors 502 503 504` into plainVHost/protectedVHost/renderVHost + catch-alls `[harvest-candidate]` | High | S | Feature |
| 6 | Optional: `handle_response @e status 5xx` for upstream-response 5xx branding (distinct from dial-failure path) | Medium | S | Feature |
| 7 | DECISION: runtime logs → journald (`output stdout` + `format journald { wrap json }`) — displaces access.log; geometrikks tail tradeoff `[harvest-candidate, blocked on g2]` | High | M | Decision |
| 8 | If 7 = yes: update geometrikks caddyLogPaths, runbook log map, and test-caddy-logs-hot expectations | Medium | M | Feature |
| 9 | Pin `servers { timeouts { read_body 15m } }` (bounds 10GB trickle uploads) `[harvest-candidate]` | Medium | S | Quality |
| 10 | Record rate-limit stance row (crowdsec stage-3 primary; caddy-ratelimit + withPlugins as recorded alternative) in docs/todo/services.md | Low | S | Documentation |

**Close the audit's own live-verification gap:**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 11 | `caddy validate --config /etc/caddy/caddy_config` + diff rendered Caddyfile against the audit's source-level claims | High | S | Quality |
| 12 | Live-probe `:2019/metrics` to confirm `caddy_http_*` series names before dashboard work | High | S | Quality |
| 13 | Verify `per_host` cardinality on live /metrics after adoption (host label count ≈ vHost count + `_other`) | Medium | S | Quality |
| 14 | Confirm the `:80` redirect matcher covers `*.larsartmann.cloud` HTTP requests as intended (caddy.nix:515) | Medium | S | Quality |
| 15 | Check static vHost (timers/catalog) 404 UX — they lack `handle_errors` branding (only catch-alls have it) | Medium | S | Feature |
| 16 | Verify no long-running SSE stream (llama-chat) stalls on the 2.11.6 `write_idle` 1m default (2.11.7 fixed the quiet-stream reset regression — confirm behavior) | Medium | S | Quality |
| 17 | Confirm `request_body max_size 10GB` global scope is intended (only Immich-class uploads need it) | Low | S | Quality |
| 18 | Audit remaining `hostOverride` users (bank-sync class) — still needed? | Low | S | Cleanup |
| 19 | Re-verify monitor vHost cache-override redundancy row vs deployed monitor365 rev (runbook says removal tracked) | Low | S | Cleanup |
| 20 | Re-verify the KNOWN-FAILING dnsblockd catchall-probe row in docs/todo/services.md is still accurate | Low | S | Documentation |
| 21 | Re-check `?Cache-Control` global backstop after monitor365 immutable rollouts | Low | S | Quality |
| 22 | If a third DNS zone ever appears: mint SAN list (caddy.nix:835) must grow — consider an assertion tying mint SANs to networking.local options | Low | S | Quality |

**Report/handoff infrastructure:**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 23 | HARVEST approved §f items into TODO_LIST.md + docs/todo/services.md `[harvest-candidate, blocked on g1]` | High | S | Process |
| 24 | Create `docs/research/README.md` index (34 reports, subject/date/refresh-trigger table) | Medium | S | Documentation |
| 25 | Read `docs/agents/monitoring.md` BEFORE implementing items 2-3 (routing-table requirement I skipped this session) | Medium | S | Process |
| 26 | Add deep-dive refresh trigger (next caddy major bump / finding adoption) to a watch surface | Low | S | Documentation |
| 27 | Give the verification screenshots a durable home or rely on the appendix's regenerable commands (currently `~/.cache/caddy-deep-dive/`) | Low | S | Process |
| 28 | Feed back to skill maintenance: library-deep-dive's Context7 MCP tools are absent in this harness (agentic_fetch substituted successfully) | Low | S | Documentation |

**Module hygiene noticed during discovery:**

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 29 | paperless registryBlindSubdomains row says "delete if it moves to the registry" — track that cleanup | Low | S | Cleanup |
| 30 | auth/seo/tasks registry-registration deferrals (§g.2/§g.3 pending) — confirm the pending rows exist | Low | S | Documentation |
| 31 | alerts legacy alias vHost — eventual-removal candidate once old bookmarks age out | Low | S | Cleanup |
| 32 | Add module-level comment for the enableReload-avoidance rationale (currently runbook-only) | Low | S | Documentation |
| 33 | `vhostLayerLines` "first localhost: line" port heuristic — tech-debt note; could parse helper output directly | Low | M | Quality |
| 34 | VM test for the 502 error route when item 5 lands (extend test-caddy-auth) | Medium | S | Quality |
| 35 | If per_host adopted: drift-guard lint asserting `per_host` stays in globalConfig (pattern: existing audit lints) | Low | S | Quality |
| 36 | Document the "correct by default" security posture in the runbook (XFF no-trust since 2.8, log credential redaction, log_credentials correctly absent) | Low | S | Documentation |
| 37 | Verify `Permissions-Policy` header value still matches intent (geolocation/mic/camera off) | Low | S | Documentation |
| 38 | Consider `log_skip` for health/smoke probe noise (gatus + post-deploy probes land in access logs) | Low | S | Quality |
| 39 | Consider `roll_compression zstd` for access-log rolls (2.11.2 feature; CPU win at roll time) | Low | S | Quality |
| 40 | Revisit per-vHost log roll budget (defaults 100MiB×10/file; aggregate grows with vHost count — 2026-09-30 disposition #9) | Low | M | Quality |
| 41 | Split bundled inventory rows #8/#9 into per-directive rows on the next deep-dive refresh | Low | S | Documentation |
| 42 | Keep the seo GSC-callback hand-rolled vHost as-is ("do NOT simplify") — add a watch note only if a second callback-exempt vHost appears | Low | S | Documentation |
| 43 | Immich hybrid-auth regression probe after any protectedVHost helper change (mobile-app bypass doctrine) | Medium | M | Quality |
| 44 | Ensure nixpkgs input bumps stay regular so caddy security fixes keep landing same-day (the version-currency lever) | Medium | S | Process |
| 45 | Check CHANGELOG convention for deep-dive reports (forgejo/dnsblockd precedents — changelogged or not?) | Low | S | Documentation |
| 46 | Confirm OTEL exporter budget note (26h request-driven, commonConfig comment) unaffected by per_host change | Low | S | Documentation |
| 47 | Re-run otel-endpoint-audit + signoz-coverage "caddy" legs after any caddy.nix change | Low | S | Quality |
| 48 | Annotate the deep-dive report as superseded per docs-health ANNOTATE mode once findings are adopted | Low | S | Documentation |
| 49 | Next audit session: run the live-probe leg (items 11-12) as a mandatory phase, not a gap | Medium | S | Process |
| 50 | Answer g1-g3 below — the actual unblocker for items 1-10 and 23 | High | S | Process |

Items NOT listed deliberately: anything requiring research beyond this session's scope (per dispatch instruction); crowdsec stage-3 enablement itself (owner-gated roadmap, only the stance row is queued as item 10).

## g) THREE QUESTIONS I CANNOT FIGURE OUT MYSELF

**g1. Should I harvest now, or wait for explicit approval?**
AGENTS.md doctrine says status reports must self-harvest their §f direct follow-ups at authoring time; your dispatch says "report, THEN WAIT FOR INSTRUCTIONS". I resolved it by recording the disposition in the report header (deliberately not harvested) — but which instruction wins for items 1-10/23? What I tried: re-read both the AGENTS.md TODO-system rule and your dispatch; both are explicit; only you can rank them.

**g2. Finding 3 (runtime logs → journald): is dropping geometrikks's tail of the GLOBAL access.log acceptable?**
Caddy allows ONE default-logger output. Moving runtime logs to journald (so SigNoz sees caddy's own errors with severity) displaces `access.log` — which today carries ONLY runtime lines (every vHost has its own log block), but geometrikks tails that file explicitly (its per-vHost tails are unaffected). What I tried: read geometrikks.nix's derivation (the access.log entry is one list item, cleanly removable); what I cannot know is whether you value runtime-lines-in-a-file (offline forensics, direct tailing) enough to keep the file sink and leave finding 3 open.

**g3. For per_host metrics: dashboard-only, or dashboard + per-host 5xx ALERT?**
The alert (item 3) is a new rule in `_signoz-alerts.nix`. What I tried: reviewed the existing alerts file and the caddy dashboard; both support it. What I cannot know: your alert-noise tolerance and which hosts warrant paging (a per-host 5xx alert across ~20 vHosts is a different noise profile than the current aggregate checks). If yes: threshold + window + host scope are yours to set.

---

*Report ends. WAITING FOR INSTRUCTIONS.*
