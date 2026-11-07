# bank-sync "divergence" was a timeout mislabel — re-triage, fix, and the /home/lars/tmp answer (v3)

**Date:** 2026-11-02, continuation 04:05→05:45 CET (report written ~05:45)
**Base:** docs/status/2026-11-02_03-40_nh-deploy-exit4-triage-opencloud-9100-bind-race-fix-session.md (v1) + docs/status/2026-11-02_04-00_deploy-exit4-session-status-update2.md (update 2) — **both reports' bank-sync §4/§b4 root-cause is WRONG and superseded by this report**
**Tree at write time:** parallel session mid-wave (openaicompat: flake.nix/lock/lib uncommitted) · my bank-sync.nix timeout landed · PSI ~74 · deploy still withheld

---

## Verdict (one line)

The bank-sync `[cqrs.journal_snapshot_divergence]` was NEVER a divergence: the unit's 5-min TimeoutStartSec killed the startup preflight mid-COUNT under deploy-battery contention, `context canceled` wrapped into the divergence code whose STATIC remediation template read as a diagnosis — doctor is all-green, the import re-ran green in <1s, migrate-journal was never needed, and the real fixes (timeout headroom + an interrupted-code upstream so this can never mislead again) are landed.

## a) The re-triage chain (how the wrong root-cause died)

1. **Runbook read first** (owner granted staging: stop → runbook → dry-run): `bank-sync/docs/runbooks/migrate-journal.md` + `internal/cqrs/journal_preflight.go`. The preflight wraps EVERY database read failure in a verdict code (`cqrs.journal_snapshot_divergence` / `cqrs.journal_unmigrated`); the remediation text ("Snapshots reference event history the journal does not contain…") lives in `cmd/bank-sync/error_templates.go` and is attached STATICALLY per code — a killed context produces the identical text.
2. **Journal re-read with fresh eyes**: the real error chain was `count journal events for stream BalanceSync:01M51ERJEZTWDMKSBXWR000011: context canceled.` — not a version comparison; the underlying error is the TIMEOUT KILL (`Failed with result 'timeout'`, 5min15s wall, 391M reads — vs the unit's normal 0.5–17s skips).
3. **Timeline**: the import finished successfully dozens of times Oct 25→Oct 30 03:35:42 (INCLUDING with the new build right after the 03:34 deploy switch); zero failures before Nov 2 01:09; the daemon has run the SAME preflight continuously since 2026-10-30 03:35 — a real divergence would have refused daemon startup.
4. **Empirical proof (staging window, daemon never stopped)**: `bank-sync doctor` 04:44 = ALL CHECKS PASSED (database 7 profiles, CQRS system-metaengine init, projection plan, qonto 2 profiles, encryption enabled); `bank-sync-qonto-import.service` re-started 04:44:58 → `Deactivated successfully` in <1s (idempotent skip). Unit GREEN, DB proven consistent.

## b) Fixes landed

1. **SystemNix `modules/nixos/services/bank-sync.nix`**: qonto-import `TimeoutStartSec` 5min→15min (the preflight ALONE measured 57s on a semi-calm box via doctor at PSI ~87 — 300s had zero storm headroom). Eval-green; rides the next deploy.
2. **Upstream bank-sync (repo HEAD 8786a2d2 + working tree)**: new `cqrs.journal_check_interrupted` transient code; `wrapPreflightRead` maps `context.Canceled`/`DeadlineExceeded` reads to it across all seven preflight wrap sites (+ `legacyEventsTableExists`); template added ("re-run when calmer — nothing to migrate or restore"); pinned by `TestInterruptedPreflightDoesNotClaimDivergence`. `go test ./internal/cqrs/` + template-coverage test GREEN; gofmt clean; CHANGELOG entry under Unreleased/Fixed.
3. **Doc rows corrected (the "edit both surfaces" rule, applied to a CORRECTION)**: services.md bank-sync row → `[x]` resolved-with-true-cause; TODO_LIST one-liner → `[x]` mirror; both prior reports carry a superseded-note pointing here.

## c) Why two sessions missed it (the transferable lesson)

**A static remediation template is not a diagnosis.** The prior session (mine) quoted the divergence template's WHY-text ("snapshots fold more events than the journal holds") as the root-cause without resolving the WRAPPED error one layer down (`context canceled`). The general rule this feeds: *before quoting an error class's remediation as the cause, decompose the error chain to its leaf error; if the leaf contradicts the class, the leaf is the verdict.* Same family as the 2026-09-18 "answer the question the item ASKED" and the quote-scrutiny rules — the number/text must survive one layer-deeper check before it enters a report.

## d) Deploy state (shared window, both gates)

- The opencloud 9500 fix + the bank-sync timeout ride ONE deploy. PSI was still ~74 at 05:45; the parallel session's openaicompat wave (flake.nix/flake.lock/lib uncommitted) makes short gaps unwinnable, so the deployed watcher is `~/.cache/deploy-repair/pressure-wait-deploy4.sh`: 4×60s polls of (io avg60 < 20% AND no eval-relevant file newer than 5 min) → green `nix eval` probe → `nix run .#deploy` → wait for full process tree → anchor verify/repair → final-state bundle (opencloud active, 9500/9100 listeners, cloud.home.lan raw-HTTPS, bank-sync units, journal fatal count). Owner escape remains `DEPLOY_FORCE_PRESSURE=1`.
- `pre-reboot-check` still owed after the deploy (carried since the gen-968 anchor repair).

## e) The owner's /home/lars/tmp question — answer + recommendation

**Why it exists**: `~/tmp` is the ratified hot-tier home for the box's heaviest unmanaged churn (agent scratch + cv's `PLAYWRIGHT_BROWSERS_PATH=/home/lars/tmp/playwright`), created 2026-10-26 (E6 leg: hot-user-caches.nix entry + disko declaration + `scripts/migrate-user-tmp-hot.sh` + selftests) so that churn stops double-billing the snapshotted QLC root — the direct lesson of the 2026-08 era when ~40G of scratch wrote into snapshotted `@`, pinned snapshots for weeks, and fed the SLC-exhaustion crash chain. The 2026-10-28 crisis wiped the Samsung subvol; the fstab still references it, hence the per-prompt fail-loop.

**Recommendation: (a) RECREATE** — live writers still need the dir; the users/ tree is actively growing (`projects` subvol landed); retiring costs MORE config edits (module + disko + selftests + negative tests + repointing playwright) AND re-opens the crash-era churn pattern. Execution hazard (new, 2026-11-02): STOP `home-lars-tmp.automount` before subvol creation — once the subvol exists, the armed automount can mount a PARTIAL rsync mid-prepare. Full answer recorded in docs/todo/storage.md's row (still `[blocked:user]` — the pick remains the owner's).

## f) Open items (self-harvested at authoring time)

- Deploy bundle row (services.md + TODO_LIST) now also names the bank-sync timeout as a rider — updated in the same pass as this report.
- No bank-sync-repo follow-up rows: the error-mapping fix is complete (code + test + template + CHANGELOG); its daemon commit lands in that repo.
- The /users/lars/tmp decision stays owner-gated with the recommendation recorded (storage.md:128).
- pre-reboot-check after the deploy (carried, owned).

## g) Post-report addendum (06:58)

Watch-window 1 (05:27→06:57, 90 min) closed WITHOUT firing: PSI worsened 74→97 (storm night 2 continuing) and the parallel session opened a NEW wave at 06:47-06:52 (flake.nix, quickshell.nix, configuration.nix) — both gates correctly held the deploy. Watcher re-armed as window 2 (`deploy4-window2.log`, pid 808842). Live state 06:58: anchor still `zwjf`=system-968; bank-sync daemon active; qonto-import inactive-GREEN; HM active; opencloud still failed (fix riding the deploy, as designed).

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.1 f.2 · already-tracked f.3 · NEW rowed: f.4 (+13-17 §f.4+8+45) → services post-deploy verify battery
