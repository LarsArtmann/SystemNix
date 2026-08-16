# Discord Alert Fix Batch — Session Status & Brutal Self-Review (COMPLETE, Verified)

**Date:** 2026-08-16 03:30 CEST
**Arc:** Diagnosis session (`01-34_DISCORD-ALERT-SPAM-DIAGNOSIS.md`) → this session executed the entire fix plan: research closed, all 5 root causes fixed, deployed twice, verified live, docs updated. Companion report with verification evidence: `2026-08-16_03-09_DISCORD-ALERT-FIX-BATCH.md` (rewritten to final state).
**Git:** fix batch committed by daemon as `66e78231` (bundled with unrelated focus-follow/zellij work — not my commit, not my message). Uncommitted now: AGENTS.md, CHANGELOG.md, gatus-config.nix (pat fixes), scripts/pre-deploy-check.sh, both status reports — all deployed, awaiting daemon pickup.

---

## a) FULLY DONE

1. **Research closed (was ~85%):** external URL key = `alertmanager.signoz.external_url` (verified in source + deployed config); channel update = `PUT /api/v1/channels/{id}`; rule in-place update = `PUT /api/v1/rules/{id}` (preserves ruleId); v5 rules accept `annotations` with `{{ $value }}` templating; fired alerts carry `alertname`/`ruleId`/`ruleSource`.
2. **C5 (nvme phantom zeros) proven to 100% from the exact deployed nvme-cli 2.16 source:** JSON keys are `avail_spare`/`percent_used`/`spare_thresh`; `available_spare` is a bit-name inside the `critical_warning` sub-object. Live proof afterward: **100% spare / 13% used / 10% threshold** reported, `keys_missing 0`.
3. **C1 (provisioning churn) — provisioner v5 deployed and proven:** run 1 converged (channel PUT 204, 17 rules PUT in place with ruleIds preserved, 3 zombie pairs deduped, convergence assertion OK); run 2 (deploy's second restart): **all 20 rules "Unchanged — skipping"** — the deploy-time double-restart now emits ZERO notifications. Live API: 20 rules / 20 unique / zero dupes.
4. **C2 (label-dump bodies):** channel carries custom templates (title `🔴/🟡/🟢 Name`, body description+value+ruleSource link); rules now ship `annotations.description` so the body template has content.
5. **C3 (localhost links):** `alertmanager.signoz.external_url = https://signoz.home.lan` live in deployed signoz.yaml. Caveat discovered honestly: no SigNoz frontend is shipped (`web.enabled=false`, no dist) — links are correct URLs that render 404 until a frontend package exists; alert bodies stay self-contained.
6. **C4 (PMA threshold flap):** thresholds now derived at collection time — 90% of each unit's own MemoryMax; live: PMA threshold = 15,461,882,265 bytes = exactly 90% of 16G; per-service values all distinct and correct.
7. **service-down + service-failed-spike rules fixed:** per-unit query (alerts now name the unit) and a real metric replacing the never-emitted `ntfy_systemd_unit_failed_total`.
8. **Bonus find — two latent Gatus pat bugs:** value-pats like `pat(*metric 0*)` never match labeled lines. The pre-existing "NVMe Endurance Warning" check had been failing EVERY run for days (silently blind). Audited ALL unlabeled value-pats in gatus-config.nix against live .prom lines; fixed both broken ones (mine + pre-existing), verified `success=true` in the gatus journal; all other mismatches are truthful conditions (disk 90%, PSI, backups broken).
9. **Docs:** AGENTS.md +5 gotcha entries (provisioner-converge pattern, Discord rendering internals, external_url + UI-not-shipped, nvme-cli 2.16 key names); CHANGELOG entry; pre-deploy-check KNOWN_NEW_METRICS pruned + stale entries removed; this report + the 03-09 companion.
10. **Gates:** `nix fmt` clean ×2, `nix flake check --no-build` passed ×2, deploy ×2 (38 PASS / 5 FAIL both times — the 5 are the pre-existing monitor365/browser-history outages; zero regressions from this batch).

## b) PARTIALLY DONE

11. **End-to-end Discord rendering:** every component verified deployed (templates, annotations, external_url) but no alert fired during the session — the final visual proof (a real 🔴 message with value + link) awaits the next genuine event. Checklist in companion report b.9.
12. **SigNoz UI absence:** documented (a.5), queued as its own task (frontend packaging is a node build, out of scope here).

## c) NOT STARTED (carried queue)

Prior report §f items 21–40: root-disk relief (~90%), monitor365 backup incident, btrfs scrub completion, btrfs corruption sentinel, Gatus-vs-SigNoz overlap policy, send_resolved-for-warnings, dashboard v2 rewrite, eval-time metric-presence check for SigNoz rule queries, provisioner VM idempotency test, audit of remaining rule queries, prior-session P0 remainders, Sunday buildcache-gc check, Gatus reminder mechanism, userSlice/GPUActive threshold derivation. New: gatus meta-check auth fix (d.15), unlabeled-value-pat lint (e.17).

## d) TOTALLY FUCKED UP (honest ledger — the 11 questions, answered straight)

13. **What did you forget? (Q1)** — To verify my own new Gatus check's pat against the actual emitted line BEFORE deploying it (shipped red once, caught in verification, fixed). Also forgot for a while that `/tmp` and unlocked store paths are volatile working copies (source vanished twice). And I nearly forgot the standing directive mid-session: I stopped to write a "we are interrupted" status report when nothing had interrupted me (d.16) — the opposite of what was asked.
14. **What is stupid that we do anyway? (Q2)** — The `|| 0` / `// 0` fallback culture in collectors: THREE separate silent-zero instances surfaced this arc (nvme metrics ×2 collectors, gatus meta-check). We keep writing "safe defaults" that convert missing data into confident zeros. Also: the auto-git daemon bundles unrelated parallel work into one commit (`66e78231` mixes my alert fixes with focus-follow/zellij) — history is becoming unauditable.
15. **What could you have done better? (Q3)** — Loaded the gatus journal for my new check IMMEDIATELY after deploy 1 instead of trusting `system_gatus_endpoints_in_error_long 0` (which I then discovered may itself be a phantom zero — d.15). One journal read was the difference between shipping blind and catching the pat bug pre-deploy.
16. **What could you still improve? (Q4)** — The pat lint (e.17), the meta-check auth (d.15), and the eval-time SigNoz rule-query validation — all three are "verify the verifier" gaps this arc proved expensive.
17. **Did you lie to you? (Q5)** — Twice by narrative, never by intent: the premature "interrupted at gates" report (false framing, corrected by rewrite), and my audit script's first run that flagged 40+ healthy pats as broken (broken verifier, not broken checks — reran before acting on it). Also repeated last session's `rg -rn` typo verbatim despite it being in the ledger.
18. **How can we be less stupid? (Q6)** — Encode every lesson as a CHECK, not a comment: phantom-zero → keys_missing metric + Gatus check (done); pat-label mismatch → lint (queued); meta-monitor failure → auth fix (queued). Prose has failed three times now; automation hasn't failed yet.
19. **Ghost systems? (Q7)** — One found: the SigNoz dashboards v1→v2 "best-effort" provisioning has been failing with HTTP 400 (`unknown field "title"`) on every deploy since the v2 API landed — five dashboards that exist as files and will never apply. It's honest in logs (WARNING) but it's a ghost: consuming attention, providing nothing. Decide: rewrite in v2 schema or delete the files and the loop.
20. **Scope creep? (Q8)** — Mostly held: the pat audit was justified (found days-blind check). The SigNoz-frontend investigation went two greps past need (stopped before building anything). The premature report was scope SELF-invention — worst kind.
21. **Removed something useful? (Q9)** — No. The delete+recreate provisioner logic it replaced was strictly worse (its convergence assertion is a superset of its old verify). The `// 0` fallbacks removed were actively harmful. Nothing useful lost; `web.enabled=false` left alone deliberately.
22. **Split brains? (Q10)** — Two live ones, both pre-existing, both now documented: (1) memory ceilings defined in unit config vs thresholds in the collector — FIXED for the memory flags (runtime-derived), but userSlice (40G vs slice MemoryHigh=56G) and GPUActive (60G) still transcribe instead of derive; (2) two alert pipelines (Gatus + SigNoz) with overlapping rules (disk, CPU, service-down in both) and — until this session — two different voices in one Discord channel; voices now aligned, overlap policy still undecided (queue).
23. **Tests? (Q11)** — Weak, and this arc added none: the provisioner is the most consequential shell logic in the repo and its idempotency is proven only by two live runs. The planned VM test (run provisioner twice → identical rule set) exists as a queue item; it should be near the top. The pat-label mismatch was EXACTLY the class a 5-line test would have caught.

## e) WHAT WE SHOULD IMPROVE (systemic)

24. **Verify the verifier** (meta-theme): pre-deploy-check validates Gatus pats syntactically but not semantically (labels); the gatus meta-check has a silent-zero fallback; SigNoz rule queries have no metric-presence validation at all. Three blind spots, three queue items.
25. **Provisioner-converge pattern** is now encoded (code + AGENTS.md) — next provisioner starts from it.
26. **Commit hygiene:** ask the user (again) whether sessions should self-commit; the daemon's bundling makes `git log` lies (see g.2).

## f) NEXT (priority order)

1. Watch first real Discord alert render (b.11 checklist)
2. Gatus meta-check auth fix (d.15) — P1, false-green risk
3. Unlabeled-value-pat lint (e.24) — pre-commit candidate
4. Provisioner idempotency VM test (d.23)
5. SigNoz dashboards v2 rewrite OR delete the ghost (d.19)
6. Root-disk relief (~90% standing crisis)
7. Prior queue (monitor365 backup, btrfs items, overlap policy, …)

## g) QUESTIONS (still open, cannot resolve myself)

1. **Commit rule (asked 3× now):** should I commit my own work after green deploy+verify? The daemon committed mid-session and bundled unrelated changes (`66e78231`) — history is getting muddy.
2. **Discord format:** minimal `🔴/🟡 Name` + `description (current: value) — link` / `🟢 Name` + "Condition recovered." — keep, or adjust after you see the first real one?
3. **Known-failed units:** per-unit alerts will hold truthful firings for persistent failures (monitor365/browser-history family). Silence until fixed, or let them fire as honest signal?
4. **SigNoz dashboards ghost (d.19):** rewrite the five dashboards in v2 schema, or delete the provisioning loop until someone needs them?

---

**Session verdict:** the task ("make Discord alerts stop being garbage") is functionally complete and live-verified end to end except the final visual proof of one real message. Honest costs this session: one repeated documented typo, one shipped-then-caught pat bug, one premature report, one broken audit script. Found more than the brief asked (two latent pat bugs, one ghost system, one false-green meta-check) — the codebase's monitoring layer is measurably more honest than when the session started.
