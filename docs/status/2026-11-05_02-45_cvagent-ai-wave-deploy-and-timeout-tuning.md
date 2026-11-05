# Status report — cvagent AI-enablement wave: deploy landed, AI proven live, timeout mis-budget caught

**When:** 2026-11-05 02:36 CET
**Session:** continuation of `2026-11-04_20-46_cvagent-dead-unit-path-fix-and-storm-gated-deploy.md` after the owner answered its §g questions (AI via zai/GLM-5.3; repo list from `meta list --sort-by importance`; autonomous poll-and-deploy). This report covers 20:46 → 02:36: the upstream + SystemNix AI wave, three deploy-gate rounds, the discovery that a PARALLEL session deployed first, the first production AI cycle, and the timeout mis-budget it exposed.
**Predecessor:** docs/status/2026-11-04_20-46_cvagent-dead-unit-path-fix-and-storm-gated-deploy.md (read its scope line first — the fix proven there is the foundation everything below ships).

---

## Scope line — what this report VERIFIES vs does NOT verify

**Verified with fresh commands/artifacts:**

| Claim | Evidence |
| --- | --- |
| Upstream `ai.baseurl` + `sk-` drop exists and is pushed | Code-To-CV-Agent `2b735e5` on origin/master (`git push` output `adfa8a1..2b735e5`); `go build`/`vet`/`go test` green; gofmt clean |
| Upstream 300s timeout exists and is pushed | `1484234` (`2b735e5..1484234`), tests green — after probe-1 PROVED 90s dies vs z.ai (`context deadline exceeded`, 200-commit prompt) |
| FOD builds green on BOTH revs | `nix build git+ssh…#cvagent` → `cvagent-2b735e5…` and `cvagent-1484234…` (prepared-source + go-modules + package; vendorHash unchanged by the go-atomic-write promotion) |
| SystemNix lock on the timeout rev | flake.lock:1019 `"rev": "148423437b003f993589863611b46a6bb38806ac"` |
| Follow-audit hit fixed | `cvagent.inputs.go-nix-helpers.inputs.treefmt-nix.follows = "treefmt-nix"` added; re-lock removed the deep-copy nixpkgs node; toplevel evals green (EVAL-OK ×3) |
| sops wiring evals green | `cvagent_ai_api_key = "glm_api_key"` keyed block (guarded `svcEnabled "cvagent"`, owner primaryUser) + `cvagent-env` template (OPENAI_API_KEY) — both in sops.nix, eval green |
| LIVE system carries the whole wave | gen 982 (02:07, ANCHORED: `/run/current-system` == `system-982-link` == `rc87rnbc…`); live unit has `EnvironmentFile=/run/secrets/rendered/cvagent-env` + ExecStart script contains `git-2.55.0` |
| AI extraction works against z.ai IN PRODUCTION | battery 02:14–02:33: `gogenfilter: 926 commits, 28 facts via ai` (extractor `"ai"` in the production db); probe-2 earlier: `21 facts via ai` on the probe db |
| The rule-based fallback still guards | probe-1: AI timeout at 90s → automatic fallback, 18 rule-based facts — the unit cannot hard-fail on AI errors alone |
| First production cycle was KILLED by my own budget | journal 02:33:54: `start operation timed out` at exactly `20min` (my wrong assumption), repo ~13/24, OnFailure paged; completed repos' facts persisted |
| 90min fix in tree + eval green | cvagent.nix `TimeoutStartSec = "90min"` with the live numbers in the comment; EVAL-OK post-edit |
| Concurrent session deployed first | deploy lock held by `crush -y` with cwd `/home/lars/projects/quotaboard` (/proc cmdline); its switches: gen 980 (23:22), 981 (01:35), 982 (02:07) |
| 90min fix deploy chain running | passive PSI watch → deploy → battery script live (`/home/lars/.cache/cvagent/deploy-fix.sh`, background job) |

**NOT verified here (and why):**

- **`done: scanned=24 failed=0` has NEVER printed** — the 90min-budget run is pending (chain in flight). Every number above is per-repo or partial-run.
- **The mesh artifacts from AI facts are not yet in the CV checkout** — the killed cycle never reached mesh; the next full cycle produces them.
- **glm-5.3-flash fact QUALITY** — count ≠ quality; no human has reviewed what the model extracted (§g Q2).
- **system-health oneshot metric flip** — still never probed (carried §f row).
- **Which session produced gen 981 vs 982** — 980/981/982 all landed tonight; I attributed 982's carrier to the quotaboard session by lock PID at 01:07, but the earlier two switches' authors were not forensically separated (multiple parallel sessions active all night).
- **The other session's go-atomic-write adoption** — their T01 work rode the same push; I verified only that MY feature's files were sane in the mixed tree, not their implementation.

---

## a) FULLY DONE

| Work | Evidence | Scope |
| --- | --- | --- |
| Upstream AI endpoint support: `ai.baseurl` config + `option.WithBaseURL` + `CVAGENT_AI_BASEURL` env mapping tests | rev `2b735e5` pushed; unit tests green (2 new Its) | Code-To-CV-Agent |
| Upstream `sk-` prefix rejection dropped (OpenAI-compatible providers validate now) | same rev; test flipped to acceptance; length check retained | Code-To-CV-Agent |
| Upstream per-call timeout 90s→300s | rev `1484234` pushed; comment carries the live probe + fleet precedent | Code-To-CV-Agent |
| SystemNix lock + FOD on the timeout rev | flake.lock @ `1484234`; probe builds green ×2 | flake.lock |
| Follow-audit compliance on the new nested dep | follows line added; audit clean; eval green | flake.nix |
| sops: cvagent AI key with NO owner interaction | `cvagent_ai_api_key` (hermes.yaml `glm_api_key`, second-consumer precedent) + `cvagent-env` template; guard `svcEnabled "cvagent"` | sops.nix |
| Module AI wiring | `aiEnable`/`aiModel`/`aiBaseUrl` options; `--config` + `--ai` in the scan loop; Nix-rendered non-secret config file | cvagent.nix |
| Repo expansion per owner directive | 24 repos from `meta list --sort-by importance` (importance ≥80, real checkouts; templates/forks/CV-target excluded), ranking commented inline | cvagent.nix |
| **DEPLOYMENT LANDED** (via parallel session's switch) | gen 982 anchored 02:07 with the full wave — PATH fix, AI wiring, sops template, 24 repos | live system |
| **AI extraction PROVEN in production** | `28 facts via ai` (gogenfilter) in the production db; probe-2 `21 facts via ai` | live system |
| Fallback safety proven live | probe-1: timeout → rule-based, facts still flow | probe db |
| Docs + queue current | runbook AI section + repo-list note + busctl/polkit trap; deploy row updated ×2 on both surfaces; 3 new harvest rows (timeout fix, upstream knob, week-one review) | docs + todo |
| Deploy-orchestration pattern that works | passive PSI watch (cheap /proc reads) → single fire: caught the 01:03 calm window in 3 polls | ~/.cache/cvagent/deploy-passive.sh |

## b) PARTIALLY DONE

1. **First full production cycle (24 repos)** — 13/24 completed with AI facts before the 20min TERM at 02:33; ~2.5 min/repo measured (gogenfilter: 926 commits → 28 facts in 2.6 min). In tree: `TimeoutStartSec = 90min` (eval green). Deploy + battery chain running. Missing: `done: scanned=24 failed=0`, mesh artifacts, final extractor mix. Blocker: none — chain is passive-watch gated. Effort: S (auto-completes).
2. **AI fact quality** — production has ~13 repos of glm-5.3-flash facts nobody has reviewed. Missing: the runbook's delta-review pass over generated pages (harvested as a [ready] row). Owner cadence decision owed (§g Q2).
3. **cvagent monitoring surface** — OnFailure fired correctly twice (05:56, 02:33); the system-health metric flip for a oneshot remains unprobed; no post-deploy §-leg yet (harvested 20:49, still queued).

## c) NOT STARTED

| Planned | Why | Priority |
| --- | --- | --- |
| post-deploy-check §-leg for cvagent | queued 2026-11-04 20:49 | High |
| eval-time `runtimeInputs` coverage audit | queued 2026-11-04 20:49 | High |
| `cvagent health` preflight in the unit | queued 2026-11-04 20:49 | Medium |
| upstream `ai.maxcommitsample` config knob | harvested THIS report (the latency lever the timeout fight proved missing) | Medium |
| week-one AI-facts quality review | harvested THIS report | Medium |
| SigNoz/system-health oneshot-failure verification | rides the cycle completion | Low |
| (carried) freeze-#46 residuals, tmpfiles mystery, SECCOMP loop, PMA stale-binary check, Stalwart CalDAV probe, pim-sync flip… | other sessions' queue — untouched by this session | see TODO_LIST.md |

## d) TOTALLY FUCKED UP

1. **My 20-minute unit budget was WRONG — and it paged Discord at 02:33.** I sized `TimeoutStartSec` from a parallelism assumption (3-way repo scan) without measuring AI-call latency; reality is effectively sequential at ~2.5 min/repo → 24 repos ≈ 60 min. systemd TERMed the run at repo ~13/24 (`status=15/TERM`, `Failed with result 'timeout'`). Cost: truthful OnFailure page #2 in one day + an incomplete cycle. Fix: 90min with the measured numbers in the comment. Lesson: budgets come from MEASURED per-unit work, not architecture assumptions.
2. **My deploy retry loop self-stormed the box it was polling.** Each `nix run .#deploy` attempt runs a full flake eval (minutes of heavy IO) BEFORE the gate can refuse — so a tight 3-minute retry cadence re-created the PSI storm it was waiting out (stalled cgroup = my own ghostty scope). 30 minutes of self-blocked retries. Fix: passive /proc-only watch + single fire. Lesson: a gate-check that costs the thing it guards is self-defeating.
3. **My busy-proxy arithmetic was wrong** (clamped to 100% constantly while PSI was 0) — 12 polls of garbage replaced by using the deploy gate itself. Corollary shame: I re-typed `rg -rn` TWICE (the `-r` is replace trap, third strike on this host per the hook) and typed `sudo` twice against the guard — every one already documented in AGENTS.md, one of them cited BY ME in this session's own reading.
4. **My probe script mislabeled a lock-conflict exit as success** (`DEPLOY-ATTEMPT-FINISHED rc=0` after `❌ Another deploy is already running`). The marker lied; the /proc forensics in the next probe corrected the record (holder = quotaboard crush session). Lesson: exit-code ≠ outcome; the script printed what I wanted to see, not what happened.
5. **Empty-read violation (self-caught, still embarrassing):** my first key-shape check piped stderr to /dev/null and concluded from `length=0` — the exact "an empty read is never evidence" trap cited in AGENTS.md. The re-run surfaced the typed-sudo guard as the real cause.
6. **Concurrent-session merge hazard handled, barely noticed in time:** the other session's tree carried the EXACT two lines my feature needed (cli plumb + Config field) interleaved with their unrelated atomic-write adoption; my first `multiedit` attempt was refused mid-flight by their edit. The diff review + pathspec commits kept attribution clean — but a twin-executor run on the SAME feature was one page-flip away.

## e) WHAT WE SHOULD IMPROVE

| Pattern | Impact | Suggested fix |
| --- | --- | --- |
| Unit budgets from assumptions | one page + one lost cycle tonight | the repo habit of writing the MEASURED number into the timeout comment (now done) — extend: any `TimeoutStartSec` change must cite a live measurement or a named estimate basis |
| Deploy retry loops that eval per attempt | 30 min self-blocked; contributed load | passive watch + single fire (pattern proven tonight) — worth a paragraph in docs/CONTRIBUTING.md's deploy section |
| Exit-code labels vs outcomes | misleading success marker | scripts should grep the OUTCOME (e.g. "done:"/"already running"), not their own pipeline rc |
| AI-call latency visibility | 2.5min/repo discovered only by timeout | upstream `ai.maxcommitsample` knob (harvested) + consider journal timing lines per repo |
| Guard discipline | 4 trips, all documented rules | no code fix — the hooks work; slow down on typed one-liners |
| Cross-session deploy coordination | three switches tonight, one wave, zero conflicts BUT zero coordination either | the deploy lock + anchor checks held; a "who is deploying" probe (`/tmp/.systemnix-deploy.lock` fd scan) before waiting loops would have saved the first two rounds |

## f) 50 things to get done next (updated dispositions; fresh items first)

**NEW-HARVEST** = queued this report. **QUEUED** = in the queue, unchanged. **DONE-THIS-SESSION** = closed by this arc (kept for the count). **RIDES-CHAIN** = the running deploy-fix chain completes it. **UPSTREAM** = Code-To-CV-Agent repo. **ROADMAP** = brainstorm fuel.

| # | Task | Impact | Effort | Category | Disposition |
| --- | --- | --- | --- | --- | --- |
| 1 | Complete the 90min-budget deploy + battery: `done: scanned=24 failed=0`, extractor mix, CV artifacts, anchor check | Critical | S | Bug | RIDES-CHAIN (script live) |
| 2 | Week-one AI-facts quality review (delta render → promote real keywords → unmark weak pages) | High | M | Quality | NEW-HARVEST |
| 3 | Upstream `ai.maxcommitsample` config knob (cost/latency lever) | Medium | S | Feature | NEW-HARVEST |
| 4 | post-deploy-check §-leg for cvagent | High | S | Quality | QUEUED |
| 5 | Eval-time audit: writeShellApplication binaries vs `runtimeInputs` | High | M | Quality | QUEUED |
| 6 | `cvagent health` preflight in the unit script | Medium | S | Quality | QUEUED |
| 7 | Verify system-health metric flips on cvagent failure | Medium | S | Quality | QUEUED (carried) |
| 8 | lessons: passive-watch deploy pattern + measured-timeout rule → docs/CONTRIBUTING.md | Medium | S | Process | NEW (record in report; commit next session) |
| 9 | Deploy-lock fd-scan before waiting loops (who-is-deploying probe) | Low | S | Tooling | ROADMAP |
| 10 | Clean up /home/lars/.cache/cvagent probe scripts (misleading rc=0 label; keep probe-ai.sh) | Low | S | Cleanup | ROADMAP |
| 11 | Deploy monitor365 tmpfiles `mkBefore` + tmpfiles-apply legs | High | S | Bug | QUEUED |
| 12 | Why `systemd-tmpfiles-setup` didn't re-run on gen-977/978 | High | M | Bug | QUEUED |
| 13 | monitor365 dmesg SECCOMP crash-loop triage | High | S | Bug | QUEUED |
| 14 | tq-agent-pool start in first sub-30% PSI window | Medium | S | Ops | QUEUED |
| 15 | PMA stale-binary standing check | High | S | Quality | QUEUED |
| 16 | OTel localhost:4318 refusals — owning unit | Medium | S | Bug | QUEUED |
| 17 | freeze-#46 residual attribution | Medium | M | Bug | QUEUED |
| 18 | Stalwart CalDAV authenticated probe | Medium | S | Verify | QUEUED |
| 19 | All-Backups-Healthy gatus deploy | High | S | Bug | QUEUED |
| 20 | mkPoolDirUnit owner/mode audit + invariant | Medium | M | Quality | QUEUED |
| 21 | pim-sync owner-gated flip ladder | High | M | Feature | QUEUED (blocked:user) |
| 22 | indexer-web post-deploy smoke + ioTier | Medium | S | Quality | QUEUED |
| 23 | paperless-tasks-collector fixture test | Medium | M | Quality | QUEUED |
| 24 | buildcache-recovery VM legs | Medium | M | Quality | QUEUED |
| 25 | FOD probe productization + lock-node gotcha doc | Medium | S | Tooling | QUEUED |
| 26 | Upstream: commit the still-uncommitted humanize work residue | High | S | Hygiene | UPSTREAM (status re-check owed) |
| 27 | Upstream: re-propagate `technologys` fix to exports | Medium | S | Bug | UPSTREAM |
| 28 | Upstream: "1 repos" copy bug | Low | S | Bug | UPSTREAM |
| 29 | Upstream: watch two-pass E2E | Low | M | Quality | UPSTREAM |
| 30 | Upstream: a11y audit | Low | M | Quality | UPSTREAM |
| 31 | Upstream: hermetic CSS build | Low | M | Quality | UPSTREAM |
| 32 | Upstream: CI unblock (billing) | Medium | — | Infra | UPSTREAM (blocked:user) |
| 33 | Upstream: determinism E2E (byte-identical reruns) | Low | S | Quality | UPSTREAM |
| 34 | Upstream: AI path E2E vs mock server | Low | M | Quality | UPSTREAM |
| 35 | Decide: repo-list cutline revisit after first full cycle (24 repos ≈ 60 min — keep/trim) | Medium | — | Decision | ROADMAP (owner, §g Q3) |
| 36 | Decide: GLM credit budget for ~24 daily AI calls | Medium | — | Decision | ROADMAP (owner, §g Q1) |
| 37 | Decide: AI-facts review cadence after week one | Medium | — | Decision | ROADMAP (owner, §g Q2) |
| 38 | Decide: rev-pin cvagent input for hash stability | Low | — | Decision | ROADMAP |
| 39 | Decide: cvagent.db backup leg vs regenerable | Low | — | Decision | ROADMAP |
| 40 | mesh export diff-preview before PMA commits | Low | M | Feature | ROADMAP |
| 41 | Per-oneshot duration metric (scan runtime visibility) | Low | M | Feature | ROADMAP |
| 42 | cvagent on darwin? | Low | — | Decision | ROADMAP |
| 43 | facts-explorer tile on dash.home.lan | Low | M | Feature | ROADMAP |
| 44 | Event-journal retention/GC policy | Low | S | Quality | ROADMAP |
| 45 | Keyword drift report (mesh vs curated base) | Low | M | Feature | ROADMAP |
| 46 | 05:53 slot collision check vs other timers | Low | S | Verify | ROADMAP |
| 47 | Integration-registry rule: timer ⇒ first-fire verification row | High | S | Process | ROADMAP |
| 48 | Integration-registry rule: manual-run ≠ unit verification (cvagent case study) | High | S | Process | ROADMAP |
| 49 | Upstream: `mesh --dry-run` | Low | M | Feature | ROADMAP |
| 50 | Upstream: prove or retire `watch` | Low | S | Cleanup | ROADMAP |

## Self-harvest ledger

- **Harvested NOW (02:35)**: §f 2 → TODO_LIST.md + services.md; §f 3 → TODO_LIST.md + upstream.md; the 90min-fix completion row → TODO_LIST.md + services.md (replaces/augments the wave deploy row with the timeout evidence).
- **Deliberately NOT harvested**: §f 1 rides the live chain (already rowed — double-rowing one dispatch); §f 8–10 are session-local cleanup/process notes recorded here; §f 26–34 belong to the cvagent repo's own queue; §f 35–50 are ROADMAP fuel (brainstorm ≠ commitment, owner decisions marked).

## g) Questions I cannot answer myself

Surfaced as interactive questions at report time: (1) GLM credit budget for cvagent's ~24 daily sampled calls; (2) AI-facts quality bar — auto-ship vs a review pass before mesh ships; (3) accept the 60–90min daily background scan or trade scope for a shorter window.

---

*Then wait for instructions.*
