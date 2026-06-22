# SystemNix: Agent Guide

**Project Type:** Cross-Platform Nix Configuration (macOS + NixOS)
**Repo:** `github:LarsArtmann/SystemNix`
**Current Build:** ✅ All checks passed (`nix flake check --no-build`)

---

## Architecture

```
SystemNix/
├── flake.nix                    # Entry point (flake-parts)
├── justfile                     # Task runner
├── overlays/                    # Shared + Linux-only overlays
│   ├── default.nix              # Aggregator (sharedOverlays, linuxOnlyOverlays, disableTests)
│   ├── shared.nix               # Darwin + NixOS overlays
│   └── linux.nix                # NixOS-only overlays
├── lib/                         # Shared NixOS module helpers (imported via lib/default.nix)
│   ├── default.nix              # Aggregator — single import point
│   ├── systemd.nix              # harden / hardenUser
│   ├── systemd/service-defaults.nix  # serviceDefaults / serviceDefaultsUser
│   ├── types.nix                # Reusable option constructors (serviceTypes)
│   ├── docker.nix               # mkDockerServiceFactory
│   ├── ports.nix                # Centralized port registry (collision-protected)
│   ├── rocm.nix                 # ROCm GPU runtime helpers
│   └── images.nix               # Pinned container image references
├── modules/nixos/services/      # flake-parts service modules (auto-discovered)
├── pkgs/                        # Custom packages (buildGoModule, etc.)
├── platforms/
│   ├── common/                  # Shared (~80%)
│   ├── darwin/                  # macOS (nix-darwin)
│   └── nixos/                   # NixOS
└── scripts/                     # Operational scripts
```

Two machines:
| System | Hostname | Platform | Constraints |
|--------|----------|----------|-------------|
| macOS | `Lars-MacBook-Air` | aarch64-darwin | 24GB RAM, 256GB SSD (90%+ full), disk-constrained |
| NixOS | `evo-x2` | x86_64-linux | 128GB RAM, AMD Ryzen AI Max+ 395 |

---

## Key Patterns

### Adding a Service

1. Create `modules/nixos/services/<name>.nix` as a flake-parts module
2. **Convention:** filename (minus `.nix`) IS the module name. The flake auto-discovers all `.nix` files in the directory — no manual list to update
3. Non-module helpers must be prefixed with `_` (e.g., `_signoz-alerts.nix`) — automatically skipped
4. Enable in `platforms/nixos/system/configuration.nix`
5. If behind Caddy, define a `port` option and reference it in `caddy.nix` — never hardcode ports
6. Import helpers from `import ../../../lib/default.nix lib` — gives `harden`, `hardenUser`, `serviceDefaults`, `onFailure`, `serviceTypes`, etc.
7. Use `harden {} // serviceDefaults {}` for systemd hardening. User services: `hardenUser {}`

### LarsArtmann Go Tool Packages

All private LarsArtmann repos use `git+ssh://` URLs. No `path:` inputs.

LarsArtmann Go tool packages (art-dupl, buildflow, etc.) are defined in `mkLarsPackages` in `flake.nix`'s top-level `let` binding — NOT as overlays. This function is the single source of truth:

1. `perSystem.packages` calls `mkLarsPackages system` so `nix build .#art-dupl` works
2. `specialArgs` passes `larsPackages = mkLarsPackages "<system>"` to NixOS/Darwin configs
3. `base.nix` receives `larsPackages` and adds them to `environment.systemPackages`

Packages needing local overrides (vendorHash, `go mod tidy`) are handled inside `mkLarsPackages` via `overrideAttrs`. Platform safety: `flakePkg` returns `null` for unsupported systems, `filterAttrs` removes them.

The remaining overlays in `overlays/shared.nix` are REAL overlays (callPackage for local .nix files, activitywatch override, d2 Darwin stub). Only `linux.nix` uses flake-input `.overlays.default` — those are legitimate overlays from upstream flakes.

### `_local_deps` Pattern (Private Go Repos)

`mkPreparedSource` is centralized in `go-nix-helpers` (`git+ssh://git@github.com/LarsArtmann/go-nix-helpers`). Auto-features: `subModules` (replace directives), `subModuleVersionNormalize` (pseudo-version normalization), `stripLocalReplaces` (strips `=> /home/...`). Only use `postPatchExtra` for repo-specific patches. When upstream deps change, set `vendorHash = ""`, build, paste the `got:` hash.

**Versioned sub-modules (v2+):** `mkPreparedSource`'s `subModules` feature handles `/v2` major version suffixes — include the version in the sub-module list entry and it will be kept in the module path but stripped from the local directory path. e.g. `subModules = { "github.com/larsartmann/go-cqrs-lite" = [ "codec/v2" "command/v2" "core" ]; };` generates `.../codec/v2 => ./_local_deps/go-cqrs-lite/codec`. Must include ALL transitive sub-modules (e.g., `command/v2`, `query/v2`, `schema/v2` even if not in root go.mod) because `go mod tidy` needs replace directives for the full dependency graph.

**proxyVendor pattern for workspace repos:** `inherit proxyVendor; overrideModAttrs = _: { preBuild = "export HOME=$TMPDIR; go mod tidy"; }; preBuild = "export HOME=$TMPDIR; go mod tidy";` — go mod tidy in BOTH phases ensures consistent module resolution.

### Go Repo Update Checklist

Core private Go deps (`go-output`, `go-branded-id`, etc.) cascade to all consumers on change:

1. Update the dep repo first (publish tags for sub-modules)
2. In each consumer: `vendorHash = ""`, build, paste `got:` hash
3. Verify transitive deps are in `go.mod`/`go.sum`
4. Update SystemNix `flake.lock` last: `nix flake lock --update-input <repo>`

### Nix Versioning Convention

**Published packages:** hardcode semver. **Internal overlays:** `self.rev or self.dirtyRev or "dev"` is fine.

### overrideModAttrs + proxyVendor Pattern

**With `proxyVendor = true`:** `go mod tidy` is safe in BOTH `overrideModAttrs.preBuild` (go-modules derivation) and `preBuild` (main build). With `proxyVendor`, the main build uses `GOPROXY=file://$goModules` (NOT `GOPROXY=off`), so `go mod tidy` can resolve modules. This is the recommended pattern for repos using `mkPreparedSource` with private deps.

**With `proxyVendor = false` (default):** AVOID `overrideModAttrs` with `go mod tidy` — it causes "inconsistent vendoring" because the main build uses `GOPROXY=off` + validates `vendor/modules.txt`.

When `vendorHash` breaks after a dep change: set to `""`, build, paste `got:` hash.

### Config-Derived URLs

Never hardcode `localhost:PORT`. Derive from service config.

### Sops + Age Toolchain

sops secrets use SSH host keys. The `sops` CLI needs **age identity format** — convert with `ssh-to-age -private-key`. See `.crush/skills/sops-secret-management/SKILL.md` for the full workflow including common mistakes.

Key gotchas:
- `SOPS_AGE_SSH_PRIVATE_KEY_FILE` does NOT work with `sops` CLI — use `SOPS_AGE_KEY` (in-memory) with the output of `ssh-to-age -private-key`
- One-liner: `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops --set '["key"] "value"' file.yaml`
- **Never** write the age key to disk — keep it in a shell variable
- Secrets with service-specific owners MUST be guarded with `lib.optionalAttrs config.services.X.enable` — one bad owner blocks ALL secrets atomically
- oauth2-proxy `cookie_secret` must be 16, 24, or 32 bytes

### lib/ Helpers

Import: `import ../../../lib/default.nix lib` — exports: `harden`, `hardenUser`, `serviceDefaults`, `serviceDefaultsUser`, `onFailure`, `serviceTypes`, `mkDockerServiceFactory`, `mkStateDir`, `mkSecretCheck`, `mkDesktopNotifyService`, `mkHttpCheck`, `ports`, `images`.

| Helper | What it does |
|--------|-------------|
| `harden { MemoryMax = "1G"; }` | systemd security hardening. `mode = "user"` or `hardenUser` for user services |
| `serviceDefaults {}` | System service defaults (uses `mkForce`). `serviceDefaultsUser {}` for user services |
| `mkStateDir "/var/lib/foo" "0755" "foo" "foo"` | tmpfiles rule |
| `onFailure` | `["notify-failure@%n.service"]` |
| `mkDockerServiceFactory { inherit pkgs; }` | systemd service for Docker Compose |
| `serviceTypes.dockerImageTag "1.2.3"` | Option that rejects `"latest"` at eval time |
| `mkSecretCheck` | Shell script that checks a secret file exists & is non-empty |
| `mkDesktopNotifyService` | Timer + oneshot service pair for desktop notifications |
| `mkHttpCheck { name; group; url; }` | Gatus endpoint definition |
| `ports` | Centralized port registry (`ports.homepage`, `ports.signoz`, etc.) |
| `images` | Pinned container image references (name + tag + optional digest) |

### Caddy vHost Pattern

ALL vhosts are defined in `modules/nixos/services/caddy.nix`. No other module should define `services.caddy.virtualHosts`. Use `protectedVHost "subdomain" port` for forward-auth via oauth2-proxy + Pocket ID. Use `lib.optionalAttrs service.enable` for conditional vhosts.

### Homepage Tile Pattern

ALL Homepage tiles are defined in `modules/nixos/services/homepage.nix`. Tiles for services that may be disabled MUST use `lib.optionalString` guards via the `when` helper. Pattern:

```nix
when = cond: text: lib.optionalString cond text;
'' + (when config.services.example.enable ''
    - Example:
        href: ${svcUrl "example"}
        description: Example Service
        icon: example.png
        statusStyle: dot
        siteMonitor: ${svcUrl "example"}
'') + ''
```

Unconditional tiles (Pocket ID, Caddy, PostgreSQL, Redis, etc.) are always shown. Categories: Infrastructure, Media, Development, AI, Monitoring, Productivity.

### WatchdogSec Rules

**Only set `WatchdogSec` on services that send `WATCHDOG=1` via `sd_notify()`.** Type=notify alone is NOT sufficient (e.g., Forgejo, Caddy). Never use on Python, Node.js, or Go/Rust without explicit sd_notify.

### Hermes `extraDependencyGroups`

Upstream excludes most adapters from `[all]` extra (lazy pip install). In Nix, declare all needed extras in the overlay. Currently: `messaging`, `anthropic`, `firecrawl`, `edge-tts`, `fal`, `exa`. **Do NOT add blindly** — `voice` has complex native deps; `matrix` requires python-olm (Linux-only).

### BTRFS Snapshots (evo-x2)

- Root (`@` subvolume): daily via `btrbk`, auto-pruning (14d + 4w)
- `/data`: NOT snapshotted — BTRFS toplevel (subvolid=5). Run `just snapshot-migrate-data` to convert
- Pre-deploy: `nix run .#deploy` auto-calls BTRFS snapshot
- Toplevel mount: `/mnt/btrfs-root` — automounts on access, idle 10min
- Verify: daily timer `btrfs-verify-snapshots` alerts if snapshots >3 days stale

---

## Critical Rules

### Must Follow

- **Use `nix`/flake commands** — never raw `nixos-rebuild`/`darwin-rebuild`. Use `nix run .#deploy` to apply
- **Test before applying** — `nix flake check --no-build` (syntax) or `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (eval)
- **Use `trash` not `rm`** for file deletion
- **Use `git mv` not `mv`** in this repo
- **2-space indentation** for Nix files
- **Open new terminal** after `nix run .#deploy` (shell changes need new session)
- **`config.allowBroken = false`** — must stay false in flake.nix
- **No OpenZFS on macOS** — causes kernel panics (ADR-003)

### Non-Obvious Gotchas

| Issue | Why It Matters |
|-------|---------------|
| Terminal hierarchy | Ghostty = primary (Mod+Return), Kitty = backup (Mod+Shift+Return), Foot = sway fallback only |
| Ghostty app-id | Niri window rules use `^com.mitchellh.ghostty$` (not just `^ghostty$`) |
| Darwin HM user | `users.users.larsartmann.home` required in `platforms/darwin/default.nix` |
| Relative paths | Darwin: `../common/`, NixOS: `../../common/` |
| `lib.mkMerge` + flake-parts | Does not work — use inline config or imports |
| d2 Darwin overlay | Re-instantiates d2 with stubs; removing it breaks Darwin eval |
| Niri `BindsTo` → `Wants=` | `BindsTo` kills niri on deploy |
| awww-wallpaper ordering | `After=awww-daemon` creates cycle; use `graphical-session.target` |
| Unbound `do-ip6 = false` | evo-x2 has no global IPv6; any new unbound instance needs this |
| otel-tui Darwin | Never add — 40+ min builds + disk exhaustion |
| Darwin disk | 229 GB, 90-95% full. `nix-collect-garbage` hangs; clear caches before builds |
| `_module.args.<pkg> = null` | Linux-only packages: platform config sets null, module args use `pkg ? null` |
| `mkLarsPackages` platform safety | Returns `null` for unavailable packages on a given system, `filterAttrs` removes them — Darwin eval won't break if a Go tool lacks `aarch64-darwin` |
| `mkPreparedSource` auto-features | Auto-strips local `=> /home/...` replaces, auto-normalizes pseudo-versions, auto-generates `replace` directives |
| `serviceModules` auto-discovery | flake.nix auto-discovers all `.nix` files in `modules/nixos/services/`. Helper files must use `_` prefix |
| rpi3-dns overlays | Only `[NUR] ++ linuxOnlyOverlays` — no shared overlays |
| SigNoz build time | Built from source (Go 1.25); takes significant time |
| `/data` BTRFS toplevel | Mounted without `subvol=` (subvolid=5) — cannot be snapshotted |
| Docker services target | All Docker/container services use `multi-user.target` (NOT `graphical.target`) |
| sops GPG key import | `gnupg.sshKeyPaths = []` prevents RSA key GPG import causing 2min+ initrd hang |
| GPU udev rule | `KERNEL=="card[0-9]"` (not `card*`) — `card*` matches DP/HDMI child devices |
| OOM crash chain | Helium/Electron renderers grow unbounded in `user-1000.slice` → reclaim thrash → journald starved → sp5100-tco hardware WDT fires hard reset (60s). Journal cuts off abruptly mid-line with NO shutdown sequence. Fixed by `MemoryHigh=56G; MemoryMax=64G` on user slice + tightened oomd thresholds (50%/20s) + PSI early-warning Gatus alert |
| Jan llama-server respawn | Spawns new `llama-server` every 1-3 min (~1.2GB each). Not a systemd service — no cgroup limits |
| Pocket ID bootstrap | Declarative: `pocket-id-config.provision.enable = true` creates admin user + OIDC clients + avatar automatically. Only manual step: register passkey at `/setup`. Client secrets auto-generated and stored in `/var/lib/pocket-id/client-secrets/`. See `just auth-bootstrap` |
| Caddy `handle_path` | STRIPS prefix before proxying. Use `handle` when backend expects full path |
| Swap exhaustion | Stale LSP processes (gopls/vtsls/rust-analyzer) eating gigabytes of swap. Mitigated by `stale-lsp-cleanup` timer running every 5min, killing processes older than 5min |
| Port 8050 resolved | Photomap reassigned to 8051. Port 8050 no longer conflicted with dns-blocker-block |
| Orphan modules | `default-services.nix` is NOT orphaned — `default = true` auto-enables Docker. `dns-failover.nix` only used by rpi3. `ai-stack.nix` restored in session 120 |
| Dozzle module eval issue | Creating `modules/nixos/services/dozzle.nix` with options causes `nix flake check` failure while `nix eval` works. Use inline `virtualisation.oci-containers` in configuration.nix instead |
| `onFailure` centralization | Always use `onFailure` from `lib/default.nix` — never hardcode `["notify-failure@%n.service"]`. Exported by `service-defaults.nix`, passed through `docker.nix` factory |
| `dns-blocker-stats` port | Port 9090 (dnsblockd stats API), NOT 8083. 8083 is the Gatus web port. Both are in `lib/ports.nix` |
| `theme.font.mono` | Font name `"JetBrainsMono Nerd Font"` defined once in `platforms/common/theme.nix` — reference via `theme.font.mono`, never hardcode |
| `harden` vs `hardenUser` | User services (systemd --user) must use `hardenUser`, not `harden`. All desktop notify services should pass `hardenFn = hardenUser` |
| `lib/default.nix` import | Always import from `lib/default.nix`, never directly from `lib/systemd.nix`, `lib/systemd/service-defaults.nix`, or `lib/rocm.nix` |
| Port centralization | All ports must be in `lib/ports.nix`. If a service exposes a port option, its default should reference `ports.*` — never hardcode |
| `art-dupl` vendorHash | Local override in `mkLarsPackages` (flake.nix) — upstream `fork` branch has stale `vendorHash`. When it breaks: set `vendorHash = ""`, build, paste `got:` hash |
| `rocm` via lib | ROCm helper accessed via `libHelpers.rocm {inherit pkgs;}` — not direct file import |
| `colorSchemeName` removed | Dead code — use `colorScheme.slug` instead |
| Boot GPU params | `amdgpuGttSize` / `ttmPagesLimit` in boot.nix are shared between `kernelParams` and `extraModprobeConfig` |
| `auto-optimise-store` | In `common/nix-settings.nix`, NOT `networking.nix` |
| `mkPreparedSource` v2 sub-modules | `subModules` handles `/v2` suffixes — include version in list entry (e.g. `"codec/v2"`), it's kept in module path but stripped from local dir |
| `proxyVendor = true` | Required for `mkPreparedSource` repos — enables `go mod tidy` in both derivation phases without vendor/ validation issues |
| sops secret owners | Secrets referencing non-existent users/groups cause sops-install-secrets to fail atomically — ALL secrets blocked. Guard with `lib.optionalAttrs config.services.X.enable` |
| `signoz.target` | SigNoz/ClickHouse use custom `signoz.target` (NOT `multi-user.target`) to avoid blocking `graphical.target`. The target is defined in `signoz.nix` and itself uses `wantedBy = ["multi-user.target"]`. All new SigNoz components must use `wantedBy = ["signoz.target"]` |
| `svcEnabled` helper | In `sops.nix`, use `svcEnabled "service-name"` instead of `config.services.X.enable` for cross-module safety (rpi3 doesn't import all modules). Defined as `name: (config.services.${name} or {}).enable or false` |
| `locale.nix` | Shared timezone + locale in `platforms/common/locale.nix`. Never hardcode `time.timeZone` or `i18n.defaultLocale` in platform configs — import this instead |
| `dns-failover.yaml` | Sops secret for VRRP auth password. Encrypted for evo-x2 only — rpi3 needs its age key added to `.sops.yaml` before deployment |
| Pocket-ID SMTP | Now fully configurable via `cfg.smtp.host`, `cfg.smtp.port`, `cfg.smtp.user`, `cfg.smtp.from`, `cfg.smtp.skipSslVerify`. Never hardcode SMTP values |
| Image registry | ALL container image references must go through `lib/images.nix` — never hardcode `image@sha256:...` in service modules. Add new images to the `images` attrset with `mkRef` |
| `notify-failure@%n` wrapper | `%i` in `writeShellApplication` is NOT expanded — must pass `%i` as script argument from `ExecStart`. Template: `"${scriptBin}/bin/script %i"` |
| `startLimitBurst` | Every service using `serviceDefaults {}` MUST set `startLimitBurst = 5; startLimitIntervalSec = 300;` to prevent infinite crash loops |
| `amdgpu.gttsize` deprecated | Kernel 7.0+ uses `ttm.pages_limit` only. Remove from both `kernelParams` and `extraModprobeConfig` |
| SigNoz JWT secret | Auto-generated at `${cfg.settings.queryService.dataDir}/jwt-secret` via wrapper script. Never store in sops — just needs to be persistent and random |
| GPU crash forensics | WDT hard reset empties pstore. Journal corruption is expected. The `initrd-nixos-activation` 2m50s hang was caused by sops owner validation failure, not initrd itself |
| SDK discovery daemon | PMA auto-commit service starts a project-discovery daemon at `/run/project-discovery/daemon.sock`. Overview probes for it via `sdk.WithDaemonProbe(daemon.ProbeDaemon)` — falls back to embedded pipeline if daemon not running. Socket mode `0o666` for cross-service access. PMA NixOS module sets `PROJECT_DISCOVERY_DAEMON_ADDR=unix:///run/project-discovery/daemon.sock` and needs `AF_UNIX` in `RestrictAddressFamilies` |
| `enrichment/meta` | Sub-module in project-discovery-sdk — must be in `subModules` list in flake.nix when daemon/preset is imported. Was untracked in git causing Nix build failures |
| `crush-daily` module `pkgs` | `pkgs` must be in the inner NixOS module scope (`{ config, lib, pkgs, ... }: `), NOT the outer flake-parts scope (`{ pkgs, ... }: `). The outer scope doesn't receive `pkgs` from NixOS |
| `cmdguard` MustNewCommand | Restored in cmdguard v2.6+ as thin wrapper around `NewCommand` (which returns `(Command, error)`). Consumers using `MustNewCommand` compile fine |
| swayidle SSH gap | swayidle only tracks Wayland input events — SSH sessions are invisible to idle tracking. `ssh-suspend-guard.service` holds a `sleep` block inhibitor via `systemd-inhibit` while any SSH session (`sshd: user@...`) is active, preventing `systemctl suspend` from succeeding |
| `user-1000.slice` MemoryMax | User-session processes (Helium/Electron, desktop AI tools) run OUTSIDE per-service MemoryMax limits. MUST set `MemoryHigh` + `MemoryMax` on `user-${uid}.slice` in `boot.nix`. Without this, runaway user processes exhaust all RAM → journald starved → WDT hard reset. Per-service MemoryMax only covers systemd services |
| oomd `settings.OOM` tuning | NixOS defaults (60% pressure sustained 30s) are too lenient — by 60% PSI pressure the system is in deep thrash. Tuned to 50%/20s. Per-slice `ManagedOOMMemoryPressureLimit` defaults to 80% via `mkDefault` — override with plain values in `systemd.slices` |
| `psi-metrics` collector | Textfile oneshot in `signoz.nix` that exports `/proc/pressure/memory` avg10 values + derived `node_psi_memory_alert` boolean. Gatus alerts via Discord when alert=1 (some>50% or full>10%). node-exporter's built-in `pressure` collector also exports cumulative PSI to SigNoz for dashboards |
| WDT forensics | Journal ending abruptly mid-line with NO shutdown/poweroff sequence = hardware watchdog reset, NOT clean shutdown or kernel panic (panic would log + auto-reboot via `kernel.panic=30`). sp5100-tco fires after 60s of unresponsiveness. Empty pstore confirms WDT (panic/oops would populate pstore) |
| Build commands (no justfile) | justfile was REMOVED — use `nix flake check --no-build` (validate), `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (quick eval), `nix run .#deploy` (deploy), `nix fmt` (format) |

---

## Build & Test

```bash
nix flake check --no-build  # Syntax-only validation (fast)
nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel  # Quick eval
nix run .#deploy            # Deploy to evo-x2 via nh
nix fmt                     # treefmt + alejandra
nix flake update            # Update flake inputs
```

Run `just` for the complete recipe list.

---

## Cross-Platform Home Manager

Both platforms import `platforms/common/home-base.nix`:
- Darwin user: `larsartmann`
- NixOS user: `lars`
- Platform differences: `pkgs.stdenv.isLinux` / `pkgs.stdenv.isDarwin`

---

## GPU Compute Headroom (NixOS)

AI workloads can starve niri of GPU cycles. Memory fractions are **per-service**, not system-wide. `OLLAMA_GPU_OVERHEAD=8589934592` (8 GiB) reserves headroom for compositor.

---

## Darwin (macOS) Constraints

Darwin IS actively used but heavily resource-constrained:

| Constraint | Impact |
|-----------|--------|
| 256GB SSD, ~90%+ full | Must `nix-collect-garbage` before large builds, never add heavy packages |
| 24GB RAM | Avoid memory-intensive builds (otel-tui takes 40+ min) |
| No desktop config | Home Manager has 7 lines — no terminal, editor, theme parity with NixOS |

**When adding packages for Darwin:** always check disk impact first. Prefer lightweight alternatives. Never add anything that builds from source for >10min.
