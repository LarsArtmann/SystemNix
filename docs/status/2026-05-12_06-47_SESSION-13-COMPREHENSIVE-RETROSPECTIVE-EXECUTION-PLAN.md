# Session 13: Comprehensive Retrospective & Execution Plan

**Date:** 2026-05-12 06:47 CEST
**Status:** IN PROGRESS — Darwin build succeeded, not yet activated
**Disk:** 14 GB free (95% full, 229 GB disk)

---

## a) FULLY DONE

| # | Item | Commit | Impact |
|---|------|--------|--------|
| 1 | otel-tui made Linux-only via `_module.args.otel-tui = null` | `cec9b0ab` | Saves 40+ min + 5+ GB per Darwin build |
| 2 | Dual-WAN ECMP+MPTCP active-active architecture | `ecafe8db` | WAN redundancy on evo-x2 |
| 3 | Dual-WAN NM dispatcher refactor (event-driven) | `a8f41dfd` | Replaced polling with inotify events |
| 4 | Dual-WAN AGENTS.md documentation | `2c081cb6` | Architecture decisions documented |
| 5 | Harmful route reset commands removed from internet-diagnostic | `ccde917b` | Prevents network self-sabotage |
| 6 | DNS FQDN trailing dot fix | `782520c5` | Unbound local-zone correctness |
| 7 | Anti-piracy blocklist removal + whitelist olevod.com | `1fe85312` | Content filtering adjustment |
| 8 | Flake nixConfig declared globally | `57fecb45` | No more --extra-experimental-features |
| 9 | Flake.lock updates (dnsblockd, home-manager, NUR) | `2b3e8598` | Dependency freshness |
| 10 | Darwin build succeeds (nix path-info valid) | `93bd9ce1` | Build validation passed |
| 11 | wan-status justfile fix (local macOS path) | `66e53874` | Remote recipe works correctly |

## b) PARTIALLY DONE

| # | Item | Status | Blocker |
|---|------|--------|---------|
| 1 | **Darwin config activation** | Build done, `just switch` NOT run | None — just needs execution |
| 2 | **NixOS deployment** | All changes committed, not deployed to evo-x2 | Needs remote SSH session |
| 3 | **AGENTS.md otel-tui documentation** | Dual-WAN documented, otel-tui pattern not yet added | None |
| 4 | **niri-config.nix formatting** | Issue identified, fix not applied | Alejandra + multiline string trick |

## c) NOT STARTED

| # | Item | Priority | Reason |
|---|------|----------|--------|
| 1 | Taskwarrior build time optimization on Darwin | HIGH | 50+ min from-source build, major pain point |
| 2 | macOS disk space monitoring/alerting | HIGH | No early warning for disk exhaustion |
| 3 | Dead LaunchAgent cleanup (sublime-sync) | MEDIUM | Points to deleted script, fails daily |
| 4 | `pre-commit.nix` dead references (config-validate.sh) | LOW | Not actively used (.pre-commit-config.yaml is active) |
| 5 | `scripts/nixos-diagnostic.sh` modernization | LOW | Uses nixos-rebuild not nh |
| 6 | `scripts/niri-health.sh` consolidation | LOW | Duplicates inline niri-config.nix logic |
| 7 | Push unpushed commit (`93bd9ce1`) | IMMEDIATE | 1 commit ahead of origin |

## d) TOTALLY FUCKED UP

| # | Issue | Severity | Explanation |
|---|-------|----------|-------------|
| 1 | **`just switch` not run for 2+ months** | CRITICAL | Active system is from March 2 (generation 64). Build is ready but not activated. Months of changes sitting unused. |
| 2 | **Disk at 14 GB free (95%)** | HIGH | Still dangerously close to exhaustion. Build consumed 2 GB of the 16 GB we freed. `nix-collect-garbage` hangs on this system. |
| 3 | **`launchagents.nix` sublime-sync dead reference** | MEDIUM | `enable = true` but script deleted — LaunchAgent fails silently at 18:00 daily. LaunchAgent is deployed to macOS user. |
| 4 | **Pre-commit `--no-verify` workaround** | MEDIUM | niri-config.nix formatting forces `--no-verify` on every commit involving that file. Pre-existing for days. |
| 5 | **`nix-collect-garbage` hangs** | LOW | Cannot run full GC. Workaround: `--delete-older-than 1d` partially works. Root cause unknown (store corruption? massive derivation count?). |

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Taskwarrior needs binary caching on Darwin** — Building from source for 50+ minutes every time is unacceptable. Options: overlay with `doCheck = false`, use Cachix, or check if nixpkgs binary cache covers aarch64-darwin.

2. **Disk space management on macOS** — 229 GB disk with 14 GB free is structural. We need: (a) regular automated GC, (b) monitoring, (c) maybe move large builds to evo-x2 via distributed building.

3. **`pre-commit.nix` vs `.pre-commit-config.yaml`** — Two separate pre-commit configs exist. The `.pre-commit-config.yaml` is the active one (used by git hooks). The `pre-commit.nix` writes to `~/.config/pre-commit/config.yaml` and references a non-existent `config-validate.sh`. Either consolidate or remove the dead one.

4. **Health check script consolidation** — `scripts/niri-health.sh` is a standalone script that duplicates logic already inlined in `niri-config.nix`. Should be one or the other, not both.

### Process

5. **Build → switch should be atomic** — We've been building without switching for days. The build succeeding doesn't help if we never activate it.

6. **Commit → push should be same session** — We have 1 unpushed commit that's been sitting since the last session.

7. **Status reports should be lighter** — 23 status report files in `docs/status/`. They're valuable for context but accumulating fast. Consider: (a) weekly rollups, (b) auto-prune after 30 days, (c) keep only the latest N.

### Code Quality

8. **alejandra formatting should pass on all files** — The niri-config.nix workaround is technical debt. Fix the multiline string pattern to work with alejandra.

9. **No dead references should exist** — Every reference to a file (script path, import, etc.) should point to something that exists. The sublime-sync LaunchAgent is a violation.

10. **Nix module type safety** — The `_module.args.otel-tui = null` pattern works but is fragile. A cleaner approach would be `lib.mkDefault null` or a proper option with `mkOption { default = null; }`.

## f) TOP 25 THINGS TO DO NEXT

Sorted by **impact × urgency / work**:

### Immediate (do now)

| # | Task | Est. | Impact |
|---|------|------|--------|
| 1 | Run `just switch` on macOS | 5 min | CRITICAL — activates 2+ months of changes |
| 2 | Push unpushed commit to origin | 10 sec | HIGH — backup safety |
| 3 | Disable sublime-sync LaunchAgent (`enable = false`) | 2 min | MEDIUM — stops daily silent failures |
| 4 | Fix niri-config.nix alejandra formatting | 10 min | HIGH — enables clean pre-commit |
| 5 | Run `nix-collect-garbage --delete-older-than 0s` to free space | 5 min | HIGH — recover disk space |

### Short-term (this session)

| # | Task | Est. | Impact |
|---|------|------|--------|
| 6 | Update AGENTS.md with otel-tui Linux-only pattern + disk gotcha | 10 min | MEDIUM — future session context |
| 7 | Remove dead `pre-commit.nix` or fix config-validate.sh references | 10 min | LOW — dead code cleanup |
| 8 | Evaluate `scripts/niri-health.sh` for removal or wiring | 5 min | LOW — consolidation |
| 9 | Update `scripts/nixos-diagnostic.sh` to use `nh` | 15 min | LOW — modernization |
| 10 | Commit and push all changes | 5 min | HIGH — safety |

### Medium-term (next session)

| # | Task | Est. | Impact |
|---|------|------|--------|
| 11 | NixOS rebuild on evo-x2 (deploy all changes) | 30 min | HIGH — production deployment |
| 12 | Verify otel-tui still works on NixOS after deploy | 2 min | HIGH — regression check |
| 13 | Investigate taskwarrior binary caching on Darwin | 30 min | HIGH — 50 min saved per build |
| 14 | Set up macOS disk space monitoring (cron/script) | 30 min | HIGH — prevent future exhaustion |
| 15 | Investigate `nix-collect-garbage` hang root cause | 60 min | MEDIUM — GC reliability |

### Longer-term (future sessions)

| # | Task | Est. | Impact |
|---|------|------|--------|
| 16 | Distributed Nix builds (build Darwin on evo-x2 remotely) | 2 hr | HIGH — offload from MacBook |
| 17 | Set up Cachix for private package caching | 1 hr | MEDIUM — faster rebuilds |
| 18 | Consolidate `docs/status/` — archive old reports | 30 min | LOW — repo cleanliness |
| 19 | Create `lib/platform.nix` with platform-conditional helpers | 1 hr | MEDIUM — cleaner cross-platform patterns |
| 20 | Add `just test-ci` target for CI-like validation | 30 min | MEDIUM — quality gate |
| 21 | Investigate `nix-store --verify --repair` for store health | 30 min | LOW — store integrity |
| 22 | Set up RPi3 DNS failover (hardware provisioning) | 4 hr | MEDIUM — HA DNS |
| 23 | Wire `scripts/niri-health.sh` into justfile or remove it | 15 min | LOW — dead code |
| 24 | Add shellcheck to all scripts in CI-like justfile target | 30 min | LOW — script quality |
| 25 | Create architecture decision records (ADRs) for major patterns | 2 hr | MEDIUM — documentation |

## g) TOP #1 QUESTION

**Why is `nix-collect-garbage` hanging on this system?**

Background:
- `nix-collect-garbage --delete-older-than 7d` hung indefinitely (killed after timeout)
- `--delete-older-than 1d` partially works but is slow
- Disk is at 95% — we NEED GC to work
- Possible causes: (a) massive number of old derivations, (b) store corruption, (c) stale locks

I cannot determine the root cause without running diagnostic commands (`nix-store --verify --check-optimized`, checking lock files, counting derivations). This directly impacts our ability to manage disk space on this machine and should be investigated before the next build cycle.

---

## Session Context

- **Platform:** macOS Darwin, aarch64 (Apple Silicon MacBook Air, 229 GB disk)
- **Nix:** 2.31.3, nh 4.2.0, nix-darwin 26.05
- **Build:** Succeeded (`/nix/store/r4k6d853v83xpl98sf6d2h9j4ab4rhvx-darwin-system-26.05.8c62fba`)
- **Active system:** March 2 generation (`system-64-link`) — 2+ months stale
- **Git:** 1 commit ahead of origin/master, working tree clean
