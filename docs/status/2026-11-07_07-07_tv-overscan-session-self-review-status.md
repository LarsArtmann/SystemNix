# Session Status: TV-Overscan SSAP Fix — Full Self-Review & Status

**Date:** 2026-11-07 07:07 · **Scope:** THIS session only (the "niri thinks the TV is wider" → fixed-over-the-network arc, plus its close-out). No unrelated project research performed for this report.

**Scope line — VERIFIED here:** niri live output state (`niri msg --json outputs` via explicit socket), EDID/modes (`/sys/class/drm/card1-DP-2/{modes,status}`), deployed config (`~/.config/niri/hm.kdl:39-44`), DDC/CI (`ddcutil detect` — DP-2 "DDC communication failed", DP-1 healthy control), TV identity (`getSystemInfo` → `65UP75003LF`, `programMode:true`), SSAP behavior (pairing response, 401s, manifest-register unlock, `getPointerInputSocket` socketPath, toast `toastId`, both luna-write legs `returnValue:true`), button/pointer hotel-blocking (HOME/RATIO/VOLUMEUP/move — owner-reported no effect ×4), DRM underscan props (`drm_info` shows them on all DP connectors), TODO gate (`check-todo-system.sh` "structure clean", this session's reports not in the unharvested set). **NOT verified here:** TV-side visual outcomes (all owner-reported, not sensor-read), fix persistence across TV power-cycle/standby (NOT attempted — owner-gated), whether hotel mode resets other settings (unknown), whether the physical remote can still change menus (never tested — synthetic input block says nothing about IR), `set-underscan.py` final state (abandoned mid-debug; see d.5).

---

## a) FULLY DONE

1. **Root-cause diagnosis, evidence-backed** — niri geometry exact (3840×2160@30 EDID-preferred, scale 2.0 → 1920×1080 @ x=3072; 4096×2160 EDID modes verified NOT selected); crop = TV-side overscan. Owner confirmed symptom class.
2. **TV discovered + identified on LAN** — SSDP M-SEARCH (python, no curl): `[LG] webOS TV UP75003LF` at `192.168.1.10`, MAC `dc:03:98:77:85:f8`; SSAP 3000/3001 open; both legacy UPnP remote services SCPD-verified EMPTY placeholders. Also resolves the 2026-10-04 open question "is the TV network-connected" (yes).
3. **Hotel-mode root cause established** — bare-register SSAP tier 401s on everything user-facing; `getSystemInfo` → `"programMode": true`; research-confirmed meaning (hospitality provisioning) + per-connection permission doctrine (aiowebostv #728).
4. **SSAP pairing + manifest unlock** — owner pressed OK once; client-key saved (`~/.cache/lg-tv-ssap/client-key`, mode 600, never committed); lgtv2 `pairing.json` manifest register unlocks pointer socket + notifications (socketPath returned).
5. **THE FIX (owner-verified)** — two luna-smuggling writes via `createAlert`/`closeAlert` → `com.webos.settingsservice/setSystemSettings`: `{"justScan":"on","current_app":true}` then `{"arcPerApp":"original","allDirZoom*":"0"}`. Crop: both-sides ~3-5% → left edge perfect. Both writes returned `returnValue:true` end-to-end.
6. **Residual sliver triaged + closed** — ~0.5% right-edge cut; `allDirZoomHPosition:-4` probe inert → zoom path inactive → panel-mapping level; trade-off fixes rejected; owner accepted (library `[decision]` row).
7. **Dead-path eliminations documented** — DDC/CI (TV-side fail, DP-1 control proves tooling), direct `ssap://settings/*` writes (key rejection error verbatim), `currentSystemSettings` (404), synthetic buttons/pointer (frames deliver, TV ignores — 4 probes × owner confirmation), factorywin PIN route (blocked by same input gate).
8. **Tooling delivered** — `~/.cache/lg-tv-ssap/`: `tv-remote.sh`, `tv-pointer.sh`, `tv-set-setting.sh` (the fix re-run), `ssap-call.sh`, `register-manifest.sh`, `pairing.json`, client-key. Re-run recipe documented for hotel-mode power-cycle resets.
9. **Close-out artifacts** — `docs/agents/desktop.md` DP-2 bullet rewritten (full method + corrections); `docs/status/2026-11-07_05-30_…ssap-fix…md`; CHANGELOG entry; 2 queue rows + 3 library rows; `check-todo-system.sh` structure-clean and both session reports harvested (0 unharvested hits for `tv-overscan-ssap-fix`).

## b) PARTIALLY DONE

1. **Right-edge pixel perfection** — works: everything but ~0.5%. Open: nothing actionable below factory-menu level. Blocker: synthetic input hotel-blocked. Effort: L (owner + physical service remote) / accepted. 
2. **SSAP tooling hardening** — works: full fix/re-probe cycle. Open: cache-resident scripts pin a GC-able websocat store path; no cert verification (wss `--insecure`); no repo home. Effort: S-M (queued as TODO).
3. **TV identity in dnsblockd** — discovered + row queued; config entry itself not written (needs a deploy; deploy intentionally NOT fired this session — quiescence discipline).

## c) NOT STARTED

1. **Persistence test across TV power-cycle** — not attempted (needs the TV actually power-cycled; owner-gated). Priority: HIGH — determines whether the re-run recipe is load-bearing.
2. **Hotel-mode exit attempt** — not attempted (synthetic input blocked → needs the PHYSICAL remote; Settings-hold+`1105`/`9876` or installer remote; owner hands only). Priority: owner-decided.
3. **WoL wake for the TV** — MAC known, `CONTROL_WOL` in manifest; TV-side "Mobile TV On" setting state unknown. Priority: Low.
4. **getServiceList enumeration** — 15 services returned; only 6 probed. Priority: Low (fuel for future automation).
5. **DMS one-click "re-apply TV fix" affordance** — not started (idea; would make the re-run recipe owner-executable without me). Priority: Medium if persistence test fails.

## d) TOTALLY FUCKED UP

1. **The opening verdict was wrong.** I told the user "the one-press fix lives on your remote… niri/Wayland can't compensate." Two messages later, pushed by "are you sure?", I found THREE software paths and executed one end-to-end. Severity: high (cost the owner a false dead-end + a roundtrip). Root cause: I stopped at the first wall (no TV-side API knowledge) instead of exhausting alternatives; the answer required probing the LAN, which I hadn't done. Mitigation: the fix landed; lesson recorded in e.1.
2. **A false claim shipped to docs.** "amdgpu DC exposes no underscan connector attrs" — written into desktop.md from a sysfs absence (sysfs NEVER shows DRM props) plus memory. `drm_info` later showed the props exist on every connector. Severity: medium (documentation lies propagate). Corrected in the rewritten bullet. Root cause: inference from the wrong probe surface presented as fact — verify-external-claims violation.
3. **Heredoc mangling, repeat offense #3.** `tv-remote.sh` v1 written via bash heredoc; `'}'` → `'"}'` byte corruption; cost a bash-bisect/od debug cycle. The trap is documented TWICE in repo memory. Should have used the write tool first for a quote-dense script.
4. **Wrong wire format on the first owner-visible probe.** Sent RATIO as a raw text line; the socket protocol is `type:button\nname:X\n\n` key:value frames (lgtv2 `SpecializedSocket`). Cost one owner roundtrip ("nothing"). Root cause: fired a probe before source-verifying the protocol; I fetched lgtv2's source only afterwards.
5. **Abandoned probe left dirty.** `set-underscan.py` never completed (drmModeObjectGetProperties NULL as root — suspected libdrm version-handshake requirement); left in cache half-broken with no TODO. Not harmful, but it's litter with a misleading name.

## e) WHAT WE SHOULD IMPROVE

1. **"Cannot be done from software" requires an exhausted-alternatives table** — DDC/CI, LAN discovery, DRM props, service APIs each enumerated and disproven BEFORE the verdict. Impact: this session's biggest miss. Fix: make the exhaustion list part of the answer whenever claiming impossibility.
2. **Verify the wire protocol before the first probe that spends an owner roundtrip** — read the reference implementation FIRST (lgtv2/bscpylgtv source was public). Impact: 1 wasted roundtrip here; worse in higher-stakes loops.
3. **One-variable-at-a-time blind writes** — I batched `arcPerApp`+`allDirZoom*` in one write with no readback; effect attribution required the HPosition probe anyway. Impact: muddier causal story; cost an extra probe+roundtrip. Fix: under no-readback conditions, change one key per write.
4. **Write tool for any quote-dense script — no exceptions, even for "quick" scripts** (d.3). 
5. **Never infer kernel/driver state from sysfs absence** — DRM properties live behind ioctls (d.2).
6. **Finish or delete abandoned probes** at session end (d.5).

## f) Next tasks (ranked; 14 real items — padding to 50 with unrelated work would violate this report's scope)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Persistence test: power-cycle the TV, re-check edges; if reset, execute re-run recipe | High | S (owner-gated) | Verification |
| 2 | Promote `~/.cache/lg-tv-ssap` tooling into `scripts/` with a real websocat runtime input (queued ✓) | High | S | Cleanup |
| 3 | dnsblockd registry entry for `192.168.1.10` (queued ✓) | Medium | S | Feature |
| 4 | TOFU cert pinning for the tv-* scripts (lgtv2 `verifyCert` pattern) | Medium | S | Quality |
| 5 | DMS keybind/widget: one-click "re-apply TV aspect fix" (`tv-set-setting.sh` x2) | Medium | M | Feature |
| 6 | Owner decision: attempt hotel-mode exit via physical remote (`1105`/`9876`) | Medium | S (owner hands) | Decision |
| 7 | Enumerate the 15 `getServiceList` services; note useful ones (switchInput, power, WoL) | Low | S | Documentation |
| 8 | WoL wake wiring for the TV (needs TV-side "Mobile TV On" check first) | Low | S | Feature |
| 9 | Gatus/monitoring: cheap TV-presence check (SSDP or TCP 3001) → dashboard tile | Low | S | Monitoring |
| 10 | Delete or fix `set-underscan.py` (d.5) | Low | S | Cleanup |
| 11 | Fold the "impossibility requires exhaustion table" + "protocol-before-probe" lessons into session discipline (docs/agents/desktop.md already carries the concrete traps) | Low | S | Documentation |
| 12 | Check TV firmware-update availability (LG hotel firmware may change/reset behavior) | Low | S | Watch |
| 13 | Probe whether the TV's `getServiceList` exposes power control → scripted standby for the persistence test (feeds #1) | Low | S | Feature |
| 14 | Right-slit reopen condition documented in the `[decision]` row — nothing further until a factory-menu path opens | — | — | Closed |

## g) Questions I cannot answer myself (3)

1. **Is this TV second-hand from a hotel/business install — and do you WANT hotel mode gone?** `programMode:true` + every control locked says hospitality firmware; exiting it needs your physical remote (Settings-hold + `1105` or `9876`, or an installer remote — synthetic input is blocked, so I cannot attempt it for you). I cannot know the TV's provenance or your preference.
2. **May I power-cycle / SSAP-standby the TV now (or when you next turn it off) to test whether hotel enforcement resets the fix?** This decides whether the re-run recipe is a nightly necessity or just insurance. The TV turning off mid-evening is your call, not mine.
3. **Outside the crop, have you noticed other hotel-mode symptoms on this TV** (volume ceiling, locked picture menus, forced startup input/channel)? The same tooling can chase several of them — but only if you tell me what you've seen; I have no baseline for how this TV behaved before today.
