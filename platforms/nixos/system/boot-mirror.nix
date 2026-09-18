# Samsung 970 EVO Plus as 2nd boot disk — full ESP mirror of /boot.
#
# Layout after this module (design: docs/planning/2026-09-18_19-53_SAMSUNG-2ND-BOOT-DISK-PARETO-PLAN.md):
#   QLC p7 (by-uuid 80A3-73A9)  -> /boot        NixOS-managed ESP (sd-boot builder writes here)
#   Samsung p1 (SAMSUNG-EFI)    -> /boot-mirror verified byte-mirror + bootctl-installed loader
#
# /nix already lives on the Samsung (by-label tlc, subvol nix) — so once the
# firmware boots the Samsung ESP, the whole boot chain (loader, kernel,
# initrd, init, store) is off the QLC; only the root @ subvolume stays on it.
#
# Why a mirror unit instead of nixpkgs `mirroredBoots`: that option is
# grub/generic-extlinux-only in the locked nixpkgs (verified 2026-09-18) —
# systemd-boot has no declarative mirror. The builder writes /boot only;
# this unit keeps the Samsung ESP current on every deploy (deploy.sh
# provisioner restart — stc never restarts oneshot+RemainAfterExit) and at
# boot (wantedBy multi-user).
#
# The FIRMWARE switch (EFI entry + BootOrder) is deliberately NOT automatic:
# run `nix run .#boot-mirror-activate` once — it creates the boot entry and
# orders the Samsung first, leaving every QLC entry as fallback. Reboots on
# this box are deliberate events; NVRAM order must not fight the operator.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ../../../lib/default.nix lib)
    harden
    onFailure
    serviceOneshotDefaults
    ;
  mkFilesystem = import ../../../lib/filesystems.nix lib;

  mirrorPath = "/boot-mirror";

  # rsync to vfat: --no-owner/--no-group/--no-perms because FAT cannot store
  # unix ownership (chown would EPERM under harden{}'s empty cap set) and the
  # mount's fmask/dmask already present everything as 0700. --modify-window=2
  # covers FAT's 2-second mtime granularity so unchanged files are skipped.
  # /loader/random-seed is deliberately PER-ESP (systemd-boot derives the
  # ERSP from it): excluded from copy AND protected receiver-side from
  # --delete (rsync protects excluded files on the receiver by default).
  syncScript = pkgs.writeShellApplication {
    name = "boot-mirror-sync";
    runtimeInputs = with pkgs; [
      diffutils
      rsync
      systemd # bootctl
      coreutils
    ];
    text = ''
      set -euo pipefail

      # 1. Install/refresh systemd-boot on the mirror ESP: loader binary +
      #    EFI/BOOT fallback + per-ESP random seed. --variables=no: this unit
      #    never touches EFI variables — NVRAM is owned by boot-mirror-activate.
      #    --make-entry-directory=no: the auto entry-token dir would exist ONLY
      #    on the mirror and trip the diff gate below (NixOS's builder writes
      #    entries straight into loader/entries/, no token dir).
      bootctl --esp-path="${mirrorPath}" --variables=no --make-entry-directory=no install

      # 2. Full tree mirror (entries, kernels, initrds, loader.conf).
      rsync \
        --archive --no-owner --no-group --no-perms --modify-window=2 \
        --delete \
        --exclude=/loader/random-seed \
        /boot/ "${mirrorPath}/"

      # 3. Verification gate — the 2nd boot disk must be tree-identical to
      #    the ESP the system actually manages, or it is a lie. Any drift
      #    (failed copy, partial write, manual edit) fails the unit loudly
      #    instead of arming a stale-boot trap. "System Volume Information"
      #    is FAT-tooling noise, never mirrored.
      if ! diff -r -x random-seed -x "System Volume Information" /boot "${mirrorPath}"; then
        echo "boot-mirror-sync: mirror diverges from /boot (diff above) — refusing to call the 2nd boot disk current" >&2
        exit 1
      fi

      echo "boot-mirror-sync: OK — $(ls ${mirrorPath}/loader/entries/nixos-*.conf 2>/dev/null | wc -l) entries, $(du -sh ${mirrorPath} 2>/dev/null | cut -f1) mirrored"
    '';
  };
in
{
  # nofail: a dead/absent Samsung skips the mount, the sync unit
  # condition-skips, and the QLC boot chain stays fully functional — the
  # mirror is purely additive redundancy. NOT neededForBoot: stage 1 never
  # mounts it (the firmware consumes the ESP contents directly).
  fileSystems.${mirrorPath} = mkFilesystem {
    device = "/dev/disk/by-uuid/4F53-C156"; # SAMSUNG-EFI (Samsung p1, PARTUUID 023f66c0-…)
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
      "nofail"
    ];
  };

  systemd.services.boot-mirror-sync = {
    description = "Mirror /boot (NixOS ESP) to the Samsung 2nd-boot-disk ESP";
    wantedBy = [ "multi-user.target" ];
    after = [ "boot-mirror.mount" ];
    unitConfig = {
      RequiresMountsFor = [ mirrorPath ];
      ConditionPathIsMountPoint = mirrorPath;
    };
    startLimitBurst = 5;
    startLimitIntervalSec = 300;
    serviceConfig = lib.mkMerge [
      (harden { })
      (serviceOneshotDefaults { })
      {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe syncScript;
        ReadWritePaths = [ mirrorPath ];
        TimeoutStartSec = "5min";
      }
    ];
    onFailure = onFailure;
  };

  # Mirror staleness must be visible: a failed sync unit pages via the
  # standard notify-failure routing and shows in system-health (which also
  # catches the Condition-skipped-forever class via freshness checks).
  services.system-health.extraMonitoredServices = [ "boot-mirror-sync" ];
}
