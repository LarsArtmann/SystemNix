# Status Report — Forgejo Actions "Everywhere?" PRO/CONTRA Session

_2026-10-12 15:45 CEST · session type: exploration/Q&A (read-only analysis) · zero config changes, zero deploys_

**Session scope (complete list of what happened):**

1. Owner question: "Now that we have forgejo should we enable Actions everywhere? PRO/CONTRA"
2. Read-grounded research pass: `modules/nixos/services/forgejo.nix` (runner + actions config), `forgejo-repos.nix` / `_forgejo-scripts.nix` scans, `docs/services/forgejo.md` runbook structure, `docs/brainstorming/2026-07-22_forgejo-runners-github-sync.md`, `TODO_LIST.md` + `docs/todo/services.md` Actions cluster rows.
3. PRO/CONTRA answer delivered in chat with a decisive recommendation.
4. Self-harvest at report-authoring time (this report + 2 todo edits, §f items 1–2).

No file in `modules/`, `systems/`, `platforms/`, or `flake/` was touched. No service was probed live (`ss`, census, API) — see §b.1/§e.1 for why that matters.

---

## The Answer Itself (persisted here — chat is not durable)

**Verdict: enable Actions selectively on a canonical-repo cohort. NOT "everywhere."**

Ground truth established from config reads:

- `actions.ENABLED = true` is already instance-wide (forgejo.nix:367) — "enable everywhere" is really a question about **per-repo Actions units** (`has_actions`), currently believed ON only for `eventcatalog-hub` (via the setup script's unit PATCH — TODO prose, NOT live-verified).
- Exactly one runner: host-mode, label `native` (Docker labels removed with Docker 2026-10-08), capacity 2, `MemoryMax = 16G`, DynamicUser, PATH extended with nix/jq/python3 (forgejo.nix:1178–1223).
- Mirror-sync push **provably fires `on: push` workflows** (2026-10-11 go-live evidence).

| PRO                                                                              | CONTRA                                                                                                                                                      |
| -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nix-native CI GitHub can't do (`nix flake check`, buildflow, local-store builds) | Host-mode executor = arbitrary workflow code with nix-daemon socket access on the prod host (DNS, Immich, SigNoz, AI stack); no container isolation remains |
| Prerequisite for Forgejo-as-primary (staged-primary Phase 1)                     | Enabling on mirrored repos = every upstream repo's `.github/workflows` auto-executes here; the `starred` org mirrors **third-party** code                   |
| 128 GB host; no GitHub minute/queue limits                                       | Getting ONE repo green took 5 script versions / 7 bug classes; Actions logs are root-only (agent CI post-mortems need owner round-trips)                    |
| Cheaper than GitHub Actions for the LarsArtmann set                              | Freeze-history host: CI bursts compete with prod; runner+forgejo interlock already caused one crash-loop class                                              |
| Marginal per-repo cost is one PATCH; runner infra debugged                       | `DEFAULT_ACTIONS_URL = github` → unpinned third-party actions fetched at job time (supply chain); job builds pollute the host nix store                     |

**Recommendation:** flip Actions units on for LarsArtmann-canonical repos only (SystemNix, go libs, eventcatalog-hub); `starred` org + foreign mirrors stay Actions-off permanently. Dismissed alternative: global `DEFAULT_REPO_UNITS` flip — one malicious workflow in any starred mirror gets host + nix-daemon execution. Precondition: close the CI-log observability gap (scoped read-only token, existing `[decision]` row).

---

## a) FULLY DONE

1. **PRO/CONTRA answer delivered, grounded in repo facts** — every claim carries a `file:line` or dated evidence pointer (forgejo.nix:367/1178–1223; 2026-10-08 Docker removal; 2026-10-11 label-truename + mirror-sync-fires-on-push proofs). No generic-LLM Forgejo folklore.
2. **Decisive recommendation with a dismissed alternative** — selective cohort vs. global flip, dismissed with the exact mechanism (arbitrary workflow code + nix-daemon socket on prod host).
3. **Planning-layer pre-read honored** — `rg -il "actions"` across `docs/brainstorming/` + `docs/planning/` ran BEFORE the analysis; the 2026-07-22 runners brainstorm was read in full (its Docker-label era is stale, but the bidirectional-sync model sections are still accurate and were used).
4. **Session self-harvest completed at authoring time** — the two direct follow-ups (live census `[ready]`, cohort decision `[decision]`) landed in `TODO_LIST.md` + `docs/todo/services.md` in the same pass as this report (§f items 1–2).

## b) PARTIALLY DONE

1. **The premise "currently only eventcatalog-hub has the Actions unit" is doc-claimed, not live-verified.** Sourced from `docs/todo/services.md`:182 (the catalog go-live close-out prose). No API/census/sqlite probe ran. This violates the Session Discipline rule ("never assert a service capability from a doc claim alone — live-verify"). The analysis is directionally safe (it argues AGAINST the risky direction), but the current-state count is unverified → census queued `[ready]`.
2. **Decision recording was chat-only until this report.** The PRO/CONTRA existed nowhere durable; this report + the two todo rows close that gap (done at authoring time, listed here for the record).
3. **Staged-primary connection cited from runbook section headers only.** The full `docs/planning/2026-09-18_16-44_FORGEJO-PRIMARY-STAGED-FOUNDATION.md` was not read; the PRO "primary prep" point rests on the runbook summary, not the plan's detail.

## c) NOT STARTED

1. **Any actual enablement work** — zero config changes; `forgejo-repos.nix` / canonicalRepos has no Actions-unit mechanism yet.
2. **Live census of Actions-unit state** (now queued `[ready]`).
3. **Owner ratification of the cohort** (now queued `[decision]`).
4. **Runner isolation hardening design** (dedicated CI user / rootless containers / remote builder host) — not started anywhere; ROADMAP-grade.
5. **Dual-CI policy** (GitHub Actions vs Forgejo Actions on mirrored repos — which survives, who owns divergent results) — not addressed anywhere in the repo; surfaced by this session, never worked.

## d) TOTALLY FUCKED UP

**Nothing this session.** Read-only analysis; no config touched, no deploy, no prod probe, no state mutation — nothing to break.

One near-miss worth naming honestly: the unverified "only eventcatalog-hub" premise (§b.1) nearly graduated into a recommendation **stated as fact**. Caught during authoring-time self-review; converted into the census verification row instead of being silently carried. Had the question been "enable it everywhere, go", the wrong premise would have cost a dispatch cycle (the @home-hermes wrong-premise class, 2026-10-08).

## e) WHAT WE SHOULD IMPROVE (what I forgot / could have done better)

1. **Live-verify before asserting current state.** The one real process gap. The verified live-probe set exists (`ss`, `pgrep`, census script, openssl s_client); a single census/API call would have replaced the doc-claim with a fact. Fix landed as a queued `[ready]` row.
2. **Missed dimension: dual-CI cost.** Every mirrored LarsArtmann repo already runs GitHub Actions. Enabling Forgejo CI alongside = second CI instance, double failure surface, divergent green/red between the two forges. The natural end state ("canonical repos migrate CI to Forgejo, GitHub Actions retired there") was never weighed in the PRO/CONTRA.
3. **Missed dimension: DB/backup growth.** Actions job logs + artifacts live in `forgejo.db` → bigger dumps (03:30 cron), more btrbk snapshot pressure on the Samsung subvol. Unmentioned.
4. **Missed dimension: concurrency math.** One runner instance, capacity 2, `MemoryMax 16G`. A multi-repo cohort needs an explicit contention policy (queue behavior, priority, second instance or capacity bump, schedule windows) — the answer hand-waved "beefy host" without addressing serialization of a cohort's burst load.
5. **Missed nuance: the PR-approval trust model.** Forgejo's first-time-contributor approval protects fork PRs but NOT same-owner mirror pushes — which is exactly this setup's vector (mirrors fire `on: push` as the owner). The contra said "mirrors auto-fire" without noting which existing Forgejo knobs do and don't cover it.
6. **Format: a ratification-ready decision memo** (cohort list proposal + enablement mechanism + rollback) would have beaten pure PRO/CONTRA for actionability. Exploration mode justified the form; the recommendation still lacked the concrete "what exactly would I flip, in which file".
7. **"Everywhere" was never scoped numerically.** No census → the answer couldn't say whether "everywhere" is 12 repos or 200 (starred alone could dominate). Fixed by the queued census.

## f) Things to Get Done Next (31 items — brainstorm, not commitments; extra-N routing per docs-health HARVEST)

**Forgejo Actions cluster (this session's domain; items 1–2 harvested THIS session):**

| #  | Item                                                                                                                                                                                                                  | Suggested status/landing                            |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| 1  | **NEW** Live-census Forgejo Actions-unit state (all repos + `starred` org) — gates the enablement decision; falsifies/verifies the "only eventcatalog-hub" premise                                                    | `[ready]` → TODO_LIST + services.md (harvested now) |
| 2  | **NEW** Ratify selective Actions enablement cohort (canonical-only; starred/foreign mirrors off forever)                                                                                                              | `[decision]` → services.md (harvested now)          |
| 3  | Owner: paste run #5/#4 failed-step log (standing go-live chain head)                                                                                                                                                  | existing `[blocked:user]`                           |
| 4  | Owner: push hub `bf86e06`, cancel runs 1–3, sops-paste current sync-token                                                                                                                                             | existing `[blocked:user]`                           |
| 5  | Delete 4 orphaned all-scope setup PATs (UI)                                                                                                                                                                           | existing `[blocked:user]`                           |
| 6  | Trash stale `/var/lib/forgejo/data/gitea.db` fossil                                                                                                                                                                   | existing `[blocked:user]`                           |
| 7  | setup-forgejo.sh loud-fail on empty `FJ_SHA` after HTTP 200                                                                                                                                                           | existing `[ready]`                                  |
| 8  | Runbook capture: forgejo.md + architecture-catalog.md Actions ops (token-API auth semantics, `name:schema` labels, `on: push` fires on mirror sync, `commit.id` payload, UTC crons, system-flake-registry dependency) | existing `[ready]`                                  |
| 9  | Fixture-from-live discipline for setup-forgejo.sh jq payload shapes                                                                                                                                                   | existing `[ready]`                                  |
| 10 | Runner job-lifecycle observability (debug log level vs wrapper health line)                                                                                                                                           | existing `[ready]`                                  |
| 11 | Scoped read-only Forgejo token (sops) for agent CI post-mortems                                                                                                                                                       | existing `[decision]`                               |
| 12 | Label-semantics eval selftest in forgejo.nix (pin the corrected label contract)                                                                                                                                       | existing `[ready]`                                  |
| 13 | **NEW (ROADMAP)** Runner isolation design before any wide cohort: dedicated CI user / rootless container / remote builder host                                                                                        | ROADMAP-grade                                       |
| 14 | **NEW (decision)** Dual-CI policy: which repos keep GitHub Actions vs migrate to Forgejo CI; divergent-results ownership                                                                                              | ROADMAP/decision                                    |
| 15 | **NEW (ROADMAP)** Actions log/artifact retention policy (forgejo.db growth → dump + btrbk pressure)                                                                                                                   | ROADMAP-grade                                       |
| 16 | **NEW (decision)** Cohort concurrency policy: capacity bump vs second runner instance vs schedule windows                                                                                                             | decision-grade                                      |
| 17 | **NEW (ready, post-go-live)** Declarative Actions-unit enablement in `forgejo-repos.nix` (canonicalRepos `actions` attr → has_actions PATCH) — the cohort mechanism                                                   | after items 1–2                                     |
| 18 | **NEW (decision)** Third-party action pinning policy for cohort workflows (`DEFAULT_ACTIONS_URL=github` supply chain)                                                                                                 | decision-grade                                      |

**Architecture Catalog go-live residuals (today's adjacent state, observed in services.md:182):**

| 19 | [watch] SigNoz tile row for catalog dist freshness | existing |
| 20 | Runbook-capture row (overlaps item 8's architecture-catalog leg) | existing |

**Boot-mirror (dated TODAY in AGENTS.md context — another session's finding, attributed honestly, not this session's work):**

| 21 | Re-run `boot-mirror-activate` + post-boot NVRAM re-decode (reversion #2: BootOrder flip lost across boots; `LoaderDevicePartUUID` must equal `023f66c0-3677-4c15-9ce7-f9e1f1457edb`, `BootCurrent 000C`) | top priority |
| 22 | Root-cause WHY the NVRAM order reverts across boots (cause unknown per AGENTS.md 2026-10-12) | after 21 |

**Broader open work observed in today's queue reads (pre-existing, pointers only):**

| 23 | Boot IO storm: relocate SigNoz ClickHouse to hot-DB disk (10m52s boot start) | queued today 13:40 |
| 24 | forgejo-github-sync follow-ups: re-interval N-strike de-escalation; zombie-mirror gauge; 24h mirror-freshness sweep | queued today 11:58 |
| 25 | §f-harvest backlog triage (104 unharvested reports, cross-session) | queued today 11:40 |
| 26 | Pocket-ID secret-rotation automation guard | queued today 11:40 |
| 27 | hermes config.yaml duplicate `provider` key (breaks terminal-policy parsing) | existing `[ready]` |
| 28 | indexer-web post-deploy smoke + live bring-up verification | existing `[ready]` |
| 29 | indexer-web `ioTier.background` assignment | existing `[ready]` |
| 30 | indexer-web Gatus `[RESPONSE_TIME]` condition | existing `[ready]` |
| 31 | `/data/docker` ~15.5 G reclaim decision (owner) | existing `[decision]` |

## g) Questions I Can NOT Figure Out Myself

1. **Cohort scope:** should the Forgejo Actions cohort be canonical repos ONLY (with the intent to eventually RETIRE GitHub Actions on those repos), or run alongside GitHub Actions on all mirrored LarsArtmann repos indefinitely? This decides dual-CI cost, the mirror-sync firing policy, and whether `starred` ever needs consideration.
2. **Security posture:** is host-mode DynamicUser with nix-daemon socket access an accepted long-term risk for CI, or do you want isolation (dedicated runner user / rootless containers / a dedicated CI host) landed BEFORE any cohort beyond eventcatalog-hub?
3. **Concurrency expectation:** is capacity 2 on the single evo-x2 runner sized correctly for the cohort's real burst profile (e.g. PR batches across the go libraries), or should the enablement decision include a second runner instance / capacity bump from day one?

---

_Self-harvest at authoring time: §f items 1–2 landed in `TODO_LIST.md` + `docs/todo/services.md` (same pass as this report). Items 3–31 are pre-existing queued work with pointers — deliberately not re-harvested (already live in their domain libraries)._
