# Offline banner — yellow top-strip while offline. SystemNix wrapper around
# the upstream module.
#
# The upstream module (inputs.offline-banner.nixosModules.default,
# github:LarsArtmann/offline-banner — extracted from this file 2026-10-16 at
# v3 behavior: bar push-down animation, last-online caption, click-dismiss)
# provides every option (enable, package, checkIntervalSeconds, probeHost,
# probeTimeoutSeconds, failuresToShow, layerNamespace) plus the systemd user
# service and the inline Quickshell QML. The OFFLINE_BANNER_* env vars stay
# the public runtime-tuning surface (drop-in retuning, demos). This file
# layers ONLY the SystemNix concern: the live-parity layer namespace
# (systemnix:offline-banner — what the niri-msg-layers verification recipes
# grep). Deep context: docs/agents/desktop.md §Offline banner + the upstream
# repo's README/AGENTS; module debts (observability, VM test, IPv6 leg,
# demo mode) live in the upstream repo's TODO_LIST.
{ inputs, ... }: {
  flake.nixosModules.offline-banner =
    { ... }:
    {
      imports = [ inputs.offline-banner.nixosModules.default ];

      services.offline-banner.layerNamespace = "systemnix:offline-banner";
    };
}
