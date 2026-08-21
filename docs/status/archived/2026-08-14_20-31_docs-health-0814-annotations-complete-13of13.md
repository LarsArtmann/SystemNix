# Status: Docs-Health 08-14 Annotations COMPLETE (13 of 13) — Reboot Discovery, Release-Chain Break Found

**Date:** 2026-08-14 20:31 CEST
**Session scope:** Finish the docs-health ANNOTATE pass on the last 8 of 13 `2026-08-14` reports; live-verify everything against code, git, journal, and the running system
**Prior context:** `docs/status/2026-08-14_18-31_docs-health-0814-annotations-5of13-live-findings.md`

---

## a) FULLY DONE

### 1. Session-4's uncommitted batch — resolved, nothing lost

The 18-31 report's biggest worry (6 modified files uncommitted, daemon-sweep risk) turned out fine: the daemon had already swept everything into `19c195e9` (the 5 annotation files + 05-48 correction + buildcache fix) and `5e22c678` (the 18-31 report itself). Tree was clean at session start. The "commit current batch" todo was moot.

### 2. The failed §e 3-6 edit applied and committed (`42674b5e`)

08-24 twenty now carries its final two done-markers (backup-coordination = existing rule since `976e9547`; docker restart monitoring at `9b6590bf`). Hook passed clean.

### 3. ALL 8 remaining 08-14 reports annotated — every numbered item checked, per-file commits

| Report                           | Verdicts                            | Commit                    | Highest-value findings                                                                                                                                                                                                                                                                                                    |
| -------------------------------- | ----------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `09-30` OIDC gates/qmd/deploy    | ~40 + 3 questions answered          | `2c9be5ca`                | overlays/shared.nix mystery SOLVED (alejandra re-indent, `7afab3f8`); hermes failure root-caused; Overview 503 = PMA hang (watchdog `5e22c678`); phantom-metric escape hatch shipped at `18093b83`; **reboot-test items tested live** (see below)                                                                         |
| `10-00` SigNoz Perses            | 1 (surgical — research-only report) | swept in `e1096f46`       | live re-verify: **251 duplicate dashboards STILL in the DB**, JSONs still v1; migration fully tracked TODO_LIST:52-53                                                                                                                                                                                                     |
| `10-04` registration lock + oomd | ~35 + 3 questions answered          | `e5dfe0ae`                | **RELEASE-CHAIN BREAK**: cqrs-htmx tagged v4.8.0 correctly, but browser-history `v0.4.2` predates the lock, go.mod has zero v4.8.0 refs, SystemNix flake still at `a1b78afa` (08-12) — **the deployed binary has NO gate; MAX_USERS=1 is a no-op**; oomd 60%/30s live-verified via `oomctl`; Twenty worker RestartCount 0 |
| `10-41` OAuth2 TOCTOU            | ~25 + Q2 answered                   | `fbf0156b`                | dispatch-site audit complete: exactly 3 sites, `import_export.go:156` verifiably STILL UNGATED in v4.8.0; all 6 claimed files confirmed inside `b1ad3350` (23-file commit); migration note in usermgmt CHANGELOG                                                                                                          |
| `12-30` SSD benchmark            | 4 structural                        | `cbbba3fa`                | drives superseded: SSD1 = buildcache (relabeled NOT wiped — **the 22 test photos survived at `/mnt/buildcache/me/`**), SSD2 btrfs unmounted awaiting Docker decision; fstab plan superseded by declarative by-id mount                                                                                                    |
| `12-53` DSN audit                | ~10 + Q1/Q3 answered                | `e9a3ac41`                | all 3 upstream fixes committed but ALL UNTAGGED (bh `b750ec5`/`b350c96` same open chain; CRB `b1e5e701` — repo has NO tags; Kernovia `d139446d` not in v0.5.0-watermill); go-auto-upgrade verified live on PATH                                                                                                           |
| `13-22` vendorHash/hardening     | ~15 + Q2 answered                   | `e1570a2c`                | **harden() primitives runtime-verified**: display-watchdog + all btrfs services clean in the 20:04 boot journal; renamer pins + DSN audit + errorfamily fix all closed via 12-53                                                                                                                                          |
| `13-44` hermes                   | ~20 + Q1/Q2 answered                | (applied, commit pending) | **upstream hermes main (v0.20.1) NOW ships `registration_lifecycle` in py-modules** (verified via raw.githubusercontent) — the SystemNix patch is deletable after an input bump; hermes had 2 more oomd kills since 13:44 but is running; forgejo-oidc boot race verified recurring                                       |

### 4. THE REBOOT DISCOVERY (changes verdicts across many reports)

The machine rebooted at **20:04–20:05 tonight** (clean, user-initiated shutdown — systemd-shutdown sequence in journal, not a WDT crash). Consequences verified live:

- **oomd 60%/30s is ACTIVE** (`oomctl`: `Default Memory Pressure Limit: 60.00% / 30s`)
- All "reboot test" items across 08-23/09-30/10-04/10-41/13-22 resolved with runtime evidence
- 9 units failed at boot but ALL recovered except one: **`activitywatch-watcher-aw-watcher-window-wayland` start-limit-hit at 20:05:07 and is STILL DEAD** — the ActivityWatch ordering fix did NOT hold. New live finding, user-visible (window tracking broken)
- gatus/oauth2-proxy/browser-history/forgejo-oidc/smartd/smart-audio: transient boot failures, all self-recovered; smartd monitors both USB SSDs + NVMe

---

## b) PARTIALLY DONE

### 1. `13-44` annotations applied but NOT yet committed

All edits landed (including the one block-edit failure, fixed in-round). Committing immediately after this report.

### 2. TODO_LIST routing not started

The findings list has GROWN (see f). Carried from 18-31 §f.11-27 plus this session's new items.

---

## c) NOT STARTED

1. TODO_LIST routing (full list in f below)
2. ARCHIVE pass — candidate pool grew: 09-30, 10-04, 10-41, 12-53, 13-22, 13-44 join the ~22 from 16-20 §f.28 (10-00 and 12-30 stay — open work tracked)
3. Formal `nix flake check --no-build` gate run
4. Inline health report (Accuracy + Fitness)
5. Final attributed commit + AGENTS.md statix-staged-only note (18-31 §f.32)
6. Foreign `13-15_ssd-repurposing-options.md` — left alone per default (user never answered; 4th carry)

---

## d) TOTALLY FUCKED UP

### 1. One block-multiedit failed on THREE separate files (09-30, 10-41, 13-44)

Same root cause each time: numbered lists with BLANK LINES between items — my block old_strings assumed contiguous lines. Improvement over session 4: every failure was identified and fixed within one tool round (grep for unstruck lines). The per-item edit pattern is the fix; stop writing multi-item blocks against lists with blank separators.

### 2. 13-44 annotations sat uncommitted through the report-writing pause

The exact failure mode from 15-24 §d.5 again — work done, commit deferred. Mitigated this time by identifying the failed edit immediately, but the commit is still owed NOW.

---

## e) WHAT WE SHOULD IMPROVE

1. **Release-chain verification needs tag/date forensics, not session-summary inheritance** — "release chain open" was known, but the EXACT break (flake rev `a1b78afa` = 08-12 vs `b750ec5` = 08-14; `v0.4.2` = 08-10) required `git merge-base --is-ancestor` + tag dates. The chain is broken at the browser-history tag step — everything upstream of it is done.
2. **`git tag --contains <commit>` is the only reliable "did the tag capture the fix" check** — used for cqrs-htmx v4.8.0 (yes) and Kernovia v0.5.0-watermill (no).
3. **Boot journal (`journalctl -b 0`) is a first-class verification source** — one reboot resolved 5 reports' worth of "reboot test" items and exposed one real regression (aw-watcher).
4. **`oomctl`, `docker inspect`, `journalctl`, fetch(localhost + raw.githubusercontent)` all work in this sandbox** — systemctl/curl remain blocked. The hierarchy holds.

---

## f) NEXT (up to 50)

### Immediate

~~1. Commit `13-44` annotations~~ done — commits landed; chain continued.
2. **Route new findings to TODO_LIST:**

- ~~**aw-watcher-window-wayland start-limit-hit at boot — STILL DEAD**~~ fixed — the wayland-socket gate (`aw-watcher-window-wayland-gate`, `platforms/common/programs/activitywatch.nix:17-37`) now orders startup; closed as DONE in the 2026-08-17 harvest. Annotation 2026-08-17.
- browser-history release chain ← open — TODO_LIST P1 "Verify the browser-history registration gate is LIVE in the deployed binary" (input now `4e7604d`/storage-v4.7.0 era; live 403 verification still owed).
- `import_export.go` ungated third path ← open — TODO_LIST P1.
- Dozzle runtime container recreate ← open — TODO_LIST P1.
- ~~immich backup stale 999h (carried)~~ done — collector fix (08-15) + pool migration; overnight cycle GREEN 2026-08-17.
- ~~`/mnt/buildcache/me/` test photos cleanup~~ done — directory empty on disk (verified 2026-08-17).
- ~~BTRFS scrubs interrupted ×2 (carried)~~ superseded — weekly scrubs complete since; the 2026-08-17 /data scrub ran to completion (and found the 1.3MB corruption). Root-fs scrub remains TODO_LIST P0.
- ~~Disk item update: 97% → 87% (carried)~~ done — item re-based to the 95%-era reality (TODO_LIST P0).
- forgejo-oidc-setup boot race ← open — TODO_LIST P1.
- hermes flake input bump → DELETE registration_lifecycle patch ← open — TODO_LIST P2.
- CRB + Kernovia tags ← open — TODO_LIST P6 "Tag CreditReformBilanzampel + Kernovia DSN fixes".
- ~~Delete stale qmd-cache TODO item (carried)~~ done — absent from current TODO_LIST.
- expires_at live-reconfirmation note ← open — TODO_LIST P3.

3. Carry the 11 items from 16-20 §f.17-27 — routed/shipped; see the 16-20 annotation (2026-08-17) for per-item verdicts. 4 shipped, 7 open in TODO_LIST.

### Closure

~~4. ARCHIVE pass~~ done — 09-30/10-04/10-41/12-53/13-22/13-44 all archived; 10-00 + 12-30 closed by the 2026-08-17 pass.
~~5. `nix flake check --no-build` formal run~~ done — green 2026-08-17.
6. Inline health report ← open at annotation time — owed by the 2026-08-17 docs-health pass (printed at its close).
~~7. Final attributed commit~~ done — daemon sweeps (e.g. `46b5ffdb`).
~~8. AGENTS.md: statix staged-only note~~ done — AGENTS.md gotcha present.

### Structural debt (observed)

9-27. Carried structural items from 18-31 §f.33-37 — Darwin intent documented (AGENTS.md) and `backup_all_healthy` Gatus check live (gatus-config.nix:1178); AGENTS compression / appendix-only archives / planning triage remain OPEN in TODO_LIST P6. Annotation 2026-08-17.

---

## g) QUESTIONS

### ~~1. Foreign `13-15_ssd-repurposing-options.md` — 4th carry~~ RESOLVED — annotated with a Decision Record + archived by the 2026-08-17 docs-health pass (owning session long finished).

### ~~2. immich backup stale ~41 days — TODO-only confirmed?~~ RESOLVED — fixed across the collector-capability fix + pool migration; overnight cycle GREEN (`docs/status/2026-08-17_10-28` §a.1).

### ~~3. NEW: aw-watcher-window-wayland is dead since the 20:05 boot~~ RESOLVED — the wayland-socket gate shipped (`platforms/common/programs/activitywatch.nix:17-37`); closed as DONE in the 2026-08-17 harvest.

### 4. MiniMax Token Plan quota ← OPEN owner decision — TODO_LIST P2 ("MiniMax quota decision (carried ×4)").

---

_Report generated: 2026-08-14 20:31 CEST_
_Session delta: 8 reports annotated (13/13 complete), 8 commits landed (`42674b5e`, `2c9be5ca`, `e5dfe0ae`, `fbf0156b`, `cbbba3fa`, `e9a3ac41`, `e1570a2c`, + `e1096f46` daemon-swept), 1 reboot discovered + harvested for verdicts, 3 major findings (release-chain break, aw-watcher boot regression, upstream hermes fix available), 3 block-edit failures caught in-round_
