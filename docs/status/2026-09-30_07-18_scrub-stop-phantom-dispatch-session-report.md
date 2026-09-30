# Session report — dispatch 000001a0eaf255cff90e3b85a22accf257e2 (guard scrub-stop phantom)

**Date:** 2026-09-30, session ~03:30–06:50 (this report authored 07:18)
**Repo:** SystemNix @ master, footer commit `2ef4073a`
**Task:** TODO_LIST "Guard scrub-stop may be a PHANTOM: `systemctl stop` on `btrfs-scrub@*` kills the CLI waiter, not the kernel-side scrub — only `btrfs scrub cancel` stops the operation … verify + make the guard cancel scrubs" (Source: `docs/status/2026-09-29_01-45_…memory-guard-4-fixes…md` §e.2)

**Report-time discovery (not researched further):** after my footer commit, the queue RE-FIRED this item ("Re-fire-3"): commits `bd4d4078` ("verify+fix: guard VM test executed green after catch-up metrics fix", 06:27) and `1e074bbc` (its session report + guard CHANGELOG refresh, 07:00) carry the same Task-Queue-ID. Their contribution: the FIRST VM run was RED at scenario 9 — a REAL pre-existing ordering bug in the guard script (churn_units_stopped metrics computed BEFORE the backup catch-up grant pruned the churn file), fixed by moving the computation after both mutation points. My green VM run (~06:40) executed on top of that fix. The task's completion is therefore JOINT: my dispatch landed the verdict correction + names/template/re-arm fixes + test scenarios 8/8a; the re-fire landed the scenario-9 ordering fix + green verification + report. Both commits cross-reference the queue.

---

## a) FULLY DONE

1. **Verification with a CORRECTED verdict** (the item said "verify"):
   - The deployed `btrfs-scrub@` template already cancels the kernel-side scrub on a correctly-named stop: read `/etc/systemd/system/btrfs-scrub@.service` live (system-800) — `Type=simple` + `ExecStop=btrfs-scrub-maybe-cancel %f` (runs `btrfs scrub cancel`, rc=2 tolerated). The item's premise ("stop kills only the CLI waiter") is false for THESE units and true only for a bare `btrfs scrub start -B` or a oneshot unit (nixpkgs comment: "simple and not oneshot, otherwise ExecStop is not used"). The prior session's "deployed unit has NO ExecStop" note was a misread of the STRAY unit `btrfs-scrub--.service`.
   - The real bug: the guard's `ioChurnUnits` named the STRAY unit files `btrfs-scrub--`/`btrfs-scrub-data`/`btrfs-scrub-mnt-pool` — snapshots.nix-rendered unit files systemd never starts (weekly timers pull the template instances `btrfs-scrub@-`/`@data`/`@mnt-pool`; proven via `systemd.targets.timers.wants` eval + live service-health listings + journal). Every trip's scrub stop was a silent no-op through the 5.9 TB storm.
   - Sibling bug, same root cause: the scrubGuard deferral override documented live in AGENTS.md since 2026-08-31 was dead code the whole time (same stray attrnames) — the Sep 26–28 storm scrub ran RAW.
2. **Fixes landed** (daemon-committed `777fa972` + `31392dbf`):
   - `memory-emergency-guard.nix`: churn list → the three template instances; re-arm EXCLUDES `btrfs-scrub@*.service` (no-resume, freeze-#7 loop) with a disclosure line; guard-side explicit `btrfs scrub cancel` evaluated and REJECTED (needs CAP_SYS_ADMIN the unit deliberately lacks; ExecStop already cancels inside the scrub unit's own sandbox).
   - `snapshots.nix`: scrubGuard ExecStart override moved onto the template with `%f` (expands to the mountpoint per systemd.unit(5)); the three stray unit definitions vanish from the config (eval-verified).
   - `tests/test-memory-emergency-guard.nix`: dummy `btrfs-scrub@` template (Type=simple + ExecStop marker); scenario 8 = trip stops the INSTANCE + ExecStop ran; scenario 8a = re-arm restarts balance but NOT the scrub.
3. **Docs landed:** AGENTS.md ×3 (BTRFS §Scrub dead-code correction + stray-attrname lesson; Zone-6 churn-stop semantics; Freeze #7 entry), runbook `docs/services/memory-emergency-guard.md` Zone-6 section rewritten, `docs/todo/stability.md` + `TODO_LIST.md` (3 rows closed incl. the freeze-7 re-arm-exclusion item, 1 new [ready] stray-unit-lint backlog item in both files).
4. **Verification:** evo-x2 toplevel eval green; `nix flake check --no-build` green; guard script derivation builds (shellcheck) with instance names + case-skip + disclosure line verified in the built artifact (`bash -n` OK); rendered `btrfs-scrub@.service` verified (guard ExecStart `%f`, ExecStop preserved, `Type=simple`, upstream `SuccessExitStatus=1` noted).
5. **VM test executed GREEN** (`checks.x86_64-linux.memory-emergency-guard`, run in the session's only calm window on top of the re-fire's scenario-9 fix).
6. **Footer commit `2ef4073a`** landed (close-out report update; gitleaks + pre-commit green). Close-out report: `docs/status/2026-09-30_06-29_task-…_scrub-stop-phantom-closeout.md`.

## b) PARTIALLY DONE

1. **Live post-deploy verification not possible from an agent sandbox:** the cancel path is proven by unit-file reading + VM test, but a real Zone-6 trip cancelling a REAL running scrub on the host needs the deploy (owner-run) + one trip with an active scrub. Escape condition documented in the close-out (§ Deploy notes).
2. **Session hygiene under the daemon race:** every file edit got absorbed by the auto-commit daemon within ~10 min; only the final footer commit carries my message. History is correct but attribution is diff-archaeology, not `git log` prose. Partially mitigated by embedding the Task-Queue-ID inside the TODO row texts themselves.
3. **The stray-unit lint I queued is only an idea** (backlog row + design caveat); zero code exists.

## c) NOT STARTED

- **Deploy** (owner-run, per house rule). Deploy notes: the changed template unit file will make stc restart the currently-FAILED `btrfs-scrub@-`/`@data` instances; scrubGuard re-checks PSI/zram/heavy-readers at start (defer under pressure). Expect the chronic-FAIL exit-4 hazard (01-45 §f.12) at most once; upstream `SuccessExitStatus=1` (already in the rendered unit) defuses it further.
- **The rest of the freeze-7 program** (queued, other lanes): scrub timers `Persistent=false` + serialization/staggering; scrub completion metric + Gatus staleness; trip-rate escalation page; guard-silence root-cause (09:56 boot); post-freeze storm-drain verification; project-discovery-daemon admission control.

## d) TOTALLY FUCKED UP

1. **Two broken PSI-poller one-liners burned ~50 minutes and MISSED a real calm window** (polls at avg60 16–18% skipped because `awk -v a="avg60=16.42" 'a<30'` compares STRINGS — "avg…" > "30"; the second poller's awk was mangled by shell quoting and declared "WINDOW OPEN" on EMPTY values). Third version (grep+cut + explicit `exit !(...)` numeric gate + 2-consecutive-poll requirement) worked. Lesson recorded in the close-out §d: dry-run a gate script ONCE before trusting it; write pollers as repo scripts, not quoting-sensitive one-liners.
2. **Git hunk-splitting dance was clumsy** (awk patch extraction → "garbage"; sed-range patch → "does not apply"; add/remove-row dance left a staged-vs-worktree split needing `git restore --staged`). The right sequence — check `git show --stat HEAD` FIRST, then amend-vs-new-commit — was eventually applied but only after wasted cycles.
3. **Batched edits instead of per-file immediate commits** — the ~10-min daemon cadence absorbed every file into heuristic commits before I could footer-commit them; correct pattern (now obvious in hindsight): commit each file immediately with a pathspec.
4. **My close-out report briefly claimed the VM test "deferred" while the re-fire session had already run it RED→fixed→green** — I authored at 06:29 without noticing `bd4d4078` (06:27) existed; corrected the report before the footer commit, but the initial version would have contradicted the other session's report. Report-time tree-state check should have been step zero.
5. **Did not append the new backlog items in the SAME commit as the queue close-outs** — they rode separate daemon commits, momentarily violating the "queue and library must not drift in one change" ideal (both files were edited together, but committed apart).

## e) WHAT WE SHOULD IMPROVE

1. **Eval-time stray-unit lint** (queued): flag `systemd.services.<name>` definitions that are not templates, carry no wantedBy, and are referenced by no timer/unit — this one lint would have caught BOTH this task's bugs (churn-list names AND the dead deferral override). Warning-grade; needs a template/manual-start allowlist.
2. **Reflex: before trusting ANY `systemd.services.<name>` override, eval the timer's wants (or `systemctl list-unit-files`) to confirm the overridden attrname is a unit something actually instantiates.** Now encoded in AGENTS.md; making it a scripted check is item f.1.
3. **Repo-owned PSI gate script** (`scripts/wait-io-calm.sh` or similar) with fixture-tested numeric parsing — three session-written pollers, two broken.
4. **Per-file immediate pathspec commits as the default for agent sessions on this tree** (daemon absorbs batched work; multi-session races are the norm, not the exception).
5. **Report-time protocol: `git log --all --grep=<task-id>` BEFORE authoring a close-out** — catches re-fires/parallel sessions claiming the same queue item.
6. **The `btrfs-scrub` unit family deserves one documented owner** — template (nixpkgs) vs deferral wrapper (snapshots.nix) vs churn list (guard) vs failed-state cleanup (service-health) currently live in four files; the runbook now describes the shape but a single "scrub lifecycle" doc section would prevent the next stray-name incident.

## f) NEXT THINGS (in-lane first; ~50, several already queued in the library — listed for completeness)

1. Stray-unit eval lint (queued this session): non-template service definitions with no wantedBy and no referencing timer/unit → warning.
2. Deploy the landed fix (owner) and watch the first Zone-6 trip: `btrfs scrub status` must show the scrub CANCELLED (proves ExecStop cancel end-to-end on real hardware).
3. Post-deploy: verify the re-arm path restores btrbk/balance but NOT scrubs; confirm the disclosure line appears once.
4. Post-deploy: confirm the stray unit files (`btrfs-scrub--.service` etc.) disappear from `/etc/systemd/system` after the switch.
5. Scrub timers `Persistent = false` (queued) — boot catch-up fired all three scrubs 24 s into the 09:56 boot.
6. Serialize/stagger the three scrubs (`After=` chain, root first) (queued).
7. Scrub completion metric (`btrfs_scrub_last_completed` per fs) + Gatus staleness (queued).
8. Guard trip-rate escalation page (`trips_last_hour`/per-boot threshold → notify "guard is load-bearing") (queued).
9. Root-cause guard silence in the 09:56 boot (0 trips at avg60 79%; stale io-ticks baseline vs eval blindness) (queued).
10. Post-freeze storm-drain verification + remaining drivers (project-discovery 7.1 GB/7 min, nix-daemon build, hermes 3.3 GB) (queued).
11. project-discovery-daemon into `ioChurnUnits` or heavy-job-gate its du-walks (queued).
12. Backup-starvation audit Sep 27–29 (432 trips vs btrbk sends; catch-up slot behavior) (queued).
13. Root-cause the `btrfs-scrub@data` exit-1-after-"no errors found" FAILED state + clear it (parallel lane now carries `SuccessExitStatus` follow-up) (queued).
14. `btrfs-scrub@data` re-FAILs weekly on exit 3 while the known csum errors persist — decide alarm vs accept until T04–T08 (queued [decision]).
15. Guard Zone 6 flm-exemption design (owner decision) (queued).
16. Zone 6 alert fatigue — Discord cooldown/escalation-context half remains open (queued, PARTIAL).
17. Kill or legitimize the hermes-cron-resurrected llama-servers + durable guard (queued).
18. ExecPrint the ioChurnUnits list at guard start into the journal (drift detection: a future rename silently no-ops stops again — the exact class fixed here).
19. Guard-side assertion that every `ioChurnUnits` entry matches a unit file that a timer/template actually references (module-level, cheaper than the general lint, catches this class for the guard specifically).
20. VM test: scenario for a guard stop while a scrub unit is FAILED (stop resets failed→inactive; assert no exit-4 interaction).
21. VM test: scenario asserting the ExecStop marker is written when the guard stops the instance DURING the cooldown window (stop still fires outside the 600 s action cooldown — verify semantics).
22. Consider `OnFailure` on the scrub template instances? (upstream-owned; evaluate whether a failed scrub should page via service-health only — current state OK, document it).
23. Re-verify the `btrfs-health.nix` deferred-vs-wedged logic (line ~336 greps the churn file for 'btrfs-scrub') against the NEW instance names — it starts working now; confirm the metric semantics hold.
24. After deploy, refresh the AGENTS.md BTRFS §Scrub "DEPLOY REQUIRED" remnants if any docs still describe the old stray-unit shape (grep `btrfs-scrub--` repo-wide once post-deploy).
25. Docs: one "scrub lifecycle" section (template → deferral wrapper → churn stop → cancel → re-arm exclusion → weekly resume) — single owner for the whole chain (see e.6).
26. Make `scripts/wait-io-calm.sh` (repo PSI gate, fixture-tested) so agent sessions stop hand-rolling pollers (see e.3).
27. Add the poller lessons (string-vs-number compare; empty-value false-positives) to `docs/CONTRIBUTING.md` "Verification conventions" or the lessons file.
28. Sweep other `systemd.services` overrides for the same stray-attrname class (manual grep + eval of every `serviceConfig.*` override vs instantiated units) — one-time audit, likely finds nothing, cheap insurance.
29. Queue-drift check: confirm the stability-library row for the f.12 FAILED-state item and the re-fire-3 report agree on status (I did not reconcile; different lane).
30. Confirm `docs/services/memory-emergency-guard.md` "How to re-arm btrbk manually" section still accurate post-exclusion (it never mentioned scrubs; now also mention the scrub manual-resume command exists there — I added it; verify it renders).
31. After deploy, watch one full weekly scrub window: all three scrubs should now DEFER under pressure and run cleanly in quiet windows (the first time the deferral guard has ever actually run).
32. SigNoz: consider a panel for `memory_emergency_guard_churn_units_stopped` (per-unit) — forensics visibility parity with Gatus.
33. Gatus: the "Memory Guard Backup Starved" check was planned in the 01-45 report (§b "Monitoring wiring… not inserted") — confirm landed or queue it.
34. Verify `checks.x86_64-linux.memory-emergency-guard` in CI (nix-check.yml) actually runs VM tests or only evals — my green run was local; CI coverage unknown to me.
35. Update `docs/services/memory-emergency-guard.md` metrics section if the re-fire changed metric emission order (their fix moved computation; docs may name the old order).
36. Confirm the re-fire-3 report + my close-out do not contradict each other on the scenario-9 story (mine references theirs; a one-line cross-check suffices).
37. Change-log: the guard CHANGELOG entry was refreshed by the re-fire (1e074bbc) — verify no other stale "deploy remain open" phrasings remain in guard docs.
38. `sev1 notify-tier for backup_starved` (queued in 01-45 §f.13) — still open?
39. Resurrection detector (port-holder probe metric) — queued in 01-45 §e.4, still open.
40. Tmpfs trash hygiene: nothing this session, but /tmp scripts created (`/tmp/full.patch`, `/tmp/h1.patch`, `/tmp/my-todo.patch`, `/tmp/their-row.txt`) were trashed — verify no strays remain (they were trashed inline; belt check next session).
41. Re-run `nix flake check --all-systems` once on a quiet box (my run was x86_64-only; the darwin-side eval delta for my changed files is small but unverified).
42. Consider bumping `docs/status/2026-09-29_01-45_…` §e.2 with a one-line "RESOLVED (verdict corrected), see close-out" pointer so future harvests don't re-queue it (the TODO row is [x], but the source report's §e.2 line still reads open).
43. Same for the freeze-7 report §f.1 (re-arm exclusion) — pointer to the landing commit.
44. Guard module header comment: the 884-line header's churn narrative still says "balance/scrub timers re-fire on schedule; nothing is lost" — now WRONG for scrubs (they do NOT re-fire until the weekly window); one-line correction.
45. `systemd-shape-audit`/`start-limit-audit`: confirm the dummy VM template (`btrfs-scrub@` with ExecStop) doesn't trip any audit in --all-systems mode (my flake check was `--no-build` x86_64; cheap re-check).
46. Owner question pending from re-fire-3 (their §g) — merge their open questions with mine in the next owner pass so the queue gets one coherent answer set.
47. CHANGELOG prune pass: three [x] rows landed in TODO_LIST this session (this task + freeze-7 re-arm + AGENTS-entry) — the periodic prune-to-CHANGELOG pass will pick them up; nothing to do now.
48. After the deploy, archive the deployed-generation diff (`nvd diff`) into the close-out report for the record (optional, house habit varies).
49. Backlog hygiene: the new stray-unit-lint row exists in BOTH files — confirm the check-todo-system gate passes on them (pre-commit ran green on my footer commit; the rows predate it in daemon commits — one explicit green run of `scripts/check-todo-system.sh` would close it).
50. Next dispatch reading order fix (from re-fire-3's lesson + mine): "verify against AGENTS.md changelog first" for handoffs — both sessions independently re-derived context the other had already settled.

## g) QUESTIONS (cannot resolve myself)

1. **Deploy bundling:** do you want this deploy to carry ONLY the guard/scrub fix, or bundle the remaining freeze-7 scheduling half (`Persistent=false` + serialization, items f.5–6)? My exclusion is in-tree now; deploying it alone leaves the boot catch-up storm class open — fine, but I cannot tell whether you want one deploy or two.
2. **CAP_SYS_ADMIN belt-and-suspenders:** I rejected a guard-side explicit `btrfs scrub cancel` (the guard deliberately runs with `CAP_FOWNER CAP_DAC_OVERRIDE` only; ExecStop already cancels in the scrub unit's own sandbox). Do you accept that verdict, or do you want the guard to also cancel explicitly (requires widening the guard unit's caps)?
3. **The re-fire-3 handoff:** `bd4d4078`/`1e074bbc` continued this task after my dispatch — is the task now CLOSED for the queue (both commits carry the ID), or do you want the still-open §f items above (esp. 18, 23, 42–43 doc pointers) folded into one final pass before closing?

---

**Self-check:** no secrets written (gitleaks green on the footer commit); no pushes; no `.crushrc`/`crush.json`/`.tq-verify` touched; tree left green (`nix flake check --no-build` + VM test green at last run; three unrelated dirty files from a parallel session left untouched).
