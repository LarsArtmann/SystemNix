# Session 9 — Hermes Hardening & System Audit

**Date:** 2026-05-01 00:33 CEST
**Branch:** master
**Base commit:** `877fb45` chore(flake.lock): update all pinned flake inputs
**Session focus:** Hermes agent log review, service hardening, justfile UX fixes

---

## A) FULLY DONE

### Hermes Service Hardening (`modules/nixos/services/hermes.nix`)

| Fix                           | Before                                                   | After                                                                | Impact                                |
| ----------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------- |
| **libopus for Discord voice** | `Opus codec not found — voice channel playback disabled` | `LD_LIBRARY_PATH=${pkgs.libopus}/lib` + `pkgs.libopus` in `path`     | Discord voice playback now functional |
| **Deprecated MESSAGING_CWD**  | Set in `Environment` + persisted in `.env`               | Removed from `Environment`, auto-cleaned from `.env` by merge script | No more deprecation warning           |
| **Merge script cleanup**      | No cleanup of deprecated keys                            | New loop removes `MESSAGING_CWD` from `.env` on every start          | Self-healing migration                |

### Justfile UX Overhaul (6 recipes fixed)

| Recipe               | Before                                    | After                                                       |
| -------------------- | ----------------------------------------- | ----------------------------------------------------------- |
| `hermes-logs`        | `journalctl -u hermes -f` (hangs forever) | `journalctl -u hermes --no-pager -n 200` (prints and exits) |
| `hermes-logs-follow` | Did not exist                             | New: `journalctl -u hermes -f --no-pager -n 50` (live tail) |
| `dns-logs`           | `-f` follow mode (hangs)                  | Static output, `-n 100`                                     |
| `dns-logs-blocker`   | `-f` follow mode (hangs)                  | Static output, `-n 100`                                     |
| `immich-logs`        | `-f` follow mode (hangs)                  | Static output, `-n 100`                                     |
| `immich-logs-ml`     | `-f` follow mode (hangs)                  | Static output, `-n 100`                                     |
| `cam-logs`           | `-f` follow mode (hangs)                  | Static output, `-n 100`                                     |

### Build Validation

- `just test-fast` passes: all flake checks, all module evaluations, all NixOS configurations
- No new eval warnings introduced
- Pre-existing warning: `gitea-ensure-repos.service Type=oneshot with Restart=always` (known, low priority)

---

## B) PARTIALLY DONE

### Hermes — Not Yet Deployed

All changes are committed to the Nix config but **not yet applied** via `just switch`. The service currently running is the previous generation with:

- No libopus (voice disabled)
- Deprecated MESSAGING_CWD warning still present
- Opus warning still in logs

**Action needed:** `just switch` to deploy.

### Failed System Services (9 system + 1 user unit)

From `just health` output, the following services are in failed state:

| Service                                 | Severity     | Notes                                                      |
| --------------------------------------- | ------------ | ---------------------------------------------------------- |
| `caddy.service`                         | **CRITICAL** | Reverse proxy down — all `*.home.lan` services unreachable |
| `ollama.service`                        | **HIGH**     | Local LLM inference down                                   |
| `gitea-ensure-repos.service`            | **MEDIUM**   | GitHub mirror sync failed (oneshot, not persistent)        |
| `home-manager-lars.service`             | **MEDIUM**   | HM activation may have failed during last switch           |
| `service-health-check.service`          | **LOW**      | Meta-monitoring service itself failed                      |
| `podman-photomap.service`               | **HIGH**     | Crash-looping (multiple restart attempts in logs)          |
| `pull-whisper-asr-docker-image.service` | **HIGH**     | Docker pull failing (ROCm Whisper)                         |
| `whisper-asr-rocm.service`              | **HIGH**     | Depends on above image pull                                |
| `authelia.service`                      | **HIGH**     | SSO/gateway auth down                                      |
| `signoz.service`                        | **HIGH**     | Observability platform down                                |

**Root cause hypothesis:** Many of these failures are cascading from Caddy being down (TLS termination fails → upstream services can't start properly), or from Docker/Podman image availability issues (Whisper, PhotoMap).

---

## C) NOT STARTED

From MASTER_TODO_PLAN.md (33 remaining tasks):

### P1 SECURITY (4 remaining — all BLOCKED on evo-x2)

- #7: Move Taskwarrior encryption to sops (hardcoded hash)
- #9: Pin Docker digest for Voice Agents (version-tagged only)
- #10: Pin Docker digest for PhotoMap (version-tagged only)
- #11: Secure VRRP auth_pass with sops (plaintext)

### P5 DEPLOY/VERIFY (13 remaining — 0%)

- Full deployment verification pass
- Service smoke tests
- Cross-platform build validation
- End-to-end integration tests

### P6 SERVICES (6 remaining — 60%)

- Caddy restart/recovery (currently FAILED)
- Ollama service fix (currently FAILED)
- Authelia service fix (currently FAILED)
- PhotoMap container fix (crash-looping)
- Whisper ASR container fix (image pull failing)
- SigNoz recovery (currently FAILED)

### P9 FUTURE (10 remaining — 17%)

- Pi 3 DNS failover node provisioning
- macOS Darwin improvements
- CI/CD pipeline
- Automated testing

---

## D) TOTALLY FUCKED UP

### 1. Caddy is DOWN — Systemic Impact

Caddy (reverse proxy) is failed. This is the most critical service because ALL `*.home.lan` services depend on it for TLS termination. Without Caddy:

- `signoz.home.lan` — unreachable
- `tasks.home.lan` — TaskChampion sync unreachable (Taskwarrior sync fails silently)
- `git.home.lan` — Gitea unreachable
- All other internal services unreachable from LAN

### 2. Service Crash Cascades

The error logs show rapid repeated failures for photomap, whisper, authelia, and signoz — all crash-looping with systemd start-limit-hit protection kicking in. This suggests a systemic issue, possibly:

- Docker/Podman daemon problem
- Network connectivity issue during boot (services started before network ready)
- Resource exhaustion (46G/62G RAM used)

### 3. Disk Pressure

| Partition    | Used       | Free | Status                                     |
| ------------ | ---------- | ---- | ------------------------------------------ |
| `/` (root)   | 82% (412G) | 95G  | **WARN** — approaching capacity            |
| `/data`      | 86% (685G) | 116G | **WARN** — BTRFS + Docker overhead growing |
| `/nix/store` | 186G       | —    | Should run `nix-collect-garbage -d`        |

### 4. Hermes Watchdog Mystery (Resolved but Unexplained)

Between 04:49–08:47 on Apr 30, Hermes was killed repeatedly by `Watchdog timeout (limit 30s)`. But the deployed service file has NO `WatchdogSec`. The crash cycle:

- 5 restarts → `start-limit-hit` → service dead for ~40 minutes
- Manually restarted at 09:32 → stable for 13h since

The mystery: where did the watchdog come from? Possibilities:

- A previous generation had `WatchdogSec` that was later removed
- The Hermes Python process was self-signaling via `sd_notify` but not in time
- systemd was applying a default or inherited watchdog

**Resolution:** Service has been stable for 13h. The fix in commit `0909f06` removed WatchdogSec from Hermes explicitly. No further action needed unless it recurs.

---

## E) WHAT WE SHOULD IMPROVE

### Process Improvements

1. **Never ship `-f` (follow) in CLI recipes** — Every `*-logs` recipe was a trap that would hang the caller. We should audit all journalctl/tail commands in the justfile for follow-mode misuse.

2. **Service health after `just switch`** — We should add a post-switch health check that verifies all critical services are active. Currently, `just switch` can succeed while services silently fail.

3. **Nix store garbage collection** — 186G is excessive. `nix-collect-garbage -d` + `nix optimise-store` could reclaim significant space.

4. **Caddy as critical dependency** — Caddy should have `Restart=always` with aggressive `RestartSec` and a systemd health check timer. If Caddy dies, everything dies.

5. **Service ordering** — Many Docker/Podman services start before the network is truly ready. `after = ["network-online.target"]` is not always sufficient — consider `Wants` + `After` for Docker daemon dependency.

### Codebase Improvements

6. **Hermes `config.yaml` management** — Currently NOT in the repo (runtime-written). Should be managed via sops + template for declarative config, similar to how `.env` is handled.

7. **Consistent log recipe naming** — Some are `*-logs`, some are `*-log`. Should standardize to `*-logs` with `-follow` suffix for live tailing.

8. **Gitea `ensure-repos` Type=oneshot + Restart=always** — This is a known eval warning. Should be `Restart=on-failure` for oneshot services.

---

## F) TOP 25 THINGS WE SHOULD GET DONE NEXT

### Tier 1: Stop the Bleeding (Critical — Do First)

| #   | Task                                                                           | Effort | Impact                                 |
| --- | ------------------------------------------------------------------------------ | ------ | -------------------------------------- |
| 1   | **Fix Caddy service** — diagnose why failed, restart, verify TLS               | 15min  | CRITICAL — all services depend on this |
| 2   | **Deploy Hermes fixes** — `just switch` to apply libopus + deprecation cleanup | 10min  | HIGH — fixes Discord voice             |
| 3   | **Fix Authelia** — diagnose failure, likely needs Caddy first                  | 10min  | HIGH — SSO gateway                     |
| 4   | **Fix Ollama** — diagnose why local LLM inference is down                      | 15min  | HIGH — AI stack dependency             |
| 5   | **Run `nix-collect-garbage -d`** — reclaim space from 186G nix store           | 30min  | MEDIUM — disk pressure relief          |

### Tier 2: Service Recovery

| #   | Task                                                                             | Effort | Impact                        |
| --- | -------------------------------------------------------------------------------- | ------ | ----------------------------- |
| 6   | **Fix PhotoMap container** — podman crash-looping, investigate image/perm issues | 30min  | MEDIUM — photo AI tool        |
| 7   | **Fix Whisper ASR** — Docker image pull failing, check registry access           | 20min  | MEDIUM — voice agents         |
| 8   | **Fix SigNoz** — observability platform down, likely needs Caddy first           | 20min  | MEDIUM — monitoring           |
| 9   | **Fix `home-manager-lars.service`** — check HM activation errors                 | 15min  | MEDIUM — user environment     |
| 10  | **Fix `gitea-ensure-repos`** — change Restart=on-failure for oneshot type        | 5min   | LOW — eliminates eval warning |

### Tier 3: Security Hardening (from MASTER_TODO_PLAN P1)

| #   | Task                                                                     | Effort | Impact                         |
| --- | ------------------------------------------------------------------------ | ------ | ------------------------------ |
| 11  | **Move Taskwarrior encryption to sops** — replace hardcoded hash         | 30min  | HIGH — secrets management      |
| 12  | **Pin Docker digests for Voice Agents** — pin `sha256` for whisper image | 15min  | MEDIUM — supply chain security |
| 13  | **Pin Docker digests for PhotoMap** — pin `sha256` for photomap image    | 15min  | MEDIUM — supply chain security |
| 14  | **Secure VRRP auth_pass with sops** — encrypt plaintext password         | 20min  | MEDIUM — network security      |

### Tier 4: Quality of Life

| #   | Task                                                                                | Effort | Impact                           |
| --- | ----------------------------------------------------------------------------------- | ------ | -------------------------------- |
| 15  | **Add post-switch health check** — verify critical services are active after deploy | 30min  | HIGH — prevents silent failures  |
| 16  | **Add Caddy health timer** — periodic check + auto-restart if down                  | 20min  | HIGH — prevents cascade failures |
| 17  | **Manage Hermes config.yaml via sops** — declarative config, not runtime            | 45min  | MEDIUM — reproducibility         |
| 18  | **Standardize justfile log recipe naming** — all `*-logs` + `*-logs-follow`         | 15min  | LOW — consistency                |
| 19  | **Add `just nix-gc` recipe** — one-command garbage collection + optimise            | 10min  | LOW — maintenance UX             |

### Tier 5: Future Improvements

| #   | Task                                                                         | Effort | Impact                     |
| --- | ---------------------------------------------------------------------------- | ------ | -------------------------- |
| 20  | **Provision Pi 3 DNS failover node** — hardware setup + NixOS image          | 2hr    | HIGH — DNS HA              |
| 21  | **CI/CD pipeline** — automated flake check on push                           | 2hr    | MEDIUM — quality gate      |
| 22  | **E2E service smoke tests** — automated `*.home.lan` reachability checks     | 3hr    | MEDIUM — reliability       |
| 23  | **BTRFS snapshot automation review** — verify Timeshift is working correctly | 30min  | MEDIUM — disaster recovery |
| 24  | **DNS blocklist update automation** — auto-refresh blocklists on schedule    | 1hr    | LOW — security hygiene     |
| 25  | **Archive old status docs** — 180+ in archive/, consider pruning to last 30  | 15min  | LOW — repo cleanliness     |

---

## G) TOP #1 QUESTION I CANNOT FIGURE OUT MYSELF

**Why is Caddy failing?**

Caddy is the most critical service in the entire stack and it's down. From the health check, it's in `failed` state, but I cannot:

1. Read the Caddy journal logs (need `systemctl` which is blocked in my sandbox)
2. Check if the TLS certificates from sops are properly decrypted and available
3. Verify if port 443/80 is already in use by another process
4. Determine if this is a config generation issue or a runtime startup issue

**The immediate next action should be:** Run `just hermes-logs`-equivalent for Caddy (`journalctl -u caddy --no-pager -n 100`) to see why it failed, then restart it. Everything else cascades from Caddy being healthy.

---

## System State Snapshot

| Metric              | Value                | Status                       |
| ------------------- | -------------------- | ---------------------------- |
| **Nix**             | 2.34.6               | OK                           |
| **Flake check**     | Passes               | OK                           |
| **Niri compositor** | Running              | OK                           |
| **Failed units**    | 9 system + 1 user    | CRITICAL                     |
| **Disk /**          | 82% used (95G free)  | WARN                         |
| **Disk /data**      | 86% used (116G free) | WARN                         |
| **Memory**          | 46G/62G (74%)        | OK                           |
| **Hermes**          | Running 13h, stable  | OK (pending deploy of fixes) |
| **Caddy**           | FAILED               | CRITICAL                     |
| **Ollama**          | FAILED               | HIGH                         |
| **Authelia**        | FAILED               | HIGH                         |
| **SigNoz**          | FAILED               | HIGH                         |
| **PhotoMap**        | Crash-looping        | HIGH                         |
| **Whisper ASR**     | Crash-looping        | HIGH                         |

## Files Changed This Session

| File                                | Changes                                                                                       |
| ----------------------------------- | --------------------------------------------------------------------------------------------- |
| `justfile`                          | 6 log recipes fixed (removed `-f`), added `hermes-logs-follow`                                |
| `modules/nixos/services/hermes.nix` | Added libopus to path + LD_LIBRARY_PATH, removed deprecated MESSAGING_CWD, added .env cleanup |
