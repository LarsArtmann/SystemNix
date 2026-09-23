# Window Closeout — Review-Fix Round + Borg Verification (2026-09-22 06:21 → 12:42)

**Written:** 2026-09-23 02:01 CEST · **Window:** five queue tasks dispatched 2026-09-22 06:21–12:42, all `completed` in the tq journal
**Tasks:** `…fea350dcfaf06434` (buildcache reap re-dispatch) · `…a690334c899ba5510344aa` (GOTOOLCHAIN guard fix) · `…f761f6779056239de6ae76c9` (restic password UMask fix) · `…943ab3a1f2f046476b881acf` (stale cargo comment re-dispatch) · `…7c71490118972242781061faaa9` (offsite Borg verification)
**Method:** every closeout report read first, then every load-bearing claim re-verified against the tree and the live host (git show, grep, selftest run, file modes). Post-window events (the 13:04 deploy and its recovery) are included because they flip the window's central "runtime-zero" verdict.

---

## a) FULLY DONE (verified, not just claimed)

| # | Item | Evidence |
| --- | --- | --- |
| 1 | **GOTOOLCHAIN guard fix + selftest (task …344aa)** — pre-commit predicate extended to catch the unquoted spaced nix assignment (`GOTOOLCHAIN = auto;`), the drift class the reviewer caught; `scripts/test-gotoolchain-guard.sh` extracts the LIVE predicate from the hook (extraction doubles as a drift tripwire) and pins 3 catch + 3 pass shapes; wired into pre-commit AND `nix-check.yml` ("GOTOOLCHAIN guard selftest" step); TODO_LIST row ticked | work commit `744f3882` (06:38, footer verified); **selftest re-run by this pass: `SELFTEST OK`**; predicate live in `.githooks/pre-commit:177-197` |
| 2 | **Restic repo password 0600 fix (task …e76c9)** — `UMask = "0077"` on `restic-app-dumps-setup` makes the password land 0600 at creation, reconciling the script comment, the AGENTS claim, and the VM test's `mode == "600"` assertion; rendered-unit eval verified at fix time; sibling sweep found restic was the ONLY umask-less secret writer in `modules/nixos/**` (14 sites checked) | fix commit `6251c198` (07:32, footer verified); **runtime proof now REAL: `/var/lib/restic-app-dumps/password` exists on evo-x2 at `-rw-------` (0600), created 13:04 2026-09-22 by the deployed generation — the fix deployed and works** |
| 3 | **Offsite Borg leg implemented + verified (task …faaa9)** — the implementing session landed `platforms/nixos/system/backup.nix` (nixpkgs `services.borgbackup.jobs.hetzner`, 06:30 Persistent, `auto,zstd,9`, prune 7d/4w/6m, `TimeoutStartSec=2d`), the fail-closed PLACEHOLDER tripwire, sops `borg.yaml` (real random passphrase; `1c7e85bc` fixed it being gitignored), the mount-gated `borg-offsite-dir` oneshot on `/mnt/hot`, deploy.sh provisioner wiring, runbook `docs/services/offsite-borg.md`, and ticked the TODO row (`aae1b75a`); the re-dispatch session verified end-to-end: dormant eval leaks zero units, enabled-shape eval materializes job/timer/dir/freshness row, tripwire stays fail-closed | module live on tree (`configuration.nix:57,1159` — `offsite-borg.enable = false`); **deployed dormant in system-796 (2026-09-22 ~14:30)**; reports `316228e9` (12:07) + `6398b256` (12:42) |
| 4 | **Buildcache reap finding verified-landed (task …f06434)** — the re-dispatch correctly made NO change: the fix `d60d598c` (05:28) already carried the footer; clause-by-clause verification (deploy.sh `.cache` loop + non-`.cache` loop unconditional of mount state; usb-recovery step 2.5 mirror) and fix-file byte-identity since the fix confirmed | report commit `a6d079ba`; `git show d60d598c` inspected this pass |
| 5 | **Stale cargo comment finding verified-landed (task …81acf)** — second same-day verification-only re-dispatch: fix `db2b44c0` (07:04, comment-only home.nix reword) already footered; anchor text gone from the tree (survives only as quotes inside status reports); prior 07:15 report annotated with a supersede note | report commit `3b0ad5a7`; grep confirmed zero live-tree hits |
| 6 | **The window's deploy debt CLEARED (post-window, changes everything below)** — the 13:04 deploy forced through two red gates exit-4'd (9 smoke FAILs, profile unanchored), and the 13:07–15:06 recovery session landed system-796: profile anchored, 112 PASS / 0 FAIL smoke, DiscordSync attachments migrated pool-side (20.5 GB content-verified, NVMe source removed), browser-history `SQLITE_READONLY` fixed (DynamicUser uid-drift + ownership-heal ExecStartPre), Health Hub LIVE (missing `wantedBy` was the whole bug), Overview 502 fixed, flm restored | `docs/status/2026-09-22_15-06_deploy-792-recovery-retrospective.md`; this pass independently verified the restic password mode, the three HM cache symlinks (all resolve to store paths since 13:04), and the anchored-generation claim's side effects |
| 7 | **Queue journal audited for the window:** all five tasks `status=completed`, priority 0 throughout, attempts 0–2 | sqlite read-only over `/mnt/pool/services/tq/tq.db` this pass |

## b) PARTIALLY DONE

1. **The GOTOOLCHAIN selftest has never executed in CI.** `744f3882` wired it into `nix-check.yml`, but the main job dies at the statix step BEFORE the selftest (verified live: run `35799069755`, 2026-09-22 23:47 — "Run statix linter" red, every later gate incl. the selftest skipped). Patterns proven locally; the CI-leg proof (06-48 report §f30) is still owed.
2. **Restic feature is deploy-true but not yet backup-true.** Password 0600 verified live; the first nightly run fires 05:45 on 2026-09-23 (after this report). The dedup premise ("per-service dumps share ~0 extents") remains unproven until ≥3 runs; the VM test (`tests/test-restic-app-dumps.nix`, written + eval-verified) has still never executed — PSI-gated since writing.
3. **Offsite Borg leg is dormant by design with open pre-go-live gaps:** no VM test for `backup.nix` (every other backup-producing service has one), no post-deploy smoke, recovery-copy policy undecided, restore drill (TODO_LIST §storage) untouched. Go-live is owner-gated on StorageBox hostname/username + `ssh-keyscan -p 23` host-key pin.
4. **The reap-discipline cluster is fixed but unguarded.** All four reap surfaces now agree (the deploy ran the reap live at 13:04 — the symlinks exist), but the name set still lives in four hand-kept lists with no parity enforcement, no regression test for either reap site, and `buildcache-init` still does not provision the three new targets (post-USB-recovery the symlinks dangle until the next deploy).
5. **Lineage closure (06-21 report §b.3):** storage.md rows 80/82 and the TODO_LIST:21 parent note still do not cite `d60d598c` as the review-fix completion (storage.md is outside this pass's write scope; queued).

## c) NOT STARTED (the window skipped; still open)

1. **CI repair — the two stacked red classes the 06-48 report discovered are BOTH still live (re-verified 2026-09-23 02:00):**
   - statix `[04]` on `modules/nixos/services/hot-user-caches.nix` (`device = cfg.device;`) — kills the main job and skips every later gate;
   - VM-test jobs fail fetching `ssh://git@github.com/LarsArtmann/branching-flow` (deploy key not loaded in the vm-tests job);
   - a THIRD red is now visible on recent pushes: **`secret-history-scan` fails on the scanner's own canaries** — the historical `leak-canary.tmp.md` blob and the `sk-00000…` fixture shapes quoted in `docs/status/2026-09-15_07-32_window-closeout-rerun-gitleaks-rewrite-regression.md` (verified in run `35799069770` logs).
   - Master CI has therefore provided zero signal for ≥2 days while commits kept landing.
2. **GOTOOLCHAIN predicate single-sourcing:** the CI "Flake input hygiene" step (`nix-check.yml:156`) and the orphan `scripts/check-flake-inputs.sh:37` still carry the OLD bare `GOTOOLCHAIN.*auto` grep that false-positives home.nix's fish session override — the exact class `744f3882` fixed in the hook. Three copies of the predicate, two stale.
3. **Offsite Borg restore drill** (TODO_LIST line 28) — "a backup you have never restored is Schrödinger's backup".
4. **Restic post-deploy proof chain** (TODO_LIST line 43) — first run + `restic check` + one-file restore smoke + dedup measurement.
5. **Queue re-dispatch idempotency** — the window contained THREE re-dispatches of already-closed work (…f06434, …81acf, …faaa9), each costing a full session to conclude "already done". Owner-side queue work (TODO_LIST lines 167/174/260 track it).
6. **`buildcache-init` provisioning, reap single-sourcing + parity gate, mountPoint-vs-HM-symlink eval guard, buildcache VM-test rebuild** — all still open in TODO_LIST §storage (lines 41/42/34 + the library).
7. **`$DRY_RUN_CMD` ratification for the HM activation `rm -rf`** — still blocking the audit-script design (08-03 report question 3).

## d) TOTALLY FUCKED UP

1. **Master CI is dark and nobody owns it.** ≥6 consecutive red pushes on 09-21 (06-48 discovery), still red at 02:00 today with now THREE stacked independent failures (statix, VM ssh fetch, secret-scan canaries) masking each other. The 13:04 deploy was then **forced through two of the red gates** — which is exactly the failure mode red CI exists to prevent (and indeed the forced activation exit-4'd with 9 failures). No tripwire pages on consecutive reds; the queue kept dispatching into a repo whose CI proves nothing.
2. **The window's flagship CI deliverable is invisible.** The GOTOOLCHAIN selftest step wired by `744f3882` has never run on a runner (skipped behind statix). A guard fix that CI cannot execute is guard-rail theater until CI heals.
3. **Three full agent sessions burned on re-dispatched-already-done tickets** (≈06:24, ≈08:03, ≈12:42 dispatches). Each behaved correctly (verification-only, no invented commits — the right call), but the queue paid three sessions for zero delta. The repo cannot fix this; the owner can (footer-scan preflight).
4. **The secret-history scanner is red on its own test fixtures.** `leak-canary.tmp.md` (a deliberate canary committed ~2026-08 era, since removed from the tree but not from history) and the `sk-00000…` synthetic shapes quoted in a 09-15 report now fail the full-history scan. The scanner works; its allowlist doesn't know its own canaries. Also a standing GH013 hazard: those shapes are exactly the class GitHub push-protection pattern-matches regardless of local allowlists.
5. **Small residue from strict minimalism (inherited, tracked):** the restic script comment still attributes the mechanism to "umask 077" (it lives on the unit); no standalone CHANGELOG entry existed for the 0600 fix or the Borg implementation until this pass; storage.md lineage citations owed.

## e) WHAT WE SHOULD IMPROVE

1. **A consecutive-red CI tripwire is the highest-leverage process fix available.** Master went dark and stayed dark through a forced deploy and ~30 pushes. A daily (or per-push counter) check that pages at ≥3 consecutive red `nix-check.yml` runs converts "CI is silently dead" from a discoverable-by-accident fact into an alert.
2. **Verification-only re-dispatches should be CHEAP and recognized.** The three same-ticket re-dispatch reports converged on the right protocol (verify finding → link prior report → don't regenerate the backlog). Encode it: footer-scan before dispatch (queue side), anchor-search excludes `docs/status/` (quotes of dead claims false-positive otherwise), re-dispatch reports stay short.
3. **Security-shaped review fixes need the exposure probe FIRST.** The restic 0644 finding was fixed correctly but its severity framing ("every local account can read the password") was counterfactual — the module was deploy-pending. One `ls` before the fix separates "hole in shipped config" from "hole reachable at runtime". It also would have said so in the commit message.
4. **Never let the flagship verification ride only the local lane.** Anything wired into CI should get a same-session "does the step actually run?" check when CI is red — skipped-behind-earlier-failure is the CI twin of the phantom-green class.
5. **Post-window reality flipped this window's biggest caveat** ("everything runtime-zero, deploy refused by storms for 3 reports") within two hours of its last report. Lesson: runtime-zero claims in closeouts should carry "deploy state re-verify before acting on this" staleness markers — the 12:54 report did exactly this and was stale within an hour anyway. Deployment-state claims have a half-life measured in hours on this box.
6. **The sibling-sweep habit (07-40 report §a5) is worth keeping as doctrine:** every security fix ends with a class grep + a "no other instances" statement. It found restic was the sole umask-less writer in 30 seconds.

## f) UP TO 50 NEXT THINGS (top items; harvested into TODO_LIST — see the ticked/appended rows there)

1. Fix the statix finding in `hot-user-caches.nix` (`inherit (cfg) device;` shape) — unblocks ALL skipped CI gates. **[queued]**
2. Fix the branching-flow ssh fetch in CI VM jobs + audit CV/go-cqrs-lite deploy keys for the same gap. **[queued]**
3. Converge the GOTOOLCHAIN predicate: CI hygiene step + orphan `check-flake-inputs.sh` onto the hook's predicate (or delete the orphan). **[queued]**
4. Allowlist the secret-scanner's own canaries (canary marker convention, GH013-safe synthetic shapes). **[queued]**
5. Consecutive-red CI tripwire (≥3 red `nix-check.yml` runs → page). **[queued]**
6. Eval-time audit: reject secret-looking-path redirects without UMask/chmod (restic class → flake-check failure). **[queued]**
7. VM test for `backup.nix` (tripwire/shape/marker) before Borg go-live. **[queued]**
8. Regression test for both env-less cache reap sites (real-dir/symlink/absent fixtures). **[queued]**
9. storage.md lineage annotations: cite `d60d598c` on rows 80/82; tick row 82's [watch] (symlinks verified resolved 13:04). **[queued]**
10. End-to-end staged-file drill for the GOTOOLCHAIN guard block (closes "patterns proven, plumbing unexercised"). **[queued]**
11. Restic first-nightly proof chain (05:45 run): unit green, `.last_success`, `restic check`, one-file restore smoke, dedup ratio. (TODO_LIST line 43)
12. Retire the restic script-comment drift ("umask 077" → "unit UMask 0077") on next touch. (07-40 §f5)
13. Borg go-live chain once owner inputs arrive: host-key pin → `borg list` probe → enable → first-run watch. (docs/services/offsite-borg.md)
14. Borg repo-size projection against the BX11 1 TB quota before the first WAN seed. (12-42 §f5)
15. `backup_ever_succeeded` integration + ioTier.background on the borg unit + pre/post-deploy smoke entries. (TODO_LIST line 29)
16. Restore drill runbook + first timed restore. (TODO_LIST line 28)
17. `buildcache-init` provisions the three new targets (dangling-ENOENT window). (TODO_LIST line 41)
18. Reap-list single-sourcing + consistency gate. (TODO_LIST line 42)
19. mountPoint-vs-HM-symlink eval guard. (storage.md library)
20. Rebuild hot-db/crush-hot-db/buildcache/restic/paperless VM tests in the first calm window (`heavy-job`, io avg10 <20%). (TODO_LIST lines 34, 121, 122 + library)
21. Decide `$DRY_RUN_CMD` for HM activation `rm -rf` (blocks the audit design). (08-03 g3)
22. Queue: footer-scan idempotency preflight; then backfill-scan open tickets against existing footered commits. (TODO_LIST lines 167/174/260)
23. Annotate the 2026-09-16_16-36 report's "fish guard excluded, live-verified cleared" claim as contradicted (verified false this window; exclusion never landed). (06-48 §f5)
24. Decide the GOTOOLCHAIN `off`-exclusion contract (dead relic vs sanctioned escape hatch with a live fixture). (06-48 g2)
25. Offsite-borg in `system-health.extraMonitoredServices` parity check once enabled. (12-42 §f7)
26. Watch the first `--keep-daily 14 --keep-weekly 8` prune for pool-growth sanity (morning after restic's first run). (07-40 §f17)
27. Confirm backup-coordination emits `backup_healthy{backup="restic-app-dumps"} 1` on the live host post first run. (07-40 §f18)
28. After the batch deploy: `systemctl cat restic-app-dumps-setup` parity for the UMask key (closes eval-vs-runtime for this specific key). (07-40 §f24)
29. Paperless DR completion: `pg_restore` drill + dump-integrity gate after the first 02:00 run (fires nightly since system-796). (TODO_LIST line 44)
30. Fold the "verify claims at rendered-unit level" rule into docs/CONTRIBUTING.md's verification section. (07-40 §f21)
31. Document the house secret-creation convention (UMask=0077 default; pocket-id 640 / hermes 0026 / signoz 400 exceptions). (07-40 §f8)
32. Migrate chmod-after-create sites to unit UMask opportunistically (searxng, browser-history, cv, dns-blocker, forgejo-scripts, signoz). (07-40 §f9)
33. Generalize the DynamicUser ownership-heal pattern (gatus, papdashboard, dnsblockd) — the uid-drift class is now proven live. (15-06 §e4)
34. Deploy.sh anchoring diagnostics still print misleading "unchanged" on exit-4 (15-06 §b2). 
35. Retire stale smoke fail-baseline entries (15-06 §b4).
36. Socket-presence liveness for project-discovery-daemon (15-06 §c).
37. Root-context repro of the sandbox setattr EPERM mechanism (chmod 2770 + CAP_FSETID class). (AGENTS 2026-09-22)
38. btrbk /data EIO repair (P0; blocks the data backup leg since August). (storage.md library)
39. ClickHouse backup coverage before the next SigNoz upgrade. (TODO_LIST line 26)
40. 2-disk buildcache btrfs merge window (module flip + reformat same window). (storage.md library)
41. llama-rag spin root-cause (soak under real units ≥10 min before any re-enable). (TODO_LIST §ai-stack)
42. Owed evo-x2 reboot (flm corpse :52626; `nix run .#pre-reboot-check` first). (AGENTS)
43. Health Hub fetch-load decision + cadence/timeout module options. (TODO_LIST line 134)
44. Resend "Verified" confirmation + non-owner delivery probes (mail relay + Pocket ID test email). (AGENTS)
45. Google Sync go-live checklist (user-gated, dormant). (AGENTS)
46. GeoMetrikks MaxMind/CARTO key paste (user-gated). (storage/services library)
47. `docs/services/buildcache.md` runbook if the domain produces a third review round (two rounds + two re-dispatches so far). (08-03 §f17)
48. Annotate the 2026-07-11 btrfs-wiki doc as SUPERSEDED re: `.cargo`/`@cargo` designs. (08-03 §f18)
49. Record cross-project lessons: falsified-claim fixes grep repo-wide in the same change; `git log -1` immediately before commit under the daemon. (08-03 §f20)
50. After CI heals: date exactly when master CI went dark + re-baseline CONTRIBUTING's known-reds list. (06-48 §f17/§f38)

## g) QUESTIONS FOR THE OWNER

1. **Is GitHub CI on SystemNix live signal or known-dark?** Master has been red ≥2 days across three stacked failures, a deploy was forced through two red gates, and nothing paged. If CI is signal: dispatch the statix one-liner + VM-key fix immediately and want the consecutive-red tripwire? If known-dark: which failure class convinced you, and should the workflows be paused/scheduled instead of failing on every push? — recorded as a BLOCKED TODO item.
2. **Should offsite-borg go-live gate on the recovery-copy policy?** The Borg passphrase is a real random sops value; losing host AND sops loses the repo. Hard prerequisite (record a recovery copy first) or go live and accept the window? — recorded as a BLOCKED TODO item.
3. **The GOTOOLCHAIN `off` exclusion: dead relic or supported escape hatch?** No tree line has used it in months; the selftest pins a synthetic shape. If dead, three greps lose an exclusion; if alive, it needs a sanctioned line shape + live fixture. — recorded as a BLOCKED TODO item.

## h) BAND DRIFT

**None recorded.** The tq journal (facts + facts_archive) contains no `task.reprioritized` facts in the window or at all — fact types present are only `task.{enqueued,claimed,completed,failed,released,requeued,cancelled,dead-lettered}`. All five window tasks sat at priority 0 throughout (tasks table verified). The 2026-09-22 05:55 closeout independently confirmed the same for its window; no priority moves to account for under ADR-0015.

---

## Appendix — verification anchors (this pass, 2026-09-23 02:00–02:15)

- `bash scripts/test-gotoolchain-guard.sh` → `SELFTEST OK` on the current tree.
- `ls -la ~/.cache/pnpm ~/.local/state/pnpm ~/.cargo/registry` → all three HM symlinks resolve into `home-manager-files` (created 13:04 2026-09-22).
- `stat` on `/var/lib/restic-app-dumps/password` → `-rw------- root root`, 2026-09-22 13:04.
- `modules/nixos/services/hot-user-caches.nix` still carries `device = cfg.device;` (statix class live); `.github/workflows/nix-check.yml:150-156` carries the new selftest step AND the old bare grep; `scripts/check-flake-inputs.sh:37` same.
- `gh run view 35799069755` (statix red, gates skipped) + `35799069770` (secret-scan HITs: `leak-canary.tmp.md` blob `6d07ec6ed15e`, `sk-00000…` in the 09-15 report).
- tq journal read-only: five tasks `completed`, prio 0; zero reprioritized facts (facts + facts_archive).
- `grep -n "offsite-borg" platforms/nixos/system/configuration.nix` → import + `enable = false`.
- CI red boundary: known ≥2026-09-21 (06-48 report); earlier boundary not dated (06-48 §f17 stays queued).
