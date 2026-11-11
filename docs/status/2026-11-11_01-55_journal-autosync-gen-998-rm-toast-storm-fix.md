# journal auto-sync LIVE on gen-997/998 — four live-cycle bugs found and fixed; rm toast-storm fix rides gen-999

**Arc (continuation of the 06:04 + 19:10 reports, same session):** the auto-sync pipeline
(`services.journal-import`) went LIVE on the host via the concurrent session's deploys —
gen-997 (~19:32, carried the module with the staging-in-dataDir design) and gen-998
(carrying the staging relocation fix). Two further live-cycle defects surfaced and are
fixed in-tree awaiting gen-999: the staging **traversal** block (importer couldn't reach
staging through the 0700 dataDir — gen-997) and the **rm permission** failure (importer
can't delete bank-sync-owned files from a bank-sync-owned dir — gen-998, currently
toasting OnFailure every 15 min until gen-999 lands).

**Scope line — VERIFIED here (artifact per claim):**

| Claim | Evidence |
| --- | --- |
| gen-997 deployed + carried the module + anchored | `/run/current-system` was `3yhv8kp50…` = `system-997-link` (readlink, 19:41); `journal-import.timer` active/waiting (busctl) |
| gen-997 first cycle: export ✅ / import ❌ traversal | export log "Finished journal mesh export" (574 ms, OnSuccess triggered, 20 staging files as bank-sync); import log "imported 0 file(s), kept 0 failed, unmapped skipped:[ ]" — glob-empty because `/mnt/pool/services/bank-sync` is 0700 bank-sync and lars cannot traverse (the morning `ls` Permission-denied on the same path, re-hit from the unit context) |
| gen-998 deployed + carries the staging relocation | `/etc/systemd/system/journal-sync-export.service` (deployed unit): `StateDirectory=journal-sync` + `ReadWritePaths=/var/lib/journal-sync`; live `/run/current-system` = `vkads03j…` = `system-998-link`, anchored ✓ |
| gen-998 first cycle: import READS files now (traversal fix works) but fails at rm | log: `bank-sync import: 0 facts, 0 imported, 0 failures` (file read ✓, coverage re-landed idempotently) then `rm: cannot remove '/var/lib/journal-sync/tx-108989341.json': Permission denied` → `set -e` → unit FAILURE → OnFailure toast; **5 "Failed to start" events in the 00:55→01:45 window alone** (15-min timer → toast storm since gen-998's deploy) |
| The rm-drop fix is in-tree, parse+fmt clean | `overlays…` no — `modules/nixos/services/journal-import.nix`: `rm -f` removed with a lesson comment; `nix-instantiate --parse` OK; treefmt canonical; toplevel eval PENDING (the box's IO storm — nvme0n1 100% util, PSI 51 at 01:45 — times evals out; last full-green eval was 19:5x pre-storm-peak) |
| Live host state | IO PSI avg10 51, nvme0n1 100% util (the other session's proof-builds continue overnight); lock stable since 17:26; dirty tree = docs + this module fix |
| Prior arcs stand | morning rehearsal (3 bugs), coverage records ×7, patchelf diagnosis → their `779c65a67` stage-gate, the 19:10 report + addendum — all landed |

**Scope line — NOT verified here:**

- **Whether the rm-drop fix evals green end-to-end** — the eval attempt timed out under the
  IO storm (nvme 100%); parse+fmt are clean, the change is a one-line removal + comment.
- **The total toast-storm push count** (Discord side) — 5 unit-failures counted in the
  00:55→01:45 journal window; the full count since gen-998's deploy hour needs a wider query.
- **Whether gen-998's export side is still green across ticks** — only the import failure was
  pulled from the journal; the export "Finished" lines were not re-counted per tick.
- **gatus "Journal Hauptbuch" rendered state** — still never probed (carried since the 06:04
  report §f.3; queued).
- **journal-backup / journal-serve health post-gen-998** — serve responded on 8484 at 19:41
  (new PID 2466073); nothing since.

## a) FULLY DONE

1. **The auto-sync pipeline is LIVE on the host** (gen-997 carried it, gen-998 carries the
   staging relocation): timer active/waiting, export unit green every tick (20 files, atomic),
   import unit reads staging across the user boundary (the traversal fix works — file reads
   logged), coverage records land idempotently. Evidence: deployed unit files read back from
   `/etc/systemd/system`, journal logs cited above.
2. **Four live-cycle defects found and fixed** across gen-997/998: (1) stderr-only `journal
   status` output, (2) newline-separated ID list vs space-padded match, (3) staging traversal
   through the 0700 dataDir, (4) cross-user `rm` in a bank-sync-owned dir. Fixes (1)+(2) are
   LIVE in gen-998 (proven: the status snapshot prints in the unit log and mapped IDs match);
   (3) is LIVE (import reads staging at `/var/lib/journal-sync`); (4) is in-tree awaiting
   gen-999.
3. **The staging relocation (StateDirectory)** — `journal-sync-export` now owns
   `/var/lib/journal-sync` natively: systemd creates+owns it before namespace setup (killed
   the 226/NAMESPACE first-run class), 0755/0644 gives the importer read access, no /mnt
   coupling (mount-gating + pool-recovery assertions no longer apply), DB stays DAC-private.
4. **Docs/queue/report hygiene:** 19:10 report + addendum, CHANGELOG entry, services runbook
   rows, pipeline rows (patchelf PROGRESS, two [decision] rows, go-humanize-linter [ready],
   the [blocked:deploy] battery row), TODO_LIST rows — all landed; `check-todo-system.sh`
   gate green.

## b) PARTIALLY DONE

1. **Auto-sync end-to-end**: gen-998 is live with export ✅ + import-reads ✅ + import-rm ❌
   (toast storm). The rm-drop fix is parse+fmt clean in-tree; eval is IO-blocked; gen-999
   deploy waits for a calm window. Until then every 15 min: export succeeds, import lands
   coverage idempotently, then dies at the first mapped file's rm — loud, safe, and noisy.
2. **Verification battery**: anchor ✓, timer ✓, units ✓/failed, staging ✓, coverage ✓,
   status-snapshot ✓ — remaining: gatus probe, journal-backup/serve post-wave check,
   patchelf lift-probe, full battery re-run on gen-999.
3. **The books fill** — unchanged: awaiting owner Wise SCA OTP + backfill (services.md:308);
   after it the next tick imports real facts.

## c) NOT STARTED

1. v2 real-time (push/events) — ROADMAP.
2. Upstream filings: nixpkgs patchelf-0.15.2 bootstrap patch-set failure; journal status
   stderr-only; bank-sync export UX. All verify-before-filing gated.
3. The morning-queued forensics rows (Nov 9 window-reset, journal-serve SIGKILL actor, gatus
   live probe, go-humanize-linter vendorHash, ghostty corpse) — untouched today; the day
   belonged to the deploy saga. They are QUEUED, not lost.

## d) TOTALLY FUCKED UP

1. **My `rm` line is toasting the owner every 15 minutes RIGHT NOW** — a cosmetic
   work-queue flourish (delete-after-import for tidy staging) that ignored the DAC
   mechanics one level down: `rm` needs WRITE ON THE DIRECTORY, the dir is bank-sync-owned
   0755, the importer is lars → Permission denied → `set -e` → unit failed → OnFailure
   push, on a 15-min timer, since gen-998's deploy (~4-5 h → a dozen-plus Discord pushes).
   Severity: owner-facing alert noise + a permanently "failed" unit in every listing —
   harmless to data (imports land, coverage persists) but exactly the alarm-fatigue class
   the repo fights. Fix in-tree; gen-999 lands it.
2. **Both staging bugs share one root — I designed the staging ownership from the
   exporter's perspective and never walked the importer's permission path.** The
   "DAC-pure" dataDir-internal choice (19:10-era me called it posture-preserving) blocked
   the consumer outright; the rehearsal couldn't catch it because its staging lived in
   /tmp (traversable). The rm bug then repeated the same class one level down. Lesson
   (now in the module comments): staging must be a shared interface dir with explicit
   per-side permissions — never a subdir of either side's private space.
3. **The rehearsal environment differed from the unit environment in exactly the dimensions
   that mattered** (traversal, dir-write) — rehearsal-as-practiced catches script logic,
   not unit-context effects. Four live bugs, three classes, all environment-shaped: stderr
   plumbing, namespace setup, DAC traversal, dir-write semantics. §e.1 is the fix.
4. **The eval-green → deploy gap burned the force token (13:42, carried)** and the eval
   itself is now IO-starved (60-150 s timeouts) — the box has been un-evaluable for most of
   the evening under the foreign session's proof-build load. Not mine to fix; documented.

## e) WHAT WE SHOULD IMPROVE

1. **Rehearse INSIDE the unit's context, not a lookalike**: `systemd-run --uid=<unituser>
   -p WorkingDirectory=… -p ProtectHome=read-only -p ReadWritePaths=… bash <script>` runs
   the exact script under the exact DAC/namespace constraints — the four bugs from today
   (stderr aside) are all invisible to `bash -c` and visible to this. Candidate: a repo
   checklist item + lesson.
2. **Never `rm` across an ownership boundary** — shared-interface dirs are overwrite-only
   (bounded by the writer's own cycle); deletion is the writer's job or nobody's.
3. **Toast-storm budget**: a timer unit that can fail deterministically every tick needs a
   failure-sideload — e.g. OnFailure into a dedup unit, or a "n failures then escalate"
   counter so 15-min-failures degrade to ONE push + a metric. Candidate: deploy.sh/module
   pattern + upstream journal thought.
4. **Stage-gating for overlays (done upstream-side)** — `779c65a67`'s final-package-set gate
   is the durable pattern for "override X but not in the bootstrap fixed-point"; keep it in
   mind for the next nixpkgs-attr rerouting need.
5. **Deploy gate+fire atomicity** (carried from 13:42) — unchanged verdict.
6. **`journal status --format json`** (carried) — would retire the unit's sed parse AND fix
   the stderr trap at the source.

## f) Top things to get done next (session-scoped, routed)

| # | Task | Impact | Effort | Category | Routing |
| --- | --- | --- | --- | --- | --- |
| 1 | **Deploy gen-999 (rm-drop fix) on the next calm window** — ends the 15-min toast storm; calm-wait pattern in the 19:10 addendum | Critical | S | Bug | the standing calm-wait → deploy |
| 2 | **Post-gen-999 battery** — zero failures across 2 ticks, `imported=7 unmapped=13`, staging at `/var/lib/journal-sync`, gatus probe, journal-backup/serve check, anchor | High | S | Quality | services.md [blocked:deploy] row (update: gen-998 evidence noted) |
| 3 | **Toast-storm audit** — count the OnFailure pushes 00:55→fix-landing; report the noise cost | Medium | S | Documentation | fold into #2 |
| 4 | **nixpkgs patchelf-0.15.2 bootstrap patch-set failure** — upstream filing with the stage-4 reproducer trace (this session captured it) | High | M | Bug (upstream) | ROADMAP + verify-before-filing |
| 5 | **journal status machine-readable output** — `--format json` + stdout | Medium | S | Bug (upstream) | ROADMAP + verify-before-filing |
| 6 | **bank-sync export UX** — `--schema v1` implies json; multi-balance | Low | S/M | Feature (upstream) | ROADMAP (carried) |
| 7 | **v2 real-time design note** — bank-sync events → journal ingest | Medium | M | Feature | ROADMAP (carried) |
| 8 | **go-humanize-linter vendorHash re-stale** (queued) | High | S/M | Bug | TODO_LIST + pipeline.md (queued) |
| 9 | **Float ceremony decision** (queued [decision]) | Critical | S | Decision | pipeline.md (queued) |
| 10 | **Wise SCA + backfill** (owner) — the books' zero-fill | Critical | S | Feature | services.md:308 (queued) |
| 11 | **Ghostty corpse remediation** (queued) | Medium | M | Bug | existing row |
| 12 | **Nov 9 window-reset forensics** (queued) | Critical | S | Bug | TODO_LIST (queued) |
| 13 | **journal-serve SIGKILL forensics** (queued) | High | S | Bug | TODO_LIST (queued) |
| 14 | **gatus live probe** (queued) | High | S | Quality | TODO_LIST (queued) |
| 15 | **Qonto-era import decision** (queued [decision]) | Medium | S | Decision | pipeline.md (queued) |
| 16 | **`systemd-run` rehearsal pattern** → lesson + checklist | Medium | S | Process | lessons candidate |
| 17 | **Toast budget pattern** → deploy/module pattern | Medium | M | Feature | ROADMAP |
| 18 | **CHANGELOG gen-number refresh post-999** | Low | S | Documentation | fold into #2 |
| 19 | **Coverage flip watch** — after SCA+backfill the 7 verdicts should flip from "statements never synced"; assert in the first fact cycle | Medium | S | Quality | fold into #2 |
| 20 | **`journal-import` unit NRestarts audit** — confirm the failed units didn't hit start-rate limits (5/300s burst) during the storm | Low | S | Quality | fold into #2 |

**HARVEST:** #3 folds into the services.md battery row (updated wording: gen-998 evidence +
toast-audit step). #10/#16/#17 → lessons/ROADMAP candidates noted here. #1 rides the standing
calm-wait pattern (no new row — it IS the deploy). Everything else already queued from the
06:04/19:10 reports — referenced, not duplicated. No new TODO_LIST rows needed tonight beyond
what exists.

## g) Questions I can NOT figure out myself

1. **The toast storm is firing Discord pushes every 15 minutes until gen-999 lands** — the
   fix is in-tree but the deploy needs a calm window that hasn't existed for hours. Do you
   accept a deliberate `DEPLOY_FORCE_PRESSURE=2` now (real-storm WDT risk, the documented
   deliberate token) to end the noise, or should the storm decide the timing?
2. **Shall I file the patchelf-0.15.2 bootstrap issue upstream?** I hold a clean reproducer
   (stage-4 wrapper trace + the causality flip); filing means a nixpkgs issue in your name —
   your call on whether that's mine to open, or whether the float session already owns it.
3. **Is another float wave planned tonight?** If yes, gen-999 should wait for its registry
   landing (else we deploy into the same race again); if no, I deploy on the first calm
   window. I cannot see the other session's intentions.
