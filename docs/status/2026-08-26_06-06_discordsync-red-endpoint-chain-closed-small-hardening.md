# Status Report: Follow-up Bug Batch — DiscordSync RED-Endpoint Chain Closed, Small Hardening Landed (system-723)

**Session:** 2026-08-25 ~03:30 → 2026-08-26 06:06 · **Task:** "More bugs to fix?" (continuation of the 2026-08-2x harvest) · **Deployed:** system-722 → system-723

## What was done

### a) Fully done (verified)

1. **DiscordSync input bump — the permanently-RED "Legacy DLQ Empty" gatus endpoint is GREEN** (three consecutive `success=true` cycles in the gatus journal, 05:55–06:05). The chain, step by step:
   - **Master unreachable**: upstream `87c8c0d3` requires `go >= 1.26.6`; nixpkgs has 1.26.5 + `GOTOOLCHAIN=local` (same class as file-and-image-renamer). Binary-searched upstream history: `aa56b582` (2026-08-21 20:50) is the LAST 1.26.5-compatible tree and CARRIES the legacy-DLQ metric (`418c3223`, 2026-08-18).
   - **Upstream vendorHash was stale**: a from-scratch build of the `go-modules` FOD at `aa56b582` deterministically yields `sha256-NHqx…`, not the committed `sha256-33Np…` (old hash resolves only via cached substitutes). Verified the mismatch is invariant across follows topologies (identical `.drv` path with/without `go-nix-helpers`+`nixpkgs` follows — follows were NOT the discriminator).
   - **Upstream fixes (branch `nix/aa56b582-vendorhash`, pushed)**: `7919aef4` vendorHash correction; `2862b613` NEW gauge `discordsync_projection_dlq_legacy_unchanged` (1 = depth stable since previous scrape, 0 = grew) with two tests, registered in main.go. Tests green; `go build ./...` green.
   - **SystemNix**: input rev-pinned to `2862b613` (both `go-nix-helpers` and `nixpkgs` deliberately un-followed — bank-sync/qmd precedents, comment documents why); gatus check renamed **"Legacy DLQ Stable"** asserting the growth flag in the anchored form (HELP embeds `<metric> 1` — the phantom-green trap; `gatus-pattern-lint` built clean); `KNOWN_NEW_METRICS`: `legacy_depth` retired (live at 11,404), `legacy_unchanged` added for the one-deploy window.
   - **Why the flag, not depth==0**: production permanently carries 11,404 frozen legacy dead letters until the M09 event-store replay — a depth==0 condition fires Discord every 5 min forever. The flag alerts only on NEW legacy dead letters (the Jul 3-6 silent-loss class regressing).
2. **`gatus-pattern-lint` 4th trap: lowercase HTTP methods** (`flake.nix`) — `method = "[a-z]+"` rejected with the papdashboard-405 incident cited. Mutation-tested: fails on `method = "post"`, passes the tree.
3. **`validate-gomemlimit.sh` service list corrected** — `signoz-collector:8888` removed (OTel-native collector has NO `go_memstats`; live-verified — its heap check could never do anything). `discordsync:8085` confirmed HAS go_memstats and stays.
4. **buildcache `x-systemd.device-timeout` 10s → 2s** — every D-state probe against the dead automount stalled its caller the full timeout and faked IO-PSI saturation (2026-08-24 crash3 class). Healthy enumerated devices answer instantly.
5. **attic.nix bootstrap probe dedupe** — the doubled inline python3 readiness check is now one `atticd_ready()` function. `tests/test-attic.nix` VM test green (9/9).
6. **crush-daily 0-sessions CLOSED as benign** (user question from the attic report): Aug 23 had genuinely ZERO crush sessions machine-wide (Aug 22: 94, Aug 24: 8 — queried `/api/reports` per day). The transient `/api/reports/2026-08-24` 404 was pre-03:30-generation timing, not a bug. The WARN spam (`query project db failed … unable to open database file (14)`) is the no-`.crush`-dir-per-project case — noisy but harmless.
7. **quickshell WARN triaged**: zero error lines in the journal over the last 24h/3h — the smoke WARN source is transient/stale; no action (desktop WARN row already in TODO_LIST).

### b) Partially done

- **Deploy history this session**: 2 failed deploys (hash mismatch at master-pin; hash mismatch at aa56b582-with-follows) before the upstream fix unblocked; system-722 (7919aef4 + all small fixes) and system-723 (2862b613 + gatus flip) landed clean. Post-deploy smoke both times: 60 PASS / 9 FAIL (the established DAS-cascade baseline) / 5 SKIP / 4 WARN.
- **`internal/db` upstream test failure** (`TestIOBaseline_DiskWriteBytes`): proven PRE-EXISTING via stash (fails at clean `7919aef4` too — environmental IO baseline on this loaded machine), NOT caused by the gauge change. Not fixed, not filed.

### c) Not started (deliberately)

- CHANGELOG/TODO_LIST entries for THIS batch (noted below — the exact docs-health failure mode the first session harvested about).
- KNOWN_NEW_METRICS retirement of `discordsync_projection_dlq_legacy_unchanged` — by design: one more pre-deploy run must confirm it green, then remove (comment documents the condition).
- Upstream master rebase of the branch when nixpkgs ships go ≥ 1.26.6 (flake.nix comment documents the runbook).

### d) Mistakes

1. **`| tail -N && echo OK` produced two FALSE "build green" claims** — pipe exit codes masked FOD failures; an "output path" printed by a substituted-not-built derivation compounded it. This repo's own gotchas (SIGPIPE, pipefail classes) should have rung a bell. Definitive verdicts came only from bare `nix build <drv>` runs.
2. **Follows-topology churn before evidence**: changed follows twice (two ~40s deploy cycles + relocks) before noticing the failing `.drv` path was IDENTICAL across topologies — one `derivation show`/drv-hash comparison up front would have proven follows irrelevant immediately.
3. Both mistakes cost ~4 extra build cycles on an already-loaded machine.

### e) Improvements (process)

- **FOD mismatch protocol**, distilled: (1) read `specified:` vs `got:`; (2) rebuild the bare `.drv` to prove determinism; (3) compare `.drv` PATHS across variants — same path = the variable you changed is irrelevant; (4) only then change topology. (1)+(2)+(3) here would have skipped both wrong turns.
- **Piping build output** through anything for verdicts is banned; `nix build` exit status + explicit error grep only.

### f) Next things (prioritized)

1. USER: DAS physical reseat + power-cycle (blocks: 9 baseline smoke FAILs, bank-sync metrics verification, btrbk-data catch-up, attic bootstrap happy path)
2. After next deploy's green pre-deploy run: remove `discordsync_projection_dlq_legacy_unchanged` from KNOWN_NEW_METRICS
3. CHANGELOG Unreleased entries for this batch + TODO rows (vendorHash-fix pattern, IO-baseline upstream flake, master-rebase-when-go-1.26.6)
4. Upstream: file/fix `TestIOBaseline_DiskWriteBytes` environmental flake (DiscordSync repo)
5. Upstream DiscordSync: 3 mirror-outage issues still unfiled (TODO_LIST carries them); consider merging the branch into master once the go floor is satisfiable
6. Turso quota decision (TODO_LIST P0 since 08-16) — the journal still shows `quota_exceeded` + circuit breaker hourly backoff

### g) Questions (max 3)

1. **Turso plan**: keep local-only (then remove sync env/keys), re-auth, or upgrade? (The quota log line recurs hourly.)
2. **The frozen 11,404**: schedule the M09 event-store replay sometime (would allow returning to true depth==0 semantics), or accept the growth-flag monitoring as permanent?
3. **DAS reseat timing**: any window planned? (Everything in f.1 queues behind it.)

## Verification chain

upstream: `go test ./internal/observability -run LegacyDLQ` green ×2 tests · `go build ./...` green · stash-proof of pre-existing db flake · branch pushed (`7919aef4`, `2862b613`) → SystemNix: `nix flake check --no-build` all-passed · `gatus-pattern-lint` built clean (incl. mutation test) · attic VM test 9/9 · deploys system-722 + system-723 (exit 0, generation trail printed) → live: both gauges on `:8085/metrics` (`legacy_depth 11404`, `legacy_unchanged 1`) · gatus journal: old red endpoint deleted, "Legacy DLQ Stable" `success=true` ×3 consecutive cycles · smoke 60/9/5/4 = DAS baseline.
