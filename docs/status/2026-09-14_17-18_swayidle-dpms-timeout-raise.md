# Status Report — 2026-09-14 17:18 CEST

**Session scope:** User complaint "I hate the current 5 minutes no movement and my Display goes black" → swayidle DPMS timeout raise. Single-topic session; this report covers ONLY that thread plus what was noticed along the way.

> Format note: the status-report skill's canonical output is a styled HTML dashboard; the user explicitly requested `.md`, so this file is flat Markdown by instruction (one-off override, not propagated).

---

## a) FULLY DONE

| Work | Detail |
| --- | --- |
| DPMS timeout raised 20 min → 4 h | `platforms/nixos/desktop/niri-wrapped.nix:725` — swayidle ExecStart `timeout 14400` (was `timeout 1200`). Two-step edit (first to 3600 after initial request, then 14400 on user refinement) |
| `nix flake check --no-build` passed after each edit | Ran 3× total; all checks passed (pre-existing warning only: `bank-sync-stub` lacks `meta.mainProgram`) |
| FEATURES.md updated | Line 260: "4h idle → DPMS off (`niri msg action power-off-monitors`, raised from 20min 2026-09-14)" |
| Mechanism explanation delivered | Answered "why BLACK": DPMS sleep via `niri msg action power-off-monitors` cuts the display signal; monitors enter power-saving (backlight off), any input wakes instantly |

## b) PARTIALLY DONE

| Work | Gap |
| --- | --- |
| The fix itself | Committed to the tree but **NOT deployed** — the running system still carries the old (deployed) timeout. Requires `nix run .#deploy`. Until then the user's complaint is not actually resolved on the desktop |
| AGENTS.md gotcha bullet ("Idle DPMS via swayidle (2026-08-22): 1200s") | NOT updated — still documents 20 min. Only FEATURES.md was updated. Doc drift created by this session |

## c) NOT STARTED

- **The "5 minutes" root-cause hunt.** The committed config said 1200s (20 min), the user observed ~5 min. I changed the committed value without confirming the deployed unit's ACTUAL runtime value (`systemctl` is blocked in this sandbox). Two unresolved hypotheses: (1) the deployed generation predates the 2026-08-22 20-min commit and still runs an older timeout (or another timer entirely — DMS lock screen at 10 min? an older 900s value from the archived 15-min era?), (2) the user's perception. The real check after deploy: `systemctl --user cat swayidle.service | grep ExecStart`.
- User decision on the idle ACTION itself — DPMS-off vs lock-screen-only vs nothing is still DPMS-off; only the timeout moved.
- CHANGELOG.md entry for the timeout change.

## d) TOTALLY FUCKED UP

Nothing destroyed. But two process failures worth naming:

1. **I changed a value I had never verified as the actual cause.** The user said 5 minutes; the config said 20 minutes; I edited the config anyway instead of first probing the deployed system (or at least flagging the mismatch as the primary mystery). The real bug may still be live after deploy.
2. **Sandbox blind spot discovered mid-session:** `systemctl` is blocked by Crush security policy here, so I could not inspect the live unit. I stated what I would check rather than checking — correct behavior, but it means EVERYTHING about the running desktop state in this session is inference, not observation.

## e) WHAT WE SHOULD IMPROVE

- **Verify-before-edit for user-reported symptoms vs config values**: when the reported number and the config number disagree, the discrepancy IS the investigation, not a footnote.
- **Make the idle timeouts an option**, not a magic string: `services.swayidle.dpmsTimeout` / `suspendTimeout` in niri-wrapped.nix would have made this a one-line host-config change and prevented the two-step 3600→14400 churn.
- **Doc-sync discipline**: FEATURES.md and AGENTS.md both describe swayidle; both must change together (only one did).
- **POST-deploy verification step for this change**: after `nix run .#deploy`, confirm the live user unit carries `timeout 14400` — the 2026-09-06 generation-mismatch class (exit-4 skips profile bump) makes "deploy said ok" insufficient.
- The pre-existing eval warning (`bank-sync-stub` missing `meta.mainProgram`) was noticed during checks — trivial fix on sight candidate, untouched this session (out of scope, tracked in section f).

## f) Up to 50 things to get done next

*(Brainstorm, not commitment; most items are TODO_LIST/ROADMAP fuel, many already tracked in AGENTS.md/TODO_LIST. Items 1–5 are this session's direct follow-ups.)*

**Session follow-ups (this thread):**
1. Deploy (`nix run .#deploy`) — the fix is inert until then.
2. Post-deploy: verify live user unit ExecStart carries `timeout 14400` (catch the exit-4 / profile-not-bumped class).
3. Root-cause the "5 minutes" observation — check the DEPLOYED generation's swayidle timeout and DMS lock timer; if the deployed value was 900/300, find which generation regressed and when.
4. Update the AGENTS.md gotcha bullet (1200s → 14400s + date).
5. CHANGELOG.md entry for the DPMS timeout change.

**Refactor / quality:**
6. Convert hardcoded swayidle timeouts to module options (`dpmsTimeout`, `suspendTimeout`).
7. Consider replacing DPMS-off action with lock-screen-first (no signal cut) — user decision.
8. Fix `bank-sync-stub` missing `meta.mainProgram` eval warning (use `getExe'` or set the attr).
9. Add a flake check that grep-asserts the deployed swayidle ExecStart matches the documented FEATURES.md value (anti-doc-drift tripwire).

**Carried from AGENTS.md / TODO_LIST context noticed this session (not re-verified, point-in-time):**
10. OWED reboot — clears the flm corpse pinning :52626 (EADDRINUSE class) + D-state corpse pile + IO PSI inflation. Run `nix run .#pre-reboot-check` first.
11. llama.cpp mid-load CPU-spin regression — RAG dark, both llama units stopped; pin `llama-cpp-rocwmma` back to 20260905-era build or bisect gfx1150 upstream.
12. flm v1.0.3 staged go-live (fails post-fix → now eligible); needs live-serve validation + weight re-pull discipline.
13. Resend domain verification (`larsartmann.cloud` SPF/DKIM) — unblocks Mail Relay + Pocket ID SMTP delivery; then runbook test send.
14. /data EIO inode repair (blocks every btrbk-data send; `/mnt/pool/backups/data` has zero complete receives).
15. `checks.x86_64-linux.cv` RED on master — VM fixture lacks `CV_OIDC_CLIENT_SECRET`; blocks pre-commit's full flake check (docs commits ride `--no-verify`).
16. Delete dead QLC `@nix` subvol at `/mnt/btrfs-root/@nix`.
17. Hetzner StorageBox + BorgBackup offsite leg (decided, NOT implemented).
18. clickhouse-backup (telemetry has NO backup coverage).
19. Zombie ClickHouse read-only log tables (`trace_log_14..18` etc., ~10 GiB) — human DROP TABLE decision.
20. Turso decision: upgrade plan (DiscordSync auto-resumes) or permanent local-only (remove TURSO_* env + Gatus check).
21. Google Sync go-live checklist (OAuth, rclone authorize, sops fill, flip enable).
22. Hermes: fine-grained PAT go-live (`hermes-github-token.yaml` placeholder → real token).
23. Hermes lock bump decision (79445a496 identified, ~20 commits of UI churn, nothing server-relevant).
24. SCA renewal runbook awareness for bank-sync (~90-day Wise cadence).
25. InboxClean: OAuth consent screen "In production" flip + re-consent both accounts (main's 7-day bomb).
26. InboxClean retro-decrypt backfill deploy (upstream 2026-09-12, needs upstream push + flake bump).
27. dnsblockd cached-health release tag (fix deployed via lock rev but no tag — tag-pinned consumers miss it).
28. go-taskqueue: flip `git+file` interim input to `github:` after upstream push (CI dark on git+file).
29. CV: upstream CI dead (Actions minutes) — probe CV revs locally before lock moves (standing discipline).
30. Memory-emergency-guard: corpse-aware restore skip (P1, re-arm loop between deploys).
31. Overview/PMA/papdashboard/hermes OTel tracing instrumentation upstream (signoz-coverage gaps).
32. btrbk csum-error growth watch on /data post-repair (bounded vs progressing discriminator).
33. DAS: verify `by-label/pool` mount path holds on next full DAS return.
34. Shutdown-overlay + sev1: revisit `page` tier — still reserved, zero emitters; decide if it ever earns one.
35. sops: remove inert `mimo_api_key` placeholder line (interactive sudo edit, harmless but noisy).
36. DiscordSync: two legacy poison DLQ events — keep (documented decision), just re-confirm after next replay loop.
37. Nix daemon: adopt nix#3768 overlay patch shape IF the substituter-connect-timeout SIGABRT signature ever appears during an attic outage.
38. Fish/btrfs guard: none needed — already shipped; verify once after the owed reboot that rescue snapshots survived.
39. nvme by-id smartd pins: verify both NVMe entries after reboot (kernel enumeration flip nvme0/nvme1).
40. `services.btrfs-rescue` self-test stamp: confirm `btrfs_rescue_append_only 1` post-reboot.
41. TV/DP-2 cross-output focus-follow: verify `focus-new-windows` when DP-2 reconnects (never SSH-testable).
42. Test `niri msg action power-off-monitors` while DMS-locked (archived open question, still unverified).
43. Log DPMS events to journal for debugging (archived item #45 from 2026-08-22 report).
44. SDDM Xsetup `xset -dpms` defense-in-depth (archived item, login-screen watchdog false-positive hardening).
45. Sweep `docs/status/archived/` open-questions lists for other still-unverified items like #42/#43.
46. Consider `compress-force=zstd:1` review on /mnt/buildcache ext4→btrfs conversion script (deferred 2026-08-15).
47. PapDashboard: consider converting dozzle compose unit to detached flavor (daemon-restart resilience).
48. Docker `/data/docker` ~17G pruneable garbage — schedule a granular prune.
49. macOS side: Darwin SSD 90%+ full — cache sweep still pending (platform constraint).
50. Rotation follow-up: old dead keys in `crush.db` session snapshots only die via rotation (context7/minimax-era) — confirm rotation status.

## g) Questions I CANNOT figure out myself

1. **When the screen went black after ~5 minutes — was the machine LOCKED or unlocked, and was it a recent boot?** The committed config says 20 min, so something on the deployed system disagrees with the tree (older generation, DMS lock timer, or a different unit). Knowing lock-state + approximate date the 5-min behavior started tells me whether to hunt the deployed generation or another timer.
2. **Do you want the idle action to remain DPMS-off (signal cut, power saving), or switch to lock-screen-without-signal-cut (screen stays on but locked)?** 4h DPMS is what's in the tree now; the alternative changes the ACTION, not the number.
3. **Was audio playing when it blacked out?** `sway-audio-idle-inhibit` is supposed to prevent exactly this during playback — if it blacked out mid-audio, the inhibit daemon is broken/absent and that's a second bug this session has NOT investigated.

---

**Next actions awaiting instruction:** deploy now, or investigate the deployed-generation mystery first (question 1)? Waiting.
