# Status Report — go 1.27.2 deploy-eval failure: diagnosis, stale-fix discovery, verification (2026-10-19 02:31 CEST)

**Session:** single Crush session, 2026-10-19 ~02:20 → 02:35 CEST
**Tree state at authoring:** HEAD `a00eecfa7` (heuristic daemon commit, 02:24:23), preceded by `b3f13bbff` (heuristic, same wave). Working tree carries ANOTHER session's in-flight edits (CHANGELOG.md, docs/services/tq.md, docs/todo/stability.md, drive-paperless.nix, sops.nix, tq-agent-pool.nix + test) — a concurrent session is ACTIVE (live `nix eval …systemPackages` from PID 2363091 observed 02:27).
**Trigger:** user-pasted failed deploy: `DEPLOY_FORCE_PRESSURE=1 NIX_HEAVY_GATE_FORCE=1 nix run .#deploy` died in eval with `go-standard: go.mod requires go 1.27.2 but the resolved toolchain is 1.27.1 (auto)` while evaluating `perSystem.x86_64-linux.packages`.
**Scope discipline (per prompt):** report covers THIS session's run and what it directly observed only. No project-wide re-research.

---

## Context (what the session was asked and found)

> **CORRECTION (annotated 02:5x, same session, after authoring):** the root-cause chain below (§ items 2–4) is **WRONG about the thrower**. The concurrent sessions' own closeout (pipeline.md floor row, RESOLVED; source report `docs/status/2026-10-19_00-57_metricnames-sweep-gate-go-live.md` §d/§f) isolated the actual thrower via tryEval-forcing all 18 mkLarsPackages inputs: it was **`projects-management-automation@95bbb843`'s stale `goTarballVersion = "1.27.1"` pin** (added 2026-09-20; its documented drop-condition had fired — locked nixpkgs ships 1.27.2 — while its own go.mod floor had swept to 1.27.2). Fixed upstream-side (pma checkout commit `3397f957`, awaiting owner push) + interim lock rollback to `849573de` (`1a5813174`). This session's floor census (input go.mods) could NOT see that mechanism — PMA's pin is not a go.mod floor, and PMA wasn't in the 9-input list. The diagnosis discipline lesson: a floor census over SOME inputs is not a thrower isolation; tryEval-forcing ALL consumers is. Everything else in this report (stale-fix discovery, green verification, harvests, §b–§g) stands.

The deploy failed at eval time. The session root-caused the toolchain mismatch, then discovered the tree had ALREADY been fixed by a concurrent session minutes earlier, verified the current tree green on three eval surfaces, and stopped short of deploying (mid-edit race with the active session).

Root-cause chain as this session reconstructed it (SUPERSEDED by the correction above for item 2's attribution):

1. The failing assertion is go-standard's go.mod-floor gate (`flake/parts/packages.nix` ← `modules/go-standard.nix` from go-nix-helpers, via `option perSystem`).
2. Floor census of the locked LarsArtmann tool inputs (go.mod fetched per locked rev): **`project-dependency-graph` @ `40bba335` is the only input with `go 1.27.2`**; mr-sync/project-meta sit at 1.27.1, the rest at `go 1.27`.
3. Toolchain state: root nixpkgs lock = `fe1324228`, and `nix eval github:NixOS/nixpkgs/fe1324228#go_1_27.version` = **1.27.2**, default `go` = 1.26.8. The consumer input's own nixpkgs node (`nixpkgs_5`) is the SAME `fe1324228`. So at failure time the auto-resolved 1.27.1 lagged both — unexplained detail (see §f.5); possibly the evaluating go-nix-helpers instance read a different pkgs instance than the raw eval shows.
4. go-standard's fix option space (read from `modules/go-standard.nix` @ go-nix-helpers `0f956520`): `goPkgAttr = "go_1_XX"`, `goPkgOverride`, or the newer `goTarballVersion` + `goTarballHash` (source-tarball build, takes precedence, no `pkgs` needed at flake level). The error text itself documents these three.
5. **Discovery:** the current tree is already green. Heuristic commits `b3f13bbff` + `a00eecfa7` (02:2x, the concurrent session) touched `flake.lock`, `flake.nix`, `lib/lars-packages.nix`, `overlays/linux.nix`, `lib/lock-audit.nix`, discordsync.nix, two CI workflows — the toolchain-wave fix. The user's paste was therefore a STALE failure.

Verification battery on the current tree (all green, ~02:25–02:29):

- `nix eval .#packages.x86_64-linux --apply 'p: builtins.attrNames p'` → 45 packages, including `project-dependency-graph`
- `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` → `/nix/store/fbcccibp…nixos-system-evo-x2-26.11.20261015.fe13242.drv`, exit 0
- `nix flake check --no-build` → **all checks passed** (aarch64-darwin skipped by design)

---

## a) FULLY DONE

1. **Root-cause of the pasted eval failure** — identified the asserting module (go-standard floor gate), the failing consumer's floor context (`project-dependency-graph`, go.mod floor 1.27.2 @ locked `40bba335`), and the resolved-toolchain mismatch (1.27.1 vs floor), including the full fix-option mapping to go-standard's three knobs. ~~Attributed the thrower to project-dependency-graph — see the CORRECTION block above: the actual thrower was PMA's stale goTarballVersion pin; this session's diagnosis narrowed the gate and the mechanism class but MISSED the specific consumer.~~
2. **Stale-fix discovery** — determined the failure no longer reproduces: the concurrent session's `b3f13bbff`/`a00eecfa7` wave fixed it before any double-fix could land. Co-editing the busy tree was correctly avoided.
3. **Current-tree green verification** — packages eval + evo-x2 toplevel eval + `nix flake check --no-build`, all pass on HEAD `a00eecfa7`.
4. **Toolchain floor census of the locked tool inputs** (9 inputs, per-rev go.mod reads) — a fresh enumeration that pins exactly which input drove the gate.
5. **Premise-checked the existing TODO corpus before queueing anything** — found the live go-nix-helpers auto-select row (TODO_LIST:631 / upstream.md:96), confirmed NO existing rows for the catalog-DNS eval warning or the stale toolchain comment.
6. **Self-harvest at authoring time** — §f direct follow-ups landed in `TODO_LIST.md` + domain libraries while writing this report (see the Self-harvest record at the bottom).

## b) PARTIALLY DONE

1. **The session's actual goal — "the deploy works" — is NOT achieved.** Eval-green is proven; the FOD layer is not. Eval gates (toolchain floors, vendorHash shape) are only the FIRST class; the vendorHash wave this lock move implies is exactly the 2026-10-03 class where ~13 FODs re-hashed at once. §11 (`pre-deploy-check.sh --section-11-only`, real FOD builds) has NOT run, `nix run .#deploy` has NOT run, no switch, no anchor check, no §17/§19 post-deploy sweeps. This is the single most important open item.
2. **Attribution/review of the fixing commits** — `git show --stat` read (file lists known), but the CONTENT of `a00eecfa7`/`b3f13bbff` (including the two CI workflow edits) was NOT reviewed. Per concurrent-session discipline I deliberately did not co-verify another session's in-flight work — but it also means "the fix is correct" is asserted by eval-gate passage only, not by review.
3. **go-standard auto-select behavior** — the error text proves the auto mode is now live in the evaluating helper instance (`(auto)` + the goTarball option text), yet it resolved 1.27.1 while the locked nixpkgs ships go_1_27 = 1.27.2. The row at upstream.md:96 says the auto-select obsoletes explicit `goPkgAttr` pins; today's wave WAS a helper lock move (root node `07aefa24`, consumer node `0f956520` — note: TWO helper instances in one lock). The probe-and-drop-pins work is unblocked but not done.
4. **This report's §f list** — written and harvested where it is a direct follow-up of THIS session; the longer tail is brainstorm-grade and intentionally left for a `docs-health` HARVEST pass rather than dumped into the queue (larger-N lists are ROADMAP fuel per the skill's own rule).

## c) NOT STARTED

1. **Deploy retry** — the original ask; gated on the concurrent session quiescing (see §g.1).
2. **§11 FOD batch build** before any deploy attempt.
3. **Content review of the two fixing commits** (incl. `flake-update.yml` / `go-deps-audit.yml` changes).
4. **The auto-resolve 1.27.1-vs-1.27.2 anomaly probe** (why auto lagged nixpkgs' go_1_27).
5. **Catalog-DNS eval-warning triage** (21 subdomains listed as "will vanish from derived DNS once dns-local.nix is deleted").
6. **Stale-comment fix** — `flake.nix:335` still says "go_1_27 = 1.27.1 — the same minor the flake pins"; live value at the locked nixpkgs is 1.27.2 (queued [ready], not fixed in-session: flake.nix is under the concurrent session's active edit).
7. **Cross-project lesson write-up** (reproduce-before-root-cause on shared trees) → `references/lessons.md` in the crush-config repo, by commit — not done in-session.

## d) TOTALLY FUCKED UP

**Nothing at FUCKED severity.** No data loss, no broken state, no wrong claim shipped. Two honest process failures, short of "fucked":

1. **Root-caused a dead failure — and got the root cause wrong while doing it.** ~6 tool calls (gh-api go.mod census, lock-node inspection, nixpkgs version evals, go-standard module fetch) were spent diagnosing the 1.27.2 mismatch BEFORE verifying it still reproduced on the current tree. The tree had been green for minutes while I dug. Worse: the diagnosis LANDED WRONG (attributed the thrower to `project-dependency-graph`'s go.mod floor; the true thrower was PMA's stale `goTarballVersion` pin — see the Context CORRECTION block and pipeline.md's RESOLVED floor row). The floor-census method felt rigorous and was insufficient: a go.mod census over the 9 tool inputs says nothing about a consumer's embedded toolchain PIN. Reproduce-first + tryEval-thrower-isolation (the metricnames session's method) would have produced the right answer in fewer calls. This near-miss is now the concrete argument for §e.1's triage step-0 rule.
2. **Hit the documented jq direnv trap.** A `jq --arg … flake.lock` file-argument form failed with `jq: variable not defined: $r` — AGENTS.md documented this exact class on 2026-10-17 ("FILE-ARG form found same day in this repo"); I had read the AGENTS.md this session. One wasted command; stdin form worked immediately after. Memory internalization failure, cost ≈ 1 tool call.

## e) WHAT WE SHOULD IMPROVE

1. **Reproduce-first on a shared tree.** For ANY pasted failure: step 0 = reproduce on the CURRENT tree (`nix eval` of the narrowest failing surface) + check for an active concurrent session (`pgrep -af nix`, `git log --since=1h`, `git status`). Only then root-cause. The current AGENTS.md session-discipline block has the tombstone rule and the /proc forensics rules, but no explicit "verify the failure still exists" step for failure triage. Candidate one-liner for AGENTS.md (§g.3).
2. **Toolchain-adjacent comments should cite the nixpkgs rev they describe.** `flake.nix:335` ("go_1_27 = 1.27.1") rotted the moment the lock moved past the rev it described. Pattern fix: write "go_1_27 = 1.27.1 at nixpkgs <rev>"; the pin-audit gate already teaches this for input URLs — same hygiene for facts.
3. **stdin-jq as the reflex, not the recovery.** Direnv-loaded shells break jq file args; the documented workaround (stdin / `env -u DIRENV_DIFF`) should be the first form typed, every time.
4. **Deploy-failure triage should end with a "who fixed it / is it pushed" verdict.** The session ended at "already fixed, tree green" — the natural close is also "the fix commits are heuristic daemon commits; if unpushed they deserve proper messages under the daemon-race policy" — flagged, not acted on (not my work; §g.2).
5. **Two go-nix-helpers nodes in one lock** (root `07aefa24` vs consumer-owned `0f956520`) is the known deep-dup class (upstream.md:22) — today it mattered practically: the module that threw the error came from the consumer's copy, not the root's. Fleet-wide infra follows would have made the diagnosis single-instance.
6. **Eval-green must never be reported as deploy-ready.** Keep the three-surface language explicit: eval ✓ / FOD build (§11) ✓ / switch+post-deploy ✓ — this report holds itself to it (§b.1).

## f) Things to get done next (grounded in this session's observations; sorted by impact)

**Deploy-critical path (the wave this session sat on top of):**

1. **[blocked:session] Retry `nix run .#deploy` after the concurrent toolchain-wave session quiesces** — eval is green on HEAD `a00eecfa7`; nothing else has been exercised. (Queued.)
2. **Run §11 FOD batch build first** (`bash scripts/pre-deploy-check.sh --section-11-only`) — the lock move plus toolchain changes imply vendorHash churn across the LarsArtmann Go set (2026-10-03/2026-10-15 classes); ONE `--keep-going` toplevel build enumerates every stale hash before the switch pays for it.
3. **Post-deploy anchor discipline** — `readlink /run/current-system` == latest `system-N-link`, then §17 memory sweep + §19 storage-history freshness (the 2026-10-14 exit-14 class is two-for-two).
4. **Open a pre-reboot gate only if a reboot follows**: `nix run .#pre-reboot-check` (not needed for a pure switch).
5. **Review the fixing commits' content** — `git show a00eecfa7 b3f13bbff`, especially `.github/workflows/flake-update.yml` + `go-deps-audit.yml` (2 changed lines each, unread) and `lib/lock-audit.nix` (2 lines — presumably new lock-edge assertions).
6. **If unpushed: message the heuristic commits properly** — `b3f13bbff` + `a00eecfa7` are daemon "heuristic" commits carrying the whole wave; daemon-race policy says amend-forward with a real message after verifying what the daemon staged (`git show --stat`). Owner/concurrent-session call, not this session's.
7. **Update the stale toolchain comment** — `flake.nix:335` "go_1_27 = 1.27.1" → 1.27.2 at `fe1324228` (queued [ready]; two-line fix, deliberately not edited mid-session in a file the other session is actively touching).
8. **Probe the auto-resolve anomaly** — go-standard auto resolved 1.27.1 while locked nixpkgs' `go_1_27` = 1.27.2 (verified by direct eval); find which pkgs instance the auto path reads. Feeds item 9's confidence.
9. **go-nix-helpers auto-select row (upstream.md:96 / TODO_LIST:631)** — today's wave moved the helper lock (root `07aefa24`, consumer `0f956520`): the row's "next lock move" trigger has FIRED. Probe a representative consumer FOD before/after, then drop the explicit `goPkgAttr = "go_1_27"` pins in consumer flakes one at a time (upstream repos → blocked:push). Datapoint added to the row this session.
10. **PMA forward relock** (TODO_LIST:1541, blocked:push) — directly adjacent: its upstream comment names the same `fe1324228` nixpkgs and the same 1.27.2 fact this session verified live.
11. **go-licenses overlay drop-condition check** — condition "nixpkgs default go ≥ 1.27": live default = 1.26.8 → condition NOT met, block stays. Re-check on the next nixpkgs bump (verified live this session so the sweep row's premise is current).
12. **Expired-shim sweep in overlays/shared.nix** (TODO_LIST:976 [ready]) — the sops-nix > `13616fff` and playwright conditions were NOT probed this session; the sweep remains open and this session confirmed the file still carries all three shims.
13. **GOTOOLCHAIN shell-removal follow-ups** (TODO_LIST:866) — amend-forward `2e3ca9e1` + post-deploy `go env GOTOOLCHAIN` probe; the 1.27.2 wave makes the probe MORE relevant (floors now sit above the old 1.27.1 shell go).
14. **Tile-logo wave deploy** (TODO_LIST:1539 [blocked:deploy]) — rides the same next deploy window.
15. **Catalog-DNS eval warning triage** (queued [ready]) — every evo-x2 eval prints 21 subdomains ("catalog, cache, banksync, history, daily, discordsync, renamer, status, immich, inbox, llama, monitor, mr-sync, overview, dash, paperless, search, signoz, graph, timers, tq") that "will vanish from derived DNS once dns-local.nix is deleted". Decide per-subdomain: add catalog entries or accept the vanish. Live-observed this session on the toplevel eval.

**Adjacent toolchain/lock debt the session touched but did not open:**

16. **Two go-nix-helpers lock nodes** — fold into the fleet infra-follows wave (upstream.md:22 [blocked:push]); today's diagnosis cost is the concrete argument.
17. **`go-standard.proxyVendor = true is ignored` eval warning** (TODO_LIST:670 / upstream.md:97 [ready]) — fires on evals; this session saw eval warnings again during the toplevel eval.
18. **DiscordSync FOD hash-invariance root-cause** (TODO_LIST:591 [ready]) — same helper surface, still open.
19. **bank-sync go-nix-helpers alias contradiction** (TODO_LIST:635 [ready]) — decide follow-vs-non-follow before the next clean relock re-hashes its FOD; this wave shows how often "next relock" comes around.
20. **bank-sync nixpkgs un-follow decision** (TODO_LIST:1166 [decision]) — owner call, same toolchain-skew family as everything above.
21. **go-nix-helpers own-pinned consumer sweep** (TODO_LIST:1089 [ready]) — 4 independent lock nodes; the wave keeps proving lock-copies are a live failure amplifier.
22. **monitor365 back on the package surface** (packages.nix comment, 2026-10-18) — master-tracking heavy Rust workspace now evals into `packages`; §11/§13/§16 pre-deploy battery will surface its FODs — budget for it in item 2.

**Process/docs follow-ups owned by this session's lessons:**

23. **Write the reproduce-before-root-cause lesson** to crush-config `references/lessons.md` (by commit; [blocked:push]-equivalent — different repo).
24. **AGENTS.md session-discipline candidate line** (owner call, §g.3): "failure triage step 0: reproduce on the current tree + concurrency probe; never root-cause a failure another session may have already fixed."
25. **Comment-hygiene pattern** (item 7 generalized): rev-cite toolchain facts in comments — candidate for docs/CONTRIBUTING.md contributor style section.

**Watch items live-observed this session (no action derived yet):**

26. **aarch64-darwin leg unchecked** — `nix flake check` skipped it (expected, documented); any darwin-affecting fallout of this wave is invisible until the Mac builds.
27. **Lock-audit growth** — `lib/lock-audit.nix` gained 2 lines in the wave (new enforced edge?); unreviewed, listed for item 5's review pass.
28. **qmd / paperless-gpt-src / nixpkgs-llama-rag pins** — the pin-audit banner fired on every eval this session; all three LIFT conditions unchanged (llama.cpp 0.4.0 regression, tag hashes, qmd CLI verify) — nothing new, recorded for completeness.
29. **Forgejo Actions log-transfer regression #14843** (services.md:51 [watch]) — instance still 15.0.10; unrelated to this wave, untouched.
30. **First real push-triggered Actions runs on G2 repos** (services.md:53 [ready]) — untouched, adjacent only via the workflow files the wave touched.

(30 grounded items; the "up to 50" budget is deliberately not padded — items 16–30 already draw on pre-existing rows re-confirmed this session, and everything beyond would be invention, not observation.)

## g) Questions I cannot answer myself

1. **Deploy timing vs the active session:** the toolchain-wave session is live RIGHT NOW (in-flight tq/sops/paperless edits + a running `nix eval`). Do you want me to hold the deploy retry until you confirm that session is done (my recommendation), or take over the deploy now and accept the mid-edit race + co-verification duty for its uncommitted files?
2. **Ownership of the fix commits:** were `b3f13bbff` + `a00eecfa7` authored by your other session as the deliberate fix for THIS deploy failure (reviewed, intended — in which case I leave commit-message cleanup to them), or are they daemon-swept accidents you want me to amend-forward with proper messages if unpushed?
3. **Where the triage lesson lands:** should I add the "reproduce on current tree + concurrency probe as step 0 of failure triage" line to this repo's AGENTS.md Session Discipline now (committed here), and/or commit the generalized lesson to crush-config `references/lessons.md` — or hold both until you've read §d/§e?

---

## Self-harvest record (authoring-time, per the status-report rule)

Landed while writing this report:

- **Queued [ready]** — deploy retry + §11-before-deploy sequence → `TODO_LIST.md` queue + `docs/todo/pipeline.md`.
- **Queued [ready]** — stale toolchain comment `flake.nix:335` → `TODO_LIST.md` queue + `docs/todo/pipeline.md`.
- **Queued [ready]** — catalog-DNS eval-warning triage (21 subdomains) → `TODO_LIST.md` queue + `docs/todo/services.md`.
- **Updated existing row** — go-nix-helpers auto-select (upstream.md:96): today's helper lock move recorded as a fired trigger + the 1.27.1-vs-1.27.2 auto anomaly datapoint + the corrected thrower cross-ref (no new row; TODO_LIST:631 one-liner unchanged in meaning).
- **Cross-ref discipline:** this report's wrong thrower attribution is corrected inline (Context block) and defers to the RESOLVED floor row in `docs/todo/pipeline.md` + the 00:57 metricnames report as the authoritative diagnosis surfaces.

Deliberately NOT harvested (with reasons):

- **Items 1–4, 5–6, 8–10, 13–14** — live in this report as the deploy window's runbook (§f order matters); queueing a "deploy" row duplicates item 1's row (landed) and §b.1's content. Items 5/6/8 are owner/concurrent-session-gated (see §g.1/§g.2).
- **Items 23–25** — blocked on §g.3 (owner call on placement).
- **Items 16–22, 26–30** — pre-existing rows in the domain libraries, re-confirmed this session; no new facts beyond what those rows already carry (drift rule: no parallel entries).
- **§d process failures** — lessons, not tasks; §e carries them; §g.3 gates the durable landing.
