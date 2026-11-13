# Eval-time audit: every TCP port literal in systemd unit text must be a
# value from the port registry — the "never hardcode localhost:PORT"
# Critical Rule, finally ENFORCED instead of remembered.
#
# DELEGATED (2026-11-13, SUPERB T14): the module body lives in the
# collection (github:LarsArtmann/nixos-modules, modules/port-registry-audit
# — contract check + negative legs travel with it). This layer imports it
# and feeds the fleet registry; the evo-x2 host consumes it via the
# modules/nixos auto-discovery map, exactly as before (allowPorts consumers
# in service modules keep working unchanged).
#
# Fleet-agnostic change carried by the delegation: the collection module
# takes the registry as an OPTION (it never hardcodes fleet ports — the
# split contract, collection lib/README); this layer wires lib/ports.nix
# in, so registry membership + collision enforcement stay identical.
{
  inputs,
  ...
}: {
  flake.nixosModules.port-registry-audit = {
    imports = [inputs.nixos-modules.nixosModules.port-registry-audit];

    services.port-registry-audit = {
      enable = true;
      registry = (import ../../../lib/ports.nix).ports;
    };
  };
}
