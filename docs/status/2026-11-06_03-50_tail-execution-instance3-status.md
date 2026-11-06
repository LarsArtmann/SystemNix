# Float-Gate-Green Tail Execution — Instance 3 (pareto plan T17–T21 + T26 legs)

**Session:** 2026-11-06 02:44–03:5x CET · resume instance 3 of `docs/planning/2026-11-05_22-30_SUPERB-go-cache-unblock-cutover-pareto-plan.md` (tombstone `2d7188fe9`) · tree shared with 13+ parallel crush sessions · io PSI 54–78 the whole window.

## §a FULLY DONE

1. **T17 — ec-hub 54G refill row CLOSED** (storage.md:181, both-surface tick via TODO_LIST pointer n/a — library-only row). Attribution (source-code evidence, refill not live so io-forensics N/A): `/mnt/buildcache/ec-hub` = the **eventcatalog-hub repo's own scripts** — `build.sh` (`EC_STATE_ROOT` default `/mnt/buildcache/ec-hub`, per-run `run-<pid>` dirs already self-reaping >2d, shared gomod/gocache) + `verify-site.sh` (`site-verify` build tree, NEVER cleaned — the unbounded accumulator). NOT the CI runner (separate bounded `ci-runner-cache`). Bound landed **upstream** (`fix it upstream` directive class): eventcatalog-hub `ff1ae20` — verify-site.sh now reaps a fully-stale OUT tree (zero files newer than 2d, mtime-gated = concurrency-safe, explicit `--out` exempt, DRY_RUN exits first); shellcheck clean + script self-test green + predicate sandbox-tested (stale reaped / fresh kept); CHANGELOG entry. Live at close: mount 51%, residue 1.5G dormant since 11-02 → next verify run auto-reaps.
2. **T18 — trash closing loop + observability landed** (rows storage.md:131 + :148 ticked): `platforms/common/programs/trash-prune.nix` (weekly `trash-empty 30d` user timer, Persistent, before/after bytes journaled — answers the realized-reclaim row at every fire; home Trash ONLY, `/data/.Trash-1000` stays owner-gated) + `scripts/trash-size-metrics.sh` + `modules/nixos/services/trash-metrics.nix` (hourly system collector, `trash_size_bytes{path}` + freshness stamp, bun-memory-watchdog pattern; selftest green) + **pre-deploy-check §20** (WARN-only ≥10 GiB home Trash) + runbook `docs/services/trash-metrics.md`. Age-expiry WINS over blanket-empty (the row's open question). Live at wiring: home Trash 8.1G (the 55G partially burned down already).
3. **T19 — tmp-cleanup foreign-residue class CLOSED** (services.md:285 + TODO_LIST.md:860 ticked): mechanism found is NOT the suspected user class — the unit runs as **root**, but `harden{}` defaults `CapabilityBoundingSet = ""` (lib/systemd.nix:17) and capability-less root cannot unlink inside foreign-owned non-writable dirs; the script's `rm … 2>/dev/null || true` suppressed every EACCES silently (the 2026-10-01 100%-tmpfs class). Fix: unit carries `CAP_DAC_OVERRIDE CAP_FOWNER` (bun-memory-watchdog precedent) + failed removals log journal WARNs naming the entry. Design decision recorded: NO per-class TTL/exclusion — generic 4h rule + active-descendant check covers foreign residue once caps land. Rides next deploy.
4. **T21 — both skill notes landed.** 21.1: how-to-golang trigger over-match scoped (SKILLS `2cb16fc` — description now excludes box-level build/cache infra; "Go performance" = app/library choices). 21.2: buildflow `crush://` load retry REPRODUCED then root-caused **NOT-DO**: buildflow is a USER skill at `~/.agents/skills/buildflow` (loads fine); the builtin namespace correctly 404s a non-builtin; no config carries the wrong path (rg-verified) — the reference was the 19-50 report's assumption. All 3 carried §f items annotated NOT-DO + the 22-27 item-34 struck with the SKILLS hash (annotate.go prose, dry-run first).
5. **µ20.1 — BuildFlow cache-name root-cause CLOSED, no upstream fix** (upstream.md:95 ticked): env_guard used the STANDARD `go-build` across its entire history (`git log -S` clean); only `gocache` is BuildFlow's (preflight-gate.sh:62 / e2e-snapshot.sh:172) and that non-standard name is DELIBERATE — the standard name is SystemNix's HM out-of-store symlink into the mount, so a standard fallback would write through a dead symlink (gotcha #129). `gobuild`/`gomod` = no tracked source → agent-session export class (2026-11-03-proven). Wrong "BuildFlow's cross-repo fallback names" attribution comments corrected in reap-names.sh + buildcache.nix (comment-only).
6. **T26.1 + 26.3-partial — dual-counter recount pinned** (pipeline.md:395 updated): check-todo-system = **191 unharvested §f-bearing reports**; docs-gates `freshness --audit-all` = **12,628 unharvested open items / 2,516 replayed reports** (03:2x, both same-night). Strategy reframe recorded: 12.6k items is not batch-harvestable report-by-report — marker-close/annotate sweeps + archiving, harvest only verify-against-code survivors. 26.1 (tonight's reports) was already rowed at authoring; default freshness gate rc=0.
7. **doc-counts catch honored:** the new trash-metrics module tripped `checks.doc-counts` at commit time (README 146 vs truth 147 — the gate working as designed on THIS session's own change); README lineage re-stamped 146→147 with the embedded re-derive command.

## §b PARTIALLY DONE

1. **T20** — 20.1 closed (above); **20.2 ghostty io_uring filing stays owner-[decision]** (venue undecided, verify-before-filing gate); **20.3 go-taskqueue sqlite-forbid design note deferred** — the row's own probe-first gate (agent-contract surface in go-taskqueue) wasn't run and a half-probed design note is worse than none.
2. **T26** — recount + reframe landed; the first bounded month-sweep batch deliberately NOT started (03:3x, PSI 70+, harvest-rigor rule: no rushed unverified rows).

## §c NOT STARTED (gated)

1. **T11 benchmark** — PSI-gated all window (avg10 63.8 → 71.7 at 03:34, worsening; needs <20 ×3min).
2. **T15/T16/T27** — blocked on T3 (the deploy, owner gate D2). Live state at 03:44: gen-983 == current-system (anchored), Phase B never ran (no go-* mounts; USB buildcache still live), no deploy since 23:15.

## §d TOTALLY FUCKED UP

1. **The `rg -r` replace-trap hook caught me TWICE more this session** (`-rn`, `-rln` muscle-typo) after the AGENTS.md rule was already twice-struck — the hook is the only reason these didn't mangle my readings. Discipline: type `-n`, full stop.
2. The first T19 commit aborted at doc-counts because I added a module (T18) without re-stamping README — the exact class the gate exists for. Cost: one commit cycle.

## §e WHAT WE SHOULD IMPROVE

1. The docs-gates audit-all replay takes >15 min under storm (first two attempts unbounded; only the `timeout 900` form completed) — consider a `--audit-since` window or precomputed index if the corpus keeps growing.
2. `check-todo-system.sh` (191 reports) and docs-gates (12,628 items) measure DIFFERENT units of the same backlog — one line in each tool's output naming the other's counter would prevent future unit confusion in rows.

## §f Up to 50 things we should get done next

*(self-harvested at authoring — every obligation landed in an existing surface this session; no new rows minted)*

1. ~~Deploy D2 carries T18+T19 config~~ — deliberately not harvested as a new row: the plan's own T3/D2 owner gate owns it (plan line 52 + tombstone).
2. ~~Live-verify the verify-site reap on the next verify run~~ — deliberately not harvested: the mechanism self-verifies (journal `reaping stale site-verify tree` line on next run; the 1.5G dormant tree is the built-in fixture).
3. ~~trash-metrics gatus alert~~ — deliberately deferred per runbook doctrine (same as bun-memory-watchdog at introduction); revisit only on a burn-down regression.

**Commits this session:** `2d7188fe9` (tombstone), `ff1ae20` (eventcatalog-hub), `156bebdb6`/`679115732` (daemon sweeps of my in-flight files — contents verified exclusively mine), `a77c9bcf5` (T18), `425cc9440` (daemon: T21 annotations), `2cb16fc` (SKILLS), T19+README commit (this report's §a.3/.7), pipeline.md:395 + plan annotation (daemon-swept or final commit).
