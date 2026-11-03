# VM test for services.hot-db (Samsung hot-DB tier module).
#
# Verifies the runtime behavior eval CANNOT check:
#   1. The bootstrap oneshot creates the `hot/<name>` subvolume on a REAL
#      btrfs disk before the generated mount comes up (fstab cannot create
#      subvolumes — ordering proof).
#   2. The generated entry mounts AT the dataDir with nodatacow effective
#      (mount option present in /proc/mounts + chattr +C visible via lsattr
#      on the subvolume root).
#   3. The consumer (wired via `unit`) writes successfully — proves
#      RequiresMountsFor ordering (mount before service).
#   4. Anti-shadow: after a manual unmount (simulating a detached
#      Samsung), the consumer condition-skips (ConditionResult=no) instead
#      of writing into a root-fs shadow dir.
#   5. Bootstrap is idempotent (second run creates nothing new, exits 0).
#   6. Shadow-split guard (2026-11-03, superb-v3 S-0038): a declared-but-
#      unprepared entry (populated dataDir, no migrate marker) gets NO
#      subvol — its mount fails naturally, the live shadow stays REACHABLE
#      (never covered), the consumer never runs, and the healthy entry
#      converges unaffected (no shared-unit blast radius).
#
# VM-trap notes:
#   - qemu-vm.nix replaces the WHOLE `fileSystems` option via mkVMOverride
#     whenever `virtualisation.fileSystems != {}` — so both the toplevel
#     /mnt/hot mount AND a copy of the module-generated entry mount are
#     declared under virtualisation.fileSystems (test-cv pool-fmt pattern).
#   - The disk must be formatted BEFORE the by-label mount units start
#     (pool-fmt: wantedBy + before local-fs.target and the mount units).
{ pkgs, ... }:
let
  hotDbModule = (import ../modules/nixos/services/hot-db.nix).flake.nixosModules.hot-db;

  entryPath = "/var/lib/hotdb-test";
  shadowedPath = "/var/lib/hotdb-shadowed";
  entryMount = {
    device = "/dev/disk/by-label/tlc";
    fsType = "btrfs";
    options = [
      "subvol=hot/testdb"
      "noatime"
      "nodiscard"
      "space_cache=v2"
      "nofail"
      "nodatacow"
    ];
  };
  shadowedMount = {
    device = "/dev/disk/by-label/tlc";
    fsType = "btrfs";
    options = [
      "subvol=hot/shadowed"
      "noatime"
      "nodiscard"
      "space_cache=v2"
      "nofail"
    ];
  };
in
{
  name = "hot-db";

  nodes.machine = { ... }: {
    imports = [ hotDbModule ];

    boot.supportedFilesystems = [ "btrfs" ];
    virtualisation.emptyDiskImages = [ 512 ];
    virtualisation.fileSystems = {
      "/mnt/hot" = {
        device = "/dev/disk/by-label/tlc";
        fsType = "btrfs";
        options = [
          "subvolid=5"
          "noatime"
          "nodiscard"
          "space_cache=v2"
          "nofail"
        ];
      };
      "/var/lib/hotdb-test" = entryMount;
      "${shadowedPath}" = shadowedMount;
    };

    services.hot-db = {
      enable = true;
      entries.testdb = {
        path = entryPath;
        cow = false;
        unit = "hotdb-consumer.service";
      };
      # Leg 6 fixture: declared but NEVER migrated (populated dataDir, no
      # marker) — the exact 2026-10-12 incident shape.
      entries.shadowed = {
        path = shadowedPath;
        cow = true;
        unit = "hotdb-shadowed-consumer.service";
      };
    };

    # Probe consumer: writes into the mounted dataDir. Succeeding at all
    # proves the mount came up first (RequiresMountsFor).
    systemd.services.hotdb-consumer = {
      description = "Hot-DB probe consumer";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        echo probe > ${entryPath}/probe.txt
      '';
    };

    # Leg 6 probe consumer for the unprepared entry — it must NEVER run
    # (the entry mount stays failed, the consumer condition-skips).
    systemd.services.hotdb-shadowed-consumer = {
      description = "Hot-DB shadow-split fixture consumer (must never run)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        echo must-never-land > ${shadowedPath}/consumer-write.txt
      '';
    };

    # Leg 6: populate the shadowed dataDir BEFORE the bootstrap consults
    # the guard (tlc-fmt shape: pulled + ordered before the unit that
    # reads the state). Without a pre-populated dataDir the guard would
    # CREATE — the fixture must reproduce the incident's live-store shape.
    systemd.services.hotdb-shadow-populate = {
      description = "Test-only: populate a live dataDir before hot-db-bootstrap";
      wantedBy = [ "hot-db-bootstrap.service" ];
      before = [ "hot-db-bootstrap.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p ${shadowedPath}
        echo live-store-bytes > ${shadowedPath}/live.db
      '';
    };

    # Format the virtio disk as btrfs label `tlc` (production label)
    # before any by-label mount unit can start. Tie to the mount unit
    # itself (atticd-storage-dir shape) — `before local-fs.target` plus
    # the service's default After=sysinit/basic is an ordering cycle.
    systemd.services.tlc-fmt = {
      description = "Format the virtio disk as btrfs label tlc (test-only)";
      wantedBy = [ "mnt-hot.mount" ];
      before = [ "mnt-hot.mount" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [
        pkgs.btrfs-progs
        pkgs.util-linux
      ];
      script = ''
        if ! blkid /dev/vdb | grep -q 'LABEL="tlc"'; then
          mkfs.btrfs -f -L tlc /dev/vdb
        fi
      '';
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    import re
    print("DEBUG entry-cat:", machine.execute("systemctl cat var-lib-hotdb-test.mount || true")[1])
    print("DEBUG toplevel-cat:", machine.execute("systemctl cat mnt-hot.mount || true")[1])
    print("DEBUG toplevel-deps:", machine.execute("systemctl show -p Wants,After,Before mnt-hot.mount || true")[1])
    print("DEBUG re usage:", re.match("x", "x") is not None)
    print("DEBUG bootstrap status:", machine.execute("systemctl status hot-db-bootstrap --no-pager -l || true")[1])
    print("DEBUG bootstrap journal:", machine.execute("journalctl -b --no-pager | grep -i bootstrap | tail -20 || true")[1])

    # 1+2: subvolume exists and is mounted AT the dataDir, nodatacow live.
    machine.succeed("btrfs subvolume show /var/lib/hotdb-test")
    # nodatacow EFFECT check: files created inside the subvol inherit the
    # +C flag. Do NOT grep /proc/mounts for the option — btrfs ≥6.x omits
    # nodatacow from displayed mount options (applies but never shows).
    machine.succeed("lsattr /var/lib/hotdb-test/probe.txt | grep -q C")
    machine.succeed("btrfs subvolume list /mnt/hot | grep -q 'hot/testdb'")

    # chattr +C landed on the fresh subvolume root (fresh-subvol
    # inheritance does NOT carry the flag — the bootstrap sets it).
    machine.succeed("lsattr -d /mnt/hot/hot/testdb | grep -q -- --C")

    # 3: consumer wrote through the mount.
    machine.wait_for_unit("hotdb-consumer.service")
    machine.succeed("test -f /var/lib/hotdb-test/probe.txt")

    # 5: bootstrap idempotent — second run adds nothing, exits 0.
    machine.succeed("systemctl restart hot-db-bootstrap")
    machine.succeed(
        "systemctl is-failed hot-db-bootstrap && exit 1 || true"
    )
    count = machine.succeed("btrfs subvolume list /mnt/hot | grep -c 'hot/testdb'").strip()
    assert count == "1", f"expected exactly one hot/testdb subvol, got {count}"

    # T14 (2026-09-30): the mount-presence collector emits the tier + entry
    # gauges fail-closed shape (scrape_errors 0 + value gauges only on a
    # completed run — absence, not stale values, is the failure signal the
    # anchored Gatus conditions key on).
    machine.succeed("systemctl start hot-db-metrics.service")
    machine.succeed("systemctl is-enabled hot-db-metrics.timer")
    prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/hot-db.prom")
    assert "hot_tier_mounted 1" in prom, f"tier gauge wrong:\n{prom}"
    assert 'hot_db_entry_mounted{name="testdb"} 1' in prom, f"entry gauge wrong:\n{prom}"
    assert "hot_db_scrape_errors 0" in prom, f"scrape_errors not 0:\n{prom}"

    # 4: anti-shadow — unmount (detached-Samsung shape). The mount is
    # nofail so nothing else fails; the consumer must condition-SKIP
    # rather than write into the plain dir left behind. The consumer's
    # RequiresMountsFor would re-pull (re-MOUNT) the unit on a normal
    # start, so the mount is stopped first and the consumer is started
    # dependency-free — this isolates exactly the CONDITION layer that
    # protects against a shadow dir. Assert on observables, not the
    # ConditionResult enum vocabulary: the skip contract is "conditions
    # failed → unit did not execute → no write".
    machine.succeed("umount /var/lib/hotdb-test")
    machine.succeed("systemctl stop 'var-lib-hotdb\\x2dtest.mount' || true")
    machine.succeed("systemctl stop hotdb-consumer.service")
    machine.succeed(
        "systemctl start --job-mode=ignore-dependencies hotdb-consumer.service || true"
    )
    cond = machine.succeed("systemctl show -p ConditionResult -o cat hotdb-consumer.service").strip()
    assert cond != "yes", f"consumer conditions unexpectedly passed (ConditionResult={cond})"
    state = machine.succeed("systemctl is-active hotdb-consumer.service || true").strip()
    assert state != "active", f"consumer ran despite failed condition (state={state})"
    # The skip must leave NO shadow write.
    out = machine.succeed("ls -A /var/lib/hotdb-test || true")
    assert "probe.txt" not in out, f"shadow write detected: {out}"

    # T14 failure path (review fix): after the entry unmount, the collector
    # must flip the entry gauge to 0 — that transition is what the Gatus
    # check alerts on; a regression in the mount probe would otherwise
    # never be caught. The TIER gauge stays 1: only the entry mount was
    # removed, /mnt/hot itself is still mounted.
    machine.succeed("systemctl start hot-db-metrics.service")
    prom2 = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/hot-db.prom")
    assert "hot_tier_mounted 1" in prom2, f"tier gauge unexpectedly changed after entry unmount:\n{prom2}"
    assert 'hot_db_entry_mounted{name="testdb"} 0' in prom2, f"entry gauge did not flip to 0 after unmount:\n{prom2}"
    assert "hot_db_scrape_errors 0" in prom2, f"scrape_errors not 0 after unmount:\n{prom2}"

    # 6: shadow-split guard — the unprepared `shadowed` entry (populated
    # dataDir, no marker) must have been REFUSED a subvol; its mount fails
    # naturally, the live shadow is still reachable and intact (never
    # covered by a fresh subvol), its consumer never wrote, and the SHARED
    # bootstrap stayed green (healthy testdb converged throughout).
    # Escape trap (live 2026-11-03 first run): the escaped mount unit name
    # carries a literal \x2d — through Python AND an unquoted bash word the
    # backslash vanishes and systemctl queries hotdbx2dshadowed → exit 4
    # (not-found). Resolve the name INSIDE the guest shell instead.
    machine.succeed("systemctl is-failed \"$(systemd-escape -p --suffix=mount /var/lib/hotdb-shadowed)\"")
    # A completed oneshot (no RemainAfterExit) reads INACTIVE, not active —
    # the shared-unit green state is NOT-failed (exit-3 trap live 2026-11-03).
    machine.fail("systemctl is-failed hot-db-bootstrap")
    machine.fail("btrfs subvolume show /mnt/hot/hot/shadowed")
    guard_count = machine.succeed("btrfs subvolume list /mnt/hot | grep -c 'hot/'").strip()
    assert guard_count == "1", f"expected exactly the testdb subvol, got {guard_count}"
    machine.succeed("grep -q live-store-bytes " + "${shadowedPath}/live.db")
    machine.fail("test -e " + "${shadowedPath}/consumer-write.txt")
    machine.fail("systemctl is-active hotdb-shadowed-consumer.service")
    refusals = machine.succeed("journalctl -b -u hot-db-bootstrap --no-pager | grep -c 'REFUSED fresh subvolume for entry shadowed'").strip()
    assert refusals != "0", "no guard refusal in the bootstrap journal"
  '';
}
