# cv rev-pin verification: the 80c2c88 attribution is FALSE (2026-11-03 ~21:15)

**Trigger:** owner pasted the `lib/flake-input-pin-audit.nix` cv allowlist row back with
the verdict "this looks like BS!". This session verified every clause of the pin
rationale against the live journal, the generation store, and the CV source tree.
**Result: the owner's instinct was right — the pin's causal story does not survive
verification.** The retraction is now written into all three .nix surfaces; the real
root cause is identified and queued upstream.

## a. Claim-by-claim verdict

| Pinned-rationale claim | Verdict | Evidence |
| --- | --- | --- |
| "80c2c88 panic-loops cv-server" | **FALSE causality** | 80c2c88 = "Boot the credentials store from an on-disk master key" (`git show 80c2c88 --stat`: touches `internal/credentials/store.go`, never the panic site). First SIGSEGV 2026-11-02 **14:06** — the 80c2c88 float did not even exist until 21:03 that evening, and first deployed 2026-11-03 16:01 (gen-974). The loop started on **cv@aa878d2** (deployed 08:12 gen-969). |
| "samber/do lazy healthcheck nil-derefs ChatstoreSessions.HealthCheck (sessions_chatstore.go:112, SIGSEGV addr=0x8)" | TRUE mechanics — but rev-independent | Journal stack 2026-11-02 14:06 names exactly `(*ChatstoreSessions).HealthCheck` → `sessions_chatstore.go:112` → `samber/do/v2 serviceLazy.healthcheck`. `git show 16a656f4:internal/agent/sessions_chatstore.go` lines 105–120 are **byte-identical to HEAD (ff1798002)**; the whole e168e6d..16a656f4 span is docs/chore commits. |
| "systemd restart-loops every ~2.5 min (live journal 2026-11-03 16:19–16:44)" | Overstated window/cadence, cherry-picked day | Real boot-`6e75c5e7` picture: 3 panics 16:22–16:24, then a **52-minute** healthy-degraded gap, one panic 17:16. The loop has actually been running since 2026-11-02 (228 SIGSEGVs on deed9c84 alone) — see next row. |
| "16a656f4 is the gen-973 rev proven GREEN for 18 h on boot deed9c84" | **FALSE — the pinned rev crash-looped that whole boot** | gen-973 (2026-11-02 17:34) ExecStart = `…-cv-16a656f/bin/cv` ✓ (it IS the gen-973 rev), but `journalctl -u cv-server -b -2 --until 16:01` = **233 scheduled restarts / 228 SIGSEGVs** (first 22:15:25, ~2–3/hour all night). Post-rollback, 16a656f4 panicked identically at 18:52/19:08/19:24 (pc=`0x20d215c`, same pc as the Nov-02 aa878d2 panics; pc=`0x20d335c` on the 80c2c88 builds — same site, shifted offsets). |
| vendorHash shim: bPvMOBEz is 16a656f4's proven hash | TRUE, and the rollback's only real value | gen-972/973/975 all carry store path `…rras5xm…-cv-16a656f` (deterministic rebuild). The pin = build-hash stability, **not a fix**. |

## b. Generation → boot → binary map (the decisive reconstruction)

| gen (mtime) | cv ExecStart | boot / window |
| --- | --- | --- |
| 969/970 (11-02 08:12 / 12:51) | `cv-aa878d2` | long boot `2a642827`-predecessor (11-01 01:11 → 11-02 14:03) — **onset here** |
| 971 (11-02 14:32) | `cv-aa878d2` | boot `2a642827` 14:03→14:42 |
| 972/973 (11-02 16:51 / 17:34) | `cv-16a656f` | boot deed9c84 22:09→11-03 16:16 — "green 18 h" boot, actually 228 panics |
| 974 (11-03 16:01) | `cv-80c2c88` | deployed 15 min before freeze-41; crash-looped on boots `6e75c5e7` + `49e157e0` |
| 975 (11-03 18:50) | `cv-16a656f` (rollback) | current boot — **panicked identically 18:52/19:08/19:24; still 3 SIGSEGVs in the 21:00 hour** |

Onset detail: restart counter already **17** at the first SIGSEGV (14:06) — counter resets
on the 08:12 cv restart, so ~17 failures (exit-1 rehydration/startup cycles) accumulated
08:12→14:06 on aa878d2, i.e. the state trigger crossed ~midday 11-02 while the binary sat
unchanged.

## c. Root cause (code-level, verified in source)

1. `career-pipeline/eventstore/sqlite_eventstore.go:65` — `sqliteOperationTimeout = 5 * time.Second`
   applied per-op, including `All()` (`:405`): `SELECT … FROM pipeline_events ORDER BY timestamp`
   **full scan + full materialization** under a 5 s deadline.
2. Continuous crm-sync writes grew `pipeline_events` past what 5 s can scan (crash cycles
   read ~300 MB from disk per cycle) → **every** boot rehydration fails:
   `career-pipeline: query all events: context deadline exceeded`, `attempts=3` →
   `boot rehydration FAILED — in-memory state is incomplete`.
3. The chatstore lazy service never resolves → nil receiver → samber/do healthcheck probe
   (`serviceLazy.healthcheck`, raceWithTimeout) derefs it → SIGSEGV `addr=0x8`
   (`sessions_chatstore.go:112`). Systemd restarts; the loop repeats indefinitely
   (~2–4/hour, around the clock, independent of load — it fires at 04:00 too).
4. Contributing pressure: `GOMEMLIMIT=768MiB` (cv.nix) vs full-events materialization —
   observed 739.1M memory peak on a panic cycle.

**Why the pin could never work:** the panic site + timeout are byte-identical in every rev
e168e6d..HEAD. "Green 18 h" was never measured — it was inferred from "the box didn't
freeze", while cv-server crash-looped through the whole window unnoticed.

## d. Live state at authoring (2026-11-03 21:17)

cv-server **active/running** (pid 1760918, unit correctly probed via
`cv_2dserver_2eservice` — an earlier `cv_2dservice_2eservice` mis-escape read a phantom
"inactive/dead" unit, caught and corrected this session) on the pinned gen-975 build —
alternating panic/degraded: 3 SIGSEGVs since 21:00, CRM sync working in the windows
between panics, intermittent `find opportunities` timeouts against crm :8091.

## e. Surfaces corrected (post-state)

1. `lib/flake-input-pin-audit.nix` cv row — retracted causal claim; pin re-justified as
   build-hash stability only; same LIFT condition.
2. `flake.nix` cv comment — same retraction + root cause + onset evidence.
3. `modules/nixos/services/cv.nix` ROLLBACK paragraph — "80c2c88 panic-loops /
   16a656f4 gen-973-green" retracted; bPvMOBEz provenance kept (verified true).
4. `docs/services/cv.md` incident playbook — new SIGSEGV-loop entry (signature, root
   cause, rev-independence, live-state probe).
5. `docs/todo/upstream.md` — new `[blocked:push]` fix row (nil-guard + chunked/raised
   rehydration; `query event stream after version` chunking API already exists at
   sqlite_eventstore.go:395).
6. `TODO_LIST.md` — queue one-liner for the same row (edited both, no drift).
7. `CHANGELOG.md` — correction entry.

## f. Follow-ups (self-harvested at authoring)

- **Harvested:** the upstream cv fix row (docs/todo/upstream.md + TODO_LIST.md) — the pin
  LIFT condition depends on it.
- **Deliberately NOT harvested:** (a) crm :8091 intermittent slowness — observed only in
  cv-backfill windows, no SystemNix-side action identified yet, left pending owner signal;
  (b) cv `GOMEMLIMIT`/`MemoryMax` retune — subsumed by the upstream chunked-rehydration
  fix; retuning now would only mask the deadline failure.

## g. Verification commands (reproducible)

```
journalctl -u cv-server --since "2026-11-02" | grep -c '\[signal SIGSEGV'   # per-day: cut -c1-11 | sort | uniq -c
journalctl -u cv-server -b -2 --no-pager --until "2026-11-03 16:01" | grep -c 'Scheduled restart'  # 233
for g in 969 970 972 973 974 975; do grep -h '^ExecStart=' /nix/var/nix/profiles/system-$g-link/etc/systemd/system/cv-server.service; done
cd ~/projects/CV && git show 16a656f4:internal/agent/sessions_chatstore.go | sed -n '105,120p'  # == HEAD
rg -n 'sqliteOperationTimeout' ~/projects/CV/career-pipeline/eventstore/sqlite_eventstore.go   # 5 * time.Second
```
