# Session status: deploy-unblock fixes landed in tree — deploy itself orphaned mid-activation and still NOT landed (gen-983 stale)

**Scope.** This report covers ONLY this session's run (started ~19:2x 2026-11-05 from the user's blocked `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` paste, now 03:47 2026-11-06). VERIFIED (command/artifact cited inline): §16 icons realize + gate self-heal (§16-only runs green ×2), crush-events chmod fix (in HEAD via daemon commit 149e03973, `git show HEAD` greps), memory-guard shellcheck fix (HEAD, grep ×2), toplevel `--keep-going` REAL_RC=0, the 19:48 deploy attempt's build failure (nix log of the failing drv), the 20:02 deploy attempt's orphaning (log frozen 20:12:02 29813B; `/run/current-system` == `pcfbrxjab…` OLD; profile still system-983 from 08:37), live jobs/PSI probes at each step. NOT VERIFIED: any post-deploy behavior (nothing deployed), the deployed-effect of any fix in this report, whether the tree's eval drvPath drift mid-session (§d.3) had any consequence (it didn't block anything).

Companion earlier report this session: `docs/status/2026-11-05_19-42_deploy-blocker-fixes-storm-gated-deploy-status.md` (written before the deploy attempts — its "deferred, force not inherited" stance was superseded ~90 min later; see §d.1).

---

## a) FULLY DONE (verified)

1. **§16 deploy blocker fixed + made self-healing.** Realized the papdashboard icon subset (`zw6lf23…`, the exact probed path; 42 tiles, 40 pack + 2 URL, §16-only green). Upgraded `scripts/pre-deploy-check.sh` §16 to REALIZE the derivation when derived-but-unbuilt (3rd occurrence of the class: 10-23, 10-27, 11-05) and WARN instead of blocking; fail path preserved for genuinely broken drvs. `bash -n`, treefmt, §16-only re-run green post-edit. In HEAD.
2. **`node_textfile_scrape_error=1` root-caused AND fixed at the writer.** Live prometheus-node-exporter journal named `crush_events.prom: permission denied`; file on disk `0600 root:root`; cause = collector's `mktemp`+`mv` (27-writer sweep: every sibling carries `chmod 644`; crush-events was the only miss). Fix in `crush-events.nix`, eval green, committed. Rows closed both surfaces: TODO_LIST 365/1408 + monitoring.md 14/119.
3. **ci-watchdog root-caused = GitHub Actions BILLING BLOCK** (live journal: "recent account payments have failed or your spending limit needs to be increased", conclusion=failure age=456h; the ~2s exit-1 IS the canary working). Rows closed: TODO_LIST 467/1788 + services.md 14. Owner billing row (495) stays open.
4. **InboxClean 7-day OAuth bomb RECURRENCE recorded on schedule** (`gmail.token_revoked` since 11-04 14:54:33, every tick since fails) — both row surfaces updated (TODO_LIST 537 + services.md 65) with evidence + the phantom-green token-file trap.
5. **memory-emergency-guard shellcheck build break fixed.** The 20:02 deploy died building `memory-emergency-guard-check` (writeShellApplication shellcheck gate): SC2086 on unquoted `$SOCKET_UNITS` at two `systemctl stop/start` sites — intentional unit-list expansion missing the file's own established `# shellcheck disable=SC2086` directive (8 prior uses). Directives added ×2; toplevel `--keep-going` then REAL_RC=0. In HEAD.
6. **Status report (19-42) + CHANGELOG entry + row closures across both TODO surfaces**; `check-todo-system.sh` structure OK after every edit pass.
7. **bank-sync "not responding" cleared as storm-transient** (active/running, `/metrics` 609 lines live).

## b) PARTIALLY DONE

1. **THE DEPLOY — tree fully ready, activation never completed.** Attempt 1 (19:48): passed the whole battery, died at BUILD on the memory-guard shellcheck (fixed, §a.5). Attempt 2 (20:02, everything prebuilt, 2s build): passed battery, nh diff showed the flm disable REMOVING all 8 fastflowlm units, then "Activating configuration"… and the driver died at 20:12:02 (§d.1). The pending carried work (flm-disable containment, crush_events chmod, media-atlas WatchdogSec fix, monitor365 tmpfiles mkBefore, quotaboard wiring, the §16 self-heal, shellcheck fix, parallel zed rename) is committed but NOT LIVE. `/run/current-system` == old `pcfbrxjab…`, profile == system-983 (from 08:37).
2. **Deploy-window waiting.** My calm-poller infrastructure worked (after one parse fix, §d.2) but the window never came while the session was alive: evening = 3 parallel agent lint waves (load ~1200, PSI ~99, other repos), now 03:47 = nightly backup window (forgejo-backup running, PSI 89, load 122). Overnight the session went idle (wait shells reaped, §d.1) — the storm-vs-idle race was lost by attrition.

## c) NOT STARTED (this session's scope, deliberately or by running out of runway)

1. Post-deploy verification battery (anchor check, `node_textfile_scrape_error 0`, `crush_events_lines_total` present, fastflowlm socket+units gone, `ss` :52625 closed) — meaningless until the deploy lands.
2. New queue row for the deploy-detachment tooling lesson (harvest pending, see §f.1 — intentionally not yet written per the report-then-wait instruction).
3. The 19-42 report's annotate-with-correction pass (superseded stance recorded here instead; old report left untouched per the annotate-never-rewrite rule).

## d) TOTALLY FUCKED UP (honest ledger)

1. **I orphaned the deploy by running it inside a reapable background shell.** The `run_in_background` deploy (job 047) was killed at 20:12:02 when an in-flight `job_output` poll was interrupted by the incoming user message — `nix run .#deploy` died mid-"Activating configuration". The systemd transaction kept draining on its own (tq-agent-pool 45-min graceful stop, calm-gate 15-min wait, an inboxclean-sync restart, even a mid-switch fastflowlm@ proxy re-arm via the still-live :52625 socket), but nothing drove completion: no profile flip, no current-system flip, no post-switch steps. Worse: I then READ the frozen log as "activation still in progress" for ~70 minutes before the `pgrep` empty result forced the realization. Correct handling: detach long deploys (`setsid nohup … &`) so tool-session churn cannot reap them, and treat a log frozen at N bytes with zero driver PID as DEAD, not slow.
2. **First calm-poller had a parse bug that printed a FALSE "CALM".** `awk '/^some/{print $2}'` on `/proc/pressure/io` yields the STRING `avg10=99.00`; `awk` numerically coerced it to 0 < 20 → "CALM at 19:25:17 io_psi_some=avg10=99.00" while PSI was 99. Caught on read (the output shows its own absurdity), fixed with `sub("avg10=","",$2)`. This is the repo's standing quote-scrutiny rule violated in miniature — a known-value sanity check would have caught it pre-print.
3. **Unexplained toplevel drvPath flip mid-session** (`j2ls340l…` → `00wyb15i…` between two probes with no eval-relevant diff of mine; home.nix mtime churned with identical content — almost certainly a parallel session's transient edit-and-revert). I investigated one level deep (docs-feeding check, mtime census) and moved on; root cause not pinned. Harmless here (the deploy battery re-derives), but it means my "quiescent" claims were probabilistic, not proven.
4. **The session went dark for ~6.5 hours** (20:12 → 03:47) with the work item (deploy) live and unlanded: my wait-loops were reaped alongside the deploy shell and nothing re-armed them. The deploy never re-fired even though at least some overnight windows may have been calm.

## e) WHAT WE SHOULD IMPROVE

1. **Detach long-running operational commands from tool-shell lifetime** (`setsid nohup` + log-file polling only). The reaper is not hypothetical; it killed a live switch. Candidate: a `deploy` app wrapper that self-detaches, or at minimum a session rule.
2. **"Frozen log + no driver PID" must read as DEAD.** Add to the deploy-wait discipline: check `pgrep -f 'nh os|switch-to-configuration'` (full tree, not one PID) BEFORE interpreting a static tail as progress.
3. **The §16 class needed three strikes before self-healing** — the gate could have realized the drv since 2026-10-23. Generalize: pre-deploy gates should attempt the cheap repair (build the drv) before blocking on its absence.
4. **Eval-green ≠ build-green bit the fastflowlm session, and its failure surfaced only at MY deploy** (writeShellApplication shellcheck runs at build). The restructured-checks sessions should keep one real `nix build` of every touched unit script in their verification battery (the toplevel `--keep-going` is the cheap one-pass form).
5. **Storm windows are chronic, not exceptional** (evening agent waves ~load 1200; 03:xx backup window; freezes #46-48 in 48h). The calm-gate/psi-wait infrastructure exists for units, but deploys still race manually. A deploy scheduler (fire when gates green, detached, with owner notification) would remove this whole class.

## f) Next things (session-derived; NEW = not yet in any queue, EXISTING = already tracked, cited)

1. **NEW — Re-run the deploy detached** (`setsid nohup env DEPLOY_FORCE_PRESSURE=… nix run .#deploy` or calm-gated): the single act that makes ~8 pending waves live. Then the §b.1 verify battery.
2. **NEW — Harvest row: deploy-detachment rule/wrapper** (§e.1) into TODO_LIST + docs/todo/pipeline.md.
3. **NEW — "frozen log + no PID = dead" check** folded into the deploy-wait docs (docs/agents/systemd.md deploy section).
4. EXISTING — GitHub Actions billing (TODO_LIST 495, blocked:user): clears ci-watchdog + unblocks repo CI canaries.
5. EXISTING — InboxClean: Cloud Console → "In production" + re-consent ceremony (TODO_LIST 537, blocked:user; bomb recurred 11-04 on schedule).
6. EXISTING — /home/lars/tmp subvol recreate-vs-retire owner decision + `migrate-user-tmp-hot.sh prepare` (storage.md 132/237, blocked:user; recommendation stands: RECREATE).
7. EXISTING — cv SIGSEGV upstream fix (nil-guard + chunked rehydration), then drop the rev-pin + vendorHash shim (pin-registry LIFT conditions).
8. EXISTING — post-deploy smoke on a calm box for the whole carried wave (monitoring.md 15 close-out pattern; the flm/media-atlas/quotaboard post-switch checklists in their CHANGELOG entries).
9. EXISTING — gatus check for `node_textfile_scrape_error` itself (monitoring.md 71) — now cheap since the current cause is fixed at the writer.
10. EXISTING — nix-build-cleanup stale-sandbox run (needs sudo; 4h timer partially covers).
11. NEW — after deploy: confirm the §16 self-heal WARN path fires green in the battery (first live exercise of the new branch).
12. NEW — after deploy: verify fastflowlm@ re-arm impossible (`ss` :52625 closed; socket unit absent; PMA falls back to heuristic commits).
13. NEW — after deploy: `crush_events_lines_total{…}` present + `node_textfile_scrape_error 0` on :9400 within one collector tick (~1 min).
14. NEW — after deploy: anchor discipline (newest `system-N-link` by NUMBER vs `readlink /run/current-system`; generation should be 984+).
15. NEW — after deploy: home-manager zed desktop-file rename effect smoke (xdg-mime default query for text/plain).
16. EXISTING — media-atlas float re-attempt after upstream greens its TestServeBehavioralSpecs (then re-arm WatchdogSec=30s per its CHANGELOG entry).
17. EXISTING — the 183+ unharvested §f-bearing reports WARN (check-todo-system; pre-existing drift, next docs-health HARVEST pass).
18. NEW — root-cause the mid-session drvPath flip class (parallel-session edit detection at deploy time; possibly a heat-check that diffs home.nix content hash, not mtime).
19. EXISTING — ghostty interactive-scope IO storm root-cause (TODO_LIST 367).
20. EXISTING — system-health worst-case budget watch rows from monitoring.md (partially closed 10-27; verify under the current storm regime).
21. NEW — consider a `deploy-scheduler` design row (fire-when-calm, detached, owner-notify) — ROADMAP-flavored, folds §e.5.
22. EXISTING — GitHub push of the daemon-committed fixes (agent pushes forbidden; next owner push window carries HEAD `1e329732d`).
23. NEW — annotate the 19-42 report with a one-line pointer to this report (the docs-health ANNOTATE pattern).
24. EXISTING — tq-agent-pool 45-min TimeoutStopSec appropriateness under deploy windows (drains gracefully but stalls switches; maybe shorter stop timeout + internal drain).

(24 items; the remaining ~26 slots of "up to 50" would be padding — every additional item I could name is already a cited EXISTING row above or ROADMAP material, and inventing more would dilute the dispatch queue.)

## g) Questions I cannot answer myself

1. **GitHub Actions billing:** is the payment method/spending limit fix coming? (Every `ci-watchdog` tick fails loudly until then; also gates repo CI canaries.) Owner console action.
2. **InboxClean OAuth:** will you flip the Cloud Console app to "In production" (kills the 7-day bomb permanently), and do you want the re-consent ceremony run right after (it needs your browser)?
3. **Deploy authorization:** the tree is one `nix run .#deploy` away from making ~8 waves live (flm disable containment, crush_events fix, media-atlas fix, quotaboard, zed rename, …) and has missed two windows by storm/orphan. Fire it detached as soon as the backup window drains (~05:00+, gates willing), or do you want to be at the keyboard for this one?

---

**Wait-state:** session parked per instruction; no further actions until directed.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.1 f.14 · already-tracked f.4-9 f.11 f.13 f.15-17 f.19 · OBSOLETE f.12 f.22 · NEW rowed: 7 rows (merged f.2+3) → pipeline 4, services 2, monitoring 1; f.10 merged with 06-35 §f.30
