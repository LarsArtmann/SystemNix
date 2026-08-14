# TV Display Scale + Resolution — Comprehensive Status Report

**Date:** 2026-08-13 15:09 CEST
**Session Goal:** Set TV 'Display' (DP-2, LG Electronics LG TV SSCR2) scale from 1 to 2 and ensure correct resolution
**Outcome:** Runtime applied successfully; declarative config committed; full deploy blocked by pre-existing issues

---

## a) FULLY DONE

### 1. Niri `outputs` block added to declarative config
**File:** `platforms/nixos/desktop/niri-wrapped.nix:127-152`

SystemNix previously had NO `programs.niri.settings.outputs` block — niri auto-detected all displays with EDID defaults. Added explicit output configuration for both connected displays:

| Output | Connector | Display Name | Mode | Scale | Position |
|--------|-----------|-------------|------|-------|----------|
| DP-1 | LG HDR 4K monitor | `LG Electronics LG HDR 4K 510NTNHPZ455` | 3840×2160 @ 59.997Hz | 1.25 | (0, 0) |
| DP-2 | LG TV | `LG Electronics LG TV SSCR2 0x01010101` | 3840×2160 @ 30.0Hz | 2.0 | (3072, 0) |

The niri-flake `outputs` option is an `attrsOf submodule` where the key IS the connector name (DP-1, DP-2). Sub-options: `mode` (width, height, refresh), `scale` (float), `position` (x, y), `enable`, `transform`, `variable-refresh-rate`, `focus-at-startup`.

### 2. Runtime change applied and verified
Applied immediately via `niri msg output` commands (bypassing the broken deploy pipeline):

```
niri msg output DP-2 scale 2
niri msg output DP-2 mode 3840x2160@30.000
niri msg output DP-2 position set 3072 0
niri msg output DP-1 position set 0 0   # fix position that shifted
```

**Verified output (live):**
- DP-1: 3840×2160 @ 59.997Hz, Scale 1.25, Logical 3072×1728, Position (0,0)
- DP-2: 3840×2160 @ 30.000Hz, Scale 2, Logical 1920×1080, Position (3072,0)

### 3. Upstream cqrs-lint vendorHash fixed
**File:** `/home/lars/projects/go-cqrs-lite/flake.nix:749`

The `cqrs-lint` package in the upstream `go-cqrs-lite` repo had a stale `vendorHash` that caused `buildGoModule` to fail with a fixed-output hash mismatch. This was blocking the SystemNix deploy.

- Old: `sha256-F6j9fmzX0Gkdyw7LYl956rj93YqY9EUWSUabhl2YWjU=`
- New: `sha256-teupozp6qKjdq/GYEBeHHzFAYYV83/HqGohq3/jPm1Q=`
- Committed as `a6300fd20` and pushed to `origin/master`
- SystemNix `flake.lock` updated: `go-cqrs-lite` input now points to `a6300fd206dddc218a2263005ccac4457168b5b0`

### 4. Config evaluation verified
- `nix eval .#nixosConfigurations.evo-x2.config.home-manager.users.lars.programs.niri.settings.outputs` — passes, correct values
- `nix eval .#nixosConfigurations.evo-x2.config.home-manager.users.lars.programs.niri.settings.outputs."DP-2".scale` — returns `2`
- `nix flake check --no-build` — all checks passed (after fixing the vendorHash)

### 5. Disk space freed
- `nix-collect-garbage --delete-older-than 7d` freed 11.3 GiB (95% → 94%)
- `nix-collect-garbage --delete-older-than 1d` freed 22.7 GiB (96% → 94%)
- Total freed: ~34 GiB across two GC runs
- Root filesystem: 631G used / 74G available / 90% (post-GC, at time of report)

### 6. Auto-commit captured changes
The auto-git daemon committed my `niri-wrapped.nix` and `flake.lock` changes as part of commit `cfeee94d` ("feat(audio): pin HDMI output to LG TV via WirePlumber profile priority") — a commit that also bundled audio routing changes from another concurrent session.

---

## b) PARTIALLY DONE

### 1. Full NixOS deploy — BLOCKED by pre-existing issues
The `nix run .#deploy` command could not complete. The niri config change is in the declarative Nix config (committed) and applied at runtime, but the full system activation did not happen. The runtime `niri msg output` changes are **temporary** — they will be lost if niri restarts. The declarative config in `niri-wrapped.nix` will make them permanent once a deploy succeeds.

**Blockers encountered (all pre-existing, none caused by my change):**
1. Root filesystem at 95-96% (deploy hard-fails at >=95%)
2. `cqrs-lint` vendorHash mismatch — FIXED in this session
3. HaGeZi blocklist 404 — `HaGeZi-dga7-raw` fetch returns 404 from all mirrors, aborting the build ~~— resolved at `88c594cc` (GitLab mirror)~~
4. Failed systemd services (browser-history-agent, nix-build-cleanup) ~~— both healthy/retired since (`c39b6d50`)~~

### 2. AGENTS.md not updated
The niri `outputs` configuration pattern (connector name as key, mode/scale/position structure) should be documented in the Desktop section of AGENTS.md. The fact that SystemNix previously had NO output configuration and relied on niri auto-detection is noteworthy.

### 3. Boot.nix has uncommitted changes (NOT mine)
`platforms/nixos/system/boot.nix` has uncommitted changes from another session — ZRAM config changed from 17% to 30% memoryPercent and swappiness documentation updated. This is NOT my change; I did not touch it. ~~Committed and deployed at `0bd8a272`.~~

---

## c) NOT STARTED

### 1. HaGeZi blocklist 404 investigation
The `HaGeZi-dga7-raw` derivation fails with 404 from all mirrors. This blocks ALL deploys. Not investigated — likely an upstream URL change or temporary outage. ~~Done at `88c594cc` — root cause was GitHub's automated fraud detection locking `hagezi/dns-blocklists`; all lists now track the GitLab mirror with SRI-hash pinning~~

### 2. Flake.lock go-cqrs-lite deduplication
The flake.lock has 5 duplicate `go-cqrs-lite` entries (go-cqrs-lite, go-cqrs-lite_2 through go-cqrs-lite_5), each pointing to different revisions. This is a flake input hygiene issue that should be cleaned up.

### 3. Niri output persistence verification
Not verified whether the declarative `outputs` config in `niri-wrapped.nix` will correctly override niri's auto-detection on next niri restart. The config evaluates correctly but has never been deployed + restarted to confirm. ~~Done (moot) — deployed at `0bd8a272`; config survived the many niri restarts since (see AGENTS.md restart history)~~

### 4. VRR (Variable Refresh Rate) for DP-2
The TV supports VRR but it's not enabled. `variable-refresh-rate` is not set in the outputs config (defaults to `false`).

### 5. Focus-at-startup
Neither output has `focus-at-startup` set. DP-1 (the monitor) should likely be the focused output on startup.

---

## d) TOTALLY FUCKED UP

### 1. The entire deploy pipeline is broken
**This is the most critical issue.** `nix run .#deploy` cannot complete due to a HaGeZi blocklist 404 error. This means NO NixOS configuration changes can be deployed to evo-x2. Every declarative change is stuck in limbo until this is fixed. The runtime `niri msg output` workaround is a band-aid, not a solution. ~~Resolved at `88c594cc`; deploys succeeding since.~~

### 2. Disk space is chronically critical
Root filesystem at 90-94% on a 723GB drive. The deploy hard-fails at >=95%. Two GC runs freed 34 GiB but the system is already back at 90%. This is a systemic problem — the nix store is growing faster than GC can keep up, and there's no automated GC schedule configured. ~~Partially resolved: `nix.gc.automatic = true` (--delete-older-than 3d) now exists — but disk was at 97% on 08-14; cleanup tracked in TODO_LIST.~~

### 3. The auto-git daemon bundled unrelated changes
My `niri-wrapped.nix` + `flake.lock` changes were auto-committed together with an audio routing change (`audio.nix`) from another session under commit `cfeee94d`. The commit message only mentions the audio change. This makes the niri display config change invisible in git log — you'd have to know to look at this commit to find it.

### 4. 5 duplicate go-cqrs-lite entries in flake.lock
```
go-cqrs-lite:     rev=949d21aacc97 (orphaned, no inputs)
go-cqrs-lite_2:   rev=04be9f6dc75b
go-cqrs-lite_3:   rev=74b5762e29cb
go-cqrs-lite_4:   rev=a6300fd206dd (the one root → go-cqrs-lite points to)
go-cqrs-lite_5:   rev=067ab5671cb4
```
Each duplicate is a different revision, creating a confused dependency graph. The AGENTS.md notes about `follows` on LarsArtmann inputs exist to prevent this, but it still happened.

---

## e) WHAT WE SHOULD IMPROVE

### Process
1. **Check disk space BEFORE attempting deploy** — I wasted 3 deploy attempts before realizing disk was at 95%. Should be a pre-flight check in the session, not in the deploy script.
2. **Use `niri msg output` for immediate effect** — I should have applied the runtime change FIRST, then worked on the declarative config. Instead I did it in reverse order.
3. **The auto-git daemon should not bundle unrelated changes** — My niri config and the audio config from another session got merged into one commit with a misleading message.

### Config
4. **Niri `outputs` should have been in the config from day one** — Relying on auto-detection means display config is non-reproducible. Adding it now is correct. ~~Done — explicit `outputs` block present since `0bd8a272`.~~
5. **The `refresh` value for DP-1** (`59.997`) is the exact EDID value — this is fragile. If the monitor's EDID changes slightly, the mode won't match. Consider omitting `refresh` (defaults to highest available) or using a more standard `60.0`.
6. **VRR should be enabled on the TV** — The LG TV supports variable refresh rate. `variable-refresh-rate = true` would improve gaming/video playback.
7. **`focus-at-startup = true`** should be set on DP-1 (the primary monitor) so the session always starts focused on the main display.

### Infrastructure
8. **HaGeZi blocklist URLs need monitoring** — A 404 on a blocklist fetch should not block ALL deploys. Consider a fallback or cached version. ~~Done (superseded) at `88c594cc` — lists track the GitLab mirror's mutable `main` with SRI-hash pinning; content drift fails the build loudly.~~
9. **Automated nix GC schedule** — The system has no `nix.gc` auto-optimize-store schedule. Disk fills to 95%+ between manual GC runs. ~~Done — `nix.gc.automatic = true` (`--delete-older-than 3d`) in `platforms/common/nix-settings.nix`.~~
10. **Flake lock deduplication** — The 5 duplicate `go-cqrs-lite` entries should be consolidated. The `follows` mechanism exists for this but wasn't applied correctly.

---

## f) Up to 50 Things We Should Get Done Next

### Critical (blocks all deploys)
1. ~~Fix HaGeZi blocklist 404 — investigate the URL, update or add fallback~~ done at `88c594cc` (GitLab mirror)
2. ~~Get a successful `nix run .#deploy` to activate the niri outputs config permanently~~ done — deploys succeeded after `88c594cc`; outputs config committed at `0bd8a272`
3. ~~Verify niri outputs config survives niri restart (after deploy succeeds)~~ done (moot) — config survived the many restarts since
4. ~~Set up automated nix GC schedule (`nix.gc.automatic = true`) to prevent disk filling~~ done — `nix.gc.automatic = true`, `--delete-older-than 3d`
5. ~~Reset failed services: browser-history-agent, nix-build-cleanup~~ done — agent healthy since; sandbox cleanup automated at `c39b6d50`

### Config improvements for the niri outputs block
6. Add `focus-at-startup = true` to DP-1 (primary monitor)
7. Add `variable-refresh-rate = true` to DP-2 (TV supports VRR)
8. Consider omitting `refresh` on DP-1 to use auto-highest (more robust)
9. Add `variable-refresh-rate = true` to DP-1 if the LG HDR 4K supports it
10. Disable unused DP connectors (DP-3 through DP-8) with `enable = false`

### Documentation
11. Update AGENTS.md Desktop section with niri outputs configuration pattern
12. Document that connector name is the key (not EDID name) in niri outputs
13. Document the `niri msg output` runtime override as a deploy workaround
14. Note that runtime `niri msg output` changes are temporary (lost on restart)
15. Document the niri-flake `outputs` option schema reference

### Flake lock hygiene
16. Deduplicate go-cqrs-lite entries in flake.lock (5 copies → 1)
17. ~~Verify all LarsArtmann flake inputs have `follows` on go-nix-helpers~~ done at `fe891bff` (rule now documented in AGENTS.md)
18. ~~Run `nix flake check --no-build` after flake.lock changes~~ done (existing rule — pre-commit runs it on every commit)
19. ~~Audit all flake inputs for duplicate/locked entries~~ done — CI flake-input hygiene checks (`.github/workflows/nix-check.yml`) + `82963f04`/`caf2cab8` dedup
20. ~~Consider `nix flake update --recreate-lock-file` to start fresh (nuclear option)~~ **Won't implement — unnecessary after follows dedup; recreating loses all pinned revisions**

### Upstream go-cqrs-lite
21. Tag a new release on go-cqrs-lite with the fixed vendorHash
22. Update SystemNix flake input to use the tagged version instead of master
23. Remove the dirty suffix from cqrs-lint derivation name
24. Fix the go-cqrs-lite pre-commit (go-licenses and vulnix binaries missing)

### Disk space management
25. Investigate what's consuming 631G on root (nix store is 99G)
26. Check BTRFS snapshot retention (14d+4w — could be holding a lot)
27. Consider moving nix store to a separate subvolume (currently inside @)
28. Run `nix path-info --all --json | jq '...'` to find largest store paths
29. ~~Consider `nix.settings.auto-optimise-store = true` for hardlink dedup~~ **Won't implement — deliberately `false` (QLC NAND per-build I/O); scheduled `optimise.automatic` instead**

### Pre-existing issues noticed but not investigated
30. ~~Monitor365 endpoint is down (port 9191 not responding — metrics skipped)~~ done (moot) — service currently disabled (upstream wireguard-collector build break); checks conditional
31. ~~browser-history-agent.service is in failed state~~ done (moot) — healthy since; timer checks pass
32. ~~nix-build-cleanup.service is in failed state~~ done (superseded) — replaced by daily auto-clean timer `c39b6d50`
33. ~~boot.nix has uncommitted ZRAM changes (17% → 30%, swappiness 10 → 150) from another session~~ done — committed at `0bd8a272`
34. ~~The HaGeZi 404 affects multiple list variants: dga7, doh, gambling, dyndns, native-lgwebos~~ done at `88c594cc` — all lists switched to the GitLab mirror

### Display config edge cases
35. What happens when the TV is disconnected? Niri should handle missing outputs gracefully
36. What happens when only the TV is connected (e.g., monitor off)? Position may be wrong
37. Hot-plug behavior: niri should re-apply config when a display is reconnected
38. Consider using `lib.mkDefault` on scale values so DMS or other tools can override
39. The `position.x = 3072` is tied to DP-1's logical width (3072 at scale 1.25) — if DP-1 scale changes, this breaks

### System health
40. Gatus should monitor the deploy pipeline health (nix build success rate)
41. Add a pre-deploy disk space check that auto-runs GC if above 90%
42. Consider a `nix run .#gc` convenience command for garbage collection
43. ~~The `pre-deploy-check.sh` should warn at 90% (currently only at 95% hard-fail)~~ done — warns at 85%, hard-fails at 95% (`pre-deploy-check.sh:135-137`)
44. Add a health check for "time since last successful deploy" (alert if >7 days)

### Follow-up from this session
45. ~~Confirm the niri outputs config is in the next successful deploy diff~~ done — deployed with `0bd8a272`
46. ~~Remove the temporary runtime `niri msg output` overrides after deploy succeeds~~ done (moot) — declarative config took over after deploy
47. ~~Update the status report with "deploy verified" once it succeeds~~ done — recorded here; deploys verified in later sessions
48. Add niri outputs to the Gatus monitoring (display config drift detection)
49. Consider a niri config validation pre-commit hook (ensure outputs block exists)
50. Test that niri doesn't crash if a configured output is disconnected at boot

---

## g) Questions (3)

### Q1: HaGeZi blocklist 404 — temporary outage or permanent URL change?
The `HaGeZi-dga7-raw` derivation fails with 404 from all mirrors. I did not investigate the URL. Is this a known temporary issue, or has the HaGeZi project changed their download URLs? The DNS blocker module (`dnsblockd`) depends on these blocklists being fetchable at build time. Without knowing the source URL pattern, I can't determine if this needs a URL update or just a retry.

> **Answered (2026-08-14):** Neither — GitHub's automated fraud detection repeatedly locked `hagezi/dns-blocklists` (404ing all 22 fetch derivations). Fixed by switching to the GitLab mirror (`gitlab.com/hagezi/mirror`) with SRI-hash pinning at `88c594cc`.

### Q2: The uncommitted boot.nix ZRAM changes — should these be deployed?
`boot.nix` has uncommitted changes from another session: ZRAM changed from 17% → 30% memoryPercent, and swappiness documentation updated from 10 → 150. These are not my changes. Should I leave them as-is (for the other session to handle), or are they safe to include in the next deploy? The swappiness=150 change for zram-only is a significant behavior change.

> **Answered (2026-08-14):** Safe — committed and deployed at `0bd8a272`; the swappiness/zram retune is documented in AGENTS.md "ZRAM & Memory Reclaim".

### Q3: The 5 duplicate go-cqrs-lite entries in flake.lock — known or should I deduplicate?
The flake.lock has entries for `go-cqrs-lite`, `go-cqrs-lite_2` through `go-cqrs-lite_5`, each at different revisions. The root node maps `go-cqrs-lite → go-cqrs-lite_4` (my fixed version). The other 4 appear to be transitive inputs from other LarsArtmann flakes that don't `follows` correctly. Should I attempt to consolidate these by adding missing `follows` directives, or is this expected behavior that I should leave alone?

> **Still open (2026-08-14):** The `go-cqrs-lite_2`..`_5` nodes still exist in flake.lock. Dedup remains desirable — tracked in TODO_LIST.

---

## Session Summary

| Metric | Value |
|--------|-------|
| Files changed (mine) | 1 (`niri-wrapped.nix`) + 1 (`flake.lock` updated) |
| Files changed (upstream) | 1 (`go-cqrs-lite/flake.nix` — vendorHash fix) |
| Commits made | 1 upstream (`a6300fd20`) |
| Auto-commits captured | 1 (`cfeee94d` — bundled with audio changes) |
| Deploys attempted | 4 |
| Deploys succeeded | 0 (blocked by pre-existing HaGeZi 404) |
| Runtime changes applied | Yes (via `niri msg output`) |
| Disk space freed | ~34 GiB (two GC runs) |
| Pre-existing issues found | 5 (HaGeZi 404, disk critical, failed services, flake lock dupes, Monitor365 down) |
