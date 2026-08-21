# SystemNix Status — 2026-08-12 13:05 CEST

Session: overview + hermes recovery, StartLimitBurst hardening, PMA split-mode.

---

## 1. What was the user asking for?

Two distinct workstreams ended up in this session:

1. **Hermes Agent** — originally down because it was temporarily disabled on
   2026-08-10 to unblock a deploy that was failing on the `hermes-tui` pnpm
   build inside the Nix sandbox (OOM kill). The upstream
   `hermes-agent` flake had already fixed it; SystemNix was still pinned to the
   broken revision.

2. **Overview service** — failed during the same deploy with exit status 69
   (`UNAVAILABLE`). The root cause was the missing
   `project-discovery` daemon socket (`/run/project-discovery/daemon.sock`),
   which is provided by `projects-management-automation` (PMA), but PMA had
   been left disabled in `configuration.nix`.

The user then asked to make the dependency explicit and noisy rather than
silently crash-looping, and to re-enable PMA in "discovery-only" mode (no git
auto-commit daemon) so overview could work without re-introducing the
`go-cqrs-lite/codec/v4` FOD issue that originally disabled PMA.

---

## 2. Work actually done in this session

### a) Fully done

- Bumped `hermes-agent` flake input from `ed5e17f4` to `ee472a7f`
  (2026-08-12), which resolves the `hermes-tui` pnpm-build OOM kill.
- Re-enabled `services.hermes.enable = true` in
  `platforms/nixos/system/configuration.nix` (removed the TEMP disable comment).
- Built and activated the full system toplevel on `evo-x2`.
  Hermes came up successfully; the deploy diff shows `hermes-agent 0.20.0`,
  `hermes-tui`, and all dependency groups being added back to the system.
- Diagnosed `overview.service` exit 69: it could not create the SDK client
  because `unix:///run/project-discovery/daemon.sock` was not available.
- Re-enabled `projects-management-automation` in split mode:
  - `enable = true`
  - `mode = "passive"` (log-only; disables the git auto-commit daemon)
  - `enableDiscoveryDaemon = true` (default) so the discovery daemon still
    runs and serves the socket that overview depends on.
- Hardened `modules/nixos/services/overview.nix` with three layered fixes:
  1. **Eval-time assertion** — if `services.overview.daemonSocket` is non-empty
     but `services.projects-management-automation.enable` is false, the build
     fails with an explicit, actionable message (enable PMA or use in-process
     discovery).
  2. **ExecStartPre gate exits 1** instead of 0 when the daemon is not ready
     after 60 s, and prints the socket path plus the two remediation paths.
     This prevents overview from starting and immediately crash-looping with
     exit 69.
  3. **Restart-limit placement fix** — moved `startLimitBurst` and
     `startLimitIntervalSec` from `serviceConfig` (which upstream sets and
     systemd 261+ silently ignores in `[Service]`) to the top-level NixOS
     options, which map to `[Unit]`. This is the exact same bug class that
     caused the 2026-08-11 WDT crash chain on `browser-history-agent`.
- Updated `overview` flake input to `477c5e5` (2026-08-12) and let the cascade
  pull in new upstream pins for `cmdguard`, `cqrs-htmx`, `go-cqrs-lite`,
  `gogenfilter`, `project-discovery-sdk`, `project-meta`,
  `samber-do-auditlog`, `go-nix-helpers`, `go-etag`, and
  `go-flightrecorder v0.2.0`.
- Verified `nix flake check --no-build` passes after all changes.

### b) Partially done

- Hermes is deployed and the build succeeded, but runtime functionality
  (Discord bot connection, cron registration, gateway health) has not been
  verified post-deploy in this session.
- Overview's dependency graph is fixed in configuration, but the actual
  runtime interaction between overview and the re-enabled PMA discovery daemon
  has not been observed yet because the system was just activated.
- The long-standing `hermes-tui` pnpm build fragility is mitigated by tracking
  upstream, but not eliminated locally. A local upstream npmDepsHash
  regression would still break deploys until the next upstream bump.

### c) Not started

- No Gatus health-check changes were made for overview or PMA in this session.
- No cleanup of the `patchedOverlay` in `modules/nixos/services/hermes.nix`;
  the 18 `extraDependencyGroups` override is now redundant because the
  upstream `full` package already includes them plus `vercel`, but it still
  works and was left untouched.
- No work on the `TODO_LIST.md` items for Hermes (SSH deploy key, fallback
  model) was done.
- No work on the Darwin side; the changes are NixOS-only.
- No backfill or validation of the `overview`/`project-discovery` metrics.

### d) Totally fucked up / things that went wrong

- **The initial deploy still failed** even after updating `overview` to
  `477c5e5`, because the real failure was the missing daemon socket, not the
  overview package revision. The package update was a red herring; the actual
  fix required re-enabling PMA.
- **/overview was silently crash-looping before this session** because the
  `ExecStartPre` gate swallowed the timeout (exit 0 with "proceeding anyway"),
  and because `StartLimitIntervalSec` was placed in `serviceConfig` where
  systemd 261+ silently ignores it. Both defects were already documented in
  `AGENTS.md` but had not been applied to `overview` until now.
- **PMA was disabled with a comment about a go-cqrs-lite FOD issue**, but its
  discovery daemon was still a hard dependency of overview. The system was
  therefore deployed in a known-broken state for overview.

---

## 3. What I forgot / could have done better

- Should have checked `journalctl -u overview.service` immediately on the
  first deploy failure instead of first updating the `overview` flake input.
  The package bump was unnecessary for the crash; the journal would have
  pointed straight to the missing daemon socket.
- Should have asked whether to keep PMA fully disabled or run it in
  discovery-only mode before making that decision. I chose `mode = "passive"`
  based on the existing TEMP comment, but the user may prefer a different
  split.
- Should have verified that `nix flake check` fails with the new assertion
  _before_ enabling PMA, as a controlled test. I did see it fail after the
  change, but not as a deliberate negative test.
- Could have added the same `StartLimitBurst`/`StartLimitIntervalSec` audit to
  other imported modules in the same session, since we know upstream has the
  same pattern in other flakes. I only fixed `overview`.
- Did not run `nix run .#post-deploy-check` after the successful activation;
  the user will need to verify runtime behavior manually.

---

## 4. What should still be improved

> **Note:** Items below were harvested into TODO_LIST.md / ROADMAP.md where actionable. Done items are struck through. / next steps

1. **Runtime verification** (next deploy): confirm `hermes.service` is
   healthy, `overview.service` is reachable, and `project-discovery` socket
   answers `v1/health`.
2. **Add Gatus health checks** for `overview` and `project-discovery` (PMA).
   The socket endpoint is `http://localhost/v1/health` over the unix socket
   at `/run/project-discovery/daemon.sock`.
3. **Simplify `hermes.nix` overlay**: remove the 18 `extraDependencyGroups`
   override since the upstream `full` package already includes them. This
   reduces maintenance surface and avoids future group-name mismatches.
4. ~~**Audit other imported modules** for `StartLimitBurst` in `serviceConfig`;
   at minimum grep the lockfile-pinned upstream modules for the same
   systemd-261 pitfall.~~ done — comprehensive audit 2026-08-14, zero violations (`2026-08-14_09-14` report §a.7)
5. ~~**Resolve the PMA `go-cqrs-lite/codec/v4` FOD issue** so the git
   auto-commit daemon can be re-enabled. Right now PMA is running only for
   discovery, which is a half-measure.~~ done — PMA full mode runs (the auto-git daemon committing across sessions IS PMA active mode)
6. **Update `TODO_LIST.md`** items for Hermes (SSH deploy key, fallback model)
   and verify whether they are still needed.
7. **Consider an upstream PR to `overview`**: move `StartLimitBurst`/
   `StartLimitIntervalSec` to `[Unit]` in the upstream module, and/or make
   the daemonSocket dependency optional/graceful instead of fatal.
8. **Add a test or VM test** that asserts `services.overview.enable` fails
   eval when `services.projects-management-automation.enable = false` and
   `daemonSocket` is set, to prevent regression.
9. ~~**Post-deploy-check**: run `nix run .#post-deploy-check` after the next
   switch and ensure overview and hermes are in the smoke test set.~~ done — post-deploy-check runs on every deploy (57 checks, 0 failed at the 08-14 hermes deploy)
10. ~~**Hermes runtime validation**: check Discord bot presence, cron job
    registration, and gateway request handling.~~ done (process level) 2026-08-14 — gateway, cron scheduler, agent loop verified after `registration_lifecycle` fix; Discord bot presence/end-to-end still untested (TODO_LIST)

---

## 5. Three questions I cannot answer without you

1. **Should PMA run fully enabled (`mode = "active"`) or is `mode = "passive"`
   the intended long-term state?** I used passive to avoid the unresolved
   `go-cqrs-lite/codec/v4` FOD rebuild, but if you want auto-commits back, we
   need to fix that separately.

2. **Do you want the `hermes.nix` `extraDependencyGroups` overlay simplified
   in this same session, or as a follow-up?** It is redundant but harmless; I
   left it to avoid scope creep.

3. **Should I add Gatus checks and post-deploy smoke tests for overview and
   the project-discovery daemon now, or wait until after runtime verification?**
   I can add them speculatively but their exact endpoints/conditions depend
   on whether the daemon socket should be probed from the Gatus unit (which
   has its own access constraints).

---

## 6. Files changed this session

- `flake.lock` — bumped `hermes-agent`, `overview`, and cascade inputs.
- `platforms/nixos/system/configuration.nix` — re-enabled Hermes; re-enabled
  PMA in `mode = "passive"`.
- `modules/nixos/services/overview.nix` — assertion, ExecStartPre fail-fast,
  `StartLimitBurst`/`StartLimitIntervalSec` placement fix.

---

## 7. Commands that validated the work

```bash
nix flake lock --update-input hermes-agent
nix flake lock --update-input overview
nix flake check --no-build
nix run .#deploy   # executed on evo-x2, activation succeeded
```

The last `nix flake check --no-build` passed all checks.

---

_End of status report. Waiting for instructions._
