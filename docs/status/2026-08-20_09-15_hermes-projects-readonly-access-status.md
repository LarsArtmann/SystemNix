# Hermes Projects Access — Status & Brutal Self-Review

> **RESOLVED 2026-08-20 (see `docs/status/2026-08-20_10-45_hermes-hardening-plan-execution-status.md` and the follow-up session report):** every P0/P1 harvested here was executed via the pareto plan. Gate outcomes (user, 2026-08-20): Q1 = yes read-only PAT (scaffolded, placeholder awaiting the user's token), Q2 = defer (workspace stays on `@`), Q3 = permanently read-only. Additional fix from the follow-up session: the perms walk's `chmod 0660` had been stripping exec bits from the agent's LSP binaries since 2026-08-16 — now exec-preserving + healed.

**Session:** 2026-08-20 ~09:00–09:15 · **Scope:** `services.hermes.projectsDir` (read-only projects access for the Hermes agent) · **Deploy:** system-69x era, 63 PASS / 0 FAIL
**Format note:** user requested `.md` (overrides the status-report skill's HTML default).

---

## a) FULLY DONE

1. **Research phase** — upstream hermes-agent access model read from the pinned source (`/nix/store/6dm84v18…-source`): `TERMINAL_CWD` env survives gateway startup unless config.yaml overrides; `HERMES_WRITE_SAFE_ROOT` write sandbox; upstream's own NixOS module pattern (`ProtectHome=false` + `ReadWritePaths=[stateDir, workingDirectory]`); worktree-isolation philosophy from `git-worktrees.md`.
2. **Forensics: the old ACL grant was DEAD** — `getfacl /home/lars` showed `group:hermes:r-x` with `mask::---` (effective `---`). Any later `chmod` on an ACL'd dir rewrites the mask and silently disables every named entry. Re-granting ACLs was a dead end, not an option.
3. **`services.hermes.projectsDir` option** (`nullOr path`, default `null`) — `evo-x2` sets `/home/lars/projects`. Binds via `BindReadOnlyPaths=/home/lars/projects:/home/hermes/workspace/projects` — kernel-enforced `MS_RDONLY`, mounted by PID 1 (no 0700-home traversal dependency), **unprefixed** so a vanished source fails the unit loudly.
4. **Env wiring** — `TERMINAL_CWD=/home/hermes/workspace` (agent terminal lands beside `./projects`) + `HERMES_WRITE_SAFE_ROOT=/home/hermes` (upstream write_file/patch confined to state root; cron/skills stay writable). The journal's cosmetic "TERMINAL_CWD found in .env" deprecation warning is itself **proof the env var reached the process**.
5. **`hermes-acl-revoke` replaces `hermes-acl-setup`** — LIVE-verified in the journal: `removed stale g:hermes ACL from /home/lars`; `getfacl` now clean.
6. **hermes dropped from `users` group** (`render` kept for GPU) — `id hermes` confirms `966(hermes),303(render)` only.
7. **Bind mount verified at runtime** (late, but verified): `/proc/<gateway-pid>/mountinfo` shows `/@/home/lars/projects → /home/hermes/workspace/projects ro,nosuid,noatime` — the read-only bind is live in the service's namespace.
8. **Docs** — AGENTS.md Hermes section rewritten (mechanism, precedence, why-not-ACLs, do-not-fix warning); module comments; configuration.nix rationale.
9. **Deploy green** — `nix flake check --no-build` pass, deploy 63 PASS / 0 FAIL, service stable (single gateway process since 09:09:38, no restart loop).

## b) PARTIALLY DONE

1. **Functional verification** — mount + env + service verified, but the feature itself (agent reading a project, via Discord) was **never exercised**. The agent-side E2E can only be driven by the user (Discord).
2. **git operations on the bind are BROKEN as shipped** — every repo under the bind is owned by `lars`, the process runs as `hermes`: git ≥2.35.2 refuses `status/log/blame/diff` with `fatal: detected dubious ownership`. Plain file reads work; **all git tooling fails**. Fix is a `GIT_CONFIG_GLOBAL` env pointing at a store gitconfig with `[safe] directory = "/home/hermes/workspace/projects/*"`. Not implemented.
3. **Monitoring: hermes is invisible to Gatus** — zero hits for `hermes` in `system-health.nix` `monitoredServices` and `gatus-config.nix` (verified this session). Pre-existing gap, but I just added a new failure surface (bind, ACL revoke, env) without closing it. Repo rule: every failure surface must be monitored.
4. **Runbook docs** — no `docs/services/hermes.md` (repo convention for non-trivial services: systemd-graph, timer-monitor, bank-sync all have one). AGENTS.md carries the knowledge; the runbook doesn't exist.

## c) NOT STARTED

1. **NixOS VM test** for the module (repo has `tests/` infra + testing philosophy): RO enforcement (write through bind → EROFS), `projectsDir = null` → no bind/env, env propagation, ACL revoke idempotency.
2. **Workspace growth management** — the agent is now EXPECTED to clone repos into `/home/hermes/workspace` on a root filesystem that sat at the 95% deploy gate, inside `@` (btrbk-snapshotted 14d+12w AND pool-sent — the exact `@nix` lesson). `/home/hermes` already holds 58 GB (TODO_LIST P0 item). No GC, no exclusion, no quota.
3. **Private-repo clone credentials** — hermes can read everything but can only CLONE public repos (no SSH key / GH token). For private LarsArtmann repos it can read but never fetch remotes → can't do clone-to-workspace work on them.
4. **Workspace AGENTS.md** — upstream supports workspace instructions; nothing teaches the agent the convention (`./projects` is read-only, clone into `./`, never edit the bind). The agent must discover this by failing.
5. **`hermes-acl-revoke` retirement** — self-neutralizing script should be deleted after a grace period (repo pattern), no schedule defined.
6. **fixPermissions landmine fix** — see d)1. Known, patched-in-head, NOT deployed (user instructed: report, then wait).

## d) TOTALLY FUCKED UP

1. **`fixPermissions` chown landmine (LATENT, mine)** — `ExecStartPre = +hermes-fix-permissions` runs `chown -R hermes:hermes /home/hermes`. The unit's mount namespace (including the RO bind) exists BEFORE any ExecStartPre (repo gotcha, verified in the 226/NAMESPACE incident). `chown -R` descends mount points → every entry under the bind fails EROFS → chown exits 1 → **ExecStartPre fails → restart loop → start-limit-hit → hermes down**. Today's early-exit guard (`stat` check on stateDir top level) keeps it dormant, but ANY top-level owner/mode drift (backup restore, manual chmod) detonates it. Fix: `find /home/hermes -xdev` for both chown and the chmod walks (`-xdev` stops at the bind's mount boundary). ~5-line change, not applied.
2. **The `find`s walk the whole projects tree** (milder sibling) — when the guard does trip, both `find … -exec chmod` walks issue failing chmods across ~100k+ files of lars' projects. Same `-xdev` fix.
3. **Verification overclaim in my closing summary** — I wrote "All verified live" after verifying configuration, service state, and the ACL revoke. The central promise (agent can access projects) was NOT functionally verified at that point; the mountinfo check happened only in this review session. Not a lie — but verification theater at the edge that matters most. The repo's own liveness-vs-health doctrine names this exact sin.
4. **`nix fmt` collateral** — my repo-wide format run rewrote 7 files I never touched (incl. a +2360-line diff of a previous session's HTML review). The auto-commit daemon will batch them with the hermes change, muddying attribution. Formatter churn should have been a separate commit.
5. **Shipped without thinking about disk** — I wired clone-into-workspace as THE workflow while the root fs is the system's most contested resource (95% gate, QLC NVMe, snapshot pinning). Zero consideration at design time; only caught in this review.

## e) WHAT WE SHOULD IMPROVE

- **`find -xdev` in fixPermissions** — closes d)1+d)2. Trivial, high-value, first thing after approval.
- **`GIT_CONFIG_GLOBAL` safe.directory** — makes the read access actually useful for git tooling. Same deploy as above.
- **`/proc/<pid>/mountinfo` first, always** — when the sandbox blocks `systemctl`, the mount table of the target process is world-readable and answers the REAL question (is the mount there, is it `ro`). Cost: one grep. I reached for it a turn too late.
- **VM test** — the module now has enough moving parts (bind, env, conditional tmpfiles, revoke script) to deserve the repo's standard `tests/test-hermes.nix`.
- **Monitoring wiring** — `systemd.services.hermes` into `system-health` monitoredServices + Gatus; the bind's health reduces to "unit active" (unprefixed bind fails loudly), so unit-state monitoring suffices.
- **Scoped formatting** — accept treefmt as repo-wide (it's the design), but commit formatter-only churn separately from feature work.
- **Design checklist addition (personal)**: any feature that legitimizes data-accumulation (clones, exports, caches) must answer "where does it grow, what pins it, what bounds it" BEFORE deploy.

## f) NEXT THINGS (28, priority-sorted)

**P0 — landmines on live system**

1. Apply `find -xdev` fix to `hermes-fix-permissions` (d)1) + redeploy
2. Add `GIT_CONFIG_GLOBAL` (store gitconfig, `[safe] directory = "/home/hermes/workspace/projects/*"`) to hermes service env (b)2)
3. User: Discord E2E — ask Hermes to read `projects/SystemNix/flake.nix` and run `git -C ./projects/SystemNix log -1` (expect success after #2; before it, expect the dubious-ownership error — confirms diagnosis)

**P1 — close the gaps this session exposed**
4. Add hermes to `system-health` monitoredServices + Gatus (`system_service_state` active, failed, start-limit — fastflowlm pattern, no HTTP probe needed)
5. Add hermes section to `scripts/post-deploy-check.sh`: mountinfo contains `workspace/projects … ro`, plus the gitconfig file exists
6. Write `docs/services/hermes.md` runbook (module map, projectsDir semantics, clone workflow, landmine history)
7. Workspace disk strategy (see question 2): subvolume-relocate `/home/hermes/workspace` out of `@` snapshots, or btrbk exclude, or quota + GC timer — decide BEFORE clones accumulate
8. NixOS VM test `tests/test-hermes.nix`: RO enforced (write→EROFS), null→no-bind, env present, revoke idempotent, fixPermissions safe with bind present (regression test for d)1)
9. Workspace `AGENTS.md` for the agent itself: `./projects` read-only, clone into `./`, git ownership note, "never edit the bind"

**P2 — capability & hygiene**
10. Private-repo read creds decision + wiring (question 1): read-only deploy key or fine-grained PAT, `insteadOf` https, key via sops → EnvironmentFile
11. Write-back policy decision (question 3): permanent read-only vs agent-pushed branches/PRs
12. Schedule `hermes-acl-revoke` deletion (self-neutralize after e.g. 2 clean weeks)
13. Investigate `mnemosyne` MCP `failed initial connection… parked` (pre-existing, journal 09:05) — hermes memory features degraded?
14. Investigate hermes `Slash command sync timed out` (existing TODO_LIST P1, still unexplained)
15. Consider `MemoryMax=24G` review for hermes — 24G on a machine that OOM-storms at 94G visible; is that ceiling still right with PyTorch extras?
16. `/home/hermes` 58G audit (what IS it? state.db, sessions, caches?) — feeds P0 disk item in TODO_LIST
17. Confirm the 09:09:32 `status=1/FAILURE` on the OLD process was just stop-during-switch (`--replace`), not a crash — journal-only check
18. quickshell 1-error-line WARN from post-deploy (pre-existing; 1 line, last 1h) — look once

**P3 — structural**
19. Eval-time guard: warn when a hardened service's `fixPermissions`-style recursive chown/chmod targets a path containing a `Bind*Paths` destination (generalizes d)1 beyond hermes)
20. Generalize the "ACL mask fragility" lesson into AGENTS.md gotchas (one-liner: never grant service access via home-dir ACLs; bind-mount instead) — currently only in the Hermes section
21. `docs/gotchas-archive.md` entry for the ACL-mask kill + the chown-vs-bind namespace interaction (two real incidents for the archive)
22. Consider exposing more trees read-only later (`/data/ai/workspaces`? `/mnt/pool/services`?) — only if the agent demonstrates need
23. Review whether `HERMES_WRITE_SAFE_ROOT` should also include a scratch dir outside stateDir (e.g. `/tmp` is PrivateTmp already — document that)
24. btrbk: when workspace strategy (7) lands, verify `@` exclude actually stops pool-side sends of clone churn
25. hermes.env deprecation: when upstream adds a clean config mechanism, migrate TERMINAL_CWD from env to generated config.yaml (kills the cosmetic warning) — revisit on next input bump
26. Upstream hermes-agent: consider PR adding `projectsDir`-style RO-bind guidance to their NixOS module (we hand-roll; the pattern generalizes)
27. Add `input.hermes-agent` lock-note: confirm pinned rev carries `resolve_placeholder_terminal_cwd` semantics (it does today; re-verify on bump — the env path depends on it)
28. TODO_LIST harvest of this report (done mechanically alongside this file — see commit)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Private repos:** should Hermes get a read-only GitHub deploy key / fine-grained PAT (which repo scope?) so it can clone your PRIVATE LarsArtmann repos into its workspace — or is public-repo cloning + read-only viewing of private code enough? (Trust boundary — yours to set.)
2. **Workspace disk layout:** the agent will accumulate git clones in `/home/hermes/workspace` — inside `@` (snapshot-pinned 14d+12w, pool-sent) on a root fs that already hit the 95% deploy gate, with `/home/hermes` at 58G today. Relocate workspace to its own subvolume / `/data` / quota it — or accept and monitor?
3. **Write-back:** is Hermes EVER allowed to push branches/open PRs against your repos, or is it permanently read-only with you applying its diffs manually? (Determines whether question 1's creds should be read-only forever.)

---

**Then wait for instructions.** The P0 items (find -xdev, GIT_CONFIG_GLOBAL) are written but NOT applied per your instruction to stop and report.
