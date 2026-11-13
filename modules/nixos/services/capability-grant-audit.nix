# Eval-time audit: CAPABILITY-GRANT CONFUSION on non-root units —
# CapabilityBoundingSet only LIMITS; AmbientCapabilities GRANTS. An
# ungranted DAC-class bounding entry on a User=/DynamicUser unit is dead
# weight and the service hits EACCES where its author expected access
# (geometrikks 2026-09-29→10-07: zero ingested events, /health 200).
#
# DELEGATED (2026-11-13, SUPERB wave A1b): the DAC-class walker and its
# allow option live in the collection (github:LarsArtmann/nixos-modules,
# modules/capability-grant-audit — a contract check + negative legs travel
# with it; tests/test-geometrikks-caps.nix keeps pinning the evo-x2 wiring
# through this lock). This layer only imports it.
{
  inputs,
  ...
}:
{
  flake.nixosModules.capability-grant-audit = {
    imports = [ inputs.nixos-modules.nixosModules.capability-grant-audit ];
  };
}
