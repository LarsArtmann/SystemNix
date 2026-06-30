# SystemNix: Agent Guide

Cross-Platform Nix Configuration (macOS + NixOS) — `github:LarsArtmann/SystemNix`

---

## Architecture

```
flake.nix              # Thin entry point: inputs + flake-parts wiring (~680 lines)
systems/               # Host assembly: evo-x2.nix, darwin.nix, rpi3-dns.nix
lib/                   # Helpers — import via lib/default.nix (single import point)
  lars-packages.nix    # mkLarsPackages — single source of truth for LarsArtmann Go tools
  systemd/             # harden / serviceDefaults / serviceOneshotDefaults
modules/nixos/         # flake-parts NixOS modules, auto-discovered by filename
  services/            # Server/networking/app daemons (Caddy, Immich, SigNoz, DNS, …)
  desktop/             # Desktop-environment config (audio, display-manager, niri, steam, …)
pkgs/                  # Custom packages (buildGoModule, dms-plugins/)
overlays/              # shared.nix (callPackage + activitywatch + d2 Darwin stub), linux.nix (flake-input overlays)
platforms/common/      # Shared (~80%): home-base.nix, programs/, packages/, theme.nix, locale.nix
platforms/darwin/      # macOS (nix-darwin) — user: larsartmann
platforms/nixos/       # NixOS — user: lars
  desktop/quickshell.nix # Quickshell HM module (DankMaterialShell)
scripts/               # Shell + Python operational scripts
```

**Module auto-discovery:** `flake.nix` scans `modules/nixos/{services,desktop}/` — filenames MUST be unique across both dirs (filename → `flake.nixosModules.<name>`). `_`-prefixed files are helpers (skipped). docs/patches live in `docs/services/`, not the module tree.

| System | Hostname | Platform | Constraints |
|--------|----------|----------|-------------|
| macOS | `Lars-MacBook-Air` | aarch64-darwin | 24GB RAM, 256GB SSD (90%+ full) |
| NixOS | `evo-x2` | x86_64-linux | 128GB RAM, AMD Ryzen AI Max+ 395 |

---

## Key Procedures

### Adding a Service

1. Create `modules/nixos/services/<name>.nix` (or `modules/nixos/desktop/` for desktop config) — filename IS the module name, auto-discovered. Filenames must be unique across both dirs. Prefix `_` for non-module helpers
2. Enable in `platforms/nixos/system/configuration.nix`
3. Ports go in `lib/ports.nix` — never hardcode. Caddy vHosts go in `caddy.nix` via `protectedVHost "subdomain" port`
4. Import `import ../../../lib/default.nix lib` for `harden`, `serviceDefaults`, `onFailure`, `serviceTypes`, `ports`, etc.
5. Use `harden {} // serviceDefaults {}` for systemd. **Must** set `startLimitBurst = 5; startLimitIntervalSec = 300;`
6. All vHosts in `caddy.nix`, all Homepage tiles in `homepage.nix` (guard conditional tiles with `lib.optionalString`)
7. `WatchdogSec` ONLY on services that send `WATCHDOG=1` via `sd_notify()` — Type=notify alone is NOT sufficient
8. For native OIDC SSO: add the client to `pocket-id.nix` `oidcClients` default, add a provisioning oneshot that reads the secret from `/var/lib/pocket-id/client-secrets/<clientId>` and configures the service via its CLI/API. Use a direct TLS Caddy vHost (NOT `protectedVHost`) — forward-auth + native OIDC causes double-auth loops. See Forgejo (`forgejo-oidc-setup`) as the reference pattern

### Private Go Repos (LarsArtmann)

All private repos use `git+ssh://` URLs. Go tool packages defined in `mkLarsPackages` in `flake.nix` — NOT overlays.

`mkPreparedSource` (from `go-nix-helpers`) auto-strips local replaces, normalizes pseudo-versions, generates `replace` directives. Features: `subModules` (handles `/v2` suffixes — include version in list entry, kept in path, stripped from dir), `stripLocalReplaces`, `subModuleVersionNormalize`.

**vendorHash breaking?** Set `vendorHash = ""`, build, paste `got:` hash.
**Core dep cascade?** Update dep repo first → publish tags → each consumer: `vendorHash = ""` → `nix flake lock --update-input <repo>`
**`proxyVendor = true`:** `go mod tidy` safe in both phases. **`proxyVendor = false`:** AVOID `overrideModAttrs` with `go mod tidy` — causes "inconsistent vendoring"
**Versioning:** Published = hardcode semver. Internal = `self.shortRev or self.dirtyShortRev or "dev"` for the **package version** (keeps the store-path name short, e.g. `pkg-ff1f0db`). For full-commit traceability inside the *binary*, add a separate `commit = self.rev` and pass it via ldflags (`-X main.commit=${commit}`) — NEVER use the full `self.rev` as the package `version`, it pollutes every derivation name (40-char hash in nvd/store paths)

### Quickshell (DankMaterialShell)

Quickshell is a QtQuick desktop shell replacing Waybar, Dunst, Wlogout, polkit_gnome, **and rofi** (launcher, clipboard, keybinds, emoji, calc). Configured via DankMaterialShell's upstream HM module.

- **Input:** `dankMaterialShell` (github:AvengeMedia/DankMaterialShell/stable) — brings `quickshell` transitively, no separate quickshell input
- **HM module:** `platforms/nixos/desktop/quickshell.nix` — imports DMS upstream, sets `programs.systemnix-quickshell.enable = true`, enables `systemd.enable = true` (defaults to false!)
- **DMS plugins:** `pkgs/dms-plugins/` — 13 SystemNix-native widgets + 2 community launcher plugins (dms-emoji-launcher, DankCalculator) declaratively installed via DMS's `plugins` option with port-templated settings from `lib/ports.nix`. Community plugins use `fetchFromGitHub`. Each uses `PluginComponent` + `plugin.json`
- **DevShell:** `nix develop .#quickshell` for hot-reload QML development with `qmlls` LSP
- **Wallpaper management:** DMS owns wallpapers natively. awww is RETIRED. `dms-wallpaper-init` service seeds a random wallpaper from `~/.local/share/wallpapers/` (installed from `wallpapers-src` flake input) on first launch. DMS derives cycling directory from current wallpaper's parent dir. `Mod+W` = `dms ipc call wallpaper next`. Dynamic theming (`enableDynamicTheming = false`) is DISABLED — matugen overrides Catppuccin Mocha (our global theme). Re-enable if committing to Material You dynamic colors
- **Waybar RETIRED:** Completely removed (import, package, service, scripts). DMS is the sole shell
- **Rofi migrated to DMS (2026-06-30):** niri's 5 rofi keybindings rewired to DMS IPC (`spotlight toggle`, `clipboard toggle`, `keybinds toggle niri`, `spotlight toggleQuery ":e"`, `spotlight toggleQuery "="`). Rofi leaked 7 GB and OOM-killed niri. Rofi config (`rofi.nix`) remains for Sway backup WM only. DMS service has `MemoryMax=4G` as defense-in-depth. Emoji via dms-emoji-launcher plugin (trigger `:e`), calculator via DankCalculator plugin (trigger `=`)
- **Runtime verified:** DMS owns `org.freedesktop.Notifications`, `org.gnome.ScreenSaver`, `org.kde.StatusNotifierWatcher` DBus names
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

### SSO / OIDC Architecture

Two SSO layers, both backed by **Pocket ID** (passkey-only OIDC IdP at `auth.<domain>`):

| Layer | How | Services |
|-------|-----|----------|
| **Layer 1 — Native OIDC** | App integrates directly with Pocket ID (in-app login button). Provisioned as OIDC clients in `pocket-id.nix`; Caddy uses **plain `reverse_proxy`** (NOT `protectedVHost`) | Forgejo, Immich, **Gatus** |
| **Layer 2 — oauth2-proxy forward-auth** | App has no native auth; Caddy `protectedVHost` gates external access behind a Pocket ID login. LAN access is open | Homepage, SigNoz, Twenty, Taskchampion, Manifest, OpenSEO, Crush Daily, Dozzle, Monitor365 |

**Adding Layer 1 (native OIDC) to a service** — follow the immich/gatus pattern:
1. Register the OIDC client in `pocket-id.nix` `provision.oidcClients` (clientId, callbackURLs)
2. The provisioner writes the client secret to `/var/lib/pocket-id/client-secrets/<clientId>` (owned `pocket-id:pocket-id`, 640)
3. The service reads it: either via upstream `_secret` (immich), a runtime script `cat` (forgejo), or systemd `LoadCredential` (gatus — needed because gatus is a **DynamicUser** that can't own files)
4. Order the service `after`/`wants` `pocket-id-provision.service`
5. **In Caddy, use plain `reverse_proxy`** (like Forgejo/Gatus), NOT `protectedVHost` — a service with native OIDC behind `protectedVHost` causes a **double-auth** conflict

**Native OIDC is NOT free for most services** — verify upstream support before assuming:
- Homepage: no built-in auth at all (proxy-only by design)
- SigNoz: OIDC is Enterprise-only (not Community Edition)
- Twenty: SSO gated behind a billing entitlement
- Custom LarsArtmann Go services: require upstream OIDC code in their repos

**Single Logout (SLO) is partial, not coordinated.** Layer 2 apps share the oauth2-proxy session cookie (`.${domain}`) — logging out via oauth2-proxy's `/oauth2/sign_out` clears them together. Layer 1 apps (Forgejo, Immich, Gatus) each keep their **own** session cookie and do NOT participate in coordinated logout — visiting them after an IdP logout may still show the cached app session until it expires or the user explicitly logs out per-app. Pocket ID supports RP-initiated logout, but wiring it into every Layer 1 app's logout flow is per-app work and not currently done.

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
| DMS owns wallpaper management | awww is RETIRED. DMS manages wallpapers natively (`dms ipc call wallpaper set/next/prev`). `dms-wallpaper-init` service seeds a random wallpaper from `~/.local/share/wallpapers/` on first launch. DMS derives cycling directory from the current wallpaper's parent dir. `Mod+W` = `dms ipc call wallpaper next`. `enableDynamicTheming = false` — matugen conflicts with Catppuccin Mocha |
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
| DMS notification conflict | Only one DBus notification daemon can run. Dunst is disabled (`services.dunst.enable = lib.mkForce false`) — DMS owns `org.freedesktop.Notifications` |
| Quickshell pre-1.0 | Breaking changes expected before 1.0. Pin DMS to `stable` branch. Migration guides promised |
| QML is programming | Quickshell configs are applications, not config files. Requires QML knowledge. Use `nix develop .#quickshell` for LSP + hot-reload |
| `nixpkgs-unstable` vs `nixos-unstable` | **Use `nixos-unstable` in flake inputs.** Hydra only caches expensive builds (ROCm, CUDA) on the `nixos-unstable` jobset — `nixpkgs-unstable` produces different hashes with no binary cache for these. `ollama-rocm` was a 30+ min local build on `nixpkgs-unstable` but substitutes instantly from `nixos-unstable` |
| DMS `systemd.enable` defaults false | DMS HM module's `systemd.enable` defaults to `false`. MUST explicitly set `programs.dank-material-shell.systemd.enable = true` or DMS won't auto-start |
| DMS plugin system | DMS `plugins` option takes `attrsOf (submodule { enable, src, settings })`. `src` = path/package, `settings` = JSON written to `plugin_settings.json`. Plugins read settings via `pluginData.<key>` in QML |
| deploy.sh `SCRIPT_DIR` | Deploy script in nix store can't find `pre-deploy-check.sh` via `SCRIPT_DIR`. Fixed to use `nix run .#pre-deploy-check` instead |
| `switch-to-configuration` exit code 4 | Activation fails with `ExitStatus(Exited(4))` when a service whose unit definition changed is in `start-limit-hit` state — systemd refuses to restart it. **deploy.sh now runs `systemctl reset-failed` (system + user) before `nh os switch`** to clear the start-limit counter. Without this, any service that crash-looped at boot blocks ALL deploys until manually reset or rebooted. `nh` also swallows the per-unit error — run `sudo /run/current-system/bin/switch-to-configuration test` directly to see which unit failed |
| pre-deploy-check `((PASS++))` | Bash `((0++))` returns exit code 1, killing scripts under `set -e`. Fixed with `PASS=$((PASS + 1))` |
| DMS Quickshell `Process.onFailed` | Quickshell's `Process` has NO `onFailed` signal. Use `onStreamFinished` with text-length check or try/catch for error handling |
| Stale polkit-gnome after deploy | polkit-gnome process lingers from previous generation after removing it from packages. Self-resolves on reboot. DMS polkit agent warns "already exists" until then |
| DMS `plugin_settings.json` read-only | HM symlinks this to Nix store — user can't change plugin settings via DMS UI. Settings are declarative from `programs.dank-material-shell.plugins.<name>.settings` |
| cliphist service RETIRED | cliphist (wl-paste --watch) was retired when Alt+C migrated to DMS clipboard modal. DMS owns clipboard history exclusively. cliphist CLI remains in base.nix for manual use |
| Rofi OOM crash (2026-06-30) | Rofi leaked to 7 GB + 2.3 GB swap over 5h22m, triggering global OOM that killed niri, ghostty, signal, pipewire, unbound, clickhouse, immich. Root cause: long-lived `-dmenu`/`-drun` instances leaking. Fix: all 5 niri rofi bindings migrated to DMS spotlight/clipboard/keybinds IPC. DMS has MemoryMax=4G. Rofi remains for Sway backup WM only |
| DMS `settings.json` vs `plugin_settings.json` | **Split-brain:** `settings.json` is user-owned/mutable (bar layout, theme, lock config). `plugin_settings.json` is Nix-managed/read-only symlink (plugin URLs, ports). DMS UI changes to plugin settings silently disappear on rebuild. Document this tradeoff |
| `find -L` for Nix store symlinks | `find` does NOT follow starting-point symlinks by default. Wallpaper directories installed via HM symlinks need `find -L "$dir"` or trailing slash. Without `-L`, find silently returns nothing |
| `serviceOneshotDefaults` for oneshot services | `serviceDefaults`/`serviceDefaultsUser` default to `Restart=always` which is INVALID for `Type=oneshot` — systemd refuses to start. Use `serviceOneshotDefaults` (system) or `serviceOneshotDefaultsUser` (HM user) which default to `Restart=no`. Override to `on-failure` if retry-on-error is desired |
| `%h` vs `$HOME` in ExecStart | systemd user services may NOT expand `$HOME` in ExecStart (especially hardened services). Use `%h` (systemd specifier) instead, which always resolves to the user's home directory |
| `/nix/var/nix/builds` stale sandboxes | OOM crashes / hard resets leave orphaned build sandboxes in `/nix/var/nix/builds/` that can accumulate to 100+ GB. The `nix-build-cleanup` timer (every 4h + on boot) cleans dirs untouched >1h, but BTRFS snapshots may hold references — space isn't freed until snapshots expire (14d retention). Manual: `sudo rm -rf /nix/var/nix/builds/nix-*` |
| BTRFS CoW + snapshots block space reclamation | `rm` on BTRFS doesn't immediately free space when snapshots reference the data. After deleting large files/dirs, check `btrfs filesystem df /` — actual reclamation happens as btrbk snapshots expire. Don't assume `df` reflects freed space instantly |
| PocketID client-secret file desync | `pocket-id-provision` had a migration block that seeded `client-secrets/<id>` from the OLD sops secret, then the skip-if-exists check (`if [ -f ] && [ -s ]`) prevented calling `POST /secret` to generate the correct value. Since `POST /api/oidc/clients/{id}/secret` ALWAYS generates a NEW secret (rotating the old), and `POST /api/oidc/clients` does NOT auto-generate one, the DB had null/stale while the file had old sops → `401 invalid client secret` at token exchange. **Recovery (order matters):** (1) `sudo rm /var/lib/pocket-id/client-secrets/<id>`, (2) `sudo systemctl RESTART pocket-id-provision.service` (NOT `start` — `RemainAfterExit=true` makes `start` a no-op on already-active service), (3) `sudo systemctl reset-failed <consumer>.service && sudo systemctl start <consumer>.service`. **NEVER restart the consumer before provision completes** — `LoadCredential` makes the file load-bearing at service start; missing file = instant crash-loop (`status=243/CREDENTIALS`). Migration block now removed from provision script |
| BTRFS metadata ENOSPC crash (2026-06-26) | Nightly `nix-gc` timer fires metadata transactions on a filesystem with zero device-unallocated space → I/O deadlock → WDT reset. `df` reports Data-pool free space (statfs), NOT chunk-level allocation — the entire monitoring stack was blind. **Fix:** `btrfs-health.nix` gates `nix-gc` + `nix-build-cleanup` via `ExecStartPre` guard (aborts when device-unallocated < 10%), collects Prometheus metrics every 5 min, Gatus sends Discord alerts, DMS widget shows device-unallocated %. btrbk staggered to 23:00 (before GC at 00:00) so expired snapshots free extents before GC runs. Recovery: grow partition (sfdisk → partx → btrfs resize), NOT balance or rollback. See `docs/troubleshooting/btrfs-metadata-enospc-recovery.md` |
| DiscordSync always-on API server | Upstream (go-cqrs-lite v3) ALWAYS starts an HTTP API (`/metrics`, `/api/events/stream`, `/api/export`) — no flag to disable. Defaults to `:8080` which **conflicts with SigNoz**. Module overrides `API_ADDR` to `127.0.0.1:8085` (localhost-only). GCS attachment backup is opt-in: set `services.discordsync.gcsBucket` + add `discordsync_gcs_credentials` (service account JSON) to `discordsync.yaml` sops file |
| DiscordSync schema-drift migration (FIXED) | Migration crashed on old databases (`invalid expression in CREATE INDEX: guild_id`) because the initial schema lacked `guild_id` and `CREATE TABLE IF NOT EXISTS` was a no-op. **Fixed upstream:** Migrate now parses schemaDDL as single source of truth, runs `ALTER TABLE ADD COLUMN` for any missing column before creating indexes, and gracefully degrades when FTS5 is unavailable (turso engine lacks it). The `database is locked` errors during initial backfill are transient (single-connection SQLite pool under contention) |
| SigNoz stale SQLite migration_lock | After a crash/OOM/hard-reset mid-migration, `migration_lock` table in `/var/lib/signoz/signoz.db` keeps a row → next boots loop `attempt to acquire lock failed` → start-limit-hit. **Now self-healing:** `signoz.service` has an `ExecStartPre` (`signoz-clear-migration-lock`) that `DELETE FROM migration_lock` — safe because ExecStartPre runs with no signoz process alive. Do NOT remove this ExecStartPre. Manual recovery (pre-fix): `sqlite3 /var/lib/signoz/signoz.db "DELETE FROM migration_lock;"` |
| monitor365 hardened user services | ExecStart/ExecStartPre MUST use systemd specifiers (`%t` for runtime dir), NOT `$XDG_RUNTIME_DIR` — hardened user services don't reliably expose it (same class as the `%h` vs `$HOME` gotcha). The agent's inject-auth script receives `%t` as `$1`. Also: monitor365 binaries are a private LarsArtmann package whose CLI changed — the **server dropped `--config <file>`** (uses `MONITOR365_SERVER__*` env vars + XDG `~/.config/monitor365/server.toml` auto-load); the agent keeps `-c/--config` |
| `pkgs.nss` is libs-only | `certutil` (and other NSS tools) are in the **`pkgs.nss.tools`** output, NOT `pkgs.nss` (which is the library). A service with `path = [pkgs.nss]` will get `status=127` at runtime for `certutil`. Use `pkgs.nss.tools` (+ `coreutils` for `mkdir`/`sleep`) |
| xdg-document-portal needs fusermount3 | The portal fails at login (`posix_spawn for fusermount3 failed: No such file or directory`) unless a setuid `fusermount3` wrapper exists. Added via `security.wrappers.fusermount3` in `configuration.nix` (pulls `fuse3` into the closure). Removing it re-breaks the portal every login |
| Network interface boot race | **FIXED** for dnsblockd/keepalived; pending deploy. dns-blocker now uses a dedicated `dnsblockd-attach-ip.service` (CAP_NET_ADMIN oneshot, ordered after `sys-subsystem-net-devices-eno1.device`) to add the block IP, and `dnsblockd.service` depends on it. `networking.localCommands` with `|| true` is removed. keepalived and the dual-wan services (when re-enabled) also order after the `.device` unit. The old race where the IP was never added and dnsblockd crash-looped is closed. |
| SSH control-master socket stale-refuse | `ControlMaster auto` + `ControlPersist 600` (set by the `nix-ssh-config` module for `github.com`) leaves orphaned socket files in `~/.ssh/sockets/` when a master dies uncleanly (OOM, suspend, logout). SSH then prints `ControlSocket ... already exists, disabling multiplexing` on every `git push/fetch` (ops still succeed — SSH falls back to a direct connection). **Fixed** in `platforms/common/programs/ssh-config.nix`: `home.activation.ssh-sockets-dir` ensures the dir exists, and a `ssh-socket-cleanup` systemd **user** timer (every 5 min, Linux-only via `lib.optionalAttrs stdenv.isLinux`) probes each socket via AF_UNIX `connect()` and unlinks dead ones. Darwin has no systemd so it gets only the dir-creation activation. One-time manual clear: `rm ~/.ssh/sockets/*` |
| `-config` option suffix is intentional | A module named `audio.nix` exposes `services.audio-config.enable` (not `services.audio`). The `-config` suffix avoids colliding with the **upstream** NixOS option the module configures (e.g. `services.displayManager`, `services.pipewire`). Modules wrapping a same-named upstream service (immich, caddy, forgejo) reuse the upstream `.enable` directly. This is a deliberate convention, not a naming bug — do NOT "fix" it |
| `import ../../../lib/default.nix lib` boilerplate is required | Every module re-imports `lib/default.nix` rather than receiving helpers via `_module.args`. **This is correct:** `nix flake check` evaluates each `nixosModule` standalone (no injected args), so helpers MUST be self-imported. Injecting via `_module.args` would either break the standalone check or keep the import as a default (no win). Canonical form: `inherit (import ../../../lib/default.nix lib) harden serviceDefaults onFailure ports;` |
| Forgejo OIDC SSO via Pocket ID | Forgejo uses **native OIDC** (not Caddy forward-auth). The `forgejo-oidc-setup` oneshot service (in `forgejo.nix`) reads the client secret from `/var/lib/pocket-id/client-secrets/forgejo` and creates the "PocketID" auth source in Forgejo's DB via `forgejo admin auth add-oauth`. The auth source name ("PocketID") IS the URL slug — callback URL is `https://forgejo.${domain}/user/oauth2/PocketID/callback`. **Do NOT use spaces in the auth source name** — the callback URL would need `%20` encoding. Caddy vHost for forgejo is a direct TLS proxy (no `protectedVHost`/forward-auth) because forward-auth + native OIDC causes a double-auth redirect loop. `oauth2_client.ENABLE_AUTO_REGISTRATION = true` auto-creates users on first OIDC login (bypasses `service.DISABLE_REGISTRATION`). `ACCOUNT_LINKING = "auto"` links OIDC users to existing accounts by email match |
| Gatus native OIDC + DynamicUser | Gatus uses **native OIDC** (Layer 1) via `security.oidc` in `gatus-config.nix`. The NixOS gatus module sets `DynamicUser = true`, so the `gatus` user does NOT exist at sops-decrypt time and can't own files. Therefore the client secret is NOT a sops secret — it's the provisioned file `/var/lib/pocket-id/client-secrets/gatus`, loaded via systemd `LoadCredential` (read by root, exposed in `$CREDENTIALS_DIRECTORY`), then an `ExecStartPre` (`gatus-oidc-env`) copies it into `/run/gatus/oidc.env` which gatus reads via config.yaml `$GATUS_OIDC_CLIENT_SECRET` interpolation. Caddy `status.${domain}` is a plain `reverse_proxy` (NOT `protectedVHost`) — same double-auth rule as Forgejo. The Gatus self-health probe must use `[STATUS] < 400` (not `== 200`) when OIDC is on, because unauthenticated probes get a 302 redirect to the IdP login |
| Native OIDC ≠ free for every service | Before adding Layer 1 OIDC to a service, verify upstream support. Homepage has **no** built-in auth (proxy-only). SigNoz OIDC is **Enterprise-only** (not Community Edition we run). Twenty SSO is **billing-entitlement-gated** (contact twenty.com). Custom LarsArtmann Go services need OIDC code in their repos. These stay on Layer 2 (oauth2-proxy forward-auth). Each blocked service has a header comment in its `.nix` documenting why |

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
