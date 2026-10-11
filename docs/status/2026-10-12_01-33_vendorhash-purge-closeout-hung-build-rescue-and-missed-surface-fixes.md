# Status: vendorHash-purge close-out, hung-build rescue, missed-surface fixes (2026-10-12, 01:33 CEST)

**Session scope:** the close-out of the 2026-10-11 23:41 vendorHash shim-purge session — its §f harvest, its pending verification verdict, and the two real defects the verdict exposed. Trigger: user's standing READ/UNDERSTAND/RESEARCH/REFLECT loop + "keep going until everything works".

**End state: evo-x2 toplevel build EXIT 0, flake check --no-build --all-systems GREEN, all lint legs clean, harvest fully landed. Commits: `6a537d39` (harvest + gitleaks scanner FP), `8dcba7bc` (two missed-surface fixes), `13074ccf` (daemon-swept fmt + ledger, heuristic message), plus daemon/parallel commits `f8765023`, `ca7c9b29`.**

---

## a) FULLY DONE

1. **Daemon-commit review debt cleared** — `ac4099bc` (the rev the prior report flagged "NOT yet reviewed") contains ONLY the parallel session's TODO_LIST/services.md rows; my actual edits had landed across `215c98ab`/`25966d73`/`628f73c2`/`d397fde8`/`ed5f369c` interleaved with foreign doc files. Every one `git show --stat`-verified.
2. **Hung-build diagnosis and rescue** — the prior session's "final toplevel build STILL RUNNING (0 errors)" was a LIE BY OMISSION: the client (`nix build` PID 3350520) plus BOTH its daemon workers had slept ~0 CPU for 4h with NO builder process (log frozen since 20:25; client stuck in `unix_stream_read_generic`; the only nix client on the box). Kill → workers released (one transient D-state, exited cleanly, /nix I/O verified healthy, no OOM in kernel log) → restarted fresh. Completed 20 minutes of work was store-cached; nothing lost.
3. **Missed surface #1 — pdd service module** — the wave8 drop cleaned `lib/lars-packages.nix` but `modules/nixos/services/project-discovery-daemon.nix:56` still specified `Mrn25ftf…` while the lock (ea6e8ce9) bakes `6ZDAkBB…` upstream (`flake.nix:60` — verified live). Specified-vs-got mismatch blocked the toplevel. Override dropped with a drop record naming the BOTH-surfaces trap (PMA wave5 precedent, now 2×).
4. **Missed surface #2 — crush-daily doCheck** — the wave8 drop record claimed "the doCheck leg's blocker is fixed upstream" — true for the chromedp API break ONLY; the known-red `TestGenerator_Generate_GoldenFile` still fails the sandbox checkPhase and blocked the toplevel. Gate re-added as `crushDailyDoCheckGate` (doCheck=false ONLY, vendorHash leg stays dead), with the corrected drop record inline.
5. **Overlay-order bug found and fixed** — my first gate placement sat BEFORE `crush-daily.overlays.default` in the overlays list; the input's overlay recreates `pkgs.crush-daily` and clobbered the gate (drv hash unchanged `xhpf7k9d…`, rebuild failed identically). Moved AFTER the input entry → drv hash changed to `l1da7a4z…` → checkPhase gone → **restart #3 TOPLEVEL EXIT 0** (`/tmp/toplevel-fix-20261012c.log`, 0 FAIL lines).
6. **Full verification chain green** — `nix flake check --no-build --all-systems` ("all checks passed!", `/tmp/flakecheck-final.log`); alejandra (`--ci`, 0 changed after a fix), statix, deadnix clean on every touched .nix file; `gitleaks-coverage-selftest` builds green after a config touch.
7. **§f harvest (the prior report's standing obligation)** — 17 `[ready]` one-liners into `TODO_LIST.md`, rows into `docs/todo/{upstream,services,pipeline}.md` (29 rows total incl. tags), the fleet infra-follows row enriched with the live pdd two-context datapoint + 7-repo instance list, and a disposition ledger appended to the prior report (all 40 §f items: done/dedup'd/folded/deliberately-not).
8. **Stale queue row killed** — the art-dupl row still asked for the `eabf846c` push; wave7 had landed `63003892`, shim long gone, lock verified == `63003892` live before closing. Row marked `[x]` with post-state.
9. **Docs sharpened with this session's lessons** — `docs/agents/nix-flakes.md`: the orphan-node bullet now carries the 2026-10-11 drop-record falsification (7142e43d vs true f12a849b) + the resolve-via-`root.inputs` command; the CV-chain bullet's "rev-scoped hash" corrected to (rev, the input's OWN flake.lock state) with the pdd same-day-restale case. `docs/agents/go-ecosystem.md`: measure-at-target-rev rule + the full chromedp v0.16→v0.19 migration pattern (fleet-exposure doc).
10. **gitleaks scanner FP fixed at the SCANNER** — the commit-blocking finding was `finish_reason=stop` (OpenAI response enum) quoted in llama-chat.md prose, landed via daemon sweep `e10611cf` past the hook on 2026-10-10 and wedging every manual commit since. Adjudicated FP, enum-family allowlist entry added with precedent-style evidence comment; full staged-tree rescan = "no leaks found"; selftest green. Plus a pre-existing `[ready]` queue row de-time-worded ("tonight's" → "the storm-window") that tripped the TODO gate.
11. **Wave8 correction recorded where it lied** — `docs/todo/upstream.md` wave8 bullet + crush-daily `[x]` row corrected (2026-10-12 CORRECTION paragraph: which surfaces, what post-state); the `TestGenerator_Generate_GoldenFile` library row now says it BLOCKS THE TOPLEVEL and keeps the gate alive.
12. **Commit-message hygiene salvaged under daemon race** — `8dcba7bc` carries the proper two-surface-fix message (amend-forward over the daemon's heuristic commit after `git show --stat` verified all 4 files mine, branch verified unpushed ahead-15).

## b) PARTIALLY DONE

1. **Commit-message quality on `13074ccf`** — the daemon swept my fmt fix + report-ledger edit into a heuristic commit; TWO amend attempts failed (ref moved to `13074ccf` mid-amend; retry blocked by gitleaks on the parallel session's freshly staged content). Contents verified 100% mine; the heuristic MESSAGE stands as debt.
2. **The overlay-order lesson is documented in the overlay list comment only** — NOT yet in `docs/agents/nix-flakes.md` where fleet-wide lessons live (I wrote the inline comment, then moved on). This is a gap I noticed while writing this report.
3. **cqrs-lint upstream fix** — shim verified NECESSARY with fresh evidence (orphan-trap-corrected rev f12a849b; master `c1993ba3f` bakes `9y6O/R2f…`; repo mid-churn, 21 unpushed commits). Upstream work itself remains blocked on the repo settling — unchanged from wave7, now with sharper evidence.
4. **Coordination with the parallel session** — I detected and dodged their in-flight edits (services.md mid-write race ×2, then `.githooks/pre-commit`/`.gitleaks.toml`/negative-tests.yml deletion), but never RESOLVED the potential conflict: my committed `.gitleaks.toml` allowlist entry vs their live edit of the same file, and the fate of the deleted `negative-tests.yml` workflow (AGENTS.md's Prevention-Layers table still cites it).

## c) NOT STARTED

1. All 17 harvested `[ready]` queue rows (by design — dispatched via the tq pool, not by this session): go-cqrs-lite 164-file wave classification, md-go-validator CI glance, niri/clickhouse/bun+swagger overlay drop checks, crush-daily LOCKSTEP pin + nix-check browser suite + doCheck verify-once + probe lint, orphan-rev static check, docs orphan-rev sweep, drop-comment graveyard compaction, vendorHash-citation selftest, root.inputs convention, blocked:push semantics doc, .nix standalone-lint rule, chromedp fleet survey.
2. The two `[decision]` rows (crush-daily golden-update mechanism unification; daemon commit-message mechanism).
3. The pdd-driven follows-alignment work itself (evidence recorded in the fleet row; the 7-repo execution is upstream work, `[blocked:push]`).
4. The wave8 session's still-open §g questions (see g) — the 3 from the prior report remain unanswered and now also gate the `[blocked:user]` crush-daily rows.

## d) TOTALLY FUCKED UP

1. **I wrote "DONE … dropped the gate BOTH legs" into `docs/todo/upstream.md` BEFORE the verifying build had exited — again.** The prior session was already burned by exactly this class (evidence claims written before enumeration ran); I repeated it in the harvest. The correction cycle (CORRECTION paragraph + row fix + ledger) was pure self-inflicted rework. Sequence is verify → write, never write → hope.
2. **Overlay-order mistake, full rebuild cycle wasted.** The list I edited literally contains six `*.overlays.default` entries that CREATE packages; I placed my gate above the one it gates. The failed restart ran ~25 min under load to reproduce the identical failure. Worse: I had a cheap probe available (eval the toplevel `drvPath` — eval-only, would have shown the unchanged drv) and instead burned the rebuild as the probe after my two clever `--impure` eval probes failed on syntax/`_module`-visibility. Three strikes: wrong order, no cheap probe, gave up probing too easily.
3. **Trusted the summary's "build STILL RUNNING, 0 errors" premise without a liveness check.** I read log CONTENT before file MTIME — the log had been frozen for 4 hours and "0 errors" was technically true of a dead build. I nearly carried a false "in flight" claim into the ledger (the first ledger revision said "verdict watched to completion (see below)" pointing at nothing). An `ls -la` one-liner settles liveness; content reading without mtime is theater.
4. **Amend #3 fired without re-checking `git status` for newly staged foreign content.** The parallel session had staged `.githooks/pre-commit`/`.gitleaks.toml` edits seconds earlier; my amend's gitleaks leg then scanned THEIR staged tree, found a leak, and failed — a wasted cycle and a moment where I could have committed a tree state containing foreign half-done work if the leak hadn't blocked it. The shared-tree rule (check what's staged before every git write) exists; I applied it to my commits but not to my amends.
5. **Two mod-time edit races on files I'd already read** (`docs/todo/services.md`, the status report) — the tool refused, I re-read, re-applied. Minor, but each is a round trip that a fresh `git status`/View before editing would have saved; the mid-edit-race doctrine says re-read EVERY time in this tree.
6. **First statix invocation was a syntax error** (multi-target usage) and my exit-code echoes initially captured the pipe's exit, not the tool's — sloppy shell hygiene in a session whose whole point was verification rigor.

## e) WHAT WE SHOULD IMPROVE

1. **Make "in-flight/running" claims require an mtime+PID proof.** Add to the nix-flakes/systemd runbooks: long-build checks start with `ls -la <log>` (mtime) + builder-process existence, never log content alone. Content says nothing about liveness.
2. **Close the write-ahead-verification loophole for docs.** The correction rule catches these after the fact; the cheaper fix is sequencing: a durable "DONE/X dropped/gate removed" sentence may only be WRITTEN after the artifact that proves it exists (build exit, drv path, test output). Consider a pre-commit grep gate: rows claiming "DROPPED <date>" whose same line cites no artifact (log/drv/exit) get flagged — machine-checkable.
3. **Overlay-order doctrine into `docs/agents/nix-flakes.md`** (not just the inline comment): "an override on an input-provided package must be listed AFTER that input's `overlays.default`; verify with an eval-only drvPath probe before any rebuild."
4. **Second-surface inventory as a mechanical step.** BOTH-surfaces has now bitten twice (PMA wave5, pdd wave8). The planned `lars-packages.nix` selftest (§f.24) should grep `modules/nixos/**` for the same `overrideAttrs { vendorHash` pattern too, and the drop protocol gains a mandatory `grep -rn "<pkg>" modules/ lib/ overlays/` before declaring a shim fully dropped.
5. **Cheap probe reflex.** Before ANY full toplevel rebuild to "see if it worked": `nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` (eval-only, seconds) and compare against the failed run's drv — drv unchanged = fix didn't bind, no rebuild needed. This would have saved the clobbered-gate rebuild entirely.
6. **Shared-tree amend discipline:** `git status --short` immediately before EVERY amend (not just commits); abort if any staged path isn't mine. The race window between add and amend is where the daemon lives.
7. **Daemon-sweep message debt is accumulating** (3 heuristic messages in two sessions where races beat proper messages). The `[decision]` row (daemon commit-message mechanism) deserves owner attention — every heuristic commit is a future archaeology tax.
8. **Parallel-session coordination surface.** This session had: mid-write file races ×2, a daemon commit race ×2, and a same-file (`.gitleaks.toml`) concurrent edit. A session-start "who else is editing" check (pgrep other crush instances + dirty-file inventory) would set expectations explicitly instead of discovering them via tool refusals.
9. **House limits in muscle memory:** 72-char subjects, the TODO-gate time-word list (`tonight|tomorrow|re-dispatch after|…`) — both cost a blocked commit each. Cheap: count the subject before writing; grep the row for gate words before queueing.

## f) NEXT (≤50, prioritized)

**Immediate (this-week, small):**
1. Add the overlay-order + eval-probe doctrine to `docs/agents/nix-flakes.md` (from e.3/e.5 — the inline comment alone will rot).
2. Extend the planned vendorHash selftest to scan `modules/nixos/**` for second surfaces (e.4; makes BOTH-surfaces mechanical).
3. Re-read the parallel session's committed `.gitleaks.toml`/`.githooks/pre-commit` changes for conflict/duplication with my `finish_reason` allowlist entry and my assumptions.
4. Investigate the unidentified "leaks found: 1" from their staged content (blocked my amend; if it landed in `ca7c9b29`, the tree carries a new finding).
5. Adjudicate the deleted `.github/workflows/negative-tests.yml` — AGENTS.md's Prevention-Layers table still cites it; either restore a CI home for the negative-test harness or update the table.
6. Deploy readiness: the toplevel is green but NOT deployed — `nix run .#deploy` when an IO window opens (pdd + crush-daily + discordsync/dnsblockd hash-neutral changes ride this switch), then post-deploy smoke (`scripts/post-deploy-check.sh`).
7. Answer §g below — three of the queued rows are gated on it.

**Harvested `[ready]` rows now sitting in the queue (execute in dispatch order):**
8. go-cqrs-lite: classify the 164-file origin/master wave before any cqrs-lint hash paste (upstream.md).
9. md-go-validator: confirm own CI green with `e+jOFi3m…` under its own lock (upstream.md).
10. niri libdisplay-info shim drop check (upstream.md).
11. clickhouseVersionPinOverlay drop check (upstream.md).
12. bunMemoryLimitOverlay + monitor365SwaggerUiFixOverlay drop re-verify (upstream.md).
13. crush-daily: templ-components LOCKSTEP pin reconcile + goldens (services.md).
14. crush-daily: full `TestUI_` suite inside a nix check (chromium as checkInputs) (services.md).
15. crush-daily: re-enable + verify doCheck end-to-end once the golden test resolves; document the sandbox browser-skip (services.md).
16. crush-daily: CI leg against throwaway probes (services.md).
17. Static check: FAIL shim drop-comments citing non-`root.inputs` revs (pipeline.md).
18. Sweep status reports/docs for orphan-rev citations (pipeline.md).
19. Compact the lars-packages/linux.nix drop-comment graveyard (pipeline.md).
20. lars-packages selftest: vendorHash overrides REQUIRE enumeration-log citations (pipeline.md).
21. CONTRIBUTING: drop claims must cite `root.inputs`-resolved revs (pipeline.md).
22. Docs: record the "user directive overrides `[blocked:push]`" case (pipeline.md).
23. CONTRIBUTING daemon-race section: extend standalone-lint re-run rule to .nix (pipeline.md).
24. Fleet chromedp-pin survey (pipeline.md).

**Carried, higher-order (blocked/decision lanes):**
25. crush-daily `TestGenerator_Generate_GoldenFile` disposition (gates #15 + the doCheck gate) — `[blocked:user]`.
26. crush-daily `TestLegacySnapshotRow_DecodesUnderNewStack` fix — `[blocked:user]`.
27. cqrs-lint upstream paste once go-cqrs-lite settles, then re-lock + drop the shim (treadmill: root-nixpkgs follower).
28. Fleet infra-follows alignment (pdd + 6 siblings; the regrowth 387→454 evidence row) — `[blocked:push]`.
29. Daemon commit-message mechanism decision — `[decision]`.
30. crush-daily golden-update mechanism unification — `[decision]`.
31. Re-check the vendorHash-refresher fleet after the NEXT root nixpkgs wave — `[watch]`.
32. Pre-existing crush-daily reds' BuildFlow close-the-loop (tag known-red in repo AGENTS.md if unfixed) — folded into #25.
33. md-go-validator/pdd two-round lesson already in go-ecosystem.md — verify the chromedp pattern bullet survives the next doc sweep (fresh, unreviewed by a second pair of eyes).
34. Consider making hung-build detection mechanical: a post-build-log mtime staleness check in deploy.sh or the tq harness (e.1 made doctrine; this makes it code).
35. `git config`/hook timing for daemon races — folded into #29.

(35 substantive items; the remaining queue mass lives in the libraries the harvest created — dispatching the 17 `[ready]` rows IS the next batch.)

## g) QUESTIONS FOR YOU (cannot answer myself)

1. **crush-daily `TestGenerator_Generate_GoldenFile` disposition** — is the report-golden drift intended (→ I run `go test ./internal/report/... -update` upstream and drop the doCheck gate), a real regression someone owns, or should the test be tagged known-red upstream? This now BLOCKS the toplevel-cleanliness of every crush-daily rev (the gate stays until you answer).
2. **Push authority scope (carried from the prior report, still unanswered)** — I pushed to crush-daily, md-go-validator, and project-discovery-daemon master under "fix all upstream". Was that (a) this task only, (b) standing for vendorHash fixes, or (c) standing generally? The `[blocked:push]` label semantics for future sessions depend on it.
3. **The parallel session's pre-commit/gitleaks edits + `negative-tests.yml` deletion** — is that session sanctioned to restructure the prevention layers (AGENTS.md's table cites the deleted workflow), and should my committed `finish_reason` allowlist entry survive their concurrent `.gitleaks.toml` rewrite, or are they replacing the allowlist approach wholesale? I can't see their intent from diffs alone and won't touch their files.

---

**Verification artifacts:** `/tmp/toplevel-fix-20261012.log` (restart #1, 2 failures), `/tmp/toplevel-fix-20261012b.log` (restart #2, clobbered gate — the overlay-order proof), `/tmp/toplevel-fix-20261012c.log` (restart #3, EXIT 0), `/tmp/flakecheck-final.log` (all-systems green), `/tmp/gitleaks.log` (the FP finding).
