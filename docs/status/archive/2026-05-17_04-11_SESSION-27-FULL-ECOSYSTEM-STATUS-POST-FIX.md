# Session 27 — Dead Code Cleanup + Full Ecosystem Status

**Date:** 2026-05-17 04:11
**Session:** 27
**Trigger:** User requested full comprehensive status update after session 26 fix

---

## System State

| Metric | Value | Status |
|--------|-------|--------|
| Root disk | 446G/512G (90%) | ⚠️ Tight — 51G free |
| /data disk | 819G/1.0T (80%) | OK |
| /nix/store | 86G | Large but expected |
| Branching-flow rev | `20192b4cbf26` | ✅ Latest, builds |
| Latest commit | `8c6e528a` | ✅ Pushed to origin/master |

---

## A. FULLY DONE

### Session 24 (Deduplication Sprint)
- 28 files changed, -196 net lines across the codebase
- Deduplication of lib helpers, service patterns, overlay structure

### Session 25 (Collision Recovery + Deadnix Fixes)
- Resolved parallel agent session collision (sessions 24+25 ran simultaneously)
- Fixed `authelia.nix` undefined `onFailure` → explicit `notify-failure@%n.service`
- Merged systemd attrsets in `manifest.nix` (statix fix)
- Updated `flake.lock` — branching-flow, go-finding, go-output upgraded
- Fixed `disk-monitor.nix` — added missing `onFailure` import

### Session 26 (Branching-Flow VendorHash Fix)
- Root cause diagnosed: stale `vendorHash` after go-output dependency changes
- `go-error-family` made public (unblocked `go mod download` in Nix sandbox)
- Two vendorHash iterations in branching-flow (revs `1475e06` → `20192b4`)
- AGENTS.md go-branded-id gotcha expanded with correct fix procedure
- `nix build .#branching-flow` verified green

### Infrastructure (Cumulative, Last 7 Days)
- ✅ Display watchdog for self-healing dead output detection
- ✅ mkDockerService factory extracted to `lib/docker.nix`
- ✅ All flake inputs updated (26 packages across Go/AI/CLI)
- ✅ Zero `~/go/bin` in sessionPath — all Go tools via Nix overlays
- ✅ govalid Nix package added
- ✅ SSH signing enforced across all commits
- ✅ Catppuccin Mocha theme applied everywhere

---

## B. PARTIALLY DONE

1. **mkDockerService refactoring** — 2/4 Docker services refactored (twenty, photomap still pending)
2. **Full `just switch` deployment** — `nix build .#branching-flow` verified but complete NixOS build not yet tested end-to-end
3. **Go repo vendorHash audit** — Only branching-flow fixed; go-structure-linter, buildflow, etc. may also be stale

---

## C. NOT STARTED

1. **Full `just switch` deployment** — need to run and verify
2. **Adopt file-and-image-renamer's robust postPatch pattern** in branching-flow and other Go repos
3. **mkGatusEndpoint helper** — reusable Gatus endpoint constructor
4. **Consecutive-failure lib helper** — for Gatus alert rules
5. **Caddy vhosts-as-data** — extract virtual host definitions into structured data
6. **Twenty + photomap mkDockerService migration** — remaining 2 Docker services
7. **Archive old docs/status/ files** — 40+ status files accumulating
8. **CI pipeline for private Go repos** — catch stale vendorHash before merge
9. **`just update-vendor-hash` automation** — one-command vendorHash fix
10. **NixOS test suite** — `just test-aliases` for shell alias verification

---

## D. TOTALLY FUCKED UP

1. **Session 26 misdiagnosed twice** — First said "make go-error-family public" (necessary but insufficient), then said "go.sum missing go-branded-id" (it wasn't). Real issue: stale `vendorHash`.
2. **Didn't find existing solution early** — `file-and-image-renamer` already had the robust postPatch pattern that prevents this class of failure. Should have searched for it in step 1.
3. **Had to fix vendorHash twice** — The flake.lock update pulled transitive input changes (go-finding, go-output), invalidating the first fix.
4. **Parallel session collision** — Sessions 24+25 ran simultaneously, creating merge conflicts and requiring manual collision recovery.
5. **AGENTS.md edit silently failed** — File was modified by concurrent session between read and edit; wasn't caught until later verification.
6. **6 sessions of undeployed changes** accumulated before session 25's commit — risk of configuration drift.

---

## E. WHAT WE SHOULD IMPROVE

### Process
1. **No parallel agent sessions** — Concurrent Crush instances modify the same files, causing collisions. Enforce sequential sessions.
2. **Verify edits took effect** — After every edit, verify with `git diff` or re-read the file.
3. **Build before committing** — Run `just test-fast` or `nix build` before every commit.
4. **Deploy after every session** — Accumulating uncommitted/undeployed changes is risky.

### Technical
1. **Adopt file-and-image-renamer's postPatch pattern** across ALL Go repos — Inject `go-branded-id` into `go.mod`/`go.sum` if missing. This eliminates the entire vendorHash-stale-after-dep-change class of failures.
2. **Automate vendorHash updates** — `just update-vendor-hash <repo>` that sets to `""`, builds, extracts `got:` hash, writes back.
3. **Add CI for private Go repos** — `nix build .#default` in GitHub Actions catches stale vendorHash before merge.
4. **Archive old status reports monthly** — Move to `docs/status/archive/` to keep the directory clean.
5. **Disk space monitoring** — Root disk at 90%. Add `nix-collect-garbage` to a weekly timer.
6. **Consider `nix-auto-gc`** — Automatic garbage collection when store exceeds threshold.

### Architecture
1. **Extract Caddy vhost definitions** into structured Nix data — Currently hardcoded in `caddy.nix`, should be derived from service configs.
2. **Unified service module template** — Common pattern for systemd services with hardening, onFailure, Gatus health checks.
3. **Go repo template** — Standard flake.nix with correct prepared-source, postPatch, vendorHash patterns.

---

## F. Top 25 Things To Do Next (Sorted by Impact/Effort)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | **Run `just switch` — deploy all accumulated changes** | Critical | Low | Deploy |
| 2 | Commit dead-code cleanup: minecraft.nix + voice-agents.nix unused `onFailure` | Low | Low | Cleanup |
| 3 | Verify full NixOS build passes end-to-end | Critical | Low | Verify |
| 4 | Adopt file-and-image-renamer postPatch in branching-flow | High | Low | Prevention |
| 5 | Check go-structure-linter vendorHash isn't stale | High | Low | Fix |
| 6 | Check buildflow vendorHash isn't stale | High | Low | Fix |
| 7 | Audit all Go overlay repos for stale vendorHash | Medium | Medium | Fix |
| 8 | Migrate twenty to mkDockerService | Medium | Low | Refactor |
| 9 | Migrate photomap to mkDockerService | Medium | Low | Refactor |
| 10 | Add `just update-vendor-hash` command | Medium | Medium | Tooling |
| 11 | Archive old docs/status/ files to archive/ | Low | Low | Cleanup |
| 12 | Run `just format` to ensure all .nix files formatted | Low | Low | Quality |
| 13 | Run `just validate-scripts` for shellcheck | Low | Low | Quality |
| 14 | Run `just test-fast` for syntax validation | Medium | Low | Quality |
| 15 | Add weekly `nix-collect-garbage` timer | Medium | Low | Maintenance |
| 16 | Extract Caddy vhost definitions into structured data | High | High | Architecture |
| 17 | Create mkGatusEndpoint helper | Medium | Medium | Library |
| 18 | Create consecutive-failure lib helper for Gatus | Medium | Low | Library |
| 19 | Add CI pipeline for private Go repos | High | High | Prevention |
| 20 | Create Go repo template with correct Nix patterns | Medium | Medium | Tooling |
| 21 | Run `just health` for cross-platform health check | Low | Low | Verify |
| 22 | Check hermes npmDeps hash isn't stale | Medium | Low | Fix |
| 23 | Add `nix flake check` to pre-commit hooks | Medium | Low | Quality |
| 24 | Review all overlay repos for consistent patterns | Medium | Medium | Quality |
| 25 | Consider `nix-auto-gc` for automatic store cleanup | Medium | Low | Maintenance |

---

## G. Top #1 Question I Cannot Figure Out Myself

**Why is root disk at 90% (446G/512G) with 86G in /nix/store alone?**

The Nix store alone is 86G. Combined with system packages, Docker images on `/data`, and kernel/firmware, this explains most usage — but 446G total is very high. I need user input:

1. Is there old data that can be cleaned up outside `/nix/store`?
2. Should we run `nix-collect-garbage --delete-older-than 7d` aggressively?
3. Should Docker image pruning be scheduled (`docker system prune -f`)?
4. Is there accumulated log data or temp files we should check?

This matters because disk exhaustion causes build failures (see session 9/10 history with Darwin disk issues).

---

## Pending Files (Uncommitted)

| File | Change | Risk |
|------|--------|------|
| `modules/nixos/services/minecraft.nix` | Remove unused `onFailure` import | Safe — dead code |
| `modules/nixos/services/voice-agents.nix` | Remove unused `onFailure` import | Safe — dead code |
| `docs/status/2026-05-17_03-58_SESSION-25-...` | Session 25 status report | Documentation |
