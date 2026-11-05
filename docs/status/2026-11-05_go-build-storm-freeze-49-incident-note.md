# Incident Note: Go-Build Storm + Freeze #49 (2026-11-05) — canonical narrative

**Created:** 2026-11-06 (pareto-plan T8 merge; authored by the resume session, tombstone `crush-glm53-resume-2244`)
**Supersedes-as-index (ANNOTATE, not rewrite):** the five per-phase reports — 19-50 storm diagnosis, 21-00 WDT autopsy, 21-03 brutal self-review, 21-43 advisory + boot-reset observation, 22-21 relocation execution (22-27 close-out stays the execution-phase record). Each keeps its detail; THIS file is the single timeline + root-cause index future readers should hit first.

## Timeline (all 2026-11-05 CET)

| Time | Event |
|------|-------|
| ≤19:44 | Storm at peak: load 1248–1292, io PSI ~99% — 8 concurrent golangci-lint runs across 5 repos (ChastityAPI 48m, index 44m, go-auto-upgrade 41m, go-bilanz 7m, Zlota44 2m) + 5 go linkers, under TWO toolchains (go1.27.2 + go1.27.3) |
| 19:50 | Diagnosis report: structural multipliers named — all Go caches on one DRAM-less USB SSD (ext4, 85% full), GOTOOLCHAIN=auto floor-fork (4 toolchains downloaded into GOMODCACHE: go1.27.0–1.27.3), GOEXPERIMENT/-race key splits, gopls defeating Go's LRU trim; live profile `go` = 1.26.8 below every 1.27 floor |
| 20:02 | Deploy attempt blocked by storm gate (real-IO-storm refusal) |
| 20:36:40 | **Freeze #49**: boot `5819f35ddbd34e58b5c9697df1313f04` died mid-run — 2m40s journal gap, zero shutdown markers (hard freeze, not clean reboot); confirmed independently by the 21-03 session |
| 20:39 | Reboot; recovery |
| 21:00–21:03 | WDT autopsy + self-review: freeze class = IO-storm memory pressure; the 20:02 blocked deploy was the RIGHT call (forcing it would have been the crash-#3 precursor class) |
| 21:43 | Advisory: relocate Go caches to Samsung hot tier (fits: 126G needed vs 306G free); boot-reset observation recorded |
| 22:11 | Auto-commit daemon commits an UNPROVEN flake.lock float (~66 inputs) — tree-wide eval gate goes RED |
| 22:18 | Deploy attempt: float gate aborts in 3s (exit 12) |
| 22:21–22:30 | Relocation executed in-tree (disko subvols + automounts + env repoints + direnv-guard fix from owner challenge); close-out report; pareto plan authored |
| 23:15 | Deploy attempt: float-register proof RED — `monitor365-prepared-source` FOD dies `rm: Cargo.lock: Permission denied` |
| 23:5x–00:2x | Resume session: root cause found + empirically reproduced — `cp -r <store-src> $out/<dir>` propagates 0555/0444 store modes, later `rm`/`rm -rf` die EACCES; upstream fix committed (monitor365 `164e159a4`, **push pending — owner gate**); SystemNix lock pinned back to proven `ebfa4056`; float-register proof re-launched |

## Root causes (three independent failures stacked)

1. **The storm (chronic):** every Go build/lint on the box shared one DRAM-less USB ext4 (85% full) while up to 8 lint runs × 2 toolchains forked the cache keys. Fix in flight = Samsung hot-tier relocation (parked riders awaiting deploy) + post-deploy single-toolchain convergence (profile go_1_27 = 1.27.3 ≥ every floor → auto stops downloading → one cache key).
2. **Freeze #49 (acute):** IO-storm memory pressure class; the remaining unowned lever is builder-capacity containment (owner declined PSI gate; cap shape = decision gate D3).
3. **The eval lockout (2026-11-05 22:11→):** unproven float wave + a genuinely broken upstream FOD at the floated monitor365 rev; recovery = pin-back to last-proven + upstream chmod fix (committed, unpushed).

## Open ends (owner gates + queued)

- **monitor365 `164e159a4` push** — after push: `nix flake lock --update-input monitor365` + float-register re-proof lifts the pin-back (drop condition recorded in the float commit).
- **Phase B prepare** (`sudo bash scripts/migrate-go-caches-hot.sh prepare`) — owner sudo, recommended overnight.
- **The deploy** (relocation + 6 parked riders) — after float green + Phase B.
- **Builder-cap containment** (D3) — freezes recur without it.
- Benchmark (Samsung vs USB, armed harness) + post-deploy battery per the pareto plan (`docs/planning/2026-11-05_22-30_SUPERB-go-cache-unblock-cutover-pareto-plan.md`).

**Merge pointers added in-place to:** 19-50, 21-00, 21-03, 21-43, 22-21 (single header line each; no content rewritten).
