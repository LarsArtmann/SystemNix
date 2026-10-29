# Status Report — crush 0.99.0 rollout: EXECUTED (deploy 1 landed; deploy 2 storm-gated), full plan task closure

**Session window:** 2026-10-29 ~19:35 – 22:3x CET — executor session of `docs/planning/2026-10-29_18-42_SUPERB-crush-0990-rollout-finish-and-hardening.md`
**Trigger:** owner directive "GET SHIT DONE — the WHOLE TODO LIST" (full execution mode)
**Final state at writing:** evo-x2 on gen-962 running **crush 0.99.0** (anchor-verified, glm-5.3-flash xhigh parity, llamacpp discovery working); ALL 24 plan tasks executed or closed-with-attribution; hooks + telemetry hardening committed (crush-config master 0054687, SystemNix through 90b17f512) but **NOT yet deployed** — the second deploy is gated on a real IO storm (flm-real crash-loop, the standing owner [decision] row).

---

## 1. What landed, in order

### Deploy 1 — the float wave (gen-962, 19:41–19:52)

Executed under `DEPLOY_FORCE_PRESSURE=1` with the phantom-PSI signature verified first (root PSI 78%, disks 1–6% busy, system.slice 1.9% — the ghostty CQ-waiter class; the memory gate passed clean at 0.00%). Battery: **164 PASS / 3 FAIL / 14 WARN**; anchor green (`readlink /run/current-system` == system-962 by NUMBER); toplevel delta +38 MiB.

The 3 FAILs, all triaged NOT-regressions (each re-probed, not assumed):
- **gitea-runner** — inactive with no journal since 10-28 (carried since the 02:3x smoke; the 18:56 report §f.8 row already owns it).
- **tq-agent-pool** — `maintenance-entry-gate` REFUSED to start the pool: "IO PSI some avg10=72.05% (>= 30% band)" — the pool protecting itself from the freeze class. Self-heals when the storm drains.
- **§18 journal rate** — crm-server (18k lines/8min) and cv-server were deploy-restart bursts (settled to 9 and 163 lines/2min on re-probe); node-exporter's 500/min is the CHRONIC connection-reset spam — **156,344 resets between 12:00–18:00, i.e. hours BEFORE this deploy** (evidence appended to its monitoring.md row).

### Core verification (T7)

- `crush --version` → **v0.99.0** from `/run/current-system/sw/bin/crush` (fresh shell).
- Provider/model parity: `zai/glm-5.3-flash` appears **exactly once** in `crush models`; the rc carries `--reasoning-effort xhigh` (the 2026-08-31 regression class did not recur — assert-which-entity discipline).
- Hooks **correctly absent**: the deployed lock's crush-config rev (4468af5) predates the hook commits — hooks wait for deploy 2 (owner push landed mid-session; see §2).
- tq repos (CV/SystemNix/go-taskqueue): managed `.crushrc` blocks + glm-5.3-flash xhigh all present (T24 grep).

### The storm (diagnosed, not fixed — owner rows)

The IO storm that gates deploy 2 is engine-attributed with evidence: **flm-real crash-loop** (SIGABRT 21:08, SIGSEGV 21:19 with an **809 MB coredump**, `double free or corruption (!prev)` 21:34, SIGABRT+771.8M again 22:02 — the disable-or-pin [decision] row in ai-stack.md now carries tonight's recurrence), **hermes patchelf SIGSYS** every ~10 min (seccomp `syscall=383 compat=1`, cores only 13 KB — annoying, not IO-relevant), and ClickHouse XFS-CIL commit churn on nvme1n1p9. 732 MB/s page-writeback at peak; nvme1n1 100% busy sustained.

## 2. Everything else, task by task

| # | Task | Outcome |
|---|------|---------|
| T1/T2 | owner upstream pushes | **SUPERSEDED** consumer-side (shims, 18:56 session); the upstream paste cycle stays `[blocked:push]` |
| T3 | owner answers | Q2 deploy authority = granted by the execution directive; Q1 moot (shims); Q3 catwalk = parked (default per plan) |
| T4/T5 | re-proof + crush-config float | Done by the parallel float wave (proof rc=0); **the owner pushed crush-config mid-session** (lock now references d79602d — hooks INCLUDED and proven); my later hook commits (70dd859/3643dbe/0054687) need the NEXT float, riding deploy 2 |
| T6 | deploy | Deploy 1 landed (above); deploy 2 (hooks + hardening + crush-events) storm-gated |
| T7 | core verify | DONE (above); µ7.4/7.5 hook-fire = deploy-2-gated |
| T8 | llamacpp | **Discovery works live**: test server on 8899 (45 MB model — the first two GGUFs were corrupt/MTP-flag-needing), `crush models` lists `llamacpp/<model>` through the `--base-url …/v1` provider — no double-/v1. `--type llamacpp` accepted (rc-load + working discovery). Server stopped, port freed |
| T9 | crush-daily | **Schema-compatible**: real `collect` run against the 0.99.0-written DBs — 167 projects, 162 sessions, 26,345 messages, cost 263.12 parsed sane. (First `--config` probes hit the flag-after-subcommand parsing order + the missing-yaml default-config fallback — noted for the runbook) |
| T10 | pool dispatch | **Storm-gated** (entry-gate refuses at PSI ≥30; forcing a freeze-prevention gate is out of bounds). #4143 turn-resilience is binary-level (0.99.0 live); the pool-level soak re-opens with the calm window |
| T11 | float-register roots file | **LANDED** (940461ea): per-run `float-roots-<stamp>.md` beside every proof log (source-log path, drifted revs, root lines / green marker) + 4 selftest legs (8/8 green) |
| T12 | crush-config AGENTS.md | **LANDED** as `docs/hooks.md` (the repo's AGENTS.md IS the global template source — project content must not pollute it; right-file rule). Hook table, self-mute discipline, jq/DIRENV_DIFF rule, fixture-matrix requirements, module pointer comment |
| T13 | lessons | rc-masking + PIPESTATUS **already present** (crush-config lessons.md:469/791 — verified, not duplicated); per-log root-extraction lesson **LANDED** in SystemNix nix-flakes.md |
| T14 | hook robustness | **LANDED** (70dd859): redact 8 MiB size-cap early-exit + trap-remediation DIRENV_DIFF capture-before-unset evidence clause; fixtures both ways (9+11 assertions green) |
| T15 | daemon-commit SOP | 15.1 fmt-clean ✓; 15.2 `nix flake check --no-build` GREEN (after doc-counts re-stamp 142/252/53 — the check caught my own module landing); 15.3 already existed (CONTRIBUTING:311, more detailed than planned — no duplication) |
| T16 | StopFailure telemetry | **LANDED, deploy 2 carries it**: crush-config `stop-failure-log.sh` hook (redacted JSONL, 50k rotation, 11-assertion matrix) + SystemNix `crush-events` module (collector + 1m timer + gatus freshness canary + SigNoz rule at ≥5 errors/30m). Deviation: no standalone gatus HTTP endpoint — the freshness canary probes node-exporter (the architecture-catalog pattern); a StopFailure has no HTTP surface to probe, metric assertions belong to SigNoz |
| T17 | crush serve spike | **DECISION DOC LANDED** (docs/planning/2026-10-29_22-20_…, [decision] row in ai-stack.md): it's `crush server` (HTTP/Unix socket, multi-session, SIGHUP config-reload); recommendation = stay per-task, park B behind triggers; owner sign-off pending |
| T18 | upstream filing | 18.1 re-verified at the tag (lifecycle results parsed-then-discarded; PreCompact honors only deny — sharper than the original claim); 18.2 draft **voice-checked** (docs/drafts/2026-10-29_crush-hook-context-lifecycle-events.md, 0 FAIL 0 WARN); 18.3 owner approval pending |
| T19 | catwalk lever | PARKED (default; no trigger fired) |
| T20 | guard prose ergonomics | Folded into docs/hooks.md (ALLOW_RG_REPLACE prose-FP escape vs fix-the-scanner boundary) |
| T21 | permission audit | **LANDED** (3643dbe): `permission-audit.sh` PermissionResult hook — JSONL audit (ts/session/tool/decision, NEVER tool input), 10 MiB rotation, render + removal assertions, 10-assertion matrix |
| T22 | annotate 18:30 report | **LANDED** (5-point appendix: the missed 4th root, journal "transient" superseded, shims overtaking upstream-first, nur moved again, hooks-not-on-this-deploy) |
| T23 | cache cleanup | **DONE** (~/.cache/crush099 + scratch commitmsg trashed; proof logs kept — they are the audit trail) |
| T24 | tq repos coverage | grep green (3/3 managed blocks); kith-crm clone decision stays owner-gated with the paste-cycle row |

## 3. Multi-agent reality this session

Three parallel sessions were live (float-wave, router-audit, contacts-calendar executor). The daemon mixed commits repeatedly (my T16 files rode a commit with media-atlas edits; my README stamp rode a router-plan commit) — every mix was `git show --stat`-verified with content greps, pathspec discipline held throughout, and no foreign file was touched. A mid-ceremony collision with the float wave was caught and stood down (my drift-probe died on SIGPIPE before doing anything; their proof owned the tree). The plan EXECUTING marker was written before any plan action (1b58b4b8e).

## 4. What remains (all deploy-2- or owner-gated)

1. **Deploy 2** (float crush-config d79602d→0054687 + carry hooks/hardening/crush-events + T16.3 verify firing + T7.4/7.5 hook-fire + T10 pool soak) — blocked ONLY by the storm. It will fire on the first calm window (PSI<20 + disks<20% sustained 60s); the watcher ran through session end.
2. **flm disable-or-pin** — the standing [decision] row; tonight's crash evidence (3 crashes/26 min, 771.8 MB cores) is appended. This is the single owner action that would end the storm class.
3. Upstream pushes: cv/crm/journal paste cycle + crush-config (after 0054687) — one owner push session retires the whole treadmill (18:56 report §e.1).
4. T18.3: approve + file the lifecycle-context issue (draft ready).
5. T17 sign-off: ratify the per-task-processes park (or pick B with the doc's prerequisites).

**Self-harvest:** all session follow-ups landed at authoring time — storm rows (ai-stack.md flm recurrence + hermes SIGSYS, monitoring.md node-exporter evidence), the [decision] row (T17), the plan's queue pointer rows were verified non-drifted, and this report is the source for the EXECUTED marker flip.
