# Status Report — Forgejo Deep-Research Session

**Date:** 2026-09-18 07:47 CEST
**Scope:** This session only — the "research everything Forgejo + write the max-out report" run. Not a project-wide status.
**Artifacts produced:**

- `docs/research/2026-09-18_forgejo-deep-research.html` (86.5 KB, 1879 lines, committed by daemon: `cb096333` → corrected in `ce4df826` 07:16)
- This report.

**Format note:** The status-report skill's canonical output is a styled HTML dashboard; the user explicitly requested `.md` at `docs/status/`, so the override is honored here (skill spec divergence flagged per its own rule).

---

## a) FULLY DONE

1. **Local Forgejo audit** — `modules/nixos/services/forgejo.nix` read in full (598 lines), plus `docs/services/forgejo-upstream-issues.md` (3 drafted upstream issues, re-verified upstream 2026-09-18 per its own header) and `docs/archive/forgejo-federation.md`.
2. **Primary-source web research (13 fetches, all 2026-09-18):** forgejo.org/releases (v16.0.5 stable, v15.0.9 LTS, EOL table), Codeberg releases page (repo stats: 5.5k stars / 955 forks / 119 releases), official announcements **v12, v13, v14, v15, v16**, Delightful Forgejo README (full community catalog), Actions admin guide (retention/storage/DEFAULT_ACTIONS_URL), runner releases (v13.1.0 / v13.0.0), runner v13 breaking-changes blog post, Renovate platform docs (`platform=forgejo`), gitea-mcp repo page (official MCP server, 60+ tools, read-only mode), catppuccin/gitea README, data.forgejo.org API record for `actions/checkout`.
3. **The report itself** — `docs/research/2026-09-18_forgejo-deep-research.html`: 10 sections, feature tables by introducing version, Actions deep dive, ecosystem catalog, 19-item prioritized roadmap (P0–P3) with anti-recommendations, instance-specific risk section, full sources appendix.
4. **Verification loops ran twice:** HTML tag-balance validator (0 errors before and after edits), secret-pattern scan (clean), stale-claim grep after corrections (clean).
5. **Self-caught false claim:** initial draft asserted "zero Actions workflows exist"; a local `find` disproved it (3 repos carry `.forgejo/workflows`). Report corrected via 9 targeted edits; corrected claim is now precise (which repos, which workflows, what they do).
6. **Pre-recommendation verification:** `data.forgejo.org/actions/checkout` confirmed to exist (public mirror of the GitHub action, `mirror_updated` 2026-09-18) via its API **before** recommending the `DEFAULT_ACTIONS_URL` flip that three live workflows depend on.
7. **Deliverable committed** by the auto-commit daemon (initial `cb096333`, corrected `ce4df826`); working tree clean for the artifact.
8. **LTS-vs-stable question answered** with sourced reasoning (forgejo.nix:137, support windows, v16 mirror-redirect breaking change, host upgrade history).

## b) PARTIALLY DONE

1. **The 3 workflow files were read at heads only** (30–40 lines each). The report's "clean on a spot-check" (v13-removed commands) rests on partial reads — the full sweep (`rg '::set-output|::set-env|::add-path|GITEA_'`) was written into the report as R8 but **not executed**.
2. **`_forgejo-scripts.nix` never read.** All inventory claims about mirror/token/OIDC/SSH-key scripts derive from `forgejo.nix` usage and comments, not the script sources.
3. **"3 repos run workflows" is really "3 repos have workflow files."** No call was made to the live forge — whether `wireguard-collector`/`collector-utils`/`monitor365` exist as native repos there, and whether any runs ever executed, is unverified.
4. **Scorecard denominator is sloppy:** "3 of ~260" mixes PMA's 260+ _local checkouts_ with the forge's actual repo population (~134 mirrors + natives). The numerator is verified; the denominator is not a forge-side number.
5. **Mirror count "~134"** comes from the 2026-08-22-era upstream-issues doc — never re-verified against the live instance.
6. **v11.0 announcement not fetched** → its table row is intentionally thin and flagged as such in the sources section.
7. **Visual QA skipped:** the HTML passed structural validation but was never rendered/screenshotted; the scrollspy script is untested beyond writing it.
8. **`agentic_fetch` hard-failed 4/4** at session start (provider-side Go unmarshal error). I fell back to plain `fetch` and moved on — the failure was never reported to the user until this report, and remains undiagnosed.

## c) NOT STARTED

1. **docs-health HARVEST** — section (f) below has not been routed into `TODO_LIST.md` / `ROADMAP.md`.
2. **AGENTS.md updates** — nothing learned this session (LTS rationale, 3 existing workflows, runner label naming, data.forgejo.org flip pending) was written into the project memory file.
3. **Filing the 3 drafted upstream issues** — pre-existing blocker (no Codeberg account), untouched this session; drafts remain verified and ready.
4. **Every roadmap remediation** — R1–R19 are recommendations only; zero config lines changed on the host this session.
5. **Live-forge verification pass** — no API call to `forgejo.home.lan` was made at any point (mirror count, native-vs-mirror repo split, runner version, Actions run history).
6. **Dedicated Forgejo runbook** — `docs/services/forgejo.md` does not exist (only the issues + federation notes); operational knowledge still lives in AGENTS.md and status docs.

## d) TOTALLY FUCKED UP

1. **The first committed version of the report contained a fabricated-by-negligence claim** ("no repository carries a `.forgejo/workflows/` file doing real work" + scorecard stat "0 real Actions workflows"). It was asserted from absence-of-evidence — I never ran a `find` before writing it. The wrong version was auto-committed as `cb096333`; the correction landed in `ce4df826`. Per the point-in-time doctrine the old commit stays (annotate, never rewrite), but the false claim is in history. **Lesson encoded:** existential claims ("no X exists") require an existence check in the same breath as writing them — this is the report-writing twin of the repo's "independently verify tool output" rule.

That is the only entry. Nothing was destroyed, no config touched, no secrets exposed (secret scan clean), no service impacted.

## e) WHAT WE SHOULD IMPROVE

1. **Verify against the LIVE system, not the source config.** "What does the forge actually have" beats "what does forgejo.nix say" for every count claim (mirrors, repos, runner version, Actions runs).
2. **Existence-check before existential claims** (see d1) — a `find`/`grep` costs 5 seconds.
3. **Read whole files before characterizing them** (workflow heads, `_forgejo-scripts.nix`).
4. **Number hygiene:** every count in a report carries its source and scope ("forge-side" vs "checkout-side"); no mixed denominators.
5. **Close the loop in-pass:** AGENTS.md + TODO_LIST updates should happen inside the session that learns the thing (memory-maintenance doctrine says "immediate", not "next session").
6. **Visual QA for styled deliverables:** tag-balance ≠ renders-well; open the artifact once.
7. **Report tool breakage immediately** (agentic_fetch 4/4 failures were silent-switched around) — environment faults are session findings too.
8. **Calendar the time-bombed facts:** v17.0 lands 2026-10-15, v16.0 EOL 2026-10-29, v15.0.9 EOL 2027-07-15 — none became a tracked reminder.

## f) TOP THINGS TO GET DONE NEXT (50, sorted by tier; 1–10 are session follow-ups, 11+ are the report's roadmap made actionable)

**Session hygiene (verify my own work first):**

1. Run the R8 sweep for real: `rg -n '::set-output|::set-env|::add-path|DOCKER_USERNAME|GITEA_'` across all local `.forgejo`/`.gitea` workflow dirs; record the deployed `forgejo-runner --version`.
2. Live-forge API pass: native-vs-mirror repo split, whether the 3 workflows have actual runs, real mirror count (replace stale "~134").
3. Read `_forgejo-scripts.nix` in full; confirm the report's inventory claims.
4. Read the 3 workflow files in full; confirm v13-cleanliness; log the "kept in sync manually" debt in AGENTS.md.
5. Fix the "3 of ~260" denominator in the report via a point-in-time annotation (docs-health ANNOTATE style — the doc is committed, not rewritten).
6. Annotate the same doc noting `cb096333` carried the corrected-claim history (readers of the file today see the fixed text; history stays).
7. Update AGENTS.md forgejo section: LTS choice + rationale, 3 existing workflows, `native` label naming, data.forgejo.org flip pending.
8. **HARVEST this list into `TODO_LIST.md` / `ROADMAP.md`** (docs-health) — section (f) is fuel, not an entombed appendix.
9. Visual render check of the report (browser open / screenshot).
10. Calendar items: v17.0 2026-10-15, v16.0 EOL 2026-10-29, v15.0.9 EOL 2027-07-15.

**P0 — config-only quick wins (report R1–R5):**
11. `DEFAULT_ACTIONS_URL` → `https://data.forgejo.org` (checkout mirror verified; three workflows keep working).
12. `LOG_RETENTION_DAYS = 30`, `ARTIFACT_RETENTION_DAYS = 30` (defaults 365/90 on QLC NVMe).
13. `[migrations].ALLOWED_DOMAINS` GitHub-only allowlist + `ALLOW_LOCALNETWORKS = false`; verify one mirror sync after (watch `system_forgejo_mirror_erroring`).
14. `forgejo doctor cleanup-commit-status --dry-run` (SQLite: small chunk / quiet window).
15. Catppuccin Mocha theme: CSS into `custom/public/assets/css` + extend `ui.THEMES` (declarative derivation).

**P1 — real unlocks (R7–R12 + decisions):**
16. Scale the workflow pattern to active Go repos + SystemNix itself (monitor365's Nix+attic shape is the template).
17. Create a reusable-workflow library repo; port the 3 hand-synced workflows to it (v15 expansion = separate job logs, multi-label).
18. Migrate any workflow the R8 sweep flags to v13 syntax **before** the next nixpkgs runner bump.
19. `enable-email-notifications: true` on scheduled workflows (gated on Resend domain verification — cross-ref mail-relay TODO).
20. Create the Codeberg account; file the 3 drafted upstream issues (TouchMirror masking, Trace-level dedup-skips, credential-helper aborts) — they are verified and blocked on nothing else.
21. Mirror-rename inventory pre-v16: list upstream repos renamed/transferred since mirror creation (v16 makes their redirects hard errors).
22. Re-issue sync/hermes/(future MCP) tokens as repo-scoped (v15 feature).
23. Decide the upgrade path and write it down: hold v15 LTS → jump to the Apr-2027 LTS, vs. mid-cycle v16.x once patched; include the mirror-redirect mitigation plan.
24. Evaluate whether `tests/test-forgejo.nix` exists; if not, add a VM test (OIDC setup, mirror sync, backup converge flow — the module is the least-tested first-tier service).

**P2 — ecosystem adoption (R13–R16 + tooling):**
25. Wire gitea-mcp into crushrc: read-only first (`GITEA_READONLY=1`), repo-scoped token, probe the tool set against Forgejo; remember MCP loads at session start.
26. Self-hosted Renovate via Actions on native repos (`platform=forgejo`, explicit repo allowlist; autodiscovery correctly skips mirrors).
27. Nightly `skopeo copy` of `lib/images.nix` pinned images into the Forgejo OCI registry (Docker-Hub outage insurance; `org.opencontainers.image.source` for v15 auto-linking).
28. Weekly mathisdt/forgejo-backup run for the handful of repos whose issues/PRs/releases must survive (migration-grade, complements `forgejo dump`).
29. Pick ONE CLI for scripting (tea / berg / forgejo-cli) and put it on PATH via `mkLarsPackages`; avoid a three-CLI split brain with the existing API scripts.
30. Terraform provider: adopt or record the explicit rejection in AGENTS.md (currently only implicit in the report's anti-recommendations).
31. Nayrah Discord bot: adopt or reject (Gatus→Discord + PapDashboard already own event alerting).
32. Evaluate moving Actions artifacts/logs (and later LFS) to `/mnt/pool` via `[storage.*]` with the mount-gated oneshot pattern (226 class rules apply).
33. Document the runner trust boundary: `container.network=host` + `native` label stay only while 100% of workflows are self-authored.
34. Decide org-level vs repo-level Actions secrets (monitor365's `ATTIC_ENDPOINT/TOKEN` pattern as the precedent) and document it.
35. Create `docs/services/forgejo.md` — the service lacks the standard runbook every sibling service has.

**P3 — frontier / watchlist / exploration:**
36. Pages server evaluation (git-pages / gitgay pages-server behind Caddy) vs the Firebase website-launch pattern.
37. Federation watch item: revisit when cross-instance issues/PRs land (ForgeFed roadmap; v13 moderation was the groundwork).
38. Cargo registry trial for private Rust crates (exploratory; Nix fetch plumbing unknown).
39. Go module registry trial for LarsArtmann modules (GOPRIVATE interplay; exploratory).
40. Code-search indexer decision: native repos opt-in only (IO cost of indexing 134 mirrors on this NVMe).
41. Instance SSH commit signing (v12) evaluation for forge-created merge commits.
42. Review `[quota]`/soft-quota settings (likely no-op single-user; document the decision).
43. Incoming-email (reply-by-email) feasibility note — parked until inbound mail exists at all.
44. GitHub-rename watchdog oneshot: diff upstream `full_name` vs mirror config URLs, alert on drift (automates R21 permanently).
45. Mirror sync cadence review: 6h enumeration + 8h interval vs actual need; free rate-limit headroom for bulk operations.
46. Diagnose/report the `agentic_fetch` provider failure if it recurs (crush_logs evidence).
47. Sweep `docs/status/` older Forgejo-adjacent reports for still-open items and ANNOTATE-mark them (docs-health pass).
48. Consider surfacing `system_forgejo_mirror_*` metrics into a SigNoz dashboard panel set (currently Gatus-only visibility).
49. Evaluate `forgejo-runner exec` as the local workflow-testing loop for the reusable library (dev UX win, zero deploy cost).
50. Re-run this research pass at v19-LTS time (Apr 2027) — the feature tables will have moved; mark the report superseded then.

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **What is Forgejo's strategic role?** Permanent read-only mirror cabinet of GitHub (current de-facto), or intended to become the authoritative forge for some repos (native repos, CI, releases there)? This decides the scope of R7/R16/R26 (workflows, Renovate, registry) — everything else I can derive.
2. **Codeberg account:** the 3 drafted upstream issues are blocked on creating one — under what identity/name should it be registered, and are you OK with filing from this machine?
3. **Upgrade risk appetite:** strict LTS→LTS only (wait for April 2027), or willing to ride a stable branch mid-cycle when a specific v16/v17 feature becomes load-bearing? Given this host's deploy history I recommended LTS-only, but that is your risk call, not a derivable fact.

---

**Next:** waiting for instructions. If the instruction is "process the list," the first move is #8 (HARVEST into TODO_LIST.md) so none of the 50 items get entombed in this timestamped file.
