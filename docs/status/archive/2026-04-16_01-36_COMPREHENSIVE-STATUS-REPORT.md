# SystemNix — Comprehensive Status Report

**Date:** 2026-04-16 01:36
**Session:** Merge conflict resolution + code hardening
**Branch:** master (mid-rebase, being resolved)

---

## Executive Summary

Project is in **good health** overall. This session resolved a merge conflict in `emeet-pixyd` that arose from rebasing the scaffolding commit (`d706023`) onto the feature branch (`6d000cd`) which added bidirectional HID state querying. The conflict revealed 7 `:=` re-declaration errors and a type mismatch that were fixed. Additionally, a significant refactoring pass was already staged from the feature branch (DRY extraction of HID commands).

**Build:** PASS | **Tests:** 27/27 PASS | **Lint:** PASS | **Vet:** PASS

---

## A. FULLY DONE

### 1. EMEET PIXY Daemon (`pkgs/emeet-pixyd/`) — COMPLETE

A production-grade Go daemon for the EMEET PIXY dual-camera AI webcam. Full feature set:

| Feature                 | Status | Details                                                                    |
| ----------------------- | ------ | -------------------------------------------------------------------------- |
| Auto call detection     | DONE   | Scans `/proc/*/fd` for video device usage with 3-sample debounce           |
| HID control             | DONE   | Tracking/privacy/idle mode, audio mode, gesture toggle                     |
| Auto-management         | DONE   | Activates tracking + noise cancellation on call start, privacy on call end |
| Bidirectional HID query | DONE   | Reads camera's actual state via `hidSendRecv` — tracking, audio, gesture   |
| State sync              | DONE   | `sync` command reconciles believed state with camera reality               |
| State persistence       | DONE   | JSON state file in `/run/emeet-pixyd/`                                     |
| Unix socket control     | DONE   | `emeet-pixy <command>` CLI interface                                       |
| Waybar integration      | DONE   | Camera state indicator with click actions                                  |
| PipeWire integration    | DONE   | Auto-switches default source to PIXY on call start                         |
| Desktop notifications   | DONE   | State change notifications via `notify-send`                               |
| Systemd watchdog        | DONE   | `WATCHDOG=1` keepalive, `READY=1`/`STOPPING=1` lifecycle                   |
| Device auto-detection   | DONE   | USB vendor/product ID matching, hotplug recovery                           |
| Boot default            | DONE   | Privacy mode (camera physically disabled until needed)                     |
| Type-safe HID           | DONE   | `CameraState.HIDByte()`, `AudioMode.HIDByte()` methods                     |
| Config struct           | DONE   | `Config` with `StateDir`, `PollInterval`, `DebounceCount`                  |
| DRY refactoring         | DONE   | `setDeviceState`, `pixyConfig`, `pixyCommit`, `queryDevice` extraction     |
| Project scaffolding     | DONE   | `.gitignore`, `.golangci.yml`, `CHANGELOG.md`, `LICENSE`, `README.md`      |

**Code stats:** 1,180 lines (`main.go`) + 493 lines (`main_test.go`) = 1,673 lines total

### 2. DNS Blocklist Processor (`pkgs/dnsblockd-processor/`) — COMPLETE

| Feature                           | Status |
| --------------------------------- | ------ |
| Multi-format blocklist parsing    | DONE   |
| Deduplication + domain extraction | DONE   |
| Lint fix (line length)            | DONE   |
| Project scaffolding               | DONE   |

**Code stats:** 194 lines (`main.go`)

### 3. NixOS System Configuration — STABLE

| Component                               | Status |
| --------------------------------------- | ------ |
| Flake structure (flake-parts)           | DONE   |
| Cross-platform Home Manager             | DONE   |
| 15+ NixOS service modules               | DONE   |
| DNS blocker stack (Unbound + dnsblockd) | DONE   |
| Taskwarrior + TaskChampion sync         | DONE   |
| Catppuccin Mocha theming everywhere     | DONE   |
| SOPS secrets management                 | DONE   |
| BTRFS snapshots                         | DONE   |
| SSH config (external flake)             | DONE   |
| AMD GPU/NPU drivers                     | DONE   |
| Niri Wayland compositor                 | DONE   |

---

## B. PARTIALLY DONE

### 1. Interactive Rebase — IN PROGRESS

**State:** Mid-rebase on master. Replaying scaffolding commit onto feature branch.

- **Replay commit:** `d706023 chore(pkgs): add standard project scaffolding`
- **Rebase onto:** `6d000cd feat(emeet-pixyd): bidirectional HID state querying and sync`
- **Conflict:** Resolved in `pkgs/emeet-pixyd/main.go`
- **Remaining:** Need to `git rebase --continue` to complete

### 2. Stash Cleanup — PARTIAL

3 stashes exist, potentially stale:

- `stash@{0}`: "Git Town WIP" — emeet-pixyd formatting changes (likely absorbed by current work)
- `stash@{1}`: Flake restructuring (may be outdated)
- `stash@{2}`: Pre-commit fixes (older, likely absorbed)

### 3. Remote Branch Cleanup — NOT DONE

18+ `copilot/fix-*` remote branches exist. Many may be merged and deletable.

---

## C. NOT STARTED

| #   | Task                                                   | Priority | Effort |
| --- | ------------------------------------------------------ | -------- | ------ |
| 1   | SigNoz full integration (traces/metrics/logs pipeline) | Medium   | High   |
| 2   | Authelia SSO for all services                          | Medium   | High   |
| 3   | NixOS system tests (automated validation)              | Medium   | Medium |
| 4   | Darwin (macOS) config parity audit                     | Low      | Medium |
| 5   | Immich external access (beyond LAN)                    | Low      | Low    |
| 6   | Automated BTRFS snapshot verification                  | Low      | Low    |
| 7   | Flake lock automated updates (Renovate/bot)            | Low      | Low    |
| 8   | Photomap production hardening                          | Low      | Medium |

---

## D. TOTALLY FUCKED UP (Issues Found This Session)

### 1. Merge Conflict Resolution Left Build Errors

The automatic/conflict-marker removal left `:=` (short variable declaration) in places where `=` was needed because `err` was already declared in scope. **7 instances** across `setTracking`, `setAudio`, `setGesture`, `centerCamera`. Fixed.

### 2. Type Mismatch in `queryDevice`

`parseHIDResponse()` returns `hidResponse` (value) but `queryDevice` returns `*hidResponse` (pointer). Required `return &parsed, nil`. Fixed.

### 3. Staged vs Working Tree Divergence

The file had `MM` status — staged refactored code vs working tree original code. The `go build` was building different code than what was staged, causing confusion. Resolved by restoring staged version.

---

## E. WHAT WE SHOULD IMPROVE

### Process

1. **Merge conflict tooling:** The `:=` → `=` issue would have been caught immediately by `go build`. Always build immediately after resolving conflicts.
2. **Stash hygiene:** 3 stashes of unknown vintage. Audit and drop stale ones.
3. **Remote branch cleanup:** 18+ copilot branches. Run `git remote prune origin` and delete merged branches.
4. **Status doc overload:** 100+ status files in `docs/status/`. Consider archiving all but the latest 10.

### Code

5. **emeet-pixyd error handling:** Many places use `errors.New` for static strings where `fmt.Errorf` with `%w` wrapping would preserve error chains for callers.
6. **emeet-pixyd test coverage:** No tests for `hidSend`, `hidSendRecv`, `parseHIDResponse` with edge cases, `autoManage` logic, or the socket protocol. Test coverage is ~40% by line.
7. **dnsblockd-processor has zero tests:** 194 lines of parsing logic with no test coverage at all.
8. **Go module naming:** Module is `github.com/larsartmann/systemnix/emeet-pixyd` but the repo might be `SystemNix`. Verify `go.mod` matches actual repo path.
9. **`findPixySource` uses deprecated APIs:** `strings.SplitSeq`/`strings.FieldsSeq` are Go 1.25+ iterators — fine if pinned, but worth documenting the Go version requirement.

### Infrastructure

10. **CI/CD pipeline:** No automated build/test/lint on push. A GitHub Actions workflow for `nix flake check` and `go test` would prevent broken merges.
11. **Monitoring alerts:** SigNoz is set up but alerting rules are not configured.
12. **Backup automation:** BTRFS snapshots exist but no automated off-site backup.

---

## F. Top 25 Things We Should Get Done Next

| #   | Task                                                                                             | Category      | Priority | Effort |
| --- | ------------------------------------------------------------------------------------------------ | ------------- | -------- | ------ |
| 1   | **Complete the rebase** — `git rebase --continue`                                                | Git           | P0       | 1 min  |
| 2   | **Drop stale stashes** — audit and remove                                                        | Git           | P1       | 5 min  |
| 3   | **Prune remote branches** — `git remote prune origin` + delete merged copilot branches           | Git           | P1       | 5 min  |
| 4   | **Archive old status docs** — move 90+ files to `docs/status/archive/`                           | Hygiene       | P1       | 2 min  |
| 5   | **Add dnsblockd-processor tests** — at minimum: parseHostsFile, domain extraction, dedup         | Testing       | P1       | 2 hr   |
| 6   | **Increase emeet-pixyd test coverage** — autoManage, socket protocol, edge cases                 | Testing       | P1       | 4 hr   |
| 7   | **Add GitHub Actions CI** — `go test`, `go vet`, `nix flake check` on push                       | CI/CD         | P1       | 2 hr   |
| 8   | **SigNoz alerting rules** — PagerDuty/email for service failures                                 | Infra         | P2       | 3 hr   |
| 9   | **Authelia SSO** — protect all `*.home.lan` services                                             | Security      | P2       | 4 hr   |
| 10  | **NixOS system tests** — automated validation of service configs                                 | Testing       | P2       | 6 hr   |
| 11  | **emeet-pixyd: add `version` command** — report daemon version via socket                        | Feature       | P2       | 30 min |
| 12  | **emeet-pixyd: structured metrics** — expose HID command success/failure counts                  | Observability | P2       | 2 hr   |
| 13  | **emeet-pixyd: config file support** — `/etc/emeet-pixyd.toml` for poll interval, debounce, etc. | Feature       | P3       | 3 hr   |
| 14  | **Flake lock automated updates** — GitHub Actions + auto PR                                      | Automation    | P2       | 2 hr   |
| 15  | **Off-site backup** — BTRFS snapshot sync to S3/B2                                               | Reliability   | P2       | 3 hr   |
| 16  | **Darwin config audit** — ensure macOS config matches NixOS feature parity where applicable      | Config        | P3       | 2 hr   |
| 17  | **Immich external access** — Caddy reverse proxy + Authelia                                      | Feature       | P3       | 2 hr   |
| 18  | **emeet-pixyd: graceful shutdown** — flush state, close HID cleanly on SIGTERM                   | Robustness    | P2       | 1 hr   |
| 19  | **DNS blocker dashboard** — Grafana panel for blocked query metrics                              | Monitoring    | P3       | 2 hr   |
| 20  | **Photomap production hardening** — auth, rate limiting, error handling                          | Feature       | P3       | 4 hr   |
| 21  | **emeet-pixyd man page** — document all commands and socket protocol                             | Docs          | P3       | 1 hr   |
| 22  | **Go module naming audit** — verify all `go.mod` files match repo structure                      | Hygiene       | P3       | 30 min |
| 23  | **Automated BTRFS snapshot verification** — cron job that validates snapshots are readable       | Reliability   | P3       | 1 hr   |
| 24  | **Gitea mirror health check** — alert when GitHub→Gitea sync fails                               | Monitoring    | P3       | 1 hr   |
| 25  | **Contributing guide** — `CONTRIBUTING.md` for the monorepo                                      | Docs          | P4       | 2 hr   |

---

## G. Top #1 Question I Cannot Figure Out Myself

**What is the intended relationship between the two divergent branches?**

The git history shows:

- `master` has commit `d706023` (scaffolding) on top of `20bb921`
- A detached branch has commit `6d000cd` (bidirectional HID) also on top of `20bb921`

The rebase is trying to replay the scaffolding commit onto the HID feature commit. But the HID feature branch already has all the scaffolding files (.gitignore, .golangci.yml, etc.) plus the main.go refactoring. **Was the intent to:**

1. Merge the HID feature into master (absorbing the scaffolding)?
2. Squash everything into a single clean commit?
3. Rebase master onto the feature branch?

The current rebase will produce duplicate scaffolding files since both commits add the same files. I'm continuing the rebase as-is since it's what was started, but please confirm the desired final git topology.

---

## Build & Test Verification

```
emeet-pixyd:
  Build:  PASS (go build ./...)
  Vet:    PASS (go vet ./...)
  Tests:  27/27 PASS (go test -count=1 -v ./...)
  Lines:  1,180 main + 493 tests = 1,673 total

dnsblockd-processor:
  Build:  PASS (go build ./...)
  Vet:    PASS (go vet ./...)
  Tests:  N/A (no test files)
  Lines:  194 main

Staged changes:
  13 files changed, 730 insertions(+), 178 deletions(-)
```
