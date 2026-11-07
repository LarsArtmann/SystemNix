# Memory-Guard io-Restore-Gate Session — Fix Landed + Deployed + Live-Validated; VM Scenario Pending Behind a Storm Gate

**Date:** 2026-11-02, session ~11:30–15:05 CET (multi-day conversation; edits landed via daemon waves Oct 28 → Nov 2)
**Tree at write time:** HEAD `03be65857` (parallel session active: freeze #40 autopsy docs + TODO_LIST/stability/flake.lock in flight — NOT mine)
**Trigger:** owner pasted the 2026-10-25 browser-history 503 (`complete chat qwen3.6-moe:35b-a3b: dial tcp 127.0.0.1:52625: connect: connection refused` → `client.complete_failed_after_retries` → Transient 503) and asked "how can this happen?" → "fix it for the deployment on/at ../SystemNix/…"

---

## Verdict (one line)

The guard's socket-restore gate was MEMORY-only while the dominant trip zone is Zone 6 (io PSI) — the fix adds an io-drain axis (`restoreIoSomeAvg60ThresholdPercent`, default 20 = half the trip bar), it landed in-tree, **shipped in gen-968, and was live-validated the same night**: 463 trips (freeze #39) with the restore budget UNSPENT (0 restores, capped 0) vs Oct 25's capped-3/3-by-12:34Z all-day-dark failure. The authored VM scenario 6-io has NEVER EXECUTED (CI red since 10-29 on SSH-input auth, infra) — a self-sufficient storm-gated builder is armed and correctly holding at io ~98.

---

## What the fix is (for the fresh reader)

The restore `elif` in `modules/nixos/services/memory-emergency-guard.nix` gated on MemAvailable + memory PSI avg10/avg60 + episode bucket + cooldown. Zone 6 storms leave every one of those healthy, so the socket restored INTO the storm, the 21.6 GB flm cold load re-tripped Zone 6, and the daily budget (3) burned on doomed restores — the 2026-10-25 class. The gate now also requires `io_psi_some_avg60 < restoreIoSomeAvg60ThresholdPercent` (fail-closed on unreadable PSI, like every other restore gate). The churn re-arm has used exactly this doctrine since 2026-09-17 (io < 40); the socket was the only unit allowed to re-enter a storm. Ladder: trip 40 / memory restore 5,10 / **io restore 20** / churn re-arm 40 / backup catch-up 50.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Root-cause diagnosis | live prom (io 83%, capped 1, socket 0) + module read + asymmetry vs churn re-arm line |
| 2 | Restore elif io gate + option `restoreIoSomeAvg60ThresholdPercent` (default 20) + header incident paragraph + capped/cleared journal wording | in HEAD; option declared exactly once; grep count 8 |
| 3 | Deployed | gen-968 (01:04 Nov 2, parallel session); live `/etc/systemd/system` ExecStart `b87z7izw…` carries the gate at script line 709 |
| 4 | Live validation | 463-trip freeze-#39 night: budget 0 used, capped 0 — Oct-25 all-day-dark did NOT recur; socket still trips at peaks (sacrifice semantics, 3 flm cycles) and self-recovers post-drain |
| 5 | VM scenario 6-io + fixtures `restoreIoMild`/`restoreIoDrained` authored (mild-storm hold must NOT restore or consume budget; drained restore must fire) | in HEAD; budget-neutral vs 6a/6b-cap (its reset_state clears counters) |
| 6 | `guard-restore-io-gate-selftest` static tripwire | built green locally (`nix build .#checks.x86_64-linux.guard-restore-io-gate-selftest`) |
| 7 | `nix flake check --no-build` | ALL CHECKS PASSED (at my-edit HEAD) |
| 8 | Rendered-script proof | realized ExecStart script: `bash -n` OK + threshold ladder visible (trip 40 line 255, restore 5/10/**20** lines 555-557) |
| 9 | Scoped treefmt | 0 changed (alejandra-clean) |
| 10 | Runbook `docs/services/memory-emergency-guard.md` restore section | updated (io gate + incident); later sessions extended it for ioPause |
| 11 | CHANGELOG entry | landed + two precision passes (deploy-pending → DEPLOYED by gen-968; socket-UP claim softened to budget-unspent + flap semantics) |
| 12 | `docs/todo/stability.md` decision rows (restore-cap policy, boot reset) | io-gate context appended to both |
| 13 | `system-health.nix` trip alert text | now mentions the io-drain restore bar |
| 14 | browser-history AGENTS.md gotcha | updated ×2 (root-cause fixed + deployed + live-validated); daemon-swept `60822a9` |
| 15 | CI red root-caused | `Permission denied (publickey)` fetching SSH-form inputs (Oct-29 `ca3acb6e3` sweep); NOT content; existing `[blocked:user]` row `docs/todo/pipeline.md` updated with the widening + consequence (no green CI since 10-29) |
| 16 | Daemon-wave co-rider review | foreign files flagged (caddy.nix/otel-endpoint-audit/signoz-coverage rode my waves = parallel session's; freeze-39 commit is docs-only) |
| 17 | Storm-gated builder v2 armed | `~/tmp/tmpdir/vmtest-guard-gate.sh` → log `~/tmp/tmpdir/vmtest-guard-build.log`; freshness-checked, io<20 sustained 9 min, nice/ionice, 7.5 h budget; currently correctly holding (io 98) |

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| 1 | **VM scenario 6-io execution** | authored+pushed but NEVER run (CI infra-red; local gate armed, holding). Closure is warm — dry-run shows exactly ONE derivation to build, so the run is minutes once calm returns |
| 2 | CI validation of the fix wave | blocked entirely by the SSH-input auth gap (owner console needed) |
| 3 | Behavioral proof of the fix | live-production observation only (strong: budget survived a 463-trip night) — harness proof pending item b1 |

## c) NOT STARTED

| # | Item |
|---|------|
| 1 | browser-history product UX for the sacrificed-LLM window: chat/summary SSE toast still shows generic "Temporary error" during storm peaks — could distinguish "LLM backend temporarily sacrificed by memory guard" (map the ECONNREFUSED class in `client.Classify` consumers) |
| 2 | PSI-gating my OWN eval/build commands (I ran flake check/selftest-build/dry-runs during active churn — light, but ungated) |
| 3 | Self-harvest of §f follow-ups into TODO_LIST + domain library — **deliberately deferred**: TODO_LIST.md + stability.md are mid-edit by the parallel freeze-#40 session (concurrent-edit race); harvest after quiescence (rows f1–f3 below name the targets) |
| 4 | Any deploy action by me (correctly out of scope: deploy.sh PSI/trip-recency gates + owner action) |

## d) TOTALLY FUCKED UP (honest)

No damage shipped; all self-caught or corrected, but four real stumbles:

1. **First VM-scenario draft had a guaranteed-red assertion** — `cat restores-* == "1"` after `reset_state()` deletes that file; `cat` errors. Caught pre-commit by tracing state, but the right order is trace-then-write.
2. **"deploy pending" claims written without probing deployment state** — went stale within the session (gen-968 shipped it); needed two correction passes across two repos. Should have grepped `/etc/systemd/system` ExecStart at claim time.
3. **First storm-gate design was mathematically unsatisfiable + result-lossy** — required `trips_last_hour ≤ 2` (cannot fire within an hour of a 22-trips storm: window decay) and no prom-freshness check; its timeout verdict was lost because the background shell vanished between turns. v2 fixes all three (freshness gate, io-only, persistent log).
4. **Burned several tool calls on commit-date "time paradox" theorizing** (Oct-29 commits containing "today's" edits) before checking author-vs-committer dates + HEAD content — the content was the only thing that mattered; the conversation simply spans days with context re-rendering.

## e) WHAT WE SHOULD IMPROVE (lessons, generalizable)

1. Probe live state (`/etc/systemd/...`, prom, systemctl-equivalents) BEFORE writing any "deployed/pending" claim.
2. Design test scenarios by walking the state machine first (what does reset_state delete? what does each counter hold?), then write asserts.
3. Background jobs must persist results to files — never rely on retrieving a shell across turn boundaries.
4. Gate conditions must be satisfiable given window-decay math (trips_last_hour semantics).
5. On commit confusion: read HEAD blobs + `%ad/%cd` first; theorize never.
6. Rendered artifacts: predict interpolation before grepping (option name → literal `20`).
7. In multi-session repos, verify HEAD blob content, not working-tree memory.
8. Even eval-time nix commands deserve a PSI sanity check on this box.
9. Report claims get one precision pass BEFORE the user asks (the socket-UP overstatement needed the storm autopsy to catch).

## f) NEXT (curated, grouped; ~34)

**Verification closure (this fix)**
1. Read `~/tmp/tmpdir/vmtest-guard-build.log` → want `BUILD_EXIT=0`; if red, triage scenario 6-io vs ioPause scenarios (the latter = other sessions').
2. If the gate prints DEFERRED, run `nix build .#checks.x86_64-linux.memory-emergency-guard --no-link` manually in the first io<20 window (1 derivation, minutes).
3. After 6-io runs green, cite it in the CHANGELOG entry (replace "pinned red-green by VM test" aspirational wording with the actual run).
4. Re-run `nix flake check --no-build` on CURRENT HEAD once (my green predates freeze-#40 doc commits — eval-neutral, but cheap to re-assert).
5. Existing repo watch row "authored-but-never-executed VM scenarios" (pipeline.md) — mark 6-io executed; sweep the guard test's other scenarios once while the closure is warm.
6. Selftest dependency note: `guard-restore-io-gate-selftest` only runs in CI — currently dead infra; note in the row that local selftest runs are the only signal until auth lands.

**Storm/guard (adjacent, noticed during validation)**
7. Tonight's watch: does the budget survive freeze #40/#41 (expect capped=0; restores only post-drain)?
8. Identify what started fastflowlm at 01:51:23 (third start; io was ~97%) — deploy re-arm vs consumer socket-activation vs service restart policy; the storm doc leaves it ambiguous.
9. llama-chat OOM-loop = cold-load storm engine (`Restart=on-failure`+10s re-fires a 20 GB load) — pair with the existing ready row "PSI entry gate for model-load units".
10. Weekly fstrim vs QLC storm overlap (ran 105+ min during freeze #39) — PSI-gate or reschedule.
11. Deploy re-arm-into-storm: gen-968 activation restarted owner-stopped units (nsfw-classifier, llama-chat timer) — trip-recency gate for `switch-to-configuration test`?
12. ioPause pattern list missed every storm driver ("NO eligible headless tree matched" ×587) — add model-load cgroup patterns or document the boundary.
13. ioPause "escalation arms after 3 trips" never fired — why?
14. Re-adjudicate `maxRestoresPerDay` (stability.md decision row) with post-fix burn-rate data — the budget now survives storms; 3 may be raiseable.
15. Boot-reset decision row — same re-adjudication (io-gate removed the churn leg that motivated per-DATE keying).
16. Add a restores-per-day-per-zone metric (budget burn-rate observability).
17. The io-gated HOLD is currently journal-silent — verify the verbose heartbeat covers it or add a disclosed hold line (operator should see WHY the socket is still down).
18. Gatus memory-guard check text + sev1-escalation details: sweep for other "restores once memory recovers" wordings missing the io axis (alert text in system-health.nix done; two more surfaces to audit).
19. `post-deploy-check.sh` flm leg: pat budget state (`restore_capped`) alongside the ActiveState fix already queued.
20. Reconcile stability.md "thresholds unchanged (40/20)" verdict row with the restore-20 semantics (probably 40=trip/20=rearm there — confirm no doc contradiction).

**browser-history (the original error's product side)**
21. SSE error payload: distinguish "backend sacrificed (ECONNREFUSED during guard window)" from other transients — actionable copy instead of generic retry hint.
22. `/health` aiHealth: expose a distinct "llm socket down (guard)" signal vs breaker-open.
23. Sweep other fastflowlm consumers (PMA commit msgs, paperless enricher logs) for the same blind spot.
24. Quantify before/after: trips-vs-restores-vs-capped timeline Oct 25 → Nov 2 from `trip-history` (evidence artifact for this fix).

**Infra/CI**
25. Owner console: deploy key for SSH inputs (pipeline.md `[blocked:user]` row) — until then every pushed fix is CI-unvalidated.
26. Post-auth canary: docs-only commit must go green across all four workflows before trusting CI again.
27. Turn infra-auth failures into a NAMED signal (workflow step that fails loudly "CI cannot fetch inputs" vs eval failures).

**Session hygiene**
28. Preserve the gate script as `scripts/vmtest-quiet-window-gate.sh` (it currently lives in ephemeral `~/tmp`) — pending owner answer (question 3).
29. Harvest §f rows 1-2 + 14 into TODO_LIST + stability library once the parallel session's TODO_LIST/stability edits land (race avoidance, recorded in c3).
30. Pathspec-commit this status report if the daemon hasn't swept it before push-time (mixed-dirty-tree rule).
31. Consider a one-line AGENTS.md (SystemNix) prevention-layers table entry for the io-restore gate.
32. Verify the corrected gotcha text reads cleanly in a FRESH browser-history session context (file already over size budget — my +8 lines should stay tight).
33. Check whether thermal-pstate-guard or any other unit reuses memory-only "restore" semantics (pattern audit — one grep).
34. After the next capped event (if any), verify the "memory AND I/O" capped journal wording renders (line only fires on the capped path).

## g) QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Is an executed VM scenario a deploy-blocking gate for guard changes**, or is live-validation (budget-unspent through a 463-trip night) + CI-when-fixed acceptable? (Risk-appetite call: I armed the gate, not a rule.)
2. **Cap policy**: now that the budget survives storms, keep `maxRestoresPerDay = 3`, raise it, or make capped-state handling louder (the stability.md `[decision]` row — yours; my data says 3 is comfortable)?
3. **browser-history UX during storm peaks**: consumers 503 by design while the guard holds the socket — want me to build the "LLM temporarily sacrificed by memory guard" product surface (distinct toast + health signal), or is the generic transient error acceptable for a homelab?

---

## Timeline (this session's turns)

1. **"How can this happen?"** — live diagnosis: guard sacrificed the socket, budget capped 3/3, Zone-6 churn storm; explained the full 503 causal chain (refused → go-aichat transient retry-exhausted → errorfamily 503).
2. **"fix it for the deployment"** — module read → asymmetry found → gate + option + header + journal lines + VM scenario + selftest + runbook + CHANGELOG + stability rows + alert text + browser-history gotcha; verification battery green (selftest, flake check, bash -n ladder, treefmt); VM-test build deferred as "needs quiet window".
3. **"think"** — cold-load io math (a calm-machine cold load contributes ≤~33% to avg60 — below the 40 bar; restore-into-calm keeps Zone 6 quiet), cross-scenario budget audit (all pre-existing restore fixtures default io 0.00 → unaffected), stale-surface sweep found alert text + decision rows.
4. **"READ/UNDERSTAND…" (1)** — daemon reconciliation (dates vs edits → multi-day conversation), HEAD-content verification (all landed, no duplicates), freeze-#39 discovery, **gen-968 deployed-state discovery**, precision-corrected validation claims, CI red root-cause (SSH inputs), gated build v1 (flawed).
5. **"READ/UNDERSTAND…" (2)** — gate v2 (freshness + io-only + ionice + persistent log), corrections landed verification, pipeline.md row widened, storm-gate armed and correctly holding.

**Live at write time:** io 98.92, trips 19/h, socket DOWN (trip), capped 0, budget unspent — the fix's semantics visible in production in real time.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.3 f.30 · OBSOLETE f.1 f.2 f.4 f.7-9 f.19 f.23 f.29 f.32 · already-tracked f.5 f.10 f.11 f.13 f.14 f.18 f.25 f.33 · NEW rowed: 13 rows → stability 7, services 2, pipeline 3, monitoring 1
