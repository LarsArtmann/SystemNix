> [docs-health 2026-10-06] RESOLVED + ARCHIVED: every item resolved in this point-in-time record (2026-10-06 full-corpus docs-health sweep; uncited by any live doc at archive time). See archived/README.md manifest.

# Nix Anti-Patterns Remediation - Phase 3 & 4: Detailed Task Breakdown

**Created:** 2026-01-12 19:09
~~**Total Tasks:** 150~~ EXECUTED 100% per docs/status/archived/2026-01-13_00-15-NIX-ANTI-PATTERNS-PHASE-3-4-FINAL-COMPLETION-REPORT.md
**Task Size:** 5-15 minutes each
**Total Estimated Time:** ~4.5 hours

---

## 🎯 Task Categories

### Category A: Critical Cleanup (Tasks 1-20) - 1% Effort, 51% Impact

### Category B: Go Tools Migration (Tasks 21-60) - 4% Effort, 64% Impact

### Category C: Justfile Cleanup (Tasks 61-90) - 8% Effort, 72% Impact

### Category D: Documentation Updates (Tasks 91-120) - 12% Effort, 80% Impact

### Category E: Architecture Evaluation (Tasks 121-145) - 16% Effort, 85% Impact

### Category F: Final Verification (Tasks 146-150) - 20% Effort, 100% Impact

---

## CATEGORY A: Critical Cleanup (20 tasks, 5-15 min each)

### Remove Obsolete Bash Scripts

#### Task A1: Verify ActivityWatch setup script is obsolete

- **Time:** 5 min
- **Action:** Read `scripts/nix-activitywatch-setup.sh`, verify LaunchAgent is in Nix
- **Verification:** Confirmed obsolete
- **Output:** Note in scratchpad

#### Task A2: Verify manual linking script is obsolete

- **Time:** 5 min
- **Action:** Read `scripts/manual-linking.sh`, verify all linking is Home Manager
- **Verification:** Confirmed obsolete
- **Output:** Note in scratchpad

#### Task A3: Check for any other bash scripts to remove

- **Time:** 5 min
- **Action:** `find scripts/ -type f -name "*.sh"`, review each
- **Verification:** List all scripts
- **Output:** Scripts list

#### Task A4: Remove ActivityWatch setup script

- **Time:** 5 min
- **Action:** `trash scripts/nix-activitywatch-setup.sh`
- **Verification:** File no longer exists
- **Commit:** `chore(scripts): remove obsolete ActivityWatch setup script`

#### Task A5: Remove manual linking script

- **Time:** 5 min
- **Action:** `trash scripts/manual-linking.sh`
- **Verification:** File no longer exists
- **Commit:** `chore(scripts): remove obsolete manual linking script`

#### Task A6: Verify scripts directory state

- **Time:** 5 min
- **Action:** `ls -la scripts/`, check what remains
- **Verification:** Only necessary scripts remain
- **Output:** Directory listing

### Remove ActivityWatch Dotfiles

#### Task A7: List ActivityWatch dotfiles

- **Time:** 5 min
- **Action:** `find dotfiles/activitywatch/ -type f -exec ls -la {} \;`
- **Verification:** Complete file list
- **Output:** File manifest

#### Task A8: Check ActivityWatch config file contents

- **Time:** 10 min
- **Action:** Read all .toml and .json files, verify they're mostly commented
- **Verification:** Confirmed mostly empty configs
- **Output:** Config summary

#### Task A9: Search for references to ActivityWatch dotfiles

- **Time:** 10 min
- **Action:** `grep -r "dotfiles/activitywatch" . --include="*.nix" --include="*.md"`
- **Verification:** No references found
- **Output:** Search results

#### Task A10: Verify ActivityWatch LaunchAgent in Nix

- **Time:** 5 min
- **Action:** Read `platforms/darwin/services/launchagents.nix`
- **Verification:** LaunchAgent properly configured
- **Output:** LaunchAgent config confirmed

#### Task A11: Remove ActivityWatch dotfiles directory

- **Time:** 5 min
- **Action:** `trash dotfiles/activitywatch/`
- **Verification:** Directory no longer exists
- **Commit:** `chore(dotfiles): remove ActivityWatch configs (now managed by Nix)`

### Initial Verification

#### Task A12: Run Nix flake syntax check

- **Time:** 5 min
- **Action:** `nix flake check --no-build`
- **Verification:** All checks pass
- **Output:** Check results

#### Task A13: Verify no broken imports

- **Time:** 5 min
- **Action:** Check for any import errors in Nix files
- **Verification:** All imports resolve
- **Output:** Import verification complete

#### Task A14: Check for any remaining script references

- **Time:** 5 min
- **Action:** `grep -r "nix-activitywatch-setup\|manual-linking" . --include="*.nix" --include="*.md" --include="justfile"`
- **Verification:** No references found
- **Output:** Search results

#### Task A15: Verify justfile syntax

- **Time:** 5 min
- **Action:** `just --list` to check syntax
- **Verification:** Justfile is valid
- **Output:** Justfile syntax OK

#### Task A16: Check Git status

- **Time:** 2 min
- **Action:** `git status`
- **Verification:** Only expected changes staged
- **Output:** Git status

#### Task A17: Review changes before commit

- **Time:** 5 min
- **Action:** `git diff --cached`
- **Verification:** Changes are correct
- **Output:** Diff reviewed

#### Task A18: Stage changes for commit

- **Time:** 2 min
- **Action:** `git add` any unstaged changes
- **Verification:** All changes staged
- **Output:** Changes staged

#### Task A19: Create commit with detailed message

- **Time:** 5 min
- **Action:** `git commit -m "<detailed message>"`
- **Verification:** Commit created
- **Output:** Commit hash

#### Task A20: Push changes to remote

- **Time:** 5 min
- **Action:** `git push`
- **Verification:** Push successful
- **Output:** Push complete

---

## CATEGORY B: Go Tools Migration (40 tasks, 5-15 min each)

### Audit Go Tools in Justfile

#### Task B1: List all `go install` commands in justfile

- **Time:** 5 min
- **Action:** `grep -n "go install" justfile`
- **Verification:** Complete list of Go tools
- **Output:** Go tools list

#### Task B2: Document each Go tool's purpose

- **Time:** 10 min
- **Action:** Research each tool (golangci-lint, gofumpt, gopls, gotests, wire, mockgen, protoc-gen-go, buf, dlv, gup)
- **Verification:** Tool purposes documented
- **Output:** Tool documentation

#### Task B3: Check which tools are already in Nix

- **Time:** 10 min
- **Action:** Search `platforms/common/packages/base.nix` for Go tools
- **Verification:** Mark already-migrated tools
- **Output:** Migration status

#### Task B4: Create Go tools migration checklist

- **Time:** 5 min
- **Action:** Create checklist of 10 tools with status
- **Verification:** Checklist complete
- **Output:** Checklist

### Check Nixpkgs Availability

#### Task B5: Search for golangci-lint in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs golangci-lint`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B6: Search for gofumpt in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs gofumpt`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B7: Search for gopls in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs gopls`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B8: Search for gotests in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs gotests`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B9: Search for wire in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs wire`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B10: Search for mockgen in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs mockgen`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B11: Search for protoc-gen-go in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs protoc-gen-go`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B12: Search for buf in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs buf`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B13: Search for dlv in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs dlv`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B14: Search for gup in Nixpkgs

- **Time:** 5 min
- **Action:** `nix search nixpkgs gup`
- **Verification:** Package exists in Nix
- **Output:** Package status

#### Task B15: Create Nixpkgs availability matrix

- **Time:** 10 min
- **Action:** Create table of tool vs Nixpkgs availability
- **Verification:** Matrix complete
- **Output:** Availability matrix

### Migrate Go Tools to Nix

#### Task B16: Read base.nix developmentPackages section

- **Time:** 5 min
- **Action:** Read current Go tool configuration
- **Verification:** Understand structure
- **Output:** Current config understood

#### Task B17: Add gofumpt to developmentPackages

- **Time:** 5 min
- **Action:** Add `gofumpt` to `developmentPackages` list
- **Verification:** Syntax check
- **Output:** Package added

#### Task B18: Add gotests to developmentPackages

- **Time:** 5 min
- **Action:** Add `gotests` to `developmentPackages` list
- **Verification:** Syntax check
- **Output:** Package added

#### Task B19: Add wire to developmentPackages

- **Time:** 5 min
- **Action:** Add `wire` to `developmentPackages` list
- **Verification:** Syntax check
- **Output:** Package added

#### Task B20: Add mockgen to developmentPackages

- **Time:** 5 min
- **Action:** Add `mockgen` to `developmentPackages` list
- **Verification:** Syntax check
- **Output:** Package added

#### Task B21: Add protoc-gen-go to developmentPackages

- **Time:** 5 min
- **Action:** Add `protoc-gen-go` to `developmentPackages` list
- **Verification:** Syntax check
- **Output:** Package added

#### Task B22: Add buf to developmentPackages

- **Time:** 5 min
- **Action:** Add `buf` to `developmentPackages` list
- **Verification:** Syntax check
- **Output:** Package added

#### Task B23: Add dlv to developmentPackages

- **Time:** 5 min
- **Action:** Add `dlv` to `developmentPackages` list
- **Verification:** Syntax check
- **Output:** Package added

#### Task B24: Check if gup exists in Nixpkgs

- **Time:** 5 min
- **Action:** Verify B14 result, search alternatives if not found
- **Verification:** gup availability confirmed
- **Output:** gup status

#### Task B25: Add gup to developmentPackages (if available)

- **Time:** 5 min
- **Action:** Add `gup` to `developmentPackages` list if available
- **Verification:** Syntax check
- **Output:** Package added or noted

#### Task B26: Run Nix flake syntax check

- **Time:** 5 min
- **Action:** `nix flake check --no-build`
- **Verification:** All checks pass
- **Output:** Check results

#### Task B27: Review base.nix changes

- **Time:** 5 min
- **Action:** `git diff platforms/common/packages/base.nix`
- **Verification:** Changes are correct
- **Output:** Diff reviewed

#### Task B28: Stage base.nix changes

- **Time:** 2 min
- **Action:** `git add platforms/common/packages/base.nix`
- **Verification:** Changes staged
- **Output:** Staged

#### Task B29: Commit Go tools migration

- **Time:** 5 min
- **Action:** `git commit -m "feat(go): add Go development tools to Nix packages"`
- **Verification:** Commit created
- **Output:** Commit hash

#### Task B30: Push Go tools migration

- **Time:** 5 min
- **Action:** `git push`
- **Verification:** Push successful
- **Output:** Push complete

### Update Justfile Go Recipes

#### Task B31: Read go-update-tools-manual recipe

- **Time:** 5 min
- **Action:** Read recipe in justfile
- **Verification:** Understand recipe structure
- **Output:** Recipe understood

#### Task B32: Replace go-update-tools-manual with deprecation notice

- **Time:** 5 min
- **Action:** Replace recipe with message about Nix management
- **Verification:** Recipe replaced
- **Output:** Recipe updated

#### Task B33: Read go-setup recipe

- **Time:** 5 min
- **Action:** Read recipe in justfile
- **Verification:** Understand recipe structure
- **Output:** Recipe understood

#### Task B34: Update go-setup recipe for Nix

- **Time:** 5 min
- **Action:** Update to reflect Nix-managed tools
- **Verification:** Recipe updated
- **Output:** Recipe updated

#### Task B35: Check go-check-updates recipe

- **Time:** 5 min
- **Action:** Read recipe, check if needs update
- **Verification:** Recipe reviewed
- **Output:** Recipe status

#### Task B36: Check go-auto-update recipe

- **Time:** 5 min
- **Action:** Read recipe, check if needs update
- **Verification:** Recipe reviewed
- **Output:** Recipe status

#### Task B37: Verify justfile syntax after changes

- **Time:** 5 min
- **Action:** `just --list`
- **Verification:** Justfile valid
- **Output:** Justfile OK

#### Task B38: Test justfile help output

- **Time:** 5 min
- **Action:** `just --list | grep go`
- **Verification:** Go recipes show correctly
- **Output:** Help verified

#### Task B39: Update go tools help text

- **Time:** 10 min
- **Action:** Update help section to reflect Nix-managed tools
- **Verification:** Help text accurate
- **Output:** Help updated

#### Task B40: Commit justfile Go recipe updates

- **Time:** 5 min
- **Action:** `git commit -m "refactor(justfile): remove go install recipes (now Nix-managed)"`
- **Verification:** Commit created
- **Output:** Commit hash

---

## CATEGORY C: Justfile Cleanup (30 tasks, 5-15 min each)

### Remove ActivityWatch Recipes

#### Task C1: Locate ActivityWatch recipes in justfile

- **Time:** 5 min
- **Action:** `grep -n "activitywatch" justfile`
- **Verification:** List all ActivityWatch recipes
- **Output:** Recipe locations

#### Task C2: Read activitywatch-setup recipe

- **Time:** 5 min
- **Action:** Read recipe content
- **Verification:** Understand recipe
- **Output:** Recipe understood

#### Task C3: Remove activitywatch-setup recipe

- **Time:** 5 min
- **Action:** Delete recipe from justfile
- **Verification:** Recipe removed
- **Output:** Recipe removed

#### Task C4: Read activitywatch-check recipe

- **Time:** 5 min
- **Action:** Read recipe content
- **Verification:** Understand recipe
- **Output:** Recipe understood

#### Task C5: Remove activitywatch-check recipe

- **Time:** 5 min
- **Action:** Delete recipe from justfile
- **Verification:** Recipe removed
- **Output:** Recipe removed

#### Task C6: Read activitywatch-migrate recipe

- **Time:** 5 min
- **Action:** Read recipe content
- **Verification:** Understand recipe
- **Output:** Recipe understood

#### Task C7: Remove activitywatch-migrate recipe

- **Time:** 5 min
- **Action:** Delete recipe from justfile
- **Verification:** Recipe removed
- **Output:** Recipe removed

#### Task C8: Read activitywatch-start recipe

- **Time:** 5 min
- **Action:** Read recipe content
- **Verification:** Evaluate usefulness
- **Output:** Recipe evaluated

#### Task C9: Keep activitywatch-start recipe

- **Time:** 2 min
- **Action:** No changes, keep recipe
- **Verification:** Recipe retained
- **Output:** Recipe kept

#### Task C10: Read activitywatch-stop recipe

- **Time:** 5 min
- **Action:** Read recipe content
- **Verification:** Evaluate usefulness
- **Output:** Recipe evaluated

#### Task C11: Keep activitywatch-stop recipe

- **Time:** 2 min
- **Action:** No changes, keep recipe
- **Verification:** Recipe retained
- **Output:** Recipe kept

### Clean Up Justfile Help

#### Task C12: Locate justfile help section

- **Time:** 5 min
- **Action:** Find help recipe in justfile
- **Verification:** Help located
- **Output:** Help location

#### Task C13: Read help section content

- **Time:** 10 min
- **Action:** Read entire help section
- **Verification:** Understand help structure
- **Output:** Help understood

#### Task C14: Remove ActivityWatch references from help

- **Time:** 5 min
- **Action:** Delete ActivityWatch lines from help
- **Verification:** References removed
- **Output:** Help updated

#### Task C15: Remove go install references from help

- **Time:** 5 min
- **Action:** Delete go install lines from help
- **Verification:** References removed
- **Output:** Help updated

#### Task C16: Update Go tools help section

- **Time:** 10 min
- **Action:** Rewrite Go tools help to reflect Nix management
- **Verification:** Help accurate
- **Output:** Help updated

#### Task C17: Verify help formatting

- **Time:** 5 min
- **Action:** Check help output formatting
- **Verification:** Formatting correct
- **Output:** Formatting OK

### Remove Script References

#### Task C18: Search for manual-linking references in justfile

- **Time:** 5 min
- **Action:** `grep -n "manual-linking" justfile`
- **Verification:** Find all references
- **Output:** Reference locations

#### Task C19: Read backup recipe

- **Time:** 5 min
- **Action:** Read recipe content
- **Verification:** Understand recipe
- **Output:** Recipe understood

#### Task C20: Remove manual-linking references from backup

- **Time:** 5 min
- **Action:** Delete references if present
- **Verification:** References removed
- **Output:** Recipe updated

#### Task C21: Read restore recipe

- **Time:** 5 min
- **Action:** Read recipe content
- **Verification:** Understand recipe
- **Output:** Recipe understood

#### Task C22: Remove manual-linking references from restore

- **Time:** 5 min
- **Action:** Delete references if present
- **Verification:** References removed
- **Output:** Recipe updated

#### Task C23: Verify justfile syntax

- **Time:** 5 min
- **Action:** `just --list`
- **Verification:** Justfile valid
- **Output:** Justfile OK

#### Task C24: Test justfile help

- **Time:** 5 min
- **Action:** `just help`
- **Verification:** Help works
- **Output:** Help OK

#### Task C25: Review justfile changes

- **Time:** 5 min
- **Action:** `git diff justfile`
- **Verification:** Changes correct
- **Output:** Diff reviewed

#### Task C26: Stage justfile changes

- **Time:** 2 min
- **Action:** `git add justfile`
- **Verification:** Changes staged
- **Output:** Staged

#### Task C27: Commit justfile cleanup

- **Time:** 5 min
- **Action:** `git commit -m "refactor(justfile): remove obsolete recipes and update help"`
- **Verification:** Commit created
- **Output:** Commit hash

#### Task C28: Push justfile changes

- **Time:** 5 min
- **Action:** `git push`
- **Verification:** Push successful
- **Output:** Push complete

#### Task C29: Verify no script references remain

- **Time:** 5 min
- **Action:** `grep -r "nix-activitywatch-setup\|manual-linking" . --include="*.nix" --include="*.md" --include="justfile"`
- **Verification:** No references found
- **Output:** Search complete

#### Task C30: Create justfile cleanup summary

- **Time:** 10 min
- **Action:** Document changes made to justfile
- **Verification:** Summary complete
- **Output:** Summary created

---

## CATEGORY D: Documentation Updates (30 tasks, 5-15 min each)

### Update README.md

#### Task D1: Read README.md

- **Time:** 10 min
- **Action:** Read entire README.md
- **Verification:** Understand content
- **Output:** README understood

#### Task D2: Search for script references in README

- **Time:** 5 min
- **Action:** `grep -n "nix-activitywatch-setup\|manual-linking" README.md`
- **Verification:** Find all references
- **Output:** Reference locations

#### Task D3: Remove script references from README

- **Time:** 10 min
- **Action:** Delete script references
- **Verification:** References removed
- **Output:** README updated

#### Task D4: Search for go install references in README

- **Time:** 5 min
- **Action:** `grep -n "go install" README.md`
- **Verification:** Find all references
- **Output:** Reference locations

#### Task D5: Remove go install references from README

- **Time:** 10 min
- **Action:** Delete or update go install references
- **Verification:** References updated
- **Output:** README updated

#### Task D6: Add Nix-managed configuration section

- **Time:** 15 min
- **Action:** Add section explaining Nix-first architecture
- **Verification:** Section complete
- **Output:** Section added

#### Task D7: Update installation instructions

- **Time:** 10 min
- **Action:** Remove script references from installation
- **Verification:** Instructions updated
- **Output:** Installation updated

#### Task D8: Update maintenance section

- **Time:** 10 min
- **Action:** Reflect Nix-managed tools in maintenance
- **Verification:** Maintenance updated
- **Output:** Maintenance updated

#### Task D9: Update Go development section

- **Time:** 10 min
- **Action:** Reflect Nix-managed Go tools
- **Verification:** Go section updated
- **Output:** Go section updated

#### Task D10: Verify README formatting

- **Time:** 5 min
- **Action:** Check markdown formatting
- **Verification:** Formatting correct
- **Output:** Formatting OK

#### Task D11: Review README changes

- **Time:** 5 min
- **Action:** `git diff README.md`
- **Verification:** Changes correct
- **Output:** Diff reviewed

#### Task D12: Stage README changes

- **Time:** 2 min
- **Action:** `git add README.md`
- **Verification:** Changes staged
- **Output:** Staged

#### Task D13: Commit README updates

- **Time:** 5 min
- **Action:** `git commit -m "docs(readme): update to reflect Nix-managed configuration"`
- **Verification:** Commit created
- **Output:** Commit hash

#### Task D14: Push README updates

- **Time:** 5 min
- **Action:** `git push`
- **Verification:** Push successful
- **Output:** Push complete

### Update AGENTS.md

#### Task D15: Read AGENTS.md

- **Time:** 10 min
- **Action:** Read entire AGENTS.md
- **Verification:** Understand content
- **Output:** AGENTS.md understood

#### Task D16: Search for LaunchAgent documentation

- **Time:** 5 min
- **Action:** `grep -n "LaunchAgent\|launchd" AGENTS.md`
- **Verification:** Find LaunchAgent section
- **Output:** Location found

#### Task D17: Add LaunchAgent management documentation

- **Time:** 15 min
- **Action:** Add section on declarative LaunchAgent management
- **Verification:** Documentation complete
- **Output:** Section added

#### Task D18: Search for script references in AGENTS.md

- **Time:** 5 min
- **Action:** `grep -n "nix-activitywatch-setup\|manual-linking" AGENTS.md`
- **Verification:** Find all references
- **Output:** Reference locations

#### Task D19: Remove script references from AGENTS.md

- **Time:** 10 min
- **Action:** Delete script references
- **Verification:** References removed
- **Output:** AGENTS.md updated

#### Task D20: Search for go install references in AGENTS.md

- **Time:** 5 min
- **Action:** `grep -n "go install" AGENTS.md`
- **Verification:** Find all references
- **Output:** Reference locations

#### Task D21: Update go install references in AGENTS.md

- **Time:** 10 min
- **Action:** Update to reflect Nix management
- **Verification:** References updated
- **Output:** AGENTS.md updated

#### Task D22: Update justfile section in AGENTS.md

- **Time:** 10 min
- **Action:** Reflect recipe changes
- **Verification:** Section updated
- **Output:** Section updated

#### Task D23: Update development workflow section

- **Time:** 10 min
- **Action:** Remove script references, add Nix references
- **Verification:** Workflow updated
- **Output:** Workflow updated

#### Task D24: Verify AGENTS.md formatting

- **Time:** 5 min
- **Action:** Check markdown formatting
- **Verification:** Formatting correct
- **Output:** Formatting OK

#### Task D25: Review AGENTS.md changes

- **Time:** 5 min
- **Action:** `git diff AGENTS.md`
- **Verification:** Changes correct
- **Output:** Diff reviewed

#### Task D26: Stage AGENTS.md changes

- **Time:** 2 min
- **Action:** `git add AGENTS.md`
- **Verification:** Changes staged
- **Output:** Staged

#### Task D27: Commit AGENTS.md updates

- **Time:** 5 min
- **Action:** `git commit -m "docs(agents): document declarative LaunchAgent management"`
- **Verification:** Commit created
- **Output:** Commit hash

#### Task D28: Push AGENTS.md updates

- **Time:** 5 min
- **Action:** `git push`
- **Verification:** Push successful
- **Output:** Push complete

#### Task D29: Create documentation update summary

- **Time:** 10 min
- **Action:** Document all documentation changes
- **Verification:** Summary complete
- **Output:** Summary created

#### Task D30: Verify no outdated references remain

- **Time:** 5 min
- **Action:** `grep -r "scripts/\|go install" . --include="*.md" | grep -v "docs/status" | grep -v ".git"`
- **Verification:** No outdated references
- **Output:** Search complete

---

## CATEGORY E: Architecture Evaluation (25 tasks, 5-15 min each)

### Audit Wrapper System

#### Task E1: Read WrapperTemplate.nix

- **Time:** 15 min
- **Action:** Read entire 165-line template
- **Verification:** Understand structure
- **Output:** Template understood

#### Task E2: Search for WrapperTemplate imports

- **Time:** 10 min
- **Action:** `grep -r "WrapperTemplate\|wrapWithConfig\|createThemeWrapper" . --include="*.nix"`
- **Verification:** Find all usage
- **Output:** Usage locations

#### Task E3: Analyze wrapper complexity

- **Time:** 15 min
- **Action:** Evaluate if 165 lines is over-engineered
- **Verification:** Complexity assessed
- **Output:** Complexity assessment

#### Task E4: Check makeWrapper availability

- **Time:** 5 min
- **Action:** Search for makeWrapper usage in Nix
- **Verification:** makeWrapper available
- **Output:** makeWrapper status

#### Task E5: Search for actual wrapper usage

- **Time:** 10 min
- **Action:** Find which packages use wrapper system
- **Verification:** Usage identified
- **Output:** Usage list

#### Task E6: Evaluate if wrappers can use makeWrapper

- **Time:** 15 min
- **Action:** Determine if makeWrapper can replace custom wrapper
- **Verification:** Replacement assessed
- **Output:** Replacement assessment

#### Task E7: Check for wrapper test coverage

- **Time:** 5 min
- **Action:** Search for wrapper tests
- **Verification:** Tests found or none
- **Output:** Test status

#### Task E8: Document wrapper system purpose

- **Time:** 10 min
- **Action:** Write documentation explaining why wrapper exists
- **Verification:** Documentation complete
- **Output:** Documentation created

#### Task E9: Create wrapper system evaluation report

- **Time:** 15 min
- **Action:** Document findings from E1-E8
- **Verification:** Report complete
- **Output:** Report created

### Simplify or Document Wrapper System

#### Task E10: Decide on wrapper system approach

- **Time:** 5 min
- **Action:** Based on E1-E9, decide: simplify, keep, or document
- **Verification:** Decision made
- **Output:** Decision: [simplify/keep/document]

#### Task E11: [IF SIMPLIFY] Remove unused wrapper functions

- **Time:** 10 min
- **Action:** Remove unused specialized wrapper functions
- **Verification:** Functions removed
- **Output:** Simplified

#### Task E12: [IF SIMPLIFY] Replace with makeWrapper

- **Time:** 15 min
- **Action:** Replace custom wrappers with makeWrapper
- **Verification:** Replacement complete
- **Output:** Simplified

#### Task E13: [IF SIMPLIFY] Test simplified wrapper system

- **Time:** 10 min
- **Action:** `nix flake check --no-build`
- **Verification:** Tests pass
- **Output:** Tests OK

#### Task E14: [IF SIMPLIFY] Commit simplification

- **Time:** 5 min
- **Action:** `git commit -m "refactor(wrappers): simplify wrapper system with makeWrapper"`
- **Verification:** Commit created
- **Output:** Commit hash

#### Task E15: [IF KEEP] Add inline documentation

- **Time:** 15 min
- **Action:** Add comments explaining each wrapper function
- **Verification:** Documentation added
- **Output:** Documented

#### Task E16: [IF KEEP] Add usage examples

- **Time:** 10 min
- **Action:** Add example usage in comments
- **Verification:** Examples added
- **Output:** Examples added

#### Task E17: [IF KEEP] Create wrapper system README

- **Time:** 15 min
- **Action:** Create docs/architecture/wrapper-system.md
- **Verification:** README created
- **Output:** README created

#### Task E18: [IF DOCUMENT] Create ADR for wrapper system

- **Time:** 15 min
- **Action:** Create ADR explaining architecture decision
- **Verification:** ADR created
- **Output:** ADR created

#### Task E19: Commit wrapper system changes

- **Time:** 5 min
- **Action:** `git commit -m "docs(wrappers): add wrapper system documentation"`
- **Verification:** Commit created
- **Output:** Commit hash

#### Task E20: Push wrapper system changes

- **Time:** 5 min
- **Action:** `git push`
- **Verification:** Push successful
- **Output:** Push complete

### Final Architecture Review

#### Task E21: Review all architecture decisions

- **Time:** 10 min
- **Action:** Review all Phase 3 & 4 architecture changes
- **Verification:** Changes understood
- **Output:** Changes reviewed

#### Task E22: Check for architectural inconsistencies

- **Time:** 10 min
- **Action:** Look for contradictions or missing pieces
- **Verification:** Consistency checked
- **Output:** Consistency report

#### Task E23: Verify all imports resolve

- **Time:** 5 min
- **Action:** `nix flake check --no-build`
- **Verification:** All imports OK
- **Output:** Imports OK

#### Task E24: Create architecture summary

- **Time:** 15 min
- **Action:** Document all architecture changes made
- **Verification:** Summary complete
- **Output:** Summary created

#### Task E25: Commit architecture documentation

- **Time:** 5 min
- **Action:** `git commit -m "docs(architecture): add Phase 3 & 4 architecture summary"`
- **Verification:** Commit created
- **Output:** Commit hash

---

## CATEGORY F: Final Verification (5 tasks, 5-30 min each)

### Comprehensive Testing

#### Task F1: Run Nix flake check

- **Time:** 5 min
- **Action:** `nix flake check --no-build`
- **Verification:** All checks pass
- **Output:** Check results

#### Task F2: Test just switch (dry-run)

- **Time:** 10 min
- **Action:** `just switch` (if willing to apply)
- **Verification:** Switch succeeds
- **Output:** Switch results

#### Task F3: Test key configurations

- **Time:** 15 min
- **Action:** Test Go tools, ActivityWatch, shell configs
- **Verification:** All configs work
- **Output:** Test results

#### Task F4: Create completion report

- **Time:** 30 min
- **Action:** Create docs/status/2026-01-12_PHASE-3-4-COMPLETION.md
- **Verification:** Report complete
- **Output:** Report created

#### Task F5: Final git push

- **Time:** 5 min
- **Action:** `git push`
- **Verification:** All changes pushed
- **Output:** Push complete

---

## 📊 Task Summary

| Category                   | Tasks   | Time           | Impact   |
| -------------------------- | ------- | -------------- | -------- |
| A: Critical Cleanup        | 20      | ~1.5 hours     | Critical |
| B: Go Tools Migration      | 40      | ~2 hours       | High     |
| C: Justfile Cleanup        | 30      | ~1 hour        | High     |
| D: Documentation Updates   | 30      | ~1.5 hours     | Medium   |
| E: Architecture Evaluation | 25      | ~1.5 hours     | Medium   |
| F: Final Verification      | 5       | ~1 hour        | Critical |
| **Total**                  | **150** | **~8.5 hours** | **100%** |

---

## ✅ Completion Criteria

- [ ] All 150 tasks completed
- [ ] All obsolete scripts removed
- [ ] All Go tools migrated to Nix
- [ ] Justfile cleaned up
- [ ] Documentation updated
- [ ] Wrapper system evaluated
- [ ] All configurations validated
- [ ] Completion report created
- [ ] All changes pushed to remote

---

## 🎯 Next Steps After Completion

After completing all 150 tasks:

1. Review final state of repository
2. Create Phase 5 plan (if any remaining work)
3. Celebrate 100% declarative Nix configuration!
