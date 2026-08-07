# Eval-time assertion: services with ExecStartPre MUST have TimeoutStartSec.
#
# ExecStartPre scripts (DNS-gate waits, DB heal, secret checks, migrations) can
# hang indefinitely on network issues or I/O contention. Without TimeoutStartSec,
# the systemd default (90s) applies — but during system switches with I/O
# contention, 90s is not enough, causing exit code 4 and blocked deploys.
#
# This audit catches any future service that adds ExecStartPre without
# TimeoutStartSec, before it can cause a deploy failure.
#
# Bug class history: discordsync (DB heal + DNS wait), hermes (535MB state
# migration), and 10 other services that silently failed on every deploy.
_:
{
  flake.nixosModules.timeout-audit =
    {
      lib,
      config,
      ...
    }:
    let
      servicesWithExecStartPre = lib.filterAttrs (
        _name: svc:
        let
          execStartPre = svc.serviceConfig.ExecStartPre or null;
        in
        execStartPre != null
      ) config.systemd.services;

      missingTimeout = lib.filterAttrs (
        _name: svc: (svc.serviceConfig.TimeoutStartSec or null) == null
      ) servicesWithExecStartPre;

      violators = builtins.attrNames missingTimeout;
    in
    {
      config.assertions = map (name: {
        assertion = false;
        message = ''
          systemd service "${name}" has ExecStartPre but no TimeoutStartSec.
          ExecStartPre scripts can hang on DNS waits, DB migrations, or I/O
          contention. The systemd default (90s) is too short during system
          switches, causing exit code 4 and blocked deploys.
          Fix: add TimeoutStartSec = "3min" to the serviceConfig.
        '';
      }) violators;
    };
}
