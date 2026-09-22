# VM test for the restic-app-dumps module.
#
# Verifies the runtime risks that eval CANNOT check (library entry
# docs/todo/storage.md, 2026-09-22):
#   1. Password bootstrap: created at boot, non-empty, mode 0600, IDEMPOTENT
#      on re-run (searxng-secret-key pattern — a rotated-by-rerun password
#      would orphan the repo).
#   2. `restic init` on the missing repo rides the nixpkgs preStart
#      (`restic cat config || restic init`, initialize = true) — the lost-pool
#      re-initialization contract.
#   3. Backup lands: a real snapshot for the seeded dump dir is provable via
#      the restic CLI against the same password file the unit uses.
#   4. `.last_success` marker appears ONLY on success: a wrong-password run
#      FAILS the unit (preStart cannot unlock) and must NOT touch the marker;
#      restoring the password converges the next run.
#   5. backup-coordination registry fan-out: the integration `backup` row
#      makes the collector report backup_healthy=1 from the marker's mtime.
#   6. Unit shape: mount gating (RequiresMountsFor=/mnt/pool), bounded prune
#      (--keep-daily), the 05:45 timer with Persistent catch-up.
#
# Pool simulation is the test-cv.nix pattern: a real btrfs disk mounted
# by-label at /mnt/pool (virtualisation.fileSystems, NOT fileSystems —
# qemu-vm.nix mkVMOverride would silently drop a plain entry).
{ pkgs }:
let
  # Extract the NixOS module from the flake-parts wrapper.
  resticFlakeOutput = (import ../modules/nixos/services/restic-app-dumps.nix { });
  resticNixosModule = resticFlakeOutput.flake.nixosModules.restic-app-dumps;
in
{
  name = "restic-app-dumps";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        resticNixosModule
        # co-import: the module declares a services.integration entry
        # (mkIf-wrapped options?-guard caveat, 2026-09-15)
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
        (import ../modules/nixos/services/backup-coordination.nix { }).flake.nixosModules.backup-coordination
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      services.restic-app-dumps = {
        enable = true;
        # One seeded dir keeps the VM closure light; production mirrors ten.
        paths = [ "/mnt/pool/backups/cv" ];
      };

      # Collector half of assertion 5 (registry row -> backups attrset fan-out
      # -> textfile metrics).
      services.backup-coordination.enable = true;

      # Direct CLI assertions (snapshot listing) alongside the module's own
      # `restic-app-dumps` wrapper.
      environment.systemPackages = [ pkgs.restic ];

      # --- pool simulation (test-cv.nix pattern, verbatim semantics) ---
      boot.supportedFilesystems = [ "btrfs" ];
      virtualisation.emptyDiskImages = [ 512 ];
      virtualisation.fileSystems."/mnt/pool" = {
        device = "/dev/disk/by-label/pool";
        fsType = "btrfs";
        options = [ "nofail" ];
      };
      systemd.services.pool-fmt = {
        description = "Format the virtio disk as btrfs label pool (test-only)";
        # Must complete BEFORE mnt-pool.mount starts (its by-label device
        # unit only exists once mkfs has run) — a sibling under
        # local-fs.target with no ordering races the mount.
        wantedBy = [ "local-fs.target" ];
        before = [
          "mnt-pool.mount"
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
          if ! blkid /dev/vdb | grep -q 'LABEL="pool"'; then
            mkfs.btrfs -f -L pool /dev/vdb
          fi
          udevadm settle
        '';
      };
    };

  testScript = ''
    machine.start()

    # 1. Password bootstrap at boot: exists, non-empty, 0600, idempotent.
    machine.wait_for_unit("restic-app-dumps-setup.service")
    machine.succeed("test -s /var/lib/restic-app-dumps/password")
    mode = machine.succeed("stat -c %a /var/lib/restic-app-dumps/password").strip()
    assert mode == "600", f"password mode {mode!r} != 600"
    pw_before = machine.succeed(
      "sha256sum /var/lib/restic-app-dumps/password | cut -d' ' -f1"
    ).strip()
    machine.succeed("systemctl restart restic-app-dumps-setup.service")
    pw_after = machine.succeed(
      "sha256sum /var/lib/restic-app-dumps/password | cut -d' ' -f1"
    ).strip()
    assert pw_before == pw_after, "password bootstrap is not idempotent — a re-run must never rotate the repo password"

    # 6. Unit shape: mount gating, bounded prune, staggered persistent timer.
    machine.wait_for_unit("mnt-pool.mount")
    machine.succeed(
      "systemctl cat restic-backups-app-dumps.service | grep -q 'RequiresMountsFor=/mnt/pool'"
    )
    machine.succeed(
      "systemctl cat restic-backups-app-dumps.service | grep -q -- '--keep-daily'"
    )
    machine.wait_for_unit("restic-backups-app-dumps.timer")
    machine.succeed(
      "systemctl cat restic-backups-app-dumps.timer | grep -q '05:45:00'"
    )
    machine.succeed(
      "systemctl cat restic-backups-app-dumps.timer | grep -q 'Persistent=yes'"
    )

    # 2+3. Seed a dump source, run the backup once: restic init rides the
    # preStart on the missing repo, the snapshot lands, the marker appears.
    machine.succeed("mkdir -p /mnt/pool/backups/cv")
    machine.succeed(
      "dd if=/dev/urandom of=/mnt/pool/backups/cv/pipeline-20260922.sqlite bs=4k count=4 status=none"
    )
    machine.succeed("systemctl start restic-backups-app-dumps.service")
    machine.succeed(
      "restic -r /mnt/pool/backups/restic-app-dumps --password-file /var/lib/restic-app-dumps/password snapshots | grep -q '/mnt/pool/backups/cv'"
    )
    machine.succeed("test -f /mnt/pool/backups/restic-app-dumps/.last_success")

    # 4. Marker ONLY on success: a wrong password fails preStart (cannot
    # unlock the existing repo) and must NOT leave a fresh marker. Restoring
    # the password converges the next run (backup + marker back).
    machine.succeed("rm -f /mnt/pool/backups/restic-app-dumps/.last_success")
    machine.succeed("cp /var/lib/restic-app-dumps/password /root/pw.bak")
    machine.succeed("echo definitely-the-wrong-password > /var/lib/restic-app-dumps/password")
    machine.fail("systemctl start restic-backups-app-dumps.service")
    machine.fail("test -e /mnt/pool/backups/restic-app-dumps/.last_success")
    machine.succeed("cp /root/pw.bak /var/lib/restic-app-dumps/password")
    machine.succeed("systemctl start restic-backups-app-dumps.service")
    machine.succeed("test -f /mnt/pool/backups/restic-app-dumps/.last_success")

    # 5. backup-coordination fan-out: the registry `backup` row resolves the
    # marker's mtime into freshness metrics (healthy=1, timestamp > 0).
    machine.succeed("systemctl start backup-health-metrics.service")
    machine.wait_for_file(
      "/var/lib/prometheus-node-exporter/textfile_collectors/backups.prom"
    )
    prom = "/var/lib/prometheus-node-exporter/textfile_collectors/backups.prom"
    machine.succeed(f"grep -q 'backup_healthy{{backup=\"restic-app-dumps\"}} 1' {prom}")
    ts = machine.succeed(
      f"grep 'backup_last_success_timestamp{{backup=\"restic-app-dumps\"}}' {prom}"
    ).strip().split()[-1]
    assert int(ts) > 0, f"marker mtime not picked up, got {ts!r}"
  '';
}
