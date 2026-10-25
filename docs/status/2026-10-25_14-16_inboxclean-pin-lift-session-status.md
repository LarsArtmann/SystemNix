# Session status: inboxclean pin lift (nixpkgs-unstable follow)

**Date:** 2026-10-25 14:16 CET · **Instance:** Crush (glm-5.3-flash) · **Scope:** THIS session only (owner directive: "inboxclean should never be pinned") + what was noticed in passing — no unrelated research, per instruction.
**Format note:** user explicitly demanded `.md` at `docs/status/` — explicit override of the status-report skill's HTML canonical, honored per skill contract.

**HEAD trail this session:** `56f10814` → `c50ba89c` → `9576bc43` → `d2759f5c` (my four core surfaces) → `15d8849e` → `ae7cf5ca` (daemon sweeps; parallel session active throughout on memory-emergency-guard io-gate work — their batches attributed in `git log`, narratives in their 12:52/13:19/13:58 reports).

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **LIFT condition verified UNMET live** before acting: pinned nixpkgs (`fe13242`) evals `go = 1.26.8`, `go_1_27 = 1.27.2`, `go_1_28` attribute ABSENT — the written LIFT ("root ships go ≥ 1.27.3") could not be satisfied by waiting | eval transcripts in session; `nix eval` rc=0 |
| a2 | **Upstream state established first-hand**: master HEAD `c63bf289` (go.mod `go 1.27.3`, daemon push 08:43Z), upstream flake wires `goPkg = unfreePkgs.go_1_27` from the FOLLOWED nixpkgs (no self-built toolchain), upstream's own lock nixpkgs = `3ec63636` | `gh api` pulls, upstream flake.nix lines 103–160 |
| a3 | **Pin dropped on all FOUR surfaces**: flake.nix URL → `?ref=refs/heads/master` (pre-pin form), pin-audit allowlist row removed + header rewritten hermes-only, lock updated, expected-locks registry regenerated (3-line diff exactly: seed note, inboxclean → `c63bf289`, + `nixpkgs-unstable` → `3ec63636`) | daemon batch `d2759f5cd` (lock+registry TOGETHER); `git show --stat` verified = exactly my 4 files |
| a4 | **Toolchain decoupled from the root pin**: new FLOATING input `nixpkgs-unstable` (nixos-unstable branch, allowed by pin-audit without allowlist row) feeding `inboxclean.inputs.nixpkgs`; locked rev `3ec63636` ships **go_1_27 = 1.27.3** (eval-verified on the locked rev, not the branch tip) | lock node + eval |
| a5 | **FOD proof: inboxclean builds rc=0 under go 1.27.3** with upstream's committed vendorHash UNCHANGED — because upstream's own lock resolves the same `3ec63636` (context byte-alignment) | `/nix/store/a0aghv75zhgq…-inboxclean-c63bf28`, `/tmp/ic-fod.log` rc=0 |
| a6 | **Toplevel proof rc=0** (`--keep-going --no-link`, root pin intact in the drv name): inboxclean-web/sync units + fish-completions + package closure all realized; zero errors in-log. Run under sustained io storm (some avg60 ~58%) — verdict unaffected, only slower | `~/.cache/lockfloat/inboxclean-lift-toplevel-proof.log` |
| a7 | **Eval gates green**: pin-audit trace shows inboxclean GONE from deliberate pins (no stale-row throw); `nix flake check --no-build` rc=0, zero error lines | `/tmp/flakecheck.log` |
| a8 | **Resolution graph proven via `nix flake metadata`**: `inboxclean/nixpkgs → nixpkgs-unstable (3ec63636)`, art-dupl rides along; the three same-named lock nodes are NOT a split brain — bare node = templ's own nested input (@ `a7868a72`, upstream's lock), `_3` = templ-cli's | metadata tree output in session |
| a9 | **Docs landed**: CHANGELOG entry (top), go-ecosystem.md pattern paragraph ("Follower toolchain-skew floor…"), status report `2026-10-25_14-05_…status.md`, paired queue rows (TODO_LIST + pipeline.md) for [watch] collapse + [ready] hermes lift | all committed by daemon by `ae7cf5ca` |
| a10 | **Queue discipline held**: check-todo-system.sh after my row appends → zero NEW pairing/harvest WARNs (41 drift / 124 unharvested are pre-existing, gate-hardness pending) | checker output in session |
| a11 | **Formatting verified canonical** (post-hoc gap, closed): `nix fmt -- flake.nix lib/flake-input-pin-audit.nix flake/expected-locks.nix` → 0 changed | `/tmp/fmt.log` |
| a12 | **Concurrent-session discipline held**: parallel session's uncommitted `memory-emergency-guard.nix` diffed and flagged before any shared-surface eval; my surfaces disjoint; no rebase/amend of shared history attempted | session log |

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| b1 | **The lift's prod effect** — built and proven, NOT deployed (sudo legs fail from the agent shell; the standing deploy train row owns execution). inboxclean-web is meanwhile live-DOWN (502 since 04:40, pre-existing stop-without-start — existing row in docs/todo/services.md; NOT caused by this session, which touched only inputs) | in-tree, deploy-pending |
| b2 | **Upstream CI confidence** — my "context alignment ⇒ vendorHash valid" claim is empirically proven by OUR build (rc=0) but upstream's OWN CI on `c63bf289` was never checked (assumed, not verified) | HARVESTED at authoring time → TODO_LIST + docs/todo/upstream.md §f.10 |
| b3 | **Hermes-agent same-pattern lift** — identified as the direct beneficiary of the new input (unstable patchelf carries #672), queued [ready] with the wholesale-instance caveat — not executed (scoped to the inboxclean directive) | queued: TODO_LIST + pipeline.md |
| b4 | **The drop condition for `nixpkgs-unstable`** — documented in FOUR surfaces (flake.nix comment ×2, CHANGELOG, pin-audit header, two reports). The canonical home should be ONE (flake.nix); the rest are narrative. Mild split-brain by construction; acceptable per repo convention, flagged in (e) | documented |

## c) NOT STARTED (consciously out of this session's scope)

1. **Deploy** the new lock (owner/privileged terminal; rides the pending train with the 2026-10-20/23 stability batch).
2. **inboxclean-web 502 restart/triage** (pre-existing live outage; blocked on the same privileged terminal + stop-without-start mechanism triage).
3. **hermes-agent lift execution** (b3).
4. **nixpkgs-compat workflow extension** to probe `nixpkgs-unstable` (owner decision on CI minutes — question g2).
5. **Upstream goTarball fix** for InboxClean (question g3; redundant today, durable tomorrow).
6. **Root nixpkgs pin lift** (own gate: green toplevel with aw-core + linux-7.3-modules — untouched, existing row).
7. **cv §g.2** (the exec-3 float proof's remaining blocker — existing row).
8. **Calm-window re-proof** — deliberately skipped: the proof's verdict (rc=0, which-derivations) is not storm-confounded; a re-run adds nothing the deploy build won't do anyway.

## d) TOTALLY FUCKED UP

Nothing landed is broken — every gate green, formatting canonical, tree clean. The honest fuck-up list is about PROCESS:

1. **The 14-05 status report shipped with a mid-thought sentence** ("DEAD ON ARRIVAL … so wait — see §c") and a typo ("nixpkpkgs") because I wrote the report WHILE my fix-branch analysis was still revising itself. Caught both and fixed in place — but a written report is a claim surface; first-write quality control failed. A 30-second re-read before considering any report done would have caught both.
2. **expected-locks splice duplicated two body rows** (`head -25` vs the `{` on line 23) — caught by my own diff before it could matter, but the root cause was not reading the boundary line numbers before splicing a generated file onto a hand-maintained header.
3. **Two background-job rc fumbles**: lost `${PIPESTATUS}` through the job wrapper twice, costing two full cached re-runs just to obtain exit codes. The fix (echo rc into the log file inside the command) was applied only from the third command onward.
4. **The core lock surfaces sit in a heuristic daemon commit** (`d2759f5cd` "auto-commit 4 changed file(s)") — the float procedure's ideal ("the registry's git history is the float audit log") is weakened: the narrative lives in CHANGELOG + reports, but the commit message itself attributes nothing. Amend-forward was impossible (HEAD had moved; rebasing under an active parallel session is the documented edit-loss hazard). Right call under the constraints, missed ideal nonetheless.
5. **Storm-gating was ad-hoc**: I polled PSI three times, never pre-stated an abort/defer threshold, and proceeded on judgment (FOD already cached → eval+link only). It worked; it was not a procedure.

## e) WHAT WE SHOULD IMPROVE

1. **Reports get one re-read before "done"** — both d1 defects were self-visible in 30 seconds.
2. **Background commands self-report rc** into their log file, always (`; echo rc=$? >> log`) — never rely on the wrapper's PIPESTATUS.
3. **Storm gates need pre-declared thresholds** (e.g. "defer toplevel if io some avg60 > X unless the critical FOD is already cached") so the go/no-go is a checked rule, not a mood.
4. **One drop-condition, one home**: the `nixpkgs-unstable` collapse condition should be canonical in flake.nix only; CHANGELOG/pin-audit should reference, not restate.
5. **Formatter check belongs at edit time**, not as a post-hoc gap (`nix fmt -- <paths>` immediately after the last edit; 0-changed this time, but it was luck-adjacent diligence).
6. **Context-alignment claims need their evidence chain spelled**: lock-alignment (fact) + local build-green (proof) + upstream CI (unverified) are three different confidence levels — I initially blurred 1+2 into "validates"; b2 now separates them and the CI leg is harvested.
7. **The expected-locks generator should live in a script** (like prune-done-todos.sh) instead of a header comment one-liner — the splice bug is the second hand-splice incident class waiting to happen.

## f) Up to 50 things to get done next (impact-sorted; disposition honest)

**Harvested at authoring time (this report):** item 10 only (new, session-born, actionable). Items 1–9/11+ were already queued by prior reports or are owner-gated/roadmap — re-harvesting them would duplicate rows (the drift the checker hunts).

| # | Item | Source | Disposition |
|---|------|--------|-------------|
| 1 | Deploy the pending train: new inboxclean lock + 2026-10-20/23 stability batch (IOReadBandwidthMax, tmpfiles OnFailure, MemoryMax raises) | existing TODO rows | owner-gated privileged terminal |
| 2 | inboxclean-web 502 (down since 04:40): privileged restart + stop-without-start triage | docs/todo/services.md row | existing row owns it |
| 3 | hermes-agent pin lift via nixpkgs-unstable follow (patchelf#672; prove IFD + pm-ripgrep/pm-node first) | this session | queued [ready] (14-05 report) |
| 4 | Collapse `nixpkgs-unstable` follow → root when fe13242 lifts with go ≥ 1.27.3 | this session | queued [watch] |
| 5 | Root nixpkgs pin lift: green toplevel w/ aw-core + linux-7.3-modules realized | pin-audit row | existing row |
| 6 | cv §g.2: the ONE remaining float-proof blocker (cv go-modules) | exec-3 report §g.2 | existing row |
| 7 | signoz-src pin lift: patches apply unchanged or sonic ≥ 1.15 | pin-audit row | existing row |
| 8 | Upstream InboxClean goTarball decision (durable toolchain hermeticity) | question g3 | owner decision |
| 9 | nixpkgs-compat coverage for `nixpkgs-unstable` (second override-input leg) | question g2 | owner decision |
| 10 | **Verify upstream InboxClean CI green for `c63bf289`** (go.mod daemon push; if red → goTarball fix upstream) | this session | **HARVESTED now** → TODO_LIST + upstream.md |
| 11 | First `--apply` of scripts/prune-done-todos.sh at next prune cycle | existing row | queued |
| 12 | Pairing recheck pipeline.md + services.md (41 WARNs) after discordsync session closes | existing row | queued |
| 13 | §f unharvested-report backlog sweep (122 WARN) — batch by domain | existing row | queued |
| 14 | stray-unit-audit warning: "systemd.services entries nothing ever starts" (seen in my flake-check run) — enumerate + adjudicate | noticed this session | roadmap (needs enumeration leg) |
| 15 | catalog: 21 integration subdomains without catalog entries (warning names them: cache, banksync, history, daily, …) — derived-DNS loss surface | noticed this session | roadmap |
| 16 | stalwart 0.15.5 → 0.16 migration path (eval warning says incompatible today) | noticed this session | roadmap |
| 17 | zfs.latestCompatibleLinuxPackages deprecation + forceImportRoot=false recommendation | noticed this session | roadmap |
| 18 | llama-vlm post-deploy soak-test reminder (eval warning) | noticed this session | rides its deploy |
| 19 | templ + templ-cli nested `nixpkgs-unstable` @ `a7868a72` (2026-10-03, go 1.27.2-era) — upstream lock staleness; templ builds green today; watch for the next templ floor bump | noticed this session (metadata tree) | watch, no row |
| 20 | inboxclean-canary scrape_errors dead-code fix (fail-open) | existing [ready] row | queued |
| 21 | `nix run .#inboxclean-paperless` flake app wiring | existing [ready] row | queued |
| 22 | Wrapper unit-env fixture test (7 vars + PATH line) | existing [ready] row | queued |
| 23 | InboxClean storm-driver legs: identify `/` poller, IOWeight defense-in-depth, review §3/§7 amendment | existing rows | queued |
| 24 | InboxClean per-account `auth_expired` gatus check [decision] | existing row | owner decision |
| 25 | InboxClean→CRM feed go-live scope [decision] | existing row | owner decision |
| 26 | Google OAuth "In production" confirmation (7-day token bomb recurrence) | existing [blocked:user] row | owner action |
| 27 | Baseline /health latency pre-pickup (cached-health quantified before/after) | existing [ready] row | queued |
| 28 | Cached /health pickup into SystemNix after upstream push (2ee3860) | existing [blocked:push] row | blocked:push |
| 29 | Sync-run budget + resumable corpus-backup self-heal upstream | existing [blocked:push] row | blocked:push |
| 30 | gmail-verdict-cache regression test upstream | existing [ready] row | queued |
| 31 | Nested art-dupl consumers FOD check (discordsync/inboxclean pre-fix revs) | existing [ready] row | queued |
| 32 | expected-locks generator → script with dry-run (see e7) | this session (e7) | candidate new row — deliberately NOT harvested yet: one-line ask needs the script shape agreed first |
| 33 | Weekly flake-update float will move `nixpkgs-unstable` + inboxclean together — verify both re-lock cleanly at the next PR | this session (a3/a4) | rides the standing weekly process; no row |
| 34 | Post-deploy: readlink anchor discipline + post-deploy-check.sh §14/§15/§16/§17/§19 legs on the train from item 1 | standing doctrine | rides item 1 |
| 35 | SigNoz/monitoring check that inboxclean-web unit start is ALERTED (the 04:40 stop-without-start had no page until a human looked) | noticed via b1 context | adjacent to existing monitoring rows; roadmap |
| 36 | `diskoConfigurations` unknown-flake-output warning (benign today; silence or declare) | noticed this session | cosmetic |
| 37 | `system`→`stdenv.hostPlatform.system` rename warning sweep | noticed this session | cosmetic |
| 38 | Re-adjudicate 41 drift WARNs' gate hardness (CHECK_TODO_PAIRING=strict) | existing row | queued |
| 39 | docs-health ANNOTATE pass on the 14-05 + this report once hermes/collapse land | convention | rides items 3/4 |
| 40 | Consider `nixpkgs-unstable` ALSO feeding overview (same follower class) IF its go floor ever outruns root — pre-position, don't pre-wire | this session | roadmap |

(40 items: 10–11 substantive new observations, the rest pointers into existing queue state — honest "up to 50" without padding.)

## g) Questions I cannot figure out myself

1. **Deploy intent for the lifted lock:** inboxclean-web is live-DOWN (502 since 04:40) and my lift is built-but-undeployed. Should the next privileged-terminal deploy carry the new inboxclean lock immediately (also clearing the 2026-10-20/23 stability batch), or do you want the 04:40 stop-without-start mechanism triaged FIRST so the deploy doesn't restart into the same trap?
2. **CI budget for the new input:** should the daily nixpkgs-compat workflow gain a second leg probing `nixpkgs-unstable` (early warning when unstable's go moves again), accepting extra CI minutes — or is "the inboxclean FOD is the compatibility test" acceptable as the permanent stance?
3. **Upstream strategy:** do you want the goTarball toolchain fix pushed to upstream InboxClean anyway (hermetic vs ANY follower nixpkgs, browser-history/PMA pattern — also the answer if upstream CI turns out red on `c63bf289`), or is the SystemNix-side follow-swap the intended permanent answer?

---

*Evidence paths: toplevel `~/.cache/lockfloat/inboxclean-lift-toplevel-proof.log` · FOD `/tmp/ic-fod.log` · flake check `/tmp/flakecheck.log` · fmt `/tmp/fmt.log` · prior report `docs/status/2026-10-25_14-05_inboxclean-pin-lift-nixpkgs-unstable-follow-status.md` (§e.4 filled, §b.2/typo corrected post-write — see d1).*
