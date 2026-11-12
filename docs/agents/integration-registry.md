# Service Integration, Registry & Module Conventions — Agent Reference

> Migrated verbatim from AGENTS.md on 2026-10-01 (restructure; one duplicated Gatus paragraph inside step 9 was collapsed).
> **Read when:** adding or significantly changing ANY service module, Caddy vHost, Gatus check, homepage tile, OIDC client, or consuming an upstream LarsArtmann NixOS module.

## Index

- [Adding a Service (full checklist)](#adding-a-service)
- [Manifest Bridge — how scripts consume eval truth](#manifest-bridge--how-scripts-consume-eval-truth)
- [Auth/DNS Gate Helpers (`mkOidcGate` / `mkDnsGate`)](#authdns-gate-helpers-mkoidcgate--mkdnsgate)
- [Consuming LarsArtmann Flakes (DiscordSync/Monitor365 pattern)](#consuming-larsartmann-flakes-discordsyncmonitor365-pattern)
- [Module naming & shared lib helpers](#module-naming--shared-lib-helpers)

## Adding a Service

1. Create `modules/nixos/services/<name>.nix` (or `modules/nixos/desktop/` for desktop config) — filename IS the module name, auto-discovered. Filenames must be unique across both dirs. Prefix `_` for non-module helpers
2. Enable in `platforms/nixos/system/configuration.nix`
3. Ports go in `lib/ports.nix` — never hardcode. Operational SCRIPTS never hardcode either: consume `/etc/systemnix/integration-manifest.json` (see [Manifest Bridge](#manifest-bridge--how-scripts-consume-eval-truth) below); `script-port-audit.nix` fails eval on unregistered host-form port literals in `scripts/`
4. Import `import ../../../lib/default.nix lib` for `harden`, `serviceDefaults`, `onFailure`, `serviceTypes`, `ports`, etc.
5. Use `harden {} // serviceDefaults {}` for systemd. **Must** set `startLimitBurst = 5; startLimitIntervalSec = 300;` A global `DefaultTimeoutStartSec=3min` is set by `timeout-audit.nix` — individual services don't need per-service `TimeoutStartSec` unless they need a longer timeout (e.g. large DB migrations)
6. **Declare a `services.integration.<name>` entry in the service's own module** (see `modules/nixos/services/integration.nix` + `miniflux.nix` as the reference): one entry fans out to Caddy vHost (`vHost.layer = "plain"|"protected"|"none"`), Gatus checks, dashboard tile (the `homepage` field — historical name, consumed by the PapDashboard services tab via `services.papdashboard.extraTiles`; **tile coverage is ENFORCED at eval time since 2026-10-25: any entry with a `subdomain` MUST carry a `homepage` tile** — eval fails otherwise; a registry tile with `icon = null` WARNS (owner directive: cosmetic gap, warn don't fail — §16 pre-deploy remains the hard monogram block); defaults keep authoring one line: `homepage = { icon = "forgejo.png"; }` with `name` derived from the subdomain, `group` defaulting to `"Services"`, `href` derived; a genuinely tile-less web service opts out with `noDashboardTile = true;` + justification comment, cf. `papdashboard.nix` — carrying BOTH the flag and a `homepage` tile fails eval, the pair is a contradiction). For FIRST-PARTY services, check the product checkout for brand/logo assets and a served route BEFORE reaching for the generic icon pack (crush-daily serves its own brand mark at /favicon.svg; absolute-URL icons have precedent — opencloud.nix; 2026-10-27), backup-coordination freshness, system-health monitored unit, OTel env + signoz-coverage, and Pocket ID client. The entry lives inside `lib.mkIf cfg.enable`, wrapped as `services.integration = lib.optionalAttrs (options ? services.integration) { <name> = {...}; }` (VM tests MUST co-import `integration.nix` — the options?-guard does NOT survive an enclosing `mkIf cfg.enable` with enable=true: the mkIf-wrapped empty def at the undeclared path still errors, flake-check-proven 2026-09-15). `subdomain` MUST also be in `platforms/common/dns-local.nix` (eval-time assertion). The reverse direction is enforced too (2026-10-25): a HAND-ROLLED caddy vHost with no registry entry fails eval (caddy.nix `registryBlindSubdomains` table carries the justified exceptions) — registering the service is the preferred fix. Do NOT hand-add rows in caddy.nix/gatus-config.nix/configuration.nix/system-health.nix/pocket-id.nix — the registry owns them. **Catalog entry (ADR-008, migrating 2026-09-23): the same module ALSO declares an unconditional `services.catalog.<name>` entry** (subdomain/port/owner/description/healthPath — "what exists", vs integration's "what runs here") via an inline `imports` module — see `cv.nix` as the reference. The catalog option lives in `nixosModules.catalog`; hosts/VMs importing a service module MUST co-import it (loud eval failure if missing — deliberate, no silent absence). Placement trap, flake-check-proven 2026-09-23: do NOT wrap inline-import definitions in `optionalAttrs (options ? ...)` (an empty attrset is still a definition → "option does not exist"), and do NOT evaluate `options` from an imports-position module (infinite recursion in the runNixOSTest driver fixpoint) — declare unconditionally and co-import instead. Until the migration completes, the catalog cross-check runs as an eval WARNING listing integration subdomains missing catalog entries; it hardens into an assertion when `platforms/common/dns-local.nix` is deleted (plan T05/T06). **Tile icon (2026-10-17): set `homepage.icon` to a homarr-labs/dashboard-icons pack FILE NAME** (e.g. `"miniflux.png"` — verified against the pinned pack; an absolute http(s) URL also works). A wrong name fails the toplevel BUILD naming the icon + pack path, and a non-pack/non-URL form fails EVAL — the tile renders a monogram only when you deliberately leave `icon` null
7. `WatchdogSec` ONLY on services that send `WATCHDOG=1` via `sd_notify()` — Type=notify alone is NOT sufficient
8. For native OIDC SSO: declare the client via the registry entry's `oidc` field (`services.integration.<name>.oidc`, lands in `pocket-id-config.provision.extraOidcClients`), add a provisioning oneshot that reads the secret from `/var/lib/pocket-id/client-secrets/<clientId>` and configures the service via its CLI/API. Use `vHost.layer = "plain"` (direct TLS) — forward-auth + native OIDC causes double-auth loops. See Forgejo (`forgejo-oidc-setup`) as the reference pattern
9. **Add a Gatus health check via the registry entry's `checks` list** (migration complete 2026-09-15: gatus-config.nix keeps only infra/meta checks — DNS functional, node-exporter, SigNoz*, Stuck D-State, Gatus self, Textfile Collector, Immich, Homepage; everything service-specific lives in the owning module). Registry check fields: `name`/`group`/`path` (relative to the entry's port) or `url` (absolute override — preserve the ORIGINAL string, `localhost` vs `127.0.0.1` matters for set-equality), `interval` (default 30s), `conditions` (default `["[STATUS] == 200"]`), `alert` (null = auto-generated "<name> down — <sub>.<domain> unreachable", `""` = deliberately silent). TCP/DNS raw-attrset checks stay in gatus-config.nix's core list. Add `[RESPONSE_TIME] < N` conditions for user-facing services (500ms-2s depending on service). Every new service MUST be monitored — silent failures are unacceptable. **Gatus `pat()` uses GLOB, not regex** — `?` is single-char wildcard (NOT optional quantifier), `+` is literal (NOT one-or-more). **`!` is ALSO literal** (no glob negation exists; negation only via the `!=` operator), and patterns are whole-string anchored. **`pat()` against a `/metrics` body matches HELP/TYPE comments too** — an asserted-1 condition `pat(*<metric> 1*)` silently matches the metric's own `# HELP <metric> 1 if ...` comment and stays green at ANY value (the 2026-08-22 phantom-green class). Use the anchored form: `[BODY] != pat(*<metric> 0\n*)` + `[BODY] == pat(*\n<metric> *)` — the `\n` MUST reach gatus as a REAL newline (single-backslash `\n` in a double-quoted Nix string; `pkgs.formats.yaml` round-trips it as a double-quoted scalar). A literal backslash-n (`\\n` in Nix source) is filepath.Match's ESCAPE for the letter 'n' and can NEVER match any body — 2026-08-22: 7 deployed checks permanently red for hours from exactly this. The `gatus-pattern-lint` flake check rejects all three trap classes automatically: `?`/`+` in `pat()`, bare `pat(*<metric> 1*)`, and literal `\\n` inside `pat()` — since 2026-09-14 the scan covers ALL module files (registry-era: conditions are authored in service modules, not just gatus-config.nix); pre-deploy-check §10 mirrors them at deploy time. Full check-design patterns (anchored pats, freshness composites, liveness-vs-health, the alert-description charset rule): [monitoring.md → Gatus Health Check Design Patterns](./monitoring.md#gatus-health-check-design-patterns)
10. **For OTLP tracing**: set `OTEL_EXPORTER_OTLP_ENDPOINT` in the service environment. Go services: `localhost:4318` (no scheme). Rust: `http://localhost:4317` (with scheme, gRPC). Python: `http://localhost:4318`. The env var is a noop if the upstream binary lacks OTel instrumentation — see DiscordSync as the reference. `otel-endpoint-audit.nix` enforces this at eval time (gRPC 4317 ⇒ scheme REQUIRED, host allowlist, port registry; register new services in its `expectations` attrset). **ALWAYS register the unit in `services.signoz-coverage.expected`** (signoz-coverage.nix) — the eval-time reverse assertion rejects any unit carrying the env var without a registry entry, and the runtime collector alerts when a registered service's spans go dark. `wiring = "upstream"` marks known instrumentation gaps (visible, non-paging). Do NOT add `siteMonitor` to Homepage tiles — Gatus owns all health alerting
11. **For backup-producing services**: declare `backup = { directory, filePattern, maxAgeHours }` in the registry entry (the service module still owns the backup unit/timer). Stagger schedules (01:00, 02:00, 02:30, 03:00) to avoid IO spikes

## Manifest Bridge — how scripts consume eval truth

**Rule: scripts NEVER hardcode `localhost:PORT` — they consume eval truth via
`/etc/systemnix/integration-manifest.json`.** The manifest
(`modules/nixos/services/integration-manifest.nix`, builder in
`lib/integration-manifest.nix`) merges `services.catalog` + enabled
`services.integration` + the whole `lib/ports.nix` registry into one JSON
file baked into every NixOS generation:

```json
{
  "domain": "home.lan",
  "ports":   { "pocket-id": 1411, ... },
  "services": { "<name>": { "port": …, "healthPath": …, "unit": …, "vHostLayer": …, "checks": [...] } }
}
```

Why a file and not `nix eval`: the etc file ALWAYS matches the deployed
generation (it IS part of it), while `nix eval` measures the tree — which
drifts mid-deploy — and costs 30-90s per invocation.

**Consumer pattern** (post-deploy-check.sh's `m_port` is the reference):

```bash
MANIFEST_PATH="${SYSTEMNIX_MANIFEST:-/etc/systemnix/integration-manifest.json}"
# degrade: absent manifest = WARN + SKIP, never FAIL
p="$(jq -r --arg n pocket-id '.ports[$n] // empty' <"$MANIFEST_PATH")"
curl "http://localhost:${p}/healthz"
```

Contracts:

- **Degrade loudly, never block**: absent/unparseable manifest → WARN +
  section SKIP. An old generation running a new-tree script must not fail
  a deploy.
- **Reference port NAMES**, not numbers — a port move (monitor365
  9191→9421) needs zero script edits; the manifest is rebuilt per
  generation.
- **Unregistered hardcodes fail eval** (`script-port-audit.nix`): the gate
  caught verify-deployment.sh probing gatus at the retired 9110 for 12
  days on its first sweep (2026-11-08).
- **Shape is pinned** by `checks.integration-manifest-shape-selftest`
  (fixture data; extend THAT when extending the builder) + a build-time
  jq validation in the derivation's checkPhase.
- The builder mirrors `integration.nix`'s checkUrl resolution exactly —
  change one, change both (the fixture pins the parity).

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

**Probe-before-lock (codified 2026-10-19, PapDashboard CI retirement):** before ANY `nix flake lock --update-input <larsartmann-input>`, BUILD the target rev outside the lock first — `nix build github:LarsArtmann/<repo>/<rev>#<pkg>` (or the local checkout's `path:` flake) — and only re-lock on green. Upstream repos auto-commit AND auto-push through an UNVALIDATED channel (the daemon pushed both a break and its fix inside one hour, 2026-09-30), and upstream CI cannot be assumed alive (PapDashboard's was billing-dead 2026-07-15 → 2026-10-19, then retired). The SystemNix lock is the ONLY verified gate in the chain: a blind `--update-input` imports whatever the daemon last pushed. A FOD mismatch at the probe = shim protocol (`lib/lars-packages.nix` flakePkgShim), never a blind lock.

Reference implementations: `modules/nixos/services/monitor365.nix` (gold standard), `modules/nixos/services/discordsync.nix` (converged to the pattern), `modules/nixos/services/mr-sync.nix` + `modules/nixos/services/nsfw-classifier.nix` (delegated 2026-11-08 — nsfw is the reference for delegating while keeping deployment-only sub-units (immichScan) and neutralizing upstream unit-config bugs). Full own-project upstreaming audit + classification matrix: `docs/status/2026-11-08_03-15_own-project-module-upstreaming-audit-two-delegations.md`.

### Extraction recipe: hand-rolled module → upstream `nixosModules`

Distilled from nsfw-classifier 2026-10-18 + mr-sync/nsfw-classifier 2026-11-08. Follow in order; step 0 and step 1 are stop-gates.

0. **Premise-probe the repo before planning the wave.** Verify against the INPUT URL (flake.nix), not the local checkout: `git remote get-url origin` in the checkout, ahead-count vs `@{upstream}`, and whether the flake exports `nixosModules` **at the LOCKED rev** (lock rev ≠ checkout HEAD). Live premise failures (2026-11-08): hermes-agent's input is THIRD-PARTY `github:NousResearch/hermes-agent` (no LarsArtmann fork exists — "just push it" was meaningless; its module also sits on newer upstream revs only), and nsfw-classifier's fix depended on the daemon's push channel. An "own-project" classification must be proven from the input URL.
1. **Inventory with a stop-gate.** Mark every block of the SystemNix module UPSTREAM-PORTABLE (options, unit shape, portable defaults, package wiring, generic hardening) vs SYSTEMNIX-LAYER (sops templates, `lib/ports.nix`, ioTier, onFailure, integration/gatus/catalog entries, gates — mkDnsGate/mkOidcGate/calm/mount — host users/paths, operational heal/verify units, workspace docs, credential helpers). If the portable set is small OR the deployment philosophies conflict (upstream renders config declaratively vs the service owns its state — the hermes case), STOP: that is an upstream-first wave (cvagent-class), not an extraction.
2. **Extract upstream** in the product repo: options + unit + portable hardening only, SystemNix specifics OUT, portable defaults as overridable options (never host paths). Option namespace == the product's.
3. **Upstream verification**: the repo's own eval/checks (`nix flake check` inside the repo; add a `checks` entry or VM test when a harness exists — Code-To-CV-Agent `nix/vm-test.nix` is the seam).
4. **Push + probe-before-lock** (see above): build the target rev outside the lock; re-lock only on green. FOD mismatch → shim protocol, never a blind lock. Rev-POLICY pins (crm: "re-roll this rev per pin wave") get re-rolled to the new rev; LIFT-condition pins (journal: "compiles at tip") verify the condition first, then drop pin AND its `lib/flake-input-pin-audit.nix` allowlist row together.
5. **Delegate**: SystemNix module becomes `imports = [ inputs.X.nixosModules.<name> ];` + `lib.mkIf cfg.enable` layering ONLY the step-1 SYSTEMNIX-LAYER set. `mkDefault` for anything upstream may own; `mkForce` only where SystemNix must win — upstream PLAIN-priority serviceConfig keys beat `mkDefault` (CPUQuota trap, above).
6. **Expect the eval audits on first switch** — fix by layering SystemNix-side, source-fix upstream when it is a real upstream bug: io-tier-coverage on NEW upstream units (esp. boot-started oneshots → layer `ioTier.background`), systemd-shape classes (oneshot+Restart; class-9 unitConfig-vs-serviceConfig section traps → `mkForce null` neutralizer SystemNix-side + upstream fix, cf. nsfw `TimeoutStartSec`), timeout floors (`mkDefault "5min"` on new oneshots), port-registry literals, memory-watermark coherence, deploy-restart oneshot coverage.
7. **Rendered-unit parity (the hard gate)**: baseline = last commit WITHOUT your marker (`git log -S "<marker>" --format=%h | tail -1` — never HEAD~N), worktree at that rev, render every affected unit both sides (`nix eval .#nixosConfigurations.evo-x2.config.systemd.services.<unit> --json`), `diff <(jq . < old.json) <(jq . < new.json)`. Every hunk byte-identical or an intended documented delta. The 2026-11-08 delegations caught 3 silently-dropped harden bounds (CPUQuota/MemoryHigh/ProtectHostname) this way.
8. **Close out**: tick `docs/todo/upstream.md`, CHANGELOG entry, runbook header (`docs/services/<svc>.md`) owning-module line, reference-implementation list above when it becomes one.

### Collection delegation recipe: pattern module → `github:LarsArtmann/nixos-modules`

Sibling of the recipe above, distilled from the W1 pilot (wifi-failover, 2026-11-11/12) + W2 (boot-mirror). For project-LESS pattern modules (no owning product repo) — the collection batches them (`modules/<name>/` auto-discovered as `nixosModules.<name>` PATH references; never import-applied, or options.json provenance dies).

1. **Extract into the collection** (`modules/<name>/{default.nix,README.md,script}` + a check in `tests/`): every fleet fact becomes an option (`device`, paths, feeds); the spine comes from the collection's `import ../../lib lib` — **call convention is POSITIONAL `lib`, not `{inherit lib;}`** (the wrapper-attrset mistake cost 6 eval rounds in W1). Unit names stay EXACTLY as the fleet knew them (audits, selftests, negative legs, and runbooks reference them). Collection code uses plain/mkDefault only — mkForce is a consumer right.
2. **Untracked files are INVISIBLE to flake eval** (git-archive source semantics): `git add` new collection files BEFORE any eval/check claims "module missing". Same trap as the evo-x2 tracked-files class.
3. **Fail-on-bug-shape legs move WITH the module** (`tests/negative/run.sh`, the copy-mutate-prove harness ported from `scripts/negative-test-lints.sh`). Mutation targets must trip the CHECK's hardcoded expectations — a self-referential module assertion (expected-value and pathConfig rendered from the SAME expression) is immune to single-string seds: the mutation changes both sides (phantom-green). SystemNix-side: retire the moved legs (a sed on this tree is a no-op = phantom leg) but KEEP the host-eval selftest — it evals the delegated config through the lock, so a collection regression cannot slip past unnoticed.
4. **Push + probe-before-lock**: `nix build github:LarsArtmann/nixos-modules/<rev>#checks.x86_64-linux.<check>` from GitHub, then `nix flake update nixos-modules`. Lock budget: the input stays +1 node (nixpkgs + treefmt-nix follow ours).
5. **Delegation layer** replaces the SystemNix file in place (same import path; `inputs` is in specialArgs, so even `platforms/` files can import collection modules directly — no `flake.nixosModules.<name>` wrapper shape needed outside the auto-discovery tree): `imports = [ inputs.nixos-modules.nixosModules.<name> ];` + enable + the fleet facts + integration/monitoring entries. Registry entries stay fleet-side ALWAYS: an `options ? services.integration` guard cannot survive `mkIf cfg.enable` with enable=true (2026-09-15 lesson) — the layer is co-evaluated with integration.nix, use `lib.optionalAttrs (options ? …)` for isolated-eval portability.
6. **Parity, the W2 refinements**: capture the baseline BEFORE any edit (`~/.cache/parity/<name>-before-{svc,path,fs}.json`), SAME-LOCK where possible (a parallel lock float between baseline and after-tree rehashes every store path — semantically strip `/nix/store/[a-z0-9]{32}-` and diff); `path` units need `--apply` to select JSON-able fields (the full attrset dies in serialization). Build-level proof: `diff -r` the two ExecStart store trees — same-version runtimeInputs rehash + (documented) comment/description deltas are the acceptable classes; ANY executable-line delta is a blocker.
7. **Ordering**: parity green → delete the superseded SystemNix source (script/module body) → deploy at a 4×60s quiescent window → anchor by generation NUMBER → passive smoke (journalctl markers), never a prod-mutating probe.

Reference implementations: `modules/nixos/services/wifi-failover.nix` (W1, registry-entry-at-layer) + `platforms/nixos/system/boot-mirror.nix` (W2, platform-file layer with device fact + system-health guard).

## Module naming & shared lib helpers

- **`-config` suffix is intentional** — `services.audio-config.enable` avoids colliding with upstream `services.pipewire` etc.
- **`wrapWithMemoryLimit` helper** — `lib/default.nix` creates `-memlimit` wrappers for dev commands (go-test-memlimit, cargo-test-memlimit, etc.).
- **DynamicUser eval-time assert** — `dynamic-user-audit.nix` cross-references DynamicUser services with sops secrets at eval time. Catches ANY DynamicUser service, not just hardcoded names.
- **NixOS VM tests** — `tests/default.nix` uses `pkgs.testers.runNixOSTest`. `mock-sops.nix` + `test-helpers.nix` provide common mocks.
- **In VM tests, extra mounts MUST be declared as `virtualisation.fileSystems`, not `fileSystems`** — qemu-vm.nix replaces the WHOLE `fileSystems` option via `mkVMOverride` (priority 900, applied whenever `virtualisation.fileSystems != {}`, which is always) so a plain `fileSystems."/mnt/x"` entry silently VANISHES from the guest fstab (no eval error — the mount unit just 'could not be found'). Guest-side bootstrap units that must run before a mount: `wantedBy/before = local-fs.target` + explicit `before = [ "mnt-x.mount" ]` (a mount waiting on a by-label device whose label only exists post-mkfs is a chicken-and-egg — format BEFORE local-fs, `udevadm settle` after). **test-cv FIXED 2026-09-02**: converted to `virtualisation.fileSystems` + a REAL btrfs pool disk (pool-fmt unit, `findmnt -o FSTYPE` assertion) — before that, its `fileSystems."/mnt/pool"` never mounted and every cv-backup assertion ran against a root-fs shadow directory (green but weaker than believed).

## Service Matrix (generated — do not hand-edit)

The table below is GENERATED from eval truth on every `nix flake check`
(`checks.registry-matrix-drift`, the features-drift doctrine); hand edits
drift red. Regenerate after any registry change:
`nix build .#registry-matrix --print-out-paths && cat <path>`.

<!-- BEGIN GENERATED SERVICE MATRIX — byte-exact contract owned by
     checks.registry-matrix-drift; regenerate: nix build .#registry-matrix --print-out-paths -->
| Service | Subdomain | Port | Layer | Unit | Checks | Backup |
| ------- | --------- | ---- | ------ | ---- | ------ | ------ |
| ai-meter | — | 8107 | none | ai-meter | 2 | — |
| alerts | alerts | — | — | — | — | — |
| architecture-catalog | catalog | — | protected | architecture-catalog-sync | 3 | — |
| attic | cache | 8200 | plain | attic | 2 | — |
| audible-sync | — | — | none | audible-sync | — | — |
| auth | auth | 1411 | — | — | — | — |
| backup-coordination | — | — | none | backup-coordination | 1 | — |
| bank-sync | banksync | 8097 | protected | bank-sync | 4 | — |
| browser-history | history | 8087 | plain | browser-history | 3 | /mnt/pool/backups/browser-history |
| browser-history-agent | — | — | none | browser-history-agent | — | — |
| btrfs-balance-watch | — | — | none | btrfs-balance-watch | 1 | — |
| buildcache | — | — | none | buildcache | 4 | — |
| caddy | — | — | none | caddy | — | — |
| crm | crm | 8091 | — | — | — | — |
| crm-server | crm | 8091 | plain | crm-server | 1 | /mnt/pool/backups/crm |
| crowdsec | — | 8082 | none | crowdsec | 1 | — |
| crush-daily | daily | 8081 | protected | crush-daily | 1 | /mnt/pool/backups/crush-daily |
| crush-events | — | — | none | crush-events-collector | 1 | — |
| cv | cv | 8098 | plain | cv | 10 | /mnt/pool/backups/cv |
| cvagent | cvagent | 8787 | protected | cvagent | 2 | — |
| discordsync | discordsync | 8085 | protected | discordsync | 4 | /mnt/pool/backups/discordsync |
| dmarc-monitor | — | — | — | — | — | — |
| dnsblock | dnsblock | — | — | — | — | — |
| dnsblockd | dnsblockd | — | none | dnsblockd | 4 | /mnt/pool/backups/dnsblockd |
| emeet-pixyd | emeet-pixyd | 8090 | protected | emeet-pixyd | 2 | — |
| file-and-image-renamer | renamer | 8086 | protected | file-and-image-renamer | 2 | — |
| forgejo | forgejo | 3000 | plain | forgejo | 5 | /mnt/pool/backups/forgejo |
| gatus | status | 9410 | plain | gatus | — | — |
| geometrikks | geo | 8102 | plain | geometrikks | 1 | /mnt/pool/backups/geometrikks |
| gotenberg | — | — | none | gotenberg | — | — |
| health-dashboard | health | 8103 | protected | health-dashboard | 2 | — |
| hermes | — | — | none | hermes | — | — |
| immich | immich | 2283 | protected | immich | — | /mnt/pool/services/immich/database-backup |
| inboxclean | inbox | 8099 | protected | inboxclean | 6 | /mnt/pool/backups/inboxclean |
| indexer-web | index | 8105 | protected | indexer-web | 2 | — |
| invoices-dashboard | invoices | 8110 | protected | invoices-dashboard | 2 | /mnt/pool/backups/invoices |
| journal-serve | journal | 8484 | protected | journal-serve | 1 | — |
| lan-nic-watchdog | — | — | none | lan-nic-watchdog | — | — |
| llama-embeddings | — | — | none | llama-embeddings | — | — |
| llama-rag | — | — | none | llama-rag | 2 | — |
| mail-relay | — | — | none | postfix | 3 | — |
| mail-server | — | — | — | — | — | — |
| media-atlas | map | 8493 | plain | media-atlas | 4 | /mnt/pool/backups/media-atlas |
| miniflux | rss | 8101 | plain | miniflux | 2 | /mnt/pool/backups/miniflux |
| monitor365 | — | — | none | monitor365 | 2 | — |
| monitor365-server | monitor | 3001 | none | monitor365-server | 5 | /var/lib/monitor365-server |
| mr-sync-dashboard | mr-sync | 7331 | protected | mr-sync-dashboard | 1 | — |
| netbird | — | 51820 | none | netbird | 1 | — |
| nix-daemon | — | — | none | nix-daemon | — | — |
| nsfw | nsfw | 8104 | — | — | — | — |
| offsite-borg | — | — | none | borgbackup-job-hetzner | 1 | /var/lib/borg-offsite |
| opencloud | cloud | 9500 | plain | opencloud | 2 | — |
| openseo | seo | 3002 | none | openseo | 1 | — |
| overview | overview | 8083 | protected | overview | 1 | — |
| papdashboard | dash | 8088 | protected | papdashboard | 2 | — |
| paperless | paperless | 2892 | none | paperless | 1 | /mnt/pool/services/paperless/export |
| paperless-consumer | — | — | none | paperless-consumer | — | — |
| paperless-db | — | — | none | paperless-db | — | /mnt/pool/backups/paperless |
| paperless-gpt | — | 8106 | — | — | — | — |
| paperless-scheduler | — | — | none | paperless-scheduler | — | — |
| paperless-task-queue | — | — | none | paperless-task-queue | — | — |
| paperless-triage | — | — | none | paperless-triage | 2 | /var/lib/paperless-triage |
| paperless-web | — | — | none | paperless-web | — | — |
| pbx | — | — | — | — | — | — |
| pbx-backup-pull | — | — | none | pbx-backup-pull | — | /mnt/pool/backups/pbx |
| pbx-lens | — | — | — | — | — | — |
| pim-sync | — | — | — | — | — | — |
| pocket-id | auth | — | none | pocket-id | 2 | /mnt/pool/backups/pocket-id |
| pool-recovery | — | — | none | pool-recovery | 1 | — |
| pool-smart-metrics | — | — | none | pool-smart-metrics | 3 | — |
| projects-management-automation | — | — | none | projects-management-automation | 2 | — |
| projects-subvol | — | — | none | projects-subvol | 1 | — |
| restic-app-dumps | — | — | none | restic-app-dumps | — | /mnt/pool/backups/restic-app-dumps |
| rust-cache | — | — | none | rust-cache | 2 | — |
| searxng | search | 8889 | protected | searxng | 1 | — |
| seo | seo | 3002 | — | — | — | — |
| signoz | signoz | 8080 | protected | signoz | 3 | /mnt/pool/backups/clickhouse |
| storage-collector-freshness | — | — | none | storage-collector-freshness | 1 | — |
| storage-history | — | — | none | storage-history | — | /mnt/pool/backups/restic-storage-history |
| system-health | — | — | none | system-health | 43 | — |
| systemd-graph | graph | 8847 | plain | systemd-graph | 1 | — |
| systemd-timer-monitor | timers | — | none | systemd-timer-monitor | 1 | — |
| taskchampion-sync-server | tasks | 10222 | none | taskchampion-sync-server | — | — |
| tasks | tasks | 10222 | — | — | — | — |
| tika | — | — | none | tika | — | — |
| timesheets | timesheets | 8109 | protected | timesheets | 2 | /mnt/pool/backups/timesheets |
| tq-agent-pool | — | — | none | tq-agent-pool | 1 | — |
| tq-bootstrap | — | — | none | tq-bootstrap | — | — |
| tq-serve | tq | 8100 | protected | tq-serve | 1 | — |
| visionreviewd | — | — | none | visionreviewd | — | — |
| webphone | — | — | — | — | — | — |
| wifi-failover | — | — | none | wifi-failover | — | — |
<!-- END GENERATED SERVICE MATRIX -->
