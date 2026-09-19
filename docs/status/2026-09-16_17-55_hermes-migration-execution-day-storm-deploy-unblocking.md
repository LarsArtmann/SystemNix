# Hermes @home-hermes Migration — Execution Day: IO Storm, Buried Outages, Deploy Un-Blocking

**Session:** 2026-09-16 ~14:10 → 17:55 CEST (continuation of the 2026-09-15 subvolume migration session)
**Machine:** evo-x2 (local master, ~110 commits ahead of origin — push still GH013-blocked)
**Live state at report time:** newest config ACTIVATED (`jc7jvkvn…ef34387`, 17:48) but **UN-ANCHORED** (`/nix/var/nix/profiles/system` still `system-779` = `eaad089` pre-migration era). Hermes mount LIVE on `@home-hermes`. 46 crush sessions. IO PSI chronically 45-75% (oscillating between real storm and corpse-pile phantom).

---

## What happened this session (timeline)

| Time        | Event                                                                                                                                                                                                                                                                                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 14:15       | User ran `prepare` v1 → died instantly on `rsync --reflink=always` (MY bug — the documented 2026-08-17 @nix class, repeated). Empty subvol left behind.                                                                                                                                                                                                       |
| 14:40–15:22 | User re-ran (fixed script) **into an active IO storm** (declined my Ctrl-C advice) — 92.3 GB / 948,341 files / 42 min, pass-2 delta **zero**, parity gate clean, mv-aside swap done. QLC at 100% busy for the duration; guard Zone 6 cycled; flm socket sacrificed (still down at report time).                                                               |
| ~15:23      | `line 228 syntax error` after "prepare DONE" — parallel session editing the script mid-run; harmless (functions already parsed).                                                                                                                                                                                                                              |
| 15:25       | Restored hermes via 3 systemctl commands (mount + reset-failed + start) — verified live on the subvol.                                                                                                                                                                                                                                                        |
| ~15:45      | Discovered hermes had been **down 7h**: a parallel session's 08:25 deploy (manual `stc test`, nixpkgs bump) shipped the migration config and hit the deploy-before-prepare hazard exactly as the prior session's status report predicted ("fucked up #1").                                                                                                    |
| 15:57       | User's `nh os switch` died at eval: `cannot coerce the built-in function 'head'` — brand-new `sops-recipient-audit` module (parallel session, 15:39) had never evaluated once; it broke every deploy + pre-commit on the box.                                                                                                                                 |
| 16:0x–16:2x | Fixed 3 bugs in the module (see below). Tree buildable again; assertions evaluate truthfully green; flake check passed.                                                                                                                                                                                                                                       |
| 16:2x–16:4x | User's 2 deploys aborted at the **wedge detector — false positive**: `pgrep -f 'switch-to-configuration'` matched a parallel session's **remote pbx deploy ssh client** (hung 2h+). The printed kill advice would have killed the remote deploy mid-flight. Fixed the detector (real lock-ownership verification via `/proc/<pid>/fd`), committed `d5501bdf`. |
| 17:4x       | User ran `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (gate first read corpse-signature idle disks 0.7%, then real storm 95.5% — the storm oscillates). Build fine (35 drvs, 42s); **activation exit-4** on browser-history.service (recovered by deploy.sh post-switch restarts); config activated; **profile bump skipped again**; 6 smoke failures (below).  |

---

## a) FULLY DONE

1. **Migration live path complete and verified**: `@home-hermes` subvol (92.3 GB, parity-verified), fstab mount LIVE at `/home/hermes` (subvolid 465), hermes gateway + mnemosyne + MCP supervisor running FROM the subvol, zero startup errors, original preserved at `/home/hermes.old`. The migration config (fstab + btrbk entry + `RequiresMountsFor`) has been live since the 08:25 deploy.
2. **`rsync --reflink` v1 bug fixed** (commit `37c6fae6`): plain two-phase rsync (state is not reflink-able via rsync — that flag is cp syntax; verified locally: sockets, hardlinks, dry-run parity all fine on rsync 3.5.0).
3. **Migration script storm-hardened** (commits `38fc8c8d`/`ff366633` + daemon batch): refuses to start at io PSI some avg10 ≥20% (deploy-gate bar), ionice idle on both passes, `--info=progress2` + source-size print, self-wipes partial staging on retry, post-quiesce failure hint trap. Guard logic unit-tested in a harness.
4. **sops-recipient-audit eval un-broken** (daemon batch `1a03314d`/`07f87403`): (i) Nix list-literal application trap — `[ f x ]` is TWO elements; the refs list carried the primop `head` itself (parallel session fixed the same line in parallel; both landed); (ii) `fileRecipients` returned a list-of-lists (would die on first multi-recipient file); (iii) `ruleRef` captured `key_groups` structure lines (`- age:`) as recipients — **28 false positives** flagging every secrets file. After fixes: assertions `[]`, `nix flake check --no-build` all green.
5. **deploy.sh wedge detector fixed** (`d5501bdf`): both wedged + concurrent checks now verify actual `/run/nixos/switch-to-configuration.lock` ownership via `/proc/<pid>/fd`. Live-verified against the pbx ssh (does not hold). Shellcheck-clean (after one SC2010 iteration).
6. **7h hermes outage root-caused** and hermes restored without a deploy.
7. **Docs corrected**: rsync-has-no-reflink recurrence noted in AGENTS.md + gotchas-archive; measured 92.3 GB / 948k files recorded in hermes.md runbook (was "~1 GB" everywhere).

## b) PARTIALLY DONE

1. **Generation anchoring** — diagnosed, fix commands delivered **three times**, never run. After the forced deploy the box is now TWO un-anchored systems deep (current `jc7jvkv` activated 17:48; profile still `system-779`/eaad089). A reboot boots eaad089: no home-hermes fstab → empty placeholder → **brainless hermes** + full config revert. One clean deploy OR the 2 surgical commands close it.
2. **The deploy itself** — config IS activated (mr-sync dashboard, browser-history agent metrics, llama-rag config-disable removal, md-go-validator + todo-list-ai bumps all live), provisioner-restart sweep ran, paperless-dashboard-provision now PASSES (parallel session's write-probe fix works). But exit-4 skipped the profile bump and 6 smoke checks failed (below).
3. **Migration backup leg** — btrbk `@home-hermes` entry deployed; first full ~92 GB pool send rides tonight's 23:00 timer (unverified; runs into whatever storm state exists).
4. **finalize** — by design gated days away (mount live + hermes active + first snapshot exists).

## c) NOT STARTED

1. VM-test assertion 2b (`RequiresMountsFor` pin, test-hermes.nix) — **never executed anywhere** (CI unreachable: push blocked).
2. GH013 push unblock — URL click is user-only; 110+ commits waiting.
3. Hermes `state.db` WAL forensics — retired capture at `/home/hermes.old/state.db.retired-wal-20260916-020432-114425` (another writer touched the DB 02:04–08:25; upstream-repo material).
4. CV pipeline-store health failure — `/health` lacks the check; deployed binary may predate 2026-09-02 (predates the 08:25 deploy? binary version says `ed8b92f` — needs triage; :8098 metrics dark all day).
5. Bank-Sync `sync_errors_total > 0` since restart (partial: Wise data + one successful sync present).
6. `crush-rc-test.sh` missing from the post-deploy-check derivation (the smoke's Crush check is a phantom-fail — parallel session's post-deploy-check.sh edit references a script not packaged).
7. signoz-provision exit-code failure (failing in 1.26s wall since 08:25; retried at 17:4x, still failing — rules/dashboards stale).
8. InboxClean main account `auth_expired` (work account fine) — OAuth runbook is user-run.
9. Empty `@home` toplevel subvol cleanup; TODO_LIST harvest; retention-number de-duplication (from prior session backlog).
10. pbx remote deploy (parallel session's ssh, hung 2h+) — ownership theirs.

## d) TOTALLY FUCKED UP (mine, honestly)

1. **`rsync --reflink=always` in script v1** — I repeated a landmine documented in this very repo (`docs/status/2026-08-17…`, AGENTS @nix entry) because I pattern-matched on migrate-clickhouse-xfs instead of checking the CORRECTED sibling migrate-nix-subvol. Cost: one aborted run, user confidence, a fix commit.
2. **The "~1 GB" size assumption** — stated in the script's own output message and my ETA reasoning; reality 92.3 GB / 948k files (92× off). Never measured. This made the copy-time estimate nonsense and made me under-rate the storm impact of the copy.
3. **The Ctrl-C recommendation had the wrong premise** — I read 25 min of D-state + unknown size as unbounded; the copy completed fine at 38 MB/s. The census was right, the call was wrong. (The hardening it motivated is still correct and stays.)
4. **Shipped the deploy-before-prepare hazard unguarded (prior session's choice, recurred today as the 7h outage)** — the ConditionPathIsMountPoint skip-pattern guard was offered and not shipped; a parallel deploy then detonated it. Known-unsafe shape left in the tree overnight.
5. First hardening commit attempt lost attribution to the daemon race (minor, but I knew the daemon races and still lost the race window).

## e) WHAT WE SHOULD IMPROVE

1. **Measure, then assert** — sizes, ETAs, and "trivial" claims need a number first (`du` now printed by the script pre-copy; should have been there day one).
2. **Check corrected precedents before writing kin scripts** — the repo keeps learning the same lessons; the @nix incident doc even said "recurred" would be inexcusable, and it recurred.
3. **P0 operator actions get buried by new fires** — the anchor commands were correct at 15:50 and are STILL unrun at 17:55 because three successive incidents (eval bug, wedge FP, pressure gate) each replaced the message. A pinned "do these two commands before anything else" list would have survived.
4. **Parallel-session topology needs a coordination rail** — today: one session deployed at 08:25 (hazard), one is deploying pbx (wedge FP victim), one shipped a never-evaluated eval-breaking module, one rewrote git history mid-flight, and 46 interactive sessions drive the IO weather that gates everyone's deploys. The tree and the box are shared; the coordination is not.
5. **`--no-verify` on a red tree hides fires** — the crush agent bypassed the failing flake check at ~15:4x; that same failure then blocked deploys "mysteriously". A red flake check should page, not get bypassed.
6. **Guards that have never evaluated are negative value** — sops-recipient-audit shipped committed-but-broken (its own author couldn't have seen its output). New eval-time guards should land with a green eval in the same commit.

## f) NEXT — up to 50, priority order

**P0 (reboot-safety chain):**

1. ANCHOR: `sudo nix-env --profile /nix/var/nix/profiles/system --set /run/current-system && sudo /run/current-system/bin/switch-to-configuration boot` (or one clean deploy)
2. `nix run .#pre-reboot-check`
3. REBOOT (owed since 2026-09-05): clears D-state corpse pile (PSI becomes truthful), guarantees flm :52626 clean
4. Post-reboot: verify home-hermes.mount from fstab + hermes auto-start + profile==current-system
5. Post-reboot clean deploy (ships everything, proper profile bump)

**P1 (today/tomorrow):**
6. Watch tonight 23:00 btrbk — first full ~92 GB `@home-hermes` snapshot + pool send
7. Tomorrow: `migrate-hermes-subvol.sh status` — first local snapshot + pool receive verified
8. Triage CV pipeline-store `/health` missing check (binary version vs deployed rev)
9. Triage Bank-Sync sync_errors (journal `journalctl -u bank-sync -n 100`)
10. Fix crush-rc-test.sh packaging in post-deploy-check (phantom smoke failure)
11. Diagnose signoz-provision 1.26s exit-code failure (rules/dashboards stale)
12. InboxClean main re-auth (user runbook; work account unaffected)
13. flm socket restore verification (guard auto-restore post-reboot)
14. GH013 push-unblock click → `git push` (110+ commits)

**P2 (this week):**
15. Run `nix build .#checks.x86_64-linux.test-hermes` (assertion 2b never executed)
16. Hermes WAL retired-capture forensics → upstream issue
17. sops-recipient-audit: VM-test fixtures use the REAL .sops.yaml key_groups shape (fixture≠truth class)
18. TODO_LIST harvest from this + prior session reports
19. Storm governance: cap concurrent crush sessions (Gatus threshold >6; today 40-46)
20. crush-hot-db deploy decision (gated on /nix soak)
21. pbx wedged deploy ssh — parallel session follow-up
22. SigNoz "Trace Coverage Missing" alert firing >24h (cv dark contributes)
23. zram 84.7% — within 8 points of the 92% zone; post-reboot re-baseline
24. quickshell 1 error line (last 1h) — triage
25. Retention ratification (see questions) + retention-number de-dup across docs
26. `finalize` migration (after settling days): trash `/home/hermes.old`
27. Empty `@home` toplevel subvol cleanup
28. Browser-history agent metrics: retire the gatus new-metric loan entries once live
29. Deploy pressure gate: consider a corpse-pile-aware bypass hint (PSI high + disks idle + known pile = suggest reboot, not force)
30. Consider `ConditionPathIsMountPoint`-style skip-guards for ALL RequiresMountsFor-on-new-mount shapes (lesson from the 7h outage)

## g) QUESTIONS (cannot figure out myself)

1. **Reboot window**: the reboot kills your 46 crush sessions, the pbx deploy ssh, and any running agent work. When do you want it — now, tonight after 23:00 btrbk, or a specific window? (Everything P0 chains behind it; the landmine stays armed until the anchor runs either way.)
2. **Pool retention ratification (still open since the prior session)**: `@home-hermes` pool receives currently use bounded `7d`/`14d 4w` (Option A, what I deployed). Keep it, or switch to forever like `@` (Option B)? With 92.3 GB per full send and a 15 TB pool, this materially changes pool burn.
3. **The crush agent's git history surgery** (commit-tree + update-ref rewrite to fix its commit message, done mid-session while bypassing the red pre-commit): review it before the push unblock, or accept its self-verification and push as-is once unblocked?

---

_Report written 17:55; machine state snapshot: current-system `jc7jvkv…ef34387` (un-anchored), profile `system-779`/eaad089, hermes mount LIVE, 46 crush sessions, signoz-provision failing, tree clean at `2ec61542`._
