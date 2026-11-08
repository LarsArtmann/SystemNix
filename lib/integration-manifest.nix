# Integration-manifest builder: merges the two Nix-owned service registries
# plus the port allocator into ONE JSON blob that operational scripts consume
# (the "manifest bridge", plan T1 — docs/planning/2026-11-08 nix-native
# modernization). Nix stays the single owner of the data; scripts become pure
# consumers instead of hardcoding `localhost:PORT` literals that drift when a
# port moves (monitor365 9191→9421 class).
#
# Sources (never duplicated here):
#   services.catalog        "what EXISTS"  — port/healthPath/subdomain/description
#   services.integration    "what RUNS here" (enabled entries only) —
#                           unit/vHost.layer/monitored/checks
#   lib/ports.nix           the port allocator — logical name → number, so
#                           scripts reference PORT NAMES and a port move
#                           needs zero script edits
#
# Consumers:
#   modules/nixos/services/integration-manifest.nix (system.build + /etc)
#   scripts/post-deploy-check.sh (manifest loader; WARN-skips when absent)
#   checks.integration-manifest-shape-selftest (pins this contract on stub
#   data — extend THAT fixture when extending this shape)
#
# Merge semantics: per entry NAME. Catalog and integration usually key the
# same service differently (catalog "auth" vs integration "pocket-id"), so a
# name in only one surface appears with only that surface's fields; nothing
# is joined on subdomain (fragile) — the manifest is the UNION of both views.
#
# Check-URL resolution mirrors integration.nix's checkUrl EXACTLY (absolute
# URLs pass through verbatim; relative paths ride the integration entry's own
# port — the upstream checkWithoutPort assertion already guarantees a port
# exists whenever a relative check does). The shape-selftest pins this
# symmetry; if integration.nix's resolution ever changes, change both.
#
# Contract: every leaf must be JSON-serializable. assertJsonSafe throws
# naming the first offender's path, so a bad field fails EVAL (with a useful
# message) instead of a jq parse error at deploy time.
lib:
{
  catalog ? { },
  integration ? { },
  domain ? null,
  ports ? { },
}:
let
  enabledIntegration = lib.filterAttrs (_: e: e.enable or false) integration;

  resolveCheckUrl =
    e: check:
    if check.url != null then check.url else "http://127.0.0.1:${toString e.port}${check.path}";

  checkToJson =
    e: check:
    {
      inherit (check) name interval conditions;
      url = resolveCheckUrl e check;
    }
    // (lib.optionalAttrs (check.client ? timeout) { timeout = check.client.timeout; });

  catalogFields = c: {
    inherit (c)
      port
      healthPath
      subdomain
      description
      ;
  };

  integrationFields =
    name: e:
    {
      unit = if e.unit != null then e.unit else name;
      vHostLayer = e.vHost.layer;
      inherit (e) monitored;
      checks = map (checkToJson e) e.checks;
    }
    // (lib.optionalAttrs (e.port != null) { inherit (e) port; });

  # Union of both key sets; a name present in both gets both field groups
  # (no key overlaps between the two groups by construction).
  serviceEntry =
    name:
    (lib.optionalAttrs (catalog ? ${name}) (catalogFields catalog.${name}))
    // (lib.optionalAttrs (enabledIntegration ? ${name}) (
      integrationFields name enabledIntegration.${name}
    ));

  manifest = {
    inherit domain ports;
    services = lib.mapAttrs (name: _: serviceEntry name) (catalog // enabledIntegration);
  };

  # Walk the tree; throw with the full path of the first value toJSON could
  # not faithfully represent (functions are the realistic escapee; a path
  # also lands here because its string-context is lossy in JSON).
  assertJsonSafe =
    path: v:
    if
      v == null || builtins.isBool v || builtins.isInt v || builtins.isFloat v || builtins.isString v
    then
      true
    else if builtins.isList v then
      builtins.all (i: assertJsonSafe "${path}[${toString i}]" (builtins.elemAt v i)) (
        lib.range 0 (builtins.length v - 1)
      )
    else if builtins.isAttrs v then
      builtins.all (n: assertJsonSafe "${path}.${n}" v.${n}) (builtins.attrNames v)
    else
      throw "integration-manifest: non-JSON-serializable value at ${path} (type ${builtins.typeOf v}) — manifest fields must stay str/int/float/bool/null/list/attrs";

  safe = assertJsonSafe "manifest" manifest;
in
assert safe;
{
  inherit manifest;
  json = builtins.toJSON manifest;
}
