# Status Report: HDMI Audio Routing (WirePlumber Profile Priority)

**Date:** 2026-08-13 09:06
**Session Focus:** Fix LG monitor / TV not being selected as audio output in PipeWire + WirePlumber

---

## Context

The user asked "Why is my LG Monitor not my speaker?" The system has a Radeon HD Audio Controller (`pci-0000:c5:00.1`) with two HDMI/DisplayPort outputs connected to displays:

| Port   | ELD Device | Monitor Name | Speakers                     | Profile Name                |
| ------ | ---------- | ------------ | ---------------------------- | --------------------------- |
| HDMI 2 | `eld#0.1`  | LG HDR 4K    | Stereo (FL/FR)               | `output:hdmi-stereo-extra1` |
| HDMI 3 | `eld#0.2`  | LG TV SSCR2  | Full surround (all channels) | `output:hdmi-stereo-extra2` |

WirePlumber was auto-selecting HDMI 3 (the TV) by default. The `audio.nix` module had **zero WirePlumber routing configuration** -- it only enabled PipeWire + ALSA + Pulse + JACK with no `wireplumber.extraConfig`.

---

## A) FULLY DONE

> **Superseded (2026-08-14):** the static profile-priority approach developed a persistence gap (see `2026-08-13_23-39` §d.1) and is now superseded by the `smart-audio` focus-following daemon (`8ad493c9`) — see AGENTS.md "Smart-Audio".

1. **Diagnosed the root cause:** WirePlumber had no explicit profile priority rules, so it auto-selected HDMI 3 (TV) over HDMI 2 (monitor) based on its internal "find-best-profile" heuristic (surround profiles have higher priority than stereo in WirePlumber's default scoring)
2. ~~**Added `wireplumber.extraConfig` to `audio.nix`** with:
   - `device.profile.priority.rules` matching `alsa_card.pci-0000_c5_00.1` to set explicit profile priority order
   - `device.restore-profile = false` to prevent WirePlumber from overriding the declarative priority with whatever was last selected at runtime via `wpctl set-profile`~~ done at `cfeee94d`, later superseded by the `smart-audio` daemon (`8ad493c9`)
3. ~~**Applied runtime fix** via `wpctl set-profile 43 <index>` so audio works immediately without requiring a deploy~~ done (temporary by design), superseded by `8ad493c9`
4. ~~**Flipped priority twice** -- initially set HDMI 2 (monitor) as priority, then user said "for now I need it on my TV", so switched to HDMI 3 (TV) as priority~~ done at `cfeee94d`, superseded by `8ad493c9`
5. **Verified eval passes** -- `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` succeeded
6. **Verified `nix flake check --no-build` passes** -- all checks passed including the `audio` module

---

## B) PARTIALLY DONE

1. ~~**Runtime audio verified but not auditorily confirmed** -- I confirmed the sink switched via `wpctl status` (HDMI 3 is the active sink, volume 1.00), but never played a test sound. `speaker-test` and `amixer` were not on PATH. Could have used `pw-cat` or a Helmholtz test tone to confirm audio actually reaches the TV speakers~~ done (moot) -- audio audibly confirmed in the `2026-08-13_23-39` session; `smart-audio` deployed live
2. ~~**Config file written but NOT deployed** -- the Nix change is in the working tree but `nix run .#deploy` was NOT run. The runtime fix (`wpctl set-profile`) is temporary; it will survive until WirePlumber restarts or the system reboots, at which point the declarative config takes over (once deployed)~~ done -- deployed with `cfeee94d`
3. ~~**Volume set to 100%** -- `wpctl set-volume 51 1.00` was applied, but the WirePlumber config has `device.routes.default-sink-volume = 0.064` (6.4%) as the default. The `device.restore-routes` setting (still `true`) means WirePlumber will restore the last known volume, so 100% should persist after deploy. But if routes are not restored, audio will be very quiet on next boot~~ done (moot) -- no volume regression reported across subsequent reboots

---

## C) NOT STARTED

1. ~~**AGENTS.md update** -- The audio routing gotcha (WirePlumber profile priority for multi-HDMI setups) should be documented in the "Desktop (DMS / Quickshell / Helium)" or a new "Audio" section of `AGENTS.md`. Currently there is no mention of WirePlumber or audio routing anywhere in the project docs~~ done at `8ad493c9` + `61a2224b` (AGENTS.md "Smart-Audio" section)
2. **`nix fmt`** -- The file was not formatted with `alejandra`/`treefmt`. The comments contain em dashes (`---`) which violate the project's code conventions ("Never use em dashes in source code")
3. **Pre-commit hook run** -- `.githooks/pre-commit` was not run (would catch formatting, deadnix, statix, etc.)
4. ~~**Deploy** -- No `nix run .#deploy` was executed~~ done -- deployed with `cfeee94d`/`0bd8a272`; `smart-audio` deployed live (`8ad493c9`)
5. **Gatus health check for audio** -- No monitoring was added for audio device state. If the TV is disconnected and reconnected, WirePlumber may not automatically switch back. There is no alerting for "audio output is the wrong device"

---

## D) TOTALLY FUCKED UP

1. **Did not ask the user which output they wanted first** -- The user asked "Why is my LG Monitor not my speaker?" which I interpreted as "make the monitor the speaker." I spent significant effort setting up HDMI 2 (monitor) as the priority, only for the user to immediately say "For now I need it on my TV." I should have asked "Which output do you want audio on?" before writing any config. This wasted a round-trip and required a second edit
2. **Em dashes in comments** -- Lines 37-38 of `audio.nix` contain em dashes (`---`) which the AGENTS.md explicitly bans: "Never use em dashes in source code; use commas, periods, parentheses, or semicolons instead." I wrote these comments and violated the project's own convention
3. **`device.restore-profile = false` is GLOBAL, not device-scoped** -- This setting disables profile restoration for ALL devices, not just the Radeon HDMI controller. If the user plugs in a Bluetooth headset, USB DAC, or any other audio device, WirePlumber will NOT remember their profile selections across reboots. This is an overly broad hammer. The WirePlumber 0.5 config format does not appear to support per-device settings in the `wireplumber.settings` section -- they are global. A better approach would be a custom Lua script or accepting that the priority rules alone (without disabling restore) might be sufficient since the priority rules run BEFORE the stored profile check... except they don't: `find-preferred-profile` runs AFTER `find-stored-profile` (see `apply-profile.lua:14`). So without disabling restore, the stored profile DOES override the priority rules. This is a real tradeoff that should be documented

---

## E) WHAT WE SHOULD IMPROVE

1. ~~**Scope `device.restore-profile = false` to just the Radeon device** -- Investigate whether WirePlumber 0.5 supports per-device settings overrides, or write a small Lua script that only ignores stored profiles for `alsa_card.pci-0000_c5_00.1`. The global disable is a sledgehammer~~ done (superseded) -- the `smart-audio` daemon now actively switches profiles on focus change (`8ad493c9`); static priority is retired
2. **Remove em dashes from comments** -- Replace with commas/parentheses per project conventions
3. ~~**Make audio output selectable** -- Instead of hardcoding which HDMI port has priority, consider a NixOS option like `services.audio-config.hdmiOutput` that lets the user pick "monitor" or "tv" without editing the priority list. Or even better, a runtime switcher script~~ done (superseded) -- `smart-audio` selects the output from the focused workspace at runtime (`8ad493c9`)
4. ~~**Document the WirePlumber profile priority mechanism in AGENTS.md** -- The fact that `find-preferred-profile` runs AFTER `find-stored-profile` (so stored profiles override priority rules unless `device.restore-profile = false`) is a critical non-obvious gotcha~~ done at `61a2224b` -- AGENTS.md "Smart-Audio" documents the daemon supersedes the static rules and the possible `device.restore-profile = false` fight
5. **Add `device.routes.default-sink-volume` override** -- The WirePlumber default is 6.4% which is extremely quiet. If routes are not restored (e.g., after TV reconnection), audio will be nearly silent. Consider setting this to a higher default like 0.5 (50%) or 1.0 (100%)
6. ~~**Test audio output after changes** -- Find a way to play a test tone. `pw-cat` might work, or install `alsa-utils` in the system config for `speaker-test`~~ done (moot) -- audio audibly confirmed in `2026-08-13_23-39`
7. **Consider surround sound** -- The TV (LG TV SSCR2) supports 5.1/7.1 surround via `output:hdmi-surround-extra2`. Currently using stereo (`output:hdmi-stereo-extra2`). If the user wants surround from the TV, the priority should list `output:hdmi-surround-extra2` first
8. ~~**Wireplumber config file naming** -- Used `51-hdmi-monitor-priority` as the config key. WirePlumber conf.d files are loaded alphabetically. The `51` prefix places it after the `50-` nixpkgs defaults but the number has no semantic meaning in WirePlumber 0.5 (it uses JSON sections, not sequential scripts). Could use a more descriptive name~~ done (moot) -- approach retired with `smart-audio`

---

## F) Up to 50 Things to Get Done Next

| #      | Task                                                                                                                                                                 | Priority   | Effort     |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ---------- |
| 1      | Remove em dashes from `audio.nix` comments (replace with commas/parentheses)                                                                                         | HIGH       | 1 min      |
| ~~2~~  | ~~Run `nix fmt` to format `audio.nix`~~ done at `0bd8a272`                                                                                                           | ~~HIGH~~   | ~~1 min~~  |
| ~~3~~  | ~~Deploy the audio config change: `nix run .#deploy`~~ done at `cfeee94d`, `0bd8a272`                                                                                | ~~HIGH~~   | ~~10 min~~ |
| ~~4~~  | ~~Verify audio works on TV after deploy (play a YouTube video or similar)~~ done (moot, audibly confirmed in `2026-08-13_23-39`)                                     | ~~HIGH~~   | ~~2 min~~  |
| ~~5~~  | ~~Update AGENTS.md with WirePlumber audio routing gotcha (profile priority vs stored profile ordering)~~ done at `61a2224b` (AGENTS.md "Smart-Audio")                | ~~MEDIUM~~ | ~~10 min~~ |
| ~~6~~  | ~~Investigate per-device `device.restore-profile` scoping instead of global disable~~ done (superseded) by `smart-audio` daemon `8ad493c9`                           | ~~MEDIUM~~ | ~~30 min~~ |
| ~~7~~  | ~~Add `services.audio-config` NixOS option for HDMI output selection (monitor vs TV)~~ done (superseded) — `smart-audio` follows focused workspace `8ad493c9`        | ~~LOW~~    | ~~30 min~~ |
| 8      | Consider adding `output:hdmi-surround-extra2` to priority list for TV surround sound                                                                                 | LOW        | 5 min      |
| 9      | Override `device.routes.default-sink-volume` to something higher than 6.4%                                                                                           | MEDIUM     | 5 min      |
| 10     | Add `alsa-utils` to system packages so `speaker-test`/`amixer` are available for debugging                                                                           | LOW        | 5 min      |
| 11     | Write a quick audio test script that plays a tone via `pw-cat`                                                                                                       | LOW        | 15 min     |
| 12     | Consider a DMS (DankMaterialShell) widget for audio output switching                                                                                                 | LOW        | 1 hr       |
| ~~13~~ | ~~Verify the WirePlumber config survives a reboot (after deploy)~~ done (moot) — the static approach was superseded; `smart-audio` re-switches on every focus change | ~~HIGH~~   | ~~5 min~~  |
| 14     | Check if the Ryzen HD Audio Controller (card 1) has any useful analog output                                                                                         | LOW        | 10 min     |
| 15     | Document the ELD inspection process (`/proc/asound/card0/eld*`) as a debugging procedure                                                                             | LOW        | 10 min     |
| ~~16~~ | ~~Consider whether `device.restore-routes = true` (still enabled) causes volume issues~~ done (moot) — no volume regression across subsequent reboots                | ~~MEDIUM~~ | ~~10 min~~ |
| 17     | Add a Gatus check or metric for "default audio sink is the expected device"                                                                                          | LOW        | 30 min     |
| ~~18~~ | ~~Pre-commit hook: run it to verify no other issues (deadnix, statix, gitleaks)~~ done (moot) — subsequent commits passed the hooks                                  | ~~MEDIUM~~ | ~~2 min~~  |
| ~~19~~ | ~~Verify the config file naming (`51-` prefix) follows any SystemNix conventions~~ done (moot) — static approach retired                                             | ~~LOW~~    | ~~5 min~~  |
| ~~20~~ | ~~Consider making the HDMI port mapping (extra1=HDMI2, extra2=HDMI3) a comment in the config~~ done — documented at `audio.nix:38` (ELD mapping)                     | ~~LOW~~    | ~~2 min~~  |

---

## G) Questions I Cannot Answer Myself

1. **Do you want surround sound on the TV?** The LG TV SSCR2 supports 5.1 surround (`output:hdmi-surround-extra2`) and even 7.1. I set it to stereo (`output:hdmi-stereo-extra2`). Should I add `output:hdmi-surround-extra2` as the first priority instead, or do you prefer stereo?

   > **Answered (2026-08-14):** Still stereo. `smart-audio` maps focused workspace → output → profile dynamically; surround remains an open idea (§F.8).

2. **Is the global `device.restore-profile = false` acceptable?** This means NO audio device (including Bluetooth, USB DACs, future headsets) will remember its profile across reboots. The alternative is writing a custom Lua script to scope the disable to just the Radeon HDMI controller, which is more work. Do you want me to scope it, or is the global disable fine for your setup?

   > **Answered (2026-08-14):** Superseded — `smart-audio` (`8ad493c9`) owns profile switching now; AGENTS.md notes the possible `device.restore-profile = false` fight (coexistence unverified).

3. **Should the audio output priority be a runtime-switchable thing or always declaratively pinned?** Right now it is hardcoded in Nix. If you frequently switch between monitor speakers and TV speakers, a DMS widget or a `switch-audio-output` script might be more ergonomic than editing `audio.nix` and redeploying each time.

   > **Answered (2026-08-14):** Runtime — that is exactly what `smart-audio` does: focus-following workspace → output routing (`8ad493c9`).
