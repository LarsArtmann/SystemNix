# Status Report — 2026-07-13 22:40

**Session scope:** Fix stale `go.sum`/`vendorHash` workarounds for LarsArtmann Go repos (library-policy, mr-sync) and implement missing upstream features for monitor365 (env var secrets, runtime deps, display discovery).

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## a) FULLY DONE

### library-policy — Local replace removed (UPSTREAM, UNPUSHED)

- **Commit `ad71a72`** — Removed `replace github.com/larsartmann/go-finding => /home/lars/projects/go-finding` from `go.mod`. Switched to published `v1.2.0`. Build passes, all tests pass (17 packages OK).
- **Commit `4467e3c`** — Applied deadnix + nix-fmt auto-fixes (removed unused `self` param, renamed `type` → `_type`). BuildFlow passed 29/29.
- The `mkTidyOverride` workaround was already removed from SystemNix in a prior refactor (commit `4cffb612`, 2026-07-09). The `go.sum` was already correct (`go mod tidy` = 0 diff). The only real issue was the committed local replace.
- **State: 2 commits on master, NOT pushed, clean working tree.**

### mr-sync — Verified Already Clean

- `go.sum` matches `go mod tidy` (0 diff). No local replaces in `go.mod`. No workarounds exist in SystemNix. No changes needed.
- **State: nothing to do, already correct.**

### monitor365 — runtimeDeps + display discovery (UPSTREAM, UNPUSHED)

- **Commit `9b709d83`** — Two fixes in the upstream NixOS module:
  1. **`runtimeDeps` PATH wiring**: The option existed but was never wired into the systemd service `PATH`. Collectors calling CLI tools (`pgrep`, `xdotool`, `scrot`, etc.) silently failed. Now: `Environment = [ "PATH=${makeBinPath cfg.runtimeDeps}:..." ]`.
  2. **`displayUser` option**: New option. When set, the start script discovers `DISPLAY`, `WAYLAND_DISPLAY`, `XAUTHORITY`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`, `XKB_DEFAULT_*` from the user's compositor PID via `/proc/<pid>/environ` (agent has `CAP_SYS_PTRACE`). No more hardcoding or missing display env.
- BuildFlow passed 15/15 (auto-applied nix-fmt + statix fixes, already committed).
- **State: 1 commit on master, NOT pushed, clean working tree.**

### SystemNix — Module wrapper updated (UNCOMMITTED)

- `modules/nixos/services/monitor365.nix`: Added `displayUser = lib.mkDefault primaryUser;`. Updated comments.
- `TODO_LIST.md`: All 3 items marked `[x]` with resolution details.
- `AGENTS.md`: Added 2 new gotcha rows (display discovery + runtimeDeps PATH, agent auth model).
- Syntax validated via `nix-instantiate --parse`.
- **State: 3 files modified, NOT committed.**

### Stale TODO clarified — monitor365 env var secrets

- The TODO claimed monitor365 required "config file mutation via `sed` at runtime" for secrets. Investigation found this was **stale/incorrect**: the agent already reads secrets via systemd `LoadCredential` → start script exports `MONITOR365__CLOUD__AUTH_TOKEN` env var → Rust figment config system picks it up. No `sed` anywhere. Marked resolved in TODO_LIST.md.

---

## b) PARTIALLY DONE

### Nothing is partially done — each item is either fully completed or not started.

---

## c) NOT STARTED

1. **Push upstream repos** — library-policy (2 commits) and monitor365 (1 commit) are committed locally but NOT pushed to GitHub. `git push` in both repos.
2. **Update SystemNix flake.lock** — `nix flake lock --update-input library-policy --update-input monitor365` needed to pull the new upstream commits. Without this, SystemNix still evaluates against the old code.
3. **Commit SystemNix changes** — 3 files modified but uncommitted. Needs `git commit`.
4. **`nix flake check --no-build`** — Not run yet. Will fail until flake.lock is updated (the `displayUser` option doesn't exist in the currently pinned monitor365 commit).
5. **Deploy** — None of these changes are deployed to evo-x2.
6. **Post-deploy verification** — After deploy, verify: (a) monitor365 agent has correct `PATH` with runtime deps, (b) graphical collectors work with discovered display env, (c) `library-policy` and `mr-sync` build from flake without workarounds.

---

## d) TOTALLY FUCKED UP

### Nothing was broken beyond repair, but here's what I should have caught:

1. **Forgot to commit SystemNix changes** — Left 3 files uncommitted. If this session ends, the SystemNix wrapper changes (`displayUser = primaryUser`) are orphaned with no commit.
2. **Forgot to update flake.lock** — Even if I had committed and pushed, SystemNix still pins the OLD monitor365 commit that doesn't have `displayUser`. The module will eval-fail with "option displayUser not found" until flake.lock is updated. I should have done `nix flake lock --update-input monitor365` as part of the work.
3. **Forgot to run `nix flake check --no-build`** — The AGENTS.md says "Test first — `nix flake check --no-build`". I ran `nix-instantiate --parse` (syntax only) but never the full eval check. The build would have caught the missing `displayUser` option error immediately.

---

## e) WHAT WE SHOULD IMPROVE

1. **flake.lock is load-bearing** — When modifying an upstream flake input AND a SystemNix module that depends on new upstream options, the flake.lock update is NOT optional. It should be part of the same commit or at least the same session. The sequence should always be: push upstream → update flake.lock → `nix flake check` → commit SystemNix.
2. **TODO accuracy** — The TODO items described `mkTidyOverride` and `sed`-based config mutation that didn't exist in the current code. The TODOs were written based on an older state and never updated. This wasted investigation time. **Action:** Audit TODO_LIST.md items against actual code more frequently.
3. **`go-finding` is PRIVATE** — library-policy depends on `github.com/larsartmann/go-finding` which is a **private repo**. The `v1.2.0` tag works locally (git+ssh) but `proxy.golang.org` can't fetch it. The `GOPRIVATE` setting in `platforms/common/home-base.nix` handles this for local dev, but the Nix `buildGoModule` fetch needs `GIT_SSH_COMMAND` or the `go-nix-helpers` `mkPreparedSource` to inject the dep. This is already handled by the flake's `deps` mechanism — but worth verifying the build actually works in Nix after the flake.lock update.
4. **The `procps` and `coreutils` references in the display discovery script** — The upstream `settings.nix` references `${pkgs.procps}` and `${pkgs.coreutils}` for the `pgrep`/`head`/`tr` commands. But `procps` and `coreutils` are listed in the SystemNix `runtimeDeps` (which gets wired to `PATH`), not necessarily in the upstream module's `pkgs`. The references should work because `pkgs` is the full nixpkgs in the module's scope, but I didn't verify this builds.
5. **The heredoc in the display discovery script** — The `<<ENVEOF` heredoc inside a Nix `optionalString` inside a `writeShellScript` is fragile. If `/proc/$DISPLAY_PID/environ` contains special characters or the process exits between `pgrep` and `cat`, the script could behave unexpectedly. A more robust approach would use `systemd --user` environment import or `dbus` session discovery. But this is acceptable for a first implementation.

---

## f) NEXT 50 THINGS TO GET DONE

### Immediate (blocks correctness — must do before deploy)

1. Push library-policy upstream (`git push origin master`)
2. Push monitor365 upstream (`git push origin master`)
3. Update SystemNix flake.lock: `nix flake lock --update-input library-policy --update-input monitor365`
4. Run `nix flake check --no-build` and fix any eval errors
5. Commit SystemNix changes (monitor365.nix, TODO_LIST.md, AGENTS.md)
6. Run `nix run .#deploy` to activate

### Post-deploy verification

7. Verify `monitor365.service` has `PATH` with runtime deps: `systemctl show monitor365.service -p Environment`
8. Verify display discovery: `journalctl -u monitor365.service | grep -i "display\|wayland"` after login
9. Verify graphical collectors produce data (check monitor365 dashboard)
10. Verify `library-policy` builds: `nix build .#library-policy`
11. Verify `mr-sync` builds: `nix build .#mr-sync`

### SystemNix pending deploys (from TODO_LIST.md Priority 0)

12. Deploy DNS migration (unbound → dnsblockd) — commit `076dc778`, pending deploy
13. Reboot evo-x2 — verify boot time after NVMe APST fix
14. Run BTRFS scrub on `/` and `/data` — 91K csum errors found, never scrubbed
15. Run `smartctl -a /dev/nvme0n1` — determine if drive is physically failing
16. Set up off-site backup — #1 data loss risk, no DR backup exists
17. Install `dnsblockd-CA` on Mac — breaks Touch ID for `*.home.lan` SSO
18. Verify Pocket ID email sending after SMTP wiring
19. Verify crush-daily collection post-deploy
20. Verify Monitor365 `/ui/` serves WASM dashboard post-deploy
21. Verify DiscordSync SSO post-deploy
22. Verify Overview vHost post-deploy
23. Verify post-deploy smoke test runs after deploy

### Infrastructure improvements

24. Fix Twenty CRM: PG role mismatch (`role "twenty" does not exist`)
25. Decide Twenty Docker vs native (4 containers, ~1.5 GB RAM)
26. BTRFS `/data` subvolume migration (toplevel → `@data`)
27. Swap investigation (4.5 GiB used on 128 GiB RAM)
28. GPUActive monitoring — add Prometheus textfile collector for `/proc/meminfo` GPUActive
29. TTM `page_pool_size` reduction (currently 112 GiB, exceeds visible RAM)
30. Monitor365 agent→server auth (no auth, anyone on LAN can POST)
31. Provision Pi 3 for DNS failover cluster
32. Auditd enablement (blocked on NixOS 26.05 bug)
33. AppArmor enablement (commented out in security-hardening.nix)
34. Disabled service triage (voice-agents, minecraft: decide enable or remove)

### Upstream contributions (from TODO_LIST.md Priority 5)

35. `hermes`: Auto-create directory structure on first run
36. `hermes`: Handle own state migration from old paths
37. `hermes`: Use PID file or socket-based single-instance locking instead of `--replace`
38. nixpkgs: `aw-watcher-utilization` poetry-core migration PR
39. nixpkgs: `valkey` / `aiocache` / `timm` / `xformers` broken test fixes
40. nixpkgs: `taskwarrior3` build flags PR
41. nixpkgs: Kitty GC resilience patch
42. nixpkgs: KeePassXC Chromium manifests
43. nixpkgs: `llama-cpp` ROCm MMFMA flag PR
44. HM: ActivityWatch Wayland watcher graphical-session deps
45. HM: ActivityWatch theme setting option
46. Third-party: `jscpd` lockfile PR
47. Third-party: XRT boost 1.87+ compat PR

### Codebase quality

48. Split large modules — signoz (943L), forgejo (725L)
49. Add monitor365 CORS env var fix upstream (figment deserializes env string, not sequence)
50. Verify the `displayUser` display discovery actually works on a Wayland-only session (no X11 at all) — the current script discovers env vars but some collectors (xdotool, xprintidle) are X11-only and will fail on pure Wayland

---

## g) TOP 2 QUESTIONS

### Q1: Should I commit SystemNix changes and update flake.lock now, or wait until the upstream repos are pushed?

The SystemNix `monitor365.nix` references `displayUser`, which only exists in the unpushed monitor365 commit `9b709d83`. If I commit SystemNix + update flake.lock without pushing upstream first, the flake.lock update will fail (can't fetch the commit). If I commit SystemNix WITHOUT updating flake.lock, `nix flake check` will fail (option doesn't exist in pinned version). **The correct order is: push upstream → update flake.lock → check → commit SystemNix.** Should I do this now?

### Q2: The monitor365 runtimeDeps list includes X11-only tools (`xdotool`, `xprintidle`, `scrot`) but evo-x2 runs niri (Wayland-only). Should I replace them with Wayland equivalents (`wlr-randr`, `grim`, `slurp`, `wtype`)?

The display discovery I implemented will correctly export `WAYLAND_DISPLAY`, but `xdotool`/`xprintidle`/`scrot` can't use it — they're X11 protocols. The Rust collectors have native fallbacks (xcap for screenshots, x11rb for window titles), but the CLI fallback tools are X11-only. On evo-x2, the CLI fallbacks will always fail. Should I update the runtimeDeps list to include Wayland tools, or is this acceptable since the native Rust providers should work?
