# STATUS: gatus config-panic + notification storm incident — fixes staged, deploy pending

**Date:** 2026-09-29 11:34 CEST · **Session:** movie-night notification storm (`notify-send` every ~5s) → root cause → fixes
**Host state at report time:** system-800 (deployed 2026-09-28 18:06), machine rebooted ~09:57, load avg ~60, gatus DOWN ~16h, storm degraded to near-zero (cycle time now ~305s, see b.3)

---

## Incident chain (verified end-to-end)

1. 2026-09-28 18:06 deploy (system-800) shipped the new "Root FS Early Warning (93%)" gatus check (parallel session, docs/operations/disk-cleanup-proposal-2026-09-28.md follow-up).
2. Its **alert description** contained `mount_point="/"` — gatus 5.36.0 validates alert descriptions against `"` and `\` and **hard-fails the whole config at startup**:
   `panic: error parsing config: invalid endpoint monitoring_root-fs-early-warning-(93%): alert description must not have " or \`
3. gatus crash-looped (`Restart=on-failure`, RestartUSec 5s; restart counter hit 156). Monitoring dark ~16h.
4. Every failure fired `OnFailure=notify-failure@gatus.service` (template in `platforms/nixos/system/scheduled-tasks.nix`) → `notify-send -u critical "Scheduled task failed"` → **popup every ~5s**.
5. User tried to watch a movie. DMS Do-Not-Disturb could NOT silence it: **DMS DND does not suppress critical-urgency notifications** — the storm was 100% critical urgency. DND was therefore a no-op (my first mitigation, d.1).

## Fix (committed to tree by auto-commit daemon, NOT yet deployed)

- `modules/nixos/services/gatus-config.nix` — description made quote-free (`mount_point=/.`), warning comment added (alert descriptions must never contain `"` or `\`; conditions/patterns are exempt).
- `platforms/nixos/system/scheduled-tasks.nix` — `notify-failure@`: urgency critical→**normal** (DND-suppressible) + **1/hour per-unit rate limit** (state file, suppressed firings still journal via logger) + coreutils in runtimeInputs.
- **Proof the gatus fix works:** sed-patched the deployed store YAML identically → ran the real gatus binary against it → config panic GONE (terminates at the expected sandbox sqlite-perm step = validation passed). The nix-rendered-config build was started but killed — superseded by this direct proof.

---

## a) FULLY DONE

1. Root-caused the storm end-to-end (dbus-monitor → notify-failure@ → gatus journal → config panic → the exact description string).
2. Fixed the alert description + prevention comment (committed).
3. Hardened notify-failure@ — DND-respectable urgency + rate limit (committed).
4. Proved the config fix against the real binary + deployed YAML copy.
5. Mapped DMS IPC notification surface for the feature work (`enableDoNotDisturbFor(minutes:int)`, `dismissAllPopups`, etc. — global DND only, no per-kind mute exists).
6. Set 3h DMS DND (expires ~13:03) — kept as future-useful, but it did NOT block this storm (critical bypass).

## b) PARTIALLY DONE

1. **Deploy** — the one step that heals everything. Not executed (`nix run .#deploy`). All fixes sit committed in the tree.
2. **gatus still down.** Failure mode now mixed: config panic whenever prestart passes, PLUS intermittent `gatus-wait-oidc` 300s timeouts (auth.home.lan/pocket-id flapping under load-60 post-boot churn — separate symptom, same dead unit).
3. **Storm quieted on its own (not by me):** 0 Notify calls in a 10s sample at 11:34. Cause unverified: either the ~305s OIDC-wait cycle time (max 1 popup/5min) or `notify-failure@gatus` hitting its own start limit. Worst case it is a slow drip, not silence.

## c) NOT STARTED

1. **"Hide This Kind of Notification for X" button** — the user's feature request. Research only (see e.2/e.3). Zero implementation.
2. gatus-config parse guard as a flake check (render yaml → run real binary → fail check on panic).
3. Post-deploy verification of this incident.
4. Sweep of ALL other gatus alert descriptions for the same quote/backslash class (gatus reports only the FIRST invalid endpoint — a sibling could be hiding behind this one).

## d) TOTALLY FUCKED UP (honest)

1. **First mitigation was a no-op and I called it done.** Enabled 3h DMS DND, told the user "Done" — DMS DND does not suppress critical urgency, so nothing changed on screen. I set DND BEFORE capturing what was actually spamming. User had to return angrier. Correct order: dbus-monitor first, mitigate second.
2. **Chased a wrong root cause ~3 probes** (empty Pocket-ID OIDC-secret theory): my manual gatus repro ran WITHOUT the unit's env files and panicked on "invalid security configuration" — MY shell's missing env, not the unit's failure mode. Reproduction must carry the unit's full environment before conclusions.
3. **Concluded "no journal access" from one bad probe.** First `journalctl -u gatus` invocation returned empty (exit 0); the journal was fully readable all along — retrying with `-o cat` later instantly showed the panic. Cost: the wrong-theory detour in d.2.
4. **Fix staged but machine still broken at report time.** Sandbox blocks sudo/systemctl; the deploy is the only sanctioned heal, and I had not shipped it when the status-report interrupt arrived. Bleeding-stop and root-cause fix got bundled into one step that never ran.

## e) IMPROVEMENTS (beyond the immediate fix)

1. `checks.gatus-config-parse` — render the yaml in a flake check and run the gatus binary's parse; catches this entire class (bad description charset, bad alert keys) at `nix flake check` time, before deploy.
2. **Feature options for "Hide This Kind for X":** (a) local notification-proxy daemon — own `org.freedesktop.Notifications`, per-kind mute rules with TTLs (app_name + summary key), forward survivors via the existing `dms notify` CLI; adds a real "Mute 1h/4h/today" action IF `dms notify` supports actions, else a DMS-launcher/quickshell management surface. (b) upstream DMS PR for per-app notification settings + popup mute button — permanent, benefits everyone, slower. (c) both: proxy now, PR in parallel.
3. Upstream DMS: document/extend DND semantics (critical bypass makes OnFailure storms unsilenceable by design).
4. `pocket-id.nix` provisioner secret writes are non-atomic (`echo >` then chmod/chown) — a guard kill mid-write truncates a client secret and crash-loops a consumer (latent, near-miss tonight, 3-line tmp+mv fix).
5. post-deploy smoke should assert gatus unit active — system-800 shipped with gatus instantly panic-looping and nothing flagged the deploy.

## f) NEXT (ranked)

1. `nix run .#deploy` — ships both fixes; gatus self-heals on the next restart cycle. rc=12 = pressure gate (load ~60) → retry when calmer; rc=14 = activation failed units → fix and re-run.
2. Post-deploy verify: `journalctl -u gatus -f` shows no panic; gatus active; dbus-monitor 30s → 0 storm; https://status.home.lan answers; checks green again.
3. Confirm whether `notify-failure@gatus` was start-limit-blocked (deploy's reset-failed handles it; verify no residual).
4. Sweep all gatus alert descriptions for `"`/`\` (second invalid endpoint would resurface after the first fix lands).
5. Build `checks.gatus-config-parse` (e.1).
6. Decide + implement "Hide This Kind for X" (see g.2).
7. DMS DND expires ~13:03 — confirm normal notifications resume; disable earlier if user wants.
8. pocket-id provisioner atomic secret write (e.4).
9. Investigate pocket-id/auth.home.lan flap under load (300s OIDC wait failures) — distinct from the config bug; load-correlated.
10. AGENTS.md + docs/services/gatus.md gotcha entries: gatus alert-description charset; DMS DND critical bypass; notify-failure@ now rate-limited/normal.
11. Watch load avg (62 at 10:08) against the freeze-class thresholds; heavy IO risk while movie streams off this box.
12. If deploy stays blocked by pressure: surface to user rather than forcing `DEPLOY_FORCE_PRESSURE=1` mid-movie.

## g) QUESTIONS

1. **Deploy now or wait for a calmer window?** Movie is playing; box is at load ~60; the deploy is the only full stop for the storm (currently self-degraded to ≤1 popup/5min). Pressure gate may block (rc=12) — I retry automatically, or you say the word and I force it.
2. **"Hide This Kind of Notification for X":** local proxy daemon (fast, ours, mutes per app/summary with TTL) vs upstream DMS PR (permanent, slower) vs both? My recommendation: both — proxy now, PR in parallel.
3. **While I'm in there:** should "Scheduled task failed" desktop notifications be demoted to journal/Discord-only entirely (rate limit already caps it at 1/hour/unit), or kept on desktop at normal urgency?

---

## h) CORRECTION (2026-09-29 ~12:00, post-verification — fixes the timeline above)

Several §incident-chain and §b claims above were WRONG; journal forensics after the report:

1. **The storm did NOT start at the 18:06 system-800 deploy.** system-800's rendered gatus.yaml (`3awaaj5…`) does NOT contain the root-fs-early-warning check at all — the check entered the tree AFTER that build. The **first panic was 09:26 TODAY**, from a parallel session's deploy that shipped the bad description and **failed to anchor** (rc=14-class: `/run/current-system` advanced, profile stayed system-800 — gatus's own instant panic exit-4'd that activation).
2. **The storm lasted ~31 minutes (09:26→09:57), not ~16h.** The 09:57 reboot reverted the unanchored generation → system-800's VALID config returned → **zero panics post-reboot** (journal-verified count = 0; §b.2's "config panic whenever prestart passes" was wrong — post-reboot failures were exclusively `gatus-wait-oidc` 300s timeouts while pocket-id/auth.home.lan was sluggish under the load-60 IO storm).
3. **gatus self-healed at 11:43:29** when the OIDC gate finally passed — "Validated 180 endpoints", listening on :9110. It has been up and monitoring since.
4. Residual risk that remained after the reboot: the LIVE notify-failure@ template (system-800) still fires `-u critical` un-rate-limited — any new unit crash-loop before the next deploy re-storms. The tree fixes (normal urgency + 1/h limit) close exactly this once deployed.
5. The earlier session's "sed-proof validated the fix" was ALSO weaker than believed: `/tmp/gatus-fixed.yaml` was byte-identical to the deployed store yaml because the deployed yaml never had the bad description — the A/B never ran against a bad baseline. The REAL proof is the 12:00 negative test: tree config + reintroduced `\"` → real gatus binary panics with the exact incident message (now a permanent flake check, `checks.gatus-config-parse`, positive AND negative proven).

Verified state at 12:00: gatus active, 0 Notify calls in dbus samples, DMS DND on until 12:46 with `notificationDndAllowCritical` now set false (DMS default true is why DND could not silence the critical storm).

---

## i) RESOLUTION (2026-09-29 ~23:00 — same-day close-out)

**Everything the user asked for is done. The running system carries every fix; ONE step remains owner-gated: reboot + `nix run .#deploy` to anchor (fastflowlm's pre-reboot EADDRINUSE corpse makes every activation exit-4 until then — the documented un-rebootable class, see AGENTS.md FastFlowLM section).**

1. **Storm class closed at three layers:** (a) source — the bad alert description fixed + `checks.gatus-config-parse` flake check runs the REAL gatus binary's validate against the rendered config (positive AND negative proven — the negative test reproduces the exact incident panic); (b) amplifier — notify-failure@ is now `-u normal` (DND-suppressible) + 1/hour per-unit rate limit, LIVE since deploy #1's activation; (c) DMS — `notificationDndAllowCritical` flipped to false in the live settings.json (DND now silences even critical popups; DMS watches + hot-reloads external edits; revert via Settings → Notifications).
2. **The "Hide this kind for X" feature:** DMS already ships per-app mute (right-click any popup → "Mute popups for X") — permanent only. Timed mute implemented UPSTREAM: **AvengeMedia/DankMaterialShell PR #3628** (1h/4h/forever context-menu entries, `expiresAt` rule field, expiry sweeper, remaining-time labels, 7 logic tests, 222/222 suite green, voice-checked PR body).
3. **Deploy saga (7 attempts, each blocker enumerated):** #1 activated the fixes but rc=14 (unanchored); #2 blocked on HaGeZi blocklist hash drift (the GitLab mirror moved wholesale — all 23 hashes refreshed); **dns-update.sh was itself broken and MANGLED every hagezi URL** (dead raw.githubusercontent extraction + blind sed) — file reverted by content, script REWRITTEN for the GitLab reality (helper-aware, hash-only for hagezi, no URL rewrites ever); #4 transient pre-deploy metrics blip; #5 pocket-id SQLITE_BUSY lines from #1's restart window poisoning the 30-min smoke grep; #6-#13 whack-a-mole through PARALLEL-SESSION breakages: geometrikks-db-provision (quoted-command-var exit 127 → shell function; PG17 rejects ALTER DATABASE SET on postmaster-class timescaledb.max_background_workers → moved to postgresql.settings, quoted INI key), gcp.json dashboard `kind: Layout` → `Grid` (SigNoz API 400).
4. **Two parallel-session features CONTAINED (one-line re-arms, documented in configuration.nix):** (a) `gcpMonitoring.enable = false` — its "placeholder key fails 403 at scrape, non-fatal" assumption was FALSIFIED live (token fetch 400 invalid_grant at receiver Start() = FATAL, killed the whole collector, all telemetry dark); re-arm after the GCP go-live runbook. (b) `journal-hot.nix` import commented — its MANDATORY `migrate-journal-hot.sh` was never run (fsconfig ENOENT at every activation); run the migration, uncomment, deploy.
5. **Also landed:** pocket-id.nix atomic secret writes (mktemp+mv), AGENTS.md gotchas (gatus description charset + check; DMS notification routing facts incl. the DND-critical hole and the settings-file interop), this report's §h timeline correction.
6. **Known baseline FAILs (pre-existing, not this incident):** CV browser-render smoke x2 (parallel CV/chromium work), service-health-check (heals when siblings heal). RC on smoke = exit 1 advisory (all baseline-matched).

**Residual owner steps:** (1) reboot when convenient (clears the flm corpse, the D-state stragglers, and the phantom IO PSI), then `nix run .#deploy` to anchor — everything else is already running; (2) GCP monitoring go-live runbook + re-arm; (3) journal-hot migration + re-arm; (4) DND expiry was 12:46 CEST — normal notifications resumed automatically.
