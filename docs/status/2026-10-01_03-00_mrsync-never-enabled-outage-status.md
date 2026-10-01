# Status Report — mr-sync Never-Enabled Outage (session closeout)

**When:** 2026-10-01 03:00 CEST
**Scope:** This session ONLY — the `mr-sync.home.lan is down` diagnosis + fix, plus what the session's probes surfaced. No unrelated research was done (per instruction). A parallel session was actively restructuring docs/AGENTS.md during this window; their changes are flagged, not touched.
**Deployed state at session start:** evo-x2 on generation `system-811` (`26.11.20260928.7a0f122`, anchored: `/run/current-system` == profile), uptime ~40h (boot Sep 29 09:56, the freeze-#7 recovery boot), mid-sustained IO storm.

---

## a) FULLY DONE

1. **Root cause of the mr-sync outage identified, with a complete evidence chain.**
   Evidence chain, each step verified live:
   - `http://127.0.0.1:7331/` → connection refused (nothing listening).
   - `system_service_active{service="mr-sync-dashboard"} 0` in the node_exporter textfile — and `state_failed 0`, `start_limit_hit 0`, `nrestarts 0` → NOT failed, NOT start-limited, never restarted: **never started**.
   - `journalctl -u mr-sync-dashboard.service` → **zero entries across ALL boots since 2026-09-15** (journal access proven working via sshd control query).
   - The unit file EXISTS and is deployed (`/etc/systemd/system/mr-sync-dashboard.service` → store unit, current generation), but there is **no `multi-user.target.wants/mr-sync-dashboard.service` symlink** → not enabled at boot.
   - `git log -p` on `modules/nixos/services/mr-sync.nix`: both commits (8cb64722, fc4555e1 — both 2026-09-16) contain **no `wantedBy` anywhere**. The module never had an enablement path.
   - Ruled-out alternatives: un-anchored generation (profile anchored), missing EnvironmentFile (sops secret present, root 0400), crash/start-limit loop (metrics), stale unit name (metrics + unit file agree).
   **Verdict:** identical class to the health-dashboard 2026-09-22 bug — "defined, monitored, smoke-checked, but NEVER started". The dashboard served **zero requests in the 15 days since it shipped**.

2. **Fix landed:** `wantedBy = [ "multi-user.target" ]` added to `systemd.services.mr-sync-dashboard` (modules/nixos/services/mr-sync.nix:73), matching the house pattern (health-dashboard.nix:100, tq-agent-pool.nix:126, indexer-web.nix:88). Deploys start newly-enabled units at activation, so no reboot is needed.

3. **Fix verified at the Nix layer:** targeted `nix eval .#nixosConfigurations.evo-x2.config.systemd.services.mr-sync-dashboard.wantedBy` → `["multi-user.target"]`. Full `nix flake check --no-build` → **all checks passed** (this includes the eval-time guard army: deploy-restart-audit, gatus-pattern-lint, port-registry, sops-key-audit, systemd-shape, etc.).

4. **Runbook updated:** docs/services/mr-sync.md gained the dated OUTAGE + FIX entry with the full evidence chain and the class cross-reference, so the next reader knows why the "15 days red" happened.

5. **Deploy-state verification (early, ruled out the wrong-track diagnoses):** profile anchoring checked before anything else (`readlink /run/current-system` vs `/nix/var/nix/profiles/system` — identical), because this repo's history says rc/anchor confusion is the most common misdiagnosis after any deploy.

## b) PARTIALLY DONE

1. **The outage fix — landed but NOT deployed.** Eval-green in-tree; mr-sync.home.lan remains DOWN until someone runs `nix run .#deploy`.
   - Remaining: the deploy itself; post-switch the unit starts, Gatus goes green within one 5-min probe cycle.
   - Blocker: deploy is sudo-gated and this session's sandbox has no sudo; deploy authority (queue-fired vs user-manual) is itself an open owner decision (existing storage.md queue row).
   - Effort to finish: S (one command + one verification pass).

2. **Post-deploy verification battery — defined, unexecuted.** Checklist written into the harvested todo row: Gatus "mr-sync Dashboard" green; `127.0.0.1:7331` answers; PapDashboard tile flips up; the dashboard actually renders the portfolio; `GITHUB_TOKEN` verdict (real PAT vs PLACEHOLDER → FetchError banner is the designed degraded mode, not a crash); first cold-walk probe survives `[RESPONSE_TIME] < 15000` (the 5-min interval + 20s timeout were sized for warm-cache probes; the FIRST probe after start pays a full `~/projects`+`~/forks` du-walk on the QLC NVMe). Blocked by (b1).

3. **§f harvest — partially applied by design.** The 4 DIRECT follow-ups of this session were harvested into TODO_LIST.md + domain libraries at authoring time (see §f items marked HARVESTED). The remaining ~30-item brainstorm was deliberately NOT harvested: it is ROADMAP fuel awaiting owner instruction ("THEN WAIT FOR INSTRUCTIONS"), and several items touch domains a parallel session is actively editing (docs/agents restructure).

## c) NOT STARTED

1. **The class's structural fix — an eval-time "never-enabled unit" audit** (any integration-registry service with checks/monitoring whose unit has no enablement path fails `nix flake check`). No code written. Two live incidents (health-dashboard 09-22, mr-sync today) prove eval-green does not mean "starts". Priority: HIGH — queued in pipeline.md.
2. **mr-sync VM test.** The module has zero test coverage (no `tests/test-mr-sync.nix`); every other recent service module has one. Queued, not started. Priority: MEDIUM.
3. **Why 15 days of red never escalated.** The Gatus check carried a Discord alert the whole time; nothing acted. Delivery audit not started (gatus.sqlite is root-only; journal leg is agent-readable). Queued in monitoring.md. Priority: HIGH — if delivery is broken, EVERY red check is invisible, which is worse than the mr-sync bug itself.
4. **mr-sync GitHub PAT go-live.** The sops secret ships PLACEHOLDER (per docs; value is root-only so this session could not confirm). Paste = owner step, runbook documented. Not started. Priority: LOW (dashboard degrades gracefully).
5. **Post-fix sweep confirmation that no OTHER service module shares the class** — subsumed by (c1) once the audit exists; a one-time manual list was deliberately skipped in favor of the permanent audit.

## d) TOTALLY FUCKED UP

1. **mr-sync shipped as a fully-wired ghost service (the headline).** Everything EXCEPT the daemon was present and correct: Gatus check with alert text, PapDashboard tile, system-health monitoredServices row, DNS subdomain, Caddy protected vHost, sops secret, hardening, IO tier — and the unit was never enabled, so **zero requests served 2026-09-16 → 2026-10-01**. Every config surface was green; the eval-time guards all passed; nothing in the pipeline layers catches "a monitored service that never starts". Severity: the service was silently absent for 15 days (user-facing), and the class remains open fleet-wide until the audit lands. Root cause: missing `wantedBy` (one line). Mitigation: landed today, deploy pending.
2. **The alerting loop failed its purpose.** A check that was red for 15 days with an active Discord alert produced no action. Either Discord delivery is broken, or chronic reds are untriaged noise. This is the most valuable finding of the session BEYOND the bug itself — a red-that-nobody-acts-on makes every other check untrustworthy. Needs the monitoring.md investigation (partially root-gated).
3. **My own session mistakes (four wasted tool calls):** two `systemctl` invocations rejected by the sandbox command allowlist before I checked what was permitted; two `fetch` calls missing the required `format` parameter; and one ~100KB truncated node_exporter `/metrics` fetch that did not even contain the metrics I needed — the correct move (grep the `system_health.prom` textfile directly) answered in seconds and one call. Impact: minutes + context, nothing landed wrong. Lesson recorded in §e.
4. **Shared-tree hazard during the session (flagged, untouched):** a parallel session is mid-restructure (AGENTS.md 605KB→34KB into `docs/agents/`, 15 new runbooks, 21 runbook appendices, commits d89029cf/8e6409dd) and `tests/test-dns-blocker-render.nix` changed in the tree during my session — NOT by me. My `nix flake check` green therefore certifies a moving tree at a moment in time; the other session's in-flight work rides the same verdict.
5. **Standing reds the session's metrics glance surfaced (not investigated — out of scope, listed for the record):** root NVMe `btrfs_health_critical 1` (unalloc 4.7G < 5% floor, 99% of device allocated — both balance jobs self-skip below their bounce-room gates); `llama_rag_leaks_present 1` with `leaked_instances 2` while the module is config-disabled (expected-instances=2 vs disabled looks like a collector accounting question worth one glance); `forgejo_mirror_health_scrape_errors 1`; `forgejo_subvol_backup_fresh 0` (expected — flip staged, owner window pending); architecture-catalog PLACEHOLDER-inert reds (expected until go-live); memory-emergency-guard mid-storm (restore-capped 1, sacrifice down, 6 trips in the last hour, io PSI some avg60 63.49%) — the box was storming throughout this session.

## e) WHAT WE SHOULD IMPROVE

1. **Make "starts" a verified property, not an assumption.** Prose lessons do not hold: the health-dashboard wantedBy lesson (2026-09-22) was written down, and mr-sync still shipped without enablement 3 days BEFORE the lesson — but nothing in the pipeline catches the class at all. Concrete fix: eval-time audit (c1), plus a post-deploy gate that fails when a newly-enabled unit is not active after switch.
2. **Chronic-red needs its own signal.** Gatus pages on transitions; a check that sits red for weeks generates noise that everyone learns to ignore (exactly what happened here). Add a "red > 24h" escalation path distinct from flap alerting, and audit the raw Discord delivery path end-to-end once.
3. **Probe textfiles, not /metrics.** node_exporter serves frozen textfiles from disk; a targeted `grep` on `/var/lib/prometheus-node-exporter/textfile_collectors/*.prom` is faster, complete, and sandbox-safe. The one full `/metrics` fetch this session returned 100KB of truncation and missed the target section.
4. **Check the command allowlist before invoking system binaries.** Two rejected `systemctl` calls cost nothing but signal — but in a repo where every deploy-minute counts, knowing the sandbox surface first is free discipline.
5. **New-service bring-up checklist needs enforcement, not prose.** "One verified unit start before the first deploy" is already the documented lesson; make it mechanical (post-deploy expected-active manifest, or the eval audit from (1)).
6. **Registry-wired services get a minimal VM test by default.** The integration registry fans out config surfaces at eval time only; a 2-minute VM test (unit boots, endpoint answers) would have caught mr-sync on day one. mr-sync is the second service without one that mattered.

## f) Next tasks (ranked; HARVESTED items already queued in TODO_LIST.md + domain libraries at authoring time)

| #  | Task                                                                                                                                                                       | Impact  | Effort | Category      | Queue status |
|----|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|--------|---------------|--------------|
| 1  | Deploy the mr-sync `wantedBy` fix (`nix run .#deploy`)                                                                                                                      | Critical | S     | Bug           | HARVESTED → services.md `[blocked:user]` |
| 2  | Post-deploy verification: Gatus green, :7331 answers, tile up, dashboard renders, token verdict, first cold-walk probe survives 15s bound                                  | High     | S     | Bug           | HARVESTED → services.md (same row) |
| 3  | Eval-time "never-enabled unit" audit (integration entry with checks/monitored ⇒ unit must have an enablement path)                                                          | Critical | M     | Quality       | HARVESTED → pipeline.md + queue |
| 4  | Gatus→Discord delivery E2E audit + chronic-red (>24h) escalation check                                                                                                      | High     | M     | Bug/Feature   | HARVESTED → monitoring.md + queue |
| 5  | mr-sync VM test (unit starts, `/` renders as lars, PLACEHOLDER token degrades gracefully)                                                                                  | Medium   | M     | Quality       | HARVESTED → services.md + queue |
| 6  | Post-deploy gate: newly-enabled unit must be ACTIVE after switch (expected-active manifest for registry services)                                                           | High     | M     | Quality       | not harvested (design needed) |
| 7  | Add an mr-sync smoke block to post-deploy-check.sh (loopback :7331 + protected vHost) — currently absent                                                                    | Medium   | S     | Quality       | not harvested |
| 8  | Document the wantedBy rule in the module-authoring docs (`docs/agents/` unit-domain file + CONTRIBUTING template) — prose home for the new eval audit                        | Medium   | S     | Documentation | not harvested (parallel session owns docs/agents today) |
| 9  | Confirm no other shipped module lacks enablement — superseded by item 3's audit output; run the audit and triage its findings                                               | High     | S     | Bug           | rides item 3 |
| 10 | Paste the mr-sync fine-grained PAT (or accept the degraded FetchError mode permanently — owner call)                                                                        | Low      | S     | Feature       | owner step (runbook documented) |
| 11 | Disposition the `llama_rag_leaks_present 1` standing red: collector expects 2 instances while the module is disabled — expected orphan doctrine or an accounting bug?        | Medium   | S     | Bug           | not harvested (noticed this session) |
| 12 | Investigate `forgejo_mirror_health_scrape_errors 1` (collector failing since when? journal first)                                                                           | Medium   | S     | Bug           | not harvested (noticed this session) |
| 13 | Root NVMe unalloc 4.7G is CRITICAL (<5%) and both balance jobs self-skip — check the existing storage.md chunk-headroom row covers the current reading; schedule the quiet-window balance dance | High | M | Bug | not harvested (storage domain, likely existing row — verify before duplicating) |
| 14 | Verify the freeze-#7 remaining fix (scrub timers `Persistent=false` + serialization) landed; metrics show both scrubs interrupted                                         | Medium   | S     | Bug           | not harvested (existing stability row) |
| 15 | Watch item: box is mid-IO-storm (guard restore-capped, 6 trips/hour) — batch any deploy with the storm's drain; the deploy pressure gate will enforce this anyway          | High     | S     | Bug           | informational |
| 16 | Fold the interim `crush-hot-db` module into the ratified `services.hot-db` Phase-2 module (standing pending item; storm driver class)                                       | Medium   | L     | Cleanup       | existing storage queue row — do not duplicate |
| 17 | Extend the "ship checklist" in CONTRIBUTING.md with the mechanical gate (item 6) once designed                                                                             | Low      | S     | Documentation | rides item 6 |
| 18 | Gatus check inventory pass: any other check whose alert has been firing >7 days continuously (same chronic-red blind spot, find them all)                                   | Medium   | M     | Bug           | rides item 4 |
| 19 | PapDashboard: the mr-sync tile transitioned unknown→down at restart; confirm tiles re-probe to "down" correctly for never-started units (probe semantics, not just render)  | Low      | S     | Quality       | not harvested |
| 20 | Change-log the incident per house convention when the fix deploys (runbook entry exists; CHANGELOG row at deploy time)                                                      | Low      | S     | Documentation | rides item 1 |
| 21 | Consider testing-mode→production flip discipline for any future OAuth clients surfaced by this class of bring-up (mr-sync token goes live with item 10)                     | Low      | S     | Documentation | informational |
| 22 | Tooling note for agent sessions: textfile-grep over /metrics fetch (this report §e3) — candidate for the crush-config AGENTS guidance                                       | Low      | S     | Quality       | not harvested |
| 23 | After item 3's audit exists, retro-run it against git history to find services that were NEVER noticed (the mr-sync of two months ago)                                      | Medium   | M     | Bug           | rides item 3 |

Items 6-23 beyond the harvested five are deliberately NOT queued yet: most are extensions awaiting the audit design (item 3), touch domains a parallel session is actively editing, or are owner steps. They are recorded here as the harvest source; say the word and they get routed.

## g) Questions I cannot answer myself

1. **Deploy timing/authority:** the fix is landed but the box is mid-IO-storm (guard restore-capped, avg60 63%) and deploy authority (queue-fired vs user-manual) is an open owner decision. Do you want `nix run .#deploy` run now (it will gate on the pressure check), batched with the parallel session's in-flight restructure, or deferred to a quiet window?
2. **Alert delivery:** "mr-sync Dashboard" has been red with an active Discord alert for 15 days and nothing acted. Do you actually RECEIVE Gatus Discord alerts (did any mr-sync alert ever reach a channel you read), or should I treat the Gatus→Discord path itself as broken and investigate accordingly (journal leg is readable; gatus.sqlite needs root)?
3. **GitHub token state:** the sops secret `mr_sync_github_token` is root-0400 so I could not read whether the fine-grained PAT was ever pasted. Is the PAT in (dashboard comes up fully populated), or should it come up in the designed degraded mode (FetchError banner, `.mrconfig`-only data) until you paste it?
