# Hermes Projects Hardening — Plan Execution Status

**Date:** 2026-08-20 10:44 CEST · **Session:** executed `docs/planning/2026-08-20_09-18_hermes-projects-hardening-pareto-plan.md` · **Machine:** evo-x2 · **Worktree:** clean @ `04dac7b6`

---

## a) FULLY DONE — implemented, deployed, runtime-verified

| Task | What shipped | Verification evidence |
|------|--------------|----------------------|
| **T1/D2 dubious ownership** | `GIT_CONFIG_GLOBAL` env (projectsDir-gated) → read-only store gitconfig, `[safe] directory` for mount root + `/*` (recursive semantics verified against installed git 2.55.0 man page — NOT assumed) | Deployed unit env inspected; store file content verified; **live agent sessions run git inside `workspace/projects`** (journal 10:29-10:30); VM test positive + negative control (git fails WITHOUT the env var — proves it's load-bearing) |
| **T1/D1 verification** | The chown-vs-bind landmine fix (concurrent session's commit `962d433d`) verified deployed and live-exercised | **CRITICAL FINDING: D1 was NOT dormant** — journal shows the EROFS crash-loop detonated live 09:18→09:35 (start-limit-hit, hermes down) before the fix deployed. The fix's walk ran cleanly at 10:13 and 10:33 restarts (journal: `hermes-perms: fixing ownership`, zero `Read-only file system`) |
| **T2 monitoring** | `hermes` added to system-health `monitoredServices`; Gatus "Hermes Agent Gateway" (state_failed + start_limit_hit, fail-closed pat()s) + "Hermes Memory Pressure" (90% of 24G MemoryMax), both Discord-alerting | First gatus cycle red (metrics not yet collected — fail-closed working AS DESIGNED), green from next collector cycle (`success=true` 10:18:42); textfile metrics confirmed in `system_health.prom` |
| **T3 deploy smoke** | Hermes section in `scripts/post-deploy-check.sh`: gateway-PID mountinfo `ro` bind + deployed-unit `GIT_CONFIG_GLOBAL` (extracts path from unit file, parses with `git config --file`) | 2 PASS on standalone run + 2 PASS in deploy #3 (63→65 PASS total) |
| **T4 VM test** | `tests/test-hermes.nix` (new, in `checks`): two nodes (bound + bare). Asserts: bind `ro` in unit namespace via nsenter; writes EROFS **even as root**; workspace-beside writable (positive control); env ×3 present/absent on `projectsDir=null`; **git through the bind with the deployed gitconfig** + negative control; acl-revoke removes a seeded stale grant EXACTLY once (restart twice, journal-count=1); D1 regression (chmod 0755 drift + bind present → walk runs, no EROFS, unit starts). Gateway replaced by `sleep infinity` (mkForce) — tests SystemNix plumbing, not upstream Python | GREEN ×3 runs (initial, post mock-sops fix, post-format). One eval bug found+fixed en route: mock-sops needed `sops.templates."hermes-env"` DEFINED (module reads `.path`; the real host defines it elsewhere) |
| **T5 workspace AGENTS.md** | `hermesGitConfig` sibling: `workspaceAgentsDoc` + `hermes-workspace-doc` ExecStartPre (projectsDir-gated, runs as service user) — ONCE-ONLY `test -f || install`, so agent edits survive deploys (NOT tmpfiles `f`, which would clobber). Content: RO mirror semantics, clone-first workflow, per-repo git identity (global is read-only), write scope, 0700-dirs-are-intentional, disk hygiene | Journal: `hermes-workspace: installed AGENTS.md` 10:34:03. Content itself not cat-verified — `/home/hermes` is 2770 hermes-only (see e) |
| **T6 runbook** | `docs/services/hermes.md` (new): options table, access model (all 5 mechanisms), ExecStartPre chain ORDER, ops commands, MemoryMax note, landmine history, benign-noise list (TERMINAL_CWD warning, tool-registry lines, Discord 429). AGENTS.md Hermes section extended (GIT_CONFIG_GLOBAL, never-chown-R rule with the -xdev caveat, monitoring map) | Committed |
| **T9 investigations** | (a) 09:09:32 `status=1/FAILURE` = SIGTERM deploy stop; gateway shutdown path exits 1 BY DESIGN (drain context logged by the process itself). (b) quickshell WARN = transient deploy-window line, self-cleared (no entries on re-query). (c) `Slash command sync timed out`: **zero** occurrences in 24h — live variant is `Discord rate-limited slash command sync; retrying after NNNs` (HTTP 429 on restart re-sync, upstream retries with backoff) — benign | Journal greps in report |
| **T10 mnemosyne** | Classified, no action: `mcp_servers` entry in hermes' RUNTIME config.yaml (settings-UI owned, NOT SystemNix config); backing server closes instantly; upstream parks after 3 attempts BY DESIGN; warnings stop on restart. Removal = user settings-UI action | Upstream source read (`hermes_cli/config.py` mcp_servers handling, `plugins/memory`) + journal |
| **T11 eval guard** | `chown-vs-bind-audit` flake check (next to `gatus-pattern-lint`): WARNs on `chown|chmod -R` or `find … -exec chown/chmod` without `-prune`/`-xdev` in any module configuring `Bind*Paths`. **WARNING-only per plan guardrail** (exit 0 always). Also fixed my own grep bug (`grep -v '^#'` never matches `grep -n` line-numbered output) before it shipped | Negative-tested standalone: synthetic violator → both warnings fire; hermes.nix (fixed) → zero. Full flake check green, zero warnings repo-wide |
| **T12 gotcha docs** | AGENTS.md systemd-gotcha bullet (ACL-fragility + chown-vs-bind + `-xdev` insufficiency); gotchas-archive ×2 full entries (ACL-mask kill; namespace-before-ExecStartPre ordering, with incident dates + verify commands) | Committed |
| **T13.1 retirement gate** | Dated TODO_LIST item: earliest 2026-09-03, verify `getfacl /home/lars \| grep hermes` empty, then delete script + ExecStartPre | Committed |
| **T15 upstream hygiene** | flake.nix hermes-agent input comment (RE-VERIFY ON BUMP: TERMINAL_CWD/WRITE_SAFE_ROOT env behavior, where verified, what covers it); upstream PR outline in TODO_LIST (incl. verify-before-filing gate); TERMINAL_CWD migration TODO (do-NOT-fix note) | Committed |
| **T8 tooling** | `scripts/hermes-state-audit.sh` (shellcheck-clean): bind-aware du/find (excludes the RO view — no double-count), top-20 files, workspace growth, MemoryMax/cgroup peak + OOM-history pointer. **Not yet RUN — needs sudo (user)** | bash -n + shellcheck clean |

**Deploys this session: 3** (T1, T2, T5) — each `nix run .#deploy`, post-deploy smoke **63→65 PASS / 0 FAIL** (2 new hermes checks counted from deploy #2). Full `nix flake check --no-build` green after every change. Committed: `04dac7b6` (mine) + auto-commit daemon captured intermediates (`81b12f8f`, `568db6d8`, `17bd9b10`). **NOT pushed** (no instruction to).

## b) PARTIALLY DONE

- **U1 (user Discord E2E)** — infrastructure fully verified, the actual agent-side E2E NOT exercised by me (no Discord access). Everything predicts success (live sessions already git the bind), but "the only true functional proof" is still open. Commands ready (see g).
- **T8** — script shipped; the audit itself (58G breakdown, MemoryMax verdict) awaits the sudo run.

## c) NOT STARTED (deliberately)

- **T7 workspace disk strategy** — GATED on Q2 (user). Recommendation stands: sibling subvolume `@hermes-workspace` (excluded from `@` snapshots AND pool sends by construction; NOT `/data` — un-repaired EIO corruption).
- **T14 private-repo creds** — GATED on Q1+Q3 (user). Recommendation: read-only fine-grained PAT or deploy key; write-back = permanently no.
- **T13.2 acl-revoke deletion** — time-gated ≥2026-09-03 (by design, 2-week grace).

## d) TOTALLY FUCKED UP (own this)

1. **The gate-collection `question` call FAILED** — I malformed the tool payload (nested the questions array inside a wrapper item; validator: `invalid type ""`). The Q1-Q3 decisions never reached the user this session; T7/T14 stayed blocked on a tooling error I did not retry before the user interrupted. Should have retried once with the correct shape immediately.
2. **Inherited a wrong claim without evidence** — the plan said D1 was "dormant"; I repeated that framing in my first verification message ("Dormant only because the stat-guard early-exits") BEFORE reading the journal. The journal proved a real 17-minute outage (09:18→09:35). Lesson (already in AGENTS.md): status reports are point-in-time — re-verify, don't inherit.
3. **Three deploys with zero check for LIVE agent sessions** — the journal showed active agent turns at 09:42-10:00 and 10:29; each of my restarts drained/interrupted them (`Gateway drain timed out … 1 active agent(s)` at 10:13). The P0 fixes justified it, but deploy #3 (docs-only + workspace doc) could have waited or checked `journalctl -u hermes --since -10min` for session activity first.
4. **Formatter churn rode the feature commit AGAIN** — `nix fmt` reformatted `tests/test-hermes.nix` (152-line diff) and it merged into `04dac7b6`. This exact lesson was written down LAST session; still repeated. The fix is procedural: `nix fmt` → commit formatter output separately → then feature commits.
5. **First-draft garbage comment** — wrote `"detentious ownership" — actually: "detected dubious ownership"` into hermes.nix and had to immediately re-edit (caught it myself, but it proves I didn't proofread before writing).
6. **Status-report typo** (`flake.nick`) — fixed before commit.

## e) WHAT WE SHOULD IMPROVE (concrete)

1. **deploy.sh: warn when hermes has active agent sessions** before `nh os switch` (journal grep, non-blocking WARN) — same class as the deploy-kill awareness PMA has.
2. **Separate formatter commits** — procedural rule; the daemon will batch otherwise (d.4).
3. **Smoke check hardcodes `/home/hermes`** while the module's `stateDir` is configurable — derive or assert-on-default; fine for evo-x2, misleading for another host.
4. **Workspace AGENTS.md content unverified end-to-end** — `/home/hermes` is 2770; only the install journal line is observable from lars. A root-side smoke check (or making the doc world-readable once installed) would close that.
5. **VM test uses `sleep infinity`** — upstream gateway startup (uv2nix venv, .env merge interplay) remains untested in CI; accepted tradeoff, should be stated in the test header (it is) and revisited if upstream grows a `--check` mode.
6. **chown-vs-bind-audit is source-grep, not unit-attribute eval** — script texts are unreachable at eval time (drv outPaths unbuilt); the grep heuristic covers authored modules only. Documented in the check itself; promote to FAILING after a clean week.
7. **Gatus restart-churn alert** (system_service_nrestarts threshold) — start-limit coverage exists; a crash-loop that never quite hits the limit (exit 75 chain) wouldn't alert.

## f) NEXT — ranked, ~40 items (P0 → backlog)

**User actions (blocking):**
1. U1 Discord E2E: read `projects/SystemNix/flake.nix`; `git -C ./projects/SystemNix log -1`; `git clone ./projects/SystemNix ./systemnix-clone && ls ./systemnix-clone`
2. `sudo bash scripts/hermes-state-audit.sh` → review 58G breakdown + MemoryMax verdict
3. Answer Q1-Q3 (see g) → unblocks T7/T14
4. Push `04dac7b6` (+ this report) — I don't push unasked

**Immediately after gates:**
5. T7: create `@hermes-workspace` subvol (sudo) → mkFilesystem mount → migration oneshot → verify `@` snapshots + pool sends EXCLUDE it
6. Workspace clone GC timer (age-based, ioTier.maintenance) once on its own subvol
7. Workspace usage metric (buildcache-metrics pattern) + Gatus threshold
8. T14: read-only PAT/deploy key → sops (public-key encrypt, no sudo) → hermes env + `core.sshCommand` in the safe-dir gitconfig → clone-verify ONE private repo
9. MemoryMax decision from T8 data (document GPU-mapping-vs-RSS reasoning; don't blind-cut)

**Hardening follow-ups:**
10. Promote `chown-vs-bind-audit` WARNING→FAILING (~2026-08-27, one clean CI week)
11. e.1: deploy.sh active-session WARN for hermes
12. e.3: derive smoke-check paths from config (or assert default stateDir)
13. e.4: root-side existence check for workspace AGENTS.md in smoke
14. e.7: Gatus nrestarts churn alert for hermes
15. VM test: assert workspace-doc once-only across TWO restarts (mtime unchanged)
16. VM test: upstream-lightweight case if hermes ever gains a dry-run/health command
17. T13.2: delete acl-revoke ≥2026-09-03 after `getfacl` verify (dated TODO exists)

**Upstream (hermes-agent):**
18. File projectsDir RO-bind module proposal (verify-before-filing first — TODO has outline)
19. Bump input past v0.20.1 + DELETE registration_lifecycle patch (existing TODO)
20. Upstream issue: 10× duplicate `Switched to fallback model` lines at startup
21. Upstream: parked-MCP visibility (mnemosyne class — silent until reconnect attempt)
22. TERMINAL_CWD → generated-config migration when upstream supports it (TODO exists)

**Noticed in journals this session (out of scope, backlog candidates):**
23. hermes LSP broken: `PermissionError /home/hermes/lsp/bin/{pyright,bash-language-server}` — agent lint tooling degraded
24. Agent's doctor tool probes `/tmp/doctor_probe.py` → HERMES_WRITE_SAFE_ROOT denial; teach scratch semantics in workspace AGENTS.md v2
25. `cp: …/.hermes/scripts/ensure-chromium-cdp.sh same file` — agent self-copy confusion, harmless
26. Chromium CDP children SIGKILLed on every hermes restart (KillMode=mixed) — expected but noisy; document in runbook ops
27. Pocket ID SQLITE_BUSY spikes adjacency to hermes IO (existing gotcha, no new action)
28. Quickshell deploy-window WARN recurs every deploy — demote after 3 clean deploys if pattern holds

**Bookkeeping:**
29. Annotate `2026-08-20_09-15` status report with execution pointer (docs-health)
30. Reconcile TODO_LIST hermes SSH-key + fallback-model items (56/57) with T14 outcome
31. Consider `docs/services/` index README
32. CI: confirm hermes VM test substitutes cleanly on a cold runner (flake check full)
33. Plan mermaid: mark executed nodes (cosmetic)

## g) QUESTIONS (cannot resolve myself)

1. **Q1 — private-repo credentials for hermes?** Read-only fine-grained PAT / deploy key (recommended — unblocks private-repo clones, RO bounds blast radius), or none?
2. **Q2 — workspace disk layout?** Sibling subvolume `@hermes-workspace` (recommended — excluded from snapshots/sends by construction, NOT `/data` which has the un-repaired EIO), quota+GC on `@`, or defer?
3. **Q3 — write-back policy?** Permanently read-only (recommended — no creds to revoke later), or push-branches scope?

---

**Session verdict:** 13/16 plan tasks DONE+verified, 2 gated on the questions above, 1 time-gated. The feature is now safe (D1 fixed + regression-locked), useful (git works — proven by live agent traffic), observable (Gatus + smoke), and durable (VM-tested). Waiting for instructions.
