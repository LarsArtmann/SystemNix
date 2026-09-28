# Crush-DB migration: before/after io-psi-forensics baseline + Zone 6 verdict (task 000001a0ea08e0f3d12e865cf0be9a35c141)

**Date:** 2026-09-29 00:45
**Status:** Verification complete. Verdict: the crush attribution is **eliminated** (rate-based evidence below); the second half of the ask — "confirm Zone 6 stops cycling flm post-migration" — is **REFUTED as stated**: Zone 6 keeps tripping (22–130/day) and keeps cycling flm, because the residual storm drivers are OTHER full-disk readers plus the W1/W2/W3 re-wake loop already named in `2026-09-28_22-12_fastflowlm-waker-attribution-p0-evidence.md`.
**Task:** `docs/todo/storage.md` row "Crush-DB migration: baseline + follow-through" (queue `000001a0ea08e0f3d12e865cf0be9a35c141`); migration itself converged 2026-09-18..21 (279 symlinks, `/mnt/hot/crush` 45 GiB, Samsung `/dev/nvme0n1p2`).

## 1. Baseline comparison (io-psi-forensics, rate-based)

The guard has fired `io-psi-forensics` on every Zone 6 trip since 2026-09-14 (`/var/tmp/io-psi-forensics-*`), so both sides of the comparison use the same instrument. Cgroup `io.stat` deltas between consecutive ~12-min bundle pairs give rates; cumulative `top-io-procs` gives the all-time ranking.

|                              | PRE-migration (`20260915T034939Z` → `20260915T040139Z`, 12 min) | POST-migration (`20260928T214838Z` → `20260928T220124Z`, 12.7 min) |
| ---------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------ |
| io PSI some avg60            | 41.7 → 47.1%                                                    | 66.6 → 44.4%                                                       |
| Top cgroup movers            | hermes (user@975) +15.7 GiB; **crush session scopes ~7.6 GiB total** (8 scopes, top single +2.0 GiB) | system.slice +19.4 GiB (**clickhouse +7.7, nix-daemon +7.5**); user.slice +3.3 GiB; **crush sessions +0.12 GiB total** (session-3388 +0.117, session-19629 +0.005) |
| Crush-session IO rate        | **~630 MB/min aggregate** (sessions = 5 of the top-10 movers)    | **~9 MB/min aggregate** (≈70× reduction; absent from top-10)       |
| Worst single process (cumulative since boot) | crush PID 2607864 **50.4 GB** — #3 on the box, above clickhouse | crush PIDs 16.2/15.4 GB — far down the list, counters near-frozen |

Caveat: the two windows are different hours with different workloads — this is magnitude evidence for the crush attribution, not a controlled A/B. Both windows are storm conditions.

**Device split (live, 2026-09-29 00:30):** `/mnt/hot` = `/dev/nvme0n1p2` (Samsung); crush session DBs physically live there via the symlinks. In the sampled 10 s both NVMes were idle (io_ticks Δ≈0) while PSI some avg10 read 55% — the episodic-burst class (freeze-3 doctrine), not a steady QLC grind.

**SigNoz arc** (`node_psi_io_some_avg300`, 15-min samples, 15-min step): the per-day io-PSI profile did **not** improve post-migration (09-15..18: avg 50–61%, 61–91% of samples ≥40%; 09-20..28: avg 21–75%, 20–100% ≥40%). Sustained QLC pressure continues from other drivers; note the SigNoz-scraped name is `some_avg300` (no `some_avg60` series is exported — the "node_psi_io_some_avg60 in SigNoz" phrasing in the original row has no such series to compare against).

## 2. Zone 6 / flm ledger since the migration converged (2026-09-19 onward)

| Day (Sep) | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 |
| --------- | -- | -- | -- | -- | -- | -- | -- | -- | -- | -- |
| Zone 6 trips (`action taken` lines) | 22 | 60 | 108 | 96 | 76 | 82 | 62 | 85 | 110 | 130 |

- 790 guard "stopping sockets" lines since 09-19; trip #1385 at 2026-09-29 00:18:16 (io avg60 66.56%, max disk busy 20.8%). flm is DOWN right now (restore budget 3/day exhausted; the `fflm-waker` capture loop is polling for the next wake).
- **Current-storm attribution (post-migration):** clickhouse + nix-daemon build churn dominate the measured windows; `btrfs-scrub.slice` carried 5.9 TB cumulative since boot with Δ0 inside the measured window — the guard's own stop/re-arm churn loop (btrfs-scrub is in `ioChurnUnits`) keeps re-paying scrub progress across trips, the freeze-#5/#6 amplifier doctrine.
- What the migration DID fix: crush sessions no longer put sustained seeky SQLite IO on the QLC root. What it could never fix: the other full-disk readers. Zone 6 remains a real, firing zone — its driver set just changed.

## 3. Migration completeness sweep (2026-09-29)

- 279 `.crush` symlinks live (`~/projects/**/.crush → /mnt/hot/crush/…`), matching the 2026-09-21 sweep.
- 2 real dirs remain: `legal-cases/.crush` (25 MB) and `go-daemon/.crush` (952 KB).
  - `go-daemon`: legit per-project live-writer skip (a crush process holds cwd `/home/lars/projects/go-daemon`); self-converges when that session ends.
  - `legal-cases`: **blocked by a root-owned EMPTY target** `/mnt/hot/crush/legal-cases` (root:root 0700, left by the interrupted 2026-09-18 first run) — every migrate run logs `skip legal-cases: target … already exists (manual merge needed)` and the run cannot heal it as `lars` (non-sticky parent, root-owned dir). One-liner fix (root): `sudo rmdir /mnt/hot/crush/legal-cases` → the next boot/timer/deploy run converges the 25 MB source. Harvested to `docs/todo/storage.md`.

## 4. Deployed-state finding (harvested, not acted on)

The review-fix batch for `crush-hot-db-migrate` is **already live** on the deployed generation (`nixos-system-evo-x2-26.11.20260922`): the unit script body carries the per-project live-writer guard, the depth-4 WARN, and `CRUSH_HOT_DB_DRY_RUN`; the unit carries `OnFailure=notify-failure@%n` + `WantedBy=multi-user.target`; per-project skip lines are in the journal since 2026-09-22. The "[blocked:deploy] Needs ONE `nix run .#deploy`" claims in `docs/todo/storage.md` rows (alerting / depth tripwire / per-project guard) and the "deploy-pending" sentences in `docs/services/crush.md` + AGENTS.md are stale. `extraMonitoredServices` rendering was NOT verified (lives in the system-health config, not the unit). Harvested as a [ready] verification item in `docs/todo/storage.md`; rows are left unflipped until that check lands.

## 5. Follow-ups harvested at authoring time

1. `legal-cases` root-owned empty target blocks convergence — **[blocked:user]** (root one-liner), `docs/todo/storage.md`.
2. Verify + flip the stale review-fix rows (storage.md alerting/tripwire/per-project rows + crush.md/AGENTS.md "deploy-pending" sentences), incl. one `extraMonitoredServices` rendering check — **[ready]**, `docs/todo/storage.md` + `TODO_LIST.md`.
3. Zone 6 trip lines name only PSI/disk-busy numbers; the attribution already exists in the per-trip `io-psi-forensics` bundles but must be hand-joined. A top-3 cgroup-mover line in the guard's trip message would make every future verdict a one-journal-read — **[ready]**, `TODO_LIST.md` (guard module enhancement).

Deliberately not harvested: re-running a controlled crush-attribution A/B (the magnitude evidence above is conclusive for the question asked); tq-agent-pool's 937 GB cumulative figure (one boot, mixed devices, no PSI attribution — needs its own investigation before it is an item).
