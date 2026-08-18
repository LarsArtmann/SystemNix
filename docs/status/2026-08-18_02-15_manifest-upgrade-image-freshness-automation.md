# Manifest 6.18.0 Upgrade + Image-Freshness Automation — Self-Review & Status

**Date:** 2026-08-18 02:15
**Scope:** This session only — LiteLLM research → Manifest discovery → upgrade → "always latest" automation → healthcheck bug fix → two deploys.
**Live state at report time:** `mnfst-manifest-1` at `6.18.0` **healthy** (failing=0), `mnfst-postgres-1` healthy, Twenty untouched at v2.7.3, all other smoke checks green except the transient pocket-id item (below).

---

## a) FULLY DONE

1. **Research chain (LiteLLM vs llama.cpp vs Manifest)** — established Manifest is already a self-hosted LLM gateway (~80% LiteLLM overlap: routing, fallbacks, cost tracking; missing caching/virtual keys; unique: Autofix + subscription flows). Also surfaced: Manifest deprecated its "smart router" in June 2025 — our Homepage tile said "Smart LLM Router".
2. **Manifest upgrade 6.6.1 → 6.18.0** — `lib/images.nix`, now **digest-pinned** (`sha256:6e4fe29…`). Deployed twice, container healthy, `/api/v1/health` 200 via host, external vHost `manifest.home.lan` 200 through the auth gateway. DB migrations ran clean (backfill boot service completed: "stamped 0 messages across 0 windows").
3. **postgres:16-alpine digest refresh** (manifest sidecar only) — `cf78e766…`, container healthy, pgdata volume intact.
4. **whisper-rocm phantom tag fixed** — upstream repo (`beecave/insanely-fast-whisper-rocm`) has NO `latest` tag, only `main`. The old `tag = "latest"` only ever resolved because the digest pin wins. Corrected to `tag = "main"` with an explanatory comment. **Runtime-safe: `voice-agents.enable = false`** — no container exists to break.
5. **Pre-existing healthcheck bug FOUND and FIXED** — since 6.6.1 the compose healthcheck used a JS template literal `` `http://127.0.0.1:${p}/…` ``; docker-compose substitutes `${p}` with its OWN (unset) env → `http://127.0.0.1:/api/v1/health` → **every probe failed since the service was created**. Container reported "unhealthy" for its entire deployed life while host-level Gatus (200 on :2099) masked it. Fixed with string concatenation; verified `healthy, failing=0`. Root cause chain: manual `docker exec` fetch (200) → `docker inspect .Config.Healthcheck.Test` showed the mangled URL.
6. **`scripts/check-image-updates.sh`** — validates every entry in `lib/images.nix` against Docker Hub v2 API: digest-drift for pinned entries, highest-semver for app tags, SKIP for floating-unpinned (by design), `library/` prefix handling for official images. Live-tested: correctly reports Manifest/whisper/postgres OK, **Twenty OUTDATED (v2.7.3 → v2.31.1)**.
7. **`.github/workflows/image-updates.yml`** — daily 07:00 UTC (staggered after nixpkgs-compat 06:00), opens a deduplicated `image-updates`-labeled issue on drift. Mirrors the proven nixpkgs-compat shape.
8. **Stale naming corrected** — Homepage tile: "Smart LLM Router (Cost Optimization)" → "LLM Gateway (Autofix, Fallbacks, Cost Tracking)"; module description strings in `manifest.nix` updated to match.
9. **Policy codified** — AGENTS.md Critical Rules now carry the "Docker images ALWAYS on latest, pin tag+digest" directive with the checker/workflow pointers and the DB-app caveat.
10. **Twenty upgrade deliberately deferred to TODO_LIST (P1)** — 24 minors of startup DB migrations is not a blind bump; daily pg_dump → `/mnt/pool/backups/twenty` noted as the safety net.
11. **Deployed twice, both fully activated** — also shipped the stranded URGENT google-sync 226 crash-loop fix from the working tree (TODO P0). google-sync alerts should now be silent.
12. **pocket-id SQLITE_BUSY FAIL triaged to closure** — timeline-proven transient: first occurrence 00:23 (BEFORE any deploy; IO-pressure storm context — post-deploy WARN showed I/O avg10=97%), last 02:06 during the second deploy's restart churn, **zero in the 3 minutes after**. Auth flows (OIDC discovery) returned 200 throughout the tail. Not a regression from this session.

## b) PARTIALLY DONE

1. **"Always latest" automation** — script + workflow exist and the script is live-tested, but the **workflow is INERT until pushed to GitHub** (push not permitted from session). Until then there is no daily enforcement, only the manual script.
2. **Image pinning consistency** — manifest + manifest-postgres + whisper-rocm fully pinned; **twenty, twenty-postgres, twenty-redis unpinned** (twenty semver-checked by script, sidecars skipped as floating). Dozzle (`amir20/dozzle:latest`, unpinned) isn't in `lib/images.nix` at all — invisible to the checker.
3. **Checker robustness** — works against Docker Hub only; no pagination beyond 100 tags (Twenty has 381 — "latest" found only because tags list is recency-ordered); ghcr.io/quay.io images would false-ERROR as "repo gone".
4. **Manifest 6.18.0 verification** — liveness + migrations verified; **Autofix (the headline feature this upgrade unlocks for self-hosted) never exercised**, UI never rendered, Ollama env integration never re-verified, existing BetterAuth sessions not confirmed valid.

## c) NOT STARTED

1. Twenty v2.7.3 → v2.31.1 (changelog review + stepwise-or-single-jump decision).
2. Gatus/post-deploy-check coverage for **container-level health** (`docker inspect` health status) — the smoke suite tests host endpoints only; that blind spot is exactly how the 6.6.1 healthcheck bug survived.
3. AGENTS.md gotcha entry for the **compose `${}` substitution in healthcheck JS** class (fixed the instance, didn't record the pattern).
4. Manifest-as-router product wiring: register FastFlowLM/Ollama as custom providers, repoint go-commit/PMA `OPENAI_BASE_URL` at Manifest for fallback routing.
5. CHANGELOG entry for the upgrade (repo's CHANGELOG is stale since 2025-11 — practice-consistent omission, still an omission).
6. Pushing the workflow + committing session work (awaiting user).

## d) TOTALLY FUCKED UP

Nothing irreversible or data-threatening. Ranked honest mistakes:

1. **Blind 12-minor upgrade of a DB-backed app without first verifying its backup existed.** I checked Twenty's backup story in prose but never `ls`'d manifest's dump before upgrading it. Luck: `20260817_024949.sql` (prior night) exists. The mistake is real even though the outcome was fine — verify the net BEFORE the tightrope.
2. **First deploy shipped with the healthcheck still broken.** I treated "post-deploy Manifest 200" as success without looking at container health; the unhealthy state was caught only because I kept digging ~3 minutes later. A faster check of `docker ps` in the deploy loop would have caught it on deploy #1.
3. **Assumed the whisper tag change was runtime-neutral without checking the service was even enabled** — verified only now, post-hoc (it's disabled; inert). Right outcome, unverified reasoning at edit time.

## e) WHAT WE SHOULD IMPROVE (process, from this session)

1. **Pre-upgrade checklist for DB-backed containers**: verify latest dump exists + is younger than the newest data change, THEN bump. Should be scripted into a `pre-image-bump` guard.
2. **Post-deploy-check should assert container health** (`State.Health.Status == healthy` for all compose services), not just host-port HTTP. This single addition kills the entire class the 6.6.1 bug belonged to.
3. **Record reusable gotchas at fix time**, not "later": the compose-`${}`-in-healthcheck pattern belongs in AGENTS.md the moment it's root-caused.
4. **Distinguish "deployed" from "enforced"** in reporting: a workflow that isn't pushed is a draft, and status reports must say so explicitly (this one now does).
5. **Complete the pinning policy**: every image in `lib/images.nix` (and Dozzle, currently invisible) gets tag+digest, or an explicit `floating = intentional` marker so the checker's SKIP is a decision, not an accident.
6. Checker hardening: paginate tags, support non-Hub registries, shellcheck in pre-commit.

## f) NEXT — up to 50, session-scoped + noticed-along-the-way

*Image freshness (this session's thread):*
1. ~~Commit + push `image-updates.yml`, `check-image-updates.sh`, images bump — activate the daily enforcement~~ done (workflow live — daily run opens drift issues (AGENTS.md Docker images rule))
2. ~~Twenty v2.31.1: read release notes for breaking migrations; decide single-jump vs stepwise (2.7→~2.12→~2.18→2.31); verify a fresh pg_dump first; then bump~~ done (upgraded past it: v2.32 shipped by the 20-38 session (single-jump, verified))
3. Pin twenty / twenty-postgres / twenty-redis with digests; register Dozzle in `lib/images.nix` (pinned) — it currently escapes all policy
4. Checker: paginate Docker Hub tags (>100-tag repos); optional ghcr.io support via registry API
5. Add `scripts/check-image-updates.sh` to pre-commit or CI-on-push so a bad bump never merges
6. Decide digest-refresh ergonomics: `postgres:16-alpine` digest will drift ~weekly — the workflow will nag often; consider auto-PR (renovate-style) instead of issue-only
7. ~~`nixpkgs-compat`-style: first manual run of the workflow via `workflow_dispatch` after push to prove the issue-creation path works end-to-end~~ done (issue-creation path proven — the workflow keeps an open issue on Twenty being behind)

*Manifest (the actual app):*
8. Verify Autofix works self-hosted (trigger a deliberately malformed request; check `/errors/` catalog)
9. Verify existing login sessions survived 6.6.1→6.18.0 (BetterAuth secret unchanged, but confirm in browser)
10. Re-verify Ollama integration env is still honored by 6.18.0 (`OLLAMA_HOST` reaches the UI's local-model list)
11. Register FastFlowLM (`http://host.docker.internal:52625/v1`) as a custom OpenAI-compat provider
12. Product decision: point go-commit/PMA `OPENAI_BASE_URL` at Manifest for NPU→Ollama→cloud fallback chains
13. Browser-eyeball the new Homepage tile description
14. ~~Watch Gatus/Discord for alert noise from tonight's double-restart (should be none)~~ done (no alert noise from the double-restart)

*Prevention-layer gaps found:*
15. Post-deploy-check: container-health assertions (see e.2)
16. AGENTS.md gotcha: compose `${}` substitution inside healthcheck/exec strings (see e.3)
17. Consider an eval-time guard in `lib/docker.nix`: reject healthcheck/cmd strings containing unescaped `${` that isn't an intended compose var (hard — maybe just a comment + README note)
18. ~~CHANGELOG: decide whether it's maintained or dead; if dead, delete or archive to stop pretending~~ done (CHANGELOG is actively maintained (rich Unreleased section through 2026-08-18))

*Noticed but not touched (pre-existing, from TODO/journal during this session):*
19. Root fs at 91% (69G free) — deploy gate is 95%; the P0 free-space item is still open and shrinking
20. I/O pressure avg10=97% WARN during deploy (btrbk seed + corruption-recovery context) — check BFQ tiering impact while sends run
21. pocket-id SQLITE_BUSY under IO storms (00:23 onset, pre-session) — if it recurs outside deploys, worth a WAL/busy_timeout look; possibly the known corruption-read contention
22. ~~DiscordSync API still in startup backfill (SKIP in smoke) — expected, but confirm it converges~~ done (DI crash-loop fixed 2026-08-18 (0d8a58ca); API converged)
23. quickshell journal 1 error line/h WARN — cosmetic, untriaged
24. URGENT google-sync fix deployed — VERIFY the crash-loop alerts actually stopped (journal quiet since deploy)
25. The other P0s in TODO_LIST are unchanged (data-corruption recovery plan T04-T08, offsite decision, Turso decision, dnsblockd oomd exemption, scrub coverage for /data, emergency reserve re-provision, foreground scrub of `/`)

*(list intentionally ends at 25 — the remaining TODO_LIST backlog is already tracked there; duplicating it here adds nothing.)*

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **May I commit + push this session's work** (image bump, healthcheck fix, checker, workflow, docs)? The always-latest enforcement is a draft until `image-updates.yml` reaches GitHub — I don't push without your say-so.
2. **Twenty risk appetite:** jump v2.7.3 → v2.31.1 in one upgrade after changelog review, or stepwise through intermediate majors? Do you actively use Twenty day-to-day (i.e., is downtime/migration-risk acceptable in an evening window)?
3. **Manifest as the AI router:** should local consumers (go-commit, PMA, eventually Crush) route through `manifest.home.lan` with FastFlowLM+Ollama fallback tiers, or keep direct `127.0.0.1:52625/v1` connections? (Traffic-shape/product decision — both are technically fine.)
