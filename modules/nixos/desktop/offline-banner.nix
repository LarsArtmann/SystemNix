# Offline banner — yellow top-strip while offline. SystemNix wrapper around
# the upstream module.
#
# The upstream module (inputs.offline-banner.nixosModules.default,
# github:LarsArtmann/offline-banner — extracted from this file 2026-10-16 at
# v3 behavior: bar push-down animation, last-online caption, click-dismiss)
# provides every option (enable, package, checkIntervalSeconds, probeHost,
# probeTimeoutSeconds, failuresToShow, layerNamespace, and since 2026-11-10
# the tcpProbeHost/tcpProbePort/dnsProbeName/degradedDwellSeconds leg
# options) plus the systemd user service and the inline Quickshell QML. The
# OFFLINE_BANNER_* env vars stay the public runtime-tuning surface (drop-in
# retuning, demos). This file layers the SystemNix concerns: the live-parity
# layer namespace (systemnix:offline-banner — what the niri-msg-layers
# verification recipes grep) and the consumer-side env-contract pin (the
# resolved unit's PATH must actually carry the probe tools — the gen-995
# PATH-phantom live bug shipped through upstream's own name-grep check; a
# relock could re-import a drifted upstream invisibly to local eval).
# Deep context: docs/agents/desktop.md §Offline banner + the upstream repo's
# README/AGENTS; module debts (observability, VM test, IPv6 leg, demo mode)
# live in the upstream repo's TODO_LIST.
{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.offline-banner =
    {
      config,
      ...
    }:
    {
      imports = [ inputs.offline-banner.nixosModules.default ];

      config.services.offline-banner.layerNamespace = "systemnix:offline-banner";

      # Consumer-side pin (queue row 1453, executed 2026-11-10): the
      # RESOLVED unit's Environment must keep the probe contract — the env
      # keys the live recipes and drop-in docs name, and a PATH whose
      # getent actually resolves (gen-995 shipped pkgs.glibc where this
      # nixpkgs keeps getent as its own package; the dns leg failed all
      # 1448 probes while upstream's name-grep check stayed green).
      config.assertions = [
        {
          assertion =
            let
              env = config.systemd.user.services.offline-banner.environment;
              path = env.PATH or "";
              requiredKeys = [
                "OFFLINE_BANNER_INTERVAL"
                "OFFLINE_BANNER_PROBE_HOST"
                "OFFLINE_BANNER_PROBE_TIMEOUT"
                "OFFLINE_BANNER_FAILURES"
                "OFFLINE_BANNER_TCP_HOST"
                "OFFLINE_BANNER_TCP_PORT"
                "OFFLINE_BANNER_DNS_NAME"
                "OFFLINE_BANNER_DEGRADED_DWELL"
              ];
            in
            lib.all (k: lib.hasAttr k env) requiredKeys
            && lib.hasInfix "getent" path
            && lib.hasInfix "coreutils" path
            && lib.hasInfix "iputils" path;
          message = "offline-banner: the resolved unit lost the OFFLINE_BANNER_* env contract or its PATH cannot supply the probe tools (getent/coreutils/iputils — the gen-995 PATH-phantom class: the dns leg fails every probe)";
        }
      ];
    };
}
