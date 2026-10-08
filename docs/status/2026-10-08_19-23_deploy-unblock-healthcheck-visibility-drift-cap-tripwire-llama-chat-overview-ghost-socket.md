# Deploy unblock: eval gate, health-check visibility, drift tripwire, llama-chat model, overview ghost-socket

**Authoring time:** 2026-10-08 19:23 CEST
**Session scope:** diagnose + fix the 17:30 `nh os switch` exit-4 and the 18:0x `nix run .#deploy` abort (pre-deploy §1 flake-check failure); root-cause every failing unit it exposed; land repo fixes; redeploy; verify live.
**Live at authoring:** profile **anchored** at `system-847` (`2ij7p4n1…`, 18:30). Failed units: only `service-health-check.service` (correct reporter: forgejo gate + transient units). Drift tripwire green on its 19:02 tick. A parallel session committed llama-chat gatus-coverage work at 18:47+ (it also finalized the model `.part` rename at 18:15 — attribution by timing).

---

## TL;DR — the four roots and their state

| # | Root cause | Evidence | Fix | State |
|---|---|---|---|---|
| 1 | **Eval blocker**: `inboxclean.nix:202` references `config.services.llama-chat.*`; `tests/test-inboxclean-paperless.nix` didn't co-import the module → `checks.x86_64-linux.inboxclean-paperless` failed `nix flake check --no-build` → deploy §1 blocked ALL deploys | deploy log error; repo doctrine = consumer co-imports (2026-09-15 enumeration) | llama-chat co-import added to the test (commit `6bb3897a`) | **DONE, deployed, verified** (`nix flake check --no-build --keep-going`: all checks passed; deploy §1 green) |
| 2 | **service-health-check silent death** (the exit-4 unit): `writeShellApplication` errexit + bare `check_service` call sites → first failing static check (forgejo, gated down) killed the script before ANY output. 6s runtime = exactly 3×2s retries | journal: zero script output across 17:30/17:47/18:01/18:17 ticks; `set -e` semantics; 2026-10-07 report §d4 predicted it | `check_service X \|\| true` at call sites (d4 fix) | **DONE, deployed, verified live**: 18:35 tick prints `FAILED: forgejo / browser-history-agent.service (failed)` into the journal |
| 3 | **bank-sync-rev-drift 40/40 false positives**: `harden{}`'s empty `CapabilityBoundingSet` strips CAP_SYS_PTRACE from root → `readlink /proc/<bank-sync-uid>/exe` = EACCES → NixOS script wrapper's implicit `set -e` killed the unit before any diagnostic echo. Running binary MATCHED all along (running argv0 == active-gen ExecStart == tree eval: `hd8hjz6a…`) | deployed unit file `CapabilityBoundingSet=` (empty); journal: no script output ever; ELF has no wrapper; nix-build-cleanup CAP_DAC_OVERRIDE precedent | `harden { CapabilityBoundingSet = "CAP_SYS_PTRACE"; }` + `readlink … \|\| true` | **DONE, deployed, verified live**: 19:02:45 tick logs `bank-sync-rev-drift: OK (hd8hjz6a…/bin/bank-sync)` — first green run since go-live |
| 4 | **overview 26h crash-loop via ghost socket**: `projects-management-automation.service` still carries stale `RuntimeDirectory=project-discovery` (predates the 2026-09-07 standalone-daemon flip). PMA's deploy-stop at Oct 7 16:28:36 flushed `/run/project-discovery/` → unlinked the live daemon's socket; PMA's 16:29:09 start recreated it EMPTY. Daemon process alive+`active` (sleeping futex, socket fds open) but unreachable; overview's ExecStartPre gate correctly refuses → ~65s crash-loop since | `/run/project-discovery/` empty, dir mtime 16:29; daemon `ActiveState=active` MainPID 3425730 alive (state S); journal timeline PMA stop 16:28:36 / start 16:29:09; both units declare the same RuntimeDirectory | **NOT LANDED** — I was mid-edit (interrupted): PMA wrapper needs `RuntimeDirectory = lib.mkForce [ ]` (line ~148 `mkMerge`); daemon needs an ExecStartPost `test -S` socket-existence start-contract; then one daemon restart (via the unit change riding the next deploy) recreates the socket and overview self-heals within ~70s | **NOT STARTED (fix authored in analysis only)** |

**Deploy outcome:** `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (18:21–18:30) — all pre-deploy gates green, switch clean, **profile anchored system-847**, post-deploy smoke 6 FAIL / rest PASS (triage below).

---

## a) FULLY DONE (this session, verified)

1. Eval unblock: llama-chat co-import in `tests/test-inboxclean-paperless.nix` — `nix flake check --no-build --keep-going` all-checks-passed; deployed and live (§1 gate passed in the 18:21 deploy run).
2. service-health-check d4 errexit fix (`scheduled-tasks.nix`) — live-verified: findings now journal-visible (18:35 tick). This also satisfies the 2026-10-07 report's unharvested §f.7 (errexit) and §f.8 (journal the FAILED list — achieved via the now-reachable `echo` + `StandardOutput=journal`; no separate `logger` needed).
3. bank-sync-rev-drift CAP_SYS_PTRACE + readlink-tolerance fix — live-verified green at 19:02:45.
4. Deploy anchored (system-847) — closes the un-anchored-profile state from the user's 17:30 paste.
5. Diagnosis (evidence-grade, cited above) of: overview ghost-socket chain, papdashboard auth regression, llama-chat model state, inboxclean-sync TEMPFAIL flapping, browser-history-agent warm-up race (self-healed: 18:37 run OK, cleared from failed list).
6. bank-sync sentinel go-live verification todo — the verifiable halves done: `/metrics` exports the gauges (`bank_sync_sync_sustained_failure 0`, `bank_sync_sca_approval_pending 1`); no gatus Bank-Sync alerts firing; drift tripwire green post-fix.

## b) PARTIALLY DONE

1. **llama-chat go-live**: model file is complete on disk (size exactly 23,424,536,704 B = HF Content-Length; finalized to the real filename 18:15 by the parallel session/owner; local `sha256sum` = `8d344a43…`), but the **unit is not started** (still skipped-state from the 17:30 activation; polkit denied my busctl StartUnit — needs one `sudo systemctl start llama-chat` or equivalent). gatus "llama.cpp Chat" alerts fire until then.
2. **Overview remediation**: root cause fully diagnosed; the two repo edits + daemon restart NOT yet made (see #4 above).
3. **Model hash provenance**: measured local sha256 `8d344a4336d8…` ≠ runbook's recorded `1c6a4813…` — the runbook value is the HF xet-bridge **ETag** misrecorded as sha256 (HF tree API exposes no content sha256 for xet files; ETags are chunk-hash based). Doc correction pending; exact-size + completed-download + future /health gatus check bound the corruption risk.
4. **Queue/doc hygiene for this session's fixes** (TODO rows, CHANGELOG, bank-sync.md tripwire note, llama-chat.md hash) — identified, not written.

## c) NOT STARTED

1. PMA `RuntimeDirectory = mkForce []` override (the overview root-cause fix).
2. project-discovery-daemon ExecStartPost socket-existence start-contract (+ the one-time daemon restart riding the next deploy).
3. papdashboard `/api/services` auth regression — repo-side row + upstream fix (see d/e).
4. Session CHANGELOG entry + TODO_LIST/docs/todo updates + runbook doc corrections (bank-sync.md, llama-chat.md, overview.md incident note).
5. Post-fix Overview smoke verification (needs #1–2 deployed).

## d) TOTALLY FUCKED UP (honest self-review)

1. **busctl unit-pattern probe misuse** → I concluded "overview service removed with Docker, zero units exist" and nearly rewrote the smoke battery to SKIP a live crash-looping service. The call `ListUnitsByPatterns 'asas' 1 "all" 1 "overview*"` returned 0 for a unit that provably exists — wrong arg encoding, unvalidated negative result (exactly the AGENTS "validate negative DB queries against a known positive" lesson). Caught only because `docs/services/overview.md` contradicted me. **Every busctl conclusion in this session was re-verified through /proc, unit files, or journal before acting — but the first pass was wrong.**
2. **Two wrong overview theories before the right one** ("docker residue" → "deliberately disabled" → ghost socket). Cost: ~4 tool rounds; mitigated by evidence-before-edit discipline (no repo edit landed on a wrong premise).
3. **Premature "verified complete" framing on the model file** — I ran sha256 late and only compared it at report time: it MISMATCHES the documented hash. Nothing shipped on that claim, but my in-session assertions outran my evidence.
4. **Drift diagnosis order**: the empty `CapabilityBoundingSet=` line was in my FIRST unit-file grep output and I skimmed past it for two hypothesis rounds (wrapper → systemctl-sandbox → caps).
5. My first flake-check leg in the 18:21 deploy ran with `--keep-going` (mine); the repo's pre-deploy §1 does NOT use keep-going for evals — a multi-failure eval still surfaces one-at-a-time there (improvement candidate, not my bug).

## e) WHAT WE SHOULD IMPROVE (structural, from this session)

1. **Eval-time guard for cross-module option references** — `inboxclean.nix` → `llama-chat` broke only in check-closures. A lint/eval check that imports EVERY service module in a minimal system individually would catch missing co-imports at `nix flake check`, not at deploy time.
2. **`harden{}` + root units that inspect other units need explicit caps** — CAP_SYS_PTRACE (this session) and CAP_DAC_OVERRIDE (nix-build-cleanup) are now two incidents of the same class; deserves a line in `docs/agents/systemd.md` harden guidance.
3. **Shared RuntimeDirectory is a silent kill-switch** — any unit declaring a name another unit's socket lives under can flush it on stop. Consider an eval-time assertion or audit forbidding duplicate RuntimeDirectory names across enabled units.
4. **Smoke battery false confidence**: `Overview FAIL` ran for 26h as "unreachable" while the real story was a deaf daemon; consider a check_local companion that reads the daemon unit's socket-existence (or the overview gate's specific error) instead of bare HTTP.
5. **Deploy-vs-health-check-timer coin flip**: every deploy has a ~1-in-15-min chance of exit-4 from a coincident health-check tick while forgejo is gated (chronic red). The report-don't-fail semantics row (owner-gated) is the structural exit; until then deploys should note the race window.
6. **gatus "Memory Pressure" alert fired while `/proc/pressure/memory` some≈0.06%** — the check's thresholds match the IO storm (~70% PSI) under a Memory name; likely monitoring the wrong PSI file or misnamed (unverified beyond the observation).

## f) NEXT — up to 50, impact-ordered

**Restore broken surfaces (highest):**
1. PMA `RuntimeDirectory = lib.mkForce []` (overview root cause; wrapper line ~148 mkMerge).
2. project-discovery-daemon `ExecStartPost = "+test -S /run/project-discovery/daemon.sock"` start-contract (also forces the healing daemon restart via deploy).
3. Deploy both → verify socket exists, overview green ≤70s, smoke `Overview` PASS.
4. Start llama-chat (`sudo systemctl start llama-chat`) → verify `:8850/v1/models` lists the alias; gatus "llama.cpp Chat" green.
5. papdashboard decision: roll back lock bump vs fix-forward upstream `/api/services` key gate (question #1).
6. Upstream papdashboard fix: restore 401-without-key on `/api/services` (currently 200 through `dash.home.lan` unauthenticated — verified).

**Verification & close-outs from this session:**
7. Re-run post-deploy-check after 1–3; expect FAILs reduced to known set (forgejo gate, fastflowlm, CV render baseline, InboxClean /health IO-cap).
8. Update `docs/services/bank-sync.md` tripwire section: CAP_SYS_PTRACE requirement + set -e narrative.
9. Correct `docs/services/llama-chat.md` + module header hash: `8d344a43…` measured; `1c6a4813…` was the ETag.
10. Add `docs/services/overview.md` incident note (ghost-socket chain, Oct 7 16:28).
11. Close `[blocked:deploy]` bank-sync sentinel row in TODO_LIST + docs/todo/services.md (drift green 19:02, gauges verified).
12. Queue papdashboard auth-regression row (upstream, blocked:push class).
13. CHANGELOG entry for: eval co-import fix, d4 health-check visibility, drift CAP_SYS_PTRACE fix, (pending) PMA RuntimeDirectory fix.
14. Harvest-note correction: 2026-10-07 02:43 report §f.7/f.8 were never harvested into TODO_LIST (gap) — now landed by this session; annotate per correction-claim rule.
15. Verify llama-chat soak-test warning (module header: health + one vision request + 10min idle) once started.

**Monitoring / stability follow-ups (observed, unowned):**
16. Attribute the ongoing IO storm (io PSI some ~70%; `iotop-c` was already running owner-side; /proc per-cgroup io.pressure method per AGENTS).
17. gatus "Memory Pressure" check: verify which PSI file it reads; fix name or source (f.6).
18. inboxclean-sync TEMPFAIL flapping under IO PSI (15:20/16:50/17:50 fails, OK between) — heals with pressure; watch, don't patch.
19. `bank_sync_sca_approval_pending = 1` — real pending bank SCA approval? Owner action or expected.
20. fastflowlm :52625 down (memory-guard sacrifice class under the storm) — confirm return when pressure drains.
21. Postgres `paperless` collation version mismatch warnings (2.42→2.44) — `ALTER DATABASE paperless REFRESH COLLATION VERSION` maintenance.
22. postgres collation warnings appeared twice in 10 min — check if an app reconnect-loops.
23. CV browser-render smoke baseline red (documented 2026-09-29 class) — still open upstream/parallel work.
24. dnsblockd TLS handshake errors from 192.168.1.62 (Mac) — benign-ish (DoH client mismatch?), worth one look.
25. gitea-runner-evo-x2 post-crash crash-loop row (docs/todo/services.md) — status after today's activity?

**Structural improvements (from e):**
26. Eval check: every service module imports cleanly in a minimal nixosSystem (co-import guard).
27. Audit: duplicate `RuntimeDirectory` names across enabled units (assertion).
28. `docs/agents/systemd.md`: "caps for root units that read other units' /proc" harden guidance row.
29. Pre-deploy §1: `--keep-going` on the flake-check eval leg to enumerate all eval failures in one pass.
30. post-deploy-check: Overview check should distinguish "gate failed (daemon)" from "port dead".
31. smoke/pre-deploy EXPECTED-SKIP classifier for condition-gated units (forgejo class — already queued pipeline.md; llama-chat now joins it whenever the model file is absent).
32. Port the smoke's CV_ENDPOINT_UP 401-classifier into pre-deploy §10 (queued item, reaffirmed by this session's cv/monitor365 warnings).
33. service-health-check: `check_user_service` is defined but never called (dead shell function — wire or drop).

**Model/AI stack:**
34. Confirm who/what finalizes downloads into the Jan model tree (question #2) — if manual, consider a tiny finalizer/watch path unit.
35. llama-chat page-in: first model load mmaps 23.4 GB under the IO storm — schedule the start when PSI allows (or accept one slow load).
36. After soak: revisit llama-chat `MemoryMax=32G` vs page-cache accounting under the memory-emergency-guard.

**Deploy pipeline hygiene:**
37. Document the deploy/health-check-timer race + recommended timing (deploy just after a tick) until report-don't-fail lands.
38. `systemd.services.service-health-check` unit change rides deploys — after d4, its restart mid-deploy re-runs it; confirm stc doesn't start inactive oneshots (it didn't at 18:30 — keep it that way).
39. Consider `SuccessExitStatus`/report-don't-fail decision for service-health-check (owner-gated row — question #3 adjacent).
40. Auto-commit attribution: my 3 fixes rode `6bb3897a` "heuristic" — per repo policy amend-worthy if the owner wants clean history before push.

**Small residue noticed (no action taken):**
41. `overview = "http-host-port"` key in otel-endpoint-audit shapes map — inert, verify on next registry pass.
42. `lib/ports.nix` overview/8083 stays (module live) — no change; DNS `overview` subdomain rides the documented dns-local migration.
43. `/tmp/model-sha256*.txt` artifacts — trash on next /tmp clean.
44. papdashboard-env sops template + ingest key verified still armed on `/api/ingest` (401 PASS) — only `/api/services` regressed.
45. The 17:30 deploy's `mandb.service` first-start line — benign.
46. `bank-sync-rev-drift` failed-state cleared by the 18:30 switch (stc reset) — if you want failed-state persistence semantics, that's systemd default, fine.
47. inboxclean-web `/cqrs/-/events/stream` 30s held SSE + `/health` 503 timeouts — same IO-cap class as #18.
48. `post-deploy-check.sh` null-byte warnings (lines 133/640) — cosmetic; strip binary reads with `tr -d '\0'`.
49. Two `system_fish-completions` python collision warnings in buildEnv — cosmetic.
50. flake.lock papdashboard bump commit `f12d5604` is the one carrying the auth regression — pin point for any rollback.

## g) Questions I cannot answer myself

1. **papdashboard auth regression — rollback or fix-forward?** `dash.home.lan/api/services` currently serves the services config unauthenticated (verified 200 from LAN). Rolling back lock input `papdashboard` (bump landed today in `f12d5604`) restores the gate but drops the alert-hub feature the parallel deploy intended. Fix-forward needs an upstream commit + your push (I don't push). Which way?
2. **Who finalized the model `.part` → final filename at 18:15** — you, or the 18:47 llama-chat session's tooling? If nothing automates Jan-tree finalization, future downloads will strand the same way (llama-chat skips silently until renamed).
3. **forgejo stays on service-health-check's critical list while the subvol-migration gate holds?** It exit-1s every ~15 min and gives every deploy a ~1-min exit-4 coin-flip window. Temporary exemption (until `.subvol-migrated` finalize) vs keep-as-designed-loud — this is the owner-gated report-don't-fail adjacent decision; the 2026-10-01 §g3 question never got an answer.

---

**Evidence index:** deploy log (user pastes, 17:30 + 18:0x); journal: service-health-check 17:30–18:35, bank-sync-rev-drift 19:02:45 OK, overview crash-loop + Oct 7 16:28 PMA/overview stop timeline, gatus llama/ Memory-Pressure alerts; live probes: busctl (failed units, unit states, MainPID), /proc (3425730 alive S-state; 501752 argv0), unit files (CapabilityBoundingSet=, RuntimeDirectory dup), HF HEAD (Content-Length exact match; xet ETag ≠ content sha256), local sha256 `8d344a43…`, /metrics gauges, /run/project-discovery empty; repo: commits `6bb3897a` (3 fixes), `f12d5604` (papdashboard bump), system profile 845/846/847.
