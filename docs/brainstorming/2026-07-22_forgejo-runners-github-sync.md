# Forgejo Runners, GitHub Sync & Issue Sync

_2026-07-22_

## Context

Forgejo is deployed with bidirectional GitHub mirroring and an Actions runner.
This document analyzes how each layer works, what the gaps are, and whether a
dedicated sync daemon (like DiscordSync) is warranted.

---

## 1. Forgejo Runners — Current State & Opportunities

### What's configured

One runner registered on host `evo-x2` with three labels (`forgejo.nix:25-35`):

| Label                                     | Executor         | Use case                               |
| ----------------------------------------- | ---------------- | -------------------------------------- |
| `ubuntu-latest:docker://node:22-bookworm` | Docker container | CI matching GitHub Actions environment |
| `ubuntu-22.04:docker://node:22-bookworm`  | Docker container | Same, pinned version                   |
| `native:host`                             | Direct host exec | Nix builds, system-level tasks         |

- Capacity: 2 concurrent jobs
- `DEFAULT_ACTIONS_URL = "github"` — workflows can reuse standard GitHub Actions (checkout, setup-go, etc.) directly
- `MemoryMax = 4G` per job
- Docker executor pulls `node:22-bookworm` on first run

### How to leverage runners

Add `.forgejo/workflows/*.yml` to any repo that needs CI — syntax is compatible with GitHub Actions:

- **`runs-on: ubuntu-latest`** for portable Docker-based jobs (build, test, lint)
- **`runs-on: native`** for Nix-native jobs (`nix build`, `nix flake check`) — this is where Forgejo runners shine over GitHub Actions since they have the full Nix toolchain on the host

### Practical ideas

- Run `nix flake check --no-build` on every push to SystemNix via a native runner job
- Run `go test ./...` on Go repos (dnsblockd, monitor365, etc.)
- Run `buildflow` checks before merge
- Run `golangci-lint` and `statix` on PRs

---

## 2. Bidirectional Sync — How It Works

Both directions are wired and functional.

### GitHub → Forgejo (pull mirror)

- Created at migration time via `mirror: true` in the migrate payload (`forgejo.nix:124`)
- Forgejo's built-in cron pulls new commits every 30 minutes (`cron.update_mirrors`, line 634-640)
- Only fetches **git refs** (branches, tags, commits) — nothing else
- Rate limited: `PULL_LIMIT = 50` repos per cycle

### Forgejo → GitHub (push mirror)

- Set up via `POST /api/v1/repos/{owner}/{repo}/push_mirrors` with `sync_on_commit: true` (`forgejo.nix:138-147`)
- Every commit pushed to Forgejo is automatically pushed to GitHub
- The GitHub token is embedded in the remote URL

### Net effect

You can `git push` to either Forgejo or GitHub, and changes propagate to the
other within 30 minutes (or instantly for Forgejo → GitHub).

---

## 3. Why Issues, Milestones, PRs Are Not Synced

The migrate payload sets `issues: true, milestones: true, pull_requests: true,
labels: true` (`forgejo.nix:127-130`). But they don't sync because of a
**fundamental Forgejo/Gitea design constraint**:

**Mirror repos only sync git refs. Period.**

When `mirror: true`:

- The `issues`, `pull_requests`, `milestones`, `labels` flags are **silently
  ignored** by the migrate endpoint for mirror repos
- `wiki` and `releases` may get a one-time import, but are never updated by the
  periodic mirror sync
- The `cron.update_mirrors` job runs `git fetch` — it has no mechanism to sync
  GitHub Issues or PRs (those are API objects, not git data)

These flags exist for **non-mirror migrations** (`mirror: false`) — one-time
copies that import everything once but never update.

### Options to sync issues/PRs

1. **One-way periodic script (~100 lines)** — GitHub API → Forgejo API copy,
   run as a systemd timer. Covers 90% of the need for a solo developer.
2. **Switch to `mirror: false`** — one-time copy, then maintain issues locally
   in Forgejo only. Lose automatic git ref syncing.
3. **Third-party tool** — various GitHub-Actions-based syncers exist but none
   are maintained or fit the Forgejo mirror model cleanly.
4. **Forgejo migration API** — periodically call the migrate endpoint without
   mirror flag. Fragile and unsupported for mirrors.

None of these are premade/maintained tools. The periodic script would be
custom-written into `forgejo.nix`.

---

## 4. Sync Architecture — Step by Step

Three independent layers operate:

### Layer A — Bootstrap/Discovery (`forgejo-github-sync` timer)

- **Timer:** every 6h + 5min after boot (`forgejo.nix:753-761`)
- **Script:** `forgejo-mirror-github` — fetches GitHub repo list via API,
  creates any missing repos as pull mirrors in Forgejo, sets up push mirrors
- **Idempotent:** skips repos that already exist (HTTP 200 check)

### Layer B — Pull Mirror (Forgejo built-in cron)

- **Schedule:** `@every 30m` (line 636)
- **Mechanism:** Forgejo runs `git fetch --prune` against each mirror's remote
- **Scope:** branches and tags only
- **Rate limits:** `PULL_LIMIT = 50` repos per cycle

### Layer C — Push Mirror (event-driven)

- **Trigger:** `sync_on_commit: true` — fires immediately on push to Forgejo
- **Mechanism:** Forgejo runs `git push --mirror` to GitHub
- **Scope:** all branches and tags

### Layer D — `forgejo-repos.nix` (declarative specific repos)

- Runs on rebuild + daily timer
- Same migrate + push-mirror pattern, but for a specific list of SSH-URL repos
- Uses SSH URLs (`git@github.com:...`) instead of HTTPS + token

### Token flow

```
forgejo-generate-token.service
  → generates admin API token → /var/lib/forgejo/.admin-token.env
    → consumed by forgejo-github-sync (EnvironmentFile)
    → consumed by forgejo-ssh-keys (reads directly)
    → consumed by forgejo-ensure-repos (EnvironmentFile)
```

---

## 5. Decision: No Dedicated Sync Daemon

**Recommendation: do NOT build a dedicated sync daemon like DiscordSync.**

### Why DiscordSync exists vs why this doesn't warrant one

| Aspect           | DiscordSync                                     | Proposed github-local-sync                       |
| ---------------- | ----------------------------------------------- | ------------------------------------------------ |
| Source platform  | Discord — no export, no git, no standard format | GitHub — full REST API, git-native, export tools |
| Data gravity     | Discord owns your data, can't clone it          | `git clone` exists, mirrors work natively        |
| Sync mechanism   | WebSocket gateway (custom bot required)         | Forgejo built-in `git fetch` + push mirrors      |
| Current solution | Impossible without a daemon                     | Already works (shell scripts + Forgejo cron)     |

DiscordSync exists because **there is no other way** to get Discord data. The
GitHub sync already works — Forgejo's built-in mirror system handles the hard
part (git refs in both directions). The shell scripts are just
discovery/bootstrap, not the sync engine.

### Additional reasons against a daemon

- **Solo developer** — repos have minimal issue/PR volume. ROI of building a
  5000-line event-sourced Go application to sync a handful of issues is negative.
- **Bidirectional issue sync is genuinely hard** — user identity mapping,
  attachment URL rewriting, markdown flavor differences, label/reaction
  translation. Multi-month project with diminishing returns.
- **Maintenance burden** — another repo, another flake, another NixOS module,
  another database, another thing that can break.

### What to do instead

1. **Current approach (shell scripts + Forgejo built-ins): keep as-is** —
   correctly solves the actual problem: local git backup with bidirectional
   commit flow
2. **If issue sync becomes a real need**: add a periodic `forgejo-sync-issues`
   oneshot script (one-way GitHub → Forgejo copy) to the existing `forgejo.nix`
   module — ~100 lines, no new repo
3. **For runner leverage**: add `.forgejo/workflows/` files to repos — that's
   where the real value is (free CI on your own hardware)
