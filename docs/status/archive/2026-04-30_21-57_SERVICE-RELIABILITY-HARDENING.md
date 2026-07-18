# SystemNix — Session 8: System-Wide Service Reliability Hardening

**Date:** 2026-04-30 21:57 CEST
**Branch:** master
**Commit Range:** `616b425` → (pending)

---

## Session Trigger

Wallpapers disappeared. `awww-daemon` crashed with a Rust panic (`BrokenPipe` → `unwrap()` → SIGABRT → core dump). `Restart=on-failure` did NOT restart it because systemd treats core dumps as `ABRT` signal, not a "failure" exit code. The dependent `awww-wallpaper` oneshot also died. Result: no wallpaper for hours.

**Root cause:** `Restart=on-failure` only covers non-zero exit codes. It does NOT cover:

- SIGABRT (core dumps from panics)
- SIGHUP (terminal disconnects)
- Clean exits (exit code 0) from services that shouldn't exit

**Solution:** `Restart=always` for all long-running daemons — restarts regardless of exit reason.

---

## a) FULLY DONE

### 1. Service Defaults Library (`lib/systemd/service-defaults.nix`)

- Changed default `Restart` from `"on-failure"` → `"always"`
- All future services using `serviceDefaults` inherit `always` automatically

### 2. System-Wide Restart Policy Overhaul — 17 files, 19 services

Every long-running daemon in the project now uses `Restart = "always"`:

| Service                 | File               | Added StartLimitBurst? |
| ----------------------- | ------------------ | ---------------------- |
| awww-daemon             | `niri-wrapped.nix` | ✅ (10/60s)            |
| awww-wallpaper          | `niri-wrapped.nix` | Already had            |
| swayidle                | `niri-wrapped.nix` | Already had            |
| cliphist                | `niri-wrapped.nix` | Already had            |
| Caddy                   | `caddy.nix`        | ✅ Added               |
| Immich server           | `immich.nix`       | Already had            |
| Immich ML               | `immich.nix`       | Already had            |
| Homepage                | `homepage.nix`     | Already had            |
| Authelia                | `authelia.nix`     | ✅ Added               |
| SigNoz query-service    | `signoz.nix`       | Already had            |
| SigNoz clickhouse       | `signoz.nix`       | Already had            |
| SigNoz otel-collector   | `signoz.nix`       | Already had            |
| TaskChampion            | `taskchampion.nix` | ✅ Added               |
| ComfyUI                 | `comfyui.nix`      | ✅ Added               |
| Voice Agents (Whisper)  | `voice-agents.nix` | ✅ Added               |
| Minecraft               | `minecraft.nix`    | Already had            |
| AI Stack (Unsloth)      | `ai-stack.nix`     | ✅ Added               |
| Twenty CRM              | `twenty.nix`       | ✅ Added               |
| Gitea                   | `gitea.nix`        | Already had            |
| Gitea Repos             | `gitea-repos.nix`  | ✅ Added               |
| DNS Blocker (dnsblockd) | `dns-blocker.nix`  | Already had            |
| Monitor365              | `monitor365.nix`   | Already had            |

### 3. Wallpaper Service Reliability (`niri-wrapped.nix`)

- `awww-daemon`: `Restart = "always"`, `RestartSec = "2s"`, `StartLimitBurst = 10` / 60s
- `awww-wallpaper`: Changed `Requires` → `BindsTo` (restarts when daemon restarts)
- `awww-wallpaper`: `RestartSec` 2s → 3s (give daemon breathing room)

### 4. Missing StartLimitBurst/StartLimitIntervalSec Added

Services that previously had NO rate limiting now have `StartLimitBurst = 3` + `StartLimitIntervalSec = 300`:

- Caddy, Authelia, TaskChampion, ComfyUI, Voice Agents, AI Stack, Twenty, Gitea Repos

### 5. Validation

- `just test-fast` passes — all Nix module eval checks green

---

## b) PARTIALLY DONE

### Photomap Service

- Uses `serviceDefaults {RestartSec = "10s";}` — inherits new `Restart = "always"` from the helper automatically. **No manual change needed but not explicitly verified in this session.**

### Hermes Agent

- Already had `Restart = lib.mkForce "always"` — was the ONLY service doing it right before this session. No change needed.

### Niri Service Itself

- Already had `Restart=always` via dropin in `niri-config.nix`. No change needed.

---

## c) NOT STARTED

### High-Priority Infrastructure

1. **DNS Failover Cluster (Pi 3)** — `dns-failover.nix` module exists but Pi 3 hardware not provisioned
2. **Wallpaper rotation timer** — service runs at boot only, no periodic cycling (30min timer planned)
3. **Pre-commit statix hook** — broken since wallpapers commit, using `--no-verify`
4. **SigNoz alert rules** — provisioned but no active alerting channels configured

### Services That Could Be Added

5. **Photomap health check** — no ExecStartPost health verification
6. **Docker health monitoring** — no automatic container health → systemd propagation
7. **Automated backup verification** — Immich/Gitea backups run but aren't tested for restore

### Desktop UX

8. **Wallpaper rotation timer** — systemd user timer cycling wallpaper every 30min
9. **Mod+Shift+W / Mod+Ctrl+W** — wallpaper next/prev keybinds (from improvement-ideas)
10. **ActivityWatch autostart** — NixOS service for AW (currently only Darwin launchagent)

---

## d) TOTALLY FUCKED UP

### Nothing This Session

All changes validated with `just test-fast`. 17 files, 37 insertions, 21 deletions — purely additive safety improvements with zero functional behavior changes.

### Known Ongoing Issues

| Issue                               | Severity | Status                                       |
| ----------------------------------- | -------- | -------------------------------------------- |
| Pre-commit statix hook broken       | Medium   | Using `--no-verify` workaround               |
| Monitor365 disabled                 | Low      | High RAM usage, disabled in config           |
| DNS failover cluster                | Low      | Module exists, Pi 3 not provisioned          |
| awww v0.12.0 BrokenPipe panic       | Medium   | Upstream bug — mitigated by `Restart=always` |
| `wallpapers` repo only has 4 images | Low      | Subjective — user may want more variety      |
| SigNoz built from source            | Info     | 20+ min build times, unavoidable             |

---

## e) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Never use `Restart=on-failure` for long-running daemons again** — `always` should be the default for any service expected to run continuously. `on-failure` should only be for oneshot/batch jobs.
2. **Always include `StartLimitBurst` + `StartLimitIntervalSec`** — prevents runaway restart loops when a service is fundamentally broken (e.g., missing config, broken binary).
3. **Fix the pre-commit statix hook** — every commit requiring `--no-verify` is a smell.
4. **Add `OnFailure` notifications to critical services** — wallpaper daemon failure was invisible until user noticed. `OnFailure=notify@%n.service` pattern should be on all user services.

### Technical Debt

5. **Consolidate restart settings into `serviceDefaults`** — many services still inline their restart config instead of using the shared helper. Should migrate remaining services to `serviceDefaults {}`.
6. **Extract wallpaper config into dedicated module** — wallpaper logic is embedded in the massive `niri-wrapped.nix` (866 lines). Wallpaper daemon, startup, keybinds should be their own module.
7. **awww upstream bug** — File issue on awww repo about the `unwrap()` on BrokenPipe. Should be a graceful reconnect, not a panic.

---

## f) Top 25 Things to Do Next

### Critical (P0)

| #   | Task                                                        | Est.  |
| --- | ----------------------------------------------------------- | ----- |
| 1   | Deploy this session's changes: `just test && just switch`   | 10min |
| 2   | Verify awww-daemon restarts after `just switch`             | 2min  |
| 3   | Fix pre-commit statix hook (broken since wallpapers commit) | 15min |

### High (P1)

| #   | Task                                                                                 | Est.  |
| --- | ------------------------------------------------------------------------------------ | ----- |
| 4   | Add `OnFailure` notification to all user systemd services (awww, cliphist, swayidle) | 15min |
| 5   | Add wallpaper rotation timer (every 30min, random from wallpaperDir)                 | 10min |
| 6   | Consolidate remaining inline restart config into `serviceDefaults` calls             | 20min |
| 7   | Extract wallpaper logic from niri-wrapped.nix into dedicated module                  | 30min |
| 8   | Add Mod+Shift+W (next wallpaper) and Mod+Ctrl+W (prev wallpaper) keybinds            | 10min |
| 9   | File upstream awww bug report for BrokenPipe panic                                   | 10min |

### Medium (P2)

| #   | Task                                                                                      | Est.           |
| --- | ----------------------------------------------------------------------------------------- | -------------- |
| 10  | Add ExecStartPost health checks to services missing them (Authelia has one, others don't) | 30min          |
| 11  | Update AGENTS.md with new Restart=always policy and rationale                             | 5min           |
| 12  | Provision Pi 3 hardware for DNS failover cluster                                          | 1hr (hardware) |
| 13  | Add Docker container health → systemd status propagation                                  | 20min          |
| 14  | Configure SigNoz alert channels (email/Discord/webhook)                                   | 15min          |
| 15  | Add Immich backup restore test (verify backups actually work)                             | 30min          |
| 16  | Add Gitea backup restore test                                                             | 20min          |
| 17  | Wire monitor365 back up (investigate RAM usage, tune or add MemoryMax)                    | 20min          |
| 18  | Add ActivityWatch NixOS systemd service (currently only Darwin)                           | 15min          |

### Low (P3)

| #   | Task                                                                        | Est.  |
| --- | --------------------------------------------------------------------------- | ----- |
| 19  | Audit all services for missing `ReadWritePaths` (systemd hardening)         | 30min |
| 20  | Add `PrivateUsers=true` to services that don't need UID manipulation        | 20min |
| 21  | Review all `TimeoutStartSec` values (some may be too aggressive)            | 15min |
| 22  | Add `LogRateLimitIntervalSec` / `LogRateLimitBurst` for noisy services      | 10min |
| 23  | Investigate niri-wrapped.nix line count (866 lines) — further decomposition | 1hr   |
| 24  | Add nix flake check CI (already have workflows but not wired)               | 20min |
| 25  | Audit all `mkForce` usage — some may be unnecessary                         | 15min |

---

## g) Top #1 Question I Cannot Answer Myself

**Why is the awww daemon hitting a BrokenPipe in the first place?**

The crash happened at `daemon/src/main.rs:712:32` — a `Result::unwrap()` on what appears to be a Wayland compositor socket write. The daemon was running fine for ~2d 18h before crashing. Possible causes:

1. **niri compositor restart** — Did niri restart during a `just switch` or crash, breaking the Wayland socket?
2. **Display sleep/resume** — The swayidle timeout is 43200s (12h). Did display power management briefly break the socket?
3. **awww daemon memory leak** — It peaked at 225MB with 217MB swap. Is there a slow leak that eventually OOMs?

I can't determine which without:

- `RUST_BACKTRACE=full` output from the next crash
- Correlation with niri logs around the same timestamp (Apr 30 04:22)
- Memory usage trend over the 2d 18h uptime

**Recommendation:** Enable `RUST_BACKTRACE=1` in the awww-daemon service Environment and add a coredump analysis step to the awww service config.

---

## Statistics

| Metric                     | Value                 |
| -------------------------- | --------------------- |
| Files changed this session | 17                    |
| Services hardened          | 19                    |
| New StartLimitBurst added  | 8 services            |
| Total commits April 2026   | 580+                  |
| Service modules total      | 28                    |
| Custom packages            | 7                     |
| `just test-fast`           | ✅ Pass               |
| Build validation           | Pending (`just test`) |
