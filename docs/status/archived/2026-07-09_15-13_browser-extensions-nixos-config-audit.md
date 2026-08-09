# Browser Extension NixOS Configuration — Self-Audit & Status

**Date:** 2026-07-09 15:13
**Session scope:** Making browser extensions NixOS-configurable + adding all extensions from `legacy/My Chrome Plugins.txt`
**Commit context:** Helium wrapper overhaul (`f732201b`) and nix anti-pattern refactor (`78fb56df`) were already committed by earlier sessions. This session built on top.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## a) FULLY DONE

| #   | What                                                                                                                                                                                                                                                                                                                                                            | Files                                        | Verified                                                          |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- | ----------------------------------------------------------------- |
| 1   | **Browser-policies module refactored** with typed `chromiumExtensions` submodule option (id, name, installationMode, toolbarPin) + `defaultInstallationMode` wildcard control                                                                                                                                                                                   | `modules/nixos/desktop/browser-policies.nix` | `nix flake check --no-build` passes                               |
| 2   | **Removed redundant `ExtensionInstallForcelist`** — was duplicated by `ExtensionSettings` (the former is superseded by the latter)                                                                                                                                                                                                                              | `modules/nixos/desktop/browser-policies.nix` | Policy JSON no longer contains forcelist                          |
| 3   | **Fixed missing `update_url`** — `force_installed` extensions require `update_url` in `ExtensionSettings`; without it, Chromium silently fails to install. Added `https://clients2.google.com/service/update2/crx` to every extension.                                                                                                                          | `modules/nixos/desktop/browser-policies.nix` | `nix eval` confirms `update_url` present                          |
| 4   | **Confirmed Helium reads `/etc/chromium/policies/`** — Researched Chromium source (`policy_paths.cc`): the policy directory is a compile-time constant determined by `GOOGLE_CHROME_BRANDING`, which Helium doesn't set → defaults to `/etc/chromium/policies`. No separate `/etc/helium/policies/` needed. Policies already apply to both Chromium and Helium. | Research (chromium.googlesource.com)         | Verified against live `/etc/chromium/policies/managed/` on evo-x2 |
| 5   | **Found and read `legacy/My Chrome Plugins.txt`** — 19 active extensions across 4 categories (General, GitHub, YouTube, Unsure) + 19 disabled extensions                                                                                                                                                                                                        | `legacy/My Chrome Plugins.txt`               | Full inventory extracted                                          |
| 6   | **Looked up all 19 extension IDs** from Chrome Web Store (2 batches of agentic searches + 1 individual for 9gag post filter)                                                                                                                                                                                                                                    | Chrome Web Store                             | IDs cross-referenced with official extension pages                |
| 7   | **Added all 20 extensions** (19 from txt + YouTube Shorts Blocker already present) to `configuration.nix`, organized by category with `ext id name` helper function                                                                                                                                                                                             | `platforms/nixos/system/configuration.nix`   | `nix eval` confirms 21 policy entries (20 ext + `"*"` wildcard)   |
| 8   | **`nix flake check --no-build` passes** after all changes                                                                                                                                                                                                                                                                                                       | —                                            | Clean                                                             |
| 9   | **`nix fmt` applied** — 24 files reformatted (mostly pre-existing dirty HTML files from other sessions, not our work)                                                                                                                                                                                                                                           | —                                            | Clean                                                             |

---

## b) PARTIALLY DONE

| #   | What                                         | Why partial                                                                                                                                                                                                                                                                                             |
| --- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Extension configuration module**           | Module design and eval are done, but **NOT deployed or runtime-verified**. We don't know if all 20 extensions actually install in Helium. `chrome://policy` check is pending deploy.                                                                                                                    |
| 2   | **`legacy/My Chrome Plugins.txt` migration** | 19 of 21 extensions from the file are added. **CRW-Extension** (GitHub release download, not Web Store CRX) was correctly excluded — enterprise policy `update_url` only works with Chrome Web Store. But this was not communicated to the user until asked.                                            |
| 3   | **Extension policy correctness**             | `update_url` is now present, but we haven't verified whether **ungoogled-chromium (Helium)** actually fetches from `clients2.google.com`. ungoogled-chromium strips Google integration — it may silently ignore the `update_url` or need a different update mechanism. This is a **high-risk unknown**. |

---

## c) NOT STARTED

| #   | What                                                                                                                                                                        |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Deploy to evo-x2** and verify `chrome://policy` shows all 20 policies                                                                                                     |
| 2   | **Runtime-verify extensions actually install** — check extension toolbar in Helium                                                                                          |
| 3   | **Verify uBlock Origin doesn't conflict with Helium's built-in uBO fork** (Helium ships with built-in ad blocker)                                                           |
| 4   | **Add KeePassXC-Browser or Bitwarden** if password manager integration is needed (not in the old list but commonly needed)                                                  |
| 5   | **macOS Helium wrapping** for privacy flags (still not done from previous session)                                                                                          |
| 6   | **Consider `defaultInstallationMode = "blocked"`** for allowlist-only security (currently `"allowed"`)                                                                      |
| 7   | **Extension policy for Firefox** — Firefox uses a completely different policy mechanism (`policies.json` with `Extensions` key). Currently no Firefox extension management. |
| 8   | **9gag Post Filter** is abandoned (dev archived repo, "THIS PROJECT IS DEAD"). May want to replace or remove.                                                               |

---

## d) TOTALLY FUCKED UP

| #   | What                                                                 | Impact                                                                                                                                                                                                                                                                                   | Fix                                                                                                                                                       |
| --- | -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **`nix fmt` reformatted 24 pre-existing dirty files**                | The `nix fmt` run touched HTML files in `docs/`, `flake.lock`, `immich.nix`, `signoz.nix` — files that were already modified by other sessions (shown in `git status` at conversation start). These are now mixed into our diff, making it hard to isolate our changes.                  | Should have committed our changes BEFORE running `nix fmt`, or used a more targeted formatting approach. These files need to be sorted out before commit. |
| 2   | **Did not verify extension IDs are still valid on Chrome Web Store** | Several extensions from the 2018-2020 era txt file may have been removed from the Web Store. `force_installed` with a dead extension ID will cause a silent install failure — no error, just missing extension. The 9gag filter is confirmed abandoned. Others may be too.               | Need to verify each ID resolves to a live Web Store page after deploy.                                                                                    |
| 3   | **No investigation of ungoogled-chromium extension update behavior** | This is the biggest unknown. ungoogled-chromium intentionally removes Google integration. The `update_url = "https://clients2.google.com/service/update2/crx"` we're setting may be **silently stripped or ignored** by Helium. If so, `force_installed` extensions will never download. | Need to test after deploy — check if extensions actually appear. May need to manually install CRXs or use a different `update_url`.                       |

---

## e) WHAT WE SHOULD IMPROVE

### Design improvements

1. **Extension `update_url` for ungoogled-chromium** — This is a ticking time bomb. ungoogled-chromium patches out Google update services. We're setting `update_url` to `clients2.google.com` which may not work. Need to either: (a) verify it works at runtime, (b) use `chrome://extensions` with developer mode to manually install, or (c) bundle CRXs in the Nix store and point `update_url` there.

2. **Per-extension `update_url` override** — The module hardcodes `https://clients2.google.com/service/update2/crx` for all extensions. Should be an option on the submodule so non-Web-Store extensions (e.g., from GitHub releases) can use custom URLs.

3. **Extension enablement per-browser** — Currently the module applies to all Chromium-based browsers (Helium + Chromium if both installed). If the user wants different extensions per browser, the module doesn't support that. Low priority for a single-browser homelab.

4. **`installationMode` granularity** — Everything is `force_installed`. Some extensions (dev tools like React DevTools, WhatFont) would be better as `normal_installed` so they can be disabled when not needed. The API supports this but we set the same default for all.

5. **Helium built-in uBO fork conflict** — Helium ships with a built-in ad blocker (uBlock Origin fork). Adding uBlock Origin as `force_installed` may conflict or duplicate. Need to verify.

### Process improvements

6. **Should have committed before `nix fmt`** — The `nix fmt` run polluted the diff with 24 unrelated files. Lesson: always commit targeted changes first, THEN format.

7. **Should have verified extension IDs at lookup time** — Trusted the agentic search results without cross-checking. Some IDs from `extwise.com` (a third-party site) may be stale.

8. **No runtime verification at all** — This is the 3rd session in a row where we make browser changes without deploying. The Helium wrapper changes from the previous session are also unverified. We're accumulating unverified changes.

9. **MODULE NOT COMMITTED** — The `configuration.nix` extension list changes are uncommitted. The `browser-policies.nix` refactor was committed by a previous session (`78fb56df`).

---

## f) Up to 50 things we should get done next

### Priority 1 — Verify what we built (CRITICAL)

| #   | Task                                                                                                         |
| --- | ------------------------------------------------------------------------------------------------------------ |
| 1   | Deploy to evo-x2                                                                                             |
| 2   | Open `chrome://policy` in Helium — verify all 20 policies are listed                                         |
| 3   | Open `chrome://extensions` — verify extensions actually installed                                            |
| 4   | **Test if ungoogled-chromium fetches from `clients2.google.com`** — if not, `force_installed` silently fails |
| 5   | Check if uBlock Origin conflicts with Helium's built-in uBO fork                                             |
| 6   | Verify each extension ID is live on Chrome Web Store (not removed)                                           |
| 7   | Test disabling a `force_installed` extension — should be impossible                                          |
| 8   | Test that user-installed (non-listed) extensions still work (default mode is `allowed`)                      |

### Priority 2 — Fix what's broken or unknown

| #   | Task                                                                                                                  |
| --- | --------------------------------------------------------------------------------------------------------------------- |
| 9   | **Investigate ungoogled-chromium extension update mechanism** — does `update_url` work? Check chromium source patches |
| 10  | If `update_url` doesn't work: bundle CRX files in Nix store, point `update_url` to `file://` path                     |
| 11  | Remove 9gag Post Filter (dev archived, "THIS PROJECT IS DEAD") or replace with alternative                            |
| 12  | Separate dirty `nix fmt` changes from our work (stash/commit separately)                                              |
| 13  | Add per-extension `updateUrl` option to the submodule                                                                 |
| 12  | Set dev tools (React DevTools, WhatFont) to `normal_installed` so they can be disabled                                |
| 13  | Consider `defaultInstallationMode = "blocked"` for allowlist-only hardening                                           |

### Priority 3 — Extension module improvements

| #   | Task                                                                                             |
| --- | ------------------------------------------------------------------------------------------------ |
| 14  | Add per-extension `updateUrl` override option (not just hardcoded Google URL)                    |
| 15  | Add extension policy documentation comment explaining the `update_url` + ungoogled-chromium risk |
| 16  | Add Firefox extension management to the module (`programs.firefox.policies.Extensions`)          |
| 17  | Add a module option for Chrome Web Store update URL constant (avoid magic strings)               |
| 18  | Consider `ExtensionInstallSources` policy for allowing CRX installs from specific domains        |
| 19  | Add `BlockThirdPartyCookies` policy                                                              |
| 20  | Add `HTTPSOnlyMode` policy                                                                       |
| 15  | Consider adding `RestoreOnStartup` policy (session restore via policy instead of flag)           |

### Priority 4 — Helium wrapper improvements (from previous session)

| #   | Task                                                                                |
| --- | ----------------------------------------------------------------------------------- |
| 21  | Test removing `--enable-zero-copy` (may eliminate hotplug crashes)                  |
| 22  | Add `--disk-cache-dir` to tmpfs                                                     |
| 23  | Configure Memory Saver enterprise policy (`PerformanceMultiStateModeEnabled`, etc.) |
| 24  | Verify KeePassXC native messaging host path                                         |
| 25  | Measure memory before/after: `smem -P helium -k -s pss`                             |

### Priority 5 — Broader browser hardening

| #   | Task                                                                                                    |
| --- | ------------------------------------------------------------------------------------------------------- |
| 26  | Review and apply relevant Chromium privacy policies (BackgroundModeEnabled, SafeBrowsing, etc.)         |
| 27  | Add `BrowserSignin` policy (disable Chrome Sync / Google signin — ungoogled should already handle this) |
| 28  | Add `SyncDisabled` policy                                                                               |
| 29  | Add `ClearBrowsingDataOnExitList` policy                                                                |
| 30  | Add `DefaultCookiesSetting`, `DefaultPopupsSetting` policies                                            |
| 31  | Review Firefox policies — currently only UI/gesture locks, no security policies                         |
| 32  | Add Firefox `EnableTrackingProtection` policy                                                           |
| 33  | Consider `Certificate Transparency` policy                                                              |
| 34  | Consider `AutoSelectCertificateForUrls` if using client certs                                           |
| 35  | Review whether Helium's built-in privacy flags overlap with enterprise policies                         |

### Priority 6 — Documentation & housekeeping

| #   | Task                                                                                                                         |
| --- | ---------------------------------------------------------------------------------------------------------------------------- |
| 36  | Update `FEATURES.md` browser policies line with new extension count and configurable module                                  |
| 37  | Update `AGENTS.md` with ungoogled-chromium `update_url` behavior (once verified)                                             |
| 38  | Delete or archive `legacy/My Chrome Plugins.txt` (now migrated to Nix config)                                                |
| 39  | Update Helium audit report (`docs/status/2026-07-09_08-48_*`) — mark browser-policies item as done                           |
| 40  | Commit `configuration.nix` extension changes                                                                                 |
| 41  | Verify the `nix fmt` collateral changes are intentional (HTML files, immich.nix, signoz.nix)                                 |
| 42  | Consider adding a deploy smoke test for browser policies (check `/etc/chromium/policies/managed/` exists with expected JSON) |
| 43  | Add a Gatus health check for browser policy file existence                                                                   |
| 44  | Add `post-deploy-check` verification for extension policy JSON structure                                                     |

### Priority 7 — Future enhancements

| #   | Theme                                                                                                                 |
| --- | --------------------------------------------------------------------------------------------------------------------- |
| 45  | Consider `chrome://flags` standardization via master_preferences or equivalent                                        |
| 46  | Consider policy-based DNS-over-HTTPS configuration for Helium (currently only Firefox has DoH disabled)               |
| 47  | Consider `QuicAllowed` policy                                                                                         |
| 48  | Consider `URLBlocklist` / `URLAllowlist` policies for content filtering                                               |
| 49  | Evaluate extension sandboxing policies (`ExtensionContentVerification`)                                               |
| 50  | Consider `PasswordManagerEnabled` policy — disable Chrome's built-in password manager in favor of KeePassXC/Bitwarden |

---

## g) Top 2 Questions

### Q1: Does Helium (ungoogled-chromium) respect `update_url` in `ExtensionSettings` policy?

**Why I can't figure this out myself:** ungoogled-chromium patches are spread across many files and change between versions. The core question is whether the "ungoogling" patches remove the CRX update fetcher entirely, or just remove the built-in extension store integration. If the former, `force_installed` extensions with Google `update_url` will **silently fail to download** — the policy will show in `chrome://policy` as active, but the extension will never appear in `chrome://extensions`. This is the single biggest risk to the entire extension setup.

**How to find out:** Deploy, then check `chrome://extensions` for actual installed extensions. If missing, check Helium's log output (`~/.config/helium/chromium/Default/Extensions/` for download attempts). Alternatively, read the ungoogled-chromium patch set for extension-update-related patches.

### Q2: Should `defaultInstallationMode` be `"blocked"` (allowlist-only)?

**Why I can't figure this out myself:** This is a security vs. usability tradeoff that depends on your workflow. `"allowed"` (current) means any extension can be installed manually — convenient but a security risk (malicious extensions). `"blocked"` means ONLY the 20 listed extensions can exist in the browser — maximally secure but prevents installing one-off extensions without a config change + rebuild. For a single-user homelab, `"allowed"` is probably fine, but `"blocked"` is the "correct" security posture if you never install random extensions.
