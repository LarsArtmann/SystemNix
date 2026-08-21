# Status: systemd-graph + systemd-timer-monitor — Package Fixes, Partial Deploy, HTTPS Broken

**Date:** 2026-08-19 17:49 CEST
**Session start:** ~17:25 (resumed from prior session's blocked state)
**Prior session doc:** `docs/status/2026-08-19_17-04_systemd-review-tools-graph-timer-monitor-packaging.md`

---

## Executive Summary

Fixed all three systemd-graph package build blockers (pnpm hook, vendorHash, binary name). Both packages now build cleanly and `nix flake check --no-build` passes. Attempted deploy twice — **both failed**. The first attempt hit a stale `switch-to-configuration` lock from a prior session; the second was interrupted by the user's status request. The first deploy **partially activated**: systemd-graph is running and serving the SPA on `:8847`, Caddy has the new vHosts in its config and serves graph over HTTP, but **HTTPS is broken system-wide** (TLS internal error on ALL vHosts, not just ours) and `/run/current-system` still points to the old generation. The system is in a **partial activation state** that a clean deploy should fix, but the lock must be cleared first.

---

## a) FULLY DONE

| Item                                  | Evidence                                                                                                                                    |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **systemd-graph webui builds**        | `nix build .#systemd-graph-webui` → `/nix/store/h5ppq2zzvkclww5n1lnvk3jlw86iappa-…` with `dist/{index.html,assets/,favicon.svg,icons.svg}`  |
| **systemd-graph Go binary builds**    | `nix build .#systemd-graph` → `/nix/store/z45y0jsdbf59…/bin/systemd-graph`, `--help` prints `-addr string listen address (default ":8080")` |
| **vendorHash computed**               | `sha256-Ac63bZlBvCrhS7b8mk7aJdApI8UGtJxnZG35L37roGY=` (was empty `""`)                                                                      |
| **Binary renamed**                    | `postInstall` renames `bin/server` → `bin/systemd-graph` to match `meta.mainProgram` so `lib.getExe` resolves                               |
| **restartTriggers added**             | `modules/nixos/services/systemd-graph.nix:58` — `restartTriggers = [ cfg.package ]`                                                         |
| **DNS subdomains registered**         | `platforms/common/dns-local.nix` — added `"graph"` and `"timers"` to `localSubdomains`                                                      |
| **nix flake check --no-build passes** | "all checks passed!" (run twice, before and after DNS addition)                                                                             |
| **systemd-timer-monitor package**     | Was already done from prior session — pure Python, zero deps, builds to `/nix/store/1szzv1113shqw2qs693yx77r43rkf2v8-…`                     |
| **Both NixOS modules eval cleanly**   | `nix eval` confirms ExecStart paths for both services + Caddy vHosts `['graph.home.lan', 'timers.home.lan']`                                |
| **systemd-graph IS RUNNING live**     | PID 2620577, serving `http://127.0.0.1:8847/` → 200/455B (React SPA), `/api/snapshot` → 200/698KB (D-Bus data)                              |
| **Caddy has both vHosts**             | Config on disk includes `graph.home.lan` + `timers.home.lan` blocks with `tlsConfig`, `commonConfig`, `proxyTo` / `file_server`             |
| **HTTP graph.home.lan works**         | `http://192.168.1.150/` with `Host: graph.home.lan` → 200/455B (the SPA)                                                                    |

---

## b) PARTIALLY DONE

| Item                        | State                                                                                                                                                                                                                                                                                      | What's missing                                                                                                                                                                                                            |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Deploy**                  | First deploy partially activated (unit files copied, some services started), but `/run/current-system` still → gen 695 (old). Second deploy never ran (interrupted).                                                                                                                       | A clean `nix run .#deploy` after clearing the stale lock file. The lock at `/run/nixos/switch-to-configuration.lock` is free (no process holds it) but the file still exists.                                             |
| **HTTPS / TLS**             | Caddy is running (PID 2684150) with admin API on :2019, configured to listen on `192.168.1.150:80` and `:443`. HTTP works. **HTTPS is broken system-wide** — `tlsv1 alert internal error` on ALL vHosts (auth.home.lan, dash.home.lan, graph.home.lan — all fail identically).             | The partial activation may have restarted Caddy before sops rendered the cert, or the cert config path changed. A clean deploy (which includes `sudo systemctl restart caddy.service` per deploy.sh:137) should fix this. |
| **timer-monitor state dir** | `/var/lib/systemd-timer-monitor/` exists (created by partial activation's tmpfiles) but is **empty** — no `report.html`, no `status.json`, no `.last-run`. The timer hasn't fired yet (OnBootSec=2min, and systemd may not have loaded the timer unit properly during partial activation). | A clean deploy would start the timer, which fires after 2 min and writes the audit.                                                                                                                                       |
| **timers.home.lan**         | Returns 404 on HTTP (Caddy file_server has no files to serve).                                                                                                                                                                                                                             | Will resolve once the timer fires and writes `report.html`.                                                                                                                                                               |

---

## c) NOT STARTED

| Item                        | Why                                                                                       |
| --------------------------- | ----------------------------------------------------------------------------------------- |
| **Gatus health checks**     | Not added to `gatus-config.nix` yet                                                       |
| **Post-deploy smoke tests** | Not added to `scripts/post-deploy-check.sh`                                               |
| **Homepage tiles**          | Not added to `homepage.nix` (under "Review Tools" group)                                  |
| **Service docs**            | `docs/services/systemd-graph.md` and `docs/services/systemd-timer-monitor.md` not written |
| **AGENTS.md update**        | "Other Services" section and SSO table not updated                                        |

---

## d) TOTALLY FUCKED UP

### 1. The Root Cause of the Webui Build Failure (Previous Session)

**The bug was `dontConfigure = true`.** The previous session added `pnpmConfigHook` to `nativeBuildInputs` (correct) but then set `dontConfigure = true` (wrong) and hand-rolled `pnpm install` in `buildPhase` (fighting the hook).

`pnpmConfigHook` is registered in `postConfigureHooks` — it fires during the **configure** phase, not the build phase. Setting `dontConfigure = true` skips the entire configure phase, so `pnpmConfigHook` **never ran**. The hand-rolled `pnpm install` in buildPhase then tried to install deps manually, but:

1. It used `--config.verify-deps-before-run=false` which is a pnpm 11 **run-time** check, not the **install-time** supply-chain verification
2. It didn't set `--offline` (pnpmConfigHook does this)
3. It didn't set `pnpm_config_trust_lockfile=true` (pnpmConfigHook does this for pnpm 11)
4. It didn't set `store-dir` to the offline store from `fetchPnpmDeps` (pnpmConfigHook does this)

So pnpm tried to fetch metadata from `registry.npmjs.org` in the Nix sandbox (DNS blocked) → `ERR_PNPM_META_FETCH_FAIL` → 6 failed attempts across the prior session.

**The fix was 3 lines**: Remove `dontConfigure = true`, remove the hand-rolled `pnpm install` from buildPhase, keep only `pnpm build` in buildPhase. `pnpmConfigHook` handles everything else automatically.

**Lesson:** When a Nix build hook exists, let it do its job. Don't bypass the configure phase and then try to replicate the hook's work manually in the build phase. Read the hook's source (`nix build nixpkgs#pnpm.configHook && cat .../nix-support/setup-hook`) to understand what it does and what phase it runs in.

### 2. The Binary Name Mismatch

`buildGoModule` with `subPackages = ["cmd/server"]` produces a binary named `server` (the source directory name), NOT `systemd-graph` (the pname). `meta.mainProgram = "systemd-graph"` is just metadata — it doesn't rename the binary. `lib.getExe` in the NixOS module resolves to `$out/bin/systemd-graph` which didn't exist → the service would fail with "no such file" if the deploy had completed. Fixed with `postInstall = 'mv $out/bin/server $out/bin/systemd-graph'`.

**Lesson:** Always verify the binary name with `ls $out/bin/` after building a Go package. `subPackages` dir name = binary name, not `pname`.

### 3. The Stale Lock (Not My Fault, But I Should Have Caught It)

The lock file `/run/nixos/switch-to-configuration.lock` existed from a prior session's deploy at 12:46 (timestamp on the file). The processes that created it were already dead. deploy.sh's wedged-lock detection checks for live processes older than 30 min via `pgrep` + `ps -o etimes=` — but since the processes were dead, `pgrep` returned nothing, the loop didn't find any wedged PIDs, and deploy.sh proceeded to call `nh os switch`, which then failed with `exit 11 "Could not acquire lock"` because the lock FILE still existed.

deploy.sh's detection is correct for live wedged processes, but it doesn't handle the case where the process died and left a stale lock file. The lock file is an `flock` — when the holding process dies, the lock is released, but the FILE persists. `nh` / `switch-to-configuration` should handle this by treating the lock as acquireable when no process holds it, but it appears to check file existence rather than flock state (or the flock is on the file descriptor, and the next process can't acquire it because the file exists but isn't locked — this needs investigation).

**Fix that was needed but not done:** Remove the stale lock file before retrying: `sudo rm /run/nixos/switch-to-configuration.lock` (or just retry deploy, which should work since the lock is advisory and the flock is released).

### 4. The Partial Activation State

The first deploy's `switch-to-configuration test` partially ran before getting wedged. It:

- Copied unit files to `/etc/systemd/system/` (systemd-graph.service, systemd-timer-monitor-audit.service, systemd-timer-monitor-audit.timer)
- Started systemd-graph.service (PID 2620577, running from the new store path)
- Restarted Caddy with the new config (vHosts include graph.home.lan, timers.home.lan)
- Created `/var/lib/systemd-timer-monitor/` via tmpfiles

But it **never completed**:

- `/run/current-system` still → gen 695 (old generation `2jxmi57l`)
- The system profile was never updated to gen 697
- HTTPS is broken system-wide (Caddy restarted but TLS is broken — likely cert issue from incomplete sops rendering)
- The timer-monitor timer was never started by systemd (the unit file exists on disk but may not be loaded)

This is a dangerous state: the system is running a mix of old generation (profile, current-system) and new unit files (on disk, partially loaded by systemd). A clean deploy would fix this by atomically switching to the new generation.

### 5. What I Forgot During the Deploy

1. **I didn't check for the stale lock before the first deploy.** I should have checked `ls /run/nixos/switch-to-configuration.lock` and `fuser` on it before running `nix run .#deploy`. The deploy.sh detection only catches LIVE wedged processes, not stale lock files from dead processes.

2. **I didn't add the timer-monitor to the deploy.sh provisioner restart list.** The timer uses a systemd timer (not a provisioner oneshot), so this might not be needed — but if the timer doesn't fire after a deploy, an explicit `systemctl start systemd-timer-monitor-audit.timer` might be needed. I should verify this after the next deploy.

3. **I didn't verify HTTPS worked before deploying.** I assumed the wildcard `*.home.lan` cert would cover the new subdomains (it should — it's a wildcard), but I never confirmed the cert was actually a wildcard vs. a SAN list. The TLS internal error on ALL vHosts (including pre-existing ones like auth.home.lan) suggests this is a Caddy restart issue, not a cert SAN issue — but I should have verified.

---

## e) WHAT WE SHOULD IMPROVE

1. **deploy.sh stale-lock detection should check for orphaned lock FILES, not just live processes.** The current check (`pgrep -f 'switch-to-configuration'` + age >30min) misses the case where the process died and left the file. Add: if the lock file exists but no process holds it (`fuser` returns nothing), remove it before proceeding.

2. **The `dontConfigure = true` + `pnpmConfigHook` conflict should be documented in AGENTS.md.** This is a general Nix gotcha: `postConfigureHooks` are skipped by `dontConfigure`, silently disabling any setup hook that lives there (pnpmConfigHook, npmConfigHook, etc.). The symptom is "deps not installed" with no error message — the build proceeds against an empty `node_modules` and either fails mysteriously or produces a broken output.

3. **buildGoModule binary naming should be verified before deploying.** `subPackages = ["cmd/foo"]` → binary named `foo`, not `pname`. Always `ls $out/bin/` after building. Add to AGENTS.md "Other Services" gotchas.

4. **DNS subdomains should be checked BEFORE deploying new vHosts.** I caught this just in time (added graph/timers to dns-local.nix before the first deploy), but it should be a checklist item: "New subdomain? → Add to `platforms/common/dns-local.nix` BEFORE deploying."

5. **The partial activation state is dangerous and should be recoverable.** A deploy that fails during `switch-to-configuration` can leave the system with new unit files on disk but an old generation active. deploy.sh should detect this (compare `/run/current-system` to the built toplevel) and warn the user.

6. **`fetchPnpmDeps` doesn't honor `sourceRoot`** — this is already documented in the prior session's status report but should be in AGENTS.md. For pnpm in a subdirectory, pass `src = "${finalAttrs.src}/subdir"` to `fetchPnpmDeps`.

7. **The prior session spent 6 attempts trying to fix the pnpm build without reading the `pnpmConfigHook` source.** Reading the hook source (`nix build nixpkgs#pnpm.configHook && cat .../nix-support/setup-hook`) immediately reveals that it runs in `postConfigure`, uses `--offline`, sets `trust_lockfile`, and handles the store-dir. This should be the first debugging step for any Nix build hook issue: read the hook's setup-hook script.

---

## f) Up to 50 Things to Do Next

### Immediate (blocking — do before anything else)

1. **Clear the stale lock file** — `sudo rm /run/nixos/switch-to-configuration.lock` (verify no process holds it first with `fuser`)
2. **Retry `nix run .#deploy`** — should complete now that the lock is cleared
3. **Verify `/run/current-system` points to the new generation** after deploy
4. **Verify HTTPS works on ALL vHosts** (not just graph/timers) — `python3 -c "import urllib.request, ssl; ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE; r=urllib.request.urlopen('https://192.168.1.150/', headers={'Host':'auth.home.lan'}, context=ctx, timeout=5); print(r.status)"`
5. **Verify `https://graph.home.lan/`** returns 200 with the React SPA
6. **Verify `https://timers.home.lan/`** returns 200 with the audit HTML (may need to wait 2 min for the timer to fire, or manually trigger: `sudo systemctl start systemd-timer-monitor-audit.service`)
7. **Check `systemctl --failed`** for any units that failed during activation
8. **If HTTPS is still broken after clean deploy**, check Caddy logs: `sudo journalctl -u caddy.service -n 50 --no-pager` and verify sops rendered the cert: `ls -la /run/secrets/dnsblockd_server_cert`

### Post-deploy verification

9. **Verify the timer fires and writes report.html** — check `/var/lib/systemd-timer-monitor/report.html` exists after 2 min
10. **Verify `timers.home.lan/report.html`** returns the HTML audit via HTTPS
11. **Verify `timers.home.lan/status.json`** returns the JSON audit
12. **Verify `graph.home.lan/api/snapshot`** returns 200 with JSON D-Bus data (~700KB)
13. **Verify `graph.home.lan/api/events`** SSE stream is live (if the upstream supports it)

### Monitoring

14. **Add Gatus health check for `graph.home.lan`** — `mkHttpCheck` with `[STATUS] == 200` + `[BODY] == pat(*<html*)` (liveness + HTML body check)
15. **Add Gatus health check for `timers.home.lan`** — `mkHttpCheck` with `[STATUS] == 200` + a body check for a known audit HTML string (e.g., `pat(*systemd*audit*)` or similar)
16. **Add `discordAlert`** to both Gatus checks if failure should notify
17. **Add `[RESPONSE_TIME] < 500`** to the graph check (it serves from memory, should be fast)
18. **Consider a freshness check for timers** — alert if `/var/lib/systemd-timer-monitor/.last-run` mtime is >10 min old (timer is 5 min, so >10 min = 2 missed runs)

### Post-deploy smoke tests

19. **Add smoke test for `graph.home.lan`** in `scripts/post-deploy-check.sh` — HTTP 200 + body contains `<html` or `systemd-graph`
20. **Add smoke test for `timers.home.lan`** in `scripts/post-deploy-check.sh` — HTTP 200 (or 404 if timer hasn't run yet — make it a soft check or wait for the timer)
21. **Gate both smoke tests with `systemctl is-enabled` checks** per the AGENTS.md pattern (`test -e /etc/systemd/system/<unit>.service`)

### Homepage tiles

22. **Add a "Review Tools" group** to `modules/nixos/services/homepage.nix` `groups` list
23. **Add a Homepage tile for systemd-graph** — `mkService "graph" "Systemd Graph" "https://graph.home.lan"` with a graph icon
24. **Add a Homepage tile for systemd-timer-monitor** — `mkService "timers" "Timer Audit" "https://timers.home.lan"` with a timer/clock icon
25. **Guard both tiles with `lib.optional (config.services.systemd-graph.enable or false)`** etc.

### Documentation

26. **Write `docs/services/systemd-graph.md`** — purpose, architecture, how to use, known issues
27. **Write `docs/services/systemd-timer-monitor.md`** — purpose, interval, output files, how to read the audit
28. **Update `AGENTS.md` "Other Services" section** — add entries for both services with key gotchas
29. **Update `AGENTS.md` SSO table** — both are Layer 0 (LAN bypass, no auth) — add a new row or note
30. **Document the `dontConfigure` + `pnpmConfigHook` gotcha** in AGENTS.md Nix section
31. **Document the `buildGoModule` binary naming gotcha** in AGENTS.md Nix section
32. **Document the `fetchPnpmDeps` + `sourceRoot` gotcha** in AGENTS.md Nix section

### Code quality / hardening

33. **Add `restartTriggers` for the webui derivation** — if the webui is rebuilt, the Go package should rebuild too (already handled via `srcWithWebui` dependency chain, but verify)
34. **Consider making systemd-graph `Type=notify`** with sd_notify if the upstream supports it (for better startup detection) — check upstream source
35. **Add a `systemd-graph` health check endpoint** — the upstream already has `/api/snapshot` which returns 200, so this is available for monitoring
36. **Consider adding `WatchdogSec`** to systemd-graph if it calls `sd_notify` (check upstream) — per AGENTS.md, only if the binary actually sends `WATCHDOG=1`
37. **Verify DynamicUser D-Bus access** — the service connects to the system D-Bus as a dynamic user; verify it can read unit listings (the `/api/snapshot` 200/698KB response confirms this works)

### deploy.sh improvements

38. **Add stale-lock-file detection** to `scripts/deploy.sh` — if lock file exists but `fuser` shows no process, remove it before proceeding
39. **Add timer-monitor to the provisioner restart list** in deploy.sh:145 — or verify the timer auto-starts after deploy
40. **Add a post-deploy Caddy HTTPS probe** to deploy.sh — verify `https://auth.home.lan/` returns a valid TLS response after every deploy (would have caught the current HTTPS break immediately)

### Testing

41. **Write a VM test for systemd-graph** — `tests/test-systemd-graph.nix` that starts the service and probes `/api/snapshot`
42. **Write a VM test for systemd-timer-monitor** — `tests/test-systemd-timer-monitor.nix` that runs the audit and checks `report.html` exists
43. **Test the timer-monitor audit output** — verify the HTML contains expected sections (failed services, timer status)
44. **Test systemd-graph with no D-Bus** — verify the service handles D-Bus unavailable gracefully (should log error, not crash)

### Future enhancements

45. **Consider adding polkit rules** for systemd-timer-monitor so it can run as a non-root user (currently runs as root for accurate failed-unit counts)
46. **Consider a cron-based alert** from systemd-timer-monitor — the script supports `--quiet` with non-zero exit on issues; could wire to `onFailure`
47. **Consider adding systemd-graph to the OTel tracing pipeline** — set `OTEL_EXPORTER_OTLP_ENDPOINT` if the upstream supports it (unlikely — it's a simple Go app with no OTel instrumentation)
48. **Consider a read-only user for systemd-graph** instead of DynamicUser — if the D-Bus access pattern requires a stable user
49. **Evaluate if systemd-graph should be behind `protectedVHost`** — currently LAN-only no-auth; if external access is ever needed, add Layer 2 forward-auth
50. **Add both services to the `backup-coordination` module** — systemd-graph has no state, but timer-monitor writes `report.html` + `status.json` (low value, but consistent with the pattern)

---

## g) Questions I Cannot Answer Myself

### Q1: Should I clear the stale lock file and retry the deploy now, or do you want to investigate the partial activation state first?

The lock at `/run/nixos/switch-to-configuration.lock` is free (no process holds it) but the file exists. The system is in a partial state: gen 695 is active (`/run/current-system`), but new unit files are on disk and systemd-graph is running from the new store path. A clean deploy would fix this, but I want to confirm you're OK with me running `sudo rm /run/nixos/switch-to-configuration.lock && nix run .#deploy` without investigating the partial state further.

### Q2: Is the system-wide HTTPS break (TLS internal error on ALL vHosts) a known pre-existing issue, or did my partial deploy cause it?

I can't tell if HTTPS was broken BEFORE my deploy attempt or if the partial activation broke it. The Caddy process is running (PID 2684150, started 17:48 — during my deploy) with the new config, but TLS fails on all vHosts including pre-existing ones (auth.home.lan, dash.home.lan). The cert files exist (`/run/secrets/dnsblockd_server_cert`, 2211 bytes, owned by caddy:0400). This looks like Caddy restarted but didn't properly load the cert — possibly because sops-nix's activation script didn't complete during the partial activation. A clean deploy (which includes `sudo systemctl restart caddy.service`) should fix this, but I want to know if this was already broken before my session.

### Q3: Do you want me to fix the deploy.sh stale-lock detection (check for orphaned lock files, not just live processes) as part of this session, or should that be a separate task?

The current detection in `deploy.sh:24-50` only catches LIVE wedged processes (pgrep + age >30min). It misses the case I hit: the process died and left a stale lock file. The fix would be: after the live-process check, if the lock file still exists and `fuser` shows no process, remove it with a log message. This is a 5-line change but touches the deploy script, so I want to know if you want it done now or separately.

---

## Root Cause Analysis: The pnpmConfigHook Bug

The previous session's 6 failed attempts to build the systemd-graph webui all failed because of a single line: `dontConfigure = true`.

### How pnpmConfigHook works

```
pnpmConfigHook is in nativeBuildInputs
  → registered in postConfigureHooks (at the end of the setup-hook script)
  → runs during the stdenv "configure" phase
  → does: pnpm install --offline --ignore-scripts --frozen-lockfile
  → sets: pnpm_config_trust_lockfile=true (pnpm 11)
  → sets: store-dir to the offline store from pnpmDeps (fetchPnpmDeps)
  → exits
```

### What `dontConfigure = true` does

```
stdenv.mkDerivation with dontConfigure = true
  → skips the entire configure phase
  → postConfigureHooks NEVER fire
  → pnpmConfigHook NEVER runs
  → node_modules is EMPTY
```

### What the previous session did

```
dontConfigure = true       ← skips pnpmConfigHook
buildPhase = ''
  pnpm install --frozen-lockfile \
    --config.verify-deps-before-run=false \    ← pnpm 11 RUN-time check, not install-time
    --config.manage-package-manager-versions=false \
    --config.auto-install-peers=false
  pnpm build
''
  ← pnpm install tries to fetch from registry.npmjs.org
  ← Nix sandbox blocks DNS
  ← ERR_PNPM_META_FETCH_FAIL (17 min of retries)
```

### The fix

```
# Remove dontConfigure = true (let pnpmConfigHook run in configure phase)
# Remove hand-rolled pnpm install (pnpmConfigHook does it correctly)
buildPhase = ''
  runHook preBuild
  pnpm build          ← just build, deps already installed by the hook
  runHook postBuild
'';
```

**The fix was 3 lines. The bug was 1 line. The previous session spent 6 attempts and 17+ minutes because it didn't read the hook source.**

---

## Commit History (This Session)

| Commit     | Description                                                                     | Files                                                                                                        |
| ---------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `995f4f8d` | fix(systemd-graph): fix package build, binary name, and pnpm hook integration   | `modules/nixos/services/systemd-graph.nix`, `pkgs/systemd-graph/default.nix`, `pkgs/systemd-graph/webui.nix` |
| `b4eeaffa` | feat(dns): register graph and timers services in local DNS configuration        | `platforms/common/dns-local.nix`                                                                             |
| `276475a2` | docs(architecture): add RAG embedding and reranker architecture decision record | `docs/adr/…` (unrelated to this task)                                                                        |
| `64d6957f` | chore(deps): update flake.lock for file-and-image-renamer                       | `flake.lock` (unrelated)                                                                                     |
| `91181cd8` | chore(deps): update bank-sync and document CQRS read adapter fix                | `flake.lock`, `docs/status/…` (unrelated)                                                                    |

**Note:** Commits `276475a2`, `64d6957f`, `91181cd8` were auto-committed by the daemon or another session — they rode alongside my work. Only `995f4f8d` and `b4eeaffa` are from this session.

---

## Current System State

```
/run/current-system → /nix/store/2jxmi57l... (gen 695, OLD — before my session)
Latest profile: system-696-link → /nix/store/fz1qr9l6... (gen 696, also before my session)
My built toplevel: /nix/store/2gaqhm7a... (gen 697, NEVER ACTIVATED)

systemd-graph.service: RUNNING (PID 2620577, from new store path z45y0jsdbf59)
  - http://127.0.0.1:8847/ → 200/455B (React SPA) ✅
  - http://127.0.0.1:8847/api/snapshot → 200/698KB (D-Bus data) ✅

caddy.service: RUNNING (PID 2684150, from old store path sa981f149rjp)
  - Admin API :2019 → OPEN ✅
  - HTTP :80 → graph.home.lan 200/455B ✅, timers.home.lan 404 (no files yet) ⚠
  - HTTPS :443 → TLS internal error on ALL vHosts ❌ (system-wide break)

systemd-timer-monitor-audit.timer: unit file exists on disk, may not be loaded by systemd
systemd-timer-monitor-audit.service: unit file exists on disk, has not run
/var/lib/systemd-timer-monitor/: exists, EMPTY (no report.html)

Lock: /run/nixos/switch-to-configuration.lock exists, NO process holds it
```
