# Session 100: Post-Deploy Service Fixes & Cleanup

**Date:** 2026-05-27 15:50 | **Status:** Deployed & Verified | **Platform:** evo-x2 (NixOS 26.11)

---

## A) Fully Done

### 1. Fixed `niri-health-metrics.service` — Permission denied on textfile dir
- **Root cause:** `textfile_collectors` dir was `0755 nobody:nogroup`. The `niri-health-metrics` service runs as root with `harden` (system mode), which sets `ProtectSystem=full` and strips `CAP_DAC_OVERRIDE`. Root could not write to a directory it doesn't own, even with 0755.
- **Fix:** Changed tmpfiles rule from `0755` to `1777` (sticky bit + world-writable) — the standard for node_exporter textfile collectors. All writer services (amdgpu-metrics, nvme-metrics, niri-health-metrics) now work.
- **Fix 2:** Removed duplicate tmpfiles rule from `niri-config.nix` that claimed `root:root 1777` ownership. `signoz.nix` is the canonical owner.
- **Fix 3:** `journalctl --user -u niri` does not work from system service context. Changed to `journalctl _SYSTEMD_USER_UNIT=niri.service` for correct journal filtering.
- **Files:** `modules/nixos/services/signoz.nix:369`, `modules/nixos/services/niri-config.nix:33-36,126-127`
- **Verified:** Service exits 0/SUCCESS, writes metrics to `niri.prom` ✅

### 2. Fixed `oauth2-proxy.service` — cookie_secret wrong size
- **Root cause:** `oauth2_proxy_cookie_secret` in sops-encrypted `pocket-id.yaml` was 21 bytes. oauth2-proxy requires exactly 16, 24, or 32 bytes for AES cipher.
- **Fix:** Generated new 32-byte base64-encoded secret via `os.urandom(32)`. Updated sops file using `ssh-to-age` to convert SSH host key to age identity, then `sops --set`.
- **Lesson learned:** `sops` CLI requires age identity format (not raw SSH key). Must use `ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key` + `SOPS_AGE_KEY_FILE` env var. `sudo env VAR=VALUE` pattern needed because `sudo` strips env vars.
- **Files:** `platforms/nixos/secrets/pocket-id.yaml`
- **Verified:** Service `active`, no more cookie_secret errors ✅

### 3. Removed dead `METRICS_FILE` variable from `nvme-health-monitor`
- **Root cause:** `METRICS_FILE` defined at `nvme-health-monitor.nix:21` but never used in the script. The actual `nvme.prom` writer is `nvme-metrics` in `signoz.nix`. Misleading for anyone reading the code.
- **Files:** `modules/nixos/services/nvme-health-monitor.nix:21`

### 4. Suppressed Home Manager version mismatch warning
- **Root cause:** `home-manager` input tracks master (26.05) while `nixpkgs` is on `nixpkgs-unstable` (26.11). Warning fires on every eval: "You are using Home Manager version 26.05 and Nixpkgs version 26.11."
- **Fix:** Added `home.enableNixpkgsReleaseCheck = false` for both evo-x2 user (`lars`) and rpi3 user (`root`). This is safe because HM follows nixpkgs via `inputs.nixpkgs.follows`.
- **Files:** `platforms/nixos/users/home.nix:188`, `flake.nix:702`

### 5. Full deploy executed and verified
- `just switch` completed successfully on evo-x2
- All 24 derivations built, activation successful
- Both previously-failed services now running:
  - `niri-health-metrics.service`: active (oneshot, exits 0)
  - `oauth2-proxy.service`: active

---

## B) Partially Done

### 1. `service-health-check.service` — still failing (pre-existing)
- Runs every 15 min, checks ~30 services. Currently fails because it checks services that are **disabled** or **don't exist**:
  - `ollama` — disabled (`enable = false` or not configured)
  - `whisper-asr` — disabled (voice agents disabled)
  - `livekit` — disabled (voice agents disabled)
  - `monitor365` (user service) — inactive
  - `monitor365-server` (user service) — failed
  - `file-and-image-renamer` (user service) — disabled (Go 1.26.3 mismatch)
- **Needs:** Script should dynamically check only enabled services, or list should be kept in sync with configuration.nix
- **Status:** Not fixed this session — pre-existing issue

### 2. Port collision assertion — error message quality
- `lib/ports.nix` port collision detection works but shows count mismatch (e.g., "25 ≠ 24") without showing which ports collide
- **Status:** Functional but could be improved

---

## C) Not Started

### From Session 99 (still outstanding)
1. **Move `todo-list-ai` FOD hash upstream** — bun node_modules hash managed in SystemNix instead of upstream repo
2. **Move `dnsblockd`/`file-and-image-renamer` vendorHash upstream** — hardcoded in `overlays/linux.nix`
3. **GitHub Actions CI** — no CI exists at all
4. **PMA `go.work` version** — `go 1.26.2` vs `go 1.26.3` in submodules
5. **PMA `overrideModAttrs` anti-pattern** — still present, blocked on git tags for submodules
6. **Convert `/data` BTRFS from toplevel to `@data` subvolume** — enables /data snapshots
7. **Gatus health checks for all services** — only partial coverage
8. **Centralize Docker image tags** — scattered across modules

### New this session
9. **Service health check script** — needs to only check enabled services
10. **NixOS module assertion for oauth2-proxy cookie_secret length** — would prevent the 21-byte issue at eval time

---

## D) Totally Fucked Up

### Nothing is catastrophically broken. But:

1. **`/data` disk at 92% (933G/1.0T)** — 91G free. AI models and Docker images are the main consumers. Not critical yet but trending upward.
2. **Swap at 63% (12Gi/19Gi)** — high but stable. systemd-oomd is configured and watching.
3. **Session 99 changes were deployed but the health check script was not updated** — it checks disabled services and always fails, generating noise.

---

## E) What We Should Improve

### Process Improvements
1. **Commit immediately after each fix** — I batched fixes and committed at the end. Should commit per logical change for cleaner git history and easier rollback.
2. **Know the sops+age toolchain better** — wasted 3 attempts on `SOPS_AGE_SSH_PRIVATE_KEY_FILE` before realizing sops CLI needs age identity format, not SSH format. Should document this in AGENTS.md.
3. **Check `service-health-check` script when enabling/disabling services** — it's a static list that rots. Should be auto-generated or at least validated against enabled services.
4. **Validate sops secret values at NixOS eval time** — oauth2-proxy cookie_secret length could be asserted in the NixOS module before deployment.

### Architecture Improvements
5. **Textfile collectors directory ownership** — currently `nobody:nogroup 1777`. Consider a dedicated `node-exporter` user with 0755 and explicit ACLs. World-writable is standard for textfile collectors but not ideal.
6. **Cross-module tmpfiles dependencies** — `niri-config.nix` writes to a dir created by `signoz.nix`. Should be an explicit dependency or the dir ownership should be in a shared module.
7. **Type models for secrets** — no validation of secret content (length, format). Could add `lib.types` assertions for critical secrets.

### Libs & Patterns
8. **Use `writeShellApplication` instead of `writeShellScript`** — provides automatic `set -euo pipefail`, shellcheck, and runtime input validation. Currently mixed usage.
9. **Use `lib.types.*` more** — `servicePort` exists but could add `serviceSecretFile` with assertions on file existence and content format.

---

## F) Top 25 Next Tasks

### Tier 1: Immediate (today, <30 min each)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 1 | Fix `service-health-check` script — remove disabled services (ollama, whisper-asr, livekit, file-and-image-renamer, monitor365*) | 10 min | Stops every-15-min false alerts |
| 2 | Add sops/age toolchain docs to AGENTS.md (ssh-to-age, SOPS_AGE_KEY_FILE pattern) | 10 min | Prevents future sops debugging pain |
| 3 | Set `boot.zfs.forceImportRoot = false` — suppress 26.11 deprecation warning | 2 min | Clean eval output |
| 4 | Verify Darwin build passes (`just test-fast` on macOS) | 5 min | Cross-platform regression check |

### Tier 2: This Week (<2 hr each)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 5 | Move `todo-list-ai` bun FOD hash management to upstream repo | 30 min | Eliminates most fragile hash in SystemNix |
| 6 | Move `dnsblockd` vendorHash to upstream repo | 15 min | Eliminates linux.nix hardcode |
| 7 | Move `file-and-image-renamer` vendorHash to upstream repo | 15 min | Eliminates linux.nix hardcode + anti-pattern |
| 8 | Add NixOS module assertion for oauth2-proxy cookie_secret byte length | 30 min | Prevents bad secrets at eval time |
| 9 | Fix PMA go.work: `go 1.26.2` → `go 1.26.3` | 2 min | Unblocks local golangci-lint |
| 10 | Publish git tags for go-output submodules (9 tags) | 10 min | Enables PMA overrideModAttrs removal |
| 11 | Remove PMA `overrideModAttrs` after tags exist | 15 min | Eliminates anti-pattern |
| 12 | Add GitHub Actions CI: `nix flake check --no-build` on push | 30 min | Catch eval errors pre-deploy |

### Tier 3: Architecture (this sprint)

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 13 | Auto-generate `service-health-check` service list from enabled services | 1 hr | Never rots again |
| 14 | Improve port collision assertion with duplicate port names in error message | 30 min | Better DX on collision |
| 15 | Redesign `mkPreparedSource` to auto-generate `require` lines | 2 hr | Eliminates manual postPatchExtra sed hacks |
| 16 | Add `mkPackageOverlay` platform filtering (skip Linux-only on Darwin) | 1 hr | Cleaner overlay separation |
| 17 | Convert `writeShellScript` to `writeShellApplication` across all services | 2 hr | Shellcheck + bashStrict done automatically |

### Tier 4: Nice to Have

| # | Task | Effort | Impact |
|---|------|--------|--------|
| 18 | Convert /data BTRFS from toplevel to `@data` subvolume | 30 min | Enables /data snapshots |
| 19 | Add Gatus health checks for all services | 1 hr | Full observability |
| 20 | Audit all services for `WatchdogSec` misuse | 30 min | Correctness |
| 21 | Centralize Docker image tags in `lib/` | 2 hr | Single source of truth |
| 22 | Add `just test` to GitHub Actions (full build) | 1 hr | Complete CI coverage |
| 23 | Create `modules/nixos/services/` README with conventions | 15 min | Onboarding |
| 24 | Benchmark flake eval time before/after auto-discovery | 10 min | Performance baseline |
| 25 | Add `# @module <name>` convention to replace file parsing in auto-discovery | 1 hr | Faster eval, more explicit |

---

## G) Open Question

**#1 question I cannot figure out myself:**

> Should `monitor365` and `monitor365-server` user services be running? They show as `inactive` / `failed` in the health check, and I cannot determine from the code alone whether they're supposed to be enabled for the `lars` user on evo-x2. The monitor365 NixOS module appears to be enabled in `configuration.nix`, but the user services may need manual setup or may be intentionally disabled. **Are these services supposed to be active?**

---

## Session Metrics

| Metric | Value |
|--------|-------|
| Commits pushed | 4 (`eb8af6bf` → `0c1f50fa`) |
| Files changed | 5 |
| Services fixed | 2 (niri-health-metrics, oauth2-proxy) |
| Warnings suppressed | 1 (HM version mismatch) |
| Dead code removed | 1 (METRICS_FILE variable) |
| Build | All checks passed |
| Deploy | Successful on evo-x2 |
| Working tree | Clean |
| Disk (root) | 78% used (113G free) |
| Disk (/data) | 92% used (91G free) |
| Swap | 63% used (12Gi/19Gi) |
| Memory | 20Gi/93Gi used |

## Active Services (evo-x2)

| Service | Status |
|---------|--------|
| caddy | ✅ active |
| forgejo | ✅ active |
| postgresql | ✅ active |
| immich-server | ✅ active |
| immich-machine-learning | ✅ active |
| pocket-id | ✅ active |
| oauth2-proxy | ✅ active (fixed this session) |
| homepage-dashboard | ✅ active |
| signoz | ✅ active |
| signoz-collector | ✅ active |
| clickhouse | ✅ active |
| gatus | ✅ active |
| prometheus-node-exporter | ✅ active |
| cadvisor | ✅ active |
| hermes | ✅ active |
| manifest | ✅ active |
| twenty | ✅ active |
| dnsblockd | ✅ active |
| unbound | ✅ active |
| docker | ✅ active |
| niri-health-metrics | ✅ active (fixed this session) |
| ollama | ⚠️ inactive (not configured?) |
| whisper-asr | ⚠️ inactive (voice agents disabled) |
| livekit | ⚠️ inactive (voice agents disabled) |
| service-health-check | ❌ failed (checks disabled services) |
