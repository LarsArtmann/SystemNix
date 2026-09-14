# Status Report — 2026-09-14 16:34 CEST

**Session scope:** unblocking the blocked `nix run .#deploy` (pre-deploy §10 phantom-metric FAIL on `bank_sync_*`), root-causing it to the 13:35 boot's pool-mount dropout, fixing the class at three layers, and verifying end-to-end.

**One-line state:** the deploy gate is UNBLOCKED (verified, rc=0), the fixes are NOT yet deployed, and bank-sync + immich-server + paperless-web have now been down ~3 hours (since the 13:35 boot) — recovery rides the next deploy's post-switch pool-usb-recovery run.

---

## a) FULLY DONE

1. **Root-cause diagnosis of the deploy block** — pre-deploy §10 hard-FAILED on `bank_sync_last_sync_timestamp_seconds` / `bank_sync_sync_errors_total` absent. Traced to: 13:35 boot → `mnt-pool.mount` start job cancelled same-second (helper SIGTERM'd, `Failed with result 'signal'`) → pool-usb-recovery remounted 13:36:56 (worked as designed) → bank-sync / immich-server / paperless-web — all enabled, Requires-ing the mount — never started by anyone all boot. Evidence: zero PID1 lifecycle lines for all three, zero "Dependency failed" journal entries, zero pending jobs, Gatus Bank-Sync red since 13:40, Discord alerts fired 13:42/13:50.
2. **Diagnosis of WHY the old guards missed it** — (a) pool-usb-recovery's consumer step was is-failed-only (the units are inactive, NOT failed); (b) the healthy-mount path `exit 0`'d BEFORE the consumer step, so even deploy.sh's post-switch recovery run converged nothing; (c) the §10 gate had endpoint-down WARN branches for monitor365/discordsync/cv but NOT bank-sync.
3. **Fix layer 1 — gate:** `BANKSYNC_METRICS`/`BANKSYNC_UP` endpoint-down WARN branch added (`scripts/lib/metrics-gate.sh` + `scripts/pre-deploy-check.sh`); bank-sync down ⇒ WARN, up-but-absent ⇒ still hard FAIL. Evidence: fixture tests 13/13 OK (`bash scripts/test-pre-deploy-metrics.sh`), and a real full `scripts/pre-deploy-check.sh` run exited **rc=0 — 121 passed, 25 warnings, 0 failed**.
4. **Fix layer 2 — self-healing:** `converge_consumers()` in `modules/nixos/services/pool-recovery.nix` now runs in BOTH paths (healthy + recovered) and starts enabled-but-inactive consumers; only explicit `disabled`/`masked` states are respected; racing the boot transaction is safe (systemd merges duplicate start jobs). Also removed the healthy path's immediate `pool-recovery-metrics` start (it clustered with boot coldplug + timer starts into start-limit-hit — caught by the VM test).
5. **Fix layer 3 — deploy.sh:** failed-gated `--no-block` restart of `discordsync-db-heal` (RemainAfterExit oneshot pulled INDIRECTLY — `is-enabled` rc=1 — so the provisioner loop always skipped it; its 10-min budget died in this boot's IO storm and nothing reran it).
6. **Regression tests:** `tests/test-pool-recovery.nix` gained the boot-dropout convergence fixture (enabled-but-inactive consumer gets started by the healthy-path run; listed-but-nonexistent unit degrades non-fatally). **VM test passes (rc=0).**
7. **§6 failed-unit triage (WARN tier):** `btrfs-compsize` = 2-min timeout in the boot IO storm, self-reruns on its 6h timer; `discordsync-db-heal` = 10-min timeout same storm, now deploy-converged; `inboxclean-sync` = the KNOWN OAuth `invalid_grant` (main account, dead since 2026-09-04, re-consent pending); `service-health-check` = by-design reporter of the others.
8. **Docs/memory:** AGENTS.md updated — pool-recovery bullet carries the full incident + diagnosis traps (busctl GC'd-unit-object re-instantiation lies via zeroed `InactiveExitTimestampMonotonic`; VM `/etc` read-only ⇒ disable/mask fixtures impossible); pre-deploy §10 bullet documents the per-service endpoint-down branch pattern.
9. **Verification sweep:** `nix flake check --no-build` all checks passed; shellcheck clean (only expected SC2148 on the sourced-only lib); `nix fmt --no-update-lock-file -- --ci` 0 changed; generated recovery script syntax-checked + eyeballed (converge loop renders correctly with the real unit list).

## b) PARTIALLY DONE

1. **The actual deploy** — gate unblocked and verified, but `nix run .#deploy` has NOT been run (user action; session cannot run it — systemctl/sudo/polkit all blocked in this harness). Until it lands, the three dead services stay down. Effort to finish: S (one command + ~10 min switch).
2. **Service restoration** — recovery will start bank-sync/immich-server/paperless-web automatically in the deploy's post-switch pool-usb-recovery run, but that is UNVERIFIED until it happens. What works: VM test proves the convergence code path. What remains: live confirmation of all three active + `bank_sync_*` present in :8097/metrics + Gatus green. Blocker: deploy not run. Effort: S.
3. **Root cause of the mount-job cancellation** — observed precisely (13:36:13, same-second SIGTERM during coldplug churn, job-superseded signature) but NOT root-caused. The recovery now makes the fallout self-healing, so the class is contained, not explained. Effort to finish: M (journal debugging at the 13:36:13 window; possibly debug-level systemd logging on next boot).
4. **Runtime-mask anomaly** — `systemctl mask --runtime --force` in the VM provably did NOT prevent a start (PID1 started the masked unit 0.4s later); documented as "provably ignored" but the WHY is unexplained (systemd 261 semantics vs my expectation). Effort: M. Low priority — it only affects future VM fixture design.
5. **Section (f) harvest** — the next-task list below is written but NOT yet harvested into TODO_LIST.md/ROADMAP.md (user instructed: report then WAIT). Effort: S via docs-health HARVEST.

## c) NOT STARTED

1. **Post-deploy verification round** — bank-sync syncs + `bank_sync_*` reset, immich + paperless UI checks green, `discordsync-db-heal` restarted by the new deploy.sh block, boot-dropout fixture metrics (`pool_usb_recovery_*`) unchanged. Waiting on the deploy.
2. **Wise SCA approval** — noticed in the 13:20 bank-sync journal: statements paused pending SCA approval on ALL balances (degraded transfers-only fallback active). Human step in the Wise app + OTT into `/var/lib/bank-sync-sca/token.env` per `docs/services/bank-sync-sca.md`. Blocked on user's phone, not on code.
3. **InboxClean main-account re-consent** — still failing since 2026-09-04 (`Run 'inboxclean auth' to re-consent` in every sync tick). Human step, 10 days pending.
4. **Enabled-but-inactive liveness metric** — a `*_pool_consumer_inactive` textfile gauge + Gatus check as a detection net independent of the event-driven recovery. Designed in my head, zero code. Priority: High (this is the tripwire if recovery ever misses again).
5. **Boot-transaction dropout VM simulation** — a test variant that cancels the mount job mid-boot (like the real incident) and asserts convergence; current fixture only proves the healthy-path convergence. Not started.
6. **Boot -1's missing shutdown trail** — journal ends mid-startup 13:32:17 with no Stopping sequence (crash or fsync-loss reboot); `last -x`/wtmp check not yet run. Also unexplained: multi-user.target took **15 minutes** to reach (13:36:22 → 13:51:32).

## d) TOTALLY FUCKED UP

1. **Three production services down ~3h and counting (severity: HIGH, financial-sync outage):** bank-sync (:8097 dead, Wise sync halted, Discord alerting on fire), immich-server, paperless-web. Root cause understood, fix written+tested, **but undeployed**. Workaround the user can run RIGHT NOW if unwilling to wait for the deploy: `sudo systemctl start bank-sync immich-server paperless-web` (pool is healthy, 2/2 members, real-IO verified).
2. **This boot was sick beyond the mount:** multi-user.target reached only at 13:51:32 (15 min after Basic System) — the whole boot crawled under IO pressure; `btrfs-compsize` AND `discordsync-db-heal` both timed out inside it. The 11 GB discordsync integrity check has NOT run this boot (deploy.sh fix lands with the next switch).
3. **`inboxclean-sync` red for 10 days** — known `invalid_grant` (Testing-mode token death class, 2026-09-04 incident); nothing code-side can fix it; re-consent is a standing human TODO that keeps failing every 30-min tick + firing OnFailure.
4. **Wise statements degraded** — SCA gate active on every balance (journal 13:20: deposits/card activity/fees missing until the challenge is cleared). Data-fidelity gap, not an outage.
5. **Two real bugs noticed in `systemd-analyze verify` output this session, unfixed:** (a) `tq-serve.service` + `tq-agent-pool.service` carry `startLimitBurst`/`startLimitIntervalSec` in `[Service]` — **silently ignored** (the documented infinite-restart class); (b) `projects-management-automation.service` has broken `Environment=` assignments ("Invalid environment assignment, ignoring: Artmann" ×2 — unquoted spaces splitting values), meaning some PMA env vars are partially ignored RIGHT NOW.
6. **`/mnt/pool` root-fs shadow directory** — boot logs "Directory /mnt/pool to mount over is not empty" on every boot (also seen 2026-09-07); stale content under the mountpoint is the 226-class hygiene debt, still there.

## e) WHAT WE SHOULD IMPROVE

1. **Fixture design must start from VM constraints** — I burned ~4 VM iterations (disable → read-only /etc; mask → symlink replace refusal; mask --runtime → ignored by PID1) before landing a fixture the environment allows. The read-only-/etc constraint is now in AGENTS.md; next time, check the target environment's writability model BEFORE writing the first fixture.
2. **I violated the box's own anti-storm doctrine** — ran `nix flake check --no-build` in parallel with a VM test and got a flaky device-timeout failure that cost a full 5-min rerun to exonerate. Serial heavy jobs, always (this is literally the workload-admission lesson).
3. **Stopgap-first communication** — production was down while the clean fix required a user-run deploy; my final message mentioned the manual `systemctl start` workaround only implicitly. When service is down and the fix is deploy-gated, the 10-second manual recovery command should be line one.
4. **The §10 endpoint-down branches are accreting hand-registered elifs** (monitor365 → discordsync → cv → bank-sync). Table-drive them: one endpoint→metrics map consumed by both the probe loop and the classifier, so the next service needs a data entry, not code in two files.
5. **Same philosophy, stronger: auto-derive endpoint-down WARNs** from the live probe results (if `localhost:<port>/metrics` is referenced by the rendered gatus config AND the probe fails ⇒ auto-loan that endpoint's patted metrics), eliminating per-service registration entirely — the same move that replaced the manual KNOWN_NEW_METRICS list.
6. **Busctl trap now in memory, worth tooling** — reading unit properties of an inactive unit re-instantiates a GC'd object with zeroed timestamps; any future "did it ever start?" investigation must go to the journal first. Consider a tiny `scripts/unit-started-this-boot.sh` helper that does the journal-based check correctly so the trap can't recur.
7. **Daemon-commit attribution** — my session's script/test changes were swept into `chore: auto-commit N changed file(s) (heuristic)` commits, so history doesn't tell the story of this incident. Where explicit commits are authorized (they weren't this session), commit per task — the known PMA lesson; noting it because the same sweep also carried a foreign session's `io-psi-forensics.sh` edits.

## f) NEXT TASKS (ranked, up to 50 — HARVEST fuel for TODO_LIST/ROADMAP)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Run `nix run .#deploy` (gate verified green) | Critical | S | Deploy |
| 2 | Or, as immediate stopgap before the deploy: `sudo systemctl start bank-sync immich-server paperless-web` | Critical | S | Ops |
| 3 | Post-deploy: verify bank-sync :8097 answers + `bank_sync_*` metrics present + Gatus Bank-Sync green | Critical | S | Verify |
| 4 | Post-deploy: verify immich-server + paperless-web active and their UI health checks green | Critical | S | Verify |
| 5 | Post-deploy: confirm the new deploy.sh block restarted `discordsync-db-heal` (was failed since boot) | High | S | Verify |
| 6 | Wise SCA approval in the app + OTT into `/var/lib/bank-sync-sca/token.env` per runbook (statements paused on ALL balances) | High | M | Ops-user |
| 7 | InboxClean main-account re-consent (`inboxclean auth`; pending since 2026-09-04, failing every 30-min tick) | High | M | Ops-user |
| 8 | Add `enabled-but-inactive pool consumer` textfile metric + Gatus check (detection net beyond event-driven recovery) | High | M | Feature |
| 9 | Fix `tq-serve`/`tq-agent-pool` startLimit placement (in `[Service]` = silently ignored → infinite-restart risk; move to unitConfig/top-level) | High | S | Bug |
| 10 | Fix `projects-management-automation` Environment= splitting ("Artmann" bare-token warnings — quoted values with spaces) and audit what PMA env vars are currently ignored | High | S | Bug |
| 11 | Root-cause the 13:36:13 `mnt-pool.mount` same-second SIGTERM (job-superseded by whom?) | High | M | Bug |
| 12 | Investigate the 15-minute multi-user.target reach (13:36→13:51) — which unit held the transaction | High | M | Bug |
| 13 | Investigate boot -1's missing shutdown trail (journal ends mid-startup 13:32:17; `last -x`/wtmp check) | Medium | S | Bug |
| 14 | Investigate why `systemctl mask --runtime` was ignored by PID1 in the VM (systemd 261 semantics; affects future fixture design) | Medium | M | Bug |
| 15 | Table-drive the §10 endpoint→metrics WARN map (replace the 4 hand-registered elif branches) | Medium | M | Quality |
| 16 | Auto-derive endpoint-down WARN branches from gatus-config probe results (retire per-service registration entirely) | Medium | L | Quality |
| 17 | VM test: simulate the real dropout (cancel mount job before consumer starts, assert recovery converges) | Medium | M | Quality |
| 18 | Evaluate systemd `Upholds=` as the declarative auto-restart for mount-dependent services (structural alternative to event-driven convergence) | Medium | M | Feature |
| 19 | Verify `btrfs-compsize` green at its next 6h tick (timed out in the boot storm) | Low | S | Verify |
| 20 | Confirm `system_booted_is_newest_profile` appears in the textfile post-switch (auto-loaned new metric) | Low | S | Verify |
| 21 | Clean the `/mnt/pool` root-fs shadow directory (every boot warns "to mount over is not empty"; 226-class hygiene) | Low | S | Cleanup |
| 22 | Verify bank-sync canary (`bank-sync-canary.timer`, landed 09-12) produced sane `canary-last.json` this boot | Low | S | Verify |
| 23 | Decide whether bank-sync-down deserves a sev1 notify tier (currently Discord-only via Gatus; outage ran 3h with only channel alerts) | Medium | S | Decision |
| 24 | Duplicate the "VM /etc is read-only — disable/mask fixtures impossible" gotcha into the general NixOS-VM-test gotcha list (currently buried in the pool-recovery bullet) | Low | S | Docs |
| 25 | Add a boot-dropout recovery note to `docs/services/` runbooks (bank-sync/paperless) so the next on-call knows recovery is automatic post-deploy | Low | S | Docs |
| 26 | Consider `scripts/unit-started-this-boot.sh` helper (journal-based, avoids the busctl GC'd-object trap) | Low | S | Quality |
| 27 | Audit remaining services for the indirect-unit restart gap: list RemainAfterExit oneshots pulled only via `wants` (is-enabled rc=1) that deploys never re-run | Medium | M | Audit |
| 28 | Review `pocket-id.service` Type=simple + ExecStartPost + credentials race warning from systemd-analyze | Low | M | Quality |
| 29 | Modernize `cups.socket` /var/run legacy path (systemd-analyze warning) | Low | S | Cleanup |
| 30 | Sweep ALL unit files with `systemd-analyze verify` and file the remaining warnings as tasks (this session only sampled) | Medium | S | Audit |
| 31 | After the owed reboot: verify the boot-dropout class is gone at boot (recovery converges during coldplug) and boot time is sane again | Medium | M | Verify |
| 32 | Confirm immich-machine-learning + redis-immich came up with the converge (server alone is not the full stack) | Medium | S | Verify |
| 33 | Make deploy.sh's pool-usb-recovery post-switch run print its convergence lines into the deploy log (visibility) | Low | S | Quality |
| 34 | Verify no OTHER enabled services besides the three are sitting inactive since 13:35 (full `is-enabled && !is-active` sweep across system + user managers) | High | S | Audit |
| 35 | Coordinate with the owning session on `scripts/io-psi-forensics.sh` (foreign +5-line edit rode the daemon commits; completeness unverified by me) | Low | S | Coordination |
| 36 | Harvest this report's items into TODO_LIST.md/ROADMAP.md (docs-health HARVEST) | Medium | S | Docs |
| 37 | Add the pool-recovery healthy-path metrics-start removal to the CHANGELOG (behavior change: 5-min timer owns freshness now) | Low | S | Docs |
| 38 | Consider a pre-deploy §6 auto-classifier for tolerated known-red units (inboxclean-sync noise) | Low | M | Quality |
| 39 | Re-verify Gatus "Pool Mounted"/"Pool RAID1 Membership" stayed truthful through the incident (textfile showed mounted=1 throughout — confirm no alert gaps) | Low | S | Verify |
| 40 | Long-term: document the "job-failure-with-dependency ≠ failed service" doctrine (restart=never engages, recovery layers must cover inactive) next to the Docker compose `Requires=` lesson in AGENTS.md | Low | S | Docs |

## g) QUESTIONS (only you can answer)

1. **Was the ~13:32 reboot intentional** (e.g. you rebooting to complete the flm v1.0.3 revert / the owed Samsung reboot), or did the machine crash/hang on you? Boot -1's journal ends mid-startup with NO shutdown sequence, and the next boot was sick (15-min multi-user, cancelled mount job). I can read wtmp to distinguish clean-vs-crash, but only you know the intent — and intent decides whether we hunt a sick-boot signature or file it as a one-off storm.
2. **Should a production service outage like bank-sync-down (finance sync halted) page you (sev1 overlay/notify tier), or stay Discord-only?** The alerting-tier doctrine is yours (movie-night rule); today it fired Discord at 13:42 and nothing else for 3 hours.
3. **For the structural fix, do you want `Upholds=` (systemd-native "keep this running while the mount is up") on the mount-dependent services, or is event-driven pool-usb-recovery convergence the accepted long-term mechanism?** I can prototype Upholds on a scratch eval, but changing dependency semantics across always-on services is a doctrine call.

---

*Point-in-time snapshot. Section (f) is HARVEST input for `TODO_LIST.md`/`ROADMAP.md` — do not let it die in this file. (Format note: skill default is styled HTML; user explicitly requested `.md`, honored per the skill's override rule.)*
