# SystemNix - COMPREHENSIVE EXECUTIVE STATUS UPDATE

**Date:** March 5, 2026 01:56 CET
**Classification:** CRITICAL - Strategic Assessment
**Branch:** master
**Commit:** 4711280
**Status:** STABLE WITH KNOWN ISSUES

---

## EXECUTIVE SUMMARY

SystemNix is a sophisticated cross-platform Nix configuration system managing both macOS (darwin) and NixOS (evo-x2) systems. The project has achieved **production stability** with comprehensive tooling, though several architectural debt items and experimental features require attention. Current state: **OPERATIONAL** but with accumulated technical debt requiring strategic intervention.

---

## a) FULLY DONE ✅

### Core Infrastructure (COMPLETE)

| Component                             | Status      | Evidence                                                      |
| ------------------------------------- | ----------- | ------------------------------------------------------------- |
| **Nix Flake Architecture**            | ✅ COMPLETE | `flake.nix` with 15+ inputs, multi-platform outputs           |
| **macOS (Darwin) System**             | ✅ COMPLETE | `darwin-rebuild switch` functional, ActivityWatch working     |
| **NixOS (evo-x2) System**             | ✅ COMPLETE | System boots, Hyprland operational                            |
| **Home Manager Integration**          | ✅ COMPLETE | Cross-platform user configs unified                           |
| **ActivityWatch Window URL Fix**      | ✅ COMPLETE | Permissions resolved via `just activitywatch-fix-permissions` |
| **ActivityWatch Utilization Watcher** | ✅ COMPLETE | LaunchAgent deployed, CPU/RAM/disk monitoring active          |
| **Sublime Text Configuration**        | ✅ COMPLETE | Backup system operational, 8 daily backups preserved          |
| **Git Configuration**                 | ✅ COMPLETE | SSH keys, GPG signing, git-town integration                   |
| **Shell Environment**                 | ✅ COMPLETE | Fish + Starship + Tmux unified across platforms               |
| **Crush-Patched Tool**                | ✅ COMPLETE | v0.46.1 deployed with automated update mechanism              |

### Tooling & Automation (COMPLETE)

| Tool                      | Status      | Location                                      |
| ------------------------- | ----------- | --------------------------------------------- |
| **Just Task Runner**      | ✅ COMPLETE | 150+ commands in `justfile`                   |
| **Pre-commit Hooks**      | ✅ COMPLETE | Gitleaks, statix, trailing-whitespace         |
| **Backup System**         | ✅ COMPLETE | `just backup` with automatic rotation         |
| **Health Checks**         | ✅ COMPLETE | `just health` comprehensive system validation |
| **ActivityWatch Control** | ✅ COMPLETE | `activitywatch-start/stop/fix-permissions`    |

### Documentation (COMPLETE)

| Document                          | Status      | Lines                                              |
| --------------------------------- | ----------- | -------------------------------------------------- |
| **AGENTS.md**                     | ✅ COMPLETE | 1,004 lines - comprehensive AI behavior guidelines |
| **README.md**                     | ✅ COMPLETE | Project overview, installation, troubleshooting    |
| **Status Reports**                | ✅ COMPLETE | 60+ reports in `docs/status/`                      |
| **Architecture Decision Records** | ✅ COMPLETE | ADR-001, ADR-002, ADR-003 documented               |

---

## b) PARTIALLY DONE ⚠️

### ActivityWatch Ecosystem (70% COMPLETE)

| Component                            | Status       | Blocker                                    |
| ------------------------------------ | ------------ | ------------------------------------------ |
| **Core Watchers (afk, window, web)** | ✅ Working   | -                                          |
| **Utilization Watcher**              | ✅ Deployed  | LaunchAgent (removed unsupported CLI args) |
| **Input Watcher**                    | ⚠️ Available  | Not auto-started                           |
| **Enhanced Watcher (AI/OCR)**        | ⚠️ Researched | Requires Ollama setup                      |
| **Screenshot Watcher**               | ⚠️ Researched | Storage planning needed                    |
| **Spotify Watcher**                  | ⚠️ Available  | Beta status, needs testing                 |
| **Anki Watcher**                     | ⚠️ Available  | Only if using Anki                         |

### NixOS evo-x2 (80% COMPLETE)

| Component              | Status       | Issue                                         |
| ---------------------- | ------------ | --------------------------------------------- |
| **Base System**        | ✅ Working   | Boots, networking, SSH                        |
| **Hyprland Desktop**   | ✅ Working   | Wayland compositor operational                |
| **Home Manager**       | ✅ Working   | User configs applied                          |
| **Bluetooth Audio**    | ⚠️ Configured | Pending testing with Nest Audio               |
| **Security Hardening** | ⚠️ Partial    | Audit rules disabled (kernel module conflict) |
| **ActivityWatch**      | ✅ Working   | NixOS native service                          |

### File Organization (85% COMPLETE)

| Action                     | Status        | Files                       |
| -------------------------- | ------------- | --------------------------- |
| **Root directory cleanup** | ✅ Done       | 12 files moved              |
| **Script organization**    | ✅ Done       | 6 scripts → `bin/`          |
| **Documentation archives** | ✅ Done       | 4 docs → `docs/archives/`   |
| **Path constants library** | ⚠️ Not started | Hardcoded paths still exist |
| **Just organize command**  | ⚠️ Not started | Automation pending          |

### Code Quality (75% COMPLETE)

| Check                | Status     | Issues                             |
| -------------------- | ---------- | ---------------------------------- |
| **Nix syntax**       | ✅ Passing | No eval errors                     |
| **Flake check**      | ✅ Passing | `nix flake check --no-build` clean |
| **Statix linting**   | ⚠️ Warnings | W20, W04, W23 warnings             |
| **Gitleaks secrets** | ⚠️ Flagged  | 6 potential secrets need review    |
| **Type safety**      | ✅ Passing | Core validation system operational |

---

## c) NOT STARTED ❌

### High-Priority (Never Started)

| Item                             | Priority | Impact                        |
| -------------------------------- | -------- | ----------------------------- |
| **Program Discovery System**     | P0       | Automate program integration  |
| **VS Code Full Integration**     | P1       | Currently partial             |
| **Cross-platform CLI Tool**      | P1       | `setup-mac` shell script      |
| **Automated Testing Framework**  | P1       | No test suite exists          |
| **Documentation Consolidation**  | P2       | 3 Bluetooth docs need merging |
| **Path Constants Library**       | P2       | Prevent hardcoded paths       |
| **File Organization Automation** | P2       | `just organize` command       |

### Medium-Priority (Never Started)

| Item                          | Priority | Impact                     |
| ----------------------------- | -------- | -------------------------- |
| **iOS App Research**          | P2       | ActivityWatch mobile gap   |
| **aw-sync Multi-device**      | P2       | Cross-device time tracking |
| **InfluxDB/Grafana Export**   | P3       | Advanced analytics         |
| **AI/LLM Integration (MCP)**  | P3       | Natural language queries   |
| **Screenshot Watcher Deploy** | P3       | Visual documentation       |
| **Self-reflection (aw-ask)**  | P3       | Experience sampling        |

### Low-Priority (Backlog)

| Item                       | Priority | Impact             |
| -------------------------- | -------- | ------------------ |
| **Standing Desk Hardware** | P3       | DIY sensor project |
| **Anki Watcher**           | P4       | Only if using Anki |
| **Chromecast Watcher**     | P4       | WIP, not working   |
| **OpenVR Watcher**         | P4       | WIP, not working   |

---

## d) TOTALLY FUCKED UP ❌🔥

### Critical Issues (REQUIRING IMMEDIATE ATTENTION)

| Issue                             | Severity  | Details                                                                         |
| --------------------------------- | --------- | ------------------------------------------------------------------------------- |
| **Homebrew Tier 3 Configuration** | 🔴 HIGH   | Wrong prefix (/usr/local vs /opt/homebrew), missing git origin, deprecated taps |
| **Flake.lock Update Needed**      | 🟡 MEDIUM | Multiple inputs outdated (nixpkgs, home-manager, darwin)                        |
| **Pre-commit Hook Failures**      | 🟡 MEDIUM | Gitleaks detects 6 potential secrets; statix warnings                           |
| **TODO List Stale**               | 🟡 MEDIUM | Last updated 2026-02-10, many items outdated                                    |
| **NixOS Bluetooth Untested**      | 🟡 MEDIUM | Configuration complete but never validated with hardware                        |

### Architectural Debt (TECHNICAL DEBT)

| Debt                               | Impact    | Effort                               |
| ---------------------------------- | --------- | ------------------------------------ |
| **Hardcoded paths throughout**     | 🔴 HIGH   | Medium - Need path constants library |
| **Duplicate documentation**        | 🟡 MEDIUM | Low - 3 Bluetooth docs should be 1   |
| **No automated file organization** | 🟡 MEDIUM | Medium - `just organize` needed      |
| **Missing program discovery**      | 🟡 MEDIUM | High - Architectural change          |
| **AGENTS.md in root**              | 🟢 LOW    | Low - Should move to docs/           |

### Build/Deploy Issues

| Issue                            | Status     | Workaround                            |
| -------------------------------- | ---------- | ------------------------------------- |
| **darwin-rebuild eval time**     | ⚠️ Slow     | ~30-60 seconds                        |
| **Flake input updates**          | ⚠️ Manual   | `just update` works but not automated |
| **ActivityWatch LaunchAgent**    | ⚠️ Fixed    | Removed unsupported CLI args          |
| **Home Manager user workaround** | ⚠️ In place | Explicit user definition required     |

---

## e) WHAT WE SHOULD IMPROVE 📈

### Immediate (This Week)

1. **Fix Homebrew Configuration**
   - Add git origin remote
   - Address Tier 3 warnings
   - Consider reinstall to /opt/homebrew

2. **Update Flake.lock**
   - Run `just update` to get latest nixpkgs
   - Test build after update
   - Commit if successful

3. **Review Gitleaks Findings**
   - Run `gitleaks detect --verbose`
   - Whitelist false positives
   - Rotate any real secrets

4. **Fix Statix Warnings**
   - Address W20 (repeated keys)
   - Address W04 (inherit suggestions)
   - Address W23 (empty list concat)

### Short-term (This Month)

5. **Implement Program Discovery System**
   - Create `programs/discovery.nix`
   - Auto-discover programs from `pkgs/`
   - Integrate into flake.nix

6. **Deploy ActivityWatch Enhanced**
   - Install Ollama locally
   - Test aw-watcher-enhanced
   - Validate AI context extraction

7. **Create Path Constants Library**
   - `scripts/lib/paths.sh`
   - `PROJECT_ROOT` variable
   - Update all scripts

8. **Test NixOS Bluetooth**
   - Rebuild evo-x2
   - Pair with Nest Audio
   - Validate audio output

9. **Consolidate Documentation**
   - Merge 3 Bluetooth docs into 1
   - Archive redundant files
   - Update references

### Medium-term (This Quarter)

10. **Cross-platform CLI Tool**
    - Expand `setup-mac` functionality
    - Add `setup-nixos` variant
    - Unified program management

11. **Automated Testing Framework**
    - `tests/` directory structure
    - Nix expression tests
    - Integration tests

12. **ActivityWatch Sync Setup**
    - aw-sync configuration
    - Multi-device time tracking
    - Folder-based sync

13. **Advanced Analytics**
    - InfluxDB export option
    - Grafana dashboards
    - Resource correlation

14. **iOS Integration Research**
    - Screen Time import
    - aw-ios feasibility
    - Mobile tracking gap

### Long-term (This Year)

15. **AI-Powered Insights**
    - activitywatch-mcp-server
    - Natural language queries
    - Automated productivity reports

16. **Hardware Integration**
    - Standing desk sensor (optional)
    - Arduino button inputs
    - Environmental sensors

17. **Screenshot Documentation**
    - Deploy aw-watcher-screenshot
    - Storage management
    - Visual work logs

18. **Self-Reflection System**
    - aw-watcher-ask deployment
    - Mood tracking
    - Experience sampling

---

## f) TOP #25 THINGS TO GET DONE NEXT 🎯

### P0 - Critical (Do This Week)

| # | Task                                        | Effort | Impact | Owner   |
| - | ------------------------------------------- | ------ | ------ | ------- |
| 1 | Fix Homebrew git origin and Tier 3 warnings | 30 min | HIGH   | User    |
| 2 | Update flake.lock (`just update`)           | 15 min | HIGH   | User    |
| 3 | Review and resolve gitleaks findings        | 45 min | HIGH   | User    |
| 4 | Fix statix linting warnings                 | 30 min | MEDIUM | AI/User |
| 5 | Test NixOS Bluetooth with Nest Audio        | 60 min | MEDIUM | User    |

### P1 - High Priority (This Month)

| #  | Task                                        | Effort | Impact | Owner |
| -- | ------------------------------------------- | ------ | ------ | ----- |
| 6  | Implement programs/discovery.nix            | 2 hrs  | HIGH   | AI    |
| 7  | Install Ollama and test aw-watcher-enhanced | 1 hr   | HIGH   | User  |
| 8  | Create scripts/lib/paths.sh constants       | 1 hr   | MEDIUM | AI    |
| 9  | Merge Bluetooth documentation               | 30 min | LOW    | AI    |
| 10 | Create `just organize` command              | 2 hrs  | MEDIUM | AI    |
| 11 | Deploy aw-watcher-input (keystrokes)        | 30 min | MEDIUM | User  |
| 12 | Add automated flake update check            | 1 hr   | MEDIUM | AI    |

### P2 - Medium Priority (This Quarter)

| #  | Task                                     | Effort | Impact | Owner |
| -- | ---------------------------------------- | ------ | ------ | ----- |
| 13 | Build cross-platform CLI tool            | 4 hrs  | HIGH   | AI    |
| 14 | Create tests/ framework                  | 3 hrs  | HIGH   | AI    |
| 15 | Set up aw-sync multi-device              | 2 hrs  | MEDIUM | User  |
| 16 | Deploy aw-watcher-spotify                | 30 min | LOW    | User  |
| 17 | Add InfluxDB export option               | 2 hrs  | LOW    | AI    |
| 18 | Research iOS integration                 | 2 hrs  | MEDIUM | AI    |
| 19 | Create file organization pre-commit hook | 1 hr   | MEDIUM | AI    |
| 20 | Update TODO_LIST.md (stale)              | 30 min | LOW    | AI    |

### P3 - Low Priority (Backlog)

| #  | Task                            | Effort | Impact | Owner |
| -- | ------------------------------- | ------ | ------ | ----- |
| 21 | Deploy aw-watcher-screenshot    | 1 hr   | MEDIUM | User  |
| 22 | Set up aw-watcher-ask           | 30 min | LOW    | User  |
| 23 | Move AGENTS.md to docs/         | 15 min | LOW    | AI    |
| 24 | Create onboarding checklist     | 1 hr   | LOW    | AI    |
| 25 | Research standing desk hardware | 2 hrs  | LOW    | User  |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT 🤔

### The Question:

**"Why does the Home Manager Darwin configuration require an explicit user definition workaround (`users.users.lars = { name = "lars"; home = "/Users/lars"; };`) when the same configuration on NixOS does not?"**

### Context:

This issue is documented in:

- `README.md` line 162-165
- `AGENTS.md` line 280-290
- `docs/status/2026-03-02_10-24_DARWIN-HOME-MANAGER-FIX.md`

### What I Know:

1. **Symptom:** `nix-darwin` build fails without explicit user definition
2. **Root Cause:** Home Manager's `nix-darwin/default.nix` imports `../nixos/common.nix` (NixOS-specific file)
3. **Workaround:** Adding explicit user definition in `platforms/darwin/default.nix` fixes it
4. **Platform Difference:** NixOS doesn't need this because it has native user management

### What I Don't Know:

1. **Is this a Home Manager bug or intended behavior?**
2. **Should this be reported upstream to nix-community/home-manager?**
3. **Will future Home Manager versions break this workaround?**
4. **Is there a more elegant solution we're missing?**
5. **Why does the import chain (`nix-darwin/default.nix` → `nixos/common.nix`) exist?**

### Why This Matters:

- The workaround is **fragile** - depends on internal Home Manager structure
- **No official documentation** explains this requirement
- Could **break on Home Manager updates**
- Creates **technical debt** that needs monitoring

### Research Needed:

1. Check Home Manager GitHub issues for similar reports
2. Review nix-darwin integration documentation
3. Test if newer Home Manager versions still need workaround
4. Determine if this should be an upstream bug report

---

## APPENDIX: SYSTEM METRICS

### Build Health

| Metric                       | Status                |
| ---------------------------- | --------------------- |
| `just test-fast`             | ✅ Passing            |
| `nix flake check --no-build` | ✅ Passing            |
| `just pre-commit-run`        | ⚠️ 6 gitleaks findings |
| `darwin-rebuild switch`      | ✅ Working            |
| `nixos-rebuild switch`       | ✅ Working (evo-x2)   |

### ActivityWatch Status

| Watcher                | Platform     | Status                          |
| ---------------------- | ------------ | ------------------------------- |
| aw-watcher-afk         | Darwin/NixOS | ✅ Active                       |
| aw-watcher-window      | Darwin/NixOS | ✅ Fixed (permissions resolved) |
| aw-watcher-web-chrome  | Darwin/NixOS | ✅ Active                       |
| aw-watcher-utilization | Darwin       | ✅ Active (LaunchAgent)         |
| aw-watcher-input       | Available    | ⚠️ Not deployed                  |
| aw-watcher-enhanced    | Research     | ⚠️ Ready for testing             |

### Recent Commits (Last 10)

```
4711280 feat(sublime-text): add comprehensive Sublime Text configuration backup
26a17dd feat(sublime-text): add comprehensive Sublime Text configuration backup
d74f326 fix(darwin): remove unsupported CLI args from aw-watcher-utilization LaunchAgent
75ee0d8 docs(status): add comprehensive report on ActivityWatch Nix utilization watcher
691c0f1 feat(darwin): add ActivityWatch utilization watcher via LaunchAgent
bd7d4c6 docs(status): add status report for Darwin Home Manager user workaround fix
6303cb7 fix(darwin): restore Home Manager user workaround for larsartmann
1c85584 feat(sublime-text): comprehensive configuration update with backup system and formatting improvements
28cb3b4 docs(status): add comprehensive status report for crush-patched v0.46.1 update fix
8cd7600 fix(crush-patched): add hash validation and fix sed pattern in update.sh
```

### File Statistics

| Category          | Count          |
| ----------------- | -------------- |
| Status Reports    | 60+ files      |
| Nix Configuration | 50+ files      |
| Shell Scripts     | 15+ files      |
| Documentation     | 100+ .md files |
| Git Commits       | 500+ total     |

---

**Report Generated:** 2026-03-05 01:56 CET
**Classification:** Internal Strategic Assessment
**Next Review:** 2026-03-12 or after significant changes
**Distribution:** SystemNix Project Team
