# FastFlowLM waker attribution + P0 host-health evidence (SUPERB plan M1/M2/M5)

**Date:** 2026-09-28 22:12
**Status:** Evidence complete (journal forensics + unit verification + coredump triage). Live PID-level sampler armed at `~/.local/share/cv-verify/fastflowlm-waker/` (journal follow + 1s `ss -tnp`) for the next restore window. **Persistent capture (23:15, survives agent sessions):** user unit `fflm-waker-capture.service` runs the 1s `ss` sampler into `~/.local/share/cv-verify/fastflowlm-waker/ss-persistent.log` — on the next FastFlowLM wake, correlate the ESTABLISHED port with the connecting PID (root `ss -tnp` sees foreign-uid owners). Stop with `systemctl --user stop fflm-waker-capture` once the waker is PID-named.
**Source plan:** CV `docs/planning/2026-09-28_18-18_SUPERB-HOST-HEALTH-RESTORATION.md` (M1, M2, M5.2, M5.3).

## Verdict (one paragraph)

The "unknown consumer re-waking FastFlowLM" is **not one mystery client — it is three named, by-design consumers plus the guard's own restore**, and the trips keeping the socket down are **all Zone 6 (sustained I/O PSI with disk 97–100% busy while MemAvailable stays healthy at 52–76%)**, not memory exhaustion. The 21.6 GB model cold-load is itself one of the "stacked full-disk readers" that re-trips Zone 6 within ~2 min of every restore. Containment (M2) is **already deployed and verified** — no module change needed. The coredumps are triaged: quickshell = aborted `/tmp` test scripts; flm = upstream NPU-driver heap corruption.

## 1. The named wakers (M1)

| #  | Waker                                                                                                                                                                                                                                                                                                                         | Evidence               | Class                                                                                                            |
| -- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------------- |
| W1 | **PapDashboard NPU insight enricher** — default `llmBaseUrl` → `http://127.0.0.1:52625/v1` (`modules/nixos/services/papdashboard.nix` header + `PapDashboard/internal/insight/llm.go:49`); module docs explicitly note "FastFlowLM cold-loads 2-5 min on first insight request (socket activation on :52625 wakes the model)" | by design, still wired | alert-driven self-reference: guard trips generate alerts → ingest → enricher → cold load                         |
| W2 | **Deploy smoke** — `scripts/post-deploy-check.sh:304` curls `:52625/v1/models` with `--max-time 480`, deliberately cold-loads AND pins the model ("the sole functional gate"); a capped-down socket makes this leg FAIL → **deploy exit 3** (the 2026-09-27 21:27 red verdict, now fully explained)                           | by design              | every deploy = 21.6 GB read + pin                                                                                |
| W3 | **The guard's own restore** — `maxRestoresPerDay = 3`; restore re-arms the socket, then the first queued/retrying client (W1/W2) connects within seconds                                                                                                                                                                      | by design              | 2026-09-28 02:12: restore #64 → backend start + client proxy connection same second → Zone 6 re-trip 2 min later |

Trip ledger (from `/var/lib/memory-emergency-guard/`): **1374 trips all-time, 66 restores**, restore budget exhausted (3/3) since ≥21:47 today — the socket stays DOWN until a human restarts it (intended anti-churn behavior).

## 2. The trip zones are I/O, not memory (reframes the whole plan)

Every trip today (00:00–03:15 at ~10-min cadence, then 21:57) logs:
`I/O PSI some avg60=41–88% sustained (max disk busy 97–100%, MemAvailable=52–76% — the crash #3 class: stacked full-disk readers livelocking the scheduler while memory looks healthy)`.

Named full-disk readers:

- **btrfs scrub** started 00:00 (3 scrub starts by 04:12 — `/` and `/data`)
- **nightly btrbk** send window
- **flm's own cold-load** (10–21.6 GB reads per attempt; 2026-09-28 02:12: "10G read from disk, 27.8G memory peak" in 1m49s)
- **agent build storms** (2026-09-28 21:57 trip: 3× golangci-lint + 2× buildflow + nix builds → load 184)

Consequence: memory budgets cannot fix Zone 6; the levers are (a) deploy/restart in quiet windows, (b) fewer cold-loads (W1/W2 policy, owner O2), (c) I/O scheduling of scrub/btrbk vs flm load.

## 3. M2 containment: already deployed, verified — NO module change

The RUNNING unit (`/etc/systemd/system/fastflowlm.service`) carries everything the plan asked for (landed 2026-08-21, `fastflowlm.nix:357-366`): `MemoryMax=40G`, `MemoryHigh=32G`, `MemorySwapMax=20G`, `OOMScoreAdjust=300`, exponential restart backoff (60s→15min, 5 steps), `TimeoutStartSec=3min`. Idle TTL 1h/5min checker is sane. **Editing these values now would be churn without evidence** — closed as verify-only.

## 4. Coredump triage (M5.2/M5.3)

- **flm 765 MB core (2026-09-27 04:58): glibc heap-corruption abort inside `libxrt_driver_xdna.so.2`** (`malloc_printerr` → `_int_free_chunk` → xdna driver frames) — upstream AMD XRT userspace bug triggered during model load under pressure; same class as the Sep 22 SIGSEGV/SIGABRT trio (cores already vacuumed). Not fixable from systemd; record as known-issue, owner may report upstream.
- **quickshell SIGABRT pairs: NOT a production crash loop** — command line is `quickshell -p /tmp/qs-feature-test.qml` (deliberate feature-test invocations; Qt fatal message → `qAbort`). The "crash-loop pairs aligned with deploy-pressure windows" hypothesis from the status report is **debunked**. No action beyond optionally guarding the test script.
- 2× `imagetoraster` SIGSEGV (2026-09-28 15:00, cups-filters printing) — one-off, ignore.
- 958 MB total; vacuum is OWNER row F5.1 (`coredumpctl vacuum-time=2days`) — the flm core is the bulk.

## 5. What this changes in the SUPERB plan

- **M2 → DONE (verify-only, zero diff).** F2.3/F2.4 collapse into this memo.
- **M3 (owner restart)** must happen in a quiet window: no scrub/btrbk running, build storms idle, AND ≥1 restore available (else the guard re-caps). The 1s sampler stays armed for PID-level confirmation of W1/W2 at that moment.
- **M7 (deploy → exit 0)** green condition is now precise: flm socket UP + Zone 6 quiet — otherwise the W2 smoke leg fails by design. Alternative (owner decision): teach the smoke to SKIP the flm leg while the guard holds the socket down (a "capped ≠ broken" verdict) — that is a policy change to `post-deploy-check.sh`, gated on O2, NOT part of M7 as planned.
- **O2 (owner question) is sharpened**: the PapDashboard enricher wake-loop (W1) is the standing "consumer" — accept the churn (restores are capped anyway) or repoint/disable the enricher. Also: flm v1.0.2 + xdna driver heap bug means some cold-loads are doomed regardless of policy → an upstream report is the durable fix.
