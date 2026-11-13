# Eval-time assertion: a unit's MemoryHigh (soft throttle watermark) must
# never sit far below its own MemoryMax (hard kill) — the llama-chat
# 2026-10-08 silent-throttle class (410M watermark under a 48G ceiling,
# 46k throttle events with the unit active and every liveness green).
#
# DELEGATED (2026-11-13, SUPERB wave A1b): the parseBytes/threshold walker
# (system units + user units + home-manager user services) and its
# allowUnits option live in the collection (github:LarsArtmann/nixos-modules,
# modules/memory-watermark-audit — a contract check + negative legs travel
# with it). This layer only imports it; evo-x2 consumes it via the
# modules/nixos auto-discovery map.
{
  inputs,
  ...
}: {
  flake.nixosModules.memory-watermark-audit = {
    imports = [inputs.nixos-modules.nixosModules.memory-watermark-audit];
  };
}
