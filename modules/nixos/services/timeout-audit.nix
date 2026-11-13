# Eval-time module: enforce a sane global DefaultTimeoutStartSec.
#
# DELEGATED (2026-11-13, SUPERB wave A1a): the module body lives in the
# collection (github:LarsArtmann/nixos-modules, modules/timeout-audit —
# contract check + negative legs travel with it). This layer only imports
# it; evo-x2 consumes it via the modules/nixos auto-discovery map.
#
# Why it exists: ExecStartPre scripts (DNS-gate waits, DB heal, secret
# checks, migrations) can hang on network issues or I/O contention. The
# systemd default (90s) is too short during system switches, causing exit
# code 4 and blocked deploys (discordsync, hermes, and 10 other services).
{
  inputs,
  ...
}: {
  flake.nixosModules.timeout-audit = {
    imports = [inputs.nixos-modules.nixosModules.timeout-audit];
  };
}
