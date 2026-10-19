# Forgejo Task-Queue Batch — Avatar Live-Verify + Swagger Contract + `domains` Flip Verify

**Session:** 2026-10-19 ~04:45–06:00 CEST · **Queue-ID:** `000001a1522b185f8bbf64b33db300000000` (3 items, one session)
**Repo:** SystemNix (read-only verification batch — zero config changes; one cross-repo annotation in `~/projects/domains`)
**Re-dispatch check:** `git log --grep Task-Queue-ID` → no prior footer commits; fresh dispatch.

---

## Item 1 — Avatar parity sync live-verify: **DONE (all criteria met)**

| Criterion (from the row) | Live evidence |
| --- | --- |
| First post-deploy run uploads all org avatars | `journalctl -u forgejo-github-sync` 2026-10-16 00:57:44: `targets=9 updated=8 in-sync=0 failed=1` — 7 org avatars + the then-enabled user avatar uploaded; `org:vonArtmann` 404 (no local twin — the later absent-target skip + `forgejo_avatar_skipped` gauge covers it) |
| Second run `updated=0` (verbatim-storage assumption) | 2026-10-16 01:22:34: `targets=8 updated=0 in-sync=7 failed=1` — **byte-compare converged, forgejo stores uploads verbatim CONFIRMED**; same run already carried the OIDC kill-switch (`User avatar sync skipped (FORGEJO_AVATAR_SYNC_USER=false)`) |
| Steady state green | Every run 2026-10-18/19: `targets=8 updated=0 in-sync=7 failed=0 skipped=1` (latest 2026-10-19 04:41:47) |
| Metrics `forgejo_avatar_*` | Prom file present + **end-to-end scrape proven**: `python3` GET `127.0.0.1:9100/metrics` serves `forgejo_avatar_failed 0`, `forgejo_avatar_in_sync 7` (node_exporter textfile chain live) |
| Org pages render GitHub avatars | `in-sync=7` IS the render proof at byte level: the phase GETs forgejo's served `avatar_url` and sha256-compares against GitHub's bytes — 7/7 identical |

**Verdict:** ORG-only expectations exactly met; user avatar correctly OIDC-owned since the second run. No code changes needed.

## Item 2 — Issues/comments API contract vs deployed swagger: **DONE (contract clean, zero fixes)**

Probe: `https://forgejo.home.lan/swagger.v1.json` (live v15.0.10, 828 KB, downloaded to `~/.cache/forgejo-batch/`). All 5 paths used by `~/projects/domains/.forgejo/workflows/deploy.yml` verified:

| Workflow call (deploy.yml) | Swagger verdict |
| --- | --- |
| `GET /repos/{owner}/{repo}/issues/{index}/comments` (:131) | ✓ `issueGetComments` |
| `POST /repos/{owner}/{repo}/issues/{index}/comments` (:137, :156) | ✓ `issueCreateComment` |
| `PATCH /repos/{owner}/{repo}/issues/comments/{id}` (:134) | ✓ `issueEditComment` (`{id}` = comment id — workflow passes the listed `.id`, correct) |
| `GET /repos/{owner}/{repo}/issues?state=open&type=issues` (:152) | ✓ `issueListIssues`; query params `state` AND `type` both exist in v15 |
| `POST /repos/{owner}/{repo}/issues` (:159) | ✓ `issueCreateIssue` |

Body/field checks: `CreateIssueCommentOption.required = ["body"]` ✓, `EditIssueCommentOption.required = ["body"]` ✓, `CreateIssueOption.required = ["title"]` ✓ (workflow sends `{title, body}`); `Comment.{id,body}` + `Issue.{number,title}` fields present for the workflow's jq selectors; `PATCH` body `$ref → EditIssueCommentOption` confirmed. **The pre-flip gate is cleared contract-clean — the flip's red-run risk from d4 of the 06-37 report is retired.**

## Item 3 — `domains` Forgejo-primary flip verification: **2 of 4 legs ✓, 1 root-caused → owner, 1 blocked:user**

Context recovered: the flip itself already executed 2026-10-16 (G2 session, `docs/status/2026-10-16_07-31_*` §a2: dry-run → flip → `mirror:false` API-verified, import parity 1 issue + 1 PR); `FORGEJO_CANONICAL_REPOS=domains eventcatalog-hub` is LIVE in the deployed gen-932 unit (read from `/etc/systemd/system/forgejo-github-sync.service`).

| Leg | Verdict | Evidence |
| --- | --- | --- |
| `mirror == false` | ✓ | Hourly phase-5 script GETs the repo and REFUSES pull-mirrors (`✗ still a PULL mirror` path) — every run since 10-18 logs `✓ domains: push mirror already attached` (latest 05:41:39), so `.mirror` is false by script behavior; flip-time API check 2026-10-16 §a2 |
| Phase-5 push mirror attached | ✓ | Same hourly `already attached` line = `push_mirrors` length ≠ 0 via API |
| `sync_on_commit` reaches GitHub | ✗ **ROOT-CAUSED → owner** | Hook fires (2026-10-19 05:12:21 pre/post-receive → 05:12:25 `SyncPushMirror`) but **GitHub rejects**: `! [remote rejected] master -> master (refusing to allow a Personal Access Token to create or update workflow .github/workflows/deploy.yml without workflow scope)` — same for the stale imported `dependabot/github_actions/actions-f1906c3da7` branch. github/master frozen at `aba7cb9` (2026-10-16 08:40) vs `origin/master = 5c2bc02`: **96 commits stuck**. The PAT itself is healthy (harness: `gh api user` → LarsArtmann, repo perms `push:true`; `git ls-remote` over HTTPS works) — ONLY the workflow-scope gate blocks, because the unpushed range carries 4+ commits touching `.github/workflows/*` (incl. `5c174a0` Stripe Payment Link redirects) |
| `runs-on: native` Actions job green | ⛔ unverifiable agent-side | Runner picks domains tasks up (task 106→137, latest 2026-10-19 04:04) but run CONCLUSIONS need the forgejo API — no agent-readable token exists (`/var/lib/forgejo/.admin-token.env` is root/forgejo-only; `/run/secrets/rendered/forgejo-sync.env` holds only `GITHUB_TOKEN`/`GITHUB_USER`). Agent forgejo access is already a standing [blocked:user] row in the domains repo. Note `ci.yml` (`Terraform CI`) is secret-free and CAN go green; `deploy.yml` cannot until the owner mints `NAMECHEAP_*`/`GCP_TERRAFORM_STATE_KEY`/`FORGEJO_TOKEN` (still 🔵 blocked:user there) |

**Fix recipe (owner, also queued as [blocked:user] in `docs/todo/services.md`):** mint a classic PAT with `repo` + `workflow` scopes → update the push-mirror credential forgejo-side (UI Settings → Mirrors, or `PATCH /repos/lars/domains/push_mirrors/{name}`) → optionally align `forgejo-sync.env` `GITHUB_TOKEN` in sops at the next rotation (API reads work scope-free) → `cd ~/projects/domains && nix run .#mirror-lag` until OK. The planned burn-in end-state (delete `.github/workflows/*` ~2026-10-23) removes the long-term need for `workflow` scope but does NOT unstick the already-stuck 96-commit range. `workflow_dispatch`-only caveat: forgejo re-sends the WHOLE ref set on each mirror attempt — the stale dependabot branch ref will keep one rejection line alive until deleted forgejo-side.

## Side-finding checked, NOT queued

The forgejo-journal `pull mirror failed to meet migration URL requirements: migration/cloning from 'github.com' is not allowed` storm (~150 lines / 48 h) is already documented as the benign DNS-blip class in `docs/services/forgejo.md` ("Transient ... self-heals, no action") — re-verified against the runbook, no row.

## Self-harvest (report-authoring-time)

- PAT `workflow`-scope fix → `docs/todo/services.md` [blocked:user] row (deliberately NOT harvested into `TODO_LIST.md`: not agent-executable, and the queue harvests `[ready]` only).
- "First REAL push-triggered Actions runs" verification → already exists as `docs/todo/services.md` "Verify the first REAL push-triggered Actions runs on the G2-flipped repos" [ready] — no duplicate row; this report's runner evidence (task pickup through 137) feeds it.
- Runbook push-mirror section: the workflow-scope trap added in-batch (5-min fix on sight, item-3 commit).

## Verification chain

Live journal reads (`forgejo-github-sync`, `forgejo`, `gitea-runner-evo\x2dx2`) → deployed-unit env read → prom file + python3 :9100 scrape → downloaded-swagger jq checks (stdin-form, DIRENV_DIFF-safe) → secret-safe PAT harness (`gh-probe.sh`, token never on a command line, file removed after) → three-ref git comparison (`5c2bc02` / `5c2bc02` / `aba7cb9`). Nothing mutated: no config changes, no pushes (GitHub untouched; domains repo only annotated), no service restarts.
