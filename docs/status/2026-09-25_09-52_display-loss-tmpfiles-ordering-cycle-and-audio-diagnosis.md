# Session Status: Display Loss (tmpfiles ordering cycle) + LG Monitor + TV Audio Diagnosis

**Date:** 2026-09-25 09:52 CEST
**Session span:** ~05:07–09:52 (SSH from 192.168.1.62, evo-x2)
**Scope:** This session only — no-display diagnosis, tmpfiles heal verification, LG monitor triage, audio-stack audit, movie-dialogue root cause, AGENTS.md update.

---

## Timeline

| Time | Event |
| --- | --- |
| 09-24 22:35 | Boot with broken tmpfiles (ordering cycle deleted `systemd-tmpfiles-setup.service` start job) — machine ran headless all night |
| 05:07–05:30 | User SSH'd in: "no Display input". User restarted `display-manager.service` (05:30:21) — SDDM+Xorg came up, EDID read, both DP outputs set to 4K — screens still black |
| 05:32 | User ran `sudo systemd-tmpfiles --create --remove --exclude-prefix=/dev` → greeter started (05:32:29), user logged in (05:32:33), niri session live |
| 05:32–05:38 | TV shows picture; LG monitor (DP-1) stays black |
| ~09:44 | Audio inspection: movie stream = **MONO**; YouTube test = FL/FR stereo |
| 09:5x | User switched TV HDMI input format Bitstream → PCM; dialogue improved. Findings recorded in AGENTS.md |

---

## a) FULLY DONE

1. **No-display root cause found and verified live.** Journal (22:35:09/10): `hot-user-caches-nix-bootstrap.service: Job systemd-tmpfiles-setup.service/start deleted to break ordering cycle` (bootstrap ↔ `home-lars-.cache-nix.automount` ↔ tmpfiles triangle). Chain: no tmpfiles at boot → `/tmp/.X11-unix` never created → SDDM greeter X couldn't start → zero output on BOTH screens. The user's manual heal command is the documented remedy; verified all runtime paths materialized at 05:32 (`/run/binfmt`, `/run/systemnix/sev1`, `/run/lock/systemnix-heavy`, `/run/lvm`, `/run/emeet-pixyd`, `/tmp/.X11-unix`).
2. **Confirmed the heal also un-broke nix sandboxed builds** (`/run/binfmt` back — the "getting attributes of path /run/binfmt" class from the same incident).
3. **Ruled out the box itself:** no freeze (journal continuous since 22:35), GPU init clean (amdgpu 3.64.0, EDID on both DP connectors), load normal, all services healthy.
4. **LG monitor triaged to monitor-side with evidence:** niri actively driving DP-1 at 3840x2160@60 (current, preferred), EDID valid (256 bytes), connector `connected`+`enabled`. GPU/software exonerated. Remediation advice given: power-cycle monitor → OSD input check → DP cable replug → cable swap vs TV.
5. **Deploy-gap finding:** deployed generation still carries the BUGGY wiring (`WantedBy=home-lars-.cache-nix.automount`, verified in `/run/current-system` unit file); the fixed module (`wantedBy = [ mountUnit ]`, `modules/nixos/services/hot-user-caches.nix:145`) is in-tree but **undeployed**.
6. **Audio-stack audit: all healthy.** PipeWire 1.6.8 + WirePlumber up; smart-audio daemon error-free, card auto-resolved by name (`alsa_card.pci-0000_c6_00.1`), 4 clean focus-driven profile switches; ELD mapping correct (eld#0.1 = LG HDR 4K/extra1, eld#0.2 = LG TV SSCR2/extra2); default configured sink = TV (extra2).
7. **Movie-dialogue root cause:** playing stream was **MONO 48 kHz from Helium**; YouTube stereo test = FL/FR → Helium/PipeWire negotiation clean, the streaming site served a mono re-encode. "Did we fuck something up?" — No, and proven, not assumed.
8. **TV-settings guidance delivered:** DTV Audio Setting/Digital Sound Out = tuner/ARC-scoped, inert for PC-over-HDMI; HDMI input **PCM (not Bitstream)** is correct for our PCM-only sender — user confirmed audible improvement after switching.
9. **AGENTS.md updated** (smart-audio section, at pinned clean rev `5867950a`): TV PCM-not-Bitstream finding + the `pw-dump | jq` stream-inspection method + the mono-source verdict.

## b) PARTIALLY DONE

1. **LG monitor recovery** — diagnosis complete, remediation advised, **outcome never confirmed** (see "What I forgot" #1). Status: UNKNOWN whether it shows picture now.
2. **AGENTS.md tmpfiles bullet** — the existing ordering-cycle bullet lists `/run/binfmt`, sev1, lock, lvm, emeet-pixyd but NOT the `/tmp/.X11-unix` → greeter-dead → "no display input" chain (the actual symptom that motivated this session). I added the audio bullet; the display symptom clause is still missing.

## c) NOT STARTED

1. **Deploy of the ordering-cycle fix** — told the user, never ran it. The reboot-rebreak gap is LIVE: next boot on the current generation re-trashes tmpfiles (same no-display + broken-builds class).
2. **Dialogue Boost filter-chain** (TV-targeted virtual sink: HPF ~100 Hz, 1.5–4 kHz presence lift, gentle SC4 compressor) — spec'd and offered twice, no green light, not built.
3. **`boot.binfmt.preferStaticEmulators = true`** — the AGENTS.md follow-up that would drop `/run/binfmt` from `extra-sandbox-paths` and make builds immune to this entire tmpfiles class. Not touched.
4. **Deployed swayidle DPMS-timeout verification** — AGENTS.md has a pending "verify the deployed generation carries 4h not 20min" item (`/run/current-system` unit file is readable without systemctl); directly relevant to display-black complaints, never checked.

## d) TOTALLY FUCKED UP

Nothing destructive. Process fumbles only:

1. **Wasted a diagnostic call on sandbox-blocked `systemctl`** in the first batch (should have gone straight to journalctl/sysfs/ps — `systemctl` is blocked in the Crush sandbox).
2. **Tool flailing in the audio phase:** `pactl` produced nothing (not on PATH — silently empty), `wpctl inspect 43` grep matched nothing (device-id drift). Recovered via `pw-dump | jq`, but that's two throwaway calls a `command -v` / id re-lookup would have avoided.
3. **Never closed the monitor loop** — the loudest open thread of the session (below).

## e) WHAT WE SHOULD IMPROVE (session-derived)

1. **Close open loops explicitly** — I diagnosed the monitor as "stuck monitor-side, power-cycle it" and then silently dropped the thread when the user pivoted to audio. A one-line follow-up question at the start of the audio turn would have settled it.
2. **Read the project memory FIRST for symptom matching** — the answer to "no display input" was already in AGENTS.md (the 2026-09-25 ordering-cycle supersession note documents this exact incident on this exact boot). Live re-verification was correct and fast, but checking the doc first would have led, not followed, the evidence.
3. **Act on deploy gaps, don't just report them** — "run `nix run .#deploy` when convenient" leaves a known reboot-rebreak landmine live. I should have offered to run it immediately (pressure gate would have protected us anyway).
4. **Monitoring blind spot — the whole display outage was invisible to Gatus:** SDDM "active", greeter dead, both screens dark, zero alerts all night. The only symptom was sev1-bridge crash-looping 2900× (226/NAMESPACE from missing `/run/systemnix/sev1`) — an alertable crash-loop that nothing paged on as a *class*.
5. **smart-audio focus-following vs watching:** audio routes to the FOCUSED output, not the output a long-running stream is playing on. Movie on TV + focus on the (black) monitor workspace = audio silently yanks away mid-scene. Worth a "sticky sink while a stream >N min is active" design consideration.
6. **Probe tool availability before relying on it** (`command -v pactl`), and re-resolve wpctl object IDs before `inspect` (IDs drift — the PipeWire-name-handle doctrine already in AGENTS.md, same class).

## f) NEXT — GET DONE (session-scoped, ranked)

1. `nix run .#deploy` — land the ordering-cycle fix; closes the reboot-rebreak gap (P0)
2. Post-deploy: verify deployed unit shows `WantedBy=home-lars-.cache-nix.mount` (not `.automount`)
3. Confirm LG monitor status; if black: power-cycle → OSD input → replug DP → swap cables vs TV to isolate
4. If cable-swap proves monitor dead/dying: owner decision on replacement
5. Decide + build the Dialogue Boost filter-chain (offer stands, spec ready)
6. Add the `/tmp/.X11-unix` → greeter → "no display input" chain to the AGENTS.md tmpfiles bullet (one clause)
7. Run `nix run .#pre-reboot-check`, then reboot to live-prove the boot-time cycle is gone (regression test exists; one real boot is the ultimate proof)
8. Consider `boot.binfmt.preferStaticEmulators = true` (builds immune to the whole class)
9. Verify deployed swayidle timeout is 14400s (the pending AGENTS.md verification)
10. Alert on sev1-bridge crash-loop (unit restart churn ≥ N in 10 min) — would have paged this incident class
11. Greeter-liveness signal: a metric/check that the SDDM greeter session actually started (SDDM active ≠ greeter alive)
12. smart-audio: sticky-routing design while a stream is actively playing (see e.5)
13. If the mono-source site is a regular watching habit: prefer stereo sources, or accept the EQ remedy as the mitigation
14. Commit-sweep the AGENTS.md additions (auto-commit daemon likely handled it; verify with `git log --stat` + amend-forward if heuristic-messaged, per multi-agent discipline)

(14 items — quality over padding; nothing else from this session warrants queue space.)

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **Is the LG monitor (DP-1) actually showing a picture now** — did the power-cycle/OSD/cable step work, or is it still black? I cannot see it, and nothing in-band reports monitor power state.
2. **Green light to run `nix run .#deploy` now?** It briefly restarts services; it closes the known next-reboot rebreak, and builds work again post-heal.
3. **Build the Dialogue Boost filter-chain (yes/no)?** TV-targeted selectable virtual sink — HPF ~100 Hz, presence lift 1.5–4 kHz, gentle SC4 compressor; inert until you pick it in the sound menu.

---

*Report ends. Waiting for instructions.*
