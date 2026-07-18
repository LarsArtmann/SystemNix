# File-and-Image-Renamer NixOS Integration — Final Status

**Date:** 2026-05-01 07:24
**Scope:** Integrate `file-and-image-renamer` into SystemNix evo-x2 NixOS configuration
**Session span:** ~5 hours (02:00–07:24 CEST)

---

## A) FULLY DONE ✅

1. **Package derivation** — `pkgs/file-and-image-renamer.nix`
   - `buildGoModule` with `proxyVendor = true` — avoids vendor inconsistency with local `go.mod` replaces
   - `postPatch` rewrites `go.mod` replace directives from `/home/lars/projects/...` to nix store paths
   - `cleanSourceWith` filter strips vendor, docs, scripts, .plist, .toml, .envrc, etc.
   - `vendorHash` pinned: `sha256-KSAkJXZ+40jkceXUv0+CFxUO9otFTOvMl3hq8mfCvXA=`
   - Binary builds and runs: `file-renamer --help` confirmed functional

2. **NixOS service module** — `modules/nixos/services/file-and-image-renamer.nix`
   - Options: `enable`, `package`, `user`, `watchDirectory`, `apiKeyFile`, `logDirectory`
   - Defaults: user=lars, watchDirectory=/home/lars/Desktop, apiKeyFile=/home/lars/.zai_api_key
   - systemd user service (not system service) — runs under user `lars` with `graphical-session.target`
   - Hardened: MemoryMax=512M, PrivateTmp, NoNewPrivileges, ProtectClock, ProtectHostname, RestrictNamespaces, LockPersonality
   - Log directory created via `systemd.tmpfiles.rules`
   - Package installed system-wide via `environment.systemPackages`

3. **Flake wiring** — `flake.nix`
   - 3 SSH-based flake inputs (portable):
     - `file-and-image-renamer-src` → `git+ssh://git@github.com/LarsArtmann/file-and-image-renamer?ref=master`
     - `cmdguard-src` → `git+ssh://git@github.com/LarsArtmann/cmdguard?ref=master`
     - `go-output-src` → `git+ssh://git@github.com/LarsArtmann/go-output?ref=master`
   - `fileAndImageRenamerOverlay` in `linuxOnlyOverlays` + perSystem overlays
   - Module imported in flake-parts `imports` and `nixosConfigurations.evo-x2.modules`
   - Package exposed in `perSystem.packages` for Linux

4. **Service enabled on evo-x2** — `platforms/nixos/system/configuration.nix`
   - `services.file-and-image-renamer.enable = true`

5. **Flake inputs migrated from path: to SSH URLs**
   - Initially used `path:/home/lars/projects/...` (non-portable)
   - Switched to `git+ssh://git@github.com/LarsArtmann/...?ref=master` (portable, private repo access via SSH)
   - Build and check verified after migration

6. **Project .gitignore fixed** — `file-and-image-renamer/.gitignore`
   - `vendor/` un-commented so it's properly ignored

7. **All verification passing**
   - `nix flake check --no-build` — all checks passed
   - `nix build .#file-and-image-renamer` — build succeeds
   - `nix eval .#nixosConfigurations.evo-x2.config.services.file-and-image-renamer` — correct config
   - Pre-commit hooks pass: gitleaks, deadnix, statix, alejandra, flake check

### Commits Made

| Repo                   | SHA       | Message                                                                        |
| ---------------------- | --------- | ------------------------------------------------------------------------------ |
| SystemNix              | `569a37a` | `feat(nixos): integrate file-and-image-renamer as NixOS service on evo-x2`     |
| SystemNix              | `fccef1b` | `refactor(flake): switch file-and-image-renamer inputs from path: to SSH URLs` |
| file-and-image-renamer | `9e70d94` | `chore(config): enable vendor directory in .gitignore`                         |

### Files Created/Modified (SystemNix)

| File                                                | Status   | Lines |
| --------------------------------------------------- | -------- | ----- |
| `pkgs/file-and-image-renamer.nix`                   | NEW      | 60    |
| `modules/nixos/services/file-and-image-renamer.nix` | NEW      | 120   |
| `flake.nix`                                         | Modified | +29   |
| `flake.lock`                                        | Modified | +75   |
| `platforms/nixos/system/configuration.nix`          | Modified | +5    |
| `docs/status/2026-05-01_02-40_...md`                | NEW      | 159   |

---

## B) PARTIALLY DONE ⚠️

1. **Project's own `flake.nix`** (`file-and-image-renamer/flake.nix`)
   - Still has `vendorHash = null` — won't build standalone via `nix build`
   - Doesn't handle local replace directives (same problem we solved in SystemNix's package derivation)
   - Needs: `proxyVendor = true`, `postPatch` for replace directives, computed `vendorHash`
   - The `nixosModules`, `darwinModules`, and `homeManagerModules` it defines are also broken by the vendor issue

---

## C) NOT STARTED ❌

1. **Actual deployment** — `nh os switch .` has NOT been run. Integration is verified in eval/build but not deployed to the running evo-x2 machine.

2. **API key provisioning** — The service expects `~/.zai_api_key` on evo-x2. Need to verify this file exists after deployment.

3. **End-to-end runtime testing** — Once deployed:
   - `systemctl --user status file-and-image-renamer`
   - Drop a screenshot on Desktop, verify auto-rename
   - GLM-4.6V API calls succeed
   - Dead-letter queue handles failures

4. **sops-nix integration for API key** — Currently a plain file at `~/.zai_api_key`. Should use sops-nix secrets management (like hermes uses `sops.templates."hermes-env".path`).

5. **Darwin/Home Manager module in SystemNix** — Integration is NixOS-only. No cross-platform HM or darwin module created.

6. **NIX_INTEGRATION.md update** — The project's docs still reference `path:` URLs and macOS paths. Should be updated to reflect the SSH-based integration.

7. **Project AGENTS.md update** — Should record the SystemNix integration pattern (vendorHash, proxyVendor, postPatch approach).

8. **CI pipeline for nix build** — `file-and-image-renamer/.github/workflows/nix-check.yml` exists but the nix build is broken in the project.

9. **Homepage dashboard entry** — Service not visible on the homepage dashboard alongside hermes, monitor365, etc.

10. **Health check wiring** — `file-renamer health` command exists but not wired into systemd watchdog or `service-health-check` script.

---

## D) TOTALLY FUCKED UP 💥

1. **Project standalone nix build is BROKEN** — `cd file-and-image-renamer && nix build .#file-and-image-renamer` fails with vendor inconsistency. The `vendorHash = null` + local `replace` directives make it impossible. This is pre-existing and NOT caused by this integration, but it means the project can't be used as a flake input by anyone else.

2. **No GitHub push yet** — Both SystemNix (4 commits ahead) and file-and-image-renamer (1 commit ahead) have unpushed commits. The SSH-based flake inputs reference `?ref=master` which won't pick up the local-only changes until pushed.

---

## E) WHAT WE SHOULD IMPROVE 📈

1. **Fix project's own flake.nix** — Add `proxyVendor = true`, `postPatch` for replace directives, and compute `vendorHash`. This unblocks standalone builds and makes the project usable as a flake input by others.

2. **sops-nix for API key** — Store `ZAI_API_KEY` in sops secrets, reference via `EnvironmentFile`. Eliminates plain-text key file. Follow the hermes pattern.

3. **Add home-manager module** — Cross-platform HM module so tool + watcher work on macOS (the project already defines `homeManagerModules.default` but it's broken).

4. **Wire health check** — `file-renamer health` into systemd watchdog or existing health-check script.

5. **Homepage dashboard** — Add file-and-image-renamer card showing watcher status, stats, dead-letter count.

6. **Push to GitHub** — Both repos need their commits pushed for the SSH flake inputs to resolve correctly on other machines.

7. **Add log rotation** — lumberjack is already a Go dependency; ensure config is properly set for the systemd service.

8. **Add Prometheus metrics** — Expose watcher stats (files processed, errors, dead-letters) for the existing monitoring stack.

9. **Add deadletter alerting** — Notify (via dunst/hermes) when dead-letter queue grows.

10. **Clean up project's NIX_INTEGRATION.md** — References are stale (path: URLs, old binary names).

---

## F) Top 25 Things To Do Next

| #   | Priority | Task                                                               | Effort | Repo      |
| --- | -------- | ------------------------------------------------------------------ | ------ | --------- |
| 1   | P0       | Deploy: `nh os switch .` on evo-x2                                 | 5m     | SystemNix |
| 2   | P0       | Verify service: `systemctl --user status file-and-image-renamer`   | 2m     | evo-x2    |
| 3   | P0       | Verify API key exists: `cat ~/.zai_api_key` on evo-x2              | 1m     | evo-x2    |
| 4   | P0       | End-to-end test: drop screenshot on Desktop, verify rename         | 5m     | evo-x2    |
| 5   | P1       | Push SystemNix to GitHub (4 commits ahead)                         | 2m     | SystemNix |
| 6   | P1       | Push file-and-image-renamer to GitHub (1 commit ahead)             | 2m     | fir       |
| 7   | P1       | Fix project's own flake.nix (proxyVendor + postPatch + vendorHash) | 15m    | fir       |
| 8   | P1       | Migrate API key to sops-nix (hermes pattern)                       | 20m    | SystemNix |
| 9   | P2       | Update project NIX_INTEGRATION.md with SSH URL pattern             | 10m    | fir       |
| 10  | P2       | Update project AGENTS.md with nix integration info                 | 5m     | fir       |
| 11  | P2       | Fix project's nix-check.yml CI workflow                            | 15m    | fir       |
| 12  | P2       | Create cross-platform home-manager module in SystemNix             | 30m    | SystemNix |
| 13  | P3       | Wire `file-renamer health` into service-health-check script        | 10m    | SystemNix |
| 14  | P3       | Add file-and-image-renamer to homepage dashboard                   | 10m    | SystemNix |
| 15  | P3       | Add daily `file-renamer stats` cron/timer                          | 15m    | SystemNix |
| 16  | P3       | Add log rotation config for watcher                                | 10m    | SystemNix |
| 17  | P3       | Add Prometheus metrics endpoint for watcher                        | 30m    | fir       |
| 18  | P3       | Add deadletter alerting (dunst/hermes notification)                | 20m    | SystemNix |
| 19  | P4       | Add nixosTest integration test                                     | 30m    | SystemNix |
| 20  | P4       | Add desktop file entry for file-renamer                            | 5m     | fir       |
| 21  | P4       | Explore hash database persistence across rebuilds                  | 15m    | SystemNix |
| 22  | P4       | Add `file-renamer compare` as scheduled benchmark                  | 15m    | SystemNix |
| 23  | P4       | Consolidate project flake.nix modules with SystemNix's             | 30m    | both      |
| 24  | P4       | Add XDG mime association for screenshot files                      | 5m     | SystemNix |
| 25  | P4       | Document nix integration in SystemNix README                       | 10m    | SystemNix |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Is the `~/.zai_api_key` file already present on evo-x2?**

The service is configured to read the API key from `/home/lars/.zai_api_key`, but I cannot verify from here whether this file exists on the actual evo-x2 machine. If it's missing, the watcher will fail immediately on startup with an API key error. This must be verified after deployment — and if missing, either copied from the dev machine or provisioned via sops-nix.
