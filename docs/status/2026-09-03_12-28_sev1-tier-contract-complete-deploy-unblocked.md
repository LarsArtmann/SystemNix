# 2026-09-03 12:28 — SEV1 tier contract COMPLETE (warn tier live) + deploy blocker fixed; session closure

**Session window:** 2026-09-02 ~21:14 → 2026-09-03 ~01:15 (implementation + deploys), with a 12:28 verification pass. This report closes out the arc begun in `2026-09-02_22-10_sev1-memory-alerts-demoted-to-notify-deployed.md` (initial demotion) and its addendum (warn tier + niri fix). Predecessor reports: `2026-09-02_21-25_pareto-execution-tier1-2-code-done-deploy-train-pending.md` (other session), `2026-09-03_00-07_inboxclean-paperless-golive-and-deploy-gate-battles.md` (other session — their deploy-gate findings intersected with mine).

## Final state (verified 12:28)

| Thing | State |
| ---- | ----- |
| Memory alerts | `notify` tier — can never overlay (deployed 21:46, gen `r26nn0zq`) |
| Warn tier (DAS/NIC/btrfs) | static amber banner ONCE per alert set + one cooldown-gated notification (deployed 01:0x, gen `h4w1yz17`; refined 12:3x per user choice → NON-fullscreen top strip) |
| `page` (red pulsing fullscreen) | RESERVED — zero current emitters |
| Warn QML | **verified running**: overlay process launched the new shell (`xknjlls9z…`), "Configuration Loaded", no crash-loop after the restartTriggers switch |
| `niri-health-metrics` (the deploy blocker) | fixed + live: `niri.prom` freshly written by the root timer |
| cv input | rolled back to buildable `7dee729` (revCount 3465) — still the lock state; nobody re-bumped yet |
| Deploy exit | 0 (final), smoke 84 PASS / 8 FAIL (none sev1/niri; enumerated below) |

## a) FULLY DONE (this session)

1. **Memory alerts demoted to notify** — trip/stall/episodic/guard-dead can never overlay; cooldown-gated single notification + Discord/Gatus.
2. **`warn` tier implemented end-to-end** — bridge severity resolution (`page > warn > notify`), the `warn-seen` same-set downgrade (the "once" lives in the BRIDGE so it survives quickshell restarts and is VM-testable; a CHANGED alert set re-arms), amber static QML rendering (no animation, conditional colors/text).
3. **Deploy-blocking bug root-caused and fixed** — `nsm_pid=$(pgrep -x niri-session-manager … | head -1)` without `|| true`: pgrep exits 1 when the manager is absent (the NORMAL state), pipefail+set -e killed the collector before the prom write → oneshot failed → test-activation `Exited(4)` → 4+ failed deploys across two sessions. One-line fix with a LOAD-BEARING comment (`modules/nixos/desktop/niri-config.nix`, commit `d99e8336`).
4. **VM regression test carries the whole contract** — scenarios 2/3b/3c/4 (notify), 6 (warn → warn-seen → changed-set re-arm), 10/11 (notify), 6 (page never asserted anymore); header documents the tier contract; PASSED.
5. **Docs/memory synced** — AGENTS.md sev1 bullet (final tier table + user quotes), module header, Gatus "SEV1 Escalation Bridge" alert text, `mkEnableOption` description.
6. **Two generation switches verified live** — deployed bridge script introspection (6 notify / 3 warn severities), prom files, overlay journal, user-side script execution tests (rc=1 → rc=0 for the niri collector).
7. **cv deployability restored twice** — rolled the lock back to `7dee729` when the CV session's bump (`a03ff09`, then `6615eec`) was unbuildable; their own report later confirmed `6615eec` fails vendorHash upstream.
8. **Cross-session verification pass at 12:28** — overlay alive on the new QML, cv lock state confirmed, tree clean, all changes daemon-committed.

## b) PARTIALLY DONE

1. **cv re-bump** — lock sits on `7dee729` (deployable, deployed); upstream master kept churning overnight (`cbded30` → `57f320b2`) and the vendorHash fix landing upstream is the CV session's move. Until then the deployed cv binary predates the pipeline-store feature → the "CV pipeline-store not healthy" smoke FAIL and its Gatus check stay red BY DESIGN of the rollback.
2. **Post-deploy smoke** — ran end-to-end (the pressure-report.sh packaging got fixed by a parallel session in the `d99e8336` batch): 84 PASS / 8 FAIL / 5 WARN. The 8 fails are all other domains (Pocket ID SQLITE_BUSY, FastFlowLM socket unreachable under an IO storm avg10 67%, CV pipeline-store (expected vs rollback), llama.cpp embed+rerank ×4, paperless PAPERLESS_EMAIL_HOST) — enumerated, not driven to green.
3. **system-health collector freshness** — went stale (~24 min) during the 00:3x IO storm; the sev1 bridge correctly escalated it as NOTIFY-tier only (the contract working as intended). Did not verify it recovered.

## c) NOT STARTED (deliberate scope cuts, now tracked)

1. Generic tier lint (assert: no memory condition emits `page`; page emitters == 0 today), mutation-tested via `scripts/negative-test-lints.sh`.
2. `sev1_bridge_notify_suppressed_pages_total` visibility counter (how often the old page tier WOULD have fired).
3. `sev1_bridge_warn_shown_total` / `warn_seen` counters (observability of the once-mechanics).
4. Visual/forced test of the amber banner (the QML loaded cleanly = syntactically valid, but the amber render + 10-20s once-behavior has never been seen by human eyes — needs a root-written fake alert).
5. niri-health-metrics VM-test case for the exact regression (collector run with the manager absent).

## d) TOTALLY FUCKED UP (honest)

Nothing destroyed and no wrong config shipped — but three real stumbles:

1. **Walked straight into a documented trap**: ran whole-tree `nix fmt -- --ci` at ~21:33 while two parallel sessions owned the tree — it reformatted 3 foreign files. The rule ("nix fmt is NEVER path-scoped… never run it while a parallel session owns the tree") is in AGENTS.md; I even cited the buffering lesson later without applying it here.
2. **Burned 2 blind deploy retries (00:12–00:26) before reading the evidence**: the sibling session's 00:07 status report ALREADY documented the niri-health-metrics deploy blocker, and `/var/log/systemnix-deploys/` held four identical failure tails. I found both only after re-triaging from scratch. Cross-session report + deploy-log check must precede any deploy retry.
3. **The user screamed "STOP THE ALERT ASAP" at 21:25 and got code-work instead of the 5-second mitigation**: `sudo systemctl stop sev1-bridge.timer && sudo rm -f /run/systemnix/sev1/alert` would have killed the flashing instantly; I offered it only in passing much later. When blocked by permissions, lead with the user-runnable escape hatch, then go heads-down.

Minor: 3 wasted `question`-tool invocations on schema errors; 2 lost multiedits to mtime races (should have checked git status first, both times); an `ExecStart` store-path string is world-readable so my "can't verify deployed script" assumption was wrong twice.

## e) WHAT WE SHOULD IMPROVE (process-level)

1. **Deploy-failure triage order**: (1) `/var/log/systemnix-deploys/<latest>` full tail + the `deploy exited code=N` line, (2) same-day `docs/status/` reports from parallel sessions, (3) THEN re-run. `tail -N` of a killed process loses buffered output — "no output after X" ≠ "died at X".
2. **The standalone-script verification technique generalizes**: extract ExecStart from `/etc/systemd/system/<unit>`, sed store paths to /tmp, run as yourself — found in 10 minutes what 5 deploys didn't. Deserves a line in AGENTS.md.
3. **`pgrep`/probe rc=1 class needs a lint row**: the binaryCoverageScanner pattern (provider-grep per file) could flag unguarded `pgrep` in pipefail scripts the way it flags awk-without-gawk. The journalctl-IO-trap lesson keeps repeating one command family at a time.
4. **Tier contract should be DATA, not prose**: one Nix table (condition → tier) generating bridge logic + test assertions + docs. Three synced prose locations is two too many.
5. **Lock rollback etiquette**: my cv rollback had no in-repo breadcrumb — the CV session reconstructed why from git. A one-line note in docs/services/cv.md (or the eventual commit body) avoids coordination-by-archaeology.
6. **Lock bump protocol** (the CV session's own lesson, worth promoting to AGENTS): hermetic worktree FOD check at the TARGET rev BEFORE moving the lock; a `path:` build sees untracked files and proves nothing.
7. **User-runnable escape hatches first**: when a fix needs deploy but the pain is NOW, state the sudo stopgap in the first reply.

## f) NEXT (curated, grouped — ~30 items)

**Deploy-blocking / correctness (soonest):**
1. cv upstream vendorHash fix → push → re-lock `nix flake lock --update-input cv` → deploy (CV session; unblocks 2 red checks).
2. Root-cause llama.cpp embed/rerank (:8848/:8849) being down — smoke FAIL ×4 (Requires= the HF fetch unit? GPU unit dead?).
3. paperless `PAPERLESS_EMAIL_HOST` relay-gated block — real regression or check bug (mail-relay session).
4. Pocket ID SQLITE_BUSY — one-off under IO storm or the 2026-08-22 crash class returning (journal check).
5. Verify `system_health.prom` freshness recovered post-storm (was 1464 s stale; sev1 correctly notify-tiered it).
6. Confirm the deploy-gate battle fixes are CI-green (SC2155/SC2034/SC1091 suppressions, pre/post-deploy lib packaging — parallel session's batch in `d99e8336`).

**SEV1 hardening (mine, small):**
7. Generic tier lint: no memory condition may emit `page`; zero page emitters today; negative-test it.
8. Add `sev1_bridge_warn_shown_total` / `warn_seen` counters + suppressed-pages counter.
9. Force-test the warn banner live (root writes a fake warn alert; user watches once-behavior; clears) — needs sudo, user-assisted.
10. niri-health-metrics VM case: collector run with the manager absent (locks my fix).
11. Decide/observe warn banner duration (~10-20 s = one bridge tick) — acceptable or lengthen.
12. Gatus niri checks: confirm the new `niri_aw_watcher_*` metrics + `niri_session_manager_config_stale` patterns went green after the fix.
13. SigNoz/dashboards: `sev1_bridge_page_*` metrics now read 0 forever — annotate or replace with warn counters.

**Follow-through on today's other sessions:**
14. CV session: prune their stale worktrees (`/tmp/cv-before2`, `/tmp/cvbase/CV` — mine `cv-6615eec-test` is gone).
15. test-cv btrfs-pool rewrite (their fix): local VM run when IO is quiet (CI runs it on push).
16. InboxClean→Paperless go-live: their generation built but activation failed on the niri blocker — my fix unblocks THEIR deploy; it still needs to run.
17. niri-health-metrics black-screen-batch session: flag my `|| true` fix to them so nobody "re-cleans" it away.
18. Black-screen batch's other changes (QT style env, polkit sanity smoke) — smoke PASSed; watch for the journal WARN (1 quickshell error line) noted in smoke.

**Documentation/memory:**
19. AGENTS.md: promote "hermetic worktree check before lock bump" + "deploy triage order" + "standalone script verification" to the gotchas section.
20. AGENTS.md: add the pgrep/pipefail trap next to the journalctl exit-code trap.
21. docs/services/cv.md: breadcrumb for the 7dee729 rollback + re-bump protocol.
22. docs/services/ sev1 tier runbook: how to force-test each tier safely.
23. TODO_LIST rows for items 1-13.

**Structural (bigger, not urgent):**
24. Tier contract as a single Nix table generating bridge + tests + docs.
25. Deploy orchestrator: `deploy.sh` should surface the deploy-log path + exit-record line on failure (it appends but the console doesn't point at it).
26. nh/deploy buffering: line-buffer or `stdbuf -oL` the switch phase so killed deploys don't lose the failure point.
27. Post-deploy smoke: separate "other-domain FAIL" from "this-deploy FAIL" (diff against the previous run's FAIL set) to stop false alarms for every session.
28. Gatus: check for `system_service_start_limit_hit` on `niri-health-metrics` specifically (a silent collector death should alert, not just stale textfile).
29. Revisit whether the insight enricher (PapDashboard→flm) should be flm-capable at all — the re-wake churn loop's root; with `maxRestoresPerDay=3` it self-caps but the dependency remains.
30. At a quiescent moment: full `nix flake check` (VM tests incl. fixed test-cv + sev1) — has not run whole since the niri fix.

## g) Questions (cannot answer these myself)

1. Warn banner presentation: ~10-20 s once per event — acceptable, or want it longer/different (top strip vs fullscreen dim)?
2. Should I force-test the warn tier live now (needs one root command; you'd see the amber banner once), or first real DAS/NIC/btrfs event is the test?
3. The 8 red smoke checks span four other sessions' domains (pocket-id, flm, llama.cpp, paperless/mail) — want me to drive them to green, or leave each to its owning session?
