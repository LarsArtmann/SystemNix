# SystemNix: Agent Guide

**Project Type:** Cross-Platform Nix Configuration (macOS + NixOS)
**Repo:** `github:LarsArtmann/SystemNix`

---

## Architecture

```
SystemNix/
├── flake.nix                    # Entry point (flake-parts)
├── justfile                     # Task runner — ALWAYS use this
├── overlays/                    # Shared + Linux-only overlays
│   ├── default.nix              # mkPackageOverlay helper
│   ├── shared.nix               # Darwin + NixOS overlays
│   └── linux.nix                # NixOS-only overlays
├── lib/                         # Shared NixOS module helpers
│   ├── systemd.nix              # harden / hardenUser
│   ├── systemd/service-defaults.nix  # serviceDefaults / serviceDefaultsUser
│   ├── types.nix                # Reusable option constructors
│   ├── docker.nix               # mkDockerServiceFactory
│   └── rocm.nix                 # ROCm GPU runtime helpers
├── modules/nixos/services/      # flake-parts service modules
├── pkgs/                        # Custom packages (buildGoModule, etc.)
├── platforms/
│   ├── common/                  # Shared (~80%)
│   ├── darwin/                  # macOS (nix-darwin)
│   └── nixos/                   # NixOS
└── scripts/                     # Operational scripts
```

Two machines:
| System | Hostname | Platform |
|--------|----------|----------|
| macOS | `Lars-MacBook-Air` | aarch64-darwin |
| NixOS | `evo-x2` | x86_64-linux |

---

## Key Patterns

### Adding a Service

1. Create `modules/nixos/services/<name>.nix` as a flake-parts module
2. Add to `serviceModules` list in `flake.nix` (single source of truth)
3. Enable in `platforms/nixos/system/configuration.nix`
4. If behind Caddy, define a `port` option and reference it in `caddy.nix` — never hardcode ports

### Custom Overlays

All private LarsArtmann repos use `git+ssh://` URLs. No `path:` inputs.

**`mkPackageOverlay`** (from `overlays/default.nix`) — use for ALL flake-input overlays:
```nix
mkPackageOverlay = input: name: overrides:
  _final: prev: let pkg = input.packages.${prev.stdenv.system}.default; in {
    ${name} = if overrides == {} then pkg else pkg.overrideAttrs overrides;
  };
```

Overlay makes packages available as `pkgs.<name>` but does **not** install them. Also add to `home.packages` in `platforms/common/packages/base.nix` for PATH access.

### `_local_deps` Pattern (Private Go Repos)

When a Go repo has private dependencies, use `preparedSrc` to copy deps into `_local_deps/` and inject `replace` directives. The vendor derivation needs `overrideModAttrs` with `go mod tidy`:
```nix
buildGoModule {
  vendorHash = "...";
  overrideModAttrs = old: { preBuild = ''go mod tidy''; };
}
```

When upstream deps change, set `vendorHash = ""`, build, and paste the `got:` hash.

### Config-Derived URLs

Never hardcode `localhost:PORT`. Derive from service config:
```nix
forgejoPort = config.services.forgejo.settings.server.HTTP_PORT;
forgejoUrl = "http://localhost:${toString forgejoPort}";
```

### lib/ Helpers

Single import pattern:
```nix
inherit (import ../../../lib/default.nix lib)
  harden serviceDefaults onFailure serviceTypes mkStateDir mkDockerServiceFactory;
```

- `harden { MemoryMax = "1G"; }` — systemd security hardening. Use `mode = "user"` for user services (or `hardenUser` wrapper).
- `serviceDefaults {}` — system services (uses `mkForce`). `serviceDefaultsUser {}` — user services (no `mkForce`).
- `mkStateDir "/var/lib/foo" "0755" "foo" "foo"` — tmpfiles rule.
- `onFailure` — constant `["notify-failure@%n.service"]`.
- `mkDockerServiceFactory { inherit pkgs; }` — generates systemd service for Docker Compose.

### WatchdogSec Rules

**Only set `WatchdogSec` on services that send periodic `WATCHDOG=1` via `sd_notify()`.**

- **Type=notify but NO watchdog keepalives** (do NOT use): Forgejo, Caddy
- **Never use on**: Python (Hermes, ComfyUI), Node.js (Homepage), Go without sd_notify (SigNoz, Authelia), Rust without sd_notify (TaskChampion)

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
| Darwin HM user | Must define `users.users.larsartmann.home` in `platforms/darwin/default.nix` |
| Relative paths differ | Darwin: `../common/`, NixOS: `../../common/` |
| `lib.mkMerge` + flake-parts | Does not work — use inline config or imports |
| d2 Darwin overlay | Re-instantiates d2 with stub packages; removing it breaks Darwin eval |
| Niri `BindsTo` patched | Replaced with `Wants=` in `niri-config.nix`; `BindsTo` kills niri on `just switch` |
| awww-wallpaper ordering | Must NOT `After=awww-daemon` — creates cycle. `After=graphical-session.target` is sufficient |
| Unbound `do-ip6` | evo-x2 has no global IPv6. Any new unbound instance MUST set `do-ip6 = false` |
| otel-tui Linux-only | Excluded from Darwin; never re-add — 40+ min builds + disk exhaustion |
| Darwin disk exhaustion | 229 GB, regularly 90-95% full. `nix-collect-garbage` hangs. Clear caches before major builds |
| `_module.args` pattern | Linux-only packages need `_module.args.<pkg> = null` in platform config + `pkg ? null` in module args |
| `serviceModules` single source | Listed once in `flake.nix`; both imports and nixosConfigurations derive from it |
| rpi3-dns minimal overlays | Uses `[NUR] ++ linuxOnlyOverlays` only — no shared overlays |
| SigNoz built from source | Go 1.25 build; takes significant time |

---

## Build & Test

```bash
just test-fast          # Syntax-only validation (fast)
just test               # Full build validation (slow)
just format             # treefmt + alejandra
just switch             # Apply config (auto-detects platform)
just update             # Update flake inputs
```

Run `just` (or `just --list`) for the complete recipe list.

---

## Cross-Platform Home Manager

Both platforms import `platforms/common/home-base.nix`:
- Darwin user: `larsartmann`
- NixOS user: `lars`
- Platform differences: `pkgs.stdenv.isLinux` / `pkgs.stdenv.isDarwin`

---

## GPU Compute Headroom (NixOS)

AI workloads can starve niri of GPU cycles. Memory fractions are **per-service**, not system-wide:

| Service | Fraction | Key Setting |
|---------|----------|-------------|
| Ollama | 0.45 | `OLLAMA_MAX_LOADED_MODELS=1` prevents dual-runner OOM |
| ComfyUI | 0.50 | — |
| gpu-python | 0.95 (configurable) | Override with `GPU_MEM_FRACTION=0.8` |

`OLLAMA_GPU_OVERHEAD=8589934592` (8 GiB) reserves headroom for compositor.
