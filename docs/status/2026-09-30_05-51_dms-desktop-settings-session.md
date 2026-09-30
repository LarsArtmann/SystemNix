# DMS Desktop Settings Session — Status Report

**Date:** 2026-09-30 05:51 · **Scope:** this session only — DMS (DankMaterialShell) desktop settings configuration in `platforms/nixos/desktop/quickshell.nix` · **Host:** evo-x2 (changes repo-only, NOT deployed)

**Session summary:** 13 DMS settings + 1 package patch + 1 pre-existing dead-option fix, all in one file. Every settings key was verified against the pinned DMS source (`quickshell/Common/settings/SettingsSpec.js` and consumers) before writing — zero guessed keys. The patched dms-shell package was built and its patch verified in the built output. Nothing is live yet.

---

## a) FULLY DONE (repo-side, verified)

| #  | Change                              | Key / mechanism                                                                                                                                                                                                                                        | Verification                                                                                                                                                                                                                                                      |
| -- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | Notification timeout progressbar    | `notificationShowTimeoutBar = true`                                                                                                                                                                                                                    | SettingsSpec.js:522 (def `false`)                                                                                                                                                                                                                                 |
| 2  | Notification history retention 30d  | `notificationHistoryMaxAgeDays = 30`                                                                                                                                                                                                                   | SettingsSpec.js:529 (def `7`)                                                                                                                                                                                                                                     |
| 3  | Max notifications kept 200          | `notificationHistoryMaxCount = 200`                                                                                                                                                                                                                    | SettingsSpec.js:528 (def `50`)                                                                                                                                                                                                                                    |
| 4  | Clock shows seconds                 | `showSeconds = true`                                                                                                                                                                                                                                   | SettingsSpec.js:85 (def `false`)                                                                                                                                                                                                                                  |
| 5  | Pad hours                           | `padHours12Hour = true`                                                                                                                                                                                                                                | UI "Pad Hours" toggle → Clock.qml:214 (def `false`)                                                                                                                                                                                                               |
| 6  | Date format "Day Month Date"        | `clockDateFormat = "ddd MMM d"`                                                                                                                                                                                                                        | TimeWeatherTab.qml:247 label→format mapping (def `""` → "ddd d")                                                                                                                                                                                                  |
| 7  | Weather auto location               | `useAutoLocation = true`                                                                                                                                                                                                                               | SettingsSpec.js:313; geoclue→IP fallback verified WeatherService.qml:573-592 — no extra service needed                                                                                                                                                            |
| 8  | OSD "Always Show Percentage"        | `osdAlwaysShowValue = true`                                                                                                                                                                                                                            | OSDTab.qml:78 (def `false`)                                                                                                                                                                                                                                       |
| 9  | Font scaling 150%                   | `fontScale = 1.5`                                                                                                                                                                                                                                      | SettingsSpec.js:340 (def `1.0`) — see §b.2: surface ambiguity                                                                                                                                                                                                     |
| 10 | Workspace index numbers in bar      | `showWorkspaceIndex = true`                                                                                                                                                                                                                            | SettingsSpec.js:186 (def `false`)                                                                                                                                                                                                                                 |
| 11 | Workspace apps, max 5               | `showWorkspaceApps = true` + `maxWorkspaceIcons = 5`                                                                                                                                                                                                   | SettingsSpec.js:190/192 (defs `false`/`3`)                                                                                                                                                                                                                        |
| 12 | Clipboard history 100,000           | `clipboardSettings.maxHistory = 100000` → `clsettings.json`                                                                                                                                                                                            | NOT a settings.json key — Go core Config (`core/internal/clipboard/types.go:16-35`, def 100); HM module renders it (home.nix:114-116); rendered JSON **built and cat'd**: `{"maxHistory": 100000}`; missing keys keep Go defaults (MaxEntrySize 5M, MaxPinned 25) |
| 13 | Weather "pop" in dark mode          | package `overrideAttrs` `postInstall` sed: bar `Weather.qml` icon + temp recolored `Theme.widgetTextColor/widgetIconColor` → `Theme.primary`                                                                                                           | **Patched package built** (`i59rkaqi…-dms-shell-1.6.2`); built output verified: 4× `color: Theme.primary`, 0 muted tokens left. Fail-loud `test -f` + `grep -q` gates in the build                                                                                |
| 14 | Dead-option fix (pre-existing debt) | `programs.systemnix-quickshell.package` was declared but **never consumed anywhere** — upstream module used its own default package, so the option (and any override of it) was inert. Now wired: `programs.dank-material-shell.package = cfg.package` | grep: zero consumers before; eval resolves the patched drv through the HM path                                                                                                                                                                                    |
| 15 | Text rendering options explained    | —                                                                                                                                                                                                                                                      | enums source-verified: `TextRenderType { Qt=0, Native=1, Curve=2 }` (default **Qt** distance-field), `TextRenderQuality { Default…VeryHigh }`                                                                                                                     |

**Commits:** auto-commit daemon picked up every edit batch (`3ea37636`, `6f3c579f`, `9fb816e2` — heuristic messages, per doctrine). Tree clean at report time.

## b) PARTIALLY DONE

1. **NOTHING IS DEPLOYED.** All 13 settings + the patch sit in the repo; the live system still runs the old generation. Activation requires `nix run .#deploy` (human-owned, sudo-gated). Every "done" above is done at eval/build level only.
2. **`fontScale` surface ambiguity.** DMS has THREE scale knobs: global `fontScale` (what I set — scales the whole DMS UI), bar-specific `dankBarFontScale` (SettingsSpec line 725, def 1.0), and per-bar `barConfig.fontScale`. The ask "set font scaling to 150%" was ambiguous; I chose the global one. Risk: at 150% global, bar text may crowd/clip the fixed bar thickness. Needs owner confirmation or post-deploy eyeball.
3. **Gate coverage thinner than repo doctrine.** Only `nix-instantiate --parse` per edit + targeted option evals (HM attr path) + the one package build were run. A full `nix flake check --no-build` (pre-commit/CI gate, eval-time guard army) was NOT run this session.
4. **Patched package verified standalone, not in the toplevel.** The evo-x2 toplevel closure containing the patched dms-shell was never built as a whole.

## c) NOT STARTED

1. Deploy + post-deploy smoke of everything in §a (settings.json keys live, clipboard cap via `dms clipboard config get`, weather city resolution, accent-colored weather widget, OSD %, clock format, workspace indices/5 icons).
2. Upstream DMS feature request: per-widget accent color option (would retire the Weather.qml sed patch permanently). Not checked whether an issue exists.
3. AGENTS.md DMS section update with this session's durable lessons (settings.json vs clsettings.json surfaces, key-verify-against-SettingsSpec discipline, `cfg.package` wiring).
4. Text render type switch (explained + offered; owner decision pending — currently default Qt).

## d) TOTALLY FUCKED UP (sloppy, honestly)

Nothing landed broken — but four process screw-ups:

1. **Lost a background build shell.** Launched the patched-package build in the background, then GUESSED its shell ID (`b0f75f36`) for `job_output` → "background shell not found". Wasted a round trip. Should have used the tool-returned ID.
2. **Unexplained nix anomaly worked around, not root-caused.** `nix build <drv-path> --no-link --print-out-paths` twice returned rc=0 echoing the DRV path while the output path stayed unrealized (`nix path-info`: "not valid"). Worked around with `nix-store -r` (which built fine). Root cause undiagnosed — possibly nix 2.34 treating a bare `.drv` installable differently than expected. Left as-is; flagged in §f.
3. **Wrong eval attr path on first try.** Queried NixOS-level `config.programs.systemnix-quickshell…` before realizing the module is imported through home-manager (home.nix:157) — the option lives at `home-manager.users.lars.programs…`. Self-corrected in one step, but the flailing round (three malformed store-path/jq probes before that) was avoidable by checking WHERE the module is imported first.
4. **Source-verification rigor gap.** Key verification grepped ONE of THREE identical-looking candidate DMS store source dirs without confirming it matches the flake.lock-pinned rev. All three dirs contained all verified keys, so the conclusions hold — but "all three agree" is luck, not method. The locked-rev confirmation is one `nix flake metadata` away.

## e) WHAT WE SHOULD IMPROVE

1. **Run the repo's own gates after multi-edit sessions** — `nix flake check --no-build` is the documented minimum; parse-only is the weakest signal this repo offers (AGENTS.md: "Test first").
2. **Ask-on-ambiguity for settings with sibling knobs.** fontScale/dankBarFontScope, clockFormat/padHours interplay — a 10-second question beats a wrong-surface deploy. (Mitigated: flagged in §g.)
3. **A typo-proofing eval guard for DMS settings.** Every settings.json key we declare should be asserted to exist in the pinned source's `SettingsSpec.js` — the same class of guard the repo uses for gatus patterns and ports. Cheap, catches the `email_states` fixture-trap class (a plausible-but-wrong key silently no-ops; DMS ignores unknown keys).
4. **The Weather.qml sed patch is version-coupled friction.** It fails LOUDLY on any DMS stable bump that refactors those color tokens (by design), but each bump then needs a patch refresh. The durable fix is upstream (per-widget accent setting); the patch comment already carries the drop-condition.
5. **DMS config-surface map belongs in AGENTS.md.** This session burned several greps learning: `settings.json` (SettingsSpec keys, HM `settings` option), `clsettings.json` (daemon config: clipboard caps — HM `clipboardSettings` option), `plugin_settings.json` (plugins). Future sessions shouldn't re-derive that.
6. **Auto-location endpoint unvetted.** `useAutoLocation` falls back to IP geolocation via an external HTTP service whose hostname I did NOT identify. If dnsblockd's blocklists classify it as telemetry (the `monitoring.googleapis.com` phantom-200 class), weather silently degrades to "--". Post-deploy check: a real city name resolves.
7. **Clipboard 100k×30d growth watch.** 100,000 entries × 30d retention against DMS's `MemoryMax=4G` and a history UI that loads entries — the bolt DB lives under `~/.local/share`; unbounded-feeling cap chosen by owner request, worth one look after a few weeks.
8. **Settings split-brain expectation-setting.** The live `settings.json` may be a DMS-expanded real file (~530 keys vs our ~50 declarative). On deploy, any UI-made tweaks to keys we now declare will snap back to declarative values (deploy.sh backs up the real file first — AGENTS.md split-brain bullet).

## f) Next things (session-scoped; not padded to 50)

**Owner-gated (do first):**

1. `nix run .#deploy` — activate everything
2. Post-deploy: `jq` the live settings.json — all 13 new keys present
3. Post-deploy: `dms clipboard config get` → maxHistory 100000
4. Post-deploy: weather resolves a real city (auto-location through dnsblockd works)
5. Post-deploy: weather widget renders in accent color; OSD shows %; clock shows seconds/padded/"Wed Sep 30"; workspace indices + ≤5 app icons
6. Eyeball fontScale 1.5: if bar clips/crowds → decide global vs `dankBarFontScale` (§g.1)
7. Decide textRenderType: Native (crispest) vs Curve (crisp at any scale) vs keep Qt (§g.2)
8. Confirm weather accent = Theme.primary is the intended "pop" (§g.3)

**Agent-actionable:**
9. Run `nix flake check --no-build` on the tree before/with the deploy
10. Update AGENTS.md DMS section (config-surface map + `cfg.package` wiring + key-verification discipline)
11. Build the eval guard: declared DMS `settings` keys ⊆ pinned SettingsSpec.js keys (typo-proofing)
12. Identify the DMS IP-geo endpoint in source; check dnsblockd classification of that hostname; whitelist if blocked
13. Check whether geoclue is enabled on evo-x2 (preciser auto-location than IP)
14. Diagnose or document the `nix build <drv>` rc=0-without-building anomaly (nix 2.34)
15. Confirm the flake.lock-pinned DMS rev ↔ the store source used for key verification (close §d.4)
16. File the upstream DMS per-widget-accent feature request (after verify-before-filing pass)
17. If "pop" should extend to the dash weather tab (WeatherTab/ForecastCard), scope a second patch
18. Watch clipboard history DB size after a few weeks at 100k cap (bolt DB under `~/.local/share`)
19. Snapshot the live expanded settings.json pre-deploy and diff post-deploy (deploy.sh backs up — verify it did)
20. Sweep for other dead module options (`cfg.package` was dead — are there siblings?)

## g) Questions I cannot figure out myself

1. **Font scaling surface:** did you mean the WHOLE DMS UI at 150% (`fontScale` — what I set: bar, popups, modals, dash all scale), or ONLY the top bar text (`dankBarFontScale`, currently 1.0)? Both exist; they compose.
2. **Text render type:** keep the default **Qt** distance-field (smooth scaling, slightly soft at small sizes), or switch to **Native** (FreeType — crispest static text) or **Curve** (crisp at any zoom, best match for 150%)? I recommended Native or Curve; your call.
3. **Weather accent color:** `Theme.primary` (the theme accent — mauve/purple family) is what the patch applies. Is that the "pop" you want, or a semantic weather color (e.g. warm amber for temp) — the latter is a one-line change in the same patch?

---

### Self-harvest record (AGENTS.md TODO doctrine)

Harvested at authoring time: agent-actionable §f.10-12 → `TODO_LIST.md` queue + `docs/todo/desktop.md` library entries; owner-gated §f.1-8 stay library-only (`[blocked:user]`/`[decision]`) — deploy, render-type and color choices are owner actions. Items 13-20 remain report-only (lower priority, no queue row yet) — deliberately not harvested to avoid queue inflation; they route on the next docs pass.

_Report format: user-requested `.md` (skill default is styled HTML — override honored per skill spec)._
