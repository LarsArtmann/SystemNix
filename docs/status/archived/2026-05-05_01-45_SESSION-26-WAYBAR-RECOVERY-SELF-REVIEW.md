# Session 26 — Waybar Recovery, Self-Review, Comprehensive Status

**Date:** 2026-05-05 01:45
**Host:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)
**Uptime:** 3h07m (booted May 4 22:38)
**Build:** `just test-fast` PASSING — clean working tree

---

## The Incident: Waybar Dead for 4 Days

### Timeline

| When         | What                                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------------ |
| Apr 30 04:49 | Commit `a83c0e0` introduced `PartOf=graphical-session.target` replacing `BindsTo=`                     |
| May 1 04:31  | System resource exhaustion (EAGAIN on fork) — all waybar custom modules failed                         |
| May 1 04:32  | Waybar disabled all modules, ran as empty bar                                                          |
| May 1 09:44  | Waybar stopped — never restarted (`Restart=on-failure` didn't cover clean exits)                       |
| May 4 22:38  | System rebooted. Niri started. Waybar **never came back** — `graphical-session.target` never activated |
| May 5 00:36  | Fix committed: `PartOf=` → `Wants=` in `niri-config.nix`                                               |
| May 5 01:45  | Waybar still not running — fix not yet deployed (`just switch` pending)                                |

### Root Cause

`PartOf=` is a **stop propagation** directive — it tells systemd "restart me when the target restarts" but does NOT pull in the target. Without `BindsTo=` or `Wants=`, nothing activated `graphical-session.target`, so waybar, cliphist, swayidle, and awww-daemon all stayed dead.

The original `BindsTo=graphical-session.target` was removed because it killed niri during `just switch` (when the target cycles). The correct replacement is `Wants=` — it pulls in the target (activating dependent services) without hard-binding niri to it. Niri's lifecycle is managed by `niri-shutdown.target` which `Conflicts=graphical-session.target` on session end.

### Fix

```
modules/nixos/services/niri-config.nix:40
  - ["PartOf=graphical-session.target"]
  + ["Wants=graphical-session.target"]
```

**Status: COMMITTED but NOT DEPLOYED.** Requires `just switch` + relogin/reboot.

---

## a) FULLY DONE

### Session 25–26 Completed Work

| #  | Item                                                                                                   | Commit               | Status    |
| -- | ------------------------------------------------------------------------------------------------------ | -------------------- | --------- |
| 1  | **Waybar root cause fix** — `PartOf` → `Wants`                                                         | `8ed4eae`            | Committed |
| 2  | **niri-config rationale comment** — documents BindsTo→Wants choice                                     | `7371bdb`            | Committed |
| 3  | **lib/systemd.nix mkDefault refactoring** — curried `{lib}:` pattern, `mkDefault'` preserves overrides | `173f605`            | Committed |
| 4  | **15 service modules migrated** to `{inherit lib;}` harden import                                      | session 24           | Committed |
| 5  | **file-and-image-renamer** restored shared `harden()` (was inlined)                                    | session 24           | Committed |
| 6  | **Unsloth removed** from caddy vhosts, homepage dashboard, DNS records                                 | session 24           | Committed |
| 7  | **AGENTS.md updated** — BindsTo→Wants rationale documented                                             | `8ed4eae`            | Committed |
| 8  | **signoz GPU metrics fix** — strip newlines from sysfs reads                                           | `b6ec972`            | Committed |
| 9  | **hermes-agent vendorHash update**                                                                     | `22f2181`            | Committed |
| 10 | **HaGeZi DNS blocklist hash updates**                                                                  | `d44004d`, `22f2181` | Committed |

### Existing Working Systems (pre-session)

- Niri compositor — running 3h07m stable
- Sops-nix secrets — age-encrypted, working
- Docker — Immich, SigNoz, ComfyUI containers operational
- DNS blocker — Unbound + dnsblockd, 2.5M+ domains blocked
- Taskwarrior — synced via TaskChampion, 6 windows saved every 60s
- Wallpaper self-healing — awww-daemon + PartOf propagation
- EMEET PIXY — webcam daemon with auto-activation
- Hermes — AI agent gateway running as system service
- Gitea — git hosting + GitHub mirror (token issue with sops)

---

## b) PARTIALLY DONE

| # | Item                          | What's Left                                                                                                                                                                         | Impact                 |
| - | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| 1 | **Waybar fix deployment**     | Fix committed but `just switch` not run. Waybar still dead on live system.                                                                                                          | HIGH — user has no bar |
| 2 | **Harden adoption audit**     | 18/31 service modules import `harden`, but 11 `// harden` calls are active code (not commented). Remaining 13 modules don't need harden (config-only, like ai-models, audio, sops). | MEDIUM — mostly done   |
| 3 | **Service defaults adoption** | Only 5/31 modules use `serviceDefaults`. Many services manually set `Restart=always` instead of using the shared helper.                                                            | LOW — works fine       |

---

## c) NOT STARTED

| # | Item                                                                          | Priority | Notes                             |
| - | ----------------------------------------------------------------------------- | -------- | --------------------------------- |
| 1 | **Deploy waybar fix** (`just switch` + relogin)                               | P0       | User must do this                 |
| 2 | **Root partition cleanup** — 89% full (56GB free)                             | P1       | `/nix/store` garbage collection   |
| 3 | **Gitea sops token** — `GITEA_TOKEN not set in sops secrets` error every sync | P1       | Scheduled tasks spamming journal  |
| 4 | **helium.desktop missing Icon** key — waybar warns on every tray scan         | P2       | Upstream helium package issue     |
| 5 | **DNS failover Pi 3** — hardware not provisioned                              | P3       | Module written, awaiting hardware |
| 6 | **Darwin (macOS) platform** — untested with recent niri changes               | P3       | No changes made to darwin         |

---

## d) TOTALLY FUCKED UP

| # | What                                 | How Bad                                                                     | Recovery                                                                       |
| - | ------------------------------------ | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 1 | **Waybar dead 4 days** (May 1–5)     | SEVERE — no system bar, no workspace indicator, no clock, no volume control | Fix committed (`8ed4eae`), pending deployment                                  |
| 2 | **PartOf mistake introduced Apr 30** | HIGH — broke graphical session activation for all future boots              | Fixed in `8ed4eae` with `Wants=`                                               |
| 3 | **May 1 EAGAIN fork storm**          | MEDIUM — waybar couldn't exec custom modules, cascading module disable      | Transient — resolved on reboot. `cgroup pids.current=2420/4194304` now healthy |

---

## e) WHAT WE SHOULD IMPROVE

### Architecture

1. **Health check for graphical-session.target** — Add a systemd watchdog or `just health` check that verifies `graphical-session.target` is active after boot. If not, alert via `notify-send`.
2. **Waybar restart policy** — Upstream `waybar.service` uses `Restart=on-failure`. Should patch to `Restart=always` so waybar recovers from clean exits (like the May 1 09:44 stop).
3. **Centralized service monitoring** — SigNoz monitors system services but not user services. Add journald receiver for user units.
4. **lib/ adoption tracking** — Create a linter or check that services with `serviceConfig` use `harden {}` from shared lib.

### Code Quality

5. **file-and-image-renamer uses user-level systemd** — All other custom services use system-level. Inconsistent. Consider migrating to system service like monitor365.
6. **monitor365 harden disabled** — `// harden {};` is active code but empty args means default hardening applied. Verify this works with `DISPLAY=:0` access pattern.
7. **hermes harden disabled** — `// harden { MemoryMax = "24G"; ProtectHome = false; ReadWritePaths = [cfg.stateDir]; }` is active code. Hermes needs 24G for ROCm. Verify this is intentional.

### Operational

8. **Root disk at 89%** — 56GB free on 512GB. Nix GC needed. Add automated `nix.gc` with `nix.settings.max-free`.
9. **Swappiness still 30** — Session 23 planned to reduce to 10, but current system shows 30. The `boot.nix` setting may not have been deployed.
10. **27 SSH sessions open** — `who | wc -l` shows 27 users. SSH sessions from macOS not cleaned up.

---

## f) Top 25 Things to Do Next (Sorted by Impact × Effort)

### P0 — Do Immediately

| # | Task                                                              | Effort | Impact   |
| - | ----------------------------------------------------------------- | ------ | -------- |
| 1 | **Deploy waybar fix** — `just switch` + relogin                   | 5min   | CRITICAL |
| 2 | **Verify waybar starts** — check `systemctl --user status waybar` | 1min   | CRITICAL |

### P1 — High Impact, Low Effort

| # | Task                                                                                               | Effort | Impact                |
| - | -------------------------------------------------------------------------------------------------- | ------ | --------------------- |
| 3 | **Patch waybar.service Restart=always** — override in HM config to survive clean exits             | 10min  | HIGH                  |
| 4 | **Fix gitea sops token** — add `gitea_token` to `secrets/hermes.yaml` or create separate sops file | 15min  | HIGH                  |
| 5 | **Add graphical-session health check** — `just health` should verify target is active              | 20min  | HIGH                  |
| 6 | **Nix GC** — `nix-collect-garbage -d` to reclaim disk space (root at 89%)                          | 5min   | HIGH                  |
| 7 | **Verify swappiness=10 deployed** — check if `boot.nix` setting is active                          | 2min   | MEDIUM                |
| 8 | **Add helium.desktop Icon fix** — patch or override the .desktop file                              | 10min  | LOW (noise reduction) |

### P2 — High Impact, Medium Effort

| #  | Task                                                                                                              | Effort | Impact |
| -- | ----------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 9  | **Consolidate serviceDefaults adoption** — audit all services with manual `Restart=` and migrate to shared helper | 1h     | MEDIUM |
| 10 | **Add user-unit monitoring to SigNoz** — journald receiver for `user-*.service`                                   | 30min  | MEDIUM |
| 11 | **file-and-image-renamer → system service** — migrate from HM user unit to system-level like other watchers       | 30min  | MEDIUM |
| 12 | **Add `just waybar-restart` command** — convenience for future recovery                                           | 5min   | LOW    |
| 13 | **Create harden adoption linter** — CI check that services with `serviceConfig` use `harden {}`                   | 1h     | MEDIUM |
| 14 | **Root partition monitoring** — disk warning threshold in waybar (already has `disk` module)                      | 5min   | LOW    |

### P3 — Lower Priority

| #  | Task                                                                                                | Effort | Impact           |
| -- | --------------------------------------------------------------------------------------------------- | ------ | ---------------- |
| 15 | **Provision Pi 3 for DNS failover** — hardware setup, flash NixOS image                             | 2h     | HIGH (when done) |
| 16 | **Clean up SSH session leak** — 27 stale sessions, investigate `sshd_config` keepalive              | 15min  | LOW              |
| 17 | **Migrate justfile recipes to flake apps** — follow AGENTS.md policy (justfile deprecated)          | 2h     | MEDIUM           |
| 18 | **Add `nix.settings.max-free` for automatic GC** — prevent future disk full                         | 10min  | MEDIUM           |
| 19 | **Monitor365 hardening review** — verify `// harden {}` works with X11 DISPLAY access               | 15min  | LOW              |
| 20 | **Hermes hardening review** — verify 24G MemoryMax is still needed                                  | 10min  | LOW              |
| 21 | **Signoz hardening** — re-enable `// harden {}` for cadvisor and collector                          | 15min  | MEDIUM           |
| 22 | **Twenty CRM hardening** — re-enable `// harden { MemoryMax = "2G"; ReadWritePaths = [stateDir]; }` | 10min  | MEDIUM           |
| 23 | **Homepage hardening** — re-enable `// harden {}` + `// serviceDefaults {}`                         | 5min   | LOW              |
| 24 | **Gitea services hardening** — re-enable `// harden {}` for token-gen and runner-token scripts      | 10min  | LOW              |
| 25 | **Darwin platform test** — verify `just switch` still works on macOS                                | 30min  | MEDIUM           |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why did `just test-fast` (which runs `nix flake check --no-build`) sometimes pass and sometimes fail with the same working tree?**

On first run during session 25, it passed. On second run (same files, no changes), it failed with the `harden is not a function` error. Then after a few minutes it passed again. This suggests Nix evaluation caching or a race condition with the flake lock. I cannot determine if this is:

- A Nix daemon caching issue (stale evaluations mixed with new ones)
- A flake-parts module ordering issue
- Something specific to `--no-build` skipping a real build-time check

This is concerning because it means `just test-fast` may not be a reliable gate for correctness.

---

## System Metrics (Live)

| Metric           | Value                    | Status                                   |
| ---------------- | ------------------------ | ---------------------------------------- |
| Root partition   | 438G/512G (89%)          | WARNING                                  |
| /data partition  | 592G/800G (74%)          | OK                                       |
| RAM              | 54G/62G used (87%)       | HIGH (Ollama + llama-server running)     |
| Swap             | 12G/41G used             | OK (ZRAM 3.1G → 10.4G, 3.3x compression) |
| Swappiness       | 30                       | Should be 10 (per session 23 plan)       |
| Load average     | 5.77, 6.15, 7.99         | HIGH (AI inference load)                 |
| Waybar           | NOT RUNNING              | DOWN — pending deployment                |
| Niri             | Running (PID 4689)       | OK                                       |
| Build            | `just test-fast` PASSING | OK                                       |
| Git working tree | CLEAN                    | OK                                       |

---

## Session Commit History (This Session)

```
7371bdb docs(niri-config): add BindsTo→Wants rationale comment
b6ec972 fix(signoz): strip newlines from AMD GPU sysfs reads to prevent Prometheus metric corruption
22f2181 chore(deps): update hermes-agent vendorHash and HaGeZi DNS blocklist hashes
d44004d chore(dns): update HaGeZi anti-piracy blocklist hash
5f8828e fix(signoz): GPU metrics empty value + fix hermes-tui npmDepsHash
8ed4eae fix(niri): replace PartOf with Wants for graphical-session target binding  ← THE FIX
```

---

_The bar is dead. Long live the bar._
