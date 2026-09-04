# SystemNix Comprehensive Status Report — Session 4

**Date:** 2026-04-30 04:48
**Author:** Crush (AI Agent)
**Branch:** master @ `85e12da` (1 ahead of origin)
**Working Tree:** 1 staged change — `modules/nixos/services/niri-config.nix` (niri restart fix)
**Codebase:** 97 Nix files, 12,826 lines, 1,891 total commits, 28 service modules

---

## Executive Summary

**CRITICAL INCIDENT RESOLVED:** `just switch` (flake.lock update `09f0ebc`) killed the running niri compositor and it did NOT restart. User was dumped to a TTY with no graphical session. Root cause: upstream niri systemd unit uses `BindsTo=graphical-session.target` — when systemd rewrites the unit during a NixOS rebuild, it SIGTERMs niri, which tears down `graphical-session.target`, and `BindsTo` prevents systemd from ever restarting it. **Fix is staged but NOT YET DEPLOYED** — requires another `just switch` (which, ironically, requires a working compositor or TTY deploy).

Project sits at **65% MASTER_TODO_PLAN completion (62/95 tasks)**. All critical, reliability, code quality, architecture, tooling, and documentation categories remain at 100%. The niri restart fix is the only new work this session.

**55 commits in the last 4 days** (since 2026-04-27).

---

## A) FULLY DONE ✅

### Session 4 — Niri Compositor Restart Fix (this session)

| What                                                         | File(s)                                  | Detail                                                                                                                                                         |
| ------------------------------------------------------------ | ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Diagnosed niri crash after `just switch`                     | `journalctl --user -u niri`              | Niri was SIGTERMd at 04:22:01 — systemd stopped it during HM activation, `BindsTo` prevented restart                                                           |
| Patched `niri.service` unit to auto-restart                  | `modules/nixos/services/niri-config.nix` | Replaced `BindsTo=graphical-session.target` → `PartOf=graphical-session.target` + `Restart=on-failure` + `RestartSec=2s` + `WantedBy=graphical-session.target` |
| Verified syntax                                              | `just test-fast`                         | All checks passed                                                                                                                                              |
| **NOT YET DEPLOYED** — fix is staged, awaiting `just switch` |                                          |                                                                                                                                                                |

### Previous Sessions (commits `77df26e` → `85e12da`)

| Session                           | Commits | Highlights                                                                                                      |
| --------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------- |
| Session 1 — UI/UX Audit           | 5       | Catppuccin Mocha across waybar/fzf/starship/homepage, visual bell, dunst history                                |
| Session 2 — Self-reflection fixes | 13      | Homepage CSS, dunst icons, FZF colors, duplicate packages, Minecraft firewall, waybar disk module, niri keybind |
| Session 3 — Direnv/flake fixes    | 3       | Corrupted direnv profile, nix-colors follows warning, nix-ssh-config duplicate                                  |

### Historical — 100% Complete Categories (62/95 total tasks)

| Priority | Category      | Done | Total |
| -------- | ------------- | ---- | ----- |
| P0       | Critical      | 6    | 6 ✅  |
| P2       | Reliability   | 11   | 11 ✅ |
| P3       | Code Quality  | 9    | 9 ✅  |
| P4       | Architecture  | 7    | 7 ✅  |
| P7       | Tooling & CI  | 10   | 10 ✅ |
| P8       | Documentation | 5    | 5 ✅  |

---

## B) PARTIALLY DONE 🔧

### Session 4 — Niri Fix (DEPLOYMENT PENDING)

The niri restart fix is **coded and staged but not deployed**. This is a catch-22:

- Deploying the fix requires `just switch`
- `just switch` is what killed niri in the first place
- User is currently on a TTY (no graphical session)

**Recovery path:** Run `just switch` from TTY, then either `systemctl --user start niri` or log back in via SDDM. After this deploy, future `just switch` will no longer kill niri permanently.

### P1 — SECURITY (3/7 = 43%)

| #  | Task                                           | Status     | Blocker                                     |
| -- | ---------------------------------------------- | ---------- | ------------------------------------------- |
| 7  | Move Taskwarrior encryption secret to sops-nix | ⬜ BLOCKED | Needs evo-x2 for sops secret creation       |
| 9  | Pin Docker digest for Voice Agents             | ⬜ BLOCKED | Version-tagged, needs evo-x2 to pull SHA256 |
| 10 | Pin Docker digest for PhotoMap                 | ⬜ BLOCKED | Version-tagged, needs evo-x2 to pull SHA256 |
| 11 | Secure VRRP auth_pass with sops-nix            | ⬜ BLOCKED | Needs evo-x2 for sops secret                |

### P6 — SERVICES (9/15 = 60%)

| #  | Task                        | Status                                              |
| -- | --------------------------- | --------------------------------------------------- |
| 56 | ComfyUI hardcoded paths     | ACCEPTABLE — module defaults designed for override  |
| 58 | ComfyUI dedicated user      | ACCEPTABLE — needs lars for GPU groups              |
| 62 | Hermes health check         | PENDING — needs Hermes code change                  |
| 63 | Hermes key_env migration    | PENDING — low risk cleanup                          |
| 65 | SigNoz missing metrics      | BLOCKED — needs evo-x2 metric endpoint verification |
| 66 | Authelia SMTP notifications | BLOCKED — needs SMTP credentials                    |

### P9 — FUTURE (2/12 = 17%)

Investigated: #85 (just test race — documented), #90 (SSH config migration — documented).
Remaining 10 are research/architecture items with no immediate deadline.

---

## C) NOT STARTED ⬜

### P5 — DEPLOYMENT & VERIFICATION (0/13 = 0%)

ALL 13 tasks require evo-x2 physical access. The niri fix makes this MORE urgent — we have 55+ commits of undeployed changes.

| #  | Task                                                 | Est. |
| -- | ---------------------------------------------------- | ---- |
| 41 | `just switch` — deploy all pending changes to evo-x2 | 45m+ |
| 42 | Verify Ollama works after rebuild                    | 5m   |
| 43 | Verify Steam works after rebuild                     | 5m   |
| 44 | Verify ComfyUI works after rebuild                   | 5m   |
| 45 | Verify Caddy HTTPS block page                        | 3m   |
| 46 | Verify SigNoz collecting metrics/logs/traces         | 5m   |
| 47 | Check Authelia SSO status                            | 3m   |
| 48 | Check PhotoMap service status                        | 3m   |
| 49 | Verify AMD NPU with test workload                    | 10m  |
| 50 | Build Pi 3 SD image                                  | 30m+ |
| 51 | Flash SD + boot Pi 3                                 | 15m  |
| 52 | Test DNS failover                                    | 10m  |
| 53 | Configure LAN devices for DNS VIP                    | 10m  |

---

## D) TOTALLY FUCKED UP 💥

### Session 4 — The Niri Incident

| Issue                                       | Root Cause                                                                                                                                | Impact                                                                  | Fix                                                               |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **Niri compositor killed by `just switch`** | Upstream `niri.service` uses `BindsTo=graphical-session.target` — systemd stops niri during unit file rewrite, `BindsTo` prevents restart | User dumped to TTY with no GUI, no way to recover without TTY knowledge | Replaced `BindsTo` → `PartOf` + `Restart=on-failure` + `WantedBy` |

**Timeline of the incident:**

1. `04:22:01` — `nixos-rebuild switch` triggers HM activation
2. HM rewrites `niri.service` unit file (niri package path changed in flake.lock update)
3. systemd stops old niri process (SIGTERM)
4. `graphical-session.target` goes down (because niri provides it)
5. `BindsTo` binding breaks — systemd will NOT restart niri
6. User sees black screen / TTY login prompt
7. No SDDM restart because niri IS the session — there's nothing to fall back to

**Why this is especially bad:** The niri flake.lock update (`09f0ebc`) bumped niri from one unstable version to another (both `niri-unstable-2026-04-*`). The package path changed, which is enough to trigger a unit file rewrite and service restart. This can happen on ANY flake.lock update that touches niri or its transitive dependencies.

**Why it wasn't caught before:** The previous 54 commits didn't change the niri package path. The flake.lock update happened to bump niri's commit hash this time.

### Session 3 Self-Inflicted Wounds (all caught and fixed)

| Issue                             | Root Cause                           | Fix                          |
| --------------------------------- | ------------------------------------ | ---------------------------- |
| `.direnv/flake-profile` corrupted | Unknown (possibly interrupted build) | Trashed and rebuilt          |
| `nix-colors` follows warning      | Added follows for non-existent input | Removed follows line         |
| `nix-ssh-config` etc duplicate    | Upstream bug                         | Fixed in nix-ssh-config repo |

### Session 2 Self-Inflicted Wounds (all caught and fixed)

| Issue                           | Root Cause                          | Fix                               |
| ------------------------------- | ----------------------------------- | --------------------------------- |
| Homepage CSS in `settings.yaml` | YAML multi-line mangling            | Moved to `custom.css` file        |
| Dunst broken icons              | Hardcoded `/usr/share/icons/` paths | Changed to theme-resolvable names |
| FZF hardcoded hex colors        | Didn't use `colorScheme.palette`    | Refactored to palette reference   |

**Pattern across all 4 sessions:** Every session introduces 1-3 regressions. The niri incident is the most severe — it's not a code regression but a **missing resilience mechanism**. The self-reflection loop catches code bugs but can't catch "systemd won't restart my compositor" because that only manifests on a live deploy.

---

## E) WHAT WE SHOULD IMPROVE 📈

| #  | Area                                          | Problem                                                    | Proposed Fix                                                                                                                                                                                  |
| -- | --------------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | **Compositor resilience**                     | Niri can be killed by any rebuild that touches its package | DONE (this session) — `PartOf` + `Restart=on-failure`. But needs deploy.                                                                                                                      |
| 2  | **Deploy safety net**                         | No fallback if compositor dies during rebuild              | Add `just safe-switch` that runs rebuild in background and only activates after verifying the new config builds. Or add a systemd rescue target that auto-starts niri after a failed rebuild. |
| 3  | **Regression rate**                           | Each session introduces 1-3 regressions                    | Add `nix flake check --no-build` as mandatory gate. The self-reflection loop works for code bugs but misses runtime issues.                                                                   |
| 4  | **No integration testing**                    | Zero automated verification that services work together    | Add NixOS VM tests for critical services. Even one smoke test would catch compositor restart failures.                                                                                        |
| 5  | **Deployment bottleneck**                     | 13 tasks + niri fix blocked on evo-x2                      | Consider SSH-based remote deploy (`just deploy-remote`).                                                                                                                                      |
| 6  | **Flake evaluation speed**                    | `nix flake check` evaluates everything                     | Add `--systems x86_64-linux` to skip darwin evaluation on Linux.                                                                                                                              |
| 7  | **Direnv robustness**                         | Corrupted profiles silently break dev env                  | Add `just doctor` command checking direnv health.                                                                                                                                             |
| 8  | **Secret management gaps**                    | 4 security items still using hardcoded/plaintext secrets   | Prioritize sops migration for Taskwarrior and VRRP auth.                                                                                                                                      |
| 9  | **Missing: compositor-specific deploy guard** | Niri is special — it IS the session                        | Add a justfile check: before `switch`, verify niri package path didn't change. If it did, warn the user or auto-add `Restart=on-failure` verification.                                        |
| 10 | **AGENTS.md outdated for niri**               | AGENTS.md doesn't document the `BindsTo` risk or the fix   | Update AGENTS.md with the niri restart behavior and recovery steps.                                                                                                                           |

---

## F) TOP 25 THINGS TO DO NEXT 🎯

Ordered by urgency × impact × feasibility:

| #      | Task                                                      | Category    | Est. | Blocker?            | Why                                         |
| ------ | --------------------------------------------------------- | ----------- | ---- | ------------------- | ------------------------------------------- |
| **1**  | **Deploy niri fix via `just switch` from TTY**            | URGENT      | 45m  | User on TTY NOW     | Fixes compositor kill. 55+ commits waiting. |
| **2**  | **Verify niri restarts after deploy**                     | URGENT      | 2m   | Needs deploy        | Confirm the fix works.                      |
| **3**  | **Verify Ollama works** after rebuild                     | P5-VERIFY   | 5m   | Needs evo-x2        | Core AI service.                            |
| **4**  | **Verify SigNoz** collecting metrics/logs/traces          | P5-VERIFY   | 5m   | Needs evo-x2        | Observability backbone.                     |
| **5**  | **Move Taskwarrior encryption to sops-nix**               | P1-SECURITY | 10m  | Needs evo-x2        | Quick security win.                         |
| **6**  | **Pin Docker digests** for Voice Agents + PhotoMap        | P1-SECURITY | 10m  | Needs evo-x2        | Supply chain safety.                        |
| **7**  | **Secure VRRP auth_pass** with sops-nix                   | P1-SECURITY | 8m   | Needs evo-x2        | Plaintext secret in repo.                   |
| **8**  | **Update AGENTS.md** with niri restart behavior           | P8-DOCS     | 5m   | None                | Prevent future confusion.                   |
| **9**  | **Add `just doctor`** — direnv/flake/git health check     | NEW-TOOLING | 15m  | None                | Prevent silent corruption.                  |
| **10** | **Add `just safe-switch`** — deploy with compositor guard | NEW-TOOLING | 20m  | None                | Prevent compositor kill on future switches. |
| **11** | **Verify ComfyUI** after rebuild                          | P5-VERIFY   | 5m   | Needs evo-x2        | GPU workload.                               |
| **12** | **Verify Steam** after rebuild                            | P5-VERIFY   | 5m   | Needs evo-x2        | Proton/GPU.                                 |
| **13** | **Verify Caddy HTTPS** block page                         | P5-VERIFY   | 3m   | Needs evo-x2        | DNS blocker visual.                         |
| **14** | **Check Authelia SSO** status                             | P5-VERIFY   | 3m   | Needs evo-x2        | Auth layer.                                 |
| **15** | **Verify AMD NPU** with test workload                     | P5-VERIFY   | 10m  | Needs evo-x2        | Hardware verification.                      |
| **16** | **Build Pi 3 SD image**                                   | P5-DEPLOY   | 30m  | Needs Pi 3 hardware | DNS failover.                               |
| **17** | **Flash SD + boot Pi 3**                                  | P5-DEPLOY   | 15m  | Needs Pi 3 hardware | DNS failover.                               |
| **18** | **Test DNS failover** between evo-x2 and Pi 3             | P5-VERIFY   | 10m  | Needs Pi 3          | Reliability.                                |
| **19** | **Hermes health check** endpoint                          | P6-SERVICE  | 30m  | Needs Hermes code   | Observability.                              |
| **20** | **SigNoz missing metrics** — add scraping for services    | P6-SERVICE  | 30m  | Needs evo-x2        | Full observability.                         |
| **21** | **Add NixOS VM test** for at least one critical service   | P9-TESTING  | 2h   | Research            | Prevent deploy surprises.                   |
| **22** | **Add Waybar module** for session restore stats           | P9-FEATURE  | 1h   | None                | UX polish.                                  |
| **23** | **Create homeModules pattern** for HM via flake-parts     | P9-ARCH     | 2h   | Research            | Architecture improvement.                   |
| **24** | **Investigate binary cache (Cachix)** for faster builds   | P9-PERF     | 1h   | Research            | Build speed.                                |
| **25** | **Configure LAN devices** for DNS VIP                     | P5-DEPLOY   | 10m  | Network access      | DNS failover complete.                      |

---

## G) TOP #1 QUESTION 🤔

**Are you currently on a TTY on evo-x2?**

If yes → run `just switch` right now, then `systemctl --user start niri` or log in via SDDM. The fix will be deployed and you'll be back in niri within minutes.

If you're on a different machine → we need to SSH into evo-x2 or you need to go to the physical machine. All deployment (including this critical fix) requires evo-x2 access.

---

## Incident Detail: Niri BindsTo Kill Chain

```
just switch
  └─ nixos-rebuild switch
      └─ HM activation writes new niri.service
          └─ systemd detects unit file changed
              └─ SIGTERM to old niri process
                  └─ graphical-session.target goes down
                      └─ BindsTo binding breaks
                          └─ systemd WILL NOT restart niri
                              └─ User sees TTY. No GUI. No recovery.
```

**After fix:**

```
just switch
  └─ nixos-rebuild switch
      └─ HM activation writes new niri.service
          └─ systemd detects unit file changed
              └─ SIGTERM to old niri process
                  └─ graphical-session.target goes down
                      └─ PartOf means niri is just "part of" it (not bound)
                          └─ Restart=on-failure triggers after 2s
                              └─ Niri restarts. graphical-session.target comes back up.
                                  └─ All services resume. User sees niri again.
```

---

## Session Stats

| Metric                 | Value                     |
| ---------------------- | ------------------------- |
| Sessions today         | 4                         |
| Commits today (so far) | 18 (17 prev + 1 pending)  |
| Commits since Apr 27   | 55                        |
| Total commits          | 1,891                     |
| Nix files              | 97                        |
| Lines of Nix           | 12,826                    |
| Service modules        | 28                        |
| Custom packages        | 7+1 (dnsblockd-processor) |
| Tasks done / total     | 62 / 95 (65%)             |
| Blocking issues        | 1 (niri fix not deployed) |
| Known regressions      | 0 (working tree staged)   |
| Undeployed commits     | 55+                       |

---

_Arte in Aeternum_
