# Window closeout: monitor365 batch + btrbk BE/6 watch + reviewer fix wave (2026-11-22)

**Session:** 2026-11-22 15:46 CET (done-prompt closeout)
**Window span:** 2026-11-22 ~03:00 → ~14:30 CET
**Tasks:** 5 (…a1ff786b7a monitor365 runbook refresh; …a2012fe866 + …a202070cf storm-wedge batch (double-dispatched); …a202271815 btrbk BE/6 watch; …a2022ba94c896 reviewer finding)
**Dispatch-time dedup:** docs/status/README.md index + window reports grepped for the span and all 5 task ids — no prior window report covers this window (the newest, `2026-11-21_19-57_window-reverify-monitor365-batch-plus-reviewfix-wave.md`, covers the 2026-11-21 02:14 five-task window). FULL PASS.
**Closeout reports read first (per contract):** `docs/status/tasks/2026-11-22_08-02_task-000001a202070cf…md`, `docs/status/tasks/2026-11-22_10-30_task-000001a202271815…md`, `docs/status/tasks/2026-11-22_14-21_task-000001a2022ba94c896…md`, plus landing commits re-verified with `git show --stat` at HEAD `1f1517f8e`.

---

## a) FULLY DONE

1. **monitor365 runbook refresh (…a1ff786b7a)** — five-item docs batch on `docs/services/monitor365.md`, landed 03:1x–03:27: owner-stop incident recorded with sudo receipts (`fd3e1224f`), nsfw + mr-sync state check closed (`a0c0ef2e5`), the +0.8 GB growth anomaly dissolved (`210396b65`), and item 5's DuckDB memory_limit tune closed as ALREADY SHIPPED 2026-10-25 (server DuckDB capped 4 GB under a 6G/8G watermark-coherent cgroup, live-verified gen-1021: 657 MB current, high=0, oom_kill=0; DB shrunk 13.09→3.85 GB by the 11-21 compact) with all three premise legs of the old 4G/3G/25 GB item superseded — rows ticked with fresh evidence (`f9b0d027de`).
2. **monitor365 storm-wedge SystemNix-side fix (…a2012fe866 / …a202070cf, double-dispatched)** — `ioTier.heavyDB` (BE/5) serviceConfig on monitor365-server (`modules/nixos/services/monitor365.nix:630`) + start-limit widened to burst 10 / interval 300 (`mkForce`; the NixOS default burst of 5 parked the unit failed after rapid storm re-kills; upstream `Restart=always`/`RestartSec=5` was already present) — landed `afecf20d6`. Phantom-red `monitor365-backup.prom` orphan purged via idempotent tmpfiles `r` rule (`619939b7f`, rule at `backup-coordination.nix:157`). dnsblockd `/etc/hosts`-shadow runbook pointer verified landed (`5b346bb8d`, section at `docs/services/dnsblockd.md:19`). bootmetrics `transaction_open` OPEN-path fixture landed (`cc3c8f2ce`) AND actually built green this window (`nix build .#checks.x86_64-linux.bootmetrics-openpath-selftest`). The re-dispatch session (08-02 report) verified all four landings in-tree and ticked the four queue rows (`9edb71f85`, `5e1337bc5`, `6d6cb28e1`, `b0d76fe9b`); the deploy leg was pre-queued (`fd769ada4`).
3. **btrbk BE/6 + compsize first-night watch (…a202271815)** — journal sweep over boot 0 (Nov 13→22): all five BE/6 send legs hold their windows (root 6m06s, pool 5s, forgejo 36s; zero TimeoutStartSec hits), last green runs Nov 16/17 post-deploy; compsize has NEVER fired green post-deploy (0 Started vs ~38+ consecutive admission REFUSEs; 2,040 memory-emergency-guard trips in 9 days = chronic storm starves BOTH the nightly sends since Nov 19 and the idle-tier gate since deploy). Watch row ticked with the narrative (`5160a63d9`); starvation fix queued as its own `[ready]` row (TODO_LIST 524).
4. **drive-paperless e2e VM test (same 10-30 session, item 2)** — `checks.drive-paperless-e2e` green against REAL paperless + real immich: token mint, machine-key provision + scoped validation, 3-asset ingest with full metadata contract, idempotence. The first green run caught TWO live module bugs fixed in `b15d03ec8`: (1) `ingestImages` scope lacked `user.read` — Immich gates `GET /users/me` on it (source-verified); images go-live would have failed day one; (2) the token-mint EACCES on every re-run (foreign-owned `/run/drive-paperless/env` cleared by a root ExecStartPre). Stale scope strings fixed in 3 more sites in the closeout. Go-live rows (items 3/4/5) correctly left BLOCKED on owner-held OAuth inputs (`7edc9fa60`).
5. **Reviewer finding (…a2022ba94c896)** — the bootmetrics wiring attribution correction landed (`765d7fa87` + `8eea4f100`): TODO_LIST row 521 and `docs/todo/stability.md:204` both now name daemon commit `95fd92e85` as the real wiring commit with the `git show --stat` evidence command; attribution report written; the session's own daemon-race incident (bare amend swept 3 foreign files) caught and repaired per the reset-soft + pathspec recipe with zero damage.

## b) PARTIALLY DONE

1. **The storm-wedge fix is tree-only until the next deploy** — ioTier isolation, start-limit widen, phantom-prom purge, and the ioTier precedence/perms follow-up fixes (`1f1517f8e`, see d.1) all await the next owner-gated PSI-calm deploy; the 89 flaps/24h thesis is unverified on-host (watch row 3849 queued).
2. **Post-deploy battery (2026-10-17 row, item 5 of the 08-02 batch)** — its five probes need a live host; annotated BLOCKED, verification queued into the deploy leg.
3. **Drive/Immich go-live (items 3/4)** — module side fully landed + e2e-proven; the `google-sync.enable` flip is gated on owner OAuth client + sops secrets. The wiring's post-deploy battery shrinks to live-host confirmation since the VM test covers three asserts in miniature.
4. **Reviewer-derived lint evidence** — the attribution report's "re-checked" claim is reviewer-derived, not first-hand (the 2-minute standalone re-run is queued, TODO_LIST 3863).

## c) NOT STARTED

1. **compsize idle-tier starvation FIX** — diagnosed and queued (row 524: catch-up slot vs dampened band vs last-success-age override), not implemented.
2. **btrbk-data last-green determination** — NO green run anywhere in the Nov 13→22 window while siblings have Nov 16/17 greens; journal retention vs longer starvation unresolved (row 3853).
3. **Upstream monitor365 shutdown-drain fix** — push-gated to the upstream repo, correctly stays rowed, untouched.
4. **Paging leg during the send drought** — whether Gatus backup-freshness checks fired/alerted Nov 19-21 unproven (row 3854).
5. **VM-test legs for batch-cap / missing-source / 403-negative** (rows 3855-3858) and the immich fresh-DB admin race decision (row 3857) — queued, untouched.

## d) TOTALLY FUCKED UP

1. **Two live service-module defects shipped with the ioTier batch and were fixed only at 15:35 by a parallel session (`1f1517f8e`, HEAD)**: monitor365-server composed its serviceConfig as `{ ... } // ioTier.heavyDB` — a shallow merge that silently destroys any mkDefault/mkForce priority carried inside the ioTier fragment — and a summit-planner identity DB rendered world-readable. Both fixed in that commit (another session's task; reported here because the batch this window carried them). Lesson: the pre-commit `serviceConfig = X // Y` grep leg exists but did not fire on this form.
2. **The daemon-race miss that spawned task …a2022ba94c896** — item-5's wiring rode heuristic commit `95fd92e85` while item commit `cc3c8f2ce`'s message claimed it; no `git show --stat` before declaring done. Repair cost ~3× prevention (two further commits + a correction report + a reviewer cycle).
3. **Two bare-amend foreign-file sweeps in one day** (the 10-30 session and the 14-21 session) — both caught and repaired with zero damage, but the same foreseeable error happened twice after the policy was already in context. The repair recipe works; the reflex does not exist yet.
4. **Four wasted ~5-min VM cycles** in the e2e session (test-helper domain collision, wait_for_unit on oneshots, `''`-string escaping, a statix "fix" that renamed an option and broke eval — caught only by the pre-commit flake-check leg).
5. **The double dispatch of the storm-wedge task** (…a2012fe866 and …a202070cf for the same batch) — the second dispatch still earned its keep (verified + ticked four rows the first session left unticked), but the tick-lag is what made the re-dispatch non-wasteful; see e.1.

## e) WHAT WE SHOULD IMPROVE

1. **Tick at landing time.** Two of this window's sessions landed fixes with full narratives but left their own batch's rows unticked, minting a paid re-dispatch. Rule: the footer commit that lands a fix TICKS its row in the same commit (or names why not).
2. **`git show --stat HEAD` before EVERY amend, mechanically** — twice violated, twice survivable by luck. The queued guard rows (3861 claim-vs-diff, 3862 amend interlock) would make the failure loud; they deserve dispatch priority.
3. **Fragment-composition lint**: extend the pre-commit shallow-merge audit to catch `attrset // moduleFragment` forms where the fragment may carry priorities (d.1's class), with a selftest.
4. **Starved idle-tier gates need starvation observability**: a gate that never opens silently removes its metrics (compsize gauges absent since deploy). Every gated collector should emit a last-success-age gauge.
5. **Read the served binary's source before encoding API contracts** — the `user.read` gap survived a year of fixture-green runs because fixtures stub the API.
6. **`[blocked:deploy]` rows should reference their deploy-leg row** so a deploy session can enumerate them mechanically (queued today).
7. **Report titles within 72 chars on the first commit attempt** — one subject-length retry widened the daemon race window that produced d.3.

## f) NEXT THINGS (up to 50; queued subset appended, dedup-checked)

**Deploy-window cluster (all blocked on the next owner-gated deploy):**

1. Execute the 2026-10-17 post-deploy battery's five probes.
2. Verify ioTier.heavyDB + StartLimitBurst=10 render live (`systemctl show`); confirm upstream Restart=always still coexists with the mkForce override.
3. Confirm `/var/lib/.../monitor365-backup.prom` absent + the replacement backups.prom consumed by a live check (row 3850).
4. Fold the `1f1517f8e` fixes into the same battery (precedence survived, identity DB mode 0600). _(Queued.)_
5. Watch monitor365 gatus flap count 24h post-deploy (row 3849).
   **Storage/storm:**
6. Fix compsize starvation (row 524) — design: catch-up slot vs dampened band vs last-success-age override.
7. Determine btrbk-data's last green send (row 3853).
8. Prove the paging leg during the Nov 19-21 drought (row 3854).
9. Starvation-observability pattern: last-success-age gauge on gated collectors (e.4).
   **Queue/git hygiene:**
10. Claim-vs-diff commit guard (row 3861).
11. Daemon-commit amend interlock (row 3862).
12. Standalone bootmetrics lint re-run for first-hand evidence (row 3863).
13. Sweep other 2026-11-22 LANDED annotations still unticked (row 3852).
14. Annotate row 522's compsize battery leg as unsatisfiable under the starvation (row 3859).
    **Drive-paperless follow-ups:**
15. Batch-cap leg vs real API (row 3855).
16. Missing-source first-boot leg (row 3856).
17. drive-ingest fixture 403 negative leg (row 3858).
18. immich fresh-DB admin race decision + restore-runbook step (row 3857).
19. Move `checks.drive-paperless-e2e` to nightly CI (row 3860).
20. Stale-scope wording refresh in rows 527 (10-30 report §f.9).
21. File:line citation rot in drive-paperless module comments — re-cite controller+decorator form. _(Queued.)_
22. Hands-off VM bootstrap ordering (admin-sign-up before provisioner) if the e2e re-iterates.
    **Docs:**
23. Correction-report discoverability: `*-correction.md` naming convention + README grep line (14-21 report §f.6).
24. Single-source the daemon-race repair recipe (14-21 report §f.8).
25. TODO_LIST prune pass (`scripts/prune-done-todos.sh`, dry-run first) — unchecked mass is large; expect WARNs to rise.
26. Verify commit `fd769ada4`'s deploy-leg row enumerates ALL blocked:deploy legs, not just the storm wedge. _(Superseded by the new enumeration row.)_
27. "Re-verified <date> by <task-id>" append convention on re-dispatch ticks (08-02 report §e.4).
28. Verification-mechanism note in CONTRIBUTING's re-dispatch protocol (08-02 report §e.3).
    29–50. (Refinements of the above — CI wiring details for row 3860, paperless version-skew notes, tq-verdict loudness, fleet-wide daemon-sweep audit — deliberately not itemized to avoid queue noise.)

## g) OWNER QUESTIONS

1. **When is the next acceptable PSI-calm deploy window?** Six verification legs across four batches are blocked on it (storm-wedge, bootmetrics, drive-paperless wiring, ioTier precedence/perms, backups.prom, the 2026-10-17 battery); on a chronically storming box this is an owner-scheduling call. — BLOCKED: when do you want the next `nix run .#deploy`, and should a quiet-window monitor trigger it?
2. **Guard appetite (carried from the 14-21 report §g.1, still unanswered):** claim-vs-diff commit check — blocking pre-commit leg or WARN-only selftest?

## h) BAND DRIFT

**None recorded.** The tq facts journal for 2026-11-22 holds no `task.reprioritized` entries (fact types present: enqueued/claimed/requeued/completed/released/failed/dead-lettered/cancelled/question-asked — no priority-move facts in the window). Priorities moved only implicitly via landing: the storm-wedge cluster drained from [ready] to done/blocked:deploy, and the starvation + hygiene rows it spawned are the new [ready] front.

---

## Queue appends (3 rows, dedup-checked)

Appended to TODO_LIST.md: ioTier precedence/perms post-deploy battery fold-in; drive-paperless file:line citation refresh; blocked:deploy leg enumeration (also serves as §g.1's vehicle). Dedup: rows 3849-3863 already cover flap-watch, backups.prom, starvation, hygiene guards, and the drive-paperless VM legs — no rewords.
