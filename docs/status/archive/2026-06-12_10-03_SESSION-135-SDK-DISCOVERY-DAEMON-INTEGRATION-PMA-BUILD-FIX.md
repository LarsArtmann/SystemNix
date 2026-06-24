# Session 135 — SDK Discovery Daemon Integration + PMA Build Fix

**Date:** 2026-06-12 10:03 CEST
**Status:** ✅ Build passes, deployed via `nh os boot`, awaiting reboot
**Scope:** project-discovery-sdk, cmdguard, PMA, Overview, SystemNix

---

## Summary

Integrated the project-discovery SDK daemon so that Overview delegates project discovery to PMA's running daemon via unix socket, instead of running its own full discovery pipeline. Also fixed the PMA build (broken since session 133 due to branching-flow/cmdguard API breaks), fixed a crush-daily module evaluation error, and committed an untracked SDK sub-module that was causing Nix build failures.

---

## a) FULLY DONE ✅

### 1. SDK Discovery Daemon Architecture
- **PMA** starts a `project-discovery` daemon server on `/run/project-discovery/daemon.sock` alongside its auto-commit file watcher
- **Overview** probes for the daemon at startup via `sdk.WithDaemonProbe(daemon.ProbeDaemon)` + `sdk.WithMode(sdk.ModeAuto)`
- If daemon is running → Overview delegates discovery (shared, cached, debounced results)
- If daemon is not running → Overview falls back to embedded in-process pipeline (graceful degradation)

### 2. project-discovery-sdk changes
- Added `WithSocketMode(fs.FileMode)` option to `daemon.Server` (was hardcoded `0o600`, now configurable for cross-service access at `0o666`)
- Committed untracked `enrichment/meta` sub-module (was on disk but never in git, caused Nix build failures when preset package referenced it)

### 3. cmdguard API compatibility
- Restored `MustNewCommand` and `MustNewParentCommand` as panic-on-error wrappers around the new `NewCommand`/`NewParentCommand` (which return `(Command, error)`)
- These were removed in cmdguard v2.6.0, breaking PMA and go-auto-upgrade

### 4. PMA build fixed
- Fixed `branching_flow_service.go` linter key renames: `LinterKeyAntiPatt` → `LinterKeyAntiPatterns`, `LinterKeyStrongID` → `LinterKeyStrongId`, `LinterKeyBoolBlind` → `LinterKeyBoolblind`
- Created `internal/discovery/daemon_server.go` — wraps SDK daemon server, uses `sdkDaemon.WithSocketMode(0o666)` for cross-service socket access
- Wired into `service start` command — daemon starts in goroutine alongside auto-commit service, shares lifecycle context
- Fixed logger type mismatch (PMA uses zerolog, daemon server uses slog → use `slog.Default()`)

### 5. PMA NixOS module updates
- Added `AF_UNIX` to `RestrictAddressFamilies` (daemon needs unix socket)
- Added `RuntimeDirectory = "project-discovery"` for `/run/project-discovery/` directory
- Added `ReadWritePaths` for `/run/project-discovery`
- Set `PROJECT_DISCOVERY_DAEMON_ADDR=unix:///run/project-discovery/daemon.sock` in environment

### 6. Overview daemon probe integration
- Updated `sdk_client.go` to use `sdk.WithMode(sdk.ModeAuto)` + `sdk.WithDaemonProbe(daemon.ProbeDaemon)`
- Added `daemon` sub-module import to `go.mod`
- Added `daemon`, `enrichment/meta`, `preset` to `subModules` in `flake.nix`
- NixOS module: added `AF_UNIX` to `RestrictAddressFamilies`
- NixOS module: added `PROJECT_DISCOVERY_DAEMON_ADDR=unix:///run/project-discovery/daemon.sock` to environment

### 7. SystemNix fixes
- Fixed `crush-daily.nix` module evaluation error: moved `pkgs` from outer flake-parts scope (where it's unavailable) to inner NixOS module scope
- Updated `flake.lock` for: overview, projects-management-automation, cmdguard, project-discovery-sdk
- Updated `AGENTS.md` with 5 new gotchas (SDK daemon, enrichment/meta, crush-daily pkgs, cmdguard MustNewCommand)

### 8. Build & Deploy
- Full `nix build` passes (all pre-commit hooks: gitleaks, deadnix, statix, alejandra, `nix flake check`)
- Deployed via `nh os boot` — awaiting reboot to activate

---

## b) PARTIALLY DONE ⚠️

### 1. Daemon socket verification
- Config is deployed but system hasn't been rebooted yet
- Need to verify after reboot:
  - `/run/project-discovery/daemon.sock` exists
  - PMA service starts and daemon socket is created
  - Overview probes successfully and delegates to daemon
  - `overview` logs show "auto-detected running daemon" message

### 2. oauth2-proxy race fix (from session 134)
- Fix was committed and deployed but not yet verified after reboot
- Added `unbound.service` and `network-online.target` to `after`/`wants`

---

## c) NOT STARTED ❌

### 1. Immich OAuth login via Pocket ID (original goal from session 132)
- The Pocket ID OIDC client was provisioned in session 134
- Immich OAuth configuration needs to be tested end-to-end
- PKCE compatibility with confidential client needs verification

### 2. Follows policy for SystemNix
- Need to decide which inputs should be overridden via `follows` vs let upstream pin its own
- Currently: only `nixpkgs` follows are kept; others removed when API breaks occurred

### 3. PMA API migration for cmdguard
- PMA still uses `MustNewCommand` (panic wrapper) instead of properly handling `NewCommand` errors
- Should migrate to error-returning `NewCommand` pattern for better error handling

### 4. projects-management-automation full API catch-up
- PMA is frozen at pre-API-break revision for `branching-flow` (linter keys fixed but `go-structure-linter` API still has `LinterKeyAntiPatt` in some places)
- Need full API migration to catch up with current branching-flow + go-structure-linter

---

## d) TOTALLY FUCKED UP 💥

### 1. VendorHash iteration cycle
- The Overview vendorHash needed **4 iterations** (empty → get hash → push → update lock → repeat) because:
  - First: missing `enrichment/meta` sub-module in SDK git
  - Then: missing `enrichment/meta` in Overview's flake.nix subModules
  - Then: SDK updated again, invalidating hash
  - Then: PMA changes triggered another Overview hash change
- **Root cause:** Each upstream repo change cascades to consumers. The `got:` hash workflow is slow and manual.
- **Improvement:** Could script `nix build → grep got: → sed vendorHash → git commit` into a single command.

### 2. MustNewCommand removal cascade
- cmdguard removed `MustNewCommand` in v2.6.0 without a backward-compatible shim
- This broke PMA (18 files, 28 call sites), go-auto-upgrade, and potentially other consumers
- Had to restore it in cmdguard instead of fixing each consumer
- **Should have:** Added the shim to cmdguard immediately when the break was discovered in session 133

### 3. enrichment/meta untracked for unknown duration
- The `enrichment/meta` sub-module existed on disk in the SDK repo but was never committed to git
- This silently worked in local dev (via go.mod replace directives) but broke Nix builds (which fetch from git)
- **Lesson:** Always `git status` after creating new sub-modules

---

## e) WHAT WE SHOULD IMPROVE 🔧

1. **Automated vendorHash update script** — `nix build → grep got: → update flake.nix → commit` is a 5-step manual process done 6+ times this session. Should be a single `just update-hash <pkg>` command.

2. **CI for upstream repos** — The `enrichment/meta` untracked file issue would have been caught by CI. Each LarsArtmann repo should build from a clean checkout.

3. **Daemon integration test** — Should have a NixOS test that verifies PMA creates the socket and Overview can connect to it. Currently no automated verification.

4. **SDK daemon binary versioning** — The daemon server has `version = "0.4.0"` hardcoded. Should derive from the SDK version or accept it via `WithVersion()`.

5. **Socket path consistency** — PMA module hardcodes `/run/project-discovery/daemon.sock`, Overview module hardcodes the same. Should be a shared constant or lib option.

6. **Overview DiscoveryCache becomes redundant** — When daemon is running, Overview's `DiscoveryCache` (TTL + singleflight + background refresh) is double-caching since the daemon itself runs the pipeline. Could simplify by checking daemon availability and skipping the cache layer.

---

## f) TOP 25 THINGS TO DO NEXT

| # | Priority | Task | Impact | Effort |
|---|----------|------|--------|--------|
| 1 | P0 | **Reboot and verify daemon socket** — confirm PMA creates socket, Overview probes it | High | 5min |
| 2 | P0 | **Test Immich OAuth login** via Pocket ID (original goal from session 132) | High | 15min |
| 3 | P0 | **Test PKCE compatibility** with confidential client in Immich | High | 10min |
| 4 | P1 | **Push 2 local commits** to origin master | Low | 1min |
| 5 | P1 | **Define `follows` policy** for SystemNix — document which inputs use follows and why | Med | 30min |
| 6 | P1 | **Write automated vendorHash update script** — `just update-hash <pkg>` | High | 30min |
| 7 | P1 | **Migrate PMA from MustNewCommand to NewCommand** with proper error handling | Med | 2h |
| 8 | P1 | **PMA full API catch-up** — fix go-structure-linter API breaks in projects-management-automation | Med | 2h |
| 9 | P1 | **Add NixOS test for daemon integration** — verify socket creation + connectivity | High | 1h |
| 10 | P2 | **SDK daemon version** — derive from SDK version instead of hardcoded `"0.4.0"` | Low | 15min |
| 11 | P2 | **Shared socket path constant** — avoid hardcoding in both PMA and Overview modules | Low | 15min |
| 12 | P2 | **Overview: skip DiscoveryCache when daemon is available** — reduce double-caching | Med | 1h |
| 13 | P2 | **CI for all LarsArtmann repos** — catch untracked files, build failures from clean checkout | High | 4h |
| 14 | P2 | **Daemon health monitoring** — add Gatus endpoint for daemon socket availability | Low | 30min |
| 15 | P2 | **PMA: expose daemon status in `pma service status`** — show socket path, daemon PID | Low | 30min |
| 16 | P2 | **Overview: show daemon connection status in /health endpoint** | Low | 15min |
| 17 | P3 | **SDK daemon: add authentication** — unix socket is world-readable (0o666), consider restricting | Med | 1h |
| 18 | P3 | **SDK daemon: add rate limiting** — prevent abuse from misbehaving consumers | Low | 1h |
| 19 | P3 | **SDK daemon: add metrics** — request count, latency, cache hit rate | Low | 1h |
| 20 | P3 | **go-auto-upgrade: migrate from MustNewCommand** to NewCommand | Low | 30min |
| 21 | P3 | **Overview: add daemon connection metrics** — show probe success/failure in dashboard | Low | 30min |
| 22 | P3 | **SDK daemon: graceful reload** — accept new config without dropping connections | Low | 2h |
| 23 | P3 | **PMA: add `PROJECT_DISCOVERY_MODE` env var** — allow forcing daemon/standalone mode | Low | 15min |
| 24 | P3 | **Overview flake.nix: share socket path** as a let binding instead of hardcoding in module.nix | Low | 10min |
| 25 | P3 | **Session retrospective** — update TODO_LIST.md with new items from this session | Med | 30min |

---

## g) TOP QUESTION I CANNOT FIGURE OUT MYSELF 🤔

**After reboot: does the PMA service actually create the socket BEFORE Overview starts?**

The PMA service and Overview both use `multi-user.target`. systemd starts them in parallel. The socket creation happens inside PMA's `service start` command (after the auto-commit watcher starts). If Overview starts and probes the socket before PMA creates it, Overview will silently fall back to embedded pipeline and never retry the daemon.

Possible fixes:
- Add `After=projects-management-automation.service` to Overview's systemd unit
- Have Overview periodically re-probe the daemon (currently probes only at startup)
- Make the daemon socket a systemd `ListenStream` with activation

I can't determine which approach is right without seeing the actual startup timing on the machine after reboot.

---

## Repos Modified (17 total)

| Repo | Commits | Key Changes |
|------|---------|-------------|
| project-discovery-sdk | `0313ea5`, `8b4d947` | `WithSocketMode`, committed `enrichment/meta` |
| cmdguard | `62ddcd7` | Restored `MustNewCommand`/`MustNewParentCommand` |
| projects-management-automation | `6f5c0bdd`, `83fc3e1f`, `9abda04f`, `1d0dedd2` | Daemon server, branching-flow keys, logger fix, vendorHash |
| overview | `3157097`, `760a9db`, multiple hash updates | Daemon probe, sub-modules, vendorHash |
| SystemNix | `0a3b61d7`, `57403d07` | Flake lock, crush-daily fix, AGENTS.md |

## System State

```
Build:    ✅ nix build passes
Hooks:    ✅ All pre-commit hooks pass
Deploy:   ✅ nh os boot (awaiting reboot)
Push:     ❌ 2 commits ahead of origin (need push)
```
