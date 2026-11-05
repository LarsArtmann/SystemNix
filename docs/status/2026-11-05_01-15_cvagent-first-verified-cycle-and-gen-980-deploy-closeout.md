# Status report — cvagent first-verified-cycle + gen-980 deploy closeout (lock-forensics session)

**2026-11-05 01:15 CET — single crush session on evo-x2; ran 2026-11-04 22:46 → 2026-11-05 ~01:2x.**

**Trigger:** the owner pasted their 23:59 (Nov-04) terminal output — `nix flake update cv && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` blocked by the deploy lock (then-holder PID 1001912, started 23:59 Nov-03) — with the instruction to wait for the lock and re-run.

**Scope of work:** SystemNix only — deploy-lock forensics, deploy-need determination, one deploy, cvagent unit first-cycle verification, queue close-outs, runbook/AGENTS corrections.

---

## Scope line — what this report VERIFIES vs does NOT verify

**Verified with fresh commands/artifacts this session:**

| Claim | Evidence |
| --- | --- |
| The pasted lock holder (PID 1001912, 23:59 Nov-03) was long dead; the lock had been re-acquired twice since (content PID 2975826 written 21:36:39, also gone); no deploy/switch processes at session start | `stat`/`cat` on `/tmp/.systemnix-deploy.lock`, `/proc` liveness tests, `pgrep -af 'bin/deploy\|nh os\|switch-to-configuration'` |
| The 21:36 attempt was a 3-second PSI-gate refusal (exit 12), NOT a mid-build death | tail of `/var/log/systemnix-deploys/2026-11-04_21-36-39.log` (`deploy exited code=12 … after 3s`) — a log dir I found only at 01:15 (see §d.4) |
| gen-979 (20:53) was the **21-13 session's deploy** (lock-wave rollback + eval gates + float ceremony; co-deployed boot.nix/buildcache/templ per its own report) | its report `docs/status/2026-11-04_21-13_lock-wave-rollback-eval-gates-and-deploy.md` + sudo journal 20:40:29 deploy-log creation + anchor `p10k64kf…` == `system-979-link` |
| The tree had REAL eval drift vs gen-979: pim-sync dormant module (+96), `configuration.nix` (+16), `flake/expected-locks.nix` (+1) landed after its build | `nix eval --raw …toplevel.drvPath` → `clv7zxl2…drv` vs `nix-store -q --deriver $(readlink /run/current-system)` → `cpirafhx…drv` — DIFFER; plus `git diff --stat 024794b75..HEAD` |
| The cvagent PATH fix was live since gen-979 | `/etc/systemd/system/cvagent.service` ExecStart = `anvh45…-cvagent-scan-mesh` (the exact script the 20:46 session built as proof); its PATH line carries cvagent + git-2.55.0 + coreutils-9.11 |
| **First verified cvagent unit cycle: GREEN** | script-internal-sudo `busctl … StartUnit ss "cvagent.service" "replace"` 23:08:35 → journal `done: scanned=6 failed=0 target=/home/lars/projects/CV` 23:09:50, `Result=success`, ExecMainStatus 0, "Deactivated successfully"; read models rebuilt `events=72` (the failure facts self-healed through replay — the 20-46 report's §f 6 leg) |
| Mesh artifacts landed, curated set preserved | `~/projects/CV/data/cv/lars_artmann-en-cvagent.patch.json` (10,736 bytes, 23:09) + 6 NEW generated `data/projects-v2/*.md` (cmdguard, code-to-cv-agent, go-aichat, go-cqrs-lite, monitor365, systemnix); hand-curated hornbach/rolls-royce/wolt/README intact; all untracked in the CV repo (PMA pending) |
| gen-980 deployed and anchored | deploy log `2026-11-04_23-11-34.log` (started 23:11:34, exited code=3 at 23:43:17 after 1903s — the exit 3 is the smoke-battery regression signal only); anchor triple-match `readlink /run/current-system` == `system-980-link` == `profiles/system` == `9bq24kk…fe13242` |
| The battery's "NEW failure: Gitea runner" was stale, not real | direct re-probe: ActiveState=active, SubState=running, Result=success, NRestarts=0; journal shows it picking up task 351 at 23:36 and the 5-min ensure timer converging at 23:41 (the check message itself names that timer) |
| cvagent keeps the fixed script in gen-980 | `/etc/systemd/system/cvagent.service` ExecStart unchanged post-switch; timer next elapse 2026-11-05 ~05:57 |
| A parallel session was deploying gen-981 WHILE this report was written — now identified as the **cvagent AI-enable wave** (their queued rows, appended 00:0x–00:5x: upstream `2b735e5→1484234` pushed with `ai.baseurl` + sk-drop + 300s timeout, sops `cvagent_ai_api_key` + `cvagent-env` template, module aiEnable/aiModel/aiBaseUrl (glm-5.3-flash @ z.ai), 24 meta-importance repos, TimeoutStartSec 20min; probe-1 LIVE: z.ai 90s timeout → rule-based fallback 18 facts; probe-2 at 300s rides gen-981) | `/var/log/systemnix-deploys/2026-11-05_00-59-15.log` (94 KB, tail "> Activating configuration" at 01:15): cvagent `16a656f4 → 14842343`, ADDED `cvagent-config.yaml` + `cvagent-env`, quotaboard 0.1.0→0.1.1; commit `bb2a97cf3` 01:00:36 "float: register cvagent quotaboard (auto-proof rc=0)"; ListJobs showed a `cvagent.service start` job RUNNING at 01:15; seven fast-failed attempts 00:49–00:58 precede it |
| Runbook trigger line was false and is now fixed | polkit DENIED the documented unprivileged busctl line live ("requires interactive authentication"); without the `ss` signature busctl dies `Unknown signature type c` — both recorded in `docs/services/cvagent.md:14` with the working script-internal-sudo line |
| Both deploy-row surfaces closed with evidence, no drift | `TODO_LIST.md:1889` + `docs/todo/services.md:765` ticked with identical DONE suffix; `git diff` = 1 line per file. Convergent-discovery note: the parallel AI-wave session's queued battery line independently specifies the same `sudo -n busctl … StartUnit ss` form (polkit + ss) that this session discovered live and fixed into the runbook + AGENTS.md |
| AGENTS.md memory updated in-session | busctl-mutation clause (polkit + explicit `ss`) in the agent-shell bullet; deploy-log FIRST STOP + drv-equality pre-check clause in the anchor-discipline bullet |

**NOT verified here (and why):**

- **The other 10 battery FAILs + 2 STORM-SUSPECTs** (llama-embeddings 183% CPU, node-exporter 864 lines/min journal rate, 2 downgraded checks) — not re-probed; the battery itself ran under io-PSI storm (its own storm-mode downgrade was active) and re-running the battery in the current load (~140+) would add storm to storm. Queued as a calm-window [watch] row.
- **gen-981** — the 00:59 parallel deploy was still activating at report time; its outcome belongs to that session's report.
- **Why the 21-13 report evaded my 22:46 pre-read** — its birth/ctime/mtime are all 21:14:57 (predates my `ls -t docs/status/ | head -8` at 22:46), yet it did not appear in that listing. The probe's ordering is suspect, not the file. Recorded as an instrument failure (§d.2), not chased further.
- **The cvagent pin-lift story in the 00:5x wave** — the wave's PURPOSE is now clear (AI-enable, per their queued rows), but whether `14842343` also carries the SEGV-class runtime fix (nil-guard on `ChatstoreSessions.HealthCheck` + rehydration that completes against the existing store — the pin's stated LIFT condition) is NOT stated in their row; their battery's `scanned=24 failed=0` would prove the boot path incidentally. Narrowed question left in §g.1.
- **system-health metric semantics for oneshot failure (20-46 §f 5)** — never probed; now queued properly (harvest ledger).
- **PMA auto-commit of the CV artifacts** — async, unobserved (§b.3).
- **darwin eval** — `nix flake check --all-systems` never run this session.
- **`tasks.db.readmodel.db.fold-lock`** — noticed as a 0-byte entry in the `024794b75..HEAD` diff range; not researched (owner directive: this session reports, doesn't research) — queued for identification.

---

## Context: what triggered this session

The owner's pasted error was ~23 hours stale: their 23:59 chain hit a lock held by a deploy that had since died, and two more deploy attempts (21:04 TTY re-run, 21:36 PSI-refused) plus a full session (21-13: rollback, eval gates, gen-979) had happened in between. The literal instruction ("wait for it to finish and re-run") would have been executed blind; the session instead re-derived state, proved a deploy was genuinely needed (drv drift), deployed, and completed the queued deploy row's real scope — the cvagent unit's first verified cycle — which gen-979's own deployer had left undone.

---

## a) FULLY DONE

| Work | Evidence | Scope |
| --- | --- | --- |
| Lock/attempt forensics → the pasted error declared stale with holder genealogy | stat + /proc liveness + deploy logs 21:04/21:36 | live system + `/var/log/systemnix-deploys/` |
| Deploy-need decided by drv-equality proof, not instruction-following | `clv7zxl2` (tree) vs `cpirafhx` (live deriver) — differ; drift files identified | nix eval + git |
| gen-980 deployed, switched, anchored by generation NUMBER | deploy log 23:11→23:43; triple anchor match | live system |
| **First verified cvagent unit cycle** (the queued row's core scope) | journal `done: scanned=6 failed=0`, Result=success; read models rebuilt events=72 | live system |
| Mesh artifacts + curated-page preservation verified | patch.json 10.7 KB + 6 generated pages; curated set intact | `~/projects/CV` |
| Smoke exit-3 triaged: Gitea-runner FAIL re-probed green (stale-smoke class, third live instance) | busctl active/running/success/NRestarts=0 + ensure-timer journal | live system |
| Runbook agent-trigger line corrected (polkit denial + `ss` signature) | `docs/services/cvagent.md:14` rewritten with working line | docs |
| Both deploy-row surfaces closed with identical evidence (no drift) | TODO_LIST.md:1889 + services.md:765 ticked + DONE suffix | queue surfaces |
| AGENTS.md: busctl-mutation clause + deploy-log FIRST STOP + drv-equality pre-check | 2 edits to the agent-shell and anchor-discipline bullets | AGENTS.md |
| 21-13 report reconciled (gen-979 attribution absorbed, not duplicated) | §scope table rows 3–4 | docs |

## b) PARTIALLY DONE

1. **Post-deploy battery verification.** The gen-980 battery ran green where it mattered (157 PASS incl. §19 storage-history + §20 CRM OIDC + §24 unit shapes) but finished exit 3 under storm: 11 FAILs + 2 STORM-SUSPECTs. One FAIL (Gitea runner) is re-probe-cleared; the rest are unproven storm artifacts pending a calm-window battery run (or automatic re-baseline by the next green battery — possibly already gen-981's). Queued [watch].
2. **cvagent §f 5 leg** (system-health `extraMonitoredServices` semantics on a ONESHOT failure) — the 20-46 report's RIDES-DEPLOY leg that its closed deploy row never carried; queued [ready] into monitoring.
3. **§f 7 ship leg** (PMA auto-commit → `cv-server-content-sync` ships the generated pages) — artifacts sit untracked in `~/projects/CV`; async and unobserved. Queued [watch].

## c) NOT STARTED

| Planned | Why not started | Priority |
| --- | --- | --- |
| Calm-window battery re-run (§b.1) | box at load ~140 during the whole session window; queued | Medium (check-first whether gen-981 re-baselined) |
| `media-atlas.service`, `forgejo-github-sync.service`, `home-lars-tmp.mount` triage | owned by the 21-13 session's §c — already on their surfaces | High (unchanged) |
| Upstream got-hash bake wave (23 repos) + re-floating ~28 healthy inputs | 21-13 §a.2/§b.1 — push-gated / ceremony-gated | unchanged |
| `nix run .#pre-reboot-check` before the next planned reboot | 21-13 §c.7 — reboot not planned tonight | unchanged |
| `tasks.db.readmodel.db.fold-lock` identification | noticed only in a diff range; research was out of session scope | Low-Medium (queued) |
| gen-981 verification | the 00:59 session's obligation, still activating at report time | theirs |

## d) TOTALLY FUCKED UP

1. **The evening's deploy chain ran piecemeal across ≥5 actors with the row open the whole time.** 20:40 deploy (21-13 session → gen-979), 21:04 TTY re-run, 21:36 PSI-refused, 22:50 + 22:52 attempts, this session's 23:11 deploy (gen-980), then 00:49–00:59 a fresh parallel wave (cvagent float + gen-981) — and the queued deploy row stayed `[ ]` open through ALL of it until this session closed it at ~23:5x. The owner's pasted error was ~23 h stale; nobody closed the row they executed; each later session re-derived the same state from scratch. Cost here: ~30 min of forensics before the first action — and the gen-981 wave started WHILE gen-980's closeout was being written.
2. **My pre-read was a broken instrument and I trusted it.** `ls -t docs/status/ | head -8` at 22:46 did NOT surface the 21-13 report although the file existed since 21:14:57 (birth = ctime = mtime, verified at 01:15). I concluded "no live executor signal" from an ordering behavior I never validated — the exact stale-signal failure AGENTS.md warns about, in the tool that was supposed to prevent it. Only a lucky pull of the deploy-log dir at report time surfaced the parallel work. Every conclusion I drew from "what I saw in docs/status/" inherits this.
3. **I stated a false causal story before checking the artifact that would falsify it.** "The 21:36 deploy died mid-build" was my hypothesis, delivered to the owner as fact — the deploy log (which existed the whole evening, 30-day retention) showed a 3-second gate refusal. Artifact-before-attribution, again.
4. **I piped the 1903-second deploy through `| tail -40` in a background job**, discarding the full battery output I then needed for triage; re-derived the Gitea-runner check from the script + live probes instead. The log file preserved everything — but I didn't know the log dir existed until 01:15 (see §e.2).
5. **Command churn, all self-inflicted, zero damage:** fish `end` in a bash `if`; a sed `/`-delimiter collision with slashed DONE text; a grep anchor missing the closing quote in `"replace"\`;`; a busctl call without the `ss` signature (executing the runbook's own untested line verbatim — which is also how the runbook bug survived: it was written 20:46 and never executed until polkit stopped me at 23:0x).

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Concrete fix |
| --- | --- | --- |
| Deploy executors leave rows open; later sessions re-derive | 3+ sessions, ~23 h of stale errors, duplicated forensics | rule: the session that lands a deploy closes its row in the same session with gen + anchor + battery verdict (CONTRIBUTING candidate) |
| The pre-read probe (`ls -t docs/status/`) is unvalidated | false "no parallel session" signal — the exact trap the pre-read exists to catch | harden: `ls -lt` + spot-`stat` birth time, or `find docs/status -newermt`; HARVESTED-NOW (pipeline) |
| Deploy-attempt trail existed but is undiscoverable | I re-derived state for 2 h without the one artifact holding the answers | FIXED on sight: AGENTS.md anchor-discipline bullet now names `/var/log/systemnix-deploys/` as FIRST STOP |
| Storm-window deploys poison the exit-3 baseline | next deploy inherits a regression signal that is really weather | the baseline auto-clears on the next green battery; calm-window re-run queued [watch], check-first |
| No cheap "is a deploy even needed" gate before re-running | blind re-runs (the pasted instruction) vs proven drift — both happened tonight, decided by one drv-equality command | FIXED on sight: drv-equality clause added to AGENTS.md next to the anchor discipline |
| Runbook lines get written but never executed (polkit/ss bug shipped in the "fix" report) | the 20-46 session's fix for the runbook was itself unverified — the manual-vs-live class again | the fixed line now records BOTH failure modes it hit; keep "executed ≠ documented" discipline |
| Background jobs lose output when piped through `tail` | full 1903 s battery output lost | run background jobs with full output to a file; read slices on demand |

## f) Things to get done next (this session's yield; the standing queue — 20-46 §f, 21-13 §c, upstream.md — remains authoritative and is NOT re-listed here)

| # | Task | Impact | Effort | Disposition |
| --- | --- | --- | --- | --- |
| 1 | Confirm `14842343` also carries the SEGV-class runtime fix (nil-guard on `ChatstoreSessions.HealthCheck` + boot-rehydration completing against the existing store) — the AI wave moved the rev for AI reasons; the pin's LIFT condition was runtime, and the SIGSEGV trap re-arms at the next boot rehydration if the fix isn't really in (their `scanned=24 failed=0` battery leg would prove the boot path incidentally) | Critical | S | that session's report must own it (see §g.1) |
| 2 | Calm-window post-deploy battery re-run — clear the 23:43 exit-3 baseline; re-proof for llama-embeddings CPU, node-exporter journal rate, 2 STORM-SUSPECTs; CHECK FIRST whether gen-981's battery already re-baselined | High | S | HARVESTED-NOW [watch] pipeline.md |
| 3 | Probe system-health `extraMonitoredServices` oneshot-failure semantics (the closed row's orphaned §f 5 leg) | Medium | S | HARVESTED-NOW [ready] TODO_LIST + monitoring.md |
| 4 | Verify the PMA ship leg: CV artifacts (patch.json + 6 pages) must leave untracked state via PMA auto-commit; flag if still untracked after its next pass | High | S | HARVESTED-NOW [watch] services.md |
| 5 | Harden the status-report pre-read instrument (the `ls -t` false negative) | High | S | HARVESTED-NOW [ready] TODO_LIST + pipeline.md |
| 6 | Identify `tasks.db.readmodel.db.fold-lock` (git log the file; track-intentionally vs trash+ignore) | Low-Med | S | HARVESTED-NOW [ready] services.md |
| 7 | Rule: deploy executor closes the row same-session (gen + anchor + battery verdict) | Medium | S | ROADMAP (process change; CONTRIBUTING is the home) |
| 8 | Fold "deploy attempt trail = `/var/log/systemnix-deploys/`" + drv-equality pre-check into docs/CONTRIBUTING.md's deploy section (AGENTS.md now carries it; CONTRIBUTING should mirror) | Low | S | ROADMAP |
| 9 | gen-981 closeout (parallel session): anchor check, cvagent-config/env smoke, battery verdict | High | — | theirs, in flight |
| 10 | Standing queue unchanged: monitor365 SECCOMP triage (20-46 §f 13), media-atlas / forgejo-github-sync / home-lars-tmp (21-13 §c), upstream bake wave, pre-reboot-check, 05:53 timer collision check (20-46 §f 46) | — | — | QUEUED, not re-harvested |

### Self-harvest ledger (report-authoring obligation)

- **Harvested NOW:** §f 2 → `docs/todo/pipeline.md` ([watch]); §f 3 → `TODO_LIST.md` + `docs/todo/monitoring.md` ([ready]); §f 4 → `docs/todo/services.md` ([watch]); §f 5 → `TODO_LIST.md` + `docs/todo/pipeline.md` ([ready]); §f 6 → `docs/todo/services.md` ([ready]).
- **Deliberately NOT harvested:** §f 1 (the in-flight session's own obligation — its report is the surface); §f 7/8 (process/doc changes → ROADMAP per the 20-46 §f 47/48 routing precedent); §f 9 (theirs); §f 10 (already queued with Sources — re-adding would double-row).
- **Fixed on sight instead of queued:** the runbook trigger line (§a), the two AGENTS.md clauses (§e rows 3 and 5).

## g) Questions I cannot answer myself

1. **The 00:49–01:15 parallel wave** (AI-enable: upstream `2b735e5→1484234` pushed, sops key + env template, 24 repos, gen-981 activating as I wrote): did `14842343` also land the SEGV-class runtime fix (nil-guard on `ChatstoreSessions.HealthCheck` + rehydration completing against the existing store — the pin's stated LIFT condition), or is the AI wave running on top of the still-open SIGSEGV rehydration risk? Their `done: scanned=24 failed=0` battery leg would incidentally prove the boot path — but if that leg is green, nobody has NAMED whether the nil-guard is in or the pin condition was silently superseded.
2. **Do you want the storm-degraded exit-3 battery baseline cleared by a dedicated calm-window battery re-run, or is "the next green battery re-baselines it" acceptable?** (If the latter, I'll close the queued [watch] row as covered the next time any deploy battery runs green.)
3. **`tasks.db.readmodel.db.fold-lock` — do you recognize it?** It appears in tonight's daemon-commit range as a 0-byte diff entry at repo root. If it's a runtime lock artifact (pim-sync wave? PMA read model?), it should probably be untracked + ignored; if it's intentional, say so and I'll close the row with that.

---

*Then wait for instructions.*
