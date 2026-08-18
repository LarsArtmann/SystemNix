# Status Report: Audit-Residue Execution — 2 Production Fixes, Phantom-Green Discovery, Tooling Committed

**Date:** 2026-08-18 22:40 (Tuesday)
**Author:** Crush AI Agent
**Session scope:** Execute the residue of `2026-08-18_22-16_docs-health-audit-resumed-harvest-annotate-archive.md` §f (correctness fixes + bounded harvested TODOs + tooling debt). User-gated §f items and §g questions left for the user (asked at session end).

---

## Session Summary

| What | Result |
|------|--------|
| f.2 pool-receive 2nd source | Journal + live `ls`: **root chain healthy** (0812–0815 pool-side, 0815 received Aug 18 03:25 — the deleted P0's claim substantiated for root). BUT two NEW findings, below |
| **NEW production bug 1** | `btrfs-verify-pool-backups` mirror-health check was a **phantom green its whole life** — `awk` missing from unit `path`; `if`-condition pipefail is non-fatal → device-stats branch silently skipped (`awk: command not found` in journal while reporting clean). **Fixed:** `gawk`+`findutils` added (`snapshots.nix`), CHANGELOG entry, AGENTS.md updated |
| **NEW finding 2 (known P0 confirmed wider)** | `/mnt/pool/backups/data` holds **ZERO received subvolumes** — every nightly `btrbk-data` aborts on the /data EIO inode (`send ioctl failed with -5` on `data.20260721T2330`); the verify unit has correctly FAILED both nights (00:47 Aug 17 root-stale, 00:41 Aug 18 data-stale). Consistent with the decided keep-failing stance (TODO_LIST P0) — but "pool safety net live since 08-16" is HALF-true: root yes, data no. AGENTS.md corrected |
| **NEW production bug 2 (f.10)** | papdashboard `journalUnits` default `dns-blocker.service` → **`dnsblockd.service`** (DNS evidence silently empty in production; no `dns-blocker` unit exists) + dropped pointless `TimeoutStartSec=2min`. TODO closed, CHANGELOG entry, live `/api/health`+`/api/ingest` 401 verified via fetch |
| f.3 harvest | 17-42 §F.6/9/49 → 2 TODO items (visionreviewd rocmEnv latent gap; hermes 24G-without-rocmEnv + llama-server runtime VRAM verify; §F.9/49 merged as near-dupes). Code verified open first (no rocmEnv in either module) |
| f.4 marker fix | 15-03 item 30 scope-corrected ("02-36 archived; 13-33/13-38/14-51 kept live") |
| f.5 marker fix | 22-55 item 12 replaced lazy `done` with split verdict (check-off half already `[x]` at `71256d6f` 21:40; harvest half — item 13 resolved, item 10 was NEVER harvested) |
| f.14 harvest completion | Gatus-lint TODO got clause (4): ingest success-count/last-success-age metric (20-52 §f.10) |
| f.11 PapDashboard smoke | post-deploy-check block: `/api/health` 200, unauthenticated `/api/ingest` → **401=route exists / 404=stale pin / 405=method bug**, gatus ingest journal check (WARN on quiet windows — verified live: last 200s at 21:52, format `path=/api/ingest status=200` NOT `method=POST status=200`, initial grep pattern fixed) |
| f.22 annotator tooling | `annotate-rows.py` + `annotate-prose.py` committed to `~/.config/crush/skills/docs-health/assets/` with **`--dry-run`**, de-hardcoded pass date, clean spec-parse errors, atomic writes. Test suite: dry-run no-write, section scoping, already-annotated guard, malformed-spec guard — all pass. SKILL.md now references them ("do not hand-roll") |
| f.23 pre-commit link guard | `.githooks/pre-commit`: staged `*.md` renames/deletes → `git grep -lF` the old path across tracked md (frozen `docs/status/archived/` + `docs/planning/` exempt) → fail listing dangling refs. Both paths tested (fake paths pass; a real referenced path correctly fails) |
| f.24 health-report math | `references/health-report-format.md`: "Math discipline" section — count-first/score-second, no narrative adjustments, grouping in the table not the formula, show the substitution, qualitative beats pseudo-quantitative (encodes the 22-16 §d.2 lesson) |
| f.25 plan annotated | Continuation plan carries EXECUTED banner + graph nodes ✅ (31 annotated / 18 archived deviations noted) |

## NOT DONE / deferred

- **f.1** (`sudo btrfs subvolume show` Received-UUID proof) — user-gated; the journal + presence evidence above makes the root-chain claim solid, data-chain gap now explicit
- **§f.6–9** (key rotations, purge push, 162-commit decision) + **§g 1–3** — asked via question tool at session end
- **Quality gate**: `nix flake check --no-build` currently FAILS in a **concurrent session's** in-progress file (`modules/nixos/services/activitywatch-data-to-pool.nix` — bare module, no `flake.nixosModules` wrapper, `attribute 'pkgs' missing`; the documented auto-discovery trap). NOT this session's breakage; my files parse clean (`nix-instantiate --parse` OK ×2, `bash -n` OK ×2). Re-run the gate at quiescence
- **Deploy**: the papdashboard + gawk fixes are in-tree but NOT deployed (deploying mid-concurrent-session risks activating their half-done work; also `deploy.sh`/`flake.lock`/`configuration.nix` carry their uncommitted-then-staged changes). Deploy after both sessions settle — the fixes ride the next `nix run .#deploy`

## Concurrent-session flag (user attention)

A second session is live in this tree RIGHT NOW: `activitywatch-data-to-pool.nix` (new), `flake.lock`, `configuration.nix`, `deploy.sh` all changed by it mid-session. Its module currently breaks `nix flake check` (missing flake-parts wrapper). Flagged, not touched.

---

*Point-in-time snapshot. All live probes executed 2026-08-18 22:20–22:35 CEST. The auto-commit daemon will sweep this file.*
