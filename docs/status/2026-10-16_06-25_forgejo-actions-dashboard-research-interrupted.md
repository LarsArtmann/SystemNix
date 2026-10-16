# Status Report — Forgejo Actions Dashboard Research (INTERRUPTED MID-RESEARCH)

_2026-10-16 06:25 CEST · session type: research/exploration (read-only: repo reads + primary-source web fetches + mechanical source greps) · zero config changes, zero deploys, zero prod probes_

**Session scope (complete list of what happened):**

1. Owner question: *"Is there a way to get some kind of proper Overview/Dashboard for all my Forgejo Actions? Something native? An unmerged PR? Another open source tool or extension?"* — with an explicit process demand: READ → UNDERSTAND → RESEARCH → REFLECT, break into steps, execute + verify one at a time, keep going until done.
2. Local-context pass: `docs/services/forgejo.md` (runbook) + `docs/services/forgejo-upstream-issues.md` read in full; `forgejo.nix` / `_forgejo-scripts.nix` grepped for the Actions/runner config; repo-wide greps for prior dashboard research.
3. Prior-art pass: `docs/status/2026-10-12_15-45_forgejo-actions-everywhere-pro-contra.md` read in full (the Actions cohort decision context) + `docs/status/2026-09-18_07-47_forgejo-research-session-status.md` read in full (the 09-18 deep-research session's known gaps). The 09-18 HTML report itself was only heading-scanned, NOT read in full (§e.5).
4. Primary-source research (all fetches 2026-10-16): forgejo.org docs ×4 (user/actions reference, user/actions overview, admin/actions, admin/actions/configuration), delightful-forgejo README (full catalog), `routers/web/web.go` from the forgejo branch (downloaded + mechanically grepped), forgejo-runner `go.mod` + `config.example.yaml` (downloaded + grepped), plus 6 `gh` searches (GitHub repos/issues) and 3 Codeberg API fetches (2 misfired, §d.1; 1 batch 429'd, §e.3).
5. **INTERRUPTED by this status demand after ~20 tool calls — the synthesized ANSWER was never delivered to the owner.** The verified fragments are persisted in §"Findings so far" below and harvested into `TODO_LIST.md` + `docs/todo/services.md` at this report's authoring time (bottom of file).

No file in `modules/`, `systems/`, `platforms/`, or `flake/` was touched. Todo surfaces got exactly two new `[ready]` rows each (self-harvest, recorded at the end).

---

## Findings so far (the durable value — chat is not durable, so this section IS the payload)

### F1. Native: there is NO instance-wide Actions dashboard (verified at source level)

Mechanically verified from `routers/web/web.go` (codeberg.org/forgejo/forgejo, `forgejo` branch, fetched 2026-10-16):

- **Repo scope is the only runs surface**: `/{owner}/{repo}/actions` → `actions.List` (the runs list), plus `/runs/{run}/jobs/{job}/attempt/{attempt}`, `/logs`, `/cancel`, `/rerun`, `/delete`, `/artifacts`, `/prioritize`, `/deprioritize`, `/workflows/{name}/badge.svg`.
- **User / org / repo settings** each mount `/settings/actions` = `RedirectToDefaultSetting` + **Runners** management (`shared_actions.RunnersList/Create/Details/Edit/Delete/reset_registration_token`) + Secrets + Variables. Runner MANAGEMENT exists at four scopes; run VISIBILITY does not.
- **Admin `/admin/actions`** = `RedirectToDefaultSetting` + `addSettingsRunnersRoutes()` + `addSettingsVariablesRoutes()` — a Runners + Variables manager. **No instance-wide runs list, no global task view.**
- Docs corroborate (user guide + admin guide, fetched same day): per-repo Actions tab, repo Settings → Actions → Runners, and `admin/monitor/cron` for the log/artifact cleanup task. Nothing else.

**Verdict: "native" = per-repo Actions tabs only. An all-repos overview does not exist upstream as of the current forgejo branch (post-v17.0).**

### F2. Unmerged PRs / feature requests: leads found, not yet read

Via `gh search issues` on go-gitea/gitea (titles + states verified through search results; bodies/comments/linked PRs NOT yet read):

- **go-gitea/gitea#31692 — "Actions dashboard for all the actions in the repos you can access"** — OPEN, `type/proposal`, `topic/gitea-actions`. This is the exact ask.
- **go-gitea/gitea#33162 — "Organization Actions overview"** — OPEN, `type/proposal`, `topic/gitea-actions`.
- Forgejo-side (Codeberg) equivalents: **unsearched** — the targeted Codeberg fetches 429-rate-limited before the label-filtered search ran (§e.3). Unknown whether Forgejo tracks its own issue for this or only inherits the Gitea upstream ones.
- Open PRs *implementing* such a dashboard: **unsearched** (the owner's literal "unmerged PR?" question is still unanswered).

### F3. Third-party: nothing exists (searched, two independent surfaces)

- **delightful-forgejo** (official community catalog, full README fetched): CI/CD section lists alternative CIs (Woodpecker/Crow, Jenkins, yojo, agola, Buildbot, mvoCI, Concourse); the Forgejo Actions section lists runners, runner-deployment tools, and individual actions. **No dashboard tool.**
- **GitHub repo searches**: `forgejo actions` (20 results — runners, actions, images, one C++ runner experiment), `forgejo dashboard` (2 toy repos), `gitea actions dashboard` / `actions dashboard gitea` (zero). Nothing real.

### F4. The metrics path is a dead end at the RUNNER, unexplored at the SERVER

- **forgejo-runner exposes NO Prometheus endpoint** (verified): `go.mod` has zero prometheus dependencies (only indirect otel), and `config.example.yaml` has exactly six sections (`log`, `runner`, `cache`, `container`, `host`, `server` — the last being Forgejo-connection config), no `metrics`.
- **Forgejo SERVER `/metrics`** (`[metrics] ENABLED` in app.ini): **not yet checked** for actions counters. This is the most promising remaining "use what we already have" path — the box already runs SigNoz + Gatus + textfile collectors, so a server-side metrics feed would need zero new infrastructure.

### F5. Incidental find with real operational value: the 15.0.10 Actions-log regression

From the v17.0.0 release-notes dump + issue #14843 (both encountered during the misfiltered Codeberg fetch, §d.1 — the payload was unasked-for but the content is primary-source):

- **#14843** (reported 2026-10-14, closed 2026-10-15): affects **v15.0.10 exactly** (15.0.9 and 16.0.6 unaffected per the report). A retried final `UpdateLog(NoMore)` 500s with `transfer logs: dbfs open …: file does not exist`, the runner's retry aborts before `UpdateTask`, and `stop_zombie_tasks` reaps the job as a failure 10–15 min later; `needs:`-jobs stay blocked until `cancel_abandoned_jobs` (24h).
- Fixes: PR 14847 (merged, v18 milestone), 14855 (merged → v17.0.1), **14856 (v15.0 LTS backport — still OPEN at fetch time)**, 14857 (v17 duplicate, closed-unmerged).
- **Why it matters here**: the runbook's 2026-10-16 avatar-sync row cites the *"deployed swagger v15.0.10"* — a doc-claim, never live-probed. If the instance really is on 15.0.10, it carries this regression. Blast radius today is small (one Actions-enabled repo), but it must be checked before any Actions-heavy push.

---

## a) FULLY DONE

1. **The local-context read** — forgejo runbook + upstream-issues doc in full; `forgejo.nix`/`_forgejo-scripts.nix` greps for the runner config (label `native`, capacity 2, `MemoryMax 16G`, `actions.ENABLED = true`, `DEFAULT_ACTIONS_URL = "github"`); the 2026-10-12 pro/contra report in full (cohort decision + the standing census gap).
2. **F1 (no native dashboard) verified at source level**, not from blog folklore — the router file was downloaded and grepped mechanically; every `/actions` route group was read in context (settings-scopes at ~856/1022/1173/1361, repo runs at ~1655). This is the strongest claim of the session and it is source-backed.
3. **F3 (no third-party tool) verified across two independent surfaces** — the official community catalog AND GitHub repo search. Negative results, honestly bounded: GitHub + delightful-forgejo only; Codeberg-adjacent and Grafana registries unsearched (§c).
4. **F4-runner half (no runner metrics)** verified mechanically from the runner's own `go.mod` + config example.
5. **The two gitea feature-request leads located** (#31692, #33162) — the exact shape of the owner's ask exists upstream as open proposals; located and state-verified, queued for reading.
6. **F5 (15.0.10 regression) surfaced and stamped** with affected/unaffected versions and per-branch fix-PR status — a genuinely useful operational find that no one was looking for.
7. **Environment-fault reporting discipline held**: the `agentic_fetch` usage-limit failure at session start was NOT silently switched around (the 09-18 session's documented failure mode) — pivot to raw `fetch` recorded here and in the tool stream.
8. **Todo-surface self-harvest landed at authoring time** — two `[ready]` rows each in `TODO_LIST.md` + `docs/todo/services.md`, one-liners and library entries in lockstep (no drift), Source pointers to this report.

## b) PARTIALLY DONE

1. **The owner's actual question is ~70% answered and 0% delivered.** Native: answered (no). Third-party: answered within searched bounds (nothing). Unmerged PR: located issue-level proposals but zero PRs found/read. Synthesis + recommendation: never written. The session was interrupted before any answer text reached the owner — everything above lived only in the tool stream until this report.
2. **Prior-art overlap unassessed.** The 09-18 deep-research HTML (86.5 KB) was heading-scanned only; it covers "Actions admin" topics and may already document parts of the UI landscape — risk of duplicated conclusions or, worse, a split-brain between this report and that one. Only its companion status report was read in full.
3. **The local Actions-usage picture is still doc-claimed, not live.** Which repos have Actions units enabled (believed: only `eventcatalog-hub`), run volume, runner health — all inherited from the pro/contra report's own §b.1 caveat. This session added zero live facts (by scope: read-only research), so ANY dashboard recommendation is calibrated against an unverified census.
4. **F5's local applicability is a doc-claim chain**: "instance on 15.0.10" rests on one runbook sentence (avatar row, today); the version has never been probed via `GET /api/v1/version`. The harvested row makes the probe the first step.
5. **The webhook feed path is half-understood.** v17.0.0 notes show "webhooks for workflow jobs" (14334) + "fine-grained event triggers for workflow run webhooks" (14351) AND "deprecate action run webhook events" (14356) — three PRs whose exact relationship was never read. A SigNoz-feed design built on this today would rest on a skim, not a reading.

## c) NOT STARTED

1. Reading #31692 + #33162 bodies/comments (design ideas, maintainer positions, linked PRs, whether anything merged).
2. Searching for OPEN PRs implementing a global Actions dashboard (forgejo/forgejo on Codeberg + go-gitea/gitea) — the owner's literal "unmerged PR?" remains unanswered.
3. The Codeberg-side feature-request search (429'd) — does Forgejo track its own instance-wide-overview request?
4. Forgejo SERVER `/metrics` actions-coverage check (config-cheat-sheet + `modules/metrics/` source) — the "zero new infrastructure" path.
5. Grafana.com dashboard registry sweep (forgejo/gitea actions dashboards) + a Codeberg-side tool search (symmetry with the GitHub sweep).
6. Live instance probes: version (`/api/v1/version`, F5 gate), Actions-unit census (standing `[ready]` row), run history.
7. The synthesis itself: recommendation matrix (per-repo tabs + bookmarks vs API-fed static page vs webhook→SigNoz/Gatus feed vs server-metrics dashboard vs Woodpecker/Crow) with a Pareto pick — never drafted.
8. Woodpecker/Crow evaluation beyond catalog-level facts (the "different CI with a real dashboard" escape hatch — heaviest option, deliberately shallow).
9. Memory updates: nothing this session learned was written into `docs/agents/*` or the runbook except via the harvested todo rows.
10. Any implementation — zero config lines changed anywhere.

## d) TOTALLY FUCKED UP

**Nothing was destroyed, mutated, deployed, or exposed** — read-only session; no prod probes, no config edits, no secrets touched. The damage is confined to wasted effort and one near-miss:

1. **Two Codeberg issues-search fetches misfired and burned ~large chunks of context**: the `q=` keyword param on `/api/v1/repos/issues/search` did NOT filter (both responses returned generic recent issues with full bodies, ~100 KB each). Root cause: I batched two unvalidated API calls instead of testing the param with one `limit=2` probe. Silver lining: the unasked-for v17.0.0 release-notes dump inside those payloads is what surfaced F5.
2. **The Git trees API capped at 1000 entries and the first grep nearly shipped a wrong conclusion**: "no action templates/routes in the tree" was an artifact of truncation (exactly 1000 paths, `templates/`+`routers/` absent). Caught in-pass by counting entries and noticing the missing top dirs, then corrected by fetching `routers/web/web.go` directly. Had the count check been skipped, F1 would have been "verified" against garbage.
3. **Codeberg 429-rate-limited the two UI-search fetches** (batched too aggressively after the API misfires) — the Forgejo-side search never ran. The pivot to `gh`/GitHub worked and found the leads, but the forgejo-native question is still open.
4. **The todo tool was created ~6 research steps late** despite the owner's explicit "break this down into actionable steps" instruction — the first half of the session ran untracked.

## e) WHAT WE SHOULD IMPROVE

1. **Surface partial answers while the research runs.** F1 was solid ~10 tool calls before the interrupt; a two-line progress note ("native = no, source-verified; digging into PRs/tools next") would have given the owner something actionable at every point. Deep-research sessions need checkpoint emits, not a single end-of-task reveal.
2. **Validate API query params with a minimal probe before batch-fetching.** One `limit=2` call would have exposed the dead `q=` param for the cost of kilobytes, not the ~200 KB both misfires consumed.
3. **Respect rate limits structurally, not by retry**: after two heavy Codeberg responses, the right move was a gap or a different surface FIRST — instead the next batch hit 429. GitHub (`gh`) should have been the default for issue search from the start; Codeberg was chosen because forgejo lives there, but go-gitea/gitea proposals cover the shared feature surface.
4. **Run the planning-layer pre-read first**: `rg -il` across `docs/brainstorming/` + `docs/planning/` for "actions dashboard" never ran (Session Discipline). The 09-18 research doc was found only via a later content grep, and never read in full — the cheap sweep that prevents duplicate research was skipped.
5. **Read the local prior art before the web.** The 09-18 HTML almost certainly documents the Actions UI landscape; reading it BEFORE fetching forgejo.org docs would have trimmed 2–3 fetches and avoided the overlap risk now flagged in §b.2.
6. **Negative-existence claims need bounded search scopes stated in the claim** — F3 should always be phrased "nothing on GitHub + delightful-forgejo", never "nothing exists". The report wording above does this; keep it that way when the answer is eventually delivered.
7. **The session never probed the live instance even once.** A single `GET /api/v1/version` (openssl probe, guard-safe) would have converted F5 from a doc-claim chain into a fact and cost nothing. Research sessions still owe the cheap live checks when they are one call away.

## f) Things to Get Done Next (36 items — brainstorm, not commitments; extra-N routing per docs-health HARVEST)

**This session's research chain (items 1–10 harvested THIS session as two rows):**

| # | Item | Landing |
| -- | ---- | ------- |
| 1 | Read go-gitea/gitea#31692 + #33162 (bodies, comments, linked PRs, merge status) — they ARE the owner's ask upstream | `[ready]`, harvested |
| 2 | Search OPEN PRs implementing a global Actions dashboard (Codeberg forgejo + go-gitea/gitea) | `[ready]`, harvested (part of row 1) |
| 3 | Re-run the Codeberg-side feature-request search (429'd), throttled, label `code/actions` | `[ready]`, harvested (part of row 1) |
| 4 | Check Forgejo SERVER `/metrics` (`[metrics]` ENABLED) for actions counters — the zero-new-infra SigNoz/Gatus path | `[ready]`, harvested (part of row 1) |
| 5 | Grafana.com registry sweep + Codeberg-side tool search (complete F3's bounded negative) | harvested (part of row 1) |
| 6 | Live-probe `GET /api/v1/version` → resolve the F5 15.0.10 question | `[ready]`, harvested (row 2) |
| 7 | If on 15.0.10: watch PR 14856 (v15.0 backport, open at fetch) / plan the patch ride | folds into row 2 |
| 8 | Synthesize the recommendation matrix + Pareto pick (tabs+bookmarks vs API-fed page vs webhook/SigNoz feed vs server-metrics vs Woodpecker/Crow) | follows 1–5 |
| 9 | Reconcile with the 09-18 deep-research HTML (annotate it or this report — never fork the knowledge) | harvested (part of row 1) |
| 10 | Read the 14334/14351/14356 webhook-PR relationship before any feed design (v17-pin awareness) | harvested (part of row 1, noted) |

**Adjacent unexplored paths (surfaced this session, not harvested — fold into the chain when dispatched):**

| # | Item | Note |
| -- | ---- | ---- |
| 11 | API-fed overview prototype: one collector hitting `GET /repos/{o}/{r}/actions/runs` for the Actions cohort → textfile metric or tiny static page (repo's collector pattern) | the lightest build-it-yourself path |
| 12 | Scoped read-only Forgejo token (sops) — existing `[decision]` row; ALSO the prerequisite for any API-fed dashboard + agent CI post-mortems | existing row, new consumer |
| 13 | Runner job-lifecycle observability — existing `[ready]` row; a metrics/feed path would subsume it | existing row |
| 14 | Woodpecker/Crow eval (only if the owner wants a real cross-repo pipeline UI more than staying on Actions) | heaviest option |
| 15 | `DEFAULT_ACTIONS_URL=github` supply-chain interplay with any NEW workflows added for dashboard purposes | decision-grade |
| 16 | Cohort decision dependency: dashboard value scales with Actions-enabled repo count — sequence vs the `[decision]` cohort row | existing row |

**Pre-existing rows re-confirmed as live during this session's reads (pointers, deliberately NOT re-harvested):**

| # | Item | Surface |
| -- | ---- | ------- |
| 17 | Live Actions-unit census (all repos incl. `starred`) | TODO_LIST:1249 + services.md |
| 18 | Ratify the canonical-repo Actions cohort (`[decision]`) | services.md |
| 19 | gitea-actions-runner persistent tokenFile (CREDENTIALS boot-failure class) | services.md `[ready]` |
| 20 | Deploy the tokenFile fix + FIRST-BOOT verification (`[blocked:deploy]`) | services.md |
| 21 | `$STATE_DIRECTORY` colon-joined-LIST hardening (paperless.nix ×2, pool-smart-metrics.nix) | services.md `[ready]` |
| 22 | Deploy the discordsync db-heal fix wave + runbook fold | services.md `[blocked:deploy]` |
| 23 | CHANGELOG row for the 2026-10-15 wave2 | services.md `[ready]` |
| 24 | VM tests touched by the manifest removal (eval-green, never RUN) | services.md `[ready]` |
| 25 | Label-semantics eval selftest | services.md `[ready]` |
| 26 | Eval-time forgejo-family `.subvol-migrated` gate assertion | services.md `[ready]` |
| 27 | setup-forgejo.sh loud-fail on empty `FJ_SHA` | services.md `[ready]` |
| 28 | Forgejo + architecture-catalog runbook capture | services.md `[ready]` |
| 29 | Fixture-from-live discipline for setup-forgejo.sh jq shapes | services.md `[ready]` |
| 30 | Delete 4 orphaned all-scope setup PATs (owner-committed) | services.md `[blocked:user]` |
| 31 | Trash the stale `/var/lib/forgejo/data/gitea.db` fossil (owner) | services.md `[blocked:user]` |
| 32 | SigNoz tile for catalog dist freshness `[watch]` + CRM passkey login + `/data/docker` reclaim `[decision]` | services.md cluster |

**Knowledge-capture (new, from this session's tooling friction):**

| # | Item | Note |
| -- | -- | ---- |
| 33 | Record the Codeberg API gotchas in `docs/agents/shell-devtools.md` (or similar): issues-search `q=` does not keyword-filter; Git trees API caps at 1000 entries regardless of `per_page`/`recursive` | both cost real context today |
| 34 | Record the research-tool precedence: `gh search` (GitHub) FIRST for gitea/forgejo feature-surface questions — go-gitea/gitea proposals cover the shared surface and `gh` is authed + unthrottled here | 429 + misfire lesson |
| 35 | Stamp the F1 conclusion durably ("no native instance-wide Actions overview, source-verified 2026-10-16") in the forgejo runbook once the research completes — so no future session re-researches it | pending chain completion |
| 36 | §f-harvest backlog triage (104+ unharvested reports, cross-session, pre-existing) | pipeline.md |

## g) Questions I Can NOT Figure Out Myself

1. **What KIND of overview do you actually want?** A GitHub-style *web page* listing recent runs across your Actions-enabled repos (click through to logs), or an *ops/health* view (failure rates, durations, runner saturation) living in the existing SigNoz/Gatus stack? Both are legitimately "a dashboard"; the answer decides API-fed-page vs metrics-feed, and I cannot infer it from the repo.
2. **Does the dashboard precede or follow the cohort decision?** Today exactly one repo (`eventcatalog-hub`, doc-claimed) runs Actions — a perfect cross-repo overview would show one row. Is the intent "I'm about to enable Actions on the canonical cohort and want the overview ready", or "make the one repo's CI visible first"? This sequences item 16 against the whole chain.
3. **Version appetite: is a v15→v17 jump on the table to unlock the feed mechanisms?** The webhook-for-jobs path (the cleanest push-feed into SigNoz/Gatus) is v17-only, while the instance rides the v15 LTS (deliberately, per the 09-18 research). Would you accept planning an LTS-major jump for this, or must any dashboard work stay v15-compatible (polling API / server-metrics only)?

---

_Self-harvest at authoring time: §f items 1–10 consolidated into TWO `[ready]` rows (research chain + F5 version check), landed in `TODO_LIST.md` + `docs/todo/services.md` in the same pass as this report. Items 11–16 deliberately not harvested (fold into the chain when dispatched); items 17–32 are pre-existing rows with pointers (never re-harvest); items 33–36 queue at next dispatch. The owner interrupted the research mid-flight with "THEN WAIT FOR INSTRUCTIONS" — no further research executed after this line._
