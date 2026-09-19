# Rogue Git-Identity Audit + Declarative Identity — 2026-09-14 (task queue)

Closes TODO_LIST P1 "Rogue git-identity audit across all repos + declarative global identity"
(source: `docs/status/2026-08-18_13-53_pma-commit-failures-crush-identity-and-daemon-recovery.md` §b/§f).

## 1. Audit — all `~/projects/*` git repos, full history (`git log --all --format='%an <%ae>'`)

Foreign/agent identities found in Lars-owned repos (upstream histories in cloned
third-party repos — e.g. `hermes-agent`'s dozens of community Hermes Agent
identities — are upstream authors, NOT local leaks, and excluded):

### AI-agent identities (the incident class)

| Identity                                                        | Repos (count)                    | Notes                                                                                                                                                                                                                                                                                                                                                                                             |
| --------------------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Unknown Author <unknown@example.com>`                          | ~100 repos, ~5,200 commits total | Largest cohort. Top: go-cqrs-lite 238, monitor365 227, BuildFlow 219, PapDashboard 189, go-workflow-auditlog 160, project-discovery-sdk 135, erraudit 134, samber-do-auditlog 140, template-CLI 135 (Claude also), art-dupl 131, CV 23, DiscordSync 120, cqrs-htmx 119. These are the pre-2026-08-18 era commits from the identity-less-repo gap (PMA heuristic fallback + early Crush sessions). |
| `Claude <noreply@anthropic.com>`                                | ~30 repos, ~900 commits          | template-CLI 135, CreditReformBilanzampel 92, smart-configs 92, SQLC-Wizzard 65, standard-bug-tracking-schema 64, artmann-holding 70, CV 40, library-policy 17, invoices 19, Domination 20, ai-task-prioritizer 16, accountability-system 37, others ≤14.                                                                                                                                         |
| `Crush <crush@larsartmann.com>`                                 | CV only — 163                    | The original incident. Local override removed + `.mailmap` added 2026-08-18; commits still carry the author on GitHub (rewrite decision = user, below).                                                                                                                                                                                                                                           |
| `Crush <crush@charm.land>`                                      | Kernovia — 2                     | Second Crush identity (charm.land domain variant).                                                                                                                                                                                                                                                                                                                                                |
| `Crush <crush@MiniMax.local>`                                   | dnsblockd — 7                    | Third Crush identity variant.                                                                                                                                                                                                                                                                                                                                                                     |
| `hermes-agent <hermes@noreply.forgejo.home.lan>`                | SystemNix — 2                    | Local hermes agent commits via the Forgejo mirror.                                                                                                                                                                                                                                                                                                                                                |
| `Hermes AI Agent Gateway service user <hermes@evo-x2.home.lan>` | go-taskqueue — 3                 | Local hermes gateway service commits.                                                                                                                                                                                                                                                                                                                                                             |

### Lars variant identities (legit-looking but non-canonical)

- `Lars <lars@evo-x2.home.lan>` — project-dependency-graph, 23
- `Lars Artmann <art@onprem-nixos0.>` — private-cloud 7, template-readme 6
- `art <me+onprem@lars.software>` — private-cloud 72, test-runner-repo 1
- `LarsArtmann <larsartmann@users.noreply.github.com>` — SystemNix **local config override** (see §3)

### Local git identity overrides still present (3 repos)

- `SystemNix`: `LarsArtmann <larsartmann@users.noreply.github.com>` (Lars-owned but non-canonical)
- `dnsblockd`: `Lars Artmann <>` (empty email — git accepts, GitHub attributes to nobody)
- `go-crush-data`: `Lars Artmann <git@lars.software>` (identical to global — harmless redundancy)

## 2. Declarative identity — DONE

- HM `platforms/common/programs/git.nix` already sets `user.name = "Lars Artmann"` /
  `user.email = "git@lars.software"` via `programs.git.settings.user` (verified — no change needed).
- The 2026-08-18 hand-set `~/.gitconfig` `[user]` entries (the §d4 split-brain layer)
  are REMOVED (`git config --global --unset user.{name,email}`). The rest of
  `~/.gitconfig` (insteadOf, town aliases, credential helpers) is owned by other
  tooling and untouched. Effective identity verified: resolves from the HM-managed
  `~/.config/git/config` in a fresh identity-less repo (`git init /tmp/idtest` →
  `Lars Artmann <git@lars.software>`).
- The global identity closes the ROOT ENABLER (identity-less repos → invented
  identities) for all FUTURE commits; existing PMA daemon env already carries
  `GIT_AUTHOR_*` (2026-08-18 fix, still live).

## 3. User decision — rewrite history or leave (NOT actionable by agent)

Options, in rough effort order:

1. **Leave as-is (cheapest).** Identities are cosmetic in private repos;
   `.mailmap` per-repo fixes local tooling display. GitHub-facing attribution
   stays wrong.
2. **`.mailmap` sweep (cheap, local-only).** Add the canonical mapping
   (`Lars Artmann <git@lars.software>` + all variants/agents) to every affected
   repo; `git shortlog`/`git log --use-mailmap` then show clean attribution.
   Does NOT rewrite anything.
3. **History rewrite (`git filter-repo --mailmap` or `--replace-message`).**
   Rewrites author/committer across the affected repos. Consequences: force-push
   every affected repo (forks/caches keep old SHAs regardless), re-clone all
   worktrees, signed commits invalidated (SSH signatures on rewritten commits
   break), and go module proxy pseudo-version stability churn for published
   LarsArtmann Go repos (CV, go-cqrs-lite, etc. — tags would need re-cutting,
   which poisons module-proxy alignment, cf. the go-output v0.37.0 re-tag
   incident). HIGH cost, mostly cosmetic payoff.

Recommendation: option 2 (mailmap sweep), leave history intact. Not executed
here — per-repo commits in ~100 repos are outside this task's smallest-correct
change and the choice is the item's explicit user decision.

## 4. Actions taken this session

1. Full `~/projects` author audit (results above).
2. Removed the hand-set `~/.gitconfig` `[user]` split-brain layer; verified
   effective identity resolves from HM config.
3. No SystemNix tree change was required for the declarative identity itself
   (git.nix already correct).
