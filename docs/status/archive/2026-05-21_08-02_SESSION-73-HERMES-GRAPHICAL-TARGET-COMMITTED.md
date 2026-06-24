# Session 73 — Hermes moved to graphical.target, Boot Fixes Still Awaiting Deploy

**Date:** 2026-05-21 08:02 CEST
**Trigger:** User asked about `graphical-session.target` vs `graphical.target`, then moved hermes and discovered more services should follow
**Status:** 5 COMMITS AHEAD OF ORIGIN | Boot fixes committed but NOT deployed | Hermes graphical.target change committed but NOT deployed

---

## a) FULLY DONE

### Hermes moved from multi-user.target to graphical.target

**Change:** `modules/nixos/services/hermes.nix:195`
- `wantedBy = ["multi-user.target"];` → `wantedBy = ["graphical.target"];`

**Rationale:** Hermes is a user-facing web service (Discord bot, messaging gateway, cron scheduler). It should start alongside display-manager.service at graphical.target, not block multi-user.target which other infrastructure services need.

**Commit:** `5328769f` — "fix(hermes): move from multi-user.target to graphical.target"

**Verification:**
- `just test-fast` ✅ All checks passed
- All pre-commit hooks passed: gitleaks, deadnix, statix, alejandra ✅

### Previous Session 72 — Boot Speed Fixes (Committed)

| Fix | File | Status |
|-----|------|--------|
| Skip unbound-anchor network fetch | `dns-blocker.nix` | Committed, NOT deployed |
| Conditional hermes fixPermissionsScript | `hermes.nix` | Committed, NOT deployed |

### Previous Session 71 — tmpfs Boot Fix (Deployed + Verified)

| Metric | Before | After |
|--------|--------|-------|
| Total boot | 133.55s | 58.128s ✅ |
| tmpfiles-setup | 44.912s | 303ms ✅ |
| `/tmp` filesystem | BTRFS (stale sockets) | tmpfs ✅ |

---

## b) PARTIALLY DONE

| Item | Progress | Blocker |
|------|----------|---------|
| **Boot speed round 2 deploy** | 2 fixes committed in `dc9eaf87` | Need `nh os switch` + reboot |
| **Hermes graphical.target** | Committed in `5328769f` | Need `nh os switch` + reboot |
| **Session 72 status report** | Written and committed `a77e4004` | — |
| **Session 73 status report** | Written and committed `9d4bb569` | — |
| **Other services audit** | 8 custom modules on multi-user.target identified | Need decision: which to move |
| **Nix store cleanup** | 7,639 paths eligible for GC | Not scheduled |
| **TODO_LIST.md** | 10+ days stale | Needs update post-deploy |
| **System load** | Improved: 10.78/5.67/8.13 (was 18-26) | Still high for 16-core system |
| **Swap usage** | 8.8Gi/13Gi | Still heavy — GPU memory pressure |

---

## c) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | Deploy all 5 commits and reboot | P0 | `nh os switch . && sudo reboot` |
| 2 | Audit remaining services on multi-user.target | P1 | 8 custom modules + upstream modules |
| 3 | Create custom `apps.target` for non-essential services | P1 | Alternative to mass graphical.target moves |
| 4 | CI check for `self.rev` anti-pattern | P2 | GitHub Actions |
| 5 | Shared `flake-parts-go-template` repo | P2 | Prevent anti-pattern |
| 6 | `version-bump` automation script | P3 | One-command releases |
| 7 | `sync-flake-lock` script | P3 | One-command lock updates |
| 8 | Dozzle deployment | P3 | Docker log tailing |
| 9 | nix-colors integration | P3 | Wire to Home Manager |
| 10 | ADR-007: Nix Versioning Convention | P3 | Permanent ADR |
| 11 | `CONTEXT.md` at SystemNix root | P3 | Agent onboarding |
| 12 | `docs/status/` archive sweep | P4 | Move old reports |
| 13 | Darwin disk cleanup | P4 | 229GB, 90-95% full |
| 14 | SigNoz JWT secret fix | P4 | `SIGNOZ_TOKENIZER_JWT_SECRET` |
| 15 | Whisper ASR down alert | P4 | Add to SigNoz rules |
| 16 | Boot time alert timer | P4 | Alert if `systemd-analyze` > 60s |
| 17 | Weekly nix store GC timer | P4 | Prevents disk exhaustion |
| 18 | Hermes migrateScript optimization | P4 | Move SQLite integrity check to weekly timer? |
| 19 | Unbound `num-threads` reduction | P4 | 2→1 saves boot + runtime CPU |
| 20 | GPU workload CPU affinity | P4 | Reserve cores for niri compositor |

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Impact | Fix Required |
|-------|----------|--------|-------------|
| **5 commits ahead, none deployed** | 🔴 HIGH | All boot fixes and hermes change sitting in git, not active | `nh os switch` + reboot |
| **System load 10.78** | 🟡 MEDIUM | 16-core system, load >10 = 62% saturation | GPU workload scheduling |
| **Swap 8.8Gi/13Gi** | 🟡 MEDIUM | Memory pressure from ROCm/HIPIFY | Review GPU mem limits |
| **Root disk 83%** | 🟡 MEDIUM | 89G free on 512G | `nix store gc` |
| **Hermes pre-start still slow** | 🟡 MEDIUM | 2m+ on restart (old code active) | Deploy `dc9eaf87` |
| **Evaluation warning: boot.zfs.forceImportRoot** | 🟢 LOW | Upstream nixpkgs warning | Set explicitly to `false` |
| **Pre-commit hooks failing** | 🟢 LOW | BuildFlow, dnsblockd, golangci-lint-auto-configure | Pre-existing |
| **art-dupl default branch `fork`** | 🟢 LOW | `flake.nix` references `ref=master` | Standardize branches |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Service startup target audit** — 8 custom modules on `multi-user.target`. Most should move to `graphical.target` or a custom `apps.target`:
   - `dnsblockd` ✅ (web service)
   - `homepage-dashboard` ✅ (web UI)
   - `signoz` ✅ (observability)
   - `comfyui` ✅ (AI web UI)
   - Docker containers via `mkDockerServiceFactory` ✅ (all containers)
   - `dual-wan` ❌ (network infra — keep on multi-user)

2. **Custom `apps.target`** — Instead of moving everything to `graphical.target`, create:
   ```nix
   systemd.targets.apps = {
     description = "User-facing applications";
     after = ["multi-user.target" "network-online.target"];
     wantedBy = ["graphical.target"];
   };
   ```
   Then services use `wantedBy = ["apps.target"];`. This is cleaner than overloading `graphical.target`.

3. **Hermes migrateScript async** — The SQLite integrity check on 244MB blocks hermes for 2+ minutes. Should be:
   - A separate weekly timer service
   - Or conditional (only run if `.managed` marker older than 7 days)

4. **Nix store GC automation** — 7,639 paths = potentially 200-400GB. Weekly timer essential.

### Process

5. **Deploy-before-report discipline** — Status reports should clearly distinguish: committed → deployed → verified.

---

## f) Top 25 Things to Get Done Next

### P0 — Deploy Now

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | `nh os switch . && sudo reboot` | 5m | Activates all 5 commits |
| 2 | Verify boot time post-deploy | 1m | Confirm improvements |
| 3 | Check hermes journal for fast-path | 10s | Confirms conditional perms work |
| 4 | Check unbound journal for no anchor fetch | 10s | Confirms preStart override works |

### P1 — Service Target Audit

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | Audit all 8 custom modules on multi-user.target | 15m | Identify what to move |
| 6 | Create `apps.target` systemd target | 10m | Clean separation |
| 7 | Move dnsblockd, homepage, signoz, comfyui to apps.target | 10m | Faster multi-user |
| 8 | Move docker containers (mkDockerServiceFactory) to apps.target | 10m | Faster multi-user |
| 9 | Keep dual-wan, unbound on multi-user.target | 0m | Network infra |

### P2 — System Health

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10 | `nix store gc --delete-older-than 7d` | 10m | Frees 200-400GB |
| 11 | Reduce unbound `num-threads` from 2 to 1 | 2m | Saves boot + runtime CPU |
| 12 | Make hermes migrateScript conditional/weekly | 20m | Saves 2m on restart |
| 13 | Update `TODO_LIST.md` | 15m | Accurate state |

### P3 — Prevent Regression

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 14 | Create `flake-parts-go-template` | 1h | Prevents anti-pattern |
| 15 | Add CI check for `self.rev`/`self.shortRev` | 15m | Catches anti-pattern |
| 16 | Remove redundant `boot.tmp.cleanOnBoot = true` | 2m | Cleanliness |

### P4 — Cleanup & Features

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 17 | Fix pre-commit hooks in BuildFlow | 2h | Clean commits |
| 18 | Fix pre-commit hooks in dnsblockd | 30m | Clean commits |
| 19 | Fix pre-commit hooks in golangci-lint-auto-configure | 30m | Clean commits |
| 20 | Standardize repo branches | 1h | Removes fragility |
| 21 | Archive old status reports | 15m | Hygiene |
| 22 | Create `version-bump` script | 30m | One-command releases |
| 23 | Create `sync-flake-lock` script | 30m | One-command lock updates |
| 24 | Deploy Dozzle at `logs.home.lan` | 1h | Container log tailing |
| 25 | Write ADR-007: Nix Versioning Convention | 15m | Permanent record |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why does `nh os switch` crash with `Failed to resolve base output path to store path` when run inside a nix-shell?**

This happened in Session 71:
```
Error:
   0: Failed to resolve base output path to store path
   1: No such file or directory (os error 2)
```

`nh` writes build output to a temp dir (`/tmp/nix-shell.*/nh-os*/result`), then tries to read it back. But:
- The temp dir gets cleaned up by the nix-shell wrapper
- Or `nh` loses the reference before it can resolve the symlink

The workaround is `sudo /nix/store/.../bin/switch-to-configuration switch`, but that's manual and error-prone.

**Is there a way to make `nh os switch` reliable inside a nix-shell?** Or should we:
- Exit the nix-shell before running `nh`?
- Use `nixos-rebuild switch` directly?
- Set a persistent `--out-link` path?
- Or is this a bug in `nh` that should be reported upstream?

---

## System Vital Signs

| Metric | Value |
|--------|-------|
| **Build status** | ✅ `just test-fast` passes |
| **Branch** | `master` (5 commits ahead of origin) |
| **Commits ahead** | `9d4bb569`, `5328769f`, `a77e4004`, `dc9eaf87`, `50d9e43b` |
| **nixpkgs** | `d233902` (unstable, 2026-05-17) |
| **Kernel** | `7.0.8` |
| **Uptime** | 3h 9m |
| **Load average** | 10.78, 5.67, 8.13 🟡 |
| **Memory** | 62Gi total, 42Gi used, 19Gi available |
| **Swap** | 13Gi total, 8.8Gi used 🟡 |
| **Root disk (/)** | 512G, 408G used (83%), 89G free |
| **Data disk (/data)** | 1.0T, 827G used (81%), 198G free |
| **Boot disk (/boot)** | 2.0G, 238M used (12%), 1.8G free |
| **Nix store paths for GC** | 7,639 |
| **Boot time (current)** | 58.128s total (old code still active) |
| **Userspace boot** | 32.968s |
| **tmpfiles-setup** | 303ms ✅ |
| **unbound pre-start** | ~12s (old code — pending deploy) |
| **hermes pre-start** | ~2m (old code — pending deploy) |
| **`.nix` files** | 112 files |
| **Service modules** | 36 |
| **`enable = true` occurrences** | 122 |
| **Flake inputs** | 47 |
| **Evaluation warnings** | 1 (`boot.zfs.forceImportRoot` default) |
| **Empty hashes** | 0 |

---

_Generated by Session 73 — 2026-05-21 08:02 CEST_
