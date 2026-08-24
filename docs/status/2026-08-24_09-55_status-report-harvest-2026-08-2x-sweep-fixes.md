# Status Report: 2026-08-2x Status-Report Harvest — 7 Live Bugs Fixed, Deployed as system-721

**Session:** 2026-08-24 ~09:00-10:00 · **Task:** "Read all docs/status/2026-08-2* — fix!" · **Mode:** docs-health HARVEST + VERIFY + fix

## What was done

Read ALL 47 status reports from 2026-08-20 → 2026-08-24 (620 KB) via 4 parallel extraction agents, cross-verified every candidate against current code and live textfile metrics, then fixed the confirmed-live bugs and harvested the remainder into TODO_LIST.

### a) Fully done (verified)

1. **Gatus "Build Cache Usage" phantom green FIXED** (`gatus-config.nix`) — flagged unfixed in three reports since 2026-08-22 17-31. Was GREEN on a dead drive through the whole DAS outage (only asserted `buildcache_usage_over_threshold 0`, which stays "0" in the always-written `.prom`). Now requires anchored `buildcache_mounted` presence + non-0. gatus-pattern-lint built clean.
2. **Dozzle logs missing from SigNoz FIXED** (`dozzle.nix`) — the 2026-08-22 regression (`--log-driver=json-file` + log-opts beating the daemon's journald default) removed; regression-guard comment added. Container recreates on deploy.
3. **display-watchdog login-kill bug FIXED** (`scripts/display-watchdog.sh`) — 60s session-creation grace via `TimestampMonotonic` age (absolute-monotonic lesson applied); skips the tick WITHOUT resetting the failure counter. Kills the "watchdog bounced two legitimate logins" class from the 2026-08-24 black-screen incident. bash -n + shellcheck clean.
4. **KNOWN_NEW_METRICS bypass graveyard pruned** (`scripts/pre-deploy-check.sh`) — 21 entries retired after live verification against `/var/lib/prometheus-node-exporter/textfile_collectors` (zram ×5, lan-nic, das-link, profile-anchor, forgejo-mirror ×3 — collector confirmed GREEN at `scrape_errors 0`, psi ×2, crush ×2, cgroup ×4, sev1 ×2). Kept: discordsync (input-bump pending) + bank-sync ×2 (unverifiable, pool down), each with exact removal conditions.
5. **LAN-NIC/DAS-link gating consistency** (`system-health.nix` + `gatus-config.nix`) — `system_lan_nic_present` emitted a permanent phantom `1` on hosts with `lanInterface = ""`; metric emission and both Gatus checks now gated on the SAME non-empty condition. evo-x2 behavior unchanged (eval-verified endpoints intact).
6. **nix max-free 100 GB → 30 GB** (`platforms/common/nix-settings.nix`) — the top advisory carried across three 2026-08-21 reports; 100G was unreachable on the ~95%-full root so every GC swept the whole store in one QLC I/O storm.
7. **Fish login guard extended + optimized** (`platforms/nixos/users/home.nix`) — now covers all NINE inherited cache vars (added CARGO_HOME, PIP_CACHE_DIR, SCCACHE_DIR, npm_config_cache, PLAYWRIGHT_BROWSERS_PATH) with per-DISTINCT-mount probe memoization: measured 1.02s with the mount dead vs ~8s naive per-var (live-tested against the real dead automount; `fish -i -c exit` 8.1s → 1.05s).
8. **deploy.sh generation trail** — prints was→now generation delta + warns when `/run/current-system` is unanchored (manual-activation detector). Live-proven: "✓ New profile generation: system-721 (was system-720)".
9. **btrfs-gc-guard stale `<10%` comment corrected** (`platforms/nixos/system/btrfs-health.nix:542`).
10. **CHANGELOG Unreleased deduplicated** — 3× `### Fixed` / 2× `### Added` / 2× `### Changed` merged to one each (bullet-content diff verified: 419 → 419, zero lost); session entries added.
11. **TODO_LIST harvested** — 13 net-new rows from the 08-22/08-24 reports (IO-PSI phantom saturation + guard tier, niri gatus false negatives, boot-generation freshness, btrbk-data oom, dnsblockd health wedge, post-DAS-recovery sweep, BuildFlow 11.3 GB caches, attic-class sweep, forgejo upstream filing, paperless embeddings E2E, crush-daily 0-sessions, device-timeout). Verified NOT-already-done before adding: bank-sync pin (already rolled to `c89e8cfd`), test-gatus-patterns (already wired in checks), pool-usage Gatus (already live).
12. **Deployed as system-720 → system-721.** Pre-deploy: 89 passed / 0 failed. Post-deploy smoke: 60 PASS / 9 FAIL (identical DAS-cascade set as the established baseline) / 5 SKIP / 4 WARN. system-health-metrics rebuilt green (1.2s wall).

### b) Partially done

- **First deploy attempt failed at build**: shellcheck SC2157 on `[ -n "eno1" ]` (Nix-interpolated literal = always-true). Fixed by using the shell vars (`$LAN_IF`/`$DAS_USB_PATH`); collector built clean on direct `.drv^out` build, then deployed. Lesson: never interpolate config literals into shell conditions in `writeShellApplication` scripts — reference the assigned variable.
- **TODO_LIST multiedit self-mangle** (two items fused by a bad edit sequence) — caught by immediate re-read, repaired in the same session.

### c) Not started (deliberately — user-gated or physical)

- DAS physical reseat + power-cycle (blocks the post-recovery sweep; TODO row added)
- 11.3 GB BuildFlow fallback-cache disposition (user keep/quarantine call)
- Crush Daily 0-sessions deep-dive (user question carried; investigation row added)
- All items requiring user decisions identified in the reports (hermes PAT go-live, visionreviewd, monitor365 G7, XFS finalize, etc.) — already tracked in TODO_LIST

### d) Mistakes

1. The SC2157 build failure (one wasted deploy cycle) — the class was even documented in AGENTS (`writeShellApplication` lints at build time).
2. The TODO_LIST multiedit mangle — inserting before a partial-line anchor; repaired.

### e) Improvements

- The harvest confirms the reports' own "already fixed in HEAD?" pre-check rule: several top-recommended items (forgejo dbPath, pool-usage gatus, bank-sync pin, gatus VM test) were already done by later sessions — verifying before fixing saved phantom work.
- KNOWN_NEW_METRICS now carries exactly 3 entries, each with a removal condition — the "bypass graveyard" drift mode is structurally harder to repeat.

### f) Next

See TODO_LIST (13 new rows). Highest value: IO-PSI phantom-saturation correlation (crash3 class), IO-PSI guard tier, niri gatus false negatives.

## Verification chain

`nix fmt` (6 files) → `nix flake check --no-build` (all passed) → gatus-pattern-lint built clean → endpoints eval'd (LAN/DAS/Build-Cache conditions correct, real newlines) → collector `.drv^out` built → system-720 → SC2157 fix → system-721 → pre-deploy 89/0 → post-deploy 60/9(DAS-baseline) → fish login 1.05s live → generation-trail line live.
