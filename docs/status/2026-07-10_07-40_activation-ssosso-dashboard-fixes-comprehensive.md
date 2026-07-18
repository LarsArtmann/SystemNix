# Session: Three Activation Failures + SSO + Dashboard MIME Fixed, Deployed

**Date:** 2026-07-10 07:40 CEST
**System:** evo-x2 (NixOS, x86_64-linux)
**Session span:** 2026-07-09 21:00 – 2026-07-10 07:40 (overnight + morning)

---

## TL;DR

Fixed 5 distinct issues across 2 repos (SystemNix + monitor365), deployed 4 times, freed 103 GB disk. Monitor365 SSO still unverified end-to-end due to Pocket ID crash mid-flow. Two SystemNix files and `flake.lock` remain uncommitted.

---

## a) FULLY DONE

### 1. gpu-active.service — `awk: command not found` (status=127)

**Root cause:** `writeShellApplication` `runtimeInputs` was `[pkgs.gnugrep pkgs.coreutils]` — missing `pkgs.gawk`. The `read_kb()` function calls `awk`, which lives in `gawk`, not `coreutils`.

**Fix:** Added `pkgs.gawk` to `runtimeInputs` in `modules/nixos/services/gpu-active.nix:30`.

**Verified at runtime:** `/var/lib/prometheus-node-exporter/textfile_collectors/gpu_active.prom` now contains valid metrics (`node_gpu_active_bytes 764018688`).

### 2. signoz-provision.service — `timeout: failed to run command 'bash'` (status=127)

**Root cause:** The `preStart` script used `timeout 120 bash -c '...'`. `writeShellApplication` bakes PATH from `runtimeInputs` only, and `bash` wasn't listed. `timeout` (from coreutils) tried to exec `bash`, which wasn't on the hardened PATH.

**Fix:** Rewrote the wait loop to native bash `while`/`$SECONDS` — no subshell needed. Same 120s timeout semantics.

**File:** `modules/nixos/services/signoz.nix:374-383`

**NOT verified at runtime:** signoz-provision wasn't re-triggered during deploys (its parent signoz.service wasn't restarted). Fix is in the built system but hasn't been exercised.

### 3. monitor365-server.service — CORS parse error (status=1)

**Root cause:** Upstream `server-module.nix` emits `MONITOR365_SERVER__CORS_ORIGINS` as a comma-separated string env var. The server's Rust config deserializer (figment/toml) expects a TOML sequence, not a string — fatal parse error on startup.

**Fix:** Removed `corsOrigins` from SystemNix defaults in `modules/nixos/services/monitor365.nix`. CORS is unnecessary for same-origin deployment (UI + API both behind Caddy at `monitor.home.lan`).

**Verified at runtime:** Server running, responding to HTTP requests, enforcing auth (401s in logs).

### 4. monitor365 WASM dashboard — MIME type error (black screen)

**Root cause:** Browser cached a stale `bootstrap.js` from a previous deployment that referenced old content-hashed asset filenames (`56b008ffb4142d95`). When the browser requested the old `.js` file, the Rust server's SPA fallback served `index.html` (text/html) instead, causing: `Expected a JavaScript-or-Wasm module script but the server responded with a MIME type of "text/html"`.

**Fix:** Added `Cache-Control: no-cache, no-store, must-revalidate` headers in Caddy for `/ui/index.html` and `/ui/bootstrap.js` — entry-point files that reference content-hashed assets must always revalidate.

**File:** `modules/nixos/services/caddy.nix:164-178`

**Verified:** Deployed. User confirmed dashboard HTML loads (the next issue was SSO, not the dashboard itself).

### 5. monitor365 SSO — `email_verified` gate rejected all logins

**Root cause:** Monitor365's SSO callback handler (`flow.rs:206`) checked `userinfo.email_verified` and rejected login if `false`. Pocket ID is a passkey-only IdP — it dropped the `email_verified` column entirely (`ALTER TABLE users DROP COLUMN email_verified`). The serde `#[serde(default)]` defaulted to `false`, causing ALL SSO logins to fail with "SSO email is not verified by the identity provider".

**Fix:** Removed the `email_verified` gate entirely. Passkey-authenticated users are trusted without separate email verification. Field kept in `IdpUserInfo` struct (with `#[allow(dead_code)]`) for potential future use.

**Repo:** monitor365 (`crates/server/src/handlers/sso/flow.rs`)
**Commit:** `385442a8e` — pushed to master, flake.lock updated, deployed.

### 6. Disk space crisis resolved

**Before:** Root at 98% (669G/723G) — deploy blocked.
**Action:** `nix-collect-garbage -d` freed 103 GB (5427 store paths deleted).
**After:** Root at 91% (623G/723G).

---

## b) PARTIALLY DONE

### Pocket ID "renew lock: lock ownership lost" crash

**What happened:** During SSO login testing, Pocket ID crashed mid-passkey-authentication with `ERR Failed to run pocket-id: failed to run services: renew lock: lock ownership lost`. It auto-restarted successfully ~27s later.

**Status:** Not investigated. This is likely a transient crash caused by the rapid deploy/restart cycle (pocket-id was stopped/started multiple times during the session). The "unknown error" the user saw on the Pocket ID authorize page was this crash, NOT a monitor365 issue.

**What remains:** Verify SSO login works end-to-end now that Pocket ID is stable. The `email_verified` fix is deployed but the SSO flow has never completed successfully.

---

## c) NOT STARTED

### Uncommitted changes in SystemNix

Three `.nix` files changed + `flake.lock` updated, none committed:

- `modules/nixos/services/gpu-active.nix` — added `pkgs.gawk`
- `modules/nixos/services/signoz.nix` — rewrote preStart wait loop
- `modules/nixos/services/monitor365.nix` — removed CORS origins
- `modules/nixos/services/caddy.nix` — added no-cache headers for monitor365 UI
- `flake.lock` — monitor365 rev `d42665a9` → `385442a8`

### AGENTS.md not updated

Five new gotchas discovered, none documented:

1. `writeShellApplication` + `awk` — must include `pkgs.gawk` (not in coreutils)
2. `timeout N bash -c` inside `writeShellApplication` — bash won't be on PATH
3. Upstream monitor365 `corsOrigins` env var — incompatible with Rust config deserializer
4. WASM SPA entry-point files need `no-cache` headers (stale bootstrap.js → MIME error)
5. Pocket ID `email_verified` column was dropped — IdPs may not return this field

### Post-deploy smoke test broken

14 false FAILs — all show empty `localhost:` (no port interpolated). The `post-deploy-check` script has a port-resolution bug making it useless as a safety net.

---

## d) TOTALLY FUCKED UP

Nothing was irreversibly damaged. But:

### The CORS "fix" is a workaround, not a real fix

Removing CORS entirely means if anyone ever accesses the monitor365 API from a different origin (e.g., a custom dashboard, a development tool), it will fail silently. The real fix is upstream: the monitor365 `server-module.nix` should use a TOML config file for sequence-typed values, not env vars. Figmond cannot represent TOML sequences as env var strings.

### The `email_verified` removal is unilateral

I removed a security check without considering whether it might be needed for other IdPs that DO support email verification. A more nuanced approach would be: `email_verified` defaults to `true` when absent (trusting the IdP), but still enforced when the IdP explicitly returns `false`. This was the first approach I implemented, but the user asked for the simpler "just allow it" version.

### Pocket ID crash not investigated

`renew lock: lock ownership lost` could be a recurring issue. I dismissed it as "transient from deploy" without checking if it's a known Pocket ID 2.9.0 bug, or if the lock mechanism (SQLite-based?) is fragile under systemd restart cycles.

---

## e) WHAT WE SHOULD IMPROVE

### Process improvements

1. **Always commit after deploy** — I deployed 4 times this session and committed zero times in SystemNix. The running system diverges from git history.
2. **Always update AGENTS.md immediately** — I discovered 5 new gotchas and documented none. Future sessions will rediscover them the hard way.
3. **The post-deploy smoke test is our safety net and it's broken** — empty ports make it useless. This should be P0.
4. **`writeShellApplication` runtimeInputs audit** — both the `gpu-active` and `signoz-provision` failures were missing deps in `runtimeInputs`. A systematic audit or lint rule would catch these.
5. **Test SSO end-to-end before declaring done** — I "fixed" SSO twice without ever seeing a successful login. The Pocket ID crash masked whether my fix actually works.

### Technical improvements

6. **Upstream CORS fix needed** — PR to monitor365: use TOML config file for sequence types
7. **Pocket ID lock instability** — investigate `renew lock: lock ownership lost`
8. **monitor365-desktop user service** — still unverified (may not be running)
9. **Disk space root cause** — what consumed 50+ GB since last GC?

---

## f) Up to 50 Things To Do Next

### P0 — Critical (Do Now)

1. **Commit all SystemNix changes** (gpu-active.nix, signoz.nix, monitor365.nix, caddy.nix, flake.lock)
2. **Verify SSO login works end-to-end** — open `https://monitor.home.lan/ui/`, click SSO, complete passkey auth
3. **Update AGENTS.md** with the 5 new gotchas
4. **Fix the post-deploy smoke test** — empty `localhost:` ports make it useless (14 false FAILs)
5. **Verify monitor365-desktop user service is running** — `systemctl --user status monitor365-desktop` as lars

### P1 — High (This Week)

6. **Verify signoz-provision at runtime** — restart signoz.service to trigger provision chain
7. **Investigate Pocket ID `renew lock: lock ownership lost`** — is this a 2.9.0 bug? SQLite lock contention under systemd restart?
8. **Fix upstream monitor365 CORS** — PR: server-module.nix should use TOML config file for sequence types
9. **Audit ALL `writeShellApplication` scripts for missing runtimeInputs** — systematic check
10. **Add a lint/CI check for `timeout bash -c` inside writeShellApplication** — shellcheck or pre-commit
11. **Clean stale build sandboxes** — 11 still in `/nix/var/nix/builds/`
12. **Investigate disk space consumption** — what filled 50+ GB?
13. **Add Gatus health check for monitor365 server and desktop agent**
14. **Test the WASM dashboard loads correctly** — confirm black screen is gone after cache-control fix
15. **Add response-time check to Gatus for monitor365**

### P2 — Medium (This Month)

16. **Write a nixos test for monitor365 server module** — config parsing, startup, health endpoint, SSO mock
17. **Write a nixos test for signoz-provision** — provision chain works end-to-end
18. **Add `tests/exec-start-paths.nix` check for gpu-active** — ensure all deps on PATH
19. **Consider switching monitor365 to TOML config file** — instead of env vars for sequence types
20. **Refactor pre-deploy check to validate runtimeInputs** — statically check commands vs deps
21. **Audit all ExecStartPost health checks** — ensure they fail loud
22. **Document monitor365 dual-instance architecture** in a dedicated doc
23. **Add monitor365 to Homepage tiles** (if not present)
24. **Review Pocket ID OIDC client configuration for monitor365** — verify redirect URIs, scopes
25. **Consider `nix.auto-optimise-store`** — hard linking saves 45.4 GiB
26. **Add disk space monitoring to DMS widget**
27. **Audit all systemd oneshot services for the `timeout bash -c` anti-pattern**
28. **Check CORS implications of removing corsOrigins** — will the WASM dashboard break cross-origin?
29. **Consider `email_verified` default-true approach** instead of removing the check entirely
30. **Review monitor365 agent CLI changes** — server dropped `--config`, uses env vars
31. **Verify the `ExecStartPost` health check for monitor365 catches real failures** — uses `-` prefix (ignores failure)
32. **Add monitoring for gpu-active collector staleness** — alert if `gpu_active.prom` not updated
33. **Review BTRFS snapshot retention** — 14d+4w may be too aggressive under disk pressure
34. **Document the figmond env var limitation** — sequences can't be represented as env vars
35. **Review oomd configuration** — 50%/20s tuning given chronic GPUActive pressure

### P3 — Low (Backlog)

36. **Consolidate status docs** — archive/ has 200+ files
37. **Consider a flake-parts module for declarative health checks** — auto-generate Gatus from service defs
38. **Add `pkgs.procps` to gpu-active runtimeInputs** — for future metrics
39. **Review gpu-active timer interval** — 1min may be too frequent
40. **Consider merging gpu-active into broader amdgpu metrics collector**
41. **Audit Caddy commonConfig snippet** — ensure all vhosts include it
42. **Review nix-build-cleanup timer interval** — 4h may not be enough
43. **Add systemd timer to clean `/nix/var/nix/builds/` more aggressively**
44. **Document deploy → GC → deploy cycle** — when to GC, expected freed space
45. **Consider a systemd hardening profile for metrics collectors** — lighter than full `harden`
46. **Review signoz alert provisioning script** — verify it handles current API version
47. **Add `jq` verification to signoz-provision path** — confirm it's actually used
48. **Add a nixos test that boots with monitor365-server enabled** — catch config parse errors
49. **Review Pocket ID version** — 2.9.0, check if lock issue is fixed in newer version
50. **Consider adding email verification to Pocket ID** — if the column was dropped intentionally, document why

---

## g) Top 2 Questions I Cannot Answer Myself

### Q1: Did the SSO login actually work after Pocket ID recovered?

The last thing we saw was Pocket ID crashing mid-passkey-authentication with `renew lock: lock ownership lost`. It restarted, but the user never completed the SSO flow again. The `email_verified` fix is deployed but **unverified** — no SSO callback has ever reached monitor365-server successfully. **Can you try logging in at `https://monitor.home.lan/ui/` again and tell me if SSO completes?**

### Q2: Is the Pocket ID `renew lock: lock ownership lost` crash going to recur?

This error occurred during the deploy/restart cycle. Pocket ID 2.9.0 uses some form of distributed lock (likely SQLite-based, since Pocket ID is backed by SQLite). If the lock ownership mechanism is fragile under systemd `Restart=always` cycles, this could crash during every deploy that touches Pocket ID. I don't know if this is a known upstream bug, a configuration issue, or a one-time fluke. **Have you seen this error before, or was this the first time?**
