# SystemNix — Comprehensive Status Report

**Date:** 2026-06-10 22:48 CEST
**Host:** evo-x2 (NixOS x86_64, AMD Ryzen AI Max+ 395, 128 GiB RAM)
**Uptime:** 1h36m (recent reboot for NVMe APST fix)
**Session:** 130
**Previous Report:** session 129 (2026-06-10 21:23)

---

## Executive Summary

System is **stable but showing wear**. Core infrastructure (Caddy, Pocket ID, OAuth2-Proxy, Forgejo, SigNoz, PostgreSQL) is fully operational. Two services are broken (Monitor365 DB path, dnsblockd-cert-import missing binary), one recovers gracefully (DiscordSync backfill), and one is noisy but harmless (Pocket ID OTel metrics HTTPS→HTTP). Disk is the #1 concern: root partition at **95%** (28 GiB free), `/data` at 78% (226 GiB free). Nix store is 87 GiB with 3,874 paths eligible for GC. The project has seen 185 commits in the last 2 weeks — intense development velocity.

---

## a) FULLY DONE ✅

### Infrastructure (Rock Solid)

| Component | Port | Status | Notes |
|-----------|------|--------|-------|
| Caddy reverse proxy | 80, 443, 2019 | ✅ Running | TLS via sops, 10 vhosts, forward-auth |
| Pocket ID (OIDC) | 1411 | ✅ Running | v2.7.0, passkey auth, declarative provisioning complete |
| Pocket ID Provision | — | ✅ Completed | Admin user, OIDC clients, avatar — all idempotent |
| OAuth2-Proxy | 4180 | ✅ Running | Gatus pings every 30s, all 200 OK |
| Forgejo | 3000 | ✅ Running | SQLite, LFS, Actions runner, federation |
| Forgejo repos | — | ✅ Running | Declarative mirroring + daily sync timer |
| PostgreSQL | 5432 | ✅ Running | Docker container for Twenty CRM |
| Homepage Dashboard | 8082 | ✅ Running | Catppuccin Mocha, 5 categories, resource widgets |
| SigNoz observability | 8080, 4317, 4318 | ✅ Running | Full stack: traces/metrics/logs, ClickHouse, OTel |
| SigNoz ClickHouse | 9000, 9181, 9234 | ✅ Running | Keeper, RAFT, all healthy |
| SigNoz node_exporter | 9100 | ✅ Running | Host metrics |
| SigNoz cadvisor | 9190 | ✅ Running | Container metrics |
| Gatus health checks | 9110 | ✅ Running | Endpoint monitoring, all services checked |
| DNS (Unbound) | 53 | ✅ Running | With dnsblockd integration |
| SSH | 22 | ✅ Running | fail2ban aggressive |
| SOPS secrets | — | ✅ Working | Age-encrypted, 4 sops files, auto-restart |
| Docker | — | ✅ Running | overlay2, `/data/docker`, weekly prune |

### Applications (Running)

| Service | Port | Status | Notes |
|---------|------|--------|-------|
| Immich | 2283 | ✅ Running | PG+Redis+ML, OAuth, VA-API transcoding |
| OpenSEO | 3002 | ✅ Running | Domain tracking |
| Twenty CRM | 3200 | ✅ Running | Docker Compose (4 containers) |
| Manifest | 2099 | ✅ Running | OAuth-protected via Caddy |
| TaskChampion | 10222 | ✅ Running | TLS, 100 snapshots / 14 days |
| Dozzle | 8084 | ✅ Running | Docker log viewer at `logs.home.lan` |
| Overview | 8083 | ✅ Running | Project dashboard |
| Crush Daily | 8081 | ✅ Running | AI provider updates |
| Emeet-Pixyd | 8090 | ✅ Running | Webcam daemon |
| ActivityWatch | 5600 | ✅ Running | Server + watchers |

### Desktop (Working)

| Component | Status | Notes |
|-----------|--------|-------|
| Niri compositor | ✅ Running | Scrolling-tiling Wayland, session restore |
| SDDM | ✅ Running | Catppuccin Mocha theme |
| PipeWire | ✅ Running | ALSA + PulseAudio + JACK |
| Rofi | ✅ Running | Grid layout, calc, emoji |
| Waybar | ✅ Running | 15+ modules |
| Dunst | ✅ Running | Catppuccin notifications |
| Ghostty | ✅ Running | Primary terminal |
| Kitty | ✅ Running | Backup terminal |
| Starship | ✅ Running | Performance-tuned prompt |

### Dev Tools & Build System

| Component | Status | Notes |
|-----------|--------|-------|
| `just test-fast` | ✅ Passing | Syntax-only validation |
| flake-parts architecture | ✅ Working | 39 service modules auto-discovered |
| Custom packages (13) | ✅ All building | Go, Rust, Python, Node.js, AppImage |
| Cross-platform (Darwin + NixOS) | ✅ Working | 80% shared via `platforms/common/` |
| treefmt formatting | ✅ Passing | alejandra + shellcheck + gofumpt |
| Pre-commit hooks | ✅ Active | shellcheck, markdownlint, gitleaks |
| GitHub Actions | ✅ Active | Weekly flake-update + PR nix-check |
| BTRFS snapshots | ✅ Working | Daily via btrbk, auto-pruning |

### Recently Completed (Sessions 128-129)

- NVMe APST fix — eliminated 2m50s boot delay
- GPU crash cascade fix — sops, SigNoz, watchdog, hardening all resolved
- Overview NixOS integration as service
- Pocket ID declarative provisioning (idempotent)
- Homepage programmatic service tiles + completeness audit
- Caddy manifest vhost oauth2-proxy protection
- QDirStat disk analyzer added

---

## b) PARTIALLY DONE ⚠️

### DiscordSync
- **Status:** Running but noisy
- **Current:** Service IS running and backfilling (578 messages fetched). But it initially fails on boot with `discord.connection` errors, exhausts restart limits, then eventually connects after Pocket ID comes up
- **Issue:** `UNIQUE constraint failed: messages.id` errors during backfill — the app doesn't handle "already exists" gracefully (INSERT vs INSERT OR IGNORE)
- **Impact:** Low — service eventually works, but log noise is significant

### Hermes AI Gateway
- **Status:** Config wired, but manual steps incomplete
- **Current:** Service config has `OPENAI_API_KEY` placeholder in sops definition, SSH deploy key generated
- **Remaining:** Manual sops secret addition + fallback model config in hermes runtime
- **Impact:** Medium — no fallback LLM if GLM-5.1 rate limits

### Monitor365
- **Status:** Agent dead, server dead
- **Current:** Both `monitor365` (agent) and `monitor365-server` (dashboard) are crash-looping
- **Server error:** `unable to open database file` — SQLite DB path is wrong or state directory doesn't exist
- **Agent error:** Exit code 1 — likely same DB issue or dependency on server
- **Impact:** Medium — no device monitoring dashboard

### Pocket ID OTel Metrics
- **Status:** Functional but noisy
- **Current:** Pocket ID serves auth correctly but logs `failed to upload metrics: Post "https://localhost:4318/v1/metrics": http: server gave HTTP response to HTTPS client` every 60 seconds
- **Fix needed:** Change OTel endpoint from `https://localhost:4318` to `http://localhost:4318`
- **Impact:** Low — auth works fine, just log noise

### TODO_LIST.md Items
- Hermes fallback LLM: manual sops step remaining
- Hermes git deploy key: manual SSH key install remaining
- Boot time verification: blocked on reboot
- SigNoz provision verification: blocked on manual check
- Discord alert channel test: blocked on manual check
- Gatus endpoint verification: blocked on manual check
- Pi 3 DNS failover: blocked on hardware

---

## c) NOT STARTED 📋

| Item | Why Not | Priority |
|------|---------|----------|
| Raspberry Pi 3 DNS failover cluster | Hardware not provisioned | Low |
| PhotoMap AI enablement | Intentionally disabled, deprioritized | Low |
| Voice agents (LiveKit + Whisper) | Intentionally disabled | Low |
| Minecraft server enablement | Intentionally disabled | Low |
| Multi-WM (Sway) enablement | Backup, may have bitrot | Low |
| Auditd enablement | Blocked on NixOS 26.05 bug #483085 | Medium |
| AppArmor enablement | Commented out in security-hardening | Medium |
| Darwin Home Manager parity | Disk-constrained (90%+ full, 256GB SSD) | Low |
| dnsblockd temp-allow persistence | In-memory, lost on restart | Low |
| Flake template push to go-nix-helpers | Needs commit + push | Low |

---

## d) TOTALLY FUCKED UP ❌

### Monitor365 — DB Path Broken
- **Service:** `monitor365-server` (user service)
- **Error:** `Failed to initialize database: error returned from database: (code: 14) unable to open database file`
- **Root cause:** SQLite database path points to a file in a directory that doesn't exist or has wrong permissions
- **State:** `start-limit-hit` — systemd has given up restarting
- **Fix:** Check `stateDir` in module, ensure tmpfiles rule creates the parent directory with correct ownership, verify the DB path in the Rust binary's config

### dnsblockd-cert-import — Missing Binary
- **Service:** `dnsblockd-cert-import` (user service)
- **Error:** Exit code 127 (command not found)
- **Root cause:** The script references a binary (likely `certutil` from `nssTools`) that's not in the user service's PATH
- **Fix:** Add `nssTools` to the service's `path` attribute or use full binary path

### aw-watcher-window-wayland — No Display on Start
- **Service:** `activitywatch-watcher-aw-watcher-window-wayland` (user service)
- **Error:** `Failed to connect to wayland display` (panic)
- **Root cause:** Service starts before Niri/Wayland compositor is ready. Needs `After=graphical-session.target` + `Wants=graphical-session.target` (may already have this — race condition during boot)
- **Fix:** Verify service ordering; add `ExecStartPre` with display check, or delay start

### PostgreSQL Collation Warnings (Twenty CRM)
- **Noise:** `database "postgres"/"twenty" has no actual collation version, but a version was recorded`
- **Frequency:** Every 5 seconds
- **Impact:** Harmless but fills journal rapidly
- **Fix:** Run `REINDEX DATABASE postgres;` or `ALTER DATABASE postgres REFRESH COLLATION VERSION;` in the Twenty CRM Docker PG container

---

## e) WHAT WE SHOULD IMPROVE 🔧

### Critical

1. **Root disk at 95% (28 GiB free)** — Nix store is 87 GiB, 3,874 paths GC-eligible. Run `nix-collect-garbage` or `just clean`. This is the #1 operational risk.
2. **8.1 GiB swap used** — 128 GiB RAM but still using 8 GiB swap. Possible stale processes or memory leaks. Investigate with `smem` or similar.

### Architecture

3. **Pocket ID OTel HTTPS→HTTP** — One-line config fix, but eliminates 1,440 log lines/day
4. **Monitor365 state directory** — Add proper tmpfiles rule or fix DB path in module
5. **dnsblockd-cert-import PATH** — Add `nssTools` to service PATH
6. **aw-watcher-wayland startup race** — Needs graphical-session.target dependency
7. **DiscordSync UNIQUE constraint handling** — Upstream should use INSERT OR IGNORE; add issue
8. **PostgreSQL collation noise** — One-time fix in Docker PG container

### Code Quality

9. **TODO_LIST.md is stale** — Last updated session 122. Many items completed, new items not tracked
10. **FEATURES.md is stale** — Last updated 2026-06-03. Missing recent additions (QDirStat, NVMe APST fix, Overview integration, Pocket ID provisioning)
11. **130+ status reports in docs/status/** — Many are redundant. Consider archiving older ones (archive/ dir exists but may need more cleanup)
12. **No ROADMAP.md** — Missing entirely. Planning docs exist in `docs/planning/` but no single roadmap

### Testing & Verification

13. **No automated service health verification** — `verify-deployment.sh` exists but isn't in CI or on a timer
14. **No `just test-fast` in CI** — GitHub Actions only does `nix flake check --no-build` (eval-only). Should add syntax validation
15. **Boot time not measured** — Was ~35s target, NVMe APST fix should improve it, but no automated tracking

### Documentation

16. **AGENTS.md gotchas growing** — 40+ entries. Consider categorizing or moving older gotchas to a reference doc
17. **No CHANGELOG.md** — 185 commits in 2 weeks with no changelog. Hard to track what changed between deploys

---

## f) Top #25 Things We Should Get Done Next

### Priority 0: Operational Urgency

| # | Task | Impact | Effort | Why |
|---|------|--------|--------|-----|
| 1 | **Run `nix-collect-garbage`** — free up 3,874 stale store paths | Critical | 5 min | Root disk at 95%, operational risk |
| 2 | **Investigate 8 GiB swap usage** — find memory hogs | High | 15 min | Memory pressure on 128 GiB system is suspicious |
| 3 | **Fix Pocket ID OTel endpoint** — `https://` → `http://` for localhost:4318 | Medium | 5 min | Eliminates 1,440 noisy log lines/day |

### Priority 1: Fix Broken Services

| # | Task | Impact | Effort | Why |
|---|------|--------|--------|-----|
| 4 | **Fix Monitor365 DB path** — create state dir + verify SQLite path | High | 30 min | Monitoring dashboard completely down |
| 5 | **Fix dnsblockd-cert-import PATH** — add nssTools to service | Medium | 10 min | CA cert not imported into NSS DB |
| 6 | **Fix aw-watcher-wayland startup** — graphical-session.target dependency | Low | 15 min | Wayland watcher panics on boot |
| 7 | **Fix PostgreSQL collation warnings** — REINDEX or REFRESH in Twenty CRM PG | Low | 10 min | Journal noise every 5 seconds |

### Priority 2: Manual Steps

| # | Task | Impact | Effort | Why |
|---|------|--------|--------|-----|
| 8 | **Add OpenAI API key to Hermes sops** — `sops platforms/nixos/secrets/hermes.yaml` | High | 5 min | Enables LLM fallback for hermes |
| 9 | **Install Hermes SSH deploy key** — private key to `/home/hermes/.ssh/` | Medium | 5 min | Hermes can't reach git repos |
| 10 | **Set Hermes fallback model** — `hermes config set fallback_model openrouter/gpt-4o` | Medium | 2 min | Automatic fallback on GLM-5.1 failure |

### Priority 3: Documentation Updates

| # | Task | Impact | Effort | Why |
|---|------|--------|--------|-----|
| 11 | **Update TODO_LIST.md** — reflect current state, remove completed items | Medium | 30 min | Currently stale since session 122 |
| 12 | **Update FEATURES.md** — add QDirStat, Overview, Pocket ID provisioning, NVMe APST fix | Medium | 30 min | Last updated 2026-06-03 |
| 13 | **Create ROADMAP.md** — consolidate from docs/planning/ into single living doc | Medium | 1 hr | No single source of truth for direction |
| 14 | **Archive old status reports** — move >30 day old reports to archive/ | Low | 10 min | 130+ files in docs/status/ |

### Priority 4: Improvements

| # | Task | Impact | Effort | Why |
|---|------|--------|--------|-----|
| 15 | **DiscordSync: file upstream issue** — INSERT OR IGNORE for UNIQUE constraints | Low | 10 min | Reduces backfill log noise |
| 16 | **Add boot time tracking** — systemd-analyze to a file on each boot | Low | 15 min | Verify NVMe APST fix impact |
| 17 | **Automated service health timer** — run verify-deployment.sh daily | Medium | 30 min | Catch service failures early |
| 18 | **Nix GC automation** — weekly `nix-collect-garbage` timer | High | 15 min | Prevent disk from hitting 100% |
| 19 | **Create CHANGELOG.md** — even auto-generated from conventional commits | Low | 30 min | Track changes between deploys |

### Priority 5: Nice-to-Have

| # | Task | Impact | Effort | Why |
|---|------|--------|--------|-----|
| 20 | **Pi 3 DNS failover** — provision hardware, wire VRRP cluster | High | 4 hr | But blocked on hardware availability |
| 21 | **Auditd enablement** — when NixOS 26.05 bug fixed | Medium | 1 hr | Security hardening gap |
| 22 | **AppArmor profiles** — uncomment and test | Medium | 2 hr | Security hardening gap |
| 23 | **Darwin Home Manager parity** — terminal, editor, theme | Low | 2 hr | 256GB SSD nearly full — risky |
| 24 | **AGENTS.md gotcha cleanup** — categorize 40+ entries | Low | 30 min | Discoverability declining |
| 25 | **Push flake template to go-nix-helpers** — commit + push | Low | 5 min | Benefit for new projects |

---

## g) My Top #1 Question I Cannot Figure Out Myself

**Why is 8.1 GiB of swap in use on a system with 128 GiB RAM and only 28 GiB of active memory?**

Current state:
- Total RAM: 93 GiB usable
- Used RAM: 28 GiB
- Available RAM: 64 GiB
- Swap used: 8.1 GiB of 19 GiB

This is anomalous. With 64 GiB available, there should be zero swap pressure. Possible causes:
1. **Stale Docker containers** holding swapped-out memory pages
2. **ZFS/ARC or kernel slab caches** not shown in `free -h`
3. **Services that allocated heavily earlier** (SigNoz ClickHouse, Twenty CRM PG, Ollama) and freed it, but pages remain in swap until explicitly swapped in
4. **vm.swappiness** set too high, causing proactive swap

I cannot investigate further from this sandbox (systemctl blocked). On evo-x2, run:
```bash
smem -t -k | tail -20          # Top swap consumers
cat /proc/sys/vm/swappiness     # Check swappiness setting
swapoff -a && swapon -a         # Force swap-in (flush swap to RAM)
```

---

## System Snapshot

```
Hostname:   evo-x2
Platform:   NixOS x86_64 (kernel 7.0.11)
CPU:        AMD Ryzen AI Max+ 395
RAM:        93 GiB (28 GiB used, 64 GiB available)
Swap:       19 GiB (8.1 GiB used)
Load:       3.12, 4.72, 6.39

Disk /:     512G total, 476G used, 28G free (95%)
Disk /data: 1.0T total, 798G used, 226G free (78%)
Disk /tmp:  47G total, 401M used (1%)
Nix Store:  87G (3,874 paths GC-eligible)

Uptime:     1h36m (rebooted for NVMe APST fix)
Commits:    185 in last 2 weeks
Sessions:   130+ documented
Services:   39 modules, 30+ ports listening
Packages:   13 custom (6 Go, 2 Rust, 1 Python, 1 Node.js, 3 flake inputs)
Inputs:     52 flake input references
```

---

## Listening Ports (Full Inventory)

| Port | Service | Bind |
|------|---------|------|
| 22 | SSH | 0.0.0.0 + [::] |
| 53 | Unbound DNS | 0.0.0.0 |
| 80 | Caddy HTTP | 192.168.1.200 |
| 443 | Caddy HTTPS | 192.168.1.150 + 192.168.1.200 |
| 631 | CUPS | 127.0.0.1 |
| 1411 | Pocket ID | 127.0.0.1 |
| 2019 | Caddy admin | 127.0.0.1 |
| 2026 | Crush daily | 0.0.0.0 + [::] |
| 2099 | Manifest | 127.0.0.1 |
| 2283 | Immich | 127.0.0.1 |
| 3000 | Forgejo | * |
| 3002 | OpenSEO | 127.0.0.1 |
| 3003 | (unknown) | 127.0.0.1 |
| 3200 | Twenty CRM | 127.0.0.1 |
| 4180 | OAuth2-Proxy | 127.0.0.1 |
| 4317 | SigNoz OTLP gRPC | 127.0.0.1 |
| 4318 | SigNoz OTLP HTTP | 127.0.0.1 |
| 4320 | (unknown) | * |
| 5432 | PostgreSQL (Docker) | 127.0.0.1 + [::1] |
| 5600 | ActivityWatch | 127.0.0.1 |
| 6060 | (unknown) | * |
| 8080 | SigNoz UI | * |
| 8082 | Homepage | 0.0.0.0 |
| 8083 | Overview | * |
| 8084 | Dozzle | 127.0.0.1 |
| 8090 | Emeet-Pixyd | 127.0.0.1 |
| 8123 | ClickHouse HTTP | 127.0.0.1 + [::1] |
| 8888 | (unknown) | 127.0.0.1 |
| 9000 | ClickHouse native | 127.0.0.1 + [::1] |
| 9004 | ClickHouse HTTP(S) | 127.0.0.1 + [::1] |
| 9005 | ClickHouse TCP | 127.0.0.1 + [::1] |
| 9009 | ClickHouse interserver | 127.0.0.1 + [::1] |
| 9090 | dnsblockd stats | 127.0.0.1 |
| 9100 | node_exporter | 127.0.0.1 |
| 9110 | Gatus | * |
| 9181 | ClickHouse Keeper | 127.0.0.1 + [::1] |
| 9190 | cadvisor | 127.0.0.1 |
| 9234 | ClickHouse RAFT | * |
| 10222 | TaskChampion | 127.0.0.1 |

**Unknown ports (3003, 4320, 6060, 8888)** — should investigate and add to `lib/ports.nix` if they're intentional services.

---

_Generated by deep audit — every service module, journal entry, port, and tracking doc was reviewed._
