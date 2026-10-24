# Archived plans — manifest

Closed history: plans whose work shipped or whose decision settled. Do not re-open; the entries below record why each file landed here.

## 2026-10-24 docs-health corpus sweep (10 files)

| File | Classification | Deciding reason |
| --- | --- | --- |
| `2026-06-23_22-56-QUICKSHELL_IMPLEMENTATION_PLAN.html` | EXECUTED | Quickshell/DMS is the live desktop (`platforms/nixos/desktop/quickshell.nix`, AGENTS.md) |
| `2026-08-22_07-01_STABILITY-DEFENSE-IN-DEPTH-PARETO-PLAN.html` | EXECUTED | Executed per status doc "stability-defense-in-depth-plan-executed"; `workload-admission.nix` shipped |
| `2026-09-02_19-13_PAPERLESS-SSO-CLOSEOUT-AND-BOX-STABILITY-PARETO-PLAN.md` | EXECUTED | `pressure-report.sh`, `docs/services/paperless.md`, Pocket ID SQLite Health check shipped |
| `2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md` | EXECUTED | `hot-db.nix` + `crush-hot-db.nix` + `disko/samsung-tlc.nix` live (T-task table carries in-file completion status) |
| `2026-09-18_19-53_SAMSUNG-2ND-BOOT-DISK-PARETO-PLAN.md` | EXECUTED | Checklist rows `[x]`; mirror built + activation EXECUTED 2026-09-30, live boot drive since 2026-10-15 |
| `2026-09-19_10-48_SAMSUNG-BOOT-MIRROR-FINISH-PARETO-PLAN.md` | EXECUTED | Status doc `2026-09-30_13-07_…W1-W4-EXECUTED.md`; BootOrder owner-verified |
| `2026-09-22_23-27_EVENTCATALOG-FEDERATION-HUB.md` | EXECUTED | Addendum "HUB PHASE SHIPPED OUT-OF-BAND"; go-live complete 2026-10-12 (`docs/services/architecture-catalog.md`) |
| `2026-09-23_15-06_FORGEJO-COOL-CATPPUCCIN-THEME.md` | EXECUTED | Phase 1 IMPLEMENTED; `_forgejo-themes/` live, deployed system-864 |
| `2026-09-29_21-41_GEOMETRIKKS-NATIVE-NIX-MIGRATION.md` | EXECUTED | Flip deploy EXECUTED (`2026-09-29_23-13_*`); `pkgs/geometrikks.nix` shipped |
| `2026-09-30_12-13_DNSBLOCKD-MAX-ADOPTION.md` | EXECUTED | Max-adoption wave DEPLOYED LIVE 2026-09-30 system-810 (`docs/services/dnsblockd.md`) |

Companion dispositions from the same sweep (files kept in place): 13 SUPERSEDED banners (7 written 2026-10-24 + 6 pre-existing), 21 REFERENCE-KEEP, 6 ACTIVE. Evidence: `docs/status/2026-10-24_12-04_*` §a.9 and the M2 record in the closeout status report.
