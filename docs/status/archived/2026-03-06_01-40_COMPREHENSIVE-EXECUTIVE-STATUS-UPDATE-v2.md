# SystemNix - COMPREHENSIVE EXECUTIVE STATUS UPDATE v2

**Date:** March 6, 2026 01:40 CET
**Classification:** CRITICAL - Strategic Assessment
**Branch:** master
**Commit:** 663a0d9
**Status:** STABLE - Homebrew Migration Analysis Complete

---

## EXECUTIVE SUMMARY

SystemNix remains operationally stable with comprehensive tooling. This update focuses on **Homebrew configuration analysis** following `just check` warnings. The project has achieved **production stability** with identified technical debt requiring strategic decisions.

**Key Finding:** Homebrew is misconfigured for Apple Silicon (Tier 3 at `/usr/local` instead of Tier 1 at `/opt/homebrew`). Migration path identified but requires user decision.

---

## a) FULLY DONE ✅

### Core Infrastructure (18 items)

| Component                      | Status      | Evidence                                                    |
| ------------------------------ | ----------- | ----------------------------------------------------------- |
| **Nix Flake Architecture**     | ✅ COMPLETE | Multi-platform outputs, 15+ inputs                          |
| **macOS (Darwin) System**      | ✅ COMPLETE | `darwin-rebuild switch` functional                          |
| **NixOS (evo-x2) System**      | ✅ COMPLETE | System boots, Hyprland operational                          |
| **Home Manager Integration**   | ✅ COMPLETE | Cross-platform user configs unified                         |
| **ActivityWatch Core**         | ✅ COMPLETE | Window URL fix, utilization watcher deployed                |
| **Sublime Text Configuration** | ✅ COMPLETE | Backup system with 8 daily snapshots                        |
| **Git Configuration**          | ✅ COMPLETE | SSH, GPG, git-town integration                              |
| **Shell Environment**          | ✅ COMPLETE | Fish + Starship + Tmux unified                              |
| **Crush-Patched Tool**         | ✅ COMPLETE | v0.46.1 with auto-update                                    |
| **Just Task Runner**           | ✅ COMPLETE | 150+ commands                                               |
| **Pre-commit Hooks**           | ✅ COMPLETE | Gitleaks, statix, trailing-whitespace                       |
| **Backup System**              | ✅ COMPLETE | `just backup` with rotation                                 |
| **Health Checks**              | ✅ COMPLETE | `just health` comprehensive validation                      |
| **Documentation**              | ✅ COMPLETE | 60+ status reports, AGENTS.md (1004 lines)                  |
| **Status Report v1**           | ✅ COMPLETE | `2026-03-05_01-56_COMPREHENSIVE-EXECUTIVE-STATUS-UPDATE.md` |
| **File Organization**          | ✅ COMPLETE | 12 files moved from root                                    |
| **Nix Syntax Validation**      | ✅ COMPLETE | `just test-fast` passing                                    |
| **Flake Check**                | ✅ COMPLETE | `nix flake check --no-build` clean                          |

### Recent Achievements (Last 48 Hours)

| Date       | Achievement                       | Commit  |
| ---------- | --------------------------------- | ------- |
| 2026-03-05 | Comprehensive status report v1    | 663a0d9 |
| 2026-03-04 | Sublime Text backup system        | 4711280 |
| 2026-03-02 | ActivityWatch utilization watcher | d74f326 |
| 2026-03-02 | Darwin Home Manager fix           | 6303cb7 |
| 2026-02-28 | Crush-patched v0.46.1 update      | 28cb3b4 |

---

## b) PARTIALLY DONE ⚠️

### ActivityWatch Ecosystem (70% COMPLETE)

| Component                        | Status      | Blocker                      |
| -------------------------------- | ----------- | ---------------------------- |
| Core watchers (afk, window, web) | ✅ Working  | -                            |
| Utilization watcher              | ✅ Deployed | LaunchAgent (CLI args fixed) |
| Input watcher                    | ⚠️ Available | Not auto-started             |
| Enhanced watcher (AI/OCR)        | ⚠️ Analyzed  | Requires Ollama setup        |
| Screenshot watcher               | ⚠️ Analyzed  | Storage planning needed      |
| Spotify watcher                  | ⚠️ Available | Beta status                  |
| Anki watcher                     | ⚠️ Available | Only if using Anki           |

### Homebrew Configuration (ANALYSIS COMPLETE, MIGRATION PENDING)

| Aspect              | Current              | Target                          | Status                         |
| ------------------- | -------------------- | ------------------------------- | ------------------------------ |
| **Prefix**          | `/usr/local` (Intel) | `/opt/homebrew` (Apple Silicon) | ⚠️ Migration planned            |
| **Git Origin**      | Missing              | `github.com/Homebrew/brew`      | ⚠️ Will auto-fix with migration |
| **Tier Status**     | Tier 3 (limited)     | Tier 1 (full support)           | ⚠️ Migration required           |
| **Deprecated Tap**  | `homebrew/bundle`    | Remove (now in core)            | ⚠️ Fix ready                    |
| **Directory Perms** | Root-owned           | User-owned                      | ⚠️ Will auto-fix                |

**Analysis Complete:** Migration path identified. Decision required from user.

### NixOS evo-x2 (80% COMPLETE)

| Component          | Status       | Issue                                  |
| ------------------ | ------------ | -------------------------------------- |
| Base System        | ✅ Working   | -                                      |
| Hyprland Desktop   | ✅ Working   | -                                      |
| Home Manager       | ✅ Working   | -                                      |
| Bluetooth Audio    | ⚠️ Configured | Pending testing with Nest Audio        |
| Security Hardening | ⚠️ Partial    | Audit rules disabled (kernel conflict) |

### Code Quality (75% COMPLETE)

| Check            | Status     | Issues                          |
| ---------------- | ---------- | ------------------------------- |
| Nix syntax       | ✅ Passing | No eval errors                  |
| Flake check      | ✅ Passing | Clean                           |
| Statix linting   | ⚠️ Warnings | W20, W04, W23                   |
| Gitleaks secrets | ⚠️ Flagged  | 6 potential secrets need review |

---

## c) NOT STARTED ❌

### High-Priority (P0-P1)

| Item                            | Priority | Impact | Dependencies      |
| ------------------------------- | -------- | ------ | ----------------- |
| **Homebrew Migration**          | P0       | HIGH   | User decision     |
| **Program Discovery System**    | P0       | HIGH   | None              |
| **VS Code Full Integration**    | P1       | HIGH   | Program discovery |
| **Cross-platform CLI Tool**     | P1       | HIGH   | None              |
| **Automated Testing Framework** | P1       | HIGH   | None              |
| **Gitleaks Review**             | P1       | HIGH   | None              |
| **Statix Warnings Fix**         | P1       | MEDIUM | None              |
| **NixOS Bluetooth Testing**     | P1       | MEDIUM | Hardware access   |

### Medium-Priority (P2)

| Item                             | Priority | Impact |
| -------------------------------- | -------- | ------ |
| **Documentation Consolidation**  | P2       | LOW    |
| **Path Constants Library**       | P2       | MEDIUM |
| **File Organization Automation** | P2       | MEDIUM |
| **iOS App Research**             | P2       | MEDIUM |
| **aw-sync Multi-device**         | P2       | MEDIUM |
| **InfluxDB/Grafana Export**      | P3       | LOW    |
| **AI/LLM Integration (MCP)**     | P3       | LOW    |

### Low-Priority (P3-P4)

| Item                          | Priority | Impact |
| ----------------------------- | -------- | ------ |
| **Screenshot Watcher Deploy** | P3       | MEDIUM |
| **Self-reflection (aw-ask)**  | P3       | LOW    |
| **Standing Desk Hardware**    | P4       | LOW    |
| **Anki Watcher**              | P4       | LOW    |

---

## d) TOTALLY FUCKED UP ❌🔥

### Critical Issues (REQUIRING IMMEDIATE ATTENTION)

| Issue                              | Severity  | Details                                         | Fix Status                       |
| ---------------------------------- | --------- | ----------------------------------------------- | -------------------------------- |
| **Homebrew Tier 3**                | 🔴 HIGH   | `/usr/local` on Apple Silicon = limited bottles | **Analyzed, ready to fix**       |
| **Homebrew Git Origin**            | 🔴 HIGH   | Missing origin remote, updates may fail         | **Will auto-fix with migration** |
| **Deprecated homebrew/bundle Tap** | 🟡 MEDIUM | Now in core, causes warnings                    | **Fix ready**                    |
| **6 Gitleaks Findings**            | 🟡 MEDIUM | Potential secrets need review                   | **Pending user review**          |
| **TODO_LIST.md Stale**             | 🟡 MEDIUM | Last updated 2026-02-10                         | **Pending update**               |

### Homebrew Deep Dive (THE BIG ONE)

**Current State (WRONG for Apple Silicon):**

```
Architecture: arm64 (Apple Silicon) ✅
Brew Prefix:  /usr/local (Intel location) ❌
Brew Binary:  /usr/local/bin/brew ❌
Tier Status:  Tier 3 (limited support) ❌
Git Origin:   MISSING ❌
```

**Target State (CORRECT):**

```
Architecture: arm64 (Apple Silicon) ✅
Brew Prefix:  /opt/homebrew (Apple Silicon location) ✅
Brew Binary:  /opt/homebrew/bin/brew ✅
Tier Status:  Tier 1 (full support) ✅
Git Origin:   github.com/Homebrew/brew ✅
```

**Why This Happened:**

- `nix-homebrew` with `autoMigrate = true` inherited existing Homebrew
- Existing Homebrew was installed at `/usr/local` (likely from Intel era or old install)
- nix-homebrew kept it there instead of migrating to `/opt/homebrew`

**Impact of NOT Fixing:**

- Slower installs (build from source vs. download bottles)
- Some packages may not have bottles available
- Potential compatibility issues
- Continued warnings from `brew doctor`

---

## e) WHAT WE SHOULD IMPROVE 📈

### Immediate (This Week)

1. **Homebrew Migration Decision** ⭐ CRITICAL
   - **Options:**
     - A) Full migration to `/opt/homebrew` (RECOMMENDED)
     - B) Minimal fix (remove deprecated tap only)
   - **Effort:** 15-30 minutes
   - **Impact:** HIGH (fixes all Homebrew issues)

2. **Review Gitleaks Findings**
   - Run: `gitleaks detect --verbose`
   - Review 6 flagged items
   - Whitelist false positives, rotate real secrets

3. **Fix Statix Warnings**
   - W20: Repeated keys
   - W04: Inherit suggestions
   - W23: Empty list concatenation

4. **Test NixOS Bluetooth**
   - Rebuild evo-x2
   - Pair with Nest Audio
   - Validate audio output

### Short-term (This Month)

5. **Implement Program Discovery System**
   - Create `programs/discovery.nix`
   - Auto-discover from `pkgs/`
   - Integrate into flake.nix

6. **Deploy ActivityWatch Enhanced**
   - Install Ollama
   - Test aw-watcher-enhanced
   - Validate AI context extraction

7. **Create Path Constants Library**
   - `scripts/lib/paths.sh`
   - `PROJECT_ROOT` variable
   - Update all hardcoded paths

8. **Consolidate Documentation**
   - Merge 3 Bluetooth docs
   - Archive redundant files

### Medium-term (This Quarter)

9. **Build Cross-platform CLI Tool**
10. **Create Automated Testing Framework**
11. **Set up aw-sync Multi-device**
12. **Add Advanced Analytics (InfluxDB/Grafana)**

---

## f) TOP #25 THINGS TO GET DONE NEXT 🎯

### P0 - Critical (This Week) ⭐

| # | Task                                     | Effort | Impact   | Status                   |
| - | ---------------------------------------- | ------ | -------- | ------------------------ |
| 1 | **Homebrew Migration Decision**          | 15m    | CRITICAL | ⏳ User decision pending |
| 2 | Execute Homebrew migration (if approved) | 30m    | CRITICAL | ⏳ Blocked on #1         |
| 3 | Review gitleaks findings                 | 45m    | HIGH     | ⏳ Pending               |
| 4 | Fix statix linting warnings              | 30m    | MEDIUM   | ⏳ Pending               |
| 5 | Test NixOS Bluetooth with Nest Audio     | 60m    | MEDIUM   | ⏳ Pending               |

### P1 - High Priority (This Month)

| #  | Task                                        | Effort | Impact | Dependencies |
| -- | ------------------------------------------- | ------ | ------ | ------------ |
| 6  | Implement programs/discovery.nix            | 2h     | HIGH   | None         |
| 7  | Install Ollama and test aw-watcher-enhanced | 1h     | HIGH   | None         |
| 8  | Create scripts/lib/paths.sh constants       | 1h     | MEDIUM | None         |
| 9  | Merge Bluetooth documentation               | 30m    | LOW    | None         |
| 10 | Create `just organize` command              | 2h     | MEDIUM | None         |
| 11 | Deploy aw-watcher-input                     | 30m    | MEDIUM | None         |
| 12 | Add automated flake update check            | 1h     | MEDIUM | None         |

### P2 - Medium Priority (This Quarter)

| #  | Task                                     | Effort | Impact | Dependencies      |
| -- | ---------------------------------------- | ------ | ------ | ----------------- |
| 13 | Build cross-platform CLI tool            | 4h     | HIGH   | Program discovery |
| 14 | Create tests/ framework                  | 3h     | HIGH   | None              |
| 15 | Set up aw-sync multi-device              | 2h     | MEDIUM | None              |
| 16 | Deploy aw-watcher-spotify                | 30m    | LOW    | None              |
| 17 | Add InfluxDB export option               | 2h     | LOW    | None              |
| 18 | Research iOS integration                 | 2h     | MEDIUM | None              |
| 19 | Create file organization pre-commit hook | 1h     | MEDIUM | None              |
| 20 | Update TODO_LIST.md                      | 30m    | LOW    | None              |

### P3 - Low Priority (Backlog)

| #  | Task                            | Effort | Impact | Dependencies     |
| -- | ------------------------------- | ------ | ------ | ---------------- |
| 21 | Deploy aw-watcher-screenshot    | 1h     | MEDIUM | Storage planning |
| 22 | Set up aw-watcher-ask           | 30m    | LOW    | None             |
| 23 | Move AGENTS.md to docs/         | 15m    | LOW    | None             |
| 24 | Create onboarding checklist     | 1h     | LOW    | None             |
| 25 | Research standing desk hardware | 2h     | LOW    | None             |

---

## g) TOP #1 QUESTION I CANNOT FIGURE OUT 🤔

### The Question:

**"Why did nix-homebrew with `autoMigrate = true` NOT automatically migrate Homebrew from `/usr/local` to `/opt/homebrew` when the system is clearly Apple Silicon (arm64)?"**

### Context:

**Current Configuration:**

```nix
nix-homebrew = {
  enable = true;
  enableRosetta = true;  # May be causing issues
  user = "larsartmann";
  autoMigrate = true;    # Should have migrated!
  taps = {
    "homebrew/bundle" = homebrew-bundle;
    "homebrew/cask" = homebrew-cask;
  };
};
```

**System Facts:**

- Architecture: `arm64` (Apple Silicon) ✅
- Current prefix: `/usr/local` (WRONG - Intel prefix) ❌
- Expected prefix: `/opt/homebrew` (Apple Silicon prefix) ✅

### What I Know:

1. **nix-homebrew documentation** says `autoMigrate` migrates existing Homebrew installations
2. **Apple Silicon Macs** should use `/opt/homebrew` by default
3. **Intel prefix on Apple Silicon** = Tier 3 configuration (limited bottles)
4. **The user had Homebrew at `/usr/local`** before nix-homebrew took over
5. **nix-homebrew kept it at `/usr/local`** instead of migrating to `/opt/homebrew`

### What I Don't Know:

1. **Does `autoMigrate` only migrate within the same prefix?**
   - Or should it detect architecture and migrate to correct prefix?

2. **Does `enableRosetta = true` confuse the migration?**
   - Does it think we want Intel compatibility so keeps `/usr/local`?

3. **Is there a nix-homebrew option to force prefix?**
   - Something like `prefix = "/opt/homebrew"`?

4. **Should we disable `autoMigrate` and do fresh install?**
   - Would nix-homebrew then install to correct prefix?

5. **Is this a nix-homebrew bug or intended behavior?**
   - Should we report upstream?

### Why This Matters:

- **Blocking optimal Homebrew configuration**
- **User needs to decide:** migrate (risky) or keep (suboptimal)
- **Affects all future Homebrew operations**

### Research Needed:

1. Check nix-homebrew GitHub issues for similar reports
2. Test if `enableRosetta = false` helps
3. Test if removing `autoMigrate` and reinstalling works
4. Check if there's a `prefix` option we missed

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

| Watcher                | Platform     | Status                  |
| ---------------------- | ------------ | ----------------------- |
| aw-watcher-afk         | Darwin/NixOS | ✅ Active               |
| aw-watcher-window      | Darwin/NixOS | ✅ Fixed (permissions)  |
| aw-watcher-web-chrome  | Darwin/NixOS | ✅ Active               |
| aw-watcher-utilization | Darwin       | ✅ Active (LaunchAgent) |
| aw-watcher-input       | Available    | ⚠️ Not deployed          |
| aw-watcher-enhanced    | Research     | ⚠️ Ready for testing     |
| aw-watcher-screenshot  | Research     | ❌ Not started          |

### Homebrew Status

| Metric         | Current         | Target                      |
| -------------- | --------------- | --------------------------- |
| Prefix         | `/usr/local` ❌ | `/opt/homebrew` ✅          |
| Architecture   | arm64 ✅        | arm64 ✅                    |
| Git Origin     | Missing ❌      | github.com/Homebrew/brew ✅ |
| Tier Status    | Tier 3 ❌       | Tier 1 ✅                   |
| Deprecated Tap | Present ❌      | Removed ✅                  |

### Recent Commits (Last 5)

```
663a0d9 docs(status): add comprehensive executive status update (2026-03-05)
4711280 feat(sublime-text): add comprehensive Sublime Text configuration backup
26a17dd feat(sublime-text): add comprehensive Sublime Text configuration backup
d74f326 fix(darwin): remove unsupported CLI args from aw-watcher-utilization LaunchAgent
75ee0d8 docs(status): add comprehensive report on ActivityWatch Nix utilization watcher
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

**Report Generated:** 2026-03-06 01:40 CET
**Classification:** Internal Strategic Assessment
**Next Review:** After Homebrew migration decision
**Distribution:** SystemNix Project Team
