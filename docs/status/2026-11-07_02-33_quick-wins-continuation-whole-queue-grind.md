# Quick Wins continuation: the whole-queue grind — 33 rows, class 9, the first --apply prune

**Written:** 2026-11-07 02:33 CET (`date`), boot 01:06, gen 984 live.
**Session shape:** continuation of the 00-15/01-15 quick-wins session after the owner's "GET SHIT DONE — THE WHOLE TODO LIST" directive. Executed against a THREE-session-contended tree (deploy-unblock 01-20, freeze-51 triage 01-25/01-36, crush-v100 verify 01-24 all minting rows and daemon commits concurrently) on a box at sustained IO PSI 22-50 (avg10) — every heavy item stayed PSI-gated by design.
**Repo state at start:** HEAD `0a5249508`, tree clean. At close: all work committed (mix of pathspec commits `0d0913e30` + daemon sweeps).

---

## a) FULLY DONE (33 queue rows closed, ticked with evidence on both surfaces where twins exist)

### Verification/superseded closures (premise-checked, live-probed)
1. **pkce provisioner semantics** — source-verified create-OR-update (`pocket-id.nix:252-275`: existing clients take `api_put` with `clientAttrs`, which inherits `pkceEnabled` at :257). No manual flip needed; remainder (live canary) retagged `[blocked:deploy]` on both surfaces.
2. **nix-gate-removal deploy row — STALE since 10-17**: live-proven (plain ELF `nix`, an entire session of unmolested evals at PSI 30-50, no NIX_HEAVY_GATE_FORCE).
3. **hermes re-pin row — STALE**: lock at `6b21d056` (last hermes move 06:28 Nov 6) is check-proven green by the 11:35 full `flake check --all-systems` (fc-113500.log).
4. **NNP/sudo investigation — ANSWERED**: deliberate v0.100.0 change; probed sudo rc=0 in THIS session's own tool shell, AGENTS.md exception clause widened with the datapoint (a parallel session had already added the nested-yolo clause; mine extends it to own-shell scope).
5. **kill_pid row — premise half-wrong**: `lib/process.sh` HAS the helper (finder's grep missed lib/); only bench-hot-file.sh was broken (now sources it).
6. **dead-server-JSONL row — already landed** (script's failure path builds event JSONL; row predates the fix).
7. **btrbk excludes — landed as the 2026-11-03 nested-subvol doctrine** (snapshots.nix:385-392 + exclude-rot guard).
8. **bak-subvol stale-reference check — CLEAN** (tree-wide grep: zero references; owner runbook safe).
9. **Trash-in-snapshot-set — ANSWERED config-side**: YES inside `@` (bounded by 3d retention; 10-08-dated trash outlived every pin).
10. **[blocked:deploy] audit — 30/30 genuine**, zero sudo-only mismatches, zero retags needed.

### Code landed (eval-green, rides next deploy)
11. **systemd-shape-audit class 9**: ~170 documented [Service]-section keys + `Limit*` prefix family rejected inside `unitConfig`; `allowUnitConfigServiceKeys` escape; header/docs/negative-test legs. Verified BOTH directions: evo-x2 toplevel eval green (assertions forced) AND `CASES=shapeaudit` 3/3 PASS (the new leg throws the marker). First mutation attempt was malformed (nested-attr eval crash) — the harness correctly rejected it; fixed mutation mutates at unit level. docs/agents/systemd.md mirror-trap bullet added.
12. **vm-top-metrics collector** (row 153): scripts/vm-top-metrics.sh (selftesting: top-N order, kernel-thread skip, TOP_N bound, hwm, comm sanitization) + module (trash-metrics pattern, ExecStartPost start-contract) + runbook + evo-x2 enable. First live run already shows the target class: helium/electron at ~1.45 TiB VmSize each. Selftest caught a real trap: **call-site env-prefix does NOT rebind globals frozen at script start** (documented in the runbook).
13. **boot-evidence-scratch-gc weekly user timer** (row 154): platforms/common/programs/boot-evidence-gc.nix, checkout-referenced (catalog-inventory precedent), absent-checkout no-op degrade; HM probe confirms OnCalendar=weekly renders.
14. **io-psi-crosscheck `verdict` mode** (row 26): pure `verdict_classify` (PHANTOM ≤5%-util+CQ-waiters+zero-D / REAL ≥20% / INCONCLUSIVE, D-state outranks all) + 6 classifier selftest cases + live run classified the current box correctly (7 D-state → INCONCLUSIVE-D).
15. **bench-cold-load hardening** (4 rows): scratch under ~/.cache (durable, /tmp-volatility class), mem-PSI columns (psi_mem_* in both JSON paths), gate hysteresis (2 calm polls 10s apart), plus the NEW 4-leg guard selftest (live 4/4 PASS — which itself exposed the real guard ORDER: server → model → port → gate → cold).
16. **check-buildcache-known-parity**: shape 4 (KNOWN-added stays green, `expect_pass` helper) + rename-proof leg (hook literal paths asserted; rides flake check). First selftest run caught my own `grep -x`-vs-indented-line bug.
17. **commit-msg WARN leg**: staged queue/library rows without Task-Queue-ID footer → warning (never blocks); shellcheck-clean, live-verified both directions.

### Docs/conventions landed
18. CONTRIBUTING: step-2 LIVE/HOST-state clause, step-4 footer-heredoc + daemon-sweep clause, RETIRE-in-diagnosing-session paragraph.
19. TODO_LIST header: re-fire stamp-hygiene bullet (~3-stamp cap, collapse convention).
20. AGENTS.md sudo-exception widened (probe ×2).
21. **Phantom citation annotated on ALL surfaces** (05-03 §2, 10-15 §2, the 10-17 task report — a FIFTH surface the 00-15 report's "four" count missed — and CHANGELOG:1005, source pointer replaced).
22. **Chromium adj-300 citation pinned AND re-verified**: `9a988a2a…` (main@{#1733436}, 2026-11-02T23:59:47Z); constants fetched at that SHA match the citation verbatim.

### The first `--apply` prune (owner question 3, answered by directive)
23. **357 `[x]` rows pruned** (159 queue + 198 libraries), entry block with pre-prune line numbers pasted into CHANGELOG, 3 truncation-forged half-links normalized (caught by the pre-commit link check), count rows updated (DRIFT 60→74 expected unmasking; unharvested 203→202 — **DOWN one**, pre-count measured live at a HEAD worktree). **Process miss, recorded in the CHANGELOG entry: F27b (never prune a row whose Source carries an open drift) ran POST-apply instead of before; no over-prune materialized.** Committed `0d0913e30` (bulk rode daemon `f123b49d7`).

---

## b) DELIBERATELY DEFERRED (PSI-gated, gates named)

| Item | Gate |
|---|---|
| Owed full `nix flake check --no-build` (tee ~/.cache/fc.log) + era-annotate 00-15 §f.2 + drift baseline | io PSI some avg10 < ~20 (observed 22-50 all session; row exists) |
| /data du -sb MB-grain re-baseline + compare-one-liner smoke + storage.md verdict | same gate (rows 57/162-equivalents exist) |
| Stale deploy-gated claims sweep (row 494) | needs the healthy post-deploy window — the live host is mid-recovery (CrowdSec down, HM start-limit per the 01-20 report); post-deploy batteries on a broken host false-red |
| storage-ledger capability (row 140) | unmet prerequisites (dirSizes wiring + spawn_blocking rows) |

## c) PROCESS FINDINGS (this session's own lessons)

1. **F27b ordering miss** — the over-prune inspection's real content (open-drift Source check) was executed post-apply as a worktree A/B. The pre-count (203) could only be measured that way because the pre-prune gate run wasn't captured BEFORE applying. Rule going forward: the prune script should capture BOTH gate counts at WARN-A time, not just DRIFT.
2. **Call-site env-prefix ≠ variable rebinding** — `VAR=x func` does not rebind a global already assigned at script start; the vm-top selftest failed 4/4 on its first run because of it. Fixed by direct assignment; documented in the runbook.
3. **The negative-test harness works** — my malformed mutation (nested attr) and my indented-line `grep -x` both got caught by no-op/expect checks inside the session, before anything shipped.
4. **A multiedit new_string with a stray fragment applied SANELY** (the placeholder text never landed in bench-cold-load.sh) — verified by grep after; do not assume edit-tool failure modes, verify.
5. **sops-nix crashes when forcing `config.assertions` directly** (null-owner message interpolation) — the sanctioned assertion surface stays the toplevel eval / flake check; direct `config.assertions` probes are a dead end on this config.

## d) BRUTAL SELF-CRITIQUE

- I ticked several rows as "verified-superseded" on strong source/eval evidence but WITHOUT re-reading every cited report's full context — the counts and citations were spot-checked, not exhaustively re-derived. The re-dispatch protocol's step-2/3 rigor was applied to the load-bearing claims, not every row.
- 33 of 1079 ready rows ≈ 3% — "the WHOLE TODO LIST" is not literally achievable in one session; the honest framing is: every row triaged into executable-now / deferred-with-gate / not-mine (tq-harness rows are owner-locked; deploy rows wait on the owner's deploy).
- The prune executed at 02:0x while two parallel sessions were minting rows minutes earlier — the rev-pin protected the write, but a mid-prune tick from another session would have raced the file rewrite. It didn't (WARN A/B + rev check held), but the exposure was real.
- Row 140 was skipped on prerequisites without checking whether the prerequisite rows THEMSELVES are still open — noted here so the next pass verifies rather than trusts the row text.

## e) NEXT (highest leverage first)

1. Owner's pending wave-deploy decision (question 1 from the 01-15 report) now carries MORE tree work: pkce + nsfw + class 9 + vm-top-metrics + boot-evidence-gc + trash-metrics enable all ride it.
2. PSI-calm window: the owed flake check + /data re-baseline (existing rows).
3. The unharvested-§f backlog is 203 and growing (each parallel session adds a report) — the batch-harvest rows are the structural fix.

## §f harvest note (self-harvest at authoring)

- **Rowed below in this pass:** SigNoz paneling for node_vm_top_vmsize_bytes (monitoring); the sops-nix config.assertions crash as a probe-pattern quirk row (pipeline).
- **Covered by existing rows, not duplicated:** flake-check leg, /data re-baseline, stale-deploy-claims sweep, storage-ledger prerequisites.
- **Deliberately not harvested:** the shape-audit class-9 user-services scope extension (no incident, no evidence of need — noted here only).
