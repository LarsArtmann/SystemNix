# Status Report — branch consolidation (PR #144 merge) + CI unblock: bundle deploy keys, go-paperless rewire

**Session window:** 2026-10-29 ~16:40 – 23:18 CET
**Author:** Crush agent session (SystemNix, master working tree)
**Final repo state at writing:** master `c5b7fb0f8`, clean; tree has moved well past my last push (`899906c39`) through interleaved parallel-session + daemon commits (float wave, status reports). Latest CI on `47f8b2f`: Nix flake check FAIL, Secret history scan FAIL; go-deps-audit regressed to FAIL on `0377cab` after being GREEN on `5d94d60` (see §b1/§b2).
**Scope discipline (per user instruction):** this report covers ONLY this session's two tasks and what they surfaced in passing. No project-wide research sweep was performed.

---

## Task narrative

Two chained user asks on master:

1. **"merge all PRs and finished branches into master or better rebase"** — consolidate the open PR and dead branches.
2. **"fix"** — after I reported CI red-on-master pre-dating the branch, fix what is agent-fixable in CI.

The CI arc turned out to be a layered excavation: fetch-auth missing for 38 of 46 private inputs → multi-deploy-key protocol trap → a local-path nested lock node → a github-tarball auth class that is owner-gated → content-level lint findings that three months of red CI had been masking.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **PR #144 merged as a true fast-forward** (the rebase outcome: linear history, no merge commit, the rewritten SHAs cited by the 15:49 status report preserved verbatim). Push `media-atlas-hub-service:master` = `aeded830a..64baadea5`; PR auto-marked MERGED (mergedAt 2026-10-29T16:52:18Z). Local evo-x2 toplevel eval gate run BEFORE the push (`g4r19ywx…drv`), which also closes item b3 of the 15:49 report. | `gh pr view 144` = MERGED; `git log` ff shape |
| a2 | **All finished branches deleted** (local + remote): `media-atlas-hub-service` (auto-pruned on merge), `status-report-backup` (remote already gone; stale tracking ref pruned), `inboxclean-module-migration` (containment proven `merge-base --is-ancestor` before `-D`; remote deleted via push --delete). Only `master` remains, local == origin. | `git branch -a` = master only |
| a3 | **CI failure inventory established** (before touching anything): CI had been red since **2026-07-29 — 100 consecutive nix-check failures, zero green in the last 100 runs**. Distinct classes named: per-repo deploy-key allowlist gap (8 secrets vs 46 private ssh inputs; first-hits `branching-flow`, `dnsblockd`), statix job broken by nixpkgs defaultApp alias removal, secret-history-scan (known held decision), and — once fetches worked — the layers in §a5–§a7. | `gh api .../runs?status=success` newest = 2026-07-29; run-log greps |
| a4 | **46 read-only deploy keys registered** — one ed25519 pair per private repo in the lock (`ssh-keygen` + `gh api -X POST repos/LarsArtmann/<repo>/keys -F read_only=true`, title `systemnix-ci-readonly`), 46/46 ok, fingerprint spot-check vs local key (`dnsblockd` SHA256:+MroO9d9… match). | API responses; `ssh-keygen -lf` both sides |
| a5 | **`NIX_DEPLOY_KEYS_BUNDLE` Actions secret (v2 manifest format)** — all 46 private keys in one secret, each introduced by an `@REPO <name>` header; ~20 KB, set via stdin (`gh secret set … < file`, key material never in argv, never displayed). | `gh secret list` timestamp |
| a6 | **All five workflow auth blocks rewritten** (nix-check.yml ×2, negative-tests.yml, go-deps-audit.yml, flake-update.yml): bundle → per-repo key files → generated ssh config `Host nixci-<repo>` blocks (HostName github.com, IdentityFile, **IdentitiesOnly yes**) → `insteadOf` rewrite per repo URL → `GIT_SSH_COMMAND=ssh -F ~/.ssh/nixci-config`. No ssh-agent at all. YAML validated locally before each push. | commit `27f2813a1`; `python3 yaml.safe_load` ×4 OK |
| a7 | **End-to-end auth proof BEFORE the alias push**: isolated `GIT_CONFIG_GLOBAL` + generated config, `git ls-remote` through the alias mechanism for `dnsblockd` AND `branching-flow` — the two repos CI actually died on — both green with their own keys. | session log; HEAD SHAs returned |
| a8 | **statix job fixed**: `nix run "<pin>" -- statix check .` relied on the removed defaultApp alias; now runs the explicit `#statix` app attr (attr existence verified locally against the pinned rev first: 0.5.8). | commit `27f2813a1` parent |
| a9 | **go-paperless CI-eval unblock**: journal's own lock pinned its go-paperless dep to `file:///home/lars/projects/go-paperless` (machine-only; killed the doc-counts + evo-x2 toplevel controls the moment the harness could run). Root-follow rewired to the github remote (HEAD == previously locked rev `ba4ea1fe` — byte-identical tree), declared `flake = false` (matches journal's plain-source consumption; also stops its nixpkgs/treefmt nodes from entering our lock — the lock then PRUNED 113 orphan lines), registry row added to `flake/expected-locks.nix`. Local `nix flake check --no-build`: **all checks passed**. | commit `5d94d60c5` (flake.lock + registry; flake.nix hunk rode daemon commit `46be5347d`) |
| a10 | **First CI green in 3 months**: go-deps-audit SUCCESS on `5d94d60` (2026-10-29T18:29) — the workflow that evals every private input tree. Proves the 46-key alias layer works end-to-end on real runners. | run list; run 40925295434-era successor |
| a11 | **Doctrine recorded**: `docs/agents/go-ecosystem.md` deploy-key recipe section rewritten — per-repo-secret form marked SUPERSEDED, bundle recipe documented (incl. the add-repo-without-workflow-edit property), plus the two traps (multi-key first-accepted-key; github-tarball-404 class). Committed + pushed `899906c39`. | docs/agents/go-ecosystem.md |
| a12 | **Two stragglers queued in the TODO system** (library row in pipeline.md + dispatch one-liner in TODO_LIST.md, cross-linked): the owner-gated PAT for the github-tarball class (`[blocked:user]`) and the dead-guard-lint content finding (`[ready]`). Both rows landed on origin via daemon commit `511edc0b0`. | grep counts 1/1 in both files |
| a13 | **Local private-key material trashed** after secret registration (keys/, bundle, bundle2, split-test, e2e sandbox, commit-msg file) — `trash`, never `rm`. | `ls ~/.cache/systemnix-dk/` residue = text files only |

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| b1 | **CI overall**: at my best head (`5d94d60`) 1 of 4 workflows green, 1 held-decision-red, 1 content-red, 1 pending. Since then the parallel session's float wave moved the tree several heads forward and **go-deps-audit has REGRESSED to FAIL** (`0377cab`: "FATAL: nix eval of input outPaths failed" — cause not yet diagnosed; prime suspects: a newly-walked private `github:`-type node hitting the tarball 404 class, or their newest eval content). The auth layer itself stands; the tree content on top of it is moving under other actors. | run list at report time |
| b2 | **Nix flake check on my heads never reached a verdict while I watched** (vm-tests build closures; 20–40 min). It failed on later heads (`9c6c00f`, `47f8b2f`) that include substantial non-mine content. My session's contribution to its state is bounded: fetch-auth + go-paperless + statix. | run list |
| b3 | **Old per-key secrets + old deploy keys cleanup** — deliberately deferred ("delete after verified green"): `NIX_DEPLOY_KEY_{CV,GO_CQRS_LITE,BRANCHING_FLOW,FILE_AND_IMAGE_RENAMER,BUILDFLOW,PROJECT_DEPENDENCY_GRAPH,PROJECT_DISCOVERY_SDK,JOURNAL}` secrets and the old `SystemNix CI (read-only)` deploy keys (e.g. branching-flow id 161686718) still exist. Full-green never arrived, so the cleanup window never opened. | `gh secret list`; deploy-key list |
| b4 | **flake.lock churn rode my pushes unverified row-by-row**: my full `nix flake lock` (a mistake, §d2) plus the parallel session's re-locks produced a float wave (flake-parts `427bf4bd`→`024633cd`, an `nixpkgs-unstable` `3ec63636` node, and more) that interleaved into daemon commits and went out with my pushes. I verified the consolidated state with ONE local `nix flake check --no-build` (green) — not a row-by-row reconciliation of every moved node against `expected-locks.nix`. | `git diff origin/master..HEAD -- flake.lock` at push time |
| b5 | **Attribution of interleaved history**: my fix(ci) content landed inside daemon heuristic commits (`97c08f88b` bundled my 4 workflow files WITH the parallel session's flake.lock float + crm.nix/cv.nix; `46be5347d` bundled my flake.nix go-paperless hunk WITH their re-lock). My properly-messaged commits (`27f2813a1`, `5d94d60c5`, `899906c39`) carry the later deltas; the bundling is narrated in the 27f2813a1 message but the heuristic commits remain heuristic. | `git show --stat` of the named commits |
| b6 | **negative lint tests**: the harness now genuinely RUNS (first time since July — some groups PASS, e.g. signoz/job-matcher), but the pristine-copy controls still fail: dead-guard-lint content finding + project-discovery-sdk tarball 404. Queued, not fixed. | run 40931326244 log |

## c) NOT STARTED

| # | Item | Why it surfaced |
|---|------|-----------------|
| c1 | Fine-grained PAT for the github-tarball class (owner-gated — no API to mint PATs; `GITHUB_TOKEN` is repo-scoped and cannot read sibling private repos; tarball fetches bypass git/ssh entirely and have no fallback) | queued pipeline.md `[blocked:user]` |
| c2 | dead-guard-lint content fix ("unreachable degraded-path guards" — captures inline in run 40931326244) | first honest harness run exposed it |
| c3 | secret-history-scan red = the held history-purge decision (rotated 2026-08-18 synthetic key in July archive blobs — docs/agents/secrets.md already owns this; NO new row created to avoid duplication) | pre-existing, in-passing |
| c4 | Upstream doc fix: the `nix-private-go-repos` SKILL.md (ci-auth.md Strategy 1) documents EXACTLY the multi-deploy-key-agent pattern that cannot work — verify-before-filing + upstream PR candidate | hit live in this session |
| c5 | Old secret/deploy-key cleanup (§b3) | gated on full green |
| c6 | §f self-harvest of THIS report at authoring time — **deliberately deferred**: user instruction "THEN WAIT FOR INSTRUCTIONS" (recorded here per the AGENTS.md escape hatch, same pattern as the 15:49 report b4). The two actionable stragglers were ALREADY harvested into the TODO system at authoring time (a12) — the deferral covers only post-report items. | this sentence |

## d) TOTALLY FUCKED UP

| # | Item | What happened | Damage |
|---|------|---------------|--------|
| d1 | **First bundle push failed on a protocol trap I should have predicted** — I tested the csplit split + `ssh-keygen -y` parse validity locally, but never the github ACCEPTANCE semantics. Multi-deploy-key agents fundamentally cannot serve N repos: ssh offers keys in order, GitHub accepts the FIRST valid one, and that key has access to exactly one repo → `ERROR: Repository not found` for every other fetch. One wasted CI cycle, one secret rewrite (v2 manifest), one 5-file workflow rewrite to per-host aliases. The diagnostic clue (authenticated-but-no-access vs publickey-denied) was IN the CI logs from the start. | cost: ~1 h + one churn cycle |
| d2 | **Ran broad `nix flake lock` where a surgical edit was needed** — floated flake-parts & co. (182-line diff), had to revert twice, then hand-edit the lock (jq attempt polluted key order; python order-preserving edit was the right tool). The churn still leaked into history via daemon commits. | cost: ~3 lock cycles + diff noise in history |
| d3 | **Three failed git commit attempts against a live parallel session**: (1) pathspec commit hit "nothing to commit" — the daemon swept my staged files mid-command; (2) amend attempt hit index.lock (parallel session mid-commit); my retry loop would have AMENDED ON TOP OF THEIR commit had the lock cleared at the wrong moment — it didn't (luck, not control); (3) TODO commit hit index.lock again and the background retry timed out (rows landed via a later daemon sweep instead). I kept retrying git ops instead of FIRST probing `.git/index.lock` + `pgrep git commit` — the concurrency discipline existed and I applied it late. | time + near-miss on rewriting another session's commit |
| d4 | **Re-hit the documented jq direnv trap** (AGENTS.md 2026-10-17): `jq --indent …` parsed the flag as filter code ("function not defined: indent/0"). The workaround (`env -u DIRENV_DIFF jq …`) was in my own context and I reached for it only after the error. | minutes; pure own-goal |
| d5 | **Pushes carried interleaved content I did not author** (parallel session's lock float wave + service edits inside my pushed range). I verified via `git show --stat` + a local green eval at the instant of push — but the tree was mid-flight of another session, and go-deps-audit has since regressed on later heads. The daemon-race policy (pathspec commits, amend-forward) was applied, but the bundling itself was unavoidable only because the daemon acted between my `git add` and `git commit`. | attribution debt; §b4/§b5 |

## e) WHAT WE SHOULD IMPROVE

1. **Credential changes get ROUND-TRIP tests, not parse tests.** "The split files parse" ≠ "GitHub accepts and authorizes them." Simulate the remote-acceptance semantics locally (or against a scratch repo) before any CI push.
2. **Read the error CLASS before the hypothesis.** `ERROR: Repository not found` over ssh = authenticated-but-no-access; "Permission denied (publickey)" = no key accepted. I burned a cycle hypothesizing key-availability when the log already named the class.
3. **Probe `.git/index.lock` + `pgrep 'git (commit|add)'` BEFORE every git write** when any parallel session is known-active (and in this repo one usually is). Batch add+commit+push into one atomic command; never plan an amend whose target could silently become another session's commit.
4. **Single-node lock changes are python json edits** (order-preserving, diff-minimal); `nix flake lock` is for deliberate waves only. `--update-input` cascades into the input's subtree — it is NOT surgical.
5. **Enumerate ALL failure classes before the first fix push** when a red gate is old: three months of red masked FOUR independent layers; the --keep-going-first doctrine applies to CI archaeology too.
6. **When the daemon bundles your work with a neighbor's, say so in the commit message and move on** — splitting via reset is banned by the amend-forward doctrine and the bundle is already history. (Applied; noting it as the standing resolution.)
7. **House skills drift too**: the nix-private-go-repos skill's Strategy 1 is the broken pattern; skills need the same staleness review as docs.

## f) UP TO 50 THINGS TO GET DONE NEXT

Grouped; impact-ordered within groups. Direct follow-ups first.

**P0 — CI completion (this session's direct arc):**

| # | Task | Source |
|---|------|--------|
| 1 | Diagnose the go-deps-audit REGRESSION on `0377cab`+ ("FATAL: nix eval of input outPaths failed") — was green on `5d94d60`; name the exact input/spec that started failing | b1 |
| 2 | Owner: mint fine-grained read-only PAT (all LarsArtmann private repos) → `gh secret set NIX_GITHUB_PAT` → wire `access-tokens = github.com=…` into the 5 auth blocks — unlocks the entire private-github-tarball class (~300+ lock nodes) | c1 / pipeline.md row |
| 3 | Fix dead-guard-lint content finding (captures inline in run 40931326244) so the pristine controls go green | b6 / TODO_LIST row |
| 4 | After 2: re-run negative lint tests + nix flake check on a settled head; expect control-green for the fetch class | b2 |
| 5 | Delete the 8 old per-key secrets + old `SystemNix CI (read-only)` deploy keys once full green (§b3 list) | b3 |
| 6 | Row-by-row reconciliation of the float wave that rode `46be5347d`/`b81a141a8` (flake-parts move, nixpkgs-unstable node, friends) against `expected-locks.nix` — deliberate adoption or drift | b4 |
| 7 | Get a full-green `nix flake check` verdict on a settled head at all (vm-tests have not completed green in this session's window) | b2 |

**P1 — doctrine/docs consolidation:**

| # | Task | Source |
|---|------|--------|
| 8 | Update `nix-private-go-repos` SKILL.md + references/ci-auth.md: Strategy 1 (agent with N deploy keys) is protocol-broken; document the alias pattern + tarball-404 class (upstream = own repo, so direct edit + verify) | c4 |
| 9 | Add the "authenticated-but-no-access vs publickey-denied" error-class table to docs/agents/git.md or go-ecosystem.md | e2 |
| 10 | Record the go-paperless rewiring pattern as a reusable playbook (nested local-path node → root follow, flake=false, registry row) — currently only narrated in flake.nix comments + this report | a9 |
| 11 | AGENTS.md Session Discipline: add "probe index.lock before git writes when parallel sessions are live" bullet | e3 |
| 12 | Consider a pre-commit leg: reject `file:///home/` URLs in flake.lock original nodes (machine-only paths are a CI-eval time bomb; go-paperless class) | a9 |
| 13 | Consider a pre-commit leg: reject new per-repo `NIX_DEPLOY_KEY_*` env lines in workflows (bundle recipe is the only sanctioned pattern now) | a6/a11 |
| 14 | Sweep the other 4 workflows for the same nixpkgs-default-app alias bug class (`nix run "github:NixOS/nixpkgs/${REV}"` with no attr) | a8 |

**P2 — hygiene noticed in passing:**

| # | Task | Source |
|---|------|--------|
| 15 | `monitor` flake.nix input: 404 repo AND not in lock — dead input definition, delete | §a3 era |
| 16 | `crm`/`cv` service edits + journal-serve/journal-backup edits that rode daemon commits: owner-ratify or revert (they were mid-flight of the parallel session) | b5 |
| 17 | Verify `secret-history-scan` failure is EXACTLY the known held-purge finding set and nothing NEW (my session added no secrets; assert the failure signature didn't grow) | c3 |
| 18 | The 15:49 report's open §b1 (unidentified merge-aborter actor) remains unsolved — three destroyed merge states on 2026-10-29 afternoon; /proc + journalctl forensics still pending | passed-through frame |
| 19 | `gh secret list` shows secret created dates in UTC while `gh run list` mixes UTC — standardize the runbook's evidence-table timezone convention | minor, in-passing |
| 20 | Retire `pgrep -q` usage in repo scripts — this box's pgrep lacks `-q` (use `pgrep … >/dev/null`) | d3 noise |
| 21 | Dependabot-style pin check: workflow `actions/*` versions — the checkout@v4-era SHA pinning comment (2026-10-29 dependabot success run) suggests pins are managed; confirm the alias-auth blocks inherit the pinned-SHA policy | in-passing |
| 22 | Bundle secret rotation procedure doc: how to rotate ONE repo's key inside the bundle without downtime | a5 follow-on |
| 23 | CI: cache the 46-key ssh config generation (keyscan cost is trivial, but the per-run `git config --global` writes accumulate) — measure before optimizing | speculative |
| 24 | Add `csplit`/`awk` fallback note: the manifest splitter assumes gawk-free pure-bash; verify on the runner image (it ran green twice — record as verified, not assumed) | a6 |
| 25 | Post-green: flip the TODO rows (items 2/3) to `[x]`, prune to CHANGELOG, and recount the pairing/harvest WARNs per the prune doctrine | process |

*(Stopped at 25 — the tail would be padding; the list is honest at this length.)*

## g) QUESTIONS FOR THE OWNER

1. **Old credentials cleanup timing** — delete the 8 old per-key secrets + old `SystemNix CI (read-only)` deploy keys NOW (they are dead weight but also a fallback if the bundle ever breaks), or only after a fully-green CI run on a settled head?
2. **PAT shape for the tarball class** — is ONE fine-grained read-only PAT across all ~46 private repos acceptable as `NIX_GITHUB_PAT`, or do you want per-repo granularity / a GitHub App (more setup, smaller blast radius)? Creation is yours either way; I will wire whichever exists.
3. **The float wave that rode my pushes** (flake-parts `427bf4bd`→`024633cd`, `nixpkgs-unstable` node, crm/cv/journal service edits — bundled into daemon commits with my work): deliberate adoption by the parallel session that I should treat as ratified, or do you want the row-by-row reconciliation against `expected-locks.nix` (§f item 6) before treating master as settled?

---

*Report authored 2026-10-29 23:18 CET. §c6 deferral recorded; a12 harvest already landed. WAITING FOR INSTRUCTIONS.*
