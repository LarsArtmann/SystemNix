# Google Sync Follow-Up: Sops Scaffold, configCheck Verification, Self-Review

**Date:** 2026-08-18 02:48
**Session scope:** Continuation of the 01:34 google-sync incident-fix session. This report covers ONLY this session's run: live-state re-verification, user-question resolution, sops scaffold update, configCheck re-verification, TODO_LIST corrections — plus the brutal self-review the user demanded. No new research performed.

**Session arc in one line:** Resumed believing a LIVE crash-loop needed urgent user action → journal proved the timer was already stopped at 01:21:28 → downgraded urgency everywhere → closed the prior session's "biggest miss" (sops scaffold) → proved the previously-unproven configCheck branch against the real store binary → caught myself inheriting a false urgency claim in the 01:34 report.

---

## a) FULLY DONE

1. **Live-state verified, urgency downgraded with receipts.** `google-sync.timer` was stopped at **01:21:28** ("Deactivated successfully / Stopped Google Drive mirror sync interval" — journal), last `status=226/NAMESPACE` failure **01:20:35**, zero failures since (checked 01:43). The alert noise is over; nothing is crash-looping right now. The actor who stopped the timer is not attributable from the journal (presumed user SSH — unconfirmed).
2. **sops scaffold rewritten to 3-remote layout** (`platforms/nixos/secrets/google-sync.yaml`, key `google_sync_rclone_config` unchanged): `[gdrive]` (private ~1.9 TB), `[gdrive-shared]` + `shared_with_me = true`, `[gwork]` with a commented `team_drive = <id>` line (user answered "unsure" on work-account layout). Encrypted with the public age recipient only (no sudo needed), `git add -f`'d (secrets/ is gitignored), staged as of 02:48. This closes the prior session's self-declared "biggest miss."
3. **configCheck proven against the REAL store binary** — not an eval, the actual `…-google-sync-config-check/bin/google-sync-config-check` script (drv `4dzhc0gl…`, out `r3vscdp7…`). Three cases:
   - Placeholder config (the exact scaffold content) → **exit 1** + actionable go-live message. This proves the `REPLACE_WITH` branch, which the post-rework test in the prior session never reached (it tripped the remote-guard branch first).
   - Filled 3-remote INI (comments, `shared_with_me`, JSON token lines) → **exit 0**. Proves the scaffold's exact structure passes once tokens are pasted.
   - `[gwork]` removed → **exit 1**, message names the missing remote.
4. **TODO_LIST corrected (2 edits):** "URGENT … LIVE crash-loop" item rewritten to "Deploy the google-sync disable + 226 fix" with the loop-stopped receipt (01:21:28 / last failure 01:20:35) and the deploy-deferred decision; go-live step (3) rewritten from "write the FULL rclone.conf" to "fill the EXISTING sops scaffold," noting the unsure team-drive answer.
5. **Questions resolved via user (2 of 3):** deploy timing = **wait for concurrent session** (it landed mid-session in `0d8a58ca` + `00c8007a`; next deploy ships everything); work-account layout = **unsure** (scaffold handles both via the commented line). Question tool used, answers recorded.
6. **Housekeeping:** 4 tmp test fixtures trashed; todos maintained; concurrent session's files (homepage/migration/images) deliberately untouched throughout.

## b) PARTIALLY DONE

1. **Incident closure — verified, NOT deployed.** Fix (mount-gated `google-sync-dirs` oneshot + `configCheck` + enable=false) is committed (`0d8a58ca` swept the prior session's module work) but the live system still runs generation `ycvhzq52` (pre-fix; `google-sync-dirs` has zero journal entries). Post-deploy verification checklist is prepared but pending (see f.2). Deploy is the USER's command (`nix run .#deploy`) — my session cannot run sudo/systemctl.
2. **Multi-mirror go-live — scaffold done, tokens absent.** Blocked on: OAuth client ("In production"), `rclone authorize` ×2, sops fill (needs `SOPS_AGE_KEY` from sudo), enable+deploy, 1.9 TB seed.
3. **Working tree pending sweep:** my TODO_LIST + sops edits await the auto-commit daemon (verified staged/modified at 02:48).

## c) NOT STARTED

1. Post-deploy verification (`google-sync-dirs` ran + mkdir'd 6 dirs; no new 226s; generation newer than `ycvhzq52`; OnFailure silent).
2. All go-live execution steps (OAuth, authorize, sops fill, enable, seed watch).
3. Hardening backlog from the 01:34 report §f items 14-25 (pre-deploy-check google-sync section, unit-drift check, VM test, seed IO-tier/daytime decision, restore-path doc, `mkDnsGate` opt-out, statix ignore).
4. Annotation of the 01:34 status report with the timer-stopped fact (see d.2 — should have been done this session).
5. Photos / Takeout / immich-go pipeline — user-deferred until mirror stability.

## d) TOTALLY FUCKED UP!

1. **(Root incident, prior session, still costing us):** the force-enable file-edit hack escaped into the 00:33 production deploy → module live + 226 crash-loop for 47 minutes. Fix undeployed. The incident CLASS is unbanned in writing — AGENTS.md still doesn't forbid the hack (f.4).
2. **I inherited and repeated a false urgency claim:** the 01:34 report (which I resumed from) states the crash-loop was "still live at session end (01:34, 11+ failures, last at 01:20)." The second half is true but the framing is wrong — the timer had already been stopped at **01:21:28**, thirteen minutes before that report was written. Neither the prior session nor my resumed summary caught it; only this session's journal-first check did. The report still carries stale urgency, unannotated. Same class of sin I accuse others of: a claim without a same-moment receipt.
3. **Test-fixture surgery botch:** derived the "missing gwork" fixture via nested `sed`, leaving orphaned `type = drive`/`scope = drive` lines outside any section — a garbage test input that would have invalidated the case. Caught by eyeball, rewrote by hand. Wasted a round trip; hand-writing 8 lines was always cheaper.
4. **Fragile verification method:** `nix build --expr` on the ExecStartPre string failed with a Nix context error; my workaround only worked because the error message leaked the store path, letting me rebuild the `.drv^out` directly. Luck-assisted, not a method.
5. **Concurrent-session race, strike three:** TODO_LIST `multiedit` failed because the file's mtime moved (01:38:42, other session). Prior session already raced concurrent writes twice. Three strikes, still no enforced habit change (e.2).

## e) WHAT WE SHOULD IMPROVE!

1. **Receipts or it didn't happen — for de-escalation too.** Every urgency claim (up OR down) must carry a timestamped journal/command receipt from the same moment. This session modeled it; the 01:34 report violated it.
2. **Race discipline must be mechanical, not aspirational:** `stat` mtime + re-read immediately before EVERY edit in this repo while parallel sessions run. Three failures of the "I'll be careful" approach prove vigilance doesn't scale.
3. **Ban the force-enable file-edit hack in writing** (AGENTS.md): use the throwaway-expression pattern this session used (`nix build --impure --expr` with `extendModules { modules = [{ services.X.enable = true; }]; }`) — it can never reach a deploy because it never touches the working tree.
4. **Ship the scaffold with the module.** A disabled module whose sops secret is a stale placeholder is a trap for the next session. Rule: new-module + secret-file scaffold land in the SAME change.
5. **Hand-write small fixtures; sed surgery is negative-value below ~20 lines.**
6. **Deploy-gate gap still open:** nothing detects "deployed unit ≠ configured unit" (mystery `ycvhzq52` generation, 01:34 report f.25). Until pre-deploy-check.sh grows a drift check, "deployed but stale" will keep surprising us.
7. **CHANGELOG has no scaffold line** for the 3-remote placeholder (minor — belongs under the existing Added entry, f.18).

## f) Up to 50 things to get done next

**P0 — incident closure:**

1. ~~User runs `nix run .#deploy` (ships fix + the concurrent session's landed work; tree carries my sops scaffold + TODO edits).~~ done (deploys ran through 2026-08-18 (gen 690); fix live since system-686)
2. ~~Post-deploy verify: `journalctl -u google-sync-dirs` (ran, mkdir'd 6 dirs); `journalctl -u google-sync.service -n 5` (no new 226s); `readlink /run/current-system` ≠ `ycvhzq52`; OnFailure silent.~~ done (no new 226s since 01:20:35; google-sync-dirs oneshot deployed)
3. ~~Annotate the 01:34 report (appendix): timer stopped 01:21:28, urgency was stale at write time.~~ done (01-34 carries the addendum; correction also in CHANGELOG (00:33 was manual activation))
4. ~~AGENTS.md: codify the throwaway-expression force-enable pattern; ban the file-edit hack (incident class from d.1).~~ done (AGENTS.md Critical Rules ban manual activation + document the throwaway-expression pattern)

**P0 — go-live (user steps + my support):**
5. Google Cloud OAuth client (Drive API enabled, publishing status "In production").
6. `rclone authorize "drive" "<id> <secret>"` ×2 — incognito window for the work account.
7. Check work account: My Drive vs shared/team drive → uncomment `team_drive` in `[gwork]` if shared.
8. Fill sops scaffold tokens (`SOPS_AGE_KEY` from sudo, per AGENTS.md Sops section) — re-run configCheck locally against the filled file before deploying.
9. Flip `services.google-sync.enable = true` + deploy — **daytime only** (avoid btrbk 23:00-23:45 + backup jobs 01:00-04:00 on the shared USB DAS link; the 1.9 TB seed runs hours-to-days).
10. Watch the seed: `journalctl -u google-sync -f`; verify `/mnt/pool/backups/google-drive{,-shared,-work}` populate; `backup_healthy{google-sync}=1`.
11. Deletion-grace test per mirror (delete a file remotely, confirm it lands in `google-drive-deleted/<remote>/`, expires after 30d).
12. Observe shared-with-me root-name collisions (forest semantics — untested until live).

**Hardening backlog (01:34 report §f, unchanged):**
13. `scripts/pre-deploy-check.sh`: google-sync section (mount present, dirs exist, secret present).
14. Deployed-vs-configured unit drift check in pre-deploy-check.sh.
15. VM test: timer/sentinel/grace lifecycle.
16. Seed IO-tier decision (`ioTier.background`?) + daytime-start gate.
17. Restore-path doc (rclone copy back from pool → Drive).
18. `mkDnsGate` opt-out evaluation for google-sync (rclone needs DNS at start).
19. statix ignore for the `serviceOneshotDefaults ()` parens false positive.
20. ~~CHANGELOG: scaffold line under the google-sync Added entry.~~ done (google-sync entries present in CHANGELOG (module Added, 226 Fixed, multi-mirror rework))
21. ~~Confirm auto-daemon swept TODO_LIST + sops edits (verify in next `git log`).~~ done (TODO_LIST + sops edits swept by the auto-daemon (visible in git log))

**Standing TODO_LIST P0s noticed this session (not researched):**
22. Free root below 95% + deploy the stranded monitor365-gating change (`backup_healthy{monitor365}=0` alerts continue until then).
23. dnsblockd `ManagedOOMPreference=omit`.
24. Turso plan decision (DiscordSync cloud sync down since 2026-08-16).
25. Scrub-result Gatus coverage for `/data` + `/mnt/pool`.
26. Re-provision `/btrfs-emergency-reserve` + freshness semantics.
27. Foreground BTRFS scrub on `/`.
28. Off-site backup decision (3rd copy; pool is same-chassis).
29. Photos/Takeout/immich-go — deliberately deferred until mirror stability (user decision 2026-08-18).

## g) Questions I cannot figure out myself

1. **Work account layout — My Drive or Workspace shared/team drive?** Check the Drive sidebar for a "Shared drives" section while logged into the work account. Decides whether `[gwork]` keeps the commented `team_drive` line commented or not. You answered "unsure" — this is the concrete check that resolves it.
2. **Deploy authorization now?** The concurrent session's work has landed (`0d8a58ca`, `00c8007a`); your earlier answer was "wait for it to land." It has. Running `nix run .#deploy` ships the google-sync fix, the scaffold, and their homepage/image-updates work together — yes/no?
3. **Seed window policy:** I recommend the first enable+deploy happens during the DAY so the 1.9 TB seed avoids the nightly btrbk/backup window on the single shared USB DAS link. Do you want a mechanical start-time gate in the module (e.g., timer only fires 08:00-22:00 until first success), or is manual coordination enough?

---

_Arte in Aeternum — receipts above claims, annotations over rewrites._
