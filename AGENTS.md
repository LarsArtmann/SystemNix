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

| System | Hostname           | Platform       | Constraints                      |
| ------ | ------------------ | -------------- | -------------------------------- |
| macOS  | `Lars-MacBook-Air` | aarch64-darwin | 24GB RAM, 256GB SSD (90%+ full)  |
| NixOS  | `evo-x2`           | x86_64-linux   | 128GB RAM, AMD Ryzen AI Max+ 395 |

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
9. **Add a Gatus health check** in `gatus-config.nix`. Use `mkHttpCheck` for HTTP endpoints, raw attrset for TCP/DNS checks. Add `alerts = discordAlert "..."` for any service whose failure should notify. Add `[RESPONSE_TIME] < N` conditions for user-facing services (500ms-2s depending on service). Every new service MUST be monitored — silent failures are unacceptable
10. **For OTLP tracing**: set `OTEL_EXPORTER_OTLP_ENDPOINT` in the service environment. Go services: `localhost:4318` (no scheme). Rust: `http://localhost:4317` (with scheme, gRPC). Python: `http://localhost:4318`. Docker: `http://host.docker.internal:4318`. The env var is a noop if the upstream binary lacks OTel instrumentation — see DiscordSync as the reference. Do NOT add `siteMonitor` to Homepage tiles — Gatus owns all health alerting
11. **For backup-producing services**: add the backup directory to `services.backup-coordination.backups.<name>` in `configuration.nix` with `directory`, `filePattern`, and `maxAgeHours`. Stagger schedules (01:00, 02:00, 02:30, 03:00) to avoid IO spikes

### Consuming LarsArtmann Flakes (DiscordSync/Monitor365 pattern)

When a service has an upstream LarsArtmann flake that exports `nixosModules`, **always consume the upstream module** — never hand-roll a parallel one:

```nix
{
  imports = [ inputs.X.nixosModules.default ];
  config = lib.mkIf cfg.enable {
    services.X = {
      # Override defaults with lib.mkDefault so upstream values still win
      # if they have higher priority. Use lib.mkForce only for values that
      # MUST differ (e.g. MemoryMax, startLimitBurst).
      package = lib.mkDefault inputs.X.packages.${pkgs.system}.default;
      someOption = lib.mkDefault "value";
    };
    systemd.services.X = {
      # Layer SystemNix specifics via lib.mkMerge — preserves mkDefault/mkForce
      serviceConfig = lib.mkMerge [
        { /* SystemNix-only additions */ }
        (harden { MemoryMax = lib.mkForce "2G"; })
      ];
    };
  };
}
```

**What to layer (SystemNix-only, upstream cannot provide):** sops templates, DNS-gate (`waitDnsReady`), `onFailure` alert routing, port wiring from `lib/ports.nix`, GCS/OTel env vars, activation scripts for subdir creation. **What NOT to re-declare:** `enable`, `package`, `user`, `group`, `dataDir`, `backend`, or any option upstream already declares — these arrive via `imports`.

**Fix application bugs upstream, not in SystemNix.** When a LarsArtmann service has a code-level bug (migration error, logic bug, schema drift), the fix belongs in the upstream repo (`/home/lars/projects/<repo>`) with tests, not as a local patch under `patches/` or an `overrideAttrs` hack in SystemNix. Downstream patches are reserved for build-environment problems (sandbox paths, missing dependencies). Patching logic downstream creates a hidden second source of truth, bypasses upstream tests, and makes rollback/rebuild fragile. The DiscordSync crash-loop was resolved by fixing `internal/db/backfill_nulls.go` in DiscordSync and bumping the flake input, not by maintaining a SystemNix patch.

Reference implementations: `modules/nixos/services/monitor365.nix` (gold standard), `modules/nixos/services/discordsync.nix` (converged to the pattern).

### Private Go Repos (LarsArtmann)

**GOPRIVATE setting** (`platforms/common/home-base.nix`): `privateGoPattern = "github.com/larsartmann/go-cqrs-lite,github.com/larsartmann/go-finding,github.com/larsartmann/go-structure-linter,github.com/LarsArtmann/go-commit"`. These 4 repos return 404 on `sum.golang.org` (checksum database). The Go proxy (`proxy.golang.org`) CAN serve their tagged versions, but the checksum DB can't verify them, so `GOPRIVATE` is required to skip sumdb verification. All other LarsArtmann repos are public and work fine WITHOUT GOPRIVATE.

All private repos use `git+ssh://` URLs. Go tool packages defined in `mkLarsPackages` in `flake.nix` — NOT overlays.

`mkPreparedSource` (from `go-nix-helpers`) auto-strips local replaces, normalizes pseudo-versions, generates `replace` directives. Features: `subModules` (handles `/v2` suffixes — include version in list entry, kept in path, stripped from dir), `stripLocalReplaces`, `subModuleVersionNormalize`.

**vendorHash breaking?** Set `vendorHash = ""`, build, paste `got:` hash.
**Core dep cascade?** Update dep repo first → publish tags → each consumer: `vendorHash = ""` → `nix flake lock --update-input <repo>`
**`proxyVendor = true`:** `go mod tidy` safe in both phases. **`proxyVendor = false`:** AVOID `overrideModAttrs` with `go mod tidy` — causes "inconsistent vendoring"
**Versioning:** Published = hardcode semver. Internal = `self.shortRev or self.dirtyShortRev or "dev"` for the **package version** (keeps the store-path name short, e.g. `pkg-ff1f0db`). For full-commit traceability inside the _binary_, add a separate `commit = self.rev` and pass it via ldflags (`-X main.commit=${commit}`) — NEVER use the full `self.rev` as the package `version`, it pollutes every derivation name (40-char hash in nvd/store paths)

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

### Qmd (On-Device Markdown Search)

**Module:** `modules/nixos/services/qmd-config.nix` (filename → `services.qmd-config`, named `-config` to avoid colliding with the upstream `pkgs.qmd` attribute)

- **Input:** GitHub `tobi/qmd` (Nix-native: VCS source + real `pnpm-lock.yaml`). Packaged in `pkgs/qmd.nix` via `fetchFromGitHub` + `pnpmConfigHook` + `pnpm run build` to produce `dist/`. The npm tarball is no longer used — this avoids vendoring a regenerated lockfile.
- **Service:** `qmd mcp --http` runs as a Home Manager **user** systemd service (`qmd-mcp.service`) on `127.0.0.1:8181` so embedding/reranker GGUF models (~2 GiB) stay loaded across requests. StdIO MCP mode spawns a fresh process per connection, paying 5-15s model-reload cost on every reconnect.
- **Index location:** `~/.cache/qmd/index.sqlite` (XDG_CACHE_HOME). Models cached in `~/.cache/qmd/models/`. Config in `~/.config/qmd/index.yml`. Declarative bootstrap collections via `services.qmd-config.bootstrapCollections` option.
- **CLI:** Available system-wide from `base.nix`. Use `qmd collection add ~/notes --name notes`, `qmd search ...`, `qmd query ...`, `qmd get ...`, `qmd status`.
- **MCP integration:** HTTP mode at `http://localhost:8181/mcp` for clients (Crush, Claude Code MCP config). Any MCP client with `qmd` on PATH can also use stdio MCP via `qmd mcp` (auto-discovered by Claude Code, requires explicit Crush `mcpServers` config for stdio).
- **CPU-only by default** (`QMD_FORCE_CPU=1`) — node-llama-cpp Vulkan probing is brittle on Strix Halo and competes with Ollama for VRAM. Override `services.qmd-config.qmdForceCpu = false` + set `QMD_LLAMA_GPU` to opt in to GPU acceleration.
- **Native deps:** `better-sqlite3` builds from source via `node-gyp` during `pnpm install` (no prebuilt download in sandbox). `autoPatchelfHook` ignores missing `libvulkan.so.1` / `libcuda.so.1` / `libcudart.so.*` / `libcublas.so.*` because GPU backends are disabled by default.
- **User-service sandboxing:** `qmd-mcp` runs as a Home Manager user service. The `hardenUser` helper omits `ProtectHome`/`ProtectSystem`/`ReadWritePaths` (these are system-only in the SystemNix helper), so the service runs within the user's normal filesystem namespace. It relies on `PrivateTmp`, `MemoryMax=4G`, `NoNewPrivileges`, and `RestrictNamespaces` for containment. This is intentional: qmd must read user-owned collections and write to `~/.cache/qmd/index.sqlite` and `~/.config/qmd/index.yml`.
- **Embedding model:** Override via `services.qmd-config.qmdEmbedModel = "hf:Qwen/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf"` for multilingual (CJK) support. Re-run `qmd embed -f` after switching — vectors are not cross-compatible between models.
- **Models:** Three auto-downloaded GGUF models on first use (cached in `~/.cache/qmd/models/`): `embeddinggemma-300M-Q8_0` (300MB), `qwen3-reranker-0.6b-q8_0` (640MB), `qmd-query-expansion-1.7B-q4_k_m` (1.1GB). HuggingFace fetch on first run requires INTERNET.
- **Restart triggers:** `restartTriggers` not yet needed (no store-path content observed to affect runtime). Add if `$out/lib/qmd/node_modules/` changes cause the same `_next/static/*` 404 pattern as Homepage.
- **Gatus:** `qmd MCP HTTP Server` health check at `http://localhost:8181/health` (5min interval, Discord alert on down). Health endpoint returns uptime JSON per docs.

### Sops + Age

**Encrypting a NEW secret file** — NO sudo needed. The age PUBLIC key in `.sops.yaml` is sufficient:

```bash
echo "secret_key: $(openssl rand -base64 32)" > platforms/nixos/secrets/newservice.yaml
sops -e -i platforms/nixos/secrets/newservice.yaml
git add -f platforms/nixos/secrets/newservice.yaml  # secrets/ matches .gitignore pattern
```

**Modifying or decrypting an existing secret** — requires the age PRIVATE key (from SSH host key, needs sudo):

```bash
SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age -private-key) sops --set '["key"] "value"' file.yaml
```

- `SOPS_AGE_KEY` in RAM only — never write age key to disk. `SOPS_AGE_SSH_PRIVATE_KEY_FILE` does NOT work with `sops` CLI
- `sops -e` (encrypt): needs only the PUBLIC key recipient from `.sops.yaml` — NO sudo. The private key is only needed at DEPLOY time (sops-nix activation script runs as root on the target host)
- `sops --set` / `sops -d` (modify/decrypt): needs `SOPS_AGE_KEY` env var with the private key — requires `sudo` to read the SSH host key
- Secrets with service-specific owners MUST be guarded with `lib.optionalAttrs config.services.X.enable` — one bad owner blocks ALL secrets atomically
- See `.crush/skills/sops-secret-management/SKILL.md` for full workflow

### Hermes

Active pip extras: `messaging`, `anthropic`, `firecrawl`, `edge-tts`, `fal`, `exa`. Do NOT add blindly — `voice` has complex native deps, `matrix` needs python-olm (Linux-only).

### SearXNG (Privacy Metasearch)

**Module:** `modules/nixos/services/searxng.nix` (wraps nixpkgs `services.searx` with package `searxng`)

- **Service:** SearXNG built-in Granian ASGI server on `127.0.0.1:${ports.searxng}` (8889). NOT uWSGI — the nixpkgs module's built-in server mode is simpler and sufficient for a homelab
- **No Redis/Valkey:** The rate limiter (`server.limiter = false`) is disabled — Redis was only used for bot detection sliding-window counters, pointless on a private LAN instance where all traffic is passlisted. Removing Redis eliminates a synchronous unix-socket round-trip on every search request
- **Secret key:** Auto-generated by `searxng-secret-key` oneshot service (`openssl rand -hex 32` → `/var/lib/searxng/searxng.env`, mode 0600, root:root). NOT sops — this is a machine-local random value, not a shared credential. systemd reads `EnvironmentFile` as PID 1, so the DynamicUser `searx` process receives the env var without file access
- **SSO:** Layer 2 (`protectedVHost`) — SearXNG has no native OIDC support. External access via oauth2-proxy forward-auth; LAN bypass open
- **Key settings:** `http_protocol_version = "1.1"` (keep-alive behind Caddy), `method = "GET"` (shareable URLs), `autocomplete = "duckduckgo"` (Yandex was slow from EU), `favicon_resolver = "duckduckgo"`, `theme_args.simple_style = "auto"` (dark mode), `query_in_title = true`, `formats = [ "html" ]` (no API surface)
- **`restartTriggers`** on `searx.service` references settings JSON + package — ensures searx restarts when config changes (the nixpkgs module only sets restartTriggers for uWSGI mode, not direct server mode)
- **Browser integration:** SearXNG is set as the default Chromium/Helium search engine via `programs.chromium.extraOpts` in `configuration.nix` (conditional on `services.searx.enable`). The `DefaultSearchProviderSuggestURL` uses SearXNG's `/autocompleter` endpoint — suggestions are proxied through SearXNG (not sent directly to Google). LAN access bypasses forward-auth, so search works without SSO prompts

### SSO / OIDC Architecture

Two SSO layers, both backed by **Pocket ID** (passkey-only OIDC IdP at `auth.<domain>`):

| Layer                                                    | How                                                                                                                                                                       | Services                                                                                         |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **Layer 1 — Native OIDC**                                | App integrates directly with Pocket ID (in-app login button). Provisioned as OIDC clients in `pocket-id.nix`; Caddy uses **plain `reverse_proxy`** (NOT `protectedVHost`) | Forgejo, Immich, **Gatus**                                                                       |
| **Layer 2 — oauth2-proxy forward-auth**                  | App has no native auth; Caddy `protectedVHost` gates external access behind a Pocket ID login. LAN access is open                                                         | Homepage, Twenty, Taskchampion, Manifest, OpenSEO†, Crush Daily, Dozzle, Monitor365, **SearXNG** |
| **Layer 2+ — oauth2-proxy forward-auth (unconditional)** | App internal auth disabled (impersonation mode); Caddy applies `forwardAuth` to ALL requests — no LAN bypass. Pocket ID is the sole auth boundary                         | **SigNoz**                                                                                       |

> **†** OpenSEO uses a **hand-rolled Caddy vHost** (not `protectedVHost`) to exempt `/api/gsc/oauth/callback` from forward-auth — see gotcha table. All other paths follow standard Layer 2 behavior (forward-auth for external clients, LAN bypass).

**Adding Layer 1 (native OIDC) to a service** — follow the immich/gatus pattern:

1. Register the OIDC client in `pocket-id.nix` `provision.oidcClients` (clientId, callbackURLs)
2. The provisioner writes the client secret to `/var/lib/pocket-id/client-secrets/<clientId>` (owned `pocket-id:pocket-id`, 640)
3. The service reads it: either via upstream `_secret` (immich), a runtime script `cat` (forgejo), or systemd `LoadCredential` (gatus — needed because gatus is a **DynamicUser** that can't own files)
4. Order the service `after`/`wants` `pocket-id-provision.service`
5. **In Caddy, use plain `reverse_proxy`** (like Forgejo/Gatus), NOT `protectedVHost` — a service with native OIDC behind `protectedVHost` causes a **double-auth** conflict

**Native OIDC is NOT free for most services** — verify upstream support before assuming:

- Homepage: no built-in auth at all (proxy-only by design)
- SigNoz: OIDC is Enterprise-only ($4k/mo). Uses impersonation mode (no internal auth) + unconditional Caddy forward-auth — Pocket ID is the sole auth boundary, no LAN bypass
- Twenty: SSO gated behind a billing entitlement
- Custom LarsArtmann Go services: require upstream OIDC code in their repos

**Single Logout (SLO) is partial, not coordinated.** Layer 2 apps share the oauth2-proxy session cookie (`.${domain}`) — logging out via oauth2-proxy's `/oauth2/sign_out` clears them together. Layer 1 apps (Forgejo, Immich, Gatus) each keep their **own** session cookie and do NOT participate in coordinated logout — visiting them after an IdP logout may still show the cached app session until it expires or the user explicitly logs out per-app. Pocket ID supports RP-initiated logout, but wiring it into every Layer 1 app's logout flow is per-app work and not currently done.

### BTRFS (evo-x2)

**Subvolume layout:** `/` mounts `@` (root). `/nix` and `/home` live INSIDE `@` — NOT separate `@nix`/`@home` subvolumes (wikis recommend flat layout; deferred to next reinstall). `/data` is a separate BTRFS partition (subvolid=5, toplevel). Cache dirs (`@cache-home`, `@go`, `@npm`, `@cargo`) are separate top-level subvolumes with automount. Rust `target/` dirs live on ext4 (`/rust-cache`) to avoid COW fragmentation.

**Snapshots:** Root (`@`) daily via btrbk at 23:00, `/data` (toplevel) daily at 23:30, both 14d+4w retention. Staggered BEFORE nix-gc (00:00) so expired snapshots free extents before GC runs. Snapshot freshness verified daily (alerts if >3 days old). `/mnt/btrfs-root` (subvolid=5) automounted for btrbk access.

**No remote backup:** All snapshots are LOCAL-ONLY. If the NVMe fails, everything is lost. This is the #1 data loss risk (flagged since 2026-06-25).

**Compression:** `compress=zstd` on `/` (filesystem-wide — covers all `@` subvolumes). `/data` uses `compress=zstd:3`. NOT `compress-force` (against upstream Btrfs guidelines). BTRFS compression is filesystem-wide: setting it on any mount applies to ALL subvolumes on that filesystem. Only `subvol`/`subvolid` and VFS options like `noatime` are per-mount-point.

**Commit interval:** `commit=300` on `/` and `/data`. Default 30s commits metadata every 30s; on QLC NAND this is ~10x write amplification for metadata alone. `commit=300` batches metadata commits to every 5 min, preserving SLC cache blocks for foreground I/O. Data loss window on crash: 5 min (acceptable with daily btrbk snapshots + CoW journaling consistency).

**Scrub:** `autoScrub` weekly on `/` and `/data`. Changed from monthly — frequent reboots (58 unsafe shutdowns) almost never let a monthly scrub complete before interruption. Scrub results collected as Prometheus metrics (`btrfs_scrub_errors_total`, `btrfs_scrub_status`, `btrfs_scrub_error_free`) via `btrfs-health-metrics` every 5 min. Gatus alerts on Discord when `btrfs_scrub_error_free` drops to 0 (errors found).

**TRIM:** `services.fstrim.enable = true` with daily schedule (`OnCalendar = lib.mkForce "daily"`). All BTRFS/ext4 mounts explicitly set `nodiscard` — QLC NAND causes 253ms discard latency → BTRFS commit stalls → WDT reset. Daily fstrim at idle I/O priority (`IOSchedulingClass=idle`, `Nice=10`) keeps the NVMe controller's FTL informed of freed blocks so the SLC cache stays healthy. BTRFS CoW churn (every write = new block + unreported free block) re-exhausts the SLC cache within 22-47h on weekly TRIM — daily runs only trim ~24h of churn (~50-100 GiB, ~10-15 min) vs the initial 446 GiB backlog (1h14m). Monitored via Gatus (`system_fstrim_duration_over_threshold`) when trim takes >30 min.

**bees dedup:** NOT recommended on this hardware. bees does random 4KB reads across the entire filesystem to hash blocks — QLC NAND random IO sensitivity makes this counterproductive. `auto-optimise-store` (whole-file hardlink dedup) captures the biggest win with zero extra IO.

**BTRFS quotas (qgroups):** NOT enabled. `btrfs quota enable` adds metadata overhead to every transaction for qgroup accounting. On QLC NAND, this I/O tax is not worth per-subvolume usage tracking. If the NVMe is upgraded to TLC/MLC, enable quotas and re-add the qgroup metrics (removed from `btrfs-health.nix` — search git history for `btrfs_qgroup_referenced_bytes`).

**Scrub monitoring:** `btrfs-health-metrics` (every 5 min) collects `btrfs_scrub_errors_total`, `btrfs_scrub_status`, `btrfs_scrub_duration_seconds`, and `btrfs_scrub_error_free` via `btrfs scrub status`. Requires `CAP_SYS_ADMIN` (the kernel's `btrfs_ioctl_scrub_progress` checks `capable(CAP_SYS_ADMIN)`). The service overrides `harden {}`'s empty `CapabilityBoundingSet` with `CAP_SYS_ADMIN`. Gatus "BTRFS Scrub Health" endpoint alerts on Discord when `btrfs_scrub_error_free` drops to 0.

**Balance (chunk consolidation):** Weekly automated balance in `btrfs-health.nix` prevents the 2026-06-26 metadata ENOSPC crash mode. Metadata balance (`-musage=50`) runs Mon 04:00, data balance (`-dusage=50 -dlimit=10`) runs Mon 05:00 — staggered after metadata (which is fast) and before nix-gc (00:00 next day). Both are guarded by `btrfs-chunk-check`: skip if a balance is already running, skip if device-unallocated < 5 GiB (metadata) or < 10 GiB (data) bounce room. Data balance is bounded (`-dlimit=10` = max 10 chunks per run, ~10 GiB) to prevent runaway IO. Both use `ProtectSystem = false` (balance ioctl needs raw filesystem access) + `CAP_SYS_ADMIN`.

**Emergency reserve:** A 10 GiB `fallocate`d file at `/btrfs-emergency-reserve`, created on boot by `btrfs-emergency-reserve.service`. Delete it (`rm /btrfs-emergency-reserve`) for instant 10 GiB free space when you need to run balance, repair, or survive metadata ENOSPC. The file is NOT auto-recreated after deletion — manually re-provision with `sudo systemctl start btrfs-emergency-reserve` after recovery. Tracked via Prometheus metrics (`btrfs_emergency_reserve_present`, `btrfs_emergency_reserve_bytes`) and Gatus alerts on Discord if the reserve goes missing.

---

## Critical Rules

- **Use flake commands** — `nix run .#deploy`, never raw `nixos-rebuild`/`darwin-rebuild`
- **Test first** — `nix flake check --no-build` (syntax) or `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (eval)
- **`trash` not `rm`**, **`git mv` not `mv`**, **2-space indentation**, **`config.allowBroken = false`**, **No OpenZFS on macOS** (kernel panics, ADR-003)
- **Open new terminal** after deploy (shell changes need new session)
- **Never hardcode** `localhost:PORT` — derive from config. All ports in `lib/ports.nix`, all images in `lib/images.nix`

---

## Non-Obvious Gotchas

> Full incident narratives, commit hashes, dates, and root-cause analysis are in [docs/gotchas-archive.md](./docs/gotchas-archive.md). Below are only enduring rules — things hard to discover from code alone.

### Nix & Nixpkgs

- **`mkMerge` on flake-parts top-level `config`** — Does NOT work; use inline config or imports. `mkMerge` on `serviceConfig` inside `systemd.services.<name>` IS safe.
- **`//` on `serviceConfig` discards priority** — Shallow merge clobbers `mkDefault`/`mkForce`. Always use `lib.mkMerge [...]`.
- **`with pkgs;` hides missing attrs** — Falls through to enclosing scope on missing attrs. Use explicit `pkgs.` prefixes.
- **`buildGoModule` silently drops unknown `env` attrs** — Only forwards a whitelist (`CGO_ENABLED`, `GOWORK`, etc.). Use `export VAR=value` in `preBuild` for anything else.
- **`buildGoDir` swallows build-constraint errors** — Returns 0 with empty output. Add post-build assertion that `$out/bin/` is non-empty.
- **flake-parts `mkFlake` does NOT accept a bare list** — Use `{ imports = [ ... ]; }` attrset instead. Nested lists crash evaluation.
- **`builtins.toString null` = `""`** — Does NOT throw. `config.users.users.<name>.uid` is `null` at eval time for `isNormalUser`. NEVER use it in slice/service names without null-checking. This caused the 2026-08-03 WDT crash (user-1000.slice ran uncapped).
- **deadnix `--fix` removes lambda params** — Does NOT add `...` when removing all params. Verify output leaves `...` in patterns whose callers pass extra attrs.
- **catppuccin-gtk + Python 3.14** — Overlay in `overlays/shared.nix` pins `python312`. nixpkgs default python3 breaks the build script.
- **`nixos-unstable` not `nixpkgs-unstable`** — Hydra only caches expensive builds (ROCm, CUDA) on the `nixos-unstable` jobset.
- **`import ../../../lib/default.nix lib` boilerplate required** — Each module self-imports helpers because `nix flake check` evaluates modules standalone (no injected args).
- **nixpkgs tarball lock regression (RECURRING)** — The Nix global registry rewrites `github:NixOS/nixpkgs/nixos-unstable` to a stale `channels.nixos.org` tarball during ANY `nix flake update`. `flake.nix` has an eval-time `nixpkgsTarballGuard` that fails `nix flake check`/`nix eval` when this happens. `--override-input` and `--no-use-registries` do NOT prevent it (registry intercepts even explicit github URLs on this machine). The PMA auto-commit daemon runs `nix flake update` and can re-introduce the regression despite the pre-commit hook. **One-command recovery:** `nix run .#fix-nixpkgs-lock` (pins current rev, no dependency cascade) or `bash scripts/fix-nixpkgs-lock.sh --latest` (newest nixos-unstable). The script uses `nix flake prefetch` (immune to registry interception) to repin the node. Defense in depth: eval guard (flake.nix) + pre-commit hook (.githooks) + CI normalization (.github/workflows/flake-update.yml runs the script after every update).
- **Go submodule `replace => ../../sibling` breaks transitive consumers** — Published Go submodules MUST use published versions, not local replaces. `mkPreparedSource` only strips top-level replaces.
- **Go vendorHash mismatches are FOD** — `nix flake check --no-build` does NOT catch them. Batch-test individual Go packages before full builds.
- **Dual cargo build paths need different `outputHashes` keys** — crane uses full git URL key; `importCargoLock` uses `package-version` key. Same hash value, different key format.

### Systemd

- **`harden {}` ExecStart trap** — NEVER put `ExecStart`/`Type`/`RemainAfterExit` inside `harden {}`. Merge outside via `mkMerge`.
- **`runuser` + `harden {}` = PAM failure** — PAM can't complete session init. Run as `User` directly, add shell `runuser()` passthrough function.
- **`serviceOneshotDefaults` for oneshots** — `serviceDefaults` defaults to `Restart=always` which is INVALID for `Type=oneshot`. Use `serviceOneshotDefaults`.
- **`%h` not `$HOME` in ExecStart** — Hardened user services may NOT expand `$HOME`. Use `%h` (systemd specifier).
- **`switch-to-configuration` exit code 4** — Service in `start-limit-hit` blocks activation. `deploy.sh` runs `systemctl reset-failed` first.
- **`switch-to-configuration` ignores `restartTriggers` on oneshot+RemainAfterExit** — `deploy.sh` explicitly restarts 8 provisioner oneshots after `nh os switch`.
- **`PathChanged` not `PathExists`** — `PathExists` fires immediately if file exists at unit start → re-fire loop → start-limit-hit. Use `PathChanged`.
- **`WorkingDirectory` runs BEFORE `ExecStartPre`** — If ExecStartPre creates the dir, service fails with `status=200/CHDIR`. Set WorkingDirectory to a parent that exists.
- **CPUQuota=200% default in `harden()`** — All services get a 2-core cap. Override per-service (AI services: 300-400%).
- **Docker services use `multi-user.target`** — NOT `graphical.target`.
- **`harden` vs `hardenUser`** — User services (systemd --user) MUST use `hardenUser`.

### Caddy & Reverse Proxy

- **`handle_path` STRIPS prefix** — Use `handle` when backend expects full path.
- **`${commonConfig}` required on ALL vhosts** — Security headers, compression, `-Server` suppression. Auto-applied by `protectedVHost`; manual vhosts must include explicitly.
- **`proxyTo` is canonical** — ALL `reverse_proxy` directives use `${proxyTo PORT}`. Never bare `reverse_proxy` — it omits `X-Real-IP`.
- **`auto_https off`** — `:80` catch-all vhost handles HTTP→HTTPS redirect. TLS certs are sops-managed, not ACME.
- **`tlsConfig`** — Enforces TLS 1.2+. `strict_sni_host on` prevents serving certs for unrecognized hostnames.
- **Admin API (port 2019) intentionally unauthenticated** — Firewalled out (only 80/443 open). `admin off` would kill `/metrics`.
- **Native OIDC services use plain `reverse_proxy`** — NOT `protectedVHost`. Forward-auth + native OIDC = double-auth loop.

### SSO / OIDC

- **Native OIDC is NOT free** — Verify upstream support: Homepage (no auth), SigNoz (Enterprise-only), Twenty (billing-gated), SearXNG (no accounts). These stay on Layer 2 forward-auth.
- **SigNoz impersonation mode** — Internal auth disabled; Caddy applies `forwardAuth` UNCONDITIONALLY (no LAN bypass). Pocket ID is the sole auth boundary.
- **Gatus native OIDC + DynamicUser** — Secret via `LoadCredential` (can't own files). Self-health probe must use `[STATUS] < 400` (302 redirect when OIDC on).
- **Forgejo OIDC** — Native OIDC via `forgejo-oidc-setup` oneshot. Auth source name ("PocketID") IS the URL slug — no spaces. `ENABLE_AUTO_REGISTRATION = true`.
- **Pocket ID client-secret desync** — Declarative recovery: `pocket-id-config.provision.regenerateSecretsFor = [ "clientId" ]`. `RemainAfterExit=true` makes `start` a no-op — use `RESTART`.
- **oauth2-proxy `--whitelist-domain=.${domain}` REQUIRED** — Without it, post-login redirect fails with 500.
- **oauth2-proxy `partOf` pocket-id-provision** — `LoadCredential` secrets need service restart when regenerated.

### BTRFS & Filesystems

- **All mounts set `nodiscard`** — QLC NAND (`discard=async`) causes 253ms discard latency → BTRFS commit stalls → WDT reset. Daily `fstrim.timer` (idle priority) handles TRIM.
- **SLC cache exhaustion is the root crash cause** — QLC NAND uses an SLC write cache that BTRFS CoW churn exhausts within 22-47h when fstrim is weekly. With cache gone, every write hits QLC directly (~253ms), building an exponential I/O queue that freezes the kernel → WDT reset. Daily fstrim + `commit=300` mitigates this. See `docs/gotchas-archive.md` for full incident narrative.
- **`commit=300` on all BTRFS mounts** — Reduces metadata write frequency ~10x vs default 30s, preserving SLC cache blocks. Data loss window: 5 min (acceptable with daily snapshots + CoW journaling).
- **ext4 uses bare `discard`** — `discard=async` on ext4 → mount fails → emergency shell.
- **Non-`nofail` mounts = boot hazard** — Any non-root mount without `nofail` that fails brings down `local-fs.target`.
- **Compression is filesystem-wide** — `compress=zstd` on any mount applies to ALL subvolumes. Only `subvol`/`subvolid` and VFS options are per-mount.
- **`/nix` lives inside `@`** — NOT a separate `@nix` subvolume. btrbk snapshots include the full nix store.
- **`rm` doesn't free space when snapshots reference data** — Reclamation happens as btrbk snapshots expire (14d retention).
- **`compsite` is memory-intensive** — Needs `MemoryMax=2G` minimum on a 47 GiB nix store. Runs every 6h (not 5min).
- **`/tmp` tmpfs capped at 48 GiB** — Via `systemd.mounts` (static `tmp.mount`). NEVER use `fileSystems."/tmp"` — generates runtime fstab entry → unmount failure.
- **`mkFilesystem` helper** — `lib/filesystems.nix` validates mount options at eval time. Use it instead of raw `fileSystems`.

### Docker & Containers

- **`oci-containers` backend defaults to Podman** — Set `backend = "docker"` when Docker is already enabled.
- **Docker 29.x `userland-proxy-path`** — `daemon.settings.userland-proxy = false`.
- **containerd bbolt corruption** — Recovery: stop docker → `mv meta.db meta.db.bak` → remove `containers/`/`containerd/`/`network/` dirs → restart.

### DNS (dnsblockd)

- **dnsblockd is the SOLE DNS resolver on :53** — Replaces unbound entirely. Embedded sdns handles DNSSEC, DoT/DoH, local zones, blocklists.
- **`dnsIPv6Enabled = false`** — evo-x2 has no global IPv6. Omits IPv6 root servers, avoids 5-15s timeouts.
- **Wildcard `*.home.lan` does NOT resolve** — Only explicitly listed subdomains in `dnsLocal.localSubdomains` resolve. New service subdomains MUST be added.
- **`restartTriggers` on dnsblockd** — Without it, config changes may not restart the process → stale config → DNS outage.
- **`ProtectSystem=strict` + SQLite** — Needs `WorkingDirectory` alongside `StateDirectory` or CANTOPEN errors.
- **Manual `/etc/resolv.conf` edits break local DNS** — Nix config writes static resolv.conf with only `127.0.0.1`. Every deploy restores it. Do NOT add fallback nameservers.

### Monitor365

- **Package alias trap** — `pkgs.monitor365` = agent (CLI), NOT server. Server is `monitor365-server` (symlinkJoin with WASM UI).
- **No JIT SSO provisioning** — Users MUST be pre-provisioned via bootstrap or `create-admin` CLI. SSO login fails if email doesn't match existing user.
- **DuckDB not SQLite** — Uses `.duckdb` extension. `normalize_db_path` converts `.db` → `.duckdb` as safety net.
- **Daily event limit override** — `monitor365-schema-migrate` runs `UPDATE tenants SET max_events_per_day = 1000000000` on every boot. Do NOT remove — server re-syncs upstream default on bootstrap.
- **DuckDB WAL corruption self-heal** — `ExecStartPre` removes `.wal` on every startup (always means unclean shutdown). Restores from backup if main DB missing.
- **DuckDB pool deadlock watchdog** — `monitor365-server-watchdog` (every 5min) checks `/health` + counts "pool acquire failed" journal errors. `Restart=always` only covers process exit — degraded-but-alive states need active health probes.
- **Graphical collectors need** — `input`/`video` groups, `ProtectProc = "default"` (not `invisible`), `%t` (not `$XDG_RUNTIME_DIR`) in ExecStart.
- **utoipa-swagger-ui overlay** — `overlays/linux.nix` deletes 0444 zip between cargo check/build. Remove when upstream fixes `fs::copy`.
- **libspa-sys vendored Cargo.tomls** — ALWAYS strip `[lints]` sections when regenerating vendor patches. `workspace = true` fails in sandbox.

### DiscordSync

- **Always-on API server** — Upstream ALWAYS starts HTTP API on `:8080` (conflicts with SigNoz). Override `apiAddr` to `127.0.0.1:8085`.
- **API startup race (5-11 min)** — API binds after thumb-hash backfill. NEVER add `ExecStartPost` readiness gate — it crash-loops the service. Use Gatus (60s interval).
- **SQLite corruption self-heal** — `ExecStartPre` runs `PRAGMA integrity_check`; corrupt DB moved to `.corrupt-<timestamp>`. Re-syncs from Turso cloud.
- **Module consumption pattern** — `imports = [ inputs.X.nixosModules.default ]` + layer SystemNix specifics via `lib.mkMerge`. See Monitor365 as gold standard.

### Desktop (DMS / Quickshell / Helium)

- **DMS `inputs.nixpkgs.follows` MANDATORY** — Mismatched Qt causes silent runtime crashes.
- **DMS `systemd.enable` defaults false** — MUST explicitly set `programs.dank-material-shell.systemd.enable = true`.
- **DMS owns wallpaper management** — awww RETIRED. `enableDynamicTheming = false` (matugen conflicts with Catppuccin Mocha).
- **DMS notification conflict** — Dunst disabled. DMS owns `org.freedesktop.Notifications`.
- **DMS `plugin_settings.json` read-only** — Nix-managed symlink. `settings.json` is user-owned/mutable. UI changes to plugin settings disappear on rebuild.
- **cliphist RETIRED** — DMS owns clipboard history exclusively.
- **Quickshell `Process` has NO `onFailed`** — Use `onStreamFinished` with text-length check.
- **ScriptModel UAF (unfixed upstream)** — Quickshell 0.3.0 + Qt 6.11.1 use-after-free in ScriptModel. Mitigation: `Restart=always` + `StartLimitBurst=30`.
- **SDDM hides boot logs** — `console=tty2` redirects boot messages. `Ctrl+Alt+F2` = full log.
- **Helium GPU SIGBUS** — `--disable-gpu-watchdog` in wrapper. Amplified by `--enable-zero-copy` + high GPUActive.
- **Helium zero-output death** — Niri has no virtual output support. When all outputs disconnect, Helium exits cleanly. `Restart=always` + `RestartSec=5`.
- **helium-launch waits indefinitely** — No timeout (timeout caused empty-window loop). Becomes a monitor that blocks until existing instance dies.
- **Helium is Chromium 150** — Full ungoogled-chromium fork, NOT Electron. Widevine bundled separately.
- **VA-API flag renames (Chromium 131+)** — `VaapiVideoDecodeLinuxGL` → `AcceleratedVideoDecodeLinuxGL`, etc. Since 143+, VA-API works out of box; explicit flags are defense-in-depth.
- **`--disable-background-networking` kills extensions** — Blocks ExtensionDownloader. Do NOT re-add (Helium's ungoogled base already strips Google telemetry).

### SearXNG

- **`enable` infinite recursion** — Wrapper MUST NOT set `services.searx.enable` inside `lib.mkIf cfg.enable` where `cfg = config.services.searx`.
- **No `restartTriggers` in direct server mode** — nixpkgs only sets them for uWSGI mode. SystemNix adds them.
- **Port 8889** (not 8888 — SigNoz OTel collector owns 8888).
- **Engine init never retried** — Engines that fail network during `init()` at boot stay permanently disabled. DNS-gate `ExecStartPre` ensures DNS is ready.
- **`formats = [ "html" ]`** — Blocks JSON API (403). Deliberate privacy hardening. Test in HTML mode.
- **`autocomplete = "duckduckgo"`** — Google leaked every keystroke.
- **XFF health-check noise is benign** — `/healthz` is exempt from limiter.

### Other Services

- **`pkgs.nss` is libs-only** — `certutil` is in `pkgs.nss.tools`.
- **xdg-document-portal needs fusermount3** — `security.wrappers.fusermount3` required.
- **Homepage `enableLocalIcons = false` (default)** — SystemNix overrides to `true`. Many "obvious" icon names DON'T exist — verify against store path.
- **Homepage `restartTriggers`** — ANY service serving static files from nix store MUST have `restartTriggers = [ pkg ]`. Orphaned process + GC'd files = silent 404s.
- **Homepage `siteMonitor` removed** — Gatus owns all health alerting. Do NOT re-add.
- **qmd first-run warmup** — 30-60s model loading on first start. Subsequent restarts <5s.
- **qmd stdio vs HTTP MCP** — Pick ONE mode per client. Both configured = 4 GiB VRAM pressure.
- **Crush Daily API returns date strings** — Array of ISO date strings, NOT objects with `"id"`.
- **PMA `Type=notify` override** — Upstream sets `Type=notify` but binary never calls `sd_notify`. SystemNix overrides `Type=exec`. Remove when upstream adds sd_notify.
- **Deploy generation mismatch** — `nix eval` may show correct values but deployed unit has STALE values. Deploy AGAIN if they differ.
- **Forgejo SSH keys** — Forgejo doesn't read NixOS `openssh.authorizedKeys.keys`. Provisioned via admin API (`forgejo-ssh-keys` oneshot).
- **Forgejo `GET /admin/users/{u}/keys` → 405** — Use public `GET /api/v1/users/{u}/keys` for dedup. POST stays on admin path.
- **OpenSEO GSC callback** — Hand-rolled Caddy vHost (NOT `protectedVHost`) to exempt `/api/gsc/oauth/callback` from forward-auth. Do NOT simplify.
- **`-config` suffix is intentional** — `services.audio-config.enable` avoids colliding with upstream `services.pipewire` etc.

### Shell & DevTools

- **`writeShellApplication` pipefail + `|| echo 0`** — Produces multi-line output under pipefail. Use `|| true` + `''${var:-0}`.
- **`writeShellApplication` pipefail + `| sort | head` SIGPIPE** — Append `|| true` to pipeline.
- **`find -L` for Nix store symlinks** — `find` does NOT follow starting-point symlinks by default.
- **Smart direnv library** — `~/.config/direnv/lib/zz-smart-nix.sh` overrides `_nix_add_gcroot` (5.1x speedup) + `use_go_env` (auto-detects GOEXPERIMENT/GOPRIVATE).
- **Fish per-prompt direnv caching** — mtime-gated; 0.7ms cache hit vs 43ms. Per-session sentinel includes `$fish_pid`.
- **`git insteadOf` flake.lock SSH pollution** — Global rule rewrites `https://github.com/` → `git@github.com:`. Workaround: `GIT_CONFIG_GLOBAL=/dev/null nix flake update <input>`.
- **statix `repeated_keys` disabled** — False positive for NixOS modules. `statix.toml` (non-dotted) has `disabled = ["repeated_keys"]`.

### Infrastructure Patterns

- **`backup-coordination` module** — Generic backup monitoring via Prometheus textfile. Add backups to `services.backup-coordination.backups.<name>` in `configuration.nix`.
- **`system-health` module** — Textfile collector for systemd state, memory, GPUActive, CPU%. Pre-computes boolean flags for Gatus (Gatus `pat()` can't do numeric comparison).
- **`wrapWithMemoryLimit` helper** — `lib/default.nix` creates `-memlimit` wrappers for dev commands (go-test-memlimit, cargo-test-memlimit, etc.).
- **DynamicUser eval-time assert** — `dynamic-user-audit.nix` cross-references DynamicUser services with sops secrets at eval time. Catches ANY DynamicUser service, not just hardcoded names.
- **NixOS VM tests** — `tests/default.nix` uses `pkgs.testers.runNixOSTest`. `mock-sops.nix` + `test-helpers.nix` provide common mocks.
- **Attic binary cache** — RS256 (not HS256). DynamicUser → sops owner must be root. No `/api/v1/server-info` endpoint. No `attic token` subcommand — use `atticadm make-token`. tmpfiles unsafe path transition on `/data` → dedicated storage-dir service needed.
- **Secret rotation monitoring** — `pocket-id-secret-rotation` checks client secret freshness (90d threshold). Does NOT auto-rotate.
- **Gatus `[BODY].jsonpath.X` unreliable in v5.36.0** — Use `[STATUS]` + `[BODY] == pat(*)` instead.
- **SigNoz alert `target=0` + `above_or_equal` = always true** — `mkRule` has eval-time `validateTarget` assertion. Use `target=1` for "at least one" semantics.
- **Post-deploy smoke test** — `nix run .#post-deploy-check` verifies functional outcomes, not just liveness. Hard FAILs on silent-zero regressions.
- **Prebuilt ELF binaries in Go modules break FOD purity** — Use `buildGoModule` with `subPackages` or vendor via `fetchurl`.

---

## Build & Deploy

```bash
nix flake check --no-build  # Validate syntax (fast)
nix run .#deploy            # Build + deploy via nh
nix fmt                     # treefmt + alejandra
```

For contributor style, module templates, and verification commands, see [docs/CONTRIBUTING.md](./docs/CONTRIBUTING.md).

---

## Platform Constraints

**Darwin:** 256GB SSD 90-95% full, 24GB RAM. `nix-collect-garbage` hangs; clear caches before builds. Never add packages that build from source >10min. HM config is minimal — no terminal/editor/theme parity with NixOS.

**GPU (NixOS):** `OLLAMA_GPU_OVERHEAD=8589934592` (8 GiB) reserves headroom for compositor. Memory fractions are per-service, not system-wide.
