# Session 39 — Comprehensive Status Report

**Date:** 2026-05-18 18:34 CEST
**Branch:** master @ `e64057c4`
**Platform:** evo-x2 (NixOS x86_64-linux)

---

## a) FULLY DONE

### Version String Fix — All 5 Go Repos
**Problem:** `nh` closure diff couldn't split name/version for packages whose version starts with a letter (e.g., `buildflow-c328098` treated as single name, `hierarchical-errors-ce98e48` shown as `<none>`).

**Fix:** Prefix all versions with `0.0.0-` so version always starts with a digit.

| Repo | Commit | Changes |
|------|--------|---------|
| branching-flow | `ef45f1e` | `0.0.0-` version prefix |
| go-structure-linter | `e29d768` | `0.0.0-` version prefix |
| hierarchical-errors | `267820e` | `0.0.0-` version prefix + dep bumps (ginkgo, gomega, x/tools, x/mod, x/net, x/sys, x/text) |
| projects-management-automation | `76c0eb2b` | `0.0.0-` version prefix |
| BuildFlow | `01f8d1d1` | **Full mkPreparedSource migration** + `0.0.0-` version prefix + go-output updated to latest master |

### BuildFlow mkPreparedSource Migration (Session 38→39 carry-over)
- Replaced 32-line hand-written `preparedSrc` with 15-line `mkPreparedSource` call
- Removed sub-module `require` directives that caused vendor inconsistency
- Added `postPatchExtra` to strip stale absolute-path go-finding replace
- Updated go-output from v0.4.0 to v0.4.1-dev (adds testhelpers sub-module needed transitively)
- Copied `mkPreparedSource.nix` helper into BuildFlow repo

### Session 38 mkPreparedSource v2 Migration (4 repos)
- branching-flow → v1 (flat subModules, `-mod=mod` mode)
- go-structure-linter → v2 (per-dep subModules, vendor mode)
- mr-sync → v2 + dep update (go-output, go-branded-id)
- projects-management-automation → v2 + `postPatchExtra` for gogenfilter sed

### ComfyUI Disabled (Session 38)
- `comfyui.enable = false` — user prefers AI models via code directly
- Module still registered in serviceModules, just disabled

### Verification Results
- `just test-upstream-builds` — **17/17 OK**
- `just hash-check` — **all hashes valid**
- `just test-fast` — **all checks passed**
- `nix flake check --all-systems --no-build` — **passed**

---

## b) PARTIALLY DONE

### TODO_LIST.md — 14 Unchecked Items Remain
**File:** `TODO_LIST.md`

| Item | Status | Blocker |
|------|--------|---------|
| Deploy to evo-x2 + reboot (kernel update) | **Stale** — may already be deployed | Needs verification |
| Verify all services start clean | **Blocked** — 6 failed units (see section d) | |
| Check SigNoz provision logs | **Not verified** | |
| Test Discord alert channel | **Not verified** | |
| Move dns-failover plaintext password to sops | **Not started** | |
| Consolidate voice-agents Caddy vHost | **Not started** | |
| nix-colors integration (17+ hardcoded colors) | **Not started** — ~6h estimate | |
| Deploy Dozzle (Docker log tailing) | **Not started** | |
| Provision Pi 3 for DNS failover | **Not started** — hardware not available | |
| Wire Pi 3 as secondary DNS | **Blocked** — hardware | |

### Built-but-Not-Installed Packages
- `netwatch` — overlay builds it, but it's NOT in `base.nix` or any `environment.systemPackages`. Should be added or the overlay removed.

### Dead/Stale Files
- `flake.lib` export (`inputs.self.lib`) — exported but **zero consumers** in this repo. Only consumed by upstream private repos via `lib/prepared-source.nix`.
- `jscpd-package-lock.json` — was removed in session 37 commit `3e5ce96d`.

---

## c) NOT STARTED

### High-Impact Backlog
1. **Refactor remaining hand-written preparedSrc repos** — all 5 private Go repos now migrated, but the pattern could be further extracted into a shared flake input
2. **Create `mk-pnpm-package.nix` reusable helper** — for todo-list-ai's fixed-hash pattern
3. **Implement `just hash-check --fix` auto-repair** — currently manual process
4. **Set up cachix or attic** for faster rebuilds across 3 machines
5. **CI spec for pre-merge validation** — no GitHub Actions for SystemNix

### Medium-Impact Backlog
6. **Flake input audit** — 137 transitive inputs is excessive, prune unused
7. **Document `overrideModAttrs` pattern** — discovered during BuildFlow migration
8. **Write session 35/36 case study** — vendor hash cascade incident
9. **Dependency graph visualization** — D2 diagram of overlay dependency tree
10. **Go sub-module tag automation** — prevent `testhelpers/v0.0.0` tag issues

### Documentation Backlog
11. **FEATURES.md references 4 non-existent scripts** — `benchmark-system.sh`, `performance-monitor.sh`, `shell-context-detector.sh`, `storage-cleanup.sh` — all listed as features but files don't exist
12. **Consolidate/archive 55+ status docs** in `docs/status/`
13. **Write upstream fix playbook** — step-by-step vendorHash recovery

### Hardware Backlog
14. **Provision Raspberry Pi 3** — DNS failover cluster requires hardware
15. **Darwin disk space strategy** — MacBook Air at 90-95% full, need distributed builds to evo-x2
16. **Investigate GMKtec BIOS updates** for >130W power ceiling

---

## d) TOTALLY FUCKED UP

### 6 Failed Systemd Units (from `just health`)

| Unit | Impact | Likely Cause |
|------|--------|--------------|
| `caddy.service` | **CRITICAL** — all `*.home.lan` services unreachable | Config error or missing TLS cert |
| `blocklist-auto-update.service` | DNS blocklists stale | Depends on network/DNS which depends on caddy |
| `niri-health-metrics.service` | No compositor metrics | May depend on failed units |
| `service-health-check.service` | No service monitoring | Cascading from caddy failure |
| `timeshift-backup.service` | No BTRFS snapshots | Unrelated — likely schedule conflict |
| 2 user units (unnamed) | Unknown | Need investigation |

**Note:** These failures are from the currently RUNNING system, not from our changes. The `just switch` with the new flake.lock has NOT been deployed yet. These failures likely predate this session.

### Disk Warnings
- `/` at **87% used** (69G free) — approaching capacity
- `/data` at **81% used** (198G free)
- `/nix/store` is **88G** — garbage collection may be needed

### `just update-vendor-hashes` False Negatives
The recipe uses `nix build --no-link` which returns "OK" from Nix store cache even when `vendorHash` is stale. This missed the BuildFlow stale hash in Session 36, causing a cascade of 7 broken upstream builds. **`just hash-check` works correctly** (forces fresh build) but the two recipes overlap and should be consolidated.

---

## e) WHAT WE SHOULD IMPROVE

### 1. Deploy Before Reporting
We've been committing but NOT deploying. The failed systemd units may be from an old generation. **Deploy with `just switch` first, then re-check health.**

### 2. Consolidate Hash-Check Tooling
- `just hash-check` — correct, forces fresh builds
- `just update-vendor-hashes` — broken, uses cached results
- **Fix:** Remove `update-vendor-hashes`, enhance `hash-check` with `--fix` flag

### 3. Eliminate `flake.lib` Dead Export
`inputs.self.lib` is exported but never consumed within SystemNix. It only serves `lib/prepared-source.nix` which is copied into upstream repos. Consider: is this the right layer, or should repos own their own copies entirely?

### 4. FEATURES.md Out of Sync
4 features reference scripts that don't exist. Either create the scripts or remove the features. Currently misleading.

### 5. Pre-Merge CI
No automated validation on push. Every flake.lock update risks breaking builds. A GitHub Action running `just test-fast && just test-upstream-builds` would catch regressions.

### 6. Systematic Service Verification
No recipe to verify all systemd services are running after `just switch`. The health check exists but isn't automated post-deploy.

### 7. Netwatch Ghost Package
Built via overlay but not installed. Either add to `base.nix` or remove the overlay entry.

---

## f) Top 25 Things We Should Get Done Next

### Critical (Do First)
1. **Deploy current config** — `just switch` to apply all pending changes
2. **Fix caddy.service** — all reverse-proxied services are down
3. **Verify all 6 failed units** post-deploy
4. **Run garbage collection** — `/` at 87%, `/nix/store` at 88G
5. **Fix `just update-vendor-hashes`** — remove or merge with `hash-check`

### High Impact
6. **Add `netwatch` to `base.nix`** or remove from overlays
7. **Fix FEATURES.md dead script references** — remove or create the 4 missing scripts
8. **Move dns-failover `authPassword` to sops** — plaintext password in nix config
9. **Consolidate `docs/status/`** — 55 files, most should be archived
10. **Set up GitHub Actions CI** — `just test-fast` on push

### Medium Impact
11. **Create `mk-pnpm-package.nix` helper** — generalize todo-list-ai fixed-hash pattern
12. **Audit 137 transitive flake inputs** — prune unused
13. **Add `just hash-check --fix` auto-repair** — set hash to empty, build, capture got: hash
14. **Write vendorHash recovery playbook** — document the cascade incident
15. **Wire nix-colors integration** — 17+ hardcoded color values across modules
16. **Deploy Dozzle** — Docker container log tailing at `logs.home.lan`

### Lower Priority
17. **Provision Pi 3 hardware** — DNS failover cluster
18. **Explore cachix/attic** — faster rebuilds across 3 machines
19. **Darwin distributed builds** — offload to evo-x2 (MacBook disk at 95%)
20. **Document `overrideModAttrs` pattern** — discovered during BuildFlow migration
21. **Dependency graph visualization** — D2 diagram of overlay tree
22. **PhotoMap AI** — fix podman permission issue, re-enable
23. **Auditd re-enablement** — check if NixOS 26.05 bug #483085 is fixed
24. **AppArmor** — currently disabled in security-hardening module
25. **Go sub-module tag automation** — prevent missing tags like `testhelpers/v0.0.0`

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why are 6 systemd units (including caddy) failing on the currently running system?**

The health check shows caddy, blocklist-auto-update, niri-health-metrics, service-health-check, and timeshift-backup all failed. But we haven't deployed the new config yet — the running system is from a previous generation. I cannot run `systemctl status` or read journal logs without the blocked `systemctl` command. The root cause could be:

1. Stale generation with a known caddy config bug already fixed
2. Missing sops secret preventing caddy TLS startup
3. Network issue (caddy can't bind ports if network isn't ready)

**Action needed:** Deploy with `just switch` first, then re-check health. If caddy still fails after deploy, investigate with `just switch` output and caddy logs.

---

## Session Statistics

| Metric | Value |
|--------|-------|
| Upstream repos migrated to mkPreparedSource | 5/5 |
| Upstream repos with version fix | 5/5 |
| Upstream builds passing | 17/17 |
| Vendor hashes valid | 14/14 |
| SystemNix test-fast | PASSED |
| Failed systemd units on running system | 6 |
| Disk usage (/) | 87% |
| SystemNix commits this session | 1 (`e64057c4`) |
| Upstream commits this session | 5 |
| Uncommitted changes | 0 |
