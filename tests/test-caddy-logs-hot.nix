# VM test for the caddy-logs hot-tier mount (caddy-logs-hot.nix) — port of
# test-journal-hot.nix to the caddy shape (NO journald Before=sysinit
# landmine; caddy is a normal post-local-fs service, so the formatter
# scaffolding is the only borrowed trick).
#
# Verifies the two things eval CANNOT check:
#   1. HAPPY path (Samsung present): caddy's access-log writes land ON the
#      mounted caddy-logs subvolume. Proof: curl roundtrip PLUS findmnt -T on
#      the ACTIVE access-log file resolving to the mount (a shadow-split
#      would leave the file on the root fs) + lsattr +C (doctrine C).
#   2. DEGRADED path (Samsung absent): the failed nofail mount must NOT wedge
#      the boot or kill caddy (wants, not requires) — caddy serves and logs
#      into the QLC shadow dir.
#
# qemu-vm replaces the WHOLE fileSystems option (mkVMOverride, test-hot-db
# lesson) — the entry is re-declared under virtualisation.fileSystems with
# the production options; the caddy after/wants wiring comes from the REAL
# module import (parity with production).
#
# The vHost here is minimal test scaffolding writing a single access file —
# the mount is the system under test, not the production logging map.
{pkgs, ...}: let
  caddyLogsHot = import ../platforms/nixos/system/caddy-logs-hot.nix;

  entry = {
    device = "/dev/disk/by-label/tlc";
    fsType = "btrfs";
    options = [
      "subvol=caddy-logs"
      "noatime"
      "nodiscard"
      "space_cache=v2"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  caddyVm = _: {
    services.caddy = {
      enable = true;
      globalConfig = "auto_https off";
      virtualHosts."localhost" = {
        logFormat = "output file /var/log/caddy/access-localhost.log";
        extraConfig = "respond \"caddy-hot-ok\"";
      };
    };
    environment.systemPackages = [pkgs.curl];
  };
in {
  name = "caddy-logs-hot";

  nodes.machine = {...}: {
    imports = [
      caddyLogsHot
      caddyVm
    ];
    boot.supportedFilesystems = ["btrfs"];
    virtualisation.emptyDiskImages = [512];
    virtualisation.fileSystems."/var/log/caddy" = entry;

    # Test-only scaffolding (production: scripts/migrate-caddy-logs-hot.sh
    # creates the subvol BEFORE the first deploy — fstab cannot create
    # subvolumes). Same DefaultDependencies=false rationale as
    # test-journal-hot.nix: with default deps the formatter closes the cycle
    # var-log-caddy.mount → tlc-fmt → sysinit → local-fs → mount and
    # systemd's cycle breaker hangs the guest SILENT. The explicit
    # udev-trigger anchor keeps /dev/vdb visible this early.
    systemd.services.tlc-fmt = {
      description = "Format tlc disk + create caddy-logs subvolume (test-only)";
      unitConfig.DefaultDependencies = false;
      wantedBy = ["var-log-caddy.mount"];
      before = ["var-log-caddy.mount"];
      after = ["systemd-udev-trigger.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [
        pkgs.btrfs-progs
        pkgs.e2fsprogs
        pkgs.util-linux
      ];
      script = ''
        if ! blkid /dev/vdb | grep -q 'LABEL="tlc"'; then
          mkfs.btrfs -f -L tlc /dev/vdb
        fi
        mkdir -p /tlc-top /var/log/caddy
        mount -t btrfs -o subvolid=5 /dev/vdb /tlc-top
        if ! btrfs subvolume show /tlc-top/caddy-logs >/dev/null 2>&1; then
          btrfs subvolume create /tlc-top/caddy-logs
        fi
        chattr +C /tlc-top/caddy-logs
        umount /tlc-top
      '';
    };
  };

  nodes.degraded = {...}: {
    imports = [
      caddyLogsHot
      caddyVm
    ];
    # NO disk: the by-label device never appears — the mount fails after
    # the 5s device timeout and caddy must proceed degraded (shadow dir).
    virtualisation.fileSystems."/var/log/caddy" = entry;
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("caddy.service")

    # 1a: the mount came up and is the caddy-logs subvolume.
    fsroot = machine.succeed("findmnt -n -o FSROOT /var/log/caddy").strip()
    assert "caddy-logs" in fsroot, f"unexpected FSROOT on /var/log/caddy: {fsroot}"

    # 1b: nodatacow inherited on the subvol root (doctrine C; test-hot-db
    # lsattr idiom — do NOT grep /proc/mounts, btrfs >=6.x omits nodatacow).
    machine.succeed("lsattr -d /var/log/caddy | grep -q -- --C")

    # 1c: marker roundtrip — caddy accepted the mount and serves through it.
    machine.succeed("curl -sf http://localhost/ | grep -q caddy-hot-ok")

    # 1d: THE anti-split proof — the ACTIVE access-log file physically lives
    # on the mount. A lost boot race (caddy opening the QLC shadow dir first)
    # would leave the file on the root fs.
    machine.sleep(3)
    target = machine.succeed(
        "findmnt -T /var/log/caddy/access-localhost.log -n -o TARGET"
    ).strip()
    assert target == "/var/log/caddy", (
        f"active access log off-mount (TARGET={target})"
    )

    machine.shutdown()

    # 2: degraded — Samsung absent. The failed mount must not kill caddy
    # (wants, not requires — a regression to requires leaves caddy dead and
    # this wait_for_unit fails) nor wedge the boot; logging falls to the
    # shadow dir.
    degraded.start()
    degraded.wait_for_unit("multi-user.target")
    degraded.wait_for_unit("caddy.service")
    degraded.succeed("curl -sf http://localhost/ | grep -q caddy-hot-ok")
    degraded.succeed("test -f /var/log/caddy/access-localhost.log")
    degraded.fail("mountpoint -q /var/log/caddy")
  '';
}
