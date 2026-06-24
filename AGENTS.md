# SystemNix: Agent Guide

Cross-Platform Nix Configuration (macOS + NixOS) — `github:LarsArtmann/SystemNix`

---

## Architecture

```
flake.nix              # Entry point (flake-parts), mkLarsPackages, ~55 inputs
lib/                   # Helpers — import via lib/default.nix (single import point)
modules/nixos/services/# flake-parts modules, auto-discovered by filename
pkgs/                  # Custom packages (buildGoModule, dms-plugins/)
overlays/              # shared.nix (callPackage + activitywatch + d2 Darwin stub), linux.nix (flake-input overlays)
platforms/common/      # Shared (~80%): home-base.nix, programs/, packages/, theme.nix, locale.nix
platforms/darwin/      # macOS (nix-darwin) — user: larsartmann
platforms/nixos/       # NixOS — user: lars
  desktop/quickshell.nix # Quickshell HM module (DankMaterialShell)
scripts/               # Shell + Python operational scripts
```

| System | Hostname | Platform | Constraints |
|--------|----------|----------|-------------|
| macOS | `Lars-MacBook-Air` | aarch64-darwin | 24GB RAM, 256GB SSD (90%+ full) |
| NixOS | `evo-x2` | x86_64-linux | 128GB RAM, AMD Ryzen AI Max+ 395 |

---

## Key Procedures

### Adding a Service

1. Create `modules/nixos/services/<name>.nix` — filename IS the module name, auto-discovered. Prefix `_` for non-module helpers
2. Enable in `platforms/nixos/system/configuration.nix`
3. Ports go in `lib/ports.nix` — never hardcode. Caddy vHosts go in `caddy.nix` via `protectedVHost "subdomain" port`
4. Import `import ../../../lib/default.nix lib` for `harden`, `serviceDefaults`, `onFailure`, `serviceTypes`, `ports`, etc.
5. Use `harden {} // serviceDefaults {}` for systemd. **Must** set `startLimitBurst = 5; startLimitIntervalSec = 300;`
6. All vHosts in `caddy.nix`, all Homepage tiles in `homepage.nix` (guard conditional tiles with `lib.optionalString`)
7. `WatchdogSec` ONLY on services that send `WATCHDOG=1` via `sd_notify()` — Type=notify alone is NOT sufficient

### Private Go Repos (LarsArtmann)

All private repos use `git+ssh://` URLs. Go tool packages defined in `mkLarsPackages` in `flake.nix` — NOT overlays.

`mkPreparedSource` (from `go-nix-helpers`) auto-strips local replaces, normalizes pseudo-versions, generates `replace` directives. Features: `subModules` (handles `/v2` suffixes — include version in list entry, kept in path, stripped from dir), `stripLocalReplaces`, `subModuleVersionNormalize`.

**vendorHash breaking?** Set `vendorHash = ""`, build, paste `got:` hash.
**Core dep cascade?** Update dep repo first → publish tags → each consumer: `vendorHash = ""` → `nix flake lock --update-input <repo>`
**`proxyVendor = true`:** `go mod tidy` safe in both phases. **`proxyVendor = false`:** AVOID `overrideModAttrs` with `go mod tidy` — causes "inconsistent vendoring"
**Versioning:** Published = hardcode semver. Internal = `self.rev or self.dirtyRev or "dev"`

### Quickshell (DankMaterialShell)

Quickshell is a QtQuick desktop shell replacing Waybar, Dunst, Wlogout, polkit_gnome. Configured via DankMaterialShell's upstream HM module.

- **Input:** `dankMaterialShell` (github:AvengeMedia/DankMaterialShell/stable) — brings `quickshell` transitively, no separate quickshell input
- **HM module:** `platforms/nixos/desktop/quickshell.nix` — imports DMS upstream, sets `programs.systemnix-quickshell.enable = true`
- **DMS plugins:** `pkgs/dms-plugins/` — 10 SystemNix-native widgets (Ollama, DNS stats, GPU, Task radar, Service health, Btrfs, Voice agent, Camera, Server resources, CRM) using `PluginComponent` + `plugin.json`
- **DevShell:** `nix develop .#quickshell` for hot-reload QML development with `qmlls` LSP
- **Parallel run:** Waybar kept alongside DMS during migration. Disabled in P2 when DMS is proven
- **DMS niri module:** Import `dankMaterialShell.homeModules.niri` for niri-specific integration (workspace IPC via `$NIRI_SOCKET`)
- **`inputs.nixpkgs.follows`** on the DMS input is MANDATORY — mismatched Qt causes runtime crashes

### Sops + Age

```bash
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops --set '["key"] "value"' file.yaml
```
- `SOPS_AGE_KEY` in RAM only — never write age key to disk. `SOPS_AGE_SSH_PRIVATE_KEY_FILE` does NOT work with `sops` CLI
- Secrets with service-specific owners MUST be guarded with `lib.optionalAttrs config.services.X.enable` — one bad owner blocks ALL secrets atomically
- See `.crush/skills/sops-secret-management/SKILL.md` for full workflow

### Hermes

Active pip extras: `messaging`, `anthropic`, `firecrawl`, `edge-tts`, `fal`, `exa`. Do NOT add blindly — `voice` has complex native deps, `matrix` needs python-olm (Linux-only).

### BTRFS (evo-x2)

Root (`@`): daily via btrbk, 14d+4w retention. `/data`: NOT snapshotted — BTRFS toplevel (subvolid=5). Pre-deploy snapshots: manual only.

---

## Critical Rules

- **Use flake commands** — `nix run .#deploy`, never raw `nixos-rebuild`/`darwin-rebuild`
- **Test first** — `nix flake check --no-build` (syntax) or `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (eval)
- **`trash` not `rm`**, **`git mv` not `mv`**, **2-space indentation**, **`config.allowBroken = false`**, **No OpenZFS on macOS** (kernel panics, ADR-003)
- **Open new terminal** after deploy (shell changes need new session)
- **Never hardcode** `localhost:PORT` — derive from config. All ports in `lib/ports.nix`, all images in `lib/images.nix`

---

## Non-Obvious Gotchas

| Issue | Why It Matters |
|-------|---------------|
| `lib.mkMerge` + flake-parts | Does not work — use inline config or imports |
| d2 Darwin overlay | Re-instantiates d2 with stubs; removing it breaks Darwin eval |
| Niri `BindsTo` → `Wants=` | `BindsTo` kills niri on deploy |
| awww-wallpaper ordering | `After=awww-daemon` creates cycle; use `graphical-session.target` |
| Unbound `do-ip6 = false` | evo-x2 has no global IPv6 — any new unbound instance needs this |
| otel-tui on Darwin | Never add — 40+ min builds + disk exhaustion |
| Darwin HM user | `users.users.larsartmann.home` required in `platforms/darwin/default.nix` |
| Pocket ID bootstrap | `pocket-id-config.provision.enable = true` — creates admin + clients automatically. Only manual step: register passkey at `/setup` |
| Caddy `handle_path` | STRIPS prefix before proxying. Use `handle` when backend expects full path |
| Dozzle module eval | `modules/nixos/services/dozzle.nix` with options breaks `nix flake check`. Use inline `virtualisation.oci-containers` |
| `signoz.target` | SigNoz/ClickHouse use custom `signoz.target` (NOT `multi-user.target`) — all SigNoz components use `wantedBy = ["signoz.target"]` |
| `svcEnabled` helper | In `sops.nix`, use `svcEnabled "name"` — safer than `config.services.X.enable` (rpi3 doesn't import all modules) |
| sops secret owners | Non-existent user/group blocks ALL secrets atomically. Guard with `lib.optionalAttrs` |
| `harden` vs `hardenUser` | User services (systemd --user) must use `hardenUser`. Desktop notify services pass `hardenFn = hardenUser` |
| OOM crash chain | Helium/Electron renderers grow unbounded in `user-1000.slice` → journald starved → sp5100-tco WDT hard reset (60s). This is WHY `user-${uid}.slice` has `MemoryHigh=56G; MemoryMax=64G` in `boot.nix`, oomd is tuned to 50%/20s, and per-service MemoryMax alone is insufficient (user processes run outside it) |
| MGLRU thrashing prevention | `min_ttl_ms=1000` set via `mglru-thrash-protection.service` in `boot.nix`. Protects youngest page generation from eviction for 1s under pressure — prevents the thrash spiral that starves journald. Sysfs-only (`/sys/kernel/mm/lru_gen/`), cannot use `boot.kernel.sysctl`. Compiled in (`0x0007`) but defaults to 0 (disabled) |
| Docker services target | All Docker/container services use `multi-user.target` (NOT `graphical.target`) |
| `harden` ExecStart trap | `harden {}` now passes through extra args, but NEVER put `ExecStart`/`Type`/`RemainAfterExit` inside it — merge with `//` outside instead. The `harden` function only processes named hardening params; extras go to `passthrough` |
| ext4 `discard=async` | **BTRFS-only mount option.** ext4 uses bare `discard` (boolean). `discard=async` on ext4 → `fsconfig() failed` → mount fails → `local-fs.target` fails → **emergency shell**. Caused the 2026-06-23 boot emergency |
| Non-`nofail` mounts = boot hazard | Any `fileSystems` entry without `nofail` that fails to mount brings down `local-fs.target` → emergency shell. ALWAYS add `nofail` for non-root mounts (cache, data, etc.) |
| `oci-containers` backend defaults to Podman | `virtualisation.oci-containers.backend` defaults to `"podman"`, silently pulling in a full Podman daemon alongside Docker. Set `backend = "docker"` when Docker is already enabled |
| Docker 29.x `userland-proxy-path` | Docker 29.x moved `docker-proxy` to the internal moby derivation, which nixpkgs doesn't expose. Daemon fails with "invalid userland-proxy-path". Fix: `daemon.settings.userland-proxy = false` |
| Docker containerd bbolt corruption | OOM/hard reset corrupts `/data/docker/containerd/daemon/io.containerd.metadata.v1.bolt/meta.db`. Recovery: stop docker → `mv meta.db meta.db.bak` → remove `containers/`, `containerd/`, `network/` dirs → restart. Preserves volumes/images |
| dnsblockd + `ProtectSystem=strict` | SQLite needs a writable CWD. Set `WorkingDirectory = "/var/lib/dnsblockd"` alongside `StateDirectory` or SQLite CANTOPEN errors |
| `mkFilesystem` helper | `lib/filesystems.nix` validates mount options at eval time. Use it instead of raw `fileSystems` attrsets to catch cross-fs contamination (e.g. `discard=async` on ext4) |
| Pre-deploy validation | `nix run .#pre-deploy-check` catches boot-breaking issues before switch. Runs automatically as part of `nix run .#deploy` |
| DMS `inputs.nixpkgs.follows` | MANDATORY — mismatched Qt versions between DMS/quickshell and system nixpkgs cause silent runtime crashes |
| DMS notification conflict | Only one DBus notification daemon can run. Dunst must be disabled (`services.dunst.enable = lib.mkForce false`) when DMS is active |
| Quickshell pre-1.0 | Breaking changes expected before 1.0. Pin DMS to `stable` branch. Migration guides promised |
| QML is programming | Quickshell configs are applications, not config files. Requires QML knowledge. Use `nix develop .#quickshell` for LSP + hot-reload |
| `nixpkgs-unstable` vs `nixos-unstable` | **Use `nixos-unstable` in flake inputs.** Hydra only caches expensive builds (ROCm, CUDA) on the `nixos-unstable` jobset — `nixpkgs-unstable` produces different hashes with no binary cache for these. `ollama-rocm` was a 30+ min local build on `nixpkgs-unstable` but substitutes instantly from `nixos-unstable` |

---

## Build & Deploy

```bash
nix flake check --no-build  # Validate syntax (fast)
nix run .#deploy            # Build + deploy via nh
nix fmt                     # treefmt + alejandra
```

---

## Platform Constraints

**Darwin:** 256GB SSD 90-95% full, 24GB RAM. `nix-collect-garbage` hangs; clear caches before builds. Never add packages that build from source >10min. HM config is minimal — no terminal/editor/theme parity with NixOS.

**GPU (NixOS):** `OLLAMA_GPU_OVERHEAD=8589934592` (8 GiB) reserves headroom for compositor. Memory fractions are per-service, not system-wide.
