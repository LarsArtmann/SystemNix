# Session 113 — PMA Service Stop Fix, Sub-Module Cascade, Build Status

**Date:** 2026-06-01 12:58 CEST
**Duration:** ~1 hour (continuation of session 112)
**Status:** ⚠️ PARTIALLY COMPLETE

---

## TL;DR

Fixed `pma service stop` (was broken — PID file never acquired on start). Then hit a cascading sub-module issue: `project-discovery-sdk` added 3 new `enrichment/*` sub-modules and `go-filewatcher` moved to `/v2` module path — both broke the Nix build. Fixed the sub-modules but PMA still can't compile due to `go-output`/`cmdguard`/`meta` API mismatches (pre-existing, unrelated to flake changes).

---

## A) FULLY DONE

### 1. `pma service stop` — Now Works
- **Root cause:** `runServiceStart` never acquired the PID file lock, so `runServiceStop` always said "Service is not running"
- **Fix:** Acquire PID file at start, defer release on shutdown, prevent duplicate instances
- **Commit:** `d10e924b` in PMA, pushed to master

### 2. PMA flake.nix — Sub-Module Coverage Complete
- Added `enrichment/codestats`, `enrichment/git`, `enrichment/visibility` to `subModules` + `requireDeps`
- Fixed `go-filewatcher` dep mapping: `github.com/larsartmann/go-filewatcher/v2` (not `/v2` subdirectory, the module path IS `/v2`)
- **Commit:** `cdf8e28a` in PMA, pushed to master

### 3. SystemNix flake.lock Updated
- PMA pinned to `cdf8e28a`
- PMA package evaluates correctly

---

## B) PARTIALLY DONE

### 4. PMA Nix Build — Vendoring Fixed, Compilation Blocked

The go-modules derivation (vendoring) now succeeds. But the actual Go compilation fails with pre-existing API mismatches:

```
go-output/markup: HasFooter/Footer undefined on TableData
go-output/delimited: HasFooter/Footer undefined on TableData
cmdguard/v2/output.go: undefined: output.MarshalJSON, MarshalTSV, MarshalYAML, etc.
meta/adapter.go: undefined: meta.Tag, meta.Importance, meta.ProjectName, etc.
committer/committer.go: undefined: providers.NewFallback
```

**What this means:** `go-output`, `cmdguard`, and `project-meta` have all evolved their APIs but PMA's `go.mod` pins older versions that don't match. The `_local_deps` replace directives point to flake inputs which fetch the latest `master` — but the source code expects the older API.

**To fix:** PMA's source code needs updating to match the current `go-output`/`cmdguard`/`meta` APIs, OR the flake inputs need pinning to the versions PMA's code expects.

---

## C) NOT STARTED

### 5. PMA NixOS Module
- No module exists yet
- Blocked on build working first

### 6. Systemd Timer for Auto-Commit
- Design discussed: `pma service start` with `debounce_duration: 5m`, `min_commit_interval: 5m`
- Config fields exist and are wired (verified in session 112)
- Blocked on build working

### 7. PMA `run` Command Build
- `nix run .#run -- service start` fails with same API mismatch
- Same blocker as #4

---

## D) TOTALLY FUCKED UP

### 8. PMA Source Code vs Dependency APIs

The core blocker: PMA's source code imports APIs that no longer exist in the deps fetched by the flake. This is a **code-level issue**, not a flake issue. Three separate dep mismatches:

| Dep | Missing API | Likely Cause |
|-----|-------------|--------------|
| `go-output` | `TableData.HasFooter`, `TableData.Footer` | `go-output` added footer support, PMA hasn't adopted |
| `cmdguard` | `output.MarshalJSON`, `output.MarshalTSV`, etc. | `cmdguard` expects newer `go-output` serialization API |
| `project-meta` | `meta.Tag`, `meta.Importance`, `meta.ProjectName` | `project-meta` changed its type exports |

**This is not something I can fix from the flake alone** — it requires updating PMA's Go source code to match the current dependency APIs.

---

## E) WHAT WE SHOULD IMPROVE

### Immediate (blocks everything):
1. **Fix PMA's Go source to match current dep APIs** — the build is the gate for everything else
2. **Consider pinning flake inputs** to known-good revisions instead of always tracking `master`

### Architectural:
3. **`mkPreparedSource` should auto-discover sub-modules** — currently manual, breaks every time PDS adds one
4. **The sub-module cascade problem** — every new PDS sub-module breaks PMA's build. This needs a structural fix in `go-nix-helpers`

### Process:
5. **Stop trying to build when source doesn't compile** — wasted time on vendor hash when the code itself is broken

---

## F) Top 25 Things To Do Next

| # | Task | Impact | Effort | Status |
|---|------|--------|--------|--------|
| 1 | Fix PMA `go-output` API mismatch (HasFooter/Footer) | **Critical** | Medium | Blocked on understanding new API |
| 2 | Fix PMA `cmdguard` API mismatch (MarshalJSON etc.) | **Critical** | Medium | Blocked on go-output fix first |
| 3 | Fix PMA `project-meta` API mismatch (Tag, Importance) | **Critical** | Low | Blocked on understanding new types |
| 4 | Fix PMA `committer` providers.NewFallback | **Critical** | Low | Likely cascades from go-output fix |
| 5 | Rebuild PMA vendorHash after source fixes | **Critical** | Low | After #1-4 |
| 6 | Create PMA NixOS module | High | Medium | After build works |
| 7 | Wire PMA NixOS module into SystemNix | High | Low | After #6 |
| 8 | Add systemd timer for PMA auto-commit (5m debounce) | High | Low | After #6 |
| 9 | Commit SystemNix uncommitted overlay changes | Medium | Low | Independent |
| 10 | Fix SystemNix `go-structure-linter` overlay error | Medium | Low | Independent |
| 11 | Auto-discover sub-modules in `mkPreparedSource` | High | High | Long-term |
| 12 | Pin PMA flake inputs to specific commits | Medium | Low | Risk mitigation |
| 13 | Fix PMA gosec config (`rules` not allowed) | Low | Low | PMA |
| 14 | Fix PMA concurrent access flaky test | Medium | Medium | PMA |
| 15 | Extract `NotificationSender` interface | Medium | Medium | PMA |
| 16 | Replace `notify-send` with `godbus/dbus` | Low | Medium | PMA |
| 17 | Fix `GoProjectWithDepsTemplate` hardcoded test-project | Low | Low | PMA |
| 18 | Set up Hetzner Storage Box + BorgBackup | High | High | SystemNix |
| 19 | Add BTRFS /data snapshot migration | High | High | SystemNix |
| 20 | Archive old status docs (100+ files) | Low | Low | SystemNix |
| 21 | Fix gitleaks false positives in PMA status docs | Low | Low | PMA |
| 22 | Add `nilaway` or `errcheck` to PMA CI | Medium | Low | PMA |
| 23 | Consolidate PMA `pkg/domain/types/` with `pkg/domain/domain/` | Medium | High | PMA |
| 24 | Migrate PMA from `gopkg.in/yaml.v3` to `go-faster/yaml` | Low | Medium | PMA |
| 25 | Remove dead `go_homedir` dep from PMA | Low | Low | PMA |

---

## G) Top #1 Question I Cannot Figure Out Myself

**What changed in `go-output`'s `TableData` API and what is the migration path?**

PMA's code references `data.HasFooter` and `data.Footer` on `output.TableData`, but the current `go-output@v0.6.1` doesn't have these fields. I need to know:
- Were they renamed? Moved to a different type?
- Is there a changelog or migration guide?
- What version of `go-output` was PMA last building against?

Similarly for `cmdguard`'s `output.MarshalJSON` etc. — these seem to be serialization functions that were moved or renamed in newer `go-output`.

This blocks everything — I cannot fix the build without understanding the new APIs.

---

## Commits This Session

| Commit | Repo | Description |
|--------|------|-------------|
| `d10e924b` | PMA | `fix(service): acquire PID file on start so service stop works` |
| `cdf8e28a` | PMA | `fix(flake): add all project-discovery-sdk sub-modules + fix go-filewatcher/v2 path` |
| *(uncommitted)* | SystemNix | `flake.lock` update for PMA `cdf8e28a` |

---

## Files Changed

### PMA (committed & pushed)
- `internal/application/commands/service.go` — PID file acquisition on start
- `flake.nix` — enrichment/* sub-modules, go-filewatcher/v2 path, vendorHash

### SystemNix (uncommitted)
- `flake.lock` — PMA updated to `cdf8e28a`
