# Health-Hub /readyz 503 → cv Remote Dark: Diagnosis-Only Session Status

**Instance:** Crush (glm-5.3-flash), SystemNix repo, single-session diagnostic dispatch
**Window:** 2026-11-03 ~21:21 → 21:35 CET
**HEAD at start:** `0f23ab1a4` · **HEAD at report time:** `bc2869e40` (auto-commit daemon advanced the tree mid-session — expected, shared-tree discipline)
**Working tree at start:** clean · **This session changed:** this report + 3 new queue rows (see §f harvest tags); ZERO source/config changes

**Trigger (verbatim input):** `FAIL Health Hub - /readyz status '503' - a remote is dark or reporting fail (check HEALTH_HUB_REMOTES in the unit + the remote's own /health)` — a post-deploy-check §e leg.

---

## TL;DR

The FAIL is **correct and correctly attributed**: the federated health hub (127.0.0.1:8103) is alive (`/healthz` 200) but its aggregate `/readyz` is 503 because exactly ONE remote is dark — **`cv/reachable`**, the CV resume server. The root cause is the already-documented, already-queued **cv-server SIGSEGV restart loop** (docs/services/cv.md:234-247, docs/todo/upstream.md:245, TODO_LIST.md:1839 — all landed by today's parallel sessions): boot rehydration loses the 5 s `sqliteOperationTimeout` race against the outgrown `pipeline_events` table, the chatstore stays nil, and the samber/do healthcheck nil-derefs (`addr=0x8`) every few minutes-hours. Live this session: **8 SIGSEGVs in the trailing 2 h**, unit active/running (pid 1760918, started 21:14:10, rehydration failed ×3 at 21:14:43), and **NO listener on 127.0.0.1:8098** — the process survives between panics but the HTTP server never binds on this boot. **No SystemNix-side remediation exists** (rev-independent; the 16a656f4 rev-pin was tried and retracted today by a parallel session). The FAIL clears automatically once the upstream CV fix lands, re-locks, and deploys.

---

## a) FULLY DONE

Every step below is live-probed this session with the probe command cited; nothing asserted from doc claims alone (planning-layer pre-read + live-state verification discipline, 2026-10-05).

1. **Session-discipline pre-reads** — `rg -il` across docs/status/ + docs/todo/ for health-hub/readyz signatures FIRST; content-pin (`git rev-parse HEAD` + clean-tree check) before any work. The pre-read correctly surfaced that today's parallel sessions already owned the cv incident.
2. **Hub liveness proven** — `curl http://127.0.0.1:8103/healthz` → **200**; `ss -ltn` shows the hub bound on 127.0.0.1:8103 (ports.health-dashboard). The hub itself is NOT the problem.
3. **Aggregate verdict decoded** — full `/readyz` merged document fetched and parsed with `jq` (FILE-ARG trap avoided via `env -u DIRENV_DIFF jq`): exactly **one failing check namespace** — `cv/reachable = fail` — across 66 checks; all 7 other remotes pass (discordsync, dnsblockd, nsfw, pma, renamer, renamer-watcher, tq). tq's 3 warns (`dlq`, `projection`, `workers`) are tolerated-by-design per scripts/post-deploy-check.sh:1387 (warn never flips the aggregate).
4. **Remote dark confirmed at the socket layer** — `curl http://127.0.0.1:8098/health` → `000` (connection failure); `ss -ltnp` shows **nothing listening on 8098** (nearest: 8097 + 8099 belong to other services — probed and identified, not confused with cv). The cv process itself is ALIVE (`pgrep -af` → pid 1760918 `/nix/store/rras5x…-cv-16a656f/bin/cv serve`, cgroup `system.slice/cv-server.service`, `busctl` → ActiveState=active SubState=running).
5. **Root cause identified via journal + runbook match** — `journalctl -u cv-server --since '6 hours ago'`: 21:14:10 start → `Server configuration loaded port=8098` → rehydration FAILED ×3 (`career-pipeline: query all events: context deadline exceeded`) → 8 × `[signal SIGSEGV … addr=0x8 pc=0x20d215c]` in the trailing 2 h with restart counter cycling 0→3. Exact signature match to the runbook incident (docs/services/cv.md:234-247), which today's parallel sessions root-caused, rev-pin-retracted, and queued.
6. **Runbook + queue cross-check (no drift found)** — docs/services/cv.md incident playbook (committed in `b6379612a`), docs/todo/upstream.md:245 `[blocked:push]` fix row, TODO_LIST.md:1839 queue one-liner — all three surfaces present and mutually consistent (correct-surface discipline verified rather than assumed).
7. **Federation-drift sweep state verified (this session's own addition, done at report time)** — `health-dashboard-rediscover.timer` last trigger 2026-11-03 17:56 local, service "Deactivated successfully" (exit 0 = no unfederated go-health speaker found). The 2026-11-02 remotes-stale incident class is NOT recurring. This closes the "did the sweep silently find another missing remote?" question — answer: no, cv is the only anomaly.
8. **Remediation-space mapped and bounded** — restart (no: rev-independent, ~24/7 loop since 2026-11-02), rev-pin (no: tried + retracted today), config change (no: nothing in SystemNix controls the 5 s timeout vs table size). Conclusion: correct verdict is **"known incident, queued upstream, no agent-side action"** — and that verdict was stated rather than manufacturing busywork.

## b) PARTIALLY DONE

1. **Secondary symptom triage (cv → crm at 8091)** — observed: a burst of `context deadline exceeded` from cv→crm company/opportunity lookups 21:15:55-21:21:22, then SUCCESSFUL HTTP from 21:25 onward (HTTP 409 "deal does not exist or is closed" responses — reached the API, data-level errors). Assessment: transient boot-window storm during cv's failed rehydration, self-cleared; crm-server was listening throughout (8091 in `ss` from the start). NOT queued (deliberately — low signal, self-cleared), but the correlation (cv boot storm → CRM call pileup) is only asserted, not fully timeline-proven.
2. **Close-out of the §e FAIL itself** — verdict fully delivered (which remote, why, since when, what clears it), but NO remediation was executed because none exists; per the 2026-09-18 rule the verdict leads with the contradiction (503 while hub healthy) and answers exactly what the FAIL asked. What remains partial: the battery was NOT re-run, so the rest of §e's green-ness is unverified this session (→ §f item 1).
3. **Self-harvest of §f follow-ups** — executed at report authoring time per the status-report discipline (3 new rows, tagged in §f below), but the harvest deliberately EXCLUDES anything already queued by the parallel sessions (duplicate-row class) and marks transient observations as not-harvested with reasons.

## c) NOT STARTED (none of it was this session's scope; listed for completeness)

1. **The actual cv fix** — nil-guard `ChatstoreSessions.HealthCheck` + chunked/raised rehydration. Owned upstream, `[blocked:push]` (agents never push), queued at docs/todo/upstream.md:245. This session did NOT touch the CV repo.
2. **Lift the 16a656f4 rev-pin after the fix lands** — drop pin + shim, re-lock, toplevel proof (drop-condition already documented in flake.nix + pin-audit allowlist row).
3. **Post-fix verification chain** — 8098 listener bound, `/health/live` version-stamp = new rev, hub `/readyz` back to 200, Gatus `CV PDF Export` green.
4. **cv-server crash-loop DETECTION (vs the loop itself)** — the 21-24 parallel report's §26 follow-up ("Add crash-loop detection (NRestarts-delta or unit-failure-rate check) for cv-server"). Verified this session: NO matching row in TODO_LIST.md (grep `crash-loop|NRestarts` → unrelated rows only). This is that report's self-harvest obligation; flagged here rather than duplicated — **the 21-24 report author should land it or record why not**.
5. **Known-incident annotation for post-deploy §e** — didn't exist before this session; now queued as a `[decision]` row (§f item 2).
6. **Hub merged-doc diagnostics upstream** — didn't exist; now queued `[blocked:push]` (§f item 3).

## d) TOTALLY FUCKED UP

**Nothing.** Honest accounting of the nearest misses, all caught by existing guards:

1. **`rg -rln` trap — THIRD strike of this exact trap on this host** (AGENTS.md session-discipline bullet, 2026-10-23). I typed `rg -rln 'cv-server' …` (intending recursive+line-numbers); the pre-execution hook BLOCKED it before any damage. No output was mangled, nothing mis-read. The trap is documented, the guard works — but an agent hit it again, which is itself the signal that the guard (not vigilance) is the working defense.
2. **`systemctl` guard-block** — first probe attempt typed `systemctl status`; rejected at parse time per the ops-binary ban. Switched to the verified substitute set (`ss -ltnp`, `busctl get-property`, `journalctl -u`). One wasted tool call, zero damage.
3. **No destructive commands, no `rm`, no git state changes, no commits, no force-anything, no service restarts** (a cv-server restart was considered and explicitly rejected as a no-op risk — the process was already mid-loop; touching it would only reset the panic clock and muddy the parallel session's evidence window).
4. **One honest process gap**: my first command batch ran before the §e-fail scope was fully framed, i.e. the single-FAIL triage never enumerated the REST of the battery (see §e.1). Not damage — an incompleteness, now queued.

## e) WHAT WE SHOULD IMPROVE

1. **Enumeration discipline for verification sweeps, not just builds.** The `--keep-going FIRST` critical rule exists for deploys; the same class applies to triaging ONE failing §e leg: don't declare the battery otherwise-green from absence of evidence. One full re-run enumerates every failure in a single pass. (Queued, §f item 1.)
2. **When a service's health is in question, sweep its SIBLING guard units in the same pass.** The hub has a drift-sweep timer (rediscover) whose green state materially narrows the diagnosis; I checked it only at report time, after the verdict. Habit: probe the guard units (timers/oneshots/convergers) alongside the service itself.
3. **The §e FAIL line should name the culprit.** The hub's merged doc CONTAINS the failing namespace (`cv/reachable`), but scripts/post-deploy-check.sh:1389 prints a generic "a remote is dark" — the triaging agent must re-fetch and jq to learn what the probe already knew. One-line script enrichment: parse the readyz body and include failing namespaces in the FAIL text. (Folded into the §f.2 decision row rather than landed unilaterally — script semantics change = owner-visible output change.)
4. **Alarm fatigue is real and now live**: until the upstream CV fix deploys, EVERY battery run FAILs the health-hub leg by construction. Ground-truth FAILs are correct, but a known-incident annotation mechanism (marker file + expiry, or a WARN-downgrade for checks with an open incident marker) deserves a policy decision before the next multi-day incident makes every deploy report red. (Queued `[decision]`, §f item 2.)
5. **Hub diagnostics belong in the hub**: `cv/reachable` fails with EMPTY output — no last-error, no last-success timestamp. Triage required manual socket+journal probes of the remote. A per-remote `lastError` + `lastSuccess` in the merged document (upstream go-health-dashboard feature) makes "which remote, since when" a single-fetch answer. (Queued `[blocked:push]`, §f item 3, verify-before-filing gated.)
6. **Two guard-trips in one short session** (rg `-r` trap, systemctl ban) is not a failure — the guards did their job — but it re-confirms that the guard layer, not agent memory, is the durable defense. Keep hardening the hooks; do NOT rely on agents remembering AGENTS.md bullets.

## f) WHAT WE SHOULD GET DONE NEXT (session-derived, provenance-tagged)

**NEW — harvested this session into the queue (TODO_LIST.md + domain file, authoring-time self-harvest):**

1. `[ready]` **Re-run the full post-deploy battery ONCE while the cv incident is live** — enumerate ALL §e failures in a single pass instead of triaging the single health-hub FAIL in isolation (the `--keep-going` discipline applied to verification sweeps). → TODO_LIST.md + docs/todo/pipeline.md (Source: this report §e.1)
2. `[decision]` **Known-incident annotation for post-deploy §e + FAIL-line enrichment** — owner policy call: (a) marker-file downgrade with expiry, (b) keep FAIL + enrich the line with the failing remote namespace(s) parsed from the readyz body, (c) status quo; folds in the gatus-/readyz-probe rejection rationale (an aggregate probe would storm during known incidents). → TODO_LIST.md + docs/todo/pipeline.md (Source: this report §e.3/§e.4)
3. `[blocked:push]` **go-health-dashboard upstream: per-remote evidence in the merged /readyz doc** — `lastError` + `lastSuccess` per remote so triage is a single fetch; gate through verify-before-filing (probe the upstream doc schema first). → TODO_LIST.md + docs/todo/upstream.md (Source: this report §e.5)

**ALREADY QUEUED by today's parallel sessions — do NOT re-harvest (verified present, no drift):**

4. Fix the cv boot-rehydration nil-deref upstream — docs/todo/upstream.md:245 + TODO_LIST.md:1839 `[blocked:push]` (the FIX for everything in this report)
5. Lift the 16a656f4 rev-pin after the fix lands (drop-condition documented in flake.nix + pin-audit allowlist row)
6. Post-fix verification chain (8098 bound, `/health/live` stamp, hub readyz 200, Gatus `CV PDF Export` green)

**FLAGGED, owned by the concurrent session's report (its self-harvest obligation, verified absent from the queue this session):**

7. cv-server crash-loop detection (NRestarts-delta / unit-failure-rate check) — the 21-24 report's §26; I do not duplicate another report's unharvested follow-up.

**DELIBERATELY NOT HARVESTED (with reasons, per the discipline):**

8. cv→crm 8091 boot-window timeout burst — transient, self-cleared by 21:25 (successful HTTP incl. 409 data-level responses), crm-server listening throughout; queueing would add a low-signal watch row. If a SECOND burst appears outside a cv boot window, harvest then.
9. tq warns (dlq/projection/workers) in the merged doc — tolerated by design (script comment); no action.
10. Gatus /readyz aggregate probe — rejected idea, rationale folded into item 2's decision rather than queued standalone.

**Adjacent hygiene (observed en passant this session, not incident-blocking):**

11. The 21-35 window shows the tree moving under the session (`0f23ab1a` → `bc2869e40` daemon commits) — nothing to do beyond the standing shared-tree rules; noted because the report's HEAD citations differ start vs end.

(10 candidate items beyond the three harvests were considered and rejected as padding; "up to 50" read as a ceiling, not a quota — a diagnosis-only session honestly yields three new actionable rows.)

## g) QUESTIONS FOR THE OWNER (not self-answerable)

1. **Interim CV posture until the upstream fix lands (days?):** live with the crash-loop (CRM sync works between panics; only 8098/product surface is dark), or attempt the root-gated mitigation now — `pipeline_events` compaction / backup-restore surgery per docs/services/cv.md §Restore drill? That is data-risky DB surgery with a live-writer stop order, and the runbook marks it owner-gated; it also does NOT fix the nil-deref (rehydration still loses the 5 s race on a smaller-but-big table) — so my read is "wait for the upstream fix", but the product downtime is yours to weigh.
2. **Post-deploy §e known-incident policy (§f item 2):** when a FAIL is a known, queued, upstream-owned incident — do you want (a) an annotated downgrade (WARN + marker with expiry), (b) enriched FAIL text only (names the culprit), or (c) raw FAIL as perpetual ground truth? This decides a recurring red signal's meaning for every future deploy report.
3. **Do you want the full battery re-run NOW (§f item 1)?** It is ~5-10 min of endpoint probes + journal reads on a box currently at IO PSI some avg60 ~71 % (the 21:2x window logged 51 guard trips + 122 throttle ENTERs since boot 49e157e0 at 17:41). Under storm, §e probes can false-fail (the script has a storm-suspect path for Pocket ID, not for every leg). Options: run now and accept storm-noise, wait for the agent-load pause the stability row already queues, or fold it into the next scheduled post-deploy.

---

*Report per owner directive 2026-11-03 21:35 CET. Self-harvest complete (items 1-3 landed; 4-11 dispositioned above). Waiting for instructions.*
