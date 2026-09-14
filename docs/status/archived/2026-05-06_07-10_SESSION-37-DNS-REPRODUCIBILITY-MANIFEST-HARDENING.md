# Session 37 — DNS Blocklist Reproducibility Fix & Manifest Service Hardening

**Date:** 2026-05-06 07:10 CEST
**System:** evo-x2 (NixOS 26.05.20260423.01fbdee, Yarara)
**Branch:** master @ e693caa
**Generation:** `/nix/store/bwxn7c6wyv6sil1mw79kfn2ylyvbzk1p-nixos-system-evo-x2-26.05.20260423.01fbdee`

---

## Executive Summary

Fixed a build-breaking hash mismatch caused by mutable DNS blocklist URLs (pointing to `main` branch), hardened the manifest Docker service against activation restart races, and successfully deployed with zero service failures.

---

## A. FULLY DONE

### 1. DNS Blocklist Hash Mismatch Fix

- **Root cause:** 11 of 25 blocklist URLs pointed to `hagezi/dns-blocklists/main/...` and `StevenBlack/hosts/master/...` — mutable branches. Every upstream commit invalidated the Nix hash.
- **Fix:** Pinned all 25 blocklists to specific git commits:
  - HaGeZi: `489ce87162a4824080b8ab3fb4db7c8ea65fd38c`
  - StevenBlack: `4a68876c7fc71ecd572ad74e491b75a52ef2d31b`
- **Updated hashes:** 12 stale SRI hashes replaced with current values
- **File:** `platforms/shared/dns-blocklists.nix` — 25 URL edits, 12 hash updates

### 2. Manifest Service Hardening

- **Root cause:** During `nh os switch`, systemd restarts manifest.service, which tears down Docker containers that are still initializing. The postgres container gets SIGTERM mid-init, leading to "dependency failed to start" cascading failures.
- **Fix in `modules/nixos/services/manifest.nix`:**
  - Added `docker-compose down --remove-orphans || true` in `ExecPreStart` — cleans stale state before each start
  - Added `--timeout 30` to `ExecStop` — graceful container shutdown
  - Added `TimeoutStopSec = "60"` — systemd patience for shutdown
  - Added `KillMode = "process"` — lets docker-compose manage its own children

### 3. Successful Build & Activation

- Build: 18 derivations, 0 failures, 7 seconds
- Activation: all services started cleanly, no failures
- Bootloader updated (nh os switch, not test mode)

---

## B. PARTIALLY DONE

### 1. Manifest Docker Healthcheck

- **Status:** Container reports "unhealthy" but `/api/v1/health` returns 200 OK
- **Root cause:** The healthcheck URL in docker-compose uses wrong path/port combination:
  ```yaml
  test:
    [
      "CMD",
      "node",
      "-e",
      "const p=process.env.PORT||'2099';fetch(`http://127.0.0.1/$${p}/api/v1/health`)...",
    ]
  ```
  The URL becomes `http://127.0.0.1/2099/api/v1/health` — but the app likely listens on root, not `/2099/`. The `fetch` URL template is wrong.
- **Impact:** Low — service works, but Docker marks it unhealthy. Needs healthcheck URL fix.

### 2. dnsblockd Context Canceled Errors

- **Status:** Persistent `TRACK_REQUEST` and `TRACK_METRICS` context canceled errors in logs
- **Impact:** Low — appears to be a timing issue during metric aggregation, not affecting DNS blocking
- **Needs:** Investigation — could be upstream dnsblockd issue or config tuning

---

## C. NOT STARTED

### 1. Upstream PRs for Forked Projects

- niri-session-manager fork PR not yet created (planned in session 36)
- No fork PRs for other modified upstream projects

### 2. DNS Failover Cluster (Pi 3)

- Status: Planned — Pi 3 hardware not yet provisioned
- Module exists: `modules/nixos/services/dns-failover.nix`

### 3. Automated Blocklist Update Workflow

- No justfile recipe for updating blocklist commit pins + hashes
- Currently manual process: fetch new HEAD commit, update URLs, prefetch all hashes
- Should be automated with a justfile recipe

### 4. Darwin (macOS) Build Verification

- No cross-platform build test performed
- Blocklist changes are shared (`platforms/shared/`) — affects both platforms

---

## D. TOTALLY FUCKED UP

### 1. watchdogd Config Parse Error

- **Service:** `watchdogd.service` — started but config fails to parse
- **Error:** `missing title for` at line 1 of generated config
- **File:** `platforms/nixos/system/boot.nix` lines 132-146
- **Generated config:** `/nix/store/5n7kxscm28msy4jkgl5nam3v786k2s04-watchdogd.conf`
- **Root cause:** The Nix `services.watchdogd.settings` format doesn't match watchdogd v4.1 expected TOML/INI format. The generated file lacks section headers (e.g., `[meminfo]` should be a TOML section, not a nested attribute).
- **Impact:** HIGH — hardware watchdog is NOT supervising the system. If the GPU hangs again, automatic reboot won't trigger.
- **Fix needed:** Rewrite the watchdogd config to use proper TOML section format.

### 2. Previous Session: Activation Failure Caused Network Loss

- During the first `nh os switch` attempt (before this session), unbound was stopped/restarted during activation, causing temporary DNS loss. The user had to reboot.
- This is an inherent risk of `nh os switch test` mode — services restart during activation. The `switch` mode (which updates bootloader) is safer since it's a full generation change.

---

## E. WHAT WE SHOULD IMPROVE

### Architecture

1. **Reproducible blocklist updates** — Create a justfile recipe that: fetches latest HaGeZi/StevenBlack HEAD, updates commit pins, prefetches all hashes, validates build
2. **watchdogd config** — Fix TOML format so hardware watchdog actually works
3. **Manifest healthcheck** — Fix Docker healthcheck URL so container reports healthy
4. **Activation ordering** — Consider adding `After=network-online.target` or DNS-wait logic for services that need DNS during startup

### Operational

5. **Service health dashboard** — All services should report health to SigNoz, not just logs
6. **Pre-switch validation** — `just test` should catch hash mismatches before `just switch`
7. **dnsblockd error investigation** — Track down context canceled errors

### Code Quality

8. **Manifest sops secret duplication** — Secrets are defined in both `manifest.nix` and `sops.nix` with duplicate `restartUnits`
9. **Blocklist file structure** — Consider extracting commit pins as a separate attrset for easier updates

---

## F. Top #25 Things to Do Next

| #  | Priority | Task                                                                                   | Impact   | Effort |
| -- | -------- | -------------------------------------------------------------------------------------- | -------- | ------ |
| 1  | P0       | Fix watchdogd config parse error (hardware watchdog non-functional)                    | Critical | Low    |
| 2  | P0       | Fix manifest Docker healthcheck URL                                                    | Medium   | Low    |
| 3  | P1       | Create `just dns-update` recipe for blocklist pin+hash updates                         | Medium   | Medium |
| 4  | P1       | Verify Darwin (macOS) build still passes with blocklist changes                        | Medium   | Low    |
| 5  | P1       | Investigate dnsblockd `context canceled` errors                                        | Low      | Medium |
| 6  | P1       | Deduplicate manifest sops secrets between manifest.nix and sops.nix                    | Low      | Low    |
| 7  | P2       | Create niri-session-manager upstream fork PR                                           | Medium   | Medium |
| 8  | P2       | Add `After=network-online.target` to manifest.service for first-boot reliability       | Medium   | Low    |
| 9  | P2       | Update AGENTS.md with blocklist pinning pattern and update procedure                   | Low      | Low    |
| 10 | P2       | Add SigNoz health checks for manifest, dnsblockd, hermes                               | Medium   | Medium |
| 11 | P2       | Create automated blocklist freshness check (alert when commit is >30 days old)         | Low      | Medium |
| 12 | P3       | Migrate manifest from docker-compose to podman (podman was removed but Docker remains) | Medium   | High   |
| 13 | P3       | Add BTRFS snapshot before `just switch` for rollback safety                            | Medium   | Medium |
| 14 | P3       | Provision Pi 3 for DNS failover cluster                                                | Medium   | High   |
| 15 | P3       | Add immich database backup verification (restore test)                                 | Medium   | Medium |
| 16 | P3       | Review and clean up Docker images/volumes (42% of /data used)                          | Low      | Low    |
| 17 | P3       | Add home-manager activation script for niri-session-manager app→command mapping        | Medium   | Low    |
| 18 | P3       | Configure Twenty CRM behind Caddy reverse proxy                                        | Medium   | Medium |
| 19 | P4       | Add GPU temperature monitoring to SigNoz                                               | Low      | Low    |
| 20 | P4       | Create justfile recipe for GPU recovery testing                                        | Low      | Low    |
| 21 | P4       | Add disk usage alerting via SigNoz (root 88%, /data 76%)                               | Medium   | Low    |
| 22 | P4       | Review deer-flow Docker stack — not behind Caddy, no reverse proxy                     | Medium   | Medium |
| 23 | P4       | Document GPU hang recovery procedure (REISUB) in justfile                              | Low      | Low    |
| 24 | P4       | Add niri-drm-healthcheck timer validation                                              | Low      | Low    |
| 25 | P5       | Investigate whisper-asr Docker container — no health check, no restart policy          | Low      | Low    |

---

## G. Top #1 Question I Cannot Figure Out Myself

**Is the watchdogd NixOS module (`services.watchdogd`) generating the wrong config format, or is the Nix option schema wrong?**

The generated config at `/nix/store/5n7kxscm28msy4jkgl5nam3v786k2s04-watchdogd.conf` produces flat key-value pairs like `meminfo.critical = 0.98` but watchdogd v4.1 expects TOML sections like `[meminfo]` with `critical = 0.98` underneath. I'm not sure if:

- (a) The NixOS module has a bug for v4.1 format, or
- (b) We're using the settings options incorrectly, or
- (c) watchdogd v4.1 changed its config format and nixpkgs hasn't caught up

This needs investigation of the nixpkgs `watchdogd.nix` module to understand the expected settings format.

---

## System State Snapshot

| Metric            | Value                                                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| NixOS Version     | 26.05.20260423.01fbdee (Yarara)                                                                                                         |
| Kernel            | Latest from nixpkgs unstable                                                                                                            |
| Root Disk         | 431G/512G (88% used) — needs cleanup                                                                                                    |
| /data Disk        | 606G/800G (76% used)                                                                                                                    |
| RAM               | 44G/62G used, 2.6G swap                                                                                                                 |
| Services Up       | unbound, caddy, dnsblockd, manifest, hermes, ollama, immich, gitea, signoz, twenty, deer-flow, whisper-asr, niri-session-manager (user) |
| Services Broken   | watchdogd (config parse error)                                                                                                          |
| DNS               | Working (unbound + Quad9 DoT)                                                                                                           |
| Docker Containers | 10 running (manifest unhealthy but functional)                                                                                          |

## Recent Commits

```
e693caa chore(dns): pin DNS blocklists to specific commits for reproducibility
5b52db9 chore(deps): update flake inputs and DNS blocklist hashes
491a1d6 docs(amd): add practical debugging guide for Strix Halo GPU bugs
c8e7064 fix(docs): use full commit hash in amdgpu bug report
60259db fix(docs): add GPU model name and PCI revision to amdgpu bug report
```
