# Eval-time audit: ReadWritePaths under /mnt/ WITHOUT mount gating
# (the 226/NAMESPACE + root-fs contamination class; full class narratives
# in the collection module header + docs/agents/systemd.md).
#
# DELEGATED (2026-11-13, SUPERB wave A1b): the two-class walker (ungated
# /mnt/ paths + dash-prefix-under-declared-mount) and its allowUnits option
# live in the collection (github:LarsArtmann/nixos-modules,
# modules/mount-gating-audit — a contract check + negative legs travel with
# it). This layer only imports it; evo-x2 consumes it via the
# modules/nixos auto-discovery map, and the fleet feeds
# services.mount-gating-audit.allowUnits at the host level (signoz's
# clickhouse exception).
{
  inputs,
  ...
}: {
  flake.nixosModules.mount-gating-audit = {
    imports = [inputs.nixos-modules.nixosModules.mount-gating-audit];
  };
}
