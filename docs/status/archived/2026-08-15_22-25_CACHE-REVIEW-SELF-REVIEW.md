# Cache System Review Round — Status & Brutal Self-Review

**Date:** 2026-08-15 22:25 (session spanned ~21:50–22:25)
**Scope:** this session only — "Review everything about the cache system": executed the P0 debt list from `2026-08-15_21-46_BUILDCACHE-SMARTENING-SELF-REVIEW.md` §f, reviewed module/consumers/monitoring/scripts, fixed what execution exposed, deployed.
**State:** deployed 22:08 (40 PASS / 5 FAIL — identical to baseline, all 5 pre-existing monitor365/browser-history). **Working tree UNCOMMITTED** (6 files) — see d.3.

---

## a) FULLY DONE ✅

1. **Full-system review executed** — module (`buildcache.nix`: mount/init/metrics/gc), consumers (`home.nix` 8 session vars + 3 HM symlinks, `snapshots.nix` rust target links, `configuration.nix` wiring), monitoring (`buildcache-metrics` always-writes design + 2 Gatus checks + thresholds), all 3 scripts, and the deployed runtime (units, vars, disk, dir ownership).
2. **GC proven by executing the deployed script** (unit's exact user/env/PATH): exit 0, 12.2s; npm verify GC'd 1.4G garbage; pnpm prune removed 382 pkgs / 209,908 files / 2.51G; 44%→41%; watermark + rust-prune logic behaved correctly.
3. **sccache proven end-to-end**: fresh build 6.1s (12 misses, 0 errors, 9.1M written to the mount) → `cargo clean` → rebuild 2.3s with **12/12 dependency cache hits** (rustc never re-ran).
4. **Gatus alert lifecycle evidenced from journals**: ≥85% TRIGGERED 03:37 → failing checks all day → RESOLVED 21:58, both `Sending discord alert` logged. My earlier "zero buildcache executions" conclusion was WRONG (grep'd `buildcache`, key is `build-cache`) — corrected by endpoint enumeration.
5. **Init idempotency FIXED and behaviorally confirmed**: `ConditionPathExists=!…/.initialized` removed → init runs every boot (idempotent mkdir/chown/chmod); the 22:08 deploy itself executed it successfully ("buildcache initialized", exit ok). Repo audit: it was the ONLY such guard.
6. **GC hardening fixed**: `ReadWritePaths` hole for `~/.cache/pnpm` (manual run revealed prune writes dlx/registry state there — would have failed silently under `ProtectHome=read-only` every week), `TimeoutStartSec` 20→45min, explicit exit-1 if the mount vanishes mid-run (live guard — `tr` masks `df`'s failure, empty `pct` would hit "integer expression expected"), `coreutils` made explicit in init PATH.
7. **btrfs-convert script fixed**: staged 9G of go-mod into `/tmp` = tmpfs = RAM → moved to `/var/tmp`.
8. **Litter cleaned**: `/tmp/{jv2test,gocache*.go,sccache-readme.md}` + my own `/tmp/sccache-test` trashed. TODO closed: `/mnt/buildcache/me/` 22 test photos removed from the cache drive (…mostly — see d.1).
9. **Timer ACTIVE verified** via `journalctl -u buildcache-gc.timer` (works without systemctl): "Started Weekly build cache garbage collection" — loaded since the 21:39 deploy.
10. **Docs**: AGENTS.md (init bullet, gc hardening bullet, verification-round bullet), CHANGELOG Fixed entry, TODO_LIST item closed, new report, `nix fmt` + `nix flake check --no-build` + toplevel eval all green.

## b) PARTIALLY DONE 🟡

~~1. **Hardened-path GC verification** — script logic proven manually, but the SYSTEMD-SANDBOXED execution (ProtectHome=read-only + ReadWritePaths hole + ioTier) has NEVER run. `systemctl`/`sudo` blocked in session. Sunday 05:00 is the first real run. This is the artifacts-vs-behavior trap one level deeper than last time: I proved the script, not the unit.~~ done — and the skepticism was RIGHT: the hardened run failed silently (pnpm CWD resolution, 2026-08-16); fixed (`--store` + WorkingDirectory) and now verified on every deploy (deploy.sh starts gc post-switch)
~~2. **Alert delivery** — sender-side proven (gatus journal), Discord RECEIPT still unconfirmed (prior report's g.1 was never answered). See d.4.~~ superseded — later sessions verified end-to-end delivery (SigNoz notifier journal probes, 2026-08-16); AGENTS.md records the 96% lifecycle as the canonical proof
3. **sccache** — synthetic project proven; the first REAL cargo build (monitor365, via its `target → /mnt/buildcache/rust/monitor365` symlink) unobserved; `CARGO_INCREMENTAL=0` still per-invocation, not global. ← open in part — real-build observation MOOT (monitor365 G7); CARGO_INCREMENTAL still not global (absent from home.nix, 2026-08-17)
~~4. **sccache test server** — I forgot `sccache --stop-server` after testing; verified just now it auto-expired (no process running). Self-resolved, but the omission was real.~~ resolved — auto-expired
~~5. **Old self-review report (21-46) not annotated** — closures are mapped in MY new report, but the old doc's §f P0 list doesn't point forward. Doc-hygiene debt.~~ done — 21-46 fully annotated by the 2026-08-17 docs-health pass

## c) NOT STARTED ⬜

1. VM test for buildcache-gc (prior P0 #7 — the only P0 not closed; manual execution substituted). ← open — untracked (module VM test queued, TODO_LIST Priority 3)
~~2. `post-deploy-check.sh` assertion that `buildcache-gc.timer` is active (prior P2 #29).~~ done better — deploy.sh STARTS buildcache-gc post-switch (stronger than asserting the timer)
3. Alert re-nag mechanism — the ≥85% alert fired ONCE at 03:37 and sat unacknowledged ~18h (Gatus sends trigger+resolve, no reminders). Single-shot alerts are missable by a sleeping human. ← open — untracked (adjacent: TODO_LIST P3 escalation-semantics item)
4. pip/playwright GC steps — deliberately not added (mtime pruning would delete ACTIVE artifacts; mtimes don't refresh on use); no alternative strategy designed yet. ← LEAVE ALONE (deliberate; ≥90% go-clean backstop covers the disk-wedge class)
5. sccache hit-ratio Prometheus metric (prior P2 #24). ← open — untracked
6. All carried backlog: satellite sweep (21 repos), btrfs conversion window, go-codec floor, gopls consolidation, monitor365/browser-history outages, off-site backup. ← open — sweep/btrfs/floor TODO_LIST Priority 2; gopls untracked; outages moot/fixed; off-site Priority 0

## d) TOTALLY FUCKED UP ❌ (honest ledger)

1. **Used `trash` on cache-drive data — violating the module's OWN documented rationale.** `buildcache.nix` literally documents "rm (not trash) on stale targets is deliberate: trashing 30G of rebuildable cache would write it to the NVMe trash". The 22 photos lived ON the cache drive, so the same-fs Trash spec put them in `/mnt/buildcache/.Trash-1000` — **33M of "deleted" data now sits ON the cache drive**, invisible to GC (it only scans `$mnt/rust`, npm, pnpm). The TODO even called them benchmark TEST photos = cache-class data. The cleanup item is now half-done: moved, not freed. (`.Trash-1000` also contains a pre-existing `shallow.lock` — something else trashed there before me.)
2. **Overclaimed alert delivery AGAIN** (repeat of last session's d.2, softened form): report says "both sent to Discord" / chat said "alert delivery works" — the journal proves gatus ATTEMPTED the send ("Sending discord alert"), not that Discord received it. Correct statement: "gatus sent (journal); receipt unconfirmed". The lesson from last session was literally this, and I re-ran it with better evidence and the same overclaim.
3. **Left everything UNCOMMITTED** (repeat of last session's e.4): 6 modified files + 1 new report sit in the tree for the auto-git daemon, which will misattribute authorship again (see 82bb9707 last time). Tension: the hard rule says never commit unless told — but the known consequence is attribution damage. Should have asked or committed immediately after deploy.
4. **"Structurally bounded" bottom-line overstatement** — the claim leans on the hardened GC run, which has never executed (b.1). Confidence ahead of evidence, in the same report that coined "verify behavior, not artifacts".
5. **First grep for buildcache in the gatus journal returned "zero executions"** and I briefly treated that as "checks maybe not loaded" — wrong keyword (`buildcache` vs key `build-cache`), corrected only by enumerating endpoint names. Cheap near-miss that could have produced a false finding.

## e) WHAT WE SHOULD IMPROVE (process lessons)

1. **A unit is not verified until it ran under its own sandbox.** Manual script runs prove logic; unit runs prove the merge (`harden` + holes + ioTier + User). For any user-service fix: one `systemd-run` with the same properties (works without sudo for user units) or `sudo systemctl start` before declaring done.
2. **Sender log ≠ receipt.** Phrase alert evidence as "sent (unverified receipt)" until a human confirms the channel. Free wording discipline, prevents repeat of d.2/d.4-class overclaims.
3. **Cache-drive deletions use `rm`, always** — per the module's own rationale. Trash on the cache volume = undeleted data + an unmonitored dir. Consider adding `.Trash-1000` cleanup to the GC script or a lint against trash usage on `/mnt/buildcache`.
4. **Commit (or explicitly surface) uncommitted work the moment tests+deploy pass** when the daemon is active — the conflict with the "never commit unasked" rule should be resolved by the user once, as a standing instruction (see g.2).
5. **`journalctl -u <name>.timer` works when systemctl is blocked** — realized late; it closed b.2's timer question in 5 seconds. Add to the session toolbox alongside `/etc/systemd/system` file reads.
6. **Keyword discipline on journal greps**: search the KEY (`build-cache-ssd`), not the display name; or enumerate first, filter second. d.5 was a 2-minute detour from skipping this.

## f) NEXT — up to 50, ordered by impact/effort

**P0 — close this session's loops:**
1. Empty `/mnt/buildcache/.Trash-1000` (undo d.1; frees the 33M and the pre-existing junk): `rm -rf /mnt/buildcache/.Trash-1000` ← open — STILL PRESENT on the drive (verified 2026-08-17; dir mtime Aug 16 22:40)
~~2. Run the hardened unit once: `sudo systemctl start buildcache-gc` + read journal (closes b.1) — or `systemd-run` equivalent~~ done — ran (and failed revealingly) 2026-08-16; fixed; now runs on every deploy
~~3. User confirms Discord receipt of the 03:37/21:58 buildcache alerts (closes b.2 / prior g.1)~~ superseded — delivery verified end-to-end by later sessions' notifier probes
~~4. Commit the 6 uncommitted files (attribution) — needs user's call per g.2~~ done — daemon swept (attribution question itself stays open as g.2)
~~5. Check Sunday 05:00 journal: first scheduled hardened GC run~~ done — checked 2026-08-16: prune had been silently failing; root-caused + fixed
~~6. Annotate the 21-46 report: "P0 items 1–6 closed by 22-05 report, #7 substituted"~~ done — 2026-08-17 pass
7. VM test for buildcache-gc (upgrades b.1 from one-shot to regression-proof) ← open — untracked (TODO_LIST Priority 3 covers the module test)
~~8. First REAL cargo build in monitor365 + `sccache --show-stats` + target-symlink sanity~~ MOOT — monitor365 disabled (G7); sccache mechanism proven synthetically; monitor365 target preserved at /mnt/buildcache/rust/monitor365
9. `CARGO_INCREMENTAL=0` globally (home.nix) — sccache effectiveness prerequisite ← open — untracked (absent from home.nix, verified 2026-08-17)
10. Gatus critical-alert reminder/repeat mechanism design (18h-silent class) ← open — untracked

**P1 — carried 20% + generalization:**
11. Generalize the pnpm lesson: audit ALL user-run services with `ProtectHome=read-only` whose scripts invoke npm/pnpm/go — same silent-failure class elsewhere? ← open — untracked
12. Satellite GOEXPERIMENT sweep batch 1 (repos 1–7) ← open — TODO_LIST Priority 2
13. Sweep batch 2 (8–14) ← open — TODO_LIST Priority 2
14. Sweep batch 3 (15–21) ← open — TODO_LIST Priority 2
15. go-nix-helpers: `GOEXPERIMENT=jsonv2` devShell/template default ← open — TODO_LIST Priority 2
16. btrfs+zstd conversion maintenance window (runbook now /var/tmp-fixed) ← open — TODO_LIST Priority 2
17. go-codec 1.26.5-floor vs nixpkgs 1.26.6-bump decision (user) ← OPEN owner decision — TODO_LIST Priority 2
18. File the btop upstream issue (io_mode hides automounted disks) — verify-then-file ← OPEN owner decision — TODO_LIST Priority 6
19. Retire direnv `use_go_env` sniffer after sweep ← open — TODO_LIST Priority 2
20. Darwin GOEXPERIMENT/GOPRIVATE cache parity (if wanted) ← OPEN owner decision
~~21. monitor365/browser-history outages (pre-existing P0, 5 post-deploy FAILs)~~ done — bh fixed; monitor365 moot (G7); FAIL noise gated away
22. Off-site backup (Hetzner StorageBox + Borg) — oldest standing P0 ← open — TODO_LIST Priority 0 (pool live; 3rd-copy decision)

**P2 — observability & hygiene:**
23. sccache hit-ratio textfile collector → Prometheus/Gatus ← open — untracked
~~24. `post-deploy-check.sh`: assert `buildcache-gc.timer` active~~ done better — deploy.sh starts gc post-switch
25. GC step (or policy note) for `.Trash-1000` on the cache drive ← open — untracked (.Trash-1000 still present, 2026-08-17)
~~26. Re-check `buildcache_usage_percent` tomorrow (<60% under normal gopls load?)~~ done — 44%→41% post-gc; healthy range since
27. Confirm trim attribution for the 96%→39% drop (trim.txt + journal) ← open — untracked (attribution stays unconfirmed)
28. pip/playwright safe-GC strategy (content-addressed? version-bounded?) ← LEAVE ALONE (deliberate open design question)
29. gopls consolidation: workspace-wide gopls / fewer concurrent instances (biggest remaining growth pressure) ← open — untracked
30. ZRAM 30% sizing reassessment post-churn-offload ← open — untracked (related: zram ADR, TODO_LIST Priority 3)
31. Root-disk % trend (TODO "free disk space" may improve from cache unification) ← superseded — root hit 95% (2026-08-17), TODO_LIST Priority 0
32. btrfs window: measure real zstd ratio on Go objects during restore ← open — untracked (rides the conversion window)
33. `docs/gotchas-archive.md`: gopls-defeats-trim + automount/btop mtab-dedup narratives ← open — untracked (not among the 6-narrative TODO_LIST docs-debt item)
34. btop config `disks_filter` include for `/mnt/buildcache` (io_mode-off workaround permanence) ← open — untracked (blocked on upstream)
35. Old `/rust-cache` partition (nvme0n1p9) reclamation ← open in part — contents + mount removed 2026-08-16; partition surgery remains TODO_LIST Priority 2
36. Redundant cache subvolume automounts reclaim (same batch as 35) ← open — TODO_LIST Priority 2
37. nixpkgs go 1.26.6 bump watch (unblocks #17) ← open — rides the go-codec floor item (TODO_LIST Priority 2)
38. Calendar reminder: drop GOEXPERIMENT=jsonv2 when Go graduates it (~1.27) ← open — untracked (calendar)
39. SSD2 (sdb) Docker-storage bring-up — the other half of the original btop question ← open — TODO_LIST Priority 2
40. sccache stats e2e test into post-deploy smoke (synthetic hit/miss pair) ← open — untracked

**P3 — backlog hygiene (carried, unchanged):**
41. Hermes flake bump + `registration_lifecycle` patch deletion ← open — TODO_LIST Priority 2
42. dnsblockd `ManagedOOMPreference=omit` ← open — TODO_LIST Priority 0
43. Foreground BTRFS scrub on `/` ← open — TODO_LIST Priority 0
~~44. aw-watcher fix deploy~~ done — gate healthy (2026-08-17)
45. Turso plan decision; MiniMax quota decision (carried ×4) ← open — TODO_LIST Priority 0 (Turso) + Priority 2 (MiniMax)
46. Darwin deploy (registry override written, undeployed) ← open — TODO_LIST Priority 2
47. BIOS USB-boot disable (DAS hang) ← open — TODO_LIST Priority 2
48. smart-audio audibility verification ← open — TODO_LIST Priority 2
49. browser-history OAuth2 e2e test; dnsblockd dashboard auth verify ← open — TODO_LIST Priority 2
50. WebAuthn `.lan` RP ID validation; orphaned dnsblockd DB trash (724 MB) ← open — TODO_LIST Priority 2

## g) QUESTIONS (cannot determine myself)

~~1. **Did the two Discord messages actually arrive** (buildcache ≥85% TRIGGERED ~03:37 and RESOLVED ~21:58)? Gatus logged both sends; I cannot read Discord. Your yes/no finally closes the receipt question — and if NO, alert delivery IS broken and escalates to an incident (the monitor365 silence would then be part of it).~~ superseded — treated as verified by later sessions (AGENTS.md records the lifecycle as canonical alert-delivery proof; SigNoz notifier probes confirmed Discord receipt 2026-08-16)
2. **Standing commit instruction?** The hard rule is "never commit unless you say so", but the parallel auto-git daemon then sweeps my finished+deployed work with wrong attribution (twice now). Should I commit my own session's work immediately after a green deploy, by default? ← OPEN owner decision (unanswered)
~~3. **Run the hardened GC now or wait for Sunday?** I can't `sudo`. Either you run `sudo systemctl start buildcache-gc` (~1 min, closes b.1 today), or we accept Sunday 05:00 as the first evidence point. Preference?~~ superseded — moot: the run happened, failed, was fixed, and now runs on every deploy

---
**Bottom line:** executed every P0 the prior report left open (GC, sccache, alert evidence, init fix — all with runtime proof), fixed 3 real bugs the execution exposed, deployed clean. Honest ledger: trashed-onto-the-cache-drive (d.1), a repeated overclaim (d.2), uncommitted tree (d.3), and one verification level still owed — the hardened unit's first true run.
