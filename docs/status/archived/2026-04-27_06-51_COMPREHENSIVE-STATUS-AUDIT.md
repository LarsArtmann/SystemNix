# FULL COMPREHENSIVE STATUS REPORT — SystemNix

**Date:** 2026-04-27 06:51 CEST
**Author:** Crush (AI audit agent)
**Scope:** Entire SystemNix repository — 96 Nix files, 19 Go files, 95 tracked tasks
**Trigger:** User-requested comprehensive accuracy audit + status update

---

## Executive Summary

SystemNix is a cross-platform Nix configuration managing two machines (macOS + NixOS) through a single flake. The project is at **65% task completion** (62/95 tasks done). Code quality is high — all P0–P4 categories are at 100%. The remaining work is almost entirely **blocked on physical access to evo-x2** (the NixOS machine) or **external dependencies**.

The most critical unsolved issue is a **`nix-ssh-config` build error** (`duplicate environment.etc`) that prevents `just switch` from succeeding on NixOS. This is an upstream issue in `github:LarsArtmann/nix-ssh-config`.

**Key numbers:**

| Metric                  | Value                         |
| ----------------------- | ----------------------------- |
| Nix files               | 96 (12,211 lines)             |
| Go files                | 19 (7,643 lines)              |
| Service modules         | 27                            |
| Custom packages         | 7                             |
| Total tasks tracked     | 95                            |
| Tasks done              | 62 (65%)                      |
| Tasks blocked on evo-x2 | 25 (76% of remaining)         |
| Commits since Apr 24    | 67                            |
| Commits since Apr 20    | 167                           |
| Justfile recipes        | 155 (1,935 lines)             |
| Git branch              | `master` (clean, pushed)      |
| Binary cache hit ratio  | 64% (fixed from 0% this week) |

---

## A) FULLY DONE ✅

Tasks verified against actual code in this session. All evidence double-checked.

### P0 — CRITICAL (6/6 = 100%)

- Git hygiene clean: no unpushed commits, no stashes, no stale remote branches
- Status docs archived (132 in `docs/status/archive/`, 16 retained)
- Status README.md rewritten (6 lines)
- "29 modules" → correct count fixed across all docs

### P2 — RELIABILITY (11/11 = 100%)

- All long-running services have `Restart=on-failure`
- WatchdogSec=30 on caddy, gitea, authelia, taskchampion, hermes, homepage, immich, signoz, photomap (WatchdogSec=60 on comfyui, minecraft)
- Dead let bindings, pager conflicts, font compatibility, udisks2 all verified
- `.editorconfig`, deadnix strict mode, statix pre-commit hook all present
- `meta.homepage` on emeet-pixyd (line 22)

### P3 — CODE QUALITY (9/9 = 100%)

- Deadnix unused params fixed in all 12 service modules
- Git ignores deduplicated
- GPG program cross-platform conditional in git.nix:53-59
- Bash history config (HISTCONTROL, HISTSIZE, HISTFILESIZE)
- Fish GOPATH init with guard, `fish_maximum_history_size` verified real
- Unfree allowlist cleaned

### P4 — ARCHITECTURE (7/7 = 100%)

- `lib/systemd.nix` shared hardening helper created
- Preferences.nix wired to theming
- Niri session restore converted to module options (sessionSaveInterval, maxSessionAgeDays, fallbackApps at niri-wrapped.nix:308-361)
- All 4 enable-toggles batches applied (services, desktop, security, monitoring)

### P7 — TOOLING & CI (10/10 = 100%)

- 3 GitHub Actions workflows (nix-check, go-test, flake-update)
- Eval smoke tests fixed (no `|| true`)
- Alejandra replacing nixpkgs-fmt
- System monitors trimmed to 2 (btop + bottom)
- LC_ALL removed (LC_CTYPE kept for macOS compat in fish.nix:17)
- `allowUnsupportedSystem = false` in nix-settings.nix:75
- Taskwarrior daily backup timer in taskwarrior.nix:168

### P8 — DOCUMENTATION (5/5 = 100%)

- README.md updated with all 13 services, DNS failover, commands
- AGENTS.md DNS Failover Cluster section
- ADR-005 for niri session restore design
- 86 description fields across 8 service files with mkOption
- CONTRIBUTING.md with patterns, hooks, architecture

### Proactive Cleanup (beyond original plan)

- Removed 8 dead platform files (628 lines)
- Fixed `{…}:` → `_:` anti-pattern in darwin/environment.nix
- Fixed `pkgs.lib.mkForce` → `lib.mkForce` in ai-stack.nix
- Cleaned dead imports in configuration.nix

### Cache Performance Fix (this week, commit `97bf8fd`, `b586ed0`)

- Fixed 0% → 64% binary cache hit ratio
- Removed redundant goOverlay (identical version, different derivation hash)
- Disabled unboundDoQOverlay (cascaded to rebuild ffmpeg, linux, pipewire)
- Added disableTestsOverlay for valkey cluster test hang
- Pinned nixpkgs to specific commit (not floating branch ref)
- 621 paths fetched from cache (6.3 GiB), 353 built from source

---

## B) PARTIALLY DONE 🔶

### P6 — SERVICES (9/15 = 60%)

| Task                         | Status     | What's Done                                 | What's Left                                                           |
| ---------------------------- | ---------- | ------------------------------------------- | --------------------------------------------------------------------- |
| #56 ComfyUI hardcoded paths  | ACCEPTABLE | Module options exist with defaults          | Defaults are hardcoded to `/home/lars/` paths — designed for override |
| #58 ComfyUI dedicated user   | ACCEPTABLE | WatchdogSec + MemoryMax done                | Runs as `lars` for GPU group access — acceptable tradeoff             |
| #62 Hermes health check      | PENDING    | Service runs, has WatchdogSec               | Needs `/health` endpoint in Hermes codebase (external dep)            |
| #63 Hermes key_env migration | PENDING    | Most providers use key_env                  | `mergeEnvScript` is redundant but low risk                            |
| #65 SigNoz missing metrics   | BLOCKED    | Collector scraping node_exporter + cAdvisor | Need evo-x2 to verify 10 additional service metric endpoints          |
| #66 Authelia SMTP            | BLOCKED    | Authelia SSO running                        | SMTP credentials needed for notification emails                       |

### P1 — SECURITY (3/7 = 43%)

| Task                   | Status  | What's Done                                   | What's Left                  |
| ---------------------- | ------- | --------------------------------------------- | ---------------------------- |
| #9 Voice Agents digest | BLOCKED | Version-tagged `1.0.0` (not `latest`)         | Pull SHA256 digest on evo-x2 |
| #10 PhotoMap digest    | BLOCKED | Version-tagged `1.0.0` (not `latest`)         | Pull SHA256 digest on evo-x2 |
| #11 VRRP auth          | BLOCKED | dns-failover module has `authPassword` option | Move default to sops secret  |

### DNS-over-QUIC

- Feature disabled but code preserved in comments
- Needs isolated approach (separate derivation, not global overlay)

---

## C) NOT STARTED ⬜

### P5 — DEPLOYMENT & VERIFICATION (0/13 = 0%)

All 13 tasks require physical access to evo-x2:

| #  | Task                                         | Est. |
| -- | -------------------------------------------- | ---- |
| 41 | `just switch` — deploy all pending changes   | 45m+ |
| 42 | Verify Ollama works                          | 5m   |
| 43 | Verify Steam works                           | 5m   |
| 44 | Verify ComfyUI works                         | 5m   |
| 45 | Verify Caddy HTTPS block page                | 3m   |
| 46 | Verify SigNoz collecting metrics/logs/traces | 5m   |
| 47 | Check Authelia SSO status                    | 3m   |
| 48 | Check PhotoMap service status                | 3m   |
| 49 | Verify AMD NPU with test workload            | 10m  |
| 50 | Build Pi 3 SD image                          | 30m+ |
| 51 | Flash SD + boot Pi 3                         | 15m  |
| 52 | Test DNS failover                            | 10m  |
| 53 | Configure LAN devices for DNS VIP            | 10m  |

### P9 — FUTURE / RESEARCH (2/12 investigated = 17%)

All 10 uninvestigated tasks are research/architecture items with no immediate action:

| #  | Task                                          | Category |
| -- | --------------------------------------------- | -------- |
| 86 | homeModules pattern for HM via flake-parts    | ARCH     |
| 87 | Package ComfyUI as proper Nix derivation      | ARCH     |
| 88 | Investigate lldap/Kanidm for unified auth     | ARCH     |
| 89 | Migrate Pi 3 from linux-rpi to nixos-hardware | ARCH     |
| 91 | Add NixOS VM tests for critical services      | TESTING  |
| 92 | Investigate binary cache (Cachix)             | PERF     |
| 93 | Add Waybar module for session restore stats   | FEATURE  |
| 94 | Add real-time save via niri event-stream      | FEATURE  |
| 95 | Add integration tests for session restore     | TESTING  |
| 96 | File nixpkgs issue for hipblaslt Tensile      | UPSTREAM |

### Service-Specific Blocked Tasks

| #  | Task                           | Blocker      |
| -- | ------------------------------ | ------------ |
| 67 | Immich backup restore test     | Needs evo-x2 |
| 68 | Twenty CRM backup restore test | Needs evo-x2 |

---

## D) TOTALLY FUCKED UP 💥

### 1. MASTER_TODO_PLAN had multiple inaccuracies (caught in this audit)

**Evidence claims that were wrong:**

| What was claimed                       | Actual truth                                 | Impact                                       |
| -------------------------------------- | -------------------------------------------- | -------------------------------------------- |
| P1-9: "latest tag in voice-agents.nix" | Version-tagged `1.0.0` — not `latest`        | Inflated severity, wrong blocker description |
| P1-10: "latest tag in photomap.nix"    | Version-tagged `1.0.0` — not `latest`        | Same                                         |
| P8: "6/6 DONE"                         | Only 5 tasks (79–83). Task #84 never existed | Wrong count, inflated done total             |
| P6: "11/15 DONE"                       | Only 7 done + 2 acceptable = 9 at most       | Overstated by 2 tasks                        |
| Summary: "60 done, 96 tasks, 63%"      | Actually 95 tasks (no #84), 62 done, 65%     | Wrong on every axis                          |
| P2-18: "fonts.nix:6"                   | `packages/fonts.nix:6` (wrong directory)     | Misleading reference                         |
| P2-19: "configuration.nix:154"         | Actually line 144                            | Stale reference                              |
| P7-76: "Removed LC_ALL and LC_CTYPE"   | LC_CTYPE still exists in fish.nix:17         | False claim                                  |
| SigNoz: "lines 294-300"                | Actually lines 287-298                       | Stale reference                              |

**Lesson:** Status documents must be verified against code, not copied from prior sessions.

### 2. Binary cache was broken for days (0% hit ratio)

- `goOverlay` was overriding go_1_26 with the identical version — different derivation hash invalidated the entire transitive closure
- `unboundDoQOverlay` patched unbound globally, cascading to rebuild ffmpeg, linux kernel, pipewire
- Nobody noticed because builds "worked" (just took 40+ minutes)
- **Root cause:** No cache-hit monitoring or CI gate on build performance

### 3. `nix-ssh-config` build error blocking all deploys

- `nixos-rebuild switch` fails with `attribute 'environment.etc' already defined`
- Issue is in the external `github:LarsArtmann/nix-ssh-config` flake
- This means **zero NixOS configuration changes have been deployed** despite 67+ commits since Apr 24
- All the P2–P4–P7 "done" tasks are code-complete but **untested on the actual machine**

### 4. Security items mischaracterized

- Docker images were described as using `latest` tags (security risk) when they actually use version tags (`1.0.0`)
- Real risk is lower than documented — only digest pinning needed, not full image pinning
- VRRP auth password is a module option default, not hardcoded in config — also lower risk than implied

---

## E) WHAT WE SHOULD IMPROVE 📈

### Process Gaps

1. **No cache-hit monitoring** — We ran at 0% cache hits for days without noticing. Need CI gate or pre-build check.
2. **Status docs not verified against code** — MASTER_TODO_PLAN had 10+ inaccuracies from stale line numbers and wrong claims. Need automated verification.
3. **No deploy pipeline** — 67 commits with zero deploys. Code changes pile up without validation.
4. **Overlay safety rules not documented** — No guidelines for which packages are safe to overlay without cache invalidation.
5. **No `just switch` dry-run in CI** — GitHub Actions checks syntax but doesn't catch runtime errors like the nix-ssh-config duplicate.
6. **Line numbers in status docs rot fast** — Every code edit invalidates line-number references. Use function/section names instead.

### Technical Debt

7. **`with lib;` still in 3 files** (signoz.nix:64, dnsblockd-processor/package.nix:16, monitor365.nix:47) — anti-pattern
8. **`rec {}` in 7 places** — some legitimate (buildGoModule), some questionable (theme.nix uses `_: rec {}`)
9. **`pkgs.lib.*` in taskwarrior.nix:44-45** — should use `lib.*` directly
10. **`HSA_OVERRIDE_GFX_VERSION = "11.5.1"` in 3 files** — hardware constant, low DRY benefit but could be extracted
11. **Hardcoded `/home/lars/` in 3 module defaults** (monitor365, comfyui ×2)
12. **Hardcoded `"lars"` username in 7 files** — should use `config.users.users.<name>` or `primaryUser` consistently
13. **4 TODO comments in service modules** — 2 security (digest pinning), 2 kernel audit (blocked upstream)
14. **Security hardening module has 2 disabled features** — audit kernel module and audit-rules service disabled with TODOs
15. **DNS-over-QUIC disabled** — overlay approach was wrong, needs separate derivation

### Documentation Debt

16. **MASTER_TODO_PLAN counting was inconsistent** — P6 overcounted, P8 overcounted, missing task gap (#84) not explained
17. **No ADR for overlay safety policy** — should document which packages are safe to override
18. **No ADR for nixpkgs pinning policy** — just learned this lesson the hard way
19. **Cache performance report (2026-04-27_06-46) is excellent** — but the MASTER_TODO_PLAN it references was inaccurate

---

## F) TOP 25 NEXT ACTIONS 🎯

Ranked by impact and unblocked status.

| #  | Priority | Action                                                            | Est. | Blocked?   | Category |
| -- | -------- | ----------------------------------------------------------------- | ---- | ---------- | -------- |
| 1  | 🔴 P0    | Fix `nix-ssh-config` duplicate `environment.etc` build error      | 30m  | Upstream   | BLOCKER  |
| 2  | 🔴 P0    | `just switch` on evo-x2 — deploy all 67+ pending commits          | 45m  | evo-x2     | DEPLOY   |
| 3  | 🔴 P1    | Verify full build succeeds end-to-end after nix-ssh-config fix    | 10m  | #1         | VERIFY   |
| 4  | 🔴 P1    | Move Taskwarrior encryption to sops-nix (#7)                      | 10m  | evo-x2     | SECURITY |
| 5  | 🔴 P1    | Pin Docker digest for Voice Agents (#9)                           | 5m   | evo-x2     | SECURITY |
| 6  | 🔴 P1    | Pin Docker digest for PhotoMap (#10)                              | 5m   | evo-x2     | SECURITY |
| 7  | 🔴 P1    | Secure VRRP auth_pass with sops-nix (#11)                         | 8m   | evo-x2     | SECURITY |
| 8  | 🟡 P2    | Verify Ollama, Steam, ComfyUI, Caddy after deploy (#42-45)        | 20m  | evo-x2     | VERIFY   |
| 9  | 🟡 P2    | Verify SigNoz collecting metrics/logs/traces (#46)                | 5m   | evo-x2     | VERIFY   |
| 10 | 🟡 P2    | Check Authelia SSO + PhotoMap status (#47-48)                     | 6m   | evo-x2     | VERIFY   |
| 11 | 🟡 P2    | Verify AMD NPU with test workload (#49)                           | 10m  | evo-x2     | VERIFY   |
| 12 | 🟡 P2    | Create `just cache-check` command (dry-run + fetch ratio)         | 20m  | No         | TOOLING  |
| 13 | 🟡 P2    | Document nixpkgs pinning + overlay safety policy in AGENTS.md     | 15m  | No         | DOCS     |
| 14 | 🟡 P2    | Fix `with lib;` in signoz.nix, dnsblockd-processor, monitor365    | 5m   | No         | QUALITY  |
| 15 | 🟢 P3    | Isolate unbound DoQ into separate derivation (not global overlay) | 60m  | No         | ARCH     |
| 16 | 🟢 P3    | Build Pi 3 SD image + test DNS failover (#50-52)                  | 55m  | evo-x2+Pi  | DEPLOY   |
| 17 | 🟢 P3    | Hermes health check endpoint (#62)                                | 60m  | Hermes     | SERVICE  |
| 18 | 🟢 P3    | SigNoz missing metrics investigation (#65)                        | 30m  | evo-x2     | OBSERV   |
| 19 | 🟢 P3    | Authelia SMTP notifications (#66)                                 | 15m  | SMTP creds | UX       |
| 20 | 🟢 P3    | Immich + Twenty backup restore tests (#67-68)                     | 30m  | evo-x2     | RELIAB   |
| 21 | 🟢 P3    | Remove `disableTestsOverlay` when valkey test fixed upstream      | 5m   | Upstream   | CLEANUP  |
| 22 | 🟢 P3    | Add `meta.mainProgram` to remaining custom packages               | 10m  | No         | QUALITY  |
| 23 | 🔵 P4    | Investigate binary cache (Cachix) for custom packages (#92)       | 60m  | No         | PERF     |
| 24 | 🔵 P4    | Add NixOS VM tests for critical services (#91)                    | 120m | No         | TESTING  |
| 25 | 🔵 P4    | Add `just update-nixpkgs` that verifies Hydra cache hits          | 30m  | No         | TOOLING  |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT 🤔

**Why does `nix flake update nixpkgs` NOT update the nixpkgs entry in flake.lock when using a branch ref?**

This was observed during the cache investigation:

- `flake.nix` had `nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"` (branch ref)
- `flake.lock` pinned nixpkgs to rev `46db2e0` (March 24)
- `nix flake update` and `nix flake update nixpkgs` did NOT change the rev
- Yet Nix evaluated with rev `01fbdee` (April 23) — a different revision than what was in the lock
- This caused zero cache hits because the evaluated rev had no Hydra-built binaries

Hypotheses:

1. Nix re-resolves branch refs at evaluation time, ignoring the lock file
2. A corrupted local flake registry or Nix cache
3. `accept-flace-config = true` affecting lock resolution
4. A Nix daemon caching issue where the daemon resolved the ref differently

We worked around it by pinning to a specific commit hash in `flake.nix`, but the underlying behavior is not understood. If branch refs are silently re-resolved, then `flake.lock` provides no reproducibility guarantee for branch-ref inputs — which is a serious concern.

---

## Task Completion Breakdown

```
P0 CRITICAL    ████████████████████ 100% (6/6)
P1 SECURITY    ████████░░░░░░░░░░░░  43% (3/7)
P2 RELIABILITY ████████████████████ 100% (11/11)
P3 QUALITY     ████████████████████ 100% (9/9)
P4 ARCH        ████████████████████ 100% (7/7)
P5 DEPLOY      ░░░░░░░░░░░░░░░░░░░░   0% (0/13)
P6 SERVICES    ████████████░░░░░░░░  60% (9/15)
P7 TOOLING     ████████████████████ 100% (10/10)
P8 DOCS        ████████████████████ 100% (5/5)
P9 FUTURE      ███░░░░░░░░░░░░░░░░░  17% (2/12)
──────────────────────────────────────
TOTAL          █████████████░░░░░░░  65% (62/95)
```

## What's Blocking Progress

```
                                    ┌──────────────┐
                                    │  evo-x2 box  │
                                    │  (NixOS)     │
                                    └──────┬───────┘
                                           │
              ┌────────────────────────────┼────────────────────────┐
              │                            │                        │
     ┌────────▼────────┐        ┌─────────▼──────────┐  ┌─────────▼──────────┐
     │ P1: 4 security  │        │ P5: 13 deploy/     │  │ P6: 6 service      │
     │ tasks (sops,    │        │ verify tasks       │  │ tasks (metrics,    │
     │ digests, VRRP)  │        │ (just switch,      │  │ restore tests,     │
     └─────────────────┘        │ verify services)   │  │ SMTP, health)      │
                                └────────────────────┘  └────────────────────┘

     ┌─────────────────┐        ┌────────────────────┐  ┌────────────────────┐
     │ nix-ssh-config  │        │ Hermes upstream    │  │ SMTP credentials   │
     │ duplicate       │        │ (health endpoint)  │  │ (Authelia)         │
     │ environment.etc │        │                    │  │                    │
     └─────────────────┘        └────────────────────┘  └────────────────────┘
```

**25 of 33 remaining tasks (76%) are blocked on evo-x2 access or upstream fixes.**

## Files Modified This Session

| File                              | Change                                                                                            |
| --------------------------------- | ------------------------------------------------------------------------------------------------- |
| `docs/status/MASTER_TODO_PLAN.md` | Corrected 10+ inaccuracies: P6 count 11→9, P8 count 6→5, totals 96→95, line refs, evidence claims |

## Session Context

This session performed a **comprehensive accuracy audit** of the MASTER_TODO_PLAN against actual code. Every evidence claim was verified by reading the referenced files and checking line numbers, status markers, and factual accuracy. 10 inaccuracies were found and corrected. This report synthesizes the full project state.
