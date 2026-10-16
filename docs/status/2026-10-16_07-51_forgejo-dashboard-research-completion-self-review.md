# Status Report — Forgejo Actions Dashboard Research COMPLETION + Self-Review

_2026-10-16 07:51 CEST · session type: research completion (read-only) + live probes + durable doc stamps · third and final session of the dashboard-research arc (06:25 interrupted → 07:05 completion report → this self-review) · zero config changes, zero deploys, prod touched only by read-only GETs (version, swagger, 2 API endpoints)_

**Scope:** the owner's demand to finish the interrupted research ("keep going until done"), then a full a–g self-review of THIS session. Per the status-report skill the canonical format is HTML; the owner's prompt explicitly demands an `.md` at `docs/status/` — honored, override flagged once here.

**The session in one paragraph:** recreated state from the 06:25 canonical report → read both gitea proposals in full (no PRs, no maintainer work) → searched implementing PRs (zero anywhere) → closed the Forgejo-side search on 3 fallback surfaces (nothing tracked) → mechanically killed the server-`/metrics` hope (blobless sparse clone: exactly ONE prometheus registration codebase-wide, zero Actions counters) → verified the v15.0 API feed surface at source (the DIY-collector building block) → LIVE-probed the instance version (**15.0.10**, settling the F5 doc-claim chain) and the two recommended endpoints (route live, auth required) → delivered the ANSWER in chat (native: no; unmerged PR: no; third-party: no; DIY: ~30 lines) → stamped runbook + closed queue rows in lockstep → harvested 2 new `[ready]` rows → trashed session scratch.

---

## a) FULLY DONE

1. **State recreation, daemon-safe**: 06:25 canonical report read in full; repo state verified (HEAD had moved `c3cdf7a5`→`0ac481ce`; foreign dirty files identified and never touched); both harvested `[ready]` rows confirmed still present before executing them.
2. **gitea#31692 + #33162 read in full** (bodies, comments, `gh api …/timeline` cross-references): both OPEN proposals, no maintainer engagement, **no linked PR in either timeline** (they cross-reference only each other + #23725, the equally-stalled "Actions failure email notifications" ask). The owner's literal "an unmerged PR?" sub-question: answered with evidence, not folklore.
3. **PR search, two methods**: `gh search prs "actions dashboard"` on go-gitea/gitea → zero; timelines → zero. **No implementing PR exists.**
4. **Forgejo-side feature-request search closed on 3 surfaces**: (a) Codeberg API `labels=` filter probed → **silently ignored** (3 KB `limit=1` probe caught it pre-batch — the 06:25 lesson applied); (b) DuckDuckGo `site:codeberg.org` scoping → candidate triage; (c) direct issue-number fetches of the triaged candidates (#5343, #7483, #4500) → all closed UI-dashboard **bugs**, none Actions-related. Verdict: no Forgejo-tracked feature request found anywhere.
5. **F7 — server `/metrics` hope mechanically killed**: blobless sparse clone of forgejo (`--filter=blob:none` + `*.go` sparse-checkout, 2929 files) → `rg` proof that **exactly ONE** prometheus registration exists in the entire codebase (`routers/web/web.go:405` → `metrics.NewCollector()`), whose full Desc enumeration contains **zero Actions counters**; `/metrics` = bare `promhttp` + optional bearer. Combined with F4 (runner): the metrics path is dead at BOTH components. The 06:25 report's "most promising remaining path" is closed.
6. **F8 — the v15.0.10 API feed surface verified at source** on the `v15.0/forgejo` release branch: repo-scoped `GET /repos/{o}/{r}/actions/tasks` with `page`/`limit`/`status=` (enum: unknown/waiting/running/success/failure/cancelled/skipped/blocked) = the history feed; org-scoped `/actions/runners/jobs` = **waiting/running ONLY** (live-queue probe, not history); user/admin jobs search = dev-branch-only (2 `addActionsRoutes` call sites on v15 vs 3 on dev).
7. **F9 — version LIVE-probed**: `GET /api/v1/version` (openssl pattern) → `{"version":"15.0.10"}`. The runbook's "deployed swagger v15.0.10" doc-claim is now a live fact; the **#14843 Actions log-transfer regression is present on this instance**. PR 14856 (v15.0 backport) re-checked live: still OPEN, mergeable, NO milestone — no fixed 15.0.x exists.
8. **Endpoints live-probed (self-correction, see §e.2)**: unauthenticated `…/actions/tasks?status=failure` → 404-mask (forgejo's private-repo no-leak behavior — **route live, scoped token REQUIRED**, confirming the collector prerequisite); org route live (`GetOrgByName` error — `lars` is a user, not an org, so org-scope is moot single-user); swagger UI 200 but `/api/swagger.v1.json` 404s on both loopback and vhost (cosmetic, recorded).
9. **Grafana registry bounded negative**: API endpoint bot-blocked (409), site is a JS SPA — recorded as unsearchable-from-CLI, not as "nothing exists".
10. **The ANSWER delivered** (chat + `docs/status/2026-10-16_07-05_forgejo-actions-dashboard-research-complete.md`): native NO / unmerged-PR NO / third-party NO / DIY-collector YES with a recommendation matrix and a clear Pareto pick. The 06:25 session's never-delivered payload is delivered.
11. **Durable capture, all in lockstep**: runbook stamp `forgejo.md` §"Actions overview/dashboard" (§f item 35 of the 06:25 report, satisfied); two 06:25 `[ready]` rows closed in BOTH surfaces; the F5 residue reclassified as a single `[watch]` row (14856); research-tooling gotchas into `docs/agents/shell-devtools.md` (Codeberg `q=`+`labels=` broken, gh-first precedence, blobless-clone technique, grafana bot-block, `v15.0/forgejo` branch naming).
12. **Mid-edit races handled correctly**: TODO_LIST edit failed twice on foreign modification (parallel session live) → re-read via view → edit landed; daemon sweep `d1550ace` verified content-exact (my 2 files only, no foreign absorption).
13. **Guards green**: `scripts/check-todo-system.sh` → "TODO queue/library structure clean" (the 121 UNHARVESTED warnings are the known pre-existing backlog, not this session's).
14. **Scratch hygiene**: all `/tmp` session artifacts (clone + 13 fetch files) trashed and verified gone.

## b) PARTIALLY DONE

1. **The collector exists only as a spec** — routes, filters, and the house pattern are pinned (runbook + 07:05 report), but no code, no metric name, no Gatus/SigNoz rule. Deliberately: gated on the owner's §g1/§g2 + the scoped-token `[decision]` row.
2. **The webhook-feed path is still a skim** — v17.0.0 release notes name 14334/14351/14356 but their relationship (feed vs deprecate) is unread. Deliberately: it only matters if a v15→v17 jump ever happens (§g3).
3. **Woodpecker/Crow evaluation remains catalog-level** — deliberately; it answers "different CI", not "Actions dashboard".
4. **The direct Codeberg keyword search never ran** — structurally unreachable from the CLI all session (`q=` broken, `labels=` ignored, UI 429); `agentic_fetch` reset only at 12:16, after this session ended. Harvested as a `[ready]` row.
5. **The Grafana registry sweep is bounded, not complete** — needs a browser or a post-12:16 agentic pass; the 3-surface negative (delightful-forgejo + GitHub + web search) stands regardless.
6. **CHANGELOG entries for the closed rows are deferred** — `CHANGELOG.md` currently holds unresolved stash-conflict markers from a parallel session (§d.4); my entries land with whoever resolves that conflict.

## c) NOT STARTED

1. **The live Actions-unit census** — pre-existing `[ready]` row, deliberately not re-harvested; post-G2 the expected answer is "eventcatalog-hub + domains" but nothing live confirms it.
2. **First real-push Actions run health on the G2-flipped repos** — harvested this session as a new `[ready]` row (the runbook documents only a rehearsal `workflow_dispatch` 204; #14843 exposure on real runs is unverified).
3. **Subscribing to gitea#31692/#33162** — owner GitHub-account action; not machine-actionable.
4. **Swagger JSON 404 root-cause** — observed and recorded (UI 200 / JSON 404 both surfaces); chasing WHERE the UI loads its spec from has zero functional payoff, so stopped at observation.

## d) TOTALLY FUCKED UP

Nothing destroyed, mutated, deployed, or exposed (read-only session; the only prod writes were zero — all four HTTP touches were GETs). The damage ledger:

1. **Called the `download` TOOL inside a bash for-loop** (`for n in …; do download …`) — three silent "command not found" failures and one wasted round-trip before the fix. Tool/shell boundary confusion in a session whose whole subject was tooling gotchas; the meta-irony is noted.
2. **`git fetch origin v15.0`** — guessed the release-branch name and lost a fetch round-trip. The correct name (`v15.0/forgejo`) was sitting in the backport-label list I had fetched MINUTES earlier. Evidence in hand, guess anyway.
3. **Probed Codeberg's `labels=` filter on faith** that `q=`-brokenness was endpoint-specific — it was ignored too. The `limit=1` probe caught it for 3 KB (the 06:25 lesson APPLIED — cost ≈ nothing), but the instinct to try an unverified param is the same class as 06:25's §d.1; only the blast radius differed.
4. **Discovered foreign in-flight breakage and correctly did not touch it**: `CHANGELOG.md` holds unresolved stash-conflict markers (`<<<<<<< Updated upstream` / `>>>>>>> Stashed changes`) from parallel-session work. Flagged in the 07:05 report §d.4 and left alone — but my queue-prune CHANGELOG entries are hostage to it (§b.6).
5. **Two edit-tool race round-trips wasted on TODO_LIST.md** — I refreshed my read-state via bash `grep` (which does not count) instead of the view tool (which does) during an ACTIVE parallel session. The correct first move was known; I paid two rejections to remember it.
6. **Left ~40 MB of session scratch in `/tmp` un-noted** until §a.14 — trivial, but the note came only at self-review time, not at action time.

## e) WHAT WE SHOULD IMPROVE

1. **Emit partial answers WHILE the research runs — second offense.** The 06:25 report's §e.1 named this exact failure ("surface partial answers, checkpoint emits"); this session again ran ~25 tool calls before the owner saw a single finding, and again got interrupted first. Two sessions in a row is a pattern, not an accident: deep-research sessions need a one-line emit after each completed research step.
2. **Live-probe what you recommend, at decision time.** My first pass certified the endpoints "source-verified" and moved on; the live probes (§a.8) happened only because the a–g demand forced a re-read of my own claims. "Source-verified" and "live-verified" are different grades in this repo's own vocabulary — I used the weaker grade where the stronger cost 10 seconds.
3. **Read conventions from evidence already in hand before guessing** — the branch-name miss (§d.2) was avoidable by re-reading a list I already possessed.
4. **Tool-boundary hygiene**: agent CLIs are tools, not shell commands (§d.1). Multi-fetch loops should be parallel tool calls in one message, which is also faster.
5. **Run cheap independent surfaces in the same batch as the primary** — DDG ran only after the Codeberg API probes failed; it could have been parallel from the start (it needs no rate-limit budget on Codeberg).
6. **A repeated §g is a smell**: the 06:25 report asked 3 owner questions; they were never answered; this report must ask them crisply in CHAT (not just in a file) — doing exactly that in the closing message.

## f) Things to Get Done Next (20 items — brainstorm, not commitments; NO padding to 50: the repo's remaining open work lives in the domain libraries and the owner said DO NOT RESEARCH OTHER STUFF — inventing filler here would be worse than a shorter list)

**Direct follow-ups from THIS session:**

| # | Item | Routing |
| -- | ---- | ------- |
| 1 | Decide §g1: clickable WEB overview vs SigNoz/Gatus ops view — decides the collector's shape | owner question, blocks #4 |
| 2 | Decide §g2: build now (2 live repos) vs wait for cohort growth | owner question, blocks #4 |
| 3 | Decide §g3: v17 appetite (webhook feeds, fix rides) or hard v15 LTS pin | owner question, gates #10 |
| 4 | Build the actions-failure textfile collector (`actions/tasks?status=failure` per repo → `system_forgejo_actions_failures`-style metric, Gatus presence, SigNoz rule — the `mirror_sync_stale_count` pattern) | gated on #1+#2+#5 |
| 5 | Ratify the scoped read-only Forgejo token (existing `[decision]` row — LIVE-confirmed prerequisite this session: unauthenticated API reads 404-mask) | existing row |
| 6 | Watch PR 14856 / ride the next 15.0.x carrying it (#14843 is live-verified present) | existing `[watch]` row |
| 7 | Live Actions-unit census (all repos incl. `starred`) — pre-existing `[ready]` row, now post-G2 | existing row |
| 8 | Close the direct Codeberg `code/actions`-label sweep in an agentic_fetch-capable window (post-12:16) — the definitive close of the one bounded search gap | **harvested `[ready]` this session** |
| 9 | Verify first REAL push-triggered Actions runs on eventcatalog-hub + domains (rehearsal 204 ≠ real-run health; #14843 exposure) | **harvested `[ready]` this session** |
| 10 | Read 14334/14351/14356 (workflow-job webhook PR relationship) | only if #3 says v17 |
| 11 | Subscribe to gitea#31692/#33162 (the only upstream vehicles for a native dashboard) | blocked:user |
| 12 | Absorb this arc's two closed-row entries into CHANGELOG when the foreign stash-conflict resolves | blocked by foreign conflict |
| 13 | Grafana registry sweep (forgejo/gitea Actions dashboards) via browser or agentic pass — completes the bounded negative | nice-to-have |
| 14 | Woodpecker/Crow evaluation — only if the owner ever wants to LEAVE Actions | roadmap, deliberately shallow |
| 15 | Gatus "Actions jobs stuck waiting" check via the org jobs endpoint — early warning for the runner-wedge class (note: `lars` is a user; org-scope needs a real org or the user-scope endpoint of a post-v15 jump) | design candidate, gated #1 |
| 16 | If the collector lands: decide SigNoz retention/aggregation for the failure-count series | follow-on of #4 |
| 17 | If the collector lands: wire it into pre/post-deploy checks (metric presence = phantom-metric discipline) | follow-on of #4 |
| 18 | Swagger JSON 404: locate where the UI actually loads its spec (cosmetic; zero urgency) | backlog-filler, no urgency |
| 19 | Fold "next 15.0.x release carrying 14856" into the version-watch row when it ships | watch upkeep |
| 20 | Re-check gitea#31692 for movement on any future research touchpoint (nobody is building it — quiet watch) | watch |

**Deliberately NOT harvested (reasons recorded per the self-harvest rule):** #1–#3 (owner questions, not tasks), #5–#7 (pre-existing rows — never re-harvest), #11 (blocked:user), #12 (blocked by foreign conflict), #13–#20 (no queue-worthy action exists yet / roadmap-grade / watch-grade). Items #8 and #9 ARE harvested (TODO_LIST one-liners + `docs/todo/services.md` full rows, in lockstep, at authoring time).

## g) Questions I can NOT figure out myself (asked in chat, not just here)

1. **Which KIND of overview do you actually want?** A clickable web PAGE listing recent runs across your Actions repos, or an OPS view (failure counts, stuck jobs, runner saturation) living in the SigNoz/Gatus stack you already have? The API supports both; the collector's shape (static page feed vs textfile metric) follows entirely from this.
2. **Build now or when the cohort grows?** Two repos run Actions on real pushes as of this morning (G2). Is the SigNoz collector wanted NOW, or is two-bookmarks-and-wait the right call until the canonical-repo cohort decision lands? (If now: the scoped-read-token ratification rides along.)
3. **Is a v15→v17 LTS jump ever on the table?** The cleanest feed mechanism (workflow-job webhooks) and the #14843 fix ride are version-gated; the instance deliberately pins v15 LTS. Must all dashboard work stay v15-compatible, or would you accept planning the jump for the right payoff?

---

_Arc closed: 06:25 interrupted → 07:05 completion (the answer) → 07:51 this self-review (the honest ledger). The durable knowledge lives in three places: runbook §"Actions overview/dashboard" (facts), the 07:05 report (evidence), this report (process lessons). No commit made — harness rule; the daemon picks the files up._

_THEN WAIT FOR INSTRUCTIONS._
