# Fast-TODO Wave 1 — Session Status & Self-Review

**Window:** 2026-10-26 ~08:45 → 10:38 CEST · **Head at close:** `db2290766` (parallel session's opencloud commit on top of my `d5cd73e98`, which is pushed) · **Instance:** crush / glm-5.3-flash

## a) FULLY DONE

1. **Full TODO inventory + work-sorted ranking** — `TODO_LIST.md` (1,403 open rows) + all 10 `docs/todo/*.md` libraries read end-to-end; exact counts (822 `[ready]`, 51 `[decision]`, 45 `[watch]`, 70 blocked) and an XS→XL work-sorted table with a Pareto read (4 blockers = the 1%) delivered in chat; per-surface counts grep-verified (`grep -c` runs).
2. **Wave-1 execution: 19 queue/library rows closed or retagged, 4 code/config fixes, 380M reclaimed.** Details in `docs/planning/2026-10-26_09-11_SUPERB-fast-todo-wave1.md` §2:
   - Fixes landed: nvme-health-monitor fail-loud default (flip-trap literal gone), flake.nix toolchain comment rev-cited, `backup.nix` + `data-corruption-repair.sh` tmp-crush-test references dropped, `/data/tmp-crush-test` (380M) trashed after zero-reference verification.
   - Premise catches (the wave's highest value): `vm.overcommit_memory=1` was **superseded** (boot.nix deliberately `mkForce 0` — applying would have reverted a conscious decision); catalog-inventory bash:127 was **already fixed 2026-10-23** (never-ticked re-fire class); hermes dup-key file is perm-denied → retag `[blocked:user]` with behavior-preserving recipe; btrfs-compression.prom owner **found** (`btrfs-compsize.timer`, 6h + admission-gate deferral); status-report.sh verdict (unit-state only); task.reprioritized dedupe already single-lane; niri-wrapped.nix drift already healed; nix-fmt scoping already answered in AGENTS.md.
   - Hygiene: tmp-reclaim row retagged `[blocked:deploy]`→`[blocked:user]` (retires the 8-fire loop), SUPERB plan rows S-0702/S-1758 flipped done, CHANGELOG empty-workspace entry, AGENTS.md full-line-match rule.
3. **Verification battery, all green:** `nix eval` evo-x2 toplevel rc=0 (nvme assertion holds under the by-id override) · eval stderr has ZERO "non-existent input" warnings (row 609's override confirmed already resolved) · `nix fmt --` over changed .nix: 0 changed · full pre-commit battery green (gitleaks/statix/deadnix/treefmt/shellcheck/flake check) · `check-todo-system.sh` run standalone post-edit: **"OK: TODO queue/library structure clean"** (only the standing 131-unharvested WARN).
4. **Commit + push** — `d5cd73e98` pathspec-scoped to my 12 files with parallel-session attribution note; pushed `706659d05..d5cd73e98`.
5. **Shared-tree discipline held:** parallel session's 7 in-flight files untouched in the commit; their append-only harvest rows co-committed inside shared TODO files WITH attribution named in the message.

## b) PARTIALLY DONE

1. **Queue↔library twin sync** — the wave ticked 14 queue rows but I initially synced only 3 library twins. Healed in the close-out pass (storage.md tmp-crush-test/tmp-bench twins, services.md overcommit twin, upstream.md dedupe note) — but storage.md was edited while a parallel session holds it dirty (co-mingle risk accepted + attributed); pipeline.md twins (rows 648/1386/1419/1491) remain **open by documented exception**: the parallel session is actively holding an uncommitted `docs/todo/pipeline.md`, and per the commit-cadence rule I chose not to interleave. One follow-up session must tick those 4 twins.
2. **Wave scope vs. plan file** — the plan file's T6–T11 (wave 2: M-tier fixtures, PG-shadow-split gate, the 4 Pareto blockers) are queued but not executed; wave 1 covered only the XS/S tier by design.

## c) NOT STARTED (deliberately out of this session's scope)

- The four Pareto blockers (ghostty-scope IO root-cause, tq-pool harvest rescan, InboxClean upstream query cost, `deploy-when-quiescent.sh` productization).
- Wave 2 M-tier: PG-shadow-split pre-deploy gate + `.migrate-state` forensics, hermes WAL fixture, system-health freshness composites, per-endpoint gatus collector, §17 user.slice leg.
- All L/XL programs (sev1 chronic latch, system-health decomposition, config diet, offsite Borg, /data repair, CI restoration) — unchanged, tracked.
- No deploy was attempted (3 recent freezes + live storms; deploys are PSI-gated and today is not the day).

## d) TOTALLY FUCKED UP

Nothing landed broken — but two self-caught process failures, reported honestly:

1. **I created queue↔library drift myself** by ticking 14 queue rows while syncing only 3 twins — the exact "edit both" rule this repo enforces. Self-caught in the close-out pass; healed same session (see b.1).
2. **Scratch-file location slip:** `eval-warn.txt` was created in the repo root instead of `~/.cache/<topic>/` (AGENTS /tmp-volatility rule); caught and trashed within minutes. Also invoked `check-todo-system.sh` via `python3` once (it is bash) — one wasted command, self-corrected.

## e) WHAT WE SHOULD IMPROVE

1. **Tick-and-twin must be ONE atomic operation** — a small helper (or check-todo-system parity leg, row 907) would have prevented the drift I created; the parity leg is still prose-only.
2. **Premise-check FIRST is now proven ROI:** 2 of 6 "obvious one-liners" were false. Queue rows should carry a `premise-checked:` stamp field (row 906 territory) so dispatches stop paying for stale claims.
3. **Never-ticked re-fire class keeps recurring** (catalog PATH fixed 2026-10-23, ticked only today) — the prune-done-todos + harvest pipeline should auto-tick surfaces cited as DONE in-tree; row 680's first `--apply` exercise would help.
4. **Foreign-dirty shared files need a convention** for "tick now vs wait" — today I documented exceptions; a `[when:quiescent]` tag (queued already, stability row) generalizes it.
5. Scratch artifacts → `~/.cache/` habit needs enforcing on my side (e.2).

## f) NEXT 50 (prioritized; §f self-harvest note: every item below is ALREADY tracked in TODO_LIST/docs/todo at the cited row — no new rows minted this report, per the "deliberately not re-harvested because already queued" record)

| # | Item | Row |
|---|------|-----|
| 1 | Ghostty interactive-scope IO storm root-cause (blocked 3+ deploys) | monitoring.md:167 |
| 2 | tq-agent-pool harvest full-rescan skip-cursor (sustained a whole freeze) | stability.md:161 |
| 3 | InboxClean dashboard query cost — upstream cache/LIMIT | upstream.md:15 |
| 4 | Productize `scripts/deploy-when-quiescent.sh` (3 lost batteries) | queue:1525 |
| 5 | PG-cluster-shadow-split pre-deploy gate (data-loss class) | storage.md:13 |
| 6 | `.migrate-state` wave-6 forensics | storage.md:14 |
| 7 | Tick pipeline.md twins for rows 648/1386/1419/1491 (this report's own follow-up) | this report §b.1 |
| 8 | ai-meter deploy chain (key-perm fix → VM → deploy → live smoke) | ai-stack.md:39 |
| 9 | Deploy + live-verify caddy edge-tracing :4318 fix | monitoring.md:174 |
| 10 | Deploy the 2026-10-20/21 stability batch + verify | queue:174 |
| 11 | sev1 chronic-storm latch implementation | stability.md:101 |
| 12 | system-health `extraCollectors` decomposition (byte-stable names) | queue:520 |
| 13 | configuration.nix diet 1522→≤600 | queue:521 |
| 14 | signoz family → per-service dirs | queue:522 |
| 15 | hermes-migrate WAL-branch VM fixture | queue:879 |
| 16 | system-health freshness-composite fixtures | monitoring.md:131 |
| 17 | Per-endpoint gatus failure NAMES collector | monitoring.md:163 |
| 18 | §17 user.slice sweep leg | monitoring.md:95 |
| 19 | Phantom-metric detector (frozen-gauge class) | monitoring.md:148 |
| 20 | paperless consume-dir staleness/depth probe | monitoring.md:146 |
| 21 | Better-model bench (abliterated Qwen3 family) | ai-stack.md:19 |
| 22 | Vulkan llama.cpp experiment (owner-gated soak) | ai-stack.md:20 |
| 23 | catalog VM test (`test-architecture-catalog.nix`) | queue:379 |
| 24 | drive-paperless journal/walk scalability pass | queue:367 |
| 25 | Offsite-borg VM rehearsal + §13/§16 fixture family | storage.md:97 |
| 26 | Boot-mirror path-trigger VM-test runtime leg | storage.md:166 |
| 27 | Gitleaks Slack rule + fixture | security.md:31 |
| 28 | Pre-deploy §17 negative-path fixture selftest | stability.md:27 |
| 29 | `check_user_service` dead code (wire or delete) | monitoring.md:13 |
| 30 | Textfile-collector exit-0/empty-value class audit (~20 collectors) | monitoring.md:15 |
| 31 | Zero-python allowlist gate | queue:1324 |
| 32 | First `--apply` of `scripts/prune-done-todos.sh` | queue:680 |
| 33 | Pairing-WARN recount pass (41 left: 13 wrong-link + 28 no-entry) | queue:678 |
| 34 | Unharvested §f sweep (131 and rising) | queue:50 |
| 35 | `gate:sudo` pre-flight + structured gate fields in harvest | queue:956 |
| 36 | R19: locate tq harvest impl, map 5 hardening rules | queue:681 |
| 37 | Doc-counts eval gate (README asserts vs nix-eval truth) | queue:1505 |
| 38 | `docs/status/archived/` manifest README (1,457 files) | queue:1506 |
| 39 | Catalog-DNS eval warning: 21 subdomains, decide per name | queue:1420 |
| 40 | Batch `client.timeout` 15s across all /metrics gatus checks | monitoring.md:161 |
| 41 | Alert-description disambiguation pass (gatus-config.nix) | monitoring.md:162 |
| 42 | `system_service_cpu_percent` all-zeros phantom fix + canary | monitoring.md:124 |
| 43 | Paperless llmindex age-gauge query fix (false RAG-dark) | monitoring.md:142 |
| 44 | Storm-aware ghostty scope IOWeight cap decision | monitoring.md:167 |
| 45 | monitor365 volume batch deploy at PSI-calm + rendered spot-check | queue:341 |
| 46 | Hot-user-caches tmp migration follow-ups (parallel session owns) | storage.md:182 |
| 47 | monitor365 upstream mainProgram + Binder-error fix | upstream.md:200/553 |
| 48 | `ssh-suspend-guard` inhibitor verify | desktop.md:27 |
| 49 | KeePassXC managed-storage key names vs primary source | desktop.md:55 |
| 50 | Drain the XS/S tail (~300 rows, ~15 h batched) | 2026-10-26 inventory |

## g) Questions only the owner can answer

1. **overcommit posture:** boot.nix deliberately forces `vm.overcommit_memory=0` ("overrides Redis's 1"). I superseded the =1 row on the strength of that comment — is 0 still the intended steady state (Redis's boot warning stays accepted noise), or do you want the flip to 1 as a deliberate change?
2. **hermes config.yaml:** the dup `provider` key (edge vs zai) needs one sudo line — delete the EARLIER `provider: edge` line (behavior-preserving, zai keeps serving). Authorize that in your next owner terminal, or do you want to decide edge-vs-zai intent first?
3. **Wave-2 order:** the PG-shadow-split pre-deploy gate (data-loss class) vs the four Pareto blockers (deploy/freeze throughput) — which do you want first, and is a PSI-calm deploy window expected soon that should reorder everything else?
