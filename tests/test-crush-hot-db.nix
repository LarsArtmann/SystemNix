# VM test for the crush-hot-db service module
# (modules/nixos/services/crush-hot-db.nix).
#
# Four review rounds on this module (static-unit enable gap, 226/NAMESPACE
# ReadWritePaths, nested-discovery glob, ProtectHome empty-/home trap) each
# caught a defect that only a BOOTING unit can expose — the pre-review
# verification was an ephemeral /tmp fixture with stubbed pgrep/PATH, and
# transient systemd-run flag replicas silently differ from the real unit
# (round 4: they probed ProtectHome=read-only while the unit carried
# ProtectHome=true, which systemd maps to inaccessible-and-EMPTY /home).
# This test boots the REAL module and
# exercises every behavior the TODO_LIST "fixture-tested" claim listed:
#
#   1. migrate + symlink (top-level, NESTED at depth 3, space-in-name,
#      projects-root special case) with payload data preserved at the
#      hot-DB destination
#   2. depth cap: `<group>/<group>/<repo>/.crush` (depth 4) stays put
#   3. fresh-write skip: a crush.db written <10 min ago is left for the
#      next run (touch-backdated fixtures are what make case 1 migratable)
#   4. per-project live-writer guard (2026-09-21): a comm=crush process
#      holding an fd on one project's crush.db skips ONLY that project —
#      the old blanket pgrep skip starved convergence on a box where
#      16-21 sessions are always live (legal-cases sat unmigrated 13 days
#      after the freeze-interrupted first run)
#   5. depth-4 tripwire WARN + CRUSH_HOT_DB_DRY_RUN rehearsal (reports,
#      never moves; per-dir mv failures exit non-zero — functionally
#      proven in the user-space harness, see docs/services/crush.md)
#   6. idempotent re-run: "0 project(s) relocated", already-migrated
#      symlinks skipped (find -type d does not match them)
#   7. the is-enabled regression (deploy.sh's provisioner loop silently
#      skipped static units) and the unit-shape regressions: RequiresMountsFor
#      present (226 class) and the declared unit path carrying flock
#      (exit-127 phantom-binary class)
#
# /mnt/hot is a tmpfs stand-in (virtualisation.fileSystems — plain
# fileSystems silently vanish in VM tests, test-cv 2026-09-02); the module's
# RequiresMountsFor orders the migrate unit after the mount, exactly as the
# Samsung by-label mount does on evo-x2.
#
# The test itself caught a fourth boot-only defect: the module's Persistent
# timer elapses at BOOT (catch-up, timers.target phase — before the
# multi-user transaction) and starts the migrate unit as a fresh job that
# does NOT inherit any multi-user-transaction ordering. A boot-time fixture
# ordered only Before=multi-user.target therefore RACED the first migrate
# run (coin-flip: `find: /home/lars/projects: No such file or directory`).
# The dependency is expressed on the consumer unit (wants/after): unit-level
# ordering applies to EVERY start job regardless of trigger, so the timer's
# catch-up job waits for the fixture too.
{ pkgs }:
let
  # The flake-parts wrapper form: the file evaluates to
  # `{ flake.nixosModules.crush-hot-db = <NixOS module>; }` (two-statement
  # select — the `(import f) { }.attr` one-liner does not parse as
  # apply-then-select, test-miniflux precedent).
  crushHotDbModule =
    (import ../modules/nixos/services/crush-hot-db.nix).flake.nixosModules.crush-hot-db;

  # Fixture tree created BEFORE the migrate unit starts (After= ordering):
  # the unit's ReadWritePaths on /home/lars/projects aborts 226/NAMESPACE if
  # the path does not exist at namespace setup — the ordering IS part of the
  # regression. Every crush.db except `recent` is backdated out of the
  # module's 10-minute fresh-write window.
  fixtureSetup = pkgs.writeShellApplication {
    name = "crush-hot-db-fixture";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      projects=/home/lars/projects
      mkdir -p \
        "$projects/.crush" \
        "$projects/repo-a/.crush" \
        "$projects/archived/repo-b/.crush" \
        "$projects/spaced repo/.crush" \
        "$projects/deep/group/repo/.crush" \
        "$projects/recent/.crush"

      echo payload-root > "$projects/.crush/crush.db"
      echo payload-top > "$projects/repo-a/.crush/crush.db"
      echo payload-wal > "$projects/repo-a/.crush/crush.db-wal"
      echo payload-nested > "$projects/archived/repo-b/.crush/crush.db"
      echo payload-spaced > "$projects/spaced repo/.crush/crush.db"
      echo payload-deep > "$projects/deep/group/repo/.crush/crush.db"
      echo payload-fresh > "$projects/recent/.crush/crush.db"

      touch -d '@1000000000' \
        "$projects/.crush/crush.db" \
        "$projects/repo-a/.crush/crush.db" \
        "$projects/repo-a/.crush/crush.db-wal" \
        "$projects/archived/repo-b/.crush/crush.db" \
        "$projects/spaced repo/.crush/crush.db" \
        "$projects/deep/group/repo/.crush/crush.db"
    '';
  };
  # A real binary whose PROCESS NAME (comm) is `crush`: the liveness
  # guard matches comm, which the kernel seeds from the BASENAME of the
  # executed path — a store path's basename is `<hash>-crush`, never
  # `crush` — so the binary sets its own name via prctl(PR_SET_NAME), and
  # OPENS argv[1] (a fixture crush.db) so it demonstrably holds an fd
  # under a live project. coreutils' sleep cannot be copied under another
  # name either: nixpkgs builds it as a multi-call dispatcher that fails
  # "unknown program" exit 1 when executed as `crush` (this emptied the
  # first two committed runs' guard windows).
  crushFakeBin = pkgs.runCommand "crush" { nativeBuildInputs = [ pkgs.stdenv.cc ]; } ''
    printf '#include <unistd.h>\n#include <sys/prctl.h>\n#include <fcntl.h>\nint main(int argc,char**argv){prctl(PR_SET_NAME,"crush",0,0,0);if(argc>1){int fd=open(argv[1],O_RDONLY);(void)fd;}for(;;)pause();}\n' > main.c
    cc -O0 -o $out main.c
  '';
in
{
  name = "crush-hot-db";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ crushHotDbModule ];

      system.stateVersion = "25.11";

      # The module chowns the hot-DB tree to `${primaryUser}:users` and
      # defaults projectsDir to /home/<primaryUser>/projects; the `or`
      # fallback resolves to "lars", so the VM needs that user (isNormalUser
      # gives group = users).
      users.users.lars = {
        isNormalUser = true;
      };

      # Tmpfs stand-in for the Samsung hot-DB mount.
      virtualisation.fileSystems."/mnt/hot" = {
        fsType = "tmpfs";
      };

      systemd.services.crush-hot-db-fixture = {
        description = "crush-hot-db VM fixture tree (test-only)";
        wantedBy = [ "multi-user.target" ];
        before = [
          "crush-hot-db-migrate.service"
          "multi-user.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe fixtureSetup;
        };
      };

      # Unit-level ordering: the fixture precedes EVERY migrate start job,
      # including the Persistent timer's boot catch-up (see header).
      systemd.services.crush-hot-db-migrate = {
        wants = [ "crush-hot-db-fixture.service" ];
        after = [ "crush-hot-db-fixture.service" ];
      };

      services.crush-hot-db.enable = true;

      # A process NAMED `crush` holding a fixture crush.db open: the
      # per-project guard must skip that project and ONLY that project.
      systemd.services.crush-fake-session = {
        description = "Fake crush session (test-only live-writer guard)";
        serviceConfig = {
          Type = "exec";
          ExecStart = "${crushFakeBin} /home/lars/projects/late/.crush/crush.db";
        };
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("crush-hot-db-migrate.service")

    # ---- Regressions 1: is-enabled (deploy.sh provisioner loop gate) ----
    machine.succeed(
        'test "$(systemctl is-enabled crush-hot-db-migrate.service)" = enabled'
    )
    machine.succeed(
        'test "$(systemctl is-enabled crush-hot-db-migrate.timer)" = enabled'
    )

    # ---- Regression 2: unit shape (226 + phantom-binary classes) ----
    unit = machine.succeed("systemctl cat crush-hot-db-migrate.service")
    assert "RequiresMountsFor" in unit, "RequiresMountsFor missing from unit"
    assert "util-linux" in unit, "unit path missing flock (util-linux)"
    assert (
        "ProtectHome=read-only" in unit
    ), "ProtectHome must be read-only: harden{}'s `true` default maps to systemd yes = inaccessible-and-EMPTY /home, so every find ENOENTs (round-4 trap)"

    # ---- Boot-run outcome: exactly the 4 migratable fixtures relocated ----
    boot_log = machine.succeed(
        "journalctl -b -u crush-hot-db-migrate.service --output cat"
    )
    assert "4 project(s) relocated" in boot_log, boot_log

    # ---- Depth-4 tripwire: the deep fixture surfaces a WARN ----
    assert "deeper than discovery depth 3" in boot_log, boot_log
    assert "deep/group/repo/.crush" in boot_log, boot_log

    # ---- Migration + symlink + data preserved ----
    # The module moves the PROJECT'S `.crush` dir and symlinks it back:
    # `<project>` stays a real dir, `<project>/.crush` becomes the symlink.
    machine.succeed("test -L /home/lars/projects/repo-a/.crush")
    machine.succeed(
        'test "$(readlink /home/lars/projects/repo-a/.crush)" = /mnt/hot/crush/repo-a'
    )
    machine.succeed("grep -q payload-top /mnt/hot/crush/repo-a/crush.db")
    machine.succeed("grep -q payload-wal /mnt/hot/crush/repo-a/crush.db-wal")

    # projects-root special case: $projects/.crush → /mnt/hot/crush/projects-root
    machine.succeed("test -L /home/lars/projects/.crush")
    machine.succeed(
        'test "$(readlink /home/lars/projects/.crush)" = /mnt/hot/crush/projects-root'
    )
    machine.succeed("grep -q payload-root /mnt/hot/crush/projects-root/crush.db")

    # Nested checkout: parent hierarchy auto-created under the destination.
    machine.succeed("test -L /home/lars/projects/archived/repo-b/.crush")
    machine.succeed("grep -q payload-nested /mnt/hot/crush/archived/repo-b/crush.db")

    # Space-in-name checkout.
    machine.succeed("test -L '/home/lars/projects/spaced repo/.crush'")
    machine.succeed("grep -q payload-spaced '/mnt/hot/crush/spaced repo/crush.db'")

    # ---- Left in place: depth cap + fresh-write skip ----
    machine.fail("test -L /home/lars/projects/deep/group/repo/.crush")
    machine.succeed("test -f /home/lars/projects/deep/group/repo/.crush/crush.db")
    machine.fail("test -L /home/lars/projects/recent/.crush")
    machine.succeed("test -f /home/lars/projects/recent/.crush/crush.db")

    # ---- Per-project live-writer guard, with BOTH controls ----
    # `late` is held open by a comm=crush process; `late2` is identical
    # but unheld. The run must migrate late2 while skipping exactly
    # `late` — the old blanket pgrep skip would have left BOTH on the QLC
    # root (relocating under a live writer strands the directory on an
    # unlinked inode, but ONE live session must not starve the rest).
    machine.succeed(
        "mkdir -p /home/lars/projects/late/.crush /home/lars/projects/late2/.crush"
        " && echo payload-late > /home/lars/projects/late/.crush/crush.db"
        " && echo payload-late2 > /home/lars/projects/late2/.crush/crush.db"
        " && touch -d '@1000000000' /home/lars/projects/late/.crush/crush.db"
        " /home/lars/projects/late2/.crush/crush.db"
    )
    machine.succeed("systemctl start crush-fake-session.service")
    machine.succeed("pgrep -x crush")  # guard must be live BEFORE the restart
    machine.succeed("systemctl restart crush-hot-db-migrate.service")
    guard_log = machine.succeed(
        "journalctl -b -u crush-hot-db-migrate.service --output cat"
    )
    assert "skip late: live crush session holds it open" in guard_log, guard_log
    machine.fail("test -L /home/lars/projects/late/.crush")
    machine.succeed("test -f /home/lars/projects/late/.crush/crush.db")
    machine.succeed("test -L /home/lars/projects/late2/.crush")
    machine.succeed("grep -q payload-late2 /mnt/hot/crush/late2/crush.db")

    # ---- Dry-run rehearsal: reports the migration, never performs it ----
    machine.succeed(
        "mkdir -p /home/lars/projects/dryproj/.crush"
        " && echo payload-dry > /home/lars/projects/dryproj/.crush/crush.db"
        " && touch -d '@1000000000' /home/lars/projects/dryproj/.crush/crush.db"
    )
    machine.succeed(
        "systemctl set-environment CRUSH_HOT_DB_DRY_RUN=1"
        " && systemctl restart crush-hot-db-migrate.service"
    )
    dry_log = machine.succeed(
        "journalctl -b -u crush-hot-db-migrate.service --output cat"
    )
    assert "dry-run: would migrate dryproj" in dry_log, dry_log
    assert "would relocate 1 project(s)" in dry_log, dry_log
    machine.fail("test -L /home/lars/projects/dryproj/.crush")
    machine.succeed("systemctl unset-environment CRUSH_HOT_DB_DRY_RUN")

    # Guard gone → the next run converges the pending projects.
    machine.succeed("systemctl stop crush-fake-session.service")
    machine.succeed("systemctl restart crush-hot-db-migrate.service")
    machine.succeed("test -L /home/lars/projects/late/.crush")
    machine.succeed("grep -q payload-late /mnt/hot/crush/late/crush.db")
    machine.succeed("test -L /home/lars/projects/dryproj/.crush")
    machine.succeed("grep -q payload-dry /mnt/hot/crush/dryproj/crush.db")

    # ---- Idempotent re-run: symlinks skipped, 0 relocated ----
    machine.succeed("systemctl restart crush-hot-db-migrate.service")
    rerun_log = machine.succeed(
        "journalctl -b -u crush-hot-db-migrate.service --output cat | tail -n 2"
    )
    assert "0 project(s) relocated" in rerun_log, rerun_log
  '';
}
