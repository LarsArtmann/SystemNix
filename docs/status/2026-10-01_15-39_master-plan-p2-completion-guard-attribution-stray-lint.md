# Status: Master-Plan P2 Completion — Scrub-Staleness Verification Closed a Real Bug, Stray-Unit Lint Shipped, Guard Attribution Batch Landed

Session: 2026-10-01 ~13:45–15:39 CEST (continuation of the 13-41 interrupted session).
Scope: finish P2 #5's verification debt, then P2 #8–#11 in order, then the fifty-todos↔P3 crosswalk. All four P2 items landed and verified; the crosswalk dedupes P3 before any execution.

## a) FULLY DONE

| Item | Verdict | Evidence |
| --- | --- | --- |
| P2 #5 verification debt | CLOSED — verification found + fixed a real bug | binary strings from locked btrfs-progs 7.1 (`/nix/store/78j9xamn…-btrfs-progs-7.1/bin/btrfs`) prove `Scrub started:    %s\n` AND `Scrub resumed:    %s\n` both print at column 0 (no leading tab — `strings` hides non-printables; raw-bytes dump was required). The parser matched only `started:` — a resumed-and-finished fresh scrub would have false-positived `btrfs_scrub_stale=1`. Fixed; rendered script `bash -n` OK; fixture harness run against the REAL rendered collector (sed-redirected output paths only) — 19/19 assertions green on host AND in-sandbox |
| P2 #5 persisted regression | `checks.x86_64-linux.btrfs-scrub-staleness-fixture` | 4 runs × (5 branches + fail-closed absence): finished-old→stale 1, finished-fresh→0, resumed-fresh→0 (the fix), running→0+last 0, unparseable→parse_errors 1 (fails loud, not silent 0), never-started→1, scrub-status-failure→lines ABSENT (gatus presence conditions own it). Commit `a061bbe5` |
| P2 #8 stray-unit lint | module + baseline + negative test, both hosts silent | `modules/nixos/services/stray-unit-audit.nix` (warning-grade). Probe lessons encoded: (1) dep text must be gathered PER NAMESPACE — a `//` union of services//timers//… drops the service entry of every timer+service name twin (phantom-clean, found by construction); (2) `requiredBy` is a pull class (nixpkgs paperless-secret-key — found live); (3) `onFailure` sinks are pulled (rpi3 crush-update-failure); (4) dep getters must tolerate non-list values (`u.k or []` throws on `""`). Baseline allowlist 27 entries (20 upstream preset/alias/dbus-wired + 7 deploy.sh/udev/runbook-started + hot-db-bootstrap inert-while-entries={}); evo-x2 AND rpi3-dns evaluate silent. 8-case negative test `tests/test-stray-unit-audit.nix` — assertion keys on the warning HEADER only (the guidance text names btrfs-scrub-- as the example and phantom-matches otherwise). Daemon commit `9d2edef5` |
| P2 #9 per-zone trip gauges | landed, VM-proven | trip-history lines carry the zone; `memory_emergency_guard_zone_trips_last_hour{zone="1".."6"}` emitted every run; legacy bare-timestamp lines count aggregate-only. VM scenario 6a-z seeds mixed history and asserts attribution + legacy exclusion. Commit `347173af` |
| P2 #10 cooldown disclosure + churn drift | landed, VM-proven | cooldown heartbeat discloses `last trip zone=N` + seconds remaining; churn-list drift probe (`systemctl cat` existence, every tick, heartbeat-throttled WARN) — prefix `GUARD CHURN-LIST DRIFT` deliberately distinct so emergency greps cannot match (the first wording contained the literal string "MEMORY EMERGENCY" inside its own anti-phantom parenthetical and phantom-failed the healthy scenario — fixed, lesson below). Commit `347173af` |
| P2 #11 deploy.sh race detector | landed, live-verified | pre-switch WARN when HEAD <15 min old AND the config first-activates units absent from the running generation (the 05:50 cert-mint class). Unit-name eval (`nix eval --raw --apply concatStringsSep`) runs only when HEAD is young; shellcheck 0 findings; live dry-run correctly names the pending `btrfs-scrub@data`/`@mnt-pool` instances as first-activation candidates. Commit `1ea5f0ae` |
| Crosswalk (f.9 from 13-41 report) | done, encoded as row verdicts | fifty-todos (48/50) was overwhelmingly docs/convention work; P3 overlaps: **#36 DONE** (fifty #15/#16 — exit contract in docs/agents/storage.md, cancel-during-storm in guard runbook; spot-verified in tree), **#50 DONE** (fifty #31), **#33 DONE** (parallel `51431058`), **#31 STAGED** (01-03 report; owner window), **#34 PARTIAL** (09-25 §e5 + 23-20 done; 04-34 nsfw premise remains), **#40 partial** (this session executed the scrub-staleness fixture + full guard VM test). Also resolved while checking: **#24** (CV TODO_LIST daemon-committed, task 000001a0 closed by `38990f167`), **#53** (socket down = guard containing a LIVE Zone-6 storm; working as designed). Plan rows 5/8/9/10/11/24/31/33/34/36/40/50/53 annotated; remaining P3 ≈ 42 rows, no other overlaps |

Gates at close: `nix flake check --no-build` green (twice — after P2#8 and after the guard batch), full guard VM test rc=0, fixture check + negative test built green, `verify-html-diagrams.sh` PASS after each annotation pass.

## b) PARTIALLY DONE

1. **P3 execution** — not started beyond the crosswalk-resolved rows; the highest-value remaining agent-local items (P3#40 fleet VM sweep, #22 goModules sweep, #12 pressure-gate multi-sample) are all IO-heavy, and a Zone-6 storm is LIVE at close (see §d) — deliberately deferred rather than executed into the storm.

## c) NOT STARTED (deliberately)

- P3 rows 12–23, 25–30, 32, 35, 37–39, 41–49, 51–52, 54–61 minus the crosswalk-resolved ones. Owner-gated items untouched as always (deploys, sudo, `docs/todo/storage.md` Oct-5 decisions).

## d) TOTALLY FUCKED UP (self-caught, all fixed in-session)

1. **Fixture harness sed missed its targets** — writeShellApplication strips the common indent, so my `^      METRICS_FILE=` pattern (6-space) never matched; the collector ran against the REAL sticky-dir path and died at the final `mv`. Fixed with indent-agnostic `^\( *\)METRICS_FILE=`. Second harness bug: the fake btrfs's `root.fails` check sat after the status branch's `exit 0` — unreachable; moved before the case.
2. **Unquoted heredoc in the flake check** — the stub's `$cmd` was expanded by the BUILDER shell under `set -u` (`cmd: unbound variable`). The forgejo precedent used `<<'STUBEOF'`; quoting the delimiter fixed it. Then the stub itself couldn't find `$FIX` (check-shell var, not exported, quoted heredoc left it literal) — made the stub self-locating via its own `$0`.
3. **Unanchored assertion phantom-match** — `grep -qE 'btrfs_scrub_staleness_parse_errors 1'` matches the HELP comment ("parse_errors 1 = a FINISHED…"), which made an all-failing run look 1/16-pass. `$`-anchored every value assertion. Same class re-appeared at a higher level: the drift WARN's own anti-phantom parenthetical contained the literal "MEMORY EMERGENCY" and phantom-failed the healthy scenario — reworded.
4. **Stray-lint probe false-clean #1**: refText included each unit's own name → every unit self-referenced → 0 orphans guaranteed. **False-orphans #2**: the `//` namespace union (timer twins). Both caught by construction before shipping; the module encodes the fixes.
5. **Misread a VM failure as my regression, briefly** — scenario 9b failed on one build while the baseline passed; analysis showed the baseline won a coin flip, not a difference: identical diskstats ticks across back-to-back runs make Zone-6 corroboration depend on `elapsed` being 0 (corroborated, fail-safe) vs ≥1s (0% busy, no trip). Fixed with rising-tick fixture variants (zone6mid base 26000, then a/b/c at 39000/52000/65000) so every scenario-9 trip is deterministic — a pre-existing flake fixed en route.
6. **Commit-msg hook rejected a 75-char subject** (house gate working as intended); also one commit attempt blocked by a PARALLEL session's mid-flight flake.lock (`bank-sync/systems follows non-existent systems`) — waited, their edit healed, committed normally. No `--no-verify` used.

## e) WHAT WE SHOULD IMPROVE

1. **Binary format verification beats recitation** — the `Scrub resumed:` trap was only findable by dumping raw bytes around the format strings; `strings` output alone hides leading tabs and ADJACENT format strings are invisible without context. Any future parser of tool output should be verified against the locked binary's format strings, not memory.
2. **Phantom-match discipline extends to assertion AUTHORSHIP** — three separate instances this session (HELP-comment grep, guidance-text grep, self-referential WARN wording). The `$`-anchor + header-only-scan patterns used here should be the default for every fixture assertion written in this repo.
3. **Agent sessions are IO-storm drivers** — at close the guard was cycling Zone-6 (trips #1611–1613) with this session's VM boots/builds among the contributors. The doctrine already says cap concurrency during guard-active windows; the practical rule for agents: after ANY VM test or build batch, check `memory_emergency_guard_trips_last_hour` before starting the next heavy leg, and stop heavy work when it is ≥2.

## f) Up to 50 next things (self-harvested)

1. Deploy the landed P2 batch (`nix run .#deploy`, owner-gated): scrub-staleness check + guard attribution gauges + drift WARN + stray-unit lint + race detector all ride it — annotate rows "rides deploy" post-deploy. Queued: TODO_LIST.md + docs/todo/stability.md row. **Source:** this report §a.
2. P3 remaining ~42 rows in plan order after the crosswalk (rows 12-23, 25-30, 32, 35, 37-39, 41-49, 51-52, 54-61 minus resolved) — execute in a QUIET window (see §e3). Queued: TODO_LIST.md pointer row. **Source:** this report §a crosswalk.
3. The stray-unit-audit allowlist needs a re-probe after the NEXT deploy adds/renames units (a stale allowlist entry is harmless; a new unallowed stray is the point). **Source:** this report §a/P2#8.

## g) Questions

(carried, unchanged from `docs/status/2026-10-01_13-41_master-plan-p2-continuation-scrub-staleness-inflight.md` §g — deploy authority, gate hardness for the pairing/harvest lints, attribution footers. One addition:)

1. **FLM restore-cap during storms (P3#55 adjacent, plan decision #13):** the socket sat restore-capped through the 15:04–15:34 storm window (3/3 budget). Working as designed, but the cap policy (3/day) + waker policy is the standing owner decision — this session adds no new evidence beyond trips #1611-1613's attribution lines now naming top io movers.
