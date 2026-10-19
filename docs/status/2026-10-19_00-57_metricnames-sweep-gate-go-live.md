# The metricnames Sweep Gate Went Live (+ a Phantom-Count Correction and a Go-Floor Discovery)

**Session:** 2026-10-18 ~06:56 → 2026-10-19 00:03 (owner re-entry) → ~01:00 CEST · **Instance:** successor of the 05-23 closure session (tile-logos wave, instance 1 lineage)
**Trigger:** handoff instruction: recreate the 28 todos, then the standing "break into steps, execute and verify one at a time, keep going" — then the owner's a–g status report request at 00:03.
**Predecessor:** [05-23 self-audit](2026-10-18_05-23_superb-closure-self-audit-and-store-truth-correction.md) (its §e/§f candidate follow-ups are this session's work queue)
**Commits (this session):** content landed via daemon sweeps `93cf1bb90`/`6c86f8fb6` (initial + clobber-fix script), `2345a3c1a` (7 doc files), `6dbd01bd9` (directive fix, riding the parallel session's lock-bump commit), plus my explicit `d7ceeaede` (05-23 §f amendment, pathspec, pre-commit green). HEAD ≈ `6dbd01bd9` at report time; tree hot (parallel session active).

## TL;DR

The manual E4 sweep is now a repo-native GATE: `scripts/metric-sweep.sh` extracts every dashboard+alert metric reference (122 → 121 after scanner fixes), probes them against ClickHouse in ONE batched query, and fails on any zero-series name off a store-justified allowlist — with an opt-in `CASES=metricnames` harness leg proving both the pass and the fail path (2/2 PASS). Rewriting the extractor from python to shell/jq/gawk (the zero-python rule) fixed FOUR scanner gaps the python had — and that correction REVERSED a finding: **only 1 of yesterday's "4 REAL phantoms" is real** (`discordsync_immich_lookup_total`); the io_* pair was a regex-alternation split of LIVE full names and `reallocated_events` was a label value. Separately, the session DISCOVERED a deploy-blocking go-toolchain floor breakage introduced by a parallel session's 00:52 lock bump. The IO gate never opened (PSI avg10 45→82→52 across the session), so the battery re-run and E12/E13 remain deferred — and the battery now ALSO blocks on the go floor.

## a) FULLY DONE

| # | Item | Evidence |
| --- | --- | --- |
| a1 | **28 todos recreated** (21 completed / 7 pending, exact handoff statuses) + 6 new session tasks tracked | todos tool |
| a2 | **Recon before touching anything**: tree clean at `eccae1b30` == origin/master, no parallel commits at session start, `docs/status/` mtimes stable since 05:25 | git log + ls -lt |
| a3 | **Owner-question triage**: the re-issued standing instruction answers NONE of the 3 open questions → E1/E2/E3/E9/E10 left untouched by design | this report §g |
| a4 | **05-23 §f self-harvest gap FOUND**: §e cites (f)3/(f)4/(f)5 that §f never listed; e.3/e.4 had neither queue rows nor explicit dispositions — then ALL THREE executed (see a5–a8) and the disposition recorded retroactively in the 05-23 report | commit `d7ceeaede` |
| a5 | **`scripts/metric-sweep.sh`** — the promoted gate: jq (dashboards) + gawk (alerts, all THREE nix quote forms — the python missed `query = "…"`, so `system_tmpfs_tmp_usage_percent` had never been probed) + gawk tokenizer (`__name__=~"P(a|b)"` regex-matchers EXPANDED to full names; by()/without()/on()/ignoring() label lists stripped; remaining `{...}` selector blocks and quoted label VALUES stripped; PromQL function set excluded) + ONE batched CH `IN (...)` probe + expected-absent allowlist (`scripts/metric-sweep-expected-absent.txt`, `*`-globs with justification comments) + `SWEEP_INJECT` self-test hook + `--list` mode | file; runs below |
| a6 | **Gate verified end-to-end**: `--list` → 121 distinct names; live sweep → **110 live, 11 expected-absent, 0 PHANTOM(S), exit 0**; `SWEEP_INJECT=sweep_selftest_phantom_probe` → **exit 1 naming the injected phantom** (fail path proven through the REAL store query) | terminal transcripts this session |
| a7 | **`CASES=metricnames` harness leg** wired into `scripts/negative-test-lints.sh` — explicit-selection-ONLY (CI's nightly workflow sets no CASES and has no store access; verified by reading the workflow + the harness filter logic); leg 1 = real sweep must pass, leg 2 = injected phantom must fail | `CASES=metricnames` run: **2 passed, 0 failed** |
| a8 | **The e.3/e.4 executions**: gotchas-archive "lesson-generalization" row (incl. the new sibling: sweeps are tools with failure modes too) + CONTRIBUTING "Concurrent-edit discipline" **rule 5: docs-file ownership** (content-pin: `git log -1 -- file`, re-read, `grep -c` markers before the commit window closes, atomic re-apply) | both files, daemon-carried in `2345a3c1a` |
| a9 | **Phantom-count CORRECTION propagated** (surface-named): monitoring.md E4.5 row now reads "only ONE of the 4 is real" with the store evidence; allowlist trimmed to `discordsync_immich_lookup_total` (+ GCP glob); 05-23 §a3 disposition amendment; agents/monitoring.md "Exporter names vs store names" gains the repo-native sweep sentence; signoz.md cheat-sheet gains the sweep line; pipeline.md baseline-diff row gains the store-vs-lint axis note; monitoring.md 2026-08-27 sweep-automation row item (1) marked DONE | all seven surfaces |
| a10 | **Store-truth probes for the corrected verdicts**: `memory_emergency_guard_io_disk_busy_percent_max` + `_io_psi_some_avg60_percent` = Gauge, 713 series each, LIVE; `pool_smart_attribute_raw` = Gauge, 9982 series, LIVE | `metric-exists.sh` output |
| a11 | **shellcheck discipline enforced despite daemon sweeps**: my .sh files rode daemon commits (the known filetype-leg bypass) → re-ran standalone at the pre-commit's own severity; fixed SC2254 with a justified directive (first attempt had invalid `--` comment syntax — pre-commit caught it, correctly); HEAD copy content-pinned CLEAN | shellcheck 0.11.0 standalone runs |
| a12 | **Go-floor discovery queued**: `[blocked:push]` row in pipeline.md — the 00:52 lock bump broke the go toolchain floor for EVERY nix eval leg; deploy/battery-blocking; the eval error's own 3-option fix menu recorded for the owner | pipeline.md row; §d4 |

## b) PARTIALLY DONE

| # | Item | Works | Missing | Blocker | Effort |
| --- | --- | --- | --- | --- | --- |
| b1 | **Whole-tree battery re-run** ([ready] row) | Nothing re-run | full pre-deploy battery + `nix flake check --no-build` on the final tree | **TWO blockers now**: IO gate (PSI some avg10 never < 30 this session: 45.76 → 82.65 → 51.80) AND the go-floor breakage (flake check fails on ANY commit's nix leg) | ~5 min at calm + go-floor fix |
| b2 | **b4 neuter-proof** (remove deadMetrics entry → dotted-phantom-dead case red) | Not started; the INJECT leg already proves the new sweep gate's fail path end-to-end | the literal lint-mutation run for the deadMetrics entries | none, just wasn't reached | 5 min |
| b3 | **metric-sweep.sh "live provenance"** | Everything above | the script has never been run by a SECOND session; its first consumer will be the next post-lock-bump sweep | — | — |

## c) NOT STARTED (all owner/IO-gated, unchanged from handoff)

1. **E1 deploy** (⛔ owner sudo; now ALSO waits on the go-floor fix — see §g1) — carries the dotted-query revert + icon wave.
2. **E2 first-fire battery** (post-deploy; E2.6 expects the UNDERSCORE provisioned query).
3. **E3 browser visual pass** (⛔ owner browser).
4. **E9 icon-style decision** (⛔ owner).
5. **E10 off-LAN phone probe** (⛔ owner phone).
6. **E12 papdashboard VM test** (IO gate; plan §3 E12).
7. **E13 shim-fleet sweep** (IO gate + upstream pushes; note: E13's FOD builds ALSO hit the go floor until fixed).
8. **Forgejo alert history question + PapDashboard CI repair-vs-retire** (⛔ owner; memo at upstream TODO row 104).

## d) TOTALLY FUCKED UP (all caught; radical honesty)

| # | What | Severity | Root cause | Caught by / mitigation |
| --- | --- | --- | --- | --- |
| d1 | **The first metric-sweep.sh shipped BROKEN and sat in the tree ~17h**: an awk `RSTART`/`RLENGTH` clobber — `harvest()`→`tokenize()` calls `match()` internally, clobbering the outer while-loop's offsets, so `line` never shrank → infinite loop (state R, pipe backpressure, alerts-gawk never started). The daemon committed it (`93cf1bb90`) before any successful run. | HIGH (a promoted gate that hangs on real input, committed) | I wrote the outer loop using the globals AFTER a function call that rewrites them — the classic awk scoping trap; and my verification run went to BACKGROUND with output redirected to /tmp files, so it read as "running, no output" instead of "hung", and the session ended without the verdict | `/proc` forensics (state R + pgrep tree) → per-file binary search → single-query repro (`{__name__="…​.sum"}` matcher through tokenize) → snapshot `rs=RSTART; rl=RLENGTH` before the call. Full pass+fail re-verification after the fix. Standing lesson: **a session never ends with a promoted-but-unverified script in the tree — the daemon makes "uncommitted" meaningless, the tree IS the release** |
| d2 | **My own verification pipeline was the misdirection**: (i) verification output redirected to /tmp (volatile — wiped, cost a re-run), (ii) the job-output channel empty BECAUSE of the redirect, (iii) a first "tokenizer clean" test was VACUOUS — `gawk -f /dev/stdin <<heredoc` consumed the heredoc as BOTH program and data, testing nothing | MEDIUM | Redirect habit + heredoc-as-stdin trap | Redone with the program in a cache FILE and data on the pipe; the repo rule about /tmp already existed — I violated it on the very first scratch file |
| d3 | **A multiedit of mine dropped a trailing newline and JOINED two bash statements** (`live_file=$(mktemp …)  printf …`) → `unbound variable` at runtime | LOW | edit-tool old_string included a trailing `\n` the new_string didn't | `bash -n` + the run itself; split back into two lines |
| d4 | **The go toolchain floor breakage sat UNNOTICED across my whole session until pre-commit happened to run a nix leg** — I ran shell-only verifications all session; the parallel session's 00:52 lock bump (710-line flake.lock) broke every go eval, and only my SC2254 recommit exposed it | MEDIUM (deploy-blocking class, discovered ~1h after landing) | The battery re-run (the whole-tree verdict) was correctly IO-deferred — so no session had eval'd the tree since the bump | Pre-commit flake-check leg; queued as `[blocked:push]` pipeline row with the fix menu; reported to owner §g1 |
| d5 | **First shellcheck-directive attempt used invalid `--` comment syntax INSIDE the directive** (SC1072/73) — and it reached a staged commit because the daemon had swept the file between my standalone run and the commit | LOW | Directive syntax + daemon race | The pre-commit shellcheck leg itself (the gate worked); corrected to rationale-comment-above-directive; HEAD copy pinned clean |

## e) WHAT WE SHOULD IMPROVE

1. **Never end a session on an unverified promoted artifact.** d1 is the negative-test doctrine applied to my own tooling and initially violated: the tree auto-publishes. The inject-fail-leg should be the FIRST thing written for any probe-type gate, not the last.
2. **Verification output goes to the terminal (or XDG_CACHE), never /tmp, and never as a detached background redirect** — the 17h dead window started with a redirect that made a hang invisible.
3. **Heredoc-as-stdin is a testing trap**: `cmd -f /dev/stdin <<EOF` silently consumes the heredoc as data. Worth one line in the harness conventions (queued, f).
4. **The daemon filetype-leg bypass is now a three-time specimen** (heal-breadcrumb, this session's SC2254-attempt, the initial sweep script): the rule "re-run skipped lints standalone after daemon-swept commits" should be MECHANICAL — the pre-commit could detect "daemon commit touched .sh since your last green" … over-engineering; the simpler fix is the habit: standalone shellcheck before ANY script work is called done.
5. **Extractor correctness is load-bearing for findings**: the python predecessor's gaps produced THREE false phantoms that survived a whole triage pass and landed in a [ready] row as "fix or delete each query" — someone could have "fixed" LIVE queries off that row. Probe-before-claim applies to SWEEP OUTPUT too; that clause is now in the gotchas row.
6. **The parallel-session lock-bump blast radius** (d4): a floating-input bump one session makes can break every other session's pre-commit + the deploy. The pipeline row carries the fix menu; the OWNER choice (g1) unblocks everything downstream.

## f) FOLLOW-UPS (self-harvest at authoring time, per the §f contract)

**HARVESTED NOW (1 new row):**

| # | Item | Surface |
| --- | --- | --- |
| 1 | go toolchain floor fix — the 00:52 lock bump's `go 1.27.2` requirement vs resolved 1.27.1; three-option fix menu; deploy/battery-blocking | `docs/todo/pipeline.md` [blocked:push] row (added this session, pre-report) |

**Deliberately NOT harvested (already on surfaces):**

- Battery re-run at calm — existing [ready] row (services.md + TODO_LIST mirror); now double-blocked (IO + go floor), the row's premise still holds.
- E12/E13 — successor plan §3 pending epics (IO-gated; E13 also go-floor-gated).
- discordsync phantom fix-or-delete — the corrected monitoring.md E4.5 row IS the surface (now exactly one item + its allowlist line).
- Weekly lint baseline-diff CI — pipeline.md row (its note now delineates the store vs lint axes).
- b4 neuter-proof — recorded here as the remaining honesty gap (b2); trivial, next calm window.
- Harness-convention line for the heredoc-as-stdin trap (e.3) — one sentence for the next harness-touching session; folded into this report rather than a row (docs-owned, not queue-owned).

## g) Questions I CANNOT answer myself (max 3)

1. **The go toolchain floor fix (NEW, blocking):** the 00:52 parallel-session lock bump broke `nix flake check` for the whole tree (go.mod needs 1.27.2, resolved toolchain 1.27.1, `GOTOOLCHAIN=local` forbids downloads). The eval error offers: (a) `goPkgAttr = "go_1_XX"` newest branch pin, (b) `goTarballVersion = "1.27.2"` + tarball hash, (c) update the nixpkgs input (bumps ALL floating inputs — dependency decision). Which do you want? Until then every nix eval leg, the battery re-run, and any deploy build is red.
2. **Deploy sequencing (carried from 05-23 g1, now compounded):** the tile-logos wave deploy still awaits your sudo — should it wait for the go-floor fix + battery green (my recommendation: yes; deploying from a tree whose checks cannot run is the 2026-10-17 outage class), or is there a reason to go sooner?
3. **PapDashboard CI: repair or retire?** (carried, unchanged — memo at upstream TODO row 104 recommends RETIRE). The forgejo alert-history question from 05-23 g2 also still stands if you recall either way.

---

**§g DISPOSITION (amended 2026-10-19 03:5x, answered by execution — see [the closeout](2026-10-19_03-26_closeout-battery-green-deploy-landed.md) + [the self-review](2026-10-19_03-55_post-closeout-self-review-status.md)):** (1) the go-floor fix turned out to be NONE of the three offered options — root cause was pma's stale `goTarballVersion` pin whose drop-condition had fired; fixed upstream-local (push pending), SystemNix on the interim lock rollback `849573de`. (2) the deploy waited for battery green as recommended, then landed (gen-930, anchored). (3) PapDashboard CI: RETIRED (local tree; push pending). The forgejo alert-history question remains open.
