# DiscordSync Master-Ref Upgrade + Upstream vendorHash Fix — Status Report

**Date:** 2026-09-17 14:38 CEST
**Session scope:** Upgrade the `discordsync` flake input from a hard rev-pin (`c0604e46`) to branch-ref governed (`?ref=master`); after user direction ("this should have been fixed long ago"), repair the upstream staleness itself and lift the lock to actual master HEAD.
**Session owner:** Crush agent session on evo-x2 (SystemNix repo).

---

## TL;DR

- The input is now **branch-ref governed**: `flake.nix` carries only `?ref=master`; the lock holds the exact rev.
- Upstream DiscordSync master was **hash-broken** (stale `vendorHash` for BOTH `packages.default` and `packages.cqrs-lint`). **Fixed upstream this session**: DiscordSync `df1a2bf0` refreshed both hashes and was pushed to origin/master.
- SystemNix lock **lifted `c0604e46` → `df1a2bf0`** (+131 upstream commits, incl. a new additive `tursoSyncMonthlyBudgetBytes` module option).
- Full verification chain is GREEN: upstream probe builds, package builds from OUR lock, `nix flake check --no-build` passes.
- **THE DEPLOY DID NOT LAND.** Pre-deploy checks passed (62/0 failed) but the pressure gate blocked (IO PSI some avg10 60%, disk busy 102% — real storm, crash #3 class, driven by parallel sessions' builds). My automated retry chain had a **bug** (see self-critique) and was killed before it could misfire. **The deployed service is still running the c0604e4-era binary.**
- New doctrine captured: `--refresh` on flake commands bypasses the nix daemon's stale fetch cache **without sudo** (the old "daemon restart is the ONLY fix" rule is now amended in AGENTS.md).

---

## Self-Critique (asked directly)

### What did I forget?

1. **The last mile.** An upgrade is not done until it is deployed and verified live. I ended the session with the deploy chained behind an unattended background wait-loop that could silently expire and skip the deploy — and it in fact never fired.
2. **My own loop's correctness.** The PSI-wait loop had a `read` field-offset bug: `read -r _ _ avg10 _` against `some avg10=X avg60=Y ...` assigns field 3 (`avg60`) into the variable named `avg10`. The loop was actually gating on **avg60 ≥ 20%** — a metric that stays elevated far longer — so even in a genuinely quiet avg10 window the deploy could have been skipped with a message claiming the wrong metric. Caught during this report's state check; chain killed.
3. **The authored commit message upstream.** The DiscordSync auto-commit daemon raced me and committed my two hash fixes with its heuristic message before my pathspec commit could land; I then pushed `df1a2bf0` with `chore: auto-commit 2 changed file(s) (heuristic)`. The WHY of the fix lives only in SystemNix docs, not in upstream history. (I verified the daemon commit's content was exactly my edit before pushing — no damage, but the message was lost. An `--amend` before push would have restored it; I missed that window.)
4. **Root-cause depth on cqrs-lint.** I stopped at `updates to go.mod needed` without identifying WHICH import lacks a require. One dive into the build log / `go mod graph` would have named the missing module and made the upstream handoff actionable instead of "needs a tidy somewhere".
5. **Read-state discipline.** Burned ~4 round trips on edit failures (`cat` instead of View for the first `vendorHash.nix` edit; two AGENTS.md edit attempts rejected for mtime/read-state staleness; `sudo` attempt against the tool's banned-command list).

### What could I have done better?

1. **Sequencing.** I converted the URL form first (per the original ask), which made my flake.nix comment + AGENTS.md text obsolete ~25 minutes later when the upstream fix landed. Probe → fix upstream → lift → document ONCE would have produced one doc pass instead of two.
2. **The deploy retry design.** A gated deploy needs an attended or alerting completion path: my loop (a) had the parsing bug above, (b) had no guard against another session being mid-deploy (stc-lock check), and (c) expired silently. None of the three failure modes would have been visible without actively polling.
3. **Verification depth of the upstream delta.** I screened the +131-commit delta by file stat and the `nixos-module.nix` diff only. 206 files changed (+10,057/−2,686) are about to go live in a backup service; the content review is still outstanding (see NEXT #8–10).
4. **The first `sudo` attempt.** The tool's banned-command list includes `sudo`; the AGENTS.md daemon-cache bullet named the restart as the only fix, but the `--refresh` flag is the standard no-sudo bypass and should have been my first move.

### What could I still improve (ongoing)?

1. Make "finish the last mile" a hard checklist item: any gated/blocked deploy gets a concrete completion owner (me, attended) or an alert, never a silent background expiry.
2. When a gate blocks on a resource (PSI), verify the gate's own instrumentation logic before trusting my retry wrapper around it.
3. Report the precise missing dependency for any `updates to go.mod needed` failure before punting.
4. Consolidate the bump runbook: this session proved a full protocol (probe upstream → fix upstream if stale → push → re-probe with `--refresh` → re-lock with `--refresh` → build from OUR lock → `nix flake check` → deploy → post-deploy). It is currently scattered across bullets; it should be one block in AGENTS.md.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Branch-ref conversion of the `discordsync` input | `flake.nix` `github:LarsArtmann/DiscordSync?ref=master`; lock `original.ref` = `master` via python sorted-keys round-trip (1-line diff, `locked` byte-identical) |
| 2 | Upstream vendorHash staleness FIXED | DiscordSync `df1a2bf0`: `vendorHash.nix` → `sha256-Zu9kdtqb6Af4OjWGNrYySHOgr69PqKEzGLmAnnSv7aw=`; `flake.nix` cqrs-lint hash → `sha256-02HmHaC+cYkdn2xPtX6v9YDgu7XQejslulnmFyNS8HY=`; pushed `c3494bd6..df1a2bf0` |
| 3 | SystemNix lock lifted to real master HEAD | `nix flake lock --update-input discordsync --refresh` → `df1a2bf070f0148a1d7892932aa247cf9446b491` |
| 4 | Upstream probe green at HEAD | `nix build github:LarsArtmann/DiscordSync/master#default.goModules --refresh` → store path at `discordsync-df1a2bf` |
| 5 | Package builds from OUR lock | `f.inputs.discordsync.packages.x86_64-linux.default` → `/nix/store/xbd8n0r2…-discordsync-df1a2bf` |
| 6 | `nix flake check --no-build` | "all checks passed" (evo-x2 eval accepts the +131-commit upstream module) |
| 7 | Upstream delta screen (interface level) | `nixos-module.nix` diff is purely ADDITIVE: new `tursoSyncMonthlyBudgetBytes` option (int, default 2500000000 = 2.5 GB/month Turso sync breaker) + one env mapping |
| 8 | Doctrine updates | `flake.nix` comment rewritten to post-fix doctrine; AGENTS.md pin-policy bullet flipped to FIXED+LIFTED; NAR-hash/daemon-cache bullet amended with the **`--refresh` no-sudo bypass** (live-verified) |
| 9 | Tree state | Clean; all session artifacts daemon-committed (HEAD era `517c48b0`) |

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| 1 | **THE DEPLOY** | Pre-deploy: 62 passed / 19 warnings / 0 failed — blocked ONLY by the memory-pressure gate (IO PSI some avg10 60% + disk busy 102%, real storm from parallel sessions building `.#installer-standin-initrd` + linkers + golangci-lint + 10-core zstd). My PSI-wait retry chain had a field-parsing bug (gated avg60, not avg10) and was KILLED before misfiring; no deploy fired (profile still `781-link`, zero switch processes). **Deployed discordsync binary is still c0604e4-era.** |
| 2 | `packages.cqrs-lint` upstream | FOD hash fixed (green), but the package build still fails AFTER the FOD: `updates to go.mod needed` — go-cqrs-lite `cmd/cqrs-lint` module inconsistency with DiscordSync's locked input pins. Diagnosed, NOT fixed (needs tidy/tag upstream or a package drop — owner decision). SystemNix does not consume it. |
| 3 | Post-deploy verification | Not run (blocked on deploy): post-deploy-check, deployed-rev probe, Gatus checks, `TURSO_SYNC_MONTHLY_BUDGET_BYTES` in the rendered unit, `/run/current-system` anchoring. |
| 4 | Content review of the +131 commits | Stat-level only (206 files, +10,057/−2,686; turso-sync views, monitoring/alerts.yml +43, web churn). Not reviewed line-by-line. |
| 5 | The 2026-09-16 pin-portfolio | The now-proven probe→fix→lift protocol applies to the 6 remaining "pins KEPT" repos (signoz-src, signoz-collector-src, library-policy, go-auto-upgrade, overview, projects-management-automation) — none touched this session. |

## c) NOT STARTED

1. Upstream repair of go-cqrs-lite `cmd/cqrs-lint` (tidy → tag → re-pin in DiscordSync → re-derive hash) — or dropping `packages.cqrs-lint` from DiscordSync's flake.
2. VendorHash drift prevention upstream: DiscordSync's flake already ships a "Fast vendorHash drift check" (`flake.nix:463`) — it was never wired to anything that runs (CI presumably dead in the hosted-minutes class, unverified). Stale hashes will recur otherwise.
3. DiscordSync CI status verification + documentation in its repo AGENTS.md (CV precedent).
4. `docs/services/discordsync.md` runbook covering the new breaker option and its interplay with our local-first Turso stance (nothing written beyond AGENTS.md/flake.nix this session).
5. VM-test coverage for the discordsync module incl. the new option (existence of a discordsync VM test not even checked).

## d) TOTALLY FUCKED UP

Honest assessment: **nothing is irreversibly broken.** The lock state, upstream state, and docs are all consistent and verified. Near-misses that belong on record:

1. **The buggy PSI-wait loop** — it would have (a) gated on the wrong metric (avg60 instead of avg10) and (b) silently skipped the deploy with a message naming the wrong metric. Caught and killed during this report. If I had reported "deploy retry armed" and walked away, the upgrade would have silently never shipped.
2. **The heuristic upstream commit message** — the fix rationale is not in DiscordSync's history (`df1a2bf0` says "auto-commit 2 changed file(s)"). Rewriting pushed master is worse; accepted and documented here.
3. **Two near-races with parallel sessions** — AGENTS.md was modified under me mid-edit (daemon recommit; recovered), and the deploy would have raced the parallel session's build storm had the gate not caught it. The gate did its job.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy-completion doctrine:** a gated deploy must have an attended owner or an alerting completion path — never a background loop that can expire silently (and whose instrumentation must itself be verified before arming).
2. **One-runbook bump protocol:** write the full probe→fix→lift→verify→deploy chain as a single AGENTS.md block instead of scattered bullets (this session executed it correctly only by stitching bullets).
3. **No-sudo paths first:** check the tool's banned-command list before privileged attempts; `--refresh` is now the documented cache-bust (AGENTS.md amended).
4. **Commit-message authorship under daemon races:** when the daemon commits my staged work, `--amend` BEFORE pushing restores authorship; add that to the daemon-race rules.
5. **Gate instrumentation testing:** my retry wrapper's parsing bug is exactly the `comm`/collation class of "the tool around the gate lies". A tiny selftest for PSI parsers would prevent recurrence.
6. **Upstream drift prevention:** stale vendorHashes are a RECURRING class (CV, DiscordSync, 6 more repos). The probe step should be automated (flake check or scheduled probe) rather than discovered at bump time.

## f) NEXT (ordered, session-grounded)

**Deploy completion**
1. Retry `nix run .#deploy` in a genuinely quiet window (PSI some avg10 < 20% — verify by reading `/proc/pressure/io` directly; today's storm was driven by parallel sessions' `installer-standin-initrd` builds; two sibling status files from 14:16/14:24 show they were deploy-blocked too).
2. `nix run .#post-deploy-check` after the switch.
3. Verify the deployed binary is `discordsync-df1a2bf` (unit ExecStart store path / `go version -m`).
4. Verify Gatus DiscordSync checks go green and stay green through one sync cycle.
5. Confirm `TURSO_SYNC_MONTHLY_BUDGET_BYTES=2500000000` rendered in the deployed unit (new env).
6. Anchoring check: `/run/current-system` matches the numbered profile (exit-4 skip class) — profile was `781-link` pre-deploy.
7. Decide explicit `tursoSyncMonthlyBudgetBytes` for our config vs the 2.5 GB default (interacts with the local-first Turso stance).

**Upstream DiscordSync follow-ups**
8. Content-review the +131 commits (capture pipeline, DLQ, backfill changes) before/after go-live; daemon messages hide everything.
9. Map the upstream `monitoring/alerts.yml` additions (+43 lines) to our Gatus/SigNoz surfaces where relevant.
10. Review the turso-sync dashboard view changes (`internal/web/turso_sync_view_test.go` +116) for UI impact.
11. Fix `packages.cqrs-lint`: tidy go-cqrs-lite `cmd/cqrs-lint`, tag, re-pin, re-derive hash — OR drop the package (owner decision; it feeds DiscordSync's verifyScript health-score gate).
12. Verify DiscordSync CI status; document dead-CI in its AGENTS.md (CV precedent) if confirmed.
13. Wire the existing "Fast vendorHash drift check" (`flake.nix:463`) into CI or a scheduled probe so stale hashes cannot recur silently.

**Pin portfolio (protocol now proven)**
14. Apply probe→fix→lift to the 6 remaining broken pins: library-policy, go-auto-upgrade, overview, projects-management-automation (hash-refresh chores); signoz-src + signoz-collector-src (migration-review — schema-migrator runs on service start).
15. go-taskqueue: flip the interim `git+file` input to `github:…?ref=master` once the missing rev is pushed (CI is dark for it).

**Docs & doctrine**
16. Consolidate the bump runbook into one AGENTS.md block (see e2).
17. Sweep AGENTS.md for remaining `--update-input` mentions missing the `--refresh` caveat.
18. Write `docs/services/discordsync.md` (breaker semantics, local-first interplay, bump discipline incl. `--refresh`).
19. Check for a discordsync VM test; add coverage for the new option if a test module exists.
20. TODO_LIST entries: cqrs-lint upstream task, pin-portfolio sweep, vendorHash-drift prevention.

**Watch-items noticed this session**
21. Next upstream daemon churn on DiscordSync master will move HEAD past `df1a2bf0` — probe with `--refresh` before any future bump (hash may go stale again, same class).
22. The lock's internal templ-components subtree moved (`c35bdf5` → `8a046c4`) with the lift — root input is separate; spot-verify no other consumer pinned the old subtree.
23. `tq-redesign` manual process (PID 229432) still flagged by deploy.sh's double-pool guard — complete the cutover per `docs/services/tq.md`.
24. Parallel-session build storms keep blocking deploys fleet-wide (3 status files today) — consider routing their builds through `heavy-job` (workload-admission) per doctrine.
25. Consider a lightweight scheduled upstream-probe check here (staleness discovered at bump time is the recurring pain).

*(Stopped at 25 — the remaining items would be padding; the above is the complete set this session actually surfaced.)*

## g) Questions I cannot figure out myself

1. **Deploy timing:** should I retry the deploy as soon as PSI drains (even if the parallel session's build is still running), or hold until the parallel `installer-standin-initrd` work is fully finished? I can observe pressure, not intent — and three sessions were deploy-blocked today, so "quiet" may not arrive soon.
2. **cqrs-lint disposition:** fix it properly in go-cqrs-lite (tidy → tag → re-pin → re-hash; it feeds DiscordSync's verifyScript health-score gate) or drop `packages.cqrs-lint` from DiscordSync's flake entirely?
3. **Upstream history hygiene:** leave `df1a2bf0`'s heuristic daemon message as-is (my vote — rewriting pushed master is worse), or add a follow-up DiscordSync commit documenting the fix rationale in its repo docs/AGENTS.md?

---

## Appendix: session artifact map

| Artifact | Location |
|---|---|
| Input URL (branch-ref governed) | `flake.nix` `discordsync` block (comment carries the full post-fix doctrine) |
| Lock node | `flake.lock` `nodes.discordsync`: `original.ref=master`, `locked.rev=df1a2bf0…` |
| Upstream fix commit | LarsArtmann/DiscordSync `df1a2bf0` (pushed `c3494bd6..df1a2bf0`, 2026-09-17 ~13:1x) |
| AGENTS.md updates | Pin-policy bullet (DiscordSync parenthetical) + NAR-hash/daemon-cache bullet (`--refresh` bypass) |
| Killed retry chain | Background shell 028 (PSI-wait loop with the avg60-parsing bug) — terminated 14:0x, deploy never fired |
| Pre-deploy evidence | 62 passed / 19 warnings / 0 failed; blocked at memory-pressure gate |
