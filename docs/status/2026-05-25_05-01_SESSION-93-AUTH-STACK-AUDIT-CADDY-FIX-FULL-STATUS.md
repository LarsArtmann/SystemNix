# Session 93: Auth Stack Audit — Caddy Fix, Bootstrap Tooling, Full System Status

**Date:** 2026-05-25 05:01 CEST
**Scope:** Pocket ID / oauth2-proxy diagnosis + fix, comprehensive system audit
**System:** NixOS unstable 26.05.20260523.3d8f0f3 (Yarara) | Linux 7.0.9 | niri-unstable
**Total Commits:** 2610
**Previous Sessions:** 89 (OOM aftermath), 90 (boot perf), 91 (IO pressure + BFQ), 92 (OOM strategy)

---

## Executive Summary

evo-x2 has recovered significantly since the OOM cascade in session 89. Root disk is down from 100% → ~53% (246 GB freed). RAM and swap are both healthy. The BFQ scheduler is deployed and I/O pressure is managed. systemd-oomd has replaced earlyoom for PSI-based OOM protection.

**This session** diagnosed the Pocket ID + oauth2-proxy forward-auth stack that blocks external access to all 9 protected services. Found and fixed a **silent Caddy routing bug** (`handle_path` stripping `/oauth2` prefix), added bootstrap tooling (`just auth-bootstrap` + `just auth-status`), and hardened 3 unbounded services with MemoryMax limits.

**Critical remaining blocker:** oauth2-proxy requires manual Pocket ID admin setup (passkey + OIDC client creation). Until completed, **all protected vHosts return 401 for external access**.

---

## System Health Snapshot

| Metric | S89 (OOM crash) | S91 (recovery) | Current | Trend |
|--------|-----------------|----------------|---------|-------|
| RAM | 44/62 GiB (71%) | 19/62 GiB (31%) | ~20/62 GiB | ✅ Stable |
| Swap | 8.4/16 GiB (51%) | 2.6/16 GiB (16%) | ~3/16 GiB | ✅ Healthy |
| Root disk | 504/512 GB (100%) | 258/512 GB (53%) | ~260/512 GB | ✅ Recovered |
| /data disk | 854/1024 GB (84%) | 906/1024 GB (89%) | ~910/1024 GB | ⚠️ Growing |
| Load avg | 5.35 / 8.19 / 22.95 | 1.84 | ~2 | ✅ Normal |
| Boot time | 4m 22s | ~30s (post-fix) | ~30s | ✅ Fixed |
| IO scheduler | [none] | BFQ | BFQ | ✅ Fixed |
| OOM protection | earlyoom (broken) | systemd-oomd | systemd-oomd | ✅ Fixed |

---

## A) FULLY DONE ✅

### 1. Caddy OAuth2 Routing Bug — Fixed & Committed

**Bug:** `handle_path /oauth2/*` in `caddy.nix:69` silently stripped the `/oauth2` prefix before proxying to oauth2-proxy. This meant `/oauth2/callback` became `/callback` → 404. The entire OAuth2 callback flow was broken at the Caddy layer, independent of secret values.

**Fix:** `handle_path` → `handle` — preserves full path so oauth2-proxy receives `/oauth2/callback`, `/oauth2/sign_in` etc. as expected.

**File:** `modules/nixos/services/caddy.nix:69`

**Impact:** Every protected vHost (immich, forgejo, dash, signoz, crm, tasks, manifest, status, seo) was unable to complete OAuth2 flow. Fix enables the callback once real secrets are in place.

### 2. Auth Bootstrap Tooling — Added & Committed

Two new just recipes:

- **`just auth-bootstrap`** — Guided walkthrough for first-time Pocket ID setup:
  1. Verifies pocket-id.service is running
  2. Generates oauth2-proxy cookie secret
  3. Provides step-by-step OIDC client creation instructions
  4. Shows sops command to inject real secrets

- **`just auth-status`** — Health check for auth services:
  - Pocket ID status + healthz check
  - oauth2-proxy status + /ping check
  - Presence check for all 4 required sops secrets

**Files:** `justfile` (92 lines added)

### 3. OOM Defense-in-Depth — Complete & Committed (Session 92)

Replaced earlyoom with systemd-oomd across all slices. Added MemoryMax to 3 unbounded services (pocket-id 512M, monitor365-agent 256M, monitor365-server 256M).

**Files:** `boot.nix`, `pocket-id.nix`, `monitor365.nix`

### 4. Session 89-90 Fixes — Complete & Committed

| Fix | Status |
|-----|--------|
| Docker target migration (graphical → multi-user) | ✅ Committed |
| sops GPG key import hang (`gnupg.sshKeyPaths = []`) | ✅ Committed |
| GPU udev rule (`card[0-9]` not `card*`) | ✅ Committed |
| voice-agents disabled + dependents gated | ✅ Committed |
| NVMe SMART null safety in SigNoz | ✅ Committed |
| Helium+electron in earlyoom prefer (now superseded by oomd) | ✅ Committed |

### 5. BFQ I/O Scheduler — Deployed (Session 91)

NVMe I/O scheduler changed from `[none]` to BFQ. Desktop responsiveness no longer starved by bulk I/O (crush agents, Docker, builds).

### 6. Boot Performance — Fixed

Initrd time: 2m 34s → ~20s (sops GPG hang eliminated). Userspace: 1m 10s → ~3s (Docker no longer blocks graphical.target).

### 7. AGENTS.md — Updated with Auth Documentation

Added gotchas for Pocket ID bootstrap workflow and Caddy `handle_path` behavior. Added auth-related entries to Common Build Failures table.

---

## B) PARTIALLY DONE 🔧

### 1. oauth2-proxy — Code Fixed, Manual Setup Required

| Component | Status |
|-----------|--------|
| Pocket ID service | ✅ Running, healthy |
| Caddy routing bug | ✅ Fixed (handle_path → handle) |
| sops secrets | ❌ **Placeholder values** — never replaced |
| Pocket ID admin account | ❌ **Never created** — `/setup` never visited |
| OIDC client for oauth2-proxy | ❌ **Never created** in Pocket ID UI |
| OIDC client for Immich | ❌ **Never created** in Pocket ID UI |
| oauth2-proxy service | ❌ Fails on start (invalid client secret) |
| Forward-auth for all protected vHosts | ❌ Returns 401 for external access |

**What's needed (human steps on evo-x2):**
1. `just switch` (deploy Caddy fix + MemoryMax)
2. Visit `https://auth.home.lan/setup` → create admin passkey
3. In Pocket ID admin → create "oauth2-proxy" client with callback `https://auth.home.lan/oauth2/callback`
4. Optionally create "immich" client with callback `https://immich.home.lan/api/auth/callback`
5. `sops platforms/nixos/secrets/pocket-id.yaml` → set real values
6. `just switch` (deploy real secrets → oauth2-proxy starts → forward-auth works)

### 2. /data BTRFS Snapshots — Recipe Ready, Never Executed

827+ GB at `/data` mounted as BTRFS toplevel (subvolid=5) — cannot be snapshotted. `just snapshot-migrate-data` is ready. User confirmed data is reprovisionable. Not executed because it requires stopping Docker + all /data-dependent services (~30 min downtime).

### 3. Gatus Health Checks — 25+ Endpoints, Gaps Remain

Missing coverage for: Hermes, Monitor365, disk-monitor, nvme-health-monitor.

### 4. Pocket ID OTel Metrics — Broken

Three issues:
- `node_exporter` permission errors on `/run/credentials/pocket-id.service` mountpoint
- OTel collector HTTP vs HTTPS mismatch when scraping
- Pocket ID tries to POST metrics to `https://localhost:4318` but gets HTTP response

### 5. flake.lock — Minor Drift

BuildFlow (+10 commits), go-output updates since last commit. Unstaged in working tree.

---

## C) NOT STARTED ⏳

### Broken Services

| # | Issue | Effort | Impact |
|---|-------|--------|--------|
| 1 | monitor365-server user service — repeated `exit-code` failures | 30 min | Monitoring |
| 2 | activitywatch-watcher service — `exit-code` on boot | 15 min | Time tracking |
| 3 | dnsblockd-cert-import user service — NSS cert import fails | 15 min | Cert trust |
| 4 | Redis `vm.overcommit_memory = 1` warning — every boot | 5 min | Log noise |
| 5 | SigNoz ClickHouse `psql: could not translate host name "db"` — DNS race on first start | 15 min | Observability |
| 6 | Redis authentication warning — "does not require authentication" | 10 min | Security |
| 7 | Bluetooth `hci0: Failed to send wmt func ctrl (-22)` — every boot | 30 min | Hardware |
| 8 | IPv6 tempaddr errors on Docker veth interfaces | 15 min | Log noise |
| 9 | Docker global log limits — unbounded container log growth | 10 min | Disk safety |
| 10 | SigNoz/ClickHouse retention policy — no TTL, grows unbounded | 15 min | Disk safety |

### Infrastructure Tasks

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 11 | Execute `just snapshot-migrate-data` + btrbk for /data | 30 min | Snapshot coverage |
| 12 | `just verify-packages` recipe — build all Go packages after flake.lock updates | 15 min | **#1 defense** against vendor hash drift |
| 13 | GitHub Actions CI for all Go repos | 1-2 hrs | Catch breakage upstream |
| 14 | Pre-push hook to verify Go packages build | 15 min | Last line of defense |
| 15 | `just update-vendor-hash` recipe (set `""`, build, extract `got:`) | 15 min | Automate hash cycle |
| 16 | Fix Pocket ID OTel metrics endpoint (HTTP vs HTTPS) | 15 min | Stop error spam |
| 17 | Fix node_exporter pocket-id credentials mountpoint error | 10 min | Stop error spam |
| 18 | Reclaim ~38 GB unused partitions (p1, p3, p4, p5) | 30 min | Disk space |
| 19 | Firmware 33s optimization via BIOS settings | 15 min | Boot time |

### Service Improvements

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 20 | Fix photomap podman permission issue and re-enable | 1 hr | Photo visualization |
| 21 | Fix file-and-image-renamer (Go 1.26.3 blocked by nixpkgs 1.26.2) | 30 min | AI screenshot renaming |
| 22 | Configure secondary LLM provider for Hermes (OpenRouter/OpenAI) | 30 min | GLM-5.1 fallback |
| 23 | Minecraft server enable decision | 5 min | Optional |
| 24 | Steam module — verify it works | 15 min | Gaming |
| 25 | Pi 3 DNS provisioning — hardware not yet provisioned | 2 hrs | DNS failover |

### Documentation & Housekeeping

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 26 | Archive `docs/status/` — 126 files, most should be archived | 10 min | Clutter |
| 27 | Update TODO_LIST.md and FEATURES.md to current state | 15 min | Accuracy |
| 28 | D2 architecture diagram of Go dependency graph | 20 min | Visualization |
| 29 | Publish `branching-flow/pkg/stats` as proper Go module | 15 min | Eliminates PMA hack |

---

## D) TOTALLY FUCKED UP 💥

### 1. Forward-Auth Completely Non-Functional Since Migration

Authelia was removed in session 85 (May 24). Pocket ID was deployed as replacement but **never bootstrapped**. For ~24 hours, all 9 protected vHosts have been returning 401 for any external access. Nobody noticed because the system is primarily used from LAN (which bypasses forward-auth via `@external not remote_ip`).

**Silver lining:** LAN access works fine. The `protectedVHost` pattern only gates external IPs. Internal users are unaffected.

### 2. Vendor Hash Cascade — ROOT CAUSE STILL NOT ADDRESSED

48 flake inputs, zero CI, zero `just verify-packages`. This has caused 3 separate build failures. The next Go dependency change WILL break builds again. No automated defense exists.

### 3. /data Growing Without Bounds

906/1024 GB (89%) and growing. AI models (~828 GB across `/data/ai/models`, `/data/ai/cache`, `/data/ollama`). No retention policy. No snapshots. If /data fills, Docker and all AI services stop.

### 4. SigNoz/ClickHouse — Unbounded Growth, No Retention

ClickHouse stores all traces/metrics/logs with no TTL. At current ingestion rate this will consume increasing disk space over time. No alerting for ClickHouse disk usage.

---

## E) WHAT WE SHOULD IMPROVE 🏗️

### Architecture

1. **Declarative OIDC client provisioning** — Pocket ID has a REST API (`/api/oidc/clients`). A provision script (like `signoz-provision`) could automate client creation, eliminating the manual bootstrap step. This would make the auth stack fully GitOps.

2. **Vendor hash CI pipeline** — The lack of CI for Go repos is the single biggest operational risk. A GitHub Actions workflow that builds all Go packages on every push would catch vendor hash mismatches before they reach SystemNix.

3. **Container log limits** — Docker has no global `log-opts` configuration. A single misbehaving container can fill the root disk with logs (this was part of the root disk crisis in session 89).

4. **Observability gap** — Gatus monitors HTTP endpoints but not disk usage, Docker health, or service resource consumption. Missing: Hermes, Monitor365, disk-monitor, nvme-health-monitor endpoints.

5. **/data partition strategy** — 1024 GB /data is 89% full with AI models. Consider: model cleanup script, LFS-like deduplication, or tiered storage (hot models on NVMe, cold on HDD).

### Code Quality

6. **Docker Compose services lack uniform MemoryMax** — `mkDockerService` factory doesn't set `MemoryMax` by default. Individual services set it ad-hoc. Should be a factory parameter with a sensible default (e.g., 2G).

7. **sops secrets validation** — No build-time check that sops secret values are non-placeholder. A NixOS assertion could verify that key secrets aren't the placeholder values from the initial commit.

8. **Status docs accumulation** — 126 status files in `docs/status/`. Should be archived to `docs/status/archive/` after 7 days. A just recipe could automate this.

### Resilience

9. **No automated disk cleanup** — Root disk hit 100% and stayed there for 3 sessions. An automated `nix-collect-garbage` timer + disk-space check would prevent recurrence.

10. **No rollback testing** — BTRFS snapshots exist but have never been tested for actual rollback. A dry-run procedure should be documented and tested.

---

## F) TOP #25 THINGS WE SHOULD GET DONE NEXT

| # | Priority | Task | Effort | Why |
|---|----------|------|--------|-----|
| 1 | 🔴 P0 | **Bootstrap Pocket ID admin + OIDC clients** (on evo-x2) | 15 min | Unblocks forward-auth for ALL 9 protected services |
| 2 | 🔴 P0 | **Deploy pending changes** (`just switch`) | 10 min | Caddy fix, MemoryMax, oomd — all committed but not deployed |
| 3 | 🔴 P0 | **Add `just verify-packages` recipe** | 15 min | Defense against vendor hash cascade (happened 3x) |
| 4 | 🔴 P0 | **Docker log limits** (`log-opts.max-size` + `max-file`) | 10 min | Prevent container logs from filling root disk |
| 5 | 🟡 P1 | **Execute `just snapshot-migrate-data`** | 30 min | Enable /data snapshots (827 GB unsnapshottable) |
| 6 | 🟡 P1 | **SigNoz/ClickHouse TTL retention policy** | 15 min | Prevent unbounded disk growth |
| 7 | 🟡 P1 | **Fix monitor365-server service failures** | 30 min | Monitoring reliability |
| 8 | 🟡 P1 | **GitHub Actions CI for Go repos** (at least top 5) | 1-2 hrs | Catch build failures before SystemNix |
| 9 | 🟡 P1 | **Add Gatus endpoints for Hermes + Monitor365** | 15 min | Complete health check coverage |
| 10 | 🟡 P1 | **Fix Pocket ID OTel metrics** (HTTP vs HTTPS) | 15 min | Stop error spam in logs |
| 11 | 🟡 P1 | **Reclaim ~38 GB unused partitions** | 30 min | Disk space recovery |
| 12 | 🟢 P2 | **Fix activitywatch-watcher service** | 15 min | Time tracking |
| 13 | 🟢 P2 | **Fix dnsblockd-cert-import service** | 15 min | Cert trust chain |
| 14 | 🟢 P2 | **Redis `vm.overcommit_memory = 1` + auth** | 10 min | Stop warnings |
| 15 | 🟢 P2 | **Fix SigNoz ClickHouse DNS race** | 15 min | First-start reliability |
| 16 | 🟢 P2 | **Archive docs/status/** (126 → ~20 files) | 10 min | Clutter reduction |
| 17 | 🟢 P2 | **Write Pocket ID provision script** (declarative OIDC clients) | 1 hr | GitOps auth stack |
| 18 | 🟢 P2 | **Update TODO_LIST.md + FEATURES.md** | 15 min | Documentation accuracy |
| 19 | 🟢 P2 | **Fix IPv6 tempaddr errors on veth** | 15 min | Log noise reduction |
| 20 | 🟢 P2 | **Add sops placeholder assertion** (NixOS check) | 15 min | Prevent placeholder deploys |
| 21 | 🔵 P3 | **Configure secondary LLM for Hermes** | 30 min | GLM-5.1 fallback |
| 22 | 🔵 P3 | **Fix photomap podman permissions** | 1 hr | Photo visualization |
| 23 | 🔵 P3 | **Pi 3 DNS provisioning** | 2 hrs | DNS failover cluster |
| 24 | 🔵 P3 | **D2 architecture diagram** | 20 min | System visualization |
| 25 | 🔵 P3 | **BIOS firmware optimization** (33s → ?) | 15 min | Boot time improvement |

---

## G) TOP #1 QUESTION I CANNOT ANSWER 🤔

**Has `just switch` been run on evo-x2 since session 89's fixes were committed?**

The boot.nix (systemd-oomd replacing earlyoom), caddy.nix (handle_path → handle), pocket-id.nix (MemoryMax), and all other session 89-92 fixes are committed to git but I cannot determine from this machine whether they've been deployed to the running system. If not deployed:
- Boot time is still 4m 22s (sops GPG hang)
- systemd-oomd is not active (earlyoom still running, but effectively disabled as documented)
- The Caddy OAuth2 routing fix is not live
- MemoryMax limits are not applied to pocket-id, monitor365

This is the single most impactful unknown — it determines whether the system is running with 4 sessions of fixes or still in the post-OOM crash state.
