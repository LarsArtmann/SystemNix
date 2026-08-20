# Hermes Projects Hardening — Plan Execution (2026-08-20, T1–T15 session)

**Executed from:** `docs/planning/2026-08-20_09-18_hermes-projects-hardening-pareto-plan.md`
**Result:** all non-gated tasks DONE and deployed/verified; 2 gates remain open (user decisions).

## What shipped

| Task | State | Evidence |
|------|-------|----------|
| T1/D1 chown landmine | DONE (concurrent session `962d433d`, verified here) | **detonated live 09:18→09:35** (not dormant — EROFS spam in journal, start-limit-hit) before the fix deployed; fix exercised again cleanly at 10:13 + 10:33 restarts |
| T1/D2 dubious ownership | DONE | `GIT_CONFIG_GLOBAL` → read-only store gitconfig (`safe.directory` root + `/*`, recursive form per `git help config`); deployed unit verified; **live agent sessions run git inside `workspace/projects` (journal 10:29)** |
| T2 monitoring | DONE | `hermes` in system-health `monitoredServices`; Gatus "Hermes Agent Gateway" (failed/start-limit) + "Hermes Memory Pressure" (90% of 24G), fail-closed pat()s, Discord alerting — `success=true` verified live |
| T3 deploy smoke | DONE | hermes section in `post-deploy-check.sh`: gateway-PID mountinfo `ro` bind + deployed-unit `GIT_CONFIG_GLOBAL` parse check (2 PASS on live run) |
| T4 VM test | DONE, GREEN | `tests/test-hermes.nix`: bound+bare nodes; EROFS (even root), env ×3 presence/absence, git positive+negative control through the bind, acl-revoke exactly-once, D1 drift regression. Gateway = `sleep infinity` (mkForce) |
| T5 workspace AGENTS.md | DONE | `hermes-workspace-doc` ExecStartPre, once-only install; journal: `hermes-workspace: installed AGENTS.md` 10:34:03 |
| T6 runbook | DONE | `docs/services/hermes.md` (options, access model, ExecStartPre order, ops, landmine history) + AGENTS.md Hermes section updated |
| T8 audit tooling | DONE | `scripts/hermes-state-audit.sh` (user-run sudo; bind-aware du/find; MemoryMax/OOM context). **NOT yet run — user action** |
| T9 investigations | DONE | 09:09 exit-1 = SIGTERM deploy stop (shutdown path exits 1 by design); quickshell WARN = transient deploy-window line, self-cleared; "Slash command sync timed out" = 0 occurrences/24h — live variant is Discord 429 rate-limit on restart re-sync (benign, upstream retries) |
| T10 mnemosyne | DONE (classified) | user-configured `mcp_servers` entry in RUNTIME config.yaml; backing server closes instantly; upstream parks it by design; warnings stop on restart; removal is a settings-UI action |
| T11 eval guard | DONE | `chown-vs-bind-audit` flake check — WARNING-only (plan guardrail), negative-tested standalone (catches `chown -R` + unscoped find walks in Bind*Paths modules; hermes.nix clean); promote to FAILING after ~1 week (TODO_LIST) |
| T12 gotcha docs | DONE | AGENTS.md systemd-gotcha bullet (ACLs + chown-vs-bind); gotchas-archive ×2 (ACL-mask kill; namespace-vs-ExecStartPre ordering) |
| T13.1 retirement TODO | DONE | dated TODO_LIST item ≥2026-09-03 + verify command |
| T15 upstream hygiene | DONE | flake-input re-verify comment (TERMINAL_CWD/WRITE_SAFE_ROOT env dependency); upstream PR outline + TERMINAL_CWD migration TODO in TODO_LIST |
| U1 Discord E2E | **USER ACTION** | see below |
| T7 workspace disk | **GATED (Q2)** | recommended: sibling subvolume `@hermes-workspace` |
| T14 private-repo creds | **GATED (Q1+Q3)** | recommended: read-only fine-grained PAT/deploy key |

## Verification summary

- 3 deploys this session, each `63–65 PASS / 0 FAIL` (the 2 new hermes smoke checks count from the second deploy)
- `nix flake check --no-build` green incl. new `chown-vs-bind-audit` (zero warnings)
- VM test green twice (pre/post-format)
- GIT_CONFIG_GLOBAL semantics verified against installed git 2.55.0 man page (`<dir>/*` = all repos under, recursive)

## Concurrent-session note

The D1 fix (commit `962d433d`, 09:29) was authored by a parallel session — this session verified it deployed + live-exercised, and built everything else on top. Journal evidence shows the landmine was a REAL outage (09:18–09:35), not the "dormant" defect the plan assumed.

## Open (user)

1. **U1 E2E**: in Discord ask hermes to (a) read `projects/SystemNix/flake.nix`, (b) run `git -C ./projects/SystemNix log -1` (would have failed pre-T1 with dubious ownership), (c) `git clone ./projects/SystemNix ./systemnix-clone && ls ./systemnix-clone`
2. **Q2 disk**: sibling subvolume `@hermes-workspace` (recommended) / `/data` / quota+GC
3. **Q1+Q3 creds**: read-only PAT/deploy key scope, write-back = permanently no (recommended)
4. **T8 execution**: `sudo bash scripts/hermes-state-audit.sh` and review the 58G breakdown
