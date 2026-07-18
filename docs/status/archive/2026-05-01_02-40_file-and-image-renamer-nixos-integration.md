# File-and-Image-Renamer NixOS Integration — Complete

**Date:** 2026-05-01 02:40
**Scope:** Integrate `file-and-image-renamer` into SystemNix evo-x2 NixOS configuration
**Status:** Integration complete, builds pass, binary verified

---

## A) FULLY DONE

1. **Package derivation** — `pkgs/file-and-image-renamer.nix`
   - `buildGoModule` with `proxyVendor = true`
   - `postPatch` rewrites `go.mod` replace directives from local paths (`/home/lars/projects/...`) to nix store paths at build time
   - `cleanSourceWith` filter strips vendor, docs, scripts, .plist, .toml, etc.
   - `vendorHash` computed and pinned: `sha256-KSAkJXZ+40jkceXUv0+CFxUO9otFTOvMl3hq8mfCvXA=`
   - Build verified: binary at `/nix/store/...-file-and-image-renamer-0.1.0/bin/file-renamer` runs correctly

2. **NixOS service module** — `modules/nixos/services/file-and-image-renamer.nix`
   - Options: `enable`, `package`, `user`, `watchDirectory`, `apiKeyFile`, `logDirectory`
   - Defaults: user=lars, watchDirectory=/home/lars/Desktop, apiKeyFile=/home/lars/.zai_api_key
   - systemd user service (not system service) — runs under user lars with `graphical-session.target`
   - Watcher script wrapper reads API key from file and sets `ZAI_API_KEY` + `DESKTOP_PATH` env
   - Hardened: MemoryMax=512M, PrivateTmp, NoNewPrivileges, ProtectClock, etc.
   - Log directory created via `systemd.tmpfiles.rules`
   - Package installed system-wide via `environment.systemPackages`

3. **Flake wiring** — `flake.nix` modifications
   - 3 new path-based flake inputs: `file-and-image-renamer-src`, `cmdguard-src`, `go-output-src` (all `flake = false`)
   - `fileAndImageRenamerOverlay` added to `linuxOnlyOverlays` + perSystem overlays
   - Module imported in `imports` list and `nixosConfigurations.evo-x2.modules`
   - Package exposed in `perSystem.packages` for Linux

4. **Service enabled in evo-x2** — `platforms/nixos/system/configuration.nix`
   - `services.file-and-image-renamer.enable = true`

5. **Verification**
   - `nix flake check --no-build` passes (all checks)
   - `nix build .#file-and-image-renamer` succeeds
   - `nix eval .#nixosConfigurations.evo-x2.config.services.file-and-image-renamer` returns correct config
   - Binary `--help` output confirmed

---

## B) PARTIALLY DONE

1. **Project's own `flake.nix`** — `file-and-image-renamer/flake.nix` still has `vendorHash = null` and doesn't handle local replace directives. It won't build standalone via `nix build` in the project directory. The integration works via SystemNix's package derivation, not the project's own flake.

2. **Go vendor directory** — `go mod vendor` was run during debugging, creating a `vendor/` directory in the project. This is untracked and should be added to `.gitignore` or deleted (the SystemNix build uses `proxyVendor = true` which doesn't need it).

---

## C) NOT STARTED

1. **Actual deployment** — `nh os switch .` has NOT been run. The integration is verified in eval/build but not deployed to the running evo-x2 system.

2. **API key setup** — The service expects `~/.zai_api_key` to exist on evo-x2. This needs to be verified/provisioned after deployment.

3. **Service runtime testing** — Once deployed, need to verify:
   - `systemctl --user status file-and-image-renamer`
   - Watcher actually detects new screenshots on Desktop
   - GLM-4.6V API calls succeed
   - Dead-letter queue handles failures

4. **sops-nix integration** — API key is currently a plain file at `~/.zai_api_key`. Should be migrated to sops-nix secrets management (like hermes uses `sops.templates."hermes-env".path`).

5. **Darwin integration** — The module is NixOS-only. No home-manager or darwin module created in SystemNix (the project's own `flake.nix` has `darwinModules` and `homeManagerModules` but they're broken due to vendor issues).

6. **GitHub-based flake inputs** — Currently using `path:` URLs which only work on this machine. Once repos are pushed, should switch to `github:` URLs for portability.

---

## D) TOTALLY FUCKED UP

1. **Project's standalone nix build is BROKEN** — `cd file-and-image-renamer && nix build .#file-and-image-renamer` fails with vendor inconsistency errors. The `vendorHash = null` + local `replace` directives in `go.mod` make it impossible to build without the SystemNix wrapper. This is a pre-existing issue, not caused by this integration.

2. **Path-based flake inputs are NOT portable** — `path:/home/lars/projects/...` only works on this specific machine. Anyone else cloning SystemNix will get build failures. This is a known tradeoff (same as `monitor365-src` uses SSH URLs, but file-and-image-renamer isn't on GitHub yet).

---

## E) WHAT WE SHOULD IMPROVE

1. **Fix project's own flake.nix** — Add `proxyVendor = true`, `postPatch` for replace directives, and compute `vendorHash`. Makes the project buildable standalone.

2. **Add vendor/ to .gitignore** — Prevent the vendor directory from ever being committed.

3. **Switch to GitHub flake inputs** — Once file-and-image-renamer, cmdguard, and go-output are pushed to GitHub, replace `path:` URLs with `github:LarsArtmann/...` for portability.

4. **sops-nix for API key** — Store `ZAI_API_KEY` in sops secrets, reference via `EnvironmentFile` like hermes does. Eliminates the plain-text key file.

5. **Add home-manager module** — Create a cross-platform HM module so the tool + watcher work on macOS too (matching the project's existing `homeManagerModules`).

6. **Add a health check** — The `file-renamer health` command exists; wire it into the existing `systemd` service watchdog or `service-health-check` script.

7. **Add the package to the project's CI** — GitHub Actions `go-test.yml` and `nix-check.yml` exist but the nix build is broken.

8. **Integrate with existing monitoring** — The service should appear in the homepage dashboard alongside hermes, monitor365, etc.

---

## F) Top 25 Things To Do Next

| #   | Priority | Task                                                                    | Effort |
| --- | -------- | ----------------------------------------------------------------------- | ------ |
| 1   | P0       | Deploy to evo-x2: `nh os switch .`                                      | 5m     |
| 2   | P0       | Verify service starts: `systemctl --user status file-and-image-renamer` | 2m     |
| 3   | P0       | Verify API key exists on evo-x2: `~/.zai_api_key`                       | 1m     |
| 4   | P1       | Fix project's own flake.nix (proxyVendor + postPatch + vendorHash)      | 15m    |
| 5   | P1       | Add `vendor/` to `.gitignore` in file-and-image-renamer                 | 1m     |
| 6   | P1       | Test end-to-end: drop a screenshot on Desktop, verify rename            | 5m     |
| 7   | P1       | Migrate API key to sops-nix (like hermes pattern)                       | 20m    |
| 8   | P2       | Push file-and-image-renamer to GitHub                                   | 5m     |
| 9   | P2       | Push cmdguard to GitHub                                                 | 5m     |
| 10  | P2       | Push go-output to GitHub                                                | 5m     |
| 11  | P2       | Switch flake inputs from `path:` to `github:` URLs                      | 10m    |
| 12  | P2       | Add `nix flake check` CI for file-and-image-renamer repo                | 10m    |
| 13  | P2       | Create cross-platform home-manager module in SystemNix                  | 30m    |
| 14  | P3       | Wire health check into service-health-check script                      | 10m    |
| 15  | P3       | Add to homepage dashboard                                               | 10m    |
| 16  | P3       | Add `file-renamer stats` cron job for daily stats reporting             | 15m    |
| 17  | P3       | Add log rotation config (lumberjack already in Go deps)                 | 10m    |
| 18  | P3       | Add Prometheus metrics endpoint for the watcher                         | 30m    |
| 19  | P3       | Add `deadletter` alerting (notify on dead-letter queue growth)          | 20m    |
| 20  | P4       | Add `compare` command as scheduled benchmark                            | 15m    |
| 21  | P4       | Document integration in project's NIX_INTEGRATION.md                    | 10m    |
| 22  | P4       | Update project AGENTS.md with SystemNix integration info                | 5m     |
| 23  | P4       | Add nix integration test (nixosTest)                                    | 30m    |
| 24  | P4       | Add desktop file entry for `file-renamer` GUI-less operation            | 5m     |
| 25  | P4       | Explore hash database persistence across rebuilds                       | 15m    |

---

## G) Top #1 Question I Cannot Figure Out Myself

**Are cmdguard and go-output already published on GitHub (even as private repos)?**

The current integration uses `path:` flake inputs which break portability. If these repos exist on GitHub (even `git+ssh://git@github.com/LarsArtmann/cmdguard`), I can switch to proper URLs immediately. If they're local-only, we need to publish them first. The `go.mod` replace directives point to `/home/lars/projects/cmdguard` and `/home/lars/projects/go-output`, and I cannot determine from here whether these have GitHub remotes configured.

---

## Architecture Decisions Made

| Decision                          | Rationale                                                                                 |
| --------------------------------- | ----------------------------------------------------------------------------------------- |
| Path-based flake inputs           | Temporary; works for dev machine, avoids blocking on GitHub publish                       |
| `proxyVendor = true`              | Required because `go mod vendor` chokes on replace directives pointing to nix store paths |
| `postPatch` substituteInFile      | Minimal, reliable approach to rewrite go.mod at build time                                |
| Systemd user service (not system) | Matches monitor365 pattern; needs user session for Desktop access                         |
| ZAI_API_KEY_FILE env var          | Decouples key file path from service definition; future sops migration path               |

## Files Changed

```
SystemNix/
  flake.nix                                    +29  (inputs, overlay, module, package)
  flake.lock                                   +42  (new input lock entries)
  pkgs/file-and-image-renamer.nix              NEW  (package derivation)
  modules/nixos/services/file-and-image-renamer.nix  NEW  (NixOS module)
  platforms/nixos/system/configuration.nix     +5   (enable service)
```
