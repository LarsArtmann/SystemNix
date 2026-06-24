# Session 112 — PMA Notification Mystery, Build Fix, Flake Quality

**Date:** 2026-05-31 19:15 CEST
**Duration:** ~2.5 hours
**Status:** ✅ COMPLETE

---

## TL;DR

Investigated mystery desktop notifications from PMA's notifier tests firing real `notify-send` calls. Fixed with injectable `sendFunc`. Then discovered and fixed a pre-existing broken Nix build in PMA (missing sub-modules, stale go.sum, dead postPatchExtra). Updated SystemNix flake.lock to consume the fix.

---

## A) FULLY DONE

### 1. PMA Notification Mystery — Root Cause Found & Fixed
- **Problem:** Desktop notifications showing `PMA: Commit Failed [test-project] commit failed: permission denied`
- **Root cause:** `internal/service/notifier_test.go` created `Notifier{Enabled: true}` and called real notification methods → `exec.Command("notify-send", ...)` → actual desktop notifications
- **Fix:** Added injectable `sendFunc func(title, body string) error` to `Notifier` struct (commit `1f144c41`, already pushed)
- **Tests now:** Capture `(title, body)` via injected function and assert on exact values. Zero real notifications.
- **Verified:** `go test ./internal/service/ -v` — all 14 tests pass, no desktop notifications

### 2. PMA Nix Build Fixed (was broken BEFORE our changes)
- **Root cause #1:** Missing `project-discovery-sdk` sub-modules (`domain`, `mr`, `remoteurl`) in `subModules`/`requireDeps` → `go mod tidy` couldn't resolve transitive imports
- **Root cause #2:** Stale `go-output` checksums in `go.sum` (force-pushed upstream, checksums diverged)
- **Root cause #3:** Dead `postPatchExtra` sed commands targeting non-existent `gogenfilter v3.0.0+incompatible`
- **Fix:** Added 3 missing sub-modules, fixed go.sum, removed dead postPatchExtra, added `overrideModAttrs` + `proxyVendor` + `preBuild` for consistent vendoring
- **Commit:** `0a86c54d` pushed to `master`

### 3. PMA Flake Quality Improvements
| Change | Why |
|--------|-----|
| `version = self.rev or self.dirtyRev or "dev"` | AGENTS.md convention — internal overlay, no formal release process |
| Removed `gcc`, `gnumake` from devShell | `CGO_ENABLED=0` everywhere |
| `mkShellNoCC` for CI shell | No C compiler needed |
| `GOWORK = "off"` in default devShell | Was missing (present in package env + CI) |
| Removed `go install art-dupl` from shellHook | Network access in shell init is anti-pattern |
| Fixed `install-hooks` indentation | Was misaligned |

### 4. SystemNix Updated
- `flake.lock` updated → PMA now at `0a86c54d`
- `just test-fast` passes (all NixOS module checks OK)

---

## B) PARTIALLY DONE

### 5. SystemNix Uncommitted Changes (pre-existing, NOT from this session)
The working tree has 4 uncommitted files that predate this session:

| File | Change | Status |
|------|--------|--------|
| `flake.lock` | PMA update + other input updates | Updated this session |
| `overlays/linux.nix` | `dnsblockd` vendorHash, `emeet-pixyd` migration to `mkPackageOverlay` | Pre-existing |
| `overlays/shared.nix` | Multiple vendorHash updates, `mr-sync`/`buildflow`/`go-auto-upgrade`/`branching-flow` hash bumps, activitywatch comment cleanup | Pre-existing |
| `platforms/nixos/system/configuration.nix` | `user = "lars"` for emeet-pixyd | Pre-existing |

**These need to be committed separately** — they are NOT part of this session's work.

---

## C) NOT STARTED

### 6. PMA NixOS Module / systemd Service
PMA has a skeleton `deploy/systemd/projects-management-automation.service` but:
- No NixOS module (no `module.nix`, no `nixos/` directory)
- Hardcoded `/usr/local/bin/` path instead of Nix store
- `service stop` returns "not yet implemented"
- No timer for scheduled commits
- No SSH key access for git push
- Not wired through SystemNix's `harden`/`serviceDefaults`

### 7. PMA `Notifier` Interface Extraction
Currently a concrete struct with `sendFunc` injection. Could be extracted to an interface (`NotificationSender`) for proper DI through the container. Low priority — current approach works.

### 8. PMA Test Infrastructure Cleanup
- `GoProjectWithDepsTemplate` hardcodes `module test-project` (should use template variable)
- `createGoProject()` in BDD steps hardcodes `module test-project`
- These don't cause real problems but reduce reusability

### 9. PMA `godbus/dbus` for Notifications
Currently shells out to `notify-send` via `exec.Command`. Could use `godbus/dbus` for proper D-Bus integration — avoids process spawning, supports actions, persistence hints, etc.

### 10. Pre-existing BuildFlow Failures
BuildFlow pre-commit hook fails on 7 pre-existing issues:
- `golangci-lint` gosec config (`rules` not allowed)
- `todo-check` (119 TODO comments)
- `library-policy` (37 violations — testify, goyaml, etc.)
- `gitleaks` (4 potential secrets in old status docs)
- `doc-files-age-check` (README + TODO_LIST outdated)

---

## D) TOTALLY FUCKED UP

### Nothing catastrophically broken.

**Near-misses:**
- Spent ~30 min debugging `go mod tidy` failures in Nix sandbox before realizing the build was already broken before our changes
- Should have checked `git stash && nix build` FIRST to establish baseline
- Didn't notice `sendFunc` was already committed — was editing an already-fixed file

---

## E) WHAT WE SHOULD IMPROVE

### In PMA:
1. **Extract `NotificationSender` interface** — enables mocking in tests, DI container wiring, future backends (Slack, Discord, etc.)
2. **Fix `GoProjectWithDepsTemplate`** — use `{{.ProjectName}}` instead of hardcoded `test-project`
3. **Add NixOS module to flake outputs** — so SystemNix can `imports = [ pma.nixosModules.default ];`
4. **Fix BuildFlow failures** — gosec config, library policy violations
5. **Add `doCheck = true` with `checkFlags = ["-short"]`** — once the concurrent access test is fixed

### In SystemNix:
6. **Commit the 4 uncommitted files** — vendorHash updates, emeet-pixyd migration
7. **Create PMA systemd service** — once PMA has a NixOS module

### In go-nix-helpers:
8. **Add `goModTidy` option to `mkPreparedSource`** — automatically run tidy after patching, with `HOME=$TMPDIR`

### Process:
9. **Always establish build baseline first** — `nix build` before any changes
10. **Commit step-by-step** — one logical change per commit, not batched

---

## F) Top 25 Things To Do Next (sorted by impact/effort)

| # | Task | Impact | Effort | Repo |
|---|------|--------|--------|------|
| 1 | Commit SystemNix uncommitted overlay changes | High | Low | SystemNix |
| 2 | Fix PMA gosec config (`rules` not allowed) | Medium | Low | PMA |
| 3 | Fix `GoProjectWithDepsTemplate` hardcoded `test-project` | Low | Low | PMA |
| 4 | Create PMA NixOS module in flake outputs | High | Medium | PMA |
| 5 | Wire PMA NixOS module into SystemNix | High | Low | SystemNix |
| 6 | Add `goModTidy` option to `mkPreparedSource` | High | Medium | go-nix-helpers |
| 7 | Enable `doCheck = true` in PMA flake | Medium | Low | PMA |
| 8 | Fix PMA concurrent access flaky test | Medium | Medium | PMA |
| 9 | Extract `NotificationSender` interface in PMA | Medium | Medium | PMA |
| 10 | Replace `exec.Command("notify-send")` with `godbus/dbus` | Low | Medium | PMA |
| 11 | Implement `service stop` in PMA (PID file) | Medium | Medium | PMA |
| 12 | Add PMA systemd timer for scheduled commits | High | Medium | SystemNix |
| 13 | Fix PMA library-policy violations (testify→ginkgo) | Low | High | PMA |
| 14 | Migrate PMA from `gopkg.in/yaml.v3` to `go-faster/yaml` | Low | Medium | PMA |
| 15 | Clean up PMA `deploy/systemd/` → proper NixOS module | High | Medium | PMA |
| 16 | Add `GONOSUMCHECK`/`GONOSUMDB` to PMA flake for private deps | Low | Low | PMA |
| 17 | Remove dead `go_homedir` dep from PMA (use `os.UserHomeDir()`) | Low | Low | PMA |
| 18 | Add BTRFS /data snapshot migration (`just snapshot-migrate-data`) | High | High | SystemNix |
| 19 | Set up Hetzner Storage Box + BorgBackup offsite backup | High | High | SystemNix |
| 20 | Archive old status docs (100+ files in `docs/status/`) | Low | Low | SystemNix |
| 21 | Add `GOWORK=off` check to PMA pre-commit hook | Low | Low | PMA |
| 22 | Fix gitleaks false positives in PMA status docs | Low | Low | PMA |
| 23 | Consolidate PMA `pkg/domain/types/` with `pkg/domain/domain/` | Medium | High | PMA |
| 24 | Add `nilaway` or `errcheck` to PMA CI pipeline | Medium | Low | PMA |
| 25 | Create `docs/planning/` with Pareto execution graph | Low | Medium | PMA |

---

## G) Top #1 Question I Cannot Figure Out Myself

**What is the intended relationship between PMA's auto-commit service and git signing?**

PMA's `service start` watches file changes and auto-commits. But:
- If `commit.gpgsign = true` (which git config might set globally), auto-commits will fail (no TTY for passphrase)
- If `commit.gpgsign = false` is set in test repos (as `git_test_helper.go` does), that's fine for tests but production auto-commits need a policy
- SSH signing (`gpg.format = ssh`) could work if SSH agent is available in the service context
- Should the systemd service run with `GIT_CONFIG_PARAMETERS` to force/override signing?

**This matters for designing the NixOS module** — the service needs to know how to handle signing before we wire it up.

---

## Commits This Session

| Commit | Repo | Description |
|--------|------|-------------|
| `1f144c41` | PMA | `feat(notifier): add injectable sendFunc for testable notification dispatching` |
| `0a86c54d` | PMA | `fix(flake): fix nix build and improve flake quality` |
| *(uncommitted)* | SystemNix | `flake.lock` update for PMA + pre-existing overlay changes |

---

## Files Changed

### PMA (committed & pushed)
- `internal/service/notifier.go` — added `sendFunc` field + nil check
- `internal/service/notifier_test.go` — inject capture func, assert on title/body, added `TestNotifyConflict_ManyFiles`
- `flake.nix` — version, sub-modules, vendorHash, overrideModAttrs, proxyVendor, devShell cleanup
- `go.mod` — updated by `go mod tidy`
- `go.sum` — fixed stale `go-output` checksums

### SystemNix (uncommitted)
- `flake.lock` — PMA updated to `0a86c54d`
- `overlays/linux.nix` — dnsblockd vendorHash, emeet-pixyd migration
- `overlays/shared.nix` — multiple vendorHash updates
- `platforms/nixos/system/configuration.nix` — emeet-pixyd `user = "lars"`
