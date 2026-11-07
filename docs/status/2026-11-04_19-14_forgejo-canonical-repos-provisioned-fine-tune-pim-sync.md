# Status: Forgejo-canonical repos provisioned — fine-tune + pim-sync

**2026-11-04 19:14 CET — session report (single session, scoped to what this session did and observed).**

**Scope line — what this report VERIFIED:**

- Fleet remote audit of all 254 top-level folders via `ls` + per-folder `git remote -v` / `git rev-parse --git-dir` (fresh command output, this session).
- Both repos' provisioned state via `git ls-remote` against Forgejo (`evo-x2.home.lan`) and GitHub (`LarsArtmann/*`) at push time: fine-tune `32a43e5`, pim-sync `e9d44a2` → later catch-up push verified pim-sync `2f184bd` on BOTH remotes at 19:14.
- GitHub twin visibility = PRIVATE via `gh repo view --json visibility` (fresh API read, both repos).
- Forgejo repo privacy: unauthenticated `GET http://forgejo.home.lan/api/v1/repos/lars/{fine-tune,pim-sync}` → **404** (API itself reachable: `/api/v1/version` → `15.0.10`), plus source-verified instance defaults `ENABLE_PUSH_CREATE_USER`/`DEFAULT_PUSH_CREATE_PRIVATE` (SystemNix forgejo.nix:297-298). Public repos would have returned 200 — they did not.
- SystemNix edit parses: `nix-instantiate --parse configuration.nix` → OK (syntax only).
- **NOT verified:** Forgejo repo visibility as an *authenticated* view of the repo object (404-to-anonymous is consistent with private, not proof of the repo's `private` flag); phase-5 push-mirror attach (requires deploy — not run); `nix flake check`/eval of SystemNix (blocked, see d1); container sub-repos' remotes (~80 repos, counted but never checked); whether pim-sync/fine-tune CI or docs claims hold (out of scope per session directive); the full pim-sync test suite (never ran — no code touched in that repo).

---

## a) FULLY DONE

1. **Fleet remote audit, top level (the original ask).** 254 folders checked; 252 have git remotes or are non-repos by design. Found exactly 2 repos without remotes: `fine-tune`, `pim-sync`; classified all 20 non-repos (8 containers with sub-repos, 6 scratch dirs, 3 empty, `ssh-key-monitor.worktrees` = worktree container whose parent has a remote). Evidence: audit command output this session.
2. **`fine-tune` provisioned Forgejo-canonical.** Created via SSH push-to-create (`forgejo@evo-x2.home.lan:lars/fine-tune.git`), `master` pushed, remotes wired `origin` (Forgejo) + `github` (private twin `LarsArtmann/fine-tune`). Both remotes served `32a43e5` (verified via ls-remote). 4 files in tree (AGENTS.md, PLAN.md, .config, .crush) — docs-only repo, nothing lost, 0 tags.
3. **`pim-sync` provisioned Forgejo-canonical.** Same pattern (`lars/pim-sync.git` + `LarsArtmann/pim-sync`), pushed at `e9d44a2`, later catch-up pushed to `2f184bd` — SHA verified identical on both remotes at 19:14.
4. **GitHub twins created PRIVATE** via `gh repo create --private` with descriptions (fine-tune: "Fully local LLM fine-tuning (unsloth, ROCm, Docker on Strix Halo)" — deliberately neutralized vs the AGENTS.md prose, which names the NSFW subject matter; disclosed here so the difference is visible). `gh` confirms `visibility: PRIVATE`, default branch `master`, pushedAt stamped.
5. **Declarative GitHub sync wired:** both repos added to `services.forgejo.canonicalRepos` (SystemNix `platforms/nixos/system/configuration.nix:563-580`) with the established native-since-inception annotation style (quotaboard/pingen-spike precedent). On next deploy, phase 5 attaches outbound GitHub push mirrors (8h interval + sync-on-commit, idempotent). Neither repo has `.github/workflows` (pim-sync only `.github/dependabot.yml`), so the repo-scoped sync PAT suffices — no `workflow` scope needed.
6. **Forgejo privacy directly probed** (was initially only inferred from defaults): API reachable at `http://forgejo.home.lan` (v15.0.10), both repos 404 to anonymous → not publicly visible. Probe is repeatable by anyone.
7. **Pre-mirror drift caught and closed:** pim-sync's auto-commit daemon landed `2f184bd` ~30 min after provisioning, leaving both twins 1 commit behind; manual catch-up push executed and verified on both remotes.

## b) PARTIALLY DONE

1. **Automated GitHub sync (the "private GitHub sync" half).** Works today: manual `git push` to both remotes. Missing: phase-5 mirror attach — **gated on a SystemNix deploy**, which is itself gated on the broken flake eval (d1). Effort to finish: S once deploy unblocks (attach is automatic + idempotent); the deploy itself is owner action in an IO-quiet window.
2. **Fleet remote guarantee below top level.** Top level done (a1); the ~80 sub-repos inside containers (archived 32, minecraft 21, games 17, ci-siblings 5, forks 3, deep-review-cordiverse 3, stale 3, projects 2) were counted (`find -name .git -type d`) but their **remotes were never checked** — my in-session claim "each sub-repo has its own remotes" was an assumption presented as fact. Effort: S (one loop command). Wanted? Owner decides (see g3).
3. **GitHub twin hygiene.** Twins exist and are private, but `gh repo create` defaults left issues/wiki enabled — drift surfaces for a mirror twin (someone files an issue on GitHub, it can never reach Forgejo-primary). Not tuned. Effort: S per repo, but the *policy* decision is the owner's (g2).

## c) NOT STARTED

1. **Dependabot posture for pim-sync** — `.github/dependabot.yml` exists in a now-Forgejo-canonical repo. Dependabot PRs will pile up on the GitHub twin and never flow back (push mirror is Forgejo→GitHub only; pull direction is dead for native repos). Delete the file, keep it (with a documented "orphan PRs" caveat), or move dependency updates Forgejo-side (renovate)? Not started — needs owner decision (g2).
2. **Forgejo Actions CI for pim-sync** — evo-x2 runs a `native` label runner (per canonicalRepos preamble comments); neither repo has any CI definition. fine-tune arguably needs none (docs-only). Not started; interplay with pim-sync's BuildFlow setup unexamined (out of session scope).
3. **Provisioning runbook.** The quotaboard/pingen-spike annotations record *state* but nowhere records the *procedure* (push-to-create → gh twin → remotes → canonicalRepos entry → deploy). This session re-derived it in ~6 research hops. A recipe in `docs/services/forgejo.md` makes the next repo a 1-hop task. Not started. Effort: S.
4. **Non-repo directory dispositions.** `BuildFlow.vendor.bak`, `data`, `deep-review-reports`, `internal`, `scripts`, `Rezepte-und-Atteste-EU-Polen` (all unrecoverable-by-git if deleted — no repo, no remote), plus empty `Darknet-Monitor`, `gh-relations`, `sales`. No decisions made; nothing trashed (correctly — deletion needs owner say-so).
5. **README for fine-tune** — twins are live on two forges with no README (PLAN.md is authoritative per AGENTS.md, but a twin visitor sees nothing). S effort. Unknown whether pim-sync has one (listing was truncated; not checked — named, not guessed).
6. **Hostname split-brain audit.** Forgejo remotes in the fleet use two different SSH forms: `forgejo@evo-x2.home.lan:lars/…` (8 repos incl. the new two) vs `ssh://forgejo@forgejo.home.lan/lars/gogenfilter.git`. Both work; whether that aliasing is deliberate or drift is unexamined.

## d) TOTALLY FUCKED UP

1. **SystemNix flake eval is broken at HEAD — and it gates THIS session's main deliverable.** `nix eval .#nixosConfigurations` fails the infra-follows lock audit: `go-nix-helpers_3` locks its own `treefmt-nix` deep copy without a follows override. Introduced by HEAD commit `e9b353742` ("chore(flake): refresh flake.lock across upstream inputs" — another session's work; flake.lock/flake.nix are clean in the working tree, so this predates and excludes my edit; the audit fails before configuration.nix is even loaded). Severity: blocks ALL flake commands → blocks deploys → blocks phase-5 mirror attach → pim-sync/fine-tune twins stay manual-push-only indefinitely. Root cause named in the error with its own fix (add `go-nix-helpers_3.inputs.treefmt-nix.follows = "treefmt-nix"` to the infra-follows group, or a documented `deliberate` entry in `lib/lock-audit.nix`). Not fixed here: unrelated to session scope, and another session's commit is theirs to fix forward.
2. **Structural twin-drift window until deploy.** Observed live: one daemon commit drifted pim-sync 1 commit behind both twins within ~30 minutes. Every daemon commit widens the gap until phase 5 attaches. Mitigation exists (manual catch-up, done once at 19:14) but it is manual and per-repo — this WILL recur for fine-tune/pim-sync and any future canonical repo. Systemic fix = the deploy in d1; stopgap = a catch-up script (f-item).
3. **Mixed-commit hazard in the SystemNix tree right now.** My `configuration.nix` edit sits uncommitted alongside *another session's* modified `docs/planning/2026-11-03_data-redesign-latency-first-design.md` + an untracked status doc. The auto-commit daemon will bundle them into one heuristic commit. Nothing done about it (untouched others' work per policy) — flagged so the deploy unit isn't a surprise. Severity: process noise, not data loss.

## e) WHAT WE SHOULD IMPROVE

1. **Verify claims before asserting them, even small ones.** Two instances this session: (i) Forgejo privacy asserted from instance defaults, only probed directly after the fact — the probe costs 30 seconds; (ii) container sub-repos' remotes asserted without a single check. Both would have been caught by one extra command each at claim-time.
2. **Capture procedures, not just state.** The canonicalRepos annotations are excellent state memory but the provisioning *recipe* lives nowhere — this session paid ~6 hops of research (remotes → SystemNix → mirror script → nix module → precedent comments). Write the runbook (c3); it converts the next provisioning from an hour of archaeology to minutes.
3. **Tokenless-path-first research.** The winning move (push-to-create via `ENABLE_PUSH_CREATE_USER`) was found in the nix module, not in any doc a session would read first. Surface instance capabilities in `docs/services/forgejo.md`'s head (or AGENTS.md) so the next session starts there.
4. **Scope greps before running them.** The first `grep -ril forgejo ~/.config` hit JetBrains dictionaries and hung → auto-backgrounded → interrupted → wasted a round trip. Every subsequent scoped `timeout N rg …` worked first try. Pattern: always bound unscoped greps.
5. **Post-delivery drift check.** The drift (d2) was only discovered because the user demanded a status report. A 5-second `ls-remote` diff right before ending a provisioning session should be part of the routine — "pushed" and "in sync" are different claims.
6. **GitHub-twin default settings are silently wrong for mirror twins.** `gh repo create` leaves issues/wiki on. If twin-as-frozen-mirror is the policy, provision with `--disable-issues --disable-wiki` (and consider a `gh api` pass over the four existing native twins). Policy first (g2), then one-shot fix.

## f) NEXT TASKS (up to 50; ranked by impact; feeds docs-health HARVEST)

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 1 | Fix flake lock audit: add `go-nix-helpers_3.inputs.treefmt-nix.follows = "treefmt-nix"` (or documented `deliberate` entry) — unblocks ALL deploys | Critical | S | Bug |
| 2 | Deploy SystemNix in an IO-quiet window → phase 5 attaches push mirrors for fine-tune + pim-sync (8h + sync_on_commit) | Critical | S | Feature |
| 3 | Post-deploy verify: `push_mirrors` populated on both repos + `sync_on_commit` lands a commit on each GitHub twin (check pushedAt via gh) | Critical | S | Quality |
| 4 | Check what `forgejo-branch-protect` (phase at `_forgejo-scripts.nix:1188`) does to newly canonical repos — decide if branch protection wanted on fine-tune/pim-sync | High | S | Quality |
| 5 | Decide GitHub-twin posture: frozen mirror (disable issues/PRs/wiki/Actions/Dependabot on all native twins) vs live twin | High | S | Decision |
| 6 | Per g2 decision: delete or annotate pim-sync's `.github/dependabot.yml` (orphan-PR caveat if kept) | High | S | Cleanup |
| 7 | One-shot `gh api` pass: align the four existing native twins (company-master-data, media-atlas, pingen-spike, quotaboard) with the g2 posture | High | M | Cleanup |
| 8 | Write provisioning runbook (push-to-create → twin → remotes → canonicalRepos → deploy) into `docs/services/forgejo.md` | High | S | Documentation |
| 9 | Until deploy lands: after any working session on fine-tune/pim-sync, `ls-remote`-diff + catch-up push (or script it, #10) | High | S | Process |
| 10 | Tiny `forgejo-twin-sync.sh`: push origin+github, diff SHAs, exit non-zero on drift | High | S | Quality |
| 11 | Answer g3, then (if in scope) run the sub-repo remote audit across the ~80 container repos (`forks/`, `archived/`, `games/`, `minecraft/`, `stale/`, `ci-siblings/`, `projects/`, `deep-review-cordiverse/`) | High | S | Audit |
| 12 | Commit SystemNix canonicalRepos change as a clean deploy unit — separate it from the other session's planning-doc changes before the daemon bundles them (d3) | High | S | Process |
| 13 | `fine-tune`: write a README for the twins (PLAN.md summary, machine facts, no NSFW specifics needed on a private repo) | Medium | S | Documentation |
| 14 | Check whether pim-sync has a README; add if missing | Medium | S | Documentation |
| 15 | Decide Forgejo-side issue tracker for pim-sync (it's an app on the primary forge now; Forgejo issues vs GitHub-issues-on-twin) | Medium | S | Decision |
| 16 | Hostname split-brain: standardize Forgejo SSH remote form (`evo-x2.home.lan` vs `forgejo.home.lan` — gogenfilter differs) or document the alias as deliberate | Medium | S | Cleanup |
| 17 | Dispose-or-adopt decision for the 6 non-repo dirs with content (`BuildFlow.vendor.bak`, `data`, `deep-review-reports`, `internal`, `scripts`, `Rezepte-und-Atteste-EU-Polen`) — trash or git-init or leave, per dir | Medium | M | Cleanup |
| 18 | Trash the 3 empty dirs (`Darknet-Monitor`, `gh-relations`, `sales`) — or recreate with intent | Low | S | Cleanup |
| 19 | Forgejo Actions CI for pim-sync (`runs-on: native` precedent) — only after BuildFlow interplay is understood | Medium | M | Feature |
| 20 | Document fine-tune's future LFS risk (model checkpoints, if ever committed → Forgejo LFS is on, GitHub twin has 100 MB hard limit) in its AGENTS.md now, before it bites | Medium | S | Documentation |
| 21 | Add `fine-tune`/`pim-sync` remote + Forgejo-canonical status lines to their own AGENTS.md files (memory-at-discovery duty) | Low | S | Documentation |
| 22 | Verify gogenfilter-style flip services (`forgejo-flip@*`) unaffected by the new list entries (fixture checks exist: `fixtures-forgejo.nix`) — run once flake eval is fixed | Medium | S | Quality |
| 23 | After deploy, re-run `forgejo-attach-org-push-mirrors.sh` sanity pass? No — org script is org-scoped; instead confirm phase-5 log line for the two new repos | Low | S | Quality |
| 24 | Check `mirror.DEFAULT_INTERVAL` 2h (pull mirrors) vs phase-5's hardcoded 8h (push mirrors): confirm 8h+sync_on_commit is the intended push posture, annotate if so | Low | S | Documentation |
| 25 | Confirm the Forgejo HTTP API exposure (`forgejo.home.lan` reachable unauthenticated from LAN) is intended; if not, tighten Caddy | Medium | S | Security |
| 26 | Tag strategy: both repos have 0 tags; pim-sync is Go — decide if/when go-release flow applies (Forgejo-primary changes tag push targets) | Low | S | Decision |
| 27 | Set GitHub twin default branches explicitly (already `master`, verified — re-check only if settings churn) | Low | S | Quality |
| 28 | Add topics/descriptions on Forgejo repos to match the GitHub twins (descriptions were only set GitHub-side; Forgejo repos have none) | Low | S | Documentation |
| 29 | Periodic (post-deploy) drift monitor: one cron/one-shot that diffs local vs both twins for the canonical set | Medium | M | Feature |
| 30 | Decide whether `github-local-sync` or `project-meta` should record the new canonical repos in whatever fleet inventory they keep (existence unverified — named as follow-up, not researched per session scope) | Low | S | Documentation |
| 31 | fine-tune: no `.config` review this session — confirm its checked-in config carries no secrets before twins are broadly visible | Medium | S | Security |
| 32 | pim-sync: same secret-scan over its full tree (first time this repo has EVER left the machine) | Medium | S | Security |
| 33 | Confirm btrbk/restic coverage story for the two new repos is unchanged (they're inside `/var/lib/forgejo` subvol like the rest — verify docs/services/forgejo.md backup table mentions nothing repo-specific needed) | Low | S | Documentation |
| 34 | Consider `sync_on_commit` verification cadence: after deploy, watch one real daemon commit flow Forgejo→GitHub end-to-end (the 19:14 manual push was the last verified flow) | Medium | S | Quality |
| 35 | Record the "provisioned via push-to-create, NOT API" nuance in the runbook (#8): token exists only root-side on evo-x2; push-to-create is the tokenless path from dev machines | Low | S | Documentation |

*(35 items — stops where specificity ends; more would be ROADMAP filler.)*

## g) QUESTIONS ONLY YOU CAN ANSWER (3)

1. **When is the next SystemNix deploy window?** Phase-5 mirror attach (and my canonicalRepos entries) activate only then — and item #1 (lock-audit fix) gates it. Everything else about the twins' automation flows from this one date. I can't schedule or deploy for you.
2. **Frozen mirror or live twin?** Should GitHub twins be write-disabled backups (issues/PRs/wiki/Actions/Dependabot off, push-only), or stay live surfaces? This decides pim-sync's `dependabot.yml` fate (#6) and the settings pass (#7). I searched this session's scope and found no recorded decision either way — the twins so far just inherited `gh` defaults.
3. **Are the ~80 container sub-repos in scope for "all projects have remotes"?** Top level is done and verified. I asserted their remotes exist without checking. If they're in scope, say so and I'll run the audit; if containers are exempt by definition, the guarantee is already met and I'll correct my earlier claim explicitly.

---

*Report per `status-report` skill (`.md` default per 2026-10-27 decision; self-review questions folded into d/e per session request). Section (f) is HARVEST input — routes to `TODO_LIST.md` (#1-#12, #16, #25, #31, #32) and `ROADMAP.md` (the rest) when you say go. No commit performed (harness: no commits without explicit request); the auto-commit daemon will pick this file up.*

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.1 f.2 f.12 f.22 f.24 · OBSOLETE f.9 f.27 · NEW rowed: 15 rows (merged f.3+23+33+34+20-41 §f.2, f.5-7, f.8+35, f.13+14, f.15+26, f.17+18, f.20+21, f.29+30, f.31+32) → services 13, security 2
