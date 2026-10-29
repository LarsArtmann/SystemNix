# Status Report — Lock-float wave unblock: cv/crm/journal vendorHash shims + media-atlas build-gate fix

**Session window:** 2026-10-29 ~17:50 – 18:56 CET
**Author:** Crush agent session (trigger: owner frustration "flake/expected-locks.nix is stupid — I want to be able to update", followed by a pasted RED float-register proof from `nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`)
**Final state at writing:** SystemNix @ `27f2813a1` (my wave lands in `97c08f88b`, `ee6bf1600`, `4881815bf`); the 2026-10-29 float wave (16 floated inputs) is **registered, proven (toplevel keep-going rc=0), and eval-green at HEAD — deployable**. evo-x2 still runs gen-939-era config; the deploy itself is owner-gated.
**Scope:** this report covers ONLY this session's work and what it directly observed. A parallel crush-0.99.0 session was live the whole window (its own report: `docs/status/2026-10-29_18-33_crush-0990-session-brutal-self-review-and-status.md`; its plan: `docs/planning/2026-10-29_18-42_SUPERB-crush-0990-rollout-finish-and-hardening.md`). I read the top of their report mid-session; I have NOT read their §3 or their new plan doc.

---

## 0. What actually blocked the update (the one-paragraph answer to the owner's complaint)

The float gate was never the blocker — the gate worked exactly as designed. The blocker was that the floated revs **don't build**: three stale go-modules vendorHashes (cv@e168e6d, kith-crm@f1d40c9, journal@50b4941 — each repo's flake bakes a spec hash its module graph no longer produces) plus one brand-new module bug (media-atlas key-provision shellcheck SC2034). The gate converted "silent DOA deploy" into "loud, enumerable, fixable RED proof" — the `--keep-going` proof listed ALL FOUR roots in one pass, which is the anti-domino discipline working. The update was unblocked by consumer-side shims + one dead-var deletion, not by weakening the gate.

---

## a) FULLY DONE

1. **Root-caused the RED float proof** — 3 hash mismatches + 1 builder failure, all first-hand from `~/.cache/lockfloat/float-proof-20261029-180630.log`; verified the log held EXACTLY 3 FOD mismatches (no hidden roots behind the "Cannot build" cascade).
2. **cv vendorHash shim, 11th re-stale bump** — cv@e168e6d spec `autqYveR` → got `g1hKglo1…`, evidence-dated comment appended (`modules/nixos/services/cv.nix:119-124`). Proven green in the final proof.
3. **crm vendorHash shim bump** — kith-crm@f1d40c9 spec `XDRvpM8` → got `LpMsryrv…` (`modules/nixos/services/crm.nix:110-115`). Proven green.
4. **journal vendorHash shim at all THREE consumption sites** — spec `R6w7rVD9` → got `OzU6YCvB…`: `lib/lars-packages.nix:262-272` (flakePkgShim), `modules/nixos/services/journal-serve.nix:64-76`, `modules/nixos/services/journal-backup.nix:70-82`, with "edit ALL THREE" cross-references. Proven green. (Finding the third site is §d.2; the fix itself is complete.)
5. **media-atlas key-provision dead-var fix** — `url="${hubCfg.immich.url}"` was declared-but-unused (provisioning is DB-direct via psql INSERT, no HTTP calls), failing the writeShellApplication shellcheck gate; removed (`modules/nixos/services/media-atlas.nix:167`), committed `4881815bf`. Proven green.
6. **Float pair landed at HEAD** — registry regenerated from flake.lock, proven rc=0, committed `4881815bf` with a hook-compliant message via PATHSPEC commit (the daemon's own attempt had been hook-rejected — see §d.4).
7. **Cheap green-eval probe at HEAD** — `nix eval …toplevel.drvPath` passes: lock-float gate green, pins audit green, toplevel evals. The wave is deploy-ready.
8. **Repo formatter run on every edited file** — `nix fmt -- <paths>` scoped form, 0 changes needed on all five files.
9. **Parallel-session hygiene held** — their staged workflow edits, `docs/todo/pipeline.md`, and `crush-daily.nix` modifications were flagged and left untouched throughout; no cross-session reverts.
10. **Self-harvest completed at authoring time** — session follow-ups landed in `TODO_LIST.md` (+2 queue rows services, +1 pipeline), `docs/todo/upstream.md` (paste-upstream row), `docs/todo/services.md` (2 rows), `docs/agents/nix-flakes.md` (the false-"daemon landed" trap). Details in the harvest record at the bottom.

## b) PARTIALLY DONE

1. **The float wave adoption overall** — consumer side is proven and deployable, but the upstream half of each fix is absent: all three repos still bake stale hashes, so the shims are debt that re-fires on the next float (cv is on its 11th cycle). The paste-upstream cycle is queued `[blocked:push]` in `docs/todo/upstream.md`.
2. **The journal shim** — works, but it is a THREE-site split brain by construction; consolidation to one consumer is queued `[ready]`. Also its necessity is not fully resolved: the parallel session's report claims "journal builds green standalone, rc=0" while TWO toplevel proofs got the same deterministic FOD mismatch. Either their standalone probe rode my shims sitting on disk (edits landed 18:21–18:27, their report window ends 18:30), or the FOD content genuinely flapped (the re-served-dependency class cv.nix documents). A shim-less rebuild probe is queued; until then the shim stays.
3. **The crush-0.99.0 rollout (parallel session's work, observed)** — their nur float is registered and the crush 0.99.0 package built green in our proof; the deploy + soak that finishes their rollout is still pending and will ride the same deploy as my wave.
4. **The CI workflow edits (parallel session's, observed dirty then committed as `27f2813a1`)** — I did NOT verify them; per the shared-tree rule, my "proof green" covers my files only. They touched `flake-update.yml`, `go-deps-audit.yml`, `negative-tests.yml`, `nix-check.yml` — the first CI run on each is the real test.

## c) NOT STARTED (this session; standing items the wave keeps pointing at)

1. **The deploy itself** — owner-gated (`DEPLOY_FORCE_PRESSURE=1` was needed at 18:06; sda sat at 102.7% util with two ghostty scopes at ~100% IO PSI).
2. **Paste-upstream vendorHash cycle for cv/crm/journal** — queued, not started.
3. **Journal shim consolidation** — queued, not started.
4. **float-register hardening (subject limit + false-success check)** — queued, not started.
5. **All seven deliberate input pins remain** — hermes-agent (patchelf #672), nixpkgs fe13242 (needs green aw-core + linux-7.3-modules proof), nixpkgs-llama-rag (0.4.0 spin regression), nsfw-classifier (upstream telemetry refactor doesn't compile), paperless-gpt v0.28.0, qmd v2.8.3, signoz-src 375b3f83. Every eval prints them; none lifted today.
6. **media-atlas module end-to-end review** — queued for the owning session, not started.

## d) TOTALLY FUCKED UP (my own failures this session, no varnish)

1. **One entire heavy toplevel build wasted by skipping a 2-second precondition check** — job `010` (18:2x) launched `nix build …toplevel` while the lock-float gate was mid-drift (the parallel session had regenerated the registry against a different lock state); the build died AT EVAL on the gate. The AGENTS.md deploy-vs-executor pattern I was operating under explicitly prescribes the cheap green-eval probe FIRST (`nix eval …drvPath`). I knew the rule, didn't apply it to a non-deploy build. Cost: several minutes of IO under an already-storming disk.
2. **Missed the third journal consumption site on the first pass** — I grepped `inputs.journal` only in the two files I already knew about; `journal-backup.nix` surfaced only after the next proof failed with the IDENTICAL drv path (which is the tell: same drv = override absent from graph). A full `rg "inputs.journal"` BEFORE the first edit would have found all three sites immediately. Cost: one wasted proof cycle + a false "fixed" intermediate state.
3. **Skipped the docs/status pre-read discipline at session start** — the 2026-10-23 rule (grep `docs/status/` + `docs/todo/` for the error signature before diagnosing anything pasted) would have surfaced the parallel session's untracked 18:33 report — including their (wrong, see b.2) journal claim and their in-flight float work — before I built anything. I found their report accidentally, via daemon-commit archaeology, ~40 minutes in.
4. **Trusted float-register's success line for one dangerous moment** — the script printed "the auto-commit daemon landed the pair during the proof — content verified, nothing to do" while `git log` showed NO new commit (the daemon's attempt had been hook-rejected on the 197-char subject). I caught it by checking `git status` out of daemon-race habit, not because I doubted the script. The pair sat staged-and-uncommitted; only the on-disk registry kept evals green. This trap is now documented in `docs/agents/nix-flakes.md` + queued as a script fix — but the false-negative message shipped and I nearly shipped with it.
5. **Attribution mess I contributed to** — the daemon swept my cv.nix/crm.nix edits into a commit that also carried the parallel session's 4 workflow files + flake.lock (`97c08f88b`, 7 files). PATHSPEC commits were the documented protection and I used them for MY final commit, but the earlier edits sat unprotected during the sweep window. The workflow edits are theirs, the lock is the owner's update, my two files ride along — `git log` attribution for that commit is now permanently mixed.

## e) WHAT WE SHOULD IMPROVE

1. **Kill the vendorHash treadmill at the root, not the 12th shim.** cv has ELEVEN dated RE-STALE entries in one comment chain; crm five; journal one and counting. Every cycle: float → RED → read got-hash → bump shim → re-prove. The paste-upstream ritual (bake the got hash at the locked rev, push, re-lock, drop shim) is documented but has never been run for these three. One owner-approved push session retires the whole class.
2. **One consumer per input.** journal proved the failure mode: three files each independently deriving from `inputs.journal` means every future re-stale needs three synchronized edits and a proof to discover you missed one. cv/crm get away with one site each, but the pattern should be: service modules consume the package THROUGH `lars-packages`, never directly from `inputs.*`.
3. **The cheap green-eval probe belongs BEFORE every heavy build, not just deploys.** `nix eval …drvPath` is seconds; a toplevel build under IO storm is minutes. Make it muscle memory for float-register follow-ups too.
4. **float-register's green path needs a commit-existence assertion** — and its commit message needs to fit the house 72-char limit (input count in the subject, list in the body). Today the failure chain was: daemon commit → hook reject → silent staged state → FALSE success message. Two queued script fixes close it.
5. **The pre-read discipline needs to be automatic, not remembered.** The 2026-10-23 rule fired again: a 10-second `rg` would have saved a duplicated investigation. The parallel session is ALREADY building PostToolUse/SessionStart hooks in crush-config — a SessionStart hook that surfaces the newest untracked `docs/status/` files would mechanize this rule. Tell them; it's a natural addition to their hook set.
6. **Cross-session claims need a "which surface did you actually build" check.** The parallel session's "journal builds green standalone" close-out is either a sub-proof (built a different path than the failing one) or evidence of a flapping FOD — both are important, neither is resolved. The AGENTS.md "assert WHICH question your evidence answers" rule applies to status-report claims between sessions, not just deploy close-outs.
7. **The registry/lock pair should never be committable separately.** Today: lock in one daemon commit, registry regen staged-uncommitted, a THIRD registry state committed earlier by the other session that didn't match the lock. A pre-commit leg asserting "expected-locks.nix and flake.lock move together" (both-or-neither, modulo deliberate pin edits) would make the whole class structurally impossible.
8. **New Go inputs should be shim-resistant by construction** — media-atlas just joined the fleet and its first build-gate contact was a failure. A "new input checklist" (own flake bakes its own vendorHash green at the locked rev, verified through OUR lock, before the service module lands) would have caught both the hash and the dead var at authoring time.

## f) TOP 50 THINGS TO GET DONE NEXT

Sorted by impact; `[S]` = direct session follow-up (self-harvested, queue pointer noted), `[O]` = owner-gated, `[D]` = deploy-gated, `[R]` = roadmap/brainstorm fuel (docs-health HARVEST should route with extra rigor).

1. `[O][D]` **Run the deploy** — the wave is proven and eval-green; carries crush 0.99.0 + 16 floats + cv/crm/journal fixes + media-atlas fix. Pressure gate may require `DEPLOY_FORCE_PRESSURE=1` or waiting out the sda storm. Then: anchor verify (readlink current-system == newest system-N-link), post-deploy battery.
2. `[S]` → `docs/todo/upstream.md` — **paste-upstream cycle for cv/crm/journal** (bake got-hashes, push, re-lock, drop all five shim sites).
3. `[S]` → `docs/todo/services.md` — **journal shim consolidation** (three sites → one) **+ necessity probe** (shim-less rebuild to resolve the green-standalone contradiction).
4. `[S]` → `docs/todo/pipeline.md` — **float-register: 72-char subject + commit-existence assertion** (both script fixes).
5. `[S]` → `docs/todo/services.md` — **media-atlas module end-to-end review** by its owning session.
6. `[D]` **Post-deploy crush 0.99.0 soak** — hook firing (the parallel session's three hooks), llamacpp `/v1` model discovery, tq-agent-pool turn-survival.
7. `[D]` **Post-deploy smoke of the floated services** — journal-serve (8484), kith-crm, cv-server, media-atlas (map.home.lan), herdr, nix-email, go-cqrs-lite consumers, offline-banner, dms-shell (desktop session), file-and-image-renamer, buildflow-dependent units.
8. `[D]` **gitea-runner + tq inactive units** — carried from the 02:3x deploy smoke (unverified since; re-run post-deploy-check.sh when IO is calm).
9. `[O]` **Decide the vendorHash class policy** — keep pasting upstream per-repo (§e.1) vs a shared hash-oracle script that pre-computes all FOD got-hashes in one fakeHash sweep before any float.
10. `[R]` **Upstream CI for LarsArtmann Go repos: build own flake package on push** — would have caught cv/crm/journal stale bakes at push time instead of in SystemNix proofs (buildflow territory).
11. `[R]` **Pre-commit leg: expected-locks.nix + flake.lock must move together** (§e.7) — makes split-pair commits structurally impossible.
12. `[S]` **Verify the parallel session's CI workflow edits actually run** — their `flake-update.yml`/`nix-check.yml` rewrites (commit `27f2813a1`) are unverified by anyone; next push/PR + nightly runs are the test.
13. `[O]` **nixpkgs fe13242 rev-pin lift attempt** — the standing LIFT condition is one green `--keep-going` toplevel with aw-core + linux-7.3-modules realized; trial is cheap, the pin is one line.
14. `[O]` **Rollback-tenure review date for the nixpkgs pin** — already a `[decision]` row in upstream.md (review date vs defect-gated); the wave keeps making the pin's cost visible (every "lift" instruction re-printed at eval).
15. `[O]` **hermes-agent pin lift** — blocked on nixpkgs pin (patchelf #672 chain); lifts WITH #13.
16. `[O]` **nsfw-classifier pin lift** — upstream telemetry refactor compiles + probe build green, then drop pin + row.
17. `[O]` **nixpkgs-llama-rag drop** — 0.4.0 spin regression fixed upstream + live re-verified, then delete the input entirely.
18. `[O]` **paperless-gpt tag bump** — v0.28.0 → next tag + vendorHash + npmDepsHash together.
19. `[O]` **qmd tag bump** — v2.8.3 → next tag + CLI + `qmd mcp` re-verify.
20. `[O]` **signoz-src pin lift** — patches apply unchanged or sonic ≥1.15 obsoletes them + `nix build .#signozPkg` green.
21. `[D]` **Investigate the 18:06 sda IO storm before the next deploy** — 102.7% util, two ghostty user scopes at ~100% stall; the DEPLOY_FORCE_PRESSURE override was correct once, but the storm's owner (likely the ghostty io_uring CQ-waiter phantom class, already a queued upstream item) keeps re-arming the gate.
22. `[S]` **Resolve the "journal builds green standalone" claim in the parallel session's report** — subsumed by #3's probe; annotate their report (docs-health ANNOTATE) with the outcome either way so no later reader trusts an unresolved claim.
23. `[S]` → `docs/agents/nix-flakes.md` (done) — **spread the false-"daemon landed" trap to AGENTS.md's Session Discipline** at next AGENTS.md touch (one-line cross-ref; deferred to avoid racing the active session).
24. `[S]` → `docs/todo/pipeline.md` — **route the media-atlas "new input checklist" idea (§e.8) as a real gate or drop it** (currently only prose in this report).
25. `[R]` **SessionStart hook: surface newest untracked docs/status/ files** (§e.5) — mechanizes the 2026-10-23 pre-read rule; natural extension of the parallel session's crush-config hook work.
26. `[R]` **Collapse the 7-pin eval trace noise** — every eval prints ~20 lines of deliberate-pin LIFT instructions; a count + file pointer (or `--allowlist-file`) would make REAL warnings legible again.
27. `[R]` **expected-locks.nix generated-file marker** — header already says "never hand-edited"; consider a check that rejects hand-edits (diff vs regen) so manual registry edits (like today's unproven parallel-session regen) fail loudly.
28. `[R]` **GOPROXY/vendor strategy for the re-served-dependency class** — if #3's probe shows FOD content flapping, vendoring (or pinned GOPROXY) for the treadmill repos is the durable kill.
29. `[R]` **Shim-history extraction** — cv.nix's 11-entry comment chain (~90 lines) and crm.nix's 5 entries belong in docs/todo/upstream.md; modules keep one line + pointer.
30. `[R]` **Post-commit hook failure feedback to the daemon** — the daemon cannot act on "fix with: git commit --amend"; either a hook exception path for script-committed floats or a daemon-side retry with truncated subject.
31. `[R]` **Hygiene probe: the hook-rejected commit attempt's leftover state** — COMMIT_EDITMSG / daemon queue state after a rejection; confirm the next daemon cycle is unaffected.
32. `[R]` **nur float cadence** — moved twice in 4 days (crush releases); either accept the churn (automated by #4's fixes) or pin crush releases deliberately.
33. `[R]` **crush-daily floated twice within the session window** (53d08a6 → 412bdd15, parallel session's second update) — registry handled it, but double-updates per hour is churn worth noting in the daemon-race policy discussion.
34. `[R]` **Stray-unit-audit findings from today's eval** — `forgejo-dump`, `systemd-tmpfiles-clean`, `tmpfiles-clean-debug` render DORMANT; resolve or allowlist with justification.
35. `[R]` **cv graphrag inert-keys eval warning** — `settings.graphrag.store_dsn` set while graphrag disabled; flip enabled or drop the keys (the warning is per-eval noise).
36. `[R]` **stalwart 0.15.5 pin warning** — already queued in services.md (2026-10-29 03-17 task row); standing eval noise, still open.
37. `[R]` **catalog subdomains warning** — 23 subdomains (map, journal, immich, …) will vanish from derived DNS if `platforms/common/dns-local.nix` is ever deleted; backfill catalog entries or document the dependency.
38. `[R]` **Unpushed sibling repos from today's drift report** — crm +6, crush-config +3, crush-daily +1, file-and-image-renamer +23, media-atlas +6, journal +32 commits ahead of origin; each is "the locked rev cannot provide what the tree expects". Owner push session (ties into #2's push trip).
39. `[R]` **Parallel session's plan-doc marker check** — `docs/planning/2026-10-29_18-42_SUPERB-crush-0990-rollout-finish-and-hardening.md` should carry an EXECUTING marker per the 2026-10-18 tombstone rule; I did not verify (not my plan).
40. `[R]` **homebrew-cask float verification on darwin** — the proof covers Linux; the darwin side of the wave (homebrew-cask, dankMaterialShell desktop bits) gets its next `darwin-rebuild`, no verification exists yet.
41. `[R]` **Consider a `--section-N-only`-style fast path for float proofs** — when a float touches only Go inputs, a pre-filtered FOD-only enumeration (hash checks without full toplevel) could turn the 4-root discovery from minutes to seconds; design sketch only.
42. `[R]` **Document the "identical drv path = your override wasn't in the graph" tell** — it diagnosed journal-backup instantly once seen; belongs in docs/agents/nix-flakes.md next touch (one line).
43. `[R]` **Eval-cache sqlite "busy (ignored)" under parallel evals** — seen twice this session; harmless so far, worth a known-noise line in docs/agents/nix-flakes.md.
44. `[R]` **Queue-row format check on my harvest rows** — next docs-health pass should verify my 5 new rows survive the WARN recount (pairing WARNs rise after every append by design).
45. `[R]` **media-atlas key-provision timer overlap with Immich migrations** — the DB-direct INSERT assumes api_key schema stability; the schema guard fails loud (good), but a start-ordering dependency on Immich being migrated deserves a look in the review (#5).
46. `[R]` **The 12:09 owner proof's `media-atlas.nix cfg.group` eval failure** (per the parallel session's report, "since fixed by owner") — verify the fix landed in the tree I proved (it did eval green, but the specific fix isn't something I audited).
47. `[R]` **AGENTS.md GOBIN/shell-devtools cross-ref for jq-in-hooks** — the parallel session's hooks defensively `unset DIRENV_DIFF`; the jq trap doc (shell-devtools.md) should cross-ref that hooks are now protected post-deploy.
48. `[R]` **redact-argv hook vs this session's outputs** — my session printed no argv-secrets (checked mentally during the run), but the platform hook (post-deploy) makes that check automatic; no action beyond #6's soak.
49. `[R]` **Decide whether `flake/expected-locks.nix` even wants the manual-regen header procedure documented** — the header's jq procedure is now fully superseded by float-register; shrink the header to point at the script (doc debt, 5-minute fix).
50. `[R]` **The owner's original complaint deserves a UX answer beyond today's mechanics** — "I want to be able to update" is now true (update + float-register just works when upstreams bake their hashes), but the deeper ask might be "no ceremony at all" — that's #9/#10/#11's systemic path, an owner direction call.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Deploy now, or hold for the crush-0.99.0 session?** The tree is proven and deployable, but the deploy would also activate the parallel session's committed work (crush 0.99.0 via nur, their CI rewrites are push-side only). Their plan doc says "rollout finish and hardening" — if you deploy before they declare done, they lose the "staged but not deployed" safety line; if you wait, you stay on gen-939-era config. Your call on sequencing.
2. **Do you authorize the paste-upstream push session for cv + crm + journal (+#38's six unpushed sibling repos)?** It's the single highest-leverage fix (retires the 11-cycle shim treadmill and the "locked rev can't provide what the tree expects" drift class), but it means pushing to six-plus of your repos in one sitting — the exact `[blocked:push]` class agents never do without you.
3. **What is the end state you actually want for the float ceremony?** Today's answer made `nix flake update && nix run .#deploy` work again — with the gate still forcing a proof whenever upstreams ship stale hashes (which they keep doing). Options: (a) keep the gate + fix upstreams (#2/#9/#10), (b) soften the gate to WARN-and-continue on hash-only failures, (c) drop the registry entirely and let proofs catch breakage at deploy time like pre-2026-10-23. I can implement any of them; which future are you buying?

---

## Self-harvest record (AGENTS.md authoring-time rule)

| §f item | Queue (TODO_LIST.md) | Domain library | Status |
| --- | --- | --- | --- |
| #2 paste-upstream cv/crm/journal | — (`[blocked:push]` rows are library-only by routing rules) | docs/todo/upstream.md | landed |
| #3 journal consolidation + probe | ### services | docs/todo/services.md | landed |
| #4 float-register fixes | ### pipeline | docs/todo/pipeline.md | landed |
| #5 media-atlas review | ### services | docs/todo/services.md | landed |
| §d.4/nix-flakes trap | — (doc, not a task) | docs/agents/nix-flakes.md | landed |
| #23 AGENTS.md cross-ref | deliberately not queued — one-line cross-ref deferred to next AGENTS.md touch to avoid racing the live parallel session on the same file | — | recorded here |
| All others | brainstorm/roadmap fuel or duplicates of existing rows (#14/#16-20/#34/#36/#37 already live in their libraries) | — | not harvested |

Note: `docs/todo/pipeline.md` was mid-edit by the parallel session when I appended (their unstaged changes untouched); my two rows are EOF appends — verify they survived their next save at the next docs-health pass.
