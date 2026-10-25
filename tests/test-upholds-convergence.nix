# VM test for the systemd `Upholds=` evaluation (2026-09-14 boot-dropout
# class, docs/todo/stability.md row "Evaluate systemd Upholds=").
#
# Question under test: can `Upholds=` replace pool-recovery's event-driven
# converge_consumers for the CONSUMER half of mount dropout (enabled-but-
# inactive daemons left dark for the whole boot after a cancelled mount
# start job; daemons FAILED against a zombie EIO mount)?
#
# Three scenarios, one node (ext4 on a single virtio disk — mechanism under
# test is systemd dependency semantics, not any filesystem):
#
#   1. CRASH-RESTART: consumer with Restart=no dies (SIGKILL) while the
#      mount is active — Upholds must restart it. This is the "daemon died
#      against a bad mount" half of converge_consumers.
#   2. DROPOUT SIMULATION: mount stopped + consumer stopped (the cancelled-
#      start-job end state: everything down, nothing failed) — the consumer
#      must STAY down while the mount is inactive (Upholds is not Requires;
#      a detached mount must fail loudly, never spin a restart loop), and
#      must be pulled UP again when the mount returns — with NO converger
#      script, purely declaratively. This is the boot-dropout half.
#   3. NO RESTART LOOP: steady inactive-mount window — assert the consumer
#      shows no activating/restart churn while the mount is down.
#
# What Upholds deliberately does NOT cover (kept as the evaluation's
# verdict, docs/agents/stability.md): zombie-mount detection + real-IO
# verification + udev-triggered remount — pool-recovery's mount-half work.
{ pkgs }:
{
  name = "upholds-convergence";

  nodes.machine =
    { ... }:
    {
      boot.supportedFilesystems = [ "ext4" ];
      virtualisation.emptyDiskImages = [ 512 ];
      # qemu-vm.nix replaces `fileSystems` at priority 900 — must use the
      # virtualisation alias (test-pool-recovery gotcha).
      virtualisation.fileSystems."/mnt/uph" = {
        device = "/dev/disk/by-label/uph";
        fsType = "ext4";
        options = [ "nofail" ];
      };
      systemd.services.uph-fmt = {
        description = "Format the virtio disk as ext4 label uph (test-only)";
        wantedBy = [ "local-fs.target" ];
        before = [
          "mnt-uph.mount"
          "local-fs.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path = [
          pkgs.e2fsprogs
          pkgs.util-linux
          pkgs.systemd
        ];
        script = ''
          if ! blkid /dev/vdb | grep -q 'LABEL="uph"'; then
            mkfs.ext4 -L uph /dev/vdb
          fi
          udevadm settle
        '';
      };
      systemd.services.uph-consumer = {
        description = "Upholds evaluation fixture (mount-dependent daemon)";
        # The mechanism under test: while mnt-uph.mount is active, systemd
        # continuously (re)starts this unit if it is inactive/failed.
        upholds = [ "mnt-uph.mount" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
          # Deliberately NO auto-restart: any recovery observed below can
          # only have come from Upholds.
          Restart = "no";
        };
      };
      system.stateVersion = "25.11";
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("mnt-uph.mount")
    machine.wait_for_unit("uph-consumer.service")

    # 1. Crash-restart while mount active (Restart=no ⇒ Upholds did it).
    # wait_until_succeeds, not wait_for_unit: the unit passes THROUGH a
    # transient "failed" state (SIGKILL result) before Upholds restarts it.
    machine.succeed("systemctl kill --signal=SIGKILL uph-consumer.service")
    machine.wait_until_succeeds("systemctl is-active --quiet uph-consumer.service")
    machine.succeed("systemctl is-active uph-consumer.service")
    n_restarts = int(machine.succeed("systemctl show -p NRestarts --value uph-consumer.service").strip())
    assert n_restarts == 0, f"NRestarts={n_restarts} — restart must be Upholds-attributed, not Restart= (unit has Restart=no)"
    # journal attribution: systemd logs the uphold edge
    machine.succeed("journalctl -u uph-consumer.service -b --no-pager | grep -i uphold")

    # 2+3. Dropout simulation: everything down, mount inactive — consumer
    # must stay DOWN (no restart loop) while the mount is dark...
    machine.succeed("systemctl stop uph-consumer.service mnt-uph.mount")
    machine.succeed("sleep 5")
    machine.fail("systemctl is-active --quiet uph-consumer.service")
    state = machine.succeed("systemctl show -p ActiveState --value uph-consumer.service").strip()
    assert state == "inactive", f"consumer churned while mount down: {state}"
    # ...and must come back when the mount returns — declaratively, no
    # converger involved.
    machine.succeed("systemctl start mnt-uph.mount")
    machine.wait_until_succeeds("systemctl is-active --quiet uph-consumer.service")
    machine.succeed("systemctl is-active uph-consumer.service")
  '';
}
