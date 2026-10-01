# Service Integration, Registry & Module Conventions — Agent Reference

> Migrated verbatim from AGENTS.md on 2026-10-01 (restructure; one duplicated Gatus paragraph inside step 9 was collapsed).
> **Read when:** adding or significantly changing ANY service module, Caddy vHost, Gatus check, homepage tile, OIDC client, or consuming an upstream LarsArtmann NixOS module.

## Index

- [Adding a Service (full checklist)](#adding-a-service)
- [Auth/DNS Gate Helpers (`mkOidcGate` / `mkDnsGate`)](#authdns-gate-helpers-mkoidcgate--mkdnsgate)
- [Consuming LarsArtmann Flakes (DiscordSync/Monitor365 pattern)](#consuming-larsartmann-flakes-discordsyncmonitor365-pattern)
- [Module naming & shared lib helpers](#module-naming--shared-lib-helpers)

## Adding a Service

1. Create `modules/nixos/services/<name>.nix` (or `modules/nixos/desktop/` for desktop config) — filename IS the module name, auto-discovered. Filenames must be unique across both dirs. Prefix `_` for non-module helpers
2. Enable in `platforms/nixos/system/configuration.nix`
3. Ports go in `lib/ports.nix` — never hardcode
4. Import `import ../../../lib/default.nix lib` for `harden`, `serviceDefaults`, `onFailure`, `serviceTypes`, `ports`, etc.
5. Use `harden {} // serviceDefaults {}` for systemd. **Must** set `startLimitBurst = 5; startLimitIntervalSec = 300;` A global `DefaultTimeoutStartSec=3min` is set by `timeout-audit.nix` — individual services don't need per-service `TimeoutStartSec` unless they need a longer timeout (e.g. large DB migrations)
6. **Declare a `services.integration.<name>` entry in the service's own module** (see `modules/nixos/services/integration.nix` + `miniflux.nix` as the reference): one entry fans out to Caddy vHost (`vHost.layer = "plain"|"protected"|"none"`), Gatus checks, dashboard tile (the `homepage` field — historical name, consumed by the PapDashboard services tab via `services.papdashboard.extraTiles`), backup-coordination freshness, system-health monitored unit, OTel env + signoz-coverage, and Pocket ID client. The entry lives inside `lib.mkIf cfg.enable`, wrapped as `services.integration = lib.optionalAttrs (options ? services.integration) { <name> = {...}; }` (VM tests MUST co-import `integration.nix` — the options?-guard does NOT survive an enclosing `mkIf cfg.enable` with enable=true: the mkIf-wrapped empty def at the undeclared path still errors, flake-check-proven 2026-09-15). `subdomain` MUST also be in `platforms/common/dns-local.nix` (eval-time assertion). Do NOT hand-add rows in caddy.nix/gatus-config.nix/configuration.nix/system-health.nix/pocket-id.nix — the registry owns them. **Catalog entry (ADR-008, migrating 2026-09-23): the same module ALSO declares an unconditional `services.catalog.<name>` entry** (subdomain/port/owner/description/healthPath — "what exists", vs integration's "what runs here") via an inline `imports` module — see `cv.nix` as the reference. The catalog option lives in `nixosModules.catalog`; hosts/VMs importing a service module MUST co-import it (loud eval failure if missing — deliberate, no silent absence). Placement trap, flake-check-proven 2026-09-23: do NOT wrap inline-import definitions in `optionalAttrs (options ? ...)` (an empty attrset is still a definition → "option does not exist"), and do NOT evaluate `options` from an imports-position module (infinite recursion in the runNixOSTest driver fixpoint) — declare unconditionally and co-import instead. Until the migration completes, the catalog cross-check runs as an eval WARNING listing integration subdomains missing catalog entries; it hardens into an assertion when `platforms/common/dns-local.nix` is deleted (plan T05/T06)
7. `WatchdogSec` ONLY on services that send `WATCHDOG=1` via `sd_notify()` — Type=notify alone is NOT sufficient
8. For native OIDC SSO: declare the client via the registry entry's `oidc` field (`services.integration.<name>.oidc`, lands in `pocket-id-config.provision.extraOidcClients`), add a provisioning oneshot that reads the secret from `/var/lib/pocket-id/client-secrets/<clientId>` and configures the service via its CLI/API. Use `vHost.layer = "plain"` (direct TLS) — forward-auth + native OIDC causes double-auth loops. See Forgejo (`forgejo-oidc-setup`) as the reference pattern
9. **Add a Gatus health check via the registry entry's `checks` list** (migration complete 2026-09-15: gatus-config.nix keeps only infra/meta checks — DNS functional, node-exporter, cAdvisor, SigNoz*, Stuck D-State, Gatus self, Textfile Collector, Immich, Homepage; everything service-specific lives in the owning module). Registry check fields: `name`/`group`/`path` (relative to the entry's port) or `url` (absolute override — preserve the ORIGINAL string, `localhost` vs `127.0.0.1` matters for set-equality), `interval` (default 30s), `conditions` (default `["[STATUS] == 200"]`), `alert` (null = auto-generated "<name> down — <sub>.<domain> unreachable", `""` = deliberately silent). TCP/DNS raw-attrset checks stay in gatus-config.nix's core list. Add `[RESPONSE_TIME] < N` conditions for user-facing services (500ms-2s depending on service). Every new service MUST be monitored — silent failures are unacceptable. **Gatus `pat()` uses GLOB, not regex** — `?` is single-char wildcard (NOT optional quantifier), `+` is literal (NOT one-or-more). **`!` is ALSO literal** (no glob negation exists; negation only via the `!=` operator), and patterns are whole-string anchored. **`pat()` against a `/metrics` body matches HELP/TYPE comments too** — an asserted-1 condition `pat(*<metric> 1*)` silently matches the metric's own `# HELP <metric> 1 if ...` comment and stays green at ANY value (the 2026-08-22 phantom-green class). Use the anchored form: `[BODY] != pat(*<metric> 0\n*)` + `[BODY] == pat(*\n<metric> *)` — the `\n` MUST reach gatus as a REAL newline (single-backslash `\n` in a double-quoted Nix string; `pkgs.formats.yaml` round-trips it as a double-quoted scalar). A literal backslash-n (`\\n` in Nix source) is filepath.Match's ESCAPE for the letter 'n' and can NEVER match any body — 2026-08-22: 7 deployed checks permanently red for hours from exactly this. The `gatus-pattern-lint` flake check rejects all three trap classes automatically: `?`/`+` in `pat()`, bare `pat(*<metric> 1*)`, and literal `\\n` inside `pat()` — since 2026-09-14 the scan covers ALL module files (registry-era: conditions are authored in service modules, not just gatus-config.nix); pre-deploy-check §10 mirrors them at deploy time. Full check-design patterns (anchored pats, freshness composites, liveness-vs-health, the alert-description charset rule): [monitoring.md → Gatus Health Check Design Patterns](./monitoring.md#gatus-health-check-design-patterns)
10. **For OTLP tracing**: set `OTEL_EXPORTER_OTLP_ENDPOINT` in the service environment. Go services: `localhost:4318` (no scheme). Rust: `http://localhost:4317` (with scheme, gRPC). Python: `http://localhost:4318`. Docker: `http://host.docker.internal:4318`. The env var is a noop if the upstream binary lacks OTel instrumentation — see DiscordSync as the reference. `otel-endpoint-audit.nix` enforces this at eval time (gRPC 4317 ⇒ scheme REQUIRED, host allowlist, port registry; register new services in its `expectations` attrset). **ALWAYS register the unit in `services.signoz-coverage.expected`** (signoz-coverage.nix) — the eval-time reverse assertion rejects any unit carrying the env var without a registry entry, and the runtime collector alerts when a registered service's spans go dark. `wiring = "upstream"` marks known instrumentation gaps (visible, non-paging). Do NOT add `siteMonitor` to Homepage tiles — Gatus owns all health alerting
11. **For backup-producing services**: declare `backup = { directory, filePattern, maxAgeHours }` in the registry entry (the service module still owns the backup unit/timer). Stagger schedules (01:00, 02:00, 02:30, 03:00) to avoid IO spikes

## Auth/DNS Gate Helpers (`mkOidcGate` / `mkDnsGate`)

Services that need the OIDC stack (Pocket ID + DNS + TLS) or DNS resolution at boot MUST use the shared helpers from `lib/default.nix` instead of hand-rolling curl/getent scripts. Both return a `{ after, wants, serviceConfig.ExecStartPre }` fragment that merges into `systemd.services.<name>`.

**`mkOidcGate`** — probes `https://auth.${domain}/.well-known/openid-configuration` via curl (300s budget, TLS verified). Verifies the full chain: DNS → TLS → HTTP. Use for any service consuming native OIDC or oauth2-proxy. **The budget is 300s because dnsblockd needs ~2min at boot** to load its 3.9M-entry blocklist before answering `*.home.lan` (2026-08-31: the old 120s budget expired 3s before DNS went ready — oauth2-proxy + gatus + browser-history all failed into OnFailure Discord alerts, then self-healed 5s later). Consumers MUST set their unit's `TimeoutStartSec ≥ 6min` (all four current consumers do).

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

**`mkDnsGate`** — probes DNS resolution via `getent hosts <hostname>`. Use for services that need DNS at init time but don't depend on OIDC (e.g., SearXNG engine init). Supports `fatal = false` for non-blocking warnings. **Default budget 180s since 2026-08-31** (was 120s — dnsblockd needs ~2min at boot to load its blocklist mapping, same measured boot that broke the OIDC gate's old budget).

```nix
dnsGate = mkDnsGate { inherit pkgs; serviceName = "my-svc"; hostname = "wikidata.org"; fatal = false; };
```

**`includeProvision`** (default `true`) — adds `pocket-id-provision.service` to after/wants. Set to `false` for services that don't need provisioned OIDC clients.

## Consuming LarsArtmann Flakes (DiscordSync/Monitor365 pattern)

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

**Upstream plain-priority serviceConfig keys REQUIRE `lib.mkForce` downstream (CPUQuota trap, eval-proven 2026-09-25).** When an upstream nixos-module declares a `serviceConfig` key at plain (no priority) — e.g. go-cqrs-lite's `nixos-module.nix` renders `CPUQuota = "100%"` verbatim — that plain value BEATS harden{}'s `mkDefault` layering, and a downstream `CPUQuota = "200%"` silently evals to `100%` in the rendered unit. Prove priorities with `nix eval .#nixosConfigurations.<host>.config.systemd.services.<svc>.serviceConfig.CPUQuota` BEFORE trusting an override, and override with `lib.mkForce` plus a comment naming the upstream declaration site (DiscordSync: `modules/nixos/services/discordsync.nix`, upstream `nixos-module.nix:233`). Same class applies to any upstream-declared key (MemoryMax, RestartSec): plain beats mkDefault.

Reference implementations: `modules/nixos/services/monitor365.nix` (gold standard), `modules/nixos/services/discordsync.nix` (converged to the pattern).

## Module naming & shared lib helpers

- **`-config` suffix is intentional** — `services.audio-config.enable` avoids colliding with upstream `services.pipewire` etc.
- **`wrapWithMemoryLimit` helper** — `lib/default.nix` creates `-memlimit` wrappers for dev commands (go-test-memlimit, cargo-test-memlimit, etc.).
- **DynamicUser eval-time assert** — `dynamic-user-audit.nix` cross-references DynamicUser services with sops secrets at eval time. Catches ANY DynamicUser service, not just hardcoded names.
- **NixOS VM tests** — `tests/default.nix` uses `pkgs.testers.runNixOSTest`. `mock-sops.nix` + `test-helpers.nix` provide common mocks.
- **In VM tests, extra mounts MUST be declared as `virtualisation.fileSystems`, not `fileSystems`** — qemu-vm.nix replaces the WHOLE `fileSystems` option via `mkVMOverride` (priority 900, applied whenever `virtualisation.fileSystems != {}`, which is always) so a plain `fileSystems."/mnt/x"` entry silently VANISHES from the guest fstab (no eval error — the mount unit just 'could not be found'). Guest-side bootstrap units that must run before a mount: `wantedBy/before = local-fs.target` + explicit `before = [ "mnt-x.mount" ]` (a mount waiting on a by-label device whose label only exists post-mkfs is a chicken-and-egg — format BEFORE local-fs, `udevadm settle` after). **test-cv FIXED 2026-09-02**: converted to `virtualisation.fileSystems` + a REAL btrfs pool disk (pool-fmt unit, `findmnt -o FSTYPE` assertion) — before that, its `fileSystems."/mnt/pool"` never mounted and every cv-backup assertion ran against a root-fs shadow directory (green but weaker than believed).
