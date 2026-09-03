# CV Closeout + CI Unblocked — Session Status (2026-09-03 23:58)

Resume of `docs/status/2026-09-03_15-58_cv-vendorhash-chain-repaired-self-review.md` under the
"keep going until everything works" directive. Re-verified everything before acting — the world
had moved twice again.

## a) What this session found on resume (re-verify doctrine paid off again)

| Handoff said | Reality at 23:38 |
| --- | --- |
| Lock at `4ac7ca7b`, deploy blocked on PSI | Lock at `6b635cca` (moved twice: `d08abc7` @ 18:07 deploy, then `6b635cca` @ 22:00 re-lock + switch by a parallel session) |
| Pipeline-store check red BY DESIGN | **GREEN** — Gatus journal 23:46:09: `CV Pipeline Store Health success=true errors=0 duration=15ms` |
| `/health/live` stamp = 4ac7ca7 expected | Live = `6b635cc` (= current lock rev — deployed and current) |
| CI dark since ≥ 09-02 20:04 | Dark for **120+ runs** (no green nix-check in the last 120); systemic, not fresh |

## b) CV integration — CLOSED (live-verified)

- `/health/live`: `{"status":"pass","version":"6b635cc"}`, uptime 1h39m.
- Full `/health` body contains `"pipeline-store":{"name":"pipeline-store","status":"healthy"` —
  the Gatus pattern contract verified against the LIVE server (closes self-review f.2 without
  needing the git diff).
- PDF export: 200 in 0.5s (`%PDF-1.7`). Gatus "CV PDF Export" flapped 8×10.001s-timeout under
  IO PSI bursts, recovered (170ms) — **true positive of box pathology, check left as designed**.
- Funnel: scan 18:23 discovered **253 jobs, 0 errors**; `funnelStale:false` on every green read.
- Wrapper audit (f.3): upstream `d08abc7..6b635cca` touches ZERO nixos-module options (only the
  vendorHash line + code/assets) — nothing to re-audit; runtime compatibility proven by the 22:00
  switch + smoke.
- TODO_LIST row flipped to `[x]` with evidence.

## c) "CV Funnel Freshness" false pages — root-caused + fixed (needs deploy)

The check failed 4×/12h across BOTH binaries with the alert "funnel stale — no new job
discovered in 26h+" while the funnel was demonstrably fresh. Truth: `/api/pipeline/sse-stats`
scans the WHOLE event log per call (`funnelStaleness(h.events.All(ctx), …)`); under IO PSI it
took **2.4–12s** — blowing `[RESPONSE_TIME] < 2000` (condition failures, `errors=0`) and the
default 10s client timeout (`errors=1`), and the alert text then lied about the cause. Fix
(`gatus-config.nix`): dropped the latency condition, `client.timeout = "30s"`, liveness still
guarded by `[STATUS] == 200`. **Upstream observation for the CV repo (not a bug):** caching the
newest-discovery age instead of a per-call full scan would make the endpoint cheap.

## d) CI darkness — root-caused + half-fixed (1 user step remains)

Chain: `85f7c43a` (2026-07-15) mass-converted ~30 git+ssh inputs to `github:` tarball URLs "for
CI compatibility" (correct while repos were public) → repos went private (~2026-08) → every
`github:`-type lock node 404s in CI because the job-scoped `GITHUB_TOKEN` only reads THIS repo.
**32 private repos** are pinned that way (root + subtree nodes at follows-unreachable depth —
deploy keys structurally cannot fix them). The 2026-08-29 session added the branching-flow
deploy key + secret + ssh-agent wiring but never flipped the URL — the half-finished fix.

Fix shipped here: `nix-check.yml`, `go-deps-audit.yml`, `nixpkgs-compat.yml` now use
`access-tokens = github.com=${{ secrets.NIX_GITHUB_RO_TOKEN || secrets.GITHUB_TOKEN }}`
(zero regression until the secret exists). **Mechanism proven**: local nix fetches the same
private tarballs via the user's gh OAuth token in `~/.config/nix/nix.conf` `access-tokens`.

**USER STEP (the only remaining blocker):** fine-grained PAT (Contents: Read-only, all repos)
→ `gh secret set NIX_GITHUB_RO_TOKEN --repo LarsArtmann/SystemNix`. Then nix-check (incl.
test-cv VM), go-deps-audit, nixpkgs-compat go green without touching flake.lock.

## e) Secret-history-scan red — triaged, NOT silenced (correctly failing)

Every run fails on the documented 2026-08-18 residues. Still-LIVE keys in public history:
Gemini `AIzaSyAV…LU4k` (console project `453958689374`) and Context7 `ctx7sk-a5b19…` — both
user rotations pending. Allowlisting live keys would silence real alarms; the workflow stays
red until both are dead, then a digest-based allowlist (never plaintext values) can restore
signal. Also noted: the full Context7 key lives in AGENTS.md's own purge-runbook blobs, and a
`leak-canary.tmp.md` fixture.

## f) Honest ledger

- The 15:58 report's "CI covers it on push" deferrals were no-ops — but so was my plan to
  "diagnose the branching-flow 404": the deployed-key wiring existing WITHOUT the URL flip
  misled the handoff's hypothesis (renamed repo / rewritten rev). The rev exists; the repo is
  simply private and tokenless in CI.
- treefmt CI failures are the LIVE parallel session's in-flight files
  (`post-deploy-check.sh`, `test-inboxclean-paperless.nix`, mtimes 23:48) — deliberately not
  raced; their session formats them.
- The btop TODO row was clobbered by an edit of mine for ~60s — restored immediately, verified.

## g) Not done + why

1. **test-cv VM run** — IO PSI 64–70% all day (box awaits user reboot for the NPU wedge;
   load 45–59). Stability doctrine: no heavy IO additions. CI alternative needs the PAT above.
2. **Deploy of the freshness-check fix** — same PSI gate; next deploy train carries it
   (tonight's trains ran at similar PSI, but the gate + doctrine decide, not me).
3. **min_day_rate, reboot, deploy-trigger ownership** — owner decisions, unchanged from 15:58 §g.
