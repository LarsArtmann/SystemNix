# Eval-time assertion: StartLimitBurst/StartLimitIntervalSec must NEVER live in
# serviceConfig (systemd 261+ silently ignores them there — Restart=on-failure
# services restart infinitely while their author believes a limit exists).
#
# DELEGATED (2026-11-13, SUPERB wave A1a): the assertion walker lives in the
# collection (github:LarsArtmann/nixos-modules, modules/start-limit-audit —
# contract check + negative legs travel with it). This layer only imports it;
# evo-x2 consumes it via the modules/nixos auto-discovery map.
{
  inputs,
  ...
}: {
  flake.nixosModules.start-limit-audit = {
    imports = [inputs.nixos-modules.nixosModules.start-limit-audit];
  };
}
