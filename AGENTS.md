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
5. Use `harden {} // serviceDefaults {}` for systemd. **Must** set `startLimitBurst = 5; startLimitIntervalSec = 300;` A global `DefaultTimeoutStartSec=3min` is set by `timeout-audit.nix` — individual services don't need per-service `TimeoutStartSec` unless they need a longer timeout (e.g. large DB migrations)
6. All vHosts in `caddy.nix`, all Homepage tiles in `homepage.nix` (guard conditional tiles with `lib.optionalString`)
7. `WatchdogSec` ONLY on services that send `WATCHDOG=1` via `sd_notify()` — Type=notify alone is NOT sufficient
8. For native OIDC SSO: add the client to `pocket-id.nix` `oidcClients` default, add a provisioning oneshot that reads the secret from `/var/lib/pocket-id/client-secrets/<clientId>` and configures the service via its CLI/API. Use a direct TLS Caddy vHost (NOT `protectedVHost`) — forward-auth + native OIDC causes double-auth loops. See Forgejo (`forgejo-oidc-setup`) as the reference pattern
9. **Add a Gatus health check** in `gatus-config.nix`. Use `mkHttpCheck` for HTTP endpoints, raw attrset for TCP/DNS checks. Add `alerts = discordAlert "..."` for any service whose failure should notify. Add `[RESPONSE_TIME] < N` conditions for user-facing services (500ms-2s depending on service). Every new service MUST be monitored — silent failures are unacceptable. **Gatus `pat()` uses GLOB, not regex** — `?` is single-char wildcard (NOT optional quantifier), `+` is literal (NOT one-or-more). The `gatus-pattern-lint` flake check rejects `?`/`+` in `pat()` automatically
10. **For OTLP tracing**: set `OTEL_EXPORTER_OTLP_ENDPOINT` in the service environment. Go services: `localhost:4318` (no scheme). Rust: `http://localhost:4317` (with scheme, gRPC). Python: `http://localhost:4318`. Docker: `http://host.docker.internal:4318`. The env var is a noop if the upstream binary lacks OTel instrumentation — see DiscordSync as the reference. Do NOT add `siteMonitor` to Homepage tiles — Gatus owns all health alerting
11. **For backup-producing services**: add the backup directory to `services.backup-coordination.backups.<name>` in `configuration.nix` with `directory`, `filePattern`, and `maxAgeHours`. Stagger schedules (01:00, 02:00, 02:30, 03:00) to avoid IO spikes

### Prevention Layers

Every change passes through 5 pipeline layers. Each catches a different class of bug:

| Layer | What it catches | Where | Mechanism |
|-------|----------------|-------|-----------|
| **Eval-time (Nix)** | Port collisions, filesystem contamination, tarball regression, missing TimeoutStartSec | `flake.nix`, `lib/`, `modules/nixos/services/*-audit.nix`, `timeout-audit.nix` | `builtins.throw`, `config.assertions`, `systemd.settings.Manager` |
| **Pre-commit** | Secrets, dead code, lint, formatting, tarball, Gatus pat() syntax, Unknown Author, GOTOOLCHAIN=auto | `.githooks/pre-commit` | gitleaks, deadnix, statix, alejandra, `nix flake check`, grep guards |
| **CI (GitHub Actions)** | Same linters + VM tests + flake input hygiene + daily nixpkgs compat | `.github/workflows/` | `nix-check.yml` (push/PR), `nixpkgs-compat.yml` (daily schedule) |
| **Pre-deploy** | Mount safety, ExecStart-in-harden, disk space, port conflicts, **phantom metrics** | `scripts/pre-deploy-check.sh` | 10 numbered checks including metric presence validation |
| **Post-deploy** | Service liveness, functional outcomes, data presence, **auth gateway health** | `scripts/post-deploy-check.sh` | HTTP smoke tests, SigNoz impersonation check, auth vHost 500/502 detection |

**Gatus Health Check Design Patterns:**
- `pat(*metric_name*)` = presence check (metric exists in `/metrics` output)
- `pat(*metric_name 0*)` = value check (metric exists AND equals 0 — e.g. "no errors")
- `pat(*<html*)` = HTML body check (web UI is serving HTML)
- **Liveness vs health**: liveness = "process alive" (`[STATUS] == 200`), health = "functional" (`[BODY] == pat(*metric*)`). Always include BOTH conditions — liveness alone gives false greens
- **"Intentionally headless" vs "desktop died"**: `niri-health-metrics` emits `niri_graphical_session` (1 if user has a wayland/x11 session via `loginctl`), `niri_desktop_died` (1 if graphical session active but niri not running), and `niri_crash_loop` (1 if `niri_restarts_10m >= 3`). Gatus alerts on `niri_desktop_died 0` and `niri_crash_loop 0` — NOT on `niri_running 0`. This avoids false alerts when the user is SSH-only and hasn't logged in via SDDM. `niri_desktop_died` uses a 60s grace period (2 consecutive checks) to avoid flapping during niri's 2s auto-restart window
- **Phantom metrics**: Rust `metrics` crate lazily serializes — a metric that's never incremented never appears in `/metrics`. Always verify the metric exists at runtime via pre-deploy-check.sh section 10

### Auth/DNS Gate Helpers (`mkOidcGate` / `mkDnsGate`)

Services that need the OIDC stack (Pocket ID + DNS + TLS) or DNS resolution at boot MUST use the shared helpers from `lib/default.nix` instead of hand-rolling curl/getent scripts. Both return a `{ after, wants, serviceConfig.ExecStartPre }` fragment that merges into `systemd.services.<name>`.

**`mkOidcGate`** — probes `https://auth.${domain}/.well-known/openid-configuration` via curl (120s timeout, TLS verified). Verifies the full chain: DNS → TLS → HTTP. Use for any service consuming native OIDC or oauth2-proxy.

```nix
inherit (import ../../../lib/default.nix lib) mkOidcGate;
# ...
systemd.services.my-service =
  let oidcGate = mkOidcGate { inherit pkgs domain; serviceName = "my-service"; };
  in {
    after = oidcGate.after ++ [ "other-dep.service" ];
    wants = oidcGate.wants;
    serviceConfig = lib.mkMerge [
      (harden {})
      { ExecStartPre = [ "${lib.getExe myCheckScript}" ] ++ oidcGate.serviceConfig.ExecStartPre; }
    ];
  };
```

**`mkDnsGate`** — probes DNS resolution via `getent hosts <hostname>`. Use for services that need DNS at init time but don't depend on OIDC (e.g., SearXNG engine init). Supports `fatal = false` for non-blocking warnings.

```nix
dnsGate = mkDnsGate { inherit pkgs; serviceName = "my-svc"; hostname = "wikidata.org"; fatal = false; };
```

**`includeProvision`** (default `true`) — adds `pocket-id-provision.service` to after/wants. Set to `false` for services that don't need provisioned OIDC clients.

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

**What to layer (SystemNix-only, upstream cannot provide):** sops templates, DNS-gate (`mkDnsGate`/`mkOidcGate` from `lib/default.nix`), `onFailure` alert routing, port wiring from `lib/ports.nix`, GCS/OTel env vars, activation scripts for subdir creation. **What NOT to re-declare:** `enable`, `package`, `user`, `group`, `dataDir`, `backend`, or any option upstream already declares — these arrive via `imports`.

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
- **dms-wallpaper-init needs `dms` in runtimeInputs** — The service calls `dms ipc call wallpaper next` but `dms` is NOT on PATH by default in a systemd service context. Must add `dankMaterialShell.packages.${pkgs.system}.default` to the script's `runtimeInputs`
- **Waybar RETIRED:** Completely removed (import, package, service, scripts). DMS is the sole shell
- **Rofi migrated to DMS (2026-06-30):** niri's 5 rofi keybindings rewired to DMS IPC (`spotlight toggle`, `clipboard toggle`, `keybinds toggle niri`, `spotlight toggleQuery ":e"`, `spotlight toggleQuery "="`). Rofi leaked 7 GB and OOM-killed niri. Rofi config (`rofi.nix`) remains for Sway backup WM only. DMS service has `MemoryMax=4G` as defense-in-depth. Emoji via dms-emoji-launcher plugin (trigger `:e`), calculator via DankCalculator plugin (trigger `=`)
- **Runtime verified:** DMS owns `org.freedesktop.Notifications`, `org.gnome.ScreenSaver`, `org.kde.StatusNotifierWatcher` DBus names
- **DMS niri module:** Import `dankMaterialShell.homeModules.niri` for niri-specific integration (workspace IPC via `$NIRI_SOCKET`)
- **`inputs.nixpkgs.follows`** on the DMS input is MANDATORY — mismatched Qt causes runtime crashes
- **Shutdown countdown overlay (2026-08-14):** `modules/nixos/desktop/shutdown-overlay.nix` runs a SECOND Quickshell instance (`services.shutdown-overlay`, user service) that shows a fullscreen overlay on ALL monitors when `/run/systemd/shutdown/scheduled` has ≤60s left — `WlrLayer.Overlay` + `ExclusionMode.Ignore` + click-through `mask: Region {}` (DMS FrameWindow pattern). It reads the µs timestamp from line 1; `shutdown -c` removes the file and the overlay hides within 200ms. niri's built-in hotkey overlay ("Important hotkeys", compositor-drawn while a keybind chord is pending) renders above the ENTIRE layer-shell Overlay layer (`Niri::render_inner` pushes it before `Layer::Overlay`) — no client can top it; only session-lock/exit-dialog do. A standalone quickshell run from SSH needs `DISPLAY` set or it dies silently after a Gtk warning (session user services get both DISPLAY and WAYLAND_DISPLAY imported, so the unit is unaffected)

### Smart-Audio (focus-following HDMI audio router)

**Module:** `modules/nixos/desktop/smart-audio.nix` (`services.smart-audio.enable`) — user systemd service, deployed live

- Python stdlib daemon watching `niri msg --json event-stream`; maps focused workspace → output → Radeon HDMI profile; switches via `wpctl set-profile` + `wpctl set-default`. HDMI audio profiles on the Radeon card are MUTUALLY EXCLUSIVE — profile switching (not just sink switching) is required
- Supersedes the static WirePlumber profile-priority rules in `audio.nix` (coexistence unverified — `device.restore-profile = false` may fight the daemon on device events)
- **`pkgs.writers.writePython3Bin` runs a strict pyflakes/pycodestyle linter at build time** — use `pkgs.writeScriptBin` with a `python3.interpreter` shebang for daemon scripts (cost a full build+deploy cycle to learn)

### Browser History

**Module:** `modules/nixos/services/browser-history.nix` — thin wrapper importing upstream `nixosModules.browser-history-server` + `nixosModules.browser-history-agent`

- **Architecture:** SystemNix consumes BOTH upstream modules via `imports`. Upstream provides all options, defaults, assertions, and security hardening (`DynamicUser`, `ProtectSystem=strict`, `MemoryMax=512M`, `StartLimitBurst`, `USE_SQLITE_READ_MODEL=true`). SystemNix layers only: package wiring, port from `lib/ports.nix`, WebAuthn/OAuth2 domain config, OTel endpoint, sops agent token, Pocket ID secret bridging, onFailure routing
- **Server + Agent dual-module:** Both modules imported unconditionally. Machines enable independently: `services.browser-history.enable = true` (server) and/or `services.browser-history-agent.enable = true` (agent)
- **Agent runs as desktop user** (`User = primaryUser`) because browser profiles are mode 0700. Upstream sets `ProtectHome=read-only` which is compatible — user can read own profiles, systemd injects env via `EnvironmentFile` (root reads the file)
- **Agent token:** Shared sops secret (`browser_history_agent_token`) rendered as `browser-history-env` template. Both server (DynamicUser) and agent read it via `EnvironmentFile`. The v1 auth path uses constant-time env-var comparison — raw hex token works without DB-backed `bh_`-prefixed token creation
- **Pocket ID OAuth2 bridging:** `browser-history-oidc-setup` oneshot reads the Pocket ID client secret via systemd `LoadCredential = [ "pocket-id-secret:${config.services.pocket-id.dataDir}/client-secrets/browser-history" ]` (bypasses `ProtectSystem=strict` — systemd reads the file as PID 1 at service start, makes it available via `$CREDENTIALS_DIRECTORY/pocket-id-secret`). Writes `OAUTH2_POCKET_ID_CLIENT_ID`, `OAUTH2_POCKET_ID_CLIENT_SECRET`, AND `OAUTH2_POCKET_ID_ISSUER` to `/var/lib/browser-history-oidc/oauth2-secrets.env`. Optional `-` prefix on server's `EnvironmentFile` = graceful degradation to WebAuthn-only if secret missing
- **OIDC oneshot isolated StateDirectory:** The oneshot uses `StateDirectory = "browser-history-oidc"` (NOT `browser-history`). The server's `DynamicUser=true` + `StateDirectory=browser-history` creates `/var/lib/browser-history/` owned by a random dynamic UID (mode 0700). No other service can write there. The oneshot MUST use a separate StateDirectory to write the OAuth2 env file
- **`ProviderConfig.Validate()` crash-loop root cause:** Upstream module uses `optionalEnv "OAUTH2_POCKET_ID_CLIENT_ID" cfg.oauth2.pocketId.clientId` — if `clientId` is set via module option, the env var is ALWAYS emitted as a systemd `Environment` directive, even when the client secret is missing. The Go OAuth2 provider builder gates on `ClientID != ""` but does NOT check `ClientSecret`. `cqrs-htmx/usermgmt/oauth2/provider.go:Validate()` rejects empty `ClientSecret` with a hard error → `server.create_oauth2_provider` → crash-loop (exit code 69). Fix: do NOT set `clientId`/`issuer` via upstream module options — route ALL three Pocket ID OAuth2 vars (CLIENT_ID, CLIENT_SECRET, ISSUER) through the single OIDC oneshot env file so they're either ALL present or ALL absent
- **EnvironmentFile list merging:** Server gets TWO env files via NixOS list concatenation across `mkMerge` blocks: sops template (always) + OAuth2 secrets (optional, `-` prefix). Verified: `[ "-/var/lib/browser-history-oidc/oauth2-secrets.env" "/run/secrets/rendered/browser-history-env" ]`
- **Deploy ordering:** `deploy.sh` restarts `browser-history-oidc-setup` (provisioner loop) then explicitly restarts `browser-history.service` so it reloads the OAuth2 env file
- **go.work needs the `identity-model/v4 => ../cqrs-htmx/identity-model` local replace** — without it, builds break against local cqrs-htmx (20-min diagnosis if unknown). The Nix build uses PUBLISHED versions: browser-history `go.mod` must require new cqrs-htmx tags BEFORE the SystemNix flake bump (go.work replaces hide the version dependency locally)

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

**`registration_lifecycle` missing-module patch:** Upstream `pyproject.toml` `[tool.setuptools] py-modules` list is missing `registration_lifecycle`, a top-level module imported by `hermes_cli/plugins.py` at module level. Without it, the sealed uv2nix venv is missing the file → `ModuleNotFoundError` → crash-loop → `start-limit-hit`. Fix in `hermes.nix`: extract `registration_lifecycle.py` from the flake input source into a `runCommand` derivation, inject via `wrapProgram --suffix PYTHONPATH` in `overrideAttrs postInstall`. The module only imports stdlib (`threading`, `dataclasses`, `collections.abc`), so no additional deps needed. When upstream adds `registration_lifecycle` to `py-modules`, the SystemNix patch becomes a no-op (PYTHONPATH suffix is harmless if the module is already in site-packages) — delete it then. Also `mini_swe_runner.py` is missing from `py-modules` but is not imported at runtime (only by its own test file), so it doesn't need patching.

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
| **Layer 1 — Native OIDC**                                | App integrates directly with Pocket ID (in-app login button). Provisioned as OIDC clients in `pocket-id.nix`; Caddy uses **plain `reverse_proxy`** (NOT `protectedVHost`) | Forgejo, Immich, **Gatus**, **Browser History**                                                 |
| **Layer 2 — oauth2-proxy forward-auth**                  | App has no native auth; Caddy `protectedVHost` gates external access behind a Pocket ID login. LAN access is open                                                         | Homepage, Twenty, Taskchampion, Manifest, OpenSEO†, Crush Daily, Dozzle, Monitor365, **SearXNG**, **SigNoz** |

> **SigNoz** runs in impersonation mode (every request = root admin, no internal auth). OIDC is Enterprise-only ($4k/mo). Uses standard Layer 2 `protectedVHost`: LAN bypass (direct proxy), external forward-auth via oauth2-proxy. The previous unconditional forward-auth (no LAN bypass) caused 500 errors for ALL users when oauth2-proxy hiccuped — `protectedVHost` fixes this by keeping LAN traffic off the oauth2-proxy path entirely.

> **†** OpenSEO uses a **hand-rolled Caddy vHost** (not `protectedVHost`) to exempt `/api/gsc/oauth/callback` from forward-auth — see gotcha table. All other paths follow standard Layer 2 behavior (forward-auth for external clients, LAN bypass).

**Adding Layer 1 (native OIDC) to a service** — follow the immich/gatus pattern:

1. Register the OIDC client in `pocket-id.nix` `provision.oidcClients` (clientId, callbackURLs)
2. The provisioner writes the client secret to `/var/lib/pocket-id/client-secrets/<clientId>` (owned `pocket-id:pocket-id`, 640)
3. The service reads it: either via upstream `_secret` (immich), a runtime script `cat` (forgejo), or systemd `LoadCredential` (gatus — needed because gatus is a **DynamicUser** that can't own files)
4. Order the service `after`/`wants` `pocket-id-provision.service`
5. **In Caddy, use plain `reverse_proxy`** (like Forgejo/Gatus), NOT `protectedVHost` — a service with native OIDC behind `protectedVHost` causes a **double-auth** conflict

**Native OIDC is NOT free for most services** — verify upstream support before assuming:

- Homepage: no built-in auth at all (proxy-only by design)
- SigNoz: OIDC is Enterprise-only ($4k/mo). Runs in impersonation mode (no internal auth). Uses Layer 2 `protectedVHost` — LAN bypass + external forward-auth
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

### BFQ I/O Priority Tiers (evo-x2)

The evo-x2 has a 2TB QLC NVMe (Lexar NQ790) with an SLC write cache that BTRFS CoW churn exhausts within 22-47h. BFQ I/O scheduling prevents build storms from freezing SSH sessions and the desktop compositor.

**Tier system** (lower BE priority = higher I/O precedence):

| Tier | Helper | BFQ Class/Pri | Services | Purpose |
|------|--------|---------------|----------|---------|
| Interactive | `ioTier.interactive` | BE/1 | sshd | SSH must always respond |
| Desktop | `ioTier.desktop` | BE/3 | niri, dms, pipewire, crush (wrapper) | Compositor/audio must stay responsive |
| Service (default) | `ioTier.service` | BE/4 | Most services | Default for unclassified services |
| Heavy DB | `ioTier.heavyDB` | BE/5 | clickhouse, monitor365-server | Latency-sensitive databases |
| Background | `ioTier.background` | BE/6 | signoz, discordsync, browser-history, ollama, attic | Standard daemons tolerating I/O latency |
| Build | `ioTier.build` | BE/7 + Nice=10 | nix-daemon, forgejo-runner, PMA | Batch builds and CI — lowest BE |
| Maintenance | `ioTier.maintenance` | idle + Nice=10 | fstrim, clamav | Only runs when nothing else needs I/O |

**Usage:** Import `ioTier` from `lib/default.nix`, merge with `harden {}` via `mkMerge`:

```nix
inherit (import ../../../lib/default.nix lib) harden ioTier;
# ...
serviceConfig = lib.mkMerge [
  (harden { MemoryMax = "1G"; })
  ioTier.background
];
```

**Crush wrapper:** The `crush` binary is wrapped with `ionice -c 2 -n 3 nice -n 5` (BE/3) via `writeShellApplication` in `base.nix`. Works in all contexts (interactive, scripts, MCP) — not just interactive shells like the old alias. Scheduled tasks (`crush-update-providers`) use the raw binary directly via `lib.getExe'`.

**DB-heal oneshot:** DiscordSync's 11 GB SQLite integrity check runs as `discordsync-db-heal.service` (Type=oneshot, RemainAfterExit=true) with its own 10-min timeout — extracted from ExecStartPre so deploy activation isn't blocked by DB recovery during build storms.

### Build Cache SSD (`/mnt/buildcache`)

**Module:** `modules/nixos/services/buildcache.nix` — SanDisk SDSSDA240G (240 GB, SandForce SF-2000, DRAM-less) on USB 3.0, ext4 `noatime,lazytime,commit=120,data=writeback`, `nofail` + automount. Deployed 2026-08-14.

- **Purpose:** All rebuildable build caches live OFF the QLC NVMe — the ephemeral build churn (64 GB Go build cache, Rust targets, npm/pnpm) was a root contributor to the SLC-cache-exhaustion WDT crashes and the 93% disk crisis. ~115 GB of caches moved.
- **Consumers:** `GOCACHE`, `GOMODCACHE`, `GOLANGCI_LINT_CACHE`, `PIP_CACHE_DIR`, `PLAYWRIGHT_BROWSERS_PATH`, `npm_config_cache` (set in `platforms/nixos/users/home.nix` — NixOS ONLY, not darwin). `~/.cache/goimports`, `~/.cache/go`, and `~/.local/share/pnpm/store` are HM symlinks into the mount. Rust `target/` dirs: `snapshots.nix` symlinks `~/projects/<p>/target → /mnt/buildcache/rust/<p>` (via `services.buildcache.rustProjects`). **pnpm 11 ignores `npm_config_*` env vars AND .npmrc for `store-dir`** — the store is redirected via the `~/.local/share/pnpm/store` symlink instead (mechanism-independent). Env-var coverage only reaches processes started with the new session vars — long-lived pre-change processes kept writing the old NVMe paths until the source dirs were removed on 2026-08-14.
- **Device identification:** `/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1` — the kernel creates ata-serial by-id symlinks via SAT even though the USB bridge hides the model at the SCSI layer. Stable across sdb/sdc swaps between the two enclosures. SSD 2 (serial `174244451713`, btrfs) is earmarked for Docker storage.
- **Monitoring:** `buildcache-metrics` (every 5 min) writes `buildcache.prom` — mount presence, SMART health (`smartctl -d sat`), usage %. Gatus alerts on `buildcache_mounted`, `buildcache_smart_healthy`, usage >85%. The collector ALWAYS writes the .prom (even when the drive is absent) so a dead drive flips to 0 instead of serving stale greens. smartd monitors both SSDs with `-d sat`.
- **No TRIM through the USB bridge** (`lsblk -D` = 0B). If write perf degrades from stale-block pressure, reformat the drive — it's a cache (`mkfs.ext4 -L buildcache <device>`, then re-run `nix run .#migrate-buildcache` semantics).
- **Failure mode:** if the drive dies, builds fail with missing-directory errors until `GOCACHE`/`GOMODCACHE` are reverted in home.nix. Acceptable trade: Gatus alerts on Discord within minutes.
- **Corruption tolerance:** `data=writeback` + no PLP + SandForce SRAM means a dirty shutdown can corrupt cache entries. Go verifies content hashes itself; cargo/npm/pnpm just need a `clean`/`prune`. Never store anything irreplaceable here.
- **Old `/rust-cache` (nvme0n1p9, ext4):** its 32 GB `monitor365` target was copied to `/mnt/buildcache/rust/monitor365`; the partition itself is still mounted and awaits reclamation (TODO_LIST). The old cache subvolume automounts (`/home/lars/.cache`, `/home/lars/go`, `/home/lars/.npm`, `/home/lars/.cargo`) are now redundant — same reclaim batch (TODO_LIST).

---

## Critical Rules

- **Use flake commands** — `nix run .#deploy`, never raw `nixos-rebuild`/`darwin-rebuild`
- **Test first** — `nix flake check --no-build` (syntax) or `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel` (eval)
- **`trash` not `rm`**, **`git mv` not `mv`**, **2-space indentation**, **`config.allowBroken = false`**, **No OpenZFS on macOS** (kernel panics, ADR-003)
- **Open new terminal** after deploy (shell changes need new session)
- **Never hardcode** `localhost:PORT` — derive from config. All ports in `lib/ports.nix`, all images in `lib/images.nix`
- **Never silently substitute placeholder identity in git commits** — if `user.name`/`user.email` cannot be resolved, FAIL LOUD. Hardcoded `"Unknown Author"`/`"unknown@example.com"` fallbacks masked broken git config and produced ~6,400 unattributable commits. SystemNix's `services.projects-management-automation` sets `gitIdentity` which translates to `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env vars on the daemon — env precedence beats config lookup, so the daemon always has a valid identity. See `docs/gotchas-archive.md` for the full incident.

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
- **`builtins.toString null` = `""`** — Does NOT throw. `config.users.users.<name>.uid` is `null` at eval time for `isNormalUser`. NEVER use it in slice/service names without null-checking.
- **deadnix `--fix` removes lambda params** — Does NOT add `...` when removing all params. Verify output leaves `...` in patterns whose callers pass extra attrs.
- **catppuccin-gtk + Python 3.14** — Overlay in `overlays/shared.nix` pins `python312`. nixpkgs default python3 breaks the build script.
- **`nixos-unstable` not `nixpkgs-unstable`** — Hydra only caches expensive builds (ROCm, CUDA) on the `nixos-unstable` jobset.
- **`import ../../../lib/default.nix lib` boilerplate required** — Each module self-imports helpers because `nix flake check` evaluates modules standalone (no injected args).
- **nixpkgs tarball lock regression (root cause fixed)** — The global flake registry at `channels.nixos.org` contains `exact: true` entries that rewrite `nixpkgs(ref=nixos-unstable)` → `tarball:channels.nixos.org/nixos-unstable/nixexprs.tar.xz`. When `nix flake update` runs with `use-registries = true`, it consults these entries and rewrites the flake.lock nixpkgs node from `type: github` to `type: tarball`. Registry overrides MUST use the registry's own key format (`from = { id = "nixpkgs"; ref = "nixos-unstable"; }`) — a combined id string (`from.id = "nixpkgs/nixos-unstable"`) is a DIFFERENT key and silently fails. **Fix (configuration.nix):** (1) `nix.settings.flake-registry` points to a local empty JSON file (`builtins.toFile`), eliminating ALL global tarball entries; (2) correct-format system registry overrides. Same fix mirrored in `platforms/darwin/nix/settings.nix`. **Recovery script** (if regression recurs): `bash scripts/fix-nixpkgs-lock.sh` (NOT `nix run .#fix-nixpkgs-lock` — flake eval fails when lockfile is broken). Eval-time `nixpkgsTarballGuard` in flake.nix remains as last line of defense.
- **Go submodule `replace => ../../sibling` breaks transitive consumers** — Published Go submodules MUST use published versions, not local replaces. `mkPreparedSource` only strips top-level replaces.
- **Go vendorHash mismatches are FOD** — `nix flake check --no-build` does NOT catch them. Batch-test individual Go packages before full builds.
- **Dual cargo build paths need different `outputHashes` keys** — crane uses full git URL key; `importCargoLock` uses `package-version` key. Same hash value, different key format.
- **`__intentionallyOverridingVersion = true`** — nixpkgs warns when `overrideAttrs` changes `version` without changing `src`. Set this flag in the overrideAttrs attrset to silence the warning when intentionally version-shimming (e.g., the libdisplay-info shim for niri-flake).
- **`go mod tidy` in `preBuild` for mkPreparedSource** — When `mkPreparedSource` adds `replace` directives for private deps, the Go dep graph shifts and `go.sum` becomes stale. Adding `go mod tidy` to `preBuild` (safe with `proxyVendor = true`) regenerates `go.sum` automatically, avoiding "inconsistent vendoring" errors. Also add any new `subModules` (e.g., `testhelpers`, `testhelpers/graphtest` from go-output) so Go can resolve them from the nix store path.
- **NAR hash differs between `github:` tarball and `git+ssh:` fetch for same rev** — The same git commit produces DIFFERENT narHashes depending on fetch type: `github:` tarball normalizes file permissions (all 0644), while `git+ssh:` preserves git's executable bits. If a flake input is fetched via `git+ssh:` (e.g., due to `git insteadOf` pollution) and later switched to `github:`, the narHash changes. The nix daemon caches fetchTree results in MEMORY by (url, rev) — a stale cached hash from one fetch type causes "NAR hash mismatch" when the lock file specifies the other. **All LarsArtmann flake inputs MUST have `go-nix-helpers.follows = "go-nix-helpers"`** to avoid independent `git+ssh:` locked versions that diverge from the top-level `github:` fetch. **Daemon cache recovery:** When the daemon has a cached `git+ssh:` hash, BOTH `nix flake lock --update-input` AND `nix flake prefetch` return the STALE cached hash, not the GitHub tarball hash. `nix flake check --no-build` passes with the stale hash (daemon serves cached store path), but `nix fmt` or any operation that triggers a fresh GitHub fetch breaks. The ONLY fix is `sudo systemctl restart nix-daemon` to clear the in-memory cache, then `nix flake lock --update-input go-nix-helpers` to re-lock with the correct GitHub tarball hash. Without sudo access, the stale hash must be kept in flake.lock until the daemon is restarted. **Follows encoding issue:** `nix flake lock --update-input` does NOT re-encode `follows` overrides in the root node of flake.lock — only a full `nix flake lock` (no `--update-input`) processes all follows from flake.nix. If follows are missing from the lock file root node, consumer flakes use their own independent go-nix-helpers lock entries instead of the root's pin

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
- **`TimeoutStartSec` for ExecStartPre-heavy services** — systemd default is 90s. Services with slow pre-start (DB heal, DNS wait, state migration) exceed this during system switches (I/O contention). Set `TimeoutStartSec = "3min"` explicitly for discordsync (DB heal + DNS wait) and hermes (535 MB state migration). Without it, `nh os switch` reports "Failed to start" even though the service succeeds on retry.
- **`StartLimitBurst`/`StartLimitIntervalSec` in `serviceConfig` = SILENTLY IGNORED (CRITICAL)** — In systemd 261+, these directives are ONLY valid in the `[Unit]` section. Placing them in `serviceConfig` (which maps to `[Service]`) causes systemd to silently ignore them with a warning: `Unknown key 'StartLimitIntervalSec' in section [Service], ignoring`. Services with `Restart=on-failure` then restart INFINITELY with no limit. **Correct placement:** NixOS top-level options `systemd.services.<name>.startLimitBurst` / `.startLimitIntervalSec` (camelCase, outside `serviceConfig`), or `unitConfig.StartLimitBurst`. The `service-defaults.nix` helper documents this (lines 21-27); a full module audit confirmed zero current violations, but there is no eval-time guard yet.

- **systemd-oomd kills nix-daemon during builds** — nix-daemon is the top memory consumer under `/system.slice` during builds (4-8G peak). Because it is **socket-activated**, an oomd kill triggers rapid restarts → `start-limit-hit` → daemon permanently dead → ALL nix operations fail. Fix: `ManagedOOMPreference = "omit"` + `OOMScoreAdjust = -1000` (`networking.nix`). Recovery: `sudo systemctl reset-failed nix-daemon.service && sudo systemctl start nix-daemon.service`. Pressure threshold is 60%/30s — tolerates transient spikes from nix builds, AI model loads, and Docker restarts while still catching genuine exhaustion; per-slice `ManagedOOMMemoryPressureLimit` matches (60%). Re-evaluate if kills recur

### Caddy & Reverse Proxy

- **`handle_path` STRIPS prefix** — Use `handle` when backend expects full path.
- **`${commonConfig}` required on ALL vhosts** — Security headers, compression, `-Server` suppression. Auto-applied by `protectedVHost`; manual vhosts must include explicitly.
- **`proxyTo` is canonical** — ALL `reverse_proxy` directives use `${proxyTo PORT}`. Never bare `reverse_proxy` — it omits `X-Real-IP`.
- **`auto_https off`** — `:80` catch-all vhost handles HTTP→HTTPS redirect. TLS certs are sops-managed, not ACME.
- **`tlsConfig`** — Enforces TLS 1.2+. `strict_sni_host on` prevents serving certs for unrecognized hostnames.
- **Admin API (port 2019) intentionally unauthenticated** — Firewalled out (only 80/443 open). `admin off` would kill `/metrics`.
- **Native OIDC services use plain `reverse_proxy`** — NOT `protectedVHost`. Forward-auth + native OIDC = double-auth loop.

### SSO / OIDC

- **Native OIDC is NOT free** — Verify upstream support: Homepage (no auth), SigNoz (Enterprise-only, impersonation mode + Layer 2), Twenty (billing-gated), SearXNG (no accounts). All four stay on Layer 2 forward-auth.
- **SigNoz Layer 2 — never use unconditional forward-auth** — SigNoz uses `protectedVHost` (LAN bypass + external forward-auth). The previous unconditional forward-auth (no LAN bypass) caused 500 errors for ALL users when oauth2-proxy hiccuped. `protectedVHost` keeps LAN traffic off the oauth2-proxy path entirely, so oauth2-proxy failures only affect external access.
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

### ZRAM & Memory Reclaim

- **`vm.swappiness=150` for zram-only swap** — With zram as the ONLY swap, low swappiness tells the kernel to prefer page-cache reclaim (disk I/O on BTRFS/QLC NAND) over zram swap (in RAM) — this fed the recurring BTRFS I/O storms (`kworker/inode_switch_wbs` at 100% CPU, I/O PSI `full avg10=79%`). Correct range for zram-only: 100-200 (kernel docs: "for zram, use 100+")
- **ZRAM sizing for zram-only swap** — `memoryPercent=30` (~28 GiB). A too-small zram (was 17%/16 GiB) fills under normal load, and with no disk-swap fallback the kernel falls back to aggressive page-cache eviction = BTRFS disk I/O storms. At 3.2x zstd compression, 28 GiB costs ~8.7 GiB physical RAM while holding ~90 GiB original data — good trade on 94 GiB visible RAM
- **`vm.watermark_scale_factor=100`** — At 10 the kernel waits until memory is very low, then does aggressive synchronous "panic reclaim" I/O bursts. 100 (the default) starts reclaim earlier and gradually, avoiding sudden BTRFS writeback storms
- **`vm.dirty_ratio=5`, `vm.dirty_background_ratio=1` for QLC NAND** — 10% of 94 GiB = 9.4 GiB of dirty pages before forced writeback = huge writeback bursts on QLC NAND. 5%/1% spreads writes more evenly
- **`vm.vfs_cache_pressure=150`** — Prefers reclaiming dentry/inode cache (cheap, no disk I/O) over page cache (expensive, requires disk reads/writes)
- **zram compression ratio is ~3.2x live** — Measured via `/sys/block/zram0/mm_stat`. zstd level=1 is optimal (level 3 gains 1.7% ratio for 11.5% less speed)

### Docker & Containers

- **`oci-containers` backend defaults to Podman** — Set `backend = "docker"` when Docker is already enabled.
- **Docker 29.x `userland-proxy-path`** — `daemon.settings.userland-proxy = false`.
- **containerd bbolt corruption** — Recovery: stop docker → `mv meta.db meta.db.bak` → remove `containers/`/`containerd/`/`network/` dirs → restart.
- **systemd-oomd kills Docker containers under system-slice pressure (Twenty worker)** — Docker containers run as `docker-<id>.scope` under `/system.slice`. systemd-oomd picks the largest memory consumer to kill when system-slice pressure exceeds 50% for 20s. The Twenty worker (~856MB, largest container) was SIGKILL'd (exitCode=137) every ~15s: oomd kills → `restart: always` restarts → Node.js init spike → more pressure → oomd kills again → infinite loop (136 restarts in 40 min). Docker reports `OOMKilled: false` because systemd-oomd kills via cgroup signal, not Docker's own OOM handler. Fix: `mem_limit: "2g"` + `memswap_limit: "2g"` + `NODE_OPTIONS="--max-old-space-size=1536"` in the compose file. `ManagedOOMPreference=omit` canNOT be set on Docker scopes from NixOS (transient units). The nix-daemon oomd exemption reduces cascade pressure events, which indirectly reduces worker kills.

### DNS (dnsblockd)

- **dnsblockd is the SOLE DNS resolver on :53** — Replaces unbound entirely. Embedded sdns handles DNSSEC, DoT/DoH, local zones, blocklists.
- **`dnsIPv6Enabled = false`** — evo-x2 has no global IPv6. Omits IPv6 root servers, avoids 5-15s timeouts.
- **Wildcard `*.home.lan` does NOT resolve** — Only explicitly listed subdomains in `dnsLocal.localSubdomains` resolve. New service subdomains MUST be added.
- **`restartTriggers` on dnsblockd** — Without it, config changes may not restart the process → stale config → DNS outage.
- **`ProtectSystem=strict` + SQLite** — Needs `WorkingDirectory` alongside `StateDirectory` or CANTOPEN errors.
- **Manual `/etc/resolv.conf` edits break local DNS** — Nix config writes static resolv.conf with `127.0.0.1` first and `9.9.9.9` as fallback. Every deploy restores it. Do NOT reorder: `127.0.0.1` MUST be first so `*.home.lan` resolves via dnsblockd; `9.9.9.9` provides resilience when dnsblockd is down or slow
- **Dashboard auth token via sops env** — `auth_token` is passed via `DNSBLOCKD_AUTH_TOKEN` EnvironmentFile (koanf env override), NOT the nix-store config YAML. The sops secret `dnsblockd_auth_token` is owned by `primaryUser:users` so the DMS DnsStatsWidget can read it for its `Authorization: Bearer` header. The sops template `dnsblockd-auth-env` (root-owned) feeds the systemd EnvironmentFile. Two renderings of the same key, different owners, different consumers. Protected routes: `/stats`, `/api/allow`, `/api/report`, `/api/cache/flush`. Unprotected: `/health`, `/metrics`, `/dashboard`, `/api/dashboard-data` (cookie-gated).
- **HaGeZi blocklists come from the GitLab mirror** (`gitlab.com/hagezi/mirror`), NOT GitHub — GitHub's automated fraud detection repeatedly locks `hagezi/dns-blocklists` (404s all 22 fetch derivations, blocking every deploy). Lists track the mirror's mutable `main` branch with SRI-hash pinning: content drift fails the build loudly; fresh blocklists require periodic hash refreshes

### Monitor365

- **Package alias trap** — `pkgs.monitor365` = agent (CLI), NOT server. Server is `monitor365-server` (symlinkJoin with WASM UI).
- **No JIT SSO provisioning** — Users MUST be pre-provisioned via bootstrap or `create-admin` CLI. SSO login fails if email doesn't match existing user.
- **DuckDB not SQLite** — Uses `.duckdb` extension. `normalize_db_path` converts `.db` → `.duckdb` as safety net.
- **Daily event limit override** — `monitor365-schema-migrate` runs `UPDATE tenants SET max_events_per_day = 1000000000` on every boot. Do NOT remove — server re-syncs upstream default on bootstrap.
- **DuckDB WAL corruption self-heal** — `ExecStartPre` removes `.wal` on every startup (always means unclean shutdown). Restores from backup if main DB missing.
- **DuckDB pool deadlock watchdog** — `monitor365-server-watchdog` (every 5min) checks `/health` + counts "pool acquire failed" journal errors. `Restart=always` only covers process exit — degraded-but-alive states need active health probes. **Must use `journalctl --grep` + `-n` cap** — the naive `journalctl | grep -c` pattern serialized 270+ MB and burned 98% CPU every 5 minutes because it piped every journal entry through grep. `--grep` filters inside journalctl; `-n 21` enables early termination
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
- **DMS config split-brain** — Both `settings.json` and `plugin_settings.json` are HM-managed symlinks (NOT user-owned). DMS may replace the `settings.json` symlink with a real file at runtime (expanding 19 declarative keys to 530+ with defaults + UI changes). `deploy.sh` backs up real-file versions before `nh os switch` overwrites them. UI changes to either file are ephemeral — only declarative Nix settings survive rebuilds.
- **cliphist RETIRED** — DMS owns clipboard history exclusively.
- **Quickshell `Process` has NO `onFailed`** — Use `onStreamFinished` with text-length check.
- **ScriptModel UAF (unfixed upstream)** — Quickshell 0.3.0 + Qt 6.11.1 use-after-free in ScriptModel. Mitigation: `Restart=always` + `StartLimitBurst=30`.
- **SDDM hides boot logs** — `console=tty2` redirects boot messages. `Ctrl+Alt+F2` = full log.
- **Helium GPU SIGBUS** — `--disable-gpu-watchdog` in wrapper. Amplified by `--enable-zero-copy` + high GPUActive.
- **Helium zero-output death** — Niri has no virtual output support. When all outputs disconnect, Helium exits cleanly. `Restart=always` + `RestartSec=5`.
- **Helium video throttling (3 FPS)** — Missing anti-throttling flags caused Chromium to throttle video to 1-3 FPS when tab was backgrounded or scrolled out of view in niri. Four flags added: `--disable-background-timer-throttling`, `--disable-backgrounding-occluded-windows`, `--disable-renderer-backgrounding`, `--disable-background-media-suspend`. Brave/Darwin config already had the first three — they were never ported to Helium Linux.
- **helium-launch waits indefinitely** — No timeout (timeout caused empty-window loop). Becomes a monitor that blocks until existing instance dies.
- **Helium is Chromium 151** — Full ungoogled-chromium fork, NOT Electron. Widevine bundled separately.
- **VA-API flag renames (Chromium 131+)** — `VaapiVideoDecodeLinuxGL` → `AcceleratedVideoDecodeLinuxGL`, etc. Since 143+, VA-API works out of box; explicit flags are defense-in-depth.
- **`--disable-background-networking` kills extensions** — Blocks ExtensionDownloader. Do NOT re-add (Helium's ungoogled base already strips Google telemetry).
- **niri-flake libdisplay-info stale pin** — niri-flake's `make-niri` pins `libdisplay-info_0_2` via `callPackage` with `assert version == "0.2.0"`. nixpkgs removed that alias (it throws). niri's Cargo.lock uses `libdisplay-info-sys` 0.3.0 (requires C library `< 0.4.0` via pkg-config), but the real C library is 0.4.0 (backward compatible — APIs only added). The `niriLibdisplayInfoShim` overlay in `overlays/linux.nix` patches both: (1) derivation `version = "0.2.0"` to pass the assert, (2) `.pc` file `Version:` line via sed regex to `0.3.0` for pkg-config. Uses `__intentionallyOverridingVersion = true` to silence the nixpkgs warning. MUST be first in the overlay list (before niri's own overlay). Remove when niri-flake drops the pin.

### SearXNG

- **`enable` infinite recursion** — Wrapper MUST NOT set `services.searx.enable` inside `lib.mkIf cfg.enable` where `cfg = config.services.searx`.
- **No `restartTriggers` in direct server mode** — nixpkgs only sets them for uWSGI mode. SystemNix adds them.
- **Port 8889** (not 8888 — SigNoz OTel collector owns 8888).
- **Engine init never retried** — Engines that fail network during `init()` at boot stay permanently disabled. DNS-gate `mkDnsGate` in `ExecStartPre` ensures DNS is ready.
- **`formats = [ "html" ]`** — Blocks JSON API (403). Deliberate privacy hardening. Test in HTML mode.
- **`autocomplete = "duckduckgo"`** — Google leaked every keystroke.
- **XFF health-check noise is benign** — `/healthz` is exempt from limiter.

### Other Services

- **`pkgs.nss` is libs-only** — `certutil` is in `pkgs.nss.tools`.
- **ClickHouse `background_pool_size` sanity check trap** — Reducing `background_pool_size` below the default (16) triggers cascading `Code: 36 BAD_ARGUMENTS` startup sanity checks: every `number_of_free_entries_in_pool_*` merge_tree setting (defaults 20/8/25) must be less than `background_pool_size * background_merges_mutations_concurrency_ratio` (default 2), and each fails one-at-a-time (whack-a-mole through deploys). Keep `background_pool_size` at default. The other 4 pool reductions (`background_schedule_pool_size=8`, `background_buffer_flush_schedule_pool_size=4`, `background_move_pool_size=2`, `background_fetches_pool_size=1`) are safe — no sanity-checked dependents (~145 threads saved). An eval-time assertion in `signoz.nix` catches `background_pool_size=2`
- **ClickHouse `Type=notify` without sd_notify** — Upstream sets `Type=notify` but the binary never calls `sd_notify`. SystemNix overrides `Type=exec`. Remove when upstream adds sd_notify
- **PMA page-cache death-loop containment** — PMA reads 260+ git repos during discovery, charging ~16 GB of page cache to its cgroup. Without `MemoryHigh`, reclaim loops at 91% CPU (`memory.events max` climbing, `oom_kill = 0` — page cache is reclaimable) until system-wide PSI freezes the kernel. Contained by: `MemoryHigh=12G`, `MemoryMax=16G`, `CPUQuota=200%`, `MemorySwapMax=0`, `PMA_COMMITTER_WORKERS=2`, `PMA_DISCOVERY_WORKERS=2`, `ManagedOOMPreference=omit`. **Ceiling retuned 2026-08-14:** the 6G/8G ceiling from the 2026-08-09 analysis fell below the scan's grown working set — every restart pinned memory at ~6.3G in permanent direct reclaim and the discovery daemon goroutine starved (unix socket accepted connections, never answered; 3 hangs in one day, incl. a 21h one that 503'd Overview the whole time). 12G high restores scan headroom (pre-incident scans completed under a 16G max); 16G max keeps the freeze-proof hard bound. **`pma-daemon-watchdog`** (every 5 min) probes the daemon socket liveness and restarts PMA after 2 failed probes 30s apart — the hang class is "hung but active", invisible to systemd. Note: Overview has `partOf` PMA, so every PMA restart bounces Overview (it re-discovers on start). The `system-health` collector emits `system_service_memory_events_{max,high}` metrics with a Gatus "Memory Events Thrash" alert (collector runs as root with `ProtectSystem=full` — `/sys/fs/cgroup` unaffected). Full narrative: `docs/crash-analysis-2026-08-09.md`
- **Deploy generation mismatch** — `nix eval` may show correct values but deployed unit has STALE values. Deploy AGAIN if they differ.
- **Forgejo SSH keys** — Forgejo doesn't read NixOS `openssh.authorizedKeys.keys`. Provisioned via admin API (`forgejo-ssh-keys` oneshot).
- **Forgejo `GET /admin/users/{u}/keys` → 405** — Use public `GET /api/v1/users/{u}/keys` for dedup. POST stays on admin path.
- **OpenSEO GSC callback** — Hand-rolled Caddy vHost (NOT `protectedVHost`) to exempt `/api/gsc/oauth/callback` from forward-auth. Do NOT simplify.
- **Browser History: WebAuthn + OAuth2, direct TLS proxy** — Caddy uses plain `reverse_proxy` (NOT `protectedVHost`). Forward-auth would intercept WebAuthn/OAuth2 API calls and break registration/login. The app has built-in passkey auth PLUS native OAuth2/OIDC via Pocket ID. OTel uses gRPC (port 4317, NOT 4318) because the Go code uses `otlptracegrpc`, not `otlptracehttp`.
- **Browser History: LoadCredential for OIDC secret bridging** — The OIDC oneshot runs inside `ProtectSystem=strict` (from `harden {}`). It CANNOT read `/var/lib/pocket-id/client-secrets/browser-history` directly. Use `LoadCredential = [ "pocket-id-secret:${config.services.pocket-id.dataDir}/client-secrets/browser-history" ]` — systemd reads the file as PID 1 at service start, makes it available via `$CREDENTIALS_DIRECTORY/pocket-id-secret`. Same pattern as Forgejo (`forgejo.nix:302-303`).
- **Browser History: DynamicUser StateDirectory isolation** — When the server has `DynamicUser=true` + `StateDirectory=browser-history`, systemd creates `/var/lib/browser-history/` owned by a random dynamic UID (mode 0700). No other service can read or write there. The OIDC oneshot MUST use its own `StateDirectory=browser-history-oidc` to write the OAuth2 env file.
- **Browser History: upstream `optionalEnv` env-var split** — Upstream `optionalEnv "OAUTH2_POCKET_ID_CLIENT_ID" cfg.oauth2.pocketId.clientId` ALWAYS emits the env var as a systemd `Environment` directive when the module option is set, even if the client secret is missing. This triggers OAuth2 provider creation → `ProviderConfig.Validate()` rejects empty ClientSecret → crash-loop. Fix: do NOT set `clientId`/`issuer` via module options; route all 3 vars through the OIDC oneshot env file.
- **Browser History: agent→server startup race** — When server+agent are co-located (evo-x2), both restart simultaneously during deploy. The server is `Type=simple` (marked "active" before Go binds the port), the agent is `Type=oneshot` with only 4 retries per batch (~7s). The agent races ahead, gets 502 from Caddy, fails all 4 retries, exits 1, and blocks the deploy with "Activation (test) failed: exit status 4". Fix: `after = ["browser-history.service"]` + `wants` + `ExecStartPre` health-gate that polls `http://127.0.0.1:8087/health` with `curl --retry 30 --retry-delay 2` (60s max). `TimeoutStartSec=2min` for slow boot disk I/O.
- **Browser History: registration locked to single user** — `POST /auth/register` was open to anyone on LAN. Now gated by cqrs-htmx `ServiceConfig.MaxUsers` (0=unlimited, N=N users max). BOTH creation paths are gated: `Service.Register()` AND OAuth2 first-login auto-provisioning in `OAuth2Service.matchOrCreateUser` (a second user cannot be created via "Login with Pocket ID"; existing users always log in). Both return `ErrRegistrationClosed` (HTTP 403). The check-then-dispatch window is serialized by a shared registration mutex (TOCTOU-safe for in-process sync projections). browser-history exposes `MAX_USERS` env (default 1). SystemNix sets `MAX_USERS=1` explicitly. The `importUsers()` CSV path is NOT yet gated. Changing this requires deploying new cqrs-htmx + browser-history tags (includes a breaking `NewOAuth2Service` signature change) and bumping the flake input.
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
- **SigNoz journald receiver CPU burn** — The OTel collector's journald receiver spawns `journalctl --follow --output=json` as a subprocess. At `priority=info` with 14 units, this burned 96% CPU and 3.78 GB read continuously (monitor365-server alone generated 270 MB / 5 min). Fix: `priority=warning` + pruned unit list (dropped docker, postgresql, monitor365-server, projects-management-automation). Toggle via `services.signoz.components.journaldLogs`.
- **`journalctl | grep -c` is an IO trap** — Serializes every journal entry through a pipe. Use `journalctl --grep "pattern" --output cat | wc -l` instead — filters inside journalctl. Add `-n N` for early termination once N matches are found. Affected: monitor365-server-watchdog, niri-health-metrics (every 30s!), niri-health.sh, niri-drm-healthcheck.sh.
- **Post-deploy smoke test** — `nix run .#post-deploy-check` verifies functional outcomes, not just liveness. Hard FAILs on silent-zero regressions.
- **Prebuilt ELF binaries in Go modules break FOD purity** — Use `buildGoModule` with `subPackages` or vendor via `fetchurl`.
- **`*_templ.go` files MUST be committed** — Templ-generated Go files are required by Nix builds that vendor source without running `templ generate`. The global `~/.config/git/ignore` previously had `*_templ.go` (removed in `platforms/common/programs/git.nix`). Per-repo `.gitignore` patterns must also not ignore them. If a templ project fails to compile in Nix with "undefined: someFragment", check that the `*_templ.go` file is tracked by git.

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
