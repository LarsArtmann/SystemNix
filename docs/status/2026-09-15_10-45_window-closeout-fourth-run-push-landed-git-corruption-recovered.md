# Window closeout — FOURTH run: push landed, git-corruption recovery confirmed, third run's TODO harvest was claimed but never landed

**Date:** 2026-09-15 10:45 CEST
**Queue task:** 000001a0a1f149f8469390a3b300fddf0914 closeout — this is the **FOURTH run** of the same closeout (first: `docs/status/2026-09-15_06-10_*`; second: `07-32_*`, committed `7ebb0863`; third: `09-22_*`, committed via daemon `17acfe3d`). This run is **delta-first**: it re-verified the third run's claims against the 10:40 tree, found three genuinely new facts (the master push landed; the git zero-byte corruption was recovered while this very task was being requeued on it; the third run's TODO_LIST appends never landed despite being claimed), and re-harvests what was lost.
**Window under report (unchanged from prior runs):** 2026-09-14 00:37 → 03:11 (tq facts 2981–3110), five tasks, all `task.completed`.
**Method:** `git log`/`git show`/`git merge-base --is-ancestor` on every cited SHA, `git fsck --full` (clean; dangling objects only), `tq facts` against `/mnt/pool/services/tq/tq.db` (facts 3617–3627 re-read this run), read-back of TODO_LIST/CHANGELOG/AGENTS and the three prior closeout reports. No invented history.

## a) FULLY DONE (window tasks, re-verified at 10:40)

1. **The five window tasks are complete and their content is durable in reachable history** — the third run's verification table stands re-confirmed: the `InvokeNamed[interface]` sweep (17 repos, zero live traps, cmdguard row present in the archived report), the crash3 IO-PSI/disk-%util correlation in `scripts/deploy.sh` + `_signoz-metrics.nix` (`node_psi_io_phantom`, `node_disk_busy_percent_max`) + the phantom-filtered Gatus check, guard Zone 6 (io-PSI avg60 ≥40% with io_ticks corroboration, churn-unit stop-list, live-fired 14+ times in freeze #4), and both reviewer-fix tasks (gitleaks-report correction; cmdguard row + count 17). All five original commits (`695ffda8`, `1483bde0`, `5daa85cc`, `bc2d399c`, `449ef806`) remain dangling; all seven reachable counterparts cited in the 09:22 report remain reachable.
2. **NEW — the master push LANDED (~09:21).** `origin/master` is at `689e6c10` (2026-09-15 09:21:37 +0200); the ~39-commit GH013 backlog that the 09:22 report flagged as stuck is now on origin. Only `17acfe3d` (this morning's daemon commit) is unpushed. The GH013 push-protection block is resolved in practice. This closes the third run's §c.4 headline (the _report_ is now pushed too: the third-run report itself rode `17acfe3d`, which is NOT yet on origin — see §b.3).
3. **NEW — the 2026-09-15 git zero-byte object corruption was RECOVERED, with prevention landed.** This run has first-hand evidence of the incident's tail: `tq facts` 3618/3620/3622/3624/3626 show `task.requeued … preflight: git status failed … object file .git/objects/4f/0b9081… is empty` from 10:11:56 to 10:25:54 — **including this closeout task itself, requeued twice** — and by 10:40 the object file is gone, `git status`/`git log`/`git fsck --full` are all healthy, and the recovery + prevention (`core.fsync = "loose-object,index"` in `platforms/common/programs/git.nix`, full runbook in AGENTS.md "Git zero-byte object corruption") are committed in `17acfe3d` (10:35:46). A parallel session executed the AGENTS runbook while the queue was thrashing on the broken tree.
4. The window's TODO closures have correctly graduated to CHANGELOG (no `[x]` residue; Zone 6, PSI correlation, and the sweep all carry Unreleased entries).

## b) PARTIALLY DONE

1. **The third run's TODO_LIST harvest is MISSING.** Its report claims "New this run (appended to TODO_LIST, 5 work items + 2 blocked questions)" — grep of TODO_LIST for any of the five (GH013 unblock, pre-push history scan, purge-runnable check, `.tq-verify` rail commit check, second-scanner lint) returns **zero matches**; the last dated sections are "Added 2026-09-15 06:10" and "Added 2026-09-15 07:32". The report landed; the appends did not. This run re-appends them (adapted to the post-push reality — the unblock item is now a verification item, not an action item).
2. **Zone 6 deployed-state verification** remains open exactly as the 06:10 run harvested it (parity, metric liveness, VM-test rebuild, counter-reset tolerance, notify-tier routing — all still open in TODO_LIST, all still valid).
3. **`17acfe3d` is not on origin** — it carries the third-run report, the AGENTS corruption runbook, the `core.fsync` prevention, and (mixed in by the daemon) a parallel session's `modules/nixos/services/nix-email.nix`. The next push carries all of it.
4. **The 08:50 session's tq env fix is still committed-but-not-live** (pool restart + DLQ rescue gated on the next deploy / `/nix` soak ~2026-09-17); sibling dead-letter `000001a09d2b6d052` still awaits it.
5. **The held gitleaks purge** (the fabricated `120ada36` sentence): re-verified `git merge-base --is-ancestor 120ada36 origin/master` → **true** — the sentence is now on ORIGIN, which is expected (the push moved normal history; only a push-time re-filter or key rotation kills it), but it means the purge decision is now live-facing rather than theoretical. Unchanged doctrine: rotation is the real fix.

## c) NOT STARTED (skipped; none owned by the window's five tasks)

1. Repo-generic CI do-analyzer (provide/invoke pairing lint) — TODO item open, untouched.
2. Zone 6 threshold recalibration, `zone6_churn_units_stopped` forensics metric, SigNoz dashboard surfaces, runbook entry — all harvested, none started.
3. The owed evo-x2 reboot (flm :52626 corpse) — untouched, correctly.
4. The llama.cpp gfx1150 mid-load-spin pin-back/bisect (RAG dark since 2026-09-14) — untouched.
5. The deploy of the scrub-mechanism fix (`lib.getExe scrubGuard`) + the /data gate-(b) scrub — still deploy-gated.

## d) TOTALLY FUCKED UP

1. **A "claimed but not landed" docs write in the third run** — the strongest possible argument for the "closeout runs verify the footer commit landed" rule: even when the commit DOES land (it did, in `17acfe3d`), a multi-file append can silently half-land when the daemon batches a parallel session's files. Every future closeout must diff its claimed TODO appends against the file, not trust its own report text. (Fixed this run — the missing items are appended for real.)
2. **The git corruption class struck a second tree state the same morning it was documented**: the boot death (09:32:40) tore the objects; the wedge persisted until ~10:30; the tq pool burned ≥5 claim/requeue cycles (three different tasks) on a preflight that cannot distinguish "repo corrupted" from "repo busy". Net effect: the queue starved its own recovery work for ~an hour. The AGENTS runbook + `core.fsync` fix are correct and landed; the queue-level resilience gap is new (see §f.8).
3. **Five dangling SHA citations from one window** (standing, annotated three times now) and **two reviewer-rejection loops for 30-second slips** — both remain the window's process scars; the citation rule and transcript rule are in TODO_LIST awaiting adoption.
4. **The `120ada36` sentence is now on origin** (§b.5) — not a regression (nothing got worse), but the "held" state now has public exposure it didn't have before the push. The purge runbook's push-time re-filter step is the only remaining execution path.

## e) WHAT WE SHOULD IMPROVE

1. **Closeout runs must verify their own writes post-commit** (grep TODO_LIST for the claimed appends; `git show --stat` the footer commit) — the 09:22 run is the cautionary tale, this run is the pattern.
2. **Delta-first closeouts:** this fourth run cost ~1/3 of the third run's effort by re-reading instead of re-deriving. The queue-level dedupe question (owner) becomes more valuable with every run.
3. **tq preflight needs a corrupted-repo lane:** on `git status` failing with object errors, requeue-with-delay + a distinct reason (or alert) instead of hot-looping claims every 3–14 minutes.
4. **Multi-writer commits need per-file provenance:** `17acfe3d` mixes the closeout report, the corruption runbook, and a parallel session's `nix-email.nix` — the daemon-footer convention item (still open) covers the class.
5. **Post-push secret verification:** the push landed without the pre-push history scan the third run planned; a post-hoc run of `scripts/scan-history-secrets.sh` over the pushed range closes the gap retroactively (appended).

## f) NEXT THINGS (delta only — the 06:10/07:32 sections above remain open and are not duplicated)

Appended to TODO_LIST as "Added 2026-09-15 10:45" (7 work items + 2 blocked questions):

1. Verify post-push CI is green and close the GitHub secret-scanning alerts for the four templated-fixture locations.
2. Post-hoc `scripts/scan-history-secrets.sh` over the pushed range (the pre-push scan never ran).
3. Verify the `.tq-verify` rail edits in `~/projects/CV` + `~/projects/go-taskqueue` actually got committed.
4. Mechanical second-scanner lint (pre-commit + CI) rejecting tracked literals matching known push-protection patterns unless templated; template the two remaining literal fixtures.
5. Reconcile the corruption timeline (AGENTS says runbook executed; tq shows the wedge until ~10:30) and confirm `core.fsync` reaches the deployed gitconfig (needs a deploy).
6. Confirm the held purge runbook is now executable at the push point — or formally retire it (blocked, owner).
7. Confirm the third run's own report/append pair is complete on origin once `17acfe3d` pushes.
8. (blocked) Push scope settled itself (the push landed as-is) — the remaining owner question is whether the next push waits for the nix-email session to stage its flake.nix/flake.lock edits.
9. (blocked) Closeout dedupe/rate-limit at the queue level — now four runs.

## g) QUESTIONS FOR THE OWNER

1. **Purge disposition:** with the backlog now pushed and `120ada36` on origin, do you want the held purge runbook executed at the next push point (re-clone + re-filter + force push), or formally retired in favor of key rotation only?
2. **Closeout contract:** four runs of the same closeout today; should repeated closeouts be deduped/claimed/rate-limited at the queue level, with "delta-only" as the re-run contract?
3. **nix-email mid-flight:** the unstaged `flake.nix`/`flake.lock` edits (new `nix-email` input) belong to a parallel session — should other sessions treat that input as settled (and may docs closeouts reference it), or is it still in flux?

## h) BAND DRIFT

`tq facts` grepped for `task.reprioritized` across the **entire journal** (3,627 facts, re-read this run): **zero matches. None recorded.** Queue movement in and around the window was lifecycle churn only: the five window tasks went enqueued → claimed → completed; this closeout task itself was claimed at 10:11/10:22 and requeued twice on the corrupted-tree preflight before its 10:39:59 claim succeeded (facts 3621–3627); sibling tasks `000001a0a3164497…` and `000001a0a3165fe9…` were requeued on the same preflight (facts 3617–3626). No priorities moved; nothing to explain under ADR-0015.
