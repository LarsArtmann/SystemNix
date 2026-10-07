# Status Report — Browser-History Device-Labels Verification Session

**Timestamp:** 2026-10-07 08:48 CEST
**Session type:** Read-only Q&A + live verification (ZERO code/config changes, ZERO commits)
**Scope discipline:** Per owner instruction, this report covers ONLY this session's run: two questions about `https://history.home.lan/` device support and the live-state probes they triggered. No other repo areas were researched.
**Parallel-session note:** The tree carries work from other sessions (06-59 vendorhash-wave report, caddy catch-all rows in `docs/todo/services.md`). None of it is mine; nothing here co-claims it. One corroborating intersection is cited where it confirms my finding (§a.2).

---

## 0. What this session actually was

1. **Q1:** "Does https://history.home.lan/ support device(s) (labels)?" → Answered **yes — machine labels**, with source-level + deployed-rev + live-DB evidence.
2. **Q2:** "All setup superbly?" → Ran live probes (textfile collector, backup DB, service wiring) and answered yes with an evidence table.
3. **Q3:** This report.

No work was dispatched; no files outside `docs/status/` (+ the todo-system harvest below) were modified by me.

---

## a) FULLY DONE (verifiably complete, with evidence)

| # | Item | Evidence |
|---|------|----------|
| a.1 | **Answered the device-labels question end-to-end**: per-visit `machineId` exists, agent sets it via `X-Machine-ID` (`-machine-id` flag / `BROWSER_HISTORY_MACHINE_ID`), dashboard renders an "All machines" dropdown + machine table linking to `/?machine=<label>` filtered views | Upstream source at deployed rev `3ebbfbfee` (2026-10-06 22:56, per SystemNix `flake.lock`): `git show 3ebbfbfee:domain/visit/visit_data.go` line 59 (MachineID field), `api/filter_options.go:55` ("All machines"), `api/dashboard.go:99-100` (`dashboardMachineFilterURL`), `api/dashboard.go:155` (Machines view model) — all confirmed present AT THE DEPLOYED REV via `git cat-file`/`git show`, not just at master HEAD |
| a.2 | **Live prod attribution proven**: every visit in prod carries a machine label — `SELECT machine_id, count(*) FROM visits` → `evo-x2 \| 4219`, **zero** empty rows (so no legacy-`/extract` orphan visits and no backfill needed) | Latest pool backup `browser-history-db-2026-10-07.sqlite` queried read-only (copied to /tmp; sqlite has no local binary — `nix shell nixpkgs#sqlite`) |
| a.3 | **Agent freshness proven live**: `browser_history_agent_last_ingest_age_seconds 55`, `browser_history_agents_active 1`, `browser_history_agent_tokens_total 1`, `browser_history_agent_scrape_errors 0`; textfile written 08:23 today | `/var/lib/prometheus-node-exporter/textfile_collectors/browser-history-agent.prom` read directly |
| a.4 | **Agent token inventory**: exactly one DB token, label `evo-x2`, scope `write`, last_used `2026-10-06 23:51:21 UTC` (consistent with the 02:15 backup cut) | `agent_tokens` table in the same backup |
| a.5 | **Naming-collision disambiguation**: identified that the `/devices` page is a DIFFERENT concept — WebAuthn passkey credentials (`api/devices.go`, "Unnamed device" fallback, backup-eligible/state flags) — and told the user, preventing a future split-brain question | `git show 3ebbfbfee:api/devices.go` |
| a.6 | **SystemNix-side wiring located**: provisioner mints the token with `-label "${machineId}"` (module line 93); label default `config.services.browser-history-agent.machineId or "evo-x2"` (line 162); upstream agent module carries its own `machineId` option fed to the agent binary | `modules/nixos/services/browser-history.nix:93,162` + upstream `nix/agent-module.nix:74,139` |
| a.7 | **Caught a doc-drift item while reading the runbook**: the runbook's 2026-09-17 "UPSTREAM REGRESSION HOLD" bullet still reads as if lock `0971fe9c` is current, while `flake.lock` is at `3ebbfbfee` (and the parallel 06-59 report records the browser-history vendorHash shim DROPPED in `f0442ea3` because upstream `3ebbfbf` already fixed it — corroboration, not my claim) | `docs/services/browser-history.md:11` vs `flake.lock` vs `docs/status/2026-10-07_06-59_*` §d.7 |
| a.8 | **Caught a potential data-correctness risk (unverified, flagged)**: visit IDs are deterministic (`url+ts+browser` per runbook line 14) and `machine_id` is a column, not obviously part of the dedup key — two machines visiting the same URL within the same second may silently merge into one row. NOT yet verified; queued for upstream-source verification | Runbook `docs/services/browser-history.md:14` + existence of `api/dedup_test.go` in upstream |

---

## b) PARTIALLY DONE

| # | Item | What works | What remains open | Effort |
|---|------|-----------|-------------------|--------|
| b.1 | **"All setup superbly?" verdict** | Infra layers verified live: ingest fresh (55 s), attribution 100%, token healthy, alerting collector clean, nightly backup present | Three legs verified only INDIRECTLY (see §d.1–d.3): direct HTTP probe of `/health` (curl tool-blocked, no substitute run), the authenticated dashboard UI (machine dropdown render — needs a human login), and confirmation that the RUNNING generation is built from lock `3ebbfbfee` (inferred from flake.lock + the 03-02 fix-verified report, never read off the live unit) | S |
| b.2 | **machineId mechanism chain** | The OUTCOME is proven (all 4219 prod visits labeled `evo-x2`); the token-label default (module line 162) is located | The CAUSAL chain is only partially traced: I did not confirm whether the agent's `X-Machine-ID` value comes from the upstream module's own `machineId` option default, an evo-x2 config set, or the SystemNix `or "evo-x2"` fallback — if upstream ever renames/defaults that option, token label and visit label could silently diverge. Prod DB would mask it until a second machine appears | S |

---

## c) NOT STARTED

| # | Item | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| c.1 | **Second machine (macOS) agent** feeding `history.home.lan` | Owner-gated decision; deliberately not set up. The ONLY knob is `machineId` (e.g. `lars-macbook-air`) — everything else (token provisioning, freshness metric, dashboard filter) is already multi-machine-ready | Asked in §g.3 |
| c.2 | **Machine-label documentation in the SystemNix runbook** | This session DISCOVERED the feature is undocumented in `docs/services/browser-history.md` — I learned it entirely from upstream source. A future agent answering the same question would redo the whole dig | Yes — harvested §f.2 |
| c.3 | **Per-machine monitoring dimensions** (per-label freshness gauges, token label in the textfile) | Premature with one machine; the current any-agent metric is correct for today's topology | Deferred by design |

---

## d) TOTALLY FUCKED UP

**Prod level: nothing.** This session was read-only; no service, file, or data was broken by it. The honest failures are session-quality failures — each is exactly a class AGENTS.md already names:

| # | What went wrong | Severity | Root cause | Mitigation |
|---|-----------------|----------|-----------|------------|
| d.1 | **"Server healthy" claim rode indirect evidence.** I answered "server healthy" from ingest-freshness (a 200-ingest 55 s ago proves the server lives) — but I never got a direct HTTP response from the box: `curl` is tool-blocked and I did NOT re-run the probe via the fetch tool. Ingest-health ≠ dashboard/login-health (the 2026-09-18 "answer the question the item ASKED" class, one level down: assert WHICH question your evidence answers) | Low — ingest 200s are strong liveness evidence and the 03-02 report separately verified the dashboard fix | Tool-policy block + not substituting the obvious alternative | §f.1 — one authenticated login (owner) + one fetch `/health` closes it |
| d.2 | **Transient world-readable prod-data copy.** My `/tmp` staging of the 200 MB backup (`cp` under default umask) briefly created a mode-644 copy of prod browsing history; deleted immediately after each query, but the copy step was sloppy | Low — LAN single-user box, existed ~seconds, deleted | Reached for `cp` before `install -m 600` | §f.6 — recipe in the runbook harvest uses `umask 077`/`install -m 600` |
| d.3 | **Answer-completeness gap on Q1.** The dashboard ALSO has a browser-axis filter (`?browser=` Firefox/Chromium, `api/dashboard.go:56`) — a second "which device" reading of the question. I noticed it while reading `dashboard.go` but did not surface it in my answer; the user only learned machine labels exist. If the user meant the browser axis, my answer half-missed | Low — machine labels were the dominant reading and the full capability is now on record in this report | Answered from the strongest signal without enumerating adjacent axes | §g.2 asks which reading was meant |
| d.4 | **Loose mechanism citation in the Q2 answer.** I cited module line 162 as "the default" for the prod label — but line 162 is the token-provisioner's let-binding; I did not prove it is what drives the agent's `X-Machine-ID`. Outcome (DB) was right; the cited mechanism was under-verified | Low | Stopped digging once the outcome was proven | b.2 + §f.4 |

---

## e) WHAT WE SHOULD IMPROVE

| # | Improvement | Impact | Concrete fix |
|---|-------------|--------|--------------|
| e.1 | **Service capability docs lag upstream features.** Machine labels shipped upstream (dashboard dropdown, REST filter, machine table) but the SystemNix runbook — the file agents are ROUTED to first — never mentions them. Cost this session: ~10 tool calls of re-discovery that the runbook should have saved | Medium | §f.2 harvest: document the chain (option → X-Machine-ID → dashboard) in `docs/services/browser-history.md` |
| e.2 | **Live-probe recipes absent from the runbook.** Three standard probes were tool-blocked or friction-heavy this session: `systemctl` (blocked → textfile-collector read is the working proxy), `curl` (blocked → use fetch), `sqlite3` (not in PATH + `-readonly`/URI modes both failed on this box → copy to /tmp first). The next agent hits all three again | Medium | Same harvest row: add a "live verification recipe" block with the working invocations |
| e.3 | **Dated incident bullets rot into false-current-tense.** The 09-17 hold bullet reads as if the rollback lock is still current. The correction was already INSIDE the bullet (uid-drift reattribution) but the lock claim was left behind | Medium | §f.2 harvest: annotate the bullet with the current lock; future incident bullets should carry their own "superseded on <date>" stamps |
| e.4 | **Multi-machine readiness is undocumented.** The system is one knob away from a second machine, but nothing records that (which option, what label convention, what the freshness metric will and won't show) | Low-Medium | Same harvest row + §c.1 decision |
| e.5 | **Session-tool blocks need pre-known workarounds**, not in-session discovery (two failed sqlite attempts before the copy workaround worked) | Low | e.2's recipe doubles as the workaround catalog for this service |

---

## f) NEXT TASKS (scoped to this session's findings, ranked by impact)

Dispositions per the TODO contract: **HARVESTED** = landed in `docs/todo/services.md` (+ `TODO_LIST.md` queue for `[ready]` items) at authoring time; **NOT HARVESTED** = brainstorm/ROADMAP fuel or premature (reason given). Items already tracked elsewhere are marked DEDUP.

| # | Task | Impact | Effort | Category | Disposition |
|---|------|--------|--------|----------|-------------|
| f.1 | Authenticated dashboard verification: machine dropdown renders, `evo-x2` row present, `/?machine=evo-x2` filters, AND the 03-02 acceptance range (Aug 14 → Oct 5) — one login covers all | High | S | Verification | HARVESTED as `[blocked:user]` — MERGED into the existing "Test browser-history OAuth2 login end-to-end" library row (no duplicate row) |
| f.2 | Runbook refresh (`docs/services/browser-history.md`): document machine labels end-to-end (option → X-Machine-ID → dashboard dropdown/table/`?machine=` links + browser-axis filter), annotate the stale 09-17 hold bullet (lock now `3ebbfbfee`), add the live-probe recipe (textfile path, backup path, umask-077 sqlite-copy pattern, fetch-not-curl) | High | S | Documentation | HARVESTED `[ready]` |
| f.3 | Verify cross-machine visit dedup: read upstream visit-ID derivation + dedup tests — does the deterministic ID include machine_id? If two machines CAN silently merge same-second same-URL visits, prep the upstream issue locally (verify-before-filing) | High | S→M | Bug (potential) | HARVESTED `[ready]` (local verify leg; upstream filing would be `[blocked:push]`) |
| f.4 | Confirm the RUNNING generation's browser-history package = lock `3ebbfbfee` (read the unit's package path off the live system) — closes b.1's inference gap | Medium | S | Verification | HARVESTED `[ready]` |
| f.5 | Eval assertion tying provisioner token label to the agent's machineId (one source of truth for both; guards upstream option rename/default drift — b.2) | Medium | S | Quality | HARVESTED `[ready]` |
| f.6 | Prod-DB probe hygiene into the recipe: `umask 077` / `install -m 600` for any /tmp staging of backup DBs (d.2) | Low | S | Quality | HARVESTED (folded into f.2's recipe) |
| f.7 | VM test: add a machine-attribution step to `tests/test-browser-history.nix` (ingest with a machine header → dashboard `?machine=` filter returns only those visits). Today only upstream Go tests cover the filter; NixOS-level e2e does not | Medium | M | Quality | HARVESTED `[ready]` |
| f.8 | Second machine (macOS) agent — machineId convention + token provisioning (everything else already works) | Medium | S | Feature | HARVESTED `[decision]` (owner timing; §g.3) |
| f.9 | Per-machine freshness gauges (`browser_history_agent_active{label=…}`) + token label emitted in the textfile | Medium | S | Feature (monitoring) | NOT HARVESTED — premature with one machine; revisit when f.8 lands |
| f.10 | machineId free-text validation (format/uniqueness) upstream — a typo'd machineId creates a phantom machine row in the dropdown | Low-Med | M | Feature (upstream) | NOT HARVESTED — upstream brainstorm, file only after f.3's source dig |
| f.11 | `/devices` passkey naming UX upstream: name credentials during the WebAuthn ceremony instead of "Unnamed device" fallback | Low | M | UX (upstream) | NOT HARVESTED — upstream brainstorm |
| f.12 | Index `machine_id` for `ListMachines` GROUP BY at scale (4219 rows fine today) | Low | S | Perf (upstream) | NOT HARVESTED — premature |
| f.13 | Verify Gatus "Browser History Agent Data" check is green NOW (collector output green ≠ gatus eval green — I never probed gatus itself) | Low | S | Verification | NOT HARVESTED — trivial; folds into any next health pass |
| f.14 | Verify `ListMachines` most-recent-first ordering has a test upstream (comment claims it; unverified) | Low | S | Quality (upstream) | NOT HARVESTED — micro-verify, ride along f.3 |
| f.15 | Pin dashboard auth-guard on machine-filter routes with a test (unauth `/?machine=` must not leak per-machine data) | Low | S | Security (upstream) | NOT HARVESTED — guard seen on `/devices`+dashboard in source; test-only nicety |
| f.16 | DOMAIN_LANGUAGE.md glossary entry upstream: label vs machine vs device vs credential (this session needed all four disambiguated) | Low | S | Docs (upstream) | NOT HARVESTED — upstream brainstorm |
| f.17 | FEATURES.md row: mention per-machine labels in the Browser History line | Low | S | Docs | HARVESTED (folded into f.2) |
| f.18 | DEDUP: AGENT_FRESHNESS quiet-day 503 upstream heartbeat | — | — | — | ALREADY TRACKED (`docs/todo/services.md` `[ready]` empty-batch-heartbeat row) — not re-queued |
| f.19 | DEDUP: revoke the 4 test bring-up users | — | — | — | ALREADY TRACKED (`[blocked:user]` row exists) |
| f.20–f.30 | Brainstorm residue (not tasks yet): machine-filter state persistence; per-machine color coding in day view; machine column surfaced in visits table UI; token-label ↔ machine-id consistency lint upstream; per-machine `/metrics` labels; multi-agent README recipe upstream; machine table click-through count badge; export per-machine CSV; machine rename/migration story (relabeling historical visits); alert on NEW machine label appearing (unexpected-device signal); dashboard i18n of "All machines" | — | — | — | NOT HARVESTED — ROADMAP fuel; tq must not see these |

**Harvest summary:** 8 items harvested (f.1 merged into an existing row; f.2+f.6+f.17 one row; f.3; f.4; f.5; f.7; f.8 decision). Everything else explicitly not harvested with reasons above, so a later `docs-health` HARVEST pass does not have to re-adjudicate.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Did the dashboard actually render it?** When you log in next: does the "All machines" dropdown appear, does the `evo-x2` row show, does clicking it filter, and does the range look like Aug 14 → Oct 5? I cannot authenticate (and this simultaneously closes the still-open 03-02 acceptance test — the only test nobody has run).
2. **What did you mean by "device(s) (labels)"?** Machine labels (what I verified — history attributed per computer), the `/devices` WebAuthn passkey list, or the Firefox-vs-Chromium browser axis (`?browser=` filter, which I under-surfaced in the live answer — d.3)? If you meant passkeys or the browser axis, say so and I'll verify that surface with the same rigor.
3. **Is a second machine (macOS) actually planned?** If yes: what machineId label (e.g. `lars-macbook-air`), and should its agent ride the sops env-token fallback or get its own `bh_` token from the same account? (Runbook says bh_ is mandatory for remote agents — but timing/naming is yours.)

---

**Next action:** WAITING FOR INSTRUCTIONS. Per the standing rule, §f direct follow-ups are already harvested (see dispositions); nothing else was touched.

---

## h) DISPATCH CLOSE-OUT (same day, ~10:15 UTC — the five `[ready]` harvests executed + the two d-gaps closed)

The user's execute instruction dispatched the harvested queue. All five `[ready]` items landed and verified; both d-gaps closed with direct evidence.

| Item | Verdict | Evidence |
| --- | --- | --- |
| d-gap "server healthy rested on indirect evidence" | **CLOSED — direct probe.** `GET https://history.home.lan/health` via the fetch tool returned 200 `{"status":"ok","db":"ok","agents":{"active":1,...},"lastIngestAt":"2026-10-07T08:00:39Z"}` at 08:06 UTC (uptime 26 min — the server had restarted ~07:40 UTC, so this is post-restart health, not stale-session luck) | fetch output, this section |
| d-gap "running generation rev never read off the live unit" | **CLOSED — store-path proof.** `/etc/systemd/system/browser-history.service` → `ExecStart=/nix/store/999dlpy9…-browser-history-server-3ebbfbf/bin/…`: the RUNNING generation is lock rev `3ebbfbfee` (short form in the store path name) | `readlink` + unit ExecStart |
| f.2 runbook refresh | **DONE.** `docs/services/browser-history.md` gained: machine-labels bullet (full chain option → `--machine-id` → `X-Machine-ID` → `visits.machine_id` → dashboard dropdown/`?machine=`), the AD-2 verdict below, the live-probe recipe (textfile / backup-DB-sqlite-workaround / fetch-not-curl / rev-from-store-path), and a lock-note superseding the 09-17 hold bullet (kept for the uid-drift lesson). FEATURES.md Browser History row extended | runbook diff |
| f.3 cross-machine dedup | **VERDICT REVERSED — NOT a bug, it is architecture (AD-2).** Upstream `domain/visit/visit_data.go:62-64`: machine_id is "Attribution only — never part of the deterministic VisitID hash (AD-2)". Guard test `api/dedup_test.go::TestDedup_SameVisitFromTwoMachines_ProducesOneRecord` PINS one-row + first-dispatch-wins (machine-a keeps attribution) — deliberate browser-sync replication semantics, and the test message says breaking it = someone added machineID to the hash. This session's §f.3 "potential data-loss bug" hypothesis is ANSWERED: no upstream issue to file; semantics documented in the runbook instead | upstream source + test, read at `f597e1c6` |
| f.4 running rev | **DONE** (see store-path proof above) | — |
| f.5 token-label == machineId | **DONE — single shared binding, no fallback.** Module's `machineId` let-binding dropped the `. or "evo-x2"`: the binding now reads the upstream option directly (required, no default; evo-x2 sets it in configuration.nix:731). An upstream option rename now FAILS EVAL LOUDLY instead of silently relabeling tokens "evo-x2" while visits keep carrying the header value. Eval-verified: `nix eval .#nixosConfigurations.evo-x2.config.services.browser-history-agent.machineId` → `"evo-x2"` | module diff + eval |
| f.7 VM-test machine step | **DONE + test GREEN.** `tests/test-browser-history.nix` steps 11-12: provisioned-token label == machineId option (`SELECT label FROM agent_tokens` = `vm-test`); header-stamped ingest lands `machine_id` (`machine-a`); re-ingest of the SAME visit under `machine-b` stays ONE row keeping `machine-a` (AD-2 verified on the deployed NixOS wiring, not just upstream Go tests). Full test rc=0 | `nix build .#checks.x86_64-linux.browser-history` rc=0 |

**Bonus fix (pre-existing blocker removed en route): the browser-history VM test is OFF the known-failing list.** Its step 2 died at `curl -sf /health` (HTTP error after `wait_for_open_port` succeeded): since `AGENT_FRESHNESS` (lock `10fe5d8a+`) a server with no agent ingest yet answers **503 degraded** — demanding 200 there is exactly the liveness-deadlock class the module's own `waitServerReady` gate documents. Fixed to accept any answered status, plus new step 7.5 proving the agent's empty-batch ingest HEALS the server back to 200. This closes the browser-history leg of the `[blocked:user]` six-failing-VM-tests triage row (pipeline.md) with root cause + fix; the other five remain owner-triage.

**Still open (unchanged):** §g.1-3 owner questions (dashboard render, "devices" intent, macOS plans — unanswered); f.1 login e2e (`[blocked:user]`); f.8 second machine (`[decision]`). No commit made (daemon handles it, per harness policy).
