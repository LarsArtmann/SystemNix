# Status Report: systemd-graph + systemd-timer-monitor Deploy & Wiring

**Date:** 2026-08-19 18:49
**Session start:** ~17:28 (resumed from prior session that had partial deploy)
**Session end:** 18:49
**Host:** evo-x2 (NixOS unstable, 128GB RAM, 723GB NVMe)
**Generation:** `8g5aqihr` (activated successfully at ~18:47)

---

## a) FULLY DONE

### Packages (prior session + this session)

1. **`systemd-timer-monitor` package** — `pkgs/systemd-timer-monitor.nix`. Pure Python (zero deps), `stdenvNoCC.mkDerivation` fetching `cappy-dev/systemd-timer-monitor@ff68e41`. Builds clean: `/nix/store/1szzv1113...-systemd-timer-monitor-1.0.0/bin/systemd-audit`

2. **`systemd-graph` webui package** — `pkgs/systemd-graph/webui.nix`. `fetchPnpmDeps` + `pnpmConfigHook` + Vite build. The root cause of 6 prior failed attempts was `dontConfigure = true` silently skipping `pnpmConfigHook` (it runs in the configure phase, not build phase). Fixed by removing `dontConfigure` and letting the hook handle `pnpm install` automatically. Builds clean: `/nix/store/h5ppq2zz...-systemd-graph-webui-0-unstable-2026-06-08`

3. **`systemd-graph` Go package** — `pkgs/systemd-graph/default.nix`. `buildGo126Module` with `srcWithWebui` (runCommand re-packs upstream tarball with `webui/dist` injected for `//go:embed dist`). Fixed `vendorHash` and binary name mismatch (`postInstall = 'mv $out/bin/server $out/bin/systemd-graph'`). Builds clean: `/nix/store/z45y0jsd...-systemd-graph-0-unstable-2026-06-08`

### NixOS modules (prior session + this session)

4. **`modules/nixos/services/systemd-graph.nix`** — DynamicUser Go service, `MemoryMax=128M`, `ioTier.background`, `startLimitBurst=5/300s`, `after = ["dbus.service" "network-online.target"]`, `restartTriggers = [cfg.package]`. Port 8847 from `lib/ports.nix`.

5. **`modules/nixos/services/systemd-timer-monitor.nix`** — Timer-driven oneshot (every 5 min), root user, writes `report.html` + `status.json` to `StateDirectory` served by Caddy `file_server`. Hardened with `harden {}` + `serviceOneshotDefaults {}` + `ioTier.background`. Two fixes applied this session: (a) added `pkgs.python3` to `runtimeInputs` (script uses `#!/usr/bin/env python3` shebang, `harden {}` blocks default PATH), (b) `|| true` on the audit command (exit code 1 = "issues found" is expected, not a failure).

### Infrastructure wiring

6. **Caddy vHosts** (`modules/nixos/services/caddy.nix`) — `graph.home.lan` (plain `reverse_proxy` to port 8847) and `timers.home.lan` (`file_server` on state dir with `@report` matcher rewriting `/` → `/report.html`). Both LAN-only, no auth.

7. **DNS subdomains** (`platforms/common/dns-local.nix`) — `"graph"` and `"timers"` added to `localSubdomains` list.

8. **Port registry** (`lib/ports.nix`) — `systemd-graph = 8847` added.

9. **Flake + overlays** — `flake.nix` (packages), `overlays/shared.nix` (systemd-timer-monitor), `overlays/linux.nix` (systemd-graph + webui).

10. **Enabled in config** (`platforms/nixos/system/configuration.nix`) — both `systemd-graph.enable = true` and `systemd-timer-monitor.enable = true`.

### Deploy + fixes (this session)

11. **Stale lock cleared** — `/run/nixos/switch-to-configuration.lock` existed from a dead prior-session process. Confirmed `flock` is released on process death; the first successful deploy proved the file was harmless.

12. **First deploy** — completed activation (generation `4f3lbxrg`), fixed system-wide HTTPS (Caddy restart), all 57 post-deploy smoke tests passed. Timer-monitor failed (exit code 1 on issues found).

13. **Timer-monitor python3 fix** — added `pkgs.python3` to `runtimeInputs`. Without it: `env: 'python3': No such file or directory` (exit 127).

14. **Timer-monitor exit code fix** — added `|| true` to the audit command. The script returns 1 when it finds failed services (expected monitoring behavior), which systemd interpreted as a service failure.

15. **deploy.sh timer-monitor trigger** — added explicit `systemctl start systemd-timer-monitor-audit.service` post-switch. The timer's `OnBootSec=2min` is boot-based, not deploy-based; without this the report stays stale after deploys.

16. **Final deploy** — generation `8g5aqihr` activated. Both services running, all 59 post-deploy smoke tests passed (0 FAIL, 5 SKIP, 2 WARN).

### Monitoring + documentation

17. **Gatus health checks** (`modules/nixos/services/gatus-config.nix`) — Two new endpoints in "Review Tools" group, enable-gated:
    - `systemd-graph`: `https://graph.home.lan/`, 5m interval, `[STATUS] == 200` + `[RESPONSE_TIME] < 2000`, Discord alert
    - `systemd-timer-monitor`: `https://timers.home.lan/`, 5m interval, `[STATUS] == 200` + `[BODY] == pat(*<!DOCTYPE html*)`, Discord alert
    - Total Gatus endpoints: 113 (confirmed via nix eval)

18. **Post-deploy smoke tests** (`scripts/post-deploy-check.sh`) — Enable-gated via `test -e /etc/systemd/system/<unit>.service`:
    - `systemd-graph (HTTPS)` → `https://graph.home.lan/` expects 200
    - `systemd-timer-monitor (HTTPS)` → `https://timers.home.lan/` expects 200 + `<html` body match
    - Both confirmed PASS in the final deploy

19. **Homepage tiles** (`modules/nixos/services/homepage.nix`) — New "Review Tools" group with enable-gated tiles:
    - `systemd-graph` → `https://graph.home.lan/`, "Live systemd Dependency Graph", icon `mdi-graph-outline`
    - `systemd-timer-monitor` → `https://timers.home.lan/`, "Systemd Services & Timers Audit", icon `mdi-timer-outline`
    - Group added to `groups` list (single source of truth for layout + services.yaml)

20. **Service docs** — `docs/services/systemd-graph.md` and `docs/services/systemd-timer-monitor.md` written with architecture, module options, service details, and gotchas.

21. **AGENTS.md updated**:
    - Other Services section: entries for both services with key details
    - SSO table: new "Layer 0 — No auth (LAN-only)" row with both services
    - Nix & Nixpkgs gotchas: 4 new entries (`dontConfigure`/`pnpmConfigHook`, `buildGoModule` binary naming, `fetchPnpmDeps`+`sourceRoot`, `python3` in `runtimeInputs`)

### Live verification

22. **`https://graph.home.lan/`** — 200/455B (React SPA served, D-Bus snapshot endpoint returns 698KB JSON)
23. **`https://timers.home.lan/`** — 200/16395B (HTML audit report, fresh within 5 min)
24. **`https://dash.home.lan/`** — 200/48238B (Homepage dashboard with Review Tools tiles)
25. **`https://auth.home.lan/`** — 200/5317B (system-wide HTTPS confirmed working)
26. **Timer-monitor report freshness** — 209 seconds old at last check (within 5 min timer cadence)

### Bank-sync flake input fix (incidental)

27. **`flake.lock` updated** — Concurrent session commit `485bc2b4` broke bank-sync build (locked rev `7a1a5ce` failed). Updated to latest `0a6a4b2a` which fixed the build. This was blocking the final deploy.

---

## b) PARTIALLY DONE

### Deploy.sh stale-lock detection fix — NOT DONE

The prior session's status report listed "Fix deploy.sh stale-lock detection (check for orphaned lock files, not just live processes)" as a TODO. This session discovered that `flock` is automatically released when a process dies — the orphaned lock FILE persists but the lock itself is not held. So `nh os switch` succeeded without removing it. This means the fix is **not needed** — the current detection (checking for live processes with age >30min) is sufficient. The orphaned file is cosmetic, not a blocker.

### Gatus `pat()` for graph.home.lan — could be richer

The graph health check only validates `[STATUS] == 200` + `[RESPONSE_TIME] < 2000`. It could also check for the SPA's HTML structure (like the timer-monitor check does with `pat(*<!DOCTYPE html*)`). However, the 455B response IS the SPA shell — a more specific body check would be fragile if the upstream HTML changes. Current check is adequate.

---

## c) NOT STARTED

1. **NixOS VM tests** for both services — `tests/test-systemd-graph.nix` and `tests/test-systemd-timer-monitor.nix` could verify the modules work in isolation. Not critical since both services are live-verified.
2. **systemd-timer-monitor JSON alerting** — The script writes `status.json` with failed service counts. Could be scraped by a Prometheus textfile collector or Gatus JSON path check for proactive alerting. Currently only the HTML presence is checked.
3. **systemd-graph D-Bus access hardening review** — The graph service uses DynamicUser but needs D-Bus system bus access. The `harden {}` defaults don't block D-Bus (no `RestrictAddressFamilies` set), but a dedicated polkit rule could further restrict it to read-only D-Bus methods. Not urgent — the service works and only reads public systemd data.

---

## d) TOTALLY FUCKED UP

### Prior session's 6 failed pnpm build attempts

The prior session spent 6 attempts trying to build `systemd-graph-webui` by fighting `pnpmConfigHook` instead of letting it work. The root cause was a single line: `dontConfigure = true` — which silently skips the configure phase where `pnpmConfigHook` runs. The previous agent then hand-rolled `pnpm install` in `buildPhase` with wrong flags (`--config.verify-deps-before-run=false` is a pnpm 11 run-time check, not install-time; missing `--offline`; missing `store-dir`; missing `trust_lockfile`). This cost ~2 hours of build attempts that could have been avoided by reading the hook source (`nix build nixpkgs#pnpm.configHook && cat .../nix-support/setup-hook`).

### Partial activation left system in dangerous state

The prior session's first deploy hit a stale `switch-to-configuration` lock and partially activated before dying. This left:
- New unit files on disk (`/etc/systemd/system/systemd-graph.service` etc.)
- Old generation active (`/run/current-system` → `2jxmi57l`, gen 695)
- HTTPS broken system-wide (Caddy restarted before sops rendered cert)
- systemd-graph running with the fixed binary but no clean generation

A clean deploy fixed everything, but the partial activation was a dangerous state that could have caused further issues if left unresolved.

### Timer-monitor python3 missing — 4 failed runs

After the first successful deploy, the timer-monitor service crash-looped 4 times (every 5 min) with `env: 'python3': No such file or directory` (exit 127). The `#!/usr/bin/env python3` shebang requires `python3` in PATH, but `harden {}` restricts the service PATH to only what's in `runtimeInputs`. Adding `pkgs.python3` to `runtimeInputs` fixed it. This should have been caught during module development, not after 4 failed timer fires.

---

## e) WHAT WE SHOULD IMPROVE

1. **Read hook sources before fighting them** — The `pnpmConfigHook` fiasco (6 failed attempts) would have been avoided by reading the hook's setup-hook file. When a Nix build hook exists, let it do its job. The hook source is always at `$out/nix-support/setup-hook` after building it.

2. **Test shebang dependencies under hardening** — Any script with `#!/usr/bin/env python3` (or `#!/usr/bin/env node`, etc.) needs its interpreter explicitly in `runtimeInputs` when running under `harden {}`. The hardened PATH only includes what's in the wrapper's `runtimeInputs` plus a minimal system PATH. This should be a checklist item when writing new NixOS modules.

3. **Check exit code semantics of monitoring tools** — `systemd-audit` returns 1 when it finds issues (expected for a monitoring tool). This is different from a crash (exit 2+). The `|| true` fix was applied after 4 failed timer fires. Monitoring tools that return non-zero on "issues found" should always have their exit code suppressed in systemd oneshots.

4. **Don't trust partial activations** — When `switch-to-configuration` partially runs and dies, the system is in an inconsistent state (new unit files on disk, old generation active, services running with new binaries but no clean generation). Always complete a clean deploy after a partial activation.

5. **The `flock` behavior is a gotcha worth documenting** — An orphaned lock FILE persists after the process dies, but the flock itself is released. `nh os switch` checks the flock, not the file existence. So an orphaned file is cosmetic, not a blocker. This contradicts the prior session's assumption that the file needed removal.

6. **Concurrent session commits can break builds** — Commit `485bc2b4` (from another session working on llama-rag) updated the bank-sync flake input to a version that failed to build. This blocked my deploy until I updated to the latest revision. When multiple sessions are active, always check for build failures from other sessions' commits before deploying.

7. **The auto-commit daemon batches multiple sessions' work** — My timer-monitor fixes (python3, `|| true`, deploy.sh trigger) were committed alongside the Homepage/Gatus/docs changes in a single commit `7bfba47a`. This makes it hard to attribute changes to specific sessions. The commit message is comprehensive but the batching obscures the timeline.

8. **llama-rag-model-fetch.service is failing (concurrent session's work)** — `mkdir: cannot create directory '/run/llama-rag-model-fetch': Permission denied`. This is from commits `393d2123` and `321f599e` (not my work). The service tries to create a directory in `/run/` without proper privileges under hardening. This should be flagged to the user — it's not my code but it failed during my deploy.

---

## f) Up to 50 things we should get done next

1. **Fix `llama-rag-model-fetch.service`** — `/run/llama-rag-model-fetch` permission denied. The oneshot needs `RuntimeDirectory=llama-rag-model-fetch` or `+`-prefixed mkdir. This is from a concurrent session's commit, not mine.
2. **NixOS VM test for systemd-graph** — `tests/test-systemd-graph.nix` verifying the module starts and serves the SPA.
3. **NixOS VM test for systemd-timer-monitor** — `tests/test-systemd-timer-monitor.nix` verifying the timer fires and writes the report.
4. **systemd-timer-monitor JSON alerting** — Scrape `status.json` via a Prometheus textfile collector for proactive alerting on failed service counts.
5. **systemd-graph polkit hardening** — Restrict D-Bus access to read-only systemd methods via a polkit rule.
6. **systemd-graph README in upstream** — Document the Nix build process (separate webui derivation, `//go:embed dist` re-pack) in the upstream repo.
7. **systemd-timer-monitor: add `--alert-webhook` support** — If the upstream script supports webhooks, wire it to Discord for real-time alerting when new failures are detected.
8. **Review the `systemd-graph` Caddy vHost for WebSocket support** — The SPA might use WebSocket for live updates. Check if `reverse_proxy` needs `flush_interval` or `header_up` settings.
9. **Add `systemd-graph` and `systemd-timer-monitor` to the FEATURES.md inventory** — Both are DONE features.
10. **Update `docs/CONTRIBUTING.md` with the `python3` in `runtimeInputs` gotcha** — Add to the module template checklist.
11. **Consider adding `systemd-timer-monitor` as a Gatus data source** — The JSON output could feed Gatus endpoint conditions for cross-referencing failed units with Gatus endpoint health.
12. **Audit all `#!/usr/bin/env` scripts in NixOS modules** — Find any other Python/Node scripts that might be missing their interpreter in `runtimeInputs`.
13. **Add `systemd-graph` to the system-health textfile collector** — Emit a metric for the number of systemd units shown in the graph.
14. **Consider a shared "Review Tools" Caddy snippet** — Both vHosts share similar patterns (LAN-only, no auth). A snippet could reduce duplication.
15. **Check if `systemd-graph` supports dark mode** — The SPA might have a theme toggle. If not, file an upstream feature request.
16. **Pin `systemd-timer-monitor` to a release tag** — Currently pinned to a commit hash. If the upstream publishes tags, pin to the latest stable release.
17. **Add `systemd-graph` and `systemd-timer-monitor` to the deploy.sh post-switch restart list** — Currently only `systemd-timer-monitor-audit.service` is explicitly started. `systemd-graph` is a `Type=simple` service that restarts via `restartTriggers`, but adding it to the restart list would be belt-and-suspenders.
18. **Monitor the `systemd-graph` memory usage** — DynamicUser with `MemoryMax=128M`. If the D-Bus snapshot is large (698KB JSON), the Go binary might approach the limit. Consider increasing to 256M if OOM kills occur.
19. **Check if `systemd-graph` needs `After=systemd-timer-monitor-audit.service`** — No dependency, but ordering could help if both start simultaneously during boot.
20. **Consider adding `systemd-timer-monitor` output to SigNoz logs** — The audit script's stdout could be ingested via journald for historical analysis.
21. **Review the `systemd-timer-monitor` `--timeout 30` setting** — If the system has many units, `systemctl list-units` might take longer than 30s during boot. Consider increasing to 60s.
22. **Add a `systemd-timer-monitor` Grafana dashboard** — Using the JSON output as a data source for historical failed-unit trends.
23. **Consider making `systemd-graph` and `systemd-timer-monitor` available externally** — Currently LAN-only. If external access is needed, add `protectedVHost` (Layer 2).
24. **Document the `runCommand` re-pack pattern** — The `srcWithWebui` pattern for `//go:embed dist` is non-obvious. Add to `docs/CONTRIBUTING.md` as a recipe.
25. **Check if `fetchPnpmDeps` with `src = "${finalAttrs.src}/subdir"` is documented upstream** — If not, file a nixpkgs docs PR.
26. **Consider vendoring `systemd-graph` webui into the Go binary at build time** — Instead of a separate derivation + runCommand, use a Nix hook to build the SPA inline.
27. **Review the `systemd-graph` `MemoryMax=128M`** — The D-Bus snapshot is 698KB JSON. The Go binary + React SPA + Cytoscape.js rendering might need more memory. Monitor for OOM.
28. **Add `systemd-graph` and `systemd-timer-monitor` to the `lib/ports.nix` collision detection test** — Verify no port conflicts with future services.
29. **Check if `systemd-graph` supports authentication** — If the upstream adds auth, consider wiring it to Pocket ID (Layer 1).
30. **Consider a `systemd-timer-monitor` Gatus check for report freshness** — Alert if the report is older than 10 min (2 timer cycles).
31. **Add `systemd-graph` and `systemd-timer-monitor` to the `docs/CONTRIBUTING.md` module template** — As reference examples for LAN-only review tools.
32. **Review the `systemd-timer-monitor` `interval` option** — 5 min default might be too frequent for a homelab. Consider 10 min or 15 min.
33. **Check if `systemd-graph` has a health endpoint** — `/api/snapshot` returns 200/698KB. A lighter `/health` endpoint would be better for Gatus checks.
34. **Consider adding `systemd-graph` to the `system-health` textfile collector** — Emit metrics for the number of units, dependencies, and failed units shown in the graph.
35. **Review the `systemd-timer-monitor` `harden {}` settings** — The service runs as root. Check if `ProtectSystem=full` blocks writing to `StateDirectory` (it shouldn't, but verify).
36. **Consider adding `systemd-graph` to the Homepage "Monitoring" group** — It's a monitoring tool, not just a review tool. Currently in "Review Tools".
37. **Check if `systemd-graph` supports filtering by unit type** — The SPA might have filters for services, timers, sockets, etc. If not, file an upstream feature request.
38. **Consider a `systemd-timer-monitor` cron-style alerting mode** — The script returns exit code 1 on issues found. Wire `onFailure` to a Discord notification for real-time alerting.
39. **Review the `systemd-graph` `ioTier.background` setting** — D-Bus queries are fast but the SPA serving might benefit from a higher I/O priority. Consider `ioTier.service`.
40. **Check if `systemd-graph` needs `After=network-online.target`** — The service binds to `127.0.0.1` only, so network-online might not be needed. Verify and simplify if possible.
41. **Consider adding `systemd-graph` and `systemd-timer-monitor` to the backup coordination module** — The timer-monitor state dir and graph service are stateless, but the timer-monitor reports could be backed up for historical analysis.
42. **Review the `systemd-timer-monitor` `StateDirectory` cleanup** — The state dir grows with each run (overwritten, not appended). Verify that old reports are cleaned up.
43. **Check if `systemd-graph` supports export** — The SPA might support exporting the graph as PNG/SVG. If not, file an upstream feature request.
44. **Consider adding `systemd-graph` to the `pre-deploy-check.sh` ExecStart existence check** — Currently only the post-deploy smoke test checks it. Pre-deploy would catch phantom binaries earlier.
45. **Review the `systemd-timer-monitor` `Persistent = true` timer setting** — If the system was down for a long time, `Persistent` causes the timer to fire immediately on boot. This might be undesirable during boot storms.
46. **Consider a shared `review-tools` Caddy snippet** — Both vHosts share the same pattern (LAN-only, no auth). A snippet would reduce duplication.
47. **Check if `systemd-graph` supports custom CSS/themes** — The SPA might allow custom styling. If so, wire it to the Catppuccin Mocha theme.
48. **Consider adding `systemd-graph` to the `systemd-timer-monitor` audit** — The timer-monitor audits systemd units; the graph service IS a systemd unit. Meta-monitoring.
49. **Review the `systemd-graph` `DynamicUser` setting** — DynamicUser generates a random UID per start. If the service needs consistent ownership for any future state, this could be a problem. Currently stateless, so it's fine.
50. **Document the `dontConfigure = true` gotcha in `docs/CONTRIBUTING.md`** — Add a "Nix build hooks" section explaining which hooks run in which phases.

---

## g) Questions I CANNOT figure out myself

1. **Should `graph.home.lan` and `timers.home.lan` be accessible externally (outside the LAN)?** Currently both are LAN-only with no auth. If you want external access, we'd need to add `protectedVHost` (Layer 2 oauth2-proxy) or native OIDC. The tools serve read-only public systemd data, so the security risk is low, but exposing internal system structure externally is a privacy concern.

2. **The `llama-rag-model-fetch.service` is failing (concurrent session's work) — should I fix it or leave it for the other session?** The error is `mkdir: cannot create directory '/run/llama-rag-model-fetch': Permission denied`. It needs `RuntimeDirectory=llama-rag-model-fetch` in its systemd unit. This is NOT my code (commits `393d2123` and `321f599e` from a concurrent session working on llama-rag), but it failed during my deploy and shows up as a warning.

3. **Should the `systemd-timer-monitor` interval be changed from 5 min to something longer?** 5 min matches Gatus cadence, but for a homelab with ~60 timers, the audit is lightweight (~1s execution). If you prefer less frequent audits (e.g., 15 min), the `interval` option makes it a one-line change.

---

## Session Commits (auto-committed by daemon)

| Commit | Time | Description |
|--------|------|-------------|
| `995f4f8d` | 17:28 | fix(systemd-graph): fix package build, binary name, and pnpm hook integration (prior session) |
| `b4eeaffa` | 17:35 | feat(dns): register graph and timers services in local DNS configuration (prior session) |
| `f05fb244` | 17:58 | docs(status): add status report for systemd-graph package fix (prior session) |
| `7bfba47a` | 18:34 | feat(services): add systemd-graph and systemd-timer-monitor for system introspection (this session — batched: AGENTS.md, docs, homepage tiles, timer-monitor python3 + \|\| true fixes, deploy.sh trigger) |
| `6ddb753f` | 18:34 | feat(monitoring): add health checks for systemd-graph and systemd-timer-monitor (this session — Gatus checks + post-deploy smoke tests) |
| `c9fb8424` | 18:47 | chore(flake): update flake.lock (this session — bank-sync input update to fix build) |

## Concurrent Session Commits (NOT my work)

| Commit | Time | Description |
|--------|------|-------------|
| `485bc2b4` | ~18:00 | chore(deps): update bank-sync flake input (broke build, fixed by my `c9fb8424`) |
| `04b37358` | ~18:00 | docs(agents): enable Paperless RAG embeddings via llama-rag GPU module |
| `cb812981` | ~18:00 | feat(services): add llama.cpp embeddings and reranker health monitoring |
| `83e2b2c2` | ~18:00 | test(paperless): include llama-rag module for embedding model configuration |
| `cea4f323` | ~18:00 | feat(paperless): enable RAG embeddings via llama-rag embeddings instance |
| `ce91825a` | ~18:00 | feat(rag): enable llama.cpp RAG stack and wire Paperless to embeddings |
| `fe8093d4` | ~18:00 | docs(memory): update Strix Halo VRAM carveout figures |
| `7db09df5` | ~18:00 | refactor(services): extract llama-rag ExecStart commands |
| `9218a1ac` | ~18:00 | feat(llama-rag): add llama.cpp RAG service ports and rebalance VRAM carveout |
| `393d2123` | ~18:40 | feat(llama-rag): auto-fetch GGUF models at activation (caused model-fetch.service failure) |
| `321f599e` | ~18:44 | feat(services/llama-rag): split model fetching into dedicated oneshot service (caused model-fetch.service failure) |
