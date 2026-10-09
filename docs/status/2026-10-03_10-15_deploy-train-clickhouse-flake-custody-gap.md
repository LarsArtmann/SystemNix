# Status: Deploy Train — Clickhouse Flake, Custody Gap, Harvest Landed

**Date:** 2026-10-03 10:15 | **Session start:** ~05:20 (resumed from the 05:11 deploy-unblock report)
**Mission:** resume the Paperless AI-Max Wave 1 execution → collect the final toplevel enumeration (073) → `nix run .#deploy` (paperless-gpt go-live + paperless-ngx 3.1.3→3.2.1 ride) → post-deploy battery → surface sync.

**Live system:** UNCHANGED — **gen 813 (2026-10-01 07:27, `r6fcay8x…`), paperless-ngx 3.1.3 live, ZERO deploys this session.** The deploy remains blocked by exactly ONE store build: `clickhouse-26.8.7.19-lts` (fresh nixpkgs c59305b; cache.nixos.org does NOT carry it — verified `nix path-info --store https://cache.nixos.org` → "not valid", so from-source is legitimate). A NEW enumeration attempt (PID 769592, log `/tmp/toplevel-myverdict3.log`) was launched by a parallel session at 10:12 — clickhouse restarts from zero (~2h+), and the flake that killed attempt #2 is UNDIAGNOSED (§d.1).

---

## §a) FULLY DONE (this session, verified)

1. **Mission resume + todo reconciliation** — the stale todo list was rebuilt first (per the handoff's explicit instruction); statuses: B53 + flake-check re-verify → completed, deploy-unblock → in_progress.
2. **073 verdict collected: INTERRUPTED, not green.** `/tmp/topfinal2.log` ends `error: interrupted by the user` with NO `TOP2_EXIT=` marker — the 05:11 handoff's "RUNNING, zero errors" was already dead on arrival (session-end kill). This session did NOT inherit a green verdict; it inherited an unfinished one.
3. **Parallel-train discovery + non-duplication** — found the authoritative re-run already in flight (PID 742598, `--keep-going --no-link`, log `/tmp/toplevel-myverdict.log`, started 05:15 by a parallel session). Monitored instead of launching a duplicate (3+ concurrent `nix build` invocations from other sessions were already contending).
4. **Deploy-independent harvest LANDED + committed (`aa39239b`)**, pre-commit green (docs-only path):
   - `docs/agents/nix-flakes.md`: the **bare `nix flake lock` ban** (2026-10-03's 241-line blanket re-lock incident) into the Infra-follows Rules list.
   - `docs/agents/go-ecosystem.md`: the **two-surface vendorHash shim sweep** (mkLarsPackages/overlays AND direct `inputs.X.packages` consumers; the `rg "inputs\.<tool>\.packages" modules/ platforms/ systems/` sweep command; null-safe darwin shim pattern; fakeHash-learn doctrine; `--keep-going` enumeration as the canonical got-hash source).
5. **Deploy mechanics verified read-only:** deploy.sh's flock concurrent-deploy guard (T13, `/tmp/.systemnix-deploy.lock`, line 43-53) makes racing deploys fail fast; the paperless-gpt convergence block exists (deploy.sh:698-705, token re-mint + daemon restart behind `systemctl is-enabled`); `nix run .#pre-deploy-check` runs first inside deploy.sh.
6. **Post-deploy battery surface mapped:** post-deploy-check.sh paperless-gpt legs (lines 579-601: `/api/filter-tag`, loopback-bind guard, token-file ownership); FEATURES.md paperless-gpt row (line 77, 🟡 deploy-pending → flips on verification); CHANGELOG Unreleased section (wave-1 entry exists; deploy-unblock session entry owed); TODO_LIST rows 226-231+603 and docs/todo/services.md rows 18-25, pipeline.md rows — all located with exact line numbers for the post-deploy sync pass.
7. **Baseline captured for post-deploy comparison:** `/run/current-system` = `r6fcay8x…` (gen 813), live paperless = 3.1.3 via `/run/current-system/sw`, 3.2.1 store path `f071gk6g…` present, paperless-gpt absent (pre-go-live).
8. **PSI-gated the deploy decision** — refused to deploy under io PSI some avg10=70.66 (05:25 reading; deploy.sh's pressure gate would likely have tripped anyway). Correct per the stability doctrine: enumeration-finish → IO settle → deploy.

## §b) PARTIALLY DONE

1. **Deploy unblock — the toplevel enumeration.** Attempt #2 (742598, 05:15→07:24, 2h09m) FAILED: clickhouse died at `error: opening directory "…/build/source/build/external/googleapis/src/googleapis_download/google/cloud/scheduler/v1": No such file or directory` (log line 62, `MY_EXIT=1`). Everything EXCEPT clickhouse in the toplevel closure is built or cached (0 errors before it; unit drvs, activate, etc. all enumerated clean). Attempt #3 (769592) launched 10:12 by a parallel session — clickhouse compiles from scratch AGAIN (third full compile: attempt #1 killed 05:21 as "interrupted", #2 died 07:24 googleapis, #3 now). ETA past the googleapis step ≈ 12:20-12:45 IF it doesn't flake the same way.
2. **Surface sync** — targets fully mapped (§a.6) but ZERO edits landed: every row's final wording depends on the deploy outcome. Also owed from the handoff: the CHANGELOG entry for the whole shim-fleet unblock session (13 got-hashes, todo-list-ai drop, xrt C++20, ltrace doCheck, SC2029 exclusion).

## §c) NOT STARTED (unchanged from the 05:11 handoff, all gated on the deploy)

1. **THE DEPLOY** (`nix run .#deploy`) — carries paperless-gpt go-live, 3.1.3→3.2.1 ride, A11 env vars, A12/A17 collector+Gatus, A13 reranker pruning, crm module go-live, bank-sync-paperless live verify, + every commit since gen 813.
2. **Post-deploy battery** — post-deploy-check.sh (incl. new paperless-gpt legs); paperless-gpt liveness `http://127.0.0.1:8106/api/filter-tag`; `/run/paperless-gpt/env` 0400+owner; `paperless-gpt-failed` tag in live paperless; 3.2.1 live-path check; collector `.prom` tick (all 6 metrics); gatus "llama.cpp Reranker" ABSENT from endpoints; bank-sync-paperless both units result=success.
3. **CHANGELOG / FEATURES / TODO surface updates** (the §b.2 mapping, executed).

## §d) TOTALLY FUCKED UP (nothing hidden)

1. **The clickhouse googleapis failure is UNDIAGNOSED and I watched passively.** I polled clang counts and load for 76+ minutes (05:16→06:32) and then again 06:32→(suspended) — at NO point did I investigate whether clickhouse's `googleapis_download` ExternalProject step is a known flake class (cmake glob race), whether `--keep-failed` + manual inspection was warranted, or whether a retry even addresses it. Attempt #2 then died on EXACTLY that step at 07:24, and attempt #3 (10:12) is now exposed to the SAME undiagnosed failure with nobody assigned to diagnose it. Two-plus hours of pure wait time were available for this research; I spent them on progress polling.
2. **Custody gap 07:24→10:11 (~2h47m).** The mission-critical train (742598) failed at 07:24 unwitnessed — my poll job (023) was a 50-minute loop that ended ~07:25, and the session sat suspended until the user's 10:11 status demand. No detached watcher, no setsid build, no handoff note. If attempt #3's owner-session dies the way mine's predecessor did, the build dies with it — this exact class killed attempts #1 (05:21 "interrupted by the user") and nearly #2.
3. **First background watcher was a false positive** — `while kill -0 <pid>` reported "EXITED" while 742598 demonstrably ran (race in the background shell's process check). Corrected to `tail --pid` on retry, but the primitive should have been right the first time; a naive reader of that output would have started a duplicate build.
4. **Index-lock patience miscalibrated** — the first commit retry loop (10×4s) lost to the daemon's long index write (383KB lock file held >40s); needed a 150s wait-for-lock-clearance loop. On this repo, git retries need MINUTES of patience, not seconds (matches the handoff's warning; I under-applied it).

## §e) WHAT WE SHOULD IMPROVE

1. **Wait time is research time.** Any build >30 min with a novel from-source component (clickhouse on fresh nixpkgs) should trigger a PARALLEL risk assessment of its known failure modes while it compiles — not after it fails. The googleapis step cost the mission a 2-hour rebuild cycle that 10 minutes of proactive research might have prevented or converted into a pre-planned fix (retry vs `-K` diagnosis vs drv-level patch).
2. **Custody must survive sessions.** Enumeration builds that gate a deploy should run detached (`setsid nohup nix build … &`) with a log + exit-echo convention, so a session suspension or death doesn't restart a 2-hour compile from zero. Three full clickhouse compiles in 5 hours is pure waste (attempt #1 interrupted, #2 googleapis, #3 running).
3. **One canonical train owner.** Four parallel sessions have now independently built/monitored the same toplevel (checks.lint/build/format + two toplevel runs + a bare `nix build .`). The flock guard protects the DEPLOY, but nothing protects the BUILD from duplicated multi-hour work. The `--keep-going` enumeration doctrine should name a single owner (or a detached shared build) per deploy window.
4. **Status-verdict hygiene on resume:** "RUNNING with zero errors" from a prior session is not evidence of anything until the process is confirmed alive — check `ps` before trusting any inherited in-flight claim (this session's first act generalized correctly, but the lesson belongs in the resume protocol).

## §f) Next (session-derived, ranked)

1. **Diagnose the googleapis failure class** (nixpkgs clickhouse 26.8.x, `external/googleapis` ExternalProject, "opening directory … scheduler/v1: No such file or directory") — flake or systematic; check nixpkgs issue tracker + the clickhouse cmake external project; decide retry vs `--keep-failed` inspection vs drv patch. HARRVESTED → TODO_LIST + docs/todo/services.md.
2. **Watch attempt #3 (769592, `/tmp/toplevel-myverdict3.log`) THROUGH the googleapis window (~12:00-12:45)** — with a detached watcher this time; on same-way death, execute item 1's verdict immediately.
3. **On green enumeration:** verify log has 0 errors + exit 0 → check io PSI avg10 < gate (~50) → **deploy** `nix run .#deploy` from the agent shell; if the internal sudo demands a password (fails fast at deploy.sh:10), hand to the user's ssh terminal — their 03:44 failure reason is fully fixed.
4. **Post-deploy battery** (wave-1 report §f items 1-5): post-deploy-check.sh green incl. paperless-gpt legs; :8106 `/api/filter-tag`; `/run/paperless-gpt/env` 0400 + owner; `paperless-gpt-failed` tag exists live; 3.2.1 referenced by `/run/current-system`; collector `.prom` with all 6 metrics; gatus reranker check ABSENT; bank-sync-paperless units result=success.
5. **Surface sync** (handoff step 5, mapping done): TODO_LIST rows (shim fleet drop conditions, todo-list-ai drop + upstream-fix obligation, xrt C++20, ltrace doCheck, SC2029 exclusion, B53 done, deploy outcome, 3.2.x-ride row → done); docs/todo/services.md + pipeline.md siblings; CHANGELOG deploy-unblock entry + deploy outcome; FEATURES.md paperless-gpt row → ✅.
6. **Restate the 3 owner questions in the final answer** (§g below — they remain unanswered from the 05:11 report).
7. _(from item 1, if systematic)_ land the clickhouse fix in-repo (patch/override) and re-enumerate.
8. Deliberately NOT harvested (in-flight mission steps owned by this deploy session, already implicit in the staged rows per the wave-1 report's self-harvest note): items 2-6. No NEW untracked follow-ups exist beyond item 1.

## §g) Questions I can NOT figure out myself (restated from 05:11, still unanswered)

1. **Deploy authority:** if the enumeration goes green while you're away, do you want the agent session to fire `nix run .#deploy` itself (passwordless sudo unproven from the agent shell — it fails fast+clean if a password is needed), or should the deploy ALWAYS run from your ssh terminal? (Moot for this report — clickhouse is still building.)
2. **todo-list-ai upstream fix:** OK for it to stay off PATH (`todo-list-ai = null` shim, documented) until you push an upstream lockfile regen (bun.lock under nixpkgs bun 1.4.2 + depsHash `sha256-dOQ37ka5bHY2H9PBsGIox7lyUP8O92Ju5FV/iz1qe+k=`), and separately finish-or-revert the half-swept effect@^4.0.0 bump sitting on upstream master (29edab6 — foreign in-flight work, deliberately not completed by the agent)?
3. **A3 Stage-0 execution path + German ack:** run `sudo scripts/paperless-ai-stage0-eval.sh` yourself (~10-15 min) after the deploy, or should the next session wire it as a deploy-carried root-gated oneshot (side effect: mints a token on the live host)? And: confirm German as the AI suggestion output language (A11 landed `PAPERLESS_AI_LLM_OUTPUT_LANGUAGE=German` — rides this deploy).

---

_Self-harvest note: §f.1 landed in TODO_LIST.md + docs/todo/services.md at authoring time; §f.2-6 are this mission's remaining steps (deliberately not separately harvested — same standing rationale as the 00-33 wave report). Evidence: `/tmp/toplevel-myverdict.log` (attempt #2, MY_EXIT=1 line 63), `/tmp/topfinal2.log` (073, interrupted), deploy log dir last entry 03:57 (pre-session), gen list verified `system-813-link` → `r6fcay8x…`._

---

## CORRECTION (in-place, 2026-10-03 ~11:55, deploy-train session): §d.1/§f.1 premise RESOLVED — there never was a googleapis flake

The "UNDIAGNOSED googleapis ExternalProject failure" premise of §d.1/§e.1/§f.1 is **falsified**. Root cause (journal-correlated to the second): the LOCAL `nix-build-cleanup.service` reaped LIVE build sandboxes — its `find /nix/var/nix/builds -maxdepth 1 -name 'nix-*' -mmin +60 -exec rm -rf` matched by the TOP-LEVEL dir mtime, which freezes at sandbox creation while builds churn deep inside. Timer fires at 03:20:50, 07:24:13 (= attempt #2's death second), 11:25:43 (= attempt #3's death — twin error `setting permissions on <sandbox>: ENOENT`; #3 never reached any googleapis step). The 03:20 fire also explains the user's 03:29/03:56 deploy failures. The googleapis-shaped error was nix's own `SysError("opening directory %s")` (readDirectoryIgnoringInodes) racing the vanished sandbox — found by grepping every build tool for the string (zero hits), then locating the format in nix's source, then correlating `journalctl -u nix-build-cleanup` with both deaths.

**Post-state:** fix landed in `platforms/nixos/system/scheduled-tasks.nix` (orphan = embedded builder PID dead AND no tree writes in the last hour; mock-tested 3-case; daemon-swept into an amend-contended heuristic commit), live with the NEXT deploy. Surfaces corrected: this report (§d.1/§f.1), TODO_LIST.md queue row → [x], docs/todo/services.md row → [x], docs/gotchas-archive.md (new entry), CHANGELOG Unreleased/Fixed. §f.1 is DONE; §f.7 (in-repo clickhouse patch) is moot — no clickhouse defect exists. Until the fix deploys, the OLD killer still fires every ~4h (next ~15:27, then ~19:29); toplevel attempt #4 (this session, detached setsid, `--cores 32`, log `/tmp/toplevel-attempt4.log`) is staggered behind the parallel session's 11:28 attempt as a self-healing fallback.
