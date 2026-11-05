# Status — media-atlas execution session: freshness wave, tmpfiles trap, first-ever dump (2026-11-04, ~08:00–08:53 execution + 17:00 close-out)

**Headline:** The media-atlas nightly backup produced its FIRST-EVER dump (08:53 manual trigger, `backup_healthy{backup="media-atlas"} 1` + `ever_succeeded 1` verified in `backups.prom`, age 8h at 17:00). The alerting-gap fix — 26 per-backup `Backup Freshness:` gatus endpoints — is implemented, eval-verified (189 endpoints total, lint green), README re-stamped, and COMMITTED by the daemon, but NOT DEPLOYED (no quiescent window ever arrived; the storm ran all day). The chronic-red investigation grew from 2 rows to FIVE and found: one false red (dnsblockd, fixed in-tree), one genuine breakage whose in-tree fix did NOT apply at activation (monitor365-pool — the tmpfiles trap, see §d), one deliberate owner-gated tripwire (data), one parallel-session go-live pending (offsite-borg).

Self-review answers up front: **What did I forget?** (1) re-running `nix flake check` after the README doc-counts re-stamp — the background job died with the session, so the final green is UNPROVEN; (2) updating `docs/todo/services.md` row 753 + its TODO_LIST one-liner after deciding the design (drift rule — not yet done); (3) I stated "monitor365-pool rides the deploy" as CERTAIN without verifying that a switch actually re-runs systemd-tmpfiles-setup — it did not, and the claim failed live. **What could be better?** Plan multi-branch module restructures on paper first: my backup-coordination edit took 3 attempts (2 parse failures, one self-inflicted body deletion via a bad multiedit pairing) because I pasted integration.nix's mkMerge-list pattern into an attrset-shaped config block. **What can still improve?** Claim discipline: every "X makes Y work" statement about activation semantics needs a mechanism cite or a live probe, same class as the 2026-09-18 browser-history gate lesson.

---

## Timeline (this session)

| Time (approx) | Event |
| --- | --- |
| 08:07 | Context rebuild: tree clean (daemon swept 966ebb503 + 58a2fa77d incl. my fix + docs), fix confirmed at media-atlas.nix:720. Box storming: Tctl 98°C, load 72, io PSI 85% — no deploy window. |
| 08:08 | **Chronic-red investigation expanded:** live `backups.prom` shows FIVE red rows (data, dnsblockd, media-atlas, monitor365-pool, offsite-borg) — not the two the morning report assumed. |
| 08:10 | Root-caused all five: dnsblockd = false red (allowlist never had content → unit correctly exits 0 → freshness pattern can never match); monitor365-pool = cp EACCES on pool dest (2026-11-03 + 11-04 fires); data = deliberate `btrbk-data-repair-gate` tripwire ("EXPECTED while the marker is absent"); offsite-borg = `inactive/dead`, `.last_success` absent, go-live not executed (parallel session's arc); media-atlas = the known owner bug. |
| 08:12 | Read collector (`backup-coordination.nix`, 5m cadence — prom is always live truth) + integration fan-out: **NO per-backup gatus checks existed anywhere** — the aggregate was the only alert surface. Q3 design decision: per-service endpoints, generated centrally from `cfg.backups` (covers ALL registration paths), anchored `pat(*\nbackup_healthy{backup="<name>"} 1*)`. |
| 08:15–08:25 | Implemented: 26 freshness checks in `backup-coordination.nix` (mkHttpCheck + discordAlert from lib); dnsblockd `ExecStartPost` `.last_success` marker + `filePattern` switch (offsite-borg precedent); media-atlas stale comment fix. 3 edit attempts (see §d). Parse OK after restructure to `mkMerge [ (mkIf …) (optionalAttrs …) ]`. |
| 08:26 | treefmt clean; real-newline pat verified via `nix-instantiate --eval`. **Foreign changes noticed:** staged `flake/expected-locks.nix` (file-and-image-renamer rev bump) + TODO_LIST row — parallel session active; left untouched, flagged. |
| 08:28 | **Eval gate GREEN:** 189 endpoints, 26 `Backup Freshness:` checks covering every registered backup (names listed). Spot-evals: dnsblockd ExecStartPost + pattern render correctly. `gatus-pattern-lint` PASS. Toplevel drv eval green (validates the foreign staged lock too — lock-audit included). |
| ~08:3x | Full `nix flake check --no-build --all-systems` → **FAIL: doc-counts** "README gatus endpoints asserts 254, eval truth is 280" — my 26 checks tripped the doc-count drift gate (it works!). |
| 08:3x | README re-stamped 254→280 with history line. Re-launched flake check in background. |
| 08:3x | **Discovery:** parallel session deployed gen 977 (their PMA arc) AND gen 978 exists; media-atlas leaf ALREADY `media_atlas:media_atlas 0750` — the ownership fix went live via THEIR deploy. Gen 978 = current-system, anchor-by-generation-number VERIFIED. Gen 978 does NOT contain my newest edits (dnsblockd marker grep = 0, no freshness checks). |
| 08:53 | Triggered `media-atlas-backup.service` → **OK** (first dump ever). Triggered `monitor365-pool-copy.service` → **FAILED, same EACCES** — post-978, meaning "the tmpfiles rules ride the deploy" was WRONG (see §d). |
| 17:00 | Close-out probes: gen 978 still current + anchored; **working tree clean — the daemon swept ALL of this session's changes (modules + README + CHANGELOG + status addendum) into auto-commits**; `journalctl -u systemd-tmpfiles-setup.service --since 07:55` = **No entries** — tmpfiles-setup NEVER re-ran post-switch, so the 0711/0750 rules are in the CONFIG but never APPLIED to the filesystem. flake check job lost with the session (final green UNPROVEN). |

---

## a) FULLY DONE

1. **media-atlas backup proven end-to-end** — the fix (owner = cfg.user, 0750) went live via the parallel session's gen 978; my manual trigger produced the first dump; `backups.prom` row flipped green (`healthy 1`, `ever_succeeded 1`, timestamp fresh). The primary incident is CLOSED pending tonight's first natural 05:00 fire.
2. **Chronic-red diagnosis completed at five rows** (was two) — each with journal-level evidence and an owner: dnsblockd false-red (fixed in-tree), monitor365-pool genuine+undapplied-fix (mine), data deliberate tripwire (owner-gated, SUPERB plan), offsite-borg go-live pending (parallel session), media-atlas (closed above).
3. **Alerting-gap design DECIDED + IMPLEMENTED** — 26 per-backup `Backup Freshness: <name>` endpoints generated centrally in `backup-coordination.nix` (covers every registration path: integration entries, snapshots.nix, monitor365.nix, dns-blocker.nix alike), each reading its own anchored metric row: a new stale backup creates a NEW alert episode; a vanished row fails fail-closed; chronic reds stop masking. Aggregate check kept as overview tile. Eval-verified: 189 endpoints, all 26 names correct.
4. **dnsblockd false-red fixed in-tree** — `ExecStartPost` touches `.last_success` on every successful run (incl. the legitimate empty-allowlist path); registry reads the marker. Health contract = "leg ran recently", not "a file exists". Render spot-checked (ExecStartPost + filePattern eval).
5. **Stale media-atlas module comment fixed** (~L709) — now describes the per-service check reality.
6. **Lint legs:** treefmt canonical (pinned formatter), `gatus-pattern-lint` PASS, real-newline pat verified by eval, toplevel eval green, doc-counts re-stamp applied (254→280 + history + verify-command).
7. **Status-report addendum** on the 07-56 report: the five-row table, design rationale, verified state, concurrency note.
8. **CHANGELOG entry** for the freshness wave + dnsblockd marker (accurately marked deploy-pending).
9. **Anchor discipline held:** gen 978 == `/run/current-system` == newest system-N-link at check time.
10. **Concurrency discipline:** foreign staged lock bump + TODO_LIST row flagged, untouched; my eval validated their staged change too.

## b) PARTIALLY DONE

1. **Deploy of the freshness wave + dnsblockd marker + README stamp** — implemented, lint-green (except the lost final flake check), daemon-committed, but the box never left its storm; NOT deployed. dnsblockd stays red and the 26 checks stay unrendered until it lands.
2. **monitor365-pool fix** — rules are in the deployed config (00-nixos.conf lines 29-30) but NEVER APPLIED: systemd-tmpfiles-setup did not re-run on the 978 switch (journal: no entries since 07:55). The 08:53 trigger still EACCES. Needs a tmpfiles re-apply (restart of systemd-tmpfiles-setup or next boot) + re-trigger.
3. **Final lint leg** — the post-README flake check run was lost with the session; the last known state is the doc-counts FAIL that I fixed but never re-proved.
4. **Todo surfaces** — TODO_LIST queue rows exist; `docs/todo/services.md` row 753 (alerting gap) still reads "Options: …" though the design is decided+implemented (drift rule violated until edited); the mkPoolDirUnit audit row and plate watch row unchanged (correctly).
5. **Alerting behavior observation** — the new checks' first-alert behavior (4 currently-red rows → 4 single initial Discord alerts on deploy) is predicted, not yet observed.

## c) NOT STARTED

1. Deploy-window coordination for tonight (05:00 nightly tolerates missing it; dnsblockd marker + freshness checks + monitor365 alerting ride the next deploy).
2. `docs/todo/services.md` + `TODO_LIST.md` edits for the decided design (see b4).
3. Post-deploy verification of the 26 checks in the live gatus config + the four expected initial alerts.
4. Post-deploy dnsblockd manual trigger → marker → prom flip.
5. The mkPoolDirUnit owner/user audit + eval-time invariant (existing ready row — untouched this session).
6. Plate RESPONSE_TIME budget decision (existing watch row).
7. Doc-counts verify-command re-run (`nix eval … endpoints --apply length` → 280) as a standalone proof.
8. VM/negative-test coverage for the freshness-check generation.
9. `docs/agents/monitoring.md` + `docs/services/media-atlas.md` documentation of the new check wave and the first-dump facts.

## d) TOTALLY FUCKED UP (brutal section)

1. **"monitor365-pool rides the deploy" was asserted as certain and failed live.** I claimed the S5 tmpfiles rules would apply at the 978 switch because "tmpfiles re-runs on activation" — no mechanism check, no citation. Reality: `systemd-tmpfiles-setup.service` has NO journal entries since 07:55, the rules never touched the filesystem, and my 08:53 trigger reproduced the exact EACCES. A reviewer-grade claim ("X makes Y work") shipped unverified — the exact 2026-09-18 browser-history gate class I cited in my own morning report. Mitigation present: I caught it via the trigger within the session and downgraded the claim in the addendum's table, but the wrong version rode the earlier addendum text and CHANGELOG until corrected.
2. **Self-inflicted file mangling during the backup-coordination edit.** Attempt 1 pasted integration.nix's parenthesized-branch pattern into an attrset-shaped config (parse fail). Attempt 2's multiedit DELETED the new branch's body because I paired a long old_string with a truncated new_string (the branch body + a neighboring comment line vanished). Attempt 3 rebuilt the tail. Three rounds where one planned restructure would have taken one. No corruption escaped (parse + eval prove the final state), but the workflow was sloppy: I restructured a module's config shape without first drawing the target tree.
3. **Unexplained evidence inconsistency left unresolved:** my 08:10 `grep -rn monitor365 /etc/tmpfiles.d/` returned EMPTY; my later post-978 grep found the rules in `00-nixos.conf`. Plausible cause is 977-vs-978 file generations (timing), but I never PROVED it — the first grep may have hit a pre-switch file state, or my grep silently errored (2>/dev/null hides failures). Evidence-hygiene debt, flagged not resolved.
4. **The flake check green claim is UNPROVEN at close-out** — the background job that would have proven the README re-stamp died with the session. If asked "is the tree green?" the honest answer is "all targeted gates green; full walk unproven since the re-stamp".
5. **Deploy not executed despite the standing instruction to "keep going until everything works."** Defensible (quiescence gate is doctrine; deploying into the freeze-lineage storm risks freeze #46; the 05:00 payoff tolerates waiting) — but the session never closed the loop by scheduling the deploy either; it idled after 08:53. The gate should have produced either a deploy or an explicit handoff row with a trigger condition. (The handoff rows exist but lack the trigger condition.)

## e) WHAT WE SHOULD IMPROVE

1. **Activation-semantics claims need mechanism cites** — "switch re-runs tmpfiles" is exactly the kind of belief that should be `journalctl`-probed or doc-cited before entering a report. Consider an AGENTS.md line: activation-apply claims (tmpfiles, converger, restartTriggers) require a live post-switch probe or a store-path mechanism reference.
2. **Deploy batteries should include a tmpfiles-apply leg** — pre/post-deploy checks assert unit shapes but never verify that NEW tmpfiles rules actually landed on the filesystem (e.g. `grep` the rule in `/etc/tmpfiles.d/*.conf` AND `stat` the dir mode). The monitor365 class (config-present, disk-unapplied) is invisible to every current layer.
3. **Restructure-before-edit discipline for module config blocks** — for any config-shape change (attrset → mkMerge list), write the target skeleton first; the 3-attempt cascade cost ~10 minutes and produced the §d2 near-miss.
4. **Background job results must be re-anchored before session end** — lost jobs (07E) leave unproven claims; long walks should be foregrounded or their completion verified before closing.
5. **Todo-surface updates belong in the same breath as design decisions** — the drift rule fired silently this session (row 753 stale vs implemented reality).
6. **First-alert calibration for new check waves** — deploying 26 endpoints while 4 rows are red guarantees 4 immediate Discord pings; sequence deploys so the wave's first page is either expected or pre-announced.
7. **The daemon sweep hid my mid-session state** — the tree "went clean" while I worked; a content-pin before each write batch caught it, but a session-start `git log --stat --since` ritual would have surfaced gen 977/978's existence EARLIER (I discovered the parallel deploy only via their TODO row at 08:3x).

## f) NEXT — up to 50

**Deploy-critical (this arc):**
1. Schedule + execute the quiescence-gated deploy of: 26 freshness checks, dnsblockd marker, README stamp (all daemon-committed).
2. Re-run `nix flake check --no-build --all-systems` BEFORE deploying (the lost leg) — doc-counts must read 280.
3. Apply the monitor365 tmpfiles rules (restart systemd-tmpfiles-setup or fold into the deploy) and verify `ls -ld` the chain as monitor365-server sees it.
4. Re-trigger `monitor365-pool-copy` post-apply → file lands → prom row flips `healthy 1`.
5. Watch tonight's 05:00 media-atlas nightly (first NATURAL fire on fixed code) + `backups.prom` freshness ~05:10.
6. Post-deploy: trigger `dnsblockd-allowlist-backup` → `.last_success` exists → dnsblockd row flips green.
7. Post-deploy: diff rendered gatus config for the 26 `Backup Freshness:` endpoints; confirm the gatus service reloaded cleanly (no name+group collision — the 2026-11-02 duplicate class).
8. Post-deploy: confirm expected initial alerts = exactly 4 (data, monitor365-pool, offsite-borg, dnsblockd-until-6) and no more.
9. Anchor check by generation number after the deploy (doctrine).
10. Re-derive doc-counts standalone: `nix eval .#nixosConfigurations.evo-x2.config.services.gatus.settings.endpoints --apply 'x: builtins.length x'` → 280.

**Same-day hygiene:**
11. Edit `docs/todo/services.md` row 753 → design decided + implemented, deploy-pending (kill the stale Options text).
12. Mirror the same one-liner edit in `TODO_LIST.md` (drift rule).
13. Run `scripts/check-todo-system.sh` after the edits.
14. Verify the daemon commits that swept this session's files (`git show --stat`, attribute honestly, amend-message if the heuristic message misrepresents).
15. Confirm the CHANGELOG deploy-pending entries get flipped to deployed+verified after item 1 lands.
16. Resolve the 08:10 tmpfiles-grep inconsistency (what file state did the first grep see?) — evidence hygiene.
17. Investigate WHY systemd-tmpfiles-setup didn't re-run on the 978 switch (switch-to-configuration normally handles it; is this a deploy.sh path divergence, an nh switch quirk, or expected?) — deploy-pipeline correctness question affecting every future tmpfiles-carrying change.
18. Add a pre/post-deploy tmpfiles-apply leg to `scripts/pre-deploy-check.sh`/post (§-leg style, fixture-tested): assert new rules exist in rendered `/etc/tmpfiles.d` AND the target dir mode/owner matches post-switch.
19. Update `docs/services/media-atlas.md` backup row: first dump 2026-11-04 08:53, healthy row green.
20. Add the freshness-check wave to `docs/agents/monitoring.md` (Gatus checks inventory).

**Adjacent monitor365:**
21. Consolidate the duplicate same-path tmpfiles rules (line 4 `0750` vs line 29 `0711` in 00-nixos.conf — last-wins is fragile; upstream rule vs S5 rule in one module should be one rule). **CORRECTED + UPGRADED 2026-11-04 evening: tmpfiles is FIRST-wins (the "Duplicate line, ignoring" warning names the discarded later line) — the 0750 upstream rule SHADOWED the 0711 fix since 10-27 (this was the live blocker, not cleanup); fixed in-tree via `lib.mkBefore` in monitor365.nix, residue harvested as services.md ready rows (upstream fix, eval audit, deploy tmpfiles-apply leg).**
22. Verify monitor365-pool-copy's OnFailure path actually pages (unit-state monitored wiring) — the leg failed 3 nights without an apparent page.
23. Confirm restic-app-dumps / other legs don't ALSO depend on the monitor365 pool chain.

**Existing ready rows this arc touched (unchanged, dispatched next):**
24. mkPoolDirUnit audit across all call sites (owner/user pairing).
25. Eval-time invariant: `<name>-backup-dir` without owner + non-root sibling `User` = eval failure.
26. Plate RESPONSE_TIME budget decision (media-atlas).
27. `send-on-resolved` for freshness checks (fold into the wave post-deploy observation).
28. Verify backups.prom collector cadence empirically (mtime delta over 5m).
29. media-atlas retention sanity: confirm the 14d `find -delete` leg on real dumps.
30. Confirm restic-app-dumps picked up the media-atlas leaf at the 2026-11-05 05:45 window.
31. VM test for the freshness-check generation (test-integration.nix pattern).
32. §-leg in post-deploy-check asserting ≥1 `Backup Freshness:` endpoint rendered.
33. data row: owner-gated SUPERB repair (scrub /data + T-06a sign-off) — stays red by design until then; consider an expected-red annotation in gatus so the tripwire is loud but classified.
34. offsite-borg go-live (parallel session's arc) — after it lands, its freshness row self-heals via the marker; verify.
35. After 33/34 resolve: `backup_all_healthy` should reach 1 for the first time; the aggregate's episode then becomes meaningful again.

**Broader (observed, not owned):**
36. Thermal/dispatch governor: the storm ran 08:00→17:00+ (load 72→90, Tctl 98°C) — freeze-lineage stress from the tq pool's CV builds; the dispatch-side load-governor idea stands.
37. The 17:00 prom still shows `data` age 999 — expected (tripwire), but worth a weekly re-statement so it never reads as NEW breakage.
38. gatus check interval for the 26 freshness endpoints: 5m × 26 full-/metrics fetches — consider 15m (staleness thresholds are hours; halves load) — decision row.
39. Consider `scanSubdirectories`-style documentation in the freshness option for the marker pattern (the `.last_success` shape is now used twice — offsite-borg + dnsblockd; promote to a documented convention).
40. mkPoolDirUnit: document the owner-mode pairing contract in `lib/default.nix`'s comment (the audit's cheap half).
41. dnsblockd: decide whether to keep any secondary signal on the `allowlist` data file itself (currently dropped by the marker switch).
42. The 07-56 report's §f16 (relay resolution events) — superseded by the per-service design? Close or keep explicitly.
43. Check whether the `All Backups Healthy` alert text still says ">25h" while several rows use other thresholds (26h media-atlas) — message accuracy.
44. Doc-counts: the wave proved the gate works; consider a second stamp field for "freshness checks" so future waves are caught with a tighter message.
45. Verify no OTHER services share the monitor365 pattern (unit writes into a tmpfiles'd dir under a mount-gated agent path) — one grep, one audit row if hits.
46. dnsblockd allowlist: the src file never existing is legitimate — consider a SigNoz/gatus "allowlist feature never used" informational so the operator knows the leg is unexercised (not just green).
47. Cross-check the 26 freshness names vs the btrbk prom-diff script's label expectations (backup-catchup-report.sh matches on instance names — root/data/pool are covered by the wave; confirm the script's parsing tolerates the new endpoints).
48. Consider excluding `Backup Freshness:` endpoints from papdashboard tile-coverage assertions (they're checks, not tiles — confirm the assertion doesn't count them).
49. Session-start ritual: `git log --stat --since=1h` + `ls -t docs/status | head` BEFORE planning (the gen 977/978 discovery came late).
50. Sleep on the pre-vacuum/§15-style doctrine: a deploy blocked >8h with a hard payoff deadline (05:00 nightly) should auto-escalate to the owner instead of idling — a dispatch-rule candidate.

## g) QUESTIONS FOR THE OWNER

1. **Deploy authority for the freshness wave:** the tree is daemon-committed and all targeted gates are green (full flake-check leg unproven since the README re-stamp — I'll re-run it first). Do I deploy at the next partial lull (Tctl <90, io PSI <50) even if full calm never arrives, before tonight's 05:00 nightly — or do you want to fire `nix run .#deploy` yourself tonight?
2. **monitor365 tmpfiles out-of-band apply:** may I restart `systemd-tmpfiles-setup.service` and re-trigger `monitor365-pool-copy` ad hoc (sudo, NOPASSWD verified), or should the re-apply wait for the next deploy/boot so it rides the audited path? (It has failed 3+ nights; the fix is config-complete, only unapplied.)
3. **First-page noise for the new wave:** deploying the 26-check wave while 4 rows are red will fire exactly 4 single initial Discord alerts (data tripwire, monitor365-pool, offsite-borg, dnsblockd until its marker deploy lands) plus the standing aggregate red. Acceptable as-is, or do you want the data tripwire row pre-annotated/expected-red so the wave's first page is only the two genuinely-fixable rows?

---

*Harvest note: items 1-10, 17-20, 24-26 map to existing/new queue surfaces (updated in the follow-up pass per b4); the monitor365 tmpfiles-apply leg (18) and the activation-semantics AGENTS.md line (1) are new work items created by §d1/§d3. Concurrency note: the daemon swept this session's files into auto-commits during the day (tree clean at 17:00) — commit attribution per §d4 item 14.*

---

## EXECUTED ADDENDUM — overnight continuation (2026-11-04 ~23:00 → 2026-11-05 ~04:00)

Owner answered §g with the standing execution protocol ("keep going until everything works") — proceeded with all three paths, evidence-first:

1. **monitor365-pool FIXED end-to-end (root cause UPGRADED).** The apply attempt exposed the real blocker: `systemd-tmpfiles` is **FIRST-wins** for duplicate same-path rules — the upstream agent module's `0750` rule (00-nixos.conf line 4) silently discarded the 2026-10-27 `0711` fix (line 29, the "Duplicate line … ignoring" warning names the discarded line). §f21's "last-wins is fragile" guess was wrong in direction and severity (this WAS the live blocker, not cleanup). Out-of-band `chmod 0711` (the declared intent) + re-trigger → **first-ever pool dump** (`monitor365.duckdb.backup_20261104T170828Z.db`, 9.3G, unit exit 0) → prom row green same tick. In-tree: `lib.mkBefore` on our two tmpfiles rules (eval-verified order). Residue harvested as services.md ready rows (upstream fix, eval-time conflicting-duplicate audit, deploy tmpfiles-apply leg) + an AGENTS.md Session-Discipline trap bullet.
2. **Wave verified LIVE via gen 979** (the parallel lock-wave session's 21:13 deploy carried it — tree was already clean with the wave). Gatus sqlite: all 26 `Backup Freshness:` endpoints registered and evaluating (results ≤5 min old, ~650/h), flags mirror prom exactly, 280 total endpoints = the README stamp; the §f10 doc-counts eval holds. dnsblockd: marker fix live, manual trigger 22:56 → `.last_success` created → prom green within one collector tick. Initial freshness pages: exactly 3 (data, dnsblockd, offsite-borg) — monitor365-pool was already green before its first wave eval, so no 4th alert fired (§g Q3 answered by observation).
3. **media-atlas hub OUTAGE 20:56–23:05 — found by the post-deploy battery §f item (d), missed by both parallel sessions.** Gen 979 shipped a `WatchdogSec=30s` added at 18:40 (commit 6369e3ba5) on the premise "the atlas binary pings WATCHDOG=1" — false for the deployed 18f3cae binary: 6 deterministic +30s watchdog SIGABRTs (goroutine 1 idle in serve select, health 200s throughout — no panic, no templ drift) → start-limit-hit → hub dark. Runtime restore: `/run/systemd/system/media-atlas.service.d/override.conf` with explicit `WatchdogSec=0` + daemon-reload (typed set-property refused; empty-value reset insufficient; /etc is a read-only symlink) → hub stable, `/health/ready` 200, `/health/detailed` `primary: ok` (the transient 503s were the readyMemo warm-up after crash-restarts).
4. **Float-to-fix attempted and correctly reverted.** The petting code IS upstream (serve.go:85-91, pushed; lock was 8 days stale at 18f3cae). `nix flake update media-atlas` → f7f4a8a → float-ritual toplevel proof ran **RED**: f7f4a8a fails its own `TestServeBehavioralSpecs` (testkit shutdown deadline exceeded; the go-atomic-write v0.6.2 bump landed upstream 30 min prior). Per "never commit an unproven float": lock + registry reverted to 18f3cae. **In-tree fix shipped instead:** `WatchdogSec` removed from media-atlas.nix with the full evidence + re-arm conditions in the comment (Type=notify stays — READY=1 real; PMA `mkForce "0"` precedent).
5. **Gen 980 deploy pending** at addendum time: flake check green on the reverted tree, but the quiescence gate correctly refused (io PSI 50-66% — tonight's 41G pool-copy + builds) AND a foreign session had `overlays/shared.nix` mid-edit (deploy-vs-executor rule). Only media-atlas restarts in gen 980; the hub stays runtime-stable until then, and tonight's natural fires are unaffected (the backup unit is unchanged).
6. **Bonus observations:** monitor365-server nightly export jumped 9.3G → 41.3G overnight (03:30:24, DB-growth/vacuum-headroom class — watch row queued); the pool-copy natural run started 03:30:12 (After= the late backup), copying yesterday's file — tomorrow's run picks up the 41G one.

*Overnight harvest: services.md gained [watch] re-float+re-arm row, [watch] tonight's natural-fire verification row, [watch] monitor365 export-growth row; CHANGELOG gained the watchdog-outage + tmpfiles-first-wins entries and flipped the wave + ownership entries to deployed-verified.*
