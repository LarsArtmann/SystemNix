# Three-Check Fix Session — CV render, llama-rag re-enable, FastFlowLM socket (2026-10-10 night)

Session window: 2026-10-10 ~03:46 → 08:1x CEST. Trigger: post-deploy check summary
showing `SKIP llama.cpp RAG`, `FAIL FastFlowLM :52625`, `FAIL CV browser render smoke`.

## Verdict

| Check              | Outcome                                                                                        |
| ------------------ | ---------------------------------------------------------------------------------------------- |
| CV render smoke    | **FIXED (was storm starvation, not a regression)** — re-run exit 0, 4/4 DOM renders + PDF PASS |
| llama-rag (RAG)    | **FIXED IN TREE, activation deploy-gated** — enable flip + watermark-wiring fix landed, eval-verified |
| FastFlowLM :52625  | **ROOT-CAUSED, fix rides the same deploy** — guard-sacrifice + restore-cap, socket re-arms on switch |

## CV — "pages load but do not RENDER"

The 03:11 FAIL line came from `scripts/post-deploy-check.sh`'s CV leg
(report_fail phrasing), while `/tmp/.smoke-cv-render.log` now contains an
all-PASS run: the failing invocation's log was overwritten by a later passing
run. Re-verification at 03:57 (and again at close): `bun
~/projects/CV/scripts/render-smoke.ts http://127.0.0.1:8098` → **exit 0**, all
four rendered-DOM checks (cv, de/cv, admin, pipeline) + PDF export PASS. The
pages render; the one WARN is the by-design anonymous 401 on the gated
pipeline API (locked banner is the keyed-deployment design). The 03:1x failure
was chromium starving during the zone-6 IO storm (guard trips #2532-#2539 that
night at ~10-min cadence, io some avg60 up to 55%). No CV-repo or harness
change made; the storm-classification follow-up already exists as a queue row
("Storm-aware vHost probe verdict", docs/todo/pipeline.md).

## llama-rag — SKIP (units absent) → re-enabled in tree

- **Decision:** owner demand ("fix all 3") ended the 2026-09-18 config-disable.
  Same byte-identical pinned llama.cpp 0.3.0 build (`nixpkgs-llama-rag`), now
  on kernel 7.2.9 — three kernels since the spin was last reproduced (suspect
  set is kernel/GPU-state, upstream of llama.cpp).
- **The documented soak gate could NOT run:** `scripts/llama-rag-soak.sh` is
  root+quiet-IO-gated (`sudo systemd-run` sandbox); the agent shell cannot
  sudo, and no quiet-IO window existed all night (chronic fleet batteries).
  The REAL deployed units' own post-activation watch (≥15 min CPU-time deltas
  + functional probes) is the empirical spin gate in its place — RE-DISABLE
  (`llama-rag.enable = false`) immediately on the freeze-#5 signature (CPU
  climbing while /health stays 503 past the vocab-warning line).
- **Eval-blocking defect found and fixed at root:** enabling surfaced
  `memory-watermark-audit` assertion failure — `llama-embeddings` (and
  `llama-reranker`) merged bare `MemoryMax = cfg.memoryMax` OUTSIDE
  `harden{}`, leaving harden's phantom 512M-derived throttle watermark under a
  2G ceiling (the llama-chat 2026-10-08 class, frozen into the audit). Fix:
  `MemoryMax` now flows INTO `harden{}` on both server units (watermark = 80%
  of ceiling), bare `MemoryMax` removed from `commonServiceConfig`.
  Reference: `lib/systemd.nix` arg contract, `llama-chat.nix:210`.
- **Commits:** flip `85e936ae`, watermark fix `8a3a027f` (both daemon-batched
  heuristic commits; content verified via `git show` — the pathspec commit
  attempt was blocked by the pre-commit TODO-system gate on 96 unrelated
  unharvested-report debt, so the standalone lint legs were run manually:
  parse + full toplevel eval GREEN post-fix, drv
  `y0yqgda8n2snrbpwqjpks0x6ij71cgwy`).
- **Surfaces updated:** runbook DARK bullet (docs/services/llama-rag.md),
  ai-stack soak row (now the ratification step), inline config comment.
- Reranker leg stays dropped (plan A13).

## FastFlowLM :52625 — socket dead → root cause + fix path

Journal chain: guard trips #2532-#2535 (zone 6, ~10-min cadence, real disk
busy corroboration) → 3 same-day auto-restores burned by 02:45 (`restore
capped (3 restores today >= 3)`) → trip #2534 02:49:36 stopped
`fastflowlm.socket` + backend → restore-capped message keeps the socket DOWN
by design ("Manual restart once memory is healthy"). Every :52625 consumer
since 02:49 gets ECONNREFUSED (PMA falls back to heuristic commits — by
design, degraded not broken).

The fix is NOT a code change: `fastflowlm.socket` is `sockets.target`-wanted,
so the deploy switch re-arms it; the post-deploy smoke's `/v1/models` leg then
cold-loads the 21.6 GB model (budget 480 s) and proves the endpoint. Manual
equivalent: `sudo systemctl start fastflowlm.socket` in a calm window.

No module change made — the sacrifice/restore-cap behavior is deliberate
(churn protection); its known sharpening proposals are owner-blocked rows
(docs/todo/stability.md: zone-6 action split, flm zone-6 exemption, tq IO
discipline).

## Why the deploy did not land in-session

`scripts/deploy.sh` gates: memory PSI some avg10 ≥20 blocks; IO PSI some
avg10 ≥20 blocks (phantom-corroborated); ≥1 guard trip in the last 60 min
blocks unless `DEPLOY_FORCE_PRESSURE=1` (documented override). The night's
agent fleet (owner SSH crush fleet + tq pool batteries: go test/link,
buildflow, cargo/duckdb, nix builds reading the USB buildcache SSD at ~85 MB/s
= 98% util) kept global IO PSI at 38-69% with only ~2-minute dips (observed
floor 17.1% once at 04:39, then 21.1-21.5 kisses). Three hunt loops (~3.5 h,
down to 40-45 s cadence, deploy chained to first qualifying window) found no
sub-20 dip with a usable margin. Memory PSI stayed 0-10% all night (no memory
zone ever fired; the waves were pure IO/CPU stacking); a 07:2x transient wave
(load 373, io some avg60 89%) matched the freeze-#19/#20 wave SHAPE but
recovered within minutes — the box is riding exactly the episodic pattern the
trip-recency gate exists for.

## §f Follow-ups (self-harvest)

1. **Deploy the staged fixes at the first io-avg10 <20 window**:
   `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (pressure gates still enforce
   the dip; the override only clears the trip-recency deadlock). Then verify:
   rag `/health` 200 + `/v1/embeddings` 1024-dim + 15-min CPU-time soak on
   `llama-embeddings`; flm socket up + `/v1/models` cold-load; full
   post-deploy-check rerun. → TODO_LIST + docs/todo/services.md
2. **Ratify the rag re-enable with the root soak** at the next quiet window:
   `sudo ./scripts/llama-rag-soak.sh …` (row updated in docs/todo/ai-stack.md).
3. **flm functional cold-load verify** if the deploy smoke was storm-eaten:
   re-run `scripts/post-deploy-check.sh` when io avg60 <30 (the cold load
   re-trips zone 6 above that). → covered by follow-up 1's verify list.
