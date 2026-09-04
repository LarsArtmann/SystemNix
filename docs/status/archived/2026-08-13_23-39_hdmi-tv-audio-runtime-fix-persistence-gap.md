# Status: HDMI TV Audio Routing — Runtime Fix Applied, Persistence Gap Found

**Date:** 2026-08-13 23:39
**Session:** Audio routing to LG TV SSCR2 via HDMI 3
**Trigger:** "I need audio on the TV ASAP!"
**System:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395)

---

## What Happened This Session

1. User urgently requested audio on the TV
2. Searched repo for audio config — found `modules/nixos/desktop/audio.nix` with WirePlumber HDMI priority rules
3. Ran `wpctl status` — found default sink was **Ryzen HD Audio Controller Analog Stereo** (sink 52), NOT the HDMI TV output
4. Ran `wpctl set-default 50` — switched default sink to **Radeon HDMI 3 (LG TV SSCR2)**
5. Verified via `wpctl status` that Helium + cava streams rerouted to the TV sink
6. Read `audio.nix` to check persistence — found existing WirePlumber profile priority config
7. Told user "nix run .#deploy will make it permanent" — **THIS WAS WRONG** (see below)

---

## a) FULLY DONE

| Item                 | Status | Detail                                                               |
| -------------------- | ------ | -------------------------------------------------------------------- |
| Runtime sink switch  | DONE   | `wpctl set-default 50` — audio now routing to LG TV SSCR2 via HDMI 3 |
| Stream verification  | DONE   | Helium and cava confirmed connected to TV sink in `wpctl status`     |
| Config investigation | DONE   | Read `audio.nix`, understood the WirePlumber profile priority rules  |

---

## b) PARTIALLY DONE

### Persistent TV-as-default-sink — **NOT ACHIEVED**

The runtime `wpctl set-default 50` works NOW but will be **lost on reboot or PipeWire restart**. No config change was made to make this permanent. ~~Resolved (superseded) at `8ad493c9` — the `smart-audio` focus-following daemon now sets sink + profile on every focus change (deployed live).~~

### Root cause diagnosis — **INCOMPLETE**

The existing `audio.nix` WirePlumber config (lines 28-57) does NOT solve the problem. It only sets `device.profile.priority.rules` for the Radeon card — this controls **which HDMI profile** is selected on the Radeon card, NOT **which card is the default sink**. The user had this config in the repo and audio was STILL going to the Ryzen analog output. Either:

- The config was never deployed (not checked), OR
- The config doesn't do what's needed (likely — it only controls profile, not default device selection)

~~Diagnosis confirmed correct — profile priority ≠ default-sink selection. Documented in AGENTS.md "Smart-Audio" (`8ad493c9`-era + `61a2224b`).~~

---

## c) NOT STARTED

- ~~No change to `audio.nix` to add persistent default sink routing~~ done (superseded) at `8ad493c9` — `smart-audio` daemon owns runtime sink+profile routing
- ~~No deploy (`nix run .#deploy`) to push any config change~~ done — deploys green since
- ~~No verification that actual sound comes out of the TV speakers (only verified PipeWire routing)~~ done (moot) — audio confirmed working; daemon deployed live
- ~~No check whether the WirePlumber config was actually deployed to the running system~~ done (moot) — superseded by the daemon approach

---

## d) TOTALLY FUCKED UP

### 1. Gave WRONG persistence advice

**I said:** "Already configured in audio.nix — nix run .#deploy will make it permanent"

**Reality:** The existing config does NOT set the default sink. `device.profile.priority.rules` only controls which HDMI _profile_ is preferred on the Radeon card. It does NOT tell WirePlumber to prefer the Radeon HDMI output as the default sink over the Ryzen analog output. Deploying the current config would NOT make the TV the default audio output.

**Fix needed:** Add WirePlumber `default.configured-sinks` config (or equivalent) to `audio.nix`:

```nix
# Make HDMI 3 (LG TV) the persistent default sink
"wireplumber.settings" = {
  "device.restore-profile" = false;
};
# Plus a node or device priority rule that makes the Radeon HDMI sink
# win over the Ryzen analog sink as the default
```

Or use `wpctl status` node names and set default via a WirePlumber `default.nodes` config or a systemd user service that runs `wpctl set-default` after login.

### 2. Didn't verify actual audio output

I confirmed PipeWire routing changed but never played a test sound. The TV might be muted, on the wrong input, or the HDMI audio channel might have its own issue.

### 3. Didn't check if existing config was deployed

The fact that analog was the default despite profile priority config existing in the repo is a red flag. I should have checked whether the config was actually live on the running system (e.g., `cat /etc/wireplumber/` or checking the WirePlumber state directory).

---

## e) WHAT WE SHOULD IMPROVE

1. ~~**WirePlumber default sink config** — The `audio.nix` module needs a `default.configured-sinks` rule (or equivalent) to make HDMI TV the persistent default output, not just the preferred profile on the Radeon card. Profile priority != default device selection.~~ done (superseded) at `8ad493c9` — the `smart-audio` daemon sets the default sink at runtime on focus change; the profile-priority vs default-sink distinction is documented in AGENTS.md "Smart-Audio"

2. **Audio verification script** — Add a `scripts/test-audio.sh` that plays a test tone and checks `wpctl status` routing, so we can verify end-to-end not just PipeWire internals.

3. **DMS audio widget** — If DankMaterialShell has an audio output switcher widget, wire it up so the user can toggle between analog/HDMI/TV from the desktop shell without SSH.

4. ~~**Boot-time default sink** — Consider a systemd user service or WirePlumber script that sets the default sink to HDMI TV on session start, as a belt-and-suspenders approach alongside the WirePlumber config.~~ done (superseded) at `8ad493c9` — that IS the `smart-audio` user service (workspace-focus-following, not just boot-time)

5. ~~**AGENTS.md documentation** — Document the distinction between WirePlumber profile priority (which HDMI output on a card) vs default sink selection (which card/output is the system default). This is exactly the kind of non-obvious gotcha that belongs in the audio section.~~ done — AGENTS.md "Smart-Audio" section (`61a2224b`)

6. **Don't claim "deploy will fix it" without verifying** — I should have traced the config to its actual effect before telling the user it would persist. The config does something different from what the user needs.

---

## f) Next 50 Things We Should Get Done

### Audio (Immediate — This Session's Debt)

1. ~~**Fix `audio.nix` — add persistent default sink for HDMI TV** (WirePlumber `default.configured-sinks` or `default.nodes` config)~~ done (superseded) at `8ad493c9` — `smart-audio` daemon handles routing at runtime
2. ~~**Deploy the fixed config** (`nix run .#deploy`)~~ done — deploys green since
3. ~~**Verify audio actually comes out of the TV speakers** (play a test sound)~~ done (moot) — audio confirmed working
4. ~~**Reboot-test** — verify the default sink survives a reboot~~ done (superseded) — the daemon re-establishes routing continuously; no reboot dependence
5. ~~**Document in AGENTS.md** — WirePlumber profile priority vs default sink distinction~~ done at `61a2224b`

### Audio (Near-Term)

6. **Add DMS audio output switcher widget** if available — let user toggle output device from desktop
7. **Add `scripts/test-audio.sh`** — test tone + routing verification
8. **Consider Bluetooth audio** — Blueman client is running but no BT sink config documented
9. **Volume normalization** — check if any compress/limiter is needed for TV output (TVs often expect line-level)
10. **Check HDMI EDID audio capabilities** — verify the TV is receiving the right codec/format

### AGENTS.md Corrections

11. ~~**Fix the claim that profile priority = default sink** — this is in the status doc from 2026-08-13_09-06, needs correction~~ done at `61a2224b` — the 09-06 report now carries a SUPERSEDED banner pointing here and to `smart-audio`
12. ~~**Document the WirePlumber default sink mechanism** — `default.configured-sinks`, `default.nodes`, or `wpctl set-default` persistence~~ done (superseded) — AGENTS.md "Smart-Audio" documents the daemon's `wpctl set-profile` + `wpctl set-default` mechanism

### Verification Gaps

13. ~~**Check if WirePlumber config from audio.nix was actually deployed** — `ls /etc/wireplumber/` or check store path~~ done (moot) — superseded; the daemon approach works live
14. **Audit all "ASAP" responses** — ensure runtime fixes are always backed by config changes
15. **Add pre-deploy audio check** — verify audio routing in `pre-deploy-check.sh`

### Session Process Improvements

16. **Never claim persistence without tracing the config** — verify the mechanism actually does what's needed
17. **Always play a test sound** — routing != audible output
18. **When config exists but doesn't work, investigate WHY** — don't just layer a runtime fix on top
19. **"ASAP" doesn't mean "stop at the first thing that works"** — finish the job, make it permanent

### General SystemNix (Observed)

20. ~~**Previous status report from 2026-08-13_09-06** claims HDMI audio routing was solved — it wasn't, or regressed. Verify and reconcile.~~ done at `61a2224b` — 09-06 annotated with a SUPERSEDED banner
21. ~~**Check if `nix flake check --no-build` passes** — no validation run this session~~ done (moot) — green in pre-commit/CI since
22. **Check if any other audio-related issues exist** — HDMI 2 monitor speakers, DisplayPort audio, USB audio
23. **Review WirePlumber version** — 1.6.8 may have changed config syntax vs what audio.nix uses
24. **Check `wpctl inspect 50`** — verify the sink properties and ensure it's healthy
25. **Consider `auto-profile` vs manual profile selection** — WirePlumber may fight the config

### Documentation

26. ~~**Update `docs/status/2026-08-13_09-06_hdmi-audio-routing-wireplumber-profile-priority.md`** — mark as INCOMPLETE, add follow-up~~ done at `61a2224b` — marked SUPERSEDED (by `smart-audio`, `8ad493c9`)
27. **Add audio troubleshooting section to AGENTS.md** — wpctl commands, common issues, profile vs sink distinction
28. ~~**Document HDMI port → device mapping** — HDMI 2 = monitor, HDMI 3 = TV, with ALSA names~~ done — documented at `audio.nix:38` (ELD mapping comment)

### Monitoring

29. **Add Gatus check for audio sink** — verify the expected default sink is active
30. **Add audio health metric** — `system-health` could check PipeWire daemon liveness and default sink
31. **Alert on audio sink change** — if default sink changes from HDMI TV, alert

### DMS / Quickshell

32. **DMS volume widget** — verify it controls the correct sink (TV, not analog)
33. **DMS audio routing widget** — expose output device selection in the panel
34. **Media key integration** — verify volume keys affect TV output

### Deployment

35. ~~**Deploy and verify audio persistence** — the #1 outstanding task~~ done (superseded) at `8ad493c9` — `smart-audio` deployed live
36. ~~**Test config change doesn't break other audio** — analog still available as fallback~~ done (moot) — analog remains available; daemon only moves the default
37. ~~**Test profile switching** — ensure HDMI 2 (monitor) still works as fallback~~ done — the daemon maps every focused output (monitor included) to its HDMI profile

### Quality

38. **Audit audio.nix for correctness** — is the WirePlumber config syntax correct for WP 1.6.x?
39. **Add assertion in audio.nix** — warn if HDMI TV device not found at eval time
40. **Consider device.naming** — use ALSA card names not PCI addresses for robustness

### Backup / Recovery

41. **Document manual recovery** — `wpctl set-default 50` as the manual fallback command
42. **Add to runbook** — "Audio not on TV" troubleshooting steps

### Remaining (Lower Priority)

43. **Check if JACK support is needed** — it's enabled but may not be used
44. **Review 32-bit ALSA support** — still needed?
45. **Check PipeWire config** — `client.conf`, `pipewire.conf` defaults
46. **Review `security.rtkit`** — is it still needed/recommended?
47. **Consider PipeWire wireplumber split** — separate config files for clarity
48. **Check audio latency** — HDMI audio can have higher latency, may need adjustment
49. **Review ALSA UCM profiles** — are custom profiles needed for the Radeon card?
50. ~~**Add audio to `FEATURES.md`** — document audio routing as a feature with status~~ done at `61a2224b` — Smart-Audio row added to FEATURES.md

---

## g) Questions I Cannot Answer Myself

1. **Does the audio actually come out of the TV speakers right now?** I verified PipeWire routing but never played a test sound. Is the TV on the right HDMI input? Is it muted? Does the HDMI cable carry audio?

   > **Answered (2026-08-14):** Yes — audio works on the TV; the `smart-audio` daemon has been routing since `8ad493c9` (deployed live).

2. **Was the WirePlumber config from `audio.nix` ever actually deployed?** The config exists in the repo but the default sink was analog — this means either it was never deployed, or it doesn't work as intended. I can't tell without checking the running system's WirePlumber state directory, and I'm not sure if `audio.nix` changes since the last deploy are live.

   > **Answered (2026-08-14):** Moot — the static config was superseded; `smart-audio` owns routing now. AGENTS.md notes the `device.restore-profile = false` coexistence question as unverified.

3. **Do you want the TV to be the ONLY audio output, or should analog (headphones/speakers) remain available as a fallback?** This affects how we configure the default sink — hard-priority TV-only vs soft-priority TV-preferred-but-analog-available.

   > **Answered (2026-08-14):** Soft-priority — `smart-audio` routes per focused workspace; all outputs stay available.
