# SUPERB Masterplan v2 — Execution Session 2 Status

**Instance:** `superb-masterplan-v2-exec-1` · **Plan:** `docs/planning/2026-10-23_15-00_SUPERB-backlog-masterplan-v2.md` (EXECUTING marker stamped 16:06 CEST, rode `8a16b14e9` after a daemon race) · **Window:** 2026-10-23 ~15:35–17:30 CEST · **HEAD at close:** `76a14d432`

## a) Session summary

Executed v2 sprints **T-001 through T-006** (all P0, top-down): two already-satisfied closes, one forensic verification, one attribution correction, two full H2 implementations with regression checks. Tree verified FULLY GREEN twice (`nix flake check --no-build` all-checks-passed ~15:50 and ~17:20) — **the 07:09 eval-red era is over** (U0's fix landed by the lock-wave session at 11:44, `62e5da76a`; verified here by full check + toplevel eval). Census: 1,758 open rows at close (1,760 − 6 closed + 1 new + parallel drift). IO storm persisted all session (PSI some avg300 64%, load 86–121); 30+ concurrent crush processes; the daemon raced every commit (see §d).

## b) Sprints closed

| Sprint | Row | Verdict | Landing |
|---|---|---|---|
| T-001 | ai-stack:38 llama-chat start budget | **Already-satisfied** — 15min timeout (`c10d80f7db` 10-08) + 400-retry probe citing the exact incident (`62c58457e8` 10-12) + `after=multi-user` deploy-train unblock (`e412b30d5b` 10-17); busctl live: `active`, TimeoutStartUSec=900s | `ad594acef` |
| T-002 | monitoring:31 flm crash-trigger composite alert | **Implemented** — 2 new journal walks (`commit.generate` deadline-exceeded × `code=dumped`) + 3 metrics (`system_pma_generate_timeouts_24h`, `system_flm_coredumps_24h`, `system_flm_crash_trigger_pair_24h`) + PMA Commit Health anchored condition + `checks.flm-crash-trigger-pair` VM test (real walk_journal vs stubbed journalctl incl. exit-1/timeout-124; 4-cell pair arithmetic; wiring tripwires) | `a856c3569` + daemon `02c07c82d`/`727fb6616` |
| T-003 | monitoring:128 storm-night btrbk sends | **Verified LANDED** — pool-side received-subvol timestamps (window journal vacuumed): root `@.20261011T2300`+`T2327`+`20261012T2300`, hermes both nights, forgejo 0540 both days, inboxclean + cv both days; empty `backups/data` = the standing btrbk-data EIO repair gate (2026-09-11+), NOT a storm casualty | `a771ae28c` |
| T-004 | monitoring:148 memcg OOM collector | **Implemented** — `collectMemcgOom` section (kernel `CONSTRAINT_MEMCG` raw capture, parallel walk, fail-closed) + total/per-memcg series (`\xNN` label escaping = census class, parser grounded in preserved freeze-#28 evidence) + "Memcg OOM Collector" Gatus check + `checks.memcg-oom-collector` (promtool accept/reject legs) | daemon `5da631e86` + close `6fa485c69` |
| T-005 | monitoring:154 ee085387 heat attribution | **Strong-form claim DISPROVEN** — the death spiral was a three-way stack: nsfw ROCm ensemble active (0.8→13.6G, GPU +24°C = the ROCm signature) × mid-window flm cold load (0→33.5G; nvme1 45→67°C) × nix builds (→17.8G); k10temp 52→100°C across 23:15→00:15; **crm-server exonerated** (flat 0.1G). Byproduct: `system_service_cpu_percent` is a standing all-zeros phantom → new P0 row queued | `7a4701f2c` + daemon `0923993a6` |
| T-006 | monitoring:156 truncated-journal corroboration | **Loss REFUTED** — 54,067 readable entries through the crash instant (00:40:44); the truncated `.journal~` broke only the boot-id INDEX (`-b ee085387…` fails) + direct `--file` reads. T-005's "journal is GONE" wording corrected on both surfaces | `76a14d432` |

## c) Verification record

- `nix flake check --no-build`: **all checks passed** at ~15:50 (pre-T-002) and ~17:20 (post-lock-convergence). Toplevel eval green at 15:36 (`nixos-system-evo-x2-26.11.20261020.02c087f.drv`).
- New checks built AND ran green: `checks.x86_64-linux.flm-crash-trigger-pair`, `checks.x86_64-linux.memcg-oom-collector`, `checks.x86_64-linux.gatus-config-parse` (twice).
- Daemon-swept `.nix` files got their bypassed pre-commit legs re-run standalone: deadnix clean, statix clean (errfmt, no findings), treefmt `--fail-on-change` 0-changed (scoped file args worked).
- Live probes: busctl (llama-chat ActiveState/TimeoutStartUSec), journalctl (btrbk units, boot coverage, kernel OOM format — all zero-mutation reads), python3 urllib → localhost:8080 SigNoz query_range (read-only queries).

## d) Foreign-session interaction log (shared tree)

1. **16:41 lock regression**: daemon batch `5da631e86` carried MY T-004 files + a foreign flake.lock delta moving `nixpkgs_4` BACKWARD (`02c087f`→`fe13242`, −4 days) → crowdsec `settings.acquisitions` vanished → full check red ~30 min. The lock-wave session converged it in the 17:06 delta (`3949c3d87`, 117 lock lines) — crowdsec evals green again at 17:2x, full check green. Not my surface; both red and green states documented in T-004's row close-out.
2. **Three partial-commit daemon races**: my pathspec commits landed 2-of-5, 2-of-5, 1-of-3 files; the rest rode heuristic batches (`02c07c82d`, `0923993a6`). All contents verified via `git show --stat` + content greps; bypassed lint legs re-run standalone (§c). No amends (foreign files in every batch).
3. A parallel session's r8125 commit (`8a16b14e9`) swept my plan marker (+1 line) — marker content carries its own attribution; guard satisfied.
4. Their kernel-modules CHANGELOG entry + monitor365 mainProgram fix landed alongside my doc edits (pathspec commits kept everything separable).

## e) Lessons (harvested inline; see §f)

1. **Edit-tool newline discipline**: an edit whose old/new strings differ only by a trailing newline GLUES the next line (`else` + echo on one line — T-004's shell syntax error; caught by the collector's own build, fixed in one round). The build gate bit correctly.
2. **writeShellApplication probe tests**: SC1091 (dynamic source of sliced artifacts) and SC1012 (printf '\n' inside bash -c strings) are recurring legitimate excludes for artifact-slice probes — now encoded in both new tests.
3. **SigNoz `/api/v1/query` silently ignores start/end** (returns instant) — historical windows need `/api/v1/query_range`; a collapsing range query looks like phantom zeros (bit once during T-005).
4. **`-b <id>` failure ≠ evidence loss** — boot index vs entry stream are independently damaged; timestamp re-query before declaring loss (bit T-005, corrected in T-006, doctrine added to docs/agents/monitoring.md).

## f) Self-harvest status (TODO rules)

- **system_service_cpu_percent all-zeros phantom** → QUEUED [ready] P0, monitoring.md + TODO_LIST.md mirror (done this session, pre-report).
- **Journal boot-index/query_range doctrines** → docs/agents/monitoring.md collector-hygiene section (done).
- **T-002/T-004 go live with the next deploy** — pre-deploy §10 will assert the new metrics; noted in both rows + CHANGELOG entries. Deliberately NOT harvested as new rows (the deploy train owns them via U1).
- Nothing else from this session's findings remains unharvested.

## g) Next steps (for the next execution session)

1. **T-007** (monitoring:198 Gatus boot/restart alert-storm + flap suppression) — next P0 sprint; the `.nix` lane is open (tree green).
2. **Deploy train when PSI calms** — carries T-002 + T-004 (+ the parallel sessions' kernel-module shims, DNS unification, forgejo-runner migration); post-deploy: §10 metric asserts + `storage_collector_crash_orphans_total` from session 1's T-001.
3. **Census re-baseline** before the next plan dispatch (1,758 at close; parallel sessions drift it continuously).
4. The lock-wave session owns: crowdsec render tests (their `5e3c05033`), the forgejo-runner row tick (their migration, verified green by this session).

*Report authored by instance `superb-masterplan-v2-exec-1`; marker flips to EXECUTED in the same commit as this report.*
