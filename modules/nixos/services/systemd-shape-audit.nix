# Eval-time audit: INVALID or RACY systemd unit SHAPES that systemd itself
# either refuses to load or accepts while silently arming a failure cascade —
# ten bug classes, all with live incident history (oneshot+invalid-Restart,
# timer+Restart≠no, PathExists path units, literal $HOME in user-unit Exec
# lines, script options nested in serviceConfig, shared RuntimeDirectory,
# unbounded boot-blocking oneshots, OnFailure in serviceConfig,
# [Service]-keys-in-unitConfig, is-active probes vs oneshots). Full class
# narratives: docs/agents/systemd.md gotchas + the collection module header.
#
# DELEGATED (2026-11-13, SUPERB wave A1a): the 10-class walker + its four
# allow* options live in the collection (github:LarsArtmann/nixos-modules,
# modules/systemd-shape-audit — a contract check pinning all ten class
# detections + negative legs travel with it). This layer only imports it;
# evo-x2 consumes it via the modules/nixos auto-discovery map, and the
# fleet-file mutation legs in scripts/negative-test-lints.sh (shapeaudit
# group) keep proving the HOST integration end-to-end through this lock.
{
  inputs,
  ...
}: {
  flake.nixosModules.systemd-shape-audit = {
    imports = [inputs.nixos-modules.nixosModules.systemd-shape-audit];
  };
}
