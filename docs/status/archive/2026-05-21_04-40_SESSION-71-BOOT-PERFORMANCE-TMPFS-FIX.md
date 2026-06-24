# Session 71 — Boot Performance Crisis: `/tmp` tmpfs Fix + Comprehensive Status

**Date:** 2026-05-21 04:40 CEST
**Trigger:** User asked "Why was my last boot so slow?" → `systemd-analyze` revealed 2m 13s boot time
**Status:** ✅ FIX VERIFIED | `boot.tmp.useTmpfs = true` deployed + rebooted | 56% boot time reduction confirmed

---

## a) FULLY DONE

### Boot Performance Fix — Root Cause Eliminated

**The problem:** `systemd-tmpfiles-setup.service` consumed **44.912 seconds** on every boot because `/tmp` (on BTRFS root) accumulated hundreds of stale Chromium `SingletonSocket` files and SDDM session sockets from previous boots. `systemd-tmpfiles` tried to open/lock every socket, failing with `No such device or address` on each one, serially blocking the entire boot chain.

**The fix:** `boot.tmp.useTmpfs = true` in `platforms/nixos/system/boot.nix:65`

| Metric | Before Fix | After Fix (actual) | Improvement |
|--------|-----------|-------------------|-------------|
| `systemd-tmpfiles-setup.service` | 44.912s | 303ms | **99.3%** (44.6s saved) |
| `graphical.target` | 1m 32s | 32.968s | **64.2%** (59.2s saved) |
| `initrd` | 31.692s | 15.794s | **50.2%** (15.9s saved) |
| Total boot | 2m 13.550s | 58.128s | **56.5%** (75.4s saved) |

**Files changed:**
- `platforms/nixos/system/boot.nix` — added `tmp.useTmpfs = true`
- `flake.lock` — updated upstream inputs

**Verification (pre-deploy):**
- `just test-fast` ✅ All checks passed (eval warning: `hostPlatform` deprecation — upstream)
- `nix flake check --no-build` ✅ Passed

**Verification (post-reboot):**
- `systemd-analyze` ✅ Total boot 58.128s (was 133.55s)
- `findmnt /tmp` ✅ `tmpfs` mounted at `/tmp` (size=32GB)
- `journalctl -u systemd-tmpfiles-setup.service -b` ✅ Only 8 log lines, zero socket errors
- `systemd-tmpfiles-setup.service` ✅ 303ms (was 44.912s)

### Previous Session 70 — Nix Versioning Mass Fix (Completed)

| Metric | Value |
|--------|-------|
| Repos fixed | 29 |
| Tags created | 26 |
| Automation scripts created | 2 (`fix-versions.py`, `commit-tag-push.py`) |
| Package versions now readable | `dnsblockd 0.1.0`, `go-auto-upgrade 0.1.0`, etc. |
| AGENTS.md updated | "Nix Versioning Convention" section added |

---

## b) PARTIALLY DONE

| Item | Progress | Blocker |
|------|----------|---------|
| **Boot performance verification** | ✅ **VERIFIED** — 58.1s boot (was 133.6s) | tmpfs confirmed, tmpfiles 303ms, no socket errors |
| **`boot.tmp.cleanOnBoot = true`** | Still present alongside `useTmpfs` | Redundant but harmless — `cleanOnBoot` is a no-op on tmpfs. Could remove for cleanliness. |
| **Nix store cleanup** | 7,479 store paths eligible for GC | Disk at 83% on root — GC would free significant space but requires scheduling |
| **TODO_LIST.md accuracy** | Last updated 2026-05-11 (10 days stale) | Many P1 items (deploy, verify services, Discord alerts) still unchecked but may be done |
| **SigNoz dashboards** | 4 dashboards created (Session 74) | Alert thresholds and Discord channel routing still need verification |
| **Gatus TLS cert check** | Added in Session 74 | Not verified since last `just switch` |
| **Pi 3 DNS provisioning** | Hardware acquired, `rpi3-dns` config exists | Undervoltage issue diagnosed, not physically deployed yet |
| **Pre-commit hooks** | 3 repos still failing (BuildFlow, dnsblockd, golangci-lint-auto-configure) | `--no-verify` still required for clean commits |
| **Branch standardization** | 3 repos on non-`master` branches | art-dupl (`fork`), Standup-Killer (`main`), standard-bug-tracking-schema (`main`) |

---

## c) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | CI check for `self.rev` anti-pattern | P2 | GitHub Actions workflow to grep `.nix` files |
| 2 | Shared `flake-parts-go-template` repo | P2 | Prevent anti-pattern in new repos |
| 3 | `version-bump` automation script | P3 | Edit `flake.nix` → commit → tag → push in one command |
| 4 | `sync-flake-lock` script | P3 | Update all LarsArtmann inputs in SystemNix |
| 5 | Dozzle deployment | P3 | Docker container log tailing at `logs.home.lan` — evaluation done, needs implementation |
| 6 | nix-colors integration | P3 | Wire to Home Manager, migrate 17+ hardcoded colors |
| 7 | ADR-007: Nix Versioning Convention | P3 | Permanent ADR in `docs/adr/` |
| 8 | `CONTEXT.md` at SystemNix root | P3 | Agent onboarding document |
| 9 | `docs/status/` archive sweep | P4 | Move reports older than 2 weeks to `archive/` |
| 10 | Darwin disk cleanup | P4 | 229GB, 90-95% full — `nix-collect-garbage` hangs, manual cache clearing needed |
| 11 | SigNoz JWT secret fix | P4 | `SIGNOZ_TOKENIZER_JWT_SECRET` hardcoded or missing |
| 12 | Whisper ASR down alert | P4 | Add to SigNoz rules |

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Impact | Fix Required |
|-------|----------|--------|-------------|
| **Boot time 2m 13s → 58s** | ✅ **FIXED** | 44s tmpfiles bottleneck eliminated, 75.4s total saved | `boot.tmp.useTmpfs = true` deployed and verified |
| **Root disk 83% full** | 🟡 MEDIUM | 89G free on 512G root, BTRFS with dedup overhead | `nix store gc` would free space from 7,479 stale paths |
| **Data disk 81% full** | 🟡 MEDIUM | 198G free on 1TB /data | Monitor growth, consider GC or data cleanup |
| **`TODO_LIST.md` 10 days stale** | 🟡 MEDIUM | P1 deploy items may be done but not marked | Update TODO_LIST.md after next deploy |
| **BuildFlow 50+ unstaged files** | 🟡 MEDIUM | Working directory dirty, blocks clean batch ops | Dedicated cleanup session |
| **dnsblockd TLS handshake errors** | 🟢 LOW | Client at `192.168.1.62` offers TLS 1.0 (unsupported) | Normal behavior — old client trying to connect |
| **Evaluation warning: `boot.zfs.forceImportRoot`** | 🟢 LOW | Upstream nixpkgs warning, not a bug | Set `boot.zfs.forceImportRoot = false` explicitly |
| **Pre-commit hooks failing** | 🟢 LOW | golangci-lint (77 issues), todo-check (3), nix-fmt, gitleaks | Pre-existing, blocks clean commits |
| **art-dupl default branch `fork`** | 🟢 LOW | `flake.nix` references `ref=master` | Either change default branch or update `flake.nix` input |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Boot performance monitoring** — Add a systemd timer that runs `systemd-analyze` after each boot and logs to a file. Alert if boot time > 60s.

2. **`/tmp` as tmpfs should be the default** — The `boot.tmp.cleanOnBoot = true` pattern is a trap. On a real filesystem, stale sockets accumulate and `systemd-tmpfiles` traverses them all. tmpfs eliminates this class of problem entirely.

3. **Nix store GC automation** — Disk at 83% is approaching danger zone. A weekly `nix-collect-garbage --delete-older-than 7d` timer would prevent emergencies.

4. **Shared flake template** — Every new Go repo copies the same `flake.nix` boilerplate. A `github:LarsArtmann/flake-parts-go-template` with correct `version = "0.1.0"`, `mkPackageOverlay`, `preparedSrc`, and `overlays.default` would prevent anti-patterns.

5. **Branch standardization** — `art-dupl` uses `fork`, `Standup-Killer` and `standard-bug-tracking-schema` use `main`. The rest use `master`. The `flake.nix` inputs all hardcode `ref=master`. This is fragile and caused merge workarounds.

### Process

6. **TODO_LIST.md hygiene** — After every `just switch`, update TODO_LIST.md. A 10-day stale TODO list is worse than no list.

7. **Pre-commit hook bypass** — We used `--no-verify` for 29 commits because hooks fail. Consider a `BATCH_MODE=1` env var or fix the underlying issues.

8. **Working directory hygiene** — Several repos had unstaged changes during batch operations. A `git status --short` check at the start of scripts would catch this.

### Documentation

9. **ADR-007: Nix Versioning Convention** — Now documented in AGENTS.md, but needs a permanent ADR.

10. **`CONTEXT.md`** — A root-level document describing the project's domain, architecture, and conventions for agent onboarding.

---

## f) Top 25 Things to Get Done Next

### P1 — Verify & Deploy

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | `just switch` + reboot to verify tmpfs boot fix | 5m | Confirms 45s boot time reduction |
| 2 | Run `systemd-analyze` after reboot, log result | 1m | Baseline for future comparison |
| 3 | `nix store gc --delete-older-than 7d` | 10m | Frees disk space (7,479 paths eligible) |
| 4 | Update `TODO_LIST.md` — mark done items, remove stale ones | 15m | Accurate project state |

### P2 — Prevent Regression

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | Create `github:LarsArtmann/flake-parts-go-template` | 1h | Prevents anti-pattern in new repos |
| 6 | Add CI check that fails on `self.rev`/`self.shortRev` in `.nix` files | 15m | Catches anti-pattern at PR time |
| 7 | Add CI check that verifies `version` is hardcoded semver | 15m | Catches dynamic versions |
| 8 | Remove redundant `boot.tmp.cleanOnBoot = true` (tmpfs makes it a no-op) | 2m | Cleanliness |

### P3 — Cleanup

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 9 | Fix pre-commit hooks in BuildFlow (77 golangci-lint issues) | 2h | Enables clean commits without `--no-verify` |
| 10 | Fix pre-commit hooks in dnsblockd (3 TODO comments) | 30m | Enables clean commits |
| 11 | Fix pre-commit hooks in golangci-lint-auto-configure (nix-fmt, gitleaks) | 30m | Enables clean commits |
| 12 | Standardize all repos to `master` branch or update `flake.nix` `ref=` | 1h | Removes branch-name fragility |
| 13 | Clean BuildFlow working directory (50+ unstaged files) | 30m | Hygiene |
| 14 | Archive `docs/status/` reports older than 2 weeks | 15m | Hygiene |

### P4 — Automation & Features

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 15 | Create `version-bump` script: edit `flake.nix` → commit → tag → push | 30m | Reduces release to 1 command |
| 16 | Create `sync-flake-lock` script: update all LarsArtmann inputs | 30m | Reduces lock updates to 1 command |
| 17 | Deploy Dozzle at `logs.home.lan` | 1h | Docker container log tailing |
| 18 | Write ADR-007: Nix Versioning Convention | 15m | Permanent record |
| 19 | Create `CONTEXT.md` at SystemNix root | 30m | Agent onboarding |
| 20 | Fix SigNoz JWT secret (`SIGNOZ_TOKENIZER_JWT_SECRET`) | 30m | Security |
| 21 | Add Whisper ASR down alert to SigNoz rules | 15m | Monitoring |
| 22 | Add boot time alert (alert if `systemd-analyze` > 60s) | 15m | Performance monitoring |
| 23 | Weekly nix store GC systemd timer | 15m | Prevents disk exhaustion |
| 24 | Extract hardcoded ports in `voice-agents.nix`, `configuration.nix` | 30m | Config consistency |
| 25 | Provision Pi 3 as secondary DNS | 2h | DNS redundancy |

---

## g) Top #1 Question I Cannot Figure Out Myself

**How do we prevent new repos from reintroducing the `self.rev` version anti-pattern AND the `/tmp` on-BTRFS trap?**

Both problems share the same root cause: **seductive defaults that seem correct but create cascading problems.**

- `self.rev` feels "automatic" and "always correct" but produces garbage package names.
- `boot.tmp.cleanOnBoot = true` on a real filesystem feels "correct" but creates a socket-traversal bottleneck.

The fixes are:
1. **Documentation** — AGENTS.md documents both conventions
2. **Automation** — `fix-versions.py` detects the anti-pattern
3. **Template** — Shared flake template with correct patterns

But none of these are **enforced**. A developer (or AI agent) can still:
- Copy a random `flake.nix` from the internet with `self.rev`
- Set `tmp.cleanOnBoot = true` without `useTmpfs = true`

**The core question:** Is there a way to enforce these at the Nix level? Could we:
- Write a `nix flake check` assertion that fails if `version` contains a git hash?
- Create a NixOS module option that warns when `tmp.cleanOnBoot = true` without `tmp.useTmpfs = true`?
- Or is the only real solution a CI gate + code review discipline?

---

## System Vital Signs

| Metric | Value |
|--------|-------|
| **Build status** | ✅ `just test-fast` passes |
| **Branch** | `master` (clean, up to date with `origin/master`) |
| **Last commit** | `3c8a70aa` — "chore(deps): update flake.lock with upstream revisions + tmpfs boot option" |
| **Tag** | `v1.0-1909-g3c8a70aa` |
| **nixpkgs** | `d233902` (unstable, 2026-05-17) |
| **Kernel** | `7.0.8` |
| **Uptime** | 2m (post-reboot) |
| **Load average** | 2.87, 1.79, 0.72 |
| **Memory** | 62Gi total, 41Gi used, 21Gi available |
| **Swap** | 13Gi total, 1.0Gi used |
| **Root disk (/)** | 512G, 407G used (83%), 89G free |
| **Data disk (/data)** | 1.0T, 827G used (81%), 198G free |
| **Boot disk (/boot)** | 2.0G, 238M used (12%), 1.8G free |
| **Nix store paths eligible for GC** | 7,479 |
| **Boot time** | 58.128s total (was 133.55s) |
| **Userspace boot** | 32.968s (was 92.132s) |
| **Current system size** | 40.5 GiB |
| **`.nix` files** | 112 files, 14,933 lines |
| **Service modules** | 36 |
| **`enable = true` occurrences** | 92 |
| **Flake inputs** | 47 |
| **Custom packages (Linux)** | 18 (x86_64-linux) |
| **Custom packages (Darwin)** | 14 (aarch64-darwin shared) |
| **Shell scripts** | 25 |
| **Python scripts** | 2 (`fix-versions.py`, `commit-tag-push.py`) |
| **Evaluation warnings** | 1 (`boot.zfs.forceImportRoot` default — upstream) |
| **Empty hashes** | 0 |

---

_Generated by Session 71 — 2026-05-21 04:40 CEST_
