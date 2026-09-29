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
