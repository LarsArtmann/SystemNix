# Registry-matrix generator: renders the service matrix (markdown table)
# from eval truth — the docs-as-data companion to the integration manifest
# (plan T9, 2026-11-08). The committed table between the sentinels in
# docs/agents/integration-registry.md must be BYTE-IDENTICAL to this output;
# checks.registry-matrix-drift fails `nix flake check` on drift (the
# features-drift pattern: drift = red check, not stale prose).
#
# Columns: Service | Subdomain | Port | Layer | Unit | Checks | Backup
# Sources: services.catalog (what exists) + ENABLED services.integration
# (what runs here) — the same two surfaces the manifest merges, union view
# keyed by entry name (no subdomain join).
#
# Regenerate the committed table after any registry change:
#   nix build .#registry-matrix --print-out-paths && cat <path>
lib:
{
  catalog ? { },
  integration ? { },
}:
let
  enabledIntegration = lib.filterAttrs (_: e: e.enable or false) integration;

  dash = v: if v == null || v == "" then "—" else toString v;

  checkCount = e: if e.checks != [ ] then toString (builtins.length e.checks) else "—";

  row =
    name:
    let
      c = catalog.${name} or null;
      e = enabledIntegration.${name} or null;
    in
    "| ${name} | ${
      dash (
        if c != null then
          c.subdomain
        else if e != null then
          e.subdomain
        else
          null
      )
    } | ${
      dash (
        if c != null && c.port != null then
          c.port
        else if e != null && e.port != null then
          e.port
        else
          null
      )
    } | ${if e != null then e.vHost.layer else "—"} | ${
      if e != null then (if e.unit != null then e.unit else name) else "—"
    } | ${if e != null then checkCount e else "—"} | ${
      if e != null && e.backup != null then e.backup.directory else "—"
    } |";

  names = builtins.attrNames (catalog // enabledIntegration);

  header = ''
    <!-- BEGIN GENERATED SERVICE MATRIX — byte-exact contract owned by
         checks.registry-matrix-drift; regenerate: nix build .#registry-matrix --print-out-paths -->
    | Service | Subdomain | Port | Layer | Unit | Checks | Backup |
    | ------- | --------- | ---- | ------ | ---- | ------ | ------ |
  '';
in
''
  ${header}${lib.concatStringsSep "\n" (map row (lib.naturalSort names))}
  <!-- END GENERATED SERVICE MATRIX -->
''
