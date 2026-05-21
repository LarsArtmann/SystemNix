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

### Hermes `extraDependencyGroups` Pattern

Upstream `hermes-agent` deliberately excludes most platform adapters from the `[all]` extra (they lazy-install via pip at runtime). In Nix, pip is unavailable, so **all needed extras must be declared** in the overlay:

```nix
hermes-agent = base.hermes-agent.override {
  callPackage = interceptCallPackage;
  extraDependencyGroups = ["messaging" "anthropic"];
};
```

**Currently included:** `messaging` (discord.py, telegram, slack), `anthropic`
**Likely needed but not yet added:** `firecrawl` (web_search), `edge-tts` (TTS), `fal` (image gen), `exa` (web search)
**Do NOT add blindly:** `voice` (faster-whisper) has complex native deps; `matrix` requires python-olm (Linux-only)

### Go Repo Update Checklist

Core private Go deps (`go-output`, `go-branded-id`, etc.) cascade to all consumers on change:

1. Update the dep repo first (publish tags for sub-modules like `testhelpers/v0.0.0`)
2. In each consumer repo: set `vendorHash = ""`, build, paste `got:` hash
3. Verify transitive deps — if `go-output` imports `go-branded-id`, every consumer must have it in `go.mod`/`go.sum`
4. Update SystemNix `flake.lock` last: `nix flake lock --update-input <repo>`

### Nix Versioning Convention

**NEVER use `self.rev`/`self.shortRev` as package version.** Always hardcode semver:

```nix
# ✅ Correct
version = "0.1.0";

# ❌ Wrong — produces garbage like "dnsblockd-f832f9f"
version = self.shortRev or self.dirtyShortRev or "dev";
version = self.rev or self.dirtyRev or "dev";
version = "0.0.0-" + (self.shortRev or self.dirtyShortRev or "dev");
```

**Release workflow:**
1. Bump `version = "X.Y.Z"` in `flake.nix` (or `nix/packages/default.nix`)
2. Commit with message like `release: v0.2.0`
3. Tag: `git tag -a v0.2.0 -m "v0.2.0"`
4. Push: `git push && git push origin v0.2.0`
5. Update SystemNix: `nix flake lock --update-input <repo>`

**Rationale:** `self.rev` produces unreadable package names (`dnsblockd-f832f9f`), breaks `nix search`, and makes it impossible to tell which version is installed. The version is a property of the software, not the git commit.

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
| `serviceModules` single source | Listed once in `flake.nix`; both imports + nixosConfigs derive from it |
| rpi3-dns overlays | Only `[NUR] ++ linuxOnlyOverlays` — no shared overlays |
| SigNoz build time | Built from source (Go 1.25); takes significant time |

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

## Common Build Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `hash mismatch in fixed-output derivation` | Stale `vendorHash` / `npmDepsHash` | Set to `""`, build, paste `got:` hash |
| Go vendor fail after dep update | Missing transitive dep in `go.sum` | Ensure all transitive deps from `_local_deps` are in `go.mod`/`go.sum` |
| `errno=28` (Darwin) | Disk full | `rm -rf ~/Library/Caches/*`, `nix-collect-garbage --delete-older-than 1d` |
| `cannot coerce null to a string` | Missing `_module.args.<pkg>` | Add `_module.args.<pkg> = null` to platform config + `pkg ? null` to module |
| `infinite recursion` | `config` in `options` or import cycle | Check for `config.services.*` in option defaults or circular imports |
| `attribute 'X' missing` | Overlay not applied or package not installed | Verify overlay is in `sharedOverlays`/`linuxOnlyOverlays`, then add to `base.nix` |

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
