# SystemNix — Comprehensive Status Report

**Date:** 2026-06-03 16:47 CEST
**Host:** evo-x2 (x86_64-linux, NixOS)
**Session:** 118 — Code Cleanup Sprint
**Build:** ✅ `just test-fast` passes (all checks, zero warnings)
**Branch:** master (1 commit ahead of origin)
**Uncommitted:** 10 files changed (9 modified, 1 new, 1 deleted)

---

## Session 118 Summary

### What got done

| # | Task | Status | Details |
|---|------|--------|---------|
| 1 | Delete orphan `ai-stack.nix` | ✅ | 109 lines removed — truly unused (Ollama managed differently) |
| 2 | Fix port 8050 conflict | ✅ | Reassigned photomap to 8051, registered in `lib/ports.nix` |
| 3 | Re-add `go-structure-linter` | ✅ | User fixed upstream. Overlay + package restored. `vendorHash` obtained via build. |
| 4 | Add stale LSP cleanup timer | ✅ | Daily timer kills gopls/vtsls/rust-analyzer >24h old |
| 5 | Add Dozzle service module | ⚠️ | Module created, port registered (8084), but **disabled** — `nix flake check` fails with "option services.dozzle does not exist" despite `nix eval` working. Suspected Nix eval caching or module ordering issue. Needs investigation. |

### In Progress (blocked)

| Task | Blocker |
|------|---------|
| Dozzle activation | `nix flake check` rejects the module while `nix eval` accepts it. Module is registered, options exist, but the `seq`-based check fails. |
| Remaining TODO items | See section C) |

---

## A) Fully Done ✅

### Session 117-118 Combined

- Overlay cleanup: ALL sed patches eliminated, upstream fixes tagged with semver
- Activation fixes: xdg-desktop-portal-gtk (confirmed working), home-manager-lars (retry resilience), dnsblockd (wider start limits + blockIP check)
- Orphan module deleted: `ai-stack.nix`
- Port 8050 conflict resolved: photomap → 8051
- go-structure-linter restored: upstream fixed `template-LICENSE/types` dep
- Stale LSP cleanup: daily systemd timer kills processes >24h old
- Dozzle module created (disabled pending eval fix)

### Full Infrastructure

| Component | Status |
|-----------|--------|
| Cross-platform flake (Darwin + NixOS) | ✅ |
| 36 service modules (auto-discovered) | ✅ |
| Overlay system (mkPackageOverlay) | ✅ |
| SOPS + Age secrets | ✅ |
| Home Manager integration | ✅ |
| Formatter + linting (treefmt, alejandra, statix, deadnix) | ✅ |
| 25+ services running on evo-x2 | ✅ |
| BTRFS snapshots (daily, 14d+4w retention) | ✅ |
| Journald (16G system, 2G runtime, 1 month) | ✅ |
| systemd-oomd + per-service MemoryMax | ✅ |

---

## B) Partially Done ⚠️

| Item | Status | Remaining |
|------|--------|-----------|
| Dozzle module | ⚠️ Created but disabled | Debug `nix flake check` eval issue |
| go-structure-linter | ✅ Restored | Was broken for weeks, user fixed upstream |
| SigNoz alerting | ✅ Functional | Per-threshold channel routing not done |
| DNS infrastructure | ✅ Working | DoQ disabled (unbound lacks ngtcp2), Pi 3 not provisioned |
| Hermes | ✅ Running | No secondary LLM fallback, no git remote |

---

## C) Not Started 📋

| # | Item | Effort | Why |
|---|------|--------|-----|
| 1 | Fix Dozzle `nix flake check` issue | 1-2h | Module eval works but check fails — needs deep NixOS module system debugging |
| 2 | Deploy committed changes (`just switch`) | 5min | 2+ commits ahead of origin |
| 3 | Add `/data` disk growth trend alerting | 1h | Prevents repeat of May 30 disk-full crash |
| 4 | ClickHouse data retention policy (30d TTL) | 2h | Largest disk growth contributor |
| 5 | Add nixosTest for dnsblockd module | 2h | Most complex custom service, zero test coverage |
| 6 | Add per-threshold SigNoz channel routing | 1h | critical→Discord, warning→log |
| 7 | Create `just status` command | 2h | Automated status report generation |
| 8 | Audit flake inputs (48 total) | 2h | Reduce eval time, attack surface |
| 9 | GitHub Actions CI | 1h | `just test-fast` + `just hash-check` on PRs/push |
| 10 | Provision Pi 3 for DNS failover | 4h | Eliminates single DNS point of failure |
| 11 | nix-colors integration | 6h | Migrate 17+ hardcoded colors |
| 12 | Darwin home.nix parity | 4h | Only if actively used |

---

## D) Totally Fucked Up 💥

### D1. Dozzle `nix flake check` Mystery

Module registers correctly, `nix eval` resolves the option, but `nix flake check`'s `seq`-based validation fails with "option does not exist". This is the first time this pattern has failed — all other service modules work identically. Possible causes:
- Nix eval caching of module options
- Flake-parts module wrapping issue specific to this module
- Race condition in Nix's parallel evaluation

**Workaround:** Module exists, disabled. Can be enabled via config once the eval issue is resolved.

### D2. Swap Exhaustion (Pre-existing)

13Gi/13Gi swap, 7 gopls instances at ~7.4Gi RSS. Stale LSP cleanup timer added but not yet deployed.

### D3. `/data` at 93-95% (Pre-existing)

No ClickHouse retention policy. No disk growth trend alerting.

### D4. Darwin Config Bitrotting (Pre-existing)

62 lines vs 536 on NixOS.

### D5. `default-services.nix` "Orphan" (Clarified)

NOT actually orphaned — auto-discovered and enabled by default (`default = true`). Provides Docker config. Initially thought it was dead code.

---

## E) What We Should Improve 🔧

### E1. CI Pipeline — Still Nonexistent

The #1 highest-impact gap. No GitHub Actions. Manual-only testing.

### E2. Test Coverage — 2 Tests for 36 Modules

Same as last report. No new tests added this session.

### E3. Module Eval Debugging

The Dozzle issue highlights a gap in understanding `nix flake check` vs `nix eval` behavior. Should document the difference and create a pattern for adding new service modules that avoids this class of issue.

### E4. Disk Management — No Long-term Plan

Same as last report. No data retention policies, no automated cleanup beyond weekly Docker prune.

---

## F) Top 25 Things to Do Next 🎯

### P0: Deploy & Verify

| # | Task | Effort |
|---|------|--------|
| 1 | Deploy committed changes (`just switch`) | 5min |
| 2 | Push to origin | 1min |
| 3 | Verify activation — portal-gtk, home-manager-lars, dnsblockd | 10min |

### P1: Debug & Fix

| # | Task | Effort |
|---|------|--------|
| 4 | Debug Dozzle `nix flake check` issue — try moving module to inline config | 1-2h |
| 5 | Investigate Monitor365 crash-loop | 30min |
| 6 | Add `/data` disk growth trend alerting | 1h |
| 7 | Add ClickHouse 30d retention policy | 2h |

### P2: CI & Testing

| # | Task | Effort |
|---|------|--------|
| 8 | Add GitHub Actions CI — `just test-fast` + `just hash-check` | 1h |
| 9 | Add nixosTest for dnsblockd module | 2h |
| 10 | Add `just test` to CI (full build on merge) | 30min |

### P3: Code Quality

| # | Task | Effort |
|---|------|--------|
| 11 | Create `just status` command | 2h |
| 12 | Audit flake inputs (48 total) | 2h |
| 13 | Add per-threshold SigNoz channel routing | 1h |
| 14 | Delete disabled modules (photomap, voice-agents if unused) | 30min |

### P4: Architecture

| # | Task | Effort |
|---|------|--------|
| 15 | Separate `/data` subvolume for observability | 2h |
| 16 | Provision Pi 3 for DNS failover | 4h |
| 17 | nix-colors integration | 6h |
| 18 | Darwin home.nix parity | 4h |
| 19 | Shared flake-parts template for Go repos | 3h |

### P5: Polish

| # | Task | Effort |
|---|------|--------|
| 20 | Enable Dozzle once eval issue resolved | 1h |
| 21 | Deploy Dozzle at `logs.home.lan` | 30min |
| 22 | Configure Hermes secondary LLM provider | 30min |
| 23 | Add nixosTests for critical services | 8h |
| 24 | Automated secret rotation | 4h |
| 25 | Convert go-auto-upgrade `path:` inputs to SSH URLs | 1h |

---

## G) Unanswered Question ❓

Same as last report: **Is Darwin actively used for daily work?** This determines 10h+ investment in Darwin parity.

---

## Session Timeline (Recent)

| Date | Session | Key Achievement |
|------|---------|-----------------|
| Jun 3 | 118 | Code cleanup: orphan module, port conflict, go-structure-linter restore, stale LSP timer, Dozzle (blocked) |
| Jun 3 | 117 | Overlay cleanup, activation fixes, comprehensive status report |
| Jun 3 | 116 | Post-crash forensics, journald limits, disk-monitor fix |
| Jun 2 | 115 | Ghostty migration, justfile fixes, Gatus alerting |

---

_Arte in Aeternum_
