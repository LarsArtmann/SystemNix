# Status: dnsblockd → Hot-DB Wave 2 — Window Execution (Owner-GO Session)

**Authored:** 2026-10-14 22:22 CEST · **Scope:** this session only (continuation of `2026-10-14_19-03` PLAN-ONLY session; owner GO received ~21:00, window fired 21:35:39)
**Live outcome:** `dnsblockd` is **serving on the Samsung hot tier** (`nvme1n1p2[/hot/dnsblockd]`), byte-exact-verified, functionally probed — but the window blew its downtime target ~10×, exited 43 without running finalize, and left `/run/current-system` unanchored (reboot-revert hazard).

## Window timeline (all times CEST)

| T | Event |
| --- | --- |
| 21:1x | cv input's go-modules FOD (from the parallel session's 20:48 flake.lock rewrite, rev `0ad2a6b` = upstream master tip) broke the toplevel build; vendorHash shim re-added per the documented bootstrap exception (first-hand got-hash evidence, gh-verified no upstream-fixed rev exists); commit `5eb7f1a4` (daemon-swept, verified 1-file) |
| 21:35:39 | Window fired. Drift gate PASS (rev 5eb7f1a4, tree unchanged, not mounted, service up) |
| ~21:35:45 | **HARD-DOWN START** (`systemctl stop dnsblockd`) |
| 21:52:33 | Cutover verified byte-exact: 9/9 files, 4,823,594,355 B both sides; marker written. Delta rsync took **17 min** (4.06 GB literal — see §d1) |
| ~22:02:46 | Deploy: pre-checks 99/0/7-warn, nh build 22 drvs green; activation exit 4 (`crowdsec`, `hot-db-bootstrap`, `service-health-check` failed) — but `var-lib-dnsblockd.mount` started and `dnsblockd.service` was started ON the mount |
| ~22:08–22:12 | deploy.sh post-flow incl. post-deploy-check: 147 PASS / 5 FAIL / 14 WARN; **NEW failure vs baseline: "DNS"** (probe raced the service restart); **UNANCHORED** gate → deploy exit 3 |
| 22:12ish | My window script saw deploy ≠ 0 → printed R1 card → **exit 43 without running finalize**. R1 was NOT executed (correct — service was up) |
| 22:16–22:22 | Verification battery + read-only marker cross-check: ALL GREEN (below) |

## Verification battery (22:16–22:22, all first-hand)

- `findmnt`: `/dev/nvme1n1p2[/hot/dnsblockd] rw,noatime,compress=zstd:3,ssd,space_cache=v2,subvol=/hot/dnsblockd` ✅
- `dig @127.0.0.1`: `home.lan` → 192.168.1.150 ✅ · `cache.home.lan` → 192.168.1.150 ✅ · `google.com` → 172.217.19.14 ✅
- stats API `:9090/health` → 200 ✅ · metric `hot_db_entry_mounted{name="dnsblockd"} 1` ✅
- dnsblockd journal: **live LAN client (192.168.1.62) queries being blocked/answered** — real traffic served ✅
- Marker cross-check (read-only, restart deliberately skipped): files 13 ≥ floor 7 ✅; `tracking.db` 2,374,135,808 ≥ marker 2,373,619,712 (grew 517 KB — live writes land on the subvol) ✅
- MemoryHigh watermark: dnsblockd hit it 1,191× since start (§17 sweep) — advisory, watch item

## a) FULLY DONE

1. **T-120 pre-flight audit** — 4.88 GB / 13 files, dataDir not mounted, subvol absent, tier 589 G free, no switch in flight; PSI read recorded.
2. **Warm prepare** — 4.88 GB / 13 files receipt-verified byte-identical, service stayed up; storm calmed mid-run (PSI 36% → 0%, gate passed legitimately).
3. **Entry add + commit `6efafec6`** — all pre-commit hooks green including full `nix flake check` (eval with assertions + btrbk landmine scan).
4. **Build green** after the cv-`0ad2a6b` vendorHash shim (closure `7x08hc1a…`); the shim re-add followed the file's own doctrine (first-hand keep-going got-hash evidence, gh-verified `0ad2a6b` is upstream tip with no fixed rev to float to).
5. **Cutover byte-exact** — 9/9 files / 4,823,594,355 B identical; R0 auto-rollback never needed.
6. **Mount + service live on the hot tier** — the wave's actual outcome is in place and verified (see battery above).
7. **Marker cross-check PASS (read-only)** — biggest-file floor + count floor satisfied without a redundant second restart of the sole LAN resolver.
8. **R1/R4 rollback cards staged and armed** — never needed.
9. **cv upstream verification** (gh API: `0ad2a6b` is master tip, committed 18:45Z today) before choosing shim-over-float.

## b) PARTIALLY DONE

1. **Finalize** — its verification is satisfied (read-only marker gates above) and the service was already restarted by the switch/deploy flow (current PID 3073247), but the script's formal finalize step (restart + probes inside the tool) never ran: the window exited 43 at the deploy-failure branch first.
2. **Deploy** — config IS activated (profile `system-890` exists, nh diff showed the entry's mount + crowdsec units landing), but activation exited 4 (3 failed units) and deploy.sh exited 3 (post-check "DNS" regression + UNANCHORED gate).
3. **gatus "DNS Resolver" self-resolve** — functionally proven (dig ×3, /health 200, LAN traffic), but the journal grep for the check's state came back empty (gatus doesn't log per-check results there); the check-render confirmation is still open. Post-deploy-check's 22:08 "DNS" probe was red (restart gap), since then everything answers.
4. **Docs** — `hot-db.md` wave-2 row not yet flipped to LIVE, `dnsblockd.md` header line not yet added (queued; see harvest).
5. **Harvest** — direct follow-ups landed in TODO_LIST + domain files at authoring time (below); the §f brainstorm is deliberately NOT fully harvested (ROADMAP fuel, per docs-health routing).

## c) NOT STARTED

1. **Re-anchor deploy**: `/run/current-system` still points at the pre-wave generation while profile `system-890` holds the wave — **a reboot right now would revert dnsblockd to the QLC shadow** (intact through cutover, so service would survive, but the tier entry would be lost until re-deploy).
2. **`hot-db-bootstrap.service` failure diagnosis** — it failed during activation; harmless right now (all entries cow=true → no chattr leg; subvol already existed from prepare; the mount succeeded anyway) but the failure cause is unknown.
3. **`crowdsec.service` failure diagnosis** — the parallel session's stage-1 rollout activated in this same deploy and failed (it even ships a `crowdsec-wait-dns` helper — DNS was down mid-window).
4. **`service-health-check.service` failure triage** — likely raced the dnsblockd restart.
5. **Storm-calm re-verification** (plan §3 task 9) — full post-deploy-check pass in a calm window; PSI was 20.6% at report time.
6. **`preflight` action implementation** (plan §3 task 8) — needs its own owner GO.
7. **dnsblockd MemoryHigh watermark follow-up** — 1,191 reclaim events since start; sub-threshold advisory.

## d) TOTALLY FUCKED UP

1. **Hard-down ≈ 27–40 min vs the 2–3.5 min target (the plan's core number).** Root cause: `systemctl stop` makes SQLite checkpoint WAL into the main DBs — the "delta" rsync re-transferred **4.06 GB literal** at ~4 MB/s (QLC read speed) = 17 min. The plan's "10–60 s delta" assumed small WAL tails; for a 4.5 GB SQLite store the delta ∝ dirty pages, not file count. Secondary: the deploy's substituter retried `cache.home.lan` narinfo fetches — **it needed the resolver that was down** — burning minutes before disabling the cache.
2. **The window script's abort branch fired on a HEALTHY outcome.** deploy.sh exited 3 (post-check regression + unanchored) → my `if ! deploy` branch printed the R1 card and exited 43, skipping finalize. R1 (`umount` + start) would have **unmounted a correctly-migrated, serving service**. Only the fact that the script's R1 is a separate manual paste (not auto-executed) prevented a self-inflicted rollback incident. Lesson: the abort branch must verify SERVICE+MOUNT state, not trust the deploy exit code alone.
3. **`/run/current-system` unanchored** — deploy's UNANCHORED gate exits 3, and its own remedy is "re-run deploy", but a plain re-run re-enters the same exit-3 unless the 3 failed units first pass (crowdsec needs DNS — now up; bootstrap unknown). Not yet resolved (see §c1).
4. **Mid-wave build breakage from the shared tree** — the parallel session's flake.lock rewrite moved cv to a rev whose own flake bakes a stale go-modules hash; my build died on it and needed a shim re-add (fix-forward, evidence-documented — but it cost a build cycle and rides their in-flight lock work).
5. **Restoration time is uncertain** — I have no continuous probe between 21:35:45 (stop) and 22:16 (my battery); deploy's 22:08 DNS probe was red, my 22:16 probes green, and the PID changed between 22:03 and 22:16 (restart trigger unattributed — likely the `dnsblockd-attach-ip` provisioner restart or stc re-start). LAN had at least one additional blip inside the window.

## e) WHAT WE SHOULD IMPROVE

1. **Pre-stop WAL checkpoint** in `migrate-hot-db.sh` cutover: `sqlite3 <db> "PRAGMA wal_checkpoint(TRUNCATE)"` per DB BEFORE `systemctl stop` → the quiesced delta shrinks to near-zero and the 17-min literal pass disappears. (Needs sqlite3 in the stop path + fixture update; pairs with the queued preflight action.)
2. **Window-script post-deploy branch must be outcome-aware**: after deploy, check `findmnt` + `systemctl is-active` + a dig; route to R1 ONLY if actually down; exit-3-with-green-service should proceed to finalize and queue the anchor re-deploy instead of aborting.
3. **Downtime budget must be size-scaled**: hard-down ≈ dirty-pages-GB ÷ QLC-read-rate + deploy-min; a per-store estimate belongs in the preflight GO/NO-GO output.
4. **Resolver-adjacent windows should neutralize the binary-cache substituter** (`--option substituters ""` or prewarmed narinfo) — the resolver cannot resolve its own cache during its own migration.
5. **Run the deep post-deploy-check AFTER finalize + settle**, not mid-window (deploy.sh embeds it; its "DNS" regression was the window racing itself).
6. **gatus check-state needs a real probe surface** (API/status page or metrics), not journal grep — journal grep returned nothing useful.
7. **UNANCHORED handling**: when activation failed-units are the only blocker, a targeted unit-retry + `switch-to-configuration` re-anchor via a NEW deploy run is the sanctioned path — encode that as a documented runbook step instead of discovering it mid-incident.

## f) Up to 50 things we should get done next

*(brainstorm, impact-ordered within groups; direct follow-ups are harvested — the rest is ROADMAP fuel)*

**Wave-2 close-out (direct follow-ups — HARVESTED):**
1. Re-run `nix run .#deploy` to anchor `/run/current-system` → system-890 (after the 3 failed units pass; closes the reboot-revert hazard).
2. Diagnose `hot-db-bootstrap.service` failure (journal + aVM-safe repro); it must be green before the postgres wave trusts the bootstrap path.
3. Diagnose/triage `service-health-check.service` failure (expected: raced the restart; confirm and reset).
4. `crowdsec.service` first-activation failure — diagnose (DNS-wait helper timing?) or hand to the owning session.
5. Flip `docs/services/hot-db.md` wave-2 row → LIVE with the ~27–40-min actual; add `dnsblockd.md` header hot-tier line.
6. Queue + confirm the first nightly **btrbk cycle against `hot/dnsblockd`** (landmine live-cycle watch).
7. Queue soak-end reclaim of the dnsblockd QLC shadow (contents-only removal; owner call ≥1 week).
8. Confirm gatus "DNS Resolver" check renders green on the status page (close the §b3 open item).

**Hot-db program:**
9. Implement the `preflight` action (eval + build + drift + PSI + flock → GO/NO-GO) — now with the size-scaled downtime estimate (§e3).
10. Add the pre-stop WAL checkpoint step (§e1) + fixture test.
11. Encode the outcome-aware window-script post-deploy branch (§e2) as the standard window template.
12. Postgres wave: re-plan its downtime with the checkpoint lesson BEFORE its window (its DBs are bigger than dnsblockd's).
13. Add `hot_db_shadow_bytes` per-entry metric (queued guard from the 2026-10-12 split) — today's unanchored-revert hazard is the same "silent state" class.
14. Sweep the hot-db runbook for the "delta 10–60 s" claim and replace with the checkpoint-on-stop model.
15. gatus/browser-history/pocket-id/discordsync/dnsblockd soak-gate calendar: one owner pass to set explicit soak-end dates per wave.

**dnsblockd ops:**
16. Investigate the 1,191 MemoryHigh watermark hits (MemoryMax/MemoryHigh tuning or tracking-db growth policy).
17. Revisit the legacy `dnsblockd_tracking.db` (0.76 GB) + `tracking.db` (2.37 GB) growth — pruning was deliberately out of wave scope; make it an owner decision with a size chart.
18. Add a dnsblockd functional probe to post-deploy-check that tolerates the restart gap (retry-until-green over 120 s) so a migration window doesn't paint a false NEW-failure.
19. Verify dnsblockd's DNSSEC/DoT paths post-migration (only plain A/AAAA probed tonight).
20. Confirm the failover path (`dns-failover.nix`) did/didn't engage during the window — clients saw a hard blip, so likely not; document why.

**Deploy/stability:**
21. Make deploy.sh's UNANCHORED gate actionable: auto-retry the switch once failed units are reset, or emit the exact remediation command.
22. Decide whether post-deploy-check regressions should exit 3 (fail deploy) vs WARN-and-continue-with-report when the deploy itself activated correctly — tonight the strictness nearly triggered a destructive R1.
23. Storm-gate telemetry: the deploy ran under DEPLOY_FORCE_PRESSURE + 5 memory-guard trips — log these overrides to a textfile so a post-incident review can correlate.
24. nh exit-4 ("activation completed with failed units") should list the failed units in deploy.sh's summary line, not only in the scrolled stderr.
25. Consider `systemd-units`-level retry for the 3 failed units inside deploy.sh's existing "Resetting failed units" step (it reset start-limit only).

**Shared-tree / parallel-session:**
26. Adopt a "flake.lock rewrite announces itself" norm: a session rewriting the lock posts the fact (and runs a toplevel build) BEFORE other sessions arm windows — tonight's cv FOD broke a live window's pre-build.
27. Extend the deploy race detector's first-activation warning to also flag first-activation UNITS THAT FAILED (crowdsec appeared as risk, then actually failed — the warning was right).
28. Add the cv shim's drop condition to the pin-audit trace output (it currently only lists deliberate input pins; the shim lives in a comment).
29. Reconcile `docs/todo/upstream.md` cv rows: the 2026-10-10 shim cycle (paste-upstream → push → re-lock → re-drop) applies again at `0ad2a6b`.
30. The parallel session's uncommitted TODO_LIST/browser-history/upstream edits at report time — coordinate before the next harvest sweep (drift risk).

**Monitoring:**
31. Surface `hot_db_entry_mounted` for dnsblockd on a dashboard tile (metric exists, tile unverified).
32. Add a SigNoz rule: `hot_db_entry_mounted{name="dnsblockd"} == 0` for >2 min (gatus covers presence; a second surface covers flapping).
33. Log the window timeline (stop/verify/activate/serve timestamps) into a textfile collector from migrate-hot-db.sh — tonight's timeline was reconstructed from logs.
34. node-exporter journal rate 347/min (§18 FAIL tonight) — attribute (likely dnsblockd block-line spam during the window) and decide rate-limit vs tolerated.

**Upstream / cv:**
35. File the cv upstream issue: go-modules vendorHash stale at master tip `0ad2a6b` (got XLIgHM1V… vs specified NeXR9Ened…) — verify-before-filing first.
36. After upstream fixes: re-lock cv past the fixed rev, drop the shim (the documented cycle), re-verify toplevel.
37. BuildFlow is present in this repo (`.buildflow.yml`): evaluate `buildflow -s nix-hash-fix` against the cv-style FOD class as the sanctioned hash-paste path (the cv.nix comment already says "Re-add ONLY via nix-hash-fix evidence").
38. templ float (`?ref=refs/heads/main`, 20:48 commit): watch the regen-skew warning class its own comment predicts.

**Tooling:**
39. Ship the outcome-aware window script as `scripts/hot-db-window.sh` (template + per-service registry), replacing tonight's /tmp one-offs.
40. Fixture-test the R1 card contents (the umount+start one-liner) — tonight it was never exercised, by luck.
41. `migrate-hot-db.sh status` should show the marker's BIG_SIZE vs live size (the cross-check I ran by hand).
42. Add `--skip-finalize-restart` mode to finalize for the "service already restarted by the switch" case (tonight's deviation, codified).

**Docs:**
43. Record the checkpoint-on-stop lesson in `docs/agents/storage.md` (it generalizes to every future SQLite wave).
44. Record the "deploy exit-3 during window ≠ abort" lesson in `docs/services/hot-db.md` window doctrine.
45. Annotate the wave-2 plan file with ACTUALs (its §1 budget table is now measured data).
46. `docs/services/crowdsec.md` (the parallel session's new runbook) will need the first-activation failure post-mortem appended.

**Hygiene:**
47. Clean `/tmp/w2-*` scripts after close-out (they contain no secrets; R1 card should be preserved in the runbook first).
48. The `/tmp/w2-build.log` evidence file referenced by the cv shim comment — move the got-hash evidence into the repo (docs or commit message) so the comment's pointer survives /tmp cleanup.
49. TODO_LIST is at 40+ open rows again — next docs-health pass should HARVEST/prune before adding more.
50. Plan-vs-actual retro: the plan's §4 micro-schedule (T-minus) worked exactly as designed for everything EXCEPT the two things it couldn't see (checkpoint delta, deploy exit-3) — fold both into the preflight action spec so wave 3 (postgres) inherits them as code.

## g) Questions I cannot answer myself

1. **Anchor now or coordinate?** Re-running `nix run .#deploy` within the hour anchors system-890 and closes the reboot-revert hazard, but it restarts services once more (dnsblockd blip included) and re-enters the exit-3 path unless the 3 failed units first pass. Do you want the anchor re-deploy now, after I triage the failed units, or folded into the parallel session's next deploy?
2. **crowdsec ownership**: the failed `crowdsec.service` belongs to the parallel session's stage-1 rollout (enabled in their 20:48 commit). Is it theirs to fix, or do you want me to diagnose it (its journal + the `crowdsec-wait-dns` helper timing) as part of the anchor re-deploy?
3. **Downtime doctrine for big SQLite stores**: accept "checkpoint-on-stop makes the delta ∝ dirty pages" as inherent and re-baseline the target (e.g. "~1 min per GB of dirty pages on QLC reads"), or fund the pre-stop WAL checkpoint step in `migrate-hot-db.sh` (needs sqlite3 in the stop path + a fixture update) before the postgres wave?

## Harvest (direct follow-ups landed at authoring time)

Rows added to `TODO_LIST.md` + domain libraries: anchor re-deploy (services), hot-db-bootstrap + service-health-check diagnosis (services), crowdsec first-activation failure (services), wave-2 docs flip (services), migrate-hot-db pre-stop checkpoint + outcome-aware window branch (services), btrbk live-cycle watch for hot/dnsblockd (storage), soak-end dnsblockd shadow reclaim (storage). §f items 9–50 deliberately NOT harvested (brainstorm/ROADMAP fuel per docs-health routing).
