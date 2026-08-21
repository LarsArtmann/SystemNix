# Browser-History 4.5-min Startup: Root Cause, Fix, Release — Status Report

**Date:** 2026-08-16 04:32 CEST
**Session arc:** "Research Browser-history issues properly!" — diagnose the ~4.5-min
CPU-bound pre-bind startup burn, root-cause it, fix it, release it, propagate it.
**Stopped at the user's request** before the SystemNix deploy step.

---

## Executive Summary

The ~4.5-minute silent CPU burn before browser-history binds :8087 on every
restart is **fully root-caused and fixed** — but **not yet deployed to
production**.

Root cause (two layers, both proven):

1. browser-history wires `usermgmt.NewService` **without `CheckpointStore`** →
   6 usermgmt projections replay the **entire event journal on every restart**
   (deliberate choice documented in `api/server.go:345` — avoids the
   in-memory-read-model hydration trap).
2. go-cqrs-lite's `JournalReader.ReadFrom` paginated the drain with a
   **self-JOIN cursor query** (`events e JOIN events c ON c.id = ?`) that
   defeats `idx_events_occurred_at` in SQLite — `EXPLAIN QUERY PLAN` shows
   `MULTI-INDEX OR` + `USE TEMP B-TREE FOR ORDER BY` per batch → **O(N²/batch)
   drain**.

Fix: keyset pagination (cursor point-lookup + timestamp-range scan) in
go-cqrs-lite `storage/sql`. **~285x faster** (measured: 200k-event journal
drain 62.9s → 0.22s). Released as **`storage/v4.7.0`**, tagged and pushed,
proxy-verified. browser-history bumped to it locally, full test suite green —
**commit blocked at the last step** by a pre-commit hook that builds the
sibling session's mid-edit (temporarily broken) go-cqrs-lite working tree via
go.work replaces.

---

## a) What is FULLY DONE

### Evidence gathering (journal + live metrics)

- Journal (2 observed restarts): silent gap **"OAuth2 providers configured" →
  "server starting"** = 4m19s (03:26:41.6→03:31:00.4) and 4m08s
  (03:35:34.5→03:39:42.2). Both at ~101% CPU.
- systemd accounting: **4min27s CPU over 12min wall**, only **9.2M read / 4K
  written disk**, 345.8M memory peak → CPU-bound, NOT IO-bound (journal was in
  page cache) → not event-store disk replay cost.
- Live `/metrics` (fetched via fetch tool): `process_cpu_seconds_total` 252.81,
  **50.6M heap allocations** since start → the burn is the replay allocation
  storm, server otherwise idle.
- Key discriminator: browser-history's own `replayEvents` (single `ReadAll` +
  checkpoint skip) runs in **0.7s** between two adjacent log lines — a full
  journal scan is cheap; the usermgmt drain is ~370x more expensive per event.

### Root cause (proven, not hypothesized)

- Code path: `api/server.go` → `usermgmt.NewService` (cqrs-htmx
  `service_core.go:282` → `es_setup.go:284` → `startProjectionHost` with
  `block=true`) → 6 projection workers each drain the journal from checkpoint
  zero (memory checkpoint store: `es_projection_setup.go:89-92`) via
  `ReadFrom(batch=100)` → `storage/sql/journal_reader.go` self-JOIN query.
- Empirical proof (production schema, 200k synthetic events, batch=100):
  - self-JOIN: **62.93s full drain (31.5 ms/batch)** — `SEARCH c (PK)`,
    `MULTI-INDEX OR`, `USE TEMP B-TREE FOR ORDER BY` (re-sorts the remaining
    tail per batch → quadratic)
  - keyset: **0.22s (0.1 ms/batch)** — `SEARCH e USING INDEX
    idx_events_occurred_at (occurred_at>?)` → **~285x**
- Production journal size not directly measurable (no sudo in sandbox;
  `/var/lib/browser-history` is root 0700); estimated ~200-300k events from
  timing × 6 workers — consistent with observed 4.5 min.

### Fix implementation (go-cqrs-lite, module `storage/v4`)

- NEW `storage/sql/keyset.go`: `ResolveCursorTimestamp` (PK point lookup,
  driver-native value passed back verbatim — no format round-trip) +
  `KeysetPositionQuery` (`WHERE e.ts >= ? AND (e.ts > ? OR e.id > ?)` — the
  `>=` prefix enables the index range scan; tie-break disjunction filters
  inside the scanned range).
- `JournalReader.ReadFrom` afterID path rewritten to the two-step keyset.
  Dangling cursor (pruned row) **preserves the old contract** (zero rows, no
  error) instead of silently replaying from start.
- `eventstore.ReadStreamFrom` (streaming variant, same self-JOIN) rewritten
  identically; new `emptySQLEventIterator` for the dangling-cursor case.
- Tests added:
  - `storage/sqlite_journal_readfrom_test.go`: tie-group equivalence
    (occurred_at ties + newest-first insertion so rowid order can't mask an
    ORDER BY bug), multi-cursor batch drains == canonical suffix, dangling
    cursor, **EXPLAIN QUERY PLAN regression pin** (must use
    idx_events_occurred_at; must NOT contain `MULTI-INDEX OR` or
    `TEMP B-TREE FOR ORDER BY`), full-drain benchmark.
  - `storage/pg_integration_readfrom_test.go`: real-Postgres keyset
    equivalence + dangling cursor (proves $1..$4 placeholder numbering and
    time.Time round-trip).
  - sqlmock tests updated from old self-JOIN query text to the two-step
    sequence.
- Verification: storage module suite green; projectionhost suite green;
  Postgres integration green (via `nix run .#integration-pg`, real PG);
  benchmark: **5k events full drain = 28.8ms** (5.7µs/event; extrapolated
  250k × 6 workers ≈ 8.6s vs current ~4.5min). One `#verify` failure
  (`TestProbeEngine_RealPostgres_LiveRTT`, RTT EWMA=0) proven flake — 5/5 PASS
  in isolation; no code-path overlap.
- Committed tree verified green in an **isolated worktree** (`/tmp/gcl-verify`
  at the release commit) because the live working tree is mid-edit by the
  sibling session (see §d).

### Release (supply side)

- **`storage/v4.7.0`** tagged (annotated) at `f30183e1b`, pushed to origin.
  Contents: keyset fix + sibling's wave-3 storage work that landed in the same
  commit range (batch INSERT chunking, view batch shuttle, pebble/bbolt
  deserialize fast path). MINOR bump (new exported API:
  `MaxParametersForDialect`, `BatchSize`, `ResolveCursorTimestamp`,
  `KeysetPositionQuery`, ...).
- `storage/go.mod` at tag: `go 1.26.5`, **zero replace directives** (the known
  1.26.6 toolchain trap avoided; safe for nixpkgs 1.26.5 builds).
- CHANGELOG.md: added Unreleased "Fixed — journal keyset pagination" section +
  cut `## [storage/v4.7.0] — 2026-08-16` summary section; committed alone via
  pathspec (`f30183e1b`).
- Proxy verified: `go list -m -versions` serves v4.7.0. browser-history's
  `go get` consumed it successfully (equivalent to the clean-dir Phase 6.2
  check).
- No cascade: v4.7.0's sibling-module requires are all ≤ browser-history's
  existing pins.

### Consumer bump (browser-history)

- `api/go.mod`: `storage/v4 v4.6.0 → v4.7.0` (via `go get`, not manual edit) +
  tidy. go.sum updated.
- Full workspace test suite (`go test ./...`): **green, exit 0**.
- Stale NOTE in `api/server.go` (claimed "full replay ~2-3 min, deferred
  CheckpointStore") updated to document the real root cause and the new cost
  (single-digit seconds).
- Change set staged: `api/go.mod`, `api/go.sum`, `api/server.go`.

### Carried F3 gap (partial)

- `go test ./...` in **browser-history**: DONE this session (green ×2).
- file-and-image-renamer + go-cqrs-lite full-suite: still pending (see §f).

---

## b) What is PARTIALLY DONE

- **browser-history commit: STAGED BUT BLOCKED.** The pre-commit hook builds
  the whole go.work tree, which includes `../go-cqrs-lite` via workspace
  replaces — and the sibling session's **in-flight, uncommitted** edits there
  (`projectionhost/worker.go`, `scenario/dsl.go`) are currently mid-edit
  syntax-broken. Hook output: `pre-commit: BUILD FAILED — commit rejected`.
  Options: (1) retry when the sibling tree heals, (2) `--no-verify` with
  disclosure (precedent: prior session did this for the toolchain-gap hook
  failure). My staged content itself is test-verified against **published**
  v4.7.0.
- **go-cqrs-lite master branch not pushed.** The release commit `f30183e1b` is
  on origin only via the tag ref; `origin/master` may lag (sibling's daemon
  will likely push it with their next sweep).
- **Daemon attribution muddle (disclosed):** my uncommitted go-cqrs-lite fix
  files were **swept by the auto-commit daemon into the sibling's commit
  `fde8f9444`** ("wave-3 ... keyset ReadFrom") while I was still verifying.
  Byte-identical to my working tree (verified: files show unmodified vs the
  commit), tests green — net effect correct, but my fix landed inside their
  wave-3 commit message.
- Alert-spam fix verification (carried f-8/9): untouched this session; still
  unknown whether Discord alerts fired during 03:26–03:39 browser-history
  downtime.

---

## c) What is NOT STARTED

1. ~~**SystemNix flake input bump** for browser-history~~ **done** — deployed rev `4e7604d` (live since the 08-16 deploys).
2. ~~**Deploy** (`nix run .#deploy`) — production is still running the slow binary.~~ **done** — the v4.7.0-era binary is live (the 17-09 session's report confirms the deployed input performs OIDC discovery at startup — a v4.7.0+ behavior).
3. ~~**Post-deploy startup measurement** from journal~~ **done** — startup fast; the timing proof is recorded in the repo's own session docs (async drain + readiness gate).
4. `scripts/post-deploy-check.sh` browser-history poll-with-timeout fix
   (sibling has uncommitted edits in that file — must re-read and coordinate
   first).
5. `deploy.sh` removal of the explicit browser-history double-restart
   (with fast startup this becomes low-urgency polish).
6. SystemNix AGENTS.md / TODO_LIST updates for this finding.
7. Monitor365 gating in post-deploy-check (TODO 51) — separate work, not
   started.
8. Consumers sweep: check whether DiscordSync / Monitor365 / other
   LarsArtmann services drain journals through `ReadFrom` and want the
   storage/v4.7.0 bump.

---

## d) What I TOTALLY FUCKED UP (honest accounting)

1. **Didn't check the shared repo's git log/status before large independent
   work.** go-cqrs-lite had an ACTIVE sibling session + auto-commit daemon. I
   implemented the entire fix before discovering (mid-verify) that their
   wave-3 commit had swept mine. Cost: attribution muddle + verification
   confusion. Lesson: in shared repos, read `git log -5` + `git status` +
   recent `docs/status/` FIRST, and commit immediately after green tests.
2. **Ran `nix run .#verify` against the live tree while the sibling was
   editing.** First run: one flake (fine). Second run: failed on their
   mid-edit syntax errors → I briefly treated it as a possible own-goal before
   diffing authorship. Wasted a cycle; the isolated-worktree re-verification
   was the correct first move.
3. **Sloppy worktree seeding:** my initial `cp` dumped stray file copies into
   `/tmp/gcl-verify/storage/` root (package clash) — two cleanup round trips.
4. **Test file needed 2 compile-fix iterations** (unused variable;
   `*testing.T` vs `testing.TB` on the eventtest helper; EXPLAIN result has 4
   columns not 3).
5. **Near-miss on a false verification claim:** I first stated the
   browser-history suite ran "against the fixed code" — it had actually
   resolved go-cqrs-lite via go.work replaces (local tree). Caught it while
   investigating the hook failure; re-verified after the published-version
   bump. The final claim ("green against published v4.7.0") is accurate.
6. Left the browser-history commit **staged and uncommitted** at session end
   (blocked, but also: I should have retried the hook once more or decided
   --no-verify explicitly rather than stopping between states).

---

## e) What Could Have Been Done Better / Differently

- **Query-plan verification FIRST.** The EXPLAIN QUERY PLAN reproduction
  (5-minute Python harness) settled in seconds what I'd spent significant
  static-reading time hypothesizing (checkpoint store? hydration? per-event
  projection cost?). For any "why is this SQL slow" question, EXPLAIN before
  code-archaeology.
- **The "0.7s vs 4.5min on the same journal" discriminator** was the single
  most valuable observation — it eliminated the entire "event store too big /
  replay inherently expensive" hypothesis family in one step. Collect
  side-by-side timings of adjacent code paths early.
- **Commit cadence in daemon-swept repos:** green tests → commit instantly.
  Every additional verification minute is a window for the daemon to swallow
  the work into someone else's commit.
- **Hooks that build the whole go.work tree** make every commit hostage to
  every sibling's working tree. Worth proposing (upstream, both repos): scope
  pre-commit builds to staged modules, or add a GOWORK=off escape hatch.
- **Q3 (old) is now evidence-answered:** cqrs-htmx already has `AsyncStartup`
  - `ProjectionReadinessCheck` (bind-early + gate reads) — but with replay at
    single-digit seconds, **keeping the blocking read-your-writes startup is the
    right call**; no stale-read window, no semantics change. The remaining
    long-term optimization is `CheckpointStore` + `HydrateFromSQL` in cqrs-htmx
    (makes restarts O(delta) instead of O(journal)) — documented as future work,
    not needed now.
- **Regression-proofing:** the EXPLAIN QUERY PLAN pin test turns "the plan
  regressed to a temp-B-tree sort" into a loud CI failure instead of a
  4.5-minute production burn discovered months later.

---

## f) NEXT 50 THINGS (rough order)

1. Retry the browser-history commit (hook likely passes once the sibling's
   go-cqrs-lite tree heals); escalate to `--no-verify` + disclosure only if
   blocked for long.
2. Push browser-history master.
3. SystemNix: bump `browser-history` flake input rev to the new commit.
4. SystemNix: vendorHash refresh cycle (`vendorHash = ""` → build → paste
   `got:`).
5. `nix flake check --no-build` in SystemNix.
6. `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (eval
   gate).
7. Deploy: `nix run .#deploy`.
8. Measure post-deploy browser-history startup from journal (`journalctl -u
   browser-history` — expect "server starting" within seconds of "OAuth2
   providers configured").
9. `nix run .#post-deploy-check` — full smoke.
10. Verify (carried f-8/9): did Discord alerts fire/resolve for the 03:26–03:39
    browser-history downtime?
11. Verify Gatus endpoints all green post-deploy.
12. Clean scratch: `rm -rf /tmp/bh-repro` (200k-event SQLite DB in tmpfs ≈ RAM
    waste until reboot).
13. `git worktree remove /tmp/gcl-verify` (release-verification worktree).
14. Push go-cqrs-lite master (release commit currently reachable only via the
    tag).
15. Trigger pkg.go.dev docs fetch for `storage/v4@v4.7.0`.
16. Fix `scripts/post-deploy-check.sh` browser-history check → poll-with-timeout
    on `/health` (RE-READ the sibling's uncommitted edits in that file first).
17. Remove `deploy.sh` explicit browser-history restart (double-restart).
18. Gate monitor365 probes on `services.monitor365-server.enable` in
    post-deploy-check (TODO 51).
19. Identify the residual WARN in post-deploy-check (I/O pressure 81% vs
    quickshell journal error).
20. Update SystemNix AGENTS.md browser-history section: keyset root cause +
    storage/v4.7.0 requirement.
21. Update SystemNix TODO_LIST.md (mark this item; add CheckpointStore future
    work).
22. Commit SystemNix working tree cleanly (mine vs sibling's — pathspec;
    carried from prior session).
23. Sweep consumers: grep LarsArtmann repos for `JournalReader`/`ReadFrom`
    batch-drain usage; bump any service doing full replays (DiscordSync?
    Monitor365?) to storage/v4.7.0.
24. cqrs-htmx: add `HydrateFromSQL` (enables CheckpointStore for in-memory
    read models) — future upstream work.
25. browser-history: wire `CheckpointStore` once HydrateFromSQL exists
    (restarts become O(delta)).
26. Reconsider `AsyncStartup` + readiness gating only if the journal grows so
    large that even keyset replay (>30s?) hurts deploys.
27. DuckDB dialect: verify keyset query shape (untested dialect).
28. MySQL/MariaDB integration test for ReadFrom keyset
    (`nix run .#integration-mysql-vm`).
29. Turso connector: verify keyset path (shares SQLite dialect).
30. Confirm bbolt/pebble `ReadFrom` paths have no analogous per-batch rescan
    (different code family; quick audit).
31. Confirm metaengine `JournalReadFrom` (separate cursor impl) has no
    self-JOIN pattern.
32. go-cqrs-lite: full `nix run .#verify` once the sibling's wave lands (my
    worktree verification covered storage/projectionhost/scenario only).
33. `go test ./...` in file-and-image-renamer (last carried F3 gap).
34. Check `TestProbeEngine_RealPostgres_LiveRTT` flake history — maybe needs a
    min-measurement floor (0s EWMA on loaded machines).
35. Consider raising `projectionhost` default batch size (100) for drain-heavy
    consumers — 0.1ms/batch makes this low-priority.
36. Add the full-drain benchmark to a CI bench job (regression guard beyond
    the EXPLAIN pin).
37. browser-history: expose a projection-drain duration metric/log line (the
    silent gap made diagnosis harder than it should be).
38. browser-history agent: check whether the agent's oneshot health-gate still
    times out during (now short) server warmup — may be simplifiable.
39. Review sibling's landed `66e78231` alert-spam fixes end-to-end (deployed
    unverified at 03:26).
40. monitor365 restoration: start with the empty-journal mystery
    (`journalctl -u monitor365-server`).
41. Partition surgery (carried Q1): on authorization — btrbk freshness check →
    p9 delete + p6 grow → `btrfs filesystem resize max /`.
42. Redundant `@cache-home`/`@go`/`@npm`/`@cargo` automount removal (TODO_LIST).
43. `sudo rmdir /rust-cache` leftover mountpoint (with Q1).
44. HARVEST this + prior status reports into TODO_LIST/ROADMAP (docs-health
    skill; carried 4 sessions).
45. Check go-codec dirty-tree/GOTOOLCHAIN signal (repo was mid-upgrade).
46. Re-run `scripts/report-goexperiment-gaps.sh` follow-up (21 satellite
    repos).
47. buildcache btrfs+zstd conversion maintenance window (deferred).
48. Consider a Gatus/browser-history startup-duration alert (only if 37 lands).
49. Codify in SystemNix CONTRIBUTING: "EXPLAIN QUERY PLAN before accepting any
    batched SQL pagination" (prevention layer).
50. Coordinate with sibling session on shared go-cqrs-lite release flow
    (daemon sweeps + wave commits) — agree a commit protocol.

---

## g) 3 QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **(Carried Q1 — partition surgery, unchanged):** Authorize deleting
   `nvme0n1p9` (98G, empty, unmounted) and growing the root BTRFS partition p6
   into the freed space — now, or in a maintenance window with a fresh btrbk
   snapshot? Irreversible on a 92%-full production root; needs your call plus
   p6/p9 adjacency confirmation before executing.
2. **browser-history commit mechanics:** the pre-commit hook fails on the
   SIBLING's in-flight broken go-cqrs-lite tree (via go.work), not on my
   staged, test-verified content. Retry-until-healed (my default), or
   `--no-verify` with disclosure now to unblock the deploy chain?
3. **Deploy sequencing (carried Q2):** once browser-history is committed —
   deploy the perf fix immediately as its own deploy, or batch with the
   alert-verification + monitor365 work? Immediate = production stops burning
   4.5 min per restart and per deploy window; batching = fewer deploy cycles
   but the fix (and its false-FAIL smoke window) stays live until then.

---

### Key references

- Fix: `go-cqrs-lite` `storage/sql/keyset.go`, `journal_reader.go`,
  `eventstore/event_store_stream.go`; release tag **`storage/v4.7.0`** @
  `f30183e1b` (fix bytes swept into `fde8f9444` by the daemon — byte-identical).
- Tests: `storage/sqlite_journal_readfrom_test.go` (equivalence/dangling/
  EXPLAIN pin/benchmark), `storage/pg_integration_readfrom_test.go`.
- Consumer: `browser-history` `api/go.mod` (v4.7.0), `api/server.go` NOTE.
- Diagnosis evidence: journal 03:26–03:41 window; `/metrics`
  (process_cpu_seconds_total 252.81, 50.6M allocs); Python EXPLAIN repro
  (62.93s → 0.22s on 200k events).

---

## Resolution (2026-08-17, docs-health pass)

Release chain completed: browser-history committed/pushed/tagged past v0.5.0, input bumped to `4e7604d`, deployed — startup is seconds (b-section blockers cleared). c/f verdicts: c.4/c.5 → TODO_LIST P3 (/health poll + double-restart removal; low urgency now); c.6 done (AGENTS updated with the replay root-cause); c.7 done (22-00 SKIP-gating); c.8 → monitor365 half moot, DiscordSync half untracked; f.1-9 done (commit/push/bump/deploy/measure/smoke/verify); f.10-11 done (probe alerts verified 06-38); f.12-13 moot (scratch gone via reboots); f.14-15 done (master pushed; pkg.go.dev); f.16-17 → P3; f.18 → P3; f.19 → P3 (residual WARNs); f.20-21 done (AGENTS/TODO); f.22 done; f.23 → untracked (monitor365 half moot); f.24-25 → untracked future upstream work (pain resolved by async startup); f.26-39 → untracked upstream/benchmark polish, monitor365 items moot; f.40 moot; f.41-43 → TODO_LIST P2 (partition batch); f.44 done (this harvest); f.45-50 → untracked/moot. g.1 → standing P2 partition item; g.2 resolved (commit landed); g.3 resolved by events. Archived as resolution-complete.
