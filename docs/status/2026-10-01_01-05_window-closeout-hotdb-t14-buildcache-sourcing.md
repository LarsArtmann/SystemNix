# Window Closeout — hot-db T14 review fixes, buildcache fallback convergence, reap single-sourcing

**Date:** 2026-10-01 01:05 CEST · **Window:** 2026-09-30 ~10:35 → 2026-10-01 00:59
**Queue:** SystemNix · **Done-prompt task:** `000001a0f466956bfcfc4a4de8fe00000000`
**Format note:** the status-report skill's canonical format is a styled HTML dashboard; the dispatch explicitly requires a Markdown file at a `docs/status/*.md` path with sections a)–h), so Markdown is used here. One-off override, not propagated to the skill.
**Method:** each task's closeout report was read FIRST and its claims spot-verified against the tree (code greps, script executions, git show) before being repeated here. Nothing below is taken from the task list alone.

---

## a) FULLY DONE (verified)

1. **T-task status pass on the Phase-2 hot-db plan doc** (`51431058`, report `2026-09-30_14-12_task-…4f7e0f76a8.md`). All 24 rows of the plan's T-table carry a `Status (2026-09-30)` column; the queue-named mapping (T3/T4/T6/T7/T8/T14 done; T5/T9–T13/T15 pending) recorded verbatim, every other row derived from artifacts (scripts, modules, tests verified to exist). Both queue surfaces (TODO_LIST line + `docs/todo/storage.md` row 39) closed together. The report's own T13 wrong-by-omission was self-caught and fixed in-commit (the vehicle's all-cow=true decision supersedes the plan's no-`+C` gatus design).
2. **T14 review-fix #1 — dead-collector phantom-green gap closed** (`65e93b80`, report `2026-09-30_15-18_task-…5e67f808f9.md`). VERIFIED IN TREE: `modules/nixos/services/hot-db.nix:379` wires `inherit onFailure` on `hot-db-metrics` (→ `notify-failure@%n.service` Discord paging) and `:438` adds it to `services.system-health.extraMonitoredServices` behind the standalone-import `options ?` guard. The module + Gatus comments and the parent report §b1 were corrected to the honest coverage split (anchored checks see metric ABSENCE only = never-ran; collector DEATH = unit-state alerting). Gates: fmt clean, `nix flake check --no-build --all-systems` green.
3. **T14 review-fix #2 — VM test asserts the failure transition** (`f2edc387`, report `2026-09-30_15-29_task-…8f9b8b00.md`). VERIFIED IN TREE: `tests/test-hot-db.nix:181-191` re-runs the collector after the entry unmount and asserts `hot_db_entry_mounted{name="testdb"} 0` (the actual Gatus alert trigger) + `hot_db_scrape_errors 0`, while deliberately keeping `hot_tier_mounted 1` (only the entry mount is removed — the reviewer's optional tier-flips-to-0 reading was corrected, not transcribed). The full VM test was BUILT and RUN green, not just eval'd.
4. **Review-fix #3 — anchored assertion-count command** (`db15905c`, report `2026-09-30_15-40_task-…3b6076e7.md`). The wrong count command (bare `grep -c 'ok "'` = 23, over-counting the helper body) was replaced by the anchored form (verified live = 22 call sites) on all three surfaces: TODO_LIST fixture row, `docs/todo/storage.md` coverage row, and the 12-54 source report §e1 (SUPERSEDED marker closing the earlier "could not be reworded" loop). No test-script change, exactly as the finding scoped.
5. **buildcache-init provisions the three fallback targets** (`af9b3ef2`, report `2026-10-01_00-11_task-…e17821ae.md`). VERIFIED IN TREE: `modules/nixos/services/buildcache.nix:66-70` adds `pnpm-cache`, `pnpm-state`, `cargo/registry` to `buildcacheDirs` with the why-comment; the rendered init script eval contains all three paths; `nix flake check --no-build` green. Post-recovery, `buildcache-usb-recovery` step 5 now heals the dangling HM symlinks immediately instead of leaving them ENOENT until the next deploy.
6. **Env-less cache reap inventories single-sourced** (`0fdbf2d7`, report `2026-10-01_00-46_task-…d20862cf.md`). VERIFIED IN TREE: `scripts/lib/buildcache-reap-names.sh` holds the two canonical lists (7 cache dirs + 2 home dirs); `lib/buildcache-cache-names.nix` parses it with an eval throw on missing/malformed assignments; deploy.sh sources it (array conversion, shellcheck-clean); `buildcache-usb-recovery` step 2.5 and the home.nix activation block interpolate the parsed lists; the home.nix activation reap widened from 3 to the full 9 paths. Functional verification (rendered script built from its drv, parser probed, deploy.sh split exercised, `--all-systems` check green) recorded in the closeout; the two stale "kept in sync" comments were replaced.
7. **Caddy shallow-merge un-blocked the pre-commit** (`f1e703c5`, landed mid-window by a parallel stream). VERIFIED: `modules/nixos/services/caddy.nix` now uses `lib.mkMerge` at both sites (580, 671) and the repo-wide scan runs `199 files scanned, fail=0`. NOTE the scanner's own SELFTEST still fails (see d2) — the repo-wide pass and the selftest failure are independent surfaces.
8. **Queue loop closed on both surfaces for every task** — spot-checked: the buildcache-init item ticked with close-out (TODO_LIST:25), reap single-sourcing item ticked + library row appended (51d990a6 harvests its three follow-ups: parity assertion, das-check convergence, stale-phrase sweep — TODO_LIST:27-29), T-task item ticked on both surfaces.

## b) PARTIALLY DONE

1. **The buildcache-init fix is UNDEPLOYED** — eval + checks green, but no `nix run .#deploy` (human-owned) and no live replug proof. Until deployed, a mount recovery still dangles the three symlinks until the next deploy.
2. **The reap single-sourcing deliberately excluded two surfaces** — `das-link-recovery-check.sh`'s diagnostic lists (deliberate non-reap subset; convergence queued as TODO_LIST:28) and the home.nix `mkOutOfStoreSymlink` definitions (reap-set ⊇ symlink-set parity assertion queued as TODO_LIST:27).
3. **T14 runtime confirmation is deploy-gated** — the OnFailure + extraMonitoredServices wiring is eval-proven only; TODO_LIST:511 already carries the live-gatus/timer legs on the deployed system-804 generation (which predates `65e93b80`).
4. **The fixture count fix is a citation patch, not the structural fix** — the helper-rename (`ok()` → `_ok`) remains queued (TODO_LIST:516, sharpened), and the self-verifying count row exists (harvest 15-40 §f2). A future plain-line `ok "…"` assertion would silently drift the anchored count low again.
5. **T14 filesystem half** (autoScrub `/mnt/hot` + btrfs-health loop) stays open in `docs/todo/storage.md` row 41(1) — deliberately split, unchanged by this window.

## c) NOT STARTED (window's orbit skipped)

1. **The five hot-db migration windows** (gatus → dnsblockd → pocket-id → browser-history → discordsync) — all owner sudo windows; no agent-side work remains before them.
2. **Postgres hot-db wave**, T15 full RPO review, T23 Phase-3/4 trigger — pending the first waves.
3. **Offsite Borg go-live, /data EIO repair, NetBird setup key, Resend verification confirmation, SigNoz GCP re-arm** — standing owner-gated items, untouched (correctly — not this window's scope).
4. **Nothing from the window's own task scope was left unstarted.**

## d) TOTALLY FUCKED UP

1. **The pre-commit gate was DARK repo-wide during the window — FIXED at closeout by a parallel session.** `bash scripts/audit-serviceconfig-merge.sh --selftest` failed on a clean tree when reproduced early this closeout (~01:00): the scanner flagged its own sanctioned-form fixture `serviceConfig = mkDefault (env "https://example.test" // { })`. While this report was being written, a parallel session hardened the audit to v2 (bounded continuation-line check + per-occurrence URL-scheme stripping + 4-fixture selftest) and the selftest now PASSES on a clean tree (re-verified ~01:12). The window still shipped three `--no-verify` commits against the red gate, and the fix was UNCOMMITTED at closeout time (parallel session's working tree). The root cause of the landing-time defect was corrected en route: the v1 regex did NOT miss the caddy shape (both v1 and v2 flag it against `f1e703c5~1`) — it reached master because the daemon commits past a FAILING pre-commit. TODO_LIST row ticked with evidence this pass.
2. **Three pool tasks DEAD-LETTERED tonight on an environmental verify gate** (tq journal, 00:22–00:53, go-taskqueue project): the `vendor-gofmt` signature — `gofmt -l .` flags only GITIGNORED `vendor/` files — killed three tasks identically on retry (`000001a0f4669545…`, `000001a0f46fc0…`, `000001a0f47d78…`), each dead-lettered `[class=permanent]` with "rescue: classify environmental". The gate is structurally wrong for repos with vendored trees (gofmt must skip gitignored paths, e.g. pipe through `git ls-files`). A fourth CV task (`000001a0eebb785f…`) requeued 4× on a "gate also fails at the pre-attempt rev" pre-existing-failure classification. Pool-level: verify-gate hygiene is burning attempts across repos, not just here.
3. **Two count-claim failures in one day on the same fixture** (the 15-40 finding's root): hand-count 21→22, then a wrong command asserted without running (23 vs 22). Both patched citations; the generator (helper shadowing the grep) is still queued. Third instance of the class and it will recur until TODO_LIST:516/519-self-verifying-count land.
4. **Daemon-race footervore continues**: the 15-40 fix landed inside a daemon batch commit that also carried a parallel session's quickshell report + post-deploy-check fix — one footer, two work streams; the parallel session's queue↔git cross-reference is healed only by prose (standing 12-54 §e4 gap, now with another data point).
5. **Daemon-race amends remain the norm, not the exception** — four of five tasks exercised the amend-forward path (one used `reset --soft` squash on two heuristic commits). Policy-compliant every time, but the recurring near-misses (one multiedit silently dropping `onFailure` from an inherit block, caught pre-eval; one 2-of-3 multiedit against the wrong file) show the cost is real.

## e) WHAT WE SHOULD IMPROVE

1. **Fix the verify-gate, not the victims (d2):** the `vendor-gofmt` dead-letter signature should be a gate-side fix — `test -z "$(gofmt -l $(git ls-files '*.go'))"` or `gofmt -l . | grep -vFf <(git ls-files --others --ignored --exclude-standard --directory vendor/)`. Three permanent dead-letters in one night is the most expensive failure mode the queue has.
2. **Land one file per daemon cycle** — every task raced the ~10-min auto-commit daemon; amend-forward worked but blends authorship and repeatedly absorbs foreign footer-less work. Small, fast, single-file commits are the cheapest countermeasure.
3. **Self-testing gates should self-report their drift commit** — the serviceconfig selftest failure named the flagged form but not WHICH change desynced scanner vs fixture; the parallel v2 fix landed without a drift-origin note either. A tiny drift-guard message ("scanner/fixture out of sync since <assert>") would cut the archaeology to zero.
4. **Reviewer findings are converging on reusable invariants** — the dead-collector class is now 3× (forgejo-github-sync, memory-guard, T14); the eval-time lint "every textfile-collector unit must appear in system-health monitoring OR carry onFailure" (queued below) converts the third strike into a mechanical gate instead of review luck.
5. **VM collector tests should assert transitions, not snapshots** — the T14 failure-path finding exposed a systemic happy-path-only shape; generalize to backup-coordination/buildcache-metrics/pool-smart (queued below) and codify the rule in `docs/CONTRIBUTING.md`.
6. **Fixtures/carriers of commands in queue rows must paste `command = N` at queueing time** — codified repeatedly (14-32 §d2, 15-40 §e2) but the queue authoring step still skips it; the cost is a full dispatch cycle each time.

## f) NEXT THINGS (harvest disposition)

Most candidates are ALREADY queued and were NOT re-appended (dedup check performed against all 460 unchecked rows): parity assertion (27), das-check convergence (28), stale-phrase sweep (29), serviceconfig selftest (288), live hot-tier Gatus/timer legs (511), helper-rename (516) + self-verifying count (harvested 15-40), caddy regression case (519), deploy-authority decision (34), hot-db wave sequencing question, crush-hot-db fold question. The following NEW items were appended this pass (7 tasks + 3 questions):

| # | Item | Source |
|---|------|--------|
| 1 | Post-deploy verify `hot-db-metrics` OnFailure + extraMonitoredServices on the live generation | 15-18 §f1 |
| 2 | Fixture test for `buildcache-init` dir provisioning (PATH-stub mkdir/chown per entry) | 00-11 §f4 |
| 3 | `buildcache-metrics` pnpm-cache/pnpm-state size gauges (growth visibility) | 00-11 §f5 |
| 4 | Deploy the buildcache-init fix + post-deploy dir-existence proof (folds with the next deploy window) | 00-11 §f6 |
| 5 | Eval-time lint: textfile-collector units must be in system-health monitoring OR carry onFailure | 15-18 §f2 |
| 6 | Opposing-state assertions in the other collector VM tests (backup-coordination, buildcache-metrics, pool-smart) | 15-29 §f2 |
| 7 | AGENTS.md-adjacent: `hot_db_metrics_fresh` mtime gauge as belt for the wedged-collector residual (watch-listed) | 15-18 §f3 |
| Q1-Q3 | Questions below, appended as BLOCKED items | §g |

**Deliberately not harvested:** the plan-doc status column maintenance (one-time snapshot, 14-12 §e4), ROADMAP-fuel echoes already tracked elsewhere (offsite-borg, /data, llama-rag bisect, CV hold, etc. — all have living rows), and the 00-11 report's items 8-50 (pre-existing backlog echoes; re-appending would mint the duplicate-dispatch class the queue doctrine explicitly bans).

## g) QUESTIONS (only the owner can answer)

1. **Freshness stamp for `hot-db.prom` — wanted, or is unit-state alerting the accepted floor?** Unit-state alerting covers dead/restart-looping collectors; the only uncovered residual is a SLOW-but-completing run (bounded today by TimeoutStartSec 3min, which itself pages as a failure). Is the mtime-based `hot_db_metrics_fresh` gauge worth the wiring, or is the 5-min dormant-tier collector adequately covered? (15-18 §g1)
2. **Footerless daemon-batched commits — accepted healing convention?** Current practice: cite the commit hash in the later closure. Alternative: the queue accepts ticket→commit-range matching instead of footer equality. This decides whether the standing 12-54 §e4 backlog item is a policy change or just more cite-hash bookkeeping. (15-40 §g2)
3. **Should `pnpm-cache`/`pnpm-state` ever be pruned by `buildcache-gc`?** They are provisioned but not pruned (metadata-sized today, unbounded tomorrow). Owner preference: prune weekly (rm + re-provision is trivial) or leave unbounded? (00-11 §g2)

## h) BAND DRIFT (ADR-0015)

**`task.reprioritized` facts in the window: NONE recorded** (`tq facts --type task.reprioritized` → 0 facts; full journal scanned through seq 8476).

Priority movement this window happened through the queue's normal claim ordering, not explicit reprioritization. Two adjacent accountability notes from the same journal (not reprioritizations, but priority-relevant):

- **Three go-taskqueue tasks dead-lettered `[class=permanent]`** (00:22–00:53) on the environmental `vendor-gofmt` gate signature (see d2) — effectively an involuntary priority loss: three backlog items left the runnable pool entirely and now need a `tq dlq --rescue`.
- **One CV task requeued 4×** (00:23–00:58, `000001a0eebb785f…`) on "verify gate dead — pre-existing/environmental (fails at the pre-attempt rev)"; it remains queued, consuming claim slots each cycle until the CV gate is healed or the task is rescued.

---

*Task-Queue-ID: 000001a0f466956bfcfc4a4de8fe00000000*
