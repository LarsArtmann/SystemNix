# Status Report — Boot Reliability: Six Service Fixes

**Generated:** Saturday, June 27, 2026 at 21:18 CEST
**Host:** evo-x2 (NixOS, x86_64-linux, AMD Ryzen AI Max+ 395, 128GB RAM)
**Uptime:** 4h12m (booted 17:06) · **Branch:** master @ `aeef15fd`

---

## TL;DR

A full boot/shutdown log audit found the system **boots cleanly at the kernel level** (no OOM, no WDT reset, no NVMe/FS errors) and **shuts down cleanly** (boot −1 was a normal `systemd-reboot`). The reliability problems are all **service-startup failures**: 6 root-caused, **5 fixed in this session** (1 blocked on an upstream bug). All fixes pass `nix flake check --no-build` + full evo-x2 system eval. **Deploy pending.**

| Metric | Value |
|--------|-------|
| Boot-to-graphical-target | 2m 18s (userspace) · 4m 53s total |
| Failed services this boot | 7 (5 now fixed, 1 upstream-blocked, 1 self-heals) |
| Disk: root (`/`) | 535G / 723G (75%) |
| Disk: `/data` | 631G / 1.1T (61%) |
| `/nix` store | 118G |
| Enabled service modules | ~29 |

---

## a) FULLY DONE ✅

### Boot reliability fixes (this session — verified, eval passing)

1. **SigNoz stale migration lock — self-healing.** After a crash/OOM mid-migration, `migration_lock` in `/var/lib/signoz/signoz.db` kept a row → next boots looped `attempt to acquire lock failed` → start-limit-hit. Added `ExecStartPre` (`signoz-clear-migration-lock`) that `DELETE FROM migration_lock` — safe because no signoz process is alive at ExecStartPre. **`modules/nixos/services/signoz.nix`**

2. **Monitor365 agent — fixed `$XDG_RUNTIME_DIR` vanishing.** Hardened user services don't reliably expose `$XDG_RUNTIME_DIR`, so the ExecStart collapsed to `monitor365 --config run` (config path gone, `run` treated as the path). Switched to systemd specifier `%t` (always resolves). The inject-auth ExecStartPre now receives `%t` as `$1`. **`modules/nixos/services/monitor365.nix`**

3. **Monitor365 server — removed invalid `--config` flag.** The binary's CLI changed: `--config <file>` was dropped (server now uses `MONITOR365_SERVER__*` env vars + XDG `~/.config/monitor365/server.toml` auto-load). The old flag caused `unexpected argument '--config'`. **`modules/nixos/services/monitor365.nix`**

4. **dnsblockd-cert-import — added the actual `certutil` provider.** `path = [pkgs.nss]` was libs-only; `certutil` lives in the **`pkgs.nss.tools`** output. Status 127 (command not found) on every login. Now `path = [pkgs.nss.tools pkgs.coreutils]`. **`modules/nixos/services/dns-blocker.nix`**

5. **xdg-document-portal — added missing `fusermount3` setuid wrapper.** The portal crashed every login: `posix_spawn for fusermount3 failed: No such file or directory`. Added `security.wrappers.fusermount3` (pulls `fuse3` into the closure). **`platforms/nixos/system/configuration.nix`**

6. **ActivityWatch wayland watcher — added `Restart=on-failure`.** The watcher panicked on boot when the compositor wasn't ready yet (`Failed to connect to wayland display`), then **stayed dead** because it had no Restart policy. Now self-heals 5s after a failure. **`platforms/common/programs/activitywatch.nix`**

7. **AGENTS.md — 6 new gotchas documented** (discordsync turso bug, signoz migration lock, monitor365 hardened services, `pkgs.nss` libs-only, fusermount3 wrapper, network interface boot race). **`AGENTS.md`**

### Already-shipped prior work (this week)

- **Ethernet connectivity restored** — `dual-wan.enable = false` (commit `7d9e5b09`). The `route-health-monitor` was evicting the eno1 default route on transient 2s probe failures. Full incident report: `docs/ethernet-connectivity-loss-2026-06-27.md`.
- **BTRFS metadata ENOSPC crash prevention** — `btrfs-health.nix` gates `nix-gc`/`nix-build-cleanup` via ExecStartPre guard, Prometheus metrics every 5min, Gatus Discord alerts, btrbk staggered before GC. (commits `4f580f5e`, `fbe6f672`, `6646fceb`)
- **DankMaterialShell migration complete** — 13 SystemNix plugins verified loading, awww/waybar retired.
- **DiscordSync reactivated** — go-cqrs-lite v3, localhost API on :8085, Gatus/Homepage integration (commit `eea32b64`, `a475a905`).
- **Caddy boot ordering fix** — `wants = ["sops-nix.service"]` prevents 14h outage recurrence.

---

## b) PARTIALLY DONE ⚠️

| Area | Status | What remains |
|------|--------|--------------|
| **Monitoring stack (SigNoz)** | The query service + signoz-provision cascade-failed on the stale lock. Now self-healing. | **Deploy** to activate. signoz-provision will succeed once signoz starts cleanly. |
| **Monitor365** | Agent + server ExecStart fixed. | **Deploy** required. The TODO_LIST noted an earlier "Rust panic (Axum)" root cause — that is now superseded; the current failure is purely the CLI/env issues fixed above. |
| **OAuth2-proxy** | Failed once at boot (credential-mount race) then **recovered** on retry — now serving 200s to Gatus. | No action needed; consider it transient. |
| **DNS failover cluster** | `dns-failover` (keepalived VRRP) module is ready; rpi3 config exists. | Hardware not provisioned; dual-wan disabled. See "Not Started". |
| **DiscordSync** | Reactivated, integrated into monitoring. | **Upstream migration bug blocks it** (see TOTALLY FUCKED UP). |
| **Hermes** | Nix wiring done, Otel fixed, SMTP wired. | Manual steps blocked: OpenAI key in sops, SSH deploy key, fallback model set. |
| **Validation** | `nix flake check --no-build` + full evo-x2 eval **pass**. | No live deploy verification yet this session. |

---

## c) NOT STARTED 📋

| Item | Notes |
|------|-------|
| **Deploy the 6 fixes** | `nix run .#deploy` not yet run this session. |
| **Cloud/off-site backup** | No BorgBackup to Hetzner StorageBox. Single point of failure for all `/data`. |
| **BTRFS `/data` subvolume migration** | `/data` is BTRFS toplevel (subvolid=5), cannot be snapshotted. Needs ~1h downtime + USB rescue boot. |
| **Firewall deny-by-default** | NixOS allows all inbound; Docker punches its own holes. |
| **Auditd enablement** | Blocked on NixOS 26.05 bug #483085. |
| **AppArmor enablement** | `mkDefault false` in security-hardening.nix. |
| **Monitor365 agent→server auth** | No authentication — anyone on LAN can POST data. |
| **Disabled service triage** | voice-agents (keep disabled), minecraft (seasonal), photomap (remove). |

---

## d) TOTALLY FUCKED UP 💥

### 1. DiscordSync upstream migration bug — **cannot fix in Nix**

```
[infrastructure:db.error] failed to run migrations:
turso: error: Parse error: Error: invalid expression in CREATE INDEX: guild_id
```

DiscordSync crash-loops on every start (5 retries → start-limit-hit). The migration SQL is rejected by the turso/libsql parser. This is an **upstream app bug in `github:LarsArtmann/DiscordSync`** — the migration `CREATE INDEX` statement uses syntax the DB engine doesn't accept. **There is no Nix-side workaround.** Requires patching the DiscordSync source.

### 2. Boot is slow (4m 53s)

`signoz-provision` alone takes **2 minutes** (waiting for signoz health). `clickhouse` 43s, `hermes` 41s, `docker` 27s. graphical-target at 2m18s is acceptable; the extra 2.5min to full-userspace is the provision + container startup tail.

### 3. Network interface boot race — only worked around, not fixed

`dual-wan` was disabled to restore ethernet, but the **underlying race** is real: services binding to `eno1`/VRRP VIP start before the NIC/IP is ready. In boot −1 this caused `dnsblockd` to crash-loop **105 times** and `keepalived` to fail (`interface eno1 for vrrp_instance VI_DNS doesn't exist`). The proper fix (re-enable with `sys-subsystem-net-devices-eno1.device` ordering + a CAP_NET_ADMIN oneshot to assign the IP) is **not done**.

### 4. TODO_LIST root-cause discrepancy for monitor365

The TODO_LIST (`Updated 2026-06-25`) records the monitor365-server root cause as "upstream Rust panic (Axum 0.7 route syntax `:param` → `{param}`)". The **current** failure is entirely different: an invalid `--config` flag on the new CLI. The old note is stale/misleading — this session's diagnosis supersedes it.

---

## e) WHAT WE SHOULD IMPROVE 🔧

1. **Deploy first, then verify** — the 6 fixes are eval-clean but not live. A single `nix run .#deploy` activates them.
2. **Fix DiscordSync upstream** — it's a private LarsArtmann repo; the migration SQL bug is a 5-line fix in the source.
3. **Self-healing everywhere** — the signoz lock pattern (ExecStartPre clears stale state) should be applied to other crash-prone stateful services.
4. **Order network-dependent services correctly** — if dual-wan is ever re-enabled, bind to the `.device` unit, not just `network-online.target` (NM returns "online" before the IP is assigned).
5. **Boot-time regression tests** — add a post-boot check (extend `pre-deploy-check`) that asserts no service is in `start-limit-hit`.
6. **Off-site backup** — the absence of cloud backup is the single biggest disaster-recovery gap. All Docker data on un-snapshottable `/data`.
7. **Reduce provision tail** — signoz-provision's 2-min wait is the largest boot-time contributor; consider `Type=notify` or a shorter health-check interval.

---

## f) Top 25 Things to Get Done Next

Ranked by impact × effort (Pareto):

| # | Task | Impact | Effort |
|---|------|--------|--------|
| 1 | **Deploy the 6 boot fixes** (`nix run .#deploy`) | 🔴 Critical | XS |
| 2 | **Fix DiscordSync migration SQL** (upstream `CREATE INDEX` bug) | 🔴 Critical | S |
| 3 | **Verify signoz + signoz-provision self-heal post-deploy** | 🔴 High | XS |
| 4 | **Verify monitor365 agent + server start post-deploy** | 🔴 High | XS |
| 5 | **Verify xdg-document-portal + activitywatch post-deploy** | 🟠 Medium | XS |
| 6 | **Set up BorgBackup to Hetzner StorageBox** (off-site DR) | 🔴 Critical | M |
| 7 | **BTRFS `/data` subvolume migration** (snapshot protection) | 🔴 High | L |
| 8 | **Fix network-dependent service ordering** (`.device` units) | 🟠 High | M |
| 9 | **Reduce signoz-provision boot tail** (2min → target <30s) | 🟠 Medium | M |
| 10 | **Hermes manual steps** (OpenAI key, SSH deploy key, fallback model) | 🟠 Medium | S |
| 11 | **Firewall deny-by-default** + explicit allowlist | 🟠 High | M |
| 12 | **Bind Immich to localhost** (remove `0.0.0.0` + openFirewall) | 🟡 Security | XS |
| 13 | **Monitor365 agent→server auth** | 🟡 Security | M |
| 14 | **Remove photomap** (decided — podman perm issue, niche) | 🟢 Low | XS |
| 15 | **Audit disk: `/nix` at 118G** — run `nix-collect-garbage -d` | 🟠 Medium | S |
| 16 | **Split large modules** (monitor365 716L, signoz 705L, forgejo 583L) | 🟢 Low | L |
| 17 | **Upstream: nixpkgs `aw-watcher-utilization` poetry-core PR** | 🟢 Low | S |
| 18 | **Upstream: HM ActivityWatch watcher deps PR** | 🟢 Low | S |
| 19 | **Add post-boot `no-failed-services` assertion** to deploy checks | 🟠 Medium | S |
| 20 | **Auditd enablement** (re-check NixOS bug #483085 status) | 🟡 Security | S |
| 21 | **AppArmor enablement** | 🟡 Security | M |
| 22 | **Provision Pi 3** for DNS failover cluster (hardware needed) | 🟢 Low | L |
| 23 | **Jan llama-server respawn investigation** (spawns new proc every 1-3min) | 🟠 Medium | M |
| 24 | **Extract dnsblockd to standalone repo** (~930 lines embedded Go) | 🟢 Low | L |
| 25 | **Darwin HM parity** (blocked by 256GB disk constraint) | 🟢 Low | L |

---

## g) Top Question I Cannot Figure Out Myself 🤔

**Should I dig into the `github:LarsArtmann/DiscordSync` source to fix the turso `CREATE INDEX: guild_id` migration bug, or disable DiscordSync until you patch it upstream?**

The migration failure (`turso: error: Parse error: Error: invalid expression in CREATE INDEX: guild_id`) is definitively an **upstream application bug** — not a Nix config issue. DiscordSync is a private LarsArtmann repo, so I *could* attempt the fix, but I need to know:

- Is this a recent schema change you're mid-flight on (i.e. is the migration intentionally not yet valid)?
- Do you want me to read the DiscordSync migration files and propose/apply the SQL fix, or is DiscordSync low-priority and I should just disable it cleanly to stop the crash-loop noise?

This is the one thing blocking an otherwise-clean service startup picture, and the decision (patch upstream vs. disable) is yours.

---

## Files Changed This Session

| File | Change |
|------|--------|
| `modules/nixos/services/signoz.nix` | + ExecStartPre (`signoz-clear-migration-lock`) |
| `modules/nixos/services/monitor365.nix` | agent `%t` specifier; server dropped invalid `--config` |
| `modules/nixos/services/dns-blocker.nix` | `path = [pkgs.nss.tools pkgs.coreutils]` |
| `platforms/common/programs/activitywatch.nix` | + `Restart=on-failure` on wayland watcher |
| `platforms/nixos/system/configuration.nix` | + `security.wrappers.fusermount3`; conflict resolved |
| `AGENTS.md` | + 6 gotcha entries |

**Validation:** `nix flake check --no-build` ✅ · `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` ✅
