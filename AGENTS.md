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
│   ├── ports.nix                # Centralized port registry (collision-protected)
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
2. **Convention:** filename (minus `.nix`) IS the module name. The flake auto-discovers all `.nix` files in the directory — no manual list to update, no file parsing.
3. Non-module helpers must be prefixed with `_` (e.g., `_signoz-alerts.nix`) — automatically skipped
4. Enable in `platforms/nixos/system/configuration.nix`
5. If behind Caddy, define a `port` option and reference it in `caddy.nix` — never hardcode ports

### Custom Overlays

All private LarsArtmann repos use `git+ssh://` URLs. No `path:` inputs.

**`mkPackageOverlay`** (from `overlays/default.nix`) — use for ALL flake-input overlays:
```nix
mkPackageOverlay = input: name: overrides: _final: prev: let
  systemPkgs = input.packages.${prev.stdenv.system} or {};
  pkg = systemPkgs.default or null;
in
  if pkg == null then {} else {
    ${name} = if overrides == {} then pkg else pkg.overrideAttrs overrides;
  };
```

Platform-safe: returns empty overlay `{}` when the input doesn't provide a package for the current system (e.g., Linux-only packages evaluated on Darwin). No need to split overlays by platform manually.

Overlay makes packages available as `pkgs.<name>` but does **not** install them. Also add to `home.packages` in `platforms/common/packages/base.nix` for PATH access.

### `_local_deps` Pattern (Private Go Repos)

`mkPreparedSource` is centralized in the **`go-nix-helpers`** repo (`git+ssh://git@github.com/LarsArtmann/go-nix-helpers`). All Go repos use it as a `flake = false` input:

```nix
inputs = {
  go-nix-helpers = {
    url = "git+ssh://git@github.com/LarsArtmann/go-nix-helpers?ref=master";
    flake = false;
  };
};

# In outputs:
mkPreparedSource = import (go-nix-helpers + "/mkPreparedSource.nix") {
  inherit pkgs lib;
  goPkg = pkgs.go_1_26;
};
```

**Auto-features (no manual sed needed):**
- `subModules` auto-generates `replace` directives for each sub-module
- `subModuleVersionNormalize` auto-normalizes pseudo-versions (`v0.0.0-20240101...`) to `v0.0.0` for all sub-modules
- `stripLocalReplaces` (default `true`) auto-strips stale `replace X => /home/...` directives
- Use `requireDeps` for sub-modules not yet in go.mod (e.g., newly added sub-module imports)

**Only use `postPatchExtra` for repo-specific patches** (e.g., removing incompatible versions, patching sub-module go.mod files). The common patterns (local replace stripping, version normalization) are handled automatically.

When upstream deps change, set `vendorHash = ""`, build, and paste the `got:` hash.

### Hermes `extraDependencyGroups` Pattern

Upstream `hermes-agent` deliberately excludes most platform adapters from the `[all]` extra (they lazy-install via pip at runtime). In Nix, pip is unavailable, so **all needed extras must be declared** in the overlay:

```nix
hermes-agent = base.hermes-agent.override {
  callPackage = interceptCallPackage;
  extraDependencyGroups = ["messaging" "anthropic" "firecrawl" "edge-tts" "fal" "exa"];
};
```

**Currently included:** `messaging` (discord.py, telegram, slack), `anthropic`, `firecrawl` (web_search), `edge-tts` (TTS), `fal` (image gen), `exa` (web search)
**Do NOT add blindly:** `voice` (faster-whisper) has complex native deps; `matrix` requires python-olm (Linux-only)

### Go Repo Update Checklist

Core private Go deps (`go-output`, `go-branded-id`, etc.) cascade to all consumers on change:

1. Update the dep repo first (publish tags for sub-modules like `testhelpers/v0.0.0`)
2. In each consumer repo: set `vendorHash = ""`, build, paste `got:` hash
3. Verify transitive deps — if `go-output` imports `go-branded-id`, every consumer must have it in `go.mod`/`go.sum`
4. Update SystemNix `flake.lock` last: `nix flake lock --update-input <repo>`

### Nix Versioning Convention

**For published/public packages:** hardcode semver. **For internal-only overlays:** `self.rev` is fine — it auto-updates and is honest about what commit is deployed.

```nix
# ✅ Published packages — hardcode semver
version = "0.1.0";

# ✅ Internal overlays — self.rev is fine (auto-updates with every push)
version = self.rev or self.dirtyRev or "dev";

# ❌ Always wrong — stale hardcoded version that never gets bumped
version = "0.1.0";  # (when no formal release process exists)
```

**Release workflow (for published packages):**
1. Bump `version = "X.Y.Z"` in `flake.nix` (or `nix/packages/default.nix`)
2. Commit with message like `release: v0.2.0`
3. Tag: `git tag -a v0.2.0 -m "v0.2.0"`
4. Push: `git push && git push origin v0.2.0`
5. Update SystemNix: `nix flake lock --update-input <repo>`

### overrideModAttrs + `go mod tidy` Anti-Pattern

**AVOID `overrideModAttrs` with `go mod tidy` in `buildGoModule`.** It causes inconsistent vendoring:

```nix
# ❌ Anti-pattern — causes "inconsistent vendoring" error on dep changes
vendorHash = "sha256-...";
overrideModAttrs = _: { preBuild = "go mod tidy"; };

# ✅ Correct — keep go.mod tidy locally, use exact vendorHash
vendorHash = "sha256-...";
# (no overrideModAttrs)
```

**Why it breaks:** `buildGoModule` has two phases: (1) go-modules derivation (with network) produces vendor/, (2) main build (no network) uses vendor/ with original go.mod. `overrideModAttrs` runs `go mod tidy` in phase 1 only, producing vendor/modules.txt that doesn't match the un-tidied go.mod in phase 2 → "inconsistent vendoring" error.

**Exception:** repos with complex `_local_deps` setups (like PMA with 12 private deps + sub-modules) may need `overrideModAttrs` because `mkPreparedSource` creates a go.mod state that genuinely needs tidy. In that case, ensure the committed go.mod is pre-tidied to match what the Nix build resolves.

**When vendorHash breaks after a dep change:** set `vendorHash = ""`, build, paste the `got:` hash.

### Config-Derived URLs

Never hardcode `localhost:PORT`. Derive from service config:
```nix
forgejoPort = config.services.forgejo.settings.server.HTTP_PORT;
forgejoUrl = "http://localhost:${toString forgejoPort}";
```

### Sops + Age Toolchain

sops-encrypted secrets use the SSH host key for encryption. The `sops` CLI requires **age identity format**, not raw SSH keys. Use `ssh-to-age` to convert:

```bash
# Convert SSH host key → age identity (needed by sops CLI)
ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > /tmp/age.key

# Set a sops secret (e.g., update cookie_secret)
sudo env SOPS_AGE_KEY_FILE=/tmp/age.key \
  sops --set '["oauth2_proxy_cookie_secret"] "'"$(python3 -c 'import os,base64; print(base64.b64encode(os.urandom(32)).decode())')"'"' \
  platforms/nixos/secrets/pocket-id.yaml

# Cleanup
rm /tmp/age.key
```

**Key gotchas:**
- `SOPS_AGE_SSH_PRIVATE_KEY_FILE` does NOT work with `sops` CLI — it needs `SOPS_AGE_KEY_FILE` with age identity format
- `sudo` strips env vars — use `sudo env VAR=VALUE command` pattern
- oauth2-proxy `cookie_secret` must be exactly 16, 24, or 32 bytes (AES-128/192/256)
- Always clean up the age key file after use

### lib/ Helpers

Single import pattern:
```nix
inherit (import ../../../lib/default.nix lib)
  harden serviceDefaults onFailure serviceTypes mkStateDir mkDockerServiceFactory ports;
```

- `harden { MemoryMax = "1G"; }` — systemd security hardening. Use `mode = "user"` for user services (or `hardenUser` wrapper).
- `serviceDefaults {}` — system services (uses `mkForce`). `serviceDefaultsUser {}` — user services (no `mkForce`).
- `mkStateDir "/var/lib/foo" "0755" "foo" "foo"` — tmpfiles rule.
- `onFailure` — constant `["notify-failure@%n.service"]`.
- `mkDockerServiceFactory { inherit pkgs; }` — generates systemd service for Docker Compose.
- `serviceTypes.dockerImageTag "1.2.3"` — Docker image tag option that rejects `"latest"` at eval time.
- `ports` — centralized port registry (`ports.homepage`, `ports.signoz`, etc.).
- `mkHttpCheck { name = "..."; group = "..."; url = "..."; }` — Gatus endpoint definition.

### Caddy vHost Pattern

ALL vhosts are defined in `modules/nixos/services/caddy.nix`. No other module should define `services.caddy.virtualHosts`.

Use `protectedVHost "subdomain" port` for services that need forward-auth via oauth2-proxy + Pocket ID (most services). Use inline config only for public endpoints.

### WatchdogSec Rules

**Only set `WatchdogSec` on services that send periodic `WATCHDOG=1` via `sd_notify()`.**

- **Type=notify but NO watchdog keepalives** (do NOT use): Forgejo, Caddy
- **Never use on**: Python (Hermes, ComfyUI), Node.js (Homepage), Go without sd_notify (SigNoz), Rust without sd_notify (TaskChampion)

### BTRFS Snapshots (evo-x2)

Managed via `platforms/nixos/system/snapshots.nix`:

- **Root (`@` subvolume):** `services.btrbk` — daily snapshots, auto-pruning (14d + 4w)
- **`/data`:** NOT snapshotted — mounted as BTRFS toplevel (subvolid=5, no `subvol=`). `btrfs subvolume snapshot` cannot snapshot the toplevel.
- **Pre-deploy:** `just switch` auto-calls `just snapshot` (root only)
- **Toplevel mount:** `/mnt/btrfs-root` — automounts on access, idle 10min. Needed by btrbk.
- **Verify:** Daily timer `btrfs-verify-snapshots` alerts if root snapshots >3 days stale.

**To enable /data snapshots:** Run `just snapshot-migrate-data` to convert /data from toplevel to `@data` subvolume. Then add btrbk instance for /data.

**Rollback procedure:**
```bash
sudo mount /dev/disk/by-uuid/0b629b65-... /mnt/btrfs-root
cd /mnt/btrfs-root
mv @ @.broken
btrfs subvolume snapshot .snapshots/@.<timestamp> @
reboot
```

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
| `mkPackageOverlay` platform safety | Returns empty overlay on unsupported systems — Linux-only packages in `shared.nix` won't break Darwin eval |
| `mkPreparedSource` auto-features | Auto-strips local `=> /home/...` replaces, auto-normalizes sub-module pseudo-versions, auto-generates `replace` directives. Use `requireDeps` for missing sub-module requires |
| `serviceModules` auto-discovery | `flake.nix` auto-discovers all `.nix` files in `modules/nixos/services/`. Filename = module name. Helper files must use `_` prefix to be skipped. No file reading or regex parsing |
| rpi3-dns overlays | Only `[NUR] ++ linuxOnlyOverlays` — no shared overlays |
| SigNoz build time | Built from source (Go 1.25); takes significant time |
| `/data` BTRFS toplevel | Mounted without `subvol=` (subvolid=5) — cannot be snapshotted. Run `just snapshot-migrate-data` to convert to `@data` |
| Docker services target | All Docker/container services use `multi-user.target` (NOT `graphical.target`) — desktop must not wait for containers |
| sops GPG key import | `gnupg.sshKeyPaths = []` set to prevent RSA key GPG import causing 2min+ initrd hang |
| GPU udev rule | `KERNEL=="card[0-9]"` (not `card*`) — `card*` matches DP/HDMI child devices causing errors |
| OOM crash chain | Helium (Electron) escaped cgroup limits → spawned 42 processes → OOM killed journald → cascade crash. Now mitigated by: `MemoryHigh` in `harden`, per-service `MemoryMax`, `systemd-oomd` PSI monitoring (replaces earlyoom) |
| Jan llama-server respawn | Jan AI spawns new `llama-server` every 1-3 min (each ~1.2GB). Not a systemd service — no cgroup limits. Monitor total impact on RAM |
| Pocket ID bootstrap | Staged deployment: deploy with Pocket ID only → visit `https://auth.home.lan/setup` → create admin passkey → create OIDC clients → update sops secrets → deploy with oauth2-proxy. See `just auth-bootstrap` |
| Caddy `handle_path` | `handle_path /prefix/*` STRIPS the prefix before proxying. Use `handle` (not `handle_path`) when the backend expects the full path (e.g., oauth2-proxy expects `/oauth2/callback`) |

---

## Build & Test

```bash
just test-fast          # Syntax-only validation (fast)
just test               # Full build validation (slow)
just format             # treefmt + alejandra
just switch             # Apply config (auto-snapshots BTRFS on NixOS, auto-detects platform)
just update             # Update flake inputs
```

Run `just` (or `just --list`) for the complete recipe list.

## Common Build Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| oauth2-proxy fails to start | Placeholder sops secrets in `pocket-id.yaml` | Run `just auth-bootstrap` — Pocket ID admin must be configured first |
| Pocket ID unreachable from oauth2-proxy | DNS for `auth.home.lan` not resolving | Ensure Unbound/Caddy handles `auth.home.lan` on localhost |
| `hash mismatch in fixed-output derivation` | Stale `vendorHash` / `npmDepsHash` | Set to `""`, build, paste `got:` hash |
| Go vendor fail after dep update | Missing transitive dep in `go.sum` | Ensure all transitive deps from `_local_deps` are in `go.mod`/`go.sum` |
| `errno=28` (Darwin) | Disk full | `rm -rf ~/Library/Caches/*`, `nix-collect-garbage --delete-older-than 1d` |
| `cannot coerce null to a string` | Missing `_module.args.<pkg>` | Add `_module.args.<pkg> = null` to platform config + `pkg ? null` to module |
| `infinite recursion` | `config` in `options` or import cycle | Check for `config.services.*` in option defaults or circular imports |
| `attribute 'X' missing` | Overlay not applied or package not installed | Verify overlay is in `sharedOverlays`/`linuxOnlyOverlays`, then add to `base.nix` |
| Pocket ID / oauth2-proxy startup fail | `pocket-id.yaml` sops file not created yet | Create with `sops platforms/nixos/secrets/pocket-id.yaml` — needs `pocket_id_encryption_key`, `oauth2_proxy_client_secret`, `oauth2_proxy_cookie_secret`, `immich_oauth_client_secret` |

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
