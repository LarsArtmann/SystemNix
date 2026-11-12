# Runbook: docs/services/boot-mirror section in AGENTS.md ("Samsung boot
# mirror") + docs/agents/systemd.md#boot-mirror-samsung-2nd-boot-disk.
#
# DELEGATED to the collection module (inputs.nixos-modules.nixosModules.
# boot-mirror, repo github:LarsArtmann/nixos-modules — contract-checked in
# the collection's own checks.boot-mirror-contract + mutation-proven in its
# tests/negative/ harness): the sync script (bootctl install, loader-state
# reverse-propagation, rsync mirror, diff gate), the boot-mirror-sync
# service + path unit, the nofail mount, and the self-pinned contract
# assertions all live upstream. This file layers ONLY the SystemNix-specific
# concerns (collection-delegation recipe, docs/agents/integration-registry.md):
#   - enable + the Samsung ESP device (host fact: /dev/disk/by-uuid/4F53-C156,
#     PARTUUID 023f66c0-… — by-uuid because nvme enumeration flips across boots)
#   - system-health monitoring (unit-state only — the sync has no HTTP surface)
#
# Stays SystemNix-side by design: scripts/boot-mirror-activate.sh + the
# `boot-mirror-activate` flake app (the one-shot NVRAM switch is an operator
# decision, deliberately not a module option) and the pre-reboot-check §11
# boot-mirror gate (fleet boot-chain auditor).
{
  inputs,
  config,
  options,
  lib,
  ...
}: {
  imports = [inputs.nixos-modules.nixosModules.boot-mirror];

  config = {
    services.boot-mirror = {
      enable = true;
      device = "/dev/disk/by-uuid/4F53-C156"; # SAMSUNG-EFI (Samsung p1)
    };

    # Mirror staleness must be visible: a failed sync unit pages via the
    # standard notify-failure routing and shows in system-health (which also
    # catches the Condition-skipped-forever class via freshness checks).
    # Guarded: this layer is always co-evaluated with system-health on this
    # fleet, but the guard keeps the layer importable in isolated evals
    # (tests) where the option tree lacks it.
    services.system-health = lib.optionalAttrs (options ? services.system-health) {
      extraMonitoredServices = ["boot-mirror-sync"];
    };
  };
}
