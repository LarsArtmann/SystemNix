# Status Report — deploy watch: the converger handoff in flight

**Session window:** 2026-10-25 ~07:52–13:58 CET (fourth report of one continuous session; covers everything after the 12:52 report)
**Report written:** 2026-10-25 13:58 · **HEAD:** auto-commit daemon series
**Trigger:** owner answered the 12:52 report's questions (deploy NOW · "I am deploying already" · drive-paperless LATER) and is running the production deploy personally. This report covers the deploy-watch arc.

> **Format override (flagged per skill spec):** `.md` demanded by owner prompt; HTML-canonical skill overridden one-off, not propagated.

---

## TL;DR

The deploy is **in flight but not landed**: ~35 minutes of watch polls show NO generation change (newest `system-943-link`), NO `current-system` flip (still `…20261015.fe13242`), while three signals prove a switch attempt is churning: the provision unit **transiently registered at 13:45:57** (one poll cycle, then gone — units get loaded into the manager during a switch attempt), builders active at 13:46 (3) and 13:55–56 (1) — an iterate/fail/rebuild cadence, and an unexplained **discordsync restart cycle at 13:23:21→13:24:23** (stop → exit 69 → start; the known drain class) that happened WITHOUT any profile change. The daemon is currently healthy (200s on `/healthz` + `/metrics`). My post-deploy ritual is staged and ready; the one thing I cannot see is the owner's terminal.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | **Question capture + scope decisions locked**: deploy now · float ownership = me · drive-paperless adoption = LATER (queued row already in place from the 12:52 arc — reconfirmed, no new work) | interactive answers 13:0x |
| a2 | **Watch infrastructure live** (verified probes only): 45s-cycle poll of newest-generation-by-NUMBER (`sort -V`, never mtime — anchor doctrine), `current-system` readlink, provision-unit presence via `busctl ListUnitsByPattern`, builder-process census; ~35 min of evidence accumulated | background shell 0A7 transcript |
| a3 | **Current-state baseline pinned for the post-deploy diff**: gen 943 / old current-system / daemon healthy (200s `/healthz`+`/metrics` at 13:57, serving the owner's browser 192.168.1.150) | live probes 13:57–13:58 |
| a4 | **Two pre-report fixes landed in the previous turn** (recorded in 12:52 §a8, listed here only to bound this report's scope): provisioner in `extraMonitoredServices`; post-deploy leg's dead PLACEHOLDER branch → "has not converged" classification | discordsync.nix + scripts/post-deploy-check.sh |

## b) PARTIALLY DONE

| # | Item | Works | Missing | Blocker |
| - | ---- | ----- | ------- | ------- |
| b1 | **The deploy (owner-driven)** | Switch attempt evidence: transient provision-unit registration 13:45:57; builders churning 13:46 + 13:55 | The switch has NOT committed: no new generation, no `current-system` flip, provision unit absent from the live unit list at every poll except the transient | Owner's terminal state — invisible to me (§g Q1) |
| b2 | **Post-deploy ritual (staged, ready)** | Exact steps prepared: provision journal (`minted`/`converged`), verify journal (`Immich API key verified against http://127.0.0.1:2283`), daemon env contains both files, `/lookup` E2E found/not-found/asset-link, anchor check (`readlink /run/current-system` == newest `system-N-link`), SigNoz/Gatus no-regression sweep | Runs only after the switch lands | b1 |
| b3 | **Carried debts (owner-assigned, unexecuted)**: float procedure (Q1 answer "run float"), phantom-check mystery session (Q3 answer "root-cause") | Queued with repro pointers | Sessions not yet spent | This arc's budget went to the watch |

## c) NOT STARTED

| # | Item | Why | Wanted? |
| - | ---- | --- | ------- |
| c1 | `--keep-going` failure enumeration (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going`) IF the owner's terminal shows a build/FOD wall — the AGENTS "one pass enumerates ALL root failures" rule exists precisely for this | Concurrent with the owner's own deploy it could collide on build locks; needs their go | Conditional on Q1's answer |
| c2 | Float procedure + full `nix flake check` (validates the provisioner's deploy-restart-audit admission + shape test in the real closure) | Sequenced behind the deploy settling | Yes (pre-assigned) |
| c3 | Mystery root-cause session | Pre-assigned, queued | Yes |
| c4 | drive-paperless converger adoption | Owner chose "later, as queued" | After its Drive go-live |
| c5 | CHANGELOG entries (converger + retirement) | Rides the landed deploy review | Optional |

## d) TOTALLY FUCKED UP (radical honesty — this thin arc's failures)

| # | What | Severity | Lesson |
| - | ---- | -------- | ------ |
| d1 | **I never warned the owner that their deploy would eval the SAME floated-locks audit gate that blocked every one of MY flake evals this session.** The gate threw at flake instantiation for me; `nix run .#deploy` evals the same flake. If their deploy is stalled on exactly that throw, I watched for 35 minutes and said nothing — the risk was KNOWABLE from my own session evidence | Medium (their time; anticipatable) | When a shared-surface gate blocks MY work, every consumer of that surface (including the owner's own commands) inherits the blocker — warn proactively, name the exact error text to look for |
| d2 | **The transient prov=1 at 13:45:57 was only analyzed post-hoc** from the finished poll dump — live, I kept polling instead of immediately investigating the one anomalous sample (which is the single most informative observation of the whole watch) | Low-Medium (the evidence survived in the transcript; a live drill-down could have resolved the switch state 10 minutes earlier) | Anomalies in watch loops interrupt the loop; polls are for confirming, not discovering |
| d3 | **Poll output noise**: `pgrep -cf` emitted stray `0` lines interleaved into the transcript (mvdan/sh builtin quirk + my `|| echo 0` doubling) — cosmetic, but it degraded my own evidence stream | Low | Test watch-loop one cycle before backgrounding |
| d4 | **35 minutes of 45s-cycle watching produced ~47 samples of an unchanged state** — a completion-signal design (owner ping, or a single slow loop) would have cost the same coverage for a fraction of the noise | Low | Watch loops need a defined "done" predicate or a human callback |
| d5 | **Typed `systemctl is-failed` got guard-blocked mid-check** (13:5x) — the probe-set substitution (busctl) is documented and I still typed the banned form reflexively | Low | Use the verified probe set first, every time |

## e) WHAT WE SHOULD IMPROVE

1. **Deploy-watch as a first-class pattern**: poll loop + done-predicate + anomaly-interrupt + a staged post-ritual checklist (this arc improvised all four). Candidate for a small `scripts/deploy-watch.sh` or a CONTRIBUTING snippet.
2. **Shared-gate awareness**: when an eval gate (locks, FOD, audits) blocks agent evals, the SAME gate will hit the owner's own deploy/build commands — every such block should trigger a proactive warning to the operator with the exact error signature.
3. **DiscordSync stop-path exit 69**: the 13:23 stop recorded `status=69/UNAVAILABLE` on the way down (drain/flush class; the 2026-09-20 SIGKILL family). Healthy now, but the stop-path exit code keeps showing up in deploys — worth a look upstream someday (queued Tier-3 adjacent).
4. **`current-system`-vs-`system-N-link` semantics**: my watch tracked BOTH (correct per the 2026-10-23 anchor doctrine — mid-flight they legitimately diverge); the transient unit registration adds a THIRD mid-flight signal. Fold all three into the deploy-watch pattern (f1).
5. **The converger's first real run is still pending** — everything about it is sandbox-verified; the production INSERT + verify-loop closure happens at the switch. Until then, "verified" for this feature has an asterisk (isolated-only), and that asterisk should retire at f2.

## f) Up to 50 things we should get done next — session-scoped, ranked

> Honesty note: **14 items** are genuinely derivable from this arc; the 50-cap would be filler. Full-project pareto = separate explicitly-requested task.

| # | Task | Impact | Effort | Category | Harvest status |
| - | ---- | ------ | ------ | -------- | -------------- |
| f1 | Land the deploy (owner terminal pending) → run the staged ritual: provision + verify journals, `/lookup` E2E, anchor check, SigNoz sweep | Critical | S | Verification | HARVESTED — `services.md:112` deploy-only row |
| f2 | Float procedure (owner-assigned) → full `nix flake check` (provisioner audit admission + shape test in real closure) | High | L | Infrastructure | Queued (b3) |
| f3 | Mystery root-cause session (owner-assigned) | Medium | M-L | Bug (tooling) | Queued (b3) |
| f4 | IF deploy is walled on build/FOD failures: `--keep-going` toplevel enumeration, fix all in one pass | Critical (conditional) | M | Bug | HARVESTED — new row below (conditional on Q1) |
| f5 | `deploy-watch.sh`: poll + done-predicate + anomaly-interrupt + staged ritual checklist | Medium | M | Quality | HARVESTED — new row below |
| f6 | Shared-gate proactive warning habit (locks/FOD/audits block the owner's commands too) | Medium | S | Process | HARVESTED — new row below |
| f7 | drive-paperless converger adoption (owner: later) | Medium | M | Feature | Queued — `services.md` row |
| f8 | Upstream Tier-3 batch (badge wording, WARN-on-auth-fail, tag carry, module options, healthCheck URL) | High (UX/obs) | M | Bug/Feature | Queued — `services.md:113` |
| f9 | DiscordSync stop-path exit 69 look (13:23 evidence; the SIGKILL family keeps resurfacing) | Low | M | Bug | HARVESTED — new row below |
| f10 | CHANGELOG entries: converger + retirement + deploy outcome | Low | S | Documentation | Deliberately NOT harvested (c5 — rides the landed review) |
| f11 | `nix develop -c shellcheck scripts/post-deploy-check.sh` (full-script lint; module scripts already covered by their build gates) | Low | S | Quality | HARVESTED — existing 10:38 row |
| f12 | immich.md unit-name trap note (`immich-server.service`, not `immich.service`) | Low | S | Documentation | Deliberately NOT harvested (file shared with another session's scope) |
| f13 | Re-run isolated harness post-float (revs live-read; expect green, prove it) | Low | S | Verification | Deliberately NOT harvested (rides f2) |
| f14 | Daily-timer RandomizedDelaySec collision-matrix audit (verify=1h, provision=6h, immich=10m, bank-sync…) | Low | M | Quality | Deliberately NOT harvested (beyond arc scope; noted) |

## g) Questions I can NOT figure out myself

Presented interactively after this report; recorded here for the file:

1. **Your terminal**: what does the deploy show RIGHT NOW — the lock-audit throw, a FOD hash failure, an activation error, or still building? (Your terminal is the one surface I cannot see; the system-side signals say "attempt churning, not landed".)
2. **Should I run the `--keep-going` toplevel enumeration myself** (one pass lists ALL root failures) or is your deploy about to succeed and make it moot? (Concurrent builds could collide — I won't start it without your go.)
3. **Keep watching or stand down**: should I re-arm the background poll and auto-run the staged ritual when the switch lands, or do you ping me when it's done?

---

## Evidence appendix

```bash
date '+%Y-%m-%d %H:%M:%S %Z'                    # 2026-10-25 13:57:51 CET
ls /nix/var/nix/profiles/ | grep '^system-' | sort -V | tail -1   # system-943-link (unchanged through ~47 polls)
readlink /run/current-system                    # …nixos-system-evo-x2-26.11.20261015.fe13242 (unchanged)
busctl … ListUnitsByPattern sss 0 discordsync-immich-key          # transient hit 13:45:57, absent otherwise
journalctl -u discordsync --since 10:00 | grep -E 'Started|Stopped|Failed'
# 13:23:21 Stopping … / 13:23:31 exit 69 … / 13:24:23 Started (healthy 200s since)
```
