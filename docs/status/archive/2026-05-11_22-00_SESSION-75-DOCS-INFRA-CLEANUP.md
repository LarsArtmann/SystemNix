# Session 75 — Execution Plan Cleanup, Documentation, Infrastructure

**Date:** 2026-05-11
**Focus:** Complete remaining master TODO tasks (Phases 7-9)

---

## What Changed

### Documentation
- **TODO_LIST.md** — Created comprehensive task list from all planning docs
- **ADR-005** — Discord notification channel architecture decision
- **ADR-006** — Gatus secret injection via environment file
- **Archived** 23 old status docs (sessions 45-65) to `docs/status/archive/`
- **Updated** master execution plan with accurate statuses (75% done)

### Infrastructure
- **`mkGraphicalUserService`** — New lib helper for Wayland-bound user services (`lib/graphical-user-service.nix`)
- **`just test-hm`** — Home Manager integration test recipe
- **`just test-aliases`** — Shell alias test recipe (fish/zsh/bash)

### Flake.nix Fix
- Removed invalid `nixConfig` block that caused pre-commit hook failures
- Removed `self` from outputs destructuring (flake-parts handles it via `inputs@`)
- Reverted expanded input destructuring back to `...` pattern (Nix passes `self` as arg, must be caught)

---

## Commits

| Hash | Description |
|------|-------------|
| `34947edd` | docs: ADRs, TODO_LIST, archive old status docs, mkGraphicalUserService, test recipes |

---

## Master TODO Status

| Phase | Status |
|-------|--------|
| 1. Deploy or Die | ✅ pushed / ⬜ needs deploy |
| 2. Monitoring Completeness | ✅ 15/15 done |
| 3. Flake.nix Cleanup | ✅ 7/7 done |
| 4. Lib/ Consistency | ✅ 3 done, 3 skipped (correct) |
| 5. Script Quality | ✅ 6/6 done |
| 6. SigNoz v2 Migration | ✅ dashboards done, v2 N/A |
| 7. Security & Secrets | ✅ 2/3 done (1 blocked) |
| 8. Documentation | ✅ 7/7 done |
| 9. Infrastructure | ✅ 4/7 done (3 = hardware/low-priority) |

**Overall: ~80% complete.** Remaining items need deploy verification, Pi 3 hardware, or are low-priority improvements.

---

## Remaining Work

| Priority | Task | Blocker |
|----------|------|---------|
| 🔴 | Deploy to evo-x2 + verify all services | Physical access |
| 🟡 | Per-threshold SigNoz channel routing | None |
| 🟡 | dns-failover authPassword → sops | age identity |
| 🟢 | nix-colors integration (~6h) | Time |
| 🟢 | Dozzle deployment | Time |
| 🔵 | Pi 3 DNS failover cluster | Hardware |
