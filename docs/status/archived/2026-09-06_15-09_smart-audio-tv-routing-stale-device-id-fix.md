# Smart-Audio TV Routing: Root Cause Found, Fixed, Deployed — Self-Review

**Date:** 2026-09-06 15:09 · **Host:** evo-x2 · **Session scope:** audio-not-following-to-TV complaint → live diagnosis → module fix → deploy → E2E verify

---

## The Complaint

"Why does the audio not auto change when I move the Helium window that plays the audio to the TV? Move audio to TV and fix the root cause after."

## Root Cause (verified live, both directions post-fix)

**Stale PipeWire object id in the smart-audio daemon.** The daemon resolved the Radeon HDMI card's numeric device id **once at startup** (id 69). PipeWire ids drift whenever devices re-register; id 69 later became the **Ryzen analog card**. Every "Switching to DP-2" then ran `wpctl set-profile 69 3` on the WRONG card:

- The Radeon card stayed on `extra1` (monitor) → the TV sink `alsa_output.pci-0000_c6_00.1.hdmi-stereo-extra2` never appeared → daemon error-looped `sink not found` for **~10 hours** (journal: repeated attempts Sep 6 08:55–09:04).
- `check=False` on the wpctl call swallowed the failure entirely — zero signal that the wrong device was being mutated.
- **Collateral:** the stray writes flipped the Ryzen card to `input:analog-stereo` (mic-only; output sink gone), persisted by WirePlumber.
- DP-1 direction only ever "worked" because `extra1` was already the card's active profile at daemon start — the profile switch was a silent no-op on the wrong card, then `set-default` found the already-existing monitor sink. The success was accidental.

**Not the cause (verified):** the DP-2→`output:hdmi-stereo-extra2` mapping — correct, confirmed against `/proc/asound/card0/eld#0.2` (`monitor_name LG TV SSCR2`; DP-1 monitor = `eld#0.1` = `extra1`).

## The Fix (deployed 09:14, system generation via `nix run .#deploy`)

`modules/nixos/desktop/smart-audio.nix`, daemon script:

1. **`resolve_device()`** — re-resolves the device by its **stable `device.name`** before every profile switch, with auto-scan fallback (PCI-renumber resilience, matching the 2026-08-31 lesson). Name is the stable handle; numeric ids are ephemeral — same doctrine as PCI addresses and sd-letters.
2. **wpctl error capture** — `set-profile` rc/stderr captured and logged on failure (was `check=False`, fully silent).
3. **Diagnosability** — sink-not-found now logs the live HDMI node names (`hdmi_sink_names()`); "Switching to …" logs the resolved device id.

Verified E2E live: `focus-workspace main` → monitor sink `[LG HDR 4K]` default on device 54; `focus-workspace chat` → TV sink (HDMI 3) default on device 54; **zero ERROR/WARNING lines since the fix**; Ryzen card restored to `output:analog-stereo+input:analog-stereo` and never touched again. Committed by the auto-commit daemon (`eea8bbec`, `bb5d2e66` — tree clean). AGENTS.md updated (id-drift class, verified jack map, `focus-workspace` numeric-ref gotcha).

---

## a) FULLY DONE

1. Live diagnosis with authoritative evidence at every step (journal, `pw-dump`, `wpctl status`, `/proc/asound` ELDs, inline probe replica) — no guesses shipped.
2. Operational fix first: audio routed to the TV (profile extra2 on the correct card, TV sink set default) within minutes of diagnosis, per the user's ordering.
3. Root-cause fix in the module (name-based re-resolution + error surfacing), not a workaround.
4. Syntax gate (`py_compile` on the extracted script), eval gate (`nix eval` evo-x2 toplevel), format gate (`nix fmt --no-update-lock-file -- --ci`, 0 changed).
5. Deploy via the sanctioned `nix run .#deploy` (93 PASS / 1 FAIL = pre-existing Bank-Sync baseline, advisory; pressure gate WARN on IO PSI = known corpse-pile signature, no reboot since 2026-08-31).
6. E2E verification in BOTH directions post-deploy, including proof the wrong-card mutation is gone (Ryzen profile stable across switches).
7. Repaired the collateral damage (Ryzen card profile, twice — the old daemon re-broke it once more at 09:09 before the deploy).
8. AGENTS.md memory updated immediately (id-drift class, verified jack mapping, numeric workspace-ref trap).
9. Final state left exactly as the user wanted: `chat` workspace (DP-2) focused, TV sink default.

## b) PARTIALLY DONE

1. **Playback-follow verification:** routing (profile + default sink) is verified, but NO live audio stream existed during the session (Helium was paused; Streams empty). I never confirmed an actual playing stream moves with the default sink. High confidence (profile flip destroys the old sink; WirePlumber relinks streams to the new default; a saved per-app target can't pin a nonexistent sink), but **unproven audibly**.
2. **The TV sink's missing ELD label:** TV sink shows `Digital Stereo (HDMI 3)` WITHOUT the `[LG TV SSCR2]` suffix the monitor sink gets. I judged it cosmetic (description only; routing is ELD/jack-correct) but did NOT prove it — if WirePlumber fails to read the ELD for that route, there could be edge behavior (e.g. format negotiation falling back to stereo PCM defaults). Unresolved.
3. **Pre-commit/CI validation of the committed change:** the daemon committed before I ran the repo's full gate (`nix flake check`). The eval + fmt + py_compile gates passed and the deploy built the world successfully, so risk is low, but I did not watch a clean hook run on MY diff.

## c) NOT STARTED

1. No regression test for the stale-id class (no `tests/test-smart-audio*.nix`; module is only eval-covered via evo-x2).
2. No monitoring for smart-audio failure/hang states — the ~10h error-loop was COMPLETELY silent to every alerting layer (service "active", no Gatus, no textfile metric). Repo doctrine says silent failures are unacceptable; this one slid.
3. No runbook doc (`docs/services/` has none for smart-audio).
4. No daemon-side retry backoff — on a future genuine failure the daemon will error-log on EVERY focus event (the flood pattern seen 08:55–09:04).
5. Semantics review: daemon routes on **focused output**, not on the output of the window **producing** audio. If the user moves an audio-playing window without focusing it, audio does NOT follow. Never discussed with the user.

## d) TOTALLY FUCKED UP

Nothing destructive or lasting. Honest damage ledger for the session:

1. During the interim window (manual TV fix ~09:03 → deploy 09:14), the old daemon kept wrong-card writing; I restored the Ryzen mic profile at 09:04 and the old daemon re-broke it at 09:09. Self-healed by the deploy + final restore.
2. My probe loop briefly parked the Radeon card on the dead base `hdmi-stereo` jack (idx 1, `monitor_present 0`) between probes — no audio target existed for ~seconds until I set extra2. No user impact observed.
3. Wasted diagnosis round on the "daemon's pw_dump mysteriously failing" theory (09:04–09:09): it was my own timeline misread — the manual fix landed AFTER the last failed attempt, and the user's idle session generated no new focus events to prove it. An immediate forced focus-event test would have collapsed three tool calls into one.
4. `focus-workspace 4` numeric-ref confusion: two round trips burned before switching to workspace NAMES. (Now documented in AGENTS.md so it's at least paid-for knowledge.)

## e) WHAT WE SHOULD IMPROVE (session-derived lessons)

1. **Cached-handle hygiene as a class:** any daemon caching PipeWire/Wayland numeric ids (pw device ids, node ids) must re-resolve by stable name per use. Worth a repo-wide grep for other `pw-dump`-id or numeric-id caches (quickshell widgets, collectors).
2. **`check=False` without logging is a trap:** every fire-and-forget subprocess call in daemon scripts should at least log rc/stderr on failure. The 10h silence was 50% stale-id, 50% swallowed error.
3. **"Active ≠ healthy" for user services:** the daemon error-looped for 10h while systemd showed active. Failure-state visibility for user-session daemons is a gap (only hard unit failures reach `system_user_units_failed`).
4. **Time-correlation discipline:** when manually fixing live state mid-diagnosis, timestamp the fix precisely and correlate with the last error BEFORE theorizing about "why does the daemon still fail".
5. **Drive focus tests by workspace NAME** — numeric refs are ambiguous with named + unnamed workspaces across outputs.

## f) NEXT UP TO 50 (session-scoped backlog, roughly Pareto-ordered)

**Verification / confidence:**

1. User confirms audio audibly plays from TV speakers during Helium playback (the one thing SSH cannot prove).
2. While a stream plays, capture `pw-dump` stream→sink link to prove playback follows the default on a DP-1↔DP-2 flip.
3. Investigate missing `[LG TV SSCR2]` ELD label on the TV sink (WirePlumber route/ELD refresh; compare `pw-dump` route props for both jacks).
4. Watch first real TV-audio session for dropouts/format issues (TV is 30Hz SSCR2; audio PCM caps from ELD unchecked).

**Monitoring (doctrine: silent failures unacceptable):**
5. Add smart-audio health signal: journal-error counter or daemon self-metric (e.g. `smart_audio_switch_errors_total`, `smart_audio_last_success_epoch`) via textfile or Gatus-able surface.
6. Gatus check for "audio routing healthy" (e.g. default sink is an HDMI sink when a graphical session exists).
7. Consider a desktop notification/notify on persistent smart-audio failure (sev1-bridge notify tier).

**Robustness of the daemon:**
8. Add error backoff (after N consecutive failures for same target, log once per minute instead of per focus event).
9. Re-resolve device ALSO when `set-default` fails (currently only profile path is guarded).
10. Handle `resolve_device()` name-gone + auto-scan-found-new-card logging edge (verify card_token recompute propagates to later switches — code says yes, untested).
11. Consider re-pinning `current_output` validity: if the default sink disappears under the daemon (external change), next focus event only fires on EVENT, not state drift — optional periodic re-check timer (60s) as self-healing.
12. Startup: also verify `WP default sink` matches expectation at start (already switches to focused output — OK).

**Semantics / UX:**
13. Decide focus-based vs audio-source-window-based routing (see question 2).
14. If focus-based stands: document in module description that audio follows KEYBOARD focus, and moving a window without focusing it won't move audio.
15. Consider per-sink volume normalization (TV at 1.10 vs monitor 0.70 — jarring on switch; maybe intentional).

**Tests / CI:**
16. Extract the daemon Python to a derivable string and add a `py_compile`-plus-smoke flake check (cheap, catches syntax regressions at check time).
17. Add a lightweight eval-level regression test that the daemon text contains `resolve_device` and error capture (tripwire against regression to cached-id).
18. Full VM test is likely impractical (needs PipeWire + niri), but a unit test of `resolve_device`/`find_sink_id` against a FIXTURE pw-dump JSON is easy and valuable (the fixture≠prod-truth rule from InboxClean applies — keep fixtures derived from real pw-dump captures).
19. Verify the committed change passes the pre-commit hook path on next manual commit (daemon commits may bypass).

**Class-wide hygiene:**
20. Grep repo for other cached PipeWire/numeric-id patterns (quickshell plugins, scripts, collectors).
21. Grep repo for `check=False`-style swallowed failures in daemon scripts (smart-audio fixed; focus-new-windows and others unaudited).
22. Check focus-new-windows daemon for the same stale-id/niri-socket assumptions (it caches window ids by design — different, but the niri socket path could rotate like NIRI_SOCKET did mid-session concern).
23. Add smart-audio runbook to `docs/services/` (diagnosis flow: journal → ELD map → wpctl manual switch → daemon restart).

**Adjacent items noticed but untouched (per scope discipline):**
24. Deploy smoke WARN: fish startup 218ms (>200ms threshold) — recurring baseline noise, not mine.
25. Deploy smoke WARN: 1 error line in quickshell journal last 1h — unexamined.
26. IO PSI avg10 72.60% WARN with calm memory — the documented D-state corpse-pile signature; the owed reboot (since 2026-08-31 boot) would clear it.
27. Sink node id 106 was reused across profile flips (71→106) — node-id reuse confirms node ids are as unstable as device ids; anything referencing node ids long-term is fragile.
28. Helium runs with only an "input" PipeWire client visible while idle — playback client registers on demand; nothing to fix, just noted for future stream debugging.

## g) QUESTIONS (cannot be answered from the machine)

1. **Did audio actually come out of the TV speakers?** I verified profile, sink, default-sink, and ELD wiring — but never heard a thing (no active stream during the session). If YouTube on the TV is silent despite the TV sink being default, the remaining suspect is the ELD/format path (item 3).
2. **Should audio follow the focused output (current design), or the window that is PRODUCING the audio?** Today: move the Helium window to the TV without focusing it → video on TV, audio stays on monitor until you focus it. Focus-following is simpler and usually coincides; source-following matches the literal complaint but needs a stream→window mapping (app_id heuristics). Your call.
3. **Do you want smart-audio failures to notify you** (Discord/desktop notification when routing fails repeatedly), or keep it silent-log-only? Doctrine says monitored, but it's a desktop-comfort service and only you can weigh notification fatigue vs. a silently-wrong audio sink.

---

**Bottom line:** complaint root-caused to a stale PipeWire device id + swallowed wpctl errors; fixed at the source, deployed, verified both directions live; audio left on the TV as requested. The honest gaps: audible-verification and stream-follow proof (needs the user playing something), no regression test, and no monitoring — all queued above.
