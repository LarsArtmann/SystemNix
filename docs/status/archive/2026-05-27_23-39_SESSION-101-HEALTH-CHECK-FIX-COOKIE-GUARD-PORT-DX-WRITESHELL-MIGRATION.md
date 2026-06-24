# Session 101: Health Check Fix, Cookie Secret Guard, Port Collision DX, writeShellApplication Migration

**Date:** 2026-05-27 23:39 | **Status:** Ready to Commit & Deploy | **Platform:** evo-x2 (NixOS 26.11)

---

## A) Fully Done

### 1. Fixed `service-health-check` script — removed disabled services
- **Root cause:** Script checked 30 services including 4 that are disabled (ollama, whisper-asr, livekit, file-and-image-renamer), causing false alerts every 15 minutes
- **Fix:** Removed 4 disabled services from check list. Kept `monitor365`/`monitor365-server` (both are enabled — their failures are real signals, not noise)
- **Services removed:** `ollama` (ai-stack not in configuration.nix), `whisper-asr` (voice-agents disabled), `livekit` (voice-agents disabled), `file-and-image-renamer` (disabled, Go 1.26.3 mismatch)
- **Services kept:** `monitor365` + `monitor365-server` (enabled via `monitor365.enable = true; server.enable = true`)
- **Files:** `platforms/nixos/scripts/service-health-check`
- **Impact:** Stops every-15-min false alerts

### 2. Added oauth2-proxy cookie_secret runtime assertion
- **Root cause:** Session 100 had a 21-byte cookie_secret that caused oauth2-proxy to crash. No validation existed — bad secrets only fail at runtime with cryptic AES cipher errors
- **Fix:** Added `ExecStartPre` script using `writeShellApplication` that:
  1. Checks the secret file exists at the sops-decrypted path
  2. Base64-decodes the secret and checks byte length
  3. Rejects anything not exactly 16, 24, or 32 bytes (AES-128/192/256)
  4. Uses `+` prefix in ExecStartPre to run as root (needed for sops secret access)
- **Files:** `modules/nixos/services/oauth2-proxy.nix`
- **Impact:** Prevents the session-100 issue from recurring — bad secrets fail fast with clear error message

### 3. Improved port collision error message
- **Root cause:** `lib/ports.nix` collision detection used `builtins.genericClosure` to deduplicate port values, then asserted `length values == length deduped`. On collision, error showed cryptic count mismatch like `"25 ≠ 24"` with no indication of which ports collided
- **Fix:** Replaced with `builtins.groupBy` + filter approach that shows exactly which ports collide and which service names share them. Example: `Port collision: port 3000 used by: forgejo, monitor365-server`
- **Files:** `lib/default.nix`
- **Impact:** Much better developer experience on port collision — immediate actionable error

### 4. Suppressed ZFS `forceImportRoot` deprecation warning on rpi3-dns
- **Root cause:** NixOS 26.11 added deprecation warning for `boot.zfs.forceImportRoot` defaulting to `true`. Even though evo-x2 is BTRFS-only, rpi3-dns uses ZFS and triggered the warning on every eval
- **Fix:** Added `boot.zfs.forceImportRoot = false;` to rpi3-dns config
- **Files:** `platforms/nixos/rpi3/default.nix`
- **Impact:** Clean eval output, no more warnings

### 5. Added sops/age toolchain docs to AGENTS.md
- **Root cause:** Session 100 wasted 3 attempts on `SOPS_AGE_SSH_PRIVATE_KEY_FILE` before discovering sops CLI needs age identity format via `ssh-to-age`
- **Fix:** Added new "Sops + Age Toolchain" section to AGENTS.md covering:
  - `ssh-to-age` conversion of SSH host key to age identity
  - `SOPS_AGE_KEY_FILE` env var pattern (not `SOPS_AGE_SSH_PRIVATE_KEY_FILE`)
  - `sudo env VAR=VALUE` pattern (sudo strips env vars)
  - Cookie secret byte requirements (16/24/32)
  - Cleanup of age key file after use
- **Files:** `AGENTS.md`
- **Impact:** Prevents future sops debugging pain — the painful learning from session 100 is now documented

### 6. Converted 11 inline scripts from `writeShellScript` → `writeShellApplication`
- **Root cause:** `writeShellScript` provides no shellcheck, no `set -euo pipefail`, and requires manual `${pkgs.xxx}/bin/` prefixes for all commands. Mixed usage across the codebase
- **Fix:** Converted 11 inline scripts across 7 modules to `writeShellApplication`, gaining:
  - Automatic `set -euo pipefail` (removed manual `set -euo pipefail` lines)
  - Shellcheck at build time
  - `runtimeInputs` for PATH management (replaced `${pkgs.xxx}/bin/` prefixes)
  - Removed redundant `path = [...]` from systemd service definitions where `runtimeInputs` handles it
- **Converted:**
  - `disk-monitor.nix` — disk-monitor-check script
  - `hermes.nix` — merge-env, fix-permissions, migrate-state scripts (3 scripts)
  - `niri-config.nix` — niri-health-metrics script
  - `nvme-health-monitor.nix` — nvme-health-check script
  - `oauth2-proxy.nix` — check-cookie-secret script
  - `signoz.nix` — amdgpu-metrics, nvme-metrics scripts (2 scripts)
  - `scheduled-tasks.nix` — notify-failure, rust-target-cleanup scripts (2 scripts)
- **Dead code removed:** Unused `strip_pct()` function in amdgpu-metrics, `findutils` from amdgpu-metrics path
- **Files:** 7 service modules
- **Status:** 11 converted, 34 remaining (see Partially Done)

---

## B) Partially Done

### 1. `writeShellScript` → `writeShellApplication` migration (11/45 done)
- **Progress:** 11 of 45 inline scripts converted. `writeShellApplication` is now the majority pattern for monitoring/health scripts
- **Remaining 34 scripts** across these modules:
  - `forgejo.nix` — 8 scripts (setup, admin-setup, token-gen, runner-token, register-runner, mirror-github, mirror-starred, ensure-password-file)
  - `forgejo-repos.nix` — 3 scripts (ensure-repos, update-github-token, wait-for-forgejo)
  - `waybar.nix` — 7 scripts (camera, dns-stats, media, clipboard, clipboard-menu, clipboard-clear, weather)
  - `dual-wan.nix` — 4 scripts (route-health-monitor, mptcp-endpoint-manager, mptcpize-wrapper, mptcp-dispatcher)
  - `monitor365.nix` — 1 script (inject-auth)
  - `dns-blocker.nix` — 2 scripts (init, start-wrapper)
  - `niri-wrapped.nix` — 2 scripts (awww-check-wayland, swayidle-suspend)
  - `taskwarrior.nix` — 1 script (backup)
  - `ai-stack.nix` — 1 script (gpu-python)
  - `scheduled-tasks.nix` — 2 scripts (dns-update, service-health-check — both use `builtins.readFile` from external files)
  - `flake.nix` — 3 scripts (deploy, validate, dns-diagnostics — all `writeShellScriptBin` with `builtins.readFile`)
- **Note:** External scripts loaded via `builtins.readFile` need their shebangs removed for `writeShellApplication` compatibility — requires updating the source `.sh` files
- **Effort:** ~1.5-2 hr remaining

---

## C) Not Started

### From Session 99/100 (still outstanding)
1. **Move `todo-list-ai` FOD hash upstream** — bun node_modules hash managed in SystemNix instead of upstream repo
2. **Move `dnsblockd`/`file-and-image-renamer` vendorHash upstream** — hardcoded in `overlays/linux.nix`
3. **GitHub Actions CI** — no CI exists at all
4. **PMA `go.work` version** — `go 1.26.2` vs `go 1.26.3` in submodules
5. **PMA `overrideModAttrs` anti-pattern** — still present, blocked on git tags for submodules
6. **Convert `/data` BTRFS from toplevel to `@data` subvolume** — enables /data snapshots
7. **Gatus health checks for all services** — only partial coverage
8. **Centralize Docker image tags** — scattered across modules

### New this session
9. **Finish `writeShellScript` → `writeShellApplication` migration** — 34 scripts remaining
10. **Auto-generate `service-health-check` service list from enabled services** — currently static, rots when services are enabled/disabled

---

## D) Totally Fucked Up

### Nothing catastrophically broken. But:

1. **`/data` disk at ~92% (933G/1.0T)** — 91G free. AI models and Docker images are main consumers. Not critical yet but trending upward.
2. **Swap at ~63% (12Gi/19Gi)** — high but stable. systemd-oomd is configured and watching.
3. **`monitor365-server` user service failing** — enabled in configuration.nix but crashing. Root cause unknown (needs `journalctl --user -u monitor365-server -n 50`). The health check now correctly reports this as a real failure rather than noise.
4. **34 `writeShellScript` scripts remain** — partial migration means inconsistent patterns across the codebase. Should complete the migration to avoid confusion.

---

## E) What We Should Improve

### Process Improvements
1. **Commit per logical change** — this session batched 6 logical changes into one commit. Should commit per fix for cleaner git history and easier rollback.
2. **Check `service-health-check` when enabling/disabling services** — it's still a static list. Should be auto-generated from NixOS config.
3. **Validate sops secret values at activation time** — the cookie_secret ExecStartPre is a good pattern that could be applied to other secrets (e.g., client_secret format validation).

### Architecture Improvements
4. **Textfile collectors directory ownership** — currently `nobody:nogroup 1777` (world-writable). Consider a dedicated `node-exporter` user with 0755 and explicit ACLs.
5. **Cross-module tmpfiles dependencies** — `niri-config.nix` writes to a dir created by `signoz.nix`. Should be explicit dependency or shared module.
6. **Type models for secrets** — no validation of secret content (length, format). The ExecStartPre pattern works but Nix-level assertions would be better.

### Libs & Patterns
7. **Use `writeShellApplication` everywhere** — 34 scripts remaining. Complete the migration.
8. **Use `lib.types.*` more** — `servicePort` exists but could add `serviceSecretFile` with assertions on file existence.

---

## F) Top 25 Next Tasks

### Tier 1: Immediate (today, <30 min each)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Finish `writeShellScript` → `writeShellApplication` migration (forgejo.nix: 8 scripts) | 30 min | Consistency, shellcheck on all scripts |
| 2 | Finish migration (waybar.nix: 7 scripts) | 20 min | Consistency, shellcheck |
| 3 | Finish migration (dual-wan, dns-blocker, monitor365, niri-wrapped, taskwarrior, ai-stack) | 30 min | Consistency, shellcheck |
| 4 | Investigate `monitor365-server` failure — check logs and fix | 10 min | Real service failure hidden by previous noise |
| 5 | Convert external `.sh` scripts to `writeShellApplication` (service-health-check, dns-update, deploy, validate, dns-diagnostics) | 30 min | Complete migration |

### Tier 2: This Week (<2 hr each)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 6 | Move `todo-list-ai` bun FOD hash management to upstream repo | 30 min | Eliminates most fragile hash in SystemNix |
| 7 | Move `dnsblockd` vendorHash to upstream repo | 15 min | Eliminates linux.nix hardcode |
| 8 | Move `file-and-image-renamer` vendorHash to upstream repo | 15 min | Eliminates linux.nix hardcode + anti-pattern |
| 9 | Fix PMA go.work: `go 1.26.2` → `go 1.26.3` | 2 min | Unblocks local golangci-lint |
| 10 | Publish git tags for go-output submodules (9 tags) | 10 min | Enables PMA overrideModAttrs removal |
| 11 | Remove PMA `overrideModAttrs` after tags exist | 15 min | Eliminates anti-pattern |
| 12 | Add GitHub Actions CI: `nix flake check --no-build` on push | 30 min | Catch eval errors pre-deploy |
| 13 | Auto-generate `service-health-check` service list from enabled services | 1 hr | Never rots again |

### Tier 3: Architecture (this sprint)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 14 | Redesign `mkPreparedSource` to auto-generate `require` lines | 2 hr | Eliminates manual postPatchExtra sed hacks |
| 15 | Add `mkPackageOverlay` platform filtering (skip Linux-only on Darwin) | 1 hr | Cleaner overlay separation |
| 16 | Convert `/data` BTRFS from toplevel to `@data` subvolume | 30 min | Enables /data snapshots |
| 17 | Add Gatus health checks for all services | 1 hr | Full observability |
| 18 | Audit all services for `WatchdogSec` misuse | 30 min | Correctness |
| 19 | Centralize Docker image tags in `lib/` | 2 hr | Single source of truth |

### Tier 4: Nice to Have

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 20 | Add `just test` to GitHub Actions (full build) | 1 hr | Complete CI coverage |
| 21 | Create `modules/nixos/services/` README with conventions | 15 min | Onboarding |
| 22 | Benchmark flake eval time before/after auto-discovery | 10 min | Performance baseline |
| 23 | Add `# @module <name>` convention to replace file parsing in auto-discovery | 1 hr | Faster eval, more explicit |
| 24 | Add runtime secret validation for other critical secrets (pattern from cookie_secret) | 1 hr | Prevents bad secret deployments |
| 25 | Textfile collectors: dedicated `node-exporter` user instead of world-writable 1777 | 30 min | Better security posture |

---

## G) Open Question

**#1 question I cannot figure out myself:**

> `monitor365-server` is enabled in configuration.nix with `server.enable = true` and `listenAddr = "0.0.0.0:3001"`. It's a user service bound to `default.target`. The health check now correctly reports it as failed (it was previously hidden among the noise of disabled services). **Should I investigate and fix `monitor365-server`, or is it intentionally left in a broken state while under development?** The module is complex (700+ lines) and the failure could be a config issue, missing database, or an actual bug.

---

## Session Metrics

|| Metric | Value |
||--------|-------|
|| Commits (pending) | 1 (this session's changes) |
|| Files changed | 11 |
|| Disabled services removed from health check | 4 |
|| Runtime assertions added | 1 (cookie_secret byte length) |
|| ZFS warnings suppressed | 1 (rpi3-dns forceImportRoot) |
|| Scripts converted to writeShellApplication | 11 of 45 |
|| Dead code removed | 1 (unused strip_pct in amdgpu-metrics) |
|| Error message improvements | 1 (port collision) |
|| Documentation additions | 1 (sops/age toolchain in AGENTS.md) |
|| Build | All checks passed ✅ |
|| Working tree | 11 modified files, 1 untracked (gather-status.sh) |
