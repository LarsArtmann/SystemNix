# ADR-008: Host-Independent Service Catalog Derivation

**Date:** 2026-09-23
**Status:** Accepted
**Supersedes:** the `platforms/common/dns-local.nix` shared hand-list (kept alive until the migration lands; see Consequences)
**Origin:** `docs/planning/2026-09-23_18-15_dynamic-service-mesh-registry.md` decision D1 (tasks T01–T08)

## Context

SystemNix's service-integration registry (`services.integration`,
`modules/nixos/services/integration.nix:113`) is **host-scoped by construction**:
every service module declares its entry inside its own `mkIf cfg.enable` block
(`integration.nix:18-19`, live example `cv.nix:828-846`), so the option's
_values_ exist only on hosts that (a) import the module and (b) enable the
service. There is no host-independent view of "what services exist on this
platform" — only per-host views of "what runs here".

The host topology is asymmetric, which makes this worse:

- **evo-x2** auto-discovers and imports ALL service modules
  (`flake.nix:810-830`, `systems/evo-x2.nix`).
- **rpi3-dns** imports an explicit SUBSET (integration, dns-failover, sops +
  audits — `systems/rpi3-dns.nix:45-67`); it is a minimal DNS-failover image
  where every module is deliberately listed.

Because rpi3-dns cannot see service declarations it does not import, the DNS
subdomain truth degraded into a shared hand-list
(`platforms/common/dns-local.nix`) that is:

1. duplicated into two host configs — `platforms/nixos/system/dns-blocker-config.nix:75-86`
   and `platforms/nixos/rpi3/default.nix:112-123`,
2. asserted against the registry at eval time (`integration.nix:46,391-407`)
   so a forgotten entry fails `nix flake check` instead of silently NXDOMAINing,

and every new service must touch a fourth file beyond its own module. The same
hand-wiring pattern repeats in the health-dashboard `remotes` list
(`health-dashboard.nix:50-62`, `configuration.nix:925-930`). This split-brain
is tracked at `ROADMAP.md:71`.

The driver (plan §2): derive `localRecords` on **both** DNS hosts from a single
platform-level source — keepalived failover must answer byte-identical
`home.lan` records from evo-x2 and rpi3-dns (VIP `192.168.1.53`).

## Decision

**Option A: a new host-independent `services.catalog` option, declared by the
service modules themselves, imported by ALL hosts.**

1. `flake.nixosModules.catalog` (`modules/nixos/services/catalog.nix`) declares
   `options.services.catalog.<name>` — `attrsOf (submodule …)` with the fields
   that describe _existence_, not _execution_: `subdomain`, `port`, `owner`,
   `description`, `healthPath` (extensible; T25 later adds `api`/`exports`/`slo`).
2. Each service module declares its catalog entry **unconditionally** — at the
   module's top-level config, OUTSIDE `mkIf cfg.enable`, in the proven guard
   shape `services.catalog = lib.optionalAttrs (options ? services.catalog) { … }`
   (same doctrine as the integration fan-outs, `integration.nix:375-386`).
   A disabled service still _exists_; only its runtime fan-out disappears.
3. "What runs here" stays in `services.integration` inside `mkIf cfg.enable`.
   The two options answer different questions and are kept adjacent in each
   service module.
4. **Both hosts import the full service-module set.** rpi3-dns gains the
   modules it currently skips — via evo-x2's auto-discovery (`moduleDirs`,
   `flake.nix:810-830`) if the desktop modules prove inert on aarch64, or via
   an explicit full-service-module list if they do not (T03 decides on eval
   evidence). This is the
   non-obvious load-bearing consequence: catalog entries live in the service
   modules, so a host that skips those modules cannot see the catalog.
   Importing the full set is safe because module files are inert-by-construction
   (guard-shaped, `mkIf cfg.enable` bodies) — that is already evo-x2's daily
   reality across ~49 modules.
5. Governance moves with it: `integration.nix`'s dns-local import + assertion
   (`:46,391-407`) is rewired to the catalog — an integration entry with a
   `subdomain` MUST have a catalog entry (error); a catalog entry without an
   integration entry lands on a warning list (declared-but-never-run is legal).
6. DNS derivation (T05) becomes: `localRecords` = catalog entries with
   `subdomain != null`, preserving today's apex + `*.home.lan` wildcard + zone
   boundary entries verbatim (`dns-blocker-config.nix:79-86`,
   `rpi3/default.nix:114-122`).

## Alternatives Considered

### B: flake cross-ref — `nixosConfigurations.evo-x2.config.services.integration`

Rejected, four independent reasons:

1. **Wrong semantics.** evo-x2's registry values are enablement-gated — they
   answer "what runs on evo-x2", not "what exists on the platform". Moving a
   service to another host would silently drop its DNS name.
2. **Recursion landmine.** rpi3 reading evo-x2 is acyclic _today_ only because
   nothing on evo-x2 reads rpi3 back. The moment an eval-time parity assertion
   (or any future derivation) crosses in the other direction, evaluation
   infinite-recurses through `nixosConfigurations`. B builds the trap into the
   foundation instead of a fence around it.
3. **Eval coupling.** Every rpi3-dns build would evaluate evo-x2's entire
   workstation config (home-manager, disko, all services) — any evo-x2
   eval breakage then breaks DNS-failover builds, the host you least want
   broken during an outage.
4. **Precedent is narrower than it looks.** `flake.nix:1140` already reads
   `inputs.self.nixosConfigurations.evo-x2.options` — but only _declarations_
   (`options ? disko`), which cannot trigger value merging or recursion. It is
   not license to read _values_ cross-config.

### C: keep the shared list + CI audit

Rejected: it _is_ the status quo, i.e. the split-brain this plan exists to
kill. The existing assertion catches drift only after both sides were
hand-edited, and every new service still requires a fourth-file edit. The audit
is not discarded, though — it is re-pointed at the catalog (Decision #5).

### D: codegen — generate `dns-local.nix` from the registry

Rejected without a matrix row: violates the plan's no-codegen-drift guardrail
(§2) — generated files go stale the moment someone edits them by hand. Eval-time
derivation is strictly fresher than any generator run.

## Consequences

**Positive**

- One declaration per service; DNS (and later hub federation, EventCatalog)
  derive from it. The fourth-file edit for "add a service" dies.
- The split-brain becomes structurally impossible: there is no second list
  left to drift.
- Byte-identical keepalived answers by construction — both hosts fold the same
  catalog into the same record shape (the dig-parity gate remains the
  runtime proof, per plan §2).

**Negative / accepted costs**

- rpi3-dns now evaluates ~49 service modules (eval time up; measured in T03's
  eval step). Mitigations: modules are inert without their `enable`; rpi3
  images are built from evo-x2, not on the Pi; if eval cost ever matters, a
  dedicated `nixosModules.catalog-only` import list is a contained follow-up.
- Two small blocks per service module (catalog + integration). Accepted: they
  answer different questions ("exists" vs "runs here") and the T04 assertion
  keeps them honest.
- New hosts MUST import the full module set or accept an incomplete catalog —
  recorded in the AGENTS registry section (T28).
- Untouched by design: guard-shape doctrine, port registry centrality
  (`lib/ports.nix`), VM-test co-import of `integration.nix`
  (`docs/todo/pipeline.md:115`), and every live-verification gate (dig parity,
  one-vHost-per-commit) from the plan's risk register.

## Verification

- `nix flake check` + VM tests green after each migration task (plan T07).
- Eval-level parity: the derived subdomain set equals the frozen
  `localSubdomains` list at migration time (assertion in T05, deleted in T06).
- Runtime dig parity against `192.168.1.53` / `.150` / `.151` before and after
  every activation (plan §10).
