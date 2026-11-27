# Status: the 2026-11-27 deploy failure (stale cached go-modules FODs)

**Session window:** 2026-11-27 12:17 to 14:05 (fix work), 16:59 to 17:07 (re-pin and this report).
**Trigger:** `DEPLOY_FORCE_PRESSURE=2 nix run .#deploy` died in `go-taskqueue-0.4.2` after §11 had printed "20 uncached go-modules FOD(s) built clean".

**Follow-up session (2026-11-27 22:49 to 23:55, same harness rules: no commits, no push; its work rode the daemon commits named below).** §11's build leg is fixed and proven, and the survey it ran found §15's pre-vacuum evidence gate deaf since its birth and fixed that too. Every resolved item below carries an inline `done at` marker; the open ones say where they stand. Verified in that session, outputs under `~/.cache/systemnix-fodreuse/leg1/`:

| Claim | Evidence |
| ----- | -------- |
| §11 leg 1 realises now | `36b248c5d`: `nix-store --realise --keep-going` over every go-modules FOD of the toplevel closure whose output is not valid; leg 2 reads the store's record of every FOD and FAILs on any output still invalid |
| The old verb is a no-op, live | `nix build <drv> --keep-going --no-link` on a tiny FOD whose output was not valid: rc 0, output still not valid, `result` re-pointed at the `.drv` |
| Live harness, real store | two stale tiny FODs: FAIL twice with the real got-hash; a correct one: PASS; the old verb answering the realise call: FAIL `NOT REALISED` |
| On the tree | `nix run .#pre-deploy-check -- --section-11-only`, tree `d1b856d`, 23:24 to 23:39: PASS, 72 realised + 129 verified (41 by deriver identity, 63 re-verified by check-mode rebuild, 25 by prior receipt), 0 FAIL |
| Fixture suite | `scripts/test-pre-deploy-vendor.sh`: 120 assertions, five persisted mutation legs each proven to fail the suite while a comment-only control passes; flake check `pre-deploy-vendor-selftest` green in the sandbox |
| §15 gate was deaf | `grep -E '^- \[ \]' docs/todo/stability.md` piped into `grep -q -- 2026-11-03`: rc 141 against 52 citing rows; fixed in `scripts/pre-vacuum-evidence-gate.sh` (one `grep -qE`, four selftest legs padded with 6000 rows, the old form fails them); live after: pass, every exposed boot guarded |
| check #1's named blocker | `nix build .#checks.x86_64-linux.doc-counts` rc 0 at 23:24:22; FEATURES.md 55 to 54 by another session (`56e15c1dd`) |
| Queue | five rows closed on both surfaces, three minted (net minus two); `scripts/check-todo-system.sh` rc 0 |

**NOT verified in the follow-up session:** the full toplevel build; `nix flake check --no-build` as a whole (only its doc-counts check); the deploy (no attempt since 16:49, profile still `system-1033` at 23:40); a real stale-hash go-modules FOD on the tree (the tree had none, so the proof used tiny throwaway FODs); cargo and pnpm hashes (outside the gate's scope, queued); a fetched stale-hash FOD against a real substituter (covered by fixtures only).

## Scope line

**Verified here** (commands run in this session, outputs on disk under `~/.cache/systemnix-fodreuse/`), repo at `git rev-parse --short HEAD` = `ec52fa153` (clean tree, 17:06):

| Claim | Evidence |
| ----- | -------- |
| The cached go-taskqueue FOD was reused, not rebuilt | `nix-store -q --deriver /nix/store/0n0p2vmv…-go-taskqueue-0.4.2-go-modules` = `cavivn0c…-go-modules.drv`, closure holds `3pgfc344…` (12:27) |
| `nix-store --realise --check <drv>` is the oracle for a valid FOD path | mismatch with `got: sha256-HqHkPDVQ…` in 15 s (12:30:05 to 12:30:20); plain `--realise` and `nix build --rebuild` on the same drv: rc 0, no rebuild |
| The wave had TWO stale cached FODs, not one | prototype audit of toplevel `327wk58q…`: 129 go-modules drvs = 93 uncached, 16 proven, 20 reused; check-mode: go-taskqueue and journal stale, 18 reproduce (`reverify.summary`) |
| New §11 leg 2 blocks on the real tree before the repair | `nix run .#pre-deploy-check -- --section-11-only` at 13:27: `1 passed, 2 failed`, one FAIL per stale FOD with got-hash (`section11-before.log`) |
| §11 leg 2 runs inside a real deploy battery | deploy log `2026-11-27_16-45-21.log:241`: "✓ vendorHash valid — 56 cached FOD(s) verified (31 by deriver identity, 0 re-verified by check-mode rebuild, 25 by prior receipt) [tree 3a66b19]" |
| **§11 leg 1 is a no-op** | A/B at 17:03:53 on `…-caddy-2.11.9-go-modules.drv` (output not valid): `nix build <drv> --no-link --keep-going` rc 0 in 1 s, output still not valid; `nix build '<drv>^out' --no-link` rc 0, path copied from cache.nixos.org, output valid |
| `fod-hash-diff.sh` had two defects, both fixed | old live-site classifier missed a live literal in a 234 KB fixture 20/20 runs; `--selftest` rc 0 with 16 assertions after |
| Fixture suites | `bash scripts/test-pre-deploy-vendor.sh` rc 0, 78 ok (13:59); `nix build .#checks.x86_64-linux.pre-deploy-vendor-selftest .#checks.x86_64-linux.fod-hash-diff-selftest --no-link` rc 0 (14:00) |
| Repaired packages build | `nix build .#tq .#journal --no-link` rc 0 (13:4x); all four shim literals at HEAD byte-equal to the evidence log |
| Standalone lint on touched files | shellcheck `--severity=warning` rc 0 (4 scripts), deadnix and statix silent, gitleaks "no leaks found", nullglob audit: 0 warnings in touched scripts, `nix fmt -- --fail-on-change` 0 changed |
| TODO gate | `bash scripts/check-todo-system.sh` rc 0, "OK: TODO queue/library structure clean" (WARN 92 unharvested reports, none from this session) |
| Deploy state at report time | `/var/log/systemnix-deploys/`: 15:37 `nh os switch FAILED (exit 1)` at 16:04; 16:15 and 16:45 `DEPLOY BLOCKED` on check #1; 16:49 rc 13 (flock). Running `zp0384i8…`, profile `system-1033-link` |

**NOT verified here:**

- The full toplevel build. I never ran it (IO storm, see d-6). Commit `3a66b194e` (another session, 16:42) states "The evo-x2 toplevel now builds green"; I did not reproduce that.
- Why check #1 (`nix flake check --no-build`) fails in the 16:15 and 16:45 batteries. The log says `doc-counts: FEATURES packages asserts 55, eval truth is 54`; none of this session's files appear in that error. Not investigated.
- Why journal's FOD drifts under our graph (suspected: the `go-paperless` follow); not probed.
- Whether the daemon `--no-verify` path is the ONLY way lock waves land. Verified for today's 10:34 wave (`97b74f040` exists although its lock did not build, so a FAIL-ing hook cannot have run); not surveyed across history.
- Whether the 15:37 `nh os switch` failure was what `3a66b194e`'s message describes (signoz-otel-collector patchPhase). Read from the commit message, not from the build log.
- Anything outside this incident. No other service, module or TODO row was examined.

## What happened

1. 10:34: the auto-commit daemon swept a lock wave (`97b74f040`, 131 new rev lines). go-taskqueue moved d4bfcc86 to af5b6ec5 with its source changed and its vendorHash literal unchanged. Daemon commits use `--no-verify`, so the pre-commit lock-build gate never ran.
2. A fixed-output store path is keyed by the SPECIFIED hash. The old module tree stayed valid under the same path, nix reused it, no builder ran, no mismatch was printed.
3. The deploy's §11 only looked at FODs the preview lists as "to be built". A cached FOD is invisible there, and the gate read "cached" as "proven by prior builds". It passed. The build died at compile time.
4. This session (12:17 to 14:05): root cause, a cached-FOD audit for §11, two repairs in the batch tool, the hash repairs at four surfaces, docs and TODO rows.
5. 13:53: my §11 re-run printed PASS with "20 uncached go-modules FOD(s) built clean". That half of the line was false (see d-1, d-2).
6. 15:37 to 16:49 (another session): four deploy attempts, none landed. `3a66b194e` re-stamped seven more stale vendor hashes and the SigNoz frontend pnpm hash from a keep-going enumeration: exactly the uncached class §11 leg 1 claims to build and does not.

## a) FULLY DONE

All of it sits in daemon `chore: auto-commit` commits (I made no commits; harness rule).

1. **§11 audits cached go-modules FODs** (`scripts/lib/vendor-freshness.sh`, last touched `5d342093a`). When the preview builds anything, the gate lists every `*-go-modules.drv` in the toplevel's derivation closure (`nix-store -qR`), reads each output path's recorded deriver, and treats deriver == drv as proof. Anything else is rebuilt with `nix-store --realise --check`; a PASS is receipted per drv hash under `~/.cache/systemnix/fod-check-receipts/`, receipts outside the audited closure are pruned. One FAIL per stale FOD with its got-hash and the verbatim nix block. Evidence: the 13:27 before-run and the 16:45 deploy battery (scope table).
~~2. **Leg 1 reports every stale uncached FOD instead of the first** (`vendor_freshness_mismatch_pairs`). Fixture-proven (G12); hollow in production until d-1 is fixed, because the build step before it realises nothing.~~ done — at `36b248c5d`: the build step before it realises now; the mutation leg `reported-fod-reported-twice` pins the per-FOD enumeration
3. **Fixtures** (`scripts/test-pre-deploy-vendor.sh`, `5d342093a`): 78 assertions. New: deriver classification, check-mode pass and mismatch captures (verbatim, 2026-11-27), closure excerpt, receipt store, flows G6 to G13 (reproduces, receipt converges, stale cached FOD, non-hash failure, closure query failure, unresolvable toplevel drv, two stale FODs, tree mutation). Both flake checks build green in the sandbox.
4. **`scripts/fod-hash-diff.sh`** (`bd2a7b9eb`): (i) live-site classifier no longer `… | grep -q` under `pipefail` (SIGPIPE turned a found match into "comment only, not rewritten", so `--apply` skipped `modules/nixos/services/tq-agent-pool.nix`); (ii) an upstream-only stale hash no longer aborts the run (bare `grep` exit 1 under `set -e` hid the note and every later pair). Selftest grew from 11 to 16 assertions, both new legs regress-proven.
5. **Hash repairs, four surfaces**: go-taskqueue `sha256-HqHkPDVQ…` in `lib/lars-packages.nix` (`tq`) and `modules/nixos/services/tq-agent-pool.nix`, applied with `fod-hash-diff.sh --apply` from the §11 log; journal `sha256-2piQtqwo…` re-shimmed in `modules/nixos/services/_journal-package.nix` and the `journal` PATH entry (`9c53b1d10`). Evidence comments at each site. `nix build .#tq .#journal` rc 0.
6. **Docs**: `AGENTS.md` (Pre-deploy table row, new paragraph "§11 audits CACHED FODs too", `8ca7fa3f0`); `docs/agents/nix-flakes.md` (daemon `--no-verify` blind spot, `--check` oracle, corrected 2026-11-06 refinement, classifier race); `CHANGELOG.md` entry; `scripts/pre-deploy-check.sh` §11 prose and title.
7. **TODO rows updated, none minted**: `docs/todo/upstream.md` watch row "Cache-hit-FOD green ≠ rebuildable" (trigger hit), the upstream re-pin sweep row (2026-11-27 wave bullet, both shims, owner push step), and the "Amended flake.lock commits skip the toplevel build gate" row in `TODO_LIST.md` and `docs/todo/pipeline.md` (corrected premise: the daemon's own commits never reach the hook).

## b) PARTIALLY DONE

~~1. **§11 as a gate.** Leg 2 is proven on the live tree. Leg 1 (`nix build $fods --keep-going`) realises nothing, so the PASS line can still say "built clean" about FODs that were never built. Fix: S (under 30 min). Blocker: none; I stopped because you asked for a report.~~ done — at `36b248c5d`: leg 1 is `nix-store --realise --keep-going` over every go-modules FOD of the toplevel closure whose output is not valid, and leg 2 FAILs on any output still invalid after it; proven live on tiny throwaway FODs against the real store and on the tree (`nix run .#pre-deploy-check -- --section-11-only` on tree `d1b856d`, 23:24 to 23:39: PASS, 72 go-modules FODs realised + 129 verified (41 by deriver identity, 63 re-verified by check-mode rebuild, 25 by prior receipt), 0 FAIL)
2. **Docs describing §11.** `AGENTS.md` still calls the §11 preview "real builds"; my CHANGELOG entry says the preview leg "reports every stale UNCACHED FOD". True only after b-1. Fix: S, together with b-1.
3. **The deploy.** Not landed as of 17:07. Vendor hashes are no longer the blocker in the 16:45 battery (§11 green). Current blocker is check #1 (doc-counts), not mine, not investigated. Status of the other session's toplevel proof: their claim. **→ blocker gone: FEATURES.md re-stamped 55 to 54 by another session (`56e15c1dd`), `nix build .#checks.x86_64-linux.doc-counts` rc 0 at 23:24:22; no deploy attempt since 16:49, so this stays open**
4. **Upstream side of both shims.** go-taskqueue@af5b6ec5 bakes `sha256-+JIm293y…` (its `flake.nix:78`), journal@f32e70c2 bakes `sha256-9M6laArs…` (`flake.nix:215`). Both stale under our graph. Interim shims are in; the bake, push and re-float are an owner step (I cannot push; go-taskqueue's checkout had a live session today at 12:18).
~~5. **Negative-test coverage for the gate's own commands.** Leg 2 has a live negative proof (the 13:27 run). Leg 1 has none; its fixture stubs `nix`, so it cannot see a no-op.~~ done — at `36b248c5d` and `d1b856df1`: flows for a hollow realise, a fetched FOD and a non-hash build failure, the old verb run live against the real store (it FAILs), and five persisted mutation legs at the end of `scripts/test-pre-deploy-vendor.sh`

## c) NOT STARTED

~~1. Leg 1 fix and its negative test (b-1). Priority: highest in this report.~~ done — at `36b248c5d`: leg 1 is `nix-store --realise --keep-going` over every go-modules FOD of the toplevel closure whose output is not valid, and leg 2 FAILs on any output still invalid after it
2. Audit for non-go FOD classes (source fetchers, pnpm and cargo deps). `3a66b194e` found the SigNoz frontend pnpm hash stale in the same wave; the audit is scoped to `*-go-modules.drv` on purpose.
3. A §11 result metric (stale count, verified count) for SigNoz and the textfile collectors.
4. Correcting the "fifth re-stale" framing in the shim comments if a different count is wanted; I counted 10-27, 10-28, 11-02, 11-10, 11-27 from the tq comment trail.
~~5. Queue row for b-1. See the harvest ledger under (f).~~ **NOT-DO — b-1 was fixed in the follow-up session (`36b248c5d`), so no queue row was needed.**
6. Identifying the carrier of the module-graph drift (still UNIDENTIFIED in the watch row).

## d) TOTALLY FUCKED UP

~~1. **§11 leg 1 has been hollow since the gate was written (`8ef8d57f4`, 2026-10-04, 54 days).** `git log -S` shows the line `nix build $fods --keep-going` is unchanged since then. `nix build <drv>` realises the `.drv` path, which is already valid, not its output. Every "N uncached go-modules FOD(s) built clean" line was rc 0 in about one second. Severity: High. The gate's founding purpose (stale vendorHashes of UNCACHED FODs caught before the deploy build) has not worked; only the parts that do not depend on that build had an effect (preview failure handling since 2026-11-25, leg 2 since today). Root cause: the installable form. Confirmed today by A/B at 17:03:53 and by three independent observations (the deploy plan listing the same ~19 FODs after §11 "built" them; 93 FOD outputs still invalid after three such runs; `3a66b194e` re-stamping seven stale vendor hashes after my green §11). Workaround: the working form is `nix build '<drv>^out'` or `nix-store --realise <drv>`.~~ done — at `36b248c5d`: leg 1 is `nix-store --realise --keep-going` over every go-modules FOD of the toplevel closure whose output is not valid, and leg 2 FAILs on any output still invalid after it; live: two stale tiny FODs FAIL with the real got-hash, the old verb FAILs
~~2. **My 13:53 PASS was a false pass.** I wrote "20 uncached go-modules FOD(s) built clean + 36 cached FOD(s) verified". The second half is proven; the first half repeated leg 1's claim without testing it, although `docs/agents/nix-flakes.md` documents the `nix build <drv>` no-op twice. The other session's `3a66b194e` (16:42) re-stamped seven stale vendor hashes from a keep-going enumeration; by elimination they sat in the set leg 1 calls "built clean" (leg 2 had re-verified every cached FOD, and a stale FOD cannot be fetched from a cache), though I did not match each of the seven to the 13:53 list. I noticed at 14:00, when "20 uncached again?" did not add up, and confirmed at 17:03. Anyone who read that line as "the wave is clear" was misled for three hours; the other session's enumeration was the real proof.~~ done — cannot pass again through this gate since `36b248c5d`: an output still invalid after a "successful" realise is one FAIL, pinned by the mutation leg `audit-skips-unrealised`
3. **The deploy is still not landed.** 15:37: `nh os switch FAILED (exit 1)` after 1585 s. 16:15 and 16:45: blocked by `nix flake check --no-build` (`doc-counts: FEATURES packages asserts 55, eval truth is 54`). 16:49: rc 13, a live deploy held the flock. Running system is still `zp0384i8…`. Not my change, not my investigation. **→ blocker gone: FEATURES.md re-stamped 55 to 54 by another session (`56e15c1dd`), `nix build .#checks.x86_64-linux.doc-counts` rc 0 at 23:24:22; no deploy attempt since 16:49, so this stays open**
4. **The pre-commit lock-build gate cannot see lock waves.** The daemon commits with `--no-verify` (`pma-daemon/committer/committer.go:113`, `NoVerify: true`). The hook covers hand-made commits only. Documented today; no fix.
5. **History.** The daemon committed intermediate states: `616e8c591` carries a test file with three failing expectations. All of this session's work is in commits titled "chore: auto-commit N changed file(s) (heuristic)". `9c53b1d10` mixes my shim edits with another session's `docs/todo/stability.md` change. I did not amend (harness rule). **→ owner question 1 (section g) is still open; the follow-up session committed nothing either (harness rule), its work rode daemon commits `36b248c5d`, `d1b856df1`, `9a4a185b8`**
6. **I added build load during an IO storm.** 20 check-mode rebuilds at 12:33, two package builds at 13:4x, 20 more in the 13:27 §11 run. PSI some was 25 to 45 % and the guard tripped 11 to 13 times an hour. Justified by the task, not asked. **→ the follow-up session added one 15-minute §11 run under the same storm (72 realises, 63 check-mode rebuilds), knowingly**
~~7. **A false premise in the gate header survived 54 days.** "Cached FODs never appear in the preview, prior success is the proof" sat above the tq shim's own description of the trap.~~ done — the header was rewritten at `36b248c5d` (one enumeration, two legs; rc 0 is not a build)

## Self-review: what I forgot, what I could have done better

1. I rewrote leg 1's reporting and wrote its PASS text without first proving the build command builds. The test for "a gate works" is to make the condition true and watch the verdict flip. I did that for leg 2 (live before-run, G8) and not for leg 1.
2. I read two doctrine bullets about `nix build <drv>` false-green as history, not as a live trap in the code I was editing.
3. My first receipt-prune design probed the live store (`[ -e "$drv" ]`), so the fixture passed locally by coincidence and failed 4 assertions in the nix sandbox. I had reported "tests green" before building the sandboxed check. Rule for me: the flake check is the test; the local run is a smoke.
4. Shell hygiene slipped: an `rg -r ''` (replace flag) mangled one display, and a search pattern in double quotes executed `nix --section-11-only` plus one "permission denied" command (harmless, sloppy, the exact traps AGENTS.md lists). I also dumped a 250-line FOD log to the terminal once.
5. I wrote "third recurrence" into three surfaces before counting; corrected to "fifth re-stale of that one shim since 2026-10-27".
6. I edited a shared tree while the daemon committed, so an intermediate red test file is in history.
7. I did not run the full toplevel proof and did not ask whether you wanted it under the storm.
8. I scoped the audit to go-modules only while the same wave also staled a pnpm hash.
9. I left the docs describing §11 as a working two-leg gate. They should have been written after leg 1 was proven, or with the gap named.

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Suggested fix |
| ------- | ------ | ------------- |
| ~~Verdict lines are not tied to proof that their command did the work~~ done — `36b248c5d`: verdicts are read off the store (`nix-store -q --deriver`), never off an exit code; five persisted mutation legs | ~~§11 leg 1 hollow for 54 days; one false PASS today~~ | ~~For every verdict: a negative test that makes the condition true and asserts the flip. For builds: assert output-path validity after the command (`nix path-info <out>`), never rc alone~~ |
| ~~Leg 1 and leg 2 use different realisation forms~~ done — `36b248c5d`: both legs use `nix-store` (leg 1 `--realise --keep-going`, leg 2 `--realise --check`); the hook's lock-build leg realises the flake-attr toplevel and needs no change | ~~One works, one does not~~ | ~~One helper, `nix-store --realise` (plus `--check` for valid paths), used by both legs and by the pre-commit lock-build gate~~ |
| Lock waves land through `--no-verify` **→ owner decision; already the `[decision]` row TODO_LIST.md → "§11-after-any-lock-wave enforcement point (pre-commit vs update-bot vs manual discipline)"** | The build gate is dead for every daemon lock commit | Owner decision: a proof off the commit path (post-commit or timer, alert on failure), or accept §11 as the gate. You retired the lock-float gate on 2026-11-11; do not rebuild it by accident |
| vendorHash shims per surface (tq: 2 sites, journal: 2 sites) **→ open, not harvested: no queue row yet (§f 11 below)** | Every re-stale is a multi-file edit; one missed site is a dead deploy | One shim constant per package in `lib/lars-packages.nix`, imported by the modules |
| Upstream bakes that only hold under the upstream lock **→ open, owner decision (the shim policy per input, §f 10)** | The treadmill | Decide per input: un-follow its nixpkgs (the `journal` precedent) or accept the consumer shim as permanent |
| FOD verification only at deploy time, under pressure **→ routed to TODO_LIST.md row "Move pre-deploy §11's check-mode rebuilds into a quiescence-aware window" (docs/todo/pipeline.md)** | Runs in the storm window | Batch the audit into quiescent windows and emit a metric, so a stale FOD is known before a deploy is attempted |
| Same templ FOD built as five derivations **→ open, not harvested: no queue row yet (§f 15 below)** | Five check-mode rebuilds per wave for one content | Dedupe the templ input across consumers |
| Evidence typed by hand where no live site exists **→ open, not harvested: no queue row yet (§f 12 below)** | Transcription risk (journal hash, two files) | Let `fod-hash-diff.sh --add-shim <pkg> <got>` write the shim at declared sites |

## f) Up to 50 things to get done next

Ranked by impact. "Direct" marks a follow-up of this report.

| # | Task | Impact | Effort | Category |
| - | ---- | ------ | ------ | -------- |
| ~~1~~ done at `36b248c5d` | ~~Direct. Fix §11 leg 1: build `'<drv>^out'` (or `nix-store --realise`), assert output validity after the build, FAIL when a "built" FOD is still invalid~~ | ~~Critical~~ | ~~S~~ | ~~Bug~~ |
| ~~2~~ done — at `36b248c5d`: flow G13 plus the `hollow-verb` and `audit-skips-unrealised` mutation legs; the old verb was also run live against the real store and FAILs | ~~Direct. Negative test for leg 1: a stubbed build that returns rc 0 and leaves the output invalid must FAIL the gate~~ | ~~Critical~~ | ~~S~~ | ~~Bug~~ |
| ~~3~~ done — `nix run .#pre-deploy-check -- --section-11-only` on tree `d1b856d`, 23:24 to 23:39: PASS, 72 go-modules FODs realised + 129 verified (41 by deriver identity, 63 re-verified by check-mode rebuild, 25 by prior receipt), 0 FAIL | ~~Direct. Re-run `--section-11-only` on the repaired tree and read the leg 1 part as proven~~ | ~~Critical~~ | ~~S~~ | ~~Bug~~ |
| ~~4~~ done at `36b248c5d` | ~~Direct. Correct `AGENTS.md`, `docs/agents/nix-flakes.md` and the CHANGELOG entry once leg 1 is real; add the leg 1 no-op to the traps list~~ | ~~High~~ | ~~S~~ | ~~Documentation~~ |
| 5 **→ blocker gone: FEATURES.md re-stamped 55 to 54 by another session (`56e15c1dd`), `nix build .#checks.x86_64-linux.doc-counts` rc 0 at 23:24:22; no deploy attempt since 16:49, so this stays open** | Direct. Land the deploy: the 16:15 and 16:45 batteries are blocked by check #1 (`doc-counts: FEATURES packages asserts 55, eval truth is 54`) | Critical | S | Bug |
| 6 **→ open, owner step (section g, question 3); carried by the 2026-11-27 wave bullet of the re-pin sweep row in docs/todo/upstream.md** | Direct. Owner: bake `sha256-HqHkPDVQ…` in go-taskqueue and `sha256-2piQtqwo…` in journal upstream, push, re-float, drop both shims (four sites) | High | M | Cleanup |
| 7 **→ routed to TODO_LIST.md row "Extend pre-deploy §11's FOD proof beyond go-modules: cargo vendor dirs, pnpm deps and source fetchers" (docs/todo/pipeline.md)** | Extend the cached-FOD audit to source fetchers and pnpm and cargo deps hashes | High | M | Feature |
| 8 **→ open, not harvested: no queue row yet** | Emit §11 counts as metrics (stale, reused, receipted) and a SigNoz rule on stale > 0 | Medium | S | Feature |
| ~~9~~ **NOT-DO — DUPLICATE: already the `[decision]` row TODO_LIST.md "§11-after-any-lock-wave enforcement point (pre-commit vs update-bot vs manual discipline)"; nothing new to mint.** | ~~Decide the lock-wave proof placement (question 2)~~ | ~~High~~ | ~~M~~ | ~~Quality~~ |
| 10 **→ open, owner decision; open, not harvested: no queue row yet** | Decide the shim policy per input: un-follow nixpkgs or permanent consumer shim | Medium | M | Quality |
| 11 **→ open, not harvested: no queue row yet** | Single shim constant per package, imported by its modules (tq, journal) | Medium | M | Refactor |
| 12 **→ open, not harvested: no queue row yet** | Add `--add-shim` to `fod-hash-diff.sh` so a hash with no live site gets its shim written, not typed | Medium | S | Feature |
| 13 **→ partly: flow G4 now reads a §11-shaped gate output and G8 a real mismatch block through `vendor_freshness_mismatch_pairs`; `scripts/fod-hash-diff.sh` itself is still not driven by a §11 log in any test** | Teach `fod-hash-diff.sh` to read a §11 log directly (it does today; add a test) | Low | S | Quality |
| 14 **→ open (the watch row in docs/todo/upstream.md still says UNIDENTIFIED)** | Identify the carrier of the module-graph drift behind the watch row | Medium | M | Bug |
| 15 **→ open, not harvested: no queue row yet** | Dedupe the templ-0.3.1100 go-modules derivation across its consumers | Low | M | Cleanup |
| 16 **→ routed to TODO_LIST.md row "Move pre-deploy §11's check-mode rebuilds into a quiescence-aware window" (docs/todo/pipeline.md)** | Move §11's 20-plus check-mode rebuilds into a quiescence-aware window | Medium | M | Stability |
| 17 **→ open, owner question 1 (section g)** | Reword or squash the daemon commits carrying this session (question 1) | Low | S | Cleanup |
| 18 **→ open, not harvested: no queue row yet** | Add a docs-gate rule: a status report's PASS quotes must name which leg or command produced them | Low | S | Quality |
| ~~19~~ done — recorded on 2026-11-27 in `AGENTS.md` (Session Discipline) and in `docs/agents/nix-flakes.md` instead of `docs/CONTRIBUTING.md` | ~~Record in `docs/CONTRIBUTING.md`: "rc 0 from `nix build <drv>` is not a build"~~ | ~~Low~~ | ~~S~~ | ~~Documentation~~ |
| ~~20~~ done — 2026-11-27: every `nix build` call site under scripts/, .githooks/, flake/, flake.nix, lib/, modules/, platforms/, systems/ and pkgs/ read; the gate's leg 1 was the only raw-`.drv` proof, fixed at `36b248c5d` | ~~Survey whether any other script uses `nix build <drv>` on a raw drv path as proof~~ | ~~Medium~~ | ~~S~~ | ~~Bug~~ |
| ~~21~~ done — 2026-11-27: 109 sites in pipefail scripts read; one real instance found and fixed (§15's `pvg_open_row_hits`, rc 141 against 52 citing rows, `scripts/pre-vacuum-evidence-gate.sh`); the 10 open sites are queued as TODO_LIST.md row "Fix the remaining `producer \| grep -q` pipefail races named by the 2026-11-27 survey" | ~~Survey `\| grep -q` under `pipefail` in the other gate scripts (same race class)~~ | ~~Medium~~ | ~~S~~ | ~~Bug~~ |
| ~~22~~ **NOT-DO — the hook's leg realises the flake-attr toplevel (`nix build .#…toplevel --keep-going --no-link`), never a raw `.drv`; there is no second form to unify.** | ~~Make the pre-commit hook's lock-build leg use the shared realisation helper~~ | ~~Medium~~ | ~~S~~ | ~~Quality~~ |
| 23 **→ open, not harvested: no queue row yet** | Receipt store: add `--forget-receipts` to the §11-only mode for debugging | Low | S | Feature |
| 24 **→ open, not harvested: no queue row yet** | Print the closure's stale FOD names in the §11 FAIL summary line (one line, all names) | Low | S | Feature |
| 25 **→ open, not harvested: no queue row yet** | Reduce the two-line progress output per re-verified FOD to one line | Low | S | Cleanup |
| 26 **→ open, not harvested: no queue row yet** | Add the 2026-11-27 captures as fixtures in `negative-test-lints.sh` once a leg exists there | Low | S | Quality |
| 27 **→ open; the audit already does it at every deploy (the 23:24 run verified go-taskqueue and journal after the 23:19 lock wave, no hand probe); the row waits for a float that actually moves those two inputs** | Re-verify the four shim literals after the next lock float with the audit alone (no hand probe) | Medium | S | Quality |
| 28 **→ open: no toplevel build was run in the follow-up session either** | Close `TODO_LIST.md:3959` (art-dupl, samber-linter reproduce per the audit; cv and signoz re-stamped by `3a66b194e`) after one green toplevel | Low | S | Cleanup |
| 29 **→ open, not harvested: no queue row yet** | Drop the "fifth re-stale" phrasing if a count is not wanted in shim comments | Low | S | Cleanup |
| 30 **→ open; the follow-up session added its own evidence under the same directory (`leg1/`)** | Prune `~/.cache/systemnix-fodreuse/` once the evidence is cited from a committed report | Low | S | Cleanup |

Items 17 to 30 are ROADMAP fuel more than commitments.

**Harvest ledger (AGENTS.md rule: §f direct follow-ups land in the queue, or are recorded here as deliberately not harvested).** Items 1 to 6 are the direct follow-ups of this report. They are deliberately NOT harvested at authoring time: your instruction for this turn was report, then wait, and this session closed 0 queue rows (intake rule: close at least as many as you mint). Items 1 to 4 are written as dispatch-ready one-liners and belong in `docs/todo/pipeline.md`; item 5 is the live deploy blocker (owner or next session); item 6 extends the wave bullet already added to the upstream re-pin sweep row in `docs/todo/upstream.md`.

## g) Questions I cannot answer myself

1. **Commits.** `AGENTS.md` says to amend daemon `chore: auto-commit` commits into properly-messaged ones; my harness forbids committing unless you say so. Do you want me to reword or squash the commits that carry this session's work, or leave history to the daemon?
2. **Where a lock wave gets proven.** The pre-commit lock-build gate is unreachable for daemon commits. Do you want a proof off the commit path (a post-commit or timer-driven toplevel keep-going build with an alert), or is §11 at deploy time the accepted gate? You retired the lock-float gate on 2026-11-11 as "more problems than it solves", so I will not build either without your word.
3. **Upstream hashes.** Should I drive the upstream bakes for go-taskqueue and journal (I can run `buildflow -s nix-hash-fix --fix` and commit in those checkouts, but I cannot push, and go-taskqueue had a live session today), or will you bake, push and re-float so both shims can be dropped?

## Evidence index

- `~/.cache/systemnix-fodreuse/section11-before.log`: the 13:27 §11 run (2 FAIL, 18 re-verified).
- `~/.cache/systemnix-fodreuse/section11-after.log`: the 13:53 run (PASS with the false leg 1 half).
- `~/.cache/systemnix-fodreuse/reverify.summary`: 20 reused FODs, rc per check-mode rebuild, both got-hashes.
- `~/.cache/systemnix-fodreuse/classify.txt`: the 12:33 classification of toplevel `327wk58q…`.
- `~/.cache/systemnix-fodreuse/leg1-A.log`, `leg1-B.log`: the 17:03 A/B of the leg 1 build form.
- `~/.cache/systemnix-fodreuse/nscheck-tq.log`: the first check-mode mismatch (go-taskqueue).
- `/var/log/systemnix-deploys/2026-11-27_16-45-21.log`: the latest full battery (§11 green at line 241, check #1 red).
- Receipt store: `~/.cache/systemnix/fod-check-receipts/`.
