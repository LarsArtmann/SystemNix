# Eval-time audit: GATUS MONITORING COVERAGE — the "every service MUST be
# monitored" doctrine, finally ENFORCED instead of remembered.
#
# DELEGATED (2026-11-13, SUPERB T15): the module body lives in the
# collection (github:LarsArtmann/nixos-modules, modules/gatus-coverage-audit
# — contract check + negative legs travel with it). This layer imports it
# and feeds the fleet registry; hosts consume it via the modules/nixos
# auto-discovery map, exactly as before (allowPorts exemption consumers in
# fastflowlm/llama-vlm/systemd-graph keep working unchanged).
#
# Fleet-agnostic change carried by the delegation: the collection module
# takes the registry as an OPTION (same map as port-registry-audit) and
# reads whatever services.gatus the consumer declares; this layer wires
# lib/ports.nix in, so both audit directions stay identical.
{
  inputs,
  ...
}:
{
  flake.nixosModules.gatus-coverage-audit = {
    imports = [ inputs.nixos-modules.nixosModules.gatus-coverage-audit ];

    services.gatus-coverage-audit = {
      enable = true;
      registry = (import ../../../lib/ports.nix).ports;
    };
  };
}
