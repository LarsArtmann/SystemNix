# Status Report: Renamer System Service Conversion & Sops Investigation

**Date:** 2026-08-10 13:45 CEST\
**Session scope:** Investigate sops redesign question → fix root cause → deploy\
**Machine:** evo-x2 (NixOS 26.11, nixos-unstable @ f13ff45)

---

## Context

User asked: _"Why does https://renamer.home.lan/ seem so old?"_ and _"Can and SHOULD we redesign our sops nix setup? synthetic_api_key has only 1 per account and it works for crush so why does it NOT work for file-and-image-renamer?"_

This session continued from a prior session that had:

- Diagnosed 3 root causes (dead watcher, placeholder API key claim, stale binary)
- Fixed the nixpkgs tarball regression (nixos-hardware follows)
- Written a status report but NOT deployed

---

## A) FULLY DONE

### 1. Sops Investigation — "Should we redesign?" → NO

**Conclusion:** The sops setup was never the problem. No redesign needed.

**Evidence:**

- Both `synthetic_api_key` secrets decrypt to the real key: `REDACTED-SYNTHETIC-KEY-ELIDED` (36 bytes, verified at runtime)
- The previous session's "placeholder" claim (`"synthetic_api_key"` at `sops.nix:158`) was **wrong** — that string is the YAML _key name_ in `mkKeyedSecrets`, not the decrypted value
- The renamer's `_FILE` pattern (`SYNTHETIC_API_KEY_FILE=/run/secrets/...`) is actually **more secure** than crush-daily's env-file template — the key never appears in `/proc/<pid>/environ`
- The Go binary (`pkg/config/config.go`) correctly handles `SYNTHETIC_API_KEY_FILE` via `loadSecretFromEnv()` — reads file, trims whitespace, returns key

**Sops pattern comparison (both valid, different tradeoffs):**

| Service                | Pattern                                                             | Key in environ?      | Key in file?    |
| ---------------------- | ------------------------------------------------------------------- | -------------------- | --------------- |
| crush-daily            | sops template → `CRUSH_DAILY_LLM_API_KEY=...` via `EnvironmentFile` | Yes (in process env) | No              |
| file-and-image-renamer | sops secret → `SYNTHETIC_API_KEY_FILE=/run/secrets/...`             | No (only file path)  | Yes (mode 0400) |

Both are correct. The renamer pattern is arguably better (key not in process environment).

### 2. Watcher Converted from HM User Service to System Service

**File:** `modules/nixos/services/file-and-image-renamer.nix`

**Before:** Watcher was a Home Manager user service with:

- `WantedBy = [ "graphical-session.target" ]`
- `PartOf = [ "graphical-session.target" ]`
- `After = [ "network.target" "graphical-session.target" ]`

**After:** System service with:

- `wantedBy = [ "multi-user.target" ]`
- `after = [ "network.target" ]`
- `harden { ProtectHome = "read-only"; ReadWritePaths = [ dataDir watchDirectory ] ++ watchPaths; }`
- Runs as `cfg.user` (primaryUser) via `User = cfg.user`
- Uses `sd.serviceDefaults` (system) instead of `sd.serviceDefaultsUser`
- Removed `hardenUser` import (no longer needed)

**Why:** Current session is `Type=tty` (no graphical session). The watcher never started because its target was inactive. Converting to a system service means it runs headless, started at boot.

**Verified no desktop notification dependency:** Grepped the Go source — only `signal.Notify` (OS signals), no libnotify/DBus notification calls. Safe to run headless.

### 3. Deploy Succeeded (Despite Exit Code 4)

- `nix run .#deploy` built and activated the new generation
- `nh os switch` reported exit code 4 (known `switch-to-configuration` issue — dbus connection refused for monitor365/sddm user sessions, non-fatal)
- New generation is active: `/nix/store/clfrssyvpcc1imlyqsv6lk74h9hv2y27-nixos-system-evo-x2-26.11.20260807.f13ff45`
- `file-and-image-renamer.service` started as a new unit

### 4. End-to-End AI Rename Verified

- Created `untitled.png` (4x4 blue PNG, unique hash) in `~/Downloads`
- Watcher detected it within ~30 seconds
- AI vision API called successfully: `glm-4.6v`, 764 tokens, $0.0004
- Renamed: `untitled.png` → `solid-blue-background.png`
- History entry: `success: true`, `quality_level: POOR` (original name), `was_skipped: false`

**Both processes running:**

```
PID 1383819: file-renamer health --addr 127.0.0.1:8086
PID 1384079: file-renamer watch
```

**Binary version:** `e2156ba` (Aug 9, from flake.lock) — up from `d7e1d55` (Aug 8, stale deployed version)

### 5. Upstream Fixes Pushed

| Repo                             | Commit              | Fix                                                                      |
| -------------------------------- | ------------------- | ------------------------------------------------------------------------ |
| `go-cqrs-lite`                   | `9d92d91`           | `cqrs-lint` vendorHash updated for nixpkgs Go version bump               |
| `projects-management-automation` | `a383c381` (pushed) | Unpushed commit with correct vendorHash + project-discovery-sdk dep bump |

Both flake inputs updated in SystemNix `flake.lock`.

### 6. Flake Check Passes

```
nix flake check --no-build → all checks passed!
nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel → store path returned
```

---

## B) PARTIALLY DONE

### 1. Deploy Exit Code 4 — Config IS Active But Deploy Script Aborted

The deploy script (`scripts/deploy.sh`) aborted after `nh os switch` returned exit code 4, meaning:

- Pre-deploy check ran ✓
- `nh os switch` activated the config ✓ (new generation is live, services started)
- Post-deploy check did NOT run (script aborted)
- Deploy script's explicit service restarts did NOT run

The exit code 4 is from `switch-to-configuration` failing to reload dbus for `monitor365` (UID 966) and `sddm` (UID 175) user sessions — "Failed to connect to socket /run/user/966/bus: Connection refused". These are non-fatal warnings — the system config activated successfully.

**Impact:** Services that `deploy.sh` explicitly restarts after switch (provisioner oneshots, etc.) may be stale until next deploy or manual restart. The renamer services started correctly because they're new units.

### 2. Sops.nix Code Quality — mkKeyedSecrets Naming Confusion

The `mkKeyedSecrets` pattern at `sops.nix:148-159` maps a Nix attrset name to a YAML key name:

```nix
{
  file_renamer_synthetic_api_key = "synthetic_api_key";
}
```

This means: "Create sops secret `file_renamer_synthetic_api_key` from YAML key `synthetic_api_key`". The previous session misread `"synthetic_api_key"` as the _value_ rather than the _key name_. This naming pattern is functional but confusing — the comment on line 156-157 helps, but the pattern itself is non-obvious.

### 3. flake.nix Uncommitted Formatting Changes

Pure alejandra reindentation (275 insertions / 279 deletions, no logic changes). Still unstaged from the prior session. Not deployed-affecting but clutters `git diff`.

---

## C) NOT STARTED

### 1. Audit ALL Flake Inputs for Missing `inputs.nixpkgs.follows`

Identified in the prior session as a prevention item. `nixos-hardware` was the one missing it, but the audit of ALL inputs was never completed. Other inputs could still cause the tarball regression if they independently resolve nixpkgs through the global registry.

### 2. Gatus Health Check for Renamer Watcher

The renamer health dashboard (port 8086) has no Gatus health check. The dashboard only shows accumulated state — if the watcher dies, the dashboard stays green. A Gatus check on `http://localhost:8086/status` with `[BODY].jsonpath` checking `pass_checks` or process count would catch a dead watcher.

### 3. Homepage Tile for Renamer

No Homepage tile exists for `renamer.home.lan`. Every service should be discoverable from the dashboard.

### 4. DNS Local Subdomain for Renamer

Need to verify `renamer.home.lan` is in `dnsLocal.localSubdomains` in the dnsblockd config.

### 5. Caddy vHost for Renamer

Need to verify the Caddy reverse proxy configuration for `renamer.home.lan` → `127.0.0.1:8086`.

### 6. OTel Tracing for Renamer

The env var `OTEL_EXPORTER_OTLP_ENDPOINT` is set but may be a noop if the binary lacks OTel instrumentation. Not verified.

---

## D) TOTALLY FUCKED UP

### 1. Prior Session's "Placeholder API Key" Diagnosis Was WRONG

The prior session's status report (`docs/status/2026-08-10_08-59_renamer-stale-nixpkgs-tarball-regression-recurrence.md`) stated:

> "API key in sops is still placeholder (`synthetic_api_key`)"

This was **factually incorrect**. `"synthetic_api_key"` at `sops.nix:158` is the YAML _key name_ in `mkKeyedSecrets`, not the decrypted value. The actual decrypted value is `REDACTED-SYNTHETIC-KEY-ELIDED` (36 bytes) — a real, valid Synthetic.new API key. I verified this by reading the file at `/run/secrets/file_renamer_synthetic_api_key`.

**Impact:** This misdiagnosis would have led someone to "fix" a non-existent problem by replacing a real key with a real key, wasting time and potentially introducing errors.

**Lesson:** Always verify claims at runtime before writing them in status reports. Read the actual decrypted secret file before claiming it's a placeholder.

### 2. cqrs-lint and PMA vendorHash Mismatches Blocked Deploy

Both were caused by the nixpkgs version change (January → August 2026 = different Go version = different vendored output). These are Fixed-Output Derivations (FODs) that `nix flake check --no-build` does NOT catch. The deploy failed twice before these were fixed.

**Impact:** ~3 minutes of wasted build time across 2 failed deploys.

**Lesson:** After a nixpkgs version bump, batch-test individual Go packages before attempting a full deploy. The AGENTS.md already documents this gotcha but it wasn't followed.

### 3. Prior Session's Root Cause Analysis Was Incomplete

The prior session identified 3 root causes:

1. Dead watcher (graphical-session binding) ✓ correct
2. Placeholder API key ✗ WRONG (was real key)
3. Stale binary ✓ correct

But missed the actual deploy blockers (vendorHash mismatches). The investigation focused on service-level issues before checking whether a deploy would even succeed.

---

## E) WHAT WE SHOULD IMPROVE

### Architecture / Design

1. **Never bind daemons to `graphical-session.target`** — Daemons that don't need a display server should always be system services with `multi-user.target`. The graphical-session binding was a design mistake from the start. If a future service needs display access (notifications, screenshots), use `hardenUser` + `WantedBy = [ "default.target" ]` (user session, not graphical-specific).

2. **Sops `mkKeyedSecrets` naming is confusing** — The pattern `{ nix_attr_name = "yaml_key_name"; }` is backwards from intuition. Most people expect the left side to be the source and the right side to be the destination. Consider renaming to make the directionality explicit, or add a more prominent comment.

3. **FOD vendorHash mismatches need a pre-deploy batch test** — After any nixpkgs version change, run `nix build .#cqrs-lint .#projects-management-automation` individually before `nix run .#deploy`. Add this to `pre-deploy-check.sh`.

4. **Deploy exit code 4 should not abort the script** — `switch-to-configuration` exit code 4 means "some units failed to reload" but the config IS active. The deploy script should treat exit code 4 as a warning, not a hard failure. Consider `|| [ $? -eq 4 ]` in the deploy script.

### Prevention

5. **Add a runtime assertion that the watcher process is alive** — The health dashboard shows accumulated state but doesn't verify the watcher is running. A simple `pgrep -x file-renamer` check in the health endpoint (or a separate systemd watchdog) would catch a dead watcher immediately.

6. **Add Gatus monitoring for renamer** — `http://localhost:8086/status` with a check on `fail_checks == 0` and `warn_checks < 2`. This is AGENTS.md rule #9 — every new service MUST be monitored.

7. **Audit ALL flake inputs for `inputs.nixpkgs.follows`** — Run `grep "url.*github" flake.nix` and verify every input that could transitively depend on nixpkgs has the follows declaration. This prevents the tarball regression from other vectors.

### Documentation

8. **Update AGENTS.md with the system-service conversion** — The "Quickshell" and "file-and-image-renamer" sections should note the watcher is now a system service, not a HM user service.

9. **Correct the prior status report** — The placeholder API key claim should be retracted or annotated.

---

## F) Up to 50 Things to Get Done Next

### High Priority (Blocking / Safety)

1. ~~Deploy the fixed config~~ DONE — config is live
2. Commit `flake.nix` formatting changes (pure alejandra, 275 ins / 279 del)
3. Commit `flake.lock` updates (go-cqrs-lite + PMA input bumps)
4. Commit `modules/nixos/services/file-and-image-renamer.nix` (watcher → system service)
5. Audit ALL flake inputs for `inputs.nixpkgs.follows` — grep every input
6. Fix deploy script exit code 4 handling — treat as warning, continue to post-deploy-check
7. Add Gatus health check for renamer watcher (`http://localhost:8086/status`)
8. Add Gatus alert for watcher liveness (process count or health endpoint)
9. Verify `renamer.home.lan` is in dnsblockd localSubdomains
10. Verify Caddy vHost for `renamer.home.lan` exists and uses `proxyTo`
11. Add Homepage tile for renamer (link to `renamer.home.lan`)

### Medium Priority (Quality / Hardening)

12. Add OTel tracing verification for renamer (check if traces appear in SigNoz)
13. Add `restartTriggers` for renamer package (prevents stale binary after GC)
14. Add BFQ I/O tier for renamer watcher (`ioTier.background` or `ioTier.service`)
15. Add backup-coordination entry if renamer state (`~/.file-renamer/`) needs backup
16. Consider adding a systemd watchdog (`WatchdogSec`) if the binary supports `sd_notify`
17. Verify `ProtectHome = "read-only"` doesn't break inotify on watched directories
18. Add pre-deploy vendorHash batch test to `pre-deploy-check.sh` for Go FODs
19. Document the system-service conversion pattern in AGENTS.md
20. Consider extracting the renamer's `_FILE` env pattern as a reusable sops helper
21. Review whether crush-daily should also switch to `_FILE` pattern (security improvement)
22. Add memory/performance metrics for renamer to system-health textfile collector

### Low Priority (Cleanup / Tech Debt)

23. Rename `mkKeyedSecrets` to something clearer (e.g., `mkAliasedSecrets`)
24. Add eval-time assertion that renamer watcher + health use the same `dataDir`
25. Consider unifying the renamer env vars (HISTORY_FILE_PATH, HASHDB_PATH, etc.) into a single env file
26. Add a renamer CLI quick-start to AGENTS.md (how to query history, dead-letter, etc.)
27. Consider adding a `--dry-run` mode to the watcher for testing without API calls
28. Review whether the `DESKTOP_PATH` env var is still needed (legacy from Desktop-only watching)
29. Consider adding a dead-letter retry mechanism (currently 1 pending, 0 retrying)
30. Add log rotation guidance for `~/.file-renamer/logs/`
31. Consider adding file-type filtering (only rename images, not PDFs in Downloads)
32. Review the quality scoring threshold (currently EXCELLENT 80+ = skip)
33. Consider adding a max-file-size limit to prevent renaming large downloads
34. Add a systemd timer to periodically clean old history entries
35. Consider adding notification on successful rename (via DMS IPC or similar)
36. Review whether `WorkingDirectory = cfg.watchDirectory` is needed (it's Desktop by default)
37. Consider adding `OOMPolicy=kill` to ensure clean restart on OOM
38. Review `KillMode = "mixed"` — is it correct for a watcher with child processes?
39. Consider adding `RestartPreventExitStatus` for expected exit codes
40. Add integration test for the renamer module in `tests/`
41. Consider adding a `systemd.tmpfiles.rules` entry for the watch directories
42. Review whether the 512M MemoryMax is sufficient for large image batches
43. Consider adding rate limiting to prevent API cost spikes
44. Add a cost monitoring metric (total_cost from history.json) to Gatus or Prometheus
45. Consider adding multi-model fallback (if Synthetic is down, try ZAI or llama.cpp)
46. Review the `startLimitBurst = 5` — is it sufficient for a watcher that may crash-loop?
47. Consider adding a `User` systemd hardening review (does it need `video`/`input` groups?)
48. Add the renamer to the `backup-coordination` module if state matters
49. Consider adding a `systemd.tmpfiles.rules` cleanup for old log files
50. Review whether `StandardOutput = "journal"` is sufficient or if structured logging is needed

---

## G) Questions (Cannot Figure Out Myself)

### Q1: Should the deploy script treat `nh os switch` exit code 4 as success?

The deploy failed twice due to exit code 4 (`switch-to-configuration` couldn't connect to dbus for `monitor365` UID 966 and `sddm` UID 175 user sessions). The config DID activate — all services started, new generation is live. But the deploy script aborted, skipping post-deploy-check and explicit service restarts.

**Should I change `scripts/deploy.sh` to treat exit code 4 as a warning and continue?** Or is this masking a real problem (services that need dbus user session reload)?

### Q2: Should the renamer watcher run with `ioTier.background` or `ioTier.service`?

The watcher does periodic file I/O (inotify, hashing, SQLite writes) and occasional network I/O (API calls). On the QLC NVMe, I/O scheduling matters. Background (BE/6) would yield to most services. Service (BE/4) is the default. Given that renamer is not latency-sensitive (a 5-second delay on a rename is invisible to the user), I'd pick `ioTier.background` — but I want to confirm.

### Q3: Should I commit the upstream vendorHash fixes as part of SystemNix, or are they already correctly tracked?

I pushed vendorHash fixes to `go-cqrs-lite` (commit `9d92d91`) and pushed an already-existing commit in `projects-management-automation` (`a383c381`). Both are now reflected in SystemNix's `flake.lock`. The SystemNix changes (`flake.lock` + `file-and-image-renamer.nix`) are uncommitted. Should I commit them now as a single "deploy renamer fix" commit, or wait for the formatting changes and other pending work to be committed separately?

---

## Session Metrics

| Metric                     | Value                                                                                       |
| -------------------------- | ------------------------------------------------------------------------------------------- |
| Files modified (SystemNix) | 2 (`file-and-image-renamer.nix`, `flake.lock`)                                              |
| Files modified (upstream)  | 1 (`go-cqrs-lite/flake.nix`)                                                                |
| Upstream repos pushed      | 2 (`go-cqrs-lite`, `projects-management-automation`)                                        |
| Failed deploys             | 2 (vendorHash mismatches)                                                                   |
| Successful deploys         | 1                                                                                           |
| Test images renamed        | 2 (`test-screenshot-for-renamer.png` skipped, `untitled.png` → `solid-blue-background.png`) |
| API calls verified         | 1 (glm-4.6v, 764 tokens, $0.0004)                                                           |
| Root causes fixed          | 1 (watcher graphical-session binding)                                                       |
| Root causes disproved      | 1 (placeholder API key — was real key)                                                      |

---

## Key Takeaway

**The sops setup was fine. The watcher was dead because it was bound to graphical-session.target.** The "placeholder API key" was a misread of the `mkKeyedSecrets` YAML key name. The fix was converting the watcher from a HM user service to a system service — a one-file change that took 2 minutes to write but required understanding the full secret chain first.

_"Status reports are point-in-time, not living documents. Verify before treating as truth."_
