# SystemNix Status Report — 2026-06-29 06:23

## Monitor365 cranked to MAX · 73 commits undeployed · root disk at 93%

---

## Executive Summary

Monitor365 has been reconfigured for **full telemetry mode** — all 19 collector
boolean flags ON, ActivityWatch integration OFF, 30 GiB storage ring buffer.
Three bugs fixed in the demo launcher (port collision, false-ready, silent failure).
**None of this is live.** The running system is a generation from June 26; 73
commits sit undeployed on master. The root disk is at 93% (53 GiB free, 142 GiB
nix store). The single highest-leverage action remains: **deploy**.

| Metric | Value |
|--------|-------|
| Undeployed commits (since ~June 23) | **73** |
| Current generation | `scxw80zl…` (nixpkgs `e73de5b`, June 26) |
| HEAD commit | `99d14573` (mass formatting + monitor365 max mode) |
| Root disk (`/`) | **93%** — 53 GiB free of 723 GiB |
| Data disk (`/data`) | 61% — 404 GiB free of 1.1 TiB |
| nix store size | 142 GiB |
| Uptime | (check `uptime`) |
| Services listening | 40+ ports across system + user services |

---

## a) FULLY DONE ✅

### This Session

1. **Monitor365 collectors — ALL ON.** All 8 previously-disabled collectors
   (screenshot, camera, keystroke, mouse, clipboard, notifications, location,
   fsEvent) now enabled. All 19 boolean flags evaluated ON via `nix eval`.
   `platforms/nixos/system/configuration.nix:327`. **Committed** (`99d14573`).

2. **Monitor365 ActivityWatch integration — OFF.** `activityWatch.enable =
   lib.mkDefault false`. DMS handles notifications; ActivityWatch redundancy
   removed. **Committed**.

3. **Monitor365 storage cap — 30 GiB.** `storage.maxSizeMb = 30 * 1024` (30720).
   Protects BTRFS root from unbounded screenshot/camera growth — the same root
   that nearly died from metadata ENOSPC on June 26. **Committed**.

4. **Demo port collision fixed.** `nix/demo.sh` default port `3001 → 13001`.
   Demo can no longer fight the production server for the same port.
   **Uncommitted** (in `github:LarsArtmann/monitor365`).

5. **Demo false-ready bug fixed.** Readiness loop now checks process liveness
   BEFORE curl — was checking curl first, which hit the production server's
   `/health` and reported "ready!" for a demo server that never started.
   Added 15s timeout + server log capture on failure. **Uncommitted**.

6. **Demo pre-flight port check.** Uses bash `/dev/tcp` (no `ss` dependency,
   works inside the nix-wrapped PATH). Aborts early with a clear error.
   **Uncommitted**.

### Previously Done (committed, code-complete)

7. **BTRFS metadata ENOSPC prevention** — `btrfs-health.nix` gates `nix-gc` +
   `nix-build-cleanup` via `ExecStartPre` guard (aborts when device-unallocated
   < 10%), Prometheus metrics every 5 min, Gatus Discord alerts, DMS widget.
   btrbk staggered to 23:00 (before GC at 00:00).

8. **Deploy exit-code-4 fix** — `deploy.sh` now runs `systemctl reset-failed`
   (system + user) before `nh os switch` to clear start-limit counters.

9. **Network boot race fix** — `dnsblockd-attach-ip.service` (CAP_NET_ADMIN
   oneshot, ordered after `eno1.device`) adds the block IP reliably.

10. **SSH control-master socket cleanup** — systemd user timer probes + unlinks
    dead sockets every 5 min. Darwin gets dir-creation only.

11. **SigNoz SQLite migration lock self-healing** — `ExecStartPre` deletes
    stale `migration_lock` row. Prevents crash-loop after OOM/hard-reset.

12. **Pocket ID provision migration block removed** — fixes the client-secret
    desync that caused `401 invalid client secret` at token exchange.

13. **Docker 29.x `userland-proxy` fix** — `daemon.settings.userland-proxy =
    false` (docker-proxy moved to internal moby derivation).

14. **`mkFilesystem` helper** — validates mount options at eval time. Catches
    cross-fs contamination (e.g. `discard=async` on ext4 → emergency shell).

15. **`serviceOneshotDefaults`** — `Restart=no` default for oneshot services
    (`Restart=always` is invalid for `Type=oneshot`).

16. **DankMaterialShell migration complete** — 13 native DMS plugins, awww
    retired, Waybar retired, wallpaper management native, dynamic theming
    disabled (Catppuccin Mocha preserved).

17. **Crush Daily vendorHash fix** — HTTP server in schedule mode.

18. **DiscordSync reactivated** — go-cqrs-lite v3, localhost API (`:8085`),
    GCS backup opt-in, Gatus + Homepage integration.

---

## b) PARTIALLY DONE ⚠️

### Monitor365 — config maxed, runtime unverified

| Aspect | State |
|--------|-------|
| Agent collectors | All 19 ON — **committed, undeployed** |
| Server | Running (stale `0.2.0`), `0.0.0.0:3001` |
| Auth | **None** — agent→server has no API key, dashboard open on LAN |
| Dashboard | Raw `0.0.0.0:3001`, no TLS, no reverse proxy |
| Storage cap | 30 GiB set — **committed, undeployed** |
| Module size | 716 lines — flagged for split (agent + server) |
| ActivityWatch | Disabled — **committed, undeployed** |

The server binary supports real auth (`/v1/auth`, SSO/OIDC, API keys, Swagger
UI, RBAC admin routes) — none wired. When auth is added, route through Caddy +
Pocket ID (`protectedVHost "monitor365" 3001`).

### Hermes — enabled, missing 3 manual steps

| Step | Status |
|------|--------|
| OpenAI API key in sops | **Blocked** — needs `sops platforms/nixos/secrets/hermes.yaml` |
| SSH deploy key | **Blocked** — private key to `/home/hermes/.ssh/` |
| Fallback model | **Blocked** — `hermes config set fallback_model` |

Without the API key, insights generation cannot function.

### Boot time — ~4 min 53 s

`signoz-provision.service` takes ~2 min waiting for health checks. Sequential
dependencies compound. Not a blocker but impacts recovery time after crashes.

### Gatus health checks — 2 known DOWN

- **Ollama** — expected (`wantedBy = []`, no autostart)
- **Monitor365 Server** — was crash-looping; stale state on the box

### Dual-WAN — disabled

`fix(networking): disable dual-wan to restore ethernet connectivity` (`7d9e5b09`).
Ethernet connectivity restored at the cost of WAN failover. Single-link until
re-enabled.

---

## c) NOT STARTED 📋

1. **Monitor365 agent→server auth** — no authentication. Anyone on LAN can POST
   data. Route through Caddy + Pocket ID when ready.

2. **Monitor365 Caddy vHost** — no reverse proxy, no TLS. Add
   `protectedVHost "monitor365" 3001` in `caddy.nix`.

3. **BTRFS `/data` subvolume migration** — `/data` is toplevel (subvolid=5),
   cannot be snapshotted. Requires USB rescue boot + ~1h downtime.

4. **Cloud backup** — no off-site backup exists. BorgBackup to Hetzner
   StorageBox evaluated but not implemented.

5. **Raspberry Pi 3 provisioning** — DNS failover cluster module ready,
   hardware not provisioned.

6. **Firewall deny-by-default** — NixOS currently allows all inbound. Docker
   punches its own holes.

7. **Auditd enablement** — blocked on NixOS 26.05 bug #483085.

8. **AppArmor** — `mkDefault false` in `security-hardening.nix`.

9. **Module splits** — `monitor365.nix` (716L), `signoz.nix` (705L),
   `forgejo.nix` (583L) all flagged as too large.

10. **Twenty CRM** — intermittent 502s appear resolved but unverified
    post-deploy.

---

## d) TOTALLY FUCKED UP! 🔴

### 1. Zero deploys in 3+ days — all fixes are dead code

**Critical.** The running system on evo-x2 is generation
`scxw80zl…` (nixpkgs June 26). **73 commits** with boot fixes, service fixes,
BTRFS prevention, monitor365 max-mode, and flake.lock updates sit on master.
Every single service fix — the BTRFS GC guard, the network race, the signoz
lock, the SSH socket cleanup, the deploy exit-code-4 fix, the monitor365
collector changes, the crush-daily vendorHash — is **completely inert** until
`nix run .#deploy`.

This is the single most damaging state in the project. It means:
- The BTRFS metadata ENOSPC crash that took down the box on June 26 **can
  happen again tonight** — the GC guard is not live.
- Monitor365 is running the OLD binary with the OLD config (collectors off,
  no storage cap).
- The deploy exit-code-4 bug means any `nh os switch` attempt on the live
  box silently fails if a crash-looped service is in `start-limit-hit`.

### 2. Root disk at 93% — 53 GiB free

**Critical.** 142 GiB nix store on a 723 GiB BTRFS root at 93%. The BTRFS
metadata ENOSPC crash taught us that `df` reports Data-pool free space
(statfs), NOT chunk-level allocation — the entire monitoring stack was blind.
The `btrfs-health.nix` guard exists **but is not deployed**. A nightly
`nix-gc` transaction on a near-full filesystem can I/O deadlock → WDT reset.
**Do not deploy without first running `nix-collect-garbage` or growing the
partition.**

### 3. DiscordSync turso migration bug — upstream

Migration fails: `turso: error: Parse error: Error: invalid expression in
CREATE INDEX: guild_id`. This is an **upstream app bug** in the DiscordSync
migration SQL (libsql/turso parser rejects it). Service crash-loops and hits
start-limit. Requires an upstream fix; cannot be fixed in this repo.

---

## e) WHAT WE SHOULD IMPROVE! 🚀

### Architecture

- **Deploy cadence** — 73 commits without a deploy is a process failure.
  The pre-deploy-check + deploy.sh + exit-code-4 fix all exist; the gap is
  operational, not technical. Consider a recurring reminder or a
  post-commit hook that warns after N undeployed commits.

- **Module size** — Three modules over 500 lines. Split `monitor365.nix`
  into agent + server. Split `signoz.nix` into app + ClickHouse + OTel.
  Split `forgejo.nix` into app + repos + runner.

- **Storage growth visibility** — The 142 GiB nix store on a 93%-full root
  needs proactive GC scheduling. The `nix-build-cleanup` timer (every 4h)
  helps, but `nix-collect-garbage` should run more aggressively when root
  exceeds 90%.

### Security

- **Monitor365 LAN exposure** — `0.0.0.0:3001` with no auth. If the network
  is breached, the dashboard and all collected data (now including
  screenshots, keystrokes, camera) are open.

- **No off-site backup** — All data is on one physical machine. A disk
  failure or BTRFS corruption event is total data loss for Docker volumes,
  Immich, Forgejo, Monitor365, and all service databases.

### Monitoring

- **Gatus DOWN endpoints** — 2 services show DOWN. Needs a post-deploy
  audit to verify which are real outages vs stale check URLs.

- **Boot time** — `signoz-provision` dominates at ~2 min. Parallelize or
  defer non-critical provision steps.

### Upstream debt

- 8+ LarsArtmann Go repos have stale `go.sum` / `vendorHash` workarounds
  in SystemNix overlays that should be fixed upstream.
- 6+ nixpkgs packages have local patches/overrides that are candidates for
  upstream PRs.
- ActivityWatch Wayland watcher needs HM module improvements (graphical-
  session.target deps).

---

## f) Top #25 Things We Should Get Done Next

Sorted by impact × urgency.

| # | Task | Impact | Effort | Why now |
|---|------|--------|--------|---------|
| 1 | **`nix run .#deploy`** | 🔴 Critical | S | 73 commits inert. Everything below is moot until this happens. |
| 2 | **`nix-collect-garbage`** before deploy | 🔴 Critical | S | Root at 93%. Deploy builds a new generation (~5-10 GiB). Free space first. |
| 3 | **Verify Monitor365 post-deploy** | 🔴 Critical | S | Confirm all 19 collectors running, 30 GiB cap active, server healthy. |
| 4 | **Verify BTRFS GC guard is live** | 🔴 Critical | S | The ENOSPC crash WILL recur without it. Check `systemctl status btrfs-health`. |
| 5 | **Commit + push demo.sh fix** (monitor365 repo) | 🟡 Medium | S | Port collision fix is uncommitted in `github:LarsArtmann/monitor365`. |
| 6 | **Monitor365 Caddy vHost + Pocket ID** | 🟠 High | M | Dashboard has no auth, no TLS. Screenshots + keystrokes on open LAN. |
| 7 | **Gatus health audit post-deploy** | 🟡 Medium | S | Verify which DOWN endpoints are real vs stale URLs. |
| 8 | **Hermes: add OpenAI API key to sops** | 🟡 Medium | S | 3 manual steps blocking Hermes insights. This is the first. |
| 9 | **BTRFS `/data` subvolume migration** | 🟠 High | L | Docker/Immich/AI data has no snapshot protection. ~1h downtime. |
| 10 | **Cloud backup (BorgBackup → Hetzner)** | 🟠 High | M | No off-site backup = total data loss risk. |
| 11 | **Split `monitor365.nix`** (716L → agent + server) | 🟢 Low | M | Module too large, hard to maintain. |
| 12 | **Split `signoz.nix`** (705L) | 🟢 Low | M | Same. |
| 13 | **Boot time optimization** (signoz-provision) | 🟡 Medium | M | 5 min boot is unacceptable for crash recovery. |
| 14 | **Firewall deny-by-default** | 🟠 High | M | NixOS allows all inbound. Docker punches holes. |
| 15 | **Fix DiscordSync turso migration** (upstream) | 🟡 Medium | M | Service crash-loops. Upstream SQL bug. |
| 16 | **Monitor365 agent→server auth** | 🟠 High | M | No API key auth. Resolved by #6 (Caddy + Pocket ID). |
| 17 | **Re-enable dual-WAN** (after ethernet verified stable) | 🟡 Medium | S | WAN failover disabled since June 27. |
| 18 | **Raspberry Pi 3 DNS failover** | 🟢 Low | L | Hardware needed. Module ready. |
| 19 | **Hermes: SSH deploy key + fallback model** | 🟡 Medium | S | Steps 2+3 of Hermes unblock. |
| 20 | **`nix-collect-garbage` automation** (root >90%) | 🟡 Medium | S | Prevent the 93% situation from recurring. |
| 21 | **Twenty CRM 502 monitoring** | 🟢 Low | S | Appears resolved. Monitor post-deploy. |
| 22 | **Upstream Go repo `go.sum` fixes** (library-policy, mr-sync) | 🟢 Low | M | Removes Nix-side workaround overlays. |
| 23 | **nixpkgs upstream PRs** (6 candidates) | 🟢 Low | L | aw-watcher-utilization, valkey, taskwarrior3, etc. |
| 24 | **AppArmor enablement** | 🟢 Low | M | Currently `mkDefault false`. |
| 25 | **Auditd enablement** | 🟢 Low | S | Blocked on NixOS 26.05 bug. Re-evaluate. |

---

## g) The #1 Question I Cannot Answer Myself

### Should I deploy right now, given the root disk is at 93%?

The deploy will build a new system generation. On a 93%-full BTRFS root with
142 GiB of nix store, this is risky:

- The build itself needs free space (Nix sandbox builds, derivation outputs).
- The BTRFS metadata ENOSPC crash (June 26) was triggered by exactly this
  scenario: GC transactions on a near-full filesystem.
- The `btrfs-health.nix` GC guard that prevents this **is in the undeployed
  code** — so the running system has NO protection.

**I cannot run `sudo` or `systemctl` from this environment** (blocked by
policy), so I cannot:
- Check BTRFS chunk-level allocation (`sudo btrfs filesystem df /`)
- Run `nix-collect-garbage` to free space before deploying
- Check which services are in `start-limit-hit` on the live box
- Verify the actual boot generation age vs commit history

**The decision I need from you:** Do you want to deploy now (accepting the
disk-space risk), or should we first garbage-collect the nix store to get
root below 85%? A `nix-collect-garbage -d` could free 20-40 GiB of old
generations, but I cannot run it from here — it needs your terminal.

---

_Generated 2026-06-29 06:23. Working tree: clean (SystemNix). Monitor365 repo:
1 uncommitted file (`nix/demo.sh`)._
