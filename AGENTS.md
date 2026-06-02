# SystemNix: Agent Guide

**Project Type:** Cross-Platform Nix Configuration (macOS + NixOS)
**Repo:** `github:LarsArtmann/SystemNix`
**Current Build:** ✅ All checks passed (`just test-fast`)

---

## Architecture

```
SystemNix/
├── flake.nix                    # Entry point (flake-parts)
├── justfile                     # Task runner
├── overlays/                    # Shared + Linux-only overlays
│   ├── default.nix              # mkPackageOverlay helper
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

### Custom Overlays

All private LarsArtmann repos use `git+ssh://` URLs. No `path:` inputs.

Use `mkPackageOverlay` (from `overlays/default.nix`) for ALL flake-input overlays. It's platform-safe — returns empty overlay `{}` on unsupported systems. See the file for signature.

Overlay makes packages available as `pkgs.<name>` but does **not** install them. Also add to `home.packages` in `platforms/common/packages/base.nix` for PATH access.

### `_local_deps` Pattern (Private Go Repos)

`mkPreparedSource` is centralized in `go-nix-helpers` (`git+ssh://git@github.com/LarsArtmann/go-nix-helpers`). Auto-features: `subModules` (replace directives), `subModuleVersionNormalize` (pseudo-version normalization), `stripLocalReplaces` (strips `=> /home/...`). Only use `postPatchExtra` for repo-specific patches. When upstream deps change, set `vendorHash = ""`, build, paste the `got:` hash.

### Go Repo Update Checklist

Core private Go deps (`go-output`, `go-branded-id`, etc.) cascade to all consumers on change:

1. Update the dep repo first (publish tags for sub-modules)
2. In each consumer: `vendorHash = ""`, build, paste `got:` hash
3. Verify transitive deps are in `go.mod`/`go.sum`
4. Update SystemNix `flake.lock` last: `nix flake lock --update-input <repo>`

### Nix Versioning Convention

**Published packages:** hardcode semver. **Internal overlays:** `self.rev or self.dirtyRev or "dev"` is fine.

### overrideModAttrs Anti-Pattern

**AVOID `overrideModAttrs` with `go mod tidy` in `buildGoModule`.** It causes "inconsistent vendoring" — phase 1 (go-modules derivation) gets tidied but phase 2 (main build) uses the original go.mod. Exception: complex `_local_deps` setups may need it; ensure committed go.mod is pre-tidied.

When `vendorHash` breaks after a dep change: set to `""`, build, paste `got:` hash.

### Config-Derived URLs

Never hardcode `localhost:PORT`. Derive from service config.

### Sops + Age Toolchain

sops secrets use SSH host keys. The `sops` CLI needs **age identity format** — convert with `ssh-to-age`. See `justfile` `auth-bootstrap` recipe for full procedure.

Key gotchas:
- `SOPS_AGE_SSH_PRIVATE_KEY_FILE` does NOT work with `sops` CLI — use `SOPS_AGE_KEY_FILE`
- `sudo` strips env vars — use `sudo env VAR=VALUE command`
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

ALL vhosts are defined in `modules/nixos/services/caddy.nix`. No other module should define `services.caddy.virtualHosts`. Use `protectedVHost "subdomain" port` for forward-auth via oauth2-proxy + Pocket ID.

### WatchdogSec Rules

**Only set `WatchdogSec` on services that send `WATCHDOG=1` via `sd_notify()`.** Type=notify alone is NOT sufficient (e.g., Forgejo, Caddy). Never use on Python, Node.js, or Go/Rust without explicit sd_notify.

### Hermes `extraDependencyGroups`

Upstream excludes most adapters from `[all]` extra (lazy pip install). In Nix, declare all needed extras in the overlay. Currently: `messaging`, `anthropic`, `firecrawl`, `edge-tts`, `fal`, `exa`. **Do NOT add blindly** — `voice` has complex native deps; `matrix` requires python-olm (Linux-only).

### BTRFS Snapshots (evo-x2)

- Root (`@` subvolume): daily via `btrbk`, auto-pruning (14d + 4w)
- `/data`: NOT snapshotted — BTRFS toplevel (subvolid=5). Run `just snapshot-migrate-data` to convert
- Pre-deploy: `just switch` auto-calls `just snapshot`
- Toplevel mount: `/mnt/btrfs-root` — automounts on access, idle 10min
- Verify: daily timer `btrfs-verify-snapshots` alerts if snapshots >3 days stale

---

## Critical Rules

### Must Follow

- **Use `just` commands** — never raw `nixos-rebuild`/`darwin-rebuild`
- **Test before applying** — `just test-fast` (syntax) or `just test` (full build)
- **Use `trash` not `rm`** for file deletion
- **Use `git mv` not `mv`** in this repo
- **2-space indentation** for Nix files
- **Open new terminal** after `just switch` (shell changes need new session)
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
| Niri `BindsTo` → `Wants=` | `BindsTo` kills niri on `just switch` |
| awww-wallpaper ordering | `After=awww-daemon` creates cycle; use `graphical-session.target` |
| Unbound `do-ip6 = false` | evo-x2 has no global IPv6; any new unbound instance needs this |
| otel-tui Darwin | Never add — 40+ min builds + disk exhaustion |
| Darwin disk | 229 GB, 90-95% full. `nix-collect-garbage` hangs; clear caches before builds |
| `_module.args.<pkg> = null` | Linux-only packages: platform config sets null, module args use `pkg ? null` |
| `mkPackageOverlay` platform safety | Returns empty overlay on unsupported systems — Linux-only packages in `shared.nix` won't break Darwin eval |
| `mkPreparedSource` auto-features | Auto-strips local `=> /home/...` replaces, auto-normalizes pseudo-versions, auto-generates `replace` directives |
| `serviceModules` auto-discovery | flake.nix auto-discovers all `.nix` files in `modules/nixos/services/`. Helper files must use `_` prefix |
| rpi3-dns overlays | Only `[NUR] ++ linuxOnlyOverlays` — no shared overlays |
| SigNoz build time | Built from source (Go 1.25); takes significant time |
| `/data` BTRFS toplevel | Mounted without `subvol=` (subvolid=5) — cannot be snapshotted |
| Docker services target | All Docker/container services use `multi-user.target` (NOT `graphical.target`) |
| sops GPG key import | `gnupg.sshKeyPaths = []` prevents RSA key GPG import causing 2min+ initrd hang |
| GPU udev rule | `KERNEL=="card[0-9]"` (not `card*`) — `card*` matches DP/HDMI child devices |
| OOM crash chain | Helium (Electron) escaped cgroup limits → OOM killed journald → cascade. Mitigated by `MemoryHigh`, per-service `MemoryMax`, `systemd-oomd` |
| Jan llama-server respawn | Spawns new `llama-server` every 1-3 min (~1.2GB each). Not a systemd service — no cgroup limits |
| Pocket ID bootstrap | Staged: deploy Pocket ID → `https://auth.home.lan/setup` → admin passkey → OIDC clients → sops secrets → deploy oauth2-proxy. See `just auth-bootstrap` |
| Caddy `handle_path` | STRIPS prefix before proxying. Use `handle` when backend expects full path |
| Swap exhaustion | 7 gopls instances eating ~7.4Gi RSS (13Gi/13Gi swap). SigNoz alerting at 80% swap usage. Root cause: stale LSP processes |
| Port 8050 latent conflict | `dns-blocker-block` and `photomap` both use 8050. Both disabled currently. Needs reassignment if both enabled |
| Orphan modules | `ai-stack.nix` and `default-services.nix` exist but no config imports them. `dns-failover.nix` only used by rpi3 |

---

## Build & Test

```bash
just test-fast          # Syntax-only validation (fast)
just test               # Full build validation (slow)
just format             # treefmt + alejandra
just switch             # Apply config (auto-snapshots BTRFS on NixOS, auto-detects platform)
just update             # Update flake inputs
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
