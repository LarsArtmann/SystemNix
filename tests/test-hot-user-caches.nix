# VM test for the hot-user-caches module + the 2026-09-24 boot-transaction
# tmpfiles regression + the 2026-09-29 D-state bootstrap wedge.
#
# Regression 1 (live 2026-09-24 22:35, first boot after the module's
# deploy): wiring the bootstrap's wantedBy=/before= against the fstab
# .AUTOMOUNT unit closed an ordering cycle inside the boot transaction —
# systemd-tmpfiles-setup.service's start job got DELETED to break the cycle
# ("Job systemd-tmpfiles-setup.service/start deleted to break ordering
# cycle"), so the main tmpfiles pass never ran and /run/binfmt (nix sandbox
# extra-sandbox-paths), /run/systemnix/sev1, /run/lock/* never existed for
# the whole boot. Every sandboxed nix build died "getting attributes of
# path /run/binfmt"; sev1-bridge 226'd 2900x. Only an actual BOOT catches
# transaction cycles — eval cannot see them.
#
# Regression 2 (live 2026-09-29 09:58): the bootstrap's process hung in
# D-state right after boot (btrfs ioctl window, zero output for hours).
# TimeoutStartSec cannot complete a start job whose process ignores
# SIGKILL, so the job sat "running" forever, the before=-ordered .mount sat
# "waiting" forever, and everything touching the automount path parked in
# autofs_wait: every nix invocation on the host (all AI agents stuck "on
# outputs"), 84 D-state processes, load 86, boot transaction never reached
# multi-user.target. The fix — JobTimeoutSec/JobRunningTimeoutSec on the
# service + x-systemd.mount-timeout on the mount — is pinned twice here:
# production values asserted on the healthy node, mechanism exercised on
# the `wedged` node (bootstrap replaced by an eternal sleep with test-only
# fast timeouts; the automount must still serve the path).
#
# Asserts:
#   1. systemd-tmpfiles-setup.service is ACTIVE after boot, and a probe
#      tmpfiles rule was actually applied (rule application, not just unit
#      state).
#   2. No failed units from the automount chain.
#   3. First cache access: automount triggers → .mount pulls the bootstrap
#      → subvolume created on the hot disk → btrfs mount serves it.
#   4. Writes through the automounted path land on the hot disk.
#   5. Production timeout posture: the bootstrap carries job-level
#      timeouts; the mount carries x-systemd.mount-timeout.
#   6. A bootstrap that never exits cannot park the automount forever.
{
  pkgs,
}:
let
  # Two-statement load form (the miniflux Nix-parsing trap: apply-then-select
  # does not parse as intended).
  hotUserCachesFile = import ../modules/nixos/services/hot-user-caches.nix;
  hotUserCachesModule = (hotUserCachesFile { }).flake.nixosModules.hot-user-caches;
in
{
  name = "hot-user-caches";

  nodes.machine =
    { ... }:
    {
      imports = [
        ./test-helpers.nix
        hotUserCachesModule
      ];

      users.primaryUser = "lars";
      users.users.lars.isNormalUser = true;

      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 512 ];

      # Mirror the production /mnt/hot Samsung-toplevel mount. MUST be
      # virtualisation.fileSystems, NOT fileSystems (qemu-vm mkVMOverride
      # replaces the whole option — plain entries vanish from the guest
      # fstab; test-cv/test-pool-recovery precedent). The module's eval-time
      # assertion still sees the merged config.fileSystems entry.
      virtualisation.fileSystems."/mnt/hot" = {
        device = "/dev/disk/by-label/tlc";
        fsType = "btrfs";
        options = [ "nofail" ];
      };

      # Test-cv pool-fmt pattern: format the hot disk BEFORE mnt-hot.mount
      # starts (its by-label device unit only exists after mkfs).
      systemd.services.hot-fmt = {
        description = "Format the virtio disk as btrfs label tlc (test-only)";
        wantedBy = [ "local-fs.target" ];
        before = [
          "mnt-hot.mount"
          "local-fs.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.systemd
        ];
        script = ''
          if ! blkid /dev/vdb | grep -q 'LABEL="tlc"'; then
            mkfs.btrfs -f -L tlc /dev/vdb
          fi
          udevadm settle
        '';
      };

      # Probe rule: proves the main tmpfiles CREATE pass actually applied
      # rules (unit state alone could be RemainAfterExit theatre).
      systemd.tmpfiles.rules = [ "d /run/huc-tmpfiles-probe 0755 root root -" ];

      services.hot-user-caches.enable = true;

      system.stateVersion = "25.11";
    };

  nodes.wedged =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        ./test-helpers.nix
        hotUserCachesModule
      ];

      users.primaryUser = "lars";
      users.users.lars.isNormalUser = true;

      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 512 ];

      virtualisation.fileSystems."/mnt/hot" = {
        device = "/dev/disk/by-label/tlc";
        fsType = "btrfs";
        options = [ "nofail" ];
      };

      # Same hot-fmt, but the subvolume is PRE-created so the .mount can
      # succeed the moment the wedged bootstrap's job is cancelled — the
      # regression isolates the ordering wedge, not subvol creation.
      systemd.services.hot-fmt = {
        description = "Format the virtio disk as btrfs label tlc + pre-create the cache subvol (test-only)";
        wantedBy = [ "local-fs.target" ];
        before = [
          "mnt-hot.mount"
          "local-fs.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.btrfs-progs
          pkgs.util-linux
          pkgs.systemd
        ];
        script = ''
          if ! blkid /dev/vdb | grep -q 'LABEL="tlc"'; then
            mkfs.btrfs -f -L tlc /dev/vdb
          fi
          udevadm settle
          mount /dev/disk/by-label/tlc /mnt
          mkdir -p /mnt/users/lars/cache
          btrfs subvolume create /mnt/users/lars/cache/nix
          umount /mnt
        '';
      };

      services.hot-user-caches.enable = true;

      # 2026-09-29 regression stand-in: a bootstrap whose process NEVER
      # exits (the D-state class is unkillable; an eternal sleep is the
      # killable stand-in — production values are pinned by assertion 5 on
      # the healthy node). Fast test-only timeouts keep the scenario at
      # ~20s instead of the production 2min/4min budget.
      systemd.services.hot-user-caches-nix-bootstrap = {
        script = lib.mkForce ''
          sleep infinity
        '';
        serviceConfig.TimeoutStartSec = lib.mkForce "15s";
        unitConfig = {
          JobTimeoutSec = lib.mkForce "20s";
          JobRunningTimeoutSec = lib.mkForce "20s";
        };
      };

      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1. THE REGRESSION TRIPWIRE — with the pre-2026-09-25 wiring (bootstrap
    # wantedBy/before on the .automount), systemd deleted the tmpfiles start
    # job to break the boot ordering cycle and BOTH of these fail.
    machine.succeed("systemctl is-active --quiet systemd-tmpfiles-setup.service")
    machine.succeed("test -d /run/huc-tmpfiles-probe")

    # 2. No failed units from the automount/bootstrap chain.
    machine.fail("systemctl --failed --no-legend | grep -v '0 loaded units'")

    # 3. First cache access: automount → .mount → bootstrap → subvol → mount.
    # The bootstrap cold-creates the subvolume and pulls mnt-hot.mount, so
    # allow a generous timeout for the first trigger.
    machine.succeed("ls /home/lars/.cache/nix/ >/dev/null")
    machine.wait_for_unit("home-lars-.cache-nix.mount", timeout=120)
    machine.succeed("findmnt -n -o FS_TYPE /home/lars/.cache/nix | grep -q btrfs")
    machine.succeed("systemctl is-active --quiet hot-user-caches-nix-bootstrap.service")

    # 4. Writes land on the hot-disk subvolume (the mount is live, not a
    # shadow of the underlying @ dir).
    machine.succeed("touch /home/lars/.cache/nix/alive && test -f /home/lars/.cache/nix/alive")
    machine.succeed("test -f /mnt/hot/users/lars/cache/nix/alive")

    # 5. Production timeout posture (2026-09-29 class): job-level timeouts
    # on the bootstrap (240000000 µs = 4min), mount-timeout on the .mount
    # (90000000 µs = 90s). These vanish silently if someone drops the
    # options from the module — this is the tripwire.
    machine.succeed("systemctl show hot-user-caches-nix-bootstrap.service -p JobTimeoutUSec | grep -q 240000000")
    machine.succeed("systemctl show hot-user-caches-nix-bootstrap.service -p JobRunningTimeoutUSec | grep -q 240000000")
    machine.succeed("systemctl show hot-user-caches-nix-bootstrap.service -p TimeoutStartUSec | grep -q 120000000")
    machine.succeed("systemctl show home-lars-.cache-nix.mount -p TimeoutStartUSec | grep -q 90000000")

    # 6. THE WEDGED-BOOTSTRAP REGRESSION (live 2026-09-29): first access
    # fires the automount, the .mount queues behind a bootstrap that never
    # exits — the timeouts must cancel its job and let the mount through.
    # Pre-fix, this ls parks in autofs_wait forever and the wait_for_unit
    # below never happens.
    wedged.start()
    wedged.wait_for_unit("multi-user.target")
    wedged.succeed("ls /home/lars/.cache/nix/ >/dev/null")
    wedged.wait_for_unit("home-lars-.cache-nix.mount", timeout=120)
    wedged.succeed("findmnt -n -o FS_TYPE /home/lars/.cache/nix | grep -q btrfs")
    wedged.succeed("systemctl is-failed --quiet hot-user-caches-nix-bootstrap.service")
    wedged.succeed("touch /home/lars/.cache/nix/unwedged")
  '';
}
