# 2026-08-27 16:08 — Self-Review: SigNoz Phantom-Alert Purge Session

Session: "Can you find any bugs??" → found 3 bug classes / 11 instances in the
monitoring stack, fixed + deployed + verified (see
`2026-08-27_15-50_signoz-phantom-alert-purge-6-dead-rules-fixed.md` for the
work itself). This report is the honest self-assessment the user asked for:
what was forgotten, what was done badly, what remains.

---

## a) FULLY DONE (verified end-to-end this session)

1. **Diagnosed + fixed 6 phantom-green SigNoz rules** (`up{job=}` never
   matches: OTel receiver stores job as dotted `service.name`, unselectable in
   PromQL). All converted to live-verified selectors
   (`node_systemd_unit_state`, session-aware gates).
2. **Fixed 1 false-positive critical firing live** ("Niri Compositor Down" on
   headless machine → `niri_desktop_died` gate; confirmed inactive after deploy).
3. **Added "DNS Blocker Stats API Wedged" rule** (`count(up{service_name=...})
   or vector(0)`) — correctly returned 0 during the live wedge, 1 after
   recovery; catches the process-alive-but-API-wedged class the old rule was
   blind to.
4. **Fixed GPU Thermal rule** (queried zero-series `node_amdgpu_gpu_temp_celsius`)
   → two-source OR (hwmon + ClickHouseAsyncMetrics), bus-renumber resilient.
5. **Fixed 4 phantom dashboard panels**: caddy latency + response-size, dns
   resolve-duration (dotted histogram names via `{__name__=}` form), 2 GPU
   panels (temp OR-query; removed dead "Memory Controller Busy").
6. **Full verification**: every replacement selector instant-queried against
   `:8080/api/v1/query` BEFORE deploying; provisioner converged (26 rules,
   26 policies, 5 dashboards, 0 errors); rules API shows all rewrites with
   fresh `updateAt`; failed units cleared; generation anchoring confirmed
   (current == system-729).
7. **Documentation**: 2 new AGENTS.md gotchas (phantom `up{job=}` class incl.
   the up-series label-flip mechanism; dashboard panel+layout coupling),
   dnsblockd wedge note updated (instance healed by deploy restart 15:32,
   root cause still unknown), status report written.
8. **Swept Gatus pat() checks** for the same phantom-metric class — clean
   (service-local endpoints are enable-gated and serve their own metrics).
9. **Incidentally healed the dnsblockd :9090 wedge** (deploy restart; /metrics
   answering 177KB) and confirmed the wedge-detector rule flips correctly.

## b) PARTIALLY DONE

1. **Phantom-rule PREVENTION layer** — I fixed the instances and documented
   the meta-limitation (`system_signoz_alert_rules_healthy` only counts rules,
   structurally cannot catch dead queries), but built NO mechanical guard
   (no `signoz-query-lint` flake check, no post-deploy rule-state diff). The
   repo's core philosophy is prevention layers; I shipped instances-only.
2. **Wedge-rule fragility** — the `service_name`-selector dependency is
   documented in a rule comment only; no code guard, no TODO_LIST entry, no
   note in the dnsblockd module where an upstream bump could silently break it.
3. **dnsblockd root cause** — the wedge healed before a SIGQUIT goroutine
   dump could be taken; AGENTS.md carries the forensic note but there is no
   prepared dump runbook, so the next wedge may again be restarted "blind".

## c) NOT STARTED (noticed this session, deliberately deferred)

1. `signoz-query-lint` eval-time check (blocklist `up{job=`, zero-series
   metric names, `metric_sum`-style suffix queries).
2. post-deploy-check assertion that `signoz-provision.service` SUCCEEDED
   (see d-1 — the current check passed while the unit was failed).
3. Deploy-window tolerance for `service-health-check` / transient
   "Systemd Service Failed" criticals (fires when the checker catches a
   service mid-restart during deploys).
4. dnsblockd `service_version` label-churn decision (20+ historical
   fingerprints in ClickHouse; drop via relabeling or accept).
5. SigNoz mirror of `niri_crash_loop` (Gatus-only today).
6. Discord-delivery proof for the NEW wedge rule (never fired for real —
   by design nothing should have; route policy created but unproven).
7. Cosmetic: "Temperature by Card" panel name is now wrong (single max series).

## d) TOTALLY FUCKED UP (my own regression, caught + fixed same session)

1. **First deploy shipped a broken GPU dashboard**: I removed the
   "Memory Controller Busy" panel but FORGOT its `spec.layouts` `$ref` item
   → v2 API rejected the dashboard (`references unknown panel`, HTTP 400) →
   `signoz-provision.service` FAILED → "Systemd Service Failed" (critical)
   fired on the provisioner itself for ~18 minutes until my second deploy.
   Two compounding mistakes: (1) I had the JSON loaded in python when deciding
   the removal and never cross-checked layout refs ⊆ panel ids — a 3-line
   assertion would have caught it pre-deploy; (2) after the first deploy I
   verified RULES convergence but not the provisioner UNIT result — the
   post-deploy-check's "26 rules provisioned PASS" masked it (it counts rules,
   not unit exit status), and I only noticed via the alert chain 2 steps later.
   Silver lining: the now-working monitoring caught my own regression — the
   fix's first real save was my mistake.
2. Minor: first redeploy aborted on the concurrent session's un-added
   `website-deploy-monitor.nix` (documented tracked-files trap; handled by
   waiting and re-running — not damage, but I deployed into a known-hot tree
   without pre-checking `git status` first).

## e) WHAT WE SHOULD IMPROVE (from this session's observations)

1. **Prevention layers for query hygiene**: the gatus-pattern-lint pattern
   should extend to SigNoz rules + dashboards (blocklist selectors/metric
   names proven dead). The same class was caught by hand twice now (ollama
   2026-08-16, this session ×6).
2. **Post-deploy-check lies when the provisioner fails on dashboards** —
   rule-count ≠ convergence. Assert unit result + dashboard convergence.
3. **Per-rule query liveness expectations**: absence-based rules are
   legitimately empty; always-present-gauge rules are not. Encode which is
   which so a generic emptiness detector becomes possible.
4. **Deploy-window alert noise**: transient unit failures during restart
   churn trip real criticals (service-health-check caught dnsblockd
   mid-restart; my provisioner failure fired Systemd Service Failed).
   Either tolerate (alertmanager grouping) or make the checker retry-aware.
5. **Concurrent-session deploys**: verify `git status` (untracked module
   files) before `nix run .#deploy` — the failure mode is documented but not
   automated in pre-deploy-check.
6. **Fragile-selectors need owners**: the `service_name`-selector rule and
   the PCI-address-keyed hwmon chip regex both silently break on upstream
   bumps / bus renumbers. They need companion notes where the breaking
   change would land (dnsblockd module, NIC docs) — not just rule comments.

## f) NEXT: up to 50 things (grouped, ranked)

**Prevention (highest leverage):**
1. `signoz-query-lint` flake check (dead selectors/metrics in rules+dashboards)
2. post-deploy-check: assert signoz-provision result=success + dashboard convergence
3. post-deploy-check: diff `:8080/api/v1/rules` states — flag any rule firing >24h
4. pre-deploy-check #0: warn on untracked files under modules/ (tracked-files trap)
5. Per-rule "always-present" flag in mkRule → enables generic emptiness detector
6. Extend `system_signoz_alert_rules_healthy` to include provisioner freshness

**dnsblockd:**
7. Write `scripts/dnsblockd-goroutine-dump.sh` runbook (SIGQUIT + journal capture) for the next wedge
8. Root-cause deploy.sh dnsblockd-restart block not firing (AGENTS.md "unexplained")
9. Decide service_version label churn: drop via metric_relabel_configs or accept+document
10. Upstream fix for the tracking-DB/mutex wedge suspect (after dump evidence)
11. Textfile `system_dnsblockd_metrics_fresh` metric (robust wedge detector, no service_name dependency)

**Monitoring coverage gaps noticed:**
12. caddy.service unit-state rule in SigNoz (Gatus covers vHosts; process death currently unmirrored)
13. SigNoz `niri_crash_loop` mirror decision
14. pocket-id scrape-death coverage sweep (all collector scrape jobs vs alert rules)
15. bank-sync SigNoz rules for when DAS returns (currently Gatus-only, enable-gated)
16. Docker engine metrics presence check (up=1 but empty /metrics class)

**This session's loose ends:**
17. Prove wedge-rule Discord delivery end-to-end (needs a controlled dnsblockd stats stop — root)
18. Rename "Temperature by Card" panel → "GPU Temperature Trend"
19. Add VRAM-% panel (rule exists, dashboard shows bytes only)
20. Verify emeet + niri rules behave when graphical session returns (expected_down gates flip)
21. dnsblockd module comment: wedge-rule depends on self-reported service_name label
22. AGENTS.md: note hwmon chip regex fragility in the NIC/bus-renumber section

**Known ecosystem debt (context, not started):**
23. DAS physical recovery (unblocks Immich/Attic/Paperless/Bank-Sync + 8 post-deploy FAILs)
24. /data EIO corruption repair (TODO_LIST P0)
25. ClickHouse telemetry backup coverage (TODO_LIST)
26. nixpkgs go_1_26 ≥ 1.26.6 → drop tarball overrides (AGENTS.md drop-list)
27. bank_sync sync-errors WARN post-restart (metric new; confirm it clears after a good cycle)
28. Residual-offscreen: verify gpu/caddy/dns dashboards render correctly in the UI (needs browser)
29. Cache/HDD pool verification once DAS returns (btrfs-verify-pool-backups backlog)
30. Re-run full `nix flake check` with builds (VM tests) at a quiet moment — only --no-build run this session

(30 substantive items — the honest list; padding to 50 would be noise.)

## g) QUESTIONS (cannot be answered from the repo/system)

1. **dnsblockd wedge forensics**: want me to write the SIGQUIT goroutine-dump
   runbook (script + AGENTS.md wiring) so the NEXT wedge is captured before
   any restart? It only pays off if you (root) run it at the next wedge
   instead of restarting immediately — is that tradeoff acceptable, or is
   fast recovery always preferred over root-causing?
2. **Deploy-window alert noise policy**: transient "Systemd Service Failed"
   criticals during every deploy restart-churn — accept as-is, or should the
   checker/alert get a deploy-window tolerance (e.g. grace period gated on an
   activation marker file)?
3. **SigNoz as second alert layer for niri/caddy**: Gatus already covers
   these — should SigNoz mirror them (dual-layer, more noise) or stay
   complementary-only (unit-state + resource rules, HTTP checks stay Gatus)?
   Current de-facto policy after my changes is "complementary"; confirm or
   reverse.

---

**State at report time**: deploy green (system-729 active + anchored),
provisioner 0 errors, 0 failed units, dnsblockd healthy, all 7 rewritten
rules live and correct. Tree carries this session's edits + another active
session's WIP; auto-commit daemon owns commits.
