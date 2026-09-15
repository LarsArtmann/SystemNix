# mkIf-survivable shape for the `services.integration` registry — evaluation

**Date:** 2026-09-15 17:57 CEST
**Scope:** evaluation only — implementation is the pending row-551 owner decision (TODO_LIST).
**Deliverable for:** TODO row 547 (report `2026-09-15_11-05_window-closeout-fifth-run-delta-verification.md` §f.3).

## The proposed shape

Service modules currently declare their registry entry INSIDE the service `mkIf`:

```nix
# CURRENT (the co-import trap): options?-guard inside mkIf
config = lib.mkIf cfg.enable {
  # ...service config...
  services.integration = lib.optionalAttrs (options ? services.integration) {
    <name> = { monitored = true; /* ... */ };
  };
};
```

The proposed shape hoists the `optionalAttrs` guard OUT of the `mkIf` and gates
the entry's own `enable` field instead:

```nix
# PROPOSED (mkIf-survivable): guard outside mkIf, enable = cfg.enable inside
config = lib.mkMerge [
  (lib.mkIf cfg.enable {
    # ...service config, unchanged...
  })
  (lib.optionalAttrs (options ? services.integration) {
    services.integration.<name> = {
      enable = cfg.enable;   # the registry's own enabledEntries filter does the gating
      vHost.layer = "none";  # entry fields unchanged
      monitored = true;
    };
  })
];
```

Why it works: `optionalAttrs` is PLAIN Nix evaluated when the module's config
attrset is BUILT — when `integration.nix` is not imported, the branch is absent
from the config before the module system ever collects definitions. The current
shape's `services.integration = {}` definition sits inside a `mkIf`, and
`mkIf` conditions are resolved per-DECLARED-option at merge time — an
undeclared path errors during definition collection regardless of the condition
value.

## Evidence

Two probes, both run 2026-09-15 (expressions transient, tree untouched by the
bare-module probe; the real-module probe used the sanctioned atomic
backup→patch→eval→restore cycle, restore verified byte-identical + clean
`git status`):

### Probe 1 — bare `evalModules` matrix (8 cells)

| scenario                                    | current shape | proposed shape |
| ------------------------------------------- | ------------- | -------------- |
| integration declared + service enabled      | OK, entry lands | OK, entry `enable=true` |
| integration declared + service disabled     | OK, `{}` | OK, entry `enable=false` (fan-out inert via `enabledEntries`) |
| integration ABSENT + service enabled        | **ERROR** (the 11:05 class) | **OK** |
| integration ABSENT + service disabled       | **ERROR** | **OK** |

Note: the current shape errors even with the service DISABLED under a forced
(`deepSeq`) config evaluation — the AGENTS documents only the enable=true case;
definition collection does not care about the condition. Every test importing a
module with the current pattern needs the co-import even if it never enables
the service.

### Probe 2 — the REAL wifi-failover module

Harness: `<nixpkgs/nixos>` + the module's flake wrapper + `local-network.nix`,
`enable = true`, NO `integration.nix` co-import — exactly the 11:05 failure
scenario.

- Original module: `error: The option 'services.integration' does not exist. Definition values: ...` — the reported regression reproduced.
- Patched module (proposed shape): evaluates clean — `unitType = "simple"` (the
  unit is intact), `services.integration` correctly absent from config.

## Migration cost (if the owner picks the redesign)

- ~42 service modules carry the `optionalAttrs (options ? services.integration)`
  pattern (grep-verified 2026-09-15). The transform is mechanical: hoist guard
  out of `mkIf`, merge as a sibling branch, add `enable = cfg.enable`.
- **Per-entry review constraint:** with the new shape the entry VALUE is merged
  (and its fields evaluated by the submodule type) even when the service is
  disabled. Entry fields must reference only the module's own options (always
  declared) or static values — never config that exists only under `mkIf
  cfg.enable`. The 12 already-patched VM-test co-imports remain correct either
  way (co-import is harmless; it just stops being REQUIRED).
- The co-import convention needs no teardown: 12 test files, AGENTS rule, and
  `tests/test-integration.nix` stay valid; a migration would only make the
  guard line unnecessary.

## Recommendation

The proposed shape is sound and proven; the tradeoff is a one-shot ~42-module
sweep (with per-entry field review) against a convention that is already
landed, green, and costs one import line per new VM test. If the sweep is
deferred, the co-import convention remains coherent as-is; if adopted, new
modules should use the new shape immediately and the sweep can proceed
incrementally (both shapes coexist — each module migrates independently).
