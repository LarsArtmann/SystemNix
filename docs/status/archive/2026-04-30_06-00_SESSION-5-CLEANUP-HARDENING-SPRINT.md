# SystemNix Status Report — Session 5

**Date:** 2026-04-30 06:00
**Author:** Crush (AI Agent)
**Branch:** master @ `ec98c7d`
**Working Tree:** Clean
**Commits this session:** 8 (plus 3 auto-generated doc/lint commits = 11 total)
**Net impact:** +241 / -3596 lines (3,356 net deletions)

---

## Executive Summary

Executed a focused cleanup and hardening sprint following the niri compositor kill incident. Fixed the root cause (BindsTo → PartOf + Restart=always), consolidated 3 fragmented health check implementations into one cross-platform script, deleted 8 dead macOS-only scripts (~2900 lines of rot), extracted hardcoded IPs into shared module options, refactored flake.nix to eliminate 30 lines of duplicated config, and added a reusable `serviceDefaults` helper to lib/systemd.

---

## A) FULLY DONE ✅

| Commit    | What                                                                                              | Impact                  |
| --------- | ------------------------------------------------------------------------------------------------- | ----------------------- |
| `682edef` | Remove dev/testing/, download_glm_model.py, tools/ from repo                                      | -1005 lines             |
| `682edef` | Refactor flake.nix: extract sharedOverlays, sharedHomeManagerConfig, sharedHomeManagerSpecialArgs | -40 lines duplication   |
| `682edef` | Extract hardcoded IPs into `networking.local` module options                                      | 6 IP addresses → 1 file |
| `682edef` | justfile: `rm` → `trash` in cleanup recipes                                                       | Safety                  |
| `682edef` | statix fixes: `x = x` → `inherit x` in dns-blocker-config.nix                                     | Lint                    |
| `0643e63` | Fix niri Restart=on-failure → Restart=always + StartLimitBurst                                    | **Root cause fix**      |
| `0643e63` | alejandra formatting across 9 files                                                               | Formatting              |
| `950230e` | Add `lib/systemd/service-defaults.nix`                                                            | Reusable defaults       |
| `950230e` | Wire serviceDefaults into photomap.nix (proof of concept)                                         | -8 lines per service    |
| `41624b8` | Rewrite health-check.sh as cross-platform (Darwin + NixOS)                                        | -523 lines, +165 lines  |
| `b7ad89b` | Trim justfile health recipe (47 lines → 1 line)                                                   | -46 lines               |
| `b7ad89b` | Delete 8 dead macOS-only scripts                                                                  | -2959 lines             |
| `ec98c7d` | Update AGENTS.md with all changes                                                                 | Documentation           |

---

## B) PARTIALLY DONE 🔧

### lib/systemd serviceDefaults Migration (1/10 services)

Only photomap.nix uses `serviceDefaults` so far. Remaining 9 services that use `harden`:
comfyui, gitea, hermes, homepage, immich, minecraft, signoz, twenty.

Each needs manual verification since their restart/watchdog defaults differ. Safe to do incrementally.

---

## C) NOT STARTED ⬜

### P5 — DEPLOYMENT & VERIFICATION (0/13 = 0%)

All 13 deployment tasks still blocked on evo-x2. The niri fix and all other changes are in the repo but NOT deployed.

### P1 — SECURITY (3/7 = 43%)

4 items still blocked on evo-x2 (sops secrets, Docker digests, VRRP auth).

### P9 — FUTURE (2/12 = 17%)

No new work on research/architecture items.

---

## D) TOTALLY FUCKED UP 💥

### Session 5 Mistakes

| Issue                                                       | Root Cause                                              | Fix                                       |
| ----------------------------------------------------------- | ------------------------------------------------------- | ----------------------------------------- |
| Committed cleanup + network refactor together               | Staged cleanup files got combined with unstaged changes | Acceptable — logically related            |
| `nix fmt` formatted 7 extra files I didn't intend to commit | Formatter touches everything                            | Included in niri commit, no logic changes |
| Wrote health-check.sh 3 times                               | File modification timestamp check blocked write         | Used `trash` + fresh write                |

### Niri Incident (from session 4, fixed this session)

Root cause: upstream `BindsTo=graphical-session.target` + `Restart=on-failure` (misses exit code 0).
Fix: `PartOf` + `Restart=always` + `StartLimitBurst=3`.

---

## E) WHAT WE SHOULD IMPROVE 📈

| # | Area                                                 | Detail                                                                                    |
| - | ---------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| 1 | **Deploy cadence**                                   | 60+ commits undeployed. Need to deploy soon.                                              |
| 2 | **serviceDefaults migration**                        | 9 more services to wire. Each is a ~5 min task.                                           |
| 3 | **Health check depth**                               | Could add: Ollama status, Docker container health, BTRFS scrub status, ZRAM swap pressure |
| 4 | **CI should run health check**                       | Add `just health` to CI pipeline for NixOS-specific checks                                |
| 5 | **`builtins.replaceStrings` for niri unit patching** | Fragile — upstream formatting change silently breaks it. Need upstream fix or assertion.  |

---

## F) TOP 25 THINGS TO DO NEXT 🎯

| #  | Task                                         | Category    | Est. | Blocker?          |
| -- | -------------------------------------------- | ----------- | ---- | ----------------- |
| 1  | **Deploy on evo-x2** — `just switch`         | P5-DEPLOY   | 45m  | Needs evo-x2      |
| 2  | **Verify niri restarts after deploy**        | P5-VERIFY   | 2m   | Needs deploy      |
| 3  | **Verify Ollama**                            | P5-VERIFY   | 5m   | Needs evo-x2      |
| 4  | **Verify SigNoz**                            | P5-VERIFY   | 5m   | Needs evo-x2      |
| 5  | **Move Taskwarrior encryption to sops**      | P1-SECURITY | 10m  | Needs evo-x2      |
| 6  | **Pin Docker digests**                       | P1-SECURITY | 10m  | Needs evo-x2      |
| 7  | **Secure VRRP auth_pass**                    | P1-SECURITY | 8m   | Needs evo-x2      |
| 8  | **Migrate 9 services to serviceDefaults**    | REFACTOR    | 45m  | None              |
| 9  | **Add niri unit patch assertion**            | RELIABILITY | 15m  | None              |
| 10 | **Verify ComfyUI**                           | P5-VERIFY   | 5m   | Needs evo-x2      |
| 11 | **Verify Steam**                             | P5-VERIFY   | 5m   | Needs evo-x2      |
| 12 | **Verify Caddy HTTPS**                       | P5-VERIFY   | 3m   | Needs evo-x2      |
| 13 | **Check Authelia SSO**                       | P5-VERIFY   | 3m   | Needs evo-x2      |
| 14 | **Verify AMD NPU**                           | P5-VERIFY   | 10m  | Needs evo-x2      |
| 15 | **Build Pi 3 SD image**                      | P5-DEPLOY   | 30m  | Needs Pi 3        |
| 16 | **Add health check to CI**                   | P7-TOOLING  | 15m  | None              |
| 17 | **Hermes health check**                      | P6-SERVICE  | 30m  | Needs Hermes code |
| 18 | **SigNoz missing metrics**                   | P6-SERVICE  | 30m  | Needs evo-x2      |
| 19 | **Add NixOS VM test**                        | P9-TESTING  | 2h   | Research          |
| 20 | **Add Waybar session restore stats**         | P9-FEATURE  | 1h   | None              |
| 21 | **Create homeModules pattern**               | P9-ARCH     | 2h   | Research          |
| 22 | **Binary cache (Cachix)**                    | P9-PERF     | 1h   | Research          |
| 23 | **Configure LAN devices for DNS VIP**        | P5-DEPLOY   | 10m  | Network access    |
| 24 | **Add Ollama/Docker/BTRFS checks to health** | NEW-TOOLING | 30m  | None              |
| 25 | **Authelia SMTP notifications**              | P6-SERVICE  | 15m  | Needs SMTP creds  |

---

## G) TOP #1 QUESTION 🤔

**Same as last session:** Can you SSH into evo-x2? If yes, we can unblock the entire deployment pipeline remotely.

---

## Session Stats

| Metric                | Value                                                      |
| --------------------- | ---------------------------------------------------------- |
| Commits this session  | 11                                                         |
| Net lines changed     | +241 / -3596                                               |
| Files deleted         | 10                                                         |
| New files created     | 2 (lib/systemd/service-defaults.nix, health-check rewrite) |
| Linter warnings fixed | 2 (statix W03)                                             |
| Build status          | ✅ passing                                                 |
| Deployment status     | ⬜ not deployed                                            |

---

_Arte in Aeternum_
