# VM test for the hot-user-caches module.
#
# Incident history this file guards against (full narrative in
# modules/nixos/services/hot-user-caches.nix):
#
# Regression 1 (live 2026-09-24 22:35): the v1 bootstrap wiring (edges
# against the .automount) closed ordering cycles inside the boot
# transaction — systemd DELETED systemd-tmpfiles-setup.service's job to
# break the cycle, so /run/binfmt (nix sandbox extra-sandbox-paths),
# /run/systemnix/sev1, /run/lock/* never existed for the whole boot and
# every sandboxed nix build died. Only an actual BOOT catches transaction
# cycles — eval cannot see them. The bootstrap no longer exists (removed
# 2026-09-29), but the tmpfiles tripwire stays: it catches ANY future
# wiring that resurrects the cycle class.
#
# Regression 2 (live 2026-09-27 ×2, 2026-09-29): the bootstrap child hung
# PRE-EXEC in autofs_wait (systemd's sandbox namespace builder MNT_DETACHes
# autofs mounts; the umount's lookup blocked on the pending direct autofs
# whose mount job was queued behind the same service — kernel-level
# self-deadlock, /proc/<pid>/stack: umount2 → autofs_wait). The cache mount
# NEVER completed in ANY boot since deploy; every nix invocation touching
# ~/.cache/nix parked in D-state (2026-09-29: 84 processes, load 86, boot
# transaction stuck 3+h). Fix: the bootstrap is GONE — subvolumes are
# provisioning state (disko), the automount mounts directly, nothing
# runtime sits in between. Tripwire 3 pins the deletion.
#
# Asserts:
#   1. systemd-tmpfiles-setup.service is ACTIVE after boot, and a probe
#      tmpfiles rule was actually applied (rule application, not just unit
#      state).
#   2. No failed units from the automount chain.
#   3. NO bootstrap unit exists — nothing runtime between automount and
#      mount (the 2026-09-27/29 self-deadlock class).
#   4. First cache access mounts FAST (no service in the transaction) and
#      serves the btrfs subvolume; writes land on the hot disk.
#   5. Production posture: the .mount carries x-systemd.mount-timeout
#      (bounds any future pathological mount job).
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
      # side still sees the merged config.
      virtualisation.fileSystems."/mnt/hot" = {
        device = "/dev/disk/by-label/tlc";
        fsType = "btrfs";
        options = [ "nofail" ];
      };

      # Provisioning stand-in for disko/samsung-tlc.nix (which declares
      # /users/lars/cache/nix in production): format the hot disk BEFORE
      # mnt-hot.mount starts, mount it transiently, create the subvolume,
      # unmount. Since the 2026-09-29 fix, subvolume creation is
      # provisioning-time ONLY — the runtime bootstrap is deleted (it hung
      # pre-exec in autofs_wait on 4 consecutive boots and wedged every
      # nix invocation on the host).
      systemd.services.hot-fmt = {
        description = "Format the virtio disk as btrfs label tlc + provision the cache subvol (test-only disko stand-in)";
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

      # Probe rule: proves the main tmpfiles CREATE pass actually applied
      # rules (unit state alone could be RemainAfterExit theatre).
      systemd.tmpfiles.rules = [ "d /run/huc-tmpfiles-probe 0755 root root -" ];

      services.hot-user-caches.enable = true;

      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1. THE 2026-09-24 TRIPWIRE — with the v1 wiring, systemd deleted the
    # tmpfiles start job to break a boot ordering cycle and BOTH of these
    # fail (sandboxed nix builds then die on /run/binfmt for the whole
    # boot). The bootstrap is gone now, but any future edge that
    # resurrects the cycle class trips this.
    machine.succeed("systemctl is-active --quiet systemd-tmpfiles-setup.service")
    machine.succeed("test -d /run/huc-tmpfiles-probe")

    # 2. No failed units from the automount chain.
    machine.fail("systemctl --failed --no-legend | grep -v '0 loaded units'")

    # 3. THE 2026-09-27/29 TRIPWIRE — no runtime bootstrap may ever sit
    # between the automount and its mount again (pre-exec autofs_wait
    # self-deadlock class, wedged every nix command on the host across 4
    # boots).
    machine.fail("systemctl cat hot-user-caches-nix-bootstrap.service")
    machine.succeed("! systemctl list-unit-files | grep -q hot-user-caches")

    # 4. First cache access: automount fires and mounts DIRECTLY (no
    # service pulled into the transaction — pre-fix, this ls parked in
    # autofs_wait forever). Tight timeout: the mount is instant when
    # nothing serializes in front of it.
    machine.succeed("timeout 30 ls /home/lars/.cache/nix/ >/dev/null")
    machine.wait_for_unit("home-lars-.cache-nix.mount", timeout=60)
    machine.succeed("findmnt -n -o FS_TYPE /home/lars/.cache/nix | grep -q btrfs")

    # 5. Production posture: the .mount carries x-systemd.mount-timeout
    # (90000000 µs = 90s) so even a pathological future mount job fails
    # fast instead of parking autofs waiters forever.
    machine.succeed("systemctl show home-lars-.cache-nix.mount -p TimeoutStartUSec | grep -q 90000000")

    # 6. Writes land on the hot-disk subvolume (the mount is live, not a
    # shadow of the underlying @ dir).
    machine.succeed("touch /home/lars/.cache/nix/alive && test -f /home/lars/.cache/nix/alive")
    machine.succeed("test -f /mnt/hot/users/lars/cache/nix/alive")
  '';
}
