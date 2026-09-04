# PMA Commit Blackout — Full Fix (backoff, fallback, local LLM, monitoring)

**Date:** 2026-09-02 · **Session:** blackout postmortem + end-to-end fix · **Status:** deployed

## Incident

Every PMA auto-commit failed from **2026-08-22 to 2026-09-02** (11 days, ~3,800
failed commits, 910 on the last day alone) with `429 rate_limit_error (2056)`
("Token Plan usage limit reached" — minimax billing state, not a bad key).
Service liveness, CPU, and memory checks stayed GREEN the entire time: nothing
anywhere watched commit OUTCOMES. The 2026-09-02 12:36 ecosystem toolchain
sweep (the 82-file BuildFlow bump and siblings) sat UNCOMMITTED in the PMA
repo for the same reason — the repo's own committer was the thing that was
dead.

## Root causes (four, stacked)

1. **Single provider death**: minimax's Token Plan exhausted 2026-08-22. The
   `pma-env` sops template injected `MINIMAX_API_KEY` (shared with hermes),
   making minimax the only working provider.
2. **The local provider was unreachable by construction**: SystemNix sets
   `OPENAI_BASE_URL=http://127.0.0.1:52625/v1` (FastFlowLM), but PMA's
   flake.lock pinned go-commit at `7321133` (2026-08-11) — six days BEFORE
   `22f0e4c` (v0.8.0) taught `DefaultChainFromEnv` to read `OPENAI_BASE_URL`.
   The env vars sat in the daemon's `/proc/<pid>/environ` while the built
   binary sent its OpenAI requests to api.openai.com with key `local`
   (eternal 401). Both chain providers dead → every commit failed.
3. **No fallback, no real backoff**: go-commit fails the whole commit when
   message generation fails (its retry middleware exists but is wired in
   nowhere); PMA's flat 5-minute per-project cooldown retried every dirty
   project for 11 days straight.
4. **No alerting**: no metric, no gatus check, no journal watched commit
   failures.

## Fixes

### Upstream (PMA `7b9533d5`, pushed)

- go-commit flake input `7321133` → `22f0e4c` + vendorHash refresh — the
  provider chain now races the local FastFlowLM (`OPENAI_BASE_URL` honored).
- **Heuristic fallback** (`committer.Config.HeuristicFallback`, on for the
  daemon): when message generation fails with `errorfamily.Code(err) ==
  "commit.generate"`, retry `Execute` with a deterministic message
  (`chore: auto-commit N changed file(s) (heuristic) on <branch>`).
  Generation runs BEFORE staging in go-commit's `Execute`, so the failed
  attempt staged nothing — the retry is side-effect-free. `Result.Fallback`
  is set and the service logs WARN `committed via heuristic fallback`.
- **Escalating cooldown**: per-project failure cooldown doubles per
  consecutive failure (5m → 10m → … → 4h cap), resets on first success.
- Tests: blackout regression (total provider outage → commit lands, flagged,
  clean tree), opt-out keeps strict behavior, escalation curve + streak
  bookkeeping.

### SystemNix (deployed)

- `pma-env` drops `MINIMAX_API_KEY` (empty template kept; comment warns
  against re-adding external provider keys without a fallback plan).
- `system-health` collector section: `system_pma_commit_scrape_errors`,
  `system_pma_commit_failures_1h` (+`_over_threshold`, ≥3/h = sustained
  blackout class), `system_pma_commit_heuristic_fallbacks_24h`
  (+`_over_threshold`, ≥20/day = LLM path dead while commits keep landing).
  Journal scans follow the forgejo discipline: `--since` bound, `timeout 30`,
  journalctl exit ≤1 valid, ≥2/timeout fails visible.
- Gatus "PMA Commit Health" (anchored `\n` patterns, fail-closed on metric
  absence) with Discord alerting.
- Pre-deploy §10: the three gauges rode the `KNOWN_NEW_METRICS` one-deploy
  loan; the paperless `pat(*oidc/pocket-id*)` body-pattern joined the
  lowercase body-field exclusions (`oidc`) so it stops parsing as a metric.

## Side findings (fixed or flagged)

- **`system_health.prom` whole-file poisoning** (fixed by the parallel
  mail-relay session in `360e9a03` before it blocked this deploy): the
  forgejo journal-scan failure path (timeout 124 under IO pressure) emitted
  `system_forgejo_mirror_errors_30m ` with an EMPTY value — invalid
  exposition syntax made node_exporter drop the ENTIRE file (all 38
  `system_*` metrics dark, §10 fails 37 checks). The scan pair is now gated
  on its own emptiness.
- **gobwas/glob v0.2.3→v1.0.0 cascade** (NOT mine, left to the sweep
  session): the uncommitted ecosystem dep sweep breaks `glob.Glob` call
  sites in PMA (`pkg/coreutils/pathutil/wildcard.go` — 2-line `*glob.Pattern`
  fix left uncommitted in the working tree, only valid against the swept
  go.mod) and in the published project-discovery-sdk v0.21.0. My commits
  deliberately exclude the sweep: master = HEAD + blackout fix only, built
  and verified green via a clean worktree (glob v0.2.3 everywhere).
- **signoz-coverage.prom duplicate series** (`file-and-image-renamer`
  registered twice) sets `node_textfile_scrape_error 1` — pre-existing,
  owned by the signoz-coverage registry, flagged here for that session.
- First flm-bound commits after an idle hour may ride the heuristic fallback
  once (30s HTTP timeout vs 2-5min socket cold load) — self-heals as the
  socket warms; sustained fallbacks alert instead of failing.

## Verification

- Worktree build of PMA (HEAD + fix + fresh vendorHash) green; binary
  strings confirm `OPENAI_BASE_URL` + `committed via heuristic fallback`.
- `go test ./pma-daemon/... ` green (committer + daemon packages).
- evo-x2 toplevel build green; deploy passed all gates (after the pressure
  window and the concurrent mail-relay session's index lock cleared).
- Post-deploy: backlog commits resumed, 429s gone, metrics live, gatus green.
