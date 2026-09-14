# Session 13: Post-Reboot Service Recovery & Systemic Hardening Fix

**Date:** 2026-05-01 09:45 — 15:54 CEST
**Host:** evo-x2 (x86_64-linux, AMD Ryzen AI Max+ 395, 128GB)
**Uptime:** 6h09m at time of writing
**Branch:** master (827cfac)

---

## a) FULLY DONE ✅

### Service Recovery (6 crashed services → 0)

| Service         | Root Cause                                                                                                                                                                                                                   | Fix                                                                                       |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Caddy**       | `bind` directive inside `servers {}` (invalid Caddy syntax) + `WatchdogSec=30` killing process during certmagic TLS init                                                                                                     | Config already fixed pre-reboot; removed `WatchdogSec` entirely                           |
| **SigNoz**      | `ProtectSystem=strict` from hardening lib blocked mmap writes to `/var/lib/signoz/queries.active` → panic                                                                                                                    | Changed to `ProtectSystem=full`; added `--max-time --retry` to ExecStartPost health check |
| **Authelia**    | ExecStartPost `curl` had no timeout → hung forever → systemd 90s timeout killed service                                                                                                                                      | Added `--max-time 3 --retry 30 --retry-delay 1 --retry-all-errors`                        |
| **Photomap**    | Podman blocked by hardening: `ProtectHome=true` → can't read containers.conf, `RestrictNamespaces=true` → can't clone namespaces, `NoNewPrivileges=true` → can't write uid_map, `CapabilityBoundingSet=""` → no capabilities | Removed hardening entirely — podman containers provide their own isolation                |
| **Whisper ASR** | Docker image tag `beecave/insanely-fast-whisper-rocm:1.0.0` doesn't exist on Docker Hub                                                                                                                                      | Changed to `:main`                                                                        |
| **Twenty CRM**  | Image `twentycrm/twenty:0.16.2` removed from Docker Hub (project jumped to v2.x)                                                                                                                                             | Changed to `:latest` (already cached locally)                                             |

### Systemic Fixes

| Fix                                                                   | Files                                           | Impact                                                                            |
| --------------------------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------- |
| **StartLimitIntervalSec** moved from `[Service]` to `[Unit]`          | 14 service files across modules/ and platforms/ | Prevents systemd config warnings; correct semantics                               |
| **lib/systemd.nix** `RestrictNamespaces` made configurable            | 1 file                                          | Was hardcoded `true`, blocking podman/container services                          |
| **lib/systemd.nix** `NoNewPrivileges` made configurable               | 1 file                                          | Was hardcoded `true`, blocking podman user namespace setup                        |
| **lib/systemd.nix** default `ProtectSystem` changed `strict` → `full` | 1 file                                          | Prevents future read-only filesystem crashes for services that need `/var` writes |
| **Ollama** `DynamicUser` disabled, runs as `lars:users`               | ai-stack.nix                                    | Dynamic UID couldn't write to `/data/ai/models/ollama` owned by lars              |
| **Home Manager** Jan data symlink mkdir                               | home.nix                                        | `~/.config/Jan/` parent dir didn't exist at first boot                            |

### Final State: 19/19 services running, 0 failures

```
✅ caddy              ✅ authelia-main      ✅ signoz
✅ signoz-collector    ✅ signoz-provision   ✅ ollama
✅ gitea               ✅ homepage-dashboard  ✅ immich-server
✅ immich-ml           ✅ hermes              ✅ taskchampion
✅ comfyui             ✅ cadvisor            ✅ minecraft-server
✅ twenty              ✅ whisper-asr         ✅ dnsblockd
✅ podman-photomap
```

---

## b) PARTIALLY DONE ⚠️

- **Gitea GitHub mirror sync**: Auth token expired. Mirror repos fail to pull from GitHub. Needs manual token update in Gitea web UI — not a NixOS config issue.
- **SigNoz JWT secret**: Log shows `🚨 CRITICAL SECURITY ISSUE: No JWT secret key specified!` — `SIGNOZ_TOKENIZER_JWT_SECRET` env var not set. Service still runs but sessions are insecure.

---

## c) NOT STARTED 📋

1. **Status dashboard integration**: Homepage dashboard needs updating for new/changed services
2. **SigNoz alert rules**: Provisioning ran but may need verification that dashboards/rules are correct
3. **Twenty CRM v2.x migration**: Major version jump (0.16.2 → latest). Database was auto-migrated but custom configs/CRMs should be verified
4. **Disk usage audit**: Root 88%, /data 86% — getting tight. Should audit large files/dirs
5. **Swap usage**: 11GB/41GB — higher than expected. Memory pressure from Docker containers?

---

## d) TOTALLY FUCKED UP 💥

Nothing currently broken. The session started with 6 services in crash loops (800+ restarts for photomap, 700+ for twenty, 600+ for whisper) and recovered all of them.

### Lessons Learned / Mistakes Made:

1. **First switch was premature** — I should have stopped all crash-looping services before switching. Systemd was overwhelmed from 800+ restarts, causing `systemctl` timeouts.
2. **Harden lib was a footgun** — `ProtectSystem=strict` default caused signoz crash. Should have been `full` from the start. Fixed now.
3. **Harden lib had hardcoded values** — `RestrictNamespaces` and `NoNewPrivileges` were hardcoded `true`, not configurable params. Had to fix the lib interface mid-recovery.
4. **Multiple round trips** — Took 7 `just switch` cycles to fix everything. Could have been fewer if I'd audited the harden lib and all systemd configs upfront before the first switch.

---

## e) WHAT WE SHOULD IMPROVE 📈

### Architecture

1. **`lib/systemd.nix` should be a proper NixOS module** — currently just a function returning an attrset. Should have `mkHarden` that integrates with `lib.mkOption` for better type safety and conflict detection.
2. **Service health checks should use a shared helper** — Every ExecStartPost health check (authelia, signoz, caddy) independently reinvents `curl -sf --max-time --retry ...`. Should be a reusable function.
3. **Docker image tags should be pinned by digest** — Whisper and Twenty images use floating tags. Should pin by `@sha256:...` for reproducibility.
4. **Podman services should have a dedicated hardening profile** — Instead of removing all hardening (photomap) or manually disabling each option, create `lib/systemd/podman.nix` with podman-compatible defaults.
5. **Secrets for SigNoz JWT** should be in sops — Currently missing entirely.

### Operational

6. **Pre-switch validation** — Run `nix eval` to check that all hardening overrides actually propagate before switching.
7. **Monitoring for crash loops** — SigNoz should alert on `StartLimitIntervalSec` hit or service restart count > 5 in 5 minutes.
8. **Disk cleanup automation** — 88% root usage is concerning. Should add a timer for nix-store GC and Docker image pruning.

---

## f) Top 25 Next Actions

Sorted by (impact × urgency) / effort:

| #  | Action                                                                      | Impact | Effort  | Est.  |
| -- | --------------------------------------------------------------------------- | ------ | ------- | ----- |
| 1  | **Pin Docker images by digest** (whisper, twenty, photomap)                 | High   | Low     | 15min |
| 2  | **Add SIGNOZ_TOKENIZER_JWT_SECRET** via sops                                | High   | Low     | 10min |
| 3  | **Create `lib/systemd/podman.nix`** hardening profile                       | Medium | Low     | 10min |
| 4  | **Create `lib/systemd/health-check.nix`** shared curl helper                | Medium | Low     | 10min |
| 5  | **Update Gitea GitHub mirror token**                                        | High   | Trivial | 2min  |
| 6  | **Nix GC + Docker image prune timer**                                       | Medium | Low     | 15min |
| 7  | **Audit disk usage** — find large dirs/files                                | Medium | Low     | 10min |
| 8  | **Verify Twenty CRM v2.x data integrity**                                   | Medium | Medium  | 20min |
| 9  | **Verify SigNoz dashboards/alerts** provisioned correctly                   | Medium | Low     | 10min |
| 10 | **Add signoz alert for service crash loops**                                | Medium | Medium  | 15min |
| 11 | **Update homepage dashboard** for new services                              | Low    | Low     | 10min |
| 12 | **Test Caddy TLS cert renewal**                                             | Medium | Low     | 5min  |
| 13 | **Verify whisper-asr GPU passthrough** working                              | Medium | Low     | 5min  |
| 14 | **Add backup verification** for twenty DB                                   | Medium | Low     | 5min  |
| 15 | **Review swap usage** — 11GB seems high                                     | Low    | Low     | 10min |
| 16 | **Add systemd watchdog** for services that support sd_notify (caddy, gitea) | Medium | Medium  | 15min |
| 17 | **Consolidate StartLimitBurst/IntervalSec** into serviceDefaults            | Low    | Low     | 10min |
| 18 | **Add emeet-pixyd** to signoz-collector scrape config                       | Low    | Trivial | 5min  |
| 19 | **Create integration test** for hardening lib                               | High   | High    | 30min |
| 20 | **Niri session restore test**                                               | Medium | Low     | 5min  |
| 21 | **Audit all sops secrets** — check for rotation needs                       | Medium | Medium  | 20min |
| 22 | **Add `services.*.enable` guards** for all services                         | Low    | Low     | 15min |
| 23 | **Document hardening profiles** in AGENTS.md                                | Low    | Low     | 10min |
| 24 | **BTRFS scrub timer** for data integrity                                    | Medium | Low     | 10min |
| 25 | **Consider podman rootless** migration from Docker                          | High   | High    | 60min |

---

## g) Top #1 Question I Cannot Figure Out Myself

**Why does Caddy's `sd_notify` not send `WATCHDOG=1` within any timeout?**

Caddy is built as `Type=notify` by NixOS and is documented to support sd_notify. Yet it never sends the watchdog ping, causing systemd to SIGABRT it after any `WatchdogSec` value (tested 30s and 120s). The crash trace shows it dying in `certmagic.(*Cache).maintainAssets` — the TLS cert maintenance goroutine. This suggests Caddy is getting stuck during TLS certificate operations and never reaching the point where it sends watchdog pings. Is this a bug in the NixOS Caddy package (2.11.2), a config issue with how `auto_https off` interacts with cert maintenance, or a Caddy upstream bug?

**Impact:** Without WatchdogSec, Caddy crashes go undetected by systemd until the restart limit is hit.

---

## Commits This Session

| SHA       | Message                                                                                    |
| --------- | ------------------------------------------------------------------------------------------ |
| `4a2eab1` | fix(services): post-reboot recovery — fix 6 crashed services and systemic hardening issues |
| `827cfac` | refactor(systemd): change default ProtectSystem to full, fix niri user service limits      |

## Files Changed This Session

```
lib/systemd.nix                          |  8 +++---
modules/nixos/services/ai-stack.nix      |  7 +++--
modules/nixos/services/authelia.nix      |  8 ++++--
modules/nixos/services/caddy.nix         |  7 +++--
modules/nixos/services/comfyui.nix       |  9 +----
modules/nixos/services/gitea-repos.nix   |  2 -
modules/nixos/services/gitea.nix         |  6 +++-
modules/nixos/services/homepage.nix      |  2 -
modules/nixos/services/immich.nix        |  4 --
modules/nixos/services/minecraft.nix     |  2 -
modules/nixos/services/photomap.nix      |  5 +--
modules/nixos/services/signoz.nix        | 20 +++++-----
modules/nixos/services/taskchampion.nix  |  8 ++++-
modules/nixos/services/twenty.nix        |  4 +--
modules/nixos/services/voice-agents.nix  |  8 +----
platforms/nixos/modules/dns-blocker.nix  |  6 +++-
platforms/nixos/programs/niri-wrapped.nix| 12 +++---
platforms/nixos/users/home.nix           |  7 +++--
```
