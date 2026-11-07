# Session Status: DP-2 TV Overscan Fixed via SSAP (Hotel-Mode 65UP75003LF)

**Date:** 2026-11-07 (early hours) · **Scope:** this session only — diagnose + fix the TV-as-DP-2 overscan crop end-to-end from the network, no remote presses beyond the one pairing approval.

**Outcome headline:** overscan FIXED (owner-confirmed: full left edge, from ~3-5% both-sides crop). Residual ~0.5% right-edge sliver accepted (panel-mapping level). The TV turned out to be a **hotel/Pro:Centric-provisioned LG 65UP75003LF** at `192.168.1.10` — which explained both the crop and every blocked control path.

## §a What was done

1. **Niri-side verified exact before touching anything:** DP-2 runs the pinned 3840×2160@30 EDID-preferred mode, scale 2.0 → logical 1920×1080 at x=3072 (`niri msg --json outputs`); panel 16:9, uniform 2.4 px/mm. The 4096×2160 EDID modes are NOT selected (red herring ruled out).
2. **Owner triage:** confirmed symptom = overscan crop (not scale proportions — those are intentional).
3. **DDC/CI: dead.** `ddcutil detect`: DP-1 monitor answers (VCP 2.1), DP-2 TV = "DDC communication failed". TV-side, not tooling.
4. **TV discovered on LAN via SSDP:** `[LG] webOS TV UP75003LF` = 65UP75003LF, `192.168.1.10`, MAC `dc:03:98:77:85:f8`. SSAP ports 3000/3001 open. UPnP service SCPDs (virtualSvc, WebOS_SecondScreen) are empty placeholders on this firmware.
5. **SSAP paired** (one owner OK-press; client-key saved `~/.cache/lg-tv-ssap/client-key`, mode 600). Bare register = minimal permission tier: `getSystemInfo` works, everything user-facing 401s. `getSystemInfo` returns **`"programMode": true`** = hospitality/Pro:Centric provisioning (research-confirmed meaning; second-hand hotel set).
6. **Manifest register unlocks the API:** permissions are **per-connection, from the register manifest** (aiowebostv #728 doctrine) — re-registering with lgtv2's `pairing.json` payload grants notifications + pointer socket + more.
7. **Synthetic input is hotel-blocked:** button frames (`type:button\nname:X\n\n`) and pointer moves deliver over `netinput.pointer.sock` but the TV ignores them (HOME/RATIO/VOLUMEUP/move — all dead; toast works). This also kills the klattimer factorywin route (PIN 0413 needs working buttons).
8. **THE FIX — createAlert luna-smuggling** (bscpylgtv recipe, verbatim): alert with `onClick`/`onclose`/`onfail` = `luna://com.webos.settingsservice/setSystemSettings`, then closeAlert. Writes that worked:
   - `{"category":"aspectRatio","settings":{"justScan":"on"},"current_app":true}` (`current_app` REQUIRED for this category) — fixed the bulk of the crop.
   - `{"arcPerApp":"original","allDirZoom*":"0"}` — fixed the left edge completely.
9. **Residual right sliver investigated and closed:** `allDirZoomHPosition` nudges do nothing (zoom path inert) → panel-mapping level. Trade-offs (symmetric amdgpu borders / global niri struts) rejected; accepted.
10. **amdgpu underscan claim corrected:** DC DOES expose `underscan`/`hborder`/`vborder` (≤128) connector props (drm_info) — unusable from outside niri (DRM master), not absent as previously stated in desktop.md.

## §b Tooling left behind

`~/.cache/lg-tv-ssap/`: `tv-remote.sh` (buttons), `tv-pointer.sh` (moves), `tv-set-setting.sh` (luna writes — the important one), `ssap-call.sh`, `register-manifest.sh`, `pairing.json` (manifest), `client-key` (600, never commit). All pin a websocat STORE PATH — rebuild with `nix build nixpkgs#websocat` if GC'd. If the TV power-cycles the crop back (hotel enforcement), re-run the two §a.8 writes.

## §c Follow-ups harvested (§f obligations)

See TODO_LIST rows citing this report: tooling promotion to repo scripts (desktop), dnsblockd registry entry for the TV (services, also resolves the 2026-10-04 "is the TV network-connected" open question), residual-slit decision recorded as accepted (desktop, [decision]).

## §d Lessons

- **Session sudo exception confirmed again** (crush v0.100.0 gen 984 class, 2026-11-07 probe ×2 doctrine): this session's `sudo -n true` rc=0 — the DRM/ddcutil probes depended on it.
- **Heredoc transport mangling struck a third time:** `'}'`→'"}'` byte corruption in a shell-heredoc-written script (2026-11-03 class) — the write tool is mandatory for quote-dense scripts.
- **The lgtv2 README button list omits RATIO; button frames use key:value lines, not JSON** (SpecializedSocket format) — source-verified before driving.
