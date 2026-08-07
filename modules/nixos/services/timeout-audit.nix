# Eval-time module: enforce a sane global DefaultTimeoutStartSec.
#
# ExecStartPre scripts (DNS-gate waits, DB heal, secret checks, migrations) can
# hang on network issues or I/O contention. The systemd default (90s) is too
# short during system switches, causing exit code 4 and blocked deploys.
#
# This module sets a global DefaultTimeoutStartSec=3min via systemd.settings.Manager,
# covering ALL services — upstream nixpkgs modules, external flakes, and SystemNix
# modules alike. Per-service TimeoutStartSec overrides still win when set.
#
# Bug class history: discordsync (DB heal + DNS wait), hermes (535MB state
# migration), and 10 other services that silently failed on every deploy with
# exit code 4 because the 90s systemd default expired under I/O contention.
_: {
  flake.nixosModules.timeout-audit =
    { lib, ... }:
    {
      config.systemd.settings.Manager.DefaultTimeoutStartSec = lib.mkDefault "3min";
    };
}
