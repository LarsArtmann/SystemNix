# Handoff execution: owner answers, DiscordSync push, full ladder verify, calm-box on gen-959

**Date:** 2026-10-29 05:45 CET (session 22:54 → 05:45)
**Session type:** handoff execution (4th-generation arc: 18-50 → 19-01 → 22-03 → 22-30 → this)
**Prior report in the arc:** [22-30](2026-10-28_22-30_do-wave-brutal-self-review-status.md) (its §g answers landed 22:56 and are annotated there)
**Deploy context:** gen-959 was deployed by the PARALLEL session at 22:55:42 (owner-command reproduced — see [23-35](2026-10-28_23-35_lock-float-deploy-fix-and-resolver-unit-loss.md)); this session verified it rather than firing it. Overnight sessions then added **gen-960** (02:32 — monitor365 heal + the templ-components/go-health LIFT executed, root pins + follows + allowlist rows dropped, keep-going proof green) and **gen-961** (03:38, anchored — see [04-04](2026-10-29_04-04_monitor365-outage-census-honesty-pin-lift.md)); the calm-box in §e ran against the LIVE **gen-961**, the newest deployed state. Same boot throughout (10-28 00:42 — no reboot).

---

## a) Owner answers (22:56) and their execution

| Question (22-30 §g) | Answer | Execution |
|---|---|---|
| wevisone-spike 19 G | **trash-all** | `trash ~/projects/wevisone-spike` 22:58; source gone; ~12 G (zstd-compressed) in `~/.local/share/Trash` awaiting the owner trash-empty window (root 70%, 211 G free — no pressure). storage.md row + plan A2 struck. |
| DiscordSync push grant | **yes** | See §b. |
| Deploy window | "postladder" | MOOT — the parallel session deployed gen-959 at 22:55:42 (before the question was asked); owner-command-driven per the 23-35 report. This session verified instead (§c). |

## b) DiscordSync templ-components v1.24.0 lockstep bump — PUSHED 79952c46

- The repo's own `scripts/sync-flake-pins.sh` (go.mod is canonical) moved **6 pins**: templ-components `2126f3c8` → **v1.24.0 tag commit `29f71a51`** (the LIFT condition), **go-health → v0.8.1** (resolves upstream.md's DoServiceName row), plus go-cqrs-lite/httputil/go-output/go-health-dashboard (drifted siblings the script caught).
- `vendorHash.nix` re-measured (`1O/b94…` → **`gYJcV6Ol…`**) — and note: the hash MOVED, which is counter-evidence to the "FOD hash invariance" row's absolutist reading (annotated in upstream.md).
- Proof: `nix build .#discordsync` RC=0, `nix build .#cqrs-lint` RC=0, `check-flake-pins.sh` all-OK. The daemon swept flake.nix+lock mid-flight (23:01:15, exactly my 2 files) → amend-forward per daemon-race policy → pushed `921d5fc4..79952c46`.
- SystemNix-side consequence: **both consumers satisfied the templ-components LIFT condition by 23:04** (crush-daily 955ddb2 + DiscordSync 79952c46). **The LIFT was then EXECUTED by the overnight session** (gen-960, 02:32): root inputs + all 11 follows lines + both allowlist rows removed, registry regenerated, keep-going proof green, zero FOD re-stales — upstream.md row ticked [x] by that session; the CHANGELOG's top entry owns the narrative.

## c) gen-959 verification (deploy was not mine to fire)

- Anchor: `readlink /run/current-system` == `system-959-link` (newest by NUMBER) ✓, config-revision `0c97ef04f` == tree HEAD ✓.
- **cv@dd201874b live**: PID 233541, `/proc/exe` → `/nix/store/zw0r8z1q…-cv-dd20187`, /health 200 every 2s, uptime matches the 22:55 activation. `overall_status=warn` (45 checks) **predates the deploy** (old process showed the same) — degraded, not regressed; **no 5165e44 rollback**.
- Lock forensics en route: root lock node `templ-components` resolves to `_7` (29f71a51) matching `expected-locks.nix` → lock-float gate GREEN; the plain-named `templ-components` node (2126f3c8/v1.23.0) belongs to consumers whose follows are declared in flake.nix but not yet expressed in the lock — transitional pre-LIFT state, coherent for eval and for gen-959's build (overlay shims carried the FODs).

## d) The btrbk ladder — first full night on the projects subvol: ALL GREEN

| Instance | Verdict | Evidence |
|---|---|---|
| root (23:00) | **GREEN via SELF-HEAL** | 10-27's run FAILED at 23:00:11 (crisis night) leaving an unstamped orphan `@.20261027T2300` (no received-uuid → unmatchable). Tonight btrbk deleted it and full re-seeded: Created 23:00:01, Received UUID `d0deba59…` stamped at stream end, **Finished 00:50:31** (1h50m, 322.4 G written). Tonight's `@.20261028T2300` + both `@home-hermes` increments (10-27, 10-28) landed on top. Chain fully healed. |
| projects (23:10) | **GREEN — first nightly** | Incremental receive `projects.20261028T2310` (vs 18:03 manual seed), 1m18s, Finished 23:11:18; `projects_subvol_backup_fresh 1`, 341 top-level entries. |
| data (23:30) | **DELIBERATE fast-fail** | The 2026-09-11 EIO repair gate (no `/data/.repair-done`): local snapshot `data.20261028T2330` + retention prune ran, unit fast-fails BY DESIGN as the canary. Owner-gated repair unchanged. |
| pool (23:45) | **GREEN** | Deactivated successfully 23:45:06. |
| forgejo (05:40) | **GREEN — heal PROVEN** | The timer itself (not the manual re-seed) re-received the chain incrementally: `forgejo.20261028T1340` + `T2140` + `20261029T0540`, Deactivated successfully 05:41:00. Closes the stray-receive heal (services.md triage row updated). |

Operational note: the root self-heal streamed 322 G to the HDD pool through the ladder window — expected cost of re-seeding an orphaned chain; the pool has ~13 TiB free.

## e) Calm-box post-deploy re-run — DONE 05:44, against the LIVE gen-961

**168 PASS / 3 FAIL (all previous-baseline-matched, advisory) / 4 SKIP / 12 WARN / STORM-SUSPECT 0.**

- The 2 STORM-SUSPECTs converted (the handoff's goal) — the storm engine (tq-agent-pool) stayed paused through the night and the baseline settled.
- Residual FAILs are the known §18 classes: tq-agent-pool 409 % CPU sustained; llama-embeddings 1216 lines/min + node-exporter 389 lines/min journal rate. All already carry rows (§18 sanity redesign, node-exporter journal rate).
- Memory-throttle WARNs are cumulative-since-start counters (forgejo 750k, papdashboard 430k, cv 86k) — standing advisories, not tonight's regression.

## f) Rows touched this session (both surfaces, no drift)

- storage.md: wevisone [x] (trash executed, owner-ruled); plan A2 struck.
- upstream.md: templ-components LIFT row rewritten [ready] (both pushes recorded); go-health row [x] (folded into the LIFT ceremony); FOD-invariance row annotated (hash is not invariant — moved on the v1.24.0 bump).
- TODO_LIST.md + pipeline.md: calm-box row [x] with the full ladder verdict; deploy row's FIRE half annotated as parallel-session work.
- services.md: failed-units triage row — btrbk-forgejo x2 leg RESOLVED (05:41 proof).

## g) Carried / follow-ups

- ~~templ-components + go-health LIFT~~ — **EXECUTED overnight** (gen-960, see §b); row ticked [x] by the executing session.
- **CV shim-drop-at-upstream-bake** — unchanged (the cv strand flaps per float; the 23-35 session already re-pinned cv's FOD to `MeDzARcT…`).
- §18 sanity redesign; node-exporter journal rate; tq-agent-pool CPU — pre-existing rows, evidenced again by tonight's calm-box.
- DiscordSync golden-snapshot tz fix (921d5fc4) rides upstream; nothing SystemNix-side pending from it.

**No open questions for the owner.** The arc's original mission (deploy fix + projects-subvol cutover + first-night proof) is closed end-to-end.
