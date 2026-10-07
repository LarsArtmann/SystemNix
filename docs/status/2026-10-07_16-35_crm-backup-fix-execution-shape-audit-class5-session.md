# Status Report — crm-backup Fix Execution + shape-audit Class 5 (Get-Shit-Done Phase)

**Date:** 2026-10-07 16:35 CEST
**Session scope:** the "Get shit done!" execution phase of this session (the
plan's steps 1-3 + 13), building on the 15:50 report
(`docs/status/2026-10-07_15-50_crm-cutover-live-verification-backup-root-cause.md`).
Format: `.md` at explicit user path demand (standing convention; skill's HTML
default overridden by instruction, flagged per skill contract).
**Provenance tags:** `[live]` probed this session · `[eval]` proven via nix
eval/check this session · `[tree]` read from the working tree · `[report]`
claimed by another session's report, not independently verified.

---

## 0. TL;DR

- Both fixes LANDED and eval-green: the crm-backup `script` hoist (unit now
  renders a real `ExecStart`) and systemd-shape-audit class 5 (the
  freeform-garbage class is now eval-fatal, negative-tested). `[eval]`
- Nothing is deployed: **live gen 836 was switched at 12:21** (wave3's
  switch) — wave4's 15 FOD re-pins, nsfw alerting, dnsblockd WAL, and both
  of my fixes ALL ride the next deploy. `[live]`
- One attribution error caught in self-review (§d.1), one deliberate
  verification limit stated honestly (§b.2), one new small [ready] item
  harvested (§f.1).

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Now-state established: IO PSI ~35-42 (avg60 41.7, above the 15/20 deploy gate), live generation = **system-836, created 12:21** — everything committed after 12:21 is undeployed | `head -1 /proc/pressure/io`, profile link mtimes `[live]` |
| 2 | **crm-backup fixed in-tree**: `script` hoisted from inside `serviceConfig` to the unit top level in `crm.nix`, with an incident-comment at the hoist site | daemon commit `40c1df1e` (verified via `git show --stat` — carried crm.nix + systemd-shape-audit.nix + 4 foreign doc files) `[tree]` |
| 3 | **Fix eval-proven at unit level**: top-level `script` exists; merged `serviceConfig` attrNames = `[ExecStart Group IOSchedulingClass IOSchedulingPriority ReadWritePaths Restart RestartSec Type User]` — real ExecStart, no garbage keys, AND the `serviceOneshotDefaults` + `ioTier.background` mkMerge legs still compose (Restart/IOScheduling* present) | `nix eval` ×2 `[eval]` |
| 4 | **systemd-shape-audit class 5 landed**: flags `script`/`preStart`/`preStop`/`postStart`/`postStop`/`stopScript`/`reloadScript` inside `serviceConfig` — none are real `[Service]` keys, so the check is false-positive-free by construction; header comment documents class 5 with the incident | same commit `[tree]` |
| 5 | **Audit proven non-vacuous**: throwaway `extendModules` negative leg (`/tmp/shape-audit-selftest.nix`, tree untouched) → bad unit makes toplevel eval THROW ("NEGATIVE TEST GREEN: audit fired"); evo-x2 itself clean (zero offenders) | `nix eval --impure --file` `[eval]` |
| 6 | Full gates: evo-x2 toplevel eval green; `nix flake check --no-build` **all checks passed** (darwin omission expected); `nix fmt` — 1 file reformatted (my crm.nix hunk), zero foreign files touched; post-fmt unit-shape re-verify `true` | command outputs `[eval]` |
| 7 | Queue/library close-outs on all 3 surfaces: TODO_LIST rows → `[x]` (fix half / full); `docs/todo/services.md` crm-backup row → `[blocked:deploy]` ACTIVATION residue (deploy + first snapshot + `backup_healthy`→1 + restore drill + T42 precondition); `docs/todo/pipeline.md` shape-audit row → `[x]` with evidence | `check-todo-system.sh`: "OK: TODO queue/library structure clean" (51-drift + 88-unharvested warnings are pre-existing global state) `[tree]` |
| 8 | CHANGELOG: (1) crm-backup Fixed entry (root cause, fix, paired guard, activation caveat); (2) the four-wave vendorHash-day row (closing the tracked [ready] queue row — facts taken from all four wave reports, deploy state pinned to gen 836/12:21) | CHANGELOG.md `### Fixed` `[tree]` |
| 9 | Daemon-race discipline held: contents of every daemon commit that swept my work verified (`git show --stat` on `40c1df1e`, `6a759775` read earlier); no amend attempted (shared batches); foreign mid-edit on CHANGELOG/flake.lock detected via empty-unstaged-diff → re-checked before writing | git probes `[tree]` |

## b) PARTIALLY DONE

1. **crm-backup activation** — the fix is in-tree and eval-proven, but the
   LIVE unit is still the broken store path until the next deploy switches
   (systemd holds the old unit text; the timer remains unloaded). First
   `ledger-*.db`, `backup_healthy`→1, restore drill: all deploy-gated,
   tracked in the `[blocked:deploy]` library row.
2. **Verification depth was EVAL-level only** — `nix eval …drvPath` +
   `flake check --no-build`, not a real toplevel BUILD. Defensible (both
   changes are pure config/eval surface; no FOD involved; the deploy's own
   pre-deploy gates re-run §11) — but it is a stated limit, not an
   equivalence. Wave4's real `--keep-going` build predates my edits.
3. **`/tmp/shape-audit-selftest.nix` left in /tmp** (ephemeral, outside the
   repo — the nsfw session's litter class, smaller). Not trashed.

## c) NOT STARTED (owner-gated, correctly queued — not this phase's work)

1. The deploy itself (`nix run .#deploy`) — owner sudo + IO-PSI weather
   (still ~42 avg60 at 16:0x).
2. Post-deploy verify chain (first snapshot, `backup_healthy`, journal
   lines, restore drill) — the activation row owns it.
3. Everything downstream: G1 finalize, CRM ladder (imports → passkey →
   T42 freeze, now explicitly backup-gated), upstream push window.

## d) TOTALLY FUCKED UP!

1. **Deploy-attribution speculation shipped in chat**: my execution-phase
   summary said gen 830-836 meant "the storm-watcher/owner shipped them."
   The watcher provably did NOT — no generation exists inside its ~15:20
   window (836 = 12:21, PSI never drained). The deploys were the owner's or
   a session's; I asserted a plausible mechanism as fact. Same class as the
   15:50 report's provenance finding, one level shallower: not just WHICH
   facts are verified, but WHO/WHAT caused them.
2. **First CHANGELOG edit hit an ambiguous anchor** (`### Fixed` ×10 in the
   file) — the tool rejected it; fixed by anchoring on the section's first
   bullet. Cost: one round trip. The habit failure was editing against a
   non-unique anchor without checking.
3. Nothing broke, nothing reverted, no foreign work touched. The 15:50
   report's §f table is now stale (items 1/2 done) — point-in-time
   snapshots may age; the queue rows carry the live truth.

## e) WHAT WE SHOULD IMPROVE!

1. **The backup script body is still unproven pre-deploy** — the python
   sqlite backup-API snippet can be tested NOW against a COPY of
   `ledger.db` in /tmp (no sudo, no deploy): the unit wiring is eval-proven
   but the script's own logic has never executed anywhere. 5-minute
   de-risk of tonight's 03:40 first run. Harvested as §f.1.
2. **Attribute mechanisms, not just facts** — "verified" covers what
   happened; it does not license inferences about why. The watcher claim
   was an inference labeled as observation.
3. **State verification limits explicitly** ("eval-level, not build-level")
   at claim time, not in the self-review. I did state it in the final table
   only implicitly ("flake check green").
4. **Close-out annotations on prior reports are optional but cheap** — a
   one-line appendix on the 15:50 report ("§f.1-2 done, see 16:35 report")
   would keep the report chain navigable without rewriting anything
   (docs-health ANNOTATE shape). Not done; noted.

## f) Things to get done next (ranked; [new] = harvested this report, [tracked] = already queued)

| # | Task | Tag |
|---|------|-----|
| 1 | [new] Pre-deploy: test the crm-backup script BODY against a copy of `ledger.db` in /tmp (sqlite backup API, chmod, retention find) — proves the logic before the first live 03:40 run | [ready] services.md + queue |
| 2 | [tracked] The deploy (owner, PSI-gated) — carries crm-backup fix + audit + wave4 FODs + nsfw + dnsblockd WAL | [blocked:deploy] |
| 3 | [tracked] Post-deploy: first `ledger-*.db` + `backup_healthy`→1 + journal lines + timer loaded | activation row |
| 4 | [tracked] Restore drill on the first snapshot; then T42 freeze precondition green | activation row |
| 5 | [tracked] nsfw post-deploy gatus-conditions verify + helium pairing | nsfw rows |
| 6 | [tracked] dnsblockd post-deploy journal probes (journal.db, metrics, SigNoz rule) | dnsblockd rows |
| 7 | [tracked] Ledger binary rev jump `33b7dd8 → fe9da495` health check post-deploy | 15:50 report §f.4 |
| 8 | [tracked] Forgejo blast-radius enumeration → G1 finalize window | 15:53 report |
| 9 | [tracked] CRM ladder: CV checkpoint → dedupe decision → T33-35 → T32 → T42 | cutover plan |
| 10 | [tracked] Upstream push window: 5 non-follower vendorHash pushes (incl. crm `fe9da495`) + nsfw `46f02bb` + CI-verify today's 2 | upstream.md |
| 11 | [tracked] Overview-class un-follow [decision] (kills 8 permanent re-pins) | upstream.md |
| 12 | [watch] Trash `/tmp/shape-audit-selftest.nix` (cosmetic; /tmp is ephemeral) | this report |

## g) Questions I cannot figure out myself

1. **Deploy timing:** PSI has sat 35-60% for hours — do you want to deploy
   the pending payload (crm-backup fix + audit + wave4 + nsfw + dnsblockd
   WAL) at the next calm window tonight, or batch it with the G1 finalize
   sitting? (The backup fix argues for SOON: every 03:40 that passes is
   another night with zero journal backups.)
2. **T42 freeze gate:** confirm backup-green (first snapshot + restore
   drill) as a hard precondition for freezing Twenty — my recommendation,
   your call.
3. **Push window:** is the crm `fe9da495` vendorHash paste-push (plus the
   other 4 non-followers) something you push this evening, or is there an
   agent-open window mirroring today's bank-sync/InboxClean pushes?

---

*Self-harvest: §f.1 landed in TODO_LIST.md + docs/todo/services.md at
authoring time ([ready]); items 2-11 are pre-existing tracked rows (not
re-queued — no-drift rule); item 12 recorded here deliberately (cosmetic,
not queue-worthy).*

*Evidence index: profile mtimes for gen 836 (12:21); `nix eval` script +
serviceConfig attrNames (16:1x); `/tmp/shape-audit-selftest.nix` negative
leg ("NEGATIVE TEST GREEN"); `nix flake check --no-build` all-pass;
`nix fmt` 1-file diff scoped to my surfaces; `check-todo-system.sh` OK;
daemon commit `40c1df1e` stat; IO PSI `some avg10=34.92 avg60=41.68`.*
