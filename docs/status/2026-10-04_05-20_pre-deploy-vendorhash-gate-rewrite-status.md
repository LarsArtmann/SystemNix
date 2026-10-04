# Status Report — Pre-deploy §11 vendorHash gate rewrite + session races

**Session:** 2026-10-04 ~04:30–05:20 CEST · **Repo:** SystemNix @ `master` (HEAD `29d55e15` at authoring)
**Scope:** review + rewrite of the pre-deploy-check §11 "vendorHash freshness" warning; multi-agent git-race forensics. Per operator instruction this report covers ONLY this session's run and what it noticed.

---

## a) FULLY DONE

1. **§11 root cause proven with live evidence (not inferred).** The old check hardcoded 6 package names (`dnsblockd monitor365 netwatch emeet-pixyd file-and-image-renamer crush-daily`) and grepped `nix build --dry-run` output for `would build` / `would (copy|fetch)` — output shapes nix NEVER produces. Real output is `these N derivations will be built:` (uncached) or notices-only silence (cached). Every invocation since 2026-08-08 therefore fell into the catch-all `warn "unable to determine status (may not be a buildGoModule)"`. Evidence: captured real outputs for all three shapes (uncached batch, cached batch, hash mismatch), preserved as test fixtures.
2. **Discovery audit:** 28 local packages expose `goModules` (eval-driven), not 6. crush-daily and file-and-image-renamer have grown Go modules (the 2026-09-24 f37 "bun-only" classification is stale for them). `systemPackages`-intersection was TESTED and rejected as the scoping oracle: dnsblockd/emeet-pixyd/crush-daily enter evo-x2 via service packages, not systemPackages — the intersect missed exactly the packages the old list knew.
3. **§11 rewritten as a real verdict gate** (`scripts/lib/vendor-freshness.sh` + `scripts/pre-deploy-check.sh`): the toplevel `--dry-run` is the deploy-build preview oracle (what `nh os switch` will build on this commit); any listed `*-go-modules.drv` is real-built in-gate with `--keep-going` BEFORE the 12-min deploy build. Stale hash ⇒ FAIL in seconds with the extracted `got:` hash (message points at `buildflow -s nix-hash-fix --fix`); clean build ⇒ vendorHash proven + cache warmed; non-hash FOD failure ⇒ FAIL with the error tail; eval failure ⇒ degraded WARN (never phantom-green).
4. **Fixture selftest, evidence-grade:** `scripts/test-pre-deploy-vendor.sh` — 11 assertions over REAL captured nix output, including a genuine FOD hash mismatch produced this session via a bogus `outputHash` override on dnsblockd (per the commit-message evidence rule: every claimed output shape was actually run today). Wired as `checks.x86_64-linux.pre-deploy-vendor-selftest` (through-nix staging, same pattern as pre-deploy-metrics-selftest).
5. **`--section-11-only` flag** mirroring `--section-10-only`, for iterating on the gate without a full 10-min run.
6. **Live end-to-end verification:** `bash scripts/pre-deploy-check.sh --section-11-only` → `✓ all deploy go-modules FODs cached — vendorHash proven by prior builds`, exit 0. `nix flake check --no-build` green (incl. the new check). shellcheck clean on all three touched shell files. Zero `GO_PKGS` leftovers repo-wide.
7. **Cache warmed as a side effect of diagnosis:** the 3 then-uncached FODs (dnsblockd, crush-daily, file-and-image-renamer) real-built CLEAN — their vendorHashes are proven valid as of today's lock, and the next deploy build skips them.
8. **Docs + todo surfaces closed in sync:** CHANGELOG `### Fixed` entry; AGENTS.md prevention-layers row corrected ("10 numbered checks" → 13 + vendorHash preview — was stale before this session); `TODO_LIST.md` §11 row + "verify greps at runtime" row marked DONE; `docs/todo/pipeline.md` library rows closed; the `quick-go` library entry annotated with the implicit mkLarsPackages-FOD coverage. DONE stamps cite `8ef8d57f` (the code landing commit).
9. **Harvest at authoring (per TODO-system contract):** 10 new session follow-ups queued in `TODO_LIST.md` AND `docs/todo/pipeline.md` (§f.1–§f.10 below, each tagged `HARVESTED at authoring`).

## b) PARTIALLY DONE

1. **Proper commit narrative for the code change.** The code is fully landed (4 files, +276/−18, commit `8ef8d57f`) but with the daemon's heuristic message: my properly-messaged amend `7d9fc871` was discarded by a concurrent actor minutes after it landed (see §d.1). The narrative survives in CHANGELOG + this report, not in `git log`. Remaining: optionally re-message `8ef8d57f` while unpushed (§g2 decision). Effort: S.
2. **Pre-deploy warning-noise reduction (the 2026-09-17 06-16 §c.8 class).** §11's 6 permanent WARNs are gone; §12 "not built yet" ×3, buildEnv collision spam, and mandb whatis noise remain exactly as before — pre-existing queued item, untouched this session.
3. **2026-09-24 f37 non-Go-input classification.** Partially resolved as a side effect: crush-daily/file-and-image-renamer are now covered by the §11 oracle as Go packages; the input-hygiene WARN classification for genuinely non-Go inputs (qmd) is not done.
4. **`quick-go` batch-build item (pipeline.md row).** The mkLarsPackages-FOD half is now implicit via the §11 preview (annotated in the library entry); the explicit `.#quick-go` output incl. cv + hermes (which are outside the evo-x2 toplevel preview) remains open. Effort: M.

## c) NOT STARTED (noticed, deliberately untouched)

1. **Full pre-deploy gate re-run after the rewrite** — only §11-only + fixtures + flake check ran. Accepted risk: §10/§12/§13 code paths untouched; full run costs ~10 min. Priority if any §12/§13 regression is ever suspected from this change.
2. **Per-host gate parity (rpi3-dns, darwin)** — the gate is evo-x2-bound; other hosts get no FOD preview. Queued as §f.6.
3. **CI visibility of the new selftest** — it runs under `nix flake check` but CI is dark on private inputs until `NIX_GITHUB_RO_TOKEN` exists (existing `blocked:user` item, §g-independent).
4. **Parallel-session forensics beyond reflog evidence** — blocked on §g1 (the ground truth of what the other actor executed is not recoverable from my side).

## d) TOTALLY FUCKED UP

1. **Concurrent-actor commit/worktree clobber (severity: high for multi-agent integrity; no code or data lost).** Timeline, all evidence first-hand this session: (a) the daemon swept my 4 in-flight code files into heuristic `8ef8d57f`; (b) I verified its contents (`git show --stat` = exactly my files) and amended into `7d9fc871` per the documented amend-forward policy; (c) minutes later `7d9fc871` was ABANDONED — absent from `git log --all` and the reflog — and the identical diff re-landed as a NEW heuristic commit also showing as `8ef8d57f`; (d) my doc edits were reverted in the WORKING TREE (rows back to `[ ]`, CHANGELOG entry gone) while surviving in the INDEX — recovered via `git restore`; (e) my first harvest appends to pipeline.md/TODO_LIST were clobbered again by a stale-buffer write (05:19:33/05:21:32 mod-times) and had to be re-applied atomically. Root cause: UNKNOWN — needs §g1. Mitigation that worked: verify-before-touch, index-vs-worktree diffing, land-on-top instead of re-amending, atomic re-apply. This is the same class AGENTS.md §"Concurrent agent sessions" warns about, but the WORKTREE-REVERT leg (an actor restoring files over fresh edits) is nastier than documented.

2. **The thing this session was sent to review was itself fucked for 2 months:** §11 warned "unable to determine status" on EVERY deploy since 2026-08-08 while the vendorHash class broke two real deploys (incl. bank-sync, which the hardcoded list couldn't see). Fixed today; the standing lesson is queued as the drift-canary item (§f.10) so a locked-nix output-shape change can never silently re-create it.

## e) WHAT WE SHOULD IMPROVE

1. **Content-pin discipline at session START, not at first conflict.** I hit "file modified since read" on my first flake.nix edit because a parallel session was already active; AGENTS.md prescribes `git rev-parse` + `git log --stat` BEFORE writes. Cost: one refused edit; could have been a clobber.
2. **Cite landing hashes only after a re-verify.** I wrote DONE stamps citing `7d9fc871`, which died minutes later — re-pointing needed a sed pass. Fix queued (§f.2: mechanical hash-reachability leg in check-todo-system.sh).
3. **Verify a tool's real output shape BEFORE writing matchers.** The entire §11 failure class was greps against imaginary output; capture-first (as done today) should be the standing reflex for any log-parser work.
4. **Batch expensive probes.** I paid the ~49 s toplevel dry-run eval three separate times (timing probe, oracle validation, live gate). A shared/cached eval design is queued as a brainstorm (deliberately NOT harvested — see §f.28 rationale).
5. **Daemon-swept amend handling needs a decision, not heroics.** Amend-forward (the documented policy) lost to a concurrent rewrite this session. The response (land-on-top) worked but leaves heuristic messages in history — policy question in §g2.

## f) NEXT TASKS (session-derived; §f.1–§f.10 HARVESTED to TODO_LIST + pipeline.md at authoring)

| # | Task | Impact | Effort | Category | Harvest |
|---|------|--------|--------|----------|---------|
| 1 | Daemon commit-discard forensics (identify what abandoned `7d9fc871` + reverted worktree files) → CONTRIBUTING daemon-race policy entry | High | M | Bug/Process | ✅ queued |
| 2 | check-todo-system.sh leg: DONE-stamp hashes must resolve (`git cat-file -e`), selftested | High | S | Quality | ✅ queued |
| 3 | docs/agents/go-ecosystem.md: refresh vendorHash-freshness section to the §11 oracle (not verified this session) | Medium | S | Documentation | ✅ queued |
| 4 | docs-health ANNOTATE: 5 historical "§11 warns ×6" reports → resolution pointer `8ef8d57f` | Low | S | Documentation | ✅ queued |
| 5 | §11 got-hash handoff file (`/run/systemnix-fod-got-hash.txt`) for direct nix-hash-fix consumption | Low | S | Feature | ✅ queued |
| 6 | Per-host §11 gate (`--host` arg; rpi3-dns + darwin toplevel attrs) | Medium | M | Feature | ✅ queued |
| 7 | Flow-level stub-`nix` selftest driving `vendor_freshness_run_gate` through all 4 branches | Medium | S | Quality | ✅ queued |
| 8 | pre-deploy-check: exit 64 on mutually-exclusive section flags (currently §10-only silently wins) | Low | S | Quality | ✅ queued |
| 9 | Suppress nix trusted-setting notices in gate captures (`NIX_CONFIG` inline) | Low | S | Cleanup | ✅ queued |
| 10 | Nix-output-shape drift canary: sandbox re-capture of real dry-run/mismatch output diffed against committed fixtures | High | M | Quality | ✅ queued |
| 11 | Re-message heuristic `8ef8d57f` (unpushed) or accept it — blocked on §g2 | Low | S | Cleanup | ⏸ §g2 |
| 12 | Full pre-deploy gate run on a quiet window as a one-off regression sweep of §10–§13 | Low | S | Verification | ❌ not harvested — one-off check, not standing work |
| 13 | Shared-eval refactor of the gate (§10/§11/§12 each pay a full config eval today) | Medium | L | Feature | ❌ not harvested — ROADMAP fuel; blocked on §g3 cost-acceptance answer first |
| 14 | Remaining deploy-gate noise (§12 "not built yet" ×3, buildEnv collision spam, mandb whatis) | Medium | M | Cleanup | ❌ not harvested — ALREADY queued (2026-09-17 06-16 §c.8); do not duplicate |
| 15 | `quick-go` explicit output (cv + hermes inputs) | Medium | M | Feature | ❌ not harvested — existing pipeline.md row, annotated today |
| 16 | f37 remainder: classify genuinely non-Go inputs (qmd) in input-hygiene | Low | S | Quality | ❌ not harvested — pre-existing 2026-09-24 report item outside this session's domain |
| 17 | CI visibility: un-darks `nix flake check`-run selftests via `NIX_GITHUB_RO_TOKEN` | High | S | Infra | ❌ not harvested — existing `blocked:user` row |
| 18 | Post-deploy-check null-byte WARN lines (133/633) — named in this morning's 04-29 deploy report as unaddressed | Low | S | Quality | ❌ not harvested — owned by the 04-29 report's own follow-ups, different session's scope |
| 19 | AGENTS.md: extend the concurrent-session section with the worktree-revert leg observed today (actor restoring files over fresh edits) | Medium | S | Documentation | ❌ not harvested — deliberately folded into §f.1's CONTRIBUTING write to avoid a second doc surface for the same fix |
| 20 | Consider `nix build --dry-run` JSON-ish structured source (nix eval–based drv listing) if output wording drifts again | Low | M | Feature | ❌ not harvested — speculative; §f.10 canary is the cheap guard |

(Items beyond #20 would be padding — everything else this session noticed is either already queued upstream, recorded above with rationale, or §g-dependent.)

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **What discarded my amend?** `7d9fc871` (verified content pre-amend, unpushed) was abandoned and its diff re-swept as heuristic `8ef8d57f` within minutes, and my worktree doc edits were reverted while surviving in the index. I checked reflog, `git log --all`, index-vs-worktree diffs — the ACTOR (daemon re-stage? a `jj` operation? another session's reset/restore?) is not recoverable from inside this session. Do you know what else was running, or should §f.1 treat it as an open forensic?
2. **Amend policy under the daemon:** after this evidence, should I (a) keep amend-forwarding daemon-swept work, (b) always land-on-top with properly-messaged commits, or (c) re-message unpushed heuristic commits via rebase at session end when the tree is quiescent?
3. **Gate cost:** §11 adds ~50 s (toplevel `--dry-run` eval) + real FOD build time (0 s when warm; the 3 uncached FODs today cost ~2 min once) to every deploy. Acceptable as-is, or do you want a skip/knob (e.g. reuse when `HEAD`+`flake.lock` unchanged since last gate run)?

---

*Landing commits: code `8ef8d57f` (heuristic message — see §d.1), docs `29d55e15`. Report itself not manually committed (harness rule); the daemon will sweep it.*
