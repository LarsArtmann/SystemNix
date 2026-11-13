# Eval-time assertion: no unit may glob-delete /tmp/* inline without
# excluding systemd-private-* (the 2026-08-18..30 forgejo 12-day mirror
# outage class — deleting PrivateTmp backing dirs makes every file creation
# inside the unit's private /tmp fail ENOENT, self-perpetuating).
#
# DELEGATED (2026-11-13, SUPERB wave A1a): the assertion walker lives in the
# collection (github:LarsArtmann/nixos-modules, modules/tmp-cleaner-audit —
# contract check + negative legs travel with it). This layer only imports it;
# evo-x2 consumes it via the modules/nixos auto-discovery map. The behavioral
# half (the REAL tmp-cleanup unit preserving aged systemd-private dirs) stays
# SystemNix-side in tests/test-tmp-cleanup.nix + the scheduled-tasks.nix
# self-assertion.
{
  inputs,
  ...
}:
{
  flake.nixosModules.tmp-cleaner-audit = {
    imports = [ inputs.nixos-modules.nixosModules.tmp-cleaner-audit ];
  };
}
