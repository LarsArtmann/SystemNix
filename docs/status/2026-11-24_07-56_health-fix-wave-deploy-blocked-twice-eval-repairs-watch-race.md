# Health-Fix Wave: Deploy Blocked Twice by Foreign Churn + Pressure Gate; Eval Repairs; Watch-Race Inventory

**Scope line (verified vs not):** This report describes the resumption session that continued the 05:21 health-sweep work (audiblesync backup fix + desktop-notification dedup, both already in-tree). VERIFIED live: tree/commit state via `git status`/`git log` at each step; the 07:05 deploy failure via `/var/log/systemnix-deploys/2026-11-24_07-05-24.log` (4 battery failures quoted verbatim); the 07:41 deploy failure via `2026-11-24_07-41-24.log` tail (rc=12 pressure refusal, 5s); eval failures via two full `nix eval --raw …toplevel.drvPath` runs (duplicate-attr error and mount-gating assertion quoted); watcher health via `/proc` + `~/.cache/deploy-when-quiescent.log`. NOT verified (blocked or deliberately not attempted): any post-deploy runtime proof (no deploy has landed — the audiblesync unit render and dedup double-run journal evidence remain pending); whether the eval is green at HEAD 57cc30f7a after the foreign wave (last full eval 07:3x was red on mount-gating; the foreign session's fix commits landed after and were NOT re-evaluated before this report per the no-new-research instruction); the contents of the 514-file commit 2655f7281 beyond its identity (author Lars via daemon, 07:51:53). Repo HEAD at report time: `57cc30f7a`.

---

## What this session did

Resumed the interrupted 05:21 session with four remaining steps: eval retry, TODO harvest, quiescence-gated deploy, post-deploy verification. Steps 1–2 completed (with two extra eval repairs surfaced along the way); step 3 attempted twice by proxy (armed watcher + foreign fires) and blocked twice; step 4 therefore not reachable. Session ends waiting for owner instruction on the deploy.

## a) FULLY DONE

1. **audiblesync backup fix, both layers, committed** — `mkPoolDirUnit` owner dropped (hardened-root EPERM class) + `caps = "CAP_DAC_READ_SEARCH"` on `mkSqliteBackupUnit`; live state converged earlier (dir chowned, 1.2 MB WAL-safe backup, `backup_healthy{audiblesync} 1`, age 0h). Ride commit b63a00e22.
2. **Desktop-notification dedup implemented + rotted second copy deleted** — per-failure-set sha256 state in `~/.cache/service-health-check/last-notified-failed` (notify only on set change; green clears state; exit-1 semantics deliberately untouched); dead `platforms/nixos/scripts/service-health-check` removed. Same commits.
3. **Session report (05:21) delivered** — sections a–g, 35 ranked next items, 3 owner questions.
4. **TODO harvest — actually landed this time** — 11 `[ready]` queue rows + 12 library rows (services ×5, monitoring ×5, stability ×1, storage ×1; paperless backlog `[blocked:user]` library-only), single atomic edit pass at 06:0x; report ledger line corrected to name the real landed set (the original line claimed the harvest before it existed — see §d.1).
5. **Eval repair #1: duplicate systemd attrs in `gatus-alert-relay.nix`** — foreign tq edit added a second `after`/`wants` pair (lines 139 vs 151); merged into `[ "network-online.target" ] ++ lib.optionals tqSinkEnabled [ "tq-api.service" ]` with the ordering comment preserved. Verified fixed: the next eval got past it.
6. **Eval repair #2: untracked sops secret `platforms/nixos/secrets/tq.yaml`** — the tracked-files trap (whole dir behind `.gitignore:144 secrets*`; sibling convention is force-add); verified sops-encrypted (`ENC[AES256_GCM` ×2) then `git add -f`. Eval's "not tracked by Git" error gone.
7. **Foreign deploy failure forensics ×2** — read both deploy logs, extracted every `✗`, identified the failure chain: 07:05 = PSI storm + tree-wide eval break (brandAssets + papdashboard legs downstream) at tree 50bb391; 07:41 = rc=12 designed pressure-gate refusal at entry (sdc 105.3%, app.slice ghosts 70–80% PSI, 5s, no build attempted).
8. **Foreign-session eval-break root-caused to upstream state, not tree rot** — `timesheets.nix:293` needs `cfg.package.brandAssets`; upstream local checkout HAS `passthru.brandAssets` at both c75d195 and 2697de8; the 07:05 failure tree predated the foreign session's second lock float (70b809da6). No SystemNix-side fix needed — upstream was already fixed; the lock was mid-iteration.
9. **Watcher discipline held** — found PID 1054447 already armed, did NOT arm a sibling; used its log as the single fire source; my observe loops caught both foreign deploy outcomes and the watcher's own rc=12 stop with DISARM-LIST.

## b) PARTIALLY DONE

1. **The deploy itself** — the whole point of "go and fix audiblesync" is not live yet. Two blocked attempts: 07:05 (foreign direct-fire, 4 battery failures incl. the then-broken eval) and 07:41 (watcher-fired, rc=12 pressure gate by design). Both watchers now dead; no deploy landed; the module fixes still eval-only.
2. **Eval-green state at HEAD** — my last full eval (07:3x) failed on the mount-gating audit (`tq-api`, `bank-sync-fresh-start`, `media-atlas-archive-perms` ReadWritePaths under /mnt/pool without gating). The foreign session landed `a1897abc8` (bank-sync.nix + media-atlas.nix edits — their mount-gating fixes) and the 514-file 2655f7281 afterwards; I did NOT re-run the eval before this report (scope discipline), so green is UNPROVEN, not assumed.
3. **Post-deploy verification battery** — designed and ready but unexecutable without a landed deploy: `systemctl cat audiblesync-backup` shows `CapabilityBoundingSet=CAP_DAC_READ_SEARCH`; forced `audiblesync-backup` run green + file written; `service-health-check` ×2 shows `NOTIFIED:` then `NOTIFY-SKIPPED:`; gatus "Backup Freshness: audiblesync" green; deploy-anchor gen-N check.

## c) NOT STARTED (this session's scope — carried or queued)

1. All runtime verification legs above (blocked on deploy).
2. The 05:21 report's §c items (P0 thermal driver, root-disk 94% reclaim, memory-guard churn) — untouched here; they sit in the queue/report of record.
3. Owner questions from 05:21 §g (thermal shutdown-guard, paperless purge-vs-preserve) — no answers received; re-asked below where still open.

## d) TOTALLY FUCKED UP (honest accounting)

1. **The 05:21 report's verification ledger claimed the TODO harvest was done BEFORE it was done** ("queued via TODO_LIST + domain libraries in one edit pass") — a fabricated close-out of exactly the 2026-09-29 count-claim class. The resuming session caught it by grepping for the report's filename in the todo corpus (rc=1, zero rows). Corrected 06:0x by doing the harvest for real and rewriting the ledger line to name the actual landed set. Lesson: ledger lines must say "pending" until the rows exist on disk.
2. **~90 minutes of dead watching with inverted detection semantics** — my first observe loop compared against a stale `LAST_LOG` baseline, so when re-armed it "detected" the 07:05 deploy that had already failed 6 minutes earlier; the 55-min v2 loop timed out with no escalation path; between 06:56 and 07:16 nothing watched anything while a foreign deploy fired and failed. The final monitor loop (commit-base + watcher-alive polling) was the correct shape and should have been loop #1. Cost: the session learned about the rc=12 stop ~15 min late.
3. **"Eval blocked only by parallel-session churn" was a premature verdict** — the 05:57 rc=102 read attributed the failure wholly to tree churn; the tree actually had THREE stacked real problems (duplicate attrs, untracked sops file, then brandAssets-at-stale-lock, then mount-gating trips). I fixed two and never asserted green — but the mental model was wrong for an hour. A full drvPath eval at the first retry would have enumerated the layers in one pass (`--keep-going` discipline applies to evals, not just builds).
4. **Two quiescence watchers were armed simultaneously (1054447 mine, 400455 foreign)** — discovered only via the DISARM-LIST when mine stopped at 07:41. The 2026-10-28 two-sequencer race class materialized across sessions; we got away with it only because rc=12 refused at entry (no build, no switch). The arming check (`pgrep -af deploy-when-quiescent`) found 1054447 but 400455 was evidently armed after it — there is no cross-session registry, so the check can never be reliable as-is.
5. **A foreign direct-fire deploy ran mid-wave (07:05) and burned a full 5-minute battery on a known-broken tree** — not my action, but my session contributed nothing to prevent it and the battery result (4 failures) was fully predictable from the eval state. The pressure gate (07:41 rc=12) then correctly refused during a 100%+ disk-busy storm. Net deploy-attempt cost tonight: 2 batteries, 0 deploys.

## e) WHAT WE SHOULD IMPROVE (systemic, from this run)

1. **Eval-health pre-check before arming ANY deploy path**: one `nix eval --raw …toplevel.drvPath` run, errors captured once to `~/.cache/`, greped N times — before the watcher, not after (the watcher's gate C only proves green at fire time; knowing the layer stack early turns "watch and hope" into "fix the named units").
2. **Cross-session watcher registry**: arming checks must query `/proc` for ALL `deploy-when-quiescent` processes (mine did), but two sessions can arm seconds apart; a file-based claim (`~/.cache/systemnix-deploy-watcher.lock` with PID + start time, stale after 30 min) would make the one-watcher rule enforceable.
3. **Observe-loop shape standard**: capture the log/commit baseline AT ARM TIME, first check immediate (not after the first sleep), escalate on loop exit (don't silently end), and treat "loop timeout" as a finding to report, not silence.
4. **Ledger honesty gate**: verification-ledger lines that describe work not yet on disk should be written as `pending (lands: <surface>)` and flipped only after a self-grep proves the landing — the same spot-verify-at-queueing rule the TODO system already has, applied to status reports.
5. **Foreign-wave waiting protocol**: when the blocker is another session's mid-flight work (tonight: timesheets float + mount-gating fixes), the correct move was bounded monitoring with explicit hand-off criteria (20-min monitor worked once adopted); document it as a pattern instead of re-deriving it.

## f) Next — ranked (up to 50; queued-status marked Q)

**P0 — get the fixes live**

1. Re-verify eval at HEAD post-foreign-wave (drvPath; expect the mount-gating trips fixed by a1897abc8/2655f7281 — unproven) → then deploy. **[NEW — Q as the deploy row below]**
2. Deploy the health-fix wave (audiblesync caps + dir-owner, service-health-check dedup, rotted script removal) at a calm window or with owner-approved pressure override. **[Q — added to TODO_LIST + services.md this pass]**
3. Run the post-deploy verification battery (§b.3 legs) and update the 05:21 report ledger + tick the queue rows. **[Q — same row]**
4. Thermal driver (98–99°C oscillation, freeze #55 nearly certain) — carried P0 from 05:21, still unowned. **[already in 05:21 report; not re-queued]**
5. Root disk 94% + `root_prune_guard_fired` + mold SIGBUS — carried P0. **[not re-queued]**
6. tq-agent-pool `memory.events max` 3.3M churn — carried P0. **[not re-queued]**
7. post-crash-calm-gate 22:13 failure → llama-embeddings re-arm. **[Q 06:0x — stability.md]**

**P1 — real outages (from the sweep; queued unless noted)**
8. CV suite 9× gatus 401 + cvagent :8787 hang. **[Q — services.md]**
9. Paperless 3,426-task backlog + 1,244 verdict_down. **[Q library-only — blocked:user]**
10. Backups stale: data 999h / pool 195h / root 174h + 2 failed units. **[Q — storage.md]**
11. forgejo-github-sync exit 1 + dead mirror candidate. **[Q — services.md]**
12. Bank-Sync SCA — owner must approve in Wise app. **[owner]**
13. onprem nixos-0 (192.168.1.100) unreachable. **[owner question]**
14. NetBird Dex healthz 404. **[Q — services.md]**
15. InboxClean-sync + MediaAtlas lanes failed, rollup 26.9h. **[Q — services.md]**
16. monitor365 `cloud_sync_consecutive_failures` absent. **[Q — monitoring.md]**
17. hermes `signoz_traces_reporting 0`. **[Q — monitoring.md]**
18. Decide the pressure-gate vs chronic-storm doctrine (rc=12 will keep refusing during storm eras; loop-back-on-rc12 vs human-review-always). **[NEW — Q this pass, stability.md, decision]**
19. Cross-session watcher registry (file-lock claim + stale detection). **[NEW — Q this pass, pipeline.md]**

**P2 — monitoring-layer repairs (queued)**
20. system-health.nix:541 → `/api/v3/rules` + `data.total`. **[Q — monitoring.md]**
21. FastFlowLM gatus checks retire + flm journal-scan timeout. **[Q — monitoring.md]**
22. "Enabled But Inactive Units" condition-leg verification vs real engine. **[Q — monitoring.md]**
23. Per-endpoint gatus up-gauges OR loopback statuses JSON. **[05:21 §f.19]**
24. Chronic-red aggregate → SEV1 tier (one event, not eighty). **[05:21 §f.20]**
25. SEV1 bridge active-alert naming. **[05:21 §f.21]**
26. `secret_rotation_all_fresh 0` — find the stale secret. **[05:21 §f.22]**
27. dnsblockd allowlist-backup false-red close. **[05:21 §f.23]**
28. Cosmetics batch (Architecture Catalog title, EMEET fragment, OpenCloud webfinger). **[05:21 §f.24]**
29. BTRFS wave: health-critical + stale scrubs + chunk drill. **[05:21 §f.25]**
30. fstrim 4328s why. **[05:21 §f.26]**
31. coredump-handler failed-unit noise in sweeps. **[05:21 §f.27]**
32. User units ×3 failed (gdd-crtsh, go-cqrs-nightly-bench, nextd-refresh). **[05:21 §f.28]**
33. PMA heuristic fallbacks 498/24h. **[05:21 §f.29]**
34. Docs: "67 endpoints" claims → registry-derived. **[05:21 §f.30]**
35. Rust cache over threshold. **[05:21 §f.31]**
36. `boot_userspace_regression 1` drill. **[05:21 §f.32]**
37. forgejo auth failures 58/24h baseline 15. **[05:21 §f.33]**
38. Probe-red vs chronic-red triage helper under scripts/. **[05:21 §f.34]**
39. Inter-session deploy lock (file-based) against quiescence starvation. **[05:21 §f.35 — pairs with §e.2]**
40. Eval-health pre-check standardization (drvPath eval before arming). **[NEW — Q this pass, pipeline.md]**

**P3 — hygiene**
41. `branching-flow` override warning (non-existent input treefmt-nix) — cosmetic but every eval prints it. **[NEW this session]**
42. nixpkgs-pin vs running-system MISMATCH advisory (running 0bb8272 / pinned 2786a2a) — deploy-forward to clear. **[from 07:05 log]**
43. The 514-file mega-commit needs a stat review (daemon heuristic swept something large at 07:51). **[NEW]**
44. Mount-gating audit: confirm tq-api trip fixed by the foreign wave; if not, allowUnits with justification or `RequiresMountsFor`. **[conditional on #1]**
45–50. Remainder of the 05:21 §f list (items 19–35 not individually re-listed here) — tracked in the 05:21 report and the queue; no drift intended.

**Self-harvest note:** NEW direct follow-ups of THIS report are items 2+3 (one combined deploy+verify row), 18, 19, 40, 44 — landed in TODO_LIST + domain libraries in the same authoring pass per the AGENTS self-harvest rule. Items 4–6, 8–17, 20–39 were already queued by the 05:21 harvest or are owner-gated; deliberately not re-harvested to avoid duplicate rows.

## g) Questions for the owner (cannot be answered from the box)

1. **Deploy authority under pressure:** the wave is twice-blocked (broken tree mid-iteration, then the designed rc=12 pressure refusal with sdc at 105%). Do you want me to (a) re-arm the watcher and let it fire when calm, (b) fire with `DEPLOY_FORCE_PRESSURE=1` now that the foreign wave has landed, or (c) you fire it yourself at a moment you pick?
2. **The foreign wave (tq session):** it landed two lock floats, mount-gating fixes, and a 514-file daemon mega-commit between 07:00 and 07:51 — is it still expected to continue editing tonight, or is it done (i.e. is the tree safe to treat as settled for a deploy)?
3. **Carried from 05:21 §g, still unanswered:** thermal shutdown-guard (sustained ≥99°C → page) — yes/no? Paperless 3,426-task backlog — purge or preserve? (Both are decisions only you can make; they gate P0/P1 rows.)
