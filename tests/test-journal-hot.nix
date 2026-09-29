# VM test for the journald hot-tier mount (journal-hot.nix).
#
# Verifies the two things eval CANNOT check:
#   1. HAPPY path (Samsung present): journald's boot-time writes land ON the
#      mounted subvolume — the after/wants wiring beats journald's
#      Before=sysinit.target early start (probed live: systemd 261.2 has NO
#      RequiresMountsFor=/var/log/journal). Proof: marker roundtrip PLUS
#      findmnt -T on the ACTIVE journal file resolving to the mount (a
#      shadow-dir split would leave the active file on the root fs).
#   2. DEGRADED path (Samsung absent): the failed nofail mount must NOT wedge
#      the boot or kill journald (wants, not requires) — logging stays alive.
#
# qemu-vm replaces the WHOLE fileSystems option (mkVMOverride, test-hot-db
# lesson) — the entry is re-declared under virtualisation.fileSystems with
# the production options; the journald after/wants wiring comes from the REAL
# module import (parity with production).
{ pkgs, ... }:
let
  journalHot = import ../platforms/nixos/system/journal-hot.nix;

  entry = {
    device = "/dev/disk/by-label/tlc";
    fsType = "btrfs";
    options = [
      "subvol=journal"
      "noatime"
      "nodiscard"
      "space_cache=v2"
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };
in
{
  name = "journal-hot";

  nodes.machine =
    { ... }:
    {
      imports = [ journalHot ];
      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 512 ];
      virtualisation.fileSystems."/var/log/journal" = entry;

      # Test-only scaffolding (production: scripts/migrate-journal-hot.sh
      # creates the subvol BEFORE the first deploy — fstab cannot create
      # subvolumes). Atticd-storage-dir shape: tied to the mount unit
      # itself, NOT before=local-fs.target (that edge is an ordering cycle).
      systemd.services.tlc-fmt = {
        description = "Format tlc disk + create journal subvolume (test-only)";
        wantedBy = [ "var-log-journal.mount" ];
        before = [ "var-log-journal.mount" ];
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
          mkdir -p /tlc-top /var/log/journal
          mount -t btrfs -o subvolid=5 /dev/vdb /tlc-top
          if ! btrfs subvolume show /tlc-top/journal >/dev/null 2>&1; then
            btrfs subvolume create /tlc-top/journal
          fi
          chattr +C /tlc-top/journal
          umount /tlc-top
        '';
      };
    };

  nodes.degraded =
    { ... }:
    {
      imports = [ journalHot ];
      # NO disk: the by-label device never appears — the mount fails after
      # the 5s device timeout and journald must proceed degraded.
      virtualisation.fileSystems."/var/log/journal" = entry;
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1a: the mount came up and is the journal subvolume.
    fsroot = machine.succeed("findmnt -n -o FSROOT /var/log/journal").strip()
    assert "journal" in fsroot, f"unexpected FSROOT on /var/log/journal: {fsroot}"

    # 1b: nodatacow inherited on the subvol root (doctrine C; test-hot-db
    # lsattr idiom — do NOT grep /proc/mounts, btrfs >=6.x omits nodatacow).
    machine.succeed("lsattr -d /var/log/journal | grep -q -- --C")

    # 1c: marker roundtrip — journald accepted the entry and reads it back.
    machine.succeed("systemd-cat -t jhot-verify echo marker-jhot-ok")
    machine.sleep(3)
    machine.succeed("journalctl -t jhot-verify -b --no-pager | grep -q marker-jhot-ok")

    # 1d: THE anti-split proof — the ACTIVE journal file physically lives on
    # the mount. A lost boot race (journald opening the shadow dir first)
    # would leave the active file on the root fs.
    newest = machine.succeed("ls -t /var/log/journal/$(cat /etc/machine-id)/ | head -1").strip()
    target = machine.succeed(
        f"findmnt -T /var/log/journal/$(cat /etc/machine-id)/{newest} -n -o TARGET"
    ).strip()
    assert target == "/var/log/journal", (
        f"active journal file off-mount (TARGET={target})"
    )

    machine.shutdown()

    # 2: degraded — Samsung absent. The failed mount must not kill journald
    # (wants, not requires — a regression to requires leaves journald dead
    # and this section fails on wait_for_unit) nor wedge the boot.
    degraded.start()
    degraded.wait_for_unit("multi-user.target")
    degraded.wait_for_unit("systemd-journald.service")
    degraded.succeed("systemd-cat -t jhot-degraded echo marker-degraded-ok")
    degraded.sleep(3)
    degraded.succeed("journalctl -t jhot-degraded -b --no-pager | grep -q marker-degraded-ok")
    degraded.fail("mountpoint -q /var/log/journal")
  '';
}
