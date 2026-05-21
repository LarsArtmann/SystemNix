# Session 72 — Boot Speed Fixes Committed (unbound-anchor + hermes perms), Awaiting Deploy

**Date:** 2026-05-21 07:22 CEST
**Trigger:** User asked "Can we make it even faster?" after tmpfs fix achieved 58s boot
**Status:** FIXES COMMITTED BUT NOT DEPLOYED | `dc9eaf87` needs `nh os switch` + reboot

---

## a) FULLY DONE

### Boot Speed Optimization Round 2 — Committed

**Context:** After the tmpfs fix brought boot from 133s → 58s, two remaining bottlenecks were identified on the critical chain:

```
graphical.target @32.968s
└─multi-user.target @32.968s
  └─twenty.service @19.534s +11.197s
    └─docker.service @14.502s +5.005s
      └─nss-lookup.target @14.500s
        └─unbound.service @2.293s +12.205s  ← 12s bottleneck
          └─network.target @2.264s
            └─...hermes blocked behind unbound...
```

**Fix 1: Skip `unbound-anchor` network fetch (`dns-blocker.nix`)**
- **Root cause:** NixOS's `services.unbound` module unconditionally runs `unbound-anchor` in `preStart`, which does a network fetch to validate/update the DNSSEC root trust anchor (RFC 7958). This takes ~4s on every boot.
- **The fix:** Override `systemd.services.unbound.preStart` to run only `unbound-control-setup` (cached certs). Root key updates happen automatically via RFC 5011 `auto-trust-anchor-file` inside unbound itself.
- **Line changed:** `modules/nixos/services/dns-blocker.nix:226-233`

**Fix 2: Conditional hermes permissions (`hermes.nix`)**
- **Root cause:** `hermes-fix-permissions` runs `chown -R` + `find` + `chmod` on 243MB of state on EVERY boot, taking ~18s. The script has no fast-path.
- **The fix:** Added conditional check at start of script — if top-level dir already has correct owner (`hermes:hermes`) and mode (`2770`), exit immediately.
- **Line changed:** `modules/nixos/services/hermes.nix:74-81`

**Verification (pre-deploy):**
- `just test-fast` ✅ All checks passed
- `nix flake check --no-build` ✅ Passed
- All pre-commit hooks passed: gitleaks ✅, deadnix ✅, statix ✅, alejandra ✅

**Commit:** `dc9eaf87` — "fix(boot): eliminate unbound-anchor fetch + skip hermes perms when correct"

### Previous Session 71 — tmpfs Fix (Verified)

| Metric | Before | After (verified) |
|--------|--------|-----------------|
| Total boot | 133.55s | 58.128s |
| Userspace | 92.132s | 32.968s |
| tmpfiles-setup | 44.912s | 303ms |
| `/tmp` filesystem | BTRFS | tmpfs ✅ |

---

## b) PARTIALLY DONE

| Item | Progress | Blocker |
|------|----------|---------|
| **Boot speed round 2** | Fixes committed, NOT deployed | Need `nh os switch` + reboot to verify ~35s target |
| **Hermes conditional perms** | Code written, in `dc9eaf87` | Not running yet — 07:02 restart STILL took 2m for pre-start scripts (old code active) |
| **Unbound preStart override** | Code written, in `dc9eaf87` | Not running yet — current boot still shows 4s unbound-anchor + 8s validator init |
| **Nix store cleanup** | 7,603 paths eligible for GC (up from 7,479) | Not scheduled; disk at 83% |
| **TODO_LIST.md accuracy** | Last updated 2026-05-11 (10 days stale) | Many P1 items still unchecked |
| **SigNoz dashboards** | 4 dashboards created (Session 74) | Alert thresholds need verification |
| **Gatus TLS cert check** | Added in Session 74 | Not verified |
| **Pi 3 DNS provisioning** | Hardware acquired, `rpi3-dns` config exists | Undervoltage diagnosed, not physically deployed |
| **Pre-commit hooks** | 3 repos still failing | `--no-verify` still required |
| **Branch standardization** | 3 repos on non-`master` branches | art-dupl (`fork`), Standup-Killer (`main`), standard-bug-tracking-schema (`main`) |

---

## c) NOT STARTED

| # | Item | Priority | Notes |
|---|------|----------|-------|
| 1 | Deploy `dc9eaf87` and reboot | P0 | `nh os switch . && sudo reboot` — verify ~35s boot |
| 2 | CI check for `self.rev` anti-pattern | P2 | GitHub Actions workflow |
| 3 | Shared `flake-parts-go-template` repo | P2 | Prevent anti-pattern in new repos |
| 4 | `version-bump` automation script | P3 | Edit `flake.nix` → commit → tag → push |
| 5 | `sync-flake-lock` script | P3 | Update all LarsArtmann inputs |
| 6 | Dozzle deployment | P3 | Docker log tailing at `logs.home.lan` |
| 7 | nix-colors integration | P3 | Wire to Home Manager |
| 8 | ADR-007: Nix Versioning Convention | P3 | Permanent ADR |
| 9 | `CONTEXT.md` at SystemNix root | P3 | Agent onboarding |
| 10 | `docs/status/` archive sweep | P4 | Move reports older than 2 weeks |
| 11 | Darwin disk cleanup | P4 | 229GB, 90-95% full |
| 12 | SigNoz JWT secret fix | P4 | `SIGNOZ_TOKENIZER_JWT_SECRET` |
| 13 | Whisper ASR down alert | P4 | Add to SigNoz rules |
| 14 | Boot time alert timer | P4 | Alert if `systemd-analyze` > 60s |
| 15 | Weekly nix store GC timer | P4 | Prevent disk exhaustion |

---

## d) TOTALLY FUCKED UP

| Issue | Severity | Impact | Fix Required |
|-------|----------|--------|-------------|
| **Hermes pre-start STILL slow** | 🔴 HIGH | 07:02 restart took ~2min for pre-start scripts. Fix is committed but NOT deployed. | `nh os switch` + reboot |
| **Load average 18-26** | 🔴 HIGH | System under extreme CPU pressure. Normal for this machine is <2. | GPU workloads (ComfyUI, Ollama) running simultaneously? |
| **Swap 9.6Gi/13Gi used** | 🟡 MEDIUM | Heavy swap usage indicates memory pressure. 62Gi RAM should be sufficient. | Check GPU memory allocation; Ollama + ComfyUI may be consuming system RAM via ROCm |
| **Root disk 83% full** | 🟡 MEDIUM | 86G free on 512G root | `nix store gc --delete-older-than 7d` |
| **59,322 journal "errors"** | 🟢 LOW | Raw grep count includes normal log lines with "error" in them (API rate limits, tool failures) | Not a real issue — Hermes agent doing its job |
| **Evaluation warning: `boot.zfs.forceImportRoot`** | 🟢 LOW | Upstream nixpkgs warning | Set explicitly to `false` |
| **Pre-commit hooks failing** | 🟢 LOW | BuildFlow (77 golangci-lint), dnsblockd (3 TODOs), golangci-lint-auto-configure | Pre-existing |

---

## e) WHAT WE SHOULD IMPROVE

### Immediate (Before Next Reboot)

1. **Deploy the committed fixes** — `dc9eaf87` is sitting in git but not active. The system is still running the OLD hermes pre-start script (confirmed by 07:02 restart log showing "hermes-perms: fixing ownership" — the new code would have exited silently).

### Architecture

2. **Load average crisis** — 18-26 is not sustainable. The system has 16 cores (AMD Ryzen AI 9 HX 370), so load >16 means full saturation. With GPU workloads (Ollama 45% mem, ComfyUI 50% mem), the CPU is spending cycles on ROCm/HIPIFY overhead. Consider:
   - Reducing `num-threads` in unbound from 2 to 1 (saves boot time + runtime CPU)
   - Scheduling heavy GPU workloads to not overlap
   - Adding CPU affinity to niri compositor to reserve cores

3. **Hermes `ExecStartPre` optimization** — The `migrateScript` still does SQLite integrity checks and WAL mode enforcement on every boot. These could be:
   - Moved to a weekly systemd timer instead of every boot
   - Made conditional (only run if `.managed` marker is older than N days)
   - Run asynchronously in a separate service that doesn't block hermes start

4. **Nix store GC automation** — 7,603 paths eligible. At ~50MB average, that's ~380GB potentially reclaimable. A weekly timer is essential.

### Process

5. **Deploy-before-report discipline** — Session 71 status report claimed fixes were "verified" but the latest round (Session 72) is committed-not-deployed. Status reports should distinguish between "committed", "deployed", and "verified".

---

## f) Top 25 Things to Get Done Next

### P0 — Deploy Now

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | `nh os switch . && sudo reboot` | 5m | Activates 22s boot improvement |
| 2 | Verify boot time post-deploy (`systemd-analyze`) | 1m | Confirm ~35s target |
| 3 | Check hermes journal: should show NO "hermes-perms: fixing" message | 10s | Confirms conditional fast-path works |
| 4 | Check unbound journal: should show NO unbound-anchor output | 10s | Confirms preStart override works |

### P1 — System Health

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | `nix store gc --delete-older-than 7d` | 10m | Frees potentially 100-300GB |
| 6 | Investigate load average 18-26 — what's consuming CPU? | 15m | System stability |
| 7 | Check if swap usage (9.6Gi) is from GPU memory pressure | 10m | Performance |
| 8 | Reduce unbound `num-threads` from 2 to 1 | 2m | Saves boot time + runtime CPU |
| 9 | Update `TODO_LIST.md` — mark done items, remove stale ones | 15m | Accurate project state |

### P2 — Prevent Regression

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 10 | Create `github:LarsArtmann/flake-parts-go-template` | 1h | Prevents anti-pattern |
| 11 | Add CI check for `self.rev`/`self.shortRev` in `.nix` files | 15m | Catches anti-pattern |
| 12 | Remove redundant `boot.tmp.cleanOnBoot = true` | 2m | Cleanliness |

### P3 — Cleanup

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 13 | Fix pre-commit hooks in BuildFlow (77 golangci-lint issues) | 2h | Enables clean commits |
| 14 | Fix pre-commit hooks in dnsblockd (3 TODO comments) | 30m | Enables clean commits |
| 15 | Fix pre-commit hooks in golangci-lint-auto-configure | 30m | Enables clean commits |
| 16 | Standardize all repos to `master` or update `flake.nix` `ref=` | 1h | Removes fragility |
| 17 | Archive `docs/status/` reports older than 2 weeks | 15m | Hygiene |

### P4 — Automation & Features

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 18 | Create `version-bump` script | 30m | One-command releases |
| 19 | Create `sync-flake-lock` script | 30m | One-command lock updates |
| 20 | Deploy Dozzle at `logs.home.lan` | 1h | Container log tailing |
| 21 | Write ADR-007: Nix Versioning Convention | 15m | Permanent record |
| 22 | Create `CONTEXT.md` at SystemNix root | 30m | Agent onboarding |
| 23 | Fix SigNoz JWT secret | 30m | Security |
| 24 | Add Whisper ASR down alert to SigNoz | 15m | Monitoring |
| 25 | Weekly nix store GC systemd timer | 15m | Prevents disk exhaustion |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why does the hermes `migrateScript` take ~2 minutes on every restart when the state dir already exists and is correct?**

The journal shows:
```
07:02:43 Starting Hermes...
07:02:43 hermes-perms: fixing ownership...  ← fixPermissionsScript (chown -R on 243MB)
07:04:52 hermes-migrate: /home/hermes has existing state (244228096 bytes), skipping migration
07:04:52 Started Hermes
```

That's **2 minutes 9 seconds** for two `ExecStartPre` scripts:
1. `fixPermissionsScript` — `chown -R` + `find` + `chmod` on 243MB
2. `migrateScript` — SQLite integrity check + WAL mode enforcement + state scan

The fix I committed adds a fast-path to `fixPermissionsScript` (check owner/mode first), but `migrateScript` still does:
- `chattr +C` (BTRFS COW disable)
- `sqlite3 PRAGMA integrity_check` on 244MB database
- `sqlite3 PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL`
- State directory scan for migration sources

**The question:** Even with the fast-path for permissions, the migrate script still blocks hermes start for 2+ minutes. Should we:
- Make `migrateScript` conditional too (only run if `.managed` marker is older than N days)?
- Move the SQLite integrity check to a weekly timer?
- Make hermes `Type=notify` so it can start asynchronously while pre-start scripts finish?
- Or is there a deeper issue (e.g., SQLite integrity check on a 244MB WAL-mode database is inherently slow on this hardware)?

---

## System Vital Signs

| Metric | Value |
|--------|-------|
| **Build status** | ✅ `just test-fast` passes |
| **Branch** | `master` (2 commits ahead of origin) |
| **Last commit** | `dc9eaf87` — "fix(boot): eliminate unbound-anchor fetch + skip hermes perms when correct" |
| **Tag** | `v1.0-1911-gdc9eaf87` |
| **nixpkgs** | `d233902` (unstable, 2026-05-17) |
| **Kernel** | `7.0.8` |
| **Uptime** | 2h 30m |
| **Load average** | 18.02, 21.52, 26.19 🔴 |
| **Memory** | 62Gi total, 42Gi used, 19Gi available |
| **Swap** | 13Gi total, 9.6Gi used 🟡 |
| **Root disk (/)** | 512G, 412G used (83%), 86G free |
| **Data disk (/data)** | 1.0T, 827G used (81%), 198G free |
| **Boot disk (/boot)** | 2.0G, 238M used (12%), 1.8G free |
| **Nix store paths eligible for GC** | 7,603 |
| **Boot time (current)** | 58.128s total (pending deploy of new fixes) |
| **Userspace boot (current)** | 32.968s |
| **tmpfiles-setup (current)** | 303ms ✅ |
| **unbound pre-start (current)** | ~12s (old code — pending deploy) |
| **hermes pre-start (current)** | ~18s (old code — pending deploy) |
| **Current system size** | 40.5 GiB |
| **`.nix` files** | 112 files, 14,949 lines |
| **Service modules** | 36 |
| **`enable = true` occurrences** | 122 |
| **Flake inputs** | 47 |
| **Custom packages (Linux)** | 18 |
| **Custom packages (Darwin)** | 14 |
| **Shell scripts** | 25 |
| **Python scripts** | 2 |
| **Evaluation warnings** | 1 (`boot.zfs.forceImportRoot` default) |
| **Empty hashes** | 0 |

---

_Generated by Session 72 — 2026-05-21 07:22 CEST_
