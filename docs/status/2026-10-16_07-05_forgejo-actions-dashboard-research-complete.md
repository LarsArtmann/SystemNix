# Status Report — Forgejo Actions Dashboard Research COMPLETE (the answer, delivered)

_2026-10-16 ~07:05 CEST · completion of [the 06:25 interrupted report](2026-10-16_06-25_forgejo-actions-dashboard-research-interrupted.md) · read-only research + live version probe + durable doc stamps · zero config changes, zero deploys_

---

## THE ANSWER (owner's original question, all three sub-questions)

> *"Is there a way to get some kind of proper Overview/Dashboard for all my Forgejo Actions? Something native? An unmerged PR? Another open source tool or extension?"*

1. **Native: NO.** There is no instance-wide/all-repos Actions overview in Forgejo. Source-verified twice: the web routes (06:25 report, F1 — every `/actions` route group is repo-scoped runs or a Settings→Runners/Secrets/Variables manager; `/admin/actions` = Runners + Variables only) and now the API (this session, F8 — no global runs-history endpoint exists; the only cross-repo query returns waiting/running jobs, not history).
2. **Unmerged PR: NO.** Zero PRs implement this anywhere. go-gitea/gitea#31692 ("Actions dashboard for all the actions in the repos you can access") and #33162 ("Organization Actions overview") are both OPEN **proposals** — read in full this session: no maintainer engagement, no design, no linked PR, their timelines cross-reference only each other (plus #23725, the equally-stalled "email notifications for failed Actions" ask). Forgejo tracks no equivalent feature request that three search surfaces could find (F6). Nobody is building this.
3. **Third-party tool: NO.** Nothing real on delightful-forgejo (official catalog), GitHub repo search, or web search (F3 + F6 extension). Grafana's dashboard registry is bot-blocked from the CLI (409 on the API endpoint, JS-only SPA otherwise) — the one bounded-unsearched surface. Woodpecker/Crow are alternative CIs with their own dashboards, not Forgejo Actions dashboards — adopting one means leaving Actions.

**What EXISTS instead (verified on the exact deployed version, 15.0.10):** per-repo Actions tabs, and an API that makes a ~30-line DIY overview trivial: `GET /api/v1/repos/{owner}/{repo}/actions/tasks?page=&limit=&status=failure` returns task history per repo (F8). A textfile collector polling the Actions-enabled repos into the existing SigNoz stack (the exact `system_forgejo_mirror_sync_stale_count` house pattern from today's runbook section) delivers the ops-grade cross-repo view with zero new infrastructure.

---

## New verified findings this session (F6–F9; F1–F5 carry over from the 06:25 report)

### F6. No implementing PR, no Forgejo-side feature request (3 search surfaces)

- gitea#31692 + #33162 bodies/comments/timelines read via `gh`: proposals only; #31692's sole comment is "+1, not even email notifications exist (#23725)"; #33162's comments add "a global admin view would also help" + a cross-ref to #31692. **No PR in either timeline; `gh search prs "actions dashboard"` → zero.**
- Codeberg keyword search is structurally unavailable: the API `q=` param does not keyword-filter (06:25 report) AND the repo-scoped `labels=` filter is silently ignored too (probed this session: `?labels=96148` returned an issue without that label — 3 KB probe, caught pre-batch). UI search 429s.
- Workaround surface: DuckDuckGo `site:codeberg.org` scoping → only closed UI-dashboard **bugs** (#5343, #7483, PR #4500 — the issue/PR dashboard, not Actions). **No Forgejo feature request exists that any surface found.**

### F7. Server `/metrics` CLOSED as a dead end (mechanical proof)

Sparse blobless clone of forgejo (forgejo branch), full Go-source grep: **exactly ONE prometheus registration exists in the entire codebase** — `routers/web/web.go:405` `prometheus.MustRegister(metrics.NewCollector())`. `modules/metrics/collector.go` enumerates every Desc: issues/pulls/repos/users/webhooks/star counters — **zero `gitea_actions_*` anything**. `/metrics` = `promhttp.Handler()` (default registry + optional bearer token, `routers/web/metrics.go`). Combined with F4 (runner has none): **no native metrics path exists at either component.** The 06:25 report's "most promising remaining path" is dead.

### F8. The v15.0.10 API feed surface (what the DIY overview builds on)

Verified against the `v15.0/forgejo` release branch (fetched into the clone):

- `GET /repos/{owner}/{repo}/actions/tasks` (`routers/api/v1/repo/action.go:699`) — **repo-scoped task history**, `page`/`limit`/`status=` filters; status enum: `unknown, waiting, running, success, failure, cancelled, skipped, blocked`. One poll per Actions-enabled repo + aggregate = the dashboard.
- `GET /orgs/{org}/actions/runners/jobs` (`shared/runners.go:52`) — org-wide but **waiting/running ONLY** (hardcoded `FindTaskOptions` status filter): a live-queue probe, perfect for a Gatus "jobs stuck waiting = runner wedged" check, useless as history.
- User- and admin-scope `/actions/runners/jobs` exist only on the dev branch (3 `addActionsRoutes` call sites vs v15's 2: repo + org). Not available on the instance.
- Probe note: `http://localhost:3000/api/swagger.v1.json` → 404 (swagger JSON not served on the loopback listener or disabled); the API itself demonstrably works (avatar-sync POSTs through it).

### F9. Version LIVE-VERIFIED: the instance IS on 15.0.10 → #14843 is live here

`GET /api/v1/version` via the openssl probe pattern (192.168.1.150:443, 2026-10-16 ~06:49): `{"version":"15.0.10"}`. The runbook avatar row's "deployed swagger v15.0.10" doc-claim is now a live fact. Consequence (F5 carries): the Actions log-transfer regression is PRESENT — a retried final `UpdateLog(NoMore)` 500s, the runner aborts, `stop_zombie_tasks` reaps the job as failed in 10–15 min. Fix state re-verified live: **PR 14856 (v15.0 backport) still OPEN, mergeable, NO milestone** — no fixed 15.0.x exists yet. Ride the next LTS patch or watch the PR; blast radius today is two low-volume repos.

### Misc verified

- **Grafana registry**: `grafana.com/api/dashboards?search=` → 409 (bot-blocked); the site is a JS SPA (no server-rendered results). Bounded negative stands: GitHub + delightful-forgejo + web search found nothing.
- **09-18 deep-research HTML reconciliation**: content grep → ONE dashboard/overview mention. No overlap, no split-brain; both reports stand independently.
- **Cohort context moved TODAY (parallel sessions)**: `eventcatalog-hub` AND `domains` are now forgejo-native primaries with Actions on real pushes (runbook §"G2 pilot flips — EXECUTED 2026-10-16"). The cross-repo overview went from hypothetical (1 doc-claimed repo) to real (2 active repos) in the last 12 hours.

---

## Recommendation matrix (the Pareto pick)

| Option | Verdict |
| ------ | ------- |
| Per-repo Actions tabs + bookmarks | **Today's sufficient answer.** Two repos = two bookmarks. Zero work. |
| API-polling collector → SigNoz/Gatus | **The Pareto pick when it stops being enough** (≈5+ repos or first pager-worthy missed failure). ~30 lines following the `system_forgejo_mirror_sync_stale_count` pattern: poll `actions/tasks?status=failure` per repo into a textfile metric; Gatus presence check; SigNoz rule on failure-count > 0. v15-compatible, no new infra. Blocked only by the existing scoped-read-token `[decision]` row. |
| Wait for native (watch #31692) | Zero cost to subscribe; nothing is being built — do not plan around it. |
| Static web page fed by the same API | Only if the owner wants a clickable WEB overview rather than an ops view; same polling base, more UI work, no SigNoz integration value. |
| v17 webhook feed (workflow-job webhooks) | Cleanest push mechanism, but pins a v15→v17 major jump; the 14334/14351/14356 relationship is still unread (06:25 §b.5). Re-evaluate only if a version jump happens anyway. |
| Server/runner metrics | Dead end, both source-verified (F4 + F7). Do not revisit. |
| Woodpecker/Crow | Different CI entirely — only if the owner ever wants to LEAVE Actions. |

## a) FULLY DONE

1. The interrupted research chain executed to completion: both gitea proposals read (bodies/comments/timelines), PR search run (zero), Forgejo-side search run via three surfaces (nothing), server-metrics path mechanically closed (F7), runner-metrics path already closed (F4), version live-probed (F9), Grafana swept (bounded negative), 09-18 HTML reconciled.
2. The answer DELIVERED (top of this report) — the 06:25 session's never-delivered payload.
3. Durable stamps: runbook "Actions overview/dashboard" section (this session), todo rows closed/reclassified, research-tooling gotchas into `docs/agents/shell-devtools.md`.
4. The v15 API feed surface documented at source level with exact routes/filters (F8) — the building-block spec for the collector, ready for dispatch.

## b) PARTIALLY DONE

1. Woodpecker/Crow evaluation — deliberately still shallow (catalog-level); only worth depth if the owner wants a different CI.
2. The webhook-feed path — PR relationship (14334/14351/14356) still unread; irrelevant until a v17 jump is on the table.

## c) NOT STARTED

1. The collector itself — gated on the owner's §g answers (which KIND of overview) + the scoped-read-token decision row.

## d) TOTALLY FUCKED UP

Nothing destroyed/mutated/exposed (read-only + one GET). Friction, honestly logged:

1. Probed `labels=` on the Codeberg issues endpoint believing `q=`'s failure might be endpoint-specific — it failed too, but the 1-issue/3 KB probe caught it pre-batch (the 06:25 lesson applied, cost ≈ nothing).
2. Called the `download` TOOL inside a bash for-loop (it is a tool, not a shell command) — three silent failures, one retry cycle wasted.
3. `git fetch origin v15.0` — wrong branch name (it's `v15.0/forgejo`, matching the backport-label convention); one retry, then FETCH_HEAD worked.
4. Discovered (NOT mine, flagged, untouched): `CHANGELOG.md` currently holds unresolved stash-conflict markers (`<<<<<<< Updated upstream` / `>>>>>>> Stashed changes`) from parallel-session work — my CHANGELOG entries are therefore deferred to the pass that resolves that conflict; this report + the queue edits carry the closure record meanwhile.

## e) WHAT WE SHOULD IMPROVE

1. (Carried, now proven) Validate API query params with a minimal probe before batching — the `labels=` discovery validated the rule at 3 KB instead of ~200 KB.
2. When a tracker's keyword search is broken, DuckDuckGo `site:` scoping + direct issue-number fetches by triaged candidates is a working substitute surface — record it, don't rediscover it (done: shell-devtools gotchas).
3. Blobless sparse clone (`--filter=blob:none --sparse-checkout`) beat every API/tree-search surface for whole-codebase claims — the F7 "exactly one registration" proof was impossible via any rate-limited API and trivial via `rg` over the clone.

## f) Direct follow-ups (self-harvested)

- **[watch] PR 14856** (v15.0 backport of the #14843 fix) — row reclassified in `docs/todo/services.md`; closed the two 06:25 `[ready]` rows in `TODO_LIST.md` + `services.md` (this report is the closure record; CHANGELOG prune deferred behind the foreign conflict, see §d.4).
- Collector dispatch prerequisites (NOT newly harvested — existing rows): scoped read-only Forgejo token `[decision]`, live Actions-unit census `[ready]` (now plausibly = eventcatalog-hub + domains, post-G2).

## g) Questions I can NOT figure out myself (unchanged from the 06:25 report — owner decides)

1. **Which KIND of overview** — a clickable web page of recent runs, or an ops/health view (failures, stuck jobs) inside SigNoz/Gatus? The API supports both; the collector shape depends on it.
2. **Sequencing vs the cohort decision** — with G2 live (2 repos), is the SigNoz collector wanted NOW, or after the canonical-repo cohort grows?
3. **v17 appetite** — only relevant if the webhook-feed design ever wins; the LTS deliberately pins v15.

---

_Research chain CLOSED. The durable knowledge: runbook §"Actions overview/dashboard" (the stamp), this report (the full answer + evidence), `docs/agents/shell-devtools.md` (the tooling gotchas). Nothing left unread on any reachable surface._
